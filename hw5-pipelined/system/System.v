module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "20" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(5),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(30),
		.CLKOP_CPHASE(15),
		.CLKOP_FPHASE(0),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(4)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_proc),
		.CLKFB(clkfb),
		.CLKINTFB(clkfb),
		.PHASESEL0(1'b0),
		.PHASESEL1(1'b0),
		.PHASEDIR(1'b1),
		.PHASESTEP(1'b1),
		.PHASELOADREG(1'b1),
		.PLLWAKESYNC(1'b0),
		.ENCLKOP(1'b0),
		.LOCK(locked)
	);
endmodule
module gp1 (
	a,
	b,
	g,
	p
);
	input wire a;
	input wire b;
	output wire g;
	output wire p;
	assign g = a & b;
	assign p = a | b;
endmodule
module gp4 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [3:0] gin;
	input wire [3:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [2:0] cout;
	assign cout[0] = gin[0] | (pin[0] & cin);
	assign cout[1] = (gin[1] | (pin[1] & gin[0])) | ((pin[1] & pin[0]) & cin);
	assign cout[2] = ((gin[2] | (pin[2] & gin[1])) | ((pin[2] & pin[1]) & gin[0])) | (((pin[2] & pin[1]) & pin[0]) & cin);
	assign gout = ((gin[3] | (pin[3] & gin[2])) | ((pin[3] & pin[2]) & gin[1])) | (((pin[3] & pin[2]) & pin[1]) & gin[0]);
	assign pout = ((pin[3] & pin[2]) & pin[1]) & pin[0];
endmodule
module gp8 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [7:0] gin;
	input wire [7:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [6:0] cout;
	assign cout[0] = gin[0] | (pin[0] & cin);
	assign cout[1] = (gin[1] | (pin[1] & gin[0])) | ((pin[1] & pin[0]) & cin);
	assign cout[2] = ((gin[2] | (pin[2] & gin[1])) | ((pin[2] & pin[1]) & gin[0])) | (((pin[2] & pin[1]) & pin[0]) & cin);
	assign cout[3] = (((gin[3] | (pin[3] & gin[2])) | ((pin[3] & pin[2]) & gin[1])) | (((pin[3] & pin[2]) & pin[1]) & gin[0])) | ((((pin[3] & pin[2]) & pin[1]) & pin[0]) & cin);
	assign cout[4] = ((((gin[4] | (pin[4] & gin[3])) | ((pin[4] & pin[3]) & gin[2])) | (((pin[4] & pin[3]) & pin[2]) & gin[1])) | ((((pin[4] & pin[3]) & pin[2]) & pin[1]) & gin[0])) | (((((pin[4] & pin[3]) & pin[2]) & pin[1]) & pin[0]) & cin);
	assign cout[5] = (((((gin[5] | (pin[5] & gin[4])) | ((pin[5] & pin[4]) & gin[3])) | (((pin[5] & pin[4]) & pin[3]) & gin[2])) | ((((pin[5] & pin[4]) & pin[3]) & pin[2]) & gin[1])) | (((((pin[5] & pin[4]) & pin[3]) & pin[2]) & pin[1]) & gin[0])) | ((((((pin[5] & pin[4]) & pin[3]) & pin[2]) & pin[1]) & pin[0]) & cin);
	assign cout[6] = ((((((gin[6] | (pin[6] & gin[5])) | ((pin[6] & pin[5]) & gin[4])) | (((pin[6] & pin[5]) & pin[4]) & gin[3])) | ((((pin[6] & pin[5]) & pin[4]) & pin[3]) & gin[2])) | (((((pin[6] & pin[5]) & pin[4]) & pin[3]) & pin[2]) & gin[1])) | ((((((pin[6] & pin[5]) & pin[4]) & pin[3]) & pin[2]) & pin[1]) & gin[0])) | (((((((pin[6] & pin[5]) & pin[4]) & pin[3]) & pin[2]) & pin[1]) & pin[0]) & cin);
	assign gout = ((((((gin[7] | (pin[7] & gin[6])) | ((pin[7] & pin[6]) & gin[5])) | (((pin[7] & pin[6]) & pin[5]) & gin[4])) | ((((pin[7] & pin[6]) & pin[5]) & pin[4]) & gin[3])) | (((((pin[7] & pin[6]) & pin[5]) & pin[4]) & pin[3]) & gin[2])) | ((((((pin[7] & pin[6]) & pin[5]) & pin[4]) & pin[3]) & pin[2]) & gin[1])) | (((((((pin[7] & pin[6]) & pin[5]) & pin[4]) & pin[3]) & pin[2]) & pin[1]) & gin[0]);
	assign pout = ((((((pin[7] & pin[6]) & pin[5]) & pin[4]) & pin[3]) & pin[2]) & pin[1]) & pin[0];
endmodule
module CarryLookaheadAdder (
	a,
	b,
	cin,
	sum
);
	input wire [31:0] a;
	input wire [31:0] b;
	input wire cin;
	output wire [31:0] sum;
	wire [31:0] cout;
	wire [31:0] g1;
	wire [31:0] p1;
	wire [8:0] g2;
	wire [8:0] p2;
	wire gout;
	wire pout;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : genblk1
			localparam i = _gv_i_1;
			gp1 first(
				.a(a[i]),
				.b(b[i]),
				.g(g1[i]),
				.p(p1[i])
			);
		end
	endgenerate
	gp4 top(
		.gin(g1[3:0]),
		.pin(p1[3:0]),
		.cin(cin),
		.gout(g2[0]),
		.pout(p2[0]),
		.cout(cout[2:0])
	);
	generate
		for (_gv_i_1 = 1; _gv_i_1 < 8; _gv_i_1 = _gv_i_1 + 1) begin : genblk2
			localparam i = _gv_i_1;
			gp4 bottoms(
				.gin(g1[(4 * i) + 3:4 * i]),
				.pin(p1[(4 * i) + 3:4 * i]),
				.cin(cout[(4 * i) - 1]),
				.gout(g2[i]),
				.pout(p2[i]),
				.cout(cout[(4 * i) + 2:4 * i])
			);
		end
	endgenerate
	gp8 last(
		.gin(g2[7:0]),
		.pin(p2[7:0]),
		.cin(cin),
		.gout(gout),
		.pout(pout),
		.cout({cout[27], cout[23], cout[19], cout[15], cout[11], cout[7], cout[3]})
	);
	assign cout[31] = gout | (pout & cin);
	assign sum[0] = (a[0] ^ b[0]) ^ cin;
	generate
		for (_gv_i_1 = 1; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : genblk3
			localparam i = _gv_i_1;
			assign sum[i] = (a[i] ^ b[i]) ^ cout[i - 1];
		end
	endgenerate
endmodule
module DividerUnsignedPipelined (
	clk,
	rst,
	stall,
	i_dividend,
	i_divisor,
	o_remainder,
	o_quotient
);
	input wire clk;
	input wire rst;
	input wire stall;
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] dividend [0:31];
	wire [31:0] remainder [0:30];
	wire [31:0] quotient [0:30];
	reg [127:0] regs [0:6];
	divu_1iter first_final_divide_iter(
		.i_dividend(regs[6][127-:32]),
		.i_divisor(regs[6][95-:32]),
		.i_remainder(regs[6][63-:32]),
		.i_quotient(regs[6][31-:32]),
		.o_dividend(dividend[28]),
		.o_remainder(remainder[28]),
		.o_quotient(quotient[28])
	);
	genvar _gv_i_2;
	generate
		for (_gv_i_2 = 29; _gv_i_2 < 31; _gv_i_2 = _gv_i_2 + 1) begin : gen_final_stage
			localparam i = _gv_i_2;
			divu_1iter intermediate_final_divide_iters(
				.i_dividend(dividend[i - 1]),
				.i_divisor(regs[6][95-:32]),
				.i_remainder(remainder[i - 1]),
				.i_quotient(quotient[i - 1]),
				.o_dividend(dividend[i]),
				.o_remainder(remainder[i]),
				.o_quotient(quotient[i])
			);
		end
	endgenerate
	divu_1iter final_final_divide_iter(
		.i_dividend(dividend[30]),
		.i_divisor(regs[6][95-:32]),
		.i_remainder(remainder[30]),
		.i_quotient(quotient[30]),
		.o_dividend(dividend[31]),
		.o_remainder(o_remainder),
		.o_quotient(o_quotient)
	);
	genvar _gv_s_1;
	generate
		for (_gv_s_1 = 6; _gv_s_1 > 0; _gv_s_1 = _gv_s_1 - 1) begin : gen_inter_stages
			localparam s = _gv_s_1;
			divu_1iter first_intermediate_divide_iter(
				.i_dividend(regs[s - 1][127-:32]),
				.i_divisor(regs[s - 1][95-:32]),
				.i_remainder(regs[s - 1][63-:32]),
				.i_quotient(regs[s - 1][31-:32]),
				.o_dividend(dividend[4 * s]),
				.o_remainder(remainder[4 * s]),
				.o_quotient(quotient[4 * s])
			);
			genvar _gv_j_1;
			for (_gv_j_1 = (4 * s) + 1; _gv_j_1 < (4 * (s + 1)); _gv_j_1 = _gv_j_1 + 1) begin : gen_j_iters
				localparam j = _gv_j_1;
				divu_1iter intermediate_intermediate_divide_iters(
					.i_dividend(dividend[j - 1]),
					.i_divisor(regs[s - 1][95-:32]),
					.i_remainder(remainder[j - 1]),
					.i_quotient(quotient[j - 1]),
					.o_dividend(dividend[j]),
					.o_remainder(remainder[j]),
					.o_quotient(quotient[j])
				);
			end
			always @(posedge clk) begin
				regs[s][127-:32] <= dividend[(4 * s) + 3];
				regs[s][95-:32] <= regs[s - 1][95-:32];
				regs[s][63-:32] <= remainder[(4 * s) + 3];
				regs[s][31-:32] <= quotient[(4 * s) + 3];
			end
		end
	endgenerate
	divu_1iter first_first_divide_iter(
		.i_dividend(i_dividend),
		.i_divisor(i_divisor),
		.i_remainder(32'b00000000000000000000000000000000),
		.i_quotient(32'b00000000000000000000000000000000),
		.o_dividend(dividend[0]),
		.o_remainder(remainder[0]),
		.o_quotient(quotient[0])
	);
	genvar _gv_k_1;
	generate
		for (_gv_k_1 = 1; _gv_k_1 < 4; _gv_k_1 = _gv_k_1 + 1) begin : gen_k_iters
			localparam k = _gv_k_1;
			divu_1iter intermediate_first_divide_iters(
				.i_dividend(dividend[k - 1]),
				.i_divisor(i_divisor),
				.i_remainder(remainder[k - 1]),
				.i_quotient(quotient[k - 1]),
				.o_dividend(dividend[k]),
				.o_remainder(remainder[k]),
				.o_quotient(quotient[k])
			);
		end
	endgenerate
	always @(posedge clk) begin
		regs[0][127-:32] <= dividend[3];
		regs[0][95-:32] <= i_divisor;
		regs[0][63-:32] <= remainder[3];
		regs[0][31-:32] <= quotient[3];
	end
endmodule
module divu_1iter (
	i_dividend,
	i_divisor,
	i_remainder,
	i_quotient,
	o_dividend,
	o_remainder,
	o_quotient
);
	reg _sv2v_0;
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	input wire [31:0] i_remainder;
	input wire [31:0] i_quotient;
	output wire [31:0] o_dividend;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	assign o_dividend = i_dividend << 1;
	wire [31:0] remainder_int;
	reg [31:0] o_quotient_logic;
	reg [31:0] o_remainder_logic;
	assign remainder_int = ((i_dividend >> 31) & 32'b00000000000000000000000000000001) | (i_remainder << 1);
	always @(*) begin
		if (_sv2v_0)
			;
		if (remainder_int < i_divisor) begin
			o_quotient_logic = i_quotient << 1;
			o_remainder_logic = remainder_int;
		end
		else begin
			o_quotient_logic = (i_quotient << 1) | 32'b00000000000000000000000000000001;
			o_remainder_logic = remainder_int - i_divisor;
		end
	end
	assign o_quotient = o_quotient_logic;
	assign o_remainder = o_remainder_logic;
	initial _sv2v_0 = 0;
endmodule
module Disasm (
	insn,
	disasm
);
	parameter signed [7:0] PREFIX = "D";
	input wire [31:0] insn;
	output wire [255:0] disasm;
endmodule
module RegFile (
	rd,
	rd_data,
	rs1,
	rs1_data,
	rs2,
	rs2_data,
	clk,
	we,
	rst
);
	input wire [4:0] rd;
	input wire [31:0] rd_data;
	input wire [4:0] rs1;
	output wire [31:0] rs1_data;
	input wire [4:0] rs2;
	output wire [31:0] rs2_data;
	input wire clk;
	input wire we;
	input wire rst;
	localparam signed [31:0] NumRegs = 32;
	reg [31:0] regs [0:31];
	wire [32:1] sv2v_tmp_E4190;
	assign sv2v_tmp_E4190 = 32'd0;
	always @(*) regs[0] = sv2v_tmp_E4190;
	assign rs1_data = ((we && (rd == rs1)) && (rs1 != 5'd0) ? rd_data : regs[rs1]);
	assign rs2_data = ((we && (rd == rs2)) && (rs2 != 5'd0) ? rd_data : regs[rs2]);
	genvar _gv_i_3;
	generate
		for (_gv_i_3 = 1; _gv_i_3 < 32; _gv_i_3 = _gv_i_3 + 1) begin : genblk1
			localparam i = _gv_i_3;
			always @(posedge clk)
				if (rst)
					regs[i] <= 32'd0;
				else if (we && (rd == i))
					regs[i] <= rd_data;
		end
	endgenerate
endmodule
module DatapathPipelined (
	clk,
	rst,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem,
	halt,
	trace_completed_pc,
	trace_completed_insn,
	trace_completed_cycle_status
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	output wire [31:0] pc_to_imem;
	input wire [31:0] insn_from_imem;
	output reg [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output reg [31:0] store_data_to_dmem;
	output reg [3:0] store_we_to_dmem;
	output reg halt;
	output wire [31:0] trace_completed_pc;
	output wire [31:0] trace_completed_insn;
	output wire [31:0] trace_completed_cycle_status;
	localparam [6:0] OpLoad = 7'b0000011;
	localparam [6:0] OpStore = 7'b0100011;
	localparam [6:0] OpBranch = 7'b1100011;
	localparam [6:0] OpJalr = 7'b1100111;
	localparam [6:0] OpMiscMem = 7'b0001111;
	localparam [6:0] OpJal = 7'b1101111;
	localparam [6:0] OpRegImm = 7'b0010011;
	localparam [6:0] OpRegReg = 7'b0110011;
	localparam [6:0] OpEnviron = 7'b1110011;
	localparam [6:0] OpAuipc = 7'b0010111;
	localparam [6:0] OpLui = 7'b0110111;
	reg [31:0] cycles_current;
	always @(posedge clk)
		if (rst)
			cycles_current <= 0;
		else
			cycles_current <= cycles_current + 1;
	reg [31:0] f_pc_current;
	wire [31:0] f_insn;
	reg [31:0] f_cycle_status;
	reg branch_successful;
	reg [95:0] decode_state;
	reg [159:0] execute_state;
	wire load_use_stall = ((execute_state[102:96] == OpLoad) && (execute_state[107:103] != 5'b00000)) && ((decode_state[51:47] == execute_state[107:103]) || ((decode_state[56:52] == execute_state[107:103]) && (decode_state[38:32] != OpStore)));
	reg [31:0] x_branch_target;
	always @(posedge clk)
		if (rst) begin
			f_pc_current <= 32'd0;
			f_cycle_status <= 32'd1;
		end
		else begin
			f_cycle_status <= 32'd1;
			if (branch_successful)
				f_pc_current <= x_branch_target;
			else if (!load_use_stall)
				f_pc_current <= f_pc_current + 4;
		end
	assign pc_to_imem = f_pc_current;
	assign f_insn = insn_from_imem;
	wire [255:0] f_disasm;
	Disasm #(.PREFIX("F")) disasm_0fetch(
		.insn(f_insn),
		.disasm(f_disasm)
	);
	always @(posedge clk)
		if (rst)
			decode_state <= 96'h000000000000000000000004;
		else if (branch_successful)
			decode_state <= 96'h000000000000001300000008;
		else if (!load_use_stall)
			decode_state <= {f_pc_current, f_insn, f_cycle_status};
	wire [255:0] d_disasm;
	Disasm #(.PREFIX("D")) disasm_1decode(
		.insn(decode_state[63-:32]),
		.disasm(d_disasm)
	);
	wire we;
	reg [159:0] writeback_state;
	wire [4:0] insn_rd = writeback_state[107:103];
	wire [4:0] insn_rs1 = decode_state[51:47];
	wire [4:0] insn_rs2 = decode_state[56:52];
	wire [31:0] rd_data;
	wire [31:0] rs1_data;
	wire [31:0] rs2_data;
	RegFile rf(
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
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk)
		if (rst)
			execute_state <= 160'h0000000000000000000000040000000000000000;
		else if (branch_successful || load_use_stall)
			execute_state <= {64'h0000000000000013, (branch_successful ? 32'd8 : 32'd16), 64'h0000000000000000};
		else
			execute_state <= {sv2v_cast_32(decode_state[95-:32]), sv2v_cast_32(decode_state[63-:32]), sv2v_cast_32(decode_state[31-:32]), rs1_data, rs2_data};
	wire [255:0] x_disasm;
	Disasm #(.PREFIX("X")) disasm_2execute(
		.insn(execute_state[127-:32]),
		.disasm(x_disasm)
	);
	wire [6:0] x_insn_funct7;
	wire [2:0] x_insn_funct3;
	wire [6:0] x_insn_opcode;
	assign x_insn_funct7 = execute_state[127:121];
	assign x_insn_funct3 = execute_state[110:108];
	assign x_insn_opcode = execute_state[102:96];
	wire [11:0] x_imm_i;
	assign x_imm_i = execute_state[127:116];
	wire [4:0] x_imm_shamt = execute_state[120:116];
	wire [11:0] x_imm_s;
	assign x_imm_s[11:5] = x_insn_funct7;
	wire [12:0] x_imm_b;
	assign {x_imm_b[12], x_imm_b[10:5]} = x_insn_funct7;
	assign {x_imm_b[4:1], x_imm_b[11]} = execute_state[107:103];
	assign x_imm_b[0] = 1'b0;
	wire [20:0] x_imm_j;
	assign {x_imm_j[20], x_imm_j[10:1], x_imm_j[11], x_imm_j[19:12], x_imm_j[0]} = {execute_state[127:108], 1'b0};
	wire [31:0] x_imm_i_sext = {{20 {x_imm_i[11]}}, x_imm_i[11:0]};
	wire [31:0] x_imm_s_sext = {{20 {x_imm_s[11]}}, x_imm_s[11:0]};
	wire [31:0] x_imm_b_sext = {{19 {x_imm_b[12]}}, x_imm_b[12:0]};
	wire [31:0] x_imm_j_sext = {{11 {x_imm_j[20]}}, x_imm_j[20:0]};
	wire insn_lui = x_insn_opcode == OpLui;
	wire insn_auipc = x_insn_opcode == OpAuipc;
	wire insn_jal = x_insn_opcode == OpJal;
	wire insn_jalr = x_insn_opcode == OpJalr;
	wire insn_beq = (x_insn_opcode == OpBranch) && (execute_state[110:108] == 3'b000);
	wire insn_bne = (x_insn_opcode == OpBranch) && (execute_state[110:108] == 3'b001);
	wire insn_blt = (x_insn_opcode == OpBranch) && (execute_state[110:108] == 3'b100);
	wire insn_bge = (x_insn_opcode == OpBranch) && (execute_state[110:108] == 3'b101);
	wire insn_bltu = (x_insn_opcode == OpBranch) && (execute_state[110:108] == 3'b110);
	wire insn_bgeu = (x_insn_opcode == OpBranch) && (execute_state[110:108] == 3'b111);
	wire insn_addi = (x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b000);
	wire insn_slti = (x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b010);
	wire insn_sltiu = (x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b011);
	wire insn_xori = (x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b100);
	wire insn_ori = (x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b110);
	wire insn_andi = (x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b111);
	wire insn_slli = ((x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b001)) && (execute_state[127:121] == 7'd0);
	wire insn_srli = ((x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b101)) && (execute_state[127:121] == 7'd0);
	wire insn_srai = ((x_insn_opcode == OpRegImm) && (execute_state[110:108] == 3'b101)) && (execute_state[127:121] == 7'b0100000);
	wire insn_add = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b000)) && (execute_state[127:121] == 7'd0);
	wire insn_sub = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b000)) && (execute_state[127:121] == 7'b0100000);
	wire insn_sll = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b001)) && (execute_state[127:121] == 7'd0);
	wire insn_slt = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b010)) && (execute_state[127:121] == 7'd0);
	wire insn_sltu = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b011)) && (execute_state[127:121] == 7'd0);
	wire insn_xor = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b100)) && (execute_state[127:121] == 7'd0);
	wire insn_srl = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b101)) && (execute_state[127:121] == 7'd0);
	wire insn_sra = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b101)) && (execute_state[127:121] == 7'b0100000);
	wire insn_or = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b110)) && (execute_state[127:121] == 7'd0);
	wire insn_and = ((x_insn_opcode == OpRegReg) && (execute_state[110:108] == 3'b111)) && (execute_state[127:121] == 7'd0);
	wire insn_mul = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b000);
	wire insn_mulh = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b001);
	wire insn_mulhsu = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b010);
	wire insn_mulhu = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b011);
	wire insn_div = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b100);
	wire insn_divu = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b101);
	wire insn_rem = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b110);
	wire insn_remu = ((x_insn_opcode == OpRegReg) && (execute_state[127:121] == 7'd1)) && (execute_state[110:108] == 3'b111);
	wire is_div_cycle = ((insn_div || insn_divu) || insn_rem) || insn_remu;
	wire insn_ecall = (x_insn_opcode == OpEnviron) && (execute_state[127:103] == 25'd0);
	wire insn_fence = x_insn_opcode == OpMiscMem;
	wire [31:0] a;
	wire [31:0] b;
	wire carry_in;
	wire [31:0] sum;
	CarryLookaheadAdder cla(
		.a(a),
		.b(b),
		.cin(carry_in),
		.sum(sum)
	);
	wire [31:0] x_rs1_negated;
	reg [31:0] x_rs1_data;
	CarryLookaheadAdder negator_rs1(
		.a(~x_rs1_data),
		.b(32'b00000000000000000000000000000000),
		.cin(1'b1),
		.sum(x_rs1_negated)
	);
	wire [31:0] x_rs2_negated;
	reg [31:0] x_rs2_data;
	CarryLookaheadAdder negator_rs2(
		.a(~x_rs2_data),
		.b(32'b00000000000000000000000000000000),
		.cin(1'b1),
		.sum(x_rs2_negated)
	);
	wire [31:0] quotient_negated;
	wire [31:0] o_quotient;
	CarryLookaheadAdder negator_quotient(
		.a(~o_quotient),
		.b(32'b00000000000000000000000000000000),
		.cin(1'b1),
		.sum(quotient_negated)
	);
	wire [31:0] remainder_negated;
	wire [31:0] o_remainder;
	CarryLookaheadAdder negator_remainder(
		.a(~o_remainder),
		.b(32'b00000000000000000000000000000000),
		.cin(1'b1),
		.sum(remainder_negated)
	);
	wire [31:0] i_dividend;
	wire [31:0] i_divisor;
	DividerUnsignedPipelined divider(
		.clk(clk),
		.rst(rst),
		.stall(1'b0),
		.i_dividend(i_dividend),
		.i_divisor(i_divisor),
		.o_remainder(o_remainder),
		.o_quotient(o_quotient)
	);
	reg illegal_insn;
	reg [31:0] alu_result_logic;
	reg [31:0] a_logic;
	reg [31:0] b_logic;
	reg carry_in_logic;
	reg [63:0] multiplication_result;
	reg [31:0] i_dividend_logic;
	reg [31:0] i_divisor_logic;
	assign a = a_logic;
	assign b = b_logic;
	assign carry_in = carry_in_logic;
	assign i_dividend = i_dividend_logic;
	assign i_divisor = i_divisor_logic;
	reg [159:0] memory_state;
	wire [6:0] m_opcode_bypass = memory_state[102:96];
	wire M_bypass = (memory_state[107:103] != 5'b00000) && (((((((m_opcode_bypass == OpLui) || (m_opcode_bypass == OpAuipc)) || (m_opcode_bypass == OpJal)) || (m_opcode_bypass == OpJalr)) || (m_opcode_bypass == OpRegReg)) || (m_opcode_bypass == OpRegImm)) || (m_opcode_bypass == OpLoad));
	wire [6:0] w_opcode_bypass = writeback_state[102:96];
	wire W_bypass = (writeback_state[107:103] != 5'b00000) && (((((((w_opcode_bypass == OpLui) || (w_opcode_bypass == OpAuipc)) || (w_opcode_bypass == OpJal)) || (w_opcode_bypass == OpJalr)) || (w_opcode_bypass == OpRegReg)) || (w_opcode_bypass == OpRegImm)) || (w_opcode_bypass == OpLoad));
	wire [31:0] w_bypassed_data = (w_opcode_bypass == OpLoad ? writeback_state[31-:32] : writeback_state[63-:32]);
	wire [4:0] x_rs1 = execute_state[115:111];
	wire [4:0] x_rs2 = execute_state[120:116];
	always @(*) begin
		if (_sv2v_0)
			;
		x_rs1_data = execute_state[63-:32];
		x_rs2_data = execute_state[31-:32];
		if (M_bypass && (memory_state[107:103] == x_rs1))
			x_rs1_data = memory_state[63-:32];
		else if (W_bypass && (writeback_state[107:103] == x_rs1))
			x_rs1_data = w_bypassed_data;
		if (M_bypass && (memory_state[107:103] == x_rs2))
			x_rs2_data = memory_state[63-:32];
		else if (W_bypass && (writeback_state[107:103] == x_rs2))
			x_rs2_data = w_bypassed_data;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		illegal_insn = 1'b0;
		alu_result_logic = 32'b00000000000000000000000000000000;
		a_logic = 32'b00000000000000000000000000000000;
		b_logic = 32'b00000000000000000000000000000000;
		carry_in_logic = 1'b0;
		branch_successful = 0;
		x_branch_target = 32'b00000000000000000000000000000000;
		multiplication_result = 64'b0000000000000000000000000000000000000000000000000000000000000000;
		i_dividend_logic = 32'b00000000000000000000000000000000;
		i_divisor_logic = 32'b00000000000000000000000000000000;
		case (x_insn_opcode)
			OpLui: alu_result_logic = {execute_state[127:108], 12'b000000000000};
			OpAuipc: alu_result_logic = execute_state[159-:32] + {execute_state[127:108], 12'b000000000000};
			OpJal: begin
				alu_result_logic = execute_state[159-:32] + 4;
				branch_successful = 1'b1;
				x_branch_target = execute_state[159-:32] + x_imm_j_sext;
			end
			OpJalr: begin
				alu_result_logic = execute_state[159-:32] + 4;
				branch_successful = 1'b1;
				x_branch_target = (x_rs1_data + x_imm_i_sext) & ~32'b00000000000000000000000000000001;
			end
			OpBranch: begin
				x_branch_target = execute_state[159-:32] + x_imm_b_sext;
				if (insn_beq) begin
					if (x_rs1_data == x_rs2_data)
						branch_successful = 1'b1;
				end
				else if (insn_bne) begin
					if (x_rs1_data != x_rs2_data)
						branch_successful = 1'b1;
				end
				else if (insn_blt) begin
					if ($signed(x_rs1_data) < $signed(x_rs2_data))
						branch_successful = 1'b1;
				end
				else if (insn_bge) begin
					if ($signed(x_rs1_data) >= $signed(x_rs2_data))
						branch_successful = 1'b1;
				end
				else if (insn_bltu) begin
					if (x_rs1_data < x_rs2_data)
						branch_successful = 1'b1;
				end
				else if (insn_bgeu) begin
					if (x_rs1_data >= x_rs2_data)
						branch_successful = 1'b1;
				end
				else
					illegal_insn = 1'b1;
			end
			OpLoad: alu_result_logic = x_rs1_data + x_imm_i_sext;
			OpStore: alu_result_logic = x_rs1_data + x_imm_s_sext;
			OpRegImm:
				if (insn_addi) begin
					a_logic = x_rs1_data;
					b_logic = x_imm_i_sext;
					alu_result_logic = sum;
				end
				else if (insn_slti)
					alu_result_logic = ($signed(x_rs1_data) < $signed(x_imm_i_sext) ? 1 : 0);
				else if (insn_sltiu)
					alu_result_logic = (x_rs1_data < x_imm_i_sext ? 1 : 0);
				else if (insn_xori)
					alu_result_logic = x_rs1_data ^ x_imm_i_sext;
				else if (insn_ori)
					alu_result_logic = x_rs1_data | x_imm_i_sext;
				else if (insn_andi)
					alu_result_logic = x_rs1_data & x_imm_i_sext;
				else if (insn_slli)
					alu_result_logic = x_rs1_data << x_imm_i_sext[4:0];
				else if (insn_srli)
					alu_result_logic = x_rs1_data >> x_imm_i_sext[4:0];
				else if (insn_srai)
					alu_result_logic = $signed(x_rs1_data) >>> x_imm_i_sext[4:0];
				else
					illegal_insn = 1'b1;
			OpRegReg:
				if (insn_add) begin
					a_logic = x_rs1_data;
					b_logic = x_rs2_data;
					alu_result_logic = sum;
				end
				else if (insn_sub) begin
					a_logic = x_rs1_data;
					b_logic = ~x_rs2_data;
					carry_in_logic = 1'b1;
					alu_result_logic = sum;
				end
				else if (insn_sll)
					alu_result_logic = x_rs1_data << x_rs2_data[4:0];
				else if (insn_slt)
					alu_result_logic = ($signed(x_rs1_data) < $signed(x_rs2_data) ? 1 : 0);
				else if (insn_sltu)
					alu_result_logic = (x_rs1_data < x_rs2_data ? 1 : 0);
				else if (insn_xor)
					alu_result_logic = x_rs1_data ^ x_rs2_data;
				else if (insn_srl)
					alu_result_logic = x_rs1_data >> x_rs2_data[4:0];
				else if (insn_sra)
					alu_result_logic = $signed(x_rs1_data) >>> x_rs2_data[4:0];
				else if (insn_or)
					alu_result_logic = x_rs1_data | x_rs2_data;
				else if (insn_and)
					alu_result_logic = x_rs1_data & x_rs2_data;
			default: illegal_insn = 1'b1;
		endcase
	end
	always @(posedge clk)
		if (rst)
			memory_state <= 160'h0000000000000000000000040000000000000000;
		else
			memory_state <= {sv2v_cast_32(execute_state[159-:32]), sv2v_cast_32(execute_state[127-:32]), sv2v_cast_32(execute_state[95-:32]), alu_result_logic, x_rs2_data};
	wire [255:0] m_disasm;
	Disasm #(.PREFIX("M")) disasm_3memory(
		.insn(memory_state[127-:32]),
		.disasm(m_disasm)
	);
	wire [6:0] m_insn_opcode = memory_state[102:96];
	reg [31:0] offset;
	reg [31:0] m_load_data;
	wire insn_lb = (m_insn_opcode == OpLoad) && (memory_state[110:108] == 3'b000);
	wire insn_lh = (m_insn_opcode == OpLoad) && (memory_state[110:108] == 3'b001);
	wire insn_lw = (m_insn_opcode == OpLoad) && (memory_state[110:108] == 3'b010);
	wire insn_lbu = (m_insn_opcode == OpLoad) && (memory_state[110:108] == 3'b100);
	wire insn_lhu = (m_insn_opcode == OpLoad) && (memory_state[110:108] == 3'b101);
	wire insn_sb = (m_insn_opcode == OpStore) && (memory_state[110:108] == 3'b000);
	wire insn_sh = (m_insn_opcode == OpStore) && (memory_state[110:108] == 3'b001);
	wire insn_sw = (m_insn_opcode == OpStore) && (memory_state[110:108] == 3'b010);
	wire [4:0] m_rs2 = memory_state[120:116];
	reg [31:0] m_store_data;
	always @(*) begin
		if (_sv2v_0)
			;
		m_store_data = memory_state[31-:32];
		if (W_bypass && (writeback_state[107:103] == m_rs2))
			m_store_data = w_bypassed_data;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		addr_to_dmem = 32'b00000000000000000000000000000000;
		store_data_to_dmem = 32'b00000000000000000000000000000000;
		store_we_to_dmem = 4'b0000;
		offset = 32'b00000000000000000000000000000000;
		m_load_data = 32'b00000000000000000000000000000000;
		case (m_insn_opcode)
			OpLoad: begin
				addr_to_dmem = memory_state[63-:32] & ~32'b00000000000000000000000000000011;
				offset = memory_state[63-:32] & 32'b00000000000000000000000000000011;
				if (insn_lb)
					m_load_data = {{24 {load_data_from_dmem[(offset * 8) + 7]}}, load_data_from_dmem[offset * 8+:8]};
				else if (insn_lh)
					m_load_data = {{16 {load_data_from_dmem[(offset[1] * 16) + 15]}}, load_data_from_dmem[offset[1] * 16+:16]};
				else if (insn_lw)
					m_load_data = load_data_from_dmem[31:0];
				else if (insn_lbu)
					m_load_data = {24'b000000000000000000000000, load_data_from_dmem[offset * 8+:8]};
				else if (insn_lhu)
					m_load_data = {16'b0000000000000000, load_data_from_dmem[offset[1] * 16+:16]};
			end
			OpStore: begin
				addr_to_dmem = memory_state[63-:32] & ~32'b00000000000000000000000000000011;
				offset = memory_state[63-:32] & 32'b00000000000000000000000000000011;
				if (insn_sb) begin
					store_data_to_dmem[offset * 8+:8] = m_store_data[7:0];
					store_we_to_dmem = 4'b0001 << offset;
				end
				else if (insn_sh) begin
					store_data_to_dmem[offset[1] * 16+:16] = m_store_data[15:0];
					store_we_to_dmem = 4'b0011 << offset;
				end
				else if (insn_sw) begin
					store_data_to_dmem = m_store_data;
					store_we_to_dmem = 4'b1111;
				end
			end
			default:
				;
		endcase
	end
	always @(posedge clk)
		if (rst)
			writeback_state <= 160'h0000000000000000000000040000000000000000;
		else
			writeback_state <= {sv2v_cast_32(memory_state[159-:32]), sv2v_cast_32(memory_state[127-:32]), sv2v_cast_32(memory_state[95-:32]), sv2v_cast_32(memory_state[63-:32]), m_load_data};
	wire [255:0] w_disasm;
	Disasm #(.PREFIX("W")) disasm_4writeback(
		.insn(writeback_state[127-:32]),
		.disasm(w_disasm)
	);
	wire [6:0] w_opcode = writeback_state[102:96];
	wire [4:0] w_rd = writeback_state[107:103];
	reg we_logic;
	reg [31:0] rd_data_logic;
	always @(*) begin
		if (_sv2v_0)
			;
		we_logic = 1'b0;
		rd_data_logic = 32'b00000000000000000000000000000000;
		halt = 1'b0;
		case (w_opcode)
			OpLui, OpAuipc, OpJal, OpJalr, OpRegReg, OpRegImm: begin
				we_logic = 1'b1;
				rd_data_logic = writeback_state[63-:32];
			end
			OpLoad: begin
				we_logic = 1'b1;
				rd_data_logic = writeback_state[31-:32];
			end
			OpEnviron:
				if (writeback_state[95-:32] == 32'd1)
					halt = 1'b1;
			default:
				;
		endcase
	end
	assign we = we_logic;
	assign rd_data = rd_data_logic;
	assign trace_completed_pc = (writeback_state[95-:32] == 32'd1 ? writeback_state[159-:32] : 32'b00000000000000000000000000000000);
	assign trace_completed_insn = (writeback_state[95-:32] == 32'd1 ? writeback_state[127-:32] : 32'b00000000000000000000000000000000);
	assign trace_completed_cycle_status = writeback_state[95-:32];
	initial _sv2v_0 = 0;
endmodule
module MemorySingleCycle (
	rst,
	clk,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem
);
	reg _sv2v_0;
	parameter signed [31:0] NUM_WORDS = 512;
	input wire rst;
	input wire clk;
	input wire [31:0] pc_to_imem;
	output reg [31:0] insn_from_imem;
	input wire [31:0] addr_to_dmem;
	output reg [31:0] load_data_from_dmem;
	input wire [31:0] store_data_to_dmem;
	input wire [3:0] store_we_to_dmem;
	reg [31:0] mem_array [0:NUM_WORDS - 1];
	initial $readmemh("mem_initial_contents.hex", mem_array);
	always @(*)
		if (_sv2v_0)
			;
	localparam signed [31:0] AddrMsb = $clog2(NUM_WORDS) + 1;
	localparam signed [31:0] AddrLsb = 2;
	always @(negedge clk)
		if (rst)
			;
		else
			insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
	always @(negedge clk)
		if (rst)
			;
		else begin
			if (store_we_to_dmem[0])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
			if (store_we_to_dmem[1])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
			if (store_we_to_dmem[2])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
			if (store_we_to_dmem[3])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
			load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype none
`default_nettype none
module SystemResourceCheck (
	external_clk_25MHz,
	btn,
	led
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	wire clk_proc;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.locked(clk_locked)
	);
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	wire [31:0] trace_writeback_pc;
	wire [31:0] trace_writeback_insn;
	wire [31:0] trace_writeback_cycle_status;
	MemorySingleCycle #(.NUM_WORDS(128)) memory(
		.rst(!clk_locked),
		.clk(clk_proc),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we)
	);
	DatapathPipelined datapath(
		.clk(clk_proc),
		.rst(!clk_locked),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem(mem_data_loaded_value),
		.halt(led[0]),
		.trace_completed_pc(trace_writeback_pc),
		.trace_completed_insn(trace_writeback_insn),
		.trace_completed_cycle_status(trace_writeback_cycle_status)
	);
endmodule