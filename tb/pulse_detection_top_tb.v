`timescale 1ns / 1ps

module pulse_detection_top_tb;

    reg clk;
    reg rst;
    reg enable;

    reg  [7:0]  echo_delay;
    reg  [15:0] threshold;

    wire        detection_valid;
    wire        detected;
    wire [15:0] peak_magnitude;
    wire [7:0]  peak_index;
    wire [7:0]  estimated_delay;

    wire signed [15:0] correlation_out;
    wire               correlation_valid;
    wire        [7:0]  correlation_index;

    reg [15:0] observed_peak;
    reg [7:0]  observed_peak_index;
    reg [15:0] background_peak;

    integer errors;


    // Convert signed correlation into unsigned magnitude
    wire [15:0] correlation_magnitude;

    assign correlation_magnitude =
        correlation_out[15]
            ? (~correlation_out + 1'b1)
            : correlation_out;


    // Instantiate the complete DSP pipeline
    pulse_detection_top #(
        .SAMPLE_WIDTH(12),
        .INDEX_WIDTH(8),
        .CORR_WIDTH(16),
        .FRAME_LENGTH(256),
        .DELAY_OFFSET(15)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),

        .echo_delay(echo_delay),
        .threshold(threshold),

        .detection_valid(detection_valid),
        .detected(detected),
        .peak_magnitude(peak_magnitude),
        .peak_index(peak_index),
        .estimated_delay(estimated_delay),

        .correlation_out(correlation_out),
        .correlation_valid(correlation_valid),
        .correlation_index(correlation_index)
    );


    // Initialize the clock
    initial begin
        clk = 1'b0;
    end


    // Generate a 100 MHz clock
    always begin
        #5 clk = ~clk;
    end


    // Apply one complete-frame test
    initial begin
        errors              = 0;
        observed_peak       = 16'd0;
        observed_peak_index = 8'd0;
        background_peak     = 16'd0;

        rst        = 1'b1;
        enable     = 1'b0;
        echo_delay = 8'd40;

        // Selected between the measured background of 23
        // and the measured pulse peak of 214
        threshold = 16'd100;

        // Hold synchronous reset for two clock cycles
        repeat (2) @(negedge clk);

        rst    = 1'b0;
        enable = 1'b1;

        // Wait for one completed 256-sample frame
        wait (detection_valid == 1'b1);

        @(negedge clk);
        enable = 1'b0;


        // The detector must report a pulse above threshold
        if (detected !== 1'b1) begin
            $display(
                "ERROR: Expected a pulse detection"
            );
            errors = errors + 1;
        end


        // The deterministic integrated pipeline produces
        // a correlation magnitude of 214
        if (peak_magnitude !== 16'd214) begin
            $display(
                "ERROR: Peak expected 214, received %0d",
                peak_magnitude
            );
            errors = errors + 1;
        end


        // Pulse begins at 40, Barker completion adds 12,
        // and FIR group delay adds 3: 40 + 12 + 3 = 55
        if (peak_index !== 8'd55) begin
            $display(
                "ERROR: Peak index expected 55, received %0d",
                peak_index
            );
            errors = errors + 1;
        end


        // Remove the 15-sample offset to recover echo_delay
        if (estimated_delay !== echo_delay) begin
            $display(
                "ERROR: Delay expected %0d, received %0d",
                echo_delay,
                estimated_delay
            );
            errors = errors + 1;
        end


        // Independently tracked peak must match the detector
        if (peak_magnitude !== observed_peak) begin
            $display(
                "ERROR: Detector peak %0d does not match observed peak %0d",
                peak_magnitude,
                observed_peak
            );
            errors = errors + 1;
        end

        if (peak_index !== observed_peak_index) begin
            $display(
                "ERROR: Detector index %0d does not match observed index %0d",
                peak_index,
                observed_peak_index
            );
            errors = errors + 1;
        end


        // Confirm that the chosen threshold separates
        // background response from the coded-pulse response
        if (background_peak >= threshold) begin
            $display(
                "ERROR: Background peak %0d reached threshold %0d",
                background_peak,
                threshold
            );
            errors = errors + 1;
        end

        if (peak_magnitude < threshold) begin
            $display(
                "ERROR: Pulse peak %0d was below threshold %0d",
                peak_magnitude,
                threshold
            );
            errors = errors + 1;
        end


        $display("--------------------------------------------");
        $display("FINAL FULL PIPELINE RESULTS");
        $display("Echo delay input:           %0d", echo_delay);
        $display("Correlation peak:           %0d", peak_magnitude);
        $display("Correlation peak index:     %0d", peak_index);
        $display("Estimated delay:            %0d", estimated_delay);
        $display("Background maximum:         %0d", background_peak);
        $display("Detection threshold:        %0d", threshold);
        $display("--------------------------------------------");


        if (errors == 0)
            $display("FULL PIPELINE TEST PASSED");
        else
            $display(
                "FULL PIPELINE TEST FAILED with %0d errors",
                errors
            );

        $finish;
    end


    // Independently monitor the correlator stream
    always @(posedge clk) begin
        #1;

        if (rst) begin
            observed_peak       = 16'd0;
            observed_peak_index = 8'd0;
            background_peak     = 16'd0;
        end

        else if (correlation_valid) begin

            if (correlation_magnitude > observed_peak) begin
                observed_peak       = correlation_magnitude;
                observed_peak_index = correlation_index;
            end

            // Exclude the region affected by the filtered pulse
            if ((correlation_index < 8'd25) ||
                (correlation_index > 8'd75)) begin

                if (correlation_magnitude > background_peak)
                    background_peak = correlation_magnitude;
            end
        end
    end

endmodule