Pattern.create do

  address    = 0x00002020
  rwb        = 0
  ap_dp      = 1
  wdata      = 0xAAAA5555
  start      = 1
  apndp      = 1
  rnw        = rwb
  addr       = address >> 2
  parity_pr  = ap_dp ^ rwb ^ (addr >> 3) ^ (addr >> 2) & (0x01) ^ (addr >> 1) & (0x01) ^ addr & 0x01
  trn        = 0
  data       = wdata
  require_dp = 0
  line_reset = 0
  stop       = 0
  park       = 1

  cc 'SWD transaction'
  cc 'Packet Request Phase'

  annotate 'Send Start Bit'
  $dut.swd.send_data(start, 1)
  cc('Send APnDP Bit (DP or AP Access Register Bit)', prefix: true)
  $dut.swd.send_data(apndp, 1)
  c2 'Send RnW Bit (read or write bit)'
  $dut.swd.send_data(rnw, 1)
  c2 'Send Address Bits (2 bits)'
  $dut.swd.send_data(addr, 2)
  c2 'Send Parity Bit'
  $dut.swd.send_data(parity_pr, 1)
  c2 'Send Stop Bit'
  $dut.swd.send_data(stop, 1)
  c2 'Send Park Bit'
  $dut.swd.send_data(park, 1)

  cc 'Acknowledge Response phase'
  $dut.swd.send_data(0xf, trn + 1)
  $dut.swd.get_data(3)

  cc 'Write Data Phase'
  cc 'Write'
  cc 'Send ACK Bits'
  $dut.swd.send_data(0xf, trn + 1)
  cc 'SWD 32-Bit Write Start'
  $dut.swd.send_data(data, 32, overlay: 'write_ovl')
  cc 'SWD 32-Bit Write End'
  cc 'Send Write Parity Bit'
  xor = 0
  32.times do |bit|
    xor ^= (data >> bit) & 0x01
  end
  xor
  $dut.swd.send_data(xor, 1)

  cc 'SWD DIO to 0 for 10 cycles'
  $dut.swd.swd_dio_to_0(10)

end
