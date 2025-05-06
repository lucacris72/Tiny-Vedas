# Notes for Lecture 6

## Installing RISC-V GNU Toolchain

```bash
$ sudo apt install gcc-riscv64-unknown-elf
$ riscv64-unknown-elf-gcc --version
```

## Compiling a program

```bash
riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -o <path-to-output-file> -nostdlib -Ttext 0x100000 <path-to-assembly-or-C-file>
```

## Running the ISS

```bash
./tools/riscv_sim <path-to-elf-file> -o <path-to-output-log-file>
```

## Running the Simulation Manager

```bash
python3 tools/sim_manager.py -s verilator -n <test-name>
```

NB <test-name> in the format asm.nameofthetest
NB To disassemble elf executable (in order to know how the assembly as been translated): riscv64-unknown-elf-objdump -D <elf file>