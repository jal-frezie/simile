/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

:- consult(sp_only).

:- 	use_module([library(tcltk), library(lists), library(charsio),
		    input, utility]).

/* Just in case we use the outline runtime system from Sicstus 3.9... */
runtime_entry(start) :-
	main.

/* This is here because in Gnu it can only be added after the Prolog code has
been loaded. Others are in ame_gen.pl */

:- op(500, fx, ['!']).

:- dynamic(is_interpreter/1).

:- dynamic(version_is/1).

set_interpreter(Interp) :-
	assert(is_interpreter(Interp)).

unset_interpreter :-
	retractall(is_interpreter(_)).

any_tcl_eval(Cmd, _Except, Result) :-
	is_interpreter(Interp),
	tcl_eval(Interp, Cmd, Result).

deEncode(_, A, A, 0) :- atom(A).
reEncode(_, A, A, 0) :- atom(A).
all_ttfn_to_utf8(S, S).

main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	state:retractall(model_in(_,_)),
	prolog_flag(version, FullVnum),
	name(FullVnum, FullVnumStr),
	append(VnumStr, [32, 40 | _], FullVnumStr),
	name(Vnum, VnumStr), !, /* remove first ' (' onwards */
        tk_new([], Interp),
	set_interpreter(Interp),
	on_exception(ErrorFunction, 
		     any_tcl_eval([source, '../Run/toolbox.tcl'], 1, _),
		     /* rel path only needed in dev sys */
		     (ErrorFunction =.. [_, _, String],
			 name(Bug, String),
			 write(Bug), nl,
			 fail)),
	on_exception(ErrorFunction, state:kickoff(Vnum), true),
        (nonvar(ErrorFunction),
	    ame_gen:do_dialogue("Failed startup", error, "Simile has been unable to start up due to problems with this system.", ok, _);
	tk_main_loop),
        tcl_delete(Interp),
	unset_interpreter,
	state:kill_windows,
	true.

wind_up :-
	backup:use_temp_dir(TempDir),
	output:my_delete_file(TempDir),
	any_tcl_eval([destroy, '.'], 0, _).
