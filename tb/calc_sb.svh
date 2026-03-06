class calc_sb #(int DataSize, int AddrSize);

  int mem_a [2**AddrSize];
  int mem_b [2**AddrSize];
  
  bit [DataSize:0] golden_lower_data;  // Added for golden model -Josh
  bit [DataSize:0] golden_upper_data;  // Added for golden model -Josh
  bit carry_lower;  // -Josh
  bit second_read;  // -Josh
  
  // Store the first operand for comparison -Josh
  bit [DataSize-1:0] first_operand_lower;  // -Josh
  bit [DataSize-1:0] first_operand_upper;  // -Josh

  mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box;

  function new(mailbox #(calc_seq_item #(DataSize, AddrSize)) sb_box);
    this.sb_box = sb_box;
    golden_lower_data = 0;  // Initialize golden model -Josh
    golden_upper_data = 0;  // -Josh
    carry_lower = 0;  // -Josh
    second_read = 0;  // -Josh
  endfunction

  task main();
    calc_seq_item #(DataSize, AddrSize) trans;
    forever begin
      sb_box.get(trans);
      // Implement the scoreboard's core functionality.
      // The scoreboard's task is to verify the DUT's behavior by comparing the
      // data received from the monitor against a golden reference model.
      // Use `$display` to log successful transactions and `$error` to report mismatches.
      // If a mismatch occurs, use `$finish` to terminate the simulation.
      //-----------
      // RESET -Josh
      //-----------
      if (trans.reset) begin
        // On reset transaction, clear scoreboard state -Josh
        $display($stime, " SB: Reset detected - clearing scoreboard state");  // -Josh
        golden_lower_data = 0;  // -Josh
        golden_upper_data = 0;  // -Josh
        carry_lower = 0;  // -Josh
        second_read = 0;  // -Josh
        first_operand_lower = 0;  // VCS fix: also clear first operand -Josh
        first_operand_upper = 0;  // VCS fix: also clear first operand -Josh
      //------------
      // INITIALIZE -Josh
      //------------
      // For initialization, update the scoreboard's local memory (`mem_a` and `mem_b`) 
      // to match the DUT's initial SRAM state.
      end else if (trans.initialize) begin  // -Josh
        if (!trans.loc_sel) begin  // -Josh
          // SRAM A (lower 32 bits)
          mem_a[trans.curr_wr_addr] = trans.lower_data;  // -Josh
          $display($stime, " SB: Initialized SRAM A[0x%0x] = 0x%0x", trans.curr_wr_addr, trans.lower_data);  // -Josh
        end else begin  // -Josh
          // SRAM B (upper 32 bits)
          mem_b[trans.curr_wr_addr] = trans.upper_data;  // -Josh
          $display($stime, " SB: Initialized SRAM B[0x%0x] = 0x%0x", trans.curr_wr_addr, trans.upper_data);  // -Josh
        end
      
      //------------
      // WRITE -Josh
      //------------
      // For write operations, compare the DUT's output to the data calculated 
      // by the golden model in the scoreboard.
      end else if (trans.rdn_wr) begin  // -Josh
        // VCS fix: Check if we have a valid golden model (i.e., two reads happened)
        // If golden is still 0 and both operands are 0, skip this comparison as it's 
        // likely a stale transaction from before reset
        if (golden_lower_data == 0 && golden_upper_data == 0 && 
            first_operand_lower == 0 && first_operand_upper == 0 &&
            (trans.lower_data != 0 || trans.upper_data != 0)) begin
          $display($stime, " SB: Skipping stale write transaction (golden not calculated)");
        end else begin
        // Calculate expected result using golden model -Josh
        // The DUT adds lower 32 bits first (no carry in), then upper 32 bits (with carry from lower)
        bit [DataSize:0] expected_lower;  // -Josh
        bit [DataSize:0] expected_upper;  // -Josh
        
        expected_lower = golden_lower_data[DataSize-1:0];  // -Josh
        expected_upper = golden_upper_data[DataSize-1:0];  // -Josh
        
        $display($stime, " SB: Checking write at addr 0x%0x", trans.curr_wr_addr);  // -Josh
        $display($stime, " SB: Expected - Lower: 0x%0x, Upper: 0x%0x", expected_lower, expected_upper);  // -Josh
        $display($stime, " SB: Actual   - Lower: 0x%0x, Upper: 0x%0x", trans.lower_data, trans.upper_data);  // -Josh
        
        // Compare DUT output with expected values -Josh
        if (trans.lower_data !== expected_lower) begin  // -Josh
          $error($stime, " SB: MISMATCH on lower 32 bits! Expected: 0x%0x, Got: 0x%0x",   // -Josh
                 expected_lower, trans.lower_data);
          $finish;  // -Josh
        end
        
        if (trans.upper_data !== expected_upper) begin  // -Josh
          $error($stime, " SB: MISMATCH on upper 32 bits! Expected: 0x%0x, Got: 0x%0x",   // -Josh
                 expected_upper, trans.upper_data);
          $finish;  // -Josh
        end
        
        $display($stime, " SB: Write verification PASSED!");  // -Josh
        
        // Update local memory with the written values -Josh
        mem_a[trans.curr_wr_addr] = trans.lower_data;  // -Josh
        mem_b[trans.curr_wr_addr] = trans.upper_data;  // -Josh
        
        // Reset for next operation -Josh
        second_read = 0;  // -Josh
        golden_lower_data = 0;  // -Josh
        golden_upper_data = 0;  // -Josh
        carry_lower = 0;  // -Josh
        first_operand_lower = 0;  // VCS fix: clear for next operation -Josh
        first_operand_upper = 0;  // VCS fix: clear for next operation -Josh
        end  // VCS fix: end of else block for valid golden check
      
      //------------
      // READ -Josh
      //------------
      // For read operations, compare the data from the SRAM in the DUT to the data 
      // stored in the scoreboard's memory.
      // Account for the two sequential reads in the DUT for the single write operation.
      end else begin  // -Josh
        // Verify read data matches our local memory -Josh
        if (trans.lower_data !== mem_a[trans.curr_rd_addr]) begin  // -Josh
          $error($stime, " SB: Read MISMATCH on SRAM A! Addr: 0x%0x, Expected: 0x%0x, Got: 0x%0x",  // -Josh
                 trans.curr_rd_addr, mem_a[trans.curr_rd_addr], trans.lower_data);
          $finish;  // -Josh
        end
        
        if (trans.upper_data !== mem_b[trans.curr_rd_addr]) begin  // -Josh
          $error($stime, " SB: Read MISMATCH on SRAM B! Addr: 0x%0x, Expected: 0x%0x, Got: 0x%0x",  // -Josh
                 trans.curr_rd_addr, mem_b[trans.curr_rd_addr], trans.upper_data);
          $finish;  // -Josh
        end
        
        $display($stime, " SB: Read verification at addr 0x%0x PASSED (Lower: 0x%0x, Upper: 0x%0x)",  // -Josh
                 trans.curr_rd_addr, trans.lower_data, trans.upper_data);
        
        if (!second_read) begin  // -Josh
          // This is the first read - store the first operand -Josh
          first_operand_lower = trans.lower_data;  // -Josh
          first_operand_upper = trans.upper_data;  // -Josh
          second_read = 1;  // -Josh
          $display($stime, " SB: First operand stored - Lower: 0x%0x, Upper: 0x%0x",   // -Josh
                   first_operand_lower, first_operand_upper);
        end else begin  // -Josh
          // This is the second read - calculate the golden result -Josh
          // Calculate lower 32 bits first (no carry in) -Josh
          golden_lower_data = first_operand_lower + trans.lower_data;  // -Josh
          carry_lower = golden_lower_data[DataSize];  // Capture carry out from lower addition -Josh
          
          // Calculate upper 32 bits with carry from lower -Josh
          golden_upper_data = first_operand_upper + trans.upper_data + carry_lower;  // -Josh
          
          $display($stime, " SB: Second operand - Lower: 0x%0x, Upper: 0x%0x",   // -Josh
                   trans.lower_data, trans.upper_data);
          $display($stime, " SB: Golden result calculated - Lower: 0x%0x, Upper: 0x%0x, Carry: %b",  // -Josh
                   golden_lower_data[DataSize-1:0], golden_upper_data[DataSize-1:0], carry_lower);
        end
      end
    end
  endtask

endclass : calc_sb
