/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

term_expansion(sicstus_module(Title, Exports), ( :- module(Title, Exports))).
term_expansion(sicstus_use_module(ModuleList), ( :- use_module(ModuleList))).
term_expansion(sicstus_meta_predicate(Pred), ( :- meta_predicate(Pred))).

% swi: allow operators to be used outside modules declaring them
goal_expansion(op(X,Y,N), (initialization(op(X,Y,user:N)), op(X,Y,user:N))) :- 
    \+ N = user:_.

% swi: inexplicably missing predicates
suffix(Back, Whole) :- append(_Front, Back, Whole).

nth(N, List, Element) :-
	var(N), !,
	    nth0(M, List, Element),
	    N is M+1;
	M is N-1,
	    nth0(M, List, Element).

substitute(_, [], _, []).

substitute(E, [G | T1], F, [H | T2]) :-
        (E=G, !, F=H;
            G=H),
        substitute(E, T1, F, T2).

% swi: things actually more similar to gnu-prolog

local_atom_chars(Atom, Chars) :-
	atom_codes(Atom, Chars).

local_wind_up :-
    halt(0).

% swi: can read unicode direct so do not need this
unicode_to_utf8(C, [C]).
utf8_to_unicode([C], C).

% GNU-friendly notation for cross-module calls -- already an operator in swi
% but precedence needs changing
:- op(550, xfy, '><').

% include tcltk -- we are using pipe interface
:- 	use_module([library(lists), sp_only, tcltk, input, code]).

% actually converts to Unicode -- see above
get_native(FileTtfn, FileNative) :-
        name(FileTtfn, StrTtfn),
        tcltk:all_ttfn_to_utf8(StrTtfn, StrNative),
        name(FileNative, StrNative).

/* Just in case we use the outline runtime system from Sicstus 3.9... */
runtime_entry(start) :-
	main.

/* This is here because in Gnu it can only be added after the Prolog code has
been loaded. Others are in ame_gen.pl */

:- op(500, fx, ['!']).

main :-
	gtrace,
%    guitracer,
%    spy(utility:wake),
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	database:empty_tree,
	state:retractall(model_in(_,_)),
        % swi: avoid prompt chars messing up the pipe interface
        prompt(_P, ''),
        % swi: include decimals in floats so they are readable by other Prologs
        set_prolog_flag(float_format, '%#.12g'),
        nl, write(ready), nl,
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
