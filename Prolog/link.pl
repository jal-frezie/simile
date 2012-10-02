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
	now_follows/2, follows/2, no_longer_follows/2,
	has_new_link_equivalences/2, has_link_equivalences/2,
	has_changed_link_equivalences/2, no_longer_has_link_equivalences/2,
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
	query_model(connection( Node2, Node1, Arc )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given two nodes, make an arc between them
% arcs may only be placed between parents and offspring or between siblings

:- op( 500, xfy, [is_new_connector, is_also_connector]).

Arc is_new_connector from Source to Dest :-
	(nonvar(Arc);
	unique_name( arc, Arc ),
	    \+ Arc is_connector _), !,
	assert_model(is_arc(Arc)),
	Arc is_also_connector from Source to Dest.

Arc is_also_connector from Source to Dest :-
	parent_of(Source, Parent),
	parent_of(Dest, Parent),
	assert_model( connection( Dest, Source, Arc )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding, getting and removing information about arc types

:- op( 500, xfy, [has_type,no_longer_has_type,has_new_type]).

Arc has_type Type :-
	query_model(arc_type( Arc, Type )).

Arc has_new_type Type :-
	\+ query_model(arc_type( Arc, _AnyType )),
	assert_model( arc_type( Arc, Type )).

Arc no_longer_has_type Type :-
	retract_model( arc_type( Arc, Type )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding, getting and removing information about arc attributes

:- op( 500, xfy, [has_attribute,has_new_attribute,no_longer_has_attribute]).

Arc has_attribute Attribute of Value :-
	query_model(arc_info( Arc, Attribute, Value )).

Arc has_new_attribute Attribute of Value :-
	Arc is_connector from _ to _,
	\+ query_model(arc_info( Arc, Attribute, _AnyValue )),
	assert_model( arc_info( Arc, Attribute, Value )).

Arc no_longer_has_attribute Attribute of Value :-
	!,
	ground( Attribute ),
	retract_model( arc_info( Arc, Attribute, Value )).

Arc no_longer_has_attribute Attribute :-
	atomic( Attribute ),
	Arc no_longer_has_attribute Attribute of _AnyValue.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Experimental facility to reroute a connection without disturbing it

:- op( 500, xfy, has_changed_termination).

Arc has_changed_termination End from OldEnd to NewEnd :-
	retract_model(connection(OldFinish, OldStart, Arc)),
	member(End-NewFinish-NewStart-OldEnd-FarEnd,
	       [start-OldFinish-NewEnd-OldStart-OldFinish,
		finish-NewEnd-OldStart-OldFinish-OldStart]),
	parent_of(FarEnd, Parent),
	parent_of(NewEnd, Parent),
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
:- op(500, xfy, now_follows).
:- op(500, xfy, follows).
:- op(500, xfy, no_longer_follows).

After now_follows Before :-
	assert_model(continues(Before, After)).

After follows Before :-
	query_model(continues(Before, After)).

After no_longer_follows Before :-
	retract_model(continues(Before, After)).

% following are a bit legacy
:- op(500, xfy, has_link_equivalences).

Node has_link_equivalences Links :-
	Node has_class submodel,
	setof(Link, has_link_equivalence(Node, Link), Links).

has_link_equivalence(Node, Prev-Subs) :-
	(Subs is_connector from Node to _, Inner = Prev, Bdr = End;
	    Prev is_connector from _ to Node, Inner = Subs, Bdr = Start),
	Subs follows Prev,
	Inner is_connector from Start to End,
	Bdr is_part_of Node.

:- op(500, xfy, no_longer_has_link_equivalences).

Node no_longer_has_link_equivalences Links :-
	Node has_link_equivalences Links,
	all(link, remove_connection, [build(Links)]).

remove_connection(Prev-Subs) :-
	Subs no_longer_follows Prev.

:- op(500, xfy, has_new_link_equivalences).

_Node has_new_link_equivalences Links :-
	all(link, add_connection, [build(Links)]).

add_connection(Prev-Subs) :-
	Subs now_follows Prev.

:- op(500, xfy, has_changed_link_equivalences).

Node has_changed_link_equivalences Links :-
	Node no_longer_has_link_equivalences _OldLinks,
	Node has_new_link_equivalences Links.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete an arc connection

:- op( 450, xf, is_no_longer_connector).
:- op( 450, xf, no_longer_has_connections).

Arc is_no_longer_connector :-
	Arc no_longer_has_connections,
	Arc no_longer_has_type _Type,
	any_setof( Attribute-Value,
		   Arc has_attribute Attribute of Value,
		   Pairs ),
	foreach( Attribute-Value, Pairs,
		 Arc no_longer_has_attribute Attribute of Value ),
	Arc no_longer_has_graphical_attributes,
	(_ no_longer_follows Arc, fail;
	    Arc no_longer_follows _, fail;
	retract_model( connection( _Node2, _Node1, Arc ))),
	retract_model(is_arc(Arc)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parent_of(Node, Parent) :-
	Node is_part_of NodeOrArc,
	(NodeOrArc is_connector from End to _, !,
	    End is_part_of Parent;
	  Parent = NodeOrArc). % nodes in links but no links to/from links

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
	    Link1 follows Link3,
	    (sequence(Link2, Link3); Link3 = Link2);
	var(Link1),
	    Link3 follows Link2,
	    (sequence(Link3, Link1); Link3 = Link1).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node is_no_longer_has_connections succeeds if Node's connecting arcs have
% been deleted from the tree

Node no_longer_has_connections :-
	(Source = Node; Dest = Node),
	Connector is_connector from Source to Dest,
	Connector is_no_longer_connector,
	fail; true.

