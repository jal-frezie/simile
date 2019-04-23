/*******************************************************************************
**** CONSTRUCTION MODULE FOR AME - predicates to build the various parts    ****
**** of the representation ADT.                                             ****
*******************************************************************************/

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IMPORTANT NOTE!!! Each of the predicates exported here has two extra final   %
% arguments, which are used for internal book-keeping. These arguments must be %
% added to the calls saved in an ame file - it's done this way to make hand    %
% editing of ame files more user friendly.                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sicstus_module(build, [roots/4, properties/4,
	node/8, node/9, arc/9, ghosts/5, ancestor_has_enum_type/2] ).

sicstus_use_module( [library( lists), sp_only, m_class, utility] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% roots builds new nodes, attaches them to the desktop root and adds
% them to the bindings

roots( [], _, Bindings, Bindings ).
roots( [Node|Nodes], Root, Bindings, NewBindings ) :-
	get_match( Node, Bindings, RealNode), % if we've already made a node, 
					   % and it's already connected to root
	RealNode is_part_of Root,	   % ignore it
	!,
	roots( Nodes, Root, Bindings, NewBindings ).
roots( [Node|Nodes], Root, Bindings, NewBindings ) :-
	get_match( Node, Bindings, RealNode), % if we've already made a node,
					   % and it's not connected to root
	\+ RealNode is_part_of Root,
	RealNode is_new_part_of Root,      % make it so
	!,
	roots( Nodes, Root, Bindings, NewBindings ).
roots( [Node|Nodes], Root, Bindings, NewBindings ) :-
	\+ get_match( Node, Bindings, _AnyNode), % if we haven't made a node,
	gen_equiv_nodes(Node, Root, Trn),  % make it so, in the right place
	roots( Nodes, Root, [Trn | Bindings], NewBindings ).

properties([],_,B,B).

properties([A-V | Rest], Root, B, B) :-
	(A=name, !; /* do not set submodel name from saved model */
	A = enum_types, !,
	    merge_enum_types(V, Root);
	Root has_changed_class_refinement A of V, !;
	Root has_new_class_refinement A of V),
	properties(Rest, Root, B, B).

merge_enum_types(Types, Parent) :-
	Types = [];
	Types = [Class-Mems | Rest],
	(ancestor_has_enum_type(Parent, Class-OldMems),
	    (Mems = OldMems;
	     ame_gen><query(lose_enum_type(Class, Mems, OldMems), warning,
			   enumtype, [ok], _)), !;
	 Parent has_class_refinement enum_types of OldTypes,
	     Parent has_changed_class_refinement enum_types of
	         [Class-Mems | OldTypes];
	    Parent has_new_class_refinement enum_types of [Class-Mems]),
	merge_enum_types(Rest, Parent).

ancestor_has_enum_type(Model, Class-Mems) :-
	Model has_class_refinement enum_types of Types,
	(member(Class-Mems, Types);
	 Parent has_part Model,
	 ancestor_has_enum_type(Parent, Class-Mems),
	 \+ member(Class-_InnerMems, Types)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% add_node inserts new information about a node, and updates bindings
% accordingly. If any of the info is already there, the operation will fail.
% 1998: model refinements are no longer used

node(N, Cl, Ch, C, _, G, _, B, NB) :-
	node(N, Cl, Ch, C, G, _, B, NB).

node(  Node, OldClass, Children, ClassRefinements, GraphicalInfo,
				_, Bindings, NewBindings ) :-
	get_match(Node, Bindings, RealNode),
	RealNode is_part_of _,	% the node must be already known
	
	(member(OldClass, [source, sink]), !, Class = cloud;
	    Class = OldClass),                  % Remove obsolete types
	RealNode has_new_class Class,		% add the info
	add_children(Bindings, RealNode, Children, NewBindings),
/*	( setof( Child-RealChild, 
			( member( Child, Children ),
		 	  RealChild is_new_part_of RealNode ),
			MidBindings );
	  MidBindings = [] ),
*/	foreach( CAttribute=CValue, ClassRefinements,
		RealNode has_new_class_refinement CAttribute of CValue ),
/* no model refinements restored */
/* try putting this in the adjust_to cascade...
   (Class = border,
	    append(B4, [centre=Ctr | Rfter], GraphicalInfo), !, % v5 style
	    Sm has_part RealNode,
	    Sm has_graphical_attribute internal_extent of Box,
	    event><get_posn_around(Ctr, Box, Theta),
	    append(B4, [along=Theta | Rfter], V6Graph);
	  V6Graph = GraphicalInfo), */
	foreach( GAttribute=GValue, GraphicalInfo,    
		RealNode has_new_graphical_attribute GAttribute of GValue ).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arc inserts a new arc and any info known about it. 
% 2011 (v6): arcs can now have children

arc( Arc, Start, End, Type, ExtdAttributeValuePairs,
		GraphicalInfo, _, Bindings, NewBindings ) :-
	(ExtdAttributeValuePairs = [SubsName=Children | AttributeValuePairs],
	    member(SubsName, [attached, children]), !; % was latter in prototype
	  Children = [],
	    AttributeValuePairs = ExtdAttributeValuePairs),
	(Bindings = copy, MidBindings = copy, Arc=RealArc,
	    RealStart = Start, RealEnd = End;
	\+ member( Arc-_AnyArc, Bindings ),
	    member( Start-RealStart, Bindings ),
	    member( End-RealEnd, Bindings ),
	    MidBindings = [Arc-RealArc|Bindings],
	    (is_connector(Arc, _), !;
	    RealArc = Arc)),
	% Convert to v6: arc is from implicit function
	(RealEnd is_connector _, !,
	    RealStart is_part_of Parent,
	    RealStart is_no_longer_part_of Parent,
	    RealStart is_also_part_of RealEnd,
	    NewBindings = Bindings; % no arc added
	  % Convert to v6: arc is influence from flow
	  (RealStart is_connector _, !,
	        RealStart has_part ImpFn,
	        ImpFn has_class function,
	        RealArc is_new_connector from ImpFn to RealEnd;
	      RealArc is_new_connector from RealStart to RealEnd),
	    add_children(MidBindings, RealArc, Children, NewBindings),
	    foreach( Attribute=Value, AttributeValuePairs,
		     RealArc has_new_attribute Attribute of Value ),
	    foreach( GAttribute=GValue, GraphicalInfo,
		     RealArc has_new_graphical_attribute GAttribute of GValue ),
	    RealArc has_new_type Type).

add_children(Bindings, Parent, Children, NewBindings) :-
	Bindings = copy, !,
	    foreach(Child, Children, Child is_new_part_of Parent),
	    NewBindings = copy;
	all(build, gen_equiv_nodes,
	        [build(Children), unify(Parent), build(MoreBindings)]),
	    append( MoreBindings, Bindings, NewBindings ).

/* If a node with the same id as that being added does not already exist, the
new Id is kept, because (a) it makes canvas translation more efficient, and (b)
it makes it not crash, by avoiding circles. */
gen_equiv_nodes(Node, Parent, Node-NewN) :-
    (Node is_part_of _, !; 
	NewN = Node),
    NewN is_new_part_of Parent.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% links takes a node name and a list of link_equivalences and renames them to
% fit the model. Fails if not all the old values are bound (and so gets
% deferred until they are)

:- dynamic(missing/1).

links( Node, Links, _, Bindings, Bindings ) :-
	get_match(Node, Bindings, NewNode),
	length( Links, L ),
	length( NewLinks, L ),
	setof( NewIn-NewOut,
		[OldIn,OldOut]^
		( member( OldIn-OldOut, Links ),
		  get_match( OldIn, Bindings, NewIn ),
		  get_match( OldOut, Bindings, NewOut )),
		NewLinks ),
	\+ (member(In-Out, NewLinks),
	       member(WaitFor, [In, Out]),
	       \+ WaitFor is_connector _),
	NewNode has_new_link_equivalences NewLinks,
	% check all links nodes etc were real -- order not guaranteed same
	NewNode has_link_equivalences _TestLinks, !;
	retractall(missing(_)),
	member(MissingIn-MissingOut, Links),
	member(Missing, [MissingIn, MissingOut]),
	\+ (Bindings = copy,
	       Missing is_connector _;
	    member(Missing-_, Bindings)),
	assert(missing(Missing)),
	fail.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% references takes a node name and a list of references and renames them to
% fit the model. Fails if not all the old values are bound (and so gets
% deferred until they are)

references( Node, Links, _, Bindings, Bindings ) :-
	get_match(Node, Bindings, NewNode),
	update_locals(Links, Bindings, NewLinks),
	NewNode has_new_model_refinement references of NewLinks.

references(Node, Refs, _, Bindings, Bindings) :-
	get_match(Node, Bindings, NewNode),
	translate_all(Refs, Bindings, NewRefs),
	NewNode has_new_attribute references of NewRefs.

update_locals([], _, []).

update_locals([OldRef | Links], Bindings, [NewRef | NewLinks]) :-
	(OldRef = local(OldLink), !,
	NewRef = local(NewLink),
	get_match(OldLink, Bindings, NewLink);
	OldRef = NewRef),
	update_locals(Links, Bindings, NewLinks).

/* Ghosts is kept only for compatibility with pre-version 4 models.
The model refinements added will be translated to the version 4
representation of direct influences by adjust_to_4. */

ghosts(Node, Ghosts, _, Bindings, Bindings) :-
	get_match(Node, Bindings, NewNode),
	translate_all(Ghosts, Bindings, NewGhosts),
	NewNode has_new_model_refinement has_ghosts of NewGhosts,
	foreach(Ghost, NewGhosts, Ghost has_new_model_refinement is_ghost
			of NewNode).

translate_all([], _, []).

translate_all([In | R1], Bindings, [Out | R2]) :-
	get_match(In, Bindings, Out),
	translate_all(R1, Bindings, R2).

get_match(Component, Bindings, Match) :-
	Bindings = copy, !,
	Match = Component;
	member(Component-Match, Bindings).
