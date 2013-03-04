# RintCore

[![Code Climate](https://codeclimate.com/github/KazW/RintCore.png)](https://codeclimate.com/github/KazW/RintCore)

A RepRap/GCode parsing and sending utility written in Ruby.

### Usage
Install: ```gem install rintcore```

Get stats for a GCode file: ```rintcore analyze my_print.gcode```  
Print a GCode file: ```rintcore print my_print.gcode```  
See more options: ```rintcore help```  

Use it somewhere else:
```ruby
require 'rint_core/printer'
printer = RintCore::Printer.new
printer.port = '/dev/ttyUSB0' # Set to /dev/ttyACM0 by default
printer.baud = 250000 # Set to 115200 by default
printer.callbacks[:temperature] = Proc.new { |line| puts(line) }
printer.connect!
printer.print_file! 'my_print.gcode'
```

### TODO
* Implement Binary (Repetier) sending.

### Contributing
See CONTRIBUTING.md

### License & Copyright

Copyright (C) 2013  Kaz Walker

The Driver modules are based on Printrun's [printcore.py](https://github.com/kliment/Printrun/blob/master/printcore.py).  
The GCode analyzer is an optimized version of Printrun's
[gcoder.py](https://github.com/kliment/Printrun/blob/master/gcoder.py).

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
