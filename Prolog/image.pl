/* image.pl
This contains all the functions that query and update the graphical (as opposed to
mathematical) aspects of a model. It uses the model database module model_class.pl,
which contains the graphical info together with the structural info, and it is made
use of by:

draw.pl (to ascertain what should be drawn on the screen),

event.pl (to work out what a particular keyclick means in terms of edit
commands).

It is not used by model_update.pl; event will call it to make screen updates
in response to successful editing operations.
*/

sicstus_module(image,
      [get_colour/4, get_window_colour/3,
       get_closest_edge/4, map/6, get_inner_bound/3, get_outer_bound/4,
       change_shape/3, get_shape/3, set_shape/3, clear_shape/2,
       targets/5, inside_shape/4, near/2, get_middle/2, middle/2,
       crossing_point/7, make_bounding_box/5,
       density_for/2, draw_style_for/2, use_style_for/2,
       get_drawing_form/3, get_boundary_end/2,
       has_outer_equiv/3, connected_at/2, fits_inside/2,
       draws_complete/1, check_complete/1, test_complete/1,
       get_inclusions/3, get_overlaps/3, draws_at/3, right_section/2,
        find_new_box/5, line_dir_change_radius_is/1,
       multiple_draw/2, update_bowtie/2, get_bowtie/2,
       adjust_bowtie/2, adjust_kink/2, adjust_spline/2,
       get_caption_anchor/2, end_coords/3,
       update_text_position/3, make_header/2,
       get_end_pt/5, get_link_route/2, shape_route/4, route_link/4,
       route_interior_part_link/5, route_part_link/5,
       route_parent_child_link/5, check_translation/1,
       translate_between/4, translate/3, rel_translate/3,
       untranslate/3, add_to_translation/3, add_boxes_to_translation/4,
       subtract_from_translation/3]).

sicstus_use_module([library(lists),
            sp_only, ame_gen, state, text, m_class, m_update]).

get_colour(Submodel, Colour, Image, ImgPos) :-
    (Submodel has_class_refinement fill_colour of Colour, !;
    Colour = clear),
    (Submodel has_class_refinement fill_image of Image, !;
    Image = none),
    (Submodel has_class_refinement image_posn of ImgPos, !;
    ImgPos = none).

/* This works out what you can see in a window background. If a model has a
colour it covers all images behind it, but if it is clear they can all be seen
as they may have transparent bits. So to save drawing time it might be useful
to give background colours to submodels with non-transparent images. */

get_window_colour(Submodel, Colour, Images) :-
    get_colour(Submodel, TopColour, TopImage, TopPos),
    ((TopImage = none; TopPos = 'Centred'), !, AddImages = [];
        AddImages = [[TopImage, TopPos]]),
    (TopColour = clear, !,
        (Parent has_part Submodel,
        get_window_colour(Parent, Colour, BaseImages), !;
        Colour = white,
        BaseImages = []),
        append(BaseImages, AddImages, Images);
    Colour = TopColour,
        Images = AddImages).

get_shape(Component, Shape_field, Data) :-
    Component has_graphical_attribute Shape_field of Data.

change_shape(Component, Shape_field, Data) :-
    Component has_changed_graphical_attribute Shape_field to Data.

set_shape(Component, Shape_field, Data) :-
    Component has_new_graphical_attribute Shape_field of Data.

clear_shape(Component, Shape_field) :-
    Component has_graphical_attribute Shape_field of _,
    Component no_longer_has_graphical_attribute Shape_field.

/* Routine to test if we have entered a component. As an experiment, only test for
submodels, relying on the GUI to signal events in other types of component. */

targets(Wid, Parent, Point, Depth, Comp) :-
    (Wid shows_model Parent; \+ get_shape(Parent, hide_contents, 1)), !,
    Parent has_part Comp,
    find_type(Comp, submodel),
    draws_at(Wid, submodel, Depth),
    appears(Comp),
    inside(Parent, Point, Comp).

inside(Parent, [X, Y], Comp) :-
    get_shape(Comp, bounding_box, Box),
    Comp has_class Class,
    inside_shape(Parent, [X, Y], Class, Box).

inside(_Parent, [X, Y], Comp) :-
    get_bowtie(Comp, [L, T, R, B]),
    X > L, X < R, Y > T, Y < B.

inside_shape(Parent, [X, Y], Class, [L, T, R, B]) :-
/* first do a rough test, for sake of speed: is point inside bounding box? */
    X > L, X < R, Y > T, Y < B,
/* If it is, do the accurate test depending on shape of component
(no further test necessary if it's a straight rectangle) */
    (member(Class, [flow, compartment, channel]);
        /* always, if in bounding box */
    (Class = variable; Class = influence),
        Cx is (L + R)/2, Cy is (T + B)/2,
        Radius is (B - T)/2,
        inside_range([X, Y], [Cx, Cy], Radius);
    Class = function,
        Narrowing is abs(2*Y - T - B)/4,
        X > L + Narrowing, X < R - Narrowing;
    Class is_class_of_sort cloud,
    /* try each of the three circles */
        get_cloud_centres([L, T, R, B], Radius, [Cx, Cy]),
        inside_range([X, Y], [Cx, Cy], Radius);
    Class is_class_of_sort rounded_rect,
        get_submodel_corner_radius(Parent, [L, T, R, B], Radius),
        Xmiss is max(0, max(L + Radius - X, X + Radius - R)),
        Ymiss is max(0, max(T + Radius - Y, Y + Radius - B)),
        Xmiss*Xmiss + Ymiss*Ymiss =< Radius*Radius), !.

inside_range([X1, Y1], [X2, Y2], R) :-
    Xd is X1 - X2,
    Yd is Y1 - Y2,
    Xd*Xd + Yd*Yd < R*R.

fits_inside([L, T, R, B], [BigL, BigT, BigR, BigB]) :-
    Border = 0,
    L > BigL + Border, R < BigR - Border, T > BigT + Border, B < BigB - Border.

in_box(Parent, Comp, Outer) :-
	find_all_comps(Parent, Comp),
	Comp is_model_class,
	get_host(Comp, Decider),
	get_drawing_form(Decider, _, Inner),
	fits_inside(Inner, Outer).

get_inclusions(Parent, Box, Included) :-
    setof(Component, in_box(Parent, Component, Box), Included), !;
    Included = [].

get_overlaps(Parent, Targets, Part) :-
%    find_all_comps(Parent, Part), speed hacked
    Parent has_part Part,
%    (Part is_connector from Node to _,
%	find_type(Part, flow),
%	\+ is_ghost(Part);
%    Part = Node),
    appears(Part),
    /* ignore invisibles like ghost bowties -- included in hack
    \+ (find_type(Part, flow), is_ghost(Part)), */
    get_drawing_form(Part, _, Box),
    member(Target, Targets),
    interferes(Target, Box).

get_inner_bound(Parent, Edge, Bound) :-
    get_shape(Parent, internal_extent, [L, T, R, B]),
    get_box_size(Parent, submodel, Standard),
    MinDiam is Standard/2,

    member(Edge-PBoundExp, [l-(R-MinDiam), t-(B-MinDiam),
           r-(L+MinDiam), b-(T+MinDiam)]),
    PBound is PBoundExp,                    
    (setof(BB, contains_box(Parent, BB), Boxes), !; Boxes = []),
    unite_boxes(Boxes, Edge, PBound, Bound).

get_outer_bound(Node, Parent, Edge, Bound) :-
    setof(BB, contains_box(Parent, BB), Boxes),
    get_shape(Node, bounding_box, NodeBox),
    get_shape(Parent, internal_extent, [PL, PT, PR, PB]),
    member(Edge-ParentBound, [l-PL, t-PT, r-PR, b-PB]),
    exclude_boxes(Boxes, NodeBox, Edge, ParentBound, Bound).

contains_box(Parent, Box) :-
    find_all_comps(Parent, Comp),
    get_drawing_form(Comp, _, Box).

unite_boxes([], _, Bound, Bound).

unite_boxes([[L1, T1, R1, B1] | Rest], Edge, PBound, Bound) :-
    unite_boxes(Rest, Edge, PBound, PB),
    member(Edge-BB, [l-min(L1, PB), t-min(T1, PB),
             r-max(R1, PB), b-max(B1, PB)]),
    Bound is BB.

exclude_boxes([], _,_, Bound, Bound).

exclude_boxes([[BL,BT,BR,BB] | Rest], [NL,NT,NR,NB], Edge, PBound, Bound) :-
    ((BT<NB,BB>NT,
        (Edge = l, BL<NL,BR>PBound, !, NBound = BR;
        Edge = r, BR>NR,BL<PBound, !, NBound = BL);
    BL<NR,BR>NL,
        (Edge = t, BT<NT,BB>PBound, !, NBound = BB;
        Edge = b, BB>NB,BT<PBound, !, NBound = BT));
    NBound = PBound),
    exclude_boxes(Rest, [NL, NT, NR, NB], Edge, NBound, Bound).

get_closest_edge(Node, [X,Y], Edge, [EfX, EfY]) :-
    get_shape(Node, bounding_box, [L,T,R,B]),
    slice(Y, T, B, Row),
    slice(X, L, R, Col),
    map([L,T,R,B], Edge, Row, Col, EfX, EfY).

/*  LM is L-X, TM is T-Y, RM is X-R, BM is Y-B,
    MM is max(max(LM, TM), max(RM, BM)),
    member(MM-Edge, [LM-l, TM-t, RM-r, BM-b]). */

make_bounding_box(New_obj, Xpt, Ypt, Cur_size, [L, T, R, B]) :-
    ((New_obj is_class_of_sort regular_box; New_obj = channel),
        L is Xpt - Cur_size/2,
        R is Xpt + Cur_size/2;
    New_obj is_class_of_sort elongated_box,
        L is Xpt - 2*Cur_size/3,
        R is Xpt + 2*Cur_size/3;
    New_obj is_class_of_sort tall_box,
        L is Xpt - 3*Cur_size/8,
        R is Xpt + 3*Cur_size/8;
    New_obj = flow,
        L is Xpt - Cur_size/4,
        R is Xpt + Cur_size/4;
      New_obj = squirt,
        L is Xpt - Cur_size/2 + 1, % tweak to allow caption rottion if verical
        R is Xpt + Cur_size/2 - 1),
    T is Ypt - Cur_size/2,
    B is Ypt + Cur_size/2.

density_for(Comp, Density) :-
    (Comp has_type relation;
	ghost_link(Comp, _Base, _Ghost);
        find_base(Comp, Base), \+ Base = Comp), !,
    Density = gray50;
    Density = '{}'.

draw_style_for(Link, ghost_link) :-
    ghost_link(Link, _Base, _Ghost), !.

draw_style_for(Obj, Style) :-
    (Obj has_class Type; Obj has_type Type),
    use_style_for(Type, Style).

use_style_for(Obj, channel) :-
    Obj is_class_of_sort channel, !.

use_style_for(Type, Shape) :-
    member(Type-Shape, [event-variable, squirt-flow]),
    !.

use_style_for(Style, Style).

get_boundary_end(Link, IsLast) :-
    Link is_connector from _Start to Finish,
    (terminates(Link, Finish), !,
        IsLast = true;
    IsLast = false).

/* has_outer_equiv and has_inner_equiv must now look at the link's relationship 
with the node containing its equivalence, because Geraint's stuff require that the 
equivalences are listed in order of the direction of flow/influence */

has_outer_equiv(Link, Model, Superlink) :-
    Model has_link_equivalences Blah,
    (member(Link-Superlink, Blah); member(Superlink-Link, Blah)),
    Superlink is_connector from A to B,
    (A = Model; B = Model).

connected_at(Link, End) :-
    (End = start, Link is_connector from Terminus to _;
    End = finish, Link is_connector from _ to Terminus),
    (find_type(Terminus, submodel),
        /* look for relation with child */
        has_outer_equiv(_, Terminus, Link);
    find_all_comps(Parent, Terminus),
        has_outer_equiv(Link, Parent, _);
    true), !. /* regular links don't need equivalents */

/* crossing_point/7 returns the point at which a line from arg1 (inside Comp)
    to arg2 (outside Comp) crosses its boundary, it used to work by successive
    approximation (Inefficient? Who said that?) calling iterate_to_crossing,
    but no longer.
*/

crossing_point(Parent, [X1, Y1], [RX2, RY2], Class, [L, T, R, B], Warp, Exit) :-
    L = R, T = B, !, Exit = [L, T]; /* do not faff with null areas */
    X2 is RX2 - Warp*(RY2-Y1),
    Y2 is RY2 + Warp*(RX2-X1),
    get_box_crossing([X1, Y1], [X2, Y2], [L, T, R, B], [Xx, Yx]),
    Xoff is X2-X1,
    Yoff is Y2-Y1,
    (member(Class, [flow, function, compartment, channel, state]), !,
        Exit = [Xx, Yx];
    Class = variable, !,
        /* assume line starts at centre */
        Rad is X1 - L,
        get_circle_crossings([X1, Y1], Rad, [X1, Y1], Xoff, Yoff, _, Exit);
    Class = submodel, !,
        get_submodel_corner_radius(Parent, [L, T, R, B], Rad),
        /* now choose a corner and constrain result to external segment */
        Exit = [X, Y],
        ((Xj is L + Rad,
                XSide = less;
        Xj is R - Rad,
                XSide = more),
        (Yj is T + Rad,
                YSide = less;
        Yj is B - Rad,
                YSide = more),
        get_circle_crossings([Xj, Yj], Rad, [X1, Y1], Xoff, Yoff, _, 
                             Exit), 
        (XSide = less, X < Xj; XSide = more, X > Xj),
        (YSide = less, Y < Yj; YSide = more, Y > Yj),
        !;
        Exit = [Xx, Yx]); /* no corners crossed it comes out the side */
    Class is_class_of_sort cloud, !,
        setof(cross(Frag, Point), 
            Centre^(get_cloud_centres([L, T, R, B], Rad, Centre),
            get_circle_crossings(Centre, Rad, [X1, Y1], Xoff, Yoff,
                    Frag, Point)),
            Crossings),
        member(cross(Proportion, Exit), Crossings),
        \+ (member(cross(BiggerProportion, _), Crossings),
            BiggerProportion > Proportion)).

/* this finds the fraction of a parameterized line on one side of an arc
...many thanks to good old Bowyer & Woodwark, "A programmer's geometry" */

get_circle_crossings([Xj, Yj], Rad, [X0, Y0], F, G, Tp, [X, Y]) :-
    Fsq is F*F,
    Gsq is G*G,
    FGsq is Fsq+Gsq,
    FGsq > 0,
    Xj0 is Xj - X0,
    Yj0 is Yj - Y0,
    FyGx is F*Yj0 - G*Xj0,
    Root is Rad*Rad*FGsq - FyGx*FyGx,
    Root > -0.0001, /* fails if line nowhere near */
    FxGy is F*Xj0 + G*Yj0,
    (Root < 0.0001,
        Tp is FxGy/FGsq;
    Root >= 0.0001,
        SqRoot is sqrt(Root),
        (Tp is (FxGy + SqRoot)/FGsq)),
%    Tp > -0.0001,
    X is X0 + F*Tp,
    Y is Y0 + G*Tp.

get_submodel_corner_radius(Parent, [L, T, R, B], Radius) :-
	get_box_size(Parent, submodel, Size),
        Radius is min(B - T, R - L)*Size/400.

get_cloud_centres([L, T, R, B], Rad, [Cx, Cy]) :-
    Rad is (B - T)/3,
    (Cy is (2*B + T)/3,
        (Cx is (2*L + R)/3; Cx is (L + 2*R)/3);
    Cy is (B + 2*T)/3, Cx is (L + R)/2).

/* this used to find points on borders for drawing links to. It is now of
historical interest only (it was inefficient). 

iterate_to_crossing([X1, Y1], [X2, Y2], Class, [L, T, R, B], Exit) :-
    X3 is (X1 + X2)/2,
    Y3 is (Y1 + Y2)/2,
    ((X3 = X1, Y3 = Y1; X3 = X2, Y3 = Y2), !,
        Exit = [X3, Y3];
    inside_shape([X3, Y3], Class, [L, T, R, B]), !,
        iterate_to_crossing([X3, Y3], [X2, Y2], Class, [L, T, R, B], Exit);
    iterate_to_crossing([X1, Y1], [X3, Y3], Class, [L, T, R, B], Exit)).
*/

get_box_crossing([X1, Y1], [X2, Y2], [L, T, R, B], [Xx, Yx]) :-
    (0.0 is float(X2-X1), !, Xfract = Yfract; % ignore it
        Xfract is max((R - X1)/(X2 - X1), (X1 - L)/(X1 - X2))),
    (0.0 is float(Y2-Y1), !, Yfract = Xfract; % hope one is non-null
        Yfract is max((B - Y1)/(Y2 - Y1), (Y1 - T)/(Y1 - Y2))),
    Fract is min(Xfract, Yfract),
    Xx is X1 + Fract*(X2 - X1),
    Yx is Y1 + Fract*(Y2 - Y1).

middle([L, T, R, B], [X, Y]) :-
    X is (L + R)/2,
    Y is (T + B)/2.

/* This tests whether the endpoints of a link are visible
before drawing it; probably more trouble than it's worth.

visible_for(Wid, Link, Component, Depth) :-
    draws_at(Wid, Component, Depth), !;
    \+ get_shape(Component, _, _), !;
    has_outer_equiv(Sublink, Component, Link),
    Sub_depth is Depth + 1,
    draws_at(Wid, Sublink, Sub_depth).

get_drawing_form: Checks if a noder is a ghost, and if it is, gives a bounding box based on substituting the shape of the base node for the component's own. Also returns draw style and 'density' which enables ghosts to be drawn transparently. 

Channels are never ghosts; for them, the 'density' term specifies their node type which
in turn determines the little piccy (Eye of God, gullwings, egg, crucifix) that is drawn
on it. */

get_drawing_form(Comp, Style, BBox) :-
    find_base(Comp, Base),
    find_type(Base, Type),
    use_style_for(Type, Style),
    (get_bowtie(Comp, BBox), !;
    Style = text, !,
        get_shape(Comp, centre, C),
        append(C, C, BBox);
    Style = submodel, !,
        get_shape(Comp, bounding_box, BBox);
    get_shape(Comp, centre, [Xpt, Ypt]),
	get_box_size(Comp, Style, Cur_size),
	make_bounding_box(Style, Xpt, Ypt, Cur_size, BBox);
    border_node(Comp), !,
	Submodel has_part Comp,
	get_shape(Comp, along, Theta),
	around_border(Submodel, in, Theta, C),
	append(C, C, BBox)).

around_border(Sm, Context, Theta, C) :-
	Angular is 6.28319*Theta/1000,
	(Context = in,
	    get_shape(Sm, internal_extent, SBox);
	  Context = out,
	    get_shape(Sm, bounding_box, SBox)),
	middle(SBox, [MX, MY]),
	RX is MX + cos(Angular),
	RY is MY + sin(Angular),
	crossing_point(Sm, [MX, MY], [RX, RY], submodel, SBox, 0, C).

/* draws_at/3: returns if a component or link can be drawn at a certain depth,
i.e., if it has a deep enough display depth and so do others on which it
depends, e.g., compartments for flows.  */

draws_at(Wid, Type, Depth) :-
    member(Type, [caption, text]), !,
        get_display_depth(Wid, Type, Detail),
        Detail > Depth;
    depth_list_is(List),
        draws_at(Wid, Type, List, Depth).

draws_at(Wid, Type, [[LevelName | LevelObjects] | List], Depth) :-
    get_display_depth(Wid, LevelName, Detail),
    Detail > Depth,
    (Type = LevelName; member(Type, LevelObjects);
        draws_at(Wid, Type, List, Depth)).

right_section(_Link, showAll).
right_section(Link, showTerminal) :-
    Link is_connector from A to B,
    (initiates(Link, A); terminates(Link, B)), !.
right_section(Link, showLocal) :-
    Link is_connector from A to B,
    connects(Link, A, B).

interferes([L1, T1, R1, B1], [L2, T2, R2, B2]) :-
    L1 < R2,
    L2 < R1,
    T1 < B2,
    T2 < B1.

near([X, Y], Zone) :-
    line_dir_change_radius_is(R1),
    Lz is X - R1,
    Tz is Y - R1,
    Rz is X + R1,
    Bz is Y + R1,
    interferes([Lz, Tz, Rz, Bz], Zone).

/* multiple_draw generates a value which fine tunes drawing of a submodel.
1 = normal submodel, 2-4 = multiple instances,
so draw that many layers in a stack, 0 = generated submodel, so draw ellipses (...)
trailing away from each corner.
-1 is population submodel; these don't even have an important order, so draw a sort
of random pile. */

multiple_draw(VComp, Num) :-
    find_base(VComp, Comp),
    (from_value(Comp), !,
        Num = -3;
    by_record(Comp), !,
        Num = -2;
    is_population(Comp), !,
        Num = -1;
    is_conditional(Comp), !,
        Num = 0;
    (catch(get_node_size(Comp, [Val | _]), Winge, mention(Comp, Winge, Val));
    (implicit_function(Comp, CompFn); CompFn=Comp),
        CompFn has_class_refinement units of array(_, Val)),
        enum_type_ref(Val, Comp, RealVal, _, _), !,
        Num is min(RealVal, 4);
    Num = 1).

mention(Comp, Winge, Val) :-
	caption_for(Comp, Capt),
	(member(Winge, [absent_submodel(Foo), submodel_name_recurs(Foo)]),
	    Comp has_class_refinement multiplication_spec of Specs,
	    select(count=Dims, Specs, MoreSpecs),
	    select(LostRef, Dims, GoodDims),
	    LostRef =.. [size, Foo | _Level],
	    Comp has_changed_class_refinement multiplication_spec of
	        [count=GoodDims | MoreSpecs],
	    query(failed_ref_in_dimensions(Capt, Foo), warning, top, [ok], _),
	    multiple_draw(Comp, Val);
	query(dimensions_invalid(Capt, Winge), warning, top, [ok], _),
	    Val = 4).

get_bowtie_size(Link, Bowtie) :-
    Link is_connector from Comp to _,
    get_box_size(Comp, flow, Box),
    Bowtie is Box/2.

adjust_bowtie(Comp, Point) :-
    find_type(Comp, Type),
    Type is_class_of_sort has_bowtie,
    get_link_route(Comp, Point_list),
    closest_centre(Point, Point_list, Miss, _ClosePt, Posn),
    line_dir_change_radius_is(Dither),
    Miss < Dither,
    implicit_function(Comp, Fn),
    get_shape(Fn, along, _OldPosn),
%    abs(Posn-OldPosn)<100, save accidentally moving it by clicking on route
    change_shape(Fn, along, Posn).

adjust_kink(Comp, [X, Y]) :-
    find_type(Comp, Type),
    Type is_class_of_sort has_bowtie,
    get_end_pt(Comp, start, _, [X0, Y0], _),
    get_end_pt(Comp, finish, _, [Xn, Yn], _),
    (abs(Xn-X0)>abs(Yn-Y0), !,
	Kink is 1000*(X-X0)/(Xn-X0);
	Kink is 1000*(Y-Y0)/(Yn-Y0)),
    get_shape(Comp, curve, [_OldKink, Posn]),
%    abs(Posn-OldPosn)<100, save accidentally moving it by clicking on route
    change_shape(Comp, curve, [Kink, Posn]).

adjust_spline(Comp, [XOff, YOff]) :-
    find_type(Comp, Type),
    Type is_class_of_sort curved,
    get_shape(Comp, curve, [OldMX, OldMY]),
    NewMX is OldMX + 2*XOff,
    NewMY is OldMY + 2*YOff,
    change_shape(Comp, curve, [NewMX, NewMY]).

get_caption_anchor(Path, MidPt) :-
    Path = [[FX,FY], [MX,MY], [SX,SY] | _],
    TX is SX/4 + FX/4 + MX/2,
    TY is SY/4 + FY/4 + MY/2,
    MidPt = [TX, TY, TX, TY].

/*
closest_centre([X, Y], [[X1, Y1], [X2, Y2] | Rest], Start, End, Distance) :-
    (X1 = X2, Y > min(Y1, Y2), Y < max(Y1, Y2), 
        Dummy is 2*Y - Y2, Poss_start = [X1, Dummy], 
        Try is abs(X - X1);
    Y1 = Y2, X > min(X1, X2), X < max(X1, X2), 
        Dummy is 2*X - X2, Poss_start = [Dummy, Y1], 
        Try is abs(Y - Y1)), !,
        (closest_centre([X, Y], [[X2, Y2] | Rest], Start, End, Distance),
            Distance < Try, !;
        Start = Poss_start, End = [X2, Y2], Distance = Try);
    closest_centre([X, Y], [[X2, Y2] | Rest], Start, End, Distance).
*/
closest_centre(Pt, Line, Dist, ClosestPt, Orient) :-
    setof(Approach, any_distance(Pt, Line, Approach), Approaches),
    member(approach(Dist, ClosestPt, Orient), Approaches),
    \+ (member(approach(Closer, _,_), Approaches), Closer < Dist).

any_distance([X, Y], Line, approach(D, [XC, YC], P)) :-
    append(_, [[FX, FY], [SX, SY] | Tail], Line),
    XL is FX-SX,
    YL is FY-SY,
    H is sqrt(XL*XL + YL*YL),
    H > 0, % null segments cause trouble, leave them out
    Off is ((X-SX)*YL-(Y-SY)*XL)/H,
    XC is (X-(Off*YL/H)),
    YC is (Y+(Off*XL/H)),
    D is abs(Off),
    (YL*YL>=XL*XL,
	Fract is (YC-SY)/(FY-SY);
    YL*YL<XL*XL,
	Fract is (XC-SX)/(FX-SX)),
    1>Fract, Fract>=0,
    length(Line, PtCount),
    length(Tail, EarlySegs),
    P is 1000*(EarlySegs + Fract)/(PtCount - 1).

find_new_box(Obj, Xoffset, Yoffset, [L, T, R, B], 
            [L1, T1, R1, B1]) :-
    get_drawing_form(Obj, _, [L, T, R, B]),
    L1 is L + Xoffset,
    T1 is T + Yoffset,
    R1 is R + Xoffset,
    B1 is B + Yoffset.

/* Very simple except for text of a submodel, in which case we make the base
the nearest corner, side or middle to the new text position. This complex bit
has now been moved to when we actually move the border. */

update_text_position(Obj, XTOff, YTOff) :-
    (get_shape(Obj, caption_offset, [XT, YT]);
        get_shape(Obj, caption_offset, [XT, YT, _Anchor])), !,
    NXT is XT + XTOff,
    NYT is YT + YTOff,
    change_shape(Obj, caption_offset, [NXT, NYT]).

map([L,T,R,B], Anchor, Row, Col, X, Y) :-
        HC = (L+R)/2, /* only do math if we need to */
        VC = (T+B)/2,
        nth(Row, [[[nw, L, T], [n, HC, T], [ne, R, T]],
              [[w, L, VC], [c, HC, VC], [e, R, VC]],
              [[sw, L, B], [s, HC, B], [se, R, B]]], Line),
        nth(Col, Line, [Anchor, X, Y]).
    
slice(Posn, LowSide, HiSide, N) :-
    Posn < (3*LowSide+HiSide)/4, !, N=1;
    Posn < (LowSide+3*HiSide)/4, !, N=2;
    N=3.

/* This is having a few hiccups because we may try to draw outer sections before transferring the data for iner ones, so it cannot find their endpoints. So,
* Do inner ones first?
* Transfer all, then draw?
* reuse actual graphics rather than route??? (new bowtie)
*/

get_end_pt(Link, End, Type, Pt, Box) :-
	Link is_connector from Start to Fin,	
	(End = start,
	    get_host(Start, Node),
	    Check = (Link follows Other),
	    PrevPt = PrevEnd;
	 End = finish,
	    get_host(Fin, Node),
	    Check = (Other follows Link),
	    PrevPt = PrevStart),
	(call(Check),
	    find_type(Node, submodel), !,
	    Other is_connector from PrevStart to PrevEnd,
	    get_shape(PrevPt, along, Theta),
	    around_border(Node, out, Theta, Pt),
	    append(Pt, Pt, Box);
	get_drawing_form(Node, DrawType, Box),
	    (Node has_type squirt, !,
		Type = variable;
	      Type = DrawType),
	    middle(Box, Pt)).

warp_factor_for(Link, WarpFactor) :-
	Link is_connector from A to B,
	setof(GenLink, GenLink is_connector from A to B, Links),
	nth(Seq, Links, Link),
	WarpFactor is 1-2*float_fractional_part(Seq/2.6).

get_link_route(Link, Route) :-
	get_end_pt(Link, start, SType, [SX, SY], SBox),
	get_end_pt(Link, finish, FType, [FX, FY], FBox),
	find_all_comps(Parent, Link),
	warp_factor_for(Link, WarpFactor), % clockwise round start

	(Link is_of_sort curved, !,
	    get_shape(Link, curve, [CX, CY]),
	    MX is CX + (SX+FX)/2,
	    MY is CY + (SY+FY)/2,
	    crossing_point(Parent, [SX, SY], [MX, MY], SType, SBox,
			   WarpFactor/4, P0),
	    crossing_point(Parent, [FX, FY], [MX, MY], FType, FBox,
			   -WarpFactor/4, Pn),
	    Route = [Pn, [MX, MY], P0];
	SBox = [SL, ST, SR, SB],
	    FBox = [FL, FT, FR, FB],
	    (draw'><'tk_get_pref(flowRouting, 0),
		RWarp = WarpFactor,
		SPt = [SX, SY],
		FPt = [FX, FY];
	    VWarp is WarpFactor*sign(FX-SX),
		RWarp = 0,
		parallel(ST, SB, FT, FB, VWarp, PY),
		SPt = [SX, PY],
		FPt = [FX, PY];
	    HWarp is WarpFactor*sign(SY-FY),
		RWarp = 0,
		parallel(SL, SR, FL, FR, HWarp, PX),
		SPt = [PX, SY],
		FPt = [PX, FY]), !,
	    crossing_point(Parent, SPt, FPt, SType, SBox, RWarp, P0),
	    crossing_point(Parent, FPt, SPt, FType, FBox, -RWarp, Pn),
	    Route = [Pn, P0];
	% kinked flow route    
	crossing_point(Parent, [SX, SY], [FX, FY], SType, SBox,
		       WarpFactor, [X0, Y0]),
	crossing_point(Parent, [FX, FY], [SX, SY], FType, FBox,
		       -WarpFactor, [Xn, Yn]),
	    get_shape(Link, curve, [Kink, _Bowtie]),
	    (abs(Yn-Y0)>abs(Xn-X0), !, % kink is horizontal
		Yk is Y0+Kink*(Yn-Y0)/1000,
		Route = [[Xn, Yn], [Xn, Yk], [X0, Yk], [X0, Y0]];
	    Xk is X0+Kink*(Xn-X0)/1000,
	    		Route = [[Xn, Yn], [Xk, Yn], [Xk, Y0], [X0, Y0]])).

parallel(S1, F1, S2, F2, Warp, M) :-
	(Warp > 0, !,
	    NS1 is S1+Warp*(F1-S1),
	    NS2 is S2+Warp*(F2-S2);
	 NS1 = S1, NS2 = S2),
	(Warp < 0, !,
	    NF1 is F1+Warp*(F1-S1),
	    NF2 is F2+Warp*(F2-S2);
	 NF1 = F1, NF2 = F2),
	
	NS1<NF2, NS2<NF1,
	M is (max(NS1, NS2)+min(NF1, NF2))/2.

update_bowtie(_Link, _Route).

get_bowtie(Link, Bowtie) :-
    find_type(Link, LType),
    LType is_class_of_sort has_bowtie,
    get_link_route(Link, Route),
    get_bowtie_size(Link, Bowtie_size),
    Link has_part Tap,
    get_shape(Tap, along, TiePosn),
    get_middle_segment(LType, Route, Bowtie_size, TiePosn, Bowtie).

get_hierarchy(Link, End, [Pt | Rest], Recurse) :-
    Link is_connector from TopStart to TopEnd,
    member([TopNode, End, Equiv], [[TopStart, start, FarLink-Link],

				   [TopEnd, finish, Link-FarLink]]),
    get_host(TopNode, Top),
    (Top has_class submodel,
        (Recurse = no, !,
        end_coords(Link, End, Pt),
        Rest = [];
        Pt = Top,
        Top has_link_equivalences Links,
        member(Equiv, Links),
        (select(End, [start, finish], [Other]),
            end_coords(FarLink, Other, FarPt),
            [FarPt] = Rest;
        get_hierarchy(FarLink, End, Rest, Recurse)));
    Pt = Top,
        Rest = []).

end_coords(Link, Where, Pt) :-
	Link is_connector from Start to Finish,
	member(Where-Which, [start-Start, finish-Finish]),
	get_middle(Which, Pt).

get_middle(Node, Pt) :-
	get_shape(Node, centre, Pt);
	(get_shape(Node, bounding_box, BB);
	    get_bowtie(Node, BB)),
	middle(BB, Pt).

/* was:
    get_shape(Link, course, Course),
    (Where = finish, Course = [[Xpt, Ypt] | _];
    Where = start, suffix([[Xpt, Ypt]], Course)).
*/

/* make_header: generates the text to put in a window's title bar */

make_header(Model, Header) :-
    quick_file(Model, FileNameChars),
/* Do not put whole path up this makes confusing taskbar icons
    abs_path_for(Model, Path), */
    caption_for(Model, Title),
/*  (Model has_class_refinement separate of 1, !,
        Togetherness = separate;
    Togetherness = integral),
    dim_spec_for(Model, DimSpec),
    time_step_for(Model, default, Step),
*/
    expand_message(model, SimMod),
    sicstus_format_to_chars("~w (~s: ~s)", [Title, SimMod, FileNameChars],
            HeaderChars),
    name(Header, HeaderChars).

quick_file(Model, FileNameChars) :-
    get_model_file(Model, Name), !,
        name(Name, NameChars),
        split_path_chars(NameChars, _, _, FileNameChars);
    expand_message(unsaved, FileNameChars).
    
/* complete/1: determines draw style of item.
· Compartments and functions are complete if they have values set
· As a special case a function can also be complete if it is linked only to a flow which also has a link from another function which has a value
· Variables are complete if they have an incoming arc
· Sources and sinks are always complete, clouds never are
· Flows are complete if they have an incoming arc at some point along their length
· Influences are complete if their ultimate sources are
· Submodels are complete if they have an internal flow or influence corresponding to every external one.
*/
test_complete(Item) :-
    Item has_class function,
        (checks_out_locally(Item) /* , !;
        setof(OutLink,
              Far^(OutLink is_connector from Item to Far), [OutInf]),
            terminates(OutInf, Flow),
            (sequence(Control, Flow);
            sequence(Flow,Control)),
            InInf is_connector from _ to Control,
            initiates(InInf, Surrogate),
            checks_out_locally(Surrogate) */ );
    Item is_of_sort has_function,
        (implicit_function(Item, _ItemFn);
        Item has_class_refinement units of Units,
            analyze_array(Units, Base, _Dims),
            member(Base, [boolean, a(_)]);
        Item has_class_refinement min_val of _Min,
            Item has_class_refinement max_val of _Max;
        is_parameter(Item, 2));
    Item has_type flow, /* in addition to the above disjunct */
        (sequence(Control, Item);
            sequence(Item, Control)),
        _ is_connector from _ to Control;
    (Item is_of_sort cloud; Item is_of_sort channel;
        find_type(Item, text));
    Item has_class submodel,
        (Item has_link_equivalences Links, !; 
        Links = []),
        \+ (OutLink is_connector from Item to _,
                \+ OutLink has_type relation,
                OutLink is_of_sort line,
                \+ member(_-OutLink, Links));
    Item has_type influence,
        initiates(Item, HeadEnd),
        get_host(HeadEnd, VisHeadEnd),
        draws_complete(VisHeadEnd);
    Item has_type relation.

/* the complete attribute caches the completeness status of each
item on the screen. */

complete(Item) :-
    (Item is_of_sort line,
        (Item has_attribute complete of Complete, !, Complete = true;
        test_complete(Item), Item has_new_attribute complete of true, !;
        Item has_new_attribute complete of false, fail);
    (Item has_class_refinement complete of Complete, !, Complete = true;
        test_complete(Item), Item has_new_class_refinement complete of true, !;
        Item has_new_class_refinement complete of false, fail)).

/* For something to draw as complete, both itself and any guest nodes must be complete. Or it might be an input, i.e., a ghost
of a non-visible node. */

draws_complete(Item) :-
    find_base(Item, BaseItem),
    complete(BaseItem), !,
    \+ (implicit_function(BaseItem, Extra), \+ complete(Extra)).

/* check_complete removes the cache attribute forcing another test
next time its completeness value is required. */

check_complete(Item) :-
    (Component = Item; implicit_function(Item, Component)),
    (Component no_longer_has_class_refinement complete of _;
    Component no_longer_has_attribute complete of _),
    fail; true.

/* Test for existence of all variables referred to in an expression. Also checks
that their dimensionalities match, but not the dimensions themselves because this
would require the function to be parsed, which takes too long. 

Fails if either there is a link without a corresponding variable, or vice versa. */

checks_out_locally(Func) :-
    Func has_class_refinement value of Expr,
    \+ Expr = '', /* sometimes given to flow to get bowtie on right
              section 
    instance'><'apply_minmax(Func, Expr, FullExpr), */
    Func has_class_refinement units of Units,
    analyze_array(Units, Base, Dims),
    units_match_context(Func, Base, Dims, []),
    get_host(Func, Vis),
    (find_type(Vis, state), !,
	% value is [evt1-val1, evt2-val2...] so use val parts only
	% utility'><'all(image, sieve_events,
	% 	       [build(Expr), unify(Func), build(HasConts)]);
	% New value format: val1 on event1, val2 on evt2, etc
	list_evt_captions(Func, EvtCapts),
	sieve_all_events(Expr, Func, EvtCapts, HasConts);
      HasConts = Expr),
    replace_subexps(HasConts, image, pick_var, Func, top_down, Pairs, _),
    (setof(Source, valid_input(Func, continuous, Source), Sources), !;
	Sources = []),
    
    pair_off(Func, Sources, Pairs).

pick_var(_, V, _, 0) :-
    get_solo_list_depth(V, _).

sieve_all_events(Pairs, Fn, EvtCapts, Compound) :-
	Pairs = (Outcome on Evt, More),
	    select(Evt, EvtCapts, Left), 
	    sieve_all_events(More, Fn, Left, Tail),
	    Compound = (Outcome,Tail);
	  Pairs = (Compound on Evt), EvtCapts = [Evt].

/* pair_off is true if every variable in the expression represents a role of some link to the function, and every link to the function has at least one variable representing some role it has. Later we may keep the unit error and pop it up when the user mouses over to see why the node is red... */

pair_off(_, [], []).

pair_off(Function, [Source | Sources], Pairs) :-
    setof(var_pair(Var, _),
        represents(Function, Source, Pairs, Var),
        CurrentVars),
    purge(Pairs, CurrentVars, PairsLeft),
    pair_off(Function, Sources, PairsLeft).

represents(Function, Source, Pairs, Var) :-
    Source has_attribute role of UseList,
    member(use(_,_, Ref, SoughtUnit), UseList),
    (Ref = Var; Ref = usr(Var)),
    member(var_pair(Var, _), Pairs),
    get_link_source_data(Source, Function, _, FoundUnit, _,_,_),
    check_unit(FoundUnit, SoughtUnit, 2, []).
    
line_dir_change_radius_is(8).

/* Inwardly flowing...*/
route_interior_part_link(Type, Dir, Start, [X, Y], Route) :-
    get_shape(Start, internal_extent, [L, T, R, B]),
    GL is X - L,
    GT is Y - T,
    GR is R - X,
    GB is B - Y,
    Clearance is min(min(GL, GR), min(GT, GB)),
    (Clearance = GL, !, Border = [L, Y];
    Clearance = GT, !, Border = [X, T];
    Clearance = GR, !, Border = [R, Y];
    Clearance = GB, Border = [X, B]),

    (Dir = in, Begin = Border, End = [X, Y];
    Dir = out, End = Border, Begin = [X, Y]),

    (Type = flow, !,
        Route = [End, Begin];
    /* Otherwise */
        curve_route(Type, Begin, End, Midpoint),
        Route = [End, Midpoint, Begin]).
    
/* Extra clause to cope with inputs/outputs in grouped submodels which don't have 
graphical attributes; returns them as points on the component boundary where the 
lines enter/leave. This is a bit stopgap-ish, but made prettier it could win a 
few hearts.

Also links between submodels must now be affected by the children they connect,
so this takes a hierarchical list (which may end in, or even be, a point) and
gets points from within it. */

get_termination_zone([Obj | Rest], Dir, Top, Area, CompType, Centre) :-

/* comment out following to restore old system */
    Obj = [X, Y], !,
        Area = [X, Y, X, Y],
        CompType = point,
        Centre = [X, Y];
    get_host(Obj, VisObj),
    get_drawing_form(VisObj, DrawType, Area),
    find_all_comps(Top, Obj),

    (VisObj has_type squirt, !,
        CompType = variable;
    CompType = DrawType),
    (CompType = submodel,
    \+ Rest = [], !,
        get_termination_zone(Rest, Dir, _, _, _, InnerCentre),
        add_to_translation([0, 0, 1, 1], Obj, InnerTrans),
        untranslate(InnerCentre, InnerTrans, PrevCentre),
            constrain_inside(PrevCentre, Area, Centre);
    middle(Area, Centre)), ! /* ;
end of bit that implements new system
    (Dir = in, Link is_connector from Obj to _;
    Dir = out, Link is_connector from _ to Obj),
        find_all_comps(Parent, Obj),
        has_outer_equiv(Link, Parent, Big_link),
        (Dir = in, Big_link is_connector from _ to Parent,
            get_shape(Big_link, course, [InnerCentre | _]);
        Dir = out, Big_link is_connector from Parent to _,
            get_shape(Big_link, course, Route),
            last(Route, InnerCentre)),
        add_to_translation([0, 0, 1, 1], Parent, End_trans),
        blobify(InnerCentre, InnerArea),
        translate(InnerArea, End_trans, Area),
        translate(InnerCentre, End_trans, Centre),
        Link has_type CompType */ .

constrain_inside([X1, Y1], [L, T, R, B], [X2, Y2]) :-
    X2 is min(max(X1, L), R),
    Y2 is min(max(Y1, T), B).

    
blobify([X, Y], [L, T, R, B]) :-
    BlobRad = 0, /* This will ultimately have to be zoom-dependent */
    L is X-BlobRad,
    T is Y-BlobRad,
    R is X+BlobRad,
    B is Y+BlobRad.

/* Easy one for straight part routes */
route_part_link(Type, Dir, Start, [X, Y], Route) :-
    Type is_class_of_sort has_bowtie,
    get_termination_zone(Start, Dir, Parent, [L, T, R, B], NodeType, _),
    (L < X, X < R,
        Y1 is (T + B)/2,
        crossing_point(Parent, [X, Y1], [X, Y], NodeType, [L, T, R, B],
                   0, [_X, Y2]),
        X2 = X;
    T < Y, Y < B,
        X1 is (L + R)/2,
        crossing_point(Parent, [X1, Y], [X, Y], NodeType, [L, T, R, B],
                   0, [X2, _Y]),
        Y2 = Y),
    (Dir = out, !,
        Route = [[X, Y], [X2, Y2]];
    /* dir = in */
        Route = [[X2, Y2], [X, Y]]), !.

/* general one */
route_part_link(Type, Dir, Start, Point, Route) :-
    get_termination_zone(Start, Dir, Parent, Box, NodeType, Centre),
    crossing_point(Parent, Centre, Point, NodeType, Box, 0, Exit),
    (Dir = out, !,
        Exit = Begin, Point = End;
    /* in */ Point = Begin, Exit = End),
    shape_route(Type, Begin, End, Route).

/* route_parent_child_link/5...this is used on those occasions when
the route of a link between a parent boundary and a child is
determined without reference to a link outside the parent, i.e., when
a hierarchical link is being drawn, or when there is no corresponding
external link. */

route_parent_child_link(Type, Direction, Parent, Child, Route) :-
    get_shape(Parent, internal_extent, [L2, T2, R2, B2]),
    get_termination_zone(Child, Direction, _, [L1, T1, R1, B1], 
            NodeType, [Xint, Yint]),
    GL is L1 - L2,
    GT is T1 - T2,
    GR is R2 - R1,
    GB is B2 - B1,
    (min(GL, GR) < min(GT, GB), !,
            Yext = Yint,
        (GL < GR, !, Xext = L2; Xext = R2),
        crossing_point(Parent, [Xint, Yext], [Xext, Yext], 
                NodeType, [L1, T1, R1, B1], 0, InPt),
        crossing_point(Parent, [Xint, Yext], [Xext, Yext], 
                submodel, [L2, T2, R2, B2], 0, OutPt);
    /* otherwise */
        Xext = Xint,
        (GT < GB, !, Yext = T2; Yext = B2),
        crossing_point(Parent, [Xext, Yint], [Xext, Yext], 
                NodeType, [L1, T1, R1, B1], 0, InPt),
        crossing_point(Parent, [Xext, Yint], [Xext, Yext], 
                submodel, [L2, T2, R2, B2], 0, OutPt)),
    (Direction = in, !,
        Start = OutPt, Finish = InPt;
    /* it's out */
        Start = InPt, Finish = OutPt),
    (Type = flow, !, 
        Route = [Finish, Start];
    /* it's influence */
        curve_route(Type, Start, Finish, Midpoint),
        Route = [Finish, Midpoint, Start]).

/* Easy one for straight whole routes; this and its partial equivalent might need 
to take some note of the centres...OK then */

route_link(Parent, Type, Start, Finish, [End, Beginning]) :-
    Type is_class_of_sort has_bowtie,
    get_termination_zone(Start, in, Parent,
			 [L1, T1, R1, B1], NodeType1, [CX1, CY1]),
    get_termination_zone(Finish, out, Parent,
			 [L2, T2, R2, B2], NodeType2, [CX2, CY2]),
        ((CX1 >= L2, CX1 =< R2, X = CX1;
            CX2 >= L1, CX2 =< R1, X = CX2),
        Y2 is (T2 + B2)/2,
        Y1 is (T1 + B1)/2,
        crossing_point(Parent, [X, Y1], [X, Y2], 0, NodeType1, 
                [L1, T1, R1, B1], Beginning),
        crossing_point(Parent, [X, Y2], Beginning, 0, NodeType2, 
                [L2, T2, R2, B2], End);
    (CY1 >= T2, CY1 =< B2, Y = CY1;
            CY2 >= T1, CY2 =< B1, Y = CY2),
        X2 is (L2 + R2)/2,
        X1 is (L1 + R1)/2,
        crossing_point(Parent, [X1, Y], [X2, Y], 0, NodeType1, 
                [L1, T1, R1, B1], Beginning),
        crossing_point(Parent, [X2, Y], Beginning, 0, NodeType2, 
                [L2, T2, R2, B2], End)), !.

/* Slight mod to the one below to start flows in the centre of the appropriate
side of the compartment etc and thus differentiate routes in opposite
directions */

route_link(Type, Start, Finish, Route) :-
    member(Type, [flow, squirt]),
    get_termination_zone(Start, in, Parent, [SL, ST, SR, SB], _, [SX, SY]),
    get_termination_zone(Finish, out, Parent, FBox, NodeType2, [FX, FY]),
    (FX-SX>FY-SY, !, /* flow goes top right */
        (SX-FX>FY-SY, !, /* up */
            BX = SX, BY = ST;
        BX = SR, BY = SY);
        (SX-FX>FY-SY, !, /* left */
            BX = SL, BY = SY;
        BX = SX, BY = SB)),
    crossing_point(Parent, [FX, FY], [BX, BY], NodeType2, FBox, 0, End),
    shape_route(Type, [BX, BY], End, Route), !.

/* General one for other whole routes between graphically displayed objects */

route_link(Type, Start, Finish, Route) :-
    get_termination_zone(Start, in, Parent, SBox, NodeType1, Centre1),
    get_termination_zone(Finish, out, Parent, FBox, NodeType2, Centre2),
    crossing_point(Parent, Centre1, Centre2, NodeType1, SBox, 0, Beginning),
    crossing_point(Parent, Centre2, Centre1, NodeType2, FBox, 0, End),
    shape_route(Type, Beginning, End, Route), !.

/* This clause will be resorted to if I cannot get the coordinates for one end of
the link by any degree of subterfuge. */

route_link(Type, Start, Finish, Route) :-
    (Start = NoGraph, Finish = Graph, Direction = in;
    Finish = NoGraph, Start = Graph, Direction = out),
    \+ get_termination_zone(NoGraph, Direction, _, _, _, _),

    NoGraph = [Mystery | _],
    find_all_comps(Parent, Mystery),
    route_parent_child_link(Type, Direction, Parent, Graph, Route).

shape_route(Type, Beginning, End, Route) :-
    member(Type, [flow, squirt]), !,
        (draw'><'tk_get_pref(flowRouting, 1), !,
        kink_route(Beginning, End, Route);
        Route = [End, Beginning]);
    /* influence */
    curve_route(Type, Beginning, End, Midpoint),
        Route = [End, Midpoint, Beginning].

/* kink_route: this creates a route between two points comprising a sequence of
rectilinear sections. Currently it makes three, dividing the longer dimension in
two to produve a middle segment, though it need not do this. Note slight offset of
middle segment to separate bowties. */

kink_route([X1, Y1], [X2, Y2], [[X2, Y2], [KX2, KY2], [KX1, KY1], [X1, Y1]]) :-
    abs(X2 - X1) > abs(Y2 - Y1), !,
        KX1 is (6*X2 + 4*X1)/10,
        KX2 = KX1,
        KY1 = Y1,
        KY2 = Y2;
    KY1 is (6*Y2 + 4*Y1)/10,
        KY2 is KY1,
        KX1 is X1,
        KX2 is X2.

/* OK here-s a version that simply puts a right angle in it, thus keeping opposing flows separate.

kink_route([X1, Y1], [X2, Y2], [[X2, Y2], [X1, Y2], [X1, Y1]]).

Find centre of overlapping region of two sides; fail if they don't overlap */
centre(Low1, Low2, High1, High2, Middle) :-
    Low is max(Low1, Low2),
    High is min(High1, High2),
    High >= Low,
    Middle is (Low + High)/2.

curve_route(Type, [X1, Y1], [X3, Y3], [X2, Y2]) :-
	(Type = influence,
	    draw'><'tk_get_pref(infRouting, Curvature);
	  Type = relation,
	    draw'><'tk_get_pref(roleRouting, Curvature)),
	UseCurve is min(max(Curvature,-90),90),
	% -ve for counterclockwise curve
	X2 is (2*(X1 + X3) + UseCurve*(Y3 - Y1)/30)/4,
	Y2 is (2*(Y1 + Y3) + UseCurve*(X1 - X3)/30)/4.

get_linear(Acw_pt, Cw_pt, Acw_gap, Front_gap, Cw_gap, Mid_pt) :-
    Mid_pt is (Acw_pt*(Front_gap - Cw_gap) + Cw_pt*(Front_gap - Acw_gap)) / (2*Front_gap - Cw_gap - Acw_gap).

/* this version treats each segment as of equal length re whether it
gets bowtie */

get_middle_segment(Type, List, Size, Posn, Bowtie) :-
    length(List, L),
    Half_length is (L - 1)*Posn//1000,
    Fract is (L - 1)*Posn/1000 - Half_length,
    append(_, [St, Fi | Rest], List),
    length(Rest, Half_length), !,
    tie_middle(Type, St, Fi, Size, Fract, Bowtie).

/* this tries to get length of whole flow. I have gone back to the
 * above because (a) it seems more sane for the bowtie to keep its
 * position relative to its segment than to the whole flow, and (b)
 * when dragging the bowtie, the position it is dragged to is
 * calculated in that form.
   
get_middle_segment(Type, List, Size, Posn, Bowtie) :-
	find_on_flow(List, Posn, 0, _, [X1, Y1, X2, Y2], Fract),
	tie_middle(Type, [X2, Y2], [X1, Y1], Size, Fract, Bowtie).

find_on_flow([_Start], Posn, Total, PosnAlong, _, _) :-
	PosnAlong is (1000-Posn)*Total/1000.

find_on_flow([[X1, Y1], [X2, Y2] | Left], Posn, Passed,
	     PosnAlong, SegWithBowtie, Fract) :-
	SegSize is max(abs(Y2-Y1), abs(X2-X1)),
	NewPassed is Passed+SegSize,
	find_on_flow([[X2, Y2] | Left], Posn, NewPassed,
		     PosnAlong, SegWithBowtie, Fract),
	(NewPassed = Passed, !,
	 FractThisSeg is PosnAlong-Passed;
	 FractThisSeg is (PosnAlong-Passed)/(NewPassed-Passed)),
	(FractThisSeg >= 0, FractThisSeg < 1, !,
	    SegWithBowtie = [X1, Y1, X2, Y2],
	    Fract = FractThisSeg;
	  true).
*/
/* tie_middle puts bowtie on a section of flow, oriented crosswise to the axis along which the flow has greatest extent */

tie_middle(Type, [X2, Y2], [X1, Y1], Len, Fract, [NL, NT, NR, NB]) :-
    XMid is X1+Fract*(X2-X1),
    YMid is Y1+Fract*(Y2-Y1),
    (abs(Y1-Y2) < abs(X1-X2), !,
        make_bounding_box(Type, XMid, YMid, Len, [NL, NT, NR, NB]);
    make_bounding_box(Type, YMid, XMid, Len, [NT, NL, NB, NR])).

check_translation(Submodel) :-
    Wid shows_model TopModel,
    translate_between(TopModel, Submodel, _, Trans),
    make_current(Wid),
    set_translation(Trans).

translate_between(Model, Model, 0, [0,0,1,1]).

translate_between(HiModel, LoModel, Depth, Trans) :-
    \+ get_shape(LoModel, hide_contents, 1),
    find_all_comps(Parent, LoModel),
    translate_between(HiModel, Parent, HiDepth, HiTrans),
    Depth is HiDepth + 1,
    add_to_translation(HiTrans, LoModel, Trans).

translate([], _, []).

translate([X, Y | Rest], [Xoffset, Yoffset, Xscale, Yscale], 
        [NewX, NewY | NewRest]) :-
    /* removed integer(...) round result -- end of universe? */
    gnumber(X), gnumber(Y),
    NewX is (X - Xoffset)*Xscale,
    NewY is (Y - Yoffset)*Yscale, !,
    translate(Rest, [Xoffset, Yoffset, Xscale, Yscale], NewRest).

/* ...and for nested lists... */
translate([Pair | Rest], Trans, [NewPair | NewRest]) :-
    translate(Pair, Trans, NewPair),
    translate(Rest, Trans, NewRest).

/* special version for offsets */
rel_translate([OffX, OffY, Anch], [_,_, Xscale, Yscale], [NewX, NewY, Anch]) :-
    NewX is OffX*Xscale,
    NewY is OffY*Yscale.

untranslate([], _, []).

/* Here's how we do unnested lists... */
untranslate([X, Y | Rest], [Xoffset, Yoffset, Xscale, Yscale], 
        [NewX, NewY | NewRest]) :-
    gnumber(X), gnumber(Y),
    /* removed integer(...) round result -- end of universe? */
    NewX is X/Xscale + Xoffset,
    NewY is Y/Yscale + Yoffset, !,
    untranslate(Rest, [Xoffset, Yoffset, Xscale, Yscale], NewRest).

/* ...and for nested lists... */
untranslate([Pair | Rest], Trans, [NewPair | NewRest]) :-
    untranslate(Pair, Trans, NewPair),
    untranslate(Rest, Trans, NewRest).


/* work around legacy nasties */
gnumber(N) :-
    number(N);
    N = -(M), number(M).

add_to_translation(OldTrans, Comp, NewTrans) :-
    get_shape(Comp, bounding_box, Box1),
    get_shape(Comp, internal_extent, Box2),
    add_boxes_to_translation(OldTrans, Box1, Box2, NewTrans).

add_boxes_to_translation([Xoffset, Yoffset, Xscale, Yscale],
			 [L, T, R, B], [IntL, IntT, IntR, IntB],
			 [NewXoffset, NewYoffset, NewXscale, NewYscale]) :-
    Border = 0,
    NewXscale is Xscale*(IntR - IntL)/(R + 2*Border - L),
    NewYscale = Yscale*(IntB - IntT)/(B + 2*Border - T),
    NewXoffset is Xoffset + ((L + R)/2 - Border)/Xscale 
        - (IntL + IntR)/2/NewXscale,
    NewYoffset is Yoffset + ((T + B)/2 - Border)/Yscale
         - (IntT + IntB)/2/NewYscale.

subtract_from_translation([Xoffset, Yoffset, Xscale, Yscale], Comp,
        [NewXoffset, NewYoffset, NewXscale, NewYscale]) :-
    Border = 0,
    get_shape(Comp, bounding_box, [L, T, R, B]),
    get_shape(Comp, internal_extent, [IntL, IntT, IntR, IntB]),
    NewXscale is min(Xscale*(R + 2*Border - L)/(IntR - IntL),
        Yscale*(B + 2*Border - T)/(IntB - IntT)),
    NewYscale = NewXscale,
    NewXoffset is Xoffset + (IntL + IntR)/2/Xscale 
        - ((L + R)/2 - Border)/NewXscale,
    NewYoffset is Yoffset + (IntT + IntB)/2/Yscale 
        - ((T + B)/2 - Border)/NewYscale.
