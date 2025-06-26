    .globl   _start
    .section .text
_start:
    # Carico due operandi in x10 e x11
    li      x10, 3       # 3
    li      x11, 4       # 4
    addi    x13, x0, 0
    addi    x12, x0, 0

    # --- 1ª MAC: acc = 0 + 3*4 = 12
    # usiamo rd=x12, rs1=x10, rs2=x11, opcode=0001011, funct3=000

    .word   0x00B5060B

    .word   0x00B5060B

    .word   0x00B5060B

    .word   0x00B5060B

    .word   0x00B5060B

    .word   0x0000100B

    .word   0x00B5060B

    .word   0x00B5060B

    # Salvo il risultato nel DCCM per ispezione
    li      x1, 0x10     # puntatore base 0x10
    sw      x12, 0(x1)   # DCCM[0x10] = acc_reg

   .include "./eot_sequence.s"
