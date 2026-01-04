// ============================================================================
// TRANSACTION CLASS
// ============================================================================
class FIFO_transaction;
  // Input signals (randomized - these are driven to DUT)
  rand bit Write;
  rand bit Read;
  rand bit [7:0] Data_in;
  
  constraint write_read_dist {
    Write dist {0:=30, 1:=70};
    Read dist {0:=30, 1:=70};
  }
  
  function void display(string tag = "");
    $display("[%0s] Time=%0t Write=%0b Read=%0b Din=%0h", 
             tag, $time, Write, Read, Data_in);
  endfunction
endclass

// ============================================================================
// GENERATOR CLASS
// ============================================================================
class FIFO_generator;
  FIFO_transaction trans;
  mailbox #(FIFO_transaction) gen2drv;
  event drv_done;
  int num_transactions;
  
  function new(mailbox #(FIFO_transaction) gen2drv, event drv_done);
    this.gen2drv = gen2drv;
    this.drv_done = drv_done;
    this.num_transactions = 100;
  endfunction
  
  task run();
    repeat(num_transactions) begin
      trans = new();
      assert(trans.randomize());
      gen2drv.put(trans);
      @(drv_done);
    end
  endtask
endclass

// ============================================================================
// DRIVER CLASS
// ============================================================================
class FIFO_driver;
  virtual FIFO_if vif;
  mailbox #(FIFO_transaction) gen2drv;
  event drv_done;
  
  function new(virtual FIFO_if vif, mailbox #(FIFO_transaction) gen2drv, event drv_done);
    this.vif = vif;
    this.gen2drv = gen2drv;
    this.drv_done = drv_done;
  endfunction
  
  task run();
    forever begin
      FIFO_transaction trans;
      gen2drv.get(trans);
      drive_transaction(trans);
      ->drv_done;
    end
  endtask
  
  task drive_transaction(FIFO_transaction trans);
    @(posedge vif.Clock);
    vif.Write <= trans.Write;
    vif.Read <= trans.Read;
    vif.Data_in <= trans.Data_in;
  endtask
endclass

// ============================================================================
// COVERAGE CLASS
// ============================================================================
class FIFO_coverage;
  virtual FIFO_if vif;
  
  // Coverage groups
  covergroup fifo_cg @(posedge vif.Clock);
    
    // Cover Write operations
    cp_write: coverpoint vif.Write {
      bins write_low = {0};
      bins write_high = {1};
    }
    
    // Cover Read operations
    cp_read: coverpoint vif.Read {
      bins read_low = {0};
      bins read_high = {1};
    }
    
    // Cover Full flag
    cp_full: coverpoint vif.Full {
      bins not_full = {0};
      bins full = {1};
    }
    
    // Cover Empty flag
    cp_empty: coverpoint vif.Empty {
      bins not_empty = {0};
      bins empty = {1};
    }
    
    // Cover Data input values
    cp_data: coverpoint vif.Data_in {
      bins low_data = {[8'h00:8'h3F]};
      bins mid_data = {[8'h40:8'hBF]};
      bins high_data = {[8'hC0:8'hFF]};
      bins all_zeros = {8'h00};
      bins all_ones = {8'hFF};
    }
    
    // Cross coverage: Write operation with Full flag
    cross_write_full: cross cp_write, cp_full {
      ignore_bins write_when_full = binsof(cp_write.write_high) && binsof(cp_full.full);
    }
    
    // Cross coverage: Read operation with Empty flag
    cross_read_empty: cross cp_read, cp_empty {
      ignore_bins read_when_empty = binsof(cp_read.read_high) && binsof(cp_empty.empty);
    }
    
    // Cross coverage: Simultaneous Read and Write
    cross_read_write: cross cp_read, cp_write {
      bins simultaneous = binsof(cp_read.read_high) && binsof(cp_write.write_high);
      bins only_write = binsof(cp_write.write_high) && binsof(cp_read.read_low);
      bins only_read = binsof(cp_read.read_high) && binsof(cp_write.write_low);
      bins idle = binsof(cp_read.read_low) && binsof(cp_write.write_low);
    }
    
    // Cross coverage: Full and Empty states
    cross_full_empty: cross cp_full, cp_empty {
      illegal_bins both_asserted = binsof(cp_full.full) && binsof(cp_empty.empty);
    }
    
  endgroup
  
  function new(virtual FIFO_if vif);
    this.vif = vif;
    fifo_cg = new();
  endfunction
  
  task run();
    forever begin
      @(posedge vif.Clock);
      fifo_cg.sample();
    end
  endtask
  
  function void report();
    $display("\n============================================");
    $display("COVERAGE REPORT");
    $display("============================================");
    $display("Total Coverage: %.2f%%", $get_coverage());
    $display("============================================\n");
  endfunction
  
endclass

// ============================================================================
// MONITOR CLASS
// ============================================================================
class FIFO_monitor;
  virtual FIFO_if vif;
  mailbox #(FIFO_transaction) mon2scb;
  
  function new(virtual FIFO_if vif, mailbox #(FIFO_transaction) mon2scb);
    this.vif = vif;
    this.mon2scb = mon2scb;
  endfunction
  
  task run();
    forever begin
      FIFO_transaction trans = new();
      @(posedge vif.Clock);
      // Only capture input signals that were driven
      trans.Write = vif.Write;
      trans.Read = vif.Read;
      trans.Data_in = vif.Data_in;
      // Send to scoreboard along with current DUT outputs
      mon2scb.put(trans);
    end
  endtask
endclass

// ============================================================================
// SCOREBOARD CLASS
// ============================================================================
class FIFO_scoreboard;
  virtual FIFO_if vif;
  mailbox #(FIFO_transaction) mon2scb;
  bit [7:0] reference_queue[$];
  int pass_count = 0;
  int fail_count = 0;
  
  function new(virtual FIFO_if vif, mailbox #(FIFO_transaction) mon2scb);
    this.vif = vif;
    this.mon2scb = mon2scb;
  endfunction
  
  task run();
    forever begin
      FIFO_transaction trans;
      mon2scb.get(trans);
      check_transaction(trans);
    end
  endtask
  
  task check_transaction(FIFO_transaction trans);
    // Read output signals directly from interface
    bit Full = vif.Full;
    bit Empty = vif.Empty;
    bit [7:0] Data_out = vif.Data_out;
    
    // Check for simultaneous full and empty
    if (Full && Empty) begin
      $display("ERROR: Full and Empty asserted simultaneously at time %0t", $time);
      fail_count++;
    end
    
    // Track writes to reference queue
    if (trans.Write && !Full) begin
      reference_queue.push_back(trans.Data_in);
      $display("ScoreBoard: Write data=%0h, Queue size=%0d", trans.Data_in, reference_queue.size());
    end
    
    // Check reads against reference queue
    if (trans.Read && !Empty) begin
      if (reference_queue.size() > 0) begin
        bit [7:0] expected_data = reference_queue.pop_front();
        if (Data_out === expected_data) begin
          $display("ScoreBoard: PASS - Read data=%0h matches expected=%0h", Data_out, expected_data);
          pass_count++;
        end else begin
          $display("ERROR: Read data=%0h does not match expected=%0h", Data_out, expected_data);
          fail_count++;
        end
      end
    end
    
    // Check Empty flag
    if (reference_queue.size() == 0 && !Empty) begin
      $display("WARNING: Queue empty but Empty flag not set at time %0t", $time);
    end
    
    // Check Full flag
    if (reference_queue.size() == 16 && !Full) begin
      $display("WARNING: Queue full but Full flag not set at time %0t", $time);
    end
  endtask
  
  function void report();
    $display("\n============================================");
    $display("SCOREBOARD REPORT");
    $display("============================================");
    $display("Total Passed: %0d", pass_count);
    $display("Total Failed: %0d", fail_count);
    if (fail_count == 0)
      $display("TEST PASSED");
    else
      $display("TEST FAILED");
    $display("============================================\n");
  endfunction
endclass

// ============================================================================
// ENVIRONMENT CLASS
// ============================================================================
class FIFO_environment;
  FIFO_generator gen;
  FIFO_driver drv;
  FIFO_monitor mon;
  FIFO_scoreboard scb;
  FIFO_coverage cov;
  
  mailbox #(FIFO_transaction) gen2drv;
  mailbox #(FIFO_transaction) mon2scb;
  event drv_done;
  
  virtual FIFO_if vif;
  
  function new(virtual FIFO_if vif);
    this.vif = vif;
    gen2drv = new();
    mon2scb = new();
    
    gen = new(gen2drv, drv_done);
    drv = new(vif, gen2drv, drv_done);
    mon = new(vif, mon2scb);
    scb = new(vif, mon2scb);
    cov = new(vif);
  endfunction
  
  task run();
    fork
      gen.run();
      drv.run();
      mon.run();
      scb.run();
      cov.run();
    join_any
  endtask
  
  task post_run();
    #1000;
    scb.report();
    cov.report();
  endtask
endclass

// ============================================================================
// TEST CLASS
// ============================================================================
class FIFO_test;
  FIFO_environment env;
  virtual FIFO_if vif;
  
  function new(virtual FIFO_if vif);
    this.vif = vif;
    env = new(vif);
  endfunction
  
  task reset_dut();
    vif.Reset = 1;
    vif.Write = 0;
    vif.Read = 0;
    vif.Data_in = 0;
    repeat(2) @(posedge vif.Clock);
    vif.Reset = 0;
    $display("Reset completed at time %0t", $time);
  endtask
  
  task run();
    reset_dut();
    fork
      env.run();
    join_any
    env.post_run();
  endtask
endclass

// ============================================================================
// TESTBENCH TOP MODULE
// ============================================================================
module tb_FIFO;
  
  // Clock generation
  bit Clock;
  initial begin
    Clock = 0;
    forever #5 Clock = ~Clock;
  end
  
  // Interface instantiation
  FIFO_if fif();
  assign fif.Clock = Clock;
  
  // DUT instantiation
  FIFO dut (
    .Clock(fif.Clock),
    .Reset(fif.Reset),
    .Write(fif.Write),
    .Read(fif.Read),
    .Din(fif.Data_in),
    .Dout(fif.Data_out),
    .Empty(fif.Empty),
    .Full(fif.Full)
  );
  
  // Test execution
  initial begin
    FIFO_test test;
    test = new(fif);
    test.run();
    #100;
    $finish;
  end
  
  // Waveform dump
  initial begin
    $dumpfile("fifo.vcd");
    $dumpvars(0, tb_FIFO);
  end
  
  // Timeout watchdog
  initial begin
    #50000;
    $display("ERROR: Simulation timeout");
    $finish;
  end
  
endmodule
