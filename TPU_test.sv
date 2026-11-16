module testbench();
    reg axivalid, clk, reset, axilast, panic_from_reciever;
    reg [31 : 0] data_stream;

    wire Matrix_valid, axiready;
    wire [31 : 0] dump_array [0 : 2];

    wire [95 : 0] readable = {dump_array[0], dump_array[1], dump_array[2]};

    logic [31:0] expected_rows [0:2][0:2] = '{
        '{32'd0, 32'd0, 32'd1}, // Row 0
        '{32'd0, 32'd1, 32'd0}, // Row 1
        '{32'd1, 32'd0, 32'd0}  // Row 2
    };
 
    TPU_Lite #(
        .N(3),
        .DATA_WIDTH(32), 
        .RAM_SIZE(16)
    ) TPU (
        .axivalid(axivalid), 
        .clk(clk), 
        .reset(reset), 
        .axilast(axilast), 
        .panic_from_reciever(panic_from_reciever),
        .data_stream(data_stream),
        .axiready(axiready), 
        .dump(dump_array), 
        .data_valid(Matrix_valid)
    );
 
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, testbench);
    end
 
    always #1 clk = ~clk; 
 
    initial begin
        clk = 0; 
        reset = 1;
        axivalid = 0;
        axilast = 0;
        panic_from_reciever = 1;
        data_stream = '0;
    end

    task send_stream_word(
        input [31 : 0] data,
        input is_last
    );
        begin
            // Drive data and assert valid on clock edge
            @(posedge clk);
            data_stream <= data;
            axivalid    <= 1'b1;
            axilast     <= is_last;

            // Wait until axiready is sampled HIGH at a rising clock edge
            do begin
                @(posedge clk);
            end while (!axiready);

            // Handshake completed! Deassert valid for next cycle unless back-to-back
            axivalid <= 1'b0;
            axilast  <= 1'b0;
        end
    endtask
    
    // reg [31 : 0] data;
    // logic last_flag = 0;
    // logic success;
    // initial begin
    //     @(negedge clk); //Give one posedge to actually register the reset. 
    //     @(negedge clk);
    //     reset = 0;
    //     panic_from_reciever = 0; //Though I wanna see the behavior at panic. 
    //     for (int j = 0; j < 2; j++) begin
    //         last_flag = 0;
    //         for(int i = 1; i <= 18; i = i + 1) begin
    //             if (i == 18)
    //                 last_flag = 1;

    //             if(i == 1 || i == 5 || i == 9 || i == 10 || i == 14 || i == 18)
    //                 data = 1;
    //             else 
    //                 data = 0; 

    //             send_stream_word(data, last_flag);
    //         end
    //     end

    //     $display("Matrix Processing!\n");
    //     while(!Matrix_valid) @(posedge clk);

    //     $display("Matrix Ready with DATA!\n");
    //     for (int j = 0; j < 3; j = j + 1) begin
    //         success = 1;
    //         for (int k = 0; k < 3; k = k + 1) begin
    //             if(expected_rows[j][k] != dump_array[k])
    //                 success = 0; 
    //         end

    //         if(!success) begin
    //             $display("YOU'RE A LOSER!\n");
    //             $display("Expected : %d  %d  %d \n", expected_rows[j][0], expected_rows[j][1], expected_rows[j][2]);
    //             $display("Got      : %d  %d  %d \n", dump_array[0], dump_array[1], dump_array[2]);
    //         end else begin
    //             $display("NICE!!   : %d  %d  %d \n", dump_array[0], dump_array[1], dump_array[2]);
    //         end

    //         @(posedge clk); //On the next edge the next data point will be registered. 
    //     end

    //     @(posedge clk);
    //     @(posedge clk);

    //     $display("Wait a minute...\n");
    //     while(!Matrix_valid) @(posedge clk);

    //     $display("Matrix Ready with DATA!\n");
    //     for (int j = 0; j < 3; j = j + 1) begin
    //         success = 1;
    //         for (int k = 0; k < 3; k = k + 1) begin
    //             if(expected_rows[j][k] != dump_array[k])
    //                 success = 0; 
    //         end

    //         if(!success) begin
    //             $display("YOU'RE A LOSER!\n");
    //             $display("Expected : %d  %d  %d \n", expected_rows[j][0], expected_rows[j][1], expected_rows[j][2]);
    //             $display("Got      : %d  %d  %d \n", dump_array[0], dump_array[1], dump_array[2]);
    //         end else begin
    //             $display("NICE!!   : %d  %d  %d \n", dump_array[0], dump_array[1], dump_array[2]);
    //         end

    //         @(posedge clk); //On the next edge the next data point will be registered. 
    //     end


    //     #200 $finish;
    // end

    //==========================TRY THIS =========================================================
    reg [31 : 0] data;
    logic last_flag = 0;
    logic success;

    initial begin
        @(negedge clk);
        @(negedge clk);
        reset = 0;
        panic_from_reciever = 0;

        fork
            // THREAD 1: Stream 2 matrix pairs (36 words)
            begin
                for (int j = 0; j < 2; j++) begin
                    last_flag = 0;
                    for (int i = 1; i <= 18; i = i + 1) begin
                        if (i == 18)
                            last_flag = 1;

                        if (i == 1 || i == 5 || i == 9 || i == 10 || i == 14 || i == 18)
                            data = 1;
                        else 
                            data = 0; 

                        send_stream_word(data, last_flag);
                    end
                end
                $display("Finished sending both matrix pairs!\n");
            end

            // THREAD 2: Monitor & verify 2 output matrices as soon as each becomes valid
            begin
                for (int m = 0; m < 2; m = m + 1) begin
                    while (!Matrix_valid) @(posedge clk);

                    $display("Matrix %0d Ready with DATA!\n", m + 1);
                    for (int j = 0; j < 3; j = j + 1) begin
                        success = 1;
                        for (int k = 0; k < 3; k = k + 1) begin
                            if (expected_rows[j][k] !== dump_array[k])
                                success = 0; 
                        end

                        if (!success) begin
                            $display("YOU'RE A LOSER! (Matrix %0d, Row %0d)\n", m + 1, j);
                            $display("Expected : %d  %d  %d \n", expected_rows[j][0], expected_rows[j][1], expected_rows[j][2]);
                            $display("Got      : %d  %d  %d \n", dump_array[0], dump_array[1], dump_array[2]);
                        end else begin
                            $display("NICE!!   : %d  %d  %d \n", dump_array[0], dump_array[1], dump_array[2]);
                        end

                        @(posedge clk);
                    end
                end
            end
        join

        #20 $finish;
    end
 
endmodule