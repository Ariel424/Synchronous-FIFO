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
  mailbox #(FIFO_transaction) gen2drv;
  event drv_done;
  int num_transactions = 100;

  function new(mailbox #(FIFO_transaction) gen2drv, event drv_done);
    this.gen2drv = gen2drv;
    this.drv_done = drv_done;
  endfunction

  task run();
    repeat(num_transactions) begin
      FIFO_transaction trans = new();
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

  function new(virtual FIFO_if vif,
               mailbox #(FIFO_transaction) gen2drv,
               event drv_done);
    this.vif = vif;
    this.gen2drv = gen2drv;
    this.drv_done = drv_done;
  endfunction

  task run();
    forever begin
      FIFO_transaction trans;
      gen2drv.get(trans);
      @(posedge vif.Clock);
      vif.Write   <= trans.Write;
      vif.Read    <= trans.Read;
      vif.Data_in <= trans.Data_in;
      -> drv_done;
    end
  endtask
endclass

// ============================================================================
// MONITOR CLASS
// ============================================================================
class FIFO_monitor;
  virtual FIFO_if vif;
  mailbox #(FIFO_transaction) mon2scb;

  function new(virtual FIFO_if vif,
               mailbox #(FIFO_transaction) mon2scb);
    this.vif = vif;
    this.mon2scb = mon2scb;
  endfunction

  task run();
    forever begin
      FIFO_transaction trans = new();
      @(posedge vif.Clock);
      trans.Write   = vif.Write;
      trans.Read    = vif.Read;
      trans.Data_in = vif.Data_in;
      mon2scb.put(trans);
    end
  endtask
endclass

// ============================================================================
// SCOREBOARD CLASS
// ============================================================================
class FIFO_scoreboard;
  mailbox #(FIFO_transaction) mon2scb;
  bit [7:0] ref_q[$];
  int pass_count, fail_count;

  function new(mailbox #(FIFO_transaction) mon2scb);
    this.vif = vif;
    this.mon2scb = mon2scb;
  endfunction

  task run();
    forever begin
      FIFO_transaction trans;
      mon2scb.get(trans);

      if (trans.Write && !vif.Full)
        ref_q.push_back(trans.Data_in);

      if (trans.Read && !vif.Empty) begin
        bit [7:0] exp = ref_q.pop_front();
        if (vif.Data_out === exp)
          pass_count++;
        else
          fail_count++;
      end
    end
  endtask

  function void report();
    $display("PASS=%0d FAIL=%0d", pass_count, fail_count);
  endfunction
endclass

// ============================================================================
// COVERAGE CLASS
// ============================================================================
class FIFO_coverage;
  virtual FIFO_if vif;

  covergroup fifo_cg @(posedge vif.Clock);
    coverpoint vif.Write;
    coverpoint vif.Read;
    coverpoint vif.Full;
    coverpoint vif.Empty;
  endgroup

  function new(virtual FIFO_if vif);
    this.vif = vif;
    fifo_cg = new();
  endfunction

  task run();
    forever @(posedge vif.Clock) fifo_cg.sample();
  endtask

  function void report();
    $display("Coverage = %0.2f%%", $get_coverage());
  endfunction
endclass

class FIFO_environment;
  FIFO_generator gen;
  FIFO_driver drv;
  FIFO_monitor mon;
  FIFO_scoreboard scb;
  FIFO_coverage cov;

  mailbox #(FIFO_transaction) gen2drv = new();
  mailbox #(FIFO_transaction) mon2scb = new();
  event drv_done;
  virtual FIFO_if vif;

  function new(virtual FIFO_if vif);
    this.vif = vif;
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
    #500;
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
    vif.Read  = 0;
    vif.Data_in = 0;
    repeat(2) @(posedge vif.Clock);
    vif.Reset = 0;
  endtask

  task run();
    reset_dut();
    env.run();
    env.post_run();
  endtask
endclass

// ============================================================================
// TESTBENCH TOP MODULE
// ============================================================================
module tb_FIFO;

  bit Clock;
  initial forever #5 Clock = ~Clock;

  FIFO_if fif();
  assign fif.Clock = Clock;

  FIFO dut (
    .Clock (fif.Clock),
    .Reset (fif.Reset),
    .Write (fif.Write),
    .Read  (fif.Read),
    .Din   (fif.Data_in),
    .Dout  (fif.Data_out),
    .Empty (fif.Empty),
    .Full  (fif.Full)
  );

  initial begin
    FIFO_test test = new(fif);
    test.run();
    #100 $finish;
  end

endmodule
