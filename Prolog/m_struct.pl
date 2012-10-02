/*******************************************************************************
**** This module defines the predicates used for manipulating the model     ****
**** structure tree/lattice                                                 ****
**** This is the abstraction boundary for the implementation of the lattice ****
**** NB: this module has no error checking at all. It is assumed that the   ****
**** modules calling it will take care of consistency in the KR             ****
*******************************************************************************/

sicstus_module( m_struct,
		[is_new_part_of/2, is_part_of/2, has_part/2, has_parts/2,
		 have_part/2, is_new_model_class/1, is_also_part_of/2,
		 is_root/1, is_no_longer_part_of/2, is_model_class/1,
		 is_no_longer_model_class/1] ).

sicstus_use_module( [database,utility,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Predicates for traversing the network

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given a node, find a single child or a single parent

:- op(500, xfy, is_part_of).

Child is_part_of Parent :-
	query_model(subsystem( Parent, Child )).

:- op(500, xfy, has_part).

Parent has_part Child :-
	query_model(subsystem( Parent, Child )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Predicates for building and destroying the basic network

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% define the syntax of the root node name.

:- op(450, xf, is_root).

root is_root.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make a new node name (only allow node00000 if database is empty)

:- op(450, xf, is_new_model_class).

Node is_new_model_class :-
	(nonvar(Node);
	\+ _ is_part_of _,
	    Node = node00000;
	unique_name( node, Node ),
	    \+ Node is_part_of _),
	assert_model(is_node(Node)), !.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attach an existing node to a parent

:- op(500, xfy, is_also_part_of).

Node is_also_part_of Parent :-
	assert_model( subsystem( Parent, Node )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Delete an existing node

:- op(500, xfy, is_no_longer_part_of).

Node is_no_longer_part_of Parent :-
	retract_model( subsystem( Parent, Node )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test if a node is indeed in the lattice

:- op( 450, xf, is_model_class).

Class is_model_class :-
	Class is_root.
Class1 is_model_class :-
	Class1 is_part_of Class3,
	(Class2 = Class3;
	    query_model(connection(Class2, _, Class3))),
	Class2 is_model_class.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make a new node, insert it into the tree as a leaf, and return its name

:- op(500, xfy, is_new_part_of).

Node is_new_part_of Parent :-
	Node is_new_model_class,
	Node is_also_part_of Parent.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given a node, find all the children or all the parents

:- op(500, xfy, has_parts).

Parent has_parts Children :-
	bagof( Child, Parent has_part Child, Children ).

:- op(500, xfy, have_part).

Parents have_part Child :-
	bagof( Parent, Parent has_part Child, Parents ).


:- op(450, xf, is_no_longer_model_class).

Node is_no_longer_model_class :-
	retract_model(is_node(Node)).
