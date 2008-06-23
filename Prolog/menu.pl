/*
menu_handle.pl
---------------
This contains the code for responding to events signalled by the user 
interface of the application. It responds by:
* Querying and updating the GUI state representation
* Calling the model maintenance module to add information to the model
* Making calls to the screen drawing module (new image, or redraw)
*/
sicstus_module(menu, [undo_edit/2, redo_edit/2, menu_select/1, mode_select/1,
	menu_handle/3, context_find/3, set_box_size/5, change_size/2,
	not_last_toplevel/1, off_window/2, certain_death_node/1,
	kill_everything/1]).
	
sicstus_use_module([sp_only, compile, dialogue, m_update, image, draw, 
	state, backup, library, ame_gen, utility, ss_import, m_class,
	library(lists), library(ordsets)]).

undo_edit(Wid, Wids) :-
	Wid shows_model ClickedModel,
	contains(Model, ClickedModel),
	is_toplevel(Model),
	go_back(Model),
	all(menu, check_exist, [build(Wids)]).

redo_edit(Wid, Wids) :-
	Wid shows_model ClickedModel,
	contains(Model, ClickedModel),
	is_toplevel(Model),
	go_forward(Model),
	all(menu, check_exist, [build(Wids)]).

check_exist(Wid) :-
	Wid shows_model Mod,
	(get_shape(Mod, internal_extent, Rect), !,
	    output:tk_grow_canvas(Wid, Rect);
	delete_window(Wid)).
	
menu_select(Seln) :-
	update_mode(add),
	display_mode(add),
	set_adding_object(Seln),
	initialize_phase.

mode_select(Seln) :-
	update_mode(Seln),
	display_menu(none),
	initialize_phase.

update_mode(NewMode) :-
	get_mode(OldMode),
	(\+ NewMode = move,
	    normalize(_),
	    fail;
	give_focus('{}'),
	OldMode = NewMode), !;
	set_mode(NewMode),
	(Win shows_model _,
	    (NewMode = select,
		enable_text_editing_in(Win);
		\+ NewMode = select,
		disable_text_editing_in(Win)),
	    fail;
	    set_cursor_for(NewMode)).

set_cursor_for(NewMode) :-
	NewMode = add, !,
	    cursor_is(target);
	NewMode = move, !,
	    cursor_is(hand2);
/*	NewMode = move, !,
	    assert(cursor_is(fleur));
	NewMode = copy, !,
	    assert(cursor_is(exchange));
	NewMode = delete, !,
	    assert(cursor_is(pirate));
*/	NewMode = ghost, !,
	    cursor_is(sqb('GetGhostCursor'));
	NewMode = snap, !,
	    cursor_is(question_arrow);
	cursor_is(arrow).

stick_model_in(Win, Parent, Name, Mode) :-
	Mode = reopen,
	(set_model_file(Parent, Name),
	    is_toplevel(Parent),
	    get_default_export_name(Parent, "", DefName),
	    find_all_comps(Root, Parent),
	    event:list_captions(Root, Toplevels),
	    add_parameter(Parent, 0, name, DefName),
	    event:retitle_duplicate(Parent, Toplevels),
	    fail);
	use_temp_dir(LocalDir),
	(event:list_captions(Parent, Used), !; true),
	abs_path_name(Parent, root, InsertDir),
	append_atoms([LocalDir, '/', InsertDir], TargetDir),
        start_progress_dialogue(Win),
        reassure_user("Decoding MIME-format saved file"),
	output:load_file(Parent, TargetDir, Name, CheckedStr),
	substitute(0, CheckedStr, 95, SafeCheckedStr),
	name(Checked, SafeCheckedStr),
	(member(Checked, [no, yes]), !, 
	    append_atoms(TargetDir, '/model.pl', PrologData),
	    ame_merge(Parent, PrologData, FileV, Checked, Translated),
	    /* date not needed */
	    output:my_delete_file(PrologData),

	    /* If any nodes have actually been translated, scrap their
	        submodel executables */
	    (member(Old-New, Translated),
		\+ Old = New,
		find_all_comps(TweakedModel, New),
		\+ get_av_pair(TweakedModel, 1, c_new, 0),
		m_update:add_parameter(TweakedModel, 1, c_new, 0),
		fail;
		
	    /* Now if the saved model has any images these will be in the top
	    dir (fttb) so get them loaded */
	    transfer_images(Parent, TargetDir, in)),

	    append_atoms(TargetDir, '/model.cnv', GraphFileName),
	/* If this exists, call tcl to skee-WIRT it into each parent window */
	    (output:my_file_exists(GraphFileName),
		FileV > 4.05, !,
		/* reject canvas files older than v4.1 because clear submodels
		need backgrounds to get paths graphically */
		(Win2 shows_model Parent,
		    inject_graphics(Win2, GraphFileName),
		    (Translated = copy;
		    \+ Translated = copy,
			dialogue:reassure_user("Translating internal IDs of canvas objects."),
			translate_canvas_pl_names(Win2, Translated)),
		    fail;
		true);
	    /* this should call Prolog back with the display detail vals */
	    NeedsRedraw = 1),
	    output:my_delete_file(GraphFileName);
	/* legacy case, file opened is Prolog:
	    no canvas, images or runnables */
	on_exception(ProLoss, ame_merge(Parent, Name, _FileV, no, Translated),
		     (make_nice_error_message(ProLoss, ProLite),
		     show_error(Parent, open_model_failed(Checked, ProLite)))),
	    NeedsRedraw = 1;
	/* insert failed because it took model over comp limit */
	restart_move,
	    finish_progress_dialogue,
	    !, fail),
        finish_progress_dialogue,
	(Mode = reopen,
	    check_autosave(Parent, Name, Translated, NeedsRedraw),
	    (NeedsRedraw = 0,
		/* Graphics update will have made a tk_visible call which we do
		not want to save as a separate move so forget it */
 	        input:retract(resizing_windows(Win)), !;
	    resize_canvas_for(Parent),
		(Win2 shows_model Parent,
		    redraw_window(Win2),
		    fail;
		 true)),
	    update_captions(Parent),
	    redisplay(Parent),
	    output:run_if_package;
	Mode = insert(Pt),
	    (Translated = copy, !, /* paste into empty sole toplevel */
	    /* reset window title in case graphics injection changed it
	    (also makes sure there is a base canvas item */
	        reset_titles(Parent),
	        setof(Mover, (contains(Parent, Mover),
				 appears(Mover), \+ Mover = Parent), Lighters);
	    setof(Mover, O^(member(O-Mover, Translated),
			 appears(Mover)), Lighters)),
	    setof(Mover, (member(Mover, Lighters),
			     find_all_comps(Parent, Mover)), Movers),
	    (member(Mover, Lighters),
	        Mover is_of_sort box,
		event:do_colours(Mover, on),
		fail;
	    member(Mover, Movers),
	        Mover is_of_sort box,
		get_drawing_form(Mover, _, Box),
		merge_box(Box),
		fail;
	    retract(combined_box_is(Box))),
	    
	    (find_space_for(Box, Parent, Lighters, Pt, [Xoffset, Yoffset]),
		all(event, adjust_posn,
		    [build(Movers), unify([-Xoffset, -Yoffset, 1, 1])]),
		all(event, retitle_duplicate, [build(Movers), unify(Used)]),
		(member(Mover, Movers),
		    redisplay(Mover),
		    fail;
		 finish_move(Parent, 1));
	    do_dialogue("Insertion error", error, "Unable to insert components here -- not enough free space", ok, _),
		restart_move)).

:- dynamic(combined_box_is/1).

merge_box([L1, T1, R1, B1]) :-
	(retract(combined_box_is([L2, T2, R2, B2])),
	    L is min(L1, L2),
	    T is min(T1, T2),
	    R is max(R1, R2),
	    B is max(B1, B2), !;
	 [L, T, R, B] = [L1, T1, R1, B1]),
	assert(combined_box_is([L, T, R, B])).
	
check_if_already_open(Name) :-
	get_model_file(Model, Name),
	Win shows_model Model,
	output:safe_tcl_eval([wm, deiconify, sqb([winfo, toplevel, Win])], _),
	output:safe_tcl_eval([raise, sqb([winfo, toplevel, Win])], _).


resize_canvas_for(Parent) :-
%	(setof(Box, contains_box(Parent, Box), Boxes), !, Boxes = []),
	all(image, get_inner_bound,
	    [unify(Parent), build([l,t,r,b]), build([LB, TB, RB, BB])]),
	Ln is LB-10,
	Tn is TB-10,
	Rn is RB+10,
	Bn is BB+10,
	change_shape(Parent, internal_extent, [Ln, Tn, Rn, Bn]),
	expand_canvas(Parent, [Ln, Tn, Rn, Bn]).

/* menu_handle. First arg is title of menu, second is item selected. */

menu_handle(Win, file, new) :-
	Win shows_model Parent,
	check_deletable(Win, Parent),
	remove_model(Win, Parent),
	finish_move(Parent, 0),
	clear_model_file(Parent),
	set_save_status(Win, safe),
%	caption_for(Parent, Name),
%	new_autosave(Parent, Name),
	update_captions(Parent).

menu_handle(_Win, file, new_toplevel) :-
	m_update:make_desktop(_,_).

menu_handle(_Win, open_toplevel, Name) :-
	check_if_already_open(Name), !;
	m_update:make_desktop(Parent, Win),
	scrub_autosave(Parent),
	stick_model_in(Win, Parent, Name, reopen).

menu_handle(Win, file, open) :-
	get_load_file(Name),
	(Name = '', !;
	menu_handle(Win, reopen, Name)).

menu_handle(Win, reopen, Name) :-
	Win = '.hi.canvas', !,
	    menu_handle(Win, open_toplevel, Name);
	Win shows_model Parent,
	(is_toplevel(Parent),
	    find_all_comps(Parent, _), !,
	    menu_handle(Win, open_toplevel, Name);
	(is_toplevel(Parent), !,
	    \+ check_if_already_open(Name),
	    scrub_autosave(Parent);   
	 check_deletable(Win, Parent),
	    remove_model(Win, Parent)),
	    stick_model_in(Win, Parent, Name, reopen)).

menu_handle(Win, insert, Name) :-
	Win shows_model Parent,
	select_all_in(Parent, base),
	stick_model_in(Win, Parent, Name, insert([0,0])).

menu_handle(Win, file, save) :-
	Win shows_model Model,
	do_save(Win, Model, false).

menu_handle(Win, file, save_as) :-
	Win shows_model Model,
	do_save(Win, Model, true).

menu_handle(Win, file, save_seln_as) :-
	Win shows_model Model,
	do_save(Win, Model, seln_only).

menu_handle(Win, file, save_interface) :-
	Win shows_model Model,
	contains(TopModel, Model),
	is_toplevel(TopModel),
	
	caption_for(Model, MCaption),
	(is_population(Model), !,
	    Bounds=population;
	get_node_size(Model, Bounds)),
	
	get_default_export_name(Model, ".isf", DefName),
	get_program_file(DefName, TopModel, FileName),
	start_progress_dialogue(Win),
	open_native(FileName, write, Stream),
	write_with_breaks(Stream, interface_spec_for(MCaption, Bounds)),
	save_references(Stream, Model),
	(member(Type, [relation, flow, influence]),
	member(Dir, [in, out]),
	sicstus_format_to_chars("Listing ~as going ~a", [Type, Dir], ProgStr),
	reassure_user(ProgStr),
	nl(Stream),
	write_with_breaks(Stream, section(Type, Dir)),
	get_submodel_interface(Model, Type, Dir, _, Entry),
	    write_with_breaks(Stream, Entry),
	    fail;
	close(Stream),
	finish_progress_dialogue).

menu_handle(Win, file, CompOrBuild) :-
	(CompOrBuild = compile_c,
	    output:safe_tcl_eval([info, sharedlibextension], IdentStr),
	    Vers = Serial;
	 CompOrBuild = build_c,
	    IdentStr = ".cpp",
	    Vers = ''),
	Win shows_model Model,
	((is_toplevel(Model);
	    get_av_pair(Model, 0, separate, 1)), !,
	name(Ident, IdentStr),
	get_default_export_name(Model, IdentStr, DefN),
	get_program_file(DefN, Model, Tgt),
	start_progress_dialogue(Win),
	use_temp_dir(Temp),
	find_all_comps(Base, Model),
	(Base = root,
	    CompDir = Temp;
	abs_path_name(Base, root, Path),
	    append_atoms([Temp, '/', Path], CompDir)),
	(\+ rebuild_code(c, Model, CompDir), !;
	(get_av_pair(Model, 1, c_new, Serial), !; Serial = ''),
	    caption_for(Model, Capt),
	    append_atoms([CompDir, '/', Capt, '/model', Vers, Ident], Top),
	    output:safe_tcl_eval([file, copy, '-force', br(Top), br(Tgt)], _));
	do_dialogue("Error exporting code", error, "This submodel does not have its own code.", ok, _)).

menu_handle(Win, file, RunCmd) :-
	member([RunCmd, Lang], [[run_c, c], [run_tcl, tcl]]),
	Win shows_model Node,
	start_progress_dialogue(Win),
	/* Compile the thing into whatever, load it */
	use_temp_dir(Dir),
	(rebuild_code(Lang, Node, Dir), !,
	    /* no much point going for run */
	    on_exception(Whoops,
			 output:prepare_execution(Node, Lang),
		     (sicstus_write_to_chars(Whoops, Squeak),
		     do_dialogue("Compilation or startup error", error,
				  Squeak, ok, _),
			 scrub_run(Node, 0))),
	    set_running_model(Node);
	    true),
	(retract(new_exec_for(_Any)), !,
	    retractall(new_exec_for(_)),
	    finish_move(Node, 0);
	restart_move).

%################################### Bob's changes (tcl/tk version): start (
menu_handle(Win, file, list_eqns) :-
	Win shows_model Model,
	get_default_export_name(Model, ".txt", DefName),
	tk_equationlisting_start(DefName, Model),
        % changed from mysetof to findall to preserve the containment hierarchy 
	findall(Component,(contains(Model,Component),find_type(Component,submodel),appears(Component)),Submodels),
	%mysetof(Component,(contains(Model,Component),find_type(Component,submodel),appears(Component)),Submodels),
	display_submodels(1,Submodels).

% HTML stuff
/*
menu_handle(Win, file, list_eqnsxxxxxx) :-
	Win shows_model Model,
	open('c:/equations.html', write, Stream),
	write(Stream,'<html><head><title>Simile model equation listing</title></head><body>'),nl(Stream),
	mysetof(Component,(contains(Model,Component),find_type(Component,submodel)),Submodels),
	display_submodels(Stream,Submodels),
	write(Stream,'</body></html>'),nl(Stream),
	close(Stream).

display_submodels(_,[]).
display_submodels(Stream,[Submodel|Submodels]):-
	rel_path_name(Submodel, Model, _,_, SmCapt),
	sicstus_format_to_chars("Equations in ~a", [SmCapt], HeaderStr),
	name(Header, HeaderStr),
	write(Stream,'<br><br><b>'),
	write(Stream, Header),
	write(Stream,'</b><br>'),nl(Stream),
	write(Stream,'<table border cellspacing=0 cellpadding=3 width="700">'),nl(Stream),
	mysetof((Entry,Description,Comment,InFlows,OutFlow),write_eqn_term(Submodel,Entry,Description,Comment,InFlows,OutFlow),Entries),
	display_entries(Stream,Entries),
	write(Stream,'</table>'),nl(Stream),
	display_submodels(Stream,Submodels).

display_entries(_,[]).
display_entries(Stream,[(VarType:VarLabel=Expression where WhereList,Comment)|Entries]):-
	write(Stream,'<tr align=left valign=top><td><table width=340><tr align=left valign=top>'),
	display_vartype(Stream,VarType),
	display_varlabel(Stream,VarLabel),
	write(Stream,'<td width=10>=</td>'),nl(Stream),
	display_expression(Stream,Expression),
	write(Stream,'</tr></table></td>'),nl(Stream),
	display_wherelist(Stream,WhereList),
	display_comment(Stream,Comment),
	write(Stream,'</tr>'),nl(Stream),nl(Stream),
	display_entries(Stream,Entries).

display_vartype(Stream,VarType):-
	write(Stream,'<td width=20><img SRC="'),
	vartype_gif(VarType,Gif),
	write(Stream,Gif),
	write(Stream,'"></td>'),nl(Stream).

vartype_gif(compartment,'images/toolbar/compartment.gif').
vartype_gif(flow,'images/toolbar/flow.gif').
vartype_gif(condition,'images/toolbar/condition.gif').
vartype_gif(creation,'images/toolbar/creation.gif').
vartype_gif(immigration,'images/toolbar/immigration.gif').
vartype_gif(loss,'images/toolbar/loss.gif').
vartype_gif(reproduction,'images/toolbar/reproduction.gif').
vartype_gif(variable,'images/toolbar/variable.gif').
vartype_gif(X,'Unknown variable type').

display_varlabel(Stream,VarLabel):-
	write(Stream,'<td width=80><b>'),
	write(Stream,VarLabel),
	write(Stream,'</b></td>'),nl(Stream).

display_expression(Stream,Expression):-
	write(Stream,'<td width=230>'),
	write(Stream,Expression),
	write(Stream,'</td>'),nl(Stream).

display_wherelist(Stream,[null]):-!,
	write(Stream,'<td width=160>.</td>'),nl(Stream).
display_wherelist(Stream,WhereList):-
	write(Stream,'<td width=160>Where:<br>'),
	display_wherelist1(Stream,WhereList),
	write(Stream,'</td>'),nl(Stream).

display_wherelist1(_,[]).
display_wherelist1(Stream,[Where|WhereList]):-
	write(Stream,Where),write(Stream,'<br>'),
	display_wherelist1(Stream,WhereList).

display_comment(Stream,'null'):-
	write(Stream,'<td width=140>.</td>'),nl(Stream).
display_comment(Stream,Comment):-
	write(Stream,'<td width=140><i>'),
	write(Stream,Comment),
	write(Stream,'</i></td>'),nl(Stream).


%####### Note: original 'list_eqns' disabled
menu_handle(Win, file, list_eqnsxxx) :-
	Win shows_model Model,
	get_default_export_name(Model, ".eqn", DefName),
	get_program_file(DefName, FileName),
	open(FileName, write, Stream),
	(contains(Model, Submodel),
	find_type(Submodel, submodel),
	rel_path_name(Submodel, Model, _,_, SmCapt),
	sicstus_format_to_chars("Equations in ~a", [SmCapt], HeaderStr),
	name(Header, HeaderStr),
	write(Stream, Header), nl(Stream),
	write_eqn_term(Submodel, Entry, Description, Comment,InFlows,OutFlow),
	write(Stream, Entry), nl(Stream),
	(Comment = '';
	\+ Comment = '', write(Stream, Comment), nl(Stream)),
	fail;
	close(Stream)).
%################################### Bob's changes: end

menu_handle(Win, file, prolog_eqns) :-
	Win shows_model Model,
	get_default_export_name(Model, ".pl", DefName),
	get_program_file(DefName, FileName),
	open(FileName, write, Stream),
	start_progress_dialogue,
	(contains(Model, Submodel),
	find_type(Submodel, submodel),
	rel_path_name(Submodel, Model, _,_, SmCapt),
	setof(EqnTerm, Cmt^write_eqn_term(Submodel, EqnTerm, Description, Cmt,InFlows,OutFlow),
		EqnTerms),
	write_with_breaks(Stream, submodel_equation_list(SmCapt, EqnTerms)),
	nl(Stream),
	fail;
	close(Stream),
	finish_progress_dialogue).
*/

menu_handle(_Win, file, import_ss) :-
	output:safe_tcl_eval(['ConvertSSxml'], _),
	m_update:make_desktop(Parent, _),
	use_temp_dir(Dir),
	append_atoms(Dir, '/ss_decls.pl', SSFile),
	convert_ss(SSFile, Parent),
	finish_move(Parent, 0).

menu_handle(Win, file, export_prolog) :-
	Win shows_model Model,
	\+ too_big_for_edn(Model),
	contains(TopModel, Model),
	is_toplevel(TopModel),
	get_default_export_name(Model, ".pl", DefName),
	get_program_file(DefName, TopModel, FileName),
	output:date_is(Date),
        start_progress_dialogue(Win),
	save_isolated(FileName, Model, Date, no),
        finish_progress_dialogue.

menu_handle(Win, edit, Component) :-
	(Component is_class_of_sort box; Component is_class_of_sort line),
	get_edit_model(Win, _Model, Node),
	event:assert(instant_link(Component)),
	(Node = [_,_], !,
	    get_original_click(Xpt, Ypt),
	    event:click(Xpt, Ypt, 0);
	 event:click_on(_, Node, 0)),
	event:unclick,
	(Component is_primitive,
	    Component is_class_of_sort box, !;
	 event:assert(instant_link(Component))).
/*
menu_handle(Win, edit, Component) :-
	get_edit_model(Win, Model, Tgt),
	((Component = compartment, find_type(Tgt, cloud), !,
	        event:cloud_to_comp(Tgt);
	  Component is_primitive,
	  Component is_class_of_sort box, !,
	        event:insert(Win, Model, Tgt, Component)),
	    finish_move(Model, 1);
	(Component = submodel,
	    Tgt = [Xpt, Ypt], !,
	    advance_phase_to(action_choice);
	    (Tgt = [Xpt, Ypt], !,
	        set_current_coords(Xpt, Ypt),
	        event:make_terminator(Component, Model, StartPt),
	        nonvar(StartPt);
	    StartPt = Tgt),
	    event:do_linear(Component, StartPt)),
	    advance_phase_to(targetting),
	    event:assert(instant_link(Component))).

Delete the selection */
menu_handle(Win, edit, reroute) :-
        start_progress_dialogue(Win),
	reassure_user("Reroute in progress"),
	get_edit_model(Win, Model, _),
	/* Get selected links top-down, flows first */
	(setof(Rerouter, (contains(Model, Rerouter),
			    Rerouter is_of_sort line,
			    event:doomed(Rerouter)), Rerouters), !,
	    reroute_sections(Rerouters);
	true),
	finish_move(Model, 0),
	remove_old_incomplete,
	finish_progress_dialogue.

menu_handle(Win, edit, snap) :-
	get_edit_model(Win, Model, _),
	event:retract(grid_pitch_is(Old)),
	event:assert(grid_pitch_is(15)),
	event:resnap(Model, 1),
	event:retract(grid_pitch_is(15)),
	event:assert(grid_pitch_is(Old)),
	menu_handle(Win, edit, reroute).

menu_handle(Win, edit, delete) :-
        start_progress_dialogue(Win),
	reassure_user("Delete in progress"),
	get_edit_model(Win, Model, _),
	event:delete_net(Model),
	finish_move(Model, 1),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, CutOrCopy) :-
	(CutOrCopy = cut,
	    Msg = "Cut in progress";
	CutOrCopy = copy,
	    Msg = "Copy in progress"),
        start_progress_dialogue(Win),
	reassure_user(Msg),
	get_edit_model(Win, Model, _),

	/* Old version: took too long
	New version: first, find the innermost submodel with the whole
	selection in it */
%	assert(suspend_display),
	/* invert_seln_in(Model),
	event:delete_net(Model),


	Now delete unselected submodels containing selected components?
	Why not just select them...

	(contains(Innermost, Bit),
	    \+ Bit = Innermost,
	    find_type(Bit, submodel),
	    \+ member(Bit, SelnList),
	    contains(Bit, SelnBit),
	    member(SelnBit, SelnList),
	    
		      
	and unselected links across
	selected submodels */
	
	/* OK, now I just have the originally selected bit left -- save it */
	use_pref_dir(Dir),
	append_atoms(Dir, '/clipboard.pl', CopyFile),
	output:date_is(Date),
	save_isolated(CopyFile, Model, Date, yes),
	/* restart_move will put the rest of the model back but it will
	not be selected, so list the nodes and select them after the rest is
	added so any external links and ghosts come out right
	(setof(Bit, (contains(Model, Bit), Bit is_of_sort box, \+ Bit = Model),
	      SelBits), !;
	SelBits = []), */
%	restart_move,
%	all(event, do_colours, [build(SelnList), unify(on)]),
%	retract(suspend_display),

	/* Restore original selection as we may have added submodels */
	(CutOrCopy = cut,
	    event:delete_net(Model),
	    finish_move(Model, 1);
	CutOrCopy = copy),
	finish_progress_dialogue.

menu_handle(Win, edit, paste) :-
	get_edit_model(Win, Model, Pt),
	use_pref_dir(Dir),
	append_atoms(Dir, '/clipboard.pl', CopyFile),
	stick_model_in(Win, Model, CopyFile, insert(Pt)),
	event:set_selection_abilities(Model).
	
menu_handle(Win, edit, selall) :-
        start_progress_dialogue(Win),
	reassure_user("Selecting whole model"),
	get_edit_model(Win, Model, _),
	select_all_in(Model, seln),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, unselall) :-
        start_progress_dialogue(Win),
	reassure_user("Unselecting whole model"),
	get_edit_model(Win, Model, _),
	select_all_in(Model, base),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, invsel) :-
        start_progress_dialogue(Win),
	reassure_user("Inverting selection"),
	get_edit_model(Win, Model, _),
	invert_seln_in(Model),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, properties) :-
	get_edit_model(Win, Model, Tgt),
	(Tgt = [_,_], !,
	    /* background or edit menu selection */
	    (setof(PossTgt,
		   (contains(Model, PossTgt),
		       \+ PossTgt = Model,
		       get_highlit_obj(0, PossTgt),
		       PossTgt is_of_sort box),
		   [Target | _]), !;
		setof(PossTgt,
		   (contains(Model, PossTgt),
		       get_highlit_obj(1, PossTgt),
		       PossTgt is_of_sort line),
		   [Target | _]), !;
		Target = Model);
	    Target = Tgt),
	(find_type(Target, submodel), !,
	    set_properties(Win, Target);
	event:doubleclick_on(Target), !;
	    true).

menu_handle(Win, edit, Action) :-
	member(Action, [flip_v, flip_h]),
	Win shows_model Node_name,
	(flip_innards(Node_name, Action);
	event:make_links_follow(Node_name)),
	(OtherWin shows_model Node_name,
		redraw_window(OtherWin),
		fail;
	redisplay(Node_name)),
	finish_move(Node_name, 0).

menu_handle(Win, edit, set_interface) :-
	Win shows_model Submodel,
	contains(Model, Submodel),
	is_toplevel(Model),
	get_import_file('plugplay.isf', Model, SpecFile),
	open_native(SpecFile, read, Stream),
	read(Stream, interface_spec_for(SubmodelName, _)),
	caption_for(Submodel, OldName),
	(OldName = SubmodelName, !;
	sicstus_format_to_chars("The interface specification you have chosen is for a submodel named ~a, whereas the current submodel is named ~a. Do you want the submodel renamed?", [SubmodelName, OldName], WrongNameStr),
	    do_dialogue("Submodel name mismatch", warning, WrongNameStr,
			yesnocancel, Choice),
	    (Choice = yes,
		add_parameter(Submodel, 0, name, SubmodelName),
		update_captions(Submodel);
	    Choice = no)),
	read(Stream, ReferenceLine),
	(ReferenceLine = references(References),
	    load_references(Submodel, References);
	ReferenceLine = no_references),
	(load_submodel_interface(Stream, Submodel, _, _),
	    event:make_links_follow(Submodel),
%	    event:tweak_link_connections(Submodel, [0,0], l, [0,0,1,1]),
	    finish_move(Submodel, 1);
	close(Stream),
	    restart_move,
	    (FarWin shows_model Submodel,
		redraw_window(FarWin),
		fail;
	    redisplay(Submodel))).
	
	 
menu_handle(Win, window, NastyAtom) :-
	name(NastyAtom, NastyStr),
	(get_term(NastyStr, detail(Parameter,Level,Redraw), []),
	    set_display_depth(Win, Parameter, Level),
	    (Redraw=0, !; redraw_window(Win));
	 get_term(NastyStr, halo(Way,Depth), []),
	    set_halo(Win, Way, Depth),
	    update_halo(Win)).

menu_handle(_, _, _).

get_edit_model(Win, Comp, Pt) :-
	(event:menu_submodel_is(Comp, Pt), !;
	Win shows_model Comp).

select_all_in(Model, Way) :-
	Way = base, is_toplevel(Model), !,
	    (event:new_selection(Model);
		event:set_selection_abilities(Model));
	contains(Model, Bit),
	    Bit is_of_sort box,
	    appears(Bit),
	    \+ event:at_def_con(Bit, Way),
	    \+ Bit = Model,
	    (Way = seln,
		event:do_colours(Bit, on);
	    Way = base,
		get_highlit_obj(0, Bit),
		event:do_colours(Bit, off)),
	    fail;
	event:set_selection_abilities(Model).

invert_seln_in(Model) :-
	(setof(Bit, 
	      (contains(Model, Bit),
		 \+ Bit = Model,
		 \+ (get_highlit_obj(N, Bit),
			normalize(Bit),
			N = 0;
		    \+ (appears(Bit), Bit is_of_sort box))),
	      NewSel),
	member(Node, NewSel),
	    event:do_colours(Node, on),
	    fail;
	event:set_selection_abilities(Model)).
/*
find_innermost_selection_holder([Comp | Rest], Innermost, TempSels) :-
	find_all_comps(Model, Comp),
	(Rest = [], !,
	    Innermost = Model,
	    TempSels = [];
	find_innermost_selection_holder(Rest, HoldsRest, MoreTempSels),
	    contains(Innermost, HoldsRest, Adds),
	    contains(Innermost, Model, MoreAdds), !,
	    append(Adds, MoreAdds, AllAdds),
	    (setof(TempSel, (member(TempSel, AllAdds),
				\+ event:doomed(TempSel)), NewSels), !,
		all(draw, set_highlit_obj, [unify(0), build(NewSels)]),
		merge_lists(NewSels, MoreTempSels, TempSels);
	    TempSels = MoreTempSels)).
*/
find_space_for([L, T, R, B], Model, Including, DefPt, [TargetX, TargetY]) :-
	get_shape(Model, internal_extent, [ML, MT, MR, MB]),
	(nonvar(DefPt), !; DX is (L+R)/2, DY is (T+B)/2),
	DefPt = [DX, DY],

	MinOffX is ML - L,
	MinOffY is MT - T,
	MaxOffX is MR - R,
	MaxOffY is MB - B,

	/* These two are the offset to get it to nearest feasible posn...
	cant believe this has to be so complicated */
	(event:grid_pitch_is(Spcs), !,
	    MinGridX is ceiling(MinOffX/Spcs),
	    MaxGridX is floor(MaxOffX/Spcs),
	    MaxGridX >= MinGridX,
	    BestX is Spcs*max(MinGridX, min(MaxGridX,
					    round((DX-(L+R)/2)/Spcs))),
	    MinGridY is ceiling(MinOffY/Spcs),
	    MaxGridY is floor(MaxOffY/Spcs),
	    MaxGridY >= MinGridY,
	    BestY is Spcs*max(MinGridY, min(MaxGridY,
					    round((DY-(T+B)/2)/Spcs)));
	BestX is max(MinOffX, min(MaxOffX, DX-(L+R)/2)),
	    BestY is max(MinOffY, min(MaxOffY, DY-(T+B)/2))),

	MinXTrim is BestX-MinOffX,
	MaxXTrim is MaxOffX-BestX,
	MinYTrim is BestY-MinOffY,
	MaxYTrim is MaxOffY-BestY,
	HDispMax is max(MinXTrim,MaxXTrim),
	VDispMax is max(MinYTrim,MaxYTrim),
	MaxDist is max(HDispMax, VDispMax),
	
	(event:grid_pitch_is(Spcs), !; Spcs = 10),
	count_to(0, MaxDist, Spcs, Distance),
	count_to(0, Distance, Spcs, Range),
	((Distance<MinXTrim, TargetX is BestX-Distance;
	  Distance<MaxXTrim, TargetX is BestX+Distance),
	(Range<MinYTrim, TargetY is BestY-Range;
	    Range<MaxYTrim, TargetY is BestY+Range);
	(Distance<MinYTrim, TargetY is BestY-Distance;
	    Distance<MaxYTrim, TargetY is BestY+Distance),
	(Range<MinXTrim, TargetX is BestX-Range;
	    Range<MaxXTrim, TargetX is BestX+Range)),

	/* These make sure the rectangle fits in the model so now we only need
	to check for interference */
	NewL is L+TargetX, NewT is T+TargetY,
	NewR is R+TargetX, NewB is B+TargetY,
	\+ (get_overlaps(Model, [[NewL, NewT, NewR, NewB]], Obstacle),
	       \+ member(Obstacle, Including)).
	
reroute_sections(Rerouters) :-
	Rerouters = [];
	member(Type, [relation, flow, squirt, influence]),
	full_section(Rerouters, Type, [Go | Rest], Remains),
	suffix([Stop], [Go | Rest]),
	(m_class:Go follows Start; m_class:Go is_connector from Start to _),
	(m_class:End follows Stop; event:local_ends(Stop, _, End)),
	event:draw_line_to(Start, Type, End),
	event:reuse_route(Type, Stop),
	reroute_sections(Remains).

full_section(Rerouters, Type, [Start | Rest], Remains) :-
	select(Start, Rerouters, Left),
	find_type(Start, Type),
	\+ (m_class:Start follows Before, member(Before, Left)),
	continuation(Left, Start, Rest, Remains).

continuation(Rerouters, Start, Rest, Remains) :-
	clear_shape(Start, course), fail;
	m_class:Next follows Start,
	select(Next, Rerouters, Left), !,
	continuation(Left, Next, More, Remains),
	Rest = [Next | More];
	Rest = [],
	Remains = Rerouters.

/*
display(1,10,submodel,[S,Full_submodel_label],_):-
   label(S,Label),
   comment(S,Comment),
   description(S,Descr),
   submodel_type(S,Type),
      nl,+'h2 class="submodel"',
      write('<a name='),write(S),write('>'),
      (  S=top,write('Top level');
         write('Submodel '),write(Full_submodel_label)),
      -a,-h2,
      +'p class="submodeltype"', write_submodel_type(Label,Type),-p,
      write_description(Descr),
      write_comment(Comment).
*/	
display_submodels(_,[]).
display_submodels(Isub,[Submodel|Submodels]):-
	abs_path_name(Submodel, root, AbsPath), 
	% remove the model file name prefix from submodel paths
	( name(AbsPath, AbsStr),
	    append("/", PathStr, After),
	    suffix(After, AbsStr),
	    name(Path, PathStr);
	  Path=AbsPath 
	),
	(get_av_pair(Submodel, 0, desc, SubmodelDesc)  ; 
		\+ get_av_pair(Submodel, 0, desc, SubmodelDesc), SubmodelDesc = null),
	(get_av_pair(Submodel, 0, comment, SubmodelComment)  ; 
		\+ get_av_pair(Submodel, 0, comment, SubmodelComment), SubmodelComment = null),
	(get_av_pair(Submodel, 0, step, TimeStepIndex)  ; 
		\+ get_av_pair(Submodel, 0, step, TimeStepIndex), TimeStepIndex = null),
	(get_av_pair(Submodel, 0, enum_types, EnumTypes)  ; 
		\+ get_av_pair(Submodel, 0, enum_types, EnumTypes), EnumTypes = null),
        submodel_type(Submodel,SMType),
	tk_equationlisting_addsubmodel(Isub,Path,SubmodelDesc,SubmodelComment,TimeStepIndex,EnumTypes,SMType),
	mysetof((Entry,MinMax,Description,Comment,InFlows,OutFlows),write_eqn_term(Submodel,Entry,MinMax,Description,Comment,InFlows,OutFlows),Entries),
	display_entries(Isub,1,Entries),
	Isub1 is Isub+1,
	display_submodels(Isub1,Submodels).

display_entries(_,_,[]).
display_entries(Isub,Ivar,[(where(VarType:VarLabel=Expression, WhereList),MinMax,Description,Comment,InFlows,OutFlow)|Entries]):-
	tk_equationlisting_addvariable(Isub,Ivar,VarType,VarLabel,Expression,WhereList, MinMax, Description, Comment,InFlows,OutFlow),
	Ivar1 is Ivar+1,
	display_entries(Isub,Ivar1,Entries).

submodelpath(SubmodelNode, Path) :-
   	abs_path_name(SubmodelNode, root, AbsPath), 
	% remove the model file name prefix from submodel paths
	( name(AbsPath, AbsStr),
	    append("/", PathStr, After),
	    suffix(After, AbsStr),
	    name(Path, PathStr);
	  Path=AbsPath 
	).

submodel_type(Submodel,Type):-
   connects(Link1, Submodel1, Submodel),
   connects(Link2, Submodel2, Submodel),
   Link1 has_type relation,
   Link2 has_type relation,
   Submodel1 \== Submodel2,
   Link1 has_attribute name of Role1,
   Link2 has_attribute name of Role2,
   submodelpath(Submodel, Submodelpath),
   submodelpath(Submodel1, Submodelpath1),
   submodelpath(Submodel2, Submodelpath2),
   sicstus_format_to_chars('Submodel  ~w is an association submodel between ~w (~w) and ~w (~w).', 
      [Submodelpath, Submodelpath1,Role1,Submodelpath2,Role2], TypeStr),
   name(Type, TypeStr),!.
submodel_type(Submodel,Type):- 
   connects(Link1, Submodel1, Submodel),
   connects(Link2, Submodel1, Submodel),
   Link1 has_type relation,
   Link2 has_type relation,
   Link1 has_attribute name of Role1,
   Link2 has_attribute name of Role2,
   Link1 \== Link2,
   submodelpath(Submodel, Submodelpath),
   submodelpath(Submodel1, Submodelpath1),
   sicstus_format_to_chars(
      'Submodel  ~w is an association submodel between ~w and itself with roles ~w and ~w.', 
      [Submodelpath, Submodelpath1,Role1,Role2], TypeStr),
   name(Type, TypeStr),!.
submodel_type(Submodel,Type):-
   connects(Link1, Submodel1, Submodel),
   Link1 has_type relation,
   Link1 has_attribute name of Role,
   submodelpath(Submodel, Submodelpath),
   submodelpath(Submodel1, Submodelpath1),
   sicstus_format_to_chars(
      'Submodel  ~w is a ~w satellite submodel of ~w.', 
      [Submodelpath,Role, Submodelpath1], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,Type):-
   by_record(Submodel),
   submodelpath(Submodel, Submodelpath),
   sicstus_format_to_chars(
      'Submodel  ~w is a membership by record submodel.', 
      [Submodelpath], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,Type):-
   is_population(Submodel),
   is_conditional(Submodel),
   submodelpath(Submodel, Submodelpath),
   sicstus_format_to_chars(
      'Submodel  ~w is a conditional population submodel.', 
      [Submodelpath], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,Type):-
   is_population(Submodel),
   submodelpath(Submodel, Submodelpath),
   sicstus_format_to_chars(
      'Submodel  ~w is a population submodel.', 
      [Submodelpath], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,Type):-
   is_conditional(Submodel),
   get_node_size(Submodel, Dimensions),
   submodelpath(Submodel, Submodelpath),
   sicstus_format_to_chars(
      'Submodel  ~w is a conditional fixed membership submodel of dimensions ~w.', 
      [Submodelpath,Dimensions], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,Type):-
   is_conditional(Submodel),
   get_node_size(Submodel, []),
   submodelpath(Submodel, Submodelpath),
   sicstus_format_to_chars(
      'Submodel  ~w is a conditional submodel.', 
      [Submodelpath], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,''):-
   get_all_dims(Submodel, '[]').

submodel_type(Submodel,Type):-
   get_all_dims(Submodel, Dimensions),
   Dimensions \== [],
   submodelpath(Submodel, Submodelpath),
   sicstus_format_to_chars(
      'Submodel  ~w is a fixed_membership submodel with dimensions ~w.', 
      [Submodelpath,Dimensions], TypeStr),
   name(Type, TypeStr),!.

submodel_type(Submodel,Type):-
   get_all_dims(Submodel, Type).
%submodel_type(Submodel,simple_default).
%submodel_type(Submodel,simple).

mysetof(A,B,C):-
	setof(A,B,C),!.
mysetof(_,_,[]).

% spec insead value? Only if present and not a string
write_eqn_term(Submodel, Entry, MinMax, Description, Comment, InFlows, OutFlows) :-
	find_all_comps(Submodel, Component),	
	(find_type(Component, function),
	    implicit_function(VisNode, Component),
	    pick_equation(Component, Eqn),
	    \+ Eqn = ''; 
	find_type(Component, variable),
	    VisNode = Component,
	    (is_parameter(Component, 2), Eqn = 'Fixed parameter';
		is_parameter(Component, 1), Eqn = 'Variable parameter')),
	get_desc_and_comment(VisNode, Description, Comment, null),
	find_type(VisNode, CompType),
	caption_for(VisNode, Dest),
	get_input_info(Component, Links),
	get_ppairs(Links, PPairs),
	((CompType = compartment, 
	 get_flows(VisNode, out, OutFlows), 
	 get_flows(VisNode, in, InFlows) 
	);
	(\+ CompType = compartment, 
	 InFlows = null, 
	 OutFlows = null
	)),
	((PPairs = [],
		Entry = (where((CompType:Dest=Eqn), [null]))); % Bob's change
	(PPairs = [_ | _],
		Entry = (where((CompType:Dest=Eqn), PPairs)))),
	make_min_max_line(Component, MinMax).

make_min_max_line(Component, MinMax) :-
	(get_av_pair(Component, 0, min_val, MinVal), !,
	    append_atoms('Minimum = ', MinVal, Min);
	Min = none),
	(get_av_pair(Component, 0, max_val, MaxVal), !,
	    append_atoms('Maximum = ', MaxVal, Max);
	Max = none),
	([Min, Max] = [none, none], !,
	    MinMax = '';
	 select(none, [Min, Max], [MinMax]), !;
	 append_atoms([Min, ', ', Max], MinMax)).
	
get_flows(CompartmentNode, Direction, Names) :-
	findall(Caption,(instance:flows(Direction, CompartmentNode, Arc),caption_for(Arc,Caption)), Names).

get_ppairs([],[]).
/* Only include a "...where P=V" entry where P is not the default parameter name for V. */
get_ppairs([input_link(_, Source, Param, _, _) | R1], Terms) :-
	get_ppairs(R1, R2),
	(m_update:add_brackets(Source,_, Param), !,
	    Terms = R2;
	Terms = [Param = Source | R2]).

set_properties(Wid, Model) :-
	get_disag_params(Model, P_list),
	do_disag_dialog(Wid, Model, P_list, New_P_list),
	(New_P_list = [], !; /* dialogue was cancelled */
	New_P_list = [NewColour, NewImage, NewImgPos, NewNature, NewFatness,
		      NewCount, NewStep, NewDesc, NewComment, NewFix, NewHide,
		      NewSeparate, NewProc, NewInc, NewLibs, NewEnumSpecs],
	    P_list = [Colour, Image, ImgPos, Nature, Fatness, Count, _Step,
		      _D, _C, _E, _Proc, _Inc, _Libs, _Fix, Hide, Separate],
	    (NewColour = clear, !,
		add_parameter(Model, 0, fill_colour, '');
	    NewColour = Colour, !;
	    add_parameter(Model, 0, fill_colour, NewColour)),
	    (NewImage = Image, !;
	    add_parameter(Model, 0, fill_image, NewImage)),
	    add_parameter(Model, 0, image_posn, NewImgPos),
	    (NewStep = 'Default', !,
		add_parameter(Model, 0, step, '');
	    add_parameter(Model, 0, step, NewStep)),
	    add_parameter(Model, 0, desc, NewDesc),
	    add_parameter(Model, 0, comment, NewComment),
	    (NewFix = 'Default', !,
		add_parameter(Model, 0, eqn_units, '');
	    add_parameter(Model, 0, eqn_units, NewFix)),	
	    add_parameter(Model, 0, separate, NewSeparate),
	    /* fix quirk in new strings_to_atoms */
	    (NewLibs = '', !, RealNewLibs = []; RealNewLibs= NewLibs),
	    add_parameter(Model, 0, external_code,
		  [procedure=NewProc,include=NewInc,libraries=RealNewLibs]),
	    (NewEnumSpecs = '', !,
	        NewEnumTypes = [];
	    all(menu, separate_type_from_mems,
		[build(NewEnumSpecs), build(NewEnumTypes)])),
	    add_parameter(Model, 0, enum_types, NewEnumTypes),
	    (Hide = 0, !; clear_shape(Model, hide_contents)),
	    (NewHide = 0, !; set_shape(Model, hide_contents, NewHide)),
	    (NewNature = generated,
		name(NewCount, CountStr),
		append([91 | CountStr], [93], ListStr),
		get_term(ListStr, UseCount, Error),
		(\+ Error = [],
		    append("Invalid dimension string -- ", Error, Wibble);
/*		get_actual_sizes(UseCount, Sizes), */
		on_exception(WibbleAtom,
			     get_actual_sizes(Model, UseCount, Sizes, _,_),
			     name(WibbleAtom, Wibble)),
		    (nonvar(Wibble);
		    member(Dodgy, Sizes),
			\+ (integer(Dodgy), Dodgy > 1),
			sicstus_format_to_chars("~w is not a valid dimension -- for a simple submodel, leave dimension field empty", [Dodgy], Wibble);
		    Spec = [count=UseCount]);
		Wibble = "Could not convert dimensions to numbers");
	    member(NewNature, [population, records]),
		Spec = [type=NewNature]),
	    (nonvar(Spec),
		add_parameter(Model, 0, multiplication_spec, Spec);
	    do_dialogue("Problem with dimensions", error, Wibble, ok, _)),
	    
	    ((abs(NewFatness - Fatness) =< 0.005;
	      Fatness > 1, NewFatness > 0.995), !;
	    FatFactor is Fatness/NewFatness,
		FatTrans = [0,0, FatFactor, FatFactor],
		get_shape(Model, internal_extent, Extent),
		translate(Extent, FatTrans, NewExtent),
		change_shape(Model, internal_extent, NewExtent),
%		adjust_toplevel_windows(Model, NewExtent),
		refatten_toplevels(Model, FatFactor),
		event:move_boxes(Model, FatTrans),
		event:resnap(Model, 0),
		(member(RerouteType, [flow, influence]),
		find_all_comps(Model, Linkage),
		appears(Linkage),
		find_type(Linkage, RerouteType),
		update_link_route(Linkage),
		fail; true)),

	    /* Changes in fatness require redrawing submodel's
	    toplevel windows; this plus nature, count and visibility require
	    redrawing it in other windows */
	    (([NewColour, NewImage, NewImgPos, NewNature] =
	     [Colour, Image, ImgPos, Nature],
	      FatFactor = 1, UseCount = Count, NewHide = Hide), !;
	    NewHide = Hide, !,
		(\+ FatFactor = 1,
		    find_all_comps(Model, TopComp),
		    redisplay_border(TopComp),
		    fail;
		redisplay_border(Model));
	    redisplay(Model)),

	    (Separate = NewSeparate, !;
		find_all_comps(Parent, Model),
		add_parameter(Parent, 1, c_new, 0)),
	    
	    /* this is quick so do it anyway */
	    (contains(Model, Submodel),
		_Window shows_model Submodel,
		update_captions(Submodel),
		fail;
	    NewNature = Nature, UseCount = Count, !;
		event:spread_colour(Model, yes)),
	    finish_move(Model, 1)).

separate_type_from_mems([H | T], H-T).

flip_innards(Node_name, Action) :-
	get_shape(Node_name, internal_extent, [IL, IT, IR, IB]),
	(Action = flip_h,
		MidW is IL+IR,
		Trans = [MidW, 0, -1, 1];
	Action = flip_v,
		MidH is IT+IB,
		Trans = [0, MidH, 1, -1]),
	find_all_comps(Node_name, Thing),
	get_shape(Thing, Whatever, Wherever),
	(Whatever = internal_extent,
		(flip_innards(Thing, Action); 
		Win shows_model Thing,
			redraw_window(Win),
			fail);
	((Whatever = bounding_box; Whatever = bowtie),
			translate(Wherever, Trans, [L, T, R, B]),
			(Action = flip_h,
				New_wherever = [R, T, L, B];
			Action = flip_v,
				New_wherever = [L, B, R, T]);
		(Whatever = course; Whatever = centre),
			translate(Wherever, Trans, New_wherever)),
		change_shape(Thing, Whatever, New_wherever),
		fail).

rebuild_code(Lang, Node, ProgFileDir) :-
	(on_exception(Whoops, compile(Lang, Node, ProgFileDir), true), !;
	    Whoops = compilation_failed),
	finish_progress_dialogue,
	output:safe_tcl_eval([set, log, exited_exception], _),
	(Whoops = yes;
            scrub_run(Node, 0),
	    show_error(Node, Whoops),
	    fail).

show_error(Model, Lossage) :-
	Lossage = compilation_failed, !;
	/* if this happens the user will have seen the error already */
	(Lossage = open_model_failed(MimeFail, PrologFail), !,
	    sicstus_format_to_chars("Simile could not open this file as a model. It could not be read as a MIME because: ~w. It could not be read as a model description because: ~s.", [MimeFail, PrologFail], Text),
	    Fault = user;
	Lossage = instantiation_failure(Node), !,
	    caption_for(Node, Capt),
	    sicstus_format_to_chars("There was a problem converting the model variable ~w (caption: ~w) into a program variable.", [Node, Capt], Text),
	    Fault = system;
	Lossage = bad_parameter(Node, Sub), !,
	    caption_for(Node, Capt),
	    sicstus_format_to_chars("The model variable ~w (caption: ~w) has an equation containing parameter ~w. This could not be matched with any inputs to the variable.", [Node, Capt, Sub], Text),
	    Fault = system;
	Lossage = no_phases, !,
	    Text = "This model cannot be executed because it does not have any time steps.",
	    Fault = user;
	Lossage = role_between_execs(NodeCap, SrcCap, RelCap), !,
	    sicstus_format_to_chars("This model cannot be built because it contains ~a, which has an influence from ~a (in a different executable module) which it refers to by the role ~a. References to roles currently do not work between separate executables.", [NodeCap, SrcCap, RelCap], Text),
	    Fault = user;
	Lossage = flow_splits_at_border(BadArc, BadComp, BadModel), !,
	    sicstus_format_to_chars("Flow ~a cannot connect to compartment ~a because its value would be split where it crosses the border of submodel ~a",
				    [BadArc, BadComp, BadModel], Text),
	    Fault = user;
	Lossage = flow_crosses_dll_boundary(BadArc, BadComp, BadModel), !,
	    sicstus_format_to_chars("Flow ~a cannot connect to compartment ~a because it crosses the border of submodel ~a, which is built as a separate executable module. A flow's bowtie must currently be in the same executable module as the compartments to which the flow connects.",
				    [BadArc, BadComp, BadModel], Text),
	    Fault = user;
	Lossage = flow_comp_dims_mismatch(BadArc, BadComp, AllDims, NodeDims), !,
	    sicstus_format_to_chars("Flow ~a cannot be connected to compartment ~a because the flow has dimensions ~w which cannot be matched with those of the compartment, which are ~w", [BadArc, BadComp, AllDims, NodeDims], Text),
	    Fault = user;
	Lossage = no_compiler, !,
	    Text = "To run this model as a c++ program you need to select a c++ compiler to use. Please consult the documentation for help installing a c++ compiler.",
	    Fault = user;
	Lossage = unspecified(OuterText, RedText), !,
	    sicstus_format_to_chars("Model ~w cannot be executed because it contains component ~w (shown in red), which has not been fully specified.",
				    [OuterText, RedText], Text),
	    Fault = user;
	Lossage = missing_function(LostFn, WhereSought), !,
	    sicstus_format_to_chars("This model cannot be built because it contains the user-defined function ~a, which should have a definition in the file ~a, but this file is missing.", [LostFn, WhereSought], Text),
	    Fault = user;
	Lossage = link_inconsistency(Pair), !,
	    sicstus_format_to_chars("This model cannot be executed because it contains an inconsistent link equivalence ~w.", [Pair], Text),
	    Fault = system;
	Lossage = no_defining_param(Capt), !,
	    sicstus_format_to_chars("Model ~w cannot be executed because its instance count must be set to the number of data records provided for its fixed parameters -- and it has no fixed parameters.", [Capt], Text),
	    Fault = user;
	Lossage = circular_evaluation(CircSet), !,
	    sicstus_format_to_chars("This model cannot be executed because it contains the following circular set(s) of function evaluations: ~w",
				   [CircSet], Text),
	    Fault = user;
	Lossage = mixed_phase_loop(DefCon, LoopMem, DefPh, MemPh), !,
	    sicstus_format_to_chars("This model contains the target ~w, which depends on its own values from previous iterations of a program loop. However ~w must be calculated in phase ~d, but the cycle of evaluations includes target ~w, which must be calculated in phase ~d and therefore cannot be put in the same program loop.", [DefCon, DefCon, DefPh, LoopMem, MemPh], Text),
	    Fault = user;
	Lossage = condition_outside_loop(LoopStart, Xefct), !,
	    sicstus_format_to_chars("This model contains the target ~w which depends on its own values from previous iterations of a program loop. However the cycle of evaluations includes target ~w, which is calculated outside the innermost program loop containing target ~w", [LoopStart, Xefct, LoopStart], Text),
	    Fault = user;
	Lossage = ordering_failure(Tail), !,
	    sicstus_format_to_chars("Failed to put this instruction into ordered sequence, despite it not seeming to depend on anything: ~w", [Tail], Text),
	    Fault = system;
	Lossage = bad_role(Lost), !,
	    sicstus_format_to_chars("This model cannot be built because submodel ~a has a role arrow connecting it to a submodel in a separate executable module.", [Lost], Text),
	    Fault = user;
	Lossage = bad_instance_lookup(Node), !,
	    find_all_comps(Submodel, Node),
	    caption_for(Submodel, Capt),
	    sicstus_format_to_chars("This model includes an attempt to use base instance lookup for the association submodel \"~a\". This cannot be done because index(1) in this submodel is the index of a variable-membership submodel other than itself.", [Capt], Text),
	    Fault = user;
	Lossage = preprocessor_failure(Target), !,
	    sicstus_format_to_chars("Failed to substitute macro functions and references in ~a", [Target], text),
	    Fault = system;
	Lossage = conversion_failure(Comp, Problem), !,
	    find_all_comps(Parent, Comp),
	    abs_path_name(Parent, root, Capt),
	    caption_for(Comp, Target),
	    sicstus_format_to_chars("Failed to convert ~a (in submodel ~a) into a program instruction. This may be because Simile earlier failed to detect when a change elsewhere in the model made the equation for this variable inconsistent, in which case editing this variable again will make the model runnable. ",
				    [Target, Capt], Amble),
	    dialogue:decode_error(Problem, Explain),
	    append([Amble, "The parser gave this message: ", Explain], Text),
	    Fault = user;
	Lossage = cannot_make_context(Target, BaseContext, BackSwap), !,
	    sicstus_format_to_chars("Simile cannot work out which combination of program loops to put the instruction ~a into. Trying to modify ~w with ~w.",
				    [Target, BaseContext, BackSwap], Text),
	    Fault = system;
	Lossage = cannot_convert_to_code(Clause), !,
	    sicstus_format_to_chars("This model generated the instruction ~w in the internal language, which could not be converted into your chosen target language.", [Clause], Text),
	    Fault = system;
	Lossage = extra_graph(Expr, XAxis, GraphD), !,
	    sicstus_format_to_chars("While making an assignment for equation ~w, an extra graph function of ~w was found, but the equation already had one graph with data ~w.", [Expr, XAxis, GraphD], Text),
	    Fault = user;
	sicstus_format_to_chars("An exception occurred while building this model. It generated this message: ~w.", [Lossage], Text),
	    Fault = system),
	text:escape_curlies(Text, SafeText),
	ProbDesc = ['BuildProblem', br('Problem with model'),
		    warning, br(chars(SafeText)), execution],
	(Fault = user, !, FullProb = ProbDesc;
	(get_model_file(Model, Name), !; Name = unsaved),
	    (backup:autosave_file_is(Model, AutoName), !; AutoName = none),
	    append(ProbDesc, [br(Name), br(AutoName)], FullProb)),
	output:safe_tcl_eval(FullProb, _).

/*
Unused because only desktop is runnable anyway
not_runnable(Model) :-
	reassure_user("Checking model is self-contained"), 
	get_exogenous_node(Model, Target),
		caption_for(Model, OuterText),
		get_host(Target, VisTarget),
		caption_for(VisTarget, InnerText),
		sicstus_format_to_chars("Cannot run model ~w because one of the inputs \c
				for ~w comes from ouside this model, therefore its value \c
				cannot be calculated.", [OuterText, InnerText], Message),

		do_dialogue("Cannot run model", error, Message, ok, _);
		fail.
*/

check_deletable(Win, Parent) :-
	(\+ find_all_comps(Parent, _), !;
	    get_save_status(Win, safe), !;
	    ok_to_delete(Win, Parent)).

close_exec(Parent) :-
	scrub_run(Parent, 1),
	kill_helpers(Parent),
	output:safe_tcl_eval(['KillInterpFor', Parent], _),
	scrub_autosave(Parent).
	
remove_model(Win, Parent) :-
	(is_toplevel(Parent), !,
	    close_exec(Parent),
	    superfast_delete(Parent),
	    add_parameter(Parent, 0, step, ''),
	    add_parameter(Parent, 0, multiplication_spec, ''),
	    add_parameter(Parent, 0, comment, ''),
	    add_parameter(Parent, 0, fill_colour, ''),
	    add_parameter(Parent, 0, fill_image, ''),
	    redraw_window(Win);
	start_progress_dialogue(Win),
	reassure_user("Creating new inputs for values from deleted submodel"),
	cutoff(Parent);
	(contains(Parent, Junk),
	    \+ Junk = Parent,
	    off(Junk),
	    fail;
	superfast_delete(Parent),
	    reassure_user("Updating screen representation of components affected by this delete"),
	    event:spread_colour(Parent, no),
	    finish_progress_dialogue,
	    redisplay(Parent))),
	clear_model_file(Parent),
	use_temp_dir(LocalDir),
	abs_path_name(Parent, root, DeleteDir),
	output:trim_tree(LocalDir, DeleteDir).

cutoff(Parent) :-
	find_all_comps(Parent, Child),
	sever_links(Child, Parent),
	fail.
		
cutout(Parent, SelnOnly) :-
	find_all_links(Parent, Child),
	\+ (SelnOnly = yes, \+ event:doomed(Child)),
	sever_links(Child, Parent),
	fail.
		
change_size(TopNode, Type) :-
	contains(TopNode, Obj),
	draw_style_for(Obj, Type),
	event:make_links_follow(Obj),
	redisplay_border(Obj),
	fail.

change_size(_,_).

off_window(Win, ExitIfKilled) :-
	Win shows_model Model,
	(is_toplevel(Model), !,
	    check_deletable(Win, Model),
	    (ExitIfKilled = 1, !,
		/* do not bother to delete model if closing down afterwards --
		just do the minimum to exit cleanly */
		close_exec(Model),
		delete_window(Win);
	    output:tk_certain_death(Win));
/* ...which calls the class destructor, which calls rule below. */
	delete_window(Win)).

certain_death_node(Win) :-
	Win shows_model Model,
	start_progress_dialogue(Win),
	remove_model(Win, Model),
	fast_delete(Model),
	scrap_move,
	finish_progress_dialogue.
	
not_last_toplevel(Win) :-
	OtherWin shows_model Model,
	\+ Win = OtherWin,
	is_toplevel(Model).

kill_everything(Model) :-
	Win shows_model Model,
	is_toplevel(Model),
	(not_last_toplevel(Win),
	    ExitIfKilled = 0;
	 ExitIfKilled = 1), !,
	off_window(Win, ExitIfKilled),
	 kill_everything(_);
	 exit_AME,
       user:wind_up.
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ok_to_delete(Win, Target) :-
	get_default_export_name(Target, ".sml", Handle),
	caption_for(Target, Title),
	sicstus_format_to_chars("The current version of ~a (in ~w) has not been saved. Save it now?", [Handle, Title], Query),
	do_dialogue("Save changes", question, Query, yesnocancel, Reply),
	(Reply = yes, do_save(Win, Target, false);
	Reply = no).

do_save(Win, Model, New_name) :-
	\+ too_big_for_edn(Model),
	use_temp_dir(Dir),
	abs_path_name(Model, root, Point),
	append_atoms([Dir, '/', Point], SaveDir),
	
        start_progress_dialogue(Win),
	/* Remove any old executables (and make sure dirs exist) */
	save_dlls(Point, Dir, Model, Model, _),

	/* save prolog data */
	append_atoms(SaveDir, '/model.pl', TempFile),
	output:date_is(Date),
	(New_name = seln_only, Select = yes, CanvasModel = none;
	    \+ New_name = seln_only, Select = no, CanvasModel = Model),
	save_isolated(TempFile, Model, Date, Select),
	
	/* Save image backgrounds */
	transfer_images(Model, SaveDir, out),

	/* Save canvas file -- remove selection cos graphics but not state
	are saved */
	select_all_in(Model, base),
	check_save_canvas(SaveDir, CanvasModel, Date),


	/* here is where we get the user to enter the name to save it
	as.  This may be tried multiple times, which is why it is done after
	writing all the saved components to temp file. */

        finish_progress_dialogue, /* Allow file selector to take focus */
	(New_name = false,
	    get_model_file(Model, Name);
	try_save_files(Name)),

	/* Starts dialogue, but if backtracking, finishes again before
	retrying dialogue */
	(start_progress_dialogue(Win);
        finish_progress_dialogue, fail),

	/* Now build the multi-part MIME format save file */
        reassure_user("Creating MIME-format saved file"),
	output:save_file(Model, SaveDir, Name, Select, Oops),

        (   Oops = [];
	    \+ Oops = [],
            do_dialogue("Problem building output file", error, Oops, ok, _),
	    fail),

	/* If that succeeded, mark model as saved */
	(New_name = seln_only;
	set_model_file(Model, Name),
	(is_toplevel(Model), !,
	    get_default_export_name(Model, "", NodeName),
	    add_parameter(Model, 0, name, NodeName),
	    /* copy save dir to new path */
	    abs_path_name(Model, root, NewPoint),
	    (NewPoint = Point, !;
	    append_atoms([Dir, '/', NewPoint], NewSaveDir),
		output:safe_tcl_eval(['file copy -force', br(SaveDir), br(NewSaveDir)],
				     _));
	true),
	update_captions(Model),
	clear_autosave(Model, Name),
	update_ability(Model, save, file, 'Save', 0),
	mark_model_danger(Model, safe)),
        finish_progress_dialogue, !. /* do not finish progress box 2wice */

too_big_for_edn(Model) :-
	state:get_edition_and_limit(Edn, Limit),
	count_functions(Model, N),
	N > Limit,
	sicstus_format_to_chars("This model has ~d equations. This is greater than ~d, so it cannot be saved in the ~a edition.", [N, Limit, Edn], Annoy),
	do_dialogue("Error saving model", error, Annoy, ok, _).

transfer_images(Model, TopDir, Way) :-
	setof(ImageSpec,
	      Submodel^(contains(Model, Submodel),
			get_av_pair(Submodel, 0, fill_image, ImageSpec)),
	      Fillers), !,
	shift_images(TopDir, Fillers, Way);
	true.

	/* Save canvas file */
check_save_canvas(SaveDir, Model, Date) :-
	append_atoms(SaveDir, '/model.cnv', CanvasName),
	(tk_get_pref(saveExtras, 'Canvas file'),
	is_toplevel(Model), !,
	/* might still be useful if not, but would have to do something
	about border nodes which have graphical attributes but aren't on
	the canvas... */
	reassure_user("Saving canvas description"),
	    Win shows_model Model,
	    all(state, get_display_depth, [unify(Win),
		 build([ghost_link, influence, variable, flow, compartment,
		   submodel, caption, sections]), build(CurrentDepths)]),
	    save_canvas(Win, CanvasName, CurrentDepths, Date);
	\+ output:my_file_exists(CanvasName), !;
	output:my_delete_file(CanvasName)).

save_dlls(Point, LocalDir, Top, Model, SaveParent) :-
	(setof(Sub, Part^(find_all_comps(Model, Part),
			 find_type(Part, submodel),
			 save_dlls(Point, LocalDir, Top, Part, Sub)),
		Subs),
	    member(0, Subs),
	LocalNew = 0;
	get_av_pair(Model, 1, c_new, LocalNew);
	LocalNew = ''), !,

	((get_av_pair(Model, 0, separate, 1); Model = Top), !,
	    (Top = Model, !,
		Loc = '';
	    abs_path_name(Model, Top, Loc)),
	    output:shift_dll(Point, LocalDir, Loc, LocalNew),
	    SaveParent = 1;
	SaveParent = LocalNew).
	
/* try_save_files will keep prompting the user for save files each time it is
retried, but fail when the user cancels the request */

try_save_files(Name) :-
	get_save_file(TestName),
	\+ TestName = '',
	(Name = TestName;
	try_save_files(Name)).

save_isolated(Name, Part, Date, SelnOnly) :-
/*	(SelnOnly = yes, !,
	    setof(Seln, (contains(Model, Seln),
			    \+ Seln = Model,
			    get_highlit_obj(0, Seln)), SelnList),
	    find_innermost_selection_holder(SelnList, Part, TempSels);
	Part = Model,
	    TempSels = []),
*/	assert(suspend_display),
	(cutout(Part, SelnOnly);
	ame_save(Name, Part, Date, SelnOnly),
	    Done = 1;
	true),
%	all(event, do_colours, [build(TempSels), unify(off)]),
	/* restart_move will recreate any cross-border links removed by cutout.
	If exiting, move will have been scrapped after old deletes */
	restart_move,
	retract(suspend_display),
	nonvar(Done). /* fails if save failed */


mark_model_danger(Model, Danger) :-
	Win shows_model Model,
		set_save_status(Win, Danger),
		fail;
	true.

get_default_export_name(Model, Extn, Export) :-
	[Slash] = "/", [Dot] = ".",
	(get_model_file(Model, Path), !; Path = untitled),
	sicstus_atom_chars(Path, PathStr),
	(append(Dirs, File, PathStr),
	    suffix([Slash], Dirs),
	    \+ member(Slash, File), !;
	File = PathStr),
	(append(Base, [Dot | OldExtn], File),
	    \+ member(Dot, OldExtn), !;
	Base = File),
	append(Base, Extn, ExportStr),
	sicstus_atom_chars(Export, ExportStr).
	
	
/* style selection between eng and sd is largely redundant now... 

reroute_for(Style) :-
	find_type(Function, function),
	off(Function),
	(m_class:Drive is_connector from Function to Recipient,
		off(Drive),
		(Style = sd,
			Link_end = Recipient;
		\+ Style = sd,
			(get_shape(Function, bounding_box, _);
			\+ get_shape(Function, bounding_box, _),
				(Zone = bounding_box; Zone = bowtie),
				get_shape(Recipient, Zone, [L, T, _, _]),
				get_box_size(function, Size),
				make_bounding_box(function, L, T, Size, Box),
				set_shape(Function, bounding_box, Box)),
			Link_end = Function,
			redisplay(Function)),
		event:make_links_follow(Link_end),
	\+ m_class:_ is_connector from Function to _,
		do_delete(Function)),
	fail.

reroute_for(_).
*/

