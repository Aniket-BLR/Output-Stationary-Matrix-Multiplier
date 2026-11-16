`include "PE.sv"
module Systolic_Mesh #(
    parameter DATA_WIDTH = 32,
    parameter N = 3 // NXN Matrix. 
) (
    input [DATA_WIDTH - 1 : 0] in_bus_L [0 : N - 1],
    input [DATA_WIDTH - 1 : 0] in_bus_T [0 : N - 1],
    input reset_in, //This goes to the clear_accum
    input clk, shift_mode,
    output reg [DATA_WIDTH - 1 : 0] out_bus_B [0 : N - 1] //Data_Bus containing out_data.
);
    reg reset;
    always_ff @(posedge clk) begin : blockName
        reset <= reset_in;
    end
    //We will instantiate this row wise. First row to be manually instantiated. The remaining rectangle will go in the loop. 
    logic clear_accum_chain_TOP_ROW [0 : N]; 
    assign clear_accum_chain_TOP_ROW [0] = reset;

    logic [DATA_WIDTH - 1 : 0] in_LR_bus_TOPROW [0 : N];
    assign in_LR_bus_TOPROW[0] = in_bus_L[0];

    logic [DATA_WIDTH - 1 : 0] out_to_B_TOPROW [0 : N - 1];
    logic [DATA_WIDTH - 1 : 0] shift_out_B_TOPROW [0 : N - 1];

    logic clear_accum_to_REST [0 : N - 1];

    for (genvar a = 0; a < N; a = a + 1) begin
        assign clear_accum_to_REST [a] = clear_accum_chain_TOP_ROW[a + 1];
    end

    generate
        for (genvar i = 0; i < N; i = i + 1) begin : TOP_ROW
            ProcessingElement #(
                .DATA_WIDTH(DATA_WIDTH)
                ) PE (
                    .in_L(in_LR_bus_TOPROW[i]), 
                    .in_T(in_bus_T[i]), 
                    .shift_in('0), 
                    .clear_accum(clear_accum_chain_TOP_ROW[i]), 
                    .clk(clk), 
                    .shift_mode(shift_mode),
                    .out_R(in_LR_bus_TOPROW[i + 1]), 
                    .out_B(out_to_B_TOPROW[i]), 
                    .clear_accum_out(clear_accum_chain_TOP_ROW[i + 1]), 
                    .shift_out(shift_out_B_TOPROW[i])
            );
        end
    endgenerate

    //Now we instantiate the remaining rectangle of the mesh. 
    logic [DATA_WIDTH - 1 : 0] in_LR_bus_REST [1 : N - 1][0 : N];
    for (genvar x = 1; x < N; x = x + 1) begin
        assign in_LR_bus_REST[x][0] = in_bus_L[x]; //The left column is the input.
        //x iterates the levels => rows. And 0 => the column. 
    end

    logic [DATA_WIDTH - 1 : 0] in_TB_bus_REST [0 : N - 1][0 : N - 1];
    for (genvar y = 0; y < N; y = y + 1) begin
        assign in_TB_bus_REST[0][y] = out_to_B_TOPROW[y]; //0 => The level. Top level: Top Row. And y iterates l to r. 
    end
    //in_TB_bus_REST[N - 1][i] sits alongside the output bus. 

    logic [DATA_WIDTH - 1 : 0] shift_bus_REST [0 : N - 1][0 : N - 1];
    for (genvar w = 0; w < N; w = w + 1) begin
        assign shift_bus_REST[0][w] = shift_out_B_TOPROW[w]; //Basically top level connected to the mesh. 
    end

    logic reset_rippler[0 : N - 1][0 : N - 1];
    for (genvar b = 0; b < N; b = b + 1) begin
        assign reset_rippler[0][b] = clear_accum_to_REST[b]; 
    end

    generate
        for (genvar j = 0; j < N; j = j + 1) begin : COL
            for (genvar k = 1; k < N; k = k + 1) begin : ROW //top row is already instantiated.
                ProcessingElement #(
                    .DATA_WIDTH(DATA_WIDTH)
                    ) PE (
                        .in_L(in_LR_bus_REST[k][j]), 
                        .in_T(in_TB_bus_REST[k - 1][j]), 
                        .shift_in(shift_bus_REST[k - 1][j]), 
                        .clear_accum(reset_rippler[k - 1][j]), 
                        .clk(clk), 
                        .shift_mode(shift_mode),
                        .out_R(in_LR_bus_REST[k][j + 1]), 
                        .out_B(in_TB_bus_REST[k][j]), 
                        .clear_accum_out(reset_rippler[k][j]), 
                        .shift_out(shift_bus_REST[k][j])
                ); 
            end
        end
    endgenerate

    for (genvar o = 0; o < N; o = o + 1) begin
        assign out_bus_B[o] = shift_bus_REST[N - 1][o];
    end

endmodule

//Going by the rippler logic, the reset signal will reach the last intended corner at the (2N - 1)th cycle.
//Rippler logic helps in diminishing the fanout that would increase, had we driven a reset signal everywhere. Though it would
// use lesser logic than this. 
 
/*
                ProcessingElement #(
                    .DATA_WIDTH(DATA_WIDTH)
                    ) PE (
                        .in_L(), 
                        .in_T(), 
                        .shift_in(), 
                        .clear_accum(), 
                        .clk(), 
                        .shift_mode(),
                        .out_R(), 
                        .out_B(), 
                        .clear_accum_out(), 
                        .shift_out()
                    );  
*/