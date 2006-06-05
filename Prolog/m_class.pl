/*******************************************************************************
**** This module defines the predicates used for manipulating the model     ****
**** class data structure 						                ****
*******************************************************************************/
sicstus_module(m_class, [is_new_part_of/2, is_part_of/2, has_part/2, 
	has_parts/2, have_part/2, is_new_model_class/1, is_also_part_of/2,
	is_root/1, is_library/1, is_no_longer_part_of/2,
	is_model_class/1,
	has_class/2, has_class_refinement/2, has_model_refinement/2,
	has_new_class/2, has_new_class_refinement/2,
	has_new_model_refinement/2,
	no_longer_has_model_refinement/2,
	no_longer_has_class_refinement/2,
	no_longer_has_refinements/1,
	has_type/2, has_new_type/2, no_longer_has_type/2,
	has_changed_type/2, has_attribute/2, has_new_attribute/2,
	no_longer_has_attribute/2, has_changed_attribute/2,
	has_changed_termination/2, 
	has_graphical_attribute/2, has_new_graphical_attribute/2,
	no_longer_has_graphical_attribute/2, 
	no_longer_has_graphical_attributes/1, 
	has_changed_graphical_attribute/2,
	is_connector/2, is_new_connector/2,
	is_also_connector/2,
	is_no_longer_connector/1, is_no_longer_connector/2,
	no_longer_has_class/1, no_longer_has_class/2,
	has_changed_class_refinement/2,
	has_changed_model_refinement/2, 
	connects/3, initiates/2, terminates/2, equivalent_arcs/2,
	sequence/2, follows/2, logical_follows/2,
	no_longer_has_connections/1] ).

sicstus_use_module([library(lists),link,m_struct,node,graphics,text,utility]).

