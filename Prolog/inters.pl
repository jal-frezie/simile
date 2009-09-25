sicstus_module(inters, [final_assignment/11, make_intermediates/12,
			expand_library/3, macro_expansion/2, function/4,
			promote_unit/2, promote_arg/3, propagate_units/5,
			wait_for_submodels/2, get_dims_from_loops/3, loops/1,
			make_inds_for/3, pointer_from/2]).

sicstus_use_module([library(lists), sp_only, ame_gen, units, utility]).

final_assignment(Expr, Sm, DestRef, Swaps, Step, Used, 
                 NewFormula, Setups, Context, Prereqs, NewInters) :-
	DestRef = elt(DestPathForm, Target, XUnits-Dims),
	copy_term(DestPathForm, DestPath),
	
	catch((replace_subexps(Expr, inters, insert_paths,
		sub(Sm, DestRef, Swaps), top_down, _, FullExp),
		     make_intermediates(FullExp, Sm, [Target], DestPath,
		BackSwap, [], [], Step, Used, Units, AllInters,
		part_result(SourceContext, AllSetups, Args, Formula))), Prob,
		     report(Sm, Prob)),

	get_model_and_loops(SourceContext, DestPath, _, SourceLoops, _),
	append(SourceLoops, DestPath, BaseContext),
	(swap_back(BaseContext, BackSwap, FContext, no_dim), !;
	throw(cannot_make_context(Target, BaseContext, BackSwap))),

	/* If managing units, apply conversion; error message not brilliant but
	only occurs if unit management turned on since entering equation */
	get_dims_from_loops(SourceLoops, _, SourceInds),
	(m_update:use_units_in(Sm, 'Yes'),
	    \+ Units = 1,
	    \+ promote_unit(Units, real),
	    (get_conversion(Formula, Units, XUnits, ScaledF);
		report(Sm, wrong_derived_units(Units))), !;
	ScaledF=Formula),
	/* now check for assignment from an idler. This will be eleminated. */
	(ScaledF = Formula,
	    Formula = arr(_, Idle, SourceInds),
	    Args = [made_at(Idle, _)],
	    \+ assigned_in_vm_subloop(Formula, FContext, AllSetups),
	    select(instance(internal, _,_, Idle, _-Dims),
		   AllInters, NewInters),
	    replace_subexps(AllSetups, inters, swap_vars,
			    switch(Idle, Target), top_down, _, SubbedSetups),
	    select(make(Target, Prereqs, Context, RealStep, NewFormula),
		   SubbedSetups, Setups),
	    % do not de-idle if 1st assign done less often;
	    % could do if step were passed back from here
	    RealStep >= Step, !;
	[Setups, NewInters, Context] =
	[AllSetups, AllInters, FContext],
	    pointer_from(DestPath, DestPtr),
	    get_dims_from_loops(SourceLoops, _, Inds),
	 NewFormula = [assign(arr(DestPtr, Target, Inds), ScaledF)],
	add_extra_dependencies(Context, DestPath, Formula, Args, Prereqs)).

report(Comp, Prob) :-
	find_all_comps(Parent, Comp),
	caption_for(Comp, In),
	caption_for(Parent, Out),
	retractall(error_free(build)),
	(query(conversion_failure(In, Out, Prob), warning, execution,
	      [ok, show_full], ok);
	 replace_subexps(Prob, dialogue, collapse_params,
			 _, top_down, _, TidyProb),
	    query(TidyProb, info, execution, [ok], _)),
	throw(aborted).

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
	    make_inds_for(Dims, LocalLoops, Inds),
	    copy_term(RealPathForm, RealPath),

	    pointer_from(RealPath, SmPtr),
	    (Location = in_hierarchy,
		Wait = true,
		Path = RealPath;
	    member(path_substitution(Base, Assoc, Link), Swaps),
		(Location = in_base,
		    Wait = true,
		    find_name_host(Link, LinkWithAttrs),
		    (\+ m_class:LinkWithAttrs has_attribute can_lookup of 1, !;
			Assoc = [sm(OneSided, _,_,_) | _],
			LookupWait = enumerate(OneSided)),
		    suffix(BaseFrag, Base), /* longest first */
		    append(BaseSide, Top, RealPath),
		    append(Deeper, BaseFrag, BaseSide), !,
		    pointer_from(Top, Ptr),
		    pointer_to(Assoc, Ptr),
		    append([Deeper, Assoc, Top], Path),
		    BackSwap = values_from_base(LookupWait);
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
/* inter all index refs because they become useless if context swapped? Once I
	    figure out how to stop that buggering up base instance lookup...
	Var = index(_), !,
	    NewVar = make_inter(Var, index),
	    Recurse = 0; */
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
	 UseVar =.. [Op | GoodArgs],
	    (MacroMatch = bad_format,
		length(GoodArgs, Arity),
		% e.g., if arg of 'if' has no 'then'
		throw(wrong_format_of_args(Var, Op, Args, GoodArgs));
	    MacroMatch = bad_arity,
		length(GoodArgs, FnArity),
		throw(wrong_no_of_args(Var, Op, Arity, FnArity))));
	Var = prev(N),
	    ((\+ integer(N); N < 0),
		throw(bad_index_number(N, prev));
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
	% in case I ship it after a run
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
	append_atoms([AllDirs, /, *], DeepTpt), % insert start-comment sequence
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
	catch(read_term(Stream, Line, [variable_names(VPrs)]), WrongUDF,
		     make_nice_error_message(WrongUDF, Bug)),
	(nonvar(Bug), !,
	    query(user_fn_misparse(File, Bug), warning, user_defns, [ok], _),
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
	    % Only allow free vars in function template -- fix them all then
	    % replace those in template with free ones
	    % get rid of dummy argument
	    shed_dummy_args(Macro, Fn),
	    (atom(Fn), !,
		Op = Fn,
		NewLine = (Fn --> Defn),
		Pairs = [];
	    Fn =.. [Op | Args],
		replace_subexps(Line, inters, free_params,
				switch(Args, _), top_down, Pairs, NewLine)),
	    (member(var_pair(Param, NewParam), Pairs), NewParam == Param, !,
		query(unused_macro_param(Line, Param), warning, user_defns,
		      [ok], _);
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
	    (File = 'Hidden', Done = More;
		\+ File = 'Hidden', Done = [FnEntry | More]);
	member(Line, [baseline(_,_), unit_definition(_,_), longhand(_,_)]), !,
	    % use asserta so user-supplied definitions override system ones
	    units:asserta(Line),
	    read_funcs(File, Stream, IsBuiltIn, Done);
	query(bad_user_fn_format(File, Line), warning, user_defns, [ok], _),
	    read_funcs(File, Stream, IsBuiltIn, Done)).

shed_dummy_args(Op, NewOp) :-
	Op =.. [Fn | Args],
	    member(Args, [[], ['']]), !,
	    NewOp = Fn;
	NewOp = Op.

free_params(switch(Fixed, Var), Arg, ArgVar, 0) :-
	var(Arg), !; % in case someone used an underscore
	m_update:get_solo_list_depth(Arg, _),
	(nth(N, Fixed, ArgConst),
	    \+ var(ArgConst), % in case some b**** used an underscore
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
    Target, /* The variables we are making, we may have to wait for them before
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
	    remove_physical_units_if_disabled(SubId, SrcUnits, Units),
	    /*(Step = dummy, !,
		Units = OrigUnits;
	    unmake_enum_units(OrigUnits, Units)), !, */

	    (\+ var(Units),
	    member(Units, [n(Type), a(Type)]),
	    \+ ame_gen:resolve_enum_type(_, SubId, _, Units, _), !,
		throw(no_local_defn_for_type(Type, SubId));
		
	    get_dims_from_loops(OrigLoops, Dims, _)),
	    /* get_actual_sizes(SubId, Dims, _,_,_), just a check */
	    get_dims_from_loops(SourceLoops, Dims, _),
			    
	    SourceRef = arr(_, Var, _),
	    SourceLoops = SourceContext,
	    (var(Wait), !,
		/* we are in the argument of last(...) so no need to wait for
		this before using it, just dont do it at init time */
		Args = [time];
	    swap_back(SourceContext, TermSwap, ParamContext, _),
		(TermSwap = values_from_base(LookupWait),
		    nonvar(LookupWait), !,
		    LookupWaits = [LookupWait];
		LookupWaits = []),
		/* a typical parameter: made_at(...) will be linked to it at
		the appropriate looping level in remove_idlers */
	        (([Var | _] = Target; 	% it cannot be a condition of itself,
		  Units == diffs), !,    % or its structure if a compartment
		    Args = LookupWaits;
		Args = [made_at(Var, ParamContext) | LookupWaits])),
	        /* note that for the time being the made_at condition is thrown
	           away */
	    Setups = [],
	    NewInters = PrevInters;
    /* Unable to merge this parameter's execution loop with what went before.
		Make an intermediate variable for it instead. */
	UseRef = arr(_, Var, _),
	    make_intermediates(make_inter(Source, Var), SubId, Target, DestPath,
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
	    MadeDim = new_dim),
% Before cutting, reject dummy arg so default fun handler gives sensible mess
	\+ Epsilon = '', !,

	/* If we are making an explicit intermediate variable then we
	do NOT want it to have a different value each time we go round a loop!
	Or do we...probably yes actually if making it inside a makearray. But
	don't use extra dims if values will all be the same...actually dont
	do it anyway, is just too hard

	5.5 solution: use random, not individuates, because they are
	all in the same submodel instance...no, get more x-plicit...*/
	
	(contains_something(individuates_elements, Source), !,
	    NowBuilding = BuildingArrays;
	NowBuilding = []),
	
	Source =.. [Functor | _],
	Target = [InnerTgt | _],
	(Functor = make_inter, !,
	    UseSource = Ref,
	    sicstus_format_to_chars("~w_for_~a", [Ref, InnerTgt], TotalNameStr);
	UseSource = Source,
	    sicstus_format_to_chars("~a_~a", [InnerTgt, Functor], TotalNameStr)),
	name(TotalNameBase, TotalNameStr),
	generate_name(c, TotalNameBase, TotalName, Used),
	copy_term(DestPath, TotalPath),
	(var(Payload), !,
	    IncrAct = assign(FillRef, IncrExpr),
	    TXUnits = Units,
	    make_intermediates(Epsilon, SubId, [TotalName | Target], TotalPath,
			       SubSwap, PrevInters, NowBuilding, Step, Used,
			       ArgUnits, OldInters,
			       part_result(SubContext, OldSetups,
					   OldArgs, IncrementRef));
	 append_atoms(InnerTgt, '_payload', PayloadNameBase),
	    generate_name(c, PayloadNameBase, PayloadName, Used),
	    IncrAct = cond_assign(arr(TotalPtr, PayloadName, FillInds),
				  IncrementRef, PayloadRef, IncrOp, FillRef),
	    make_all_intermediates([Epsilon, Payload], SubId,
				   [TotalName | Target],
				   TotalPath, SubSwap, PrevInters, NowBuilding,
				   Step, Used, [TXUnits, ArgUnits], OldInters,
				   PLPartResults),
	    (combine_subexp_results(TotalPath, PLPartResults, [],
				   SubContext, OldSetups, OldArgs,
				   [IncrementRef, PayloadRef]), !;
	    throw(cannot_combine_argument_dimensions(Source)))),
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
 	    (break_at_last_loop(SubLoops, TailLoops, SumLoop, ItemLoops);
		Source =.. [Fn, Arg],
		throw(needs_array_or_list(Fn, Arg)));
	TailLoops = SubLoops),

	/* Total must have same dims as one element of its arg,
	so lets work that out... */
	(Functor = count,
	    IncrExpr = FillRef+1,
	    (nonvar(SumLoop), SumLoop = set(_, loop(SourceRef,_)),
		(integer(SourceRef),
		    Units = const_int;
		atom(SourceRef), \+ SourceRef = records,
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
	member(Functor, [with_least, with_greatest]), !,
	    append(NowBuilding, DestPath, ReadyContext),
	    IncrExpr =.. [Functor, Epsilon, Payload], % either arg can vary
	    Units = ArgUnits;
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
	promote_unit(TXUnits, int), !,
	    [Wee, Muckle] = [-268435455, 268435455];
	[Wee, Muckle] = [-1.0e100, 1.0e100]), 

	(\+ (member(Dim, TotalDims),
		member(VarDim, [var, records]),
		Dim == VarDim), !;
	    throw(avoid_var_size_inter(Epsilon, TotalDims))),
	get_dims_from_loops(NowBuilding, BuildDims, BuildInds),
	append(BuildDims, TotalDims, InterDims),
	append(BuildInds, LoopInds, FillInds),
	make_inds_for(TotalDims, SourceLoops, NewInds),
	FillRef = arr(TotalPtr, TotalName, FillInds),
	append(BuildInds, NewInds, SrcInds),
	ClearRef = arr(SourcePtr, TotalName, SrcInds),

	add_extra_dependencies(WriteContext, DestPath, IncrExpr, OldArgs,
			       Depends),
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
	    check if another last(...) has been copied from it
	    Dependencies now put back as target eval may go in advance phase */
	    Setting = [make(lastvalue(TotalName),
			    [made_at(InnerTgt, DestPath), lastvalue(InnerTgt)
			    | Depends],
			    WriteContext, Step, [IncrAct]),
		       make(TotalName, [cleared(TotalName), time],
			    ClearContext, Step, [])];
	    /* If keep_from_reseting, we can remove time from the increment expression's
	    conditions since we need only do it once even though it changes */
	(Functor = at_init, !,
	    SetTime=0, purge(Depends, [time], KeepDeps);	    
	SetTime = Step, 
	    (Functor = count, !,
		purge(Depends, OldArgs, KeepDeps);
	    KeepDeps = Depends)),
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
% start of replacement section
	Inter = instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, TotalName, UseContextUnits-InterDims),
	merge_lists([Inter], OldInters, MidInters),
	(TXUnits = UseContextUnits, !;
	throw(bad_expinter_units(TotalName, TXUnits, UseContextUnits))),
	    (var(Payload), !,
	    WhatMade = TotalName,
	    NewInters = MidInters,
	    FinalInter = Inter;
	Outer = instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, PayloadName, Units-InterDims),
	    WhatMade = PayloadName,
	    merge_lists([Outer], MidInters, NewInters),
	    FinalInter = Outer),
/* end of replacement section, replaced section follows
	Inter = instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, TotalName, TXUnits-InterDims),
	    (var(Payload), !,
	    (Functor = make_inter, !,
		select(instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, TotalName, UseContextUnits-InterDims),
		       OldInters, OtherInters),
		(TXUnits = UseContextUnits, !,
		    NewInters = [Inter | OtherInters];
		    throw(inconsistent_expinter_units(TotalName, TXUnits,
						      UseContextUnits)));
	     NewInters = [Inter | OldInters]),
	    WhatMade = TotalName,
	    FinalInter = Inter;
	Outer = instance(internal, inter(InterContext, _, SourceLoops),
			      UseSource, PayloadName, Units-InterDims),
	    WhatMade = PayloadName,
	    merge_lists([Inter, Outer], OldInters, NewInters),
	    FinalInter = Outer),
*/	refer_inter(FinalInter, DestPath, BuildingArrays,
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
		throw(missing_graph_or_table_data(Source))),
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
	    Target = [InnerTgt | _],
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
	    throw(needs_channel_parameter(ChannelName))),
	    nth(ChannelNum, Used, ChannelVar), !,
	    suffix(ChanPath, DestPath),
	    pointer_from(ChanPath, ChannelPtr),
	    SourceRef = (arr(ChannelPtr, channelId, [])==ChannelNum),
	    Units = boolean),
	    /* re-use of population data structures means values can change
	    if creation counts do */
	    Args = [on_reset];
	(Source =.. [Op, N],
	    name(Op, OpStr),
	    lower(OpStr, LopStr),
	    name(TRef, LopStr),
	    member(TRef, [time, dt]), % ind_time removed
	    ((N=0; N = ''), TArg = Step;
		integer(N), N>=0, TArg = N;
		throw(bad_index_number(N, Op))),
	    SourceRef =.. [TRef, TArg],
	    default_tick_is(OrigUnits),
	    remove_physical_units_if_disabled(SubId, OrigUnits, Units), !;
	Source = keep(SourceRef), !;
	(Source = place_in(IndN), !,
	    reverse(BuildingArrays, BackBA),
	    all(inters, building_dims_and_indices,
	        [build(BackBA), build(DestDims), build(DestInds)]);
	  Source = index(IndN), !,
	    reverse(DestPath, BackDP),
	    all(inters, indices_for,
		[build(BackDP), append(DestInds, []), append(DestDims, [])]),
	    BackSwap = values_from_base(_)), % jam context swap 
	(integer(IndN), !;
	    throw(bad_index_number(IndN, index))),
	    length(DestInds, AvailInds),
	    IndPosn is AvailInds-IndN,
	    (nth0(IndPosn, DestInds, IndRef),
		nth0(IndPosn, DestDims, Units),
		/* (Step = dummy, !,
		    Units = OrigUnits;
		unmake_enum_units(OrigUnits, Units)), */ !;
		throw(index_number_out_of_range(IndN, AvailInds))),
	    (nonvar(IndRef), !;
		/* generate_name(c, loop, LoopName, Used), */
		IndRef = glob(_LoopName, _)),
	    (Units = boolean, !,
		SourceRef = IndRef-1;
	     SourceRef = IndRef)), % first index is 1 in model, 0 in code
	    Args = []),
	SourceContext = DestPath,
	Setups = [],
	NewInters = PrevInters;    

	/* fifth case: a function. Here, we recurse for all the arguments, then
	group them into those which can be evaluated in the same context. If
	there is more than one group, create intermediate variables to hold the
	results of all subexpressions not accessible in the destination
	context. */

	Source =.. [makearray | WrongLen],
	    length(WrongLen, WrongNum),
	    \+ WrongNum = 2,
	    throw(wrong_no_of_args(Source, makearray, WrongNum, 2));
	    % do not leave this to general handler because it will complain
	    % if arguments contain place_in(...)
	(Source = makearray(Element,count(Reps)),
	    fail, % not yet tested enough for release
	    make_intermediates(Reps, SubId, [dum], DestPath,_, PrevInters,
			       BuildingArrays, Step, Used, Dun, MidInters,
			       part_result(Counted, [], _, DimVal)),
	    get_model_and_loops(Counted, DestPath, _, SzLoops, _),
	    suffix([LocalLoop], SzLoops), !,
	    NowBuilding = [LocalLoop | BuildingArrays];
	((Source = makearray(Element, Dim); Source = soloarr(Element), Dim=1),
	    ((catch(DimVal is Dim, _, fail),
	          integer(DimVal), IndxUnits = int;	% it is integer now
	        make_intermediates(Dim, SubId, [dum], DestPath,_, PrevInters,
				   BuildingArrays, Step, Used, Dun, MidInters,
				   part_result([], [], _, DimVal)),
	        promote_unit(Dun, const_int)), !; % will be integer later
		  throw(bad_index_number(Dim, makearray))),
	        (Dun = n(Type),
		    (Type = boolean, IndxUnits = boolean;
			IndxUnits = a(Type));
		    IndxUnits = int), !,
	        NowBuilding = [LocalLoop | BuildingArrays],
	        length(BuildingArrays, BDept),
	        append_atoms(arraybuild, BDept, BuildName),
% added to stop bad rankings behaviour -- may clash with comp names
	        LocalInd = glob(BuildName, _);
	    make_choose_form(Source, keep(LocalInd), 1, Element),
	        length(Source, DimVal),
%	        DimSetups = [],
%	        MidInters = PrevInters,
	        NowBuilding = BuildingArrays,
	        IndxUnits = int), !,
	    ((\+ number(DimVal); DimVal > 1; Source = soloarr(_)), !;
		throw(bad_array_size(Source, DimVal))),
	    LocalLoop = set(LocalInd, loop(DimVal, IndxUnits))),
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
 	    (break_at_last_loop(ALoops, TailLoops,
 	                       set(IntIndxRef, loop(Limit,_)), ItemLoops);
		throw(only_works_on_array(element, Array))),
	    type_ind(Limit, XpectType),
	    (NeedType = XpectType;
	      % bodge: if building code, bounds have been made integer, so
	      % accept boolean or ET as index
	     \+ Step = dummy, member(NeedType, [boolean, a(_ET)]);
		% but if next disjunction fails in both these cases...
	     throw(needs_index_of_type(element, Array, XpectType, Indx, Int))),
	    ((promote_unit(Int, NeedType);
		% special case -- count or name of ET can refer to last elt
	      Int = n(AnET), NeedType = a(AnET)),
		TryIndxRef = IndxRef;
	     promote_arg(Int, real, _),
		promote_arg(NeedType, real, _),
		TryIndxRef = simile_int(IndxRef)), !,% for legacy cases
	    ((NeedType = boolean,
				% first index is 1 in model, 0 in code
	          IntIndxRef = TryIndxRef+1;
	      IntIndxRef = TryIndxRef), !;
	    % only reason this might fail is if taking element of a made array;
	    % too awkward to fix so just say don't be silly
	    throw(redundant_array(Source))),
	    
	    append(ASetups, ISetups, Setups),
	    add_extra_dependencies(IContext, DestPath, IndxRef, IArgs, IWaits),
	    append(AArgs, IWaits, Args),
	    longest_path([ABase, IBase], EltBase),
 	    append(TailLoops, ItemLoops, EltLoops),
 	    special_combine_paths(EltLoops, ILoops, [], ResultLoops),
 	    append(ResultLoops, EltBase, SourceContext);
	
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
		% not sure how to make this happen
		throw(wrong_param_units(Param, UseUnit, DefUnit))),!,
	    append(SubSetups, ExSetups, Setups);	  

	\+ atom(Source),
	    (individuates_instances(_, Source, _, _), !,
		FunctionContext = DestPath;
	    FunctionContext = []),

	    (random(_, Source, _,_), !,
		Args = [on_reset | UseArgs];
	    Args = UseArgs),

/*	    replace_subexps(Source, inters, change_constituent,
			    switch(Source, none, none),
			    top_down, Components, SourceRef), */
            append(_, [TopTgt], Target),
	    nth(GraphId, Used, TopTgt), !,
	    
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
		    throw(missing_graph_or_table_data(Source))),
		SourceList = [Param],
		RUnits = real,
		Arg_template = [real],
		ResultList = [RVal],
		ValRef = graph(GraphId, RVal);
	    Source = stop(ExcpCode), % need to insert line ID
		SourceList = [ExcpCode],
		Arg_template = [int],
		ResultList = [RVal],
		RUnits = int,
		ValRef = stop_on_id(GraphId, RVal);
	    Source =.. [table | SourceList],
	    Step = dummy,
		\+ SourceList = [''], /* let checker handle empty args */
	        (SourceList = [_|_], !;
		throw(only_works_on_array(Source))),
		(dialogue:table_data_is(TableData);
		 throw(missing_graph_or_table_data(Source))),
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
	evaluated, return results based on them. New for 5.5: avoid polluting
	the dest_path with pointer instantiations that break inter building */
	    copy_term(DestPath, GuidePath),
	    (combine_subexp_results(GuidePath, PartResultList, FunctionContext,
				SourceContext, Setups, SubArgs, ResultList), !;
	    throw(cannot_combine_argument_dimensions(Source))),
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
		 (ValRef = sofar(SourceRef);
		     ValRef = default(_), SourceRef = 0),
		    UnitList = [Units];
		 (var(Lop),
		     SourceRef = ValRef;
		  nonvar(Lop),
		     fn_or_op(Lop, MxOp, RUnits, Arg_template),
		     SourceRef =.. [MxOp | ResultList]),
		    /* first, check my units are right... */
		    try_units(RUnits, Arg_template, UnitList, Units);
		 fn_or_op(Lop, _, RUnits, Arg_template),
		    throw(mismatched_units(Lop, Source,
					   UnitList, Arg_template));
		 fn_or_op(Lop, _, RUnits, WrongLen),
		    length(WrongLen, FnArity),
		    throw(wrong_no_of_args(Source, Op,
						     Arity, FnArity));
		 m_class:SubId has_class_refinement uses_local_fns of UserFns,
		    member(Op/Arity, UserFns),
		    throw(lost_user_defined_fn(Source, Op, Arity));
		 throw(no_such_function(Source, Op))),
	    (Source = sofar(_), !,
		all(inters, dissociate, [build(SubArgs), build(UseArgs)]);
	    UseArgs = SubArgs);
	throw(undecipherable_operand(Source, SubId)).

decode_number(Source, SubId, Step, SourceRef, Units) :-
	get_actual_size(SubId, Source, [SrcNum], [SrcType], [SrcUnits]),
	remove_physical_units_if_disabled(SubId, SrcUnits, Units),
	(Step = dummy, !,
	    %Units = OrigUnits,
	    SourceRef = SrcType;
	 %unmake_enum_units(OrigUnits, Units),
	    SourceRef = SrcNum).

remove_physical_units_if_disabled(SubId, SrcUnits, Units) :-
	(m_update:use_units_in(SubId, 'No'),
	    nonvar(SrcUnits),
	    get_conversion(_, SrcUnits, SrcUnits, _), !,
	    Units = 1;
	standard_name(SrcUnits, Units)).
/*
unmake_enum_units(SrcUnits, Units) :-
	SrcUnits = n(Type),
	    \+ Type = boolean,
	    Units = const_int;
	SrcUnits = a(_),
	    Units = int;
	Units = SrcUnits.
*/
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
dissociate(Arg, Arg) :-
	Arg = later(_Cond);	% in case sofars/samesteps are nested
	Arg = enumerate(_Parent). % need this even if not waiting for source
	
refer_inter(instance(internal, inter(_,_, ParamLoops), Source, Name,
		     Units-Dims),
	    DestPath, BuildLoops, Units, SourceContext, Args, SourceRef) :-
	    (Source = last(_), !,
		Args = [Name]; /* bit of a hack...since
	    we use the total from the previous time step we don't need to
	    worry about accessing elements that haven't yet been set, and not
	    using made_at(...) should prevent it being removed as an idler */
	    Args = [made_at(Name, SourceContext)]),
	    copy_term(DestPath, SourcePath),
	    pointer_from(SourcePath, SourcePtr),
	    make_inds_for(Dims, IntLoops, IntInds),
	    copy_term(ParamLoops, SourceLoops),
	    /* order of parts exchanged simply cos it made it work */
	    append(SourceLoops, SpareLoops, IntLoops),
	    suffix(SpareLoops, BuildLoops),
	    append(SourceLoops, SourcePath, SourceContext),
	    SourceRef = arr(SourcePtr, Name, IntInds).

prevent_inappropriate_reuse(Explicit, instance(Type, I, Replaces, Name, Dims),
			    instance(Type, I, NewReplaces, Name, Dims)) :-
	replace_subexps(Replaces, inters, swap_vars, switch(Explicit, gone),
			top_down, [_Swap1 | _], _), !,
	NewReplaces = 'n/a';
	NewReplaces = Replaces.

swap_vars(switch(Take, Add), Tgt, Add, 0) :-
	nonvar(Tgt), Tgt = Take.

/* Adjusted 24/11/07 so it succeeds with unchanged context if the swap cannot
be matched */
swap_back(BaseContext, BackSwap, Context, MadeDim) :-
	nonvar(BackSwap),
	    BackSwap = path_substitution(Base, Assoc, Link),
	    append(Base, Top, BasePath),
	    append(Tail, BasePath, BaseContext),
	    append([Tail, Assoc, Top], Context),
	    (m_update:is_exclusive_role(Link);
		MadeDim = new_dim), !;
	Context = BaseContext.

propagate_units(Source, Lowest, Want, Get, Result) :-
	promote_unit(Lowest, In),
	substitute(Lowest, Want, In, SettleFor),
	try_units(In, SettleFor, Get, Result), !;
	Source =.. [Lop | _],
	throw(mismatched_units(Lop, Source, Get, Want)).
	

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
builtin('Model properties', index, boolean, [int_or_enum_type_const]).
builtin('Model properties', channel_is, boolean, [channel]).
builtin('Model properties', dies_of, boolean, [real]).
builtin('Model properties', dt, real, [const_int_or_none]).
builtin('Model properties', time, real, [const_int_or_none]).
builtin('Model properties', at_init, any, [any]).
builtin('Model properties', default, any, [any]).
%builtin('Model properties', init_time, real, []).
builtin('Model properties', parent, int, []).
builtin('Model properties', stop, int, [int]).
/* legacy versions from before we had empty arg lists */
%builtin('Model properties', time, real, [const_int]).
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
builtin('Arithmetic', abs, int, [int]).
builtin('Arithmetic', abs, real, [real]).
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

builtin('Model properties', following, a(T), [a(T)]).
builtin('Model properties', following, int, [int]).
builtin('Model properties', preceding, a(T), [a(T)]).
builtin('Model properties', preceding, int, [int]).
builtin('Model properties', first, boolean, [a(_T)]).
builtin('Model properties', first, boolean, [int]).

/* These are recognized by the parser but is not part of the equation
language -- they and the operators are hidden */

%operator(ind_time, real, [const_int]).
operator(stage_incr, real, [diffs, int, real]).
operator(loses, boolean, [real, const_int]).
operator(loses, boolean, [boolean, const_int]).
operator(choose, int, [boolean, int, int]).
operator(choose, a(T), [boolean, a(T), a(T)]).
operator(choose, real, [boolean, real, real]).
operator(choose, boolean, [boolean, boolean, boolean]).
operator(remainder, real, [real]).

/* These are handled by the parser but have special buttons to include them so
we do not want them in the function list -- they only appear here so the right
error comes up if they are used with the wrong number of args */

operator(graph, real, [real]).
operator(table, any, ['[index, ...]']).

%operator(if, any, [[then_clause]). Not needed as macro subber flags errors
operator(then, then_clause, [boolean, else_clause]).
operator(else, else_clause, [Any, Any]) :- value(Any).
operator(elseif, else_clause, [Any, then_clause]) :- value(Any).

operator(+, int, [int]).
operator(+, real, [real]).
/* operator(++, int, [int]). */
operator(-, int, [int]).
operator(-, real, [real]).

operator(+, int, [int, int]).
operator(+, real, [real, real]).
operator(-, int, [int, int]).
operator(-, real, [real, real]).
operator(*, const_int, [const_int, const_int]).
operator(*, int, [int, int]).
operator(*, 1, [1,1]).
operator(//, int, [int, int]).
operator(/, const_ratio, [const_int, const_int]).
operator(/, 1, [1,1]).

/* Comparison ops need int arg version to avoid unnecessarily constraining
parameters to real (and because everything does) */
operator(^, real, [real, real]).
operator(is, cond_spec, [int, int]).
operator(==, boolean, [Any, Any]) :- value(Any).
operator('!=', boolean, [Any, Any]) :- value(Any).
operator(<, boolean, [Any, Any]) :- value(Any).
operator(<=, boolean, [Any, Any]) :- value(Any).
operator(>, boolean, [Any, Any]) :- value(Any).
operator(>=, boolean, [Any, Any]) :- value(Any).
operator(<>, boolean, [Any, Any]) :- value(Any).

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
use_tcl_proc_for(loses). % internal function decides loss from probability

value(Any) :-
	member(Any, [boolean, int, real, a(_Enum)]).
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
	    throw(bad_array_size(L, Outer))).

add_zeros(N, SubId, Step, RN, [], U) :-
	decode_number(N, SubId, Step, RN, U).

add_zeros_all([], _,_, [], [0 | _], any).

add_zeros_all([H | T], SubId, Step, [NH | NT], [N | R], U) :-
	add_zeros(H, SubId, Step, NH, R, U1),
	add_zeros_all(T, SubId, Step, NT, [M | RR], UN),
	(R = RR, !;
	    throw(cannot_combine_argument_dimensions([H | T]))),
	propagate_units(list_parts(H,T), any, [any, any], [U1, UN], U),
	N is M+1.

/* Returns expressions for a model's indices, those for outer loops first */
indices_for(set(_, loop(_,_)), [], []).

indices_for(sm(_,_, Ptr, Spec), Inds, Dims) :-
	Spec = fm_loop(Inds, Dims,_);
	Spec = vm_loop(N, Dims,_,_),
	(N == pop, !,
	    Inds = [ind(Ptr, pop)];	  
	 (Dims = [], !,
		Inds = [];
	    Dims = [_Dim | More],
		length(More, IndCt),
		indices_for(sm(_,_, Ptr, vm_loop(N, More,_,_)), Rest, _),
		/* Inds = [ind(Ptr, IndCt) | Rest].  for inner first */
		append(Rest, [ind(Ptr, IndCt)], Inds))).

revert_bound(n(Type), Type) :- !.

/* might do better to get submodel and use g_a_s to convert */
type_ind(Ind, Type) :-
	var(Ind), !; % for self-referencing explicit inter
	(integer(Ind); Ind = glob(_,_);
	    Ind = pop; Ind = records; Ind = pra_bound(_,_)), Type = int;
	Ind = '"boolean"', Type = boolean;
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

special_combine_paths(Datum, Index, Delayed, Joint) :-
	break_at_last_loop(Index, IInside, ILoop, IOutside),
	break_at_last_loop(Datum, DInside, DLoop, DOutside), !,
	    DLoop = ILoop,
	    append(DOutside, Delayed, AllDelayed),
 	    special_combine_paths(DInside, IInside, AllDelayed, InJoint),
	    append(InJoint, [ILoop | IOutside], Joint);
	append([Datum, Delayed, Index], Joint).
	
break_at_last_loop(SubLoops, TailLoops, SumLoop, ItemLoops) :-
	append(TailLoops, [SumLoop | ItemLoops], SubLoops),
	loops(SumLoop),
	\+ (member(OtherLoop, ItemLoops), loops(OtherLoop)).

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

add_extra_dependencies(OldCon, NewCon, Source, VarList, FullList) :-
/* Now if I come out of any generated submodels, add a dependency on the generator
function...similarly a dependemcy on time for any population submodels */

        (setof(Sm, has_extras(OldCon, NewCon, Sm), Exited); Exited = []),
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
	(member(Functor, [time, dt, rand_var, last, loses]);
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

individuates_instances(_, Subexp, _, 0) :-
	individuates_elements(_, Subexp, _,_);
	nonvar(Subexp),
	member(Subexp, [channel_is(_), at_init(_), index(_)]).

individuates_elements(_, Subexp, _, 0) :-
	random(_, Subexp, _,_);
	nonvar(Subexp),
	member(Subexp, [place_in(_), use_inter(_)]).

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
	(member(Level, [sm(Model, _,_, vm_loop(_,_,_,_)), % variable membership
			set(_, loop(pra_bound(_, Model), _))]), !, % by record
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
	Level = set(Ind, loop(Bound,_))),
	make_inds_for(RB, RX, RI),
	append(RX, [Level], Sets).
	    
get_dims_from_loops([], [], []).

get_dims_from_loops(Loops, Dims, Inds) :-
	append(InnerLoops, [Loop], Loops),
	(Loop = sm(_,_,_, VLoop),
	\+ VLoop = fm_loop(_,_,_), !,
	    Dims = [var | RDims],
	    Inds = [none | RInds];
	Loop = set(Ind, loop(Dim,_)), !,
	    Dims = [Dim | RDims],
	    Inds = [Ind | RInds];
	Dims = RDims,
	    Inds = RInds),
	get_dims_from_loops(InnerLoops, RDims, RInds).

building_dims_and_indices(set(I, loop(_,L)), L, I).

loops(set(_, loop(_,_))).
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
