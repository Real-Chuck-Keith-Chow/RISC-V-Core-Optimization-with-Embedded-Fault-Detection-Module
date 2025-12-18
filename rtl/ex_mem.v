// EX/MEM pipeline register
// - Holds ALU result and control signals between EX and MEM stages.
// - rst/flush insert a bubble; stall holds the current contents.
module ex_mem(
  input  logic        clk,
  input  logic        rst,
  input  logic        stall,
  input  logic        flush,

  // From EX stage
  input  logic [31:0] alu_y_i,
  input  logic [31:0] rs2_i,
  input  logic [4:0]  rd_i,

  // Control from EX
  input  logic        reg_write_i,
  input  logic        mem_read_i,
  input  logic        mem_write_i,
  input  logic        mem_to_reg_i,

  // To MEM stage
  output logic [31:0] alu_y_o,
  output logic [31:0] rs2_o,
  output logic [4:0]  rd_o,

  // Control to MEM
  output logic        reg_write_o,
  output logic        mem_read_o,
  output logic        mem_write_o,
  output logic        mem_to_reg_o
);
  always_ff @(posedge clk or posedge rst) begin
    if (rst || flush) begin
      alu_y_o      <= 32'b0;
      rs2_o        <= 32'b0;
      rd_o         <= 5'b0;
      reg_write_o  <= 1'b0;
      mem_read_o   <= 1'b0;
      mem_write_o  <= 1'b0;
      mem_to_reg_o <= 1'b0;
    end else if (!stall) begin
      alu_y_o      <= alu_y_i;
      rs2_o        <= rs2_i;
      rd_o         <= rd_i;
      reg_write_o  <= reg_write_i;
      mem_read_o   <= mem_read_i;
      mem_write_o  <= mem_write_i;
      mem_to_reg_o <= mem_to_reg_i;
    end
  end
endmodule

