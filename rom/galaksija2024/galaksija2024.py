#!/usr/bin/env python3
with open("galaxya42.rom","rb") as bin:
  with open("galaksija2024.mem","w") as hex:
    addr = 0
    for j in range(2):
      for i in range(0x0000+j*0x8000,0x8000+j*0x8000):
        byte = bin.read(1)
        if not byte:
          break
        if addr < 0x2000 or addr >= 0xA000:
          hex.write("%02x\n" % byte[0])
        else:
          hex.write("%02x\n" % 0xff)
        addr += 1
      for k in range(i,0x8000+j*0x8000):
        hex.write("%02x\n" % 0xff)
        addr += 1
      bin.seek(0)
    hex.close()
  bin.close()
