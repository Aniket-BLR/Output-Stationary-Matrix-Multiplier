module ProcessingElement #(
    parameter DATA_WIDTH = 32
) (
    input [DATA_WIDTH - 1 : 0] in_L, in_T, shift_in,
    input clear_accum, clk, shift_mode,
    output reg [DATA_WIDTH - 1 : 0] out_R, out_B, 
    output reg clear_accum_out,
    output reg [DATA_WIDTH - 1 : 0]shift_out
);
    reg [DATA_WIDTH - 1 : 0] accum;
    reg [DATA_WIDTH - 1 : 0] accum_int0, accum_int1; 

//
    always_ff @(posedge clk) begin
        accum <= accum_int0; 
    end

    always_comb begin
        if (clear_accum)
            accum_int1 = in_L * in_T;
        else 
            accum_int1 = (in_L * in_T) + accum; 
    end

    always_comb begin
        if (shift_mode)
            accum_int0 = shift_in;
        else 
            accum_int0 = accum_int1; 
    end
//

    always_ff @(posedge clk) begin : Register_MAC
        out_R <= in_L;
        out_B <= in_T; 
    end

    always_ff @(posedge clk) begin : blockName
        clear_accum_out <= clear_accum; 
    end

    always_comb begin
        shift_out = accum;
    end

endmodule

//If DSP doesn't map, try AI:
    // always_ff @(posedge clk) begin
    //     if (shift_mode) begin
    //         accum <= shift_in;
    //     end else if (clear_accum) begin
    //         accum <= in_L * in_T; // Maps to DSP Multiplier + Clear ALU
    //     end else begin
    //         accum <= accum + (in_L * in_T); // Maps to full DSP MAC chain
    //     end
    // end