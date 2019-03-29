/*
launch.pl
---------
This starts off the application and goes into an event loop from which it is driven the rest of the time. The identity of the interpreter is saved as a global so it can be used at the other end of the system, i.e., when putting stuff on the screen. Uses all my modules to make reloading quicker.
*/

:- set_prolog_flag(double_quotes, codes).

term_expansion(sicstus_module(Title, Exports),
	       [(:- module(Title, Exports)),
		(:- set_prolog_flag(double_quotes, codes))]).
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

open_chars_stream(Str, Stm) :-
	open_codes_stream(Str, Stm).

% SWI could just use UTF-8 internally, but I also do some translation on
% macro definitions, so still have to do the save/reopen...

reopen_stream_internally_formatted(Utf8Stm, IntStm, EuContents) :-
	inters:swallow_to_chars(Utf8Stm, U8Contents), % closes stream
	tcltk:all_utf8_to_ttfn(U8Contents, Contents),

	state:use_temp_dir(TempDir),
	append_atoms(TempDir, '/temp_io.pl', TempFile),
	open_native(TempFile, write, Stream2),
	(var(EuContents) ->
	    ame_gen:make_legible_for_prolog(Contents, EuContents, true),
	    sicstus_write_chars(Stream2, EuContents);
	 sicstus_write_chars(Stream2, Contents)),
% temp file can cause NetworkDriveReadOvertakesWrite problem, avoid where poss
	close(Stream2),
	open_native(TempFile, read, IntStm).

close_internally_formatted_stream(Stm) :-
	close(Stm).

chars_from_stream(Stream, Pred, Chars) :-
        with_output_to_chars((current_output(Stream), Pred), Chars).

% 'make' should not recursively display all conds during debug
efx_of([],[]).
efx_of([make(E, _,_,_,_)  | Insts], [E | Efx]) :-
    efx_of(Insts, Efx).
portray(make(E, Conds-Z, P, F, A)) :-
    efx_of(Conds, CondEs),
    print(make(E, CondEs, Z, P, F, A)).

% use sgml library to convert XMLv3 model specs to superficial Prolog syntax
% -- GNU does this with its own libxml2 bindings
:- use_module(library(sgml)).

xml_file_to_term(FileIn, Xml) :-
	load_structure(FileIn, Xml, [dialect(xml),space(sgml)]).

% GNU-friendly notation for cross-module calls -- already an operator in swi
% but precedence needs changing
:- op(550, xfy, ><).

% include tcltk -- we are using pipe interface
:- 	use_module([library(lists), sp_only, tcltk, input, utility, code]).

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
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
        % swi: avoid prompt chars messing up the pipe interface
        prompt(_P, ''),
        % swi: include decimals in floats so they are readable by other Prologs
	set_prolog_flag(float_format, '%#.12g'),
        nl, write(ready), nl,
	% gtrace, % uncomment to trace startup
	output:safe_tcl_eval([file, join, '$::env(SYSDIR)', lib, struct_db],
			     PathToObjStr),
	name(PathToObj, PathToObjStr),
	database:empty_tree(PathToObj),
	state:retractall(model_in(_,_)),
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
