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

    # Customiz-ible 'turn-round cycle' (TRN) parameter (in cycles)
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

      @current_apaddr = 0
      @orundetect = 0
      @trn = 0
    end

    # Write data from Debug Port
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def read_dp(reg_or_val, options = {})
      reg_or_val, options = nil, reg_or_val if reg_or_val.is_a?(Hash)
      read(0, reg_or_val, options.merge(compare_data: reg_or_val.is_a?(Numeric)))
    end

    # Write data from Access Port
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def read_ap(reg_or_val, options = {})
      reg_or_val, options = nil, reg_or_val if reg_or_val.is_a?(Hash)
      read(1, reg_or_val, options.merge(compare_data: reg_or_val.is_a?(Numeric)))
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
      addr = extract_address(reg_or_val, options.merge(use_reg_or_val_if_you_must: true))
      send_header(ap_dp, 1, addr)       # send read-specific header (rnw = 1)
      receive_acknowledgement(options)
      receive_payload(reg_or_val, options)
      swd_dio.drive(0)
    end

    # Write data to Debug Port
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def write_dp(reg_or_val, options = {})
      write(0, reg_or_val, options)
    end

    # Write data to Access Port
    #
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def write_ap(reg_or_val, options = {})
      write(1, reg_or_val, options)
    end

    # Write data to Debug Port or Access Port
    #
    # @param [Integer] ap_dp A single bit indicating whether the Debug Port or the Access Port Register
    #   is to be accessed.  This bit is 0 for an DPACC access, or 1 for a APACC access
    # @param [Integer, Origen::Register::Reg, Origen::Register::BitCollection, Origen::Register::Bit] reg_or_val
    #   Value to be shifted. If a reg/bit collection is supplied this can be pre-marked for
    #   read, store or overlay and which will result in the requested action being applied to
    #   the cycles corresponding to those bits only (don't care cycles will be generated for the others).
    # @param [Hash] options Options to customize the operation
    def write(ap_dp, reg_or_val, deprecated_wdata = nil, options = {})
      deprecated_wdata, options = nil, deprecated_wdata if deprecated_wdata.is_a?(Hash)

      if deprecated_wdata
        addr = reg_or_val.respond_to?(:address) ? reg_or_val.address : reg_or_val
      else
        addr = extract_address(reg_or_val, options)
      end

      send_header(ap_dp, 0, addr)       # send write-specific header (rnw = 0)
      receive_acknowledgement

      if deprecated_wdata
        if reg_or_val.respond_to?(:data)
          reg_or_val.data = deprecated_wdata
        else
          reg_or_val = deprecated_wdata
        end
      end
      send_payload(reg_or_val, options)
      swd_dio.drive(0)
    end

    private

    def extract_data_hex(reg_or_val)
      if reg_or_val.respond_to?(:data)
        reg_or_val.data.to_s(16).upcase
      else
        reg_or_val.to_s(16).upcase
      end
    end

    def extract_address(reg_or_val, options)
      addr = options[:address] || options[:addr]
      return addr if addr
      return reg_or_val.address if reg_or_val.respond_to?(:address)
      return reg_or_val.addr if reg_or_val.respond_to?(:addr)
      return reg_or_val if reg_or_val && options[:use_reg_or_val_if_you_must]
      fail 'No address given, if supplying a data value instead of a register object, you must supply an :address option'
    end

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

      cc '[SWD] -----------------------------------------------------------------'
      cc '[SWD] | Start |  AP   | Read  | AD[2] | AD[3] |  Par  | Stop  | Park  |'
      cc "[SWD] |   1   |   #{apndp}   |   #{rnw}   |   #{addr[0]}   |   #{addr[1]}   |   #{parity[0]}   |   0   |   1   |"
      cc '[SWD] -----------------------------------------------------------------'
      swd_clk.drive(1)
      swd_dio.drive!(1)                                   # send start bit (always 1)
      swd_dio.drive!(apndp)                               # send apndp bit
      swd_dio.drive!(rnw)                                 # send rnw bit
      swd_dio.drive!(addr[0])                             # send address[2] bit
      swd_dio.drive!(addr[1])                             # send address[3] bit
      swd_dio.drive!(parity[0])                           # send parity bit
      swd_dio.drive!(0)                                   # send stop bit
      swd_dio.drive!(1)                                   # send park bit
      swd_dio.dont_care
    end

    # Waits appropriate number of cycles for the acknowledgement phase
    # @param options [Hash] Options during acknowledgement reception.
    # @option options [true, false] :ignore_acknowledgement Indicates that the acknowledgement
    #   should not be checked for a pass/fail result. Rather, the tester will just be cycled 3 times.
    # @option options [true, false] :expect_transaction_error Instead of verifying for a successful
    #   transaction, verifies that a transaction error occurred.
    # @note If both :ignore_acknowledgement and :expect_transaction_error are present,
    #   :ignore_acknowledgement will take precedence.
    def receive_acknowledgement(confirm: :success, **options)
      wait_trn
      if [:ignore, :none, :skip].include?(confirm)
        log('Ignoring Acknowledgement Phase')
        tester.cycle(repeat: 3)
      elsif [:failure, :fail, :error].include?(confirm)
        log('Confirming Error Encountered During Acknowledgement Phase')
        swd_dio.assert!(0)
        swd_dio.assert!(0)
        swd_dio.assert!(1)
      elsif confirm == :success
        log('Confirming Success During Acknowledgement Phase')
        swd_dio.assert!(1)
        swd_dio.assert!(0)
        swd_dio.assert!(0)
      else
        Origen.app!.fail!(message: "OrigenSWD: Origen SWD does not know how to confirm :#{confirm}")
      end
      swd_dio.dont_care
    end

    # Waits for TRN time delay
    def wait_trn
      $tester.cycle(repeat: trn + 1)
    end

    def log(msg)
      cc "[SWD] #{msg}"
      if block_given?
        yield
        cc "[SWD] /#{msg}"
      end
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
      log "Read: #{Origen::Utility.read_hex(reg_or_val)}" do
        options[:read] = true
        shift_payload(reg_or_val, options)
      end
      swd_dio.dont_care
      $tester.cycle
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
      wait_trn
      wdata = reg_or_val.respond_to?(:data) ? reg_or_val.data : reg_or_val

      log "Write: #{wdata.to_hex}" do
        options[:read] = false
        shift_payload(reg_or_val, options)
      end

      parity_bit = swd_xor_calc(32, wdata)
      swd_dio.drive!(parity_bit)
      swd_dio.dont_care
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
      options = { no_subr: false }.merge(options)

      reg = to_reg(reg_or_val, options)
      size = 32    # SWD only used to write to DP and AP registers of ARM Debugger (32 bits)

      # tester does not support direct labels, so can't do
      if options[:no_subr] && !$tester.respond_to?('label')
        cc 'This tester does not support use of labels, cannot do no_subr option as requested'
        cc '  going with subroutine overlay instead'
        options[:no_subr] = false
      end

      cc options[:arm_debug_comment] if options.key?(:arm_debug_comment)
      swd_clk.drive(1)

      reg_overlay = extract_reg_overlay(reg)
      if reg_overlay && !options[:no_subr] && !Origen.mode.simulation?
        Origen.tester.call_subroutine(reg[0].overlay_str)
      else
        last_overlay_label = ''
        size.times do |i|
          swd_dio.dont_care
          if options[:read]
            if reg[i].is_to_be_stored?
              Origen.tester.store_next_cycle(swd_dio)
              swd_dio.dont_care if Origen.tester.j750?
            elsif reg[i].is_to_be_read?
              swd_dio.assert(reg[i] ? reg[i] : 0, meta: { position: i })
            end
          else
            swd_dio.drive(reg_or_val[i])
          end

          if reg[i].has_overlay? && !Origen.mode.simulation? && tester.respond_to?('label')
            if reg[i].overlay_str != last_overlay_label
              Origen.tester.label(reg[i].overlay_str)
              last_overlay_label = reg[i].overlay_str
            end
            tester.cycle dont_compress: true
          else
            tester.cycle
          end
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

    # Provides shortname access to top-level SWD clock pin
    def swd_clk
      owner.pin(:swd_clk)
    end

    # Provides shortname access to top-level SWD data I/O pin
    def swd_dio
      owner.pin(:swd_dio)
    end

    # Converts reg_or_val to reg
    def to_reg(reg_or_val, options)
      if reg_or_val.respond_to?(:data)
        reg = reg_or_val.dup
      else
        reg = Reg.dummy(32)
        if reg_or_val.nil?
          reg.read(options[:compare_data]) if options[:compare_data]
        else
          reg.write(reg_or_val)
          reg.read if options[:read]
        end
      end
      reg.overlay(options[:arm_debug_overlay]) if options.key?(:arm_debug_overlay)
      reg.overlay(options[:overlay_label]) if options.key?(:overlay)
      reg
    end

    # Return overlay sting if same for all bits, otherwise return nil
    def extract_reg_overlay(reg)
      ovl = reg[0].overlay_str
      reg.size.times do |i|
        return nil unless reg[i].has_overlay?
        return nil if ovl != reg[i].overlay_str || ovl.nil?
      end
      ovl
    end
  end
end
