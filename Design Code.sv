module FIFO (
    input Clock, Reset, Write, Read,
    input [7:0] Din, 
    output reg [7:0] Dout,
    output Empty, Full
);
    reg [4:0] Write_Pointer, Read_Pointer; // 5th bit handles wrap-around
    reg [7:0] Mem [15:0];

    // Combinational flags are correct for this pointer style
    assign Empty = (Write_Pointer == Read_Pointer);
    assign Full  = (Write_Pointer[3:0] == Read_Pointer[3:0]) && 
                   (Write_Pointer[4]   != Read_Pointer[4]);

    always @(posedge Clock) begin
        if (Reset) begin
            Write_Pointer <= 0;
            Read_Pointer  <= 0;
            Dout          <= 0;
        end else begin
            // Write Logic
            if (Write && !Full) begin
                Mem[Write_Pointer[3:0]] <= Din;
                Write_Pointer           <= Write_Pointer + 1;
            end

            // Read Logic
            if (Read && !Empty) begin
                Dout         <= Mem[Read_Pointer[3:0]];
                Read_Pointer <= Read_Pointer + 1;
            end
        end
    end
endmodule
