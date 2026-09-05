`timescale 1ns / 1ps

module fir_filter_tb;

    reg clk;
    reg rst;

    reg signed [11:0] sample_in;
    reg               valid_in;
    reg        [7:0]  index_in;

    wire signed [11:0] sample_out;
    wire               valid_out;
    wire        [7:0]  index_out;

    integer errors;
    integer output_count;
    integer i;

    reg [1:0] test_mode;
    reg signed [11:0] expected_value;


    fir_filter #(
        .SAMPLE_WIDTH(12),
        .INDEX_WIDTH(8)
    ) dut (
        .clk(clk),
        .rst(rst),

        .sample_in(sample_in),
        .valid_in(valid_in),
        .index_in(index_in),

        .sample_out(sample_out),
        .valid_out(valid_out),
        .index_out(index_out)
    );


    initial begin
        clk = 1'b0;
    end

    // 100 MHz clock
    always begin
        #5 clk = ~clk;
    end


    // Apply a synchronous reset
    task reset_dut;
        begin
            @(negedge clk);

            rst       = 1'b1;
            valid_in  = 1'b0;
            sample_in = 12'sd0;
            index_in  = 8'd0;

            repeat (2) @(negedge clk);

            rst = 1'b0;
        end
    endtask


    // Send one valid sample on the next falling edge
    task send_sample;
        input signed [11:0] value;
        input        [7:0]  sample_number;

        begin
            @(negedge clk);

            sample_in = value;
            index_in  = sample_number;
            valid_in  = 1'b1;
        end
    endtask


    // Stop the input stream and allow the pipeline to empty
    task finish_stream;
        begin
            @(negedge clk);

            valid_in  = 1'b0;
            sample_in = 12'sd0;

            repeat (6) @(negedge clk);
        end
    endtask


    initial begin
        errors         = 0;
        output_count   = 0;
        test_mode      = 0;

        rst            = 1'b1;
        valid_in       = 1'b0;
        sample_in      = 12'sd0;
        index_in       = 8'd0;


        // Test 1: positive impulse
        reset_dut;

        test_mode    = 1;
        output_count = 0;

        send_sample(12'sd16, 8'd0);

        for (i = 1; i < 10; i = i + 1)
            send_sample(12'sd0, i);

        finish_stream;

        if (output_count != 10) begin
            $display(
                "ERROR: Positive impulse produced %0d outputs instead of 10",
                output_count
            );

            errors = errors + 1;
        end


        // Test 2: negative impulse verifies signed arithmetic
        reset_dut;

        test_mode    = 2;
        output_count = 0;

        send_sample(-12'sd16, 8'd0);

        for (i = 1; i < 10; i = i + 1)
            send_sample(12'sd0, i);

        finish_stream;

        if (output_count != 10) begin
            $display(
                "ERROR: Negative impulse produced %0d outputs instead of 10",
                output_count
            );

            errors = errors + 1;
        end


        // Test 3: constant input verifies unity steady-state gain
        reset_dut;

        test_mode    = 3;
        output_count = 0;

        for (i = 0; i < 10; i = i + 1)
            send_sample(12'sd16, i);

        finish_stream;

        if (output_count != 10) begin
            $display(
                "ERROR: Constant test produced %0d outputs instead of 10",
                output_count
            );

            errors = errors + 1;
        end


        if (errors == 0)
            $display("FIR TESTS PASSED");
        else
            $display("FIR TESTS FAILED with %0d errors", errors);

        $finish;
    end


    // Determine the expected result for each valid output
    always @(posedge clk) begin
        #1;

        if (valid_out) begin
            output_count = output_count + 1;

            case (test_mode)

                // Expected response to an impulse of +16
                1: begin
                    case (index_out)
                        8'd0: expected_value = 12'sd1;
                        8'd1: expected_value = 12'sd2;
                        8'd2: expected_value = 12'sd3;
                        8'd3: expected_value = 12'sd4;
                        8'd4: expected_value = 12'sd3;
                        8'd5: expected_value = 12'sd2;
                        8'd6: expected_value = 12'sd1;
                        default: expected_value = 12'sd0;
                    endcase
                end

                // Expected response to an impulse of -16
                2: begin
                    case (index_out)
                        8'd0: expected_value = -12'sd1;
                        8'd1: expected_value = -12'sd2;
                        8'd2: expected_value = -12'sd3;
                        8'd3: expected_value = -12'sd4;
                        8'd4: expected_value = -12'sd3;
                        8'd5: expected_value = -12'sd2;
                        8'd6: expected_value = -12'sd1;
                        default: expected_value = 12'sd0;
                    endcase
                end

                // Startup response to a constant input of 16
                3: begin
                    case (index_out)
                        8'd0: expected_value = 12'sd1;
                        8'd1: expected_value = 12'sd3;
                        8'd2: expected_value = 12'sd6;
                        8'd3: expected_value = 12'sd10;
                        8'd4: expected_value = 12'sd13;
                        8'd5: expected_value = 12'sd15;
                        default: expected_value = 12'sd16;
                    endcase
                end

                default: expected_value = 12'sd0;
            endcase


            if (sample_out !== expected_value) begin
                $display(
                    "ERROR: Test %0d index %0d expected %0d received %0d",
                    test_mode,
                    index_out,
                    expected_value,
                    sample_out
                );

                errors = errors + 1;
            end
        end
    end

endmodule