Pattern.create do
  dut.control.write(0x00000010)
  dut.swd.write(0, dut.control)
  dut.swd.write(0, 0x55, address: 4)
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
  #dut.swd.read_dp(address: 4)
  #dut.swd.read_ap(address: 4)

end
