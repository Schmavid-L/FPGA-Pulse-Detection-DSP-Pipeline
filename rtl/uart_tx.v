`timescale 1ns / 1ps

module uart_tx #(
    // 100 MHz / 115200 baud ≈ 868 clocks per UART bit
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] data_in,

    output reg        tx,
    output reg        busy,
    output reg        done
);

    localparam [2:0]
        STATE_IDLE  = 3'd0,
        STATE_START = 3'd1,
        STATE_DATA  = 3'd2,
        STATE_STOP  = 3'd3,
        STATE_DONE  = 3'd4;

    reg [2:0]  state;
    reg [15:0] clock_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_buffer;

    always @(posedge clk) begin
        if (rst) begin
            state       <= STATE_IDLE;
            clock_count <= 16'd0;
            bit_index   <= 3'd0;
            data_buffer <= 8'd0;
            tx          <= 1'b1;
            busy        <= 1'b0;
            done        <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    tx          <= 1'b1;
                    busy        <= 1'b0;
                    clock_count <= 16'd0;
                    bit_index   <= 3'd0;

                    if (start) begin
                        data_buffer <= data_in;
                        busy        <= 1'b1;
                        state       <= STATE_START;
                    end
                end

                // UART start bit is low
                STATE_START: begin
                    tx   <= 1'b0;
                    busy <= 1'b1;

                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 16'd0;
                        state       <= STATE_DATA;
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                // UART transmits the least-significant data bit first
                STATE_DATA: begin
                    tx   <= data_buffer[bit_index];
                    busy <= 1'b1;

                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 16'd0;

                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STATE_STOP;
                        end
                        else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                // UART stop bit is high
                STATE_STOP: begin
                    tx   <= 1'b1;
                    busy <= 1'b1;

                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 16'd0;
                        state       <= STATE_DONE;
                    end
                    else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STATE_DONE: begin
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                    tx    <= 1'b1;
                    busy  <= 1'b0;
                    done  <= 1'b0;
                end
            endcase
        end
    end

endmodule