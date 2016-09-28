Pattern.create do
  DP = 0
  AP = 1
  ap_dp      = 1
  address    = 0x00002020
  wdata      = 0xAAAA5555

  ss "API that is more in line with other Origen plugins"

  dut.control.write(0x00000010)
  dut.swd.write(DP, dut.control)
  dut.swd.write(DP, 0x55, address: 4)
  dut.swd.write_dp(dut.control)
  dut.swd.write_dp(0x55, address: 4)
  dut.swd.write_ap(dut.control)
  dut.swd.write_ap(0x55, address: 4)

  # Not really supported, can't differentiate between an old-style and new-style
  # call to do things like enable read by default
  #dut.swd.read(DP, dut.control)
  #dut.swd.read(DP, 0x55, address: 4)
  dut.swd.read_dp(dut.control)
  dut.swd.read_dp(0x55, address: 4)
  dut.swd.read_ap(dut.control)
  dut.swd.read_ap(0x55, address: 4)
  dut.swd.read_dp(address: 4)
  dut.swd.read_ap(address: 4)


  ss "Legacy API"
  dut.control.reset

  $dut.swd.write(ap_dp, address, wdata, overlay: 'write_ovl')
  cc 'SWD DIO to 0 for 10 cycles'
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.read(ap_dp, address)
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.read(ap_dp, address, compare_data: wdata)
  $dut.swd.swd_dio_to_0(10)

  #$dut.reg(:select).data = 0x01000000
  $dut.swd.write(DP, $dut.reg(:select), 0x01000000, arm_debug_overlay: 'select_reg')
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.read(DP, $dut.reg(:select))
  $dut.swd.swd_dio_to_0(10)

  $dut.swd.write(DP, $dut.reg(:stat), 0x00000032)
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.write(DP, $dut.reg(:control), 0x00000010)
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.read(DP, $dut.reg(:control), r_mask: 'store')
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.read(DP, $dut.reg(:control), compare_data: 0x00000010)
  $dut.swd.swd_dio_to_0(10)

  $dut.swd.read(DP, $dut.reg(:control), compare_data: 0x00000010)
  $dut.swd.swd_dio_to_0(10)
  $dut.swd.read(DP, $dut.reg(:control), compare_data: 0x00000010)
  $dut.swd.swd_dio_to_0(10)

end
