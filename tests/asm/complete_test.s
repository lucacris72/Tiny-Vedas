    .globl   _start
    .section .text

_start:
    # accumulator
    li    x10, 0

    # Test 1: ADD
    li    x1, 5
    li    x2, 3
    add   x3, x1, x2        # 8
    add   x10, x10, x3

    # Test 2: SUB
    li    x1, 5
    li    x2, 3
    sub   x3, x1, x2        # 2
    add   x10, x10, x3

    # Test 3: AND, OR, XOR
    li    x1, 0b1100
    li    x2, 0b1010
    and   x3, x1, x2        # 8
    add   x10, x10, x3
    or    x3, x1, x2        # 14
    add   x10, x10, x3
    xor   x3, x1, x2        # 6
    add   x10, x10, x3

    # Test 4: SHIFT IMMEDIATE
    li    x1, 16
    slli  x2, x1, 2         # 64
    add   x10, x10, x2
    li    x1, 64
    srli  x2, x1, 3         # 8
    add   x10, x10, x2

    # Test 5: SET LESS‐THAN
    li    x1, 5
    li    x2, 10
    slt   x3, x1, x2        # 1
    add   x10, x10, x3
    slt   x3, x2, x1        # 0
    add   x10, x10, x3
    slti  x3, x1, 5         # 0
    add   x10, x10, x3
    slti  x3, x1, 6         # 1
    add   x10, x10, x3

    # Test 6: ADDI
    li    x1, 2
    addi  x2, x1, 3         # 5
    add   x10, x10, x2

    # Test 7: MUL
    li    x1, 4
    li    x2, 6
    mul   x3, x1, x2        # 24
    add   x10, x10, x3

    # Test 8: MUL + forwarding
    li    x1, 2
    li    x2, 3
    mul   x3, x1, x2        # 6
    add   x4, x3, x3        # 12
    add   x10, x10, x4

    # Test 9: BRANCHES
    # BEQ
    li    x1, 1
    li    x2, 1
    beq   x1, x2, BEQ_PASS
    li    x3, 0
BEQ_PASS:
    li    x3, 1
    add   x10, x10, x3

    # BNE
    li    x1, 1
    li    x2, 0
    bne   x1, x2, BNE_PASS
    li    x3, 0
BNE_PASS:
    li    x3, 2
    add   x10, x10, x3

    # BGE
    li    x1, 5
    li    x2, 3
    bge   x1, x2, BGE_PASS
    li    x3, 0
BGE_PASS:
    li    x3, 3
    add   x10, x10, x3

    # BLT
    li    x1, 3
    li    x2, 5
    blt   x1, x2, BLT_PASS
    li    x3, 0
BLT_PASS:
    li    x3, 4
    add   x10, x10, x3

    # Test 10: JAL
    jal   ra, JAL_LABEL
    j     JAL_DONE
JAL_LABEL:
    li    x3, 7
    add   x10, x10, x3
    jalr  x0, ra, 0
JAL_DONE:

    # Test 11: LUI + ADDI
    lui   x1, 0x1           # 0x1000 = 4096
    add   x10, x10, x1
    addi  x2, x1, 9         # 4105
    add   x10, x10, x2

    # confronto finale
    # somma attesa = 8+2+8+14+6+64+8+1+5+24+12+1+2+3+4+7+4096+4105 = 8400
    li    x11, 8400
    beq   x10, x11, TEST_PASS
    j     TEST_FAIL

TEST_FAIL:
    .include "eot_sequence.s"
TEST_PASS:
    .include "eot_sequence.s"
