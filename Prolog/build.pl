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

sicstus_module(build, [source/5,roots/4,properties/4,
	node/8,node/9,arc/9,ghosts/5] ).

sicstus_use_module( [library( lists),m_class,utility] ).

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
	RealNode is_also_part_of Root,      % make it so
	!,
	roots( Nodes, Root, Bindings, NewBindings ).
roots( [Node|Nodes], Root, Bindings, NewBindings ) :-
	\+ get_match( Node, Bindings, _AnyNode), % if we haven't made a node,
	gen_equiv_nodes(Node, Root, Trn),  % make it so, in the right place
	roots( Nodes, Root, [Trn | Bindings], NewBindings ).

/* do not check for duplication for the time being... */
library(Nodes, _, Bindings, NewBindings) :-
	Library is_library,
	roots(Nodes, Library, Bindings, NewBindings).

properties([],_,B,B).

properties([A-V | Rest], Root, B, B) :-
	(A=name, !; /* do not set submodel name from saved model */
	Root has_changed_class_refinement A of V, !;
	Root has_new_class_refinement A of V),
	properties(Rest, Root, B, B).

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
	(Bindings = copy, !,
	    foreach(Child, Children, Child is_also_part_of Node),
	    NewBindings = copy;
	all(build, gen_equiv_nodes,
	        [build(Children), unify(RealNode), build(MidBindings)]),
	    append( MidBindings, Bindings, NewBindings )),
/*	( setof( Child-RealChild, 
			( member( Child, Children ),
		 	  RealChild is_new_part_of RealNode ),
			MidBindings );
	  MidBindings = [] ),
*/	foreach( CAttribute=CValue, ClassRefinements,
		RealNode has_new_class_refinement CAttribute of CValue ),
/* no model refinements restored */
	foreach( GAttribute=GValue, GraphicalInfo,    
		RealNode has_new_graphical_attribute GAttribute of GValue ).
	
gen_equiv_nodes(Node, Parent, Node-NewN) :-
	Node is_part_of _, !,
	    NewN is_new_part_of Parent;
	NewN = Node,
	    NewN is_also_part_of Parent.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arc inserts a new arc and any info known about it. 

arc( Arc, Start, End, Type, AttributeValuePairs,
		GraphicalInfo, _, Bindings, NewBindings ) :-
	(Bindings = copy, NewBindings = copy, Arc=RealArc,
	    RealArc is_also_connector from Start to End;
	\+ member( Arc-_AnyArc, Bindings ),
	    member( Start-RealStart, Bindings ),
	    member( End-RealEnd, Bindings ),
	    NewBindings = [Arc-RealArc|Bindings],
	    (is_connector(Arc, _), !,
		RealArc is_new_connector from RealStart to RealEnd;
	    RealArc = Arc,
	        RealArc is_also_connector from RealStart to RealEnd)),
	foreach( Attribute=Value, AttributeValuePairs,
			RealArc has_new_attribute Attribute of Value ),
	foreach( GAttribute=GValue, GraphicalInfo,
		RealArc has_new_graphical_attribute GAttribute of GValue ),
	RealArc has_new_type Type.

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
	NewNode has_new_model_refinement link_equivalences of NewLinks, !;
	retractall(missing(_)),
	member(MissingIn-MissingOut, Links),
	member(Missing, [MissingIn, MissingOut]),
	\+ member(Missing-_, Bindings),
	assert(missing(Missing)),
	fail.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
instance(Node, Module, _, Bindings, Bindings ) :-
	get_match(Node, Bindings, NewNode),
	get_match(Module, Bindings, NewModule),
	NewNode has_new_model_refinement instance of NewModule.

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

get_match(Component, copy, Component).

get_match(Component, Bindings, Match) :-
	member(Component-Match, Bindings).
