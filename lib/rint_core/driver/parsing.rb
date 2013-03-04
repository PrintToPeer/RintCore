require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    # Handles the parsing of printer responses and formats commands sent to the printer.
    module Parsing

private
      def format_command(command)
        (command.strip + "\n").split(RintCore::GCode::Codes::COMMENT_SYMBOL).first.encode(config.encoding)
      end

      def get_checksum(command)
        command.bytes.inject{|a,b| a^b}.to_s
      end

      def prefix_command(command, line_number)
        prefix = ('N' + line_number.to_s + ' ' + command.strip).encode(config.encoding)
        prefix+'*'+get_checksum(prefix)
      end

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

      def get_resend_number(line)
        line.sub('N:', '').sub('N', '').sub(':', '').strip.split.first.to_i
      end

    end
  end
end