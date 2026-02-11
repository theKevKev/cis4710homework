`timescale 1ns / 1ps

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits internally would generate a carry-out (independent of cin)
 * @param pout whether these 4 bits internally would propagate an incoming carry from cin
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);

   assign cout[0] = gin[0] | (pin[0] & cin);
   assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0]) | (pin[2] & pin[1] & pin[0] & cin);

   assign gout = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1]) | (pin[3] & pin[2] & pin[1] & gin[0]);
   assign pout = (pin[3] & pin[2] & pin[1] & pin[0]);

endmodule

/** Same as gp4 but for an 8-bit window instead */
module gp8(input wire [7:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [6:0] cout);

   assign cout[0] = gin[0] | (pin[0] & cin);
   assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
   assign cout[2] = gin[2] | (pin[2] & gin[1]) | (pin[2] & pin[1] & gin[0]) | (pin[2] & pin[1] & pin[0] & cin);
   assign cout[3] = gin[3] | (pin[3] & gin[2]) | (pin[3] & pin[2] & gin[1]) | (pin[3] & pin[2] & pin[1] & gin[0]) | (pin[3] & pin[2] & pin[1] & pin[0] & cin);
   assign cout[4] = gin[4] | (pin[4] & gin[3]) | (pin[4] & pin[3] & gin[2]) | (pin[4] & pin[3] & pin[2] & gin[1]) | (pin[4] & pin[3] & pin[2] & pin[1] & gin[0]) | (pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
   assign cout[5] = gin[5] | (pin[5] & gin[4]) | (pin[5] & pin[4] & gin[3]) | (pin[5] & pin[4] & pin[3] & gin[2]) | (pin[5] & pin[4] & pin[3] & pin[2] & gin[1]) | (pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0]) | (pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);
   assign cout[6] = gin[6] | (pin[6] & gin[5]) | (pin[6] & pin[5] & gin[4]) | (pin[6] & pin[5] & pin[4] & gin[3]) | (pin[6] & pin[5] & pin[4] & pin[3] & gin[2]) | (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & gin[1]) | (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0]) | (pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0] & cin);

   assign gout = gin[7] | (pin[7] & gin[6]) | (pin[7] & pin[6] & gin[5]) | (pin[7] & pin[6] & pin[5] & gin[4]) | (pin[7] & pin[6] & pin[5] & pin[4] & gin[3]) | (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & gin[2]) | (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & gin[1]) | (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & gin[0]);
   assign pout = (pin[7] & pin[6] & pin[5] & pin[4] & pin[3] & pin[2] & pin[1] & pin[0]);

endmodule

module CarryLookaheadAdder
  (input wire [31:0]  a, b,
   input wire         cin,
   output wire [31:0] sum);

   wire [31:0] cout;
   wire [31:0] g1, p1;
   wire [8:0] g2, p2;
   wire gout, pout;

   genvar i;
   generate
   for (i = 0; i < 32; i = i+1) begin
      gp1 first(
         .a(a[i]),
         .b(b[i]),
         .g(g1[i]),
         .p(p1[i])
      );
   end
   endgenerate

   gp4 top(
      .gin(g1[3:0]),
      .pin(p1[3:0]),
      .cin(cin),
      .gout(g2[0]),
      .pout(p2[0]),
      .cout(cout[2:0])
   );

   generate
      for (i = 1; i < 8; i = i+1) begin
         gp4 bottoms(
            .gin(g1[(4*i+3):(4*i)]),
            .pin(p1[(4*i+3):(4*i)]),
            .cin(cout[4*i-1]),
            .gout(g2[i]),
            .pout(p2[i]),
            .cout(cout[(4*i+2):(4*i)])
         );
      end
   endgenerate

   gp8 last(
      .gin(g2[7:0]),
      .pin(p2[7:0]),
      .cin(cin),
      .gout(gout),
      .pout(pout),
      .cout({cout[27], cout[23], cout[19], cout[15], cout[11], cout[7], cout[3]})
   );

   assign cout[31] = gout | (pout & cin);

   assign sum[0] = (a[0] ^ b[0]) ^ cin;

   generate
      for (i = 1; i < 32; i = i+1) begin
         assign sum[i] = (a[i] ^ b[i]) ^ cout[i-1];
      end
   endgenerate

endmodule
