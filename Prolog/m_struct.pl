/*******************************************************************************
**** This module defines the predicates used for manipulating the model     ****
**** structure tree/lattice                                                 ****
**** This is the abstraction boundary for the implementation of the lattice ****
**** NB: this module has no error checking at all. It is assumed that the   ****
**** modules calling it will take care of consistency in the KR             ****
*******************************************************************************/

:- module( m_struct,
		[is_new_part_of/2, is_part_of/2, has_part/2, has_parts/2,
		 have_part/2, is_new_model_class/1, is_also_part_of/2,
		 is_root/1, is_no_longer_part_of/2, is_model_class/1
		] ).

:- use_module( [database,utility,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Predicates for traversing the network

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given a node, find a single child or a single parent

infix is_part_of.

Child is_part_of Parent :-
	subsystem( Parent, Child ).

infix has_part.

Parent has_part Child :-
	subsystem( Parent, Child ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Predicates for building and destroying the basic network

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% define the syntax of the root node name.

postfix is_root.

root is_root.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make a new node name

postfix is_new_model_class.

Node is_new_model_class :-
	unique_name( node, Node ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attach an existing node to a parent

infix is_also_part_of.

Node is_also_part_of Parent :-
	assert_model( subsystem( Parent, Node )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Delete an existing node

infix is_no_longer_part_of.

Node is_no_longer_part_of Parent :-
	retractall_model( subsystem( Parent, Node )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test if a node is indeed in the lattice

postfix is_model_class.

Class is_model_class :-
	Class is_root.
Class1 is_model_class :-
	Class1 is_part_of Class2,
	Class2 is_model_class.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Make a new node, insert it into the tree as a leaf, and return its name

infix is_new_part_of.

Node is_new_part_of Parent :-
	Node is_new_model_class,
	Node is_also_part_of Parent.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% given a node, find all the children or all the parents

infix has_parts.

Parent has_parts Children :-
	bagof( Child, Parent has_part Child, Children ).

infix have_part.

Parents have_part Child :-
	bagof( Parent, Parent has_part Child, Parents ).

