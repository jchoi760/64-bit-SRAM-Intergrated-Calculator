`timescale 1ns/1ps

module tb_full_adder;

    // Testbench signals
    logic a;
    logic b;
    logic cin;
    logic s;
    logic cout;

    // Instantiate DUT (Design Under Test)
    full_adder dut (
        .a(a),
        .b(b),
        .cin(cin),
        .s(s),
        .cout(cout)
    );

    // Expected outputs
    logic exp_s;
    logic exp_cout;

    // Task to apply one test case
    task run_test(input logic ta, tb, tcin);
        begin
            // Apply inputs
            a   = ta;
            b   = tb;
            cin = tcin;

            // Wait for signals to settle
            #5;

            // Compute expected result
            {exp_cout, exp_s} = ta + tb + tcin;

            // Check result
            if ({cout, s} !== {exp_cout, exp_s}) begin
                $error("FAIL: a=%0b b=%0b cin=%0b | Expected: cout=%0b s=%0b | Got: cout=%0b s=%0b",
                        ta, tb, tcin,
                        exp_cout, exp_s,
                        cout, s);
            end
            else begin
                $display("PASS: a=%0b b=%0b cin=%0b | cout=%0b s=%0b",
                          ta, tb, tcin, cout, s);
            end
        end
    endtask


    // Main test sequence
    initial begin
        $shm_open("waves.shm");
        $shm_probe("AC");
        $display("Starting Full Adder Testbench...");
        $display("--------------------------------");

        // Initialize
        a   = 0;
        b   = 0;
        cin = 0;

        #10;

        // Run all 8 combinations
        run_test(0,0,0);
        run_test(0,0,1);
        run_test(0,1,0);
        run_test(0,1,1);
        run_test(1,0,0);
        run_test(1,0,1);
        run_test(1,1,0);
        run_test(1,1,1);

        $display("--------------------------------");
        $display("All tests completed.");

        #10;
        $finish;

    end

endmodule
