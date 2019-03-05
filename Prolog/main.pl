/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

term_expansion(sicstus_module(Title, Exports), ( :- module(Title, Exports))).
term_expansion(sicstus_use_module(ModuleList), ( :- use_module(ModuleList))).
term_expansion(sicstus_meta_predicate(Pred), ( :- meta_predicate(Pred))).

% sicstus-only, as opposed to non-GNU:
local_atom_chars(Atom, Chars) :-
	atom_chars(Atom, Chars).

% specific to dll interface
local_wind_up :-
	state:use_temp_dir(TempDir),
	output:my_delete_file(TempDir),
	any_tcl_eval([destroy, '.'], 0, _).

:- consult(sp_only).

% GNU-friendly notation for cross-module calls
:- op(550, xfy, ><).

:- 	use_module([library(tcltk), library(lists), input, code]).

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

portray(make(E, Conds, P, F, A)) :-
	\+ Conds == conds,	% print calls portray so avoid looping
	print(make(E, conds, P, F, A)).

%portray(sm(Name, _,_,Lp)) :-
%	print(sm(Name,Lp)).
%
%portray(T) :-
%	utility:rt_portray(T).
%
trim_conds(Full, Short) :-
	Full = make(Short, _,_,_,_), !;
	Full =.. [Hdr, Cond], !,
	trim_conds(Cond, StCond),
	Short =.. [Hdr, StCond];
	Short = Full.

main :-
	/* first clear state from previous run (only matters in dev sys)
	or not as the case may be */
	database:clear_database,
	database:empty_tree,
	state:retractall(model_file(_,_)),
	state:retractall(model_in(_,_)),
	state:retractall(edition_is(_)),
        tk_new([], Interp),
	set_interpreter(Interp),
	on_exception(ErrorFunction, 
		     (any_tcl_eval([set, prolog_in_console, 1], 1, _),
		     any_tcl_eval([source, '../Run/simile.tcl'], 1, _)),
		     /* rel path only needed in dev sys */
		     (ErrorFunction =.. [_, _, String],
			 name(Bug, String),
			 write(Bug), nl,
			 fail)),
	prolog_flag(version, FullVnum),
	name(FullVnum, FullVnumStr),
	append(VnumStr, [32, 40 | _], FullVnumStr),
	name(Vnum, VnumStr), !, /* remove first ' (' onwards */
	on_exception(ErrorFunction, state:kickoff(Vnum), true),
        (nonvar(ErrorFunction),
	    ame_gen:query(start_fail(ErrorFunction), error, top, [ok], _);
	tk_main_loop),
        tcl_delete(Interp),
	unset_interpreter,
	state:kill_windows,
	true.
