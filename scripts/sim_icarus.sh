#!/usr/bin/env bash
set -euo pipefail

# ---------- Config ----------
RTL_DIR="rtl"
TB_DIR="tb"
VCD_KEEP=${VCD_KEEP:-0}   # set to 1 to keep VCDs
IV_FLAGS="-g2012 -I ${RTL_DIR}"

# Core RTL list (adjust if you rename files)
RTL_LIB=(
  "${RTL_DIR}/defines.vh"
  "${RTL_DIR}/pc.v"
  "${RTL_DIR}/instr_mem.v"
  "${RTL_DIR}/data_mem.v"
  "${RTL_DIR}/reg_file.v"
  "${RTL_DIR}/imm_gen.v"
  "${RTL_DIR}/alu.v"
  "${RTL_DIR}/branch_unit.v"
  "${RTL_DIR}/control_unit.v"
  "${RTL_DIR}/if_id.v"
  "${RTL_DIR}/id_ex.v"
  "${RTL_DIR}/ex_mem.v"
  "${RTL_DIR}/mem_wb.v"
  "${RTL_DIR}/hazard_unit.v"
  "${RTL_DIR}/forward_unit.v"
  "${RTL_DIR}/fault_detector.v"
)

# Tests to run (order matters: unit → integration)
TESTS=(
  "tb_reg_file.v:${RTL_DIR}/reg_file.v"
  "tb_alu.v:${RTL_DIR}/alu.v ${RTL_DIR}/defines.vh"
  "tb_imm.v:${RTL_DIR}/imm_gen.v"
  "tb_control_unit.v:${RTL_DIR}/control_unit.v ${RTL_DIR}/defines.vh"
  "tb_branch.v:${RTL_DIR}/branch_unit.v ${RTL_DIR}/defines.vh"
  # bring-up (single-cycle)
  "tb_core_sc.v:${RTL_DIR}/core_sc.v ${RTL_LIB[*]}"
  # pipeline
  "tb_pipeline_smoke.v:${RTL_DIR}/core.v ${RTL_LIB[*]}"
  "tb_hazard_forward.v:${RTL_DIR}/core.v ${RTL_LIB[*]}"
  "tb_branch_flush.v:${RTL_DIR}/core.v ${RTL_LIB[*]}"
  # fault tests
  "tb_fault.v:${RTL_DIR}/fault_detector.v"
  "tb_fault_core.v:${RTL_DIR}/core.v ${RTL_LIB[*]}"
)

pass() { printf "\033[1;32mPASS\033[0m\n"; }
fail() { printf "\033[1;31mFAIL\033[0m\n"; }

echo "== Icarus Verilog test suite =="
for entry in "${TESTS[@]}"; do
  TB_FILE="${entry%%:*}"
  DEP_LIST="${entry#*:}"

  TB_PATH="${TB_DIR}/${TB_FILE}"

  echo ""
  echo "---- ${TB_FILE} ----"
  # Build command
  cmd=(iverilog ${IV_FLAGS} -o sim "${TB_PATH}")
  # Append dependencies (split words)
  for dep in ${DEP_LIST}; do
    cmd+=("${dep}")
  done

  # Compile
  "${cmd[@]}"

  # Run
  if vvp sim; then
    pass
  else
    fail
    exit 1
  fi

  # Clean up generated VCD unless asked to keep
  if [[ "${VCD_KEEP}" -eq 0 ]]; then
    rm -f ./*.vcd || true
  fi
done

echo ""
echo "== All tests completed =="
pass
