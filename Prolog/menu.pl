/*
menu_handle.pl
---------------
This contains the code for responding to events signalled by the user 
interface of the application. It responds by:
* Querying and updating the GUI state representation
* Calling the model maintenance module to add information to the model
* Making calls to the screen drawing module (new image, or redraw)
*/
sicstus_module(menu, [show_wait_cursor/0, show_normal_cursor/0,
	undo_edit/2, redo_edit/2, menu_select/1, mode_select/1,
	menu_handle/3, set_box_size/4, change_size/2,
	off_window/1, kill_everything/0]).
	
sicstus_use_module([sp_only, compile, dialogue, m_update, image, draw, 
	state, backup, library, ame_gen, utility, 
	library(lists), library(ordsets)]).

:- dynamic(running/1).
:- dynamic(cursor_is/1).
cursor_is(arrow).

show_wait_cursor :-
	Win shows_model _,
	cursor_in(Win, watch),
	fail;
	true.

show_normal_cursor :-
	Win shows_model _,
	(cursor_is(Special), 
	    cursor_in(Win, Special);
	\+ cursor_is(Special),
	    cursor_in(Win, arrow)),
	fail;
	true.

undo_edit(Wid, Wids) :-
	Wid shows_model ClickedModel,
	contains(Model, ClickedModel),
	is_toplevel(Model),
	go_back(Model, Further),
	all(menu, check_exist, [build(Wids)]),
	redraw_window(_),
	update_ability(Model, undo, edit, 'Undo', Further),
	update_ability(Model, redo, edit, 'Redo', 1),
	save_allowed(Model, CanSave),
	update_ability(Model, save, file, 'Save', CanSave).

redo_edit(Wid, Wids) :-
	Wid shows_model ClickedModel,
	contains(Model, ClickedModel),
	is_toplevel(Model),
	go_forward(Model, Further),
	all(menu, check_exist, [build(Wids)]),
	redraw_window(_),
	update_ability(Model, undo, edit, 'Undo', 1),
	update_ability(Model, redo, edit, 'Redo', Further),
	save_allowed(Model, CanSave),
	update_ability(Model, save, file, 'Save', CanSave).

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
	(normalize(_),
	    fail;
	give_focus('{}'),
	OldMode = NewMode), !;
	set_mode(NewMode),
	retract(cursor_is(_)),
	(Win shows_model _,
		(NewMode = select,
			enable_text_editing_in(Win);
		\+ NewMode = select,
			disable_text_editing_in(Win)),
		fail;
	NewMode = add, !,
	    assert(cursor_is(target));
	NewMode = move, !,
	    assert(cursor_is(fleur));
	NewMode = copy, !,
	    assert(cursor_is(exchange));
	NewMode = ghost, !,
	    assert(cursor_is(sqb('GetGhostCursor')));
	NewMode = delete, !,
	    assert(cursor_is(pirate));
	NewMode = snap, !,
	    assert(cursor_is(question_arrow));
	assert(cursor_is(arrow))).

stick_model_in(Parent, Name, Mode) :-
	Mode = reopen,
	check_if_already_open(Name), !;
	use_temp_dir(LocalDir),
	(event:list_captions(Parent, Used), !; true),
	abs_path_name(Parent, root, InsertDir),
	append_atoms([LocalDir, '/', InsertDir], TargetDir),
        start_progress_dialogue,
        reassure_user("Decoding MIME-format saved file"),
	output:load_file(Parent, TargetDir, Name, CheckedStr),
	name(Checked, CheckedStr),
	(member(Checked, [no, yes]), !, 
	    append_atoms(TargetDir, '/model.pl', PrologData),
	    ame_merge(Parent, PrologData, _Date, Checked, Translated),
	    /* date not needed */
	    output:my_delete_file(PrologData),

	    /* Now if the saved model has any images these will be in the top
	    dir (fttb) so get them loaded */
	    transfer_images(Parent, TargetDir, in),
		  
	    append_atoms(TargetDir, '/model.cnv', GraphFileName),
	    (Translated = copy,
		TryDll = '',
	/* If this exists, call tcl to skee-WIRT it into each parent window */
		output:my_file_exists(GraphFileName), !,
		Win shows_model Parent,
		inject_graphics(Win, GraphFileName);
	    /* this should call Prolog back with the display detail vals */
	    TryDll = 0,
		NeedsRedraw = 1),
	    add_parameter(Parent, 1, c_new, TryDll),
	    output:my_delete_file(GraphFileName);
	/* legacy case, file opened is Prolog:
	    no canvas, images or runnables */
	on_exception(ProLoss, ame_merge(Parent, Name, _Date, no, Translated),
		     (make_nice_error_message(ProLoss, ProLite),
		     show_error(Parent, open_model_failed(Checked, ProLite)))),
	    NeedsRedraw = 1),
        finish_progress_dialogue,
	(Mode = reopen,
	    set_model_file(Parent, Name),
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
	    update_captions(Parent);
	Mode = insert(Pt),
	    (Translated = copy, !, /* paste into empty sole toplevel */
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
	    record_bbox(Parent, Box)),
	    
	    (find_space_for(Box, Parent, Lighters, Pt, [Xoffset, Yoffset]),
		all(event, adjust_posn,
		    [build(Movers), unify([-Xoffset, -Yoffset, 1, 1])]);
	    true),
	    all(event, retitle_duplicate, [build(Movers), unify(Used)]),
	    (member(Mover, Movers),
		redisplay(Mover),
		fail;
	    finish_move(Parent, 1))).

check_if_already_open(Name) :-
	get_model_file(Model, Name),
	Win shows_model Model,
	output:safe_tcl_eval([wm, deiconify, sqb([winfo, toplevel, Win])], _),
	output:safe_tcl_eval([raise, sqb([winfo, toplevel, Win])], _).


resize_canvas_for(Parent) :-
	find_all_comps(Parent, Lump),
		get_shape(Lump, bounding_box, [Lb, Tb, Rb, Bb]),
		get_shape(Parent, internal_extent, [Lo, To, Ro, Bo]),
		Ln is min(Lo, Lb-10),
		Tn is min(To, Tb-10),
		Rn is max(Ro, Rb+10),
		Bn is max(Bo, Bb+10),
		change_shape(Parent, internal_extent, [Ln, Tn, Rn, Bn]),
		fail;
	get_shape(Parent, internal_extent, Rect),
		expand_canvas(Parent, Rect).

/* menu_handle. First arg is title of menu, second is item selected. */

menu_handle(Win, file, new) :-
	Win shows_model Parent,
	check_deletable(Win, Parent),
	remove_model(Win, Parent),
	finish_move(Parent, 0),
	set_save_status(Win, safe),
	update_captions(Parent).

menu_handle(_Win, file, new_toplevel) :-
	m_update:make_desktop(_,_).

menu_handle(_Win, open_toplevel, Name) :-
	check_if_already_open(Name), !;
	m_update:make_desktop(Parent, _),
	stick_model_in(Parent, Name, reopen).

menu_handle(Win, file, open) :-
	Win shows_model Parent,
	check_deletable(Win, Parent),
	get_load_file(Name),
	(Name = '', !;
	remove_model(Win, Parent),
	stick_model_in(Parent, Name, reopen)).

menu_handle(Win, GetMode, Name) :-
	Win shows_model Parent,
	(GetMode = reopen,
	    UseMode = reopen,
	    check_deletable(Win, Parent),
	    remove_model(Win, Parent);
	GetMode = insert,
	    UseMode = insert([0,0]),
	    select_all_in(Parent, off)),
	stick_model_in(Parent, Name, UseMode).

menu_handle(Win, file, save) :-
	Win shows_model Model,
	do_save(Model, false).

menu_handle(Win, file, save_as) :-
	Win shows_model Model,
	do_save(Model, true).

menu_handle(Win, file, save_seln_as) :-
	Win shows_model Model,
	do_save(Model, seln_only).

menu_handle(Win, file, save_interface) :-
	Win shows_model Model,
	caption_for(Model, MCaption),
	(is_population(Model), !,
	    Bounds=population;
	get_node_size(Model, Bounds)),
	
	get_default_export_name(Model, ".isf", DefName),
	get_program_file(DefName, FileName),
	start_progress_dialogue,
	open(FileName, write, Stream),
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
	get_program_file(DefN, Tgt),
	start_progress_dialogue,
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
	    output:safe_tcl_eval([file, copy, '-force', br(Top), br(Tgt)], _)),
	finish_progress_dialogue;
	do_dialogue("Error exporting code", error, "This submodel does not have its own code.", ok, _)).

menu_handle(Win, file, RunCmd) :-
	member([RunCmd, Lang], [[run_c, c], [run_tcl, tcl]]),
	Win shows_model Node,
	start_progress_dialogue,
	/* Compile the thing into whatever, load it */
	scrub_run(Node, 0),
	use_temp_dir(Dir),
	(rebuild_code(Lang, Node, Dir), !,
	    /* no much point going for run */
	    on_exception(_Whoops,
			 output:prepare_execution(Node, Lang),
		     (do_dialogue("Compilation or startup error", error,
				  "Select \"I/O Tools -> Add tool -> Standard tools -> TclTk error info\" to view error messages", ok, _),
			 scrub_run(Node, 0))),
	    set_running_model(Node);
	true),
	(retract(new_exec_for(_Any)), !,
	    retractall(new_exec_for(_)),
	    finish_move(Node, 0);
	restart_move),
	finish_progress_dialogue,
	show_normal_cursor.

%################################### Bob's changes (tcl/tk version): start (
menu_handle(Win, file, list_eqns) :-
	Win shows_model Model,
	tk_equationlisting_start,
	mysetof(Component,(contains(Model,Component),find_type(Component,submodel),appears(Component)),Submodels),
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

menu_handle(Win, file, export_prolog) :-
	Win shows_model Model,
	count_functions(Model, N),
	state:eval_fn_limit_is(Limit),
	(N > Limit,
	    get_edition(evaluation), !,
	    sicstus_format_to_chars("This model has ~d equations. This is greater than ~d, so it cannot be saved in the evaluation edition.", [N, Limit], Annoy),
	    do_dialogue("Error saving model", error, Annoy, ok, _),
	    fail;
	true),

	get_default_export_name(Model, ".pl", DefName),
	get_program_file(DefName, FileName),
	output:date_is(Date),
        start_progress_dialogue,
	save_isolated(FileName, Model, Date, no),
        finish_progress_dialogue.

menu_handle(Win, edit, Component) :-
	Component is_primitive,
	get_edit_model(Win, Model, Tgt),
	(Component is_class_of_sort box, !,
	    event:insert(Win, Model, Tgt, Component),
	    finish_move(Model, 1);
	(Tgt = [Xpt, Ypt], !,
	        set_current_coords(Xpt, Ypt),
	        event:make_terminator(Component, Model, StartPt),
	        nonvar(StartPt);
	    StartPt = Tgt),
	    event:do_linear(Component, StartPt),
	    advance_phase_to(targetting),
	    event:assert(instant_link(Component))).

/* Delete the selection */
menu_handle(Win, edit, reroute) :-
        start_progress_dialogue,
	reassure_user("Reroute in progress"),
	get_edit_model(Win, Model, _),
	/* Get selected links top-down, flows first */
	setof(Rerouter, (contains(Model, Rerouter),
			    Rerouter is_of_sort line,
			    event:doomed(Rerouter),
			    clear_shape(Rerouter, course)), Rerouters),
	reroute_sections(Rerouters),
	finish_move(Model, 0),
	remove_old_incomplete,
	finish_progress_dialogue.

menu_handle(Win, edit, delete) :-
        start_progress_dialogue,
	reassure_user("Delte in progress"),
	get_edit_model(Win, Model, _),
	event:delete_net(Model),
	finish_move(Model, 1),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, CutOrCopy) :-
	(CutOrCopy = cut,
	    Msg = "Cut in progress";
	CutOrCopy = copy,
	    Msg = "Copy in progress"),
        start_progress_dialogue,
	reassure_user(Msg),
	get_edit_model(Win, TopModel, _),

	/* Old version: took too long
	New version: first, find the innermost submodel with the whole
	selection in it */
%	assert(suspend_display),
	setof(Seln, (contains(TopModel, Seln),
			\+ Seln = TopModel,
			Seln is_of_sort box,
			event:doomed(Seln)), SelnList),
	find_innermost_selection_holder(SelnList, Model),

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
	select_all_in(Model, off),
	all(event, do_colours, [build(SelnList), unify(on)]),
	(CutOrCopy = cut,
	    event:delete_net(Model),
	    finish_move(Model, 1);
	CutOrCopy = copy),
	finish_progress_dialogue.

menu_handle(Win, edit, paste) :-
	get_edit_model(Win, Model, Pt),
	use_pref_dir(Dir),
	append_atoms(Dir, '/clipboard.pl', CopyFile),
	stick_model_in(Model, CopyFile, insert(Pt)).
	
menu_handle(Win, edit, selall) :-
        start_progress_dialogue,
	reassure_user("Selecting whole model"),
	get_edit_model(Win, Model, _),
	select_all_in(Model, on),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, unselall) :-
        start_progress_dialogue,
	reassure_user("Unselecting whole model"),
	get_edit_model(Win, Model, _),
	select_all_in(Model, off),
	finish_progress_dialogue.
	   
menu_handle(Win, edit, invsel) :-
        start_progress_dialogue,
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
	get_import_file('plugplay.isf', SpecFile),
	open(SpecFile, read, Stream),
	read(Stream, interface_spec_for(SubmodelName, _)),
	Win shows_model Submodel,
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
	    event:tweak_link_connections(Submodel, [0,0], l, [0,0,1,1]),
	    finish_move(Submodel, 1);
	close(Stream),
	    restart_move,
	    (FarWin shows_model Submodel,
		redraw_window(FarWin),
		fail;
	    redisplay(Submodel))).
	
	 
menu_handle(Win, window, NastyAtom) :-
	name(NastyAtom, NastyStr),
	get_term(NastyStr, detail(Parameter,Level,Redraw), []),
	set_display_depth(Win, Parameter, Level),
	(Redraw=0, !; redraw_window(Win)).

menu_handle(_, _, _).

get_edit_model(Win, Comp, Pt) :-
	(event:menu_submodel_is(Comp, Pt), !;
	Win shows_model Comp).

select_all_in(Model, Way) :-
	contains(Model, Bit),
	    Bit is_of_sort box,
	    appears(Bit),
	    \+ Bit = Model,
	    (Way = on,
		event:do_colours(Bit, on);
	    Way = off,
		get_highlit_obj(0, Bit),
		event:do_colours(Bit, off)),
	    fail;
	true.
	
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
	true).

find_innermost_selection_holder([Comp | Rest], Innermost) :-
	find_all_comps(Model, Comp),
	(Rest = [], !,
	    Innermost = Model;
	find_innermost_selection_holder(Rest, HoldsRest),
	    contains(Innermost, HoldsRest, Adds),
	    contains(Innermost, Model, MoreAdds), !,
	    append(Adds, MoreAdds, AllAdds),
	    all(draw, set_highlit_obj, [unify(0), build(AllAdds)])).

find_space_for([L, T, R, B], Model, Including, DefPt, [TargetX, TargetY]) :-
	get_shape(Model, internal_extent, [ML, MT, MR, MB]),
	(nonvar(DefPt), !; DX is (L+R)/2, DY is (T+B)/2),
	DefPt = [DX, DY],

	MinOffX is ML - L,
	MinOffY is MT - T,
	MaxOffX is MR - R,
	MaxOffY is MB - B,

	/* These two are the offset to get it to nearest feasible posn */
	BestX is max(MinOffX, min(MaxOffX, DX-(L+R)/2)),
	BestY is max(MinOffY, min(MaxOffY, DY-(T+B)/2)),

	HDispMax is (MR-ML)-(R-L),
	VDispMax is (MB-MT)-(B-T),
	MaxDist is max(HDispMax, VDispMax),
	count_to(0, MaxDist, 10, Distance),
	count_to(0, Distance, 10, Range),
	((TargetX is BestX-Distance, TargetX > MinOffX;
	  TargetX is BestX+Distance, TargetX < MaxOffX),
	(TargetY is BestY-Range, TargetY > MinOffY;
	    TargetY is BestY+Range, TargetY < MaxOffY);
	(TargetY is BestY-Distance, TargetY > MinOffY;
	    TargetY is BestY+Distance, TargetY < MaxOffY),
	(TargetX is BestX-Range, TargetX > MinOffX;
	    TargetX is BestX+Range, TargetX < MaxOffX)),

	/* These make sure the rectangle fits in the model so now we only need
	to check for interference */
	NewL is L+TargetX, NewT is T+TargetY,
	NewR is R+TargetX, NewB is B+TargetY,
	\+ (get_overlaps(Model, [NewL, NewT, NewR, NewB], Obstacle),
	       \+ member(Obstacle, Including)).
	
reroute_sections(Rerouters) :-
	Rerouters = [];
	member(Type, [relation, flow, influence]),
	full_section(Rerouters, Type, [Go | Rest], TopArc, Remains),
	suffix([Stop], [Go | Rest]),
	(m_class:follows(Start, Go); m_class:Go is_connector from Start to _),
	(m_class:follows(Stop, End); m_class:Stop is_connector from _ to Fn),
	get_host(Fn, End),
	event:draw_line_to(Start, Type, End),
	event:reuse_route(Type, TopArc),
	reroute_sections(Remains).

full_section(Rerouters, Type, [Start | Rest], Top, Remains) :-
	select(Start, Rerouters, Left),
	find_type(Start, Type),
	\+ (m_class:follows(Before, Start), member(Before, Left)),
	continuation(Left, Start, Rest, Top, Remains).

continuation(Rerouters, Start, Rest, TopArc, Remains) :-
	m_class:follows(Start, Next),
	select(Next, Rerouters, Left), !,
	continuation(Left, Next, More, FarArc, Remains),
	Rest = [Next | More],
	(find_all_links(M1, Start),
	    find_all_comps(M1, Next), !,
	    TopArc = Start;
	TopArc = FarArc);
	Rest = [],
	TopArc = Start,
	Remains = Rerouters.
	
:- op(950, yfx, [where]).

display_submodels(_,[]).
display_submodels(Isub,[Submodel|Submodels]):-
	rel_path_name(Submodel, _, _,_, SmCapt),
	sicstus_format_to_chars("Equations in ~a", [SmCapt], HeaderStr),
	name(Header, HeaderStr),
	tk_equationlisting_addsubmodel(Isub,Header),
	mysetof((Entry,Description,Comment,InFlows,OutFlows),write_eqn_term(Submodel,Entry,Description,Comment,InFlows,OutFlows),Entries),
	display_entries(Isub,1,Entries),
	Isub1 is Isub+1,
	display_submodels(Isub1,Submodels).

display_entries(_,_,[]).
display_entries(Isub,Ivar,[(VarType:VarLabel=Expression where WhereList,Description,Comment,InFlows,OutFlow)|Entries]):-
	tk_equationlisting_addvariable(Isub,Ivar,VarType,VarLabel,Expression,WhereList, Description, Comment,InFlows,OutFlow),
	Ivar1 is Ivar+1,
	display_entries(Isub,Ivar1,Entries).

mysetof(A,B,C):-
	setof(A,B,C),!.
mysetof(_,_,[]).

write_eqn_term(Submodel, Entry, Description, Comment, InFlows, OutFlows) :-
	find_all_comps(Submodel, Component),	
	find_type(Component, function),
	get_av_pair(Component, 0, value, Eqn),
	(get_av_pair(Component, 0, description, Description); 
		\+ get_av_pair(Component, 0, description, Description), Description = null),
	(get_av_pair(Component, 0, comment, Comment);
	    \+ get_av_pair(Component, 0, comment, Comment), Comment = null),
	implicit_function(VisNode, Component),
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
		Entry = ((CompType:Dest=Eqn) where [null]));     % Bob's change
	(PPairs = [_ | _],
		Entry = ((CompType:Dest=Eqn) where PPairs))).

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
		      NewCount, NewStep, NewComment, NewFix,
		      NewHide, NewSeparate, NewEnumSpecs],
	    P_list = [Colour, Image, ImgPos, Nature, Fatness, Count, Step,
		      _Comment, _EnumSpecs, Fix, Hide, Separate],
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
	    add_parameter(Model, 0, comment, NewComment),
	    (NewFix = 'Default', !,
		add_parameter(Model, 0, eqn_units, '');
	    add_parameter(Model, 0, eqn_units, NewFix)),	
	    add_parameter(Model, 0, separate, NewSeparate),
	    (NewEnumSpecs = '', !,
	        NewEnumTypes = [];
	    all(menu, separate_type_from_mems,
		[build(NewEnumSpecs), build(NewEnumTypes)])),
	    add_parameter(Model, 0, enum_types, NewEnumTypes),
	    (change_shape(Model, hide_contents, NewHide);
		set_shape(Model, hide_contents, NewHide)),
	    (NewNature = generated,
		name(NewCount, CountStr),
		append([91 | CountStr], [93], ListStr),
		get_term(ListStr, UseCount, Error),
		(\+ Error = [],
		    append("Invalid dimension string -- ", Error, Wibble);
/*		get_actual_sizes(UseCount, Sizes), */
		get_actual_sizes(Model, UseCount, Sizes, _,_),
		    (member(Dodgy, Sizes),
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
		adjust_toplevel_windows(Model, NewExtent),
		event:move_boxes(Model, FatTrans),
		(member(RerouteType, [flow, influence]),
		find_all_comps(Model, Linkage),
		find_type(Linkage, RerouteType),
		update_link_route(Linkage, no),
		redisplay(Linkage),
		fail; true)),

	    /* Changes in fatness require redrawing submodel's
	    toplevel windows; this plus nature, count and visibility require
	    redrawing it in other windows */
	    (([NewColour, NewImage, NewImgPos, NewNature] =
	     [Colour, Image, ImgPos, Nature],
	      FatFactor = 1, UseCount = Count, NewHide = Hide), !;
	    (\+ FatFactor = 1,
		Win shows_model Model,
		redraw_window(Win),
		fail;
	    redisplay(Model))),

	    /* this is quick so do it anyway */
	    (contains(Model, Submodel),
		_Window shows_model Submodel,
		update_captions(Submodel),
		fail;
	    NewNature = Nature, UseCount = Count, !;
		event:spread_colour(Model, yes)),
	    
	    (\+ (NewNature = Nature, UseCount = Count, NewStep = Step,
		   NewFix = Fix, NewSeparate = Separate),
		fail;
	    \+ NewSeparate = Separate,
		find_all_comps(Parent, Model),
		fail;
	    finish_move(Model, 1))).

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
		Whatever = course,
			translate(Wherever, Trans, New_wherever)),
		change_shape(Thing, Whatever, New_wherever),
		fail).

rebuild_code(Lang, Node, ProgFileDir) :-
	(on_exception(Whoops, compile(Lang, Node, ProgFileDir), true),
	    !;
	    Whoops = compilation_failed),
	(Whoops = yes;
	    show_error(Node, Whoops),
	    scrub_run(Node, 0),
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
	Lossage = ordering_failure(Awkward), !,
	    sicstus_format_to_chars("Failed to put this instruction into ordered sequence, despite it not seeming to depend on anything: ~w", [Awkward], Text),
	    Fault = system;
	Lossage = bad_role(Lost), !,
	    sicstus_format_to_chars("This model cannot be built because submodel ~a has a role arrow connecting it to a submodel in a separate executable module.", [Lost], Text),
	    Fault = user;
	Lossage = preprocessor_failure(Target), !,
	    sicstus_format_to_chars("Failed to substitute macro functions and references in ~a", [Target], text),
	    Fault = system;
	Lossage = conversion_failure(Target, Problem), !,
	    sicstus_format_to_chars("Failed to convert ~a into a program instruction. This may be because Simile earlier failed to detect when a change elsewhere in the model made the equation for this variable inconsistent, in which case editing this variable again will make the model runnable. ", [Target], Amble),
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
	(get_model_file(Model, Name), !; Name = unsaved),
	(backup:autosave_file_is(Model, AutoName), !; AutoName = none),
	output:safe_tcl_eval(['BuildProblem', br(Name), br(AutoName),
			      br(chars(Text)), Fault], _).

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
	    ok_to_delete(Parent)).

remove_model(Win, Parent) :-
	(is_toplevel(Parent), !,
	    scrub_run(Parent, 1),
	    output:safe_tcl_eval(['KillInterpFor', Parent], _),
	    forget_highlit_obj(_,_),
	    superfast_delete(Parent),
	    add_parameter(Parent, 0, step, ''),
	    add_parameter(Parent, 0, multiplication_spec, ''),
	    add_parameter(Parent, 0, comment, ''),
	    add_parameter(Parent, 0, fill_colour, ''),
	    redraw_window(Win);
	start_progress_dialogue,
	reassure_user("Creating new inputs for values from deleted submodel"),
	cutoff(Parent);
	(find_all_comps(Parent, Child),
	    delete_tree(Child),
	    fail;
	reassure_user("Updating screen representation of components affected by this delete"),
	    event:spread_colour(Parent, no),
	    finish_progress_dialogue,
	    redisplay(Parent))),
	clear_model_file(Parent),
	use_temp_dir(LocalDir),
	abs_path_name(Parent, root, DeleteDir),
	output:trim_tree(LocalDir, DeleteDir),
	scrub_autosave(Parent).

cutoff(Parent) :-
	find_all_comps(Parent, Child),
	sever_links(Child, Parent),
	fail.
		
cutout(Parent) :-
	find_all_links(Parent, Child),
	sever_links(Child, Parent),
	fail.
		
delete_tree(Target) :-
	find_type(Target, submodel),
	    caption_for(Target, Caption),
	    sicstus_format_to_chars("Deleting submodel ~a", [Caption], Ms),
	    clear_model_file(Target),
	    reassure_user(Ms),
	    fail;
	find_all_links(Target, Comp),
	    delete_tree(Comp),
	    fail;
	find_all_comps(Target, Comp),
	    delete_tree(Comp),
	    fail;
	off(Target),
	    fast_delete(Target).

change_size(Type, New_size) :-
	find_type(Obj, _),
	draw_style_for(Obj, Type),
	(Type = submodel; Type = influence; Type = relation;
	Type = flow,
		get_shape(Obj, bowtie, [L, T, R, B]),
		Xpt is (L+R)/2,
		Ypt is (T+B)/2,
		adjust_bowtie(Obj, [Xpt, Ypt]);
	(Type = channel; Type is_primitive, Type is_class_of_sort box),
		get_shape(Obj, bounding_box, [L, T, R, B]),
		Xpt is (L+R)/2,
		Ypt is (T+B)/2,	
		make_bounding_box(Type, Xpt, Ypt, New_size, New_box),
		change_shape(Obj, bounding_box, New_box),
		event:make_links_follow(Obj)),
	redisplay(Obj),
	fail.

change_size(_,_).

off_window(Win) :-
	Win shows_model Model,
	(is_toplevel(Model), !,
	    check_deletable(Win, Model),
	    start_progress_dialogue,
	    remove_model(Win, Model),
	    delete_tree(Model),
	    finish_progress_dialogue,
	    (is_toplevel(_Remains), !;
		exit_AME,
		user:wind_up);
	delete_window(Win)).

kill_everything :-
	Win shows_model Model,
	is_toplevel(Model),
	off_window(Win),
	fail;
	true.
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ok_to_delete(Target) :-
	get_default_export_name(Target, ".sml", Handle),
	caption_for(Target, Title),
	sicstus_format_to_chars("Component ~a (in ~a) has not been saved since it was last modified. Save it now?", [Handle, Title], Query),
	do_dialogue("Save changes", question, Query, yesnocancel, Reply),
	(Reply = yes, do_save(Target, false);
	Reply = no).

do_save(Model, New_name) :-
	count_functions(Model, N),
	state:eval_fn_limit_is(Limit),
	(N > Limit,
	 get_edition(evaluation), !,
	    sicstus_format_to_chars("This model has ~d equations. This is greater than ~d, so it cannot be saved in the evaluation edition.", [N, Limit], Annoy),
	    do_dialogue("Error saving model", error, Annoy, ok, _),
	    fail;
	true),
	use_temp_dir(Dir),
	abs_path_name(Model, root, Point),
	append_atoms([Dir, '/', Point], SaveDir),
	
        start_progress_dialogue,
	/* Remove any old executables (and make sure dirs exist) */
	save_dlls(Point, Dir, Model, Model, _),

	/* save prolog data */
	append_atoms(SaveDir, '/model.pl', TempFile),
	output:date_is(Date),
	(New_name = seln_only, !, Select = yes, CanvasModel = none;
	    Select = no, CanvasModel = Model),
	save_isolated(TempFile, Model, Date, Select),
	
	/* Save image backgrounds */
	transfer_images(Model, SaveDir, out),

	/* Save canvas file -- remove selection cos graphics but not state
	are saved */
	select_all_in(Model, off),
	check_save_canvas(SaveDir, CanvasModel, Date),


	/* here is where we get the user to enter the name to save it
	as.  This may be tried multiple times, which is why it is done after
	writing all the saved components to temp file. */

	(New_name = false,
	    get_model_file(Model, Name);
	try_save_files(Name)),

	/* Now build the multi-part MIME format save file */
        reassure_user("Creating MIME-format saved file"),
	output:save_file(Model, SaveDir, Name, Oops),

        (   Oops = [];
	    \+ Oops = [],
            do_dialogue("Problem building output file", error, Oops, ok, _),
	    fail),

	/* If that succeeded, mark model as saved */
	(New_name = seln_only;
	set_model_file(Model, Name),
	update_captions(Model),
	clear_autosave(Model, Name),
	update_ability(Model, save, file, 'Save', 0),
	mark_model_danger(Model, safe)),
        finish_progress_dialogue, !;
        finish_progress_dialogue, fail.

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
	 reassure_user("Saving canvas description"),
	    Win shows_model Model,
	    all(state, get_display_depth, [unify(Win),
		 build([ghost_link, influence, variable, flow, compartment,
		   submodel, caption, sections]), build(CurrentDepths)]),
	    save_canvas(Win, CanvasName, CurrentDepths, Date);
	\+ output:my_file_exists(CanvasName);
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
	assert(suspend_display),
	cutout(Part);
	(ame_save(Name, Part, Date, SelnOnly),
	    Done = 1;
	true),
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
	name(Path, PathStr),
	(append(Dirs, File, PathStr),
	    suffix([Slash], Dirs),
	    \+ member(Slash, File), !;
	File = PathStr),
	(append(Base, [Dot | OldExtn], File),
	    \+ member(Dot, OldExtn), !;
	Base = File),
	append(Base, Extn, ExportStr),
	name(Export, ExportStr).
	
	
/* style selection between eng and sd is largely redundant now... */

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
