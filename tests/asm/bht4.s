# tests/asm/bht_biased.s
#
# Scopo: Dimostrare il vantaggio di un Branch Predictor dinamico (BHT)
#        in uno scenario con un branch fortemente polarizzato (quasi sempre preso).
#
# Comportamento Atteso:
# - Un predittore statico "Always-Not-Taken" avrebbe ~99% di misprediction.
# - La BHT a 2 bit dovrebbe avere un tasso di misprediction molto basso (~2%),
#   sbagliando solo alla prima e all'ultima iterazione del loop interno.

.globl _start
.section .text

_start:
    # Questo test esegue un loop interno 100 volte.
    # Ripetiamo l'intero esperimento 5 volte (outer_loop) per avere dati statistici più robusti.
    li      x1, 5           # Contatore del loop esterno

outer_loop:
    li      x10, 100        # Contatore del loop interno

inner_loop:
    # Un po' di lavoro inutile per riempire il loop
    addi    x11, x11, 1
    
    # Decrementa il contatore del loop interno
    addi    x10, x10, -1

    # Questo branch sarà PRESO 99 volte consecutive e NON PRESO 1 volta.
    # La BHT dovrebbe imparare questo comportamento dopo la prima iterazione.
    bnez    x10, inner_loop

    # Decrementa il contatore del loop esterno e ricomincia se non è zero
    addi    x1, x1, -1
    bnez    x1, outer_loop


# Fine del programma
.include "eot_sequence.s"
