module FIFO (input Clock, Reset, Write, Read,
            input [7:0] Din, output reg [7:0] Dout,
            output Empty, Full);
  
  reg [3:0] Write_Pointer = 0, Read_Pointer = 0; //
  reg [4:0] Count = 0; // 
  reg [7:0] Mem [15:0]; //
 
  always @(posedge clk)
    begin
      if (Reset == 1'b1)
        begin
          Write_Pointer <= 0;
          Read_Pointer <= 0;
          Count  <= 0;
        end
      else if (Write && !Full)
        begin
          Mem[Write_Pointer] <= Din;
          Write_Pointer      <= Write_Pointer + 1;
          Count       <= Count + 1;
        end
      else if (Read && !Empty)
        begin
          Dout <= Mem[Read_Pointer];
          Read_Pointer <= Read_Pointer + 1;
          Count  <= Count - 1;
        end
    end
 
  Assign Empty = (Count == 0) ? 1'b1 : 1'b0;
  Assign Full  = (Count == 16) ? 1'b1 : 1'b0;
 
endmodule
 
//////////////////////////////////////
 
interface FIFO_if;
  
  logic Clock, Read, Write;        
  logic Full, Empty;      
  logic [7:0] Data_in;    
  logic [7:0] Data_out;        
  logic Reset;                  
  
endinterface
