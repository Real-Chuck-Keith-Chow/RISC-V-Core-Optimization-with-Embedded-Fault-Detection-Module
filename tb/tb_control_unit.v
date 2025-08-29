`timescale 1ns/1ps
`include "defines.vh"

module tb_control_unit;
  // DUT I/O
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic       funct7_5;

  logic       reg_write, mem_read, mem_write, mem_to_reg, alu_src_imm, branch, jal, jalr;
  logic [3:0] alu_sel;

  control_unit dut(
    .opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
    .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
    .mem_to_reg(mem_to_reg), .alu_src_imm(alu_src_imm),
    .branch(branch), .jal(jal), .jalr(jalr), .alu_sel(alu_sel)
  );

  task automatic expect(
    input string name,
    input bit e_reg_write, e_mem_read, e_mem_write, e_mem_to_reg, e_alu_src_imm, e_branch, e_jal, e_jalr,
    input [3:0] e_alu_sel
  );
    #1;
    if (reg_write   !== e_reg_write  ||
        mem_read    !== e_mem_read   ||
        mem_write   !== e_mem_write  ||
        mem_to_reg  !== e_mem_to_reg ||
        alu_src_imm !== e_alu_src_imm||
        branch      !== e_branch     ||
        jal         !== e_jal        ||
        jalr        !== e_jalr       ||
        alu_sel     !== e_alu_sel) begin
      $display("FAIL %s\n got: wr=%0d mr=%0d mw=%0d m2r=%0d asimm=%0d br=%0d jal=%0d jalr=%0d alu=%0d",
        name, reg_write, mem_read, mem_write, mem_to_reg, alu_src_imm, branch, jal, jalr, alu_sel);
      $display("exp: wr=%0d mr=%0d mw=%0d m2r=%0d asimm=%0d br=%0d jal=%0d jalr=%0d alu=%0d",
        e_reg_write, e_mem_read, e_mem_write, e_mem_to_reg, e_alu_src_imm, e_branch, e_jal, e_jalr, e_alu_sel);
      $fatal(1);
    end
  endtask

  initial begin
    $dumpfile("tb_control_unit.vcd"); $dumpvars(0, tb_control_unit);

    // ---------------- R-type: ADD ----------------
    opcode=`OPCODE_ALUR; funct3=`F3_ADD_SUB; funct7_5=1'b0;
    expect("R-ADD", 1,0,0,0,0,0,0,0, `ALU_ADD);

    // ---------------- R-type: SUB ----------------
    funct7_5=1'b1;
    expect("R-SUB", 1,0,0,0,0,0,0,0, `ALU_SUB);

    // ---------------- R-type: AND ----------------
    funct3=`F3_AND; funct7_5=1'b0;
    ex
