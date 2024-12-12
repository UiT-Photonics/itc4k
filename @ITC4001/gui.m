function uip = gui(varargin)
% uip = ITC4001.gui(); creates a gui to control a ITC4001 and returns the handle 
% of the uipanel that contains all the controls that has been created in a new
% uifigure.
%
% uip = ITC4001.gui(parent); as above but creates the uipanel inside the parent
% provided.
%
% Example
%    % create an application to control your laser and massflow controller
%    uif = uifigure('Name', 'Full Lab GUI');
%    gl = uigridlayout(uif, [1 3], 'ColumnWidth', {300, '1x', '2x'});
%    laser_panel = ITC4001.gui(gl);
%    mfc_panel = MyMassFlowControllerGui(gl); % you create this one
%    result_plt = uiaxes(gl);

    % the state
    s = struct('dev', [], 'timer', []);
    g = struct();

    if nargin == 0
        % autoresizing doesn't seem to work very well with position = [0 0 1 1]
        g.uif = uifigure('Name', 'ITC4001 Controller', ...
                         'AutoResizeChildren', 'off');
        uip = uipanel(g.uif, 'Units', 'norm', 'Position', [0 0 1 1]);
    elseif nargin == 1
        uip = uipanel(varargin{1}, 'Title', 'ITC4001 Controller');
        g.uif = ancestor(varargin{1}, 'matlab.ui.Figure');
    else
        error('ITC4001:gui:nargin', ...
              'ITC4001.gui only accepts 0 or 1 arguments.');
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
                           'numeric', 'ValueDisplayFormat', '%.4f K', ...
                           'ValueChangedFcn', @cb_set_Tsp);
    row = row + 1;
    g.T_reading = gl_pair(gl, row, 'Temperature reading', @uilabel, ...
                          'Text', 'N/A');
    row = row + 1;
    [~, T_units] = enumeration('ITC4001Enums.TemperatureUnit');
    g.T_unit = gl_pair(gl, row, 'T unit', @uidropdown, 'Items', T_units, ...
                       'ValueChangedFcn', @cb_set_Tunit);
    row = row + 1;
    g.TEC = gl_pair(gl, row, 'TEC', @uiswitch, 'slider', ...
                    'Orientation', 'horizontal', ...
                    'ValueChangedFcn', @cb_toggle_TEC);

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

    % Laser modulation
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
                                             'ValueChangedFcn', @cb_mod_src), ...
                                  1, 1);
    g.LD_AM_src_ext = gl_pos(uicheckbox(gl_ms, 'Text', 'External', ...
                                             'Tag', 'external', ...
                                             'ValueChangedFcn', @cb_mod_src), ...
                                  1, 2);
    row = row + 1;
    [~, mod_shapes] = enumeration('ITC4001Enums.ModulationShape');
    g.LD_AM_shape = gl_pair(gl, row, 'Internal mod. shape', @uidropdown, ...
                            'Items', mod_shapes);
    row = row + 1;
    g.LD_AM_freq = gl_pair(gl, row, 'Internal mod. Frequency', @uieditfield, ...
                           'numeric', 'ValueDisplayFormat', '%.4f Hz');
    row = row + 1;
    g.LD_AM_depth = gl_pair(gl, row, 'Internal mod. Depth', @uieditfield, ...
                            'numeric', 'ValueDisplayFormat', '%.4f %%');
    row = row + 1;
    g.LD_AM = gl_pair(gl, row, 'Modulation', @uiswitch, 'slider', ...
                      'Orientation', 'horizontal', ...
                      'ValueChangedFcn', @cb_toggle_LD_AM);

    % lastly we update the devs and adjust the window if we created it
    enable_fields('off');
    update_dd_devs();
    if nargin == 0
        g.uif.Units = 'pixels';
        root_unit = get(0, 'Units');
        set(0, 'Units', 'pixels');
        sz = get(0, 'ScreenSize');
        set(0, 'Units', root_unit);
        w = 290;
        h = 666;
        g.uif.Position = [(sz(3)-w)/2, (sz(4)-h)/2, w, h];
    end

    %% "pure" callbacks
    function cb_panel_delete(~, ~)
        if isa(s.dev, 'ITC4001'); s.dev.disconnect(); end
        if isa(s.timer, 'timer') && strcmp(s.timer.Running, 'on')
            s.timer.stop();
        end
    end

    function cb_toggle_conn(btn, dat)
        g.uif.Pointer = 'watch';
        drawnow();
        if dat.Value == 1; btn.Value = connect_dev();
        else; btn.Value = ~disconnect_dev();
        end
        if btn.Value == 1; btn.Text = 'Disconnect';
        else; btn.Text = 'Connect';
        end
        g.uif.Pointer = 'arrow';
    end

    function cb_set_Tsp(~, dat)
        if dat.Value == dat.PreviousValue; return; end
        s.dev.T_setpoint = dat.Value;
    end

    function cb_set_Tunit(~, dat)
        if strcmp(dat.Value, dat.PreviousValue); return; end
        s.dev.T_unit = dat.Value;
        % gotta update the setpoint
        set_numfield_lims(g.T_setpoint, s.dev.bounds.T_setpoint.min, ...
                          s.dev.bounds.T_setpoint.max);
        g.T_setpoint.Value = s.dev.T_setpoint;
    end

    function cb_toggle_TEC(~, dat)
        s.dev.TEC = dat.Value;
    end

    function cb_set_LD_Asp(~, dat)
        if dat.Value == dat.PreviousValue; return; end
        s.dev.LD_A_setpoint = dat.Value;
    end

    function cb_set_LD_A_lim(~, dat)
        if dat.Value == dat.PreviousValue; return; end
        s.dev.LD_A_limit = dat.Value;
    end

    function cb_toggle_LD(btn, dat)
        if dat.Value && ~s.dev.TEC
            sel = uiconfirm(g.uif, ...
                            'TEC is not on! Are you sure you want to turn on the Laser?', ...
                            'Possible overheating!', ...
                            'Options', {'Yes', 'No'}, ...
                            'DefaultOption', 2, ...
                            'Icon', 'warning');
            if strcmp(sel, 'No')
                btn.Value = false;
                return;
            end
        end
        s.dev.LD = btn.Value;
    end

    function cb_mod_src(btn, dat)
        % TODO
    end

    function cb_toggle_LD_AM(btn, dat)
        % TODO
    end

    %% supporting functions
    % these are the ones doing the heavy lifting for some of the callbacks
    function v = connect_dev()
        v = false;
        try
            s.dev = ITC4001(g.dd_devs.Value);
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
                        'StartDelay', 0, 'TimerFcn', @(~,~) update_vals_bridge()); %update_vals());
        s.timer.start();
        enable_fields('on');
        v = true;
    end
    function update_vals_bridge() 
        try
            update_vals();
        catch me
            disp(getReport(me, 'extended', 'hyperlinks', 'on'));
        end
    end

    function v = disconnect_dev()
        v = true;
        enable_fields('off');
        if isa(s.dev, 'ITC4001'); s.dev.disconnect(); end
        if isa(s.timer, 'timer') && strcmp(s.timer.Running, 'on')
            s.timer.stop();
        end
    end

    function set_numfield_lims(f, lmin, lmax)
        f.Limits = [lmin lmax];
        f.Tooltip = sprintf('%.4f - %.4f', lmin, lmax);
        f.Placeholder = f.Tooltip;
    end

    function enable_fields(tf)
        blacklist = {'uif', 'dd_devs'};
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
        g.Key_lock.Color = lamp_clrs{logical(s.dev.Key_lock)+1};

        % temperature stuff
        g.TEC.Value = g.TEC.Items{s.dev.TEC+1};
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
        
        % Laser stuff
        LD_tripped = s.dev.LD_protection_tripped.tripped;
        if any(LD_tripped)
            g.LD_prot.Color = lamp_clrs{2};
            g.LD_prot.Tooltip = sprintf('Tripped protection(s): %s', ...
                                        strjoin(s.dev.LD_protection_tripped.name(LD_tripped), ', '));
        elseif strcmpi(g.LD_prot.Color, lamp_clrs{2})
            g.LD_prot.Color = lamp_clrs{1};
            g.LD_prot.Tooltip = 'No protection tripped';
        end
        set_if_neq(g.LD_A_setpoint, s.dev.LD_A_setpoint);
        set_if_neq(g.LD_A_limit, s.dev.LD_A_limit);
        % TODO: g.LD_A_reading.Background = [color_gradient from #00FFFF to #FF0000](LD_A - LDAsp)
        g.LD_A_reading.Text = sprintf('%.4f A', s.dev.LD_A_reading);
        g.LD_V_reading.Text = sprintf('%.4f V', s.dev.LD_V_reading);
        if g.LD.Value ~= (s.dev.LD+1); g.LD.Value = g.LD.Items{s.dev.LD+1}; end

        % Laser modulation stuff
        am_src = s.dev.LD_AM_source == ...
                 [ITC4001Enums.ModulationSource.Internal, ...
                  ITC4001Enums.ModulationSource.External, ...
                  ITC4001Enums.ModulationSource.Both];
        g.LD_AM_src_int.Value = any(am_src([1,3]));
        g.LD_AM_src_int.Value = any(am_src([2,3]));

        am_shape = char(s.dev.LD_AM_shape);
        if am_shape(1) ~= g.LD_AM_shape.Value(1)
            g.LD_AM_shape.Value = am_shape;
        end

        set_if_neq(g.LD_AM_freq, s.dev.LD_AM_frequency);
        set_if_neq(g.LD_AM_depth, s.dev.LD_AM_depth);
        if g.LD_AM.Value ~= (s.dev.LD_AM+1)
            g.LD_AM.Value = g.LD_AM.Items{s.dev.LD_AM+1};
        end
    end
    function set_if_neq(c,v)
        if any(c.Value ~= v); c.Value = v; end
    end

    function update_dd_devs()
        g.uif.Pointer = 'watch';
        devs = ITC4001.list();
        strs = [devs.ResourceName];
        has_alias = ~([devs.Alias] == "");
        if any(has_alias); strs(has_alias) = [devs(has_alias).Alias]; end
        g.dd_devs.Items = strs;
        g.dd_devs.ItemsData = devs;
        g.uif.Pointer = 'arrow';
    end

    %% gui building stuff
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
    function [c1, c2] = gl_range_pair(gl, r, s, fn, varargin)
% like gl_pair but instead of of a single ctrl it makes two with a dash
% inbetween.
%   gl    - grid layout
%   r     - row
%   s     - label string
%   fn    - controls creation function, e.g. @uibutton
% any argument following fn will be pased to fn following gl.
        l = uilabel(gl, 'Text', [s, ':'], 'HorizontalAlignment', 'right', ...
                    'Interpreter', 'html');
        gl_pos(l, r, 1);
        igl = uigridlayout(gl, [1 3], 'ColumnWidth', {'1x', 'fit', '1x'}, ...
                           'ColumnSpacing', 0, 'Padding', 0);
        gl_pos(igl, r, 2);
        c1 = fn(igl, varargin{:});
        gl_pos(c1, 1, 1);
        l = uilabel(igl, 'Text', ' - ', 'HorizontalAlignment', 'center');
        gl_pos(l, 1, 2);
        c2 = fn(igl, varargin{:});
        gl_pos(c2, 1, 3);
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
