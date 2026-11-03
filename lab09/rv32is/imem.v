module imem(
    input  rdclk,
    input  en,
    input  [31:0] addr,
    output reg [31:0] dataout
);

    reg [31:0] ram[1023:0]; //4KB
    initial $readmemh("inst.hex", ram);

    always @(posedge rdclk)
        if (en)
            dataout <= ram[addr[11:2]];

endmodule
