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
:- include('utility.pl').
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
        print_to_codes(Result, Term).

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

sicstus_writeq(Stream, Term) :-
	write_term(Stream, Term, [quoted(true), portrayed(true)]).

sicstus_put(Stream, Char) :-
	put_byte(Stream, Char).

sicstus_atom_chars(Atom, Chars) :-
	atom_codes(Atom, Chars).

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

/* Not in GNU prolog but should be */

printq_to_codes(TermStr, Term) :-
	write_term_to_codes(TermStr, Term, [quoted(true), portrayed(true)]).

/* Things that are used in the eqn language but cause gnu prolog to not
load properly if they have already been declared */

/* Things to ignore temporarily */

portray(F) :-
	trim_float(F, NewF), !,
	get_print_stream(Stream),
	format(Stream,"~s",[NewF]).

/* regular stuff : xrefs occurs inside a model structure and contains other
model structures, making them circular. It must therefore be
printed incompletely to avoid infinite loops... */

portray(xrefs(Model, _, _, _)) :-
	print(xrefs(Model,'Links')).

portray(sm(Model, _,_,_)) :-
	print(sm(Model)).

/* Improved system for outputting floating-point numbers -- max of 
decimal places (thanks to Dan Diaz for making it work with print_to_chars)
-- previously unusable due to weird bug in gprolog */

trim_float(F, Ns) :-
	float(F),
	format_to_codes(Fs, "~8g", [F]),
	/* number must look like float so add .0 if it doesnt */
	(member(Ch, Fs), member(Ch, "e."), !,
	    Ns = Fs;
	append(Fs, ".0", Ns)).
	
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

main :-
	/* first clear state from previous run (only matters in dev sys)
	database:clear_database, or not as the case may be */
	state:retractall(model_in(_,_)),
	current_prolog_flag(prolog_name, Vname),
	current_prolog_flag(prolog_version, Vnum),
	append_atoms([Vname, ' ', Vnum], PlogV),
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
	state:kickoff(PlogV),
        tk_main_loop.

:- op(500, fx, ['!']).
/* Works but buggers up GNU prolog (do after loading?) */

:- initialization(main).
