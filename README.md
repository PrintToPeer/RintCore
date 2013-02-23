# RintCore

[![Code Climate](https://codeclimate.com/github/KazW/RintCore.png)](https://codeclimate.com/github/KazW/RintCore)

A RepRap/GCode parsing and sending utility written in Ruby.

### Usage

Clone the repo and cd into it.
```
bundle exec irb
```
```ruby
require 'rint_core/printer'
printer = RintCore::Printer.new
printer.port = '/dev/ttyUSB0' # Set to /dev/ttyACM0 by default
printer.baud = 250000 # Set to 115200 by default
printer.callbacks[:temperature] = Proc.new { |line| puts(line) }
printer.connect!
printer.send 'M105'
```

### TODO

Update this list and everything else in general.

### Contributing
See CONTRIBUTING.md

### License & Copyright

Copyright (C) 2013  Kaz Walker

The Diver modules are based on printcore.py by Kliment Yanev and various contributors.

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
