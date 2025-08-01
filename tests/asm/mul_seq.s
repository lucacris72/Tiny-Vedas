    .globl   _start
    .section .text
_start:
    # Carico due operandi in x10 e x11
    li      x10, 3       # 3
    li      x11, 4       # 4
    addi    x13, x0, 0
    addi    x12, x0, 0

    # --- 1ª MAC: acc = 0 + 3*4 = 12

    mul     x13, x10, x11

    add     x12, x12, x13

    mul     x13, x10, x11

    add     x12, x12, x13

    mul     x13, x10, x11

    add     x12, x12, x13

    mul     x13, x10, x11

    add     x12, x12, x13

    mul     x13, x10, x11

    add     x12, x12, x13


    # Salvo il risultato nel DCCM per ispezione
    li      x1, 0x10     # puntatore base 0x10
    sw      x12, 0(x1)   # DCCM[0x10] = acc_reg

   .include "./eot_sequence.s"
