// rtl/pmu/perf_counter.sv
`ifndef GLOBAL_SVH
`include "global.svh"
`endif

module perf_counter #(
    parameter CNT_WIDTH = 64
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // Pulsi di incremento (1‑cycle high)
    input  logic                  incr_cycle,   // di solito 1'b1
    input  logic                  incr_instr,   // exu_wb_rd_wr_en && ~pipe_flush

    // Interfaccia CSR (opzionale – vedi §4)
    input  logic                  csr_we,
    input  logic [11:0]           csr_addr,
    input  logic [CNT_WIDTH-1:0]  csr_wdata,

    output logic [CNT_WIDTH-1:0]  mcycle_q,
    output logic [CNT_WIDTH-1:0]  minstret_q
);

    // MCYCLE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)          mcycle_q   <= '0;
        else if (csr_we && csr_addr == 12'hB00)  mcycle_q <= csr_wdata;
        else if (incr_cycle) mcycle_q   <= mcycle_q + 1'b1;
    end

    // MINSTRET
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                minstret_q <= '0;
        else if (csr_we && csr_addr == 12'hB02)  minstret_q <= csr_wdata;
        else if (incr_instr)       minstret_q <= minstret_q + 1'b1;
    end

endmodule
