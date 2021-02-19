`timescale 1ns / 1ps

module fp_add
   (
    input             clk,
    input             rst,

    input             start,
    output reg        done,

    input [31:0]      op_a,
    input [31:0]      op_b,

    output            overflow,
    output            underflow,
    output            exception,

    output reg [31:0] res
    );

   // Unpack
   wire               comp = (op_a[30:23] >= op_b[30:23])? 1'b1 : 1'b0;

   wire [23:0]        A_Mantissa = comp? {1'b1, op_a[22:0]} : {1'b1, op_b[22:0]};
   wire [7:0]         A_Exponent = comp? op_a[30:23] : op_b[30:23];
   wire               A_sign = comp? op_a[31] : op_b[31];

   wire [23:0]        B_Mantissa = comp? {1'b1, op_b[22:0]} : {1'b1, op_a[22:0]};
   wire [7:0]         B_Exponent = comp? op_b[30:23] : op_a[30:23];
   wire               B_sign = comp? op_b[31] : op_a[31];

   // Align significants
   wire [7:0]         diff_Exponent = A_Exponent - B_Exponent;
   wire [23:0]        B_Mantissa_in = B_Mantissa >> diff_Exponent;

   // pipeline stage 1
   reg                A_sign_reg;
   reg [7:0]          A_Exponent_reg;
   reg [23:0]         A_Mantissa_reg;

   reg                B_sign_reg;
   reg [23:0]         B_Mantissa_reg;

   reg                done_int;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg <= 1'b0;
         A_Exponent_reg <= 8'd0;
         A_Mantissa_reg <= 24'd0;

         B_sign_reg <= 1'b0;
         B_Mantissa_reg <= 24'd0;

         done_int <= 1'b0;
      end else begin
         A_sign_reg <= A_sign;
         A_Exponent_reg <= A_Exponent;
         A_Mantissa_reg <= A_Mantissa;

         B_sign_reg <= B_sign;
         B_Mantissa_reg <= B_Mantissa_in;

         done_int <= start;
      end
   end

   // Addition
   wire [24:0]        Temp = (A_sign_reg ~^ B_sign_reg)? A_Mantissa_reg + B_Mantissa_reg:
                                                         A_Mantissa_reg - B_Mantissa_reg;
   wire               carry = Temp[24];

   // pipeline stage 2
   reg                A_sign_reg2;
   reg [7:0]          A_Exponent_reg2;

   reg [23:0]         Temp_reg;
   reg                carry_reg;

   reg                done_int2;
   always @(posedge clk) begin
      if (rst) begin
         A_sign_reg2 <= 1'b0;
         A_Exponent_reg2 <= 8'd0;

         Temp_reg <= 24'd0;
         carry_reg <= 1'b0;

         done_int2 <= 1'b0;
      end else begin
         A_sign_reg2 <= A_sign_reg;
         A_Exponent_reg2 <= A_Exponent_reg;

         Temp_reg <= Temp[23:0];
         carry_reg <= carry;

         done_int2 <= done_int;
      end
   end

   // Normalize
   wire [4:0] lzc;
   clz #(
         .DATA_W(24)
         )
   clz0
     (
      .data_in  (Temp_reg),
      .data_out (lzc)
      );

   wire [23:0]        Temp_Mantissa = carry_reg? Temp_reg[23:1] : Temp_reg << lzc;
   wire [7:0]         exp_adjust = carry_reg? A_Exponent_reg2 + 1'b1 : A_Exponent_reg2 - lzc;

   // Pack
   wire               Sign = A_sign_reg2;
   wire [22:0]        Mantissa = Temp_Mantissa[22:0];
   wire [7:0]         Exponent = exp_adjust;

   // pipeline stage 3
   always @(posedge clk) begin
      if (rst) begin
         res <= 32'd0;
         done <= 1'b0;
      end else begin
         res <= {Sign, Exponent, Mantissa};
         done <= done_int2;
      end
   end

   // Not implemented yet!
   assign overflow = 1'b0;
   assign underflow = 1'b0;
   assign exception = 1'b0;

endmodule
