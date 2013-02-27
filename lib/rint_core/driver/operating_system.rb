module RintCore
  module Driver
    # Utilities for performing OS level tasks
    module OperatingSystem

    # Return name of OS as a symbol.
    # @return [Symbol] name of OS as symbol.
    def get_os
      return :linux if /linux/ =~ RUBY_PLATFORM
      return :mac if /darwin/ =~ RUBY_PLATFORM
      return :windows if /cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM
      return :unknown
    end

private
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
    end
  end
end