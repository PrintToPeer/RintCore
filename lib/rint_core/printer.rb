require 'rint_core/driver'
require 'active_support/configurable'

module RintCore
  class Printer
    include RintCore::Driver
    include ActiveSupport::Configurable

    # Callbacks are typically given a string argument, usually the current line
    config_accessor :port, :baud, :callbacks, :error_response, :debug_response,
                    :online_response, :good_response, :temperature_response,
                    :resend_response, :encoding, :sleep_time, :wait_period,
                    :read_timeout, :long_sleep

    self.port = "/dev/ttyACM0"
    self.baud = 115200
    self.callbacks = {}
    self.error_response = 'Error'
    self.debug_response = 'DEBUG_'
    self.online_response = ['start','Grbl ']
    self.good_response = ['ok']
    self.temperature_response = 'T:'
    self.resend_response = ['rs','resend']
    self.encoding = 'us-ascii'
    self.sleep_time = 0.001
    self.wait_period = 0
    self.read_timeout = 0
    self.long_sleep = 0.25

    attr_reader :last_line_received

    def initialize(auto_connect = false)
      initialize_driver
      connect! if auto_connect
    end

  end
end