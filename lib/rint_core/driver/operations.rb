require 'rint_core/g_code'
require 'serialport'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    # Provides the raw functionality of the printer.
    module Operations

      # Connects to the printer.
      # @return [Undefined] returns the value of the connect callback.
      def connect!
        return false if connected?
        if config.port.present? && config.baud.present?
          disable_hup(config.port)
          @connection = SerialPort.new(config.port, config.baud)
          @connection.read_timeout = config.read_timeout
          @stop_listening = false
          sleep(config.long_sleep)
          @listening_thread = Thread.new{listen()}
          config.callbacks[:connect].call if config.callbacks[:connect].present?
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
        config.callbacks[:disconnect].call if config.callbacks[:disconnect].present?
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
        config.callbacks[:pause].call if config.callbacks[:pause].present?
      end

      # Resumes printing.
      # @return [Undefined] returns the value of the resume callback.
      def resume!
        return false unless paused?
        @paused = false
        printing!
        @print_thread = Thread.new{print()}
        config.callbacks[:resume].call if config.callbacks[:resume].present?
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
              @priority_queue.push(command) if command.is_a?(String)
              @priority_queue + command if command.is_a?(Array)
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
          config.callbacks[:send_error].call if config.callbacks[:send_error].present?
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
        return false unless can_print?
        return false unless gcode.is_a?(RintCore::GCode::Object)
        printing!
        @gcode_object = gcode
        @line_number = 0
        @queue_index = start_index
        @resend_from = -1
        wait_until_clear
        not_clear_to_send!
        send_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
        return true unless gcode.present?
        @print_thread = Thread.new{print()}
        @start_time = Time.now
        return true
      end

      # Starts printing the given file.
      # @param file [String] file name of a GCode file on the system.
      # @see print!
      def print_file!(file)
        return false unless can_print?
        gcode = RintCore::GCode::Object.new(file, 2400, auto_process = false)
        return false unless gcode
        print!(gcode)
      end

      # Clears the history of sent commands.
      # @return [true]
      def clear_history!(file)
        @full_history = []
        true
      end

private

      def initialize_operations
        @connection = nil
        @listening_thread = nil
        @print_thread = nil
        @full_history = []
        @start_time = nil
      end

      def readline!
        begin
          line = @connection.readline.strip
        rescue EOFError, Errno::ENODEV => e
          config.callbacks[:critcal_error].call(e) if config.callbacks[:critcal_error].present?
        end
      end

      def print
        @machine_history = []
        config.callbacks[:start].call if config.callbacks[:start].present?
        while online? && printing? do
          advance_queue
          return true if paused?
        end
        config.callbacks[:finish].call if config.callbacks[:finish].present?
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
          @last_line_received = line
          case get_response_type(line)
          when :valid
            config.callbacks[:receive].call(line) if config.callbacks[:receive].present?
            clear_to_send!
          when :temperature
            config.callbacks[:temperature].call(line) if config.callbacks[:temperature].present?
          when :temperature_response
            config.callbacks[:temperature].call(line) if config.callbacks[:temperature].present?
            clear_to_send!
          when :error
            config.callbacks[:printer_error] if config.callbacks[:printer_error].present?
            # TODO: Figure out if an error should be raised here or if it should be left to the callback
          when :resend
            @resend_from = get_resend_number(line)
            config.callbacks[:resend].call(line) if config.callbacks[:resend].present?
            clear_to_send!
          when :debug
            config.callbacks[:debug] if config.callbacks[:debug].present?
          when :invalid
            config.callbacks[:invalid_response] if config.callbacks[:invalid_response].present?
          end
        end
      end

      def listen_until_online
        begin
          empty_lines = 0
          accepted_reponses = [:online,:temperature,:valid]
          while listen_can_continue? do
            line = readline!
            if line.present?
              empty_lines = 0 
            else 
              empty_lines += 1
              not_clear_to_send!
              send!(RintCore::GCode::Codes::GET_EXT_TEMP)
            end
            break if empty_lines == 5
            if accepted_reponses.include?(get_response_type(line))
              config.callbacks[:online].call if config.callbacks[:online].present?
              online!
              return true
            end
            sleep(config.long_sleep)
          end
          raise "Printer could not be brought online."
        rescue RuntimeError => e
          config.callbacks[:critcal_error].call(e) if config.callbacks[:critcal_error].present?
        end
      end

      def send_to_printer(line, line_number = nil, calc_checksum = false)
        line = RintCore::GCode::Line.new(line) if line.is_a?(String)
        return false if line.command.nil?
        if line.is_a?(RintCore::GCode::Line)
          if calc_checksum && line_number
            @machine_history[line_number] = line.to_s unless line.command == RintCore::GCode::Codes::SET_LINE_NUM
            line = line.to_s(line_number)
          else
            line = line.to_s
          end
        end
        line = format_command(line)
        if connected?
          config.callbacks[:send].call(line) if online? && config.callbacks[:send].present?
          @connection.write(line)
          @full_history << line
          return true
        end
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