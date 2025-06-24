    .globl   _start
    .section .text
_start:
    li   x10, 7
    li   x11, 3
    .word 0x00B5060B    # mac x12, x10, x11  ⇒ 7*3 + 0 = 21
    mv   x13, x12       # salva in x13

    li   x10, 2
    li   x11, 5
    .word 0x00B5060B    # mac x12, x10, x11  ⇒ 2*5 + 21 = 31
    mv   x14, x12       # salva in x14

    # ecall per uscire, con a0=x13(21), a1=x14(31)
    mv   a0, x13
    mv   a1, x14
    li   a7, 93         # ecall exit
    .include "eot_sequence.s"
