#!/usr/bin/env python3
with open("galaxya42.rom","rb") as bin:
  with open("galaksija2024.mem","w") as hex:
    for i in range(0x0000,0x2000):
      byte = bin.read(1)
      hex.write("%02x\n" % byte[0])
    for i in range(0x2000,0xA000):
      hex.write("ff\n")
    for i in range(0xA000,0x10000):
      byte = bin.read(1)
      if not byte:
        break
      hex.write("%02x\n" % byte[0])
    hex.close()
  bin.close()
