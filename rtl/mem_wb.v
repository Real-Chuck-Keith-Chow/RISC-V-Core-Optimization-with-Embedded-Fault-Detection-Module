// MEM/WB pipeline register
module mem_wb(
  input  logic        clk,
  input  logic        rst,
  input  logic        stall,
  input  logic        flush,

  // From MEM stage
  input  logic [31:0] mem_rdata_i,
  input  logic [31:0] alu_y_i,
  input  logic [4:0]  rd_i,

  // Control from MEM
  input  logic        reg_write_i,
  input  logic        mem_to_reg_i,

  // To WB stage
  output logic [31:0] mem_rdata_o,
  output logic [31:0] alu_y_o,
  output logic [4:0]  rd_o,

  // Control to WB
  output logic        reg_write_o,
  output logic        mem_to_reg_o
);
  always_ff @(posedge clk or posedge rst) begin
    if (rst || flush) begin
      mem_rdata_o  <= 32'b0;
      alu_y_o      <= 32'b0;
      rd_o         <= 5'b0;
      reg_write_o  <= 1'b0;
      mem_to_reg_o <= 1'b0;
    end else if (!stall) begin
      mem_rdata_o  <= mem_rdata_i;
      alu_y_o      <= alu_y_i;
      rd_o         <= rd_i;
      reg_write_o  <= reg_write_i;
      mem_to_reg_o <= mem_to_reg_i;
    end
  end
endmodule

