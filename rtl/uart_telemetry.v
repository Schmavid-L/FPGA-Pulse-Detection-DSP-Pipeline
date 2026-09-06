`timescale 1ns / 1ps

module uart_telemetry #(
    parameter integer CLKS_PER_BIT = 868
)(
    input  wire        clk,
    input  wire        rst,

    input  wire        result_valid,
    input  wire        detected,
    input  wire [7:0]  estimated_delay,
    input  wire [15:0] peak_magnitude,

    output wire        uart_tx_out,
    output reg         packet_active
);

    reg        uart_start;
    reg  [7:0] uart_data;
    wire       uart_busy;
    wire       uart_done;

    reg  [2:0] byte_index;

    reg        detected_latched;
    reg  [7:0] delay_latched;
    reg [15:0] peak_latched;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uart_tx_inst (
        .clk(clk),
        .rst(rst),
        .start(uart_start),
        .data_in(uart_data),
        .tx(uart_tx_out),
        .busy(uart_busy),
        .done(uart_done)
    );

    always @(posedge clk) begin
        if (rst) begin
            uart_start       <= 1'b0;
            uart_data        <= 8'd0;
            byte_index       <= 3'd0;
            packet_active    <= 1'b0;
            detected_latched <= 1'b0;
            delay_latched    <= 8'd0;
            peak_latched     <= 16'd0;
        end
        else begin
            // start is normally low and becomes a one-clock request
            uart_start <= 1'b0;

            if (!packet_active) begin
                /*
                 * Capture one complete detector result.
                 * Results arriving while a packet is being transmitted
                 * are intentionally ignored.
                 */
                if (result_valid) begin
                    detected_latched <= detected;
                    delay_latched    <= estimated_delay;
                    peak_latched     <= peak_magnitude;

                    byte_index    <= 3'd0;
                    packet_active <= 1'b1;

                    // Byte 0: packet synchronization marker
                    uart_data  <= 8'hAA;
                    uart_start <= 1'b1;
                end
            end
            else if (uart_done) begin
                case (byte_index)
                    3'd0: begin
                        // Byte 1: detection flag
                        byte_index <= 3'd1;
                        uart_data  <= {7'd0, detected_latched};
                        uart_start <= 1'b1;
                    end

                    3'd1: begin
                        // Byte 2: recovered echo delay
                        byte_index <= 3'd2;
                        uart_data  <= delay_latched;
                        uart_start <= 1'b1;
                    end

                    3'd2: begin
                        // Byte 3: peak magnitude, most-significant byte
                        byte_index <= 3'd3;
                        uart_data  <= peak_latched[15:8];
                        uart_start <= 1'b1;
                    end

                    3'd3: begin
                        // Byte 4: peak magnitude, least-significant byte
                        byte_index <= 3'd4;
                        uart_data  <= peak_latched[7:0];
                        uart_start <= 1'b1;
                    end

                    default: begin
                        byte_index    <= 3'd0;
                        packet_active <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule