:- foreign(empty_tree(term, term)).

:- foreign(create_node(term)). 
:- foreign(add_to_tree(term, term)). 
:- foreign(set_class(term, term)). 
:- foreign(add_bbox(term, term, term, term, term)).
:- foreign(add_iext(term, term, term, term, term)).
:- foreign(add_capt_off(term, term, term)).
:- foreign(add_centre(term, term, term)).
:- foreign(add_along(term, term)).
:- foreign(set_hidden(term, term)).
:- foreign(create_arc(term)). 
:- foreign(add_link(term, term, term)). 
:- foreign(add_continuation(term, term)).
:- foreign(set_type(term, term)). 
:- foreign(add_curve(term, term, term)).

:- foreign(delete_node(term)). 
:- foreign(remove_from_tree(term, term)). 
:- foreign(unset_class(term)). 
:- foreign(remove_bbox(term)).
:- foreign(remove_iext(term)).
:- foreign(remove_centre(term)).
:- foreign(remove_along(term)).
:- foreign(remove_capt_off(term)).
:- foreign(delete_arc(term)). 
:- foreign(remove_link(term, term, term)). 
:- foreign(unset_type(term)). 
:- foreign(remove_continuation(term, term)).
:- foreign(remove_curve(term)).

:- foreign(find_parent(term, term)).
:- foreign(get_child_list_pointer(term, term)).
:- foreign(get_class(term, term)). 
:- foreign(find_ends(term, term, term)). 
:- foreign(get_in_list_pointer(term, term)).
:- foreign(get_out_list_pointer(term, term)).
:- foreign(get_type(term, term)).
:- foreign(find_prev(term, term)).
:- foreign(get_next_list_pointer(term, term)).
:- foreign(find_curve(term, term)).
:- foreign(find_bbox(term, term)).
:- foreign(find_iext(term, term)).
:- foreign(find_capt_off(term, term)).
:- foreign(find_centre(term, term)).
:- foreign(find_along(term, term)).
:- foreign(is_hidden(term)).
:- foreign(get_node_and_next_ptr(term, term, term)).
:- foreign(get_arc_and_next_ptr(term, term, term)).
