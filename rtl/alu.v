// Simple RV32I ALU
`include "defines.vh"
module alu(
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic [3:0]  alu_sel,
  output logic [31:0] y,
  output logic        zero
);
  always_comb begin
    unique case (alu_sel)
      `ALU_ADD:  y = a + b;
      `ALU_SUB:  y = a - b;
      `ALU_AND:  y = a & b;
      `ALU_OR:   y = a | b;
      `ALU_XOR:  y = a ^ b;
      `ALU_SLL:  y = a << b[4:0];
      `ALU_SRL:  y = a >> b[4:0];
      `ALU_SRA:  y = $signed(a) >>> b[4:0];
      `ALU_SLT:  y = ($signed(a) <  $signed(b)) ? 32'd1 : 32'd0;
      `ALU_SLTU: y = (a < b) ? 32'd1 : 32'd0;
      default:   y = 32'd0;
    endcase
  end
  assign zero = (y == 32'd0);
endmodule

