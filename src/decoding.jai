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

OPCODE_MASK :: enum {
	MOV_RM_R :: 0b1111_1100;
	MOV_IMM_R :: 0b1111_0000;
	MOV_IMM_RM :: 0b1111_1110;
	MOV_MEM_ACC :: 0b1111_1110;
	MOV_ACC_MEM :: 0b1111_1110;
}
OPCODE :: enum {
	MOV_RM_R :: 0b1000_1000;
	MOV_IMM_R :: 0b1011_0000;
	MOV_IMM_RM :: 0b1100_0110;
	MOV_MEM_ACC :: 0b1010_0000;
	MOV_ACC_MEM :: 0b1010_0010;
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

MOV :: struct {
	Direct_Address :: #type,distinct u16;

	src: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);
	dst: Tagged_Union(Reg, Cea, Direct_Address);

	disp: s16;
};

Instruction :: Tagged_Union(MOV);

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

	set(*mov.src, cast(MOV.Direct_Address) next_u16(stream));

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

	set(*mov.dst, cast(MOV.Direct_Address) next_u16(stream));

	return mov, true;
}

mov_imm_rm :: (stream: *[] u8) -> MOV, bool {
	mov: MOV;

	if stream.count < 2
		return mov, false;

	s0 := next_u8(stream);
	s1 := next_u8(stream);

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
					return mov, false;
			}
		case 0b01;
			disp = 8;
			if stream.count < 1
				return mov, false;
		case 0b10;
			disp = 16;
			if stream.count < 2
				return mov, false;
		case 0b11;
			mod_reg = true;
	}

	if mod_reg {
		set(*mov.dst, cast(Reg) (W + 2 *  RM));
	} else {
		if direct_addr {
			set(*mov.dst, cast(MOV.Direct_Address) next_u16(stream));
		} else {
			set(*mov.dst, cast(Cea) RM);
		}

		if disp == 8
		{
			mov.disp = next_u8(stream);
			if mov.disp & 0b1000_0000
				mov.disp |= 0b1111_1111_0000_0000;
		}
		if disp == 16
			mov.disp = cast, no_check(s16) next_u16(stream);
	}

	if W {
		set(*mov.src, next_u16(stream));
	} else {
		set(*mov.src, next_u8(stream));
	}

	return mov, true;
}

mov_imm_r :: (stream: *[] u8) -> MOV, bool {
	mov: MOV;

	if stream.count < 2
		return mov, false;

	s0 := next_u8(stream);

	W := (s0 & 0b0000_1000) >> 3;
	REG := s0 & 0b0000_0111;

	if W {
		if stream.count < 1
			return mov, false;
	}

	set(*mov.dst, cast(Reg) (W + 2 * REG));

	if W {
		set(*mov.src, next_u16(stream));
	} else {
		set(*mov.src, next_u8(stream));
	}

	return mov, true;
}

mov_rm_r :: (stream: *[] u8) -> MOV, bool {
	mov: MOV;

	if stream.count < 2
		return mov, false;

	s0 := next_u8(stream);
	s1 := next_u8(stream);

	D := (s0 & 0b0000_0010) >> 1;
	W := (s0 & 0b0000_0001) >> 0;

	MOD := (s1 & 0b1100_0000) >> 6;
	REG := (s1 & 0b0011_1000) >> 3;
	RM  := (s1 & 0b0000_0111) >> 0;

	disp := 0;
	direct_addr := false;
	mod_reg := false;

	if MOD == {
		case 0b00;
			if RM == 0b110 {
				direct_addr = true;
				if stream.count < 2
					return mov, false;
			}
		case 0b01;
			disp = 8;
			if stream.count < 1
				return mov, false;
		case 0b10;
			disp = 16;
			if stream.count < 2
				return mov, false;
		case 0b11;
			mod_reg = true;
	}

	if mod_reg {
		if D == 0 {
			set(*mov.src, cast(Reg) (W + 2 * REG));
			set(*mov.dst, cast(Reg) (W + 2 *  RM));
		}
		if D == 1 {
			set(*mov.src, cast(Reg) (W + 2 *  RM));
			set(*mov.dst, cast(Reg) (W + 2 * REG));
		}
	} else {
		if D == 0 {
			set(*mov.src, cast(Reg) (W + 2 * REG));
			if direct_addr {
				set(*mov.dst, cast(MOV.Direct_Address) next_u16(stream));
			} else {
				set(*mov.dst, cast(Cea) RM);
			}
		} else {
			set(*mov.dst, cast(Reg) (W + 2 * REG));
			if direct_addr {
				set(*mov.src, cast(MOV.Direct_Address) next_u16(stream));
			} else {
				set(*mov.src, cast(Cea) RM);
			}
		}

		if disp == 8
		{
			mov.disp = next_u8(stream);
			if mov.disp & 0b1000_0000
				mov.disp |= 0b1111_1111_0000_0000;
		}
		if disp == 16
			mov.disp = cast, no_check(s16) next_u16(stream);
	}

	return mov, true;
}

next :: (stream: *[] u8) -> Instruction, bool {
	ret: Instruction = ---;

	if stream.count == 0
		return ret, false;


	first := stream.data[0];
	if (first & cast(u8) OPCODE_MASK.MOV_RM_R) == cast(u8) OPCODE.MOV_RM_R {
		mov, ok := mov_rm_r(stream);
		set(*ret, mov);
		return ret, ok;
	}
	if (first & cast(u8) OPCODE_MASK.MOV_IMM_R) == cast(u8) OPCODE.MOV_IMM_R {
		mov, ok := mov_imm_r(stream);
		set(*ret, mov);
		return ret, ok;
	}
	if (first & cast(u8) OPCODE_MASK.MOV_IMM_RM) == cast(u8) OPCODE.MOV_IMM_RM {
		mov, ok := mov_imm_rm(stream);
		set(*ret, mov);
		return ret, ok;
	}
	if (first & cast(u8) OPCODE_MASK.MOV_ACC_MEM) == cast(u8) OPCODE.MOV_ACC_MEM {
		mov, ok := mov_acc_mem(stream);
		set(*ret, mov);
		return ret, ok;
	}
	if (first & cast(u8) OPCODE_MASK.MOV_MEM_ACC) == cast(u8) OPCODE.MOV_MEM_ACC {
		mov, ok := mov_mem_acc(stream);
		set(*ret, mov);
		return ret, ok;
	}

	return ret, false;
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

print :: (inst: Instruction) {
	while mov := isa(inst, MOV) {
		defer break;

		dst_memory := false;

		print("mov ");
		while dst := isa(mov.dst, Reg) {
			print("%", <<dst);
			break;
		}
		while dst := isa(mov.dst, Cea) {
			dst_memory = true;
			print("[%", serialize(<<dst));
			if mov.disp != 0 {
				if mov.disp > 0 print(" + %", mov.disp);
				if mov.disp < 0 print(" - %", -mov.disp);
			}
			print("]");
			break;
		}
		while dst := isa(mov.dst, MOV.Direct_Address) {
			dst_memory = true;
			print("[%]", <<dst);
			break;
		}
		print(", ");
		while src := isa(mov.src, Reg) {
			print("%", <<src);
			break;
		}
		while src := isa(mov.src, Cea) {
			print("[%", serialize(<<src));
			if mov.disp != 0 {
				if mov.disp > 0 print(" + %", mov.disp);
				if mov.disp < 0 print(" - %", -mov.disp);
			}
			print("]");
			break;
		}
		while src := isa(mov.src, MOV.Direct_Address) {
			print("[%]", <<src);
			break;
		}
		while src := isa(mov.src, u16) {
			if dst_memory
				print("word ");
			print("%", <<src);
			break;
		}
		while src := isa(mov.src, u8) {
			if dst_memory
				print("byte ");
			print("%", <<src);
			break;
		}
	}
}