/* ame_types: This module contains functions that provide information about the 
fixed data types which are defined within the user interface as things the users
like to use (e.g., compartments, flows) but not within the database itself for the
moment (though they must have counterparts in the information the database contains
about mathematical properties). To put it another way, it contains all the
functions that are needed both in model_update and image. */

sicstus_module(ame_gen,
	       [get_term/3, make_nice_error_message/2, get_host/2, appears/1, 
		implicit_function/2, is_parameter/2,
		is_ghost/1, ghost_link/3, find_base/2, find_ghosts/2,
		find_reference/3,
		do_dialogue/5, substitute_in_expr/4, replace_subexps/7,
		get_actual_sizes/5, enum_type_ref/4,
		get_node_size/2, get_node_size/4,
		is_population/1, is_conditional/1, get_all_dims/2,
		variable_size/1, list_links/2,
		get_link_exits/2, get_chain/5, contains/2, contains/3,
		purge/3, generates/2, upper/2, lower/2, mybagof/3,
		list_of/3, abs_path_for/2, caption_for/2, find_name_host/2,
		find_type/2, find_all_comps/2, draws_inside/2,
		is_primitive/1, is_of_sort/2, is_class_of_sort/2]).

sicstus_use_module([library(lists), sp_only, m_class, utility, text]).

/* Full syntax error text currently not displayed because it is too
distressing to users. Not sure why I use open_chars_stream and read_term
rather than read_from_chars...oh yes it's because there is no command
that allows us to get the variable names directly from a string */

get_term(String, Term, Error) :-
	String = [], !,
		Term = '',
		Error = [];
	make_legible_for_prolog(String, ProcessedString),
	append(ProcessedString, ".", Proper_string),
/*	name(LooksLike, Proper_string), for debug */
	open_chars_stream(Proper_string, Stream),
	on_exception(Bug, read_term(Stream, Term, [variable_names(Vs)]),
		     make_nice_error_message(Bug, Error)),
	(var(Vs), !,
	    name(Term, String);
	all(user, call, [build(Vs)]),
	    Error = []).

/* make_nice_error_message: converts Prolog's syntax_error exception into
something readable. Prolog itself can do this with the print_message function,
but this always raises an exception, otherwise I could just call it using
with_output_to_chars. It's not perfect anyway, so I have consulted perror/1
(which actually does the work) to inspire what follows... */

make_nice_error_message(ThrowUp, Error) :-
	ThrowUp = syntax_error(_,_, Problem, Bits, Where), /* sicstus */
	space_elts(Problem, Desc),
	append(BitsBefore, BitsAfter, Bits),
	length(BitsAfter, Where),
	connect_bits(BitsBefore, RunUp, _),
	connect_bits(BitsAfter, WindDown, _), !,
	sicstus_format_to_chars("Attempting to decipher this entry failed, generating this diagnostic message: \"~a\". This is what was read in, with an indication of where the problem was found:\n ~w <HERE> ~w", [Desc, RunUp, WindDown], Error);
	ThrowUp = existence_error(_,_, Type, WhereLooked, _), !,
	sicstus_format_to_chars("This operation cannot proceed because the program failed to find a ~a called ~a", [Type, WhereLooked], Error);    
	ThrowUp = error(Info, _FailedOp), !, /* gnu */
	    sicstus_write_to_chars(Info, Error);
	sicstus_format_to_chars("Unexpected Prolog error message: ~w", [ThrowUp], Error).

space_elts([Elt], Elt).
space_elts([Elt | Rest], Desc) :-
	space_elts(Rest, Cont),
	append_atoms([Elt, ' ', Cont], Desc).
space_elts(Elt, Elt).

connect_bits([], '', 0).

connect_bits([Bit | More], Recon, Space) :-
	connect_bits(More, Cont, OldSpace),
	errtranslate_token(Bit, Spec, Space),
	(Space == 1, OldSpace == 1, !,
	    append_atoms([Spec, ' ', Cont], Recon);
	append_atoms(Spec, Cont, Recon)).

errtranslate_token(atom(X), X, 1) :- !.
errtranslate_token(var(_,X,_), Y, 1) :- !, name(Y, X).
errtranslate_token(number(X), X, 0) :- !.
errtranslate_token(string(X), Y, 1) :- !,
	purge(X, [0,125], NiceX),
	name(Y, NiceX).
errtranslate_token(X-_, Y, Z) :- !, errtranslate_token(X, Y, Z).
errtranslate_token(X, X, 0).

/*This function was previously called
put_zeros_before_points_not_preceeded_by_numerals_and_put_spaces_before_special_character_unary_operators,
but that implied a certainty about what it had to do which was
unjustified. I don't want to process anything in single quotes for
instance... */

make_legible_for_prolog(String, NewString) :-
	[BS, Sq, Dq, Sp, Pt, N0, Eu, El, Po, Pc, Xm, Eq] = "\\\'\" .0Ee()!=",
	Nums = "0123456789",
	append(Prefix, ToTweak, [start | String]),
	/* Do not process anything in single quotes */
	(ToTweak = [Sq | AfterQuote],
	append(InQuotes, [Sq | Suffix], AfterQuote),
	    append([Sq | InQuotes], [Sq], Tweaked);
	/* Ignore backslashes that are sometimes added by Tcl to get things
	    into list format */
	ToTweak = [BS | Suffix],
	    Tweaked = [];
	/* Put single quotes round things in double quotes so they are read as
	    atoms rather than lists of Ascii codes */
	ToTweak = [Dq | AfterQuote],
	append(InQuotes, [Dq | Suffix], AfterQuote),
	    append([Sq, Dq | InQuotes], [Dq, Sq], Tweaked);
	/* do not start a number with a point */
	ToTweak = [N, Pt | Suffix],
	\+ member(N, Nums),
		Tweaked = [N, N0, Pt];
	/* separate a unary operator from other symbols */
	ToTweak = [M, N | Suffix],
	member(M, "+-*/\\^<>=`~:.?@#$&"),	
	member(N, "-+"),
	    Tweaked = [M, Sp, N];
	/* Make sure scientific notation numbers contain point */
	ToTweak = [N, E | Suffix],
	member(N, Nums), member(E, [Eu, El]), /* must be an exponent */
	suffix([NotN | Ns], Prefix),
	\+ member(NotN, [Pt | Nums]),
	\+ member(NotN, /* if last nondigit was alpha its part of an atom */
		  "_QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm"),
	\+ (member(Num, Ns), \+ member(Num, Nums)),
	    Tweaked = [N, Pt, N0, E];
	/* If a function has no args, pop in an empty atom */
	ToTweak = [Po, Pc | Suffix],
	    Tweaked = [Po, Sq, Sq, Pc];
	/* Enclose the operator != in single quotes: leading space in result is
	to work around a great steaming googly-moogly of a bug in Sicstus which
	causes an integer other than 1 or -1 followed by '! in a string to be
	interpreted as end-of-file. Gnu doesn't like it either... */
	ToTweak = [Xm, Eq | Suffix],
	    Tweaked = [Sp, Sq, Xm, Eq, Sq]), !,
	make_legible_for_prolog(Suffix, NewSuffix),
	append([Prefix, Tweaked, NewSuffix], [start | NewString]);	
	NewString = String.

get_host(Object, Visible) :-
	Object = Visible, \+ implicit_function(_, Visible);
	implicit_function(Visible, Object).

appears(Object) :-
	(Drawable = bounding_box; Drawable = course),
	Object has_graphical_attribute Drawable of _,
	\+ implicit_function(_, Object),
	\+ (Object is_connector from Node to Self,
		implicit_function(Self, Node)).

implicit_function(Exp_node, Imp_node) :-
	Arc is_connector from Imp_node to Exp_node,
	Arc has_type influence,
	Imp_node has_class function.
	
/* interface for ghost property to rest of program. To test for ghosthood, use 'is_ghost' -- this returns the start and finish of a ghost link. To find the 'real' node for a given node, use find_base -- if the given node is real, it will be returned. Ghost_link can be used to determine the display status of links, and find_ghosts will return all the ghosts
of a given base node. (Ghost relationship only exists between an absolute base node and its ghosts -- ghost-to-ghost links should be done away with!) */

:- op(500, xfy, is_of_sort).

is_ghost(Ghost) :-
	find_base(Ghost, Base),
	\+ Ghost = Base.

/* Now links can have multiple roles, a ghost link is one that is not an
implicit-explicit link or part of an influence chain. */

ghost_link(Link, Base, Ghost) :-
	Link has_type influence,
	connects(Link, Base, Ghost),
	influence_makes_ghost(Base),
	influence_makes_ghost(Ghost),
	\+ (terminates(Link, NonGhost),
	       \+ influence_makes_ghost(NonGhost)).

/* influence_makes_ghost: the type of node between which influences indicate
ghost relationships, i.e., a visible one other than a submodel. */

influence_makes_ghost(Component) :-
	Component is_of_sort has_function,
	appears(Component).

find_base(Ghost, Base) :-
	Ghost has_type flow, !,
	((sequence(Base, Ghost); Base = Ghost; sequence(Ghost, Base)),
	    implicit_function(Base, FlowFn),
	    (FlowFn has_class_refinement value of _Val;
		_Incoming is_connector from _Source to FlowFn), !;
	(sequence(Base, Ghost); Base = Ghost),
	\+ sequence(_, Base));
/*	find_name_host(Ghost, Base); */
	Ghost is_of_sort has_function,
	Link is_connector from NextUp to Ghost,
	Link has_type influence,
	\+ NextUp has_class function,
	initiates(Link, NextBase), !,
	   find_base(NextBase, Base);
	Base = Ghost.

find_ghosts(Base, Ghost) :-
	Base has_type flow, !,
	(implicit_function(Base, FlowFn),
	    FlowFn has_class_refinement value of _Val, !,
      	    (sequence(Base, Ghost); sequence(Ghost, Base));
	\+ sequence(_, Base),
	sequence(Base, Ghost));
	Link is_connector from Base to _,
	ghost_link(Link, Base, Ghost).

/* test for whether node is an input parameter, i.e., something
	that would normally have a function, but without any kind of
	input link. Result is 1 if yes, 0 if no, -1 if type cannot be one. */

is_parameter(Node, Val) :-
	\+ Node is_of_sort can_be_input, !,
	    Val = -1;
	appears(Node),
	    Node is_of_sort has_function,
	    \+ implicit_function(Node, _ImpFunc), !,
	    (Node has_class_refinement param_type of file, !,
		Val = 2;
	    Val = 1);
	Val = 0.

/* New system for preserving relationships between model entities when they are saved and restored: references to other entities are saved in an attribute called References, which is adjusted when the model is re-read. Other attributes refer to remote entities only by their position in this list.

find_reference matches an entity to its position in the list, adding it to the list if it is not there. Old version kept a list with each object -- new one refers recursively up the tree to the point at which the referred relation is connected.

find_reference(Object, Index, Remote) :-
	Object has_attribute references of RemoteList,
		(append(Prefix, [Remote | _], RemoteList),
			length(Prefix, Index), !;
		append(RemoteList, [Remote], NewList),
			length(RemoteList, Index),
			Object has_changed_attribute references to NewList);
	Index = 0,
		Object has_new_attribute references of [Remote].

Note new version puts parent references first to minimize the chance of
disruption due to new/deleted submodels */

find_reference(Object, Index, Remote) :-
	Object has_class submodel,
	(Parent has_part Object,
	    find_reference(Parent, ParentIndex, Remote),
	    Label = ancestor(ParentIndex);
	(nonvar(Remote), /* speed hack - do not search outgoing links */
	    Remote is_connector from Object to _,
	      Remote has_type relation,
	      initiates(Remote, Object);  
	  Remote is_connector from _ to Object,
	      Remote has_type relation,
	      terminates(Remote, Object)),
	    Label = local(Remote)),
	(Object has_model_refinement references of RemoteList,
		(nth0(Index, RemoteList, Label);
		\+ member(Label, RemoteList),
		    append(RemoteList, [Label], NewList),
		    length(RemoteList, Index),
		    Object has_changed_model_refinement references of NewList);
	Index = 0,
		Object has_new_model_refinement references of [Label]).


/* do_dialogue: Takes a string to display and a list of button identifiers, and puts up a modal dialogue box containing them. The last value is the identifier of the button that was hit to end the dialogue. */

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
do_dialogue(Header, Icon, Blurb, Buttons, Response) :-
	output:safe_tcl_eval(['ShowMessage', br(chars(Header)), Icon,
			  br(chars(Blurb)), Buttons], Feedback),
	name(Response, Feedback).

make_button_strings([], []).

make_button_strings([B1 | B], [S1 | S]) :-
	S1 = br(write(B1)),
	make_button_strings(B, S).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* the following functions can be included in AME expressions but are not
recognized by Prolog unless we tell it about them...
*/
:- op(300, yfx, ['**', '^']).

/* :- op(500, fx, ['!']).
Works but buggers up GNU prolog (do after loading?) */
:- op(500, fx, [not]).

:- op(700, yfx, ['<=']).

:- op(700, yfx, ['=\\=', '!=', =:=]).

:- op(750, yfx, ['&&', and]).

:- op(800, yfx, ['||', or, xor]).

:- op(850, xfy, [?, :, then, else, elseif]).

:- op(900, fx, [if]).

/* replace_variables is going to be the use_anywhere function to refer to the
variables used in an AME expression, replacing all sorts of horrible disparate
code that used to be dotted all over. It will take an expression, and return a
list of all the things that appear in the role of AME variables, each of them 
paired with Prolog variables, and a matching expression containing those in place
of the AME variables.

This also swaps any size expressions for the actual sizes, crashing if they are 
out of date. 

30/3/98: It now leaves local variables in.
Jan 99 : replaced by a general purpose subexpression substituter.
Sep 99 : middle arg added to specify top_down or bottom_up */

replace_subexps(Expr, TestModule, Test, Data, Dir, AllVarPairs, FinalExpr) :-
	(Dir = top_down,
	RunTest =.. [Test, Data, Expr, MidExpr, Recurse],
	call(TestModule:RunTest), !,
	(Recurse = 1,
	    replace_subexps(MidExpr, TestModule, Test, Data, Dir,
			    MorePairs, NewExpr),
	    merge_lists([var_pair(Expr, NewExpr)], MorePairs, VarPairs);
	Recurse = 0,
	    NewExpr = MidExpr,
	    VarPairs = [var_pair(Expr, NewExpr)]);
	(atomic(Expr); var(Expr); Expr = size(_); Expr = size(_,_)), !,
		VarPairs = [],
		NewExpr = Expr;
	Expr = [_ | _], !,
		replace_all_subexps(Expr, TestModule, Test, Data, Dir,
				    VarPairs, NewExpr);
/*	(Expr = (if Cond then Exp1 elseif SubExp2),
			Exp2 = (if SubExp2);
	Expr = (if Cond then Exp1 else Exp2)), !,
		replace_all_subexps([Cond, Exp1, Exp2], TestModule, Test, Data,
				Dir, VarPairs, [V1, V2, V3]),
		NewExpr = (if V1 then V2 else V3);
*/	Expr = (Lambda=SubExpr,Tail), !,
	    replace_all_subexps([Lambda, SubExpr, Tail], TestModule, Test,
				Data, Dir, ParamPairs,
				[NewLambda, NewSubExpr,NewTail]),
		clobber_local_vars(ParamPairs, Lambda, VarPairs),
		NewExpr = (NewLambda=NewSubExpr,NewTail);
	Expr =.. [Op | Args],
		replace_all_subexps(Args, TestModule, Test, Data, Dir,
				    VarPairs, NewArgs),
		NewExpr =.. [Op | NewArgs]),
	(Dir = bottom_up,
	RunTest =.. [Test, Data, NewExpr, FinalExpr, Recurse],
	call(TestModule:RunTest), !, /* never recurse on bottom-up */
	[var_pair(NewExpr, FinalExpr) | VarPairs] = AllVarPairs;
	AllVarPairs = VarPairs,
	    FinalExpr = NewExpr).

replace_all_subexps(Args, TestModule, Test, Data, Dir,
		    VarPairs, NewArgs) :-
	all(ame_gen, replace_subexps, [build(Args), unify(TestModule),
				       unify(Test), unify(Data), unify(Dir),
				       append(VarPairs, []),
				       build(NewArgs)]).

clobber_local_vars([], _, []).

clobber_local_vars([var_pair(Lambda, _) | Rest], Lambda, NewRest) :-
	!, clobber_local_vars(Rest, Lambda, NewRest).

clobber_local_vars([A | B], Lambda, [A | C]) :-
	clobber_local_vars(B, Lambda, C).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* This takes a list of dimensions including some which are specified in terms of
numbers of submodel instances, and translates those that can be translated,
stripping out those which cannot, or which correspond to non-disaggregated
submodels. */

get_actual_sizes(_, [], [], [], any).

get_actual_sizes(Node, [Sub | Rest], AllNs, AllSizes, Units) :-
	get_actual_sizes(Node, Rest, MoreNs, Sizes, MoreUnits),
	(Sub = none, AllNs = MoreNs, AllSizes = Sizes, Units = MoreUnits;
	enum_type_ref(Sub, Node, Num, Units0),
	    AllNs = [Num | MoreNs],
	    AllSizes = [Sub | Sizes],
	    inters:promote_unit(Units0, Units),
	    inters:promote_unit(MoreUnits, Units);
	(Sub = size(ModName); Sub = size(ModName, Ind)),
	    (setof(Size_source, name_matches(Size_source, ModName), Sources), !,
		(Sources = [Source], !,
		    get_node_size(Source, RealN, RealSize, Units0),
		    (var(Ind), !,
			append(RealN, MoreNs, AllNs),
			append(RealSize, Sizes, AllSizes);
		    nth(Ind, RealN, UseN),
		    nth(Ind, RealSize, UseSize),
			AllNs = [UseN | MoreNs],
			AllSizes = [UseSize | Sizes]),
		    inters:promote_unit(Units0, Units),
		    inters:promote_unit(MoreUnits, Units);
		    raise_exception(['Cannot resolve reference to size of ',
			Size_source,
			'. There are multiple submodels of this name.']));
		raise_exception(['Cannot resolve reference to size of ',
			ModName, '. There is no submodel of this name']))), !.

name_matches(Node, Name) :-
	Node has_class submodel,
	caption_for(Node, Name).

enum_type_ref(Ref, Model, Value, Units) :-
	(integer(Ref),
	    Units = const_int;
	Ref = var, 
	    Units = int;
	number(Ref),
	    Units = real), !,
	    Value = Ref;
	nth0(Value, ['"false"', '"true"'], Ref), !,
	    Units = boolean;
	resolve_enum_type(Ref, Model, Value, Units).

resolve_enum_type(Ref, Model, Value, Units) :-
	m_class:Model has_class_refinement enum_types of TypeList,
	    member(TypeName-TypeMems, TypeList),
	    (Match = TypeName; nth(Value, TypeMems, Match)),
	    append_atoms(['"', Match, '"'], Ref),
	    append_atoms(['"', TypeName, '"'], TypeRef),
	    (number(Value),
		Units=a(TypeRef);
	    length(TypeMems, Value),
		Units=n(TypeRef)), !;
	m_class:Parent has_part Model,
	    resolve_enum_type(Ref, Parent, Value, Units).
	
get_node_size(Source, Size) :-
	get_node_size(Source, _, Size, _).

get_node_size(Source, SizeN, Size, SizeUnits) :-
	Source has_class_refinement multiplication_spec of Multi,
	member(count=Dim, Multi),
	get_actual_sizes(Source, Dim, SizeN, Size, SizeUnits), !,
	(\+ member(var, Size), !;
	caption_for(Source, Capt),
	    sicstus_format_to_chars("~a has a reference to a variable membership model in its dimensions.", [Capt], Wibble),
	    name(Wobble, Wibble),
	    raise_exception(Wobble));
	Size = [].

/* This returns all the array bounds associated with a submodel in the
canonical order, i.e., those accessed by the highest index numbers first. */

get_all_dims(Source, AllDims) :-
	variable_size(Source), !,
	    AllDims = [var];
	get_node_size(Source, AllDims).
	
/* Purge removes all elements of the 2nd arg from the 1st leaving the 3rd.
It uses the database so templates which match many different elements
can be used. */

:- dynamic(purging/1).

purge(P, Unwanted, Pure) :-
	assert(purging(Unwanted)),
	purge_data(P, Pure).

purge_data(P, Pure) :-
	purging(Unwanted),
	member(Found, Unwanted),
	select(Found, P, Rest), !,
		purge_data(Rest, Pure);
	Pure = P,
	    retract(purging(Unwanted)).

get_link_exits([], []).

get_link_exits([Link | Rest], [exits(Link, Exits) | LaterStarts]) :-
	Link is_connector from Source to _,
	terminates(Link, Dest),
	get_chain(Source, Dest, _, Exits, _),
	get_link_exits(Rest, LaterStarts).

get_chain(Start, Finish, Top, Up_list, Down_list) :-
	contains(Finish, Start, Up_list), !,
		Top = Finish,
		Down_list = [];
	find_all_comps(P2, Finish),
		get_chain(Start, P2, Top, Up_list, Down_rest),
		Down_list = [Finish | Down_rest].

contains(Big, Small) :-
	contains(Big, Small, _).

contains(Big, Small, Chain) :-
	Big = Small,
		Chain = [];
	nonvar(Small), !,
		find_all_comps(Dad, Small),
		contains(Big, Dad, Chain2),
		Chain = [Small | Chain2];
	nonvar(Big),
		find_all_comps(Big, Son),
		contains(Son, Small, Chain2),
		append(Chain2, [Big], Chain).

variable_size(Source) :-
	is_population(Source);
	is_conditional(Source).

/* list_links returns the starting arcs of relations terminating on a
node. They are sorted so those with the highest indices (most recently
added) are put first and hence to the outer loops. Sort is done
Geraint stylie! But no-one will make 46 assocs to a node...*/

list_links(Node, Links) :-
	setof(Link-Index,
	      (find_reference(Node, Index, Link),
		  /* Bring references to ancestor model links up-to-date
		  but do not use them */
		  terminates(Link, Node)),
	      RefPairs),
	permutation(RefPairs, InIndexOrder),
	\+ (append(_, [_-WeeI | Rest], InIndexOrder),
	       member(_-BigI, Rest),
	       WeeI < BigI), !,
	get_base_sections(InIndexOrder, Links);
	Links = [].

get_base_sections([Arc-_ | Refs], [BaseArc | Links]) :-
	initiates(Arc, Base),
	(BaseArc = Arc; sequence(BaseArc, Arc)),
	BaseArc is_connector from Base to _, !,
	get_base_sections(Refs, Links).

get_base_sections([], []).

is_population(Node) :-
	Node has_class_refinement multiplication_spec of Spec,
	member(type=population, Spec).

is_conditional(Node) :-
	Link is_connector from _ to Node,
	Link has_type relation,
	terminates(Link, Node), !; /* all assoc models are vm */
	Node has_part Query,
	find_type(Query, condition).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
substitute_in_expr(Tail, Lambda,SubExpr, SubbedExpr) :-
	replace_subexps(Tail, ame_gen, swap_matches, Lambda=SubExpr,
			top_down, _, SubbedExpr).

swap_matches(Old=New, Old, New, 0).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* list_of/3 takes an item and returns a list of it of the given length.*/

list_of(Item, Length, Result) :-
	length(Result, Length),
	prefix(Result, [Item | Result]).

/* lower/2: turns uppercase letters in a string to lowercase */

lower([], []).

lower([L | R], [_l | _r]) :-
	(L > 64, L < 91, !,
		_l is L + 32;
	_l = L),
	lower(R, _r).

upper([], []).

upper([L | R], [_l | _r]) :-
	(L > 96, L < 123, !,
		_l is L - 32;
	_l = L),
	upper(R, _r).

/* One of the more hideous features of Prolog is that bagof fails rather than returning an empty list if there is nothing to put in the bag. Whoever decided on such a twisted feature could not have had the faintest idea what Prolog is for. The following predicate repairs it. */

mybagof(A, B, C) :-
	bagof(A, B, C), !;
	C = [].

abs_path_for(Node, Path) :-
	Dad has_part Node,
	\+ Dad is_root,
	caption_for(Dad, DadsName), !,
		abs_path_for(Dad, Start),
		name(Start, StartStr),
		name(DadsName, EndStr),
		append(StartStr, [47 | EndStr], PathStr),
		name(Path, PathStr);
	Path = ''.

/* To find the caption for a node, we have to check for ghosthood both before and
after making sure we are referencing the node that appears on the screen.

Links are never ghosts, but all sections are captioned after the last section in
the highest-level model */

:- op(500, xfy, draws_inside).

caption_for(Comp, ID) :-
	image:get_host(Comp, CompVisDest),
	find_base(CompVisDest, CompVisSrc),

	(CompVisSrc has_class_refinement name of ID, !;
	(CompVisSrc has_type relation, !,
	    find_name_host(CompVisSrc, NameSource);
	NameSource = CompVisSrc),
	NameSource has_attribute name of ID, !;
	ID = ' ').

find_name_host(CompVisSrc, NameSource) :-
	equivalent_arcs(CompVisSrc, NameSource),
	NameSource draws_inside TopModel,
	\+ (sequence(Other, NameSource),
		Other draws_inside HigherModel,
		\+ contains(TopModel, HigherModel);
	sequence(NameSource, Other),
		Other draws_inside LevelModel,
		contains(LevelModel, TopModel)).

find_type(Obj, Type) :-
	Obj has_class Type;
	Obj has_type Type.

/* This needs some go-faster stripes! */
Link draws_inside Parent :-
	nonvar(Link), !,
	home_to_node(Link, Node),
	Parent has_part Node;
	Parent has_part Node,
	chain_from_node(Node, Link).

home_to_node(Link, Node) :-
	Link is_connector from _ to Next,
	(home_to_node(Next, Node), !;
	    Next = Node).

chain_from_node(Node, Link) :-
	Last is_connector from _ to Node,
	(Link = Last;
	    chain_from_node(Last, Link)).

/* Previous version; didn't work well when both args specified,
and too flash anyway...

	when((nonvar(Parent); nonvar(Node)), 
		Parent has_part Node),
	when((nonvar(Link); nonvar(Source)),
		Link is_connector from Source),
	(Source is_connector from Node; 
		Source = Node).
*/

find_all_comps(Parent, Comp) :-
	Parent has_part Comp;
	Comp draws_inside Parent.

:- op(450, xf, is_primitive).

Type is_primitive :-
	member(Type, [compartment, function, variable, cloud,
		      flow, influence, relation, alarm,
		      condition, creation, immigration, reproduction, loss]).

:- op(500, xfy, is_class_of_sort).

/* slightly rewritten because it turned out to be very speed-critical */

Obj is_class_of_sort Class :-
	member(Obj-SortList,
		[variable-[regular_box, box, has_function, can_be_input],
		function-[regular_box, box, can_be_input],
		compartment-[rectangle, elongated_box, box, 
				has_function, can_be_input, level],
		submodel-[rounded_rect, elongated_box, box],
		flow-[line, connection, has_function],
		influence-[line, curved, connection, captionless],
		relation-[line, curved, connection],
		cloud-[cloud, regular_box, box, captionless],
		alarm-[regular_box, box, rectangle, channel, has_function,
			   boolean_value],
		condition-[regular_box, box, rectangle, channel, has_function,
			   boolean_value],
		creation-[regular_box, box, rectangle, channel, has_function,
			  value_outside],
		immigration-[regular_box, box, rectangle, channel, 
				has_function, level, value_outside],
		reproduction-[regular_box, box, rectangle, channel, 
				has_function, level],
		loss-[regular_box, box, rectangle, channel, has_function]]),
	member(Class, SortList).

Obj is_of_sort Sort :-
	find_type(Obj, Type),
	Type is_class_of_sort Sort.
