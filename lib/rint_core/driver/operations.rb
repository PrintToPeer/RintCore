require 'rint_core/g_code/codes'
require 'rint_core/g_code/object'
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
        #@print_thread.join
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

      # Sends the given command to the printer, if printing, will send command after print completion.
      # @param command [String] the command to send to the printer.
      # @param priority [Boolean] defines if command is a priority.
      # @todo finalize return value.
      def send!(command, priority = false)
        if online?
          if printing?
            priority ? @priority_queue.push(command) : @main_queue.push(command)
          else
            until clear_to_send? do
              sleep(config.sleep_time)
            end
            not_clear_to_send!
            send_to_printer(command)
          end
        else
          # TODO: log something about not being connected to printer
        end
      end

      # Sends command to the printer immediately by placing it in the priority queue.
      # @see send
      def send_now!(command)
        send!(command, true)
      end

      # Starts a print.
      # @param data [RintCore::GCode::Object] prints the given object.
      # @param data [Array] executes each command in the array.
      # @param start_index [Fixnum] starts printing from the given index (used by {#pause!} and {#resume!}).
      # @return [false] if printer isn't ready to print or already printing.
      # @return [true] if print has been started.
      def print!(data, start_index = 0)
        return false unless can_print?
        data = data.lines if data.class == RintCore::GCode::Object
        printing!
        @main_queue = [] + data
        @line_number = 0
        @queue_index = start_index
        @resend_from = -1
        send_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
        return true unless data.present?
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

private

      def initialize_operations
        @connection = nil
        @listening_thread = nil
        @print_thread = nil
        @full_history = []
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
        @print_thread.join
        @print_thread = nil
        config.callbacks[:finish].call if config.callbacks[:finish].present?
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
          when :online
            config.callbacks[:receive].call(line) if config.callbacks[:receive].present?
            if printing? && @queue_index.zero?
              sleep(config.long_sleep)
              clear_to_send!
            end
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
            config.callbacks[:resend] if config.callbacks[:resend].present?
            clear_to_send!
          when :debug
            config.callbacks[:debug] if config.callbacks[:debug].present?
          when :invalid
            config.callbacks[:invalid_response] if config.callbacks[:invalid_response].present?
            #break
          end
          # clear_to_send!
        end
        #clear_to_send!
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

      def send_to_printer(command, line_number = 0, calc_checksum = false)
        if calc_checksum
          command = prefix_command(command, line_number)
          @machine_history[line_number] = command unless command.include?(RintCore::GCode::Codes::SET_LINE_NUM)
        end
        if connected?
          config.callbacks[:send].call(command) if online? && config.callbacks[:send].present?
          command = format_command(command)
          @connection.write(command)
          @full_history << command
        end
      end


    end
  end
end