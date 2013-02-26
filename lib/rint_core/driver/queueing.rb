require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    module Queueing

private

      def initialize_queueing
        @main_queue = []
        @priority_queue = []
        @queue_index = 0
        @line_number = 0
        @resend_from = -1
        @machine_history = []
      end

      def advance_queue
        return false unless online? && printing?
        until clear_to_send? do
          sleep(config.sleep_time)
        end
        not_clear_to_send!
        return true if resend_line
        return true if run_priority_queue
        if run_main_queue
          return true
        else
          not_printing!
          unless paused?
            @queue_index = 0
            @line_number = 0
            send!(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
          end
          return true
        end
      end

      def resend_line
        if @resend_from == @line_number
          @resend_from = -1
          return nil
        elsif @resend_from < @line_number && @resend_from > -1
          send!(@machine_history[@resend_from], @resend_from, false)
          @resend_from += 1
          return true
        end
      end

      def run_priority_queue
        unless @priority_queue.blank?
          send!(@priority_queue.shift)
          # clear_to_send!
        end
      end

      def run_main_queue
        if !paused? && @queue_index < @main_queue.length
          current_line = @main_queue[@queue_index]
          current_line = current_line.to_s unless current_line.class == String
          unless current_line.blank?
            send!(current_line, @line_number, true)
            @line_number += 1
          end
          @queue_index += 1
          return true
        end
      end

    end
  end
end