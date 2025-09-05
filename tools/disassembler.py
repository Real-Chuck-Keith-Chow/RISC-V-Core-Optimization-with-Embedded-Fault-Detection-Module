#!/usr/bin/env python3
"""
disassembler.py — RV32I subset disassembler (pairs with tools/assembler.py)

Supported opcodes:
  R-type:   ADD,SUB,AND,OR,XOR,SLT,SLTU,SLL,SRL,SRA
  I-type:   ADDI,ANDI,ORI,XORI,SLTI,SLTIU, SLLI,SRLI,SRAI, LW, JALR
  S-type:   SW
  B-type:   BEQ,BNE,BLT,BGE,BLTU,BGEU
  U-type:   LUI,AUIPC
  J-type:   JAL

Features:
  - Reads .hex (one 32-bit word per line, with/without 0x, comments allowed) OR --bin raw little-endian
  - Optional label generation for branch/jump targets
  - Optional ABI register names (ra, sp, a0, …) or xN form
  - Configurable base address for PC (default 0)

Usage:
  # From HEX (default, labels on, xN registers)
  python tools/disassembler.py -i tb/prog_hazard.hex

  # From binary, with ABI reg names and base at 0x80000000
  python tools/disassembler.py -i fw.bin --bin --abi --base 0x80000000

  # Disable labels, always print offsets
  python tools/disassembler.py -i tb/prog_branch_flush.hex --no-labels
"""

from __future__ import annotations
import argparse, struct, sys, re
from pathlib import Path
from typing import List, Dict, Tuple

ABI = {
    0:"zero",1:"ra",2:"sp",3:"gp",4:"tp",5:"t0",6:"t1",7:"t2",
    8:"s0",9:"s1",10:"a0",11:"a1",12:"a2",13:"a3",14:"a4",15:"a5",
    16:"a6",17:"a7",18:"s2",19:"s3",20:"s4",21:"s5",22:"s6",23:"s7",
    24:"s8",25:"s9",26:"s10",27:"s11",28:"t3",29:"t4",30:"t5",31:"t6"
}

def reg_name(idx:int, use_abi:bool)->str:
    return ABI[idx] if use_abi else f"x{idx}"

def bits(x:int, hi:int, lo:int)->int:
    return (x >> lo) & ((1<<(hi-lo+1)) - 1)

def sign_extend(x:int, bits_count:int)->int:
    sign_bit = 1 << (bits_count-1)
    return (x & (sign_bit-1)) - (x & sign_bit)

def load_hex_words(path:Path)->List[int]:
    out=[]
    with path.open("r", encoding="utf-8") as f:
        for ln,line in enumerate(f,1):
            s=line.strip()
            # strip comments (# // ;)
            s=s.split("//",1)[0].split("#",1)[0].split(";",1)[0].strip()
            if not s: continue
            if s.lower().startswith("0x"): s=s[2:]
            try:
                v=int(s,16) & 0xFFFFFFFF
            except Exception:
                raise ValueError(f"{path}:{ln}: not a hex word: {line.strip()}")
            out.append(v)
    return out

def load_bin_words(path:Path, little_endian=True)->List[int]:
    data=path.read_bytes()
    if len(data)%4!=0: raise ValueError("Binary length must be multiple of 4.")
    fmt="<I" if little_endian else ">I"
    return [struct.unpack_from(fmt, data, i)[0] for i in range(0,len(data),4)]

# -------- immediate assemblers for encodings --------
def imm_b(instr:int)->int:
    # B-type 13-bit: imm[12|10:5|4:1|11|0] with bit0=0
    imm12 = (instr >> 31) & 0x1
    imm11 = (instr >> 7)  & 0x1
    imm10_5 = (instr >> 25) & 0x3F
    imm4_1  = (instr >> 8)  & 0xF
    v = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1)
    return sign_extend(v, 13)

def imm_j(instr:int)->int:
    # J-type 21-bit: [20|10:1|11|19:12] with bit0=0
    bit20    = (instr >> 31) & 0x1
    bits10_1 = (instr >> 21) & 0x3FF
    bit11    = (instr >> 20) & 0x1
    bits19_12= (instr >> 12) & 0xFF
    v = (bit20 << 20) | (bits19_12 << 12) | (bit11 << 11) | (bits10_1 << 1)
    return sign_extend(v, 21)

def imm_i(instr:int)->int:
    return sign_extend(bits(instr,31,20), 12)

def imm_s(instr:int)->int:
    imm = ((bits(instr,31,25) << 5) | bits(instr,11,7)) & 0xFFF
    return sign_extend(imm, 12)

def u_imm(instr:int)->int:
    return instr & 0xFFFFF000

# -------- disassembly core --------
def disassemble(words:List[int], base:int=0, labels:bool=True, use_abi:bool=False)->List[str]:
    # First pass: determine potential label targets (branch & jump)
    targets:set[int] = set()
    pc = base
    for w in words:
        opc = w & 0x7F
        if opc == 0x63:  # B-type
            off = imm_b(w)
            targets.add(pc + off)
        elif opc == 0x6F:  # JAL
            off = imm_j(w)
            targets.add(pc + off)
        pc += 4

    # assign label names in order of appearance
    addr_to_label: Dict[int,str] = {}
    if labels:
        # only label addresses that align to instruction boundaries in this range
        program_addrs = {base + 4*i for i in range(len(words))}
        lab_id=0
        for a in sorted(t for t in targets if t in program_addrs):
            addr_to_label[a] = f"L{lab_id}"
            lab_id += 1

    # Second pass: emit lines
    lines: List[str] = []
    pc = base
    for i,w in enumerate(words):
        if labels and pc in addr_to_label:
            lines.append(f"{addr_to_label[pc]}:")
        asm = decode_one(w, pc, addr_to_label, use_abi)
        lines.append(f"  {asm}    # @{pc:#010x}  [{w:08X}]")
        pc += 4
    return lines

def decode_one(w:int, pc:int, addr_to_label:Dict[int,str], use_abi:bool)->str:
    opc = w & 0x7F
    rd  = bits(w,11,7)
    funct3 = bits(w,14,12)
    rs1 = bits(w,19,15)
    rs2 = bits(w,24,20)
    funct7 = bits(w,31,25)

    r = lambda x: reg_name(x, use_abi)

    if opc == 0x33:  # R-type
        table = {
            (0b000,0b0000000): "ADD",
            (0b000,0b0100000): "SUB",
            (0b111,0b0000000): "AND",
            (0b110,0b0000000): "OR",
            (0b100,0b0000000): "XOR",
            (0b010,0b0000000): "SLT",
            (0b011,0b0000000): "SLTU",
            (0b001,0b0000000): "SLL",
            (0b101,0b0000000): "SRL",
            (0b101,0b0100000): "SRA",
        }
        mnem = table.get((funct3,funct7))
        if mnem:
            return f"{mnem} {r(rd)}, {r(rs1)}, {r(rs2)}"

    elif opc == 0x13:  # I-type arith/shift
        if funct3 in (0b001, 0b101):  # shifts with shamt
            shamt = bits(w,24,20)
            if funct3 == 0b001 and funct7 == 0b0000000:
                return f"SLLI {r(rd)}, {r(rs1)}, {shamt}"
            if funct3 == 0b101 and funct7 == 0b0000000:
                return f"SRLI {r(rd)}, {r(rs1)}, {shamt}"
            if funct3 == 0b101 and funct7 == 0b0100000:
                return f"SRAI {r(rd)}, {r(rs1)}, {shamt}"
        else:
            imm = imm_i(w)
            tbl = {0b000:"ADDI",0b111:"ANDI",0b110:"ORI",0b100:"XORI",0b010:"SLTI",0b011:"SLTIU"}
            mnem = tbl.get(funct3)
            if mnem:
                return f"{mnem} {r(rd)}, {r(rs1)}, {imm}"

    elif opc == 0x03:  # loads
        if funct3 == 0b010:  # LW
            imm = imm_i(w)
            return f"LW {r(rd)}, {imm}({r(rs1)})"

    elif opc == 0x23:  # stores
        if funct3 == 0b010:  # SW
            imm = imm_s(w)
            return f"SW {r(rs2)}, {imm}({r(rs1)})"

    elif opc == 0x63:  # branches
        imm = imm_b(w)
        target = pc + imm
        lbl = addr_to_label.get(target, f"{imm:+d}")
        m = {0b000:"BEQ",0b001:"BNE",0b010:"BLT",0b101:"BGE",0b011:"BLTU",0b111:"BGEU"}.get(funct3)
        if m:
            if isinstance(lbl, str) and lbl.startswith("L"):
                return f"{m} {r(rs1)}, {r(rs2)}, {lbl}"
            else:
                return f"{m} {r(rs1)}, {r(rs2)}, {lbl}"

    elif opc == 0x6F:  # JAL
        off = imm_j(w)
        target = pc + off
        lbl = addr_to_label.get(target, f"{off:+d}")
        # Pretty print: if rd==x0 -> J label; if rd==ra -> JAL label; else JAL rd,label
        if rd == 0:
            return f"J {lbl}"
        if rd == 1:
            return f"JAL {lbl}"
        return f"JAL {r(rd)}, {lbl}"

    elif opc == 0x67:  # JALR
        imm = imm_i(w)
        return f"JALR {r(rd)}, {imm}({r(rs1)})"

    elif opc == 0x37:  # LUI
        imm = u_imm(w)
        return f"LUI {r(rd)}, {imm:#x}"

    elif opc == 0x17:  # AUIPC
        imm = u_imm(w)
        return f"AUIPC {r(rd)}, {imm:#x}"

    # Unknown -> emit .word
    return f".word 0x{w:08X}"

def main():
    ap = argparse.ArgumentParser(description="RV32I subset disassembler.")
    ap.add_argument("-i","--input", required=True, help="Input .hex (default) or --bin raw file")
    ap.add_argument("--bin", action="store_true", help="Treat input as raw binary of 32-bit little-endian words")
    ap.add_argument("--big-endian", action="store_true", help="When --bin is used, interpret words as big-endian")
    ap.add_argument("--base", type=lambda x:int(x,0), default=0, help="Base PC address for first word (default 0)")
    ap.add_argument("--no-labels", action="store_true", help="Disable label generation")
    ap.add_argument("--abi", action="store_true", help="Use ABI register names instead of xN")
    args = ap.parse_args()

    path = Path(args.input)
    if not path.exists():
        print(f"ERROR: input not found: {path}", file=sys.stderr); sys.exit(2)

    try:
        if args.bin:
            words = load_bin_words(path, little_endian=not args.big_endian)
        else:
            words = load_hex_words(path)
    except Exception as e:
        print(f"ERROR reading {path}: {e}", file=sys.stderr); sys.exit(3)

    lines = disassemble(words, base=args.base, labels=not args.no_labels, use_abi=args.abi)
    for ln in lines:
        print(ln)

if __name__ == "__main__":
    main()
