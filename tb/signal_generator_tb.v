`timescale 1ns / 1ps

module signal_generator_tb;

    integer errors;
    reg [7:0] expected_index;

    reg       clk;
    reg       rst;
    reg       enable;
    reg [7:0] echo_delay;

    wire signed [11:0] sample_out;
    wire               sample_valid;
    wire        [7:0]  sample_index;


    // Instantiate the design under test
    signal_generator #(
        .SAMPLE_WIDTH(12),
        .FRAME_LENGTH(256)
    ) dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .echo_delay(echo_delay),
        .sample_out(sample_out),
        .sample_valid(sample_valid),
        .sample_index(sample_index)
    );


    // Initialize the clock
    initial begin
        clk = 1'b0;
    end


    // Generate a 100 MHz clock: 10 ns period
    always begin
        #5 clk = ~clk;
    end


    // Apply inputs to the design
    initial begin
        errors         = 0;
        expected_index = 8'd0;

        rst        = 1'b1;
        enable     = 1'b0;
        echo_delay = 8'd40;

        // Hold reset for two clock cycles
        repeat (2) @(negedge clk);

        // Release reset and begin generating samples
        rst    = 1'b0;
        enable = 1'b1;

        // Generate enough samples to test 255-to-0 wraparound
        repeat (270) @(negedge clk);

        // Pause the generator
        enable = 1'b0;

        // Allow the disabled state to be checked
        repeat (2) @(negedge clk);

        // Print the final verification result
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED with %0d errors", errors);

        $finish;
    end


    // Automatically check the outputs after each rising clock edge
    always @(posedge clk) begin
        // Wait for nonblocking assignments in the DUT to update
        #1;

        if (rst) begin
            expected_index = 8'd0;

            if ((sample_index !== 8'd0) ||
                (sample_out !== 12'sd0) ||
                (sample_valid !== 1'b0)) begin

                $display("ERROR: Reset outputs are incorrect");
                errors = errors + 1;
            end
        end

        else if (enable) begin
            if (sample_valid !== 1'b1) begin
                $display(
                    "ERROR: sample_valid was low while enabled"
                );
                errors = errors + 1;
            end

            if (sample_index !== expected_index) begin
                $display(
                    "ERROR: Index expected %0d, received %0d",
                    expected_index,
                    sample_index
                );
                // Verify samples inside the 13-position Barker pulse
if ((sample_index >= echo_delay) &&
    (sample_index < echo_delay + 8'd13)) begin

    case (sample_index - echo_delay)

        // Positive Barker positions should equal +64 plus noise
        8'd0, 8'd1, 8'd2, 8'd3, 8'd4,
        8'd7, 8'd8, 8'd10, 8'd12: begin

            if ((sample_out < 12'sd56) ||
                (sample_out > 12'sd71)) begin

                $display(
                    "ERROR: Positive pulse out of range at index %0d: %0d",
                    sample_index,
                    sample_out
                );

                errors = errors + 1;
            end
        end

        // Negative Barker positions should equal -64 plus noise
        default: begin
            if ((sample_out < -12'sd72) ||
                (sample_out > -12'sd57)) begin

                $display(
                    "ERROR: Negative pulse out of range at index %0d: %0d",
                    sample_index,
                    sample_out
                );

                errors = errors + 1;
            end
        end
    endcase
end

// Outside the pulse, only noise should be present
else begin
    if ((sample_out < -12'sd8) ||
        (sample_out > 12'sd7)) begin

        $display(
            "ERROR: Noise out of range at index %0d: %0d",
            sample_index,
            sample_out
        );

        errors = errors + 1;
    end
end
                errors = errors + 1;
            end

            // Eight-bit overflow automatically wraps 255 to 0
            expected_index = expected_index + 1'b1;
        end

        else begin
            if (sample_valid !== 1'b0) begin
                $display(
                    "ERROR: sample_valid remained high while disabled"
                );
                errors = errors + 1;
            end
        end
    end

endmodule