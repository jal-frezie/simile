/*
event_handle.pl
---------------
This contains the code for responding to events signalled by the user 
interface of the application. It responds by:
* Querying and updating the GUI state representation
* Calling the model maintenance module to add information to the model
* Making calls to the screen drawing module (new image, or redraw)
*/
sicstus_module(event, [get_info/3, get_params/2, bar_edit_menu/1,
		       click_obj/4, click_text/4, click/3, do_colours/2,
		       insert_variable/5,
	finish_old_edit/1, doubleclick_obj/3, doubleclick/2,
	unclick/0, embrace/2, abandon/0, abandon_eqn/0, drag/2,
		       resize_top_win/3, adjust_display_area/2,
		       prioritize_window/1, run_settings_tweaked/1]).

sicstus_use_module([sp_only, dialogue, m_update, image, draw,
		    state, backup, submodel, ame_gen, utility,
		    library(lists), library(ordsets)]).

eqn_for(Comp, EqnStr) :-
	find_node_with_data(Comp, _, Func),
	(get_av_pair(Func, 0, spec, Eqn), atom(Eqn), \+ Eqn = [], !,
	    name(Eqn, EqnStr);
	 get_av_pair(Func, 0, value, Eqn),
	    sicstus_write_to_chars(Eqn, EqnStr)).

units_for(Comp, UnitStr) :-
	find_node_with_data(Comp, _, Func),
	get_av_pair(Func, 0, units, Units),
	analyze_array(Units, Base, _D),
	(Base = 1, !, UnitStr = "real";
	sicstus_write_to_chars(Base, UnitStr)).

get_info(_Wid, Comp, eqn) :-
	(Comp is_of_sort has_function,
	    (eqn_for(Comp, Eqn), !;
		Eqn = "");
	 Eqn = "<none>"),
	callback(br(chars(Eqn))).

get_info(Wid, Comp, desc) :-
	find_type(Comp, LType),
	(LType is_class_of_sort captionless, !,
	    Part1 = "";
	caption_for(Comp, Capt),
	    name(Capt, CaptStr),
	    append(CaptStr, " : ", Part1)),

	(LType = submodel,
	    image:quick_file(Comp, Middle);
	eqn_for(Comp, Middle);
	ghost_link(Comp, _,_),
	    Middle = "ghost link";
	name(LType, Middle)), !,

	(Wid shows_model Context,
	    setof(DestLoc, Dest^(m_update:connects(Comp, Source, Dest),
				 abs_path_name(Dest, Context, DestLoc)),
		  DestList),
	    (DestList = [Dests]; Dests = DestList), !,
	    /* note Source is an ordinary variable in the above, all dests will
	    be found because it is always the same */
	    abs_path_name(Source, Context, SourceLoc),
	    sicstus_format_to_chars(" (from ~a to ~w)", [SourceLoc, Dests], 
	        Suffix);
	units_for(Comp, Units), !,
	    append([" (", Units, ")"], Suffix);
	Suffix = ""),

	append([Part1, Middle, Suffix], Desc),
	callback(br(chars(Desc))).

get_info(_, Comp, comment) :-
	(find_type(Comp, relation), !,
	    find_name_host(Comp, Func);
	find_node_with_data(Comp, _, Func)),
	(get_av_pair(Func, _, comment, Cmt), !;
	Cmt = 'no comment'),
	(get_av_pair(Func, _, description, Desc),
	    sicstus_format_to_chars("~w\n~w", [Desc, Cmt], PopStr),
	    name(Pop, PopStr), !;
	Pop = Cmt),
	callback(br(write(Pop))).

get_info(_, Name, is_unit) :-
	(units:defined_as_unit(Name, Def), !;
	Def = none),
	callback(write(Def)).

insert_mem_list(Bound, Model, Trans) :-
	(Bound = boolean,
	    Trans = [false, true];
	get_av_pair(Model, 0, enum_types, Pairs),
	    member(Type-Mems, Pairs),
	    append_atoms(['"', Type, '"'], QType),
	    member(Bound, [QType, a(QType)]), /* allow units to make trans */
	    Trans = [Type | Mems];
	find_all_comps(Parent, Model),
	    insert_mem_list(Bound, Parent, Trans);
	Trans = []), !.

get_params(_, Comp) :-
	find_node_with_data(Comp, _, Func),
	get_input_info(Func, Params),
	output:get_from_list(Params, Table),
	output:bracketize(Table, BrTable),
	callback(BrTable).

:- dynamic(min_size_is/1).
:- dynamic(max_size_is/1).
:- dynamic(clicked_obj_is/1).

click_obj(Xpt, Ypt, Name, CD) :-
	check_snap,
	assert(clicked_obj_is(Name)),
	find_current(Wid),
	find_relevant_windows(Name, Wid, Depth, Trans),
	translate([Xpt, Ypt], Trans, ActNewPt),
	snap_to_grid(ActNewPt, [NewXpt, NewYpt]),
	set_original_click(Xpt, Ypt),
	find_all_comps(Parent, Name),
	save_params(Trans, Depth, Parent),
	(get_phase(targetting),
	    check_same_desktop(Parent), !,
	    advance_phase_to(dragging),
	    drag_to(NewXpt, NewYpt, Name);
	(CD < 2, click_on([NewXpt, NewYpt], Name, CD), !; true),
	adjust_edit_menu(Wid, Parent, Name),
	(get_phase(moving),
	    /* highlight(Name, 2), */
	    find_type(Name, submodel), !,
	    set_selection_abilities(Parent),
	    get_closest_edge(Name, [NewXpt, NewYpt], Edge),
	    advance_phase_to(moving_border(Edge)) /* ,
	    retractall(min_size_is(_)),
	    (get_inner_bound(Name, Edge, CompBound), !,
		assert(min_size_is(CompBound));
	    true),
	    retractall(max_size_is(_)),
	    get_outer_bound(Name, Parent, Edge, CompSpace),
	    assert(max_size_is(CompSpace)) */ ;
	true)).

click_text(Xpt, Ypt, Name, CD) :-
	get_mode(select),
	    CD = 0,
	    doomed(Name), !,
	    finish_old_edit(Name),
	    give_focus(Name);
	click_obj(Xpt, Ypt, Name, CD),
	/* we do not want the text of a text item to get separated from its
	anchor so do not allow a caption move, just move the whole thing */
	    (find_type(Name, text);
		(get_phase(moving); get_phase(moving_border(_))),
		advance_phase_to(moving_text)).
/*
click: Handles mouse clicks in a model window.
*/
click(Xpt, Ypt, CD) :-
	check_snap,
	find_current(Wid),
	Wid shows_model Parent,
	save_params([0,0,1,1], 0, Parent),
	(get_phase(targetting),
	    check_same_desktop(Parent), !,
	    advance_phase_to(dragging),
	    drag(Xpt, Ypt);
	get_phase(peruse),
	    set_original_click(Xpt, Ypt),
	    click_in(Wid, [Xpt, Ypt], [0, 0, 1, 1], 0, Parent, CD)).

/* check we are in same model we started in */
check_same_desktop(Parent) :-
	get_line_start_obj(StartNode),
	    contains(Top, StartNode),
	    is_toplevel(Top),
	    contains(Top, Parent);
	normalize(StartNode),
	    advance_phase_to(peruse),
	    fail.

save_params(Trans, Depth, Parent) :-
	set_translation(Trans),
	set_current_depth(Depth),
	set_current_node(Parent).

click_on_sub(Wid, _, Trans, Parent, Depth, Comp, CD) :-
	save_params(Trans, Depth, Parent),
	find_type(Comp, submodel), !,
	add_to_translation(Trans, Comp, New_trans),
	New_depth is Depth + 1,
	get_original_click(Orig_X, Orig_Y),
	translate([Orig_X, Orig_Y], New_trans, New_point),
	click_in(Wid, New_point, New_trans, New_depth, Comp, CD).

/* This allows a 'click' call from Tk to connect to a component. Try doing without
it as clicking on a component should always generate a 'click_obj' call.

click_on_sub(_, Point, _, _, _, Comp) :-
	click_on(Point, Comp).

This starts addition. Last clause creates a new cloud when starting a flow in the
middle of nowhere; i could also do variables for influences. */
:- dynamic(menu_submodel_is/2).
:- dynamic(menu_submodel_will_be/3).
:- dynamic(grid_pitch_is/1).

check_snap :-
	retractall(grid_pitch_is(_)),
	(tk_get_pref(gridSnap, 0), !;
	    assert(grid_pitch_is(15))).
	
snap_to_grid([], []).

snap_to_grid([X, Y | Rest], [GX, GY | GRest]) :-
	grid_pitch_is(Pitch), !,
	    GX is Pitch*round(X/Pitch),
	    GY is Pitch*round(Y/Pitch),
	    snap_to_grid(Rest, GRest);
	 [GX, GY | GRest] = [X, Y | Rest].

snap_to_grid([Pair | Rest], [NewPair | NewRest]) :-
	snap_to_grid(Pair, NewPair),
	snap_to_grid(Rest, NewRest).


click_in(Wid, Point, Trans, Depth, Parent, CD) :-
	targets(Wid, Parent, Point, Depth, Child), !, 
	click_on_sub(Wid, Point, Trans, Parent, Depth, Child, CD);
	CD = 2,
	snap_to_grid(Point, GPoint),
	adjust_edit_menu(Wid, Parent, GPoint).

click_in(Wid, ActPt, Trans, Depth, Parent, _CD) :-
	finish_old_edit(none),
	get_mode(add),
	snap_to_grid(ActPt, [Xpt, Ypt]),
	set_start_coords(Xpt, Ypt),
	set_current_coords(Xpt, Ypt),
	save_params(Trans, Depth, Parent),
	get_adding_object(New_obj),
	(New_obj is_class_of_sort box, !,
	    (New_obj is_class_of_sort rounded_rect, !,
		Wid shows_model Top,
		contains(Top, Parent, Ladder),
		check_drawing_at_depth(Wid, Ladder, New_obj, Depth),
		advance_phase_to(rubberband);
	    insert(Wid, Parent, [Xpt, Ypt], New_obj));
	make_terminator(New_obj, Parent, DropNode),
	    (var(DropNode), !;
		do_linear(New_obj, DropNode))).

click_in(Wid, _,_,_, Parent, CD) :-
	/* get_mode(select), !,
	    set_start_coords(Xpt, Ypt),
	    save_params(Trans, Depth, Parent),
	    finish_old_edit(none),
	    give_focus('{}');   */
	get_translation(Old_trans),
	get_original_click(Orig_X, Orig_Y),
	translate([Orig_X, Orig_Y], Old_trans, ActOrig),
	snap_to_grid(ActOrig, [Xtr, Ytr]),
	
	/* Background of unselected submodel: select a region */
	(get_mode(select),
	    (Wid shows_model Parent; /* no drag submodel in own window */
		CD = 1; /* no drag if ctrl down */
		\+ get_highlit_obj(0, Parent)), !,
	    set_start_coords(Xtr, Ytr),
	    (CD = 0,
		new_selection(Parent);
	    add_incomplete([Xtr, Ytr, Xtr, Ytr]),
		draw_rubberband(square),
		advance_phase_to(rubberband));
	    
	click_on([Xtr, Ytr], Parent, CD)).

new_selection(Parent) :-
	contains(Top, Parent),
	is_toplevel(Top), !,
	contains(Top, Comp),
	normalize(Comp),
	fail.

insert(Wid, Parent, [Xpt, Ypt], New_obj) :-
	Wid shows_model Top,
	contains(Top, Parent, Ladder),
	length(Ladder, Depth),
	check_drawing_at_depth(Wid, Ladder, New_obj, Depth),
	add_at_point(Xpt, Ypt, New_obj, Parent, NewNode),
	redisplay(NewNode),
	give_focus(NewNode),
	do_colours(NewNode, on),
	select_text(Wid, NewNode),
	(setof(NewLook, presence_affects(NewNode, NewLook), NewLooks), !;
	    NewLooks = []),
	all(event, spread_colour, [build(NewLooks), unify(yes)]).

check_drawing_at_depth(Wid, Levels, New_obj, Depth) :-
	(\+ (member(Hider, Levels),
		get_shape(Hider, hide_contents, 1)),
	    use_style_for(New_obj, NewStyle),
	    draws_at(Wid, NewStyle, Depth), !;
	    do_dialogue("Failed to add component", warning,
			"Cowardly refusing to add a component where it will not currently be displayed!", ok, not)).
	    
adjust_edit_menu(Wid, Comp, Point) :-
	retractall(menu_submodel_will_be(Wid, _,_)),
	assert(menu_submodel_will_be(Wid, Comp, Point)).

bar_edit_menu(Wid) :-
	(retract(menu_submodel_will_be(Wid, Comp, Point)), !;
	Wid shows_model Comp,
	    get_shape(Comp, internal_extent, [L,T,R,B]),
	    X is (L+R)/2,
	    Y is (T+B)/2,
	    Point = [X,Y]),
	retractall(menu_submodel_is(_, _)),
	assert(menu_submodel_is(Comp, Point)),
	(Comp = Point, !,
% never true for now; titlebar menu uses centre point of window
	    CanCreate = 0;
	CanCreate = 1),
	(Point = [_,_], !,
	    CanAddNode = 1;
	 CanAddNode = 0),
	set_selection_abilities(Comp),    
	Wid shows_model Model,
	(member(Header/LinkType, ['Flow'/flow, 'Influence'/influence,
				  '{Role arrow}'/relation /*, 'Squirt'/squirt */]),
	    ((LinkType = flow, CanAddNode = 1; can_start(LinkType, Point))
	    -> Allow = 1; Allow = 0),
	    update_ability(Model, none, 'edit.add', Header, Allow),
	    fail;
	update_ability(Model, none, edit, '{Create new}', CanCreate),
	(find_type(Point, cloud), !,
	    CanAddComp = 1;
	CanAddComp = CanAddNode),
	update_ability(Model, none, 'edit.add', 'Compartment', CanAddComp),
	update_ability(Model, none, 'edit.add', 'Variable', CanAddNode),
	/* update_ability(Model, none, 'edit.add', 'Event', CanAddNode), */
	update_ability(Model, none, 'edit.add', '{Membership control}',
		       CanAddNode),
	update_ability(Model, none, 'edit.add', '{Text box}', CanAddNode)).

click_on(_XY, Poss_start, _CD) :-
	get_mode(add),
	finish_old_edit(none),
	get_adding_object(New_obj),
	(New_obj is_class_of_sort line,
	    do_linear(New_obj, Poss_start);
	Poss_start is_of_sort cloud,
	    New_obj = compartment,
	    cloud_to_comp(Poss_start)).

/* Move: drags object to new location; will decide later what it does with links and bowties. */

click_on([Xpt, Ypt], Moving_obj, CD) :-
	get_mode(select),
	set_moving_obj(Moving_obj),
        set_start_coords(Xpt, Ypt),
/* from select mode -- rest is from move */
	finish_old_edit(none),
	give_focus('{}'),

	( /* Control is down */
	CD = 1, !,
	    /* object is not selected, if it is, clear it and stop */
	    \+ (deselectable(Moving_obj),
		   do_colours(Moving_obj, off)),
	    do_colours(Moving_obj, on);
	/* Control not down: Object already selected */
	deselectable(Moving_obj), !;
	/* Object not selected; clear current, then select */    
	(new_selection(Moving_obj);
	    \+ is_toplevel(Moving_obj),
	    do_colours(Moving_obj, on))),
	
	(Moving_obj is_of_sort line,
	    get_shape(Moving_obj, course, [End | Rest]),
	    (MovingEnd = moving_finish,
		EndPoint = End;
	    MovingEnd = moving_start,
		last(Rest, EndPoint)),
	    near(EndPoint, [Xpt, Ypt, Xpt, Ypt]), !,
		advance_phase_to(MovingEnd) /* ,
	        ((MovingEnd = moving_start,
		        moving_endpoint(Moving_obj, moving_start, Root);
		    MovingEnd = moving_finish,
		        Root = Moving_obj),
		    (moving_endpoint(Root, moving_finish, ExtraObj),
		        highlight(ExtraObj, 2),
		        fail;
		    highlight(Root, 2));
		highlight(Moving_obj, 2)) */ ;
	advance_phase_to(moving)).

click_on([Xpt, Ypt], Moving_obj, _CD) :-
	find_type(Moving_obj,TargetSort),
	get_mode(ghost),
	\+ is_ghost(Moving_obj),
	member(TargetSort, [compartment, variable]),
	advance_phase_to(action_choice),
		
	highlight(Moving_obj, 1),
	set_line_start_obj(Moving_obj),
	get_shape(Moving_obj, bounding_box, [L,T,R,B]), !,
	Loff is Xpt-L,
	Toff is Ypt-T,
	Roff is R-Xpt,
	Boff is B-Ypt,
	set_border_offsets(Loff, Toff, Roff, Boff).

/* click_on([Xpt, Ypt], Edit_thing) :-
	get_mode(select),
	set_start_coords(Xpt, Ypt), in case dragging an area to zoom to
	give_focus(Edit_thing),
	finish_old_edit(Edit_thing),
	highlight(Edit_thing, 0).


click_on(_,_,_) :-
	get_mode(delete),
	get_phase(peruse),
	advance_phase_to(delete_hunt),
	(clicked_obj_is(Obj), !,
	    highlight_deletes(Obj);
	true). */

cloud_to_comp(Poss_start) :-
	find_all_comps(Parent, Poss_start),
	get_shape(Poss_start, bounding_box, OldBox),
	middle(OldBox, [Xpt, Ypt]),
	off(Poss_start),
	clear_shape(Poss_start, bounding_box),
	change_class(Poss_start, _, compartment),
	add_implicit_function(Poss_start, _),
	/* use insert_variable to make sure it goes in */
	insert_variable(Parent, Xpt, Ypt, compartment, Poss_start).

/* add_at_point: places a new 'box' type component in the model, fails if new_obj
is not a box type, or if there is no room at the given position to put the object.
*/

add_at_point(Xpt, Ypt, New_obj, Parent, Comp_name) :-
	New_obj = text, !,
	    make_node(Parent, New_obj, Comp_name),
	    set_shape(Comp_name, centre, [Xpt, Ypt]);
	use_style_for(New_obj, NewObjStyle),
	    get_box_size(Parent, NewObjStyle, Cur_size),
	    make_bounding_box(New_obj, Xpt, Ypt, Cur_size, Box),
	    attempt_addition(New_obj, Parent, Box, Comp_name, no, yes).

/* as above, but if there is no room it tries to add it nearby rather than failing and complaining */

insert_variable(Submodel, BestX, BestY, New_obj, Comp_name) :-
	check_translation(Submodel),
	use_style_for(New_obj, NewObjStyle),
	get_box_size(Submodel, NewObjStyle, Cur_size),
	get_shape(Submodel, internal_extent, [L, T, R, B]),
	MaxDist is max(max(BestX - L, R - BestX), max(BestY - T, B - BestY)),
	snap_to_grid([10,10], [Step, _]),
	count_to(0, MaxDist, Step, Distance),
	count_to(0, Distance, Step, Range),
	((TargetX is BestX-Distance; TargetX is BestX+Distance),
	(TargetY is BestY-Range; TargetY is BestY+Range);
	(TargetY is BestY-Distance; TargetY is BestY+Distance),
	(TargetX is BestX-Range; TargetX is BestX+Range)),
	make_bounding_box(New_obj, TargetX, TargetY, Cur_size, Box),
	attempt_addition(New_obj, Submodel, Box, Comp_name, no, no),
	redisplay(Comp_name), !.	    

deselectable(Obj) :-
	get_highlit_obj(N, Obj),
	(Obj is_of_sort line, !, N<2;
	    N<1).

/* do_linear/3: this is executed when a click marks the initial point
of a line object. It moves the editor into a mode in which dragging
will continue the line (not always the case when in line-entry modes
because it might have started at the wrong place). */

do_linear(Ltype, Start_thing) :-
	(can_start(Ltype, Start_thing), !,
		highlight(Start_thing, 1),
		set_line_start_obj(Start_thing),
		advance_phase_to(action_choice);
	highlight(Start_thing, 0),
		advance_phase_to(barge)).

/* Note the name being the same as the internal name means no caption is 
displayed */

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
/* finish_old_edit: this is called when the user does something which ends the
process of editing the text associated with a node. It gets the text from the GUI
and updates the prolog record of the nodes caption.
This used to be a dowdy, little-regarded rule which mattered not whether it
succeeded, but was thrust into the limelight on 22/1/98 when it was given the
task of preventing users entering duplicate captions within the same parent. Note
that ghost captions are not editable, but this routine will still be called when
a ghost node is unselected. */

finish_old_edit(NextEdit) :-
	/* Cannot get current window edit as this will already have changed.
	If no previous edit, do nothing */
	\+ suspend_display,
	has_focus(Prev_highlight),
%	get_highlit_obj(0, Prev_highlight),
%	\+ Prev_highlight = 0,
	!,
/*	Abandon update if selected comp was influence, cloud or same as new */
	find_base(Prev_highlight, RenamedNode),
	find_current(Window_id),
	get_text(Window_id, RenamedNode, Text),
		((Prev_highlight = NextEdit;
			Text = '/no_caption/'), !;
		(Text = '' -> Name = ' '; Name = Text),
		caption_for(RenamedNode, OldName),
		/* If name has changed check new one is usable and update it if so */
		(Name = OldName, !;
		find_all_comps(Parent, RenamedNode),
		    /* If name exists in submodel or contains dir chars,
		    block the update show message and highlight the node again */
		    (cannot_call_in(RenamedNode, Parent, Name),
			sicstus_format_to_chars("Cannot rename ~a. Its parent model already contains a component called ~a.", [OldName, Name], Blurb);
		    name(Name, NameStr),
			member(Dodgy, "\\./"),
			member(Dodgy, NameStr),
			sicstus_format_to_chars("Cannot rename ~a. The name ~a contains potentially confusing symbols ~s.",
				[OldName, Name, [Dodgy]], Blurb)), !,
		    sicstus_format_to_chars("Error renaming node ~a.",
					    [OldName], Head),
		    /* Put old caption back; this is turned on for now */
		    update_captions(Prev_highlight),
		    do_dialogue(Head, warning, Blurb, ok, _),
%	            highlight(Prev_highlight, 0),
%		    give_focus(Prev_highlight),
		    fail;
		change_name(RenamedNode, Name),
		    finish_move(Parent, 1))); /* 1 means date executable */
	/* last line gets executed if no prev edit highlight, or display is
	suspended */
	true.

/* Test for existing use of caption within model -- access database directly
because this is speed-critical. */

cannot_call_in(Prev_highlight, Parent, Name) :-
	(m_class:Impostor has_class_refinement name of Name;
		m_class:Impostor has_attribute name of Name),
	get_host(Impostor, InSameModel),
	caption_for(InSameModel, Name),
	find_all_comps(Parent, InSameModel),
	\+ (InSameModel = Prev_highlight; 
		is_ghost(InSameModel)).

change_name(RenamedNode, Name) :-
	(add_parameter(RenamedNode, 0, name, Name);
	    (find_type(RenamedNode, relation), !,
		find_name_host(RenamedNode, ArcWithName);
	    ArcWithName = RenamedNode),
	    add_parameter(ArcWithName, 2, name, Name)),
	(status_affects(RenamedNode, OtherGhost),
	    update_captions(OtherGhost),
	    presence_affects(OtherGhost, Reference),
	    implicit_function(Reference, DownFunc),
	    setof(InputSpec, P0^P1^P2^P3^P4^P5^P6^
		  (InputSpec = input_link(id(OtherGhost,P1,P2), P3,P4,P5,P6),
		      m_update:get_all_links(DownFunc, P0, InputSpec)),
		   InputSpecs),
	    get_av_pair(OtherGhost, 2, role, Roles),
	    get_av_pair(DownFunc, 0, value, Eqn),
	    m_update:already_used_in(InputSpecs, AllUsed),
		/* but what about names already used in other links? Should
		replace_subexps first then use old names then set vars */
	    all(event, update_role, [build(Roles), unify(InputSpecs),
				     unify(AllUsed), build(NewRoles)]),
	    replace_subexps(Eqn, event, swap_def_params,
			    [Roles, NewRoles], top_down, _, NewEqn),
	    add_parameter(DownFunc, 0, value, NewEqn),
	    add_parameter(DownFunc, 0, spec, ''), /* till I can update it */
	    add_parameter(OtherGhost, 2, role, NewRoles),
	    fail;
	 update_captions(RenamedNode)).

update_role(use(P1, P2, Ref, P3), InputSpecs, AllUsed,
	    use(P1, P2, NewRef, P3)) :-
	\+ Ref = usr(_),
	member(input_link(_, Spec, Ref, Unit,_), InputSpecs), !,
	generate_name(prolog, Spec, NewName, AllUsed),
	m_update:add_brackets(NewName, Unit, NewRef);
	NewRef = Ref.

swap_def_params([Roles, NewRoles], OldParam, NewParam, 0) :-
	member(use(P1, P2, OldParam, P3), Roles),
	member(use(P1, P2, NewParam, P3), NewRoles).
	
/* After clicking and unclicking, the scale factor and the targetted object will still be stored, so a doubleclick can make use of these without going through the selection process again. */

:- dynamic(doing_double_at/2).

doubleclick(Xpt, Ypt) :-
	retract(doing_double_at(Xpt,Ypt)), !;
	\+ get_mode(select), !;
	find_current(Wid),
	Wid shows_model Parent,
	doubleclick_in(Wid, Parent, [Xpt, Ypt], [0,0,1,1], 0).

doubleclick_in(Wid, Parent, AbsPoint, Trans, Depth) :-
	translate(AbsPoint, Trans, Rel_point),
	(targets(Wid, Parent, Rel_point, Depth, Target), !,
	    add_to_translation(Trans, Target, NewTrans),
	    NewDepth is Depth + 1,
	    doubleclick_in(Wid, Target, AbsPoint, NewTrans, NewDepth);
	menu:set_properties(Wid, Parent)).

doubleclick_obj(Xpt, Ypt, Name) :-
	retractall(doing_double_at(_,_)),
	assert(doing_double_at(Xpt, Ypt)),
	doubleclick_on(Name).

doubleclick_on(Edit_thing) :-
%	get_mode(select),
	find_type(Edit_thing, Edit_type),
	find_current(Wid),
	(Edit_type = submodel, !,
	    finish_old_edit(none), /* because leaving the window */
	all(event, get_display_depth,
	    [unify(Wid),
	    build([ghost_link, influence, variable, flow, compartment, 
		   submodel, caption, text, sections]), build(Depths)]),
	    contains(TopNode, Edit_thing),
	    is_toplevel(TopNode),
	    new_window_for(Edit_thing, TopNode, NewWin, Depths, 0),
	    all(state, set_display_depth,
		[unify(NewWin),
		build([ghost_link, influence, variable, flow, compartment,
		       submodel, caption, text, sections]), build(Depths)]),
	    redraw_window(NewWin);
	(Edit_type = relation, Attrs = [exclusive, can_lookup];
	    Edit_type = influence, Attrs = [use_sofar]), !,
	    find_name_host(Edit_thing, ControlThing),
	    all(event, get_refinement_or_0,
		[unify(ControlThing), build(Attrs), build(OldVals)]),
	    (get_av_pair(ControlThing, 2, comment, OldComment), !;
		OldComment = ''),
	    do_relation_dialog(Wid, ControlThing, Edit_type, OldVals,
			       OldComment, OKd, NewVals, NewComment),
	    (OKd == 1, !,
		all(m_update, add_parameter,
		    [unify(ControlThing), unify(2), build(Attrs),
		     build(NewVals)]),
		/* change role order if necessary */
		(nth(N, Attrs, can_lookup),
		    nth(N, NewVals, 1),
		    m_update:make_role_first(ControlThing); /* fails */
		add_parameter(ControlThing, 2, comment, NewComment)),
		find_all_comps(Parent, ControlThing),
		(find_name_host(Messed, ControlThing),
		    redisplay(Messed),
		    fail;
		finish_move(Parent, 1));
	    OKd == 0);
	\+ member(Edit_type, [cloud, influence]), !,
	    find_node_with_data(Edit_thing, Base, Control_thing),
	    is_parameter(Control_thing, WasP),
	    (get_av_pair(Control_thing, 0, units, OldUnits), !; OldUnits = no),
	    do_equation_dialog(Wid, Control_thing),
	    /* above fails if cancelled; if dialogue OK, then object is
	    complete. check here that the dims have changed */
	    find_node_with_data(Edit_thing, Base, NewControlThing),
	    (is_parameter(NewControlThing, WasP), !;
		redisplay_border(Edit_thing)),
	    (get_av_pair(NewControlThing, 0, units, OldUnits), !,
		NewDims = no;
	    NewDims = yes),
	    spread_colour(Base, NewDims),
	    find_all_comps(Parent, Base),
	    update_runnable(Parent)).
	
get_refinement_or_0(ControlThing, Attr, OldExc) :-
	get_av_pair(ControlThing, 2, Attr, OldExc), !;
	OldExc = 0.

/* If something's dimensions have changed, check all the equations
where it is used. If they do not check out unit-wise, try to re-do
them with the new units and if this succeeds, recurse if their
dimensions too have changed. In any case, mark the submodel as in
need of a rebuild as even if it doesn't change it will need to get the
input values using the new units. */

spread_dims(Tgt) :-
	find_base(Tgt, Node),
	(implicit_function(Node, Obj),
	find_all_comps(Sm, Obj),
	add_parameter(Sm, 1, c_new, 0),
	get_av_pair(Obj, 0, value, Equation),
	get_av_pair(Obj, 0, units, GivenUnits),
	get_input_info(Obj, IList),
	
	(length(Inds, 32),
	    test_eqn(Equation, Node, Inds, IList, Type, FoundArray, _, Err),
	    Err = [],
	    analyze_array(GivenUnits, GivenBase, GivenArray),
	    (get_actual_sizes(Node, FoundArray, _, Array, _),
		get_actual_sizes(Node, GivenArray, _, Array, _), !,
		UseArray = GivenArray;
		UseArray = FoundArray,
		UnitsChanged = yes),
	    (Type = real, !, Base = 1; Base = Type),
	    (check_unit(Base, GivenBase, 2, []), !,
		UseBase = GivenBase;
	    UseBase = Base,
		UnitsChanged = yes),
	    update_links_and_vars(IList);
	true),
	(UnitsChanged = no;
	build_array(UseBase, UseArray, NewUnits),
	    add_parameter(Obj, 0, units, NewUnits)), !;
	find_type(Node, submodel)),
	spread_colour(Node, UnitsChanged).

/* this will update colours of all nodes connected with the given node */

spread_colour(Node, NewDims) :-
	need_same_dims(Node, Flow),
	    update_color(Flow),
	    fail;
	setof(More, (More = Node; status_affects(Node, More)), SpreadList),
	(member(Hit, SpreadList), \+ find_type(Hit, influence);
	member(Hit, SpreadList), find_type(Hit, influence)),
	/* Do influences last cos they depend on others! */
	(NewDims = no,
	    update_color(Hit);
	NewDims = yes,
	    check_complete(Hit),
	    redisplay_border(Hit),
	    presence_affects(Hit, MayChange),
	    spread_dims(MayChange)),
	/* Component colour will be normalized so get its links normal too 
	(normalize_ghosts_etc(Hit); */
	fail; true.

new_window_for(Submodel, TopNode, Canvas_name, InitDepths, IsTopLevel) :-
	utility:unique_name('.mswindow', Topwin), !,
	window_size_for(Submodel, Sub_extent, Scale),
	get_window_colour(Submodel, Colour, Images),
	add_window(Topwin, TopNode, Submodel, Sub_extent, Canvas_name, 
		[Colour | Images], Scale, InitDepths, IsTopLevel),
	create_window(Canvas_name, Submodel),
	make_current(Canvas_name),
	set_save_status(Canvas_name, safe).

/* This version always created a window at least the size of the initial
window, always zooming in so that the original contents of the submodel
(which by default are the same size as those of its parent) fill the entire
window. This process has been abandoned because it gave rise to some very
large components.

window_size_for(Submodel, [NewL, NewT, NewR, NewB], Scale) :-
	get_initial_window_size(Xinit, Yinit),
	get_shape(Submodel, internal_extent, [L, T, R, B]),
	Scale is max(1, max(Xinit/(R - L), Yinit/(B - T))),
        NewL is L*Scale,
	NewT is T*Scale,
	NewR is R*Scale,
	NewB is B*Scale.

Current version creates a new window showing contents at the default size. If
they have not yet been scaled, the window is the same size as the submodel
in the parent. */

window_size_for(Submodel, Size, 1) :-
	get_shape(Submodel, internal_extent, Size).

/*
drag_obj(Xpt, Ypt, Name) :-
	sift_and_set(Xpt, Ypt),
	find_current(Wid),
	find_relevant_windows(Name, Wid, _, Trans),
	translate([Xpt, Ypt], Trans, [RelXpt, RelYpt]),
	drag_to(RelXpt, RelYpt, Name).

The easy bit: ignore initial drags of one unit or less, and for larger ones
register the user's choice of a drag rather than a click-start click-end. */

sift_and_set(_, _) :-
	/* Next few lines stopped drag from starting until a certain
	distance had been covered. Latest versions have faster graphics
	so this should not be necessary...
	get_original_click(OrigX, OrigY),
	abs(Xpt-OrigX) + abs(Ypt-OrigY) > 2,
	*/
	(get_phase(action_choice), !,
		advance_phase_to(dragging);
	true).

/* rather than just using Prolog
to find what component I've dragged into I'll precede this with an attempt to get
the info from Tk, only resorting to Prolog should this fail. Note GUI should only
be consulted if in multi-object mode. */

drag(Xpt, Ypt) :-
	sift_and_set(Xpt, Ypt),
	find_current(Wid),
	(multi_object_mode,
	    remove_old_incomplete,
	    remove_old_rubberband,
	    get_component_from_gui(Wid, Xpt, Ypt, Comp), !,
		(multi_level_mode, !,
			find_relevant_windows(Comp, Wid, New_depth, BorderTrans),
			(find_type(Comp, submodel), !,
				add_to_translation(BorderTrans, Comp, Trans),
				New_parent = Comp;
			find_all_comps(New_parent, Comp),
				Trans = BorderTrans),
			save_params(Trans, New_depth, New_parent);
		get_current_node(Parent),
			find_all_comps(Parent, Comp),
			get_translation(Trans)),
		translate([Xpt, Ypt], Trans, RelPt);
	/* do not delete a submodel by unclicking inside it 
	get_mode(delete), !,
	    remove_highlights,
	    fail; */
	update_context(Wid, [Xpt, Ypt], RelPt, Comp)),
	(get_phase(moving_text), !,
	    RelPt = [NewXpt, NewYpt];
	snap_to_grid(RelPt, [NewXpt, NewYpt])),
	drag_to(NewXpt, NewYpt, Comp).

/* This is a hideously complex procedure for working out what component I have
effectively dragged to. The indentation should get a level deeper after an
open-bracket, signifying the start of a conditional. There is a cut defining the
end of the clauses representing the condition. Semicolon ends the conditional
action, indentation comes out one for the next condition (put a comment here if it
is default). At end of conditional, extra close bracket and out one indentation. */

/* 1998 alterations; (1) It is now recursive, to cope with drags that cross more
than one component boundary at once (this always happened but is more common now a
drag can be signalled by click-to-start, click-to-finish) and (2) It's no longer
much more complicated than the rest of the code. */

update_context(Wid, Pair, NewPair, Comp) :-
	get_translation(Trans),
	get_current_node(Parent),
	(multi_object_mode, !,
		check_exits(Wid, Parent, Trans, Pair, InterParent, InterTrans),
		check_entries(InterParent, InterTrans, Pair, NewPair, Comp);
	/* Not multi-object mode -- just use previous object if there is one */
	(get_moving_obj(Comp), !; Comp = none),
		translate(Pair, Trans, NewPair)).

check_exits(Wid, Parent, Trans, Pair, InterParent, InterTrans) :-
	translate(Pair, Trans, [RelXpt, RelYpt]),
	get_shape(Parent, internal_extent, [L, T, R, B]),
	((RelXpt < L; RelXpt > R; RelYpt < T; RelYpt > B), !,
	/* Dragged outside previous parent... */
		multi_level_mode, 
		\+ Wid shows_model Parent,
		/* Multilevel enavles and component does not fill window, 
		so can leave it, otherwise fail */ 
			subtract_from_translation(Trans, Parent, Prev_trans),
			find_all_comps(Grandma, Parent),
			check_exits(Wid, Grandma, Prev_trans, Pair, 
					InterParent, InterTrans);
	InterParent = Parent,
		InterTrans = Trans).

/* Look for what we are pointing at within the current model. This version ignores
active display depths so allows pointing to invisible details. */

check_entries(InterParent, Trans, Pair, NewPair, Comp) :-
	translate(Pair, Trans, InterPair),
	(targets(_, InterParent, InterPair, 0, New_obj), !,
		(multi_level_mode,
		find_type(New_obj,  submodel), !,
			add_to_translation(Trans, New_obj, DeepTrans),
			check_entries(New_obj, DeepTrans, Pair, NewPair, Comp);
		/* else select this component */
			save_params(Trans, 0, New_obj),
			NewPair = InterPair,
			Comp = New_obj);
	/* in previous component but targets nothing */
		save_params(Trans, 0, InterParent),
		NewPair = InterPair,
		Comp = InterParent).


:- dynamic(moved_something/0).
:- dynamic(instant_link/1).

move_something :-
	moved_something, !;
	assert(moved_something).

drag_to(Xpt, Ypt, _Comp) :-
	get_mode(select),
	\+ instant_link(_),
	get_phase(rubberband),
	get_start_coords(OldX, OldY),
	clear_incomplete,
	add_incomplete([OldX, OldY, Xpt, Ypt]),
	remove_old_rubberband,
	draw_rubberband(square).

drag_to(Xpt, Ypt, Comp) :-
	(instant_link(Ltype), !;
	get_mode(add),
	    get_adding_object(Ltype)),
	get_phase(Phase),
	(Ltype is_class_of_sort line, Phase = dragging,
		sort_for_finish(Comp, Ltype, Xpt, Ypt);
	Ltype is_class_of_sort rounded_rect, Phase = rubberband,
		get_start_coords(OldX, OldY),
	        clear_incomplete,
		add_incomplete([OldX, OldY, Xpt, Ypt]),
		remove_old_rubberband,
		draw_rubberband(round);
	true).

drag_to(Xpt, Ypt, Moving_obj) :-
	get_mode(select), /* was move */
	get_start_coords(OldX, OldY),
	Xoffset is Xpt - OldX,
	Yoffset is Ypt - OldY,
	find_current(Wid),
	\+ Wid shows_model Moving_obj,
	(get_phase(moving),
		 (adjust_bowtie(Moving_obj, [Xpt, Ypt]), !,
		     redisplay(Moving_obj),
		     make_links_follow(Moving_obj) /* ,
		     highlight(Moving_obj, 2) */;
		 adjust_spline(Moving_obj, [Xoffset, Yoffset]), !,
		     reroute_display(Moving_obj),
		     move_text(Moving_obj, [Xoffset, Yoffset]);
		 get_highlit_obj(0, Moving_obj),
		     \+ Moving_obj is_of_sort line,
		     find_all_comps(Parent, Moving_obj),
		     get_shape(Parent, internal_extent, ParentShape),
		     setof(Mover, moves_with_seln(Parent, Mover), Movers),
		     \+ (member(Crasher, Movers),
			find_new_box(Crasher, Xoffset, Yoffset, _, BadPosn),
			( \+ fits_inside(BadPosn, ParentShape);
			    get_overlaps(Parent, BadPosn, Crashed),
			    \+ member(Crashed, Movers))),
		     all(event, adjust_posn,
			 [build(Movers), unify([-Xoffset, -Yoffset, 1, 1])]),
		     all(event, tweak_link_connections,
			 [build(Movers), unify([Xoffset, Yoffset]),
			  unify(c), build(_)]),
		     all(draw, move_display,
			 [build(Movers), unify([Xoffset, Yoffset])]));
/*		find_new_box(Moving_obj, Xoffset, Yoffset, _, NewPosn),
		     find_all_comps(Parent, Moving_obj),
 Succeed if parent doesn't have an extent limit, otherwise check it 
		    (get_shape(Parent, internal_extent, Parent_shape), !,
			fits_inside(NewPosn, Parent_shape);
		    true),

			Check we haven't run into any obstacles...
		     \+ get_overlaps(Parent, NewPosn, Moving_obj),

		     ...or crossed into another component...
		     \+ (targets(Wid, Parent, [Xpt, Ypt], 0, Model),
			    \+ Model = Moving_obj),

		     adjust_posn(Moving_obj, [Xoffset, Yoffset]),
		     tweak_link_connections(Moving_obj, [Xoffset, Yoffset],
					    _,_),
		     move_display(Moving_obj, [Xoffset, Yoffset]));  */
	get_phase(moving_border(Edge)), !,
	    update_object_boundary(Moving_obj, Edge, Xoffset, Yoffset),
	    redisplay_border(Moving_obj);
	get_phase(moving_text),
	    update_text_position(Moving_obj, Xoffset, Yoffset),
	    move_text(Moving_obj, [Xoffset, Yoffset])),
	move_something,
	set_start_coords(Xpt, Ypt).

drag_to(Xpt, Ypt, Moving_obj) :-
	get_mode(select), /* was move */
	get_phase(Phase),
	(Phase = moving_start, Inner_move = start,
	    (continues_from(Moving_obj, Box), !;
		m_update:Moving_obj is_connector from Box to _);
	Phase = moving_finish, Inner_move = finish,
	    (continues_in(Moving_obj, Box), !;
		local_ends(Moving_obj, _, Box))),
	find_type(Box, EType),
	/* find drag point in parent model */
	find_all_comps(Parent, Moving_obj),

	(Parent = Box, !,
	    get_shape(Parent, internal_extent, ParentBox),
	    subtract_from_translation([0,0,1,1], Box, Trans);
	get_drawing_form(Box, _, ParentBox),
	    (\+ EType = submodel;
		add_to_translation([0,0,1,1], Box, Trans))),
	    
	middle(ParentBox, [Xc, Yc]),
	/* allow leeway of 10% for dragging round border */
	Leeway = 0.1,
	Xin is Xpt + Leeway*(Xc - Xpt),
	Yin is Ypt + Leeway*(Yc - Ypt),
	Xout is Xpt + Leeway*(Xpt - Xc),
	Yout is Ypt + Leeway*(Ypt - Yc),
	inside_shape([Xin, Yin], EType, ParentBox),
	\+ inside_shape([Xout, Yout], EType, ParentBox),
	/* Snap to border */
	crossing_point([Xc, Yc], [Xout, Yout], EType, ParentBox,
			NewEndPt),

	(EType = submodel,
	    (Phase = moving_start,
	        moving_endpoint(Moving_obj, moving_start, Root),
	        translate(NewEndPt, Trans, RootEndPt),
	        ExtraEndPt = NewEndPt;  
	    Phase = moving_finish,
	        Root = Moving_obj,
	        RootEndPt = NewEndPt,
	        translate(RootEndPt, Trans, ExtraEndPt)),
	    (moving_endpoint(Root, moving_finish, ExtraObj),
		tweak_endpoint(ExtraObj, start, ExtraEndPt),
		fail;
	    tweak_endpoint(Root, finish, RootEndPt));
	tweak_endpoint(Moving_obj, Inner_move, NewEndPt)),
	move_something.

drag_to(Xpt, Ypt, Target) :-
	get_phase(dragging),
	get_mode(ghost),
	(get_highlit_obj(2, OldTarget),
	    normalize(OldTarget),
	    fail;
	 find_type(Target, submodel), !;
	    ghost_type(Start, _, _),
	    \+ Target = Start,
	    \+ find_ghosts(Target, _),
	    /* find_type(Target, Type), Allow target''s type to differ */ 
	    highlight(Target, 2)),
	get_border_offsets(Loff,Toff,Roff,Boff),
	L is Xpt-Loff,
	T is Ypt-Toff,
	R is Xpt+Roff,
	B is Ypt+Boff,
	clear_incomplete,
	add_incomplete([L,T,R,B]),
	remove_old_rubberband,
	draw_rubberband(round).

moves_with_seln(Parent, Obj) :-
	find_all_comps(Parent, Obj),
	(Obj is_of_sort box,
	    get_highlit_obj(0, Obj);
	local_ends(Obj, P1, P2),
	    moves_with_seln(Parent, P1),
	    moves_with_seln(Parent, P2)).

resize_top_win(Wid, W, H) :-
	Wid shows_model Mod,
	change_shape(Mod, bounding_box, [0,0,W,H]).

/* drag_to(_, _, Doomed_thing) :-
	get_mode(delete),
	get_phase(delete_hunt),
	remove_highlights,
	highlight_deletes(Doomed_thing).

adjust_display_area handles requests from the GUI to change the display
area in a submodel. expand_canvas actually changes it; here we also reroute
the internal portions of crossborder links so they still connect. */

adjust_display_area(Wid, Visible) :-
	Wid shows_model Parent,
	expand_canvas(Parent, Visible),
	tweak_link_connections(Parent, [0,0], nw, [0,0,1,1]).

tweak_link_connections(Obj, [XOff, YOff], Side, [L, T, R, B]) :-
	find_all_comps(Box, Obj),
	find_all_links(Obj, Link, Where),
	\+ (Side = c, moves_with_seln(Box, Link)),
	/* do not tweak if part of move */
	end_coords(Link, Where, [Xpt, Ypt]),
	((member(Side, [nw, w, sw]), NewX is Xpt + XOff*(R-Xpt)/(R-L);
	        member(Side, [ne, e, se]), NewX is Xpt + XOff*(Xpt-L)/(R-L);
	        member(Side, [n, s]), NewX = Xpt),
	    (member(Side, [nw, n, ne]),  NewY is Ypt + YOff*(B-Ypt)/(B-T);
		member(Side, [sw, s, se]), NewY is Ypt + YOff*(Ypt-T)/(B-T);
		member(Side, [w, e]), NewY = Ypt),
	    add_to_translation([0,0,1,1], Obj, Trans),
	    (has_outer_equiv(Inner, Obj, Link),
		select(Where, [start, finish], [Other]),
		translate([NewX, NewY], Trans, Peri),
		tweak_endpoint(Inner, Other, Peri);
	    \+ has_outer_equiv(Inner, Obj, Link));
	Side = c,
	    NewX is Xpt + XOff,
	    NewY is Ypt + YOff),
	tweak_endpoint(Link, Where, [NewX, NewY]),
	fail; true.

/* find_space handles pairs of values indicating ranges. The
first gives the range which must be covered, the second the
range already covered. The third is the new part to cover,
and the fourth the part of the previous cover which has been used. Assumes ranges are same size. */

find_space([TgtL, TgtH], [DoneL, DoneH], [NewL, NewH],
		[UsedL, UsedH]) :-
	DoneL < TgtL, !,
		NewL is max(DoneH, TgtL),
		NewH = TgtH,
		UsedL = TgtL,
		UsedH = NewL;
	NewL = TgtL,
		NewH is min(DoneL, TgtH),
		UsedL = NewH,
		UsedH = TgtH.
		
/* tweak_endpoint/3: adjusts shape of line when endpoint is moved, currently
resets middle as well if it is a flow, not otherwise! */

tweak_endpoint(Moving_obj, End, NewPt) :-
	find_type(Moving_obj, Type),
	get_shape(Moving_obj, course, [Finish | Rest]),
	append(Middle, [Start], Rest),
	local_ends(Moving_obj, Source, Dest),
	member([End, Way, Comp],
	       [[start, out, Dest], [finish, in, Source]]),
	(Type is_class_of_sort has_bowtie,
	    route_part_link(Type, Way, [Comp], NewPt, FwRoute),
	    reverse(FwRoute, Route),
/*		(End = start,
			shape_route(Type, NewPt, Finish, Route);
		End = finish,
			shape_route(Type, Start, NewPt, Route)),
*/	    get_box_size(Source, flow, FlowBox),

	    BowSize is FlowBox/2,
	    get_middle_segment(Type, Route, BowSize, BowShape),
	    change_shape(Moving_obj, bowtie, BowShape),
	    redisplay(Moving_obj),
            (has_outer_equiv(SubLink, Comp, Moving_obj),
		move_link(SubLink),
		fail;
	    true);
	Type is_class_of_sort curved,
	    NewMiddle = [[NewMX,NewMY]],
	    (End = start,
		append([NewFinish | NewMiddle], [NewPt], Route),
		scale_difference(Start, NewPt, 2, TextMove),
		(appears(Comp), \+ find_type(Comp, submodel), !;
		    NewFinish = Finish);
	    End = finish,
		append([NewPt | NewMiddle], [NewStart], Route),
		scale_difference(Finish, NewPt, 2, TextMove),
		(appears(Comp), \+ find_type(Comp, submodel), !;
		    NewStart = Start)),
	    tweak_middle(Middle, TextMove, NewMiddle),
            (ground(Route), !;
		route_part_link(Type, Way, [Comp], [NewMX,NewMY], FwRoute),
		append([NewStart | _], [NewFinish], FwRoute)),
	    move_text(Moving_obj, TextMove)),
	change_shape(Moving_obj, course, Route),
/* If I enable border points following far end drags, make sure
the internal sections follow them too...
        (End = start,
	    has_outer_equiv(SubLink, Comp, Moving_obj),
	    move_link(SubLink),
	    fail;
	true),
*/
	reroute_display(Moving_obj),
	make_links_follow(Moving_obj).

scale_difference([X1, Y1], [X2, Y2], Sc, [X, Y]) :-
	X is (X2 - X1)/Sc,
	Y is (Y2 - Y1)/Sc.

tweak_middle([[X1, Y1]], [Xt, Yt], [[X2, Y2]]) :-
	X2 is X1+Xt,
	Y2 is Y1+Yt.

/* multi_object_mode: system is in a state in which dragging from one object to
another makes sense (one day this but not the next might be true) */

multi_object_mode :-
	multi_level_mode.
	
/* multi_level_mode: system is in a state in which dragging in and out of
components makes sense */

multi_level_mode :-
	(instant_link(Type);
	 get_mode(add),
	    get_adding_object(Type)),
	Type is_class_of_sort line;
	get_mode(ghost).

/* do_colours/1: When an object is selected this should set it and its
neighbours to the appropriate colours, i.e.,
blue: moves in bulk, copies and deletes
turquoise: drags and deletes
dark green: deletes
light green: changes status */

do_colours(Obj, Way) :-
	(Way = on,
	    highlight_deletes(Obj);
	Way = off),
/*	m_class:Obj is_connector from A to B,	    
	    trail(A, Obj, Way);
	Obj is_of_sort box,
	    (Way = on, highlight(Obj, 0); Way = off, highlight(Obj, 2)),
	    fail, trail(Obj, _, Way);
*/	(Way = off,
	    normalize_deletes(Obj);
	Way = on).

/* highlight_deletes: this highlights all the objects which will be zapped if a particular delete selection is made. The target itself highlights at defcon 0 and any colateral damage at defcon 1. */

highlight_deletes(Target) :-
	(Base = Target; ghost_link(Target, Base, Ghost)),
	m_class:initiates(Link, Base),
	ghost_link(Link, Base, Ghost),
	\+ get_highlit_obj(_, Ghost),
	highlight(Ghost, 2),
	fail; 
	recursive_highlight(Target, on, base);
	recursive_highlight(Target, off, seln);
	true.

normalize_deletes(Target) :-
	(Base = Target; ghost_link(Target, Base, Ghost)),
	    m_class:initiates(Link, Base),
	    ghost_link(Link, Base, Ghost),
	    get_highlit_obj(2, Ghost),
	    normalize(Ghost),
	    fail;
	recursive_highlight(Target, on, seln);
	recursive_highlight(Target, off, base);
	find_base(Target, Base),
	    \+ Base = Target,
	    doomed(Base),
	    highlight(Target, 2), fail;
	keep_only_if_links_stay(Target, base), fail;
	true.

recursive_highlight(Target, Way, Where) :-
	(Target is_of_sort box, !,
	    change_delete_status(Target, Way, Where),
	    Also = Target;
	tk_get_pref(deleteEndToEnd, 1),
	    m_class:connects(Target, Start, Mid),
	    get_host(Mid, Finish),
	    match_delete_status([Start, Finish], Way, Where),
	    change_delete_status(Target, Way, Where),
	    (Also = Target;
	    adjust_link_backwards(Target, Way, Also, Where);
	    adjust_link_forwards(Target, Way, Also, Where);
	    bring_dependents_into_line([Start, Finish], Where), fail);
	tk_get_pref(deleteEndToEnd, 0),
	    local_ends(Target, Start, Finish),
	    match_delete_status([Start, Finish], Way, Where),
	    change_delete_status(Target, Way, Where),
	    bring_dependents_into_line([Start, Finish], Where),
	    Also = Target),
	find_all_links(Also, Linked),
	    \+ has_outer_equiv(_, Also, Linked),
	    recursive_highlight(Linked, Way, Where).

adjust_link_backwards(Target, Way, Also, Where) :-
	m_class:follows(Prev, Target),
	(Way = off,
	    change_delete_status(Prev, off, Where);
	 Way = on,
	    \+ (m_class:follows(Prev, Other),
		   at_def_con(Other, Where)),
	    change_delete_status(Prev, on, Where)),
	 (Also = Prev; adjust_link_backwards(Prev, Way, Also, Where)).
	
adjust_link_forwards(Target, Way, Also, Where) :-
	m_class:follows(Target, Next),
	(Way = on,
	    change_delete_status(Next, on, Where);
	 Way = off,
	    m_class:connects(Next, _, Mid),
	    get_host(Mid, Finish),
	    match_delete_status([Finish], Way, Where),
	    change_delete_status(Next, off, Where)),
	(Also = Next; adjust_link_forwards(Next, Way, Also, Where)).
	
change_delete_status(Target, Way, FromWhere) :-
	(\+ at_def_con(Target, FromWhere), !,
	    Way = off,
	    to_def_con(Target, FromWhere);
	Way = on,
	    highlight(Target, 1)).

bring_dependents_into_line(Followers, FromWhere) :-
	/* Now change cloud etc to same colour as link */
	(FromWhere = base,
	    member(Damage, Followers),
	    appears(Damage),	
	    keep_only_if_links_stay(Damage, FromWhere),
	    fail;
	true).

at_def_con(Tgt, FromWhere) :-
	FromWhere = base,
	    \+ get_highlit_obj(_, Tgt);
	FromWhere = seln,
	    get_highlit_obj(0, Tgt).

to_def_con(Tgt, FromWhere) :-
	FromWhere = base,
	    normalize(Tgt);
	FromWhere = seln,
	    highlight(Tgt, 0).

depends_on_links(Damage) :-
	find_type(Damage, cloud) /* keep unattached parameters for now ;
	is_parameter(Damage, N), N>0 */ .

keep_only_if_links_stay(Damage, Where) :-
	depends_on_links(Damage),
	(setof(NeedsIt, find_all_links(Damage, NeedsIt), NeedIt),
	member(HasIt, NeedIt),
	at_def_con(HasIt, Where), !,
	to_def_con(Damage, Where);					
	highlight(Damage, 1)).

match_delete_status(Ends, Way, Where) :-
	Way = on;
	member(End, Ends),
	(Where = seln; \+ depends_on_links(End)),
	\+ at_def_con(End, Where), !, Way = on;
	Way = off.

local_ends(Link, Start, Finish) :-
	m_class:Link is_connector from Start to Mid,
	get_host(Mid, Finish).

doomed(End) :-
	get_highlit_obj(L, End),
	L<2.

thread_link(Top_arc) :-
	update_link_route(Top_arc, yes),
	update_equivs(Top_arc),
	(m_class:equivalent_arcs(Top_arc, NewArc),
		redisplay(NewArc),
		fail;
	presence_affects(Top_arc, Other_arc),
		get_host(Other_arc, NewImage),
		update_color(NewImage),
		update_captions(NewImage),
		fail;
	true).

make_links_follow(Obj) :-
	find_all_links(Obj, Link),
	adjust_link(Link, no),
	fail; true.

/* move_link: adjusts the route of a link, making a new connection point
to any components it attaches to the outside of. If it continues inside one
of those components this is recursively moved as well.

Not used very much now: only when routing a ghost link, dragging one
end of a flow or connecting a link due to reading an interface spec
file (surely some mistake?) */

move_link(Link) :-
	adjust_link(Link, yes),
	update_equivs(Link).

adjust_link(Link, Recurse) :-
	(get_shape(Link, course, OldCourse), !; true),
	update_link_route(Link, Recurse),
	get_shape(Link, course, NewCourse),
	reroute_display(Link),
	(find_type(Link, flow), !,
	    redisplay(Link);
	find_type(Link, relation),
	nonvar(OldCourse), !,
	    get_caption_anchor(OldCourse, [OldTX, OldTY | _]),
	    get_caption_anchor(NewCourse, [NewTX, NewTY | _]),
	    TXMove is NewTX - OldTX,
	    TYMove is NewTY - OldTY,
	    move_text(Link, [TXMove, TYMove]);
	true),
	make_links_follow(Link).

update_equivs(Link) :-
	(continues_from(Link, Sm); continues_in(Link, Sm)),
	has_outer_equiv(Sublink, Sm, Link),
	move_link(Sublink),
	fail; true.

/* This is sort_for_finish. 
It gets a parent and a target, which may be the same. If the target can be finished 
on, highlight it in green; if not, and it is primitive, light it red, otherwise no 
light. If on a finishable primitive, draw the final route; if on a nonfinishable 
primitive do not update the route. If on a submodel, hunt if it contains anything 
finishable, otherwise do as for primitive. 

Alteration to allow drags of links into space to produce new components; always
hunt if on a submodel. Further alteration: only make this alteration for flows */

sort_for_finish(Target, Ltype, Xpt, Ypt) :-
	(get_highlit_obj(_, Old_target),
		normalize(Old_target), fail; true),

	get_line_start_obj(OrigStart),
        get_nearest_equivalent_link(Ltype, OrigStart, Target, Start),
	(find_type(Target, submodel),
	/* This requirement dropped for flows, see above */
		(find_all_comps(Target, Baby),
			can_finish(Ltype, Start, Baby),
			\+ contains(Baby, Start), !;
		member(Ltype, [flow, squirt])),
		set_current_coords(Xpt, Ypt), /* for new terminator if dropped here */
		extend_line_to(Start, Ltype, Target, [Xpt, Ypt]);
	Drawn = false),

	(can_finish(Ltype, Start, Target), !,
	    set_line_finish_obj(Target),
	    highlight(OrigStart, 1),
	    highlight(Target, 2),
	    (Drawn = true, !;
	    draw_line_to(Start, Ltype, Target));
	set_line_finish_obj(none),
	    highlight(Target, 0)).

/* get_nearest_equivalent_link: Original version tried to minimize all
link lengths. This one is much simplified, so a link will always be
one coming from the node or link the user actually clicked on, without
another visible variable in between. This stops unexpected things
happening when re-ghosting nodes. The original is in the commentary
file ghosting.txt */

get_nearest_equivalent_link(Ltype, OrigStart, Target, Start) :-
	/* For influences, draw link from a nearby influence from
		the same source if there is one handy */
	member(Ltype, [influence, ghost_link]),
                \+ find_type(OrigStart, submodel),
		get_chain(OrigStart, Target, _Top, Exits, Entries),
		reverse(Exits, BiggestFirst),
/*		append(Entries, [Top | BiggestFirst], NearestFirst),
		member(StartPoint, NearestFirst),
		Start draws_inside StartPoint,
*/
                (member(StartPoint, Entries),
		    m_class:Start is_connector from _ to StartPoint;
		member(StartPoint, BiggestFirst),
		    m_class:Start is_connector from StartPoint to _),
		get_possible_start(OrigStart, Start),
% following lines stop influences and ghost links sharing sections
		(ghost_link(Start, _,_) -> Ltype = ghost_link;
		    true),
%		    Ltype = influence),
		appears(Start),
		can_start(influence, Start),
		can_finish(influence, Start, Target), !;
	Start = OrigStart.

extend_line_to(Start, Type, Target, Point) :-
	make_chain(Type, Start, Target, Top, Up_list, Down_list),
	draw_links(Type, Top, Up_list, [Point | Down_list]).

/* draw_line_to/3: adds a temporary graphical link between two components. 
make_chain/6 fails if there is no link to draw, in which case this does nothing. */

draw_line_to(Start, Type, Target) :-
	make_chain(Type, Start, Target, Top, Up_list, Down_list), !,
		draw_links(Type, Top, Up_list, Down_list);
	true.

/* make_chain: this gets the list of boxes that must be drawn
connected, replacing the links returned by get_chain with the points
at which they enter or leave the components at the end of the
chain. */

make_chain(Type, Start, Target, Top, Up_list, Down_list) :-
	(find_type(Start, Type),
	    (continues_in(Start, Start_box);
	    find_all_comps(StartPoint, Start),
		(contains(StartPoint, Target, Dests),
		    suffix([Start_box], Dests);
		Start_box = StartPoint)), !;
	Start_box = Start),
	(find_type(Target, Type),
	    (continues_from(Target, Finish_box);
	    find_all_comps(FinishPoint, Target),
		(contains(FinishPoint, Start, Srcs),
		    suffix([Finish_box], Srcs);
		Finish_box = FinishPoint)), !;
	Finish_box = Target),
	
	get_chain(Start_box, Finish_box, Top, Full_ups, Full_downs),

	(find_type(Start, Type), !,
		get_shape(Start, course, [End | _]),
		(Start draws_inside Start_box, !,
			subtract_from_translation([0,0,1,1], Start_box, Trans),
			Full_ups = [Start_box | Rest];
		/* Link is incoming */
			add_to_translation([0,0,1,1], Start_box, Trans),
			Rest = []),
		translate(End, Trans, Rel_end),
		Up_list = [Rel_end | Rest];
	Up_list = Full_ups),

	(find_type(Target, Type), !,
		get_shape(Target, course, Outward),
		last(Outward, End2),
		(Target draws_inside Finish_box, !,
			subtract_from_translation([0,0,1,1], Finish_box, Trans2),
			Full_downs = [Finish_box | Rest2];
		/* Link is outgoing */
			add_to_translation([0,0,1,1], Finish_box, Trans2),
			Rest2 = []),
		translate(End2, Trans2, Rel_end2),
		Down_list = [Rel_end2 | Rest2];
	Down_list = Full_downs).

update_object_boundary(Submodel, Edge, XOff, YOff) :-
	get_shape(Submodel, bounding_box, [OldL, OldT, OldR, OldB]),
	/* work out what the caption was nearest to */
	(get_shape(Submodel, caption_offset, [XT, YT]);
	    get_shape(Submodel, caption_offset, [XT, YT, _Anchor])), !,
	OldCapX is OldL + XT,
	OldCapY is OldT + YT,
	get_closest_edge(Submodel, [OldCapX, OldCapY], CapEdge),
	(member(Edge, [nw, w, sw, c]), !, NewL is OldL+XOff; NewL = OldL),
	(member(Edge, [nw, n, ne, c]), !, NewT is OldT+YOff; NewT = OldT),
	(member(Edge, [ne, e, se, c]), !, NewR is OldR+XOff; NewR = OldR),
	(member(Edge, [sw, s, se, c]), !, NewB is OldB+YOff; NewB = OldB),
	NewBox = [NewL, NewT, NewR, NewB],
	/* Check it is not too small */
	get_box_size(Submodel, submodel, Standard),
	NewR-NewL > Standard//2,
	NewB-NewT > Standard//2,
	find_all_comps(Parent, Submodel),
	get_shape(Parent, internal_extent, ParentShape),
	fits_inside(NewBox, ParentShape),
	\+ (get_overlaps(Parent, NewBox, Obstacle), \+ Obstacle = Submodel),
	
	add_to_translation([0,0,1,1], Submodel, ModelTrans),
	translate(NewBox, ModelTrans, NewExtent),
	/* Check that everything that was in the model is still in it */
	\+ (find_all_comps(Submodel, Inside),
	       get_shape(Inside, bounding_box, InBox),
	       \+ fits_inside(InBox, NewExtent)),
	map([OldL, OldT, OldR, OldB], CapEdge, _,_, OBX, OBY),
	map(NewBox, CapEdge, _,_, NBX, NBY),
	NXT is OldCapX+NBX-OBX-NewL,
	NYT is OldCapY+NBY-OBY-NewT,
	change_shape(Submodel, caption_offset, [NXT, NYT]),
	change_shape(Submodel, internal_extent, NewExtent),
	change_shape(Submodel, bounding_box, NewBox),
	/* make_links_follow(Submodel), */
	tweak_link_connections(Submodel, [XOff, YOff], Edge,
			       [OldL, OldT, OldR, OldB]).

/* anything this complex has got to be wrong */

old_update_object_boundary(Submodel, Edge, XOff, YOff) :-
	get_shape(Submodel, bounding_box, [OldL, OldT, OldR, OldB]),
	member(get(Edge, Outward, Motion, Start, NewBox, InnerEdge),
	       [get(w, <, XOff, OldL, [New, OldT, OldR, OldB], InnerL),
		get(n, <, YOff, OldT, [OldL, New, OldR, OldB], InnerT),
		get(e, >, XOff, OldR, [OldL, OldT, New, OldB], InnerR),
		get(s, >, YOff, OldB, [OldL, OldT, OldR, New], InnerB)]),

	New is Start+Motion,
	max_size_is(MaxSize),
	MaxTest =..[Outward, MaxSize, New],
	call(MaxTest),
	
	add_to_translation([0,0,1,1], Submodel, ModelTrans),
	translate(NewBox, ModelTrans, NewExtent),
	NewExtent = [InnerL, InnerT, InnerR, InnerB],
	min_size_is(MinSize), !,
	MinTest =.. [Outward, InnerEdge, MinSize],
	call(MinTest),

	change_shape(Submodel, internal_extent, NewExtent),
	change_shape(Submodel, bounding_box, NewBox),
	/* make_links_follow(Submodel), */
	tweak_link_connections(Submodel, [XOff, YOff], Edge,
			       [OldL, OldT, OldR, OldB]).
	/* External links must be adjusted first because their endpoints
	are used to calculate those of internal links
        adjust_border_links(Submodel). */

unclick :-
	retractall(clicked_obj_is(_Obj)),
	retractall(menu_submodel_will_be(_,_,_)),
	get_mode(select),
	    find_current(Wid),
	    get_phase(rubberband), !, /* used to call proc below */
	    get_incomplete(Box),
	    get_translation(Trans),
	    untranslate(Box, Trans, [OldX, OldY, NewX, NewY]),
	    clear_incomplete,
	    L is min(OldX, NewX),
	    T is min(OldY, NewY),
	    R is max(OldX, NewX),
	    B is max(OldY, NewY),
	    Wid shows_model Model,
	    (select_bagged([L, T, R, B], Model);
	    set_selection_abilities(Model),
	    remove_old_rubberband),
	    initialize_phase;
	get_phase(action_choice), !,
		advance_phase_to(targetting);
	unclick_obj.

select_bagged(Rect, Model) :-
	get_overlaps(Model, Rect, Caught),
	(find_type(Caught, submodel),
	    add_to_translation([0,0,1,1], Caught, Trans),
	    translate(Rect, Trans, NewRect),
	    select_bagged(NewRect, Caught);
	 \+ (get_shape(Caught, bounding_box, Outer),
		fits_inside(Rect, Outer)),
	    \+ deselectable(Caught),
	    do_colours(Caught, on),
	    fail).
/*
zoom_to_area :-
	get_incomplete([OldX, OldY, NewX, NewY]),
	get_box_size(submodel, Standard),
	(abs(NewX-OldX) < Standard//2;
	abs(NewY-OldY) < Standard//2;
	find_current(Wid),
	    display_area(Wid)), !,
	remove_old_rubberband.
*/
unclick_obj :-
	(retract(instant_link(New_obj));
	 get_mode(add),
	    get_adding_object(New_obj)),
	get_current_node(Parent), 
	(New_obj is_class_of_sort line,
		(get_phase(dragging),
		    get_line_start_obj(OrigStart),
		    get_line_finish_obj(Finish_thing),
		    get_nearest_equivalent_link(New_obj, OrigStart,
						Finish_thing, Start_thing),
		    (Finish_thing = none, !,
			get_highlit_obj(0, WrongFinish),
			normalize(WrongFinish);
		    make_terminator(New_obj, Finish_thing, Terminator),
			normalize(OrigStart),
			normalize(Finish_thing),
			(var(Terminator), !;
			    (find_type(Terminator, TType),
				\+ member(TType, [submodel, cloud]), !;
			    draw_line_to(Start_thing, New_obj, Terminator)),
			    tie_ends(New_obj, Start_thing, Terminator),
			    (TType is_class_of_sort box, !;
				m_class:follows(Replacer, Terminator),
				menu:reroute_sections([Replacer,
						       Terminator])))),
		    clear_incomplete,
		    remove_old_incomplete;
		get_phase(barge),
		    /* Initial click on something that could not start line */
		    get_highlit_obj(0, WrongStart),
		    normalize(WrongStart)),
		    initialize_phase;
		
	New_obj is_class_of_sort rounded_rect,
	    get_phase(rubberband),
	    initialize_phase,
	    get_incomplete([OldX, OldY, NewX, NewY]),
	    clear_incomplete,
	    remove_old_rubberband,
	    L is min(OldX, NewX),
	    T is min(OldY, NewY),
	    R is max(OldX, NewX),
	    B is max(OldY, NewY),
	    attempt_new_component(Parent, [L, T, R, B]);
	New_obj is_primitive,
	    \+ New_obj is_class_of_sort line),
	update_runnable(Parent).

unclick_obj :- 
	get_mode(select), /* was move */
	get_moving_obj(Submodel),
	(get_phase(moving_border(_)), !,
	    get_shape(Submodel, internal_extent, NewSize),
	    adjust_toplevel_windows(Submodel, NewSize);
	true),
	initialize_phase,
	(\+ retract(moved_something), !;
	finish_move(Submodel, 0)).

/* Unclick in ghost mode. If unclicking in space, a new ghost node is created. If
unclicking on an existing node this node is made into a ghost of the source node
if it is of a suitable type. The target node's own equation information remains,
but is not usable or editable until it becomes de-ghosted. */

unclick_obj :-
	get_mode(ghost),
	get_phase(dragging),
	initialize_phase,
	get_current_node(Parent),
	get_incomplete(Box),
	remove_old_rubberband,
	ghost_type(Start, GhostType, Base),
	normalize(Start),
	((get_highlit_obj(2, Component_name);
	attempt_addition(GhostType, Parent, Box, Component_name, no, yes), !,
	        redisplay(Component_name)),
	    get_nearest_equivalent_link(ghost_link, Base,
					Component_name, OutLink),
	    reghost(Component_name, OutLink);
	do_dialogue("Ghosting error", error, "Unable to make ghost here",
		ok, _)),
	update_runnable(Parent).

/* this clause handles deletion. If it is a submodel, the links that
will become surplus are undisplayed, otherwise delete_net is
called.

unclick_obj :-
	get_mode(delete),
	get_phase(delete_hunt),
	initialize_phase,
	get_current_node(Parent),
	contains(Top, Parent),
	is_toplevel(Top),
	delete_net(Top),
	update_runnable(Parent).
*/
unclick_obj :-
	(get_phase(barge); get_phase(moving); get_phase(moving_text);
			get_phase(moving_start); get_phase(moving_finish)),
	initialize_phase.

tie_ends(New_obj, Start_thing, Terminator) :-
	link_ends(New_obj, Start_thing, Terminator, LastArc),
	reuse_route(New_obj, LastArc).

	/* 
	(find_all_comps(TopBox, Top_arc),
	    image:has_outer_equiv(Top_arc, TopBox, Join), !,
	    event:thread_link(Join);
	event:thread_link(Top_arc)).

Clever bit: reuse the route of the rubberband link for the newly added one */
reuse_route(New_obj, LastArc) :-
        find_current(Wid),
	Wid shows_model Parent,
	find_base(LastArc, BowtieArc),
        ((NewArc = LastArc; m_class:sequence(NewArc, LastArc)),
	    find_all_comps(Node, NewArc),
	    get_incomplete([Node | ScreenRoute]),
	    translate_between(Parent, Node, _D, Trans),
	    translate(ScreenRoute, Trans, Route),
	    set_shape(NewArc, course, Route),
	    update_bowtie(NewArc, Route),
	    redisplay(NewArc),

	    (New_obj = relation,
		get_boundary_end(NewArc, true);
	    New_obj is_class_of_sort has_bowtie,
		NewArc = BowtieArc),
	    give_focus(NewArc),
	    do_colours(NewArc, on),
	    select_text(Wid, NewArc),
	    fail;
	 true).

ghost_type(Start, Type, Base) :-
	get_line_start_obj(Start),
	find_base(Start, Base),
	find_type(Base,StartType),
	Type = StartType.

/* event-level interface to ghost creation. This identifies a
node's current ghost state, if it is a ghost it unghosts it,
undrawing any ghost links that were there, then ghosts it to the new base if there is one, displaying the links. */

reghost(Ghost, Base) :-
	ghost_link(Link, _, Ghost),
		off(Link),
		fail;
	make_ghost(Ghost, Base, TopLink),
		thread_link(TopLink),
		change_ghosthood(Ghost).

change_ghosthood(Node) :-
/*	make_links_follow(Node), */
	spread_colour(Node, yes).

delete_by_dlg(Target) :-
	remove_highlights,
	recursive_highlight(Target, on, base);
	contains(Top, Target),
	is_toplevel(Top),
	delete_net(Top).
	
/* update_runnable: When a change is made to the display that would
cause the model to behave differently if rebuilt, this sets a value in
the Tcl side of things which causes a warning to be displayed before
running the old version.

For multiple code objects, it also records that this particular submodel's code
must be rebuilt when the next runnable model is made. */

update_runnable(Parent) :-
	finish_move(Parent, 1).

/* this routine quickly inserts a new component if a flow or influence is dropped in
the middle of nowhere; only clouds on flows for now. 

It also directs a connection to a node's 'implicit function', creating this if the node previously had none. */

make_terminator(LineType, FinishZone, Terminator) :-
	find_type(FinishZone, submodel),
	    member(LineType, [flow, squirt]), TermType = cloud,
	    /* set influence/variable as alternative if required */
	    get_current_coords(FinalX, FinalY), !,
	    (add_at_point(FinalX, FinalY, TermType, FinishZone, Terminator),
		redisplay(Terminator);
		true), !;
	 LineType = influence,
	    FinishZone is_of_sort has_function,
            (implicit_function(FinishZone, Terminator);
		add_implicit_function(FinishZone, Terminator)), !;
	    Terminator = FinishZone.

/* delete_net deletes everything highlit. It orders them
influences-flows-nodes so nothing has been consequentially deleted
when its time comes. */

delete_net(Top) :-
	tk_get_pref(deleteEndToEnd, FollowArcs),
	setof(Tgt, (doomed(Tgt),
		       \+ Tgt = Top,
		       deletable(Top, FollowArcs, Tgt)), Range),
	(member(Target, Range),
	    find_type(Target, influence),
	    (\+ is_top_arc(Target);
	    is_top_arc(Target),
		find_all_comps(Sm, Target),
		add_parameter(Sm, 1, c_new, 0));
	member(Target, Range),
	    find_type(Target, Line),
	    member(Line, [flow, squirt, relation]);
	member(Target, Range),
	    Target is_of_sort box,
	    \+ find_type(Target, submodel);
	member(Target, Range),
	    find_type(Target, submodel),
	    (find_all_links(Target, OldLink),
		has_outer_equiv(InLink, Target, OldLink),
		off(InLink),
		fail;
	    true),
	    dissolve_component(Target)),
	    
	kill_primitive(Target); 
	/* now un-highlight and redisplay the ghosts of the dead node
	*/
	get_highlit_obj(2, ExGhost),
	    contains(Top, ExGhost),
	    normalize(ExGhost),
	    change_ghosthood(ExGhost),
	    fail;
	set_selection_abilities(Top).

deletable(Top, FollowArcs, Tgt) :-
	contains(Top, Tgt), !;
	FollowArcs = 1,
	    m_class:equivalent_arcs(Tgt, InTgt),
	    get_highlit_obj(M, InTgt), M<3,
	    contains(Top, InTgt).

kill_primitive(Target) :-
	off(Target),
	(setof(NewLook, (presence_affects(Target, NewLook),
			    \+ doomed(NewLook)), ChangedLooks), !;
	    ChangedLooks = []),
	forget_highlit_obj(_, Target),
	(tk_get_pref(deleteEndToEnd, 1), /* no messing about */
	    fast_delete(Target);
	tk_get_pref(deleteEndToEnd, 0),
	    do_delete(Target)),
	member(NewVisLook, ChangedLooks),
	    spread_colour(NewVisLook, yes), /* Only need to update dims
					    if arc is a relation */
	    update_captions(NewVisLook),
	    fail.

embrace(Wid, Obj) :-
	Wid shows_model Comp,
	set_selection_abilities(Comp),
	(Obj = 0, !;
	give_focus(Obj) /* ,
	highlight(Obj, 0) */).

set_selection_abilities(Comp) :-
	(contains(Comp, Lit), \+ Lit = Comp,
	    get_highlit_obj(N, Lit),
	    N<2, !,
	    Cuttable = 1,
	    Dellable = 1;
	contains(Comp, Lit), \+ Lit = Comp,
	    get_highlit_obj(2, Lit), !,
	    Cuttable = 0,
	    Dellable = 1;
	Cuttable = 0,
	    Dellable = 0),
	use_pref_dir(Dir),
	append_atoms(Dir, '/clipboard.pl', CopyFile),
	(output:my_file_exists(CopyFile), !,
	    Pastable = 1;
	Pastable = 0),
	update_ability(Comp, none, edit, 'Cut', Cuttable),
	update_ability(Comp, none, edit, 'Copy', Cuttable),
	update_ability(Comp, none, edit, 'Paste', Pastable),
	update_ability(Comp, none, edit, 'Delete', Dellable),
	update_ability(Comp, none, edit, '{Reroute links}', Dellable),
	update_ability(Comp, none, edit, '{Align to grid}', Dellable).
	
abandon :-
	finish_old_edit(none).

abandon_eqn /* :-
	normalize(_Obj) */ .

/* This will make a new node at the given position if the 4th
arg is var, or move the given node there if it is not. Fails if it
interferes with another component -- the test previously used picks,
but now uses get_component_from_gui because it is quicker. */

attempt_addition(Type, Parent, Box, Node_name, CanBag, Verbal) :-
	/* check it is inside its parent */
	get_shape(Parent, internal_extent, Parent_size),
	fits_inside(Box, Parent_size),

	/* If CanBag is 'yes' the new box can be put around existing ones */
	\+ (get_overlaps(Parent, Box, Other),
	       (CanBag = no;
		   get_shape(Other, bounding_box, WeeBox),
		   \+ fits_inside(WeeBox, Box))),
	
/* check it is not inside a submodel (GUI only checks border interference)
	\+ (find_all_comps(Parent, OtherSubmodel),
	       find_type(OtherSubmodel, submodel),
	       get_shape(OtherSubmodel, bounding_box, OtherSubSize),
	       fits_inside(Box, OtherSubSize)), */
	
	(nonvar(Node_name);
	make_node(Parent, Type, Node_name),
		add_implicit_function(Node_name, _)), !,
	set_shape(Node_name, bounding_box, Box),
	make_links_follow(Node_name);
	sicstus_format_to_chars("Cannot add a ~a here due to overlaps.",
				[Type], Wibble),
	Verbal = yes,
	do_dialogue("Failed to add component", warning, Wibble, ok, _),
	fail.

attempt_new_component(Parent, Box) :-
	Box = [L,T,R,B],
	W is R - L,
	H is B - T,
	get_box_size(Parent, submodel, Standard),
	W > Standard//2,
	H > Standard//2,
	attempt_addition(submodel, Parent, Box, Node_name, yes, yes),
	tk_get_pref(defBackground, DefBG),
	member([DefFill, DefBG], [[clear, 'Clear'], [white, 'White']]),
	add_parameter(Node_name, 0, fill_colour, DefFill),
/* List components inside the box */
	get_inclusions(Parent, Box, Contents),

	/* Undisplay arcs that will not exist after the operation...*/
	(one_end_in(Contents, Arc), 
		off(Arc), 
		clear_shape(Arc, _),
		fail;
	true),
	encapsulate(Contents, Node_name),
	set_shape(Node_name, internal_extent, [0,0,W,H]),
	add_to_translation([0, 0, 1, 1], Node_name, Node_trans),
	relate_graphics(Node_name, Node_trans),
	redisplay_border(Node_name),
	find_current(Wid),
	give_focus(Node_name),
	do_colours(Node_name, on),
	select_text(Wid, Node_name).

relate_graphics(Node_name, Node_trans) :-
	move_boxes(Node_name, Node_trans),
	(setof(DoLink,
	      Link^(find_all_links(Node_name, Link),
		    (has_outer_equiv(DoLink, Node_name, Link); DoLink = Link)),
	      MessedLinks), !,
	    menu:reroute_sections(MessedLinks);
	true),
	remove_old_incomplete.
 /* re-route flows first so influences to re-routed bowties come out right.
 Note only cross border flows need rerouting. 
	((find_all_links(Node_name, Link), find_type(Link, flow);
	find_all_links(Node_name, Link), \+ find_type(Link, flow)),
	    (has_outer_equiv(DoLink, Node_name, Link); DoLink = Link),
	    update_link_route(DoLink, yes),
	    redisplay(DoLink),
	    make_links_follow(DoLink),
	    fail;
	true). */

move_boxes(Node_name, Node_trans) :-
	find_all_comps(Node_name, Thing),
	adjust_posn(Thing, Node_trans),
	fail; true.

resnap(Node, SelOnly) :-
	find_all_comps(Node, Bit),
	(SelOnly = 0; SelOnly = 1, doomed(Bit)),
	get_shape(Bit, bounding_box, BB),
	(add_to_translation([0,0,1,1], Bit, Trans), % bit is submodel
	    snap_to_grid(BB, NBB),
	    translate(NBB, Trans, [L, T, R, B]),
	    IW is R-L, IH is B-T,
	    change_shape(Bit, internal_extent, [0, 0, IW, IH]),
	    move_boxes(Bit, [L, T, 1,1]),
	    change_shape(Bit, bounding_box, NBB),
	    (SelOnly = 0; SelOnly = 1, resnap(Bit, 1)),
	    redisplay_border(Bit);
	 find_type(Bit, New_obj),
	 \+ New_obj = submodel,
	    middle(BB, [XMid, YMid]),
	    snap_to_grid([XMid, YMid], [Xpt, Ypt]),
	    use_style_for(New_obj, NewObjStyle),
	    get_box_size(Node, NewObjStyle, Cur_size),
	    make_bounding_box(New_obj, Xpt, Ypt, Cur_size, NBB),
	    XOff is Xpt-XMid, YOff is Ypt-YMid,
	    change_shape(Bit, bounding_box, NBB),
	    move_display(Bit, [XOff,YOff])),
	fail; true.

adjust_posn(Thing, Trans) :-
	get_shape(Thing, Whatever, Wherever),
	\+ Whatever = internal_extent,
	(Whatever = caption_offset,
	    rel_translate(Wherever, Trans, New_wherever);
	\+ Whatever = caption_offset,
	    translate(Wherever, Trans, New_wherever)),
/*	(member(Trans, [[_,_,1,1], [_,_,1.0,1.0]]), !,
	    NewOnGrid = New_wherever;
	snap_to_grid(New_wherever, NewOnGrid)),
*/
	change_shape(Thing, Whatever, New_wherever),
	fail; true.

dissolve_component(Node) :-
	find_all_comps(Parent, Node),
	subtract_from_translation([0,0,1,1], Node, Node_trans),
	(move_boxes(Node, Node_trans),
	(setof(Part, m_class:Node has_part Part, Orphan_nodes), !;
	    Orphan_nodes = []),
	(setof(IntLink, 
	   (IntLink draws_inside Node, \+ has_outer_equiv(IntLink, Node, _)),
	       OrphanLinks), !; OrphanLinks = []),
	append(Orphan_nodes, OrphanLinks, Orphans),
	(list_captions(Parent, Used), !,
	    all(event, retitle_duplicate, [build(Orphans), unify(Used)]);
	true),
	    
	/* First, strip the model's dimensions and check external vars */
	(get_all_dims(Node, []), !;
	add_parameter(Node, 0, assume_simple, 1),
	    spread_colour(Node, yes)),
	/* next, set its internal extent to its bounding box so I can snap its
	    already-moved components to the parent's grid */
	get_shape(Node, bounding_box, BB),
	change_shape(Node, internal_extent, BB),
	resnap(Node, 0),
	    
	(has_outer_equiv(Inner, Node, Outer),
		/* demolition process will delete section nearest source so off this */
		off(Inner), off(Outer), fail;
	unencapsulate(Node, Orphan_nodes, MovedLinks)),
	    /* Now everything from the dead submodel must be redisplayed
	    because its fatness will have changed to match the new parent */
	(member(OrphanNode, Orphan_nodes),
	    redisplay_border(OrphanNode),
	    fail;
	member(MovedLink, MovedLinks),
	    update_link_route(MovedLink, yes),
	    redisplay(MovedLink),
	    make_links_follow(MovedLink),
	    fail;
	member(OrphanLink, OrphanLinks),
	    redisplay(OrphanLink), /* also need to change endpoints */
	    fail;
	true)).

list_captions(Parent, Used) :-
	setof(UsedCaption,
	      Part^(find_all_comps(Parent, Part),
		    appears(Part),
		    \+ is_ghost(Part),
		    caption_for(Part, UsedCaption)),
	      UsedNow), !,
	append(UsedNow, _, Used).

retitle_duplicate(Node, Used) :-
	caption_for(Node, OldCapt),
	ensure_unused(OldCapt, NewCapt, Used, []),
	(NewCapt = OldCapt, !;
	(Name_type = 0; Name_type = 2),
	    add_parameter(Node, Name_type, name, NewCapt), !,
	    update_captions(Node)).

remove_highlights :-
	get_highlit_obj(_, Old_doomed_thing),
	normalize(Old_doomed_thing),
	fail.

remove_highlights.

prioritize_window(New_top) :-
	make_current(New_top).

run_settings_tweaked(Node) :-
	update_ability(Node, save, file, 'Save', 1).
