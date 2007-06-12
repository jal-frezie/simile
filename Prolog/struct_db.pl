foreign_resource(struct_db,
		    [empty_tree, create_node, add_to_tree, set_class,
		     create_arc, add_link, set_type, add_continuation,
		     delete_node, remove_from_tree, unset_class,
		     delete_arc, remove_link, unset_type, remove_continuation,
		     find_parent, get_child_list_pointer, get_class, find_ends,
		     find_prev,
		     get_in_list_pointer, get_out_list_pointer, get_type,
		     get_next_list_pointer, get_string_and_next_ptr,
		     add_curve, remove_curve, find_curve,
		     add_bbox, remove_bbox, find_bbox,
		     add_iext, remove_iext, find_iext,
		     add_capt_off, remove_capt_off, find_capt_off,
		     add_centre, remove_centre, find_centre,
		     set_hidden, is_hidden]).

foreign(empty_tree, empty_tree).

foreign(create_node, create_node(+string)). 
foreign(add_to_tree, add_to_tree(+string, +string)). 
foreign(set_class, set_class(+string, +atom)). 

foreign(create_arc, create_arc(+string)). 
foreign(add_link, add_link(+string, +string, +string)). 
foreign(set_type, set_type(+string, +atom)). 
foreign(add_continuation, add_continuation(+string, +string)).

foreign(delete_node, delete_node(+string)). 
foreign(remove_from_tree, remove_from_tree(+string, +string)). 
foreign(unset_class, unset_class(+string, +atom)). 

foreign(delete_arc, delete_arc(+string)). 
foreign(remove_link, remove_link(+string, +string, +string)). 
foreign(unset_type, unset_type(+string, +atom)). 
foreign(remove_continuation, remove_continuation(+string, +string)).

foreign(find_parent, find_parent(+string, -string)).
foreign(get_child_list_pointer, get_child_list_pointer(+string, -integer)).
foreign(get_class, get_class(+string, -atom)). 
foreign(find_ends, find_ends(+string, -string, -string)).
foreign(find_prev, find_prev(+string, -string)).

foreign(get_in_list_pointer, get_in_list_pointer(+string, -integer)).
foreign(get_out_list_pointer, get_out_list_pointer(+string, -integer)).
foreign(get_next_list_pointer, get_next_list_pointer(+string, -integer)).
foreign(get_type, get_type(+string, -atom)).
foreign(get_string_and_next_ptr,
	get_string_and_next_ptr(+integer, -string, -integer)).

foreign(add_curve, add_curve(+string, +integer, +integer)).
foreign(remove_curve, remove_curve(+string)).
foreign(find_curve, find_curve(+string, -integer, -integer)).
foreign(add_bbox, add_bbox(+string, +integer, +integer, +integer, +integer)).
foreign(remove_bbox, remove_bbox(+string)).
foreign(find_bbox, find_bbox(+string, -integer, -integer, -integer, -integer)).
foreign(add_iext, add_iext(+string, +integer, +integer, +integer, +integer)).
foreign(remove_iext, remove_iext(+string)).
foreign(find_iext, find_iext(+string, -integer, -integer, -integer, -integer)).
foreign(add_capt_off, add_capt_off(+string, +integer, +integer)).
foreign(remove_capt_off, remove_capt_off(+string)).
foreign(find_capt_off, find_capt_off(+string, -integer, -integer)).
foreign(add_centre, add_centre(+string, +integer, +integer)).
foreign(remove_centre, remove_centre(+string)).
foreign(find_centre, find_centre(+string, -integer, -integer)).
foreign(set_hidden, set_hidden(+string, +integer)).
foreign(is_hidden, is_hidden(+string)).
