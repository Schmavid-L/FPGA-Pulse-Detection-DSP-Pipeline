`timescale 1ns / 1ps

module pulse_detection_top #(
    parameter SAMPLE_WIDTH = 12,
    parameter INDEX_WIDTH  = 8,
    parameter CORR_WIDTH   = 16,
    parameter FRAME_LENGTH = 256,
    parameter DELAY_OFFSET = 15
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         enable,

    // Selects where the synthetic Barker pulse begins
    input  wire [INDEX_WIDTH-1:0]       echo_delay,

    // Minimum correlation magnitude required for detection
    input  wire [CORR_WIDTH-1:0]        threshold,

    // Completed frame result from the peak detector
    output wire                         detection_valid,
    output wire                         detected,
    output wire [CORR_WIDTH-1:0]        peak_magnitude,
    output wire [INDEX_WIDTH-1:0]       peak_index,

    // Correlator outputs exposed for simulation and debugging
    output wire signed [CORR_WIDTH-1:0] correlation_out,
    output wire                         correlation_valid,
    output wire [INDEX_WIDTH-1:0]       correlation_index,
    output wire [INDEX_WIDTH-1:0] estimated_delay
    
);


    // ---------------------------------------------------------
    // Stage 1: synthetic signal generator
    // ---------------------------------------------------------

    wire signed [SAMPLE_WIDTH-1:0] generator_sample;
    wire                           generator_valid;
    wire        [INDEX_WIDTH-1:0]  generator_index;

    signal_generator #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .FRAME_LENGTH(FRAME_LENGTH),
        .PULSE_AMPLITUDE(64)
    ) signal_generator_inst (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .echo_delay(echo_delay),

        .sample_out(generator_sample),
        .sample_valid(generator_valid),
        .sample_index(generator_index)
    );


    // ---------------------------------------------------------
    // Stage 2: seven-tap FIR filter
    // ---------------------------------------------------------

    wire signed [SAMPLE_WIDTH-1:0] filtered_sample;
    wire                           filtered_valid;
    wire        [INDEX_WIDTH-1:0]  filtered_index;

    fir_filter #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) fir_filter_inst (
        .clk(clk),
        .rst(rst),

        .sample_in(generator_sample),
        .valid_in(generator_valid),
        .index_in(generator_index),

        .sample_out(filtered_sample),
        .valid_out(filtered_valid),
        .index_out(filtered_index)
    );


    // ---------------------------------------------------------
    // Stage 3: Barker-13 matched correlator
    // ---------------------------------------------------------

    matched_correlator #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .CORR_WIDTH(CORR_WIDTH)
    ) matched_correlator_inst (
        .clk(clk),
        .rst(rst),

        .sample_in(filtered_sample),
        .valid_in(filtered_valid),
        .index_in(filtered_index),

        .correlation_out(correlation_out),
        .valid_out(correlation_valid),
        .index_out(correlation_index)
    );


    // ---------------------------------------------------------
    // Stage 4: magnitude, threshold, and frame peak detector
    // ---------------------------------------------------------

    pulse_detector #(
        .CORR_WIDTH(CORR_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .FRAME_LENGTH(FRAME_LENGTH)
    ) pulse_detector_inst (
        .clk(clk),
        .rst(rst),

        .correlation_in(correlation_out),
        .valid_in(correlation_valid),
        .index_in(correlation_index),
        .threshold(threshold),

        .detection_valid(detection_valid),
        .detected(detected),
        .peak_magnitude(peak_magnitude),
        .peak_index(peak_index)
    );
    assign estimated_delay = peak_index - DELAY_OFFSET;
endmodule