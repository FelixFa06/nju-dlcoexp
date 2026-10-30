module display8(
    input  wire clk,
    input  wire tick,
    input  wire [31:0] data,
    output reg  [7:0] seg7,
    output wire [6:0] h
);
    reg [2:0] select = 3'd0;
    always @(posedge clk)
        if (tick)
            select <= select + 3'd1;

    reg [3:0] nibble;
    always @(*) begin
        case (select)
            3'd0: nibble = data[3:0];
            3'd1: nibble = data[7:4];
            3'd2: nibble = data[11:8];
            3'd3: nibble = data[15:12];
            3'd4: nibble = data[19:16];
            3'd5: nibble = data[23:20];
            3'd6: nibble = data[27:24];
            3'd7: nibble = data[31:28];
        endcase
    end

    hex7seg u_hex(nibble, h);

    always @(*) begin
        case (select)
            3'd0: seg7 = 8'b11111110;
            3'd1: seg7 = 8'b11111101;
            3'd2: seg7 = 8'b11111011;
            3'd3: seg7 = 8'b11110111;
            3'd4: seg7 = 8'b11101111;
            3'd5: seg7 = 8'b11011111;
            3'd6: seg7 = 8'b10111111;
            3'd7: seg7 = 8'b01111111;
        endcase
    end
endmodule
