# -------------------------------------------------------------------
# sim_modelsim_cli.do  —  Headless (CLI) simulation for ModelSim/Questa
# Usage examples:
#   vsim -c -do "do scripts/sim_modelsim_cli.do"
#   vsim -c -do "do scripts/sim_modelsim_cli.do core_tb prog_hazard.hex"
#   vsim -c -do "do scripts/sim_modelsim_cli.do forward_tb prog_branch_flush.hex"
#
# Args (optional):
#   1) TESTBENCH module name   [default: core_tb]
#   2) Program hex file (in tb)[default: prog_basic.hex]
# -------------------------------------------------------------------

# ====== Config ======
if {$argc >= 1} { set TB_NAME [lindex $argv 0] } else { set TB_NAME core_tb }
if {$argc >= 2} { set PROG_HEX [lindex $argv 1] } else { set PROG_HEX prog_basic.hex }

set RTL_DIR ../rtl
set TB_DIR  ../tb
set OUT_DIR ./out
file mkdir $OUT_DIR

# Output artifacts
set WLF_FILE $OUT_DIR/$TB_NAME.wlf
set VCD_FILE $OUT_DIR/$TB_NAME.vcd
set LOG_FILE $OUT_DIR/$TB_NAME.transcript

# ====== Clean & prepare work lib ======
transcript file $LOG_FILE
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

# ====== Compile RTL & TB ======
# Add include path for headers (e.g., defines.vh) if present.
vlog +define+SIM +acc +incdir+$RTL_DIR \
    $RTL_DIR/*.v

# Compile all testbenches and memory/program files readers
vlog +define+SIM +acc +incdir+$TB_DIR \
    $TB_DIR/*.v

# ====== Launch simulation (CLI) ======
# -voptargs="+acc" keeps full hierarchy visibility for logging/coverage
# Pass the selected program to the TB via plusarg: +PROG=<path/to/hex>
# (Your TB should $value$plusargs("PROG=%s", prog_path) or default internally.)
set PROG_PATH "$TB_DIR/$PROG_HEX"

vsim -c -voptargs="+acc" work.$TB_NAME +PROG=$PROG_PATH -wlf $WLF_FILE -coverage -do {
    # Log everything recursively
    log -r /*
    # Optional VCD for GTKWave
    vcd file ../scripts/out_tmp.vcd
    vcd add -r /*
    # Run until $finish
    run -all
    # Move VCD to desired location (ModelSim writes relative to sim dir)
    if {[file exists ../scripts/out_tmp.vcd]} {
        file rename -force ../scripts/out_tmp.vcd [pwd]/$VCD_FILE
    }
    # Coverage reports (optional)
    coverage report -details -cvg -codeAll
    # Exit cleanly
    quit -f
}

# ====== End ======
