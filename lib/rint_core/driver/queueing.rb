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
        @queue_length = 0
        @line_number = 0
        @resend_from = -1
        @machine_history = []
      end

      def advance_queue
        p "Advancing"
        return false unless online? && printing?
        p "Advancing 1"
        wait_until_clear
        not_clear_to_send!
        p "Advancing 2"
        return true if resend_line
        p "Advancing 3"
        return true if run_priority_queue
        p "Advancing 4"
        run_result = @file_handle.nil? ? run_main_queue : run_file_queue
        if run_result
          return true
          p "RUN REZULT"
        else
          p "NOT PRINTING"
          not_printing!
          unless paused?
            p "OJH PAUZED"
            @queue_index = 0
            @line_number = 0
            send_to_printer(RintCore::GCode::Codes::SET_LINE_NUM, -1)
          end
          p "Closing file!111"
          @file_handle.close unless @file_handle.nil?
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

      def run_file_queue
        p "RUN FILE QUQUEUEU"
        line = @file_handle.get_line(@queue_index)
        return false if line.nil?
        line = line.split(";")[0].strip
        p "SEND TO PRINTER RUN FILE QWUEUEU 111"
        return true if line.empty?

        p "SEND TO PRINTER RUN FILE QWUEUEU"
        send_to_printer(line, @line_number)
        callbacks[:current_line_number].call(@line_number) unless config.callbacks[:current_line_number].nil?
      end

      def run_priority_queue
        send_to_printer(@priority_queue.shift) unless @priority_queue.empty?
      end

      def run_main_queue
        p "Run main ququeueueu 111"
        return nil if paused?
        p "Run main ququeueueu 22"
        if @queue_index < @queue_length
          p "Run main ququeueueu 3"
          unless config.low_power
            apply_multipliers
            p "Run main ququeueueu 4 INSUDE ULESS"
            current_layer = @current_layer
            @current_layer = @gcode_object.in_what_layer?(@queue_index)
            config.callbacks[:layer_change] if !config.callbacks[:layer_change].nil? && @current_layer > current_layer
          end
          p "Run main ququeueueu 4"
          send_to_printer(@gcode_object[@queue_index], @line_number)
          @line_number += 1
          @queue_index += 1
          p "Run main ququeueueu RETURN TRUE"
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