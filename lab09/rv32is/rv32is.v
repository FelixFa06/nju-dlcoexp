module rv32is(
	input 	clock,
	input 	reset,
	input 	en,
	output [31:0] imemaddr,
	input  [31:0] imemdataout,
	output 	imemclk,
	output [31:0] dmemaddr,
	input  [31:0] dmemdataout,
	output [31:0] dmemdatain,
	output 	dmemrdclk,
	output	dmemwrclk,
	output [2:0] dmemop,
	output	dmemwe,
	output [31:0] dbgdata
);

	// data
	reg [31:0] pc;
	wire [31:0] instr, nextpc;
	wire [4:0] rs1, rs2, rd;
	wire [31:0] busa, busb, busw;
	wire [6:0] op;
	wire [2:0] func3;
	wire [6:0] func7;
	wire [31:0] imm, dataa, datab, aluresult;
	wire zero, less;
	wire pcasrc, pcbsrc;

	// control signals
	wire [2:0]	extop;
	wire		regwr;
	wire 		aluasrc;
	wire [1:0]	alubsrc;
	wire [3:0]	aluctr;
	wire [2:0]	branch;
	wire 		memtoreg;
	wire 		memwr;
	wire [2:0]	memop;

	// control unit
	ctrl myctrl(
		.op(op),
		.func3(func3),
		.func7(func7),
		.extop(extop),
		.regwr(regwr),
		.aluasrc(aluasrc),
		.alubsrc(alubsrc),
		.aluctr(aluctr),
		.branch(branch),
		.memtoreg(memtoreg),
		.memwr(memwr),
		.memop(memop)
	);
	assign dmemop = memop;
	assign dmemwe = memwr;

	// IF
	assign dbgdata = pc;
	assign imemaddr = reset ? 32'd0 : nextpc;
	assign imemclk = ~clock;
	assign instr = imemdataout;
	assign nextpc = (~pcasrc ? 32'd4 : imm) + (~pcbsrc ? pc : busa);
	always @(negedge clock)
		if (reset || en)
			pc <= reset ? 32'd0 : nextpc;

	// ID
	assign op = instr[6:0];
	assign rs1 = instr[19:15];
	assign rs2 = instr[24:20];
	assign rd = instr[11:7];
	assign func3 = instr[14:12];
	assign func7 = instr[31:25];
	assign dataa = ~aluasrc ? busa : pc;
	assign datab = alubsrc == 2'b00 ? busb : (alubsrc == 2'b01 ? imm: 32'd4);

	// regfile
	regfile myregfile(
		.ra(rs1),
		.rb(rs2),
		.rw(rd),
		.wrdata(busw),
		.regwr(regwr & en),
		.wrclk(~clock),
		.outa(busa),
		.outb(busb)
	);

	// imm-extention
	immext myimmext(
		.instr(instr),
		.extop(extop),
		.imm(imm)
	);

	// alu
	alu myalu(
		.dataa(dataa),
		.datab(datab),
		.aluctr(aluctr),
		.less(less),
		.zero(zero),
		.aluresult(aluresult)
	);

	// mem
	assign dmemrdclk = clock;
	assign dmemwrclk = ~clock;
	assign dmemaddr = aluresult;
	assign dmemdatain = busb;
	assign busw = (memtoreg ? dmemdataout : aluresult);

	// branch-jump control
	bandj mybanj(
		.branch(branch),
		.zero(zero),
		.less(less),
		.pcasrc(pcasrc),
		.pcbsrc(pcbsrc)
	);
	
endmodule

module regfile(
    input  [4:0]  ra,
    input  [4:0]  rb,
	input  [4:0]  rw,
	input  [31:0] wrdata,
	input  regwr,
	input  wrclk,
	output [31:0] outa,
	output [31:0] outb
	);
	
	//The regfile
	reg [31:0] regs[31:0];	
	
    //read
	assign outa = ra == 5'd0 ? 32'd0 : regs[ra];
    assign outb = rb == 5'd0 ? 32'd0 : regs[rb];

    //write
    always @(posedge wrclk)
        if (regwr && rw!=5'd0) begin
            regs[rw] <= wrdata;
        end
	
endmodule

module immext(
	input [31:0] instr,
	input [2:0] extop,
	output reg [31:0] imm
);

	wire [31:0] immI, immU, immS, immB, immJ;
	assign immI = {{20{instr[31]}}, instr[31:20]};
	assign immU = {instr[31:12], 12'b0};
	assign immS = {{20{instr[31]}}, instr[31:25], instr[11:7]};
	assign immB = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
	assign immJ = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

	always @(*)
		case (extop)
			3'b000: imm = immI;
			3'b001: imm = immU;
			3'b010: imm = immS;
			3'b011: imm = immB;
			3'b100: imm = immJ;
			default: imm = 32'd0;
		endcase

endmodule

module alu(
	input [31:0] dataa,
	input [31:0] datab,
	input [3:0]  aluctr,
	output less,
	output zero,
	output reg [31:0] aluresult
);

    always @(*) begin
        casez (aluctr)
            4'b0000: aluresult = dataa + datab;
            4'b1000: aluresult = dataa - datab;
            4'b?001: aluresult = dataa << datab[4:0];
            4'b0010: aluresult = $signed(dataa) < $signed(datab);
            4'b1010: aluresult = $unsigned(dataa) < $unsigned(datab);
            4'b?011: aluresult = datab;
            4'b?100: aluresult = dataa ^ datab;
            4'b0101: aluresult = dataa >> datab[4:0];
            4'b1101: aluresult = $signed(dataa) >>> datab[4:0];
            4'b?110: aluresult = dataa | datab;
            4'b?111: aluresult = dataa & datab;
        endcase
    end
    
    assign less = aluresult[0];
    assign zero = aluctr[2:0]==3'b010 ? dataa == datab : aluresult == 32'b0;

endmodule

module bandj(
	input [2:0]	branch,
	input 		zero,
	input 		less,
	output reg	pcasrc,
	output reg	pcbsrc
);

	always @(*) begin
		pcasrc = 1'b0;
		pcbsrc = 1'b1;
		case (branch)
			3'b000: begin pcasrc = 1'b0; pcbsrc = 1'b0; end
			3'b001: begin pcasrc = 1'b1; pcbsrc = 1'b0; end
			3'b010: begin pcasrc = 1'b1; pcbsrc = 1'b1; end
			3'b100: begin pcasrc = zero; pcbsrc = 1'b0; end
			3'b101: begin pcasrc = ~zero; pcbsrc = 1'b0; end
			3'b110: begin pcasrc = less; pcbsrc = 1'b0; end
			3'b111: begin pcasrc = ~less; pcbsrc = 1'b0; end
			default: begin pcasrc = 1'b0; pcbsrc = 1'b0; end
		endcase
	end

endmodule

module ctrl(
	input  [6:0] 	op,
	input  [2:0] 	func3,
	input  [6:0] 	func7,
	output reg [2:0] extop,
	output reg		 regwr,
	output reg 		 aluasrc,
	output reg [1:0] alubsrc,
	output reg [3:0] aluctr,
	output reg [2:0] branch,
	output reg 		 memtoreg,
	output reg 		 memwr,
	output reg [2:0] memop
);

	always @(*) begin
		extop    = 3'b000;
		regwr    = 1'b0;
		aluasrc  = 1'b0;
		alubsrc  = 2'b00;
		aluctr   = 4'b0000;
		branch   = 3'b000;
		memtoreg = 1'b0;
		memwr    = 1'b0;
		memop    = 3'b000;
		case (op)
			7'b0110011: begin					// R-op
				regwr = 1'b1;
				case (func3)
					3'b000: aluctr = {func7[5], 3'b000};
					3'b001: aluctr = 4'b0001;
					3'b010: aluctr = 4'b0010;
					3'b011: aluctr = 4'b1010;
					3'b100: aluctr = 4'b0100;
					3'b101: aluctr = {func7[5], 3'b101};
					3'b110: aluctr = 4'b0110;
					3'b111: aluctr = 4'b0111;
				endcase
			end
			7'b0010011: begin					// I-op
				regwr   = 1'b1;
				alubsrc = 2'b01;
				case (func3)
					3'b000: aluctr = 4'b0000;
					3'b001: aluctr = 4'b0001;
					3'b010: aluctr = 4'b0010;
					3'b011: aluctr = 4'b1010;
					3'b100: aluctr = 4'b0100;
					3'b101: aluctr = {func7[5], 3'b101};
					3'b110: aluctr = 4'b0110;
					3'b111: aluctr = 4'b0111;
				endcase
			end
			7'b0000011: begin					// I-load
				regwr    = 1'b1;
				alubsrc  = 2'b01;
				memtoreg = 1'b1;
				memop    = func3;
			end
			7'b0100011: begin					// S-store
				extop   = 3'b010;
				alubsrc = 2'b01;
				memwr   = 1'b1;
				memop   = func3;
			end
			7'b1100011: begin					// B-branch
				extop   = 3'b011;
				case (func3)
					3'b000: begin branch = 3'b100; aluctr = 4'b1000; end // BEQ
					3'b001: begin branch = 3'b101; aluctr = 4'b1000; end // BNE
					3'b100: begin branch = 3'b110; aluctr = 4'b0010; end // BLT
					3'b101: begin branch = 3'b111; aluctr = 4'b0010; end // BGE
					3'b110: begin branch = 3'b110; aluctr = 4'b1010; end // BLTU
					3'b111: begin branch = 3'b111; aluctr = 4'b1010; end // BGEU
				endcase
			end
			7'b1101111: begin					// J-jal
				extop   = 3'b100;
				regwr   = 1'b1;
				aluasrc = 1'b1;
				alubsrc = 2'b10;
				branch  = 3'b001;
			end
			7'b1100111: begin					// I-jalr
				regwr   = 1'b1;
				aluasrc = 1'b1;
				alubsrc = 2'b10;
				branch  = 3'b010;
			end
			7'b0110111: begin					// U-lui
				extop   = 3'b001;
				regwr   = 1'b1;
				alubsrc = 2'b01;
				aluctr  = 4'b0011;
			end
			7'b0010111: begin					// U-auipc
				extop   = 3'b001;
				regwr   = 1'b1;
				aluasrc = 1'b1;
				alubsrc = 2'b01;
			end
		endcase
	end

endmodule
