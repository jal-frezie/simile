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
	       [cursor_in/2, callback/1,
		enable_text_editing_in/1, disable_text_editing_in/1,
		select_text/2, get_component_from_gui/4, get_text/3,
		find_relevant_windows/4, update_captions/1, reset_titles/1,
		update_color/1, shift_images/3,
		give_focus/1, has_focus/1,
		update_ability/5, scrub_run/2, kill_helpers/1,
		display_mode/1, display_menu/1, off/1, off_all/1, 
		move_text/2, move_display/2, reroute_display/1,
		redisplay/1, redisplay_border/1,
		add_window/9, redraw_window/1, delete_window/1,
		inject_graphics/2, translate_canvas_pl_names/2, display_area/1,
		save_canvas/4, expand_canvas/2, adjust_toplevel_windows/2,
		highlight/2, normalize/1, current_edit/2,
		remove_old_incomplete/0, draw_rubberband/1,
		remove_old_rubberband/0, draw_links/4, show_invisible_links/1,
		tk_get_pref/2, exit_AME/0,
		tk_equationlisting_start/1,tk_equationlisting_addsubmodel/2,
		tk_equationlisting_addvariable/11]).

sicstus_use_module([library(lists), state, image, ame_gen, output]).

cursor_in(Win, Cursor) :-
	tk_cursor_in(Win, Cursor).

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

off_all([]).

off_all([Comp | Comps]) :-
	off(Comp),
	off_all(Comps).

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


/* reroute_display/1 is also to make it go faster; used when something changes
shape as well as position. New shape is calculputed from graphical info. */

reroute_display(Obj) :-
	get_shape(Obj, course, Course),
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
	(find_type(Comp, text), !,
	    draws_at(Window_id, text, Depth),
	    get_shape(Comp, centre, [X,Y]),
	    find_fatness(Trans, Fatness),
	    get_flash(Comp, Lit),
	    add_caption(Window_id, Comp, [X,Y,X,Y], Trans, Fatness, Lit);
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
	true).

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
	(Type = flow, Density = {};
	\+ Type = flow, density_for(Obj, Density)),
	Wid shows_model _,
	tk_change_color(Wid, Obj, Type, Density, Color), fail.

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

add_caption(Wid, Id, Box, Trans, Fatness, Colour_scheme) :-
	caption_for(Id, Caption),
	draw_style_for(Id, ExactStyle),
	(ExactStyle=state, !,
	    Style = compartment;
	Style = ExactStyle),

	(Style = submodel, !,
	    DefAnchor = nw;
	Style = flow,
	Box = [L, T, R, B],
	R-L>B-T, !,
	    DefAnchor = e,
	    PosStyle = vflow;
	member(Style, [compartment, channel, variable, flow]), !,
	    DefAnchor = s;
	DefAnchor = c),
	(nonvar(PosStyle), !;
	 PosStyle = Style),

	(get_shape(Id, caption_offset, [XOff, YOff]);
	 get_shape(Id, caption_offset, [XOff, YOff, _Anchor]);
	 XOff = 0, YOff = 0,
	    set_shape(Id, caption_offset, [XOff, YOff])), !,
	image:map(Box, DefAnchor, _,_, TextX, TextY),
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
			Fatness, Colour_scheme, Caption).

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
	(\+ backup:is_toplevel(Parent),
	    get_shape(Parent, bounding_box, [BL, BT, BR, BB]), !,
	    BoxRatio is (BR-BL)/(BB-BT),
	    ModelRatio is (NR-NL)/(NB-NT),
	    (ModelRatio > BoxRatio, !,
		XL = NL, XR = NR,
		grow_to_scale(NT, NB, ModelRatio/BoxRatio, XT, XB);
	    XT = NT, XB = NB,
		grow_to_scale(NL, NR, BoxRatio/ModelRatio, XL, XR));
	XL = NL, XR = NR, XT = NT, XB = NB),
	change_shape(Parent, internal_extent, [XL, XT, XR, XB]),
	adjust_toplevel_windows(Parent, [XL, XT, XR, XB]),
	redisplay(Parent).

grow_to_scale(OldLo, OldHi, Scale, NewLo, NewHi) :-
	Middle is (OldHi + OldLo)/2,
	NewLo is Middle - (Middle - OldLo)*Scale,
	NewHi is Middle + (OldHi - Middle)*Scale.
	
adjust_toplevel_windows(Parent, NewRect) :-
	Window shows_model Parent,
	tk_grow_canvas(Window, NewRect),
	fail;
	true.

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
		Num is DNum+100;
	    Num=DNum),
	    
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
	    (Style=state, !,
	       DCmd = compartment;
	    DCmd = Style),
	    Draw_command =.. [DCmd, Wid, Screen_list, Num, Fatness,
				  Density, Colour_scheme, [Comp]],
		call(Draw_command)),
	    (get_display_depth(Wid, caption, Caption_detail),
		((Style = cloud; \+ appears(Comp); Caption_detail =< Depth), !;
		add_caption(Wid, Comp, BBox, Trans, Fatness, Colour_scheme)));
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
	get_shape(Link, course, Coord_list),
	untranslate(Coord_list, Trans, Screen_coords),
	find_fatness(Trans, RelFatness),
	get_flash(Link, Colour_scheme),
	(Type = influence,
	    find_name_host(Link, ControlThing),
	    m_class:ControlThing has_attribute use_sofar of 1, !,
	    UseType = broken_influence;
	UseType = Type),
	Draw_command =.. [UseType, Wid, Screen_coords, 
			RelFatness, Colour_scheme, [Link]],
	call(Draw_command),
	((get_drawing_form(Link, LType, Bowtie),
	  density_for(Link, Density),
	  Density = {},
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
	    add_caption(Wid, Link, Bowtie, Trans, RelFatness, Colour_scheme));
	true).

find_fatness([_,_,FatX,FatY], Fatness) :-
	Fatness is 100/sqrt(FatX*FatY).

draw_incomplete(Line_type) :-
	get_incomplete([_Parent | Draw_coords]),
	find_current(Window_id),
	get_translation(Trans),
	find_fatness(Trans, Fatness),
	use_style_for(Line_type, Draw_type),
	Draw_command =.. [Draw_type, Window_id, Draw_coords, Fatness, incomplete, [unfinished_line]],
	call(Draw_command),
	fail;
	true.

remove_old_incomplete :-
	find_current(Window_id),
	kill_featured(Window_id, unfinished_line).

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
	translate_between(Backgnd, Top, _D, Trans),
/*	remove_old_incomplete, (done on drag now to avoid cluttering target */
	untranslate(Route, Trans, Screen_route),
	add_incomplete([Top | Screen_route]),
	(var(Rest), !; 
		last(Screen_route, In), 
		draw_up_links(Type, Rest, out, Trans, Last, In)),
	(var(Rest2), !; 
		Screen_route = [Out | _], 
		draw_up_links(Type, Rest2, in, Trans, Last2, Out)),
	draw_incomplete(Type).

draw_up_links(_, [], _,_,_,_).

draw_up_links(Type, [Node | Rest], Dir, Trans, Prev, Point) :-
	add_to_translation(Trans, Prev, New_trans),
	translate(Point, New_trans, Border_point),
	(atom(Node), !,
		route_part_link(Type, Dir, [Node | Rest], Border_point, Route);
	(Dir = in, shape_route(Type, Border_point, Node, Route);
	Dir = out, shape_route(Type, Node, Border_point, Route))),
	untranslate(Route, New_trans, Screen_route),
	add_incomplete([Prev | Screen_route]),
	(Dir = in, Screen_route = [Next | _];
	Dir = out, last(Screen_route, Next)),
	draw_up_links(Type, Rest, Dir, New_trans, Node, Next).

show_invisible_links(Links) :-
	find_current(Wid),
	    Wid shows_model Backgnd,
	    member(Link, Links),
	    find_all_comps(Daddy, Link),
	    m_update:contains(Backgnd, Daddy, Chain),
	    length(Chain, Depth),
	    draw_style_for(Link, Type),
	    \+ draws_at(Wid, Type, Depth),
	    translate_between(Backgnd, Daddy, _D, Trans),
	    get_shape(Link, course, Route),
	    untranslate(Route, Trans, ScreenRoute),
	    add_incomplete([Daddy | ScreenRoute]),
	    fail;
	draw_incomplete(Type).



% ############################################ Start Bob's changes

tk_equationlisting_start(DefaultName) :-
	safe_tcl_eval(['equationlisting_start', br(write(DefaultName))], _).

tk_equationlisting_addsubmodel(Isub,Submodel):-
	safe_tcl_eval(['equationlisting_addsubmodel', 
		br(write(Isub)),
		br(write(Submodel))], _).

tk_equationlisting_addvariable(Isub,Ivar,VarType,VarLabel,Expression,Where,
			       MinMax,Description,Comments,InFlows,OutFlows) :-
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
	safe_tcl_eval(['equationlisting_addvariable', 
		br(write(Isub)),
		br(write(Ivar)),
		br(write(VarType)),
		br(write(VarLabel)),
		br(write(Expression)),
		br(write(Where)),
		br(write(MinMax)),
		br(write(Description)),
		br(write(Comments)),
		br(write(InFlows)),
		br(write(OutFlows))], _),  % jmm
	safe_tcl_eval(['update idletasks'], _).


% ############################################ End Bob's changes



