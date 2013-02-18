require 'rint_core/g_code/codes'
require 'serialport'
require 'active_support/core_ext/object/blank'
require 'active_support/configurable'

module RintCore
  class PrinterDriver
    include ActiveSupport::Configurable

    # Callbacks are typically given a string argument, usually the current line
    config_accessor :port, :baud, :start_callback, :temperature_callback,
                    :receive_callback, :send_callback, :error_callback,
                    :end_callback, :online_callback, :debug_callback,
                    :connect_callback

    def control_ttyhup(port, disable_hup)
      if /linux/ =~ RUBY_PLATFORM
        if disable_hup
          `stty -F #{port} -hup`
        else
          `stty -F #{port} hup`
        end
      end
    end

    def enable_hup(port)
      control_ttyhup(port, true)
    end

    def disable_hup(port)
      control_ttyhup(port, false)
    end

    def initialize(port = nil, baud = nil)
      @baud = nil
      @port = nil
      @printer = nil # Serial instance connected to the printer, nil when disconnected
      @clear = 0 # clear to send, enabled after responses
      @online = false # The printer has responded to the initial command and is active
      @printing = false # is a print currently running, true if printing, false if paused
      @main_queue = []
      @priority_queue = []
      @queue_index = 0
      @line_number = 0
      @resend_from = -1
      @paused = false
      @sent_lines = []
      @log = []
      @sent = []
      @loud = false # emit sent and received lines to terminal
      @greetings = ['start','Grbl ']
      @wait = 0 # default wait period for send(), send_now()
      @read_thread = nil
      @stop_read_thread = false
      @print_thread = nil
      @good_response = 'ok'
      @resend_response = ['rs','resend']
      @sleep_time = 0.001
      @encoding = 'us-ascii'
      connect(port, baud) if port.present? && baud.present?
    end

    def disconnect
      if @printer 
        if @read_thread
          @stop_read_thread = true
          @read_thread.join
          @read_thread = nil
        end
        @printer.close
      end
      @printer = nil
      @online = false
      @printing = false
    end

    def connect(port = nil, baud = nil)
      disconnect if @printer
      @port = port if port.present?
      @baud = baud if baud.present?
      @port = self.port if self.port.present?
      @baud = self.baud if self.baud.present?
      if @port.present? && @baud.present?
        disable_hup(@port)
        @printer = SerialPort.new(@port, @baud)
        @printer.read_timeout = 0
        @stop_read_thread = false
        @read_thread = Thread.new(_listen)
        connect_callback.call if connect_callback.present? && connect_callback.respond_to?(:call)
      end
    end

    def reset
      @printer.dtr = 0
      sleep 0.2
      @printer.dtr = 1
    end

    def _readline
      begin
        line = @printer.readline
        if line.length > 1
          @log.push line
          receive_callback.call(line) if receive_callback.present? && receive_callback.respond_to?(:call)
        end
        line # return the line
      rescue EOFError, Errno::ENODEV => e
        # TODO: Do something useful
      end
    end

    def _listen_can_continue?
      !@stop_read_thread && @printer
    end

    def _listen_until_online
      catch 'BreakOut' do
        while !@online && _listen_can_continue? do
          _send(RintCore::GCode::Codes::GET_EXT_TEMP)
          empty_lines = 0
          while _listen_can_continue? do
            line = _readline
            throw 'BreakOut' if line.nil?
            line.blank? ? empty_lines += 1 : empty_lines = 0
            throw 'BreakOut' if empty_lines == 5
            if line.start_with?(*@greetings, @good_response)
              online_callback.call if online_callback.present? && online_callback.respond_to?(:call)
              @online = true
              return true
            end
            sleep 0.25
          end
        end
      end
    end

    def _listen
      @clear = true
      _listen_until_online unless @printing
      while _listen_can_continue? do
        line = _readline
        break if line.nil?
        debug_callback.call(line) if line.start_with?('DEBUG_') && debug_callback.present? && debug_callback.respond_to?(:call)
        @clear = true if line.start_with?(*@greetings, @good_response)
        temperature_callback.call(line) if line.start_with?(@good_response) && line.include?('T:') && temperature_callback.present? && temperature_callback.respond_to?(:call)
        error_callback.call(line) if line.start_with?('Error') && error_callback.present? && error_callback.respond_to?(:call)
        if line.downcase.start_with?(*@resend_response)
          line = line.sub('N:', ' ').sub('N', ' ').sub(':', ' ')
          linewords = line.split
          @resend_from = linewords.pop(0).to_i
          @clear = true
        end
      end
      @clear = true
    end

    def _checksum(command)
      command.bytes.inject{|a,b| a^b}.to_s
    end

    def start_print(data, start_index = 0)
      return false if @printing || !@online || !@printer
      @printing = true
      @main_queue = [] + data
      @line_number = 0
      @queue_index = start_index
      @resend_from = -1
      _send(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
      return true if data.blank?
      @clear = false
      @print_thread = Thread.new(_print)
      return true
    end

    def pause
      return false unless @printing
      @paused = true
      @printing = false
      @print_thread.join
      @print_thread = nil
    end

    def resume
      return false unless @paused
      @paused = false
      @printing = true
      @print_thread = Thread.new(_print)
    end

    def send(command, wait = 0)
      if @online
        if @printing
          @main_queue.push(command)
        else
          while @printer && @printing && !@clear do
            sleep(@sleep_time)
          end
          wait = @wait if wait == 0 && @wait > 0
          @clear = false if wait > 0
          _send(command, @line_number, true)
          @line_number += 1
          while wait > 0 && @printer && @printing && !@clear do
            sleep @sleep_time
            wait -= 1
          end
        end
      else
        # TODO: log something about not being connected to printer
      end
    end

    def send_now(command, wait = 0)
      if @online
        if @printing
          @priority_queue.append(command)
        else
          while @printer && @printing && !@clear do
            sleep(@sleep_time)
          end
          wait = @wait if wait == 0 && @wait > 0
          @clear = false if wait > 0
          _send(command)
          while wait > 0 && @printer && @printing && !@clear do
            sleep @sleep_time
            wait -= 1
          end
        end
      else
        # TODO: log something about not being connected to printer
      end
    end

    def _print
      start_callback.call if start_callback.present? && start_callback.respond_to?(:call)
      while @printing && @printer && @online do
        _send_next
      end
      @sent_lines = []
      @log = []
      @sent = []
      @print_thread.join
      @print_thread = nil
      end_callback.call if end_callback.present? && end_callback.respond_to?(:call)
      return true
    end

    def _send_next
      return false unless @printer
      while @printer && @printing && !@clear do
        sleep(@sleep_time)
      end
      @clear = false
      unless @printing && @printer && @online
        @clear = true
        return true
      end
      if @resendfrom < @lineno && @resendfrom > -1
        _send(@sent_lines[@resend_from], @resend_from, false)
        @resend_from += 1
        return true
      end
      @resend_from = -1
      unless @priority_queue.blank?
        _send(@priority_queue.pop(0))
        return true
      end
      if @printing && @queue_index < @main_queue.length
        current_line = @main_queue[@queue_index]
        current_line = current_line.split(RintCore::GCode::Codes::COMMENT_SYMBOL)[0]
        unless current_line.blank?
          _send(current_line, @line_number, true)
          @line_number += 1
        else
          @clear = true
        end
        @queue_index += 1
      else
        @printing = false
        @clear = true
        unless @paused
          @queue_index = 0
          @line_number = 0
          _send(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
        end
      end
    end

    def _send(command, line_number = 0, calc_checksum = false)
      if calc_checksum
        prefix = 'N' + line_number.to_s + ' ' + command
        command = prefix + '*' + _checksum(prefix)
        @sent_lines[line_number] = command unless command.include?(RintCore::GCode::Codes::SET_LINE_NUM)
      end
      if @printer
        @sent.push(command)
        send_callback.call(command) if send_callback.present? && send_callback.respond_to?(:call)
        command = command+"\n"
        command = command.encode(@encoding)
        @printer.write(command)
      end
    end

    def online?
      @online
    end

    def printing?
      @printing
    end

  end
end