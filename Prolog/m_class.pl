/*******************************************************************************
**** This module defines the predicates used for manipulating the model     ****
**** class data structure 						                ****
*******************************************************************************/

:- module( m_class,
		[is_new_part_of/2, is_part_of/2, has_part/2, has_parts/2,
		 have_part/2, is_new_model_class/1, is_also_part_of/2,
		 is_root/1, is_no_longer_part_of/2,
		 is_model_class/1,
		 has_class/2, has_class_refinement/2, has_model_refinement/2,
		 has_new_class/2, has_new_class_refinement/2,
		 has_new_model_refinement/2, is_no_longer_model_class/1,
		 no_longer_has_model_refinement/2,
		 no_longer_has_class_refinement/2,
		 has_type/2, has_new_type/2, no_longer_has_type/2,
		 has_changed_type/2, has_attribute/2, has_new_attribute/2,
	         no_longer_has_attribute/2, has_changed_attribute/2,
		 has_changed_termination/2, 
		 has_graphical_attribute/2, has_new_graphical_attribute/2,
		 no_longer_has_graphical_attribute/2, 
		 has_changed_graphical_attribute/2,
		 is_class/1, has_class_attribute/2, is_new_class/1,
		 has_new_class_attribute/2, is_no_longer_class/1,
		 is_no_longer_class/2, no_longer_has_class_attribute/2,
		 has_class_attributes/2, has_changed_class_attribute/2,
		 no_longer_has_class_attributes/1,
		 no_longer_has_class_attributes/2,
		 is_connector/1, is_connector/2, is_new_connector/2,
		 is_also_connector/2,
		 is_no_longer_connector/1, is_no_longer_connector/2,
		 no_longer_has_class/1, no_longer_has_class/2,
		 has_changed_class/2, has_changed_class_refinement/2,
		 has_changed_model_refinement/2, 

		 connects/3, initiates/2, terminates/2, equivalent_arcs/2,
		 sequence/2] ).

:- use_module( [library(lists),link,m_struct,node,class,graphics,
		text,utility] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node is_no_longer_has_connections succeeds if Node's connecting arcs have
% been deleted from the tree
% NB more work to do here once connectors are installed

postfix no_longer_has_connections.

Node no_longer_has_connections:-
	findall( Connector, Connector is_connector from Node to _, Outs ),
	foreach( Out, Outs, Out is_no_longer_connector ),
	findall( Connector, Connector is_connector from _ to Node, Ins ),
	foreach( In, Ins, In is_no_longer_connector ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Node is_no_longer_model_class succeeds if Node has been deleted from the tree
% along with all its related information
% NB much more work to do here once connectors are installed; think about
% connectors through the model class boundary, and about inherited values

postfix is_no_longer_model_class.

Node is_no_longer_model_class :-
	Node is_part_of Parent,
	\+ Node has_part _OtherNode,
	!,
	Node no_longer_has_refinements,
	Node no_longer_has_connections,
	Node no_longer_has_graphical_attributes,
	Node is_no_longer_part_of Parent.

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
	when((nonvar(Arc);nonvar(Start)), initiates(Arc, Start)),
	terminates(Arc, Finish).

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
	nonvar(Link1),
	    Link1 is_connector from Start to _,
	    (Node = Start; Node has_part Start),
	    Node has_model_refinement link_equivalences of Links,
	    member(Link2-Link1, Links);
	var(Link1),
	    Link2 is_connector from _ to Finish,
	    (Node = Finish; Node has_part Finish),
	    Node has_model_refinement link_equivalences of Links,
	    member(Link2-Link1, Links).
