interface my_interface (input logic clk); 
  
logic clk;
logic reset;
logic write;
logic read;
logic empty;
logic full;
logic [7:0] data_in, data_out;

clocking drv_cb @(posedge clk);
default input #1ns output #1ns;
output write;
output data_in; 
input full; 
endclocking 

clocking mon_cb @(posedge clk);
default input #1ns output #1ns;
output read;
output data_out; 
input empry; 
endclocking 

modport DRIVER_MP (clocking drv_cb, input reset);
modport MONITOR_MP (clocking mon_cb, input reset);  
    
endinterface

