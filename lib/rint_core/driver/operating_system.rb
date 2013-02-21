module RintCore
  module Driver
    module OperatingSystem
      def control_ttyhup(port, disable_hup)
        if get_os == :linux
          if disable_hup
            `stty -F #{port} -hup`
          else
            `stty -F #{port} hup`
          end
        end
      end

      def enable_hup(port)
        control_ttyhup(port, true)
      end

      def disable_hup(port)
        control_ttyhup(port, false)
      end

      def get_os
        return :linux if /linux/ =~ RUBY_PLATFORM
        return :mac if /darwin/ =~ RUBY_PLATFORM
        return :windows if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
        return :unknown
      end
    end
  end
end