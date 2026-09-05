`timescale 1ns / 1ps

module signal_generator #(
    parameter SAMPLE_WIDTH = 12,
    parameter FRAME_LENGTH = 256,

    // Strength of the positive and negative pulse samples
    parameter signed [SAMPLE_WIDTH-1:0] PULSE_AMPLITUDE = 64
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         enable,
    input  wire [7:0]                   echo_delay,

    output reg signed [SAMPLE_WIDTH-1:0] sample_out,
    output reg                          sample_valid,
    output reg [7:0]                    sample_index
);

    reg [15:0] lfsr;
    reg [7:0]  frame_counter;

    wire signed [4:0] noise_small;

    wire [8:0] frame_position_ext;
    wire [8:0] echo_start_ext;
    wire [8:0] echo_end_ext;

    wire       pulse_active;
    wire [7:0] pulse_position;

    // Convert unsigned values 0-15 into signed noise from -8 to +7
    assign noise_small =
        $signed({1'b0, lfsr[3:0]}) - 5'sd8;

    // Nine-bit values prevent overflow when adding 13 to echo_delay
    assign frame_position_ext = {1'b0, frame_counter};
    assign echo_start_ext     = {1'b0, echo_delay};
    assign echo_end_ext       = echo_start_ext + 9'd13;

    // Pulse is active for 13 sample positions
    assign pulse_active =
        (frame_position_ext >= echo_start_ext) &&
        (frame_position_ext < echo_end_ext);

    // Position inside the Barker sequence: 0 through 12
    assign pulse_position = frame_counter - echo_delay;

    always @(posedge clk) begin
        if (rst) begin
            frame_counter <= 8'd0;
            sample_index  <= 8'd0;
            sample_out    <= {SAMPLE_WIDTH{1'b0}};
            sample_valid  <= 1'b0;

            // An LFSR must begin with a nonzero seed
            lfsr <= 16'hACE1;
        end

        else if (enable) begin
            sample_valid <= 1'b1;
            sample_index <= frame_counter;

            // Insert the Barker-13 pattern while pulse_active is high
            if (pulse_active) begin
                case (pulse_position)

                    // Barker positions containing +1
                    8'd0, 8'd1, 8'd2, 8'd3, 8'd4,
                    8'd7, 8'd8, 8'd10, 8'd12:
                        sample_out <=
                            PULSE_AMPLITUDE + noise_small;

                    // Barker positions containing -1
                    default:
                        sample_out <=
                            -PULSE_AMPLITUDE + noise_small;

                endcase
            end

            // All other frame positions contain only noise
            else begin
                sample_out <= noise_small;
            end

            // Advance the pseudo-random sequence
            lfsr <= {
                lfsr[14:0],
                lfsr[15] ^ lfsr[13] ^
                lfsr[12] ^ lfsr[10]
            };

            // Advance through the 256-sample frame
            if (frame_counter == FRAME_LENGTH - 1)
                frame_counter <= 8'd0;
            else
                frame_counter <= frame_counter + 1'b1;
        end

        else begin
            sample_valid <= 1'b0;
        end
    end

endmodule