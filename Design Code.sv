module FIFO (
    input Clock, Reset, Write, Read,
    input [7:0] Din, 
    output reg [7:0] Dout,
    output Empty, Full
);
    reg [4:0] Write_Pointer, Read_Pointer;
    reg [7:0] Mem [15:0];

    assign Empty = (Write_Pointer == Read_Pointer);
    assign Full  = (Write_Pointer[3:0] == Read_Pointer[3:0]) &&
                   (Write_Pointer[4]   != Read_Pointer[4]);

    always @(posedge Clock) begin
        if (Reset) begin
            Write_Pointer <= 0;
            Read_Pointer  <= 0;
            Dout          <= 0;
        end else begin
            if (Write && !Full) begin
                Mem[Write_Pointer[3:0]] <= Din;
                Write_Pointer <= Write_Pointer + 1;
            end

            if (Read && !Empty) begin
                Dout <= Mem[Read_Pointer[3:0]];
                Read_Pointer <= Read_Pointer + 1;
            end
        end
    end
endmodule

interface FIFO_if;

  logic Clock, Reset, Write, Read, Empty, Full;
  logic [7:0] Data_in, Data_out;
    
endinterface
