require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    module State

      def can_print?
        connected? && online? && !printing?
      end

      def connected?
        @connection.present?
      end

      def clear_to_send?
        @clear && online?
      end

      def listen_can_continue?
        !@stop_listening && connected?
      end

      def online?
        connected? && @online
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
        @stop_listening = false
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