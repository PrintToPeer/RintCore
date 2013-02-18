require 'rint_core/g_code/codes'
module RintCore
  class GCode
    class << self
      def prefix_command(command, line_number)
        prefix = 'N' + line_number.to_s + ' ' + command
        command = prefix + '*' + line_checksum(prefix)
      end

      def line_checksum(command)
          command.bytes.inject{|a,b| a^b}.to_s
      end
      
    end

  end
end