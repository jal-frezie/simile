/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

/* allow module system to be ignored */
_Module:Function :-
        call(Function).

:- discontiguous([sicstus_module/2, sicstus_use_module/1, sicstus_only/1,
	sicstus_meta_predicate/1]).

/* Reimplemented from Sicstus libraries: */

substitute(_, [], _, []).

substitute(E, [G | T1], F, [H | T2]) :-
        (E=G, !, F=H;
            G=H),
        substitute(E, T1, F, T2).

:- include('tcltk.pl').

/* Files needed to load and save models */

:- include('database.pl').
:- include('text.pl').
:- include('graphics.pl').
:- include('class.pl').
:- include('m_struct.pl').
:- include('node.pl').
:- include('link.pl').
:- include('build.pl').
:- include('gnutils.pl').
:- include('ame_gen.pl').
:- include('library.pl').

/* files needed to build programs */

:- include('units.pl').
:- include('render.pl').
:- include('instance.pl').
:- include('inters.pl').
:- include('language.pl').
:- include('compile.pl').
:- include('m_update.pl').

/* files to run the GUI */

:- include('backup.pl').
:- include('files.pl').
:- include('submodel.pl').
:- include('dialogue.pl').
:- include('output.pl').
:- include('state.pl').
:- include('image.pl').
:- include('maintain.pl').
:- include('event.pl').
:- include('menu.pl').
:- include('input.pl').

/* Things that are done differently in sicstus */

get0(Stream, Char) :-
	get_code(Stream, Char).

put(Stream, Char) :-
	put_code(Stream, Char).

sicstus_read_from_chars(Term, Result) :-
        read_from_codes(Term, Result).

sicstus_write_to_chars(Term, Result) :-
        write_to_codes(Result, Term).

sicstus_format_to_chars(Template, [V1 | Vars], Result) :-
        !, format_to_codes(Result, Template, [V1 | Vars]).

sicstus_format_to_chars(Template, V1, Result) :-
        format_to_codes(Result, Template, [V1]).

open_chars_stream(String, Stream) :-
	open_input_codes_stream(String, Stream).

sicstus_write_chars(_Stream, []).
sicstus_write_chars(Stream, [Char | Rest]) :-
	put_byte(Stream, Char),
	sicstus_write_chars(Stream, Rest).

sicstus_put(Stream, Char) :-
	put_byte(Stream, Char).

raise_exception(Error) :-
	throw(Error).

on_exception(Error, Goal, Recovery) :-
	catch(Goal, Error, Recovery).

assert(T) :-
	assertz(T).

nth0(N, List, Element) :-
	var(N), !,
	    nth(M, List, Element),
	    N is M-1;
	M is N+1,
	    nth(M, List, Element).

ground(Term) :-
	atomic(Term), !;
	var(Term), !, fail;
	Term =.. [_ | ListTerm], all_ground(ListTerm).

all_ground([]).

all_ground([H | T]) :-
	ground(H),
	all_ground(T).

/* Things that are used in the eqn language but cause gnu prolog to not
load properly if they have already been declared */

/* Things to ignore temporarily */
% binary type of output file

/* regular stuff : xrefs occurs inside a model structure and contains other
model structures, making them circular. It must therefore be
printed incompletely to avoid infinite loops... */

portray(xrefs(Model, _, _, _)) :-
	print(xrefs(Model,'Links')).

portray(sm(Model, _,_,_)) :-
	print(sm(Model)).

runtime_entry(start) :-
	main.

version_is(2.92).

main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	state:retractall(model_in(_,_)),
	state:get_style(New_style),
	current_prolog_flag(prolog_name, Vname),
	current_prolog_flag(prolog_version, Vnum),
	append_atoms([Vname, ' ', Vnum], PlogV),
	version_is(V),
        nl, write(ready), nl,
	/* tcl files are sourced into the startup script rather
	than loaded by Prolog because they contain references
	to global variables which only work at top level

	on_exception(ErrorFunction, 
		     tcl_eval([source, '../Run/toolbox.tcl'], _),
		     (ErrorFunction =.. [_, _, String],
			 name(Bug, String),
			 write(Bug), nl,
			 fail)), */
	tcl_eval(['FilterErrors ControlDraw', V, br(PlogV)], TempStr),
	tcl_eval(['FilterErrors InitStyle', New_style], OpenStr),

	state:set_mode(none),
	inters:read_library_funx(LibFuns),
	dialogue:pass_functions(LibFuns),
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
	state:initialize_phase,
	name(TempDir, TempStr),
	backup:assert(use_temp_dir(TempDir)),
	name(OpenModel, OpenStr),
	(OpenModel = ''; menu:stick_model_in(Desktop, OpenModel)),
	tcl_eval(['FilterErrors FixSize', Canvas_name], _),
	append_atoms(TempDir, '/.lock/', SplashLock),
	output:trim_tree(SplashLock, ''),
	tk_main_loop.

:- op(500, fx, ['!']).
/* Works but buggers up GNU prolog (do after loading?) */

:- initialization(main).
