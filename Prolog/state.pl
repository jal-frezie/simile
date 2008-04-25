/*
gui_state.pl
- - - - - - -
This module contains the information relating to the current state of the user's 
interaction with the application, and provides predicates to make this info 
available to the other modules that use it.
*/

sicstus_module(state,
	       [kickoff/1, get_initial_window_size/2,
		create_window/2, destroy_window/1, clear_model_file/1,
		set_model_file/2, get_model_file/2, get_edition_and_limit/2,
		kill_windows/0, set_halo/3, get_halo/2,
		shows_model/2, monitors_variable/2, depth_list_is/1,
		set_display_depth/3, get_display_depth/3, set_current_depth/1,
		get_current_depth/1, suspend_display/0, make_current/1,
		find_current/1, get_original_click/2, set_original_click/2,
		get_start_coords/2, set_start_coords/2, get_current_coords/2,
		set_current_coords/2, get_border_offsets/4, set_border_offsets/4,
		get_mode/1, set_mode/1, get_current_node/1, set_current_node/1,
		get_running_model/1, set_running_model/1, get_box_size/3,
		get_text_offset/4, set_box_size/5, get_adding_object/1,
		set_adding_object/1, set_highlit_obj/2, get_highlit_obj/2,
		forget_highlit_obj/2, initialize_phase/0, advance_phase_to/1,
		get_phase/1, get_line_start_obj/1, set_moving_obj/1, get_moving_obj/1,
		set_line_start_obj/1, get_line_finish_obj/1, set_line_finish_obj/1,
		get_translation/1, set_translation/1, clear_incomplete/0,
		add_incomplete/1, get_incomplete/1,
		change_style/1, get_style/1]).

sicstus_use_module(library(lists)).

kickoff(Vnum) :-
	user:any_tcl_eval(['ControlDraw', br(Vnum)], 1, EnvVars),
	output:chop_list(EnvVars, [VStr, TempStr, OpenStr, EStr]),
	retractall(version_is(_)),
	assert(version_is(VStr)),
	name(E, EStr),
	set_edition(E),

	name(TempDir, TempStr),
	backup:retractall(use_temp_dir(_)),
	backup:assert(use_temp_dir(TempDir)),

	set_mode(none),
	inters:read_library_funx(LibFuns),
	dialogue:pass_functions(LibFuns),
	menu:update_mode(select),
	m_update:make_desktop(Desktop, Canvas),
	initialize_phase,

	(OpenStr = [];
	append(Base, ".smx", OpenStr);
	name(OpenModel, OpenStr),
	    menu:stick_model_in(Canvas, Desktop, OpenModel, reopen);
	true), !,
	user:any_tcl_eval(['FixSize', Canvas], 1, _),
	(var(Base), !;
        append(Base, ".sml", OpenFiloidStr),
	    name(OpenModel, OpenFiloidStr),
	    backup:check_autosave(Desktop, OpenModel, copy, Done),
	    (Done = 0;
	     draw:redraw_window(Canvas))).

:- dynamic(model_in/2).
:- dynamic(model_file/2).

get_initial_window_size(800, 480).

create_window(New_win, Model) :-
	destroy_window(New_win),
	assertz(model_in(New_win, Model)).

destroy_window(Dead_win) :-
	retractall(model_in(Dead_win, _)).

clear_model_file(Model) :-
	retractall(model_file(Model, _)).

set_model_file(Model, File) :-
	clear_model_file(Model),
	assertz(model_file(Model, File)).

get_model_file(Model, File) :-
	model_file(Model, File).

:- dynamic(edition_is/1).

get_edition_and_limit(Ed, Limit) :-
	edition_is(Ed),
	member(Ed-Limit, [evaluation-25, teaching-50]).

set_edition(New_depth) :-
	assertz(edition_is(New_depth)).

:- dynamic(suspend_display/0).

/* depth_list_is: each sublist contains a group of display entities that are
displayed down to the same level, with the first one used to label the
display depth variable */

depth_list_is([[submodel, relation],
	       [compartment, state], 
	       [flow, cloud],
	       [variable, function, channel],
	       [influence],
	       [ghost_link]]).

kill_windows :-
	retractall(model_in(_, _)).

:- op(500, xfy, shows_model).

Win shows_model Model :-
	model_in(Win, Model).

:- dynamic(display_depth/3).

set_display_depth(Model, Parameter, Stat) :-

	/* first bit makes sure that we display everything more important than
	things we put on, and nothing less important than things we put off
	
	depth_list_is(List),
	append(MoreImp, [[Parameter | _] | LessImp], List),
	(member([ImpType | _], MoreImp),
	    get_display_depth(Model, ImpType, ImpDepth),
	    ImpDepth < Stat;
	member([ImpType | _], LessImp),
	    get_display_depth(Model, ImpType, ImpDepth),
	    ImpDepth > Stat),
	retractall(display_depth(Model, ImpType, _)),
	assertz(display_depth(Model, ImpType, Stat)),
	fail; */
	
	retractall(display_depth(Model, Parameter, _)),
	assertz(display_depth(Model, Parameter, Stat)).

get_display_depth(Model, Parameter, Stat) :-
	display_depth(Model, Parameter, Stat).

:- dynamic(halo_is/2).

halo_is(back, 0).
halo_is(fwd, 0).

set_halo(_Win, Way, Depth) :-
	retractall(halo_is(Way, _)),
	assertz(halo_is(Way, Depth)).

get_halo(Way, Depth) :-
	halo_is(Way, Depth).

:- dynamic(current_depth_is/1).

get_current_depth(Cur_depth) :-
	current_depth_is(Cur_depth).

set_current_depth(New_depth) :-
	retractall(current_depth_is(_)),
	assertz(current_depth_is(New_depth)).

:- dynamic(current_window_is/1).

make_current(Cur_win) :-
	retractall(current_window_is(_)),
	assertz(current_window_is(Cur_win)).

find_current(Win) :-
	current_window_is(Win).

:- dynamic(original_click_are/2).

get_original_click(Cur_X, Cur_Y) :-
	original_click_are(Cur_X, Cur_Y).

set_original_click(Cur_X, Cur_Y) :-
	retractall(original_click_are(_, _)),
	assertz(original_click_are(Cur_X, Cur_Y)).

:- dynamic(start_coords_are/2).

get_start_coords(Cur_X, Cur_Y) :-
	start_coords_are(Cur_X, Cur_Y).

set_start_coords(Cur_X, Cur_Y) :-
	retractall(start_coords_are(_, _)),
	assertz(start_coords_are(Cur_X, Cur_Y)).

:- dynamic(current_coords_are/2).

get_current_coords(Cur_X, Cur_Y) :-
	current_coords_are(Cur_X, Cur_Y).

set_current_coords(Cur_X, Cur_Y) :-
	retractall(current_coords_are(_, _)),
	assertz(current_coords_are(Cur_X, Cur_Y)).

:- dynamic(border_offsets_are/4).

get_border_offsets(L,T,R,B) :-
	border_offsets_are(L,T,R,B).

set_border_offsets(L,T,R,B) :-
	retractall(border_offsets_are(_, _, _, _)),
	assertz(border_offsets_are(L,T,R,B)).

:- dynamic(box_size_is/5).

/* note assymetry -- its easier to get size for local submodel but to set it
for top level model */

get_box_size(Parent, Box_type, Cur_box_size) :-
	ame_gen:contains(Top, Parent),
	backup:is_toplevel(Top),
	box_size_is(Top, Box_type, Abs_box_size,_,_),
	(member(Box_type-Scale, [compartment-0.6, state-0.8,
				 function-0.3, variable-0.3,
				cloud-0.5, channel-0.6]), !,

	    Cur_box_size is Scale*Abs_box_size;
	Cur_box_size = Abs_box_size).

get_text_offset(TopNode, Box_type, XDefOffset, YDefOffset) :-
	box_size_is(TopNode, Box_type, _, XDefOffset, YDefOffset).

set_box_size(TopNode, Box_type, New_box_size, XDefOffset, YDefOffset) :-
	retractall(box_size_is(TopNode, Box_type, _,_,_)),
	assertz(box_size_is(TopNode, Box_type, New_box_size,
			    XDefOffset, YDefOffset)).

:- dynamic(current_node_is/1).

get_current_node(Cur_mode) :-
	current_node_is(Cur_mode).

set_current_node(New_mode) :-
	retractall(current_node_is(_)),
	assertz(current_node_is(New_mode)).

:- dynamic(running_model_is/1).

get_running_model(Cur_mode) :-
	running_model_is(Cur_mode).

set_running_model(New_mode) :-
	retractall(running_model_is(_)),
	assertz(running_model_is(New_mode)).

:- dynamic(mode_is/1).

get_mode(Cur_mode) :-
	mode_is(Cur_mode).

set_mode(New_mode) :-
	retractall(mode_is(_)),
	assertz(mode_is(New_mode)).

:- dynamic(adding_object_is/1).

get_adding_object(Cur_obj) :-
	adding_object_is(Cur_obj).

/* set_adding_object: the kind of object we are adding to the system. This will fail if called in a mode other than add mode. 
*/
set_adding_object(New_obj) :-
	retractall(adding_object_is(_)),
	assertz(adding_object_is(New_obj)).

:- dynamic(lit_obj_is/2).

get_highlit_obj(N, Obj) :-
	lit_obj_is(N, Obj).

/* Note that many objects can be highlit at once...*/
set_highlit_obj(N, Obj) :-
	forget_highlit_obj(_, Obj),
	assertz(lit_obj_is(N, Obj)).

forget_highlit_obj(N, Obj) :-
	retractall(lit_obj_is(N, Obj)).

/* Initialize_phase: some edit functions allow the user to go through a series of states; this sets the state to the appropriate 'first state' for whatever function the user has selected */

:- dynamic(phase_is/1).

initialize_phase :-
	retractall(phase_is(_)),
	assertz(phase_is(peruse)).

/* advance_phase_to/1: This has a representation of the allowable transitions in the form of a list of pairs, each containing a phase name and a list of the names of those phases (other than the initial state 'peruse') which can come after it. */

advance_phase_to(New_phase) :-
	State_machine = 
		[[peruse, [rubberband, moving, moving_border(D), action_choice,
			   moving_start, moving_finish, moving_spline,
			   moving_bowtie, moving_kink, equiv_hunt, barge]],
		 [action_choice, [dragging, targetting]],
		 [targetting, [dragging, peruse]],
		 [set_line_direction, [extend_line]],
		 [equiv_hunt, [find_equivalent]],
		 [moving, [moving_border(D), moving_text]],
		 [moving_kink, [moving_text]],
		 [moving_spline, [moving_text]],
		 [moving_bowtie, [moving_text]],
		 [moving_border(D), [moving_text]],
		 [rubberband, [moving_text]],
		 [find_equivalent, [barge]]],
	phase_is(Old_phase),
	member([Old_phase, Allowables], State_machine),
	(member(New_phase, Allowables), !,
		retract(phase_is(Old_phase)),
		assertz(phase_is(New_phase));
	output:safe_tcl_eval([puts, dq(['Attempted illegal phase change from',
			      Old_phase, 'to', New_phase])], _)).
get_phase(Phase) :-
	phase_is(Phase).

:- dynamic(line_start_obj_is/1).

set_line_start_obj(O) :-
	retractall(line_start_obj_is(_)),
	assertz(line_start_obj_is(O)).

get_line_start_obj(O) :-
	line_start_obj_is(O).

:- dynamic(moving_obj_is/1).

set_moving_obj(O) :-
	retractall(moving_obj_is(_)),
	assertz(moving_obj_is(O)).

get_moving_obj(O) :-
	moving_obj_is(O).

:- dynamic(line_finish_obj_is/1).

set_line_finish_obj(O) :-
	retractall(line_finish_obj_is(_)),
	assertz(line_finish_obj_is(O)).

get_line_finish_obj(O) :-
	line_finish_obj_is(O).

:- dynamic(translation_is/1).

set_translation(T) :-
	retractall(translation_is(_)),
	assertz(translation_is(T)).

get_translation(T) :-
	translation_is(T).

/* add_incomplete/1 etc: The incomplete line must be displayed in the
current window even if it is not yet added to the model
representation, therefore this is the place to store it. */

:- dynamic(incomplete/1).

clear_incomplete :-
	retractall(incomplete(_)).

add_incomplete(Coord_list) :-
	assertz(incomplete(Coord_list)).

get_incomplete(Coord_list) :-
	incomplete(Coord_list).

:- dynamic(style_is/1).

change_style(Style) :-
	retractall(style_is(_)),
	assert(style_is(Style)).

get_style(Style) :-
	style_is(SavedStyle), !,
		Style = SavedStyle;
	Style = sd.

/* Set editing state to initial default... */
set_initial_box_sizes(TopNode) :-
	retractall(box_size_is(TopNode, _,_,_,_)),
	assert(box_size_is(TopNode, compartment, 50, 0, 0)),
	assert(box_size_is(TopNode, state, 50, 0, 0)),
	assert(box_size_is(TopNode, function, 50, 0, 0)),
	assert(box_size_is(TopNode, variable, 50, 0, 0)),
	assert(box_size_is(TopNode, cloud, 50, 0, 0)),
	assert(box_size_is(TopNode, submodel, 50, 0, 0)),
	assert(box_size_is(TopNode, channel, 50, 0, 0)),
	assert(box_size_is(TopNode, flow, 50, 0, 0)),
	assert(box_size_is(TopNode, influence, 50, 0, 0)),
	assert(box_size_is(TopNode, ghost_link, 50, 0, 0)),
	assert(box_size_is(TopNode, relation, 50, 0, 0)).

