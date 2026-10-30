module tickgen #(
    parameter integer tick_freq = 1000,
    parameter integer clk_freq  = 100_000_000
)(
    input  wire clk,
    input  wire rst,
    input  wire en,
    output reg  tick
);
    localparam integer countlimit = clk_freq / tick_freq - 1;

    reg [31:0] clkcount = 32'd0;

    always @(posedge clk) begin
        if (rst) begin
            clkcount <= 32'd0;
            tick     <= 1'b0;
        end
        else if (en) begin
            if (clkcount >= countlimit) begin
                clkcount <= 32'd0;
                tick     <= 1'b1;
            end
            else begin
                clkcount <= clkcount + 32'd1;
                tick     <= 1'b0;
            end
        end
        else
            tick <= 1'b0;
    end
endmodule
