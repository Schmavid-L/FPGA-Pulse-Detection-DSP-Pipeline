import serial

PORT = "COM8"
BAUD_RATE = 115200
SYNC_BYTE = 0xAA
PACKET_DATA_LENGTH = 4


def read_packet(serial_port):
    """Find 0xAA and decode the following four packet bytes."""

    while True:
        first_byte = serial_port.read(1)

        if not first_byte:
            continue

        if first_byte[0] == SYNC_BYTE:
            packet = serial_port.read(PACKET_DATA_LENGTH)

            if len(packet) != PACKET_DATA_LENGTH:
                continue

            detected = packet[0]
            estimated_delay = packet[1]
            peak_magnitude = (packet[2] << 8) | packet[3]

            return detected, estimated_delay, peak_magnitude


def main():
    print(f"Opening {PORT} at {BAUD_RATE} baud...")
    print("Press Ctrl+C to stop.\n")

    previous_result = None

    with serial.Serial(PORT, BAUD_RATE, timeout=1) as serial_port:
        serial_port.reset_input_buffer()

        while True:
            result = read_packet(serial_port)

            # Avoid flooding the terminal with identical frame results
            if result != previous_result:
                detected, estimated_delay, peak_magnitude = result

                print(
                    f"Detected: {detected} | "
                    f"Estimated delay: {estimated_delay} | "
                    f"Peak magnitude: {peak_magnitude}"
                )

                previous_result = result


if __name__ == "__main__":
    try:
        main()
    except serial.SerialException as error:
        print(f"Serial error: {error}")
    except KeyboardInterrupt:
        print("\nUART monitor stopped.")