`timescale 1ns/1ps
`include "defines.vh"

module tb_alu;
  // DUT I/O
  logic [31:0] a, b, y;
  logic [3:0]  sel;
  logic        z;

  // DUT
  alu dut(.a(a), .b(b), .alu_sel(sel), .y(y), .zero(z));

  // helper
  task check(input string name, input [31:0] exp_y, input bit exp_z=0);
    begin
      #1;
      if (y !== exp_y) begin
        $display("FAIL %s: got=0x%08x exp=0x%08x (a=0x%08x b=0x%08x sel=%0d)", name, y, exp_y, a, b, sel);
        $fatal(1);
      end
      if (z !== exp_z) begin
        $display("FAIL %s: zero flag wrong (got=%0d exp=%0d)", name, z, exp_z);
        $fatal(1);
      end
    end
  endtask

  initial begin
    $dumpfile("tb_alu.vcd"); $dumpvars(0, tb_alu);

    // --- ADD ---
    a = 32'd5; b = 32'd3; sel = `ALU_ADD;  check("ADD 5+3", 32'd8, 1'b0);
    a = 32'd1; b = -32'sd1;               check("ADD 1+(-1)", 32'd0, 1'b1);

    // --- SUB ---
    a = 32'd5; b = 32'd7; sel = `ALU_SUB;  check("SUB 5-7", 32'hFFFF_FFFE, 1'b0);
    a = 32'd9; b = 32'd9;                  check("SUB 9-9", 32'd0, 1'b1);

    // --- AND / OR / XOR ---
    a = 32'hF0F0_00FF; b = 32'h0F0F_FF00; sel = `ALU_AND; check("AND", 32'h0000_0000, 1'b1);
    sel = `ALU_OR;                         check("OR",  32'hFFFF_FFFF, 1'b0);
    sel = `ALU_XOR;                        check("XOR", 32'hFFFF_FFFF, 1'b0);

    // --- SLL / SRL / SRA ---
    a = 32'h0000_0001; b = 32'd8; sel = `ALU_SLL; check("SLL 1<<8", 32'h0000_0100, 1'b0);
    a = 32'h8000_0000; b = 32'd1; sel = `ALU_SRL; check("SRL 0x80000000>>1", 32'h4000_0000, 1'b0);
    a = 32'h8000_0000; b = 32'd1; sel = `ALU_SRA; check("SRA 0x80000000>>>1", 32'hC000_0000, 1'b0);

    // shift amount masked by [4:0]
    a = 32'h0000_0001; b = 32'd40; sel = `ALU_SLL; check("SLL shamt mask", 32'h0000_0001 << (40 & 5'h1F), 1'b0);

    // --- SLT (signed) ---
    a = -32'sd1; b = 32'sd1; sel = `ALU_SLT;  check("SLT -1<1", 32'd1, 1'b0);
    a =  32'sd5; b = -32'sd3;                 check("SLT 5<-3", 32'd0, 1'b1); // y==0 → zero=1

    // --- SLTU (unsigned) ---
    a = 32'hFFFF_FFFF; b = 32'd1; sel = `ALU_SLTU; check("SLTU FFFF_FFFF<1 (u)", 32'd0, 1'b1);
    a = 32'd1;          b = 32'hFFFF_FFFF;        check("SLTU 1<FFFF_FFFF (u)", 32'd1, 1'b0);

    // --- Zero flag sanity ---
    a = 32'h1234_5678; b = 32'hEDCB_A988; sel = `ALU_XOR; check("XOR zero?", 32'hFEDF_FFF0, 1'b0);
    a = 32'hCAFE_BABE; b = 32'hCAFE_BABE; sel = `ALU_XOR; check("XOR self=0", 32'h0000_0000, 1'b1);

    $display("tb_alu: PASS ✅");
    $finish;
  end
endmodule
