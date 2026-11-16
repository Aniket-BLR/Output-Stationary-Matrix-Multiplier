/*
This is the stream unit. It is basically a kind of a native interface to AXI interface converter, which allows,
any component of MINE with a native interface to interact with any AXI unit. So basically Master and slave unit for AXI Stream 
protocol*/

// ============================ AXI-4 STREAM Adapters BEGIN !! :) ==================================//

module AXI_Master #(
    parameter DATA_WIDTH = 32
) (
    // AXI-Stream facing
    input wready,
    output reg [DATA_WIDTH - 1 : 0] wdata,
    output reg wvalid,
    output reg wlast,

    // Component facing
    input internal_valid,
    input internal_last,
    input [DATA_WIDTH - 1 : 0] internal_data,
    output reg internal_ready,
    output reg handshook,

    // Global
    input clk, rst
);

// We can accept a new beat if:
// 1. No beat is currently stored, OR
// 2. The current beat will be consumed this cycle.
always @(*) begin
    internal_ready = ~wvalid | wready;
end

always @(posedge clk) begin
    if (rst) begin
        wdata     <= 0;
        wvalid    <= 0;
        wlast     <= 0;
        handshook <= 0;
    end else begin
        if (wvalid && wready)
            handshook <= 1;
        else 
            handshook <= 0;

        // The output register can accept a new beat
        if (internal_ready) begin
            wvalid <= internal_valid;

            if (internal_valid) begin
                wdata <= internal_data;
                wlast <= internal_last;
            end
        end
    end
end

endmodule


module AXI_Slave #(
    parameter DATA_WIDTH = 32
) (
    input clk, rst,

    // AXI-Stream facing
    input [DATA_WIDTH - 1 : 0] wdata,
    input wvalid, wlast,
    output reg wready,

    // Component facing
    input ready_from_slave,
    output reg [DATA_WIDTH - 1 : 0] data_to_slave,
    output reg valid_to_slave,
    output reg last_to_slave
);

always @(*) begin
    // Can accept a new beat if the output register is empty,
    // or if the component consumes its current beat this cycle.
    wready = ~valid_to_slave | ready_from_slave;
end

always @(posedge clk) begin
    if (rst) begin
        data_to_slave  <= 0;
        valid_to_slave <= 0;
        last_to_slave  <= 0;
    end else begin
        // Accept a new AXI beat whenever the buffer can take one.
        if (wready) begin
            valid_to_slave <= wvalid;
            if (wvalid) begin
                data_to_slave <= wdata;
                last_to_slave <= wlast;
            end
        end
    end
end

endmodule

// =========================== AXI-4 Stream Adapters END!! :) ===============================//

