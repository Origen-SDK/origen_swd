module OrigenSWD
  # To use this driver the owner model must define the following pins (an alias is fine):
  #   :swd_clk
  #   :swd_dio
  #
  class Driver
    REQUIRED_PINS = [:swd_clk, :swd_dio]

    include Origen::Registers

    # Returns the parent object that instantiated the driver, could be
    # either a DUT object or a protocol abstraction
    attr_reader :owner
    attr_accessor :trn

    # Initialize class variables
    #
    # @param [Object] owner Parent object
    # @param [Hash] options Options to customize the operation
    #
    # @example
    #   # Create new SWD::Driver object
    #   DUT.new.swd
    #
    def initialize(owner, options = {})
      @owner = owner
      # validate_pins

      @current_apaddr = 0
      @orundetect = 0
      @trn = 0
    end

    # Read data from Debug Port or Access Port
    #
    # @param [Integer] ap_dp A single bit indicating whether the Debug Port or the Access Port
    #   Register is to be accessed.  This bit is 0 for an DPACC access, or 1 for a APACC access
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def read(ap_dp, reg_or_val, options = {})
      addr = reg_or_val.respond_to?(:address) ? reg_or_val.address : reg_or_val
      send_header(ap_dp, 1, addr)       # send read-specific header (rnw = 1)
      receive_acknowledgement
      receive_payload(reg_or_val, options)
    end

    # Write data to Debug Port or Access Port
    #
    # @param [Integer] ap_dp A single bit indicating whether the Debug Port or the Access Port Register
    #   is to be accessed.  This bit is 0 for an DPACC access, or 1 for a APACC access
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Integer] wdata Data to be written
    # @param [Hash] options Options to customize the operation
    def write(ap_dp, reg_or_val, wdata, options = {})
      addr = reg_or_val.respond_to?(:address) ? reg_or_val.address : reg_or_val
      send_header(ap_dp, 0, addr)       # send write-specific header (rnw = 0)
      receive_acknowledgement

      if reg_or_val.respond_to?(:data)
        reg_or_val.data = wdata
      else
        reg_or_val = wdata
      end
      send_payload(reg_or_val, options)
    end

    # Sends data stream with SWD protocol
    #
    # @param [Integer] data Data to be sent
    # @param [Integer] size The length of data
    # @param [Hash] options Options to customize the operation
    # @option options [String] :overlay String for pattern label to
    #   facilitate pattern overlay
    def send_data(data, size, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use swd.write(ap_dp, reg_or_val, wdata, options = {}) instead of send_data(data, size, options = {})'
      Origen.deprecate msg
      if options.key?(:overlay)
        $tester.label(options[:overlay])
        size.times do |bit|
          swd_clk.drive(1)
          $tester.label("// SWD Data Pin #{bit}")
          swd_dio.drive(data[bit])
          $tester.cycle
        end
        swd_dio.dont_care
      else
        size.times do |bit|
          swd_clk.drive(1)
          swd_dio.drive(data[bit])
          $tester.cycle
        end
        swd_dio.dont_care
      end
    end

    # Recieves data stream with SWD protocol
    #
    # @param [Integer] size The length of data
    # @param [Hash] options Options to customize the operation
    # @option options [String] :compare_data Data to be compared, only compared
    #   if options is set
    def get_data(size, options = {})
      # Warn caller that this method is being deprecated
      msg = 'Use swd.read(ap_dp, reg_or_val, options = {}) instead of get_data(size, options = {})'
      Origen.deprecate msg
      should_store = swd_dio.is_to_be_stored?
      swd_dio.dont_care
      size.times do |bit|
        $tester.store_next_cycle($dut.pin(:swd_dio)) if should_store
        swd_dio.assert(options[:compare_data][bit]) if options.key?(:compare_data)
        $tester.cycle
      end
    end

    # Sends specified number of '0' bits
    #
    # @param [Integer] size The length of data
    def swd_dio_to_0(size)
      swd_dio.drive(0)
      size.times do |bit|
        $tester.cycle
      end
    end

    private

    # Send SWD Packet header
    #   ------------------------------------------------------------------------
    #   | Start | APnDP |   1   | ADDR[2] | ADDR[3] | Parity |  Stop  |  Park  |
    #   ------------------------------------------------------------------------
    #
    # @param [Integer] apndp A single bit indicating whether the Debug Port or the Access Port
    #   Register is to be accessed.  This bit is 0 for an DPACC access, or 1 for a APACC access
    # @param [Integer] rnw A single bit, indicating whether the access is a read or a write.
    #   This bit is 0 for a write access, or 1 for a read access.
    # @param [Integer] address Address of register that is being accessed
    def send_header(apndp, rnw, address)
      addr = address >> 2
      parity  = apndp ^ rnw ^ (addr >> 3) ^ (addr >> 2) & (0x01) ^ (addr >> 1) & (0x01) ^ addr & 0x01

      cc 'Header phase'
      swd_clk.drive(1)
      cc 'Send Start Bit'
      swd_dio.drive!(1)                                   # send start bit (always 1)
      cc 'Send APnDP Bit (DP or AP Access Register Bit)'
      swd_dio.drive!(apndp)                               # send apndp bit
      cc 'Send RnW Bit (read or write bit)'
      swd_dio.drive!(rnw)                                 # send rnw bit
      cc 'Send Address Bits (2 bits)'
      swd_dio.drive!(addr[0])                             # send address[2] bit
      swd_dio.drive!(addr[1])                             # send address[3] bit
      cc 'Send Parity Bit'
      swd_dio.drive!(parity[0])                           # send parity bit
      cc 'Send Stop Bit'
      swd_dio.drive!(0)                                   # send stop bit
      cc 'Send Park Bit'
      swd_dio.drive!(1)                                   # send park bit
      swd_dio.dont_care
    end

    # Waits appropriate number of cycles for the acknowledgement phase
    def receive_acknowledgement
      cc 'Acknowledge Response phase'
      wait_trn
      swd_dio.dont_care
      $tester.cycle(repeat: 3)
    end

    # Waits for TRN time delay
    def wait_trn
      swd_dio.drive(1)
      $tester.cycle(repeat: trn + 1)
    end

    # Get (read) the data payload
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be read. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @option options [String] :overlay String for pattern label to
    #   facilitate pattern overlay
    def receive_payload(reg_or_val, options)
      cc 'Read Data Payload phase'

      cc 'SWD 32-Bit Read Data Start'
      options[:read] = true
      shift_payload(reg_or_val, options)

      cc 'SWD 32-Bit Read Data End'
      cc 'Get Read Parity Bit'
      swd_dio.dont_care
      $tester.cycle
      cc 'Send Read ACK bits'
      wait_trn
    end

    # Send (write) the data payload
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be written. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @option options [String] :overlay String for pattern label to
    #   facilitate pattern overlay
    def send_payload(reg_or_val, options)
      cc 'Write Data Payload phase'
      cc 'Send ACK Bits'
      wait_trn

      cc 'SWD 32-Bit Write Start'
      options[:read] = false
      shift_payload(reg_or_val, options)

      cc 'Send Write Parity Bit'
      wdata = reg_or_val.respond_to?(:data) ? reg_or_val.data : reg_or_val
      parity_bit = swd_xor_calc(32, wdata)
      swd_dio.drive!(parity_bit)
    end

    # Shift the data payload
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @option options [String] :overlay String for pattern label to
    #   facilitate pattern overlay
    def shift_payload(reg_or_val, options)
      cc options[:arm_debug_comment] if options.key?(:arm_debug_comment)
      size = 32    # SWD only used to write to DP and AP registers of ARM Debugger (32 bits)
      contains_bits = (contains_bits?(reg_or_val) || is_a_bit?(reg_or_val))
      if options.key?(:arm_debug_overlay)
        options[:overlay] = options[:arm_debug_overlay]
        options[:overlay_label] = options[:arm_debug_overlay]
      end
      if options.key?(:overlay)
        if options[:overlay_label].nil?
          options[:overlay_label] = options[:overlay]
          $tester.label(options[:overlay_label]) if options.key?(:overlay)
        end
      end
      swd_clk.drive(1)
      size.times do |i|
        if options[:read]
          # If it's a register support bit-wise reads
          if contains_bits
            if reg_or_val[i].is_to_be_stored?
              Origen.tester.store_next_cycle(swd_dio)
              swd_dio.dont_care if Origen.tester.j750?
            elsif reg_or_val[i].has_overlay?
              $tester.label(reg_or_val[i].overlay_str)
            elsif reg_or_val[i].is_to_be_read?
              swd_dio.assert(reg_or_val[i] ? reg_or_val[i] : 0)
            elsif options.key?(:compare_data)
              swd_dio.assert(reg_or_val[i] ? reg_or_val[i] : 0)
            else
              swd_dio.dont_care
            end
          else
            if options.key?(:compare_data)
              swd_dio.assert(reg_or_val[i] ? reg_or_val[i] : 0)
            else
              swd_dio.dont_care
            end
          end
          $tester.cycle
        else
          $tester.label("// SWD Data Pin #{i}") if options.key?(:overlay) && !Origen.mode.simulation?
          swd_dio.drive!(reg_or_val[i])
        end
      end
      # Clear read and similar flags to reflect that the request has just
      # been fulfilled
      reg_or_val.clear_flags if reg_or_val.respond_to?(:clear_flags)
      swd_dio.dont_care
    end

    # Calculate exclusive OR
    #
    # @param [Integer] size The number of bits in the number
    # @param [Integer] number The number being operated on
    def swd_xor_calc(size, number)
      xor = 0
      size.times do |bit|
        xor ^= (number >> bit) & 0x01
      end
      xor
    end

    # Provided shortname access to top-level SWD clock pin
    def swd_clk
      owner.pin(:swd_clk)
    end

    # Provided shortname access to top-level SWD data I/P pin
    def swd_dio
      owner.pin(:swd_dio)
    end
  end
end
