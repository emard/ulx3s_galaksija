#!/usr/bin/env python3
 
# convert galbackup.gp file to eeprom.bin
#
# Dejan Ristanovic
#
# v1.0: 21.03.2024
# v1.1: 22.03.2024
# v2.0: 30.03.2024.
# v2.1: 03.04.2024.
# v2.2: 05.04.2024. case sensitive function for Unix by Vlado Vince
# v2.5: 14.04.2024.
# v2.6: 16.04.2024.
# v2.7: 24.06.2025. EMARD dirty modification to extract eeprom.bin
#

# needs: pip install pyserial

import serial
import time
import os
import sys

version = "2.60"
checksums = 0
checksumr = 0
debug = True

def mydir():
    if getattr(sys, 'frozen', False):
        # Running as a bundled executable
        return os.path.dirname(sys.executable)
    else:
        # Running as a script
        return os.path.dirname(os.path.abspath(__file__))

def debug_print_hex_dump(title, data):
    hex_str = data.hex()
    ascii_str = ''.join(chr(byte) if 32 <= byte <= 126 else '.' for byte in data)
    print(title)
    for i in range(0, len(hex_str), 32):
        address = i // 2
        hex_line = hex_str[i:i+32]
        hex_formatted = ' '.join(hex_line[j:j+2] for j in range(0, len(hex_line), 2))
        ascii_line = ascii_str[i//2:i//2+16]  # Adjusting ASCII representation
        print(f"{address:04X}  {hex_formatted: <47} |{ascii_line}|")

def send_data(data, ser):
    global debug
    global checksums
    for byte in data: checksums += byte
    try:
       ser.write(data)
    except serial.SerialException as e:
       print("Serial port error:", e)
       sys.exit()
    except serial.SerialTimeoutException:
       print("Timeout occurred during serial communication.")
       sys.exit()
    except KeyboardInterrupt:
       print("Keyboard interrupt detected. Exiting...")
       sys.exit()
    if debug: debug_print_hex_dump("Sending data:", data)

def galfname(string):
    string = string.upper()
    string = string.replace(" ", "")
    if string.endswith(".GTP"):
       string = string[:-4]
    allowed_characters = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.")
    string = ''.join(char for char in string if char in allowed_characters)
    if len(string) > 14:
       string = string[:14]
    return string

def get_byte (ser, debg=False):
   global checksumr
   try:
      data = ser.read()
      if data:
         decimal_value = int.from_bytes(data, byteorder='big')  # Convert byte to decimal
         if debg:
            decimal_formatted = '{:03d}'.format(decimal_value)
            hex_value = data.hex()  # Convert byte to hexadecimal
            ascii_char = data.decode('ascii', errors='replace') if decimal_value>=32 and decimal_value<127 else '.'
            print("Byte received: ", decimal_formatted, hex_value, ascii_char)
         checksumr=checksumr+decimal_value
         return data
      else:
         print("Timeout reached. No data received for {} seconds. Exiting.".format(timeout))
         sys.exit()
   except KeyboardInterrupt:
         print("Keyboard interrupt. Exiting.")
         sys.exit()

def get_block(ser, length):
    global debug
    file_data = b''
    for ii in range(length):
        byte = get_byte(ser, False)
        if byte is None:
            break
        file_data += byte
    if debug: debug_print_hex_dump("Received data: ", file_data)
    return file_data

def open_serial_port(port, baudrate=19200, parity='N', timeout=10):
    try:
        ser = serial.Serial(port, baudrate, parity=parity, timeout=timeout)
    except serial.serialutil.SerialException as e:
        print("Serial communication error:", e)
    except PermissionError as e:
        print("Permission error:", e)
    except ValueError as e:
        print("Invalid parameter:", e)
    except Exception as e:
        print("Unexpected error:", e)
    else:
        return ser
    sys.exit()

def getfile_insensitive(path): # Get file name with correct capitalization
    directory, filename = os.path.split(path)
    directory, filename = (directory or '.'), filename.lower()
    for f in os.listdir(directory):
        newpath = os.path.join(directory, f)
        if os.path.isfile(newpath) and f.lower() == filename:
            return newpath

def isfile_insensitive(path): # Check if file name exists with different capitalization
    return getfile_insensitive(path) is not None

def send_backup_file(port, baudrate=19200, parity='N', timeout=10, filename=""):
    global checksums
    global checksumr
    global debug
    # ser = open_serial_port(port, baudrate, parity, timeout)
    ser = open("eeprom.bin","wb")
    checksums=0
    checksumr=0
    waiting=True
    header=b'\xaa\x39'
    file_path = os.path.join(mydir(), file_name)
    file_path=file_path+".gb"
    try:
       with open(file_path, 'rb') as file:
            file_data=file.read()
    except:
       print("Error reading file:", file_path)
       data_to_send = bytes([0xF2])
       sys.exit(1)
    if file_data[0]!=0xb7 or file_data[1]!=0xe2:
       print("Invalid backup file format")
       data_to_send = bytes([0xF5])
       sys.exit(1)
    data_to_send = bytes([0xF0])
    checksums=0
    header=b'\xcc\x36'
    word1=file_data[2]+(file_data[3] << 8)
    data_to_send=file_data[2:4]
    for blockcounter in range (0, word1):
        oneblock=file_data[blockcounter*514+4:(blockcounter+1)*514+4]
        print(f"Transfering block: {blockcounter:d} of {(word1-1):d}", end="\r")
        send_data(oneblock[2:514], ser)
    checksumx=checksums & 0xff
    checksum_byte = checksumx.to_bytes(1, byteorder='little')
    print ("File: "+file_name+" transfered.") 
    ser.close()

def read_cfg_port():
    current_directory = mydir()
    file_path = os.path.join(current_directory, "comport.txt")
    if os.path.exists(file_path):
        with open(file_path, 'r') as file:
            port = file.readline().strip()
        return port
    else:
        return None

def printusage():
    print("Usage: python restore.py [<file_name>] [<COM_port>]")

if __name__ == "__main__":
    print ("GALAXY Restore Utility v", version)
    print ("Copyright (C) 2024 by Dejan Ristanovic")
    debug=False # Run in debug mode, print communication on screen
    port = read_cfg_port()
    if not port:
       port = "COM4"
    if len(sys.argv) == 1:
        file_name = 'galbackup'
    elif len(sys.argv) == 2:
        file_name = sys.argv[1]
        if file_name == "?" or file_name=="/?":
           printusage()
           sys.exit(1)
    elif len(sys.argv) == 3:
        file_name = sys.argv[1]
        port = sys.argv[2]
    else:
        printusage()
        sys.exit(1)
    timeout = 60  # Timeout set to 60 seconds
    send_backup_file (port, timeout=timeout, filename=file_name)
