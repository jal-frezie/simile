/*******************************************************************************
**** INSTANTIATION - this is the module that generates the model instance   ****
**** of a model class that is actually converted into runnable code.        ****
*******************************************************************************/

sicstus_module(instance, [instantiate_all/2, apply_minmax/3,
			  path_section_for/6] ).

sicstus_use_module([sp_only,m_class,inters,ame_gen,units,utility,m_update,
	       library(lists),library(ordsets)]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
instance_type(instance(Type, _, _, _, _), Type).

is_instance(Type, Node, Inputs, Value, Units, Instance) :-
	Instance =.. [instance, Type, Node, Inputs, Value, Units].
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% instantiate/0 is the predicate which starts off the instantiation process.
% it traverses the model-class tree top down and effectively flattens it,
% building up a model as it goes. We will need to pass information in both
% directions, so we start with an empty list of instances, rather than building
% one on the stack. We have a list of bindings which connect Prolog variables
% with values passing along arcs, and so all that's done by unification.

/* Functions list is left open-ended, because some equations will require intermediate values which are added to the model later. Be
careful when looping through it. */

instantiate_all(Parent, Model) :-
	instantiate_trees([Parent], [Instance], [], [], TreeRefs),
	(setof(Channel, (find_all_comps(Parent, Channel),
			      counts_as_outside(Channel)), Channels),
	    instantiate_nodes(Channels, TopFns, [],[], TreeRefs, _Refs);
	TopFns = []),
	Model = model(TopFns, [Instance]).
	    
instantiate(Holder, model(ModelInstance, Submodels ), Path, Loops, FullSet) :-
	module_for(Holder, Parent),
	(setof( Primitive, contents(Parent, Primitive), TopNodes ), !; 
		TopNodes = []),
	(setof( Submodel, (Parent has_part Submodel,
			      Submodel has_class submodel,
			      \+ Submodel has_class_refinement separate of 1,
			      appears(Submodel)), LowerNodes ), !; 
		LowerNodes = []),
	instantiate_trees(LowerNodes, Submodels, Path, Loops, TreeRefs),
	caption_for(Holder, PCapt),
	sicstus_format_to_chars("Instantiating expressions from node values -- currently doing ~a", [PCapt], InfoString),
	dialogue:reassure_user(InfoString),
/* Dirty hack -- if we have local equations for any of the module member
functions, substitute their values here, and put the originals back afterwards.
*/
        (get_av_pair(Holder, 0, fn_overrides, Swaps), !; Swaps = []),
        all(instance, switch_function,
	    [unify(Parent), build(Swaps), build(Back)]),
	instantiate_nodes(TopNodes, ModelInstance, Path, Loops,
			  TreeRefs, FullSet),
        all(instance, switch_function,
	    [unify(Parent), build(Back), build(Swaps)]),
	!.

switch_function(Parent, Vis-Eqn-_, Vis-Old-_) :-
	find_all_comps(Parent, Vis),
	implicit_function(Vis, Fn),
	get_av_pair(Fn, 0, value, Old),
	add_parameter(Fn, 0, value, Eqn).

/* contents does the trick whereby immigration and creation channel nodes are placed outside their submodels. */

contents(Parent, Component) :-
	(find_all_comps(Parent, Component),
	    (Component is_of_sort has_function; Component has_class function;
		Component has_class_refinement separate of 1),
	    \+ counts_as_outside(Component);
	Parent has_part Submodel,
	    is_population(Submodel),
	    \+ Submodel has_class_refinement separate of 1,
	    find_all_comps(Submodel, Component),
	    counts_as_outside(Component)).

counts_as_outside(Node) :-
	get_host(Node, VisNode),
	VisNode is_of_sort value_outside.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
instantiate_nodes([], [], _,_, R, R).

instantiate_nodes([Node|Nodes], New_instances, Path, Loops,
		  ResultIn, ResultOut) :-
	(Node has_class Class; Node has_type Class),
	
	(Class = cloud, !,
	    New_instances = OtherInstances,
	    MidResult = ResultIn;
	    instantiate_node(Node, Class, Instances, Path, Loops, ResultIn,
			     MidResult),
	    append(Instances, OtherInstances, New_instances)),
	instantiate_nodes(Nodes, OtherInstances, Path, Loops,
			  MidResult, ResultOut).

instantiate_trees([], [], _, _, []).

instantiate_trees([Node|Nodes], [Instance|Instances], Path, Loops, ResultOut) :-
	get_node_size(Node, Multiple),
	pointer_from(Loops, HiPtr),
	caption_for(Node, Capt),
	make_code_name(c, Capt, Name),
	path_section_for(Node, Name, Multiple, NewBit, HiPtr, _),
	append(NewBit, Loops, NewLoops),
	instantiate(Node, Submodel, [Capt | Path], NewLoops, Results),
	list_links(Node, Links),
	make_base_refs(Node, Links, BaseRefs),
	/* I don't think the assoc_refs need to be in any special order... */
	(setof(base(instance(submodel, Assoc, _,_,_), Link, _),
			FarEnd^(connects(Link, Node, Assoc),
				Link is_connector from Node to FarEnd,
				Link has_type relation),
			AssocRefs), !;
	AssocRefs = []),

	Parent has_part Node,
	ParentRef = instance(submodel, Parent, _,_,_),
	
	is_instance(submodel, Node, 
			xrefs(Submodel, ParentRef, BaseRefs, AssocRefs), 
			Name, _-Multiple, Instance),
	instantiate_trees(Nodes, Instances, Path, Loops, ResultIn),
	split_base_refs(BaseRefs, BaseModelRefs),
	split_base_refs(AssocRefs, AssocModelRefs),
	append([[Instance, ParentRef | Results], 
			BaseModelRefs, AssocModelRefs],
			LocalRefs),
	merge_lists(LocalRefs, ResultIn, ResultOut), !.

instantiate_trees(_, _, _,_, _) :-
	raise_exception('Lost it for some unknown reason during instantiation.').

/* This substitutes the link used to refer to a relation (the one connected
to the model containing the destination) with the one used by the program
builder -- that connected to the source. */

make_base_refs(_, [], []).

make_base_refs(Node, [Link | R1],
	       [base(instance(submodel, Base, _,_,_), Link, _) | R2]) :-
	Link is_connector from Base to _,
	make_base_refs(Node, R1, R2).

split_base_refs([],[]).
split_base_refs([base(M, _,_) | R1], [M | R2]) :-
	split_base_refs(R1, R2).

instantiate_node(Node, Class, Instances, Path, Loops,
		 Old_instances, New_instances) :-
	(instance_of( Class, Node, Path, Loops, Instances, Refs), !;
	raise_exception(instantiation_failure(Node))),
	merge_lists(Instances, Old_instances, Mid_instances),
	merge_lists(Refs, Mid_instances, New_instances).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Ghosts are treated like variables, see later. */

instance_of(_, Node, _,_,
		[instance(variable, Node, _, Value, Dims)],
		[instance(_, RealNode, _, Value, Dims)]) :-
	(get_bowtie_section(Node, RealNode); find_base(Node, RealNode)),
	\+ Node = RealNode, !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Nodes that have been specified as input parameters are set by a function
call to the stub */

instance_of(Type, Node, Path, Loops,
	    [instance(function, Node, Default, Val, Base-Dims)], []) :-
	\+ member(Type, [compartment, creation, immigration, reproduction]),
	is_parameter(Node, PType),
	PType > 0, !,
	get_units(Node, Base, Dims),
	Val = elt(Path, Loops, _, Base-Dims),
	choose_default_value(Node, Base, PType, Default).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Compartment now refers to the same variable as the function which calculates its initial value. */

instance_of( compartment, Node, Path, Loops, Instances, [FuncRef | Refs]) :-
	is_parameter(Node, PType),
	(PType = 0, !,
	    ArcFromF is_connector from _ to Node,
	    ArcFromF has_type influence,
	    initiates(ArcFromF, F),
	    Instances = Local;
	F = Node,
	    Instances = [FuncRef | Local]),

	get_units(F, Base, Units),
	Home = elt(Path, Loops, _, Base-Units),
	Diffs = elt(Path, Loops, _, diffs-Units),
	(\+ PType = 1, !;
	    choose_default_value(Node, Base, PType, Default)),
	FuncRef = instance(init_function, F, Default, Home, Base-Units),
	((setof( Arc, flows(in, Node, Arc), InArcs),
	  bind_and_build_term(Node, InArcs, Path, Base, Units, In, In_refs);
	  In_refs = []),
	(setof( Arc, flows(out, Node, Arc), OutArcs),
	    bind_and_build_term(Node, OutArcs, Path, Base, Units, Out, Out_refs),
	    (In_refs = [], Change = -Out; Change = In++(-Out));
	\+ In_refs = [], Change = In),
	merge_lists(In_refs, Out_refs, Refs),
	/* apply_minmax(F, Home+Step*(In-Out), UpdateExpr),
	compartments will be updated in a separate procedure from flows
	so ordering will not be done -- otherwise the above would be
	Home+Step*last(In-Out) */
	
	is_instance(internal, st(Node), none, Diffs, diffs-Units, DiffStruct),
	    Expr = incr(Step,Home++stage_incr(Diffs, Step, Change)),
	    Local = [DiffStruct, Instance];
	[Refs, Local, Expr] = [[], [Instance], none]),
	    is_instance(compartment, Node, Expr, Home, Base-Units, Instance).

/* Immigration and reproduction nodes behave like compartments with an
inflow equal to their functional value and an initial value of random
between 0 and 1. It was previously 0.5 but this created too many
artefacts from small changes in the time step. They are reset to 0
when reaching 1 by the actions associated with them. Call them
compartments -- when looking for them I go back to the symbolic model
anyway. Unfortunately this is the other way round from how a
compartment works -- there, the function contains the initial
value. This means I have to come up with another node from somewhere
as compartments no longer hold two values -- or else swap the random
into the function and copy that's expression into the compartment.

Oh well, why don't I just mega-ly botch it and have each primitive
return a variable number of instances..."virtual" symbolic name means
not in the original model. */

instance_of(Type, Node, Path, Loops, 
	    [instance(Type, Node,
		      incr(Step, Home+stage_incr(Diffs, Step, Value)),
		      Home, real-[]),
	     instance(init_function, Node, rand_var(0,1), Home, real-[]),
	     DiffStruct],
	    [instance(function, Function, _, Value, _)]) :-
	member(Type, [immigration, reproduction]),
	Home = elt(Path, Loops, _, 1-[]),
	Diffs = elt(Path, Loops, _, diffs-[]),
	is_instance(internal, st(Node), none, Diffs, diffs-[], DiffStruct),
	Arc is_connector from _ to Node,
	initiates(Arc, Function).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* functions do not have any unit translations built into them, as it is assumed
that they are actually in the math bit of the function. If this is to be changed,
we will have to generate the 'natural' units for the output from all the 
operations and the units of all the inputs, and then translate between those and 
the specified output units. Painful, but imagine the pleasure of not allowing
the user any numeric values except universal constants in MKS! 
*/

instance_of( function, Node, Path, Loops, [Instance], Refs) :-
	_ is_connector from Node to Result,
	\+ is_ghost(Result),
	find_type(Result, RType),
	(Path = [Inst | _],
	    Inst is_instance_of _,
	    get_av_pair(Inst,  0, fn_overrides, OverRides),
	    get_host(Node, UseComp),
	    member(UseComp-GroundExpr-_, OverRides), !;
	Node has_class_refinement value of GroundExpr),
	(member(RType, [creation, compartment]), !,
	    UseExpr = GroundExpr,
	    FType = init_function;
	RType = condition,
	    (GroundExpr = (index(1) is UseId),
		UseExpr = soloarr(UseId); % cheat to allow single-element arr
	    GroundExpr = any(index(1) is UseExpr)), !,
	    /* Try alternative way of enumerating instances */
	    FType = id_function;
	FType = function,
	    UseExpr = GroundExpr),
	(setof(InputPair,
	       generate_input_pair(Node, Path, InputPair),
	       InputPairs ), !;
	    InputPairs = []),
	replace_subexps(UseExpr, instance, process_expr,
			sub(InputPairs, Refs), top_down,
			Switched, FinalExpr),
	(member(var_pair(_, Sub), Switched),
	    get_solo_list_depth(Sub, _),
	    raise_exception(bad_parameter(Node, Sub));
	length(Refs, _Fix)),
	get_units(Node, Base, Units),
	is_instance(FType, Node, FinalExpr, elt(Path, Loops, _, Base-Units),
		    Base-Units, Instance).
	     
/* Note if the function lacks a value it may not be the user's fault; it might be
an unnecessary virtual function generated in the SD view. 
So leave it out. */

instance_of(function, _,_,_, [], []).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* If a submodel comes up here, it is one that is built separately. The code
has to call stub functions to create an instance of it when its parent model
is created, and run it when its inputs have been set. */

instance_of(submodel, Node, Path, Loops,
	    [instance(external, Node, for_extern(Conds, Tops),
		      elt(Path, Loops, _, DSpec), DSpec)],
	    Refs) :-
	(setof(InputPair,
	       generate_input_pair(Node, Path, InputPair),
	       InputPairs ), !;
	    InputPairs = []),
	all(instance, get_cond_and_ref,
	    [build(InputPairs), build(Conds),
	     append(Tops, []), append(Refs, [])]),
	DSpec = 'void*'-[].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* flows have the value of the node connected to the bowtie if there is one, and 
that of the continuation flow in the direction of this node if not. 

Working out the continuation direction is now done when processing the function node, so just use this value. */

instance_of(flow, Arc, _,_, [instance(flow, Arc, _, Value, Units)],
	    [instance(function, Function, _, Value, Units)]) :-
	FuncLink is_connector from _ to Arc,
	initiates(FuncLink, Function).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* variables don't have any expressions of their own, they just have values which
are the same as the functions from which they are generated. This also goes for
condition, creation and loss nodes. Type is as function. */

instance_of(Type, Node, _, Inst, Ref) :-
	member(Type, [variable, condition, creation, loss, alarm]),
	(member(Node, [B, A]),
	    Arc is_connector from A to B, !,
	    initiates(Arc, F),
	    Inst = [instance(Type, Node, FnType, Value, Dims)],
	    Ref = [instance(FnType, F, _, Value, Dims)];
	/* Could not generate code for part with no connections, so kill it */
	caption_for(Node, Capt),
	    Node no_longer_has_refinements,
	    Node no_longer_has_connections,
	    Node no_longer_has_graphical_attributes,
	    Node is_no_longer_part_of Parent,
	    caption_for(Parent, PCapt),
	    sicstus_format_to_chars("Removing node ~w from submodel ~w.", [Capt, PCapt], Shpiel),
	    do_dialogue("Correcting model inconsistency", warning, Shpiel, ok, _)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
flows(Dir, Comp, Flow) :-
	(Tgt = Comp; find_ghosts(Comp, Tgt)),
	(Dir = in, Dest = Tgt; Dir = out, Src = Tgt),
	Flow is_connector from Src to Dest,
	find_type(Flow, flow).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* generate_input_pair is used in setof so should be cut free */
generate_input_pair(Node, DestPath,
             input_pair(ArcName, NodeID, Away, Home, Ref, ExprRef)) :-
	(counts_as_outside(Node), UsePath = [_ | DestPath];
	    \+ counts_as_outside(Node), UsePath = DestPath),
	get_all_links(Node, capts(UsePath, SrcPath),
		      ids(SourceID, Relation, Home, Entry),
		      input_link(id(Link,_, SourceLocation), _,
				 ArcName, SourceUnits, ArcUnits)),
	/* just in case we have extra inputs... */
	(nonvar(ArcName); ArcName = '/unused/'),
        (var(Entry),
	    NodeID = SourceID,
	    Ref = elt(SrcPath, _,_,_),
	    RefExp = Ref;
	nonvar(Entry),
	    (member(SourceLocation, [in_base, in_assoc]),
		all(draw, caption_for,
		    [build([Node, SourceID, Relation]),
		     build([NodeCap, SrcCap, RelCap])]),
		raise_exception(role_between_execs(NodeCap, SrcCap, RelCap));
	    SourceLocation = in_hierarchy),
	    ref_for_arc(Entry, ArcIndex),
	    (var(Home),
		Var = externs_done,
		PhaseSet = 1; /* Comes in from outside */
	    nonvar(Home),
		Entry is_connector from NodeID to _,
		contains(TopNode, Node),
		backup:is_toplevel(TopNode),
		output:find_phase(TopNode, SourceID, NodeID, PhaseSet),
		Ref = elt(Path, Loops, Var, _)), /* match var to submodel */
	    RefExp = elt(Path, Loops,
			 import(ImpType, Away, _L, _P0, _P, PhaseSet,
				    Var, ArcIndex), FarUnits-UseDims)),

	analyze_array(SourceUnits, FarUnits, FarDims),
	get_actual_sizes(Node, FarDims, _, UseDims, _),
	analyze_array(ArcUnits, BaseUnits, _),
	RelatedRef = input(SourceLocation, RefExp, Relation, ArcUnits),
	try_conversion(RelatedRef, FarUnits, BaseUnits, ConvertedRef, ImpType),
	find_name_host(Link, ControlLink),
	(get_av_pair(ControlLink, 2, use_sofar, 1),
	    ExprRef = sofar(ConvertedRef);
	\+ get_av_pair(ControlLink, 2, use_sofar, 1),
	    ExprRef = ConvertedRef).

/*
level_from_link(TopLink, Level) :-
	continues_from(TopLink, TopModel), !,
	caption_for(TopModel, Capt),
	path_section_for(TopModel, Capt, _, Level, _,_);
	Level = [].
*/
get_cond_and_ref(input_pair(_, Node, _, [Home | _], OutVar, UseRef, SubRefs),
		 Cond, Top, Refs) :-
	is_instance(_, Node, _, OutVar, _, Ref),
	(nonvar(Home), !,
	    /* A top level link in this submodel. Add it to the link reference
	    table and make an instruction to refer its parent by its index */
	
	    ref_for_arc(Home, HomeRef),
	    find_all_comps(HomeSm, Home),
	    is_instance(_, HomeSm, _, TopVar, _, TopRef),
	    Cond = UseRef,
	    Refs = [TopRef, Ref | SubRefs],
	    Top = [search_from(HomeRef, TopVar, _)];
	Top = [],
	    Cond = input(in_hierarchy, elt(_,_, externs_done, _), none,_),
	    Refs = [Ref | SubRefs]).

ref_for_arc(Entry, ArcIndex) :-
	compile:entry_arcs_are(ArcList),
	(suffix([Entry | ArcsAfter], ArcList), !;
	    compile:retract(entry_arcs_are(ArcsAfter)),
	    compile:assert(entry_arcs_are([Entry | ArcsAfter]))),
	length(ArcsAfter, ArcIndex).
	
try_conversion(RelatedRef, Units, BaseUnits, ConvertedRef, ImpType) :-
	get_conversion(RelatedRef, Units, BaseUnits, ConvertedRef), !,
	    ImpType = real;    
	RelatedRef = ConvertedRef,
	    (Units = any, !, ImpType = real;
		/* (only legacy nodes have no units!) */
	    ImpType = Units).
/*
This adds code that limits a model value to the range specified by its
min/max attributes. This currently is not done except for initial values
of input parameters. */

apply_minmax(Node, BaseExpr, UpdateExpr) :-
	(Node has_class_refinement min_val of Min,
	\+ Min = '', !,
		MinnedExpr = max(Min, BaseExpr);
	MinnedExpr = BaseExpr),
	(Node has_class_refinement max_val of Max,
	\+ Max = '', !,
		UpdateExpr = min(Max, MinnedExpr);
	UpdateExpr = MinnedExpr).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
choose_default_value(Node, Base, PType, Default) :-
	PType = 2, !,
	    Default = use_param_state;
	Node has_class_refinement value of Default, !;
	Base = a(_), !,
	    Default = 1;
	Base = boolean, !,
	    Default = 0;
	Node has_class_refinement min_val of MinExpr,
	Node has_class_refinement max_val of MaxExpr, !,
	    (Base = int, !,
		Default is (MinExpr+MaxExpr)//2;
	    Default is (MinExpr+MaxExpr)/2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* get_units: returns data type for a node in the form type-dimensions where
type is the data type for c and dimensions is a list of array size integers.

Experiment: Let's leave it to render to get the type name in the target
language */

get_units(Node, Type, Dims) :-
	(Node has_class_refinement units of Unit, !; Unit = 1),
	analyze_array(Unit, Type, Number),
	get_actual_sizes(Node, Number, _, Dims, _).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Puts references to connecting flows into compartment definition; note that flows
intrinsically have same units as compartment, so we go back to their control nodes
to get unit conversion factor */

bind_and_build_term(Node, [Arc], Dest, NodeBase, NodeDims, Term, [Ref]) :-
	(General_arc = Arc, Dest = Src;
	    any_equiv(Arc, General_arc, capts(Dest, Src))),
	has_bowtie(General_arc),
	get_chain(General_arc, Node, _, Exits, Entries),
	caption_for(Node, BadComp),
	caption_for(Arc, BadArc),
	(member(Multi, Entries),
	    (get_all_dims(Multi, BadDims),
		\+ BadDims = [], !,
		caption_for(Multi, BadModel),
		raise_exception(flow_splits_at_border(BadArc, BadComp,
						      BadModel));
	     Multi has_class_refinement separate of 1, !,
		caption_for(Multi, BadModel),
		raise_exception(flow_crosses_dll_boundary(BadArc, BadComp,
							  BadModel)));
	implicit_function(General_arc, Controller),
	get_units(Controller, ArcUnits, ArcDims),
	all(ame_gen, get_all_dims, [build(Exits), append(AllDims, ArcDims)]),
	    (append(NodeDims, MergeDims, AllDims), !,
		sum_dims(MergeDims, BaseVar, Var);
	    raise_exception(flow_comp_dims_mismatch(BadArc, BadComp,
						  AllDims, NodeDims)))),
	is_instance(_, Controller, _, BaseVar, _, Ref),
	BaseVar = elt(Src, _,_,_),
	default_tick_is(Tick),
	standard_name(NodeBase, TrimBase),
	try_conversion(Var, ArcUnits, TrimBase/Tick, Term, _ImpType).

bind_and_build_term(Node, [Arc|Arcs], Dest, Base, Dims, NewTerm, Refs) :-
	bind_and_build_term(Node, Arcs, Dest, Base, Dims, MidTerm, MidRefs),
	bind_and_build_term(Node, [Arc], Dest, Base, Dims, Term1, [Ref]),
	merge_lists([Ref], MidRefs, Refs),
	NewTerm =.. ['++',Term1,MidTerm].
	
sum_dims([], Var, Var).
sum_dims([_ | Rest], Middle, sum(Full)) :-
	sum_dims(Rest, Middle, Full).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arc_name_substitute takes a Prolog term apart, looks for atoms named in a
% list of name-node pairs, and reconstructs the resulting expression. Only they
% are little lists not atoms now.

process_expr(sub(InputPairs, Refs), Var, NewVar, Recurse) :-
	get_solo_list_depth(Var, _),
	(member(input_pair(Var, Node, Away, Home, OutVar, NewVar), InputPairs),
	    is_instance(_, Node, _, OutVar, _, Ref),
	    member(Ref, Refs),
	    (var(Home), !;
		find_all_comps(HomeSm, Home),
		is_instance(_, HomeSm, _, Away, _, TopRef),
		member(TopRef, Refs)), !;
	NewVar = Var),
	    Recurse = 0;
	build_table_ref(table_const(1), Var, NewVar), Recurse = 1.

build_table_ref(Table, table, Table).

build_table_ref(Table, TableFn, RefTable) :-
	TableFn =.. [table, Ind1 | IndN], ShortTableFn =.. [table | IndN],
	build_table_ref(element(Table,Ind1), ShortTableFn, RefTable).
		
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* because all taps have functions in the SD view, a valid one must also have
a value 

valid_tap(Flow, Controller) :-
	setof(Control, Arc^Go^
	     (Arc is_connector from Go to Flow,
		 initiates(Arc, Control),
		 Control has_class_refinement value of _,
		 \+ Control has_class_refinement units of boolean),
	      [Controller]).
*/

path_section_for(SmName, Context, SmDims, Level, HiPtr, LoPtr) :-
	(variable_size(SmName), !,
	    (by_record(SmName), !,
		SmSpec = vm_loop(rec, _,_,_);
	    is_population(SmName), !,
		SmSpec = vm_loop(pop, _,_,_);
	    list_local_index_meanings(SmName, Bounds),
		length(Bounds, NumInds),
		SmSpec = vm_loop(NumInds, _Bounds, _Loops, _)),
	    Level = [sm(Context, HiPtr, LoPtr, SmSpec)];
	all(ame_gen, enum_type_ref, [build(SmDims), unify(SmName),
				     build(SmSizes), build(_), build(_)]),
	    make_inds_for(SmSizes, SmPath, SmInds),
	    Level = [sm(Context, HiPtr, LoPtr, fm_loop(SmInds, _)) | SmPath]).
