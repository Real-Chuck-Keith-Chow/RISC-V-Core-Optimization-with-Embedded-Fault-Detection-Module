`timescale 1ns/1ps

module tb_hazard_forward;
  reg  clk = 0;
  reg  rst = 1;

  // 100 MHz clock
  always #5 clk = ~clk;

  // DUT: pipelined core
  core dut (.clk(clk), .rst(rst));

  // Peek registers for checks (simulation-only)
  wire [31:0] x1 = dut.u_rf.regs[1];
  wire [31:0] x3 = dut.u_rf.regs[3];
  wire [31:0] x4 = dut.u_rf.regs[4];  // ALU→ALU chain result
  wire [31:0] x5 = dut.u_rf.regs[5];  // loaded value
  wire [31:0] x6 = dut.u_rf.regs[6];  // load-use dependent ADD result
  wire [31:0] x8 = dut.u_rf.regs[8];
  wire [31:0] x9 = dut.u_rf.regs[9];

  initial begin
    $dumpfile("tb_hazard_forward.vcd");
    $dumpvars(0, tb_hazard_forward);

    // Load the hazard program into the DUT's instruction memory
    // (hierarchical backdoor — no RTL change needed)
    $readmemh("tb/prog_hazard.hex", dut.u_imem.mem);

    // Reset a bit
    repeat (5) @(posedge clk);
    rst = 0;

    // Let the program flow through the 5-stage pipe
    // (there's an infinite BEQ loop at the end)
    repeat (120) @(posedge clk);

    // --- Checks ---
    // Program sets:
    // x1 = 5, x2 = 7,
    // x3 = x1 + x2 = 12
    // x4 = x3 + x1 = 17  (needs ALU→ALU forwarding; no stall expected)
    // Memory[0] = 0x11 via SW, then LW x5,0(x8)
    // x6 = x5 + x1 = 0x11 + 5 = 22  (load-use: requires 1-cycle bubble)

    if (x4 !== 32'd17) begin
      $display("FAIL: forwarding: expected x4=17, got 0x%08x", x4);
      $fatal(1);
    end

    if (x5 !== 32'h0000_0011) begin
      $display("FAIL: load: expected x5=0x11 from LW, got 0x%08x", x5);
      $fatal(1);
    end

    if (x6 !== 32'd22) begin
      $display("FAIL: load-use: expected x6=22 (x5+x1), got 0x%08x", x6);
      $fatal(1);
    end

    $display("tb_hazard_forward: PASS ✅");
    $finish;
  end
endmodule
