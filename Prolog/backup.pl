%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   PROCEDURES FOR SAVING AND RESTORING PREVIOUS MODEL STATES             %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sicstus_module(backup, [initialize_ring/1, finish_move/1, restart_move/0,
			get_save_status/2, set_save_status/2, save_allowed/2,
			go_back/2, go_forward/2, make_auto_name/3,
			clear_autosave/2, check_autosave/3, scrub_autosave/1,
			is_toplevel/1, use_temp_dir/1, into_save_file/2]).

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

initialize_ring(Model) :-
	retractall(saved_state(Model, _,_)),

/* No need to duplicate whole database with current system...
	assert(saved_state(phase, record_even)),
	(attack_database(call, P),
		assert(saved_state(record_even, P)),
		fail;
*/
	(fetch_update(_),
		fail;
	assert(saved_state(Model, first, 1)),
	assert(saved_state(Model, last, 1)),
	assert(saved_state(Model, current, 1))).

go_back(Model, Further) :-
	retract(saved_state(Model, current, Current)),
	wrap(Prev, Current),
	reverse_changes(Model, Prev),
	into_save_file(Model, undo),
	assert(saved_state(Model, current, Prev)),
	(saved_state(Model, first, Prev), !,
		Further = 0;
	Further = 1).

go_forward(Model, Further) :-
	retract(saved_state(Model, current, Current)),
	wrap(Current, Next),
	enact_changes(Model, Current),
	into_save_file(Model, redo),
	assert(saved_state(Model, current, Next)),
	(saved_state(Model, last, Next), !,
		Further = 0;
	Further = 1).

finish_move(EditedModel) :-
	m_update:contains(Model, EditedModel),
	state:shows_model(Win, Model),
	set_save_status(Win, risky),
	/* Only proceed for toplevel window containing model */
	is_toplevel(Model),
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
	\+ state:get_edition(evaluation), !, OK = 1;
	state:eval_fn_limit_is(Limit),
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
		output:safe_tcl_eval(['NotifyOverLimit', Limit], _)), !,
	    OK = 0;
	OK = 1).

	
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
	on_exception(Lossage, (open(File, append, Save),
				  write_with_breaks(Save, ActList),
				  close(Save)),
		(sicstus_format_to_chars("Could not create an autosave file for this model. ~w. This may mean that the model was loaded from a read-only file system. No autosave data will be stored until the model is saved somewhere else.", [Lossage], Wibble),
	do_dialogue("Autosave warning!", warning, Wibble, ok, _),
	retract(autosave_file_is(Model, _)))); true.

restore_save_file(Model, File, UndoOn, RedoOn) :-
	open(File, read, Load),
	repeat,
	read(Load, ActSpec),
	(ActSpec = end_of_file,
		saved_state(Model, current, Here),
		(saved_state(Model, first, Here), !,
			UndoOn = 0;
		UndoOn = 1),
		(saved_state(Model, last, Here), !,
			RedoOn = 0;
		RedoOn = 1),
		close(Load);
		/* now load the mirror of the current state so I can continue to
			update undos and redos -- no longer needed
		saved_state(phase, Record),
		retractall(saved_state(Record, _)),
		(attack_database(call, P),
			assert(saved_state(Record, P)),
			fail;
		true); */
	repeat_action(Model, ActSpec),
		fail).

repeat_action(Model, ActSpec) :-
	ActSpec = undo,
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
		retract(saved_state(Model, current, Current)),
		wrap(Current, Next), !,
		(saved_state(Model, Current, add(P)),
			database:assert(P),
			fail;
		saved_state(Model, Current, remove(P)),
			database:retract(P),
			fail;
		assert(saved_state(Model, current, Next)));
	ActSpec = [_|_],
	        retract(saved_state(Model, first, First)),
		retract(saved_state(Model, last, _)),
		retract(saved_state(Model, current, Current)),
		retractall(saved_state(Model, Current, _)),
		enact_from_file(Model, Current, ActSpec),
		wrap(Current,Next),
		(First = Next, !,
			wrap(Next, Following),
			assert(saved_state(Model, first, Following));
		assert(saved_state(Model, first, First))),
		assert(saved_state(Model, last, Next)),
		assert(saved_state(Model, current, Next)).

enact_from_file(_,_, []).

enact_from_file(Model, Slot, [Act | Rest]) :-
	(Act = add(P),
		database:assert(P);
	Act = remove(P), 
		(database:retract(P), !;
		sicstus_format_to_chars("The log file specified the removal from the database of the term ~w at a point where this term was not in the database. This is probably non-fatal, but it might be a good idea to save the restored file and reload it in a new program run.", [P], Mess), 
		do_dialogue("Problem restoring state", warning, Mess, ok, _))),
	assert(saved_state(Model, Slot, Act)),
	enact_from_file(Model, Slot, Rest).

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

clear_autosave(Model, Name) :-
	(is_toplevel(Model),
	    scrub_autosave(Model), /* remove previous file */
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(Model, AutoName)),
	    scrub_autosave(Model), /* remove anything where new file to go */
	    assert(autosave_file_is(Model, AutoName));
	true).
	
check_autosave(Model, Name, Tweaked) :-
	state:shows_model(Win, Model),
	set_save_status(Win, safe),
	draw:update_ability(Model, undo, edit, 'Undo', 0),
	draw:update_ability(Model, redo, edit, 'Redo', 0),
	draw:update_ability(Model, save, file, 'Save', 0),
	(is_toplevel(Model), !,
	    initialize_ring(Model),
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(Model, AutoName)),
	    (output:my_file_exists(AutoName), !,
		(do_dialogue("Restore option", question,
			  "Simile left a log file of unsaved changes when this model was last edited. Do you want to apply these changes now?",
			  yesno, yes), !,
		    restore_save_file(Model, AutoName, UState, RState),
		    Tweaked = 1,
		    draw:update_ability(Model, undo, edit, 'Undo', UState),
		    draw:update_ability(Model, redo, edit, 'Redo', RState),
		    save_allowed(Model, CanSave),
		    draw:update_ability(Model, save, file, 'Save', CanSave),
		    set_save_status(Win, risky);
		output:my_delete_file(AutoName));
	    true);
	finish_move(Model)).
	    
scrub_autosave(Model) :-
	(is_toplevel(Model),
	    database:clear_model([genint/2]),
	    retract(autosave_file_is(Model, AutoName)),
	    output:my_file_exists(AutoName),
	    output:my_delete_file(AutoName),
	    fail;
	true).

is_toplevel(Model) :-
	m_class:has_part(root, Model).

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
/* this is set in main.pl */
