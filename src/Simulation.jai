#import "Tagged_Union";
#import "Instructions";
#import "Decoding";
#import "Basic";

decode_instruction_stream :: (stream: [] u8) {
	print("bits 16\n");

	while stream.count > 0 {
		inst, ok := next(*stream);
		if !ok return;
		print(inst);
		if !isa(inst, REP) && !isa(inst, LOCK)
			print("\n");
	}
}
