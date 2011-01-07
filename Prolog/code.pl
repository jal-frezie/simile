/* module CODE supplies the functions that parse the equations and build the
executable models. The intention is that these could be made a separate
process, which is why they are separated out here. */

sicstus_module(code, [tk_interactively_parse/1, tk_code/3]).

sicstus_use_module([library(lists),
		    sp_only, ame_gen, dialogue, compile, state]).

tk_interactively_parse(Node) :-
	interactively_parse(Node).

tk_code(Model, CompOrBuild, Tgt) :-
	(CompOrBuild = compile_c, % export shared library
	    output'><'safe_tcl_eval([info, sharedlibextension], IdentStr);
	 CompOrBuild = build_c, % export source code
	    IdentStr = ".cpp"),
	name(Ident, IdentStr),
%	get_default_export_name(Model, IdentStr, DefN),
%	get_program_file(DefN, Model, Tgt),
	use_temp_dir(Temp),
	find_all_comps(Base, Model),
	(Base = root,
	    CompDir = Temp;
	abs_path_name(Base, root, Path),
	    append_atoms([Temp, '/', Path], CompDir)),
	(\+ rebuild_code(c, Model, CompDir), !;
	(m_update'><'get_av_pair(Model, 1, c_new, Serial), !; Serial = 1),
	    caption_for(Model, Capt),
	    utility'><'append_atoms([CompDir, '/', Capt, '/model', Serial, Ident], Top),
	    output'><'safe_tcl_eval([file, copy, '-force', br(Top), br(Tgt)], _)).

tk_code(Node, RunCmd, _Dummy) :-
	member([RunCmd, Lang], [[run_c, c], [run_tcl, tcl]]),
	/* Compile the thing into whatever, load it */
	use_temp_dir(Dir),
	draw'><'scrub_run(Node, 0),
	rebuild_code(Lang, Node, Dir),
	    % if exceps happen here, catch in Tcl and return failure
	    % on_exception(Whoops,
	%		 output'><'prepare_execution(Node, Lang),
% 		     (sicstus_write_to_chars(Whoops, Squeak),
% 			 scrub_run(Node, 0))),
	set_running_model(Node).

rebuild_code(Lang, Node, ProgFileDir) :-
	compile(Lang, Node, ProgFileDir);
	draw'><'scrub_run(Node, 0),
	fail.
