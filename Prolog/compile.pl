/******************************************************************************
*** COMPILATION module. This module contains all the templates necessary   ****
*** to compile AME code. Everything is parameterised by language, BASIC    ****
*** being the starting point.                                              ****
******************************************************************************/

sicstus_module( compile, [compile/3] ).

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

:- dynamic(error_free/1).

compile( Language, Parent, DestDir) :-
/*	tk_scrub_run(Parent, 0),
	(Language = tcl, !,
	    unseparate(SeparateNodes);
	list_interconnects(Parent)),
*/	tk_update_infobox(pl_check, []),
	/* This is a stopgap, we should really update a property of the
	submodel containing the destination whenever a link is added or
	deleted so only to do these checks when needed */
	asserta(error_free(build)),
	catch(build_instances(Language, DestDir, Parent, Parent, 1, _,_,_,_),
	      Err, 
	      (Err = aborted, !; % no further message needed
		  retractall(error_free(build)),
% It really as the wrong thing to do to have the help reference as an
% argument to query(). It should be in messages.tcl, along with the
% text strings, since we are unlikely to ever want to offer different
% help pages with the same dialogue.		  
		  (Err = circular_evaluation(_Set), !,
		      Help = circular;
		    Help = execution),
		  query(Err, error, Help, [ok], _))),
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
	build_interconnects
	(Node, []).
	
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
	(setof(Issue, check_level_for_reds(TopNode, Parent, Issue), Issues),
	    retractall(error_free(build)),	    
	    (all(ame_gen, query, [build(Issues), unify(warning), unify(top),
				  unify([abort]), unify(more)]), fail;
	    throw(aborted));
	Parent has_model_refinement c_new of 0, !,
	    Parent has_changed_model_refinement c_new of 1,
	    ChangeTop = 1,
	    LocalFnsUsed = [],
	    LocalExtLibs = [];
	LocalFnsUsed = FnsUsed,
	    LocalExtLibs = ExtLibs),

	(( %Parent has_class_refinement separate of 1;
	  error_free(build),
	   backup'><'is_toplevel(Parent)), !,
	    /* we need an executable for this level */
	    (Language = c,
	        (Parent has_model_refinement c_new of OldTgt;
		    OldTgt = 1), !;
	    /* if no c_new look for dll from save file with 1 in name */
	    OldTgt = 0),
	    check_directory(CheckDir),
	    % Only create directory if building code -- for now I
	    % only build code for top-level models so do not need
	    % directories for others in case their children create
	    % code
	    windowize(CheckDir, WCheckDir),
	    check_exec_fns_fresh(Language, WCheckDir, OldTgt, FnsUsed, RStrs),
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
		    % delete old code, including c++ v1 as 1 may mean last
		    % build was tcl, or get sought after save/restore
		    all(compile, delete_prog, [unify(CheckDir),
			build(['.tcl', '1.cpp', '.dll', '1.so', '.dylib'])]),
		    (Language = c, Extn = '.cpp';
		     Language = tcl, Extn = '.tcl'),
		    tk_update_infobox(pl_inst, []),
		    instantiate_all(Parent, Model),
		    append_atoms([WCheckDir, '/', model, Extn], WProgName),
		    open_native(WProgName, write, Stream),
		    on_exception(Puke,
				 protected_build(Language, Stream, MyStep, 
						 Model, Includes),
				 (reclose(Stream), raise_exception(Puke))),
		    close(Stream),
		    Fuss = 1),
		dialogue'><'tk_update_infobox(pl_comp, []),
	     (Language = tcl, !,
		 Tgt = 'model.tcl';
	     compile_c_program(CheckDir, ExtLibs, Fuss, Tgt),
		 (Tgt = -1, !, fail;
		  Tgt > 0,
		  (Parent has_changed_model_refinement c_new of Tgt;
		      Parent has_new_model_refinement c_new of Tgt),
		    backup'><'finish_move(Parent, 0)))),
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
	\+ image'><'draws_complete(VisEntity),
	abs_path_name(Submodel, TopNode, OuterText),
	caption_for(VisEntity, RedText),
	menu'><'select_all_in(Submodel, base), /* make sure the red shows */
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
	is_population(Submodel),
	\+ (find_all_comps(Submodel, SmChannel),
	       SmChannel is_of_sort value_outside),
	caption_for(Submodel, OuterText),
	Wrinkle = no_seed_param(OuterText);
	\+ is_population(Submodel),
	find_all_comps(Submodel, SmChannel),
	SmChannel is_of_sort pop_only,
	caption_for(Submodel, OuterText),
	caption_for(SmChannel, InnerText),
	Wrinkle = misplaced_channel(InnerText, OuterText);
	variable_size(Submodel),
	contains(Submodel, Param),
	appears(Param),
	is_parameter(Param, N),
	(Param is_of_sort discrete -> N>1 ; N>0),
	caption_for(Submodel, OuterText),
	caption_for(Param, InnerText),
	Wrinkle = param_in_vm_model(InnerText, OuterText);
	find_all_comps(Submodel, Fn),
	find_type(Fn, function),
	get_host(Fn, Cond),
	find_type(Cond, condition),
	Fn has_class_refinement value of Val,
	instance'><'is_lookup_cond(Val, _),
	list_index_meanings(Submodel, [ind_spec(_,_,_, Link) | _]),
	\+ (Link = none; Link has_attribute can_lookup of 1),
	caption_for(Link, LinkText),
	caption_for(Submodel, OuterText),
	Wrinkle = lookup_not_allowed(OuterText, LinkText);
	fail.

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
	FullModel = model(_Channels,
			  [instance(submodel, Top, xrefs(_,_,_), _,_)]), 
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
		      channelId, version,
		      on_step, on_reset, /* dummy conditions */
		      use_param_state, /* indicates file parameter */
		      id, dims, /* arguments to extractor proc */
		      next, instanceid, new_instance,
		      cause | _], % dummy arg to event proc
	/* system vars in submodel */
/* we cannot change names of external procedures, so add them to the used */

        (setof(ExtProc, uses_ext_proc(Top, ExtProc), ExtProcs), !;
            ExtProcs = []),
	append(Keywords, ExtProcs, BuiltIn),
        append(BuiltIn, LocalNames, Used),

/* This gives names in the target programming language to all the variables, 
structures corresponding to submodels, structure types, pointers and other 
bits and pieces */

	tk_update_infobox(pl_name, []),
	declare_structure(Language, FullModel, Used, AllGraphs),

	(
% File writing starts here
	send_to_dest(Stream, ['#include <support1.cpp>']),
	tk_update_infobox(pl_expr, []),
	extract_assignments(instance(submodel, root, xrefs(FullModel, _,_),
				     _,_), [], [], TopStep, Phases, [], Used,
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
	  % This sets default time step of anything not done in a particular
	  % step to that of its submodel
	PhasesWSub is Phases+1,
	set_free_phases(ReevaluateForm, PhasesWSub, NewForm),
	  % This marks state variable changes as going in the update phase
	all(compile, mark_update_insts, [build(NewForm), append(Marked, [])]),
	  % check for limit events also goes in sub-step
	all(compile, mark_limit_checks,
	    [build(NewForm), append(CondsInSubStep, Marked)]),
	  % this puts everything in the longest possible time step
	check_functions(NewForm, Phases, CondsInSubStep),
	/* first off, unify all matching vm level specs in the two lists so
	that those that are completed when ordering their condition nodes
	can be used later */
	all(compile, get_vmsps, [build(NewForm), append(VMSPs, [])]),
	all(user, arg, [unify(3), build(NewForm), build(AllPaths)]),
	insert_enum_phases(VMSPs, AllPaths),

	state'><'version_is(VStr),
	state'><'edition_is(Edition),
	library'><'count_functions(Top, FnCount),
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
	     build([[void, this, []] | Constants]),
	     unify(0), unify(Stream)]),
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
	% the /* in the above line does not start a comment, nor that in this */
        all(user, get_native, [build(ExtIncs), build(UExtIncs)]),
	append([FnIncs, LocalIncs, UExtIncs], Incs),
	all(utility, append_atoms,
	    [unify('#include "'), build(Incs), build(PartIncs)]),
	/* the " in the above line does not start a quoted string */
	all(utility, append_atoms,
	    [build(PartIncs), unify('"'), build(FullIncs)]),
	/* the " in the above line does not start a quoted string */
	send_to_dest(Stream, FullIncs),
	
	tk_update_infobox(pl_const, []),
	excrete(Language, comment, 'CONSTANT DECLARATIONS', 0, Stream),
	all(compile, excrete,
	    [unify(Language), unify(variable_declaration), build(Constants),
	     unify(0), unify(Stream)]),
	
	tk_update_infobox(pl_struct, []),
	excrete(Language, comment, 'STRUCTURE TYPE DECLARATIONS', 0, Stream),
	
	RootInstance = instance(submodel, root, xrefs(AugmentedModel, [],_),
				'AME_model', 'AME_model'-[]),
	generate_main_decls(Language, RootInstance, EndTopType, Stream),

	build_submodel_functions(Language, BoostPhases, Constants,
				 NewForm, Marked, Used, AllGraphs, Stream),
	make_exit_proc(Language, RootInstance, Stream),
	excrete(Language, procedure_defn, [int, do_evalmodel(int)], 0, Stream),
	  
	send_to_dest(Stream, EndTopType),
	fail;

	insert_metadata(Language, FullModel, Used, Stream),
	send_to_dest(Stream, ['#include <support2.cpp>'])

	/* OK at this point we need to free all the memory we possibly can;
	fail through everything, and trust that I can ignore what was 'used'
	cos we are back in the top namespace... */
	
	).

insert_metadata(Language, FullModel, Used, Stream) :-
	tk_update_infobox(pl_meta, []),
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
	pick_types(Vars, [function, init_function, id_function, al_function,
			  state_fn, loss,
			  internal, external, magnitude, limit], NamedVars),
	name_components( Language, NamedVars, Used, Graphs),
	append(SmGraphs, Graphs, AllGraphs).

declare_submodel_structures(_, [], _, []).

declare_submodel_structures(Language, [Instance | Instances], Used, Graphs) :-
	Instance = instance(submodel, Node, xrefs(Model, Bases, _), 
		Name, Type-_),
	caption_for(Node, Capt),
	generate_name(Language, Capt, Name, Used, [type, made]),
	append_atoms(Name, type, Type),
	make_assoc_loop_names(Language, Node, Used, Bases),
	declare_structure(Language, Model, Used, HeadGraphs),
	declare_submodel_structures(Language, Instances, Used, TailGraphs),
	append(HeadGraphs, TailGraphs, Graphs).

make_assoc_loop_names(_,_,_, []).

make_assoc_loop_names(L, Node, Used, [base(BaseSm, Link, Ptrs) | Bases]) :-
	caption_for(Link, LinkName),
	invent_ptr_names(L, LinkName, BaseSm, Node, Used, Ptrs),
	make_assoc_loop_names(L, Node, Used, Bases).

invent_ptr_names(L, LinkName, BaseSm, Node, Used, Ptrs) :-
	contains(BaseSm, Node), !,
	    Ptrs = []; % 19/12/02: does this ever happen...?
            % 12/04/11: I'm pretty confident it does not
	    % 03/05/11: Yes it does, it's the boundary for the recursion
	caption_for(BaseSm, BaseCapt),
	    append_atoms(LinkName, BaseCapt, Context),
	    append_atoms(Context, ptr, PtrBase),
	    generate_name(L, PtrBase, Ptr, Used),
	    Parent has_part BaseSm,
	    invent_ptr_names(L, LinkName, Parent, Node, Used, MorePtrs),
	    Ptrs = [Ptr | MorePtrs].

mark_update_insts(Act, Add) :-
	Act = make(_,_,_, [update | _], [assign(SV, Src)]),
	    member(Src, [SV, SV+stage_incr(_,_,_,_,_)]), !,
	    Add = [Act];
	Act = make(_,_,_, [eval | _], _),
	    Add = [].

mark_limit_checks(Act, Add) :-
	Act = make(checked(_), _,_,_,_), !,
	    Add = [Act];
	Add = [].

% anything that affects a compartment has to go in the sub-shortest time step
% so R-K integration works. 
update_antes_to_step(List, Step) :-
	List = [make(_, Conds-_, _,_,_) | Rest], !,
	all(compile, mark_unstepped,
	    [build(Conds), unify(Step), append(Marked, Rest), unify(no)]),
	update_antes_to_step(Marked, Step);
	true.

mark_unstepped(Cond, Set, Add, DoSquirts) :-
	member(Cond, [Act, later(Act), this_step(Act)]),
	Act = make(Tgt, _,_, [_,_, Step | _], _),
	(\+ Tgt = tweaked(_); DoSquirts = yes),
	var(Step), !,
	Step = Set,
	Add = [Act];
	Add = [].
	    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% check_functions tests for circularity, then puts each function
% evaluation into the slowest time step in which it needs to be updated

check_functions(Functions, Steps, Updates) :-
/*	tk_update_infobox("Checking for circularity in model assignment order"),
	(\+ all(compile, reachable, [build(Functions), unify([])]),
	    retract(heres_yer_loop(Loop)),
	    all(compile, unfinished_in, [build(Loop), build(CircSet)]),
	    raise_exception(circular_evaluation(CircSet));
*/	tk_update_infobox(pl_sort, []),
/*         SpecialSteps is Steps-1,
Previously only did steps up to shortest-1, but need to do shortest
as well to stop rand_vars being changed in the R-K subphase */
        sort_assignments(Functions, Steps, no),
	RKStep is Steps+1,
	update_antes_to_step(Updates, RKStep),
	all(compile, mark_unstepped, [build(Functions), unify(Steps),
				      append(_Normal, []), unify(yes)]),
	/* Check all same-time-step circles can be done in one program loop */
	tk_update_infobox(pl_loop, []),
	(member(Start, Functions),
	    Start = make(LoopEnd, Conds-_, EndPath, _,_),
	    member(later(Loop2), Conds),
	    Loop2 = make(LoopStart, _, StartPath, [_,_, Step | _], _),
	    all(compile, remove_non_loopers,
		[build([EndPath, StartPath]), build([PureEnd, PureStart])]),
	    suffix(PurePath, PureEnd),
	    suffix(PurePath, PureStart), % all(...) cannot retry subgoals
	    find_antecedent([Loop2], outside_loop, PurePath-Step, Out),
	    /* would be better to get setof these and trace them all back at
	    once but that needs too_many_variables */
	    find_antecedent([Out], =, Start, _),
	    Out = make(Xefct, _, APath, [_,_, AStep | _], _),
	    (remove_non_loopers(APath, PureAPath),
		\+ suffix(PurePath, PureAPath),
		raise_exception(condition_outside_loop(LoopEnd, LoopStart,
						       Xefct));
	    raise_exception(mixed_phase_loop(LoopEnd, Xefct, Step, AStep)));
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
	    
/* generate_main_decls does all the declarations except the ones for
temporary variables used when expanding expressions.
* New version, for 2.34: Does all the recursing itself, and also generates
the model node data table and the extractor case statements */

generate_main_decls(L, Instance, Finish, Stream) :-
	Instance = instance(submodel, SymbolicName, 
			xrefs(Model, Bases, _), _, ModelType-_),
	(variable_size(SymbolicName), !,
	    /* Declare the type with 'compartment' to hold instance numbers */
	    list_local_index_meanings(SymbolicName, Bounds),
	    append_atoms(ModelType, '*', PtrType),
	    (is_population(SymbolicName), !,
		DummyCompDims = [1],
		DeclsOnly = [instance(internal, baseptrs,_,
					baseptrs, 'void*'-[1]),
			     instance(system, _,_, channelId, int-[])];
	    length(Bounds, IdCount),
		DummyCompDims = [IdCount],
		(render'><'count_base_ptrs(Bases, PtrCount),
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
	Model = model(_Funx, Submodels),
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
	nl(Stream),

	% Events are now conditionals in the main line of execution, so no need
	% to implement them as procedures
	
	% pick_types(Funx, [magnitude], Evts),
	% all(compile, make_event_proc,
	%     [build(Evts), unify([L, SymbolicName, Stream])]),
					 
	(var(Finish), !,
	    Finish = EndClass;
	 send_to_dest(Stream, EndClass)).

/* All events are procedures, which call those of downstream events if
the value is non-null. Additionally, some events (e.g., limits) may
insert conditions for calling themselves, others (e.g., squirts) may
adjust compartment values.
make_event_proc(instance(_Type, _, Motion, elt(Home, Name, _), Unit-Dim),
		[L, Sm, Stm]) :-
	(Motion = squirt(Sqt, InType, (Src->Dest), Conseqs),
	    (Src = 0, Twk1 = [];
	      Src = elt(_, BSrc, _), CSrc = arr('', BSrc, []),
		Twk1 = [assign(CSrc, CSrc-magnitude)]),
	    (Dest = 0, Twk2 = Twk1;
	      Dest = elt(_, BDest, _), CDest = arr('', BDest, []),
		Twk2 = [assign(CDest, CDest+magnitude) | Twk1]), !;
	  Motion = event(Sqt, InType, Conseqs),
	    Twk2 = []),
	(InType = void, !,
	    ProcSpec = call('void', Name);
	    ProcSpec = call('void', Name, [InType, cause])),
	excrete(L, procedure_start, ProcSpec, 0, Stm),
	excrete(L, variable_declaration, [Unit, magnitude, Dim], 4, Stm),
	final_assignment(Sqt, Sm, elt(Home, magnitude, _-Dim), [], 1, Used,
			 Formula, Setups, _Path, Deps, AllInters),
	connect_params([make(magnitude, Deps, [], 1, Formula) | Setups],
		       AllInters, Actions, Inters),
	all(compile, excrete, 
	    [unify(L), unify(data_declaration), build(Inters),
	     unify(4), unify(Stm)]),
% next get actions from instructions and run through language
	all(compile, old_extract_action,
	    [build(Actions), append(ActionForm, Twk2)]),
	do_assign_list( L, ActionForm, 4, Used, Stm),

	% Now call consequent events if our magnitude is non-NULL
	(Conseqs = [], !;
	  copy_term(Conseqs, SafeCons),
% avoid going through whole ordering system to make sure event proc pointers
% have a context
	    excrete(L, cond_events, [magnitude, SafeCons, [magnitude]], 4, Stm)),
	excrete(L, end(procedure), Name, 0, Stm),
	nl(Stm).

old_extract_action(make(_E,_C,_P,_S,A),A).
 */
generate_metadata(_, [], _,_,_, [], _).
generate_metadata(L, [Instance | Instances], Tree, Level,
		     Used, NodeData, Stream) :-
	Instance = instance(Type, Node, Loc, _, _-CSizes),
	(Type = submodel, !,
	    list_local_index_meanings(Node, SmIndSpecs),
	    all(forms, index_names_and_sizes,
		[build(SmIndSpecs), build(_Names), build(RSizes)]),
	    reverse(RSizes, SmSizes);
	SmSizes = CSizes),
	all(ame_gen, enum_type_ref,
	    [build(SmSizes), unify(Node), build(_), build(_), build(Posn)]),
		/* In the past, SmDims was replaced by Posn, which is
		a number from -10 down indicating the data structure in the
	        executable corresponding to the actual enumerated type. */
	(Type = submodel,
	    StartCases = 4,
	    append(Tree, [Level, -1], DeepTree),
	    (is_population(Node), !,
		['MEMBERS'] = NewDims;
	    variable_size(Node), !,
		substitute(pop, Posn, 'MEMBERS', Mid),
		substitute(records, Mid, 'RECORDS', VmBounds),
		append(['START_VM' | VmBounds], ['END_VM'], NewDims));
	append(Tree, [Level], DeepTree),
	    StartCases = 1,
	    ((by_record(Node); from_value(Node)), !,
		['RECORDS'] =  NewDims;
	    Posn = NewDims)),
	(Loc = xrefs(Model, _,_),
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
	pick_types(Funx, [function, init_function, id_function, al_function,
			  state_fn, fp_compartment,
			  loss, internal, external, magnitude, limit, series],
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
	tk_update_infobox("Generating compartment update expressions"),
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
	     build([[void, this, []] | Consts]),
	     unify(0), unify(Stream)]),
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

build_submodel_functions( Language, Phases, Constants, NewForm, Updates,
			  Used, AllGraphs, Stream) :-
	tk_update_infobox(pl_order, []),

	/* rough and ready -- phase NotDone means it never gets scheduled */
	order_all_assignments(Phases, Updates, update, OrdUpdates),
	order_all_assignments(Phases, NewForm, eval, Ordered), !,
%	order_all_assignments(Phases, NewForm, advance, OrdStates),
	(member(Forgotten, NewForm),
	    not_yet_ordered(Forgotten), !,
	    find_circle([Forgotten], Loop),
	    all(compile, unfinished_in, [build(Loop), build(CircSet)]),
	    raise_exception(circular_evaluation(CircSet));
	true),
	/* note state variables implemented by 'last' might refer to
	compartment values, hence must go before them */

	tk_update_infobox(pl_code, []),
	all(compile, build_eval_proc,
	    [unify(Language), unify(Constants),
	     build([advancemodel, updatemodel, evalmodel]),
	     % advancemodel only added to stop error when trying to reuse
	     % source code in versions before v5.4
	     build([[], OrdUpdates, Ordered]),
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
	(NewHead = make(enumerate(_), _,_,_,_); true), % prioritize
	order(NewHead, Head),
	not_yet_ordered(NewHead), !,
	(append(Circle, [NewHead | _], [Head | Chain]), % this completes it
	    Loop = [NewHead | Circle];
	 find_circle([NewHead, Head | Chain], SubLoop),
	    (SubLoop = [], !, %this was fruitless, tag it and try another
		NewHead = make(_,_,_, [_,_,_,x | _], _),
		find_circle([Head | Chain], Loop);
	     Loop = SubLoop)); % found one further down
	unfinished_in(Head, Tail),
	% pick act because raising exception with self-ref term crashes GNU
	raise_exception(ordering_failure(Tail)),
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

make_exit_proc(Language, Instance, Dest) :-
	Blank = [''],
	excrete(Language, comment, 'FREE ALL DATA STRUCTURES', 4, Dest),
	send_to_dest(Dest, Blank),
	excrete(Language, procedure_start, call(void, do_exitmodel), 0, Dest),
	send_to_dest(Dest, Blank),
	excrete(Language, clear_memory, Instance, 4, Dest),
	send_to_dest(Dest, Blank),
	excrete(Language, end(procedure), dummy, 0, Dest).

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
		       [instance(submodel, P2, xrefs(NextModel, X3,X4),
				 Top, P5) | AfterSubs], Submodels), !,
		merge_inters([instance(internal, inter(LowPath, _,_), _, Name, 
				       Type-Dims)], NextModel, NewNext, []),
		append(BeforeSubs,
		       [instance(submodel, P2, xrefs(NewNext, X3,X4),
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

extract_assignments(Instance, Path, Tree, Step, MaxStep, Swaps, Used,
		    ExtIncs, Inters, AssignList) :-
	Instance = instance(submodel, Id,
			    xrefs(model(Functions, Submodels), _,_), _,_),
	(select(instance(alarm,_,_,elt(_, Al,_),_), Functions, NoAlarm),
	    select(instance(al_function,_,_,elt(_, Al,_),_), NoAlarm, ForAlarm),
	    Path = [sm(_,_,_, fm_loop(_,_, Al))|_], !,
	    % now make alarm depend on everything in its submodel
	    % so the whole thing gets done in one pass
	    all_targets(model(ForAlarm, Submodels), AlConds),
	    AlDelay = [make(all_for(Al), AlConds, Path, Step, [])];
	  AlDelay = []),
/*	(setof(ParamUpdate,
	       input_params_in(Functions, Path, Step, ParamUpdate),
	       ParamUpdates), !;
	ParamUpdates = []),
*/	(Id has_class_refinement enum_types of ETS, !,
	    all(compile, make_et_spec, [unify(Id), build(ETS), build(ETS0)]);
	    ETS0 = []),
% Add submodel-local function definitions to database
	(Id has_class_refinement function_defns of FnDefs, !; FnDefs = []),
	all(inters, add_macro, [unify(in(Path)), build(FnDefs), build(_Ops)]),

	all(compile, get_assignment,
	    [build(Functions),
	     unify(Path), unify(Step), unify(Swaps),
	     unify(Used), append(Inters0, []), append(AssignList0, AlDelay)]),
	all(compile, extract_submodel_assignment,
	    [build(Submodels),
	     unify(Functions), unify(Path), unify(Tree),
	     unify(Swaps), unify(Step), biggest(MaxStep, Step), unify(Used),
	     merge_lists(ExtIncs, []),
	     append(Inters, Inters0), append(AssignList, AssignList0)]),
% Remove submodel-local function definitions from database
	retractall(macro_expansion(in(Path), _)).

all_targets(model(Functions, Submodels), Tgts) :-
	purge([instance(variable, _,_,_,_)], Functions, LocalFns),
	% variables removed because they include ghosts from outside
	all(user, arg, [unify(4), build(LocalFns), build(LocalElts)]),
	all(user, arg, [unify(2), build(LocalElts), build(LocalTgts)]),
	all(user, arg, [unify(3), build(Submodels), build(XRefs)]),
	all(user, arg, [unify(1), build(XRefs), build(Trees)]),
	all(compile, all_targets, [build(Trees), append(Tgts, LocalTgts)]).
% note changes to instance(), elt() and xrefs() structures may affect this!
% you say thats overkill, I say thanks for the compliment
	
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
			    Path, Tree, Swaps, TopStep, MaxStep, Used,
			    ExtIncludes, Inters, AssignList) :-

	Instance = instance(submodel, SmName, xrefs(Model, Bases, Assocs), 
			    Name, _-Dims),
	time_step_for(SmName, TopStep, Step),

	Model = model(Functions, _),
	pointer_from(Path, Ptr),
	/* bug flusher! (nonvar(Ptr); append_atoms(Name, pointer, Ptr)), */
	path_section_for(SmName, Name, Dims, Level, Ptr, NewPtr),
	append(Level, Path, LocalPath),
	LocalTree = [Instance | Tree],
	/* Do not allow an associated model to be started until its
	bases have all been enumerated */

	get_swaps_and_waits(LocalTree, Bases, in, InSwaps, 
			    CurrentBaseMembershipsSet),
	get_swaps_and_waits(LocalTree, Assocs, out, OutSwaps,
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
	    
	    CreateRules = [make(culled(Name),
				[init_list(Name), on_step | BasesEnumerated],
				Path, Step, [lose(Ptr, Name, Losses)]),
			   make(created(Name),
				[culled(Name) | Creators], Path, 0,
				[init_mems(Ptr, Name, create(Creators))])],
	    % relegate to 0 as membership may have changed during run
	    (setof(ReproRule, maker_for(SmName, Functions, Name, Path, Step,
					Ptr, reproduction, ReproRule),
		   ReproRules), !; 
		ReproRules = []),	    
	    (setof(ImRule, maker_for(SmName, ParentFns, Name, Path, Step,
				     Ptr, immigration, ImRule),
		   ImmigRules), !; 
		ImmigRules = []),
	    all(compile, unfinished_in,
		[build(ReproRules), build(ReproConds)]),
	    all(compile, unfinished_in,
	        [build(ImmigRules), build(ImmigConds)]),
	    append(ReproConds, ImmigConds, NewMemConds),
	    /* Something that will be done in the initialization procedure, to make sure we don't try to create any before we can run this procedure */
	    append([[make(can_enter(Name),
			  [culled(Name), created(Name) | NewMemConds],
			  Path, Step, []),
		     % need culled and created to get in right step
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
	    Level = [sm(_,_,_, vm_loop(Sizes, _, BaseSides, _))],
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
	    Specials = [make(enumerate(Name),
			     [existence_tested(Name), can_enter(Name)],
			     LocalPath, Step, []),
			make(existence_tested(Name),
			     [earlier(can_enter(Name)) | Conds],
			     LocalPath, Step, [test(Name, NewPtr, TestExpr)]),
			make(can_enter(Name),
			     [startable(Name) | BasesEnumerated], Path, Step,
			     []),
			make(startable(Name), [init_list(Name) | BasesCleared],
			     Path, Step, [reset_list(Ptr, Name)]),
			make(init_list(Name), [], Path, Step,
			     [assign(arr(Ptr, Name, []), 0)])];
	Level = [sm(_,_,_, fm_loop(Globs,_,_)) | _Loops],
	% its the _Loops that have the bounds!
	    all(compile, name_loop_vars, [build(Globs), unify(Used)]),
	    get_dims_from_loops(Path, _, UseInds),
            ((by_record(SmName),
	            append_atoms(Name, made, NMade),
	            SmInters = [instance(internal, inter(Path, _,_), _, NMade,
					 int-[])],
	            CFn =.. [collect, MadeCount, Name, IdxN | UseInds],
	            XFns = [CFn, AFn],
	            StartConds = [on_step],
	            StartStep = -1;
	          from_value(SmName),
	            member(instance(function, n_made(SmName), _,
				    elt(_, NMade, _), _), ParentFns),
	            SmInters = [],
	            XFns = [AFn],
	            StartConds = [NMade],
	            StartStep = Step), !,
		length(UseInds, IdxN),
		MadeCount = arr(Ptr, NMade, []),
		AFn = assign_array(Ptr, Name, NMade, 1),
		Specials = [make(enumerate(Name), [startable(Name)], Path, Step,
				 XFns),
			    make(startable(Name), StartConds, Path, StartStep,
				 [assign_array(Ptr, Name, NMade, -1)])];
	     [SmInters, Specials] = [[], []]),
	    BaseSides = []),
	extract_assignments(Instance, LocalPath, LocalTree, Step, MaxStep,
			    NewSwaps, Used, SubIncludes, FnInters, AssignList0),
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

maker_for(SmName, Fns, Name, Path, Step, Ptr, Channel, Rule) :-
	member([Channel, EffectFr, ActFr],
	       [[immigration, settled, new_member],
		[reproduction, bred, reproduce]]),
	Effect =.. [EffectFr, Name, InitSpec],
	Action =.. [ActFr, Ptr, Name, InitSpec],
	SmName has_part InitName,
	member(instance(Channel, InitName, _X, elt(_, InitSpec, _), _U), Fns),
	% first rule stops latency being used before instances created
	member(Rule, [make(InitSpec, [Effect], Path, Step, []),
	  make(Effect, [culled(Name)], Path, Step, [Action])]).

list_params_from(BaseStr, N, Assigns, List) :-
	sicstus_write_to_chars(N, NStr),
	append(BaseStr, NStr, HeaderStr),
	member(make(Tgt, _,_,_,_), Assigns),
	atom(Tgt), name(Tgt, TgtStr),
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

get_swaps_and_waits([instance(submodel, ID, _,_,_) | _], FarEnds, _, [], []) :-
	var(FarEnds),
	    caption_for(ID, Lost),
	    raise_exception(bad_role(Lost));
	FarEnds = [].

get_swaps_and_waits(Tree, [base(Assoc, Link, Ptrs) | Rest], Dir,
	  [path_substitution(Exited, Entered, Link) | MorePathSwaps], Waits) :-
	(Dir = out,
	    make_branch(Tree, Assoc, OutTree, InTree),
	    levels_to_path(OutTree, Exited, TopPtr, _),
	    levels_to_path(InTree, Entered, TopPtr, _),
	    Entered = [sm(_,_,_, vm_loop(_,_, AssocSides, _)) | _],
	    InTree = [instance(_, Assoc, xrefs(_, Bases, _), _,_) | _],
	    append(OutTree, Stump, Tree),
	    append(InTree, Stump, AssocTree),
	    get_swaps_and_waits(AssocTree, Bases, in, SwapsBack, _),
	    all(compile, get_base_side, [unify(Entered), build(SwapsBack),
					 build(AssocSides)]),
	    /* reverse(RevAssocSides, AssocSides),
	    Keeping my fingers crossed that removing this will not affect
	    operation*/
	    Tree = [instance(_, Base, _,_,_) | _], 
	    member(base(Base, Link, FarPtrs), Bases),
	    get_base_ptrs(Exited, _, FarPtrs),
	    TheseWaits = [];
	Dir = in,
	    make_branch(Tree, Assoc, InTree, OutTree),
	    levels_to_path(OutTree, Exited, TopPtr, _),
	    levels_to_path(InTree, Entered, TopPtr, _),
	    get_base_ptrs(Exited, _, Ptrs), /* this actually sets them */
	    wait_for_submodels(Exited, TheseWaits)),	
	get_swaps_and_waits(Tree, Rest, Dir, MorePathSwaps, OtherWaits),
	append(TheseWaits, OtherWaits, Waits).

convert_base_specs(time, on_reset).
convert_base_specs(enumerate(Model), startable(Model)).

% This takes a tree, being a list of nested component instances innermost first,
% and a node id, and creates the lists that must be removed and added to convert
% the tree to point to the given node.

make_branch(Tree, Tip, OldBranch, NewBranch) :-
	contains(Fork, Tip, List),
	append(OldBranch, [ForkInst | _], Tree),
	ForkInst = instance(_, Fork, xrefs(model(_Funx, Subs), _,_), _,_), !,
	nodes_to_levels(List, Subs, NewBranch).

nodes_to_levels([], _, []).
nodes_to_levels(List, Subs, NewBranch) :-
	append(Trail, [HighNode], List),
	member(HighInst, Subs),
	HighInst = instance(_, HighNode, xrefs(model(_Funx, LowerSubs), _,_),
			    _,_),
	nodes_to_levels(Trail, LowerSubs, LowerInsts),
	append(LowerInsts, [HighInst], NewBranch).
	
levels_to_path([], [], Ptr, Ptr).

levels_to_path([instance(submodel, SmName, _, Name, _-SmDims) | MoreLevels],
	       Path, TopPtr, LoPtr) :-
	path_section_for(SmName, Name, SmDims, Level, HiPtr, LoPtr),
	levels_to_path(MoreLevels, Higher, TopPtr, HiPtr),
	append(Level, Higher, Path).

/*
name_from_elt(FullRef, Cond) :-

	(FullRef = IName*_Scale, !; FullRef = IName),
	IName = input(in_hierarchy, elt(Path, Name, _), none, _),
	wait_for_submodels(Path, Waits),
	(Name = import(_,_,_,_,_, PhaseSet, Src, _), !,
	(PhaseSet = 0, !,
	    Cond = [ints(Src) | Waits];
	Cond = [exts(Src) | Waits]);
	Cond = [Name | Waits]).

insert_ptr(Path, search_from(_, Name, Ptr)) :-
	member(sm(Name, _, Ptr, _), Path).
*/
/* get_assignments takes the list of instance functions for all the
things that need to be evaluated in the model and turns them into a
list of 'make' functions which include information about how to order
the actions corresponding to them.*/

get_assignment(instance(Type, Node, Source, DestRef, Unit-DimTypes),
	       DestPath, SmStep, Swaps, Used, Inters, Assignments) :-
/* Only make assignments for functions, for now, and
	    Do not make an assignment if we are expecting one on init/reset
	    from outside */
	(member(Type, [event, magnitude, limit, series, state_fn]), !,
	    Is_P = 0;
	  is_parameter(Node, Norm_P),
	    (Norm_P = 2, \+ Node has_class_refinement param_type of file, !,
		Is_P = 3;	% a time series event
	     Is_P = Norm_P)),
	DestRef = elt(_, Dest, X),    
	((Is_P = 2,
	    (Type = function, Tgt = Dest, Step = -1, Wait = [on_step];
	    Type = init_function, Tgt = init(Dest),
		Step = 0, Wait = [on_reset]);
	 member(Is_P, [1,3]),
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
	  Type = state_fn,
	    Collects = [make(init(Tgt), [on_reset], Path, 0,
			     [assign(Val, 0)])];
	  Collects = []),
	((Is_P < 1,
	    (Type = init_function, !,
		UseList = [on_reset | RefList],
		Made = init(Dest),
		UseStep = 0;
	    (Type = id_function,
		UseList = [can_find_id(Node) | RefList];
	      Type = al_function,
		UseList = [all_for(Dest) | RefList];
	      member(Type, [function, loss, limit]),
		UseList = RefList;
	      member(Type, [magnitude, state_fn])), !,
		Made = Dest,
		UseStep = SmStep),
	    SourceEqn = Source;
	(Is_P = 1, apply_minmax(Node, Source, SourceEqn);
	    Is_P = 3, SourceEqn = 0),
	    Type = function,
	    UseList = RefList, 
	    Made = init(Dest),
	    UseStep = -2;
	member(Type, [compartment, immigration, reproduction]),
	  \+ Source = none,
	    UseList = [time | RefList], 
	    Made = update(Dest),
	    UseStep = SmStep,
	    SourceEqn = Source),
	    
	( /* Type = limit, !,
	    SourceEqn = limit(ActEqn, BoundForm),
	    (BoundForm = min(Upper, More),
		FL1 = 2;
	      More = BoundForm,
		FL1 = 0,
		Upper = 0),
	    (More = max(Lower, result),
		Flags is FL1 + 1;
	      More = result,
		Flags = FL1,
		Lower = 0),
	    GroundEqn = check_limit(ActEqn, Lower, Upper, Flags),
	    AllActs = [Expr]; */
	  Type = magnitude, !, % no derived events yet but same
	    SourceEqn = event(ActEqn, TriggerEqn, (From->To)),
	    (Unit = boolean -> Inactive = '"false"' ; Inactive = 0),
	    GroundEqn = (magnitude=TriggerEqn,
			    choose(magnitude '!=' 0, ActEqn, Inactive)),
	    % trigger is just a sum of references so building is simple
%	    final_assignment(TriggerEqn, Node,
%			     elt([], current_event_magnitude, X), Swaps,
%			     UseStep, Used, [TriggerExpr], [], _Path, EvtConds,
%			     []),
	    Val = arr(SquirtPtr, _, _), % and its submodel pointer
	    (From = 0, Twk1 = [];
	      From = elt(_, BSrc, _), CSrc = arr(SquirtPtr, BSrc, []),
		Twk1 = [assign(CSrc, CSrc-Val)]),
	    (To = 0, Twk2 = Twk1;
	      To = elt(_, BDest, _), CDest = arr(SquirtPtr, BDest, []),
		Twk2 = [assign(CDest, CDest+Val) | Twk1]), !,
%	    AllActs = [cond_event(TriggerExpr, Expr, Twk2)],
%	    append(EvtConds, RefList, UseList);
	    AllActs = [Expr | Twk2],
	    UseList = RefList;
	  Type = state_fn, !,
	    SourceEqn = event(ActEqn, TriggerEqn, (0->0)),
	    choosify(ActEqn, ChooseForm),
	    GroundEqn = (magnitude=TriggerEqn, ChooseForm),
	    AllActs = [Expr],
	    UseList = RefList;
	  (SourceEqn = with_phase(SmStep, EvtElts, GroundEqn),
	      all(user, arg, [unify(2), build(EvtElts), build(EvtConds)]);
	    EvtConds = [],
	      GroundEqn = SourceEqn),
	    AllActs = [Expr]), !,
	final_assignment(GroundEqn, Node, elt(DestPath, Dest, X), Swaps,
			 SmStep, UseStep, Used, [Expr], Setups, Path, RefList,
			 AllInters),
	connect_params([make(Made, UseList, Path, UseStep, AllActs) | Setups],
		       AllInters, Actions, Inters);
	Actions = [],
	Inters = []),
	(Type = limit, !,
%	    Expr = assign(_D, choose(Test1, _Y, _N)),
%	    Test1 =.. [_Ineq, Val, _Bound],
				% dig out the inter
	    % unite_event_contexts(Callable, Path, Combo),
	    % this merely puts its conds in the subphase
	    Linkers = [make(checked(Dest), [Dest], Path, SmStep, [])];
	    % pass value because consequent event may care whether we are minned
	    % or maxed (or cannoned into oblivion by an upstream squirt)
	    % but mostly cos it is easier
	  (member(Type, [compartment, creation, immigration, reproduction]);
	        member(Is_P, [1, 3]);
	        Is_P = 2, Type = init_function), !,
	    Linkers = [make(Dest, [init(Dest), update(Dest), tweaked(Dest)],
			    DestPath, SmStep, []),
		       make(tweaked(Dest), EvtConds, DestPath, SmStep, [])];
	Expr = assign(Val, _Fn), % dig out the result
	    Linkers = []),
	append([Collects, Actions, Linkers], Assignments).

unite_event_contexts([], Test, Test).
unite_event_contexts([elt(Path, _,_) | Others], Test, Act) :-
	unite_event_contexts(Others, Test, OldAct),
	inters'><'combine_contexts(Path, OldAct, Test, Act).

choosify([], prev(0)).
choosify([Evt-Cons | Rest], choose(happens(Evt), Cons, IfNot)) :-
	choosify(Rest, IfNot).

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
processing in the relation model. */

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
	    (CommonPath = Path, /* comment out to disable */ !,
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

No longer pairs up names of vm models with the phases they get enumerated
in, so this info is available when they are used as bases (this is now done
separately)

Search backwards until something that does not go is found, then fail */

sort_assignments(Instructions, Step, Fix) :-
	(Step = -2, !;
	 LongerStep is Step-1,
	    sort_assignments(Instructions, LongerStep, yes)),
	all(compile, check_this_step,
	    [build(Instructions), unify(Step), unify(Fix)]).

check_this_step(Inst, Phase, Fix) :-
	goes_this_step(Inst, Phase, Fix), !;
	true.

goes_this_step(make(_, Conds-_, _, [_, DefP, NewP | _],_), Step, Fix) :-
	\+ var(NewP), !; % gone already
	NewP = Step, % set while testing so loops go together
	(Step >= DefP, Fix = yes, !; % constrained by submodel step selection
	  all(compile, cond_goes, [build(Conds), unify([DefP, Step, Fix])])).

cond_goes(Cond, [DefP, Step, Fix]) :-
	(Cond = on_reset, Step >= 0;
	Cond = on_step, Step >= DefP;
	% Cond = time, Step >= DefP; 'time' never helps it get sorted!
	Cond = earlier(Act); % wrapper means ignore step
	Cond = can_find_id(_Node); % dummy to do with one-sided enumeration
	member(Cond, [Act, later(Act), this_step(Act)]),
	goes_this_step(Act, Step, Fix)), !.

/* 21st century, fully double-link-aware version: lacks AOT's ability to
promote entire same-step loops

sort_assignments(Instructions, Phase) :-
	(Phase = -2, !;
	 LongerPhase is Phase-1,
	    sort_assignments(Instructions, LongerPhase)),
	go_this_step(Instructions, Phase).

go_this_step([], _).
go_this_step([make(_, Conds-Afx, _, [_, DefP, NewP | _],_) | More], Phase) :-
	((\+ var(NewP); % gone already
	 DefP > Phase,	% need not go now
	    member(Cond, Conds),
	    (Cond = on_reload, Phase < -1;
		Cond = on_reset, Phase < 0;
		Cond = time, Phase < DefP;
		member(Cond, [Act, later(Act), this_step(Act)]),
		Act = make(_,_,_,[_,_,Done,_], _),
		var(Done))), !,
	    ToTry = More;
	NewP = Phase,
	    append(Afx, More, ToTry)),
	go_this_step(ToTry, Phase).

Tried and tested arse over tit version 

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
	NextInst = make(Efx, Conds-_, _, [_, DefP, NewP | _], _),
	var(NewP),
	DefP >= Phase,
	(Phase = -2;
	Phase = -1,
	    member(on_reload, Conds);
	Phase = 0,
	    member(on_reset, Conds);
	member(time, Conds);
	member(SameStep, Conds),
	    member(SameStep, [Cond, later(Cond), this_step(Cond)]),
	    Cond = make(_,_,_, [_,_, SPhase | _], _),
	    nonvar(SPhase),
	    SPhase >= Phase),
	NewP = Phase,
	(Efx = enumerate(Name),
	    VMSpecPairs = [vm_spec_pair(Name, Phase)];
	VMSpecPairs = []), !.	
			 
older forward-pointing version

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
	conditions that we couldn't resolve: if so, redo order_phase.
	18/2/10: changed OrderedAssign to ThisPhase in next line because o_d_a
	contains cuts and cannot be redone. Other effects? */
	\+ (member(make(_, Conds-_, _,_,_), ThisPhase),
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
	    /* go to a level where I can do something (note test for
	    having done something was on what is outstanding, as there may
	    not actually have been any new commands generated -- if this causes
	    a problem, add a 'nop' command) */
	    member(NonEmptySubPass, SubPasses),
	    \+ NonEmptySubPass = [],		     
	    /* do not go into a sumbodel if I cannot get the existence
	    test done by the time I come out -- NOTE this is the only time I
	    need the list of all instructions in the make process, and would
	    dearly like to do without it.

	    Actually I also need it to pick useful instructions, but both here
	    and there I just need the existence tests, so now I select these
	    before ordering */
	    \+ (SmLevel = sm(Sm, _,_, vm_loop(_,_,_,_)),
		   member(make(existence_tested(Sm), _,_, [_,_,_,D], _), All),
		   var(D)),

	    /* If this line uncommented, do not do anything that would use the
	    check-member feature */
	    % \+ (number(TestPhase), TestPhase < Phase),
	    /* Do not go into an alarmed submodel unless I can get the whole
	    thing done in this pass */
	    \+ (SmLevel = sm(_,_,_, fm_loop(_,_, Alarm)),
		   nonvar(Alarm),
		   \+ (member(AlarmSubPass, SubPasses),
			  member(make(Alarm, _,_,_,_), AlarmSubPass))),
			    
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
			     vm_loop(Dims,_, MoreLoops, _)),
		ptr_to_last_vm(Path, -2, ParentNew),
		make_inds_for(Dims, Sets, LocalInds),
		% check for new base instances removed in 5.9 -- if one is
		% new, the assoc instance must be, since it is enumerated
		% at least as often as the base models
		all(compile, ptr_to_last_vm,
		    [build(MoreLoops), unify(-2), append(VMPtrs, ParentNew)]),
		append([Sets | MoreLoops], BLoops),
		reverse(BLoops, AllLoops),
		all(compile, get_pass_ends,
		    [build([D1, D1 | AllLoops]), build([D2, D2 | OpenLoops]),
		     build(LastStep)]),
		all(inters, indices_for,
		    [build(AllLoops), append(LoopInds, []), append(_Ts, [])]),
		append(LoopInds, LocalInds, Inds),

		/* At this point we need to replace the innermost loop with an
		assignment if using an id-based condition, and move the
		condition evaluation outside that loop...*/
		(append(Slower, [Now | Faster], SubPasses),
		    append(IdOpens, [TestLoop, TestCond, _Cls | IdCloses], Now),
		    append(IdOpens, IdCloses, NoIdConds),
		    TestCond = make(_, IdConds-_, _,_,
					  [assign(arr(Zn, TcVar, _), IdExpr)]),
		    member(can_find_id(IdCond), IdConds),
		    /* check condition is for this level...oh sod it */
		    /* find last looping construct */
		    (append(OuterLoops, [make(_,_,_,_,
					      [open_index(IdRef, N)])
					| SmLoop], OpenLoops),
			member(SmLoop,
			   [[make(_,_,_,_, [start_submodel(_,_,_,_)])],[]]), !;
		    find_all_comps(AssocModel, IdCond),
		    caption_for(AssocModel, IdCapt),	
		    raise_exception(bad_instance_lookup(IdCapt))),
		    append_atoms(Submodel, cond, IdVar),
		    /* OK Normally a reference to index(n) in a vm submodel
		    gets turned to an element of instanceid, but this will not
		    yet have been filled when assigning the cond, so replace
		    with direct references to loop inds */
		    replace_subexps(IdExpr, compile, indices_direct,
				    [Ptr | Inds], top_down, _, IxExpr),
		    IdRef = arr('', IdVar, []),
		    Next = [TestLoop,
			    make(none,[]-_,_,_, [assign(IdRef, IxExpr)])
			   | SmLoop],
		    append(OuterLoops, Next, UseLoops),
		    (N = pra_bound(PraPtr, PraName),
			append_atoms(PraName, made, MadeBound),
			UpBound = arr(PraPtr, MadeBound, []);
		    UpBound = N),
		    append(Slower, [[make(_, IdConds-_, _,_, [assign(arr(Zn, TcVar, []), IxExpr>0&&IxExpr<=UpBound)]) | NoIdConds] | Faster], UseSubPasses), !;
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
		ptr_to_last_vm([SmLevel | Path], -2, SmNew),
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

/* we will need to initialize a submodel's contents if it is new and
the time step level is as large as the level in which it is
enumerated, or if that is true of any of its ancestors if they are
enumerated on a smaller time step than it */

ptr_to_last_vm(Path, Relevant, [new_context(Ptr, Phase) | MorePtrs]) :-
	suffix([sm(_,_, Ptr, vm_loop(_,_,_,Phase)) | Deeper], Path),
	Phase > Relevant, !,
	ptr_to_last_vm(Deeper, Phase, MorePtrs).
ptr_to_last_vm(_,_, []).

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

order_phase(Step, Path, RawAssign, All, ThisPass, Later, Taboo) :-
	pick_useful_instruction(All, Path, Instruction),
	get_next_evaluation(RawAssign, Path, Step, Others, Instruction),
	\+ member(Instruction, Taboo),
	(Instruction = make(_,_-Deps,_, [Phase,_,_, Step | _], _),
	    all(compile, select_ready,
		[build(Deps), unify(Phase), append(Assign, Others)]),
	    order_phase(Step, Path, Assign, All, Rest, Later, Taboo),
	    ThisPass = [Instruction | Rest];
	(delayable(Instruction); !, fail),
	    order_phase(Step, Path, RawAssign, All, ThisPass, Later,
			[Instruction | Taboo]));
	ThisPass = [],
	    Later = RawAssign.

delayable(make(_, Conds-_, _,_,_)) :-
	member(later(_), Conds), !.

get_vmsps(make(Efct, _,_, [_,_, Step | _], _), VMSP) :-
	Efct = enumerate(Name), !,
	VMSP = [vm_spec_pair(Name, Step)];
	VMSP = [].

/* insert_enum_phases: when we find an enumerate instruction, we want to
make sure that any time later we go into its submodel, the path will tell us
which phase the submodel was enumerated (had its membership decided) in. So
here we instantiate the 4th arg of vm_loop to the phase in all the paths... */

insert_enum_phases(_, []).

insert_enum_phases(VmSpecPairs, [Path | MorePaths]) :-
	(suffix([sm(Name, _,_, vm_loop(_,_, BPaths, Phase)) | Head], Path), !,
	    member(vm_spec_pair(Name, Phase), VmSpecPairs), % should be there
	    (var(BPaths) -> ToDo = [Head | MorePaths];
		append([Head | BPaths], MorePaths, ToDo));
	  ToDo = MorePaths),
	insert_enum_phases(VmSpecPairs, ToDo).
	
/* This one just inserts the shortest time step into any undecided phases.
Oh, and switches the conditions for references to their instructions.
set_free_phases([], _).
set_free_phases([make(_,_,_, Ph, _) | Insts], Phases) :-
	(nonvar(Ph), \+ Ph = Phases; Ph = Phases),
	set_free_phases(Insts, Phases). */

set_free_phases(OldForm, Phase, NewForm) :-
	tk_update_infobox(pl_xref, []),
	all(compile, convert_form,
	    [build(OldForm), unify(Phase), build(NewForm), build(Refs)]),
	all(compile, find_member, [build(NewForm), build(Refs), unify(NewForm)]),
	all(compile, close_dep_list, [build(NewForm)]), !.

convert_form(make(T1, Conds, Path, Ph, T5), Phase,
	     make(T1, NewC-_Deps, Path, [_, Ph | _], T5), Refs) :-
	(nonvar(Ph), \+ Ph = Phase; Ph = Phase),
	/* above is not correct -- all instructions should have a ground step,
	as the default step could be too short for their submodel. TODO: Find
	and fix any case where something gets here with a variable step. */
	( /* T5 = [assign(SV, SV+stage_incr(_,_,_))], !,
	    Refs = [], NewC = []; % no order needed in update */
	(\+ member(T1, [lastvalue(_)]),
				% can_enter irrelevant in state
	    member(sm(Name,_,_, vm_loop(_,_,_,_)), Path), !,
	    XCs = [earlier(can_enter(Name)) | Conds];
	XCs = Conds),
	(member(set(_Idx, loop(pra_bound(_, PraName),_)), Path), !,
	    ECs = [startable(PraName) | XCs];
	ECs = XCs),
	all(compile, handle_key_functors,
	    [build(ECs), build(NewC), append(Refs, [])])).

handle_key_functors(OldCond, NewCond, Refs) :-
	member(OldCond, [ % keyword conditions
time, % Action to be done in its submodel's phase, even if conds ready earlier
on_reset, % Action to be done in reset phase, even if conds ready earlier
on_step, % action cannot be promoted to longer than given step
% this could replace the above one if their steps were right
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
	Cond = make(Act, []-_, [], [_, -2, -2, -2 | _], []),
	    (member(Act, [lastvalue(_), update(_)]);
				% conditions that may not need making
	    raise_exception(cond_not_found(Act))).

close_dep_list(make(_,_-Deps, _,_,_)) :-
	length(Deps, _N).

made_in(Feature, sm(Submodel, _,_, vm_loop(_,_,_,_)), Pass) :-
	Test =.. [Feature, Submodel],
	member(make(Test, _,_,_,_), Pass).

order_all_assignments(Step, All, Phase, Done) :-
	all(compile, select_ready,
	    [build(All), unify(Phase), append(Ready, [])]),
	all(compile, select_ext_tests, [build(All), append(XTests, [])]),
	order_all(Step, Ready, XTests, Done).

order_all(Step, Undone, All, Done) :-
	order_submodel_assignments(Step, [], Undone, All, NowDone, NowLeft, _),
	(NowLeft = Undone, !, /* couldnt do any */
	    Done = [];
	add_phase_conditions(NowDone, -2, [], NowDoneForm),
	    order_all(Step, NowLeft, All, ThenDone),
	    append(NowDoneForm, ThenDone, Done)).

select_ready(All, Phase, Ready) :-
	All = make(_, Conds-_, _, [MPhase | _], _),
	(\+ MPhase = Phase;
	\+ Phase = update,
	    member(Cond, Conds),
	    (Cond = RealCond; Cond = earlier(RealCond)),
	    not_yet_ordered(RealCond)), !,
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
		Left = Later,
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
	(Level = cond_section(Cond), !,
	    extract_action(StartInit, [check_cond(Cond)]);
	Level = set(Ind, loop(IndSrc,_)), !,
	    extract_action(StartInit, [open_index(Ind, IndSrc)]);
	Level = sm(Submodel, ParentPtr, Ptr, Inds),
	    extract_action(StartInit,
		[start_submodel(Submodel, ParentPtr, Ptr, Inds)])),
	extract_action(Finish, [finish_level]).

prepares(V, F) :-
	member(F, [element(V), increment(V)]).

/* Choose next submodel in which to evaluate assignments. */

unfinished_submodels([], _,_, []).

unfinished_submodels([make(_,_, PathPlus, [_,_, FoundPhase | _], _) | Waiting],
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
	Next = make(_, _, IPath, [_,_, Phase | _], _),
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

not_yet_ordered(make(_,_,_, [_,_,_, IsOrdered | _], _)) :-
	var(IsOrdered).

find_antecedent(Chain, TestFn, TestData, Found) :-
	member(make(_, Conds-_, _,_,_), Chain),
	member(Prev, Conds),
	Prev = make(_,_,_, [Phase,_,_,Cur | _], _),
	\+ Phase = update,
	var(Cur), Cur = 1, !,
	/* above cut is important -- we do not want to retry selection. If this
	one gets us nowhere we will call the procedure again with it removed
	from the list, which avoids searching the same bit of tree again.

	Next bit means if this rule is retried we do not look for antecedents
	of something that satisfied the condition. */

	TestCall =.. [TestFn, Prev, TestData],
	(call(compile'><'TestCall), !,
	    (Found = Prev;
	    find_antecedent(Chain, TestFn, TestData, Found));
	find_antecedent([Prev | Chain], TestFn, TestData, Found)).

outside_loop(make(_,_, Path, [_,_, NPhase | _], _), LoopedPath-Phase) :-
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
	Level = sm(_,_,_, fm_loop(Inds, _, Alarm)),
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
	(member(Node, [st(Host), hist(Host), n_made(Host)]), !,
	    caption_for(Host, CompName),
	    append_atoms(CompName, '_extras', Name);
	  caption_for(Node, Name)),
	(Node = n_made(Host), !,
	    append_atoms(CompName, made, Var); % use name reserved by submodel
	  generate_name( Language, Name, Var, Used)),
%	make_code_atom(Name, Var, Used),
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

/* New technology: we want to convert any caption into a unique variable name,
while hopefully keeping it recognizable.
make_code_atom(Capt, Name, Used) :-
	name(Capt, [Hd | CaptStr]),
	(\+ available(Capt, Used), !,
	    hex_pair_for(Hd, Hx),
	    append(Hx, CaptStr, NameStr);
	all(compile, make_code_tail,
	    [build(CaptStr), append(TailStr, [])]),
	    (is_alpha_or_(Hd), !,
		NameStr = [Hd | TailStr];
	      hex_pair_for(Hd, Hx),
		append(Hx, TailStr, NameStr))),
	name(Name, NameStr).

available(Capt, Used) :-
	length(Used, _), !,
	\+ member(Capt, Used).

hex_pair_for(AscNo, HxPr) :-
	sicstus_format_to_chars("_%x", [AscNo], HxPr).

make_code_tail(AscNo, Chunk) :-
	(is_alpha_or_(AscNo); AscNo >= "0", "9" >= AscNo), !,
	Chunk = [AscNo];
	hex_pair_for(AscNo, Chunk).

is_alpha_or_(AscNo) :-
	AscNo >= "A", "Z" >= AscNo;
	AscNo >= "a", "z" >= AscNo;
	AscNo = "_".
 */
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_to_dest(Stream, Stuff) :-
	do_writing(Stuff, Stream).
