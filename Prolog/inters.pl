sicstus_module(inters, [final_assignment/10, make_intermediates/11,
			expand_library/3, function/3, propagate_units/5,
			wait_for_submodels/2, get_dims_from_loops/3, loops/1,
			make_inds_for/3, pointer_from/2, path_section_for/6]).

sicstus_use_module([library(lists), library(charsio),
		    ame_gen, units, utility]).

final_assignment(Expr, DestRef, Swaps, Step, Used, 
                 NewFormula, Setups, Context, Prerequisites, NewInters) :-
	DestRef = elt(DestPathForm, Target, _-Dims),
	copy_term(DestPathForm, DestPath),
	
	(replace_subexps(Expr, inters, insert_paths,
		sub(DestRef, Swaps), top_down, _, FullExpr), !;
	raise_exception(preprocessor_failure(Target))),

	(on_exception(_, make_intermediates(FullExpr, Target, DestPath,
		BackSwap, [], [], Step, Used, _, AllInters,
		part_result(SourceContext, AllSetups, Args, Formula)),
		      fail);
	sicstus_format_to_chars("Simile failed to convert the equation for component \"~a\" into executable code. See progress box for the location of this component. This is probably because changes were made elsewhere in the model since this component was defined, and as a result its equation no longer makes sense. You should edit the equation again.", [Target], MesgStr),
	    name(Mesg, MesgStr),
	    raise_exception(Mesg)),

	get_model_and_loops(SourceContext, DestPath, _, SourceLoops, _),
	append(SourceLoops, DestPath, BaseContext),
	(swap_back(BaseContext, BackSwap, FContext, no_dim), !;
	raise_exception(cannot_make_context(Target, BaseContext, BackSwap))),

	/* now check for assignment from an idler. This will be eleminated. */
	(Formula = arr(_, Idle, _),
	Args = [made_at(Idle, _)],
	select(instance(internal, _,_, Idle, _-Dims),
	       AllInters, NewInters), !,
	    replace_subexps(AllSetups, inters, swap_vars,
			    switch(Idle, Target), top_down, _, SubbedSetups),
	    select(make(Target, NewArgs, Context, _, NewFormula), SubbedSetups,
		   Setups);
	[Setups, NewInters, NewArgs,  Context] =
	[AllSetups, AllInters, Args, FContext],
	 pointer_from(DestPath, DestPtr),
	 get_dims_from_loops(SourceLoops, _, Inds),
	 NewFormula = [assign(arr(DestPtr, Target, Inds), Formula)]),
	    
	(setof(Model, has_extras(Context, DestPath, Model), Exited), !;
	    Exited = []),
	add_extra_dependencies(Exited, FullExpr, NewArgs, Prerequisites).

insert_paths(sub(DestRef, Swaps), Var, NewVar, Recurse) :-
	var(Var), !,
	    sicstus_write_to_chars(Var, Rep),
	    name(NewVar, Rep),
	    Recurse = 0;	  
	(Var = elt(RealPathForm, Ref, Unit-Dims), !,
	    /* from compartment expressions */
	    [Location, Link]=[in_hierarchy, none];
	Var =.. [Location, elt(RealPathForm, Ref, Unit-Dims), Link, _]),
	    (get_conversion(_, Unit, Unit, _), !,
		Type = real;
	    Type = Unit),

	    (Ref = import(_,_, LvlN, Ptr0, PtrN, _, _, ArcI),
		import_path_for(Dims, RealPathForm, ArcI, 0, Ptr0, LvlN, PtrN,
				LocalLoops, Inds),
		RealPath = [];
	    make_inds_for(Dims, LocalLoops, Inds),
		copy_term(RealPathForm, RealPath)),
	    
	    pointer_from(RealPath, SmPtr),
	    (Location = in_hierarchy,
		Wait = true,
		Path = RealPath;
	    member(path_substitution(Base, Assoc, Link), Swaps),
		(Location = in_base,
		    find_name_host(Link, LinkWithAttrs),
		    (m_class:LinkWithAttrs has_attribute last_membership of 1,
			!; Wait = true),
		    suffix(BaseFrag, Base), /* longest first */
		    append(BaseSide, Top, RealPath),
		    append(Deeper, BaseFrag, BaseSide), !,
		    pointer_from(Top, Ptr),
		    pointer_to(Assoc, Ptr),
		    append([Deeper, Assoc, Top], Path),
		    BackSwap = values_from_base;
		Location = in_assoc,
		    Wait = true,
		    append(Assoc, Top, AssocPath),
		    append(Deeper, AssocPath, RealPath),
		    append([Deeper, Base, Top], Path),
		    BackSwap = path_substitution(Base, Assoc, Link))),
	    append(LocalLoops, Path, Loops),
	    NewVar = param(arr(SmPtr, Ref, Inds), Type, Loops, BackSwap, Wait),
	    Recurse = 0;
	expand_library(DestRef, Var, NewVar),
	    Recurse = 1.

:- dynamic(macro_expansion/1).

expand_library(DestRef, Var, NewVar) :-
	macro_expansion(Macro),
	    Macro = (Var --> NewVar);
	Var = prev(N),
	    (N < 1,
		NewVar = DestRef;
	    M is N-1,
		NewVar = last(prev(M))), !;	  
	do_once(_, Var, ToDo, _),
	    NewVar = delay(ToDo);
	Var = (if Bool then IfCl), !,
	    NewVar = (Bool?IfCl);
	Var = (ThenCl else ElseCl), !,
	    NewVar = (ThenCl:ElseCl);
	Var = (ThenCl elseif Bool then IfCl), !,
	    NewVar = (ThenCl:(Bool?IfCl));
	Var = choose(Bool, V1, V2), !,
	    NewVar = (Bool?V1:V2).

read_library_funx(Done) :-
	retractall(macro_expansion(_Line)), /* in case I ship it after a run */
	open('../Functions/macros.pl', read, Stream1),
	/* rel path only needed in dev sys */
	read_funcs(Stream1, macro, Done1),
	open('../Functions/defns.pl', read, Stream2),
	read_funcs(Stream2, defn, Done2),
	append(Done1, Done2, Done).

read_funcs(Stream, Type, Done) :-
	on_exception(WrongUDF, read(Stream, Line),
		     (ame_gen:make_nice_error_message(WrongUDF, Bug),
			 sicstus_format_to_chars("Parsing user-defined ~as",
						 [Type], ProbAct),
			 do_dialogue(ProbAct, warning, Bug, ok, _))),
	(nonvar(Bug), !,
	    sicstus_format_to_chars("Parsing user-defined ~as", [Type],
					 ProbAct),
	    do_dialogue(ProbAct, warning, Bug, ok, _),
	    read_funcs(Stream, Type, Done);
	 Line == end_of_file, !,
	    close(Stream),
	    Done = [];
	(Type = macro,
	    Line = (Macro --> _Defn),
	    assert(macro_expansion(Line)),
	    Macro =.. [Fn | _Args],
	    append_atoms(Fn, ' (user-defined macro)', FnEntry);
	Type = defn,
	    Line = function(Functor, _ReturnType, _ArgTypes),
	    assert(Line),
	    assert(use_tcl_proc_for(Functor)), !,
	    append_atoms(Functor, ' (user-defined procedure)', FnEntry)),
	    read_funcs(Stream, Type, More),
	    Done = [FnEntry | More];
	sicstus_format_to_chars("The file ~as.pl contained the line ~w which is in the wrong format for a ~a -- please refer to the documentation.", 
	               [Type, Line, Type], Bug),
	    do_dialogue("Parsing user-defined functions", warning, Bug, ok, _),
	    read_funcs(Stream, Type, Done)).

import_path_for(Dims, Path, ArcI, Lvl0, Ptr0, LvlN, PtrN, LocalLoops, Inds) :-
	append(Outer, [var | Inner], Dims), !,
	    (suffix([sm(Name, _,_, vm_loop(_,_,_,_)) | InnerPath], Path), !;
		Name = none, InnerPath = []),
	    Lvl1 is Lvl0 + 1,
	    make_inds_for(Outer, OutLoops, OutInds),
	    import_path_for(Inner, InnerPath, ArcI, Lvl1, Ptr1,
			    LvlN, PtrN, InnerLoops, Inds),
	    append(InnerLoops, [sm(Name, Ptr0, Ptr1,
				   rm_loop(ArcI, Lvl0, OutInds)) | OutLoops],
		   LocalLoops);
	LvlN = Lvl0,
	    PtrN = Ptr0,
	    make_inds_for(Dims, LocalLoops, Inds).
	
/* make_intermediates: This introduces variables for any intermediate results
required while evaluating a variable. The process is explained in great detail
in exec_contexts.txt. Meantime, here is the list of arguments: */

make_intermediates(
    Source, /* representation of the formula we are trying to evaluate */
    Target, /* The variable we are making, we may have to wait for it before
		  saving something for next step */
    DestPath, /* a list giving the context in which we are attempting to
		  assign the result */
    BackSwap, /* a list of triplets of base model hierarchy, associated model
		  hierarchy and the last (?) section of the link between
		  them. Decides what loop we do the evaluation in. */
    PrevInters, /* Variables added so far for intermediate results for this
		  node. Used to substitute bits of the expression that have
		  already been given one. */
    BuildingArrays, /* Dimensions of arrays being built by explicit
		  makearray(...) functions, needed for choosing the right
		  context for place_in(...) and setting the dimensions of
		  intermediate results */
    Step, /* Time step for the current submodel, to be copied into any new
		  instructions generated. */
    Used, /* A list of variable names for the target language that have been
                  used so far */

    Units, /* Base units required for result. Needed for
		  intermediate variables and when I use this
		  function to parse equations as they are entered */
    NewInters, /* A list for variables which must now be added to the
		  model to hold intermediate results */
    part_result( /* bag up the result parameters we will be making sets of */
    SourceContext, /* A context in which we can calculate the formula that
		  this procedure generates */
    Setups, /* Instructions that must be executed before this formula */
    Args, /* A list of variables used in the formula */
    SourceRef) /* the formula we finally generate */
		  ) :-
	/* zeroth case: we have already made an intermediate variable for
	a subexpression that matches this one: need to save loops as well
	as context!! Cannot do this with randoms, which should all be
	different, except refs to explicit ones which must be the same. */
	member(instance(internal, inter(SourceContext, SourceRef, _), Source,
			Name, _), PrevInters),
	(Source = make_inter(_);
	 \+ contains_something(random, Source)), !,
	    Setups = [],
	    Args = [Name],
	    NewInters = PrevInters;
	  
	/* first case: a reference to another variable. If we are referring to
	a variable via a 'back swap' i.e., it comes from an associated model
	via an exclusive role, then we cannot use any variables from other
	associated or base models. BackSwap keeps track of this constraint.

	Some elements of the param may need to be copied rather than unified */
	copy_term(Source,
		  param(SourceRef, Units, SourceLoops, TermSwap, Wait)), !,
	    (SourceRef = arr(_, import(_, Away, _, Ptr, _, Ph, Var, _), _), !, 
		(var(Away), !, /* external toplink, stub will find from arc */
		    CommonContext = [],
		    Ptr = 'NULL';
		    /* Model to start source search is in this dll --
		    get its pointer */
		suffix(CommonContext, DestPath),
		    CommonContext = [sm(Away, _, Ptr, _) | _]),
		append(SourceLoops, CommonContext, SourceContext);
	    SourceRef = arr(_, Var, _),
		Ph = 1,
		SourceLoops = SourceContext),
	    (var(Wait), !,
		/* we are in the argument of last(...) so no need to wait for
		this before using it, just dont do it at init time */
		Args = [time];
	    swap_back(SourceContext, TermSwap, ParamContext, _),
		/* a typical parameter: made_at(...) will be linked to it at
		the appropriate looping level in remove_idlers */
	        (Ph = 0, !,      /* Var made locally by contained dll */
		    Args = [time]; /* or import from ancestor dll */
		Var = externs_done, !, /* Made from imports by contained dll */
		    Args = [externs_done, time]; 
		Args = [made_at(Var, ParamContext)])), /* Made in this dll */
	    (TermSwap = BackSwap, !;
	    raise_exception(cannot_make_context(TermSwap, BackSwap))),
	    Setups = [],
	    NewInters = PrevInters;
	
	/* second case: a cumulative function. For the cases count and exists.
	where the result does not depend on the actual values being checked,
	we put in a dummy reference to them to make sure the increment takes
	place in the source loop. */
	(Source = count(Epsilon);
	Source = sum(Epsilon),
		InitVal = 0,
		IncrOp = (+);
	Source = product(Epsilon),
		InitVal = 1,
		IncrOp = (*);
	Source = least(Epsilon),
		InitVal = Muckle,
		IncrOp = min;
	Source = greatest(Epsilon),
		InitVal = Wee,
		IncrOp = max;

	Source = any(Epsilon),
	    InitVal = 0,
	    IncrOp = ('||');
	Source = all(Epsilon),
	    InitVal = 1,
	    IncrOp = ('&&');
	member(Source, [make_inter(Epsilon), delay(Epsilon),
			last(Epsilon), exists(Epsilon)]),
	    MadeDim = new_dim), !,

	/* If we are making an explicit intermediate variable then we
	do NOT want it to have a different value each time we go round a loop!
	Or do we...probably yes actually if making it inside a makearray. But
	don't use extra dims if values will all be the same...*/
	
	(contains_something(individuates, Source), !,
	    NowBuilding = BuildingArrays;
	NowBuilding = []),
	
	Source =.. [Functor | _],
	sicstus_format_to_chars("~a_~a", [Target, Functor], TotalNameStr),
	name(TotalNameBase, TotalNameStr),
	generate_name(c, TotalNameBase, TotalName, Used),
	copy_term(DestPath, TotalPath),
	make_intermediates(Epsilon, TotalName, TotalPath, SubSwap,
			   PrevInters, NowBuilding, Step, Used, ArgUnits,
			   OldInters, part_result(SubContext, OldSetups,
						  OldArgs, IncrementRef)),
	get_model_and_loops(SubContext, TotalPath, _, SubLoops, _),

	/* choose a location for Total where it will be visible in the
	destination path .... need to make sure it does not contain any
	of the pointer references from the source */
	swap_back(TotalPath, SubSwap, WritePath, MadeDim),
	append([SubLoops, NowBuilding, WritePath], WriteContext),
	pointer_from(TotalPath, TotalPtr),
	pointer_from(DestPath, SourcePtr),

	(var(MadeDim), !, /* Summing over something other than a bunch of
	                  assoc models */
	    (append(TailLoops, [SumLoop | ItemLoops], SubLoops),
	    loops(SumLoop),
	    \+ (member(OtherLoop, ItemLoops), loops(OtherLoop));
		raise_exception(needs_array_or_list(Source)));
	TailLoops = SubLoops),
	(setof(Sm, has_extras(WriteContext, DestPath, Sm), Exited), !;
	 Exited = []),

	/* Total must have same dims as one element of its arg,
	so lets work that out... */
	((Functor = exists,
	        IncrExpr = 1,
	        Units = boolean;
	    Functor = count,
	        IncrExpr = FillRef+1,
	        (nonvar(SumLoop), SumLoop = set(_, loop(SourceRef)),
		    Units = const_int;
		Units = int)), !,
	    InitVal = 0,
	    Preps = [];
	(member(Functor, [make_inter, last, delay]), !,
		InitVal = 0,
		IncrExpr = IncrementRef,
	        [RUnits | ArgTemplate] = [any, any];	
	    IncrExpr =.. [IncrOp, IncrementRef, FillRef],
	        (member(Functor, [any, all]), !,
		    [RUnits | ArgTemplate] = [boolean, boolean];	
		    [RUnits | ArgTemplate] = [int, int])),
	    propagate_units(Source, RUnits, ArgTemplate, [ArgUnits], Units),
	    Preps = OldSetups),
	get_dims_from_loops(TailLoops, TotalDims, LoopInds),

	/* get limit values for least and greatest -- should use limits.h
	but no such for tcl and doesnt have float limits anyway, so...

	Actually it is unsound taking the very end value as a bit of
	arithmetic can push it over the edge, so these two ints are midrange
	for their signs */
	(Units = int, !,
	    [Wee, Muckle] = [-1073741823, 1073741823];
	[Wee, Muckle] = [-1.0e100, 1.0e100]), 

	(\+ (member(VarDim, TotalDims), VarDim == var);
	    raise_exception(avoid_var_size_inter(Epsilon, TotalDims))),
	get_dims_from_loops(NowBuilding, BuildDims, BuildInds),
	append(BuildDims, TotalDims, InterDims),
	append(BuildInds, LoopInds, FillInds),
	make_inds_for(TotalDims, SourceLoops, NewInds),
	FillRef = arr(TotalPtr, TotalName, FillInds),
	append(BuildInds, NewInds, SrcInds),
	TotalRef = arr(SourcePtr, TotalName, SrcInds),

	add_extra_dependencies(Exited, Source, OldArgs, Depends),
	ClearingFor = TotalName,
	(Functor = last, !, Args = [TotalName]; /* bit of a hack...since
	    we use the total from the previous time step we don't need to
	    worry about accessing elements that haven't yet been set, and not
	    using made_at(...) should prevent it being removed as an idler */
	Args = [made_at(TotalName, SourceContext)]),
	(Units = const_int;
	    SourceRef = TotalRef),
	append(SourceLoops, DestPath, SourceContext),
	append([SourceLoops, NowBuilding, DestPath], ClearContextForm),
	copy_term([ClearContextForm, TotalRef, DestPath],
		  [ClearContext, ClearRef, ClearPath]),

	(Units = const_int, !,
	    Setups = [],
	    NewInters = OldInters;
	((Functor = delay; Functor = make_inter), !,
	    Clearing = [];
	Functor = last, !,
            Clearing = [make(initializing(TotalName), [on_reset], ClearContext,
                             0, [assign(ClearRef, InitVal)]),
                        make(cleared(TotalName), [initializing(TotalName)],
                             ClearPath, 0, [])];
        Clearing = [make(clearing(ClearingFor), [this_step(TotalName)],
			 ClearContext, Step, [assign(ClearRef, InitVal)]),
                  make(cleared(ClearingFor), [clearing(ClearingFor)],
                       ClearPath, Step, [])]),
	(Functor = last, !,
	    /* we can update the saved value as soon as it has been used,
	    but we need to wait for all the goals that might use it...started
	    Setting = [make(increment(TotalName),
			    [Target, increment(Target) | Depends],
	    but now goes in update phase before compartments so only needs to
	    check if another last(...) has been copied from it */
	    Setting = [make(lastvalue(TotalName), [lastvalue(Target)],
			    WriteContext, Step, [assign(FillRef, IncrExpr)]),
		       make(TotalName, [cleared(TotalName), time],
			    DestPath, Step, [])];
	(Functor = delay, !, SetTime=0; SetTime = Step),
	Setting = [make(increment(TotalName), [cleared(TotalName) | Depends],
		       WriteContext, SetTime, [assign(FillRef, IncrExpr)]),
		  make(TotalName, [increment(TotalName)],
		       DestPath, SetTime, [])]),
	append([Clearing, Preps, Setting], Setups),
	/* Hopefully the total cannot be used in the loop in which it is
	created because of its different dimensions...be sure to try */
	copy_term(SourceContext, InterContext),
	NewInters = [instance(internal, inter(InterContext, TotalRef, Target),
			      Source, TotalName, Units-InterDims) | OldInters]);	  

	/* third case: a numerical value. Usable in any context.  */
	get_actual_sizes([Source],[SourceRef]), !,
	    SourceContext = [],
	    Setups = [],
	    Args = [],
	    NewInters = PrevInters,
	    (integer(SourceRef), !, Units = const_int;
		Units = real);

	fail, /* suspended due to scope problems */
	add_zeros(Source, BoundArray, ConstBounds, Units), !,
	    make_inds_for(ConstBounds, SourceContext, Inds),
	    generate_name(c, array, ArrayName, Used),
	    SourceRef = arr('', ArrayName, Inds),
	    NewInters = [instance(constant, Target, BoundArray, ArrayName,
				  Units-ConstBounds) | PrevInters], !,
	    Setups = [],
	    Args = [];

	/* fourth case: expression is a test of the provenance of an
	individual. Arg must be converted to numerical id of channel, and
	source context is dest path because channel_is "individuates". */

	(Source = parent(_), !,
	    pointer_from(DestPath, ChannelPtr),
	    SourceRef = arr(ChannelPtr, parentId, []),
	    Units = int;
	Source = channel_is(ChannelName), !,
	    (ChannelName = param(arr(_, ChannelVar, _), _,_,_,_);
	    raise_exception(needs_channel_parameter(ChannelName))),
	    nth(ChannelNum, Used, ChannelVar), !,
	    pointer_from(DestPath, ChannelPtr),
	    /* cannot use pointer from param cos that is parent for cr,im */
	    SourceRef = (arr(ChannelPtr, channelId, [])==ChannelNum),
	    Units = boolean;
	Source = dt(N),
	    (N=0, SourceRef = dt(Step);
	    integer(N), SourceRef = Source;
	    raise_exception(bad_index_number(N, dt))),
	    Units = real, !;
	Source = keep(SourceRef), !;
	(Source = place_in(IndN), !,
	    get_dims_from_loops(BuildingArrays, _, DestInds);
	Source = index(IndN), !,
	    reverse(DestPath, BackDP),
	    all(inters, indices_for, [build(BackDP), append(DestInds, [])])),
	    (integer(IndN), !;
	    raise_exception(bad_index_number(N, index))),
	    (length([_ | OuterInds], IndN),
		suffix([SourceRef | OuterInds], DestInds), !;
	    length(DestInds, AvailInds),
		raise_exception(index_number_out_of_range(IndN, AvailInds))),
	    Units = int,
	    (nonvar(SourceRef), !; SourceRef = glob(_, _))),
	SourceContext = DestPath,
	Setups = [],
	Args = [],
	NewInters = PrevInters;    

	/* fifth case: a function. Here, we recurse for all the arguments, then
	group them into those which can be evaluated in the same context. If
	there is more than one group, create intermediate variables to hold the
	results of all subexpressions not accessible in the destination
	context. */

	(Source = makearray(Element, Dim),
	    (Dim =.. [size | _], !,
		DimVal = Dim;
	    make_intermediates(Dim, dum, [], _, [], [], 0, _, Dun, _,
				part_result(_,_,_, DimVal)),
		Dun = const_int, !;
	    raise_exception(bad_index_number(Dim, makearray))),
	    NowBuilding = [LocalLoop | BuildingArrays];
	make_choose_form(Source, keep(LocalInd), 1, Element),
	    length(Source, DimVal),
	    NowBuilding = BuildingArrays), !,
	    LocalLoop = set(LocalInd, loop(DimVal)),
	    make_intermediates(Element, Target, DestPath, BackSwap, PrevInters,
			NowBuilding, Step, Used, Units, NewInters,
			part_result(EltContext, Setups, Args, SourceRef)),
	    get_model_and_loops(EltContext, DestPath, _, EltLoops, EltBase),
	    append(EltLoops, [LocalLoop | EltBase], SourceContext);

	Source = element(Array, Indx), !,
	    make_intermediates(Indx, Target, DestPath, BackSwap, PrevInters,
			       BuildingArrays, Step, Used, Int, MidInters,
			       part_result(IContext, ISetups, IArgs, IndxRef)),
	    (member(Int, [int, const_int]), !,
		IntIndxRef = IndxRef;
	    Int = real, !, /* for legacy cases */
	        IntIndxRef = simile_int(IndxRef);
	    raise_exception(needs_number_index(Source))),
	    make_intermediates(Array, Target, DestPath, BackSwap, MidInters,
			   BuildingArrays, Step, Used, Units, NewInters,
			   part_result(AContext, ASetups, AArgs, SourceRef)),
	    get_model_and_loops(IContext, DestPath, _, ILoops, IBase),
	    get_model_and_loops(AContext, DestPath, _, ALoops, ABase),
	    (append(TailLoops, [set(IntIndxRef, loop(Limit)) | ItemLoops],
		    ALoops),
	    \+ (member(OtherLoop, ItemLoops), loops(OtherLoop));
		raise_exception(only_works_on_array(Source))),
	    (nonvar(Limit), !; Limit = 0), /* for prev(0) dimensions */
	    
/*	    (append(TailLoops, [set(IntIndxRef, loop(_Limit)) | ItemLoops],
		    ALoops),
	    \+ (member(OtherLoop, ItemLoops), loops(OtherLoop));
		raise_exception(only_works_on_array(Source))), */

	    append(ASetups, ISetups, Setups),
	    merge_lists(AArgs, IArgs, Args),
	    longest_path([ABase, IBase], EltBase),
	    append([TailLoops, ItemLoops, ILoops, EltBase], SourceContext);
	    /* 'catch' is in case we use an element that doesn't exist in the
	    counterfactual arm of a conditional */
	
	Source = (Param=SubExp,Rest), !,
	    replace_subexps(Rest, inters, swap_vars,
			    switch(Param, make_inter(SubExp)), top_down, _,
			    UseSource),
	    make_intermediates(UseSource, Target, 
			DestPath, BackSwap, PrevInters, BuildingArrays, 
			Step, Used, Units, NewInters,
			part_result(SourceContext, Setups, Args, SourceRef));

	\+ atom(Source),
	    (individuates(_, Source, _, _), !,
		FunctionContext = DestPath;
	    FunctionContext = []),

	    (random(_, Source, _,_), !,
		Args = [on_reset | UseArgs];
	    Args = UseArgs),

/*	    replace_subexps(Source, inters, change_constituent,
			    switch(Source, none, none),
			    top_down, Components, SourceRef), */
	    (Source = [_ | _], !,
		length(Source, Enums),
		RUnits = any,
		list_of(RUnits, Enums, Arg_template),
		    /* need type for bool/int */
		SourceList = Source,
		SourceRef = ResultList;
	    Source = (Test?True:False), !,
		SourceList = [Test, True, False],
		RUnits = any,
		Arg_template = [boolean, RUnits, RUnits],
		ResultList = [RTest, RTrue, RFalse],
		SourceRef = (RTest?RTrue:RFalse);
	    Source = graph(V1,V2,V3,V4,V5,V6,V7,V8, Points, Param),
		SourceList = [Param],
		RUnits = real,
		Arg_template = [real],
		ResultList = [RVal],
		SourceRef = graph(V1,V2,V3,V4,V5,V6,V7,V8, Points, RVal);
	    Source = table(SourceList),
		RUnits = real,
		(length(SourceList, TableDims);
		    raise_exception(only_works_on_array(Source))),
		list_of(int, TableDims, Arg_template),
		SourceRef = table(ResultList);
	    Source = sofar(Param),
		SourceList = [Param],
		ResultList = [SourceRef],
		Arg_template = [RUnits];
	    Source =.. [Op | PlSourceList],
		(PlSourceList = [''], !,
		    SourceList = [];
		 SourceList = PlSourceList),
		length(SourceList, Arity),
		length(Arg_template, Arity),
	        (function(Op, RUnits, Arg_template);
		 operator(Op, RUnits, Arg_template);
		 (function(Op, _, WrongLen); operator(Op, _, WrongLen)),
		    length(WrongLen, FnArity),
		    raise_exception(wrong_no_of_args(Source, Op,
						     Arity, FnArity));
		 raise_exception(no_such_function(Source, Op))),
		/* probably need to add dims to units */
		    length(ResultList, Arity),
		    SourceRef =.. [Op | ResultList]),
	    make_all_intermediates(SourceList, Target, DestPath, BackSwap,
				   PrevInters, BuildingArrays, Step, Used,
				   UnitList, NewInters, PartResultList),
	/* first, check my units are right... */
    propagate_units(Source, RUnits, Arg_template, UnitList, Units),
	/* Now...if there are contexts in which all these things can be
	evaluated, return results based on them. */
	    (combine_subexp_results(DestPath, PartResultList, FunctionContext,
				SourceContext, Setups, SubArgs, ResultList), !;
	    raise_exception(cannot_combine_argument_dimensions(Source))),
	    (Source = sofar(_), !,
		dissociate(SubArgs, UseArgs);
	    UseArgs = SubArgs).

dissociate(SubArgs, [later(Arg) | UseArgs]) :-
	select(made_at(Arg, _), SubArgs, Rest), !,
	dissociate(Rest, UseArgs).
dissociate(Args, Args).
	
swap_vars(switch(Take, Add), Tgt, Add, 0) :-
	nonvar(Tgt), Tgt = Take.

swap_back(BaseContext, BackSwap, Context, MadeDim) :-
	(var(BackSwap), !; BackSwap = values_from_base),
	    Context = BaseContext;
	BackSwap = path_substitution(Base, Assoc, Link),
	    append(Base, Top, BasePath),
	    append(Tail, BasePath, BaseContext),
	    append([Tail, Assoc, Top], Context),
	    (m_update:is_exclusive_role(Link), !;
		MadeDim = new_dim).

propagate_units(Source, Lowest, Want, Get, Result) :-
	promote_unit(Lowest, Result),
/*	member(Result, [boolean, int, real]), */
	substitute(Lowest, Want, Result, SettleFor),
	all(inters, promote_unit, [build(Get), build(SettleFor)]);
	raise_exception(mismatched_units(Source, Get, Want)). 
	
promote_unit(Lo, Hi) :-
	Lo = Hi;
	member([Lo, Higher], [[const_int, [int, real]],
			      [any, [boolean, int, real]],
			      [int, [real]]]),
	member(Hi, Higher).

/* Operators and functions. These should be applied in a way that allows
an integer to be treated as a real -- if an arg is real, so is result

Note that most of these correspond to math functions provided by the
target language. However, some are implemented in the equation parser
-- they appear in this list anyway so that (a) they are listed in the
eqn dialogue box and (b) if the user enters them with the wrong number
of arguments they will be told so. Hopefully their correct use will be
caught by the parser before this list is checked so they will not be
put into the target program. */

:- dynamic(function/3).
:- dynamic(use_tcl_proc_for/1).

/* These are implemented by the parser. Note the units are descriptive since
they should never actually be used to parse anything.*/

function(sum, int, [array_or_list_of_ints]).
function(product, int, [array_or_list_of_ints]).
function(count, int, [array_or_list_of_any]).
function(any, boolean, [array_or_list_of_boolean]).
function(all, boolean, [array_or_list_of_boolean]).
function(channel_is, boolean, [channel]).
function(dt, real, [const_int]).
function(time, real, []).
function(init_time, real, []).
function(parent, int, []).
/* legacy versions from before we had empty arg lists */
function(time, real, [const_int]).
function(init_time, real, [const_int]).
function(parent, int, [dummy_int]).

function(last, any, [any]).
function(prev, given_units, [const_int]).
function(makearray, array_of_any, [any, const_int]).
function(place_in, int, [const_int]).
function(element, any, [array_of_any, int]).
function(size, int, [submodel_name]).
function(size, int, [submodel_name, const_int]).
function(least, int, [array_or_list_of_ints]).
function(greatest, int, [array_or_list_of_ints]).

/* These are the ones that are actually used by the parser, so the units have
to be recognizable. Note that if something is down as returning an int for an
int, it will be expected to return a real for a real, etc */

function(sqrt, real, [real]).
function(log, real, [real]).
function(log10, real, [real]).
function(exp, real, [real]).
function(abs, int, [int]).
function(int, int, [real]).
function(ceil, int, [real]).
function(floor, int, [real]).

function(sin, real, [real]).
function(cos, real, [real]).
function(tan, real, [real]).
function(cot, real, [real]).
function(sinh, real, [real]).
function(cosh, real, [real]).
function(tanh, real, [real]).
function(coth, real, [real]).

function(asin, real, [real]).
function(acos, real, [real]).
function(atan, real, [real]).
function(arctan, real, [real]).
function(acot, real, [real]).
function(asinh, real, [real]).
function(acosh, real, [real]).
function(atanh, real, [real]).
function(acoth, real, [real]).

function(rand, real, [real, real]).
function(rand_var, real, [real, real]).
function(pow, real, [real, real]). /* my c++ does not have int powers */
function(fmod, real, [real, real]).

function(hypot, real, [real, real]).
function(atan2, real, [real, real]).
function(acot2, real, [real, real]).

function(max, int, [int, int]).
function(min, int, [int, int]).

/* This one is recognized by the parser but is not part of the equation
language -- it and the operators are hidden */

operator(ind_time, real, [const_int]).

operator(!, boolean, [boolean]).
operator(+, int, [int]).
operator(-, int, [int]).

operator(+, int, [int, int]).
operator(-, int, [int, int]).
operator(*, int, [int, int]).
operator(//, int, [int, int]).
operator(/, real, [real, real]).

operator(^, int, [int, int]).
operator(==, boolean, [real, real]).
operator(=\=, boolean, [real, real]).
operator(<, boolean, [real, real]).
operator(<=, boolean, [real, real]).
operator(>, boolean, [real, real]).
operator(>=, boolean, [real, real]).
operator(<>, boolean, [real, real]).

operator('&&', boolean, [boolean, boolean]).
operator('||', boolean, [boolean, boolean]).
operator(',', boolean, [boolean, boolean]).
operator(';', boolean, [boolean, boolean]).
operator(and, boolean, [boolean, boolean]).
operator(or, boolean, [boolean, boolean]).
operator((=\=), boolean, [boolean, boolean]).

use_tcl_proc_for(min).
use_tcl_proc_for(max).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* add_zeros has the mind-numbingly monotonous task of shifting
all the array elements along one so that wooly-minded treehuggers can address
the first element as index 1. To relieve the tedium it also checks that
the list contains only numbers, and returns its (ORIGINAL) dimensions. */

zero_copy([], []) :- !.

zero_copy([H | T], [ZH | ZT]) :-
	zero_copy(H, ZH),
	zero_copy(T, ZT), !.

zero_copy(_, 0).

add_zeros(L, [Zeros | NL], N, U) :-
	add_zeros_all(L, NL, Zeros, N, U), !.

add_zeros(N, RN, [], U) :-
	get_actual_sizes([N], [RN]),
	(integer(RN), !, U = int;
	    U = real).

add_zeros_all([], [], _, [0 | _], int).

add_zeros_all([H | T], [NH | NT], Zeros, [N | R], U) :-
	add_zeros(H, NH, R, U1),
	zero_copy(NH, Zeros),
	add_zeros_all(T, NT, Zeros, [M | R], UN),
	([U1, UN, U] = [int, int, int], !;
	    U = real),
	N is M+1.

/* Retursn expressions for a model's indices, those for outer loops first */
indices_for(set(_,_), []).
indices_for(sm(_,_, Ptr, Spec), Inds) :-
	Spec = fm_loop(Inds);	  
	Spec = vm_loop(pop, _,_,_), !,
	    Inds = [ind(Ptr, pop)];
	Spec = vm_loop(Count, _,_,_),
	    (Count = 0, !,
		Inds = [];
	    IndCt is Count - 1,
		indices_for(sm(_,_, Ptr, vm_loop(IndCt, _,_,_)), Rest),
		/* Inds = [ind(Ptr, IndCt) | Rest]).  for inner first */
		append(Rest, [ind(Ptr, IndCt)], Inds)).

make_choose_form([LastElt], _,_, LastElt) :- !.

make_choose_form([Elt | Elts], Ind, N, Ind==N?Elt:Later) :-
	M is N+1,
	make_choose_form(Elts, Ind, M, Later).

/* If the source is in submodels that the dest is not, this copies their loops
(because if there are two refs to it the loops might be different for each
copy_extras(Source, Dest, Extras) :-
	append(Spare, Common, Source),
	suffix(Common, Dest), !,
	copy_term(Spare, Extras).

This determines what happens when arrays of different dimensions are
combined. Originally, each element of the shallower array was taken as an array
itself to make it the same dimensionality as the deeper one. e.g.
[1,2] + [[0,0],[0,0]] = [[1,1],[2,2]]

I then decided that the whole of the shallower array should be multiplied to
match the dimensions of the deeper one, e.g.,
[1,2] + [[0,0],[0,0]] = [[1,2],[1,2]]
and boldly attempted to achieve this by swapping the H1 and H2 with
T1 and T2 in the following routine...however this didn't work, I also had to
(obviously) change the way the equation was parsed so the shallower array's
dimensions matched the inner rather than outer dims of the deeper
array (see combine_dims in module dialogue).

I have now swapped them back on the basis that (a) if a modeller wants
the whole shallower array duplicated they can DIY with an explicit
makearray, and that the user guide (which I can't be bothered
changing) describes it the former way...*/

combine_paths(C1, C2, C) :-
	permutation([C1, C2], [C, []]), !;
	/* next two lines (and last) had H and T swapped */
	append(H1, T1, C1),
	    append(H2, T2, C2),
	    (T1 = T2, T = T2;
	    \+ ((member(Loop, T1); member(Loop, T2)),
		   loops(Loop)),
		merge_lists(T1, T2, T)),
	    \+ T = [], !,
	    combine_paths(H1, H2, H),
	    append(H, T, C).

/* Combine contexts. Takes a source context, a context in which a number
of other sources are being assigned to the destination and a dest
context, and returns a context in which the new source can be assigned
as well. */

combine_contexts(NS, PS, D, CS) :-
	get_model_and_loops(NS, D, _, NL, NP),
	get_model_and_loops(PS, D, _, PL, PP),
	longest_path([NP, PP], CP),
	combine_paths(NL, PL, CL),
	append(CL, CP, CS).

longest_path([], []).

longest_path([Path | Rest], Longest) :-
	longest_path(Rest, Long),
	(suffix(Path, Long), !, Longest = Long;
	    suffix(Long, Path), Longest = Path).

/* think about using all for this -- only cumulative inters is hard */
make_all_intermediates([], _,_,_, I, _,_,_, [], I, []).

make_all_intermediates([Source | Components], Target, DestPath,
		       Swaps, PrevInters, BuildingArrays, Step, Used,
		       [Unit | UnitList], NewInters, [Result | ResultList]) :-
	make_intermediates(Source, Target, 
			   DestPath, Swaps, PrevInters, BuildingArrays, 
			   Step, Used, Unit, NextInters, Result),
	make_all_intermediates(Components, Target, DestPath, Swaps,
			       NextInters, BuildingArrays, Step, Used,
			       UnitList, NewInters, ResultList).



/* combine_subexp_results: Takes a list of sets of possible contexts (and
other result information) and tries to make a single context for all of them.

Functions that must be evaluated at setup must get their own temporary
variables, so they are not allowed here. It may be that the whole
expression gets evaluated only at init time in which case this is unnecessary,
but there is no way to tell yet. */

combine_subexp_results(_, [], FunctionContext, FunctionContext, [], [], []).

combine_subexp_results(DestPath,
		       [part_result(SourceContext, Setup, Args, NewRef)
		       | ResultList], FunctionContext,
		       NewContext, NewSetup, NewArgs,
		       [NewRef | Comps]) :-
	combine_subexp_results(DestPath, ResultList, FunctionContext, 
			     OldContext, OldSetup, OldArgs, Comps),
	combine_contexts(SourceContext, OldContext, DestPath, NewContext),
	append(OldSetup, Setup, NewSetup),
	append(OldArgs, Args, NewArgs).
        /* cannot merge because paths in made_ins must be kept separate */

change_constituent(switch(All, Bit, NewBit), Old, New, 0) :-
	Old = Bit, !,
	    New = NewBit;
	\+ Old = All.

add_extra_dependencies(Exited, Source, VarList, FullList) :-
/* Now if I come out of any generated submodels, add a dependency on the generator
function...similarly a dependemcy on time for any population submodels */

	wait_for_submodels(Exited, WaitList),

/* Also, if the expression contains reference to the current time or time interval
it cannot be evaluated at init time, so treat these as references to a compartment
called 'time' (reserved word) */

	(contains_something(changeable, Source), !,
	    append(WaitList, [time | VarList], FullList);
	append(WaitList, VarList, FullList)).

contains_something(Property, Expr) :-
	replace_subexps(Expr, inters, Property, 0, top_down, [_ | _], _).

/* Changeable subexps are those whose value can change even if their
arguments stay the same. last(_) is in here because the 'last' value of a
constant is zero on the first evaluation step, value of the constant
thereafter. */

changeable(_, Subexp, _, 0) :-
	nonvar(Subexp),
	member(Subexp, [time(_), dt(_), rand_var(_,_), last(_)]).

/* do_once is the opposite: value must stay the same even if the args change,
though the modeller has probably erred if they do -- except for init_time,
which is actually the same function as time but this makes sure it is only
evaluated when the model is created. */

do_once(_, rand_const(Lo, Hi), rand(Lo, Hi), 0).
do_once(_, init_time(N), ind_time(N), 0).

/* individuates refers to a function such as rand_const or index, which gives
a different value for each submodel instance in which it is called, and
hence must be called in the destination context. Ind_time(_) is here cos
in a variable membership submodel, instances are initialized at different
times. last(_) similarly -- even if the args are the same the results are
different if one is brand new and the other not! Some things like randoms
and place_in will also individuate over makearray elements. */

individuates(_, Subexp, _, 0) :-
	random(_, Subexp, _,_);
	nonvar(Subexp),
	member(Subexp, [last(_), channel_is(_), ind_time(_),
			index(_), place_in(_)]).

random(_, Subexp, _, 0) :-
	nonvar(Subexp),
	member(Subexp, [rand(_,_), rand_const(_,_), rand_var(_,_)]).

/* wait_for_submodels/2
This adds the given property of any submodels from which we take values
to the list of things that must be waited for before evaluating a node.
Sure it's trivial now -- used to be tricky when only exotic submodels had
enumerate instructions.  */

wait_for_submodels([], []).

wait_for_submodels([Level | AlsoExited], Waits) :-
	(Level = sm(Model, _,_,_), !,
	    Waits = [enumerate(Model) | Others];
	Waits = Others),
	wait_for_submodels(AlsoExited, Others).

pointer_from([], '').
pointer_from([sm(_,_, Ptr, _) | _], Ptr).

pointer_to([], '').
pointer_to(Path, Ptr) :-
	suffix([sm(_, Ptr, _,_) | Tops], Path),
	\+ member(sm(_,_,_,_), Tops), !.

make_inds_for([], [], []).

make_inds_for([Bound | RB], Sets, [Ind | RI]) :-
	(Bound == var, !,
	    Level = sm(_,_,_, rm_loop(_,_,_));
	Level = set(Ind, loop(Bound))),
	make_inds_for(RB, RX, RI),
	append(RX, [Level], Sets).
	    
get_dims_from_loops([], [], []).

get_dims_from_loops(Loops, Dims, Inds) :-
	append(InnerLoops, [Loop], Loops),
	(Loop = sm(_,_,_, VLoop),
	\+ VLoop = fm_loop(_), !,
	    Dims = [var | RDims],
	    Inds = [none | RInds];
	Loop = set(Ind, loop(Dim)), !,
	    Dims = [Dim | RDims],
	    Inds = [Ind | RInds];
	Dims = RDims,
	    Inds = RInds),
	get_dims_from_loops(InnerLoops, RDims, RInds).

loops(set(_, loop(_))).
loops(sm(_,_,_, vm_loop(_,_,_,_))).
loops(sm(_,_,_, rm_loop(_,_,_))).

get_model_and_loops(Context, Dest, Path, Loops, Base) :-
	get_model(Context, Path),
	append(Loops, Base, Context),
	get_model(Dest, Base), !.

get_model(Context, Path) :-
	suffix(Path, Context),
	    Path = [sm(_,_,_,_) | _], !;
	Path = [].

has_extras(Path1, Path2, Submodel) :-
	Submodel = sm(_,_,_,_),
	member(Submodel, Path1),
	\+ member(Submodel, Path2).

path_section_for(SmName, Context, SmDims, Level, HiPtr, LoPtr) :-
	variable_size(SmName), !,
	    (is_population(SmName), !,
		SmSpec = vm_loop(pop, _,_,_);
	    m_update:list_local_index_meanings(SmName, Bounds),
		length(Bounds, NumInds),
		SmSpec = vm_loop(NumInds, _Bounds, _Loops, _)),
	    Level = [sm(Context, HiPtr, LoPtr, SmSpec)];
	make_inds_for(SmDims, SmPath, SmInds),
	    Level = [sm(Context, HiPtr, LoPtr, fm_loop(SmInds)) | SmPath].
