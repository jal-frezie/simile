/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

:- [syntax].

:- 	use_module([library(lists), library(charsio), tcltk, input, utility]).

/* xrefs occurs inside a model structure and contains other
model structures, making them circular. It must therefore be
printed incompletely to avoid infinite loops... */

portray(xrefs(Model, _, _, _)) :-
	print(xrefs(Model,'Links')).

portray(sm(Model, _,_,_)) :-
	print(sm(Model)).

/* Just in case we use the outline runtime system from Sicstus 3.9... */
runtime_entry(start) :-
	main.

/* This is here because in Gnu it can only be added after the Prolog code has
been loaded. Others are in ame_gen.pl */

:- op(500, fx, ['!']).

/* There are a few things where the GNU Prolog implementation is more concise
than the Sicstus, like... */

printq_to_codes(TermStr, Term) :-
	with_output_to_chars(write_term(Term, [quoted(true), portrayed(true)]),
			     TermStr).

main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	state:retractall(model_in(_,_)),
	prolog_flag(version, PlogV),
        nl, write(ready), nl,
	tcl_eval(['FilterErrors', 'ControlDraw', br(PlogV)], EnvVars),
	output:chop_list(EnvVars, [VStr, TempStr, OpenStr, E]),
	retractall(version_is(_)),
	assert(version_is(VStr)),
	state:set_edition(E),

	state:set_mode(none),
	inters:read_library_funx(LibFuns),
	dialogue:pass_functions(LibFuns),
	make_desktop(Desktop, Canvas),
	name(TempDir, TempStr),
	backup:assert(use_temp_dir(TempDir)),
	name(OpenModel, OpenStr),
	(OpenModel = ''; menu:stick_model_in(Desktop, OpenModel)),
	tcl_eval(['FilterErrors', 'FixSize', Canvas], _),
/*	append_atoms(TempDir, '/.lock/', SplashLock),
	output:trim_tree(SplashLock, ''),
*/        tk_main_loop.

make_desktop(Desktop, Canvas_name) :-
	m_class:Root is_root,
	(m_class:Root has_part Desktop, !;
	m_class:Desktop is_new_part_of Root,
	m_class:Desktop has_new_class submodel,
	m_class:Desktop has_new_class_refinement name of 'Desktop',
	state:get_initial_window_size(X, Y),
	image:set_shape(Desktop, internal_extent, [0, 0, X, Y]),
	image:set_shape(Desktop, bounding_box, [0, 0, X, Y])),
	InitDepths=[0,32,32,32,32,32,32,showAll],
	event:new_window_for(Desktop, Canvas_name, InitDepths),
	all(state, set_display_depth, [unify(Canvas_name),
	    build([ghost_link, influence, variable, flow, compartment,
		   submodel, caption, sections]), build(InitDepths)]),
	maintain:redraw_window(Canvas_name),
	menu:update_mode(select),
	backup:initialize_ring,
	state:initialize_phase.
