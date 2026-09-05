`timescale 1ns / 1ps

module matched_correlator_tb;

    reg clk;
    reg rst;

    reg signed [11:0] sample_in;
    reg               valid_in;
    reg        [7:0]  index_in;

    wire signed [15:0] correlation_out;
    wire               valid_out;
    wire        [7:0]  index_out;

    integer errors;
    integer output_count;
    integer i;

    reg               peak_seen;
    reg signed [15:0] maximum_correlation;
    reg        [7:0]  maximum_index;


    matched_correlator #(
        .SAMPLE_WIDTH(12),
        .INDEX_WIDTH(8),
        .CORR_WIDTH(16)
    ) dut (
        .clk(clk),
        .rst(rst),

        .sample_in(sample_in),
        .valid_in(valid_in),
        .index_in(index_in),

        .correlation_out(correlation_out),
        .valid_out(valid_out),
        .index_out(index_out)
    );


    initial begin
        clk = 1'b0;
    end

    // Generate a 100 MHz clock
    always begin
        #5 clk = ~clk;
    end


    // Send one sample to the correlator
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


    initial begin
        errors              = 0;
        output_count        = 0;
        peak_seen           = 1'b0;
        maximum_correlation = 16'sd0;
        maximum_index       = 8'd0;

        rst       = 1'b1;
        valid_in  = 1'b0;
        sample_in = 12'sd0;
        index_in  = 8'd0;

        // Hold synchronous reset for two clock cycles
        repeat (2) @(negedge clk);

        rst = 1'b0;


        // Send the Barker-13 sequence with amplitude 64
        send_sample( 12'sd64, 8'd0);
        send_sample( 12'sd64, 8'd1);
        send_sample( 12'sd64, 8'd2);
        send_sample( 12'sd64, 8'd3);
        send_sample( 12'sd64, 8'd4);
        send_sample(-12'sd64, 8'd5);
        send_sample(-12'sd64, 8'd6);
        send_sample( 12'sd64, 8'd7);
        send_sample( 12'sd64, 8'd8);
        send_sample(-12'sd64, 8'd9);
        send_sample( 12'sd64, 8'd10);
        send_sample(-12'sd64, 8'd11);
        send_sample( 12'sd64, 8'd12);


        // Send zeros after the pulse
        for (i = 13; i < 21; i = i + 1)
            send_sample(12'sd0, i);

        @(negedge clk);
        valid_in  = 1'b0;
        sample_in = 12'sd0;

        // Allow the correlation pipeline to empty
        repeat (8) @(negedge clk);


        if (!peak_seen) begin
            $display("ERROR: Expected correlation peak was not observed");
            errors = errors + 1;
        end

        if (maximum_correlation !== 16'sd832) begin
            $display(
                "ERROR: Maximum correlation expected 832, received %0d",
                maximum_correlation
            );

            errors = errors + 1;
        end

        if (maximum_index !== 8'd12) begin
            $display(
                "ERROR: Maximum expected at index 12, received index %0d",
                maximum_index
            );

            errors = errors + 1;
        end


        if (errors == 0)
            $display("MATCHED CORRELATOR TEST PASSED");
        else
            $display(
                "MATCHED CORRELATOR TEST FAILED with %0d errors",
                errors
            );

        $finish;
    end


    // Check correlation results after each pipeline update
    always @(posedge clk) begin
        #1;

        if (valid_out) begin
            output_count = output_count + 1;

            // Track the strongest correlation and its index
            if (correlation_out > maximum_correlation) begin
                maximum_correlation = correlation_out;
                maximum_index       = index_out;
            end

            // A complete Barker match should produce 13 × 64 = 832
            if (index_out == 8'd12) begin
                peak_seen = 1'b1;

                if (correlation_out !== 16'sd832) begin
                    $display(
                        "ERROR: Index 12 expected 832, received %0d",
                        correlation_out
                    );

                    errors = errors + 1;
                end
            end
        end
    end

endmodule
