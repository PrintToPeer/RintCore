require 'rint_core/g_code'
require 'serialport'
require 'active_support/core_ext/object/blank'
require 'active_support/configurable'

module RintCore
  class Printer
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

    def initialize
      @baud = baud.present? ? baud : nil
      @port = port.present? ? port : nil
      @printer = nil # Serial instance connected to the printer, nil when disconnected
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

      OnlinePrintingCheck = Proc.new { @printing && @printer && @online }
      ClearPrintingCheck = Proc.new { @printer && @printing && !@clear }
      WaitCheck = Proc.new { |wait| wait > 0 && ClearPrintingCheck }
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
      return false if @printing || !@online || !@printer
      @printing = true
      @main_queue = [] + data
      @line_number = 0
      @queue_index = start_index
      @resend_from = -1
      send!(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
      return true if data.blank?
      @clear = false
      @print_thread = Thread.new(print!)
      return true
    end

private

    def prefix_command(command, line_number)
      prefix = 'N' + line_number.to_s + ' ' + command
      command = prefix + '*' + line_checksum(prefix)
    end

    def line_checksum(command)
        command.bytes.inject{|a,b| a^b}.to_s
    end

    def readline!
      begin
        line = @printer.readline
        if line.length > 1
          receive_callback.call(line) if receive_callback.respond_to?(:call)
        end
        line # return the line
      rescue EOFError, Errno::ENODEV => e
        # TODO: Do something useful
      end
    end

    def listen_can_continue?
      !@stop_read_thread && @printer
    end

    def _listen_until_online
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

    def _listen
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

    def print!
      start_callback.call if start_callback.respond_to?(:call)
      while OnlinePrintingCheck.call do
        advance_queue
      end
      @sent_lines = []
      @print_thread.join
      @print_thread = nil
      end_callback.call if end_callback.respond_to?(:call)
      return true
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