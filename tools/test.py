#!/usr/bin/env python3

import argparse
import sys
import os
from typing import List, Optional
from elftools.elf.elffile import ELFFile
import subprocess
import shutil
import concurrent.futures
import multiprocessing
import traceback
import re

# --- IMPOSTAZIONI GLOBALI ---
DRAM_BASE = 0x80000000
LEGACY_BASE = 0x100000
IMEM_DEPTH = 1024
DMEM_DEPTH = 1024
VERBOSE = False # Variabile globale per la modalità debug

# --- FUNZIONE DI STAMPA VERBOSA ---
def vprint(*args, **kwargs):
    """Stampa solo se la modalità VERBOSE è attiva."""
    if VERBOSE:
        print(*args, **kwargs)

def run_gen(test: str) -> None:
    work_dir = os.path.join("work", test)
    os.makedirs(work_dir, exist_ok=True)
    test_path = test.split(".")
    extension = ".s" if test_path[0] == "asm" else ".c"
    elf_output_path = os.path.join(work_dir, "test.elf")
    compile_log_path = os.path.join(work_dir, 'compile.log')
    is_mac_test = len(test_path) > 1 and test_path[1].startswith("mac_")
    try:
        if is_mac_test:
            vprint(f"Compiling '{test}' for Spike (address 0x{DRAM_BASE:x})")
            link_script_path = os.path.join(work_dir, "linker.ld")
            link_script_content = f"ENTRY(_start)\nSECTIONS {{\n  . = 0x{DRAM_BASE:x};\n  .text : {{ *(.text) }}\n  .rodata : {{ *(.rodata) }}\n  .data : {{ *(.data) }}\n  .bss : {{ *(.bss COMMON) }}\n}}"
            with open(link_script_path, 'w') as f:
                f.write(link_script_content)
            base_cmd = f"riscv64-unknown-elf-gcc -I{os.path.join('tests', test_path[0])} -march=rv32im -mabi=ilp32 -o {elf_output_path} -nostdlib -T {link_script_path}"
            if extension == ".s":
                full_cmd = f"{base_cmd} {os.path.join('tests', test_path[0], test_path[1] + extension)}"
            else:
                full_cmd = f"{base_cmd} -fno-builtin-printf -fno-common -falign-functions=4 {os.path.join('tests', test_path[0], test_path[1] + extension)} {os.path.join('tests', test_path[0], 'asm_functions', 'printf.s')} {os.path.join('tests', test_path[0], 'asm_functions', 'eot_sequence.s')}"
        else:
            vprint(f"Compiling '{test}' for standard ISS (address 0x{LEGACY_BASE:x})")
            base_cmd = f"riscv64-unknown-elf-gcc -I{os.path.join('tests', test_path[0])} -march=rv32im -mabi=ilp32 -o {elf_output_path} -nostdlib"
            linker_flag = f"-Wl,-Ttext=0x{LEGACY_BASE:x}"
            if extension == ".s":
                full_cmd = f"{base_cmd} {os.path.join('tests', test_path[0], test_path[1] + extension)} {linker_flag}"
            else:
                full_cmd = f"{base_cmd} -fno-builtin-printf -fno-common -falign-functions=4 {os.path.join('tests', test_path[0], test_path[1] + extension)} {os.path.join('tests', test_path[0], 'asm_functions', 'printf.s')} {os.path.join('tests', test_path[0], 'asm_functions', 'eot_sequence.s')} {linker_flag}"
        os.system(f"{full_cmd} > {compile_log_path} 2>&1")
    except Exception as e:
        print(f"Error compiling test {test}: {e}")
        sys.exit(1)

def count_static_instructions(elf_path: str, objdump_cmd: str) -> int:
    try:
        proc = subprocess.run([objdump_cmd, '-d', elf_path], stdout=subprocess.PIPE, text=True, check=True)
        instr_count = 0
        in_text_section = False
        for line in proc.stdout.splitlines():
            if 'Disassembly of section .text:' in line:
                in_text_section = True
                continue
            if not in_text_section: continue
            if 'Disassembly of section' in line and '.text' not in line: break
            if re.match(r"^\s*[0-9a-fA-F]+:\s+[0-9a-fA-F]{2}", line):
                instr_count += 1
        return instr_count if instr_count > 0 else 500
    except Exception as e:
        vprint(f"ATTENZIONE: Impossibile contare le istruzioni con objdump: {e}")
        return 500

def run_spike_iss(test: str, objdump_cmd: str) -> None:
    vprint(f"Running Spike ISS for MAC test: {test}")
    elf_path = os.path.join("work", test, "test.elf")
    log_path = os.path.join("work", test, "iss.log")
    if not os.path.exists(elf_path):
        print(f"ERRORE FATALE: Il file ELF '{elf_path}' non è stato trovato.")
        sys.exit(1)
    instruction_count = count_static_instructions(elf_path, objdump_cmd)
    simulation_cycles = instruction_count + 50
    vprint(f"Istruzioni statiche contate: {instruction_count}. Avvio Spike per {simulation_cycles} cicli.")
    cmd = ['spike', '--log-commits', f'--instructions={simulation_cycles}', f'--isa=rv32im', elf_path]
    vprint(f"Esecuzione comando: {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', check=False)
    except FileNotFoundError:
        print("ERRORE FATALE: Il comando 'spike' non è stato trovato.")
        sys.exit(1)
    spike_log_output = result.stderr
    log_re = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-fA-F]+)\s+\((0x[0-9a-fA-F]+)\)(.*)")
    reg_write_re = re.compile(r"(x\d+)\s+0x([0-9a-fA-F]+)")
    lines_written = 0
    with open(log_path, 'w') as out_f:
        for line in spike_log_output.splitlines():
            clean_line = line.strip()
            log_match = log_re.match(clean_line)
            if not log_match: continue
            pc_str, instr_hex, rest_of_line = log_match.groups()
            pc_val = int(pc_str, 16)
            if pc_val < DRAM_BASE:
                continue
            rest_of_line = rest_of_line.strip()
            touches, mnemonic = [], rest_of_line
            reg_match = reg_write_re.search(rest_of_line)
            if reg_match:
                reg_name, reg_val_hex = reg_match.groups()
                touches.append(f"{reg_name}=0x{int(reg_val_hex, 16):08x}")
                mnemonic = rest_of_line[:reg_match.start()].strip()
            touch_str = ";".join(touches)
            log_line = f"0x{pc_str};0x{instr_hex};{mnemonic};{touch_str}"
            out_f.write(log_line + "\n")
            lines_written += 1
    vprint(f"Spike ISS log generato. Righe scritte: {lines_written}.")
    if lines_written == 0 and "core" in spike_log_output:
        print("\n--- ATTENZIONE: il file iss.log è vuoto! ---")
        raise Exception("Generazione di iss.log fallita, il log è vuoto.")

def run_iss(test: str, objdump_cmd: str) -> None:
    test_parts = test.split('.')
    if len(test_parts) > 1 and test_parts[1].startswith("mac_"):
        run_spike_iss(test, objdump_cmd)
        return
    vprint(f"Running standard ISS for test: {test}")
    elf_path = os.path.join("work", test, "test.elf")
    dmem_path = os.path.join("tests", test_parts[0], test_parts[1] + ".mem")
    has_dmem = os.path.exists(dmem_path)
    if has_dmem:
        shutil.copy(dmem_path, os.path.join("work", test, "dmem.hex"))
    try:
        cmd = f"./tools/riscv_sim {elf_path} -o {os.path.join('work', test, 'iss.log')}"
        if has_dmem:
            cmd += f" -m {os.path.join('work', test, 'dmem.hex')}"
        os.system(cmd)
    except Exception as e:
        print(f"Error running ISS for test {test}: {e}")
        sys.exit(1)

def prepare_imem(test: str) -> None:
    imem_path = os.path.join("work", test, "imem.hex")
    dmem_path = os.path.join("work", test, "dmem.hex")
    elf_path = os.path.join("work", test, "test.elf")
    test_path = test.split('.')
    is_mac_test = len(test_path) > 1 and test_path[1].startswith("mac_")
    base_addr = DRAM_BASE if is_mac_test else LEGACY_BASE
    with open(elf_path, 'rb') as f:
        elf = ELFFile(f)
        text_section = elf.get_section_by_name('.text')
        if not text_section:
            print("Error: No .text section found in ELF file")
            sys.exit(1)
        imem_data = text_section.data()
        if len(imem_data) > IMEM_DEPTH:
            imem_data = imem_data[:IMEM_DEPTH]
        if len(imem_data) < IMEM_DEPTH:
            imem_data = imem_data + b'\x00' * (IMEM_DEPTH - len(imem_data))
        rodata_section = elf.get_section_by_name('.rodata')
        if rodata_section:
            rodata_new = []
            rodata_address = rodata_section.header['sh_addr']
            rodata_base_address = rodata_address - base_addr
            rodata_data = rodata_section.data()
            if len(rodata_data) > DMEM_DEPTH:
                rodata_data = rodata_data[:DMEM_DEPTH]
            if rodata_base_address > 0:
                rodata_new.extend([0] * rodata_base_address)
            rodata_new.extend(rodata_data)
            if len(rodata_new) < DMEM_DEPTH:
                rodata_new.extend([0] * (DMEM_DEPTH - len(rodata_new)))
            with open(dmem_path, "w") as f_dmem:
                for i in range(0, DMEM_DEPTH, 4):
                    word_bytes = bytes(rodata_new[i:i+4]) if i+4 <= len(rodata_new) else bytes(rodata_new[i:])
                    if len(word_bytes) < 4: word_bytes += b'\x00' * (4 - len(word_bytes))
                    hex_str = '{:08x}'.format(int.from_bytes(word_bytes, byteorder='little'))
                    f_dmem.write(f"{hex_str}\n")
    with open(imem_path, "w") as f_imem:
        for i in range(0, IMEM_DEPTH, 4):
            word = imem_data[i:i+4]
            hex_str = '{:08x}'.format(int.from_bytes(word, byteorder='little'))
            f_imem.write(f"{hex_str}\n")

def read_task_list(filename: str) -> List[str]:
    try:
        with open(filename, 'r') as f:
            return [line.strip() for line in f if line.strip()]
    except Exception as e:
        print(f"Error reading task list file: {e}")
        return []

def run_verilator(test: str) -> None:
    work_dir = os.path.join("work", test)
    test_path = test.split('.')
    is_mac_test = len(test_path) > 1 and test_path[1].startswith("mac_")
    reset_vector = DRAM_BASE if is_mac_test else LEGACY_BASE
    imem_path = os.path.join(work_dir, "imem.hex")
    imem_abs_path = os.path.abspath(imem_path)
    verilator_cmd = (
        f"export PROJ=$(pwd) && "
        f"cd {work_dir} && "
        f"verilator --cc --trace --trace-structs --build --timing "
        f"--top-module core_top_tb --exe $PROJ/dv/verilator/core_top_tb.cpp "
        f"-f $PROJ/rtl/core_top.flist "
        f"-DICCM_INIT_FILE='\"{imem_abs_path}\"' "
        f"-DRESET_VECTOR=32\\'h{reset_vector:x} -DSTACK_POINTER_INIT_VALUE=32\\'h80000000"
    )
    dmem_path = os.path.join(work_dir, "dmem.hex")
    if os.path.exists(dmem_path):
        dmem_abs_path = os.path.abspath(dmem_path)
        verilator_cmd += f" -DDCCM_INIT_FILE='\"{dmem_abs_path}\"'"
    else:
        verilator_cmd += f" -DDCCM_INIT_FILE='\"\"'"
    verilator_cmd += f" && make -j -C obj_dir -f Vcore_top_tb.mk Vcore_top_tb"
    verilator_cmd += f" && ./obj_dir/Vcore_top_tb"
    sim_log_path = os.path.join(work_dir, 'sim.log')
    with open(sim_log_path, 'w') as sim_log:
        process = subprocess.Popen(verilator_cmd, shell=True, stdout=sim_log, stderr=subprocess.STDOUT)
        process.wait()
        exit_code = process.returncode
        if exit_code != 0:
            vprint(f"Error: Verilator returned exit code {exit_code}")

def run_xsim(test: str) -> None:
    work_dir = os.path.join("work", test)
    test_path = test.split('.')
    is_mac_test = len(test_path) > 1 and test_path[1].startswith("mac_")
    reset_vector = DRAM_BASE if is_mac_test else LEGACY_BASE
    has_dmem = os.path.exists(os.path.join(work_dir, "dmem.hex"))
    xsim_cmd = f"export PROJ=$(pwd) && cd {work_dir} && xvlog -sv -f $PROJ/rtl/core_top.flist --define ICCM_INIT_FILE='\"imem.hex\"' --define RESET_VECTOR=32\\'h{reset_vector:x} --define STACK_POINTER_INIT_VALUE=32\\'h80000000"
    if has_dmem:
        xsim_cmd += f" --define DCCM_INIT_FILE='\"dmem.hex\"'"
    else:
        xsim_cmd += f" --define DCCM_INIT_FILE='\"\"'"
    xsim_cmd += f" && xelab -top core_top_tb -snapshot sim --debug wave && xsim sim --runall"
    sim_log_path = os.path.join(work_dir, 'sim.log')
    with open(sim_log_path, 'w') as sim_log:
        process = subprocess.Popen(xsim_cmd, shell=True, stdout=sim_log, stderr=subprocess.STDOUT)
        process.wait()
        exit_code = process.returncode
        if exit_code != 0:
            vprint(f"Error: XSim returned exit code {exit_code}")

def compare_results(test: str) -> None:
    try:
        with open(os.path.join("work", test, "iss.log"), "r") as f:
            iss_log_lines = f.read().splitlines()
        with open(os.path.join("work", test, "rtl.log"), "r") as f:
            rtl_log_lines = f.read().splitlines()
    except FileNotFoundError as e:
        print(f"Error comparing logs: {e}. One of the log files is missing.")
        print(f"{test} {'.' * (50 - len(test))}. FAILED")
        return
    iss_events, rtl_events = [], []
    for line in iss_log_lines:
        if not line.strip() or ";" not in line: continue
        parts = line.split(';')
        if len(parts) >= 4 and parts[3].strip():
            pc = parts[0].replace("0x", "").upper()
            instr = parts[1].replace("0x", "").upper()
            modification = parts[3].upper()
            iss_events.append((pc, instr, modification))
    for line in rtl_log_lines:
        if not line.strip() or ";" not in line: continue
        parts = line.split(';')
        if len(parts) >= 4 and parts[3].strip():
            pc = parts[1].replace("0x", "").upper()
            instr = parts[2].replace("0x", "").upper()
            modification = parts[3].upper()
            rtl_events.append((pc, instr, modification))
    test_passed = (iss_events == rtl_events)
    if test_passed:
        print(f"{test} {'.' * (50 - len(test))}. PASSED")
    else:
        print(f"{test} {'.' * (50 - len(test))}. FAILED")
        if VERBOSE:
            sim_log_path = os.path.join('work', test, 'sim.log')
            with open(sim_log_path, 'a') as sim_log:
                sim_log.write("\n--- LOG MISMATCH DETAILS ---\n")
                sim_log.write(f"ISS generated {len(iss_events)} events.\n")
                sim_log.write(f"RTL generated {len(rtl_events)} events.\n")
                max_len = max(len(iss_events), len(rtl_events))
                for i in range(max_len):
                    iss_event = iss_events[i] if i < len(iss_events) else ("ISS_MISSING",)*3
                    rtl_event = rtl_events[i] if i < len(rtl_events) else ("RTL_MISSING",)*3
                    if iss_event != rtl_event:
                        sim_log.write(f"First mismatch at index {i}:\n")
                        sim_log.write(f"  - ISS event: PC={iss_event[0]}, INSTR={iss_event[1]}, MOD={iss_event[2]}\n")
                        sim_log.write(f"  - RTL event: PC={rtl_event[0]}, INSTR={rtl_event[1]}, MOD={rtl_event[2]}\n")
                        break

def process_rtl_log(test: str):
    rtl_log_path = os.path.join("work", test, "rtl.log")
    try:
        with open(rtl_log_path, "r") as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        vprint(f"Warning: rtl.log not found for test {test}. Skipping log processing.")
        return
    test_parts = test.split('.')
    if len(test_parts) > 1 and test_parts[1].startswith("mac_"):
        termination_signature = "mem[0x10000000]=0xdeadbeef"
        original_line_count = len(lines)
        lines = [line for line in lines if termination_signature not in line]
        if len(lines) < original_line_count:
            vprint(f"Rilevato test MAC: rimozione della riga di terminazione contenente '{termination_signature}' da rtl.log")
    new_log_lines, i = [], 0
    while i < len(lines):
        if not lines[i]: i += 1; continue
        line_parts, action_taken = lines[i].split(";"), False
        if i + 1 < len(lines):
            next_line_parts = lines[i+1].split(";")
            is_potential_merge = (len(line_parts) >= 4 and len(next_line_parts) >= 4 and line_parts[1] == next_line_parts[1] and line_parts[2] == next_line_parts[2] and "mem[" in line_parts[3] and "mem[" in next_line_parts[3])
            if is_potential_merge:
                try:
                    effect, nxt_effect = line_parts[3], next_line_parts[3]
                    mem_addr = effect.split("[")[1].split("]")[0]
                    alignment = int(mem_addr, 16) % 4
                    lower_bytes = effect.split("=")[1].lstrip("0x")[8 - alignment * 2:]
                    higher_bytes = nxt_effect.split("=")[1].lstrip("0x")[:8 - alignment * 2]
                    merged_value = higher_bytes + lower_bytes
                    new_log_lines.append(f"{line_parts[0]};{line_parts[1]};{line_parts[2]};mem[{mem_addr}]=0x{merged_value.upper()}")
                    i += 2; action_taken = True
                except (IndexError, ValueError): pass
        if not action_taken:
            new_log_lines.append(lines[i]); i += 1
    with open(rtl_log_path, "w") as f:
        f.write("\n".join(new_log_lines) + "\n")

def run_e2e(test: str, simulator: str, objdump_cmd: str):
    try:
        run_gen(test)
        run_iss(test, objdump_cmd)
        prepare_imem(test)
        if simulator == "verilator":
            run_verilator(test)
        else:
            run_xsim(test)
        process_rtl_log(test)
        compare_results(test)
    except Exception as e:
        print(f"Error running test {test}: {e}")
        if VERBOSE:
            print(traceback.format_exc())
        raise e

def main():
    parser = argparse.ArgumentParser(description="Simulation Manager")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-t", "--task-list", help="Path to the task list file")
    group.add_argument("-n", "--test-name", help="Name of the test to run")
    parser.add_argument("-s", "--simulator", required=True, choices=["verilator", "xsim"], help="Simulator to use")
    parser.add_argument("--objdump", default="riscv64-unknown-elf-objdump", help="Path to riscv objdump")
    parser.add_argument("-d", "--debug", action="store_true", help="Enable verbose/debug printing")
    args = parser.parse_args()
    
    global VERBOSE
    if args.debug:
        VERBOSE = True

    os.makedirs("work", exist_ok=True)
    tests = read_task_list(args.task_list) if args.task_list else [args.test_name]
    if not tests:
        print("Error: No valid tests found.")
        sys.exit(1)
    num_cores = multiprocessing.cpu_count()
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_cores) as executor:
        future_to_test = {executor.submit(run_e2e, test, args.simulator, args.objdump): test for test in tests}
        for future in concurrent.futures.as_completed(future_to_test):
            test = future_to_test[future]
            try:
                future.result()
            except Exception as e:
                vprint(f"Error in thread for test {test}: {e}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)