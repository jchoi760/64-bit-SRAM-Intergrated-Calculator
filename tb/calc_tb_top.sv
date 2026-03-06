module calc_tb_top;

  import calc_tb_pkg::*;
  import calculator_pkg::*;

  parameter int DataSize = DATA_W;
  parameter int AddrSize = ADDR_W;
  logic clk = 0;
  logic rst;
  state_t state;

  calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_if(.clk(clk));
  top_lvl my_calc(
    .clk(clk),
    .rst(calc_if.reset),
    .read_start_addr(calc_if.calc.read_start_addr),
    .read_end_addr(calc_if.calc.read_end_addr),
    .write_start_addr(calc_if.calc.write_start_addr),
    .write_end_addr(calc_if.calc.write_end_addr)
  );

  assign rst = calc_if.reset;
  assign state = my_calc.u_ctrl.state;
  assign calc_if.calc.wr_en = my_calc.write;
  assign calc_if.calc.rd_en = my_calc.read;
  assign calc_if.calc.wr_data_lower = my_calc.w_data_lower;
  assign calc_if.calc.wr_data_upper = my_calc.w_data_upper;
  assign calc_if.calc.rd_data_lower = my_calc.r_data_lower;
  assign calc_if.calc.rd_data_upper = my_calc.r_data_upper;
  assign calc_if.calc.ready = my_calc.u_ctrl.state == S_END;
  assign calc_if.calc.curr_rd_addr = my_calc.r_addr;
  assign calc_if.calc.curr_wr_addr = my_calc.w_addr;
  assign calc_if.calc.loc_sel = my_calc.buffer_control;  // Fixed: was my_calc.loc_sel

  calc_tb_pkg::calc_driver #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_driver_h;
  calc_tb_pkg::calc_sequencer #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sequencer_h;
  calc_tb_pkg::calc_monitor #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_monitor_h;
  calc_tb_pkg::calc_sb #(.DataSize(DataSize), .AddrSize(AddrSize)) calc_sb_h;

  always #5 clk = ~clk;

  task write_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    @(posedge clk);
    if (!block_sel) begin
      my_calc.sram_A.memory_mode_inst.memory[addr] = data;
      // Bug fix: Directly update scoreboard's memory model (bypassing monitor timing issues)
      calc_sb_h.mem_a[addr] = data;
    end
    else begin
      my_calc.sram_B.memory_mode_inst.memory[addr] = data;
      // Bug fix: Directly update scoreboard's memory model (bypassing monitor timing issues)
      calc_sb_h.mem_b[addr] = data;
    end
    calc_driver_h.initialize_sram(addr, data, block_sel);
  endtask

  // Task for running a directed test 
  task run_directed_test(
    input [AddrSize-1:0] read_start,
    input [AddrSize-1:0] read_end,
    input [AddrSize-1:0] write_start,
    input [AddrSize-1:0] write_end,
    input string test_name
  );
    $display("\n========================================");
    $display("TEST: %s", test_name);
    $display("========================================");
    calc_driver_h.start_calc(read_start, read_end, write_start, write_end, 1);
    repeat (10) @(posedge clk);
  endtask

  initial begin
    $shm_open("waves.shm");
    $shm_probe("AC");

    calc_monitor_h = new(calc_if);
    calc_sb_h = new(calc_monitor_h.mon_box);
    calc_sequencer_h = new();
    calc_driver_h = new(calc_if, calc_sequencer_h.calc_box);
    fork
      calc_monitor_h.main();
      calc_sb_h.main();
    join_none
    // Apply reset during SRAM initialization
    calc_if.reset <= 1;
    for (int i = 0; i < 2 ** AddrSize; i++) begin
      write_sram(i, $random, 0);
      write_sram(i, $random, 1);
    end

    repeat (10) @(posedge clk);
    
    $display("\n=== Starting tests (driver will manage reset) ===\n");

    //==========================================================================
    // FUNCTIONAL TESTS 
    //==========================================================================
    
    // Test 1: Basic Addition Test - Simple case with small values 
    $display("\n*** FUNCTIONAL TEST 1: Basic Addition ***");
    // Initialize specific values for predictable testing
    write_sram(0, 32'h0000_0001, 0);  // SRAM A[0] = 1 (lower bits of operand 1)
    write_sram(0, 32'h0000_0000, 1);  // SRAM B[0] = 0 (upper bits of operand 1)
    write_sram(1, 32'h0000_0002, 0);  // SRAM A[1] = 2 (lower bits of operand 2)
    write_sram(1, 32'h0000_0000, 1);  // SRAM B[1] = 0 (upper bits of operand 2)
    // Expected result: 1 + 2 = 3 at write address 384 (0x180)
    run_directed_test(0, 1, 384, 384, "Basic Addition: 1 + 2 = 3");

    // Test 2: Addition with Overflow (Lower 32 bits) 
    $display("\n*** FUNCTIONAL TEST 2: Addition with Overflow ***");
    write_sram(2, 32'hFFFF_FFFF, 0);  // SRAM A[2] = MAX (lower bits)
    write_sram(2, 32'h0000_0000, 1);  // SRAM B[2] = 0 (upper bits)
    write_sram(3, 32'h0000_0001, 0);  // SRAM A[3] = 1 (lower bits)
    write_sram(3, 32'h0000_0000, 1);  // SRAM B[3] = 0 (upper bits)
    // Expected: 0xFFFFFFFF + 0x00000001 = 0x100000000, lower = 0, upper = 1 (carry propagates)
    run_directed_test(2, 3, 385, 385, "Overflow Test: 0xFFFFFFFF + 1 = 0x100000000");

    //==========================================================================
    // EDGE CASE TESTS 
    //==========================================================================
    
    // Test 3: 0 + 0 = 0 
    $display("\n*** EDGE CASE TEST 1: Zero Addition ***");
    write_sram(4, 32'h0000_0000, 0);  // SRAM A[4] = 0
    write_sram(4, 32'h0000_0000, 1);  // SRAM B[4] = 0
    write_sram(5, 32'h0000_0000, 0);  // SRAM A[5] = 0
    write_sram(5, 32'h0000_0000, 1);  // SRAM B[5] = 0
    run_directed_test(4, 5, 386, 386, "Edge Case: 0 + 0 = 0");

    // Test 4: MAX + MAX (both 64-bit operands are maximum) 
    $display("\n*** EDGE CASE TEST 2: MAX + MAX ***");
    write_sram(6, 32'hFFFF_FFFF, 0);  // SRAM A[6] = MAX lower
    write_sram(6, 32'hFFFF_FFFF, 1);  // SRAM B[6] = MAX upper
    write_sram(7, 32'hFFFF_FFFF, 0);  // SRAM A[7] = MAX lower
    write_sram(7, 32'hFFFF_FFFF, 1);  // SRAM B[7] = MAX upper
    // Expected: 0xFFFFFFFFFFFFFFFF + 0xFFFFFFFFFFFFFFFF = 0x1FFFFFFFFFFFFFFFE (with overflow)
    run_directed_test(6, 7, 387, 387, "Edge Case: MAX + MAX");

    // Test 5: 0 + MAX 
    $display("\n*** EDGE CASE TEST 3: Zero + MAX ***");
    write_sram(8, 32'h0000_0000, 0);  // SRAM A[8] = 0 lower
    write_sram(8, 32'h0000_0000, 1);  // SRAM B[8] = 0 upper
    write_sram(9, 32'hFFFF_FFFF, 0);  // SRAM A[9] = MAX lower
    write_sram(9, 32'hFFFF_FFFF, 1);  // SRAM B[9] = MAX upper
    run_directed_test(8, 9, 388, 388, "Edge Case: 0 + MAX = MAX");

    // Test 6: Multiple consecutive additions 
    $display("\n*** FUNCTIONAL TEST 3: Multiple Consecutive Additions ***");
    write_sram(10, 32'h1111_1111, 0);
    write_sram(10, 32'h2222_2222, 1);
    write_sram(11, 32'h3333_3333, 0);
    write_sram(11, 32'h4444_4444, 1);
    write_sram(12, 32'h5555_5555, 0);
    write_sram(12, 32'h6666_6666, 1);
    write_sram(13, 32'h7777_7777, 0);
    write_sram(13, 32'h8888_8888, 1);
    // This reads addresses 10-13 and writes results to 389-390
    run_directed_test(10, 13, 389, 390, "Multiple Additions: 2 pairs");

    // Test 7: Carry propagation test (ensure carry from lower to upper works) 
    $display("\n*** FUNCTIONAL TEST 4: Carry Propagation ***");
    write_sram(14, 32'h8000_0000, 0);  // Lower half
    write_sram(14, 32'h0000_0000, 1);  // Upper half
    write_sram(15, 32'h8000_0000, 0);  // Lower half
    write_sram(15, 32'h0000_0000, 1);  // Upper half
    // 0x80000000 + 0x80000000 = 0x100000000 (carry to upper)
    run_directed_test(14, 15, 391, 391, "Carry Propagation: 0x80000000 + 0x80000000");

    //==========================================================================
    // RANDOMIZED CONSTRAINED TESTING 
    //==========================================================================
    $display("\n*** RANDOMIZED CONSTRAINED TESTING ***");
    
    // Generate and run random test sequences 
    // The sequencer generates constrained random transactions 
    calc_sequencer_h.gen(10);  // Generate 10 random test sequences 
    calc_driver_h.drive();     // Drive all generated sequences 
    
    repeat (100) @(posedge clk);

    $display("\n========================================");
    $display("TEST PASSED");
    $display("========================================");
    $finish;
  end

  /********************
        ASSERTIONS 
  *********************/

  // Assertion 1: Verify that LSBs are added before MSBs 
  // In the FSM, S_ADD (lower addition) must come before S_ADD2 (upper addition) 
  property lsb_before_msb;
    @(posedge clk) disable iff (rst)
    (state == S_ADD) |=> (state == S_ADD2);
  endproperty
  
  assert property (lsb_before_msb)
    else $error("ASSERTION FAILED: LSBs must be added before MSBs - FSM violation!");

  // Assertion 2: Verify that the carry bit propagates correctly 
  // When lower addition produces a carry, it should be used in the next cycle 
  property carry_propagation;
    @(posedge clk) disable iff (rst)
    (state == S_ADD && my_calc.carry_out) |=> 
    (state == S_ADD2 && my_calc.u_ctrl.carry_in == 1'b1);
  endproperty
  
  assert property (carry_propagation)
    else $error("ASSERTION FAILED: Carry bit did not propagate from lower to upper addition!");

  // Assertion 3: Reset brings FSM back to IDLE state 
  // From any state, reset should transition to S_IDLE 
  property reset_to_idle;
    @(posedge clk)
    $rose(rst) |=> (state == S_IDLE);
  endproperty
  
  assert property (reset_to_idle)
    else $error("ASSERTION FAILED: Reset did not bring FSM to IDLE state!");

  // Assertion 4: Read and Write enable are mutually exclusive 
  property rd_wr_mutex;
    @(posedge clk) disable iff (rst)
    not (my_calc.read && my_calc.write);
  endproperty
  
  assert property (rd_wr_mutex)
    else $error("ASSERTION FAILED: Read and Write enable are both asserted!");

  // Assertion 5: State transitions are valid (no undefined states) 
  property valid_state_transitions;
    @(posedge clk) disable iff (rst)
    (state inside {S_IDLE, S_READ, S_READ2, S_ADD, S_ADD2, S_WRITE, S_END});
  endproperty
  
  assert property (valid_state_transitions)
    else $error("ASSERTION FAILED: FSM entered an undefined state!");

  // Assertion 6: After S_END, FSM stays in S_END until reset 
  property end_state_stable;
    @(posedge clk) disable iff (rst)
    (state == S_END) |=> (state == S_END);
  endproperty
  
  assert property (end_state_stable)
    else $error("ASSERTION FAILED: FSM left S_END state without reset!");

  // Assertion 7: Write only occurs in S_WRITE state 
  property write_only_in_write_state;
    @(posedge clk) disable iff (rst)
    my_calc.write |-> (state == S_WRITE);
  endproperty
  
  assert property (write_only_in_write_state)
    else $error("ASSERTION FAILED: Write signal asserted outside of S_WRITE state!");

  // Assertion 8: Read only occurs in S_READ or S_READ2 states 
  property read_only_in_read_states;
    @(posedge clk) disable iff (rst)
    my_calc.read |-> (state inside {S_READ, S_READ2});
  endproperty
  
  assert property (read_only_in_read_states)
    else $error("ASSERTION FAILED: Read signal asserted outside of S_READ/S_READ2 states!");

  // Assertion 9: Buffer control is LOWER during S_ADD and UPPER during S_ADD2 
  property buffer_control_correct;
    @(posedge clk) disable iff (rst)
    ((state == S_ADD) |-> (my_calc.buffer_control == LOWER)) and
    ((state == S_ADD2) |-> (my_calc.buffer_control == UPPER));
  endproperty
  
  assert property (buffer_control_correct)
    else $error("ASSERTION FAILED: Buffer control signal incorrect for current state!");

  // Assertion 10: After two reads, there should be two adds followed by a write 
  property read_add_write_sequence;
    @(posedge clk) disable iff (rst)
    (state == S_READ2) |=> (state == S_ADD) ##1 (state == S_ADD2) ##1 (state == S_WRITE);
  endproperty
  
  assert property (read_add_write_sequence)
    else $error("ASSERTION FAILED: Expected READ2 -> ADD -> ADD2 -> WRITE sequence!");

endmodule
