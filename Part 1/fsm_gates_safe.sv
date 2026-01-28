module fsm_gates_safe(
    input  logic        MAX10_CLK1_50,
    input  logic [9:0]  SW,
    input  logic [1:0]  KEY,
    output logic [7:0]  HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
    output logic [9:0]  LEDR
);

    logic RESETN, ENTER;
    logic isLocked;
    logic [9:0] PASSWORD, ATTEMPT;
    logic [1:0] PRESENT_STATE;
    logic [3:0] HINT;
    logic [47:0] hexDisplay;
    logic savePW, saveAT;
    logic savePW_r, saveAT_r;

    assign RESETN = KEY[0];
    assign ENTER  = ~KEY[1];

    function automatic [3:0] count_ones(input logic [9:0] x);
        count_ones = x[0]+x[1]+x[2]+x[3]+x[4]+x[5]+x[6]+x[7]+x[8]+x[9];
    endfunction

    localparam logic [47:0] OPEN   = 48'hF7_C0_8C_86_AB_F7; // _OPEn_
    localparam logic [47:0] LOCKED = 48'hC7_C0_C6_89_86_C0; // LOCHED

    fsm_gates fsm (
        .clk(MAX10_CLK1_50),
        .RESETN(RESETN),
        .ENTER(ENTER),
        .MATCH(ATTEMPT == PASSWORD),
        .savePW_out(savePW),
        .saveAT_out(saveAT),
        .isLocked_out(isLocked),
        .present_state(PRESENT_STATE)
    );

    always_ff @(posedge MAX10_CLK1_50 or negedge RESETN) begin
        if (!RESETN) begin
            savePW_r <= 1'b0;
            saveAT_r <= 1'b0;
        end 
        else begin
            savePW_r <= savePW;
            saveAT_r <= saveAT;
        end
    end

    flopren registerPASSWORD(
        MAX10_CLK1_50,
        !RESETN,
        savePW_r,
        SW,
        PASSWORD
    );

    flopren registerATTEMPT(
        MAX10_CLK1_50,
        !RESETN,
        saveAT_r,
        SW,
        ATTEMPT
    );

    always_comb begin
    
        logic match_comb;
        match_comb = (ATTEMPT == PASSWORD);

        HINT = count_ones(SW ^ PASSWORD);

        if (isLocked)
            hexDisplay = LOCKED;
        else
            hexDisplay = OPEN;

        {HEX5,HEX4,HEX3,HEX2,HEX1,HEX0} = hexDisplay;
        LEDR[3:0] = HINT;
        LEDR[8:4] = 5'b0;
        LEDR[9:8] = PRESENT_STATE;
        LEDR[7]   = ENTER;
        LEDR[6]   = match_comb;
    end

endmodule

module flopren(
    input  logic       clk,
    input  logic       reset,
    input  logic       en,
    input  logic [9:0] d,
    output logic [9:0] q
);
    always_ff @(posedge clk)
        if (reset) q <= 10'b0;
        else if (en) q <= d;
endmodule

module fsm_gates(
    input  logic        clk,
    input  logic        RESETN,
    input  logic        ENTER,
    input  logic        MATCH,
    output logic        savePW_out, 
    output logic        saveAT_out,
    output logic        isLocked_out,
    output logic [1:0]  present_state
);

    logic [1:0] next_state;
    // s1 = MSB, s0 = LSB
    logic s1, s0;
    
    assign s1 = present_state[1];
    assign s0 = present_state[0];

	// Output Logic
    assign savePW_out = (~s1 & ~s0); // savePW is active only in OPEN (00)
    assign saveAT_out = (s1 & s0); 	 // saveAT is active only in OPENING (11)
    assign isLocked_out = s1; 		 // isLocked is active in LOCKED (10) and OPENING (11)


	// Next State Logic
    assign next_state[0] = ENTER; // n0 is high whenever ENTER is pressed

    // Karnaugh Map:
    // (s1 & ~s0):          Stays in LOCKED (10) or moves to OPENING (11).
    // (~s1 & s0 & ~ENTER): Moves from LOCKING (01) to LOCKED (10) on release.
    // (s1 & s0 & ENTER):   Holds in OPENING (11) while button pressed.
    // (s1 & s0 & ~MATCH):  Moves from OPENING (11) to LOCKED (10) on fail.
    assign next_state[1] = (s1 & ~s0) | 
                           (~s1 & s0 & ~ENTER) | 
                           (s1 & s0 & (ENTER | ~MATCH));


	// State Register
    always_ff @(posedge clk) begin
        if (!RESETN)
            present_state <= 2'b00; // Reset to OPEN
        else
            present_state <= next_state;
    end
endmodule