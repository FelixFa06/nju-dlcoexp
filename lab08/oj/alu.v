module alu(
	input [31:0] dataa,
	input [31:0] datab,
	input [3:0]  ALUctr,
	output less,
	output zero,
	output reg [31:0] aluresult
);

    always @(*) begin
        casez (ALUctr)
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
    assign zero = ALUctr[2:0]==3'b010 ? dataa == datab : aluresult == 32'b0;

endmodule