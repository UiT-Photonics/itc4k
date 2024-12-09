classdef ITC4001 < handle
% TODO:
% - power limits for the laser
% - temperature protection tripped property
%
% see https://se.mathworks.com/help/releases/R2024b/instrument/transition-your-code-to-visadev-interface.html
% see page 41 in programmers manual for sweeps
%
% With setpoint at 330 and modulation depth 2 (%?) it goes from 270 to 390,
% roughly betwen 330 * (1-0.2) to 330 * (1+0.2)
% same but with mod depth 5% it goes from 180 to 479 which is kinda close to
% 330 * (1 - 0.5) to 330 * (1 + 0.5)
%

    %% read-only properties of the physical device
    properties(Dependent = true, SetAccess = private)
% The resource name, aka "visa address"
        addr;
% Serial number of the device
        serialNumber;
% The complete identification string of the device
        id;
% The state of the keylock
        Key_lock (1,1) matlab.lang.OnOffSwitchState;
% Temperature reading
        T_reading (1,1) mustBeNumeric;
% Laser current reading
        LD_A_reading (1,1) mustBeNumeric;
% Laser voltage reading
        LD_V_reading (1,1) mustBeNumeric;
% LD protection-tripped struct with two fields, name and tripped
        LD_protection_tripped (1,1) logical;
    end
    %% read-write properties of the physical device
    properties(Dependent = true)
% State of the thermoelectric cooler (TEC)
        TEC (1,1) matlab.lang.OnOffSwitchState;
% Unit for temperature readings
        T_unit (1,1) ITC4001TemperatureUnit;
% Setpoint for TEC
        T_setpoint (1,1) mustBeNumeric;
% Laser state
        LD matlab.lang.OnOffSwitchState;
% Laser current setpoint. Note that there are two (sets of) limits that control
% the current for the laser: (1) the fixed limits for the setpoint. These are
% capped at both ends by the ITC4001 device itself and is available in the
% ITC4001.bounds.LD_A_setpoint property. (2) The configurable maximum
% current limit which is controlled with the ITC4001.LD_A_limit property and is
% usually set to (slightly below) the highest current your laser can handle. The
% upper and lower bounds that you can set this limit to can be found in
% ITC4001.bounds.LD_A_limit.
% The upper limit for the setpoint value is <= the upper limit for LD_A_limit.
        LD_A_setpoint (1,1) mustBePositive;
% Upper limit for laser current setpoint. Note that there are two (sets of)
% limits that control the current for the laser: (1) the fixed limits for the
% setpoint. These are capped at both ends by the ITC4001 device itself and is
% available in the ITC4001.bounds.LD_A_setpoint property. (2) The configurable
% maximum current limit which is controlled with this property and is usually
% set to (slightly below) the highest current your laser can handle. The upper
% and lower bounds that you can set this limit to can be found in
% ITC4001.bounds.LD_A_limit.
% The upper limit for the setpoint value is <= the upper limit for LD_A_limit.
        LD_A_limit (1,1) mustBePositive;
    end
    properties(SetAccess = immutable)
        bounds;
    end
    %% VISA props
    properties(GetAccess = protected, SetAccess = immutable)
        dev; % the VISA device
    end
    %% SCPI props/commands/path
    properties(Constant = true, Access = protected)
        pTEC = 'OUTP2';
        pTunit = 'UNIT:TEMPerature';
        pTsp = 'SOUR2:TEMP';
        pLD = 'OUTP1';
        pLDAsp = 'SOUR1:CURR';
        pLDAspLim = 'SOUR1:CURR:LIM';
        kLDprot = ["current", "voltage", "external", "internal", ...
                   "interlock", "over_temperature"]; % "keys key"
        mLDprot = 'OUTP1:PROT:'; % meta key
        pLDprot = {[ITC4001.pLDAspLim, ':TRIP'], ...
                   [ITC4001.mLDprot, 'VOLT:TRIP'], ...
                   [ITC4001.mLDprot, 'EXT:TRIP'], ...
                   [ITC4001.mLDprot, 'INT:TRIP'], ...
                   [ITC4001.mLDprot, 'INTL:TRIP'], ...
                   [ITC4001.mLDprot, 'OTEM:TRIP']},
        pKeyLock = [ITC4001.mLDprot, 'KEYL:TRIP'];
        pTread = 'MEAS:TEMP';
        % TODO add the rest
        pID = '*IDN';

        % NOTES FOR POSSIBLE DEVELOPERS
        % this is, of course, faaaar from all of the SCPI commands. the
        % structure of the class isn't really well suited for it either, so i
        % don't plan to add much more features to this class. 
    end
    %% full public implementation
    methods
        function o = ITC4001(varargin)
% o = ITC4001(); creates an instances of the first ITC4001 that's found. Throws
% an error if none is found.
%
% devs = ITC4001.list();
% o = ITC4001(devs(1)); creates an instance of the ITC4001 identified by the
% struct supplied.
%
% o = ITC4001("USB0::62700::4119::XXXXXXXXXXXXXX::0::INSTR"); creates an
% instance of the ITC4001 with the provided resource name.
%
% See also
% ITC4001.list, visadevlist
            if nargin == 0
                devs = ITC4001.list();
                assert(~isempty(devs), 'ITC4001:constructor:no_device', ...
                       'No device found.');
                o.dev = visadev(devs(1).ResourceName);
            elseif nargin == 1
                if isstruct(varargin{1})
                    assert(isfield(varargin{1}, 'ResourceName'), ...
                           'ITC4001:constructor:struct:ResourceName_missing', ...
                           'ResourceName field missing from struct argument.');
                    o.dev = visadev(varargin{1}.ResourceName);
                elseif isstring(varargin{1}) || ischar(varargin{1})
                    o.dev = visadev(varargin{1});
                else
                error('ITC4001:constructor:arg_class', ...
                      'Constructor only accepts a struct or a string as argument.');
                end
            else
                error('ITC4001:constructor:nargin', ...
                      'Constructor only accepts 0 or 1 arguments.');
            end
            o.bounds.LD_A_setpoint = o.query_numeric_bounds(o.pLDAsp);
            o.bounds.LD_A_limit = o.query_numeric_bounds(o.pLDAspLim);
            o.bounds.T_setpoint = o.query_numeric_bounds(o.pTsp);
        end
%% Read-write props
        function state = get.TEC(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query(o.pTEC)));
        end
        function set.TEC(o, state)
            o.write(o.pTEC, state);
        end

        function unit = get.T_unit(o)
            unit = ITC4001TemperatureUnit(o.query(o.pTunit));
        end
        function set.T_unit(o, unit)
            o.write(o.pTunit, unit);
        end

        function T = get.T_setpoint(o)
            T = str2double(o.query(o.pTsp));
        end
        function set.T_setpoint(o, T)
            o.write(o.pTsp, T)
        end

        function state = get.LD(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query(o.pLD)));
        end
        function set.LD(o, state)
            o.write(o.pLD, state);
        end

        function A = get.LD_A_setpoint(o)
            A = str2double(o.query(o.pLDAsp));
        end
        function set.LD_A_setpoint(o, A)
            o.write(o.pLDAsp, A);
        end

        function A = get.LD_A_limit(o)
            A = str2double(o.query(o.pLDAspLim));
        end
        function set.LD_A_limit(o, A)
            o.write(o.pLDAspLim, A);
        end

%% Read-only props
        function states = get.LD_protection_tripped(o)
            states = struct('name', o.kLDprot, ...
                            'tripped', logical(size(o.kLDprot)));
            for i = 1:numel(states.tripped)
                states.tripped(i) = str2double(o.query(o.pLDprot{i}));
            end
        end

        function state = get.Key_lock(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query(o.pKeyLock)));
        end

        function T = get.T_reading(o)
            T = str2double(o.query(o.pTread));
        end

        function A = get.LD_A_reading(o)
            A = str2double(o.query(''));
        end

        function V = get.LD_V_reading(o)
            V = str2double(o.query(''));
        end

        % props with different names than on device
        function addr = get.addr(o)
            addr = o.dev.ResourceName;
        end

        function serialNumber = get.serialNumber(o)
            serialNumber = o.dev.SerialNumber;
        end

        function id = get.id(o)
            id = o.query(o.pID);
        end

        function disconnect(o)
% Disconnect from the device.
            delete(o.dev);
        end

        % handle subclass destructor
        function delete(o)
            o.disconnect();
        end
    end

    methods(Hidden = true)
        function ret = query(o, prop, varargin)
            tic();
            fprintf('%s ', prop); % TODO find out what is taking so long!!
            ret = strip(writeread(o.dev, [prop, '?', varargin{:}]), 'right');
            toc()
        end
        function write(o, prop, v)
            if islogical(v)
                tf = '01';
                v = tf(v+1);
            elseif isnumeric(v)
                v = sprintf('%f', v);
            elseif ~ischar(v)
                v = char(v);
            end
            writeline(o.dev, [prop, ' ', v]);
            %[a,b] = visastatus(o.dev) % use to check for errors
        end
        function bounds = query_numeric_bounds(o, prop)
            bounds = struct();
            bounds.min = str2double(o.query(prop, ' MIN'));
            bounds.max = str2double(o.query(prop, ' MAX'));
        end
    end

    methods(Static = true)
        % this one's in a separate file
        uip = gui();

        function devs = list()
% devs = ITC4001.list() returns an array with structs identifying all connected
% (and turned on) ITC4001s. One of these can then be passed on to the
% constructor of the class.
            tbl = visadevlist();
            tbl(~strcmpi("ITC4001", tbl.Model), :) = [];
            devs = table2struct(tbl);
        end
    end
end
