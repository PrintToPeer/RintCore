require 'rint_core/driver/operating_system'
require 'rint_core/driver/state'
require 'rint_core/driver/parsing'
require 'rint_core/driver/queueing'
require 'rint_core/driver/operations'

module RintCore
  # Conatians the elements of the printer driver.
  module Driver
    include RintCore::Driver::OperatingSystem
    include RintCore::Driver::State
    include RintCore::Driver::Parsing
    include RintCore::Driver::Queueing
    include RintCore::Driver::Operations
    
    # Calls the initialization functions of the submodules in the correct order
    def initialize_driver
      initialize_state
      initialize_queueing
      initialize_operations
    end

  end
end

# Modification to get a particular line from a file, used in low power or direct file printing mode.
class File
  def get_line(n)
    (n+1).times{self.gets}
    self.close
    $_
  end
end