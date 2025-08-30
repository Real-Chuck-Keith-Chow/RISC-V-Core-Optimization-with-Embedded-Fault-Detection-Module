`timescale 1ns/1ps

module tb_core_sc;
  reg  clk = 0;
  reg  rst = 1;
  wire [31:0] dbg_x10;

  // 100 MHz clock
  always #5 clk = ~clk;

  // DUT
  core_sc dut (
    .clk(clk),
    .rst(rst),
    .dbg_x10(dbg_x10)
  );

  initial begin
    $dumpfile("tb_core_sc.vcd"); $dumpvars(0, tb_core_sc);

    // Reset
    repeat(5) @(posedge clk);
    rst = 0;

    // Run a little while
    repeat(80) @(posedge clk);

    // Check result from program: x10 should be 8
    $display("dbg_x10 = 0x%08x", dbg_x10);
    if (dbg_x10 !== 32'd8) begin
      $display("FAIL: expected x10==8");
      $fatal(1);
    end

    $display("tb_core_sc: PASS ");
    $finish;
  end
endmodule
