# 🚀 RISC-V Core Optimization with Embedded Fault Detection Module

## Overview

This project implements a simplified **5-stage pipelined RISC-V RV32I processor core**, optimized for improved performance and integrated with a custom **embedded fault detection module**. The design is targeted for FPGA deployment (e.g., Digilent Nexys A7) and demonstrates robust operation under voltage anomaly scenarios — a critical feature for reliable embedded and power systems.

---

## ⚡ Features

✅ 5-stage pipelined RISC-V RV32I core: IF, ID, EX, MEM, WB stages  
✅ Basic data hazard detection with stall logic (`hazard_unit.v`)  
✅ Forwarding support (`forward_unit.v`)  
✅ Embedded fault detection module (`fault_detector.v`) for voltage anomalies  
✅ Integrated stall, flush, and halt control on fault detection (`core.v`)  
✅ FPGA wrapper (`top_fpga.v`) exposing voltage monitor and halt outputs  
✅ Written in Verilog, synthesized with Vivado, and verified via simulation (ModelSim or Icarus Verilog)

---

## 🧩 Module Breakdown

### `core.v`

- Implements the 5-stage pipeline
- Ports: `clk`, `rst`, `voltage_mv[11:0]`, `fault_detected`, `core_halt`
- Parameters: `FAULT_MIN_MV`, `FAULT_MAX_MV`, `IMEM_HEX` (instruction image)
- Flushes/stalls on hazards and halts on detected faults

### `fault_detector.v`

- Monitors `voltage_mv` (mV)
- Asserts `fault_detected` when outside `[MIN_MV, MAX_MV]`

### `hazard_unit.v`

- Detects load-use hazards; issues stalls/flushes for control flow changes

### `forward_unit.v`

- Forwards EX/MEM or MEM/WB results to EX inputs to reduce stalls

### `top_fpga.v`

- FPGA wrapper that instantiates `core`, wires voltage monitor, and exposes `fault_detected`/`core_halt`

### Testbenches (`tb/`)

- `tb_pipeline_smoke.v`, `tb_branch_flush.v`, `tb_hazard_forward.v`, `tb_fault.v`, etc.
- Simulate normal, hazard, branch, and fault scenarios

---

## 💡 Future Improvements

- Add **full instruction decode logic** to support a complete RV32I subset
- Implement **forwarding unit** to minimize stalls and improve throughput
- Extend fault detection to monitor additional parameters (e.g., current, temperature)
- Integrate watchdog timer and more advanced self-recovery logic
- Create UART-based debug output or on-board LED status indicators

---

## 💻 Tools & Technologies

- Verilog (RTL design)
- Vivado (synthesis & FPGA implementation)
- ModelSim / QuestaSim / Icarus Verilog (simulation)
- Digilent Nexys A7 FPGA board (target hardware)

---

## 📄 How to Run (Icarus Verilog)

1️⃣ Clone  
```bash
git clone https://github.com/Real-Chuck-Keith-Chow/RISC-V-Core-Optimization-with-Embedded-Fault-Detection-Module.git
cd RISC-V-Core-Optimization-with-Embedded-Fault-Detection-Module
```

2️⃣ Build + run a smoke test  
```bash
iverilog -g2012 -I rtl -s tb_pipeline_smoke -o build/tb_pipeline_smoke.sim rtl/*.v tb/tb_pipeline_smoke.v
vvp build/tb_pipeline_smoke.sim
```

3️⃣ Other testbenches (swap top and tb file)  
- Branch flush: `-s tb_branch_flush tb/tb_branch_flush.v`  
- Hazard/forwarding: `-s tb_hazard_forward tb/tb_hazard_forward.v`  
- Fault detector only: `-s tb_fault tb/tb_fault.v`

4️⃣ Select program image  
Pass a parameter override for instruction memory image:  
```bash
iverilog ... -P core.IMEM_HEX="tb/prog_fault.hex" ...
```

5️⃣ View waveforms (optional)  
```bash
gtkwave tb_pipeline_smoke.vcd
```

## Notes
- `voltage_mv` drives the fault detector inside `core`. On a detected fault, the core flushes IF/ID and ID/EX once, then stalls/halts and gates off writes.
- `core_halt` stays high after a fault until reset. Use it to drive board LEDs or system reset logic in `top_fpga.v`.
'@
