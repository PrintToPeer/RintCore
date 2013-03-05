require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    # Handles the parsing of printer responses and formats commands sent to the printer.
    module Parsing

private
      
      def get_response_type(line)
        case
        when ( !line.present? || !line.is_a?(String) )
          :invalid
        when line.include?(config.error_response)
          :error
        when line.include?(config.debug_response)
          :debug
        when line.start_with?(*config.online_response)
          :online
        when ( line.start_with?(*config.good_response) && !line.include?(*config.temperature_response) )
          :valid
        when ( line.start_with?(*config.good_response) && line.include?(*config.temperature_response) )
          :temperature_response
        when ( !line.start_with?(*config.good_response) && line.include?(*config.temperature_response) )
          :temperature
        when line.start_with?(*config.resend_response)
          :resend
        else
          :invalid
        end
      end

      def format_command(line)
        (line + "\n").encode(config.encoding)
      end

      def get_resend_number(line)
        line.sub('N:', '').sub('N', '').sub(':', '').strip.split.first.to_i
      end

    end
  end
end