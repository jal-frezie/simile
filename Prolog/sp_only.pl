/* :- module(sp_only, [sicstus_read_from_chars/2, sicstus_write_to_chars/2,
		    sicstus_format_to_chars/3, sicstus_write_chars/2,
		    sicstus_put/2]).

...and here is the first component of this port! GNU has no modules, so use
term_expansion to make something which it can treat as a predicate and ignore,
but which Sicstus uses to do modules. */

term_expansion(sicstus_use_module(ModuleList), ( :- use_module(ModuleList))).
term_expansion(sicstus_module(Title, Exports), ( :- module(Title, Exports))).
term_expansion(sicstus_meta_predicate(Pred), ( :- meta_predicate(Pred))).

sicstus_use_module([library(charsio)]).

sicstus_read_from_chars(Term, Result) :-
        read_from_chars(Term, Result).

sicstus_write_to_chars(Term, Result) :-
        write_to_chars(Term, Result).

sicstus_format_to_chars(Template, [V1 | Vars], Result) :-
	format_to_chars(Template, [V1 | Vars], Result).

sicstus_write_chars(Stream, Chars) :-
	name(Atom, Chars),
	write(Stream, Atom).

sicstus_put(Stream, Char) :-
	put(Stream, Char).
