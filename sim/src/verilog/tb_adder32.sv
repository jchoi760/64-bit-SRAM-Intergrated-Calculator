/*
 * Testbench for adder32 (32-bit ripple carry adder)
 * Tests:
 *   1. Basic addition (no carry)
 *   2. Carry input functionality
 *   3. Carry output (overflow) detection
 *   4. Edge cases (0, max values)
 *   5. Random stress test with golden model
 */
module tb_adder32 import calculator_pkg::*;();

    //=========================================================================
    // DUT Signals
    //=========================================================================
    logic [DATA_W-1:0]  a, b;       // 32-bit operands
    logic               c_in;       // Carry input
    logic               c_out;      // Carry output
    logic [DATA_W-1:0]  sum;        // 32-bit sum
    
    //=========================================================================
    // Test Variables
    //=========================================================================
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // Golden model outputs
    logic [32:0] expected_result;   // 33-bit to capture carry
    logic [DATA_W-1:0] expected_sum;
    logic expected_cout;
    
    //=========================================================================
    // DUT Instantiation
    //=========================================================================
    adder32 DUT (
        .a_i    (a),
        .b_i    (b),
        .c_i    (c_in),
        .c_o    (c_out),
        .sum_o  (sum)
    );
    
    //=========================================================================
    // Golden Model
    //=========================================================================
    function automatic void compute_expected();
        expected_result = {1'b0, a} + {1'b0, b} + {32'b0, c_in};
        expected_sum = expected_result[31:0];
        expected_cout = expected_result[32];
    endfunction
    
    //=========================================================================
    // Check Task
    //=========================================================================
    task check_result(input string test_name);
        test_count++;
        compute_expected();
        
        #1;  // Allow combinational logic to settle
        
        if (sum === expected_sum && c_out === expected_cout) begin
            pass_count++;
            $display("[PASS] %s: %08h + %08h + %b = %08h (c_out=%b)", 
                     test_name, a, b, c_in, sum, c_out);
        end else begin
            fail_count++;
            $display("[FAIL] %s: %08h + %08h + %b", test_name, a, b, c_in);
            $display("       Expected: sum=%08h, c_out=%b", expected_sum, expected_cout);
            $display("       Got:      sum=%08h, c_out=%b", sum, c_out);
        end
    endtask
    
    //=========================================================================
    // Waveform Dumping
    //=========================================================================
    initial begin
        $shm_open("waves_adder32.shm");
        $shm_probe("AC");  // All signals, including internal
    end
    
    //=========================================================================
    // Main Test Sequence
    //=========================================================================
    initial begin
        $display("\n========================================");
        $display("  32-bit Adder Testbench");
        $display("========================================\n");
        
        //---------------------------------------------------------------------
        // Test 1: Basic Addition (0 + 0)
        //---------------------------------------------------------------------
        $display("\n--- Test 1: Zero + Zero ---");
        a = 32'h0000_0000;
        b = 32'h0000_0000;
        c_in = 0;
        check_result("0 + 0");
        
        //---------------------------------------------------------------------
        // Test 2: Simple Addition
        //---------------------------------------------------------------------
        $display("\n--- Test 2: Simple Addition ---");
        a = 32'h0000_0001;
        b = 32'h0000_0001;
        c_in = 0;
        check_result("1 + 1");
        
        a = 32'h0000_0005;
        b = 32'h0000_0003;
        c_in = 0;
        check_result("5 + 3");
        
        a = 32'h0000_00FF;
        b = 32'h0000_0001;
        c_in = 0;
        check_result("255 + 1");
        
        //---------------------------------------------------------------------
        // Test 3: Carry Input
        //---------------------------------------------------------------------
        $display("\n--- Test 3: Carry Input ---");
        a = 32'h0000_0000;
        b = 32'h0000_0000;
        c_in = 1;
        check_result("0 + 0 + cin=1");
        
        a = 32'h0000_0001;
        b = 32'h0000_0001;
        c_in = 1;
        check_result("1 + 1 + cin=1");
        
        a = 32'hFFFF_FFFE;
        b = 32'h0000_0000;
        c_in = 1;
        check_result("FFFFFFFE + 0 + cin=1");
        
        //---------------------------------------------------------------------
        // Test 4: Carry Output (Overflow)
        //---------------------------------------------------------------------
        $display("\n--- Test 4: Carry Output ---");
        a = 32'hFFFF_FFFF;
        b = 32'h0000_0001;
        c_in = 0;
        check_result("FFFFFFFF + 1 (overflow)");
        
        a = 32'hFFFF_FFFF;
        b = 32'hFFFF_FFFF;
        c_in = 0;
        check_result("FFFFFFFF + FFFFFFFF (overflow)");
        
        a = 32'h8000_0000;
        b = 32'h8000_0000;
        c_in = 0;
        check_result("80000000 + 80000000 (overflow)");
        
        //---------------------------------------------------------------------
        // Test 5: Carry In + Overflow
        //---------------------------------------------------------------------
        $display("\n--- Test 5: Carry In + Overflow ---");
        a = 32'hFFFF_FFFF;
        b = 32'h0000_0000;
        c_in = 1;
        check_result("FFFFFFFF + 0 + cin=1 (overflow)");
        
        a = 32'hFFFF_FFFF;
        b = 32'hFFFF_FFFF;
        c_in = 1;
        check_result("FFFFFFFF + FFFFFFFF + cin=1 (overflow)");
        
        //---------------------------------------------------------------------
        // Test 6: Edge Cases
        //---------------------------------------------------------------------
        $display("\n--- Test 6: Edge Cases ---");
        a = 32'hFFFF_FFFF;
        b = 32'h0000_0000;
        c_in = 0;
        check_result("MAX + 0");
        
        a = 32'h0000_0000;
        b = 32'hFFFF_FFFF;
        c_in = 0;
        check_result("0 + MAX");
        
        a = 32'h5555_5555;
        b = 32'hAAAA_AAAA;
        c_in = 0;
        check_result("Alternating patterns");
        
        //---------------------------------------------------------------------
        // Test 7: Bit Pattern Tests
        //---------------------------------------------------------------------
        $display("\n--- Test 7: Bit Patterns ---");
        a = 32'h0000_FFFF;
        b = 32'h0000_0001;
        c_in = 0;
        check_result("Lower half carry");
        
        a = 32'hFFFF_0000;
        b = 32'h0001_0000;
        c_in = 0;
        check_result("Upper half carry");
        
        a = 32'h00FF_00FF;
        b = 32'h0001_0001;
        c_in = 0;
        check_result("Byte boundary");
        
        //---------------------------------------------------------------------
        // Test 8: Subtraction via Two's Complement
        //---------------------------------------------------------------------
        $display("\n--- Test 8: Two's Complement Subtraction ---");
        // 5 - 3 = 5 + (~3) + 1 = 5 + FFFFFFFC + 1 = 2
        a = 32'h0000_0005;
        b = ~32'h0000_0003;  // FFFFFFFC
        c_in = 1;
        check_result("5 - 3 (two's complement)");
        
        // 10 - 7 = 10 + (~7) + 1
        a = 32'h0000_000A;
        b = ~32'h0000_0007;
        c_in = 1;
        check_result("10 - 7 (two's complement)");
        
        //---------------------------------------------------------------------
        // Test 9: Random Stress Test
        //---------------------------------------------------------------------
        $display("\n--- Test 9: Random Stress Test (100 iterations) ---");
        for (int i = 0; i < 100; i++) begin
            a = $urandom();
            b = $urandom();
            c_in = $urandom_range(0, 1);
            check_result($sformatf("Random %0d", i));
        end
        
        //---------------------------------------------------------------------
        // Test 10: Exhaustive Single-Bit Tests
        //---------------------------------------------------------------------
        $display("\n--- Test 10: Single-Bit Position Tests ---");
        for (int i = 0; i < 32; i++) begin
            a = 32'h1 << i;
            b = 32'h1 << i;
            c_in = 0;
            check_result($sformatf("Bit %0d double", i));
        end
        
        //---------------------------------------------------------------------
        // Summary
        //---------------------------------------------------------------------
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("  Total Tests: %0d", test_count);
        $display("  Passed:      %0d", pass_count);
        $display("  Failed:      %0d", fail_count);
        $display("========================================\n");
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED ***\n");
        end else begin
            $display("*** SOME TESTS FAILED ***\n");
        end
        
        $finish;
    end

endmodule
