    .globl _start
    .section .text

_start:
    # Loop counter
    li    x5, 1000

    # LCG state: x6 = seed, x7 = multiplier, x8 = increment
    li    x6, 12345
    li    x7, 1103515245
    li    x8, 12345

loop_rand:
    # x6 = x6 * 1103515245 + 12345
    mul   x6, x6, x7
    add   x6, x6, x8

    # bit0 -> x9
    andi  x9, x6, 1

    # se x9==0 -> not taken, altrimenti taken
    beq   x9, x0, not_taken
taken:
    # branch taken path (puoi mettere un nop o un piccolo lavoro)
    nop
    j     cont_rand
not_taken:
    # branch not taken path
    nop
cont_rand:
    addi  x5, x5, -1
    bnez  x5, loop_rand

    .include "eot_sequence.s"
