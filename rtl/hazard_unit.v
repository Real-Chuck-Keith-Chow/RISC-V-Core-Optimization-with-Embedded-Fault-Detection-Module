// ============================================================
// Hazard Unit (RV32I, 5-stage)
// - Load-use hazard: stall IF+ID, bubble in EX
// - Control hazard (resolved in EX): flush IF/ID and ID/EX
// ============================================================
module hazard_unit(
  // ID stage sources
  input  logic [4:0] rs1_id,
  input  logic [4:0] rs2_id,

  // EX stage destination & type (is a load?)
  input  logic [4:0] rd_ex,
  input  logic       mem_read_ex,       // 1 if EX instruction is a LOAD

  // Control transfers resolved in EX
  input  logic       branch_taken_ex,   // (branch_ex && take_branch)
  input  logic       jal_ex,
  input  logic       jalr_ex,

  // Pipeline controls
  output logic       stall_if,          // hold PC
  output logic       stall_id,          // hold IF/ID
  output logic       flush_if_id,       // bubble IF/ID
  output logic       flush_id_ex        // bubble ID/EX
);

  // -------- Load-use RAW hazard (EX is LOAD, ID reads its rd) --------
  wire load_use_hazard = mem_read_ex &&
                         (rd_ex != 5'd0) &&
                         ((rd_ex == rs1_id) || (rd_ex == rs2_id));

  // -------- Control hazard (taken branch/JAL/JALR resolved in EX) ----
  wire ctrl_hazard = branch_taken_ex | jal_ex | jalr_ex;

  // -------- Outputs ---------------------------------------------------
  // Load-use: stall IF & ID; insert bubble into EX (flush ID/EX)
  assign stall_if   = load_use_hazard;
  assign stall_id   = load_use_hazard;
  assign flush_id_ex = load_use_hazard | ctrl_hazard;

  // Control hazard: flush the fetched/decoded instruction in IF/ID
  assign flush_if_id = ctrl_hazard;

endmodule
