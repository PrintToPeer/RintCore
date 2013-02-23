require 'rint_core/g_code/codes'
require 'active_support/core_ext/object/blank'

module RintCore
  module Driver
    module Parsing

      def format_command(command)
        (command.strip + "\n").split(RintCore::GCode::Codes::COMMENT_SYMBOL).first.encode(config.encoding)
      end

      def get_checksum(command)
        command.bytes.inject{|a,b| a^b}.to_s
      end

      def prefix_command(command, line_number)
        prefix = ('N' + line_number.to_s + ' ' + command.strip).encode(config.encoding)
        prefix + ' ' + '*' + get_checksum(prefix)
      end

      def get_response_type(line)
        return :invalid unless line.present? || line.class == String
        return :error if line.include?(config.error_response)
        return :debug if line.include?(config.debug_response)
        return :online if line.start_with?(*config.online_response)
        return :valid if line.start_with?(*config.good_response) && !line.include?(config.temperature_response)
        return :temperature if line.start_with?(*config.good_response) && line.include?(config.temperature_response)
        return :resend if line.start_with?(*config.resend_response)
        return :invalid
      end

      def get_resend_number(line)
        line.sub('N:', '').sub('N', '').sub(':', '').strip.split.first.to_i
      end

    end
  end
end