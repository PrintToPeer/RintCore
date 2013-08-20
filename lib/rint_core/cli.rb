require 'rint_core/g_code/object'
require 'rint_core/printer'
require 'rint_core/g_code/codes'
require 'thor'

module RintCore
  # Provides command line interfaces for interacting with RintCore's classes.
  class Cli < Thor
    map '-a' => :analyze, '-p' => :print, '-m' => :modify

    desc 'analyze FILE', 'Get statistics about the given GCode file.'
    method_option :decimals, default: 2, aliases: '-d', type: :numeric, desc: 'The number of decimal places given for measurements.'
    # Analyze the given file, also sets the @object instance variable to a {RintCore::GCode::Object}.
    # @param file [String] path to a GCode file on the system.
    # @return [String] statistics about the given GCode file.
    def analyze(file, gcode_options = {})
      unless RintCore::GCode::Object.is_file?(file)
        puts "Non-exsitant file: #{file}"
        exit
      end
      @object = RintCore::GCode::Object.new({data: RintCore::GCode::Object.get_file(file)}.merge!(gcode_options))

      unless @object.present?
        puts "Non-GCode or empty file: #{file}"
        exit
      end

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
            "Filament used:\n"
      @object.filament_used.each_with_index do |filament,extruder|
        puts "\tExtruder #{extruder+1}: #{filament.round(decimals)}mm"
      end
      puts "\nNumber of layers: #{@object.layers}\n\n"\
            "Estimated duration: #{@object.durration_in_words}\n\n"\
            "#{@object.raw_data.length} lines / #{@object.lines.length} commands / #{@object.comments.length} comments"
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
      baud = baud unless baud.nil?
      baud = nil unless RintCore::Printer.baud_rates.include?(baud)
      port = nil unless RintCore::Printer.is_port?(port)
      while port.nil?
        puts "Please enter the port and press enter:"
        port = $stdin.gets.strip
        port = nil unless RintCore::Printer.is_port?(port)
      end
      while baud.nil?
        puts "Please enter the baud rate and press enter:"
        baud = $stdin.gets.strip
        baud = baud.to_i unless baud.empty?
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
      printer.callbacks[:resend] = Proc.new { |line| puts "RESENDING LINE: "+line }
      if options[:loud]
        printer.callbacks[:receive] = Proc.new { |line| puts "Got: "+line }
        printer.callbacks[:send] = Proc.new { |line| puts "Sent: "+line }
      end
      printer.callbacks[:disconnect] = Proc.new { puts "Printer disconnected!" }
      printer.connect!
      until printer.online?
        sleep(printer.long_sleep)
      end
      printer.print!(@object)
      run_time = Time.now
      while printer.printing?
        loop_time = Time.now
        if loop_time - run_time >= 5
          printer.send_now!(RintCore::GCode::Codes::GET_EXT_TEMP)
          puts "Printed "+((Float(printer.queue_index) / Float(@object.lines.length))*100).round(2).to_s+"% in "+printer.time_from_start+\
                "... On layer #{printer.current_layer} of #{@object.layers}"
          run_time = Time.now
        end
      end
      printer.disconnect!
    end

    desc 'modify FILE', 'add a given amount to everyline with a given acxis'
    method_option :x, aliases: '-x', type: :numeric, desc: 'The amount to add to all X coordinates.'
    method_option :y, aliases: '-y', type: :numeric, desc: 'The amount to add to all Y coordinates.'
    method_option :z, aliases: '-z', type: :numeric, desc: 'The amount to add to all Z coordinates.'
    # Analyze the given file, also sets the @object instance variable to a {RintCore::GCode::Object}.
    # @param file [String] path to a GCode file on the system.
    # @return [String] statistics about the given GCode file.
    def modify(file)
      analyze(file, {x_add: options[:x], y_add: options[:y], z_add: options[:z]})
      puts "Writing changes to file"
      @object.write_to_file(file)
      puts "Wrote new Gcode to file!"
    end

  end
end