/*******************************************************************************
**** Predicates for the manipulation of the node data structure             ****
*******************************************************************************/

sicstus_module( node,	
		[has_class/2, has_class_refinement/2, has_model_refinement/2,
		 has_new_class/2, has_new_class_refinement/2,
		 no_longer_has_class/1, no_longer_has_class/2,
		 has_new_model_refinement/2, no_longer_has_class_refinement/2,
		 no_longer_has_model_refinement/2, no_longer_has_refinements/1,
		 has_changed_class_refinement/2,
		 has_changed_model_refinement/2
		] ).

sicstus_use_module( [database,utility,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% The concrete datastructure is based on node_class/2. Arg 1 is a node name
% (generated in module model_structure; Arg 2 is a class.
% There are two other predicates, node_refinement/3 and node_attribute/3,
% which encode class refinements for a node and instantiation attributes,
% respectively.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given a node, return information about it

:- op( 500, xfy, has_class).

Node has_class Class :-
        node_class( Node, Class ).

:- op( 500, xfy, has_class_refinement).

Node has_class_refinement Refinement of Value :-
	node_refinement( Node, Refinement, Value ).

:- op( 500, xfy, has_model_refinement).

Node has_model_refinement Refinement of Value :-
	node_attribute( Node, Refinement, Value ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% make a new node datastructure

:- op( 500, xfy, has_new_class).

Node has_new_class Class :-
	\+ node_class( Node, Class ),
	assert_model( node_class( Node, Class )).

:- op( 500, xfy, has_new_class_refinement).

Node has_new_class_refinement Refinement of Value :-
	m_struct:Node is_model_class,
	\+ node_refinement( Node, Refinement, _AnyValue ),
	assert_model( node_refinement( Node, Refinement, Value )).

:- op( 500, xfy, has_new_model_refinement).

Node has_new_model_refinement Refinement of Value :-
	m_struct:Node is_model_class,
	\+ node_attribute( Node, Refinement, _AnyValue ),
	assert_model( node_attribute( Node, Refinement, Value )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete a refinement

:- op( 500, xfy, no_longer_has_class_refinement).

Node no_longer_has_class_refinement Refinement of OldValue :-
	retract_model( node_refinement( Node, Refinement, OldValue )).

:- op( 500, xfy, no_longer_has_model_refinement).

Node no_longer_has_model_refinement Refinement of OldValue :-
	retract_model( node_attribute( Node, Refinement, OldValue )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete a node datastructure 

:- op( 450, xf, no_longer_has_refinements).

Node no_longer_has_refinements :-
	retractall_model( node_class( Node, _ )),
	retractall_model( node_refinement( Node, _, _ )),
	retractall_model( node_attribute( Node, _, _ )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% delete a class attribution

:- op( 500, xfy, no_longer_has_class).

Node no_longer_has_class Class :-
	retract_model( node_class( Node, Class )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change a refinement

:- op( 500, xfy, has_changed_class_refinement).

Node has_changed_class_refinement Attribute of NewValue :-
	Node has_changed_class_refinement Attribute from _ to NewValue.

Node has_changed_class_refinement Attribute from OldValue to NewValue :-
	Node no_longer_has_class_refinement Attribute of OldValue,
	Node has_new_class_refinement Attribute of NewValue.

:- op( 500, xfy, has_changed_model_refinement).

Node has_changed_model_refinement Attribute of NewValue :-
	Node has_changed_model_refinement Attribute from _ to NewValue.

Node has_changed_model_refinement Attribute from OldValue to NewValue :-
	Node no_longer_has_model_refinement Attribute of OldValue,
	Node has_new_model_refinement Attribute of NewValue.

