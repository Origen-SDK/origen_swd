module OrigenSWD
  # To use this driver the owner model must define the following pins (an alias is fine):
  #   :swd_clk
  #   :swd_dio
  #
  class Driver
    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner

    def initialize(owner, options = {})
      @owner = owner
      @current_apaddr = 0
      @orundetect = 0
    end

    # Hardware interface
    def send_data(data, size, options = {})
      if options.key?(:overlay)
        $tester.label(options[:overlay])
        size.times do |bit|
          owner.pin(:swd_clk).drive(1)
          $tester.label("// SWD Data Pin #{bit}")
          owner.pin(:swd_dio).drive(data[bit])
          $tester.cycle
        end
        owner.pin(:swd_dio).dont_care
      else
        size.times do |bit|
          owner.pin(:swd_clk).drive(1)
          owner.pin(:swd_dio).drive(data[bit])
          $tester.cycle
        end
        owner.pin(:swd_dio).dont_care
      end
    end

    def get_data(size, options = {})
      should_store = $dut.pin(:swd_dio).is_to_be_stored?
      owner.pin(:swd_dio).dont_care
      size.times do |bit|
        $tester.store_next_cycle($dut.pin(:swd_dio)) if should_store
        $dut.pin(:swd_dio).assert(options[:compare_data][bit]) if options.key?(:compare_data)
        $tester.cycle
      end
    end

    def swd_dio_to_0(size)
      owner.pin(:swd_dio).drive(0)
      size.times do |bit|
        $tester.cycle
      end
    end
  end
end
