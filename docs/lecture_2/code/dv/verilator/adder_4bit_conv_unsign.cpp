#include "Vadder_4bit_conv_unsign_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);
    Vadder_4bit_conv_unsign_tb* top = new Vadder_4bit_conv_unsign_tb;

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("adder_4bit_conv_unsign.vcd");

    printf("****** START of 4 BIT ADDER TEST ****** \n");

    while (!Verilated::gotFinish()) {
        top->eval();
        tfp->dump(Verilated::time());
        Verilated::timeInc(1);
    }

    tfp->close();
    printf("****** END of 4 BIT ADDER TEST ****** \n");

    delete top;
    return 0;
}
