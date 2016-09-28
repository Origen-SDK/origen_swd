module OrigenSWDDev
  # This is a dummy DUT model which is used
  # to instantiate and test the SWD locally
  # during development.
  #
  # It is not included when this library is imported.
  class DUT
    include Origen::TopLevel
    include OrigenSWD

    # Initializes simple dut model with test register and required swd pins
    #
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   $dut = OrigenSWD::DUT.new
    #
    def initialize(options = {})
      # Sample DPACC register
      add_reg :test, 0x04, 32, data: { pos: 0, bits: 32 },
                               bit:  { pos: 2 }

      # Sample DPACC register
      add_reg :select, 0x08, 32, data: { pos: 0, bits: 32 }

      # Sample APACC register
      add_reg :stat, 0x00, 32, data: { pos: 0, bits: 32 }
      add_reg :control, 0x01, 32, data: { pos: 0, bits: 32 }

      add_pin :swd_clk
      add_pin :swd_dio
    end

    # Add any custom startup business here.
    #
    # @param [Hash] options Options to customize the operation
    def startup(options = {})
      $tester.set_timeset('swd', 40)
    end
  end
end
