require 'origen'
require_relative '../config/application'

# Include this module to add a SWD driver to your class
module OrigenSWD
  autoload :Driver, 'origen_swd/driver'

  # Returns an instance of the OrigenSWD::Driver
  def swd
    @swd ||= Driver.new(self)
  end
end
