`timescale 1ns / 1ps

module uart_tx_tb;

    // Shortened for faster simulation
    localparam integer CLKS_PER_BIT = 8;

    reg        clk;
    reg        rst;
    reg        start;
    reg  [7:0] data_in;

    wire       tx;
    wire       busy;
    wire       done;

    integer errors;
    integer bit_number;
    reg [7:0] received_byte;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .data_in(data_in),
        .tx(tx),
        .busy(busy),
        .done(done)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    /*
     * Receive one UART frame by sampling each bit near its center.
     * UART data arrives least-significant bit first.
     */
    task receive_uart_byte;
        begin
            received_byte = 8'd0;

            // Wait for falling edge of the start bit
            @(negedge tx);

            // Move to the center of the start bit
            repeat (CLKS_PER_BIT / 2) @(posedge clk);

            if (tx !== 1'b0) begin
                $error("UART start bit was not low");
                errors = errors + 1;
            end

            // Move one full bit period to the center of data bit zero
            repeat (CLKS_PER_BIT) @(posedge clk);

            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                received_byte[bit_number] = tx;
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            // We should now be at the center of the stop bit
            if (tx !== 1'b1) begin
                $error("UART stop bit was not high");
                errors = errors + 1;
            end
        end
    endtask

    task transmit_and_check;
        input [7:0] expected_byte;
        begin
            @(negedge clk);
            data_in = expected_byte;
            start   = 1'b1;

            @(negedge clk);
            start = 1'b0;

            receive_uart_byte;

            if (received_byte !== expected_byte) begin
                $error(
                    "UART byte mismatch: expected 0x%%02h, received 0x%02h",
                    expected_byte,
                    received_byte
                );
                errors = errors + 1;
            end

            wait (done == 1'b1);
            @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;
        rst     = 1'b1;
        start   = 1'b0;
        data_in = 8'd0;

        repeat (3) @(posedge clk);
        rst = 1'b0;

        // Idle UART line must remain high
        repeat (2) @(posedge clk);
        if (tx !== 1'b1) begin
            $error("UART line was not high while idle");
            errors = errors + 1;
        end

        transmit_and_check(8'hA5);
        transmit_and_check(8'h00);
        transmit_and_check(8'hFF);
        transmit_and_check(8'h28);

        if (errors == 0)
            $display("UART TRANSMITTER TESTS PASSED");
        else
            $display("UART TRANSMITTER TESTS FAILED with %0d errors", errors);

        $finish;
    end

endmodule