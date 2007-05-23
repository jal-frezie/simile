sicstus_module(inters, [final_assignment/11, make_intermediates/12,
			expand_library/3, macro_expansion/2, function/4,
			promote_unit/2, promote_arg/3, propagate_units/5,
			wait_for_submodels/2, get_dims_from_loops/3, loops/1,
			make_inds_for/3, pointer_from/2]).

sicstus_use_module([library(lists), sp_only, ame_gen, units, utility]).

final_assignment(Expr, Sm, DestRef, Swaps, Step, Used, 
                 NewFormula, Setups, Context, Prerequisites, NewInters) :-
	DestRef = elt(DestPathForm, Target, XUnits-Dims),
	copy_term(DestPathForm, DestPath),
	
	on_exception(Prob,
		     (replace_subexps(Expr, inters, insert_paths,
		sub(Sm, DestRef, Swaps), top_down, _, FullExp),
		     make_intermediates(FullExp, Sm, Target, DestPath,
		BackSwap, [], [], Step, Used, Units, AllInters,
		part_result(SourceContext, AllSetups, Args, Formula))),
		      raise_exception(conversion_failure(Sm, Prob))),

	get_model_and_loops(SourceContext, DestPath, _, SourceLoops, _),
	append(SourceLoops, DestPath, BaseContext),
	(swap_back(BaseContext, BackSwap, FContext, no_dim), !;
	raise_exception(cannot_make_context(Target, BaseContext, BackSwap))),

	/* now check for assignment from an idler. This will be eleminated. */
	get_dims_from_loops(SourceLoops, _, SourceInds),
	(get_conversion(Formula, Units, XUnits, ScaledF), !; ScaledF=Formula),
	(ScaledF = Formula,
	    Formula = arr(_, Idle, SourceInds),
	    Args = [made_at(Idle, _)],
	    \+ assigned_in_vm_subloop(Formula, FContext, AllSetups),
	    select(instance(internal, _,_, Idle, _-Dims),
		   AllInters, NewInters), !,
	    replace_subexps(AllSetups, inters, swap_vars,
			    switch(Idle, Target), top_down, _, SubbedSetups),
	    select(make(Target, Prerequisites, Context, _, NewFormula),
		   SubbedSetups, Setups);
	[Setups, NewInters, Context] =
	[AllSetups, AllInters, FContext],
	    pointer_from(DestPath, DestPtr),
	    get_dims_from_loops(SourceLoops, _, Inds),
	 NewFormula = [assign(arr(DestPtr, Target, Inds), ScaledF)],
	    
	(setof(Model, has_extras(Context, DestPath, Model), Exited), !;
	    Exited = []),
	add_extra_dependencies(Exited, Formula, Args, Prerequisites)).

assigned_in_vm_subloop(Formula, FContext, AllSetups) :-
	member(make(_,_, MoreLoops, _, Acts), AllSetups),
	member(assign(Formula, _), Acts),
	append(ExtraLoops, FContext, MoreLoops),
	member(sm(_,_,_, vm_loop(_,_,_,_)), ExtraLoops).

insert_paths(sub(Sm, DestRef, Swaps), Var, NewVar, Recurse) :-
	(Var = input(Location, PathExp, Link, Units),
	    m_update:analyze_array(Units, Type, _);
	Var = PathExp,
	    /* from compartment expressions -- used? -- and dest ref */
	    [Location, Link, Type]=[in_hierarchy, none, SourceType]),
	PathExp = elt(RealPathForm, Ref, SourceType-DimTypes), !,
	    all(ame_gen, enum_type_ref, [build(DimTypes), unify(Sm),
					 build(Dims), build(_), build(_)]),
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
%	m_update:get_solo_list_depth(Var, DimExp),
%	    m_update:build_array(any, Dims, DimExp),
%	    make_inds_for(Dims, Loops, _),
%	    NewVar = use_inter(Var),
	    /* just to make sure same var is used for name each occurrence...
	    section removed because it should not be if there are separate
	    uses of same explicit var, e.g., in multiple macro functions */
%	    member(instance(internal, inter(_,_, Loops), NewVar,_, _),
%		   InterInputs),
%	    Recurse = 0;
	Var = channel_is(input(Location, elt(RealPathForm, Ref, _), Link, _)),
	/* Outrageous hack -- for channel nodes of an ancestor
submodel, the link parameter is set to 'outside' if they count as
outside, so in this case we add the submodel level for their submodel,
enabling the channel ID to be got from it */
            copy_term(RealPathForm, RealPath),
	    (Link = outside, !,
		UsePath = [_ | RealPath];
	    UsePath = RealPath),
	    NewVar = channel_is(param(arr(_, Ref,_),_, UsePath,_,_)),
	    Recurse = 0;	  
	expand_library(DestRef, Var, NewVar),
	    Recurse = 1.

:- dynamic(macro_expansion/2).

expand_library(DestRef, Var, NewVar) :-
	shed_dummy_args(Var, Fn),
	Fn =.. [Op | Args],
	length(Args, Arity),
	member(MacroMatch, [right, bad_format, bad_arity]),
	macro_expansion(_Orig, (UseVar --> NewVar)),
	(MacroMatch = right,
	    UseVar = Fn, !;
	 UseVar =.. [Op | BadArgs],
	    (MacroMatch = bad_format,
		length(BadArgs, Arity),
		raise_exception(wrong_format_of_args(Var, Op, Args, BadArgs));
	    MacroMatch = bad_arity,
		length(BadArgs, FnArity),
		raise_exception(wrong_no_of_args(Var, Op, Arity, FnArity))));
	Var = prev(N),
	    ((\+ integer(N); N < 0),
		raise_exception(bad_index_number(N, prev));
	    N < 1,
		NewVar = DestRef;
	    M is N-1,
		NewVar = last(prev(M))), !.	  
	/* These have just been moved to macro_expansions so if statements can
	    be used in other macros
	do_once(_, Var, ToDo, _),
	    NewVar = keep_from_reset(ToDo).
	Var = (if Bool then IfCl), !,
	    NewVar = (Bool?IfCl);
	Var = (ThenCl else ElseCl), !,
	    NewVar = (ThenCl:ElseCl);
	Var = (ThenCl elseif Bool then IfCl), !,
	    NewVar = (ThenCl:(Bool?IfCl));
	Var = choose(Bool, V1, V2), !,
	    NewVar = (Bool?V1:V2). */

read_library_funx(Done) :-
	retractall(macro_expansion(_Cat, _Line)),
	/* in case I ship it after a run */
	assert(macro_expansion('Built-in', (if Bool then ThenCl else ElseCl -->
			       choose(Bool, ThenCl, ElseCl)))),
	assert(macro_expansion('Built-in', (if Bool then ThenCl elseif IfCl -->
			       choose(Bool, ThenCl, if IfCl)))),
%	assert(macro_expansion('Built-in', (choose(Bool, ThenCl, ElseCl) -->
%					       (Bool?ThenCl:ElseCl)))),
	read_func_tree('../Functions/', '../Functions/', yes, BuiltIns),

	backup:use_pref_dir(UserStuff),
	append_atoms(UserStuff, '/Functions/', UserFns),
	read_func_tree(UserFns, UserFns, no, Local),
	append(BuiltIns, Local, Done).

read_func_tree(TopDir, AllDirs, BuiltIn, Done) :-
	append_atoms(AllDirs, '*.pl', LocalTpt),
	output:list_matching_files(LocalTpt, FnIncs),
	all(inters, read_func_file, [build(FnIncs), unify(TopDir),
				     unify(BuiltIn), append(Local, [])]),
	append_atoms(AllDirs, '*/', DeepTpt),
	output:list_matching_files(DeepTpt, DeepDirs),
	all(inters, read_func_tree, [unify(TopDir), build(DeepDirs),
				     unify(BuiltIn), append(Done, Local)]).

read_func_file(File, Context, IsBuiltIn, Done) :-
	open_native(File, read, Stream),
	name(File, FileStr),
	append(Base, ".pl", FileStr),
	name(Context, ContextStr),
	append(ContextStr, NameStr, Base),
	name(Name, NameStr),
	read_funcs(Name, Stream, IsBuiltIn, Done).

read_funcs(File, Stream, IsBuiltIn, Done) :-
	sicstus_format_to_chars("Parsing definitions in ~a", [File], ProbAct),
	on_exception(WrongUDF, read_term(Stream, Line, [variable_names(VPrs)]),
		     (make_nice_error_message(WrongUDF, Bug),
			 do_dialogue(ProbAct, warning, Bug, ok, _))),
	(nonvar(Bug), !,
	    do_dialogue(ProbAct, warning, Bug, ok, _),
	    read_funcs(File, Stream, IsBuiltIn, Done);
	 Line == end_of_file, !,
	    close(Stream),
	    Done = [];
	all(user, call, [build(VPrs)]),
	(IsBuiltIn = yes,
	    Category = 'Built-in';
	IsBuiltIn = no,
	    Category = WhereFound),
	(Line = (Macro --> Defn),
	    WhereFound = 'Macros',
	    /* Only allow free vars in function template -- fix them all then
	    replace those in template with free ones */ 
	    /* get rid of dummy argument */
	    shed_dummy_args(Macro, Fn),
	    (atom(Fn), !,
		Op = Fn,
		NewLine = (Fn --> Defn),
		Pairs = [];
	    Fn =.. [Op | Args],
		replace_subexps(Line, inters, free_params,
				switch(Args, _), top_down, Pairs, NewLine)),
	    (member(var_pair(Param, NewParam), Pairs), NewParam == Param, !,
		sicstus_format_to_chars("Failed to parse macro definition:\n~w\nThe macro function contains the parameter ~w, which does not appear in the arguments of the macro template", [Line, Param], Bug),
		do_dialogue(ProbAct, warning, Bug, ok, _);
	    assert(macro_expansion(Category, NewLine))),
	    append_atoms(['{', Category, ' {', File, '}} ', Op], FnEntry);
	(Line = sample(Functor, ReturnType, ArgTypes),
	        assert(sample(Functor));
	 Line = function(Functor, ReturnType, ArgTypes)),
	    WhereFound = 'Procedures',
	    assert(function(Category, Functor, ReturnType, ArgTypes)),
	    assert(use_tcl_proc_for(Functor)), !,
	    dialogue:spell_out([ReturnType | ArgTypes], 1),
	    dialogue:make_arg_list(ArgTypes, String),
	    sicstus_format_to_chars("{~a {~a}} ~a (~s) returns ~w",
		[Category, File, Functor, String, ReturnType], FnChars),
	    name(FnEntry, FnChars)),
	    read_funcs(File, Stream, IsBuiltIn, More),
	    Done = [FnEntry | More];
	member(Line, [baseline(_,_), unit_definition(_,_), longhand(_,_)]), !,
	    % use asserta so user-supplied definitions override system ones
	    units:asserta(Line),
	    read_funcs(File, Stream, IsBuiltIn, Done);
	sicstus_format_to_chars("The file ~a contained the line ~w which is in the wrong format for a macro, function or unit definition -- please refer to the documentation.", 
	               [File, Line], Bug),
	    do_dialogue("Parsing user-defined functions", warning, Bug, ok, _),
	    read_funcs(File, Stream, IsBuiltIn, Done)).

shed_dummy_args(Op, NewOp) :-
	Op =.. [Fn | Args],
	    member(Args, [[], ['']]), !,
	    NewOp = Fn;
	NewOp = Op.

free_params(switch(Fixed, Var), Arg, ArgVar, 0) :-
	var(Arg), !; /* in case someone used an underscore */
	m_update:get_solo_list_depth(Arg, _),
	(nth(N, Fixed, ArgConst),
	    \+ var(ArgConst), /* in case some b**** used an underscore */
	    Arg = ArgConst,
	    nth(N, Var, ArgVar);
	ArgVar = Arg).

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
    SubId, /* Id of submodel containing expression, needed for evaluating
		  enumerated types */
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
	as context!! Cannot do this with randoms (other than in explicit
	inters), which should all be different. */
	(Source = make_inter(Payload, Ref); Source = Payload),
	Inter = instance(internal,_, Payload, Ref, _),
	member(Inter, PrevInters),
	\+ contains_something(random, Payload), !,
	    NewInters = PrevInters,
	    Setups = [],
	    refer_inter(Inter, DestPath, BuildingArrays,
			Units, SourceContext, Args, SourceRef);

	/* first case: a reference to another variable. If we are referring to
	a variable via a 'back swap' i.e., it comes from an associated model
	via an exclusive role, then we cannot use any variables from other
	associated or base models. BackSwap keeps track of this constraint.*/

	copy_term(Source,
		  param(UseRef, SrcUnits, SourceLoops, TermSwap, Wait)), !,
	    /* very selective unification needed to feed back right dims to
	    parameter info (in case it is a ref to final result) but not
	    indices (because they may differ between references) or var names
	    (so they get instantiated and declared in each procedure) */
	    (TermSwap = BackSwap, !,
		SourceRef = UseRef,
	    Source = param(_, SrcUnits, OrigLoops, _,_),
	    remove_physical_units_if_disabled(SubId, SrcUnits, OrigUnits),
	    (Step = dummy, !,
		Units = OrigUnits;
	    unmake_enum_units(OrigUnits, Units)), !,

	    (\+ var(OrigUnits),
	    member(OrigUnits, [n(Type), a(Type)]),
	    \+ ame_gen:resolve_enum_type(_, SubId, _, OrigUnits, _), !,
		raise_exception(no_local_defn_for_type(Type, SubId));
		
	    get_dims_from_loops(OrigLoops, Dims, _)),
	    /* get_actual_sizes(SubId, Dims, _,_,_), just a check */
	    get_dims_from_loops(SourceLoops, Dims, _),
			    
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
		Ph = -1,
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
		Ph = 1, !,
		    Args = [exts(Var)];
		Var = Target, !,
		    Args = []; % it cannot be a condition of itself
		Args = [made_at(Var, ParamContext)])), /* Made in this dll */
	        /* note that for the time being the made_at condition is thrown
	           away */
	    Setups = [],
	    NewInters = PrevInters;
    /* Unable to merge this parameter's execution loop with what went before.
		Make an intermediate variable for it instead. */
	make_intermediates(make_inter(Source, 'n/a'), SubId, Target, DestPath,
	    BackSwap, PrevInters, BuildingArrays, Step, Used, Units, NewInters,
	    part_result(SourceContext, Setups, Args, SourceRef)));
	
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
	Source = with_least(Epsilon, Payload),
		InitVal = Muckle,
		IncrOp = min;
	Source = with_greatest(Epsilon, Payload),
		InitVal = Wee,
		IncrOp = max;

	Source = any(Epsilon),
	    InitVal = 0,
	    IncrOp = ('||');
	Source = all(Epsilon),
	    InitVal = 1,
	    IncrOp = ('&&');
	member(Source, [make_inter(Epsilon, Ref), at_init(Epsilon),
			last(Epsilon), exists(Epsilon)]),
	    MadeDim = new_dim), !,

	/* If we are making an explicit intermediate variable then we
	do NOT want it to have a different value each time we go round a loop!
	Or do we...probably yes actually if making it inside a makearray. But
	don't use extra dims if values will all be the same...actually dont
	do it anyway, is just too hard */
	
	(contains_something(individuates, Source), !,
	    NowBuilding = BuildingArrays;
	NowBuilding = []),
	
	Source =.. [Functor | _],
	(Functor = make_inter, !,
	    UseSource = Ref,
	    sicstus_format_to_chars("~w_for_~a", [Ref, Target], TotalNameStr);
	UseSource = Source,
	    sicstus_format_to_chars("~a_~a", [Target, Functor], TotalNameStr)),
	name(TotalNameBase, TotalNameStr),
	generate_name(c, TotalNameBase, TotalName, Used),
	copy_term(DestPath, TotalPath),
	(var(Payload), !,
	    IncrAct = assign(FillRef, IncrExpr),
	    TXUnits = Units,
	    make_intermediates(Epsilon, SubId, TotalName, TotalPath, SubSwap,
			   PrevInters, NowBuilding, Step, Used, ArgUnits,
			   OldInters, part_result(SubContext, OldSetups,
						  OldArgs, IncrementRef));
	 append_atoms(Target, '_payload', PayloadNameBase),
	    generate_name(c, PayloadNameBase, PayloadName, Used),
	    IncrAct = cond_assign(arr(TotalPtr, PayloadName, FillInds),
				  IncrementRef, PayloadRef, IncrOp, FillRef),
	    make_all_intermediates([Epsilon, Payload], SubId, TotalName,
				   TotalPath, SubSwap, PrevInters, NowBuilding,
				   Step, Used, [TXUnits, ArgUnits], OldInters,
				   PLPartResults),
	    combine_subexp_results(DestPath, PLPartResults, [],
				   SubContext, OldSetups, OldArgs,
				   [IncrementRef, PayloadRef])),
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
	(Functor = count,
	    IncrExpr = FillRef+1,
	    (nonvar(SumLoop), SumLoop = set(_, loop(SourceRef)),
		(integer(SourceRef),
		    Units = const_int;
		atom(SourceRef),
		    Units = n(SourceRef)),
		UsingDim = true;
	    Units = int,
		append(NowBuilding, DestPath, ReadyContext)), !,
	    InitVal = 0;
	member(Functor, [make_inter, last, at_init]), !,
	    InitVal = 0,
	    IncrExpr = IncrementRef,
	    Units = ArgUnits,
	    ReadyContext = ClearContext;
	IncrExpr =.. [IncrOp, IncrementRef, FillRef],
	    (Functor = any, ArgUnits = cond_spec, !,
		[RUnits | ArgTemplate] = [cond_spec, cond_spec];
	     member(Functor, [any, all]), !,
		[RUnits | ArgTemplate] = [boolean, boolean];	
		[RUnits | ArgTemplate] = [int, int]),
	    append(NowBuilding, DestPath, ReadyContext),
	    propagate_units(Source, RUnits, ArgTemplate, [ArgUnits], Units)),
	get_dims_from_loops(TailLoops, TotalDims, LoopInds),

	/* get limit values for least and greatest -- should use limits.h
	but no such for tcl and doesnt have float limits anyway, so...

	Actually it is unsound taking the very end value as a bit of
	arithmetic can push it over the edge, so these two ints are midrange
	for their signs */
	(\+ member(Functor, [least, greatest, with_least, with_greatest]), !;
	TXUnits = int, !,
	    [Wee, Muckle] = [-268435455, 268435455];
	[Wee, Muckle] = [-1.0e100, 1.0e100]), 

	(\+ (member(VarDim, TotalDims), VarDim == var), !;
	    raise_exception(avoid_var_size_inter(Epsilon, TotalDims))),
	get_dims_from_loops(NowBuilding, BuildDims, BuildInds),
	append(BuildDims, TotalDims, InterDims),
	append(BuildInds, LoopInds, FillInds),
	make_inds_for(TotalDims, SourceLoops, NewInds),
	FillRef = arr(TotalPtr, TotalName, FillInds),
	append(BuildInds, NewInds, SrcInds),
	ClearRef = arr(SourcePtr, TotalName, SrcInds),

	add_extra_dependencies(Exited, IncrExpr, OldArgs, Depends),
	append(SourceLoops, DestPath, InterContext),
	append([SourceLoops, NowBuilding, DestPath], ClearContext),

	(UsingDim == true, !,
	    Setups = OldSetups, /* So, we are just using a number, but we might
	have made inters that we will use elsewhere */
	    Args = [],
	    NewInters = OldInters;
	((Functor = at_init; Functor = make_inter), !,
	    Clearing = [];
	Functor = last, !,
            Clearing = [make(cleared(TotalName), [on_reset], ClearContext,
                             0, [assign(ClearRef, InitVal)])];
        Clearing = [make(clearing(TotalName), [this_step(WhatMade)],
			 ClearContext, Step, [assign(ClearRef, InitVal)]),
		    make(cleared(TotalName), [clearing(TotalName)],
			 ReadyContext, Step, [])]),
	(Functor = last, !,
	    /* we can update the saved value as soon as it has been used,
	    but we need to wait for all the goals that might use it...started
	    Setting = [make(increment(TotalName),
			    [Target, increment(Target) | Depends])],
	    but now goes in update phase before compartments so only needs to
	    check if another last(...) has been copied from it */
	    Setting = [make(lastvalue(TotalName), [lastvalue(Target)],
			    WriteContext, Step, [IncrAct]),
		       make(TotalName, [cleared(TotalName), time],
			    ClearContext, Step, [])];
	    /* If keep_from_reseting, we can remove time from the increment expression's
	    conditions since we need only do it once even though it changes */
	(Functor = at_init, !,
	    SetTime=0, purge(Depends, [time], KeepDeps);
	SetTime = Step, KeepDeps = Depends),
        (member(Functor, [make_inter, at_init]), !,
	    Setting = [make(TotalName, KeepDeps, WriteContext, SetTime,
			    [IncrAct])];
	Setting = [make(increment(WhatMade), [cleared(TotalName) | KeepDeps],
                       WriteContext, SetTime, [IncrAct]),
                  make(WhatMade, [increment(WhatMade)],
                       ReadyContext, SetTime, [])])),
	append([OldSetups, Clearing, Setting], Setups),
	/* Hopefully the total cannot be used in the loop in which it is
	created because of its different dimensions...be sure to try */
	Inter = instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, TotalName, TXUnits-InterDims),
	merge_lists([Inter], OldInters, MidInters),
	(var(Payload), !,
	    WhatMade = TotalName,
	    NewInters = MidInters,
	    FinalInter = Inter;
	Outer = instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, PayloadName, Units-InterDims),
	    WhatMade = PayloadName,
	    merge_lists([Outer], MidInters, NewInters),
	    FinalInter = Outer),
	refer_inter(FinalInter, DestPath, BuildingArrays,
		    Units, SourceContext, Args, SourceRef));	  

	/* third case: a numerical value. Usable in any context.  */
	decode_number(Source, SubId, Step, SourceRef, Units), !,
	    SourceContext = [],
	    Setups = [],
	    Args = [],
	    NewInters = PrevInters;

	(Source = table_const(1),
	    \+ Step = dummy,
	    (m_class:SubId has_class_refinement table_data of TableData;
		raise_exception(missing_graph_or_table_data(Source))),
	    member(dims=ConstBounds, TableData),
	    member(current=BoundArray, TableData),
	    member(units=OrigUnits, TableData),
	    (member(OrigUnits, [boolean, real, 1]), !,/* is 1 still needed? */
		Units = OrigUnits;
	    Units = int);
	add_zeros(Source, SubId, Step, BoundArray, ConstBounds, Units)), !,
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

	((Source = parent(_), !,
	    pointer_from(DestPath, ChannelPtr),
	    SourceRef = arr(ChannelPtr, parentId, []),
	    Units = int;
	Source = channel_is(ChannelName), !,
	    (ChannelName = param(arr(_, ChannelVar,_),_, ChanPath,_,_);
	    raise_exception(needs_channel_parameter(ChannelName))),
	    nth(ChannelNum, Used, ChannelVar), !,
	    suffix(ChanPath, DestPath),
	    pointer_from(ChanPath, ChannelPtr),
	    SourceRef = (arr(ChannelPtr, channelId, [])==ChannelNum),
	    Units = boolean),
	    /* re-use of population data structures means values can change
	    if creation counts do */
	    Args = [on_reset];
	(Source =.. [TRef, N],
	    member(TRef, [time, dt]), % ind_time removed
	    ((N=0; N = ''), SourceRef =.. [TRef, Step];
	    integer(N), SourceRef = Source;
	    raise_exception(bad_index_number(N, TRef))),
	    default_tick_is(OrigUnits),
	    remove_physical_units_if_disabled(SubId, OrigUnits, Units), !;
	Source = keep(SourceRef), !;
	(Source = place_in(IndN), !,
	        get_dims_from_loops(BuildingArrays, DestDims, DestVals),
	        (Step = dummy, !,
		    DestInds = DestDims;
		DestInds = DestVals);
	    Source = index(IndN), !,
	        reverse(DestPath, BackDP),
	        all(inters, indices_for,
		    [build(BackDP), append(DestInds, [])])),
	    (integer(IndN), !;
	    raise_exception(bad_index_number(N, index))),
	    length(DestInds, AvailInds),
	    IndPosn is AvailInds-IndN,
	    (nth0(IndPosn, DestInds, SourceRef),
		(Step = dummy,
		    type_ind(SourceRef, Units);
		Units = int), !;
		raise_exception(index_number_out_of_range(IndN, AvailInds))),
	    (nonvar(SourceRef), !;
		/* generate_name(c, loop, LoopName, Used), */
		SourceRef = glob(_LoopName, _))),
	    Args = []),
	SourceContext = DestPath,
	Setups = [],
	NewInters = PrevInters;    

	/* fifth case: a function. Here, we recurse for all the arguments, then
	group them into those which can be evaluated in the same context. If
	there is more than one group, create intermediate variables to hold the
	results of all subexpressions not accessible in the destination
	context. */

	((Source = makearray(Element, Dim); Source = soloarr(Element), Dim=1),
	    ((on_exception(_, DimVal is Dim, fail),
		integer(DimVal); % it is integer now
	        make_intermediates(Dim, SubId, dum, DestPath,_, PrevInters,
				   BuildingArrays, Step, Used, Dun, MidInters,
				   part_result([], [], _, DimVal)),
	        (promote_unit(Dun, const_int))), !; % will be integer later
		  raise_exception(bad_index_number(Dim, makearray))), !,
	        NowBuilding = [LocalLoop | BuildingArrays],
	        length(BuildingArrays, BDept),
	        append_atoms(build, BDept, BuildName),
% added to stop bad rankings behaviour
	        LocalInd = glob(BuildName, _);
	    make_choose_form(Source, keep(LocalInd), 1, Element),
	        length(Source, DimVal),
%	        DimSetups = [],
%	        MidInters = PrevInters,
	        NowBuilding = BuildingArrays), !,
	    ((\+ number(DimVal); DimVal > 1; Source = soloarr(_)), !;
		raise_exception(bad_array_size(Source, DimVal))),
	    LocalLoop = set(LocalInd, loop(DimVal)),
	    make_intermediates(Element, SubId, Target, DestPath, BackSwap,
			PrevInters, NowBuilding, Step, Used, Units, NewInters,
			part_result(EltContext, Setups, Args, SourceRef)),
%	    append(DimSetups, EltSetups, Setups),
	    get_model_and_loops(EltContext, DestPath, _, EltLoops, EltBase),
	    append(EltLoops, [LocalLoop | EltBase], SourceContext);

	Source = element(Array, Indx), !,
	    make_intermediates(Indx, SubId, Target, DestPath, BackSwap,
			PrevInters, BuildingArrays, Step, Used, Int, MidInters,
			part_result(IContext, ISetups, IArgs, IndxRef)),
	    make_intermediates(Array, SubId, Target, DestPath, BackSwap,
			MidInters, BuildingArrays, Step, Used,Units, NewInters,
			part_result(AContext, ASetups, AArgs, SourceRef)),
	    get_model_and_loops(IContext, DestPath, _, ILoops, IBase),
	    get_model_and_loops(AContext, DestPath, _, ALoops, ABase),
	    (append(TailLoops, [set(IntIndxRef, loop(Limit)) | ItemLoops],
		    ALoops),
	    \+ (member(OtherLoop, ItemLoops), loops(OtherLoop));
		raise_exception(only_works_on_array(Source))),
	    (Step = dummy,
		type_ind(Limit, NeedType);
	     \+ Step = dummy,
	        NeedType = int),
	    ((promote_unit(Int, NeedType);
	      Int = n(AnET), NeedType = a(AnET)), !,
		/* special case -- count or name of ET can refer to last elt */
		TryIndxRef = IndxRef;
	    promote_arg(Int, real, _),
		promote_arg(NeedType, real, _), !, /* for legacy cases */
	        TryIndxRef = simile_int(IndxRef);
	    raise_exception(needs_index_of_type(Source, NeedType, Int))),
	    (IntIndxRef = TryIndxRef, !;
	    raise_exception(redundant_array(Source))),
	    
	    append(ASetups, ISetups, Setups),
	    merge_lists(AArgs, IArgs, Args),
	    longest_path([ABase, IBase], EltBase),
	    append([TailLoops, ItemLoops, ILoops, EltBase], SourceContext);
	    /* 'catch' is in case we use an element that doesn't exist in the
	    counterfactual arm of a conditional */
	
	Source = (Param=SubExp,Rest), !,
	    (Param = param(arr(_, Ref, _), UseUnit, LoopSlot,_,_), !;
		/* parsing */
	    Param = Ref,
%		member(instance(internal, inter(_,_, Loops), Param,_, _-Dims),
%		       PrevInters),
		m_update:get_solo_list_depth(Ref, DimExp),
		m_update:analyze_array(DimExp, any, RefDims),
		make_inds_for(RefDims, Loops, _),
		append(Loops, BuildingArrays, Access),
		get_dims_from_loops(Access, Dims, _)), /* building code */
	    InitInters = [instance(internal, inter(_,_, Loops), Ref,_, _-Dims)
			 | PrevInters],
	    make_intermediates(make_inter(SubExp, Ref), SubId, Target, 
			DestPath, BackSwap, InitInters, BuildingArrays, 
			Step, Used, DefUnit, MidInters,
			part_result(XIContext, SubSetups, _,_)),
	    get_model_and_loops(XIContext, DestPath,_, XILoops,_),
	    suffix(XILoops, LoopSlot),
	    /* If we know what the parameter units are by now, use them */
	    (nonvar(UseUnit), !; UseUnit = DefUnit),
	    make_intermediates(Rest, SubId, Target, 
			DestPath, BackSwap, MidInters, BuildingArrays, 
			Step, Used, Units, MixedInters,
			part_result(SourceContext, ExSetups, Args, SourceRef)),
	    all(inters, prevent_inappropriate_reuse,
		[unify(Param), build(MixedInters), build(NewInters)]),
				% in case they use param
	    (promote_arg(DefUnit, UseUnit,_FType);
		raise_exception(wrong_param_units(Param, UseUnit, DefUnit))),!,
	    append(SubSetups, ExSetups, Setups);	  

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
		ValRef = ResultList;
%	    Source = (Test?True:False), !,
%		SourceList = [Test, True, False],
%		RUnits = any,
%	        Arg_template = [boolean, RUnits, RUnits],
%		ResultList = [RTest, RTrue, RFalse],
%		ValRef = (RTest?RTrue:RFalse);
	    Source = graph(Param), \+ Param = '',
		(\+ Step = dummy;
		dialogue:table_data_is(_);
		    raise_exception(missing_graph_or_table_data(Source))),
		SourceList = [Param],
		RUnits = real,
		Arg_template = [real],
		ResultList = [RVal],
		ValRef = graph(SubId, RVal);
	    Source =.. [table | SourceList],
	    Step = dummy,
		\+ SourceList = [''], /* let checker handle empty args */
	        (SourceList = [_|_], !;
		raise_exception(only_works_on_array(Source))),
		(dialogue:table_data_is(TableData);
		 raise_exception(missing_graph_or_table_data(Source))),
		member(units=RUnits, TableData),
		member(bounds=Arg_template, TableData),
		ValRef = table(ResultList);
	    Source = rand(Lo, Hi), /* deal with horrible legacy case */
	        SourceList = [rand_var(Lo, Hi)],
		RUnits = real,
		Arg_template = [real],
		[ValRef] = ResultList;
	    Source =.. [Op | ArgListForm],
		(ArgListForm = [''], !, ArgList = [];
		    ArgList = ArgListForm),
		length(ArgList, Arity),
		SourceList = ArgList,
		length(Arg_template, Arity),
		length(ResultList, Arity),
		name(Op, OpStr),
		lower(OpStr, LopStr),
		name(Lop, LopStr),
		ValRef =.. [Lop | ResultList]),
	    make_all_intermediates(SourceList, SubId, Target, DestPath,
				   BackSwap, PrevInters, BuildingArrays, Step,
				   Used, UnitList, NewInters, PartResultList),
	/* Now...if there are contexts in which all these things can be
	evaluated, return results based on them. */
	    (combine_subexp_results(DestPath, PartResultList, FunctionContext,
				SourceContext, Setups, SubArgs, ResultList), !;
	    raise_exception(cannot_combine_argument_dimensions(Source))),
		(ValRef =.. [Lop, _, _],
		 member(Lop, [*, /]),
		    select(One, UnitList, [Other]),
		    \+ promote_arg(One, 1, _),
		    (promote_arg(Other, 1, _),
			(UnitList == [Other, One], Lop = (/),
			    Units = 1/One;
			 Units = One),
			SourceRef = ValRef;
		    TattyUnits =.. [Lop | UnitList],
			sort_units(TattyUnits, Units, ConvFactor),
			SourceRef = ConvFactor*ValRef), !;
		ValRef = Arg1++Arg2,
		    /* Used for compartment increments -- no need to parse
		    these, and conversion is done during instantiation (since
		    it happens whether or not unit checking is on) so result
		    units are simply those of 1st arg */
		    UnitList = [Units, _IncUnits],
		    SourceRef = Arg1+Arg2;
		(ValRef = Log^Exp,
		        UnitList = [Base, ExpU],
		        promote_unit(ExpU, const_ratio);
		 ValRef = sqrt(Log),
		        UnitList = [Base],
		        Exp = 1/2),
		    \+ Base = 1,
		    get_conversion(1, Base, Base, _),
		    (Exp = N/D, !,
			raise_units(Base, N, Mid),
			extract_units_root(Mid, D, Units, Conv),
			SourceRef = (Conv*Log)^Exp;
		    raise_units(Base, Exp, Units),
			SourceRef = ValRef);
		 ValRef = sofar(SourceRef),
		    UnitList = [Units];
		 (var(Lop),
		     SourceRef = ValRef;
		  nonvar(Lop),
		     fn_or_op(Lop, MxOp, RUnits, Arg_template),
		     SourceRef =.. [MxOp | ResultList]),
		    /* first, check my units are right... */
		    try_units(RUnits, Arg_template, UnitList, Units);
		 fn_or_op(Lop, _, RUnits, Arg_template),
		    raise_exception(mismatched_units(Source,
						     UnitList, Arg_template));
		 fn_or_op(Lop, _, RUnits, WrongLen),
		    length(WrongLen, FnArity),
		    raise_exception(wrong_no_of_args(Source, Op,
						     Arity, FnArity));
		 m_class:SubId has_class_refinement uses_local_fns of UserFns,
		    member(Op/Arity, UserFns),
		    raise_exception(lost_user_defined_fn(Source, Op, Arity));
		 raise_exception(no_such_function(Source, Op))),
	    (Source = sofar(_), !,
		all(inters, dissociate, [build(SubArgs), build(UseArgs)]);
	    UseArgs = SubArgs);
	raise_exception(undecipherable_operand(Source, SubId)).

decode_number(Source, SubId, Step, SourceRef, Units) :-
	get_actual_size(SubId, Source, [SrcNum], [SrcType], [SrcUnits]),
	remove_physical_units_if_disabled(SubId, SrcUnits, OrigUnits),
	(Step = dummy, !,
	    SourceRef = SrcType,
	    Units = OrigUnits;
	SourceRef = SrcNum,
	    unmake_enum_units(OrigUnits, Units)).

remove_physical_units_if_disabled(SubId, SrcUnits, Units) :-
	(m_update:use_units_in(SubId, 'No'),
	    nonvar(SrcUnits),
	    get_conversion(_, SrcUnits, SrcUnits, _), !,
	    Units = 1;
	standard_name(SrcUnits, Units)).

unmake_enum_units(SrcUnits, Units) :-
	SrcUnits = n(_),
	    Units = const_int;
	SrcUnits = a(_),
	    Units = int;
	Units = SrcUnits.

raise_units(Base, Num, Units) :-
	Num = 0, Units = 1;
	(Num < 0, Next is Num+1, Do = (/);
	    Num > 0, Next is Num-1, Do = (*)),
	raise_units(Base, Next, Mid),
	Units =.. [Do, Mid, Base].

fn_or_op(Op, MxOp, RUnits, AUnits) :-
	var(Op), MxOp = Op, !;
	name(Op, OpStr),
	(function(_Cat, MxOp, RUnits, AUnits);
	builtin(_Cat, MxOp, RUnits, AUnits);
	operator(MxOp, RUnits, AUnits)),
	name(MxOp, MxOpStr),
	lower(MxOpStr, OpStr).

dissociate(made_at(Arg, _), later(Arg)).
	
refer_inter(instance(internal, inter(Context, _, ParamLoops), Source, Name,
		     Units-Dims),
	    DestPath, BuildLoops, Units, SourceContext, Args, SourceRef) :-
	    (Source = last(_), !,
		Args = [Name]; /* bit of a hack...since
	    we use the total from the previous time step we don't need to
	    worry about accessing elements that haven't yet been set, and not
	    using made_at(...) should prevent it being removed as an idler */
	    Args = [made_at(Name, SourceContext)]),
	    pointer_from(DestPath, SourcePtr),
	    make_inds_for(Dims, IntLoops, IntInds),
	    copy_term(ParamLoops, SourceLoops),
	    /* order of parts exchanged simply cos it made it work */
	    append(SourceLoops, SpareLoops, IntLoops),
	    suffix(SpareLoops, BuildLoops),
	    append(SourceLoops, DestPath, SourceContext),
	    SourceRef = arr(SourcePtr, Name, IntInds).

prevent_inappropriate_reuse(Explicit, instance(Type, I, Replaces, Name, Dims),
			    instance(Type, I, NewReplaces, Name, Dims)) :-
	replace_subexps(Replaces, inters, swap_vars, switch(Explicit, gone),
			top_down, [_Swap1 | _], _), !,
	NewReplaces = 'n/a';
	NewReplaces = Replaces.

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
	promote_unit(Lowest, In),
	substitute(Lowest, Want, In, SettleFor),
	try_units(In, SettleFor, Get, Result), !;
	raise_exception(mismatched_units(Source, Get, Want)).
	

try_units(Result, Want, Get, Out) :-	
	all(inters, promote_arg, [build(Get), build(Want), unify(In)]),
	(Result = real,
	    (nonvar(In), Out = In;
	    Out = 1), !;
	Out = Result). 
	
promote_unit(Lo, Hi) :-
	Lo = Hi;
	uses_as(Lo, Med),
	promote_unit(Med, Hi).

uses_as(any, Type) :-
	member(Type, [boolean, a(_ET), n(_ET)]).
uses_as(boolean, cond_spec).
/* above was commented out, but seems to belong
-- probably so as not to allow cond_specs to use outside conditions
if taking out again fix spread_dims as well as eqn checking */
uses_as(n(_ET), const_int).
uses_as(const_int, int).
uses_as(const_int, const_ratio).
uses_as(const_ratio, real).
uses_as(int, real).

promote_arg(Lo, Hi, Phys) :-
	var(Lo), !, Phys = Lo;
	promote_unit(Lo, Tpt),
	(Tpt = real, Med = 1;
	    Med = Tpt),
	(Hi = real,
	    (nonvar(Phys); var(Phys), Phys = Med),
	    get_conversion(1, Med, Phys, N),
	    1 is N, !;
	Hi = Med).

/* Operators and functions. These should be applied in a way that allows
an integer to be treated as a real -- if an arg is real, so is result

Note that most of these correspond to math functions provided by the
target language. However, some are implemented in the equation parser
-- they appear in this list anyway so that (a) they are listed in the
eqn dialogue box and (b) if the user enters them with the wrong number
of arguments they will be told so. Hopefully their correct use will be
caught by the parser before this list is checked so they will not be
put into the target program. */

:- dynamic(function/4).
:- dynamic(use_tcl_proc_for/1).
:- dynamic(sample/1).

/* These are implemented by the parser. Note the units are descriptive since
they should never actually be used to parse anything. */

builtin('List handling', sum, numeric, [array_or_list_of_numerics]).
builtin('List handling', product, numeric, [array_or_list_of_numerics]).
builtin('List handling', count, int, [array_or_list_of_any]).
builtin('List handling', any, boolean, [array_or_list_of_boolean]).
builtin('List handling', all, boolean, [array_or_list_of_boolean]).
builtin('Model properties', channel_is, boolean, [channel]).
builtin('Model properties', dt, real, [const_int]).
builtin('Model properties', time, real, []).
builtin('Model properties', at_init, any, [any]).
%builtin('Model properties', init_time, real, []).
builtin('Model properties', parent, int, []).
builtin('Model properties', stop, int, [int]).
/* legacy versions from before we had empty arg lists */
builtin('Model properties', time, real, [const_int]).
%builtin('Model properties', init_time, real, [const_int]).
builtin('Model properties', parent, int, [dummy_int]).

builtin('Model properties', last, any, [any]).
builtin('Model properties', prev, given_units, [const_int]).
builtin('List handling', makearray, array_of_any, [any, const_int]).
builtin('List handling', place_in, int, [const_int]).
builtin('List handling', element, any, [array_of_any, int]).
builtin('Model properties', size, int, [submodel_name]).
builtin('Model properties', size, int, [submodel_name, const_int]).
builtin('List handling', least, numeric, [array_or_list_of_numerics]).
builtin('List handling', greatest, numeric, [array_or_list_of_numerics]).
builtin('List handling', with_least, any, [array_or_list_of_numerics, array_or_list_of_any]).
builtin('List handling', with_greatest, any, [array_or_list_of_numerics, array_or_list_of_any]).

/* These are the ones that are actually used by the parser, so the units have
to be recognizable. Note that if something is down as returning an int for an
int, it will be expected to return a real for a real, etc */

builtin('Arithmetic', sqrt, 1, [1]).
builtin('Arithmetic', log, 1, [1]).
builtin('Arithmetic', log10, 1, [1]).
builtin('Arithmetic', exp, 1, [1]).
builtin('Arithmetic', abs, 1, [1]).
builtin('Arithmetic', int, int, [1]).
builtin('Arithmetic', round, int, [1]).
builtin('Arithmetic', ceil, int, [1]).
builtin('Arithmetic', floor, int, [1]).

builtin('Trigonometry', sin, 1, [1]).
builtin('Trigonometry', cos, 1, [1]).
builtin('Trigonometry', tan, 1, [1]).
builtin('Trigonometry', sinh, 1, [1]).
builtin('Trigonometry', cosh, 1, [1]).
builtin('Trigonometry', tanh, 1, [1]).

builtin('Trigonometry', asin, 1, [1]).
builtin('Trigonometry', acos, 1, [1]).
builtin('Trigonometry', atan, 1, [1]).
builtin('Trigonometry', arctan, 1, [1]).

builtin('Statistics', rand_var, real, [real, real]).
builtin('Arithmetic', pow, 1, [1, 1]). /* my c++ does not have int powers */
builtin('Arithmetic', fmod, 1, [1, 1]).

builtin('Trigonometry', hypot, real, [real, real]).
builtin('Trigonometry', atan2, 1, [real, real]).

builtin('Arithmetic', max, int, [int, int]).
builtin('Arithmetic', max, real, [real, real]).
builtin('Arithmetic', min, int, [int, int]).
builtin('Arithmetic', min, real, [real, real]).

builtin('List handling', following, a(T), [a(T)]).
builtin('List handling', following, int, [int]).
builtin('List handling', preceding, a(T), [a(T)]).
builtin('List handling', preceding, int, [int]).
builtin('List handling', first, boolean, [a(_T)]).
builtin('List handling', first, boolean, [int]).

/* These are recognized by the parser but is not part of the equation
language -- they and the operators are hidden */

%operator(ind_time, real, [const_int]).
operator(stage_incr, real, [diffs, int, real]).
operator(choose, int, [boolean, int, int]).
operator(choose, a(T), [boolean, a(T), a(T)]).
operator(choose, real, [boolean, real, real]).
operator(choose, boolean, [boolean, boolean, boolean]).

/* These are handled by the parser but have special buttons to include them so
we do not want them in the function list -- they only appear here so the right
error comes up if they are used with the wrong number of args */

operator(graph, real, [real]).
operator(table, any, ['[index, ...]']).

operator(+, int, [int]).
operator(+, real, [real]).
/* operator(++, int, [int]). */
operator(-, int, [int]).
operator(-, real, [real]).

operator(+, int, [int, int]).
operator(+, real, [real, real]).
operator(-, int, [int, int]).
operator(-, real, [real, real]).
operator(*, int, [int, int]).
operator(*, 1, [1,1]).
operator(//, int, [int, int]).
operator(/, const_ratio, [const_int, const_int]).
operator(/, 1, [1,1]).

/* Comparison ops need int arg version to avoid unnecessarily constraining
parameters to real (and because everything does) */
operator(^, real, [real, real]).
operator(==, boolean, [int, int]).
operator(==, boolean, [real, real]).
operator(==, boolean, [boolean, boolean]).
operator(==, boolean, [a(T), a(T)]).
operator(is, cond_spec, [int, int]).
operator('!=', boolean, [int, int]).
operator('!=', boolean, [real, real]).
operator('!=', boolean, [boolean, boolean]).
operator('!=', boolean, [a(T), a(T)]).
operator(<, boolean, [int, int]).
operator(<, boolean, [real, real]).
operator(<, boolean, [boolean, boolean]).
operator(<, boolean, [a(T), a(T)]).
operator(<=, boolean, [int, int]).
operator(<=, boolean, [real, real]).
operator(<=, boolean, [boolean, boolean]).
operator(<=, boolean, [a(T), a(T)]).
operator(>, boolean, [int, int]).
operator(>, boolean, [real, real]).
operator(>, boolean, [boolean, boolean]).
operator(>, boolean, [a(T), a(T)]).
operator(>=, boolean, [int, int]).
operator(>=, boolean, [real, real]).
operator(>=, boolean, [boolean, boolean]).
operator(>=, boolean, [a(T), a(T)]).
operator(<>, boolean, [int, int]).
operator(<>, boolean, [real, real]).
operator(<>, boolean, [boolean, boolean]).
operator(<>, boolean, [a(T), a(T)]).

operator('&&', boolean, [boolean, boolean]).
operator('||', boolean, [boolean, boolean]).
operator(',', boolean, [boolean, boolean]).
operator(';', boolean, [boolean, boolean]).
operator(and, boolean, [boolean, boolean]).
operator(or, boolean, [boolean, boolean]).
operator(xor, boolean, [boolean, boolean]).
operator(not, boolean, [boolean]).

use_tcl_proc_for(min).
use_tcl_proc_for(max).
use_tcl_proc_for(following).
use_tcl_proc_for(preceding).
use_tcl_proc_for(first).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* add_zeros has the mind-numbingly monotonous task of shifting
all the array elements along one so that wooly-minded treehuggers can address
the first element as index 1. To relieve the tedium it also checks that
the list contains only numbers, and returns its (ORIGINAL) dimensions.

Change for 4.8: Don't move the array, just subtract 1 from the indices before
using them. This because people want to integrate their own c++ programs with
Simile's code, so they want arrays starting at 0. */

add_zeros(L, SubId, Step, NL, [Outer | Dims], U) :-
	add_zeros_all(L, SubId, Step, NL, [Outer | Dims], U),
	(Outer > 1, !; % others already checked
	    raise_exception(bad_array_size(L, Outer))).

add_zeros(N, SubId, Step, RN, [], U) :-
	decode_number(N, SubId, Step, RN, U).

add_zeros_all([], _,_, [], [0 | _], any).

add_zeros_all([H | T], SubId, Step, [NH | NT], [N | R], U) :-
	add_zeros(H, SubId, Step, NH, R, U1),
	add_zeros_all(T, SubId, Step, NT, [M | RR], UN),
	(R = RR, !;
	    raise_exception(cannot_combine_argument_dimensions([H | T]))),
	propagate_units(list_parts(H,T), any, [any, any], [U1, UN], U),
	N is M+1.

/* Returns expressions for a model's indices, those for outer loops first */
indices_for(set(_, loop(_)), []).

indices_for(sm(_,_, Ptr, Spec), Inds) :-
	Spec = fm_loop(Inds, _);
	Spec = vm_loop(N, _,_,_),
	member(N, [pop, rec]), !,
	    Inds = [ind(Ptr, pop)];	  
	Spec = vm_loop(Count, _,_,_),
	    (Count = 0, !,
		Inds = [];
	    IndCt is Count - 1,
		indices_for(sm(_,_, Ptr, vm_loop(IndCt, _,_,_)), Rest),
		/* Inds = [ind(Ptr, IndCt) | Rest].  for inner first */
		append(Rest, [ind(Ptr, IndCt)], Inds)).

/* might do better to get submodel and use g_a_s to convert */
type_ind(Ind, Type) :-
	var(Ind), !;
	(integer(Ind); Ind = glob(_,_)), Type = int;
	Type = a(Ind).
	
make_choose_form([LastElt], _,_, LastElt) :- !.

make_choose_form([Elt | Elts], Ind, N, choose(Ind==N,Elt,Later)) :-
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
make_all_intermediates([],_,_,_,_, I, _,_,_, [], I, []).

make_all_intermediates([Source | Components], SubId, Target, DestPath,
		       Swaps, PrevInters, BuildingArrays, Step, Used,
		       [Unit | UnitList], NewInters, [Result | ResultList]) :-
	make_intermediates(Source, SubId, Target, 
			   DestPath, Swaps, PrevInters, BuildingArrays, 
			   Step, Used, Unit, NextInters, Result),
	make_all_intermediates(Components, SubId, Target, DestPath, Swaps,
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
	Subexp =.. [Functor | _],
	(member(Functor, [time, dt, rand_var, last]);
		sample(Functor)).

/* do_once is the opposite: value must stay the same even if the args change,
though the modeller has probably erred if they do -- except for init_time,
which is actually the same function as time but this makes sure it is only
evaluated when the model is created.

do_once(_, rand_const(Lo, Hi), rand_var(Lo, Hi), 0).
%do_once(_, init_time(N), ind_time(N), 0).

individuates refers to a function such as rand_const or index, which gives
a different value for each submodel instance in which it is called, and
hence must be called in the destination context. Ind_time(_) is here cos
in a variable membership submodel, instances are initialized at different
times. last(_) similarly? -- even if the args are the same the results are
different if one is brand new and the other not! Some things like randoms
and place_in will also individuate over makearray elements. 

I don't think we've done anything in contexts higher than dest for a while */

individuates(_, Subexp, _, 0) :-
	random(_, Subexp, _,_);
	nonvar(Subexp),
	member(Subexp, [channel_is(_), %ind_time(_),
			index(_), place_in(_), use_inter(_)]).

random(_, Subexp, _, 0) :-
	nonvar(Subexp),
	member(Subexp, [rand(_,_), rand_var(_,_)]).

/* wait_for_submodels/2
This adds the given property of any submodels from which we take values
to the list of things that must be waited for before evaluating a node.
Sure it's trivial now -- used to be tricky when only exotic submodels had
enumerate instructions.  */

wait_for_submodels([], []).

wait_for_submodels([Level | AlsoExited], Waits) :-
	(Level = sm(Model, _,_, vm_loop(_,_,_,_)), !,
	    Waits = [enumerate(Model) | Others];
	Waits = Others),
	wait_for_submodels(AlsoExited, Others).

pointer_from([], this).
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
	(Loop = sm(_,_, Ptr, VLoop),
	\+ VLoop = fm_loop(_,_), !,
	    Dims = [var | RDims],
	    (VLoop = vm_loop(rec, _,_,_), !,
		Inds = [ind(Ptr, pop) | RInds];
	    Inds = [none | RInds]);
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
