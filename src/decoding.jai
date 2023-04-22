#import "Basic";
#import "Tagged_Union";

next_u8 :: (stream: *[] u8) -> u8 {
	if stream.count == 0
		return 0;
	ret := stream.data[0];
	stream.data += 1;
	stream.count -= 1;
	return ret;
}

next_u16 :: (stream: *[] u8) -> u16 {
	return (cast(u16) next_u8(stream)) | ((cast(u16) next_u8(stream)) << 8);
}

match_mask :: (idx: u8, mask: string) -> bool {
	assert(mask.count == 9);

	if mask[8] != #char "." && ((idx & 0b0000_0001) >> 0) != (mask[8] - #char "0")
		return false;
	if mask[7] != #char "." && ((idx & 0b0000_0010) >> 1) != (mask[7] - #char "0")
		return false;
	if mask[6] != #char "." && ((idx & 0b0000_0100) >> 2) != (mask[6] - #char "0")
		return false;
	if mask[5] != #char "." && ((idx & 0b0000_1000) >> 3) != (mask[5] - #char "0")
		return false;

	if mask[3] != #char "." && ((idx & 0b0001_0000) >> 4) != (mask[3] - #char "0")
		return false;
	if mask[2] != #char "." && ((idx & 0b0010_0000) >> 5) != (mask[2] - #char "0")
		return false;
	if mask[1] != #char "." && ((idx & 0b0100_0000) >> 6) != (mask[1] - #char "0")
		return false;
	if mask[0] != #char "." && ((idx & 0b1000_0000) >> 7) != (mask[0] - #char "0")
		return false;
	return true;
}

Template :: struct {
	mask: string;
	f: Table_Entry_F;
}

templates_base :: Template.[
	.{ mask = "1000_10..", f = #run binary_op_rm_r(T = MOV) },
	.{ mask = "1100_011.", f = #run binary_op_imm_rm(T = MOV, USE_S = false) },
	.{ mask = "1011_....", f = #run mov_imm_r() },
	.{ mask = "1010_000.", f = #run mov_mem_acc() },
	.{ mask = "1010_001.", f = #run mov_acc_mem() },

	.{ mask = "1000_00..", f = decode_immed },
	.{ mask = "1101_00..", f = decode_shift },
	.{ mask = "1111_011.", f = decode_grp1 },
	.{ mask = "1111_111.", f = decode_grp2 },

	.{ mask = "0000_00..", f = #run binary_op_rm_r(T = ADD) },
	.{ mask = "0000_010.", f = #run binary_op_imm_acc(T = ADD) },

	.{ mask = "0001_00..", f = #run binary_op_rm_r(T = ADC) },
	.{ mask = "0001_010.", f = #run binary_op_imm_acc(T = ADC) },

	.{ mask = "0010_10..", f = #run binary_op_rm_r(T = SUB) },
	.{ mask = "0010_110.", f = #run binary_op_imm_acc(T = SUB) },

	.{ mask = "0001_10..", f = #run binary_op_rm_r(T = SBB) },
	.{ mask = "0001_110.", f = #run binary_op_imm_acc(T = SBB) },

	.{ mask = "0011_10..", f = #run binary_op_rm_r(T = CMP) },
	.{ mask = "0011_110.", f = #run binary_op_imm_acc(T = CMP) },

	.{ mask = "0010_00..", f = #run binary_op_rm_r(T = AND) },
	.{ mask = "0010_010.", f = #run binary_op_imm_acc(T = AND) },

	.{ mask = "1000_01..", f = #run binary_op_rm_r(T = TEST) },
	.{ mask = "1010_100.", f = #run binary_op_imm_acc(T = TEST) },

	.{ mask = "0000_10..", f = #run binary_op_rm_r(T = OR) },
	.{ mask = "0000_110.", f = #run binary_op_imm_acc(T = OR) },

	.{ mask = "0011_00..", f = #run binary_op_rm_r(T = XOR) },
	.{ mask = "0011_010.", f = #run binary_op_imm_acc(T = XOR) },

	.{ mask = "0111_0100", f = #run cjmp(T = JE) },
	.{ mask = "0111_1100", f = #run cjmp(T = JL) },
	.{ mask = "0111_1110", f = #run cjmp(T = JLE) },
	.{ mask = "0111_0010", f = #run cjmp(T = JB) },
	.{ mask = "0111_0110", f = #run cjmp(T = JBE) },
	.{ mask = "0111_1010", f = #run cjmp(T = JP) },
	.{ mask = "0111_0000", f = #run cjmp(T = JO) },
	.{ mask = "0111_1000", f = #run cjmp(T = JS) },
	.{ mask = "0111_0101", f = #run cjmp(T = JNZ) },
	.{ mask = "0111_1101", f = #run cjmp(T = JGE) },
	.{ mask = "0111_1111", f = #run cjmp(T = JG) },
	.{ mask = "0111_0011", f = #run cjmp(T = JNB) },
	.{ mask = "0111_0111", f = #run cjmp(T = JA) },
	.{ mask = "0111_1011", f = #run cjmp(T = JNP) },
	.{ mask = "0111_0001", f = #run cjmp(T = JNO) },
	.{ mask = "0111_1001", f = #run cjmp(T = JNS) },
	.{ mask = "1110_0010", f = #run cjmp(T = LOOP) },
	.{ mask = "1110_0001", f = #run cjmp(T = LOOPZ) },
	.{ mask = "1110_0000", f = #run cjmp(T = LOOPNZ) },
	.{ mask = "1110_0011", f = #run cjmp(T = JCXZ) },

	.{ mask = "1000_1111", f = pop_rm },

	.{ mask = "0101_0...", f = push_r },
	.{ mask = "000._.110", f = push_sr },

	.{ mask = "0101_1...", f = pop_r },
	.{ mask = "000._.111", f = pop_sr },

	.{ mask = "1000_011.", f = #run binary_op_rm_r(T = XCHG, USE_D = false) },
	.{ mask = "1001_0...", f = #run binary_r_acc(T = XCHG) },

	.{ mask = "1110_010.", f = #run io_acc_imm(T = IN) },
	.{ mask = "1110_110.", f = #run io_acc_r(T = IN) },
	
	.{ mask = "1110_011.", f = #run io_acc_imm(T = OUT, D = 1) },
	.{ mask = "1110_111.", f = #run io_acc_r(T = OUT, D = 1) },

	.{ mask = "1101_0111", f = #run nullary(T = XLAT) },

	.{ mask = "1000_1101", f = #run binary_op_rm_r(T = LEA, USE_D = false, DD = 1) },
	.{ mask = "1100_0101", f = #run binary_op_rm_r(T = LDS, USE_D = false, DD = 1) },
	.{ mask = "1100_0100", f = #run binary_op_rm_r(T = LES, USE_D = false, DD = 1) },

	.{ mask = "1001_1111", f = #run nullary(T = LAHF) },
	.{ mask = "1001_1110", f = #run nullary(T = SAHF) },
	.{ mask = "1001_1100", f = #run nullary(T = PUSHF) },
	.{ mask = "1001_1101", f = #run nullary(T = POPF) },

	.{ mask = "0100_0...", f = #run unary_r(T = INC) },
	.{ mask = "0100_1...", f = #run unary_r(T = DEC) },

	.{ mask = "0011_0111", f = #run nullary(T = AAA) },
	.{ mask = "0010_0111", f = #run nullary(T = DAA) },

	.{ mask = "0011_1111", f = #run nullary(T = AAS) },
	.{ mask = "0010_1111", f = #run nullary(T = DAS) },

	.{ mask = "1101_0100", f = #run nullary(T = AAM, EAT_2 = true) },
	.{ mask = "1101_0101", f = #run nullary(T = AAD, EAT_2 = true) },

	.{ mask = "1001_1000", f = #run nullary(T = CBW) },
	.{ mask = "1001_1001", f = #run nullary(T = CWD) },

];
templates_grp1 :: Template.[
	.{ mask = "..00_0...", f = #run binary_op_imm_rm(T = TEST) },
	// .{ mask = "..00_1...", f = #run unary_rm(T = DEC) },
	.{ mask = "..01_0...", f = #run unary_rm(T = NOT) },
	.{ mask = "..01_1...", f = #run unary_rm(T = NEG) },
	.{ mask = "..10_0...", f = #run unary_rm(T = MUL) },
	.{ mask = "..10_1...", f = #run unary_rm(T = IMUL) },
	.{ mask = "..11_0...", f = #run unary_rm(T = DIV) },
	.{ mask = "..11_1...", f = #run unary_rm(T = IDIV) },
];
templates_grp2 :: Template.[
	.{ mask = "..00_0...", f = #run unary_rm(T = INC) },
	.{ mask = "..00_1...", f = #run unary_rm(T = DEC) },
	// .{ mask = "..01_0...", f = null },
	// .{ mask = "..01_1...", f = null },
	// .{ mask = "..10_0...", f = null },
	// .{ mask = "..10_1...", f = null },
	.{ mask = "..11_0...", f = push_rm },
	// .{ mask = "..11_1...", f = null },
];
templates_immed :: Template.[
	.{ mask = "..00_0...", f = #run binary_op_imm_rm(T = ADD) },
	.{ mask = "..00_1...", f = #run binary_op_imm_rm(T = OR) },
	.{ mask = "..01_0...", f = #run binary_op_imm_rm(T = ADC) },
	.{ mask = "..01_1...", f = #run binary_op_imm_rm(T = SBB) },
	.{ mask = "..10_0...", f = #run binary_op_imm_rm(T = AND) },
	.{ mask = "..10_1...", f = #run binary_op_imm_rm(T = SUB) },
	.{ mask = "..11_0...", f = #run binary_op_imm_rm(T = XOR) },
	.{ mask = "..11_1...", f = #run binary_op_imm_rm(T = CMP) }
];
templates_shift :: Template.[
	.{ mask = "..00_0...", f = #run shift_op(T = ROL) },
	.{ mask = "..00_1...", f = #run shift_op(T = ROR) },
	.{ mask = "..01_0...", f = #run shift_op(T = RCL) },
	.{ mask = "..01_1...", f = #run shift_op(T = RCR) },
	.{ mask = "..10_0...", f = #run shift_op(T = SHL) },
	.{ mask = "..10_1...", f = #run shift_op(T = SHR) },
	// .{ mask = "..11_0...", f = push_rm },
	.{ mask = "..11_1...", f = #run shift_op(T = SAR) },
];

#scope_export

Reg :: enum {
	AL :: 0;
	AX :: 1;
	CL :: 2;
	CX :: 3;
	DL :: 4;
	DX :: 5;
	BL :: 6;
	BX :: 7;
	AH :: 8;
	SP :: 9;
	CH :: 10;
	BP :: 11;
	DH :: 12;
	SI :: 13;
	BH :: 14;
	DI :: 15;
	ES :: 16;
	CS :: 17;
	SS :: 18;
	DS :: 19;
};

Cea :: enum {
	BX_SI :: 0;
	BX_DI :: 1;
	BP_SI :: 2;
	BP_DI :: 3;
	SI :: 4;
	DI :: 5;
	BP :: 6;
	BX :: 7;
};
Direct_Address :: #type,distinct u16;

Nullary_Op :: struct { }

Binary_Op :: struct {
	src: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);
	dst: Tagged_Union(Reg, Cea, Direct_Address, u8);

	disp: s16;
}

Conditional_Jump :: struct {
	delta: s8;
}

Unary_Op :: struct {
	op: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);

	wide := false;
	disp: s16;
}

Shift_Op :: struct {
	src: Tagged_Union(Reg, u8);
	dst: Tagged_Union(Reg, Cea, Direct_Address);

	wide := false;
	disp: s16;
}

MOV :: struct { #as using base: Binary_Op; name :: "mov"; }
ADD :: struct { #as using base: Binary_Op; name :: "add"; }
ADC :: struct { #as using base: Binary_Op; name :: "adc"; }
SUB :: struct { #as using base: Binary_Op; name :: "sub"; }
SBB :: struct { #as using base: Binary_Op; name :: "sbb"; }
CMP :: struct { #as using base: Binary_Op; name :: "cmp"; }
XCHG :: struct { #as using base: Binary_Op; name :: "xchg"; }
IN :: struct { #as using base: Binary_Op; name :: "in"; };
OUT :: struct { #as using base: Binary_Op; name :: "out"; };
LEA :: struct { #as using base: Binary_Op; name :: "lea"; };
LDS :: struct { #as using base: Binary_Op; name :: "lds"; };
LES :: struct { #as using base: Binary_Op; name :: "les"; };
AND :: struct { #as using base: Binary_Op; name :: "and"; };
TEST :: struct { #as using base: Binary_Op; name :: "test"; };
OR :: struct { #as using base: Binary_Op; name :: "or"; };
XOR :: struct { #as using base: Binary_Op; name :: "xor"; };

PUSH :: struct { #as using base: Unary_Op; name :: "push"; };
POP :: struct { #as using base: Unary_Op; name :: "pop"; };
INC :: struct { #as using base: Unary_Op; name :: "inc"; };
DEC :: struct { #as using base: Unary_Op; name :: "dec"; };
NEG :: struct { #as using base: Unary_Op; name :: "neg"; };
MUL :: struct { #as using base: Unary_Op; name :: "mul"; };
IMUL :: struct { #as using base: Unary_Op; name :: "imul"; };
DIV :: struct { #as using base: Unary_Op; name :: "div"; };
IDIV :: struct { #as using base: Unary_Op; name :: "idiv"; };
NOT :: struct { #as using base: Unary_Op; name :: "not"; };

JE :: struct { #as using base: Conditional_Jump; name :: "je"; }
JL :: struct { #as using base: Conditional_Jump; name :: "jl"; }
JLE :: struct { #as using base: Conditional_Jump; name :: "jle"; }
JB :: struct { #as using base: Conditional_Jump; name :: "jb"; }
JBE :: struct { #as using base: Conditional_Jump; name :: "jbe"; }
JP :: struct { #as using base: Conditional_Jump; name :: "jp"; }
JO :: struct { #as using base: Conditional_Jump; name :: "jo"; }
JS :: struct { #as using base: Conditional_Jump; name :: "js"; }
JNZ :: struct { #as using base: Conditional_Jump; name :: "jnz"; }
JGE :: struct { #as using base: Conditional_Jump; name :: "jge"; }
JG :: struct { #as using base: Conditional_Jump; name :: "jg"; }
JNB :: struct { #as using base: Conditional_Jump; name :: "jnb"; }
JA :: struct { #as using base: Conditional_Jump; name :: "ja"; }
JNP :: struct { #as using base: Conditional_Jump; name :: "jnp"; }
JNO :: struct { #as using base: Conditional_Jump; name :: "jno"; }
JNS :: struct { #as using base: Conditional_Jump; name :: "jns"; }
LOOP :: struct { #as using base: Conditional_Jump; name :: "loop"; }
LOOPZ :: struct { #as using base: Conditional_Jump; name :: "loopz"; }
LOOPNZ :: struct { #as using base: Conditional_Jump; name :: "loopnz"; }
JCXZ :: struct { #as using base: Conditional_Jump; name :: "jcxz"; }

XLAT :: struct { #as using base: Nullary_Op; name :: "xlat"; }
LAHF :: struct { #as using base: Nullary_Op; name :: "lahf"; }
SAHF :: struct { #as using base: Nullary_Op; name :: "sahf"; }
PUSHF :: struct { #as using base: Nullary_Op; name :: "pushf"; }
POPF :: struct { #as using base: Nullary_Op; name :: "popf"; }
AAA :: struct { #as using base: Nullary_Op; name :: "aaa"; }
DAA :: struct { #as using base: Nullary_Op; name :: "daa"; }
AAS :: struct { #as using base: Nullary_Op; name :: "aas"; }
DAS :: struct { #as using base: Nullary_Op; name :: "das"; }
AAM :: struct { #as using base: Nullary_Op; name :: "aam"; }
AAD :: struct { #as using base: Nullary_Op; name :: "aad"; }
CBW :: struct { #as using base: Nullary_Op; name :: "cbw"; }
CWD :: struct { #as using base: Nullary_Op; name :: "cwd"; }

SHL :: struct { #as using base: Shift_Op; name :: "shl"; }
SHR :: struct { #as using base: Shift_Op; name :: "shr"; }
SAR :: struct { #as using base: Shift_Op; name :: "sar"; }
ROL :: struct { #as using base: Shift_Op; name :: "rol"; }
ROR :: struct { #as using base: Shift_Op; name :: "ror"; }
RCL :: struct { #as using base: Shift_Op; name :: "rcl"; }
RCR :: struct { #as using base: Shift_Op; name :: "rcr"; }

Instruction :: Tagged_Union(
	PUSH, POP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV, NOT,
	MOV, ADD, ADC, SUB, SBB, CMP, XCHG, IN, OUT, LEA, LDS, LES, AND, TEST, OR, XOR,
	JE, JL, JLE, JB, JBE, JP, JO, JS, JNZ, JGE, JG, JNB, JA, JNP, JNO, JNS, LOOP, LOOPZ, LOOPNZ,
		JCXZ,
	XLAT, LAHF, SAHF, PUSHF, POPF, AAA, DAA, AAS, DAS, AAM, AAD, CBW, CWD,
	SHL, SHR, SAR, ROL, ROR, RCL, RCR,
);

shift_op :: ($T: Type) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;

		if stream.count < 2
			return wrap(op), false;

		s0 := next_u8(stream);
		s1 := next_u8(stream);
	
		V := (s0 & 0b0000_0010) >> 1;
		W := (s0 & 0b0000_0001);
		op.wide = ifx W then true else false;

		MOD := (s1 & 0b1100_0000) >> 6;
		RM := (s1 & 0b0000_0111);

		disp, direct_addr, mod_reg := decode_mod_rm(MOD, RM);

		if V set(*op.src, Reg.CL);
		else set(*op.src, cast(u8) 1);
		if mod_reg {
			set(*op.dst, cast(Reg) (2 * RM + W));
		} else if direct_addr {
			set(*op.dst, cast(Direct_Address) next_u16(stream));
		} else {
			set(*op.dst, cast(Cea) RM);
			if disp == 8
				op.disp = next_u8(stream);
			if disp == 16
				op.disp = cast, no_check(s16) next_u16(stream);
		}
		return wrap(op), true;
	};
}

binary_op_imm_acc :: ($T: Type) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;

		if stream.count < 2
			return wrap(op), false;

		s0 := next_u8(stream);
		W := s0 & 0b0000_0001;

		set(*op.dst, cast(Reg) (W + 2 * 0));
		if W == 0 {
			set(*op.src, next_u8(stream));
		} else {
			if stream.count < 1
				return wrap(op), false;
			set(*op.src, next_u16(stream));
		}

		return wrap(op), true;
	};
}
binary_op_imm_rm :: ($T: Type, $USE_S := true) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;
		
		if stream.count < 3
			return wrap(op), false;
		
		s0 := next_u8(stream);
		s1 := next_u8(stream);

		#if USE_S
			S := (s0 & 0b0000_0010) >> 1;
		else
			S := 0;

		W := (s0 & 0b0000_0001) >> 0;

		MOD := (s1 & 0b1100_0000) >> 6;
		RM := (s1 & 0b0000_0111) >> 0;
		
		disp, direct_addr, mod_reg := decode_mod_rm(MOD, RM);

		if mod_reg {
			set(*op.dst, cast(Reg) (W + 2 *  RM));
		} else {
			if direct_addr {
				set(*op.dst, cast(Direct_Address) next_u16(stream));
			} else {
				set(*op.dst, cast(Cea) RM);
			}

			if disp == 8
			{
				op.disp = next_u8(stream);
				if op.disp & 0b1000_0000
					op.disp |= 0b1111_1111_0000_0000;
			}
			if disp == 16
				op.disp = cast, no_check(s16) next_u16(stream);
		}

		if S == 0 {
			if W == 0 {
				if stream.count < 1
					return wrap(op), false;
				set(*op.src, next_u8(stream));
			} else {
				if stream.count < 2
					return wrap(op), false;
				set(*op.src, next_u16(stream));
			}
		} else {
			if W == 0 {
				if stream.count < 1
					return wrap(op), false;
				set(*op.src, next_u8(stream));
			} else {
				if stream.count < 1
					return wrap(op), false;
				data := cast(u16) next_u8(stream);
				if data & 0b0000_0000_1000_0000
					data |= 0b1111_1111_0000_0000;

				set(*op.src, data);
			}
		}

		return wrap(op), true;
	};
}
binary_op_rm_r :: ($T: Type, $USE_D : bool = true, $DD := 0) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;

		if stream.count < 2
			return wrap(op), false;

		s0 := next_u8(stream);
		s1 := next_u8(stream);

		#if USE_D
			D := (s0 & 0b0000_0010) >> 1;
		else
			D := DD;
		W := (s0 & 0b0000_0001) >> 0;

		MOD := (s1 & 0b1100_0000) >> 6;
		REG := (s1 & 0b0011_1000) >> 3;
		RM := (s1 & 0b0000_0111) >> 0;

		disp, direct_addr, mod_reg := decode_mod_rm(MOD, RM);

		if mod_reg {
			if D == 0 {
				set(*op.src, cast(Reg) (W + 2 * REG));
				set(*op.dst, cast(Reg) (W + 2 *  RM));
			}
			if D == 1 {
				set(*op.src, cast(Reg) (W + 2 *  RM));
				set(*op.dst, cast(Reg) (W + 2 * REG));
			}
		} else {
			if D == 0 {
				set(*op.src, cast(Reg) (W + 2 * REG));
				if direct_addr {
					set(*op.dst, cast(Direct_Address) next_u16(stream));
				} else {
					set(*op.dst, cast(Cea) RM);
				}
			} else {
				set(*op.dst, cast(Reg) (W + 2 * REG));
				if direct_addr {
					set(*op.src, cast(Direct_Address) next_u16(stream));
				} else {
					set(*op.src, cast(Cea) RM);
				}
			}

			if disp == 8
			{
				op.disp = next_u8(stream);
				if op.disp & 0b1000_0000
					op.disp |= 0b1111_1111_0000_0000;
			}
			if disp == 16
				op.disp = cast, no_check(s16) next_u16(stream);
		}

		return wrap(op), true;
	};
}

decode_mod_rm :: (MOD: u8, RM: u8) -> u8, bool, bool {
	disp: u8;
	direct_addr := false;
	mod_reg := false;
	
	if MOD == {
		case 0b00;
			if RM == 0b110 {
				direct_addr = true;
			}
		case 0b01;
			disp = 8;
		case 0b10;
			disp = 16;
		case 0b11;
			mod_reg = true;
	}

	return disp, direct_addr, mod_reg;
}

binary_r_acc :: ($T: Type) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;

		if stream.count < 1
			return wrap(op), false;

		s0 := next_u8(stream);

		REG := s0 & 0b0000_0111;

		set(*op.src, cast(Reg) REG);
		set(*op.dst, Reg.AX);

		return wrap(op), true;
	};
}

unary_rm :: ($T: Type, $USE_W := true, $WW := 0) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;

		if stream.count < 2
			return wrap(op), false;

		s0 := next_u8(stream);
		s1 := next_u8(stream);

		#if USE_W 
			W := (s0 & 0b0000_0001) >> 0;
		else
			W := WW;
		op.wide = ifx W > 0 then true else false;

		MOD := (s1 & 0b1100_0000) >> 6;
		RM := (s1 & 0b0000_0111) >> 0;

		disp, direct_addr, mod_reg := decode_mod_rm(MOD, RM);
		if mod_reg {
			set(*op.op, cast(Reg) (2 * RM + W));
			return wrap(op), true;
		} else if direct_addr {
			set(*op.op, cast(Direct_Address) next_u16(stream));
		} else {
			set(*op.op, cast(Cea) RM);
			if disp == 8
				op.disp = next_u8(stream);
			if disp == 16
				op.disp = cast, no_check(s16) next_u16(stream);
		}

		return wrap(op), true;
	};
}


unary_r :: ($T: Type) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;

		if stream.count < 1
			return wrap(op), false;

		s0 := next_u8(stream);

		REG := (s0 & 0b0000_0111) >> 0;

		set(*op.op, cast(Reg) (2 * REG + 1));

		return wrap(op), true;
	};
}


io_acc_imm :: ($T: Type, $D := 0) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		in: T;

		if stream.count < 2
			return wrap(in), false;

		s0 := next_u8(stream);
		s1 := next_u8(stream);

		W := (s0 & 0b0000_0001) >> 0;

		if W == 0 {
			set(*in.dst, cast(Reg) Reg.AL);
		} else {
			set(*in.dst, cast(Reg) Reg.AX);
		}

		set(*in.src, cast(u8) s1);

		#if D {
			t: Instruction;
			memcpy(*t, *in.src, size_of(Instruction));
			memcpy(*in.src, *in.dst, size_of(Instruction));
			memcpy(*in.dst, *t, size_of(Instruction));
		}

		return wrap(in), true;
	};
}

io_acc_r :: ($T: Type, $D := 0) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		in: T;

		if stream.count < 1
			return wrap(in), false;

		s0 := next_u8(stream);

		W := (s0 & 0b0000_0001) >> 0;

		if W == 0 {
			set(*in.dst, cast(Reg) Reg.AL);
		} else {
			set(*in.dst, cast(Reg) Reg.AX);
		}

		set(*in.src, cast(Reg) Reg.DX);
		
		#if D {
			t: Instruction;
			memcpy(*t, *in.src, size_of(Instruction));
			memcpy(*in.src, *in.dst, size_of(Instruction));
			memcpy(*in.dst, *t, size_of(Instruction));
		}

		return wrap(in), true;
	};
}

nullary :: ($T: Type, $EAT_2 := false) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		op: T;
		#if EAT_2
			if stream.count < 2
				return wrap(op), false;
		else
			if stream.count < 1
				return wrap(op), false;
		s0 := next_u8(stream);
		#if EAT_2
			s1 := next_u8(stream);
		return wrap(op), true;
	};
}

push_rm :: (stream: *[] u8) -> Instruction, bool {
	if stream.count < 2
		return .{}, false;
	
	push: PUSH;
	push.wide = true;
	s0 := next_u8(stream);
	s1 := next_u8(stream);

	MOD := (s1 & 0b1100_0000) >> 6;
	RM := (s1 & 0b0000_0111) >> 0;

	disp, direct_addr, mod_reg := decode_mod_rm(MOD, RM);

	if mod_reg {
		set(*push.op, cast(Reg) (1 + 2 *  RM));
	} else {
		if direct_addr {
			set(*push.op, cast(Direct_Address) next_u16(stream));
		} else {
			set(*push.op, cast(Cea) RM);
		}

		if disp == 8
		{
			push.disp = next_u8(stream);
			if push.disp & 0b1000_0000
				push.disp |= 0b1111_1111_0000_0000;
		}
		if disp == 16
			push.disp = cast, no_check(s16) next_u16(stream);
	}

	return wrap(push), true;
}
push_r :: (stream: *[] u8) -> Instruction, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0000_0111);

	push: PUSH;
	push.wide = true;
	set(*push.op, cast(Reg) (1 + 2 * REG));

	return wrap(push), true;
}
push_sr :: (stream: *[] u8) -> Instruction, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0001_1000) >> 3;

	push: PUSH;
	push.wide = true;
	set(*push.op, cast(Reg) (REG + cast(u8) Reg.SS));
	return wrap(push), true;
}

pop_rm :: (stream: *[] u8) -> Instruction, bool {
	if stream.count < 2
		return .{}, false;
	
	pop: POP;
	pop.wide = true;
	s0 := next_u8(stream);
	s1 := next_u8(stream);

	MOD := (s1 & 0b1100_0000) >> 6;
	RM := (s1 & 0b0000_0111) >> 0;

	disp, direct_addr, mod_reg := decode_mod_rm(MOD, RM);

	if mod_reg {
		set(*pop.op, cast(Reg) (1 + 2 *  RM));
	} else {
		if direct_addr {
			set(*pop.op, cast(Direct_Address) next_u16(stream));
		} else {
			set(*pop.op, cast(Cea) RM);
		}

		if disp == 8
		{
			pop.disp = next_u8(stream);
			if pop.disp & 0b1000_0000
				pop.disp |= 0b1111_1111_0000_0000;
		}
		if disp == 16
			pop.disp = cast, no_check(s16) next_u16(stream);
	}

	return wrap(pop), true;
}
pop_r :: (stream: *[] u8) -> Instruction, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0000_0111);

	pop: POP;
	pop.wide = true;
	set(*pop.op, cast(Reg) (1 + 2 * REG));

	return wrap(pop), true;
}
pop_sr :: (stream: *[] u8) -> Instruction, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0001_1000) >> 3;

	pop: POP;
	pop.wide = true;
	set(*pop.op, cast(Reg) (REG + cast(u8) Reg.ES));
	return wrap(pop), true;
}


mov_mem_acc :: () -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		mov: MOV;

		if stream.count < 3
			return wrap(mov), false;

		s0 := next_u8(stream);

		W := (s0 & 0b0000_0001) >> 0;

		if W {
			set(*mov.dst, Reg.AX);
		} else {
			set(*mov.dst, Reg.AL);
		}

		set(*mov.src, cast(Direct_Address) next_u16(stream));

		return wrap(mov), true;
	};
}

mov_acc_mem :: () -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		mov: MOV;

		if stream.count < 3
			return wrap(mov), false;

		s0 := next_u8(stream);

		W := (s0 & 0b0000_0001) >> 0;

		if W {
			set(*mov.src, Reg.AX);
		} else {
			set(*mov.src, Reg.AL);
		}

		set(*mov.dst, cast(Direct_Address) next_u16(stream));

		return wrap(mov), true;
	};
}

mov_imm_r :: () -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		mov: MOV;

		if stream.count < 2
			return wrap(mov), false;

		s0 := next_u8(stream);

		W := (s0 & 0b0000_1000) >> 3;
		REG := s0 & 0b0000_0111;

		if W && stream.count < 1
			return wrap(mov), false;

		set(*mov.dst, cast(Reg) (W + 2 * REG));

		if W {
			set(*mov.src, next_u16(stream));
		} else {
			set(*mov.src, next_u8(stream));
		}

		return wrap(mov), true;
	};
}

cjmp :: ($T: Type) -> Table_Entry_F {
	return (stream: *[] u8) -> Instruction, bool {
		if stream.count < 2
			return .{}, false;
		
		_ := next_u8(stream);

		op: T;
		op.delta = cast, no_check (s8) next_u8(stream);
		return wrap(op), true;
	};
}

Table_Entry_F :: #type (stream: *[] u8) -> Instruction, bool;
wrap :: (op: $Type) -> Instruction {
	inst: Instruction;
	set(*inst, op);
	return inst;
}

decode_grp2 :: (stream: *[] u8) -> Instruction, bool {
	jmp_table :: #run -> [256] Table_Entry_F {
		table: [256] Table_Entry_F;
		for templates_grp2 {
			for i: 0..255 {
				if match_mask(cast(u8) i, it.mask) {
					table[i] = it.f;
				}
			}
		}

		return table;
	};

	if stream.count < 2
		return .{}, false;
	a, b := jmp_table[stream.data[1]](stream);
	return a, b;
}
decode_grp1 :: (stream: *[] u8) -> Instruction, bool {
	jmp_table :: #run -> [256] Table_Entry_F {
		table: [256] Table_Entry_F;
		for templates_grp1 {
			for i: 0..255 {
				if match_mask(cast(u8) i, it.mask) {
					table[i] = it.f;
				}
			}
		}

		return table;
	};

	if stream.count < 2
		return .{}, false;
	a, b := jmp_table[stream.data[1]](stream);
	return a, b;
}

decode_immed :: (stream: *[] u8) -> Instruction, bool {
	jmp_table :: #run -> [256] Table_Entry_F {
		table: [256] Table_Entry_F;
		for templates_immed {
			for i: 0..255 {
				if match_mask(cast(u8) i, it.mask) {
					table[i] = it.f;
				}
			}
		}

		return table;
	};

	if stream.count < 2
		return .{}, false;
	a, b := jmp_table[stream.data[1]](stream);
	return a, b;
}

decode_shift :: (stream: *[] u8) -> Instruction, bool {
	jmp_table :: #run -> [256] Table_Entry_F {
		table: [256] Table_Entry_F;
		for templates_shift {
			for i: 0..255 {
				if match_mask(cast(u8) i, it.mask) {
					table[i] = it.f;
				}
			}
		}

		return table;
	};

	if stream.count < 2
		return .{}, false;
	a, b := jmp_table[stream.data[1]](stream);
	return a, b;
}

decode_instruction :: (stream: *[] u8) -> Instruction, bool {
	jmp_table_f :: () -> [256] Table_Entry_F {
		table: [256] Table_Entry_F;
		for * table { <<it = null; }

		for templates_base {
			for i: 0..255 {
				if match_mask(cast(u8) i, it.mask) {
					table[i] = it.f;
				}
			}
		}

		return table;
	};
	jmp_table :: #run jmp_table_f();

	if stream.count < 1
		return .{}, false;

	a, b := jmp_table[stream.data[0]](stream);
	return a, b;
}


next :: (stream: *[] u8) -> Instruction, bool {
	ret: Instruction = ---;

	if stream.count == 0
		return ret, false;

	a, b := decode_instruction(stream);
	return a, b;
}

serialize :: (cea: Cea) -> string {
	if cea == {
		case .BX_SI; return "BX + SI";
		case .BX_DI; return "BX + DI";
		case .BP_SI; return "BP + SI";
		case .BP_DI; return "BP + DI";
		case .SI; return "SI";
		case .DI; return "DI";
		case .BP; return "BP";
		case .BX; return "BX";
	}
	return "??";
}

print :: (op: $T/Binary_Op) {
	dst_memory := false;

	print("% ", op.name);
	while dst := isa(op.dst, Reg) {
		print("%", <<dst);
		break;
	}
	while dst := isa(op.dst, Cea) {
		dst_memory = true;

		if isa(op.src, u8)
			print("byte ");
		if isa(op.src, u16)
			print("word ");

		print("[%", serialize(<<dst));
		if op.disp != 0 {
			if op.disp > 0 print(" + %", op.disp);
			if op.disp < 0 print(" - %", -op.disp);
		}
		print("]");
		break;
	}
	while dst := isa(op.dst, Direct_Address) {
		if isa(op.src, u8)
			print("byte ");
		if isa(op.src, u16)
			print("word ");

		dst_memory = true;
		print("[%]", <<dst);
		break;
	}
	while dst := isa(op.dst, u8) {
		print("%", <<dst);
		break;
	}
	print(", ");
	while src := isa(op.src, Reg) {
		print("%", <<src);
		break;
	}
	while src := isa(op.src, Cea) {
		print("[%", serialize(<<src));
		if op.disp != 0 {
			if op.disp > 0 print(" + %", op.disp);
			if op.disp < 0 print(" - %", -op.disp);
		}
		print("]");
		break;
	}
	while src := isa(op.src, Direct_Address) {
		print("[%]", <<src);
		break;
	}
	while src := isa(op.src, u16) {
		if dst_memory
			print("word ");
		print("%", <<src);
		break;
	}
	while src := isa(op.src, u8) {
		if dst_memory
			print("byte ");
		print("%", <<src);
		break;
	}
}

print :: (op: $T/Conditional_Jump) {
	print("% $", op.name);
	if op.delta >= -2 print(" + %", op.delta + 2);
	else print(" - %", -(op.delta + 2));
}

print :: (op: $T/Unary_Op) {
	print("% ", op.name);
	while reg := isa(op.op, Reg) {
		print("%", <<reg);
		break;
	}
	while reg := isa(op.op, Cea) {
		if op.wide print("word ");
		else       print("byte ");
		
		print("[%", serialize(<<reg));
		if op.disp != 0 {
			if op.disp > 0 print(" + %", op.disp);
			if op.disp < 0 print(" - %", -op.disp);
		}
		print("]");
		break;
	}
	while reg := isa(op.op, Direct_Address) {
		if op.wide print("word ");
		else       print("byte ");
		print("[%]", <<reg);
		break;
	}
}

print :: (op: $T/Shift_Op) {
	print("% ", op.name);
	while reg := isa(op.dst, Reg) {
		print("%", <<reg);
		break;
	}
	while reg := isa(op.dst, Cea) {
		if op.wide print("word ");
		else       print("byte ");
		
		print("[%", serialize(<<reg));
		if op.disp != 0 {
			if op.disp > 0 print(" + %", op.disp);
			if op.disp < 0 print(" - %", -op.disp);
		}
		print("]");
		break;
	}
	while reg := isa(op.dst, Direct_Address) {
		if op.wide print("word ");
		else       print("byte ");
		print("[%]", <<reg);
		break;
	}
	print(", ");
	while reg := isa(op.src, Reg) {
		print("%", <<reg);
		break;
	}
	while reg := isa(op.src, u8) {
		print("%", <<reg);
		break;
	}
}

print :: (op: $T/Nullary_Op) {
	print("%", op.name);
}

print :: (inst: Instruction) {
	#insert #run -> string {
		str := "";
		for inst.value_types {
			str = tprint("%\nwhile op := isa(inst, %) {\n defer break;\n print(<<op);\n}", str, it);
		}
		return str;
	};
}