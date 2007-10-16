/*******************************************************************************
**** LANGUAGE module. This module contains all the templates necessary      ****
**** to compile AME code. Everything is parameterised by language, BASIC    ****
**** being the starting point.                                              ****
*******************************************************************************/

sicstus_module( language, [do_assign_list/6, indent_is/1] ).

sicstus_use_module( [sp_only, render,m_class,utility,
		ame_gen,units,text,library(lists)] ).

:- dynamic([indent_is/1]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
make_new_check(L, Pointer, NewTest) :-
	make_struct_reference(L, Pointer, new_instance, NewTestVar),
	refer_value(L, NewTestVar, NewTest).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fill_instance_ids(c, _N, _Pointer, [], _Indent, _).

fill_instance_ids(c, N, Pointer, [RefIndex | RefIndices], Indent, Stream) :-
	make_indexed_reference(c, instanceid, [N], IArray),
	make_struct_reference(c, Pointer, IArray, ISlot),
	excrete(c, assignment, ISlot=RefIndex, Indent, Stream),
	NPlus is N+1,
	fill_instance_ids(c, NPlus, Pointer, RefIndices, Indent, Stream).

fill_instance_ids(tcl, _, Pointer, RefIndices, Indent, Stream) :-
	make_struct_reference(tcl, Pointer, instanceid, Target),
	make_procedure_call_chars(tcl, [concat | RefIndices], NewRefStr),
	name(NewRef, NewRefStr),
	excrete(tcl, assignment, Target=NewRef, Indent, Stream).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* do_assign_list/9: This takes a list of assignments interspersed with
start_submodel and end_submodel statements, the start containing the
submodel name, the pointer used inside to refer to it, and the number of
instances. Args have become rather many; they are as follows:

Sent:
-----
L: The target language eg. c, tcl
Clauses: The list of assignments etc to be processed
Graphs: Info for graph data structures, separate from code so they can be
	edited in the exported model
Collects: list of ids of parameters in order of their references
Preambles: Code to go before currently open loops (list of lists)
Postambles: Code to go in currently open loops (likewise)

Modified:
---------
Used: Open-ended list of used variable names, needed when generating new index variables

Returned:
---------
Temps: Names of temporary variables created to hold intermediate results.
Results: The generated code.

The actual procedures have been renamed do_assignment, so I can put in
an exception if one of them fails, to assist debugging. */

do_assign_list(L, [Clause | Clauses],
		Graphs, Collects, Used, Stream) :-
	/* write_to_chars(Clause, ClauseMess),
	dialogue:reassure_user(ClauseMess), test only */
	do_assignment(L, [Clause | Clauses],
		      Graphs, Collects, Used, Stream), !;
	raise_exception(cannot_convert_to_code(Clause)).

do_assign_list(_, [], _, _, _, _).

/* This makes a loop for a fixed membership submodel.
Should really be done with make_array_assignment. */

do_assignment(L, [open_index(glob(Loop, Inds), loop(Bound)) | Clauses],
                GraphCount, Collects, Used, Stream) :-
        retract(indent_is(Indent)),
        NewIndent is Indent+4,
	asserta(indent_is(NewIndent)),
	declare(L, Loop, loop, int, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
        (make_indexed_reference(L, Loop, Inds, Count),
	    excrete(L, for_start, [Count, 1, Bound, 1], Indent, Stream),
	    do_assign_list(L, MyLoop,
                       GraphCount, Collects, Used, Stream),
	    retract(indent_is(_)),
	    asserta(indent_is(Indent)),
	    excrete(L, end(for), Count, Indent, Stream),
	    fail;
	do_assign_list(L, Later, GraphCount, Collects, Used, Stream)).

/* Start fixed membership submodel. Note that we may have selected an index
explicitly (using element(...)), so it can contain any expression, even a
graph. */

do_assignment(L, [start_submodel(Name, Top, Pointer, fm_loop(IndExprs, Alarm))
		 | Clauses], Graphs, Collects, Used, Stream) :-

        indent_is(Indent),
	/* some of this belongs in the next disjunction */

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, PointerForm),
	declare(L, Pointer, PointerForm, Type, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	make_evaluation_routine_all(L, IndExprs, Graphs, RefIndices),
	all(render, make_expr,
	    [unify(L), build(RefIndices), build(RefExprs)]),
	excrete(L, enter_context, Pointer=[Top, Name, RefExprs], 
		Indent, Stream),
	(nonvar(Alarm),
	    make_struct_reference(L, Pointer, Alarm, AlarmVar),
	    excrete(L, assignment, AlarmVar=1, Indent, Stream),
	    excrete(L, while_start, 1, Indent, Stream),
	    retract(indent_is(_)),
	    Indent1 is Indent + 4,
	    asserta(indent_is(Indent1)),
	    (do_assign_list(L, MyLoop, Graphs, Collects, Used, Stream),
		refer_value(L, AlarmVar, AlarmRef),
		excrete(L, if_start, AlarmRef, Indent1, Stream),
		Indent2 is Indent1 + 4,
		excrete(L, break, _, Indent2, Stream),
		excrete(L, end(cond), AlarmRef, Indent1, Stream),
		excrete(L, end(while), alarm, Indent, Stream),
		fail;
	    retract(indent_is(_)),
		asserta(indent_is(Indent)),
		do_assign_list(L, Later, Graphs, Collects, Used, Stream));
	var(Alarm),
	    % if no alarm loop this does not start new context
	    do_assign_list(L, MyLoop, Graphs, Collects, Used, Stream),
	    do_assign_list(L, Later, Graphs, Collects, Used, Stream)).

/* start non-generating vm  submodel loop;	still need to
add context for associated submodels if it is
variable length, otherwise add the loops to explicitly
hunt through them */

do_assignment(L, [start_submodel(Name, Top, Pointer, LoopSpec) | Clauses],
	      Graphs, Collects, Used, Stream) :-
        retract(indent_is(Indent)),
        Indent1 is Indent+4,
	/* some of this belongs in the next disjunction */

	/* LoopSpec = rm_loop(ArcIndex, Level, IExprs), !,
	    check_local_var(L, Pointer, externpointer, 'void*', Used, Temps1),
	    refer_value(L, Pointer, PointerRef),

	    length(IExprs, IndCount),
	    make_procedure_call_chars(L, [arrange_indices, IndCount | IExprs],
				      AIStr),
	    name(ArrInds, AIStr),
	    make_procedure_call_chars(L, [import_ptr, Level, Top,
					  ArcIndex, ArrInds], LXStr),
	    name(StartPtrRef, LXStr),

	    % finish same: move pointer to next instance in chain
	    make_procedure_call_chars(L, [advance_ptr, myClassPtr, PointerRef],
				      AdvanceStr),
	    name(OnPointerRef, AdvanceStr),
	    LoadBaseRefs = []; */

	LoopSpec = vm_loop(_,_, BaseLoops, _),
	all(compile, get_base_ptrs,
	    [build(BaseLoops), append(Names, []), append(BasePtrs, [])]), !,
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, PointerForm),
	declare(L, Pointer, PointerForm, Type, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	refer_value(L, Pointer, PointerRef),
%	all(language, declare,
%	    [unify(L), build(BasePtrs), unify(bad), build(Types),
%	     unify(Used), unify(Indent), unify(Stream)]),
	(make_struct_reference(L, Top, Name, StartPointer),
	    refer_value(L, StartPointer, StartPtrRef),

	    /* finish same: move pointer to next instance in chain */
	    make_struct_reference(L, Pointer, next, OnPointer),
	    refer_value(L, OnPointer, OnPointerRef),
	    excrete(L, assignment, Pointer=StartPtrRef, Indent, Stream),
	    ptr_compare(L, PointerRef, 0, PtrNonNull),
	    excrete(L, while_start, PtrNonNull, Indent, Stream),
	    all(language, declare_ptrs,
		[build(Names), build(Types), build(BasePtrs),
		 unify([L, Indent, Used, Stream])]),
	    move_base_ptrs(L, Pointer, restore, Indent1,
			   Names, BasePtrs, Types, Stream),
	    asserta(indent_is(Indent1)),
	    do_assign_list(L, MyLoop, Graphs, Collects, Used, Stream),
	    retract(indent_is(_)),
	    assert(indent_is(Indent)),
	    excrete(L, assignment, Pointer=OnPointerRef, Indent1, Stream),
	    excrete(L, end(while), Pointer, Indent, Stream),
	    fail;
	do_assign_list(L, Later, Graphs, Collects, Used, Stream)).

/* Start a submodel loop with a generate/test pair inside. This happens once per time step for variable membership models apart from populations. Each possible instance of the model is either generated or pulled out of the list, for testing later. If the phase is 'new' then previously existing instances are skipped over. */

do_assignment(L, [generate(Name, Top, Pointer, Phase, VMPtrs, LocalIndices,
			   BasePtrs) | Clauses],
	      Graphs, Collects, Used, Stream) :-

        retract(indent_is(Indent)),
        Indent1 is Indent+4,

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, PointerForm),
	declare(L, Pointer, PointerForm, Type, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	make_evaluation_routine_all(L, LocalIndices, [], RefIndices),
	make_struct_reference(L, Pointer, next, OnPointer),
	refer_value(L, OnPointer, OnPointerRef),

	append_atoms(Name, meta, Meta),
	resolve_pointer(L, Meta, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),

	make_struct_reference(L, Pointer, new_instance, NewInstance),

	refer_value(L, this, ThisRef),
	excrete(L, procedure_call, abort_check(ThisRef), Indent, Stream),
	length(RefIndices, NumIndices),
	(NumIndices = 0,
	    ptr_compare(L, MPTargetRef, 0, CallPrune);
	 NumIndices > 0,
	    (L = c,
		PruneArgs = [Meta, NumIndices | RefIndices];
	     L = tcl,
		make_procedure_call_chars(tcl, [concat | RefIndices],
					  NewRefStr),
		name(NewRef, NewRefStr),
		PruneArgs = [NewRef, Meta, NumIndices]),
	    make_procedure_call_chars(L, [prune | PruneArgs], CallPruneStr),
	    name(CallPrune, CallPruneStr)),
	
	(number(Phase), /* this should happen sometimes -- does
it?  For the time being I have made damn sure it does not because
there were free variables in MemberCheckTest. Also this would put some
subsequent code in a separate context so its generation should be
failed through to make sure all later temporary variables get declared. */
	    
	    declare(L, MemberCheck, check_members, int, Used, Indent, Stream),
	    make_section_cond(L, VMPtrs, MemberCheckTest),
	    combine(L, >=, [Phase, MemberCheckTest], MemberCheckExpr),
	    excrete(L, assignment, MemberCheck=MemberCheckExpr, Indent,
		    Stream);
	 \+ number(Phase)),
	
	excrete(L, if_start, CallPrune, Indent, Stream),
	excrete(L, open_context, Pointer=[Top, Name, MPTargetRef],
		Indent1, Stream),
	excrete(L, assignment, NewInstance=0, Indent1, Stream),
	/* IfChecking */
	(number(Phase), !,
	    excrete(L, if_start, MemberCheckRef, Indent1, Stream),
	    asserta(indent_is(Indent1)),
	    Indent2 is Indent1+4;
	 \+ number(Phase),
	    asserta(indent_is(Indent)),
	    Indent2 = Indent1),
	excrete(L, assignment, MPTarget=OnPointerRef, Indent2, Stream),
	/* CheckElse, StepOver, CheckEnd */
	(number(Phase),
	    refer_value(L, MemberCheck, MemberCheckRef),
	    excrete(L, else_clause, MemberCheckRef, Indent1, Stream),
	    excrete(L, make_reference, Meta = OnPointer, Indent2, Stream),
	    render(L, end(cond), MemberCheckRef, Indent1, CheckEnd),
	    do_writing(CheckEnd, Stream);
	 \+ number(Phase),
	    CheckEnd = []),
	excrete(L, else_clause, 'Instance exists', Indent, Stream),
	/* IfChecking */
	(number(Phase),
	    excrete(L, if_start, MemberCheckRef, Indent1, Stream);
	 \+ number(Phase)),
	excrete(L, assign_space, Pointer=[Top, Name, RefIndices],
		Indent2, Stream),
	/* record instance id -- this is list of all count
	values local and remote, with a 0 at the end so the extractor
	knows where to stop */
	fill_instance_ids(L, 0, Pointer, RefIndices, Indent2, Stream),
	move_base_ptrs(L, Pointer, save, Indent2,_, BasePtrs,_, Stream),
	excrete(L, assignment, NewInstance=1, Indent2, Stream),
	/* CheckEnd */
	do_writing(CheckEnd, Stream),
	excrete(L, end(cond), 'Instance exists', Indent, Stream),
	/* IfChecking */
	(number(Phase), !,
	    excrete(L, if_start, MemberCheckRef, Indent, Stream);
	 \+ number(Phase)),
	do_assign_list(L, MyLoop, Graphs, Collects, Used, Stream),
	do_writing(CheckEnd, Stream),
	/* That should make some good code */

	do_assign_list(L, Later, Graphs, Collects, Used, Stream).

do_assignment(L, [bound_gen_loop(Top, Name) | Clauses],
	      Graphs, Collects, Used, Stream) :-
        indent_is(Indent),
	
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	(make_struct_reference(L, Top, Name, SubPointer),
	    append_atoms(Name, cond, IdRef),
	    excrete(L, variable_declaration, [int, IdRef, []], Indent, Stream),
	    append_atoms(Name, 'type**', MType),
	    append_atoms(Name, meta, Meta),
	    excrete(L, variable_declaration, [MType, Meta, []], Indent, Stream),

	    excrete(L, make_reference, Meta=SubPointer, Indent, Stream),

	    do_assign_list(L, MyLoop, Graphs, Collects, Used, Stream),
	/* And here's the stuff that goes at the end of the loop... */
	    resolve_pointer(L, Meta, MPTarget),
	    refer_value(L, MPTarget, MPTargetRef),
	    excrete(L, procedure_call, delete_list(MPTargetRef),Indent, Stream),
	    excrete(L, assignment, MPTarget=0, Indent, Stream),
%	    fail;
	do_assign_list(L, Later, Graphs, Collects, Used, Stream)).

/* Nowadays we may want to stick the emptying of a list at any point in the
program. So it needs its own clause... */

do_assignment(L, [reset_list(Ptr, Name) | Clauses],
		Graphs, Collects, Used, Stream) :-
	indent_is(Indent),
	make_struct_reference(L, Ptr, Name, Ref),
	(L = c,
	    excrete(L, procedure_call, delete_list(Ref), Indent, Stream);
	L = tcl),
	excrete(L, assignment, Ref=0, Indent, Stream),
	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).

/* Clause to handle end of a submodel loop does not actually generate any code (this
is all done at start submodel time) but rearranges the preambles and postambles so
subsequent stuff is put outside the loop.


do_assignment(L, [finish_level | Clauses], Graphs, Collects,
	      [Exit | Postambles], Used, Stream) :-
	do_writing(Exit, Stream),
	do_assign_list(L, Clauses, Graphs, Collects, Postambles, Used, Stream).

Here's a really easy clause that enables program statements in the right language
to be stuck directly into the instruction queue. The reason for doing this is so that
when generating new instances, I can leave the conditional open while I add the
initialization of the instance, then slip in the close after it. All this would be
unnecessary if the thing were designed so it could call itself on parts of the
program. I blame Geraint....*/

do_assignment(L, [verbatim(CodeLine) | Clauses], Graphs, Collects,
	      Used, Stream) :-
	do_writing(CodeLine, Stream),
	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).
/* cannot use cos we only assign when condition is right
do_assignment(L, [cond_assign(Dest, Tested, Payload, Op, SoFar) | Clauses],
		Graphs, Collects, 
		Preambles, [Current | Postambles],
		Used, Temps, Results) :-
	length(Postambles, Nesting),
	Indent is Nesting*4,
	make_scalar(L, Dest, Graphs, ScalarDest),
	make_evaluation_routine(L, Tested, Graphs, TestedTerm),
	make_expr(L, TestedTerm, TestedExpr),
	make_evaluation_routine(L, Payload, Graphs, PayloadTerm),
	make_expr(L, PayloadTerm, PayloadExpr),
	make_scalar(L, SoFar, Graphs, ScalarSoFar),
	make_pointer(L, ScalarSoFar, SoFarPtr),
	append_atoms(return_if_, Op, Functor),
	make_procedure_call_chars(L, [Functor, TestedExpr, PayloadExpr,
				      SoFarPtr], CondAssignStr),
	name(CondAssign, CondAssignStr),
	render(L, assignment, ScalarDest=CondAssign, Indent, [CodeLine]), 
	append(Current, [CodeLine], NewCurrent),
	do_assign_list(L, Clauses, Graphs, Collects,
		       Preambles, [NewCurrent | Postambles],
			Used, Temps, Results).
*/
do_assignment(L, [SpecialOp | Clauses], Graphs, Collects, Used, Stream) :-
	indent_is(Indent),
	(SpecialOp =.. [collect, DestSpec, TgtRef | Args],
	    nth(CollectId, Used, TgtRef), !,
	    make_scalar(L, DestSpec, [], Dest),
	    refer(L, Dest, DestRef),
 	    make_evaluation_routine_all(L, Args, [], Inds),
 	    CallSpec =.. [collect, DestRef, CollectId | Inds];
	SpecialOp =.. [call_ext_code, ProcName, CurSmPtr, ArgCodes],
	    all(render, msr_with_ptrs,
		[unify(L), unify(CurSmPtr), build(ArgCodes), build(XArgs)]),
	    CallSpec =.. [ProcName | XArgs];
	SpecialOp =.. [SubCall, NodeId, InstHandle, NewCond],
	    member(SubCall,
		   [update_submodel, advance_submodel,
		    int_eval_submodel, ext_eval_submodel]),
	    make_section_cond(L, NewCond, PassTest),
	    render:make_constant_string(L, NodeId, Node),
	    make_scalar(L, InstHandle, [], InstPtr),
	    refer_value(L, InstPtr, InstHandleRef),
	    CallSpec =.. [SubCall, Node, InstHandleRef, PassTest];
/*	SpecialOp = search_from(ArcInd, _, TopRef),
	    CallSpec = search_from(myClassPtr, ArcInd, TopRef);
*/	SpecialOp = cond_assign(Dest, Tested, Payload, Op, SoFar),
	    make_scalar(L, Dest, Graphs, ScalarDest),
	    make_pointer(L, ScalarDest, DestPtr),
	    make_evaluation_routine(L, Tested, Graphs, TestedTerm),
	    make_expr(L, TestedTerm, TestedExpr),
	    make_evaluation_routine(L, Payload, Graphs, PayloadTerm),
	    make_expr(L, PayloadTerm, PayloadExpr),
	    make_scalar(L, SoFar, Graphs, ScalarSoFar),
	    make_pointer(L, ScalarSoFar, SoFarPtr),
	    append_atoms(assign_if_, Op, Functor),
	    CallSpec =.. [Functor, TestedExpr, PayloadExpr, SoFarPtr, DestPtr]),
	excrete(L, procedure_call, CallSpec, Indent, Stream),
	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).
% have to render after instantiating CollectId

/* This one starts a conditional execution sequence dependent on the
given submodel */

do_assignment(L, [check_phase(Phase, VMPtrs) | Clauses], Graphs, Collects,
	      Used, Stream) :-
	retract(indent_is(Indent)),
	InnerIndent is Indent+4,
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	(make_section_cond(L, VMPtrs, PassTest),
	    combine(L, >=, [Phase, PassTest], PhaseTest),
	    excrete(L, if_start, PhaseTest, Indent, Stream),
	    asserta(indent_is(InnerIndent)),
	    do_assign_list(L, MyLoop, Graphs, Collects, Used, Stream),
	    retract(indent_is(_)),
	    asserta(indent_is(Indent)),
	    excrete(L, end(cond), PhaseTest, Indent, Stream),
	    fail;
	do_assign_list(L, Later, Graphs, Collects, Used, Stream)).

/* Initial membership of populations was handled by the new_member
clause up until Simile 4.5, but now it is done like initializing a VM
model, so individuals can persist across a reset. This means their
associations can too, and makes resetting faster. */


do_assignment(L, [init_mems(ParentPtr, Name, create(InitVars)) | Clauses],
	      Graphs, Collects, Used, Stream) :-
	indent_is(Indent),
	append_atoms(Name, count, Count),
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	make_struct_reference(L, ParentPtr, Name, StartPtr), 
	make_struct_reference(L, ParentPtr, Count, Index), 

	append_atoms(Type, '*', MType),
	excrete(L, variable_declaration, [Type, Pointer, []], Indent, Stream),
	excrete(L, variable_declaration, [MType, MetaPointer, []], Indent,
		Stream),
	excrete(L, assignment, Index=0, Indent, Stream),
	excrete(L, make_reference, MetaPointer=StartPtr, Indent, Stream),
	       
	make_pointer(L, MetaPointer, MMPtr),
	all(language, make_create_proc,
	    [unify([L, ParentPtr, MMPtr, Index, Name, Indent, Used]),
	     build(InitVars), unify(Stream)]),
	
	excrete(L, procedure_call, delete_list(MPTargetRef), Indent, Stream),
	excrete(L, assignment, MPTarget=0, Indent, Stream),

	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).

/* This one should be easy too. When I extract the procedures for initializing
submodel instances where these can't always be done at init time, I leave an
'init_population' node. For population submodels, which do also need to be
initialized when their parents are, this causes the tests to be done and the
inits to be included. */

do_assignment(L, [new_member(ParentPtr, Name, NewSpec) | Clauses],
	      Graphs, Collects, Used, Stream) :-
	indent_is(Indent),
	Indent1 is Indent + 4,

	append_atoms(Name, count, Count),
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
	excrete(L, while_start, CompValRef>=1, Indent, Stream),
	make_expr(L, CompValRef-1, NewCompVal),
	excrete(L, assignment, CompVal=NewCompVal, Indent1, Stream),
	excrete(L, increment_by, [Index, 1], Indent1, Stream),
	excrete(L, assign_space, Pointer=[ParentPtr, Name, [UseElementRef]],
	       Indent1, Stream),
	nth(ChannelN, Used, InitVar), !,
	excrete(L, procedure_call, init_pop_member(Pointer, RefIndex, 0,
						  ChannelN), Indent1, Stream),
	/* no parent we are doing creation/immigration here */

	/* End of submodel loop; insert into list and do next */
	refer_value(L, Pointer, PointerRef),
	excrete(L, assignment, MPTarget=PointerRef, Indent1, Stream),
	make_struct_reference(L, Pointer, next, OnPointer),
	excrete(L, make_reference, MetaPointer=OnPointer, Indent1, Stream),
	excrete(L, end(while), 'New instances', Indent, Stream),

	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).

/* This is similar to the last one, but handles reproduction. Owing to the
limitations of Tcl it switches context between current instance and new instances.
This could be avoided by peeking at the reproduction compartment then decrementing
it in a local variable, but this way is conceptually simpler, which is everything.
*/

do_assignment(L, [reproduce(ParentPtr, Name, ReproName) | Clauses],
	      Graphs, Collects, Used, Stream) :-
	indent_is(Indent),
	Indent1 is Indent + 4,
	Indent2 is Indent1 + 4,

	/* Now stick in a loop */
	make_struct_reference(L, ParentPtr, Name, SubmodelStartPtr),
	refer_value(L, SubmodelStartPtr, SubmodelStartPtrRef),
	append_atoms(Name, count, Count),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	make_struct_reference(L, ParentPtr, Count, Index), 
	refer_value(L, Index, RefIndex),

	/* Set pointer to first model in list, and dive into loop */
	excrete(L, assignment, Pointer=SubmodelStartPtrRef, Indent, Stream),
	refer_value(L, Pointer, PointerRef),
	ptr_compare(L, PointerRef, 0, NotDone),
	excrete(L, while_start, NotDone, Indent, Stream),

	/* Conditional to avoid reproduction with new individuals  -- they have
	not been initialized yet */
	make_new_check(L, Pointer, ParentNewRef),
	combine(L, !, [ParentNewRef], ParentOld),
	excrete(L, if_start, ParentOld, Indent1, Stream),
	
	make_struct_reference(L, Pointer, ReproName, Repro),
	refer_value(L, Repro, ReproRef),
	make_struct_reference(L, Pointer, instanceid, ParentArray),
	(L = c,
	    make_indexed_reference(L, ParentArray, [0], ParentId);
	 L = tcl,
	    ParentId = ParentArray),
	refer_value(L, ParentId, ParentRef),
	excrete(L, while_start, ReproRef>=1, Indent1, Stream),
	make_expr(L, ReproRef-1, NewRepro),
	/* cannot use decrement because quantity is floating point */
	excrete(L, assignment, Repro=NewRepro, Indent2, Stream),

	/* Now make context for new individual */
	excrete(L, increment_by, [Index, 1], Indent2, Stream),
	excrete(L, assign_space, 
			MPTarget=[ParentPtr, Name, [RefIndex]],
			Indent2, Stream),
	nth(ChannelN, Used, ReproName), !,
	excrete(L, procedure_call, init_pop_member(MPTarget,RefIndex, ParentRef,
						  ChannelN), Indent1, Stream),

	/* End of submodel loop; insert into list and do next */
	make_struct_reference(L, MPTarget, next, OnMeta),
	excrete(L, make_reference, MetaPointer=OnMeta, Indent2, Stream),
	excrete(L, end(while), Repro, Indent1, Stream),
	excrete(L, end(cond), ParentOld, Indent1, Stream),
	make_struct_reference(L, Pointer, next, OnPointer),
	refer_value(L, OnPointer, OnPointerRef),
	excrete(L, assignment, Pointer=OnPointerRef, Indent1, Stream),
	excrete(L, end(while), PointerRef, Indent, Stream),

	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).

/* OK, now for mortality. This will have to be called before immigration or reproduction because any new individuals might not yet have values for their loss nodes. It used to be done as part of the reproduction loop but had to be separated now there can be many reproduction channels. However, all loss channels are equivalent, so there only needs to
be one of these loops; the instruction has a list of the appropriate nodes. */

do_assignment(L, [lose(Step, ParentPtr, Name, LossNodes) | Clauses],
	      Graphs, Collects, Used, Stream) :-
	indent_is(Indent),
	Indent1 is Indent + 4,
	Indent2 is Indent1 + 4,

	/* Now stick in a loop */
	make_struct_reference(L, ParentPtr, Name, SubmodelStartPtr), 

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointer),
	excrete(L, variable_declaration, [Type, Pointer, []], Indent, Stream),
	append_atoms(Type, '*', MType),
	excrete(L, variable_declaration, [MType, MetaPointer, []], Indent,
		Stream),
	/* Set pointer to first model in list, and dive into loop */
	excrete(L, make_reference, MetaPointer=SubmodelStartPtr, Indent,Stream),
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	ptr_compare(L, MPTargetRef, 0, NotDone),
	excrete(L, while_start, NotDone, Indent, Stream),
	excrete(L, open_context, Pointer=[ParentPtr, Name, MPTargetRef],
			Indent1, Stream),

	/* Conditional to avoid offing new individuals  -- they have
	not been initialized yet */
	make_struct_reference(L, Pointer, new_instance, NewInstance),
	
	/* Next remove shagged-out individuals, node is a variable, and move
		on to next instance */
	/* Now dig out the variable names for the loss nodes...add
		probability preprocessing here too */

	make_struct_reference(L, Pointer, 'next', OnPointer),
	excrete(L, assignment, NewInstance=0, Indent1, Stream),
	(setof(LossTerm, LossVal^(get_term_refs(L, Pointer, LossNodes, LossVal),
			test_probs(L, LossVal, Step, LossTerm)), LossTerms), !,
	    build_disjunction(L, LossTerms, IsDead),

	    excrete(L, if_start, IsDead, Indent1, Stream),
	    refer_value(L, OnPointer, OnPointerRef),
	    excrete(L, assignment, MPTarget=OnPointerRef, Indent2, Stream),
	    excrete(L, release_memory, Pointer, Indent2, Stream),
	    excrete(L, else_clause, IsDead, Indent1, Stream),
	    excrete(L, make_reference, MetaPointer=OnPointer, Indent2, Stream),
	    excrete(L, end(cond), IsDead, Indent1, Stream);
	excrete(L, make_reference, MetaPointer=OnPointer, Indent2, Stream)),    
	excrete(L, end(while), MPTargetRef, Indent, Stream),
	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).

/* This is a fairly horrrible clause that puts in what is done when a new submodel
instance is generated; if the instance fails to exist, it terminates building it,
so the end of the last if clause is left on the postambles. Should be less
horrible now it no longer includes the evaluation of the test! */

do_assignment(L, [test(Name, Pointer, Source) | Clauses],
		Graphs, Collects, Used, Stream) :-
	
/* Some variable membership models will contain 'dummy' generator clauses to
make sure they get set up and kept in correspondence with their uncles before
any of their values are calculated. The source is 1 on these; in this case
we only make the three lines that insert the submodel instance into its linked list. 
*/
        indent_is(Indent),
	(\+ Source == 1, !,
	    (setof(GenVal, get_term_refs(L, Pointer, Source, GenVal), GenVals),
		build_disjunction(L, GenVals, TestVal), !;
	    TestVal = 0),
	    excrete(L, if_start, TestVal, Indent, Stream),
	    Indent1 is Indent+4,
	    retract(indent_is(_Indent)),
	    asserta(indent_is(Indent1));
	/* clause for dummy generator */
	Indent1 = Indent),

	make_struct_reference(L, Pointer, next, OnPointer),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	refer_value(L, Pointer, PointerRef),
	excrete(L, assignment, OnPointer=MPTargetRef, Indent1, Stream),
	excrete(L, assignment, MPTarget=PointerRef, Indent1, Stream),
	excrete(L, make_reference, MetaPointer=OnPointer, Indent1, Stream),
	
	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream),

	/* Any further assignments in model generation also go inside this 'if'
	clause, so as not to do them is the submodel instance does not exist. Thus
	the 'else' clause and other condition go in the postamble. */
	(Source == 1, !;
	    retract(indent_is(_Indent1)),
	    asserta(indent_is(Indent)),
	    excrete(L, else_clause, TestVal, Indent, Stream),
	    excrete(L, release_memory, Pointer, Indent1, Stream),
	    excrete(L, end(cond), TestVal, Indent, Stream)).

/* Right, this is the one with the meat in it; the actual integration of new code
that evaluates an expression in the model */

do_assignment(L, [assign(arr(P, Val, Is), Source) | Clauses], Graphs, Collects,
		Used, Stream) :-

	indent_is(Indent),
	make_scalar(L, arr(P, Val, Is), Graphs, ScalarDest),
	make_evaluation_routine(L, Source, Graphs, Term),
	make_expr(L, Term, Expr),
	excrete(L, assignment, ScalarDest=Expr, Indent, Stream),

	do_assign_list(L, Clauses, Graphs, Collects, Used, Stream).

starts_a_level(Inst) :-
	member(Inst, [open_index(_,_), start_submodel(_,_,_,_),
		      generate(_,_,_,_,_,_,_), bound_gen_loop(_,_),
		      check_phase(_,_)]).

get_rest_of_my_loop(More, MyLoop, Later) :-
	copy_to_exit(More, 0, Later),
	append(MyLoop, [finish_level | Later], More).

copy_to_exit([finish_level | Tail], 0, Tail) :- !.
copy_to_exit([Inst | Togo], N, Tail) :-
	(starts_a_level(Inst), !,
	    M is N+1;
	 Inst = finish_level, !,
	    M is N-1;
	 M=N),
	copy_to_exit(Togo, M, Tail).

move_base_ptrs(_,_,_,_, [],[],[],_).
move_base_ptrs(L, Pointer, Action, Indent,
	       [Name | Names], [Ptr | Ptrs], [Type | Types], Stream) :-
	length(Ptrs, Count),
	make_struct_reference(L, Pointer, baseptrs, SafeArray),
	make_indexed_reference(L, SafeArray, [Count], Target),
	(Action = save,
	    refer_value(L, Ptr, PtrRef),
	    excrete(L, assignment, Target=PtrRef, Indent, Stream);
	Action = restore,
	    /* Now because of the ANSI c++ standard we have
	    to cast the base model pointer explicitly to the
	    right type -- the array in which the assoc model
	    stores them is type (void *) */
	    (L = c,
		append_atoms(Name, 'type*', Type),
	        sicstus_format_to_chars("(~a)~a", [Type, Target], CastTgtStr),
		name(CastTgt, CastTgtStr);
	    L = tcl,
	        refer_value(L, Target, CastTgt)),
	    excrete(L, assignment, Ptr=CastTgt, Indent, Stream)),
	move_base_ptrs(L, Pointer, Action, Indent, Names, Ptrs, Types, Stream).

make_section_cond(L, VMPtrs, PassTest) :-
	refer_value(L, phase, PhaseRef),
	(VMPtrs = [], !,
	    PassTest = PhaseRef;
	all(language, make_new_base_cond,
	    [unify(L), build(VMPtrs), build(LocaleTests)]),
	    build_disjunction(L, LocaleTests, NewTest),
	    combine(L, ?, [NewTest, -2:PhaseRef], PassTest)).
	    
	
make_new_base_cond(L, new_context(Ptr, Phase), LocCond) :-
	refer_value(L, phase, PhaseRef),
	combine(L, >=, [Phase, PhaseRef], PhaseTest),
	make_new_check(L, Ptr, FlagTest),
	combine(L, '&&', [PhaseTest, FlagTest], LocCond).


declare(L, Name, NameBase, Type, Used, Indent, Stream) :-
	(var(Name),
	    generate_name(L, NameBase, Name, Used);
	 \+ utility:something_used_in([Name], Used),
	    member(Name, Used)), !,
	    excrete(L, variable_declaration, [Type, Name, []], Indent, Stream);
	true.
	
declare_ptrs(Name, Type, BasePtr, [L, Indent, Used, Stream]) :-
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, 'pointer', PtrForm),
	declare(L, BasePtr, PtrForm, Type, Used, Indent, Stream).

get_term_refs(_,_, Test, Test) :-
	atom(Test), \+ Test=[].

get_term_refs(L, Pointer, LossNodes, DeadRef) :-
	member(LossVal, LossNodes),
	make_struct_reference(L, Pointer, LossVal, IsDead),
	refer_value(L, IsDead, DeadRef).

make_create_proc([L, ParentPtr, MMPtr, Index, Name, Indent, Used],
	    InitVar, Stream) :-
	make_struct_reference(L, ParentPtr, InitVar, CompVal),
	refer_value(L, CompVal, CompValRef),
	refer_value(L, Index, RefIndex),
	nth(ChannelN, Used, InitVar), !,
	BaseArgs = [init_pop, MMPtr, CompValRef, RefIndex, ChannelN],
	/* no function templates in tcl so pass class id explicitly */
	(L = tcl, !,
	    append_atoms(Name, maker, ProcName),
	    make_struct_reference(tcl, ParentPtr, ProcName, CurrentName),
	    append(BaseArgs, [CurrentName], AllArgs);
	AllArgs = BaseArgs),
	make_procedure_call_chars(L, AllArgs, CallInitStr),
	name(CallInit, CallInitStr),
	excrete(L, assignment, Index=CallInit, Indent, Stream).

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
	Graphs, /* Data set for any graph found evaluating this expression */
	/* Results, i.e., arguments defined here */
	Term /* the expression that evaluates to the destination
		in current state; -ve = in preambles, +ve = in postambles, 
		0 = inside deepest loop */
	) :-
	(make_scalar(Language, Expr, Graphs, LocalExpr), !,
	    refer_value(Language, LocalExpr, Term);
	Expr = ind(Ptr, Count), !,
	    make_struct_reference(Language, Ptr, instanceid, IndSet),
	    get_element_ref(Language, IndSet, Count, Term);
	number(Expr), !,
	    Term=Expr; /* I think not...
	    this goes num -> chars -> atom -> chars -> atom
	    print_to_codes(TermStr, Expr),
	    sicstus_atom_chars(Term, TermStr); */
	member(Expr, [time(P), ind_time(P)]), !,
	    make_procedure_call_chars(Language, [glob_element, ts, P],
				      TimeElmtStr),
	    name(Term, TimeElmtStr);

	Expr = dt(P), !, /* still used for explicit references to dt */
	    make_procedure_call_chars(Language, [glob_element, dts, P],
				      TimeElmtStr),
	    name(Term, TimeElmtStr);

	Expr = assign(Tgt, SubExpr), !,
	    make_scalar(Language, Tgt, Graphs, Dest),
	    make_evaluation_routine(Language, SubExpr, Graphs, Source),
	    make_expr(Language, Source, SourceExp),
	    make_assignment(Language, Dest, SourceExp, AssignStr),
	    command_substitute(Language, AssignStr, TermStr),
	    name(Term, TermStr);
	Expr = simile_int(SubExpr), !,
	    (Language = c, Functor = '(int)';
	     Language = tcl, Functor = int),
	    IntExpr =.. [Functor, SubExpr],
	    make_evaluation_routine(Language, IntExpr, Graphs, Term);
	Expr = graph(NodeId, XAxis), !,
	    make_evaluation_routine(Language, XAxis, [], GraphTerm),
	    make_expr(Language, GraphTerm, GraphExpr),
	    /* Keep tcl working till it uses c++ graph access */
	    nth(GraphN, Graphs, [NodeId | _]),
	    make_procedure_call_chars(Language,
				      [graphpoint, GraphExpr, GraphN],
				      Content_chars),
/* End of graph clause */
	    name(Term, Content_chars);
	Expr = stop(Ident), !, 
	    make_evaluation_routine(Language, Ident,
					Graphs, XIdent),
	    make_expr(Language, XIdent, VIdent),
	    make_procedure_call_chars(Language, [stop, VIdent], Content_chars),
	    name(Term, Content_chars);
	Expr = stage_incr(Struct, Step, Delta), !, 
	    make_scalar(Language, Struct, Graphs, SStruct),
	    make_pointer(Language, SStruct, VStruct),
	    make_evaluation_routine_all(Language, [Step, Delta],
					Graphs, [VStep, XDelta]),
	    make_expr(Language, XDelta, VDelta),
	    make_procedure_call_chars(Language, [stage_incr, VStruct, VStep,
						 VDelta], Content_chars),
	    name(Term, Content_chars);
	Expr =.. [Op | Args],
	    make_evaluation_routine_all(Language, Args, Graphs, VArgs),
	    combine(Language, Op, VArgs, Term)).

/* make_evaluation_routine_all/many: Same as above, but takes a list of terms rather
than just one, does not take a destination, and returns a list of expressions
which are rendered usable by the stuff in the preamble. Eventually this will have
to be upgraded to behave properly when the arguments have incompatible source
contexts. */

make_evaluation_routine_all(_, [], _, []).

/* For the following we just unify GraphD because no node can have
more than one graph associated with it */

make_evaluation_routine_all(Language, [Expr | Args],
		Graphs, [VArg | VArgs]) :-
	make_evaluation_routine(Language, Expr, Graphs, VArg),
	make_evaluation_routine_all(Language, Args, Graphs, VArgs).

make_scalar(L, Param, Graphs, FullLocalExpr) :-
	(Param = arr(Ptr, Var, Inds),
	    make_struct_reference(L, Ptr, Var, LocalExpr);
	Param = glob(LocalExpr, Inds),
	    Var = ''), !,
	make_evaluation_routine_all(L, Inds, Graphs, ITerms),
	all(language, aim_at_array, [unify(L), build(ITerms), build(ATerms)]),
	all(render, make_expr, [unify(L), build(ATerms),
				build(IExprs)]),
	( /* Var = import(Type, _, Level, _, TopPtr, _,_, ArcIndex),
	    (Type = a(_ET),
		ImportCmd = import_int;
	    append_atoms('import_', Type, ImportCmd)), !,
	    length(IExprs, IndCount),
	    make_procedure_call_chars(L, [arrange_indices, IndCount | IExprs],
				      AIStr),
	    name(ArrInds, AIStr),
	    make_procedure_call_chars(L, [ImportCmd, Level, TopPtr,
					  ArcIndex, ArrInds], LXStr),
	    name(FullLocalExpr, LXStr); */
	make_indexed_reference(L, LocalExpr, IExprs, FullLocalExpr)).

aim_at_array(c, Index, Index-1) :- !.
aim_at_array(_, Index, Index).
