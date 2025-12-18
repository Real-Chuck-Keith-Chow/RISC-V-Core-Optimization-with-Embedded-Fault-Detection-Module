`include "defines.vh"

module core(
    input  logic clk,
    input  logic rst
);
    // ============================
    // IF Stage (Instruction Fetch)
    // ============================
    logic [31:0] pc_q, next_pc, instr_if;
    logic        stall_if;
    logic        stall_id;
    logic        flush_if;
    logic        flush_id_ex;

    pc u_pc (
        .clk(clk),
        .rst(rst),
        .stall(stall_if),
        .next_pc(next_pc),
        .pc_q(pc_q)
    );

    instr_mem u_imem (
        .addr(pc_q),
        .rdata(instr_if)
    );

    // ============================
    // IF/ID Pipeline Register
    // ============================
    logic [31:0] pc_id, instr_id;

    if_id u_if_id (
        .clk(clk),
        .rst(rst),
        .stall(stall_id),
        .flush(flush_if),
        .pc_in(pc_q),
        .instr_in(instr_if),
        .pc_out(pc_id),
        .instr_out(instr_id)
    );

    // ============================
    // ID Stage (Decode + Regfile)
    // ============================
    // Decode fields
    wire [6:0] opcode  = instr_id[6:0];
    wire [2:0] funct3  = instr_id[14:12];
    wire       funct7_5= instr_id[30];
    wire [4:0] rs1_addr = instr_id[19:15];
    wire [4:0] rs2_addr = instr_id[24:20];
    wire [4:0] rd_addr  = instr_id[11:7];

    // Control
    logic reg_write_id, mem_read_id, mem_write_id, mem_to_reg_id;
    logic alu_src_imm_id, branch_id, jal_id, jalr_id;
    logic [3:0] alu_sel_id;

    control_unit u_ctl (
        .opcode(opcode),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .reg_write(reg_write_id),
        .mem_read(mem_read_id),
        .mem_write(mem_write_id),
        .mem_to_reg(mem_to_reg_id),
        .alu_src_imm(alu_src_imm_id),
        .branch(branch_id),
        .jal(jal_id),
        .jalr(jalr_id),
        .alu_sel(alu_sel_id)
    );

    // Register file
    logic [31:0] rs1_rdata, rs2_rdata, rd_wdata;

    reg_file u_rf (
        .clk(clk),
        .we(mem_wb_reg_write),
        .rd_addr(mem_wb_rd),
        .rd_wdata(rd_wdata),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_rdata(rs1_rdata),
        .rs2_rdata(rs2_rdata)
    );

    // Immediate generation
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    imm_gen u_imm (
        .instr(instr_id),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b),
        .imm_u(imm_u),
        .imm_j(imm_j)
    );

    // Pick the correct immediate type
    logic [31:0] imm_id;
    always_comb begin
        case(opcode)
            `OPCODE_STORE:   imm_id = imm_s;
            `OPCODE_BRANCH:  imm_id = imm_b;
            `OPCODE_LUI,
            `OPCODE_AUIPC:   imm_id = imm_u;
            `OPCODE_JAL:     imm_id = imm_j;
            default:         imm_id = imm_i;
        endcase
    end

    // ============================
    // ID/EX Pipeline Register
    // ============================
    logic [31:0] pc_ex, rs1_ex, rs2_ex, imm_ex;
    logic [4:0] rd_ex, rs1_addr_ex, rs2_addr_ex;
    logic [2:0] funct3_ex;
    logic funct7_5_ex;
    logic reg_write_ex, mem_read_ex, mem_write_ex, mem_to_reg_ex;
    logic alu_src_imm_ex, branch_ex, jal_ex, jalr_ex;
    logic [3:0] alu_sel_ex;

    id_ex u_id_ex (
        .clk(clk), .rst(rst), .stall(1'b0), .flush(flush_id_ex),
        .pc_i(pc_id),
        .rs1_i(rs1_rdata),
        .rs2_i(rs2_rdata),
        .imm_i(imm_id),
        .rd_i(rd_addr),
        .rs1_addr_i(rs1_addr),
        .rs2_addr_i(rs2_addr),
        .funct3_i(funct3),
        .funct7_5_i(funct7_5),
        .reg_write_i(reg_write_id),
        .mem_read_i(mem_read_id),
        .mem_write_i(mem_write_id),
        .mem_to_reg_i(mem_to_reg_id),
        .alu_src_imm_i(alu_src_imm_id),
        .branch_i(branch_id),
        .jal_i(jal_id),
        .jalr_i(jalr_id),
        .alu_sel_i(alu_sel_id),
        .pc_o(pc_ex),
        .rs1_o(rs1_ex),
        .rs2_o(rs2_ex),
        .imm_o(imm_ex),
        .rd_o(rd_ex),
        .rs1_addr_o(rs1_addr_ex),
        .rs2_addr_o(rs2_addr_ex),
        .funct3_o(funct3_ex),
        .funct7_5_o(funct7_5_ex),
        .reg_write_o(reg_write_ex),
        .mem_read_o(mem_read_ex),
        .mem_write_o(mem_write_ex),
        .mem_to_reg_o(mem_to_reg_ex),
        .alu_src_imm_o(alu_src_imm_ex),
        .branch_o(branch_ex),
        .jal_o(jal_ex),
        .jalr_o(jalr_ex),
        .alu_sel_o(alu_sel_ex)
    );

    // ============================
    // EX Stage
    // ============================
    logic [31:0] alu_a_ex, rs2_ex_fwd, alu_b_ex, alu_y_ex;
    logic alu_zero_ex;

    // Forwarding selections
    logic [1:0] fwd_a_sel, fwd_b_sel;

    // Forwarding muxes
    always_comb begin
        case (fwd_a_sel)
            2'b01: alu_a_ex = alu_y_mem;  // from EX/MEM
            2'b10: alu_a_ex = rd_wdata;   // from MEM/WB
            default: alu_a_ex = rs1_ex;
        endcase

        case (fwd_b_sel)
            2'b01: rs2_ex_fwd = alu_y_mem;
            2'b10: rs2_ex_fwd = rd_wdata;
            default: rs2_ex_fwd = rs2_ex;
        endcase
    end

    assign alu_b_ex = alu_src_imm_ex ? imm_ex : rs2_ex_fwd;

    alu u_alu (
        .a(alu_a_ex),
        .b(alu_b_ex),
        .alu_sel(alu_sel_ex),
        .y(alu_y_ex),
        .zero(alu_zero_ex)
    );

    // Branch decision
    logic take_branch;
    branch_unit u_br (
        .funct3(funct3_ex),
        .rs1(alu_a_ex),
        .rs2(rs2_ex_fwd),
        .take_branch(take_branch)
    );

    // Branch target computation
    wire [31:0] branch_target = pc_ex + imm_ex;
    wire [31:0] jal_target    = pc_ex + imm_ex;
    wire [31:0] jalr_target   = (rs1_ex + imm_ex) & ~32'd1;

    // ============================
    // EX/MEM Pipeline Register
    // ============================
    logic [31:0] alu_y_mem, rs2_mem;
    logic [4:0] rd_mem;
    logic reg_write_mem, mem_read_mem, mem_write_mem, mem_to_reg_mem;

    ex_mem u_ex_mem (
        .clk(clk), .rst(rst), .stall(1'b0), .flush(1'b0),
        .alu_y_i(alu_y_ex),
        .rs2_i(rs2_ex_fwd),
        .rd_i(rd_ex),
        .reg_write_i(reg_write_ex),
        .mem_read_i(mem_read_ex),
        .mem_write_i(mem_write_ex),
        .mem_to_reg_i(mem_to_reg_ex),
        .alu_y_o(alu_y_mem),
        .rs2_o(rs2_mem),
        .rd_o(rd_mem),
        .reg_write_o(reg_write_mem),
        .mem_read_o(mem_read_mem),
        .mem_write_o(mem_write_mem),
        .mem_to_reg_o(mem_to_reg_mem)
    );

    // ============================
    // MEM Stage
    // ============================
    logic [31:0] mem_rdata_mem;

    data_mem u_dmem (
        .clk(clk),
        .we(mem_write_mem),
        .wstrb(4'b1111), // simple: full word writes
        .addr(alu_y_mem),
        .wdata(rs2_mem),
        .rdata(mem_rdata_mem)
    );

    // ============================
    // MEM/WB Pipeline Register
    // ============================
    logic [31:0] mem_rdata_wb, alu_y_wb;
    logic [4:0]  mem_wb_rd;
    logic mem_wb_reg_write, mem_wb_mem_to_reg;

    mem_wb u_mem_wb (
        .clk(clk), .rst(rst), .stall(1'b0), .flush(1'b0),
        .mem_rdata_i(mem_rdata_mem),
        .alu_y_i(alu_y_mem),
        .rd_i(rd_mem),
        .reg_write_i(reg_write_mem),
        .mem_to_reg_i(mem_to_reg_mem),
        .mem_rdata_o(mem_rdata_wb),
        .alu_y_o(alu_y_wb),
        .rd_o(mem_wb_rd),
        .reg_write_o(mem_wb_reg_write),
        .mem_to_reg_o(mem_wb_mem_to_reg)
    );

    // ============================
    // WB Stage
    // ============================
    assign rd_wdata = mem_wb_mem_to_reg ? mem_rdata_wb : alu_y_wb;

    // ============================
    // Next PC Logic (Branch/Jump)
    // ============================
    assign next_pc =
        (branch_ex && take_branch) ? branch_target :
        jal_ex  ? jal_target :
        jalr_ex ? jalr_target :
        pc_q + 32'd4;

    // ============================
    // Hazard + Forwarding Control
    // ============================
    wire branch_taken_ex = branch_ex && take_branch;

    hazard_unit u_hazard (
        .rs1_id(rs1_addr),
        .rs2_id(rs2_addr),
        .rd_ex(rd_ex),
        .mem_read_ex(mem_read_ex),
        .branch_taken_ex(branch_taken_ex),
        .jal_ex(jal_ex),
        .jalr_ex(jalr_ex),
        .stall_if(stall_if),
        .stall_id(stall_id),
        .flush_if_id(flush_if),
        .flush_id_ex(flush_id_ex)
    );

    forward_unit u_forward (
        .rs1_ex(rs1_addr_ex),
        .rs2_ex(rs2_addr_ex),
        .rd_mem(rd_mem),
        .rd_wb(mem_wb_rd),
        .reg_write_mem(reg_write_mem),
        .reg_write_wb(mem_wb_reg_write),
        .mem_read_mem(mem_read_mem),
        .fwd_a_sel(fwd_a_sel),
        .fwd_b_sel(fwd_b_sel)
    );

endmodule
