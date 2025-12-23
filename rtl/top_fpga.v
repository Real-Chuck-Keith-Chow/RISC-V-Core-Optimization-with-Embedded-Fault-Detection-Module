module top_fpga #(
    parameter logic [11:0] FAULT_MIN_MV = 12'd1000,
    parameter logic [11:0] FAULT_MAX_MV = 12'd3000,
    parameter string       IMEM_HEX     = "tb/prog_simple.hex"
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [11:0] voltage_mv,
    output logic        fault_detected,
    output logic        core_halt
);

    core #(
        .FAULT_MIN_MV(FAULT_MIN_MV),
        .FAULT_MAX_MV(FAULT_MAX_MV),
        .IMEM_HEX(IMEM_HEX)
    ) u_core (
        .clk(clk),
        .rst(rst),
        .voltage_mv(voltage_mv),
        .fault_detected(fault_detected),
        .core_halt(core_halt)
    );
endmodule
