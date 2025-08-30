`timescale 1ns/1ps

module tb_pipeline_smoke;
  reg  clk = 0;
  reg  rst = 1;

  // 100 MHz
  always #5 clk = ~clk;

  // DUT (pipelined core)
  core dut (
    .clk(clk),
    .rst(rst)
  );

  // For smoke testing, peek x10 via hierarchical reference to regfile.
  // (OK for simulation only.)
  wire [31:0] x10 = dut.u_rf.regs[10];

  initial begin
    $dumpfile("tb_pipeline_smoke.vcd"); $dumpvars(0, tb_pipeline_smoke);

    // Reset a few cycles
    repeat (5) @(posedge clk);
    rst = 0;

    // Let the program flow through the 5-stage pipeline
    // (ADDI, ADDI, ADD, then BEQ loop)
    repeat (80) @(posedge clk);

    $display("x10 = 0x%08x", x10);
    if (x10 !== 32'd8) begin
      $display("FAIL: expected x10 == 8");
      $fatal(1);
    end

    $display("tb_pipeline_smoke: PASS ✅");
    $finish;
  end
endmodule
