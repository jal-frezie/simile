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

:- include('tcltk.pl').

/* Files needed to load and save models */

:- include('database.pl').
:- include('text.pl').
:- include('graphics.pl').
:- include('m_struct.pl').
:- include('node.pl').
:- include('link.pl').
:- include('build.pl').
:- include('utility.pl').
:- include('ame_gen.pl').
:- include('library.pl').
% :- include('ss_import.pl').

/* files needed to build programs */

:- include('units.pl').
:- include('render.pl').
:- include('instance.pl').
:- include('inters.pl').
:- include('language.pl').
:- include('compile.pl').
:- include('m_update.pl').
:- include('code.pl').

/* files to run the GUI */

:- include('submodel.pl').
:- include('dialogue.pl').
:- include('output.pl').
:- include('state.pl').
:- include('backup.pl').
:- include('image.pl').
:- include('draw.pl').
:- include('forms.pl').
:- include('event.pl').
:- include('menu.pl').
:- include('input.pl').

/* Things that are done differently in sicstus */

sicstus_read_from_chars(Term, Result) :-
        read_from_codes(Term, Result).

sicstus_write_to_chars(Term, Result) :-
        print_to_codes(Result, Term).

sicstus_writeq_to_chars(Term, Result) :-
        write_term_to_codes(Result, Term, [quoted(true), numbervars(false),
					   portrayed(true)]).

sicstus_format_to_chars(Template, [V1 | Vars], Result) :-
        !, format_to_codes(Result, Template, [V1 | Vars]).

sicstus_format_to_chars(Template, V1, Result) :-
        format_to_codes(Result, Template, [V1]).

open_chars_stream(String, Stream) :-
	open_input_codes_stream(String, Stream).

sicstus_write_chars(Chars) :-
	get_print_stream(Stream),
	sicstus_write_chars(Stream, Chars).

sicstus_write_chars(_Stream, []).
sicstus_write_chars(Stream, [Char | Rest]) :-
	put_code(Stream, Char),
	sicstus_write_chars(Stream, Rest).

sicstus_atom_chars(Atom, Chars) :-
	atom_codes(Atom, Chars).

raise_exception(Error) :-
	throw(Error).

on_exception(Error, Goal, Recovery) :-
	catch(Goal, Error, Recovery).

assert(T) :-
	assertz(T).

/* Reimplemented from Sicstus libraries: */

substitute(_, [], _, []).

substitute(E, [G | T1], F, [H | T2]) :-
        (E=G, !, F=H;
            G=H),
        substitute(E, T1, F, T2).

/* seems Daniel has added these in latest version */
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

gnu_round(N, IN) :-
	integer(N), !, IN = N;
	IN is round(N).

wrap_fixes(_) :-
	fail.

load_foreign_resource(_).

/* If we rely on writeq to put non-readable atoms in quotes it will
also convert wide characters into sets of hex codes enclosed in
backslashes, which other Prologs cannot read. So we do it by hand
instead.

Note use of name rather than write_to_codes because latter causes
confusion with the print stream.

This system has been removed cos I have hacked the GNU Prolog source to
stop it doing the unwanted conversion.

needs_quoting(Foo, Noo) :-
	atom(Foo),
	name(Foo, Bar),
	append(Bar, ".", Barb),
	catch(read_from_codes(Barb, Foob), _Err, true),
	\+ Foob == Foo,
        double_single_quotes(Bar, Barq),
	append([39 | Barq], [39], Noo).

double_single_quotes(NoneDone, AllDone) :-
        append(NoQuotes, [Baddie | StillUndone], NoneDone),
	member([Baddie, Good1, Good2], [[39, 39,39],[10, 92,110]]), !,
            double_single_quotes(StillUndone, NowDone),
            append(NoQuotes, [Good1, Good2 | NowDone], AllDone);
        AllDone = NoneDone.
*/

runtime_entry(start) :-
	main.

:- dynamic(version_is/1).

portray(T) :-
	rt_portray(T).
main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	database:empty_tree,
	state:retractall(model_in(_,_)),
        nl, write(ready), nl,
	current_prolog_flag(prolog_name, Vname),
	current_prolog_flag(prolog_version, Vnum),
	append_atoms([Vname, ' ', Vnum], PlogV),
	/* tcl files are sourced into the startup script rather
	than loaded by Prolog because they contain references
	to global variables which only work at top level

	on_exception(ErrorFunction, 
		     tcl_eval([source, '../Run/toolbox.tcl'], _),
		     (ErrorFunction =.. [_, _, String],
			 name(Bug, String),
			 write(Bug), nl,
			 fail)), */
	on_exception(ErrorFunction, state:kickoff(PlogV), true),
        (nonvar(ErrorFunction),
	    query(start_fail(ErrorFunction), error, top, [ok], _);
	tk_main_loop).
	 

:- op(500, fx, ['!']).
/* Works but buggers up GNU prolog (do after loading?) */

:- initialization(main).
