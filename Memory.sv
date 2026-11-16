module RAM #(
    parameter N = 3,
    parameter DATA_WIDTH = 32,
    parameter MEMORY_DEPTH = 16,
    localparam ADDR_BITS = $clog2(MEMORY_DEPTH),
    localparam DATA_IN_WIDTH = N * DATA_WIDTH
) (
    input wen, ren, clk, 
    input [ADDR_BITS - 1 : 0]waddr, raddr, 
    input [DATA_IN_WIDTH - 1 : 0]din,
    output reg [DATA_IN_WIDTH - 1 : 0]dout
);

reg [DATA_IN_WIDTH - 1 : 0] ram [0 : MEMORY_DEPTH - 1];

initial begin
    for (int i = 0; i < MEMORY_DEPTH; i = i + 1) begin
        ram[i] = '0;
    end
end

//READ-FIRST DESIGN!
always @(posedge clk) begin
    if (ren)
        dout <= ram[raddr]; 
end


always @(posedge clk) begin
    if (wen)
        ram[waddr] <= din;
end

endmodule

module RAM_Cluster #(
    parameter N = 3,
    parameter DATA_WIDTH = 32,
    parameter MEMORY_DEPTH = 16,
    localparam ADDR_BITS = $clog2(MEMORY_DEPTH),
    localparam DATA_IN_WIDTH = N * DATA_WIDTH
) (
    input [DATA_IN_WIDTH - 1 : 0] matrix [0 : N - 1],
    input wen, ren, clk, 
    input [ADDR_BITS - 1 : 0]waddr, raddr, 
    output reg [DATA_IN_WIDTH - 1 : 0] dout [0 : N - 1],
    output reg i_give_good_data //FIX THE CONDITION!
);
    generate
        for (genvar i = 0; i < N; i = i + 1) begin
            RAM #(
                .N(N),
                .DATA_WIDTH(DATA_WIDTH),
                .MEMORY_DEPTH(MEMORY_DEPTH)
            ) R (
                .wen(wen), 
                .ren(ren),  
                .clk(clk), 
                .waddr(waddr), 
                .raddr(raddr), 
                .din(matrix[i]),
                .dout(dout[i])
            );
        end
    endgenerate

    always @(posedge clk) begin
        i_give_good_data <= ren;
    end

endmodule