%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   PROCEDURES FOR SAVING AND RESTORING PREVIOUS MODEL STATES             %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sicstus_module(backup, [initialize_ring/0, finish_move/1, restart_move/0,
			get_save_status/2, set_save_status/2, save_allowed/1,
			go_back/1, go_forward/1, make_auto_name/3,
			clear_autosave/2, check_autosave/3, scrub_autosave/1,
			is_toplevel/1, use_temp_dir/1, into_save_file/1]).

sicstus_use_module([library(lists), sp_only, ame_gen, database, utility]).

:- dynamic(autosave_file_is/1).

:- dynamic(save_status_of/2).

set_save_status(Model, Stat) :-
	retractall(save_status_of(Model, _)),
	assert(save_status_of(Model, Stat)).

get_save_status(Model, Stat) :-
	save_status_of(Model, Stat).

backup_states(32).

:- dynamic(saved_state/2).

initialize_ring :-
	retractall(saved_state(_,_)),

/* No need to duplicate whole database with current system...
	assert(saved_state(phase, record_even)),
	(attack_database(call, P),
		assert(saved_state(record_even, P)),
		fail;
*/
	(fetch_update(_),
		fail;
	assert(saved_state(first, 1)),
	assert(saved_state(last, 1)),
	assert(saved_state(current, 1))).

go_back(Further) :-
	retract(saved_state(current, Current)),
	wrap(Prev, Current),
	reverse_changes(Prev),
	into_save_file(undo),
	assert(saved_state(current, Prev)),
	(saved_state(first, Prev), !,
		Further = 0;
	Further = 1).

go_forward(Further) :-
	retract(saved_state(current, Current)),
	wrap(Current, Next),
	enact_changes(Current),
	into_save_file(redo),
	assert(saved_state(current, Next)),
	(saved_state(last, Next), !,
		Further = 0;
	Further = 1).

finish_move(Model) :-
	m_update:contains(ShownModel, Model),
		state:shows_model(Win, ShownModel),
		set_save_status(Win, risky),
		fail;
	maintain:update_ability(undo, edit, 'Undo', 1),
	maintain:update_ability(redo, edit, 'Redo', 0),
	save_allowed(CanSave),
	maintain:update_ability(save, file, 'Save', CanSave),
	retract(saved_state(first, First)),
	retract(saved_state(last, _)),
	retract(saved_state(current, Current)),
	record_changes(Current),
	update_autosave(Current),
	wrap(Current,Next),
	(First = Next, !,
		wrap(Next, Following),
		assert(saved_state(first, Following));
	assert(saved_state(first, First))),
	assert(saved_state(last, Next)),
	assert(saved_state(current, Next)).

/* This undoes anything that has happened since the last finish_move; needed
after putting up restore dialog, to be sure we are restoring from the same state
we saved from. */

:- dynamic(counted_fns/1).
counted_fns(0).

save_allowed(OK) :-
	\+ state:get_edition(evaluation), OK = 1;
	state:eval_fn_limit_is(Limit),
	retract(counted_fns(OldTot)),
	assert(counted_fns(0)),
	(find_type(_Fun, function),
	    retract(counted_fns(Were)),
	    Are is Were+1,
	    assert(counted_fns(Are)),
	    Are > Limit,
	    (OldTot > Limit;
	    output:safe_tcl_eval(['NotifyOverLimit', Limit], _)), !,
	    OK = 0;
	OK = 1).

	
restart_move :-
	fetch_update(DP),
		(DP = remove(P),
			database:assert(P);
		DP = add(P),
			database:retract(P)),
		fail;
	true.

wrap(Old, New) :-
	(backup_states(Old), New = 1;
	integer(Old), New is Old + 1;
	integer(New), Old is New - 1), !.	

record_changes(Slot) :-
	retractall(saved_state(Slot, _)),
		fetch_update(DP),
		assert(saved_state(Slot, DP)),
		fail;
	true.

update_autosave(Slot) :-
	(setof(Acts, saved_state(Slot, Acts), ActList), !; ActList = []),
	into_save_file(ActList).

into_save_file(ActList) :-
	autosave_file_is(File), !,
	on_exception(Lossage, (open(File, append, Save),
				  writeq(Save, ActList),
				  write(Save, '.\n'),
				  close(Save)),
		(sicstus_format_to_chars("Could not create an autosave file for this model. ~w. This may mean that the model was loaded from a read-only file system. No autosave data will be stored until the model is saved somewhere else.", [Lossage], Wibble),
	do_dialogue("Autosave warning!", warning, Wibble, ok, _),
	retract(autosave_file_is(_)))); true.

restore_save_file(File, UndoOn, RedoOn) :-
	open(File, read, Load),
	repeat,
	read(Load, ActSpec),
	(ActSpec = end_of_file,
		saved_state(current, Here),
		(saved_state(first, Here), !,
			UndoOn = 0;
		UndoOn = 1),
		(saved_state(last, Here), !,
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
	repeat_action(ActSpec),
		fail).

repeat_action(ActSpec) :-
	ActSpec = undo,
		retract(saved_state(current, Current)),
		wrap(Prev, Current), !,
		(saved_state(Prev, remove(P)),
			database:assert(P),
			fail;
		saved_state(Prev, add(P)),
			database:retract(P),
			fail;
		assert(saved_state(current, Prev)));
	ActSpec = redo,
		retract(saved_state(current, Current)),
		wrap(Current, Next), !,
		(saved_state(Current, add(P)),
			database:assert(P),
			fail;
		saved_state(Current, remove(P)),
			database:retract(P),
			fail;
		assert(saved_state(current, Next)));
	ActSpec = [_|_],
	        retract(saved_state(first, First)),
		retract(saved_state(last, _)),
		retract(saved_state(current, Current)),
		retractall(saved_state(Current, _)),
		enact_from_file(Current, ActSpec),
		wrap(Current,Next),
		(First = Next, !,
			wrap(Next, Following),
			assert(saved_state(first, Following));
		assert(saved_state(first, First))),
		assert(saved_state(last, Next)),
		assert(saved_state(current, Next)).

enact_from_file(_, []).

enact_from_file(Slot, [Act | Rest]) :-
	(Act = add(P),
		database:assert(P);
	Act = remove(P), 
		(database:retract(P), !;
		sicstus_format_to_chars("The log file specified the removal from the database of the term ~w at a point where this term was not in the database. This is probably non-fatal, but it might be a good idea to save the restored file and reload it in a new program run.", [P], Mess), 
		do_dialogue("Problem restoring state", warning, Mess, ok, _))),
	assert(saved_state(Slot, Act)),
	enact_from_file(Slot, Rest).

/* The routines to re-enact earlier states also adjust the recorded state to
reflect the current state because this is probably quicker than copying the
current state over again (removed because no longer needed!) */

reverse_changes(Slot) :-
	(saved_state(Slot, add(P)),
		database:retract(P),
		fail;
	saved_state(Slot, remove(P)),
		database:assert(P),
		fail;
	true).

enact_changes(Slot) :-
	(saved_state(Slot, remove(P)),
		database:retract(P),
		fail;
	saved_state(Slot, add(P)),
		database:assert(P),
		fail;
	true).

clear_autosave(Model, Name) :-
	(is_toplevel(Model),
	    scrub_autosave(Model), /* remove previous file */
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(AutoName)),
	    scrub_autosave(Model), /* remove anything where new file to go */
	    assert(autosave_file_is(AutoName));
	true).
	
check_autosave(Model, Name, Tweaked) :-
	state:shows_model(Win, Model),
	set_save_status(Win, safe),
	maintain:update_ability(undo, edit, 'Undo', 0),
	maintain:update_ability(redo, edit, 'Redo', 0),
	maintain:update_ability(save, file, 'Save', 0),
	(is_toplevel(Model), !,
	    initialize_ring,
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(AutoName)),
	    (output:my_file_exists(AutoName), !,
		(do_dialogue("Restore option", question,
			  "Simile left a log file of unsaved changes when this model was last edited. Do you want to apply these changes now?",
			  yesno, yes), !,
		    restore_save_file(AutoName, UState, RState),
		    Tweaked = 1,
		    maintain:update_ability(undo, edit, 'Undo', UState),
		    maintain:update_ability(redo, edit, 'Redo', RState),
		    save_allowed(CanSave),
		    maintain:update_ability(save, file, 'Save', CanSave),
		    set_save_status(Win, risky);
		output:my_delete_file(AutoName));
	    true);
	finish_move(Model)).
	    
scrub_autosave(Model) :-
	(is_toplevel(Model),
	    database:clear_model([genint/2]),
	    retract(autosave_file_is(AutoName)),
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
