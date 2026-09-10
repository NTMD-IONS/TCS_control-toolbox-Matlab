# Library of functions to control TCS device from QST.Lab

## Overview
This repository provides a MATLAB library to control a **TCS (Thermal Cutaneous Stimulator)** device via serial (USB) communication.

## Environment
- MATLAB R2019b or later (created with R2024a and tested with R2019b)
- Windows 11 (tested with 25H2); other OS may work but are untested
- TCS device connected via USB
- Optional: - [Psychtoolbox](http://psychtoolbox.org/) (tested with version 3-3.0.19.7) — used for precise timing (`WaitSecs`)

## Installation
1. Clone or download this repository.
2. Add the repository folder (and subfolders) to your MATLAB path:
   ```matlab
   addpath(genpath('path/to/repo'));
   ```

## Note
Two classes have been written:
- `serial_manager`: manages the serial communication (USB) between the computer and the TCS device.
- `tcs_initialize`: controls the TCS device using its specific commands.

`tcs_initialize` is built on top of `serial_manager`, and inherits its properties (variables) and methods (functions).

## General use

### Initialization
Create the object using the class constructor. The constructor automatically detects the COM port and opens the serial connection.

The class name is `tcs_initialize`; the name of the created object can be chosen freely. For example:
```matlab
tcs = tcs_initialize;
```

This can be repeated for each TCS device (`tcs1`, `tcs2`, etc.) if several are connected to the same computer. In that case, connect one TCS device to the computer and call:
```matlab
obj1 = tcs_initialize;
```
then connect the second TCS device and call:
```matlab
obj2 = tcs_initialize;
```
and so on.

### Use methods for serial communication and TCS control
It is advised to wait at least 1 ms between successive commands, using either:
```matlab
WaitSecs(0.001)   % Psychtoolbox
pause(0.001)      % native MATLAB function
```

Once the object (`tcs` in the example above) has been created, its methods can be called as:
```matlab
obj.MethodName;
```

For example, to close the serial communication:
```matlab
tcs.delete;
```

To read data from the serial port:
```matlab
tcs.receive;
```

### Example commands
```matlab
tcs.disable_temperature_feedback;
% disables the reading of temperature

tcs.set_neutral_temperature(30);
% sets the neutral temperature to 30°C

zones = [0 1 1 1 0];
tcs.set_active_zones(zones);
% activates zones 2, 3, and 4

freq = 100;
tcs.enable_temperature_feedback(freq);
% enables temperature reading at 100 Hz during stimulation

battery_level = tcs.get_battery;
% retrieves the voltage and percentage of charge of the TCS device
% and stores them in "battery_level"
```

Properties (variables) shared across classes can be accessed the same way:
```matlab
tcs.portName
>> 'COM6'

tcs.verbosity
>> 1
```

### Example workflow
```matlab
% 1. Connect to the device
tcs = tcs_initialize;

% 2. Configure stimulation
tcs.set_neutral_temperature(30);
zones = [0 1 1 1 0];
tcs.set_active_zones(zones);
tcs.enable_temperature_feedback(100);

% 3. Check device status
battery_level = tcs.get_battery;

% 4. Set the stimulation parameters
tcs.set_stimulation_param(11111,32,15,200,300,300,1);

% 5. Deliver the stimulation
tcs.stimulate

% 4. Close the connection
tcs.delete;
```

## Get help about functions and variables

### List the properties of the class
Properties shared across classes can be listed with:
```matlab
properties ClassName
```
For example:
```matlab
properties tcs_initialize
% or
properties('tcs_initialize')
% or, if an object has already been created:
properties(obj)
% in the example
properties(tcs)
```

### List the methods of the class
Methods shared across classes can be listed with:
```matlab
methods('ClassName')
```
For example:
```matlab
methods('tcs_initialize')
% or
methods tcs_initialize
% or, if an object has already been created:
methods(obj)
% in the example
methods(tcs)
```

### Get help about a specific method
```matlab
help ClassName.MethodName
```
For example:
```matlab
help tcs_initialize.get_battery
```

## License
*Copyright (c) 2026 Université catholique de Louvain (UCLouvain)*

This project is licensed under the GNU GPLv3 License - see the [LICENSE](LICENSE) file for details.

---
**Created with** MATLAB (R2024a) with Psychtoolbox (3-3.0.19.7) on Windows 11 (25H2).

**Compatible with** MATLAB R2019b or later.

**Author:** Cédric Lenoir, Neuroscience Techniques and Methods Development Platform (NeTMeD),
Institute of Neuroscience (IoNS), UCLouvain, Brussels, Belgium.

**Email:** cedric.lenoir@uclouvain.be

**Version** 1.0.0, August 2026.

