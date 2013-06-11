/*
model_update.pl
---------------
This is the package of procedures that are called when an editing action is
attempted, and which, if the action is a plausible one, update the model
representation using Geraint's interaction protocol. The model representation
itself is only addressed from within the database module.
*/

sicstus_module(m_update,
	       [list_evt_captions/2, get_av_pair/4, add_parameter/4,
		list_index_meanings/2, list_local_index_meanings/2,
		get_input_info/2,get_link_source_data/7, find_node_with_data/3,
		valid_input/3, check_unit/4,
		need_same_dims/2,
		get_submodel_interface/5, load_submodel_interface/4,
		load_references/2, save_references/2, link_ends/4,
		update_links_and_vars/1,
		name_from_role_texts/3, sort_for_link/4, abs_path_name/3,
		build_array/3, analyze_array/3, get_all_enum_types/2,
		get_solo_list_depth/2, delete_implicit_node/1, 
		add_implicit_function/2, default_units/3, units_match_context/4,
		get_exogenous_node/2, find_all_links/2,
		make_node/3, one_end_in/2, new_line/5,
		presence_affects/2, status_affects/2,
		can_start/2, can_finish/3, continues_in/2, continues_from/2,
		add_equivalence/3, oblitterfry/1,
		list_cross_border_specs/2, is_top_arc/1,
		fast_delete/1, superfast_delete/1, do_delete/1, sever_links/2,
		add_new_line_between/4, change_class/3, get_disag_params/2,
		time_step_for/3, use_units_in/2,
		make_ghost/3, get_possible_start/2]).

sicstus_use_module([library(lists),
		sp_only, units, utility, state, ame_gen, m_class, text]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   UTILITY PROCEDURES FOR MANIPULATING COMPONENT PARAMETERS              %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* add_parameter: adds a new attribute-value pair to an object. Arg 1 is the object ID, 2 the type of parameter (0 = class refinement, 1 = model refinement, 2 = link attribute) 3 and 4 the attribute and value. */

add_parameter(Object, Class, Attribute, Value) :-
	(Attribute = '', !;
	clear_av_pair(Object, Class, Attribute),
		(Value = '', !;
		add_av_pair(Object, Class, Attribute, Value))).

clear_av_pair(Object, Class, Attribute) :-
	(Class = 0, Object no_longer_has_class_refinement Attribute of _;
	Class = 1, Object no_longer_has_model_refinement Attribute of _;
	Class = 2, Object no_longer_has_attribute Attribute of _), !.

clear_av_pair(_, _, _).

add_av_pair(Object, Class, Attribute, Value) :-
	Class = 0, Object has_new_class_refinement Attribute of Value;
	Class = 1, Object has_new_model_refinement Attribute of Value;
	Class = 2, Object has_new_attribute Attribute of Value.

get_av_pair(Object, Class, Attribute, Value) :-
	Class = 0, Object has_class_refinement Attribute of Value;
	Class = 1, Object has_model_refinement Attribute of Value;
	Class = 2, Object has_attribute Attribute of Value.

/* get_exogenous_node: finds a node in a model that cannot be calculated without
access to the outside of the model */

get_exogenous_node(Model, Node) :-
	Model has_link_equivalences LinkList,
	member(Out-In, LinkList),
	Out is_connector from _ to Model,
	In is_connector from _ to Node.

/* moving_endpoint/2: succeeds if the obj is
a line and one of the endpoints of that line correspond to an hierarchical
interface (i.e., is not drawn); returns the identifier for which end it is

moving_endpoint(Obj, Termination, OtherLink) :-
	(continues_from(Obj, Submodel),
		Termination = moving_start;
	continues_in(Obj, Submodel),
		Termination = moving_finish),
	Submodel has_link_equivalences Links,
	member(Link, Links),
	(Link = Obj-OtherLink; Link = OtherLink-Obj). */

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   GETTING INFORMATION ABOUT PARAMETERS FOR A NODE'S EQUATION            %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* get_input_info/2: This takes a function node and returns a list of all the 
variables which are connected to it as inputs, the 'destination' parameters on all
the links by which they are connected, and the units they have at their source.

Note that this will have to add instance parameters to the list in some cases when
dealing with multiple instances. */

:- dynamic(input_links_were/1).

list_evt_captions(Part, ['reset...' | EvtCapts]) :-
	setof(DiscIn,
	      P1^(m_update'><'get_all_links(Part, discrete, P1, DiscIn)),
	      EvtLinks), !,
	    all(user, arg, [unify(2), build(EvtLinks), build(EvtRoles)]),
	    all(user, arg, [unify(1), build(EvtRoles), build(EvtCapts)]), !;
	EvtCapts = [].

get_input_info(Function, Input_list) :-
	(setof(Link_entry,
	      IDs^get_all_links(Function, continuous, IDs, Link_entry),
	      Input_list),
	    decide_param_names(Input_list), !;
	Input_list = []),
	retractall(input_links_were(_)),
	assert(input_links_were(Input_list)).

get_all_links(Function, SrcType, ids(RemoteNode, Relation),
              input_link(id(Link, Index, SourceLocn), RemoteName, LocalName, 
			RemoteUnit, Local_unit)) :- 
	/* this should be cut free */
	(valid_input(Function, SrcType, Link);
	    Function has_class submodel,
	    Link is_connector from _ to Function),
	Link has_type influence,
	find_name_host(Link, LinkWithAttrs),
	(get_av_pair(LinkWithAttrs, 2, suppressed_roles, SuppArg) ->
	 Supps = SuppArg; Supps = []),

	get_link_source_data(Link, Function, RemoteNode, RemoteUnit,
		Relation, Index, SourceLocn),
	\+ member(Index, Supps),
	check_ET_consistency(RemoteUnit, RemoteNode, Function),
	use_destination(Link, RemoteUnit, 
			Index, LocalName, Local_unit),
	find_all_comps(DestBox, Function),
	rel_path_name(RemoteNode, DestBox, Relation, SourceLocn, RemoteName).

get_link_source_data(Link, Function, RemoteNode, RemoteUnit,
		Relation, Index, SourceLocation) :-
	initiates(Link, InitNode),
	find_node_with_data(InitNode, InitBase, ValueSource),
	(find_type(InitNode, Type),
	    member(Type, [immigration, creation, reproduction, loss]), !,
	    RemoteNode = ValueSource;
% use implicit node if a channel, as vis node has remainder rather than eqn val
	RemoteNode = InitBase),
	get_spec_units(ValueSource, ActualUnits),
	get_unit_conversion(ValueSource, Function, Subs, 
		Relation, Index, SourceLocation),
	build_array(ActualUnits, Subs, RemoteUnit).

check_ET_consistency(RemoteUnit, RemoteNode, Function) :-
	/* Now check if enumerated type definitions are same at each end */
	analyze_array(RemoteUnit, Base, Dims),
	(Base = a(Type);
	Base = boolean, Type = boolean;
	Type = 0), !,
	(member(Checking, [Type | Dims]),
	event'><'insert_mem_list(Checking, RemoteNode, SourceEnumSpec),
	event'><'insert_mem_list(Checking, Function, DestEnumSpec),
	\+ DestEnumSpec = SourceEnumSpec, !,
	caption_for(RemoteNode, RemoteCapt),
	query(enum_type_mix(RemoteCapt, Checking, SourceEnumSpec, DestEnumSpec),
	      warning, top, [ok], not);
	true).

find_node_with_data(Edit_thing, Base, Control_thing) :-
	find_base(Edit_thing, Base),
	(implicit_function(Base, Control_thing), !;
	    Control_thing = Base).

abs_path_name(RemoteNode, DestBox, RemoteName) :-
	get_host(RemoteNode, VisibleNode),
	find_all_comps(SourceBox, VisibleNode),
	get_chain(SourceBox, DestBox, _, Downs, Ups),
	list_downs(Downs, DownAll),
	list_ups(Ups, UpAll),
	caption_for(VisibleNode, LocalCaption),
	append_atoms([UpAll, DownAll, LocalCaption], RemoteName).

/* old version actually built the x-planatory text...ugh
rel_path_name(RemoteNode, DestBox, Relation, SourceLocn, RemoteName, Tail) :-
	abs_path_name(RemoteNode, DestBox, AbsName, Tail),
	(Relation = none, !,
		RemoteName = AbsName;
	(Relation has_type relation, !,
	    (SourceLocn = in_base, !,
		Dir = (from);
	    Dir = (to)),
	    caption_for(Relation, RelCaption),
	    initiates(Relation, BaseBox),
	    caption_for(BaseBox, BaseBoxCaption),
	    sicstus_format_to_chars("~a (~a \"~a\" in \"~a\")",
			    [AbsName, Dir, BaseBoxCaption, RelCaption],
			    RemoteStr);
	sicstus_format_to_chars("~a (active channel?)", [AbsName], RemoteStr)),
	name(RemoteName, RemoteStr)).

v5.7 version: merely generate the strings and allow their arrangement elsewhere
according to norms of whichever language is being used */
rel_path_name(RemoteNode, DestBox, Relation, Dir,
	      role_texts(AbsName, BaseBoxCaption, Dir, RelCaption)) :-
	abs_path_name(RemoteNode, DestBox, AbsName),
	(Relation = none, !,
	    RelCaption = '/none/',
	    BaseBoxCaption = '/none/';
	Relation has_type relation, !,
	    caption_for(Relation, RelCaption),
	    initiates(Relation, BaseBox),
	    caption_for(BaseBox, BaseBoxCaption);
	append_atoms(['/', Relation, '/'], RelCaption)).
	
list_downs([], '').

list_downs([Node | Rest], All) :-
	caption_for(Node, This),
	list_downs(Rest, Others),
	append_atoms([Others, This, '/'], All).

list_ups([], '').

list_ups([_ | Rest], All) :-
	list_ups(Rest, End),
	append_atoms('../', End, All).

get_spec_units(Node, Unit) :-
	Node has_class_refinement units of Unit, !;
	Node has_attribute units of Unit, !;
	Unit = any.

/* list_index_meanings: creates a list of atoms that are descriptions of the meanings of the 'index(n)' function with all its possible values. */

list_index_meanings(root, []).

list_index_meanings(Submodel, Meanings) :-
	list_local_index_meanings(Submodel, Group1),
	find_all_comps(Contain, Submodel),
	(instance'><'counts_as_outside(Submodel), !,
	    find_all_comps(Parent, Contain);
	Parent = Contain),
	list_index_meanings(Parent, Group2),
	append(Group1, Group2, Meanings).

list_local_index_meanings(Submodel, Meanings) :-
	caption_for(Submodel, BareCaption),
	append_atoms(['"', BareCaption, '"'], Caption),
	(is_population(Submodel), !,
		LocalDims = [pop];
	(by_record(Submodel); from_value(Submodel)), !,
		LocalDims = [records];
	get_node_size(Submodel, LocalDims)),
	list_node_index_meanings(Caption, 
			LocalDims, Group1),
	list_links(Submodel, Links),
	get_link_exits(Links, Starts),
	list_link_index_meanings(Caption, Starts, Group2),
	append(Group1, Group2, Meanings).

list_link_index_meanings(_, [], []).

list_link_index_meanings(DestCapt, [exits(_, []) | Rest], Meanings) :-
	list_link_index_meanings(DestCapt, Rest, Meanings).

list_link_index_meanings(DestCapt, [exits(Link, [Start | SRest]) | LRest],
			 Meanings) :-
	list_local_index_meanings(Start, BaseMeanings),
	caption_for(Link, LinkCapt),
	sicstus_format_to_chars(" in role \"~a\" for ~a", [LinkCapt, DestCapt], RoleCaptStr),
	all(m_update, append_base_role,
	    [build(BaseMeanings), unify([Link, RoleCaptStr]), build(First)]),
	list_link_index_meanings(DestCapt, [exits(Link, SRest) | LRest],
				 Last),
	append(First, Last, Meanings).

append_base_role(ind_spec(BaseMeaning, Posn, N, _OldLink), [Link, RoleCaptStr],
		 ind_spec(FullMeaning, Posn, N, Link)) :-
	name(BaseMeaning, BaseMeaningStr),
	append(BaseMeaningStr, RoleCaptStr, FullMeaningStr),
	name(FullMeaning, FullMeaningStr).

list_node_index_meanings(_, [], []).

list_node_index_meanings(Capt, Indices, [ind_spec(Capt, DimCount, Dim, none)
					| Meanings]) :-
	append(Early, [Dim], Indices),
	length(Indices, DimCount),
	list_node_index_meanings(Capt, Early, Meanings).

/* valid_input lists all the links that can be considered the
input to a function. i.e., those to that function, 
plus those to functions associated with variables
that are ghosts of that function's variable. */

valid_input(Real, SourceType, InputLink) :-
	implicit_function(RealVar, Real),
	find_base(RealVar, BaseVar),
	(GhostVar = BaseVar;
	find_ghosts(BaseVar, GhostVar)),
	implicit_function(GhostVar, AlsoUsed),
	InputLink is_connector from _ to AlsoUsed,
	initiates(InputLink, Source),
	get_host(Source, VisSource), % for flows/squirts with links from fn
	(SourceType = continuous,
	    \+ VisSource is_of_sort discrete; % event values not to be used
	  SourceType = discrete,
	    VisSource is_of_sort discrete). % event values to be used

/* This generates the extra array nestings due to submodels that are exited between a
link's source and its destination. Note that if the destination is a creation or
immigration node, it gets input arrays as if it were in its parent's environment rather
than in its own.

This also finds which relations may play a role in this parameter's meaning.
Currently these are restricted to those connecting an ancestor of the input
node with an ancestor of the destination, and they are referred to by the
section at the destination end to keep referencing consistent. However we may
later want to use relations whose start is a submodel of that containing the
parameter or destination. */

get_unit_conversion(Remote, Local, 
		Subs, Relation, Index, SourceLocation) :-
	(instance'><'counts_as_outside(Remote), !,
	        DefRel = outside,
		RemoteEnv has_part Remote;
	DefRel = none,
	    RemoteEnv = Remote),
	(instance'><'counts_as_outside(Local), !,
		LocalEnv has_part Local;
	LocalEnv = Local),
	find_all_comps(RemoteModel, RemoteEnv),
	find_all_comps(LocalModel, LocalEnv),
	get_chain(RemoteModel, LocalModel, _, Exited, Entered),
	reverse(Exited, BiggestFirst),
	(/* Do not display parameter for input without role reference if there
	is a reference...as of v5.7, do -- but use in_base or in_assoc as
	appropriate (keep link id of none). */
	all(ame_gen, get_all_dims, [build(BiggestFirst), append(Subs, [])]),
	    relation_of_source(Exited, Entered, SourceLocation),
	    Relation = DefRel,
	    Index = none;
	suffix([Base | ReallyExited], BiggestFirst),
	    member(Assoc, Entered),
	    connects(Relation, Base, Assoc),
	    Relation has_type relation,
	    Relation is_connector from Base to _,
	    IndexRelation is_connector from _ to Assoc,
	    (IndexRelation = Relation; sequence(Relation, IndexRelation)),
	    find_reference(LocalModel, Index, IndexRelation),
	    all(ame_gen, get_all_dims, [build(ReallyExited), append(Subs, [])]),
	    SourceLocation = in_base;
	suffix([Assoc | ReallyExited], BiggestFirst),
	    member(Base, Entered),
	    connects(Relation, Base, Assoc),
	    Relation has_type relation,
	    Relation is_connector from Base to _,
	    find_reference(LocalModel, Index, Relation),
	    (is_exclusive_role(Relation),
		all(ame_gen, get_all_dims,
		    [build(ReallyExited), append(Subs, [])]);
	    \+ is_exclusive_role(Relation),
		all(ame_gen, get_all_dims,
		    [build([Assoc | ReallyExited]), append(Subs, [])])),
	    SourceLocation = in_assoc).

relation_of_source(Exited, Entered, SourceLocation) :-
	member(Far, Exited), member(Near, Entered),
	    (connects(Relation, Far, Near),
		SourceLocation = in_base;
	      connects(Relation, Near, Far),
		SourceLocation = in_assoc),
	    Relation has_type relation, !;
	  SourceLocation = in_hierarchy.

is_exclusive_role(Role) :-
	find_name_host(Role, RoleWithAttrs),
	RoleWithAttrs has_attribute exclusive of 1.

use_destination(Link, RemoteUnit, 
		RelationIndex, LocalName, LocalUnit) :-
	Link has_attribute role of DestData,
	member(use(RelationIndex, _, PrevRep, GivenUnit), 
			DestData),
	(PrevRep = usr(PrevName); PrevRep = PrevName), !,
	add_brackets(Inter_name, _, PrevName),
	add_brackets(Inter_name, RemoteUnit, LocalName),
	analyze_array(GivenUnit, LBaseUnit, _),
	analyze_array(RemoteUnit, RBaseUnit, Subs),
	/* Refer to value by same units as before, provided conversion
	from actual units is possible */
	(check_unit(RBaseUnit, LBaseUnit, 2, []), !,
	    build_array(LBaseUnit, Subs, LocalUnit);
	LocalUnit = RemoteUnit);
	LocalUnit = RemoteUnit.

add_brackets(Name, array(Unit, _), [Name2]) :- !, 
	add_brackets(Name, Unit, Name2).

add_brackets(Name, list(Unit), {Name2}) :- !, 
	add_brackets(Name, Unit, Name2).

add_brackets(Name, _, Name).

/* check_unit/4: Takes a Prolog term then checks that it is plausible,
i.e., each atom corresponds to a known unit and they are only combined
using * and /, and that boolean is not combined with anything until I
can think of circumastances in which it would make sense to do so.

Well, we might want to allow a number to be used as a boolean
(implicit conversion) so I have added 'severity' which is as defined
as follows:

0: Succeeds for any pair of units that can be matched
1: Allows assignment to convert from 'int' to 'real' but not back
2: Checks for convertibility between physical units
3: Types must be identical or physically equivalent

Note that the 2nd argument, Target_unit, is the one the user has somehow
provided...*/

check_unit(Unit_term, Target_unit, Severity, Complaint) :-
	analyze_array(Unit_term, Unit_base, DimExprs),
	analyze_array(Target_unit, Target_base, TargetExprs),
	/* (on_exception(ParseUnit, (get_actual_sizes(DimExprs,Dims0),
				 get_actual_sizes(TargetExprs,Dims1)), true),
        */
	(DimExprs = TargetExprs, !,
	    ((member(Target_base, [any, n(_ET1), a(_ET2),
				      boolean, cond_spec, int]), !,
	          Target_type = Target_base;	 
	      check_and_report_units(Target_base, TargetDims, _),
	          Target_type = real),
		(Severity = 0, !;
		    /* Unit_base = Target_base, !; */
		    inters'><'promote_arg(Unit_base, Target_type, Unit_type), !,
		    (Target_unit = 1, Target_name = real;
			Target_name = Target_unit),
		    (Severity = 1, !;
			\+ Target_type = real, !;
% flag up dimensionless conversions; here is not really the place
%		      (\+ TargetDims = 1; Scale = 1.0;
%			  query(is_scale_factor(Target_unit, Scale),
%				warning, top, [ok], ok)), !,
		      nonvar(Unit_type),
			get_conversion(1, Unit_type, Target_base, Scale),
			(Severity = 2, !;
			1 is Scale, !;
			Complaint = needs_conversion(Target_name, Target_base,
						     Unit_base));
		    (check_and_report_units(Unit_base, UnitDims, _), !;
		     UnitDims = Unit_base),
		    Complaint = mismatched_dimensions(Target_name, TargetDims,
						      Unit_base, UnitDims));
		Complaint = bad_type_conversion(Unit_base, Target_type));
	    Complaint = unknown_unit(Target_base));
	Complaint = mismatched_arrays(Target_unit, TargetExprs, DimExprs)),
	(nonvar(Complaint); Complaint = []).

/* decide_param_names fills in the 'local name' slot in these data structures; first
it lists all those which already have names, then generates new ones which differ
from these for those which havent. */

need_same_dims(Item, Affected) :-
	(initiates(Affected, Item); terminates(Affected, Item)),
	Affected is_of_sort transfer.

end_with_units(Flow, EndUnits) :-
	% returns units for matching to adjoining flows
	need_same_dims(Comp, Flow),
	implicit_function(Comp, Fn),
	Fn has_class_refinement units of EndUnits.

match_all_units([_Unit], []).
match_all_units([U1, U2 | Rest], Whinge) :-
	match_all_units([U2 | Rest], SubWhinge),
	(SubWhinge = [], !,
	    check_unit(U1, U2, 2, Whinge);
	 Whinge = SubWhinge).

endpoint_units(Flow, EndUnits, Whinge) :-
	setof(EndUnit, end_with_units(Flow, EndUnit), [EndUnits | More]), !,
	match_all_units([EndUnits | More], Whinge);
	Whinge = [].
/*
check_flow_ends(Func, EndUnits, AnyErr) :-
	get_host(Func, Flow),
	setof(UConstraint, end_with_units(Flow, UConstraint), AllUnits),
	(var(EndUnits),
	    AllUnits = [EndUnits | ToMatch];
	 nonvar(EndUnits),
	    ToMatch = AllUnits),
	member(Next, ToMatch),
	check_unit(Next, EndUnits, 2, Err),
	\+ Err = [], !,
	    AnyErr = Err;
	AnyErr = [],
	(EndUnits = 1; true), !.
*/	    
decide_param_names(InputList) :-
	already_used_in(InputList, Used),
	all(m_update, generate_new_name, [build(InputList), unify(Used)]).

already_used_in(List, Used) :-
	(setof(Name, link_uses(List, Name), AlreadyUsed), !; AlreadyUsed = []),
	append(AlreadyUsed, _, Used).

link_uses(List, Name) :-
	member(input_link(_,_,BrName,_,_), List),
	ground(BrName),
	add_brackets(Name, _, BrName).

insert_existing_names(_, N, N).

generate_new_name(input_link(_, RoleTexts, Local_name, Remote_unit, _), Used) :-
	nonvar(Local_name), !;
	name_from_role_texts(RoleTexts, Used, Inter_name),
	add_brackets(Inter_name, Remote_unit, Local_name).

name_from_role_texts(role_texts(Path, RelId, Dir, RelnCapt), Used, Name) :-
	name(Path, PathStr),
	(TailStr = PathStr; suffix([47 | TailStr], PathStr)), % [47] = "/"
	\+ member(47, TailStr),
	name(Tail, TailStr),
	(Dir = in_hierarchy,
	    Remote_name = Tail;
	  RelId = '/none/',
	    append_atoms(every_, Tail, Remote_name);
	  Dir = in_base,
	    append_atoms([RelnCapt, '_', Tail], Remote_name);
	  append_atoms([Tail, '_', RelnCapt], Remote_name)), !,
	generate_name(prolog, Remote_name, Name, Used).
	
/* This one updates the info on the links after the dialogue box has been filled in.
*/

update_links_and_vars([]).

update_links_and_vars(InputList) :-
	InputList = [input_link(id(Link,_,_), _,_,_,_) | _],
	sort_for_link(InputList, Link, ThisList, OtherList),
	all(m_update, make_role, [build(ThisList), build(Roles)]),
	(Link has_changed_attribute role to Roles;
		Link has_new_attribute role of Roles),
	update_links_and_vars(OtherList).

make_role(InputLink, use(Index, SourceLoc, NewName, Unit)) :-
	InputLink = input_link(id(Link, Index, SourceLoc),_, Name,_, FullUnit),
	input_links_were(OldLinks),
	(member(InputLink, OldLinks),
	\+ (Link has_attribute role of OldRoles,
	    member(use(Index, SourceLoc, usr(_), _), OldRoles)),
	    NewName = Name;
	NewName = usr(Name)),
	build_array(Unit, _, FullUnit), !.

/* sort_for_link: Takes a list of input link structures and an id for an influence, and returns lists of the link structures which use it and those which do not. */

sort_for_link([], _, [], []).

sort_for_link([Link | OtherLinks], Target, Right, Wrong) :-
	sort_for_link(OtherLinks, Target, OtherRight, OtherWrong),
	(Link = input_link(id(Target, _,_), _,_,_,_), !,
		Right = [Link | OtherRight],
		Wrong = OtherWrong;
	Right = OtherRight,
		Wrong = [Link | OtherWrong]).

/* make_role_first: In order to use one-sided relation enumeration, modellers
need to be able to specify which of an association's base models' indices to
use as index(1). What this does is change the order of an association
submodel's references to make the given role first, then change references
in incoming links and submodels to reflect that change. */

make_role_first(Role) :-
	terminates(Role, Model),
	(terminates(OtherRole, Model), % un-flag any other relations
	    find_type(OtherRole, relation),
	    \+ OtherRole = Role,
	    find_name_host(OtherRole, OtherRole), % only proceed for host
	    add_parameter(OtherRole, 2, can_lookup, 0),
	    fail;
	Model has_model_refinement references of Refs),
	append(Before, [local(Role) | After], Refs),
	append([After, Before, [local(Role)]], NewRefs),
	length(After, Shift),
	length(Refs, Size),
	Model has_changed_model_refinement references of NewRefs,
	Model has_part Component,
	(find_type(Component, submodel),
	    Component has_model_refinement references of SubRefs,
	    all(m_update, roll_match, [build(SubRefs), unify(Shift),
				       unify(Size), build(NewSubRefs)]),
	    Component has_changed_model_refinement references of NewSubRefs;
	 find_type(Component, function),
	    Link is_connector from _ to Component,
	    find_type(Link, influence),
	    Link has_attribute role of LRoles,
	    all(m_update, roll_match, [build(LRoles), unify(Shift),
				       unify(Size), build(NewLRoles)]),
	    Link has_changed_attribute role to NewLRoles),
	fail.

roll_ref(N, Shift, Size, NewN) :-
	MidN is N+Shift,
	(MidN >= Size, !,
	    NewN is MidN - Size;
	NewN is MidN).

roll_match(Old, Shift, Size, New) :-
	Old =.. [Fn, N | Rest],
	    integer(N), !,
	    roll_ref(N, Shift, Size, M),
	    New =.. [Fn, M | Rest];
	New = Old.
	
build_array(Base_type, Dims, Array) :-
	Dims = [], Base_type = Array;
	Dims = [Dim | SubDims],
		build_array(Base_type, SubDims, Sub_type),
		(Dim = var,
		    Array = list(Sub_type), !;
		Array = array(Sub_type, Dim)).

analyze_array(Array, Base_type, Dims) :-
	nonvar(Array),
	(Array = array(Sub_type, Dim); Array = list(Sub_type), Dim = var), !,
		analyze_array(Sub_type, Base_type, SubDims),
		Dims = [Dim | SubDims];
	Base_type = Array, Dims = [].

get_solo_list_depth(List,Dims) :-
	atom(List), \+ List = '', \+ name(List, [34 | _]), Dims = _;
	(List = [Ellie], Dims = array(D, _);
	    List = {Ellie}, Dims = list(D)),
		get_solo_list_depth(Ellie, D).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   ADDING A NEW COMPONENT TO THE MODEL                                   %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* add_implicit_function/2: This sets up the hidden nodes for the mode that we are
in, currently a function if the mode is system dynamics and the new node is a 
variable or a flow. This also copies parent's role references for new submodels.*/

add_implicit_function(Exp_node, Node_name) :-
	get_style(sd),
	Exp_node is_of_sort has_function, !,
	    (Exp_node is_of_sort line, !,
		make_node(Exp_node, function, Node_name),
		Node_name has_new_graphical_attribute along of 550;
	    find_all_comps(Parent, Exp_node),
		make_node(Parent, function, Node_name),
		new_line(influence, [], Node_name, Exp_node, _)),
	    (default_units(Exp_node, Base, Dims),
		nonvar(Base),
		build_array(Base, Dims, Units),
		Node_name has_new_class_refinement units of Units, !;
	     true);
	Exp_node has_class submodel,
	Parent has_part Exp_node,
	Parent has_model_refinement references of ParentRefs, !,
	    convert_refs(ParentRefs, 0, ChildRefs),
	    Exp_node has_new_model_refinement references of ChildRefs;
	true.

default_units(Node, Base, Dims) :-
	get_host(Node, Form),
	(Sort = transfer,
	    units_from_context(Node, Base, Dims, []);
	member(Sort-Base, [rate-(1/day), transfer-1, level-1,
			   cond_value-cond_spec, boolean_value-boolean])),
	Form is_of_sort Sort,
	(\+ Form is_of_sort channel;
	    Dims = []), !.

/* This could probably be a lot simpler, especially as the returned
error message (Whinge) is currently never used, except to make the
predicate fail if it is not []... */

units_from_context(Node, Base, Dims, Whinge) :-
	get_host(Node, Form),
	(Form is_of_sort transfer,
	    endpoint_units(Form, EndUnits, Whinge), !,
	    (\+ Whinge = [], !;
		(var(EndUnits), !;		   % pass back default
		 analyze_array(EndUnits, EndType, Dims),
		    (Form is_of_sort rate -> default_tick_is(Tick); Tick=1),
		    standard_name(EndType, EndTypeStd),
		    Base = EndTypeStd/Tick));
	 Whinge = []).		% not a flow so no constraint.
	
units_match_context(Node, Base, Dims, Whinge) :-
	units_from_context(Node, EndType, EndWraps, ConsistencyWhinge),
	(ConsistencyWhinge = [], !,
	    (var(EndWraps), !,	 % no compartments to match
	         Whinge = [];	 % pass back default
	         (EndType = 1, !,
		      member(Base, [EndType, int]), % plead igronance
		      Dims = EndWraps,
		      Whinge = [];
		    (build_array(EndType, EndWraps, DefUnits),
			(Base = EndType, Dims = EndWraps, !;
			    build_array(Base, Dims, Units),
			    check_unit(DefUnits, Units, 2, Whinge)))));
		Whinge = ConsistencyWhinge).
	
convert_refs([], _, []).

convert_refs([OldRef | R1], SoFar, [NewRef | R2]) :-
	(OldRef = obsolete, NewRef = obsolete;
	member(OldRef, [local(_), ancestor(_)]),
	       NewRef = ancestor(SoFar)),
	NowDone is SoFar + 1,
	convert_refs(R1, NowDone, R2).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node is_no_longer_model_class succeeds if Node has been deleted from the tree
% along with all its related information
% NB much more work to do here once connectors are installed; think about
% connectors through the model class boundary, and about inherited values

oblitterfry(Node) :-
	Node is_part_of Parent,
	\+ Node has_part _OtherNode,
	!,
	Node no_longer_has_refinements,
	Node no_longer_has_connections,
	Node no_longer_has_graphical_attributes,
	Node is_no_longer_part_of Parent,
	Node is_no_longer_model_class.

delete_implicit_node(Exp_node) :-
	implicit_function(Exp_node, Imp_node),
	unghost(Imp_node),
	oblitterfry(Imp_node), fail;
	true.

/* new_line: This adds a line to the model, the arguments being (1) the class of line, (2) The list of coordinate pairs specifying its path, (3) and (4) the objects on which it starts and finishes. This always succeeds as the allowability of the operation is checked while dragging is in progress in order to highlight start and finish points correctly. Both arcs and nodes have their names initially set to their internal IDs.*/

new_line(Type, Attributes, Start, Finish, Arc) :-
	Arc is_new_connector from Start to Finish,
	Arc has_new_type Type,
	Arc draws_inside Parent,
	unique_name_for_new(Parent, Type, Name),
	add_line_attributes(Arc, [[name, Name] | Attributes]),
	add_implicit_function(Arc, _).

add_line_attributes(_, []).

add_line_attributes(Arc, [[A, V] | Attributes]) :-
	add_av_pair(Arc, 2, A, V),
	add_line_attributes(Arc, Attributes).

/* Now this one actually adds the node as a child of whatever the window is 
displaying. The initial window displays root (i.e., the Desktop); this should be 
asserted as part of the system initialization. Windows created later will have 
their own display parameter. */

make_node(Parent, Type, Node) :-
	unique_name_for_new(Parent, Type, Name),
	Node is_new_part_of Parent,
	Node has_new_class Type,
	Node has_new_class_refinement name of Name.

get_abbrev(Full, TrShort) :-
	append_atoms(Full, '_abbrev', Key),
	expand_message(Key, [], TrShort).

one_end_in(Boxes, Arc) :-
	spans_border(Boxes, Arc); link_section(Boxes, Arc).

spans_border(Boxes, Arc) :-
	in_one_of(Box1, Boxes),
	(Arc is_connector from Box1 to Box2;
	Arc is_connector from Box2 to Box1),
	\+ in_one_of(Box2, Boxes).

in_one_of(Box, Boxes) :-
	member(Box1, Boxes),
	contains(Box1, Box).

link_section(Boxes, Arc1) :-
	member(Arc1, Boxes),
	Arc1 is_connector from Box1 to Box2,
	\+ member(Box1, Boxes),
	\+ member(Box2, Boxes).
	
change_class(Object, Old, New) :-
	Object has_class Old, !,
	Object no_longer_has_class Old,
	Object has_new_class New,
	true.

/* find_all_links: recursion has been removed as the routine that calls it now recurses
find_all_links(End, VisLink) :-
	find_all_links(End, VisLink, _Where).

find_all_links(End, VisLink, Where) :-
	(Link is_connector from End to Mid, Where = start;
	Link is_connector from Mid to End, Where = finish),
	return_relevant(End, Mid, Link, VisLink).

return_relevant(End, Mid, Link, VisLink) :-
	implicit_function(End, Mid), !,
		find_all_links(Mid, VisLink);
	implicit_function(Mid, End), !,
		fail;
	VisLink = Link.
*/

find_all_links(Comp, Link) :-
	implicit_function(Comp, Terminus), !,
	    select(Relevant, [Comp, Terminus], Spare),
	    select(Relevant, [Src, Dest], Far),
	    Link is_connector from Src to Dest,
	    \+ Far = Spare; % not the link from the fn
	  member(Comp, [Src, Dest]),
	    Link is_connector from Src to Dest.

/* can_start/2: This takes a linear type (flow, influence) and a point at which it might start. If there is a box object at that point which might constitute a start for that linear, returns it, otherwise fails.  */

can_start(Ltype, Box) :-
	find_type(Box, Type),
	(Ltype = Type;
	can_connect(Ltype, Type, _), !),
	\+ start_full(Ltype, Box).

/* finish in a submodel is still allowed, we will attempt to draw a new component at
the end of the link */

can_finish(Ltype, Box1, Box2) :-
	(appears(Box2), !; contains(Box2, Box1)),
	different(Box1, Box2),
	\+ u_turn(Ltype, Box1, Box2),
	find_type(Box1, Type1),
	find_type(Box2, Type2),
	(Type1 = Ltype, !,
		Box1 is_connector from Node1 to _;
	Node1 = Box1),
	find_type(Node1, Start_type),
	( \+ Type2 is_primitive, !;
	Type2 = Ltype, !,
		Box2 is_connector from Node2 to _,
		initiates(Box2, Node2), /* cannot continue if target is
					already a continuation */
		(Node1 is_connector from Start to _, Parent has_part Start;
		Parent has_part Node1),
		\+ Parent has_part Node2;
	can_connect(Ltype, Possible_type1, Type2),
	(\+ Start_type is_primitive; Start_type = Possible_type1)),
	\+ finish_full(Ltype, Box2),
	/* final problematic case -- connect two already defined flows */
	\+ ([Ltype, Type1, Type2]=[flow, flow, flow],
	       all(image, draws_complete, [build([Box1, Box2])])),
	/* last and final problematic case -- relation that forms a loop */
	\+ (Ltype = relation,
	       membership_depends(Box2, Box1)),
	/* last and very final problematic case -- a duplicate influence */
	\+ (Ltype = influence,
	       (implicit_function(Box2, Terminus);
		find_type(Box2, submodel),
		   (Terminus = Box2;
		   find_all_comps(Box2, Terminus),
		       border_node(Terminus))),
	       (terminates(Box1, Terminus);
		(Dup is_connector from _ to Terminus,
		    initiates(Dup, Box1),
		    find_type(Dup, influence)))).

membership_depends(Ind, Dep) :-
	(find_all_comps(Con, Dep);
	Inf is_connector from _ to Dep,
	    Inf has_type relation,
	    connects(Inf, Con, Dep)),
	(Ind = Con; membership_depends(Ind, Con)).

different(Box1, Box2) :-
   find_base(Box1, Base),
   \+ find_base(Box2, Base).

/* Table of what type of link can connect what types of object. Does not include
submodels, which are taken always to be connectable. Currently allows influences
to terminate on compartments; hopefully this will allow variables to be used as
parameters when initializing compartments. However compartments cannot influence
other compartments. */

can_connect(Arc, Node1, Node2) :-
	(get_style(sd), !,
	    ConnectTable =
	[[flow,
	  [[[compartment, cloud], [compartment, cloud]]]],
	 [squirt,
	  [[[compartment, cloud], [compartment, cloud]],
	   [[state, cloud], [state, cloud]]]],
	 [influence,
	  [[[compartment, state, variable, flow,
	     alarm, creation, immigration, reproduction, loss],
	    [variable, flow, compartment, state, event, squirt,
	     alarm, condition, creation, immigration, reproduction, loss]],
	   [[event, squirt],
	    [event, squirt, state, alarm, condition,
	     immigration, reproduction, loss]]]],
	 [relation, [[[submodel], [submodel]]]]];
	    
	ConnectTable =
	[[flow,
	  [[compartment,
	    [compartment, cloud]],
	   [cloud, [compartment, cloud]]]],
	 [influence,
	  [[compartment, [function]], 
	   [function,
	    [variable, flow, compartment,
	     alarm, condition, creation, immigration, reproduction, loss]], 
	   [variable, [function]],
	   [flow, [function]]]],
	 [relation, [[submodel, [submodel]]]]]),

	member([Arc, Poss], ConnectTable),
	member([Type1_options, Type2_options], Poss),
	member(Node1, Type1_options),
	member(Node2, Type2_options).

/* Decide if the new link makes no sense in terms of direction, if
either end is a link of the same type. If the start is a link, either
it exits a submodel containing the end or enters a submodel not
containing the end. If the finish is a link, it is a reversal if it
enters a submodel containing the start, or exits one not. */

u_turn(LType, Box1, Box2) :-
	Box1 has_type LType,
	    continues_in(Box1, Border),
	    (find_all_comps(Border, Box1),
		contains(Border, Box2, [_|_]); %last arg means not same
	    \+ find_all_comps(Border, Box1),
		\+ contains(Border, Box2, [_|_]));
	Box2 has_type LType,
	    continues_in(Box2, Border),
	    (find_all_comps(Border, Box2), !,
		\+ contains(Border, Box1, [_|_]);
		contains(Border, Box1, [_|_])).


/* This one is called when the system has to put a new node in itself, such as
when a submodel requires nodes for generation/deletion etc, or when a display mode
is selected which calls for things to be displayed which previously were not. It
takes X and Y coords and sticks the new doodad as close to them as there is room,
failing with a message if there is no space in the submodel. */

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   SAVING AND RESTORING THE INTERFACE BETWEEN A SUBMODEL AND ITS PARENT  %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

get_submodel_interface(Model, relation, Dir, Link,
			 link(StartCaption, EndCaption, LinkCaption)) :-
	get_connection(Model, relation, Dir, Link,
		       StartCaption, EndCaption, _, LastLink),
	caption_for(LastLink, LinkCaption).

/* Flows are tricky, because the flow of information is from the tap to the
compartments, which may or may not be in the actual direction of the flow. */

get_submodel_interface(Model, flow, Dir, Link,
		       link(StartCaption, EndCaption,
			    control(FlowUnits, ControlDir))) :-
	get_connection(Model, flow, Dir, Link, SourceCapt, DestCapt, Dest, _),
	(ControlDir = Dir,
	    Target = Dest,
	    StartCaption = FlowCaption,
	    EndCaption = DestCapt;
	select(Dir, [in, out], [ControlDir]),
	    initiates(Link, Target),
	    StartCaption = SourceCapt,
	    EndCaption = FlowCaption),
	find_type(Target, compartment),
	(ControlDir = Dir, 
	    sequence(Tap, Link);
	 \+ ControlDir = Dir,
	    sequence(Link, Tap);
	 ControlDir = in,
	    Tap = Link),
	bowtie_section(Tap, Tap),
	implicit_function(Tap, Valve),
	get_spec_units(Valve, FlowUnits),
	/* cannot use caption_for because we want this links name, not that
	of the top link */
	Tap has_attribute name of  FlowCaption.
	
get_submodel_interface(Model, influence, Dir, Link,
			 link(InputCaption, InputCaption, SourceUnits)) :-
	get_connection(Model, influence, Dir, Link,
		       _,_, Dest, LastLink),
	initiates(Link, Source),
	caption_for(Source, InputCaption),
	setof(ParamEntry, get_param_entry(LastLink, Dest, ParamEntry),
	      SourceUnits).

get_param_entry(LastLink, Dest,
		entry(RemoteUnit, RelationCapt, SourceLocation)) :-
	get_link_source_data(LastLink, Dest, _, RemoteUnit,
			     Relation, _, SourceLocation),
	(var(Relation), RelationCapt = none;
	nonvar(Relation),
	    caption_for(Relation, RelationCapt)).

get_connection(Model, Type, Dir, Link, SourceCapt, DestCapt,
	       Dest, LastLink) :-
	Model has_link_equivalences LinkPairs,
	setof(Outer, member(Inner-Outer, LinkPairs), Outers),
	(Dir = in,
	    Link = Inner,
	    Link is_connector from _ to Model;
	Dir = out,
	    member_eg(Link, Outers),
	    Link is_connector from Model to _),
	Link has_type Type,
	connects_eg(Link, Source, Dest),
	caption_for(Source, SourceCapt),
	caption_for(Dest, DestCapt),
	LastLink is_connector from _ to Dest,
	(Link = LastLink; sequence(Link, LastLink)).

/* We only want one entry per link, so if it branches after crossing
this border and hence connects a source with multiple destinations, we
don't want to know. However we cannot put a cut in get_connection
because we want that to succeed once for each link. */

member_eg(Link, Links) :-
	member(Link, Links), !.
connects_eg(Link, A, B) :-
	connects(Link, A, B), !.

load_submodel_interface(Stream, Model, Type, Dir) :-
	read(Stream, Line),
	(Line = end_of_file,
	    close(Stream);
	Line = section(NewType, NewDir),
	    load_submodel_interface(Stream, Model, NewType, NewDir);
	Line = link(SourceCapt, DestCapt, Properties),
	    (NewDestCapt = DestCapt,
		Method = 'Found';
	    make_connection(Model, Type, Dir, ExternalSection,
			    SourceCapt, DestCapt, Properties, Hassle),
		/* dest capt need not be the same, because parameter name
		ignored on reload, and input node has now gone! */
		Method = 'Made'),
	    
	    (nonvar(Hassle), !;
	    get_submodel_interface(Model, Type, Dir, ExternalSection,
			    link(SourceCapt, NewDestCapt, NewData)), !,
	        (NewData = Properties, !;
		 Hassle = interface_mismatch(Method, Type, SourceCapt,
					     DestCapt, NewData, Properties))),
	    (var(Hassle), !;
		query(Hassle, warning, top, [abort], more)),
	    load_submodel_interface(Stream, Model, Type, Dir)).

make_connection(Model, Type, Dir, ExternalSection,
		SourceCapt, DestCapt, Properties, Hassle) :-
	Parent has_part Model,
	((Dir = in,
	    find_all_comps(Parent, InputSection),
	    ExternalSection = InputSection;  
	  Dir = out,
	    find_all_comps(Model, InputSection),
	    ExternalSection = OutputSection),
	check_input(Type, Dir, Model, SourceCapt, Properties,
		     InputSection), !,
	    /* We want to tie all possible continuation sections */
	    (setof(OutputSection, 
		  ((Dir = out,
		     find_all_comps(Parent, OutputSection);
		  Dir = in,
		    find_all_comps(Model, OutputSection)),
		      check_output(Type, Dir, Model, DestCapt, Properties,
				   OutputSection)), Outputs),
	      all(m_update, link_ends,
		[unify(Type), unify(InputSection),
		 build(Outputs), build(_TopArcs)]),
	    menu'><'reroute_sections([InputSection | Outputs]),
		menu'><'remove_old_incomplete;
	    Hassle = spare_interface_spec(Type, Dir, destination, DestCapt));
	Hassle = spare_interface_spec(Type, Dir, source, SourceCapt)).

check_input(Type, Dir, Model, SourceCapt, Properties, BorderSection) :-
	BorderSection has_type Type,
	BorderSection is_connector from _ to Dest,
	(Type = flow,
	Properties = control(_, ControlDir),
	ControlDir = Dir, !,
	    caption_for(BorderSection, SourceCapt);
	initiates(BorderSection, Source),
	    caption_for(Source, SourceCapt)),
	(Type = flow,
	    Dest is_of_sort cloud,
	    appears(Dest); % submodel cut out if outward
	Dir = in,
	    Dest = Model,
	    (Type = flow; Type = influence;
		Type = relation,
		caption_for(BorderSection, Properties));
	Dir = out,
	    Dest has_class border).
	
check_output(Type, Dir, Model, SourceCapt, Properties, BorderSection) :-
	BorderSection has_type Type,
	BorderSection is_connector from Dest to _,
	(Type = flow,
	Properties = control(_, ControlDir),
	\+ ControlDir = Dir, !,
	    caption_for(BorderSection, SourceCapt);
	Type = influence, !,
	    caption_for(Dest, SourceCapt);
	terminates(BorderSection, Source),
	    caption_for(Source, SourceCapt)),
	(Type = flow,
	    Dest is_of_sort cloud,
	    appears(Dest); % submodel cut out if inward
	  Type = influence,
	    (Dest has_class variable,
		is_parameter(Dest, 1);
% should be handled as 'Found' case
%		AlreadyDone is_connector from Dest to _,
%		sequence(InputSection, AlreadyDone);
	      true);
	  Type = relation,
	    Dir = out,
	    Dest = Model, !,
	    caption_for(BorderSection, Properties);
	  Dir = in,
	    Dest has_class border).	

add_new_line_between(Type, Start, Finish, TopLink) :-
	contains(Top, Start, Out),
	contains(Top, Finish, In),
	append(Up, [StartBox], Out), !,
	(append(Down, [FinishBox], In);
	    In = [], Down = [], make_border_node(Type, Top, FinishBox)),
	(StartBox has_type Type, !,
	    TopLink = StartBox,
	    TopLink has_changed_termination finish from Old to FinishBox,
	    remove_floater(Old),
	    link_forwards(FinishBox, StartBox, Type, Down);
	 FinishBox has_type Type, !,
	    TopLink = FinishBox,
	    TopLink has_changed_termination start from Old to StartBox,
	    remove_floater(Old),
	    link_backwards(StartBox, FinishBox, Type, Up);
	 new_line(Type, [], StartBox, FinishBox, TopLink),
	    link_forwards(FinishBox, TopLink, Type, Down), 
	    link_backwards(StartBox, TopLink, Type, Up)).

link_backwards(Top, TopLink, Type, Chain) :-
	append(More, [Next], Chain), !,
	(Next has_type Type, !,
	    OnLink = Next,
	    OnLink is_connector from _ to Old,
	    (find_type(Old, border), !,
		Bdr = Old;
	    make_border_node(Type, Top, Bdr),
		OnLink has_changed_termination finish from Old to Bdr,
		remove_floater(Old));
	 make_border_node(Type, Top, Bdr),
	    new_line(Type, [], Next, Bdr, OnLink),
	    link_backwards(Next, OnLink, Type, More)),
	 add_equivalence(Top, OnLink, TopLink);
	 true.
	     
link_forwards(Top, TopLink, Type, Chain) :-
	append(More, [Next], Chain), !,
	 (OldLink follows TopLink, !,
	     OldLink is_connector from Bdr to _;
	 make_border_node(Type, Top, Bdr)),
	(Next has_type Type, !,
	    OnLink = Next,
	    OnLink has_changed_termination start from Old to Bdr,
	    remove_floater(Old);
	 new_line(Type, [], Bdr, Next, OnLink),
	    link_forwards(Next, OnLink, Type, More)),
	 add_equivalence(Top, TopLink, OnLink);
	 true.

link_ends(New_obj, Start_thing, Terminator, Last_new_arc) :-
%	remove_border_nodes(New_obj, Terminator, Start_thing);
	add_new_line_between(New_obj, Start_thing, Terminator, Top_arc),
	get_action_point(Top_arc, Terminator, Last_new_arc),
%%% If flows, check whether bowties still exist and reroute/delete influences
        (New_obj = flow,
	    bowtie_section(Top_arc, BowtieArc),
	    caption_for(BowtieArc, BowtieCapt),
	    (sequence(SimpleArc, BowtieArc); sequence(BowtieArc, SimpleArc)),
	    SimpleArc has_changed_attribute name to BowtieCapt,
	    implicit_function(SimpleArc, OldFn),
	    NoUse is_connector from _ to OldFn,
	    event'><'delete_by_dlg(NoUse),
	    fail;
	  New_obj = relation, % make sure arrow for lookup still lowest index
	    Refs = [local(Top_arc)],
	    initiates(Top_arc, Base),
	    (Base has_model_refinement references of BRefList,
		append(BRefList, Refs, BNewList),
		Base has_changed_model_refinement references of BNewList;
	      Base has_new_model_refinement references of Refs),
	    terminates(Top_arc, Assoc),
	    (Assoc has_model_refinement references of RefList,
		append(RefList, Refs, NewList),
		Assoc has_changed_model_refinement references of NewList;
	      Assoc has_new_model_refinement references of Refs),
	    OldObj is_connector from _ to Assoc,
	    find_type(OldObj, relation),
	    find_name_host(OldObj, OldHost),
	    OldHost has_attribute can_lookup of 1,
	    make_role_first(OldHost);
	event'><'spread_colour(Last_new_arc, dims)).

load_references(Submodel, ReferenceCapts) :-
	pair_with_captions(Submodel, References, ReferenceCapts),
	(Submodel has_changed_model_refinement references of References;
	Submodel has_new_model_refinement references of References).

save_references(Stream, Model) :-
	(Model has_model_refinement references of RefList, !,
	    pair_with_captions(Model, RefList, PairList),
	    write_with_breaks(Stream, references(PairList));
	write_with_breaks(Stream, no_references)).

pair_with_captions(_, [], []).

pair_with_captions(Model, [Do | Later], [Done | DoneLater]) :-
	(match_caption(Model, Do, Done), !;
	/* If this fails, it might be that a reference is disused...*/
	Done = '/disused/', (nonvar(Do) ; Do = obsolete), !;
	/* Or we might be loading a model into a context that does not have
	the right association links */
	query(missing_relation(Done), warning, top, [abort], more)),
	pair_with_captions(Model, Later, DoneLater).
	
match_caption(Model, Do, Done) :-
	Do = local(Relation),
	(initiates(Relation, Model); terminates(Relation, Model)),
	caption_for(Relation, Done);
	Do = ancestor(Index),
	Parent has_part Model,
	Parent has_model_refinement references of ParentList,
	nth0(Index, ParentList, NextLevel),
	match_caption(Parent, NextLevel, Done).

add_equivalence(Parent, Start, Finish) :-
	(Parent has_link_equivalences Pair_list, !,
		Parent has_changed_link_equivalences
			[Start-Finish | Pair_list];
	Parent has_new_link_equivalences [Start-Finish]).

list_cross_border_specs(Parent, Link_specs) :-
	Parent has_link_equivalences Link_list,
	setof(Link_spec, spec_from(Parent, Link_list, Link_spec), Link_specs), !;
	Link_specs = [].

spec_from(Parent, Link_list,
		Type-Link1-Source_desc-Going_in-Link2-Destination_desc) :-
	member(Link1-Link2, Link_list),
	(Link1 is_connector from _ to Parent,
		InArc=Link2, OutArc = Link1, Going_in=1;
	Link2 is_connector from Parent to _,
		InArc=Link1, OutArc = Link2, Going_in=0),
	
	InArc has_type Type,
	Link1 is_connector from Source to _,
	describe(Source, Parent, InArc, Source_desc),
	Link2 is_connector from _ to Destination,
	describe(Destination, Parent, OutArc, Destination_desc).

describe(Node, Near_end, Arc, Where) :-
	(find_type(Node, submodel), !,
		Preamble = "inside submodel",
		caption_for(Node, Id);
	find_all_comps(Parent, Node),
	\+ Parent = Near_end,
	Parent has_link_equivalences Pair_list,
	(member(Arc-_, Pair_list); member(_-Arc, Pair_list)), !,
		Preamble = "outside submodel",
		caption_for(Parent, Id);
	Node has_class Class,
		name(Class, Preamble),
		caption_for(Node, Id)),
	name(Id, Postamble),
	append(Preamble, [32 | Postamble], Where).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   PROPAGATING THE EFFECTS OF DELETING COMPONENTS                        %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/* Nodes whose completion status may be affected by the addition or deletion
of the given arc. Note that the effect of the presence of a base node on its ghosts
is handled separately by change_ghosthood from within the ghosting and deletion
procedures.

Comments reflect fact that, now arcs can no longer start on submodel
boundaries, and deleting a non-final arc creates a new input node,
only destination nodes are affected by arc deletion. And none at all
if they are flows. */

presence_affects(Item, AffectedBase) :-
	(status_affects(Item, Affected);
	find_type(Item, influence),
	    Item is_connector from _ to Fn,
	    implicit_function(Affected, Fn);
	find_type(Item, submodel),
	    Emerge is_connector from Item to _,
	    find_type(Emerge, influence),
	    terminates(Emerge, Fn),
	    (implicit_function(Affected, Fn);
	    is_ghost(Fn),
		Further is_connector from Fn to _,
		find_type(Further, influence),
		terminates(Further, FarFn),
		implicit_function(Affected, FarFn),
		\+ contains(Item, Affected));
	find_type(Item, relation),
	    Item is_connector from _ to Affected,
	    terminates(Item, Affected);
	find_type(Item, condition),
	    Affected has_part Item),
	find_base(Affected, AffectedBase);
	ghost_link(Item, Base, Ghost),
	    member(AffectedBase, [Base, Ghost]).

delete_obsolete_modes([], _, []).

delete_obsolete_modes([use(N, Dir, Local, Units) | R1], DeadRef, NewList) :-
	delete_obsolete_modes(R1, DeadRef, R2),
	(((N = none; N < DeadRef), !,
	  NewN = N;
	 N > DeadRef, !,
	  NewN is N-1),
	 NewList = [use(N, Dir, Local, Units) | R2];
	NewList = R2).

/* Nodes whose completion status may be affected by a change in status
of the given item -- ghost should be converted to base before calling */

status_affects(Item, Affected) :-
%	find_base(Tgt, Item),
	(Base = Item;
	    find_ghosts(Item, Base)),
	(Affected = Base;
	  (InfSource = Base;
	      Base is_of_sort line, implicit_function(Base, InfSource)),
	    initiates(Affected, InfSource),
	    find_type(Affected, influence)),
	  \+ Affected = Item;
	find_type(Item, relation), /* for parameter name updates */
	    connects(Item, Base, Assoc),
	    (Start=Base, Finish=Assoc; Start=Assoc, Finish=Base),
	    Link1 is_connector from Start to _,
	    (Link1 = Link2; sequence(Link1, Link2)),
	    Link2 is_connector from _ to Finish,
	    connects(Link2, _, Target),
	    sequence(Link2, Affected),
	    Affected is_connector from _ to Target;
	find_type(Item, submodel),
	    caption_for(Item, Capt),
	    contains(Top, Item),
	    backup'><'is_toplevel(Top),
	    contains(Top, Affected),
	    find_type(Affected, submodel),
	    Affected has_class_refinement multiplication_spec of Multi,
	    member(_Count=DimList, Multi),
	    member(Ref, DimList),
	    (Ref = size(Capt); Ref = size(Capt, _Nth)).

/* OK, now here's the easy, teenage, New York version...

status_affects(Item, Affected) :-
	(implicit_function(Next, Item);
	initiates(Next, Item),
	find_type(Next, influence)),
	(Affected = Next;
	status_affects(Next, Affected)).
*/
	
/* Do not start on links already continued or uncontinuable */
start_full(Type, Link) :-
	old_cloud(Link);
	% connects_ghost_flow(Type, Link);
	find_type(Link, Type),
	\+ (continues_in(Link, Node),
		\+ (Node has_link_equivalences Equiv_list,
		member(Link-_, Equiv_list),
		\+ Type = influence) /*
	   allow drags from cloud-terminated flows -- buggy, very buggy ;   
	    Link is_connector from _ to Floater,
	       appears(Floater),
	       Floater is_of_sort cloud */ ).

finish_full(Type, Link) :-
	old_cloud(Link);
	connects_ghost_flow(Type, Link);
	find_type(Link, Type),
	\+ (initiates(Link, Node),
	       (is_parameter(Node, P), P>0;
		   Node is_of_sort cloud);
	    continues_from(Link, Node),
		\+ (Node has_link_equivalences Equiv_list,
		member(_-Link, Equiv_list))).

old_cloud(Link) :-
	find_type(Link, cloud),
	(_F0 is_connector from Link to _;
	    _F1 is_connector from _ to Link).

connects_ghost_flow(Type, Link) :-
	Type = influence,
	Link is_of_sort transfer,
	\+ bowtie_section(Link, Link).

remove_equivs(DeadPair) :-
	link'><'remove_connection(DeadPair),
	fail.

is_top_arc(TopArc) :-
	TopArc is_connector from Side1 to Side2,
	appears(Side1), (appears(Side2); find_type(Side2, function)).

/* do_delete fafs around making sure all connectors to an object are nicely
terminated and so forth when it is deleted. For bulk deletions these are
probably all doomed anyway, so just call fast_delete instead. As a slight
concession to usability, fast_delete removes its equivalence entry from its
start point, allowing it to be used for end-to-end deletes. */

fast_delete(Dead) :-
	delete_implicit_node(Dead),
	shows_model(Win,Dead),
	    draw'><'delete_window(Win),
	    fail;
	oblitterfry(Dead);
	Dead is_connector from In to Out,
	    (remove_equivs(_-Dead);
	    Dead is_no_longer_connector,
		remove_floater(In),
		remove_floater(Out)).

superfast_delete(Dead) :-
	(Dead has_part AlsoDead;
	    member(Dead, [E1, E2]),
	    Link is_connector from E1 to E2,
	    Link has_part AlsoDead),
	  superfast_delete(AlsoDead),
	  oblitterfry(AlsoDead),
	  shows_model(Win, AlsoDead),
	  draw'><'delete_window(Win),
	  fail;
	forget_highlit_obj(_, Dead).

do_delete(Kill_obj) :-
	delete_implicit_node(Kill_obj),
	unghost(Kill_obj),
	sever_links(Kill_obj, _),
	fast_delete(Kill_obj).

sever_links(Kill_obj, End) :-
	initiates(Kill_obj, Start),
	(continues_in(Kill_obj, End), NewEnd = start;
	    continues_from(Kill_obj, End), NewEnd = finish),
	caption_for(Start, NewCapt),
	% min_def_and_max_for(Start, SMinVal, SDefVal, SMaxVal),
	get_link_source_data(Kill_obj, End, _, SUnit, none, _,_),
	(make_new_end_node(End, Kill_obj, NewEnd,
			   NewCapt, SUnit);
	    remove_equivs(Kill_obj-_));
/*	continues_from(Kill_obj, End),
	    caption_for(Start, NewCapt),
	    min_def_and_max_for(Start, FMinVal, FDefVal, FMaxVal),
	    (make_new_end_node(End, Kill_obj, finish,
			       NewCapt, _, FMinVal, FDefVal, FMaxVal);
	    remove_equivs(_-Kill_obj)));
*/	true.
/*	    
min_def_and_max_for(VisNode, MinVal, DefVal, MaxVal) :-
	find_node_with_data(VisNode, _, Node),
	(get_av_pair(Node, 0, min_val, MinVal),
	    number(MinVal), !; true),
	(get_av_pair(Node, 0, value, DefVal),
	    number(DefVal), !; true),
	(get_av_pair(Node, 0, max_val, MaxVal),
	    number(MaxVal), !; true).
*/

make_new_end_node(Submodel, DeadLink, Dir, NewInputName, NewUnit) :-
	find_type(DeadLink, LinkType),
	member(go(LinkType, Dir, NodeType),
	       [go(influence, start, variable),
		go(flow, start, cloud),
		go(flow, finish, cloud)]),
	Submodel has_link_equivalences Equivs,
	(Dir = start,
	    OuterFirst = Equivs,
	    NodePosn = CourseStart,
	    OldEnd = NextStart,
	    [X,Y] = StartPair;
	Dir = finish,
	    swap_pairs(Equivs, OuterFirst),
	    NodePosn = CourseEnd,
	    OldEnd = NextFinish,
	    [X,Y] = EndPair),
	setof(NextBit, member(DeadLink-NextBit, OuterFirst), Others),
	Others = [TestBit | _],
	TestBit is_connector from NextStart to NextFinish,
	image'><'get_link_route(TestBit, Course),
	append([EndPair | _], [StartPair], Course),
	find_all_comps(Model, OldEnd),
	(find_type(OldEnd, submodel),
	    make_node(Model, NodeType, NewEnd);
	image'><'clear_shape(OldEnd, along),
	    change_class(OldEnd, border, NodeType),
	    NewEnd = OldEnd),
	/* make sure its name is unique to the submodel -- currently not done,
	if I put it in make sure I don't rename things just because of their
	own ghosts 
	setof(OldName, Member^(find_all_comps(Submodel, Member),
			       caption_for(Member, OldName)), OldNames),
	ensure_unused(NewInputName, UniqueInputName, OldNames), */
	add_parameter(NewEnd, 0, name, NewInputName),
	(var(NewUnit), !;
	    add_parameter(NewEnd, 0, units, NewUnit)),
/* Not sure why we transferred val, min and max to floater -- last two
cause it to persist in v5.x and first does same in v6.0
	(var(NewMinVal), !;
	    add_parameter(NewEnd, 0, min_val, NewMinVal)),
	(var(NewDefVal), !;
	    add_parameter(NewEnd, 0, value, NewDefVal)),
	(var(NewMaxVal), !;
	    add_parameter(NewEnd, 0, max_val, NewMaxVal)), */
	event'><'insert_variable(Model, X, Y, NodeType, NewEnd),

	/* Next bit is continually retried to delete all spare nodes */
	member(MoveBit, Others),
	MoveBit is_connector from CourseStart to CourseEnd,
	MoveBit has_changed_termination Dir from NodePosn to NewEnd,
	event'><'move_link(MoveBit),
	    /* Now delete old terminator if it is redundant */
	remove_floater(NodePosn),
	fail.

swap_pairs([], []).

swap_pairs([M1-M2 | R1], [M2-M1 | R2]) :-
	swap_pairs(R1, R2).

remove_floater(Node) :-
	(_ is_connector from Node to _;
	  _ is_connector from _ to Node;
	  implicit_function(_Arc, Node);
	    Node has_class C,
	    \+ member(C, [variable, cloud, border, function]);
	  Node has_class_refinement min_val of _;
	  is_parameter(Node, 2)), !;
	draw'><'off(Node),
	oblitterfry(Node).

make_border_node(Line_type, Parent, Node_name) :-
        member(Line_type-Node_type, [flow-border, squirt-border,
                                     influence-border, relation-border]),
        make_node(Parent, Node_type, Node_name).

remove_border_nodes(LineType, Finish, Start) :-
	member([Other, Local, Far, InputNode],
	       [[finish, Start, Finish, OldEnd],
		[start, Finish, Start, OldStart]]),
	find_type(Local, LineType),
	Local is_connector from OldStart to OldEnd,
	\+ border_node(InputNode),
	stick_on_edge(Local, Far, Other, LineType, InputNode),
	\+ _somethingElse is_connector from InputNode to _,
	\+ _somethingElse is_connector from _ to InputNode,
	draw'><'off(InputNode),
	fast_delete(InputNode),
	fail.

stick_on_edge(Local, Far, Other, LineType, InputNode) :-
	Box has_part InputNode,
	(contains(Box, Far, Hier), !,
	    suffix([SubBox], Hier),
	    Local has_changed_termination Other from InputNode to SubBox;
	make_border_node(LineType, Box, BorderNode),
	    Local has_changed_termination Other from InputNode to BorderNode).

add_outward_line(Line_type, Parent, Start, Arc_name) :-
	make_border_node(Line_type, Parent, Node_name),
	new_line(Line_type, [], Start, Node_name, Arc_name).

add_inward_line(Line_type, Parent, Finish, Arc_name) :- 
	make_border_node(Line_type, Parent, Node_name),
	new_line(Line_type, [], Node_name, Finish, Arc_name).

chain_hierarchy(Line_type, Dir, Link_in, To_go, Node_out, Link_out) :-
	To_go = [First, Second | Rest], !,
		(Dir = out, add_outward_line(Line_type, Second, First, Inter_link);
		Dir = in, add_inward_line(Line_type, Second, First, Inter_link)),
		(var(Link_in), !;
		(Dir = out, add_equivalence(First, Link_in, Inter_link);
		Dir = in, add_equivalence(First, Inter_link, Link_in))),
		chain_hierarchy(Line_type, Dir, Inter_link, [Second | Rest], Node_out, Link_out);
	Link_out = Link_in,
		(To_go = [Node_out], !;
		true).

oldd_new_line_between(Line_type, Start, Finish, Top_link) :-
	(Start has_type Line_type, !, 
		continues_in(Start, Start_node),
		Chain_start = Start;
	Start_node = Start),
	(Finish has_type Line_type, !, 
		continues_from(Finish, Finish_node),
		Chain_finish = Finish;
	Finish_node = Finish),

	get_chain(Start_node, Finish_node, Top_node, Out, In),
		
	chain_hierarchy(Line_type, out, Chain_start, Out, End, Forward_link),
	chain_hierarchy(Line_type, in, Chain_finish, In, End2, Backward_link),
	((nonvar(End), nonvar(End2), !,
	        new_line(Line_type, [], End, End2, Top_link),
	        (Line_type = influence, !,
		    add_parameter(Top_node, 1, c_new, 0);
		true);
	nonvar(End), !,
		add_outward_line(Line_type, Top_node, End, Top_link);
	nonvar(End2), !,
		add_inward_line(Line_type, Top_node, End2, Top_link)), !,
		(var(Forward_link), !;
			continues_in(Forward_link, Boundary),
			add_equivalence(Boundary, Forward_link, Top_link)),
		(var(Backward_link), !;
			continues_from(Backward_link, Boundary2),
			add_equivalence(Boundary2, Top_link, Backward_link));
	nonvar(Forward_link), nonvar(Backward_link), !,
		add_equivalence(Top_node, Forward_link, Backward_link),
		(Forward_link is_connector from _ to Top_node, !,
			Top_link = Forward_link;
		Top_link = Backward_link);
	Top_link = Forward_link,
		Top_link = Backward_link).

unique_name_for_new(Parent, Type, Name) :-
	(get_abbrev(Type, Abbrev), !; Type = Abbrev),
	unique_name(Abbrev, Name, _),
	\+ (Type is_class_of_sort line,
	       Part has_attribute name of Name,
	       Part draws_inside Parent;
	   Type is_class_of_sort box,
	       Part has_class_refinement name of Name,
	       Parent has_part Part), !.

get_disag_params(Submodel, [Colour, Image, ImgPos, Nature, Fat, Count, Step,
			    Desc, Comment, EnumSpecs, Proc, Inc, Libs,
			    Fix, Hide, Separate]) :-
	(Submodel has_class_refinement fill_colour of Colour,
	    \+ Colour = clear, !;
	    Colour = white),
	(Submodel has_class_refinement fill_image of Image, !;
	    Image = none),
	(Submodel has_class_refinement image_posn of ImgPos, !;
	    ImgPos = none),
	(Submodel has_class_refinement multiplication_spec of Multi,
	    member(count=QCount, Multi), !,
	    all(m_update, dequote_atom, [build(QCount), build(Count)]);
	Count=[]),
	(Submodel has_class_refinement multiplication_spec of Multi,
	    member(type=Nature, Multi), \+ Nature = derived, !;
	Nature = generated),
	time_step_for(Submodel, 'Default', Step),
	(Submodel has_class_refinement description of Desc, !;
	Desc = ''),
	(Submodel has_class_refinement comment of Comment, !;
	Comment = ''),
	enum_types_for(Submodel, EnumSpecs),
	(Submodel has_class_refinement eqn_units of Fix, !;
	Fix = 'Default'),
	(Submodel has_graphical_attribute hide_contents of Hide, !;
	Hide = 0),
	(Submodel has_class_refinement separate of Separate, !;
	Separate = 0),
	(Submodel has_class_refinement external_code of ExternCode, !,
	    member(procedure=Proc, ExternCode),
	    member(include=Inc, ExternCode),
	    member(libraries=Libs, ExternCode);
	Proc = none, Inc = none, Libs = []),
	fatness_for(Submodel, Fat).

fatness_for(Submodel, Fat) :-
	Submodel has_graphical_attribute bounding_box of [LB, _, RB, _],
	Submodel has_graphical_attribute internal_extent of [LI, _, RI, _],
	Fat is 1.0*(RB-LB)/(RI-LI).

dequote_atom(QCount, Count) :-
	ame_gen'><'dequote(QCount, Count), !;
	Count = QCount.

time_step_for(Model, TopStep, Step) :-
	Model has_class_refinement step of Step, !;
	Step = TopStep.

enum_types_for(Submodel, EnumSpecs) :-
	(Submodel has_class_refinement enum_types of EnumTypes,
	    all(menu, separate_type_from_mems,
		[build(EnumSpecs), build(EnumTypes)]), !;
	 EnumSpecs = []).

get_all_enum_types(root, []).
get_all_enum_types(Node, TypeList) :-
	enum_types_for(Node, LevelList),
	Parent has_part Node,
	get_all_enum_types(Parent, HigherList),
	append(LevelList, HigherList, TypeList).
	
use_units_in(root, 'No').
use_units_in(Model, Do) :-
	Model has_class_refinement eqn_units of Local, !,
	    Do = Local;	  
	find_all_comps(Parent, Model),
	    use_units_in(Parent, Do).

/* make_ghost establishes a ghost relationship -- Ghost becomes a ghost of Base.
Ghost ceases to be a ghost of anything it was previously a ghost of. */

make_ghost(Ghost, Base, LastLink) :-
	unmake_ghost(Ghost);
	Base = '', !;
	add_new_line_between(influence, Base, Ghost, TopLink),
	get_action_point(TopLink, Ghost, LastLink).

unmake_ghost(Ghost) :-
	find_base(Ghost, Base),
	\+ Base = Ghost,
	remove_connection(Base, Ghost),
	event'><'spread_colour(Base, none),
	fail.

remove_connection(Base, Ghost) :-
	setof(GhostLink, exists_for(GhostLink, Base, Ghost), Links),
	member(Link, Links),
	(remove_equivs(Link-_);
	draw'><'off(Link),
	    fast_delete(Link),
	    fail);
	true.

exists_for(Link, Base, Ghost) :-
	connects(Link, Base, Ghost),
	\+ (connects(Link, Base, OtherGhost),
	       \+ OtherGhost = Ghost).

unghost(Ghost) :-
	unmake_ghost(Ghost);
	true.

/* continues_in and continues_from return the id of the submodel on
whose boundary a link starts or finishes. This will work even if there is no actual continuation of the link. */

continues_in(Link, Node) :-
	Link is_connector from _ to End,
	(\+ appears(End), \+ find_type(End, function), !, 
           Node has_part End;
	find_type(End, submodel), Node = End).

continues_from(Link, Node) :-
	Link is_connector from End to _,
	(\+ appears(End), !, Node has_part End;
	find_type(End, submodel), Node = End).

get_possible_start(Base, Start) :-
	(initiates(Start, Base);
	sequence(Base, Start)),
	Start has_type influence.

next_section_of(Source, Dest) :-
/* works efficiently when source is defined */
	(Source is_connector from _ to Box; Source draws_inside Box),
	Box has_link_equivalences Pairs,
	member(Source-Dest, Pairs).

/* Following rules trace value-dependence in opposite
directions, returning a list of intermediate primitives in
source-dest order. Note the latter does not include invisible
objects. */

get_action_point(Top, End, Point) :-
        (Top is_connector from _ to End;
                continues_in(Top, End);
                next_section_of(Top, End);
                Top = End), !,
            Point = Top;
        next_section_of(Top, Next),
            get_action_point(Next, End, Point).

% load a model fragment from a file without a graphical window
make_blind_level(Root, File, Parent) :-
	make_node(Root, fragment, Parent), % generates fragment-type name
	change_class(Parent, _, submodel),
	use_temp_dir(LocalDir),
	Parent has_class_refinement name of Name,
	append_atoms([LocalDir, '/', Name], TargetDir),
        forms'><'start_progress_dialogue('.'),
        forms'><'reassure_user(decode_mime, []),
	output'><'load_file(Parent, TargetDir, File, CheckedStr),
	substitute(0, CheckedStr, 95, SafeCheckedStr),
	name(Checked, SafeCheckedStr),
	(member(Checked, [no, yes]) ->
	    append_atoms(TargetDir, '/model.pl', PrologData),
	    AllowBig = Checked;
	  PrologData = File,
	    AllowBig = yes), % prolog decls only saved by enterprise edn
	library'><'ame_merge(Parent, PrologData, _FileV, AllowBig, _Tr),
	forms'><'finish_progress_dialogue.
/* Procedure to draw first model window */

make_desktop(Desktop, Canvas_name) :-
	output'><'tk_make_desktop(Desktop, Canvas_name).
/* ...which calls the class constructor, which calls... */
make_desktop_node(Desktop, Canvas_name) :-
        m_class'><'Root is_root,
	make_node(Root, desktop, Desktop), % generates desktop-type name
	change_class(Desktop, _, submodel),
	Desktop has_class_refinement name of ModelName,
	state'><'set_initial_box_sizes(Desktop),
        get_initial_window_size(X, Y),
        image'><'set_shape(Desktop, internal_extent, [0, 0, X, Y]),
        image'><'set_shape(Desktop, bounding_box, [0, 0, X, Y]),
	output'><'safe_tcl_eval(['CanvasDefBG'], BGColStr),
	name(BGCol, BGColStr),
	Desktop has_new_class_refinement fill_colour of BGCol,
	backup'><'new_autosave(Desktop, ModelName),
	InitDepths=[0,32,32,32,32,32,32,32,showAll],
        event'><'new_window_for(Desktop, Desktop, Canvas_name, InitDepths, 1),
        all(state, set_display_depth, [unify(Canvas_name),
            build([ghost_link, influence, variable, flow, compartment,
                   submodel, caption, text, sections]), build(InitDepths)]),
        draw'><'redraw_window(Canvas_name).
