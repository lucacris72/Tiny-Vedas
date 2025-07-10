    .globl   _start
    .section .text

_start:
    # Setup puntatori e contatore
    li   x11, 4
    li   x12, 5
    li   x7,  200

L1:
    mul  x13, x11, x12
    add  x10, x10, x13

    mul  x13, x11, x12
    add  x10, x10, x13

    mul  x13, x11, x12
    add  x10, x10, x13

    mul  x13, x11, x12
    add  x10, x10, x13

    mul  x13, x11, x12
    add  x10, x10, x13

    addi x7, x7, -1
    bne  x7, x0, L1


    .include "./eot_sequence.s"
    