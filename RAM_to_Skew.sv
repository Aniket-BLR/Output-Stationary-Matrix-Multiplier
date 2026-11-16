module Controller_Unit #(
    parameter N = 3,
    localparam COUNTER_WIDTH = $clog2(4 * N + 1),
    localparam CONTROL_BITS = $clog2(N)
) (
    input [COUNTER_WIDTH - 1 : 0] count_in,
    output reg [CONTROL_BITS - 1 : 0] control_out,
    output reg zero_ctrl
);

// always_comb begin
//     if (count_in < N) begin
//         zero_ctrl = 0;
//         control_out = count_in[CONTROL_BITS - 1 : 0];
//     end else begin
//         zero_ctrl = 1;
//         control_out = 0;
//     end
// end

assign zero_ctrl   = (count_in >= N);
assign control_out = (count_in < N) ? count_in[CONTROL_BITS - 1 : 0] : '0;

endmodule

module Memory_to_Skew #(
    parameter DATA_WIDTH = 32,
    parameter N = 3,
    localparam CONTROL_BITS = $clog2(N),
    localparam LINE_WIDTH = DATA_WIDTH * N
) (
    input [LINE_WIDTH - 1 : 0] lines_in [0 : N - 1], //comes in as [a1][a2][a3], => MSB has a1
    input [CONTROL_BITS - 1 : 0] control_in,
    input zero_ctrl,
    output reg [DATA_WIDTH - 1 : 0] Data_to_Skew [0 : N - 1]
);
//Make attempts to keep 0th bus the top row value. Or left column value. 
logic [DATA_WIDTH - 1 : 0] intermediate_parsing [0 : N - 1][0 : N - 1];

for (genvar i = 0; i < N; i = i + 1) begin : MESH_ROW
    for (genvar j = 0; j < N; j = j + 1) begin : INTERNAL_CHOICES
        assign intermediate_parsing[i][j] = lines_in[i][(DATA_WIDTH) * j +: DATA_WIDTH];
    end
end

// logic zero_ctrl;

// always_comb begin
//     if (count_in < N)
//         zero_ctrl = 0;
//     else
//         zero_ctrl = 1; 
// end

// logic [DATA_WIDTH - 1 : 0] MUX_to_MUX [0 : N - 1];
always_comb begin
    for (int a = 0; a < N; a = a + 1) begin
        if (!zero_ctrl)
            Data_to_Skew[a] = intermediate_parsing[a][control_in];
        else
            Data_to_Skew[a] = 0; 
    end
end

// always_comb begin
//     for (int b = 0; b < N; b = b + 1) begin
//         if (zero_ctrl)
//             Data_to_Skew [b] = '0;
//         else
//             Data_to_Skew [b] = MUX_to_MUX[b]; 
//     end
// end
    
endmodule

module Mesh_Loader #(
    parameter N = 3,
    parameter DATA_WIDTH = 32,
    localparam COUNTER_WIDTH = $clog2(4 * N + 1),
    localparam CONTROL_BITS = $clog2(N),
    localparam LINE_WIDTH = DATA_WIDTH * N
) (
    input [COUNTER_WIDTH - 1 : 0]count,
    input [LINE_WIDTH - 1 : 0] data_in [0 : N - 1],
    output reg [DATA_WIDTH - 1 : 0] data_out [0 : N - 1]
);

wire [CONTROL_BITS - 1 : 0] ctrl_mid;
wire zero;

Controller_Unit #(
    .N(N)
) C (
    .count_in(count),
    .control_out(ctrl_mid),
    .zero_ctrl(zero)
);

Memory_to_Skew #(
    .DATA_WIDTH(DATA_WIDTH),
    .N(N)
) M (
    .lines_in(data_in),
    .control_in(ctrl_mid),
    .zero_ctrl(zero),
    .Data_to_Skew(data_out)
);
    
endmodule