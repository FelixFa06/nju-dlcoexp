`timescale 1ns / 1ps
module tb_top;
    reg  [31:0] addr = 32'd0;
    reg  [31:0] datain = 32'd0;
    reg  [2:0]  memop = 3'd0;
    reg  we = 1'b0, rdclk = 1'b0, wrclk = 1'b0;
    wire [31:0] dataout;

    dmem uut(
        .addr(addr), .dataout(dataout), .datain(datain),
        .rdclk(rdclk), .wrclk(wrclk), .memop(memop), .we(we)
    );

    initial begin
        $dumpfile("build/top.vcd");
        $dumpvars(0, tb_top);
    end

    task wr(input [31:0] a, input [31:0] d, input [2:0] m);
        begin
            addr = a; datain = d; memop = m; we = 1'b1;
            #10 wrclk = 1'b1; #10 wrclk = 1'b0;
            #10 we = 1'b0;
        end
    endtask

    task rd(input [31:0] a, input [2:0] m);
        begin
            addr = a; memop = m;
            #10 rdclk = 1'b1; #10 rdclk = 1'b0;
            #10;
        end
    endtask

    initial begin
        // sw 0x11223344, lw / lb 读回
        wr(32'h00000010, 32'h11223344, 3'b010);
        rd(32'h00000010, 3'b010);   // dataout = 11223344
        rd(32'h00000011, 3'b000);   // lb  = 00000033
        rd(32'h00000013, 3'b000);   // lb  = 00000011

        // sb 0x80, 只有最低字节改变
        wr(32'h00000013, 32'h80808080, 3'b000);
        rd(32'h00000010, 3'b010);   // lw  = 80223344
        rd(32'h00000013, 3'b000);   // lb  = ffffff80
        rd(32'h00000013, 3'b100);   // lbu = 00000080

        // sh 0xabcd
        wr(32'h00000012, 32'h0000ABCD, 3'b001);
        rd(32'h00000010, 3'b010);   // lw  = abcd3344
        rd(32'h00000012, 3'b001);   // lh  = ffffabcd
        rd(32'h00000012, 3'b101);   // lhu = 0000abcd

        // 相邻字互不影响
        wr(32'h00000014, 32'hA5A5A5A5, 3'b010);
        rd(32'h00000014, 3'b010);   // lw  = a5a5a5a5
        rd(32'h00000010, 3'b010);   // lw  = abcd3344
        $finish;
    end
endmodule
