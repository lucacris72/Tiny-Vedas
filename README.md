# Tiny Vedas - RISC-V RV32IM Processor

A complete, open-source implementation of a RISC-V RV32IM processor written in SystemVerilog. Tiny Vedas is a 4-stage pipelined processor with full RV32IM instruction set support, hazard handling, and comprehensive verification.
This project includes extensions developed as part of the Advanced Computer Architecture course at Politecnico di Milano.

## Features

### Architecture
- **ISA**: RISC-V RV32IM (32-bit integer + multiply/divide)
- **Pipeline**: 4-stage pipeline (IFU → IDU0 → IDU1 → EXU)
- **Data Width**: 32-bit (XLEN = 32)
- **Memory**: Harvard architecture with separate instruction and data memories
- **Reset Vector**: Configurable (default: 0x80000000)

### Instruction Set Support
- **Arithmetic**: ADD, SUB, ADDI, LUI, AUIPC
- **Logical**: AND, OR, XOR, ANDI, ORI, XORI
- **Shifts**: SLL, SRL, SRA, SLLI, SRLI, SRAI
- **Comparison**: SLT, SLTU, SLTI, SLTIU
- **Branches**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jumps**: JAL, JALR
- **Memory**: LB, LH, LW, LBU, LHU, SB, SH, SW
- **Multiply/Divide**: MUL, MULH, MULHU, MULHSU, DIV, DIVU, REM, REMU
- **Multiply and Accumulate**: MAC, MACRST

### Advanced Features
- **Data Hazard Resolution**: Register forwarding from EXU to IDU1
- **Control Hazard Handling**: Pipeline flush on branches
- **Branch Prediction**: 2-bit saturating BHT
- **Multi-cycle Operations**: Pipelined multiplier, mac, and divider
- **Unaligned Memory Access**: Support for byte and half-word aligned loads/stores
- **Memory Forwarding**: Store-to-load forwarding for performance

## Project Structure

```
tiny-vedas/
├── rtl/                   # RTL design files
│   ├── core_top.sv        # Top-level processor module
│   ├── core_top.flist     # File list for synthesis
│   ├── ifu/               # Instruction fetch unit
│   │   ├── ifu.sv         # IFU implementation
│   │   ├── bht.sv         # BHT implementation
│   │   └── btb.sv         # BTB implementation
│   ├── idu/               # Instruction decode units
│   │   ├── idu0.sv        # Decode stage 0
│   │   ├── idu1.sv        # Decode stage 1
│   │   ├── reg_file.sv    # Register file
│   │   ├── decode.sv      # Auto-generated decode logic
│   │   └── decode         # Decode table specification
│   ├── exu/               # Execute unit
│   │   ├── exu.sv         # Execute unit top-level
│   │   ├── alu.sv         # Arithmetic logic unit
│   │   ├── mul.sv         # Multiplier unit
│   │   ├── div.sv         # Divider unit
│   │   ├── lsu.sv         # Load/store unit
│   │   └── mac.sv         # Mac unit
│   ├── custom/            # Custom implementation
│   │   └── perf_cntr.sv   # Just an helper
│   ├── include/           # Global definitions
│   │   ├── global.svh     # Global parameters
│   │   └── types.svh      # Type definitions
│   └── lib/               # Utility modules
│       ├── mem_lib.sv     # Memory modules
│       └── beh_lib.sv     # Behavioral models
├── tests/                 # Test programs
│   ├── asm/               # Assembly test programs
│   ├── c/                 # C program tests
│   └── raw/               # Raw binary tests
├── dv/                    # Design verification
│   ├── sv/                # SystemVerilog testbenches
│   │   ├── core_top_tb.sv # Main testbench
│   │   └── lsu_tb.sv      # LSU testbench
│   └── verilator/         # Verilator simulation files
├── tools/                 # Development utilities
│   ├── dec_table_gen.py   # Decode table generator
│   ├── sim_manager.py     # Simulation manager
│   └── riscv_sim          # RISC-V simulator improved with SPIKE
└── LICENSE                # MIT license
```

## Quick Start

### Prerequisites
- **SystemVerilog Simulator**: Verilator
- **RISC-V Toolchain**: GCC with RISC-V target
- **Python 3**: For build scripts
- **custom SPIKE**: For custom MAC instruction simulation
- **Ubuntu 20.04+**: Tested platform

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/siliscale/Tiny-Vedas.git
   cd Tiny-Vedas
   ```

2. **Install dependencies**
   ```bash
   # Install Verilator
   sudo apt-get install verilator
   
   # Install RISC-V toolchain
   sudo apt-get install gcc-riscv64-linux-gnu

   # Compile SPIKE
   refer to documentation in dependencies/riscv-isa-sim

   ```

3. **Build and run simulation**
   ```bash
   # Run core simulation and ISS verification
   python3 tools/sim_manager.py -s verilator [-n asm.<testname>] [-t tests/smoke.tlist] {-d}
   
   ```

## Verification

### Test Results
Simulation results are logged to:
- `rtl.log`: Instruction execution trace
- `iss.log`: ISS execution trace
- `console.log`: Program output
- Waveform files: For detailed timing analysis
