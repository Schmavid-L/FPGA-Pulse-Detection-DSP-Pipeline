`timescale 1ns / 1ps

module uart_telemetry_tb;

    localparam integer CLKS_PER_BIT = 8;

    reg         clk;
    reg         rst;
    reg         result_valid;
    reg         detected;
    reg  [7:0]  estimated_delay;
    reg  [15:0] peak_magnitude;

    wire        uart_tx_out;
    wire        packet_active;

    integer errors;
    integer bit_number;
    reg [7:0] received_byte;

    uart_telemetry #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .result_valid(result_valid),
        .detected(detected),
        .estimated_delay(estimated_delay),
        .peak_magnitude(peak_magnitude),
        .uart_tx_out(uart_tx_out),
        .packet_active(packet_active)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task receive_uart_byte;
        output [7:0] received;
        begin
            received = 8'd0;

            // Find the beginning of the UART start bit
            @(negedge uart_tx_out);

            // Sample the middle of the start bit
            repeat (CLKS_PER_BIT / 2) @(posedge clk);

            if (uart_tx_out !== 1'b0) begin
                $error("UART start bit was not low");
                errors = errors + 1;
            end

            // Move to the middle of data bit zero
            repeat (CLKS_PER_BIT) @(posedge clk);

            // UART data is transmitted least-significant bit first
            for (
                bit_number = 0;
                bit_number < 8;
                bit_number = bit_number + 1
            ) begin
                received[bit_number] = uart_tx_out;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            // Check the stop bit
            if (uart_tx_out !== 1'b1) begin
                $error("UART stop bit was not high");
                errors = errors + 1;
            end
        end
    endtask

    task check_next_byte;
        input [7:0] expected;
        begin
            receive_uart_byte(received_byte);

            if (received_byte !== expected) begin
                $error(
                    "Packet mismatch: expected 0x%02h, received 0x%02h",
                    expected,
                    received_byte
                );
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors          = 0;
        rst             = 1'b1;
        result_valid    = 1'b0;
        detected        = 1'b0;
        estimated_delay = 8'd0;
        peak_magnitude  = 16'd0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        /*
         * Submit a known detector result:
         * detected = 1
         * delay    = 40 = 0x28
         * peak     = 214 = 0x00D6
         */
        @(negedge clk);
        detected        = 1'b1;
        estimated_delay = 8'd40;
        peak_magnitude  = 16'd214;
        result_valid    = 1'b1;

        @(negedge clk);
        result_valid = 1'b0;

        // Expected packet: AA 01 28 00 D6
        check_next_byte(8'hAA);
        check_next_byte(8'h01);
        check_next_byte(8'h28);
        check_next_byte(8'h00);
        check_next_byte(8'hD6);

        wait (packet_active == 1'b0);
        repeat (2) @(posedge clk);

        if (errors == 0)
            $display("UART TELEMETRY TESTS PASSED");
        else
            $display(
                "UART TELEMETRY TESTS FAILED with %0d errors",
                errors
            );

        $finish;
    end

endmodule