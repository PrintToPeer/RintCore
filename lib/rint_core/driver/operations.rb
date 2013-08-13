require 'rint_core/g_code'
require 'serialport'

module RintCore
  module Driver
    # Provides the raw functionality of the printer.
    module Operations

      # Connects to the printer.
      # @return [Undefined] returns the value of the connect callback.
      def connect!
        return false if connected?
        unless config.port.nil? && config.baud.nil?
          disable_hup(config.port)
          @connection = SerialPort.new(config.port, config.baud)
          @connection.read_timeout = config.read_timeout
          @stop_listening = false
          sleep(config.long_sleep)
          @listening_thread = Thread.new{listen()}
          config.callbacks[:connect].call unless config.callbacks[:connect].nil?
        end
      end

      # Disconnects to the printer.
      # @return [Undefined] returns the value of the disconnect callback.
      def disconnect!
        if connected? 
          if @listening_thread
            @stop_listening = true
            send!(RintCore::GCode::Codes::GET_EXT_TEMP)
            @listening_thread.join
            @listening_thread = nil
          end
          @connection.close
        end
        @connection = nil
        offline!
        not_printing!
        config.callbacks[:disconnect].call unless config.callbacks[:disconnect].nil?
      end

      # Resets the printer.
      # @return [false] if not connected.
      # @return [1] if printer was reset.
      def reset!
        return false unless connected?
        @connection.dtr = 0
        sleep(config.long_sleep)
        @connection.dtr = 1
      end

      # Pauses printing.
      # @return [Undefined] returns the value of the pause callback.
      def pause!
        return false unless printing?
        @paused = true
        until @print_thread.alive?
          sleep(config.sleep_time)
        end
        @print_thread = nil
        not_printing!
        config.callbacks[:pause].call unless config.callbacks[:pause].nil?
      end

      # Resumes printing.
      # @return [Undefined] returns the value of the resume callback.
      def resume!
        return false unless paused?
        @paused = false
        printing!
        @print_thread = Thread.new{print()}
        config.callbacks[:resume].call unless config.callbacks[:resume].nil?
      end

      # Sends the given command to the printer.
      # @param command [String] the command to send to the printer.
      # @param priority [Boolean] defines if command is a priority.
      # @todo finalize return value.
      def send!(command, priority = false)
        return nil unless command.is_a?(String) || command.is_a?(Array)
        if online?
          if printing?
            if priority 
              command.is_a?(String) ? @priority_queue.push(command) : @priority_queue + command
              return true
            else
              return false
            end
          else
            if command.is_a?(Array)
              command.each do |line|
                wait_then_send(line)
              end
            else
              wait_then_send(command)
            end
          end
        else
          config.callbacks[:send_error].call unless config.callbacks[:send_error].nil?
        end
      end

      # Sends command to the printer immediately by placing it in the priority queue.
      # @see send
      def send_now!(command)
        send!(command, true)
      end

      # Starts a print.
      # @param gcode [RintCore::GCode::Object] prints the given object.
      # @param start_index [Fixnum] starts printing from the given index (used by {#pause!} and {#resume!}).
      # @return [false] if printer isn't ready to print or already printing.
      # @return [true] if print has been started.
      def print!(gcode, start_index = 0)
        return false unless gcode.is_a?(RintCore::GCode::Object)
        prep_to_print(start_index)
        return true unless gcode.present?
        if low_power?
          @gcode_object = []
          gcode.lines.each_with_index do |line,line_number|
            @gcode_object << format_command(line.to_s(line_number))
          end
          gcode = nil
          GC.start
        else
          @gcode_object = gcode
          @queue_length = gcode.length
        end
        @start_time = Time.now
        @print_thread = Thread.new{print()}
        return true
      end

      # Starts printing the given file.
      # @param file [String] file name of a GCode file on the system.
      # @see print!
      def print_file!(file)
        return false unless can_print?
        return false unless File.exist?(file) || File.file?(file)
        if config.low_power
          @queue_length = %x{wc -l < "#{file}"}.to_i
          @file_handle = File.open(file)
          @start_time = Time.now
          @print_thread = Thread.new{print()}
        end
        gcode = RintCore::GCode::Object.new(file, 2400, auto_process = false)
        return false unless gcode
        print!(gcode)
      end

private

      def initialize_operations
        @connection = nil
        @listening_thread = nil
        @print_thread = nil
        @start_time = nil
        @file_handle = nil
      end

      def readline!
        begin
          line = @connection.readline.strip
        rescue EOFError, Errno::ENODEV => e
          config.callbacks[:critcal_error].call(e) unless config.callbacks[:critcal_error].nil?
        end
      end

      def prep_to_print(start_index)
        return false unless can_print?
        return false if printing?
        printing!
        @line_number = 0
        @queue_index = start_index
        @resend_from = -1
        wait_until_clear
        not_clear_to_send!
        send_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1)
      end

      def print
        @machine_history = []
        config.callbacks[:start].call unless config.callbacks[:start].nil?
        while online? && printing? do
          advance_queue
          return true if paused?
        end
        config.callbacks[:finish].call unless config.callbacks[:finish].nil?
        @start_time = nil
        initialize_queueing
        @print_thread.join
        @print_thread = nil
        return true
      end

      def listen
        clear_to_send!
        listen_until_online
        while listen_can_continue? do
          line = readline!
          @last_line_received = line unless line == "wait"
          case get_response_type(line)
          when :valid
            config.callbacks[:receive].call(line) unless config.callbacks[:receive].nil?
            clear_to_send!
          when :temperature
            config.callbacks[:temperature].call(line) unless config.callbacks[:temperature].nil?
          when :temperature_response
            config.callbacks[:temperature].call(line) unless config.callbacks[:temperature].nil?
            clear_to_send!
          when :error
            config.callbacks[:printer_error] unless config.callbacks[:printer_error].nil?
            # TODO: Figure out if an error should be raised here or if it should be left to the callback
          when :resend
            @resend_from = get_resend_number(line)
            config.callbacks[:resend].call(line) unless config.callbacks[:resend].nil?
            clear_to_send!
          when :debug
            config.callbacks[:debug] unless config.callbacks[:debug].nil?
          when :invalid
            config.callbacks[:invalid_response] unless config.callbacks[:invalid_response].nil?
          end
        end
      end

      def listen_until_online
        begin
          empty_lines = 0
          accepted_reponses = [:online,:temperature,:valid]
          while listen_can_continue? do
            line = readline!
            unless line.empty?
              empty_lines = 0 
            else 
              empty_lines += 1
              not_clear_to_send!
              send!(RintCore::GCode::Codes::GET_EXT_TEMP)
            end
            break if empty_lines == 5
            if accepted_reponses.include?(get_response_type(line))
              config.callbacks[:online].call unless config.callbacks[:online].nil?
              online!
              return true
            end
            sleep(config.long_sleep)
          end
          raise "Printer could not be brought online."
        rescue RuntimeError => e
          config.callbacks[:critcal_error].call(e) unless config.callbacks[:critcal_error].nil?
        end
      end

      def send_to_printer(line, line_number = nil)
        line = RintCore::GCode::Line.new(line) if line.include?(RintCore::GCode::Codes::SET_LINE_NUM)
        return false if line.empty?
        line = format_command(line.to_s(line_number)) if line.is_a?(RintCore::GCode::Line)
        line = format_command(line, line_number) if line_number.nil? || !line.is_a?(RintCore::GCode::Line)
        if connected?
          @machine_history[line_number] = line if printing? && !line_number.nil? && !line.include?(RintCore::GCode::Codes::SET_LINE_NUM)
          config.callbacks[:send].call(line) unless config.callbacks[:send].nil?
          @connection.write(line)
          trim_machine_history
          return true
        end
        false
      end

      def trim_machine_history
        @machine_history[@line_number-300] = nil if @line_number >= 300 && @machine_history.length >= 300
      end

      def wait_then_send(line)
        wait_until_clear
        not_clear_to_send!
        send_to_printer(line)
      end

      def wait_until_clear
        until clear_to_send? do
          sleep(config.sleep_time)
        end
      end

    end
  end
end