`timescale 1ns / 1ps

module pulse_detector_tb;

    reg clk;
    reg rst;

    reg signed [15:0] correlation_in;
    reg               valid_in;
    reg        [7:0]  index_in;
    reg        [15:0] threshold;

    wire        detection_valid;
    wire        detected;
    wire [15:0] peak_magnitude;
    wire [7:0]  peak_index;

    integer errors;


    // Instantiate the design under test
    pulse_detector #(
        .CORR_WIDTH(16),
        .INDEX_WIDTH(8),
        .FRAME_LENGTH(256)
    ) dut (
        .clk(clk),
        .rst(rst),

        .correlation_in(correlation_in),
        .valid_in(valid_in),
        .index_in(index_in),
        .threshold(threshold),

        .detection_valid(detection_valid),
        .detected(detected),
        .peak_magnitude(peak_magnitude),
        .peak_index(peak_index)
    );


    // Initialize the clock
    initial begin
        clk = 1'b0;
    end


    // Generate a 100 MHz clock
    always begin
        #5 clk = ~clk;
    end


    // Apply a synchronous reset
    task reset_dut;
        begin
            @(negedge clk);

            rst            = 1'b1;
            valid_in       = 1'b0;
            correlation_in = 16'sd0;
            index_in       = 8'd0;

            repeat (2) @(negedge clk);

            rst = 1'b0;
        end
    endtask


    // Send one valid correlation result
    task send_correlation;
        input signed [15:0] value;
        input        [7:0]  sample_index;

        begin
            @(negedge clk);

            correlation_in = value;
            index_in       = sample_index;
            valid_in       = 1'b1;
        end
    endtask


    // Send an invalid value that the detector must ignore
    task send_invalid;
        input signed [15:0] value;
        input        [7:0]  sample_index;

        begin
            @(negedge clk);

            correlation_in = value;
            index_in       = sample_index;
            valid_in       = 1'b0;
        end
    endtask


    // Check the result produced after index 255
    task check_result;
        input        expected_detected;
        input [15:0] expected_magnitude;
        input [7:0]  expected_index;

        begin
            @(posedge clk);
            #1;

            if (detection_valid !== 1'b1) begin
                $display(
                    "ERROR: detection_valid was not asserted"
                );
                errors = errors + 1;
            end

            if (detected !== expected_detected) begin
                $display(
                    "ERROR: detected expected %0d, received %0d",
                    expected_detected,
                    detected
                );
                errors = errors + 1;
            end

            if (peak_magnitude !== expected_magnitude) begin
                $display(
                    "ERROR: Peak expected %0d, received %0d",
                    expected_magnitude,
                    peak_magnitude
                );
                errors = errors + 1;
            end

            if (peak_index !== expected_index) begin
                $display(
                    "ERROR: Peak index expected %0d, received %0d",
                    expected_index,
                    peak_index
                );
                errors = errors + 1;
            end
        end
    endtask


    initial begin
        errors         = 0;
        rst            = 1'b1;
        valid_in       = 1'b0;
        correlation_in = 16'sd0;
        index_in       = 8'd0;
        threshold      = 16'd500;

        reset_dut;


        // Test 1:
        // A positive peak above the threshold should be detected
        send_correlation(16'sd100, 8'd0);
        send_correlation(16'sd600, 8'd40);
        send_correlation(-16'sd450, 8'd100);
        send_correlation(16'sd200, 8'd255);

        check_result(
            1'b1,
            16'd600,
            8'd40
        );


        // Test 2:
        // A negative correlation uses its positive magnitude
        // This also verifies that peak tracking restarted after Test 1
        send_correlation(16'sd100, 8'd0);
        send_correlation(-16'sd700, 8'd80);
        send_correlation(16'sd150, 8'd255);

        check_result(
            1'b1,
            16'd700,
            8'd80
        );


        // Test 3:
        // An invalid value of 1000 must be ignored
        // The valid peak of 499 remains below the threshold
        send_invalid(16'sd1000, 8'd25);
        send_correlation(16'sd499, 8'd33);
        send_correlation(-16'sd300, 8'd100);
        send_correlation(16'sd100, 8'd255);

        check_result(
            1'b0,
            16'd499,
            8'd33
        );


        // Test 4:
        // The final sample at index 255 must participate
        // in the peak comparison
        send_correlation(16'sd400, 8'd10);
        send_correlation(-16'sd900, 8'd255);

        check_result(
            1'b1,
            16'd900,
            8'd255
        );


        // Verify detection_valid returns low after one cycle
        @(negedge clk);
        valid_in       = 1'b0;
        correlation_in = 16'sd0;

        @(posedge clk);
        #1;

        if (detection_valid !== 1'b0) begin
            $display(
                "ERROR: detection_valid remained high"
            );
            errors = errors + 1;
        end


        if (errors == 0)
            $display("PULSE DETECTOR TESTS PASSED");
        else
            $display(
                "PULSE DETECTOR TESTS FAILED with %0d errors",
                errors
            );

        $finish;
    end

endmodule