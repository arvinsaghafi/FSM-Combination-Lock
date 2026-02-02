module keyboard(
	input  logic  	    MAX10_CLK1_50,
	input  logic [1:0] KEY,
	inout  logic [15:0] ARDUINO_IO,
	input  logic [7:0] SW,
	output logic [9:0] LEDR,
	output logic [7:0] HEX5,HEX4,HEX3,HEX2,HEX1,HEX0
);
	
	wire [3:0] row_wires;
	wire [3:0] col_wires;
	
	// ARDUINO_IO[7:4] = Row Wires (Output from FPGA)
	// ARDUINO_IO[3:0] = Col Wires (Input to FPGA)
	assign ARDUINO_IO[7:4] = row_wires; 
	assign col_wires       = ARDUINO_IO[3:0];
	
	logic [3:0] row_scan;
	logic [3:0] key_code;
	logic [3:0] row;
	logic [3:0] col;
	logic       valid;
	logic       debounceOK;
	logic       clk;
	logic       rst;
	
	assign clk = MAX10_CLK1_50;
	assign rst = ~KEY[0]; // Active high reset
	
	// Debug LEDs
	assign LEDR[9]   = valid;
    assign LEDR[8]   = debounceOK;
    assign LEDR[7:4] = ~row;
    assign LEDR[3:0] = ~col;

	// Inter-board communication Logic
	// combo.sv reads: assign key_code = ARDUINO_IO[11:8]
	assign ARDUINO_IO[11:8] = key_code;
	
	// combo.sv reads: assign key_validn = ~ARDUINO_IO[12];
	// To signal "valid" (active low validn), output HIGH on IO[12]
	assign ARDUINO_IO[12]   = valid; 

	kb_db keyboard_debounce(
		.clk(clk),
		.rst(rst),
		.row_wires(row_wires),
		.col_wires(col_wires),
		.row_scan(row_scan),
		.row(row), 
		.col(col),
		.valid(valid),
		.debounceOK(debounceOK)
	);
	
	keyboard_fsm fsm(
		.clk(clk),
		.rst(rst),
		.valid(valid),
		.col(col),
		.row_scan(row_scan)
	);

	// Instantiate the decoder to convert {row, col} to 4-bit hex
	key_decode decoder (
		.data({row, col}),
		.key_code(key_code)
	);

	// Display Logic: Shift Register for last 6 presses
	logic valid_delayed;
	logic [6:0] current_hex_seg;
	
	// Get 7-seg representation of current key
	sevenseg s_curr (.data(key_code), .segments(current_hex_seg));

	always_ff @(posedge clk) begin
		if (rst) begin
			HEX5 <= 8'b1111_1111;
			HEX4 <= 8'b1111_1111;
			HEX3 <= 8'b1111_1111;
			HEX2 <= 8'b1111_1111;
			HEX1 <= 8'b1111_1111;
			HEX0 <= 8'b1111_1111;
			valid_delayed <= 1'b0;
		end
		else begin
			valid_delayed <= valid;
			// Shift on Rising Edge of valid (New press)
			if (valid && !valid_delayed) begin
				HEX5 <= HEX4;
				HEX4 <= HEX3;
				HEX3 <= HEX2;
				HEX2 <= HEX1;
				HEX1 <= HEX0;
				HEX0 <= {1'b1, current_hex_seg};
			end
		end
	end
	
endmodule


module keyboard_fsm(
	input  logic 		 clk,
	input  logic 		 rst,
	input	 logic		 valid,
	input  logic [3:0] col,
	output logic [3:0] row_scan
);
	typedef enum logic [2:0] {ROW_ONE, ROW_TWO, ROW_THREE, ROW_FOUR} statetype;
	statetype present_state, next_state;
	
	// Timer to slow down scanning
	// kb_db requires stable row for ~1.3ms (2^16 cycles)
	// Use 200,000 cycles (~4ms) to be safe.
	logic [19:0] scan_timer;
	localparam SCAN_DELAY = 200000;

	// State register
	always_ff @(posedge clk, posedge rst) begin
		if (rst) begin
			present_state <= ROW_ONE;
			scan_timer <= SCAN_DELAY;
		end
		else begin
			// If a key is valid, stop scanning
			// This holds the row constant so kb_db maintains the 'valid' signal
			if (valid) begin
				present_state <= present_state;
				// Keep timer ready to count down once key is released
				scan_timer <= SCAN_DELAY; 
			end
			else begin
				if (scan_timer == 0) begin
					present_state <= next_state;
					scan_timer <= SCAN_DELAY; // Reset timer
				end
				else begin
					scan_timer <= scan_timer - 1;
					present_state <= present_state;
				end
			end
		end
	end
	
	// Next state logic
	always_comb begin
		case (present_state)
			ROW_ONE:   next_state = ROW_TWO;
			ROW_TWO:   next_state = ROW_THREE;
			ROW_THREE: next_state = ROW_FOUR;
			ROW_FOUR:  next_state = ROW_ONE;
			default:   next_state = ROW_ONE;
		endcase
	end
	
	// Output logic
	always_comb begin
		case (present_state)
			ROW_ONE: begin // Row 1 (Top)
				row_scan = 4'b1110;
				row_scan = 4'b0111;
			end
			ROW_TWO: begin
				row_scan = 4'b1011; // Row 2
			end
			ROW_THREE: begin
				row_scan = 4'b1101; // Row 3
			end
			ROW_FOUR: begin
				row_scan = 4'b1110; // Row 4 (Bottom)
			end
			default: row_scan = 4'b1111;
		endcase
	end
endmodule


module sevenseg(
	input  logic [3:0] data,
	output logic [6:0] segments
);
	always_comb
	case (data)
		// gfe_dcba
		4'h0:    segments = 7'b100_0000;
		4'h1:    segments = 7'b111_1001;
		4'h2:    segments = 7'b010_0100;
		4'h3:    segments = 7'b011_0000;
		4'h4:    segments = 7'b001_1001;
		4'h5:    segments = 7'b001_0010;
		4'h6:    segments = 7'b000_0010;
		4'h7:    segments = 7'b111_1000;
		4'h8:    segments = 7'b000_0000;
		4'h9:    segments = 7'b001_1000;
		4'hA:    segments = 7'b000_1000;
		4'hB:    segments = 7'b000_0011;
		4'hC:    segments = 7'b010_0111;
		4'hD:    segments = 7'b010_0001;
		4'hE:    segments = 7'b000_0110;
		4'hF:    segments = 7'b000_1110;
		default: segments = 7'b111_1111;
	endcase
endmodule

module key_decode(input logic [7:0] data, output logic [3:0] key_code);
	// Decodes the concatenated {row, col} scan code into hex key_code
	// Rows/Cols are active low (0 indicated selection)
	always_comb begin
		case(data)
			8'b0111_1110:	key_code = 4'hA;
			8'b0111_1101:	key_code = 4'h3;
			8'b0111_1011:	key_code = 4'h2;
			8'b0111_0111:	key_code = 4'h1;
			
			8'b1011_1110:	key_code = 4'hB;
			8'b1011_1101:	key_code = 4'h6;
			8'b1011_1011:	key_code = 4'h5;
			8'b1011_0111:	key_code = 4'h4;
			
			8'b1101_1110:	key_code = 4'hC;
			8'b1101_1101:	key_code = 4'h9;
			8'b1101_1011:	key_code = 4'h8;
			8'b1101_0111:	key_code = 4'h7;
			
			8'b1110_1110:	key_code = 4'hD;
			8'b1110_1101:	key_code = 4'hE; // '#'
			8'b1110_1011:	key_code = 4'h0;
			8'b1110_0111:	key_code = 4'hF; // '*'
			default:		key_code = 4'h0;
		endcase
	end
endmodule

module kb_db #( DELAY=16 ) (
	input  logic 		 clk,
	input  logic 		 rst,
	inout  wire  [3:0] row_wires, 
	inout  wire  [3:0] col_wires, 
	input  logic [3:0] row_scan,
	output logic [3:0] row,
	output logic [3:0] col,
	output logic 		 valid,
	output logic 		 debounceOK
);
	logic [3:0] col_F1, col_F2;
	logic [3:0] row_F1, row_F2;
	logic pressed, row_change, col_change;

	assign row_wires = row_scan;
	assign pressed = ~&( col_F2 );
	assign col_change = pressed ^ pressed_sync;
	assign row_change = |(row_scan ^ row_F1);
	logic [3:0] row_sync, col_sync;
	logic pressed_sync;
	
	// Synchronizer
	always_ff @( posedge clk ) begin
		row_F1   <= row_scan; 	col_F1 <= col_wires;
		row_F2   <= row_F1; 		col_F2 <= col_F1;
		row_sync <= row_F2; 		col_sync <= col_F2;
		//
		pressed_sync <= pressed;
	end
	
	// Final retiming flip-flops
	// Ensure row/col/valid appear together at the same time
	always_ff @( posedge clk ) begin
		valid <= debounceOK & pressed_sync;
		if( debounceOK & pressed_sync ) begin
			row <= row_sync;
			col <= col_sync;
		end else begin
			row <= 0;
			col <= 0;
		end
	end
	
	// Debounce counter
	logic [DELAY:0] counter;
	initial counter = 0;
		always_ff @( posedge clk ) begin
		if( rst | row_change | col_change ) begin
			counter <= 0;
		end else if( !debounceOK ) begin
			counter <= counter+1;
		end
	end
	
	assign debounceOK = counter[DELAY];
	
endmodule