module Skew_Fundunit #( //Use this when delaying by at least one cycle. 
    parameter DATA_WIDTH = 32,
    parameter DELAY_CYCLE = 1
) (
    input [DATA_WIDTH - 1 : 0] d,
    input clk, rst,
    output reg [DATA_WIDTH - 1 : 0]q 
);

reg [DATA_WIDTH - 1 : 0] wiring [0 : DELAY_CYCLE];
always_comb begin
    wiring[0] = d;
    q = wiring[DELAY_CYCLE];
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for(int i = 0; i < DELAY_CYCLE; i = i + 1) begin
            wiring[i + 1] <= 0;
        end
    end else begin
        for(int i = 0; i < DELAY_CYCLE; i = i + 1) begin
            wiring[i + 1] <= wiring[i];
        end
    end
end
    
endmodule

module Skew_Unit #(
    parameter DATA_WIDTH = 32,
    parameter N = 3
) (
    input [DATA_WIDTH - 1 : 0] data_from_buff [0 : N - 1],
    input clk, rst,
    output reg [DATA_WIDTH - 1 : 0] data_to_mesh [0 : N - 1]
);

generate
    for (genvar i = 1; i < N; i = i + 1) begin // Iterate over the rows. 
        Skew_Fundunit #(
            .DATA_WIDTH(DATA_WIDTH),
            .DELAY_CYCLE(i)
        ) S (
            .d(data_from_buff[i]),
            .clk(clk),
            .rst(rst),
            .q(data_to_mesh[i])
        );
    end
endgenerate

always_comb begin
    data_to_mesh[0] = data_from_buff[0];
end
    
endmodule