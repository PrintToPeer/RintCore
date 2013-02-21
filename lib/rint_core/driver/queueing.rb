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
        @sent_lines = []
      end

      def advance_queue
        return false unless @connected || @printing || @online
        until @clear do
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
          clear_to_send!
          return true
        end
      end

      def resend_line
        if @resend_from == @line_number
          @resend_from = -1
          return nil
        elsif @resend_from < @line_number && @resend_from > -1
          send!(@sent_lines[@resend_from], @resend_from, false)
          @resend_from += 1
          return true
        end
      end

      def run_priority_queue
        unless @priority_queue.blank?
          send!(@priority_queue.pop(0))
          return true
        end
      end

      def run_main_queue
        if !paused? && @queue_index < @main_queue.length
          current_line = @main_queue[@queue_index].split(RintCore::GCode::Codes::COMMENT_SYMBOL)[0]
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