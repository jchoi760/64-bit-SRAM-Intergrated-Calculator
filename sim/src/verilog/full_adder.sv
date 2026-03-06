/*
* Module describing a single-bit full adder. 
* The full adder can be chained to create multi-bit adders. 
*
* This module can be modified but the interface must remain the same.
*/
module full_adder (
    // DO NOT CHANGE THESE PORTS
    input logic a,
    input logic b,
    input logic cin,
    output logic s,
    output logic cout
);

    // a + b + cin produces 2-bit result (0-3), {cout, s} maps MSB to cout, LSB to s -Josh
    // Truth table: a=b=cin=0 → 0, a=b=1,cin=0 → 2 (cout=1,s=0), a=b=cin=1 → 3 (cout=1,s=1) -Josh
    assign {cout, s} = a + b + cin;
    
endmodule