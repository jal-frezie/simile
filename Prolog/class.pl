/*******************************************************************************
**** Predicates for manipulating classes				    ****
*******************************************************************************/

:- module( class, [is_class/1, has_class_attribute/2, is_new_class/1,
		   has_new_class_attribute/2, is_no_longer_class/1,
		   is_no_longer_class/2, no_longer_has_class_attribute/2,
		   has_class_attributes/2, has_changed_class_attribute/2,
		   no_longer_has_class_attributes/1, 
		   no_longer_has_class_attributes/2
		  ] ).

:- use_module( [database,utility] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY STARTS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% is_class is true if its arg is a class.

postfix is_class.

Class is_class :-
	declared_class( Class ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_class_attribute is true if arg 2 is the information associated with arg 1

infix [has_class_attribute,of]. 

Class has_class_attribute Attribute of Value :-
	Class is_class,
	attribute( Class, Attribute, Value ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% declare_class declares a new class

postfix is_new_class.

Class is_new_class :-
	\+ Class is_class,
	assert_model( declared_class( Class )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% is_no_longer_class deletes a class

postfix [is_no_longer_class,no_longer_has_class_attributes].

Class is_no_longer_class :-
	Class no_longer_has_class_attributes,
	retractall_model( declared_class( Class )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_new_class_attribute

infix has_new_class_attribute.

Class has_new_class_attribute Attribute of Value :-
	Class is_class,
	\+ attribute( Class, Attribute, Value ),
	assert_model( attribute( Class, Attribute, Value )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_changed_class_attribute

infix [has_changed_class_attribute,from,to].

Class has_changed_class_attribute Attribute from OldValue to NewValue :-
	Class is_class,
	retractall_model( attribute( Class, Attribute, OldValue )),
	assert_model( attribute( Class, Attribute, NewValue )).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% no_longer_has_class_attribute

infix no_longer_has_class_attribute.

Class no_longer_has_class_attribute Attribute of Value :-
	attribute( Class, Attribute, Value ),
	retractall_model( attribute( Class, Attribute, Value )).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ABSTRACTION BOUNDARY ENDS HERE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% has_class_attributes

infix has_class_attributes.

Class has_class_attributes ListOfAttValPairs :-
	any_setof( Attribute=Value,
		Class has_class_attribute Attribute of Value,
		ListOfAttValPairs ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% no_longer_has_class_attributes

infix no_longer_has_class_attributes.

Class no_longer_has_class_attributes AttributeValuePairs :-
	Class has_class_attributes AttributeValuePairs,
	foreach( Attribute=Value, AttributeValuePairs,
		      Class no_longer_has_class_attribute Attribute of Value ).

postfix no_longer_has_class_attributes.

Class no_longer_has_class_attributes :-
	Class no_longer_has_class_attributes _ListOfAttValPairs.
