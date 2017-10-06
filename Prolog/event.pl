/*
event_handle.pl
---------------
This contains the code for responding to events signalled by the user 
interface of the application. It responds by:
* Querying and updating the GUI state representation
* Calling the model maintenance module to add information to the model
* Making calls to the screen drawing module (new image, or redraw)
*/
sicstus_module(event, [get_info/4, context_find/3, get_params/2, get_triggers/2,
		       bar_edit_menu/1,
		       click_obj/4, click_text/4, click/3, do_colours/2,
		       insert_variable/5,
	finish_old_edit/1, doubleclick_obj/3, doubleclick/2,
	unclick/0, embrace/2, abandon/0, abandon_eqn/0, drag/2,
		       resize_top_win/3, adjust_display_area/2,
		       prioritize_window/1, run_settings_tweaked/1]).

sicstus_use_module([sp_only, forms, m_update, image, draw,
		    state, backup, submodel, ame_gen, utility,
		    library(lists), library(ordsets)]).

units_for(Comp, UnitStr) :-
	(find_node_with_data(Comp, _, Func),
	    get_av_pair(Func, 0, units, Units),
	    analyze_array(Units, Base, Dims);
	 find_type(Comp, submodel),
	    (get_av_pair(Comp, 0, multiplication_spec, Spec),
		member(count=Dims, Spec), !;
		Dims = []),
	    Base = submodel),
	to_text_prefix(Dims, Pref),
	(Base = 1, !, append(Pref, "real", UnitStr);
	sicstus_format_to_chars("~s~w", [Pref, Base], UnitStr)).

to_text_prefix([], "").
to_text_prefix([Solo], Text) :-
	sicstus_format_to_chars("~w of ", [Solo], Text), !.
to_text_prefix([First | Rest], Text) :-
	to_text_prefix(Rest, Tail),
	sicstus_format_to_chars("~wx~s", [First, Tail], Text).

follow_seln_infs(Dir, End) :-
	doomed(Comp),
	Comp is_of_sort has_function,
	(Dir = any,
	    End = Comp;
	 value_propagates(Dir, Comp, End, _Link),
	    \+ doomed(End)).

value_propagates(Dir, From, To, Link) :-
	find_base(From, Base),
	(UseComp = Base; find_ghosts(Base, UseComp)),
	(Dir = none,
	    To = UseComp;
	  (implicit_function(UseComp, Fn) -> true; Fn = UseComp),
	    (Dir = out,
	      (m_class'><'UseComp is_connector _ -> StartsInfs = Fn;
		  StartsInfs = UseComp),
	      m_class'><'connects(Link, StartsInfs, Next),
	      find_type(Next, function),
	      get_host(Next, To);
	    Dir = in,
	      m_class'><'connects(Link, StartsInfs, Fn),
	      get_host(StartsInfs, To)),
	    find_type(Link, influence)).

multi_prop(Dir, From, To, Count) :-
	To = From;
	Count > 0,
	   On is Count-1,
	   value_propagates(Dir, From, Mid, Link),
	   (To = Link;
	   multi_prop(Dir, Mid, To, On)).

build_suffix([], "").
build_suffix([H | T], Suffix) :-
	build_suffix(T, Tail),
	((H = []; Tail = ""), !,
	    append(H, Tail, Suffix);
	append([H, " ", Tail], Suffix)).

get_info(_Wid, Comp, enum_type_defns, ETDefns) :-
	(find_type(Comp, submodel), !,
	    % just get defns for this submodel level
	    m_update'><'enum_types_for(Comp, ETDefns, yes);
	  % if not a submodel, get all applicable enum types
	    find_all_comps(MotherShip, Comp),
	    get_all_enum_types(MotherShip, ETDefns)).

get_info(_Wid, Comp, colour, ColorSpec) :-
	get_av_pair(Comp, 0, fill_colour, ColorSpec), !;
	ColorSpec = white.

get_info(_Wid, selection, Dir, Ends) :-
	(setof(End, follow_seln_infs(Dir, End), Ends); Ends = '').
	
get_info(_Wid, Comp, eqn, Eqn) :-
	pick_equation(Comp, Eqn);
	Eqn = '<none>'.

get_info(_Wid, Comp, type, SubType) :-
	find_type(Comp, Type),
	((Type = event, is_parameter(Comp, 1)) -> % a limit event
	    SubType = limit;
	  SubType = Type).

get_info(Wid, Comp, context, DescAtm) :-
	find_type(Comp, LType),
	(LType is_class_of_sort captionless, !,
	    Part1 = "";
	caption_for(Comp, Capt),
	    name(Capt, CaptStr),
	    append(CaptStr, " . ", Part1)),

	(LType = submodel,
	    image'><'quick_file(Comp, Middle);
	find_node_with_data(Comp, _, Fn),
	    eqn_for(Fn, MiddleAtm),
	    name(MiddleAtm, Mid0),
	    ((LType = event, is_parameter(Comp, 1)) -> % a limit event
		(get_av_pair(Fn, 0, min_val, Min) ->
		    sicstus_format_to_chars("~s below ~w", [Mid0, Min], Mid1);
		  Mid1 = Mid0),
		(get_av_pair(Fn, 0, max_val, Max) ->
		    sicstus_format_to_chars("~s above ~w", [Mid1, Max], Middle);
		  Middle = Mid1);
		Middle = Mid0);
	ghost_link(Comp, _,_),
	    Middle = "ghost link";
	name(LType, Middle)), !,

	(units_for(Comp, Suffix1), !;
	Suffix1 = ""),
	Wid shows_model Context,
	(setof(Dest, m_update'><'connects(Comp, Source, Dest), DestList), !,
	    /* note Source is an ordinary variable in the above, all dests will
	    be found because it is always the same */
	    (\+ find_type(Source, cloud), !,
		abs_path_name(Source, Context, SourceLoc), !,
		sicstus_format_to_chars("from ~a", [SourceLoc], Suffix2);
	      Suffix2 = []),
	    (member(RealDest, DestList),
		\+ find_type(RealDest, cloud),
		all(event, abs_path_name,
		    [build(DestList), unify(Context), build(LocList)]),
		(LocList = [DestLocs]; DestLocs = LocList), !,
		sicstus_format_to_chars("to ~w", [DestLocs], Suffix3);
	      Suffix3 = []);
	  Suffix2 = [],
	    Suffix3 = []),
	
	build_suffix([Suffix1, Suffix2, Suffix3], Suffix),
	(Suffix = "", !,
	    append(Part1, Middle, Desc);
	append([Part1, Middle, " (", Suffix, ")"], Desc)),
	name(DescAtm, Desc).

get_info(_Wid, Comp, units, Unit) :-
	units_for(Comp, UnitStr),
	name(Unit, UnitStr), !.

get_info(_, Name, is_unit, Def) :-
	(units'><'defined_as_unit(Name, Def), !;
	Def = none).

get_info(_, Comp, Field, Pop) :-
	% catch-all clause to get any attribute value
	(find_type(Comp, relation), !,
	    find_name_host(Comp, Base);
	 find_node_with_data(Comp, Base, Fn)),
	(member(Field, [min_val, max_val]) -> Tgt = Fn; Tgt = Base), 
	get_av_pair(Tgt, _, Field, Pop).

context_find(Wid, Query, Target) :-
	callback('{}'),
	menu_submodel_is(Model, _),
	contains(Model, Sub),
	find_all_comps(Sub, Comp),
	appears(Comp), %     check draws_at as well
	(Target = description,
	    (get_info(Wid, Comp, description, Field);
	    get_info(Wid, Comp, comment, Field));
	 Target = equation,
	    get_info(Wid, Comp, eqn, Field),
	    \+ Field = '<none>';
	 Target = caption,
	    \+ Comp is_of_sort captionless,
	    caption_for(Comp, Field)),
	name(Query, QueryStr),
        sicstus_format_to_chars("~w", [Field], FieldStr), % state eqn not atom
	squint_at(QueryStr, LQueryStr),
	squint_at(FieldStr, LFieldStr),
	is_infix(LQueryStr, LFieldStr),
	append_callback(Comp),
	fail; true.

squint_at(Str, FlatStr) :-
	lower(Str, LStr),
	[CR, Sp] = "\n ",
	substitute(CR, LStr, Sp, FlatStr).

is_infix(In, Out) :-
	prefix(Start, Out),
	suffix(In, Start), !.
	
insert_mem_list(Bound, Model, Trans) :-
	(Bound = boolean,
	    Trans = [false, true];
	get_av_pair(Model, 0, enum_types, Pairs),
	    member(Type-Mems, Pairs),
	    append_atoms(['"', Type, '"'], QType),
	    member(Bound, [QType, a(Type)]), /* allow units to make trans */
	    Trans = [Type | Mems];
	find_all_comps(Parent, Model),
	    insert_mem_list(Bound, Parent, Trans);
	Trans = []), !.

get_params(_, Comp) :-
	find_node_with_data(Comp, _, Func),
	get_input_info(Func, Params),
	output'><'get_from_list(Params, Table),
	callback(br(Table)).

get_triggers(_, Comp) :-
	find_node_with_data(Comp, _, Part),
	list_evt_captions(Part, EvtCapts),
	output'><'safe_list(EvtCapts, EvtCaptList),
	callback(EvtCaptList).
	
:- dynamic(min_size_is/1).
:- dynamic(max_size_is/1).
:- dynamic(clicked_obj_is/1).

click_obj(Xpt, Ypt, Name, CD) :-
	check_snap,
	assert(clicked_obj_is(Name)),
	find_current(Wid),
	find_relevant_windows(Name, Wid, Depth, Trans),
	translate([Xpt, Ypt], Trans, [NewXpt, NewYpt]),
%	snap_to_grid(ActNewPt, [NewXpt, NewYpt]),
	set_original_click(Xpt, Ypt),
	find_all_comps(Parent, Name),
	save_params(Trans, Depth, Parent),
	(CD < 2, doing_add(submodel), !,
	     set_start_coords(Xpt, Ypt),
	     set_current_coords(Xpt, Ypt), 
% could offset them to actually include component clicked on
	     set_line_start_obj(Parent),
	     advance_phase_to(action_choice);
	 get_phase(targetting),
	    check_same_desktop(Parent), !,
	    advance_phase_to(dragging),
	    get_mode(Mode),
	    menu'><'set_cursor_for(Mode),
	    drag_to(NewXpt, NewYpt, Name);
	(CD < 2, click_on([NewXpt, NewYpt], Name, CD), !; true),
	adjust_edit_menu(Wid, Parent, Name),
	set_selection_abilities(Parent),
	(get_phase(moving),
	    /* highlight(Name, 2), */
	 find_type(Name, Type),
	 member(Type, [image, submodel]), !,
	    get_closest_edge(Name, [NewXpt, NewYpt], Edge, [EfX, EfY]),
	    % now adjust start point so dragged edges align to grid
	    XToGrid is EfX-NewXpt,
	    YToGrid is EfY-NewYpt,
	    snap_to_grid([XToGrid, YToGrid], [XOnGrid, YOnGrid]),
	    XForGrid is EfX-XOnGrid,
	    YForGrid is EfY-YOnGrid,
	    set_start_coords(XForGrid, YForGrid),
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
		get_phase(Phase),
		member(Phase, [moving, moving_kink, moving_border(_Pt),
			       moving_bowtie, moving_spline, rubberband]),
		% click_on will have set start to centre of component! So...
		get_translation(Trans),
		translate([Xpt, Ypt], Trans, [StX, StY]),
		set_start_coords(StX, StY),
		advance_phase_to(moving_text)).
/*
click: Handles mouse clicks in a model window.
*/
click(Xpt, Ypt, CD) :-
	check_snap,
	Trans = [0, 0, 1, 1],
	Depth = 0,
	find_current(Wid),
	Wid shows_model Parent,
	(get_phase(targetting),
	    check_same_desktop(Parent), !,
	    advance_phase_to(dragging),
	    get_mode(Mode),
	    menu'><'set_cursor_for(Mode),
	    (multi_level_mode -> save_params(Trans, Depth, Parent); true),
	    drag(Xpt, Ypt);
	get_phase(peruse),
	    set_original_click(Xpt, Ypt),
	    click_in(Wid, [Xpt, Ypt], Trans, Depth, Parent, CD)).

/* check we are in same model we started in */
check_same_desktop(Parent) :-
	get_line_start_obj(StartNode),
	(contains(Top, StartNode),
	    is_toplevel(Top),
	    contains(Top, Parent);
	normalize(StartNode),
	    advance_phase_to(peruse),
	    fail).

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
:- dynamic(currently_moving_set/1).
:- dynamic(grid_pitch_is/2).

set_snap :-
        output'><'tk_get_pref(gridH, HGR),
        output'><'tk_get_pref(gridV, VGR),
        assert(grid_pitch_is(HGR, VGR)).

check_snap :-
	retractall(grid_pitch_is(_,_)),
	(tk_get_pref(gridSnap, 0), !,
	    assert(grid_pitch_is(1,1));
        set_snap).
	
snap_to_grid([], []).

snap_to_grid([X, Y | Rest], [GX, GY | GRest]) :-
	grid_pitch_is(HPitch, VPitch), !,
	    GX is HPitch*round(X/HPitch),
	    GY is VPitch*round(Y/VPitch),
	    snap_to_grid(Rest, GRest);
	 [GX, GY | GRest] = [X, Y | Rest].

snap_to_grid([Pair | Rest], [NewPair | NewRest]) :-
	snap_to_grid(Pair, NewPair),
	snap_to_grid(Rest, NewRest).


click_in(Wid, Point, Trans, Depth, Parent, CD) :-
	% click is inside a child submodel; pass it on 
	targets(Wid, Parent, Point, Depth, Child), !, 
	click_on_sub(Wid, Point, Trans, Parent, Depth, Child, CD).

click_in(_Wid, Point, Trans, Depth, Parent, CD) :-
    % click is inside an image; pass it on
    get_mode(select),
    m_class'><'Parent has_part Child,
    get_drawing_form(Child, image, BBox),
    inside_shape(Parent, Point, image, BBox), !,
    save_params(Trans, Depth, Parent),
    click_on(Point, Child, CD),
    set_selection_abilities(Parent).

click_in(Wid, Point, _,_, Parent, CD) :-
	% right click; get ready to post menu
	CD = 2,
	snap_to_grid(Point, GPoint),
	adjust_edit_menu(Wid, Parent, GPoint).

click_in(Wid, ActPt, Trans, Depth, Parent, _CD) :-
	% Start adding a component to current submodel
	finish_old_edit(none),
	doing_add(New_obj),
	(new_selection(Parent); % new comp will be only one selected
	save_params(Trans, Depth, Parent)),
	snap_to_grid(ActPt, [Xpt, Ypt]),
	set_start_coords(Xpt, Ypt),
	set_current_coords(Xpt, Ypt),
	Wid shows_model Top,
	contains(Top, Parent, Ladder),
	check_drawing_at_depth(Wid, Ladder, New_obj, Depth),
	(New_obj is_class_of_sort box, !,
	    (New_obj is_class_of_sort rounded_rect, !,
		set_line_start_obj(Parent),
		advance_phase_to(action_choice);
	    insert(Wid, Parent, [Xpt, Ypt], New_obj));
	make_terminator(New_obj, Parent, DropNode),
	    (var(DropNode), !;
		do_linear(New_obj, DropNode))).

click_in(Wid, _,_,_, Parent, CD) :-
	/* Drag a selected submodel by a point in its background */
	get_mode(select),
	get_highlit_obj(0, Parent),
	\+ Wid shows_model Parent, /* no drag submodel in own window */
	CD = 0, !, /* no drag if ctrl down */
	get_original_click(Orig_X, Orig_Y),
	get_translation(BackTrans),
	translate([Orig_X, Orig_Y], BackTrans, ActOrig),
	snap_to_grid(ActOrig, [Xtr, Ytr]),
	set_current_coords(Xtr, Ytr),
	click_on([Xtr, Ytr], Parent, CD).

click_in(_Wid, ActOrig, Trans, Depth, Parent, CD) :-
	/* Background of unselected submodel, or ctrl down: select a region */
	get_mode(select),
	save_params(Trans, Depth, Parent),
	snap_to_grid(ActOrig, [Xtr, Ytr]),
	set_start_coords(Xtr, Ytr),
	(CD = 0,
	    new_selection(Parent);
	 add_incomplete([Xtr, Ytr, Xtr, Ytr]),
	    draw_rubberband(square),
	    advance_phase_to(rubberband)).
	    
new_selection(Parent) :-
	contains(Top, Parent),
	is_toplevel(Top), !,
	contains(Top, Comp),
	normalize(Comp),
	fail.

insert(Wid, Parent, [Xpt, Ypt], New_obj) :-
	add_at_point(Xpt, Ypt, New_obj, Parent, NewNode),
	redisplay(NewNode),
	give_focus(NewNode),
	do_colours(NewNode, seln),
	select_text(Wid, NewNode),
	(setof(NewLook, presence_affects(NewNode, NewLook), NewLooks), !;
	    NewLooks = []),
	all(event, spread_colour, [build(NewLooks), unify(dims)]).

check_drawing_at_depth(Wid, Levels, New_obj, Depth) :-
	(\+ (member(Hider, Levels),
		get_shape(Hider, hide_contents, 1)),
	    use_style_for(New_obj, NewStyle),
	    draws_at(Wid, NewStyle, Depth), !;
	    query(blind_add(New_obj, Depth), warning, top, [ok], not)).
	    
adjust_edit_menu(Wid, Comp, Point) :-
	retractall(menu_submodel_will_be(Wid, _,_)),
	assert(menu_submodel_will_be(Wid, Comp, Point)).

bar_edit_menu(Wid) :-
	(menu_submodel_will_be(Wid, Comp, Point), !;
% previously we retracted this, but that caused problems for MacOS, which can
% call postcommand twice. Now rely on unclick to retract it.
	Wid shows_model Comp,
%	    get_shape(Comp, internal_extent, Box),
%	    middle(Box, Point)
% point was never used, menu addition chose posn of last mouse click
	    Point = Comp),
	retractall(menu_submodel_is(_, _)),
	assert(menu_submodel_is(Comp, Point)),
	(Comp = Point, !,
	    CanCreate = 0;
	CanCreate = 1),
	(Point = [_,_], !,
	    CanAddNode = 1;
	 CanAddNode = 0),
	use_pref_dir(Dir),
	append_atoms(Dir, '/clipboard.pl', CopyFile),
	(output'><'my_file_exists(CopyFile), !,
	    Pastable = 1;
	Pastable = 0),
	(Wid shows_model Comp, !; %in window bg so they should already be right
	    set_selection_abilities(Comp)),
	Wid shows_model Model,
	(member(Header/LinkType, ['Flow'/flow, 'Influence'/influence,
				  '{Role arrow}'/relation /*, 'Squirt'/squirt */]),
	    ((LinkType = flow, CanAddNode = 1; can_start(LinkType, Point))
	    -> Allow = 1; Allow = 0),
	    update_ability(Model, none, 'edit.add', Header, Allow),
	    fail;
	update_ability(Model, none, edit, '{Add/change component}', CanCreate),
	update_ability(Comp, none, edit, 'Paste', Pastable),
	(find_type(Point, cloud), !,
	    CanAddComp = 1;
	  CanAddComp = CanAddNode),
	all(draw, update_ability,
	    [unify(Model), unify(none), unify('edit.add'),
	     build(['Compartment', 'Variable', 'Submodel', 'State',
		    'Event', 'Squirt', '{Membership control}', '{Text box}']),
	     build([CanAddComp, CanAddNode, CanAddNode, CanAddNode,
		    CanAddNode, CanAddNode, CanAddNode, CanAddNode])])).

click_on(XY, Poss_start, CD) :-
	doing_add(New_obj), !,
	finish_old_edit(none),
	(New_obj is_class_of_sort line,
	    do_linear(New_obj, Poss_start);
	Poss_start is_of_sort cloud,
	    New_obj = compartment,
	    cloud_to_comp(Poss_start);
	find_relevant_windows(Poss_start, Wid, Depth, Trans),
	    find_all_comps(Parent, Poss_start),
	    click_in(Wid, XY, Trans, Depth, Parent, CD)).
/* add extra disjunct here to implement splitting of flows/influences by new
compartments/variables */

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
		   do_colours(Moving_obj, base)),
	    do_colours(Moving_obj, seln);
	/* Control not down: Object already selected */
	deselectable(Moving_obj), !;
	/* Object not selected; clear current, then select */    
	(new_selection(Moving_obj);
	    \+ is_toplevel(Moving_obj),
	    do_colours(Moving_obj, seln))),
	
	(get_highlit_obj(0, Moving_obj),
	    (% align(Moving_obj),
% this was to make a snapping drag always snap to nodes...below does trick!
		find_all_comps(Context, Moving_obj),
		resnap(Context, 1),
		snap_to_grid([Xpt, Ypt], [GX, GY]),
		set_start_coords(GX, GY);
	    true), % clicked on link
 	    (tk_get_pref(quickDrag, 0);
		retractall(ghostly_move(_,_)),
		assert(ghostly_move(Xpt, Ypt))), !,
	    find_all_comps(Parent, Moving_obj),
	    setof(Mover, moves_with_seln(Parent, Mover), Movers),
	    all(draw, tag_movable, [build(Movers)]),
	    assert(currently_moving_set(Movers)),
	    advance_phase_to(moving);
	local_ends(Moving_obj, Start, Finish),
	    (MovingEnd = moving_finish,
		EndBox = Finish;
	    MovingEnd = moving_start,
		EndBox = Start),
	    get_drawing_form(EndBox, border, [EX, EY, EX, EY]),
	    near([EX, EY], [Xpt, Ypt, Xpt, Ypt]), !,
	    advance_phase_to(MovingEnd);
	Moving_obj is_of_sort has_bowtie,
	    get_link_route(Moving_obj, Point_list),
	    image'><'closest_centre([Xpt, Ypt], Point_list, _Miss, _CPt, Posn),
	    (% bowtie_section(Moving_obj, Moving_obj),
		implicit_function(Moving_obj, Fn),
		get_shape(Fn, along, OldPosn),
		abs(Posn-OldPosn)<100, !,
		advance_phase_to(moving_bowtie);
	    % save accidentally moving it by clicking on route
	    length(Point_list, 4),
		abs(Posn-500)<167, !,
		advance_phase_to(moving_kink));
	    Moving_obj is_of_sort curved, !,
		advance_phase_to(moving_spline);
	    % cannot move a feature so keep selecting
	    add_incomplete([Xpt, Ypt, Xpt, Ypt]),
	    advance_phase_to(rubberband)).
	
click_on([Xpt, Ypt], Moving_obj, _CD) :-
	find_type(Moving_obj,TargetSort),
	get_mode(ghost),
	\+ is_ghost(Moving_obj),
	TargetSort is_class_of_sort can_be_ghost,
	advance_phase_to(action_choice),
		
	highlight(Moving_obj, 1),
	set_line_start_obj(Moving_obj),
	get_drawing_form(Moving_obj, _, [L,T,R,B]), !,
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
	get_shape(Poss_start, centre, [Xpt, Ypt]),
	off(Poss_start),
	clear_shape(Poss_start, centre),
	change_class(Poss_start, _, compartment),
	add_implicit_function(Poss_start, _),
	/* use insert_variable to make sure it goes in */
	m_update'><'unique_name_for_new(Parent, compartment, Name),
	add_parameter(Poss_start, 0, name, Name),
	insert_variable(Parent, Xpt, Ypt, compartment, Poss_start),
	give_focus(Poss_start),
	do_colours(Poss_start, seln),
	find_current(Wid),
	select_text(Wid, Poss_start).

/* add_at_point: places a new 'box' type component in the model, fails if new_obj
is not a box type, or if there is no room at the given position to put the object.
*/

add_at_point(Xpt, Ypt, New_obj, Parent, Comp_name) :-
	member(New_obj, [text]), !,
	    make_node(Parent, New_obj, Comp_name),
	    set_shape(Comp_name, centre, [Xpt, Ypt]);
	attempt_addition(New_obj, Parent, [Xpt, Ypt], Comp_name, no, yes),
	(\+ New_obj = image;
	 set_shape(Comp_name, caption_offset, [90, 90])).

/* as above, but if there is no room it tries to add it nearby rather than failing and complaining */

insert_variable(Submodel, BestX, BestY, New_obj, Comp_name) :-
%	check_translation(Submodel),
	get_shape(Submodel, internal_extent, [L, T, R, B]),
	MaxDist is max(max(BestX - L, R - BestX), max(BestY - T, B - BestY)),
	snap_to_grid([10,10], [Step, _]),
	count_to(0, MaxDist, Step, Distance),
	count_to(0, Distance, Step, Range),
	((TargetX is BestX-Distance; TargetX is BestX+Distance),
	(TargetY is BestY-Range; TargetY is BestY+Range);
	(TargetY is BestY-Distance; TargetY is BestY+Distance),
	(TargetX is BestX-Range; TargetX is BestX+Range)),
	attempt_addition(New_obj, Submodel, [TargetX, TargetY], Comp_name,
			 no, no),
	redisplay(Comp_name), !.	    

deselectable(Obj) :-
	get_highlit_obj(N, Obj),
	( % Obj is_of_sort line, !, N<2;
	  % do not treat click on green line as on selection
	    N<1).

/* do_linear/3: this is executed when a click marks the initial point
of a line object. It moves the editor into a mode in which dragging
will continue the line (not always the case when in line-entry modes
because it might have started at the wrong place). */

do_linear(Ltype, Start_thing) :-
	(can_start(Ltype, Start_thing), !,
		highlight(Start_thing, 1),
		(Ltype = influence, Start_thing is_of_sort has_bowtie,
		    (implicit_function(Start_thing, Fn);
			add_implicit_function(Start_thing, Fn)), !,
		    set_line_start_obj(Fn);
		  set_line_start_obj(Start_thing)),
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
		find_all_comps(Parent, RenamedNode),
		(Name = OldName, !;
		    /* If name exists in submodel or contains dir chars,
		    block the update show message and highlight the node again */
                \+ RenamedNode is_of_sort common_caption,
		 (output'><'safe_list(Name, SafeName),
		  output'><'safe_tcl_eval([string, is, space, SafeName], "1"),
		  	query(invisible_caption(OldName), warning, top,
			      [ok], _);
		     cannot_call_in(RenamedNode, Parent, Name),
			query(caption_clash(OldName, Name), warning, top,
			      [ok], _);
		    name(Name, NameStr),
			member(DodgyChr, "\\./"),
			member(DodgyChr, NameStr),
			name(Dodgy, [DodgyChr]),
			query(dodgy_chars(OldName, Name, Dodgy), warning, top,
			      [ok], _)), !,
		    /* Put old caption back; this is turned on for now */
		    update_captions(Prev_highlight),
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
	find_all_comps(Parent, InSameModel),
	appears(InSameModel),
	\+ InSameModel is_of_sort captionless,
	\+ InSameModel is_of_sort common_caption,
	\+ InSameModel = Prev_highlight,
	(m_class'><'InSameModel has_class_refinement name of Name;
	caption_for(InSameModel, Name)).

change_name(RenamedNode, Name) :-
	(add_parameter(RenamedNode, 0, name, Name);
	    (find_type(RenamedNode, relation), !,
		find_name_host(RenamedNode, ArcWithName);
	    ArcWithName = RenamedNode),
	    add_parameter(ArcWithName, 2, name, Name)),
	((OtherGhost = RenamedNode; status_affects(RenamedNode, OtherGhost)),
	    update_captions(OtherGhost),
	    presence_affects(OtherGhost, Reference),
	    update_default_refs_in_eqns(OtherGhost, Reference),
	    fail;
	 update_captions(RenamedNode)).

update_default_refs_in_eqns(OtherGhost, Reference) :-
	implicit_function(Reference, DownFunc),
	get_av_pair(DownFunc, 0, value, Eqn),
	((setof(InputSpec, P0^P1^P2^P3^P4^P5^P6^
	     (InputSpec = input_link(id(OtherGhost,P1,P2), P3,P4,P5,P6),
		 m_update'><'get_all_links(DownFunc,continuous,P0,InputSpec)),
		InputSpecs) -> % none if source is submodel
	  get_av_pair(OtherGhost, 2, role, Roles),
	  m_update'><'already_used_in(InputSpecs, AllUsed),
	  /* but what about names already used in other links? Should
	replace_subexps first then use old names then set vars */
	  all(event, update_role, [build(Roles), unify(InputSpecs),
				   unify(AllUsed), build(NewRoles)]),
	  add_parameter(OtherGhost, 2, role, NewRoles);
	  Roles = [], NewRoles = []),
	get_av_pair(DownFunc, 0, spec, Spec),
	(find_type(Reference, state) ->
	% now sort out events for state variables. Tricky as we do not
	% have the old caption so we may not know which one was
	% changed. So, list the current ones, pair them off with those
	% in the value, and find the mismatched pair. In the event of a
	% submodel name change there may be many mismatches, if so match
	% them up by tail.
	     list_evt_captions(DownFunc, EvtPaths),
	     fix_mismatched_triggers(Eqn, Spec, EvtPaths, Roles,
				     NewRoles, NewEqn, NewSpec, []),
             \+ NewSpec = Spec; % may loop if it is?
	  replace_subexps(Eqn, event, swap_def_params,
			  [Roles, NewRoles], top_down, _, NewEqn),
	     name(Spec, OldStr),
	     ame_gen'><'update_substrings(OldStr, Roles, NewRoles, NewStr),
	     name(NewSpec, NewStr)),
	add_parameter(DownFunc, 0, value, NewEqn),
	add_parameter(DownFunc, 0, spec, NewSpec),
	fail;
	true).

fix_mismatched_triggers(Eqn, Spec, EvtPaths, Roles,
			NewRoles, NewEqn, NewSpec, SpareTriggers) :-
    (Eqn = (Val on Trigger),
    Spec = (ValAtom on Trigger);
    Eqn = (Val on Trigger, MoreEqn),
    Spec = (ValAtom on Trigger, MoreSpec)),
    replace_subexps(Val, event, swap_def_params,
		    [Roles, NewRoles], top_down, _, NewVal),
    name(ValAtom, OldStr),
    ame_gen'><'update_substrings(OldStr, Roles, NewRoles, NewStr),
    name(NewValAtom, NewStr),

    (select(Trigger, EvtPaths, MoreEvtPaths) ->
	 NewTrigger = Trigger;
     MoreEvtPaths = EvtPaths),
    (nonvar(MoreEqn) ->
	 fix_mismatched_triggers(MoreEqn, MoreSpec, MoreEvtPaths, Roles,
				 NewRoles, NMEqn, NMSpec, AvailTriggers),
	 NewEqn = (NewVal on NewTrigger, NMEqn),
	 NewSpec = (NewValAtom on NewTrigger, NMSpec);
     AvailTriggers = MoreEvtPaths,
         NewEqn = (Val on NewTrigger),
	 NewSpec = (ValAtom on NewTrigger)),
    (nonvar(NewTrigger) ->
	 SpareTriggers = AvailTriggers;
     unchanged_levels(Trigger, Unchanged),
        select(NewTrigger, AvailTriggers, SpareTriggers),
        unchanged_levels(NewTrigger, Unchanged)).

% this needs to cope if a submodel has been added/deleted around the sources
unchanged_levels(Path, KeptLevelStrs) :-
    name(Path, PathStr),
    separate_levels(PathStr, LevelStrs),
    (KeptLevelStrs = LevelStrs; select(_Changed, LevelStrs, KeptLevelStrs)).

separate_levels(PathStr, [Level | Rest]) :-
    append(Level, [47 | MorePathStr], PathStr) ->
	separate_levels(MorePathStr, Rest);
    [Level | Rest] = [PathStr].

update_role(use(P1, P2, Ref, P3), InputSpecs, AllUsed,
	    use(P1, P2, NewRef, P3)) :-
	\+ Ref = usr(_),
	member(input_link(_, Spec, Ref, Unit,_), InputSpecs), !,
	name_from_role_texts(Spec, AllUsed, NewName),
	m_update'><'add_brackets(NewName, Unit, NewRef);
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
	 m_class'><'Parent has_part Child,
	    get_drawing_form(Child, image, BBox),
	    inside_shape(Parent, Rel_point, image, BBox), !,
	    doubleclick_on(Child);
	menu'><'set_properties(Wid, Parent)).

doubleclick_obj(Xpt, Ypt, Name) :-
	retractall(doing_double_at(_,_)),
	assert(doing_double_at(Xpt, Ypt)),
	doubleclick_on(Name).

doubleclick_on(Edit_thing) :-
%	get_mode(select),
	find_type(Edit_thing, Edit_type),
	find_current(Wid),
	contains(TopNode, Edit_thing),
	is_toplevel(TopNode),
	(Edit_type = submodel, !,
	    finish_old_edit(none), /* because leaving the window */
	all(event, get_display_depth,
	    [unify(Wid),
	    build([ghost_link, influence, variable, flow, compartment, 
		   submodel, caption, text, sections]), build(Depths)]),
	    new_window_for(Edit_thing, TopNode, NewWin, Depths, 0),
	    all(state, set_display_depth,
		[unify(NewWin),
		build([ghost_link, influence, variable, flow, compartment,
		       submodel, caption, text, sections]), build(Depths)]),
	    redraw_window(NewWin);
	 setof(Distinct, find_name_host(Edit_thing, Distinct), [ControlThing]),
	(Edit_type = relation, Attrs = [exclusive, can_lookup],
	 [RoleMsgs, RoleStats] = [[], []];
	 Edit_type = influence,
		% list enablement of relation roles for influence
	 m_class'><'terminates(ControlThing, Fn),
	 setof(Role-Ref,
	       Rn^Ru^Sl^get_link_source_data(ControlThing, Fn, Rn, Ru, Role, Ref, Sl),
	       RoleRefPairs),
	 (RoleRefPairs = [_P1, _P2 | _], !,% at least one role besides none
	  (get_av_pair(ControlThing, 2, suppressed_roles, Suppd), !;
	   Suppd = []),
	  (get_av_pair(ControlThing, 2, enabled_roles, Enabd), !;
	   Enabd = []),
	  all(event, role_ref_to_msg, [build(RoleRefPairs), build(RoleMsgs)]),
	  all(event, role_ref_to_stat, [build(RoleRefPairs), unify(Suppd),
					unify(Enabd), build(RoleStats)]);
	  [RoleMsgs, RoleStats] = [[], []]), % lone role not offered for abling
	 Attrs = [use_sofar]), !,
	    all(event, get_refinement_or_0,
		[unify(ControlThing), unify(2), build(Attrs), build(OldVals)]),
	    (get_av_pair(ControlThing, 2, comment, OldComment), !;
		OldComment = ''),
	 append(Attrs, RoleMsgs, Msgs),
	 append(OldVals, RoleStats, OldStats),
	    do_relation_dialog(Wid, ControlThing, Edit_type, Msgs, OldStats,
			       OldComment, OKd, NewStats, NewComment),
	    (OKd == 1, !,
	        length(OldVals, NVals),
	        length(NewVals, NVals),
	        append(NewVals, NewChecks, NewStats),
	        (NewChecks = [], !; % lone role not offered for abling
		all(event, role_ref_to_stat,
		    [build(RoleRefPairs), unify(NewSuppd),
		     unify(NewEnabd), build(NewChecks)])),
		 % fails if single ref not checked
		 (nonvar(NewSuppd),
		  length(NewSuppd, _NSuppd), !;
		 NewSuppd = ''),
	        add_parameter(ControlThing, 2, suppressed_roles, NewSuppd),
		 (nonvar(NewEnabd),
		  length(NewEnabd, _NEnabd), !;
		 NewEnabd = ''),
	        add_parameter(ControlThing, 2, enabled_roles, NewEnabd),
		    
		all(m_update, add_parameter,
		    [unify(ControlThing), unify(2), build(Attrs),
		     build(NewVals)]),
		/* change role order if necessary */
		(nth(N, Attrs, can_lookup),
		    nth(N, NewVals, 1),
		    m_update'><'make_role_first(ControlThing); /* fails */
		add_parameter(ControlThing, 2, comment, NewComment)),
		find_all_comps(Parent, ControlThing),
		(find_name_host(Messed, ControlThing),
		    redisplay(Messed),
		    fail;
		finish_move(Parent, 1));
	    OKd == 0);
	Edit_type = text, !,
	    (get_shape(Edit_thing, caption_offset, OldVals), !,
		clear_shape(Edit_thing, caption_offset),
		\+ OldVals = [0, 0];
	      OldVals = [100, 0]),
	    do_text_item_dialog(Wid, Edit_thing, OldVals, OKd, NewVals),
	    (OKd == 1, !,
		set_shape(Edit_thing, caption_offset, NewVals),
		(redisplay(Edit_thing),
		    fail;
		 find_all_comps(Parent, Edit_thing),
		  finish_move(Parent, 1));
	     OKd == 0);
	Edit_type = image, !,
	caption_for(Edit_thing, Capt),
	(get_av_pair(Edit_thing, 0, comment, Cmt), !; Cmt = ''),
	  output'><'do_image_item_dialog(Wid, Capt, [Cmt],
					 OKd, [NewCmtStr]),
	  (OKd = 0, !;
	   name(NewCmt, NewCmtStr),
	   add_parameter(Edit_thing, 0, comment, NewCmt),
	   redisplay(Edit_thing),
		    fail;
	   find_all_comps(Parent, Edit_thing),
	   finish_move(Parent, 1));
	Edit_type is_class_of_sort has_function, !,
	    find_node_with_data(Edit_thing, Base, Control_thing),
	    is_parameter(Control_thing, WasP),
	    (get_av_pair(Control_thing, 0, units, OldUnits), !; OldUnits = no),
	    do_equation_dialog(Wid, Control_thing),
	    /* above fails if cancelled; if dialogue OK, then object is
	    complete. check here that the dims have changed */
	    find_node_with_data(Edit_thing, Base, NewControlThing),
	    (is_parameter(NewControlThing, WasP),
	     get_av_pair(NewControlThing, 0, units, OldUnits), !,
		NewDims = none;
	    NewDims = dims),
	    spread_colour(Base, NewDims),
	    find_all_comps(Parent, Base),
	    update_runnable(Parent)).

role_ref_to_msg(Role-Ref, Message) :-
	Ref = none,
	 Message = without_role;
	integer(Ref),
	 (Ref < 0 ->
	    source_locn_name(Ref, Message);
	  caption_for(Role, Capt),
	 Message = [with_role, Capt]).

role_ref_to_stat(_-Ref, Suppd, Enabd, Status) :-
	(integer(Ref), Ref<0 -> 
	(Status = 1,
	member(Ref, Enabd), !;
	Status = 0);
	(Status = 0,
	member(Ref, Suppd), !;
	Status = 1)).

get_refinement_or_0(ControlThing, AttSort, Attr, OldExc) :-
	get_av_pair(ControlThing, AttSort, Attr, OldExc), !;
	OldExc = 0.

/* If something's dimensions have changed, check all the equations
where it is used. If they do not check out unit-wise, try to re-do
them with the new units and if this succeeds, recurse if their
dimensions too have changed. In any case, mark the submodel as in
need of a rebuild as even if it doesn't change it will need to get the
input values using the new units. */

spread_dims(Node) :-
	(implicit_function(Node, Obj),
	find_all_comps(Sm, Obj),
	add_parameter(Sm, 1, c_new, 0),
	get_av_pair(Obj, 0, value, Equation),
	get_av_pair(Obj, 0, units, GivenUnits),
	get_input_info(Obj, IList),
	
	(\+ find_type(Node, state),
	    list_index_meanings(Obj, ISpecs),
	    all(dialogue, index_types, [build(ISpecs), build(IndxCount)]),
	    (get_av_pair(Obj, 0, table_data, TD) ->
	        dialogue'><'assert(table_data_is(TD)); true),
	    dialogue'><'test_eqn(Equation, Obj, IndxCount, IList,
			      Type, FoundArray, Xs, Err),
	    (get_av_pair(Obj, 0, table_data, TD) ->
	        dialogue'><'retract(table_data_is(TD)); true),
	    dialogue'><'check_param_usage(IList, [], Xs, IList, []),
	    analyze_array(GivenUnits, GivenBase, GivenArray),
	    (Err = [],
		(get_actual_sizes(Node, FoundArray, bare, _, Array, _),
		    get_actual_sizes(Node, GivenArray, bare, _, Array, _), !,
		    UseArray = GivenArray;
		  UseArray = FoundArray,
		    SpecChanged = dims),
		(Type = real, !, Base = 1; Base = Type),
		((use_units_in(Obj, 'No');
		  IList = [], inters'><'promote_unit(Base,1)),
		    CheckLevel = 1;
		  CheckLevel = 2),
		(check_unit(Base, GivenBase, CheckLevel, []), !,
		    UseBase = GivenBase;
		  UseBase = Base,
		    SpecChanged = units),
		update_links_and_vars(IList);
	      \+ GivenBase = any,
		value_propagates(out, Node, Next, _Link),
		multi_prop(out, Next, Node, 5),		
% if eqn does not parse following unit change, see if it is in a loop
% (limit search to 6 levels). If so, and this has not already been done,
% set units to 'any' and keep propagating, in the hope that they will
% all work once the whole loop has been done.
		SpecChanged = units,
		UseBase = any,
		UseArray = GivenArray);
	  true),
	(SpecChanged = none;
	build_array(UseBase, UseArray, NewUnits),
	    add_parameter(Obj, 0, units, NewUnits)), !;
	find_type(Node, submodel)),
	spread_colour(Node, SpecChanged).

/* this will update colours of all nodes connected with the given node */

spread_colour(Node, WhatsNew) :-
	need_same_dims(Node, Flow),
	    spread_colour(Flow, none),
	    fail;
	setof(More, (More = Node; status_affects(Node, More)), SpreadList),
	(member(Hit, SpreadList), Hit = Node;
	    member(Hit, SpreadList), \+ Hit = Node,
	        \+ find_type(Hit, influence);
	    member(Hit, SpreadList), find_type(Hit, influence)),
	/* Do influences last cos they depend on others! */
	(WhatsNew = dims ->
	    check_complete(Hit),
	    redisplay_border(Hit);	    
	  update_color(Hit)),
	(WhatsNew = none -> true;
	  presence_affects(Hit, MayChange),
	    spread_dims(MayChange)),
	/* Component colour will be normalized so get its links normal too 
	(normalize_ghosts_etc(Hit); */
	fail; true.

new_window_for(Submodel, TopNode, Canvas_name, InitDepths, IsTopLevel) :-
	utility'><'unique_name('.mswindow', Topwin), !,
	window_size_for(Submodel, Sub_extent, Scale),
	get_window_colour(Submodel, Colour, Images),
	add_window(Topwin, TopNode, Submodel, Sub_extent, Canvas_name, 
		[Colour | Images], Scale, InitDepths, IsTopLevel),
	create_window(Canvas_name, Submodel),
	make_current(Canvas_name),
	set_save_status(Submodel, safe).

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
register the user's choice of a drag rather than a click-start click-end.

sift_and_set(_Xpt, _Ypt) :-
	Next few lines stopped drag from starting until a certain
	distance had been covered. Latest versions have faster graphics
	so this should not be necessary...much...but with v5 they are MUCH
	faster, and showed up problems with this
%	get_original_click(OrigX, OrigY),
%	abs(Xpt-OrigX) + abs(Ypt-OrigY) > 2,
	(get_phase(action_choice), !,
	    advance_phase_to(dragging);
	true).

rather than just using Prolog
to find what component I've dragged into I'll precede this with an attempt to get
the info from Tk, only resorting to Prolog should this fail. Note GUI should only
be consulted if in multi-object mode. */

drag(Xpt, Ypt) :-
%	sift_and_set(Xpt, Ypt),
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
	(get_phase(Phase),
	    member(Phase, [moving_spline, moving_text,
			   moving_bowtie, moving_kink]), !,
	    RelPt = [RelX, RelY],
	    NewXpt is round(RelX),
	    NewYpt is round(RelY);
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

:- dynamic(ghostly_move/2).

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
	doing_add(Ltype),
%	get_phase(dragging),
	(Ltype is_class_of_sort line,
	    sort_for_finish(Comp, Ltype, Xpt, Ypt);
	Ltype is_class_of_sort rounded_rect,
	    (get_phase(dragging), !;
		advance_phase_to(dragging)),
	    get_start_coords(OldX, OldY),
	    clear_incomplete,
	    add_incomplete([OldX, OldY, Xpt, Ypt]),
	    remove_old_rubberband,
	    draw_rubberband(round)).

drag_to(Xpt, Ypt, Moving_obj) :-
	get_mode(select), /* was move */
	get_start_coords(OldX, OldY),
	Xoffset is Xpt - OldX,
	Yoffset is Ypt - OldY,
	find_current(Wid),
	\+ Wid shows_model Moving_obj,
	(get_phase(moving_bowtie),
	    adjust_bowtie(Moving_obj, [Xpt, Ypt]), !,
	    move_link(Moving_obj) /* ,
	    highlight(Moving_obj, 2) */;
	get_phase(moving_kink),
	    adjust_kink(Moving_obj, [Xpt, Ypt]), !,
	    move_link(Moving_obj) /* ,
	    highlight(Moving_obj, 2) */;
	get_phase(moving_spline),
	    adjust_spline(Moving_obj, [Xoffset, Yoffset]), !,
	    update_link_route(Moving_obj);
%	    move_text(Moving_obj, [Xoffset, Yoffset]);
	get_phase(moving),
	    find_all_comps(Parent, Moving_obj),
	    get_shape(Parent, internal_extent, ParentShape),
	    currently_moving_set(Movers),
	    (ghostly_move(_,_), !;
		\+ (setof(NewPosn,
			  Crasher^P1^(member(Crasher, Movers),
				      find_new_box(Crasher, Xoffset,
						   Yoffset, P1, NewPosn)),
			  BadPosns),
		       (member(BadPosn, BadPosns),
			   \+ fits_inside(BadPosn, ParentShape);
			   get_overlaps(Parent, BadPosns, Crashed),
			   \+ member(Crashed, Movers))),
		all(event, reposition,
		    [unify(Parent), build(Movers), unify([Xoffset, Yoffset])])),
%	    move_group(Movers, [Xoffset, Yoffset]);
	    shift_marked(Moving_obj, [Xoffset, Yoffset]);
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
	local_ends(Moving_obj, Start, Finish),
	(Phase = moving_start,
	    (continues_from(Moving_obj, Box), !;
		Box = Start);
	Phase = moving_finish,
	    (continues_in(Moving_obj, Box), !;
		Box = Finish)),
	find_type(Box, EType),
	/* find drag point in parent model */
	find_all_comps(Parent, Moving_obj),

	(Parent = Box, !,
	    get_shape(Parent, internal_extent, ParentBox);
	get_drawing_form(Box, _, ParentBox)),
	    
	middle(ParentBox, [Xc, Yc]),
	/* allow leeway of 10% for dragging round border */
	Leeway = 0.1,
	Xin is Xpt + Leeway*(Xc - Xpt),
	Yin is Ypt + Leeway*(Yc - Ypt),
	Xout is Xpt + Leeway*(Xpt - Xc),
	Yout is Ypt + Leeway*(Ypt - Yc),
	inside_shape(Parent, [Xin, Yin], EType, ParentBox),
	\+ inside_shape(Parent, [Xout, Yout], EType, ParentBox),
	/* Snap to border */
%	crossing_point([Xc, Yc], [Xout, Yout], EType, ParentBox,
%			0, NewEndPt),
	get_posn_around([Xout, Yout], ParentBox, Theta),
	(Phase = moving_start,
	    change_shape(Start, along, Theta),
	    m_class'><'Moving_obj follows Prev;
	Phase = moving_finish,
	    change_shape(Finish, along, Theta),
	    Prev = Moving_obj),
	(m_class'><'Other follows Prev,
	    move_link(Other),
	    fail;
	move_link(Prev)),
	move_something.

% Ghosting drag: should perhaps reuse sort_for_finish for some of this work...
drag_to(Xpt, Ypt, Target) :-
	(get_phase(action_choice),
	    advance_phase_to(dragging);
	get_phase(dragging)),
	get_mode(ghost), !,
	clear_incomplete,
	find_type(Target, Type),
	(get_highlit_obj(2, OldTarget),
	    normalize(OldTarget),
	    fail;
	 Type = submodel, !;
	    ghost_type(Start, Type, _),
	    \+ Target = Start,
	    \+ find_ghosts(Target, _),
	    highlight(Target, 2)),
	get_border_offsets(Loff,Toff,Roff,Boff),
	L is Xpt-Loff,
	T is Ypt-Toff,
	R is Xpt+Roff,
	B is Ypt+Boff,
	add_incomplete([L,T,R,B]),
	remove_old_rubberband,
	draw_rubberband(round).

reposition(Parent, Mover, [XOff, YOff]) :-
	adjust_posn(Mover, [-XOff, -YOff, 1,1]),
	find_all_links(Mover, Link),
	\+ moves_with_seln(Parent, Link),
	move_link(Link),
	fail; true.
%	tweak_link_connections(Mover, [XOff, YOff], c, _).

moves_with_seln(Parent, Obj) :-
	get_highlit_obj(0, Obj),
	find_all_comps(Parent, Obj),
	(Obj is_of_sort box;
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
	get_shape(Parent, internal_extent, OldInt),
	expand_canvas(Parent, Visible),
	tweak_link_connections(Parent, OldInt).
/*
tweak_link_connections(Obj, [XOff, YOff], Side, [L, T, R, B]) :-
	find_all_comps(Box, Obj),
	find_all_links(Obj, Link, Where),
	\+ (Side = c, moves_with_seln(Box, Link)),
	% do not tweak if part of move
	(end_coords(Link, Where, [Xpt, Ypt]),
	    (member(Side, [nw, w, sw]), NewX is Xpt + XOff*(R-Xpt)/(R-L);
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
	Side = c),
	update_link_route(Link),
	make_links_follow(Link),
	fail; true.
*/
tweak_link_connections(Obj, _OldInterns) :-
%	get_shape(Obj, internal_extent, NewInterns),
%	add_boxes_to_translation([0,0,1,1], OldInterns, NewInterns, UseTrans),
	(find_all_comps(Obj, Comp),
	    border_node(Comp),
	    /* border node posn now parametric so no change needed
	    get_shape(Comp, centre, OldCtr),
	    translate(OldCtr, UseTrans, NewCtr),
	    change_shape(Comp, centre, NewCtr), */
	    member(Comp, [From, To]),
	    m_class'><'Link is_connector from From to To,
	    move_link(Link),
	    fail;
	find_all_links(Obj, Link),
	    move_link(Link),
	    fail;
	true).

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
	local_ends(Moving_obj, Source, Dest),
	member([End, Comp], [[start, Source], [finish, Dest]]),
	change_shape(Comp, centre, NewPt),
	move_link(Moving_obj).

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
	doing_add(Type),
	Type is_class_of_sort line;
	get_mode(ghost).

/* do_colours/1: When an object is selected this should set it and its
neighbours to the appropriate colours, i.e.,
blue: moves in bulk, copies and deletes
turquoise: drags and deletes
dark green: deletes
light green: changes status */

do_colours(Obj, Where) :-
	tk_get_pref(deleteEndToEnd, E2E),
	(Where = seln,
	    highlight_deletes(Obj, E2E);
	Where = base,
	    normalize_deletes(Obj, E2E)).

/* lit_by: As well as the selection, there are other highlit components
in a certain relation to the selection. Traditionally these are ghosts of
selected components, but we might add diferent options to allow more of the
model structure to be illustrated */

lit_by(Target, Ghost) :-
	get_halo(fwd, GoFwd),
	get_halo(back, GoBack),
	(var(Ghost), !,
	    [Hit, Halo, Up, Down] = [Target, Ghost, in, out];
	    [Hit, Halo, Up, Down] = [Ghost, Target, out, in]),
	(multi_prop(Up, Hit, Shift, GoBack);
	multi_prop(Down, Hit, Shift, GoFwd)),
	find_base(Shift, Base),
	(Halo = Base; find_ghosts(Base, Halo)),
	\+ Ghost = Target.
	
update_halo(_) :-
	get_highlit_obj(2, OldHalo),
	normalize(OldHalo), fail;
	doomed(Base),
	lit_by(Base, Halo),
	\+ get_highlit_obj(_, Halo),
	highlight(Halo, 2), fail;
	true.

/* highlight_deletes: this highlights all the objects which will be zapped if a particular delete selection is made. The target itself highlights at defcon 0 and any colateral damage at defcon 1. */

highlight_deletes(Target, E2E) :-
	lit_by(Target, Ghost),
	\+ get_highlit_obj(_, Ghost),
	highlight(Ghost, 2),
	fail; 
	recursive_highlight(Target, from, base,  E2E);
	recursive_highlight(Target, to, seln,  E2E);
	true.

normalize_deletes(Target, E2E) :-
	lit_by(Target, Ghost),
	    get_highlit_obj(2, Ghost),
	    normalize(Ghost),
	    fail;
	recursive_highlight(Target, from, seln,  E2E);
	recursive_highlight(Target, to, base,  E2E);
	lit_by(Base, Target),
	    doomed(Base),
	    highlight(Target, 2), fail;
	keep_only_if_links_stay(Target, base), fail;
	true.


recursive_highlight(Target, Way, Where, E2E) :-
	(Target is_of_sort box, !,
	    change_delete_status(Target, Way, Where),
	    Also = Target;
	(E2E = 1,
	    m_class'><'connects(Target, VStart, VFinish);
	E2E = 0,
	    m_class'><'Target is_connector from VStart to VFinish),
	    get_visible(VStart, Start), % if a bowtie we need flow status
	    \+ Start = VFinish,
	    get_visible(VFinish, Finish),
	    match_delete_status([Start, Finish], Way, Where),
	    change_delete_status(Target, Way, Where),
	    (Also = Target;
	    E2E = 1, adjust_link_backwards(Target, Way, Also, Where);
	    E2E = 1, adjust_link_forwards(Target, Way, Also, Where);
	    bring_dependents_into_line([Start, Finish], Where), fail)),
	find_all_links(Also, Linked),
	% new bit to stop redoing what has already been done
	    (at_def_con(Linked, Where) -> Way = (from); Way = (to)),
	    (E2E = 1,
		\+ has_outer_equiv(_, Also, Linked);
	     E2E = 0,
		(has_outer_equiv(LinkedToo, Also, Linked),
		    recursive_highlight(LinkedToo, Way, Where, E2E),
		    fail; true)),
	    recursive_highlight(Linked, Way, Where, E2E).

get_visible(Invis, Vis) :-
	get_host(Invis, Maybe),
	(appears(Maybe), !, Vis=Maybe; find_all_comps(Vis, Maybe)).

adjust_link_backwards(Target, Way, Also, Where) :-
	m_class'><'Target follows Prev,
	(Way = (to),
	    change_delete_status(Prev, to, Where);
	 Way = (from),
	    \+ (m_class'><'Other follows Prev,
		   at_def_con(Other, Where)),
	    change_delete_status(Prev, from, Where)),
	 (Also = Prev; adjust_link_backwards(Prev, Way, Also, Where)).
	
adjust_link_forwards(Target, Way, Also, Where) :-
	m_class'><'Next follows Target,
	(Way = (from),
	    change_delete_status(Next, from, Where);
	 Way = (to),
	    m_class'><'connects(Next, _, Mid),
	    get_host(Mid, Finish),
	    match_delete_status([Finish], to, Where),
	    change_delete_status(Next, to, Where)),
	(Also = Next; adjust_link_forwards(Next, Way, Also, Where)).
	
change_delete_status(Target, Way, FromWhere) :-
	(\+ at_def_con(Target, FromWhere), !,
	    Way = (to),
	    to_def_con(Target, FromWhere);
	Way = (from),
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
	    \+ doomed(Tgt);
	FromWhere = seln,
	    get_highlit_obj(0, Tgt).

to_def_con(Tgt, FromWhere) :-
	FromWhere = base,
	    normalize(Tgt);
	FromWhere = seln,
	    highlight(Tgt, 0).

depends_on_links(Damage) :-
	find_type(Damage, Type),
	member(Type, [cloud, border]) /* keep unattached parameters for now ;
	is_parameter(Damage, N), N>0 */ .

keep_only_if_links_stay(Damage, Where) :-
	depends_on_links(Damage),
	(setof(NeedsIt, find_all_links(Damage, NeedsIt), NeedIt),
	member(HasIt, NeedIt),
	at_def_con(HasIt, Where), !,
	to_def_con(Damage, Where);					
	highlight(Damage, 1)).

match_delete_status(Ends, Way, Where) :-
	member(End, Ends),
	(Where = seln; \+ depends_on_links(End)),
	\+ at_def_con(End, Where), !, Way = (from);
	true.

local_ends(Link, Start, Finish) :-
	m_class'><'Link is_connector from Start to Mid,
	get_host(Mid, Finish).

doomed(End) :-
	get_highlit_obj(L, End),
	L<2.

move_link(Obj) :-
	update_link_route(Obj),
	make_links_follow(Obj).

make_any_links_follow(Obj) :-
	find_all_comps(Parent, Obj),
	find_all_links(Obj, Link),
	move_link(Link),
	m_class'><'Parent has_link_equivalences EqList,
	member(Bef-Aft, EqList),
	select(Link, [Bef, Aft], [Other]),
	move_link(Other),
	fail; true.

make_links_follow(Obj) :-
	find_all_links(Obj, Link),
	move_link(Link),
	fail; true.

/* adjust_link(Link, Recurse) :-
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

This is sort_for_finish. 
It gets a parent and a target, which may be the same. If the target can be finished 
on, highlight it in green; if not, and it is primitive, light it red, otherwise no 
light. If on a finishable primitive, draw the final route; if on a nonfinishable 
primitive do not update the route. If on a submodel, hunt if it contains anything 
finishable, otherwise do as for primitive. 

Alteration to allow drags of links into space to produce new components; always
hunt if on a submodel. Further alteration: only make this alteration for flows */

sort_for_finish(Target, Ltype, Xpt, Ypt) :-
	get_highlit_obj(_, Old_target),
		normalize(Old_target), fail;

	get_line_start_obj(OrigStart),
	(OrigStart = Target,
	    % two-click despite short drag at start point
	    get_phase(action_choice), !;
	(get_phase(dragging), !;
	    advance_phase_to(dragging)),
        get_nearest_equivalent_link(Ltype, OrigStart, Target, Start),
	    get_host(Start, VisStart),
	    (find_type(Target, submodel),
	/* This requirement dropped for flows, see above */
		(find_all_comps(Target, Baby),
		    can_finish(Ltype, VisStart, Baby),
		    \+ contains(Baby, Start), !;
		member(Ltype, [flow, squirt])),
		set_current_coords(Xpt, Ypt), /* for new terminator if dropped here */
		extend_line_to(Start, Ltype, Target, [Xpt, Ypt]);
	Drawn = false),

	(can_finish(Ltype, VisStart, Target), !,
	    set_line_finish_obj(Target),
	    highlight(OrigStart, 1),
	    highlight(Target, 2),
	    (Drawn = true, !;
	    draw_line_to(Start, Ltype, Target));
	set_line_finish_obj(none),
	    highlight(Target, 0))).

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
		    m_class'><'Start is_connector from _ to StartPoint;
		member(StartPoint, BiggestFirst),
		    Start draws_inside StartPoint),
		get_possible_start(OrigStart, Start),
% following lines stop influences and ghost links sharing sections
		draw_style_for(Start, Btype),
		Btype = Ltype, % d_s_f can agree wrongly to ground type
		appears(Start),
		can_start(influence, Start),
		(PossFinish = Target; find_all_comps(Target, PossFinish)),
		can_finish(influence, Start, PossFinish), % or entry was u-turn
		!;
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
	    get_link_route(Start, [End | _]),
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
	    get_link_route(Target, Route),
	    suffix([End2], Route),
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
    get_drawing_form(Submodel, Type, [OldL, OldT, OldR, OldB]),
	(member(Edge, [nw, w, sw, c]), !, NewL is OldL+XOff; NewL = OldL),
	(member(Edge, [nw, n, ne, c]), !, NewT is OldT+YOff; NewT = OldT),
	(member(Edge, [ne, e, se, c]), !, NewR is OldR+XOff; NewR = OldR),
	(member(Edge, [sw, s, se, c]), !, NewB is OldB+YOff; NewB = OldB),
	NewBox = [NewL, NewT, NewR, NewB],
	/* Check it is not too small */
	get_box_size(Submodel, Type, Standard),
	NewR-NewL > Standard//2,
	NewB-NewT > Standard//2,
	find_all_comps(Parent, Submodel),
	\+ (get_overlaps(Parent, [NewBox], Obstacle), \+ Obstacle = Submodel),
	(Type = image ->
	     CX is floor((NewL+NewR)/2),
	     CY is floor((NewT+NewB)/2),
	     W is NewR-NewL,
	     H is NewB-NewT,
	     change_shape(Submodel, centre, [CX, CY]),
	     change_shape(Submodel, caption_offset, [W, H]);
      get_shape(Submodel, internal_extent, OldInterns),
	/* work out what the caption was nearest to */
	(get_shape(Submodel, caption_offset, [XT, YT]);
	    get_shape(Submodel, caption_offset, [XT, YT, _Anchor])), !,
	OldCapX is OldL + XT,
	OldCapY is OldT + YT,
	get_closest_edge(Submodel, [OldCapX, OldCapY], CapEdge, _EfPt),
	add_to_translation([0,0,1,1], Submodel, ModelTrans),
	translate(NewBox, ModelTrans, NewExtent),
	(ghostly_move(_,_), !; % no bounds checking if in fast edit mode 
	get_shape(Parent, internal_extent, ParentShape),
	fits_inside(NewBox, ParentShape),
	
	/* Check that everything that was in the model is still in it */
	\+ (m_class'><'Submodel has_part Inside,
	       \+ border_node(Inside),
	       get_drawing_form(Inside, _, InBox),
	       \+ fits_inside(InBox, NewExtent))),
	map([OldL, OldT, OldR, OldB], CapEdge, _,_, OBX, OBY),
	map(NewBox, CapEdge, _,_, NBX, NBY),
	NXT is OldCapX+NBX-OBX-NewL,
	NYT is OldCapY+NBY-OBY-NewT,
	change_shape(Submodel, caption_offset, [NXT, NYT]),
	change_shape(Submodel, internal_extent, NewExtent),
	change_shape(Submodel, bounding_box, NewBox),
	/* make_links_follow(Submodel), */
	(ghostly_move(_,_), !; % no link dragging if in fast edit mode 
	tweak_link_connections(Submodel, OldInterns))).

/* anything this complex has got to be wrong

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
	% make_links_follow(Submodel),
	tweak_link_connections(Submodel, [XOff, YOff], Edge,
			       [OldL, OldT, OldR, OldB]).
	External links must be adjusted first because their endpoints
	are used to calculate those of internal links
        adjust_border_links(Submodel). */

unclick :-
	retractall(clicked_obj_is(_Obj)),
	retractall(menu_submodel_will_be(_,_,_)),
	retractall(currently_moving_set(_Movers)),
	untag_all,
	find_current(Wid),
	Wid shows_model Model,
	(get_mode(select),
	    get_phase(rubberband), !, /* used to call proc below */
	    get_incomplete(Box),
%	    get_translation(Trans),
%	    untranslate(Box, Trans, [OldX, OldY, NewX, NewY]),
	    Box = [OldX, OldY, NewX, NewY],
	    clear_incomplete,
	    L is min(OldX, NewX),
	    T is min(OldY, NewY),
	    R is max(OldX, NewX),
	    B is max(OldY, NewY),
	    ((R-L)+(B-T)>2, % less than this is a wobbly click not a drag
		get_current_node(Parent),
		select_bagged([L, T, R, B], Parent, none);
	    set_selection_abilities(Model),
	    remove_old_rubberband),
	    initialize_phase;
	get_phase(action_choice), !,
	    cursor_is(crosshair),
	    update_ability(Model, save, file, 'Save', 0), % no save halfway
	    update_ability(Model, undo, edit, 'Undo', 1),
	    update_ability(Model, redo, edit, 'Redo', 0),
	    advance_phase_to(targetting));
	unclick_obj.

select_bagged(Rect, Model, Last) :-
	get_overlaps(Model, [Rect], Caught),
	(find_type(Caught, submodel),
	    \+ Caught = Last,
	    add_to_translation([0,0,1,1], Caught, Trans),
	    translate(Rect, Trans, NewRect),
	    select_bagged(NewRect, Caught, up);
%	 \+ (get_shape(Caught, bounding_box, Outer),
%		fits_inside(Rect, Outer)),
	    \+ deselectable(Caught),
	    do_colours(Caught, seln),
	    fail);
	\+ Last = up,
	    get_shape(Model, internal_extent, Inner),
	    \+ fits_inside(Rect, Inner),
	    add_to_translation([0,0,1,1], Model, Trans),
	    untranslate(Rect, Trans, NewRect),
	    find_all_comps(Parent, Model),
	    select_bagged(NewRect, Parent, Model).
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
	doing_add(New_obj),
	retractall(instant_link(_)),
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
/* Now if replacing a visible terminator with a border node, reroute the links
on either side (tests for this should be more explicit) -- reroute all at once
so endpoints of new bits are always defined */
			    (\+ find_type(Terminator, New_obj), !,
				EndSects = [];
			     m_class'><'Terminator follows Replacer,
				EndSects = [Replacer, Terminator]),
			    ((Replacer == Start_thing;
			      \+ find_type(Start_thing, New_obj);
			      \+ New_obj = flow), !,
				MoveSects = EndSects;
			     m_class'><'Rep2 follows Start_thing,
				merge_lists(EndSects, [Start_thing, Rep2],
					    MoveSects)),
			    menu'><'reroute_sections(MoveSects))),
		    clear_incomplete,
		    remove_old_incomplete;
		get_phase(barge),
		    /* Initial click on something that could not start line */
		    get_highlit_obj(0, WrongStart),
		    normalize(WrongStart)),
		    initialize_phase;
		
	New_obj is_class_of_sort rounded_rect,
	    get_phase(dragging),
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
	(ghostly_move(OldX, OldY),
	    get_start_coords(Xpt, Ypt), % last drag finished here
	    drag_to(OldX, OldY, Submodel), % put graphics back to start
	    retract(ghostly_move(_,_)),
	    ([Xpt, Ypt]=[OldX, OldY];
	      drag_to(Xpt, Ypt, Submodel); % do it for real
		query(overlap(drag, selection), warning, top, [ok], _)), !;
	true),
	(get_phase(moving_border(_)),
	    get_shape(Submodel, internal_extent, NewSize), !,
	    adjust_toplevel_windows(Submodel, NewSize);
	true),
	initialize_phase,
	(\+ retract(moved_something), !;
	finish_move(Submodel, 0)).

/*
Unclick in ghost mode. If unclicking in space, a new ghost node is created. If
unclicking on an existing node this node is made into a ghost of the source node
if it is of a suitable type. The target node's own equation information remains,
but is not usable or editable until it becomes de-ghosted. */

unclick_obj :-
	get_mode(ghost),
	get_phase(dragging),
	initialize_phase,
	get_current_node(Parent),
	normalize(Start),
	(get_incomplete(Box),
	remove_old_rubberband,
	ghost_type(Start, GhostType, Base),
	(get_highlit_obj(2, Component_name);
	middle(Box, Pt),
	attempt_addition(GhostType, Parent, Pt, Component_name, no, yes), !,
	        redisplay(Component_name)),
	    get_nearest_equivalent_link(ghost_link, Base,
					Component_name, OutLink),
	    reghost(Component_name, OutLink);
	query(bad_ghost, error, top, [ok], _)),
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

doing_add(Comp) :-
	instant_link(AddingNow), !,
	    Comp = AddingNow; % not adding mode choice if doing instant link
	get_mode(add),
	    get_adding_object(Comp).

tie_ends(New_obj, Start_thing, Terminator) :-
	link_ends(New_obj, Start_thing, Terminator, LastArc),
	reuse_route(New_obj, LastArc).

/* Clever bit: reuse route of the rubberband link for the newly added one */
reuse_route(New_obj, LastArc) :-
        find_current(Wid),
%	Wid shows_model Parent,
	find_base(LastArc, BowtieArc),
        ((NewArc = LastArc; m_class'><'sequence(NewArc, LastArc)),
	    find_all_comps(Node, NewArc),
%	    get_incomplete(Node-ScreenRoute),
%	    translate_between(Parent, Node, _D, Trans),
%	    translate(ScreenRoute, Trans, Route),
	    get_incomplete(Node-Route),
	    local_ends(NewArc, Start, Finish),	    
	    Route = [LastPt, MidPt | Tail],
	    suffix([FirstPt], [MidPt | Tail]),
	    asserta(new_route_for(NewArc, MidPt)),
	    member(CrossPt-End, [FirstPt-Start, LastPt-Finish]),
	    border_node(End),
		get_shape(Node, internal_extent, Box),
	        get_posn_around(CrossPt, Box, Theta),
		(clear_shape(End, along), fail; % in case rerouting
		    set_shape(End, along, Theta)),
		fail;
        retract(new_route_for(NewArc, MPt)),
	    /* Arcs need points at ends of other arcs to draw, so draw after */
%	    set_shape(NewArc, course, Route),
%	    update_bowtie(NewArc, Route),
	    (member(New_obj, [flow, squirt]),
		CPt = [550,1000];
		% First is posn of kink, 2nd is posn of bowtie /1000
	      \+ member(New_obj, [flow, squirt]),
		get_end_pt(NewArc, start, _, Spt, _),
		get_end_pt(NewArc, finish, _, FPt, _),
		relativize_centre(Spt, FPt, MPt, CPt)),
	    (clear_shape(NewArc, curve), fail; % in case rerouting
		set_shape(NewArc, curve, CPt)),
	    redisplay(NewArc),
	    make_links_follow(NewArc),

	    (New_obj = relation,
		get_boundary_end(NewArc, true);
	    New_obj is_class_of_sort has_bowtie,
		NewArc = BowtieArc),
	    give_focus(NewArc),
	    do_colours(NewArc, seln),
	    select_text(Wid, NewArc),
	    fail;
	 true).
	
relativize_centre([SX, SY], [FX, FY], [MX, MY], [CX, CY]) :-
		CX is MX-(SX+FX)/2,
		CY is MY-(SY+FY)/2.


get_posn_around([X, Y], Box, Theta) :-
	middle(Box, [MX, MY]),
	Theta is round(1000*atan2(Y-MY, X-MX)/6.28319) mod 1000.

/* New version that preserves position along side -- needs work
get_posn_around([X, Y], [L, T, R, B], Theta) :-
	XFr is (X-L)/(R-L),
        YFr is (Y-B)/(T-B),
        (YFr > XFr -> Theta is 375+250*(YFr+XFr);
            Theta is round(1375-250*(YFr+XFr)) mod 1000).
*/
ghost_type(Start, Type, Base) :-
	get_line_start_obj(Start),
	find_base(Start, Base),
	find_type(Base,StartType),
	(Type = StartType; Type = cloud, StartType = compartment).

/* event-level interface to ghost creation. This identifies a
node's current ghost state, if it is a ghost it unghosts it,
undrawing any ghost links that were there, then ghosts it to the new base if there is one, displaying the links. */

reghost(Ghost, Base) :-
	make_ghost(Ghost, Base, TopLink),
	draw_line_to(Base, influence, Ghost),
	reuse_route(influence, TopLink),
	change_ghosthood(Ghost),
%	clear_incomplete,
	remove_old_incomplete.

change_ghosthood(Node) :-
/*	make_links_follow(Node), */
    status_affects(Node, OutLink),
        presence_affects(OutLink, Dest),
	update_default_refs_in_eqns(OutLink, Dest),
	fail;
    spread_colour(Node, dims).	    

delete_by_dlg(Target) :-
	remove_highlights,
	% cached to reduce load on interface...
	tk_get_pref(deleteEndToEnd, E2E),
	recursive_highlight(Target, from, base, E2E);
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
	(setof(NewLook, Tgt2^(member(Tgt2, Range),
			      presence_affects(Tgt2, NewLook),
			    \+ member(NewLook, Range)), ChangedLooks), !;
	    ChangedLooks = []),
	((member(Target, Range),
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
	    
	kill_primitive(Target, FollowArcs); 
	/* now un-highlight and redisplay the ghosts of the dead node; they may
	be outside the submodel, and there may be other highlit ghosts. This is
	now done by colour spreading
	get_highlit_obj(2, ExGhost),
	    \+ is_ghost(ExGhost),
	    normalize(ExGhost),
	    change_ghosthood(ExGhost),
	    fail; */
	member(NewVisLook, ChangedLooks),
	    spread_colour(NewVisLook, dims), /* Only need to update dims
					    if arc is a relation */
	    update_captions(NewVisLook),
	    fail;
	set_selection_abilities(Top)).

deletable(Top, FollowArcs, Tgt) :-
	contains(Top, Tgt), !;
	FollowArcs = 1,
	    m_class'><'equivalent_arcs(Tgt, InTgt),
	    get_highlit_obj(M, InTgt), M<3,
	    contains(Top, InTgt).

kill_primitive(Target, FollowArcs) :-
	off(Target),
% updating of survivors' appearance now done by delete_net, which calls this
%	(setof(NewLook, (presence_affects(Target, NewLook),
%			    \+ doomed(NewLook)), ChangedLooks), !;
%	    ChangedLooks = []),
	forget_highlit_obj(_, Target),
	(FollowArcs = 1, /* no messing about */
	    fast_delete(Target);
	FollowArcs = 0,
	    do_delete(Target)),
%	member(NewVisLook, ChangedLooks),
%	    spread_colour(NewVisLook, yes), /* Only need to update dims
%					    if arc is a relation */
%	    update_captions(NewVisLook),
	    fail.

embrace(Wid, Obj) :-
	Wid shows_model Comp,
	set_selection_abilities(Comp),
	(Obj = 0, !;
	give_focus(Obj) /* ,
	highlight(Obj, 0) */).

set_selection_abilities(Comp) :-
	(setof(Lit, 
	       (contains(Comp, Lit), \+ Lit = Comp,
		   get_highlit_obj(0, Lit)), AllLit), !,
	    Cuttable = 1,
	    Dellable = 1;
	setof(Lit, 
	      (contains(Comp, Lit), \+ Lit = Comp, \+ Lit is_of_sort cloud,
		  get_highlit_obj(1, Lit)), AllLit), !,
	    Cuttable = 0,
	    Dellable = 1;
	AllLit = [Comp], % do submodel clicked in if nothing selected
	    Cuttable = 0,
	    Dellable = 0),
	(AllLit = [Choice],
	    \+ Choice is_of_sort cloud, !,
	    Peekable = 1;
	Peekable = 0),
	update_ability(Comp, none, file, '{Save selection as...}', Cuttable),
	update_ability(Comp, none, edit, 'Cut', Cuttable),
	update_ability(Comp, none, edit, 'Copy', Cuttable),
	update_ability(Comp, none, edit, 'Delete', Dellable),
	update_ability(Comp, none, edit, '{Reroute links}', Dellable),
	update_ability(Comp, none, edit, '{Align to grid}', Dellable),
	update_ability(Comp, none, edit, 'Properties...', Peekable).

abandon :-
	finish_old_edit(none).

abandon_eqn /* :-
	normalize(_Obj) */ .

/* This will make a new node at the given position if the 4th arg is
var, or move the given node there if it is not. Fails if it interferes
with another component -- the test previously used picks, but now uses
get_component_from_gui because it is quicker (except as of v5 it
probably isnt....) */

attempt_addition(Type, Parent, Posn, Node_name, CanBag, Verbal) :-
	/* check it is inside its parent */
	(Type = submodel,
	    Box = Posn;
	 \+ Type = submodel,
	    use_style_for(Type, NewObjStyle),
	    get_box_size(Parent, NewObjStyle, Cur_size),
	    Posn = [Xpt, Ypt],
	    make_bounding_box(Type, Xpt, Ypt, Cur_size, Box)),

	get_shape(Parent, internal_extent, Parent_size),
	fits_inside(Box, Parent_size),

	/* If CanBag is 'yes' the new box can be put around existing ones */
	\+ (get_overlaps(Parent, [Box], Other),
	       (CanBag = no;
		   get_drawing_form(Other, _Style, WeeBox),
		   \+ fits_inside(WeeBox, Box))),
	
/* check it is not inside a submodel (GUI only checks border interference)
	\+ (find_all_comps(Parent, OtherSubmodel),
	       find_type(OtherSubmodel, submodel),
	       get_shape(OtherSubmodel, bounding_box, OtherSubSize),
	       fits_inside(Box, OtherSubSize)), */
	
	(nonvar(Node_name);
	make_node(Parent, Type, Node_name),
		add_implicit_function(Node_name, _)), !,
	(Type = submodel, !,
	    set_shape(Node_name, bounding_box, Box);
	set_shape(Node_name, centre, Posn)),
	make_links_follow(Node_name);
	Verbal = yes,
        query(overlap(add, Type), warning, top, [ok], _),
	fail.

attempt_new_component(Parent, Box) :-
	Box = [L,T,R,B],
	W is R - L,
	H is B - T,
	get_box_size(Parent, submodel, Standard),
	W > Standard//2,
	H > Standard//2,
	attempt_addition(submodel, Parent, Box, Node_name, yes, yes),
	output'><'safe_tcl_eval(['CanvasDefBG'], DefFillStr),
	name(DefFill, DefFillStr),
	add_parameter(Node_name, 0, fill_colour, DefFill),
/* List components inside the box */
	get_inclusions(Parent, Box, Include),

/* cann no longer happen as only flows with ends inside are checked
	(setof(CrossingFlow, just_crosses(CrossingFlow, Contents), Exclude), !,
	    purge(Exclude, Contents, Include);
	  Include = Contents),
	    
	Undisplay arcs that will not exist after the operation...*/
	(one_end_in(Include, Arc), 
		off(Arc), 
		clear_shape(Arc, _),
		fail;
	true),
	encapsulate(Parent, Include, Node_name),
	(presence_affects(Node_name, State),
	    find_type(State, state),
	    update_default_refs_in_eqns(Node_name, State),
	    fail;
	 true),
	set_shape(Node_name, internal_extent, [0,0,W,H]),
	add_to_translation([0, 0, 1, 1], Node_name, Node_trans),
	relate_graphics(Node_name, Node_trans),
	redisplay_border(Node_name),
	find_current(Wid),
	give_focus(Node_name),
	do_colours(Node_name, seln),
	select_text(Wid, Node_name).

just_crosses(Flow, Contents) :-
	member(Flow, Contents),
	m_class'><'Flow is_connector from Start to Finish,
	\+ member(Start, Contents),
	\+ member(Finish, Contents).

relate_graphics(Node_name, Node_trans) :-
	move_boxes(Node_name, Node_trans),
	(setof(DoLink,
	      Link^(find_all_links(Node_name, Link),
		    (has_outer_equiv(DoLink, Node_name, Link); DoLink = Link)),
	      MessedLinks), !,
	    menu'><'reroute_sections(MessedLinks),
	    all(event, make_links_follow, [build(MessedLinks)]);
	true),
	remove_old_incomplete.

move_boxes(Node_name, Node_trans) :-
	find_all_comps(Node_name, Thing),
%	\+ border_node(Thing),
% need to move border nodes too for refatten to work -- other uses?
	adjust_posn(Thing, Node_trans),
	fail; true.

resnap(Node, SelOnly) :-
	find_all_comps(Node, Bit),
	(SelOnly = 0; SelOnly = 1, doomed(Bit)),
	(get_shape(Bit, bounding_box, BB),
	    add_to_translation([0,0,1,1], Bit, Trans), % bit is submodel
	    snap_to_grid(BB, NBB),
	    translate(NBB, Trans, [L, T, R, B]),
	    change_shape(Bit, bounding_box, NBB),
/* If doing selection, move everything in box to align top-left of
internal grid with external; if reparenting leave internals as they
are because undo/redo graphics cannot cope */
	    (SelOnly = 1,
		snap_to_grid([L, T], [NL, NT]),
		JumpL is L-NL, JumpT is T-NT,
		NR is R-JumpL, NB is B-JumpT,
		get_shape(Bit, internal_extent, OldIntern),
		change_shape(Bit, internal_extent, [NL, NT, NR, NB]),
		move_boxes(Bit, [JumpL, JumpT, 1,1]),
		SfL is -JumpL, SfT is -JumpT,
		% No idea why graphics shift must be opposite direction to work
		(Wid shows_model Bit,
		    draw'><'shift_model(Wid, Bit, [SfL, SfT]),
		    fail;
		tweak_link_connections(Bit, OldIntern)),
		resnap(Bit, 1);
	    SelOnly = 0,
		change_shape(Bit, internal_extent, [L, T, R, B])),
	    redisplay_border(Bit);
	 find_type(Bit, New_obj),
	 \+ New_obj = submodel,
	    align(Bit),
	    SelOnly = 1, % if everything, they will anyway
	    make_links_follow(Bit)),
	fail; true.

align(Bit) :-
	get_shape(Bit, centre, [XMid, YMid]),
	snap_to_grid([XMid, YMid], [Xpt, Ypt]),
	XOff is Xpt-XMid, YOff is Ypt-YMid,
	change_shape(Bit, centre, [Xpt, Ypt]),
	%announce("Shunting by ~w, ~w", [XOff, YOff]),
	move_display(Bit, [XOff,YOff]).

adjust_posn(Thing, Trans) :-
	get_shape(Thing, Whatever, Wherever),
	\+ Whatever = internal_extent,
	(relative_coord_attribute(Whatever),
	    rel_translate(Wherever, Trans, New_wherever);
	\+ relative_coord_attribute(Whatever),
	    translate(Wherever, Trans, New_wherever)),
/*	(member(Trans, [[_,_,1,1], [_,_,1.0,1.0]]), !,
	    NewOnGrid = New_wherever;
	snap_to_grid(New_wherever, NewOnGrid)),
*/
	change_shape(Thing, Whatever, New_wherever),
	fail; true.

relative_coord_attribute(Whatever) :-
	member(Whatever, [caption_offset, curve]).
	      
dissolve_component(Node) :-
	find_all_comps(Parent, Node),
	subtract_from_translation([0,0,1,1], Node, Node_trans),
	(move_boxes(Node, Node_trans),
	(setof(Part, m_class'><'Node has_part Part, Orphan_nodes), !;
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
	    spread_colour(Node, dims)),
	(setof(State, (presence_affects(Node, State), find_type(State, state)),
	       States), !; States = []),

	/* next, set its internal extent to its bounding box so I can snap its
	    already-moved components to the parent's grid */
	get_shape(Node, bounding_box, BB),
	change_shape(Node, internal_extent, BB),
	resnap(Node, 0),
	    
	(has_outer_equiv(Inner, Node, Outer),
		/* demolition process will delete section nearest source so off this */
		off(Inner), off(Outer), fail;
	decapsulate(Node, Orphan_nodes, MovedLinks)),
	    /* Now everything from the dead submodel must be redisplayed
	    because its fatness will have changed to match the new parent */
	(member(State, States),
	    update_default_refs_in_eqns(Node, State),
	    fail;
	 member(OrphanNode, Orphan_nodes),
	    redisplay_border(OrphanNode),
	    fail;
	member(MovedLink, MovedLinks),
	    menu'><'reroute_sections([MovedLink]),
	    move_link(MovedLink),
	    fail;
	remove_old_incomplete,
	    member(OrphanLink, OrphanLinks),
	    redisplay(OrphanLink), /* also need to change endpoints */
	    fail;
	true)).

list_captions(Parent, Used) :-
	setof(UsedCaption,
	      Part^(find_all_comps(Parent, Part),
		    appears(Part),
                    \+ Part is_of_sort captionless,
                    \+ Part is_of_sort common_caption,
		    \+ is_ghost(Part),
		    caption_for(Part, UsedCaption)),
	      UsedNow), !,
	append(UsedNow, _, Used).

retitle_duplicate(Node, Used) :-
    (\+ appears(Node);
     Node is_of_sort captionless; Node is_of_sort common_caption), !;
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
