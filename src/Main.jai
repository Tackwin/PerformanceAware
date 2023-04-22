#import "Basic";
#import "File";
#import "Command_Line";

#import "Simulation";

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
		decode_instruction_stream(stream);
	}
	
	if is_set.exec {

	}
}