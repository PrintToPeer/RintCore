require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    # Controls the print queue and manages the sending of commands while printing.
    module Queueing

      # Clears the printer's queues.
      # @return [Boolean] true if successful, false otherwise.
      def clear_queues!
        if printing?
          false
        else
          initialize_queueing
          true
        end
      end

private

      def initialize_queueing
        @gcode_object = nil
        @current_layer = nil
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
            send_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1, true)
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
        send_to_printer(@priority_queue.shift) if @priority_queue.present?
      end

      def run_main_queue
        if !paused? && @queue_index < @gcode_object.lines.length
          current_line = @gcode_object.lines[@queue_index]
          current_line = apply_multipliers(current_line)
          @current_layer = @gcode_object.in_what_layer?(@queue_index)
          send_to_printer(current_line, @line_number, true)
          @line_number += 1
          @queue_index += 1
          return true
        end
      end

      def apply_multipliers(line)
        line.speed_multiplier = config.speed_multiplier if config.speed_multiplier.present?
        line.extrusion_multiplier = config.extrusion_multiplier if config.extrusion_multiplier.present?
        line.travel_multiplier = config.travel_multiplier if config.travel_multiplier.present?
        line
      end

    end
  end
end