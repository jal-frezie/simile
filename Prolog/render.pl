/*******************************************************************************
**** COMPILATION module. This module contains all the templates necessary   ****
**** to compile AME code. Everything is parameterised by language, BASIC    ****
**** being the starting point.                                              ****
*******************************************************************************/

sicstus_module( render, [render/5, excrete/5, make_assignment/4, render_all/5, 
		get_empty_list/2,
		refer_value/3, refer/3, make_expr/3, make_increment_expr/4,
		make_struct_reference/4, make_indexed_reference/4,
		put_in_context/6, ptr_compare/4,
		combine/4, make_arg_string/3, 
		make_pointer/3, resolve_pointer/3, 
		make_constant_list/3, get_element_ref/4,
		make_integer/3, command_substitute/3,
			 generate_all_case_entries/4,
		generate_data_decls/7, make_procedure_call_chars/3] ).

sicstus_use_module( [sp_only, m_class, utility, ame_gen, units, text,
utility, library(lists)] ).

/* make_assignment uses print_to_codes so the expression gets 
portrayed -- we need to do this here so numbers can be formatted
*and* spaced to avoid operator/negation clashes like x--2 */

make_assignment(L, Dest, Source, AssignStr) :-
	(L = tcl, Template = "set ~a ~a";
	L = c, Template = "~a = ~a"),
	print_to_codes(SourceStr, Source),
	sicstus_atom_chars(SourceAtm, SourceStr),
	sicstus_format_to_chars(Template, [Dest, SourceAtm], AssignStr).

/* assignment of context */
make_pointer(c, Var, Ptr) :-
	sicstus_format_to_chars("&(~w)", [Var], PtrStr),
	name(Ptr, PtrStr).
make_pointer(tcl, Var, Var).

make_indexed_namespace(L, Base, Indices, Result) :-
	L = c,
	    make_indexed_reference(L, Base, Indices, Result);
	L = tcl,
	    make_list_context_id(tcl, Indices, BraceTerm),
	    sicstus_format_to_chars("~w<~w>", [Base, BraceTerm], ResultStr),
	    name(Result, ResultStr).

declare_pointer(c, Var, Res) :-
	resolve_pointer(c, Var, Res).

declare_pointer(tcl, Var, Var).

resolve_pointer(c, Var, Res) :-
	sicstus_format_to_chars("*~a", [Var], ResStr),
	name(Res, ResStr).

resolve_pointer(tcl, Var, Res) :-
	refer_value(tcl, Var, Res).

make_increment_expr(L, Current, Step, Expr) :-
	(L = c,
		(Step = 1, !,
			sicstus_format_to_chars("++~w", [Current], Expr);
		Step = -1, !,
			sicstus_format_to_chars("--~w", [Current], Expr);
		sicstus_format_to_chars("~w += ~w", [Current, Step], Expr));
	L = tcl,
		(Step = 1, !,
			sicstus_format_to_chars("incr ~w", [Current], Expr);
		sicstus_format_to_chars("incr ~w ~w", 
				[Current, Step], Expr))).

ptr_compare(L, Ptr1, Ptr2, Expr) :-
	L = c,
	    Expr = (Ptr1 '!=' Ptr2);
	L = tcl,
	    make_procedure_call_chars(L, [string, compare, Ptr1, Ptr2],
				      ExprStr),
	    name(Expr, ExprStr).

make_cons_dest(instance(Type, Sym, _, Name, _), ConLines, DeLines) :-
	Type = submodel,
	variable_size(Sym), !,
	    make_assignment(c, Name, 0, SubConLine),
	    append(["        ", SubConLine, ";"], ConLineStr),
	    name(ConLine, ConLineStr),
	    ConLines = [ConLine],
	    render(c, procedure_call, delete_list(Name), 8, DeLines);
	by_record(Sym), !,
	    render(c, assign_space, Name= [_, Name,_,_, [0]], 8, ConLines),
	    render(c, release_space, [Name,_,_], 8, DeLines); 
/*	Type = external, !,
	    Nm = elt(_, Name, _),
	    make_constant_string(c, Sym, SymC),
	    make_procedure_call_chars(c, [fetch_instance, SymC], FetchStr),
	    name(Fetch, FetchStr),
	    render(c, assignment, Name=Fetch, 8, ConLine),
	    render(c, procedure_call, discard_instance(Name), 8, DeLine);
*/	[ConLines, DeLines] = [[], []].

count_base_ptrs([], 0).
count_base_ptrs([base(_,_, Ptrs) | More], N) :-
	length(Ptrs, Here),
	count_base_ptrs(More, M),
	N is M+Here.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% render converts proglog atoms or terms float valid expressions in the named
% programming language. Used names are not duplicated

/* c and tcl rendition functions are organized by their purpose */

/* free memory; nothing need be done in c because the structures are permanent
rather than malloced...not any more! I'll have to add this later. */

/* comment */
render( c, comment, Comment, Indent, [Atom]) :-
         sicstus_format_to_chars("~*s/* ~w */", [Indent," ",Comment], CharList),
         name( Atom, CharList ).
/* tcl comment starts with a ; in case goes after a command */
render( tcl, comment, Comment, Indent, [Atom]) :-
         sicstus_format_to_chars( "~*s;# ~w", [Indent," ",Comment], CharList ),
         name( Atom, CharList ).

/* formatting to string
render(c, format, [Dest, Pattern | Args], Indent, Result) :-
	make_constant_string(c, Pattern, PatternStr),
	name(PatternConst, PatternStr),
	Call =.. [sprintf, Dest, PatternConst | Args],
	render(c, procedure_call, Call, Indent, Result).
render(tcl, format, [Dest, Pattern | Args], Indent, Result) :-
	make_procedure_call_chars(tcl, [format, Pattern | Args], CallString),
	name(Call, CallString),
	render(tcl, assignment, Dest=Call, Indent, Result).

Incrementation, including unity incrementation and decrementation. */

/* start of a for loop */
render( L, for_start, [Name,End,Step], Indent, [For_Start]) :- 
	make_assignment(L, Name, 1, Init),
	refer_value(L, Name, NameRef),
	make_increment_expr(L, Name, Step, Incr),
	(L = c, Template = "~*sfor ( ~s; ~w; ~s ) {";
	L = tcl, Template = "~*sfor {~s} {~w} {~s} {"),
	(Step > 0, !, Test = (End >= NameRef);
	    Test = (NameRef >= End)),
	sicstus_format_to_chars( Template,
		   [Indent," ",Init, Test, Incr], StartChars ),
	name( For_Start, StartChars ).

/* start of a procedure */
render( L, procedure_start, Call, Indent, [Proc_Start]) :-
	Call =.. [call, RetType, Proc_name | Args],
	make_param_string(L, Args, Arg_string),
	(L = c,
		sicstus_format_to_chars( "~*s~w ~w (~s) {", 
				[Indent," ",RetType,Proc_name, Arg_string],
				 StartChars );
	L = tcl,
		sicstus_format_to_chars( "~*sproc ~w  {~s} {", 
				[Indent," ",Proc_name, Arg_string], StartChars )),
	name( Proc_Start, StartChars ).

/* Bits common to all model classes: public-access con- and destructor. */
render(c, public_cons_dest,
       instance(submodel, _, xrefs(model(_, Subs), _,_,_), _,
		ClassName-_), Indent, PubConDe) :-
	InIndent is Indent+4,
	sicstus_format_to_chars( "~*spublic:", [Indent," "], PubStr),
	sicstus_format_to_chars( "~*s~w () {", [InIndent," ",ClassName], ConsHd),
	sicstus_format_to_chars( "~*s~~~w () {", [InIndent," ",ClassName], DestHd),
	all(render, make_cons_dest,
	    [build(Subs), append(ConLines, []), append(DeLines, [])]),
	render(c, end(procedure), structor, InIndent, [EndStr]),
	name(Pub, PubStr),
	name(Cons, ConsHd),
	name(De, DestHd),
	append([[Pub, Cons | ConLines], [EndStr, De | DeLines], [EndStr]],
	       PubConDe).

/* end of any kind of loop */
render( L, end(Loop), Name, Indent, [For_End]) :-
	member(Loop, [for, while, switch, case, class, cond, procedure,
		      declaration, namespace, catch, if]),
	render(L, comment, end(Loop,Name), 0, [IdComment]),
	(L = c, Format = "~*s}; ~a"; L = tcl, Format = "~*s} ~a"),
	sicstus_format_to_chars( Format, [Indent," ", IdComment], CharList ),
	name( For_End, CharList ).

render(L, procedure_call, DataFunc, Indent, Line) :-
	DataFunc =.. Data,
	make_procedure_call(L, Data, CallString),
	render(L, function, CallString, Indent, Line).

render(L, function, Act, Indent, [Line]) :-
	list_of(32, Indent, Leader),
	(L = tcl, append(Leader, Act, CharList);
	L = c, append([Leader, Act, ";"], CharList)),
	name(Line, CharList).

/* This process for making a class declaration in c actually sticks close
to the nature of a class, rather than the nature of a submodel. The latter
is supplied by making it a subclass of a base submodel class, if necessary. */

render(c, class_declaration, Instance, Indent, ClassDecl) :-
	Instance = instance(submodel, SymbolicName, _,_, Name-_),

	(nonvar(SymbolicName), !,
	    sicstus_format_to_chars( "~*sclass ~w : public ~atype {",
			 [Indent, " ", Name, submodel], HeaderStr),
	    render(c, public_cons_dest, Instance, Indent, PublicHeads);
	sicstus_format_to_chars( "~*sclass ~w {", [Indent, " ", Name], HeaderStr),
	    PublicHeads = ['public:']),
	name(Line1, HeaderStr),
	sicstus_format_to_chars("}; /* end(class,~w) */", [Name], EndStr),
	name(End, EndStr),

	append([submodel_decls, '', Line1 | PublicHeads],
	       [proc_decls, End], ClassDecl).
	
/* pointer declaration for a given type
render(L, pointer_declaration, instance(submodel, SmName, _, Name, Type-_),
       Indent, Rest) :-
	do_loop_pointers(L, SmName, Type, Name, Temps),
	render_all(L, variable_declaration, Temps, Indent, Rest).
*/
/* next clause generates nested namespace declarations for tcl. They look as
if the nested loops use the same counter variable, but this is OK because each
loop is in a different namespace... */

render(tcl, class_declaration,
       instance(NodeType, SymbolicName, _, Name, _), Indent, Decl) :-
	NodeType = submodel, !,
	    ((variable_size(SymbolicName); by_record(SymbolicName)), !,
		append_atoms(Name, maker, ProcName),
		render(tcl, procedure_start,
		       call(_, ProcName, [_, instance]), Indent, Opens),
		render(tcl, end(procedure), ProcName, Indent, ProcCloses),
		NewIndent is Indent + 4,
		sicstus_format_to_chars("~*sreturn [namespace current]",
					[NewIndent, " "], ExitMakerStr),
		name(ExitMaker, ExitMakerStr),
		Closes = [ExitMaker, CloseNS | ProcCloses],
		refer_value(tcl, instance, Target);
	    get_node_size(SymbolicName, What, _,_),
		make_array_assignment(tcl, Indent, What, _,
				      NewIndent, _, Indices, Opens, ArrCloses),
		Closes = [CloseNS | ArrCloses],
		make_indexed_namespace(tcl, Name, Indices, Target)),
	    declare_namespace(Target, Indent, ClassDecl),
	    append(FillNS, [CloseNS], ClassDecl),
	    append([Opens, FillNS, Closes], Decl);
	Decl = [].

render(L, break, _, I, [Result]) :-
	list_of(32, I, Spacing),
	member([L, Inst], [[c, "break;"], [tcl, "break"]]),
	append(Spacing, Inst, ResultStr),
	name(Result, ResultStr).

render(c, release_memory, Var, Indent, [Result]) :-
	sicstus_format_to_chars("~*sdelete ~a;", [Indent, " ", Var], ResultStr),
	name(Result, ResultStr).

render(tcl, release_memory, Pointer, Indent, [Result]) :-
	resolve_pointer(tcl, Pointer, Zap),
	sicstus_format_to_chars("~*snamespace delete ~a",
			[Indent, " ", Zap], ResultStr),
	name(Result, ResultStr).

% needs render cos is used in constructor
render(c, assign_space, Dest=[_, Name, _,_, Dims], Indent, [Result]) :-
	squarify_dims(Dims, DimAtom),
	sicstus_format_to_chars("~*s~a = new ~atype~a;",
	       [Indent," ", Dest, Name, DimAtom], ResultStr),
	name(Result, ResultStr).

% needs render cos is used in destructor
render(c, release_space, [Var, _Count, _Used], Indent, [Line]) :-
	sicstus_format_to_chars("~*sdelete [] ~a;", [Indent, " ", Var],
				LineStr),
	name(Line, LineStr).

% excrete: replacement for render which writes directly to pipe and
% does not clutter the atom table

start_comment(c, Stream) :- write(Stream, '/* ').
start_comment(tcl, Stream) :- write(Stream, ';# ').
end_comment(c, Stream) :- write(Stream, ' */'), nl(Stream).
end_comment(tcl, Stream) :- nl(Stream).

strings_direct(L, comment, Comment, Indent, Stream) :-
	format(Stream, "~*s", [Indent, " "]),
	start_comment(L, Stream),
	write(Stream, Comment),
	end_comment(L, Stream).

/* Things that do not appear at all in certain languages; generate for one in
which they do, and add as comments. */

strings_direct( Target, NotNeeded, Variable, Indent, Stream) :-
	member([NotNeeded, Target, Translation],
			[[duplicate_context, c, tcl],
			 [global_declaration, c, tcl],
			 [clear_memory, c, tcl],
			 [public_cons_dest, tcl, c],
			 [end(class), tcl, c]]),
	start_comment(Target, Stream),
	strings_direct(Translation, NotNeeded, Variable, Indent, Stream),
	end_comment(Target, Stream).

strings_direct(tcl, clear_memory, instance(submodel,_,_, Name, _-Dims), Indent, 
	       Stream) :-
	(number(Dims), !,
	    NewIndent is Indent + 4,
	    excrete(tcl, for_start, [makenames, Dims, 1], Indent, Stream),
	    refer_value(tcl, makenames, VWithDollar),
	    make_struct_reference(tcl, Name, VWithDollar, SpaceName);
	NewIndent = Indent,
	    SpaceName = Name),
	format(Stream, "~*snamespace delete ~w\n", [NewIndent," ", SpaceName]),
	(\+ number(Dims), !;
	excrete(tcl, end(for), makenames, Indent, Stream)).

/* assignment */
strings_direct(L, assignment, Dest=Source, Indent, Stream) :-
	(L = c, Fmt = "~*s~a = ~w;\n";
	    L = tcl, Fmt = "~*sset ~a ~w\n"),
	format(Stream, Fmt, [Indent, " ", Dest, Source]).

strings_direct(L, open_context, Pointer=[_, _, MPTargetRef], Indent1, Stream) :-
	strings_direct(L, assignment, Pointer=MPTargetRef, Indent1, Stream).

strings_direct(L, enter_context, NewPointer=[CurrentPointer, Struct, Indices],
		Indent, Stream) :-
	(CurrentPointer = '', !,
	    Base = Struct;
	make_struct_reference(L, CurrentPointer, Struct, Base)),
	all(language, aim_at_array, [unify(L), build(Indices), build(Offs)]),
	make_indexed_namespace(L, Base, Offs, Target),
	strings_direct(L, make_reference, NewPointer=Target, Indent, Stream).

/* this creates a reference to a value in a deep context. */

strings_direct( L, make_reference, Dest=Source, Indent, Stream) :-
	refer(L, Source, SourceRef),
	strings_direct( L, assignment, Dest=SourceRef, Indent, Stream).

strings_direct(tcl, assign_space, Dest=[Top, Struct, Indices, Used, Dims],
	       Indent, Stream) :-
	Dims = [Dim | More], !, % won't work for multiple dims but no need
	    language:declare(tcl, XIndex, loop, int, Used, Indent, Stream),
	    DeepIndent is Indent+4,
	    strings_direct(tcl, for_start, [XIndex, Dim, 1],
			   Indent, Stream),
	    refer_value(tcl, XIndex, XIndexRef),
	    make_indexed_namespace(tcl, Dest, [XIndexRef], NewDest),
	    append(Indices, [XIndexRef], AllIndices),
	    strings_direct(tcl, assign_space, NewDest=[Top, Struct, AllIndices,
						       Used, More],
			   DeepIndent, Stream),
	    excrete(tcl, end(for), XIndex, Indent, Stream);
	append_atoms(Struct, maker, ProcName),
	    make_struct_reference(tcl, Top, ProcName, CurrentName),
	    make_indexed_namespace(tcl, Struct, Indices, Target),
	    make_procedure_call_chars(tcl, [CurrentName, Target], MakerStr),
	    name(Maker, MakerStr),
	    strings_direct(tcl, assignment, Dest = Maker, Indent, Stream).

strings_direct(L, increment_by, [Current, Step], Indent, Stream) :-
	make_increment_expr(L, Current, Step, ActionStr),
	excrete(L, function, ActionStr, Indent, Stream).

strings_direct(tcl, global_declaration, [_, Name | _], _Indent, Stream) :-
	format(Stream, "global ~a\n", [Name]).

strings_direct(L, variable_declaration, [Unit, Name, Dims | Init],
	       Indent, Stream) :-
	(nonvar(Dims), !;
	Dims = [],
	    strings_direct(L, comment, 'Next field had undefined dims',
			   0, Stream)),
	type_for_unit(Unit, Type),
	(member(-1, Dims), !; /* no null arrays please */
	Init = [], !,
	    (L = c,
		(Dims = void, Counts = [''];
                Counts = Dims),
		make_indexed_reference(L, Name, Counts, ArrayName),
		format(Stream, "~*s~a ~a;\n", [Indent, " ", Type, ArrayName]);
	    L = tcl,
		format(Stream, "~*svariable ~a\n", [Indent, " ", Name]));
	Init = [InitialValues],
	    (L = c,
/* if var is a char string, it will not be nested so no curlies will be added,
and the rules for breaking lines are like tcl's (need a \ at end) so... */
	        (Unit = char, !,
		    PrepStyle = tcl,
		    DeepIndent = 0;
		PrepStyle = L,
		    DeepIndent is Indent + 4),    
		(Dims = void, Counts = [''];
%		all(render, boost, [build(Dims), build(Counts)]),
                Counts = Dims),
		make_indexed_reference(L, Name, Counts, ArrayName),
		format(Stream, "~*s~a ~a = ", [Indent, " ", Type, ArrayName]),
		swap_squares_for_curlies(PrepStyle, InitialValues, Stream),
		format(Stream, ";\n", []);
	    L = tcl,
		format(Stream, "~*svariable ~a\n", [Indent, " ", Name]),
		assign_initial_values(Name, InitialValues, Indent, Stream))).

strings_direct(L, data_declaration,
		instance(NodeType, SymbolicName, _, NameIn, Type-Dims),
		Indent, Stream) :-
	(NodeType = submodel, !,
	    NameIn = NameBase,
	    ((variable_size(SymbolicName); by_record(SymbolicName)), !,
			/* variable length submodel - declare a pointer */
		declare_pointer(L, NameBase, Name),
		UseDims = [];
	    Name = NameBase,
		/* get_node_size(SymbolicName, UseDims) */ UseDims = Dims);
	    (NameIn = elt(_, Name, _), !;
		Name = NameIn),
	    UseDims = Dims),
	all(ame_gen, enum_type_ref, [build(UseDims), unify(SymbolicName),
				     build(Nums), build(_), build(_)]),
	strings_direct(L, variable_declaration, [Type, Name, Nums],
			Indent, Stream).

/* start of a for loop */
strings_direct( L, for_start, [Name,End,Step], Indent, Stream) :- 
	make_assignment(L, Name, 1, Init),
	refer_value(L, Name, NameRef),
	make_increment_expr(L, Name, Step, Incr),
	(L = c, Template = "~*sfor ( ~s; ~w; ~s ) {\n";
	L = tcl, Template = "~*sfor {~s} {~w} {~s} {\n"),
	(Step > 0, !, Test = (End >= NameRef);
	    Test = (NameRef >= End)),
	format(Stream, Template, [Indent," ",Init, Test, Incr]).

/* start of a while loop */
strings_direct( L, while_start, Expr, Indent, Stream) :-
	(L = c, Fmt = "~*swhile ( ~w ) {\n";
	    L = tcl, Fmt =  "~*swhile {~w} {\n"),
	format(Stream, Fmt, [Indent," ", Expr]),
	ContDent is Indent+4,
	refer_value(L, this, ThisRef),
	strings_direct(L, procedure_call, abort_check(ThisRef), ContDent,
		       Stream).

strings_direct(L, switch_start, Condition, Indent, Stream) :-
	make_expr(L, Condition, ConditionExpr),
	(L = c, Template = "~*sswitch (~w) {\n";
	L = tcl, Template = "~*sswitch ~w {\n"),
	format(Stream, Template, [Indent, " ", ConditionExpr]).

strings_direct(L, case_start, Match, Indent, Stream) :-
	(L = c, Template = "~*scase ~w:\n";
	L = tcl, Template = "~*s~w {\n"),
	format(Stream, Template, [Indent, " ", Match]).

strings_direct(L, case_end, Match, Indent, Stream) :-
	(L = c, Template = "~*sbreak; // end(case,~w)\n";
	L = tcl, Template = "~*s} ;# end(case,~w)\n"),
	format(Stream, Template, [Indent, " ", Match]).

strings_direct(L, if_start, ConditionExpr, Indent, Stream) :-
	L = c, !,
	    format(Stream, "~*sif (~w) {\n", [Indent, " ", ConditionExpr]);
	L = tcl, !,
	    format(Stream, "~*sif {~w} {\n", [Indent, " ", ConditionExpr]).

strings_direct(L, else_clause, Cond, Indent, Stream) :-
	format(Stream, "~*s} else { ", [Indent, " "]),
	excrete(L, comment, Cond, 0, Stream).

strings_direct(L, function, Act, Indent, Stream) :-
	list_of(32, Indent, Leader),
	(L = tcl, append(Leader, Act, CharList);
	L = c, append([Leader, Act, ";"], CharList)),
	sicstus_write_chars(Stream, CharList), nl(Stream).

strings_direct(L, procedure_call, DataFunc, Indent, Stream) :-
	DataFunc =.. Data,
	make_procedure_call(L, Data, CallString),
	strings_direct(L, function, CallString, Indent, Stream).

strings_direct(tcl, release_space, [Dest, Dim, Used], Indent, Stream) :-
	language:declare(tcl, XIndex, loop, int, Used, Indent, Stream),
	DeepIndent is Indent+4,
	excrete(tcl, for_start, [XIndex, Dim, 1], Indent, Stream),
	refer_value(tcl, XIndex, XIndexRef),
	make_indexed_namespace(tcl, Dest, [XIndexRef], NewDest),
	resolve_pointer(tcl, NewDest, Zap),
	format(Stream, "~*snamespace delete ~a\n", [DeepIndent, " ", Zap]),
	excrete(tcl, end(for), XIndex, Indent, Stream).

excrete(L, Stat, Args, Indent, Stream) :-
	strings_direct(L, Stat, Args, Indent, Stream), !;
	do_obsolete_thing(L, Stat, Args, Indent, Stream), fail; true.

do_obsolete_thing(L, Stat, Args, Indent, Stream) :-
	render(L, Stat, Args, Indent, Stuff), !,
	do_writing(Stuff, Stream);
	raise_exception(failed_to_do_obsolete_thing(Stat,Args)).

/*
do_base_pointers(_, base(_,_, []), []).
do_base_pointers(L, base(instance(submodel,_, xrefs(_, Parent, _,_),_, Type-_),
		       _, [Ptr | Ptrs]), [[Type, BasePtd, []] | Rest]) :-
	declare_pointer(L, Ptr, BasePtd),
	do_base_pointers(L, base(Parent, _, Ptrs), Rest).
*/
do_loop_pointers(L, SmName, Type, Name, Late) :-

/*	append_atoms(Name, pointer, Ptr),
	declare_pointer(L, Ptr, Ptd), */
	(variable_size(SmName), !,
	    append_atoms(Name, meta, Meta),
	    declare_pointer(L, Meta, MetaPtd),
	    declare_pointer(L, MetaPtd, MetaPtdPtd),
	    append_atoms(Name, cond, Cond),
	    Late = [[int, Cond, []], [Type, MetaPtdPtd, []]];
	Late = []).

squarify_dims([], '').
squarify_dims([D | More], Atom) :-
	squarify_dims(More, Tail),
	append_atoms(['[', D, ']', Tail], Atom).
	
generate_all_case_entries(_,_, [], _).
generate_all_case_entries(L, Match, [Inst | Insts], Stream) :-
	generate_case_entry(L, Match, Inst, Stream),
	NewMatch is Match+1,
	generate_all_case_entries(L, NewMatch, Insts, Stream).

generate_case_entry(L, Match, Inst, Stream) :-
	Inst = instance(InstType, BaseName, _, NameIn, _-LocalDims),
%	\+ InstType = internal, no metadata for internals
	excrete(L, case_start, Match, 8, Stream),

	(NameIn = elt(_, Name, _), !;
	    Name = NameIn),
	((InstType = submodel, variable_size(BaseName);
	  L = tcl, Name = instanceid), !,
	    Item = Name;
	(by_record(BaseName), !,
	    DimCount = 1;
	length(LocalDims, DimCount)),
	refer_value(L, dims, DimsRef),
	make_procedure_call_chars(L, [step_list, DimsRef, 2], SubStr),
	name(Subscript, SubStr),
	list_of(Subscript, DimCount, Subs),
	(InstType = submodel, !,
	    make_indexed_namespace(L, Name, Subs, Item);
	make_indexed_reference(L, Name, Subs, Item))),
	
	refer(L, Item, ItemRef),
	(by_record(BaseName), !,
	    % if dims is REQ_COUNT, point to made count and return
	    resolve_pointer(L, dims, DimPtr),
	    make_procedure_call_chars(L, [requests_record_count, DimPtr], CStr),
	    name(Cond, CStr),
	    excrete(L, if_start, Cond, 8, Stream),
	    % advance dims past REQ_COUNT -- stops burrow_to iterating
	    excrete(L, procedure_call, step_list(DimsRef, 2), 12, Stream),
	    append_atoms(Name, made, MadeCount),
	    make_indexed_reference(L, MadeCount, [], Count),
	    refer(L, Count, CountRef),
	    excrete(L, procedure_call, return(CountRef), 12, Stream),
	    excrete(L, else_clause, Cond, 8, Stream),
	    excrete(L, procedure_call, return(ItemRef), 12, Stream),
	    excrete(L, end(if), Cond, 8, Stream);
	excrete(L, procedure_call, return(ItemRef), 8, Stream)),
	excrete(L, case_end, Match, 8, Stream).

generate_data_decls(L, Dims, Path, Inst, Used, NodeData, Stream) :-
	Inst = instance(InstType, BaseName, _, NameIn, Unit-_),
	(NameIn = elt(_, Name, _), !;
	    Name = NameIn),
	( /* InstType = external, !, Type = 'EXTERNAL',
	        [Wee, Muckle] = [0, 0],
	    (member(make(_,_,_,_, [int_eval_submodel(_, arr(_, Name, _), _)]),
		    ExtSets), !,
		DefEval = 'EXOGENOUS';
	     member(make(_,_,_,_, [ext_eval_submodel(_, arr(_, Name, _), _)]),
		    ExtSets), !,
		DefEval = 'SPLIT';
		DefEval = 'DERIVED'); */
	    InstType = submodel, !, Type = 'VALUELESS',
	        [Wee, Muckle] = [0, 0],
	        (by_record(BaseName), !,
		    DefEval = 'TABLE';
		    DefEval = 'SPLIT');
	    (member(Unit, [boolean, cond_spec]), Type = 'FLAG',
	        [Wee, Muckle] = [0, 1];
	    Unit = a(Enum), !, Type = Posn,
		/* In the past, 'ENUMERATED' was replaced by Posn, which is
		a number from -10 down indicating the data structure in the
	        executable corresponding to the actual enumerated type. */
		Wee = 1,
		enum_type_ref(Enum, BaseName, Muckle, _, Posn);
	    member(Unit, [const_int, int]), !, Type = 'INTEGER',
	        [Wee, Muckle] = [-268435455, 268435455];
		/* limits for GNU integers; Sicstus can go further */
	    Type = 'REAL',
	        [Wee, Muckle] = [-1.0e100, 1.0e100]),

	    ( /*member(make(_,_,_,_, [assign(arr(_, Name, _), _)]), ExtSets), !,
		DefEval = 'EXOGENOUS'; */
		DefEval = 'DERIVED')),
	is_parameter(BaseName, PType),
	(PType = -1, Eval = DefEval;
	nth0(PType, [DefEval, 'INPUT', 'TABLE'], Eval)),
	
	append(Path, [0], NewPath),
	append(Dims, [0], CappedDims), 

	/* Try not doing internals -- but will we need to for save/restore
	 state? init functions confuse sketch graph editing. */
	(\+ member(InstType, [internal, loss]),
	get_host(BaseName, VisName),
	find_type(VisName, VisType),
	\+ (InstType = init_function,
	       member(VisType, [immigration, reproduction])), !,
/*	    caption_for(VisName, CaptionTail),
	    (VisName is_of_sort value_outside, !,
		Pop has_part VisName,
		caption_for(Pop, CaptionHead),
		append_atoms([CaptionHead, '/', CaptionTail], Caption);
	    CaptionTail = Caption),
	    name(Caption, CaptionTtfnStr),
	    user:all_ttfn_to_utf8(CaptionTtfnStr, CaptionUtf8Str),
	    name(UseCaption, CaptionUtf8Str),
*/	    member(VisType-Class, [submodel-'SUBMODEL',
				   variable-'VARIABLE',
				   compartment-'COMPARTMENT',
				   flow-'FLOW',
				   condition-'CONDITION',
				   alarm-'ALARM',
				   creation-'CREATION',
				   reproduction-'REPRODUCTION',
				   immigration-'IMMIGRATION',
				   loss-'LOSS']),
	    ( % nth(GraphPointer, GraphOwners, [BaseName | _]), !;
	    nth(GraphPointer, Used, Name), !;
	    GraphPointer = 0),

	    (BaseName has_class_refinement min_val of Min, 
		number(Min), !;
	    Min = Wee),
	    (BaseName has_class_refinement max_val of Max, 
		number(Max), !;
	    Max = Muckle),

	    /* Now do what needs with the enumerated types */
	    (InstType = submodel, /* do not include types for externals */
	        DescAttr = desc, !;
	      DescAttr = description),
	    (BaseName has_class_refinement enum_types of TypeList, !;
		TypeList = []),
	    length(TypeList, ETCount),
	    (ETCount = 0, !,
		MetaPtr = 'NULL';
	    all(render, make_runtime_enum_data,
		[unify(L), build(TypeList), unify(Used),
		 build(ETPtrs), unify(Stream)]),
		append_atoms(Name, '_ets', ETPtrName),
		generate_name(L, ETPtrName, MetaPtr, Used),
		excrete(L, variable_declaration, ['enum_type_data', MetaPtr,
					     [ETCount], ETPtrs], 0, Stream)),
	    % same thing for ghost references
	    (setof(ConstPair,
		  Ghost^Base^(BaseName has_part Ghost,
			      is_ghost(Ghost),
			      find_base(Ghost, Base),
			      all(render, make_constant_string,
				  [unify(L), build([Ghost, Base]),
				   build(ConstPair)])), GBList), !,
		length(GBList, GBCount),
		append_atoms(Name, '_ghosts', GBPtrName),
		generate_name(L, GBPtrName, GRefPtr, Used),
		excrete(L, variable_declaration, ['ghost_ref_data', GRefPtr,
					     [GBCount], GBList], 0, Stream);
	      GBCount = 0,
		GRefPtr = 'NULL'),

	    /* do something similar for any strings that need including */
	    all(render, make_runtime_string,
		[unify([L, Name, Used]),
		 build([VisName, BaseName, VisName, VisName]),
		 build([name, spec, DescAttr, comment]),
		 build(StringPtrs), unify(Stream)]),
		/* make a value lookup entry for each node with this value */
	    NodeData = [[VisName, Type, ETCount, MetaPtr, GBCount, GRefPtr,
			 Eval, CappedDims, NewPath, GraphPointer,
			 StringPtrs, Min, Max, Class, Name]];
	/* No need to handle ghosts and link terminators */
	NodeData = []).

make_runtime_enum_data(L, Name-Mems, Used, [ETCount, NamePtr, ETPtr],
		       Stream) :-
	EltPtrs = [NamePtr | MemPtrs],
	append_atoms(Name, '_mems', ETTag),
	generate_name(L, ETTag, ETPtr, Used),
	all(utility, append_atoms,
	    [build([Name | Mems]), unify('_txt'), build(EltNames)]),
	all(utility, generate_name,
	    [unify(L), build(EltNames), build(EltPtrs), unify(Used)]),
	all(render, templatify,
	    [unify(L), build([Name|Mems]), build(EltPtrs), build(VTemplates)]),
	length(Mems, ETCount),
	append(VTemplates, [['char*', ETPtr, [ETCount], MemPtrs]], Templates),
	all(render, excrete,
	    [unify(L), unify(variable_declaration), build(Templates),
	     unify(0), unify(Stream)]).

make_runtime_string([L, Name, Used], Node, Field, Ptr, Stream) :-
	(Field = name, !,
	    caption_for(Node, LocalStr),
	    (Node is_of_sort value_outside, !,
		Pop has_part Node,
		caption_for(Pop, CaptionHead),
		append_atoms([CaptionHead, '/', LocalStr], FullStr);
		FullStr = LocalStr);
	  Node has_class_refinement Field of FullStr,
	        atomic(FullStr)),
	templatify(L, FullStr, Ptr, Decl),
	    append_atoms([Name, '_', Field], PtrTag),
	    generate_name(L, PtrTag, Ptr, Used),
	    excrete(L, variable_declaration, Decl, 0, Stream);
	Ptr = 'NULL'.

templatify(L, Elt, Ptr, [char, Ptr, void, QElt]) :-
	name(Elt, TtfnStr),
	user:all_ttfn_to_utf8(TtfnStr, Utf8Str),
	name(Utf8Atom, Utf8Str),
	make_constant_string(L, Utf8Atom, QElt).
				     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_array_assignment/9: all subscripts other than those for submodel loops and
those used for referring to individual array elements are generated and put in
for loops here. */

make_array_assignment(_, I, [], _, I, [], [], [], []).

make_array_assignment(L, Indent, [Sub | Rest],
		Used, FinalIndent, Temps, [Index | Indices], Opens, Closes) :-
	NewIndent is Indent + 4,

	generate_name(L, loop, Temp, Used),
	add_temps(Temps0, [Temp], int, [], Temps),
	refer_value(L, Temp, Index),
	render(L, for_start, [Temp, Sub, 1], 
			Indent, Opens1),
	render(L, end(for), Index, Indent, Closes2),
	make_array_assignment(L, NewIndent, Rest, Used,
			FinalIndent, Temps0, Indices, Opens2, Closes1),
	append(Opens1, Opens2, Opens),
	append(Closes1, Closes2, Closes).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* add_temps/5: Takes a list of variable declaration templates, a list of new
variable names, a type and a dimension list, and returns the augmented list of 
templates. */

add_temps(Temps, [], _, _, Temps).

add_temps(OldTemps, [Var | Vars], Type, Dims, [[Type, Var, Dims] | Rest]) :-
	add_temps(OldTemps, Vars, Type, Dims, Rest).

declare_namespace(Target, Indent, [Line2, submodel_decls,
				   proc_decls, LastButOne]) :-
	sicstus_format_to_chars("~*snamespace eval ~w {",
			[Indent, " ", Target], Line2string),
	name(Line2, Line2string),
	render(tcl, end(namespace), Target, Indent, [LastButOne]).

%boost(P, Q) :- Q is P+1.

/* prepend_spaces puts indent blanks on strings and turns them to atoms */

prepend_spaces([], _, []).

prepend_spaces([H|T], Gap, [H2 | T2]) :-
	append(Gap, H, Line),
	name(H2, Line),
	prepend_spaces(T, Gap, T2).

get_empty_list(L, NewList) :-
	L = c,
		make_procedure_call_chars(L, ['Tcl_NewListObj', 0, 'NULL'], NewListStr),
		name(NewList, NewListStr);
	L = tcl,
		NewList = {}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* assign_initial_values does for tcl what the facility to initialize a variable
when it is declared does for c. This takes the var name (1), a list of initial 
values (2), a set of array bounds (4) and a progress count through the first (3)
and returns a set of assignments to initialize the variables (6).

The list of init vals is in list-of-lists format to match the way initialization
works in c, though this is untested for multidimensionals. */

assign_initial_values(Var, Val, Indent, Stream) :-
	atomic(Val), !,
	    excrete(tcl, assignment, Var=Val, Indent, Stream);
	make_tcl_array_set([], Val, List),
	    name(Var, VarStr),
	    format(Stream, "array set ~s ", [VarStr]),
	    swap_squares_for_curlies(tcl, List, Stream),
	    nl(Stream).
	
make_tcl_array_set(Inds, Val, Done) :-
	atomic(Val), !,
	    comma_separate(Inds, IndCsvStr),
	    name(IndCsv, IndCsvStr),
	    Done = [IndCsv, Val];
	% tcl constant arrays start at index
	make_tcl_array_elts(Inds, 1, Val, Done).

make_tcl_array_elts(_,_, [], []).
make_tcl_array_elts(Inds, N, [Val | Rest], Done) :-
	append(Inds, [N], MoreInds),
	make_tcl_array_set(MoreInds, Val, SetVal),
	M is N+1,
	make_tcl_array_elts(Inds, M, Rest, SetRest),
	append(SetVal, SetRest, Done).

swap_squares_for_curlies(L, ListList, Stream) :-
	make_arg_string(L, [ListList], NestStr),
	split_lines(L, NestStr, Stream).

/* split_lines(NestStr, [String | Strings]) :-
	[Br, C] = "},",
	append(Start, [Br, C | Rest], NestStr),
		append(Start, [Br, C], String), !,
		split_lines(Rest, Strings);
	String = NestStr, 
		Strings = [].
*/

split_lines(L, NestStr, Stream) :-
	(L = c, [Br, C] = "},";
	    L = tcl, [Br, C] = "} "),
	append(Start, Rest, NestStr),
	length(Start, Len),
	(append(String, "\n", Start);
	 (Len > 30,
	     suffix([Br, C], Start);
	  Len > 300,
	     suffix([C], Start)),
	 (L = c, String = Start;
	  L = tcl, append(Start, "\\", String))), !,
		    format(Stream, "~s\n", [String]),
		    split_lines(L, Rest, Stream);
	format(Stream, "~s", [NestStr]).

/*
This was wrong on two counts; first, it was inefficient, secondly it picked the
shortest line consistent with its rules.

OK this should pick the line closest to the ideal length of about 60 chars, and
do the biz really efficiently -- not finished yet

split_lines(L, NestStr, [String | Strings]) :-
	[Br, C, Sp, Nl, Sl] = "}, \n\\",
	(L = tcl, member([Out, In, Min],
			 [[[Nl | Rest], [], 0],
			  [[Br, Sp | Rest], [Br, Sp, Sl], 30],
			  [[Sp | Rest], [Sp, Sl], 300]]);
	L = c, member([Out, In, Min],
			 [[[Nl | Rest], [], 0],
			  [[Br, C | Rest], [Br, C], 30],
			  [[C | Rest], [C], 300]])),
	append(Base, Out, NestStr),
	length(Base, Len),
	Len >= Min, !,
	    append(Base, In, String),
	    split_lines(L, Rest, Strings);
	String = NestStr,
	    Strings = [].
*/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% render_all applies render to a list of items of a given type
/* should replace with all(render) */

render_all( _, _, [], _, []).

render_all( Language, Type, [Atom|Atoms], Indent, FinalResults) :-
	render( Language, Type, Atom, Indent, Result),
		render_all( Language, Type, Atoms, Indent, Results),
		append( Result, Results, FinalResults ).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_list_context_id; in cases where the context is
identified by a list of indices rather than just one, this
makes one that is empty if list is empty, normal if list has
one element and either an arg string or a list instruction if
there are lots */

make_list_context_id(L, RefIndices, ContextId) :-
	RefIndices = [],
		ContextId = '';
	RefIndices = [ContextId], !;
	RefIndices = [_ | _],
	(L = c,
		make_arg_string(L, RefIndices, ContextIdStr);
	L = tcl,
		make_procedure_call_chars(L, [list | RefIndices],
				ContextIdStr)),
		name(ContextId, ContextIdStr).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
make_arg_string(_, [], []).

make_arg_string(L, [Arg], String) :- 
	make_list_chars(L, Arg, String), !;
	sicstus_write_to_chars(Arg, String), !.

make_arg_string(L, [Arg | Rest], Arg_string) :-
	make_arg_string(L, [Arg], String),
	make_arg_string(L, Rest, Tail),
	(L = c,
		append(String, [44,32 |Tail], Arg_string);
	L = tcl,
		append(String, [32 | Tail], Arg_string)), !. /* green */

build_constant(Language, [String, Type, ETCount, ETArrPtr, GBCount, GBArrPtr,
			  Eval, Dims, Array, GraphPtr, Captions, Min, Max,
			  Class, _Comment], Chars) :-
	make_list_chars(Language, Dims, DimsString),
	make_list_chars(Language, Array, ArrayString),
	make_constant_string(Language, String, Arg1),
%	make_constant_string(Language, Caption, Arg5),
	make_list_chars(Language, Captions, PtrString),
	name(Arg2, DimsString),
	name(Arg3, ArrayString),
	name(Arg5, PtrString),
	make_list_chars(Language, [Arg1, Type, ETCount, ETArrPtr,
				   GBCount, GBArrPtr, Eval,
				   Arg2,Arg3, GraphPtr, Min, Max, Class, Arg5],
			Chars).
/* 	render(Language, comment, Comment, 0, [CommentWd]),
	name(CommentWd, CommentStr),
Comment string removed because it interferes with list mode
	append(BaseChars, [32 | CommentStr], Chars). */

make_constant_list(_, [], []).

make_constant_list(L, [Const | Rest], [Line | Lines]) :- 
	build_constant(L, Const, String),
	name(Line, String),
	make_constant_list(L, Rest, Lines).

make_constant_string(L, String, Atom) :-
	name(String, Chars),
	(L = tcl,
		((member(Naughty, [10,32,34]); member(Naughty, Chars)), !,
			append([123 | Chars], [125], Const);
		Const = Chars);
	L = c,
	    all(render, escape_string_breaks,
		[build(Chars), append(StraightChars, [])]),
		append([34 | StraightChars], [34], Const)),
	name(Atom, Const).

escape_string_breaks(With, Without) :-
	member(With-Without, [10-[92,110,92,10], 34-[92,34], C-[C]]), !.

make_param_string(_, [], []).

make_param_string(L, [Param], String) :- !,
	Param = [Unit, Arg],
	type_for_unit(Unit, Type),
	(L = c,
	    
		sicstus_format_to_chars("~w ~w", [Type, Arg], String);
	L = tcl,
		name(Arg, String)).

make_param_string(L, [Param | Rest], Arg_string) :-
	make_param_string(L, [Param], String),
	(L = c, Interstice = ", "; L = tcl, Interstice = " "),
	make_param_string(L, Rest, Tail),
	append([String, Interstice, Tail], Arg_string).

make_list_chars(L, List, Result) :-
	make_arg_string(L, List, Contents),
	append([123 | Contents], [125], Result).

make_procedure_call_chars(L, List, Result) :-
	make_procedure_call(L, List, Contents),
	command_substitute(L, Contents, Result).

command_substitute(c, Fn, Fn).
command_substitute(tcl, Contents, Result) :-
	append([91 | Contents], [93], Result).

make_procedure_call(tcl, List, Result) :-
	make_arg_string(tcl, List, Result).

make_procedure_call(c, [Proc | Args], Result) :-
	make_arg_string(c, Args, ContentsStr),
	sicstus_atom_chars(Contents, ContentsStr),
	sicstus_format_to_chars("~w(~a)", [Proc, Contents], Result).

get_element_ref(L, Array, Index, Result) :-
	Index = pop, !,
	    (L = c,
		make_indexed_reference(L, Array, [0], Result);
	    L = tcl,
		refer_value(L, Array, Result));
	L = c,
	    make_indexed_reference(L, Array, [Index], Result);
	L = tcl,
	    refer_value(L, Array, ArrayRef),
	    sicstus_format_to_chars("[lindex ~w ~w]", [ArrayRef, Index], ResChars),
	    name(Result, ResChars).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_struct_reference/4: Takes language, an expression which should have a
structure pointer assigned to it and a variable name, and returns an expression that can
be used to refer to that variable within the structure. Might be tricky to
inplement in BASIC. In Tcl, a structure is the same as a namespace */

make_struct_reference(c, Struct, Var, Result) :-
	Struct = '', !,
	    Result = Var;
	(sicstus_format_to_chars("~w->~w", [Struct, Var], ResultStr),
	    \+ prefix("*", ResultStr);
	sicstus_format_to_chars("(~w)->~w", [Struct, Var], ResultStr)), !,
	name(Result, ResultStr).

make_struct_reference(tcl, Struct, Var, Result) :-
	Struct = '', !,
	    Result = Var;
	(name(Struct, StructStr),
	    cannot_be_dollared(StructStr), !,
	    Format = "[set ~w]::~w";
	Format = "${~w}::~w"),
	sicstus_format_to_chars(Format, [Struct, Var], ResultStr),
	    name(Result, ResultStr).

% this variant makes pointers to members if name is ptr(x) --
% used for building arg lists for external procedures
msr_with_ptrs(L, Struct, Var, Result) :-
	Var = ptr(RealVar), !,
	    make_struct_reference(L, Struct, RealVar, OrigResult),
	    refer(L, OrigResult, Result);
	make_struct_reference(L, Struct, Var, Result).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_indexed_reference/4: Takes a language, array variable and subscript
term, and makes a reference to an array element. This is the same as the last one
in Tcl */

make_indexed_reference(_, Base, [], Base) :- !.

make_indexed_reference(L, Struct, Indices, Result) :-
	L = c,
	    Indices = [Inner | Rest],
	    sicstus_format_to_chars("~w[~w]", [Struct, Inner], MidStr),
	    name(Mid, MidStr),
	    make_indexed_reference(L, Mid, Rest, Result);
	L = tcl,
	    comma_separate(Indices, IndListStr),
	    sicstus_atom_chars(IndList, IndListStr),
	    sicstus_format_to_chars("~w(~a)", [Struct, IndList], ResultString),
	    name(Result, ResultString).

comma_separate([Solo], Str) :-
	sicstus_write_to_chars(Solo, Str), !.

comma_separate([F | R], Str) :-
	comma_separate(R, Str2),
	sicstus_write_to_chars(F, Str1), !,
	append([Str1, ",", Str2], Str).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* refer_value: used to make tcl variable references out of their names 
(by adding a $ sign). If name already contains a dollar sign,
uses the'set' construct instead. Only works forward. */

refer_value(Language, Expr, Result) :-
	Language = c, Result = Expr;
	Language = tcl, 
	    name(Expr, Str1),
	    (cannot_be_dollared(Str1), !,
		append(["[set ", Str1, "]"], Str2);
	    Str2 = [36 | Str1]),
	    name(Result, Str2).

/* refer: for indirect references. Goes straight through in Tcl, but makes
pointer in c. */

refer(Language, Expr, Result) :-
	Language = tcl, Result = Expr;
	Language = c, make_pointer(Language, Expr, Result).

cannot_be_dollared(Str) :-
	member([OpenPar, ClosePar], ["()", "[]"]),
	(append(Base, [OpenPar | Rest], Str),
	append(_Sub, [ClosePar | Tail], Rest), !,
	    append(Base, Tail, DoneHere);
	DoneHere = Str),
	member(Separator, "$<>"),
	member(Separator, DoneHere).

type_for_unit(Unit, Type) :-
	(Unit = real; get_conversion(_, Unit, Unit, _)), !,
	    Type = double;
	member(Unit, [boolean, cond_spec]), !,
	    Type = 'BOOLEAN';
	member(Unit, [const_int, a(_ET), n(_ET)]), !,
	    Type = int;
	Type = Unit.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_expr/3: Takes an expr and renders it into the language. Should handle all 
expression funnies from the models. Tcl expressions are the same as c ones except 
they have that rather quaint [expr ....] wrapper. This requires that all atoms
already appear in their final forms, it does not try to sub them. */

make_expr(c, Expr, Expr).
make_expr(tcl, Expr, Result) :-
	atomic(Expr), !, 
		Result = Expr;
	sicstus_format_to_chars("[expr ~w]", [Expr], Result_string),
		name(Result, Result_string).

make_expr_all(_, [], []).

make_expr_all(Language, [Expr0 | Expr], [Result0 | Result]) :-
	make_expr(Language, Expr0, Result0),
	make_expr_all(Language, Expr, Result).

combine( L, Op, VArgs, Atom) :-
	make_expr_all(L, VArgs, VArgExprs),
	(
/*	Op = (?), L = tcl, !,
	    VArgs = [VCond, VTrue:VFalse],
	    sicstus_format_to_chars("[if {~w} {expr ~w} else {expr ~w}]",
			    [VCond, VTrue, VFalse], CharList);
	    
Yes, horrible, nasty, ugly, repugnant, grotesque Tcl has the a?b:c format but,
mindbogglingly stupidly, evaluates the non-chosen half, and, worse, complains
about undefined array elements in it. Blooaaargh!!

	Op = choose, !,
		(L = c,
			sicstus_format_to_chars("(~w?~w:~w)", VArgs, CharList);
		L = tcl,
			sicstus_format_to_chars("[if {~w} {expr ~w} else {expr ~w}]",
					VArgs, CharList));
	  
Or so I thought. As it happens, if the programmer isn't a complete
moron, he writes 'expr {a?b:c}' rather than 'expr a?b:c', thus
ensuring only the true half is evaluated. */
	
	Op = choose, !,
	  (L = c,
	      sicstus_format_to_chars("(~w?~w:~w)", VArgs, CharList);
	   L = tcl,
	      sicstus_format_to_chars("[expr {~w?~w:~w}]", VArgs, CharList));
/*
What follows is even worse; it allows conditionals to be entered in the 
if-then-elseif-else format, though I can't see why anyone would want to.

Since this causes problems anyway (due to inters and contexts) it's all
obsolete. A stopgap conversion to a?b:c format is in place, pending the
incorporation of the actual conditionality into program generation

	Op = if,
		(L = c,
			sicstus_format_to_chars("(~w)", VArgs, CharList);
		L = tcl,
			sicstus_format_to_chars("[if ~w]",
					VArgs, CharList));

	Op = elseif,
		(L = c,
			sicstus_format_to_chars("~w:(~w)", VArgs, CharList);
		L = tcl,
			sicstus_format_to_chars("{expr ~w} else {if ~w}",
					VArgs, CharList));

	Op = then,
		(L = c,
			sicstus_format_to_chars("~w?~w", VArgs, CharList);
		L = tcl,
			sicstus_format_to_chars("{~w} ~w",
					VArgs, CharList));

	Op = else,
		(L = c,
			sicstus_format_to_chars("~w:~w", VArgs, CharList);
		L = tcl,
			sicstus_format_to_chars("{expr ~w} else {expr ~w}",
					VArgs, CharList));
			
furthermore, Tcl lacks the min and max operators although there are perfectly
good ones in c... Now, 4/8/98 sees new Tcl interpretations of Boolean relations, to
aid lazy evaluation as is done for Choose... */

	Op = rand,
		(L = tcl; L = c),
			make_procedure_call_chars(L, [ame_rand | VArgExprs], CharList);
	L = tcl,
		(inters:use_tcl_proc_for(Op),
			make_procedure_call_chars(L, [Op | VArgExprs], CharList);
		member(Op, [and, ',', '&&']),
			sicstus_format_to_chars("[if {~w} then {expr ~w} else {expr 0}]",
					VArgs, CharList);				
		member(Op, [or, ';', '||']),
			sicstus_format_to_chars("[if {~w} then {expr 1} else {expr ~w}]",
					VArgs, CharList))),

	!, name(Atom, CharList);

/* Heres a sticky botch...some models are written for modelling environments that
quietly stick in a huge but finite value when you, say, divide by zero. With 
the next few lines in place, and math_protect asserted, AME will do the same.

	state:math_protect,
	(Op = (/),
		VArgs = [Nom, Div],
		Test = '==0',
		Atom = double(Nom)/NewDiv;
	Op = (//),
		VArgs = [Nom, Div],
		Test = '==0',
		Atom = int(Nom)/int(NewDiv);
	(Op = log; Op = log10),
		VArgs = [Div],
		Test = '<=0',
		Atom =.. [Op, NewDiv]), !,
			sicstus_format_to_chars("((~w)~w?1e-100:(~w))", [Div, Test, Div],
					NewDivName),
			name(NewDiv, NewDivName);

   Enough of these; I might need to do pow(a,b) and perhaps others too.
   Now to exorcise the demon of integer division... */
	Op = (/), !,
	    VArgs = [Nom, Div],
	    (L = c, !,
		Atom = '(double)'(Nom)/Div;
	    Atom = double(Nom)/Div);
	Op = (//), !,
	    VArgs = [Nom, Div],
	    Atom = int(Nom)/int(Div);
	member(Op, [round, floor, ceil]), !,
	    Expr =.. [Op | VArgs],
	    combine(L, int, [Expr], Atom);

	(member(Op, [and, ',', '&&']), !,
		(L = c,
			TargetOp = (&&);
		L = basic,
			TargetOp = 'AND');
	member(Op, [or, ';', '||']), !,
		(L = c,
			TargetOp = ('||');
		L = basic,
			TargetOp = 'OR');
	member(Op, [xor]), !,
		((L = c; L = tcl),
			TargetOp = ('!=');
		L = basic,
			TargetOp = 'XOR');
	member(Op, [not, '!']), !,
		((L = c; L = tcl),
			TargetOp = ('!');
		L = basic,
			TargetOp = 'NOT');
	Op = (^), !,
		((L = c ; L = tcl),
			TargetOp = 'pow';
		L = basic,
			TargetOp = (^));
	Op = int, !,
		((L = basic; L = tcl),
			TargetOp = int;
		L = c,
			TargetOp = '(int)');
	Op = (=:=), !,
		((L = basic; L = tcl; L = c),
			TargetOp = (==));
	member(Op, ['<>', '=\\=']), !,
		((L = basic; L = tcl; L = c),
			TargetOp = ('!='));
	Op = arctan, !,
		TargetOp = atan;
	Op = abs, L = c, !,
	        TargetOp = myabs;
	TargetOp = Op),
		Atom =.. [TargetOp | VArgs].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
