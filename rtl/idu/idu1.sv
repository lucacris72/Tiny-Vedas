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

`ifndef TYPES_SVH
`include "types.svh"
`endif

module idu1 #(
    parameter logic [XLEN-1:0] STACK_POINTER_INIT_VALUE = 32'h80000000
) (
    input logic clk,
    input logic rst_n,

    /* IDU0 -> IDU1 Interface */
    input idu0_out_t idu0_out,

    /* IDU1 -> EXU Interface */
    output idu1_out_t idu1_out,

    /* Control Signals */
    output logic            pipe_stall,
    input  logic            pipe_flush,
    /* EXU -> IDU1 (WB) Interface */
    input  logic [XLEN-1:0] exu_wb_data,
    input  logic [     4:0] exu_wb_rd_addr,
    input  logic            exu_wb_rd_wr_en,
    input  logic            exu_mul_busy,
    input  logic            exu_mac_busy,
    input  logic            exu_div_busy,
    input  logic            exu_lsu_busy,
    input  logic            exu_lsu_stall
);

  idu1_out_t idu1_out_i;
  idu1_out_t idu1_out_before_fwd;
  logic [XLEN-1:0] rs1_data, rs2_data;
  last_issued_instr_t last_issued_instr;
  idu1_out_t idu1_out_gated;

  /* Instantiate Register file */
  reg_file #(
      .STACK_POINTER_INIT_VALUE(STACK_POINTER_INIT_VALUE)
  ) reg_file_i (
      .clk      (clk),
      .rst_n    (rst_n),
      .rs1_addr (idu0_out.rs1_addr),
      .rs2_addr (idu0_out.rs2_addr),
      .rs1_rd_en(idu0_out.rs1 & idu0_out.legal),
      .rs2_rd_en(idu0_out.rs2 & idu0_out.legal),
      .rs1_data (rs1_data),
      .rs2_data (rs2_data),
      .rd_addr  (exu_wb_rd_addr),
      .rd_data  (exu_wb_data),
      .rd_wr_en (exu_wb_rd_wr_en)
  );

  assign idu1_out_i.instr = idu0_out.instr;
  assign idu1_out_i.instr_tag = idu0_out.instr_tag;
  assign idu1_out_i.imm = idu0_out.imm;
  assign idu1_out_i.rd_addr = idu0_out.rd_addr;
  assign idu1_out_i.shamt = idu0_out.shamt;
  assign idu1_out_i.imm_valid = idu0_out.imm_valid;

  assign idu1_out_i.rs1_addr = idu0_out.rs1_addr;
  assign idu1_out_i.rs2_addr = idu0_out.rs2_addr;

  assign idu1_out_i.predicted_taken = idu0_out.predicted_taken;

  /* WB to IDU1 forwarding */
  assign idu1_out_i.rs1_data = (exu_wb_rd_addr == idu0_out.rs1_addr & exu_wb_rd_wr_en) ? exu_wb_data : rs1_data;
  assign idu1_out_i.rs2_data = (exu_wb_rd_addr == idu0_out.rs2_addr & exu_wb_rd_wr_en) ? exu_wb_data : rs2_data;

  assign idu1_out_i.alu = idu0_out.alu;
  assign idu1_out_i.rs1 = idu0_out.rs1;
  assign idu1_out_i.rs2 = idu0_out.rs2;
  assign idu1_out_i.imm12 = idu0_out.imm12;
  assign idu1_out_i.rd = idu0_out.rd;
  assign idu1_out_i.shimm5 = idu0_out.shimm5;
  assign idu1_out_i.imm20 = idu0_out.imm20;
  assign idu1_out_i.pc = idu0_out.pc;
  assign idu1_out_i.load = idu0_out.load;
  assign idu1_out_i.store = idu0_out.store;
  assign idu1_out_i.lsu = idu0_out.lsu;
  assign idu1_out_i.add = idu0_out.add;
  assign idu1_out_i.sub = idu0_out.sub;
  assign idu1_out_i.land = idu0_out.land;
  assign idu1_out_i.lor = idu0_out.lor;
  assign idu1_out_i.lxor = idu0_out.lxor;
  assign idu1_out_i.sll = idu0_out.sll;
  assign idu1_out_i.sra = idu0_out.sra;
  assign idu1_out_i.srl = idu0_out.srl;
  assign idu1_out_i.slt = idu0_out.slt;
  assign idu1_out_i.unsign = idu0_out.unsign;
  assign idu1_out_i.condbr = idu0_out.condbr;
  assign idu1_out_i.beq = idu0_out.beq;
  assign idu1_out_i.bne = idu0_out.bne;
  assign idu1_out_i.bge = idu0_out.bge;
  assign idu1_out_i.blt = idu0_out.blt;
  assign idu1_out_i.jal = idu0_out.jal;
  assign idu1_out_i.by = idu0_out.by;
  assign idu1_out_i.half = idu0_out.half;
  assign idu1_out_i.word = idu0_out.word;
  assign idu1_out_i.mul = idu0_out.mul;
  assign idu1_out_i.mac = idu0_out.mac;
  assign idu1_out_i.rs1_sign = idu0_out.rs1_sign;
  assign idu1_out_i.rs2_sign = idu0_out.rs2_sign;
  assign idu1_out_i.low = idu0_out.low;
  assign idu1_out_i.div = idu0_out.div;
  assign idu1_out_i.rem = idu0_out.rem;
  assign idu1_out_i.nop = idu0_out.nop;
  assign idu1_out_i.legal = idu0_out.legal;

  dff_rst_en_flush #(
      .WIDTH($bits(idu1_out_t))
  ) idu1_out_reg (
      .clk  (clk),
      .rst_n(rst_n),
      .din  (idu1_out_i),
      .dout (idu1_out_before_fwd),
      .en   (~pipe_stall),
      .flush(pipe_flush)
  );

  dff_rst_en_flush #(
      .WIDTH($bits(last_issued_instr_t))
  ) last_issued_instr_reg (
      .clk(clk),
      .rst_n(rst_n),
      .din({
        idu1_out_before_fwd.instr,
        idu1_out_before_fwd.instr_tag,
        idu1_out_before_fwd.rs1_addr,
        idu1_out_before_fwd.rs2_addr,
        idu1_out_before_fwd.rd_addr,
        idu1_out_before_fwd.mul,
        idu1_out_before_fwd.mac,
        idu1_out_before_fwd.alu,
        idu1_out_before_fwd.div,
        (idu1_out_before_fwd.load | idu1_out_before_fwd.store)
      }),
      .dout(last_issued_instr),
      .en(~pipe_stall),
      .flush(pipe_flush)
  );

  /* WB to EXU forwarding */
  always_comb begin : operand_forwarding
    idu1_out_gated = idu1_out_before_fwd;

    if (idu1_out_before_fwd.rs1 & (exu_wb_rd_addr == idu1_out_before_fwd.rs1_addr)) begin
      idu1_out_gated.rs1_data = exu_wb_data;
    end

    if (idu1_out_before_fwd.rs2 & (exu_wb_rd_addr == idu1_out_before_fwd.rs2_addr)) begin
      idu1_out_gated.rs2_data = exu_wb_data;
    end
  end

  /* Manage The pipe_stall signal 
     Stallo per MUL, DIV, LSU e MAC con forwarding tra MAC consecutive:
       1. Se è in corso una MUL e la prossima è un’istruzione valida ≠ MUL → stall finché exu_mul_busy
       2. Se è in corso una MUL e la prossima è MUL dipendente → stall finché exu_mul_busy
       3. Se è in corso una DIV → stall finché exu_div_busy
       4. Se è in corso una LSU e la prossima è un’istruzione valida ≠ LSU → stall finché exu_lsu_busy
       5. Se è in corso una MAC e la prossima è MAC non dipendente → NO STALL
       6. Se è in corso una MAC e la prossima è MAC dipendente → stall finché exu_mac_busy
  */
  always_comb begin : pipe_stall_management
    pipe_stall = 1'b0;

    // --- MUL cases --------------------------------------------------------
    if ( last_issued_instr.mul
      & ~idu1_out_gated.mul
      &  idu1_out_gated.legal
      & ~idu1_out_gated.nop
    ) begin
      pipe_stall = exu_mul_busy;
    end
    else if ( last_issued_instr.mul
           &   idu1_out_gated.mul
           &  ((last_issued_instr.rd_addr == idu1_out_gated.rs1_addr)
            | (last_issued_instr.rd_addr == idu1_out_gated.rs2_addr))
           &   idu1_out_gated.legal
           & ~idu1_out_gated.nop
    ) begin
      pipe_stall = exu_mul_busy;
    end
    // --- DIV case --------------------------------------------------------
    else if (last_issued_instr.div) begin
      pipe_stall = exu_div_busy;
    end
    // --- LSU case --------------------------------------------------------
    else if ( last_issued_instr.lsu
           & ~idu1_out_gated.lsu
           &  idu1_out_gated.legal
           & ~idu1_out_gated.nop
    ) begin
      pipe_stall = exu_lsu_busy;
    end

    // --- MAC cases --------------------------------------------------------
    // 5.a Se è in corso una MAC e la prossima NON è MAC → stall finché mac_busy
    else if ( last_issued_instr.mac
           & ~idu1_out_gated.mac
           &  idu1_out_gated.legal
           & ~idu1_out_gated.nop
    ) begin
      pipe_stall = exu_mac_busy;
    end
    // 6.b Se due MAC consecutive dipendono dallo stesso rd_addr → stall finché mac_busy
    else if ( last_issued_instr.mac
           &   idu1_out_gated.mac
           &  ((last_issued_instr.rd_addr == idu1_out_gated.rs1_addr)
            | (last_issued_instr.rd_addr == idu1_out_gated.rs2_addr))
           &   idu1_out_gated.legal
           & ~idu1_out_gated.nop
    ) begin
      pipe_stall = exu_mac_busy;
    end

    // Propaga lo stall da LSU (se presente)
    pipe_stall |= exu_lsu_stall;
  end


  // Mantieni uguale la logica di validità/legality perché idu1_out.nop venga imposto
  always_comb begin : pipe_stall_output
    if (pipe_stall) begin
      // Se stiamo in stall, non facciamo entrare alcuna istruzione
      idu1_out = '0;
    end else begin
      // Altrimenti passiamo al prossimo stadio tutto il pacchetto di segnali
      idu1_out = idu1_out_gated;
    end
  end


endmodule
