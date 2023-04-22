#import "Basic";
#import "File";
#import "Command_Line";

#load "decoding.jai";

MOV_OPCODE_MASK :: 0b11111100;
MOV_OPCODE :: 0b10001000;

decode_instruction_stream :: (stream: [] u8) {
	print("bits 16\n");

	// idx := 0;
	// while idx < stream.count {
	// 	first := stream[idx + 0];
	// 	second := stream[idx + 1];

	// 	assert((first & MOV_OPCODE_MASK) == MOV_OPCODE);
	// 	D := (first & 0b00000010) >> 1;
	// 	W := (first & 0b00000001) >> 0;

	// 	MOD := (second & 0b11000000) >> 6;
	// 	REG := (second & 0b00111000) >> 3;
	// 	RM  := (second & 0b00000111) >> 0;

	// 	assert(MOD == 0b11);

	// 	dst := ifx D == 0 then RM else REG;
	// 	src := ifx D == 0 then REG else RM;

	// 	TABLE_W0 :: string.[ "al", "cl", "dl", "bl", "ah", "ch", "dh", "bh" ];
	// 	TABLE_W1 :: string.[ "ax", "cx", "dx", "bx", "sp", "bp", "si", "di" ];

	// 	print("mov %, %\n", TABLE_W1[dst], TABLE_W1[src]);

	// 	idx += 2;
	// }

	while stream.count > 0 {
		inst, ok := next(*stream);
		if !ok return;
		print(inst);
		if !isa(inst, REP) && !isa(inst, LOCK)
			print("\n");
	}
}

Arguments :: struct {
	file: string;
}

main :: () {
	ok1, args, is_set := parse_arguments(Arguments);
	if !ok1 {
		print("; Failed to parse arguments\n");
		return;
	}
	if !is_set.file {
		print("; No file specified\n");
		return;
	}

	file, success := read_entire_file(args.file);
	if !success {
		print("; Failed to read file\n");
		return;
	}
	stream: [] u8;
	stream.data = file.data;
	stream.count = file.count;
	decode_instruction_stream(stream);
}