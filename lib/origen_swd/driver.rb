module OrigenSWD
  # To use this driver the owner model must define the following pins (an alias is fine):
  #   :swd_clk
  #   :swd_dio
  #
  class Driver
    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner

    # Initialize class variables
    # owner - parent object
    # options - any miscellaneous custom arguments
    # Returns nothing.
    #
    # Examples
    #
    #   DUT.new.swd
    #
    def initialize(owner, options = {})
      @owner = owner
      @current_apaddr = 0
      @orundetect = 0
    end

    # Sends data stream with SWD protocol
    # data - data to be sent
    # size - the length of data
    # options - any miscellaneous custom arguments
    # options[:overlay] - string for pattern label to facilitate pattern overlay
    # Returns nothing.
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

    # Recieves data stream with SWD protocol
    # size - the length of data
    # options - any miscellaneous custom arguments
    # options[:compare_data] - data to be compared, only compared if options is set
    # Returns nothing.
    def get_data(size, options = {})
      should_store = $dut.pin(:swd_dio).is_to_be_stored?
      owner.pin(:swd_dio).dont_care
      size.times do |bit|
        $tester.store_next_cycle($dut.pin(:swd_dio)) if should_store
        $dut.pin(:swd_dio).assert(options[:compare_data][bit]) if options.key?(:compare_data)
        $tester.cycle
      end
    end

    # Sends specified number of '0' bits
    # size - the length of data
    # Returns nothing.
    def swd_dio_to_0(size)
      owner.pin(:swd_dio).drive(0)
      size.times do |bit|
        $tester.cycle
      end
    end
  end
end
