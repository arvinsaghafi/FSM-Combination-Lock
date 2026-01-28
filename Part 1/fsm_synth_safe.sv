module fsm_synth_safe(
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

    assign RESETN = ~KEY[0]; 
    assign ENTER  = ~KEY[1];

    function automatic [3:0] count_ones(input logic [9:0] x);
        count_ones = x[0]+x[1]+x[2]+x[3]+x[4]+x[5]+x[6]+x[7]+x[8]+x[9];
    endfunction

    localparam logic [47:0] OPEN   = 48'hF7_C0_8C_86_AB_F7; // _OPEn_
    localparam logic [47:0] LOCKED = 48'hC7_C0_C6_89_86_C0; // LOCHED

    fsm_synth fsm (
        .clk(MAX10_CLK1_50),
        .RESETN(RESETN),
        .ENTER(ENTER),
        .MATCH(ATTEMPT == PASSWORD),
        .savePW(savePW),
        .saveAT(saveAT),
        .isLocked(isLocked),
        .present_state(PRESENT_STATE)
    );

    always_ff @(posedge MAX10_CLK1_50 or posedge RESETN) begin
        if (RESETN) begin
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
        RESETN,
        savePW_r,
        SW,
        PASSWORD
    );

    flopren registerATTEMPT(
        MAX10_CLK1_50,
        RESETN,
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

module fsm_synth(
    input  logic        clk,
    input  logic        RESETN,
    input  logic        ENTER,
    input  logic        MATCH,
    output logic        savePW, 
    output logic        saveAT,
    output logic        isLocked,
    output logic [1:0]  present_state
);

    typedef enum logic [1:0] {OPEN, OPENING, LOCKED, LOCKING} statetype;
    statetype state, next_state;
    
    // State Register
    always_ff @(posedge clk, posedge RESETN)
        if (RESETN) state <= OPEN;
        else        state <= next_state;
    
    // Next State Logic
    always_comb begin
        next_state = state; 

        case (state)
            OPEN: 
                if (ENTER) next_state = LOCKING;
            
            OPENING: begin
                if (ENTER)      next_state = OPENING; // Wait for release
                else if (MATCH) next_state = OPEN;    // Check match on release
                else            next_state = LOCKED;
            end
            
            LOCKING:
                if (!ENTER) next_state = LOCKED; // Wait for release
                
            LOCKED:
                if (ENTER) next_state = OPENING;
                
            default: next_state = OPEN;
        endcase
    end
            
    // Output Logic
    always_comb begin
        savePW = 0; saveAT = 0; isLocked = 0;

        case (state)
            OPEN: begin    
                isLocked = 1'b0; 
                savePW = 1'b1; // Save PW while open
            end
            OPENING: begin 
                isLocked = 1'b1; 
                saveAT = 1'b1;
            end
            LOCKED: begin  
                isLocked = 1'b1; 
            end
            LOCKING: begin 
                isLocked = 1'b0; 
            end
            default: begin 
                isLocked = 1'b0; 
            end
        endcase
    end
    
    assign present_state = state;
endmodule