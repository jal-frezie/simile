/*
draw.pl
- - - -
This is the module with the job of making sure what is on the screen reflects the
internal state of the editor. It receives requests to redraw the screen, and
occasionally individual components, from the event handler.

There is a bit of a philosophical problem when using Tcl/Tk. We don't really want
to redraw the screen every time it changes, that would give it a horrible jumpy
appearance. So we also need to draw/redraw individual components, and these redraws
have to be signalled from the consistency checker module, since the event handler
doesn't even get all the info as to what objects are actually manipulated. OK, hang
on while I change the spec to reflect that.
*/

sicstus_module(draw,
	       [cursor_is/1, callback/1, append_callback/1,
		enable_text_editing_in/1, disable_text_editing_in/1,
		select_text/2, get_component_from_gui/4,
		get_group_from_gui/3, get_text/3,
		find_relevant_windows/4, update_captions/1, reset_titles/1,
		update_color/1, shift_images/3,
		give_focus/1, has_focus/1,
		update_ability/5, scrub_run/2, kill_helpers/1,
		display_mode/1, display_menu/1, off/1,
		shift_marked/2, untag_all/0,
		move_text/2, move_group/2, move_display/2, reroute_display/1,
		update_link_route/1, redisplay/1, redisplay_border/1,
		add_window/9, redraw_window/1, delete_window/1,
		inject_graphics/2, translate_canvas_pl_names/2, display_area/1,
		save_canvas/4, expand_canvas/2,
		refatten_toplevels/2, adjust_toplevel_windows/2,
		highlight/2, normalize/1, current_edit/2,
		remove_old_incomplete/0, draw_rubberband/1,
		remove_old_rubberband/0, draw_links/4,
		tk_get_pref/2, exit_AME/0,
		tk_equationlisting_start/2,tk_equationlisting_addsubmodel/5,
		tk_equationlisting_addvariable/7]).

sicstus_use_module([library(lists), sp_only, state, image, ame_gen, output,
		    utility]).

cursor_is(Cursor) :-
	tk_cursor_is(Cursor).

append_callback(Content) :-
	tk_append_callback(Content).

callback(Content) :-
	tk_callback(Content).

display_area(Win) :-
	tk_display_area(Win).

update_captions(Model) :-
	reset_titles(Model),
	(caption_for(Model, New_caption),
	    find_relevant_windows(Model, Window, _, _),
	    change_text_to(Window, Model, New_caption),
	    fail;
	true).

reset_titles(Model) :-
	make_header(Model, Header),
	get_window_colour(Model, Colour, Images),
	(Window shows_model Model,
	    change_title_to(Window, Header, [Colour | Images]),
	    fail;
	true).

update_ability(SubModel, Un, Men, Itm, Re) :-
	contains(Model, SubModel),
	Win shows_model Model,
	tk_update_ability(Win, Un, Men, Itm, Re),
	fail;
	true.

display_mode(New_mode) :-
	tk_display_mode(New_mode).

display_menu(New_menu_highlight) :-
	tk_display_menu(New_menu_highlight).

/* find_relevant_windows/4: this returns the windows in which a component appears, excluding its own top-level windows. It should take account of the windows' settings for display level of detail, as well as whether or not display inside components is enabled. Currently also used to find translation for a component in a given window. */

find_relevant_windows(Comp, Window_id, Depth, Trans) :-
	\+ suspend_display,
	find_all_comps(Parent, Comp),
	Window_id shows_model Top,
	translate_between(Top, Parent, Depth, Trans).

/*translate_between(Model, Model, [0, 0, 1, 1]) :- !.

translate_between(Big, Small, Trans) :-
	find_all_comps(Parent, Small),
	translate_between(Big, Parent, SubTrans),
	add_to_translation(SubTrans, Small, Trans).

translate_between(Small, Big, Trans) :-
	find_all_comps(Parent, Small),
	translate_between(Parent, Big, SubTrans),
	subtract_from_translation(SubTrans, Small, Trans).

translate_between(Big, Small, Trans) :-
	contains(Big, Small, Chain), !,
	all(image, =, [build(Chain), add_to_translation(Trans, [0,0,1,1])]).
					      
translate_between(Small, Big, Trans) :-
	contains(Big, Small, Chain), !,
	all(image, =, [build(Chain), subtract_from_translation(Trans, [0,0,1,1])]).
*/					      

kill_recursive(Wid, Comp) :-
	find_all_comps(Comp, SubComp),
	    kill_recursive(Wid, SubComp),
	    fail;
	kill_featured(Wid, Comp).

off(Comp) :-
	find_relevant_windows(Comp, Wid, _, _),
	kill_featured(Wid, Comp),
	fail.

off(_) :- !.

/* move_text/2 is to make it go faster; just translates the vector and shifts
text of obj. */

move_text(Obj, [Xoff, Yoff]) :-
	find_relevant_windows(Obj, Wid, _, [_, _, Xscale, Yscale]),
		Xmotion is Xoff/Xscale,
		Ymotion is Yoff/Yscale,
		shift_text(Wid, Obj, [Xmotion, Ymotion]),
		fail;
	true.

tag_movable(Obj) :-
	find_relevant_windows(Obj, Wid, _, [_, _, _Xscale, _Yscale]),
	    mark_model(Wid, Obj);
	true.

untag_all :-
	Wid shows_model _,
	    unmark_objs(Wid),
	    fail;
	true.

mark_model(Wid, Obj) :-
	mark_obj(Wid, Obj),
	find_all_comps(Obj, Child),
	mark_model(Wid, Child).

shift_marked(Handle, [Xoff, Yoff]) :-
	find_relevant_windows(Handle, Wid, _, [_, _, Xscale, Yscale]),
	    Xmotion is Xoff/Xscale,
	    Ymotion is Yoff/Yscale,
	    shift_obj(Wid, '/moving/', [Xmotion, Ymotion]),
	    fail;
	true.

move_group(Movers, [Xoffset, Yoffset]) :-
	all(draw, move_display,
	    [build(Movers), unify([Xoffset, Yoffset])]).

/* move_display/2 is to make it go faster; just translates the vector and shifts
everything answering to the description of obj. */

move_display(Obj, [Xoff, Yoff]) :-
	find_relevant_windows(Obj, Wid, _, [_, _, Xscale, Yscale]),
		Xmotion is Xoff/Xscale,
		Ymotion is Yoff/Yscale,
		shift_model(Wid, Obj, [Xmotion, Ymotion]);
	true.

/* this ultimately fails. */

shift_model(Wid, Obj, Vect) :-
	shift_obj(Wid, Obj, Vect),
	find_all_comps(Obj, Child),
	shift_model(Wid, Child, Vect).

update_link_route(Link) :-
	find_type(Link, Type),
	(Type is_class_of_sort captionless;
% need to redisplay all flow sections so meters move
%	 Type is_class_of_sort has_bowtie,
%	    find_base(Link, Base),
%	    \+ Base = Link;
	 Type = relation,
	    \+ get_boundary_end(Link, true)), !,
	reroute_display(Link);
	redisplay(Link).

/* reroute_display/1 is also to make it go faster; used when something changes
shape as well as position. New shape is calculputed from graphical info. */

reroute_display(Obj) :-
	get_link_route(Obj, Course),
	    find_relevant_windows(Obj, Wid, _, Trans),
	    untranslate(Course, Trans, ScreenCourse),
	    zap_route(Wid, Obj, ScreenCourse),
	    fail;
	true.

/*
redisplay/1: This has the unenviable task of updating all the model structure
windows which might need to include it when a new component is added to the model.
This means that it needs to use the tree structures of the model database to find
out which windows include it. It's probably quickest to test each window in turn,
and not to forget that because submodules are displayed as subwindows (which will
of course make life very painful when porting to systems not supporting borderless
windows) we only need to draw the new shape in windows illustrating its parent...
*/

redisplay(Comp) :-
	find_relevant_windows(Comp, Window_id, Depth, Trans),
	Window_id shows_model Top,
	contains(Top, Comp, Levels),
	\+ (member(Hider, Levels),
	       \+ Hider = Comp,
	       get_shape(Hider, hide_contents, 1)),
	kill_recursive(Window_id, Comp),
	display(Window_id, Comp, Depth, Trans, 1),
	fail;
	true.

redisplay_border(Comp) :-
	find_relevant_windows(Comp, Window_id, Depth, Trans),
	kill_featured(Window_id, Comp),
	display(Window_id, Comp, Depth, Trans, 0),
	fail;
	true.

display(Window_id, Comp, Depth, Trans, Recurse) :-
        start_drawing_group(Window_id),
	(find_type(Comp, text), !,
	    draws_at(Window_id, text, Depth),
	    get_shape(Comp, centre, [X,Y]),
	    find_fatness(Trans, DefFatness),
	    get_flash(Comp, Lit),
	    (get_shape(Comp, caption_offset, [RelSize | Vals]), RelSize > 0, !;
		[RelSize | Vals] = [100, 0]),
	    Fatness is RelSize*DefFatness/100,
	    add_caption(Window_id, Comp, text, [X,Y,X,Y], Trans, Fatness, Vals, Lit);
	Comp is_of_sort box,
	display_in(Window_id, Comp, Depth, Trans),
	(Recurse = 1,
	find_type(Comp, submodel),
	\+ get_shape(Comp, hide_contents, 1),
	New_depth is Depth + 1,
	draws_at(Window_id, submodel, New_depth), !,
	    add_to_translation(Trans, Comp, Subtrans),
	    (find_all_comps(Comp, Subcomp),
		display(Window_id, Subcomp, New_depth, Subtrans,
			Recurse),
		fail;
	    update_tk);
	true);
	Comp is_of_sort line,
	    display_link_in(Window_id, Comp, Depth, Trans)),
	(get_highlit_obj(N, Comp), !,
	    highlight(Comp, N);
	true),
        finish_drawing_group(Window_id).

/* highlight not only redraws the component in any of a number of styles, it also
records its id in the GUI state database so it can be manipulated independently of
the model database, which is very useful if we want to undraw it after it has been
deleted from the latter.

Highlighting is a property of the graphical node; ghost nodes are not highlighted
along with their bases. */

highlight(Obj, Defcon) :-
	set_highlit_obj(Defcon, Obj),
	member(Defcon-Color, 
		[0-select, 1-highlight, 2-target, 3-affect]),
	change_color(Obj, Color).

normal_colour_for(Obj, Colour) :-
	draws_complete(Obj), !,
		Colour = normal;
	Colour = incomplete.

normalize(Obj) :-
	get_highlit_obj(Defcon, Obj),
	normal_colour_for(Obj, Colour),
	change_color(Obj, Colour),
	forget_highlit_obj(Defcon, Obj).

update_color(Obj) :-
	appears(Obj),
	check_complete(Obj),
	\+ get_highlit_obj(_, Obj),
	normal_colour_for(Obj, Colour),
	change_color(Obj, Colour).

/* find_relevant_windows does lots of messing with translations which I don't need
here; quicker just to send instruction to all windows. Must be cut free. */

change_color(Obj, Color) :-
	\+ suspend_display,
	/* find_relevant_windows(Obj, Wid, _, _), */
	draw_style_for(Obj, Type),
	Wid shows_model _,
	tk_change_color(Wid, Obj, Type, unchanged, Color), fail.

change_color(_, _).

:- dynamic(has_focus/1).

give_focus(Obj) :-
	Wid shows_model _,
	force_edit(Wid, Obj),
	fail;
	retractall(has_focus(_)),
	assert(has_focus(Obj)).

/* exterminate: removes deleted stuff from the screen. Includes recursive calls to match the recursive action of deletion from model.

first blow away windows, this saves work.

exterminate(Obj) :-
	Win shows_model Obj,
	delete_window(Win),
	fail.

exterminate(Obj) :-
	find_all_comps(Parent, Obj),
	Win shows_model Parent,
	kill_featured(Win, Obj),
	fail.

exterminate(Obj) :-
	find_all_comps(Obj, Child),
	exterminate(Child),
	fail.

exterminate(_).

add_caption: This is somewhat tricky as most of our GUI languages support the user directly editing the names of the components, and indeed, 
Powersim does this. Still, we must simply call a textual output device, and when the user changes the name of the component we will end up coming through here, where a pre-draw check will (in the tk case) show us that the name has already changed, thus not needing further interference. 
*/

add_caption(Wid, Id, Style, Box, Trans, Fatness, Specials, Colour_scheme) :-
	caption_for(Id, Caption),
	get_text_offset(Id, Style, DefAnchor, _ForLater),

	( /* Style = submodel, !,
	    DefAnchor = nw; */
	Style = flow,
	Box = [L, T, R, B],
	R-L>B-T, !,
%	    DefAnchor = e,
	    PosStyle = vflow,
	    rotate_compass(DefAnchor, UseAnchor);
/*	member(Style, [compartment, channel, variable, flow]), !,
	    DefAnchor = s;
	DefAnchor = c),
	(nonvar(PosStyle), !; */
	  PosStyle = Style,
	    UseAnchor = DefAnchor),

	(Style = text ->
	    [XOff, YOff] = [0, 0];
	  (get_shape(Id, caption_offset, [XOff, YOff]);
	      get_shape(Id, caption_offset, [XOff, YOff, _Anchor]);
	      XOff = 0, YOff = 0,
	      set_shape(Id, caption_offset, [XOff, YOff]))), !,
	image'><'map(Box, UseAnchor, _,_, TextX, TextY),
	VirtX is TextX + XOff,
	VirtY is TextY + YOff,
	untranslate([VirtX, VirtY], Trans, ScreenPoint),
	(is_ghost(Id), !,
		EditState = [];
	get_mode(select), !,
		EditState = [editable, currently_editable];
	EditState = [editable]),
/* currently added to last choice to test alternative edit prevention */
	text(Wid, ScreenPoint, PosStyle, [Id, fillable | EditState],
			Fatness, Specials, Colour_scheme, Caption).

rotate_compass(H, V) :-
	suffix([V, _, H | _], [e, se, s, sw, w, nw, n, ne, e, se, c, _, c]), !.

get_group_from_gui(W, Box, List) :-
	tk_get_group_from_gui(W, Box, List).

/* redraw_window/1: Well it is simple to describe what this does; it redraws the contents of the window. But I won't know how it works till I've written it.
*/

add_window(Wid, TopNode, Model, Area, Cname, Colour, Scale, InitDs, IsTL) :-
	make_header(Model, Header),
	tk_add_window(Wid, TopNode, Header, Area, Cname, Colour, Scale, InitDs,
		      IsTL).

redraw_window(Wid) :-
	Wid shows_model Model,
	clear_display(Wid),
	update_tk,
	find_all_comps(Model, Component),
	display(Wid, Component, 0, [0, 0, 1, 1], 1),
	fail.

/* Having drawn the components, succeed and don't come back...*/
redraw_window(_) :- !.

delete_window(Wid) :-
	destroy_window(Wid),
	tk_kill_window(Wid).

scrub_run(Node, Times) :- tk_scrub_run(Node, Times).
kill_helpers(Node) :- tk_kill_helpers(Node).

/* expand_canvas/2: grows the virtual display area of a model to
encompass a new point, if indeed the point was outside its current
display area. If it is a submodel, it plays with the actual values a
bit to make sure the new
canvas has the same aspect ratio as the old. */

expand_canvas(Parent, [NL, NT, NR, NB]) :-
	(\+ backup'><'is_toplevel(Parent),
	    get_shape(Parent, bounding_box, [BL, BT, BR, BB]), !,
	    BoxRatio is (BR-BL)/(BB-BT),
	    ModelRatio is (NR-NL)/(NB-NT),
	    (ModelRatio > BoxRatio, !,
		XL = NL, XR = NR,
		grow_to_scale(NT, NB, ModelRatio/BoxRatio, XT, XB);
	    XT = NT, XB = NB,
		grow_to_scale(NL, NR, BoxRatio/ModelRatio, XL, XR));
	XL = NL, XR = NR, XT = NT, XB = NB),
	add_to_translation([0,0,1,1], Parent, OldTrans),
	change_shape(Parent, internal_extent, [XL, XT, XR, XB]),
	adjust_toplevel_windows(Parent, [XL, XT, XR, XB]),
	adjust_submodel_internals(Parent-OldTrans).

grow_to_scale(OldLo, OldHi, Scale, NewLo, NewHi) :-
	Middle is (OldHi + OldLo)/2,
	NewLo is Middle - (Middle - OldLo)*Scale,
	NewHi is Middle + (OldHi - Middle)*Scale.

refatten_toplevels(Parent, DFat) :-
	Window shows_model Parent,
	tk_refatten(Window, DFat),
	fail;
	true.
	
adjust_toplevel_windows(Parent, NewRect) :-
	Window shows_model Parent,
	tk_grow_canvas(Window, NewRect),
	fail;
	true.

adjust_submodel_internals(Model-OldTrans) :-
/* imagine a component in the submodel that appears as a unit square. We work
out what position that would have in the submodel coordinates, then work out
where the same thing would appear after the boundary change, then tell TclTk
to apply that transform to the submodel graphics...simple */
        setof(Item, contains(Model, Item), ListPlus),
	select(Model, ListPlus, InList),
	find_relevant_windows(Model, Win, _Depth, Trans),
	translate([0,0,1,1], Trans, Step1),
	translate(Step1, OldTrans, CoordsInSubmodel),
	add_to_translation(Trans, Model, InTrans),
	untranslate(CoordsInSubmodel, InTrans, [L, T, R, _B]),
	FatChange is R-L,
	zoom_bits_in(Win, Model, FatChange, [L, T], InList),
	fail; % now do simple stuff
	redisplay_border(Model),
	event'><'make_links_follow(Model).
	
get_flash(Comp, Colour_scheme) :-
	get_highlit_obj(Comp, Index), !,
		member(Index-Colour_scheme, [0-select, 1-highlight, 2-target]);
	normal_colour_for(Comp, Colour_scheme).

display_in(Wid, Comp, Depth, Trans) :-
	(appears(Comp),
	get_drawing_form(Comp, Style, BBox),
	draws_at(Wid, Style, Depth), !,
	    (Style = channel, !,
		find_type(Comp, Density);
	    density_for(Comp, Density)),
	    untranslate(BBox, Trans, Screen_list),
	    find_fatness(Trans, Fatness),
	    get_flash(Comp, Colour_scheme),
	    multiple_draw(Comp, MNum),
	    find_base(Comp, BComp),
	    is_parameter(BComp, P),
	    DNum is MNum+10*max(0, P),
	    (Comp is_of_sort discrete, !,
	        (P = 1 -> Num is DNum+120;
		Num is DNum+100);
	    Num=DNum),
	    (Style=state, !,
	       DCmd = compartment;
	    DCmd = Style),
	    
	    (Style = submodel, !,
		get_colour(Comp, FillColour, FillImage, ImgPos),
		get_window_colour(Comp, BgColour, _),
/* if no contents displayed, set scheme to incomplete to avoid drawing grid */
	        (\+ get_shape(Comp, hide_contents, 1),
		    New_depth is Depth + 1,
		    draws_at(Wid, submodel, New_depth), !,
		    add_to_translation(Trans, Comp, InTrans),
		    find_fatness(InTrans, InFat),
		    untranslate([0,0], InTrans, [Ox, Oy]);
		[InFat, Ox, Oy] = [0,0,0]),
	        submodel(Wid, Screen_list, Num, Fatness,
				  FillColour, FillImage, ImgPos, Ox, Oy,
				  BgColour, InFat, Colour_scheme, Comp);
	    (Style is_class_of_sort box; Style = channel), !,
	    Draw_command =.. [DCmd, Wid, Screen_list, Num, Fatness,
				  Density, Colour_scheme, [Comp]],
		call(Draw_command);
	    output'><'safe_tcl_eval([puts, dq(['Failed to draw component',
			Comp, 'as', Style, '...removing'])], _),
		m_update'><'oblitterfry(Comp)),
	    (get_display_depth(Wid, caption, Caption_detail),
		((Style = cloud; \+ appears(Comp); Caption_detail =< Depth), !;
		add_caption(Wid, Comp, DCmd, BBox, Trans, Fatness, [0], Colour_scheme)));
	true).

display_link_in(Wid, Link, Depth, Trans) :-
	appears(Link),
	/* speed hack: do not check influence type if not drawing it anyway */
	find_type(Link, LType),
	(\+ LType = influence;
	    (draws_at(Wid, influence, Depth),
		get_display_depth(Wid, sections, WhichSections),
		right_section(Link, WhichSections);
	    draws_at(Wid, ghost_link, Depth))), !,
	draw_style_for(Link, Type),
	draws_at(Wid, Type, Depth),
	get_link_route(Link, Coord_list),
	untranslate(Coord_list, Trans, Screen_coords),
	find_fatness(Trans, RelFatness),
	get_flash(Link, Colour_scheme),
        (Type = flow,
	    multiple_draw(Link, Num);
	  Type = influence,
	    m_class'><'Link has_attribute enabled_roles of EnabList,
	    member(RIdx, EnabList),
	    member(RIdx, [-1, -2, -3]),
	    Num = 4; % or however many insts current submodel has
	  Num = 1), !,
	(Type = influence,
	    find_name_host(Link, ControlThing),
	    m_class'><'ControlThing has_attribute use_sofar of 1, !,
	    UseType = broken_influence;
	UseType = Type),
	Draw_command =.. [UseType, Wid, Screen_coords, Num,
			RelFatness, Colour_scheme, [Link]],
	call(Draw_command),
	((get_drawing_form(Link, LType, Bowtie),
	  density_for(Link, Density),
	  Density = {}, % prevent ghost controls on non-master sections
	        untranslate(Bowtie, Trans, Screen_bowtie),
		(LType = flow, !,
		    bowtie(Wid, Screen_bowtie, RelFatness,
		       Density, Colour_scheme, [Link]);
		event(Wid, Screen_bowtie, 0, RelFatness,
		       Density, Colour_scheme, [Link, bowtie]));
	  Type = relation,
	  	get_boundary_end(Link, true),
	        get_caption_anchor(Coord_list, Bowtie)), !,
	    /* bowtied links (flows) and top sections of
	    relations have captions */
	    (get_display_depth(Wid, caption, Caption_detail),
		Caption_detail =< Depth, !;
	    add_caption(Wid, Link, Type, Bowtie, Trans, RelFatness, [0], Colour_scheme));
	true).

find_fatness([_,_,FatX,FatY], Fatness) :-
	Fatness is 100/sqrt(FatX*FatY).

draw_incomplete(Line_type) :-
	get_incomplete(Parent-Draw_coords),
	contains(Backgnd, Parent),
	find_current(Window_id),
% comment out above line to show incompletes in all windows
	Window_id shows_model Backgnd,
	translate_between(Backgnd, Parent, _D, Trans),
	untranslate(Draw_coords, Trans, ScreenCoords),
	find_fatness(Trans, Fatness),
	use_style_for(Line_type, Draw_type),
	Draw_command =.. [Draw_type, Window_id, ScreenCoords, 1,
			  Fatness, incomplete, [unfinished_line]],
	call(Draw_command),
	fail;
	true.

remove_old_incomplete :-
	Window_id shows_model _,
	kill_featured(Window_id, unfinished_line),
	fail; true.

draw_rubberband(Style) :-
	get_incomplete(Box),
	find_current(Window_id),
	get_translation(Trans),
	untranslate(Box, Trans, Draw_box),
	(Style = square, !,
	    Fatness = 0;
	find_fatness(Trans, Fatness)),
	submodel(Window_id, Draw_box, 1, Fatness, clear, none,none, 0,0, white,
		 100, incomplete, [unfinished_component, '/background/']).

remove_old_rubberband :-
	find_current(Window_id),
	kill_featured(Window_id, unfinished_component).

/* draw_links/4: draws incomplete link during drag. Input is link type 
(flow/influence), Top submodel containing highest-level section of link, and lists
of other submodels from which the link exits/enters, deepest first. The end points 
of these lists may be node names, coordinate pairs (if dragging to the mouse point 
rather than into a box) or variable (if there's nothing at the end of the link, 
i.e., it is purely hierarchical). Only current window is drawn in. */

draw_links(Type, Top, Up_list, Down_list) :-
	clear_incomplete,
	(reverse(Up_list, [Last | Rest]), !,
		/* last is a node */
		(reverse(Down_list, [Last2 | Rest2]), !,
			(atom(Last2), !,
				route_link(Type, [Last | Rest], [Last2 | Rest2], Route);
			/* Last2 is a point */
				route_part_link(Type, out, [Last | Rest], Last2, Route));
		/* Down_list empty */
			route_parent_child_link(Type,out,Top,[Last | Rest], Route));
	/* up list is empty */
		(reverse(Down_list, [Last2 | Rest2]), !,
			(atom(Last2), !,
				route_parent_child_link(Type, in, Top, [Last2 | Rest2], Route);
			/* Last2 is a point */
				route_interior_part_link(Type, in, Top, Last2, Route)))),

	/* assume that there is always something to draw */
	find_current(Wid),
	Wid shows_model Backgnd,
	(var(Rest), !; 
		last(Route, In), 
		draw_up_links(Type, Rest, out, Backgnd, Last, In)),
	(var(Rest2), !; 
		Route = [Out | _], 
		draw_up_links(Type, Rest2, in, Backgnd, Last2, Out)),
%	(translate_between(Backgnd, Top, _D, Trans) ->
/*	remove_old_incomplete, (done on drag now to avoid cluttering target */
%	    untranslate(Route, Trans, Screen_route),
%	    add_incomplete(Top-Screen_route);
%	  true),
	add_incomplete(Top-Route),
	draw_incomplete(Type).

draw_up_links(_, [], _,_,_,_).

draw_up_links(Type, [Node | Rest], Dir, Backgnd, Prev, Point) :-
	add_to_translation([0,0,1,1], Prev, New_trans),
	translate(Point, New_trans, Border_point),
	(atom(Node), !,
		route_part_link(Type, Dir, [Node | Rest], Border_point, Route);
	(Dir = in, shape_route(Type, Border_point, Node, Route);
	Dir = out, shape_route(Type, Node, Border_point, Route))),
%	(translate_between(Backgnd, Prev, _D, Trans) ->
%	 untranslate(Route, Trans, Screen_route),
%	add_incomplete(Prev-Screen_route);
%	 true),
	add_incomplete(Prev-Route),
	(Dir = in, Route = [Next | _];
	Dir = out, last(Route, Next)),
	draw_up_links(Type, Rest, Dir, Backgnd, Node, Next).

/*
show_invisible_links(Links) :-
	find_current(Wid),
	    Wid shows_model Backgnd,
	    member(Link, Links),
	    find_all_comps(Daddy, Link),
	    m_update'><'contains(Backgnd, Daddy, Chain),
	    length(Chain, Depth),
	    draw_style_for(Link, Type),
	    \+ draws_at(Wid, Type, Depth),
	    translate_between(Backgnd, Daddy, _D, Trans),
	    get_shape(Link, course, Route),
	    untranslate(Route, Trans, ScreenRoute),
	    add_incomplete(Daddy-ScreenRoute),
	    fail;
	draw_incomplete(Type).
*/


% ############################################ Start Bob's changes

tk_equationlisting_start(DefaultName, Model) :-
	safe_tcl_eval(['equationlisting_start', br(write(DefaultName)),
		       Model], _).

tk_equationlisting_addsubmodel(Node,Isub,Submodel,TimeStep,Type):-
	safe_tcl_eval(['equationlisting_addsubmodel', Node,
		br(write(Isub)),
		br(write(Submodel)),
		br(write(TimeStep)),
		br(write(Type))], _).

tk_equationlisting_addvariable(VarType,VarLabel,Expression,
			       Node, MinMax,InFlows,OutFlows) :-
/*
	safe_tcl_eval(['tk_messageBox -message {tk_equationlisting_addvariable ',
		br(write(Isub)),
		br(write(Ivar)),
		br(write(VarType)),
		br(write(VarLabel)),
		br(write(Expression)),
		br(write(Where)),
		br(write(Description)),
		br(write(Comments)),
		br(write(InFlows)),
		br(write(OutFlows)),'}'], _),  % jmm
	safe_tcl_eval(['update idletasks'],_),  % jmm
*/
	safe_tcl_eval(['equationlisting_addvariable', Node,
		br(write(VarType)),
		br(write(VarLabel)),
		br(write(Expression)),
		br(write(MinMax)),
		br(write(InFlows)),
		br(write(OutFlows))], _),  % jmm
	safe_tcl_eval(['update idletasks'], _).


% ############################################ End Bob's changes



