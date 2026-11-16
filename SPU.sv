`include "AXI_Stream.sv"
/*
This is the Stream Processing Unit!! (cool name)
The AXI stream, will just dump a whole lot of data (NxNx2 data points) and this unit, is responsible
for loading the N x N x 2 data values into their correct locations.

As a convention, it will be understood that the data being streamed is in order. The first NxN values
will make up the first matrix and then the 2nd matrix. 

Data must be stored in the master memory, in this manner, 
 
           ----------- 
           |         |
           |        \|/
x - x - x  |    x - x - x
|  a11  |  |    |  b11  |
x - x - x  |    x - x - x
|  a12  |  |    |  b12  |
x - x - x  |    x - x - x
|  a13  |  |    |  b13  |
x - x - x  |    x - x - x
|  a21  |  |    |  b21  |        // Each of these values are 32bits real integers. Example shown
x - x - x  |    x - x - x           for 3x3 matrix. 9+9 = 18 elements. 
|  a22  |  |    |  b22  |
x - x - x  |    x - x - x
|  a23  |  |    |  b23  |
x - x - x  |    x - x - x
|  a31  |  |    |  b31  |
x - x - x  |    x - x - x
|  a32  |  |    |  b32  |
x - x - x  |    x - x - x
|  a33  |  |    |  b33  |
x - x - x  |    x - x - x
    |      |
    -------|

Data will start streaming in from a1!!. Last data point recieved = b33!
The SPU will communicate with it's AXI-4 Stream Adapter. 
*/


// module SPU #(
//     parameter DATA_WIDTH = 32,
//     parameter N = 3,
//     localparam RAM_LINE_WIDTH = N * DATA_WIDTH,
//     localparam COUNT_WIDTH = $clog2(N)
// ) (
//     input bank_ready, //can_write from FIFO Unit. 
//     output write_request, //The wen that again goes to the FIFO unit. 

//     input clk, reset, axivalid, axilast,
//     input [DATA_WIDTH - 1 : 0] data_in,
//     output reg [RAM_LINE_WIDTH - 1 : 0] matrixa [0 : N - 1],
//     output reg [RAM_LINE_WIDTH - 1 : 0] matrixb [0 : N - 1],
//     output reg axiready
// );

// // These signals are visible to the unit. 
// logic [DATA_WIDTH - 1 : 0] buff;
// logic valid;
// logic tlast; //This is the last signal to be registered and forwarded into the IP. 
// logic slave_ready;

// AXI_Slave #(
//         .DATA_WIDTH(DATA_WIDTH)
//     ) Slave_Port (
//         .clk(clk), .rst(reset),

//     // AXI-Stream facing
//         .wdata(data_in),
//         .wvalid(axivalid), .wlast(axilast),
//         .wready(axiready),

//     // Component facing
//         .ready_from_slave(slave_ready),
//         .data_to_slave(buff),
//         .valid_to_slave(valid),
//         .last_to_slave(tlast)
// );

// //Now the rest of the SPU will read only from the buff register. 

// endmodule

module SPU #(
    parameter DATA_WIDTH = 32,
    parameter N = 3,
    localparam RAM_LINE_WIDTH = N * DATA_WIDTH,
    localparam COUNT_WIDTH = $clog2(N)
) (
    input bank_ready, // can_write from FIFO Unit. 
    output reg write_request, // The wen that again goes to the FIFO unit. 

    input clk, reset, axivalid, axilast,
    input [DATA_WIDTH - 1 : 0] data_in,
    output reg [RAM_LINE_WIDTH - 1 : 0] matrixa [0 : N - 1],
    output reg [RAM_LINE_WIDTH - 1 : 0] matrixb [0 : N - 1],
    output wire axiready
);

    // These signals are visible to the unit. 
    logic [DATA_WIDTH - 1 : 0] buff;
    logic valid;
    logic tlast; // This is the last signal to be registered and forwarded into the IP. 
    logic slave_ready;

    AXI_Slave #(
        .DATA_WIDTH(DATA_WIDTH)
    ) Slave_Port (
        .clk(clk), .rst(reset),

        // AXI-Stream facing
        .wdata(data_in),
        .wvalid(axivalid), .wlast(axilast),
        .wready(axiready),

        // Component facing
        .ready_from_slave(slave_ready),
        .data_to_slave(buff),
        .valid_to_slave(valid),
        .last_to_slave(tlast)
    );

    // -------------------------------------------------------------------------
    // Matrix Assembly & Control Logic
    // -------------------------------------------------------------------------
    localparam TOTAL_ELEMENTS = 2 * N * N;
    localparam MAT_ELEMENTS   = N * N;

    int element_cnt;
    int row_idx;
    int col_idx;
    integer i;

    // Tell AXI_Slave we can accept data whenever FIFO has space and we aren't
    // currently committing a completed batch to RAM.
    assign slave_ready = bank_ready && !write_request;

    // Transfer happens on the component side when both valid and ready are HIGH
    wire pop_word = valid && slave_ready;

    always_ff @(posedge clk) begin
        if (reset) begin
            element_cnt   <= 0;
            row_idx       <= 0;
            col_idx       <= 0;
            write_request <= 1'b0;

            for (i = 0; i < N; i = i + 1) begin
                matrixa[i] <= '0;
                matrixb[i] <= '0;
            end
        end else begin
            // Default to 0 so write_request is a clean 1-cycle pulse
            write_request <= 1'b0;

            if (pop_word) begin
                // 1. Shift data in from the right so the 1st element ends up at the MSB
                if (element_cnt < MAT_ELEMENTS) begin
                    // First N^2 elements -> Matrix A (row-major)
                    matrixa[row_idx] <= {matrixa[row_idx][RAM_LINE_WIDTH - DATA_WIDTH - 1 : 0], buff};
                end else begin
                    // Second N^2 elements -> Matrix B (column-major / transposed)
                    matrixb[col_idx] <= {matrixb[col_idx][RAM_LINE_WIDTH - DATA_WIDTH - 1 : 0], buff};
                end

                // 2. Update counters and trigger FIFO write on the final element
                if (element_cnt == TOTAL_ELEMENTS - 1) begin
                    write_request <= 1'b1;
                    element_cnt   <= 0;
                    row_idx       <= 0;
                    col_idx       <= 0;
                end else begin
                    element_cnt <= element_cnt + 1;

                    if (col_idx == N - 1) begin
                        col_idx <= 0;
                        if (row_idx == N - 1)
                            row_idx <= 0; // Reset row index when switching from Matrix A to B
                        else
                            row_idx <= row_idx + 1;
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end
            end
        end
    end

endmodule