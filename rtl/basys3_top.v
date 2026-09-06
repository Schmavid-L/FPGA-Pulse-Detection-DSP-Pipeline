`timescale 1ns / 1ps

module basys3_top (
    input  wire        CLK100MHZ,
    input  wire        btnC,
    input  wire [15:0] sw,

    output wire [15:0] led,
    output wire        RsTx
);

    wire        detection_valid;
    wire        detected;
    wire [15:0] peak_magnitude;
    wire [7:0]  peak_index;
    wire [7:0]  estimated_delay;

    wire signed [15:0] correlation_out;
    wire               correlation_valid;
    wire [7:0]         correlation_index;

    wire telemetry_active;

    /*
     * Switch mapping:
     * sw[7:0]  = simulated echo delay
     * sw[15:8] = detection threshold, 0 through 255
     *
     * btnC = synchronous reset
     */
    pulse_detection_top #(
        .SAMPLE_WIDTH(12),
        .FRAME_LENGTH(256),
        .DELAY_OFFSET(15)
    ) pipeline_inst (
        .clk(CLK100MHZ),
        .rst(btnC),
        .enable(1'b1),

        .echo_delay(sw[7:0]),
        .threshold({8'b0, sw[15:8]}),

        .detection_valid(detection_valid),
        .detected(detected),
        .peak_magnitude(peak_magnitude),
        .peak_index(peak_index),

        .correlation_out(correlation_out),
        .correlation_valid(correlation_valid),
        .correlation_index(correlation_index),
        .estimated_delay(estimated_delay)
    );

    /*
     * Transmit five-byte result packets through the Basys 3
     * USB-UART connection at 115200 baud.
     *
     * Packet:
     *   AA, detected, delay, peak high byte, peak low byte
     */
    uart_telemetry #(
        .CLKS_PER_BIT(868)
    ) telemetry_inst (
        .clk(CLK100MHZ),
        .rst(btnC),

        .result_valid(detection_valid),
        .detected(detected),
        .estimated_delay(estimated_delay),
        .peak_magnitude(peak_magnitude),

        .uart_tx_out(RsTx),
        .packet_active(telemetry_active)
    );

    /*
     * LED mapping:
     * led[7:0]   = recovered echo delay
     * led[8]     = detection result
     * led[9]     = UART packet currently transmitting
     * led[15:10] = upper peak-magnitude bits
     */
    assign led[7:0]   = estimated_delay;
    assign led[8]     = detected;
    assign led[9]     = telemetry_active;
    assign led[15:10] = peak_magnitude[13:8];

endmodule