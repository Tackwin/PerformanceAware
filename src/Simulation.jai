#import "Tagged_Union";
#import "Instructions";
#import "Decoding";
#import "Basic";

Memory :: struct {
	data: [1024 * 1024] u8;
}

Segmented_Address :: struct {
	segment: u16;
	offset: u16;
}

access :: (memory: *Memory, address: Segmented_Address) -> *u8 {
	return memory.data.data + cast(u32) address.segment << 4 + cast(u32) address.offset;
}

Register_File :: struct {
	regs: [16] u16;
}

get :: (file: Register_File, reg: Reg) -> u16 {
	if reg == {
		case .AL; return file.regs[0] & 0xFF;
		case .AH; return file.regs[0] >> 8;
		case .AX; return file.regs[0];
		case .BL; return file.regs[1] & 0xFF;
		case .BH; return file.regs[1] >> 8;
		case .BX; return file.regs[1];
		case .CL; return file.regs[2] & 0xFF;
		case .CH; return file.regs[2] >> 8;
		case .CX; return file.regs[2];
		case .DL; return file.regs[3] & 0xFF;
		case .DH; return file.regs[3] >> 8;
		case .DX; return file.regs[3];
		case .SI; return file.regs[4];
		case .DI; return file.regs[5];
		case .BP; return file.regs[6];
		case .SP; return file.regs[7];
		case .CS; return file.regs[8];
		case .DS; return file.regs[9];
		case .ES; return file.regs[10];
		case .SS; return file.regs[11];
		case .IP; return file.regs[12];
		case .FLAGS; return file.regs[13];
		case .NONE; return 0;
	}
	return 0;
}

set :: (file: *Register_File, reg: Reg, data: u16) {
	if reg == {
		case .AL; file.regs[0] = (file.regs[0] & 0xFF00) | (data & 0x00FF);
		case .AH; file.regs[0] = (file.regs[0] & 0x00FF) | (data << 8);
		case .AX; file.regs[0] = data;
		case .BL; file.regs[1] = (file.regs[1] & 0xFF00) | (data & 0x00FF);
		case .BH; file.regs[1] = (file.regs[1] & 0x00FF) | (data << 8);
		case .BX; file.regs[1] = data;
		case .CL; file.regs[2] = (file.regs[2] & 0xFF00) | (data & 0x00FF);
		case .CH; file.regs[2] = (file.regs[2] & 0x00FF) | (data << 8);
		case .CX; file.regs[2] = data;
		case .DL; file.regs[3] = (file.regs[3] & 0xFF00) | (data & 0x00FF);
		case .DH; file.regs[3] = (file.regs[3] & 0x00FF) | (data << 8);
		case .DX; file.regs[3] = data;
		case .SI; file.regs[4] = data;
		case .DI; file.regs[5] = data;
		case .BP; file.regs[6] = data;
		case .SP; file.regs[7] = data;
		case .CS; file.regs[8] = data;
		case .DS; file.regs[9] = data;
		case .ES; file.regs[10] = data;
		case .SS; file.regs[11] = data;
		case .IP; file.regs[12] = data;
		case .FLAGS; file.regs[13] = data;
		case .None;
	}
}

simulate :: (memory: *Memory, file: *Register_File, op: $T) {
	assert(false);
}

simulate :: (memory: *Memory, file: *Register_File, mov: MOV) {
	print("% \n", mov);
	imm := isa(mov.src, u16);
	reg := isa(mov.dst, Reg);
	if imm && reg {
		set(file, <<reg, <<imm);
	}
}

simulate :: (memory: *Memory, file: *Register_File, instructions: [] Instruction) {
	for instructions {
		#insert #run -> string {
			str := "";
			for jt: it.value_types {
				str = tprint(
					"%\nwhile op := isa(it, %) {\n defer break;\n simulate(memory, file, <<op);\n}",
					str,
					jt
				);
			}
			return str;
		};
	}

	print("%\n", <<file);
}
