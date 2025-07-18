/*
MIT License

Copyright (c) 2025 Siliscale Consulting LLC

https://siliscale.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions
of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/

/* ***** Tiny Vedas Core Top ***** */

`ifndef GLOBAL_SVH
`include "global.svh"
`endif

`ifndef TYPES_SVH
`include "types.svh"
`endif

module core_top #(
    parameter string ICCM_INIT_FILE = "",
    parameter string DCCM_INIT_FILE = "",
    parameter logic [XLEN-1:0] STACK_POINTER_INIT_VALUE = 32'h80000000
) (

    /* Clock and Reset */
    input logic            clk,
    input logic            rst_n,
    input logic [XLEN-1:0] reset_vector

);

  /* Signals Definitions */

  /* Instruction Memory <-> IFU Interface */
  logic      [INSTR_MEM_ADDR_WIDTH-1:0] instr_mem_addr;
  logic                                 instr_mem_addr_valid;
  logic      [ INSTR_MEM_TAG_WIDTH-1:0] instr_mem_tag_out;
  logic      [     INSTR_MEM_WIDTH-1:0] instr_mem_rdata;
  logic                                 instr_mem_rdata_valid;
  logic      [ INSTR_MEM_TAG_WIDTH-1:0] instr_mem_tag_in;

  /* IFU -> IDU0 Interface */
  logic      [           INSTR_LEN-1:0] instr;
  logic                                 instr_valid;
  logic                                 predicted_taken_from_ifu;

  /* IDU0 -> IDU1 Interface */
  idu0_out_t                            idu0_out;

  /* IDU1 -> EXU Interface */
  idu1_out_t                            idu1_out;
  logic                                 pipe_stall;

  /* EXU -> IDU1 (WB) Interface */
  logic      [                XLEN-1:0] exu_wb_data = '0;
  logic      [                     4:0] exu_wb_rd_addr = '0;
  logic                                 exu_wb_rd_wr_en = '0;
  logic                                 exu_mul_busy;
  logic                                 exu_div_busy;
  logic                                 exu_mac_busy;
  logic                                 exu_lsu_busy;
  logic                                 exu_lsu_stall;

  /* EXU -> PC Interface */
  logic      [                XLEN-1:0] pc_out;
  logic                                 pc_load;

  /* EXU -> IFU Interface */
  logic                                 branch_feedback_is_branch;
  logic                                 branch_feedback_taken;
  logic      [                XLEN-1:0] branch_feedback_pc;
  logic      [                XLEN-1:0] branch_feedback_target_pc;

  /* Data Memory */
  logic      [                XLEN-1:0] dccm_raddr;
  logic                                 dccm_rvalid_in;
  logic      [                XLEN-1:0] dccm_rdata;
  logic                                 dccm_rvalid_out;
  logic      [                XLEN-1:0] dccm_waddr;
  logic                                 dccm_wen;
  logic      [                XLEN-1:0] dccm_wdata;
  /* ONLY FOR DEBUG */
  logic      [                XLEN-1:0] exu_instr_tag_out;
  logic      [                XLEN-1:0] exu_instr_out;
  logic      [                XLEN-1:0] instr_tag;

  /* Performance Monitor Unit (PMU) */
  logic incr_cycle;     // sempre 1
  logic incr_instr;     // pulse @commit
  logic commit_valid;   // pulse @commit
  logic [63:0] mcycle_q, minstret_q;

  /* Modules Instantiations */

  /* Performance Monitor Unit (PMU) */

  assign incr_cycle = 1'b1; 
  assign commit_valid = exu_wb_rd_wr_en | dccm_wen | ifu_inst.pc_load;
  assign incr_instr = commit_valid; //exu_wb_rd_wr_en & ~pc_load;
  perf_counter #(
        .CNT_WIDTH(64)
    ) pmu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .incr_cycle(incr_cycle),
        .incr_instr(incr_instr),
        .csr_we(1'b0),
        .csr_addr(12'd0),
        .csr_wdata('0),
        .mcycle_q(mcycle_q),
        .minstret_q(minstret_q)
    );

  /* Instruction Memory */
  iccm #(
      .DEPTH(INSTR_MEM_DEPTH),
      .WIDTH(INSTR_MEM_WIDTH),
      .INIT_FILE(ICCM_INIT_FILE)
  ) iccm_inst (
      .clk       (clk),
      .rst_n     (rst_n),
      .raddr     (instr_mem_addr),
      .rtag_in   (instr_mem_tag_out),
      .rvalid_in (instr_mem_addr_valid),
      .rdata     (instr_mem_rdata),
      .rtag_out  (instr_mem_tag_in),
      .rvalid_out(instr_mem_rdata_valid)
  );

  /* Instruction Fetch Unit */
  ifu ifu_inst (
      .clk                  (clk),
      .rst_n                (rst_n),
      .reset_vector         (reset_vector),
      .instr_mem_addr       (instr_mem_addr),
      .instr_mem_addr_valid (instr_mem_addr_valid),
      .instr_mem_rdata      (instr_mem_rdata),
      .instr_mem_rdata_valid(instr_mem_rdata_valid),
      .instr_mem_tag_out    (instr_mem_tag_out),
      .instr_mem_tag_in     (instr_mem_tag_in),
      .instr                (instr),
      .instr_valid          (instr_valid),
      .instr_tag            (instr_tag),
      .pipe_stall           (pipe_stall),
      .pc_exu               (pc_out),
      .pc_load              (pc_load),
      .predicted_taken_out  (predicted_taken_from_ifu),
      .exu_is_branch        (branch_feedback_is_branch),
      .exu_branch_taken     (branch_feedback_taken),
      .exu_target_pc        (branch_feedback_target_pc),
      .exu_branch_pc        (branch_feedback_pc)
  );

  /* Instruction Decode Unit - Stage 0 */
  idu0 idu0_inst (
      .clk        (clk),
      .rst_n      (rst_n),
      .instr      (instr),
      .instr_valid(instr_valid),
      .instr_tag  (instr_tag),
      .predicted_taken_from_ifu(predicted_taken_from_ifu),
      .pipe_stall (pipe_stall),
      .idu0_out   (idu0_out),
      .pipe_flush (pc_load)
  );

  /* Instruction Decode Unit - Stage 1 */
  idu1 #(
      .STACK_POINTER_INIT_VALUE(STACK_POINTER_INIT_VALUE)
  ) idu1_inst (
      .clk            (clk),
      .rst_n          (rst_n),
      .idu0_out       (idu0_out),
      .idu1_out       (idu1_out),
      .exu_wb_data    (exu_wb_data),
      .exu_wb_rd_addr (exu_wb_rd_addr),
      .exu_wb_rd_wr_en(exu_wb_rd_wr_en),
      .exu_mul_busy   (exu_mul_busy),
      .exu_mac_busy   (exu_mac_busy),
      .exu_div_busy   (exu_div_busy),
      .exu_lsu_busy   (exu_lsu_busy),
      .exu_lsu_stall  (exu_lsu_stall),
      .pipe_stall     (pipe_stall),
      .pipe_flush     (pc_load)
  );

  /* Execute Unit */
  exu exu_inst (
      .clk            (clk),
      .rst_n          (rst_n),
      .idu1_out       (idu1_out),
      /* ONLY FOR DEBUG */
      .instr_tag_out  (exu_instr_tag_out),
      .instr_out      (exu_instr_out),
      .exu_wb_data    (exu_wb_data),
      .exu_wb_rd_addr (exu_wb_rd_addr),
      .exu_wb_rd_wr_en(exu_wb_rd_wr_en),
      .exu_mul_busy   (exu_mul_busy),
      .exu_div_busy   (exu_div_busy),
      .exu_lsu_busy   (exu_lsu_busy),
      .exu_mac_busy   (exu_mac_busy),
      .exu_lsu_stall  (exu_lsu_stall),
      .dccm_raddr     (dccm_raddr),
      .dccm_rvalid_in (dccm_rvalid_in),
      .dccm_rdata     (dccm_rdata),
      .dccm_rvalid_out(dccm_rvalid_out),
      .dccm_waddr     (dccm_waddr),
      .dccm_wen       (dccm_wen),
      .dccm_wdata     (dccm_wdata),
      .pc_out         (pc_out),
      .pc_load        (pc_load),
      .exu_is_branch_out    (branch_feedback_is_branch),
      .exu_branch_taken_out (branch_feedback_taken),
      .exu_branch_pc_out    (branch_feedback_pc),
      .exu_target_pc_out    (branch_feedback_target_pc)
  );

  dccm #(
      .DEPTH    (DATA_MEM_DEPTH),
      .WIDTH    (DATA_MEM_WIDTH),
      .INIT_FILE(DCCM_INIT_FILE)
  ) dccm_inst (
      .clk       (clk),
      .rst_n     (rst_n),
      .raddr     ({2'b00, dccm_raddr[DATA_MEM_ADDR_WIDTH-3:2]}),
      .rvalid_in (dccm_rvalid_in),
      .rdata     (dccm_rdata),
      .rvalid_out(dccm_rvalid_out),
      .waddr     ({2'b00, dccm_waddr[DATA_MEM_ADDR_WIDTH-3:2]}),
      .wen       (dccm_wen),
      .wdata     (dccm_wdata)
  );

endmodule
