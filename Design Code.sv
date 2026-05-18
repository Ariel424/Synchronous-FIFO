module fifo (
    input  logic       clock, reset, write, read,
    input  logic [7:0] din, 
    output logic [7:0] dout, // עודכן מ-reg ל-logic
    output logic       empty, full
);
    logic [4:0] write_pointer, read_pointer;
    logic [7:0] mem [15:0];

    assign empty = (write_pointer == read_pointer);
    assign full  = (write_pointer[3:0] == read_pointer[3:0]) &&
                   (write_pointer[4]   != read_pointer[4]);

    // עודכן ל-always_ff המומלץ ב-SystemVerilog לתת-מערכות סינכרוניות
    always_ff @(posedge clock) begin
        if (reset) begin
            write_pointer <= 0;
            read_pointer  <= 0;
            dout          <= 0;
        end else begin
            if (write && !full) begin
                mem[write_pointer[3:0]] <= din;
                write_pointer <= write_pointer + 1;
            end

            if (read && !empty) begin
                dout <= mem[read_pointer[3:0]];
                read_pointer <= read_pointer + 1;
            end
        end
    end
endmodule

interface fifo_if;

  logic clock, reset, write, read, empty, full;
  logic [7:0] data_in, data_out;
    
endinterface
