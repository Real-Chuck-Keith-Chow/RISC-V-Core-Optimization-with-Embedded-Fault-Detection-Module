// ============================================================
// RISC-V RV32I Core — Global Defines
// ============================================================

`ifndef RV32I_DEFINES_VH
`define RV32I_DEFINES_VH

// -----------------------------------------------------------------------------
// Core-wide
// -----------------------------------------------------------------------------
`define XLEN               32
`define RESET_VECTOR       32'h0000_0000

// ADDI x0, x0, 0 (encoded NOP)
`define INSTR_NOP          32'h0000_0013

// -----------------------------------------------------------------------------
// Base opcodes (bits [6:0])
// -----------------------------------------------------------------------------
`define OPCODE_LOAD        7'b000_0011
`define OPCODE_STORE       7'b010_0011
`define OPCODE_ALUI        7'b001_0011    // I-type ALU
`define OPCODE_ALUR        7'b011_0011    // R-type ALU
`define OPCODE_LUI         7'b011_0111
`define OPCODE_AUIPC       7'b001_0111
`define OPCODE_BRANCH      7'b110_0011
`define OPCODE_JAL         7'b110_1111
`define OPCODE_JALR        7'b110_0111
`define OPCODE_MISC_MEM    7'b000_1111    // FENCE
`define OPCODE_SYSTEM      7'b111_0011    // ECALL/EBREAK/CSR (if used)

// -----------------------------------------------------------------------------
// Funct3 encodings (bits [14:12])
// -----------------------------------------------------------------------------

// Loads / Stores
`define F3_LB              3'b000
`define F3_LH              3'b001
`define F3_LW              3'b010
`define F3_LBU             3'b100
`define F3_LHU             3'b101

`define F3_SB              3'b000
`define F3_SH              3'b001
`define F3_SW              3'b010

// Branches
`define F3_BEQ             3'b000
`define F3_BNE             3'b001
`define F3_BLT             3'b100
`define F3_BGE             3'b101
`define F3_BLTU            3'b110
`define F3_BGEU            3'b111

// ALU (R/I-type)
`define F3_ADD_SUB         3'b000
`define F3_SLL             3'b001
`define F3_SLT             3'b010
`define F3_SLTU            3'b011
`define F3_XOR             3'b100
`define F3_SRL_SRA         3'b101
`define F3_OR              3'b110
`define F3_AND             3'b111

// JALR
`define F3_JALR            3'b000

// -----------------------------------------------------------------------------
// Funct7 cues (bit [30] is enough for ADD/SUB and SRL/SRA)
// -----------------------------------------------------------------------------
`define F7_SUB_SRA         1'b1   // instr[30] = 1 for SUB/SRA/SRAI
`define F7_ADD_SRL         1'b0   // instr[30] = 0 for ADD/SRL/SRLI

// -----------------------------------------------------------------------------
// ALU operation select (used by your control to drive the ALU)
// Encoding must match alu.v
// 0000 ADD, 0001 SUB, 0010 AND, 0011 OR,
// 0100 XOR, 0101 SLL, 0110 SRL, 0111 SRA,
// 1000 SLT, 1001 SLTU
// -----------------------------------------------------------------------------
`define ALU_ADD            4'b0000
`define ALU_SUB            4'b0001
`define ALU_AND            4'b0010
`define ALU_OR             4'b0011
`define ALU_XOR            4'b0100
`define ALU_SLL            4'b0101
`define ALU_SRL            4'b0110
`define ALU_SRA            4'b0111
`define ALU_SLT            4'b1000
`define ALU_SLTU           4'b1001

// -----------------------------------------------------------------------------
// Convenience: immediate type tags (optional for decode readability)
// -----------------------------------------------------------------------------
`define IMM_I              3'd0
`define IMM_S              3'd1
`define IMM_B              3'd2
`define IMM_U              3'd3
`define IMM_J              3'd4

`endif // RV32I_DEFINES_VH

