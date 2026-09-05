`timescale 1ns / 1ps

module fir_filter #(
    parameter SAMPLE_WIDTH = 12,
    parameter INDEX_WIDTH  = 8
)(
    input  wire                           clk,
    input  wire                           rst,

    input  wire signed [SAMPLE_WIDTH-1:0] sample_in,
    input  wire                           valid_in,
    input  wire        [INDEX_WIDTH-1:0]  index_in,

    output reg signed [SAMPLE_WIDTH-1:0] sample_out,
    output reg                           valid_out,
    output reg        [INDEX_WIDTH-1:0]  index_out
);

    // Previous six samples form the seven-tap input window
    reg signed [SAMPLE_WIDTH-1:0] delay_1;
    reg signed [SAMPLE_WIDTH-1:0] delay_2;
    reg signed [SAMPLE_WIDTH-1:0] delay_3;
    reg signed [SAMPLE_WIDTH-1:0] delay_4;
    reg signed [SAMPLE_WIDTH-1:0] delay_5;
    reg signed [SAMPLE_WIDTH-1:0] delay_6;


    // Stage 1 requires one extra bit for adding two samples
    localparam PAIR_WIDTH = SAMPLE_WIDTH + 1;

    reg signed [PAIR_WIDTH-1:0] pair_1;
    reg signed [PAIR_WIDTH-1:0] pair_2;
    reg signed [PAIR_WIDTH-1:0] pair_3;
    reg signed [PAIR_WIDTH-1:0] center_sample;

    reg                     valid_stage_1;
    reg [INDEX_WIDTH-1:0]   index_stage_1;


    // Stage 2 requires room for multiplication by up to four
    localparam TERM_WIDTH = SAMPLE_WIDTH + 3;

    wire signed [TERM_WIDTH-1:0] pair_1_extended;
    wire signed [TERM_WIDTH-1:0] pair_2_extended;
    wire signed [TERM_WIDTH-1:0] pair_3_extended;
    wire signed [TERM_WIDTH-1:0] center_extended;

    reg signed [TERM_WIDTH-1:0] term_1;
    reg signed [TERM_WIDTH-1:0] term_2;
    reg signed [TERM_WIDTH-1:0] term_3;
    reg signed [TERM_WIDTH-1:0] term_4;

    reg                     valid_stage_2;
    reg [INDEX_WIDTH-1:0]   index_stage_2;


    // The complete weighted sum can grow by four bits
    localparam SUM_WIDTH = SAMPLE_WIDTH + 4;

    wire signed [SUM_WIDTH-1:0] term_1_extended;
    wire signed [SUM_WIDTH-1:0] term_2_extended;
    wire signed [SUM_WIDTH-1:0] term_3_extended;
    wire signed [SUM_WIDTH-1:0] term_4_extended;

    reg signed [SUM_WIDTH-1:0] partial_sum_1;
    reg signed [SUM_WIDTH-1:0] partial_sum_2;

    reg                     valid_stage_3;
    reg [INDEX_WIDTH-1:0]   index_stage_3;


    // Sign-extend Stage 1 results before shifting and adding
    assign pair_1_extended =
        {{(TERM_WIDTH-PAIR_WIDTH){pair_1[PAIR_WIDTH-1]}}, pair_1};

    assign pair_2_extended =
        {{(TERM_WIDTH-PAIR_WIDTH){pair_2[PAIR_WIDTH-1]}}, pair_2};

    assign pair_3_extended =
        {{(TERM_WIDTH-PAIR_WIDTH){pair_3[PAIR_WIDTH-1]}}, pair_3};

    assign center_extended =
        {{(TERM_WIDTH-PAIR_WIDTH){center_sample[PAIR_WIDTH-1]}},
          center_sample};


    // Sign-extend Stage 2 results before the adder tree
    assign term_1_extended =
        {{(SUM_WIDTH-TERM_WIDTH){term_1[TERM_WIDTH-1]}}, term_1};

    assign term_2_extended =
        {{(SUM_WIDTH-TERM_WIDTH){term_2[TERM_WIDTH-1]}}, term_2};

    assign term_3_extended =
        {{(SUM_WIDTH-TERM_WIDTH){term_3[TERM_WIDTH-1]}}, term_3};

    assign term_4_extended =
        {{(SUM_WIDTH-TERM_WIDTH){term_4[TERM_WIDTH-1]}}, term_4};


    // Stage 1: shift samples and calculate symmetric pairs
    always @(posedge clk) begin
        if (rst) begin
            delay_1 <= {SAMPLE_WIDTH{1'b0}};
            delay_2 <= {SAMPLE_WIDTH{1'b0}};
            delay_3 <= {SAMPLE_WIDTH{1'b0}};
            delay_4 <= {SAMPLE_WIDTH{1'b0}};
            delay_5 <= {SAMPLE_WIDTH{1'b0}};
            delay_6 <= {SAMPLE_WIDTH{1'b0}};

            pair_1        <= {PAIR_WIDTH{1'b0}};
            pair_2        <= {PAIR_WIDTH{1'b0}};
            pair_3        <= {PAIR_WIDTH{1'b0}};
            center_sample <= {PAIR_WIDTH{1'b0}};

            valid_stage_1 <= 1'b0;
            index_stage_1 <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_in) begin
            delay_6 <= delay_5;
            delay_5 <= delay_4;
            delay_4 <= delay_3;
            delay_3 <= delay_2;
            delay_2 <= delay_1;
            delay_1 <= sample_in;

            // Use symmetry to reduce seven weighted terms to four
            pair_1 <=
                {sample_in[SAMPLE_WIDTH-1], sample_in} +
                {delay_6[SAMPLE_WIDTH-1], delay_6};

            pair_2 <=
                {delay_1[SAMPLE_WIDTH-1], delay_1} +
                {delay_5[SAMPLE_WIDTH-1], delay_5};

            pair_3 <=
                {delay_2[SAMPLE_WIDTH-1], delay_2} +
                {delay_4[SAMPLE_WIDTH-1], delay_4};

            center_sample <=
                {delay_3[SAMPLE_WIDTH-1], delay_3};

            valid_stage_1 <= 1'b1;
            index_stage_1 <= index_in;
        end

        else begin
            valid_stage_1 <= 1'b0;
        end
    end


    // Stage 2: apply weights 1, 2, 3, and 4 in parallel
    always @(posedge clk) begin
        if (rst) begin
            term_1 <= {TERM_WIDTH{1'b0}};
            term_2 <= {TERM_WIDTH{1'b0}};
            term_3 <= {TERM_WIDTH{1'b0}};
            term_4 <= {TERM_WIDTH{1'b0}};

            valid_stage_2 <= 1'b0;
            index_stage_2 <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_stage_1) begin
            term_1 <= pair_1_extended;

            // Multiplication by two
            term_2 <= pair_2_extended <<< 1;

            // Multiplication by three: 3x = 2x + x
            term_3 <=
                (pair_3_extended <<< 1) +
                pair_3_extended;

            // Multiplication by four
            term_4 <= center_extended <<< 2;

            valid_stage_2 <= 1'b1;
            index_stage_2 <= index_stage_1;
        end

        else begin
            valid_stage_2 <= 1'b0;
        end
    end


    // Stage 3: first level of the parallel adder tree
    always @(posedge clk) begin
        if (rst) begin
            partial_sum_1 <= {SUM_WIDTH{1'b0}};
            partial_sum_2 <= {SUM_WIDTH{1'b0}};

            valid_stage_3 <= 1'b0;
            index_stage_3 <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_stage_2) begin
            partial_sum_1 <= term_1_extended + term_2_extended;
            partial_sum_2 <= term_3_extended + term_4_extended;

            valid_stage_3 <= 1'b1;
            index_stage_3 <= index_stage_2;
        end

        else begin
            valid_stage_3 <= 1'b0;
        end
    end


    // Stage 4: final addition and normalization by 16
    always @(posedge clk) begin
        if (rst) begin
            sample_out <= {SAMPLE_WIDTH{1'b0}};
            valid_out  <= 1'b0;
            index_out  <= {INDEX_WIDTH{1'b0}};
        end

        else if (valid_stage_3) begin
            // Arithmetic shift preserves the sign of negative values
            sample_out <=
                (partial_sum_1 + partial_sum_2) >>> 4;

            valid_out <= 1'b1;
            index_out <= index_stage_3;
        end

        else begin
            valid_out <= 1'b0;
        end
    end

endmodule