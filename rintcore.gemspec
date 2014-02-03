# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rint_core/version'

Gem::Specification.new do |gem|
  gem.name                       = "rintcore"
  gem.version                    = RintCore::VERSION
  gem.authors                    = ["Kaz Walker"]
  gem.email                      = ["kaz.walker@slipline.ca"]
  gem.description                = %q{A RepRap driver and GCode analyzer written in Ruby.}
  gem.summary                    = %q{A Ruby implementation of Printrun's printcore.py and gcoder.py.}
  gem.homepage                   = "https://github.com/KazW/RintCore"

  gem.files                      = `git ls-files`.split($/)
  gem.executables                = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths              = ["lib"]
  gem.required_ruby_version      = '>= 1.9.1'
  gem.add_runtime_dependency     'activesupport'
  gem.add_runtime_dependency     'thor'
  gem.add_development_dependency 'serialport', '1.3.0'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'yard'
end
