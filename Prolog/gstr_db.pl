:- foreign(empty_tree(term)).

:- foreign(create_node(term)). 
:- foreign(add_to_tree(term, term)). 
:- foreign(set_class(term, term)). 
:- foreign(add_bbox(term, term, term, term, term)).
:- foreign(add_iext(term, term, term, term, term)).
:- foreign(add_capt_off(term, term, term)).
:- foreign(add_centre(term, term, term)).
:- foreign(set_hidden(term, term)).
:- foreign(create_arc(term)). 
:- foreign(add_link(term, term, term)). 
:- foreign(add_continuation(term, term)).
:- foreign(set_type(term, term)). 
:- foreign(add_curve(term, term, term)).

:- foreign(delete_node(+string)). 
:- foreign(remove_from_tree(+string, +string)). 
:- foreign(unset_class(+string, +atom)). 
:- foreign(delete_arc(+string)). 
:- foreign(remove_link(+string, +string, +string)). 
:- foreign(unset_type(+string, +atom)). 
:- foreign(remove_continuation(+string, +string)).
:- foreign(remove_curve(+string)).
:- foreign(remove_bbox(+string)).
:- foreign(remove_iext(+string)).
:- foreign(remove_capt_off(+string)).
:- foreign(remove_centre(+string)).

:- foreign(find_parent(+string, -integer)).
:- foreign(get_child_list_pointer(+string, -integer)).
:- foreign(get_class(+string, -atom)). 
:- foreign(find_ends(term, term, term)). 
:- foreign(get_in_list_pointer(+string, -integer)).
:- foreign(get_out_list_pointer(+string, -integer)).
:- foreign(get_type(+string, -atom)).
:- foreign(find_prev(+string, -integer)).
:- foreign(get_next_list_pointer(+string, -integer)).
:- foreign(find_curve(+string, -integer, -integer)).
:- foreign(find_bbox(+string, -integer, -integer, -integer, -integer)).
:- foreign(find_iext(+string, -integer, -integer, -integer, -integer)).
:- foreign(find_capt_off(+string, -integer, -integer)).
:- foreign(find_centre(+string, -integer, -integer)).
:- foreign(is_hidden(+string)).
:- foreign(get_id_and_next_ptr(+integer, -integer, -integer)).
