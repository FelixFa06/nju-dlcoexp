module imem(
    input  rdclk,
    input  en,
    input  [31:0] addr,
    output reg [31:0] dataout
);

    reg [31:0] ram[255:0]; //1KB
    initial $readmemh("inst.hex", ram);

    always @(posedge rdclk)
        if (en)
            dataout <= ram[addr[9:2]];

endmodule
