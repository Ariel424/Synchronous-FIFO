module FIFO (input Clock, Reset, Write, Read,
            input [7:0] Din, output reg [7:0] Dout,
            output Empty, Full);
  
  reg [4:0] Write_Pointer = 0, Read_Pointer = 0; // 5-bit pointers
  reg [7:0] Mem [15:0];
 
  always @(posedge Clock)
    begin
      if (Reset == 1'b1)
        begin
          Write_Pointer <= 0;
          Read_Pointer  <= 0;
        end
      else begin
        case ({Write && !Full, Read && !Empty})
          2'b10: begin // Write only
            Mem[Write_Pointer[3:0]] <= Din;
            Write_Pointer           <= Write_Pointer + 1;
          end
          2'b01: begin // Read only
            Dout         <= Mem[Read_Pointer[3:0]];
            Read_Pointer <= Read_Pointer + 1;
          end
          2'b11: begin // Simultaneous read and write
            Mem[Write_Pointer[3:0]] <= Din;
            Dout                    <= Mem[Read_Pointer[3:0]];
            Write_Pointer           <= Write_Pointer + 1;
            Read_Pointer            <= Read_Pointer + 1;
          end
        endcase
      end
    end
 
  assign Empty = (Write_Pointer == Read_Pointer);
  assign Full  = (Write_Pointer[3:0] == Read_Pointer[3:0]) && 
                 (Write_Pointer[4] != Read_Pointer[4]);
 
endmodule
 
//////////////////////////////////////
 
interface FIFO_if;
  
  logic Clock, Read, Write;        
  logic Full, Empty;      
  logic [7:0] Data_in;    
  logic [7:0] Data_out;        
  logic Reset;                  
  
endinterface
