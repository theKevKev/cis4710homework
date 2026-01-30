/* Authors: 
 * Kevin Han kevinhan
 * Gaurav Goel gg8
 */

`timescale 1ns / 1ns

// quotient = dividend / divisor

module DividerUnsigned (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);

  wire [31:0] dividend [32];
  wire [31:0] remainder[31];
  wire [31:0] quotient [31];

  DividerOneIter first_divide_iter (
      .i_dividend (i_dividend),
      .i_divisor  (i_divisor),
      .i_remainder(32'b0),
      .i_quotient (32'b0),
      .o_dividend (dividend[0]),
      .o_remainder(remainder[0]),
      .o_quotient (quotient[0])
  );

  genvar i;
  for (i = 1; i < 31; i = i + 1) begin
    DividerOneIter intermediate_divide_iters (
        .i_dividend (dividend[i-1]),
        .i_divisor  (i_divisor),
        .i_remainder(remainder[i-1]),
        .i_quotient (quotient[i-1]),
        .o_dividend (dividend[i]),
        .o_remainder(remainder[i]),
        .o_quotient (quotient[i])
    );
  end

  DividerOneIter final_divide_iter (
      .i_dividend (dividend[30]),
      .i_divisor  (i_divisor),
      .i_remainder(remainder[30]),
      .i_quotient (quotient[30]),
      .o_dividend (dividend[31]),
      .o_remainder(o_remainder),
      .o_quotient (o_quotient)
  );

endmodule


module DividerOneIter (
    input  wire [31:0] i_dividend,
    input  wire [31:0] i_divisor,
    input  wire [31:0] i_remainder,
    input  wire [31:0] i_quotient,
    output wire [31:0] o_dividend,
    output wire [31:0] o_remainder,
    output wire [31:0] o_quotient
);
  /*
    for (int i = 0; i < 32; i++) {
        remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
        if (remainder < divisor) {
            quotient = (quotient << 1);
        } else {
            quotient = (quotient << 1) | 0x1;
            remainder = remainder - divisor;
        }
        dividend = dividend << 1;
    }
    */

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
