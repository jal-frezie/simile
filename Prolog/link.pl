/*******************************************************************************
**** This module defines the predicates used for manipulating connecting    ****
**** arcs in the structure tree/lattice                                     ****
*******************************************************************************/

sicstus_module(link, [is_connector/2, is_new_connector/2,
		 is_also_connector/2,
		 is_no_longer_connector/1,
		 has_type/2, has_new_type/2, no_longer_has_type/2,
		 has_changed_type/2, has_attribute/2, has_new_attribute/2,
		 no_longer_has_attribute/2, has_changed_attribute/2, 
		 has_changed_termination/2, 
	connects/3, initiates/2, terminates/2, equivalent_arcs/2,
	sequence/2, follows/2, no_longer_has_connections/1] ).

sicstus_use_module( [database,utility,node,graphics,m_struct,library(lists)] ).

/* Note: the destination node has been made the first arg of connection/3.
It now goes connection(dest, source, arc). This is because the destination node
is the one we usually start with when looking for links, so putting it in the
'key' position should improve performance.
*/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Predicates for traversing, building and destroying decorating arcs 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given two nodes, find an arc between them. 

:- op( 500, xfy, is_connector).
:- op( 450, fy, [from, to]).

Arc is_connector from Node1 to Node2 :-
	connection( Node2, Node1, Arc ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given two nodes, make an arc between them
% arcs may only be placed between parents and offspring or between siblings

:- op( 500, xfy, [is_new_connector, is_also_connector]).

Arc is_new_connector from Source to Dest :-
	unique_name( arc, Arc ),
	Arc is_also_connector from Source to Dest.

Arc is_also_connector from Source to Dest :-
	(Source is_part_of _; Source is_connector from _ to _),
	(Dest is_part_of _; Dest is_connector from _ to _),
	assert_model( connection( Dest, Source, Arc )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding, getting and removing information about arc types

:- op( 500, xfy, [has_type,no_longer_has_type,has_new_type]).

Arc has_type Type :-
	arc_type( Arc, Type ).

Arc has_new_type Type :-
	\+ arc_type( Arc, _AnyType ),
	assert_model( arc_type( Arc, Type )).

Arc no_longer_has_type Type :-
	retract_model( arc_type( Arc, Type )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding, getting and removing information about arc attributes

:- op( 500, xfy, [has_attribute,has_new_attribute,no_longer_has_attribute]).

Arc has_attribute Attribute of Value :-
	arc_info( Arc, Attribute, Value ).

Arc has_new_attribute Attribute of Value :-
	Arc is_connector from _ to _,
	\+ arc_info( Arc, Attribute, _AnyValue ),
	assert_model( arc_info( Arc, Attribute, Value )).

Arc no_longer_has_attribute Attribute of Value :-
	!,
	ground( Attribute ),
	retract_model( arc_info( Arc, Attribute, Value )).

Arc no_longer_has_attribute Attribute :-
	atomic( Attribute ),
	Arc no_longer_has_attribute Attribute of _AnyValue.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete an arc connection

:- op( 450, xf, is_no_longer_connector).

Arc is_no_longer_connector :-
	any_setof( Influence-Source-Dest,
		   ((Arc = Source; Arc = Dest),
			Influence is_connector from Source to Dest),
		   BadArcs),
	foreach( Influence-Source-Dest, BadArcs,
			Influence is_no_longer_connector),

	try( Arc no_longer_has_type _Type ),
	any_setof( Attribute-Value,
		   Arc has_attribute Attribute of Value,
		   Pairs ),
	foreach( Attribute-Value, Pairs,
		 Arc no_longer_has_attribute Attribute of Value ),
	Arc no_longer_has_graphical_attributes,
	retract_model( connection( _Node2, _Node1, Arc )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Experimental facility to reroute a connection without disturbing it

:- op( 500, xfy, has_changed_termination).

Arc has_changed_termination End from OldEnd to NewEnd :-
	(NewEnd is_connector from _ to _; NewEnd is_part_of _),
	(End = start, OldStart = OldEnd, NewStart = NewEnd, NewFinish = OldFinish;
	End = finish, OldStart = NewStart, NewEnd = NewFinish, OldEnd = OldFinish),
	retract_model(connection(OldFinish, OldStart, Arc)),
	assert_model(connection(NewFinish, NewStart, Arc)).

Arc has_changed_termination End to NewEnd :-
	Arc has_changed_termination End from _OldEnd to NewEnd.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change the type of an arc.

:- op( 500, xfy, has_changed_type).

Arc has_changed_type from OldType to NewType :-
	Arc no_longer_has_type OldType,
	Arc has_new_type NewType.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change an attribute of an arc.

:- op( 500, xfy, has_changed_attribute).

Arc has_changed_attribute Attribute from OldValue to NewValue :-
	Arc no_longer_has_attribute Attribute of OldValue,
	Arc has_new_attribute Attribute of NewValue.

Arc has_changed_attribute Attribute to NewValue :-
	Arc has_changed_attribute Attribute from _AnyOldValue to NewValue.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% connects( Arc, Node1, Node2 ) if Arc connects Node1 and Node2, factoring out
% compound components

/*
connects( Arc, Node1, Node2 ) :-
	Arc is_connector from Node1 to Node3,
	Node3 has_model_refinement link_equivalences of Links,
	member( Arc-NewArc, Links ),
	NewArc is_connector from Node2,
	Node2 is_part_of Node3,
	!.
connects( Arc, Node1, Node2 ) :-
	Arc is_connector from Node3 to Node2,
	Node3 has_model_refinement link_equivalences of Links,
	member( OldArc-Arc, Links ),
	OldArc is_connector to Node1,
	Node1 is_part_of Node3,
	!.
connects( Arc, Node1, Node2 ) :-
	Arc is_connector from Node1 to Node2.

Geraint, you couldn't program your way out of a paper bagof! I see two clauses 
here, one for link that starts on a component and one that finishes on one. It 
...what I'm saying is this should be recursive. OK, I'll go on the assumption that
we don't want to follow outgoing links to their eventual destinations, but stop on
the 'ghost' cloud/variable instead. I could be wrong here */

connects(Arc, Start, Finish) :-
	nonvar(Start), 
	    initiates(Arc, Start),
	    terminates(Arc, Finish);
	var(Start),
	    terminates(Arc, Finish), 
	    initiates(Arc, Start).

/* OK, I want to be able to call the above with any one argument instantiated,
though in practice that adds up to being able to call either of the next two in
such a case. So let's see what I can do. Initiates should succeed for any
combination of arc and node where following arc back will place one on node;
terminates similarly the other way round. */

initiates(Arc, Endpoint) :-
	nonvar(Arc),
		(OtherArc = Arc; sequence(OtherArc, Arc)),
		\+ sequence(_, OtherArc),
		OtherArc is_connector from Endpoint to _;
	var(Arc),
		OtherArc is_connector from Endpoint to _,
		\+ sequence(_, OtherArc),
		(OtherArc = Arc; sequence(OtherArc, Arc)).

terminates(Arc, Endpoint) :-
	nonvar(Arc),
		(OtherArc = Arc; sequence(Arc, OtherArc)),
		\+ sequence(OtherArc, _),
		OtherArc is_connector from _ to Endpoint;
	var(Arc),
		OtherArc is_connector from _ to Endpoint,
		\+ sequence(OtherArc, _),
		(OtherArc = Arc; sequence(Arc, OtherArc)).

equivalent_arcs(Arc, General_arc) :-
	General_arc = Arc; sequence(Arc, General_arc); sequence(General_arc, Arc).

sequence(Link2, Link1) :-
	nonvar(Link1),
	    follows(Link3, Link1),
	    (sequence(Link2, Link3); Link3 = Link2);
	var(Link1),
	    follows(Link2, Link3),
	    (sequence(Link3, Link1); Link3 = Link1).

follows(Link2, Link1) :-
	(nonvar(Link1),
	    Link1 is_connector from Edge to _;
	var(Link1),
	    Link2 is_connector from _ to Edge),
	(Node = Edge; Node has_part Edge),
	Node has_model_refinement link_equivalences of Links,
	member(Link2-Link1, Links).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node is_no_longer_has_connections succeeds if Node's connecting arcs have
% been deleted from the tree
% NB more work to do here once connectors are installed

:- op(450, xf, no_longer_has_connections).

Node no_longer_has_connections:-
	findall( Connector, Connector is_connector from Node to _, Outs ),
	foreach( Out, Outs, Out is_no_longer_connector ),
	findall( Connector, Connector is_connector from _ to Node, Ins ),
	foreach( In, Ins, In is_no_longer_connector ).

