#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# compile_core.sh — Batch compile RTL + TBs (Icarus or ModelSim)
#
# Usage:
#   ./scripts/compile_core.sh                     # defaults to TOOL=icarus, TB=core_tb
#   TOOL=modelsim ./scripts/compile_core.sh
#   TB=forward_tb TOOL=icarus ./scripts/compile_core.sh
#
# Env overrides (all optional):
#   TOOL : icarus | modelsim            (default: icarus)
#   TB   : testbench top module name    (default: core_tb)
#   RTL  : RTL directory                (default: rtl)
#   TB_DIR: testbench directory         (default: tb)
#   OUT  : output/build directory       (default: build/sim)
#   EXTRA: extra compiler flags         (default: empty)
#
# Artifacts:
#   - Icarus:  $OUT/icarus/<TB>.vvp, compile log
#   - ModelSim:$OUT/modelsim/work/ (compiled library), transcript
# ------------------------------------------------------------------------------

set -euo pipefail

TOOL="${TOOL:-icarus}"
TB="${TB:-core_tb}"
RTL="${RTL:-rtl}"
TB_DIR="${TB_DIR:-tb}"
OUT="${OUT:-build/sim}"
EXTRA="${EXTRA:-}"

mkdir -p "$OUT"

# Collect sources
mapfile -t RTL_SRCS < <(find "$RTL"   -maxdepth 1 -type f \( -name "*.v" -o -name "*.sv" \) | sort)
mapfile -t TB_SRCS  < <(find "$TB_DIR" -maxdepth 1 -type f \( -name "*.v" -o -name "*.sv" \) | sort)

if [[ ${#RTL_SRCS[@]} -eq 0 ]]; then
  echo "ERROR: No RTL sources found in $RTL"; exit 2
fi
if [[ ${#TB_SRCS[@]} -eq 0 ]]; then
  echo "ERROR: No testbench sources found in $TB_DIR"; exit 2
fi

echo "==> TOOL=$TOOL  TB=$TB"
echo "==> RTL files: ${#RTL_SRCS[@]}  TB files: ${#TB_SRCS[@]}"

case "$TOOL" in
  icarus)
    OUT_DIR="$OUT/icarus"
    mkdir -p "$OUT_DIR"
    VVP="$OUT_DIR/${TB}.vvp"
    LOG="$OUT_DIR/compile.log"

    echo "==> Compiling with Icarus Verilog -> $VVP"
    {
      echo "# Icarus compile log"
      echo "TOP TB = $TB"
      echo "Command:"
      echo "iverilog -g2012 -DSIM -o $VVP -s $TB -I $RTL -I $TB_DIR ${RTL_SRCS[*]} ${TB_SRCS[*]} $EXTRA"
    } > "$LOG"

    # -g2012 for SystemVerilog-2012 support where available
    iverilog -g2012 -DSIM -o "$VVP" -s "$TB" -I "$RTL" -I "$TB_DIR" "${RTL_SRCS[@]}" "${TB_SRCS[@]}" $EXTRA >>"$LOG" 2>&1

    echo "==> Done. Output: $VVP"
    ;;

  modelsim|questa)
    OUT_DIR="$OUT/modelsim"
    mkdir -p "$OUT_DIR"
    pushd "$OUT_DIR" >/dev/null

    # Fresh work library
    if [[ -d work ]]; then vdel -lib work -all || true; fi
    vlib work
    vmap work work

    LOG="$OUT_DIR/transcript"

    echo "==> Compiling with ModelSim/Questa -> work/ (TB=$TB)"
    # Compile RTL
    vlog +define+SIM +acc +incdir+../..+"$RTL" +incdir+../..+"$TB_DIR" "${RTL_SRCS[@]/#/"../../"}" $EXTRA | tee "$LOG"
    # Compile TBs
    vlog +define+SIM +acc +incdir+../..+"$RTL" +incdir+../..+"$TB_DIR" "${TB_SRCS[@]/#/"../../"}" $EXTRA | tee -a "$LOG"

    echo "==> Done. Library at: $OUT_DIR/work"
    popd >/dev/null
    ;;

  *)
    echo "ERROR: Unknown TOOL='$TOOL' (use icarus or modelsim)"; exit 3
    ;;
esac
