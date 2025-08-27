
// Branch decision unit (RV32I)
`include "defines.vh"
module branch_unit(
  input  logic [2:0]  funct3,      // branch type
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  output logic        take_branch
);
  always_comb begin
    unique case (funct3)
      `F3_BEQ:  take_branch = (rs1 == rs2);
      `F3_BNE:  take_branch = (rs1 != rs2);
      `F3_BLT:  take_branch = ($signed(rs1) <  $signed(rs2));
      `F3_BGE:  take_branch = ($signed(rs1) >= $signed(rs2));
      `F3_BLTU: take_branch = (rs1 < rs2);
      `F3_BGEU: take_branch = (rs1 >= rs2);
      default:  take_branch = 1'b0;
    endcase
  end
endmodule
