/*
 * Copyright (c) 2025 Luca Donato
 *
 * This file is part of a custom RISC-V core extension developed for a
 * project at Politecnico di Milano. It builds upon a base core
 * provided by Siliscale, licensed under the MIT License.
 *
 * --------------------------------------------------------------------------------
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


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
    input  logic                  incr_cycle,
    input  logic                  incr_instr,   // exu_wb_rd_wr_en && ~pipe_flush

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
