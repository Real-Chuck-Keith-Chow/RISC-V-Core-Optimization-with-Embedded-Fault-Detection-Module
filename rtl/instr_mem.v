// Simple instruction memory (ROM) backed by a HEX file
module instr_mem #(
  parameter DEPTH   = 1024,                 // words
  parameter HEXFILE = "tb/prog_simple.hex"
)(
  input  logic [31:0] addr,                 // byte address
  output logic [31:0] rdata
);
  logic [31:0] mem [0:DEPTH-1];

  initial begin
    $display("Loading instruction memory: %s", HEXFILE);
    $readmemh(HEXFILE, mem);
  end

  // word-aligned read
  assign rdata = mem[addr[31:2]];
endmodule

