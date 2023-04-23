#import "Basic";
#import "File";
#import "Command_Line";

#import "Tagged_Union";
#import "Decoding";
#import "Simulation";
#import "Instructions";

Arguments :: struct {
	print: string;
	exec: string;
}

main :: () {
	ok1, args, is_set := parse_arguments(Arguments);
	if !ok1 {
		print("; Failed to parse arguments\n");
		return;
	}
	if !is_set.print && !is_set.exec {
		print("; No file specified\n");
		return;
	}

	if is_set.print {
		file, success := read_entire_file(args.print);
		defer free(file.data);

		if !success {
			print("; Failed to read file\n");
			return;
		}

		stream: [] u8;
		stream.data = file.data;
		stream.count = file.count;

		instructions: [..] Instruction;
		array_reserve(*instructions, 4098);
		defer array_free(instructions);

		t0 := current_time_monotonic();
		decode_instruction_stream(stream, *instructions);
		t1 := current_time_monotonic();

		print("bits 16\n");
		for instructions {
			print(it);
			if !isa(it, REP) && !isa(it, LOCK)
				print("\n");
		}

		print("; Decoded % in % ms\n", instructions.count, to_float64_seconds(t1 - t0) * 1000);
	}
	
	if is_set.exec {
		file, success := read_entire_file(args.exec);
		defer free(file.data);

		if !success {
			print("; Failed to read file\n");
			return;
		}

		stream: [] u8;
		stream.data = file.data;
		stream.count = file.count;

		instructions: [..] Instruction;
		array_reserve(*instructions, 4098);
		defer array_free(instructions);

		t0 := current_time_monotonic();
		decode_instruction_stream(stream, *instructions);
		t1 := current_time_monotonic();

		memory := New(Memory);
		defer free(memory);
		reg_file: Register_File;
		simulate(memory, *reg_file, instructions);
	}
}