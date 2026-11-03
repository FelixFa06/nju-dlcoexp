module dmem(
	input  [31:0] addr,
	output reg [31:0] dataout,
	input  [31:0] datain,
	input  rdclk,
	input  wrclk,
	input [2:0] memop,
	input  we
);

	// 读数据直接进寄存器，字节/半字扩展放到存储器外，便于推断成 BRAM
	(* ram_style = "block" *)
	reg [31:0] ram[32767:0]; // 128KB

	reg [31:0] raw;
	reg [1:0]  addr_lo;
	reg [2:0]  memop_r;

	always @(posedge rdclk) begin
		raw     <= ram[addr[16:2]];
		addr_lo <= addr[1:0];
		memop_r <= memop;
	end

	always @(*) begin
		case (memop_r)
			3'b000: dataout = {{24{raw[8*addr_lo+7]}}, raw[8*addr_lo +: 8]};
			3'b001: dataout = {{16{raw[16*addr_lo[1]+15]}}, raw[16*addr_lo[1] +: 16]};
			3'b100: dataout = {24'b0, raw[8*addr_lo +: 8]};
			3'b101: dataout = {16'b0, raw[16*addr_lo[1] +: 16]};
			default: dataout = raw;
		endcase
	end

	always @(posedge wrclk)
		if (we) begin
			case (memop[1:0])
				2'b00: ram[addr[16:2]][8*addr[1:0] +: 8] <= datain[7:0];
				2'b01: ram[addr[16:2]][16*addr[1] +: 16] <= datain[15:0];
				2'b10: ram[addr[16:2]] <= datain;
				default: ;
			endcase
		end

endmodule
