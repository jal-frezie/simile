/******************************************************************************
*** COMPILATION module. This module contains all the templates necessary   ****
*** to compile AME code. Everything is parameterised by language, BASIC    ****
*** being the starting point.                                              ****
******************************************************************************/

sicstus_module( compile, [compile/3, new_exec_for/1] ).

sicstus_use_module( [library(ordsets),library(lists),
		sp_only,instance,inters,language,render,m_class,utility,output,
		ame_gen, m_update, units, text, dialogue] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% compile( Language, Program ) is true if Program is an ordered list of
% statements in the specified programming Language and Program embodies the
% model specified in the KR.

% Program is generated as a list of Prolog atoms, each of which is intended to
% form one line of code in the output file; thus, the translator can have
% control over layout, which may be important for some languages. (Having said
% that, the current version does simple block-style indenting.

:- dynamic(new_exec_for/1).
:- dynamic(error_free/1).

compile( Language, Parent, DestDir) :-
	tk_scrub_run(Parent, 0),
/*	(Language = tcl, !,
	    unseparate(SeparateNodes);
	list_interconnects(Parent)),
*/	reassure_user("Checking that the model is complete and consistent"),
	/* This is a stopgap, we should really update a property of the
	submodel containing the destination whenever a link is added or
	deleted so only to do these checks when needed */
	asserta(error_free(build)),
	catch(build_instances(Language, DestDir, Parent, Parent, 1, _,_,_,_),
	      Err, 
	      (Err = aborted, !; % no further message needed
		  retractall(error_free(build)),
		  query(Err, error, execution, [ok], _))),
	finish_progress_dialogue,
	retract(error_free(build)). % only possible if nothing went wrong
/*	(Language = tcl, !,
	    all(m_class, has_new_class_refinement,
		[build(SeparateNodes), unify(separate of 1)]);  
	true).

unseparate(Nodes) :-
	setof(N, N no_longer_has_class_refinement separate of 1, Nodes), !;
	Nodes = [].

list_interconnects(Node) :-
	setof(TopArc, top_arc_for_exit(Node, TopArc), TopArcs), !,
	all(compile, entries_for, [build(TopArcs), build(XS)]),
	build_interconnects(Node, XS);
	build_interconnects(Node, []).
	
top_arc_for_exit(Node, TopArc) :-
	contains(Node, DLLSpec),
	DLLSpec has_class_refinement separate of 1,
	(End = DLLSpec;
	DLLSpec has_part End,
	    \+ appears(End), \+ find_type(End, function)),
	Crossing is_connector from _ to End,
	find_type(Crossing, influence),
	equivalent_arcs(TopArc, Crossing),
	is_top_arc(TopArc).

entries_for(TopArc, [TopArc, TopNode, Source, Entries]) :-
	find_all_comps(TopNode, TopArc),
	initiates(TopArc, Source),
	(setof(Entry, (equivalent_arcs(Entry, TopArc), is_entry(Entry)),
	      Entries), !;
	Entries = []).
		  
is_entry(Entry) :-
	Entry is_connector from End to _,
	(End = DLLSpec;
	\+ appears(End), \+ find_type(End, function),
	    DLLSpec has_part End),
	DLLSpec has_class_refinement separate of 1.

What follows still contains extensive support for building models as a
series of shared libraries corresponding to some chosen levels in the
heirarchy of submodels, although this is no longer used as of v5.0. It
may return one day... */

build_instances(Language, DestDir, Parent, TopNode,
		Step, ChangeNext, LocalFnsUsed, LocalExtLibs, KeepParents) :-
	caption_for(Parent, Name),
	append_atoms([DestDir, '/', Name], CheckDir),
	check_directory(CheckDir),
	windowize(CheckDir, WCheckDir),
	time_step_for(Parent, Step, MyStep),
	build_sub_instances(Language, CheckDir, Parent,
			    TopNode, MyStep, ChangeTop,
			    SubFnsUsed, SubExtLibs, KeepDir),

	(setof(Fn, list_user_fns(Parent, Fn), LevelFnsUsed), !,
	    merge_lists(LevelFnsUsed, SubFnsUsed, FnsUsed);
	FnsUsed = SubFnsUsed),
	(Parent has_class_refinement external_code of ExtCodSpec,
	    member(libraries=LevelExtLibs, ExtCodSpec), !,
	    merge_lists(LevelExtLibs, SubExtLibs, ExtLibs);
	ExtLibs = SubExtLibs),
	/* model can go incomplete then complete again without change
	 so check all */
	(check_level_for_reds(TopNode, Parent, Wrinkle),
	    retractall(error_free(build)),
	    query(Wrinkle, warning, top, [abort], abort),
	    throw(aborted);
	Parent has_model_refinement c_new of 0, !,
	    Parent has_changed_model_refinement c_new of 1,
	    ChangeTop = 1,
	    LocalFnsUsed = [],
	    LocalExtLibs = [];
	LocalFnsUsed = FnsUsed,
	    LocalExtLibs = ExtLibs),

	(( %Parent has_class_refinement separate of 1;
	  error_free(build),
	   backup:is_toplevel(Parent)), !,
	    /* we need an executable for this level */
	    (Language = c,
	        (Parent has_model_refinement c_new of OldTgt;
		    OldTgt = 1), !;
	    /* if no c_new look for dll from save file with 1 in name */
	    OldTgt = 0),
	    check_exec_fns_fresh(Language, CheckDir, OldTgt, FnsUsed, RStrs),
	    all(user, name, [build([Stat | Includes]), build(RStrs)]),
	    (Stat < 3, !;
		Includes = [LostFn, WhereSought],
	        raise_exception(missing_function(LostFn, WhereSought))),

	    (\+ ChangeTop == 1, % no change to model; reuse executable?
		Stat = 0,
		Tgt = OldTgt;
	    
		(\+ ChangeTop == 1, % no change to model; reuse source?
		    Language = c,
		    safe_tcl_eval(['ReuseSourceCode', br(WCheckDir), OldTgt],
				  "1"), % succeeds if old source code found
		    Fuss = 0; % rebuild quietly if it fails to compile
		 % neither worked, or model changed: rebuild source
		    all(compile, delete_prog, [unify(CheckDir),
			build(['.tcl', '.cpp', '.dll', '.so', '.dylib'])]),
		    (Language = c, Extn = '.cpp';
		     Language = tcl, Extn = '.tcl'),
		    dialogue:reassure_user("Instantiating expressions from node values"),
		    instantiate_all(Parent, Model),
		    append_atoms([WCheckDir, '/', model, Extn], WProgName),
		    open_native(WProgName, write, Stream),
		    on_exception(Puke,
				 protected_build(Language, Stream, MyStep, 
						 Model, Includes),
				 (reclose(Stream), raise_exception(Puke))),
		    close(Stream),
		    Fuss = 1),
		dialogue:reassure_user("Compiling the program generated for the model"),
	     (Language = tcl, !,
		 Tgt = 'model.tcl';
	     compile_c_program(CheckDir, ExtLibs, Fuss, Tgt),
		 (Tgt = -1, !, fail;
		  Tgt > 0,
		  (Parent has_changed_model_refinement c_new of Tgt;
		      Parent has_new_model_refinement c_new of Tgt)),
		 assert(new_exec_for(Parent)))),
	    load_executable(Language, CheckDir, Tgt, Parent, TopNode, Includes),
	    KeepDir = 1;
	ChangeNext = ChangeTop),
	/* delete dir if empty...*/
	(\+ KeepDir == 1, !;
	    KeepParents = 1).

list_user_fns(Parent, Fn) :-
	find_all_comps(Parent, Comp),
	find_type(Comp, function),
	Comp has_class_refinement uses_local_fns of FnList,
	member(Fn, FnList).

/* reclose: compiled version has a tendency to close streams when exiting their
functions on an exception, so this only closes if it has to...*/

reclose(Stream) :-
	on_exception(_,close(Stream), true).

/* delete_prog: if we are building a new program we will be marking the model
as having it, so we don't want old ones in other languages (or old executables
in other formats) hanging around. */

delete_prog(Base, Extn) :-
	append_atoms([Base, '/', model, Extn], FullName),
	my_delete_file(FullName).
	
build_sub_instances(Language, DestDir, Parent, Node,
		    Step, ChangeTop, LocalFnsUsed, LocalExtLibs, KeepDir) :-
	(setof( Submodel, (Parent has_part Submodel,
			      Submodel has_class submodel,
			      appears(Submodel)), Submodels), !; 
	    Submodels = []),
	all(compile, build_instances, 
	    [unify(Language), unify(DestDir), build(Submodels),
	     unify(Node), unify(Step), unify(ChangeTop),
	     merge_lists(LocalFnsUsed, []), merge_lists(LocalExtLibs,[]),
	     unify(KeepDir)]).

check_level_for_reds(TopNode, Submodel, Wrinkle) :-
	find_all_comps(Submodel, VisEntity),
	appears(VisEntity),
	\+ VisEntity is_of_sort captionless,
	\+ is_ghost(VisEntity),
	\+ image:draws_complete(VisEntity),
	abs_path_name(Submodel, TopNode, OuterText),
	caption_for(VisEntity, RedText),
	menu:select_all_in(Submodel, base), /* make sure the red shows */
	safe_tcl_eval([set, log, entered_exception], _),
	Wrinkle = unspecified(OuterText, RedText);
	Parent has_part Submodel,
%	remove_redundant_equivs(Submodel, Equivs),
% never happens as refs to unlinks cannot be loaded
	Submodel has_link_equivalences Equivs,
	member(Before-After, Equivs),
	Before is_connector from S1 to F1,
	After is_connector from S2 to F2,
	\+ (find_all_comps(Parent, S1), F1 = Submodel,
	       Submodel has_part S2, find_all_comps(Submodel, F2);
	    find_all_comps(Parent, F2), S2 = Submodel,
	       Submodel has_part F1, find_all_comps(Submodel, S1)),
	Wrinkle = link_inconsistency(Before-After);
	by_record(Submodel),
	\+ defines_membership(Submodel, _Param),
	caption_for(Submodel, OuterText),
	Wrinkle = no_defining_param(OuterText);
	uses_channels(Submodel),
	\+ (find_all_comps(Submodel, SmChannel),
	       SmChannel is_of_sort value_outside),
	caption_for(Submodel, OuterText),
	Wrinkle = no_seed_param(OuterText);
	\+ uses_channels(Submodel),
	find_all_comps(Submodel, SmChannel),
	SmChannel is_of_sort pop_only,
	caption_for(Submodel, OuterText),
	caption_for(SmChannel, InnerText),
	Wrinkle = misplaced_channel(InnerText, OuterText);
	variable_size(Submodel),
	\+ by_record(Submodel),
	contains(Submodel, Param),
	is_parameter(Param, N), N>0,
	caption_for(Submodel, OuterText),
	caption_for(Param, InnerText),
	Wrinkle = param_in_vm_model(OuterText, InnerText).

uses_channels(Submodel) :-
	is_population(Submodel),
	\+ by_record(Submodel).
/*
remove_redundant_equivs(Submodel, Equivs) :-
	Submodel has_link_equivalences OldEquivs,
	(select(Before-After, OldEquivs, MoreEquivs),
	\+ (Before is_connector from _ to _,
	    After is_connector from _ to _), !,
	caption_for(Submodel, Capt),
	Submodel has_changed_link_equivalences MoreEquivs,
	remove_redundant_equivs(Submodel, Equivs);
	Equivs = OldEquivs).
*/	
defines_membership(SmByRec, Fp) :-
	find_all_comps(SmByRec, Comp),
	(is_parameter(Comp, 2), Fp = Comp;
	defines_membership(Comp, Fp)).

% The code works by first giving names to the mathematical entities in the
% model, and then working out bit by bit what the program has to be.

protected_build(Language, Stream, TopStep, FullModel, LocalIncs) :-
	FullModel = model(_Channels, [instance(submodel, Top, xrefs(_,
	    instance(submodel, _, xrefs(FullModel, top, [], []),
		     'AME_model', top-[]), _,_), _,_)]), 
	/* Parent of top level model is not specified, so set it empty */
	
	% then, traverse it in a sensible order, and make up names for the
	% variables in it. The (Prolog) variables representing them are then
	% instantiated to those names.
	% From this, we get a list of variables which may be considered
	% global (compartment values, time paramaters), local (variables,
	% functions, and flow values), and external (parameters, exogenous
	% variables).

	% Throughout the code below, Used is a list of the names used so far.

/* Next, since all submodels are going to be represented as data structures 
(including the toplevel one, as this may itself be multiple instance) we need to 
generate structure type declarations for them, starting with the most deeply 
nested. Data about submodel multiplicity is left in the main model. Start with c++ 
keywords in list of things that cannot be used as variable names...*/

	Keywords = [asm, auto, bad_cast,
		    bad_typeid, bool, break, case, catch, char, class,
		    const, const_cast, continue, default, delete, do,
		    double, dynamic_cast, else, enum, except, export,
		    extern, false, far, finally, float, for, friend,
		    goto, huge, if, inline, int, long, namespace, near, new,
		    operator, private, protected, public, register,
		    reinterpret_cast, return, short, signed, sizeof,
		    static, static_cast, struct, switch, template,
		    this, throw, true, try, type_info, typedef,
		    typeid, union, unsigned, using, virtual, void,
		    volatile, while, xalloc],

/* And there are also a few variable names that are sacred to the data
extraction procedures, including 'tree' which is fairly
important...(or was, back when the A stood for Agroforestry)... */

	LocalNames = [tree, type, set, newvalue, finished, current, context,
		      dtarget, btarget, instance, time_step,
		      time, times, ts, dts,
		      parentId, channelId, version,
		      on_reset, on_reload, externs_done, /* dummy conditions */
		      use_param_state, /* indicates file parameter */
		      id, dims, /* arguments to extractor proc */
		      next, instanceid, new_instance | _],
	/* system vars in submodel */
/* we cannot change names of external procedures, so add them to the used */

        (setof(ExtProc, uses_ext_proc(Top, ExtProc), ExtProcs), !;
            ExtProcs = []),
	append(Keywords, ExtProcs, BuiltIn),
        append(BuiltIn, LocalNames, Used),

/* This gives names in the target programming language to all the variables, 
structures corresponding to submodels, structure types, pointers and other 
bits and pieces */

	reassure_user("Choosing names for program variables"),
	declare_structure(Language, FullModel, Used, AllGraphs),

	(
% File writing starts here
	send_to_dest(Stream, ['#include <support1.cpp>']),
	dialogue:reassure_user("Creating submodel value expressions"),
	extract_assignments(instance(submodel, root, xrefs(FullModel, _,_,_),
				     _,_), [], TopStep, Phases, [], Used,
			    ExtIncs, Inters, ReevaluateForm),
	merge_inters(Inters, FullModel, AugmentedModel, Constants),
	
/*	extract_submodel_updates(Instances, [], 1, Phases, Deltas),
	set_free_phases(Deltas, Phases), */

	/* EnumTypeSpecs will eventually go in a procedure outside
the model class which will be called from getcount to initialize a
list of them as soon as the model is loaded, thus allowing them to be
used when entering file parameters */
	(Phases = 0,
	    raise_exception(no_phases);
	true),
	set_free_phases(ReevaluateForm, Phases, NewForm),
	pick_state_vars(NewForm, EvaluateForm, StateForm, UpdateForm),
	all(utility, all, % just showing off here
	    [unify(compile), unify(put_in_phase),
	     build([[build(StateForm)], [build(UpdateForm)]])]),
	check_functions(EvaluateForm, Phases, VMSPs),
	/* first off, unify all matching vm level specs in the two lists so
	that those that are completed when ordering their condition nodes
	can be used later */
	all(compile, insert_enum_phases, [build(VMSPs), unify(UpdateForm)]),
	all(compile, insert_enum_phases, [build(VMSPs), unify(StateForm)]),
	all(compile, insert_enum_phases, [build(VMSPs), unify(EvaluateForm)]),

	state:version_is(VStr),
	state:edition_is(Edition),
	library:count_functions(Top, FnCount),
	sicstus_format_to_chars("\"program='AME',version=~s,edition=~a,date=unused,size=~d,\"", [VStr, Edition, FnCount], IdentStr),
	sicstus_atom_chars(IdentAtom, IdentStr),
%	name(V, VStr),
%	render(Language, variable_declaration,
%	       [real, simile_version, [], V], 0, VersionDec),
/* eval/update procedures are built here because they provide graph info
	for later declaration builder
	
	update_submodel_compartments( Language, Phases, Used, Deltas, Comps),
*/
/* This generates the declarations in languages such as C and Tcl8.0
wot need them */

	excrete(Language, comment, 'GLOBAL DECLARATIONS', 0, Stream),
	all(compile, excrete,
	    [unify(Language), unify(global_declaration),
	     build([[void, this, []] | Constants]), unify(0), unify(Stream)]),
	excrete(Language, variable_declaration,
	       [char, simile_identifier, void, IdentAtom], 0, Stream),
	excrete(Language, variable_declaration,
	       [int, phasecount, [], Phases], 0, Stream),
        BoostPhases is Phases+1,
	excrete(Language, variable_declaration,
	       [real, ts, [BoostPhases]], 0, Stream),
	excrete(Language, variable_declaration,
	       [real, dts, [BoostPhases]], 0, Stream),

	list_matching_files('../Functions/*.cpp', FnIncs),
	/* the /* in the above line does not start a comment */
        all(utility, get_native, [build(ExtIncs), build(UExtIncs)]),
	append([FnIncs, LocalIncs, UExtIncs], Incs),
	all(utility, append_atoms,
	    [unify('#include "'), build(Incs), build(PartIncs)]),
	/* the " in the above line does not start a quoted string */
	all(utility, append_atoms,
	    [build(PartIncs), unify('"'), build(FullIncs)]),
	/* the " in the above line does not start a quoted string */
	send_to_dest(Stream, FullIncs),
	
	reassure_user("Generating constant declarations"),
	excrete(Language, comment, 'CONSTANT DECLARATIONS', 0, Stream),
	all(compile, excrete,
	    [unify(Language), unify(variable_declaration), build(Constants),
	     unify(0), unify(Stream)]),
	
	reassure_user("Generating structure declarations"),
	excrete(Language, comment, 'STRUCTURE TYPE DECLARATIONS', 0, Stream),
	
	RootInstance = instance(submodel, root, xrefs(AugmentedModel, _,[],_),
				'AME_model', 'AME_model'-[]),
	generate_main_decls(Language, RootInstance, EndTopType, Stream),

	build_submodel_functions(Language, Phases, Constants,
				 StateForm, UpdateForm, EvaluateForm, Used,
				 AllGraphs, Stream),
	make_exit_proc(Language, [RootInstance], Stream),
	send_to_dest(Stream, EndTopType),
	fail;

	insert_metadata(Language, FullModel, Used, Stream),
	send_to_dest(Stream, ['#include <support2.cpp>'])

	/* OK at this point we need to free all the memory we possibly can;
	fail through everything, and trust that I can ignore what was 'used'
	cos we are back in the top namespace... */
	
	).

insert_metadata(Language, FullModel, Used, Stream) :-
	reassure_user("Generating metadata declarations"),
	extract_instances(FullModel, RealDecls),
	generate_metadata(Language, RealDecls, [], 1, Used, NodeData, Stream),
	make_constant_list(Language, NodeData, StructText),
	length(NodeData, NodeCount), /* only used in tcl */
	excrete(Language, variable_declaration,
		   [int, nodecount, [], NodeCount], 0, Stream),
	excrete(Language, variable_declaration,
		   [node_data_line, nodedata, void, StructText], 0, Stream).
		  
uses_ext_proc(Model, Proc) :-
        contains(Model, Submodel),
	Submodel has_class_refinement external_code of ExtCode,
	member(include=Inc, ExtCode),
	\+ Inc = none,
	member(procedure=Proc, ExtCode).
/*
get_graph_spec(GraphSpec) :-
	NodeId has_class_refinement table_data of
	[file='/graph/', data=[YLow, YHigh, YSpan],
	 indices=[XLow, XHigh, XSpan, Range], current=PointList,
	 units=_, _, dims=NumPts | _],
	% Keep tcl working till it uses c++ graph access
	GraphSpec = [NodeId, XLow, XHigh, XSpan,
		  YLow, YHigh, YSpan, Range, NumPts | PointList].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
declare_structure/3: goes through submodels and starting with most deeply 
nested, provides a name for each variable, and a name, type, tag and pointer
name for each structure. Note we don't generate names for variables; they are
all named after the nodes from which they take their values. */

declare_structure(Language, model(Vars, Submodels), Used, AllGraphs) :-

	declare_submodel_structures(Language, Submodels, Used, SmGraphs),
	pick_types(Vars, [function, init_function, id_function,
			  loss, internal, external], NamedVars),
	name_components( Language, NamedVars, Used, Graphs),
	append(SmGraphs, Graphs, AllGraphs).

declare_submodel_structures(_, [], _, []).

declare_submodel_structures(Language, [Instance | Instances], Used, Graphs) :-
	Instance = instance(submodel, Node, xrefs(Model, _, Bases, _), 
		Name, Type-_),
	caption_for(Node, Capt),
	generate_name(Language, Capt, Name, Used, [type]),
	append_atoms(Name, type, Type),
	make_assoc_loop_names(Language, Instance, Used, Bases),
	declare_structure(Language, Model, Used, HeadGraphs),
	declare_submodel_structures(Language, Instances, Used, TailGraphs),
	append(HeadGraphs, TailGraphs, Graphs).

make_assoc_loop_names(_,_,_, []).

make_assoc_loop_names(L, Instance, Used,
		[base(BaseInstance, Link, Ptrs) | Bases]) :-
	caption_for(Link, LinkName),
	invent_ptr_names(L, LinkName, BaseInstance, Instance, Used, Ptrs),
	make_assoc_loop_names(L, Instance, Used, Bases).

invent_ptr_names(L, LinkName, BaseInstance, Instance, Used, Ptrs) :-
	ancestor(Instance, BaseInstance, _), !,
	    Ptrs = []; % 19/12/02: does this ever happen...?
	BaseInstance = instance(submodel, BaseSm, xrefs(_, Parent, _,_), _,_),
	    caption_for(BaseSm, BaseCapt),
	    append_atoms(LinkName, BaseCapt, Context),
	    append_atoms(Context, ptr, PtrBase),
	    generate_name(L, PtrBase, Ptr, Used),
	    invent_ptr_names(L, LinkName, Parent, Instance, Used, MorePtrs),
	    Ptrs = [Ptr | MorePtrs].

pick_state_vars([], [], [], []).

pick_state_vars([One | All], Rate, State, Update) :-
	pick_state_vars(All, MoreRate, MoreState, MoreUpdate),
	One = make(Tgt, _,_,_, Acts),
	(member(Acts, [[assign(SV, SV+stage_incr(_,_,_))],
		      [update_submodel(_,_,_)]]), !,
	    Rate = MoreRate, State = MoreState, Update = [One | MoreUpdate];
	(member(Tgt, [lastvalue(_), completed(_)]);
	        Acts = [advance_submodel(_,_,_)]), !,
	    Rate = MoreRate, State = [One | MoreState], Update = MoreUpdate;
	Rate = [One | MoreRate], State = MoreState, Update = MoreUpdate).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% check_functions tests for circularity, then puts each function
% evaluation into the slowest time step in which it needs to be updated

check_functions(Functions, Phases, VMSPs) :-
/*	reassure_user("Checking for circularity in model assignment order"),
	(\+ all(compile, reachable, [build(Functions), unify([])]),
	    retract(heres_yer_loop(Loop)),
	    all(compile, unfinished_in, [build(Loop), build(CircSet)]),
	    raise_exception(circular_evaluation(CircSet));
*/	reassure_user("Sorting assignments into correct time steps"),
        sort_assignments(Functions, Phases, VMSPs),
	/* Check all same-time-step circles can be done in one program loop */
	reassure_user("Checking consistency of same-time-step loops"),
	(member(Start, Functions),
	    Start = make(_, Conds-_, _,_,_), 
	    member(later(Loop2), Conds),
	    Loop2 = make(LoopEnd, _, Path, [_, Phase | _], _),
	    remove_non_loopers(Path, PurePath),
	    find_antecedent([Loop2], outside_loop, PurePath-Phase, Out),
	    /* would be better to get setof these and trace them all back at
	    once but that needs too_many_variables */
	    find_antecedent([Out], =, Start, _),
	    Out = make(Xefct, _, APath, [_, APhase | _], _),
	    (remove_non_loopers(APath, PureAPath),
		\+ suffix(PurePath, PureAPath),
		raise_exception(condition_outside_loop(LoopEnd, Xefct));
	    raise_exception(mixed_phase_loop(LoopEnd, Xefct, Phase, APhase)));
	!).
/*
reachable(P, Trail) :-
	append(Rolled, [P | _], Trail),
	asserta(heres_yer_loop([P | Rolled])),
	!, fail;
	P = make(_, Qs-_, _, [_, Chkd | _], _),
	(Chkd == 1, !;
	all(compile, reachable, [build(Qs), unify([P | Trail])]),
	    Chkd = 1).
*/
put_in_phase(make(_,_,_, [P,P | _], _)).
	    
/* generate_main_decls does all the declarations except the ones for
temporary variables used when expanding expressions.
* New version, for 2.34: Does all the recursing itself, and also generates
the model node data table and the extractor case statements */

generate_main_decls(L, Instance, Finish, Stream) :-
	Instance = instance(submodel, SymbolicName, 
			xrefs(Model, _, Bases, _), _, ModelType-_),
	(variable_size(SymbolicName), !,
	    /* Declare the type with 'compartment' to hold instance numbers */
	    list_local_index_meanings(SymbolicName, Bounds),
	    append_atoms(ModelType, '*', PtrType),
	    (is_population(SymbolicName), !,
		DummyCompDims = [1],
		DeclsOnly = [instance(system, _,_, parentId, int-[]),
			     instance(system, _,_, channelId, int-[])];
	    length(Bounds, IdCount),
		DummyCompDims = [IdCount],
		(render:count_base_ptrs(Bases, PtrCount),
		    PtrCount > 0, !,
		    /* model have an array of assoc pointers
		    for multiple associations.
		    ..good job I can get away with making them void... */
		    DeclsOnly = [instance(internal, baseptrs,_,
					baseptrs, 'void*'-[PtrCount])];
			DeclsOnly = [])),
	    Extras = [instance(system, next, _, next, PtrType-[]),
		      instance(system, ids,_, instanceid, int-DummyCompDims),
		      instance(system, isnew, _, new_instance, 'BOOLEAN'-[])];
	Extras = [],
	    DeclsOnly = []),
	extract_instances(Model, RealDecls),
	append(Extras, RealDecls, SubInstances),
	append(DeclsOnly, SubInstances, KitchenSink),
	render(L, class_declaration, Instance, 0, ThisDecl),

	refer_value(L, id, IdRef),
% Dims in next line replaced by [] for local dims only
	append(MainClass, [proc_decls | EndClass], ThisDecl),
	append(ClassStart, [submodel_decls | ClassEnd], MainClass),
	send_to_dest(Stream, ClassStart),
	Model = model(_, Submodels),
	all(compile, generate_main_decls,
	    [unify(L), build(Submodels), unify(1), unify(Stream)]),
	send_to_dest(Stream, ClassEnd),
	all(compile, excrete,
	    [unify(L), unify(data_declaration), build(KitchenSink),
	     unify(4), unify(Stream)]),
	excrete(L, procedure_start, call('void*', get_pointer, [int, id],
					 ['int**', dims]), 0, Stream),
	excrete(L, switch_start, IdRef, 4, Stream),
	generate_all_case_entries(L, 1, SubInstances, Stream),
	excrete(L, end(switch), IdRef, 4, Stream),
	excrete(L, procedure_call, return('NULL'), 4, Stream),
	excrete(L, end(procedure), get_pointer, 0, Stream),
	(var(Finish), !,
	    Finish = EndClass;
	 send_to_dest(Stream, EndClass)).

generate_metadata(_, [], _,_,_, [], _).
generate_metadata(L, [Instance | Instances], Tree, Level,
		     Used, NodeData, Stream) :-
	Instance = instance(Type, Node, Loc, _, _-CSizes),
	(Type = submodel, !,
	    list_local_index_meanings(Node, SmIndSpecs),
	    all(dialogue, index_names_and_sizes,
		[build(SmIndSpecs), build(_Text), build(RSizes)]),
	    reverse(RSizes, SmSizes);
	SmSizes = CSizes),
	all(ame_gen, enum_type_ref,
	    [build(SmSizes), unify(Node), build(_), build(_), build(Posn)]),
		/* In the past, SmDims was replaced by Posn, which is
		a number from -10 down indicating the data structure in the
	        executable corresponding to the actual enumerated type. */
	(Type = submodel, variable_size(Node), !,
	    StartCases = 4,
	    append(Tree, [Level, -1], DeepTree),
	    (by_record(Node), !,
		['RECORDS'] =  NewDims;
	    is_population(Node), !,
		['MEMBERS'] = NewDims;
	    substitute(0, Posn, 'MEMBERS', VmBounds),
		append(['START_VM' | VmBounds], ['END_VM'], NewDims));
	append(Tree, [Level], DeepTree),
	    StartCases = 1,
	    Posn = NewDims),
	(Loc = xrefs(Model, _,_,_),
	extract_instances(Model, RealDecls), !,
	generate_metadata(L, RealDecls, DeepTree, StartCases,
			     Used, DeepNodeData, Stream);
	 /* Not a submodel */
	    DeepNodeData = []),
	generate_data_decls(L, NewDims, DeepTree, Instance,
			    Used, LocalNodeData, Stream),
	NewLevel is Level + 1,
	generate_metadata(L, Instances, Tree, NewLevel,
			     Used, MoreNodeData, Stream),
	append([LocalNodeData, DeepNodeData, MoreNodeData], NodeData).
	    
extract_instances(model(Funx, Subz), Instances) :-
	pick_types(Funx, [function, init_function, id_function, fp_compartment,
			  loss, internal, external],
		   ValFunx),
	append(Subz, ValFunx, Instances).

pick_types(All, Types, Picked) :-
	All = [], Picked = [];
	All = [This | More],
	This = instance(Type, _,_,_,_),
	(member(Type, Types), !,
	    Picked = [This | Rest];
	Picked = Rest),
	pick_types(More, Types, Rest).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% go through lists of things and extract assignments

/* DeltaForm is used to indicate that nodes that depend on compartments cannot be set at initialization time. For the same reason we include NotionalInputUpdates -- update instructions for the input parameters, which are never actually executed but which are used to make sure nodes that depend on them are evaluated every time step.

update_submodel_compartments(Language, Phases, Used, DeltaForm, Decls) :-
	reassure_user("Generating compartment update expressions"),
	render(Language, procedure_start,
	       call(void, do_updatemodel, [real, start_time], 
			[int, phase]), 0,
	       UpdateProcDeclText),
	order_submodel_assignments(Phases, [], DeltaForm,
				   UpdatePasses, [], _),
	add_phase_conditions(UpdatePasses, -1, [], UpdateInstructions),
	all(compile, extract_action, [build(UpdateInstructions),
	    append(UpdateForm, [])]),
	do_assign_list( Language, UpdateForm, _, [],
			[[]], Used, [], Temp, Updates),
	render(Language, end(procedure), updatemodel, 0, Proc_ending),

	render_all(Language, variable_declaration, Temp, 4, TempDeclText),

	render( Language, comment, 'UPDATE PROCEDURE DECLARATION', 0,
							UpdateProcDeclComment),
	render( Language, comment, 'UPDATE COMPARTMENT VALUES', 4,
							CompComment),
	render(Language, comment, 'TEMPORARY VARIABLES FOR COMPARTMENT UPDATES',
				4, TempDeclComment),
	Blank = [''],
	append([UpdateProcDeclComment,Blank,UpdateProcDeclText,Blank,
		 TempDeclComment, Blank, TempDeclText, Blank,
		 CompComment,Blank,Updates,Blank,
		 Proc_ending,Blank], Decls).
*/

build_eval_proc(Language, Consts, ProcName, OrderedForm, Used,
		AllGraphs, Stream) :-
	all(compile, extract_action,
	    [build(OrderedForm), append(ActionForm, [])]),
	excrete(Language, comment, 'EVALUATION PROCEDURE DECLARATION', 0,
				Stream),
	nl(Stream),
	excrete(Language, procedure_start,
	       call(void, ProcName, [int, phase]), 0, Stream),
	nl(Stream),
	excrete(Language, comment, 'CONSTANT DECLARATIONS', 0, Stream),
	nl(Stream),
	all(render, excrete,
	    [unify(Language), unify(global_declaration),
	     build([[void, this, []] | Consts]), unify(0), unify(Stream)]),
	nl(Stream),
	excrete(Language, comment, 'STRUCTURE TYPE DECLARATIONS', 0, Stream),
	nl(Stream),
/* following section used to be c only */
	generate_graph_handlers(AllGraphs, GraphSetups),
	(ProcName = evalmodel, \+ GraphSetups = [],
	    refer_value(Language, phase, PhRef),
	    combine(Language, ==, [PhRef, -2], InitExpr),
	    excrete(Language, if_start, InitExpr, 4, Stream),
	    all(render, excrete,
		[unify(Language), unify(procedure_call), build(GraphSetups),
		       unify(8), unify(Stream)]),
	    excrete(Language, end(cond), initializing, 4, Stream);
	 \+ (ProcName = evalmodel, \+ GraphSetups = [])),
	nl(Stream),
	excrete(Language, comment, 'UPDATE FUNCTION VALUES', 4, Stream),
	nl(Stream),
	do_assign_list( Language, ActionForm, 4, Used, Stream),
	nl(Stream),
	excrete(Language, end(procedure), ProcName, 0, Stream),
	nl(Stream),
        fail; true. % need to backtrack to forget variable declarations

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% build_functions goes throught the functions and calculates their values. The
% list is ordered and then rendered into the appropriate form for assignment in
% the relevant language. Ratio is the multiplier to scale values in the inner
% loop to the standard preferred unit

build_submodel_functions( Language, Phases, Constants, StateForm, UpdateForm,
			  SortedForm, Used, AllGraphs, Stream) :-
	reassure_user("Ordering model execution assignments"),

	/* rough and ready -- phase NotDone means it never gets scheduled */
	order_all_assignments(Phases, StateForm, OrdStates, _),
	order_all_assignments(Phases, UpdateForm, OrdUpdates, _),
	order_all_assignments(Phases, SortedForm, Ordered, Lost), !,
	(member(Forgotten, SortedForm),
	    not_yet_ordered(Forgotten), !,
	    find_circle([Forgotten], Loop),
	    all(compile, unfinished_in, [build(Loop), build(CircSet)]),
	    raise_exception(circular_evaluation(CircSet));
	member(Awkward, Lost),
	    /* lost instructions can be caused by circularity elsewhere,
	    so check for that first */
	    \+ (order(Holdup, Awkward), not_yet_ordered(Holdup)),
	    Awkward = make(Tail, _,_,_,_),
	    % pick act because raising exception with self-ref term crashes GNU
	    raise_exception(ordering_failure(Tail));
	true),
	/* note state variables implemented by 'last' might refer to
	compartment values, hence must go before them */

	reassure_user("Generating code for model execution"),
	all(compile, build_eval_proc,
	    [unify(Language), unify(Constants),
	     build([updatemodel, advancemodel, evalmodel]),
	     build([OrdUpdates, OrdStates, Ordered]),
	     unify(Used), unify(AllGraphs), unify(Stream)]).

/* find_circle([Head | Chain], Loop) :-
	order(NewHead, Head),
	not_yet_ordered(NewHead),
	(append(Circle, [NewHead | _], [Head | Chain]),
	    Loop = [NewHead | Circle];
	 find_circle([NewHead, Head | Chain], Loop)).
This looks combinatorial but I have tested it with some pretty extreme
examples, and it's fast enough. Still, if a thing's worth doing... */

find_circle([Head | Chain], Loop) :-
	order(NewHead, Head),
	not_yet_ordered(NewHead), !,
	(append(Circle, [NewHead | _], [Head | Chain]), % this completes it
	    Loop = [NewHead | Circle];
	 find_circle([NewHead, Head | Chain], SubLoop),
	    (SubLoop = [], !, %this was fruitless, tag it and try another
		NewHead = make(_,_,_, [_,_,x | _], _),
		find_circle([Head | Chain], Loop);
	     Loop = SubLoop)); % found one further down
	Loop = []. % No leads from here, go back

match_levels([], []).
match_levels([make(_,_, Path, _,_) | Insts], Levels) :-
	match_levels(Insts, MoreLevels),
	(member(Path, MoreLevels), !,
	    Levels = MoreLevels;
	Levels = [Path | MoreLevels]).

/* dummy_order/2: a miniature version of the ordering process. Removes steps
that have no antecedent from the list; if any are left when it can no longer
do this, these must contain a dependency loop.

dummy_order(Steps, Core) :-
	select(Step, Steps, Rest),
	\+ (order(Prev, Step),
	       member(Prev, Rest)), !,
	    dummy_order(Rest, Core);
	Core = Steps.

get_circle_from/3: Takes a lot of instructions that contain a circularity,
and a bunch of same that have already been linked up, and returns a set
taken from both lists that constitute a circle. Should be obvious how it
works. Clue: since we have already removed any instruction without
antecedents in the list, chaining bacwards will always find a circle.

get_circle_from(Steps, [First | Linked], Circle) :-
	order(Last, First),
	(append(InLoop, [Last | _], Linked), !,
	    Circle = [Last, First | InLoop];
	select(Last, Steps, OtherSteps), !,
	    get_circle_from(OtherSteps, [Last, First | Linked], Circle)).

Procedure to clear memory at end of run */

make_exit_proc(Language, Instances, Dest) :-
	render(Language, procedure_start,
	       call(void, do_exitmodel), 0, FinalProcDeclText),

	render_all(Language, clear_memory, Instances, 4, Finalisers),

	render(Language, end(procedure), dummy, 0, Proc_ending),

	render( Language, comment, 'FREE ALL DATA STRUCTURES', 4,
							FinalProcDeclComment),
	Blank = [''],
	append([FinalProcDeclComment, Blank, FinalProcDeclText, Blank,
		Finalisers, Blank, Proc_ending], Decls),
	send_to_dest(Dest, Decls).

/* correct_graph_headers: building the code for the functions produces graph info
related to the variable being calculated, including intermediate variables, but when
editing the graphs at run time we want to refer to them by the final result, so
here we swap them round... 

correct_graph_header([Inter | G1], Inters, Dest) :-
	member(instance(internal, inter(_,_, Next), _, Inter, _), Inters), !,
	    correct_graph_header([Next | G1], Inters, Dest);
	Dest = [Inter | G1].
*/

unfinished_in(make(L, _,_,_,_), L).

/* merge_inters: takes the fullmodel and a list of function instances
that have been created to hold intermediate results. Each of the latter
includes a path spec which enables it to be added to the fullmodel at the
appropriate point. */

merge_inters([], M, M, []).

merge_inters([Function | Rest], Model, NewModel, Constants) :-
	Model = model(Functions, Submodels),
	(Function = instance(internal, inter(Path, _,_), _, Name, Type-Dims),
	    (append(LowPath, [sm(Top, _,_,_) | _], Path),
		append(BeforeSubs,
		       [instance(submodel, P2, xrefs(NextModel, X2,X3,X4),
				 Top, P5) | AfterSubs], Submodels), !,
		merge_inters([instance(internal, inter(LowPath, _,_), _, Name, 
				       Type-Dims)], NextModel, NewNext, []),
		append(BeforeSubs,
		       [instance(submodel, P2, xrefs(NewNext, X2,X3,X4),
				 Top, P5) | AfterSubs], NewSubs),
		InterModel = model(Functions, NewSubs);
		append(Functions, [Function], NewFunctions),
		% put new ones at end so others keep same serial numbers
		InterModel = model(NewFunctions, Submodels)),
	    Constants = MoreConstants;
	Function = instance(constant, _, Value, Name, Type-Dims),
	    Constants = [[Type, Name, Dims, Value] | MoreConstants],
	    InterModel = Model),
	merge_inters(Rest, InterModel, NewModel, MoreConstants).

/* extract_action: get the action part of a make instruction. More usually used
to make a dummy instruction from an action. */

extract_action(make(Effect, Conds-_,_,_, Actions), Actions) :-
	(nonvar(Effect), !; Effect = none),
	(nonvar(Conds), !; Conds = []).

/* extract_assignments creates the instructions that set the values of compartments
and functions within a submodel. It also creates the instructions that determine how
many individuals in each population submodel within it are created each round. */

extract_assignments(Instance, Path, Step, MaxStep, Swaps, Used,
		    ExtIncs, Inters, AssignList) :-
	Instance = instance(submodel, Id, xrefs(model(Functions, Submodels),
                                              _,_,_), _,_),
	(member(instance(alarm,_,_,elt(_, Al,_),_),
		Functions), !,
	    Path = [sm(_,_,_, fm_loop(_, Al))|_];
	    true),
/*	(setof(ParamUpdate,
	       input_params_in(Functions, Path, Step, ParamUpdate),
	       ParamUpdates), !;
	ParamUpdates = []),
*/	(Id has_class_refinement enum_types of ETS, !,
	    all(compile, make_et_spec, [unify(Id), build(ETS), build(ETS0)]);
	    ETS0 = []),
	all(compile, get_assignment,
	    [build(Functions),
	     unify(Path), unify(Step), unify(Swaps),
	     unify(Used), append(Inters0, []), append(AssignList0, [])]),
	all(compile, extract_submodel_assignment,
	    [build(Submodels),
	     unify(Functions), unify(Path),
	     unify(Swaps), unify(Step), biggest(MaxStep, Step), unify(Used),
	     merge_lists(ExtIncs, []),
	     append(Inters, Inters0), append(AssignList, AssignList0)]).

biggest(B1, B2, Big) :-
	Big is max(B1, B2).

make_et_spec(Id, Type-Mems, enum_type(Id, Type, Mems)).

make_et_fn(L, enum_type(Id, Type, Mems), ProcHeader) :-
	all(render, make_constant_string,
	    [unify(L), build([Id, Type | Mems]), build([IdStr | Strings])]),
	length(Mems, MemCount),
	ProcHeader =.. [setup_enum_type_data, IdStr, MemCount | Strings].

/* extract_submodel_assignment: this goes through the model listing all the expressions,
and generating any intermediate nodes that are needed. We then make a version
of the full model augmented with the extra nodes. */

extract_submodel_assignment(Instance, ParentFns,
			    Path, Swaps, TopStep, MaxStep, Used,
			    ExtIncludes, Inters, AssignList) :-

	Instance = instance(submodel, SmName, xrefs(Model, _, Bases, Assocs), 
			    Name, _-Dims),
	time_step_for(SmName, TopStep, Step),

	Model = model(Functions, _),
	pointer_from(Path, Ptr),
	/* bug flusher! (nonvar(Ptr); append_atoms(Name, pointer, Ptr)), */
	path_section_for(SmName, Name, Dims, Level, Ptr, NewPtr),
	append(Level, Path, LocalPath),
	/* Do not allow an associated model to be started until its
	bases have all been enumerated */

	get_swaps_and_waits(Instance, Bases, in, InSwaps, 
			    CurrentBaseMembershipsSet),
	get_swaps_and_waits(Instance, Assocs, out, OutSwaps,
			    LastLocalMembershipUsed),
	append([Swaps, InSwaps, OutSwaps], NewSwaps),
	append(CurrentBaseMembershipsSet, LastLocalMembershipUsed,
	       BasesEnumerated),
	
/* Now add the special instructions for more exotic types of submodels. The new_member
instruction is generated immediately after the pointer initialization (i.e., to run in
the init phase) for create nodes, and in the execute phase for immigration nodes, along
with dedicated instructions for reproduction and loss nodes. The latter all go in one
instruction because they will not require individual initialization routines. */

        (is_population(SmName), !,
	    BaseSides = [],
	    append_atoms(Name, count, Count),
	    Level = [sm(_,_,_, vm_loop(_,_,_, SetMems))],
	    GenInters = % some now in special population class
	    [ %instance(internal, inter(LocalPath, _,_), _, parentId, int-[]),
	      %instance(internal, inter(LocalPath, _,_), _, channelId, int-[]),
	     instance(internal, inter(Path, _,_),_, Count, int-[])],
	    (by_record(SmName), !,
		SetMems = -1,
		append_atoms(Name, made, NMade),
		SmInters =[instance(internal, inter(Path, _,_),_, NMade,
				     int-[]) | GenInters],
		get_dims_from_loops(Path, _, UseInds),
		length(UseInds, IdxN),
		CFn =.. [collect, arr(Ptr, NMade, []), Name, IdxN | UseInds],
		CreateRules = [make(completed(Name), [], LocalPath, -1,
				    [assign(arr(NewPtr, new_instance, []), 0)]),
			       % goes in advance proc so reload ignored, use -1
			       make(created(Name), [on_reload], Path, Step,
				    [CFn, init_mems(Ptr, Name, create([NMade]))])],
		% create in step -1 as membership only changes with file param
		Losses = [], ReproRules = [], ImmigRules = [];
		
	    /* generate instructions for each immigration, reproduction  etc.
	    node...*/
	    /* little botch-ette: all the population adjustments have to be
	    done in the same loop because cull leaves the metapointer at the
	    end of the instance list and the others expect to find it there.
	    So creation is done in the local time step although there are only
	    individuals to be created right after reset. Really, all of them
	    should be done in the same instruction.

Changes for Simile4.5: The population is no longer emptied on
reset. Instead the creation nodes are examined and the population
adjusted to fit them. This takes one instruction for all creation
nodes.
	    
	    (setof(make(created(Name), [culled(Name), InitSpec], Path, Step,
		[new_member(Ptr, Name, create(InitSpec))]),
		   InitName^X^U^(SmName has_part InitName,
			member(instance(creation, InitName, X,
					elt(_, InitSpec, _), U), ParentFns)),
		   CreateRules), !; 
	    CreateRules = []),
*/
	    SetMems = Step,
	        SmInters = GenInters,
	        (setof(CreateBox, InitName^X^U^(SmName has_part InitName,
					member(instance(creation, InitName, X,
					elt(_, CreateBox, _), U),
					       ParentFns)), Creators), !;
		    Creators = []),

		(setof(LossBox, S^X^U^member(instance(loss, S,X,
						      elt(_, LossBox, _), U),
					     Functions), Losses), !;
		    Losses = []),

		CreateRules = [make(culled(Name), [init_list(Name),
				 time | BasesEnumerated], Path, Step,
				[lose(Ptr, Name, Losses)]),
			   make(created(Name),
				[culled(Name), on_reset | Creators], Path, 0,
				[init_mems(Ptr, Name, create(Creators))])],
		% create in step 0 as membership may have changed during run
		(setof(make(bred(Name,InitSpec), [culled(Name), time], Path,
			    Step, [reproduce(Ptr, Name, InitSpec)]),
		   S^X^U^member(instance(reproduction, S,X,
					 elt(_, InitSpec, _), U),
			  Functions),
		       ReproRules), !; 
		    ReproRules = []),

		(setof(make(settled(Name,InitSpec),
			    [culled(Name), time, InitSpec], Path, Step,
			    [new_member(Ptr, Name, immigrate(InitSpec))]),
		       InitName^X^U^(SmName has_part InitName,
				     member(instance(immigration, InitName, X,
						     elt(_, InitSpec, _), U),
					    ParentFns)),
		       ImmigRules), !; 
		    ImmigRules = [])),
	    all(compile, unfinished_in,
		[build(ReproRules), build(ReproConds)]),
	    all(compile, unfinished_in,
	        [build(ImmigRules), build(ImmigConds)]),
	    append(ReproConds, ImmigConds, NewMemConds),
	    /* Something that will be done in the initialization procedure, to make sure we don't try to create any before we can run this procedure */
	    append([[make(can_enter(Name), [created(Name) | NewMemConds],
			  Path, Step, []),
		    make(enumerate(Name), [can_enter(Name)],
			 LocalPath, Step, []),
		    make(startable(Name), [init_list(Name)], Path, Step, []),
		    make(init_list(Name), [], Path, Step,
			 [assign(arr(Ptr, Name, []), 0)])],
		    CreateRules, ImmigRules, ReproRules], Specials);  

	/* For variable-membership submodels we must not run the generate step
	    before the bases are enumerated because running it prevents the
	    model's initialization being moved outside that of its parent */

	variable_size(SmName), !,
	    SmInters = [],
	    all(compile, get_base_side,
		[unify(LocalPath), build(InSwaps), build(BaseSides)]),
	    /* reverse(RevBaseSides, BaseSides),
	    this was necessary so index meanings are compatible with earlier
	    versions (not that they were...) */
	    all(ame_gen, enum_type_ref, [build(Dims), unify(SmName),
					 build(Sizes), build(_), build(_)]),
	    Level = [sm(_,_,_, vm_loop(_IndCount, Sizes, BaseSides, _))],
	    (setof(CondBox, member(instance(condition,_, function,
			elt(_, CondBox, _),_), Functions), Conds), !,
		TestExpr = Conds;
	    /* dummy generator node for other variable membership submodels */
	    member(instance(condition,_, id_function,
			elt(_, CondBox, _),_), Functions), !,
		Conds = [CondBox], TestExpr = Conds;
	    Conds = [], TestExpr = 1),
	    all(compile, convert_base_specs,
		[build(BasesEnumerated), build(BasesCleared)]),

	    /* can_enter is needed to do anything in the model, but it must
	    be an explicit precondition of existence_tested to make sure it
	    happens in the right phase */
	    Specials = [make(existence_tested(Name), [can_enter(Name) | Conds],
			     LocalPath, Step, [test(Name, NewPtr, TestExpr)]),
			make(enumerate(Name), [existence_tested(Name)],
			     LocalPath, Step, []),
			make(can_enter(Name),
			     [startable(Name) | BasesEnumerated], Path, Step,
			     []),
			make(init_list(Name), [], Path, Step,
			     [assign(arr(Ptr, Name, []), 0)]),
			make(startable(Name), [init_list(Name) | BasesCleared],
			     Path, Step, [reset_list(Ptr, Name)])];
	Level = [sm(_,_,_, fm_loop(Globs, _)) | _Loops],
	% its the _Loops that have the bounds!
	    all(compile, name_loop_vars, [build(Globs), unify(Used)]),
            [BaseSides, SmInters, Specials] = [[], [], []]),
	extract_assignments(Instance, LocalPath, Step, MaxStep, NewSwaps, Used,
			    SubIncludes, FnInters, AssignList0),
/* Now add an extra instruction if this needs an external proc */
	(SmName has_class_refinement external_code of ExtCode,
	member(include=Inc, ExtCode),
	\+ Inc = none, !,
	    merge_lists([Inc], SubIncludes, ExtIncludes),
	    member(procedure=Proc, ExtCode),
	    list_params_from("input", 1, AssignList0, ParamsIn),
	    list_params_from("output", 1, AssignList0, DirParamsOut),
	    delay_params_out_made([ext_done_for(Name)], DirParamsOut,
	                           AssignList0, AssignList1, Goals, ParamsOut),
	    append(ParamsIn, Goals, AllConds),
	    append(ParamsIn, ParamsOut, ArgCodes),
	    ExtInst = make(ext_done_for(Name), AllConds, LocalPath, Step,
	                  [call_ext_code(Proc, NewPtr, ArgCodes)]),
	    append(Specials, [ExtInst | AssignList1], AssignList);
	ExtIncludes = SubIncludes,
	    append(Specials, AssignList0, AssignList)),
	append(FnInters, SmInters, Inters).

list_params_from(BaseStr, N, Assigns, List) :-
	sicstus_write_to_chars(N, NStr),
	append(BaseStr, NStr, HeaderStr),
	member(make(Tgt, _,_,_,_), Assigns),
	name(Tgt, TgtStr),
	append(HeaderStr, TailStr, TgtStr),
	\+ (TailStr = [Next | _], \+ [Next] = "_"), !,
	M is N+1,
	list_params_from(BaseStr, M, Assigns, More),
	List = [Tgt | More];
	List = [].	

delay_params_out_made(_, [], A, A, [], []).
delay_params_out_made(PEfx, [Out | Mo], A, [make(Out, PEfx, R2, R3, []),
			make(def_set(Out), R1,R2,R3,R4) | APlus],
		      [def_set(Out) | MoDefs], [ScPtrOut | ScPtrMo]) :-
	select(make(Out, R1, R2, R3, R4), A, AMinus),
	delay_params_out_made(PEfx, Mo, AMinus, APlus, MoDefs, ScPtrMo),
	(R2  = [sm(_,_,_,_) | _], !,
	   ScPtrOut = ptr(Out); % scalar output -- pass pointer for it
	ScPtrOut = Out).

name_loop_vars(glob(LVar, _), Used) :-
	generate_name(c, fill, LVar, Used).

get_base_side(Locale, path_substitution(Exited, Entered, _), Exited) :-
	prefix(Entered, Locale), !;
	prefix(Locale, Entered).

get_swaps_and_waits(instance(submodel, ID, _,_,_), FarEnds, _, [], []):-
	var(FarEnds),
	    caption_for(ID, Lost),
	    raise_exception(bad_role(Lost));
	FarEnds = [].

get_swaps_and_waits(Instance, [base(Assoc, Link, Ptrs) | Rest], Dir,
	  [path_substitution(Exited, Entered, Link) | MorePathSwaps], Waits) :-
	find_name_host(Link, LinkWithAttrs),
	(LinkWithAttrs has_attribute last_membership of Delay, !;
	Delay = 0),
	
	(Dir = out,
	    get_route_between(Instance, Assoc, Exited, Entered),
	    Entered = [sm(_,_,_, vm_loop(_,_, AssocSides, _)) | _],
	    Assoc = instance(submodel, _, xrefs(_,_, Bases, _), _,_),
	    get_swaps_and_waits(Assoc, Bases, in, SwapsBack, _),
	    all(compile, get_base_side, [unify(Entered), build(SwapsBack),
					 build(AssocSides)]),
	    /* reverse(RevAssocSides, AssocSides),
	    Keeping my fingers crossed that removing this will not affect
	    operation*/
	    member(base(Instance, Link, FarPtrs), Bases),
	    get_base_ptrs(Exited, _, FarPtrs),
	    (Delay = 1, !,
		wait_for_submodels(Entered, TheseWaits);
	    TheseWaits = []);
	Dir = in,
	    get_route_between(Assoc, Instance, Exited, Entered),
	    get_base_ptrs(Exited, _, Ptrs), /* this actually sets them */
	    (Delay = 0, !,
		wait_for_submodels(Exited, TheseWaits);
	    TheseWaits = [time])),
	
	get_swaps_and_waits(Instance, Rest, Dir, MorePathSwaps, OtherWaits),
	append(TheseWaits, OtherWaits, Waits).

convert_base_specs(time, on_reset).
convert_base_specs(enumerate(Model), startable(Model)).

get_route_between(Start, Finish, Exited, Entered) :-
	ancestor(Start, Top, StartTree),
	ancestor(Finish, Top, EndTree), !,
	levels_to_path(StartTree, Exited, TopPtr, _),
	levels_to_path(EndTree, Entered, TopPtr, _).

ancestor(Instance, Instance, []).
ancestor(Instance, Top, [Instance | Higher]) :-
	Instance = instance(submodel, _, xrefs(_, Parent, _,_), _,_),
	ancestor(Parent, Top, Higher).

levels_to_path([], [], Ptr, Ptr).

levels_to_path([instance(submodel, SmName, _, Name, _-SmDims) | MoreLevels],
	       Path, TopPtr, LoPtr) :-
	path_section_for(SmName, Name, SmDims, Level, HiPtr, LoPtr),
	levels_to_path(MoreLevels, Higher, TopPtr, HiPtr),
	append(Level, Higher, Path).

name_from_elt(FullRef, Cond) :-

	(FullRef = IName*_Scale, !; FullRef = IName),
	IName = input(in_hierarchy, elt(Path, Name, _), none, _),
	wait_for_submodels(Path, Waits),
	(Name = import(_,_,_,_,_, PhaseSet, Src, _), !,
	(PhaseSet = 0, !,
	    Cond = [ints(Src) | Waits];
	Cond = [exts(Src) | Waits]);
	Cond = [Name | Waits]).

/*
insert_ptr(Path, search_from(_, Name, Ptr)) :-
	member(sm(Name, _, Ptr, _), Path).
*/
/* get_assignments takes the list of instance functions for all the
things that need to be evaluated in the model and turns them into a
list of 'make' functions which include information about how to order
the actions corresponding to them.*/

get_assignment(instance(Type, Node, Source, DestRef, _-DimTypes),
	       DestPath, SmStep, Swaps, Used, Inters, Assignments) :-
/*	Type = external, !,
	    (Inters = [],
	    Source = for_extern(CondElts, Tops),
	    all(compile, insert_ptr, [unify(DestPath), build(Tops)]),
	    all(compile, name_from_elt, [build(CondElts), append(Conds, [])]),
	    DestRef = elt(_, Dest, _),    
	    pointer_from(DestPath, Ptr),
	    ptr_to_last_vm(DestPath, BuiltWith),
	    append(Tops, [ext_eval_submodel(Node, arr(Ptr, Dest, []),
						   BuiltWith)], Xvl),
	    Assignments = [make(ints(Dest), [time], DestPath, _,
				[int_eval_submodel(Node, arr(Ptr, Dest, []),
						   BuiltWith)]),
			   make(exts(Dest), [time | Conds], DestPath, _, Xvl),
			   make(none, [time], DestPath, _,
				[update_submodel(Node, arr(Ptr, Dest, []),
						   BuiltWith)]),
			   make(none, [time], DestPath, _,
				[advance_submodel(Node, arr(Ptr, Dest, []),
						   BuiltWith)])]);
*/
/* Only make assignments for functions, for now, and
	    Do not make an assignment if we are expecting one on init/reset
	    from outside */
	is_parameter(Node, Is_P),
	DestRef = elt(_, Dest, X),    
	((Is_P = 2,
	    (Type = function, Tgt = Dest, Step = -1, Wait = [on_reload];
	    Type = init_function, Tgt = init(Dest),
		Step = 0, Wait = [on_reset]);
	 Is_P = 1,
	    Tgt = update(Dest),
	    (Type = function, Step = SmStep, Wait = [init(Dest), time];
	    Type = init_function, Step = 0, Wait = [on_reset])), !,
	all(ame_gen, enum_type_ref, [build(DimTypes), unify(Node),
				     build(Dims), build(_), build(_)]),
	    pointer_from(DestPath, DestPtr),
	    get_dims_from_loops(DestPath, _, SmInds),
	    make_inds_for(Dims, LocalPath, LocalInds),
	    append(LocalPath, DestPath, Path),
	    append(SmInds, LocalInds, Inds),
	    vars_only(Inds, VarInds),
	    length(VarInds, Count),
	    CollectFn =.. [collect, arr(DestPtr, Dest, LocalInds), Dest, Count
			  | VarInds],
	    Collects = [make(Tgt, Wait, Path, Step, [CollectFn])];
	Collects = []),
	((Is_P < 1,
	    (Type = init_function, !,
		UseList = [on_reset | RefList],
		Made = init(Dest),
		UseStep = 0;
	    (Type = id_function,
		UseList = [can_find_id(Node) | RefList];
	    member(Type, [function, loss]),
		UseList = RefList), !,
		Made = Dest,
		UseStep = SmStep),
	    SourceEqn = Source;
	Is_P = 1,
	    Type = function,
	    UseList = RefList, 
	    Made = init(Dest),
	    UseStep = -2,
	    apply_minmax(Node, Source, SourceEqn);
	member(Type, [compartment, immigration, reproduction]),
	  \+ Source = none,
	    UseList = RefList, 
	    Made = update(Dest),
	    UseStep = SmStep,
	    SourceEqn = Source),
	    
	(SourceEqn = with_phase(SmStep, GroundEqn);
	    GroundEqn = SourceEqn), !,
	final_assignment(GroundEqn, Node, elt(DestPath, Dest, X), Swaps,
			 UseStep, Used, Expr, Setups, Path, RefList,
			 AllInters),
	connect_params([make(Made, UseList, Path, UseStep, Expr) | Setups],
		       AllInters, Actions, Inters);
	Actions = [],
	Inters = []),
	((member(Type, [compartment, creation, immigration, reproduction]);
	        Is_P = 1;
	        Is_P = 2, Type = init_function), !,
	    Linkers = [make(Dest, [init(Dest), update(Dest)], DestPath, SmStep, [])];
	Linkers = []),
	append([Collects, Actions, Linkers], Assignments).

/* Now...when using a variable in the equation I have been putting
'made_at' in the conditions, the idea being that I have to exit any
loops that build the variable before accessing a value with a
different index at that level, so as to make sure they are all
made. This checks which indices are different, and makes 'made_at'
(renamed 'made_for') at that level.

This has been disabled, because it occasionally stopped iterative
constructs being built in loops over relation submodels. I should
really put it back, since a workaround is needed to build those
constructs anyway, but the system seems to work just fine without it
-- I'm guessing the ordering code is not allowing references to
different parts of an array to go in the same loop. Uncomment path
match to get it going again.

Actually I found an example where it didn't work fine (gridspread) so
have put it back for now. Inheritance workaround is to do all the
peocessing in the relation model. */

connect_params(AllInsts, AllInters, Insts, Inters) :-
	select(make(Tgt, Conds, PathPlus, Step, Acts), AllInsts, LeftInsts),
	select(made_at(Param, OrigPathPlus), Conds, MoreConds), !,
	    remove_non_loopers(PathPlus, Path),
	    remove_non_loopers(OrigPathPlus, OrigPath),
	    suffix(MatchPath, Path),
	    suffix(CommonPath, OrigPath),
	    MatchPath == CommonPath,
	    suffix(CommonPathPlus, OrigPathPlus),
	    remove_non_loopers(CommonPathPlus, CommonPath), !,
	    (CommonPath = OrigPath, /* comment out to disable */ !,
		ChangedInsts = [make(Tgt, [Param | MoreConds], PathPlus, Step,
				     Acts) | LeftInsts];
	    ChangedInsts = [make(Tgt, [made_for(Tgt, Param) | MoreConds],
				 PathPlus, Step, Acts),
		     make(made_for(Tgt, Param), [Param], CommonPathPlus, Step,
			  []) | LeftInsts]),
	    LeftInters = AllInters,
	    connect_params(ChangedInsts, LeftInters, Insts, Inters);
	Insts = AllInsts,
	    Inters = AllInters.

/* (was) in a Geraint stylee -- may need speeding up */
get_common_path(Path, OrigPath, CommonPath) :-
	suffix(CommonPath, Path),
	suffix(MatchPath, OrigPath),
	MatchPath == CommonPath, !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/*
get_updates([], _, []).

get_updates([instance(Type,_, incr(dt(Step), Expr), DestRef, _)
	    | Compartments], Step, Updates) :-
	member(Type, [compartment, immigration, reproduction]), !,
	DestRef = elt(_, Dest, _),
	final_assignment(Expr, DestRef, [], Step, _, NewAssign, _, Path, _,_),
	Updates = [make(Dest, [], Path, Step, NewAssign) | Rest],
	get_updates( Compartments, Step, Rest).

get_updates([instance(Type, Node, _, DestRef, _)
	    | Compartments], Step, Updates) :-
	Type = external, !,
	    DestRef = elt(Path, Dest, _),
	    pointer_from(Path, Ptr),
	    Updates = [make(none, [], Path, _,
			       [update_submodel(Node, arr(Ptr, Dest, []), [])])
		      | Rest],
	get_updates( Compartments, Step, Rest).

get_updates([_ | Comps], Step, Done) :-
	get_updates(Comps, Step, Done).

extract_updates(Instance, Path, Step, BaseStep, Updates) :-
	Instance = instance(submodel, _, xrefs(model(Functions, Submodels),
					       _,_,_), _,_),
	get_updates(Functions, Step, Updates0),
	extract_submodel_updates(Submodels, Path, Step, SubStep, Updates1),
	BaseStep is max(Step, SubStep),
	append(Updates1, Updates0, Updates).

extract_submodel_updates([Instance | Submodels], Path, TopStep,
			 BaseStep, Updates) :-
	Instance = instance(submodel, SmName, _, Name, _-Dims),
	time_step_for(SmName, TopStep, Step),
	pointer_from(Path, Ptr),
	(variable_size(SmName), !,
	    NextPath = [sm(Name, Ptr, _, vm_loop(0, _,_,_)) | Path];
	make_inds_for(Dims, Loops, Inds),
	    append([sm(Name, Ptr, _, fm_loop(Inds)) | Loops], Path,
		   NextPath)),

	extract_updates(Instance, NextPath, Step, NextStep, Updates0),
	extract_submodel_updates(Submodels, Path, TopStep,LaterStep, Updates1),
	append(Updates0, Updates1, Updates),
	BaseStep is max(NextStep, LaterStep).

extract_submodel_updates([], _,_, 0, []).
*/
/* input_params_in: This previously just made dummy assignments to input
parameters so things using them could be put in the right timestep. However
with version 2.34 it also makes the 'collect' functions whereby parameters ask
for values from the execution environment.

input_params_in(Vars, SmPath, SmStep,
		make(Tgt, Wait, Path, Step, [CollectFn])) :-
	member(instance(Type, Param, _, elt(_, Val, _), _-DimTypes), Vars),
	member(Type, [function, init_function]),
	all(ame_gen, enum_type_ref, [build(DimTypes), unify(Param),
				     build(Dims), build(_), build(_)]),
	is_parameter(Param, ParamType),
	ParamType > 0,
	pointer_from(SmPath, DestPtr),
	get_dims_from_loops(SmPath, _, SmInds),
	make_inds_for(Dims, LocalPath, LocalInds),
	append(LocalPath, SmPath, Path),
	append(SmInds, LocalInds, Inds),
	vars_only(Inds, VarInds, ParamType),
	(ParamType = 2,
	    Tgt = Val,
	    (Type = function, Step = -1, Wait = [on_reload];
	    Type = init_function, Step = 0, Wait = [on_reset]);
	ParamType = 1,
	    Tgt = update(Val),
	    (Type = function, Step = SmStep, Wait = [init(Val), time];
	    Type = init_function, Step = 0, Wait = [on_reset])),
	length(VarInds, Count),
	CollectFn =.. [collect, arr(DestPtr, Val, LocalInds), Param, Count
		      | VarInds].

vars_only: remove indices of vm models from those passed by 'collect'. Per-
record models were treated as vm if the parameter is variable, but are no longer as of v5.3. */

vars_only(List, AllVar) :-
	select(NonVar, List, Rest), \+ var(NonVar),
%	(NonVar = none; ParamType = 1, NonVar = ind(_, pop)), !,
	NonVar = none, !,
	vars_only(Rest, AllVar);
	List = AllVar.

/* sort_assignments: if a value makes no reference to time, and all
its conditions are evaluated on a long time step, it can also be
evaluated on that long time step. We start off looking for what can be
evaluated on step 0 (initialization) then 1, and so on. Assume no
compartments are updated on step 0 -- that would be silly!

Also pairs up names of vm models with the phases they get enumerated
in, so this info is available when they are used as bases

/* Experimental arse over tit version */

sort_assignments(Instructions, Phase, VMSpecPairs) :-
	member(NextInst, Instructions),
	goes_this_step(NextInst, Phase, VMSP),
	sort_assignments(Instructions, Phase, MorePs),
	append(VMSP, MorePs, VMSpecPairs);

	(Phase = -2, !,
	    VMSpecPairs = [];
	LongerPhase is Phase-1,
	    sort_assignments(Instructions, LongerPhase, VMSpecPairs)).

goes_this_step(NextInst, Phase, VMSpecPairs) :-
	NextInst = make(Efx, Conds-_, _, [DefP, NewP | _], _),
	var(NewP),
	DefP >= Phase,
	(Phase = -2;
	 /* member(AlLevel, Path), /* if anything from an alarm submodel goes,
	    everything else from it goes	    
	    AlLevel = sm(_,_,_, fm_loop(_, Al)),
	    nonvar(Al),
	    member(make(_,_, AlPath, _,_), Compartments),
	    member(AlLevel, AlPath); */
	Phase = -1,
	    member(on_reload, Conds);
	Phase = 0,
	    member(on_reset, Conds);
	member(time, Conds);
	member(SameStep, Conds),
	    member(SameStep, [Cond, later(Cond), this_step(Cond)]),
	    Cond = make(_,_,_, [_, SPhase | _], _),
	    nonvar(SPhase),
	    SPhase >= Phase),
	NewP = Phase,
	(Efx = enumerate(Name),
	    VMSpecPairs = [vm_spec_pair(Name, Phase)];
	VMSpecPairs = []), !.	
			 /*
sort_assignments(Instructions, MustDo, Compartments, Phase, SortedForm) :-
	Instructions = [], !,
	    SortedForm = Instructions;
	    
	NextInst = make(Efx, Conds, Path, DefP, Acts),
	(member(TryNow, MustDo),
	TryInst = make(TryNow, _,_,_,_),
	member_either(TryInst, Instructions, Compartments), !,
	    select_for([], TryInst, NextInst, Instructions, []);
	true),
	(DefP = Phase,
	    select(NextInst, Instructions, Others);
	get_next_evaluation(Instructions, Compartments, _,_, Others, NextInst),
	    \+ (Phase < DefP, member(time, Conds))), !,
	(setof(WaitCond, DefCond^(member(DefCond, Conds),
		member(DefCond, [later(WaitCond), this_step(WaitCond)])),
	      AlsoMustDo),
	    (append(AlsoMustDo, MustDo, NowDo),
		ToDo = Others;
	    NowDo = [not(NextInst) | MustDo],
		ToDo = Instructions);
	NowDo = MustDo,
	    ToDo = Others, !),
		sort_assignments(Others, NowDo, Compartments, Phase,
				 MoreSorted);
	    sort_assignments(Instructions
	SortedForm = [make(Efx, Conds, Path, Phase, Acts) | MoreSorted];
	
	ShorterPhase is Phase+1,
	    purge(Compartments, [make(_,_,_, ShorterPhase, _)], Fluctuators),
	    sort_assignments(Instructions, [], Fluctuators, ShorterPhase,
			     SortedForm).

delay_clearing: what this one does is, when you have a running total it
makes sure that the value is zeroed in the same phase as the total is
incremented, otherwise we may add the values to it several times. Note that
thanks to the radical implementation of subtotal, one total may have more than
one clearing instruction. 

delay_clearing(Mess, [make(clearing(Total), CConds, CPath, IPhase, CAct), 
		      make(cleared(Total), DConds, DPath, IPhase, DAct)
		     | Better]) :-
	select(make(clearing(Total), CConds, CPath, CPhase, CAct), Mess,
	       Mess1),
	member(make(Total, _,_, IPhase, _), Mess1),
	IPhase > CPhase, !,
	    select(make(cleared(Total), DConds, DPath, CPhase, DAct), Mess1,
		   Mess2),
	    delay_clearing(Mess2, Better).
*/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% order_assignments puts a list of make instructions (1) into order so that things are
% calculated when they're used. 2nd argument is the submodel path of the last
% one chosen; we prefer to keep assignments in a given submodel together, and
% move only along hierarchical lines.

/* New version where instead of being separated into lists for the different
phases, the instructions have an extra argument to say which phase they go in,
allowing there to be more than two. */

order_assignments(Phase, Path, RawAssign, All, OrderedAssign, Left) :-
	order_phase(Phase, Path, RawAssign, All, ThisPhase, Later, []),
	order_deeper_assignments(Phase, Path, Later, All, DeepAssign, Left),
	append(ThisPhase, DeepAssign, OrderedAssign),
	/* Now check if we picked any instructions at this level with 'later'
	conditions that we couldn't resolve: if so, redo order_phase. */
	\+ (member(make(_, Conds-_, _,_,_), OrderedAssign),
	       member(later(Hanger), Conds),
	       not_yet_ordered(Hanger),
	       Hanger = make(_,_, CPath, _,_),
	       remove_non_loopers(CPath, UCPath),
	       suffix(Path, UCPath)).

	
order_deeper_assignments(Phase, Path, Later, All, OrderedAssign, Left) :-
	(unfinished_submodels(Later, Phase, Path, Subs),
	    member(SmLevel, Subs),

	    /* try something from what is left -- no commitment yet */
	    get_pass_ends(SmLevel, StartPass, FinishPass),
	    order_submodel_assignments(Phase, [SmLevel | Path], Later, All,
				       SubPasses, LaterYet, TestPhase),
	    /* don't go to a level where I can't do anything (note test for
	    having done something was on what is outstanding, as there may
	    not actually have been any new commands generated -- if this causes
	    a problem, add a 'nop' command) */
	    member(SubPass, SubPasses),
	    \+ SubPass = [],		     
	    /* do not go into a sumbodel if I cannot get the existence
	    test done by the time I come out -- NOTE this is the only time I
	    need the list of all instructions in the make process, and would
	    dearly like to do without it.

	    Actually I also need it to pick useful instructions, but both here
	    and there I just need the existence tests, so now I select these
	    before ordering */
	    \+ (SmLevel = sm(Sm, _,_, vm_loop(_,_,_,_)),
		   member(make(existence_tested(Sm), _,_, [_,_,D], _), All),
		   var(D)),

	    /* For the time being, do not do anything that would use the
	    check-member feature */
	    \+ (number(TestPhase), TestPhase < Phase),
	    /* Do not go into an alarmed submodel unless I can get the whole
	    thing done in this pass */
			    
	    /* OK, have I just done an existence test for it? */
	    (number(TestPhase),
		
		/* yes: if test was done in a level above current,
		this is the chosen submodel: set conditions for testing new
	        instances. */
	    
	        (TestPhase < Phase,
		    GenCond = TestPhase;
		TestPhase = Phase,
		    GenCond = old), !,
		/* and add extra loops that go around generate statement --
		record test phase to use in later new instance tests */
		SmLevel = sm(Submodel, ParentPtr, Ptr,
			     vm_loop(_, Dims, MoreLoops, _)),
		ptr_to_last_vm(Path, ParentNew),
		make_inds_for(Dims, Sets, LocalInds),
		all(compile, ptr_to_last_vm,
		    [build(MoreLoops), append(VMPtrs, ParentNew)]),
		append([Sets | MoreLoops], BLoops),
		reverse(BLoops, AllLoops),
		all(compile, get_pass_ends,
		    [build([D1, D1 | AllLoops]), build([D2, D2 | OpenLoops]),
		     build(LastStep)]),
		all(inters, indices_for,
		    [build(AllLoops), append(LoopInds, [])]),
		append(LoopInds, LocalInds, Inds),

		/* At this point we need to replace the innermost loop with an
		assignment if using an id-based condition, and move the
		condition evaluation outside that loop...*/
		(append(Slower, [Now | Faster], SubPasses),
		    append(IdOpens, [TestCond,
				     _Cls | NoIdConds], Now),
		    TestCond = make(_, IdConds-_, _,_,
					  [assign(arr(Zn, TcVar, _), IdExpr)]),
		    member(can_find_id(IdCond), IdConds),
		    /* check condition is for this level...oh sod it */
		    /* find last looping construct */
		    (append(OuterLoops, [make(_,_,_,_,
					      [open_index(IdRef, loop(N))])
					| SmLoop], OpenLoops),
			member(SmLoop,
			   [[make(_,_,_,_, [start_submodel(_,_,_,_)])],[]]), !;
		    raise_exception(bad_instance_lookup(IdCond))),
		    append_atoms(Submodel, cond, IdVar),
		    /* OK Normally a reference to index(n) in a vm submodel
		    gets turned to an element of instanceid, but this will not
		    yet have been filled when assigning the cond, so replace
		    with direct references to loop inds */
		    replace_subexps(IdExpr, compile, indices_direct,
				    [Ptr | Inds], top_down, _, IxExpr),
		    IdRef = arr('', IdVar, []),
		    append(IdOpens, [make(none,[]-_,_,_,
					  [assign(IdRef, IxExpr)])
					| SmLoop], Next),
		    append(OuterLoops, Next, UseLoops),
		    append(Slower, [[make(_, IdConds-_, _,_, [assign(arr(Zn, TcVar, []), IxExpr>0&&IxExpr<=N)]) | NoIdConds] | Faster], UseSubPasses), !;
		UseLoops = OpenLoops,
		    UseSubPasses = SubPasses),
				    
		get_base_ptrs(BLoops, _, BasePtrs),
		extract_action(Outer, [bound_gen_loop(ParentPtr, Submodel)]),
		extract_action(GenStep, [generate(Submodel, ParentPtr,
				Ptr, GenCond, VMPtrs, Inds, BasePtrs)]),
		SmNew = [new_context(Ptr, TestPhase)],
		append([Outer | UseLoops], [GenStep], FirstStep);
		
	    /* no: just use start_submodel -- or give up on this
	    submodel if it was enumerated in a shorter time step than we
	    are doing now, or we might end up failing to set some values
	    in new ones */

	    \+ (SmLevel = sm(_,_,_, vm_loop(_,_,_, EnumPhase)),
		   EnumPhase > Phase), !,
		ptr_to_last_vm([SmLevel | Path], SmNew),
		FirstStep = [StartPass],
		LastStep = [FinishPass],
		UseSubPasses = SubPasses),
	    /* Now put new/timing conditions round higher-level passes */
	    add_phase_conditions(UseSubPasses, -2, SmNew, CondPass),

	    /* Now if I have done some submodel assignments, recurse at
		the same level */
	    order_assignments(Phase, Path, LaterYet, All, NewOrdered, Left),
	    append([FirstStep, CondPass, LastStep, NewOrdered],
		   OrderedAssign), !;
	OrderedAssign = [],
	    Left = Later).

indices_direct([MPtr | Inds], ind(IPtr, N), Ind, 0) :-
	MPtr == IPtr,
	nth0(N, Inds, Ind).

ptr_to_last_vm(Path, Ptrs) :-
	member(sm(_,_, Ptr, vm_loop(_,_,_,Phase)), Path), !,
	    Ptrs = [new_context(Ptr, Phase)];
	Ptrs = [].

get_base_ptrs([], [], []) :- !.
get_base_ptrs([Level | AlsoExited], Names, Ptrs) :-
	(Level = sm(Model, _, Ptr, _),
	    Names = [Model | NOthers],
	    Ptrs = [Ptr | POthers];
	Level = set(_,_),
	    Names = NOthers,
	    Ptrs = POthers),
	get_base_ptrs(AlsoExited, NOthers, POthers).

/* No need for a phase test on the last group, it is always executed
(except at the top level, in case this dll has been included in a larger
model which includes a shorter time step -- but that is done separately) */

add_phase_conditions([LastPhase], _,_, LastPhase) :- !.

add_phase_conditions([Group | Groups], Phase, Ptrs, Insts) :-
	NextPhase is Phase+1,
	add_phase_conditions(Groups, NextPhase, Ptrs, Rest),
	(Group = [], !, Insts = Rest;
	all(compile, relevant, [unify(Phase), build(Ptrs),
				append(UsePtrs, [])]),
	    extract_action(StartGroup, [check_phase(Phase, UsePtrs)]),
	    extract_action(FinishGroup, [finish_level]),
	    append([StartGroup | Group], [FinishGroup | Rest], Insts)).

relevant(Phase, new_context(Ptr, EnumPhase), UseContext) :-
	Phase < EnumPhase, !,
	    UseContext = [new_context(Ptr, EnumPhase)];
	UseContext = [].

order_phase(Phase, Path, RawAssign, All, ThisPass, Later, Taboo) :-
	pick_useful_instruction(All, Path, Instruction),
	get_next_evaluation(RawAssign, Path, Phase, Others, Instruction),
	\+ member(Instruction, Taboo),
	(Instruction = make(_,_-Deps,_, [_,_, Phase | _], _),
	all(compile, select_ready, [build(Deps), append(Assign, Others)]),
	    order_phase(Phase, Path, Assign, All, Rest, Later, Taboo),
	    ThisPass = [Instruction | Rest];
	(delayable(Instruction); !, fail),
	    order_phase(Phase, Path, RawAssign, All, ThisPass, Later,
			[Instruction | Taboo]));
	ThisPass = [],
	    Later = RawAssign.

delayable(make(_, Conds-_, _,_,_)) :-
	member(later(_), Conds), !.

/* insert_enum_phases: when we find an enumerate instruction, we want to
make sure that any time later we go into its submodel, the path will tell us
which phase the submodel was enumerated (had its membership decided) in. So
here we instantiate the 4th arg of vm_loop to the phase in all the paths... */

insert_enum_phases(_, []).

insert_enum_phases(vm_spec_pair(Name, Phase),
			 [make(_,_, Path, _,_) | Insts]) :-
	(member(sm(Name, _,_, vm_loop(_,_,_, Phase)), Path), !; true),
	insert_enum_phases(vm_spec_pair(Name, Phase), Insts).	

/* This one just inserts the shortest time step into any undecided phases.
Oh, and switches the conditions for references to their instructions.
set_free_phases([], _).
set_free_phases([make(_,_,_, Ph, _) | Insts], Phases) :-
	(nonvar(Ph), \+ Ph = Phases; Ph = Phases),
	set_free_phases(Insts, Phases). */

set_free_phases(OldForm, Phase, NewForm) :-
	reassure_user("Cross-referencing effects and conditions"),
	all(compile, convert_form,
	    [build(OldForm), unify(Phase), build(NewForm), build(Refs)]),
	all(compile, find_member, [build(NewForm), build(Refs), unify(NewForm)]),
	all(compile, close_dep_list, [build(NewForm)]), !.

convert_form(make(T1, Conds, Path, Ph, T5), Phase,
	     make(T1, NewC-_Deps, Path, [Ph | _], T5), Refs) :-
	(nonvar(Ph), \+ Ph = Phase; Ph = Phase),
	(T5 = [assign(SV, SV+stage_incr(_,_,_))], !,
	    Refs = [], NewC = []; % no order needed in update
	(\+ member(T1, [lastvalue(_), completed(_)]),
				% can_enter irrelevant in state
	    member(sm(Name,_,_, vm_loop(_,_,_,_)), Path), !,
	    ECs = [earlier(can_enter(Name)) | Conds];
	ECs = Conds),
	all(compile, handle_key_functors,
	    [build(ECs), build(NewC), append(Refs, [])])).

handle_key_functors(OldCond, NewCond, Refs) :-
	member(OldCond, [ % keyword conditions
time, % Action to be done in its submodel's phase, even if conds ready earlier
on_reset, % Action to be done in reset phase, even if conds ready earlier
on_reload, % Action to be done only after setting fixed parameters
externs_done, % wait till stuff outside this submodel dll is done
can_find_id(_)]), % dummy to do with one-sided enumeration
	    NewCond = OldCond,
	    Refs = [];
	(OldCond =.. [KeyFunc, RealCond],
	    (member(KeyFunc, [ % keyword functors
this_step, % Cond to be made in same phase, earlier or later
later]), !, % Cond to be made in same program loop, earlier (?) or later
		Refs = [nodep(Ref)];
	    member(KeyFunc, [ % keyword functors
earlier]), !, % Cond to be made earlier in the program but phase dont matter
% (or maybe also has to be earlier -- check that out)
		Refs = [Ref]),
	    NewCond =.. [KeyFunc, Ref];
	 RealCond = OldCond,
	    NewCond = Ref,
	    Refs = [Ref]),
	unfinished_in(Ref, RealCond).

find_member(Dep, Conds, Full) :-
	all(compile, add_to_deps, [unify(Dep), build(Conds), unify(Full)]).

add_to_deps(Dep, Cond, Full) :-
	Cond = nodep(Ref), !,
	    member(Ref, Full);
	member(Cond, Full), !,
	    Cond = make(_,_-Deps, _,_,_),
	    member(Dep, Deps);
	Cond = make(Act, []-_, [], [-2, -2, -2 | _], []),
	    (member(Act, [lastvalue(_), completed(_), update(_)]);
				% conditions that may not need making
	    raise_exception(cond_not_found(Act))).

close_dep_list(make(_,_-Deps, _,_,_)) :-
	length(Deps, _N).

made_in(Feature, sm(Submodel, _,_, vm_loop(_,_,_,_)), Pass) :-
	Test =.. [Feature, Submodel],
	member(make(Test, _,_,_,_), Pass).

order_all_assignments(Phase, All, Done, Left) :-
	all(compile, select_ready, [build(All), append(Ready, [])]),
	all(compile, select_ext_tests, [build(All), append(XTests, [])]),
	order_all(Phase, Ready, XTests, Done, Left).

order_all(Phase, Undone, All, Done, Left) :-
	order_submodel_assignments(Phase, [], Undone, All, NowDone, NowLeft, _),
	(NowLeft = Undone, !, /* couldnt do any */
	    Done = [],
	    Left = NowLeft;
	add_phase_conditions(NowDone, -2, [], NowDoneForm),
	    order_all(Phase, NowLeft, All, ThenDone, Left),
	    append(NowDoneForm, ThenDone, Done)).

select_ready(All, Ready) :-
	All = make(_, Conds-_, _,_,_),
	member(Cond, Conds),
	(Cond = RealCond; Cond = earlier(RealCond)),
	not_yet_ordered(RealCond), !,
	Ready = [];
	Ready = [All].

select_ext_tests(All, XTests) :-
	All = make(existence_tested(_), _,_,_,_), !,
	XTests = [All];
	XTests = [].

order_submodel_assignments(Phase, Path, RawAssign, All,
			   OrderedPasses, Left, FoundTest) :-
	Phase < -2, !,
	    OrderedPasses = [],
	    Left = RawAssign;
	NextPhase is Phase-1,
	    order_submodel_assignments(NextPhase, Path, RawAssign, All,
				       HighPasses, Later, DoneTest),
	    (number(DoneTest), !,
		OrderedPasses = HighPasses,
		FoundTest = DoneTest;
	    order_assignments(Phase, Path, Later, All, LastPass, Left),
		(Path = [TestModel | _], !,
		    (made_in(existence_tested, TestModel, LastPass), !,
			FoundTest = Phase;
		    true);
		true),
		/* might not need a start/finish pair for these non-loopers */
		get_non_looping_levels(Path, LastPass, Levels),
		all(compile, get_pass_ends,
		    [build(Levels), build(RStarts), build(Finishes)]),
		reverse(RStarts, Starts),
		append([Starts, LastPass, Finishes], Pass),
		append(HighPasses, [Pass], OrderedPasses)).

get_non_looping_levels(_Path, [], []).
get_non_looping_levels(Path, [make(_,_, IPath, _,_) | More], Levels) :-
	get_non_looping_levels(Path, More, MoreLevels),
	(var(IPath), !, /* instruction with dummy path */
	    Levels = MoreLevels;
	(Path = [],
	    UsePath = IPath;
	Path = [LastLoop | _],
	    append(UsePath, [TryLastLoop | _], IPath),
	    TryLastLoop == LastLoop),
	    /* note == used in futile attempt to stop similar levels
	    codesignating -- put more info in level struct to stop this */
	suffix(NLPart, UsePath),
	\+ (member(Looper, NLPart), open_separately(Looper)), !,
	merge_lists(NLPart, MoreLevels, Levels)).

get_pass_ends(Level, StartInit, Finish) :-
	(Level = catch(Ind, Bound), !,
	    extract_action(StartInit, [catch(Ind, Bound)]);
	Level = set(Ind, IndSrc), !,
	    extract_action(StartInit, [open_index(Ind, IndSrc)]);
	Level = sm(Submodel, ParentPtr, Ptr, Inds),
	    extract_action(StartInit,
		[start_submodel(Submodel, ParentPtr, Ptr, Inds)])),
	extract_action(Finish, [finish_level]).

prepares(V, F) :-
	member(F, [element(V), increment(V)]).

/* Choose next submodel in which to evaluate assignments. */

unfinished_submodels([], _,_, []).

unfinished_submodels([make(_,_, PathPlus, [_, FoundPhase | _], _) | Waiting],
		     Phase, Current, Subs) :-
	unfinished_submodels(Waiting, Phase, Current, MoreSubs),
	(Phase >= FoundPhase,
	    remove_non_loopers(PathPlus, Path),
	    copy_term(Path, FreePath),
	    append(Extra, Current, FreePath),
	    last(Extra, NewLoop),
	    (member(NewLoop, MoreSubs),
		Subs = MoreSubs;
	    Subs = [NewLoop | MoreSubs]), !;
	Subs = MoreSubs).

get_next_evaluation(Assignments, Path, Phase, Remainder, Next) :-
	select(Next, Assignments, Remainder),
	not_yet_ordered(Next),
	Next = make(_, _, IPath, [_, Phase | _], _),
	remove_non_loopers(IPath, Path).
	/* now keep ready instructions separate so no need to check readiness
	\+ (member(Prereq, Dependencies),
	       \+ Prereq = Next,
	       (not_yet_ordered(Prereq);
		Prereq = earlier(GenPrereq),
		   not_yet_ordered(GenPrereq);
		member(Prereq, Keys))).
    new condition -- do not do something that something else needs done later 
	\+ (member(NeedsItLater, Assignments),
	       \+ NeedsItLater = Next,
	       not_yet_ordered(NeedsItLater),
	       NeedsItLater = make(_, LocalConds, _,_,_),
	       member(later(Next), LocalConds)).*/

pick_useful_instruction(All, Path, Next) :-
	member(sm(Name, _,_, vm_loop(_,_,_,_)), Path),
	/* get longest suffix first */
	Priority = make(existence_tested(Name), _, TestPath, _,_),
	member(Priority, All),
	not_yet_ordered(Priority), !,
	    select_for(TestPath, Priority, Next);
	true.

/* select_for will return priority node or an action that leads to it. */

select_for(Path, Priority, Next) :-
	Next = Priority;
	order(Needed, Priority),
	    not_yet_ordered(Needed),
	    Needed = make(_,_, GenPath, _,_),
	    suffix(Path, GenPath),
	    select_for(Path, Needed, Next).

not_yet_ordered(make(_,_,_, [_,_, IsOrdered | _], _)) :-
	var(IsOrdered).

find_antecedent(Chain, TestFn, TestData, Found) :-
	member(make(_, Conds-_, _,_,_), Chain),
	member(Prev, Conds),
	Prev = make(_,_,_, [_,_,Cur | _], _),
	var(Cur), Cur = 1, !,
	/* above cut is important -- we do not want to retry selection. If this
	one gets us nowhere we will call the procedure again with it removed
	from the list, which avoids searching the same bit of tree again.

	Next bit means if this rule is retried we do not look for antecedents
	of something that satisfied the condition. */

	TestCall =.. [TestFn, Prev, TestData],
	(call(compile:TestCall), !,
	    (Found = Prev;
	    find_antecedent(Chain, TestFn, TestData, Found));
	find_antecedent([Prev | Chain], TestFn, TestData, Found)).

outside_loop(make(_,_, Path, [_, NPhase | _], _), LoopedPath-Phase) :-
	\+ NPhase == Phase, !;
	remove_non_loopers(Path, ShortPath),
	\+ suffix(LoopedPath, ShortPath).
	
order(Cond, make(_, Conds-_, _,_,_)) :-
	member(Cond, Conds);
	member(earlier(Cond), Conds).

member_either(X, A, B) :-
	member(X, A);
	member(X, B).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
remove_non_loopers(Path, LoopsOnly) :-
	append(AllLoops, [NotLoop | SomeLoops], Path),
	\+ open_separately(NotLoop), !,
	remove_non_loopers(SomeLoops, AlsoAllLoops),
	append(AllLoops, AlsoAllLoops, LoopsOnly);
	Path = LoopsOnly.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* When we open a submodel we normally open all those inside it at the same
time, but we need to wait if (a) it is a looping level (so we don't do anything
more often than we have to) or (b) if it needs an index expression (so the
variables used are made before we open it) */

open_separately(Level) :-
	loops(Level);
	Level = sm(_,_,_, fm_loop(Inds, Alarm)),
	(member(I, Inds),
	\+ I = glob(_,_);
	    nonvar(Alarm)).

generate_graph_handlers([], []).

generate_graph_handlers([GraphData | AllGraphs], [Setup | AllSetups]) :-
	Setup =.. [setup_graph_data | GraphData],
	generate_graph_handlers(AllGraphs, AllSetups).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% name_components instantiates the unground parts of InstanceList which correspond
% with components, using names specified in the KR or generated ones if no 
% specified names exist.

name_components( _, [], _, []).

name_components(Language, [instance(_Type, Node, _, elt(_, Var, _), _)
			  | Compartments], Used, Graphs) :-
	caption_for(Node, Name),
	generate_name( Language, Name, Var, Used),
	(Node has_class_refinement table_data of
	[file='/graph/', data=[YLow, YHigh, YSpan],
	 indices=[XLow, XHigh, XSpan, Range], current=PointList,
	 units=_, _, dims=NumPts | _], !,
	    nth(GraphNo, Used, Var),
	    /* Keep tcl working till it uses c++ graph access */
	    Graphs = [[GraphNo, XLow, XHigh, XSpan, YLow, YHigh, YSpan,
		       Range, NumPts | PointList] | TGraphs];
	    Graphs = TGraphs),
	name_components( Language, Compartments, Used, TGraphs).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_to_dest(Stream, Stuff) :-
	do_writing(Stuff, Stream).
