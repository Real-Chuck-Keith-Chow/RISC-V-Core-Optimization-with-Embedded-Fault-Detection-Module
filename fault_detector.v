// fault_detector.v
// Simple voltage anomaly fault detector module

module fault_detector (
    input logic clk,
    input logic reset_n,
    input logic [11:0] voltage_in,   // Simulated voltage input (e.g., from ADC, 12-bit)
    output logic fault_detected
);

    // Threshold parameters (you can tune)
    parameter logic [11:0] V_MIN = 12'd1000;   // Example: 1.0 V
    parameter logic [11:0] V_MAX = 12'd3000;   // Example: 3.0 V

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            fault_detected <= 1'b0;
        end else begin
            if (voltage_in < V_MIN || voltage_in > V_MAX) begin
                fault_detected <= 1'b1;
            end else begin
                fault_detected <= 1'b0;
            end
        end
    end

endmodule
