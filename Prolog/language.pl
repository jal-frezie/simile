/*******************************************************************************
**** LANGUAGE module. This module contains all the templates necessary      ****
**** to compile AME code. Everything is parameterised by language, BASIC    ****
**** being the starting point.                                              ****
*******************************************************************************/

sicstus_module( language, [do_assign_list/9, make_evaluation_routine_all/5] ).

sicstus_use_module( [sp_only, render,m_class,utility,
		ame_gen,units,text,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
make_new_check(L, Pointer, NewTest) :-
	make_struct_reference(L, Pointer, new_instance, NewTestVar),
	refer_value(L, NewTestVar, NewTest).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fill_instance_ids(c, N, Pointer, [], Indent, Terminator) :-
		make_indexed_reference(c, instanceid, [N], IArray),
		make_struct_reference(c, Pointer, IArray, ISlot),
		render(c, assignment, ISlot=0, Indent, Terminator).

fill_instance_ids(c, N, Pointer, [RefIndex | RefIndices],
			Indent, [FillNow | FillLater]) :-
		make_indexed_reference(c, instanceid, [N], IArray),
		make_struct_reference(c, Pointer, IArray, ISlot),
		render(c, assignment, ISlot=RefIndex, Indent, [FillNow]),
		NPlus is N+1,
		fill_instance_ids(c, NPlus, Pointer, RefIndices,
				Indent, FillLater).

fill_instance_ids(tcl, _, Pointer, RefIndices,
			Indent, FillLater) :-
		make_struct_reference(tcl, Pointer, instanceid, Target),
		make_procedure_call_chars(tcl, [concat | RefIndices], NewRefStr),
		name(NewRef, NewRefStr),
		render(tcl, assignment, Target=NewRef, Indent, FillLater).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* do_assign_list/9: This takes a list of assignments interspersed with
start_submodel and end_submodel statements, the start containing the
submodel name, the pointer used inside to refer to it, and the number of
instances. Args have become rather many; they are as follows:

Sent:
-----
L: The target language eg. c, tcl
Clauses: The list of assignments etc to be processed
Graph_count: Number of graphs made so far
Preambles: Code to go before currently open loops (list of lists)
Postambles: Code to go in currently open loops (likewise)

Modified:
---------
Used: Open-ended list of used variable names, needed when generating new index variables

Returned:
---------
Graphs: Info for graph data structures, separate from code so they can be
	edited in the exported model
Temps: Names of temporary variables created to hold intermediate results.
Results: The generated code.

The actual procedures have been renamed do_assignment, so I can put in
an exception if one of them fails, to assist debugging. */

do_assign_list(L, [Clause | Clauses],
		Graph_count, Preambles, Postambles,
		Used, Graphs, Temps, Results) :-
	/* write_to_chars(Clause, ClauseMess),
	dialogue:reassure_user(ClauseMess), test only */
	do_assignment(L, [Clause | Clauses],
		      Graph_count, Preambles, Postambles,
			Used, Graphs, Temps, Results);
	raise_exception(cannot_convert_to_code(Clause)).

do_assign_list(_, [], _, [], [Result], _, [], [], Result).

/* This makes a loop for a fixed membership submodel.
Should really be done with make_array_assignment. */

do_assignment(L, [open_index(glob(Loop, Inds), loop(Bound)) | Clauses],
                GraphCount, Preambles, 
                [Current | Postambles],
                Used, Graphs, Temps, Results) :-
        length(Postambles, Nesting),
        Indent is 4*Nesting,
	check_local_var(L, Loop, loop, int, Used, Temps0),
        make_indexed_reference(L, Loop, Inds, Count),
        render(L, for_start, [Count, 1, Bound, 1], Indent, Open),
        render(L, end(for), Count, Indent, Close),

        do_assign_list(L, Clauses,
                       GraphCount, [Current | Preambles],
                       [Open, Close | Postambles],
                       Used, Graphs, Temps1, Results),
	merge_lists(Temps1, Temps0, Temps).

/* Start fixed membership submodel. Note that we may have selected an index
explicitly (using element(...)), so it can contain any expression, even a
graph. */

do_assignment(L, [start_submodel(Name, Top, Pointer, fm_loop(IndExprs, Alarm))
		 | Clauses], Graph_count, Preambles, 
	      [Current | Postambles],
	      Used, Graphs, Temps, Results) :-

	length(Preambles, Nesting),
	Indent is 4*Nesting,
	/* some of this belongs in the next disjunction */

	append_atoms(Name, 'type*', Type),
        append_atoms(Name, pointer, PointerForm),
	check_local_var(L, Pointer, PointerForm, Type, Used, Temps0),

	make_evaluation_routine_all(L, IndExprs, Graph_count,
				    RefIndices, Graph_data),
	all(render, make_expr,
	    [unify(L), build(RefIndices), build(RefExprs)]),
	render(L, enter_context, Pointer=[Top, Name, RefExprs], 
	       Indent, Entry),
	(nonvar(Alarm), !,
	    make_struct_reference(L, Pointer, Alarm, AlarmVar),
	    render(L, assignment, AlarmVar=1, Indent, Init),
	    render(L, while_start, 1, Indent, OpenInf),
	    render(L, end(while), alarm, Indent, CloseInf),
	    refer_value(L, AlarmVar, AlarmRef),
	    render(L, if_start, AlarmRef, Indent, OpenBrk),
	    render(L, end(cond), AlarmRef, Indent, CloseBrk),
	    render(L, break, _, Indent, Break),
	    append([Entry, Init, OpenInf], Starters),
	    append([OpenBrk, Break, CloseBrk, CloseInf], Finishers);
	Starters = Entry,
	    Finishers = []),

	(nonvar(Graph_data), !,
	    NewGraphCount is Graph_count + 1,
	    Graphs = [[index | Graph_data] | LaterGraphs];
	NewGraphCount = Graph_count,
	    Graphs = LaterGraphs),

	do_assign_list(L, Clauses, NewGraphCount, [Current | Preambles],
			[Starters, Finishers | Postambles],
			Used, LaterGraphs, Temps1, Results),
	merge_lists(Temps1, Temps0, Temps).


/* start non-generating vm  submodel loop;	still need to
add context for associated submodels if it is
variable length, otherwise add the loops to explicitly
hunt through them */

do_assignment(L, [start_submodel(Name, Top, Pointer, LoopSpec)
		 | Clauses], Graph_count, Preambles, 
	      [Current | Postambles],
	      Used, Graphs, Temps, Results) :-

	length(Preambles, Nesting),
	Indent is 4*Nesting,
	/* some of this belongs in the next disjunction */

	(LoopSpec = rm_loop(ArcIndex, Level, IExprs), !,
	    check_local_var(L, Pointer, externpointer, 'void*', Used, Temps0),
	    refer_value(L, Pointer, PointerRef),

	    length(IExprs, IndCount),
	    make_procedure_call_chars(L, [arrange_indices, IndCount | IExprs],
				      AIStr),
	    name(ArrInds, AIStr),
	    make_procedure_call_chars(L, [import_ptr, Level, Top,
					  ArcIndex, ArrInds], LXStr),
	    name(StartPtrRef, LXStr),

	    /* finish same: move pointer to next instance in chain */
	    make_procedure_call_chars(L, [advance_ptr, myClassPtr, PointerRef],
				      AdvanceStr),
	    name(OnPointerRef, AdvanceStr);

	LoopSpec = vm_loop(_,_, BaseLoops, _), !,
	    append_atoms(Name, 'type*', Type),
	    append_atoms(Name, pointer, PointerForm),
	    check_local_var(L, Pointer, PointerForm, Type, Used, Temps0),
	    refer_value(L, Pointer, PointerRef),
	    all(compile, get_base_ptrs,
		[build(BaseLoops), append(Names, []), append(BasePtrs, [])]),
	    make_struct_reference(L, Top, Name, StartPointer),
	    refer_value(L, StartPointer, StartPtrRef),

	    /* finish same: move pointer to next instance in chain */
	    make_struct_reference(L, Pointer, next, OnPointer),
	    refer_value(L, OnPointer, OnPointerRef)),

	render(L, assignment, Pointer=StartPtrRef, Indent, PreStart),
	ptr_compare(L, PointerRef, 0, PtrNonNull),
	render(L, while_start, PtrNonNull, Indent, Starts),
	Indent1 is Indent + 4,
	render(L, assignment, Pointer=OnPointerRef, Indent1, PreFinish),
	render(L, end(while), Pointer, Indent, Finish),
	move_base_ptrs(L, Pointer, restore, Indent1, Names, BasePtrs,
		       LoadBaseRefs),
	append([PreStart, Starts, LoadBaseRefs], Starters),
	append([PreFinish, Finish], Finishers),

	do_assign_list(L, Clauses, Graph_count, [Current | Preambles],
			[Starters, Finishers | Postambles],
			Used, Graphs, Temps1, Results),
	merge_lists(Temps1, Temps0, Temps).


/* Start a submodel loop with a generate/test pair inside. This happens once per time step for variable membership models apart from populations. Each possible instance of the model is either generated or pulled out of the list, for testing later. If the phase is 'new' then previously existing instances are skipped over. */

do_assignment(L, [generate(Name, Top, Pointer, Phase, VMPtrs, LocalIndices,
			   BasePtrs) | Clauses],
	      Graph_count, Preambles, 
	      [Current | Postambles], Used, Graphs, Temps, Results) :-

	length(Preambles, Nesting),
	Indent is 4*Nesting,
	Indent1 is Indent + 4,
	Indent2 is Indent1 + 4,
	Indent3 is Indent2 + 4,
	Indent4 is Indent3 + 4,

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, PointerForm),
	check_local_var(L, Pointer, PointerForm, Type, Used, Temps0),
	make_evaluation_routine_all(L, LocalIndices, 0, RefIndices, _),
	make_struct_reference(L, Pointer, next, OnPointer),
	refer_value(L, OnPointer, OnPointerRef),

	append_atoms(Name, meta, Meta),
	resolve_pointer(L, Meta, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),

	make_struct_reference(L, Pointer, new_instance, NewInstance),

	(RefIndices = [], !,
	    ptr_compare(L, MPTargetRef, 0, CallPrune);
	length(RefIndices, NumIndices),
	    (L = c,
	        PruneArgs = [Meta, NumIndices | RefIndices];
	    L = tcl,
	        make_procedure_call_chars(tcl, [concat | RefIndices],
					  NewRefStr),
	        name(NewRef, NewRefStr),
	        PruneArgs = [NewRef, Meta, NumIndices]),
	    make_procedure_call_chars(L, [prune | PruneArgs], CallPruneStr),
	    name(CallPrune, CallPruneStr)),
	
	(number(Phase), !, /* this should happen sometimes -- does it?
			   For the time being I have made damn sure it
			   does not because there were free variables
			   in MemberCheckTest */
	    generate_name(L, check_members, MemberCheck, Used),
	    Temps1 = [[int, MemberCheck, []]],
	    make_section_cond(L, VMPtrs, MemberCheckTest),
	    combine(L, >=, [Phase, MemberCheckTest], MemberCheckExpr),
	    render(L, assignment, MemberCheck=MemberCheckExpr, Indent2,
		   MakeMemberCheck),
	    refer_value(L, MemberCheck, MemberCheckRef),

	    render(L, if_start, MemberCheckRef, Indent3, IfChecking),
	    render(L, else_clause, MemberCheckRef, Indent3, CheckElse),
	    render(L, make_reference, Meta = OnPointer, Indent4, StepOver),
	    render(L, end(cond), MemberCheckRef, Indent3, CheckEnd);
	[MakeMemberCheck, IfChecking, CheckElse, StepOver, CheckEnd, Temps1]
	= [[], [], [], [], [], []]),
	
	render(L, if_start, CallPrune, Indent2, DoPrune),
	render(L, open_context, Pointer=[Top, Name, MPTargetRef],
	       Indent3, OpenExisting),
	render(L, assignment, NewInstance=0, Indent3, MarkOld),
	/* IfChecking */
	render(L, assignment, MPTarget=OnPointerRef, Indent4, Snip),
	/* CheckElse, StepOver, CheckEnd */
	render(L, else_clause, 'Instance exists', Indent2, ElsePrune),
	/* IfChecking */
	render(L, assign_space, Pointer=[Top, Name, RefIndices],
	       Indent4, MakeNew),
	/* record instance id -- this is list of all count
	values local and remote, with a 0 at the end so the extractor
	knows where to stop */
	fill_instance_ids(L, 0, Pointer, RefIndices, Indent4, FillInstanceId),
	move_base_ptrs(L, Pointer, save, Indent4, _, BasePtrs, SaveBaseRefs),
	render(L, assignment, NewInstance=1, Indent4, MarkNew),
	/* CheckEnd */
	render(L, end(cond), 'Instance exists', Indent2, PruneEnd),
	/* IfChecking */
	
	append([MakeMemberCheck, DoPrune, OpenExisting, MarkOld,
		IfChecking, Snip, CheckElse, StepOver, CheckEnd, ElsePrune,
		IfChecking, MakeNew, FillInstanceId, SaveBaseRefs,
		MarkNew, CheckEnd, PruneEnd, IfChecking], Starters),
	Finishers = CheckEnd,
	/* That should make some good code */

	do_assign_list(L, Clauses,
			Graph_count, [Current | Preambles],
			[Starters, Finishers | Postambles],
			Used, Graphs, Temps2, Results),
	merge_lists(Temps1, Temps2, Temps3),
	merge_lists(Temps0, Temps3, Temps).

do_assignment(L, [bound_gen_loop(Top, Name) | Clauses],
	      Graph_count, Preambles, 
	      [Current | Postambles], Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is 4*Nesting,
	make_struct_reference(L, Top, Name, SubPointer),
	append_atoms(Name, meta, Meta),
	render(L, make_reference, Meta=SubPointer, Indent, Starters),

	/* And here's the stuff that goes at the end of the loop... */
	resolve_pointer(L, Meta, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	render(L, procedure_call, delete_list(MPTargetRef), Indent, ChopTail),
	render(L, assignment, MPTarget=0, Indent, EndLoop),
	append(ChopTail, EndLoop, Finishers),

	do_assign_list(L, Clauses,
			Graph_count, [Current | Preambles],
			[Starters, Finishers | Postambles],
			Used, Graphs, Temps, Results).

/* Nowadays we may want to stick the emptying of a list at any point in the
program. So it needs its own clause... */

do_assignment(L, [reset_list(Ptr, Name) | Clauses],
		Graph_count, 
		Preambles, [Current | Postambles],
		Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is 4*Nesting,
	make_struct_reference(L, Ptr, Name, Ref),
	(L = c,
	    render(L, procedure_call, delete_list(Ref), Indent, L1),
	    append(L1, L2, DelCode);
	L = tcl,
	    DelCode = L2),
	render(L, assignment, Ref=0, Indent, L2),
	append(Current, DelCode, NewCurrent),
	do_assign_list(L, Clauses,
			Graph_count, Preambles, [NewCurrent | Postambles],
			Used, Graphs, Temps, Results).

/* Clause to handle end of a submodel loop does not actually generate any code (this
is all done at start submodel time) but rearranges the preambles and postambles so
subsequent stuff is put outside the loop.
*/

do_assignment(L, [finish_level | Clauses], Graph_count,
		[LastCurrent | Preambles], [Current, NextCurrent | Postambles],
		Used, Graphs, Temps, Results) :-

	append([LastCurrent, Current, NextCurrent, ['']], NewCurrent),
	do_assign_list(L, Clauses, Graph_count,
		Preambles, [NewCurrent | Postambles],
		Used, Graphs, Temps, Results).

/* Here's a really easy clause that enables program statements in the right language
to be stuck directly into the instruction queue. The reason for doing this is so that
when generating new instances, I can leave the conditional open while I add the
initialization of the instance, then slip in the close after it. All this would be
unnecessary if the thing were designed so it could call itself on parts of the
program. I blame Geraint....*/

do_assignment(L, [verbatim(CodeLine) | Clauses],
		Graph_count, 
		Preambles, [Current | Postambles],
		Used, Graphs, Temps, Results) :-
	append(Current, CodeLine, NewCurrent),
	do_assign_list(L, Clauses,
			Graph_count, Preambles, [NewCurrent | Postambles],
			Used, Graphs, Temps, Results).

do_assignment(L, [SpecialOp | Clauses],
		Graph_count, 
		Preambles, [Current | Postambles],
		Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is Nesting*4,

	(SpecialOp =.. [collect, DestSpec | Args],
	    make_scalar(L, DestSpec, 0, Dest, _),
	    make_evaluation_routine_all(L, Args, 0, [NodeId | Inds], _),
	    refer(L, Dest, DestRef),
	    render:make_constant_string(L, NodeId, Node),
	    CallSpec =.. [collect, DestRef, Node | Inds];
	SpecialOp =.. [SubCall, NodeId, InstHandle, NewCond],
	    member(SubCall,
		   [update_submodel, int_eval_submodel, ext_eval_submodel]),
	    make_section_cond(L, NewCond, PassTest),
	    render:make_constant_string(L, NodeId, Node),
	    make_scalar(L, InstHandle, _, InstPtr, _),
	    refer_value(L, InstPtr, InstHandleRef),
	    CallSpec =.. [SubCall, Node, InstHandleRef, start_time, PassTest];
	SpecialOp = search_from(ArcInd, _, TopRef),
	    CallSpec = search_from(myClassPtr, ArcInd, TopRef)), 
	render(L, procedure_call, CallSpec, Indent, CodeLine),
	append(Current, CodeLine, NewCurrent),
	do_assign_list(L, Clauses,
			Graph_count, Preambles, [NewCurrent | Postambles],
			Used, Graphs, Temps, Results).

/* This one starts a conditional execution sequence dependent on the
given submodel */

do_assignment(L, [check_phase(Phase, VMPtrs) | Clauses], Graph_count, 
	      Preambles, [Current | Postambles],
	      Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is Nesting*4,

	make_section_cond(L, VMPtrs, PassTest),
	combine(L, >=, [Phase, PassTest], PhaseTest),
	render(L, if_start, PhaseTest, Indent, Test),
	render(L, end(cond), PhaseTest, Indent, Finishers),
	NewPres = [Current | Preambles],
	NewPosts = [Test, Finishers | Postambles],
	do_assign_list(L, Clauses,
		       Graph_count, NewPres, NewPosts,
		       Used, Graphs, Temps, Results).

/* This one should be easy too. When I extract the procedures for initializing
submodel instances where these can't always be done at init time, I leave an
'init_population' node. For population submodels, which do also need to be
initialized when their parents are, this causes the tests to be done and the
inits to be included.

Atrocious hack alert: For loops have to go from low to high, so people using rollover
models get array values generated in the expected order. Interaction submodels
created within for loops therefore have instance ids running from low to high along
the list. All variable-membership submodels must have instance ids running the same
way, to check for instances associated with dead ones. New population members are
added at the beginning of the list, this is quicker than going to the end. 
Therefore instance ids count downwards and are negative. */

do_assignment(L, [new_member(ParentPtr, Name, NewSpec) | Clauses],
	      Graph_count, Preambles, [Current | Postambles],
	      Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is Nesting*4,
	Indent1 is Indent + 4,

	append_atoms(Name, count, Count),
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	make_struct_reference(L, ParentPtr, Count, Index), 
	refer_value(L, Index, RefIndex),

	NewSpec =.. [_, InitVar],
	UseElementRef = RefIndex,
	make_struct_reference(L, ParentPtr, InitVar, CompVal),
	refer_value(L, CompVal, CompValRef),

	/* Now loop on compartment to create submodel */
	render(L, while_start, CompValRef>=1, Indent, Loop0),
	make_expr(L, CompValRef-1, NewCompVal),
	render(L, assignment, CompVal=NewCompVal, Indent1, Loop1),
	render(L, increment_by, [Index, 1], Indent1, Loop1a),
	render(L, assign_space, Pointer=[ParentPtr, Name, [UseElementRef]],
	       Indent1, Loop2),
	nth(ChannelN, Used, InitVar), !,
	render(L, procedure_call, init_pop_member(Pointer, RefIndex, 0,
						  ChannelN), Indent1, Loop3),
	/* no parent we are doing creation/immigration here */
	append([Loop0, Loop1, Loop1a, Loop2, Loop3], Starters),

	/* End of submodel loop; insert into list and do next */
	refer_value(L, Pointer, PointerRef),
	render(L, assignment, MPTarget=PointerRef, Indent1, EndLoop0),
	make_struct_reference(L, Pointer, next, OnPointer),
	render(L, make_reference, MetaPointer=OnPointer, Indent1, EndLoop1),
	render(L, end(while), 'New instances', Indent, EndLoop4),
	append([EndLoop0, EndLoop1, EndLoop4], Finishers),

	/* Get init from procedures and put in continuation of this loop; do not
	remove them from the list I will need them again for update */
	Continuation = [finish_level | Clauses], 

	do_assign_list(L, Continuation, Graph_count, [Current | Preambles],
			[Starters, Finishers | Postambles],
			Used, Graphs, Temps0, Results),
	merge_lists([[Type, Pointer, []]], Temps0, Temps).

/* This is similar to the last one, but handles reproduction. Owing to the
limitations of Tcl it switches context between current instance and new instances.
This could be avoided by peeking at the reproduction compartment then decrementing
it in a local variable, but this way is conceptually simpler, which is everything.
*/

do_assignment(L, [reproduce(ParentPtr, Name, ReproName) | Clauses],
	      Graph_count, Preambles, [Current | Postambles],
	      Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is Nesting*4,
	Indent1 is Indent + 4,
	Indent2 is Indent1 + 4,

	/* Now stick in a loop */
	make_struct_reference(L, ParentPtr, Name, SubmodelStartPtr),
	refer_value(L, SubmodelStartPtr, SubmodelStartPtrRef),
	append_atoms(Name, count, Count),
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	make_struct_reference(L, ParentPtr, Count, Index), 
	refer_value(L, Index, RefIndex),

	/* Set pointer to first model in list, and dive into loop */
	render(L, assignment, Pointer=SubmodelStartPtrRef, Indent, Loop0),
	refer_value(L, Pointer, PointerRef),
	ptr_compare(L, PointerRef, 0, NotDone),
	render(L, while_start, NotDone, Indent, Loop1),

	/* Conditional to avoid reproduction with new individuals  -- they have
	not been initialized yet */
	make_new_check(L, Pointer, ParentNewRef),
	combine(L, !, [ParentNewRef], ParentOld),
	render(L, if_start, ParentOld, Indent1, CheckOld),
	render(L, end(cond), ParentOld, Indent1, OldCheckDone),
	
	make_struct_reference(L, Pointer, ReproName, Repro),
	refer_value(L, Repro, ReproRef),
	make_struct_reference(L, Pointer, instanceid, ParentArray),
	(L = c,
	    make_indexed_reference(L, ParentArray, [0], ParentId);
	 L = tcl,
	    ParentId = ParentArray),
	refer_value(L, ParentId, ParentRef),
	render(L, while_start, ReproRef>=1, Indent1, Loop3),
	make_expr(L, ReproRef-1, NewRepro),
	/* cannot use decrement because quantity is floating point */
	render(L, assignment, Repro=NewRepro, Indent2, Loop4),

	/* Now make context for new individual */
	render(L, increment_by, [Index, 1], Indent2, Loop6),
	render(L, assign_space, 
			MPTarget=[ParentPtr, Name, [RefIndex]],
			Indent2, Loop7),
	nth(ChannelN, Used, ReproName), !,
	render(L, procedure_call, init_pop_member(MPTarget, RefIndex, ParentRef,
						  ChannelN), Indent1, Loop8),
	append([Loop0, Loop1, CheckOld, Loop3, Loop4,
		Loop6, Loop7, Loop8], Starters),

	/* End of submodel loop; insert into list and do next */
	make_struct_reference(L, MPTarget, next, OnMeta),
	render(L, make_reference, MetaPointer=OnMeta, Indent2, EndLoop1),
	render(L, end(while), Repro, Indent1, EndLoop4),
	make_struct_reference(L, Pointer, next, OnPointer),
	refer_value(L, OnPointer, OnPointerRef),
	render(L, assignment, Pointer=OnPointerRef, Indent1, EndLoop9),
	render(L, end(while), PointerRef, Indent, EndLoop12),
	append([EndLoop1, EndLoop4, OldCheckDone,
			EndLoop9, EndLoop12], Finishers),

	/* Get init from procedures and put in continuation of this loop; do not
	remove them from the list I will need them again for update */
	Continuation = [finish_level | Clauses], 

	do_assign_list(L, Continuation, Graph_count, [Current | Preambles],
			[Starters, Finishers | Postambles],
			Used, Graphs, Temps0, Results),
	merge_lists([[Type, Pointer, []]], Temps0, Temps).

/* OK, now for mortality. This will have to be called before immigration or reproduction because any new individuals might not yet have values for their loss nodes. It used to be done as part of the reproduction loop but had to be separated now there can be many reproduction channels. However, all loss channels are equivalent, so there only needs to
be one of these loops; the instruction has a list of the appropriate nodes. */

do_assignment(L, [lose(Step, ParentPtr, Name, LossNodes) | Clauses],
	      Graph_count, Preambles, [Current | Postambles],
	      Used, Graphs, Temps, Results) :-
	length(Preambles, Nesting),
	Indent is Nesting*4,
	Indent1 is Indent + 4,
	Indent2 is Indent1 + 4,

	/* Now stick in a loop */
	make_struct_reference(L, ParentPtr, Name, SubmodelStartPtr), 

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointer),
	/* Set pointer to first model in list, and dive into loop */
	render(L, make_reference, MetaPointer=SubmodelStartPtr, Indent, Loop0),
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	ptr_compare(L, MPTargetRef, 0, NotDone),
	render(L, while_start, NotDone, Indent, Loop1),
	render(L, open_context, Pointer=[ParentPtr, Name, MPTargetRef],
			Indent1, Loop2),

	/* Conditional to avoid offing new individuals  -- they have
	not been initialized yet */
	make_struct_reference(L, Pointer, new_instance, NewInstance),
	make_new_check(L, Pointer, NoInitDone),
	
	/* Next remove shagged-out individuals, node is a variable, and move
		on to next instance */
	/* Now dig out the variable names for the loss nodes...add
		probability preprocessing here too */

	make_struct_reference(L, Pointer, 'next', OnPointer),
	render(L, make_reference, MetaPointer=OnPointer, Indent2, EndLoop9),
	render(L, end(while), MPTargetRef, Indent, EndLoop12),

	render(L, if_start, NoInitDone, Indent1, CheckSet),
	render(L, else_clause, NoInitDone, Indent1, NotSet),
	render(L, assignment, NewInstance=0, Indent2, SetLoserOld),
	render(L, end(cond), NoInitDone, Indent1, SetCheckDone),
	(setof(LossTerm, LossVal^(get_term_refs(L, Pointer, LossNodes, LossVal),
			test_probs(L, LossVal, Step, LossTerm)), LossTerms), !,
	    build_disjunction(L, LossTerms, IsDead),

	    render(L, if_start, IsDead, Indent1, EndLoop5),
	    refer_value(L, OnPointer, OnPointerRef),
	    render(L, assignment, MPTarget=OnPointerRef, Indent2, EndLoop6),
	    render(L, release_memory, Pointer, Indent2, EndLoop7),
	    render(L, else_clause, IsDead, Indent1, EndLoop8),
	    render(L, end(cond), IsDead, Indent1, EndLoop10),

	    append([Current, Loop0, Loop1, Loop2,
		    CheckSet, SetLoserOld, EndLoop9,
		    NotSet, EndLoop5, EndLoop6,
		    EndLoop7, EndLoop8, EndLoop9, EndLoop10, 
		    SetCheckDone,
		    EndLoop12], NewCurrent);
	append([Current, Loop0, Loop1, Loop2, CheckSet, SetLoserOld, NotSet,
		SetCheckDone,
		EndLoop9, EndLoop12], NewCurrent)),    
	do_assign_list(L, Clauses,
			Graph_count, Preambles, [NewCurrent | Postambles],
			Used, Graphs, Temps0, Results),
	merge_lists([[Type, Pointer, []]], Temps0, Temps).

/* This is a fairly horrrible clause that puts in what is done when a new submodel
instance is generated; if the instance fails to exist, it terminates building it,
so the end of the last if clause is left on the postambles. Should be less
horrible now it no longer includes the evaluation of the test! */

do_assignment(L, [test(Name, Pointer, Source) | Clauses],
		GraphN, Preambles, Postambles0,
		Used, GraphD, Temps, Results) :-
	length(Preambles, TotalNesting),
	

/* Some variable membership models will contain 'dummy' generator clauses to
make sure they get set up and kept in correspondence with their uncles before
any of their values are calculated. The source is 1 on these; in this case
we only make the three lines that insert the submodel instance into its linked list. 
*/

	(\+ Source == 1, !,
	    (setof(GenVal, get_term_refs(L, Pointer, Source, GenVal), GenVals),
		build_disjunction(L, GenVals, TestVal), !;
	    TestVal = 0),
	    Indent is TotalNesting*4,
	    render(L, if_start, TestVal, Indent, Result0),
	    Indent1 is Indent+4;
	/* clause for dummy generator */
	Indent1 is TotalNesting*4,
		Result0 = []),

	make_struct_reference(L, Pointer, next, OnPointer),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	refer_value(L, Pointer, PointerRef),
	render(L, assignment, OnPointer=MPTargetRef, Indent1, Result2),

	render(L, assignment, MPTarget=PointerRef, Indent1, Result3),

	render(L, make_reference, MetaPointer=OnPointer, Indent1, Result4),

	/* Any further assignments in model generation also go inside this 'if'
	clause, so as not to do them is the submodel instance does not exist. Thus
	the 'else' clause and other condition go in the postamble. */
	(\+ Source == 1, !,
	    render(L, else_clause, TestVal, Indent, EndLoop0),
	    render(L, release_memory, Pointer, Indent1, EndLoop2),
	    render(L, end(cond), TestVal, Indent, EndLoop4),
	    append([EndLoop0, EndLoop2, EndLoop4], Finishers);
	Finishers = []),
	
	append([Result0, Result2, Result3, Result4], Ongoing),
	Postambles0 = [Current, Next | Postambles],
	append(Current, Ongoing, NewCurrent),
	append(Finishers, Next, NewNext),
	
	do_assign_list(L, Clauses, GraphN, Preambles,
			[NewCurrent, NewNext | Postambles],
			Used, GraphD, Temps, Results).

/* Right, this is the one with the meat in it; the actual integration of new code
that evaluates an expression in the model */

do_assignment(L, [assign(arr(P, Val, Is), Source) | Clauses], GraphN, 
		Preambles, [Current | Postambles],
		Used, GraphD, Temps, Results) :-

	length(Postambles, Nesting),
	Indent is 4*Nesting,
	make_scalar(L, arr(P, Val, Is), GraphN, ScalarDest, Graph_data),
	make_evaluation_routine(L, Source, GraphN, Term, Graph_data),
	make_expr(L, Term, Expr),
	render(L, assignment, ScalarDest=Expr, Indent, Action),

	(nonvar(Graph_data), !,
		NewGraphCount is GraphN + 1,
		GraphD = [[Val | Graph_data] | LaterGraphs];
	NewGraphCount = GraphN,
		GraphD = LaterGraphs),

	append(Current, Action, NewCurrent),
	do_assign_list(L, Clauses,
		       NewGraphCount, Preambles, [NewCurrent | Postambles],
		       Used, LaterGraphs, Temps, Results).

move_base_ptrs(_,_,_,_, [], [], []).
move_base_ptrs(L, Pointer, Action, Indent, [Name | Names], [Ptr | BasePtrs],
	       [Saver | SaveBaseRefs]) :-
	length(BasePtrs, Count),
	make_struct_reference(L, Pointer, baseptrs, SafeArray),
	make_indexed_reference(L, SafeArray, [Count], Target),
	(Action = save,
	    refer_value(L, Ptr, PtrRef),
	    render(L, assignment, Target=PtrRef, Indent, [Saver]);
	Action = restore,
	    /* Now because of the ANSI c++ standard we have
	    to cast the base model pointer explicitly to the
	    right type -- the array in which the assoc model
	    stores them is type (void *) */
	    (L = c,
	        sicstus_format_to_chars("(~atype *)~a", [Name, Target], CastTgtStr),
		name(CastTgt, CastTgtStr);
	    L = tcl,
	        refer_value(L, Target, CastTgt)),
	    render(L, assignment, Ptr=CastTgt, Indent, [Saver])),
	move_base_ptrs(L, Pointer, Action, Indent, Names, BasePtrs,
		       SaveBaseRefs).

make_section_cond(L, VMPtrs, PassTest) :-
	refer_value(L, phase, PhaseRef),
	(VMPtrs = [], !,
	    PassTest = PhaseRef;
	all(language, make_new_base_cond,
	    [unify(L), build(VMPtrs), build(LocaleTests)]),
	    build_disjunction(L, LocaleTests, NewTest),
	    combine(L, ?, [NewTest, -1:PhaseRef], PassTest)).
	    
	
make_new_base_cond(L, new_context(Ptr, Phase), LocCond) :-
	refer_value(L, phase, PhaseRef),
	combine(L, >=, [Phase, PhaseRef], PhaseTest),
	make_new_check(L, Ptr, FlagTest),
	combine(L, '&&', [PhaseTest, FlagTest], LocCond).

check_local_var(L, Name, NameBase, Type, Used, Temps) :-
    (nonvar(Name), !;
    generate_name(L, NameBase, Name, Used)),
    Temps = [[Type, Name, []]].
	
get_term_refs(_,_, Test, Test) :-
	atom(Test), \+ Test=[].

get_term_refs(L, Pointer, LossNodes, DeadRef) :-
	member(LossVal, LossNodes),
	make_struct_reference(L, Pointer, LossVal, IsDead),
	refer_value(L, IsDead, DeadRef).

/* special clause for use from membership setter, which passes its list match
test instead of a list of local cond nodes...*/

build_disjunction(_, [Item], Item).

build_disjunction(L, [Item1, Item2 | Rest], Dis) :-
	build_disjunction(L, [Item2 | Rest], Others),
	(L = c; L = tcl), Op = ('||'),
	Dis =.. [Op, Others, Item1].

/* This makes the expression for an individual's probability of dying
from a particular ill over a particular period of time, where Val is
the probability of dying over one time unit. If Val is >= 1, the
result is always 1.

test_probs(L, Val, Step, Result) :-
	make_procedure_call_chars(L, [glob_element, dts, Step], MultValStr),
	name(MultVal, MultValStr),
	combine(L, rand, [0,1], Fate),
	combine(L, max, [1-Val, 0], Chance),
	combine(L, ^, [Chance, MultVal], Survives),
	combine(L, >, [Fate, Survives], Result).

Waste of time building this expr for every loss node every run: it is now
in the support code where it can also check the integration method (above
comment left in in case we ever want to build the support code for a new
target language) */

test_probs(L, Val, Step, Result) :-
	make_procedure_call_chars(L, [loses, Val, Step], ResultStr),
	name(Result, ResultStr).

/* Another group of rules with lots of arguments... */
make_evaluation_routine(
	/* Externally defined arguments */
	Language, /* programming language to generate */
	Expr, /* What we are trying to evaluate */
	GraphN, /* Number of slots in the graph data struct used up so far */

	/* Results, i.e., arguments defined here */
	Term, /* the expression that evaluates to the destination
		in current state; -ve = in preambles, +ve = in postambles, 
		0 = inside deepest loop */
	GraphD /* Data set for any graph found evaluating this expression */
	) :-
	(make_scalar(Language, Expr, GraphN, LocalExpr, GraphD),
	    refer_value(Language, LocalExpr, Term);
	Expr = ind(Ptr, Count), !,
	    make_struct_reference(Language, Ptr, instanceid, IndSet),
	    get_element_ref(Language, IndSet, Count, Term);
	number(Expr), !,
	    /* Term=Expr; I think not...
	    this goes num -> chars -> atom -> chars -> atom */
	    print_to_codes(TermStr, Expr),
	    sicstus_atom_chars(Term, TermStr);
	member(Expr, [time(P), ind_time(P)]), !,
	    make_procedure_call_chars(Language, [glob_element, ts, P],
				      TimeElmtStr),
	    name(Term, TimeElmtStr);

	Expr = dt(P), !, /* still used for explicit references to dt */
	    make_procedure_call_chars(Language, [glob_element, dts, P],
				      TimeElmtStr),
	    name(Term, TimeElmtStr);

	Expr = assign(Tgt, SubExpr), !,
	    make_scalar(Language, Tgt, GraphN, Dest, GraphD),
	    make_evaluation_routine(Language, SubExpr, GraphN, Source, GraphD),
	    make_expr(Language, Source, SourceExp),
	    make_assignment(Language, Dest, SourceExp, AssignStr),
	    command_substitute(Language, AssignStr, TermStr),
	    name(Term, TermStr);
	Expr = simile_int(SubExpr), !,
	    (Language = c, Functor = '(int)';
	     Language = tcl, Functor = int),
	    IntExpr =.. [Functor, SubExpr],
	    make_evaluation_routine(Language, IntExpr, GraphN, Term, GraphD);
	Expr = graph(NodeId, XAxis), !,
	    (nonvar(GraphD),
		raise_exception(extra_graph(Expr, XAxis, GraphD));
	    true),
	    NodeId has_class_refinement table_data of
	        [file='/graph/', data=[YLow, YHigh, YSpan],
		 indices=[XLow, XHigh, XSpan, Range], current=PointList,
		 units=_, _, dims=NumPts | _],
	    /* name(Points, PointStr),
	    append([91 | PointStr], "]", PointListStr),
	    get_term(PointListStr, PointList, _), */
	    make_evaluation_routine(Language, XAxis, 0, GraphTerm,
					'higher in same context'),
	    make_expr(Language, GraphTerm, GraphExpr),
	    /* Keep tcl working till it uses c++ graph access */
	    GraphD = [GraphN, GraphN, XLow, XHigh, XSpan,
				YLow, YHigh, YSpan, Range, NumPts | PointList],
	    make_procedure_call_chars(Language,
				      [graphpoint, GraphExpr, GraphN],
				      Content_chars),
/* End of graph clause */
	    name(Term, Content_chars);
	Expr = stop(Ident), !, 
	    make_evaluation_routine(Language, Ident,
					GraphN, XIdent, GraphD),
	    make_expr(Language, XIdent, VIdent),
	    make_procedure_call_chars(Language, [stop, VIdent], Content_chars),
	    name(Term, Content_chars);
	Expr = stage_incr(Struct, Step, Delta), !, 
	    make_scalar(Language, Struct, GraphN, SStruct, GraphD),
	    make_pointer(Language, SStruct, VStruct),
	    make_evaluation_routine_all(Language, [Step, Delta],
					GraphN, [VStep, XDelta], GraphD),
	    make_expr(Language, XDelta, VDelta),
	    make_procedure_call_chars(Language, [stage_incr, VStruct, VStep,
						 VDelta], Content_chars),
	    name(Term, Content_chars);
	Expr =.. [Op | Args],
	    make_evaluation_routine_all(Language, Args, GraphN, VArgs, GraphD),
	    combine(Language, Op, VArgs, Term)).

/* make_evaluation_routine_all/many: Same as above, but takes a list of terms rather
than just one, does not take a destination, and returns a list of expressions
which are rendered usable by the stuff in the preamble. Eventually this will have
to be upgraded to behave properly when the arguments have incompatible source
contexts. */

make_evaluation_routine_all(_, [], _, [], _).

/* For the following we just unify GraphD because no node can have
more than one graph associated with it */

make_evaluation_routine_all(Language, [Expr | Args],
		GraphN, [VArg | VArgs], GraphD) :-
	make_evaluation_routine(Language, Expr, GraphN, VArg, GraphD),
	make_evaluation_routine_all(Language, Args, GraphN, VArgs, GraphD).

make_scalar(L, Param, GraphN, FullLocalExpr, GraphD) :-
	(Param = arr(Ptr, Var, Inds),
	    make_struct_reference(L, Ptr, Var, LocalExpr);
	Param = glob(LocalExpr, Inds),
	    Var = ''), !,
	make_evaluation_routine_all(L, Inds, GraphN, ITerms, GraphD),
	all(render, make_expr, [unify(L), build(ITerms),
				build(IExprs)]),
	(Var = import(Type, _, Level, _, TopPtr, _,_, ArcIndex), !,
	    append_atoms('import_', Type, ImportCmd),
	    length(IExprs, IndCount),
	    make_procedure_call_chars(L, [arrange_indices, IndCount | IExprs],
				      AIStr),
	    name(ArrInds, AIStr),
	    make_procedure_call_chars(L, [ImportCmd, Level, TopPtr,
					  ArcIndex, ArrInds], LXStr),
	    name(FullLocalExpr, LXStr);
	make_indexed_reference(L, LocalExpr, IExprs, FullLocalExpr)).
