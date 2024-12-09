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
    g = struct('dd_devs', []);

    if nargin == 0
        parent = uifigure('Name', 'HITRAN toolbox');
        uip = uipanel(parent, 'Title', 'ITC4001 Control', 'Units', 'norm', ...
                      'Position', [0 0 1 1]);
    elseif nargin == 1
        parent = varargin{1};
        %uif = ancestor(parent, 'matlab.ui.Figure');
        uip = uipanel(parent, 'Title', 'ITC4001 Control');
    else
        error('ITC4001:gui:nargin', ...
              'ITC4001.gui only accepts 0 or 1 arguments.');
    end

    n_rows = 5;
    row = 0;
    gl = uigridlayout(uip, [n_rows 2], 'ColumnWidth', {100, '1x'}, ...
                      'RowHeight', 'fit');
    % device selection section
    row = row + 1;
    g.dd_devs = uidropdown(gl);
    gl_pos(g.dd_devs, row, [1 2]);

    row = row + 1;
    gl_pos(uibutton(gl, 'Text', 'Refresh devices', ...
                    'ButtonPushedFcn', @(~,~) update_dd_devs()), row, 1);
    gl_pos(uibutton(gl, 'Text', 'Connect', ...
                    'ButtonPushedFcn', @(~,~) connect_dev()), row, 2);
    % keylock included in device selection
    row = row + 1;
    g.Key_lock = gl_pair(gl, row, 'Key Lock', @uilamp, 'Color', 'red');

    % temperature section
    row = row + 1;
    gl_pos(uilabel('Text', 'TEC Control', 'FontWeight', 'bold'), row, [1 2]);
    row = row + 1;
    g.TEC = gl_pair(gl, row, 'TEC', @uiswitch, 'slider', ...
                    'Orientation', 'horiz');
    row = row + 1;
    g.T_setpoint = gl_pair(gl, row, 'T setpoint', @uieditfield, ...
                           'style', 'numeric');
    row = row + 1;
    g.T_reading = gl_pair(gl, row, 'T reading', @uilabel, 'Text', 'N/A');
    row = row + 1;
    g.T_unit = gl_pair(gl, row, 'T unit', @dropdown, ...
                       'Items', enumeration('ITC4001TemperatureUnit'));

    % Laser section
    row = row + 1;
    gl_pos(uilabel('Text', 'Laser Control', 'FontWeight', 'bold'), row, [1 2]);
    row = row + 1;
    g.LD_prot = gl_pair(gl, row, 'Protection tripped', @uilamp, ...
                        'Color', 'green');
    row = row + 1;
    g.LD = gl_pair(gl, row, 'LD', @uiswitch, 'slider', ...
                   'Orientation', 'horiz');
    row = row + 1;
    g.LD_A_setpoint = gl_pair(gl, row, 'Current setpoint', @uilabel, ...
                              'style', 'numeric');
    row = row + 1;
    g.LD_A_setpoint_limit = gl_pair(gl, row, 'Current limit', @uilabel, ...
                                    'style', 'numeric');
    row = row + 1;
    g.LD_A_reading = gl_pair(gl, row, 'Current reading', @uilabel, ...
                             'Text', 'N/A');
    row = row + 1;
    g.LD_V_reading = gl_pair(gl, row, 'Voltage reading', @uilabel, ...
                             'Text', 'N/A');

    % lastly we update the devs
    update_dd_devs();

    function connect_dev()
        s.dev = ITC4001(dd_devs.Value);

        % set the min and max limits for the numeric fields
        set_numfield_lims(g.T_setpoint, s.dev.bounds.T_setpoint.min, ...
                          s.dev.bounds.T_setpoint.max);
        set_numfield_lims(g.LD_A_setpoint, s.dev.bounds.LD_A_setpoint.min, ...
                          s.dev.bounds.LD_A_setpoint.max);
        set_numfield_lims(g.LD_A_setpoint_limit, ...
                          s.dev.LD_A_setpoint_limit.min, ...
                          s.dev.LD_A_setpoint_limit.max);

        s.timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, ...
                        'StartDelay', 0, 'TimerFcn', @(~,~) update_vals());
    end
    function set_numfield_lims(f, lmin, lmax)
        f.Limits = [lmin lmax];
        f.Tooltip = sprintf('%.4f - %.4f', lmin, lmax);
        f.Placeholder = f.Tooltip;
    end

    function update_vals()
        lamp_clrs = {'green', 'red'};
        % TODO
        % - values should not be set if the control has the focus
        g.Key_lock.Color = lamp_clrs{logical(s.dev.Key_lock)+1};

        % temperature stuff
        g.TEC.Value = g.TEC.Items{s.dev.TEC+1};
        Tsp = s.dev.T_setpoint;
        g.T_setpoint.Value = Tsp;
        % TODO: g.T_reading.Background = [color_gradient from #00FFFF to #FF0000](T - Tsp)
        g.T_reading.Text = sprintf('%g', s.dev.T_reading);
        
        % Laser stuff
        g.LD_prot.Color = lamp_clrs{any(s.dev.LD_protection_tripped.tripped)+1};
        g.LD.Value = g.LD.Items{s.dev.LD+1};
        LDAsp = s.dev.LD_A_setpoint;
        g.LD_A_setpoint.Value = LDAsp;
        % TODO: g.LD_A_reading.Background = [color_gradient from #00FFFF to #FF0000](LD_A - LDAsp)
        g.LD_A_reading.Text = sprintf('%g', s.dev.LD_A_reading);
        g.LD_V_reading.Text = sprintf('%g', s.dev.LD_V_reading);
    end

    function update_dd_devs()
        devs = ITC4001.list();
        strs = [devs.ResourceName];
        has_alias = ~([devs.Alias] == "");
        if any(has_alias); strs(has_alias) = [devs(has_alias).Alias]; end
        g.dd_devs.Items = strs;
        g.dd_devs.ItemsData = devs;
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
    function gl_pos(e, r, c)
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
