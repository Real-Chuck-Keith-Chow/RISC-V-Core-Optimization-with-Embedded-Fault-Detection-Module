// core.v
// Simplified 5-stage pipelined RISC-V core with fault detection hook

module core (
    input logic clk,
    input logic reset_n,
    input logic fault_detected,        // Fault detection signal input
    output logic halted                // Indicates core halted due to fault
);

    // -----------------------
    // Registers and pipeline stages
    // -----------------------
    logic [31:0] pc;                  // Program counter
    logic [31:0] instr;               // Current instruction
    logic [31:0] regfile[0:31];       // Register file
    logic [31:0] alu_result;
    logic [31:0] mem_data;

    // Pipeline stage control signals
    logic stall, flush;
    logic [31:0] if_id_instr, if_id_pc;
    logic [31:0] id_ex_instr, id_ex_pc;
    logic [31:0] ex_mem_result;
    logic [31:0] mem_wb_result;

    // Core state
    logic core_halted;

    // -----------------------
    // IF Stage
    // -----------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pc <= 32'h00000000;
        end else if (!stall && !core_halted) begin
            pc <= pc + 4;  // Simple next PC logic
        end
    end

    // Example instruction fetch (stub)
    always_comb begin
        instr = 32'h00000013; // NOP (ADDI x0, x0, 0) for simulation placeholder
    end

    // Pipeline IF/ID register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n || flush) begin
            if_id_instr <= 32'h00000013;
            if_id_pc <= 32'b0;
        end else if (!stall) begin
            if_id_instr <= instr;
            if_id_pc <= pc;
        end
    end

    // -----------------------
    // ID Stage (Stub)
    // -----------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            id_ex_instr <= 32'h00000013;
            id_ex_pc <= 32'b0;
        end else if (!stall) begin
            id_ex_instr <= if_id_instr;
            id_ex_pc <= if_id_pc;
        end
    end

    // -----------------------
    // EX Stage (Stub ALU)
    // -----------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ex_mem_result <= 32'b0;
        end else if (!stall) begin
            alu_result = id_ex_pc + 4;  // Dummy ALU operation
            ex_mem_result <= alu_result;
        end
    end

    // -----------------------
    // MEM Stage (Stub)
    // -----------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            mem_wb_result <= 32'b0;
        end else if (!stall) begin
            mem_data = ex_mem_result;  // Stub: no real memory access
            mem_wb_result <= mem_data;
        end
    end

    // -----------------------
    // WB Stage
    // -----------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            regfile[1] <= 32'b0;
        end else if (!stall) begin
            regfile[1] <= mem_wb_result; // Writeback to x1 (example)
        end
    end

    // -----------------------
    // Fault detection handling
    // -----------------------
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            core_halted <= 1'b0;
        end else if (fault_detected) begin
            core_halted <= 1'b1;  // Halt core when fault signal asserted
        end
    end

    assign halted = core_halted;

endmodule
