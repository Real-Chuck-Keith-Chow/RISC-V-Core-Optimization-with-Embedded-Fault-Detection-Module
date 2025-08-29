`timescale 1ns/1ps

module tb_reg_file;
  // clk/reset
  reg clk = 0;
  always #5 clk = ~clk; // 100 MHz

  // DUT I/O
  reg         we;
  reg  [4:0]  rd_addr, rs1_addr, rs2_addr;
  reg  [31:0] rd_wdata;
  wire [31:0] rs1_rdata, rs2_rdata;

  // Instantiate DUT
  reg_file dut (
    .clk(clk),
    .we(we),
    .rd_addr(rd_addr),
    .rd_wdata(rd_wdata),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rs1_rdata(rs1_rdata),
    .rs2_rdata(rs2_rdata)
  );

  // helpers
  task write_reg(input [4:0] r, input [31:0] v);
    begin
      we = 1; rd_addr = r; rd_wdata = v;
      @(posedge clk);
      we = 0;
      @(negedge clk);
    end
  endtask

  task read_expect(input [4:0] a1, input [31:0] e1,
                   input [4:0] a2, input [31:0] e2, input string msg);
    begin
      rs1_addr = a1; rs2_addr = a2; #1; // async read
      if (rs1_rdata !== e1) begin
        $display("FAIL [%s] rs1 addr=%0d got=0x%08x exp=0x%08x", msg, a1, rs1_rdata, e1);
        $fatal(1);
      end
      if (rs2_rdata !== e2) begin
        $display("FAIL [%s] rs2 addr=%0d got=0x%08x exp=0x%08x", msg, a2, rs2_rdata, e2);
        $fatal(1);
      end
    end
  endtask

  integer i;

  initial begin
    $dumpfile("tb_reg_file.vcd"); $dumpvars(0, tb_reg_file);

    // defaults
    we = 0; rd_addr = 0; rd_wdata = 32'h0;
    rs1_addr = 0; rs2_addr = 0;

    // 1) x0 must always read as 0
    read_expect(5'd0, 32'h0, 5'd0, 32'h0, "x0 reset");

    // 2) Write x1, x2 and read back
    write_reg(5'd1, 32'h0000_00AA);
    write_reg(5'd2, 32'h0000_00BB);
    read_expect(5'd1, 32'h0000_00AA, 5'd2, 32'h0000_00BB, "basic r/w");

    // 3) Attempt to write x0; it must remain zero
    write_reg(5'd0, 32'hFFFF_FFFF);
    read_expect(5'd0, 32'h0000_0000, 5'd1, 32'h0000_00AA, "x0 hardwired zero");

    // 4) Back-to-back writes and reads
    write_reg(5'd3, 32'h1234_5678);
    write_reg(5'd4, 32'hDEAD_BEEF);
    read_expect(5'd3, 32'h1234_5678, 5'd4, 32'hDEAD_BEEF, "burst write/read");

    /
