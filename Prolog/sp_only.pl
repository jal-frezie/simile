/* :- module(sp_only, [sicstus_read_from_chars/2, sicstus_write_to_chars/2,
		    sicstus_format_to_chars/3, sicstus_write_chars/1,
		    sicstus_writeq/2]).

...and here is the first component of this port! GNU has no modules, so use
term_expansion to make something which it can treat as a predicate and ignore,
but which Sicstus uses to do modules. */

:- op(550, xfy, '><').
term_expansion(sicstus_use_module(ModuleList), ( :- use_module(ModuleList))).
term_expansion(sicstus_load_foreign_resource(ModuleList), ( :- load_foreign_resource(ModuleList))).
term_expansion(sicstus_module(Title, Exports), ( :- module(Title, Exports))).
%term_expansion(Module'><'Pred, (Module:Pred)).
term_expansion(sicstus_meta_predicate(Pred), ( :- meta_predicate(Pred))).

'><'(Module,Pred) :-
	call(Module:Pred).

sicstus_use_module([library(charsio)]).

sicstus_read_from_chars(Term, Result) :-
        read_from_chars(Term, Result).

sicstus_write_to_chars(Term, Result) :-
        write_to_chars(Term, Result).

sicstus_writeq_to_chars(Term, Result) :-
        write_term_to_chars(Term, Result, [quoted(true), numbervars(false),
					   portrayed(true)]).

sicstus_format_to_chars(Template, [V1 | Vars], Result) :-
	format_to_chars(Template, [V1 | Vars], Result).

sicstus_write_chars([]).
sicstus_write_chars([Char | Rest]) :-
	put_code(Char),
	sicstus_write_chars(Rest).

sicstus_write_chars(_Stream, []).
sicstus_write_chars(Stream, [Char | Rest]) :-
	put_code(Stream, Char),
	sicstus_write_chars(Stream, Rest).

sicstus_atom_chars(Atom, Chars) :-
	atom_chars(Atom, Chars).

/* There are a few things where the GNU Prolog implementation is more concise
than the Sicstus, like... */

read_term_from_codes(String, Term, _Unusable) :-
	append(String, ".", ProperString),
	read_from_chars(ProperString, Term).

print_to_codes(TermStr, Term) :-
	with_output_to_chars(write_term(Term, [portrayed(true)]),
			     TermStr).

number_atom(N, A) :-
	number_chars(N, C),
	atom_chars(A, C).

gnu_round(N, IN) :-
	IN is integer(round(N)).

list(L) :-
	member(L, [[], [_|_]]).

/* Things that are used in the eqn language but cause gnu prolog to not
load properly if they have already been declared. Fortunately, 'portray' is not called when something is actually used as an operator... */

wrap_fixes(Op) :-
	atom(Op),
	(Fted =.. [Op, a]; Fted =.. [Op, b, c]),
	write_to_chars(Fted, Cncl),
	\+ suffix(")", Cncl), !,
	write('('), write(Op), write(')').

/* stop compiler complaining about foreign/1 directives intended for GNU 
(now in different file) */
% database:foreign(_).
