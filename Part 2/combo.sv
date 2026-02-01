module combo(
    input  logic MAX10_CLK1_50,
	input  logic [15:0] ARDUINO_IO,
    input  logic [9:0]  SW,    // Debug switches
    input  logic [1:0]  KEY,   // KEY[0]=enter pulse from keyboard, KEY[1]=hardware reset
    output logic [9:0]  LEDR,
    output logic [7:0]  HEX5,
    output logic [7:0]  HEX4,
    output logic [7:0]  HEX3,
    output logic [7:0]  HEX2,
    output logic [7:0]  HEX1,
    output logic [7:0]  HEX0
);

    logic [3:0] key_code;
    logic key_validn;
	 assign nreset = KEY[1];
	 
    // State-holding registers with initial values for a clean power-on start
    logic [23:0] PASSWORD = 24'hFFFFFF;
    logic [23:0] ATTEMPT = 24'h0;
    logic [2:0] digit_count = 3'b0;
    logic set_mode = 1'b1;
    typedef enum logic {UNLOCKED, LOCKED} lock_state_t;
    lock_state_t lock_state = UNLOCKED;

    // Synchronizer signals for all asynchronous input
    logic key_validn_sync1, key_validn_sync2;
    logic [3:0] key_code_sync1, key_code_sync2;

    logic [3:0] captured_key = 4'b0;
    logic new_key_event = 1'b0;
    typedef enum logic [1:0] {IDLE, CAPTURE, WAIT_RELEASE} capture_state_t;
    capture_state_t capture_state = IDLE;
    
    logic [6:0] hex5_segs, hex4_segs, hex3_segs, hex2_segs, hex1_segs, hex0_segs;

	// For debugging
    assign LEDR[2:0] = digit_count;
    assign LEDR[9:6] = captured_key;
    assign LEDR[3] = set_mode;
    assign LEDR[4] = (lock_state == LOCKED);
    
    // Connect to physical inputs
    assign key_code = ARDUINO_IO[11:8];
    assign key_validn = ~ARDUINO_IO[12]; 

    sevenseg dec5 ( .data(ATTEMPT[23:20]), .segments(hex5_segs) );
    sevenseg dec4 ( .data(ATTEMPT[19:16]), .segments(hex4_segs) );
    sevenseg dec3 ( .data(ATTEMPT[15:12]), .segments(hex3_segs) );
    sevenseg dec2 ( .data(ATTEMPT[11:8]),  .segments(hex2_segs) );
    sevenseg dec1 ( .data(ATTEMPT[7:4]),   .segments(hex1_segs) );
    sevenseg dec0 ( .data(ATTEMPT[3:0]),   .segments(hex0_segs) );
    
    always_comb begin
        if(digit_count == 0) begin
            if (lock_state == UNLOCKED) begin
                {HEX5, HEX4, HEX3, HEX2, HEX1, HEX0} = 48'hF7_C0_8C_86_AB_F7; // _OPEn_
            end else begin
                {HEX5, HEX4, HEX3, HEX2, HEX1, HEX0} = 48'hC7_C0_C6_89_86_C0; // LOCHED
            end 
		  end else begin
            HEX5 = 8'hFF; HEX4 = 8'hFF; HEX3 = 8'hFF;
            HEX2 = 8'hFF; HEX1 = 8'hFF; HEX0 = 8'hFF;
		  
            if (digit_count >= 1) HEX5 = {1'b1, hex5_segs};
            if (digit_count >= 2) HEX4 = {1'b1, hex4_segs};
            if (digit_count >= 3) HEX3 = {1'b1, hex3_segs};
            if (digit_count >= 4) HEX2 = {1'b1, hex2_segs};
            if (digit_count >= 5) HEX1 = {1'b1, hex1_segs};
            if (digit_count >= 6) HEX0 = {1'b1, hex0_segs};
        end
	 end

	 // Sync keypad
	 always_ff @(posedge MAX10_CLK1_50) begin
        // Synchronize keyboard inputs
        key_validn_sync1 <= key_validn;
        key_validn_sync2 <= key_validn_sync1;
        key_code_sync1   <= key_code;
        key_code_sync2   <= key_code_sync1;
    end

	 
	// CAPTURE FSM
    always_ff @(posedge MAX10_CLK1_50) begin
        if (nreset == 1'b0) begin // Reset is now synchronous
            capture_state <= IDLE;
            new_key_event <= 1'b0;
        end else begin
            new_key_event <= 1'b0; // Default assignment
            case (capture_state)
                IDLE: if (key_validn_sync2 == 1'b0) capture_state <= CAPTURE;
                CAPTURE: begin
                    captured_key <= key_code_sync2;
                    new_key_event <= 1'b1;
                    capture_state <= WAIT_RELEASE;
                end
                WAIT_RELEASE: if (key_validn_sync2 == 1'b1) capture_state <= IDLE;
                default: capture_state <= IDLE;
            endcase
        end
    end

    // Safe FSM
    always_ff @(posedge MAX10_CLK1_50) begin
        if (nreset == 1'b0) begin
            ATTEMPT <= 24'h0;
            digit_count <= 3'b0;
            set_mode <= 1'b1;
            lock_state <= UNLOCKED;
            PASSWORD <= 24'hFFFFFF;
        
		  end else if (new_key_event) begin
            case (captured_key)
                
					 4'hF: begin // '*' key: Reset attempt
                    ATTEMPT <= 24'h0;
                    digit_count <= 3'b0;
                end

                4'hE: begin // '#' key: Can be data OR an enter command
                    if (digit_count == 6) begin // Condition: Treat as ENTER
                        if (set_mode) 
								{PASSWORD, set_mode, lock_state} <= {ATTEMPT, 1'b0, LOCKED};
                        
								else if (ATTEMPT == PASSWORD) 
								{lock_state, set_mode} <= {UNLOCKED, 1'b1};
                        {ATTEMPT, digit_count} <= {24'h0, 3'b0};
                    end else if (digit_count < 6) begin // Condition: Treat as DATA
                        // Left-to-right display logic
                        case (digit_count)
                            3'd0: ATTEMPT <= {captured_key, 20'h0};
                            3'd1: ATTEMPT <= {ATTEMPT[23:20], captured_key, 16'h0};
                            3'd2: ATTEMPT <= {ATTEMPT[23:16], captured_key, 12'h0};
                            3'd3: ATTEMPT <= {ATTEMPT[23:12], captured_key, 8'h0};
                            3'd4: ATTEMPT <= {ATTEMPT[23:8], captured_key, 4'h0};
                            3'd5: ATTEMPT <= {ATTEMPT[23:4], captured_key};
                        endcase
                        digit_count <= digit_count + 1;
                    end
                end

                default: begin // Any other key is treated as data
                    if (digit_count < 6) begin
                       
                        case (digit_count)
                            3'd0: ATTEMPT <= {captured_key, 20'h0};
                            3'd1: ATTEMPT <= {ATTEMPT[23:20], captured_key, 16'h0};
                            3'd2: ATTEMPT <= {ATTEMPT[23:16], captured_key, 12'h0};
                            3'd3: ATTEMPT <= {ATTEMPT[23:12], captured_key, 8'h0};
                            3'd4: ATTEMPT <= {ATTEMPT[23:8], captured_key, 4'h0};
                            3'd5: ATTEMPT <= {ATTEMPT[23:4], captured_key};
                        endcase
                        digit_count <= digit_count + 1;
                    end
                end
            endcase
        end
    end

endmodule

module sevenseg	  ( input  logic [3:0] data,
							output logic [6:0] segments);
// Internal variables
	logic d3, d2, d1, d0;
	logic sg, sf, se, sd, sc, sb, sa;
// Assigning to make it eaisier to read
	assign d3 = data[3];
	assign d2 = data[2];
	assign d1 = data[1];
	assign d0 = data[0];
// Assign outputs using sum of products
	assign sg = (~d3 & ~d2 & ~d1) |
					(~d3 & d2 & d1 & d0);
	assign sf = (~d3 & ~d2 & d0) |
					(~d3 & d1 & d0) |
					(~d3 & ~d2 & d1 & ~d0) |
					(d3 & d2 & ~d1);
	assign se = (~d3 & d0) |
					(~d3 & d2 & ~d1 & ~d0) |
					(d3 & ~d2 & ~d1 & d0);
	assign sd = (~d2 & ~d1 & d0) |
					(~d3 & d2 & ~d1 & ~d0) |
					(d2 & d1 & d0) |
					(d3 & ~d2 & d1 & ~d0);
	assign sc = (~d3 & ~d2 & d1 & ~d0) |
					(d3 & d2 & ~d1 & ~d0) |
					(d3 & d2 & d1);
	assign sb = (~d3 & d2 & ~d1 & d0) |
					(d3 & d2 & ~d1 & ~d0) |
					(d2 & d1 & ~d0) |
					(d3 & d1 & d0);
	assign sa = 	(~d3 & ~d2 & ~d1 & d0) |
					(d2 & ~d1 & ~d0) |
					(d3 & d2 & ~d1) |
					(d3 & ~d2 & d1 & d0);
assign segments = {sg, sf, se, sd, sc, sb, sa};
endmodule