class calc_monitor #(int DataSize, int AddrSize);
  logic written = 0;

  logic pending_read;  // -Josh
  logic [AddrSize-1:0] pending_rd_addr;  // -Josh
  calc_seq_item #(DataSize, AddrSize) initialization_trans;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;
  mailbox #(calc_seq_item #(DataSize, AddrSize)) mon_box;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif);
    this.calcVif = calcVif;
    this.mon_box = new();
  endfunction

  task main();
    forever begin
      @(calcVif.cb);

      // Monitor the reset signal. If reset is asserted, we want to send a transaction to the scoreboard -Josh
      // to indicate that reset has happened so that the scoreboard can reset its internal state as well. -Josh
      // VCS Note: Use calcVif.reset instead of calcVif.cb.reset since reset is declared as
      // output in the clocking block, and VCS doesn't allow sampling clocking block outputs.
      if (calcVif.reset) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();  // -Josh
        written = 0;  // -Josh
        pending_read = 0;  // -Josh
        trans.reset = 1'b1;  // -Josh
        mon_box.put(trans);  // -Josh
      end

      if (calcVif.cb.rd_en && calcVif.cb.wr_en) begin
        $error($stime, " Mon: Error rd_en and wr_en both asserted at the same time\n");
      end
 
      if (pending_read) begin  // -Josh
        calc_seq_item #(DataSize, AddrSize) trans = new();  // -Josh
        // Form the transaction for the pending read operation using the pending_rd_addr -Josh
        // and the data now available on the clocking block (after SRAM latency) -Josh
        trans.rdn_wr = 1'b0;  // This is a read transaction -Josh
        trans.curr_rd_addr = pending_rd_addr;  // -Josh
        trans.lower_data = calcVif.cb.rd_data_lower;  // Data from SRAM A (lower 32 bits) -Josh
        trans.upper_data = calcVif.cb.rd_data_upper;  // Data from SRAM B (upper 32 bits) -Josh

        $display($stime, " Mon: Read from Addr: 0x%0x, Data from SRAM A: 0x%0x, Data from SRAM B: 0x%0x\n",  // -Josh
          trans.curr_rd_addr, trans.lower_data, trans.upper_data);  // -Josh
        mon_box.put(trans);  // -Josh
        pending_read = 0;  // -Josh
      end

      // Sample the transaction and send to scoreboard -Josh
      if (calcVif.cb.wr_en || calcVif.cb.rd_en) begin
        calc_seq_item #(DataSize, AddrSize) trans = new();  // -Josh
        // Assign all values in the transaction from relevant clocking block signals -Josh
        trans.rdn_wr = calcVif.cb.wr_en;  // 1 = write, 0 = read -Josh
        trans.curr_rd_addr = calcVif.cb.curr_rd_addr;  // -Josh
        trans.curr_wr_addr = calcVif.cb.curr_wr_addr;  // -Josh
        trans.loc_sel = calcVif.cb.loc_sel;  // -Josh
        trans.reset = 1'b0;  // -Josh
        trans.initialize = 1'b0;  // -Josh

        if (trans.rdn_wr) // Write -Josh
        begin
          // Assign the data for the transaction from the clocking block -Josh
          trans.lower_data = calcVif.cb.wr_data_lower;  // Lower 32 bits being written -Josh
          trans.upper_data = calcVif.cb.wr_data_upper;  // Upper 32 bits being written -Josh
          
          if (!written) begin
            written = 1;
            $display($stime, " Mon: Write to Addr: 0x%0x, Data to SRAM A (lower 32 bits): 0x%0x, Data to SRAM B (upper 32 bits): 0x%0x\n",  // -Josh
                trans.curr_wr_addr, trans.lower_data, trans.upper_data);  // -Josh
            mon_box.put(trans);  // -Josh
          end
        end else begin // Read -Josh
          written = 0;
          // For read operations, we need to wait until the data is available on the clocking block -Josh
          // Due to SRAM delay (1 clock cycle), we need to keep track of when we get a read -Josh
          // and which address the read is for, then get the actual data later -Josh
          pending_read = 1'b1;  // -Josh
          pending_rd_addr = calcVif.cb.curr_rd_addr;  // -Josh
        end
      end

      if (calcVif.cb.initialize) begin  // -Josh
        calc_seq_item #(DataSize, AddrSize) trans = new();  // -Josh
        // Assign the right fields for the transaction from the clocking block signals -Josh
        // that are relevant to initializing SRAM -Josh
        trans.initialize = 1'b1;  // -Josh
        trans.reset = 1'b0;  // -Josh
        trans.rdn_wr = 1'b0;  // Not a regular write -Josh
        trans.curr_wr_addr = calcVif.cb.initialize_addr;  // -Josh
        trans.loc_sel = calcVif.cb.initialize_loc_sel;  // 0 = SRAM A, 1 = SRAM B -Josh
        
        // Differentiate which data belongs to which SRAM block based on loc_sel -Josh
        if (!calcVif.cb.initialize_loc_sel) begin  // -Josh
          // SRAM A (lower 32 bits) -Josh
          trans.lower_data = calcVif.cb.initialize_data;  // -Josh
          trans.upper_data = '0;  // -Josh
        end else begin  // -Josh
          // SRAM B (upper 32 bits) -Josh
          trans.lower_data = '0;  // -Josh
          trans.upper_data = calcVif.cb.initialize_data;  // -Josh
        end

        $display($stime, " Mon: Initialize SRAM; Write to SRAM %s, Addr: 0x%0x, Data: 0x%0x\n", !calcVif.cb.initialize_loc_sel ? "A" : "B", calcVif.cb.initialize_addr, calcVif.cb.initialize_data);  // -Josh
        mon_box.put(trans);  // -Josh
      end
    end
  endtask : main

endclass : calc_monitor
