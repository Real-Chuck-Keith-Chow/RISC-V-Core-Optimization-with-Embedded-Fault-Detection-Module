`timescale 1ns/1ps
`include "defines.vh"

module tb_branch;
  // DUT I/O
  logic [2:0]  funct3;
  logic [31:0] rs1, rs2;
  logic        take;

  branch_unit dut(
    .funct3(funct3),
    .rs1(rs1),
    .rs2(rs2),
    .take_branch(take)
  );

  task automatic check(string name, bit exp);
    #1;
    if (take !== exp) begin
      $display("FAIL %s: got take=%0d exp=%0d (funct3=%0d rs1=0x%08x rs2=0x%08x)",
               name, take, exp, funct3, rs1, rs2);
      $fatal(1);
    end
  endtask

  initial begin
    $dumpfile("tb_branch.vcd"); $dumpvars(0, tb_branch);

    // --- BEQ ---
    funct3=`F3_BEQ; rs1=32'd5; rs2=32'd5;  check("BEQ equal", 1);
    rs1=32'd5; rs2=32'd6;                  check("BEQ not equal", 0);

    // --- BNE ---
    funct3=`F3_BNE; rs1=32'd5; rs2=32'd5;  check("BNE equal", 0);
    rs1=32'd5; rs2=32'd6;                  check("BNE not equal", 1);

    // --- BLT (signed) ---
    funct3=`F3_BLT; rs1=-32'sd1; rs2=32'sd1; check("BLT -1 < 1 (signed)", 1);
    rs1=32'sd2; rs2=-32'sd3;                 check("BLT 2 < -3 (signed)", 0);

    // --- BGE (signed) ---
    funct3=`F3_BGE; rs1=-32'sd1; rs2=32'sd0; check("BGE -1 >= 0 (signed)", 0);
    rs1=32'sd5;  rs2=32'sd5;                  check("BGE 5 >= 5 (signed)", 1);
    rs1=32'sd0;  rs2=-32'sd1;                 check("BGE 0 >= -1 (signed)", 1);

    // --- BLTU (unsigned) ---
    funct3=`F3_BLTU; rs1=32'hFFFF_FFFF; rs2=32'd1; check("BLTU FFFF_FFFF < 1 (u)", 0);
    rs1=32'd1; rs2=32'hFFFF_FFFF;                 check("BLTU 1 < FFFF_FFFF (u)", 1);
    rs1=32'd0; rs2=32'd0;                         check("BLTU 0 < 0 (u)", 0);

    // --- BGEU (unsigned) ---
    funct3=`F3_BGEU; rs1=32'hFFFF_FFFF; rs2=32'd1; check("BGEU FFFF_FFFF >= 1 (u)", 1);
    rs1=32'd0; rs2=32'd1;                          check("BGEU 0 >= 1 (u)", 0);
    rs1=32'd7; rs2=32'd7;                          check("BGEU 7 >= 7 (u)", 1);

    $display("tb_branch: PASS ✅");
    $finish;
  end
endmodule
