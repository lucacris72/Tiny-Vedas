    .globl   _start
    .section .text

_start:
    # Setup puntatori e contatore
    li   x11, 4
    li   x12, 5
    li   x7,  200
    li   x8,  5

L1:
    addi  x7, x0, 100
L2:
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B

    .word 0x0000150B

    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B
    .word 0x00C5850B

    addi x7, x7, -1
    bne  x7, x0, L2

    .word 0x0000150B
    addi x8, x8, -1
    bne  x8, x0, L1

    .include "./eot_sequence.s"
    