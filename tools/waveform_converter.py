#!/usr/bin/env python3
"""
waveform_converter.py — Convert simulator waveforms to FST (for GTKWave)

Features:
  • VCD -> FST using 'vcd2fst' (from GTKWave)
  • WLF -> VCD using 'wlf2vcd' (ModelSim/Questa), then VCD -> FST
  • Single file or entire directory (recursive optional)
  • Smart defaults for output paths; preserves filenames

Requirements:
  - 'vcd2fst' in PATH (installed with GTKWave)
  - Optional: 'wlf2vcd' in PATH to convert ModelSim/Questa .wlf

Examples:
  # Convert one VCD:
  python tools/waveform_converter.py -i build/sim/icarus/core_tb.vcd

  # Convert a ModelSim .wlf to .fst (via wlf2vcd):
  python tools/waveform_converter.py -i scripts/out/core_tb.wlf

  # Convert all waveforms in a directory (recursively):
  python tools/waveform_converter.py -i build/sim --recursive

  # Explicit output:
  python tools/waveform_converter.py -i tb/out.vcd -o tb/out.fst
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional, Tuple

def which_or_die(tool: str) -> str:
    path = shutil.which(tool)
    if not path:
        raise FileNotFoundError(f"Required tool '{tool}' not found in PATH.")
    return path

def convert_vcd_to_fst(vcd_path: Path, fst_path: Path) -> None:
    vcd2fst = which_or_die("vcd2fst")
    fst_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [vcd2fst, "-v", str(vcd_path), str(fst_path)]
    subprocess.run(cmd, check=True)

def convert_wlf_to_vcd(wlf_path: Path, vcd_path: Path) -> None:
    # 'wlf2vcd' is part of ModelSim/Questa installs
    wlf2vcd = which_or_die("wlf2vcd")
    vcd_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [wlf2vcd, str(wlf_path), str(vcd_path)]
    subprocess.run(cmd, check=True)

def default_out_path(in_path: Path, force_dir: Optional[Path]=None) -> Path:
    if force_dir:
        stem = in_path.stem
        if in_path.suffix.lower() == ".vcd":
            out = force_dir / f"{stem}.fst"
        elif in_path.suffix.lower() == ".wlf":
            out = force_dir / f"{stem}.fst"
        else:
            out = force_dir / f"{stem}.fst"
    else:
        if in_path.suffix.lower() == ".vcd":
            out = in_path.with_suffix(".fst")
        elif in_path.suffix.lower() == ".wlf":
            out = in_path.with_suffix(".fst")
        else:
            out = in_path.with_suffix(".fst")
    return out

def handle_one_file(in_file: Path, out_path: Optional[Path], keep_temp: bool=False, verbose: bool=True) -> Tuple[Path, Optional[Path]]:
    """
    Returns (fst_path, intermediate_vcd_if_any)
    """
    ext = in_file.suffix.lower()
    if out_path is None:
        fst_path = default_out_path(in_file)
    else:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        fst_path = out_path

    if ext == ".fst":
        if verbose:
            print(f"[skip] Already FST: {in_file}")
        return (in_file, None)

    if ext == ".vcd":
        if verbose:
            print(f"[vcd->fst] {in_file} -> {fst_path}")
        convert_vcd_to_fst(in_file, fst_path)
        return (fst_path, None)

    if ext == ".wlf":
        # Need to convert to VCD first
        with tempfile.TemporaryDirectory() as td:
            tmp_vcd = Path(td) / (in_file.stem + ".vcd")
            if verbose:
                print(f"[wlf->vcd] {in_file} -> {tmp_vcd}")
            convert_wlf_to_vcd(in_file, tmp_vcd)
            if verbose:
                print(f"[vcd->fst] {tmp_vcd} -> {fst_path}")
            convert_vcd_to_fst(tmp_vcd, fst_path)
            if keep_temp:
                keep_path = in_file.with_suffix(".vcd")
                shutil.copyfile(tmp_vcd, keep_path)
                if verbose:
                    print(f"[keep] wrote intermediate VCD: {keep_path}")
                return (fst_path, keep_path)
            return (fst_path, None)

    raise ValueError(f"Unsupported input extension: {ext} (expected .vcd, .wlf, or .fst)")

def main():
    ap = argparse.ArgumentParser(description="Convert waveforms to FST for GTKWave.")
    ap.add_argument("-i", "--input", required=True, help="Input file or directory (.vcd/.wlf/.fst)")
    ap.add_argument("-o", "--output", help="Output file or directory (for dir input, must be a directory)")
    ap.add_argument("--recursive", action="store_true", help="Recurse through subdirectories when input is a directory")
    ap.add_argument("--keep-intermediate", action="store_true", help="When converting .wlf, keep the intermediate .vcd next to the input file")
    ap.add_argument("--quiet", action="store_true", help="Less verbose output")
    args = ap.parse_args()

    in_path = Path(args.input)
    out = Path(args.output).resolve() if args.output else None
    verbose = not args.quiet

    if not in_path.exists():
        print(f"ERROR: Input not found: {in_path}", file=sys.stderr)
        sys.exit(2)

    try:
        # Probe for vcd2fst early to fail fast if missing
        which_or_die("vcd2fst")
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        print("Hint: Install GTKWave (vcd2fst is included).", file=sys.stderr)
        sys.exit(3)

    converted = 0

    if in_path.is_file():
        if out and out.is_dir():
            out_path = default_out_path(in_path, out)
        else:
            out_path = out
        fst_path, _ = handle_one_file(in_path, out_path, keep_temp=args.keep_intermediate, verbose=verbose)

