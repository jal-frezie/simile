/*******************************************************************************
**** This module defines the predicates used for manipulating connecting    ****
**** arcs in the structure tree/lattice                                     ****
*******************************************************************************/

:- module(link, [is_connector/1, is_connector/2, is_new_connector/2,
		 is_also_connector/2,
		 is_no_longer_connector/1, is_no_longer_connector/2,
		 has_type/2, has_new_type/2, no_longer_has_type/2,
		 has_changed_type/2, has_attribute/2, has_new_attribute/2,
		 no_longer_has_attribute/2, has_changed_attribute/2, 
		 has_changed_termination/2
		] ).

:- use_module( [database,utility,graphics,library(lists)] ).
:- use_module( m_struct).

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

infix [is_connector, from, to].
prefix [from, to].

Arc is_connector from Node1 to Node2 :-
	connection( Node2, Node1, Arc ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given two nodes, make an arc between them
% arcs may only be placed between parents and offspring or between siblings

infix is_new_connector.
infix is_also_connector.

/* the following version by Geraint has been removed because it is 
(a) obsolete (No longer have parent/child connections)
(b) baroque (check it OUT) and
(c) buggy (creates another arc on retry if arc comes from an arc.

Arc is_new_connector from Node1 to Node2 :- 	% arc between sibling nodes
	ParentNode has_part Node1,
	ParentNode has_part Node2,
	unique_name( arc, Arc ),
	assert( connection( Arc, Node1, Node2 )).
Arc is_new_connector from Node1 to Node2 :-	% arc down node hierarchy
	Node1 has_part Node2,
	unique_name( arc, Arc ),
	assert( connection( Arc, Node1, Node2 )).
Arc is_new_connector from Node1 to Node2 :-	% arc up node hierarchy
	Node1 is_part_of Node2,
	unique_name( arc, Arc ),
	assert( connection( Arc, Node1, Node2 )).
Arc1 is_new_connector from Node1 to Arc2 :-	% arc from (node) to (arc from
	Arc2 is_connector from Node2,		% sibling node)
	ParentNode has_part Node1,
	ParentNode has_part Node2,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Node1, Arc2 )).
Arc1 is_new_connector from Arc2 to Node1 :-	% arc from (arc from node) to 
	Arc2 is_connector from Node2,		% (sibling node)
	ParentNode has_part Node1,
	ParentNode has_part Node2,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Arc2, Node1 )).
Arc1 is_new_connector from Node1 to Arc2 :-	% arc from (node) to (arc to
	Arc2 is_connector to Node2,		% sibling node)
	ParentNode has_part Node1,
	ParentNode has_part Node2,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Node1, Arc2 )).
Arc1 is_new_connector from Arc2 to Node1 :-	% arc from (arc to node) to 
	Arc2 is_connector to Node2,		% (sibling node)
	ParentNode has_part Node1,
	ParentNode has_part Node2,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Arc2, Node1 )).
Arc1 is_new_connector from Arc2 to Node1 :-     % arc from (arc to node) to
	Arc2 is_connector to Node2,		% (parent node)
	Node2 has_part Node1,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Arc2, Node1 )).
Arc1 is_new_connector from Arc2 to Node1 :-     % arc from (arc from node) to
	Arc2 is_connector from Node2,		% (parent node)
	Node2 has_part Node1,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Arc2, Node1 )).
Arc1 is_new_connector from Node1 to Arc2 :-     % arc to (arc to node) from
	Arc2 is_connector to Node2,		% (parent node)
	Node2 is_part_of Node1,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Node1, Arc2 )).
Arc1 is_new_connector from Node1 to Arc2 :-     % arc to (arc from node) from
	Arc2 is_connector from Node2,		% (parent node)
	Node2 is_part_of Node1,
	unique_name( arc, Arc1 ),
	assert( connection( Arc1, Node1, Arc2 )).

Anyway, what is the point of trying to suppress the creation of bad-assed arcs,
when we are quite at liberty to make them anyway by moving the nodes around
after the fact? I should at least make sure the endpoints exist...
*/

Arc is_new_connector from Source to Dest :-
	unique_name( arc, Arc ),
	Arc is_also_connector from Source to Dest.

Arc is_also_connector from Source to Dest :-
	(Source is_part_of _; Source is_connector from _ to _),
	(Dest is_part_of _; Dest is_connector from _ to _),
	assert_model( connection( Dest, Source, Arc )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding, getting and removing information about arc types

infix has_type.

Arc has_type Type :-
	arc_type( Arc, Type ).

infix has_new_type.

Arc has_new_type Type :-
	\+ arc_type( Arc, _AnyType ),
	assert_model( arc_type( Arc, Type )).

infix no_longer_has_type.

Arc no_longer_has_type Type :-
	retract_model( arc_type( Arc, Type )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% adding, getting and removing information about arc attributes

infix [has_attribute,of].

Arc has_attribute Attribute of Value :-
	arc_info( Arc, Attribute, Value ).

infix has_new_attribute.

Arc has_new_attribute Attribute of Value :-
	Arc is_connector from _ to _,
	\+ arc_info( Arc, Attribute, _AnyValue ),
	assert_model( arc_info( Arc, Attribute, Value )).

infix no_longer_has_attribute.

Arc no_longer_has_attribute Attribute of Value :-
	!,
	ground( Attribute ),
	retract_model( arc_info( Arc, Attribute, Value )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete an arc connection

infix is_no_longer_connector.

Arc is_no_longer_connector from Node1 to Node2 :-
	any_setof( Influence-Source-Dest,
		   ((Arc = Source; Arc = Dest),
			Influence is_connector from Source to Dest),
		   BadArcs),
	foreach( Influence-Source-Dest, BadArcs,
			Influence is_no_longer_connector from Source to Dest ),

	try( Arc no_longer_has_type _Type ),
	any_setof( Attribute-Value,
		   Arc has_attribute Attribute of Value,
		   Pairs ),
	foreach( Attribute-Value, Pairs,
		 Arc no_longer_has_attribute Attribute of Value ),
	Arc no_longer_has_graphical_attributes,
	retract_model( connection( Node2, Node1, Arc )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Experimental facility to reroute a connection without disturbing it

infix has_changed_termination.

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
% look up an arc connection

postfix is_connector.

Arc is_connector :-
	Arc is_connector from _Start to _End.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete an arc connection

postfix is_no_longer_connector.

Arc is_no_longer_connector :-
	Arc is_no_longer_connector from _Node1 to _Node2.
Arc is_no_longer_connector from Node1 :-
	Arc is_no_longer_connector from Node1 to _Node2.
Arc is_no_longer_connector to Node2 :-
	Arc is_no_longer_connector from _Node1 to Node2.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change the type of an arc.

infix has_changed_type.

Arc has_changed_type from OldType to NewType :-
	Arc no_longer_has_type OldType,
	Arc has_new_type NewType.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete the type of an arc.

postfix no_longer_has_type.

Arc no_longer_has_type :-
	Arc no_longer_has_type _AnyType.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete an attribute of an arc.

Arc no_longer_has_attribute Attribute :-
	atomic( Attribute ),
	Arc no_longer_has_attribute Attribute of _AnyValue.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change an attribute of an arc.

infix [has_changed_attribute,from].

Arc has_changed_attribute Attribute from OldValue to NewValue :-
	Arc no_longer_has_attribute Attribute of OldValue,
	Arc has_new_attribute Attribute of NewValue.

Arc has_changed_attribute Attribute to NewValue :-
	Arc has_changed_attribute Attribute from _AnyOldValue to NewValue.

