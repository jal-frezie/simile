/*******************************************************************************
**** COMPILATION module. This module contains all the templates necessary   ****
**** to compile AME code. Everything is parameterised by language, BASIC    ****
**** being the starting point.                                              ****
*******************************************************************************/

sicstus_module( render, [render/5, make_assignment/4, render_all/5, 
		get_empty_list/2, make_array_assignment/9,
		refer_value/3, refer/3, make_expr/3, make_increment_expr/4,
		make_struct_reference/4, make_indexed_reference/4,
		put_in_context/6, ptr_compare/4, extract_instances/2,
		combine/4, make_arg_string/3, 
		make_pointer/3, resolve_pointer/3, 
		make_constant_list/3, get_element_ref/4,
		make_integer/3, command_substitute/3,
		generate_data_decls/10, make_procedure_call_chars/3] ).

sicstus_use_module( [m_class, utility, ame_gen, units, text, utility,
		library(charsio), library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% render converts proglog atoms or terms float valid expressions in the named
% programming language. Used names are not duplicated

:- discontiguous(render/5).

/* c and tcl rendition functions are organized by their purpose */

/* assignment */
render(L, assignment, Dest=Source, Indent, Atom) :-
	make_assignment(L, Dest, Source, Assign),
	render(L, function, Assign, Indent, Atom).

make_assignment(L, Dest, Source, AssignStr) :-
	(L = tcl, Template = "set ~a ~w";
	L = c, Template = "~a = ~w"),
	sicstus_format_to_chars(Template, [Dest, Source], AssignStr).

/* assignment of context */
make_pointer(c, Var, Ptr) :-
	sicstus_format_to_chars("&(~w)", [Var], PtrStr),
	name(Ptr, PtrStr).
make_pointer(tcl, Var, Var).

render(L, open_context, Pointer=[_, _, MPTargetRef], Indent1, Result1) :-
	render(L, assignment, Pointer=MPTargetRef, Indent1, Result1).

render(L, enter_context, NewPointer=[CurrentPointer, Struct, Indices],
		Indent, Result) :-
	(CurrentPointer = '', !,
	    Base = Struct;
	make_struct_reference(L, CurrentPointer, Struct, Base)),
	make_indexed_namespace(L, Base, Indices, Target),
	render(L, make_reference, NewPointer=Target, Indent, Result).

make_indexed_namespace(L, Base, Indices, Result) :-
	L = c,
	    make_indexed_reference(L, Base, Indices, Result);
	L = tcl,
	    make_list_context_id(tcl, Indices, BraceTerm),
	    sicstus_format_to_chars("~w<~w>", [Base, BraceTerm], ResultStr),
	    name(Result, ResultStr).

/* this creates a reference to a value in a deep context. */

render( L, make_reference, Dest=Source, Indent, [Atom]) :-
	refer(L, Source, SourceRef),
	render( L, assignment, Dest=SourceRef, Indent, [Atom]).

render(c, assign_space, Dest=[_, Name, _], Indent, [Result]) :-
	append_atoms(Name, type, Type),
	sicstus_format_to_chars( "~*s~a = new ~a;",
			[Indent," ", Dest, Type], ResultStr),
	name(Result, ResultStr).

render(tcl, assign_space, Dest=[Top, Struct, Indices], Indent, Result) :-
	append_atoms(Struct, maker, ProcName),
	make_struct_reference(tcl, Top, ProcName, CurrentName),
	make_indexed_namespace(tcl, Struct, Indices, Target),
	Call =.. [CurrentName, Target],
	render(tcl, procedure_call, Call, Indent, Line1),
	render(tcl, enter_context, Dest = [Top, Struct, Indices],
			Indent, Line2),
	append(Line1, Line2, Result).

resolve_pointer(c, Var, Res) :-
	sicstus_format_to_chars("*~a", [Var], ResStr),
	name(Res, ResStr).

resolve_pointer(tcl, Var, Res) :-
	refer_value(tcl, Var, Res).

/* comment */
render( c, comment, Comment, Indent, [Atom]) :-
	 sicstus_format_to_chars( "~*s/* ~w */", [Indent," ",Comment], CharList ),
	 name( Atom, CharList ).
/* tcl comment starts with a ; in case goes after a command */
render( tcl, comment, Comment, Indent, [Atom]) :-
	 sicstus_format_to_chars( "~*s;# ~w", [Indent," ",Comment], CharList ),
	 name( Atom, CharList ).

/* Things that do not appear at all in certain languages; generate for one in
which they do, and add as comments. */

render( Target, NotNeeded, Variable, Indent, Comment) :-
	member([NotNeeded, Target, Translation],
			[[duplicate_context, c, tcl],
			 [public_cons_dest, tcl, c],
			 [end(class), tcl, c],
			 [data_declaration, tcl, c],
			 [pointer_declaration, tcl, c]]),
	render(Translation, NotNeeded, Variable, Indent, Foreign),
	render_all(Target, comment, Foreign, 0, Comment).

/* free memory; nothing need be done in c because the structures are permanent
rather than malloced...not any more! I'll have to add this later. */
render(c, clear_memory, Object, Indent, Clearance) :-
	render(tcl, clear_memory, Object, Indent, TCLClearance),
	render_all(c, comment, TCLClearance, 0, Clearance).
render(tcl, clear_memory, instance(submodel, _, _, Name, _-Dims), Indent, 
		[Line1, Clearance, LineN]) :-
	(number(Dims), !,
		NewIndent is Indent + 4,
		render(tcl, for_start, [makenames, 1, Dims, 1], Indent, [Line1]),
		refer_value(tcl, makenames, VWithDollar),
		make_struct_reference(tcl, Name, VWithDollar, SpaceName),
		render(tcl, end(for), makenames, Indent, [LineN]);
	Line1 = '',
		LineN = '',
		NewIndent = Indent,
		SpaceName = Name),
	sicstus_format_to_chars("~*snamespace delete ~w", [NewIndent," ", SpaceName], Expr),
	name(Clearance,Expr).

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

render(L, increment_by, [Current, Step], Indent, Increment) :-
	make_increment_expr(L, Current, Step, ActionStr),
	render(L, function, ActionStr, Indent, Increment).

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

render(L, if_start, ConditionExpr, Indent, [Line]) :-
	(L = c, !,
		sicstus_format_to_chars("~*sif (~w) {", [Indent, " ", ConditionExpr], 
				LineStr);
	L = tcl, !,
		sicstus_format_to_chars("~*sif {~w} {", [Indent, " ", ConditionExpr], 
				LineStr)),
	name(Line, LineStr).

render(L, else_clause, Cond, Indent, [Result]) :-
	render(L, comment, Cond, 0, [Amble]),
	sicstus_format_to_chars("~*s} else { ~a", [Indent, " ", Amble], ResultStr),
	name(Result, ResultStr).

render(L, switch_start, Condition, Indent, [Line]) :-
	make_expr(L, Condition, ConditionExpr),
	(L = c, Template = "~*sswitch (~w) {";
	L = tcl, Template = "~*sswitch ~w {"),
	sicstus_format_to_chars(Template, [Indent, " ", ConditionExpr], LineStr),
	name(Line, LineStr).

render(L, case_start, Match, Indent, [Line]) :-
	(L = c, Template = "~*scase ~w:";
	L = tcl, Template = "~*s~w { "),
	sicstus_format_to_chars(Template, [Indent, " ", Match], LineStr),
	name(Line, LineStr).

render(c, case_end, Match, Indent, [Line]) :-
	render(c, comment, Match, 0, [Comment]),
	sicstus_format_to_chars("~*sbreak; ~w", [Indent, " ", Comment], LineStr),
	name(Line, LineStr).

render(tcl, case_end, Match, Indent, Result) :-
	render(tcl, end(case), Match, Indent, Result).

/* start of a for loop */
render( L, for_start, [Name,Start,End,Step], Indent, [For_Start]) :- 
	render(L, assignment, Name=Start,0,[Init]),
	refer_value(L, Name, NameRef),
	make_increment_expr(L, Name, Step, Incr),
	(L = c, Template = "~*sfor ( ~w ~w; ~s ) {";
	L = tcl, Template = "~*sfor {~w} {~w} {~s} {"),
	(Step > 0, !, Test = (End >= NameRef);
	    Test = (NameRef >= End)),
	sicstus_format_to_chars( Template,
		   [Indent," ",Init, Test, Incr], StartChars ),
	name( For_Start, StartChars ).

/* start of a while loop */
render( c, while_start, Expr, Indent, [While_Start]) :- 
	sicstus_format_to_chars( "~*swhile ( ~w ) {", [Indent," ", Expr],
			StartChars ),
	name( While_Start, StartChars ).
render( tcl, while_start, Expr, Indent, [While_Start]) :- 
	sicstus_format_to_chars( "~*swhile {~w} {", [Indent," ",Expr],
			StartChars ),
	name( While_Start, StartChars ).

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
       instance(submodel, _, xrefs(model(Prims, Subs), _,_,_), _,
		ClassName-_), Indent, PubConDe) :-
	InIndent is Indent+4,
	sicstus_format_to_chars( "~*spublic:", [Indent," "], PubStr),
	sicstus_format_to_chars( "~*s~w () {", [InIndent," ",ClassName], ConsHd),
	sicstus_format_to_chars( "~*s~~~w () {", [InIndent," ",ClassName], DestHd),
	append(Prims, Subs, Comps),
	all(render, make_cons_dest,
	    [build(Comps), append(ConLines, []), append(DeLines, [])]),
	render(c, end(procedure), structor, InIndent, [EndStr]),
	name(Pub, PubStr),
	name(Cons, ConsHd),
	name(De, DestHd),
	append([[Pub, Cons | ConLines], [EndStr, De | DeLines], [EndStr]],
	       PubConDe).

make_cons_dest(instance(Type, Sym, _, Nm, _), ConLine, DeLine) :-
	Type = submodel,
	variable_size(Sym), !,
	    Nm = Name,
	    render(c, assignment, Name=0, 8, ConLine),
	    render(c, procedure_call, delete_list(Name), 8, DeLine);
	Type = external, !,
	    Nm = elt(_, Name, _),
	    make_constant_string(c, Sym, SymCStr),
	    name(SymC, SymCStr),
	    make_procedure_call_chars(c, [fetch_instance, SymC], FetchStr),
	    name(Fetch, FetchStr),
	    render(c, assignment, Name=Fetch, 8, ConLine),
	    render(c, procedure_call, discard_instance(Name), 8, DeLine);
	[ConLine, DeLine] = [[], []].

/* end of any kind of loop */
render( L, end(Loop), Name, Indent, [For_End]) :-
	member(Loop, [for, while, switch, case, class, cond, procedure,
		      declaration, namespace, catch]),
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

count_base_ptrs([], 0).
count_base_ptrs([base(_,_, Ptrs) | More], N) :-
	length(Ptrs, Here),
	count_base_ptrs(More, M),
	N is M+Here.

/* This process for making a class declaration in c actually sticks close
to the nature of a class, rather than the nature of a submodel. The latter
is supplied by making it a subclass of a base submodel class, if necessary. */

render(c, class_declaration, Instance, Indent, ClassDecl) :-
	Instance = instance(submodel, SymbolicName, _,_, Name-_),

	(nonvar(SymbolicName), !,
	    sicstus_format_to_chars( "~*sclass ~w : public submodeltype {",
			 [Indent, " ", Name], HeaderStr),
	    render(c, public_cons_dest, Instance, Indent, PublicHeads);
	sicstus_format_to_chars( "~*sclass ~w {", [Indent, " ", Name], HeaderStr),
	    PublicHeads = ['public:']),
	name(Line1, HeaderStr),
	sicstus_format_to_chars("}; /* end(class,~w) */", [Name], EndStr),
	name(End, EndStr),

	append([submodel_decls, '', Line1 | PublicHeads],
	       [proc_decls, End], ClassDecl).
	
/* pointer declaration for a given type */
render(c, pointer_declaration, instance(submodel, SmName, 
		xrefs(_,_, Bases, _), Name, Type-_), Indent, Rest) :-
	do_loop_pointers(SmName, Type, Name, Temps1),
	all(render, do_base_pointers, [build(Bases), append(Temps2, [])]),
	append(Temps1, Temps2, Temps),
	render_all(c, variable_declaration, Temps, Indent, Rest).

do_base_pointers(base(_,_, []), []).
do_base_pointers(base(instance(submodel, _, xrefs(_, Parent, _,_), _, Type-_),
		       _, [Ptr | Ptrs]), [[Type, BasePtd, []] | Rest]) :-
	resolve_pointer(c, Ptr, BasePtd),
	do_base_pointers(base(Parent, _, Ptrs), Rest).

do_loop_pointers(SmName, Type, Name, Late) :-

	variable_size(SmName), !,
	    append_atoms(Name, pointer, Ptr),
	    resolve_pointer(c, Ptr, Ptd),
	    append_atoms(Name, meta, Meta),
	    resolve_pointer(c, Meta, MetaPtd),
	    resolve_pointer(c, MetaPtd, MetaPtdPtd),
	    Late = [[Type, Ptd, []], [Type, MetaPtdPtd, []]];
	Late = [].

generate_data_decls(L, Match, Dims, Path, Inst, ExtSets, GraphOwners,
		    Decl, Exts, NodeData) :-
	render(L, data_declaration, Inst, 4, Decl),
	Inst = instance(InstType, BaseName, _, NameIn, Unit-LocalDims),
	render(L, case_start, Match, 8, [Ext1]),

	(NameIn = elt(_, Name, _), !;
	    Name = NameIn),
	((variable_size(BaseName); L = tcl, Name = instanceid), !,
	    Item = Name;
	length(LocalDims, DimCount),
	refer_value(L, dims, DimsRef),
	make_procedure_call_chars(L, [step_list, DimsRef, 2], SubStr),
	name(Subscript, SubStr),
	list_of(Subscript, DimCount, Subs),
	(InstType = submodel, !,
	    make_indexed_namespace(L, Name, Subs, Item);
	make_indexed_reference(L, Name, Subs, Item))),
	
	refer(L, Item, ItemRef),
	render(L, procedure_call, return(ItemRef), 8, [Ext2]),
	render(L, case_end, Match, 8, [Ext3]),
	Exts = [Ext1, Ext2, Ext3],
	/* no break required */

	(InstType = external, !, Type = 'EXTERNAL',
	        [Wee, Muckle] = [0, 0],
	    (member(make(_,_,_,_, [int_eval_submodel(_, arr(_, Name, _), _)]),
		    ExtSets), !,
		DefEval = 'EXOGENOUS';
	     member(make(_,_,_,_, [ext_eval_submodel(_, arr(_, Name, _), _)]),
		    ExtSets), !,
		DefEval = 'SPLIT';
		DefEval = 'DERIVED');
	    InstType = submodel, !, Type = 'VALUELESS',
	        [Wee, Muckle] = [0, 0],
	        DefEval = 'SPLIT';
	    (Unit = boolean, !, Type = 'FLAG',
	        [Wee, Muckle] = [0, 1];
	    Unit = int, !, Type = 'INTEGER',
	        [Wee, Muckle] = [-1073741823, 1073741823];
	    Type = 'REAL',
	        [Wee, Muckle] = [-1.0e100, 1.0e100]),

	    (member(make(_,_,_,_, [assign(arr(_, Name, _), _)]), ExtSets), !,
		DefEval = 'EXOGENOUS';
		DefEval = 'DERIVED')),
	is_parameter(BaseName, PType),
	(PType = -1, Eval = DefEval;
	nth0(PType, [DefEval, 'INPUT', 'FILE'], Eval)),
	
	append(Path, [0], NewPath),
	append([Dims, [0]], CappedDims), 

	(/* Try not doing internals -- but will we need to for save/restore
	 state? */
	\+ InstType = internal,
	    get_host(BaseName, VisName),
	    caption_for(VisName, CaptionTail),
	    (VisName is_of_sort value_outside, !,
		Pop has_part VisName,
		caption_for(Pop, CaptionHead),
		append_atoms([CaptionHead, '/', CaptionTail], Caption);
	    CaptionTail = Caption),
	    find_type(VisName, VisType),
	    member(VisType-Class, [submodel-'SUBMODEL',
				   variable-'VARIABLE',
				   compartment-'COMPARTMENT',
				   flow-'FLOW',
				   condition-'CONDITION',
				   creation-'CREATION',
				   reproduction-'REPRODUCTION',
				   immigration-'IMMIGRATION',
				   loss-'LOSS']),
				   
	    (member([Name, GraphPointer | _], GraphOwners), !;
	        GraphPointer = 0),

		(BaseName has_class_refinement min_val of Min, 
		number(Min), !;
		Min = Wee),
		(BaseName has_class_refinement value of Def, 
		number(Def), !;
		Def = 0),
		(BaseName has_class_refinement max_val of Max, 
		number(Max), !;
		Max = Muckle),
		/* make a value lookup entry for each node with this value */
		setof([NodeName, Type, Eval, CappedDims, 
				NewPath, GraphPointer,
				Caption, Min, Def, Max, Class, Name],
			
		     (NodeName = VisName;
			 find_ghosts(VisName, NodeName)),
		      NodeData);
	/* No need to handle ghosts and link terminators */
		NodeData = []).

render(c, data_declaration,
		instance(NodeType, SymbolicName, _, NameIn,
		Type-Dims),
		Indent, Decl) :-
	(NodeType = submodel, !,
	    NameIn = NameBase,
	    (variable_size(SymbolicName), !,
			/* variable length submodel - declare a pointer */
		resolve_pointer(c, NameBase, Name),
		UseDims = [];
	    Name = NameBase,
		get_node_size(SymbolicName, UseDims));
	    (NameIn = elt(_, Name, _), !;
		Name = NameIn),
	    UseDims = Dims),
	render(c, variable_declaration, [Type, Name, UseDims],
			Indent, Decl).

/* next clause generates nested namespace declarations for tcl. They look as
if the nested loops use the same counter variable, but this is OK because each
loop is in a different namespace... */

render(tcl, class_declaration,
       instance(NodeType, SymbolicName, _, Name, _), Indent, Decl) :-
	NodeType = submodel, !,
	    (variable_size(SymbolicName), !,
		append_atoms(Name, maker, ProcName),
		render(tcl, procedure_start,
		       call(_, ProcName, [_, instance]), Indent, Opens),
		render(tcl, end(procedure), ProcName, Indent, Closes),
		NewIndent is Indent + 4,
		refer_value(tcl, instance, Target);
	    get_node_size(SymbolicName, What),
		make_array_assignment(tcl, Indent, What, _,
				      NewIndent, _, Indices, Opens, Closes),
		make_indexed_namespace(tcl, Name, Indices, Target)),
	    declare_namespace(Target, Indent, ClassDecl),
	    append([Opens, ClassDecl, Closes], Decl);
	Decl = [].

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
	render(L, for_start, [Temp, 1, Sub, 1], 
			Indent, Opens1),
	render(L, end(for), Index, Indent, Closes2),
	make_array_assignment(L, NewIndent, Rest, Used,
			FinalIndent, Temps0, Indices, Opens2, Closes1),
	render(L, comment, 'start list here', 0, [StartMark]),
	render(L, comment, 'end list here', 0, [EndMark]),
	append(Opens1, [StartMark | Opens2], Opens),
	append(Closes1, [EndMark | Closes2], Closes).

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

extract_instances(model(Funx, Subz), Instances) :-
	pick_types(Funx, [function, init_function, fp_compartment,
			  internal, external],
		   ValFunx),
	append(ValFunx, Subz, Instances).

pick_types(All, Types, Picked) :-
	All = [], Picked = [];
	All = [This | More],
	This = instance(Type, _,_,_,_),
	(member(Type, Types), !,
	    Picked = [This | Rest];
	Picked = Rest),
	pick_types(More, Types, Rest).

render(L, variable_declaration, [Unit, Name, Dims | Init], Indent, FgResult) :-
	(nonvar(Dims), !,
	    FgResult = Result;
	Dims = [],
	    render(L, comment, 'Next field had undefined dims', 0, Fg),
	    append(Fg, Result, FgResult)),
	type_for_unit(Unit, Type),
	(member(-1, Dims), !, /* no null arrays please */
	    Result = [];
	Init = [], !,
	    (L = c,
		(Dims = void, Counts = [''];
		all(render, boost, [build(Dims), build(Counts)])),
		make_indexed_reference(L, Name, Counts, ArrayName),
		sicstus_format_to_chars( "~*s~a ~a;", [Indent, " ", Type, 
					       ArrayName], Chars),
		name(Decl, Chars),
		Result = [Decl];
	    L = tcl,
		render(c, variable_declaration, [Type, Name, Dims], 
		       Indent, CDecl),
		render_all(tcl, comment, CDecl, 0, Result));

	Init = [InitialValues],
	    (L = c,
		DeepIndent is Indent + 4,
		swap_squares_for_curlies(InitialValues, InitString),
		InitString = [FirstLine | LateLines],
		(Dims = void, Counts = [''];
		all(render, boost, [build(Dims), build(Counts)])),
		make_indexed_reference(L, Name, Counts, ArrayName),
		sicstus_format_to_chars("~*s~a ~a = ~s",
				[Indent, " ", Type, ArrayName, FirstLine],
				Chars1),
			name(NewFirstLine, Chars1),
			list_of(32, DeepIndent, TabIn),
			prepend_spaces(LateLines, TabIn, NewLateLines),
			append(EarlyLines, [LastLine], [NewFirstLine | NewLateLines]),
			sicstus_format_to_chars("~a;", [LastLine], Chars2),
			name(NewLastLine, Chars2),
			append(EarlyLines, [NewLastLine], Result);
		L = tcl,
		        (Dims = void,
			    length(InitialValues, InitDim),
			    InitDims = [InitDim];
			InitDims = Dims),
			assign_initial_values(Name, InitialValues, 0, InitDims,
					Indent, Result))).

boost(P, Q) :- Q is P+1.

/* prepend_spaces puts indent blanks on strings and turns them to atoms */

prepend_spaces([], _, []).

prepend_spaces([H|T], Gap, [H2 | T2]) :-
	append(Gap, H, Line),
	name(H2, Line),
	prepend_spaces(T, Gap, T2).

render(c, release_memory, Var, Indent, [Result]) :-
	sicstus_format_to_chars("~*sdelete ~a;", [Indent, " ", Var], ResultStr),
	name(Result, ResultStr).

render(tcl, release_memory, Pointer, Indent, [Result]) :-
	resolve_pointer(tcl, Pointer, Zap),
	sicstus_format_to_chars("~*snamespace delete ~a",
			[Indent, " ", Zap], ResultStr),
	name(Result, ResultStr).

get_empty_list(L, NewList) :-
	L = c,
		make_procedure_call_chars(L, ['Tcl_NewListObj', 0, 'NULL'], NewListStr),
		name(NewList, NewListStr);
	L = tcl,
		NewList = {}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* assign_initial_values does for tcl what the facility to initialize a variable
when it is declared does for c. This takes the var name (1), a list of initial 
values (2), a set of array bounds (5) and a progress count through the first (4)
and returns a set of assignments to initialize the variables (7) and any values
which are not used (3).

The list of init vals is in list-of-lists format to match the way initialization
works in c, though this is untested for multidimensionals. */

assign_initial_values(Var, Val, 0, [], Indent, Result) :-
	render(tcl, assignment, Var=Val, Indent, Result).

assign_initial_values(_, _, Count, [Bound | _], _, []) :- 
	Count > Bound, !.

assign_initial_values(_, [], _,_,_, []).

assign_initial_values(Var, [Vals | Rest], Count, [Dim | Deep], Indent, Result) :-
	make_indexed_reference(tcl, Var, [Count], Dest),
	assign_initial_values(Dest, Vals, 0, Deep, Indent, Result0),
	Next is Count + 1,
	assign_initial_values(Var, Rest, Next, [Dim | Deep], Indent, 
			Result1),
	append(Result0, Result1, Result).

swap_squares_for_curlies(ListList, Strings) :-
	(make_list_chars(c, ListList, NestStr), !;
	sicstus_write_to_chars(ListList, NestStr)),
	split_lines(NestStr, Strings).

split_lines(NestStr, [String | Strings]) :-
	append(String, Rest, NestStr),
		append(_, "},", String), !,
		split_lines(Rest, Strings);
	String = NestStr,
		Strings = [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% render_all applies render to a list of items of a given type

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

build_constant(Language, [String, Type, Eval, Dims, Array, GraphPtr, Caption,
			  Min, Def, Max, Class, _Comment], Chars) :-
	make_list_chars(Language, Dims, DimsString),
	make_list_chars(Language, Array, ArrayString),
	make_constant_string(Language, String, Quoted),
	make_constant_string(Language, Caption, Quoted2),
	name(Arg1, Quoted),
	name(Arg5, Quoted2),
	name(Arg2, DimsString),
	name(Arg3, ArrayString),
	make_list_chars(Language, [Arg1, Type, Eval, Arg2, Arg3, GraphPtr,
				   Min, Def, Max, Class, Arg5], Chars).
/* 	render(Language, comment, Comment, 0, [CommentWd]),
	name(CommentWd, CommentStr),
Comment string removed because it interferes with list mode
	append(BaseChars, [32 | CommentStr], Chars). */

make_constant_list(_, [], []).

make_constant_list(L, [Const | Rest], [Line | Lines]) :- 
	build_constant(L, Const, String),
	name(Line, String),
	make_constant_list(L, Rest, Lines).

make_constant_string(L, String, Const) :-
	name(String, Chars),
	(L = tcl,
		((member(32, Chars); member(10, Chars)), !,
			append([123 | Chars], [125], Const);
		Const = Chars);
	L = c,
		mark_crs(Chars, StraightChars),
		append([34 | StraightChars], [34], Const)).

mark_crs(With, Without) :-
	append(L1, [10 | L2], With), !,
	append(L1, [92, 110 | L2], WithFewer),
	mark_crs(WithFewer, Without);
	With = Without.

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
	make_arg_string(c, Args, Contents),
	sicstus_format_to_chars("~w(~s)", [Proc, Contents], Result).

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
	sicstus_format_to_chars("${~w}::~w", [Struct, Var], ResultStr),
	    name(Result, ResultStr).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_indexed_reference/4: Takes a language, array variable and subscript
term, and makes a reference to an array element. This is the same as the last one
in Tcl */

make_indexed_reference(_, Base, [], Base).

make_indexed_reference(L, Struct, Indices, Result) :-
	L = c,
	    Indices = [Inner | Rest],
	    sicstus_format_to_chars("~w[~w]", [Struct, Inner], MidStr),
	    name(Mid, MidStr),
	    make_indexed_reference(L, Mid, Rest, Result);
	L = tcl,
	    comma_separate(Indices, IndListStr),
	    sicstus_format_to_chars("~w(~s)", [Struct, IndListStr], ResultString),
	    name(Result, ResultString).

comma_separate([Solo], Str) :-
	sicstus_write_to_chars(Solo, Str), !.

comma_separate([F | R], Str) :-
	comma_separate(R, Str2),
	sicstus_format_to_chars("~w,~s", [F, Str2], Str).


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
	Unit = boolean, !,
	    Type = 'BOOLEAN';
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
	Op = (?), L = tcl, !,
	    VArgs = [VCond, VTrue:VFalse],
	    sicstus_format_to_chars("[if {~w} {expr ~w} else {expr ~w}]",
			    [VCond, VTrue, VFalse], CharList);
	    
/* Yes, horrible, nasty, ugly, repugnant, grotesque Tcl has the a?b:c format but,
mindbogglingly stupidly, evaluates the non-chosen half, and, worse, complains
about undefined array elements in it. Blooaaargh!! 

What follows is even worse; it allows conditionals to be entered in the 
if-then-elseif-else format, though I can't see why anyone would want to.

Since this causes problems anyway (due to inters and contexts) it's all
obsolete. A stopgap conversion to a?b:c format is in place, pending the
incorporation of the actual conditionality into program generation

	Op = choose, !,
		(L = c,
			sicstus_format_to_chars("(~w?~w:~w)", VArgs, CharList);
		L = tcl,
			sicstus_format_to_chars("[if {~w} {expr ~w} else {expr ~w}]",
					VArgs, CharList));

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

	member(Op, [rand, rand_var]),
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
the next few lines in place, and math_protect asserted, AME will do the same. */

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

/* Enough of these; I might need to do pow(a,b) and perhaps others too.
   Now to exorcise the demon of integer division... */
	Op = (/), !,
	    VArgs = [Nom, Div],
	    Atom = double(Nom)/Div;
	Op = (//), !,
	    VArgs = [Nom, Div],
	    Atom = int(Nom)/int(Div);
	member(Op, [floor, ceil]), !,
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
	Op = (^), !,
		(L = c,
			TargetOp = 'pow';
		L = tcl,
			TargetOp = 'pow';
		L = basic,
			TargetOp = (^));
	Op = int, !,
		((L = basic; L = tcl),
			TargetOp = int;
		L = c,
			TargetOp = '(int)');
	Op = '<>', !,
		((L = basic; L = tcl; L = c),
			TargetOp = ('!='));
	Op = arctan, !,
		TargetOp = atan;
	TargetOp = Op),
		Atom =.. [TargetOp | VArgs].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
