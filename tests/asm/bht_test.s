# tests/asm/bht_test.s
# Test per verificare il funzionamento della Branch History Table (BHT) a 2 bit.

.globl _start
.section .text

_start:
    # Inizializziamo un contatore a 5. Useremo questo registro per il loop.
    li      x10, 5

loop_start:
    # Eseguiamo qualche operazione inutile dentro il loop per occupare spazio.
    # Questo assicura che il target del branch sia a un offset significativo.
    addi    x11, x11, 1
    addi    x12, x12, 1

    # Decrementiamo il contatore del loop.
    addi    x10, x10, -1

    # Branch condizionale: torna a 'loop_start' se x10 non è zero.
    # Questo branch sarà preso 4 volte e non preso l'ultima volta.
    # Ci aspettiamo che il predittore impari questo comportamento.
    bne     x10, x0, loop_start

    # Il loop è terminato.
    # Il codice arriva qui dopo che il branch 'bne' non è stato preso.

    # Includiamo la sequenza di terminazione standard per la simulazione.
    .include "eot_sequence.s"

