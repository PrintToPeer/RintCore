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
    self.online_response = ['start','Grbl']
    self.good_response = ['ok']
    self.temperature_response = 'T:'
    self.resend_response = ['rs','resend']
    self.encoding = 'us-ascii'
    self.sleep_time = 0.001
    self.wait_period = 0
    self.read_timeout = 0
    self.long_sleep = 0.25

    attr_reader :last_line_received, :main_queue, :queue_index, :resend_from, :machine_history, :full_history

    def initialize(auto_connect = false)
      initialize_driver
      connect! if auto_connect
    end

    def time_from_start
      @start_time ||= Time.now
      secs = Time.now - @start_time
      [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].map{ |count, name|
        if secs > 0
          secs, n = secs.divmod(count)
          "#{n.to_i} #{name}"
        end
      }.compact.reverse.join(' ')
    end

    class << self
      def baud_rates
        [2400, 9600, 19200, 38400, 57600, 115200, 250000]
      end

      def is_port?(port)
         port.present? && File.exist?(port) && File.new(port).isatty
      end
    end

  end
end