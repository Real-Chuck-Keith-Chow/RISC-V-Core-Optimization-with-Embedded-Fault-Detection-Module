`timescale 1ns/1ps

module tb_fault;
  reg clk=0, rst=1;
  always #5 clk = ~clk;  // 100 MHz

  reg  [11:0] v;         // mV
  wire fault;

  // DUT (override thresholds for easy testing)
  fault_detector #(.MIN_MV(950), .MAX_MV(1050)) dut (
    .clk(clk), .rst(rst), .voltage_mv(v), .fault_detected(fault)
  );

  task step; begin @(posedge clk); #1; end endtask

  initial begin
    $dumpfile("tb_fault.vcd"); $dumpvars(0, tb_fault);

    // Reset
    repeat(2) step; rst=0;

    // In-range → no fault
    v = 1000; step;
    if (fault !== 1'b0) begin $display("FAIL: in-range flagged"); $fatal(1); end

    // Low voltage → fault
    v = 900;  step;
    if (fault !== 1'b1) begin $display("FAIL: low voltage not flagged"); $fatal(1); end

    // Back to normal → clear (or stay latched if your design latches; adjust if needed)
    v = 1000; step;
    // If your design latches, change this check to expect 1.
    if (fault !== 1'b0) begin $display("FAIL: fault not cleared"); $fatal(1); end

    // High voltage → fault
    v = 1200; step;
    if (fault !== 1'b1) begin $display("FAIL: high voltage not flagged"); $fatal(1); end

    $display("tb_fault: PASS ✅");
    $finish;
  end
endmodule
