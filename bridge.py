import serial
import struct

ARDUINO_PORT = 'COM5'
FPGA_PORT = 'COM7'
BAUD_RATE = 9600

def run_bridge():
    try:
        # Open connections
        arduino = serial.Serial(ARDUINO_PORT, BAUD_RATE, timeout=1)
        fpga    = serial.Serial(FPGA_PORT,    BAUD_RATE, timeout=1)
        print(f"Bridge Started: {ARDUINO_PORT} -> {FPGA_PORT}")
        
        while True:
            # Read line from arduino
            if arduino.in_waiting > 0:
                line = arduino.readline().decode('utf-8').strip()
                
                try:
                    # Parse text to float
                    temp_val = float(line)
                    
                    # Pack into 4 bytes IEEE 754 (Big Endian)
                    # '>' = Big Endian, 'f' = float
                    payload = struct.pack('>f', temp_val)
                    
                    # Send raw bytes to FPGA
                    fpga.write(payload)
                    
                    print(f"Sent: {temp_val} -> Hex: {payload.hex().upper()}")
                    
                except ValueError:
                    print(f"Invalid data received: {line}")
                    
    except KeyboardInterrupt:
        print("\nStopping bridge.")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'arduino' in locals() and arduino.is_open: arduino.close()
        if 'fpga' in locals() and fpga.is_open: fpga.close()

if __name__ == "__main__":
    run_bridge()