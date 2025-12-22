# Logic Networks Final Project - Differential Filter Hardware - 2024/25

![Language](https://img.shields.io/badge/Language-VHDL-blue)
![Platform](https://img.shields.io/badge/Platform-Xilinx_Artix--7-red)
![Grade](https://img.shields.io/badge/Grade-26%2F30-brightgreen)

## 📌 Project Overview
This repository contains the VHDL implementation of a hardware module designed for the **Final Project of the Logic Networks Course** (Progetto di Reti Logiche) at **Politecnico di Milano** (Academic Year 2024-2025).

The goal of the project was to design a hardware component capable of interfacing with a memory, reading a sequence of bytes, applying a **differential filter** (convolution), and writing the normalized results back to memory.

**Author:** Matteo Vignocchi  
**Professor:** Prof. Gianluca Palermo  
**Final Evaluation:** 26/30

---

## ⚙️ Specifications
The system processes a sequence of $K$ words ($W$), represented as 8-bit integers in 2's complement (-128 to +127). The module performs the following operations:

1.  **Memory Read:** Reads a 17-byte header starting at a specific address (`ADD`). This header contains:
    * Sequence length ($K$).
    * Filter selector ($S$): Determines if the filter is Order 3 or Order 5.
    * Filter Coefficients ($C_1$ to $C_{14}$).
2.  **Filtering:** Applies the convolution formula:
    $$f'(i) = \frac{1}{n} \sum C_j \cdot f[j+i]$$
3.  **Normalization:** The division by $n$ ($1/12$ for Order 3, $1/60$ for Order 5) is approximated using a series of **right shifts** to optimize hardware resources, including a correction factor for negative numbers to minimize truncation error.
4.  **Saturation:** Results outside the -128 to +127 range are saturated to the nearest limit.
5.  **Write Back:** The result sequence $R$ is written back to memory immediately following the input sequence.

---

## 🏗️ Architecture
The design is based on a **Finite State Machine (FSM)** consisting of **14 states**, ensuring a fully synchronous behavior without latches.

### FSM Structure
The architecture evolved from a simple 7-state model to a robust 14-state model to handle memory latency and edge cases correctly.

* **IDLE:** Waiting for the `i_start` signal.
* **COLLECTING_DATA (1-2):** Reads the header (Length, Selector, Coefficients).
* **READ (1-3):** Manages the reading pipeline and fills the sliding window buffer.
* **FLTR (3/5):** Performs the convolution based on the selected order (Order 3 or Order 5).
* **NORM (3/5):** Applies shift-based normalization and saturation.
* **OUTPUT (0-2):** Handles the `write_enable` signals and writes the result to RAM.
* **DONE:** Asserts the `o_done` signal upon completion.

### Interface
The component entity `project_reti_logiche` exposes the following ports:

| Port Name | Direction | Width | Description |
| :--- | :--- | :--- | :--- |
| `i_clk` | IN | 1-bit | System Clock |
| `i_rst` | IN | 1-bit | Asynchronous Reset |
| `i_start` | IN | 1-bit | Start signal |
| `i_add` | IN | 16-bit | Start Address for the data sequence |
| `o_done` | OUT | 1-bit | Computation finished flag |
| `o_mem_addr`| OUT | 16-bit | RAM Address pointer |
| `i_mem_data`| IN | 8-bit | Data read from RAM |
| `o_mem_data`| OUT | 8-bit | Data to write to RAM |
| `o_mem_we` | OUT | 1-bit | Write Enable |
| `o_mem_en` | OUT | 1-bit | RAM Enable |

---

## 📊 Synthesis Results
The design was synthesized for the **Xilinx XC7A200T-FBG484-1** (Artix-7) FPGA.

* **Errors:** 0
* **Latches:** 0 (Fully synchronous)
* **Timing:** Passed constraints (20ns clock period).

| Resource | Used | Utilization |
| :--- | :--- | :--- |
| **Slice LUTs** | 904 | 0.67% |
| **Slice Registers** | 326 | 0.12% |
| **F7 Muxes** | 1 | <0.01% |

---

## 🧪 Simulation & Testing
The module was extensively verified using a comprehensive Testbench suite covering nominal and corner cases.

**Key Test Scenarios:**
* **Basic Functionality:** Correct filtering for both Order 3 and Order 5.
* **Saturation Extremes:** Verifying output clamps at -128/+127.
* **Boundary Conditions:** Minimal length ($K=7$), Maximum length ($K=249$), and Zero length ($K=0$).
* **Reset Logic:** Asynchronous reset injection during Setup and Run phases.
* **Output Isolation:** Ensuring no memory corruption outside the designated output area.
* **Multi-Run:** Executing consecutive processings without system reset.

---

## 📂 Repository Structure
* `/hdl`: Contains the VHDL source code (`project_reti_logiche.vhd`).
* `/testbench`: Contains the testbench files used for simulation.
* `/doc`: Project documentation and specifications.

## 📜 Copyright
This project was developed for the *Reti Logiche* course at *Politecnico di Milano*.
