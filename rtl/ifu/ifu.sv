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

`ifndef GLOBAL_SVH
`include "global.svh"
`endif

module ifu (
    /* Clock and Reset */
    input logic            clk,
    input logic            rst_n,
    input logic [XLEN-1:0] reset_vector,

    /* Instruction Memory Interface */
    output logic [INSTR_MEM_ADDR_WIDTH-1:0] instr_mem_addr,
    output logic                            instr_mem_addr_valid,
    output logic [                XLEN-1:0] instr_mem_tag_out,
    input  logic [     INSTR_MEM_WIDTH-1:0] instr_mem_rdata,
    input  logic                            instr_mem_rdata_valid,
    input  logic [ INSTR_MEM_TAG_WIDTH-1:0] instr_mem_tag_in,

    /* EXU -> IFU Interface */
    input logic [XLEN-1:0] pc_exu,
    input logic            pc_load,
    input logic            exu_is_branch,
    input logic            exu_branch_taken,
    input logic [XLEN-1:0] exu_branch_pc,
    input logic [XLEN-1:0] exu_target_pc,

    /* Control Signals */
    input  logic                 pipe_stall,
    output logic [INSTR_LEN-1:0] instr,
    output logic                 instr_valid,
    output logic [     XLEN-1:0] instr_tag,

    output logic predicted_taken_out
);

  logic [XLEN-1:0] pc_out;
  logic            pc_out_valid;
  
  logic            bht_predicted_taken;
  logic            btb_hit;
  logic [XLEN-1:0] btb_target_pc;
  logic            predict_take_branch;

  assign instr_mem_addr = (predict_take_branch) ? btb_target_pc[INSTR_MEM_ADDR_WIDTH-1:0] : pc_out[INSTR_MEM_ADDR_WIDTH-1:0];  /* Crop the PC since the instr_mem_addr
                                                                is narrower than the PC */
  assign instr_mem_tag_out = (predict_take_branch) ? btb_target_pc : pc_out;

  bht #( .BHT_ENTRIES(1024) ) i_bht (
      .clk                (clk),
      .rst_n              (rst_n),
      .predict_pc         (instr_mem_tag_in),
      .predict_taken      (bht_predicted_taken),
      .update_en          (exu_is_branch),
      .update_pc          (exu_branch_pc),
      .update_actual_taken(exu_branch_taken)
  );

  btb #( .BTB_ENTRIES(1024) ) i_btb (
      .clk               (clk),
      .rst_n             (rst_n),
      .predict_pc        (instr_mem_tag_in),
      .predict_hit       (btb_hit),
      .predict_target_pc (btb_target_pc),
      .update_en         (exu_is_branch && exu_branch_taken), // Scriviamo solo se il branch è preso
      .update_pc         (exu_branch_pc),
      .update_target_pc  (exu_target_pc)
  );

  assign predict_take_branch = bht_predicted_taken && btb_hit;
    
  /* Instantiate the Program Counter */
  pc pc_inst (
      .clk         (clk),
      .rst_n       (rst_n),
      .reset_vector(reset_vector),
      .load        (pc_load),
      .inc         (~pc_load),
      .stall       (pipe_stall),
      .pc_in       (pc_exu),
      .pc_out      (pc_out),
      .pc_out_valid(pc_out_valid),
      .predict_take_branch  (predict_take_branch),
      .predict_target_pc_in (btb_target_pc)
  );

  assign instr_mem_addr_valid = pc_out_valid & ~pc_load;

  /* Generate the outputs */
  dff_rst_en_flush #(INSTR_LEN + 1 + XLEN + 1) instr_dff_rst_inst (
      .clk  (clk),
      .rst_n(rst_n),
      .din  ({bht_predicted_taken, instr_mem_rdata_valid, instr_mem_rdata, instr_mem_tag_in}),
      .dout ({predicted_taken_out, instr_valid, instr, instr_tag}),
      .en   (~pipe_stall),
      .flush(pc_load)
  );
endmodule
