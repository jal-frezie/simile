/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

:- 	use_module([library(tcltk), library(lists), library(charsio),
		    input, utility]).

/* xrefs occurs inside a model structure and contains other
model structures, making them circular. It must therefore be
printed incompletely to avoid infinite loops... */

portray(xrefs(Model, _, _, _)) :-
	print(xrefs(Model,'Links')).

main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	state:retractall(model_in(_,_)),
	state:get_style(New_style),
	prolog_flag(version, Vnum),
	version_is(V),
        tk_new([], Interp),
	on_exception(ErrorFunction, 
		     tcl_eval(Interp, [source, '../Run/toolbox.tcl'], _),
		     /* rel path only needed in dev sys */
		     (ErrorFunction =.. [_, _, String],
			 name(Bug, String),
			 write(Bug), nl,
			 fail)),
	tcl_eval(Interp, ['FilterErrors ControlDraw', V, br(Vnum)], TempStr),
	tcl_eval(Interp, ['FilterErrors InitStyle', New_style], OpenStr),
	output:set_interpreter(Interp),

	state:set_mode(none),
	inters:read_library_funx(LibFuns),
	dialogue:pass_functions(LibFuns),
	make_desktop(Desktop),
	name(TempDir, TempStr),
	backup:assert(use_temp_dir(TempDir)),
	name(OpenModel, OpenStr),
	(OpenModel = ''; menu:stick_model_in(Desktop, OpenModel)),
	append_atoms(TempDir, '/.lock/', SplashLock),
	output:trim_tree(SplashLock, ''),
        tk_main_loop,
        tcl_delete(Interp),
	output:unset_interpreter,
	state:kill_windows,
	true.

make_desktop(Desktop) :-
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
