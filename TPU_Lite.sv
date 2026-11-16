/*
Grand Finale. Wire Up Everything.
REMEMBER TO SHEATH THE MESH IN A FF LAYER ON ALL SIDES!!
*/
module TPU_Lite #(
    parameter N = 3,
    parameter DATA_WIDTH = 32, 
    parameter RAM_SIZE = 16,
    localparam RAM_LINE_WIDTH = DATA_WIDTH * N,
    localparam SIZE_BITS = $clog2(RAM_SIZE), 
    localparam COUNTER_WIDTH = $clog2(4 * N + 1)
) (
    input axivalid, clk, reset, axilast, panic_from_reciever,
    input [DATA_WIDTH - 1 : 0] data_stream,
    output reg axiready, 
    output [DATA_WIDTH - 1 : 0] dump [0 : N - 1], 
    output data_valid
);
    wire [RAM_LINE_WIDTH - 1 : 0] mat_a_spu_to_Cluster_L [0 : N - 1];
    wire [RAM_LINE_WIDTH - 1 : 0] mat_b_spu_to_Cluster_T [0 : N - 1];
    wire write_request_spu_to_fifoctrl, canwrite_fifo_to_clusters, canread_to_RAMClusterLT, bankready_fifo_to_spu;
    wire empty_to_CommandCentre;
    wire [SIZE_BITS - 1 : 0] raddr_fifo_to_clusterLT, waddr_fifo_to_clusterLT;
    wire readreq_commandcentre_to_fifo;
    wire [COUNTER_WIDTH - 1 : 0] heartbeat_broadcast;
    wire shiftmode_command_to_cushion, newdata_command_to_core;
    wire [RAM_LINE_WIDTH - 1 : 0] clusterL_to_loaderL [0 : N - 1];
    wire [RAM_LINE_WIDTH - 1 : 0] clusterT_to_loaderT [0 : N - 1];
    wire [DATA_WIDTH - 1 : 0] loaderL_to_skewL [0 : N - 1];
    wire [DATA_WIDTH - 1 : 0] loaderT_to_skewT [0 : N - 1];
    wire [DATA_WIDTH - 1 : 0] skewL_to_Cushion [0 : N - 1];
    wire [DATA_WIDTH - 1 : 0] skewT_to_Cushion [0 : N - 1];
    wire [DATA_WIDTH - 1 : 0] skewLC_to_core [0 : N - 1];
    wire [DATA_WIDTH - 1 : 0] skewTC_to_core [0 : N - 1];
    wire shiftmodeC_to_core;
    wire good_data_Cluster_to_Command;

    SPU #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N)
    ) Staging_Unit (
        .bank_ready(~bankready_fifo_to_spu), //can_write from FIFO Unit. 
        .write_request(write_request_spu_to_fifoctrl), //The wen that again goes to the FIFO unit. 

        .clk(clk), .reset(reset), .axivalid(axivalid), .axilast(),
        .data_in(data_stream),
        .matrixa(mat_a_spu_to_Cluster_L),
        .matrixb(mat_b_spu_to_Cluster_T),
        .axiready(axiready)
    );

    FIFO_Control #(
        .N(N),
        .RAM_SIZE(RAM_SIZE)
    ) FIFO_Ctrl (
        .clk(clk), 
        .wen(write_request_spu_to_fifoctrl), 
        .ren(readreq_commandcentre_to_fifo), 
        .rst(reset),
        .read_valid(empty_to_CommandCentre), 
        .full(bankready_fifo_to_spu), //Useless
        .can_write(canwrite_fifo_to_clusters), 
        .can_read(canread_to_RAMClusterLT),
        .rd_ptr(raddr_fifo_to_clusterLT), 
        .wr_ptr(waddr_fifo_to_clusterLT)
    );

    Counter #(
        .N(N)
    ) Command_Centre (
        .empty(~empty_to_CommandCentre), 
        .clk(clk), .rst(reset), 
        .panic(panic_from_reciever),
        .ps_count(heartbeat_broadcast),
        .shift_out(shiftmode_command_to_cushion), 
        .new_data(newdata_command_to_core), 
        .rd_increment_signal(readreq_commandcentre_to_fifo), 
        .dat_val_frm_RAM(good_data_Cluster_to_Command), 
        .can_read_from_fifo(canread_to_RAMClusterLT)
    );

    RAM_Cluster #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_DEPTH(RAM_SIZE)
    ) Cluster_L (
        .matrix(mat_a_spu_to_Cluster_L),
        .wen(canwrite_fifo_to_clusters), 
        .ren(canread_to_RAMClusterLT), .clk(clk), 
        .waddr(waddr_fifo_to_clusterLT), 
        .raddr(raddr_fifo_to_clusterLT), 
        .dout(clusterL_to_loaderL),
        .i_give_good_data(good_data_Cluster_to_Command)
    );

    RAM_Cluster #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_DEPTH(RAM_SIZE)
    ) Cluster_T (
        .matrix(mat_b_spu_to_Cluster_T),
        .wen(canwrite_fifo_to_clusters), 
        .ren(canread_to_RAMClusterLT), .clk(clk), 
        .waddr(waddr_fifo_to_clusterLT), 
        .raddr(raddr_fifo_to_clusterLT), 
        .dout(clusterT_to_loaderT),
        .i_give_good_data(good_data_Cluster_to_Command)
    );

    Mesh_Loader #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) Mesh_Loader_L (
        .count(heartbeat_broadcast),
        .data_in(clusterL_to_loaderL),
        .data_out(loaderL_to_skewL)
    );

    Mesh_Loader #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH)
    ) Mesh_Loader_T (
        .count(heartbeat_broadcast),
        .data_in(clusterT_to_loaderT),
        .data_out(loaderT_to_skewT)
    );

    Skew_Unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N)
    ) Skew_L (
        .data_from_buff(loaderL_to_skewL),
        .clk(clk), .rst(reset),
        .data_to_mesh(skewL_to_Cushion)
    );

    Skew_Unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N)
    ) Skew_T (
        .data_from_buff(loaderT_to_skewT),
        .clk(clk), .rst(reset),
        .data_to_mesh(skewT_to_Cushion)
    );

    Cushion #(
        .N(N), 
        .DATA_WIDTH(DATA_WIDTH)
    ) Cushion_to_Core (
        .clk(clk),
        .reset(reset),
        .in_bus_L(skewL_to_Cushion),
        .in_bus_T(skewT_to_Cushion),
        .shift_mode(shiftmode_command_to_cushion),
        .in_bus_L_shifted(skewLC_to_core),
        .in_bus_T_shifted(skewTC_to_core),
        .shift_mode_shifted(shiftmodeC_to_core)
);


    Systolic_Mesh #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N) // NXN Matrix. 
    ) Compute_Core (
        .in_bus_L(skewLC_to_core),
        .in_bus_T(skewTC_to_core),
        .reset_in(newdata_command_to_core), //This goes to the clear_accum
        .clk(clk), 
        .shift_mode(shiftmodeC_to_core),
        .out_bus_B(dump) //Data_Bus containing out_data.
    );

assign data_valid = shiftmodeC_to_core;

endmodule