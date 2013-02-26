require 'rint_core/g_code/object'
require 'rint_core/printer'
require 'thor'

module RintCore
  class Cli < Thor
    map "-a" => :analyze
    desc 'analyze FILE', 'Get statistics about a GCode file.'
    method_option :decimals, default: 2, aliases: '-d', desc: 'The number of decimal places given for measurements.'
    def analyze(file)
      if File.exist?(file) && File.file?(file)
        object = RintCore::GCode::Object.new(IO.readlines(file))
        puts "Dimensions:
\tX: #{object.x_min.round(options[:decimals])} - #{object.x_max.round(options[:decimals])} (#{object.width.round(options[:decimals])}mm)
\tY: #{object.y_min.round(options[:decimals])} - #{object.y_max.round(options[:decimals])} (#{object.depth.round(options[:decimals])}mm)
\tZ: #{object.z_min.round(options[:decimals])} - #{object.z_max.round(options[:decimals])} (#{object.height.round(options[:decimals])}mm)
Total Travel:
\tX: #{object.x_travel.round(options[:decimals])}mm
\tY: #{object.y_travel.round(options[:decimals])}mm
\tZ: #{object.z_travel.round(options[:decimals])}mm
Filament used: #{object.filament_used.round(options[:decimals])}mm
Number of layers: #{object.layers}
#{object.raw_data.length} lines / #{object.lines.length} commands"
      else
        puts "Non-exsitant file: #{file}"
      end
    end
    
  end
end