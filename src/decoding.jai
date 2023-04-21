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

#scope_export

ARITHMETIC_CODE :: enum {
	ADD :: 0b000;
	SUB :: 0b101;
	CMP :: 0b111;
}


Arg :: enum {
	REG;
	IMM;
	CEA;
};

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

Binary_Op :: struct {
	src: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);
	dst: Tagged_Union(Reg, Cea, Direct_Address);

	disp: s16;
}

Conditional_Jump :: struct {
	delta: s8;
}

Unary_Op :: struct {
	op: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);

	disp: s16;
}

MOV :: struct { #as using base: Binary_Op; name :: "mov"; }
ADD :: struct { #as using base: Binary_Op; name :: "add"; }
SUB :: struct { #as using base: Binary_Op; name :: "sub"; }
CMP :: struct { #as using base: Binary_Op; name :: "cmp"; }

PUSH :: struct { #as using base: Unary_Op; name :: "push"; };
POP :: struct { #as using base: Unary_Op; name :: "pop"; };

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

Instruction :: Tagged_Union(
	PUSH, POP,
	MOV, ADD, SUB, CMP,
	JE, JL, JLE, JB, JBE, JP, JO, JS, JNZ, JGE, JG, JNB, JA, JNP, JNO, JNS, LOOP, LOOPZ, LOOPNZ,
		JCXZ
);

binary_op_imm_acc :: (stream: *[] u8, $T: Type) -> T, bool {
	op: T;

	if stream.count < 2
		return op, false;

	s0 := next_u8(stream);
	W := s0 & 0b0000_0001;

	set(*op.dst, cast(Reg) (W + 2 * 0));
	if W == 0 {
		set(*op.src, next_u8(stream));
	} else {
		if stream.count < 1
			return op, false;
		set(*op.src, next_u16(stream));
	}

	return op, true;
}
binary_op_imm_rm :: (stream: *[] u8, $T: Type) -> T, bool {
	op: T;
	
	if stream.count < 3
		return op, false;
	
	s0 := next_u8(stream);
	s1 := next_u8(stream);

	S := (s0 & 0b0000_0010) >> 1;

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
				return op, false;
			set(*op.src, next_u8(stream));
		} else {
			if stream.count < 2
				return op, false;
			set(*op.src, next_u16(stream));
		}
	} else {
		if W == 0 {
			if stream.count < 1
				return op, false;
			set(*op.src, next_u8(stream));
		} else {
			if stream.count < 1
				return op, false;
			data := cast(u16) next_u8(stream);
			if data & 0b0000_0000_1000_0000
				data |= 0b1111_1111_0000_0000;

			set(*op.src, data);
		}
	}

	return op, true;
}
binary_op_imm_rm_no_s :: (stream: *[] u8, $T: Type) -> T, bool {
	op: T;
	
	if stream.count < 3
		return op, false;
	
	s0 := next_u8(stream);
	s1 := next_u8(stream);

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
				return op, false;
			set(*op.src, next_u8(stream));
		} else {
			if stream.count < 2
				return op, false;
			set(*op.src, next_u16(stream));
		}
	} else {
		if W == 0 {
			if stream.count < 1
				return op, false;
			set(*op.src, next_u8(stream));
		} else {
			if stream.count < 1
				return op, false;
			data := cast(u16) next_u8(stream);
			if data & 0b0000_0000_1000_0000
				data |= 0b1111_1111_0000_0000;

			set(*op.src, data);
		}
	}

	return op, true;
}
binary_op_rm_r :: (stream: *[] u8, $T: Type) -> T, bool {
	op: T;

	if stream.count < 2
		return op, false;

	s0 := next_u8(stream);
	s1 := next_u8(stream);

	D := (s0 & 0b0000_0010) >> 1;
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

	return op, true;
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

sub_imm_acc :: #bake_arguments binary_op_imm_acc(T = SUB);
sub_imm_rm :: #bake_arguments binary_op_imm_rm(T = SUB);
sub_rm_r :: #bake_arguments binary_op_rm_r(T = SUB);

add_imm_acc :: #bake_arguments binary_op_imm_acc(T = ADD);
add_imm_rm :: #bake_arguments binary_op_imm_rm(T = ADD);
add_rm_r :: #bake_arguments binary_op_rm_r(T = ADD);

cmp_imm_acc :: #bake_arguments binary_op_imm_acc(T = CMP);
cmp_imm_rm :: #bake_arguments binary_op_imm_rm(T = CMP);
cmp_rm_r :: #bake_arguments binary_op_rm_r(T = CMP);

mov_imm_rm :: #bake_arguments binary_op_imm_rm_no_s(T = MOV);
mov_rm_r :: #bake_arguments binary_op_rm_r(T = MOV);

push_rm :: (stream: *[] u8) -> PUSH, bool {
	if stream.count < 2
		return .{}, false;
	
	push: PUSH;
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

	return push, true;
}
push_r :: (stream: *[] u8) -> PUSH, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0000_0111);

	push: PUSH;
	set(*push.op, cast(Reg) (1 + 2 * REG));

	return push, true;
}
push_sr :: (stream: *[] u8) -> PUSH, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0001_1000) >> 3;

	push: PUSH;
	set(*push.op, cast(Reg) (REG + cast(u8) Reg.SS));
	return push, true;
}

pop_rm :: (stream: *[] u8) -> POP, bool {
	if stream.count < 2
		return .{}, false;
	
	pop: POP;
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

	return pop, true;
}
pop_r :: (stream: *[] u8) -> POP, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0000_0111);

	pop: POP;
	set(*pop.op, cast(Reg) (1 + 2 * REG));

	return pop, true;
}
pop_sr :: (stream: *[] u8) -> POP, bool {
	if stream.count < 1
		return .{}, false;
	
	s0 := next_u8(stream);

	REG := (s0 & 0b0001_1000) >> 3;

	pop: POP;
	set(*pop.op, cast(Reg) (REG + cast(u8) Reg.ES));
	return pop, true;
}


mov_mem_acc :: (stream: *[] u8) -> MOV, bool {
	mov: MOV;

	if stream.count < 3
		return mov, false;

	s0 := next_u8(stream);

	W := (s0 & 0b0000_0001) >> 0;

	if W {
		set(*mov.dst, Reg.AX);
	} else {
		set(*mov.dst, Reg.AL);
	}

	set(*mov.src, cast(Direct_Address) next_u16(stream));

	return mov, true;
}

mov_acc_mem :: (stream: *[] u8) -> MOV, bool {
	mov: MOV;

	if stream.count < 3
		return mov, false;

	s0 := next_u8(stream);

	W := (s0 & 0b0000_0001) >> 0;

	if W {
		set(*mov.src, Reg.AX);
	} else {
		set(*mov.src, Reg.AL);
	}

	set(*mov.dst, cast(Direct_Address) next_u16(stream));

	return mov, true;
}

mov_imm_r :: (stream: *[] u8) -> MOV, bool {
	mov: MOV;

	if stream.count < 2
		return mov, false;

	s0 := next_u8(stream);

	W := (s0 & 0b0000_1000) >> 3;
	REG := s0 & 0b0000_0111;

	if W && stream.count < 1
		return mov, false;

	set(*mov.dst, cast(Reg) (W + 2 * REG));

	if W {
		set(*mov.src, next_u16(stream));
	} else {
		set(*mov.src, next_u8(stream));
	}

	return mov, true;
}

cjmp :: (stream: *[] u8) -> $T, bool {
	if stream.count < 2
		return .{}, false;
	
	_ := next_u8(stream);

	op: T;
	op.delta = cast, no_check (s8) next_u8(stream);
	return op, true;
}

Table_Entry_F :: #type (stream: *[] u8) -> Instruction, bool;
wrap :: (f: #type (stream: *[] u8) -> ($T, bool), stream: *[] u8) -> Instruction, bool {
	a, b := f(stream);
	inst: Instruction;
	set(*inst, a);
	return inst, b;
}

decode_grp2 :: (stream: *[] u8) -> Instruction, bool {
	jmp_table :: #run -> [256] Table_Entry_F {

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
		templates := Template.[
			.{ mask = "..00_0...", f = null },
			.{ mask = "..00_1...", f = null },
			.{ mask = "..01_0...", f = null },
			.{ mask = "..01_1...", f = null },
			.{ mask = "..10_0...", f = null },
			.{ mask = "..10_1...", f = null },
			.{ mask = "..11_0...", f = #bake_arguments wrap(f = push_rm) },
			.{ mask = "..11_1...", f = null },
		];

		table: [256] Table_Entry_F;
		for templates {
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
		templates := Template.[
			.{ mask = "..00_0...", f = #bake_arguments wrap(f = add_imm_rm) },
			.{ mask = "..00_1...", f = null },
			.{ mask = "..01_0...", f = null },
			.{ mask = "..01_1...", f = null },
			.{ mask = "..10_0...", f = null },
			.{ mask = "..10_1...", f = #bake_arguments wrap(f = sub_imm_rm) },
			.{ mask = "..11_0...", f = null },
			.{ mask = "..11_1...", f = #bake_arguments wrap(f = cmp_imm_rm) }
		];

		table: [256] Table_Entry_F;
		for templates {
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

		Template :: struct {
			mask: string;
			f: Table_Entry_F;
		}
		templates := Template.[
			.{ mask = "1000_10..", f = #bake_arguments wrap(f = mov_rm_r) },
			.{ mask = "1100_011.", f = #bake_arguments wrap(f = mov_imm_rm) },
			.{ mask = "1011_....", f = #bake_arguments wrap(f = mov_imm_r) },
			.{ mask = "1010_000.", f = #bake_arguments wrap(f = mov_mem_acc) },
			.{ mask = "1010_001.", f = #bake_arguments wrap(f = mov_acc_mem) },

			.{ mask = "1000_00..", f = decode_immed },
			.{ mask = "1111_111.", f = decode_grp2 },

			.{ mask = "0000_00..", f = #bake_arguments wrap(f = add_rm_r) },
			.{ mask = "0000_010.", f = #bake_arguments wrap(f = add_imm_acc) },

			.{ mask = "0010_10..", f = #bake_arguments wrap(f = sub_rm_r) },
			.{ mask = "0010_110.", f = #bake_arguments wrap(f = sub_imm_acc) },

			.{ mask = "0011_10..", f = #bake_arguments wrap(f = cmp_rm_r) },
			.{ mask = "0011_110.", f = #bake_arguments wrap(f = cmp_imm_acc) },

			.{ mask = "0111_0100", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JE)) },
			.{ mask = "0111_1100", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JL)) },
			.{ mask = "0111_1110", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JLE)) },
			.{ mask = "0111_0010", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JB)) },
			.{ mask = "0111_0110", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JBE)) },
			.{ mask = "0111_1010", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JP)) },
			.{ mask = "0111_0000", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JO)) },
			.{ mask = "0111_1000", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JS)) },
			.{ mask = "0111_0101", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JNZ)) },
			.{ mask = "0111_1101", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JGE)) },
			.{ mask = "0111_1111", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JG)) },
			.{ mask = "0111_0011", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JNB)) },
			.{ mask = "0111_0111", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JA)) },
			.{ mask = "0111_1011", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JNP)) },
			.{ mask = "0111_0001", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JNO)) },
			.{ mask = "0111_1001", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JNS)) },
			.{ mask = "1110_0010", f = #bake_arguments wrap(f = #bake_constants cjmp(T = LOOP)) },
			.{ mask = "1110_0001", f = #bake_arguments wrap(f = #bake_constants cjmp(T = LOOPZ)) },
			.{ mask = "1110_0000", f = #bake_arguments wrap(f = #bake_constants cjmp(T = LOOPNZ)) },
			.{ mask = "1110_0011", f = #bake_arguments wrap(f = #bake_constants cjmp(T = JCXZ)) },

			.{ mask = "1000_1111", f = #bake_arguments wrap(f = pop_rm) },

			.{ mask = "0101_0...", f = #bake_arguments wrap(f = push_r) },
			.{ mask = "000._.110", f = #bake_arguments wrap(f = push_sr) },

			.{ mask = "0101_1...", f = #bake_arguments wrap(f = pop_r) },
			.{ mask = "000._.111", f = #bake_arguments wrap(f = pop_sr) },
		];

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

		for templates {
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

print :: (op: PUSH) {
	print("push ");
	while reg := isa(op.op, Reg) {
		print("%", <<reg);
		break;
	}
	while reg := isa(op.op, Cea) {
		print("word [%", serialize(<<reg));
		if op.disp != 0 {
			if op.disp > 0 print(" + %", op.disp);
			if op.disp < 0 print(" - %", -op.disp);
		}
		print("]");
		break;
	}
	while reg := isa(op.op, Direct_Address) {
		print("word [%]", <<reg);
		break;
	}
}
print :: (op: POP) {
	print("push ");
	while reg := isa(op.op, Reg) {
		print("%", <<reg);
		break;
	}
	while reg := isa(op.op, Cea) {
		print("word [%", serialize(<<reg));
		if op.disp != 0 {
			if op.disp > 0 print(" + %", op.disp);
			if op.disp < 0 print(" - %", -op.disp);
		}
		print("]");
		break;
	}
	while reg := isa(op.op, Direct_Address) {
		print("word [%]", <<reg);
		break;
	}
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