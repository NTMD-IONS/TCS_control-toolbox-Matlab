% Functions to initialize and manage serial communication with TCS devices.
% The Properties and Methods of "serial_manager" are shared with the main
% Class "tcs_initialize" used to control the TCS device.
%
% Created with MATLAB (R2024a) with Psychtoolbox (3-3.0.19.7) on Windows 11 (25H2).
% Compatible with MATLAB 2019b or later (serialportlist function is not available in earlier versions).
% Author : Cédric Lenoir, Neuroscience Techniques and Methods Developement Platform (NeTMeD),
% Email : cedric.lenoir@uclouvain.be
% Institute of Neuroscience (IoNS), UCLouvain, Brussels, Belgium.
% Copyright (c) 2026 Université catholique de Louvain (UCLouvain)
% Licensed under the GNU GPLv3 License. See LICENSE file for details.
% Version 1.0.0, August 2026.//

classdef serial_manager < handle
    properties
        verbosity = 0; % can take 2 levels 0: no output, 1: output
        portName = "";
        baudRate = 115200;
        port = "";
        isOpen = false;
        timeout = 0.1; % if data is not retrieved from serial port after
        % this delay the operation is terminated
        delay_bytes = 0.05; % optimal loop time delay in ms given
        % baudRate to get and verify presence of data from serial port
    end

    methods
        % Initializes (constructor, list and find the COM port)
        function obj = serial_manager(portName)
            if nargin == 1 && portName ~= ""
                obj.portName = portName;
            else
                obj.find_com();
                pause(0.1);
                obj.open();
            end
        end

        function delete(obj)
            % obj.delete;
            % Closes serial COM port. Handle cannot be removed from
            % workspace, if needed, use "clear obj".
            if obj.isOpen
                delete(obj.port);
                obj.isOpen = false;
                disp("Port " + obj.portName + " closed.");
            end
        end

        function send(obj, str)
            % obj.send(str);
            % Writes to the serial port the "str" command.
            if obj.isOpen
                write(obj.port, str, 'char');
            else
                disp("Port " + obj.portName + " not open.");
            end
        end

        function data = receive(obj, numBytes)
            % obj.receive;
            % Reads data from serial port, output is optional.
            obj.port.Timeout = obj.timeout;
            if nargin >= 2
                % specific number of bytes requested — blocking read
                data = read(obj.port, numBytes, 'char');
                return;
            end
            % iterative check: loop until NumBytesAvailable stabilizes
            n = -1;
            while obj.port.NumBytesAvailable ~= n
                n = obj.port.NumBytesAvailable;
                pause(obj.delay_bytes);
            end
            if n == 0
                data = '';
                return;
            end
            data = read(obj.port, n, 'char');
        end

        function flush(obj)
            % obj.flush;
            % Flushes / empties the serial COM port.
            while obj.port.NumBytesAvailable > 0
                read(obj.port, obj.port.NumBytesAvailable, 'char');
                pause(0.001);
            end
        end

        function data = ask(obj, ~)
            % obj.ask;
            % Asks serial port — sends a command and returns the full response
            % by default here an '?' is sent and expected response is "TCS"
            % (displays response and time delay between sending command and
            % getting the response).
            str = '?';
            obj.flush();
            tic
            obj.send(str);
            % waits for first byte
            t0 = tic;
            while obj.port.NumBytesAvailable == 0 && toc(t0) < obj.timeout
                pause(0.01);
            end
            if obj.port.NumBytesAvailable == 0
                data = '';
                return;
            end
            % waits until stream stabilizes
            n = 0;
            while obj.port.NumBytesAvailable ~= n
                n = obj.port.NumBytesAvailable;
                pause(obj.delay_bytes);
            end
            data = obj.receive();
            toc
            disp("Received :" + data)
        end

    end


    % ── Private methods ──────────────────────────────────────────────────
    methods (Access = private)

        function find_com(obj)
            % Lists and finds the COM port. The method send an error message 
            % if the MATLAB version is prior to 2019b
            % (private function cannot be called directly)

            % finds current Matlab version
            vMatlab = version('-release');
            vMatlab_year = str2double(vMatlab(1:4));
            vMatlab_release = vMatlab(end);
            % serialportlist introduced from R2019b
            if vMatlab_year < 2019 || (vMatlab_year == 2019 && strcmp(vMatlab_release, 'a'))
                error('serialportlist function is not available in this Matlab version. Please update to R2019b or later.')
            end
                
            ports = serialportlist("available");   % string array
            
            if isempty(ports)
                error('No COM port found.')
            end
            % gets the last COM port
            if iscell(ports)
                obj.portName = ports{end};
            else
                obj.portName = ports(end);
            end
            % checks if COM port is physical ports
            if strcmpi(obj.portName, 'COM1') || strcmpi(obj.portName, 'COM2')
                disp(['No COM port found, other than physical port (' obj.portName ').'])
            end
            disp('Found serial port(s): ')
            disp(obj.portName)
        end

        function open(obj)
            % Opens serial connection on COM port
            if obj.isOpen
                disp("Port " + obj.portName + " already open.");
                return;
            else
                obj.port = serialport(obj.portName, obj.baudRate);
                obj.isOpen = true;
                disp("Port " + obj.portName + " open.");
            end
        end

    end

end
