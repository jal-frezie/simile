/* This will be removed during the port to Gnu Prolog... */

:- op( 600, fx, [prefix, infix, postfix] ).

term_expansion( prefix Name, ( :- op( 450, fy, Name ))).
term_expansion( infix Name, ( :- op( 500, xfy, Name ))).
term_expansion( postfix Name, ( :- op( 450, xf, Name ))).

/* ...and here is the first component of this port! GNU has no modules, so use
term_expansion to make something which it can treat as a predicate and ignore,
but which Sicstus uses to do modules. */

term_expansion(sicstus_use_module(ModuleList), ( :- use_module(ModuleList))).
term_expansion(sicstus_module(Title, Exports), ( :- module(Title, Exports))).
term_expansion(sicstus_meta_predicate(Pred), ( :- meta_predicate(Pred))).

term_expansion(sicstus_dynamic(Dynams), ( :- dynamic Dynams)).
