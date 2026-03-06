module tb_shift_register_8bit;
        parameter CLK_PERIOD = 10;

        // signals
        logic clk;
        logic data_in;
        logic [7:0] data_out;

        // Declare UUT
        shift_register_8bit uut (
                .clk(clk),
                .data_in(data_in),
                .data_out(data_out)
        );

        // Generate clock
        initial begin
                clk = 0;
                forever #(CLK_PERIOD/2) clk = ~clk;
        end

        // Actual test
        initial begin
                // Fill the Shift Register with all 0s
                data_in = 0;
                repeat (9) @(posedge clk);

                data_in = 1;
                repeat (1) @(posedge clk);
                data_in = 0;

                // Arbitrary wait period to observe shifting behavior
                repeat (20) @(posedge clk);

                $finish;
        end

        initial begin
                $monitor("Time %0t | Data In: %b | Data Out: %b", $time, data_in, data_out);
        end
endmodule