.text
# f(0)=0, f(1)=1, 结果 = f(n)，n 来自开关
        addi x1, x0, 0x100
        lw   x5, 0(x1)
        addi x6, x0, 0
        addi x7, x0, 1
        addi x8, x0, 0
loop:
        beq  x8, x5, done
        add  x9, x6, x7
        add  x6, x0, x7
        add  x7, x0, x9
        addi x8, x8, 1
        jal  x0, loop
done:
        sw   x6, 4(x1)
halt:
        jal  x0, halt
