require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    # Controls the print queue and manages the sending of commands while printing.
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
            sendsend_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
          end
          return true
        end
      end

      def resend_line
        if @resend_from == @line_number
          @resend_from = -1
          return nil
        elsif @resend_from < @line_number && @resend_from > -1
          send_to_printer(@machine_history[@resend_from], @resend_from, false)
          @resend_from += 1
          return true
        end
      end

      def run_priority_queue
        send!(@priority_queue.shift) if @priority_queue.present?
      end

      def run_main_queue
        if !paused? && @queue_index < @main_queue.length
          current_line = @main_queue[@queue_index]
          current_line = apply_multipliers(current_line) unless current_line.class == String
          if current_line.present?
            send_to_printer(current_line, @line_number, true)
            @line_number += 1
          end
          @queue_index += 1
          return true
        end
      end

      def apply_multipliers(line)
        line.speed_multiplier = config.speed_multiplier if config.speed_multiplier.present?
        line.extrusion_multiplier = config.extrusion_multiplier if config.extrusion_multiplier.present?
        line.travel_multiplier = config.travel_multiplier if config.travel_multiplier.present?
        line.to_s
      end

    end
  end
end