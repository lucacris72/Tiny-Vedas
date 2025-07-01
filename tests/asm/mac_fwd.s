    .globl   _start
    .section .text
_start:
    # Carico due operandi in x10 e x11
    li      x10, 3       # 3
    li      x11, 4       # 4

    # --- 1ª MAC: acc = 0 + 3*4 = 12
    # usiamo rd=x12, rs1=x10, rs2=x11, opcode=0001011, funct3=000
    .word   0x00B5060B

    # --- 2ª MAC immediatamente dopo: acc = 12 + 3*4 = 24
    .word   0x00B5060B

    mv      x18, x12   # Move result to x18
    # Ecall per terminare
    li      x17, 93
   .include "./eot_sequence.s"
