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
		 has_changed_termination/2
		] ).

sicstus_use_module( [database,utility,graphics,m_struct,library(lists)] ).

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
			Influence is_no_longer_connector from Source to Dest ),

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

