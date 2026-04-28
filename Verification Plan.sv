// ============================================================================
// TRANSACTION CLASS
// ============================================================================
class my_transaction; 
  // הגדרת משתנים (רנדומליים ולא רנדומליים)
  rand bit [7:0] data_in;
  rand bit write, read;
  bit [7:0] data_out;
  bit full, empty; // נוספו המשתנים שהיו חסרים
  
  // הגדרת אילוצים
  constraint write_read_dist {
    write dist {0:=30, 1:=70};
    read  dist {0:=30, 1:=70};
  }

  // פונקציית העתקה מתוקנת - כוללת את כל השדות
  function my_transaction copy(); 
    my_transaction tr = new();
    tr.write    = this.write;
    tr.read     = this.read;
    tr.data_in  = this.data_in;
    tr.data_out = this.data_out;
    tr.full     = this.full;
    tr.empty    = this.empty;
    return tr; 
  endfunction 
  
  // פונקציית הדפסה מתוקנת - שמות משתנים תואמים ופורמט זמן נכון
  function void display(string tag = "");
    $display("[%0s] Time=%0t Write=%0b Read=%0b Din=0x%0h Full=%0b Empty=%0b Dout=0x%0h", 
             tag, $time, write, read, data_in, full, empty, data_out);
  endfunction
endclass

// ============================================================================
// GENERATOR CLASS
// ============================================================================
class my_generator;
  mailbox #(my_transaction) gen2drv;
  event drv_done;
  int num_transactions = 100;

  function new( mailbox #(my_transaction) gen2drv, event drv_done, int num_transactions = 100);
    this.gen2drv = gen2drv;
    this.drv_done = drv_done;
    this.num_transactions = num_transactions;
  endfunction

  task run();
    repeat(num_transactions) begin
      my_transaction tr = new();
      if (tr.randomize()) $fatal ("Randomized failed!"); 
      gen2drv.put(tr);
      @(drv_done);
    end
  endtask
endclass


// ============================================================================
// DRIVER CLASS
// ============================================================================
class my_driver;
  virtual my_interface.DRIVER_MP vif;
  mailbox #(my_transaction) gen2drv;
  event drv_done;

  function new(virtual my_interface.DRIVER_MP vif, mailbox #(my_transaction) gen2drv, event drv_done);
    this.vif = vif;
    this.gen2drv = gen2drv;
    this.drv_done = drv_done;
  endfunction

  task run();

    fork 
  // producer 
     forever begin
      my_transaction tr; 
      gen2drv.get(tr);
      @(posedge vif.pro_cb);
      vif.pro_cb.write <= tr.write;
      vif.data_in <= tr.data_in;
      vif.full <= tr.full;
    end
      
// consumer
    forever begin
    my_transaction tr; 
    gen2drv.get(tr);
      @(posedge vif.con_cb);
      vif.con_cb.read <= tr.read;
      vif.con_cb.data_out <= tr.data_out;
      vif.con_cb.empty <= tr.empty;   
    end
     -> drv_done;    
    join 
  endtask
endclass

// ============================================================================
// MONITOR CLASS
// ============================================================================
class my_monitor;
  virtual my_interface vif;
  mailbox #(my_transaction) mon2scb;

  function new(virtual my_interface vif, mailbox #(my_transaction) mon2scb);
    this.vif = vif;
    this.mon2scb = mon2scb;
  endfunction

  task run();
    forever begin
      my_transaction tr = new();
      @(posedge vif.mon_cb);
      tr.write    = vif.mon_cb.write;
      tr.read    = vif.mon_cb.read;
      tr.empty    = vif.mon_cb.empty;
      tr.full    = vif.mon_cb.full;
      tr.data_in    = vif.mon_cb.data_in;
      tr.data_out    = vif.mon_cb.data_out;
      mon2scb.put(tr);
    end
  endtask
endclass

// ============================================================================
// SCOREBOARD CLASS
// ============================================================================
class my_scoreboard;
  mailbox #(my_transaction) mon2scb;
  my_transaction exp_queue[$];
  int pass_count, fail_count;

  function new(mailbox #(FIFO_transaction) mon2scb);
    this.mon2scb = mon2scb;
  endfunction

  task run();
    forever begin
      my_transaction tr;
      mon2scb.get(tr);

      if (tr.write && !tr.full) begin
        exp_queue.push_back(tr.data_in);
      end
      if (tr.read && !tr.empty) begin
        my_transaction exp = exp_queue.pop_front();
        if (tr.data_out === exp)
          pass_count++;
        else begin
          $display("MISMATCH: Expected=%0h Got=%0h at time=%0t", exp, tr.Data_out, $time);
          fail_count++;
        end
      end
    end
  endtask

// ============================================================================
// Coverage CLASS
// ============================================================================

class FIFO_coverage;
  virtual FIFO_if vif;
  mailbox #(FIFO_transaction) mon2cov;
  
  // Interface-level coverage
  covergroup interface_cg @(posedge vif.Clock);
    cp_write: coverpoint vif.Write;
    cp_read:  coverpoint vif.Read;
    cp_full:  coverpoint vif.Full;
    cp_empty: coverpoint vif.Empty;
    
    // Cross coverage for corner cases
    cross_wr: cross cp_write, cp_read;
    cross_status: cross cp_full, cp_empty;
    cross_ops: cross cp_write, cp_read, cp_full, cp_empty;
  endgroup
  
  // Transaction-level coverage
  covergroup transaction_cg;
    cp_data: coverpoint trans.Data_in {
      bins low    = {[0:63]};
      bins mid    = {[64:191]};
      bins high   = {[192:255]};
    }
    
    cp_operation: coverpoint {trans.Write, trans.Read} {
      bins idle       = {2'b00};
      bins write_only = {2'b10};
      bins read_only  = {2'b01};
      bins both       = {2'b11};
    }
  endgroup
  
  FIFO_transaction trans;
  
  function new(virtual FIFO_if vif, mailbox #(FIFO_transaction) mon2cov);
    this.vif = vif;
    this.mon2cov = mon2cov;
    interface_cg = new();
    transaction_cg = new();
  endfunction
  
  task run();
    fork
      // Interface sampling (automatic with event)
      forever @(posedge vif.Clock) interface_cg.sample();
      
      // Transaction sampling
      forever begin
        mon2cov.get(trans);
        transaction_cg.sample();
      end
    join
  endtask
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

  mailbox #(FIFO_transaction) gen2drv = new();
  mailbox #(FIFO_transaction) mon2scb = new();
  event drv_done;
  virtual FIFO_if vif;

  function new(virtual FIFO_if vif);
    this.vif = vif;
    gen = new(gen2drv, drv_done);
    drv = new(vif, gen2drv, drv_done);
    mon = new(vif, mon2scb);
    scb = new(mon2scb);
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
