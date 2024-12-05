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
    row = row + 1;
    g.dd_devs = uidropdown(gl);
    gl_pos(g.dd_devs, row, [1 2]);

    row = row + 1;
    gl_pos(uibutton(gl, 'Text', 'Refresh devices', ...
                    'ButtonPushedFcn', @(~,~) update_dd_devs()), row, 1);
    gl_pos(uibutton(gl, 'Text', 'Connect', ...
                    'ButtonPushedFcn', @(~,~) connect_dev()), row, 2);
    
    row = row + 1;
    gl_pair(gl, row, 'Key Lock', @uilamp, 'Color', 'red');
    row = row + 1;
    gl_pair(gl, row, 'TEC', @uiswitch, 'slider', 'Orientation', 'horiz');
    row = row + 1;
    gl_pair(gl, row, 'Temperature', @uilabel, 'Text', 'N/A');

%        T_reading (1,1) mustBeNumeric;
        % Current laser current reading
%        Laser_A_reading (1,1) mustBeNumeric;
        % Current laser voltage reading
%        Laser_V_reading (1,1) mustBeNumeric;

    % lastly we update the devs
    update_dd_devs();

    function connect_dev()
        s.dev = ITC4001(dd_devs.Value);

        % TODO
        % - set the min and max limits for the numeric fields!

        s.timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, ...
                        'StartDelay', 0, 'TimerFcn', @(~,~) update_vals());
    end

    function update_vals()
        if s.dev.KeyLock; clr = 'red';
        else; clr = 'green';
        end
        % TODO
        % - values should not be changed if the control has the focus
        g.Key_lock_lamp.Color = clr;
        g.TEC.Value = g.TEC.Items{s.dev.TEC+1};
        g.T_setpoint.Value = s.dev.T_setpoint;
        g.T_reading.Text = sprintf('%g %s', s.dev.T_reading, s.dev.T_unit);
        g.Laser_A_reading.Value = s.dev.Laser_A_reading;
        g.Laser_V_reading.Value = s.dev.Laser_V_reading;
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
