// IF/ID pipeline register
module if_id(
  input  logic        clk,
  input  logic        rst,
  input  logic        stall,      // hold current values
  input  logic        flush,      // insert bubble
  input  logic [31:0] pc_in,
  input  logic [31:0] instr_in,
  output logic [31:0] pc_out,
  output logic [31:0] instr_out
);
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      pc_out    <= 32'b0;
      instr_out <= 32'b0;
    end else if (flush) begin
      pc_out    <= 32'b0;
      instr_out <= 32'h00000013;  // NOP = ADDI x0,x0,0 (optional)
    end else if (!stall) begin
      pc_out    <= pc_in;
      instr_out <= instr_in;
    end
  end
endmodule

