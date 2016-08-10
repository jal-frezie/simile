/*******************************************************************************
**** INSTANTIATION - this is the module that generates the model instance   ****
**** of a model class that is actually converted into runnable code.        ****
*******************************************************************************/

sicstus_module(instance, [instantiate_all/2, apply_minmax/3, sum_over_dims/3,
			  is_lookup_cond/2, path_section_for/6] ).

sicstus_use_module([sp_only, m_class, inters, ame_gen, units, utility, m_update,
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
	    instantiate_nodes(Channels, TopFns, [], TreeRefs, _Refs);
	TopFns = []),
	Model = model(TopFns, [Instance]).
	    
instantiate(Parent, model(ModelInstance, Submodels ), Path, FullSet) :-
	(setof( Primitive, contents(Parent, Primitive), TopNodes ), !; 
		TopNodes = []),
	(setof(Submodel, Child^(find_all_comps(Parent, Child),
				(Submodel = Child;
				    Child has_class function, % submodel is
				    Child has_part Submodel), % function defn
				Submodel has_class submodel), LowerNodes), !; 
	    LowerNodes = []),
	instantiate_trees(LowerNodes, Submodels, XConts, Path, TreeRefs),
	instantiate_nodes(TopNodes, NConts, Path, TreeRefs, FullSet),
	append(XConts, NConts, ModelInstance),
	!.

/* contents does the trick whereby immigration and creation channel nodes are placed outside their submodels. */

contents(Parent, Component) :-
	find_all_comps(Parent, Component),
	    (Component is_of_sort has_function; Component has_class function;
		Component has_class_refinement separate of 1),
	    \+ counts_as_outside(Component);
	Parent has_part Submodel,
	    is_population(Submodel),
	    \+ Submodel has_class_refinement separate of 1,
	    find_all_comps(Submodel, Component),
	    counts_as_outside(Component).

counts_as_outside(Node) :-
	get_host(Node, VisNode),
	VisNode is_of_sort value_outside.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
instantiate_nodes(Nodes, New_instances, Path, RefsIn, RefsOut) :-
	all(instance, instantiate_node,
	    [build(Nodes), append(New_instances, []), unify(Path),
	     merge_lists(RefsOut, RefsIn)]).

instantiate_trees([], [], [], _, []).

instantiate_trees([Node|Nodes], [Instance|Instances], Count, Path, ResultOut) :-
	get_node_size(Node, Multiple),
	pointer_from(Path, HiPtr),
	path_section_for(Node, Name, Multiple, NewBit, HiPtr, _),
	append(NewBit, Path, NewPath),
	instantiate(Node, Submodel, NewPath, Results),
	list_links(Node, Links),
	make_base_refs(Node, Links, BaseRefs),
	/* I don't think the assoc_refs need to be in any special order... */
	(setof(base(Assoc, Link, _),
			FarEnd^(connects(Link, Node, Assoc),
				Link is_connector from Node to FarEnd,
				Link has_type relation),
			AssocRefs), !;
	AssocRefs = []),

	is_instance(submodel, Node, 
			xrefs(Submodel, BaseRefs, AssocRefs), 
			Name, _-Multiple, Instance),
	instantiate_trees(Nodes, Instances, Counts, Path, ResultIn),
	(get_actual_sizes(Node, Multiple, bare, [value(Deref)], _,_), !,
				% single reference only for now
	    SetFn = instance(function, n_made(Node),
			     max(0, input(in_hierarchy, ValMention, none, int)),
			     elt(Path, _, int-[]), int-[]),
	    Count = [SetFn | Counts],
	    ValRef = instance(_, Deref, _, ValMention, _),
	    LocalRefs = [SetFn, ValRef, Instance | Results];
	  Count = Counts,
	    LocalRefs = [Instance | Results]),
	merge_lists(LocalRefs, ResultIn, ResultOut), !.

instantiate_trees(_, _, _,_, _) :-
	raise_exception('Lost it for some unknown reason during instantiation.').

/* This substitutes the link used to refer to a relation (the one connected
to the model containing the destination) with the one used by the program
builder -- that connected to the source. */

make_base_refs(_, [], []).

make_base_refs(Node, [Link | R1], [base(Base, Link, _) | R2]) :-
	Link is_connector from Base to _,
	make_base_refs(Node, R1, R2).

instantiate_node(Node, Instances, Path, All) :-
	(Node has_class Class; Node has_type Class),
	(instance_of( Class, Node, Path, Instances, Refs), !,
	    append(Instances, Refs, All);
	  caption_for(Node, Capt),
	    raise_exception(instantiation_failure(Capt))).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Easiest first... */

instance_of(cloud, _, _, [], []) :- !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Ghosts are treated like variables, see later. */

instance_of(_, Node, _,
		[instance(variable, Node, _, Value, Dims)],
		[instance(_, RealNode, _, Value, Dims)]) :-
	find_base(Node, RealNode),
	\+ Node = RealNode, !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Nodes that have been specified as input parameters are set by a function
call to the stub */

instance_of(NType, Node, Path,
	    [instance(function, Node, Default, Val, Base-Dims)], []) :-
        member(NType-BelowParam, [variable-0, event-1]),
	is_parameter(Node, PType),
	PType > BelowParam, !,
	get_units(Node, Base, Dims),
	Val = elt(Path, _, Base-Dims),
	choose_default_value(Node, Base, PType, Default).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Compartment now refers to the same variable as the function which calculates its initial value. */

instance_of( compartment, Node, Path, Instances, [FuncRef | Refs]) :-
	is_parameter(Node, PType),
	(PType = 0, !,
	    ArcFromF is_connector from _ to Node,
	    ArcFromF has_type influence,
	    initiates(ArcFromF, F),
	    Instances = Local;
	F = Node,
	    Instances = [FuncRef | Local]),

	get_units(F, Base, Units),
	Home = elt(Path, _, Base-Units),
	Diffs = elt(Path, _, diffs-Units),
	(\+ PType = 1, !;
	    choose_default_value(Node, Base, PType, Default)),
	FuncRef = instance(init_function, F, Default, Home, Base-Units),
	change_due_to(flow, Node, Base, Units, FChange, FRefs),
	change_due_to(squirt, Node, Base, Units, QChange, QRefs),
	/* apply_minmax(F, Home+Step*(In-Out), UpdateExpr),
	compartments will be updated in a separate procedure from flows
	so ordering will not be done -- otherwise the above would be
	Home+Step*last(In-Out) */
	
	(F has_class_refinement min_val of Min ->
	 KeyL = 1; KeyL = 0, Min = 0),
	(F has_class_refinement max_val of Max ->
	 Key is KeyL + 2; KeyL = Key, Max = 0),
	is_instance(internal, st(Node), none, Diffs, diffs-Units, DiffSt),
	Expr = with_phase(Step, [],
		Home ++ stage_incr(Diffs, Step, FChange, Key, Min, Max)
			 ++ QChange),
	append(FRefs, QRefs, Refs),
	Local = [DiffSt, Instance],
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
not in the original model.

Update for Simile 5.4: For any of these nodes, the modeller may want
the equation value, the number actually made, or the remainder carried
over. The first is the value you see or get, the others are returned
by functions that work like 'channel_is'. So an extra program variable
must be made for number of instances actually made, which would
otherwise be lost. */

instance_of(Type, Node, Path,
	    [instance(Type, Node, Updater, Home, real-[]),
	     instance(init_function, Node, rand(0,1), Home, real-[]), DiffSt],
	    [instance(function, Function, _, Struct, _)]) :-
	member(Type, [immigration, reproduction]),
	Home = elt(Path, _, 1-[]),
	Diffs = elt(Path, _, diffs-[]),
	is_instance(internal, st(Node), none, Diffs, diffs-[], DiffSt),
	Arc is_connector from _ to Node,
	initiates(Arc, Function),
	(generate_input_pair(Function, discrete, _EvtPair) ->
	 % channel is event -- just add magnitude
	 Updater = Home+Struct;  % this format identifies discrete immigrations
	 % channel is coninuous -- increment compartment style
	Updater = with_phase(Step, [], Home+stage_incr(Diffs, Step,
						       Struct, 0,0,0))).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* functions do not have any unit translations built into them, as it is assumed
that they are actually in the math bit of the function. If this is to be changed,
we will have to generate the 'natural' units for the output from all the 
operations and the units of all the inputs, and then translate between those and 
the specified output units. Painful, but imagine the pleasure of not allowing
the user any numeric values except universal constants in MKS! 
*/

instance_of( function, Node, Path, Instances, Refs) :-
	get_host(Node, Result),
	\+ is_ghost(Result),
	find_type(Result, RType),
	Node has_class_refinement value of GroundExpr,
	get_units(Node, Base, Units),

	(GroundExpr = formal_parameter(_SL, _BA), !,
	    % everything for this has been done when instantiating the function
	    % containing he fragment call and left for us here in a reference
	    is_instance(function, Node, _, elt(Path, _, Base-Units), Base-Units,
			Instance),
	    Instances = [Instance];
	(setof(InputPair,
	       generate_input_pair(Node, identified, InputPair),
	       InputPairs ), !;
	    InputPairs = []),
	(setof(EvtPair,
	       generate_input_pair(Node, discrete, EvtPair),
	       EvtPairs), !;
	 EvtPairs = []),
	 all(user, arg, [unify(4), build(EvtPairs), build(EvtArgs)]),
	 all(user, arg, [unify(2), build(EvtPairs), build(EvtNodes)]),
	 all(user, arg, [unify(3), build(EvtPairs), build(EvtNames)]),
	 all(instance, is_instance, 
	     [build(_Type), build(EvtNodes), build(_Load),
	      build(EvtNames), build(_Dims), build(EvtRefs)]),
	 (build_sum(EvtArgs, EvtTrigger), !;
	   EvtTrigger = 1),
	(RType = state -> append(InputPairs, EvtPairs, AllowedInExp);
	    AllowedInExp = InputPairs),
	list_fragments_for_use(Node, FragSMs),
	replace_subexps(GroundExpr, instance, process_expr,
			sub(AllowedInExp, FragSMs, Refs), top_down,
			Switched, SubbedExpr),

	(member(RType, [creation, compartment]), !,
	    FinalExpr = SubbedExpr,
	    FType = init_function;
	    
	  (RType = event,
	      is_parameter(Node, PType),
	      nth0(PType, [magnitude, limit], FType);
	    member(RType-FType, [squirt-magnitude, state-state_fn])), !,	    
	    (FType = limit, !,
		apply_minmax(Node, result, BoundForm),
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
		Diffs = elt(Path, _, diffs-Units),
		SoughtExpr = check_limit(SubbedExpr, Lower, Upper, Flags,
					 Step, Diffs),
		FinalExpr = with_phase(Step, [], SoughtExpr),
		(Flags = 3 -> MagBase = int; MagBase = boolean),
		is_instance(internal, hist(Node), none, Diffs, diffs-Units,
			    DiffSt),
		Instances = [DiffSt, Instance];
% derived event or state: make magnitude expression
	     (EvtPairs = [_|_], !;
	       caption_for(Node, Capt),
	         raise_exception(no_antecedents_for_derived(Capt))),

	     (SubbedExpr = after(Wait, Eqn) -> % delay
	      PipeUnits = class_template(delay, _ArgUs)-Units,
	      % _ArgUs is unified with calculated units of arg by declaration
	      % of delay_for function in make_intermediates
	      Pipe = elt(Path, _, PipeUnits),
	      is_instance(internal, pipe(Node), none, Pipe, PipeUnits, DiffSt),
	      FinalExpr = event(after(Wait, Eqn, Pipe), EvtTrigger),
	      Instances = [DiffSt, Instance];
	     FinalExpr = event(SubbedExpr, EvtTrigger)),
	     EndRefs = EvtRefs);
	  RType = condition,
	    (is_lookup_cond(SubbedExpr, CondExpr), !,
	    /* Try alternative way of enumerating instances */
	        Void = 0,
	        FType = id_function;
	      CondExpr = SubbedExpr,
	        Void = '"false"',
	        FType = function),
	    (EvtTrigger = 1 ->
	        FinalExpr = CondExpr;
	      EndRefs = EvtRefs, 
	        FinalExpr = (trigger_magnitude('')=EvtTrigger,
			     choose(EvtTrigger '!=' 0, CondExpr, Void)));
	  (RType = alarm, !,
	    FType = al_function,
	    FinalExpr = al_spec(SubbedExpr, EvtTrigger, Later),
	    Path = [sm(_,_,_, fm_loop(_,_, al_action(Name, Later), _)) | _],
	    EndRefs = EvtRefs;
	   member(RType, [immigration, reproduction, loss]),
	    \+ EvtTrigger = 1, !,
	    FType = function,
	    FinalExpr = (trigger_magnitude('')=EvtTrigger,
			     choose(EvtTrigger '!=' 0, SubbedExpr, 0)),
	    EndRefs = EvtRefs;
	  FType = function,
	    FinalExpr = SubbedExpr)),

	(member(var_pair(_, Sub), Switched),
	    get_solo_list_depth(Sub, _), !,
	    caption_for(Node, Capt),
	    raise_exception(bad_parameter(Capt, Sub));
	suffix(EndRefs, Refs),
	    length(Refs, _Fix)),
	(nonvar(Instances), !;
	    Instances = [Instance]),
	 (nonvar(MagBase), !;
 	  MagBase = Base),
	 is_instance(FType, Node, FinalExpr, elt(Path, Name, MagBase-Units),
		     MagBase-Units, Instance)).
	     
/* Note if the function lacks a value it may not be the user's fault; it might be
an unnecessary virtual function generated in the SD view. 
So leave it out. However it may also be the fn of a ghost, so should get its
host's value */

instance_of(function, Node, _, Inst, Ref) :-
	get_host(Node, Result),
	Ref = [instance(variable, Result, _, Value, Dims)],
	Inst = [instance(variable, Node, _, Value, Dims)];
	Ref = [], Inst = [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* flows have the value of the node connected to the bowtie if there is one, and 
that of the continuation flow in the direction of this node if not. 

Working out the continuation direction is now done when processing the function node, so just use this value. */

instance_of(Pipe, Arc, _, [instance(Pipe, Arc, _, Value, Units)],
	    [instance(Ctrl, Function, _, Value, Units)]) :-
	member(Pipe-Ctrl, [flow-function, squirt-magnitude]),
	Arc has_part Function,
	find_type(Function, function).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loss object needs a boolean reflecting whether it actually happens

instance_of(loss, Node, Path,
	    [instance(loss, Node, Expr, elt(Path, _, boolean-[]), boolean-[])],
	    [instance(function, Function, _, Home, _)]) :-
	Home = elt(Path, _, _-[]),
	Arc is_connector from _ to Node,
	initiates(Arc, Function),
	(generate_input_pair(Function, discrete, _), !,
	    Expr = (rand(0,1)<Home); % this format identifies event losses
	  Expr = with_phase(Step, [], loses(Home, Step))).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* variables don't have any expressions of their own, they just have values which
are the same as the functions from which they are generated. This also goes for
condition, creation and loss nodes. Type is as function. */

instance_of(Type, Node, _, Inst, Ref) :-
	member(Type, [variable, condition, creation, alarm, 
		      event, state]),
	(member(Node, [B, A]),
	    Arc is_connector from A to B, !,
	    initiates(Arc, F),
	    Inst = [instance(Type, Node, FnType, Value, Dims)],
	    Ref = [instance(FnType, F, _, Value, Dims)];
	% Could not generate code for part with no connections, so kill it
	% (buggy legacy models only)
	caption_for(Node, Capt),
	    Node is_part_of Parent,
	    oblitterfry(Node),
	    caption_for(Parent, PCapt),
	    query(remove_orphan(Capt, PCapt), info, top, [ok], _)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_lookup_cond(GroundExpr, UseExpr) :-
%	GroundExpr = (index(1) is UseId),
%	   UseExpr = soloarr(UseId); % cheat to allow single-element arr
%	 GroundExpr = any(index(1) is UseExpr).
	(GroundExpr = any(IsConjunct), UseExpr = Cascade;
	 GroundExpr = IsConjunct, UseExpr = soloarr(Cascade)), !,
	havify(IsConjunct, _C, Cascade).

% use of 'choose' is arbitrary, it has the right unit tolerance
havify(index(1) is Val, 1, Val).
havify(index(N) is Val and Inner, N, choose('"true"', Val, Inners)) :-
	M is N-1,
	havify(Inner, M, Inners).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
build_sum([Solo], SoloArr) :-
    sum_over_dims(Solo, _Units, SoloArr).
    %SoloArr = Solo.
build_sum([First | Rest], FirstArr+Run) :-
    sum_over_dims(First, _Units, FirstArr),
    %FirstArr = First,
    build_sum(Rest, Run).

sum_over_dims(IP, ResDims, SD) :-
	(IP = sofar(input(_,_,_, Units)); IP = input(_,_,_, Units)),
				% in case of dashed influence
	analyze_array(Units, Base, Dims),
	(append(SummableDims, ResDims, Dims), \+ member(var, ResDims);
	 append(Dims, _RepDims, ResDims), SummableDims = [];
	throw(trigger_vs_event_dims_mismatch)), !,
	(Base = boolean -> Num = choose(IP,1,0); Num = IP),
	sum_dims(SummableDims, Num, SD).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%squirt_names_and_refs(Comp, Names, Refs) :-
%	(setof(SqtArc,
%	       Dir^LocalArc^(member(Dir, [in, out]),
%			     flows([squirt], Dir, Comp, LocalArc),
%			     find_name_host(LocalArc, SqtArc)), SqtArcs), !;
%	    SqtArcs = []),
%	all(instance, is_instance,
%	    [unify(squirt), build(SqtArcs), build(_Load), build(Names),
%	     build(_Type), build(Refs)]).
%	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
change_due_to(Type, Node, Base, Units, Change, Refs) :-
	(setof( Arc, flows([Type], in, Node, Arc), InArcs),
	    bind_and_build_term(Node, InArcs, Base, Units, In, In_refs),
	    Change = HaveInps;
	  In_refs = [],
	    Change = NoInps),
	(setof( Arc, flows([Type], out, Node, Arc), OutArcs),
	    bind_and_build_term(Node, OutArcs, Base, Units, Out, Out_refs),
	    HaveInps = In++(-Out),
	    NoInps = -Out;
	  Out_refs = [],
	    HaveInps = In,
	    NoInps = 0),
	append(In_refs, Out_refs, Refs).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
flows(Types, Dir, Comp, Flow) :-
	(Tgt = Comp; find_ghosts(Comp, Tgt)),
	(Dir = in, Dest = Tgt; Dir = out, Src = Tgt),
	Flow is_connector from Src to Dest,
	find_type(Flow, Type),
	member(Type, Types).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* generate_input_pair is used in setof so should be cut free */
generate_input_pair(Node, IType, input_pair(ArcName, NodeID, Ref, ExprRef)) :-
	m_update'><'get_all_links(Node, IType, ids(SourceID, Relation),
			       input_link(id(Link,_, SourceLocation), SrcData,
					  ArcName, SourceUnits, ArcUnits)),
	/* just in case we have extra inputs... */
	(nonvar(ArcName); SrcData = role_texts(ArcName, _,_,_)),
        NodeID = SourceID,
	RefExp = Ref,

	analyze_array(SourceUnits, FarUnits, FarDims),
	get_actual_sizes(Node, FarDims, bare, _,_,_),
	analyze_array(ArcUnits, BaseUnits, _),
	RelatedRef = input(SourceLocation, RefExp, Relation, ArcUnits),
	try_conversion(RelatedRef, FarUnits, BaseUnits, ConvertedRef),
	find_name_host(Link, ControlLink),
	(get_av_pair(ControlLink, 2, use_sofar, 1),
	    (find_type(SourceID, compartment),
		ExprRef = at_update(ConvertedRef);
	      \+ find_type(SourceID, compartment),
		ExprRef = sofar(ConvertedRef));
	\+ get_av_pair(ControlLink, 2, use_sofar, 1),
	    ExprRef = ConvertedRef).

try_conversion(RelatedRef, Units, BaseUnits, ConvertedRef) :-
	(Units = int -> TreatAs = 1; TreatAs = Units),
	get_conversion(RelatedRef, TreatAs, BaseUnits, ConvertedRef), !;    
	RelatedRef = ConvertedRef.
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
	Node has_class_refinement value of Eqn, !,
	% need to do this to expand macros etc
	replace_subexps(Eqn, instance, process_expr, sub([], [], []), top_down,
			_Switched, Default);
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
	get_actual_sizes(Node, Number, bare, _, Dims, _).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* Puts references to connecting flows into compartment definition; note that flows
intrinsically have same units as compartment, so we go back to their control nodes
to get unit conversion factor */

bind_and_build_term(Node, [Arc], NodeBase, NodeDims, Term, [Ref]) :-
	find_base(Arc, General_arc),
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
	default_tick_is(Tick),
	standard_name(NodeBase, TrimBase),
	(Arc has_type squirt -> ConvTo = TrimBase; ConvTo = TrimBase/Tick),
	try_conversion(Var, ArcUnits, ConvTo, Term).

bind_and_build_term(Node, [Arc|Arcs], Base, Dims, NewTerm, Refs) :-
	bind_and_build_term(Node, [Arc], Base, Dims, Term1, [Ref]),
	bind_and_build_term(Node, Arcs, Base, Dims, MidTerm, MidRefs),
	merge_lists([Ref], MidRefs, Refs),
	NewTerm =.. ['++',Term1,MidTerm].
	
sum_dims([], Var, Var).
sum_dims([_ | Rest], Middle, sum(Full)) :-
	sum_dims(Rest, Middle, Full).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arc_name_substitute takes a Prolog term apart, looks for atoms named in a
% list of name-node pairs, and reconstructs the resulting expression. Only they
% are little lists not atoms now.

% for the channel functions we want to use the visible component; dies_of and
% latency just return its value, while channel_is keeps the function as it is
% later processed into a comparison with an index saved in the individual.

% 'traffic' will not work because outvar will be the same for the two refs
% even though refnode is different. This is very hard to fix and can probably
% wait till we replace instantiation with something based on converting
% captions to unique c++ variable names.

process_expr(sub(InputPairs, FragSMs, Refs), OldVar, NewExpr, Recurse) :-
	% start by checking if param is in a special role for a ready-made
	% complex submodel type -- substitute with function on general role
% disable in favour of pre-built nbr list
%	expand_special_role(OldVar, InputPairs, NewExpr), !,
%	    Recurse = 1;
	\+ OldVar = 'reset...', % identifies initial value of state
	    member(OldVar-NewExpr-RefNode,
	       [dies_of(Var)-dies_of(NewVar)-VisNode,
		latency(Var)-NewVar-VisNode,
		Var-NewVar-Node]), 
	get_solo_list_depth(Var, _),
	(member(input_pair(Var, Node, OutVar, NewVar), InputPairs),
	    get_host(Node, VisNode),
	    is_instance(_, RefNode, _, OutVar, _, Ref),
	    member(Ref, Refs), !;
	NewExpr = Var),
	    Recurse = 0;
	(build_table_ref(table_const(1), OldVar, NewExpr);
	  member(OldVar-NewExpr, [channel_is(Ch)-channel_is(latency(Ch)),
		traffic(Ch)-ceil(Ch-latency(Ch))]),
	  atom(Ch)),
	    Recurse = 1;
	% model fragment defined function
	OldVar =.. [Fnct | ArgsOrDummy],
	    (ArgsOrDummy = [''] -> Args = []; Args = ArgsOrDummy),
	    % return a reference to the output in the submodel
	    fragment_expansion(_,_, Fnct, RetCapt, ArgData),
	    member(frags(FragSm, UsedYet), FragSMs), var(UsedYet), !,
	    UsedYet = yes,
	    with_capt(OutNode, _, FragSm, RetCapt),
	    OutNode has_class_refinement units of Multis,
	    is_instance(_, OutNode, _, ToMatch, _, Ref),
	    member(Ref, Refs), !,

	    % now recurse to make references for the arguments
	    all(instance, process_references,
		[build(Args), build(ArgData), unify(FragSm),
		 unify(sub(InputPairs, BuildArrs, Refs))]),

	    % submodel dimensions should be got later from rel path
	    pick_elt_from(input(in_hierarchy, ToMatch, none, Multis), BuildArrs,
			  NewExpr, place_in),
	    Recurse = 0;
	expand_library(OldVar, NewExpr),
	    Recurse = 1. % that's all the recursion we need

build_table_ref(Table, NoArgs, Table) :-
        member(NoArgs, [table, table('')]), !.

build_table_ref(Table, TableFn, RefTable) :-
	TableFn =.. [table, Ind1 | IndN], ShortTableFn =.. [table | IndN],
	build_table_ref(element(Table,Ind1), ShortTableFn, RefTable).

process_references(Arg, ArgCapt, FragSm,
		   sub(InPairs, BuildArrs, Refs)) :-
	with_capt(ArgNode, _, FragSm, ArgCapt),
	list_fragments_for_use(ArgNode, SubFrags),
	replace_subexps(Arg, instance, process_expr,
			sub(InPairs, SubFrags, Refs), top_down, _Sw, DoneArg),
	get_av_pair(ArgNode, 0, value, formal_parameter(SpareLoops, BuildArrs)),
	regenerate_makearrays(DoneArg, BuildArrs, DoneArgArr),
	append(BuildArrs, SpareLoops, AllLoops),
	pick_elt_from(DoneArgArr, AllLoops, DoneArgArrElt, index),
	is_instance(function, ArgNode, DoneArgArrElt, _, _, ToUse),
	member(ToUse, Refs).
		  
list_fragments_for_use(FnNode, FragSMs) :-
	(setof(frags(Sm, _), FnNode has_part Sm, FragSMs), !; FragSMs = []).

% rough and ready
pick_elt_from(Source, SpareLoops, SourceElt, LoopType) :-
	SpareLoops = [], SourceElt = Source;
	SpareLoops = [_First | Rest],
	    pick_elt_from(Source, Rest, Arr, LoopType),
	    length(SpareLoops, L),
	    Index =.. [LoopType, L],
	    SourceElt = element(Arr, Index).

regenerate_makearrays(Expr, [], Expr).
regenerate_makearrays(Expr, [set(_I, loop(N, _U)) | OuterLoops],
		      makearray(OuterExpr, N)) :-
	regenerate_makearrays(Expr, OuterLoops, OuterExpr).

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

% 3rd arg of *m_loop(...) is inserted by extract_submodel_assignments
path_section_for(SmName, Context, SmDims, Level, HiPtr, LoPtr) :-
	list_local_index_meanings(SmName, ISpecs),
	all(dialogue, index_types, [build(ISpecs), build(RevIndxCount)]),
	reverse(RevIndxCount, IndxCount),
	(variable_size(SmName), !,
	    (% by_record(SmName), !,
		% SmSpec = vm_loop(rec, _,[],_);
	    is_population(SmName), !,
		SmSpec = vm_loop(pop, IndxCount, [],_);
	    SmSpec = vm_loop(_Bounds, IndxCount, _Loops, _)),
	    Level = [sm(Context, HiPtr, LoPtr, SmSpec)];
	((by_record(SmName); from_value(SmName)), !,
	    SmSizes = [pra_bound(HiPtr, Context)];
	 all(ame_gen, enum_type_ref, [build(SmDims), unify(SmName),
				     build(SmSizes), build(SmBds), build(_)])),
	    make_inds_for(SmSizes, SmBds, SmPath, SmInds),
	    Level = [sm(Context, HiPtr, LoPtr,
			fm_loop(SmInds, IndxCount,_,_)) | SmPath]).
