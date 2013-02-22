module RintCore
  module Driver
    module Operations

      def connect!
        if config.port.present? && config.baud.present? && !connected?
          disable_hup(config.port)
          @connection = SerialPort.new(config.port, config.baud)
          @connection.read_timeout = config.read_timeout
          @stop_listening = false
          @read_thread = Thread.new(listen)
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
        sleep 0.2
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
        return false unless @paused
        @paused = false
        printing!
        @print_thread = Thread.new(print!)
        config.callbacks[:resume].call if config.callbacks[:resume].present?
      end

      def send(command, wait = 0, priority = false)
        if @online
          if @printing
            priority ? @priority_queue.push(command) : @main_queue.push(command)
          else
            while ClearPrintingCheck.call do
              sleep(@sleep_time)
            end
            wait = @wait if wait == 0 && @wait > 0
            @clear = false if wait > 0
            send!(command, @line_number, true)
            @line_number += 1
            while WaitCheck.call(wait) do
              sleep @sleep_time
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
        @printing = true
        @main_queue = [] + data
        @line_number = 0
        @queue_index = start_index
        @resend_from = -1
        send!(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
        return true unless data.present?
        @clear = false
        @print_thread = Thread.new(print!)
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
          line = @connection.readline
          config.callbacks[:receive].call(line) if line.length > 1 && config.callbacks[:receive].present?
          line # return the line
        rescue EOFError, Errno::ENODEV => e
          # TODO: Do something useful
        end
      end

      def print!
        config.callbacks[:start].call if config.callbacks[:start].present?
        while OnlinePrintingCheck.call do
          advance_queue
        end
        @sent_lines = []
        @print_thread.join
        @print_thread = nil
        config.callbacks[:finish].call if config.callbacks[:finish].present?
        return true
      end

      def listen
        @clear = true
        _listen_until_online unless @printing
        while listen_can_continue? do
          line = readline!
          break if line.nil?
          debug_callback.call(line) if line.start_with?('DEBUG_') && debug_callback.respond_to?(:call)
          @clear = true if line.start_with?(*@greetings, @good_response)
          temperature_callback.call(line) if line.start_with?(@good_response) && line.include?('T:') && temperature_callback.respond_to?(:call)
          error_callback.call(line) if line.start_with?('Error') && error_callback.respond_to?(:call)
          if line.downcase.start_with?(*@resend_response)
            line = line.sub('N:', ' ').sub('N', ' ').sub(':', ' ')
            linewords = line.split
            @resend_from = linewords.pop(0).to_i
            @clear = true
          end
        end
        @clear = true
      end

      def listen_until_online
        catch 'BreakOut' do
          while !@online && listen_can_continue? do
            send!(RintCore::GCode::Codes::GET_EXT_TEMP)
            empty_lines = 0
            while listen_can_continue? do
              line = readline!
              throw 'BreakOut' if line.nil?
              line.blank? ? empty_lines += 1 : empty_lines = 0
              throw 'BreakOut' if empty_lines == 5
              if line.start_with?(*@greetings, @good_response)
                online_callback.call if online_callback.respond_to?(:call)
                @online = true
                return true
              end
              sleep 0.25
            end
          end
        end
      end

      def send!(command, line_number = 0, calc_checksum = false)
        if calc_checksum
          command = prefix_command(command, line_number)
          @sent_lines[line_number] = command unless command.include?(RintCore::GCode::Codes::SET_LINE_NUM)
        end
        if @printer
          send_callback.call(command) if send_callback.respond_to?(:call)
          command = (command + "\n").encode(@encoding)
          @printer.write(command)
        end
      end


    end
  end
end