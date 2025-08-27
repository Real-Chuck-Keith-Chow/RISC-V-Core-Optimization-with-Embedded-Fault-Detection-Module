
// ------------------------------------------------------------
// 32 x 32 Register File (RV32I)
// - Two async read ports, one sync write port
// - x0 is hard-wired to 0 (writes to x0 are ignored)
// ------------------------------------------------------------
`include "defines.vh"

module reg_file #(
    parameter XLEN     = `XLEN,
    parameter NUM_REGS = 32
) (
    input  logic              clk,
    input  logic              we,          // write enable
    input  logic [4:0]        rd_addr,     // destination register
    input  logic [XLEN-1:0]   rd_wdata,    // write data
    input  logic [4:0]        rs1_addr,    // read port 1 address
    input  logic [4:0]        rs2_addr,    // read port 2 address
    output logic [XLEN-1:0]   rs1_rdata,   // read port 1 data
    output logic [XLEN-1:0]   rs2_rdata    // read port 2 data
);

    // storage
    logic [XLEN-1:0] regs [NUM_REGS-1:0];

    // async reads; x0 always returns 0
    assign rs1_rdata = (rs1_addr == 5'd0) ? '0 : regs[rs1_addr];
    assign rs2_rdata = (rs2_addr == 5'd0) ? '0 : regs[rs2_addr];

    // sync write on rising edge; ignore writes to x0
    always_ff @(posedge clk) begin
        if (we && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_wdata;
        end
    end

`ifdef FORMAL
    // Optional sanity: x0 must always be zero
    always @(posedge clk) assume(regs[0] == '0);
`endif

endmodule
