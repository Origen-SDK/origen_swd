module OrigenSWD
  # This is a dummy DUT model which is used
  # to instantiate and test the SWD locally
  # during development.
  #
  # It is not included when this library is imported.
  class DUT
    include OrigenSWD
    include Origen::Callbacks
    include Origen::Registers
    include Origen::Pins

    # Initializes simple dut model with test register and required swd pins
    # options - any miscellaneous custom arguments
    # Returns nothing.
    #
    # Examples
    #
    #   $dut = OrigenSWD::DUT.new
    #
    def initialize(options = {})
      add_reg :test, 0x0, 32, data: { pos: 0, bits: 32 },
                              bit:  { pos: 0 }
      add_pin :swd_clk
      add_pin :swd_dio
    end

    # Add any custom startup business here.
    # options - any miscellaneous custom arguments
    # Returns nothing.
    def startup(options = {})
      $tester.set_timeset('swd', 40)
    end
  end
end
