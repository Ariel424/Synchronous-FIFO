interface my_interface #(parameter int DATA_WIDTH = 8) (input logic clk); 

    logic reset;
    logic write;
    logic read;
    logic empty;
    logic full;
    logic [DATA_WIDTH - 1:0] data_in;
    logic [DATA_WIDTH - 1:0] data_out;

    clocking pro_cb @(posedge clk);
        default input #1ns output #1ns;
        output write;
        output data_in; 
        input  full; 
    endclocking 

    clocking con_cb @(posedge clk);
        default input #1ns output #1ns;
        output read;
        input  data_out;
        input  empty; 
    endclocking 
      
    clocking mon_cb @(posedge clk);
        default input #1ns output #1ns;
        input write;
        input read;
        input empty; 
        input full;
        input data_in;
        input data_out;
    endclocking 

    modport DRIVER_MP  (clocking pro_cb, clocking con_cb, output reset);
    modport MONITOR_MP (clocking mon_cb, input reset);  
        
endinterface
