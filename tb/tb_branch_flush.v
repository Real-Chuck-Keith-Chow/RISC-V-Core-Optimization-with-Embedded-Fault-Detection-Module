`timescale 1ns/1ps

module tb_branch_flush;
  reg  clk = 0;
  reg  rst = 1;

  // 100 MHz
  always #5 clk = ~clk;

  // DUT (your pipelined core)
  core dut (.clk(clk), .rst(rst));

  // Peek x7 from the regfile (simulation-only)
  wire [31:0] x7 = dut.u_rf.regs[7];

  initial begin
    $dumpfile("tb_branch_flush.vcd"); $dumpvars(0, tb_branch_flush);

    // Backdoor program load into instruction memory
    // (uses the instance name "u_imem" in core.v)
    $readmemh("tb/prog_branch_flush.hex", dut.u_imem.mem);

    // Reset
    repeat (5) @(posedge clk);
    rst = 0;

    // Let it flow through pipe (init → branch → target)
    repeat (80) @(posedge clk);

    // Expect x7 == 34 (0x22) and definitely NOT 99 (poison)
    if (x7 !== 32'd34) begin
      $display("FAIL: expected x7 = 34 at branch target, got 0x%08x", x7);
      $fatal(1);
    end
    if (x7 === 32'd99) begin
      $display("FAIL: wrong-path instruction committed (flush missing)");
      $fatal(1);
    end

    $display("tb_branch_flush: PASS ✅");
    $finish;
  end
endmodule
