require 'serialport'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    module Operations

      def connect!
        return false if connected?
        if config.port.present? && config.baud.present?
          disable_hup(config.port)
          @connection = SerialPort.new(config.port, config.baud)
          @connection.read_timeout = config.read_timeout
          @stop_listening = false
          @read_thread = Thread.new{listen()}
          config.callbacks[:connect].call if config.callbacks[:connect].present?
        end
      end

      def disconnect!
        if connected? 
          if @read_thread
            @stop_listening = true
            @read_thread.join
            @read_thread = nil
          end
          @connection.close
        end
        @connection = nil
        offline!
        not_printing!
        config.callbacks[:disconnect].call if config.callbacks[:disconnect].present?
      end

      def reset!
        @connection.dtr = 0
        sleep(config.long_sleep)
        @connection.dtr = 1
      end

      def pause!
        return false unless printing?
        @paused = true
        not_printing!
        @print_thread.join
        @print_thread = nil
        config.callbacks[:pause].call if config.callbacks[:pause].present?
      end

      def resume!
        return false unless paused?
        paused!
        printing!
        @print_thread = Thread.new{print!()}
        config.callbacks[:resume].call if config.callbacks[:resume].present?
      end

      def send(command, wait = 0, priority = false)
        if online?
          if printing?
            priority ? @priority_queue.push(command) : @main_queue.push(command)
          else
            until clear_to_send? do
              sleep(config.sleep_time)
            end
            wait = config.wait_period if wait == 0 && config.wait_period > 0
            not_clear_to_send!
            send!(command)
            while wait > 0 && !clear_to_send? do
              sleep config.sleep_time
              wait -= 1
            end
          end
        else
          # TODO: log something about not being connected to printer
        end
      end

      def send_now(command, wait = 0)
        send(command, wait, true)
      end

      def start_print(data, start_index = 0)
        return false unless can_print?
        printing!
        @main_queue = [] + data
        @line_number = 0
        @queue_index = start_index
        @resend_from = -1
        not_clear_to_send!
        send!(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
        return true unless data.present?
        @print_thread = Thread.new{print!()}
        return true
      end

private

      def initialize_operations
        @connection = nil
        @listening_thread = nil
        @printing_thread = nil
      end

      def readline!
        begin
          line = @connection.readline.strip
        rescue EOFError, Errno::ENODEV => e
          config.callbacks[:critcal_error].call(e) if config.callbacks[:critcal_error].present?
        end
      end

      def print!
        config.callbacks[:start].call if config.callbacks[:start].present?
        while online? && printing? do
          advance_queue
        end
        @machine_history = []
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
          when :valid || :online
            config.callbacks[:receive].call(line) if config.callbacks[:receive].present?
          when :temperature
            config.callbacks[:temperature].call(line) if config.callbacks[:temperature].present?
          when :error
            config.callbacks[:printer_error] if config.callbacks[:printer_error].present?
            # TODO: Figure out if an error should be raised here or if it should be left to the callback
          when :resend
            @resend_from = get_resend_number(line)
            config.callbacks[:resend] if config.callbacks[:resend].present?
          when :debug
            config.callbacks[:debug] if config.callbacks[:debug].present?
          when :invalid
            config.callbacks[:invalid_response] if config.callbacks[:invalid_response].present?
            #break
          end
          clear_to_send!
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

      def send!(command, line_number = 0, calc_checksum = false)
        if calc_checksum
          command = prefix_command(command, line_number)
          @machine_history[line_number] = command unless command.include?(RintCore::GCode::Codes::SET_LINE_NUM)
        end
        if connected?
          config.callbacks[:send].call(command) if online? && config.callbacks[:send].present?
          command = format_command(command)
          @connection.write(command)
        end
      end


    end
  end
end