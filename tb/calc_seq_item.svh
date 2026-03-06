class calc_seq_item #(int DataSize, int AddrSize);

  logic reset;
  rand logic rdn_wr;
  rand logic [AddrSize-1:0] read_start_addr;
  rand logic [AddrSize-1:0] read_end_addr;
  rand logic [AddrSize-1:0] write_start_addr;
  rand logic [AddrSize-1:0] write_end_addr;
  rand logic [DataSize-1:0] lower_data;
  rand logic [DataSize-1:0] upper_data;
  rand logic [AddrSize-1:0] curr_rd_addr;
  rand logic [AddrSize-1:0] curr_wr_addr;
  rand logic loc_sel;
  rand logic initialize;

  // Constraint to make sure read end address is greater than or equal to read start address 
  // The calculator reads pairs of addresses, so we need at least 2 addresses (start and start+1) 
  constraint read_end_gt_start { 
    read_end_addr >= read_start_addr + 1;
    // Ensure we read an even number of addresses (pairs of operands) 
    (read_end_addr - read_start_addr + 1) % 2 == 0;
  }
  
  // Constraint to make sure write end address is greater than or equal to write start address 
  constraint write_end_gt_start { 
    write_end_addr >= write_start_addr;
  }
  
  // Constraint to make sure the read and write address ranges are valid and non-overlapping 
  // Also ensures addresses are within valid SRAM range (0 to 2^AddrSize - 1) 
  constraint address_ranges_valid { 
    read_start_addr <= 10'h0FF;
    read_end_addr <= 10'h0FF;
    write_start_addr >= 10'h180;
    write_start_addr <= 10'h1FF;
    write_end_addr >= 10'h180;
    write_end_addr <= 10'h1FF;
    
    (write_end_addr - write_start_addr + 1) == ((read_end_addr - read_start_addr + 1) / 2);
  }

  function new();
  endfunction

  function void display();
    $display($stime, " Rdn_Wr: %b Read Start Addr: 0x%0x, Read End Addr: 0x%0x, Write Start Addr: 0x%0x, Write End Addr: 0x%0x, Data 0x%0x, Current Read Addr: 0x%0x, Current Write Addr: 0x%0x, Buffer location select: %b, SRAM initialization: %b\n",
        rdn_wr, read_start_addr, read_end_addr, write_start_addr, write_end_addr, {upper_data, lower_data}, curr_rd_addr, curr_wr_addr, loc_sel, initialize);
  endfunction

endclass : calc_seq_item