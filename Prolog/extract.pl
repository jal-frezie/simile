/* extract.pl
=============

This builds the procedure that gets data out of (or into) an executing model
on behalf of the helper applications. It is used by compile.pl and chiefly
uses render.pl itself, though a few clever bits make use of the assignment
loop generators in language.pl.

The basic idea is that each model component has a code list of integers
allowing its variable in the target language to be located in the model
structure, and queried or set via a giant switch statement. */

:- module( extract, [make_extractor_proc/7] ).

:- use_module( [render,language,m_class,utility,
		ame_gen,units,text,library(lists),library(charsio)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* make_extractor_proc/7: takes the full model, with names, and assembles the
bit of code that ultimately will get values out of the model for display or
tabulation. */
make_extractor_proc(L, FullModel, GraphOwners,
		RunTimeOps, Used, Decls, Extractor) :-

	list_clauses(L, FullModel, GraphOwners, '', [], [], RunTimeOps,
		result, newvalue, Used,
		Temps, Structs, Cases, NumDims, NumTemps),

/* In order to declare the data structure we want in the new style in
any language, we make a dummy 'model' and declare that: */

	render(L, class_declaration,
	       class_data(instance(submodel, _,_,_, node_data_line-_), [],
		[instance(function, _, _, name, char-[15]),
		instance(function, _, _, datatype, int-[]),
		instance(function, _, _, dims, int-[NumDims]),
		instance(function, _, _, path, int-[NumTemps]),
		instance(function, _, _, graph, int-[]),
		instance(function, _, _, min, real-[]),
		instance(function, _, _, max, real-[]),
		instance(function, _, _, caption, char-[255])]),
		8, TypeDecl),
	make_constant_list(L, Structs, StructText),
	(L = c, Extras = [['Tcl_Obj', '*newvalue']],
	    StructText = StructList, NoDim = void;
	L = tcl, Extras = [[whatever, newvalue]], NoDim = [],
	    make_procedure_call_chars(L, [list | StructText], StructListStr),
		name(StructList, StructListStr)),
	render(L, variable_declaration, [node_data_line, nodedata, NoDim,
			StructList], 0, Table),
	GetDataCall =.. [call, 'Tcl_Obj*', getdata, ['int*', tree]
			| Extras],
	render(L, procedure_start, GetDataCall, 0, ProcDecl2),
	resolve_pointer(L, result, RefResult),
	render_all(L, variable_declaration,
		   [['Tcl_Obj', RefResult, []] | Temps], 4, VarList2),

	(L = c,
		make_procedure_call_chars(L, ['Tcl_NewListObj', 0, 'NULL'], NewListStr),
		name(NewList, NewListStr),
		render(L, assignment, result=NewList, 4, InitResult);
	L = tcl,
		render(L, assignment, result='""', 0, InitResult)),

/* Insert switch statement here */

	append(TypeDecl, Table, Decls),
	(L = c, 
		FinishResult = ['    return(result);'];
	L = tcl,
		FinishResult = ['    return $result']),
	render(L, end(procedure), getdata, 0, ProcedureEnd2),

	append([ProcDecl2, VarList2, InitResult, Cases,
			FinishResult, ProcedureEnd2], Extractor).

add_to_result(L, Dest, Data, NewVal, Indent, Target) :-
	make_pointer(L, Data, DataPointer),
	ProcCall =.. ['getinstance', DataPointer, Dest, NewVal],
	render(L, procedure_call, ProcCall, Indent, Target).
		
list_clauses(L, model(Primitives, Submodels), GraphOwners, TopPtr, Parents,
	     Path, RunTimeOps, Result, NewValue, Used,
	     Temps, Structs, Cases, MaxDims, Depth) :-

	length(Parents, Number),
	Indent is 4*Number + 8,
	get_element_ref(L, tree, Number, SwitchExpr),

	render(L, switch_start, SwitchExpr, Indent, Line0),
	make_clauses(L, Primitives, GraphOwners, TopPtr, Parents, RunTimeOps,
		     0, Result, NewValue, Used, Temps0, Count,
		     Structs0, Cases0, LocalDepth),
	make_submodel_clauses(L, Submodels, GraphOwners, TopPtr, 
			      Parents, Path, RunTimeOps,
			      Count, Result, NewValue, Used,
			Temps1, Structs1, Cases1, SubDims, SubDepth),
	merge_lists(Temps0, Temps1, Temps),
	render(L, end(switch), SwitchExpr, Indent, LineN),
	append(Structs0, Structs1, Structs2),
	reorder_structs(Structs2, Structs),
	MaxDims is max(LocalDepth, SubDims),
	Depth is max(LocalDepth, SubDepth + 1),
	append([[''|Line0], Cases0, Cases1, LineN], Cases).

reorder_structs(Dodgy, Right) :-
	append(First, [start_belongs_after(Sm, Bases) | Rest], Dodgy),
	append(Move, [end_belongs_after(Sm, Bases) | Last], Rest),
	member(LastBase, Bases),
	append(Middle, [LastBaseLine | End], Last),
	LastBaseLine = [LastBase | _],
	\+ (member(LaterBase, Bases),
	       member([LaterBase | _], End)), !,
	    append(First, Middle,
		   [LastBaseLine, start_belongs_after(Sm, Bases) | Move],
		   [end_belongs_after(Sm, Bases) | End], LessDodgy),
	    reorder_structs(LessDodgy, Right);
	purge(Dodgy, [start_belongs_after(_,_), end_belongs_after(_,_)],
	      Right).
	
make_submodel_clauses(_, [], _,_,_,_,_,_,_,_,_, [], [], [], 
		0, 0).

make_submodel_clauses(L, [Submodel | Submodels], GraphOwners, TopPtr, 
		Parents, Path, RunTimeOps, Count, Result, NewVal, Used,
		Temps, Structs, Cases, Dims, Depth) :-
	Submodel = instance(submodel, SmName, xrefs(Model, _, Bases, _),
			StructName, _-SmDims),
	appears(SmName), !,
	    caption_for(SmName, Caption),
	    format_to_chars("Generating procedure for extracting information from model, currently doing ~a", [Caption], Notice),
	dialogue:reassure_user(Notice),
	length(Parents, SubNumber),
	Indent is 4*SubNumber + 8,
	NewCount is Count + 1,

	inters:path_section_for(SmName, StructName, SmDims, Level,
				TopPtr, Pointer),
	append(Level, Path, NewPath),
	all(compile, get_pass_ends, [build(Level), build(RevInsts)]),
	reverse(RevInsts, Insts),
	all(compile, extract_action, [build(Insts), append(StartCmds, [])]),
	length(StartCmds, Levels),
	list_of(finish_level, Levels, Finishes),
	append(StartCmds, [verbatim([middle]) | Finishes], AllInsts),
	do_assign_list(L, AllInsts, 0, [], [[]], Used, _, Temps0, Results),
	
	m_update:list_local_index_meanings(SmName, IndMeans),
	length(IndMeans, Dims0),
	
	render(L, case_start, NewCount, Indent, Line0),

	(variable_size(SmName), !,
	    make_struct_reference(L, Pointer, instanceid, Index),
	    refer_value(L, Index, RefIndex),
	    RefIndices = [RefIndex],
	    /* Generate procedure for setting submodel membership

	These same variables will be built by make_array_extractor so
	no need to add them to the used or temps lists here
	*/
	close_end(Used, NoUse, _),
	    append(NoUse, _, LocalUsed),
	    refer_value(L, NewVal, NewValueRef),
	    generate_name(L, writelength, WriteLength, LocalUsed),
	    refer_value(L, WriteLength, WriteLengthRef),
	    generate_name(L, writeindex, WriteIndex, LocalUsed),
	    generate_name(L, writearray, WriteArray, LocalUsed),
	    NextSubNumber is SubNumber + 1,

	    (L = c,
		NullTest = NewVal,

		make_pointer(L, WriteLength, WriteLengthPtr),
		make_pointer(L, WriteArray, WriteArrayPtr),
		ConvertListProc =.. ['Tcl_ListObjGetElements', 'NULL', NewVal,				     WriteLengthPtr, WriteArrayPtr],
		render(L, procedure_call, ConvertListProc, Indent, InitResult1),
		IndexableArray = WriteArray;
	    L = tcl,
		format_to_chars("[string compare ~a NULL]", [NewValueRef],
			    NullTestStr),
		name(NullTest, NullTestStr),

		format_to_chars("[llength ~a]", [NewValueRef], LengthExprStr),
		name(LengthExpr, LengthExprStr),
		render(L, assignment, WriteLength=LengthExpr, Indent, InitResult1),
		IndexableArray = NewVal),
	    
	    get_element_ref(L, tree, NextSubNumber, NextLevelRef),
	    combine(L, !, [NextLevelRef], NoNextLevel),
	    combine(L, ',', [NullTest, NoNextLevel], SetPopTest),
	    render(L, if_start, SetPopTest, Indent, SetPopIf),
	    get_empty_list(L, NewList),
	    render(L, assignment, Result=NewList, Indent, InitResult0),
	    /* here goes InitResult1 */

	    NumIndices = Dims0,
	    render(L, assignment, WriteIndex=0, Indent, ZeroIndex),
	    /* Now make test for match between generation indices and
	    supplied values */
	    refer_value(L, IndexableArray, IARef),
	    make_pointer(L, WriteIndex, WriteIndexPtr),
	    (NumIndices = 0, !, /* simple conditional submodel */
	        CompProcStr = "1";
	    make_procedure_call_chars(L, [compare_lists, NumIndices,
					  IARef, WriteIndexPtr,
					  RefIndex, WriteLengthRef, 1], 
				      CompProcStr)),
	    name(CompProc, CompProcStr),

	    (is_population(SmName),
		append_atoms(StructName, count, CountName),
		make_struct_reference(L, TopPtr, CountName, IndCount),
		refer_value(L, IndCount, IndCountRef),
		generate_name(L, popcount, PopIndex, Used),
		TempsY = [[int, PopIndex, []]],
		render(L, for_start, [PopIndex, IndCountRef, -1, 1], Indent,
		       GoPopLoop),
		OpenInsts = [verbatim(GoPopLoop)],
		render(L, end(for), PopIndex, Indent, EndPopLoop),
		LastStep = [finish_level, verbatim(EndPopLoop), finish_level],
		Inds = [glob(PopIndex, [])],
		BasePtrs = [];
		
	    compile:get_swaps_and_waits(Submodel, Bases, in, InSwaps, _),
		all(compile, get_base_side,
		    [unify(NewPath), build(InSwaps), build(RevBaseSides)]),
	    reverse(RevBaseSides, VMLoops),
	    TempsY = [],

	    /* Call do_assign_list to build the generation loop, this should
	    install the correct creation test... */
	    inters:make_inds_for(SmDims, Sets, LocalInds),
	    append([Sets | VMLoops], BLoops),
	    reverse(BLoops, AllLoops),
	    all(compile, get_pass_ends, [build(AllLoops), build(OpenLoops)]),
	    all(inters, indices_for, [build(AllLoops), append(LoopInds, [])]),
	    append(LoopInds, LocalInds, Inds),
	    compile:get_base_ptrs(BLoops, _, BasePtrs),
	    all(compile, extract_action, [build(OpenLoops),
					  append(OpenInsts, [])]),
	    length([x,x | OpenInsts], LoopCount),
	    list_of(finish_level, LoopCount, LastStep)),
	    
	    append([bound_gen_loop(TopPtr, StructName) | OpenInsts],
		   [generate(StructName, TopPtr, Pointer, old, [], Inds,
			     BasePtrs)], FirstStep),
	    append(FirstStep, [test(StructName, Pointer, CompProc) | LastStep],
		   GenPass),
	    do_assign_list(L, GenPass, 0, [], [[]], Used, _,
			   TempsX, PopSetProc),
	    append(TempsX, TempsY, TempsZ),
	    render(L, else_clause, 'Not setting membership', Indent,
		   SetPopElse),
	    render(L, end(cond), 'Setting membership', Indent,
		   SetPopEnd),
	    append([SetPopIf, InitResult0, InitResult1,
		    ZeroIndex, PopSetProc, SetPopElse],
		   SetPopStart);
	/* not variable membership */
	    TempsZ = [],
	    SetPopStart = [],
	    SetPopEnd = [],
	    NumIndices = -1,
	    all(inters, indices_for, [build(Level), append(Indices, [])]),
	    make_evaluation_routine_all(L, Indices, 0, RefIndices, _),
	    !),

	append(OpenCode, [middle | CloseCode], Results),

	make_array_extractor(L, Indent, OpenCode, CloseCode,
			RefIndices, Used, NumIndices, Result, NewVal,
			_, PartResult, PartNewVal, 
			Temps1, Start, Finish),

	append(Parents, [NewCount], NewParents),
	append(NewParents, [0], SubmodelTree),
	list_clauses(L, Model, GraphOwners, Pointer, NewParents, NewPath,
			RunTimeOps, PartResult, PartNewVal, Used,
			Temps2, SubStructs, SubCases, Dims2, Depth2),
	
	make_submodel_clauses(L, Submodels, GraphOwners, TopPtr, 
			Parents, Path, RunTimeOps,
			NewCount, Result, NewVal, Used,
			Temps3, Structs1, Cases1, Dims1, Depth1),
	Depth is max(Depth1, Depth2),
	OtherDims is max(Dims1, Dims2),
	Dims is max(Dims0, OtherDims),
	append([TempsZ, Temps0, Temps1, Temps2, Temps3], TempsN),
	merge_lists(TempsN, [], Temps),

	render(L, case_end, NewCount, Indent, LineM),

	/* all relations should be conditional now */

	export_dims(IndMeans, CappedLoops), 
	append([[SmName, 'SUBMODEL', CappedLoops, SubmodelTree, 
			0, Caption, 0, 0, StructName] 
			| SubStructs], Structs1, Structs2),
	(setof(BaseNode, contains_base_node(Bases, BaseNode), BaseNodes), !,
	    append([start_belongs_after(SmName, BaseNodes) | Structs2],
		   [end_belongs_after(SmName, BaseNodes)], Structs);
	/* no base submodels */
	    Structs = Structs2),
	append([[''|Line0], SetPopStart, Start, SubCases,
			Finish, SetPopEnd, LineM, Cases1],
			Cases);
	/* First submodel in list was a dummy */
	make_submodel_clauses(L, Submodels, GraphOwners, TopPtr, 
		Parents, Path, RunTimeOps, Count, Result, NewVal, Used,
		Temps, Structs, Cases, Dims, Depth).

contains_base_node(Bases, BaseNode) :-
	member(base(instance(submodel, BaseNode, _,_,_), _,_), Bases).

/* export_dims: Appends a 0 to list of bounds, also converts
'var' (variable-length) from lower to upper case, so can be
defined as -1 in C programs */

export_dims([], [0]).

export_dims([Mean | R1], [CDim | R2]) :-
	name(Mean, MeanStr),
	/* get substring giving actual size from between parentheses */
	suffix([40 | Tail], MeanStr),
	append(DimStr, [41 | _], Tail),
	name(Dim, DimStr),
	(Dim = pop, !,
		CDim = 'VAR';
	CDim = Dim),
	export_dims(R1, R2).

make_clauses(_, [], _,_,_,_, N, _,_,_, [], N, [], [], 0).

make_clauses(L, [Clause | Clauses], GraphOwners, TopPtr, Parents,
	     RunTimeOps, Count, Result, NewValue, Used, Temps, FinalCount,
	     AllStructs, AllCases, Depth) :-
	make_clause(L, Clause, GraphOwners, TopPtr, Parents, 
			RunTimeOps, Count, Result, NewValue, Used,
			Temps0, NextCount, Struct, Cases, NodeDims),
	make_clauses(L, Clauses, GraphOwners, 
			TopPtr, Parents, RunTimeOps,
			NextCount, Result, NewValue, Used,
			Temps1, FinalCount, Structs, OtherCases, OtherDims),
	merge_lists(Temps0, Temps1, Temps),
	append(Struct, Structs, AllStructs),
	append(Cases, OtherCases, AllCases),
	Depth is max(NodeDims, OtherDims).

make_clause(L, instance(InstType, BaseName, _, NameIn, Unit-Dims), 
		GraphOwners, TopPtr, Parents, RunTimeOps,
		OldCount, Result, NewVal, Used,
		Temps, Count, Struct, Cases, Depth) :-
	Count is OldCount + 1,
	length(Dims, Depth),
	append(Parents, [Count, 0], NewPath),
	append(Dims, [0], CappedDims),

	(InstType = internal, !,
	    (Unit = boolean, !, Type = 'BOOLEAN';
		Unit = int, !, Type = 'INTEGER';
		Type = 'REAL'),

	    CodeName = NameIn,
	    generate_name(L, 'int', NodeName, Used),
	    append_atoms('.', CodeName, Caption), /* normally unusable */
	    GraphPointer = 0,
	    Struct = [[NodeName, Type, CappedDims, 
		       NewPath, GraphPointer,
		       Caption, -1.0e100, 1.0e100, CodeName]];
	(appears(BaseName), /* Item shown in original model */
	    \+ is_ghost(BaseName), /* Ghosts are handled with their base */
	    \+ InstType = init_function), !, /* share vals with compartments */
	    (Unit = boolean, !, Type = 'BOOLEAN';
		Unit = int, !, Type = 'INTEGER';
		Type = 'REAL'),

	    NameIn = elt(_, CodeName, _),
	    caption_for(BaseName, Caption),
	    (member([CodeName, GraphPointer | _], GraphOwners), !;
	        GraphPointer = 0),

		(Funct has_class_refinement min_val of Min, 
		number(Min), !;
		Min = -1.0e100),
		(Funct has_class_refinement max_val of Max, 
		number(Max), !;
		Max = +1.0e100),
		/* make a value lookup entry for each node with this value */
		setof([NodeName, Type, CappedDims, 
				NewPath, GraphPointer,
				Caption, Min, Max, CodeName],
			
		     (NodeName = BaseName;
			 find_ghosts(BaseName, NodeName)),
		      Struct)),

		length(Parents, SubNumber),
		Indent is 4*SubNumber + 12,
		render(L, case_start, Count, Indent, Line1),
		make_struct_reference(L, TopPtr, 
				CodeName, Element),
		make_array_assignment(L, Indent, Dims, Used, NewIndent,
				Temps0, Indices, LoopOpens, LoopCloses),
		make_array_extractor(L, NewIndent, LoopOpens, 
				LoopCloses,
				Indices, Used, -1, Result, NewVal,
				DeepIndent, DeepResult, DeepNewVal,
				Temps1, Opens, Closes),
		append(Temps0, Temps1, Temps),
		make_indexed_reference(L, Element, Indices, NewTarget),

		refer_value(L, DeepNewVal, DeepNewValRef),
		add_to_result(L, DeepResult, NewTarget,
				DeepNewValRef, DeepIndent, Line2),
		render(L, case_end, Count, Indent, LineN),
		append([[''|Line1], Opens, Line2, Closes, LineN], Cases);
	/* No need to handle ghosts and link terminators */
	Count = OldCount,
		Depth = 0,
		Temps = [],
		Struct = [],
		Cases = [].

listify([], []).

listify([H | T1], [[H] | T2]) :-
	listify(T1, T2).

/* make_array_extractor: creates the code that builds a
nested list in the result when extracting data from an array
or multi-instance submodel. StartLoop is a list of lists,
because variable-membership submodel loops take two 
statements to start. */

make_array_extractor(L, Indent, 
		OpenAll, CloseAll,
		[IndexRef | Indices], Used, NumIndices, Result, NewVal,
		NewIndent, DeepResult, DeepNewVal, 
		Temps, Opens, Closes) :-

	/* First, find the point at which to insert the array
		initialisers */
	render(L, comment, 'start list here', 0, [StartMark]),
	render(L, comment, 'end list here', 0, [EndMark]),
	append(StartLoop, [StartMark | OpenLater], OpenAll),
	append(CloseLater, [EndMark | EndLoop], CloseAll),
	\+ member(EndMark, EndLoop), !,

	NextIndent is Indent + 4,
	make_subresult_loop(L, Used, NextIndent, IndexRef,
			NumIndices, Result, NewVal,
			Temps0, InitResult, UpdateModel, CloseNest, 
			Result0, NewVal0),
	make_array_extractor(L, NextIndent, OpenLater, CloseLater,
			Indices, Used, NumIndices, Result0, NewVal0,
			NewIndent, DeepResult, DeepNewVal, 
			Temps1, InnerOpens, InnerCloses),
	append(Temps0, Temps1, Temps),
	append([InitResult, StartLoop, UpdateModel, InnerOpens], Opens),
	append([InnerCloses, EndLoop, CloseNest], Closes).

make_array_extractor(_, Indent, Open, Close, [], _,_,
		Result, NewVal,
		Indent, Result, NewVal, [], Open, Close).

make_subresult_loop(L, Used, 
		Indent, InstanceIdRef, NumIndices, Result, NewValue,
		Temps, InitResult, UpdateModel, CloseNest,
		PartResult, WriteValue) :-
	generate_name(L, partresult, PartResult, Used),
	generate_name(L, writevalue, WriteValue, Used),
	generate_name(L, writelength, WriteLength, Used),
	generate_name(L, writeindex, WriteIndex, Used),
	generate_name(L, writearray, WriteArray, Used),
	resolve_pointer(L, PartResult, PartResultPtd),
	resolve_pointer(L, WriteValue, WriteValuePtd),
	resolve_pointer(L, WriteArray, WriteArrayPtd),
	resolve_pointer(L, WriteArrayPtd, WriteArrayPtdPtd),
	Temps = [['Tcl_Obj', PartResultPtd, []],
			['Tcl_Obj', WriteValuePtd, []],
			[int, WriteLength, []],
			[int, WriteIndex, []],
			['Tcl_Obj', WriteArrayPtdPtd, []]],
	refer_value(L, NewValue, NewValueRef),
	render(L, else_clause, NewValue, Indent, ElseWriting),
	render(L, assignment, WriteValue=NewValueRef, Indent, NotWriting),
	render(L, end(cond), NewValue, Indent, EndWriting),
	(L = c,
	    render(L, if_start, NewValueRef, Indent, TestWriting),
		make_pointer(L, WriteLength, WriteLengthPtr),
		make_pointer(L, WriteArray, WriteArrayPtr),
		ConvertListProc =.. ['Tcl_ListObjGetElements', 'NULL', NewValue,
				WriteLengthPtr, WriteArrayPtr],
		FillNestProc =.. ['Tcl_ListObjAppendElement', 'NULL', Result,
				PartResult],
		render(L, procedure_call, ConvertListProc, Indent, InitResult1),
		render(L, procedure_call, FillNestProc, Indent, CloseNest),
		IndexableArray = WriteArray;
	L = tcl,
	    format_to_chars("[string compare ~a NULL]", [NewValueRef],
			    NullTestStr),
	    name(NullTest, NullTestStr),
	    render(L, if_start, NullTest, Indent, TestWriting),
	    format_to_chars("[llength ~a]", [NewValueRef], LengthExprStr),
		name(LengthExpr, LengthExprStr),
		render(L, assignment, WriteLength=LengthExpr, Indent, InitResult1),
		refer_value(L, PartResult, RefPartResult),
		render(L, procedure_call, lappend(Result, RefPartResult),
				Indent, CloseNest),
		IndexableArray = NewValue),
	get_empty_list(L, NewList),
	render(L, assignment, PartResult=NewList, Indent, InitResult0),
	render(L, assignment, WriteIndex=0, Indent, InitResult2),
	append([InitResult0, TestWriting, InitResult1, InitResult2,
		ElseWriting, NotWriting, EndWriting], InitResult),

	Indent1 is Indent + 4,
	Indent2 is Indent1 + 4,
	Indent3 is Indent2 + 4,
	render(L, assignment, WriteValue=NewList, Indent1, UpdateModel0),
	refer_value(L, WriteIndex, WriteIndexRef),
	make_pointer(L, WriteIndex, WriteIndexPtr),
	refer_value(L, WriteLength, WriteLengthRef),
	refer_value(L, IndexableArray, IARef),

	(NumIndices = -1, !, /* population etc */
		make_procedure_call_chars(L, [compare_values, IARef,
					      WriteIndexPtr, InstanceIdRef,
					      WriteLengthRef, 2], CompProcStr),
		refer_value(L, InstanceId, InstanceIdRef),
		add_to_result(L, PartResult, InstanceId,
				'NULL', Indent1, FillNest);
	NumIndices = 0, !, /* simple conditional submodel */
		CompProcStr = "1",
		(L = c, 
			render(L, procedure_call, putarrayinresult('NULL',
				NumIndices, 'NULL', PartResult),
				Indent1, FillNest);
		L = tcl,
			render(L, procedure_call, 
					lappend(PartResult, '{}'), 
					Indent1, FillNest));
	make_procedure_call_chars(L, [compare_lists, NumIndices,
				      IARef, WriteIndexPtr,
				      InstanceIdRef, WriteLengthRef, 2], 
			CompProcStr),
		(L = c, 
			render(L, procedure_call, putarrayinresult('NULL',
				NumIndices, InstanceIdRef, PartResult),
				Indent1, FillNest);
		L = tcl,
			render(L, procedure_call, 
					lappend(PartResult, InstanceIdRef), 
					Indent1, FillNest))),
	name(CompProc, CompProcStr),

	render(L, if_start, CompProc == 1, Indent2, UpdateModel2),
	make_expr(L, WriteIndexRef + 1, NextElmtPosn),
	get_element_ref(L, IndexableArray, NextElmtPosn, ValueToWrite),
	render(L, assignment, WriteValue=ValueToWrite, Indent3, UpdateModel3), 
	render(L, end(cond), 'if new val for this elt', Indent2, UpdateModel4),
	append([TestWriting, UpdateModel0, UpdateModel2,
		UpdateModel3, UpdateModel4,
		EndWriting, FillNest], UpdateModel).
