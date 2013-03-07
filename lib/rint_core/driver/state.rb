require 'rint_core/g_code/codes'

module RintCore
  module Driver
    # keeps track of the driver's state
    module State

      # Checks if the printer can start a print.
      # @return [Boolean] true if printer is ready to print, false otherwise.
      def can_print?
        connected? && online? && !printing?
      end

      # Checks if printer is connected.
      # @return [Boolean] true if serial port connection is present, false otherwise.
      def connected?
        !@connection.nil?
      end

      # Checks if the printer is online.
      # @return [Boolean] true if online, false otherwise.
      def online?
        connected? && @online
      end

      # Checks if printing is paused.
      # @return [Boolean] true if pause, false otherwise.
      def paused?
        @paused
      end

      # Checks if the printer is currently printing.
      # @return [Boolean] true if printing, false otherwise.
      def printing?
        @printing
      end

private

      def initialize_state
        @clear = false
        @online = false
        @printing = false
        @paused = false
        @stop_listening = false
      end

      def clear_to_send?
        @clear && online?
      end

      def clear_to_send!
        @clear = true
      end

      def listen_can_continue?
        !@stop_listening && connected?
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