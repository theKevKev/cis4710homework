`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`define ADDR_WIDTH 32
`define DATA_WIDTH 32

`ifndef DIVIDER_STAGES
`define DIVIDER_STAGES 8
`endif

`ifndef SYNTHESIS
`include "../hw3-singlecycle/RvDisassembler.sv"
`endif
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "../hw3-singlecycle/cycle_status.sv"
`include "../hw4-multicycle/DividerUnsignedPipelined.sv"
`include "EasyAxilMemory.sv"

module Disasm #(
    PREFIX = "D"
) (
    input wire [31:0] insn,
    output wire [(8*32)-1:0] disasm
);
`ifndef RISCV_FORMAL
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
`endif
endmodule

// TODO: copy over your RegFile and pipeline structs from HW5
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

typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
  logic [`REG_SIZE] rs1_data;
  logic [`REG_SIZE] rs2_data;
} stage_divide_t;


module DatapathPipelinedAxil (
    input wire clk,
    input wire rst,

    // interface to insn memory/cache
    axil_if.manager imem,
    // interface to data memory/cache
    axil_if.manager dmem,

    output logic halt,

    // The PC of the insn currently in Writeback. 0 if not a valid insn.
    output logic [`REG_SIZE] trace_completed_pc,
    // The bits of the insn currently in Writeback. 0 if not a valid insn.
    output logic [`INSN_SIZE] trace_completed_insn,
    // The status of the insn (or stall) currently in Writeback. See the cycle_status.sv file for valid values.
    output cycle_status_e trace_completed_cycle_status
);

  localparam bit True = 1'b1;
  localparam bit False = 1'b0;

  // cycle counter
  logic [`REG_SIZE] cycles_current;
  always_ff @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
    end
  end

  // TODO: copy in your HW5B datapath as a starting point

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
      end else if (!load_use_stall && !div_stall) begin
        // end else if (!load_use_stall) begin
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
    end else if (!load_use_stall && !div_stall) begin
      // end else if (!load_use_stall) begin
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
  wire d_uses_rs1 = (d_insn_opcode != OpLui && d_insn_opcode != OpAuipc && d_insn_opcode != OpJal);
  wire d_uses_rs2 = (d_insn_opcode == OpStore || d_insn_opcode == OpBranch || d_insn_opcode == OpRegReg);

  wire load_use_stall = (execute_state.insn[6:0] == OpLoad && execute_state.insn[11:7] != 5'b0) && (
    (d_uses_rs1 && (decode_state.insn[19:15] == execute_state.insn[11:7])) || 
    (d_uses_rs2 && (decode_state.insn[24:20] == execute_state.insn[11:7]) && (decode_state.insn[6:0] != OpStore) ) 
  );

  // Divider Stall //
  wire div_stall = divide_stall_logic;

  wire [`OPCODE_SIZE] d_insn_opcode = decode_state.insn[6:0];
  wire d_insn_div    = d_insn_opcode == OpRegReg && decode_state.insn[31:25] == 7'd1 && decode_state.insn[14:12] == 3'b100;
  wire d_insn_divu   = d_insn_opcode == OpRegReg && decode_state.insn[31:25] == 7'd1 && decode_state.insn[14:12] == 3'b101;
  wire d_insn_rem    = d_insn_opcode == OpRegReg && decode_state.insn[31:25] == 7'd1 && decode_state.insn[14:12] == 3'b110;
  wire d_insn_remu   = d_insn_opcode == OpRegReg && decode_state.insn[31:25] == 7'd1 && decode_state.insn[14:12] == 3'b111;
  wire d_is_div_cycle = (d_insn_div || d_insn_divu || d_insn_rem || d_insn_remu);

  logic divide_stall_logic;
  logic divider_busy;
  logic div_dependent;

  always_comb begin
    divider_busy  = 1'b0;
    div_dependent = 1'b0;

    // Single loop to evaluate both divider status and dependencies
    for (int i = 0; i < 7; i++) begin
      if (divide_state[i].insn != `NOP_INSN) begin
        divider_busy = 1'b1;  // Mark that the divider has active work
        div_dependent = ((divide_state[i].insn[11:7] == decode_state.insn[19:15]) || (divide_state[i].insn[11:7] == decode_state.insn[24:20]));
      end
    end

    // Stall Logic Resolution
    if (d_is_div_cycle) begin
      // If I am a divide: check dependency
      divide_stall_logic = div_dependent;
    end else begin
      // If I am not a divide: stall if there's anything in the divider
      divide_stall_logic = divider_busy;
    end
  end

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
    end else if (branch_successful || load_use_stall || div_stall) begin
      // end else if (branch_successful || load_use_stall) begin
      execute_state <= '{
          pc: 0,
          insn: `NOP_INSN,
          cycle_status:
          branch_successful
          ?
          CYCLE_TAKEN_BRANCH
          : (
          load_use_stall ? CYCLE_LOAD2USE : CYCLE_DIV
          ),
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

  assign divide_state[0] = '{
          pc: is_div_cycle ? execute_state.pc : 0,
          insn: is_div_cycle ? execute_state.insn : `NOP_INSN,
          cycle_status: is_div_cycle ? execute_state.cycle_status : CYCLE_INVALID,
          rs1_data: is_div_cycle ? x_rs1_data : 0,
          rs2_data: is_div_cycle ? x_rs2_data : 0
      };  // keeps them the same struct effectively

  stage_divide_t divide_state[8];
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 1; i < `DIVIDER_STAGES; i++) begin
        divide_state[i] <= '{
            pc: 0,
            insn: 0,
            cycle_status: CYCLE_RESET,
            rs1_data: 0,
            rs2_data: 0
        };
      end
    end else begin
      for (int i = 1; i < `DIVIDER_STAGES; i++) begin
        divide_state[i] <= '{
            pc: divide_state[i-1].pc,
            insn: divide_state[i-1].insn,
            cycle_status: divide_state[i-1].cycle_status,
            rs1_data: divide_state[i-1].rs1_data,
            rs2_data: divide_state[i-1].rs2_data
        };
      end
    end
  end

  wire [255:0] divide_disasm[7:0];
  genvar i;
  generate
    for (i = 0; i < 8; i++) begin : gen_divide_disasm
      Disasm #(
          .PREFIX(8'("0" + i))
      ) disasm_execute (
          .insn  (divide_state[i].insn),
          .disasm(divide_disasm[i])
      );
    end
  endgenerate

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

  wire [`OPCODE_SIZE] d7_insn_opcode;
  assign d7_insn_opcode = divide_state[7].insn[6:0];
  wire d7_insn_div    = d7_insn_opcode == OpRegReg && divide_state[7].insn[31:25] == 7'd1 && divide_state[7].insn[14:12] == 3'b100;
  wire d7_insn_divu   = d7_insn_opcode == OpRegReg && divide_state[7].insn[31:25] == 7'd1 && divide_state[7].insn[14:12] == 3'b101;
  wire d7_insn_rem    = d7_insn_opcode == OpRegReg && divide_state[7].insn[31:25] == 7'd1 && divide_state[7].insn[14:12] == 3'b110;
  wire d7_insn_remu   = d7_insn_opcode == OpRegReg && divide_state[7].insn[31:25] == 7'd1 && divide_state[7].insn[14:12] == 3'b111;
  wire d7_is_div_cycle = (d7_insn_div || d7_insn_divu || d7_insn_rem || d7_insn_remu);

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
        end else if (insn_mul) begin
          multiplication_result = x_rs1_data * x_rs2_data;
          alu_result_logic = multiplication_result[31:0];
        end else if (insn_mulh) begin
          multiplication_result = $signed(x_rs1_data) * $signed(x_rs2_data);
          alu_result_logic = multiplication_result[63:32];
        end else if (insn_mulhsu) begin
          multiplication_result = $signed(x_rs1_data) * $signed({1'b0, x_rs2_data});
          alu_result_logic = multiplication_result[63:32];
        end else if (insn_mulhu) begin
          multiplication_result = x_rs1_data * x_rs2_data;
          alu_result_logic = multiplication_result[63:32];
        end else if (insn_div) begin
          i_dividend_logic = x_rs1_data[31] ? x_rs1_negated : x_rs1_data;
          i_divisor_logic  = x_rs2_data[31] ? x_rs2_negated : x_rs2_data;
        end else if (insn_divu) begin
          i_dividend_logic = x_rs1_data;
          i_divisor_logic  = x_rs2_data;
        end else if (insn_rem) begin
          i_dividend_logic = x_rs1_data[31] ? x_rs1_negated : x_rs1_data;
          i_divisor_logic  = x_rs2_data[31] ? x_rs2_negated : x_rs2_data;
        end else if (insn_remu) begin
          i_dividend_logic = x_rs1_data;
          i_divisor_logic  = x_rs2_data;
        end
      end
      // OpMiscMem: begin

      // end
      default: begin
        if (!d7_is_div_cycle) begin
          illegal_insn = 1'b1;
        end
      end
    endcase

    if (d7_insn_div) begin
      alu_result_logic = (divide_state[7].rs1_data[31] ^ divide_state[7].rs2_data[31]) ? quotient_negated : o_quotient;
      alu_result_logic = (divide_state[7].rs2_data == 32'b0) ? ~32'b0 : alu_result_logic;
    end else if (d7_insn_divu) begin
      alu_result_logic = (divide_state[7].rs2_data == 32'b0) ? ~32'b0 : o_quotient;
    end else if (d7_insn_rem) begin
      alu_result_logic = divide_state[7].rs1_data[31] ? remainder_negated : o_remainder;
      alu_result_logic = (divide_state[7].rs2_data == 32'b0) ? divide_state[7].rs1_data : alu_result_logic;
    end else if (d7_insn_remu) begin
      alu_result_logic = (divide_state[7].rs2_data == 32'b0) ? divide_state[7].rs1_data : o_remainder;
    end
  end



  /****************/
  /* MEMORY STAGE */
  /****************/

  // this shows how to package up state in a `struct packed`, and how to pass it between stages
  stage_memory_t memory_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      memory_state <= '{pc: 0, insn: 0, cycle_status: CYCLE_RESET, alu_result: 0, rs2_data: 0};
    end else if (divide_state[7].insn != `NOP_INSN) begin
      memory_state <= '{
          pc: divide_state[7].pc,
          insn: divide_state[7].insn,
          cycle_status: divide_state[7].cycle_status,
          alu_result: alu_result_logic,
          rs2_data: divide_state[7].rs2_data
      };
    end else if (!is_div_cycle) begin
      memory_state <= '{
          pc: execute_state.pc,
          insn: execute_state.insn,
          cycle_status: execute_state.cycle_status,
          alu_result: alu_result_logic,
          rs2_data: x_rs2_data
      };
    end else begin
      memory_state <= '{
          pc: 0,
          insn: `NOP_INSN,
          cycle_status: CYCLE_DIV,
          alu_result: 0,
          rs2_data: 0
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

  assign trace_completed_pc = writeback_state.pc;
  assign trace_completed_insn = writeback_state.insn;
  assign trace_completed_cycle_status = writeback_state.cycle_status;


endmodule  // DatapathPipelinedCache

/* This design has just one clock for both processor and memory. */
module Processor (
    input wire clk,
    input wire rst,
    output logic halt,
    output wire [`REG_SIZE] trace_completed_pc,
    output wire [`INSN_SIZE] trace_completed_insn,
    output cycle_status_e trace_completed_cycle_status
);

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
  wire [(8*32)-1:0] test_case;

  axil_if axil_mem_ro ();
  axil_if axil_mem_rw ();

  EasyAxilMemory #(
      .OPT_SKIDBUFFER(1),
      .OPT_LOWPOWER(0),
      .NUM_WORDS(8192)
  ) memory (
      .ACLK(clk),
      .ARESETn(~rst),
      .port_ro(axil_mem_ro.subord),
      .port_rw(axil_mem_rw.subord)
  );

  DatapathPipelinedAxil datapath (
      .clk(clk),
      .rst(rst),
      .imem(axil_mem_ro.manager),
      .dmem(axil_mem_rw.manager),
      .halt(halt),
      .trace_completed_pc(trace_completed_pc),
      .trace_completed_insn(trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status)
  );

endmodule
