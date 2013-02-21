require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    module State

      def connect!
        disconnect if connected?
        if config.port.present? && config.baud.present?
          disable_hup(config.port)
          @connection = SerialPort.new(config.port, config.baud)
          @connection.read_timeout = config.read_timeout
          @stop_read_thread = false
          @read_thread = Thread.new(listen)
          config.callbacks[:connect].call if callbacks[:connect].present?
        end
      end

      def disconnect!
        if connected? 
          if @read_thread
            @stop_read_thread = true
            @read_thread.join
            @read_thread = nil
          end
          @connection.close
        end
        @connection = nil
        offline!
        not_printing!
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
      end

      def resume!
        return false unless @paused
        @paused = false
        printing!
        @print_thread = Thread.new(print!)
      end

      def connected?
        @connection.present?
      end

      def clear_to_send?
        @clear
      end

      def online?
        @online
      end

      def paused?
        @paused
      end

      def printing?
        @printing
      end

private

      def initialize_state
        @clear = false
        @online = false
        @printing = false
        @paused = false
      end

      def clear_to_send!
        @clear = true
      end

      def not_clear_to_send!
        @clear = false
      end

      def online!
        @online = true
      end

      def offline!
        @online = false
      end

      def printing!
        @printing = true
      end

      def not_printing!
        @printing = false
      end
    end
  end
end