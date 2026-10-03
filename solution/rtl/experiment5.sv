/*
Copyright by Henry Ko and Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`ifndef DISABLE_DEFAULT_NET
`default_nettype none
`endif

// This is the top module
// It connects the PS2 controller and the LCD controller
// It first stores the typed keys onto 16 data registers
// When the data registers are full, it will update one complete LCD line
module experiment5 (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// switches                          ////////////
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs
		output logic[17:0] LED_RED_O,             // 18 red LEDs
		
		/////// PS2                               ////////////
		input logic PS2_DATA_I,                   // PS2 data
		input logic PS2_CLOCK_I,                  // PS2 clock

		/////// LCD display                       ////////////
		output logic LCD_POWER_O,                 // LCD power ON/OFF
		output logic LCD_BACK_LIGHT_O,            // LCD back light ON/OFF
		output logic LCD_READ_WRITE_O,            // LCD read/write select, 0 = Write, 1 = Read
		output logic LCD_EN_O,                    // LCD enable
		output logic LCD_COMMAND_DATA_O,          // LCD command/data select, 0 = Command, 1 = Data
		output [7:0] LCD_DATA_IO                  // LCD data bus 8 bits
);

parameter MAX_LCD_delay_count = 18'h3FFFF;

logic resetn;

enum logic [2:0] {
	S_LCD_INIT,
	S_LCD_INIT_WAIT,
	S_IDLE,
	S_LCD_WAIT_ROM_UPDATE,
	S_LCD_ISSUE_INSTRUCTION,
	S_LCD_FINISH_INSTRUCTION,
	S_LCD_ISSUE_CHANGE_LINE,
	S_LCD_FINISH_CHANGE_LINE
} state;

logic [3:0] data_counter;
// Bit 8 selects the ROM case half; bits 7 through 0 store the PS2 code.
// Storing both preserves each letter's case through later Shift presses.
logic [8:0] data_reg [15:0];

logic [7:0] PS2_code;
logic PS2_code_ready, PS2_code_ready_buf;
logic PS2_make_code;
logic shift_status, display_en;
logic previous_is_digit, previous_is_letter;
logic PS2_code_is_digit, PS2_code_is_letter;
logic [3:0] pair_count;

logic [2:0] LCD_init_index;
logic [8:0] LCD_init_sequence;
logic [8:0] LCD_instruction;
logic [7:0] LCD_code;
logic LCD_line;

logic LCD_start;
logic LCD_done;

logic [6:0] value_7_segment[1:0];

assign resetn = ~SWITCH_I[17];

// PS2 unit
PS2_controller PS2_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	
	.PS2_clock(PS2_CLOCK_I),
	.PS2_data(PS2_DATA_I),
	
	.PS2_code(PS2_code),
	.PS2_code_ready(PS2_code_ready),
	.PS2_make_code(PS2_make_code)
);

// ROM for translate PS2 code to LCD code
// PS2_to_LCD_ROM.mif keeps lowercase letters in 000h-0FFh and adds
// uppercase letters in 100h-1FFh. Number-row digit codes were added
// to both halves, with the same LCD codes in either case.
PS2_to_LCD_ROM	PS2_to_LCD_ROM_inst (
	.address ( data_reg[15] ),
	.clock ( CLOCK_50_I ),
	.q ( LCD_code )
	);

// LCD unit
LCD_controller #( 
	.MAX_LCD_delay_count(MAX_LCD_delay_count-1)) 
	LCD_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.LCD_start(LCD_start),
	.LCD_instruction(LCD_instruction),
	.LCD_done(LCD_done),
	
	// LCD side
	.LCD_power(LCD_POWER_O),
	.LCD_back_light(LCD_BACK_LIGHT_O),
	.LCD_read_write(LCD_READ_WRITE_O),
	.LCD_enable(LCD_EN_O),
	.LCD_command_data_select(LCD_COMMAND_DATA_O),
	.LCD_data_io(LCD_DATA_IO)
);

always_ff @ (posedge CLOCK_50_I or negedge resetn) begin
	if (resetn == 1'b0) begin
		state <= S_LCD_INIT;
		LCD_init_index <= 3'd0;
		LCD_start <= 1'b0;
		LCD_instruction <= 9'd0;
		LCD_line <= 1'b0;
		PS2_code_ready_buf <= 1'b0;
		data_counter <= 4'd0;
		data_reg[15] <= 9'h000;
		data_reg[14] <= 9'h000;
		data_reg[13] <= 9'h000;
		data_reg[12] <= 9'h000;
		data_reg[11] <= 9'h000;
		data_reg[10] <= 9'h000;
		data_reg[9] <= 9'h000;
		data_reg[8] <= 9'h000;
		data_reg[7] <= 9'h000;
		data_reg[6] <= 9'h000;
		data_reg[5] <= 9'h000;
		data_reg[4] <= 9'h000;
		data_reg[3] <= 9'h000;
		data_reg[2] <= 9'h000;
		data_reg[1] <= 9'h000;
		data_reg[0] <= 9'h000;
		shift_status <= 1'b0;
		display_en <= 1'b0;
		previous_is_digit <= 1'b0;
		previous_is_letter <= 1'b0;
		pair_count <= 4'd0;
	end else begin

		PS2_code_ready_buf <= PS2_code_ready;

		case (state)
		
		S_LCD_INIT: begin
			// Initialize LCD
			///////////////////
			// DO NOT CHANGE //
			///////////////////
			LCD_instruction <= LCD_init_sequence;
			LCD_start <= 1'b1;
			state <= S_LCD_INIT_WAIT;
		end
		
		S_LCD_INIT_WAIT: begin
			///////////////////
			// DO NOT CHANGE //
			///////////////////
			if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin
				if (LCD_done == 1'b1) begin
					LCD_init_index <= LCD_init_index + 3'd1;
					if (LCD_init_index < 3'd4) begin
						state <= S_LCD_INIT;
					end else begin
						// Finish initializing LCD
						state <= S_IDLE;
					end
				end
			end
		end
		
		S_IDLE: begin
			// New PS2 code arrived
			if (PS2_code_ready && ~PS2_code_ready_buf && PS2_make_code) begin
				// Handle Shift keys without storing a character
				// Shift also preserves the pair count, its display, and the previous
				// character's flags, so it does not break a displayed pair.
				if (PS2_code == 8'h12) begin
					shift_status <= 1'b1; // Left Shift selects uppercase.
				end else if (PS2_code == 8'h59) begin
					shift_status <= 1'b0; // Right Shift selects lowercase.
				end else begin
					// Hide the previous result while assembling a new line
					display_en <= 1'b0;

					// Count qualifying pairs as each new character arrives
					// Clearing at position 0 has priority in the count input mux,
					// preventing a pair across two lines. Other positions compare
					// the previous character with the current one; no match holds the count.
					if (data_counter == 4'd0) begin
						pair_count <= 4'd0;
					end else if ((LCD_line == 1'b0) &&
						(previous_is_letter && PS2_code_is_digit)) begin
						// Top LCD line: count a letter followed by a digit.
						pair_count <= pair_count + 4'd1;
					end else if ((LCD_line == 1'b1) &&
						(previous_is_digit && PS2_code_is_letter)) begin
						// Bottom LCD line: count a digit followed by a letter.
						pair_count <= pair_count + 4'd1;
					end
					// These registers describe the preceding character at the next input.
					// A space clears both flags, excluding both pairs adjacent to it.
					previous_is_digit <= PS2_code_is_digit;
					previous_is_letter <= PS2_code_is_letter;

					// Shift the register contents to make room for the new character
					data_reg[15] <= data_reg[14];
					data_reg[14] <= data_reg[13];
					data_reg[13] <= data_reg[12];
					data_reg[12] <= data_reg[11];
					data_reg[11] <= data_reg[10];
					data_reg[10] <= data_reg[9];
					data_reg[9] <= data_reg[8];
					data_reg[8] <= data_reg[7];
					data_reg[7] <= data_reg[6];
					data_reg[6] <= data_reg[5];
					data_reg[5] <= data_reg[4];
					data_reg[4] <= data_reg[3];
					data_reg[3] <= data_reg[2];
					data_reg[2] <= data_reg[1];
					data_reg[1] <= data_reg[0];
					// Letters and digits keep their PS2 code and selected case; other
					// non-Shift keys occupy one position as a space (PS2 code 8'h29).
					if (PS2_code_is_digit || PS2_code_is_letter) begin
						data_reg[0] <= {shift_status, PS2_code};
					end else begin
						data_reg[0] <= {1'b0, 8'h29};
					end

					// Advance the data counter
					data_counter <= data_counter + 4'd1;

					// Send the complete line to the LCD
					if (data_counter == 4'd15) begin
						data_counter <= 4'd0;
						state <= S_LCD_WAIT_ROM_UPDATE;
					end
				end
			end
		end
		
		S_LCD_WAIT_ROM_UPDATE: begin
			// One clock cycle to wait for ROM to update its output
			state <= S_LCD_ISSUE_INSTRUCTION;
		end
		
		S_LCD_ISSUE_INSTRUCTION: begin
			// Load translated LCD code to LCD instruction from the ROM
			LCD_instruction <= {1'b1, LCD_code};
			LCD_start <= 1'b1;
			state <= S_LCD_FINISH_INSTRUCTION;
		end
		
		S_LCD_FINISH_INSTRUCTION: begin
			if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin	
				if (LCD_done == 1'b1) begin
					if (data_counter < 4'd15) begin
						data_counter <= data_counter + 4'd1;
						state <= S_LCD_WAIT_ROM_UPDATE;
					end else begin
						data_counter <= 4'd0;
						state <= S_LCD_ISSUE_CHANGE_LINE;
					end
					data_reg[15] <= data_reg[14];
					data_reg[14] <= data_reg[13];
					data_reg[13] <= data_reg[12];
					data_reg[12] <= data_reg[11];
					data_reg[11] <= data_reg[10];
					data_reg[10] <= data_reg[9];
					data_reg[9] <= data_reg[8];
					data_reg[8] <= data_reg[7];
					data_reg[7] <= data_reg[6];
					data_reg[6] <= data_reg[5];
					data_reg[5] <= data_reg[4];
					data_reg[4] <= data_reg[3];
					data_reg[3] <= data_reg[2];
					data_reg[2] <= data_reg[1];
					data_reg[1] <= data_reg[0];
					data_reg[0] <= 9'h000;
				end
			end
		end
		
		S_LCD_ISSUE_CHANGE_LINE: begin
			// Change line
			LCD_instruction <= {2'b01, ~LCD_line, 6'h00};
			LCD_line <= ~LCD_line;
			LCD_start <= 1'b1;
			state <= S_LCD_FINISH_CHANGE_LINE;
		end
		
		S_LCD_FINISH_CHANGE_LINE: begin
			if (LCD_start == 1'b1) begin
				LCD_start <= 1'b0;
			end else begin	
				if (LCD_done == 1'b1) begin
					state <= S_IDLE;
					// Turn on the display enable in between lines
					display_en <= 1'b1;
				end
			end
		end
		
		default: state <= S_LCD_INIT;
		
		endcase
	end
end

// Initialization sequence for LCD
///////////////////
// DO NOT CHANGE //
///////////////////
always_comb begin
	case(LCD_init_index)
	0:       LCD_init_sequence	=	9'h038; // Set display to be 8 bit and 2 lines
	1:       LCD_init_sequence	=	9'h00C; // Set display
	2:       LCD_init_sequence	=	9'h001; // Clear display
	3:       LCD_init_sequence	=	9'h006; // Enter entry mode
	default: LCD_init_sequence	=	9'h080; // Set starting position to 0
	endcase
end

// Classify the PS2 code as a digit, a letter, or neither
// PS2 codes are not consecutive, so letters and digits need separate decodes.
// The default assignments ensure combinational logic is synthesized.
always_comb begin
	PS2_code_is_digit = 1'b0;
	PS2_code_is_letter = 1'b0;
	case (PS2_code)
	8'h45: PS2_code_is_digit  = 1'b1; // Key 0
	8'h16: PS2_code_is_digit  = 1'b1; // Key 1
	8'h1E: PS2_code_is_digit  = 1'b1; // Key 2
	8'h26: PS2_code_is_digit  = 1'b1; // Key 3
	8'h25: PS2_code_is_digit  = 1'b1; // Key 4
	8'h2E: PS2_code_is_digit  = 1'b1; // Key 5
	8'h36: PS2_code_is_digit  = 1'b1; // Key 6
	8'h3D: PS2_code_is_digit  = 1'b1; // Key 7
	8'h3E: PS2_code_is_digit  = 1'b1; // Key 8
	8'h46: PS2_code_is_digit  = 1'b1; // Key 9
	8'h1C: PS2_code_is_letter = 1'b1; // Key A
	8'h32: PS2_code_is_letter = 1'b1; // Key B
	8'h21: PS2_code_is_letter = 1'b1; // Key C
	8'h23: PS2_code_is_letter = 1'b1; // Key D
	8'h24: PS2_code_is_letter = 1'b1; // Key E
	8'h2B: PS2_code_is_letter = 1'b1; // Key F
	8'h34: PS2_code_is_letter = 1'b1; // Key G
	8'h33: PS2_code_is_letter = 1'b1; // Key H
	8'h43: PS2_code_is_letter = 1'b1; // Key I
	8'h3B: PS2_code_is_letter = 1'b1; // Key J
	8'h42: PS2_code_is_letter = 1'b1; // Key K
	8'h4B: PS2_code_is_letter = 1'b1; // Key L
	8'h3A: PS2_code_is_letter = 1'b1; // Key M
	8'h31: PS2_code_is_letter = 1'b1; // Key N
	8'h44: PS2_code_is_letter = 1'b1; // Key O
	8'h4D: PS2_code_is_letter = 1'b1; // Key P
	8'h15: PS2_code_is_letter = 1'b1; // Key Q
	8'h2D: PS2_code_is_letter = 1'b1; // Key R
	8'h1B: PS2_code_is_letter = 1'b1; // Key S
	8'h2C: PS2_code_is_letter = 1'b1; // Key T
	8'h3C: PS2_code_is_letter = 1'b1; // Key U
	8'h2A: PS2_code_is_letter = 1'b1; // Key V
	8'h1D: PS2_code_is_letter = 1'b1; // Key W
	8'h22: PS2_code_is_letter = 1'b1; // Key X
	8'h35: PS2_code_is_letter = 1'b1; // Key Y
	8'h1A: PS2_code_is_letter = 1'b1; // Key Z
	default: begin
		PS2_code_is_digit = 1'b0;
		PS2_code_is_letter = 1'b0;
	end
	endcase
end

// Active-low segments are off at 7'h7f; display_en selects the completed count.
// SEVEN_SEGMENT_N_O[4] shows data_counter for debugging during line assembly.
convert_hex_to_seven_segment unit1 (
	.hex_value(data_counter), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(pair_count), 
	.converted_value(value_7_segment[0])
);

assign	SEVEN_SEGMENT_N_O[0] = (display_en) ? value_7_segment[0] : 7'h7f,
		SEVEN_SEGMENT_N_O[1] = 7'h7f,
		SEVEN_SEGMENT_N_O[2] = 7'h7f,
		SEVEN_SEGMENT_N_O[3] = 7'h7f,
		SEVEN_SEGMENT_N_O[4] = (!display_en) ? value_7_segment[1] : 7'h7f,
		SEVEN_SEGMENT_N_O[5] = 7'h7f,
		SEVEN_SEGMENT_N_O[6] = 7'h7f,
		SEVEN_SEGMENT_N_O[7] = 7'h7f;
		
assign LED_GREEN_O = 9'd0;
assign LED_RED_O = 18'd0;

endmodule
