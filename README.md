# 🚀 RISC-V Core Optimization with Embedded Fault Detection Module

## Overview

This project implements a simplified **5-stage pipelined RISC-V RV32I processor core**, optimized for improved performance and integrated with a custom **embedded fault detection module**. The design is targeted for FPGA deployment (e.g., Digilent Nexys A7) and demonstrates robust operation under voltage anomaly scenarios — a critical feature for reliable embedded and power systems.

---

## ⚡ Features

✅ 5-stage pipelined RISC-V RV32I core: IF, ID, EX, MEM, WB stages  
✅ Basic data hazard detection with stall logic (`hazard_unit.v`)  
✅ Ready-to-extend forwarding support (future improvement)  
✅ Embedded fault detection module (`fault_detector.v`) for voltage anomalies  
✅ Integrated stall and halt control on fault detection  
✅ Written in Verilog, synthesized with Vivado, and verified via simulation (ModelSim or Icarus Verilog)

---

## 🧩 Module Breakdown

### `core.v`

- Implements a simplified RISC-V core pipeline
- Supports hook for external `fault_detected` signal
- Halts execution when a fault is detected

### `fault_detector.v`

- Monitors simulated voltage input (`voltage_in`)
- Asserts `fault_detected` signal when voltage goes outside safe thresholds

### `hazard_unit.v`

- Detects basic **load-use data hazards**
- Generates stall signal to prevent incorrect data usage

### `tb.v`

- Testbench for full system
- Simulates normal and faulty voltage scenarios
- Observes pipeline behavior and halt response

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

## 📄 How to Run

1️⃣ Clone this repository  
```bash
git clone https://github.com/your_username/riscv-fault-detect-core.git
cd riscv-fault-detect-core


# Example using Icarus Verilog
iverilog -g2012 core.v fault_detector.v hazard_unit.v tb.v -o sim
vvp sim


# If using GTKWave
gtkwave dump.vcd
