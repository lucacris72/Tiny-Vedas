`ifndef GLOBAL_SVH
`include "global.svh"
`endif

`ifndef TYPES_SVH
`include "types.svh"
`endif

// Pipelined MAC unit with forwarding: Radix-4 Booth + Carry-Select Adder (16-bit)
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

  // Write-back updates the accumulator
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      acc_reg <= '0;
    else if (out_rd_wr_en && !freeze)
      acc_reg <= out;
  end

  // --------------------------------------------------------------------------
  // Stage1: Capture operands and control
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s1_rs1_data, s1_rs2_data;
  logic [XLEN-1:0] s1_instr_tag;
  logic [31:0]     s1_instr;
  idu1_out_t       s1_ctrl;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_rs1_data  <= '0;
      s1_rs2_data  <= '0;
      s1_instr_tag <= '0;
      s1_instr     <= '0;
      s1_ctrl      <= '0;
    end else if (!freeze) begin
      s1_rs1_data  <= mac_ctrl.rs1_data;
      s1_rs2_data  <= mac_ctrl.rs2_data;
      s1_instr_tag <= mac_ctrl.instr_tag;
      s1_instr     <= mac_ctrl.instr;
      s1_ctrl      <= mac_ctrl;
    end
  end

  // --------------------------------------------------------------------------
  // Stage2: Booth encoding & partial products
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s2_partial [7:0];
  idu1_out_t      s2_ctrl;
  logic [XLEN-1:0] s2_instr_tag;
  logic [31:0]    s2_instr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s2_partial   <= '{default:0};
      s2_ctrl      <= '0;
      s2_instr_tag <= '0;
      s2_instr     <= '0;
    end else if (!freeze) begin
      for (int i = 0; i < 8; i++) begin
        s2_partial[i] <= rp_to_pa(s1_rs1_data, s1_rs2_data, i);
      end
      s2_ctrl      <= s1_ctrl;
      s2_instr_tag <= s1_instr_tag;
      s2_instr     <= s1_instr;
    end
  end

  // --------------------------------------------------------------------------
  // Stage3: Sum partial products
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s3_sum;
  idu1_out_t      s3_ctrl;
  logic [XLEN-1:0] s3_instr_tag;
  logic [31:0]    s3_instr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s3_sum       <= '0;
      s3_ctrl      <= '0;
      s3_instr_tag <= '0;
      s3_instr     <= '0;
    end else if (!freeze) begin
      // Reduction of partial products
      logic [XLEN-1:0] tmp_sum;
      tmp_sum = '0;
      for (int i = 0; i < 8; i++)
        tmp_sum += s2_partial[i];
      s3_sum       <= tmp_sum;
      s3_ctrl      <= s2_ctrl;
      s3_instr_tag <= s2_instr_tag;
      s3_instr     <= s2_instr;
    end
  end

  // --------------------------------------------------------------------------
  // Stage4: Final accumulate (with forwarding) & write-back
  // --------------------------------------------------------------------------
  logic [XLEN-1:0] s4_out;
  idu1_out_t      s4_ctrl;
  logic [XLEN-1:0] s4_instr_tag;
  logic [31:0]    s4_instr;

  // Forward path: if stage4 holds a MAC, forward its result
  logic [XLEN-1:0] acc_src;
  always_comb begin
    if (s4_ctrl.macrst) begin
      acc_src = '0;
    end else if (s4_ctrl.mac && !freeze) begin
      acc_src = s4_out;
    end else begin
      acc_src = acc_reg;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s4_out       <= '0;
      s4_ctrl      <= '0;
      s4_instr_tag <= '0;
      s4_instr     <= '0;
    end else if (!freeze) begin
      s4_out       <= s3_sum + acc_src;
      s4_ctrl      <= s3_ctrl;
      s4_instr_tag <= s3_instr_tag;
      s4_instr     <= s3_instr;
    end
  end

  // --------------------------------------------------------------------------
  // Outputs
  // --------------------------------------------------------------------------
  assign out           = s4_out;
  assign out_rd_addr   = s4_ctrl.rd_addr;
  assign out_rd_wr_en  = s4_ctrl.mac & s4_ctrl.legal & ~s4_ctrl.nop;
  assign instr_tag_out = s4_instr_tag;
  assign instr_out     = s4_instr;
  assign mac_busy      = |{s1_ctrl.mac, s2_ctrl.mac, s3_ctrl.mac, s4_ctrl.mac};

  // --------------------------------------------------------------------------
  // Booth-to-partial helper function (SV-2005 compatible)
  // --------------------------------------------------------------------------
  function automatic logic [XLEN-1:0] rp_to_pa;
    input logic [XLEN-1:0] rs1;
    input logic [XLEN-1:0] rs2;
    input int idx;
    logic [16:0] rp;
    begin
      // Booth encoding (use bits [2*idx+1:2*idx-1])
      case ({ rs2[2*idx+1], rs2[2*idx], (idx == 0 ? 1'b0 : rs2[2*idx-1]) })
        3'b000, 3'b111: rp = 17'd0;
        3'b001, 3'b010: rp = {{1{rs1[15]}}, rs1[15:0]};
        3'b011:        rp = {{1{rs1[15]}}, rs1[15:0]} << 1;
        3'b100:        rp = (~({{1{rs1[15]}}, rs1[15:0]} << 1)) + 1;
        3'b101,3'b110: rp = (~({{1{rs1[15]}}, rs1[15:0]})) + 1;
        default:       rp = 17'd0;
      endcase
      // sign-extend and shift
      return ({{(XLEN-17){rp[16]}}, rp} << (2*idx));
    end
  endfunction

endmodule
