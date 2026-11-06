// lab09 最小上板版本：单步执行 Fibonacci / 素数判断
// SW[15]   复位（拨上去再拨下来）
// SW[13]   程序选择：0 = 斐波那契，1 = 素数
// SW[11:0] 参数 n
// BTNC     单步按键
// LED      当前 PC 低 16 位
// 七段显示 高 4 位 = 输入参数，低 4 位 = 结果（十六进制）
module top(
    input wire CLK100MHZ,
    input wire [15:0] SW,
    input wire BTNC,
    output wire [15:0] LED,
    output wire CA,CB,CC,CD,CE,CF,CG,DP,
    output wire [7:0] AN
);

    //时基生成模块
    wire tick_1ms, tick_10ms;
    tickgen #(.tick_freq(1000)) u_tick_1ms(//数码管扫描时基
        .clk(CLK100MHZ), .rst(1'b0), .en(1'b1), .tick(tick_1ms)
    );
    tickgen #(.tick_freq(100)) u_tick_10ms(//按键消抖时基
        .clk(CLK100MHZ), .rst(1'b0), .en(1'b1), .tick(tick_10ms)
    );

    //按键消抖模块
    wire step_en;
    debounce u_btnc(
        .clk(CLK100MHZ),
        .tick_10ms(tick_10ms),
        .btn(BTNC),
        .btn_edge(step_en)
    );

    //复位
    wire reset;
    assign reset = SW[15];

    //核心逻辑-RV32I CPU
    wire [31:0] imemaddr, imemdataout;
    wire [31:0] dmemaddr, dmemdataout, dmemdatain;
    wire imemclk, dmemrdclk, dmemwrclk, dmemwe;
    wire [2:0] dmemop;
    wire [31:0] pc;

    rv32is u_cpu(
        .clock(CLK100MHZ),
        .reset(reset),
        .en(step_en),
        .imemaddr(imemaddr),
        .imemdataout(imemdataout),
        .imemclk(imemclk),
        .dmemaddr(dmemaddr),
        .dmemdataout(dmemdataout),
        .dmemdatain(dmemdatain),
        .dmemrdclk(dmemrdclk),
        .dmemwrclk(dmemwrclk),
        .dmemop(dmemop),
        .dmemwe(dmemwe),
        .dbgdata(pc)
    );

    //指令存储器，两个程序各占 512 B（128 条指令）
    wire [31:0] imemaddr_bank;
    assign imemaddr_bank = {22'b0, SW[13], imemaddr[8:0]};

    imem u_imem(
        .rdclk(imemclk),
        .en(step_en | reset),
        .addr(imemaddr_bank),
        .dataout(imemdataout)
    );

    //MMIO：0x100 读开关，0x104 写结果
    wire sel_sw, sel_result;
    assign sel_sw     = (dmemaddr == 32'h0000_0100);
    assign sel_result = (dmemaddr == 32'h0000_0104);

    //数据存储器
    wire [31:0] dout;
    dmem mymem(
        .addr(dmemaddr),
        .dataout(dout),
        .datain(dmemdatain),
        .rdclk(dmemrdclk),
        .wrclk(dmemwrclk),
        .memop(dmemop),
        .we(dmemwe & ~sel_sw & ~sel_result)
    );

    assign dmemdataout = sel_sw ? {20'b0, SW[11:0]} : dout;

    //结果寄存器
    reg [31:0] result;
    always @(posedge dmemwrclk)
        if (reset)
            result <= 32'd0;
        else if (sel_result && dmemwe)
            result <= dmemdatain;

    //显示
    assign LED = pc[15:0];

    display8 u_display(
        .clk(CLK100MHZ),
        .tick(tick_1ms),
        .data({4'h0, SW[11:0], result[15:0]}),
        .seg7(AN),
        .h({CG, CF, CE, CD, CC, CB, CA})
    );
    assign DP = 1'b1;

endmodule
