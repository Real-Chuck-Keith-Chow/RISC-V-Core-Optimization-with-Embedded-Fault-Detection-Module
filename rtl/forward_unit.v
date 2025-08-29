// ============================================================
// Forwarding Unit (RV32I, 5-stage)
// - Resolves RAW hazards by selecting newer results from
//   EX/MEM or MEM/WB instead of stalling.
// - Priority: EX/MEM over MEM/WB.
// - If EX/MEM is a LOAD, its data isn't ready yet → skip EX/MEM
//   forwarding and allow MEM/WB to forward instead.
//   (Load-use still needs a 1-cycle stall from hazard_unit.)
// ------------------------------------------------------------
// Outputs (2-bit selects):
//   00 = use register file value (rs*_ex)
//   01 = forward from EX/MEM stage (alu_y_mem)
//   10 = forward from MEM/WB stage (wb_data)
//   11 = reserved (unused)
// ============================================================
module forward_unit(
  // Source regs used in EX stage
  input  logic [4:0] rs1_ex,
  input  logic [4:0] rs2_ex,

  // Dest regs in later stages
  input  logic [4:0] rd_mem,          // EX/MEM destination
  input  logic [4:0] rd_wb,           // MEM/WB destination

  // Write enables
  input  logic       reg_write_mem,   // EX/MEM will write back
  input  logic       reg_write_wb,    // MEM/WB will write back

  // True if EX/MEM instruction is a LOAD (its data not ready yet)
  input  logic       mem_read_mem,

  // Forwarding selects for EX stage ALU inputs A and B
  output logic [1:0] fwd_a_sel,
  output logic [1:0] fwd_b_sel
);
  // Default: no forwarding
  always_comb begin
    fwd_a_sel = 2'b00;
    fwd_b_sel = 2'b00;

    // ---- Prioritize EX/MEM (if not a load) ----
    if (reg_write_mem && !mem_read_mem && (rd_mem != 5'd0)) begin
      if (rd_mem == rs1_ex) fwd_a_sel = 2'b01; // from EX/MEM
      if (rd_mem == rs2_ex) fwd_b_sel = 2'b01;
    end

    // ---- Then MEM/WB ----
    if (reg_write_wb && (rd_wb != 5'd0)) begin
      // Only set if not already fed by EX/MEM
      if ((fwd_a_sel == 2'b00) && (rd_wb == rs1_ex)) fwd_a_sel = 2'b10; // from MEM/WB
      if ((fwd_b_sel == 2'b00) && (rd_wb == rs2_ex)) fwd_b_sel = 2'b10;
    end
  end
endmodule

