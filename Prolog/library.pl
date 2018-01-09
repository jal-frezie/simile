/*******************************************************************************
**** LIBRARY FOR AME - save and load model classes, submodels, etc.         ****
**** All done in terms of an independent node-based representation, which   ****
**** is defined in terms of the model class ADT 			    ****
*******************************************************************************/

sicstus_module( library, [ame_save/5, ame_merge/5, count_functions/2] ).

sicstus_use_module( [library(lists),
	sp_only, ame_gen, m_class, utility, text, forms, build] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ame_save/4 - saves the submodels starting at the nodes listed in arg1 to the file
% named in arg 2
% models are saved in terms of calls to predicates defined in construction:, 
% thus keeping the abstract syntax away from the user.

ame_save( File, Model, Date, SelOnly, _MakeCompat) :-
	(setof(Sub, (Model has_part Sub, go_with(Sub, SelOnly)), Models), !;
	       Models = []),
	(SelOnly = yes,
	    Models = [UseAsParent],
	    \+ draw'><'get_highlit_obj(0, UseAsParent), !,
	    ame_save(File, UseAsParent, Date, SelOnly, _);
	(backup'><'is_toplevel(Model),
	    SelOnly = no,
	    setof(A-V, Model has_class_refinement A of V, Props);
	 setof(Enum, ancestor_has_enum_type(Model, Enum), AllEnums),
	    Props = [enum_types-AllEnums];	       
	Props = []),
	\+ ( member( Node, Models ),
	     \+ Node is_model_class ),
	output'><'windowize(File, WFile),
	on_exception(_, open_native(WFile, write, Stream), 
	fail), !,
	state'><'version_is(VStr),
	name(SimV, VStr),
	V is SimV + 4,
	(reassure_user(writing_root, []),
	state'><'edition_is(Edition),
	export_with_breaks(Stream, source(program='AME', version=V,
					 edition=Edition, date=Date)),
	nl(Stream),
	export_with_breaks( Stream, roots( Models )),
	nl(Stream),
	export_with_breaks( Stream, properties(Props)),
	nl(Stream),
	reassure_user(writing_node, []),
	% Arc data is saved to a separate stream -- original intention
	% was to allow the save process to try and fail each node to
	% save memory, but just doing it this way had desired
        % result (it was building list of arcs that used the resources).
        chars_from_stream(ArcData, library'><'save_nodes( Models, Stream, 
							  SelOnly, ArcData ),
			  ArcChars),
	nl(Stream),
	reassure_user(writing_arc, []),
	sicstus_write_chars(Stream, ArcChars),
	close( Stream ), !;
	fail)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_stream - does the work of ame_save/[12]. Arg [34] are "done" lists for
% Nodes and Arcs respectively - don't do the same node twice.

save_nodes( [], _,_,_ ).

save_nodes( [Node|Nodes], Stream, SelOnly, ArcData ) :-
    save_node( Node, Stream, SelOnly, NewArcsUsed ),
    save_arcs(NewArcsUsed, ArcData),
	save_links( Node, Stream, SelOnly ),
	save_refs( Node, Stream, SelOnly ),
	any_setof( Child,
		   (Node has_part Child, go_with(Child, SelOnly)),
		   Children ),
	append( Children, Nodes, NewNodes ),
	save_nodes( NewNodes, Stream, SelOnly, ArcData),
	any_setof(ArcMem, arcmem(NewArcsUsed, ArcMem), ArcMems),
	save_nodes( ArcMems, Stream, SelOnly, ArcData ).

arcmem(ArcSets, Node) :-
	member(Arc-_-_, ArcSets),
	Arc has_part Node.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_links - write out a data structure representing links in a module

save_links( Node, Stream, SelOnly ) :-
	Node has_link_equivalences AllLinks,
	setof(From-To, (member(From-To, AllLinks),
			   go_with(From, SelOnly), go_with(To, SelOnly)),
	      Links), !,
	export_with_breaks( Stream, links( Node, Links ));
	true.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_refs - write out a data structure representing references in a module

/* Since we do not change all the references when the subject of one of them
is deleted, there may be mentions to nonexistent components here. These are
replaced by 'obsolete' so they do not cause errors when loading the model. */

save_refs( Node, Stream, SelOnly ) :-
	Node has_model_refinement references of Refs,
	all(library, check_ref_entry,
	    [unify(Node), build(Refs), unify(SelOnly), incr(0),
	     build(SaveRefs)]),
	export_with_breaks( Stream, references( Node, SaveRefs )), !;
	true.

check_ref_entry(Node, Ref, SelOnly, Count, SaveRef) :-
	Ref = local(Rel),
	    \+ (find_reference(Node, Count, Rel), go_with(Rel, SelOnly)), !,
	    SaveRef = obsolete;
	SaveRef = Ref.

incr(Count, NewCount) :-
	NewCount is Count+1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_node - write out a data structure representing a node to a stream
% 1998: does not write model refinements

save_node( Node, Stream, SelOnly, ArcsUsed ) :-
	Node has_class Class,
	any_setof( Child,
		   (Node has_part Child, go_with(Child, SelOnly)),
		   Children ),
	any_setof( CRAttr=CRValue,
		   (Node has_class_refinement CRAttr of CRValue,
		       \+ (SelOnly = yes,
		       CRAttr=complete)),
		   /* if only saving seln it may be incomplete */
		   ClassRefinements ),
/*	any_setof( MRAttr=MRValue,
                   ( Node has_model_refinement MRAttr of MRValue,
		     \+ MRAttr = link_equivalences ),
                   ModelRefinements ),
*/
	any_setof( Attribute=Value,
		   Node has_graphical_attribute Attribute of Value,
		   GraphicalAttributeValuePairs ),
	export_with_breaks( Stream,
		    node( Node, Class, Children,
			  ClassRefinements, /* ModelRefinements, */
			GraphicalAttributeValuePairs)), 
	any_setof( Arc-Start-Node,
		   (Arc is_connector from Start to Node,
		       go_with(Arc, SelOnly)),
		   ArcsUsed ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

go_with(Comp, SelOnly) :-
	SelOnly = no, !;
	go_with(Comp).

go_with(Comp) :-
	draw'><'get_highlit_obj(0, Comp),
	    \+ connects_leaver(Comp), !;
	Comp has_part Inner,
	    go_with(Inner), !;
	\+ appears(Comp),
	(Comp is_connector from Start to Finish,
	    member(Use, [Start, Finish]),
	    appears(Use);
	 Use is_connector from Comp to _;
	 Use is_connector from _ to Comp),
	    go_with(Use), !;
	contains(Fn, Comp),	% comp in function-defining fragment
	    \+ Fn = Comp,
	    find_type(Fn, function),
	    implicit_function(Host, Fn),
	    go_with(Host).

% Not sure why this needs to be tested -- arcs are only blue if both ends are!
connects_leaver(Arc) :-
	Arc is_connector from Start to Mid,
	get_host(Mid, Finish),
	member(Use, [Start, Finish]),
	appears(Use),
	\+ go_with(Use, yes).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save_arcs - write out data structures representing arcs; don't do the same
% one twice because the input list is a set.

save_arcs( [], _ ).
save_arcs( [Arc-Start-End|Arcs], Stream ) :-
	Arc has_type Type,
	!, % green cut
	any_setof( Child,
		   Arc has_part Child,
		   Children ),
	any_setof( Attribute=Value,
		   Arc has_attribute Attribute of Value,
		   AttributeValuePairs ),
	any_setof( GAttribute=GValue,
		   Arc has_graphical_attribute GAttribute of GValue,
		   GraphicalAttributeValuePairs ),
	export_with_breaks(Stream,
			   arc(Arc, Start, End, Type,
			       [attached=Children | AttributeValuePairs],
			       GraphicalAttributeValuePairs)),
	% children should be separate arg but need to get through load
	% in earlier versions
	save_arcs( Arcs, Stream ).

/* Line is written character by character in the hope that this will prevent
DOS-type CRLFs being used for the line breaks, which will then bugger up
reading the file under Unix 

write_with_breaks(Stream, Term) :-
	user'><'printq_to_codes(TermStr, Term),
	append(TermStr, ".", FullTermStr),
	sicstus_write_chars(Stream, FullTermStr),
	nl(Stream).

Clever part disabled to try to help mime stuff

insert_breaks(Stream, Term, Done, Rest) :-
	length(Rest, RLen),
	choose_breakpoint(Break),
	(Break >= RLen, !,
	    sicstus_write_chars(Stream, Rest);
	length(Line, Break),
	    append(Line, NewRest, Rest),
	    \+ suffix("\\", Line), % do not put cr where it will be escaped
	    \+ prefix("'", NewRest), % do not put cr before a single quote as
		     this sometimes gets escaped along with the cr 
	    \+ suffix("-", Line), % do not put cr between a - sign and its
		     number, as the result will be read as -(n) by gnu 
	    (append([Done, Line, [10]], NewDone);
	    append([Done, Line, [92, 10]], NewDone),
		Escaped = true),
		% try inserting a cr either on its own, which will work if it
		% hits the end of a prolog atom, or escaped, which will work if
		% it goes inside a single-quoted atom 
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

ame_merge( Parent, File, SimileV, HasCode, Translated ) :-
	open_native( File, read, Stream),
	reassure_user(reading_file, []),
	read( Stream, Header ),
	((Header = source(_,version=V,edition=E,date=_);
	        Header = source(_,version=V,date=_), E=standard;
	        Header = source(_,version=V), E=standard), !,
	    SimileV is V-4.0, % were there integer versions??
	    (V >= 10.0, !, % file is UTF-8
                user'><'reopen_stream_internally_formatted(Stream, Stm, no);
	      Stm = Stream),
	    read(Stm, Term);
	Term = Header,
	    E = standard,
	    SimileV = -1,
	    Stm = Stream), 
	(Parent = node00000,
	    \+ (_ has_part Other, \+ Other = Parent), !,
	    % do not bother with renaming if opening first and only model */
	    InitBindings = copy;   
	InitBindings = []),
	store_term( Term, Stm, Parent, InitBindings, Translated, [] ),
	(V >= 10.0, !,
%	    output'><'my_delete_file(TempFile);
	    close_internally_formatted_stream(Stm);
	close( Stm )),

	(state'><'get_edition_and_limit(Edn, StopAt),
	(HasCode=no;
	\+ E = enterprise),
	\+ HasCode = 'fuck it',
	count_functions(Parent, Fns),
	Fns > StopAt, !,
	    backup'><'restart_move,
	    % abort loading project file
	    output'><'safe_tcl_eval(['catch {unset ::loadingProject}'], _),
	    query(bust_edition_limit(Fns, StopAt, Edn), error, top, [ok], _),
	    finish_progress_dialogue,
	    % prevent executable from running
	    Parent has_new_model_refinement c_new of 0,
	    fail;

	(SimileV >= 0.0, !;
	reassure_user(updating_v, ['0.0']),
	    adjust_to_4),
	(SimileV >= 2.0, !;
	reassure_user(updating_v, ['2.0']),
	    adjust_to_6([])),
	(SimileV >= 4.0, !;
	reassure_user(updating_v, ['4.0']),
	    adjust_to_8(Translated)),
	(SimileV > 4.29, SimileV < 4.31, !;
	SimileV >= 5.0, !;
	reassure_user(pl_convert_to, ['4.3']),
	    adjust_to_8_3(Translated)),
	(SimileV >= 4.8, !;
	reassure_user(updating_v, ['4.8']),
	    adjust_to_8_8(Translated)),
	(SimileV >= 5.0, !;
	reassure_user(updating_v, ['5.0']),
	    adjust_to_9(Translated)),
	(SimileV >= 5.5, !;
	reassure_user(updating_v, ['5.5']),
	    adjust_to_9_5(Parent)),
	(SimileV >= 5.8, !;
	reassure_user(updating_v, ['5.8']),
	    adjust_to_9_8(Parent)),
	(SimileV >= 6.0, !;
	  reassure_user(pl_convert_from, ['5.x']),
	    adjust_to_10(Parent)),
	(SimileV >= 6.1, !;
	  reassure_user(updating_v, ['5.x']),
	    adjust_to_10_1(Parent)),
	state'><'version_is(MyVStr),
	name(MyV, MyVStr),
	(MyV > SimileV+0.001, !, % throw away code so no need to test load
	    m_update'><'add_parameter(Parent, 1, c_new, 0);
	  MyV >= floor(SimileV), !;
	  query(future_shock(SimileV), warning, top, [ok], _))).

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
	\+ (_Link is_connector from Function to Compartment,
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
		m_update'><'add_new_line_between(influence, Node, Ghost, _),
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
	\+ member(Solo, [[], [_ | _]]), % not a list
	append(Before, [count=[Solo] | After], NewMultis),	
	Node has_changed_class_refinement multiplication_spec of NewMultis,
	adjust_to_6(Done), !.

adjust_to_6(_).

adjust_to_8(Trans) :-
	(Trans = copy; member(_-Node, Trans)),
	(Node has_class_refinement fix_math_args of V,
	    Node no_longer_has_class_refinement fix_math_args of V;
	    
	Node has_class_refinement table_data of
	    [file=F, data=T, indices=I, current=C],
	% table entered before enum_types invented
	    inters'><'add_zeros(C, Node, 0, NC, D, U),
	    length(D, N),
	    list_of(int, N, B),
	    Node has_changed_class_refinement table_data of
	[file=F, data=T, indices=I, current=NC, units=U, bounds=B, dims=D];
	Node has_class function,
	    Node has_class_refinement value of Expr,
	    replace_subexps(Expr, library, tabulate_graph_args,
			    Table, top_down, VarPairs, NewExpr),
	    VarPairs = [_],
	    Node has_changed_class_refinement value of NewExpr,
	    Node has_new_class_refinement table_data of Table;
	Node has_class_refinement fill_colour of Image,
	    output'><'safe_tcl_eval(['ColourExists', Image], "0"),
	    Node no_longer_has_class_refinement fill_colour of Image,
	    Node has_new_class_refinement fill_image of Image),	    
	adjust_to_8(Trans).

% new bit to update old boolean constants
adjust_to_8(Trans) :-
	(Trans = copy; member(_-Node, Trans)),
	Node has_class function,
	Node has_class_refinement value of Expr,
	replace_subexps(Expr, library, update_old_booleans,
			dummy, top_down, [_|_], NewExpr),
	Node has_changed_class_refinement value of NewExpr,
	adjust_to_8(Trans).
	
adjust_to_8(Trans) :-
	(Trans = copy; member(_-Comp, Trans)),
	(Fixing = node,
	    Comp has_class_refinement TclBound of TermInUtf8;
	 Fixing = arc,
	    Comp has_attribute TclBound of TermInUtf8),
	replace_subexps(TermInUtf8, tcltk, reEncode, _, top_down,
			_VPs, TermInTtfn),
	\+ TermInTtfn = TermInUtf8 ,
	(Fixing = node,
	    Comp has_changed_class_refinement TclBound of TermInTtfn;
	 Fixing = arc,
	    Comp has_changed_attribute TclBound to TermInTtfn),
	fail;
	true.

adjust_to_8_3(Trans) :-
	(Trans = copy; member(_-Node, Trans)),
	 Node has_class_refinement table_data of _, % just reduces workload
	    Node has_class_refinement value of Expr,
	    replace_subexps(Expr, library, separate_table_args,
			    _, top_down, _, NewExpr),
	    Node has_changed_class_refinement value of NewExpr,
	    Node has_class_refinement spec of _,
	    sicstus_write_to_chars(NewExpr, NewStr),
	    sicstus_atom_chars(NewSpec, NewStr),
	    Node has_changed_class_refinement spec of NewSpec,
	    fail;
	true.

adjust_to_8_8(Trans) :-
	(Trans = copy; member(_-Node, Trans)),
	    Node has_class_refinement value of Expr,
	    replace_subexps(Expr, library, lose_excs, _, top_down, _, NewExpr),
	    Node has_changed_class_refinement value of NewExpr,
% spec does not need to change, m_l_f_p will do this
	    Node has_class_refinement table_data of TabDat,
	    \+ member(file='/graph/', TabDat),
	    select(current=With0s, TabDat, MoreTabDat),
	    trim_heads(With0s, Without0s),
	    Node has_changed_class_refinement table_data
	    of [current=Without0s | MoreTabDat],
	    fail;
	true.

adjust_to_9(Trans) :-
% Nodes other than submodels have their centres rather than bounding boxes
	((Trans = copy, Obj is_model_class; member(_-Obj, Trans)),
% move any descs and comments on functions to their hosts
	    (Obj has_class function,
		member(CmtField, [description, comment]),
		Obj no_longer_has_class_refinement CmtField of CmtValue,
		m_update'><'get_host(Obj, VisObj),
		(VisObj is_of_sort line,
		    VisObj has_new_attribute CmtField of CmtValue;
		VisObj is_of_sort box,
		    VisObj has_new_class_refinement CmtField of CmtValue);
% replace bounding boxes of primitives with centre points
	    Obj has_graphical_attribute bounding_box of BB,
		\+ find_type(Obj, submodel),
		Obj no_longer_has_graphical_attribute bounding_box of BB,
		image'><'middle(BB, Pt),
		Obj has_new_graphical_attribute centre of Pt);
% Invisible terminators get points from link
	(Trans = copy, Node is_model_class, ame_gen'><'chain_from_node(Node, Obj);
	    member(_-Obj, Trans)),
	    Obj no_longer_has_graphical_attribute course of Course,
	    Course = [Pn, MPt | M],
	    suffix([P0], [MPt | M]),
	    Obj is_connector from Foo to Bar,
	    (posn_if_needed(Foo, P0), fail; true),
	    (posn_if_needed(Bar, Pn), fail; true),
% Curved links get relative midpoints rather than course
	    (Obj is_of_sort curved,
		event'><'relativize_centre(P0, Pn, MPt, CPt),
		Obj has_new_graphical_attribute curve of CPt;
% Kinked links have kink location coded, others get default
	    \+ Obj is_of_sort curved,
		(Course = [[Xn, Yn], _, [X1, Y1], [X0, Y0]],
		    (X1 = X0,
			KinkPosn is 1000*(Y1-Y0)/(Yn-Y0);
		     Y1 = Y0,
			KinkPosn is 1000*(X1-X0)/(Xn-X0));
		length(Course, 2),
		    KinkPosn = 550),
% Flows with bowties have fractional bowtie posn coded, others get default
		find_base(Obj, BowtieArc),
		(BowtieArc = Obj,
		    Obj no_longer_has_graphical_attribute bowtie of BTBox,
		    image'><'middle(BTBox, BTPt),
		    image'><'closest_centre(BTPt, Course, _,_, BTPosn);
		\+ BowtieArc = Obj,
		    BTPosn = 550),
		CPt = [KinkPosn, BTPosn]),
	    Obj has_new_graphical_attribute curve of CPt),
	fail;
	true.

adjust_to_9_5(Parent) :-
	contains(Parent, Node),
	m_update'><'remove_floater(Node), fail;
	true.

adjust_to_9_8(Parent) :-
        contains(Parent, Fn),
	Fn has_class_refinement table_data of TDList,
        select(current=ListList, TDList, Others),
        floatify_large_ints(ListList, NewLL, Hit),
	Hit == 1,
	(select(units=const_int, Others, Leave) ->
	    New = [current=NewLL, units=1 | Leave],
	    NewUnits = 1;
	    New = [current=NewLL | Others]),
	Fn has_changed_class_refinement table_data of New,
% now may need to re-parse eqn to fix overall units
        NewUnits == 1,
	get_host(Fn, Vis),
	event'><'spread_dims(Vis),
	fail; true.

adjust_to_10(Parent) :-
	contains(Parent, Flow),
	% all sections to have same caption
	    Flow is_of_sort has_bowtie,
	    bowtie_section(Flow, HasName),
	    caption_for(HasName, Capt),
	    Flow has_changed_attribute name to Capt,
	% move bowtie posn info from flow to fn
	    implicit_function(Flow, ImpFn),
	    \+ ImpFn has_graphical_attribute along of _Bowtie,
	    Flow no_longer_has_graphical_attribute curve of [Kink, Bowtie],
	    Flow has_new_graphical_attribute curve of [Kink, 1000],
	    ImpFn has_new_graphical_attribute along of Bowtie,
	    fail;
	% always use 'description', never 'desc'
	contains(Parent, Submodel),
	    Submodel no_longer_has_class_refinement desc of Desc,
	    Submodel has_new_class_refinement description of Desc,
	    fail;
	% no quotes round enumerated type specifiers in dimensions
	contains(Parent, Submodel),
	    Submodel has_class_refinement multiplication_spec of MS,
	    select(count=DimList, MS, MoreMS), % not all have count
	    all(library, dequote_ET, [build(DimList), build(NewDL)]),
	    Submodel has_changed_class_refinement multiplication_spec
	            of [count=NewDL | MoreMS],
	    fail;
	contains(Parent, Function),
	    Function no_longer_has_class_refinement units of U,
            dequote_ET_units(U, NewU),
            Function has_new_class_refinement units of NewU,
	    fail;
	update_per_record_bracket_style(Parent);
	% Influence properties now on last section because it is not shared
	contains(Parent, Influence),
	    find_type(Influence, influence),
	    (Influence no_longer_has_attribute use_sofar of V,
	        find_name_host(Influence, NewAttrLocn),
	        NewAttrLocn has_new_attribute use_sofar of V,
	        fail;
              Influence no_longer_has_attribute role of Roles,
                all(library, dequote_role_ETs, [build(Roles), build(NewRoles)]),
                Influence has_new_attribute role of NewRoles,
                fail);
        contains(Parent, Sm),
	    Sm has_graphical_attribute internal_extent of Box,
            Sm has_part Crossing,
            find_type(Crossing, border),
            Crossing no_longer_has_graphical_attribute centre of Ctr,
	    event'><'get_posn_around(Ctr, Box, Theta),
            Crossing has_new_graphical_attribute along of Theta,
            fail;
	true.

adjust_to_10_1(Parent) :-
% should probably have been done in 6.0 -- legacy dimensionless flows no longer
% parse (though they build) so replace them with new default
	contains(Parent, Flow),
	    Flow is_of_sort has_bowtie,
	    implicit_function(Flow, ImpFn),
	    ImpFn has_changed_class_refinement units from 1 to 1/day,
	    fail;
	true.
	
dequote_ET(Qat, UQat) :-
	atom(Qat),
	name(Qat, Qstr),
	append([34 | UQstr], [34], Qstr), !,
	name(UQat, UQstr);
	UQat = Qat.

dequote_ET_units(U, NewU) :-
	m_update'><'analyze_array(U, Base, DimList),
	(Base = a(Qtd) -> dequote_ET(Qtd, DQtd), NewB = a(DQtd);
		NewB = Base),
	all(library, dequote_ET, [build(DimList), build(NewDL)]),
	m_update'><'build_array(NewB, NewDL, NewU).

dequote_role_ETs(use(Rel, Use, Ref, OldETs), use(Rel, Use, Ref, ETs)) :-
        dequote_ET_units(OldETs, ETs).

floatify_large_ints([H | T], [NH | NT], Hit) :- !,
        floatify_large_ints(H, NH, Hit),
        floatify_large_ints(T, NT, Hit).

floatify_large_ints(N, NN, Hit) :-
        integer(N), abs(N) > 268435455, !, % largest int for 32-bit GProlog
	    NN is float(N), Hit = 1;
	NN = N.

update_per_record_bracket_style(Parent) :- % should do all then fail
	contains(Parent, Node),
	Node has_class submodel,
	by_record(Node),
	ExitLink is_connector from Node to _,
	(ghost_link(ExitLink, _Base, Ghost),
	    Link is_connector from Ghost to _;
	Link = ExitLink),
	Link has_type influence,
	(OtherArc = Link; sequence(Link, OtherArc)),
	\+ sequence(OtherArc, _),
	OtherArc is_connector from _ to Fn,
	m_update'><'get_all_links(Fn, continuous, _,
				  input_link(id(OtherArc, Rel, Use),
					     _, AddRef, _, NewDims)),
	OtherArc has_attribute role of Roles,
	select(use(Rel, Use, OldRef, _), Roles, MoreRoles),
	(OldRef = usr(SubRef), NewRef = usr(AddRef);
	    \+ OldRef = usr(_), SubRef = OldRef, NewRef = AddRef),
	OtherArc has_changed_attribute role to
	[use(Rel, Use, NewRef, NewDims) | MoreRoles],
	% OK now substitute new name into eqn
	Fn has_class_refinement value of OldVal,
	replace_subexps(OldVal, inters, swap_vars, switch(SubRef, AddRef),
			top_down, _, NewVal),
	Fn has_changed_class_refinement value of NewVal,
	Fn has_class_refinement spec of OldSpec, % may fail
	name(OldSpec, OldStr),
	sicstus_write_to_chars(SubRef, SubStr),
	sicstus_write_to_chars(AddRef, AddStr),
	replace_substrings(SubStr, OldStr, AddStr, NewStr),
	name(NewSpec, NewStr),
	Fn has_changed_class_refinement spec of NewSpec,
	fail.

replace_substrings(Lose, Start, Gain, Result) :-
	append(Lose, Tail, Half),
	\+ suffix(Half, Gain), % subbing inadvisable and maybe unnecessary
	append(Head, Half, Start), !,
	append(Gain, Tail, NewHalf),
	append(Head, NewHalf, Mid),
	replace_substrings(Lose, Mid, Gain, Result);
	Result = Start.
	
posn_if_needed(Prim, Pt) :-
	find_type(Prim, Type),
	(Type = submodel, !,
	    \+ Prim has_graphical_attribute bounding_box of _;
	member(Type, [variable, cloud]),
	    \+ Prim has_graphical_attribute centre of _),
	Prim has_new_graphical_attribute centre of Pt,
	m_update'><'change_class(Prim, Type, border).

	    
trim_heads(With0s, No0s) :-
	With0s = [_H | T], !,
	   all(library, trim_heads, [build(T), build(No0s)]);
	No0s = With0s.

lose_excs(_, WithExc, NoExc, 1) :-
	WithExc =.. ['!', Arg],
	    NoExc = not Arg.

separate_table_args(_, table(Args), NewTableFn, 0) :-
	NewTableFn =.. [table | Args].

shuffle_graph_args(_, graph(Var, A1, A2, A3, A4, A5, A6, Size, Points), 
	graph(A1, A2, A3, A4, A5, A6, 1, Size, Points, Var), 1) :-
	Points =.. [points | _].

tabulate_graph_args([file='/graph/', data=[YL,YH,YR], indices=[XL,XH,XR,R],
		     current=Pts, units=1, bounds=1, dims=N],
		    graph(XL, XH, XR, YL, YH, YR, R, N, Ps, X), graph(X), 1) :-
	Ps =.. [points | Pts].

update_old_booleans(dummy, Fn, ET, 0) :-
	Fn =.. [Head | _],
	member(Head-ET, [false-'"false"', true-'"true"']).

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

store_term( end_of_file, _, Parent, Bindings, AllBindings, Rest ) :- 
	!, % green cut
	length( Rest, Number ),
	reassure_user(pl_coord, []),
	deal_with_rest( Rest, Number, Parent, Bindings, AllBindings, [] ).
store_term( Term, Stream, Parent, Bindings, AllBindings, Rest ) :-
	Term =.. TermList,
	append( TermList, [Parent,Bindings,NewBindings], NewTermList ),
	NewTerm =.. NewTermList,
	%reassure_user(reading_file, []),
	call( build'><'NewTerm ),
	!,
	read_skipping_junk( Stream, NextTerm ),
	store_term( NextTerm, Stream, Parent, NewBindings, AllBindings, Rest ).
store_term( Term, Stream, Parent, Bindings, AllBindings, Rest ) :-
				% delay and try again% if something fails
	read_skipping_junk( Stream, NextTerm ),
	store_term( NextTerm, Stream, Parent, Bindings, AllBindings,
		    [Term|Rest] ).

read_skipping_junk(Stream, Term) :-
	catch(read(Stream, Term), Spew,
	      (query(declaration_misparse(Spew), error, top, [abort], more),
		  read_skipping_junk(Stream, Term))).

% deal_with_rest does the same thing, but with a list of leftovers

deal_with_rest( [], _, _, B,B, [] ).
deal_with_rest( [], PreviousLength, Parent, Bindings, AllBindings, Terms ) :-
	length( Terms, NewLength ),
	(NewLength < PreviousLength, !,
	    deal_with_rest(Terms, NewLength, Parent, Bindings, AllBindings,[]);
	(build'><'missing(Comp),
	    query(lost_component(Comp, Terms), warning, top, [ok], _);
	query(bad_model_format(Terms), warning, top, [ok], _)),
	    AllBindings = Bindings).

deal_with_rest( [Term|Terms], Length, Parent, Bindings, AllBindings, Rest ) :-
	Term =.. TermList,
	append( TermList, [Parent,Bindings,NewBindings], NewTermList ),
	NewTerm =.. NewTermList,
	call( build'><'NewTerm ),
	!,
	deal_with_rest(Terms, Length, Parent, NewBindings, AllBindings, Rest).
deal_with_rest( [Term|Terms], Length, Parent, Bindings, AllBindings, Rest ) :-
	deal_with_rest( Terms, Length, Parent, Bindings, AllBindings,
			[Term|Rest] ).

