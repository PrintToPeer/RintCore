require 'rint_core/driver'
require 'active_support/configurable'
require 'rint_core/pretty_output'

module RintCore
  # Interface for directly intereacting with the printer.
  class Printer
    include RintCore::Driver
    include RintCore::PrettyOutput
    include ActiveSupport::Configurable

    # @!macro config_accessor
    #   @!attribute [rw] $1
    #     @return [String] port that the printer is connected to.
    #   @!attribute [rw] $2
    #     @return [Fixnum] baud rate that the printer communicates at, value is not checked against {baud_rates}.
    #   @!attribute [rw] $3
    #     @return [Hash<Proc>] procs that are called at places in the code that correlate with their key.
    #     @todo make a list of all the callbacks that are used
    #   @!attribute [rw] $4
    #     @return [String] the response or prefix the printer sends when it encounters an error.
    #   @!attribute [rw] $5
    #     @return [String] the response or prefix the printer attaches to debugging messages.
    #   @!attribute [rw] $6
    #     @return [Array] the response(s) or prefix(es) the printer sends when it has successfully started.
    #   @!attribute [rw] $7
    #     @return [Array] the response(s) or prefix(es) the printer sends when it has received or executed a command.
    #   @!attribute [rw] $8
    #     @return [Array] the sequences of character the printer sends when it is reporting temperature information.
    #   @!attribute [rw] $9
    #     @return [Array] the response(s) or prefix(es) the printer sends when it needs lines resent.
    #   @!attribute [rw] $10
    #     @return [String] the character set that the printer uses to communicate.
    #     @todo make this have an effect on received responses.
    #   @!attribute [rw] $11
    #     @return [Float] the amount of time to sleep while waiting for the line to become clear before sending.
    #   @!attribute [rw] $12
    #     @return [Fixnum] read timeout value for the serial port.
    #   @!attribute [rw] $13
    #     @return [Float] used in various places while waiting for responses from the printer.
    #   @!attribute [rw] $14
    #     @return [Float] speed multiplier (print moves only).
    #   @!attribute [rw] $15
    #     @return [Float] extrusion multiplier.
    #   @!attribute [rw] $16
    #     @return [Float] travel move speed multiplier.
    #   @!attribute [rw] $17
    #     @return [Boolean] reduce the number of operations at print time for low power devices (Raspberry Pi).
    config_accessor :port, :baud, :callbacks, :error_response, :debug_response,
                    :online_response, :good_response, :temperature_response,
                    :resend_response, :encoding, :sleep_time, :read_timeout,
                    :long_sleep, :speed_multiplier, :extrusion_multiplier,
                    :travel_multiplier, :low_power

    self.port = "/dev/ttyACM0"
    self.baud = 115200
    self.callbacks = {}
    self.error_response = 'error'
    self.debug_response = 'DEBUG_'
    self.online_response = ['start','Grbl']
    self.good_response = ['ok']
    self.temperature_response = ['T:']
    self.resend_response = ['rs','resend']
    self.encoding = 'us-ascii'
    self.sleep_time = 0.001
    self.read_timeout = 0
    self.long_sleep = 0.25
    self.low_power = false

    # @!macro attr_reader
    #   @!attribute [r] $1
    #     @return [String] the last line read from the printer
    #   @!attribute [r] $2
    #     @return [RintCore::GCode::Object] GCode object that is printing.
    #   @!attribute [r] $3
    #     @return [Fixnum] 0 if not printing, other wise indicates the position in {#gcode_object}
    #   @!attribute [r] $4
    #     @return [Fixnum] normally -1, other wise indicates the position to resend data from in {#machine_history}.
    #   @!attribute [r] $5
    #     @return [Fixnum] layer currently being printed.
    #     @return [nil] if not printing.
    attr_reader :last_line_received, :gcode_object, :queue_index, :resend_from, :current_layer

    # Creates a new {Printer} instance.
    # @param auto_connect [Boolean] if true, {#connect!} will be called.
    # @return [Printer] a new instance of RintCore::Printer
    def initialize(auto_connect = false)
      initialize_driver
      connect! if auto_connect
    end

    # Returns the time since a print has started in human readable format, returns "0 seconds" if not printing.
    # @return [String] human readable time since print started, or "0 seconds" if not printing.
    def time_from_start
      start_time ||= @start_time
      start_time ||= Time.now
      seconds_to_words(Time.now-@start_time)
    end

    class << self
      # An array of standard serial port baud rates, useful for checking for a valid configuration.
      # @return [Array] of standard serial port baud rates.
      def baud_rates
        [2400, 9600, 19200, 38400, 57600, 115200, 250000]
      end

      # A function that checks if the given file exists and is a tty, useful for checking for a valid configuration.
      # @param port [String] a path on the local file system.
      # @return [Boolean] true if given path is a tty, false otherwise.
      def is_port?(port)
         !port.nil? && File.exist?(port) && File.new(port).isatty
      end
    end

  end
end