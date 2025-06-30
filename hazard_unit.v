// hazard_unit.v
// Basic hazard detection and forwarding unit for 5-stage RISC-V pipeline

module hazard_unit (
    input logic [4:0] rs1_id,          // Source reg 1 in ID stage
    input logic [4:0] rs2_id,          // Source reg 2 in ID stage
    input logic [4:0] rd_ex,           // Destination reg in EX stage
    input logic mem_read_ex,           // EX stage instruction is a load (needs MEM read)
    output logic stall                 // Stall signal for pipeline
);

    always_comb begin
        // Default no stall
        stall = 1'b0;

        // Load-use hazard detection:
        // If EX stage instruction is a load and ID stage needs EX destination register
        if (mem_read_ex && 
            ((rd_ex == rs1_id) || (rd_ex == rs2_id)) && (rd_ex != 0)) begin
            stall = 1'b1;
        end
    end

endmodule
