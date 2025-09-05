#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# clean.sh — Remove all build artifacts, logs, caches, and generated outputs.
#
# Usage:
#   ./scripts/clean.sh              # Clean everything (safe default)
#   ./scripts/clean.sh vivado       # Only clean Vivado artifacts
#   ./scripts/clean.sh modelsim     # Only clean ModelSim artifacts
#   ./scripts/clean.sh icarus       # Only clean Icarus artifacts
#
# Notes:
#   - Does NOT delete your source RTL, TB, docs, or scripts.
#   - Safe for repeated use.
# ------------------------------------------------------------------------------

set -euo pipefail

# Defaults
OUT_DIR="build"
VIVADO_DIRS=("vivado*" "*.runs" "*.sim" "*.cache" "*.hw" "*.ip_user_files" "*.srcs" "*.log" "*.jou" "*.xpr")
MODELSIM_DIRS=("work" "transcript" "*.wlf" "*.vcd" "modelsim.ini" "*.mpf")
ICARUS_DIRS=("*.vvp" "*.vcd" "a.out")
LOGS_DIRS=("*.log" "*.pb" "*.rpt" "*.jou" "*.dcp" "*.edf")

clean_vivado() {
    echo "==> Cleaning Vivado artifacts..."
    for p in "${VIVADO_DIRS[@]}"; do
        find . -type d -name "$p" -exec rm -rf {} + 2>/dev/null || true
        find . -type f -name "$p" -exec rm -f {} + 2>/dev/null || true
    done
    echo "✓ Vivado cleanup complete."
}

clean_modelsim() {
    echo "==> Cleaning ModelSim artifacts..."
    for p in "${MODELSIM_DIRS[@]}"; do
        find . -type d -name "$p" -exec rm -rf {} + 2>/dev/null || true
        find . -type f -name "$p" -exec rm -f {} + 2>/dev/null || true
    done
    echo "✓ ModelSim cleanup complete."
}

clean_icarus() {
    echo "==> Cleaning Icarus artifacts..."
    for p in "${ICARUS_DIRS[@]}"; do
        find . -type f -name "$p" -exec rm -f {} + 2>/dev/null || true
    done
    echo "✓ Icarus cleanup complete."
}

clean_logs() {
    echo "==> Cleaning reports & logs..."
    for p in "${LOGS_DIRS[@]}"; do
        find . -type f -name "$p" -exec rm -f {} + 2>/dev/null || true
    done
    echo "✓ Log cleanup complete."
}

clean_build_dir() {
    if [[ -d "$OUT_DIR" ]]; then
        echo "==> Removing build directory: $OUT_DIR"
        rm -rf "$OUT_DIR"
        echo "✓ Removed $OUT_DIR"
    fi
}

echo "==> Starting cleanup..."

# Mode-based cleaning
if [[ $# -eq 0 ]]; then
    clean_build_dir
    clean_vivado
    clean_modelsim
    clean_icarus
    clean_logs
    echo "==> Full cleanup complete."
else
    case "$1" in
        vivado)    clean_vivado ;;
        modelsim)  clean_modelsim ;;
        icarus)    clean_icarus ;;
        logs)      clean_logs ;;
        *)
            echo "ERROR: Unknown option '$1'. Use: vivado | modelsim | icarus | logs"
            exit 1
            ;;
    esac
fi
