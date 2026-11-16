module testbench();
    reg [32 - 1 : 0] in_bus_L [0 : 3 - 1];
    reg [32 - 1 : 0] in_bus_T [0 : 3 - 1];
    reg reset;
    reg clk;
    reg shift_mode;
    wire [32 - 1 : 0] out_bus_B [0 : 3 - 1];
 
    Systolic_Mesh #(
        .DATA_WIDTH(32),
        .N(3)
    ) DUT (
        .in_bus_L(in_bus_L),
        .in_bus_T(in_bus_T),
        .reset_in(reset),
        .clk(clk), 
        .shift_mode(shift_mode),
        .out_bus_B(out_bus_B)
    );
 
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, testbench);
 
        $monitor("Row_out: %d%d%d  Shift_Out: %d \n ", out_bus_B[0], out_bus_B[1], out_bus_B[2], shift_mode);
    end
 
    always #1 clk = ~clk; 
 
    initial begin
        clk = 0; 
        reset = 1;
        shift_mode = 0;
    end
 
    // Icarus doesn't support a queue nested inside a fixed array (array-of-queue) -
    // so this is three standalone scalar queues per bus instead of in_Lq[0:2][$].
    // I'm gonna introduce latency here itself.
    logic [31 : 0] in_Lq0 [$], in_Lq1 [$], in_Lq2 [$];
    logic [31 : 0] in_Tq0 [$], in_Tq1 [$], in_Tq2 [$];
 
    initial begin
        // in_Lq0 = '{32'b1, 32'b0, 32'b0, 32'b0, 32'b0}; // row 0: 1 at t=0
        // in_Lq1 = '{32'b0, 32'b1, 32'b0, 32'b0, 32'b0}; // row 1: 1 at t=1
        // in_Lq2 = '{32'b0, 32'b0, 32'b1, 32'b0, 32'b0}; // row 2: 1 at t=2
 
        // in_Tq0 = '{32'b1, 32'b0, 32'b0, 32'b0, 32'b0}; // col 0: 1 at t=0
        // in_Tq1 = '{32'b0, 32'b1, 32'b0, 32'b0, 32'b0}; // col 1: 1 at t=1
        // in_Tq2 = '{32'b0, 32'b0, 32'b1, 32'b0, 32'b0}; // col 2: 1 at t=2

        in_Lq0 = '{32'b1, 32'b1, 32'b1, 32'b0, 32'b0}; // row 0: 1 1 1
        in_Lq1 = '{32'b0, 32'b1, 32'b1, 32'b1, 32'b0}; // row 1: 1 1 1
        in_Lq2 = '{32'b0, 32'b0, 32'b1, 32'b1, 32'b1}; // row 2: 1 1 1
 
        in_Tq0 = '{32'b1, 32'b1, 32'b1, 32'b0, 32'b0};  // 1 1 1
        in_Tq1 = '{32'b0, 32'b1, 32'b1, 32'd1, 32'b0};  // 1 1 1 
        in_Tq2 = '{32'b0, 32'b0, 32'b1, 32'b1, 32'b1};  // 1 1 1
    end
 
    // Can't index into an array of queue handles either, so this is unrolled
    // per-row instead of the original for loop.
    always @(posedge clk) begin
        if (in_Lq0.size() > 0) in_bus_L[0] <= in_Lq0.pop_front(); else in_bus_L[0] <= '0;
        if (in_Lq1.size() > 0) in_bus_L[1] <= in_Lq1.pop_front(); else in_bus_L[1] <= '0;
        if (in_Lq2.size() > 0) in_bus_L[2] <= in_Lq2.pop_front(); else in_bus_L[2] <= '0;
 
        if (in_Tq0.size() > 0) in_bus_T[0] <= in_Tq0.pop_front(); else in_bus_T[0] <= '0;
        if (in_Tq1.size() > 0) in_bus_T[1] <= in_Tq1.pop_front(); else in_bus_T[1] <= '0;
        if (in_Tq2.size() > 0) in_bus_T[2] <= in_Tq2.pop_front(); else in_bus_T[2] <= '0;
    end
 
    // Timing budget for a 3x3 mesh:
    //  - reset ripple takes (N-1)+(N-1) = 4 clock edges to reach the far corner (2,2)
    //  - the 5-deep input queues take 5 cycles to fully drain
    //  - the last value out of the queue still needs up to 4 more cycles of
    //    pipeline latency (out_L/out_T are registered) to reach the far corner
    //    and get multiplied in
    // so compute isn't actually done until ~cycle 9-10. Holding reset for only
    // 4 cycles and switching to shift_mode at cycle 4 (the old code) freezes
    // and drains the array mid-computation - that's the "gibberish".
    task automatic CheckMatrix();
        repeat (12) @(posedge clk);  // let the MAC pass fully settle before draining
        shift_mode = 1;
        repeat (5) @(posedge clk);   // hold shift_mode long enough to walk all N rows out
        $finish;
    endtask //automatic
 
    initial begin
        // repeat (6) @(posedge clk);   // hold reset well past the worst-case 4-hop ripple
        CheckMatrix();
    end

    initial begin
        #1.5 reset = 0;
    end
 
endmodule