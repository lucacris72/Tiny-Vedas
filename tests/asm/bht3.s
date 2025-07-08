    .globl _start
    .section .text

_start:
    li    x1, 1000       # loop count
    li    x2, 0          # toggle bit

loop_alt:
    # flip toggle
    xori  x2, x2, 1

    # quando x2=1 branch taken, altrimenti not taken
    bnez  x2, taken_alt
not_taken_alt:
    nop
    j     cont_alt
taken_alt:
    nop
cont_alt:
    addi  x1, x1, -1
    bnez  x1, loop_alt

    .include "eot_sequence.s"
