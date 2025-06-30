#!/usr/bin/env python3
"""
ISS + Verilator simulation pipeline: compile RISC-V assembly, simulate with Spike,
produce clean ISS log with numeric registers and original PCs,
generate imem.hex from ELF inside obj_dir, then optionally run Verilator RTL simulation and capture sim.log and move waveforms/logs.
Assume always run from project root; PROJ is set from environment or defaults to current working directory.
After RTL sim, move rtl.log and core_top.vcd from obj_dir to parent test directory.
"""
import argparse
import subprocess
import re
import os
import sys
import shutil

# mappa nome_registro -> numero
REG_MAP = {
    'zero': '0', 'ra': '1',  'sp': '2',  'gp': '3',  'tp': '4',
    't0': '5',    't1': '6',  't2': '7',  's0': '8',  's1': '9',
    'a0': '10',   'a1': '11', 'a2': '12', 'a3': '13', 'a4': '14',
    'a5': '15',   'a6': '16', 'a7': '17', 's2': '18', 's3': '19',
    's4': '20',   's5': '21', 's6': '22', 's7': '23', 's8': '24',
    's9': '25',   's10': '26','s11': '27','t3': '28','t4': '29',
    't5': '30',   't6': '31'
}
DRAM_BASE = 0x80000000

# PROJ: project root directory, from ENV or default to current cwd
PROJ = os.environ.get('PROJ', os.getcwd())
# export back
os.environ['PROJ'] = PROJ



def compile_test(asm_files, elf_path, riscv_gcc, isa, abi, link_script_path):
    link_script = (
"""
ENTRY(_start)
SECTIONS {
  . = 0x80000000;
  .text : { *(.text) }
  .rodata : { *(.rodata) }
  .data : { *(.data) }
  .bss : { *(.bss COMMON) }
}
"""
    )
    os.makedirs(os.path.dirname(link_script_path), exist_ok=True)
    with open(link_script_path, 'w') as f:
        f.write(link_script)
    src_dir = os.path.dirname(asm_files[0])
    cmd = [riscv_gcc, f"-march={isa}", f"-mabi={abi}", '-nostdlib', '-T', link_script_path]
    if src_dir:
        cmd += ['-I', src_dir]
    cmd += ['-o', elf_path] + asm_files
    print('Compilazione:', ' '.join(cmd))
    subprocess.run(cmd, check=True)


def generate_imem_hex(elf_path, imem_path, objcopy_cmd):
    bin_path = imem_path + '.bin'
    subprocess.run([objcopy_cmd, '-O', 'binary', '--only-section=.text', elf_path, bin_path], check=True)
    with open(bin_path, 'rb') as f_in, open(imem_path, 'w') as f_out:
        data = f_in.read()
        if len(data) % 4:
            data += b'\x00' * (4 - len(data) % 4)
        for i in range(0, len(data), 4):
            word = int.from_bytes(data[i:i+4], 'little')
            f_out.write(f"%08x\n" % word)
    os.remove(bin_path)
    print(f'Generato imem hex in obj_dir: {imem_path}')


def count_static_instructions(elf_path, objdump_cmd):
    proc = subprocess.run([objdump_cmd, '-d', elf_path], stdout=subprocess.PIPE, text=True, check=True)
    instr_count = 0
    in_text = False
    for line in proc.stdout.splitlines():
        if line.startswith("Disassembly of section .text"):
            in_text = True; continue
        if in_text and re.match(r"^\s*[0-9A-Fa-f]+:\s+[0-9A-Fa-f]{2}", line):
            instr_count += 1
    return instr_count


def run_spike_and_filter(elf_path, spike_cmd, isa, n, output_log):
    pc_re = re.compile(r"^core\s+0:\s+0x([0-9A-Fa-f]+)")
    regs = sorted(REG_MAP.items(), key=lambda x: -len(x[0]))
    # include --instructions to stop after n commits
    cmd = spike_cmd + ['-l', f'--isa={isa}', f'--instructions={n + 10}', elf_path]
    print('Simulazione ISS:', ' '.join(cmd))
    sp = subprocess.Popen(cmd, stderr=subprocess.PIPE, text=True)
    written = 0
    with open(output_log, 'w') as out:
        for line in sp.stderr:
            m = pc_re.match(line)
            if not m:
                continue
            pc = int(m.group(1), 16)
            if pc >= DRAM_BASE:
                line = re.sub(r'^core\s+0:\s*', '', line)
                orig_pc = pc - DRAM_BASE + 0x00100000  # adjust base
                line = re.sub(r'^0x[0-9A-Fa-f]+', f"0x{orig_pc:08x}", line)
                for name, num in regs:
                    line = re.sub(rf"\b{name}\b", f"x{num}", line)
                out.write(line)
    sp.terminate()
    print(f'ISS simulata fino a {n} istruzioni, log in {output_log}')


def run_verilator(work_dir, test_name):
    wd = os.path.join(PROJ, work_dir, test_name)
    obj_dir = os.path.join(wd, 'obj_dir')
    os.makedirs(obj_dir, exist_ok=True)
    imem = os.path.join(obj_dir, 'imem.hex')
    if not os.path.exists(imem):
        print('Errore: file imem.hex non trovato in obj_dir'); sys.exit(1)
    flist = os.path.join(PROJ, 'rtl', 'core_top.flist')
    tb = os.path.join(PROJ, 'dv', 'verilator', 'core_top_tb.cpp')
    cmd = ['verilator', '--cc', '--Mdir', obj_dir, '--trace', '--trace-structs', '--build', '--timing',
           '--top-module', 'core_top_tb', '--exe', tb, '-f', flist,
           f"-DICCM_INIT_FILE=\"{os.path.basename(imem)}\"",
           f"-DRESET_VECTOR=32'h100000", f"-DSTACK_POINTER_INIT_VALUE=32'h80000000"]
    dmem = os.path.join(wd, 'dmem.hex')
    if os.path.exists(dmem): cmd.append(f"-DDCCM_INIT_FILE=\"{os.path.basename(dmem)}\"" )
    else: cmd.append(f"-DDCCM_INIT_FILE=\"\"" )
    print('Simulazione RTL Verilator:', ' '.join(cmd))
    proc = subprocess.run(cmd, cwd=wd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if proc.returncode != 0:
        print('Errore Verilator build'); print(proc.stdout); sys.exit(1)
    exe = os.path.join(obj_dir, 'Vcore_top_tb')
    run_proc = subprocess.run([exe], cwd=obj_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    sim_log = os.path.join(wd, 'sim.log')
    with open(sim_log, 'w') as f:
        f.write(run_proc.stdout)
    if run_proc.returncode != 0:
        print(f'Error RTL sim {run_proc.returncode}'); sys.exit(1)
    for fname in ['rtl.log', 'core_top.vcd']:
        src = os.path.join(obj_dir, fname)
        dst = os.path.join(wd, fname)
        if os.path.exists(src): shutil.move(src, dst)
    print(f'Verilator log: {sim_log}')

def parse_iss_log(path):
    entries = {}
    with open(path) as f:
        for line in f:
            parts = line.strip().split(')', 1)
            if len(parts)<2: continue
            pc_str,rest = parts[0].split('(',1)
            entries[int(pc_str,16)] = rest.strip()
    return entries


def parse_rtl_log(path):
    entries = {}
    with open(path) as f:
        for line in f:
            cols=line.strip().split(';')
            if len(cols)<3: continue
            entries[int(cols[1],16)] = cols[2]
    return entries



def compare_logs(iss_path, rtl_path, cmp_path=None):
    # if no compare path provided, default to compare.log next to iss_path
    if cmp_path is None:
        cmp_path = os.path.join(os.path.dirname(iss_path), 'compare.log')
    iss = parse_iss_log(iss_path)
    rtl = parse_rtl_log(rtl_path)
    mismatches=[]
    with open(cmp_path,'w') as rpt:
        for pc in sorted(set(iss)&set(rtl)):
            i=iss[pc]; r=rtl[pc]
            line=f"0x{pc:08x}: ISS='{i}' RTL='{r}'"
            rpt.write(line+"\n")
            if i!=r: mismatches.append(pc)
        only_iss=set(iss)-set(rtl)
        only_rtl=set(rtl)-set(iss)
        for pc in sorted(only_iss): rpt.write(f"0x{pc:08x} only ISS\n")
        for pc in sorted(only_rtl): rpt.write(f"0x{pc:08x} only RTL\n")
    return len(mismatches)==0



def main():
    parser = argparse.ArgumentParser(description='Pipeline: ISS + optional RTL Verilator')
    parser.add_argument('asm', help='File assembly')
    parser.add_argument('--workdir', default='work', help='Working dir')
    parser.add_argument('--gcc', default='riscv32-unknown-elf-gcc', help='GCC cmd')
    parser.add_argument('--objdump', default='riscv32-unknown-elf-objdump', help='objdump cmd')
    parser.add_argument('--objcopy', default='riscv32-unknown-elf-objcopy', help='objcopy cmd')
    parser.add_argument('--spike', default='spike', help='Spike cmd')
    parser.add_argument('--isa', default='rv32im', help='ISA')
    parser.add_argument('--abi', default='ilp32', help='ABI')
    parser.add_argument('--rtl', action='store_true', help='Run Verilator RTL')
    parser.add_argument('--compare', action='store_true', help='Compare iss.log and rtl.log')
    args = parser.parse_args()
    test_path = args.asm
    test = os.path.splitext(os.path.basename(test_path))[0]
    src_dir = os.path.dirname(test_path)
    eot = os.path.join(src_dir, 'eot_sequence.s')
    asm_files = [test_path]
    if os.path.exists(eot): asm_files.append(eot)
    out_dir = os.path.join(PROJ, args.workdir, test)
    os.makedirs(out_dir, exist_ok=True)
    elf = os.path.join(out_dir, f"{test}.elf")
    ld = os.path.join(out_dir, 'link.ld')
    obj_dir = os.path.join(out_dir, 'obj_dir')
    os.makedirs(obj_dir, exist_ok=True)
    imem = os.path.join(obj_dir, 'imem.hex')
    iss_log = os.path.join(out_dir, 'iss.log')
    compile_test(asm_files, elf, args.gcc, args.isa, args.abi, ld)
    generate_imem_hex(elf, imem, args.objcopy)
    n = count_static_instructions(elf, args.objdump)
    print(f'Istruzioni ISS: {n}')
    run_spike_and_filter(elf, [args.spike], args.isa, n, iss_log)
    if args.rtl: run_verilator(args.workdir, test)
    if args.compare:
        iss_log=os.path.join(PROJ,args.workdir,test,'iss.log')
        rtl_log=os.path.join(PROJ,args.workdir,test,'rtl.log')
        cmp_log=os.path.join(PROJ,args.workdir,test,'compare.log')
        ok=compare_logs(iss_log,rtl_log,cmp_log)
        status='PASSED' if ok else 'FAILED'
        print(f"{test} ...... {status}")

if __name__=='__main__':
    main()
