#include "Vmac_tb.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);
    Vmac_tb* top = new Vmac_tb;
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("mac.vcd");

    printf("****** START of MAC UNIT TEST ****** \n");

    while (!Verilated::gotFinish()) {
        top->eval();
        tfp->dump(Verilated::time());
        Verilated::timeInc(1);
    }

    tfp->close();
    printf("****** END of MAC UNIT TEST ****** \n");

    delete top;
    return 0;
}
