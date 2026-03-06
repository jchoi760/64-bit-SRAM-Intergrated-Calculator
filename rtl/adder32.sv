/*
* Module describing a 32-bit ripple carry adder, with no carry output or input.
*
* You can and should modify this file but do NOT change the interface.
*/
module adder32 import calculator_pkg::*; (
    // DO NOT MODIFY THE PORTs
    input logic [DATA_W - 1 : 0]    a_i, // First operand
    input logic [DATA_W - 1 : 0]    b_i, // Second operand
    input logic                     c_i, // Carry input
    output logic                    c_o, // Carry output
    output logic [DATA_W - 1 : 0]   sum_o // Sum output
);
    // You can modify anything below this line. You are required to use
    // full_adder.sv to build this module.
    
    // Internal carry chain: carry[0] is c_i, carry[32] is c_o
    logic [DATA_W:0] carry;
    
    // Connect external carry input to first carry
    assign carry[0] = c_i;
    // Connect last carry to external carry output
    assign c_o = carry[DATA_W];

    // Generate block for building the large adder out of smaller, full adders
    generate
        genvar i;
        for (i = 0; i < DATA_W; i = i + 1) begin : gen_full_adders
            full_adder fa_inst (
                .a      (a_i[i]),
                .b      (b_i[i]),
                .cin    (carry[i]),
                .s      (sum_o[i]),
                .cout   (carry[i+1])
            );
        end
    endgenerate
endmodule