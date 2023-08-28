#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VRGBSigGen.h"
#include "VRGBSigGen___024root.h"

#define pCLK 1.0/38400000.0
#define CYCLES 40000
#define MAX_SIM_TIME pCLK*1000000000*CYCLES
 
vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    VRGBSigGen *dut = new VRGBSigGen;

    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        dut->pixelClk ^= 1;
        if (sim_time > pCLK*1000000000*3.5)
           dut->enable = 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
