module shift_register_8bit (
    input logic clk,
    input logic data_in,
    output logic [7:0] data_out
);

        logic [7:0] q_chain;

        shift_register_1bit sr_0 (
                .clk(clk),
                .d(data_in),
                .q(q_chain[0])
        );

        generate
                for (genvar i = 1; i < 8; i++) begin
                        shift_register_1bit sr_g (
                                .clk(clk),
                                .d(q_chain[i-1]),
                                .q(q_chain[i])
                        );
                end
        endgenerate

        assign data_out = q_chain;
endmodule