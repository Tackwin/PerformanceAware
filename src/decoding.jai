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

MOV :: struct { using base: Binary_Op; name :: "mov"; }
ADD :: struct { using base: Binary_Op; name :: "add"; }
SUB :: struct { using base: Binary_Op; name :: "sub"; }
CMP :: struct { using base: Binary_Op; name :: "cmp"; }

JNZ :: struct { using base: Conditional_Jump; name :: "jnz"; };
JE :: struct { using base: Conditional_Jump; name :: "je"; };

Instruction :: Tagged_Union(
	MOV, ADD, SUB, CMP, JNZ, JE
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
	
	disp := 0;
	direct_addr := false;
	mod_reg := false;

	if MOD == {
		case 0b00;
			if RM == 0b110 {
				direct_addr = true;
				if stream.count < 2
					return op, false;
			}
		case 0b01;
			disp = 8;
			if stream.count < 1
				return op, false;
		case 0b10;
			disp = 16;
			if stream.count < 2
				return op, false;
		case 0b11;
			mod_reg = true;
	}

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
	
	disp := 0;
	direct_addr := false;
	mod_reg := false;

	if MOD == {
		case 0b00;
			if RM == 0b110 {
				direct_addr = true;
				if stream.count < 2
					return op, false;
			}
		case 0b01;
			disp = 8;
			if stream.count < 1
				return op, false;
		case 0b10;
			disp = 16;
			if stream.count < 2
				return op, false;
		case 0b11;
			mod_reg = true;
	}

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

	disp := 0;
	direct_addr := false;
	mod_reg := false;

	if MOD == {
		case 0b00;
			if RM == 0b110 {
				direct_addr = true;
				if stream.count < 2
					return op, false;
			}
		case 0b01;
			disp = 8;
			if stream.count < 1
				return op, false;
		case 0b10;
			disp = 16;
			if stream.count < 2
				return op, false;
		case 0b11;
			mod_reg = true;
	}

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

Table_Entry_F :: #type (stream: *[] u8) -> Instruction, bool;
wrap :: (f: #type (stream: *[] u8) -> ($T, bool), stream: *[] u8) -> Instruction, bool {
	a, b := f(stream);
	inst: Instruction;
	set(*inst, a);
	return inst, b;
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

			.{ mask = "0000_00..", f = #bake_arguments wrap(f = add_rm_r) },
			.{ mask = "0000_010.", f = #bake_arguments wrap(f = add_imm_acc) },

			.{ mask = "0010_10..", f = #bake_arguments wrap(f = sub_rm_r) },
			.{ mask = "0010_110.", f = #bake_arguments wrap(f = sub_imm_acc) },

			.{ mask = "0011_10..", f = #bake_arguments wrap(f = cmp_rm_r) },
			.{ mask = "0011_110.", f = #bake_arguments wrap(f = cmp_imm_acc) },
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

print_binary_op :: (op: $T) {
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

print :: (inst: Instruction) {
	while mov := isa(inst, MOV) {
		defer break;
		print_binary_op(mov);
	}

	while add := isa(inst, ADD) {
		defer break;
		print_binary_op(add);
	}

	while sub := isa(inst, SUB) {
		defer break;
		print_binary_op(sub);
	}

	while cmp := isa(inst, CMP) {
		defer break;
		print_binary_op(cmp);
	}
}