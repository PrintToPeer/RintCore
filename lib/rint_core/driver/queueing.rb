require 'rint_core/g_code/codes'

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
        @current_layer = 0
        @priority_queue = []
        @queue_index = 0
        @line_number = 0
        @resend_from = -1
        @machine_history = []
      end

      def advance_queue
        return false unless online? && printing?
        wait_until_clear
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
            send_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1)
          end
          return true
        end
      end

      def resend_line
        if @resend_from == @line_number
          @resend_from = -1
          return nil
        elsif @resend_from < @line_number && @resend_from > -1
          send_to_printer(@machine_history[@resend_from], @resend_from)
          @resend_from += 1
          return true
        end
      end

      def run_priority_queue
        result = send_to_printer(@priority_queue.shift) unless @priority_queue.empty?
        result
      end

      def run_main_queue
        return nil if paused?
        if @queue_index < @gcode_object.length
          unless config.low_power
            apply_multipliers
            @current_layer = @gcode_object.in_what_layer?(@queue_index)
          end
          send_to_printer(@gcode_object[@queue_index], @line_number)
          @line_number += 1
          @queue_index += 1
          return true
        end
      end

      def apply_multipliers
        @gcode_object.lines[@queue_index].speed_multiplier = config.speed_multiplier unless config.speed_multiplier.nil?
        @gcode_object.lines[@queue_index].extrusion_multiplier = config.extrusion_multiplier unless config.extrusion_multiplier.nil?
        @gcode_object.lines[@queue_index].travel_multiplier = config.travel_multiplier unless config.travel_multiplier.nil?
      end

    end
  end
end