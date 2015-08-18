require 'origen'
require_relative '../config/application.rb'

module OrigenSWD
  autoload :Driver, 'origen_swd/driver'

  # Returns an instance of the OrigenSWD::Driver
  def swd
    @swd ||= Driver.new(self)
  end
end
