#!/usr/bin/env python3
"""
memory_init_generator.py — generate $readmemh-compatible .hex/.mem files

Inputs supported:
  1) Raw hex text:      one 32-bit word per line, e.g.    00000013  or  0x00000013
  2) JSON list:         e.g. [0, 0x13, 0x002081b3, ...]
  3) Binary blob:       use --bin with a .bin file (reads little-endian 32-bit words)
  4) Assembly (.s):     if tools/assembler.py exists and supports 'assemble_to_words(str)'

Usage examples:
  # From hex text to prog_basic.hex, pad to 256 words with NOP
  python tools/memory_init_generator.py -i tb/prog_basic.txt -o tb/prog_basic.hex --depth 256

  # From JSON list, output .mem
  python tools/memory_init_generator.py -i programs/hazard.json -o tb/prog_hazard.mem

  # From binary blob (little-endian words)
  python tools/memory_init_generator.py --bin programs/firmware.bin -o tb/firmware.hex

  # From assembly (if assembler.py present)
  python tools/memory_init_generator.py -i programs/branch_flush.s -o tb/prog_branch_flush.hex --depth 512

Notes:
  - Default fill is RISC-V NOP (ADDI x0,x0,0 = 0x00000013).
  - Output words are printed as 8 hex chars, uppercase, one per line.
"""

import argparse
import json
import os
import struct
import sys
from typing import List, Optional

DEFAULT_FILL = 0x00000013  # RISC-V NOP (ADDI x0, x0, 0)

def load_words_from_hex_text(path: str) -> List[int]:
    words = []
    with open(path, "r", encoding="utf-8") as f:
        for ln, line in enumerate(f, 1):
            s = line.strip().split("#", 1)[0]  # allow trailing comments
            if not s:
                continue
            if s.lower().startswith("0x"):
                s = s[2:]
            try:
                v = int(s, 16)
            except ValueError as e:
                raise ValueError(f"{path}:{ln}: not a hex word: {line.strip()}") from e
            if v < 0 or v > 0xFFFFFFFF:
                raise ValueError(f"{path}:{ln}: out of 32-bit range: 0x{v:08X}")
            words.append(v)
    return words

def load_words_from_json(path: str) -> List[int]:
    with open(path, "r", encoding="utf-8") as f:
        arr = json.load(f)
    if not isinstance(arr, list):
        raise ValueError("JSON must be a list of integers")
    words = []
    for i, x in enumerate(arr):
        if not isinstance(x, int):
            raise ValueError(f"JSON index {i} is not int: {x}")
        if x < 0 or x > 0xFFFFFFFF:
            raise ValueError(f"JSON index {i} out of 32-bit range: {x}")
        words.append(x & 0xFFFFFFFF)
    return words

def load_words_from_bin(path: str, little_endian: bool = True) -> List[int]:
    data = open(path, "rb").read()
    if len(data) % 4 != 0:
        raise ValueError("Binary length must be a multiple of 4 bytes (32-bit words).")
    words = []
    fmt = "<I" if little_endian else ">I"
    for i in range(0, len(data), 4):
        (w,) = struct.unpack(fmt, data[i:i+4])
        words.append(w)
    return words

def try_load_assembler():
    """
    Attempt to import optional tools/assembler.py.
    Expect it to expose:
        assemble_to_words(source_text: str) -> List[int]
    """
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "tools")))
    try:
        import assembler  # type: ignore
        if hasattr(assembler, "assemble_to_words"):
            return assembler
        return None
    except Exception:
        return None

def load_words_from_assembly(path: str) -> List[int]:
    assembler = try_load_assembler()
    if assembler is None:
        raise RuntimeError("assembler.py not found or missing assemble_to_words().")
    src = open(path, "r", encoding="utf-8").read()
    words = assembler.assemble_to_words(src)  # user-supplied assembler function
    if not isinstance(words, list) or not all(isinstance(w, int) for w in words):
        raise ValueError("assembler.assemble_to_words() must return List[int].")
    # Clamp to 32-bit
    return [w & 0xFFFFFFFF for w in words]

def detect_input_mode(path: str, use_bin: bool) -> str:
    if use_bin:
        return "bin"
    ext = os.path.splitext(path)[1].lower()
    if ext in (".json",):
        return "json"
    if ext in (".s", ".asm"):
        return "asm"
    # default: treat as hex text
    return "hex"

def write_hex(words: List[int], out_path: str):
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        for w in words:
            f.write(f"{w:08X}\n")

def pad_words(words: List[int], depth: Optional[int], fill: int) -> List[int]:
    if depth is None or depth <= 0:
        return words
    if len(words) > depth:
        raise ValueError(f"Program too large ({len(words)} words) for depth={depth}.")
    return words + [fill & 0xFFFFFFFF] * (depth - len(words))

def main():
    p = argparse.ArgumentParser(description="Generate $readmemh-compatible .hex/.mem files.")
    p.add_argument("-i", "--input", required=True, help="Input file (.txt/.hex, .json, .s/.asm) unless --bin used")
    p.add_argument("-o", "--output", required=True, help="Output file (.hex or .mem)")
    p.add_argument("--depth", type=int, default=None, help="Total words in output (pads with fill to this length)")
    p.add_argument("--fill", type=lambda x: int(x, 0), default=DEFAULT_FILL, help="Fill word for padding (default 0x00000013)")
    p.add_argument("--bin", action="store_true", help="Treat input as raw binary of 32-bit words (little-endian)")
    p.add_argument("--big-endian", action="store_true", help="When --bin is used, interpret words as big-endian")
    args = p.parse_args()

    mode = detect_input_mode(args.input, args.bin)

    if mode == "bin":
        words = load_words_from_bin(args.input, little_endian=not args.big_endian)
    elif mode == "json":
        words = load_words_from_json(args.input)
    elif mode == "asm":
        words = load_words_from_assembly(args.input)
    else:
        words = load_words_from_hex_text(args.input)

    words = [w & 0xFFFFFFFF for w in words]
    words = pad_words(words, args.depth, args.fill)

    out_ext = os.path.splitext(args.output)[1].lower()
    if out_ext not in (".hex", ".mem"):
        print(f"Warning: output extension '{out_ext}' is unusual; using HEX format anyway.", file=sys.stderr)
    write_hex(words, args.output)

    print(f"Wrote {len(words)} words -> {args.output}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
