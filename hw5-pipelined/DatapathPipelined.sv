`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`ifndef DIVIDER_STAGES
`define DIVIDER_STAGES 8
`endif

`ifndef SYNTHESIS
`include "../hw3-singlecycle/RvDisassembler.sv"
`endif
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "../hw4-multicycle/DividerUnsignedPipelined.sv"
`include "../hw3-singlecycle/cycle_status.sv"

`define NOP_INSN 32'h00000013 

module Disasm #(
    byte PREFIX = "D"
) (
    input wire [31:0] insn,
    output wire [(8*32)-1:0] disasm
);
`ifndef SYNTHESIS
  // this code is only for simulation, not synthesis
  string disasm_string;
  always_comb begin
    disasm_string = rv_disasm(insn);
  end
  // HACK: get disasm_string to appear in GtkWave, which can apparently show only wire/logic. Also,
  // string needs to be reversed to render correctly.
  genvar i;
  for (i = 3; i < 32; i = i + 1) begin : gen_disasm
    assign disasm[((i+1-3)*8)-1-:8] = disasm_string[31-i];
  end
  assign disasm[255-:8] = PREFIX;
  assign disasm[247-:8] = ":";
  assign disasm[239-:8] = " ";
`endif
endmodule

module RegFile (
    input logic [4:0] rd,
    input logic [`REG_SIZE] rd_data,
    input logic [4:0] rs1,
    output logic [`REG_SIZE] rs1_data,
    input logic [4:0] rs2,
    output logic [`REG_SIZE] rs2_data,

    input logic clk,
    input logic we,
    input logic rst
);
  localparam int NumRegs = 32;
  logic [`REG_SIZE] regs[NumRegs];

  assign regs[0]  = 32'd0;  // x0 is always zero

  // WD Bypass
  assign rs1_data = (we && (rd == rs1) && (rs1 != 5'd0)) ? rd_data : regs[rs1];  // 1st read port
  assign rs2_data = (we && (rd == rs2) && (rs2 != 5'd0)) ? rd_data : regs[rs2];  // 2nd read port

  genvar i;
  for (i = 1; i < 32; i = i + 1) begin
    always_ff @(posedge clk) begin
      if (rst) begin
        regs[i] <= 32'd0;
      end else begin
        if (we && rd == i) begin
          regs[i] <= rd_data;
        end
      end
    end
  end


endmodule

/** state at the start of Decode stage */
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
} stage_decode_t;

/** state at the start of Execute stage */
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic [`REG_SIZE] rs1_data;
  logic [`REG_SIZE] rs2_data;
} stage_execute_t;

/** state at the start of Memory stage */
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic [`REG_SIZE] alu_result;
  logic [`REG_SIZE] rs2_data;
} stage_memory_t;

/** state at the start of Writeback stage */
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic [`REG_SIZE] alu_result;
  logic [`REG_SIZE] load_data;
} stage_writeback_t;

module DatapathPipelined (
    input wire clk,
    input wire rst,
    output logic [`REG_SIZE] pc_to_imem,
    input wire [`INSN_SIZE] insn_from_imem,
    // dmem is read/write
    output logic [`REG_SIZE] addr_to_dmem,
    input wire [`REG_SIZE] load_data_from_dmem,
    output logic [`REG_SIZE] store_data_to_dmem,
    output logic [3:0] store_we_to_dmem,

    output logic halt,

    // The PC of the insn currently in Writeback. 0 if not a valid insn.
    output logic [`REG_SIZE] trace_completed_pc,
    // The bits of the insn currently in Writeback. 0 if not a valid insn.
    output logic [`INSN_SIZE] trace_completed_insn,
    // The status of the insn (or stall) currently in Writeback. See the cycle_status.sv file for valid values.
    output cycle_status_e trace_completed_cycle_status
);

  // opcodes - see section 19 of RiscV spec
  localparam bit [`OPCODE_SIZE] OpLoad = 7'b00_000_11;
  localparam bit [`OPCODE_SIZE] OpStore = 7'b01_000_11;
  localparam bit [`OPCODE_SIZE] OpBranch = 7'b11_000_11;
  localparam bit [`OPCODE_SIZE] OpJalr = 7'b11_001_11;
  localparam bit [`OPCODE_SIZE] OpMiscMem = 7'b00_011_11;
  localparam bit [`OPCODE_SIZE] OpJal = 7'b11_011_11;

  localparam bit [`OPCODE_SIZE] OpRegImm = 7'b00_100_11;
  localparam bit [`OPCODE_SIZE] OpRegReg = 7'b01_100_11;
  localparam bit [`OPCODE_SIZE] OpEnviron = 7'b11_100_11;

  localparam bit [`OPCODE_SIZE] OpAuipc = 7'b00_101_11;
  localparam bit [`OPCODE_SIZE] OpLui = 7'b01_101_11;

  // cycle counter, not really part of any stage but useful for orienting within GtkWave
  // do not rename this as the testbench uses this value
  logic [`REG_SIZE] cycles_current;
  always_ff @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
    end
  end

  /***************/
  /* FETCH STAGE */
  /***************/

  logic [`REG_SIZE] f_pc_current;
  wire [`REG_SIZE] f_insn;
  cycle_status_e f_cycle_status;

  // program counter
  always_ff @(posedge clk) begin
    if (rst) begin
      f_pc_current   <= 32'd0;
      // NB: use CYCLE_NO_STALL since this is the value that will persist after the last reset cycle
      f_cycle_status <= CYCLE_NO_STALL;
    end else begin
      f_cycle_status <= CYCLE_NO_STALL;
      if (branch_successful) begin
        f_pc_current <= x_branch_target;
      end else if (!load_use_stall) begin
        f_pc_current <= f_pc_current + 4;
      end
    end
  end
  // send PC to imem
  assign pc_to_imem = f_pc_current;
  assign f_insn = insn_from_imem;

  // Here's how to disassemble an insn into a string you can view in GtkWave.
  // Use PREFIX to provide a 1-character tag to identify which stage the insn comes from.
  wire [255:0] f_disasm;
  Disasm #(
      .PREFIX("F")
  ) disasm_0fetch (
      .insn  (f_insn),
      .disasm(f_disasm)
  );

  /****************/
  /* DECODE STAGE */
  /****************/

  // this shows how to package up state in a `struct packed`, and how to pass it between stages
  stage_decode_t decode_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      decode_state <= '{pc: 0, insn: 0, cycle_status: CYCLE_RESET};
    end else if (branch_successful) begin
      decode_state <= '{pc: 0, insn: `NOP_INSN, cycle_status: CYCLE_TAKEN_BRANCH};
    end else if (!load_use_stall) begin
      decode_state <= '{pc: f_pc_current, insn: f_insn, cycle_status: f_cycle_status};
    end
  end
  wire [255:0] d_disasm;
  Disasm #(
      .PREFIX("D")
  ) disasm_1decode (
      .insn  (decode_state.insn),
      .disasm(d_disasm)
  );

  // Load-Use Stall
  wire load_use_stall = (execute_state.insn[6:0] == OpLoad && execute_state.insn[11:7] != 5'b0) && (
    (decode_state.insn[19:15] == execute_state.insn[11:7]) || 
    ( (decode_state.insn[24:20] == execute_state.insn[11:7]) && (decode_state.insn[6:0] != OpStore) ) );

  // Register File //
  wire we;
  wire [4:0] insn_rd = writeback_state.insn[11:7];
  wire [4:0] insn_rs1 = decode_state.insn[19:15];
  wire [4:0] insn_rs2 = decode_state.insn[24:20];
  wire [`REG_SIZE] rd_data;  // combinational logic set in writeback stage
  wire [`REG_SIZE] rs1_data;
  wire [`REG_SIZE] rs2_data;  // these two are used to create the execute state
  RegFile rf (
      .clk(clk),
      .rst(rst),
      .we(we),
      .rd(insn_rd),
      .rd_data(rd_data),
      .rs1(insn_rs1),
      .rs2(insn_rs2),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data)
  );

  /*****************/
  /* EXECUTE STAGE */
  /*****************/

  // this shows how to package up state in a `struct packed`, and how to pass it between stages
  stage_execute_t execute_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      execute_state <= '{pc: 0, insn: 0, cycle_status: CYCLE_RESET, rs1_data: 0, rs2_data: 0};
    end else if (branch_successful || load_use_stall) begin
      execute_state <= '{
          pc: 0,
          insn: `NOP_INSN,
          cycle_status: branch_successful ? CYCLE_TAKEN_BRANCH : CYCLE_LOAD2USE,
          rs1_data: 0,
          rs2_data: 0
      };
    end else begin
      execute_state <= '{
          pc: decode_state.pc,
          insn: decode_state.insn,
          cycle_status: decode_state.cycle_status,
          rs1_data: rs1_data,
          rs2_data: rs2_data
      };
    end
  end
  wire [255:0] x_disasm;
  Disasm #(
      .PREFIX("X")
  ) disasm_2execute (
      .insn  (execute_state.insn),
      .disasm(x_disasm)
  );

  // components of the instruction
  wire [6:0] x_insn_funct7;
  wire [2:0] x_insn_funct3;
  wire [`OPCODE_SIZE] x_insn_opcode;

  // split R-type instruction - see section 2.2 of RiscV spec
  assign x_insn_funct7 = execute_state.insn[31:25];
  assign x_insn_funct3 = execute_state.insn[14:12];
  assign x_insn_opcode = execute_state.insn[6:0];

  // setup for I, S, B & J type instructions
  // I - short immediates and loads
  wire [11:0] x_imm_i;
  assign x_imm_i = execute_state.insn[31:20];
  wire [ 4:0] x_imm_shamt = execute_state.insn[24:20];

  // S - stores
  wire [11:0] x_imm_s;
  assign x_imm_s[11:5] = x_insn_funct7,
      x_imm_s[4:0] = execute_state.insn[11:7];  // not needed in execute stage

  // B - conditionals
  wire [12:0] x_imm_b;
  assign {x_imm_b[12], x_imm_b[10:5]} = x_insn_funct7,
      {x_imm_b[4:1], x_imm_b[11]} = execute_state.insn[11:7],
      x_imm_b[0] = 1'b0;

  // J - unconditional jumps
  wire [20:0] x_imm_j;
  assign {x_imm_j[20], x_imm_j[10:1], x_imm_j[11], x_imm_j[19:12], x_imm_j[0]} = {
    execute_state.insn[31:12], 1'b0
  };

  wire [`REG_SIZE] x_imm_i_sext = {{20{x_imm_i[11]}}, x_imm_i[11:0]};
  wire [`REG_SIZE] x_imm_s_sext = {{20{x_imm_s[11]}}, x_imm_s[11:0]};
  wire [`REG_SIZE] x_imm_b_sext = {{19{x_imm_b[12]}}, x_imm_b[12:0]};
  wire [`REG_SIZE] x_imm_j_sext = {{11{x_imm_j[20]}}, x_imm_j[20:0]};

  wire insn_lui = x_insn_opcode == OpLui;
  wire insn_auipc = x_insn_opcode == OpAuipc;
  wire insn_jal = x_insn_opcode == OpJal;
  wire insn_jalr = x_insn_opcode == OpJalr;

  wire insn_beq = x_insn_opcode == OpBranch && execute_state.insn[14:12] == 3'b000;
  wire insn_bne = x_insn_opcode == OpBranch && execute_state.insn[14:12] == 3'b001;
  wire insn_blt = x_insn_opcode == OpBranch && execute_state.insn[14:12] == 3'b100;
  wire insn_bge = x_insn_opcode == OpBranch && execute_state.insn[14:12] == 3'b101;
  wire insn_bltu = x_insn_opcode == OpBranch && execute_state.insn[14:12] == 3'b110;
  wire insn_bgeu = x_insn_opcode == OpBranch && execute_state.insn[14:12] == 3'b111;

  wire insn_addi = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b000;
  wire insn_slti = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b010;
  wire insn_sltiu = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b011;
  wire insn_xori = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b100;
  wire insn_ori = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b110;
  wire insn_andi = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b111;

  wire insn_slli = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b001 && execute_state.insn[31:25] == 7'd0;
  wire insn_srli = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'd0;
  wire insn_srai = x_insn_opcode == OpRegImm && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'b0100000;

  wire insn_add  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b000 && execute_state.insn[31:25] == 7'd0;
  wire insn_sub  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b000 && execute_state.insn[31:25] == 7'b0100000;
  wire insn_sll  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b001 && execute_state.insn[31:25] == 7'd0;
  wire insn_slt  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b010 && execute_state.insn[31:25] == 7'd0;
  wire insn_sltu = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b011 && execute_state.insn[31:25] == 7'd0;
  wire insn_xor  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b100 && execute_state.insn[31:25] == 7'd0;
  wire insn_srl  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'd0;
  wire insn_sra  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b101 && execute_state.insn[31:25] == 7'b0100000;
  wire insn_or   = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b110 && execute_state.insn[31:25] == 7'd0;
  wire insn_and  = x_insn_opcode == OpRegReg && execute_state.insn[14:12] == 3'b111 && execute_state.insn[31:25] == 7'd0;

  wire insn_mul    = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b000;
  wire insn_mulh   = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b001;
  wire insn_mulhsu = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b010;
  wire insn_mulhu  = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b011;
  wire insn_div    = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b100;
  wire insn_divu   = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b101;
  wire insn_rem    = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b110;
  wire insn_remu   = x_insn_opcode == OpRegReg && execute_state.insn[31:25] == 7'd1 && execute_state.insn[14:12] == 3'b111;
  wire is_div_cycle = (insn_div || insn_divu || insn_rem || insn_remu);

  wire insn_ecall = x_insn_opcode == OpEnviron && execute_state.insn[31:7] == 25'd0; // not sure who's job this is
  wire insn_fence = x_insn_opcode == OpMiscMem;


  // ALU arithmetic
  wire [`REG_SIZE] a;
  wire [`REG_SIZE] b;
  wire carry_in;
  wire [`REG_SIZE] sum;
  CarryLookaheadAdder cla (
      .a  (a),
      .b  (b),
      .cin(carry_in),
      .sum(sum)
  );

  wire [`REG_SIZE] x_rs1_negated;
  CarryLookaheadAdder negator_rs1 (
      .a  (~x_rs1_data),   // Invert bits
      .b  (32'b0),         // Add 0
      .cin(1'b1),          // Add 1 (via carry-in)
      .sum(x_rs1_negated)  // Result is -rs1
  );

  wire [`REG_SIZE] x_rs2_negated;
  CarryLookaheadAdder negator_rs2 (
      .a  (~x_rs2_data),   // Invert bits
      .b  (32'b0),         // Add 0
      .cin(1'b1),          // Add 1 (via carry-in)
      .sum(x_rs2_negated)  // Result is -rs1
  );

  wire [`REG_SIZE] quotient_negated;
  CarryLookaheadAdder negator_quotient (
      .a  (~o_quotient),      // Invert bits
      .b  (32'b0),            // Add 0
      .cin(1'b1),             // Add 1 (via carry-in)
      .sum(quotient_negated)  // Result is -rs1
  );

  wire [`REG_SIZE] remainder_negated;
  CarryLookaheadAdder negator_remainder (
      .a  (~o_remainder),      // Invert bits
      .b  (32'b0),             // Add 0
      .cin(1'b1),              // Add 1 (via carry-in)
      .sum(remainder_negated)  // Result is -rs1
  );

  wire [31:0] i_dividend;
  wire [31:0] i_divisor;
  wire [31:0] o_remainder;
  wire [31:0] o_quotient;
  DividerUnsignedPipelined divider (
      .clk(clk),
      .rst(rst),
      .stall(1'b0),
      .i_dividend(i_dividend),
      .i_divisor(i_divisor),
      .o_remainder(o_remainder),
      .o_quotient(o_quotient)
  );

  logic illegal_insn; // idk what this even does besides debugging, so i'm only going to parse in execute
  logic [`REG_SIZE] alu_result_logic;
  logic [`REG_SIZE] a_logic;
  logic [`REG_SIZE] b_logic;
  logic carry_in_logic;
  logic [63:0] multiplication_result;  // deal with these later
  logic [31:0] i_dividend_logic;  // these are fixed at 31:0 cuz our divider only works for 32 lol
  logic [31:0] i_divisor_logic;
  logic branch_successful;
  logic [`REG_SIZE] x_branch_target;

  assign a = a_logic;
  assign b = b_logic;
  assign carry_in = carry_in_logic;
  assign i_dividend = i_dividend_logic;
  assign i_divisor = i_divisor_logic;

  // Added bypass logic: 
  wire [6:0] m_opcode_bypass = memory_state.insn[6:0];
  wire M_bypass = (memory_state.insn[11:7] != 5'b0) && 
                   (m_opcode_bypass == OpLui || m_opcode_bypass == OpAuipc || 
                    m_opcode_bypass == OpJal || m_opcode_bypass == OpJalr || 
                    m_opcode_bypass == OpRegReg || m_opcode_bypass == OpRegImm || 
                    m_opcode_bypass == OpLoad); // check if it's a use instruction

  wire [6:0] w_opcode_bypass = writeback_state.insn[6:0];
  wire W_bypass = (writeback_state.insn[11:7] != 5'b0) && 
                   (w_opcode_bypass == OpLui || w_opcode_bypass == OpAuipc || 
                    w_opcode_bypass == OpJal || w_opcode_bypass == OpJalr || 
                    w_opcode_bypass == OpRegReg || w_opcode_bypass == OpRegImm || 
                    w_opcode_bypass == OpLoad); // check if it's a use instruction
  wire [`REG_SIZE] w_bypassed_data = (w_opcode_bypass == OpLoad) ? writeback_state.load_data : writeback_state.alu_result;

  wire [4:0] x_rs1 = execute_state.insn[19:15];
  wire [4:0] x_rs2 = execute_state.insn[24:20];

  logic [`REG_SIZE] x_rs1_data;
  logic [`REG_SIZE] x_rs2_data;

  always_comb begin
    x_rs1_data = execute_state.rs1_data;
    x_rs2_data = execute_state.rs2_data;

    // MX Bypass takes priority over WX Bypass
    if (M_bypass && memory_state.insn[11:7] == x_rs1) begin
      x_rs1_data = memory_state.alu_result;
    end else if (W_bypass && writeback_state.insn[11:7] == x_rs1) begin
      x_rs1_data = w_bypassed_data;
    end

    if (M_bypass && memory_state.insn[11:7] == x_rs2) begin
      x_rs2_data = memory_state.alu_result;
    end else if (W_bypass && writeback_state.insn[11:7] == x_rs2) begin
      x_rs2_data = w_bypassed_data;
    end
  end

  always_comb begin
    illegal_insn = 1'b0;

    alu_result_logic = 32'b0;
    a_logic = 32'b0;
    b_logic = 32'b0;
    carry_in_logic = 1'b0;

    branch_successful = 0;
    x_branch_target = 32'b0;

    multiplication_result = 64'b0;
    i_dividend_logic = 32'b0;
    i_divisor_logic = 32'b0;

    case (x_insn_opcode)
      OpLui: begin
        alu_result_logic = {execute_state.insn[31:12], 12'b0};
      end
      OpAuipc: begin
        alu_result_logic = execute_state.pc + {execute_state.insn[31:12], 12'b0};
      end
      OpJal: begin
        alu_result_logic  = execute_state.pc + 4;
        branch_successful = 1'b1;
        x_branch_target   = execute_state.pc + x_imm_j_sext;
      end
      OpJalr: begin
        alu_result_logic  = execute_state.pc + 4;
        branch_successful = 1'b1;
        x_branch_target   = (x_rs1_data + x_imm_i_sext) & ~32'b1;
      end
      OpBranch: begin
        x_branch_target = execute_state.pc + x_imm_b_sext;
        if (insn_beq) begin
          if (x_rs1_data == x_rs2_data) begin
            branch_successful = 1'b1;
          end
        end else if (insn_bne) begin
          if (x_rs1_data != x_rs2_data) begin
            branch_successful = 1'b1;
          end
        end else if (insn_blt) begin
          if ($signed(x_rs1_data) < $signed(x_rs2_data)) begin
            branch_successful = 1'b1;
          end
        end else if (insn_bge) begin
          if ($signed(x_rs1_data) >= $signed(x_rs2_data)) begin
            branch_successful = 1'b1;
          end
        end else if (insn_bltu) begin
          if (x_rs1_data < x_rs2_data) begin
            branch_successful = 1'b1;
          end
        end else if (insn_bgeu) begin
          if (x_rs1_data >= x_rs2_data) begin
            branch_successful = 1'b1;
          end
        end else begin
          illegal_insn = 1'b1;
        end
      end
      OpLoad: begin
        alu_result_logic = (x_rs1_data + x_imm_i_sext);
      end
      OpStore: begin
        alu_result_logic = (x_rs1_data + x_imm_s_sext);
      end
      OpRegImm: begin
        if (insn_addi) begin
          a_logic = x_rs1_data;
          b_logic = x_imm_i_sext;

          alu_result_logic = sum;
        end else if (insn_slti) begin
          alu_result_logic = $signed(x_rs1_data) < $signed(x_imm_i_sext) ? 1 : 0;
        end else if (insn_sltiu) begin
          alu_result_logic = x_rs1_data < x_imm_i_sext ? 1 : 0;
        end else if (insn_xori) begin
          alu_result_logic = x_rs1_data ^ x_imm_i_sext;
        end else if (insn_ori) begin
          alu_result_logic = x_rs1_data | x_imm_i_sext;
        end else if (insn_andi) begin
          alu_result_logic = x_rs1_data & x_imm_i_sext;
        end else if (insn_slli) begin
          alu_result_logic = x_rs1_data << x_imm_i_sext[4:0];
        end else if (insn_srli) begin
          alu_result_logic = x_rs1_data >> x_imm_i_sext[4:0];
        end else if (insn_srai) begin
          alu_result_logic = $signed(x_rs1_data) >>> x_imm_i_sext[4:0];
        end else begin
          illegal_insn = 1'b1;
        end
      end
      OpRegReg: begin
        if (insn_add) begin
          a_logic = x_rs1_data;
          b_logic = x_rs2_data;

          alu_result_logic = sum;
        end else if (insn_sub) begin
          a_logic = x_rs1_data;
          b_logic = ~x_rs2_data;
          carry_in_logic = 1'b1;

          alu_result_logic = sum;
        end else if (insn_sll) begin
          alu_result_logic = x_rs1_data << x_rs2_data[4:0];
        end else if (insn_slt) begin
          alu_result_logic = $signed(x_rs1_data) < $signed(x_rs2_data) ? 1 : 0;
        end else if (insn_sltu) begin
          alu_result_logic = x_rs1_data < x_rs2_data ? 1 : 0;
        end else if (insn_xor) begin
          alu_result_logic = x_rs1_data ^ x_rs2_data;
        end else if (insn_srl) begin
          alu_result_logic = x_rs1_data >> x_rs2_data[4:0];
        end else if (insn_sra) begin
          alu_result_logic = $signed(x_rs1_data) >>> x_rs2_data[4:0];
        end else if (insn_or) begin
          alu_result_logic = x_rs1_data | x_rs2_data;
        end else if (insn_and) begin
          alu_result_logic = x_rs1_data & x_rs2_data;
          // end else if (insn_mul) begin
          //   multiplication_result = rs1_data * rs2_data;
          //   alu_result_logic = multiplication_result[31:0];
          // end else if (insn_mulh) begin
          //   multiplication_result = $signed(rs1_data) * $signed(rs2_data);
          //   alu_result_logic = multiplication_result[63:32];
          // end else if (insn_mulhsu) begin
          //   multiplication_result = $signed(rs1_data) * $signed({1'b0, rs2_data});
          //   alu_result_logic = multiplication_result[63:32];
          // end else if (insn_mulhu) begin
          //   multiplication_result = rs1_data * rs2_data;
          //   alu_result_logic = multiplication_result[63:32];
          // end else if (insn_div) begin
          //   if (div_cycles_current == 0) begin
          //     i_dividend_logic = rs1_data[31] ? rs1_negated : rs1_data;
          //     i_divisor_logic = rs2_data[31] ? rs2_negated : rs2_data;
          //     we_logic = 1'b0;
          //   end if (div_cycles_current + 1 == `N_DIVIDER_STAGES) begin
          //     rd_data_logic = (rs1_data[31] ^ rs2_data[31]) ? quotient_negated : o_quotient;
          //     rd_data_logic = (rs2_data == 32'b0) ? ~32'b0 : rd_data_logic;
          //   end else begin
          //     we_logic = 1'b0;
          //   end
          // end else if (insn_divu) begin
          //   if (div_cycles_current == 0) begin
          //     i_dividend_logic = rs1_data;
          //     i_divisor_logic = rs2_data;
          //     we_logic = 1'b0;
          //   end if (div_cycles_current + 1 == `N_DIVIDER_STAGES) begin
          //     rd_data_logic = (rs2_data == 32'b0) ? ~32'b0 : o_quotient;
          //   end else begin
          //     we_logic = 1'b0;
          //   end
          // end else if (insn_rem) begin
          //   if (div_cycles_current == 0) begin
          //     i_dividend_logic = rs1_data[31] ? rs1_negated : rs1_data;
          //     i_divisor_logic = rs2_data[31] ? rs2_negated : rs2_data;
          //     we_logic = 1'b0;
          //   end if (div_cycles_current + 1 == `N_DIVIDER_STAGES) begin
          //     rd_data_logic = rs1_data[31] ? remainder_negated : o_remainder;
          //     rd_data_logic = (rs2_data == 32'b0) ? rs1_data : rd_data_logic;
          //   end else begin
          //     we_logic = 1'b0;
          //   end
          // end else if (insn_remu) begin
          //   if (div_cycles_current == 0) begin
          //     i_dividend_logic = rs1_data;
          //     i_divisor_logic = rs2_data;
          //     we_logic = 1'b0;
          //   end if (div_cycles_current + 1 == `N_DIVIDER_STAGES) begin
          //     rd_data_logic = (rs2_data == 32'b0) ? rs1_data : o_remainder;
          //   end else begin
          //     we_logic = 1'b0;
          //   end
        end
      end
      // OpMiscMem: begin

      // end
      default: begin
        illegal_insn = 1'b1;
      end
    endcase
  end

  /****************/
  /* MEMORY STAGE */
  /****************/

  // this shows how to package up state in a `struct packed`, and how to pass it between stages
  stage_memory_t memory_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      memory_state <= '{pc: 0, insn: 0, cycle_status: CYCLE_RESET, alu_result: 0, rs2_data: 0};
    end else begin
      memory_state <= '{
          pc: execute_state.pc,
          insn: execute_state.insn,
          cycle_status: execute_state.cycle_status,
          alu_result: alu_result_logic,
          rs2_data: x_rs2_data
      };
    end
  end
  wire [255:0] m_disasm;
  Disasm #(
      .PREFIX("M")
  ) disasm_3memory (
      .insn  (memory_state.insn),
      .disasm(m_disasm)
  );

  wire [`OPCODE_SIZE] m_insn_opcode = memory_state.insn[6:0];
  logic [`REG_SIZE] offset;
  logic [`REG_SIZE] m_load_data;

  wire insn_lb = m_insn_opcode == OpLoad && memory_state.insn[14:12] == 3'b000;
  wire insn_lh = m_insn_opcode == OpLoad && memory_state.insn[14:12] == 3'b001;
  wire insn_lw = m_insn_opcode == OpLoad && memory_state.insn[14:12] == 3'b010;
  wire insn_lbu = m_insn_opcode == OpLoad && memory_state.insn[14:12] == 3'b100;
  wire insn_lhu = m_insn_opcode == OpLoad && memory_state.insn[14:12] == 3'b101;

  wire insn_sb = m_insn_opcode == OpStore && memory_state.insn[14:12] == 3'b000;
  wire insn_sh = m_insn_opcode == OpStore && memory_state.insn[14:12] == 3'b001;
  wire insn_sw = m_insn_opcode == OpStore && memory_state.insn[14:12] == 3'b010;

  // WM Bypassing 
  wire [4:0] m_rs2 = memory_state.insn[24:20];
  logic [`REG_SIZE] m_store_data;

  always_comb begin
    m_store_data = memory_state.rs2_data;
    if (W_bypass && writeback_state.insn[11:7] == m_rs2) begin
      m_store_data = w_bypassed_data;
    end
  end

  always_comb begin
    addr_to_dmem = 32'b0;
    store_data_to_dmem = 32'b0;
    store_we_to_dmem = 4'b0;

    offset = 32'b0;
    m_load_data = 32'b0;

    case (m_insn_opcode)
      OpLoad: begin
        addr_to_dmem = memory_state.alu_result & ~32'b11;
        offset = memory_state.alu_result & 32'b11;
        if (insn_lb) begin
          m_load_data = {{24{load_data_from_dmem[(offset*8)+7]}}, load_data_from_dmem[offset*8+:8]};
        end else if (insn_lh) begin
          m_load_data = {
            {16{load_data_from_dmem[(offset[1]*16)+15]}}, load_data_from_dmem[offset[1]*16+:16]
          };
        end else if (insn_lw) begin
          m_load_data = load_data_from_dmem[31:0];
        end else if (insn_lbu) begin
          m_load_data = {24'b0, load_data_from_dmem[offset*8+:8]};
        end else if (insn_lhu) begin
          m_load_data = {16'b0, load_data_from_dmem[offset[1]*16+:16]};
        end else begin
          // illegal_insn = 1'b1;
        end
      end
      OpStore: begin
        addr_to_dmem = memory_state.alu_result & ~32'b11;
        offset = memory_state.alu_result & 32'b11;
        if (insn_sb) begin
          store_data_to_dmem[offset*8+:8] = m_store_data[7:0];
          store_we_to_dmem = 4'b0001 << offset;
        end else if (insn_sh) begin
          store_data_to_dmem[offset[1]*16+:16] = m_store_data[15:0];
          store_we_to_dmem = 4'b0011 << offset;
        end else if (insn_sw) begin
          store_data_to_dmem = m_store_data;
          store_we_to_dmem   = 4'b1111;
        end else begin
          // illegal_insn = 1'b1;
        end
      end
      default: begin
        // ignore
      end
    endcase
  end

  /*******************/
  /* WRITEBACK STAGE */
  /*******************/

  // this shows how to package up state in a `struct packed`, and how to pass it between stages
  stage_writeback_t writeback_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      writeback_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          alu_result: 0,
          load_data: 0
      };
    end else begin
      writeback_state <= '{
          pc: memory_state.pc,
          insn: memory_state.insn,
          cycle_status: memory_state.cycle_status,
          alu_result: memory_state.alu_result,
          load_data: m_load_data
      };
    end
  end
  wire [255:0] w_disasm;
  Disasm #(
      .PREFIX("W")
  ) disasm_4writeback (
      .insn  (writeback_state.insn),
      .disasm(w_disasm)
  );

  wire [`OPCODE_SIZE] w_opcode = writeback_state.insn[6:0];
  wire [4:0] w_rd = writeback_state.insn[11:7];
  logic we_logic;
  logic [`REG_SIZE] rd_data_logic;

  always_comb begin
    we_logic = 1'b0;
    rd_data_logic = 32'b0;
    halt = 1'b0;

    // can we just let the rf handle writing to register x0
    case (w_opcode)
      OpLui, OpAuipc, OpJal, OpJalr, OpRegReg, OpRegImm: begin
        we_logic = 1'b1;
        rd_data_logic = writeback_state.alu_result;
      end
      OpLoad: begin
        we_logic = 1'b1;
        rd_data_logic = writeback_state.load_data;
      end
      OpEnviron: begin
        if (writeback_state.cycle_status == CYCLE_NO_STALL) begin
          halt = 1'b1;
        end
      end
      default: begin
        // ignore other instructions
      end
    endcase
  end

  assign we = we_logic;
  assign rd_data = rd_data_logic;

  assign trace_completed_pc = (writeback_state.cycle_status == CYCLE_NO_STALL) ? writeback_state.pc : 32'b0;
  assign trace_completed_insn = (writeback_state.cycle_status == CYCLE_NO_STALL) ? writeback_state.insn : 32'b0;
  assign trace_completed_cycle_status = writeback_state.cycle_status;

endmodule

module MemorySingleCycle #(
    parameter int NUM_WORDS = 512
) (
    // rst for both imem and dmem
    input wire rst,

    // clock for both imem and dmem. The memory reads/writes on @(negedge clk)
    input wire clk,

    // must always be aligned to a 4B boundary
    input wire [`REG_SIZE] pc_to_imem,

    // the value at memory location pc_to_imem
    output logic [`REG_SIZE] insn_from_imem,

    // must always be aligned to a 4B boundary
    input wire [`REG_SIZE] addr_to_dmem,

    // the value at memory location addr_to_dmem
    output logic [`REG_SIZE] load_data_from_dmem,

    // the value to be written to addr_to_dmem, controlled by store_we_to_dmem
    input wire [`REG_SIZE] store_data_to_dmem,

    // Each bit determines whether to write the corresponding byte of store_data_to_dmem to memory location addr_to_dmem.
    // E.g., 4'b1111 will write 4 bytes. 4'b0001 will write only the least-significant byte.
    input wire [3:0] store_we_to_dmem
);

  // memory is arranged as an array of 4B words
  logic [`REG_SIZE] mem_array[NUM_WORDS];

`ifdef SYNTHESIS
  initial begin
    $readmemh("mem_initial_contents.hex", mem_array);
  end
`endif

  always_comb begin
    // memory addresses should always be 4B-aligned
    assert (pc_to_imem[1:0] == 2'b00);
    assert (addr_to_dmem[1:0] == 2'b00);
  end

  localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam int AddrLsb = 2;

  always @(negedge clk) begin
    if (rst) begin
    end else begin
      insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
    end
  end

  always @(negedge clk) begin
    if (rst) begin
    end else begin
      if (store_we_to_dmem[0]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
      end
      if (store_we_to_dmem[1]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
      end
      if (store_we_to_dmem[2]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
      end
      if (store_we_to_dmem[3]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
      end
      // dmem is "read-first": read returns value before the write
      load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
    end
  end
endmodule

/* This design has just one clock for both processor and memory. */
module Processor (
    input wire clk,
    input wire rst,
    output logic halt,
    output wire [`REG_SIZE] trace_completed_pc,
    output wire [`INSN_SIZE] trace_completed_insn,
    output cycle_status_e trace_completed_cycle_status
);

  wire [`INSN_SIZE] insn_from_imem;
  wire [`REG_SIZE] pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
      .rst                (rst),
      .clk                (clk),
      // imem is read-only
      .pc_to_imem         (pc_to_imem),
      .insn_from_imem     (insn_from_imem),
      // dmem is read-write
      .addr_to_dmem       (mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem   (mem_data_we)
  );

  DatapathPipelined datapath (
      .clk(clk),
      .rst(rst),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .halt(halt),
      .trace_completed_pc(trace_completed_pc),
      .trace_completed_insn(trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status)
  );

endmodule
