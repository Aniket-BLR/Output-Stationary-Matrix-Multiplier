module Counter #(
    parameter N = 3,
    localparam COUNTER_WIDTH = $clog2(4 * N + 1)
) (
    input empty, clk, rst, panic, can_read_from_fifo, dat_val_frm_RAM,
    output [COUNTER_WIDTH - 1 : 0] ps_count,
    output reg shift_out, new_data, rd_increment_signal
);
/*
The freeze signal will be sampled only at ps = 3N. This is the cycle that decides, whether to switch to shift mode. 
If the reciever is not ready for matrix dump, it informs the PE, by raising the panic flag. If reciever has panicked, 
we will not perform a data dump, and freeze the counter right where it is. The PE, will hold the final matrix, up until
shift is raised to 1, and counter is unfreezed. 

Since the counter is frozen, new data won't be dumped at all. 
*/

/* Signals to control:
    shift_out, new_data, counter_state, rd_increment_signal
*/   
reg [COUNTER_WIDTH - 1 : 0] ps, ns;
always @(posedge clk) begin //Synchronous reset.
    if (rst)
        ps <= 4 * N;
    else
        ps <= ns;
end

/*
Counter Check Points:
Edge 4N : Buffer Cycle. Neither in compute mode nor in shift mode. Decision on stall/resume counter. 
Edge 0  : New Data signal is raised. 
Edge 1  : New Data signal is lowered: Array now operates in compute domain.
Edge N-1: N Cycles elapsed. Therefore, read pointer can be incremented now. !!Ensure increment takes place on subsequent cycle.!!
Edge 3N : Decision on counter freeze taken. Data is now held in the array. Awaits shift order. If reciever panics, we stall and
          do not raise the shift command.
Edge 4N : Now shift is brought down to zero.
*/

//Counter freeze unfreeze logic.
always_comb begin : CounterBlock
    if (ps == 4 * N) 
        if(dat_val_frm_RAM)
            ns = 0;
        else
            ns = ps;
    else if (ps == 3 * N)
        if(panic)
            ns = ps;
        else 
            ns = ps + 1;
    else
        ns = ps + 1;
end

always_comb begin : NewDataBlock
    if(ps == 0)
        new_data = 1;
    else
        new_data = 0;
end

always_comb begin : ShiftBlock
    if (ps == 3 * N)
        if (panic)
            shift_out = 0;
        else
            shift_out = 1;
    else if ((ps > 3 * N) && (ps < 4 * N)) //Follows logically, if reciever panicked at 3N, counter would've stalled at 3N. 
        shift_out = 1;
    else 
        shift_out = 0;
end

reg processing_now_ps, processing_now_ns;
always_ff @(posedge clk) begin : rd_incrBlock
    if (ps == 4 * N) begin
        if (!processing_now_ps) begin
            rd_increment_signal = panic ? 0 : 1;
        end else begin
            rd_increment_signal = 0;
        end
    end
    //This will turn 1 the moment the deities are not panicking. 

    //     rd_increment_signal = 1;
    // else
    //     rd_increment_signal = 0;
end

always @(negedge clk) begin
    if (!rst) begin
        processing_now_ps <= processing_now_ns;
    end else begin
        processing_now_ps <= 0;
    end
end

always_comb begin
    if (ps == 4 * N) begin
        processing_now_ns = (processing_now_ps) ? 1 : (rd_increment_signal & can_read_from_fifo);
    end else begin
        processing_now_ns = 0;
    end
end

assign ps_count = ps;

endmodule

/*
Thus, if I need to reset the systolic array, all I need to do is, reset the Counter! Making new_data signal, helps with this
universality. Otherwise, I would need to specifically make a reset logic for the mesh as well!
*/