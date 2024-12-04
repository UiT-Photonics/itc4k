classdef ITC4001 < handle
% see https://se.mathworks.com/help/releases/R2024b/instrument/transition-your-code-to-visadev-interface.html
% see page 41 in programmers manual for sweeps
%
% With setpoint at 330 and modulation depth 2 (%?) it goes from 270 to 390,
% roughly betwen 330 * (1-0.2) to 330 * (1+0.2)
% same but with mod depth 5% it goes from 180 to 479 which is kinda close to
% 330 * (1 - 0.5) to 330 * (1 + 0.5)
%
    properties(Dependent = true, SetAccess = private)
        % The resource name, aka "visa address"
        addr;
        % Serial number of the device
        serialNumber;
        % The complete identification string of the device
        id;
        % The state of the keylock
        Key_lock (1,1) matlab.lang.OnOffSwitchState;
        % Current temperature reading
        T_reading (1,1) mustBeNumeric;
        % Current laser current reading
        Laser_A_reading (1,1) mustBeNumeric;
        % Current laser voltage reading
        Laser_V_reading (1,1) mustBeNumeric;
    end
    properties(Dependent = true)
        % State of the thermoelectric cooler (TEC)
        TEC (1,1) matlab.lang.OnOffSwitchState;
        % Unit for temperature readings
        T_unit (1,1) ITC4001TemperatureUnit;
        % Setpoint for TEC
        T_setpoint (1,1) mustBeNumeric;
        % Laser state
        Laser matlab.lang.OnOffSwitchState;
        % Laser current setpoint
        Laser_A_setpoint (1,1) mustBePositive;
    end
    properties(GetAccess = protected, SetAccess = immutable)
        dev; % the VISA device
    end
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
        end
%% Read-write props
        function state = get.TEC(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query('OUTP2?')));
        end
        function set.TEC(o, state)
            % TODO
        end

        function unit = get.T_unit(o)
            unit = ITC4001TemperatureUnit(o.query('UNIT:TEMPerature?'));
        end
        function set.T_unit(o, unit)
            o.write(['UNIT:TEMPerature ', char(unit)]);
        end

        function T = get.T_setpoint(o)
            T = str2double(o.query('SOUR2:TEMP?'));
        end
        function set.T_setpoint(o, T)
            % TODO
        end

        function state = get.Laser(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query('OUTP1?')));
        end
        function set.Laser(o, state)
            % TODO
        end

        function A = get.Laser_A_setpoint(o)
            A = str2double(o.query(''));
        end

        function set.Laser_A_setpoint(o, A)
            % TODO
        end

%% Read-only props
        function state = get.Key_lock(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query('OUTP:PROT:KEYL:TRIP?')));
        end

        function T = get.T_reading(o)
            T = str2double(o.query('MEAS:TEMP?'));
        end

        function A = get.Laser_A_reading(o)
            A = str2double(o.query(''));
        end

        function V = get.Laser_V_reading(o)
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
            id = o.query('*IDN?');
        end

        function disconnect(o)
% Disconnect from the device.
            delete(o.dev);
        end

        %% implicit methods
        function delete(o)
            o.disconnect();
        end
    end

    methods(Hidden = true)
        function ret = query(o, q)
            ret = strip(writeread(o.dev, q), 'right');
        end
        function write(o, q)
            writeline(o.dev, q);
            %[a,b] = visastatus(o.dev) % use to check for errors
        end
    end

    methods(Static = true)
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
