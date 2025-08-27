
// Byte-addressable data memory with byte write strobes
module data_mem #(
  parameter BYTES = 4096
)(
  input  logic        clk,
  input  logic        we,
  input  logic [3:0]  wstrb,       // byte enables
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata
);
  logic [7:0] mem [0:BYTES-1];

  // writes
  always_ff @(posedge clk) begin
    if (we) begin
      if (wstrb[0]) mem[addr + 0] <= wdata[7:0];
      if (wstrb[1]) mem[addr + 1] <= wdata[15:8];
      if (wstrb[2]) mem[addr + 2] <= wdata[23:16];
      if (wstrb[3]) mem[addr + 3] <= wdata[31:24];
    end
  end

  // reads (combinational)
  assign rdata = { mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0] };
endmodule
