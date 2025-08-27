// Program Counter with stall and async reset
module pc(
  input  logic        clk,
  input  logic        rst,
  input  logic        stall,
  input  logic [31:0] next_pc,
  output logic [31:0] pc_q
);
  always_ff @(posedge clk or posedge rst) begin
    if (rst)        pc_q <= 32'h0000_0000;
    else if (!stall) pc_q <= next_pc;
  end
endmodule
