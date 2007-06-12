/*           DATABASE.PL
             ===========

This module contains the actual statements making up the run-time database,
and special versions of assert, retract and retractall which are used to
modify this database and also create a short term record of what it done to
it, which is used to keep a log for undo/redo functions and for restoring
after a crash (which, of course, is always someone else's fault!)

Jasper Taylor, 15/3/98
*/

sicstus_module(database, [
	/* manipulation routines */
			  my_assert/1, my_retract/1,
			  assert_model/1, retract_model/1, retractall_model/1,
			  query_model/1, anything_done/0, fetch_update/1,
			  empty_tree/0,
	/* for link */
		is_arc/1, connection/3, arc_type/2, arc_info/3, continues/2,
	/* for m_struct */
		is_node/1, subsystem/2,
	/* for node */
		node_class/2, node_refinement/3, node_attribute/3,
	/* for graphics */
		graphical_info/3]).

sicstus_use_module([library(lists), sp_only, utility, output]).

:- dynamic(is_arc/1). 
:- dynamic(connection/3).
:- dynamic(arc_type/2).
:- dynamic(arc_info/3).
:- dynamic(continues/2).
		
:- dynamic(is_node/1). 
:- dynamic(subsystem/2). 
		
:- dynamic(node_class/2). 
:- dynamic(node_refinement/3).
:- dynamic(node_attribute/3).
		
:- dynamic(graphical_info/3).
		
:- op(500, xfy, [of, from, to]).

clear_database :-
	clear_model([
	/* for link */
		connection/3, arc_type/2, arc_info/3, continues/2,
	/* for m_struct */
		is_node/1, subsystem/2,
	/* for node */
		node_class/2, node_refinement/3, node_attribute/3,
	/* for graphics */
		graphical_info/3]).

clear_model([]).

clear_model([Funt/Args | Rest]) :-
	length(ArgList, Args),
	Template =.. [Funt | ArgList],
	retractall(Template),
	clear_model(Rest).

%empty_tree.
/* Stuff needed for c database  */
sicstus_load_foreign_resource(struct_db).

:- foreign(empty_tree).

assert_model(P) :-
	my_assert(P),
	(retract(update_remove(P)), !;
	assert(update_add(P))).

my_assert(P) :-
%	assert(P).
%	tcl_assert(P).
	c_assert(P).
	
tcl_assert(P) :-
	P =.. [Funt | Args],
	all(database, pack_term, [build(Args), build(FixArgs)]),
	safe_tcl_eval(['PrologAssert', Funt | FixArgs], _), fail; true.

:- foreign(create_node(+string)). 
:- foreign(add_to_tree(+string, +string)). 
:- foreign(set_class(+string, +atom)). 
:- foreign(create_arc(+string)). 
:- foreign(add_link(+string, +string, +string)). 
:- foreign(set_type(+string, +atom)). 
:- foreign(add_continuation(+string, +string)).
:- foreign(add_curve(+string, +integer, +integer)).
:- foreign(add_bbox(+string, +integer, +integer, +integer, +integer)).
:- foreign(add_iext(+string, +integer, +integer, +integer, +integer)).
:- foreign(add_capt_off(+string, +integer, +integer)).
:- foreign(add_centre(+string, +integer, +integer)).
:- foreign(set_hidden(+string, +integer)).
c_assert(P) :-
%	safe_tcl_eval([puts, br(write(assert(P)))], _),
	P = is_node(Node), !,
	create_node(Node);
	P = subsystem(Parent, Child), !,
	add_to_tree(Parent, Child);
	P = node_class(Node, Class), !,
	set_class(Node, Class);
	P = is_arc(Node), !,
	create_arc(Node);
	P = connection(Dest, Source, Arc), !,
	add_link(Dest, Source, Arc);
	P = arc_type(Arc, Type), !,
	set_type(Arc, Type);
	P = continues(Arc1, Arc2), !,
	add_continuation(Arc1, Arc2);
	P = graphical_info(Obj, GAttr, Pts), !,
	(GAttr = bounding_box,
	    Pts = [L,T,R,B],
	    add_bbox(Obj, L, T, R, B);
	 GAttr = curve,
	    Pts = [XK, YB],
	    add_curve(Obj, XK, YB);
	 GAttr = internal_extent,
	    Pts = [L,T,R,B],
	    add_iext(Obj, L, T, R, B);
	 GAttr = caption_offset,
	    Pts = [OX,OY],
	    add_capt_off(Obj, OX, OY);
	 GAttr = centre,
	    Pts = [CX, CY],
	    add_centre(Obj, CX, CY);
	 GAttr = hide_contents,
	    (\+ Pts = 1, !; set_hidden(Obj, 1)));
%	 safe_tcl_eval([puts, br(write(failed_assert(P)))], _)), !;
	assert(P).

retract_model(P) :-
	my_retract(P),
	retract_from_current(P).

my_retract(P) :-
%	retract(P).
%	tcl_retract(P).
	c_retract(P).

tcl_retract(P) :-
	tcl_call(P, Funt, MatchStr),
	safe_tcl_eval(['PrologRetract', Funt, chars(MatchStr)], _).

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
c_retract(P) :-
%	safe_tcl_eval([puts, br(write(retract(P)))], _),
	P = is_node(Node), !,
	delete_node(Node);
	P = subsystem(Parent, Child), !,
	remove_from_tree(Parent, Child);
	P = node_class(Node, Class), !,
	c_call(P),
	unset_class(Node, Class);
	P = is_arc(Node), !,
	delete_arc(Node);
	P = connection(Dest, Source, Arc), !,
	c_call(P),
	remove_link(Dest, Source, Arc);
	P = arc_type(Arc,Type), !,
	c_call(P),
	unset_type(Arc,Type);
	P = continues(Arc1, Arc2), !,
	c_call(P),
	remove_continuation(Arc1, Arc2);
	P = graphical_info(Obj, GAttr, _Pts), !,
	    c_call(P),
	    (GAttr = curve,
		remove_curve(Obj);
	    GAttr = bounding_box,
		remove_bbox(Obj);
	    GAttr = internal_extent,
		remove_iext(Obj);
	    GAttr = caption_offset,
		remove_capt_off(Obj);
	    GAttr = centre,
		remove_centre(Obj);
	    GAttr = hide_contents,
		set_hidden(Obj, 0));
	retract(P).

retract_from_current(P) :-
	(retract(update_add(P)), !;
	assert(update_remove(P))).

retractall_model(P) :-
	retract_model(P),
		fail;
	true.

query_model(P) :-
%	call(P).
%	tcl_call(P, _Funt, _Strs).
	c_call(P).

tcl_call(P, Funt, MatchStr) :-
	P =.. [Funt | Args],
	all(database, pack_term, [build(Args), build(FixArgs)]),
	safe_tcl_eval(['PrologQuery', Funt | FixArgs], Str),
	output:chop_list(Str, MatchStrs),
	member(MatchStr, MatchStrs),
	output:chop_list(MatchStr, ArgStrs),
	all(database, unpack_term, [build(ArgStrs), build(InstArgs)]),
	Args = InstArgs.

:- foreign(find_parent(+string, -string)).
:- foreign(get_child_list_pointer(+string, -integer)).
:- foreign(get_class(+string, -atom)). 
:- foreign(find_ends(+string, -string, -string)). 
:- foreign(get_in_list_pointer(+string, -integer)).
:- foreign(get_out_list_pointer(+string, -integer)).
:- foreign(get_type(+string, -atom)).
:- foreign(find_prev(+string, -string)).
:- foreign(get_next_list_pointer(+string, -integer)).
:- foreign(find_curve(+string, -integer, -integer)).
:- foreign(find_bbox(+string, -integer, -integer, -integer, -integer)).
:- foreign(find_iext(+string, -integer, -integer, -integer, -integer)).
:- foreign(find_capt_off(+string, -integer, -integer)).
:- foreign(find_centre(+string, -integer, -integer)).
:- foreign(is_hidden(+string)).
:- foreign(get_string_and_next_ptr(+integer, -string, -integer)).
c_call(P) :-
%	safe_tcl_eval([puts, br(write(call(P)))], _),
	(P = subsystem(Parent, Child), !,
	(var(Child), !,
	    (var(Parent), !,
	    	find_all_children(Parent, Child);
	    find_child(Parent, Child));
	find_parent(Child, Parent));
	P = node_class(Node, Class), !,
	(atom(Node), !;
	    var(Node), descendent(root, Node)),
	get_class(Node, Class);
	P = connection(Dest, Source, Arc), !,
	(nonvar(Arc), !;
	    (var(Source), !,
		atom(Dest),
		find_arc_to(Dest, Arc);
	    atom(Source),
		find_arc_from(Source, Arc))),
	find_ends(Arc, Source, Dest);
	P = arc_type(Arc, Type), !,
	atom(Arc),
	get_type(Arc, Type);
	P = continues(Arc1, Arc2), !,
	(var(Arc2), !,
	    find_next(Arc1, Arc2);
	find_prev(Arc2, Arc1));
	P = graphical_info(Obj, GAttr, Pts), !,
	    (GAttr = curve,
		find_curve(Obj, XK, YB),
		Pts = [XK, YB];
	    GAttr = bounding_box,
		find_bbox(Obj, L, T, R, B),
		Pts = [L,T,R,B];
	    GAttr = internal_extent,
		find_iext(Obj, L, T, R, B),
		Pts = [L,T,R,B];
	    GAttr = caption_offset,
		find_capt_off(Obj, OX, OY),
		Pts = [OX, OY];
	    GAttr = centre,
		find_centre(Obj, CX, CY),
		Pts = [CX, CY];
	    GAttr = hide_contents,
		is_hidden(Obj),
		Pts = 1);
	call(P)).
%	safe_tcl_eval([puts, br(write(return(P)))], _).

find_all_children(Parent, Child) :-
	descendent(root, Child),
	find_parent(Child, Parent).

descendent(Node, Desc) :-
	Desc = Node;
	find_child(Node, Child),
	descendent(Child, Desc).

find_child(Parent, Child) :-
	get_child_list_pointer(Parent, Ptr),
	comps_from_pointer(Ptr, Child).

find_arc_to(Dest, Arc) :-
	get_in_list_pointer(Dest, Ptr),
	comps_from_pointer(Ptr, Arc).

find_arc_from(Dest, Arc) :-
	get_out_list_pointer(Dest, Ptr),
	comps_from_pointer(Ptr, Arc).

find_next(PrevArc, SubsArc) :-
	get_next_list_pointer(PrevArc, Ptr),
	comps_from_pointer(Ptr, SubsArc).
	
comps_from_pointer(Ptr, Comp) :-
	\+ Ptr = 0, % or whatever a NULL translates to
	get_string_and_next_ptr(Ptr, First, NxtPtr),
	(Comp = First; comps_from_pointer(NxtPtr, Comp)).

pack_term(Term, br(chars(Str))) :-
	\+ ground(Term), !,
	    Str = "*";
	atomic(Term), !,
	    name(Term, AtmStr),
	    Str = [46 | AtmStr];
	sicstus_writeq_to_chars(Term, Str).

unpack_term(Str, Term) :-
	Str = [46 | AtmStr], !,
	    name(Term, AtmStr);
	append(Str, ".", FussyStr),
	    sicstus_read_from_chars(FussyStr, Term).

:- dynamic(update_remove/1).
:- dynamic(update_add/1).

anything_done :-
	update_remove(P);
	update_add(P).

fetch_update(DP) :-
	retract(update_remove(P)),
		DP = remove(P);
	retract(update_add(P)),
		DP = add(P).
