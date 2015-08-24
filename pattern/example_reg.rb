Pattern.create do

  swd = $dut.swd
  reg = $dut.reg(:test)

  def test(msg)
    ss "Test - #{msg}"
  end

  test "Write to DR register"
  reg.write(0xFF01FF01)
  swd.write(0, reg, 0xFF01FF01)

  test "Write to DR register with overlay"
  reg.overlay("write_overlay")
  swd.write(0, reg, 0xFF01FF01)
    
  test "Write to DR register with single bit overlay"
  reg.overlay(nil)
  reg.bit(:bit).overlay("write_overlay")
  swd.write(0, reg, 0xFF01FF01)


  test "Read full DR register"
  cc "Full register (32 bits)"
  reg.read
  swd.read(0, reg)

  test "Read single bit out of DR register"
  reg.bit(:bit).read
  swd.read(0, reg)

  test "Store full DR register"
  cc "Full register (32 bits)"
  reg.store
  swd.read(0, reg)

  test "Store single bit out of DR register"
  reg.bit(:bit).store
  swd.read(0, reg)

end
