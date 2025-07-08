    .globl _start
    .section .text

_start:
    # Conta da N a zero
    li    x1, 1000

loop_end:
    addi  x1, x1, -1
    bnez  x1, loop_end   # quasi sempre taken, fall-through solo all’uscita

    .include "eot_sequence.s"
    