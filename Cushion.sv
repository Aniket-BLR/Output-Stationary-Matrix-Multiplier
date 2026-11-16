module Cushion #(
    parameter N = 3, 
    parameter DATA_WIDTH = 32
) (
    input clk,
    input reset,
    input [DATA_WIDTH - 1 : 0] in_bus_L [0 : N - 1],
    input [DATA_WIDTH - 1 : 0] in_bus_T [0 : N - 1],
    input shift_mode,
    output reg [DATA_WIDTH - 1 : 0] in_bus_L_shifted [0 : N - 1],
    output reg [DATA_WIDTH - 1 : 0] in_bus_T_shifted [0 : N - 1],
    output reg shift_mode_shifted
);

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        for (integer i = 0; i < N; i = i + 1) begin
            in_bus_L_shifted[i] <= '0;
            in_bus_T_shifted[i] <= '0;
        end
        shift_mode_shifted <= 1'b0;
    end else begin
        for (integer i = 0; i < N; i = i + 1) begin
            in_bus_L_shifted[i] <= in_bus_L[i];
            in_bus_T_shifted[i] <= in_bus_T[i];
        end
        shift_mode_shifted <= shift_mode;
    end
end
    
endmodule