#!/usr/bin/env python3
# tools/assembler.py
"""
Tiny RV32I subset assembler with labels.

Supported instructions (case-insensitive):

R-type:
  ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA

I-type:
  ADDI, ANDI, ORI, XORI, SLTI, SLTIU,
  SLLI, SRLI, SRAI,
  LW,
  JALR rd, imm(rs1)

S-type:
  SW

B-type:
  BEQ, BNE, BLT, BGE, BLTU, BGEU

U-type:
  LUI, AUIPC

J-type:
  JAL label
  JAL rd, label
  J label               (alias: JAL x0,label)

Pseudos:
  NOP                   -> ADDI x0, x0, 0
  MV  rd, rs            -> ADDI rd, rs, 0
  LI  rd, imm           -> (best-effort) small immed via ADDI, else LUI+ADDI

Directives:
  .org <addr>           # set PC (byte address)
  .word <32b int>       # emit raw word
  .text / .globl ...    # accepted and ignored

Registers:
  x0..x31 and ABI names: zero, ra, sp, gp, tp, t0..t6, s0/fp, s1, a0..a7, s2..s11

Usage (standalone):
  python tools/assembler.py program.s > program.hex
"""

from typing import List, Dict, Tuple
import re

# ---------------- Register map ----------------
ABI = {
    "zero":0, "ra":1, "sp":2, "gp":3, "tp":4,
    "t0":5, "t1":6, "t2":7,
    "s0":8, "fp":8, "s1":9,
    "a0":10, "a1":11, "a2":12, "a3":13, "a4":14, "a5":15, "a6":16, "a7":17,
    "s2":18, "s3":19, "s4":20, "s5":21, "s6":22, "s7":23, "s8":24, "s9":25, "s10":26, "s11":27,
    "t3":28, "t4":29, "t5":30, "t6":31,
}
for i in range(32):
    ABI[f"x{i}"] = i

# ---------------- Helpers ----------------
def parse_int(x: str) -> int:
    x = x.replace('_', '')
    return int(x, 0)  # 0x.., 0b.., 0o.., or decimal

def imm_in_range(val: int, bits: int, signed=True) -> bool:
    if signed:
        lo = -(1 << (bits - 1))
        hi = (1 << (bits - 1)) - 1
        return lo <= val <= hi
    return 0 <= val < (1 << bits)

def reg_id(name: str) -> int:
    n = name.lower()
    if n not in ABI:
        raise ValueError(f"Unknown register
