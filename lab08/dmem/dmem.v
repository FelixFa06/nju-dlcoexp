module dmem(
	input  [31:0] addr,
	output reg [31:0] dataout,
	input  [31:0] datain,
	input  rdclk,
	input  wrclk,
	input [2:0] memop,
	input we
);

    reg [31:0] ram[32767:0];

    always @(posedge rdclk) begin
        dataout = ram[addr[16:2]];
        case (memop)
            3'b000: dataout = {{24{dataout[8*addr[1:0]+7]}}, dataout[8*addr[1:0] +: 8]};
            3'b001: dataout = {{16{dataout[16*addr[1]+15]}}, dataout[16*addr[1] +: 16]};
            3'b100: dataout = {24'b0, dataout[8*addr[1:0] +: 8]};
            3'b101: dataout = {16'b0, dataout[16*addr[1] +: 16]};
            default: ;
        endcase
    end

    always @(posedge wrclk)
        if (we) begin
            case (memop[1:0])
                2'b00: ram[addr[16:2]][8*addr[1:0] +: 8] = datain[7:0];
                2'b01: ram[addr[16:2]][16*addr[1] +: 16] = datain[15:0];
                2'b10: ram[addr[16:2]] = datain;
                default: ;
            endcase
        end

endmodule
