`timescale 1ns / 1ps

module basys3_top (
    input  wire        CLK100MHZ,
    input  wire        btnC,
    input  wire [15:0] sw,
    output wire [15:0] led
);

    wire        detection_valid;
    wire        detected;
    wire [15:0] peak_magnitude;
    wire [7:0]  peak_index;
    wire [7:0]  estimated_delay;
    wire signed [15:0] correlation_out;
    wire        correlation_valid;
    wire [7:0]  correlation_index;

    /*
     * Switch mapping:
     * sw[7:0]  = simulated echo delay
     * sw[15:8] = detection threshold
     *
     * btnC = synchronous reset
     * The processing pipeline runs continuously.
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
     * LED mapping:
     * led[7:0]  = recovered echo delay
     * led[8]    = detected result
     * led[9]    = one-cycle detection-valid pulse
     * led[15:10] = upper peak-magnitude bits
     */
    assign led[7:0]   = estimated_delay;
    assign led[8]     = detected;
    assign led[9]     = detection_valid;
    assign led[15:10] = peak_magnitude[13:8];

endmodule