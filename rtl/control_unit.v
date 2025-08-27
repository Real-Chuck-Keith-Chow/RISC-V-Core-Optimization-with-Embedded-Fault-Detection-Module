`include "defines.vh"

// RV32I control: opcode/funct3/funct7[5] -> control signals
module control_unit(
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic       funct7_5,      // instr[30]

    output logic       reg_write,
    output logic       mem_read,
    output logic       mem_write,
    output logic       mem_to_reg,
    output logic       alu_src_imm,
    output logic       branch,
    output logic       jal,
    output logic       jalr,
    output logic [3:0] alu_sel
);
    always_comb begin
        // defaults (NOP-safe)
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        alu_src_imm = 1'b0;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        alu_sel     = `ALU_ADD;

        unique case (opcode)
            `OPCODE_ALUR: begin
                reg_write = 1'b1;
                unique case (funct3)
                    `F3_ADD_SUB: alu_sel = (funct7_5) ? `ALU_SUB : `ALU_ADD;
                    `F3_AND:     alu_sel = `ALU_AND;
                    `F3_OR:      alu_sel = `ALU_OR;
                    `F3_XOR:     alu_sel = `ALU_XOR;
                    `F3_SLL:     alu_sel = `ALU_SLL;
                    `F3_SRL_SRA: alu_sel = (funct7_5) ? `ALU_SRA : `ALU_SRL;
                    `F3_SLT:     alu_sel = `ALU_SLT;
                    `F3_SLTU:    alu_sel = `ALU_SLTU;
                    default:     ;
                endcase
            end

            `OPCODE_ALUI: begin
                reg_write   = 1'b1;
                alu_src_imm = 1'b1;
                unique case (funct3)
                    `F3_ADD_SUB: alu_sel = `ALU_ADD;             // ADDI
                    `F3_AND:     alu_sel = `ALU_AND;             // ANDI
                    `F3_OR:      alu_sel = `ALU_OR;              // ORI
                    `F3_XOR:     alu_sel = `ALU_XOR;             // XORI
                    `F3_SLL:     alu_sel = `ALU_SLL;             // SLLI
                    `F3_SRL_SRA: alu_sel = (funct7_5)?`ALU_SRA:`ALU_SRL; // SRAI/SRLI
                    `F3_SLT:     alu_sel = `ALU_SLT;             // SLTI
                    `F3_SLTU:    alu_sel = `ALU_SLTU;            // SLTIU
                    default:     ;
                endcase
            end

            `OPCODE_LOAD: begin
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                mem_to_reg  = 1'b1;
                alu_src_imm = 1'b1;      // addr = rs1 + imm
                alu_sel     = `ALU_ADD;
            end

            `OPCODE_STORE: begin
                mem_write   = 1'b1;
                alu_src_imm = 1'b1;      // addr = rs1 + imm
                alu_sel     = `ALU_ADD;
            end

            `OPCODE_BRANCH: begin
                branch  = 1'b1;
                alu_sel = `ALU_SUB;      // compare via a-b
            end

            `OPCODE_JAL:   begin reg_write = 1'b1; jal  = 1'b1; end
            `OPCODE_JALR:  begin reg_write = 1'b1; jalr = 1'b1; alu_src_imm = 1'b1; end
            `OPCODE_LUI:   begin reg_write = 1'b1; end
            `OPCODE_AUIPC: begin reg_write = 1'b1; end
            default: ;
        endcase
    end
endmodule
