/* module CODE supplies the functions that parse the equations and build the
executable models. The intention is that these could be made a separate
process, which is why they are separated out here. */

sicstus_module(code, [tk_interactively_parse/1, tk_code/3]).

sicstus_use_module([library(lists),
		    sp_only, ame_gen, dialogue, compile, state]).

tk_interactively_parse(Node) :-
	interactively_parse(Node).

tk_code(Model, CompOrBuild, _Tgt) :-
	(CompOrBuild = compile_c, % export shared library
	    Action = export_sharelib,
	    output><safe_tcl_eval([info, sharedlibextension], IdentStr);
	 CompOrBuild = build_c, % export source code
            Action = export_source,
	    IdentStr = ".cpp"),
	name(Ident, IdentStr),
	menu><get_default_export_name(Model, IdentStr, DefN),
	forms><get_program_file(DefN, Model, Tgt),
	\+ Tgt = '', % cancelled
	state><use_temp_dir(Temp),
	find_all_comps(Base, Model),
	(Base = root,
	    CompDir = Temp;
	abs_path_name(Base, root, Path),
	    append_atoms([Temp, '/', Path], CompDir)),
	caption_for(Model, Capt),	  
	utility><append_atoms([CompDir, '/', Capt, '/model', 1, Ident], Top),
	(\+ rebuild_code(c, Model, CompDir, Action), !, Success = 0;
	 output><safe_tcl_eval([file, copy, '-force', br(Top), br(Tgt)], _),
	   Success = 1),
	output><safe_tcl_eval(['Undisturb', Top], _),
	output><tk_callback(Success).

tk_code(Node, RunCmd, _Dummy) :-
	member([RunCmd, Lang], [[run_c, c], [run_in_browser, c], [run_tcl, tcl]]),
	/* Compile the thing into whatever, load it */
	use_temp_dir(Dir),
	% draw><scrub_run(Node, 0),
	(rebuild_code(Lang, Node, Dir, prepare_exec) ->
	     Success = 1,
	    % if exceps happen here, catch in Tcl and return failure
	    % on_exception(Whoops,
	%		 output><prepare_execution(Node, Lang),
% 		     (sicstus_write_to_chars(Whoops, Squeak),
% 			 scrub_run(Node, 0))),
	     set_running_model(Node);
	 Success = 0),
	output><tk_callback(Success).

rebuild_code(Lang, Node, ProgFileDir, Action) :-
        compile(Lang, Node, ProgFileDir, Action);
output><safe_tcl_eval(['DebugMess', rebuild_code_failed], _),
% Next line would cause mre setup to be abandoned (unless save dialog
% cancelled) if a rebuild fails. Doesn't seem necessary.
	% draw><scrub_run(Node, 0),
	fail.
