/* Authors: 
 * Kevin Han kevinhan
 * Gaurav Goel gg8
 */

`timescale 1ns / 1ns

// quotient = dividend / divisor

typedef struct packed {
  logic [31:0] dividend;
  logic [31:0] divisor;
  logic [31:0] remainder;
  logic [31:0] quotient;
} divide_stage_reg;

module DividerUnsignedPipelined (
    input wire clk, rst, stall,
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

  wire [31:0] dividend [32];
  wire [31:0] remainder[31];
  wire [31:0] quotient [31];
  divide_stage_reg regs [7];

  // FINAL STAGE
  divu_1iter first_final_divide_iter (
      .i_dividend (regs[6].dividend),
      .i_divisor  (regs[6].divisor),
      .i_remainder(regs[6].remainder),
      .i_quotient (regs[6].quotient),
      .o_dividend (dividend[28]),
      .o_remainder(remainder[28]),
      .o_quotient (quotient[28])
    );

  genvar i;
  for (i = 29; i < 31; i = i + 1) begin : gen_final_stage
    divu_1iter intermediate_final_divide_iters (
      .i_dividend (dividend[i-1]),
      .i_divisor  (regs[6].divisor),
      .i_remainder(remainder[i-1]),
      .i_quotient (quotient[i-1]),
      .o_dividend (dividend[i]),
      .o_remainder(remainder[i]),
      .o_quotient (quotient[i])
    );
  end

  divu_1iter final_final_divide_iter (
    .i_dividend (dividend[30]),
    .i_divisor  (regs[6].divisor),
    .i_remainder(remainder[30]),
    .i_quotient (quotient[30]),
    .o_dividend (dividend[31]),
    .o_remainder(o_remainder),
    .o_quotient (o_quotient)
  );

  // INTERMEDIARY STAGES
  genvar s;
  for (s = 6; s > 0; s = s - 1) begin : gen_inter_stages
    divu_1iter first_intermediate_divide_iter (
      .i_dividend (regs[s-1].dividend),
      .i_divisor  (regs[s-1].divisor),
      .i_remainder(regs[s-1].remainder),
      .i_quotient (regs[s-1].quotient),
      .o_dividend (dividend[4*s]),
      .o_remainder(remainder[4*s]),
      .o_quotient (quotient[4*s])
    );

    genvar j;
    for (j = (4*s)+1; j < 4*(s+1); j = j + 1) begin : gen_j_iters
      divu_1iter intermediate_intermediate_divide_iters (
        .i_dividend (dividend[j-1]),
        .i_divisor  (regs[s-1].divisor),
        .i_remainder(remainder[j-1]),
        .i_quotient (quotient[j-1]),
        .o_dividend (dividend[j]),
        .o_remainder(remainder[j]),
        .o_quotient (quotient[j])
      );
    end

    always_ff @(posedge clk) begin
      regs[s].dividend <= dividend[4*s+3];
      regs[s].divisor <= regs[s-1].divisor;
      regs[s].remainder <= remainder[4*s+3];
      regs[s].quotient <= quotient[4*s+3];
    end
  end

  // FIRST STAGE
  divu_1iter first_first_divide_iter (
      .i_dividend (i_dividend),
      .i_divisor  (i_divisor),
      .i_remainder(32'b0),
      .i_quotient (32'b0),
      .o_dividend (dividend[0]),
      .o_remainder(remainder[0]),
      .o_quotient (quotient[0])
  );

  genvar k;
  for (k = 1; k < 4; k = k + 1) begin : gen_k_iters
    divu_1iter intermediate_first_divide_iters (
        .i_dividend (dividend[k-1]),
        .i_divisor  (i_divisor),
        .i_remainder(remainder[k-1]),
        .i_quotient (quotient[k-1]),
        .o_dividend (dividend[k]),
        .o_remainder(remainder[k]),
        .o_quotient (quotient[k])
    );
  end

  always_ff @(posedge clk) begin
    regs[0].dividend <= dividend[3];
    regs[0].divisor <= i_divisor;
    regs[0].remainder <= remainder[3];
    regs[0].quotient <= quotient[3];
  end

endmodule


module divu_1iter (
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    input  wire  [31:0] i_remainder,
    input  wire  [31:0] i_quotient,
    output logic [31:0] o_dividend,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

  assign o_dividend = i_dividend << 1;
  logic [31:0] remainder_int, o_quotient_logic, o_remainder_logic;
  assign remainder_int = i_dividend >> 31 & 32'b1 | i_remainder << 1;

  always_comb begin
    if (remainder_int < i_divisor) begin
      o_quotient_logic  = i_quotient << 1;
      o_remainder_logic = remainder_int;
    end else begin
      o_quotient_logic  = i_quotient << 1 | 32'b1;
      o_remainder_logic = remainder_int - i_divisor;
    end
  end

  assign o_quotient  = o_quotient_logic;
  assign o_remainder = o_remainder_logic;

endmodule
