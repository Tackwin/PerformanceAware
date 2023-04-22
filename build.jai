#import "Compiler";
#import "Basic";

build_client :: () -> Workspace {
	w := compiler_create_workspace("PerfAware");
	import : [..] string;
	seed := get_build_options();
	opts := get_build_options(w);
	opts.Commonly_Propagated = seed.Commonly_Propagated;
	array_add(*import, ..opts.import_path);
	array_add(*import, "./src/");
	opts.output_executable_name = "PerfAware";
	opts.import_path = import;
	// opts.text_output_flags = 0;
	opts.emit_debug_info = .CODEVIEW;
	// opts.llvm_options.disable_inlining = true;
	set_build_options(opts, w);
	return w;
}

build :: () {
	client := build_client();

	compiler_begin_intercept(client);

	add_build_file("src/Main.jai", client);

	while true {
		message := compiler_wait_for_message();

		if message.kind == {
			case .COMPLETE; break;
		}
	}

	compiler_end_intercept(client);

	
	set_build_options_dc(.{ do_output=false });
}


#run build();
