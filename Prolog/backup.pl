%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   PROCEDURES FOR SAVING AND RESTORING PREVIOUS MODEL STATES             %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sicstus_module(backup, [initialize_ring/1,
			scrap_move/0, finish_move/2, restart_move/0,
			get_save_status/2, set_save_status/2, save_allowed/2,
			go_back/2, go_forward/2, make_auto_name/3,
			new_autosave/2, clear_autosave/2, check_autosave/4,
			scrub_autosave/1, is_toplevel/1, is_module/1,
			use_temp_dir/1, use_pref_dir/1, into_save_file/2]).

sicstus_use_module([library(lists), sp_only, ame_gen, database, utility]).

:- dynamic(autosave_file_is/2).

:- dynamic(save_status_of/2).

set_save_status(Model, Stat) :-
	retractall(save_status_of(Model, _)),
	assert(save_status_of(Model, Stat)).

get_save_status(Model, Stat) :-
	save_status_of(Model, Stat).

backup_states(32).

:- dynamic(saved_state/3).

scrap_move :-
	fetch_update(_),
	    fail;
	true.

initialize_ring(Model) :-
	retractall(saved_state(Model, _,_)),

/* No need to duplicate whole database with current system...
	assert(saved_state(phase, record_even)),
	(attack_database(call, P),
		assert(saved_state(record_even, P)),
		fail;
*/
        scrap_move,
	assert(saved_state(Model, first, 1)),
	assert(saved_state(Model, last, 1)),
	assert(saved_state(Model, current, 1)).

go_back(Model, Further) :-
	restart_move,
	retract(saved_state(Model, current, Current)),
	wrap(Prev, Current),
	internal_extent_jiggered(Model, Prev, LostExtents),
	appearance_changes(Model, Prev, LostExtents, Redrawn),
	all(draw, off, [build(Redrawn)]), /* safe if they don't exist yet */
	reverse_changes(Model, Prev),
	all(draw, adjust_submodel_internals, [build(LostExtents)]),
	all(draw, redisplay_border, [build(Redrawn)]),
	into_save_file(Model, undo),
	assert(saved_state(Model, current, Prev)),
	(saved_state(Model, first, Prev), !,
		Further = 0;
	Further = 1).

go_forward(Model, Further) :-
	restart_move,
	retract(saved_state(Model, current, Current)),
	wrap(Current, Next),
	internal_extent_jiggered(Model, Current, LostExtents),
	appearance_changes(Model, Current, LostExtents, Redrawn),
	all(draw, off, [build(Redrawn)]),
	enact_changes(Model, Current),
	all(draw, adjust_submodel_internals, [build(LostExtents)]),
	all(draw, redisplay_border, [build(Redrawn)]),
	into_save_file(Model, redo),
	assert(saved_state(Model, current, Next)),
	(saved_state(Model, last, Next), !,
		Further = 0;
	Further = 1).

finish_move(EditedModel, ChangeExec) :-
	m_update:contains(Model, EditedModel),
	state:shows_model(Win, Model),
	set_save_status(Win, risky),
	(ChangeExec = 0;
	 ChangeExec = 1,
	    m_update:add_parameter(EditedModel, 1, c_new, 0)),
	/* Only proceed for toplevel window containing model */
	is_toplevel(Model),
	(ChangeExec = 0;
	 ChangeExec = 1,
	    output:tk_alter_model(Model)),
	draw:update_ability(Model, undo, edit, 'Undo', 1),
	draw:update_ability(Model, redo, edit, 'Redo', 0),
	save_allowed(Model, CanSave),
	draw:update_ability(Model, save, file, 'Save', CanSave),
	retract(saved_state(Model, first, First)),
	retract(saved_state(Model, last, _)),
	retract(saved_state(Model, current, Current)),
	record_changes(Model, Current),
	update_autosave(Model, Current),
	wrap(Current,Next),
	(First = Next, !,
		wrap(Next, Following),
		assert(saved_state(Model, first, Following));
	assert(saved_state(Model, first, First))),
	assert(saved_state(Model, last, Next)),
	assert(saved_state(Model, current, Next)).

/* This undoes anything that has happened since the last finish_move; needed
after putting up restore dialog, to be sure we are restoring from the same
state we saved from. */

restart_move :-
	fetch_update(DP),
		(DP = remove(P),
			database:assert(P);
		DP = add(P),
			database:retract(P)),
		fail;
	true.

:- dynamic(counted_fns/1).
counted_fns(0).

save_allowed(Model, OK) :-
	state:get_edition_and_limit(Edn, Limit), !,
	retract(counted_fns(OldTot)),
	assert(counted_fns(0)),
	(contains(Model, Fun),
	    find_type(Fun, function),
	    retract(counted_fns(Were)),
	    Are is Were+1,
	    assert(counted_fns(Are)),
	    Are > Limit,
	    (OldTot > Limit;
		/* canny buggers can get round save limit by killing the app
		and restoring from logfile, so stop keeping logfile */
	    retractall(autosave_file_is(Model, _F)),
		output:safe_tcl_eval(['NotifyOverLimit', Edn, Limit], _)), !,
	    OK = 0;
	OK = 1);
	OK = 1.

	
wrap(Old, New) :-
	(backup_states(Old), New = 1;
	integer(Old), New is Old + 1;
	integer(New), Old is New - 1), !.	

record_changes(Model, Slot) :-
	retractall(saved_state(Model, Slot, _)),
		fetch_update(DP),
		assert(saved_state(Model, Slot, DP)),
		fail;
	true.

update_autosave(Model, Slot) :-
	(setof(Acts, saved_state(Model, Slot, Acts), ActList), !;
	    ActList = []),
	into_save_file(Model, ActList).

into_save_file(Model, ActList) :-
	autosave_file_is(Model, File), !,
	(retract(translation_info(Model, TransInfo)), !,	    
	    append(TransInfo, ActList, FullList);
	FullList = ActList),
	on_exception(Lossage, (open_native(File, append, Save),
				  write_with_breaks(Save, FullList),
				  close(Save)),
		(sicstus_format_to_chars("Could not create an autosave file called ~w for this model. The following message was produced: ~w. This may mean that the model was loaded from a read-only file system. No autosave data will be stored until the model is saved somewhere else.", [File, Lossage], Wibble),
	do_dialogue("Autosave warning!", warning, Wibble, ok, _),
	retract(autosave_file_is(Model, _)))); true.

restore_save_file(Model, Load, IdSwaps, UndoOn, RedoOn) :-
	read(Load, ActSpec),
	(ActSpec = end_of_file,
		saved_state(Model, current, Here),
		(saved_state(Model, first, Here), !,
			UndoOn = 0;
		UndoOn = 1),
		(saved_state(Model, last, Here), !,
			RedoOn = 0;
		RedoOn = 1),
		close(Load),
	        assert(translation_info(Model, [translated(IdSwaps)]));
		/* now load the mirror of the current state so I can continue to
			update undos and redos -- no longer needed
		saved_state(phase, Record),
		retractall(saved_state(Record, _)),
		(attack_database(call, P),
			assert(saved_state(Record, P)),
			fail;
		true); */
	repeat_action(Model, ActSpec, IdSwaps, NewIdSwaps),
		restore_save_file(Model, Load, NewIdSwaps, UndoOn, RedoOn)).

repeat_action(Model, ActSpec, IdSwaps, NewIdSwaps) :-
	ActSpec = undo,
	        NewIdSwaps = IdSwaps,
		retract(saved_state(Model, current, Current)),
		wrap(Prev, Current), !,
		(saved_state(Model, Prev, remove(P)),
			database:assert(P),
			fail;
		saved_state(Model, Prev, add(P)),
			database:retract(P),
			fail;
		assert(saved_state(Model, current, Prev)));
	ActSpec = redo,
	        NewIdSwaps = IdSwaps,
		retract(saved_state(Model, current, Current)),
		wrap(Current, Next), !,
		(saved_state(Model, Current, add(P)),
			database:assert(P),
			fail;
		saved_state(Model, Current, remove(P)),
			database:retract(P),
			fail;
		assert(saved_state(Model, current, Next)));
	(ActSpec = []; ActSpec = [_|_]),
	        retract(saved_state(Model, first, First)),
		retract(saved_state(Model, last, _)),
		retract(saved_state(Model, current, Current)),
		retractall(saved_state(Model, Current, _)),
		enact_from_file(Model, Current, IdSwaps, NewIdSwaps, ActSpec),
		wrap(Current,Next),
		(First = Next, !,
			wrap(Next, Following),
			assert(saved_state(Model, first, Following));
		assert(saved_state(Model, first, First))),
		assert(saved_state(Model, last, Next)),
		assert(saved_state(Model, current, Next)).

enact_from_file(_,_, I,I, []).

enact_from_file(Model, Slot, IdSwaps, NewIdSwaps, [Act | Rest]) :-
	((Act = add(OldP),
	    swap_ids(OldP, IdSwaps, MidIdSwaps, P),
	    database:assert(P);
	Act = remove(OldP), 
	    swap_ids(OldP, IdSwaps, MidIdSwaps, P),
		(database:retract(P), !;
		sicstus_format_to_chars("The log file specified the removal from the database of the term ~w at a point where this term was not in the database. This is probably non-fatal, but it might be a good idea to save the restored file and reload it in a new program run.", [P], Mess), 
		do_dialogue("Problem restoring state", warning, Mess, ok, _))),
	assert(saved_state(Model, Slot, Act));
	Act = top_level_is(OldModel),
	    append(SW1, [_-Model | SW2], IdSwaps),
	    append(SW1, [OldModel-Model | SW2], MidIdSwaps);
	Act = translated(PrevIdSwaps),
	    merge_id_swaps(IdSwaps, PrevIdSwaps, MidIdSwaps)),
	enact_from_file(Model, Slot, MidIdSwaps, NewIdSwaps, Rest).

merge_id_swaps(Swaps, [], Swaps).
merge_id_swaps(AtoCs, [A-B | MoreAtoBs], [B-C | MoreBtoCs]) :-
	select(A-C, AtoCs, MoreAtoCs),
	merge_id_swaps(MoreAtoCs, MoreAtoBs, MoreBtoCs).
	
swap_ids(OldTerm, Swaps, NewSwaps, NewTerm) :-
	OldTerm =.. [Header | Args],
	    member([Header | Template],
		   [[connection, node, node, arc],
		    [arc_type, arc, var],
		    [arc_info, arc, var, var],
		    [subsystem, node, node],
		    [node_class, node, var],
		    [node_refinement, node, var, var],
		    [node_attribute, node, var, special],
		    [graphical_info, both, var, var]]),
	    swap_args(Args, Template, Swaps, NewSwaps, NewArgs),
	    NewTerm =.. [Header | NewArgs].

swap_args([], [], S,S, []).

swap_args([Arg | Args], [Template | Templates], Swaps, NewSwaps,
	 [NewArg | NewArgs]) :-
	((Template = var,
	    NewArg = Arg;
	 Template = special,
	    replace_subexps(Arg, backup, sub_all, Swaps, top_down, _, NewArg);
	 member(Arg-NewArg, Swaps)), !,
	    MidSwaps = Swaps;
	 unique_name(Template, NewArg),
	    \+ m_class:is_part_of(NewArg, _),
	    \+ m_class:is_connector(NewArg, _), !,
	    MidSwaps = [Arg-NewArg | Swaps]),
	swap_args(Args, Templates, MidSwaps, NewSwaps, NewArgs).

sub_all(Swaps, Old, New, 0) :-
	member(Old-New, Swaps).		    
	
/* The routines to re-enact earlier states also adjust the recorded state to
reflect the current state because this is probably quicker than copying the
current state over again (removed because no longer needed!) */

reverse_changes(Model, Slot) :-
	(saved_state(Model, Slot, add(P)),
		database:retract(P),
		fail;
	saved_state(Model, Slot, remove(P)),
		database:assert(P),
		fail;
	true).

enact_changes(Model, Slot) :-
	(saved_state(Model, Slot, remove(P)),
		database:retract(P),
		fail;
	saved_state(Model, Slot, add(P)),
		database:assert(P),
		fail;
	true).

appearance_changes(Model, Slot, Reshapes, Comps) :-
	setof(Comp, Action^(saved_state(Model, Slot, Action),
			    mentions_graphics(Action, Comp),
			    \+ member(Comp-_, Reshapes)), Comps), !;
	Comps = [].

mentions_graphics(Action, Comp) :-
	(Action = remove(Term);
	    Action = add(Term)),
	(Term = graphical_info(Base, _Attr, _Val);
	    (Term = node_refinement(AuxComp, _Attr, _Val);
		Term = arc_info(AuxComp, complete, _Val)),
	    get_host(AuxComp, Base)),
	    (Comp = Base; find_ghosts(Base, Comp)).

internal_extent_jiggered(Model, Slot, ExtChgs) :-
	setof(Change, get_extent_change(Model, Slot, Change), ExtChgs), !;
	ExtChgs = [].

get_extent_change(Model, Slot, Comp-Was) :-
	saved_state(Model, Slot, remove(graphical_info(Comp, What, _))),
	saved_state(Model, Slot, add(graphical_info(Comp, What, _))),
% do not redraw contents if parent changed -- offset will be wrong
	\+ saved_state(Model, Slot, add(subsystem(_, Comp))),
	member(What, [bounding_box, internal_extent]),
	image:add_to_translation([0,0,1,1], Comp, Was).
% world-class yuckiness -- if the border has been dragged, both attributes will
% be changed so there will be two entries, but they will both be null
% transforms so that's all right :-)

clear_autosave(Model, Name) :-
	(is_toplevel(Model),
	    scrub_autosave(Model), /* remove previous file */
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(Model, AutoName)),
	    scrub_autosave(Model), /* remove anything where new file to go */
	    assert(autosave_file_is(Model, AutoName));
	true).

new_autosave(Desktop, ModelName) :-
	initialize_ring(Desktop),
	use_pref_dir(Dir),
	append_atoms([Dir, '/', ModelName, '.smx'], NewAutoName),
	assert(autosave_file_is(Desktop, NewAutoName)),
        assert(translation_info(Desktop, [top_level_is(Desktop)])).
	
check_autosave(Model, Name, IdSwaps, Tweaked) :-
	state:shows_model(Win, Model),
	set_save_status(Win, safe),
	draw:update_ability(Model, undo, edit, 'Undo', 0),
	draw:update_ability(Model, redo, edit, 'Redo', 0),
	draw:update_ability(Model, save, file, 'Save', 0),
	(is_toplevel(Model), !,
	    initialize_ring(Model),
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(Model, AutoName)),
	    (output:my_file_exists(AutoName),
	     do_dialogue("Restore option", question,
			 "Simile left a log file of unsaved changes when this model was last edited. Do you want to apply these changes now?",
			 yesno, yes), !,
		open_native(AutoName, read, Load),
		(IdSwaps = copy, !,
		    setof(Comp-Comp, contains(Model, Comp), UseIdSwaps);
		 UseIdSwaps = [Model-Model | IdSwaps]),
		restore_save_file(Model, Load, UseIdSwaps, UState, RState),
		Tweaked = 1,
		draw:update_ability(Model, undo, edit, 'Undo', UState),
		draw:update_ability(Model, redo, edit, 'Redo', RState),
		save_allowed(Model, CanSave),
		draw:update_ability(Model, save, file, 'Save', CanSave),
		set_save_status(Win, risky);
	     output:my_delete_file(AutoName),
	     (IdSwaps = copy, !,
		 assert(translation_info(Model, [top_level_is(Model)]));
	     assert(translation_info(Model, [top_level_is(Model),
				     translated([Model-Model | IdSwaps])]))));
	finish_move(Model, 0)).
	    
scrub_autosave(Model) :-
	(is_toplevel(Model),
%	    retractall(genint(_,_)),
	    retract(autosave_file_is(Model, AutoName)),
	    output:my_file_exists(AutoName),
	    output:my_delete_file(AutoName),
	    fail;
	true).

is_toplevel(Model) :-
	m_class:has_part(root, Model).

is_module(Model) :-
	m_class:has_part(library, Model).

/* This is one place where you have to take account of the fact that you
cannot rely on Windows to give you the file name extension in any particular
case... */

make_auto_name(Name, NewExtn, AutoName) :-
	name(Name, NameStr),
	member(Extn, [".sml", ".SML", ".sim", ".SIM", ".ame", ".AME",
		      ".pl", ".PL"]), /* .pl included to gruntle Alastair */
	append(BaseStr, Extn, NameStr), !,
	append(BaseStr, NewExtn, AutoNameStr),
	name(AutoName, AutoNameStr).

:- dynamic(use_temp_dir/1).
/* this is set in state.pl */

use_pref_dir(Dir) :-
	use_temp_dir(PDir),
	output:safe_tcl_eval([file, dirname, br(PDir)], DirStr),
	name(Dir, DirStr).
