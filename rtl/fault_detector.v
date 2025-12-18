// fault_detector.v
// Simple voltage anomaly fault detector module

module fault_detector #(
    parameter logic [11:0] MIN_MV = 12'd1000, // 1.0 V
    parameter logic [11:0] MAX_MV = 12'd3000  // 3.0 V
)(
    input  logic        clk,
    input  logic        rst,          // active-high synchronous reset
    input  logic [11:0] voltage_mv,   // Simulated voltage input (mV)
    output logic        fault_detected
);

    always_ff @(posedge clk) begin
        if (rst) begin
            fault_detected <= 1'b0;
        end else begin
            fault_detected <= (voltage_mv < MIN_MV) || (voltage_mv > MAX_MV);
        end
    end

endmodule
