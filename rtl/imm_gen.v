// RV32I immediate extractor (I,S,B,U,J)
module imm_gen(
  input  logic [31:0] instr,
  output logic [31:0] imm_i,
  output logic [31:0] imm_s,
  output logic [31:0] imm_b,
  output logic [31:0] imm_u,
  output logic [31:0] imm_j
);
  assign imm_i = {{21{instr[31]}}, instr[30:20]};
  assign imm_s = {{21{instr[31]}}, instr[30:25], instr[11:7]};
  assign imm_b = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
  assign imm_u = {instr[31:12], 12'b0};
  assign imm_j = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
endmodule

