module top(
    input  wire CLK100MHZ,
    input  wire [15:0] SW,
    input  wire BTNC,
    input  wire BTNU,
    output wire CA, CB, CC, CD, CE, CF, CG, DP,
    output wire [7:0] AN
);

    // 时基模块
    wire tick_1ms, tick_10ms;
    tickgen #(.tick_freq(1000)) u_tick_1ms(//数码管扫描时基
        .clk(CLK100MHZ), .rst(1'b0), .en(1'b1), .tick(tick_1ms)
    );
    tickgen #(.tick_freq(100)) u_tick_10ms(//按键消抖时基
        .clk(CLK100MHZ), .rst(1'b0), .en(1'b1), .tick(tick_10ms)
    );

    // 按键消抖, 产生读/写时钟
    wire rdclk, wrclk;
    debounce u_rd(
        .clk(CLK100MHZ), .tick_10ms(tick_10ms), .btn(BTNC), .btn_edge(rdclk)
    );
    debounce u_wr(
        .clk(CLK100MHZ), .tick_10ms(tick_10ms), .btn(BTNU), .btn_edge(wrclk)
    );

    // 数据存储器
    wire [31:0] dout;
    dmem mymem(
        .addr   ({28'b0, SW[7:4]}),
        .dataout(dout),
        .datain ({4{SW[15:8]}}),
        .rdclk  (rdclk),
        .wrclk  (wrclk),
        .memop  (SW[2:0]),
        .we     (SW[3])
    );

    // 显示模块
    display8 u_display(
        .clk (CLK100MHZ),
        .tick(tick_1ms),
        .data(dout),
        .seg7(AN),
        .h({CG, CF, CE, CD, CC, CB, CA})
    );
    assign DP = 1'b1;

endmodule
