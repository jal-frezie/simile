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
		assert_model/1, retract_model/1, retractall_model/1, fetch_update/1,
	/* for link */
		connection/3, arc_type/2, arc_info/3,
	/* for m_struct */
		subsystem/2,
	/* for node */
		node_class/2, node_refinement/3, node_attribute/3,
	/* for class */
		declared_class/1, attribute/3,
	/* for graphics */
		graphical_info/3,
	/* for utility */
		genint/2]).

:- dynamic(connection/3).
:- dynamic(arc_type/2).
:- dynamic(arc_info/3).
		
:- dynamic(subsystem/2). 
		
:- dynamic(node_class/2). 
:- dynamic(node_refinement/3).
:- dynamic(node_attribute/3).
		
:- dynamic(declared_class/1).
:- dynamic(attribute/3).
		
:- dynamic(graphical_info/3).
		
:- dynamic(genint/2).

:- op(500, xfy, [of, from, to]).

clear_database :-
	clear_model([
	/* for link */
		connection/3, arc_type/2, arc_info/3,
	/* for m_struct */
		subsystem/2,
	/* for node */
		node_class/2, node_refinement/3, node_attribute/3,
	/* for class */
		declared_class/1, attribute/3,
	/* for graphics */
		graphical_info/3,
	/* for utility */
		genint/2]).

clear_model([]).

clear_model([Funt/Args | Rest]) :-
	length(ArgList, Args),
	Template =.. [Funt | ArgList],
	retractall(Template),
	clear_model(Rest).

assert_model(P) :-
	assert(P),
	(retract(update_remove(P)), !;
	assert(update_add(P))).

retract_model(P) :-
	retract(P),
	retract_from_current(P).

retract_from_current(P) :-
	(retract(update_add(P)), !;
	assert(update_remove(P))).

retractall_model(P) :-
	retract_model(P),
		fail;
	true.

fetch_update(DP) :-
	retract(update_remove(P)),
		DP = remove(P);
	retract(update_add(P)),
		DP = add(P).
