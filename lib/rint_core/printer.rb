require 'rint_core/g_code'
require 'serialport'
require 'active_support/core_ext/object/blank'
require 'active_support/configurable'

module RintCore
  class Printer
    include ActiveSupport::Configurable

    # Callbacks are typically given a string argument, usually the current line
    config_accessor :port, :baud, :callbacks

    def initialize
      @baud = baud.present? ? baud : nil
      @port = port.present? ? port : nil
      @greetings = ['start','Grbl ']
      @wait = 0 # default wait period for send(), send_now()
      @good_response = 'ok'
      @resend_response = ['rs','resend']
      @sleep_time = 0.001
      @encoding = 'us-ascii'

      OnlinePrintingCheck = Proc.new { @printing && @printer && @online }
      ClearPrintingCheck = Proc.new { @printer && @printing && !@clear }
      WaitCheck = Proc.new { |wait| wait > 0 && ClearPrintingCheck }
    end


private

    def prefix_command(command, line_number)
      prefix = 'N' + line_number.to_s + ' ' + command
      command = prefix + '*' + line_checksum(prefix)
    end

    def line_checksum(command)
        command.bytes.inject{|a,b| a^b}.to_s
    end


  end
end