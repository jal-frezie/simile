/*******************************************************************************
**** LIBRARY FOR AME - save and load model classes, submodels, etc.         ****
**** All done in terms of an independent node-based representation, which   ****
**** is defined in terms of the model class ADT 			    ****
*******************************************************************************/

sicstus_module( library, [ame_save/3, ame_merge/4, count_functions/2] ).

sicstus_use_module( [library(lists),
	sp_only, ame_gen,m_class,utility,text,build] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ame_save/3 - saves the submodels starting at the nodes listed in arg1 to the file
% named in arg 2
% models are saved in terms of calls to predicates defined in construction:, 
% thus keeping the abstract syntax away from the user.

ame_save( File, Model, Date ) :-
	(Model has_parts Models, !; Models = []),
	(setof(A-V, Model has_class_refinement A of V, Props); Props = []),
	\+ ( member( Node, Models ),
	     \+ Node is_model_class ),
	any_setof( Class,
		   Class is_class,
		   Classes ),
	output:windowize(File, WFile),
	on_exception(_, open(WFile, write, Stream), 
	fail), !,
	(dialogue:reassure_user("Writing root information"),
	user:version_is(VStr),
	name(SimV, VStr),
	V is SimV + 4,
	state:get_edition(Edition),
	write_with_breaks(Stream, source(program='AME', version=V,
					 edition=Edition, date=Date)),
	nl(Stream),
	write_with_breaks( Stream, roots( Models )),
	nl(Stream),
	write_with_breaks( Stream, properties(Props)),
	nl(Stream),
	dialogue:reassure_user("Writing node information"),
	save_nodes( Models, Stream, ArcsUsed ),
	nl(Stream),
	dialogue:reassure_user("Writing class information"),
	save_classes( Classes, Stream ),
	nl(Stream),
	dialogue:reassure_user("Writing arc information"),
	save_arcs( ArcsUsed, Stream ),
	close( Stream ), !;
	fail).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_stream - does the work of ame_save/[12]. Arg [34] are "done" lists for
% Nodes and Arcs respectively - don't do the same node twice.

save_nodes( [], _, [] ).

save_nodes( [Node|Nodes], Stream, AllArcsUsed ) :-
	save_node( Node, Stream, NewArcsUsed ),
	save_links( Node, Stream ),
	save_refs( Node, Stream ),
	any_setof( Child,
		   Node has_part Child,
		   Children ),
	append( Children, Nodes, NewNodes ),
	save_nodes( NewNodes, Stream, ArcsUsed ),
	merge_lists( NewArcsUsed, ArcsUsed, AllArcsUsed ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_links - write out a data structure representing links in a module

save_links( Node, Stream ) :-
	Node has_model_refinement link_equivalences of Links, \+ Links = [], !,
		write_with_breaks( Stream, links( Node, Links ));
	true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_refs - write out a data structure representing references in a module

/* Since we do not change all the references when the subject of one of them
is deleted, there may be mentions to nonexistent components here. These are
replaced by 'obsolete' so they do not cause errors when loading the model. */

save_refs( Node, Stream ) :-
	Node has_model_refinement references of Refs,
	all(library, check_ref_entry,
	    [unify(Node), build(Refs), incr(0), build(SaveRefs)]),
	write_with_breaks( Stream, references( Node, SaveRefs )), !;
	true.

check_ref_entry(Node, Ref, Count, SaveRef) :-
	Ref = local(Rel),
	    \+ find_reference(Node, Count, Rel), !,
	    SaveRef = obsolete;
	SaveRef = Ref.

incr(Count, NewCount) :-
	NewCount is Count+1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_node - write out a data structure representing a node to a stream
% 1998: does not write model refinements

save_node( Node, Stream, ArcsUsed ) :-
	Node has_class Class,
	any_setof( Child,
		   Node has_part Child,
		   Children ),
	any_setof( CRAttr=CRValue,
		   Node has_class_refinement CRAttr of CRValue,
		   ClassRefinements ),
/*	any_setof( MRAttr=MRValue,
                   ( Node has_model_refinement MRAttr of MRValue,
		     \+ MRAttr = link_equivalences ),
                   ModelRefinements ),
*/
	any_setof( Attribute=Value,
		   Node has_graphical_attribute Attribute of Value,
		   GraphicalAttributeValuePairs ),
	write_with_breaks( Stream,
		    node( Node, Class, Children,
			  ClassRefinements, /* ModelRefinements, */
			GraphicalAttributeValuePairs)), 
	any_setof( Arc-Start-End,
		   ( Arc is_connector from Node to End, Node = Start;
		     Arc is_connector from Start to Node, Node = End ),
		   ArcsUsed ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_classes - write out data structures representing class definitions

save_classes( [], _ ).
save_classes( [Class|Classes], Stream ) :-
	any_setof( Attribute=Value,
		   Class has_class_attribute Attribute of Value,
		   AttributeValuePairs ),
	write_with_breaks( Stream, class( Class, AttributeValuePairs,
		[/* Graphics in here */] )),
	save_classes( Classes, Stream ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_arcs - write out data structures representing arcs; don't do the same
% one twice because the input list is a set.

save_arcs( [], _ ).
save_arcs( [Arc-Start-End|Arcs], Stream ) :-
	Arc has_type Type,
	!, % green cut
	any_setof( Attribute=Value,
		   Arc has_attribute Attribute of Value,
		   AttributeValuePairs ),
	any_setof( GAttribute=GValue,
		   Arc has_graphical_attribute GAttribute of GValue,
		   GraphicalAttributeValuePairs ),
	write_with_breaks( Stream, arc( Arc, Start, End, Type, AttributeValuePairs,
			GraphicalAttributeValuePairs)),
	save_arcs( Arcs, Stream ).

/* Line is written character by character in the hope that this will prevent
DOS-type CRLFs being used for the line breaks, which will then bugger up
reading the file under Unix 

write_with_breaks(Stream, Term) :-
	user:printq_to_codes(TermStr, Term),
	append(TermStr, ".", FullTermStr),
	sicstus_write_chars(Stream, FullTermStr),
	nl(Stream).

/* Clever part disabled to try to help mime stuff

insert_breaks(Stream, Term, Done, Rest) :-
	length(Rest, RLen),
	choose_breakpoint(Break),
	(Break >= RLen, !,
	    sicstus_write_chars(Stream, Rest);
	length(Line, Break),
	    append(Line, NewRest, Rest),
	    \+ suffix("\\", Line), /* do not put cr where it will be escaped
	    \+ prefix("'", NewRest), /* do not put cr before a single quote as
		     this sometimes gets escaped along with the cr 
	    \+ suffix("-", Line), /* do not put cr between a - sign and its
		     number, as the result will be read as -(n) by gnu 
	    (append([Done, Line, [10]], NewDone);
	    append([Done, Line, [92, 10]], NewDone),
		Escaped = true),
		/* try inserting a cr either on its own, which will work if it
		hits the end of a prolog atom, or escaped, which will work if
		it goes inside a single-quoted atom 
	    append(NewDone, NewRest, TestStr),
	    on_exception(_Oops, sicstus_read_from_chars(TestStr, TestTerm), 
	        fail),
	    Term = TestTerm, !,
	    sicstus_write_chars(Stream, Line),
	      (Escaped = false, !;
		  sicstus_put(Stream, 92)),
	      nl(Stream),
	    insert_breaks(Stream, Term, NewDone, NewRest)).

choose_breakpoint(Break) :-
	count_to(0,1000,1,Miss),
	(Break is 72+Miss;
	    Break is 71-Miss),
	Break > 0.
*/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ame_merge( Parent, File, Date ) opens File, reads the model
% structure in it, and adds it into Parent. All structures are renamed
% if not toplevel, to avoid clashes. Date from file is returned.

ame_merge( Parent, File, Date, HasCode ) :-
	open( File, read, Stream),
	dialogue:reassure_user("Reading information from file"),
	read( Stream, Header ),
	((Header = source(_,version=V,edition=E,date=Date);
	        Header = source(_,version=V,date=Date), E=standard;
	        Header = source(_,version=V), E=standard, Date=old), !,
	    SimileV is V-4,
	    read(Stream, Term);
	Term = Header,
	    Date=old,
	    E = standard,
	    SimileV = -1), 
	(Parent = node00001, !,
	    InitBindings = copy;
	InitBindings = []),
	store_term( Term, Stream, Parent, InitBindings, [] ),
	close( Stream ),

	(state:get_edition(evaluation),
	(HasCode=no;
	\+ E = enterprise),
	\+ HasCode = 'fuck it',
	state:eval_fn_limit_is(StopAt),
	count_functions(Parent, Fns),
	Fns > StopAt, !,
	    m_update:superfast_delete(Parent),
	    sicstus_format_to_chars("This model has ~d equations. This is greater than ~d, and it was not created by the enterprise edition, so it cannot be loaded in the evaluation edition.", [Fns, StopAt], Annoy),
	    do_dialogue("Error loading model", error, Annoy, ok, _),
	    !, fail;

	(SimileV >= 0.0, !;
	dialogue:reassure_user("Updating pre-AME 4.0 model representation"),
	    adjust_to_4),
	(SimileV >= 2.0, !;
	dialogue:reassure_user("Updating pre-Simile 2.0 model representation"),
	    adjust_to_6([])),
	(SimileV >= 4.0, !;
	dialogue:reassure_user("Updating pre-Simile 4.0 model representation"),
	    adjust_to_8),
	user:version_is(MyVStr),
	name(MyV, MyVStr),
	(MyV >= floor(SimileV), !;
	sicstus_format_to_chars("This file was created with a later version of Simile than the one you are currently running. To avoid potential problems, please update your copy to version ~f or later.", [SimileV], FutureShock),
	    do_dialogue("Future shock!", warning, FutureShock, ok, _))).

count_functions(Model, N) :-
	setof(Node, (contains(Model, Node), find_type(Node, function)), Nodes),
	    length(Nodes, N), !;
	N = 0.

adjust_to_4 :-
	Link no_longer_has_attribute destination of Dest,
	Link no_longer_has_attribute units of Units,
	!,
	Link has_new_attribute role of 
			[use(none,in_hierarchy,Dest,Units)],
	adjust_to_4.

adjust_to_4 :-
	Node has_class function,
	Node has_class_refinement value of Expr,
	replace_subexps(Expr, library, shuffle_graph_args, _, top_down,
		VarPairs, NewExpr),
	\+ VarPairs = [],
	Node has_changed_class_refinement value of NewExpr,
	adjust_to_4.

adjust_to_4 :-
	Compartment has_class compartment,
	\+ (Link is_connector from Function to Compartment,
		Function has_class function), !,
	Parent has_part Compartment,
	Function is_new_part_of Parent,
	Function has_new_class function,
	(Influence is_connector from _ to Compartment,
		Influence has_type influence,
		Influence has_changed_termination finish 
			from Compartment to Function,
		fail;
	Compartment no_longer_has_class_refinement initial_value
			of Value,
		Function has_new_class_refinement value
			of Value,
		fail;
	Compartment no_longer_has_class_refinement units of Units,
		Function has_new_class_refinement units of Units,
		fail;
	Link is_new_connector from Function to Compartment,
		Link has_new_type influence,
		adjust_to_4).

adjust_to_4 :-
	Node no_longer_has_model_refinement has_ghosts of Ghosts, !,
	(member(Ghost, Ghosts),
		Ghost no_longer_has_model_refinement is_ghost of Node,
		appears(Ghost),
		m_update:add_new_line_between(influence, Node, Ghost, _),
		fail;
	adjust_to_4).

adjust_to_4.

adjust_to_6(Done) :-
	Node has_class function,
	\+ member(Node, Done),
	Node has_class_refinement value of Expr,
	replace_subexps(Expr, library, arr_ind,_, top_down, VarPairs, NewExpr),
	all(library, inds_to_places, [build(VarPairs), unify(0)]),
	Node has_changed_class_refinement value of NewExpr,
	adjust_to_6([Node | Done]), !.

adjust_to_6(Done) :-
	Node has_class submodel,
	Node has_class_refinement multiplication_spec of Multis,
	append(Before, [count=Solo | After], Multis),
	\+ member(Solo, [[], [_ | _]]), /* not a list */
	append(Before, [count=[Solo] | After], NewMultis),	
	Node has_changed_class_refinement multiplication_spec of NewMultis,
	adjust_to_6(Done), !.

adjust_to_6(_).

adjust_to_8 :-
	Node has_class_refinement fix_math_args of V,
	Node no_longer_has_class_refinement fix_math_args of V,
	adjust_to_8.

adjust_to_8.

shuffle_graph_args(_, graph(Var, A1, A2, A3, A4, A5, A6, Size, Points), 
	graph(A1, A2, A3, A4, A5, A6, 1, Size, Points, Var), 1) :-
	Points =.. [points | _].

inds_to_places(var_pair(Expr, NewExpr), Depth) :-
	Expr = index(N),
	    (Depth >= N, !,
		NewExpr = place_in(N);
	    M is N-Depth,
		NewExpr = index(M));
	Expr = makearray(OldArrExpr, Count),
	    NewExpr = makearray(NewArrExpr, Count),
	    replace_subexps(OldArrExpr, library, arr_ind, _, top_down,
		VarPairs, NewArrExpr),
	    NewDepth is Depth+1,
	    all(library, inds_to_places, [build(VarPairs), unify(NewDepth)]).

arr_ind(_, Found, _, 0) :-
	member(Found, [index(_), makearray(_,_)]).
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% store_term does the various things necessary to translate the loaded model(s)
% into the internal representation. Arg3 is a list of bindings - pairs of
% symbols relating names used in the stored file to new unique names generated
% during the loading process. Arg4 is a set of commands to be tried again at
% the end. Looping is stopped by checking the length of the delayed agenda.

store_term( end_of_file, _, Parent, Bindings, Rest ) :- 
	!, % green cut
	length( Rest, Number ),
	dialogue:reassure_user("Co-ordinating model information"),
	deal_with_rest( Rest, Number, Parent, Bindings, [] ).
store_term( Term, Stream, Parent, Bindings, Rest ) :-
	Term =.. TermList,
	append( TermList, [Parent,Bindings,NewBindings], NewTermList ),
	NewTerm =.. NewTermList,
	call( build:NewTerm ),
	!,
	read( Stream, NextTerm ),
	store_term( NextTerm, Stream, Parent, NewBindings, Rest ).
store_term( Term, Stream, Parent, Bindings, Rest ) :-
				% delay and try again% if something fails
	read( Stream, NextTerm ),
	store_term( NextTerm, Stream, Parent, Bindings, [Term|Rest] ).

% deal_with_rest does the same thing, but with a list of leftovers

deal_with_rest( [], _, _, _, [] ).
deal_with_rest( [], PreviousLength, Parent, Bindings, Terms ) :-
	length( Terms, NewLength ),
	(NewLength < PreviousLength, !,
		deal_with_rest( Terms, NewLength, Parent, Bindings, [] );
	(build:missing(Comp),
	    sicstus_format_to_chars("Component ~w missing. The following lines in the file contained references to model components that were not found: ~w", [Comp, Terms], MessStr);
	sicstus_format_to_chars("Simile had some sort of problem incorporating the following lines from the file into the model: ~w", Terms, MessStr)),
		do_dialogue("Problem reading file", warning, MessStr, ok, _)).

deal_with_rest( [Term|Terms], Length, Parent, Bindings, Rest ) :-
	Term =.. TermList,
	append( TermList, [Parent,Bindings,NewBindings], NewTermList ),
	NewTerm =.. NewTermList,
	call( build:NewTerm ),
	!,
	deal_with_rest( Terms, Length, Parent, NewBindings, Rest ).
deal_with_rest( [Term|Terms], Length, Parent, Bindings, Rest ) :-
	deal_with_rest( Terms, Length, Parent, Bindings, [Term|Rest] ).

