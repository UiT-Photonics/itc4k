function varargout = gui(varargin)
% ITC4k.gui(); opens a graphical user interface to connect, control and
% disconnect from an ITC4000-series laser controller.
%
% uip = ITC4k.gui(); creates a gui to control an ITC4000 and returns the handle 
% of the uipanel that contains all the controls that has been created in a new
% uifigure.
%
% uip = ITC4k.gui(parent); as above but creates the uipanel inside the parent
% provided.
%
% Example
%    % create an application to control your laser and massflow controller
%    uif = uifigure('Name', 'Full Lab GUI');
%    gl = uigridlayout(uif, [1 3], 'ColumnWidth', {300, '1x', '2x'});
%    laser_panel = ITC4k.gui(gl);
%    mfc_panel = MyMassFlowControllerGui(gl); % you create this one
%    result_plt = uiaxes(gl);
%
% TODO
% - Switch to setting current span rather than depth as a default for internal
%   modulation (leaving the ?-button and thru that one manually setting the
%   depth)
% - Switch to more useful tooltips

    % state and gui
    s = struct('dev', [], 'timer', []);
    g = struct();

    if nargin == 0
        % autoresizing doesn't seem to work very well with position = [0 0 1 1]
        g.uif = uifigure('Name', 'ITC4000 Controller', ...
                         'AutoResizeChildren', 'off');
        uip = uipanel(g.uif, 'Units', 'norm', 'Position', [0 0 1 1]);
    elseif nargin == 1
        uip = uipanel(varargin{1}, 'Title', 'ITC4000 Controller');
        g.uif = ancestor(varargin{1}, 'matlab.ui.Figure');
    else
        error('ITC4k:gui:nargin', ...
              'ITC4k.gui only accepts 0 or 1 arguments.');
    end
    uip.DeleteFcn = @cb_panel_delete;

    n_rows = 22;
    row = 0;
    gl = uigridlayout(uip, [n_rows 2], 'ColumnWidth', {120, '1x'}, ...
                      'RowHeight', repmat({'fit'}, 1, n_rows), ...
                      'Scrollable', 'on');
    % device selection section
    row = row + 1;
    g.dd_devs = uidropdown(gl);
    gl_pos(g.dd_devs, row, [1 2]);

    row = row + 1;
    gl_pos(uibutton(gl, 'Text', 'Refresh devices', ...
                    'ButtonPushedFcn', @(~,~) update_dd_devs()), row, 1);
    gl_pos(uibutton(gl, 'state', 'Text', 'Connect', ...
                    'ValueChangedFcn', @cb_toggle_conn), row, 2);
    % since the whole ui-family is missing a horizontal ruler we'll just use the
    % html component for it
    row = row + 1;
    gl_pos(uilabel(gl, 'Text', '<hr />', 'Interpreter', 'html', ...
                   'FontSize', 1), row, [1 2]);
    % keylock included in device selection
    row = row + 1;
    g.Key_lock = gl_pair(gl, row, 'Key Lock', @uilamp, 'Color', 'red');

    % temperature section
    row = row + 1;
    gl_pos(uilabel(gl, 'Text', 'TEC Control', 'FontWeight', 'bold', ...
                   'HorizontalAlignment', 'center'), row, [1 2]);
    row = row + 1;
    g.T_setpoint = gl_pair(gl, row, 'Temperature setpoint', @uieditfield, ...
                           'numeric', 'ValueDisplayFormat', '%.3f K', ...
                           'ValueChangedFcn', @cb_set_Tsp);
    row = row + 1;
    g.T_reading = gl_pair(gl, row, 'Temperature reading', @uilabel, ...
                          'Text', 'N/A');
    row = row + 1;
    [~, T_units] = enumeration('ITC4kEnums.TemperatureUnit');
    g.T_unit = gl_pair(gl, row, 'T unit', @uidropdown, 'Items', T_units, ...
                       'ValueChangedFcn', @cb_set_Tunit);
    row = row + 1;
    g.TEC = gl_pair(gl, row, 'TEC', @uiswitch, 'slider', ...
                    'Orientation', 'horizontal', ...
                    'ValueChangedFcn', @cb_toggle_TEC);

    % Laser modulation section
    row = row + 1;
    gl_pos(uilabel(gl, 'Text', 'Laser Modulation', 'FontWeight', 'bold', ...
                   'HorizontalAlignment', 'center'), row, [1 2]);
    row = row + 1;
    gl_ms = gl_pair(gl, row, 'Source', @uigridlayout, [1 2], ...
                    'ColumnWidth', {'fit', 'fit'}, ...
                    'RowHeight', {'fit'}, ...
                    'Padding', [0 0 0 0]);
    g.LD_AM_src_int = gl_pos(uicheckbox(gl_ms, 'Text', 'Internal', ...
                                        'Tag', 'internal', ...
                                        'ValueChangedFcn', @cb_set_LD_AM_src), ...
                             1, 1);
    g.LD_AM_src_ext = gl_pos(uicheckbox(gl_ms, 'Text', 'External', ...
                                        'Tag', 'external', ...
                                        'ValueChangedFcn', @cb_det_LD_AM_src), ...
                             1, 2);
    row = row + 1;
    [~, mod_shapes] = enumeration('ITC4kEnums.ModulationShape');
    g.LD_AM_shape = gl_pair(gl, row, '(IM) Shape', @uidropdown, ...
                            'Items', mod_shapes, ...
                            'ValueChangedFcn', @cb_set_LD_AM_shape);
    row = row + 1;
    g.LD_AM_freq = gl_pair(gl, row, '(IM) Frequency', @uieditfield, ...
                           'numeric', 'ValueDisplayFormat', '%u Hz', ...
                           'ValueChangedFcn', @cb_set_LD_AM_freq);
    row = row + 1;
    gl_d = gl_pair(gl, row, '(IM) Depth', @uigridlayout, [1 2], ...
                   'ColumnWidth', {'1x', 'fit'}, ...
                   'RowHeight', {'fit'}, ...
                   'Padding', [0 0 0 0]);
    g.LD_AM_depth = gl_pos(uieditfield(gl_d, 'numeric', ...
                                       'ValueDisplayFormat', '%.1f %%', ...
                                       'ValueChangedFcn', @cb_set_LD_AM_depth), ...
                           1, 1);
    % just storing this one to dis/enable no dis/connect
    g.d_wiz = gl_pos(uibutton(gl_d, 'Text', '', 'Icon', 'question', ...
                              'Tooltip', 'Click to open a calculator that generates modulation depth and current setpoint based on current limits.', ...
                              'ButtonPushedFcn', @(~,~) LD_AM_wizard()), ...
                     1, 2);
    row = row + 1;
    g.LD_AM = gl_pair(gl, row, 'Modulation', @uiswitch, 'slider', ...
                      'Orientation', 'horizontal', ...
                      'ValueChangedFcn', @cb_toggle_LD_AM);

    % Laser section
    row = row + 1;
    gl_pos(uilabel(gl, 'Text', 'Laser Control', 'FontWeight', 'bold', ...
                   'HorizontalAlignment', 'center'), row, [1 2]);
    row = row + 1;
    g.LD_prot = gl_pair(gl, row, 'Protection tripped', @uilamp, ...
                        'Color', 'red');
    row = row + 1;
    g.LD_A_setpoint = gl_pair(gl, row, 'Current setpoint', @uieditfield, ...
                              'numeric', 'ValueDisplayFormat', '%.4f A', ...
                              'ValueChangedFcn', @cb_set_LD_Asp);
    row = row + 1;
    g.LD_A_limit = gl_pair(gl, row, 'Current limit', @uieditfield, ...
                           'numeric', 'ValueDisplayFormat', '%.4f A', ...
                           'ValueChangedFcn', @cb_set_LD_A_lim);
    row = row + 1;
    g.LD_A_reading = gl_pair(gl, row, 'Current reading', @uilabel, ...
                             'Text', 'N/A');
    row = row + 1;
    g.LD_V_reading = gl_pair(gl, row, 'Voltage reading', @uilabel, ...
                             'Text', 'N/A');
    row = row + 1;
    g.LD = gl_pair(gl, row, 'LD', @uiswitch, 'slider', ...
                   'Orientation', 'horizontal', ...
                   'ValueChangedFcn', @cb_toggle_LD);

    % lastly we update the devs and adjust the window if we created it
    enable_fields('off');
    update_dd_devs();
    if nargin == 0; resz_and_center(g.uif, 290, 666, 0); end
    if nargout > 0; varargout{1} = uip; end

%% "pure" callbacks
    % when i tried this out on some matlab version of windows it was easy to get
    % the same value in d.Value as d.PreviousValue by e.g. pressing a button
    % quickly, hence the checks everywhere.
    function cb_panel_delete(~, ~)
        if isa(s.dev, 'ITC4k'); s.dev.disconnect(); end
        if isa(s.timer, 'timer') && strcmp(s.timer.Running, 'on')
            s.timer.stop();
        end
    end

    function cb_toggle_conn(c, d)
        if strcmp(d.Value, d.PreviousValue); return; end
        g.uif.Pointer = 'watch';
        drawnow();
        if d.Value == 1; c.Value = connect_dev();
        else; c.Value = ~disconnect_dev();
        end
        if c.Value == 1; c.Text = 'Disconnect';
        else; c.Text = 'Connect';
        end
        g.uif.Pointer = 'arrow';
    end

    function cb_set_Tsp(~, d)
        if d.Value == d.PreviousValue; return; end
        s.dev.T_setpoint = d.Value;
    end

    function cb_set_Tunit(~, d)
        if strcmp(d.Value, d.PreviousValue); return; end
        s.dev.T_unit = d.Value;
        % gotta update the setpoint
        set_numfield_lims(g.T_setpoint, s.dev.bounds.T_setpoint.min, ...
                          s.dev.bounds.T_setpoint.max);
        g.T_setpoint.Value = s.dev.T_setpoint;
    end

    function cb_toggle_TEC(~, d)
        if strcmp(d.Value, d.PreviousValue); return; end
        s.dev.TEC = d.Value;
    end

    function cb_set_LD_Asp(~, d)
        if d.Value == d.PreviousValue; return; end
        s.dev.LD_A_setpoint = d.Value;
    end

    function cb_set_LD_A_lim(~, d)
        if d.Value == d.PreviousValue; return; end
        s.dev.LD_A_limit = d.Value;
    end

    function cb_toggle_LD(c, d)
        if strcmp(d.Value, d.PreviousValue); return; end
        if strcmp(d.Value, 'On') && ~s.dev.TEC
            sel = uiconfirm(g.uif, ...
                            'TEC is not on! Are you sure you want to turn on the Laser?', ...
                            'Possible overheating!', ...
                            'Options', {'Yes', 'No'}, ...
                            'DefaultOption', 2, ...
                            'Icon', 'warning');
            if strcmp(sel, 'No')
                c.Value = 'Off';
                return;
            end
        end
        s.dev.LD = d.Value;
    end

    function cb_set_LD_AM_src(c, d)
        if d.Value == d.PreviousValue; return; end
        % one thing to keep in mind here is that the possible states for the
        % buttons together can only be <either> or <both>, never <neither>
        src = s.dev.LD_AM_source;
        if strcmp(d.Tag, 'internal')
            unchecked_res = ITC4kEnums.ModulationSource.External;
        elseif strcmp(d.Tag, 'external')
            unchecked_res = ITC4kEnums.ModulationSource.Internal;
        else
            warning('ITC4k:gui:unknown_LD_AM_source', ...
                    'Unknown LD_AM_source "%s"', c.Tag);
            c.Value = d.PreviousValue;
        end

        if d.Value % checkbox has been checked
            if src == unchecked_res
                s.dev.LD_AM_source = ITC4kEnums.ModulationSource.Both;
            end
        else % checkbox has been unchecked..
            if src == ITC4kEnums.ModulationSource.Both
                s.dev.LD_AM_source = unchecked_res;
            else
                % ..but if src ~= <both> (i.e. the other checkbox is not
                % checked) we have to recheck the invoking box.
                c.Value = true;
            end
        end
    end

    function cb_set_LD_AM_shape(~, d)
        if strcmp(d.Value, d.PreviousValue); return; end
        s.dev.LD_AM_shape = d.Value;
    end

    function cb_set_LD_AM_freq(~, d)
        if d.Value == d.PreviousValue; return; end
        s.dev.LD_AM_frequency = d.Value;
    end

    function cb_set_LD_AM_depth(~, d)
        if d.Value == d.PreviousValue; return; end
        s.dev.LD_AM_depth = d.Value;
    end

    function cb_toggle_LD_AM(~, d)
        if strcmp(d.Value, d.PreviousValue); return; end
        s.dev.LD_AM = d.Value;
    end

%% supporting functions
    % these are the ones doing the heavy lifting for some of the callbacks
    function v = connect_dev()
        v = false;
        try
            s.dev = ITC4k(g.dd_devs.Value);
        catch e
            if strcmp(e.identifier, ...
                      'instrument:interface:visa:multipleIdenticalResources')
                sel = uiconfirm(g.uif, ...
                                'This device is already connected and does not support multiple connections. Do you want me to murder the other connection so you can try again?', ...
                                'Connection Failed!', ...
                                'Options', {'Yes', 'No'}, ...
                                'DefaultOption', 1, ...
                                'Icon', 'error');
                if strcmp(sel, 'Yes')
                    % visadevfind is from R2024a...
                    if exist('visadevfind', 'file') == 2; finder = @visadevfind;
                    else; finder = @instrfind; %#ok<INSTRF>
                    end
                    dev = finder('ResourceName', g.dd_devs.Value.ResourceName);
                    if ~isempty(dev)
                        delete(dev);
                        uialert(g.uif, ...
                                'Murder went well. Try connecting again!', ...
                                'Kill confirmed.', ...
                                'Icon', 'success');
                    else
                        uialert(g.uif, ...
                                'Could not find the other connection, you will likely have to restart matlab/the device/the computer.', ...
                                'Kill failed', ...
                                'Icon', 'error');
                    end
                end
            else
                uialert(g.uif, e.message, 'Connection Failed!');
            end
            return;
        end
        % set the min and max limits for the numeric fields
        set_numfield_lims(g.T_setpoint, s.dev.bounds.T_setpoint.min, ...
                          s.dev.bounds.T_setpoint.max);
        set_numfield_lims(g.LD_A_setpoint, s.dev.bounds.LD_A_setpoint.min, ...
                          s.dev.bounds.LD_A_setpoint.max);
        set_numfield_lims(g.LD_A_limit, s.dev.bounds.LD_A_limit.min, ...
                          s.dev.bounds.LD_A_limit.max);
        set_numfield_lims(g.LD_AM_freq, s.dev.bounds.LD_AM_frequency.min, ...
                          s.dev.bounds.LD_AM_frequency.max);
        set_numfield_lims(g.LD_AM_depth, s.dev.bounds.LD_AM_depth.min, ...
                          s.dev.bounds.LD_AM_depth.max);
        s.timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, ...
                        'StartDelay', 0, 'TimerFcn', @(~,~) update_vals()); %update_vals_bridge());
        s.timer.start();
        enable_fields('on');
        v = true;
    end
    function update_vals_bridge() %#ok<DEFNU>
% this one's around to debug failures when running the timer
        try update_vals();
        catch me; disp(getReport(me, 'extended', 'hyperlinks', 'on'));
        end
    end

    function v = disconnect_dev()
        v = true;
        enable_fields('off');
        if isa(s.dev, 'ITC4k'); s.dev.disconnect(); end
        if isa(s.timer, 'timer') && strcmp(s.timer.Running, 'on')
            s.timer.stop();
        end
    end

    function set_numfield_lims(f, lmin, lmax)
        f.Limits = [lmin lmax];
        fmt = char(f.ValueDisplayFormat);
        f.Tooltip = sprintf([fmt,' - ', fmt], lmin, lmax);
        f.Placeholder = f.Tooltip;
    end

    function enable_fields(tf)
        blacklist = {'uif', 'uifm', 'wiz', 'dd_devs'};
        for nm_cell = reshape(fieldnames(g), 1, [])
            if any(strcmp(nm_cell, blacklist)); continue;
            else; nm = nm_cell{1};
            end
            if isprop(g.(nm), 'Enable'); g.(nm).Enable = tf; end
        end
    end

    function update_vals()
        lamp_clrs = {'green', 'red'};
        % TODO
        % - values should not be set if the control has the focus
        if ~s.dev.Key_lock
            if g.Key_lock.Color(1) == 1
                g.Key_lock.Color = lamp_clrs{1};
                g.Key_lock.Tooltip = 'Key lock is off!';
            end
        else
            if g.Key_lock.Color(1) ~= 1
                g.Key_lock.Color = lamp_clrs{2};
                g.Key_lock.Tooltip = 'Key lock is on!';
            end
        end

        % temperature stuff
        T_unit = char(s.dev.T_unit);
        if T_unit(1) == 'K'; T_fmt = '%.4f K';
        else; T_fmt = ['%.4f °', T_unit(1)];
        end
        if g.T_unit.Value(1) ~= T_unit(1)
            g.T_setpoint.ValueDisplayFormat = T_fmt;
            g.T_unit.Value = T_unit;
        end
        Tsp = s.dev.T_setpoint;
        set_if_neq(g.T_setpoint, Tsp);
        % TODO: g.T_reading.Background = [color_gradient from #00FFFF to #FF0000](T - Tsp)
        g.T_reading.Text = sprintf(T_fmt, s.dev.T_reading);
        % dunno why uisliders dont have matlab.lang.OnOffSwitchState values..
        TEC_state = s.dev.TEC;
        if ~strcmpi(g.TEC.Value, TEC_state)
            g.TEC.Value = g.TEC.Items{TEC_state+1};
        end
        
        % Laser stuff
        LD_tripped = s.dev.LD_protection_tripped.tripped;
        if any(LD_tripped)
            g.LD_prot.Color = lamp_clrs{2};
            g.LD_prot.Tooltip = sprintf('Tripped protection(s): %s', ...
                                        strjoin(s.dev.LD_protection_tripped.name(LD_tripped), ', '));
        elseif g.LD_prot.Color(1) == 1 % TODO: make better
            g.LD_prot.Color = lamp_clrs{1};
            g.LD_prot.Tooltip = 'No protection tripped';
        end
        set_if_neq(g.LD_A_setpoint, s.dev.LD_A_setpoint);
        set_if_neq(g.LD_A_limit, s.dev.LD_A_limit);
        % TODO: g.LD_A_reading.Background = [color_gradient from #00FFFF to #FF0000](LD_A - LDAsp)
        g.LD_A_reading.Text = sprintf('%.4f A', s.dev.LD_A_reading);
        g.LD_V_reading.Text = sprintf('%.4f V', s.dev.LD_V_reading);
        LD_state = s.dev.LD;
        if ~strcmpi(g.LD.Value, LD_state)
            g.LD.Value = g.LD.Items{LD_state+1};
        end

        % Laser modulation stuff
        am_src = s.dev.LD_AM_source == ...
                 [ITC4kEnums.ModulationSource.Internal, ...
                  ITC4kEnums.ModulationSource.External, ...
                  ITC4kEnums.ModulationSource.Both];
        g.LD_AM_src_int.Value = any(am_src([1,3]));
        g.LD_AM_src_ext.Value = any(am_src([2,3]));

        LD_AM_shape = char(s.dev.LD_AM_shape);
        if ~strcmpi(g.LD_AM_shape.Value, LD_AM_shape)
            g.LD_AM_shape.Value = LD_AM_shape;
        end

        set_if_neq(g.LD_AM_freq, s.dev.LD_AM_frequency);
        set_if_neq(g.LD_AM_depth, s.dev.LD_AM_depth);
        LD_AM_state = s.dev.LD_AM;
        if ~strcmpi(g.LD_AM.Value, LD_AM_state)
            g.LD_AM.Value = g.LD_AM.Items{LD_AM_state+1};
        end
    end
    function set_if_neq(c,v)
        if any(c.Value ~= v); c.Value = v; end
    end

    function update_dd_devs()
        g.uif.Pointer = 'watch';
        devs = ITC4k.list();
        strs = [devs.ResourceName];
        has_alias = ~([devs.Alias] == "");
        if any(has_alias); strs(has_alias) = [devs(has_alias).Alias]; end
        g.dd_devs.Items = strs;
        g.dd_devs.ItemsData = devs;
        g.uif.Pointer = 'arrow';
    end

%% depth calculator ("wizard") section
    function LD_AM_wizard()
        g.uifm = uifigure('Name', 'Modulation depth calculator', ...
                          'WindowStyle','modal');
        resz_and_center(g.uifm, 290, 140, g.uif);
        g.wiz = struct();
        gl_wiz = uigridlayout(g.uifm, [4 2], 'ColumnWidth', {120, '1x'}, ...
                              'RowHeight', repmat({'fit'}, 1, 4), ...
                              'Scrollable', 'on');
        g.wiz.sp = g.LD_A_setpoint.Value;
        g.wiz.d = g.LD_AM_depth.Value;
        half_p2p = s.dev.bounds.LD_A_limit.max * g.wiz.d * 0.01 / 2;
        g.wiz.min = gl_pair(gl_wiz, 1, 'Min current', @uieditfield, ...
                            'numeric', 'Value', g.wiz.sp - half_p2p, ...
                            'ValueDisplayFormat', '%.4f A', ...
                            'ValueChangedFcn', @cb_wiz_calc);
        g.wiz.max = gl_pair(gl_wiz, 2, 'Max current', @uieditfield, ...
                            'numeric', 'Value', g.wiz.sp + half_p2p, ...
                            'ValueDisplayFormat', '%.4f A', ...
                            'ValueChangedFcn', @cb_wiz_calc);
        set_numfield_lims(g.wiz.min, s.dev.bounds.LD_A_limit.min, ...
                          s.dev.bounds.LD_A_limit.max);
        set_numfield_lims(g.wiz.max, s.dev.bounds.LD_A_limit.min, ...
                          s.dev.bounds.LD_A_limit.max);
        g.wiz.lbl = gl_pair(gl_wiz, 3, '(IM) Setpoint / Depth', @uilabel, ...
                            'Text', sprintf('%.4f A / %.1f %%', ...
                                            g.wiz.sp, g.wiz.d));
        g.wiz.btn = gl_pos(uibutton(gl_wiz, 'Text', 'Store values & close!', ...
                                    'ButtonPushedFcn', @cb_wiz_store, ...
                                    'Enable', 'off', ...
                                    'Tooltip', 'Values can not be stored while LD is on.'), ...
                           4, [1 2]);
        if strcmpi(s.dev.LD, 'off')
            g.wiz.btn.Enable = 'on';
            g.wiz.btn.Tooltip = 'Click to set calculated values';
        end
        uiwait(g.uifm);
    end
    function cb_wiz_calc(f, d)
        try
            [sp, d] = s.dev.lims2AM_depth(g.wiz.min.Value, g.wiz.max.Value);
        catch e
            uialert(g.uifm, e.message, 'Calculation error!');
            f.Value = d.PreviousValue;
            return;
        end
        g.wiz.lbl.Text = sprintf('%.4f A / %.1f %%', sp, d);
        g.wiz.sp = sp;
        g.wiz.d = d;
    end
    function cb_wiz_store(~,~)
        s.dev.LD_A_setpoint = g.wiz.sp;
        s.dev.LD_AM_depth = g.wiz.d;
        delete(g.uifm);
    end

%% gui building stuff
    function p = resz_and_center(win, w, h, parent_win)
        pu = get(parent_win, 'Units');
        wu = get(win, 'Units');
        set([parent_win, win], 'Units', 'pixels');
        if isprop(parent_win, 'Position')
            p = get(parent_win, 'Position');
            set(win, 'Position', [p(1)+(p(3)-w)/2, p(2)+(p(4)-h)/2, w, h]);
        elseif isprop(parent_win, 'ScreenSize')
            sz = get(parent_win, 'ScreenSize');
            set(win, 'Position', [(sz(3)-w)/2, (sz(4)-h)/2, w, h]);
        end
        set(win, 'Units', wu);
        set(parent_win, 'Units', pu);
    end

    function ctrl = gl_pair(gl, r, s, fn, varargin)
% helper for grid layout label-control pairs, args are:
%   gl    - grid layout
%   r     - row
%   s     - label string
%   fn    - control creation function, e.g. @uibutton, or a control.
% any argument following fn will be pased to fn following gl.
        l = uilabel(gl, 'Text', [s, ':'], 'HorizontalAlignment', 'right', ...
                    'Interpreter', 'html');
        gl_pos(l, r, 1);
        if isa(fn, 'function_handle'); ctrl = fn(gl, varargin{:});
        else; ctrl = fn;
        end
        gl_pos(ctrl, r, 2);
    end
    function e = gl_pos(e, r, c)
% Sets the row and column of an elemnt in an gridlayout's layout-property.
%
% Arguments:
% e - element
% r - row
% c - column
        e.Layout.Row = r;
        e.Layout.Column = c;
    end
end
