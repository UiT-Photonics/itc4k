classdef ITC4k < handle
% Simple class to make it easier to interact with your ITC4000-series controller
% in constant current mode. Note that this class has ONLY EVERY BEEN TESTED WITH
% AN ITC4001! So if that's what you have you should be safe, otherwise - proceed
% with caution =)
% 
% Example
% ITC4k.gui; % launch the gui and work from there
%
% Examplier example
% o = ITC4k;                  % use the first driver we find
% o.LD_AM_source = 'internal';  % use the internal modulation source
% o.LD_AM_shape = 'sin';        % sinus wave modulation
% o.LD_AM_frequency = 10e3;     % 10 kHz frequncy
% [sp, depth] = o.lims2AM_depth(0.2, 0.4);  % sweep from 0.2 to 0.4 A
% o.LD_A_setpoint = sp;
% o.LD_AM_depth = depth;
% o.TEC = 'on';                 % turn on tec
% pause(10);                    % wait for temp stabilize
% assert(~o.Key_lock, 'You gotta turn the key dummy!');
% o.LD_AM = 'on';               % turn on modulation
% o.LD = 'on';                  % and burn baby burn!
%
% IMPORTANT NOTE
% The modulation calculations only support constant current mode at the moment!
%
% (Developer-ish) Notes
% The properties of this class only abstracts a small fraction of all the SCPI
% commands/properties. This is kind of by design, it's intended to be an easy
% abstraction for the most basic use case; starting turning on the TEC, waiting
% for the temp to stabilize, and turn on the laser. If every possible property
% of a ITC4000 was a dependent property here it wouldn't be much easier than
% just looking up the SCPI commands and doing it "manually". With that said, the
% object has three different hidden methods, o.query(property, varargin),
% o.write(prop, value), and o.query_numeric_bounds(prop). You can check those
% out if you want to subclass or just check some extra props from the command
% line.
%
% TODO
% - temperature protection tripped property
% - LD_W_*-stuff, like LD_A_* but for power
% - make it a better visadev citizen, see
%   https://se.mathworks.com/help/releases/R2024b/instrument/transition-your-code-to-visadev-interface.html
% - Test it with some other ITC4000-series devices to ensure that it works
%   properly
%
% Possible future addons
% - Make it work for LDC4000-series, shold really just be to add another SCPI
%   props-section (and adjust the usage accordingly). or maybe an abstract class
%   that then gets subclassed or something..
% - Maybe also TED4000, that one's missing some stuff tho.

%% read-only properties of the physical device(-ish)
    properties(Dependent = true, SetAccess = private)
% The resource name, aka "visa address"
        addr;
% Serial number of the device
        serialNumber;
% The complete identification string of the device
        id;
% The state of the keylock [OnOffSwitchState]
        Key_lock (1,1) matlab.lang.OnOffSwitchState;
% Temperature reading [ITC4k.T_unit]
        T_reading (1,1) {mustBeNumeric};
% TEC current reading [A]
        TEC_A_reading (1,1) {mustBeNumeric};
% TEC voltage reading [V]
        TEC_V_reading (1,1) {mustBeNumeric};
% Laser current reading [A]
        LD_A_reading (1,1) {mustBeNumeric};
% Laser voltage reading [V]
        LD_V_reading (1,1) {mustBeNumeric};
% LD protection-tripped struct with two fields, name [string] and tripped
% [logical]
        LD_protection_tripped (1,1) struct;
    end
%% read-write properties of the physical device
    properties(Dependent = true)
% Thermoelectric cooler (TEC) state [OnOffSwitchState]
        TEC (1,1) matlab.lang.OnOffSwitchState;
% Unit for temperature readings [ITC4kEnums.TemperatureUnit]
        T_unit (1,1) ITC4kEnums.TemperatureUnit;
% Setpoint for TEC [ITC4k.T_unit]. The limits of this value is available in
% ITC4k.bounds.T_setpoint.
%
% See also
% ITC4k.bounds
        T_setpoint (1,1) {mustBeNumeric};
% Laser state [OnOffSwitchState]
        LD (1,1) matlab.lang.OnOffSwitchState;
% Laser current setpoint [A]. Note that there are two (sets of) limits that 
% control the current for the laser: (1) the fixed limits for the setpoint.
% These are capped at both ends by the ITC4k device itself and is available in
% the ITC4k.bounds.LD_A_setpoint property. (2) The configurable maximum
% current limit which is controlled with the ITC4k.LD_A_limit property and is
% usually set to (slightly below) the highest current your laser can handle. The
% upper and lower bounds that you can set this limit to can be found in
% ITC4k.bounds.LD_A_limit.
% The upper limit for the setpoint value is <= the upper limit for LD_A_limit.
%
% See also
% ITC4k.bounds
        LD_A_setpoint (1,1) {mustBePositive};
% Upper limit for laser current setpoint [A]. Note that there are two (sets of)
% limits that control the current for the laser: (1) the fixed limits for the
% setpoint. These are capped at both ends by the ITC4000 device itself and is
% available in the ITC4k.bounds.LD_A_setpoint property. (2) The configurable
% maximum current limit which is controlled with this property and is usually
% set to (slightly below) the highest current your laser can handle. The upper
% and lower bounds that you can set this limit to can be found in
% ITC4k.bounds.LD_A_limit.
% The upper limit for the setpoint value is <= the upper limit for LD_A_limit.
%
% See also
% ITC4k.bounds
        LD_A_limit (1,1) {mustBePositive};
% Laser amplitude modulation state [OnOffSwitchState]
        LD_AM (1,1) matlab.lang.OnOffSwitchState;
% Laser amplitude modulation source [ITC4kEnums.ModulationSource]
        LD_AM_source (1,1) ITC4kEnums.ModulationSource;
% Internal laser amplitude modulation shape [ITC4kEnums.ModulationShape]
        LD_AM_shape (1,1) ITC4kEnums.ModulationShape;
% Internal laser amplitude modulation frequency [Hz]. The limits of this value
% is available in ITC4k.bounds.LD_AM_frequency.
%
% See also
% ITC4k.bounds
        LD_AM_frequency (1,1) {mustBePositive};
% Internal laser amplitude modulation depth [%]. This property sets the
% modulation peak-to-peak amplitude to its value as a percent of
% ITC4k.bounds.LD_A_limit.max. As an example, if you set the current setpoint
% to 0.04 A, the depth to 3%, and ITC4k.bounds.LD_A_limit.max is 1.01 A
% (common value for the ITC4001) your current output will sweep from 0.0179 A to
% 0.0481 A, i.e. 0.04 + [-0.5 0.5] .* 1.01 * 3*1e-2, or more generally:
% ITC4k.LD_A_setpoint + [-0.5 0.5] .* ITC4k.bounds.LD_A_limit.max * ITC4k.LD_AM_depth*1e-2
% If you know which current range you want to sweep over but do not want to
% calculate the setpoint and depth you can use the ITC4k.lims2AM_depth.
% The limits of this value is available in ITC4k.bounds.LD_AM_depth.
%
% See also
% ITC4k.bounds, ITC4k.LD_A_setpoint, ITC4k.lims2AM_depth
        LD_AM_depth (1,1) {mustBePositive};
    end
    properties(SetAccess = private)
% Array of structs with min and max-values for the following properties
% ITC4k.LD_A_setpoint
% ITC4k.LD_A_limit
% ITC4k.T_setpoint
% ITC4k.LD_AM_frequency
% ITC4k.LD_AM_depth
%
% See also
% ITC4k.LD_A_setpoint, ITC4k.LD_A_limit, ITC4k.T_setpoint,
% ITC4k.LD_AM_frequency, ITC4k.LD_AM_depth
        bounds;
    end
%% VISA props
    % C/Should be extended with all the right protocol settings
    properties(GetAccess = protected, SetAccess = immutable)
        dev; % the VISA device
    end
%% SCPI props/commands/path
    properties(Constant = true, Access = protected)
        pTEC = 'OUTP2';
        pTunit = 'UNIT:TEMP';
        pTsp = 'SOUR2:TEMP';
        pTECAread = 'MEAS:CURR3';
        pTECVread = 'MEAS:VOLT3';
        pTread = 'MEAS:TEMP';
        pLD = 'OUTP1';
        pLDAsp = 'SOUR1:CURR';
        pLDAspLim = 'SOUR1:CURR:LIM';
        pLDAread = 'MEAS:CURR1';
        pLDVread = 'MEAS:VOLT1';
        kLDprot = ["current", "voltage", "external", "internal", ...
                   "interlock", "over_temperature"]; % "keys key"
        mLDprot = 'OUTP1:PROT:'; % meta key
        pLDprot = {[ITC4k.pLDAspLim, ':TRIP'], ...
                   [ITC4k.mLDprot, 'VOLT:TRIP'], ...
                   [ITC4k.mLDprot, 'EXT:TRIP'], ...
                   [ITC4k.mLDprot, 'INT:TRIP'], ...
                   [ITC4k.mLDprot, 'INTL:TRIP'], ...
                   [ITC4k.mLDprot, 'OTEM:TRIP']},
        pKeyLock = [ITC4k.mLDprot, 'KEYL:TRIP'];
        pLDAM = 'SOUR1:AM';
        pLDAMsrc = [ITC4k.pLDAM, ':SOUR'];
        pLDAMshape = [ITC4k.pLDAM, ':INT:SHAP'];
        pLDAMfreq = [ITC4k.pLDAM, ':INT:FREQ'];
        pLDAMdepth = [ITC4k.pLDAM, ':INT:DEPT'];
        pID = '*IDN';
    end
%% full public implementation
    methods
        function o = ITC4k(varargin)
% o = ITC4k(); creates an instances for the first ITC4000-series controller
% that's found. Throws an error if none is found.
%
% devs = ITC4k.list();
% o = ITC4k(devs(1)); creates an instance of the ITC4000 identified by the
% struct supplied.
%
% o = ITC4k("USB0::62700::4119::XXXXXXXXXXXXXX::0::INSTR"); creates an
% instance of the ITC4000 with the provided resource name.
%
% See also
% ITC4k.list, visadevlist
            if nargin == 0
                devs = ITC4k.list();
                assert(~isempty(devs), 'ITC4k:constructor:no_device', ...
                       'No device found.');
                o.dev = visadev(devs(1).ResourceName);
            elseif nargin == 1
                if isstruct(varargin{1})
                    assert(isfield(varargin{1}, 'ResourceName'), ...
                           'ITC4k:constructor:struct:ResourceName_missing', ...
                           'ResourceName field missing from struct argument.');
                    o.dev = visadev(varargin{1}.ResourceName);
                elseif isstring(varargin{1}) || ischar(varargin{1})
                    o.dev = visadev(varargin{1});
                else
                    error('ITC4k:constructor:arg_class', ...
                          'Constructor only accepts a struct or a string as argument.');
                end
                if ~strncmp(o.dev.Model, "ITC40", 5)
                    warning('ITC4k:constructor:scaryboi', ...
                            'This class has only been tested with ITC4001s - hence the name. Proceed with caution or you''ll fry your laser and/or driver..');
                end
            else
                error('ITC4k:constructor:nargin', ...
                      'Constructor only accepts 0 or 1 arguments.');
            end
            o.bounds.LD_A_setpoint = o.query_numeric_bounds(o.pLDAsp);
            o.bounds.LD_A_limit = o.query_numeric_bounds(o.pLDAspLim);
            o.bounds.T_setpoint = o.query_numeric_bounds(o.pTsp);
            o.bounds.LD_AM_frequency = o.query_numeric_bounds(o.pLDAMfreq);
            o.bounds.LD_AM_depth = o.query_numeric_bounds(o.pLDAMdepth);
        end

        function [sp, depth] = lims2AM_depth(o, minA, maxA)
% [sp, depth] = ITC4k.lims2AM_dept(o, minA, maxA) returns the
% ITC4k.LD_A_setpoint value, sp, and ITC4k.LD_AM_depth value, depth,
% required to sweep the laser current from minA to maxA.
%
% Example
% o = ITC4k;
% o.LD_AM_source = ITC4kEnums.ModulationSource.Internal;
% o.LD_AM_shape = ITC4kEnums.ModulationShape.Sinusoid;
% o.LD_AM_frequency = 10e3;
% [sp, depth] = o.lims2AM_depth(0.2, 0.4);
% o.LD_A_setpoint = sp;
% o.LD_AM_depth = depth;
% % this will sweep the laser current from 0.2 A to 0.4 A like a sinus wave at
% % 10 kHZ.
%
% See also
% ITC4k.LD_A_setpoint, ITC4k.LD_AM_depth
            assert(minA < maxA, 'ITC4k:lims2AM_depth:limits:sort', ...
                   'Lower limit (%f) must be less than upper limit (%f)', ...
                   minA, maxA);
            assert(minA >= o.bounds.LD_A_limit.min && ...
                   maxA <= o.bounds.LD_A_limit.max, ...
                   'ITC4k:lims2AM_depth:limits:oob', ...
                   'Provided limits (%f, %f) exceeds device limits (%.4f, %.4f)', ...
                   minA, maxA, o.bounds.LD_A_limit.min, ...
                   o.bounds.LD_A_limit.max);
            p2p = (maxA - minA);
            sp = minA + p2p/2;
            assert(o.bounds.LD_A_setpoint.min <= sp && ...
                   sp <= o.bounds.LD_A_setpoint.max, ...
                   'ITC4k:lims2AM_depth:setpoint:oob', ...
                   'Calculated setpoint (%f) exceeds device limits (%.4f, %.4f)', ...
                   sp, o.bounds.LD_A_setpoint.min, o.bounds.LD_A_setpoint.max);
            depth = 100 * p2p/o.bounds.LD_A_limit.max;
            assert(o.bounds.LD_AM_depth.min <= depth && ...
                   depth <= o.bounds.LD_AM_depth.max, ...
                   'ITC4k:lims2AM_depth:depth:oob', ...
                   'Calculated depth (%f) exceeds device limits (%.1f, %.1f)', ...
                   depth, o.bounds.LD_AM_depth.min, o.bounds.LD_AM_depth.max);
        end

%% Read-write props
        function state = get.TEC(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query(o.pTEC)));
        end
        function set.TEC(o, state)
            o.write(o.pTEC, state);
        end

        function unit = get.T_unit(o)
            unit = ITC4kEnums.TemperatureUnit(o.query(o.pTunit));
        end
        function set.T_unit(o, unit)
            o.write(o.pTunit, unit);
            o.bounds.T_setpoint = o.query_numeric_bounds(o.pTsp);
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

        function state = get.LD_AM(o)
            state = matlab.lang.OnOffSwitchState(str2double(o.query(o.pLDAM)));
        end
        function set.LD_AM(o, state)
            o.write(o.pLDAM, state);
        end
        
        function src = get.LD_AM_source(o)
            res = o.query(o.pLDAMsrc);
            if strcmpi(res,'INT,EXT')
                src = ITC4kEnums.ModulationSource.Both;
            else
                src = ITC4kEnums.ModulationSource(res);
            end
        end
        function set.LD_AM_source(o, src)
            if src == ITC4kEnums.ModulationSource.Both
                o.write(o.pLDAMsrc, 'INT,EXT');
            else
                o.write(o.pLDAMsrc, src);
            end
        end
        
        function shape = get.LD_AM_shape(o)
            shape = ITC4kEnums.ModulationShape(o.query(o.pLDAMshape));
        end
        function set.LD_AM_shape(o, shape)
            o.write(o.pLDAMshape, shape);
        end

        function freq = get.LD_AM_frequency(o)
            freq = str2double(o.query(o.pLDAMfreq));
        end
        function set.LD_AM_frequency(o, freq)
            o.write(o.pLDAMfreq, freq);
        end

        function depth = get.LD_AM_depth(o)
            depth = str2double(o.query(o.pLDAMdepth));
        end
        function set.LD_AM_depth(o, depth)
            o.write(o.pLDAMdepth, depth);
        end

%% Read-only props
        function states = get.LD_protection_tripped(o)
            states = struct('name', o.kLDprot, ...
                            'tripped', false(size(o.kLDprot)));
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

        function A = get.TEC_A_reading(o)
            A = str2double(o.query(o.pTECAread));
        end

        function V = get.TEC_V_reading(o)
            V = str2double(o.query(o.pTECVread));
        end

        function A = get.LD_A_reading(o)
            A = str2double(o.query(o.pLDAread));
        end

        function V = get.LD_V_reading(o)
            V = str2double(o.query(o.pLDVread));
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

%% Internal stuff
    methods(Hidden = true)
        function ret = query(o, prop, varargin)
            ret = strip(writeread(o.dev, [prop, '?', varargin{:}]), 'right');
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
            %[a,b] = visastatus(o.dev) % use to check for errors at some point
        end
        function bounds = query_numeric_bounds(o, prop)
            bounds = struct();
            bounds.min = str2double(o.query(prop, ' MIN'));
            bounds.max = str2double(o.query(prop, ' MAX'));
        end
    end

%% Statics
    methods(Static = true)
        function devs = list()
% devs = ITC4k.list() returns an array with structs identifying all connected
% (and turned on) ITC4000s. One of these can then be passed on to the
% constructor of the class.
            tbl = visadevlist();
            tbl(~strncmpi("ITC40", tbl.Model, 5), :) = [];
            devs = table2struct(tbl);
        end

        % this one's in a separate file
        varargout = gui(varargin);
    end
end
