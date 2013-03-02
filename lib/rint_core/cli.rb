require 'rint_core/g_code/object'
require 'rint_core/printer'
require 'rint_core/g_code/codes'
require 'thor'
require 'active_support/core_ext/object/blank'

module RintCore
  # Provides command line interfaces for interacting with RintCore's classes.
  class Cli < Thor
    map '-a' => :analyze, '-p' => :print

    desc 'analyze FILE', 'Get statistics about the given GCode file.'
    method_option :decimals, default: 2, aliases: '-d', type: :numeric, desc: 'The number of decimal places given for measurements.'
    # Analyze the given file, also sets the @object instance variable to a {RintCore::GCode::Object}.
    # @param file [String] path to a GCode file on the system.
    # @return [String] statistics about the given GCode file.
    def analyze(file)
      unless RintCore::GCode::Object.is_file?(file)
        puts "Non-exsitant file: #{file}"
        exit
      end
      @object = RintCore::GCode::Object.new(RintCore::GCode::Object.get_file(file))
      decimals = options[:decimals]
      decimals ||= 2

      puts "Dimensions:\n"\
            "\tX: #{@object.x_min.round(decimals)} - #{@object.x_max.round(decimals)} (#{@object.width.round(decimals)}mm)\n"\
            "\tY: #{@object.y_min.round(decimals)} - #{@object.y_max.round(decimals)} (#{@object.depth.round(decimals)}mm)\n"\
            "\tZ: #{@object.z_min.round(decimals)} - #{@object.z_max.round(decimals)} (#{@object.height.round(decimals)}mm)\n"\
            "Total Travel:\n"\
            "\tX: #{@object.x_travel.round(decimals)}mm\n"\
            "\tY: #{@object.y_travel.round(decimals)}mm\n"\
            "\tZ: #{@object.z_travel.round(decimals)}mm\n"\
            "Filament used (per extruder):\n"
      @object.filament_used.each_with_index do |filament,extruder|
        puts "\t#{extruder}: #{filament.round(decimals)}mm"
      end
      puts "Number of layers: #{@object.layers}\n"\
            "#{@object.raw_data.length} lines / #{@object.lines.length} commands"
    end
    
    desc 'print FILE', 'Print the given GCode file.'
    method_option :port, aliases: '-p', type: :string, desc: 'The port that the printer is connected to.'
    method_option :baud, aliases: '-b', type: :numeric, desc: 'The baud rate at which the printer communicates at.'
    method_option :loud, aliases: '-l', default: false, type: :boolean, desc: 'Output additional info (temperature, progress, etc.)'
    # Analyzes, then prints the given file.
    # @param file [String] path to a GCode file on the system.
    # @return [String] value of the disconnect callback in this function.
    def print(file)
      port = options[:port]
      baud = options[:baud]
      baud = baud.to_i unless baud.blank?
      baud = nil unless RintCore::Printer.baud_rates.include?(baud)
      port = nil unless RintCore::Printer.is_port?(port)
      while port.blank?
        puts "Please enter the port and press enter:"
        port = $stdin.gets.strip
        port = nil unless RintCore::Printer.is_port?(port)
      end
      while baud.blank?
        puts "Please enter the baud rate and press enter:"
        baud = $stdin.gets.strip
        baud = baud.to_i unless baud.blank?
        baud = nil unless RintCore::Printer.baud_rates.include?(baud)
      end
      analyze(file)
      printer = RintCore::Printer.new
      printer.port = port
      printer.baud = baud
      printer.callbacks[:online] = Proc.new { puts "Printer online!" }
      printer.callbacks[:start] = Proc.new { puts "Started printing!" }
      printer.callbacks[:finish] = Proc.new { puts "Print took: "+printer.time_from_start }
      printer.callbacks[:temperature] = Proc.new { |line| puts line }
      if options[:loud]
        printer.callbacks[:receive] = Proc.new { |line| puts "Got: "+line }
        printer.callbacks[:send] = Proc.new { |line| puts "Sent: "+line }
      end
      printer.callbacks[:disconnect] = Proc.new { puts "Printer disconnected!" }
      printer.connect!
      until printer.online?
        sleep(printer.long_sleep)
      end
      printer.start_print(@object)
      while printer.printing?
        printer.send_now(RintCore::GCode::Codes::GET_EXT_TEMP)
        sleep 4.20
        puts "Printed "+((Float(printer.queue_index) / Float(printer.main_queue.length))*100).round(2).to_s+"% in "+printer.time_from_start
        sleep 1
      end
      printer.disconnect!
    end

  end
end