`timescale 1ns / 1ps

module matched_correlator #(
    parameter SAMPLE_WIDTH = 12,
    parameter INDEX_WIDTH  = 8,
    parameter CORR_WIDTH   = SAMPLE_WIDTH + 4
)(
    input  wire                           clk,
    input  wire                           rst,

    input  wire signed [SAMPLE_WIDTH-1:0] sample_in,
    input  wire                           valid_in,
    input  wire        [INDEX_WIDTH-1:0]  index_in,

    output reg signed [CORR_WIDTH-1:0] correlation_out,
    output reg                         valid_out,
    output reg        [INDEX_WIDTH-1:0] index_out
);

    // Previous twelve samples plus sample_in form a 13-sample window
    reg signed [SAMPLE_WIDTH-1:0] sample_d1;
    reg signed [SAMPLE_WIDTH-1:0] sample_d2;
    reg signed [SAMPLE_WIDTH-1:0] sample_d3;
    reg signed [SAMPLE_WIDTH-1:0] sample_d4;
    reg signed [SAMPLE_WIDTH-1:0] sample_d5;
    reg signed [SAMPLE_WIDTH-1:0] sample_d6;
    reg signed [SAMPLE_WIDTH-1:0] sample_d7;
    reg signed [SAMPLE_WIDTH-1:0] sample_d8;
    reg signed [SAMPLE_WIDTH-1:0] sample_d9;
    reg signed [SAMPLE_WIDTH-1:0] sample_d10;
    reg signed [SAMPLE_WIDTH-1:0] sample_d11;
    reg signed [SAMPLE_WIDTH-1:0] sample_d12;


    // Stage 1 applies the Barker signs in seven parallel groups
    localparam STAGE_1_WIDTH = SAMPLE_WIDTH + 2;

    reg signed [STAGE_1_WIDTH-1:0] group_1;
    reg signed [STAGE_1_WIDTH-1:0] group_2;
    reg signed [STAGE_1_WIDTH-1:0] group_3;
    reg signed [STAGE_1_WIDTH-1:0] group_4;
    reg signed [STAGE_1_WIDTH-1:0] group_5;
    reg signed [STAGE_1_WIDTH-1:0] group_6;
    reg signed [STAGE_1_WIDTH-1:0] group_7;

    reg                       valid_stage_1;
    reg [INDEX_WIDTH-1:0]     index_stage_1;


    // Stage 2 combines seven groups into four partial sums
    localparam STAGE_2_WIDTH = SAMPLE_WIDTH + 3;

    reg signed [STAGE_2_WIDTH-1:0] sum_12;
    reg signed [STAGE_2_WIDTH-1:0] sum_34;
    reg signed [STAGE_2_WIDTH-1:0] sum_56;
    reg signed [STAGE_2_WIDTH-1:0] sum_7;

    reg                       valid_stage_2;
    reg [INDEX_WIDTH-1:0]     index_stage_2;


    // Stage 3 creates two correlation halves
    reg signed [CORR_WIDTH-1:0] correlation_half_1;
    reg signed [CORR_WIDTH-1:0] correlation_half_2;

    reg                        valid_stage_3;
    reg [INDEX_WIDTH-1:0]      index_stage_3;


    // Sign-extend input samples before Stage 1 arithmetic
    function signed [STAGE_1_WIDTH-1:0] extend_sample;
        input signed [SAMPLE_WIDTH-1:0] value;

        begin
            extend_sample =
                {{(STAGE_1_WIDTH-SAMPLE_WIDTH)
                    {value[SAMPLE_WIDTH-1]}},
                  value};
        end
    endfunction


    // Sign-extend Stage 1 groups before Stage 2 arithmetic
    function signed [STAGE_2_WIDTH-1:0] extend_group;
        input signed [STAGE_1_WIDTH-1:0] value;

        begin
            extend_group =
                {{(STAGE_2_WIDTH-STAGE_1_WIDTH)
                    {value[STAGE_1_WIDTH-1]}},
                  value};
        end
    endfunction


    // Sign-extend Stage 2 sums before Stage 3 arithmetic
    function signed [CORR_WIDTH-1:0] extend_sum;
        input signed [STAGE_2_WIDTH-1:0] value;

        begin
            extend_sum =
                {{(CORR_WIDTH-STAGE_2_WIDTH)
                    {value[STAGE_2_WIDTH-1]}},
                  value};
        end
    endfunction


    // Store the most recent twelve samples
    always @(posedge clk) begin
        if (rst) begin
            sample_d1  <= {SAMPLE_WIDTH{1'b0}};
            sample_d2  <= {SAMPLE_WIDTH{1'b0}};
            sample_d3  <= {SAMPLE_WIDTH{1'b0}};
            sample_d4  <= {SAMPLE_WIDTH{1'b0}};
            sample_d5  <= {SAMPLE_WIDTH{1'b0}};
            sample_d6  <= {SAMPLE_WIDTH{1'b0}};
            sample_d7  <= {SAMPLE_WIDTH{1'b0}};
            sample_d8  <= {SAMPLE_WIDTH{1'b0}};
            sample_d9  <= {SAMPLE_WIDTH{1'b0}};
            sample_d10 <= {SAMPLE_WIDTH{1'b0}};
            sample_d11 <= {SAMPLE_WIDTH{1'b0}};
            sample_d12 <= {SAMPLE_WIDTH{1'b0}};
        end

        else if (valid_in) begin
            sample_d12 <= sample_d11;
            sample_d11 <= sample_d10;
            sample_d10 <= sample_d9;
            sample_d9  <= sample_d8;
            sample_d8  <= sample_d7;
            sample_d7  <= sample_d6;
            sample_d6  <= sample_d5;
            sample_d5  <= sample_d4;
            sample_d4  <= sample_d3;
            sample_d3  <= sample_d2;
            sample_d2  <= sample_d1;
            sample_d1  <= sample_in;
        end
    end


    // Stage 1: apply Barker signs from newest sample to oldest
    always @(posedge clk) begin
        if (rst) begin
            group_1 <= {STAGE_1_WIDTH{1'b0}};
            group_2 <= {STAGE_1_WIDTH{1'b0}};
            group_3 <= {STAGE_1_WIDTH{1'b0}};
            group_4 <= {STAGE_1_WIDTH{1'b0}};
            group_5 <= {STAGE_1_WIDTH{1'b0}};
            group_6 <= {STAGE_1_WIDTH{1'b0}};
            group_7 <= {STAGE_1_WIDTH{1'b0}};

            valid_stage_1 <= 1'b0;
            index_stage_1 <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_in) begin
            // Reversed Barker-13 signs:
            // + - + - + + - - + + + + +

            group_1 <=
                extend_sample(sample_in) -
                extend_sample(sample_d1);

            group_2 <=
                extend_sample(sample_d2) -
                extend_sample(sample_d3);

            group_3 <=
                extend_sample(sample_d4) +
                extend_sample(sample_d5);

            group_4 <=
                -extend_sample(sample_d6) -
                 extend_sample(sample_d7);

            group_5 <=
                extend_sample(sample_d8) +
                extend_sample(sample_d9);

            group_6 <=
                extend_sample(sample_d10) +
                extend_sample(sample_d11);

            group_7 <=
                extend_sample(sample_d12);

            valid_stage_1 <= 1'b1;
            index_stage_1 <= index_in;
        end

        else begin
            valid_stage_1 <= 1'b0;
        end
    end


    // Stage 2: reduce seven groups to four partial sums
    always @(posedge clk) begin
        if (rst) begin
            sum_12 <= {STAGE_2_WIDTH{1'b0}};
            sum_34 <= {STAGE_2_WIDTH{1'b0}};
            sum_56 <= {STAGE_2_WIDTH{1'b0}};
            sum_7  <= {STAGE_2_WIDTH{1'b0}};

            valid_stage_2 <= 1'b0;
            index_stage_2 <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_stage_1) begin
            sum_12 <=
                extend_group(group_1) +
                extend_group(group_2);

            sum_34 <=
                extend_group(group_3) +
                extend_group(group_4);

            sum_56 <=
                extend_group(group_5) +
                extend_group(group_6);

            sum_7 <= extend_group(group_7);

            valid_stage_2 <= 1'b1;
            index_stage_2 <= index_stage_1;
        end

        else begin
            valid_stage_2 <= 1'b0;
        end
    end


    // Stage 3: reduce four partial sums to two halves
    always @(posedge clk) begin
        if (rst) begin
            correlation_half_1 <= {CORR_WIDTH{1'b0}};
            correlation_half_2 <= {CORR_WIDTH{1'b0}};

            valid_stage_3 <= 1'b0;
            index_stage_3 <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_stage_2) begin
            correlation_half_1 <=
                extend_sum(sum_12) +
                extend_sum(sum_34);

            correlation_half_2 <=
                extend_sum(sum_56) +
                extend_sum(sum_7);

            valid_stage_3 <= 1'b1;
            index_stage_3 <= index_stage_2;
        end

        else begin
            valid_stage_3 <= 1'b0;
        end
    end


    // Stage 4: calculate the final correlation
    always @(posedge clk) begin
        if (rst) begin
            correlation_out <= {CORR_WIDTH{1'b0}};
            valid_out       <= 1'b0;
            index_out       <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_stage_3) begin
            correlation_out <=
                correlation_half_1 +
                correlation_half_2;

            valid_out <= 1'b1;
            index_out <= index_stage_3;
        end

        else begin
            valid_out <= 1'b0;
        end
    end

endmodule