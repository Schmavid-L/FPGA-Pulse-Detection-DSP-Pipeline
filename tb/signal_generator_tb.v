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

    // Nine-bit comparisons prevent overflow in echo_delay + 13
    wire [8:0] sample_index_ext;
    wire [8:0] echo_start_ext;
    wire [8:0] echo_end_ext;

    assign sample_index_ext = {1'b0, sample_index};
    assign echo_start_ext   = {1'b0, echo_delay};
    assign echo_end_ext     = echo_start_ext + 9'd13;


    // Instantiate the design under test
    signal_generator #(
        .SAMPLE_WIDTH(12),
        .FRAME_LENGTH(256),
        .PULSE_AMPLITUDE(12'sd64)
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


    // Generate a 100 MHz clock with a 10 ns period
    always begin
        #5 clk = ~clk;
    end


    // Apply test inputs
    initial begin
        errors         = 0;
        expected_index = 8'd0;

        rst        = 1'b1;
        enable     = 1'b0;
        echo_delay = 8'd40;

        // Hold synchronous reset for two clock cycles
        repeat (2) @(negedge clk);

        // Release reset and begin generating samples
        rst    = 1'b0;
        enable = 1'b1;

        // Run beyond 256 samples to verify index wraparound
        repeat (270) @(negedge clk);

        // Pause the generator
        enable = 1'b0;

        // Allow the disabled state to be checked
        repeat (2) @(negedge clk);

        if (errors == 0)
            $display("SIGNAL GENERATOR TEST PASSED");
        else
            $display(
                "SIGNAL GENERATOR TEST FAILED with %0d errors",
                errors
            );

        $finish;
    end


    // Check outputs after every rising-edge register update
    always @(posedge clk) begin
        // Allow nonblocking assignments inside the DUT to complete
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

            // A new sample must be valid whenever generation is enabled
            if (sample_valid !== 1'b1) begin
                $display(
                    "ERROR: sample_valid was low while enabled"
                );
                errors = errors + 1;
            end


            // Verify the sample position and 255-to-0 wraparound
            if (sample_index !== expected_index) begin
                $display(
                    "ERROR: Index expected %0d, received %0d",                    expected_index,
                    sample_index
                );
                errors = errors + 1;
            end


            // Verify samples inside the 13-position Barker pulse
            if ((sample_index_ext >= echo_start_ext) &&
                (sample_index_ext < echo_end_ext)) begin

                case (sample_index - echo_delay)

                    // Positive Barker positions:
                    // +64 plus noise from -8 through +7
                    8'd0,
                    8'd1,
                    8'd2,
                    8'd3,
                    8'd4,
                    8'd7,
                    8'd8,
                    8'd10,
                    8'd12: begin

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


                    // Negative Barker positions:
                    // -64 plus noise from -8 through +7
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


            // Outside the Barker pulse, only noise should be present
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


            // Eight-bit arithmetic naturally wraps from 255 to 0
            expected_index = expected_index + 1'b1;
        end


        // While disabled, the old output may remain but must be invalid
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