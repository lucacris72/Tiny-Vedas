    .globl   _start
    .section .text

_start:
    # Setup puntatori e contatore
    li   x11, 4
    li   x12, 5
    li   x7,  200
L1:
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    addi x7, x7, -1
    bne  x7, x0, L1


    .include "./eot_sequence.s"
    