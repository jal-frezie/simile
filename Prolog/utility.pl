/*******************************************************************************
**** Commonly used utility procedures for AME				    ****
*******************************************************************************/

sicstus_module( utility, [wake/0, genint/2, portray/1, trim_float/2,
			  unique_name/2, unique_name/3,
			  indent/1, delete_member/2,
			  y_or_n/1, any_setof/3,foreach/3, wrap/3,
			  all/3, unify_all/2, get_precedence/2,
			  replace_in_list/4, write_with_breaks/2,
			  writelist/1,writelisttofile/2,
			  do_writing/2, open_native/3,
			  delall/3, append/2, append_atoms/2, append_atoms/3,
			  try/1,equate/2,
			  merge_lists/2, merge_lists/3, split_lists/3,
			  get_ground_part/2, generate_name/4, generate_name/5,
			  ensure_unused/4, count_to/4] ).

sicstus_use_module([database, text, sp_only,
		    library(lists), library(ordsets)]).

/* call this when I want to start the debugger */
wake.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create a unique symbol, prefixed by an Atom

:- dynamic(genint/2).

unique_name( Atom, Name ) :-
	unique_name( Atom, Name, 5 ).

unique_name( Atom, Name, Size ) :-
	(retract(genint(Atom, LastAnswer )), !;
	    LastAnswer = 0),
	FirstAnswer is LastAnswer+1,
	count_to(FirstAnswer, 100000, 1, Integer),
	(nonvar(Size); Size is truncate(log(max(Integer, 1))/log(10))//1 + 1),
	name( Atom, AtomChars ),
	name( Integer, IntegerChars ),
	length( IntegerChars, LIC ),
	RealSize is min( max( LIC, Size ), 10 ),
	append( "00000000000000000", IntegerChars, PaddedIntegerChars ),
	length( TruncatedIntegerChars, RealSize ),
	append( _, TruncatedIntegerChars, PaddedIntegerChars ),
	append( AtomChars, TruncatedIntegerChars, NameChars ),
	name( Name, NameChars ),
	\+ m_class:is_part_of(Name, _),
	\+ m_class:is_connector(Name, _),
	append(NameChars, ".canvas", CanvasNameChars),
	name(CanvasName, CanvasNameChars),
	\+ state:shows_model(CanvasName, _), !,
	assert(genint(Atom, Integer)).

/* Things that are used in the eqn language but cause gnu prolog to not
load properly if they have already been declared */

/* Things to ignore temporarily */

portray(F) :-
	trim_float(F, NewF), !,
	sicstus_write_chars(NewF).

/* regular stuff : xrefs occurs inside a model structure and contains other
model structures, making them circular. It must therefore be
printed incompletely to avoid infinite loops... */

portray(xrefs(Model, _, _, _)) :-
	print(xrefs(Model,'Links')).

/* portray(sm(Model, _,_,_)) :-
	print(sm(Model)).

Improved system for outputting floating-point numbers -- max of 
decimal places (thanks to Dan Diaz for making it work with print_to_chars)
-- previously unusable due to weird bug in gprolog */

trim_float(F, Ns) :-
	float(F),
	sicstus_format_to_chars("~8g", [F], Fs),
	/* now I can catch Sicstus bogeys without crashing GNU */
	\+ member(Fs, ["Inf", "-Inf", "NaN"]),
	/* mantissa must look like float so add .0 if it doesnt */
	(member(46, Fs), !,
	    Ms = Fs;
	(append(Mant, Exp, Fs),
	        Exp = [E | _],
	        member(E, "Ee"), !;
	    Mant = Fs, Exp = []),
	    append(Mant, ".0", RMant),
	    append(RMant, Exp, Ms)),

        /* normal printing separates -ve floats from ops with a space, so...
	actually all floats are trouble if straight after a unary */
        Ns = [32 | Ms].
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% My own delete/3 which deletes one element from a list

delete_member( H, [H|T], T ).
delete_member( X, [H|T1], [H|T2] ) :-
	delete_member( X, T1, T2 ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% My own setof, which can return an empty list

sicstus_meta_predicate(any_setof( +, :, + )).

any_setof( _, Y, [] ) :-
	\+ Y.
any_setof( X, Y, Z ) :-
	setof( X, Y, Z ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% y_or_n( Term ) reads Term from the terminal and succeeds only when it is y or
% n

y_or_n( Y ) :-
	read( X ),
	( X = y ; X = n ),
	!,
	Y = X.
y_or_n( X ) :-
	write( 'Please answer y. or n.: ' ),
	y_or_n( X ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% foreach picks elements of a list and applies a metaargument.

sicstus_meta_predicate(foreach( +, +, : )).

foreach( _, [], _ ).
foreach( Var, [Head|Tail], Command ) :-
	copy_term( Var-Command, NewVar-NewCommand ),
	Var = Head,
	call( Command ),
	foreach( NewVar, Tail, NewCommand ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% wrap: utility to put arg inside a function. Typically used in all.

wrap(Arg, Functor, Function) :-
	Function =.. [Functor, Arg].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Standard format for recursion: all.

all(_, _, ArgList) :-
    all_done(ArgList).

all(Module, Pred, ArgList) :-
    split_args(Module, ArgList, FirstList, RestList),
    Step =.. [Pred | FirstList],
    call(Module:Step),
    all(Module, Pred, RestList),
    join_args(Module, FirstList, RestList, ArgList).
	
all_done([]).

all_done([Term1 | Rest]) :-
	(Term1 = build([]);
	Term1 =.. [UserFunc, _Last],
	    \+ UserFunc = build; /* but can be unify */
	Term1 =.. [_UserFunc, Limit, Limit]),
	all_done(Rest).

split_args(_, [], [], []).

split_args(Module, [Arg | Args], [First | Firsts], [Rest | Rests]) :-
	(Arg = build([First | Remains]), Rest = build(Remains);
	Arg = unify(First), Rest=Arg;
	Arg =.. [UserFunc, First],
	    \+ member(UserFunc, [build, unify]),
	    DoSplit =.. [UserFunc, First, Next],
	    call(Module:DoSplit),
	    Rest =.. [UserFunc, Next];
	Arg =.. [UserFunc, _Result, Limit],
	    Rest =.. [UserFunc, _Inter, Limit]),
	split_args(Module, Args, Firsts, Rests).

join_args(_, [], [], []).

join_args(Module, [First | Firsts], [Rest | Rests], [Arg | Args]) :-
	(Arg = build([First | Remains]), Rest = build(Remains);
	Arg = unify(First), Rest=Arg;
	Rest =.. [UserFunc, _Next],
	    \+ member(UserFunc, [build, unify]);
	Rest =.. [UserFunc, SoFar, Base],
	    DoJoin =.. [UserFunc, First, SoFar, Next],
	    call(Module:DoJoin),
	    Arg =.. [UserFunc, Next, Base]),
	join_args(Module, Firsts, Rests, Args).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% unify_all unifies its first arg with each member of the list in its second

unify_all( _, [] ).
unify_all( H, [H|T] ) :-
	unify_all( H, T ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% replace all occurrences of C1 in L1 by C2 in L2

replace_in_list( _, [], _, [] ).
replace_in_list( C1, [C1|L1s], C2, [C2|L2s] ) :-
	!,
	replace_in_list( C1, L1s, C2, L2s ).
replace_in_list( C1, [X|L1s], C2, [X|L2s] ) :-
	replace_in_list( C1, L1s, C2, L2s ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% write ordinary

write_with_breaks(Stream, Term) :-
	write_term(Stream, Term, [quoted(true), portrayed(true)]),
	write(Stream, '.'),
	nl(Stream).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% write a list of atoms one per line

writelist( [] ).
writelist( [Atom|Atoms] ) :-
	write( Atom ),
	nl,
	writelist( Atoms ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% write a list of atoms one per line to a file

writelisttofile( List , File) :-
	open(File,write,Str),
	do_writing(List,Str),
	close(Str).

do_writing([], _).

do_writing([Atom | Rest], Str) :-
	write( Str, Atom ),
	nl(Str),
	do_writing( Rest, Str ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read the above

readlistfromfile( List , File) :-
	open_native(File,read,Str),
	do_reading(List,Str),
	close(Str).

do_reading([Atom | Rest], Str) :-
	read( Str, Atom ),
	\+ Atom = end_of_file, !,
	do_reading( Rest, Str ).

do_reading([], _Str).

/* Opening files is one of the few times Prolog talks directly to the OS, so we
need to change its own ttfn encoding to utf8 */

open_native(FileTtfn, Mode, Stream) :-
	user:deEncode(_, FileTtfn, FileUtf8, _),
	open(FileUtf8, Mode, Stream).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delall deletes all occurrances of an element from a list 

delall(All, Target, Left) :-
	setof(Stays, (member(Stays, All), \+ Stays = Target), Left), !;
	Left = [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% append/2 appends a list of lists

append( [], [] ).

append( [H|T], Y ) :-
	var(H),
		raise_exception(['Very bad! Tried to concatenate list including free variable', [H|T]]);
	append( T, Z ),
	append( H, Z, Y ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

append_atoms(A1, A2, A) :-
	name(A1, S1), name(A2, S2), append(S1, S2, S), name(MA, S), A=MA.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% append_atoms/2 appends a list of atoms

append_atoms( [], '' ).

append_atoms( [H|T], Y ) :-
	var(H),
	raise_exception(['Very bad! Tried to conc-atom-ate list including free variable', [H|T]]);
	append_atoms( T, Z ),
	append_atoms( H, Z, Y ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% try/1 is a metapredicate which calls its argument, but always succeeds, even
% if the subcall fails on the first call. Backtracking into the call is not
% allowed.

:- op(450, fx, try).

sicstus_meta_predicate(try( : )).

try Call :-
	call( Call ),
	!.
try _ .

merge_lists([], L, L).

merge_lists([J | K], L, M) :-
	merge_lists(K, L, N),
	(member(J, N), !,
		M = N;
	M = [J | N]).

/* 2 arg version expects list of lists for 1st, like Geraint's
append */

merge_lists([], []).

merge_lists([H | T], Y) :-
	merge_lists(T, Z),
	merge_lists(H, Z, Y).

split_lists([], L, L).
split_lists([J | K], L, M) :-
	split_lists(K, L, N),
	delall(N, J, M).

:- dynamic(tight/2).
:- op(600, yfx, tight).

get_ground_part(OpenList, ShutList) :-
	append(ShutList, Var, OpenList),
	var(Var), !.

precedence_lower_than(Op, Prec) :-
	op(Prec, yfx, tight),
	TestExpr =.. [Op, a tight b, c],
	sicstus_write_to_chars(TestExpr, TestString),
	member(40, TestString).

get_precedence(Op, Prec) :-
	home_on_prec(Op, 0, 1200, Prec).

home_on_prec(_, Prec, Prec1, Prec1) :- 
	Prec1 is Prec + 1, !.

home_on_prec(Op, Prec1, Prec2, Prec) :-
	Mid is (Prec1+Prec2)//2,
	(precedence_lower_than(Op, Mid), !,
		home_on_prec(Op, Prec1, Mid, Prec);
	home_on_prec(Op, Mid, Prec2, Prec)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* generate_name makes previously unused names. It used to work by taking a
list of names used so far and returning a list with the new name appended
on, however new technology has led to the use of an open-ended list. The
5 argument version is for backward compatibility. */

generate_name(L, Atom, N, Used) :-
	generate_name(L, Atom, N, Used, []).

generate_name(L, Atom, UnusedName, Used, Spares) :-
	(L = c; L = tcl; L = prolog),
	    (L = prolog, !,
		[SlashNo] = "/", /* ends pathname */
	        [Space, Paren1, Paren2] = " ()", /* begins comment */
	        [I, N] = "in", /* precedes role */
	        name(Atom, AtomStr),
		(LocalStr = AtomStr; append(_, [SlashNo | LocalStr], AtomStr)),
		    \+ member(SlashNo, LocalStr),
		    (append(NameStr, [Space, Paren1 | CmtStr], LocalStr),
			(suffix([Space, I, N, Space | RoleCBStr], CmtStr),
			    append(RoleStr, [Paren2], RoleCBStr),
			    append([NameStr, "_", RoleStr], SeedStr);
			 SeedStr = NameStr), !;
		     SeedStr = LocalStr),
		     name(LocalName, SeedStr);
		LocalName = Atom),
		alphanumeric_only(LocalName, L, Name),
	ensure_unused( Name, UnusedName, Used, Spares).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ensure_unused renames a variable if it has appeared before.

/* This version allows a bunch of names with related suffixes to be reserved
-- the returned name plus the result of appending each suffix in the list */

ensure_unused(Name, NewName, Used, Spares) :-
	nuke_if_grounded(NewName),
	(Sig = ''; count_to(0, 100000, 1, N), append_atoms('_', N, Sig)),
	append_atoms(Name, Sig, NewName),
	all(utility, append_atoms,
	    [unify(NewName), build(['' | Spares]), build(ToReserve)]),
	\+ something_used_in(ToReserve, Used),
	append(ToReserve, _, NewSuffix),
	suffix(NewSuffix, Used), !.

something_used_in(Testing, Used) :-
	length(Used, _NNowUsed), !,
	nuke_unless_grounded(Testing, Used),
	member(Taken, Testing),
	member(Taken, Used).

nuke_unless_grounded(Testing, Used) :-
	ground(Used), !;
	Testing = [Name | _],
	raise_exception(['Cannot generate unique name from', Name,
			'with variable in used list!']).

nuke_if_grounded(NewName) :-
	ground(NewName),
	raise_exception(['Attempt to generate new name already instantiated to',
		NewName]);
	true.

/* count_to returns a value between the supplied min and max. We are sometimes
using it to seek for free space for new nodes; to speed things up we go in
steps of Step. */

count_to(Min, _,_, Min).

count_to(Min, Max, Step, N) :-
	count_to(Min, Max, Step, Last),
	(Last >= Max, !, fail;
	N is Last+Step).




