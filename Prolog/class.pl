/*******************************************************************************
**** Predicates for manipulating classes				    ****
*******************************************************************************/

sicstus_module( class, [is_class/1, has_class_attribute/2, is_new_class/1,
		   has_new_class_attribute/2, is_no_longer_class/1,
		   is_no_longer_class/2, no_longer_has_class_attribute/2,
		   has_class_attributes/2, has_changed_class_attribute/2,
		   no_longer_has_class_attributes/1, 
		   no_longer_has_class_attributes/2] ).

sicstus_use_module( [database,utility] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% is_class is true if its arg is a class.

:- op(450, xf, is_class).

Class is_class :-
	declared_class( Class ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_class_attribute is true if arg 2 is the information associated with arg 1

:- op(500, xfy, has_class_attribute).

Class has_class_attribute Attribute of Value :-
	Class is_class,
	attribute( Class, Attribute, Value ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% declare_class declares a new class

:- op(450, xf, is_new_class).

Class is_new_class :-
	\+ Class is_class,
	assert_model( declared_class( Class )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% is_no_longer_class deletes a class

:- op(450, xf, [is_no_longer_class,no_longer_has_class_attributes]).

Class is_no_longer_class :-
	Class no_longer_has_class_attributes,
	retractall_model( declared_class( Class )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_new_class_attribute

:- op(500, xfy, has_new_class_attribute).

Class has_new_class_attribute Attribute of Value :-
	Class is_class,
	\+ attribute( Class, Attribute, Value ),
	assert_model( attribute( Class, Attribute, Value )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_changed_class_attribute

:- op(500, xfy, has_changed_class_attribute).

Class has_changed_class_attribute Attribute from OldValue to NewValue :-
	Class is_class,
	retractall_model( attribute( Class, Attribute, OldValue )),
	assert_model( attribute( Class, Attribute, NewValue )).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% no_longer_has_class_attribute

:- op(500, xfy, no_longer_has_class_attribute).

Class no_longer_has_class_attribute Attribute of Value :-
	attribute( Class, Attribute, Value ),
	retractall_model( attribute( Class, Attribute, Value )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_class_attributes

:- op(500, xfy, has_class_attributes).

Class has_class_attributes ListOfAttValPairs :-
	any_setof( Attribute=Value,
		Class has_class_attribute Attribute of Value,
		ListOfAttValPairs ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% no_longer_has_class_attributes

Class no_longer_has_class_attributes  :-
	Class has_class_attributes AttributeValuePairs,
	foreach( Attribute=Value, AttributeValuePairs,
		      Class no_longer_has_class_attribute Attribute of Value ).

