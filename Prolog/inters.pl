sicstus_module(inters, [final_assignment/12, make_intermediates/12,
			expand_library/2,
			macro_expansion/2, fragment_expansion/5, function/4,
			promote_unit/2, promote_arg/3, propagate_units/5,
			wait_for_submodels/2, get_dims_from_loops/3, loops/1,
			inherently_bound/1, make_inds_for/3, pointer_from/2,
			with_capt/3]).

sicstus_use_module([library(lists), sp_only, ame_gen, units, utility]).

final_assignment(Expr, Sm, DestRef, Swaps, SmStep, Step, Used, 
                 NewFormula, Setups, Context, Prereqs, NewInters) :-
	DestRef = elt(DestPathForm, Target, XUnits-Dims),
	copy_term(DestPathForm, DestPath),
	
	catch((replace_subexps(Expr, inters, insert_paths,
			       sub(Sm, DestRef, Swaps, SmStep),
			       top_down, _, FullExp),
	       make_intermediates(FullExp, Sm, [Target], DestPath, BackSwap,
				  [], [], Step, Used, Units, AllInters,
				  part_result(SourceContext, AllSetups, Args,
					      Formula))), Prob,
		     report(Sm, Prob)),

	get_model_and_loops(SourceContext, DestPath, _, SourceLoops, _),
	append(SourceLoops, DestPath, BaseContext),
	(swap_back(BaseContext, BackSwap, FContext, no_dim), !;
	throw(cannot_make_context(Target, BaseContext, BackSwap))),

	/* If managing units, apply conversion; error message not brilliant but
	only occurs if unit management turned on since entering equation */
	get_dims_from_loops(SourceLoops, _, SourceInds),
	(m_update'><'use_units_in(Sm, 'Yes'),
	    \+ Units = 1,
	    \+ promote_unit(Units, real),
	    \+ promote_unit(Units, XUnits),
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

insert_paths(sub(Sm, DestRef, Swaps, Step), Var, NewVar, Recurse) :-
	(Var = input(Location, PathExp, Link, Units),
	    m_update'><'analyze_array(Units, Type, _);
	Var = PathExp,
	    /* from compartment expressions -- used? -- and dest ref */
	    [Location, Link, Type]=[in_hierarchy, none, SourceType]),
	PathExp = elt(RealPathForm, Ref, SourceType-DimTypes), !,
	    all(ame_gen, enum_type_ref, [build(DimTypes), unify(Sm),
					 build(Dims), build(_), build(_)]),
	    make_inds_for(Dims, LocalLoops, Inds),
	    copy_term(RealPathForm, RealPath),

	    pointer_from(RealPath, SmPtr),
	    (Link = none,
		Wait = true,
		Path = RealPath;
	    member(path_substitution(Base, Assoc, Link), Swaps),
		(Location = in_base,
		    Wait = true,
/* precaution removed because it only works when getting stuff from looked-up
		    model, actually you cannot get stuff from elsewhere in
		assoc model either, and it caused...shall we say...difficulties
		when the condition was not actually a lookup
		    find_name_host(Link, LinkWithAttrs),
		    (\+ m_class'><'LinkWithAttrs has_attribute can_lookup of 1, !;
			Assoc = [sm(OneSided, _,_,_) | _],
			LookupWait = enumerate(OneSided)),  */
		    suffix(BaseFrag, Base), /* longest first */
		    append(BaseSide, Top, RealPath),
		    append(Deeper, BaseFrag, BaseSide), !,
		    pointer_from(Top, Ptr),
		    pointer_to(Assoc, Ptr),
		    append([Deeper, Assoc, Top], Path),
		    BackSwap = values_from_base(_LookupWait);
		Location = in_assoc,
		    Wait = true,
		    append(Assoc, Top, AssocPath),
		    append(Deeper, AssocPath, RealPath),
		    append([Deeper, Base, Top], Path),
		    BackSwap = path_substitution(Base, Assoc, Link))),
	    append(LocalLoops, Path, Loops),
	    NewVar = param(arr(SmPtr, Ref, Inds), Type, Loops, BackSwap, Wait),
	    Recurse = 0;
%	m_update'><'get_solo_list_depth(Var, DimExp),
%	    m_update'><'build_array(any, Dims, DimExp),
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
	Var = dies_of(input(Location, PathExp, Link, Units)), !,
	% Reference already moved to spare node by instance_of, just need to
	% fix units now
	    NewVar = input(Location, PathExp, Link, boolean),
	    Recurse = 1;
	Var =.. [TimeFn, TimeArg],
	    member(TimeFn, [time, dt]), member(TimeArg, [0, '']), !,
	    NewVar =.. [TimeFn, Step], % do here rather than pass sm time to m_i
	    Recurse = 0;
	Var = prev(N),
	    (N < 1,
		NewVar = DestRef;
	    M is N-1,
		NewVar = last(prev(M))), !,
	    Recurse = 1.

:- dynamic(macro_expansion/2).
:- dynamic(fragment_expansion/5).

expand_library(Var, NewVar) :-
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
		throw(wrong_no_of_args(Var, Op, Arity, FnArity)))).	  
	/* These have just been moved to macro_expansions so if statements can
	    be used in other macros
	do_once(_, Var, ToDo, _),
	    NewVar = keep_from_reset(ToDo).
	Var = (if Bool then IfCl), !,
	    NewVar = (Bool?IfCl);
	Var = (ThenCl else ElseCl), !,
	    NewVar = (ThenCl'><'ElseCl);
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
%					       (Bool?ThenCl'><'ElseCl)))),
	read_func_tree('../Functions/', '../Functions', 'Built-in', BuiltIns),

	backup'><'use_pref_dir(UserStuff),
	append_atoms(UserStuff, '/Functions/', UserFns),
	read_func_tree(UserFns, UserFns, 'Local', Local),
	append(BuiltIns, Local, Done).

read_func_tree(TopDir, AllDirs, BuiltIn, Done) :-
	name(AllDirs, AllDirsStr),
	    (suffix(".pl", AllDirsStr),
		read_func_file(AllDirs, TopDir, BuiltIn, Done);
	      suffix(".sml", AllDirsStr),
		load_fragment_macro(AllDirs, TopDir, BuiltIn, Done)), !;
	append_atoms([AllDirs, /, *], DeepTpt), % avoid start-comment sequence
	    output'><'list_matching_files(DeepTpt, DeepDirs),
	    all(inters, read_func_tree, [unify(TopDir), build(DeepDirs),
					 unify(BuiltIn), append(Done, [])]).

load_fragment_macro(AllDirs, Context, Category, [FnEntry]) :-
	name(AllDirs, AllDirsStr),
	append(Rootname, ".sml", AllDirsStr),
 	% parse the file name for metatdata
	[Sl, Cm, Pt] = "/,.",
	split_into_list(Rootname, Sl, Levels),
	suffix([Tail], Levels),

	% create relative path for listings
	name(Context, ContextStr),
	append(ContextStr, RelFile, Rootname),
	append(Nesting, [Sl | Tail], RelFile),

	split_into_list(Tail, Cm, [FunctorStr, Returns | Args]),
	name(Functor, FunctorStr),
	split_into_list(Returns, Pt, [OutNodeStr | OutHooks]),
	name(OutNode, OutNodeStr),
	( % first case: output field and therefore arg fields have suffixes
	  % giving units etc e.g., recipro,recip.r,value.r.sml
	all(inters, match_to_pl_vars,
	     [build(OutHooks), unify(V),
	      build([OutGT | _]), build([_OutURef | _OutDimRefs])]), !,
	    all(inters, split_into_list, [build(Args), unify(Pt),
					  build(Splists)]),
	    all(inters, convert_formal_params,
		[build(Splists), unify(V), build(Params), build(ArgTypes)]),
				% export guide types
	    dialogue'><'make_arg_list(ArgTypes, String),
	    sicstus_format_to_chars("{~a {~s}} fragment ~a (~s) returns ~a",
				    [Category, Nesting, Functor, String, OutGT],
				    FnChars);
	  % 2nd case: only names included e.g., recipro,recip,value.sml
	    all(user, name, [build(Params), build(Args)]),
	    sicstus_format_to_chars("{~a {~s}} fragment ~a",
				    [Category, Nesting, Functor],
				    FnChars)),
	    
	name(FnEntry, FnChars),
%	m_update'><'make_blind_toplevel(AllDirs, TopLevel), 
	assert(fragment_expansion(Category, AllDirs, Functor, OutNode, Params)).

split_into_list(Joined, Link, Separated) :-
	append(One, [Link | Many], Joined), !,
	split_into_list(Many, Link, Multi),
	Separated = [One | Multi];
	Separated = [Joined].

match_to_pl_vars(GridRef, Map, GuideType, Tile) :-
	nth0(Y, "abinr", Row),
		nth0(Y, [all, boolean, int, ordinal, real], GuideType),
	append([Row], Col, GridRef),
	(Col = [], !; % no digit means type unconnected with others
	  name(X, Col),  % deprecated for numbers but cross platform
	    nth0(Y, Map, RowVars),
	    nth0(X, RowVars, Tile)).

convert_formal_params([VPNameStr | GRs], V, VPName, VPType) :-
	name(VPName, VPNameStr),
	all(inters, match_to_pl_vars,
	[build(GRs), unify(V), build([VPType | _]), build([_UTile | _DTiles])]).
					     
read_func_file(File, Context, BuiltIn, Done) :-
	open_native(File, read, Stream),
	swallow_to_chars(Stream, U8Contents),
	tcltk'><'all_utf8_to_ttfn(U8Contents, Contents),
	ame_gen'><'make_legible_for_prolog(Contents, EuContents),
	state'><'use_temp_dir(TempDir),
	append_atoms(TempDir, '/temp_io.pl', TempFile),
	open_native(TempFile, write, Stream2),
	sicstus_write_chars(Stream2, EuContents),
	close(Stream2),
	
	name(File, FileStr),
	append(Base, ".pl", FileStr),
	name(Context, ContextStr),
	append(ContextStr, NameStr, Base),
	name(Name, NameStr),
	open_native(TempFile, read, Stream3),
	read_funcs(Name, Stream3, EuContents, BuiltIn, Done),
	output'><'my_delete_file(TempFile).

swallow_to_chars(Stream, Contents) :-
	get_code(Stream, C),
	(C = -1, !,
	    close(Stream),
	    Contents = [];
	  swallow_to_chars(Stream, Tail),
	    Contents = [C | Tail]).

read_funcs(File, Stream, Text, Category, Done) :-
	catch(read_term(Stream, Line, [variable_names(VPrs)]), WrongUDF,
		     make_nice_error_message(Text, WrongUDF, Bug)),
	(nonvar(Bug), !,
	    query(user_fn_misparse(File, Bug), warning, user_defns, [ok], _),
	    read_funcs(File, Stream, Text, Category, Done);
	 Line == end_of_file, !,
	    close(Stream),
	    Done = [];
	all(user, call, [build(VPrs)]),
	(Line = (Macro --> Defn),
	    add_macro(Category, Macro=Defn, Op),
	    append_atoms(['{', Category, ' {', File, '}} ', macro, ' ', Op],
			 FnEntry);
	(Line = sample(Functor, ReturnType, ArgTypes),
	        assert(sample(Functor));
	 Line = function(Functor, ReturnType, ArgTypes)),
	    assert(function(Category, Functor, ReturnType, ArgTypes)),
	    assert(use_tcl_proc_for(Functor)), !,
	    dialogue'><'spell_out([ReturnType | ArgTypes], 1),
	    dialogue'><'make_arg_list(ArgTypes, String),
	    sicstus_format_to_chars("{~a {~a}} procedure ~a (~s) returns ~w",
		[Category, File, Functor, String, ReturnType], FnChars),
	    name(FnEntry, FnChars)),
	    read_funcs(File, Stream, Text, Category, More),
	    (File = 'Hidden', Done = More;
		\+ File = 'Hidden', Done = [FnEntry | More]);
	member(Line, [baseline(_,_), unit_definition(_,_), longhand(_,_)]), !,
	    % use asserta so user-supplied definitions override system ones
	    units'><'asserta(Line),
	    read_funcs(File, Stream, Text, Category, Done);
	  Line =.. [LFunctor | LArgs],
	    query(bad_user_fn_format(File, Line, LFunctor, LArgs), warning,
		  user_defns, [ok], _),
	    read_funcs(File, Stream, Text, Category, Done)).

add_macro(Category, Macro=Defn, Op) :-
	% Only allow free vars in function template -- fix them all then
	% replace those in template with free ones
	% get rid of dummy argument
	shed_dummy_args(Macro, Fn),
	(atom(Fn), !,
	    Op = Fn,
	    NewLine = (Fn --> Defn),
	    Pairs = [];
	  Fn =.. [Op | Args],
	    Line = (Macro --> Defn),
	    replace_subexps(Line, inters, free_params,
			    switch(Args, _), top_down, Pairs, NewLine)),
	(member(var_pair(Param, NewParam), Pairs), NewParam == Param, !,
	    query(unused_macro_param(Line, Param), warning, user_defns,
		  [ok], _);
	  assert(macro_expansion(Category, NewLine))).

shed_dummy_args(Op, NewOp) :-
	Op =.. [Fn | Args],
	    member(Args, [[], ['']]), !,
	    NewOp = Fn;
	NewOp = Op.

free_params(switch(Fixed, Var), Arg, ArgVar, 0) :-
	var(Arg), !; % in case someone used an underscore
	m_update'><'get_solo_list_depth(Arg, _),
	(nth(N, Fixed, ArgConst),
	    \+ var(ArgConst), % in case some b**** used an underscore
	    Arg = ArgConst,
	    nth(N, Var, ArgVar);
	ArgVar = Arg).

/*
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

make_intermediates: This introduces variables for any intermediate results
required while evaluating a variable. The process is explained in great detail
in exec_contexts.txt. Meantime, here is the list of arguments: */

make_intermediates(
    Source, /* representation of the formula we are trying to evaluate */
    SubId, /* Id of expression, needed for evaluating enumerated types */
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
		  instructions generated. 'dummy' if just checking syntax */
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
	/* Source = make_inter(Payload, Ref); */
	% make_inter functor should force us to make one
	Inter = instance(internal,_, Source, _,_),
	member(Inter, PrevInters),
	\+ contains_something(random, Source, _), !,
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
	    \+ ame_gen'><'resolve_enum_type(_, SubId, _, Units, _), !,
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
	member(Source, [make_inter(Epsilon, Ref), at_phase(Ph, Epsilon),
			at_phase(Epsilon), last(Epsilon), 
			in_preceding(Epsilon), in_progenitor(Epsilon),
			exists(Epsilon)]),
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
	
	(contains_something(individuates_elements, Source, PrevInters), !,
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
	(member(Functor, [in_preceding]), !,
	    trim_one_multi_instance(DestPath, InterPath),
	    copy_term(InterPath, OuterPath), % Use to read stuff out
	    append(Exited, OuterPath, TotalPath);
	InterPath = DestPath,
	    OuterPath = TotalPath),
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
	    make_subexps([Epsilon, Payload], SubId,
				   [TotalName | Target],
				   TotalPath, SubSwap, PrevInters, NowBuilding,
				   Step, Used, [TXUnits, ArgUnits], OldInters,
				   _, [], SubContext, OldSetups, OldArgs,
				   [IncrementRef, PayloadRef])),
	get_model_and_loops(SubContext, TotalPath, _, SubLoops, _),

	/* choose a location for Total where it will be visible in the
	destination path .... need to make sure it does not contain any
	of the pointer references from the source */
	swap_back(TotalPath, SubSwap, WritePath, MadeDim),
	append([SubLoops, NowBuilding, WritePath], WriteContext),

	pointer_from(OuterPath, TotalPtr),
	pointer_from(InterPath, SourcePtr),

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
	member(Functor, [make_inter, last, 
			 in_preceding, in_progenitor, at_phase]), !,
	    InitVal = 0,
	    IncrExpr = IncrementRef,
	    (UseSource = trigger_magnitude('') ->
		units_for_trigger_mag(SubId, Units-_RefDims);
	      Units = ArgUnits),
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
	append(SourceLoops, InterPath, InterContext),
	append([SourceLoops, NowBuilding, InterPath], ClearContext),

	(UsingDim == true, !,
	    Setups = OldSetups, /* So, we are just using a number, but we might
	have made inters that we will use elsewhere */
	    Args = [],
	    NewInters = OldInters;
	((Functor = at_phase; Functor = make_inter), !,
	    Clearing = [];
	member(Functor-ClearTime,
	       [last-on_reset, in_preceding-this_step(WhatMade)]), !,
	    % clearing will be promoted to chosen step
            Clearing = [make(cleared(TotalName), [ClearTime], ClearContext,
                             Step, [assign(ClearRef, InitVal)])];
	Functor = in_progenitor, % check for null pointer rather than clear
% also good place to check we are in a pop
	    (find_all_comps(ParentId, SubId),
		is_population(ParentId), !;
		throw(misplaced_progenitor_ref(Source))),
            ClearTime = on_reset, % harmless value (I hope)
	    Clearing = [make(cleared(TotalName), [], [], Step, [])];
        Clearing = [make(clearing(TotalName), [this_step(WhatMade)],
			 ClearContext, Step, [assign(ClearRef, InitVal)]),
		    make(cleared(TotalName), [clearing(TotalName)],
			 ReadyContext, Step, [])]),
	(Functor= last, !,
	    /* we can update the saved value as soon as it has been used,
	    but we need to wait for all the goals that might use it...started
	    Setting = [make(increment(TotalName),
			    [Target, increment(Target) | Depends])],
	    but now goes in update phase before compartments so only needs to
	    check if another last(...) has been copied from it
	    Dependencies now put back as target eval may go in advance phase */
	    Setting = [make(lastvalue(TotalName),
			    [made_at(InnerTgt, SourceContext),
			     lastvalue(InnerTgt) | Depends],
			    WriteContext, Step, [IncrAct]),
		       make(TotalName, [cleared(TotalName), time],
			    ClearContext, Step, [])];
	member(Functor, [in_preceding, in_progenitor]), !,
	    wait_for_submodels(Exited, Access),
	    Setting = [make(lastvalue(TotalName),
			    [ClearTime,InnerTgt,lastvalue(InnerTgt) | Depends],
			    WriteContext, Step, [IncrAct]),
		       make(TotalName,
			    [cleared(TotalName), this_step(InnerTgt) | Access],
			    ClearContext, Step, [])];
	    /* If keep_from_reseting, we can remove time from the increment expression's
	    conditions since we need only do it once even though it changes */
	(Functor = at_phase,
	    (var(Ph), SetTime = Step; SetTime=Ph), !,
	    KeepDeps = [on_step | Depends]; % on_step forces time to be step
	SetTime = Step, 
	    (Functor = count, !,
		purge(Depends, OldArgs, KeepDeps);
	    KeepDeps = Depends)),
        (member(Functor, [make_inter, at_phase /*, last, 
			  in_preceding, in_progenitor */]), !,
 	    % commented-out cases handled in other clauses!
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
	Inter = instance(internal, inter(InterContext, InnerTgt, SourceLoops),
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
	    (m_class'><'SubId has_class_refinement table_data of TableData;
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

	((Source = channel_is(ChannelName), !,
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
	Source = is_new_instance(_), !,
	    (suffix([sm(_, _, Ptr, vm_loop(_,_,_,_)) | _], DestPath), !,
		SourceRef = is_new_instance(Ptr);
	      SourceRef = (phase<=0)),
	    Units = boolean,
	    Args = [on_step];
	(Source =.. [Op, N],
	    name(Op, OpStr),
	    lower(OpStr, LopStr),
	    name(TRef, LopStr),
	    member(TRef, [time, dt]), % ind_time removed
	    ((N=0; N = ''), TArg = Step;
		% now done in insert_paths so only needed here for parsing
		integer(N), N>=0, N<8, TArg = N;
		throw(bad_index_number(N, Op, 8))),
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
	    throw(bad_index_number(IndN, index, 32))),
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
	    ((catch(DimNum is float(Dim), _, fail),
	          DimVal is round(DimNum), %allow idx to be float if = to an int
	          DimNum is float(DimVal),
	          IndxUnits = int;	% it is integer now
	        make_intermediates(Dim, SubId, [dum], DestPath,_, PrevInters,
				   BuildingArrays, Step, Used, Dun, MidInters,
				   part_result([], [], _, DimVal)),
	        promote_unit(Dun, const_int)), !; % will be integer later
		  throw(bad_index_number(Dim, makearray, 16777215))),
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

/* This should work like current version of statearray(), i.e.,
   generate an inter that should get pruned as an idler in typical use
   cases, thus not need separate signalling of result dimensions --
   but might be different for explicit state arrays

	    Source = tweakarray(Element, Dim, Indx), !,
	    make_intermediates(Indx, SubId, Target, DestPath, BackSwap,
			PrevInters, BuildingArrays, Step, Used, Int, MidInters,
			part_result(IContext, ISetups, IArgs, IndxRef)),
	    make_intermediates(Element, SubId, Target, DestPath, BackSwap,
			MidInters, BuildingArrays, Step,
			Used, Units, NewInters,
			part_result(AContext, ASetups, AArgs, SourceRef)),
	    combine_contexts(IContext, AContext, DestPath, SourceContext),
	    TgtDims = [dest_index(IndxRef,Dim)],
	    append(ASetups, ISetups, Setups),
	    add_extra_dependencies(IContext, DestPath, IndxRef, IArgs, IWaits),
	    append(AArgs, IWaits, Args);
	    
Original version that put a separate initialization instruction in step 0
	Source = statearray(Element, Dim, Indx, Init), !,
	    make_intermediates(Init, SubId, Target, DestPath, BackSwap,
		    PrevInters, BuildingArrays, Step, Used, Int, MidInters,
		    part_result(IContext, ISetups, IArgs, InitRef)),
	    pointer_from(DestPath, DestPtr),
	    ILoop = set(_, loop(Dim, _)),
	    combine_contexts(IContext, [ILoop | DestPath], DestPath, IDContext),
	    get_dims_from_loops([ILoop], _, IInds),
	    Target = [TopTgt],	% should only work if single
	    DoInit = make(init(TopTgt), IArgs, IDContext, 0,
			  [assign(arr(DestPtr, TopTgt, IInds), InitRef)]),
	    make_intermediates(tweakarray(Element, Dim, Indx), SubId, Target,
			   DestPath, BackSwap, MidInters, BuildingArrays, Step,
			   Used, Units, NewInters,
			   part_result(SourceContext, TgtDims, ASetups, AArgs,
				       SourceRef)),
	    append([DoInit | ASetups], ISetups, Setups),
	    append([init(TopTgt) | AArgs], IArgs, Args);

New version that creates an inter with a special super-instruction
        Source = statearray(Action, Single, Multi), !,
	    % get stuff to make all values
	    make_intermediates(Multi, SubId, Target, DestPath, BackSwap,
		    PrevInters, BuildingArrays, Step, Used, MUnits, MInters,
		    part_result(MContext, MSetups, MArgs, MRef)),
	    % MContext will have a possibly-submodel loop

Now one that uses a special conditional level */
        Source = statearray(Action, Single, Multi), !,
	    generate_name(prolog, state, InterRef, Used),
	    make_intermediates(make_inter(Multi, InterRef),
			       SubId, Target, DestPath, BackSwap,
		    PrevInters, BuildingArrays, Step, Used, Int, MidInters,
		    part_result(SourceContext, FullSetups, Args, SourceRef)),
	    member(AuntSally, MidInters),
	    AuntSally = instance(internal, _, InterRef, InterEfct, _-[Size|_]),
	    make_intermediates(Action, SubId, Target, DestPath, BackSwap,
		    MidInters, BuildingArrays, Step, Used, AUnits, LateInters,
		    part_result(AContext, ASetups, AArgs, ARef)),
	    get_model_and_loops(AContext, DestPath, _, [], _),
	    
	    all(inters, add_condition_to_context,
		[build(FullSetups),
		 unify([AContext, [poked(InterEfct) | AArgs], ARef==0]),
		 build(CondSetups)]),
	    make_intermediates(Single, SubId, Target, DestPath, BackSwap,
			LateInters, BuildingArrays, Step,
			Used, SUnits, NewInters,
			part_result(SContext, SSetups, SArgs, SRef)),
	    pointer_from(DestPath, Ptr),
	    PartSetups = [make(poked(InterEfct), SArgs, SContext, Step,
			       [assign(arr(Ptr, InterEfct, [ARef]), SRef)]) | SSetups],
	    value(Any),
	    try_units(Any, [Any, Any], [AUnits, SUnits], Units),
	    all(inters, add_condition_to_context,
		[build(PartSetups), unify([SContext, AArgs,
					   ARef>0 and ARef<=Size]),
		 build(NotCondSetups)]),
	    append([ASetups, CondSetups, NotCondSetups], Setups);
	    
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
	     promote_arg(Int, 1, _),
		promote_arg(NeedType, 1, _),
		TryIndxRef = simile_int(IndxRef)), !,% for legacy cases
	    ((NeedType = boolean,
				% first index is 1 in model, 0 in code
	          UseIndxRef = TryIndxRef+1;
	      UseIndxRef = TryIndxRef),
		member(IntIndxRef, [UseIndxRef, glob(_, UseIndxRef)]), !;
	    % only reason this might fail is if taking element of a made array;
	    % too awkward to fix so just say don't be silly
	    throw(redundant_array(Source))),
	    
	    append(ASetups, ISetups, Setups),
	    add_extra_dependencies(IContext, DestPath, IndxRef, IArgs, IWaits),
	    append(AArgs, IWaits, Args),
	    longest_path([ABase, IBase], EltBase),
 	    append(TailLoops, ItemLoops, EltLoops),
 	    (special_combine_paths(EltLoops, ILoops, [], ResultLoops), !;
		throw(cannot_combine_argument_dimensions(Source))),
 	    append(ResultLoops, EltBase, SourceContext);
	
	Source = (Param=SubExp,Rest), !,
	    (Param = param(arr(_, Ref, _), UseUnit, LoopSlot,_,_), !;
		/* parsing */
	    Param = Ref,
%		member(instance(internal, inter(_,_, Loops), Param,_, _-Dims),
%		       PrevInters),
		(Ref = trigger_magnitude(_), !,
		    units_for_trigger_mag(SubId, _RefUnits-RefDims);
		  m_update'><'get_solo_list_depth(Ref, DimExp),
		    m_update'><'analyze_array(DimExp, any, RefDims)),
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
	    (nonvar(UseUnit), !;
		promote_unit(DefUnit, UseUnit),
	      \+ member(UseUnit, [const_int, const_ratio])),
		% variables cannot have constant units even if constant
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

	Source = ready(ToDoFirst), % keep deps but return TRUE
	    replace_subexps(ToDoFirst, inters, just_inputs, Args, _,_,_),
	    length(Args, _L), !,
	    Units = int,
	    NewInters = [],
	    SourceContext = [],
	    Setups = [],
	    SourceRef = 1;

	Source = trigger_magnitude(_),
	Step = dummy, !, % is always explicit inter when building code
	    units_for_trigger_mag(SubId, Units-Dims),
	    NewInters = [],
	    make_inds_for(Dims, SourceContext, _),
	    Setups = [],
	    SourceRef = 1;

	\+ atom(Source),
	    (individuates_instances(_, Source, _, _), !,
		FunctionContext = DestPath;
	    FunctionContext = []),

/*
	    Can't see what this next bit was for; what has randomness got to
	    do with on_reset? a_x_d adds time to conds of all changeables anyway

	    (random(_, Source, _,_), !,
		Args = [on_reset | UseArgs];
	    Args = UseArgs),

	    replace_subexps(Source, inters, change_constituent,
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
%	    Source = (Test?True'><'False), !,
%		SourceList = [Test, True, False],
%		RUnits = any,
%	        Arg_template = [boolean, RUnits, RUnits],
%		ResultList = [RTest, RTrue, RFalse],
%		ValRef = (RTest?RTrue'><'RFalse);
	    Source = graph(Param), \+ Param = '',
		(\+ Step = dummy;
		dialogue'><'table_data_is(_);
		    throw(missing_graph_or_table_data(Source))),
		SourceList = [Param],
		RUnits = 1,
		Arg_template = [1],
		ResultList = [RVal],
		ValRef = graph(GraphId, RVal);
	    Source = stop(ExcpCode), % need to insert line ID
		SourceList = [ExcpCode],
		Arg_template = [int],
		ResultList = [RVal],
		RUnits = int,
		ValRef = stop_on_id(GraphId, RVal);
	    Source = stage_incr(Diffs, Step, Change, Span), % same again
		SourceList = [Diffs, Change],
		Arg_template = [diffs, real],
		ResultList = [RDiffs, RChange],
		RUnits = real,
		ValRef = stage_incr(RDiffs, Step, RChange, Span, GraphId);
	    Source = check_limit(ActEqn, Lower, Upper, Flags, Step, Diffs),
		SourceList = [ActEqn, Diffs],
		Arg_template = [real, diffs],
		ResultList = [RActEqn, RDiffs],
		RUnits = int,
		ValRef = check_limit(RActEqn, Lower, Upper, Flags, GraphId,
				     Step, RDiffs);
	    Source =.. [table | SourceList],
	    Step = dummy,
		\+ SourceList = [''], /* let checker handle empty args */
	        (SourceList = [_|_], !;
		throw(only_works_on_array(Source))),
		(dialogue'><'table_data_is(TableData);
		 throw(missing_graph_or_table_data(Source))),
		member(units=RUnits, TableData),
		member(bounds=Arg_template, TableData),
		ValRef = table(ResultList);
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
		ValRef =.. [Lop | ResultList],
		((length(ArgTpts, Arity); WrongArity = 1),
		    fragment_expansion(_, FragFile, Lop, FragOut, ArgTpts),
		    (WrongArity = 0;
			length(ArgTpts, FnArity),
			throw(wrong_no_of_args(Source, Op, Arity, FnArity))), !,
				% (fragment-defined function:),
		    m_update'><'make_blind_level(SubId, FragFile, RefNode);
		  true)),
	    (\+ RefNode = SubId; RefNode = SubId), % = in other cases
	    make_subexps(SourceList, RefNode, Target, DestPath,
	                 BackSwap, PrevInters, BuildingArrays, Step,
			 Used, UnitList, NewInters,
			 ArgTpts, FunctionContext, ExecContext,
			 Setups, SubArgs, ResultList),
	    (nonvar(FragOut), !, % fragment-defined function: parsing, since
		% these are replaced in instantiation during code build
		SourceRef = FragOut, % placeholder
		with_capt(OutNode, RefNode, FragOut),
		m_update'><'get_av_pair(OutNode, 0, units, OutArrSpec),
		m_update'><'analyze_array(OutArrSpec, Units, OutDims),
		make_inds_for(OutDims, OutLoops, _),
		get_model_and_loops(ExecContext, DestPath, _,
				    ExecLoops, ExecBase),
		append(ExecLoops, BuildingArrays, FragLoops),
		get_dims_from_loops(FragLoops, ExecDims, _),
		m_update'><'add_parameter(RefNode, 0, multiplication_spec,
					  [count=ExecDims]),
		append([ExecLoops, OutLoops, ExecBase], SourceContext);
	      SourceContext = ExecContext),
		       
	    (nonvar(FragOut), !; % units and sourceref done
	      ValRef =.. [Lop, _, _],
		member(Lop, [*, /]),
		    \+ (member(MathWouldBeSilly, UnitList),
			   inherently_bound(MathWouldBeSilly)),
		    (member(any, UnitList),
			Units = any;
		      select(One, UnitList, [Other]), % == permutation
			\+ promote_arg(One, 1, _),
			(promote_arg(Other, 1, _),
			    (UnitList == [Other, One], Lop = (/),
				Units = 1/One;
				Units = One),
			    SourceRef = ValRef;
			  TattyUnits =.. [Lop | UnitList],
			    sort_units(TattyUnits, Units, ConvFactor),
			    SourceRef = ConvFactor*ValRef)), !;
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
		     ValRef = at_update(SourceRef);
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
		    throw(wrong_no_of_args(Source, Op, Arity, FnArity));
		 m_class'><'SubId has_class_refinement uses_local_fns of UserFns,
		    member(Op/Arity, UserFns),
		    throw(lost_user_defined_fn(Source, Op, Arity));
		 throw(no_such_function(Source, Op))),
	    (Source = sofar(_), !,
		all(inters, dissociate,
		    [unify(later), build(SubArgs), build(Args)]);
	    Source = at_update(_), !,
		all(inters, dissociate,
		    [unify(this_step), build(SubArgs), build(Args)]);
	    Args = SubArgs);
	throw(undecipherable_operand(Source, SubId)).

with_capt(Found, Sm, Capt) :-
	find_all_comps(Sm, Found),
	caption_for(Found, Capt).

decode_number(Source, SubId, Step, SourceRef, Units) :-
	get_actual_size(SubId, Source, quoted, [SrcNum], [SrcType], [SrcUnits]),
	remove_physical_units_if_disabled(SubId, SrcUnits, Units),
	(Step = dummy, !,
	    (Units = n(SourceRef), !; % enum type dims of makearray etc
	    SourceRef = SrcType);
	 %unmake_enum_units(OrigUnits, Units),
	    SourceRef = SrcNum).

remove_physical_units_if_disabled(SubId, SrcUnits, Units) :-
	(m_update'><'use_units_in(SubId, 'No'),
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
inherently_bound(Units) :-
	member(Units, [boolean, a(_)]).

raise_units(Base, Num, Units) :-
	Num = 0, Units = 1;
	(Num < 0, Next is Num+1, Do = (/);
	    Num > 0, Next is Num-1, Do = (*)),
	raise_units(Base, Next, Mid),
	Units =.. [Do, Mid, Base].

fn_or_op(Op, MxOp, RUnits, AUnits) :-
	var(Op), MxOp = Op, !;
	name(Op, OpStr),
	(function(_Cat0, MxOp, RUnits, AUnits);
	builtin(_Cat1, MxOp, RUnits, AUnits);
	operator(MxOp, RUnits, AUnits)),
	name(MxOp, MxOpStr),
	lower(MxOpStr, OpStr).

units_for_trigger_mag(Fn, MagUnits) :-
	setof(EvtUnit, units_for_evt_antecedents(Fn, EvtUnit), EvtUnits),
	% check dimensions the same
	all(m_update, analyze_array,
	    [build(EvtUnits), build(EvtBases), build(_EvtDims)]),
	length(EvtBases, NEvts),
	(value(Any),
	list_of(Any, NEvts, Anies),
	try_units(Any, Anies, EvtBases, MagBase), !;
	    caption_for(Fn, Capt),
	    throw(mixed_trigger_units(Capt, EvtUnits))),
	(MagBase = boolean -> ReferMagBase = int; ReferMagBase = MagBase),
	MagUnits = ReferMagBase-[]. % triggers now summed or howmanytrued

units_for_evt_antecedents(Fn, EvtUnit) :-
	m_update'><'get_all_links(Fn, discrete, _,
	     input_link(_,_,_,_, EvtUnit)).

dissociate(Wrapper, made_at(Arg, Level), made_at(NewArg, Level)) :-
	NewArg =.. [Wrapper, Arg].
dissociate(Wrapper, Arg, Arg) :-
	Arg =.. [Wrapper, _Cond];	% in case sofars/samesteps are nested
	Arg = enumerate(_Parent). % need this even if not waiting for source
	
refer_inter(instance(internal, inter(_,_, ParamLoops), Source, Name,
		     Units-Dims),
	    DestPath, BuildLoops, Units, SourceContext, Args, SourceRef) :-
	(Source = in_preceding(_) ->
	    trim_one_multi_instance(DestPath, InterPath);
	  InterPath = DestPath),
	(Source = last(_), !,
	    Args = [Name]; /* bit of a hack...since
	we use the total from the previous time step we don't need to
	worry about accessing elements that haven't yet been set, and not
	using made_at(...) should prevent it being removed as an idler */
	  member(Source, [in_preceding(_), in_progenitor(_)]), !,
	    Args = [made_at(cleared(Name), SourceContext),
 				% array must be cleared before first use
		    made_at(later(lastvalue(Name)), DestPath)];
				% access before setting in same loop
	    Args = [made_at(Name, SourceContext)]),
	copy_term(InterPath, SourcePath),
	(Source = in_progenitor(_),
	    InterPath = [sm(BitOfAHack, _,_,_) | _],
	    atom(BitOfAHack), !, % undefined and irrelevant when parsing
	    append_atoms(BitOfAHack, progen, SourcePtr),
	    SourceRef = choose(nonnull(arr('', SourcePtr, [])),
			       arr(SourcePtr, Name, IntInds), 0);
	  pointer_from(SourcePath, SourcePtr),
	    SourceRef = arr(SourcePtr, Name, IntInds)),
	make_inds_for(Dims, IntLoops, IntInds),
	copy_term(ParamLoops, SourceLoops),
	/* order of parts exchanged simply cos it made it work */
	append(SourceLoops, SpareLoops, IntLoops),
	suffix(SpareLoops, BuildLoops),
	append(SourceLoops, SourcePath, SourceContext).

prevent_inappropriate_reuse(Explicit, instance(Type, I, Replaces, Name, Dims),
			    instance(Type, I, NewReplaces, Name, Dims)) :-
	replace_subexps(Replaces, inters, swap_vars, switch(Explicit, gone),
			top_down, [_Swap1 | _], _), !,
	NewReplaces = 'n/a';
	NewReplaces = Replaces.

trim_one_multi_instance(DestPath, InterPath) :-
	suffix([MultiInst | DestTail], DestPath),
	indices_for(MultiInst, [_Some | _], _), !,
	get_model(DestTail, InterPath);
	throw(no_preceding_instance).

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
	    (m_update'><'is_exclusive_role(Link);
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
	member(Type, [boolean, a(_ET0), n(_ET1), real]).
uses_as(boolean, cond_spec).
/* above was commented out, but seems to belong
-- probably so as not to allow cond_specs to use outside conditions
if taking out again fix spread_dims as well as eqn checking */
uses_as(n(_ET), const_int).
uses_as(const_int, int).
uses_as(const_int, const_ratio).
uses_as(const_ratio, 1).
uses_as(int, 1).

promote_arg(Lo, Hi, Phys) :-
	var(Lo), !, Phys = Lo;
	promote_unit(Lo, Tpt),
	(Lo = any; % match to any physical unit
	    Tpt = real, Med = 1;
	    Med = Tpt),
	(Hi = real,
	    (Phys = Med; \+ Phys = Med),
	    (var(Phys); % only anies so far
	      get_conversion(1, Med, Phys, N),
		1 is N), !;
	Hi = Med).

/* this one interprets the unit specs in fragment names (more later?) */
describes_unit(Spec, Actual) :-
	Spec = all;
	promote_unit(Actual, Fits),
	(Spec = Fits;
	  Spec = ordinal,
	    member(Fits, [boolean, a(_ET0), n(_ET1), int])).

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
builtin('Model properties', dt, real, [const_int_or_none]).
builtin('Model properties', time, real, [const_int_or_none]).
builtin('Model properties', at_phase, any, [any]).
builtin('Model properties', at_phase, any, [int, any]).
builtin('Model properties', default, any, [any]).
%builtin('Model properties', init_time, real, []).
builtin('Model properties', stop, int, [int]).
/* legacy versions from before we had empty arg lists */
%builtin('Model properties', time, real, [const_int]).
%builtin('Model properties', init_time, real, [const_int]).
builtin('Model properties', parent, int, [dummy_int]).

builtin('Model properties', last, any, [any]).
builtin('Model properties', in_preceding, any, [any]).
builtin('Model properties', in_progenitor, any, [any]).
builtin('Model properties', prev, given_units, [const_int]).
builtin('Model properties', trigger_magnitude, given_units, [none]).
builtin('Model properties', after, int, [real, int]).
builtin('Model properties', ready, int, [any]).
builtin('Model properties', is_new_instance, boolean, [none]).
builtin('List handling', makearray, array_of_any, [any, const_int]).
builtin('List handling', place_in, int, [const_int]).
builtin('List handling', tweakarray, array_of_any, [any, const_int, int]).
builtin('List handling', statearray, array_of_any, [int, any, array_of_any]).
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

%builtin('Statistics', rand_var, real, [real, real]). Is now macro
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
builtin('Model properties', dies_of, boolean, [boolean]).
builtin('Model properties', dies_of, boolean, [real]).
builtin('Model properties', latency, real, [real]).

/* These are recognized by the parser but is not part of the equation
language -- they and the operators are hidden */

%operator(ind_time, real, [const_int]).
%operator(stage_incr, real, [diffs, int, real, real]).
% above now done by parser to insert graph id to identify discontinuity posn
operator(loses, boolean, [real, const_int]).
operator(loses, boolean, [boolean, const_int]).
operator(choose, int, [boolean, int, int]).
operator(choose, a(T), [boolean, a(T), a(T)]).
operator(choose, real, [boolean, real, real]).
operator(choose, boolean, [boolean, boolean, boolean]).
operator(happens, boolean, [Any]) :- value(Any).
operator(rand, real, [real, real]).
operator(cur_phase, real, []).
operator(cur_step, real, []).

/* These are handled by the parser but have special buttons to include them so
we do not want them in the function list -- they only appear here so the right
error comes up if they are used with the wrong number of args */

operator(graph, 1, [1]).
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
operator(is, cond_spec, [a(T), a(T)]).
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
	Spec = fm_loop(Inds, Dims,_,_);
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
	Ind = boolean, Type = boolean;
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
changing) describes it the former way...

combine_paths(C1, C2, C) :-
	permutation([C1, C2], [C, []]), !;
	% next two lines (and last) had H and T swapped
	append(H1, T1, C1),
	    append(H2, T2, C2),
	    (T1 = T2, T = T2;
	    \+ ((member(Loop, T1); member(Loop, T2)),
		   loops(Loop)),
		merge_lists(T1, T2, T)),
	    \+ T = [], !,
	    combine_paths(H1, H2, H),
	    append(H, T, C).

2012: have to redo above so it cannot unify submodel opens where the
parent pointers are distinct */

combine_paths(C1, C2, C) :-
	permutation([C1, C2], [C, []]), !;
	% next two lines (and last) had H and T swapped
	append(H1, T1, C1),
	    append(H2, T2, C2),
	    (all(inters, same_context, [build(T1), build(T2)]), T = T2;
	    \+ ((member(Loop, T1); member(Loop, T2)),
		   loops(Loop)),
		merge_contexts(T1, T2, T)),
	    \+ T = [], !,
	    combine_paths(H1, H2, H),
	    append(H, T, C).

merge_contexts([], L, L).

merge_contexts([J | K], L, M) :-
	merge_contexts(K, L, N),
	(member(H, N),
	    same_context(H, J), !,
	    M = N;
	M = [J | N]).

same_context(C1, C2) :-
	\+ (C1 = sm(_, P1, _, L),
	       C2 = sm(_, P2, _, L),
	       \+ L = rm_loop(_,_,_), % pointers meaningless -- syntax check
	       \+ P1 == P2),
	C1 = C2.

% slightly different version for args of element()

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

% Old make_all_intermediates and combine_subexp_results functions
% together -- note that for functions in general, DestPath was
% copy_termed before passing to combine_whatever because of pointer
% instantiation problems. Might need to reinstate...

make_subexps([],_,_,_,_, I, _,_,_, [], I, [], FC, FC, [], [], []).

make_subexps([Source | Components], SubId, Target, DestPath,
	     Swaps, PrevInters, BuildingArrays, Step, Used,
	     [Unit | UnitList], NewInters,
	     [Name | MoreATs], FunctionContext, NewContext,
	     NewSetup, NewArgs, [NewRef | Comps]) :-
	(nonvar(Name), % Supply actual node name in fragment instance
	    (setof(InComp, with_capt(InComp, SubId, Name), [VisDestId]) ->
		m_update'><'add_implicit_function(VisDestId, DestId);
	      throw(input_name_deref_fail));
	  var(Name),
	    DestId = SubId),
% terms must be done in right order to match right submodels in instantiation
	make_intermediates(Source, DestId, Target, 
			   DestPath, Swaps, PrevInters, BuildingArrays, 
			   Step, Used, Unit, LastInters,
			   part_result(SourceContext, Setup, Args, NewRef)),
	make_subexps(Components, SubId, Target, DestPath, Swaps,
		     LastInters, BuildingArrays, Step, Used,
		     UnitList, NewInters,
		     MoreATs, FunctionContext, 
		     OldContext, OldSetup, OldArgs, Comps),
/* Old version: got dims from metadata
	(nonvar(ADs),
	    reverse(ADs, InnerFirst),
	    (\+ describes_unit(AG, Unit),
		throw(mismatched_units(macro, Source, Unit, AG));
	      promote_unit(Unit, AU),
		value(AU));   % this needs retried if next input higher
	  var(ADs),
	    ADs = []),
	...now, if a named input, read dims from it */
	(nonvar(Name),
	    m_update'><'get_av_pair(VisDestId, 0, units, OldU),
	    m_update'><'analyze_array(OldU, _OldUnits, NeededDims),
	    length(NeededDims, N),
	    length(NeededLoops, N),
	    get_model_and_loops(SourceContext, DestPath, _, Loops, Model),
	    (append(SpareLoops, NeededLoops, Loops), !;
		throw(fragment_arg_needs_more_dims)),
	    append(SpareLoops, Model, UseContext),
	    % now set up input node
	    get_dims_from_loops(NeededLoops, UsingDims, _),
	    m_update'><'build_array(Unit, UsingDims, NewU),
	    /* pick_elt_from(Source, SpareLoops, SourceElt),
				% wrap in element(..)
	    m_update'><'add_parameter(DestId, 0, value, SourceElt),
	    would be wrong because params have been substituted --
	    add a keyword instead */
	    FormParam = formal_parameter(SpareLoops, BuildingArrays),
	    m_update'><'add_parameter(DestId, 0, value, FormParam),
	    m_update'><'add_parameter(DestId, 0, units, NewU),
	    event'><'spread_colour(VisDestId, dims);
	  UseContext = SourceContext),
	(combine_contexts(UseContext, OldContext, DestPath, NewContext), !;
	    throw(cannot_combine_argument_dimensions([Source | Components]))),
	append(OldSetup, Setup, NewSetup),
	append(OldArgs, Args, NewArgs).

	/* think about using all for this -- only cumulative inters is hard
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



combine_subexp_results: Takes a list of sets of possible contexts (and
other result information) and tries to make a single context for all of them.

Functions that must be evaluated at setup must get their own temporary
variables, so they are not allowed here. It may be that the whole
expression gets evaluated only at init time in which case this is unnecessary,
but there is no way to tell yet.

combine_subexp_results(_, [], [], FunctionContext, FunctionContext, [], [], []).

combine_subexp_results(DestPath,
		       [part_result(SourceContext, Setup, Args, NewRef)
		       | ResultList], [data(_,_, AU, ADs) | MoreATs],
		       FunctionContext,
		       NewContext, NewSetup, NewArgs,
		       [NewRef | Comps]) :-
	combine_subexp_results(DestPath, ResultList, MoreATs, FunctionContext, 
			     OldContext, OldSetup, OldArgs, Comps),
	(\+ ADs = [], !; ADs = []), % set to [] if var
	combine_contexts(SourceContext, OldContext, DestPath, ADs, NewContext),
	append(OldSetup, Setup, NewSetup),
	append(OldArgs, Args, NewArgs).
        cannot merge because paths in made_ins must be kept separate */

change_constituent(switch(All, Bit, NewBit), Old, New, 0) :-
	Old = Bit, !,
	    New = NewBit;
	\+ Old = All.

just_inputs(All, param(arr(_, Name, _), _,_,_,_), _, 0) :-
	member(Name, All).
	    
add_extra_dependencies(OldCon, NewCon, Source, VarList, FullList) :-
/* Now if I come out of any generated submodels, add a dependency on the generator
function...similarly a dependemcy on time for any population submodels */

        (setof(Sm, has_extras(OldCon, NewCon, Sm), Exited); Exited = []),
	wait_for_submodels(Exited, WaitList),

/* Also, if the expression contains reference to the current time or time interval
it cannot be evaluated at init time, so treat these as references to a compartment
called 'time' (reserved word) */

	(contains_something(changeable, Source, _), !,
	    append(WaitList, [time | VarList], FullList);
	append(WaitList, VarList, FullList)).

contains_something(Property, Expr, Backgnd) :-
	replace_subexps(Expr, inters, Property, Backgnd, top_down, [_ | _], _).

/* Changeable subexps are those whose value can change even if their
arguments stay the same. last(_) is in here because the 'last' value of a
constant is zero on the first evaluation step, value of the constant
thereafter.
All randoms are now changeable because the const versions are defined as
macros using at_init(). */

changeable(_, Subexp, _, 0) :-
	random(_, Subexp, _, 0);
	nonvar(Subexp),
	Subexp =.. [Functor | _],
	(member(Functor, [time, dt, cur_phase, cur_step, last, loses]);
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

individuates_instances(InterDefs, Subexp, _, 0) :-
	individuates_elements(InterDefs, Subexp, _,_);
	nonvar(Subexp),
	member(Subexp, [channel_is(_), at_phase(_,_), index(_)]).
% at_phase/1 does not, because membership not changed on subphase

individuates_elements(InterDefs, Subexp, _, 0) :-
	random(_, Subexp, _,_);
	nonvar(Subexp),
	(Subexp = place_in(_);
	  member(instance(internal, _, Subexp, _, _-[_|_]),
		 InterDefs)). % refers to inter with multiple vals

random(_, Subexp, _, 0) :-
	nonvar(Subexp),
	Subexp =.. [Functor | _],
	(member(Functor, [rand]);
	    sample(Functor)).

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

add_condition_to_context(make(Fx, R, C, S, A), [CondCtxt, CondArgs, Cond],
			 make(Fx, AllR, CPl, S, A)) :-
	append(CondArgs, R, AllR),
	combine_contexts(CondCtxt, C, [], JointC),
	append(ForFill, CondCtxt, JointC),
	append(ForFill, [cond_section(Cond) | CondCtxt], CPl).

%pointer_from([], ''). % was 'this' -- why? '' makes locals for event procs.
pointer_from([], this). % needed for tcl exec. Events no longer procs?
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
	\+ VLoop = fm_loop(_,_,_,_), !,
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
loops(cond_section(_)).

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
