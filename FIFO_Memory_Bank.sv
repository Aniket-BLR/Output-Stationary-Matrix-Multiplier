module FIFO_Control #(
    parameter N = 3,
    parameter RAM_SIZE = 16,
    localparam SIZE_BITS = $clog2(RAM_SIZE)
) (
    input clk, wen, ren, rst,
    output logic read_valid, full, can_write, can_read,
    output wire [SIZE_BITS - 1 : 0] rd_ptr, wr_ptr
);

reg [SIZE_BITS - 1 : 0] ps_w, ps_r, ns_w, ns_r, ns_w_b;
reg [SIZE_BITS : 0] count;
reg cw, read_fire, empty;

// Accepted operations
always_comb begin
    cw        = ~full & wen;
    read_fire = ren & ~empty;

    can_write = cw;
    can_read = read_fire;
end

// Track the number of occupied slots
always_ff @(posedge clk or posedge rst) begin
    if (rst)
        count <= 0;
    else begin
        case ({cw, read_fire})
            2'b10: count <= count + 1'b1;
            2'b01: count <= count - 1'b1;
            default: count <= count;
        endcase
    end
end

// Full and empty detection
always_comb begin
    full  = (count == RAM_SIZE);
    empty = (count == 0);
    read_valid = ~empty;
end

// Write pointer
always_ff @(posedge clk or posedge rst) begin : WritePointerLogic
    if (rst)
        ps_w <= 0;
    else
        ps_w <= ns_w;
end

always_comb begin
    if (cw) begin
        if (ps_w == SIZE_BITS'(RAM_SIZE - 1))
            ns_w_b = 0;
        else
            ns_w_b = ps_w + 1'b1;
    end else
        ns_w_b = ps_w;

    ns_w = ns_w_b;
end

// Read pointer
always_ff @(posedge clk or posedge rst) begin : ReadPointerLogic
    if (rst)
        ps_r <= 0;
    else
        ps_r <= ns_r;
end

always_comb begin
    if (read_fire) begin
        if (ps_r == SIZE_BITS'(RAM_SIZE - 1))
            ns_r = 0;
        else
            ns_r = ps_r + 1'b1;
    end else
        ns_r = ps_r;
end

assign rd_ptr = ps_r;
assign wr_ptr = ps_w;

endmodule
