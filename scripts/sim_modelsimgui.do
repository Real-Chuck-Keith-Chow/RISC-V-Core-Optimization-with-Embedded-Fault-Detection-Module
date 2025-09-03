# ------------------------------------------------------------
# sim_modelsimgui.do
# Usage (inside Questa/ModelSim GUI console):
#   do scripts/sim_modelsimgui.do tb/tb_pipeline_smoke.v
# If no arg is provided, defaults to tb/tb_pipeline_smoke.v
# ------------------------------------------------------------

# ----- Select testbench -----
if {$argc >= 1} {
    set TB [lindex $argv 0]
} else {
    set TB tb/tb_pipeline_smoke.v
}
set TOP [file rootname [file tail $TB]]  ;# e.g., tb/tb_foo.v -> tb_foo

# ----- Clean & setup work lib -----
if {[file exists work]} { vdel -lib work -all }
vlib work

# ----- Compile RTL -----
set RTL_DIR rtl
set INC_OPTS "+incdir+$RTL_DIR"
set RTL_LIST {
    pc.v
    instr_mem.v
    data_mem.v
    reg_file.v
    imm_gen.v
    alu.v
    branch_unit.v
    control_unit.v
    if_id.v
    id_ex.v
    ex_mem.v
    mem_wb.v
    hazard_unit.v
    forward_unit.v
    fault_detector.v
    core_sc.v
    core.v
}

foreach f $RTL_LIST {
    vlog -sv -work work $INC_OPTS $RTL_DIR/$f
}

# ----- Compile the selected testbench -----
vlog -sv -work work $INC_OPTS $TB

# ----- Launch simulation -----
vsim -voptargs=+acc work.$TOP

# ----- Viewer defaults -----
radix -hex
quietly set NumericStdNoWarnings 1
quietly set StdArithNoWarnings 1

# ----- Waves -----
# Add all by default; you can prune in GUI.
add wave -r /*

# Helpful groups (ignore errors if signals absent)
onerror {resume}
add wave -group CLK_RST  sim:/$TOP/clk
add wave -group CLK_RST  sim:/$TOP/rst

add wave -group IF       sim:/$TOP/dut/u_pc/pc_q
add wave -group IF       sim:/$TOP/dut/instr_if

add wave -group ID       sim:/$TOP/dut/instr_id
add wave -group ID       sim:/$TOP/dut/rs1_rdata
add wave -group ID       sim:/$TOP/dut/rs2_rdata

add wave -group EX       sim:/$TOP/dut/u_alu/y
add wave -group HAZARD   sim:/$TOP/dut/stall_if
add wave -group HAZARD   sim:/$TOP/dut/stall_id
add wave -group HAZARD   sim:/$TOP/dut/flush_if_id
add wave -group HAZARD   sim:/$TOP/dut/flush_id_ex

add wave -group FWD      sim:/$TOP/dut/fwd_a_sel
add wave -group FWD      sim:/$TOP/dut/fwd_b_sel

add wave -group MEM      sim:/$TOP/dut/u_dmem/addr
add wave -group MEM      sim:/$TOP/dut/u_dmem/wdata
add wave -group MEM      sim:/$TOP/dut/u_dmem/rdata

add wave -group WB       sim:/$TOP/dut/rd_wdata

# ----- Run -----
run -all
echo "Simulation of $TOP finished."
