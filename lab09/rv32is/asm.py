#!/usr/bin/env python3
"""最小 RV32I 汇编器：只覆盖本实验两个演示程序用到的指令。

用法: python asm.py [输出文件]
默认把 fib.s / prime.s 各补齐到 512 字，拼成 inst.hex（两个 bank）。
"""

import os
import re
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
BANK_WORDS = 512
SOURCES = ["fib.s", "prime.s"]

ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23,
    "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}

R_TYPE = {
    "add": (0b000, 0b0000000), "sub": (0b000, 0b0100000),
    "sll": (0b001, 0b0000000), "slt": (0b010, 0b0000000),
    "sltu": (0b011, 0b0000000), "xor": (0b100, 0b0000000),
    "srl": (0b101, 0b0000000), "sra": (0b101, 0b0100000),
    "or": (0b110, 0b0000000), "and": (0b111, 0b0000000),
}
I_TYPE = {"addi": 0b000, "slti": 0b010, "sltiu": 0b011,
          "xori": 0b100, "ori": 0b110, "andi": 0b111}
SHIFT = {"slli": (0b001, 0b0000000), "srli": (0b101, 0b0000000),
         "srai": (0b101, 0b0100000)}
BRANCH = {"beq": 0b000, "bne": 0b001, "blt": 0b100,
          "bge": 0b101, "bltu": 0b110, "bgeu": 0b111}
LOAD = {"lb": 0b000, "lh": 0b001, "lw": 0b010, "lbu": 0b100, "lhu": 0b101}
STORE = {"sb": 0b000, "sh": 0b001, "sw": 0b010}


def imm(s):
    s = s.strip()
    try:
        return int(s, 0)
    except ValueError:
        return int(s, 10)


def reg(s):
    s = s.strip()
    if s in ABI:
        return ABI[s]
    if re.fullmatch(r"x\d+", s):
        return int(s[1:])
    raise ValueError("bad register: " + s)


def r_type(f7, rs2, rs1, f3, rd, op=0x33):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def i_type(v, rs1, f3, rd, op):
    return ((v & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def s_type(v, rs2, rs1, f3, op=0x23):
    v &= 0xFFF
    return (((v >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | ((v & 0x1F) << 7) | op


def b_type(v, rs2, rs1, f3, op=0x63):
    v &= 0x1FFF
    return (((v >> 12) & 1) << 31) | (((v >> 5) & 0x3F) << 25) | \
           (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((v >> 1) & 0xF) << 8) | \
           (((v >> 11) & 1) << 7) | op


def u_type(v, rd, op):
    return ((v & 0xFFFFF) << 12) | (rd << 7) | op


def j_type(v, rd, op=0x6F):
    v &= 0x1FFFFF
    return (((v >> 20) & 1) << 31) | (((v >> 1) & 0x3FF) << 21) | \
           (((v >> 11) & 1) << 20) | (((v >> 12) & 0xFF) << 12) | (rd << 7) | op


def expand(m, o):
    if m == "li":
        rd, val = o[0], imm(o[1])
        if -2048 <= val <= 2047:
            return [("addi", [rd, "x0", str(val)])]
        hi = ((val + 0x800) >> 12) & 0xFFFFF
        lo = val - (hi << 12)
        return [("lui", [rd, str(hi)]), ("addi", [rd, rd, str(lo)])]
    if m == "mv":
        return [("addi", [o[0], o[1], "0"])]
    if m == "nop":
        return [("addi", ["x0", "x0", "0"])]
    if m == "j":
        return [("jal", ["x0", o[0]])]
    if m == "jr":
        return [("jalr", ["x0", o[0], "0"])]
    if m == "ret":
        return [("jalr", ["x0", "ra", "0"])]
    return [(m, o)]


def encode(m, o, labels, addr):
    if m in R_TYPE:
        f3, f7 = R_TYPE[m]
        return r_type(f7, reg(o[2]), reg(o[1]), f3, reg(o[0]))
    if m in I_TYPE:
        return i_type(imm(o[2]), reg(o[1]), I_TYPE[m], reg(o[0]), 0x13)
    if m in SHIFT:
        f3, f7 = SHIFT[m]
        return i_type((f7 << 5) | (imm(o[2]) & 0x1F), reg(o[1]), f3, reg(o[0]), 0x13)
    if m in LOAD:
        mo = re.fullmatch(r"(-?\w+)\s*\(\s*(\w+)\s*\)", o[1])
        return i_type(imm(mo.group(1)), reg(mo.group(2)), LOAD[m], reg(o[0]), 0x03)
    if m in STORE:
        mo = re.fullmatch(r"(-?\w+)\s*\(\s*(\w+)\s*\)", o[1])
        return s_type(imm(mo.group(1)), reg(o[0]), reg(mo.group(2)), STORE[m])
    if m in BRANCH:
        return b_type(labels[o[2]] - addr, reg(o[1]), reg(o[0]), BRANCH[m])
    if m == "jal":
        if len(o) == 1:
            rd, label = 1, o[0]
        else:
            rd, label = reg(o[0]), o[1]
        return j_type(labels[label] - addr, rd)
    if m == "jalr":
        if len(o) == 3:
            rd, rs1, off = reg(o[0]), reg(o[1]), imm(o[2])
        else:
            mo = re.fullmatch(r"(-?\w+)\s*\(\s*(\w+)\s*\)", o[1])
            rd, rs1, off = reg(o[0]), reg(mo.group(2)), imm(mo.group(1))
        return i_type(off, rs1, 0b000, rd, 0x67)
    if m == "lui":
        return u_type(imm(o[1]), reg(o[0]), 0x37)
    if m == "auipc":
        return u_type(imm(o[1]), reg(o[0]), 0x17)
    raise ValueError("unknown instruction: " + m)


def assemble(path):
    items = []
    for raw in open(path, encoding="utf-8"):
        line = raw.split("#")[0].split("//")[0].strip()
        while True:
            mm = re.match(r"^([A-Za-z_.$][\w.$]*)\s*:\s*(.*)$", line)
            if not mm:
                break
            items.append(("label", mm.group(1)))
            line = mm.group(2).strip()
        if not line or line.startswith("."):
            continue
        parts = line.replace(",", " ").split()
        items.append(("ins", parts[0].lower(), parts[1:]))

    prog = []
    for it in items:
        if it[0] == "label":
            prog.append(it)
        else:
            for m, o in expand(it[1], it[2]):
                prog.append(("ins", m, o))

    labels, addr = {}, 0
    for it in prog:
        if it[0] == "label":
            labels[it[1]] = addr
        else:
            addr += 4

    code, addr = [], 0
    for it in prog:
        if it[0] == "label":
            continue
        code.append(encode(it[1], it[2], labels, addr))
        addr += 4
    return code


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "inst.hex")
    words = []
    for name in SOURCES:
        code = assemble(os.path.join(BASE, name))
        if len(code) > BANK_WORDS:
            raise SystemExit(f"{name}: {len(code)} instructions > {BANK_WORDS}")
        print(f"{name}: {len(code)} instructions")
        words += code + [0] * (BANK_WORDS - len(code))
    with open(out, "w", encoding="utf-8") as f:
        for w in words:
            f.write(f"{w & 0xFFFFFFFF:08x}\n")
    print(f"wrote {out}: {len(words)} words")


if __name__ == "__main__":
    main()
