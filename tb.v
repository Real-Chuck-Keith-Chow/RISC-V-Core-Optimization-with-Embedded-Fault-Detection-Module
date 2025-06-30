// tb.v
// Testbench for core + fault_detector

`timescale 1ns / 1ps

module tb;

    // Clock and reset
    logic clk;
    logic reset_n;

    // Voltage input to fault detector
    logic [11:0] voltage_in;

    // Signals between modules
    logic fault_detected_signal;
    logic halted;

    // Clock generation (10ns period = 100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset logic
    initial begin
        reset_n = 0;
        #20;         // Hold reset low for 20ns
        reset_n = 1; // Release reset
    end

    // Voltage stimulus
    initial begin
        // Default safe voltage
        voltage_in = 12'd2000;

        // Wait after reset
        #50;

        // Normal operation
        $display("Normal voltage, no fault expected.");
        #100;

        // Out-of-range voltage to trigger fault
        voltage_in = 12'd500; // Below V_MIN
        $display("Voltage too low! Fault should trigger now.");
        #100;

        // Restore normal
        voltage_in = 12'd2500;
        $display("Voltage back to normal.");
        #100;

        // Out-of-range high
        voltage_in = 12'd3500; // Above V_MAX
        $display("Voltage too high! Fault should trigger now.");
        #100;

        // Finish simulation
        $display("Testbench finished.");
        $stop;
    end

    // Instantiate fault detector
    fault_detector fd_inst (
        .clk(clk),
        .reset_n(reset_n),
        .voltage_in(voltage_in),
        .fault_detected(fault_detected_signal)
    );

    // Instantiate core
    core core_inst (
        .clk(clk),
        .reset_n(reset_n),
        .fault_detected(fault_detected_signal),
        .halted(halted)
    );

endmodule
