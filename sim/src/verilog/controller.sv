/* 
 *	Controller module for DD onboarding.
 *	Manages reading from memory, performing additions, and writing results back to memory.
 *
 *	This module can and should be modified but do not change the interface.
*/
module controller import calculator_pkg::*;(
	// DO NOT MODIFY THESE PORTS
  	input  logic              clk_i,
    input  logic              rst_i,
  
  	// Memory Access
    input  logic [ADDR_W-1:0] read_start_addr,
    input  logic [ADDR_W-1:0] read_end_addr,
    input  logic [ADDR_W-1:0] write_start_addr,
    input  logic [ADDR_W-1:0] write_end_addr,
  
  	// Memory Controls
    output logic 						write,
	output logic 						read,
    output logic [ADDR_W-1:0]			w_addr,
    output logic [MEM_WORD_SIZE-1:0]	w_data,
    output logic [ADDR_W-1:0]			r_addr,
    input  logic [MEM_WORD_SIZE-1:0]	r_data,

  	// Buffer Control (1 = upper, 0, = lower)
    output logic buffer_control,
  
  	// These go into adder
  	output logic [DATA_W-1:0] op_a,
    output logic [DATA_W-1:0] op_b,

	// Carry input for adder
	output logic carry_in,	// Carry input to adder
	input  logic carry_out, // Carry output from adder
	
	// What is being stored in the buffer
    input  logic [MEM_WORD_SIZE-1:0] buff_result
  
); 

	// DO NOT MODIFY THIS BLOCK: Count how many cycles the controller has been active
	logic [31:0] cycle_count;
	always_ff @(posedge clk_i) begin
		if (rst_i)
			cycle_count <= 32'd0;
		else
			cycle_count <= cycle_count + 1'b1;
	end
	//=========================================================================
	// You can change anything below this line. There is a skeleton but feel
	// free to modify as much as you want.
	//=========================================================================

	// Declare state machine states
    state_t state, next;

	// Registers to hold read data for current and next reads
	logic [ADDR_W-1:0] r_ptr, w_ptr;
	
	// Registers to hold the two operands read from memory -Josh
	logic [MEM_WORD_SIZE-1:0] operand_a_reg;  // First 64-bit operand -Josh
	logic [MEM_WORD_SIZE-1:0] operand_b_reg;  // Second 64-bit operand -Josh
	
	// Register to store carry from lower 32-bit addition -Josh
	logic carry_reg;

	// State register -Josh
	always_ff @(posedge clk_i) begin
		if (rst_i)
			state <= S_IDLE;
		else
			state <= next;
	end

	// Next state logic -Josh
	always_comb begin
		case (state)
			S_IDLE:      next = S_READ;   // Post-reset, wait for signals to settle -Josh
			S_READ:      next = S_READ2;  // Read first address -Josh
			S_READ2:     next = S_ADD;    // Read second address -Josh
			S_ADD:       next = S_ADD2;   // Add upper half of word -Josh
			S_ADD2:      next = S_WRITE;  // Buffer result of first addition, add lower half, wait for lower half to be buffered -Josh
			S_WRITE: begin
				// Write result, check if done -Josh
				if (w_ptr >= write_end_addr)
					next = S_END;
				else
					next = S_READ;  // Loop back for next pair -Josh
			end
			S_END:       next = S_END;    // All done -Josh
			default:     next = S_IDLE;
		endcase
	end

	// Sequential logic: update pointers and latch data -Josh - 
	always_ff @(posedge clk_i) begin
		if (rst_i) begin
			r_ptr <= read_start_addr;
			w_ptr <= write_start_addr;
			operand_a_reg <= '0;
			operand_b_reg <= '0;
			carry_reg <= 1'b0;
		end
		else begin
			case (state)
				S_IDLE: begin
					r_ptr <= read_start_addr;
					w_ptr <= write_start_addr;
				end
				S_READ: begin
					// Read is issued this cycle, data will be available next cycle -Josh
					r_ptr <= r_ptr + 1'b1;  // Increment to read second operand -Josh
				end
				S_READ2: begin
					// Latch first operand (read data from S_READ) -Josh
					operand_a_reg <= r_data;
					r_ptr <= r_ptr + 1'b1;  // Increment for next pair -Josh
				end
			S_ADD: begin
				// Latch second operand (read data from S_READ2)
				// Save carry from lower 32-bit add (happening this cycle)
				operand_b_reg <= r_data;
				carry_reg <= carry_out;  // Save carry from lower addition
			end
			S_ADD2: begin
				// Upper addition happening this cycle, nothing to latch
			end
				S_WRITE: begin
					// Write complete, increment write pointer -Josh
					w_ptr <= w_ptr + 1'b1;
				end
				S_END: begin
					// Stay in end state -Josh
				end
				default: begin
					// Do nothing
				end
			endcase
		end
	end


	// Combinational output logic -Josh
	always_comb begin
        // Default values -Josh
			write = 1'b0;
        	read = 1'b0;
			r_addr = r_ptr;
			w_addr = w_ptr;
			w_data = buff_result;
			buffer_control = LOWER;  // Default to lower -Josh
			op_a = '0;
			op_b = '0;
			carry_in = 1'b0;	
        case (state)  
            S_IDLE: begin

                // Initialize - do nothing -Josh
            end
            S_READ: begin
                // Read first operand -Josh
                read = 1'b1;
				r_addr = r_ptr;
            end
			S_READ2: begin
				// Read second operand -Josh
				read = 1'b1;
				r_addr = r_ptr;
			end
            S_ADD: begin
				// Add LOWER half of word FIRST
				op_a = operand_a_reg[DATA_W-1:0];      // Lower 32 bits of first operand
				op_b = r_data[DATA_W-1:0];             // Lower 32 bits of second operand
				carry_in = 1'b0;                        // No carry in for lower half
				buffer_control = LOWER;                 // Store result in lower half of buffer
            end
			S_ADD2: begin
				// Add UPPER half WITH carry from lower addition
				op_a = operand_a_reg[MEM_WORD_SIZE-1:DATA_W];  // Upper 32 bits of first operand
				op_b = operand_b_reg[MEM_WORD_SIZE-1:DATA_W];  // Upper 32 bits of second operand
				carry_in = carry_reg;                          // USE carry from lower addition
				buffer_control = UPPER;                        // Store result in upper half of buffer
			end
			S_WRITE: begin
				// Write 64-bit result to SRAM -Josh
				write = 1'b1;
				w_addr = w_ptr;
				w_data = buff_result;
			end
            S_END: begin
                // Done - do nothing -Josh
            end
			default: begin
				// Default case -Josh
			end
        endcase
    end

	
  endmodule
