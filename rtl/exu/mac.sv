`ifndef GLOBAL_SVH
`include "global.svh"
`endif

`ifndef TYPES_SVH
`include "types.svh"
`endif

// Pipelined MAC unit: Radix-4 Booth + Carry-Select Adder (16-bit)
module mac (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             freeze,
    input  idu1_out_t        mac_ctrl,

    output logic [XLEN-1:0]  out,
    output logic [4:0]       out_rd_addr,
    output logic             out_rd_wr_en,

    output logic [XLEN-1:0]  instr_tag_out,
    output logic [31:0]      instr_out,

    output logic             mac_busy
);

  // Internal accumulator register
  logic [XLEN-1:0] acc_reg;

  // Update ACC register at write-back
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)        acc_reg <= '0;
    else if (out_rd_wr_en && !freeze) acc_reg <= out;
  end

  // --------------------------------------------------------------------------
  // Stage1: Capture control, operands, instruction, and ACC (signal-based)
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s1_rs1_data,   s1_rs1_data_next;
  logic [XLEN-1:0] s1_rs2_data,   s1_rs2_data_next;
  logic [XLEN-1:0] s1_acc_old,    s1_acc_old_next;
  logic [XLEN-1:0] s1_instr_tag,  s1_instr_tag_next;
  logic [31:0]     s1_instr,      s1_instr_next;
  idu1_out_t       s1_ctrl,       s1_ctrl_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_rs1_data   <= '0;
      s1_rs2_data   <= '0;
      s1_acc_old    <= '0;
      s1_instr_tag  <= '0;
      s1_instr      <= '0;
      s1_ctrl       <= '0;
    end else if (!freeze) begin
      s1_rs1_data   <= s1_rs1_data_next;
      s1_rs2_data   <= s1_rs2_data_next;
      s1_acc_old    <= s1_acc_old_next;
      s1_instr_tag  <= s1_instr_tag_next;
      s1_instr      <= s1_instr_next;
      s1_ctrl       <= s1_ctrl_next;
    end
  end

  always_comb begin
    s1_rs1_data_next   = mac_ctrl.rs1_data;
    s1_rs2_data_next   = mac_ctrl.rs2_data;
    s1_acc_old_next    = acc_reg;
    s1_instr_tag_next  = mac_ctrl.instr_tag;
    s1_instr_next      = mac_ctrl.instr;
    s1_ctrl_next       = mac_ctrl;
  end

  // --------------------------------------------------------------------------
  // Stage2: Booth encoding and partial product generation (signal-based)
  // --------------------------------------------------------------------------
  // Temporaries
  logic [16:0]      rp_stage2;
  logic [2:0]       tri_stage2;
  logic [XLEN-1:0]  pa_stage2;

  logic [XLEN-1:0] s2_partial0, s2_partial0_next;
  logic [XLEN-1:0] s2_partial1, s2_partial1_next;
  logic [XLEN-1:0] s2_partial2, s2_partial2_next;
  logic [XLEN-1:0] s2_partial3, s2_partial3_next;
  logic [XLEN-1:0] s2_partial4, s2_partial4_next;
  logic [XLEN-1:0] s2_partial5, s2_partial5_next;
  logic [XLEN-1:0] s2_partial6, s2_partial6_next;
  logic [XLEN-1:0] s2_partial7, s2_partial7_next;
  logic [XLEN-1:0] s2_acc_old,  s2_acc_old_next;
  logic [XLEN-1:0] s2_instr_tag,s2_instr_tag_next;
  logic [31:0]     s2_instr,    s2_instr_next;
  idu1_out_t       s2_ctrl,     s2_ctrl_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s2_partial0   <= '0;
      s2_partial1   <= '0;
      s2_partial2   <= '0;
      s2_partial3   <= '0;
      s2_partial4   <= '0;
      s2_partial5   <= '0;
      s2_partial6   <= '0;
      s2_partial7   <= '0;
      s2_acc_old    <= '0;
      s2_instr_tag  <= '0;
      s2_instr      <= '0;
      s2_ctrl       <= '0;
    end else if (!freeze) begin
      s2_partial0   <= s2_partial0_next;
      s2_partial1   <= s2_partial1_next;
      s2_partial2   <= s2_partial2_next;
      s2_partial3   <= s2_partial3_next;
      s2_partial4   <= s2_partial4_next;
      s2_partial5   <= s2_partial5_next;
      s2_partial6   <= s2_partial6_next;
      s2_partial7   <= s2_partial7_next;
      s2_acc_old    <= s2_acc_old_next;
      s2_instr_tag  <= s2_instr_tag_next;
      s2_instr      <= s2_instr_next;
      s2_ctrl       <= s2_ctrl_next;
    end
  end

  always_comb begin
    s2_ctrl_next       = s1_ctrl;
    s2_acc_old_next    = s1_acc_old;
    s2_instr_tag_next  = s1_instr_tag;
    s2_instr_next      = s1_instr;
    for (int i = 0; i < 8; i++) begin
      tri_stage2 = { s1_rs2_data[2*i+1], s1_rs2_data[2*i], (i==0 ? 1'b0 : s1_rs2_data[2*i-1]) };
      case (tri_stage2)
        3'b000,3'b111: rp_stage2 = 17'd0;
        3'b001,3'b010: rp_stage2 = {s1_rs1_data[15], s1_rs1_data[15:0]};
        3'b011:        rp_stage2 = {s1_rs1_data[15], s1_rs1_data[15:0]} << 1;
        3'b100:        rp_stage2 = (~({s1_rs1_data[15], s1_rs1_data[15:0]} << 1)) + 1;
        3'b101,3'b110: rp_stage2 = (~({s1_rs1_data[15], s1_rs1_data[15:0]})) + 1;
        default:       rp_stage2 = 17'd0;
      endcase
      pa_stage2 = {{(XLEN-17){rp_stage2[16]}}, rp_stage2} << (2*i);
      unique case (i)
        0: s2_partial0_next = pa_stage2;
        1: s2_partial1_next = pa_stage2;
        2: s2_partial2_next = pa_stage2;
        3: s2_partial3_next = pa_stage2;
        4: s2_partial4_next = pa_stage2;
        5: s2_partial5_next = pa_stage2;
        6: s2_partial6_next = pa_stage2;
        7: s2_partial7_next = pa_stage2;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // Stage3: Product reduction and sum (signal-based)
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s3_prod,      s3_prod_next;
  logic [XLEN-1:0] s3_acc_old,   s3_acc_old_next;
  logic [XLEN-1:0] s3_instr_tag, s3_instr_tag_next;
  logic [31:0]     s3_instr,     s3_instr_next;
  idu1_out_t       s3_ctrl,      s3_ctrl_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s3_prod      <= '0;
      s3_acc_old   <= '0;
      s3_instr_tag <= '0;
      s3_instr     <= '0;
      s3_ctrl      <= '0;
    end else if (!freeze) begin
      s3_prod      <= s3_prod_next;
      s3_acc_old   <= s3_acc_old_next;
      s3_instr_tag <= s3_instr_tag_next;
      s3_instr     <= s3_instr_next;
      s3_ctrl      <= s3_ctrl_next;
    end
  end

  always_comb begin
    s3_ctrl_next      = s2_ctrl;
    s3_acc_old_next   = s2_acc_old;
    s3_instr_tag_next = s2_instr_tag;
    s3_instr_next     = s2_instr;
    // sum of partials
    s3_prod_next = s2_partial0 + s2_partial1 + s2_partial2 + s2_partial3
                 + s2_partial4 + s2_partial5 + s2_partial6 + s2_partial7;
  end

  // --------------------------------------------------------------------------
  // Stage4: Final accumulate and write-back (signal-based)
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s4_out,       s4_out_next;
  logic [XLEN-1:0] s4_instr_tag, s4_instr_tag_next;
  logic [31:0]     s4_instr,     s4_instr_next;
  idu1_out_t       s4_ctrl,      s4_ctrl_next;
  logic [XLEN-1:0] sum_acc;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s4_out       <= '0;
      s4_instr_tag <= '0;
      s4_instr     <= '0;
      s4_ctrl      <= '0;
    end else if (!freeze) begin
      s4_out       <= s4_out_next;
      s4_instr_tag <= s4_instr_tag_next;
      s4_instr     <= s4_instr_next;
      s4_ctrl      <= s4_ctrl_next;
    end
  end

  assign sum_acc = s3_prod + s3_acc_old;

  always_comb begin
    s4_ctrl_next      = s3_ctrl;
    s4_out_next       = sum_acc;
    s4_instr_tag_next = s3_instr_tag;
    s4_instr_next     = s3_instr;
  end

  // output assignments
  assign out           = s4_out;
  assign out_rd_addr   = s4_ctrl.rd_addr;
  assign out_rd_wr_en  = s4_ctrl.mac & s4_ctrl.legal & ~s4_ctrl.nop;
  assign instr_tag_out = s4_instr_tag;
  assign instr_out     = s4_instr;
  assign mac_busy      = |{s1_ctrl.mac, s2_ctrl.mac, s3_ctrl.mac, s4_ctrl.mac};

endmodule
