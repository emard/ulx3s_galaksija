#!/usr/bin/env python3
with open("galaxya42.rom","rb") as bin:
  with open("galaksija2024.mem","w") as hex:
    for j in range(4):
      for i in range(0x0000+j*0x4000,0x4000+j*0x4000):
        byte = bin.read(1)
        if not byte:
          break
        hex.write("%02x\n" % byte[0])
      for k in range(i,0x4000+j*0x4000):
        hex.write("%02x\n" % 0xff)
      bin.seek(0)
    hex.close()
  bin.close()
