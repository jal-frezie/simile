/*******************************************************************************
**** This module defines the predicates used for adding and deleting        ****
**** graphical information and is common to nodes and arcs                  ****
*******************************************************************************/

sicstus_module( graphics,
		[has_graphical_attribute/2, 
		 has_new_graphical_attribute/2,
		 no_longer_has_graphical_attribute/2, 
		 has_changed_graphical_attribute/2,
		 no_longer_has_graphical_attributes/1
		] ).

sicstus_use_module( [database,utility,library(lists)] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% adding, getting and removing information about graphical attributes

:- op(500, xfy, [has_graphical_attribute]).

Object has_graphical_attribute Attribute of Value :-
	graphical_info( Object, Attribute, Value ).

:- op(500, xfy, [has_new_graphical_attribute]).

Object has_new_graphical_attribute Attribute of Value :-
	\+ graphical_info( Object, Attribute, _AnyValue ),
	assert_model( graphical_info( Object, Attribute, Value )).

:- op(450, xf, [no_longer_has_graphical_attributes]).

Node no_longer_has_graphical_attributes :-
	retractall_model(graphical_info(Node, _, _)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% delete a graphical attribute of an object.

:- op(500, xfy, [no_longer_has_graphical_attribute]).

Object no_longer_has_graphical_attribute Attribute of Value :-
	!,
	ground( Attribute ),
	retract_model( graphical_info( Object, Attribute, Value )).

Object no_longer_has_graphical_attribute Attribute :-
	atomic( Attribute ),
	Object no_longer_has_graphical_attribute Attribute of _AnyValue.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% change a graphical attribute of an object.

:- op(500, xfy, [has_changed_graphical_attribute]).

Object has_changed_graphical_attribute Attribute from OldValue to NewValue :-
	Object no_longer_has_graphical_attribute Attribute of OldValue,
	Object has_new_graphical_attribute Attribute of NewValue.

Object has_changed_graphical_attribute Attribute to NewValue :-
	Object has_changed_graphical_attribute Attribute from _AnyOldValue to NewValue.

