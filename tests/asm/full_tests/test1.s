    .globl   _start
    .section .text
_start:
    # --- inizializzo qualche registro via addi
    addi  x10, x0,  3      # x10 ← 3
    addi  x11, x0,  5      # x11 ← 5

    # --- test MUL pipelined
    mul   x12, x10, x11    # x12 ← x10 * x11 = 3 * 5 = 15

    # --- store e load
    addi  x1,  x0,  0x10   # x1 ← 0x10 (offset di memoria)
    sw    x12, 0(x1)       # MEM[0x10] ← x12 = 15
    lw    x13, 0(x1)       # x13 ← MEM[0x10] = 15

    # --- (opzionale) reset dell’accumulatore via MACRESET  
    # .insn r CUSTOM0, 0, x0, x0, x0   # istruzione di reset dell’accumulatore

    # --- primo MAC: acc = 0 + (x10 * x11) = 0 + 3*5 = 15
    .word 0x00B5060B      # MAC rs1=x10, rs2=x11 → acc

    # --- secondo MAC: acc = 15 + (x10 * x11) = 15 + 3*5 = 30
    .word 0x00B5060B

    # --- qualche operazione ALU “di disturbo”
    addi  x14, x0,  7      # x14 ← 7
    sub   x15, x14, x10    # x15 ← x14 - x10 = 7 - 3 = 4

    # --- terzo MAC: acc = 30 + (x10 * x11) = 30 + 3*5 = 45
    .word 0x00B5060B

    # --- scriviamo il valore finale dell’accumulatore in memoria
    addi  x2, x0, 0x14     # x2 ← 0x14
    sw    x12, 0(x2)       # MEM[0x14] ← acc = 45
                          
    # --- Exit (ecall)
    addi  x17, x0, 93      # a7 ← 93 (syscall exit)
    .include "../eot_sequence.s"
