// ID/EX pipeline register
module id_ex(
  input  logic        clk,
  input  logic        rst,
  input  logic        stall,
  input  logic        flush,

  // From ID
  input  logic [31:0] pc_i,
  input  logic [31:0] rs1_i,
  input  logic [31:0] rs2_i,
  input  logic [31:0] imm_i,      // choose I/S/B/U/J in ID before feeding here
  input  logic [4:0]  rd_i,
  input  logic [4:0]  rs1_addr_i,
  input  logic [4:0]  rs2_addr_i,
  input  logic [2:0]  funct3_i,
  input  logic        funct7_5_i,

  // Control from ID
  input  logic        reg_write_i,
  input  logic        mem_read_i,
  input  logic        mem_write_i,
  input  logic        mem_to_reg_i,
  input  logic        alu_src_imm_i,
  input  logic        branch_i,
  input  logic        jal_i,
  input  logic        jalr_i,
  input  logic [3:0]  alu_sel_i,

  // To EX
  output logic [31:0] pc_o,
  output logic [31:0] rs1_o,
  output logic [31:0] rs2_o,
  output logic [31:0] imm_o,
  output logic [4:0]  rd_o,
  output logic [4:0]  rs1_addr_o,
  output logic [4:0]  rs2_addr_o,
  output logic [2:0]  funct3_o,
  output logic        funct7_5_o,

  // Control to EX
  output logic        reg_write_o,
  output logic        mem_read_o,
  output logic        mem_write_o,
  output logic        mem_to_reg_o,
  output logic        alu_src_imm_o,
  output logic        branch_o,
  output logic        jal_o,
  output logic        jalr_o,
  output logic [3:0]  alu_sel_o
);
  // Reset/flush → bubble; stall → hold previous
  always_ff @(posedge clk or posedge rst) begin
    if (rst || flush) begin
      pc_o <= '0; rs1_o <= '0; rs2_o <= '0; imm_o <= '0;
      rd_o <= '0; rs1_addr_o <= '0; rs2_addr_o <= '0;
      funct3_o <= '0; funct7_5_o <= 1'b0;
      reg_write_o <= 1'b0; mem_read_o <= 1'b0; mem_write_o <= 1'b0;
      mem_to_reg_o <= 1'b0; alu_src_imm_o <= 1'b0;
      branch_o <= 1'b0; jal_o <= 1'b0; jalr_o <= 1'b0;
      alu_sel_o <= 4'b0;
    end else if (!stall) begin
      pc_o <= pc_i; rs1_o <= rs1_i; rs2_o <= rs2_i; imm_o <= imm_i;
      rd_o <= rd_i; rs1_addr_o <= rs1_addr_i; rs2_addr_o <= rs2_addr_i;
      funct3_o <= funct3_i; funct7_5_o <= funct7_5_i;
      reg_write_o <= reg_write_i; mem_read_o <= mem_read_i; mem_write_o <= mem_write_i;
      mem_to_reg_o <= mem_to_reg_i; alu_src_imm_o <= alu_src_imm_i;
      branch_o <= branch_i; jal_o <= jal_i; jalr_o <= jalr_i;
      alu_sel_o <= alu_sel_i;
    end
  end
endmodule

