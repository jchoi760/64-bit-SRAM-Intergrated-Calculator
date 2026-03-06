class calc_driver #(int DataSize, int AddrSize);

  mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box;

  virtual interface calc_if #(.DataSize(DataSize), .AddrSize(AddrSize)) calcVif;

  function new(virtual interface calc_if #(DataSize, AddrSize) calcVif,
      mailbox #(calc_seq_item #(DataSize, AddrSize)) drv_box);
    this.calcVif = calcVif;
    this.drv_box = drv_box;
  endfunction

  task reset_task();
    // Apply reset sequence to the DUT -Josh
    // The DUT uses active-high reset (rst_i is active high based on controller.sv) -Josh
    $display($stime, " DRV: Applying reset sequence");  // -Josh
    calcVif.cb.reset <= 1'b1;  // Assert reset (active-high) -Josh
    @(calcVif.cb);              // Wait one clock cycle -Josh
    @(calcVif.cb);              // Wait another clock cycle for reset to propagate -Josh
    calcVif.cb.reset <= 1'b0;  // Deassert reset -Josh
    @(calcVif.cb);              // Wait for design to exit reset -Josh
    $display($stime, " DRV: Reset sequence complete");  // -Josh
  endtask

  virtual task initialize_sram(input [AddrSize-1:0] addr, input [DataSize-1:0] data, input logic block_sel);
    // Drive signals for SRAM initialization -Josh
    // block_sel: 0 = SRAM A (lower 32 bits), 1 = SRAM B (upper 32 bits) -Josh
    $display($stime, " DRV: Initializing SRAM %s at addr 0x%0x with data 0x%0x",   // -Josh
             block_sel ? "B" : "A", addr, data);  // -Josh
    
    // Set the initialization signals on the clocking block -Josh
    calcVif.cb.initialize <= 1'b1;  // -Josh
    calcVif.cb.initialize_addr <= addr;  // -Josh
    calcVif.cb.initialize_data <= data;  // -Josh
    calcVif.cb.initialize_loc_sel <= block_sel;  // -Josh
    
    @(calcVif.cb);  // Wait for one clock cycle -Josh
    
    // Deassert initialization signal -Josh
    calcVif.cb.initialize <= 1'b0;  // -Josh
  endtask : initialize_sram

  virtual task start_calc(input logic [AddrSize-1:0] read_start_addr, input logic [AddrSize-1:0] read_end_addr,
      input logic [AddrSize-1:0] write_start_addr, input logic [AddrSize-1:0] write_end_addr,
      input bit direct = 1);
    
    int delay;
    calc_seq_item #(DataSize, AddrSize) trans;
    
    // Drive the calculation parameters to the DUT's interface -Josh
    // These are the top-level inputs to the calculator -Josh
    calcVif.cb.read_start_addr <= read_start_addr;  // -Josh
    calcVif.cb.read_end_addr <= read_end_addr;  // -Josh
    calcVif.cb.write_start_addr <= write_start_addr;  // -Josh
    calcVif.cb.write_end_addr <= write_end_addr;  // -Josh
    
    // Display transaction information -Josh
    $display($stime, " DRV: Starting calculation - Read [0x%0x:0x%0x], Write [0x%0x:0x%0x]",  // -Josh
             read_start_addr, read_end_addr, write_start_addr, write_end_addr);  // -Josh
    
    reset_task();
    @(calcVif.cb iff calcVif.cb.ready);

    if (!direct) begin // Random Mode
      if (drv_box.try_peek(trans)) begin
        delay = $urandom_range(0, 5); // Add a Random delay before the next transaction
        repeat (delay) begin
          @(calcVif.cb);
        end
      end
    end
    calcVif.cb.reset <= 1;
  endtask : start_calc

  virtual task drive();
    calc_seq_item #(DataSize, AddrSize) trans;
    while (drv_box.try_get(trans)) begin
      start_calc(trans.read_start_addr, trans.read_end_addr, trans.write_start_addr, trans.write_end_addr, 0);
    end
  endtask : drive

endclass : calc_driver
