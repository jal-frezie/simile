/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

:- 	use_module([library(lists),
		    sp_only, tcltk, input, utility]).

/* Just in case we use the outline runtime system from Sicstus 3.9... */
runtime_entry(start) :-
	main.

/* This is here because in Gnu it can only be added after the Prolog code has
been loaded. Others are in ame_gen.pl */

:- op(500, fx, ['!']).

main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	database:empty_tree,
	state:retractall(model_in(_,_)),
        nl, write(ready), nl,
        user:any_tcl_eval('WhatAmI', 1, CmdStr),
        name(Cmd, CmdStr),
        call(Cmd).

editor :-
	prolog_flag(version, FullVnum),
	name(FullVnum, FullVnumStr),
	append(VnumStr, [32, 40 | _], FullVnumStr),
	name(Vnum, VnumStr), !, /* remove first ' (' onwards */
	on_exception(ErrorFunction, state:kickoff(Vnum), true),
        (nonvar(ErrorFunction),
	    ame_gen:query(start_fail(ErrorFunction), error, top, [ok], _);
	tk_main_loop).

/* Uncomment following to make standalone executable
:- initialization(main). */
