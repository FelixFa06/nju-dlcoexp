.text
# 结果 = 1 表示素数，0 表示非素数，n 来自开关
        addi x1, x0, 0x100
        lw   x5, 0(x1)
        addi x6, x0, 0
        addi x10, x0, 2
        blt  x5, x10, done
        addi x7, x0, 2
        addi x8, x0, 4
        addi x9, x0, 5
outer:
        blt  x5, x8, prime
        add  x10, x0, x5
mod:
        sub  x10, x10, x7
        bge  x10, x7, mod
        beq  x10, x0, done
        addi x7, x7, 1
        add  x8, x8, x9
        addi x9, x9, 2
        jal  x0, outer
prime:
        addi x6, x0, 1
done:
        sw   x6, 4(x1)
halt:
        jal  x0, halt
