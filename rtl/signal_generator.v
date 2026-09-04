`timescale 1ns / 1ps

module signal_generator #(
    parameter SAMPLE_WIDTH = 12,
    parameter FRAME_LENGTH = 256
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
    reg [7:0] frame_counter;

    wire signed [4:0] noise_small;
    
    localparam signed [SAMPLE_WIDTH-1:0] PULSE_AMPLITUDE = 64;

// Extend to nine bits so echo_delay + 13 cannot overflow at 255
wire [8:0] frame_position_ext;
wire [8:0] echo_start_ext;
wire [8:0] echo_end_ext;

assign frame_position_ext = {1'b0, frame_counter};
assign echo_start_ext     = {1'b0, echo_delay};
assign echo_end_ext       = echo_start_ext + 9'd13;

    // Shift the unsigned range 0-15 into the signed range -8 to +7
    assign noise_small = $signed({1'b0, lfsr[3:0]}) - 5'sd8;

    always @(posedge clk) begin
        if (rst) begin
            frame_counter <= 8'd0;
            sample_index  <= 8'd0;
            sample_out    <= {SAMPLE_WIDTH{1'b0}};
            sample_valid  <= 1'b0;

            // The LFSR requires a nonzero starting value
            lfsr <= 16'hACE1;
        end

        else if (enable) begin
            sample_valid <= 1'b1;
            
            

            // sample_index and sample_out now describe the same position
            sample_index <= frame_counter;
                          // Insert the 13-sample pulse beginning at echo_delay
        if ((frame_position_ext >= echo_start_ext) &&
            (frame_position_ext < echo_end_ext)) begin

    // Barker-13 pattern: + + + + + - - + + - + - +
                case (frame_counter - echo_delay)
        8'd0,
        8'd1,
        8'd2,
        8'd3,
        8'd4,
        8'd7,
        8'd8,
        8'd10,
        8'd12:
            sample_out <= noise_small + PULSE_AMPLITUDE;

        default:
            sample_out <= noise_small - PULSE_AMPLITUDE;
    endcase
end

// Every position outside the pulse contains only noise
else begin
    sample_out <= noise_small;
end
            // XOR feedback produces the next pseudo-random state
            lfsr <= {
                lfsr[14:0],
                lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]
            };

            // Advance to the next sample or begin a new frame
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