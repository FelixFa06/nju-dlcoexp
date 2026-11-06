`timescale 1ns/1ps
module tb_top;

    reg clk = 0;
    always #5 clk = ~clk;

    reg  [15:0] SW = 16'd0;
    reg         BTNC = 1'b0;
    wire [15:0] LED;
    wire CA, CB, CC, CD, CE, CF, CG, DP;
    wire [7:0] AN;

    top u_top(
        .CLK100MHZ(clk), .SW(SW), .BTNC(BTNC), .LED(LED),
        .CA(CA), .CB(CB), .CC(CC), .CD(CD),
        .CE(CE), .CF(CF), .CG(CG), .DP(DP), .AN(AN)
    );

    // 仿真里把时基调快，避免等真实的 10 ms
    defparam u_top.u_tick_1ms.tick_freq  = 10_000_000;
    defparam u_top.u_tick_10ms.tick_freq = 10_000_000;

    task do_reset;
        begin
            SW[15] = 1'b1;
            repeat (10) @(posedge clk);
            SW[15] = 1'b0;
            repeat (10) @(posedge clk);
        end
    endtask

    task press;
        begin
            BTNC = 1'b1;
            repeat (40) @(posedge clk);
            BTNC = 1'b0;
            repeat (40) @(posedge clk);
        end
    endtask

    task steps;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                press;
        end
    endtask

    integer errors = 0;

    task check;
        input [31:0] got;
        input [31:0] want;
        input [255:0] name;
        begin
            if (got === want)
                $display("PASS %0s = %0d", name, got);
            else begin
                $display("FAIL %0s: got %0d (%h), want %0d", name, got, got, want);
                errors = errors + 1;
            end
        end
    endtask

    // ---- dmem 定向测试：字/字节/半字读写与扩展 ----
    reg  [31:0] dm_addr = 0;
    reg  [31:0] dm_din  = 0;
    reg  [2:0]  dm_op   = 0;
    reg         dm_we   = 0;
    wire [31:0] dm_dout;

    dmem u_dmem_tb(
        .addr(dm_addr),
        .dataout(dm_dout),
        .datain(dm_din),
        .rdclk(clk),
        .wrclk(clk),
        .memop(dm_op),
        .we(dm_we)
    );

    task dm_write;
        input [31:0] a;
        input [31:0] d;
        input [2:0]  op;
        begin
            dm_addr = a;
            dm_din  = d;
            dm_op   = op;
            dm_we   = 1'b1;
            @(posedge clk);
            #1;
            dm_we   = 1'b0;
        end
    endtask

    task dm_read;
        input [31:0]  a;
        input [2:0]   op;
        input [255:0] name;
        input [31:0]  want;
        begin
            dm_addr = a;
            dm_op   = op;
            @(posedge clk);
            #1;
            check(dm_dout, want, name);
        end
    endtask

    initial begin
        dm_we = 1'b0;
        dm_write(32'h10, 32'h12345678, 3'b010);
        dm_read (32'h10, 3'b010, "dmem word", 32'h12345678);
        dm_write(32'h11, 32'h000000AB, 3'b000);      // sb: byte 1
        dm_read (32'h10, 3'b010, "dmem sb  ", 32'h1234AB78);
        dm_write(32'h12, 32'h0000BEEF, 3'b001);      // sh: byte 2-3
        dm_read (32'h10, 3'b010, "dmem sh  ", 32'hBEEFAB78);
        dm_write(32'h20, 32'h000000FF, 3'b010);
        dm_read (32'h20, 3'b000, "dmem lb  ", 32'hFFFFFFFF);
        dm_read (32'h20, 3'b100, "dmem lbu ", 32'h000000FF);
        dm_write(32'h24, 32'h00008000, 3'b010);
        dm_read (32'h24, 3'b001, "dmem lh  ", 32'hFFFF8000);
        dm_read (32'h24, 3'b101, "dmem lhu ", 32'h00008000);
        $display("DMEM TESTS DONE");
    end

    initial begin
        // 斐波那契 f(10) = 55
        SW[13] = 1'b0;
        SW[11:0] = 12'd10;
        do_reset;
        steps(200);
        check(u_top.result, 32'd55, "fib(10)");

        // 素数 13 -> 1
        SW[13] = 1'b1;
        SW[11:0] = 12'd13;
        do_reset;
        steps(120);
        check(u_top.result, 32'd1, "prime(13)");

        // 素数 11 -> 1
        SW[11:0] = 12'd11;
        do_reset;
        steps(120);
        check(u_top.result, 32'd1, "prime(11)");

        // 素数 2 -> 1
        SW[11:0] = 12'd2;
        do_reset;
        steps(60);
        check(u_top.result, 32'd1, "prime(2)");

        // 素数 4 -> 0
        SW[11:0] = 12'd4;
        do_reset;
        steps(60);
        check(u_top.result, 32'd0, "prime(4)");

        // 素数 9 -> 0
        SW[11:0] = 12'd9;
        do_reset;
        steps(100);
        check(u_top.result, 32'd0, "prime(9)");

        // 素数 15 -> 0
        SW[11:0] = 12'd15;
        do_reset;
        steps(120);
        check(u_top.result, 32'd0, "prime(15)");

        // 素数 97 -> 1
        SW[11:0] = 12'd97;
        do_reset;
        steps(600);
        check(u_top.result, 32'd1, "prime(97)");

        // 素数 91 -> 0
        SW[11:0] = 12'd91;
        do_reset;
        steps(500);
        check(u_top.result, 32'd0, "prime(91)");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule
