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
        raise ValueError(f"Unknown register '{name}'")
    return ABI[n]

def parse_off_base(expr: str) -> Tuple[int,int]:
    # imm(rs1), e.g. 0(x1) or 16(s0)
    m = re.match(r'^\s*([\-+]?(?:0x[0-9a-fA-F]+|\d+))\s*\(\s*([A-Za-z0-9]+)\s*\)\s*$', expr)
    if not m:
        raise ValueError(f"Bad offset(base) syntax: '{expr}'")
    imm = parse_int(m.group(1))
    rs1 = reg_id(m.group(2))
    return imm, rs1

def enc_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def enc_i(imm, rs1, funct3, rd, opcode):
    imm &= 0xFFF
    return (imm << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def enc_s(imm, rs2, rs1, funct3, opcode):
    imm &= 0xFFF
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0  = imm & 0x1F
    return (imm_11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | (imm_4_0 << 7) | (opcode & 0x7F)

def enc_b(offset, rs2, rs1, funct3, opcode):
    # PC-relative byte offset; must be even (LSB implicit zero)
    if (offset % 2) != 0:
        raise ValueError(f"Branch offset not 2-byte aligned: {offset}")
    if not (-4096 <= offset <= 4094):
        raise ValueError(f"Branch offset out of range: {offset}")
    bit12    = (offset >> 12) & 0x1
    bits10_5 = (offset >> 5) & 0x3F
    bits4_1  = (offset >> 1) & 0xF
    bit11    = (offset >> 11) & 0x1
    return (bit12 << 31) | (bits10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | (bits4_1 << 8) | (bit11 << 7) | (opcode & 0x7F)

def enc_u(imm, rd, opcode):
    # upper 20 bits; lower 12 are zero
    return ((imm & 0xFFFFF000)) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def enc_j(offset, rd, opcode):
    if (offset % 2) != 0:
        raise ValueError(f"JAL offset not 2-byte aligned: {offset}")
    if not (-1048576 <= offset <= 1048574):
        raise ValueError(f"JAL offset out of range: {offset}")
    bit20     = (offset >> 20) & 0x1
    bits10_1  = (offset >> 1)  & 0x3FF
    bit11     = (offset >> 11) & 0x1
    bits19_12 = (offset >> 12) & 0xFF
    return (bit20 << 31) | (bits19_12 << 12) | (bit11 << 20) | (bits10_1 << 21) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

class Item:
    def __init__(self, op:str, args:List[str], line:int, pc:int):
        self.op   = op.upper()
        self.args = args
        self.line = line
        self.pc   = pc

def tokenize(line: str) -> Tuple[str, List[str]]:
    # strip EOL comments (#, //, ;)
    s = line
    if '//' in s: s = s.split('//',1)[0]
    if '#'  in s: s = s.split('#',1)[0]
    if ';'  in s: s = s.split(';',1)[0]
    s = s.strip()
    if not s: return ("", [])
    # pure label?
    if s.endswith(':'):
        return (s, [])
    parts = s.replace(',', ' ').split()
    return (parts[0], parts[1:])

def assemble_to_words(source_text: str) -> List[int]:
    lines = source_text.splitlines()
    labels: Dict[str,int] = {}
    items: List[Item] = []
    pc = 0

    # ----- Pass 1: gather labels & items -----
    for ln, raw in enumerate(lines, 1):
        txt = raw.strip()
        # quick strip for label/directive detection
        cut = txt
        for c in ('//', '#', ';'):
            if c in cut:
                cut = cut.split(c,1)[0]
        cut = cut.strip()
        if not cut:
            continue

        if cut.endswith(':'):
            lab = cut[:-1].strip()
            if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', lab):
                raise ValueError(f"Line {ln}: invalid label '{lab}'")
            if lab in labels:
                raise ValueError(f"Line {ln}: duplicate label '{lab}'")
            labels[lab] = pc
            continue

        head = cut.split()[0].lower()
        if head == '.org':
            try:
                pc = parse_int(cut.split()[1])
            except Exception:
                raise ValueError(f"Line {ln}: .org requires an address")
            continue
        if head == '.word':
            # keep as a normal item at current pc
            try:
                val = parse_int(cut.split()[1]) & 0xFFFFFFFF
            except Exception:
                raise ValueError(f"Line {ln}: .word requires a 32-bit value")
            items.append(Item('.word', [str(val)], ln, pc))
            pc += 4
            continue
        if head in ('.text', '.globl', '.global', '.section'):
            continue

        op, args = tokenize(cut)
        if not op:
            continue
        items.append(Item(op, args, ln, pc))
        pc += 4

    # ----- Pass 2: encode -----
    out: List[int] = []

    def enc_logic_r(op, args, funct3, funct7):
        if len(args) != 3: raise ValueError(f"{op} expects rd, rs1, rs2")
        rd, rs1, rs2 = reg_id(args[0]), reg_id(args[1]), reg_id(args[2])
        return enc_r(funct7, rs2, rs1, funct3, rd, 0b0110011)

    def enc_shift_r(op, args, funct3, funct7):
        return enc_logic_r(op, args, funct3, funct7)

    def enc_arith_i(op, args, funct3):
        if len(args) != 3: raise ValueError(f"{op} expects rd, rs1, imm12")
        rd, rs1 = reg_id(args[0]), reg_id(args[1])
        imm = parse_int(args[2])
        if not imm_in_range(imm, 12, signed=True):
            raise ValueError(f"{op} immediate out of 12-bit signed range")
        return enc_i(imm, rs1, funct3, rd, 0b0010011)

    def enc_shift_i(op, args, funct3, funct7):
        if len(args) != 3: raise ValueError(f"{op} expects rd, rs1, shamt")
        rd, rs1 = reg_id(args[0]), reg_id(args[1])
        shamt = parse_int(args[2])
        if not (0 <= shamt <= 31):
            raise ValueError(f"{op} shamt 0..31 required")
        imm = (funct7 << 5) | (shamt & 0x1F)
        return enc_i(imm, rs1, funct3, rd, 0b0010011)

    for it in items:
        try:
            op = it.op
            a  = it.args

            # Pseudos
            if op == 'NOP':
                op, a = 'ADDI', ['x0','x0','0']
            elif op == 'MV':
                if len(a) != 2: raise ValueError("MV expects rd, rs")
                op, a = 'ADDI', [a[0], a[1], '0']
            elif op == 'LI':
                # Best-effort LI: try ADDI if fits; else LUI+ADDI sequence.
                if len(a) != 2: raise ValueError("LI expects rd, imm")
                rd = reg_id(a[0])
                imm = parse_int(a[1])
                if imm_in_range(imm, 12, signed=True):
                    out.append(enc_i(imm, 0, 0b000, rd, 0b0010011))  # ADDI rd, x0, imm
                else:
                    upper = (imm + (1<<11)) & 0xFFFFF000  # round to nearest for sign-friendly split
                    lower = imm - upper
                    # LUI rd, upper20
                    out.append(enc_u(upper, rd, 0b0110111))
                    if lower != 0:
                        if not imm_in_range(lower, 12, signed=True):
                            raise ValueError("LI lower 12-bit out of range after split")
                        out.append(enc_i(lower, rd, 0b000, rd, 0b0010011))  # ADDI rd, rd, lower
                continue

            # Direct word
            if op == '.word':
                out.append(parse_int(a[0]) & 0xFFFFFFFF)
                continue

            # R-type
            if op in ('ADD','SUB'):
                funct7 = 0b0100000 if op=='SUB' else 0b0000000
                out.append(enc_logic_r(op,a,0b000,funct7)); continue
            if op == 'AND':
                out.append(enc_logic_r(op,a,0b111,0b0000000)); continue
            if op == 'OR':
                out.append(enc_logic_r(op,a,0b110,0b0000000)); continue
            if op == 'XOR':
                out.append(enc_logic_r(op,a,0b100,0b0000000)); continue
            if op == 'SLT':
                out.append(enc_logic_r(op,a,0b010,0b0000000)); continue
            if op == 'SLTU':
                out.append(enc_logic_r(op,a,0b011,0b0000000)); continue
            if op == 'SLL':
                out.append(enc_shift_r(op,a,0b001,0b0000000)); continue
            if op == 'SRL':
                out.append(enc_shift_r(op,a,0b101,0b0000000)); continue
            if op == 'SRA':
                out.append(enc_shift_r(op,a,0b101,0b0100000)); continue

            # I-type (arith/logical)
            if op == 'ADDI':
                out.append(enc_arith_i(op,a,0b000)); continue
            if op == 'ANDI':
                out.append(enc_arith_i(op,a,0b111)); continue
            if op == 'ORI':
                out.append(enc_arith_i(op,a,0b110)); continue
            if op == 'XORI':
                out.append(enc_arith_i(op,a,0b100)); continue
            if op == 'SLTI':
                out.append(enc_arith_i(op,a,0b010)); continue
            if op == 'SLTIU':
                # For SLTIU, immediate is still signed in encoding, but comparison is unsigned
                out.append(enc_arith_i(op,a,0b011)); continue

            # I-type shifts
            if op == 'SLLI':
                out.append(enc_shift_i(op,a,0b001,0b0000000)); continue
            if op == 'SRLI':
                out.append(enc_shift_i(op,a,0b101,0b0000000)); continue
            if op == 'SRAI':
                out.append(enc_shift_i(op,a,0b101,0b0100000)); continue

            # Loads
            if op == 'LW':
                if len(a)!=2: raise ValueError("LW expects rd, imm(rs1)")
                rd = reg_id(a[0]); imm, rs1 = parse_off_base(a[1])
                if not imm_in_range(imm,12,True): raise ValueError("LW offset out of 12-bit signed range")
                out.append(enc_i(imm, rs1, 0b010, rd, 0b0000011)); continue

            # Stores
            if op == 'SW':
                if len(a)!=2: raise ValueError("SW expects rs2, imm(rs1)")
                rs2 = reg_id(a[0]); imm, rs1 = parse_off_base(a[1])
                if not imm_in_range(imm,12,True): raise ValueError("SW offset out of 12-bit signed range")
                out.append(enc_s(imm, rs2, rs1, 0b010, 0b0100011)); continue

            # Branches
            if op in ('BEQ','BNE','BLT','BGE','BLTU','BGEU'):
                if len(a)!=3: raise ValueError(f"{op} expects rs1, rs2, label")
                rs1, rs2 = reg_id(a[0]), reg_id(a[1])
                lab = a[2]
                if lab not in labels: raise ValueError(f"Unknown label '{lab}'")
                target = labels[lab]
                offset = target - it.pc
                f3 = {'BEQ':0b000,'BNE':0b001,'BLT':0b010,'BGE':0b101,'BLTU':0b011,'BGEU':0b111}[op]
                out.append(enc_b(offset, rs2, rs1, f3, 0b1100011)); continue

            # Jumps
            if op == 'J':
                if len(a)!=1: raise ValueError("J expects label")
                lab = a[0]
                if lab not in labels: raise ValueError(f"Unknown label '{lab}'")
                offset = labels[lab] - it.pc
                out.append(enc_j(offset, 0, 0b1101111)); continue

            if op == 'JAL':
                if len(a)==1:
                    rd = ABI['ra']; lab = a[0]
                elif len(a)==2:
                    rd = reg_id(a[0]); lab = a[1]
                else:
                    raise ValueError("JAL expects label OR rd,label")
                if lab not in labels: raise ValueError(f"Unknown label '{lab}'")
                offset = labels[lab] - it.pc
                out.append(enc_j(offset, rd, 0b1101111)); continue

            if op == 'JALR':
                # JALR rd, imm(rs1)
                if len(a)!=2: raise ValueError("JALR expects rd, imm(rs1)")
                rd = reg_id(a[0]); imm, rs1 = parse_off_base(a[1])
                if not imm_in_range(imm,12,True): raise ValueError("JALR imm out of 12-bit signed range")
                out.append(enc_i(imm, rs1, 0b000, rd, 0b1100111)); continue

            # U-type
            if op == 'LUI':
                if len(a)!=2: raise ValueError("LUI expects rd, imm20<<12")
                rd = reg_id(a[0]); imm = parse_int(a[1])
                out.append(enc_u(imm, rd, 0b0110111)); continue

            if op == 'AUIPC':
                if len(a)!=2: raise ValueError("AUIPC expects rd, imm20<<12")
                rd = reg_id(a[0]); imm = parse_int(a[1])
                out.append(enc_u(imm, rd, 0b0010111)); continue

            raise ValueError(f"Unsupported instruction '{op}'")

        except Exception as e:
            raise ValueError(f"Line {it.line} (pc=0x{it.pc:08X}) {it.op} {' '.join(it.args)}: {e}")

    return [w & 0xFFFFFFFF for w in out]

# Standalone: assemble file to hex on stdout
if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python tools/assembler.py <input.s>", file=sys.stderr)
        sys.exit(2)
    src = open(sys.argv[1], "r", encoding="utf-8").read()
    try:
        words = assemble_to_words(src)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    for w in words:
        print(f"{w:08X}")
