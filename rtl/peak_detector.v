`timescale 1ns / 1ps

module pulse_detector #(
    parameter CORR_WIDTH   = 16,
    parameter INDEX_WIDTH  = 8,
    parameter FRAME_LENGTH = 256
)(
    input  wire                          clk,
    input  wire                          rst,

    input  wire signed [CORR_WIDTH-1:0] correlation_in,
    input  wire                          valid_in,
    input  wire        [INDEX_WIDTH-1:0] index_in,

    // Minimum correlation magnitude required for detection
    input  wire        [CORR_WIDTH-1:0] threshold,

    // Completed frame result
    output reg                           detection_valid,
    output reg                           detected,
    output reg        [CORR_WIDTH-1:0]  peak_magnitude,
    output reg        [INDEX_WIDTH-1:0] peak_index
);

    // Largest magnitude observed so far in the current frame
    reg [CORR_WIDTH-1:0] running_peak_magnitude;
    reg [INDEX_WIDTH-1:0] running_peak_index;

    // Unsigned strength of the signed correlation value
    wire [CORR_WIDTH-1:0] correlation_magnitude;

    // Final valid index in one frame
    localparam [INDEX_WIDTH-1:0] LAST_INDEX =
        FRAME_LENGTH - 1;


    // Two's-complement absolute value:
    // positive values pass through; negative values are inverted and incremented
    assign correlation_magnitude =
        correlation_in[CORR_WIDTH-1]
            ? (~correlation_in + 1'b1)
            : correlation_in;


    always @(posedge clk) begin
        if (rst) begin
            running_peak_magnitude <= {CORR_WIDTH{1'b0}};
            running_peak_index     <= {INDEX_WIDTH{1'b0}};

            peak_magnitude <= {CORR_WIDTH{1'b0}};
            peak_index     <= {INDEX_WIDTH{1'b0}};

            detected        <= 1'b0;
            detection_valid <= 1'b0;
        end

        else begin
            // Asserted for only one cycle when a frame result is ready
            detection_valid <= 1'b0;

            // Ignore correlation values that are not marked valid
            if (valid_in) begin

                // The final index completes the current frame
                if (index_in == LAST_INDEX) begin
                    detection_valid <= 1'b1;

                    // Include the final correlation in the peak decision
                    if (correlation_magnitude >
                        running_peak_magnitude) begin

                        peak_magnitude <= correlation_magnitude;
                        peak_index     <= index_in;

                        detected <=
                            (correlation_magnitude >= threshold);
                    end

                    else begin
                        peak_magnitude <= running_peak_magnitude;
                        peak_index     <= running_peak_index;

                        detected <=
                            (running_peak_magnitude >= threshold);
                    end

                    // Clear the running peak for the next frame
                    running_peak_magnitude <= {CORR_WIDTH{1'b0}};
                    running_peak_index     <= {INDEX_WIDTH{1'b0}};
                end

                // Save a new maximum during the current frame
                else if (correlation_magnitude >
                         running_peak_magnitude) begin

                    running_peak_magnitude <= correlation_magnitude;
                    running_peak_index     <= index_in;
                end
            end
        end
    end

endmodule