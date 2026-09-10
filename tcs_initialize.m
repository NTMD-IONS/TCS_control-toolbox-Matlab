% Functions to control TCS device.
% Class "tcs_initialize" inherits methods and properties 
% from the Class "serial_manager".
%
% See README for use instructions.
%
% As precision of the device is 0.1 °C, commands dealing with 1/100°C are
% currently not included.
% 
% Created with MATLAB (R2024a) with Psychtoolbox (3-3.0.19.7) on Windows 11 (25H2).
% Compatible with MATLAB 219b or later.
% Author : Cédric Lenoir, Neuroscience Techniques and Methods Developement Platform (NeTMeD),
% Email : cedric.lenoir@uclouvain.be
% Institute of Neuroscience (IoNS), UCLouvain, Brussels, Belgium.
% Copyright (c) 2026 Université catholique de Louvain (UCLouvain)
% Licensed under the GNU GPLv3 License. See LICENSE file for details.
% Version 1.0.0, August 2026.//

classdef tcs_initialize < serial_manager

    properties
        probe_serial_no = "";
        probe_type = "";
        firmware_short = "";
        test_reset = "";
        battery_level = "";
        filter_level = "";
        wait_duration = "";
        temperature_feedback_state = "";
    end

    methods

        function obj = tcs_initialize(portName)
            % obj = tcs_initialize(portName); (portName is optional). 
            % The constructor automatically finds the COM port and creates the object.
            % It initializes the serial communication and gets the user/computer information,
            % as well as settings, software and hardware informations about the TCS and probe.
            % It saves all informations in a log .txt file. Initialization takes approximately
            % 10 seconds. In addition, the initialization requires the user to confirm 
            % that the stimulation rate does not exceed 1 Hz. This stimulation rate is the
            % maximum advised by QST.Lab to avoid damaging the probe. 
            disp(' ');
            disp("WARNING! STIMULATION RATE MUST NOT EXCEED 1 Hz." + newline + "To confirm & continue, press any key.");
            disp(' ');
            pause();
            disp('Initialize serial communication...');
            if nargin < 1
                portName = "";
            end
            obj@serial_manager(portName);
            pause(0.001);
            disp('Getting settings and creating log file...');
            obj.reset;
            % Creates a log file summarizing software and hardware details
            timestamp = char(replace(string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),{':',' '},'-'));
            log_filename = strcat(['log_TCS_initialize_',timestamp,'.txt']);
            user_name = char(java.lang.System.getProperty('user.name'));
            pc_name = char(java.net.InetAddress.getLocalHost().getHostName());
            obj.get_battery;
            pause(0.001);
            obj.get_mri_filter;
            pause(0.001);
            v = obj.get_library_version;
            pause(0.001);
            obj.get_error;
            fidLog = fopen(log_filename,'w');
            fprintf(fidLog,...
                '# User settings: \n\nDate and time: %s \nUser: %s \nComputer: %s %s \n\nToolbox version: %s\n\n\n# TCS settings: %s \n\nBattery levels: %s \n\nMRI filter level: %s \n',...
                timestamp, user_name, computer, pc_name, v, obj.test_reset, obj.battery_level, obj.filter_level);
            fclose(fidLog);
            disp('Serial communication initialized.')
        end


        % ── Get info from TCS device ─────────────────────────────────────

        function get_probe(obj)
            % obj.get_probe;
            % Gets probe type and serial number, the output: probe_serial_no
            % and probe_type are shared properties.
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('H');
            TCS_help = obj.receive;
            if isempty(TCS_help)
                warning('No response from TCS device.');
                return;
            end
            idx_ID = regexpi(TCS_help, 'ID');
            idx_TYPE = regexpi(TCS_help, 'TYPE');
            obj.probe_serial_no = TCS_help(idx_ID + 4 : idx_ID + 26);
            obj.probe_type = TCS_help(idx_TYPE + 6 : idx_TYPE + 8);
            obj.flush;
            if obj.verbosity == 1
                disp("Probe serial no. : " + obj.probe_serial_no);
                disp("Probe type : " + obj.probe_type);
            end
        end

        function get_tcs_version(obj)
            % obj.get_version; 
            % Gets TCS device firmware version, the output: firmware_short
            % is a shared property.
            obj.mute_temperature_display
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('H');
            TCS_help = obj.receive;
            if isempty(TCS_help)
                warning('No response from TCS device.');
                return;
            end
            idx_FW = regexpi(TCS_help, 'Firmware');
            obj.firmware_short = TCS_help(idx_FW + 10 : idx_FW + 33);
            obj.flush;
            if obj.verbosity == 1
                disp("Firmware version : " + obj.firmware_short);
            end
        end

        function get_battery(obj)
            % obj.get_battery;
            % Gets battery level, the output: battery_level is a shared 
            % property containing voltage and % of charge.
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('B');
            str = obj.receive;
            if isempty(str)
                warning('No response from TCS device.');
                obj.battery_level = NaN;
                return;
            end
            obj.battery_level = str;
            if obj.verbosity == 1
                disp("Battery: " + str);
            else
            end
        end

        function get_error(obj)
            % obj.get_error;
            % Gets the error state of the TCS device, for each zone of the
            % probe, the output error is a shared property.
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('Q');
            pause(0.001);
            error_state = obj.receive;
            if obj.verbosity == 1
                disp(error_state);
            else
            end
        end

        function get_mri_filter(obj)
            % obj.get_mri_filter;
            % Gets MRI filter level, the output filter_level is a shared
            % property. (Changing the filter level might affect heating and
            % cooling speeds)
            obj.flush;
            obj.send('Ofg');
            pause(0.001);
            filter = obj.receive;
            obj.filter_level = filter;
            if obj.verbosity == 1
                switch filter
                    case '1'
                        disp(' ');
                        disp(['MRI filter strength is low (',filter,')']);
                        disp('Check the maximum heating/cooling ramps !');
                    case '2'
                        disp(' ');
                        disp(['MRI filter strength is medium (',filter,')']);
                        disp('Check the maximum heating/cooling ramps !');
                    case '3'
                        disp(' ');
                        disp(['MRI filter strength is high (',filter,')']);
                        disp('Check the maximum heating/cooling ramps !');
                end
            end
        end

        function param = get_stimulation_profile(obj)
            % param = obj.get_stimulation_profile;
            % Displays stimulation parameters defined in the profile mode for
            % each zone. (Use get_stimulation_param for stimulation
            % parameters defined based on duration and speeds.)
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('Ur');
            pause(0.001);
            param = obj.receive;
            % formats the output for readability
            idx = regexp(param,' 1 ');
            for izone = 1:size(idx,2)
                zones{izone} = param(idx(izone)-1:idx(izone)-1);
                segs{izone} = param(idx(izone)+3:idx(izone)+5);
                profils{izone} = param(idx(izone)+7:idx(izone)+7+(str2double(segs{1})*7)+1);
                profils{izone} = regexprep(profils{izone},'\D','');
                for iseg = 1:str2double(segs{1})
                    dur_temp{izone,iseg} = ['seg' num2str(iseg) ': ' profils{izone}((1:3)+(6*(iseg-1))) 'x10ms to ' profils{izone}((4:6)+(6*(iseg-1))) 'x0.1°C; '];
                end
            disp(['zone-' zones{izone} ': ' dur_temp{izone,1:end}]);
            end
        end

        % Function to get MRI parameters (not included yet)
        % 'OiI' to program IRM room extension cable
        % 'OiC' to program control room extension cable
        % 'Oim' to measure temperature of extension cable
        % 'Oit' to display temperature of extension cable

        function param = get_stimulation_param(obj)
            % param = obj.get_stimulation_param;
            % Gets stimulation parameters for stimulation defined based on
            % the temporal parameters: ramp_TN2T, ramp_T2TN and duration.
            % (Use get_stimulation_profile for stimulation parameters
            % defined in profile mode)
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('P');
            pause(0.001);
            param = obj.receive;
        end

        function v = get_library_version(obj)
            % v = obj.get_library_version;
            % Displays the docstring of the library Class and its version.
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            v = help('tcs_initialize');
            idx_v = strfind(v, './/');
            v = v(1:idx_v);
            if obj.verbosity == 1
                disp(v);
            end
        end

        function str = get_serial_command_list(obj)
            % str = obj.get_serial_command_list;
            % Displays serial commands list and help defined by QST.Lab.
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('H');
            str = obj.receive;
            if isempty(str)
                warning('No response from TCS device.');
                return
            end
            disp(str);
        end

        function timedate = get_time_date(obj)
            % timedate = obj.get_time_date;
            % Displays the time and date from the TCS device.
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('Xr');
            pause(0.100);
            timedate = obj.receive;
            pause(0.100);
            % TCS response can be slow if timedate is incomplete, redo
            if size(timedate,1) < 13
                obj.send('Xr');
                pause(0.100);
                timedate = obj.receive;
                pause(0.100);
            else
            end
            % formats and displays
            timedate = sprintf('%s:%s:%s %s-%s-%s', timedate(2:3), timedate(4:5),...
                timedate(6:7), timedate(8:9), timedate(10:11), timedate(12:13));
            disp(timedate);
        end

        % ── Configure TCS device ─────────────────────────────────────────

        function reset(obj)
            % obj.reset;
            % Resets TCS device, takes 10 s, outputs settings and the
            % automatic diagnostic test results, this output is a shared
            % property used for the log text file during initialization.
            obj.mute_temperature_display();
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('Oc');
            pause(10);
            obj.test_reset = obj.receive;
            obj.flush;
            if obj.verbosity == 1
                disp(obj.test_reset);
            end
        end

        function set_verbosity(obj,level)
            % obj.set_verbosity(level);
            % Sets verbosity level for commands output
            %   0 : no device responses displayed
            %   1 : output command messages.
            if level < 0 || level > 1
                error('Verbosity level is 0 or 1.')
            end
            obj.verbosity = level;
        end
  
        function set_stimulation_param(obj, zones, TN, T, duration, ramp_TN2T, ramp_T2TN, feedback_state)
            % obj.set_stimulation_param(zones, TN, T, duration, ramp_TN2T, ramp_T2TN, feedback_state);
            % Sets stimulations parameters. Disables profile mode, and sets
            % active zones, baseline and target temperatures, duration and
            % thermal speeds, and if temeprature feedback is requested.
            % (It creates a property "wait_duration" later used in get_stimulation_feedback.)
            % Its also automatically enable temperature feedback if
            % feedback_state is true.
            % Input :
            %   zones 0:inactive/1:active (i.e.,11111 for 5 zones by default);
            %   TN (neutral temperature in °C [20 - 40]); duration (in ms [00001 - 99999]);
            %   ramp_TN2T (speed of temperature change from neutral temperature (TN)
            %   to target temperature (T) in °C/s (see probe limits)
            %   ramp_T2TN (speed of temperature change from target temperature (T)
            %   to neutral temperature (TN) in °C/s (see probe limits)
            %   feedback_state : 0 (no feedback); 1 (feedback during stimulation)
            % (It ouputs the plateau time = duration minus the time to reach
            % the target temperature.).
            % WARNING! the settings are applied on the "activated zones" using:
            % obj.set_active_zones(zones); if different parameters have to
            % be applied on different zones, call again:
            % obj.set_active_zones(zones); and specify the new zones and
            % keep the previous zones "activated" (to "1").

            % defines a wait period + safety maring of 50 ms, before
            % sending command to get temperature feedback
            % computes the ramp_T2TN time
            timeT2TN = abs(T-TN)/ramp_T2TN;
            obj.wait_duration = duration/1000 + timeT2TN + 0.05;
            % Adjusts temperature feedback duration if feedback requested
            if feedback_state == true
                obj.temperature_feedback_state = true;
                obj.enable_temperature_feedback(100);
                pause(0.001);
                obj.send(obj.format_xxxx_command('Yxxxx', (obj.wait_duration)*100, [0 9999]));
                pause(0.001);
            else
            end
            if nargin < 7
                disp('Not enough arguments');
                disp('Please provide: zones, baseline and target temperatures, duration (rise time + plateau) and thermal ramps');
                return;
            end
            if obj.verbosity == 1
                disp("Plateau time: " + (duration - abs(T-TN)*1000/ramp_TN2T) + " ms");
            end
            % disables profile mode
            obj.set_profile_zones(00000);
            pause(0.001);
            % sets neutral temperature
            obj.send(['N' obj.format_xxxx_string(TN*10, 3, [200 400])]); pause(0.001);
            % sets target temperature
            indiv_zone = regexp(sprintf('%05d', zones),'1');
            for izone = 1:size(indiv_zone,2)
                obj.send(['C' num2str(indiv_zone(1,izone)) obj.format_xxxx_string(T*10, 3, [100 700])]); pause(0.001);
                % sets duration (rise time + plateau)
                obj.send(['D' num2str(indiv_zone(1,izone)) obj.format_xxxx_string(duration, 5, [1 99999])]); pause(0.001);
                % sets ramp_TN2T
                obj.send(['V' num2str(indiv_zone(1,izone)) obj.format_xxxx_string(ramp_TN2T*10, 4, [1 9999])]); pause(0.001);
                % sets ramp_T2TN
                obj.send(['R' num2str(indiv_zone(1,izone)) obj.format_xxxx_string(ramp_T2TN*10, 4, [1 9999])]); pause(0.001);
            end
        end

        function set_neutral_temperature(obj, TN)
            % obj.set_neutral_temperature(TN);
            % Sets only neutral / baseline temperature in °C ranging in
            % [20 to 40] °C.
            obj.send(['N' obj.format_xxxx_string(TN*10, 3, [200 400])]);
        end

        function set_max_temperature(obj, Tmax)
            % obj.set_max_temperature(Tmax);
            % Sets maximum limit temperature in °C up to 70°C.
            obj.send('Ox70'); pause(0.001); % hidden command
            % sets the maximum target temperature
            obj.send(['Om' obj.format_xxxx_string(Tmax*10,3,[100 700])]);
        end

        function set_stimulation_temperature(obj, T)
            % obj.set_stimulation_temperature(T);
            % Sets only the stimulation / target temperature between
            % [10 - 70] °C.
            obj.set_profile_zones(00000);
            pause(0.001);
            indiv_zone = regexp(sprintf('%05d', zones),'1');
            for izone = 1:size(indiv_zone,2)
            obj.send(['C' num2str(indiv_zone(izone)) obj.format_xxxx_string(T*10, 3, [100 700])]);
            pause(0.001);
            end
        end

        function set_stimulation_duration_speed(obj, zones, duration, ramp_TN2T, ramp_T2TN, feedback_state)
            % obj.set_stimulation_duration_speed(zones, duration, ramp_TN2T, ramp_T2TN, feedback_state);
            % Sets only stimulation temporal parameters (duration: rise time + plateau, in ms
            % and thermal speeds in °C/s, and if temeparture feedback is requested).
            % feedback_state : 0 (no feedback); 1 (feedback during stimulation).
            % Its also automatically enable temperature feedback if
            % feedback_state is true.
            % (It ouputs the plateau time based on the remaining time =
            % duration minus time to reach the target temperature.).
            % WARNING! the settings are applied on the "activated zones" using:
            % obj.set_active_zones(zones); if different parameters have to
            % be delivered on different zones, call again obj.set_active_zones(zones);
            % and specify the new zones and keep the previous zones activated (to "1").

            % (delay + safety margin of 50 ms to wait before asking for feedback)
            timeT2TN = abs(T-TN)/ramp_T2TN;
            obj.wait_duration = duration/1000 + timeT2TN + 0.05;
            if feedback_state == true
                obj.temperature_feedback_state = true;
                obj.enable_temperature_feedback(100);
                pause(0.001);
                obj.send(obj.format_xxxx_command('Yxxxx', (obj.wait_duration)*100, [0 9999]));
                pause(0.001);
            else
            end
            % disables profile mode
            obj.set_profile_zones(00000);
            pause(0.001);
            indiv_zone = regexp(sprintf('%05d', zones),'1');
            for izone = 1:size(indiv_zone,2)
                obj.send(['D' num2str(indiv_zone(izone)) obj.format_xxxx_string(duration, 5, [1 99999])]);
                pause(0.001);
                if nargin == 4
                    obj.send(['V' num2str(indiv_zone(izone)) obj.format_xxxx_string(round(ramp_TN2T*10), 4, [1 9999])]);
                    pause(0.001);
                end
                if nargin == 5
                    obj.send(['R' num2str(indiv_zone(izone)) obj.format_xxxx_string(round(ramp_T2TN*10), 4, [1 9999])]);
                    pause(0.001);
                end
            end
        end

        function set_profile_zones(obj, zones)
            % obj.set_profile_zones(zones);
            % Activates or deactivates the profile mode for the specified
            % probe zones, "zones" is a 5-digit vector of 0s and 1s.
            % (0 to deactivate, 1 to activate).
            cmd_temp = obj.format_xxxx_command('Uexxxxx', zones, [0 11111]);
            obj.send(cmd_temp);
        end

        function set_stimulation_profile(obj, zones, num_seg, seg_duration, seg_end_temp, feedback_state)
            % obj.set_stimulation_profile(zones, num_seg, seg_duration, seg_end_temp, feedback_state);
            % Sets stimulation parameters in profile mode.
            % input : zones (11111); num_seg : total number of segments;
            % seg_duration: list of segment durations in 10x ms; seg_end_temp: list
            % of temperatures at the end of each segment in °C). To request
            % temperature feedback during stimulation set "feedback_state"
            % to "0" (no feedback) or "1" (feedback during stimulation).
            % Its also automatically enable temperature feedback if
            % feedback_state is true.
            % WARNING! before setting the stimulation profile, activate the
            % zones from which the profile should be delivered using:
            % obj.set_zones_profile(zones); if a different profile has to
            % be delivered on different zones, call again obj.set_zones_profile(zones);
            % and specify the new zones and keep the previous zonesactivated (to "1").

            % (delay + safety margin of 50 ms to wait before asking for feedback)
            obj.wait_duration = sum(seg_duration/1000) + 0.05;
            if feedback_state == true
                obj.temperature_feedback_state = true;
                obj.enable_temperature_feedback(100);
                pause(0.001);
                obj.send(obj.format_xxxx_command('Yxxxx', (obj.wait_duration)*100, [0 9999]));
                pause(0.001);
            else
            end
            % check if there are enough parameters for the number of segments
            if size(seg_duration,2) ~= num_seg || size(seg_end_temp,2) ~= num_seg
                error('Mismatch between number of segments and number of durations and temperatures!')
            else
            end
            % check if segment durations are at 10x ms precision
            if ~all(mod(seg_duration,10) == 0)
                error('Segment durations should be at 10x ms precision !')
            else
            end
            if nargin < 5
                disp('Missing arguments !');
                disp('you must provide : zones + number of segments + list of segment durations (ms) + list of temperatures at end of segments (°C)');
                return
            else
                pause(0.001);
                str1 = obj.format_xxxx_command('Uwxxxxx',zones,[0 11111]);
                str2 = obj.format_xxxx_string(num_seg,3);
                for seg = 1:num_seg
                    temp_str3{seg} = [obj.format_xxxx_string((seg_duration(seg))/10,3) obj.format_xxxx_string(round(seg_end_temp(seg)*10),3)];
                end
                str3 = [temp_str3{:}];
                Uw_cmd = [str1 str2 str3];
                pause(0.001);
                obj.send(Uw_cmd);
            end
        end

        function disable_temperature_feedback(obj)
            % obj.disable_temperature_feedback;
            % Disables temperature feedback between and during stimulations
            % (mute mode).
            obj.send('F');
            obj.temperature_feedback_state = false;
        end

        function enable_temperature_feedback(obj,freq)
            % obj.enable_temperature_feedback(freq);
            % Enables temperature feedback between or during stimulations.
            % If the frequency "freq" is "1" then the feedback is activated 
            % between stimulation as it is by default; if "freq" is 100 Hz,
            % then feedback is activated during stimulation.
            if freq == 1
                obj.send('Oa');
                obj.temperature_feedback_state = false;
            elseif freq == 100
                obj.send('Ob');
                obj.temperature_feedback_state = true;
            else
                error('Frequency of feedback should be 1 or 100 (Hz).')
            end
        end

        function set_active_zones(obj, zones)
            % obj.set_active_zones;
            % Sets active zones of the probe : "1" to activate, "0" to
            % deactivate(e.g., 10001 to activate zones 1 and 5). If the probe
            % has less than 5 zones, indicate the state of the zones followed
            % by zeros (e.g., probe has 3 zones, to activate the 3 zones : 11100).
            % Only "0" and "1" are tolerated.

            % Check is zones is only zeros and ones
            if ~isempty(regexp(num2str(zones), '^[01]+$', 'once'))
                if ischar(zones) && strcmpi(zones, 'all')
                    zones = 11111;
                end
                obj.set_profile_zones(00000);
            else
                error('input for each zone should be "0" or "1".')
            end
            pause(0.001);
            cmd_temp = obj.format_xxxx_command('Sxxxxx', zones, [0 11111]);
            obj.send(cmd_temp);
        end

        function set_trigger_out(obj,n,duration)
            % obj.set_trigger_out(n,duration);
            % Sets the parameters for trigger out, if using QST.Lab cable the
            % trigger code "n" must be 1 (or 255). Trigger out is 10 ms delayed.
            % If duration is not specified, duration is 10 ms default.
            % Duration is between [10 - 999] ms.
            if nargin == 1
                error('Missing argument: you must provide a number between 1 and 255')
            elseif nargin == 2
                duration = 10; % keep default duration of 10 ms
            end
            % Builds Command String "Txxxyyy" : with trigger code : xxx [1 - 255],
            % and duration yyy between [10 - 999] ms).
            xxx = obj.format_xxxx_string(n,3,[1 255]);
            yyy = obj.format_xxxx_string(duration,3,[10 999]);
            obj.send(['T' xxx yyy]);
        end

        function set_trigger_in(obj,state)
            % obj.set_trigger_in(state);
            % Sets trigger in to launch stimulation immediately.
            % State should be "on" or "off". If temperature has been
            % requested, it defines the duration of the feedback based on 
            % the stimulation duration.
            if strcmpi(state,'on')
                obj.send('Ose');
            elseif strcmpi(state,'off')
                obj.send('Osd');
            else
                error('State for trigger in is "on" or "off".')
            end
        end

        function set_mri_filter(obj, filter)
            % obj.set_mri_filter(filter);
            % Sets the strength of Kalman filter for MRI environnement
            % compatible probe, level should be integer : 1 (low), or 2
            % (medium), or 3 (high).

            % Check if filter level is 1 or 2 or 3
            if ~ismember(filter, [1 2 3])
                error('Filter level should be : 1 or 2 or 3.')
            else
            end
            cmd_temp = obj.format_xxxx_command('Ofx', filter, [1 3]);
            obj.send(cmd_temp);
            levels = {"low", "medium", "high"};
            if obj.verbosity == 1
            disp("MRI filter set to " + levels{filter} + " (" + filter + ").");
            disp('Check the maximum heating/cooling ramps!');
            end
        end

        function set_time_date(obj, hh, mm, ss, dd, MM, yy)
            % obj.set_time_date('hh', 'mm', 'ss', 'dd', 'MM', 'yy');
            % Sets time and date of the device, arguments should be char type
            % i.e., between single quote (e.g., '10','30','00','01','12','26').
            
            % Checks inputs and formats time_date as hhmmssddMMyy
            if nargin < 6
                error('Missing arguments: provide hour, minute, second, day, month, and year, as character vectors.');
            end
            if str2double(hh) > 23 || str2double(mm) > 59 || str2double(ss) > 59 || str2double(dd) > 31 || str2double(MM) > 12 || str2double(yy) > 99
                error('Invalid time or date values. Please provide valid values for hour (0-23), minute (0-59), second (0-59), day (1-31), month (1-12), and year (0-99).');
            end
            time_date = [hh mm ss dd MM yy];
            time_date = str2double(time_date);
            cmd_time = obj.format_xxxx_command('Xwxxxxxxxxxxxx', time_date, [000000000000 235959311299]);
            obj.send(cmd_time);
        end

        % ── Actions ──────────────────────────────────────────────────────

        function stimulate(obj)
            % obj.stimulate;
            % Sends the stimulation. It also sets the duration of the
            % temperature feedback to be recorded if feedback has been
            % requested (temperature_feedback_state = true).
            if obj.verbosity == 1
                disp('Stimulation sent...');
            end
            obj.send('L');
        end

        function abort_stimulation(obj)
            % obj.abort_stimulation;
            % Aborts the current stimulation.
            obj.send('A');
        end

        function send_trigger_out(obj)
            % obj.send_trigger_out;
            % Sends trigger out defined by obj.set_trigger_out(n,duration);
            % Trigger out is 10 ms delayed.
            obj.send('Oo');
        end

        function zone_feedback_mat = get_stimulation_feedback(obj,zones,plotty)
            % obj.zone_feedback_mat = get_stimulation_feedback(obj,zones,plotty);
            % Gets temperature feedback from thermocouples and plots (if plotty = 1)
            % the stimulation time course for the specified "zones" of the probe.
            % It waits for the stimulation to be done, i.e., using "wait_duration" delay
            % defined as the stimulation duration + safety margin of 50 ms
            % before the serial port is read to get the feedback.
            
            % Waits for the stimulation to be done
            pause(obj.wait_duration);
            % stores output
            temperature_feedback = obj.receive;
            % extracts position of separators '+' in the character temperature data
            sample_index = strfind(temperature_feedback,'+');
            % preallocation
            feedback_array = zeros(1,length(sample_index));
            % stores temperature data based on indices
            for idx = 1:length(sample_index)
                feedback_array(idx) = str2double(temperature_feedback(sample_index(idx)+1:sample_index(idx)+4));
            end
            % sorts the temperatures for each zones
            indiv_zone = regexp(sprintf('%05d', zones),'1');
            for izone = 1:size(indiv_zone,2)
                zone_feedback{1,indiv_zone(izone)} = feedback_array(indiv_zone(izone):5:end);
            end
            for izone = 1:size(indiv_zone,2)
                zone_feedback_mat(indiv_zone(izone),:) = zone_feedback{indiv_zone(izone)};
            end
            % optional plot
            if nargin == 3
                if plotty == 1
                    figure('color','w','Position',[0,0,1000,900]);
                    color_plot = {[0,0.4470,0.7410],[0.85,0.325,0.098],[0.929,0.694,0.125],[0.494,0.184,0.556],[0.466,0.674,0.188]};
                    % time vector
                    xvalues = ((1:size(zone_feedback{1,size(indiv_zone,2)},2))*10);
                    for izone = 1:size(indiv_zone,2)
                        pz{(izone)} = plot(xvalues,zone_feedback_mat(indiv_zone(izone),:),'Color',color_plot{indiv_zone(izone)},'LineWidth',1);
                        hold on
                    end
                    % layout
                    ax = gca;
                    ax.Box = 'off';
                    ax.FontSize = 12;
                    ax.TickDir = 'out';
                    ax.XTick = 0:100:obj.wait_duration*1000;
                    ax.XAxis.Label.String = 'time (ms)';
                    ax.YAxis.Label.String = 'temperature (°C)';
                    legend_text = arrayfun(@(x) sprintf('zone %d', x), indiv_zone(1:end), 'UniformOutput', false);
                    L = legend([pz{1,1:size(indiv_zone,2)}], legend_text);
                    set(L,'Box','off','Location','best');
                end
            end
        end

        function THC = get_thermocouples(obj)
            % THC = obj.get_thermocouples;
            % Gets the current neutral temperature from the thermocouples
            % in °C.
            THC = [];
            obj.mute_temperature_display;
            pause(0.001);
            obj.flush;
            pause(0.001);
            obj.send('E');
            str = obj.receive;
            if regexp(str(2),'\d') == true
                idx_temp = strfind(str,'+');
                for itemp = 1:length(idx_temp)
                    temp_z(itemp,1) = str2double(str(idx_temp(itemp)+1:idx_temp(itemp)+3))/10;
                end
                if obj.verbosity == 1
                    disp(temp_z);
                end
                THC = temp_z;
            end
        end

        function TNc = calibrate_neutral_temperature(obj)
            % TNc = obj.calibrate_neutral_temperature;
            % Calibrates neutral / baseline temperature based on temperature
            % skin measurement. Procedure lasts about 10 seconds.
            disp('Place the probe on the skin! Do not move...');
            disp('PRESS any key, it will take approx. 10 seconds');
            pause();
            % disables temperature feedback
            mute_temperature_display(obj);
            pause(0.001);
            % clears serial port
            obj.flush;
            pause(0.001);
            % sends calibration command
            obj.send('G');
            pause(7);
            neutral = obj.receive;
            pause(0.100);
            if isempty(neutral)
                error('No response from TCS device, try again.');
            end
            TNc = str2double(neutral(2:end))/10;
            if obj.verbosity == 1
                neutral_temp = sprintf('Neutral temperature set to %.1f °C',TNc);
                disp(neutral_temp);
            end
        end

        function play_buzzer(obj,duration,freq)
            % obj.play_buzzer(duration,freq);
            % Sets and plays back TCS buzzer. Duration should be in ms between
            % [10 - 9990] and frequency (freq) should be in the range [10 to 9990] Hz.

            % check if duration and frequency are at 10x ms or 10x Hz precision
            if ~all(mod(duration,10) == 0) || ~all(mod(freq,10) == 0)
                error('Duration and frequency should both be at 10x ms precision!')
            else
            end
            obj.send(['Z' obj.format_xxxx_string(duration/10, 3, [001 999]) obj.format_xxxx_string(freq/10, 3, [001 999])]);
        end

    end

    % ── Private methods ──────────────────────────────────────────────────
    methods (Access = private)

 % set profile zones

        function mute_temperature_display(obj)
            % Disables temperature feedback between and during stimulation,
            % to get clean response from serial COM port (mute mode)
            % (private function cannot be called directly).
            obj.send('F');
        end

    end

    % ── Private Static methods ──────────────────────────────────────────────────
    methods (Static, Access = private)

        function xxxx = format_xxxx_string(value,n,range)
            % Format of the "xxxx" part of a TCS command string
            %   xxxx = format_xxxx_string(value,n)  converts value to n digit string.
            %   xxxx = format_xxxx_string(value,n,range)  checks that value is inside range.
            %   example:
            %       builds string of characters to select the second and fourth areas:
            %       format_xxxx_string(1010,5,[0 11111])  -> output: '01010'
            %   or  format_xxxx_string(01010,5,[0 11111])  -> output: '01010'
            % (private function cannot be called directly).

            % prepares arguments
            value = round(value);
            if nargin >= 3
                if (value < range(1)) || (value > range(2))
                    error('Value (%d) outside range (%d to %d). Check units.',value,range(1),range(2))
                end
            end
            format = ['%' int2str(n) 'd'];
            xxxx = sprintf(format,value);
            xxxx(xxxx == ' ') = '0';
        end

        function cmd = format_xxxx_command(cmd,value,range)
            % format_xxxx_command  Formats a TCS command string.
            %    cmd = format_xxxx_command(cmd,value,range) builds the string command
            %    to be sent to the TCS using tcs_initialize.send(cmd). It replaces the 'xxx...'
            %    following the characters by the value argument comprised in the range argument.
            %  Examples:
            %       command to set neutral temperature ('N'):
            %       format_xxxx_command('Nxxx',320,[200 400])   % -> outputs: 'N320'
            %       command to set the second, fourth and fifth areas active ('S'):
            %       format_xxxx_command('Sxxxxx',01011,[0 11111])  % -> outputs: 'S01011'
            % (private function cannot be called directly).
            n = sum(cmd == 'x');
            xxxx = tcs_initialize.format_xxxx_string(value,n,range);
            cmd(cmd == 'x') = xxxx;
        end

    end

end
