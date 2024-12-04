classdef ITC4001 < handle
% see https://se.mathworks.com/help/releases/R2024b/instrument/transition-your-code-to-visadev-interface.html
    properties(Dependent = true, SetAccess = private)
        addr;         % The resource name, aka "visa address"
        serialNumber; % Serial number of the device
        id;           % The complete identification string of the device
    end
    properties(Dependent = true)
        TEC matlab.lang.OnOffSwitchState;  % 
        Laser matlab.lang.OnOffSwitchState;   %
        T_unit ITC4001TemperatureUnit;
        T_setpoint;
        T_reading;
        Laser_A_setpoint;
        Laser_A_reading;
        Laser_V_reading;
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


        function disconnect(o)
% Disconnect from the device.
            delete(o.dev);
        end

        %% implicit methods
        function delete(o)
            o.disconnect();
        end
        function addr = get.addr(o)
            addr = o.dev.ResourceName;
        end
        function serialNumber = get.serialNumber(o)
            serialNumber = o.dev.SerialNumber;
        end
        function id = get.id(o)
            id = o.query('*IDN?');
        end
    end

    methods(Hidden = true)
        function ret = query(o, q)
            ret = writeread(o.dev, q);
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
