/*******************************************************************************
**** Manipulation module - contains all the high level stuff to do with     ****
**** manipulating models 						    ****
*******************************************************************************/

sicstus_module(submodel, [encapsulate/2, unencapsulate/3, find_flow_control/2,
			  extended_connection/3, extended_connection/4,
			  extended_connections/3, extended_connections/4] ).

sicstus_use_module( [ame_gen,m_class,utility,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% encapsulate/3 takes a list of nodes and arcs and makes them into a sub-model
% the node name of the new submodel is returned in the second argument
% All the nodes being encapsulated are required to be on the same level in the
% tree - ie with the same parent. If the arcs listed are flows, then it is
% assumed that the flow valve is inside the component

encapsulate( ListOfThings, NewNode ) :-
	ListOfThings = [], !;
	all_same_parent( ListOfThings, _,_,_,_ ),
	move_components(ListOfThings, NewNode).

/* Puts Migrants in new submodel. The list of migrants contains all boxes included
in the boundary, and all flows whose bowties are included. This routine does what
is necessary to break cross-border flows into separate externam and internal parts,
but ignores links other than flows or influences. */

move_components(Migrants, California) :-
	member(Flow, Migrants),
		((Flow is_part_of OldParent,
			Flow is_no_longer_part_of OldParent,
			Flow is_also_part_of California,
			fail);
		Flow is_connector from Source to Dest,
		(\+ member(Source, Migrants),
			add_section(California, cloud, source, in, Flow, 
					Dest, Source),
			fail;
		\+ member(Dest, Migrants),
			add_section(California, cloud, sink, in, Flow, 
					Source, Dest),
			fail);
		((Arc is_connector from Flow to End,
			Fix = sink;
		Arc is_connector from End to Flow,
			Fix = source),
		\+ member(End, Migrants),
		\+ member(Arc, Migrants),
			(Arc has_type influence,
			    \+ make_branch(Arc, California),
			    NewNodeType = variable;
			Arc is_of_sort has_bowtie,
			    NewNodeType = cloud;
			Arc has_type relation,
			    NewNodeType = submodel),
			add_section(California, NewNodeType, Fix, out,
						Arc, Flow, End),
			fail));
	true.

make_branch(Arc, California) :-
	initiates(Arc, DeepSource),
	initiates(CompleteArc, DeepSource),
	m_update:continues_from(CompleteArc, California),
	CompleteArc has_type influence,
	California has_model_refinement link_equivalences of Equivs,
	member(InnerArc-CompleteArc, Equivs),
	CompleteArc is_connector from Junction to _,
	(m_update:continues_from(Arc, OldBorder), !,
	    OldBorder has_model_refinement link_equivalences of OBEquivs,
	    select(_-Arc, OBEquivs, OBRest),
	    OldBorder has_changed_model_refinement link_equivalences of OBRest;
	true),
	Arc has_changed_termination start from _OldStart to Junction,
	California has_changed_model_refinement link_equivalences of
	        [InnerArc-Arc | Equivs].

/* If a flow has multiple sections the bowtie is drawn on the one
whose implicit function has a value, except if none have in which case
it goes on the section at the source end. If dividing a flow with no
values we need to add one to the section that currently has the bowtie
in case that bowtie is not on the new source section (typical ghastly
hack) */

add_null_value_if_needed(Arc) :-
	get_bowtie_section(Arc, Base),
	implicit_function(Base, BaseFn),
	(BaseFn has_class_refinement value of _Val, !;
	    BaseFn has_new_class_refinement value of '').
	
add_section(California, NewClass, Direction, Keep, Flow, NearEnd, FarEnd) :-
	add_null_value_if_needed(Flow),
	NewNode is_new_part_of California,
	NewNode has_new_class NewClass,
	((Direction = sink, Keep = out; Direction = source, Keep = in) ->
		EndToChange = start;
		EndToChange = finish),
	(Keep = in ->
		OldEnd = FarEnd,
		ChangedEnd = NewNode,
		NewEnd = California;
		OldEnd = NearEnd,
		NewEnd = NewNode,
		ChangedEnd = California),
	Flow has_changed_termination EndToChange from OldEnd to ChangedEnd,

	(EndToChange = finish ->
		NewFlow is_new_connector from NewEnd to OldEnd,
			substitute_finish_equivalences(Flow, NewFlow),
			add_link_equivalence(California, Flow-NewFlow);
		NewFlow is_new_connector from OldEnd to NewEnd,
			substitute_start_equivalences(Flow, NewFlow),
			add_link_equivalence(California, NewFlow-Flow)),
	copy_local_attributes(Flow, NewFlow),
	change_references(OldEnd, Flow, NewFlow),
	m_update:add_implicit_function(NewFlow, _NewFunc).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% unencapsulate/2 does the opposite of the above, but only returns a list of 
% nodes. The new arcs have the attributes of both the arcs they replace, with
% those ffrom the one nearest the destination taking precedence. Input/output
% and source/sink nodes are thrown away, even if they were visible.

unencapsulate(Node, Contents, ToReroute) :-
	(Node has_model_refinement link_equivalences of Equivs, !;
	    Equivs = []),
	(setof(OutputLink, is_output_link(Node, Equivs, OutputLink),
	      OutputLinks), !;
	OutputLinks = []),
	Parent has_part Node,
	extract_nodes(Node, Parent, Contents),
	make_link_spec(Node, Equivs, NewLinks),
	append(NewLinks, OutputLinks, ToReroute).

is_output_link(Submodel, Equivs, Link) :-
	Link draws_inside Submodel,
	Link is_connector from _ to Unseen,
	\+ find_type(Unseen, function),
	\+ appears(Unseen),
	\+ member(Link-_, Equivs).

/* make_link_spec/3: This flashy procedure is needed to cover the case where a
single internal link is equivalent to a different external one at each end */	

make_link_spec(_, [], []).

make_link_spec(Submodel, Equivs, [Link | NewLinks]) :-

	(select(Start-Mid, Equivs, Inter_equivs), 
	select(Mid-Finish, Inter_equivs, Others),
		Dead = [Start, Mid, Finish];
	select(Start-Finish, Equivs, Others),
		Dead = [Start, Finish]), !,

	(Start is_connector from Origin to _,
	    Finish is_connector from _ to Destination, !,
	    Link is_new_connector from Origin to Destination,
	    copy_local_attributes(Finish, Link),
	    copy_start_equivalences(Start, Link),
	    copy_finish_equivalences(Finish, Link),
	    change_references(Origin, Start, Link),
	    change_references(Destination, Finish, Link),
	    Gone = Dead;
	/* keep going if there is a bad equivalence */
	Gone = []),
	
	(member(OldLink, Gone),
	/* Don't kill link if it has other equivalences */
	    \+ member(OldLink-_, Others),
	    (_ has_changed_termination _ from OldLink to Link,
		fail;
	    kill_equivalences(OldLink)),
	    OldLink is_connector from Post1 to Post2,
	    OldLink is_no_longer_connector,
	    (	Cutoff = Post1; Cutoff = Post2),
	    \+ member(Cutoff, [Origin, Submodel, Destination]),
	    \+ _ is_connector from Cutoff to _,
	    m_update:Cutoff is_no_longer_model_class,
	    fail;
	make_link_spec(Submodel, Others, NewLinks),
	    scrap_spare_functions(Link)).

/* scrap_spare_functions/1: This takes care of the implicit functions for flows
that are merged into a single flow if using the system dynamics display mode.
It chooses the first one it finds with a formula, reassigns it to the new link
and obliterates the others, transferring any incoming links to the chosen one. 
Harsh but fair. */

scrap_spare_functions(Link) :-
	Link is_of_sort has_bowtie, state:get_style(sd),
		pick_best_function(Link, Grain),
		(_ is_connector from Chaff to Link,
			\+ Chaff = Grain,
			(_ has_changed_termination finish from Chaff to Grain,
				fail;
			m_update:Chaff is_no_longer_model_class,
				fail));
	true.

pick_best_function(Flow, Best) :-
	_ is_connector from Best to Flow,
	(Best has_class_refinement value of _;
	\+ (_ is_connector from Other to Flow,
		Other has_class_refinement value of _)),
	!.

extract_nodes(_, _, []).

extract_nodes(Node, Parent, [Child | Rest]) :-
	Child is_no_longer_part_of Node,
	Child is_also_part_of Parent,
	extract_nodes(Node, Parent, Rest).
	
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% all_same_parent checks that all the nodes in a list of nodes and arcs have
% the same parent and returns its name. It also separates out the nodes and
% arcs, and returns all the arcs connected to the nodes as well as the ones

all_same_parent( [], _, [], [], [] ).
all_same_parent( [Thing|Things], Parent, [Thing|Nodes], InclFlows, NewArcs ) :-
	Thing is_model_class,
	!, % green cut
	Thing is_part_of Parent,
	all_same_parent( Things, Parent, Nodes, InclFlows, Arcs ),
	(setof( Arc, A^B^( Arc is_connector from A to B,
			    member(Thing, [A,B]);
			    member( Arc, Arcs )), NewArcs ), !; NewArcs = []).
all_same_parent( [Thing|Things], Parent, Nodes, [Thing|InclFlows], Arcs ) :-
	Thing is_connector from P1 to _,
	P1 is_part_of Parent,
	all_same_parent( Things, Parent, Nodes, InclFlows, Arcs ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% add_link_equivalence convenient interface to the ADT to add equivalences

add_link_equivalence( Node, From-To ) :-
	\+ Node has_model_refinement link_equivalences of _Equivs,
	!,
	Node has_new_model_refinement link_equivalences of [From-To].
add_link_equivalence( Node, From-To ) :-
	Node has_model_refinement link_equivalences of Equivs,
	member( From-To, Equivs ),
	!.
add_link_equivalence( Node, Pair ) :-
	Node has_model_refinement link_equivalences of Equivs,
	Node has_changed_model_refinement link_equivalences of [Pair|Equivs].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete_link_equivalence ditto for deleting

delete_link_equivalence( Node, _ ) :-
	\+ Node has_model_refinement link_equivalences of _Equivs,
	!.
delete_link_equivalence( Node, From-To ) :-
	Node has_model_refinement link_equivalences of Equivs,
	\+ member( From-To, Equivs ),
	!.
delete_link_equivalence( Node, From-To ) :-
	Node has_model_refinement link_equivalences of Equivs,
	delall( Equivs, From-To, NewEquivs ),
	Node has_changed_model_refinement link_equivalences of NewEquivs,
	!; true.

kill_equivalences(Link) :-
	Link is_connector from Start to Finish,
	find_link_node(Start, SP),
	delete_link_equivalence(SP, _-Link),
	find_link_node(Finish, FP),
	delete_link_equivalence(FP, Link-_).

	
copy_local_attributes(Arc, NewArc) :-
	Arc has_type Type,
	findall( Attribute-Value,			
		 Arc has_attribute Attribute of Value,	
		 AVPairs ),				
	findall( GAttribute-GValue,			
		 Arc has_graphical_attribute GAttribute of GValue,
		 GAVPairs ),
	NewArc has_new_type Type,
	foreach( Attribute-Value,
		 AVPairs,
		 NewArc has_new_attribute Attribute of Value ),
/* Jasper needs to do this bit - graphical attributes can't just be copied */
	foreach( GAttribute-GValue,
		 GAVPairs,
		 NewArc has_new_graphical_attribute GAttribute of GValue).

copy_start_equivalences(FromArc, NewArc) :-
	NewArc is_connector from Start to _,
	find_link_node(Start, Parent),
	(Parent has_model_refinement link_equivalences of Equivs,
	    setof(Far-NewArc, member(Far-FromArc, Equivs), NewEquivs),
	    append(Equivs, NewEquivs, AllEquivs),
	    Parent has_changed_model_refinement link_equivalences
	        of AllEquivs, !;
	true).

copy_finish_equivalences(ToArc, NewArc) :-
	NewArc is_connector from _ to Finish,
	find_link_node(Finish, Parent),
	(Parent has_model_refinement link_equivalences of Equivs,
	    setof(NewArc-Far, member(ToArc-Far, Equivs), NewEquivs),
	    append(Equivs, NewEquivs, AllEquivs),
	    Parent has_changed_model_refinement link_equivalences
	        of AllEquivs, !;
	true).

substitute_start_equivalences(FromArc, NewArc) :-
	NewArc is_connector from Start to _,
	find_link_node(Start, Parent),
	change_equivalences(Parent, start, FromArc, NewArc).

/* The same arc may have only one start equivalence but may finishes */
substitute_finish_equivalences(ToArc, NewArc) :-
	NewArc is_connector from _ to Finish,
	find_link_node(Finish, Parent),
	change_equivalences(Parent, finish, ToArc, NewArc).

find_link_node(Node, Parent) :-
	Node has_class submodel, appears(Node), !, Parent = Node;
	find_all_comps(Parent, Node).

change_equivalences(Node, End, OldLink, NewLink) :-
	Node has_model_refinement link_equivalences of List, !,
	swap_all(List, End, OldLink, NewLink, NewList),
	Node has_changed_model_refinement link_equivalences 
		of NewList;
	true.

swap_all(List, End, Old, New, NewList) :-
	append(Early, [L1-L2 | Late], List),
	(End = finish, Old = L1, Sub = New-L2;
	    End = start, Old = L2, Sub = L1-New), !,
	append(Early, [Sub | Late], MidList),
	swap_all(MidList, End, Old, New, NewList);    
	NewList = List.

change_references(Node, OldLink, NewLink) :-
	NewLink has_type relation,
	Node has_model_refinement references of List, !,
	swap_all_refs(List, OldLink, NewLink, NewList),
	Node has_changed_model_refinement references of NewList;
	true.

swap_all_refs(List, Old, New, NewList) :-
	append(Early, [Ref | Late], List),
	Ref =.. [Type, Old],
	member(Type, [local, ancestor]), !,
	Sub =.. [Type, New],
	append(Early, [Sub | Late], MidList),
	swap_all_refs(MidList, Old, New, NewList);    
	NewList = List.

