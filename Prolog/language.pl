/*******************************************************************************
**** LANGUAGE module. This module contains all the templates necessary      ****
**** to compile AME code. Everything is parameterised by language, BASIC    ****
**** being the starting point.                                              ****
*******************************************************************************/

sicstus_module( language, [do_assign_list/5, template_type/3] ).

sicstus_use_module( [sp_only, render,m_class,utility,
		ame_gen,units,text,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
make_new_check(L, Pointer, NewTest) :-
	make_struct_reference(L, Pointer, new_instance, _, NewTest).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fill_instance_ids(c, _N, _Pointer, [], _Indent, _).

fill_instance_ids(c, N, Pointer, [RefIndex | RefIndices], Indent, Stream) :-
	make_indexed_reference(c, instanceid, [N], IArray),
	make_struct_reference(c, Pointer, IArray, ISlot, _),
	excrete(c, assignment, ISlot=RefIndex, Indent, Stream),
	NPlus is N+1,
	fill_instance_ids(c, NPlus, Pointer, RefIndices, Indent, Stream).

fill_instance_ids(tcl, _, Pointer, RefIndices, Indent, Stream) :-
	make_struct_reference(tcl, Pointer, instanceid, Target, _),
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

do_assign_list(L, [Clause | Clauses], Indent, Used, Stream) :-
	/* write_to_chars(Clause, ClauseMess),
	dialogue><reassure_user(ClauseMess), test only */
	do_assignment(L, [Clause | Clauses], Indent, Used, Stream), !;
	raise_exception(cannot_convert_to_code(Clause)).

do_assign_list(_, [], _, _, _).

/* This makes a loop for a fixed membership submodel.
Should really be done with make_array_assignment. */

do_assignment(L, [open_index(glob(Loop, Inds), Bound) | Clauses],
                Indent, Used, Stream) :-
        deepen_indent(Indent, NewIndent),
	declare(L, Loop, loop, int, Used, Indent, Stream),
% fatal question -- what does this do
%	declare(L, _Feature, bound, int, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
        (make_indexed_reference(L, Loop, Inds, Count),
	    (Bound = pra_bound(Ptr, Name) ->
	        append_atoms(Name, made, MadeBound),
	        make_struct_reference(L, Ptr, MadeBound, _, UseBoundRef);
	     UseBoundRef = Bound),
	    set_introspect(L, Used, IndexSlot, CountSlot),
	    make_pointer(L, Count, CountPtr),
	    excrete(L, assignment, IndexSlot = CountPtr, Indent, Stream),
	    excrete(L, assignment, CountSlot = -1, Indent, Stream),
	    excrete(L, for_start, [Count, 1, UseBoundRef, 1], Indent, Stream),
	    do_assign_list(L, MyLoop, NewIndent, Used, Stream),
	    excrete(L, end(for), Count, Indent, Stream),
	    excrete(L, assignment, IndexSlot=0, Indent, Stream),
	    fail;
	do_assign_list(L, Later, Indent, Used, Stream)).

/* Start submodel. Note that we may have selected an index
explicitly (using element(...)), so it can contain any expression, even a
graph. */

do_assignment(L, [start_submodel(Name, Top, Pointer, LoopSpec) | Clauses],
	      Indent, Used, Stream) :-
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, PointerForm),
	declare(L, Pointer, PointerForm, Type, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),

	((LoopSpec = fm_loop(IndExprs,_, Alarm, _),
	all(language, make_evaluation_routine,
	    [unify(L), build(IndExprs), unify(Used), build(RefIndices)]),
	all(render, make_expr,
	    [unify(L), build(RefIndices), build(RefExprs)]),
	excrete(L, enter_context, Pointer=[Top, Name, RefExprs], 
		Indent, Stream),
	(nonvar(Alarm),
	  Alarm = al_action(DoneCond, TryCond),
	  member(assign(arr(Pointer, DoneCond, _), _), MyLoop) ->
	    % only add alarm loop if assigning condition in this pass
	    make_struct_reference(L, Pointer, DoneCond, AlarmVar, AlarmRef),
	    excrete(L, assignment, AlarmVar=1, Indent, Stream),
	    make_evaluation_routine(L, TryCond, Used, TryRef),
	    excrete(L, while_start, TryRef, Indent, Stream),
	    deepen_indent(Indent, Indent1),
	    excrete(L, procedure_call, abort_check, Indent1, Stream),
	    do_assign_list(L, MyLoop, Indent1, Used, Stream),
	    excrete(L, if_start, AlarmRef, Indent1, Stream),
	    deepen_indent(Indent1, Indent2),
	    excrete(L, break, _, Indent2, Stream),
	    excrete(L, end(cond), AlarmRef, Indent1, Stream),
	    excrete(L, end(while), alarm, Indent, Stream);
	% if no alarm loop this does not start new context
	    do_assign_list(L, MyLoop, Indent, Used, Stream),
	    KeepContext = yes);
	LoopSpec = vm_loop(Dims, _, BaseLoops, _),
        (Dims == pop ->
	    append_atoms(Name, progen, ParentPtr),
	    BasePtrs = [ParentPtr],
	    Names = [Name],
	    IndCount = 1;
	  (get_ground_part(BaseLoops, GndBaseLoops) -> true;
	   GndBaseLoops = BaseLoops),
				% quick and dirty fix, should be gnd anyway
	    all(compile, get_base_ptrs, [build(GndBaseLoops), append(Names, []),
					 append(BasePtrs, [])]),
	    count_loops(LoopSpec, IndList),
	    length(IndList, IndCount)),
	  refer_value(L, Pointer, PointerRef),
%	all(language, declare,
%	    [unify(L), build(BasePtrs), unify(bad), build(Types),
%	     unify(Used), unify(Indent), unify(Stream)]),
	  make_struct_reference(L, Top, Name, _, StartPtrRef),

	/* finish same: move pointer to next instance in chain */
	  make_struct_reference(L, Pointer, next, _OnPointer, OnPointerRef),
	  excrete(L, assignment, Pointer=StartPtrRef, Indent, Stream),
	  (Dims == start_only -> % will use locate to go through list
	   do_assign_list(L, MyLoop, Indent, Used, Stream),
	   KeepContext = yes;
	   ptr_compare(L, PointerRef, 0, PtrNonNull),
	   set_introspect(L, Used, IndexSlot, CountSlot),
	   make_pointer(L, Pointer, PointerPtr),
	   excrete(L, assignment, IndexSlot=PointerPtr, Indent, Stream),
	   excrete(L, assignment, CountSlot=IndCount, Indent, Stream),
	   excrete(L, while_start, PtrNonNull, Indent, Stream),
	   deepen_indent(Indent, Indent1),
	   excrete(L, procedure_call, abort_check, Indent1, Stream),
	   all(language, declare_ptrs,
	       [build(Names), build(Types), build(BasePtrs),
		unify([L, Indent1, Stream])]),
	   move_base_ptrs(L, Pointer, restore, Indent1,
			  BasePtrs, Types, Stream),
	   do_assign_list(L, MyLoop, Indent1, Used, Stream),
	   excrete(L, assignment, Pointer=OnPointerRef, Indent1, Stream),
	   excrete(L, end(while), Pointer, Indent, Stream),
	   excrete(L, assignment, IndexSlot=0, Indent, Stream));
	LoopSpec = nbrs,
	  template_type(nbrlist, Name, NbrsType),
	  declare(L, NbrsPointer, nbrpointer, NbrsType, Used, Indent, Stream),
	  refer_value(L, NbrsPointer, NbrsPointerRef),
	  make_struct_reference(L, NbrsPointer, next, _OnPointer, OnPointerRef),
	  make_struct_reference(L, Top, nbrs, _, NbrsStartRef),
	  excrete(L, assignment, NbrsPointer=NbrsStartRef, Indent, Stream),
	  ptr_compare(L, NbrsPointerRef, 0, PtrNonNull),
	  excrete(L, while_start, PtrNonNull, Indent, Stream),
	  deepen_indent(Indent, Indent1),
	  make_struct_reference(L, NbrsPointer, payload, _ForUse, ForUseRef),
	  excrete(L, assignment, Pointer=ForUseRef, Indent1, Stream),
	  do_assign_list(L, MyLoop, Indent1, Used, Stream),
	  excrete(L, assignment, NbrsPointer=OnPointerRef, Indent1, Stream),
	  excrete(L, end(while), NbrsPointer, Indent, Stream);
	LoopSpec = progen,
	  append_atoms(Name, progen, HackedName),
	  ptr_compare(L, HackedName, 0, PtrNonNull),
	  excrete(L, if_start, PtrNonNull, Indent, Stream),
	  deepen_indent(Indent, Indent1),
	  excrete(L, assignment, Pointer=HackedName, Indent1, Stream),
	  do_assign_list(L, MyLoop, Indent1, Used, Stream),
	  excrete(L, end(if), HackedName, Indent, Stream);
	LoopSpec = vm_retrieve(List, Count, VmIndices),
	  all(language, make_evaluation_routine,
	      [unify(L), build(VmIndices), unify(Used), build(VmUseIndices)]),
	  make_pointer(L, Pointer, PointerPtr),
	  (List = nbrs -> % fall back on old system
	      make_struct_reference(L, Top, List, _, StartPtrRef),
	      VmUseIndices = [VmUseIndex],
	      make_procedure_call_chars(L, [locate_nbr, StartPtrRef, PointerPtr,
					    VmUseIndex], LocateCallStr),
	      name(ToTest, LocateCallStr);
	   make_struct_reference(L, Top, Name, _, StartPtrRef),
	      make_procedure_call_chars(L, [locate, StartPtrRef,
					 Count | VmUseIndices], LocateCallStr),
	      name(LocateCall, LocateCallStr),
	      excrete(L, assignment, Pointer=LocateCall, Indent, Stream),
	      refer_value(L, Pointer, PointerRef),
	      ptr_compare(L, PointerRef, 0, ToTest)),
	  excrete(L, if_start, ToTest, Indent, Stream),
	  deepen_indent(Indent, Indent1),
	  do_assign_list(L, MyLoop, Indent1, Used, Stream),
	  excrete(L, end(cond), ToTest, Indent, Stream)),
	ground(KeepContext); true),
	do_assign_list(L, Later, Indent, Used, Stream).


	/* Start a submodel loop with a generate/test pair inside. This happens once per time step for variable membership models apart from populations. Each possible instance of the model is either generated or pulled out of the list, for testing later. If the phase is 'new' then previously existing instances are skipped over. */

do_assignment(L, [generate(Name, Top, Pointer, Phase, VMPtrs, LocalIndices,
			   BasePtrs) | Clauses],
	      Indent, Used, Stream) :-

        deepen_indent(Indent, Indent1),

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, PointerForm),
	declare(L, Pointer, PointerForm, Type, Used, Indent, Stream),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	all(language, make_evaluation_routine,
	    [unify(L), build(LocalIndices), unify(Used), build(RefIndices)]),
	make_struct_reference(L, Pointer, next, OnPointer, _),

	append_atoms(Name, meta, Meta),
	resolve_pointer(L, Meta, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),

	make_struct_reference(L, Pointer, new_instance, NewInstance, _),

	excrete(L, procedure_call, abort_check, Indent, Stream),
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
	    combine(L, >=, [Phase, MemberCheckTest], MemberCheckCompare),
	    make_expr(L, MemberCheckCompare, MemberCheckExpr),
	    excrete(L, assignment, MemberCheck=MemberCheckExpr, Indent,
		    Stream);
	 \+ number(Phase)),
	excrete(L, if_start, CallPrune, Indent, Stream),
	excrete(L, open_context, Pointer=[Top, Name, MPTargetRef],
		Indent1, Stream),
	excrete(L, assignment, NewInstance=0, Indent1, Stream),
	/* IfChecking */
	(number(Phase), !,
	    refer_value(L, MemberCheck, MemberCheckRef),
	    excrete(L, if_start, MemberCheckRef, Indent1, Stream),
	    deepen_indent(Indent1, Indent2);
	 \+ number(Phase),
	    Indent2 = Indent1),
        % cut instance out of linked list
	% refer_value(L, OnPointer, OnPointerRef),
	% excrete(L, assignment, MPTarget=OnPointerRef, Indent2, Stream),
	/* CheckElse, StepOver, CheckEnd */
	(number(Phase),
	    excrete(L, else_clause, MemberCheckRef, Indent1, Stream),
	    excrete(L, make_reference, Meta = OnPointer, Indent2, Stream),
	    render(L, end(cond), MemberCheckRef, Indent1, CheckEnd),
	    do_writing(CheckEnd, Stream);
	 \+ number(Phase)),
	excrete(L, else_clause, 'Instance exists', Indent, Stream),
	/* IfChecking */
	(number(Phase),
	    excrete(L, if_start, MemberCheckRef, Indent1, Stream);
	 \+ number(Phase)),
	excrete(L, assign_space, Pointer=[Top, Name, RefIndices, _, []],
		Indent2, Stream),
	/* record instance id -- this is list of all count
	values local and remote, with a 0 at the end so the extractor
	knows where to stop */
	fill_instance_ids(L, 0, Pointer, RefIndices, Indent2, Stream),
	move_base_ptrs(L, Pointer, save, Indent2, BasePtrs,_, Stream),
	excrete(L, assignment, NewInstance=1, Indent2, Stream),
	(number(Phase) ->
	     /* CheckEnd */
	     do_writing(CheckEnd, Stream),
	     excrete(L, end(cond), 'Instance exists', Indent, Stream),
	     /* IfChecking */
	     (excrete(L, if_start, MemberCheckRef, Indent, Stream),
	        do_assign_list(L, MyLoop, Indent1, Used, Stream),
	        do_writing(CheckEnd, Stream),
	        fail;
	     do_assign_list(L, Later, Indent, Used, Stream));
	   excrete(L, end(cond), 'Instance exists', Indent, Stream),
	     do_assign_list(L, MyLoop, Indent, Used, Stream),
	     do_assign_list(L, Later, Indent, Used, Stream)).
	/* That should make some good code */


do_assignment(L, [bound_gen_loop(Top, Name, Ready, CondCount) | Clauses],
	      Indent, Used, Stream) :-
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	(make_struct_reference(L, Top, Name, SubPointer, _),
% what is this for? Matches dummy index for base-instance-lookup
	    append_atoms(Name, cond, IdRef),
	    excrete(L, variable_declaration, [int, IdRef, [CondCount]],
		    Indent, Stream),

	    append_atoms(Name, 'type*', Type),
	    append_atoms(Name, 'type**', MType),
	    append_atoms(Name, meta, Meta),
	    excrete(L, variable_declaration, [MType, Meta, []], Indent, Stream),

	    excrete(L, make_reference, Meta=SubPointer, Indent, Stream),
% Now some stuff for ready-made associations
	    (member(Ready, [rect_grid(Out, In), hex_grid(Out, In)]) ->
	        excrete(L, variable_declaration,
			[int, trailPt, []], Indent, Stream),
	        MyLoop = [open_index(IndO, Out), open_index(IndI, In) | Core],
				% get outer dimension
	        append(Body, [LastClose], Core),
	        TrailSize is In+2,
	        list_of('NULL', TrailSize, TrailInit), % pesky Tcl
	        excrete(L, variable_declaration,
			[Type, trail, [TrailSize], TrailInit], Indent, Stream),
	        refer_value(L, trailPt, TrailPtRef),
	        aim_at_array(L, NotIdx, (TrailPtRef+1)'%'TrailSize),
	        append([[open_index(IndO, Out), open_index(IndI, In),
			 assign(glob(trailPt, []), Out+IndI-IndO)], Body,
			[assign(glob(trail, [NotIdx]), 'NULL'), LastClose]],
		       MyLoopPlus);
	      MyLoopPlus = MyLoop),
	    do_assign_list(L, MyLoopPlus, Indent, Used, Stream),
	/* And here's the stuff that goes at the end of the loop... */
	    resolve_pointer(L, Meta, MPTarget),
	    refer_value(L, MPTarget, MPTargetRef),
	    excrete(L, procedure_call, delete_list(MPTargetRef),Indent, Stream),
	    excrete(L, assignment, MPTarget=0, Indent, Stream),
%	    fail;
	do_assign_list(L, Later, Indent, Used, Stream)).

/* Nowadays we may want to stick the emptying of a list at any point in the
program. So it needs its own clause... */

do_assignment(L, [reset_list(Ptr, Name) | Clauses],
	      Indent, Used, Stream) :-
	make_struct_reference(L, Ptr, Name, Ref, _),
	(L = c,
	    excrete(L, procedure_call, delete_list(Ref), Indent, Stream);
	L = tcl),
	excrete(L, assignment, Ref=0, Indent, Stream),
	do_assign_list(L, Clauses, Indent, Used, Stream).

/* Put the next loop into a separate procedure */

do_assignment(L, [define_proc_for(Sm, Path), open_index(MSt, _B) | Clauses],
	      I, Used, Stream) :-
    get_rest_of_my_loop(Clauses, MyLoop, Later), Path = [_|_], wake,
    all(user, append_atoms, [unify(Sm), build(['_context', '_proc', '_mtd']),
			     build([StructName, ProcName, MethodName])]),
    all(language, formal_arg_for_proc_sm,
	[build(Path), unify([L, Used, context]), build(Defns)]),
    excrete(L, struct_defn, [StructName, ['AME_model*', mdlInst, []] | Defns],
	    I, Stream),
    
    CallSpec =.. [call, 'static void', ProcName, ['ModelThread', '*mThd']],
    excrete(L, procedure_start, CallSpec, I, Stream),
    all(render, make_struct_reference,
	[unify(L), unify(mThd), build([tid, phase, context, go, come]),
	 build(_Nms), build([TidMem, PhaseMem, ContextMem, Go0Mem, Come1Mem])]),
    append_atoms(['(', StructName, '*)(', ContextMem, ')'], CastContextMem),
    deepen_indent(I, I1),
    excrete(L, variable_declaration, [StructName, '*context', [],
				      CastContextMem], I1, Stream),
    SetupRandCall =.. [setup_thread_randoms, 1234567890, TidMem],
    excrete(L, procedure_call, SetupRandCall, I1, Stream),
    excrete(L, assignment, phoneHome=Come1Mem, I1, Stream),
    make_struct_reference(L, context, mdlInst, _, InstRef),
    make_struct_reference(L, InstRef, MethodName, _, MethodRef),
    MethodCall =.. [MethodRef, mThd],
    excrete(L, procedure_call, MethodCall, I1, Stream),
    excrete(L, end(procedure), CallSpec, I, Stream),
    nl(Stream),
    MtdCallSpec =.. [call, void, MethodName, ['ModelThread', '*mThd']],
    excrete(L, procedure_start, MtdCallSpec, I, Stream),
    
    excrete(L, variable_declaration, [StructName, '*context', [],
				      CastContextMem], I1, Stream),
    excrete(L, variable_declaration, [int, snf, [2]], I1, Stream),
    make_procedure_call_chars(L, ['PIPEREAD', Go0Mem, '(char*)snf',
				  '2*sizeof(int)'], ReadProcStr),
    name(ReadProc, ReadProcStr),
    excrete(L, while_start, ReadProc, I1, Stream),		     
    deepen_indent(I1, I2),
    excrete(L, variable_declaration, [int, phase, [], PhaseMem], I2, Stream),
    % re-create stuff from open_index
    deepen_indent(I2, I3),
    MSt = glob(Loop, Inds),
    declare(L, Loop, loop, int, Used, I2, Stream),
    make_indexed_reference(L, Loop, Inds, Count),
    % per-record array?
    all(render, make_indexed_reference, [unify(L), unify(snf), build([[0],[1]]),
				   build([Go, Stop])]),
    excrete(L, for_start, [Count, Go, Stop, 1], I2, Stream),
    
    do_assign_list(L, MyLoop, I3, Used, Stream),
    excrete(L, end(for), Count, I2, Stream),
    excrete(L, procedure_call, 'PIPEWRITE'(Come1Mem, '(char*)snf',
				     'sizeof(int)'), I1, Stream),
    excrete(L, end(while), ReadProc, I1, Stream),
    excrete(L, end(procedure), MtdCallSpec, I, Stream),
    do_assign_list(L, Later, I, Used, Stream).

/* Call that proc */

do_assignment(L, [call_proc_for(Sm, Path, Loop) | Clauses], I, Used, Stream) :-
    all(user, append_atoms, [unify(Sm), build(['_context', '_state', '_proc']),
			     build([ContextName, StateName, ProcName])]),
    append_atoms('static struct ', ContextName, StructType),
    excrete(L, variable_declaration, [StructType, StateName, []], I, Stream),
    all(language, arg_for_proc_sm,
	[build(Path), unify([L, Used]), build(Mems), build(Args)]),
    all(render, populate_struct,
	[unify(L), unify(StateName), build([mdlInst | Args]),
	 build([this | Mems]), unify(I), unify(Stream)]),
    make_pointer(L, StateName, StatePtr),
    append_atoms('(void* (*)(void*))', ProcName, CastProcName),
    append_atoms('(void*)', StatePtr, CastStatePtr),
    Call =.. [thread_mgr, CastProcName, phase, CastStatePtr, Loop],
    excrete(L, procedure_call, Call, I, Stream),
    do_assign_list(L, Clauses, I, Used, Stream).
    
/* Clause to handle end of a submodel loop does not actually generate any code (this
is all done at start submodel time) but rearranges the preambles and postambles so
subsequent stuff is put outside the loop.


do_assignment(L, [finish_level | Clauses], Collects,
	      [Exit | Postambles], Used, Stream) :-
	do_writing(Exit, Stream),
	do_assign_list(L, Clauses, Collects, Postambles, Used, Stream).

Here's a really easy clause that enables program statements in the right language
to be stuck directly into the instruction queue. The reason for doing this is so that
when generating new instances, I can leave the conditional open while I add the
initialization of the instance, then slip in the close after it. All this would be
unnecessary if the thing were designed so it could call itself on parts of the
program. I blame Geraint....*/

do_assignment(L, [assign_array(Parent, Name, Made, Init) | Clauses], Indent,
	      Used, Stream) :-
	make_struct_reference(L, Parent, Name, Dest, _),
	make_struct_reference(L, Parent, Made, _, CountRef),
	(Init = -1, !,
	    excrete(L, release_space, [Dest, Used], Indent, Stream);
	 excrete(L, assign_space, Dest=[Parent, Name, [], Used, [CountRef]],
		Indent, Stream)),
	do_assign_list(L, Clauses, Indent, Used, Stream).

do_assignment(L, [verbatim(CodeLine) | Clauses],
	      Indent, Used, Stream) :-
	do_writing(CodeLine, Stream),
	do_assign_list(L, Clauses, Indent, Used, Stream).

/*
do_assignment(L, [marker(_) | Clauses],
	      Indent, Used, Stream) :-
	do_assign_list(L, Clauses, Indent, Used, Stream).

cannot use cos we only assign when condition is right
do_assignment(L, [cond_assign(Dest, Tested, Payload, Op, SoFar) | Clauses],
		Collects, 
		Preambles, [Current | Postambles],
		Used, Temps, Results) :-
	length(Postambles, Nesting),
	Indent is Nesting*4,
	make_scalar(L, Dest, ScalarDest),
	make_evaluation_routine(L, Tested, TestedTerm),
	make_expr(L, TestedTerm, TestedExpr),
	make_evaluation_routine(L, Payload, PayloadTerm),
	make_expr(L, PayloadTerm, PayloadExpr),
	make_scalar(L, SoFar, ScalarSoFar),
	make_pointer(L, ScalarSoFar, SoFarPtr),
	append_atoms(return_if_, Op, Functor),
	make_procedure_call_chars(L, [Functor, TestedExpr, PayloadExpr,
				      SoFarPtr], CondAssignStr),
	name(CondAssign, CondAssignStr),
	render(L, assignment, ScalarDest=CondAssign, Indent, [CodeLine]), 
	append(Current, [CodeLine], NewCurrent),
	do_assign_list(L, Clauses, Collects,
		       Preambles, [NewCurrent | Postambles],
			Used, Temps, Results).
*/
do_assignment(L, [SpecialOp | Clauses], Indent, Used, Stream) :-
	(SpecialOp =.. [Move, DestSpec, TgtRef | Args],
	    Move = collect,
	    nth(CollectId, Used, TgtRef), !,
	    make_scalar(L, DestSpec, Used, Dest),
	    refer(L, Dest, DestRef),
	    all(language, make_evaluation_routine,
		[unify(L), build(Args), unify(Used), build(Inds)]),
 	    CallSpec =.. [Move, DestRef, CollectId | Inds];
	  SpecialOp = call_ext_code(ProcName, CurSmPtr, ArgCodes),
	    all(render, msr_with_ptrs,
		[unify(L), unify(CurSmPtr), build(ArgCodes), build(XArgs)]),
	    CallSpec =.. [ProcName | XArgs];
/*	SpecialOp =.. [SubCall, NodeId, InstHandle, NewCond],
	    member(SubCall,
		   [update_submodel, advance_submodel,
		    int_eval_submodel, ext_eval_submodel]),
	    make_section_cond(L, NewCond, PassTest),
	    render><make_constant_string(L, NodeId, Node),
	    make_scalar(L, InstHandle, InstPtr),
	    refer_value(L, InstPtr, InstHandleRef),
	    CallSpec =.. [SubCall, Node, InstHandleRef, PassTest];
	SpecialOp = search_from(ArcInd, _, TopRef),
	    CallSpec = search_from(myClassPtr, ArcInd, TopRef);
*/      SpecialOp = cond_assign(Dest, Tested, Payload, Op, SoFar),
	    make_scalar(L, Dest, Used, ScalarDest),
	    make_pointer(L, ScalarDest, DestPtr),
	    make_evaluation_routine(L, Tested, Used, TestedTerm),
	    make_expr(L, TestedTerm, TestedExpr),
	    make_evaluation_routine(L, Payload, Used, PayloadTerm),
	    make_expr(L, PayloadTerm, PayloadExpr),
	    make_scalar(L, SoFar, Used, ScalarSoFar),
	    make_pointer(L, ScalarSoFar, SoFarPtr),
	    append_atoms(assign_if_, Op, Functor),
	    CallSpec =.. [Functor, TestedExpr, PayloadExpr, SoFarPtr, DestPtr];
	SpecialOp =.. [insert_to_pipe | Args], !,
	    all(language, make_evaluation_routine,
		[unify(L), build(Args), unify(Used), build(VArgs)]),
	    all(render, make_expr, [unify(L), build(VArgs), build(ArgExps)]),
	    CallSpec =.. [insert_to_pipe | ArgExps];
	 SpecialOp = list_fixed_nbrs(Ptr, Shp, CB, RB, Inds), !,
	     all(language, make_evaluation_routine,
		 [unify(L), build(Inds), unify(Used), build([CX, RX])]),
	     CallSpec = make_fixed_nbr_list(Ptr, Shp, CB, RB, CX, RX)),
	excrete(L, procedure_call, CallSpec, Indent, Stream),
	do_assign_list(L, Clauses, Indent, Used, Stream).
% have to render after instantiating CollectId

/* This one starts a conditional execution sequence dependent on the
given submodel */

do_assignment(L, [check_phase(Phase, VMPtrs) | Clauses], Indent,
	      Used, Stream) :-
	deepen_indent(Indent, InnerIndent),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	(make_section_cond(L, VMPtrs, PassTest),
	    combine(L, >=, [Phase, PassTest], PhaseTest),
	    excrete(L, if_start, PhaseTest, Indent, Stream),
	    do_assign_list(L, MyLoop, InnerIndent, Used, Stream),
	    excrete(L, end(cond), PhaseTest, Indent, Stream),
	    fail;
	do_assign_list(L, Later, Indent, Used, Stream)).

do_assignment(L, [check_cond(Cond) | Clauses], Indent,
	      Used, Stream) :-
	deepen_indent(Indent, InnerIndent),
	get_rest_of_my_loop(Clauses, MyLoop, Later),
	(make_evaluation_routine(L, Cond, Used, CondXpr),
	    excrete(L, if_start, CondXpr, Indent, Stream),
	    do_assign_list(L, MyLoop, InnerIndent, Used, Stream),
	    excrete(L, end(cond), CondXpr, Indent, Stream),
	    fail;
	do_assign_list(L, Later, Indent, Used, Stream)).
/*
do_assignment(L, [check_limits(DestSpec, BoundForm) | Clauses],
	      Indent, Used, Stream) :-
	make_scalar(L, DestSpec, Dest),
	(BoundForm = min(Upper, More),
	    make_expr(L, max(Dest-Upper, adapt_maxerr), Overshoot),
	    excrete(L, assignment, adapt_maxerr=Overshoot, Indent, Stream);
	  More = BoundForm),
	(More = max(Lower, result),
	    make_expr(L, max(Lower-Dest, adapt_maxerr), Undershoot),
	    excrete(L, assignment, adapt_maxerr=Undershoot, Indent, Stream);
	  More = result),
	do_assign_list(L, Clauses, Indent, Used, Stream).

do_assignment(L, [apply_limits(DestSpec, BoundForm, Callable, ArgSpecs)
		 | Clauses], Indent, Used, Stream) :-
	all(language, make_scalar,
	    [unify(L), build([DestSpec | ArgSpecs]), build([Dest | Args])]),
	(BoundForm = min(Upper, More),
	    make_expr(L, Dest>Upper, Overshoot),
	    SomeConds = [Overshoot];
	  More = BoundForm,
	    SomeConds = []),
	(More = max(Lower, result),
	    make_expr(L, Dest<Lower, Undershoot),
	    AllConds = [Undershoot | SomeConds];
	  More = result,
	    AllConds = SomeConds),
	build_disjunction(L, AllConds, AppTest),
	excrete(L, cond_events, [AppTest, Callable, Args], Indent, Stream),
	do_assign_list(L, Clauses, Indent, Used, Stream).

do_assignment(L, [apply_event(AllConds, Tgt, Expr, MoreActs) | Clauses],
	      Indent, Used, Stream) :-
	(build_disjunction(L, AllConds, AppTest), !, % fail if no triggers
	    excrete(L, if_start, AppTest, Indent, Stream),
	    DeepIndent is Indent+4,
	    do_assignment(L, [assign(Tgt, Expr) | MoreActs],
			  DeepIndent, Used, Stream),
	    excrete(L, else_clause, AppTest, Indent, Stream),
	    do_assignment(L, [assign(Tgt, 0)], DeepIndent, Used, Stream),
	    excrete(L, end(if), AppTest, Indent, Stream);
	  do_assignment(L, [assign(Tgt, 0)], Indent, Used, Stream)),
	do_assign_list(L, Clauses, Indent, Used, Stream).

do_assignment(L, [cond_event(TriggerExpr, Expr, Transfers) | Clauses],
		  Indent, Used, Stream) :-
	do_assignment(L, [TriggerExpr], Indent, Used, Stream),
	refer_value(L, current_event_magnitude, Magn),
	excrete(L, if_start, Magn, Indent, Stream),
	DeepIndent is Indent+4,
	do_assignment(L, [Expr | Transfers], DeepIndent, Used, Stream),
	excrete(L, else_clause, Magn, Indent, Stream),
	Expr = assign(Dest, _),
	do_assignment(L, [assign(Dest, 0)], DeepIndent, Used, Stream),
	excrete(L, end(if), Magn, Indent, Stream),
	do_assign_list(L, Clauses, Indent, Used, Stream).
		    
Initial membership of populations was handled by the new_member
clause up until Simile 4.5, but now it is done like initializing a VM
model, so individuals can persist across a reset. This means their
associations can too, and makes resetting faster. */


do_assignment(L, [init_mems(ParentPtr, Name, create(InitVars)) | Clauses],
	      Indent, Used, Stream) :-
	append_atoms(Name, count, Count),
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointerName),
	make_struct_reference(L, ParentPtr, MetaPointerName, MetaPointer, _), 
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	make_struct_reference(L, ParentPtr, Name, StartPtr, _), 
	make_struct_reference(L, ParentPtr, Count, Index, _), 

%	append_atoms(Type, '*', MType),
	declare(L, Pointer, _, Type, Used, Indent, Stream),
%	declare(L, MetaPointer, _, MType, Used, Indent, Stream),
/*	excrete(L, variable_declaration, [Type, Pointer, []], Indent, Stream),
	excrete(L, variable_declaration, [MType, MetaPointer, []], Indent,
		Stream),
*/	excrete(L, assignment, Index=0, Indent, Stream),
	excrete(L, make_reference, MetaPointer=StartPtr, Indent, Stream),
	       
	make_pointer(L, MetaPointer, MMPtr),
	all(language, make_create_proc,
	    [unify([L, ParentPtr, MMPtr, Index, Name, Indent, Used]),
	     build(InitVars), unify(Stream)]),
	
	excrete(L, procedure_call, delete_list(MPTargetRef), Indent, Stream),
	excrete(L, assignment, MPTarget=0, Indent, Stream),

	do_assign_list(L, Clauses, Indent, Used, Stream).

/* This one should be easy too. When I extract the procedures for initializing
submodel instances where these can't always be done at init time, I leave an
'init_population' node. For population submodels, which do also need to be
initialized when their parents are, this causes the tests to be done and the
inits to be included. */

do_assignment(L, [new_member(ParentPtr, Name, InitVars) | Clauses],
	      Indent, Used, Stream) :-
	append_atoms(Name, count, Count),
	append_atoms(Name, meta, MetaPointerName),
	make_struct_reference(L, ParentPtr, MetaPointerName, MetaPointer, _),
	resolve_pointer(L, MetaPointer, MPTarget),
	make_struct_reference(L, ParentPtr, Count, Index, RefIndex),

	/* Now loop on compartment to create submodel */
	all(language, add_for_channel,
	    [build(InitVars), unify([L, Index, ParentPtr, ParentPtr, MetaPointer, MPTarget, Name, RefIndex, Indent, Used, Stream])]),

	do_assign_list(L, Clauses, Indent, Used, Stream).

/* This is similar to the last one, but handles reproduction. Owing to the
limitations of Tcl it switches context between current instance and new instances.
This could be avoided by peeking at the reproduction compartment then decrementing
it in a local variable, but this way is conceptually simpler, which is everything.
*/

do_assignment(L, [reproduce(ParentPtr, Pointer, Name, ReproNames) | Clauses],
	      Indent, Used, Stream) :-
	deepen_indent(Indent, Indent1),

	append_atoms(Name, count, Count),
	append_atoms(Name, meta, MetaPointerName),
	make_struct_reference(L, ParentPtr, MetaPointerName, MetaPointer, _),
	resolve_pointer(L, MetaPointer, MPTarget),
	make_struct_reference(L, ParentPtr, Count, Index, RefIndex),

	/* Conditional to avoid reproduction with new individuals  -- they have
	not been initialized yet -- no longer needed as they are initialized in
	the loop
	make_new_check(L, Pointer, ParentNewRef),
	combine(L, !, [ParentNewRef], ParentOld),
	excrete(L, if_start, ParentOld, Indent1, Stream), */

	all(language, add_for_channel,
	    [build(ReproNames), unify([L,Index,Pointer,ParentPtr,MetaPointer,MPTarget,Name,RefIndex,Indent1,Used,Stream])]),
%	excrete(L, end(cond), ParentOld, Indent1, Stream),

	do_assign_list(L, Clauses, Indent, Used, Stream).

/* OK, now for mortality. This will have to be called before immigration or reproduction because any new individuals might not yet have values for their loss nodes. It used to be done as part of the reproduction loop but had to be separated now there can be many reproduction channels. However, all loss channels are equivalent, so there only needs to
be one of these loops; the instruction has a list of the appropriate nodes. */

do_assignment(L, [lose(ParentPtr, Name, LossNodes) | Clauses],
	      Indent, Used, Stream) :-
	deepen_indent(Indent, Indent1),
	deepen_indent(Indent1, Indent2),

	/* Now stick in a loop */
	make_struct_reference(L, ParentPtr, Name, SubmodelStartPtr, _), 

	append_atoms(Name, 'type*', Type),
	append_atoms(Name, pointer, Pointer),
	append_atoms(Name, meta, MetaPointerName),
	make_struct_reference(L, ParentPtr, MetaPointerName, MetaPointer, _), 
%	append_atoms(Type, '*', MType),
	declare(L, Pointer, _, Type, Used, Indent, Stream),
%	declare(L, MetaPointer, _, MType, Used, Indent, Stream),
/*	excrete(L, variable_declaration, [Type, Pointer, []], Indent, Stream),
	excrete(L, variable_declaration, [MType, MetaPointer, []], Indent,
		Stream),
	Set pointer to first model in list, and dive into loop */
	excrete(L, make_reference, MetaPointer=SubmodelStartPtr, Indent,Stream),
	resolve_pointer(L, MetaPointer, MPTarget),
 	refer_value(L, MPTarget, MPTargetRef),
	ptr_compare(L, MPTargetRef, 0, NotDone),
	excrete(L, while_start, NotDone, Indent, Stream),
	excrete(L, open_context, Pointer=[ParentPtr, Name, MPTargetRef],
			Indent1, Stream),

	make_struct_reference(L, Pointer, new_instance, NewInstance, _),
	excrete(L, assignment, NewInstance=0, Indent1, Stream),
	
	/* Next remove shagged-out individuals, node is a variable, and move
		on to next instance */
	/* Now dig out the variable names for the loss nodes...add
		probability preprocessing here too */

	make_struct_reference(L, Pointer, 'next', OnPointer, OnPointerRef),
	(setof(LossVal, get_term_refs(L, Pointer, LossNodes, LossVal),
	       LossTerms), !,
	    build_junction(LossTerms, '||', IsDead),

	    excrete(L, if_start, IsDead, Indent1, Stream),
	    excrete(L, assignment, MPTarget=OnPointerRef, Indent2, Stream),
	    excrete(L, release_memory, Pointer, Indent2, Stream),
	    excrete(L, else_clause, IsDead, Indent1, Stream),
	    excrete(L, make_reference, MetaPointer=OnPointer, Indent2, Stream),
	    excrete(L, end(cond), IsDead, Indent1, Stream);
	excrete(L, make_reference, MetaPointer=OnPointer, Indent1, Stream)),    
	excrete(L, end(while), MPTargetRef, Indent, Stream),
	do_assign_list(L, Clauses, Indent, Used, Stream).

/* This is a fairly horrrible clause that puts in what is done when a new submodel
instance is generated; if the instance fails to exist, it terminates building it,
so the end of the last if clause is left on the postambles. Should be less
horrible now it no longer includes the evaluation of the test! */

do_assignment(L, [test(Name, Pointer, Source, Ready) | Clauses],
		Indent, Used, Stream) :-
	
/* Some variable membership models will contain 'dummy' generator clauses to
make sure they get set up and kept in correspondence with their uncles before
any of their values are calculated. The source is 1 on these; in this case
we only make the three lines that insert the submodel instance into its linked list. 
*/
	(Source == 1, !,
	    % clause for dummy generator
	    Indent1 = Indent;
	 (setof(GenVal, get_term_refs(L, Pointer, Source, GenVal), GenVals),
	     build_junction(GenVals,  '&&', TestVal), !;
	  TestVal = 0),
	    excrete(L, if_start, TestVal, Indent, Stream),
	    deepen_indent(Indent, Indent1)),
	deepen_indent(Indent1, Indent2),
	% only insert in linked list if new -- old ones not removed
	make_new_check(L, Pointer, IsNew),
	excrete(L, if_start, IsNew, Indent1, Stream),
	make_struct_reference(L, Pointer, next, OnPointer, OnPointerRef),
	append_atoms(Name, meta, MetaPointer),
	resolve_pointer(L, MetaPointer, MPTarget),
	refer_value(L, MPTarget, MPTargetRef),
	refer_value(L, Pointer, PointerRef),
	excrete(L, assignment, OnPointer=MPTargetRef, Indent2, Stream),
	excrete(L, assignment, MPTarget=PointerRef, Indent2, Stream),
	(member(Ready-Shp, [rect_grid(Out, In)-1, hex_grid(Out, In)-2]) ->
	    make_struct_reference(L, Pointer, nbrs, _NbrPointer, NbrPointerRef),
	    excrete(L, else_clause, IsNew, Indent1, Stream),
	    excrete(L, procedure_call, delete_list(NbrPointerRef),
		    Indent2, Stream),
	    excrete(L, end(cond), IsNew, Indent1, Stream),
	    TS is In+2,
	    (Shp = 2 ->
	        make_evaluation_routine(L, 1+ind(Pointer,0)'%'2, Used, Spacing),
	        make_expr(L, Spacing, SpacingEx);
	      SpacingEx = 0),
	    refer_value(L, trailPt, TrailPtRef),
	    excrete(L, procedure_call,
		    fill_nbr_ptrs(Pointer, trail, TrailPtRef, SpacingEx, TS),
		    Indent1, Stream);
	  excrete(L, end(cond), IsNew, Indent1, Stream)),
	excrete(L, make_reference, MetaPointer=OnPointer, Indent1, Stream),
	
	(do_assign_list(L, Clauses, Indent1, Used, Stream),

	/* Any further assignments in model generation also go inside this 'if'
	clause, so as not to do them is the submodel instance does not exist. Thus
	the 'else' clause and other condition go in the postamble. */
	(Source == 1, !;
	    excrete(L, else_clause, TestVal, Indent, Stream),
	    excrete(L, if_start, IsNew, Indent1, Stream),
	    excrete(L, else_clause, IsNew, Indent1, Stream),
	    % cut instance out of linked list
	    excrete(L, assignment, MPTarget=OnPointerRef, Indent2, Stream),
	    excrete(L, end(cond), IsNew, Indent1, Stream),
	    excrete(L, release_memory, Pointer, Indent1, Stream),
	    (nonvar(TS) ->
	        make_expr(L, TrailPtRef '%' TS, TrailIdx),
	        make_indexed_reference(L, trail, [TrailIdx], TrailSpot),
	        excrete(L, assignment, TrailSpot='NULL', Indent1, Stream);
	      true),
	    excrete(L, end(cond), TestVal, Indent, Stream),
	    fail);
	true). % all remaining clauses are inside condition group


/* Right, this is the one with the meat in it; the actual integration of new code
that evaluates an expression in the model */

do_assignment(L, [assign(Dest, Source) | Clauses], Indent, Used, Stream) :-
	make_scalar(L, Dest, Used, ScalarDest),
	make_evaluation_routine(L, Source, Used, Term),
%	make_expr(L, Term, Expr),
	excrete(L, assignment, ScalarDest=Term, Indent, Stream),

	do_assign_list(L, Clauses, Indent, Used, Stream).

deepen_indent(Indent, Deeper) :-
    Deeper is Indent+4.

count_loops(LoopSpec, Count) :-
    LoopSpec = set(I,_),
      Count = [I];
    LoopSpec = fm_loop(_IndExprs,_,_,_),
      Count = []; % should match those in set() levels
    LoopSpec = vm_loop(_Type, Count, _, _).

set_introspect(L, Used, IndexSlot, CountSlot) :-
    ensure_unused('/slot', Free, Used, []),
    (atom_concat('/slot_', LoopNumAtom, Free) ->
	 atom_number(LoopNumAtom, LoLoopNum),
	 LoopLevel is LoLoopNum+1;
     LoopLevel=0),
    make_indexed_reference(L, loopIndexPtrs, [LoopLevel], IndexSlot),
    make_indexed_reference(L, loopIndexCounts, [LoopLevel], CountSlot).

template_type(TptName, Specific, TptPtr) :-
	append_atoms([TptName, ' <', Specific, 'type> *'], TptPtr).

starts_a_level(Inst) :-
	member(Inst, [open_index(_,_), start_submodel(_,_,_,_),
		      generate(_,_,_,_,_,_,_), bound_gen_loop(_,_,_,_),
		      check_phase(_,_), check_cond(_)]).

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

arg_for_proc_sm(Level, [L, Used], ArgRef, Field) :-
    (Level = sm(_,_, Arg, _);
    Level = set(Spec, _),
      make_scalar(L, Spec, Used, Arg)),
    refer_value(L, Arg, ArgRef),
    generate_name(L, arg, Field, Used).

formal_arg_for_proc_sm(Level, [L, Used, State], [Type, Mem, []]) :-
    (Level = sm(Name, _, Arg, _),
       append_atoms(Name, 'type*', Type);
     Level = set(Spec, _),
       Type = int,
       Spec = glob(_, glob(Arg, []))),
    generate_name(L, arg, Mem, Used),
    make_struct_reference(L, State, Mem, Arg, _).

declare_as(glob(Ind,_), Type, [Ind, Type]).

move_base_ptrs(_,_,_,_, [],[],_).
move_base_ptrs(L, Pointer, Action, Indent,
	       [Ptr | Ptrs], [Type | Types], Stream) :-
	length(Ptrs, Count),
	make_struct_reference(L, Pointer, baseptrs, SafeArray, _),
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
	        sicstus_format_to_chars("static_cast<~a>(~a)", [Type, Target],
					CastTgtStr),
		name(CastTgt, CastTgtStr);
	    L = tcl,
	        refer_value(L, Target, CastTgt)),
	    excrete(L, assignment, Ptr=CastTgt, Indent, Stream)),
	move_base_ptrs(L, Pointer, Action, Indent, Ptrs, Types, Stream).

make_section_cond(L, VMPtrs, PassTest) :-
	refer_value(L, phase, PhaseRef),
	(VMPtrs = [], !,
	    PassTest = PhaseRef;
	all(language, make_new_base_cond,
	    [unify(L), build(VMPtrs), build(LocaleTests)]),
	    build_junction(LocaleTests, '||', NewTest),
	    combine(L, choose, [NewTest, -2, PhaseRef], PassTest)).
	    
	
make_new_base_cond(L, new_context(Ptr, Phase), LocCond) :-
	refer_value(L, phase, PhaseRef),
	combine(L, >=, [Phase, PhaseRef], PhaseTest),
	(Ptr = all, !,
	    LocCond = PhaseTest;
	make_new_check(L, Ptr, FlagTest),
	    combine(L, '&&', [PhaseTest, FlagTest], LocCond)).

/* This gets a bit sophisticated now. If the name is free, it
generates one from namebase and inserts a declaration, also adding a
decl(Name) to Used so it doesn't get declared again in the same
context. If the name is ground, it checks for this, and declares it
and adds it if it isn't there.  */

declare(L, Name, NameBase, Type, Used, Indent, Stream) :-
	(var(Name),
	    generate_name(L, NameBase, Name, Used);
	 \+ utility><something_used_in([decl(Name)], Used)),
	    member(Name, Used),
	    member(decl(Name), Used), !,
	    excrete(L, variable_declaration, [Type, Name, []], Indent, Stream);
	true.

declare_ptrs(Name, Type, BasePtr, [L, Indent, Stream]) :-
	append_atoms(Name, 'type*', Type),
	append_atoms(Name, 'pointer', PtrForm), % should not be used
	declare(L, BasePtr, PtrForm, Type, _Used, Indent, Stream).

get_term_refs(_,_, Test, Test) :-
	atom(Test), \+ Test=[].

get_term_refs(L, Pointer, LossNodes, DeadRef) :-
	member(LossVal, LossNodes),
	make_struct_reference(L, Pointer, LossVal, _, DeadRef).

make_create_proc([L, ParentPtr, MMPtr, Index, Name, Indent, Used],
	    InitVar, Stream) :-
	make_struct_reference(L, ParentPtr, InitVar, _, CompValRef),
	refer_value(L, Index, RefIndex),
	nth(ChannelN, Used, InitVar), !,
	BaseArgs = [init_pop, MMPtr, CompValRef, RefIndex, ChannelN],
	/* no function templates in tcl so pass class id explicitly */
	(L = tcl, !,
	    append_atoms(Name, maker, ProcName),
	    make_struct_reference(tcl, ParentPtr, ProcName, CurrentName, _),
	    append(BaseArgs, [CurrentName, Name], AllArgs);
	AllArgs = BaseArgs),
	make_procedure_call_chars(L, AllArgs, CallInitStr),
	name(CallInit, CallInitStr),
	excrete(L, assignment, Index=CallInit, Indent, Stream).

% Add all instances associated with a channel
add_for_channel(InitVar, [L, Index, Pointer, ParentPtr, MetaPointer, MPTarget, Name, RefIndex, Indent, Used, Stream]) :-
	deepen_indent(Indent, Indent1),

	/* Now loop on compartment to create submodel */
	make_struct_reference(L, Pointer, InitVar, CompVal, CompValRef),
	excrete(L, while_start, CompValRef>=1, Indent, Stream),
	make_expr(L, CompValRef-1, NewCompVal),
	excrete(L, assignment, CompVal=NewCompVal, Indent1, Stream),
	excrete(L, increment_by, [Index, 1], Indent1, Stream),
	excrete(L, assign_space, MPTarget=[ParentPtr, Name, [RefIndex],
					  _, []], Indent1, Stream),
	nth(ChannelN, Used, InitVar), !,
	excrete(L, procedure_call, init_pop_member(MPTarget, RefIndex,
						  ChannelN), Indent1, Stream),
	((Pointer = ParentPtr) -> true; % immigrate: progen set to 0 in i_p_m
	  move_base_ptrs(L, MPTarget, save, Indent1, [Pointer], _, Stream)),

	/* End of submodel loop; insert into list and do next */
	make_struct_reference(L, MPTarget, next, OnMeta, _),
	excrete(L, make_reference, MetaPointer=OnMeta, Indent1, Stream),
	excrete(L, end(while), 'New instances', Indent, Stream).

/* special clause for use from membership setter, which passes its list match
test instead of a list of local cond nodes...*/

build_junction([Item], _, Item).

build_junction([Item1, Item2 | Rest], Op, Dis) :-
	build_junction([Item2 | Rest], Op, Others),
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
target language)

test_probs(L, Val, Step, Result) :-
	make_procedure_call_chars(L, [loses, Val, Step], ResultStr),
	name(Result, ResultStr).

Another group of rules with lots of arguments... */
make_evaluation_routine(
	/* Externally defined arguments */
	Language, /* programming language to generate */
	GExpr, /* What we are trying to evaluate */
	Used, % list of constants to get numbers from names
	/* Results, i.e., arguments defined here */
	Term /* the expression that evaluates to the destination
		in current state; -ve = in preambles, +ve = in postambles, 
		0 = inside deepest loop */
	) :-
	(GExpr = glob(_SpareLoop, Expr), % took element of madearray
	    \+ is_list(Expr), !;
	  Expr = GExpr),
	(make_scalar(Language, Expr, Used, LocalExpr), !,
	    refer_value(Language, LocalExpr, Term);
	Expr = ind(Ptr, Count), !,
	    make_struct_reference(Language, Ptr, instanceid, IndSet, _),
	    get_element_ref(Language, IndSet, Count, Term);
	Expr = is_new_instance(Ptr), !,
	    make_new_check(Language, Ptr, Term);
	number(Expr), !,
	    Term=Expr; /* I think not...
	    this goes num -> chars -> atom -> chars -> atom
	    print_to_codes(TermStr, Expr),
	    sicstus_atom_chars(Term, TermStr); */
	member(Expr-Arr-Idx, [time(P)-ts-P, ind_time(P)-ts-P, dt(P)-dts-P,
			      cur_step-dts-0, cur_phase-ts-0]),
	    (Language = c,
		make_indexed_reference(Language, Arr, [Idx], Term);
	    make_procedure_call_chars(Language, [glob_element, Arr, Idx],
				      TimeElmtStr),
		name(Term, TimeElmtStr)), !;
	Expr = assign(Tgt, SubExpr), !,
	    make_scalar(Language, Tgt, Used, Dest),
	    make_evaluation_routine(Language, SubExpr, Used, Source),
	    make_expr(Language, Source, SourceExp),
	    make_assignment(Language, Dest, SourceExp, AssignStr),
	    command_substitute(Language, AssignStr, TermStr),
	    name(Term, TermStr);
	Expr = simile_int(SubExpr), !,
	    (Language = c, Functor = '(int)';
	     Language = tcl, Functor = int),
	    IntExpr =.. [Functor, SubExpr],
	    make_evaluation_routine(Language, IntExpr, Used, Term);
	Expr = graph(GraphId, XAxis), !,
	    make_evaluation_routine(Language, XAxis, Used, GraphTerm),
	    make_expr(Language, GraphTerm, GraphExpr),
	    /* Keep tcl working till it uses c++ graph access */
	    make_procedure_call_chars(Language,
				      [graph_lookup, GraphExpr, GraphId],
				      Content_chars),
/* End of graph clause */
	    name(Term, Content_chars);
	Expr = stop_on_id(GraphId, Ident), !, 
	    make_evaluation_routine(Language, Ident, Used, XIdent),
	    make_expr(Language, XIdent, VIdent),
	    make_procedure_call_chars(Language, [stop_on_id, GraphId, VIdent],
				      Content_chars),
	    name(Term, Content_chars);
	Expr = Home+stage_incr(Struct, Step, Delta, Key, Min, Max, GraphId), !,
	    make_scalar(Language, Home, Used, SHome),
	    make_scalar(Language, Struct, Used, SStruct),
	    make_pointer(Language, SStruct, VStruct),
	    make_evaluation_routine(Language, Home, Used, VHome),
	    make_evaluation_routine(Language, Step, Used, VStep),
	    make_evaluation_routine(Language, Delta, Used, XDelta),
	    make_expr(Language, XDelta, VDelta),
	    make_procedure_call_chars(Language, [stage_incr, SHome, VStruct,
						 VStep, VDelta, Key, Min, Max,
						 GraphId], Content_chars),
	    name(Content, Content_chars),
	    Term = VHome+Content;
	Expr =.. [check_limit, Trigger | Args], !,
	    append(EarlyArgs, [Struct], Args),
	    make_scalar(Language, Struct, Used, SStruct),
	    make_pointer(Language, SStruct, VStruct),
	    append(EarlyArgs, [VStruct], VArgs),
	    make_evaluation_routine(Language, Trigger, Used, VTrigger),
	    make_expr(Language, VTrigger, XTrigger),
	    make_procedure_call_chars(Language, [check_limit, XTrigger | VArgs],
				      TermStr),
	    name(Term, TermStr);
	Expr = ref_to(Struct), !,
	    make_scalar(Language, Struct, Used, SStruct),
	    make_pointer(Language, SStruct, Term);
	Expr = graph_id(Comp), !,
	    nth(Term, Used, Comp);
	Expr = flag_derived_event(_GrapghId, Val), Language = tcl, !,
	    make_evaluation_routine(Language, Val, Used, Term);
	Expr =.. [Op | Args],
	    all(language, make_evaluation_routine,
		[unify(Language), build(Args), unify(Used), build(VArgs)]),
	    combine(Language, Op, VArgs, Term)).

/* make_evaluation_routine_all/many: Same as above, but takes a list of terms rather
than just one, does not take a destination, and returns a list of expressions
which are rendered usable by the stuff in the preamble. Eventually this will have
to be upgraded to behave properly when the arguments have incompatible source
contexts. */

make_scalar(L, Param, Used, FullLocalExpr) :-
	(Param = arr(Ptr, Var, Inds),
	    make_struct_reference(L, Ptr, Var, LocalExpr, _);
	Param = glob(LocalExpr, Inds)), !,
	all(language, make_evaluation_routine,
	    [unify(L), build(Inds), unify(Used), build(ITerms)]),
 	all(language, aim_at_array, [unify(L), build(ITerms), build(ATerms)]),
	all(render, make_expr, [unify(L), build(ATerms), build(IExprs)]),
	make_indexed_reference(L, LocalExpr, IExprs, FullLocalExpr).

aim_at_array(c, Index+1, Index) :- !.
aim_at_array(c, Index, Index-1) :- !.
aim_at_array(_, Index, Index).
