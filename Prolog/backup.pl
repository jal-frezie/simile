%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                                                                         %%%
%%%   PROCEDURES FOR SAVING AND RESTORING PREVIOUS MODEL STATES             %%%
%%%                                                                         %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sicstus_module(backup, [initialize_ring/1,
			scrap_move/0, finish_move/2, restart_move/0,
			get_save_status/2, set_save_status/2, save_allowed/2,
			go_back/1, go_forward/1, make_auto_name/3,
			new_autosave/2, clear_autosave/2, check_autosave/4,
			scrub_autosave/1,
			is_toplevel/1, append_to_log/2]).

sicstus_use_module([library(lists), sp_only, ame_gen, database,
		    utility, state]).

:- dynamic(autosave_file_is/2).

:- dynamic(autosave_suspended/1).

:- dynamic(save_status_of/2).

:- dynamic(running_session/3).

set_save_status(Model, Stat) :-
    retractall(save_status_of(Model, _)),
    assert(save_status_of(Model, Stat)),
    member(Stat-CanSave, [safe-0, risky-1]),
    draw><update_ability(Model, file, ['Save'], [CanSave]).

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

exit_two_click_op :-
	get_phase(targetting),
	/* halfway through two-click link addition -- tidy up. */
	event><retractall(instant_link(_)),
	advance_phase_to(peruse),
	get_line_start_obj(New),
	New is_of_sort cloud,
	draw><off(New).

synchronize_graphics(LostExtents, Redrawn) :-
    event><remove_highlights,
	all(draw, adjust_submodel_internals, [build(LostExtents)]),
	all(draw, redisplay_border, [build(Redrawn)]),
	all(event, make_any_links_follow, [build(Redrawn)]),
	all(user, arg, [unify(1), build(LostExtents), build(Submodels)]),
	all(event, tweak_link_connections, [build(Submodels), unify(dummy)]).
	% needed because link database entries do not change when ends moved

go_back(Model) :-
	(exit_two_click_op, !;
	    /* If removing floater, end operation as user did not intend
	    going back further */
	restart_move,
	retract(saved_state(Model, current, Current)),
	wrap(Prev, Current),
	purge_graphics(Model, Prev, LostExtents, Redrawn),
	enact_changes(Model, Prev, reverse),
	synchronize_graphics(LostExtents, Redrawn),
	update_autosave(Model, Prev, no),
	assert(saved_state(Model, current, Prev))),
	set_edit_abilities(Model).

go_forward(Model) :-
	exit_two_click_op, fail; % should never happen
	restart_move,
	saved_state(Model, current, Current),
	(running_session(Model, Stm, IdMap),
	    saved_state(Model, last, Current), !,
	    % playing a session and no outstanding undos, so read session file
	    retract(running_session(Model, Stm, IdMap)),
	    get_ring_point(Model, Current),
	    retractall(saved_state(Model, Current, _)),
	    run_move_from_file(Model, Stm, Current, IdMap, NewIdMap),
	    (NewIdMap = done, !;
	      assert(running_session(Model, Stm, NewIdMap)));
	  retract(saved_state(Model, current, Current)),
	    wrap(Current, Next),
	    assert(saved_state(Model, current, Next))),
	purge_graphics(Model, Current, LostExtents, Redrawn),
	enact_changes(Model, Current, forward),
	synchronize_graphics(LostExtents, Redrawn),
	update_autosave(Model, Current, yes),
% if running (or just finished) session, retain pauses
	(var(IdMap), !;
	    append_to_log(Model, pause)),
	set_edit_abilities(Model).

purge_graphics(Model, Prev, LostExtents, Redrawn) :-
	internal_extent_jiggered(Model, Prev, LostExtents),
	appearance_changes(Model, Prev, LostExtents, Redrawn),
	all(draw, off, [build(Redrawn)]). /* safe if they don't exist yet */

finish_move(EditedModel, ChangeExec) :-
	\+ anything_done, !;
	m_update><contains(Model, EditedModel),
	set_save_status(Model, risky),
	/* Only proceed for toplevel window containing model */
	is_toplevel(Model),
	(ChangeExec = 0;
	  ChangeExec = 1,
	    m_update><add_parameter(Model, 1, c_new, 0),
	    output><tk_alter_model(Model)),
	get_ring_point(Model, Current),
	record_changes(Model, Current),
	update_autosave(Model, Current, yes),
	set_edit_abilities(Model).

get_ring_point(Model, Current) :-
	retract(saved_state(Model, first, First)),
	retract(saved_state(Model, last, _)),
	retract(saved_state(Model, current, Current)),
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
			my_assert(P);
		DP = add(P),
			my_retract(P)),
		fail;
	true.

:- dynamic(counted_fns/1).
counted_fns(0).

save_allowed(Model, OK) :-
	get_edition_and_limit(Edn, Limit), !,
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
	    assert(autosave_suspended(Model)),
		Win shows_model Model,
		output><safe_tcl_eval(['NotifyOverLimit', Win, Edn, Limit],
					_)), !,
	    OK = 0;
	retractall(autosave_suspended(Model)),
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

update_autosave(Model, Slot, Fwd) :-
	(setof(Act, point_act(Model, Slot, Fwd, Act), ActList), !;
	    ActList = []),
	into_save_file(Model, ActList).

point_act(Model, Slot, Fwd, Act) :-
	saved_state(Model, Slot, Go),
	(Fwd = yes, Act = Go;
	  Fwd = no, select(Go, [add(Fact), remove(Fact)], [Act])).
	
into_save_file(Model, ActList) :-
	autosave_suspended(Model), !;
	(retract(translation_info(Model, TransInfo)), !,	    
	    append(TransInfo, ActList, FullList);
	FullList = ActList),
	append_to_log(Model, FullList).

append_to_log(Model, Action) :-
	autosave_file_is(Model, File),
	(open_native(File, append, Save) ->
	     write_with_breaks(Save, Action),
	     close(Save);
	 query(no_autosave(File), warning, top, [ok], _),
	 retract(autosave_file_is(Model, _))).

restore_save_file(Model, Load, IdSwaps) :-
	read(Load, ActSpec),
	(ActSpec = end_of_file,
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
	    restore_save_file(Model, Load, NewIdSwaps)).

run_move_from_file(Model, Stm, Current, IdSwaps, NewIdSwaps) :-
	read(Stm, ActSpec),
	(ActSpec = end_of_file,
	    close(Stm),
	    NewIdSwaps = done;
	  ActSpec = pause,
	    NewIdSwaps = IdSwaps;
	  enact_from_file(Model, Current, IdSwaps, MidIdSwaps, ActSpec, yes),
	    run_move_from_file(Model, Stm, Current, MidIdSwaps, NewIdSwaps)).

set_edit_abilities(Model) :-
	saved_state(Model, current, Here),
	(saved_state(Model, first, Here), !,
	    CanSave = 0,
	    UndoOn = 0;
	save_allowed(Model, CanSave),
	    UndoOn = 1),
	(saved_state(Model, last, Here),
	    \+ running_session(Model, _Stm, _Trans), !,
	    RedoOn = 0;
	 RedoOn = 1),
	draw><update_ability(Model, file, ['Save'], [CanSave]),
	draw><update_ability(Model, edit, ['Undo', 'Redo'], [UndoOn, RedoOn]).

repeat_action(Model, ActSpec, IdSwaps, NewIdSwaps) :-
/* undo and redo clauses no longer needed because the acts are put into the
	autosave file in full (needed for sessions) but clauses left in in case
	we are restoring a crash record from an older version */
	ActSpec = undo,
	    NewIdSwaps = IdSwaps,
	    retract(saved_state(Model, current, Current)),
	    wrap(Prev, Current), !,
	    enact_changes(Model, Prev, reverse),
	    assert(saved_state(Model, current, Prev));
	ActSpec = redo,
	    NewIdSwaps = IdSwaps,
	    retract(saved_state(Model, current, Current)),
	    wrap(Current, Next), !,
	    enact_changes(Model, Current, forward),
	    assert(saved_state(Model, current, Next));
	ActSpec = pause,
	    NewIdSwaps = IdSwaps;
	(ActSpec = []; ActSpec = [_|_]),
	    get_ring_point(Model, Current),
	    retractall(saved_state(Model, Current, _)),
	    enact_from_file(Model, Current, IdSwaps, NewIdSwaps, ActSpec, no).

enact_from_file(Model, Slot, IdSwaps, NewIdSwaps, Acts, Animate) :-
	(Acts = [top_level_is(OldModel) | More], !,
	    append(SW1, [_-Model | SW2], IdSwaps),
	    append(SW1, [OldModel-Model | SW2], MidIdSwaps);
	More = Acts,
	    MidIdSwaps = IdSwaps),
	(More = [translated(PrevIdSwaps) | DBActs] , !,
	    merge_id_swaps(MidIdSwaps, PrevIdSwaps, TransIdSwaps);
	DBActs = More,
	    TransIdSwaps = MidIdSwaps),
	swap_all_ids(Model, Slot, DBActs, TransIdSwaps, NewIdSwaps, TransActs),
	(Animate = yes /* ,
	    purge_graphics(Model, Slot, Reshaped, Redrawn),
	    enact_list(TransActs, forward),
	    synchronize_graphics(Reshaped, Redrawn) */ ;
	  Animate = no,
	     enact_list(TransActs, forward)).

swap_all_ids(_Model, _Slot, [], IdSwaps, IdSwaps, []).
swap_all_ids(Model, Slot, [Act | MoreActs], IdSwaps, NewIdSwaps,
	     [TransAct | MoreTransActs]) :-
	Act =.. [Motion, OldTerm],
	swap_ids(OldTerm, IdSwaps, MidIdSwaps, Term),
	TransAct =.. [Motion, Term],
	    (select(Motion, [add, remove], [UnMotion]),
	    TransUnAct =.. [UnMotion, Term],
	    retract(saved_state(Model, Slot, TransUnAct)), !;
	  assert(saved_state(Model, Slot, TransAct))),
	swap_all_ids(Model, Slot, MoreActs, MidIdSwaps, NewIdSwaps,
	     MoreTransActs).

/*
enact_from_file(_,_, I,I, []).

enact_from_file(Model, Slot, IdSwaps, NewIdSwaps, [Act | Rest]) :-
	((Act = add(OldP),
	    swap_ids(OldP, IdSwaps, MidIdSwaps, P),
	    my_assert(P);
	Act = remove(OldP), 
	    swap_ids(OldP, IdSwaps, MidIdSwaps, P),
		(my_retract(P), !;
                query([odd_log, P], warning, top, [ok], _))),
	assert(saved_state(Model, Slot, Act));
	Act = top_level_is(OldModel),
	    append(SW1, [_-Model | SW2], IdSwaps),
	    append(SW1, [OldModel-Model | SW2], MidIdSwaps);
	Act = translated(PrevIdSwaps),
	    merge_id_swaps(IdSwaps, PrevIdSwaps, MidIdSwaps)),
	enact_from_file(Model, Slot, MidIdSwaps, NewIdSwaps, Rest).
*/
merge_id_swaps(Swaps, [], Swaps).
merge_id_swaps(AtoCs, [A-B | MoreAtoBs], [B-C | MoreBtoCs]) :-
	select(A-C, AtoCs, MoreAtoCs),
	merge_id_swaps(MoreAtoCs, MoreAtoBs, MoreBtoCs).
	
swap_ids(OldTerm, Swaps, NewSwaps, NewTerm) :-
	OldTerm =.. [Header | Args],
	    member([Header | Template],
		   [[is_arc, arc],
		    [connection, node, node, arc],
		    [arc_type, arc, var],
		    [arc_info, arc, var, var],
		    [continues, arc, arc],
		    [is_node, node],
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
	    \+ m_class><is_part_of(NewArg, _),
	    \+ m_class><is_connector(NewArg, _), !,
	    MidSwaps = [Arg-NewArg | Swaps]),
	swap_args(Args, Templates, MidSwaps, NewSwaps, NewArgs).

sub_all(Swaps, Old, New, 0) :-
	member(Old-New, Swaps).		    
	
/* The routines to re-enact earlier states also adjust the recorded state to
reflect the current state because this is probably quicker than copying the
current state over again (removed because no longer needed!) */

enact_changes(Model, Slot, Dir) :-
	(setof(Act, saved_state(Model, Slot, Act), Acts), !,
	    enact_list(Acts, Dir);
	true).

enact_list(Acts, Dir) :-
	member(Dir-Template-Action,
	       [forward-remove(P)-my_retract(P),
		reverse-add(P)-my_retract(P),
		forward-add(P)-my_assert(P),
		reverse-remove(P)-my_assert(P)]),
	member(Action-SeqCheck,
	       [my_retract(P)-(\+ exist_pred(P)), my_retract(P)-exist_pred(P),
		my_assert(P)-exist_pred(P), my_assert(P)-(\+ exist_pred(P))]),
	member(Template, Acts),
	call(SeqCheck),
	call(Action),
	fail; true.
	       
exist_pred(P) :- member(P, [is_node(_), is_arc(_)]).

appearance_changes(Model, Slot, Reshapes, Comps) :-
	setof(Comp, Action^Base^(saved_state(Model, Slot, Action),
			    mentions_graphics(Action, Base),
                            (Comp = Base; find_ghosts(Base, Comp)),
			    \+ member(Comp-_, Reshapes)), Comps), !;
	Comps = [].

mentions_graphics(Action, Comp) :-
	(Action = remove(Term);
	  Action = add(Term)),
	(Term = graphical_info(Comp, _Attr1, _Val1);
	  (Term = node_refinement(Fn, _Attr2, _Val2);
	   Term = graphical_info(Fn, along, _Val3)), % bowtie fn 'along' flow
	    get_host(Fn, Comp);
	  Term = arc_info(Comp, complete, _Val4)).
% things that make submodel conditional still not handled

internal_extent_jiggered(Model, Slot, ExtChgs) :-
	setof(Change, get_extent_change(Model, Slot, Change), ExtChgs), !;
	ExtChgs = [].

get_extent_change(Model, Slot, Comp-Was) :-
	saved_state(Model, Slot, remove(graphical_info(Comp, What, _))),
	saved_state(Model, Slot, add(graphical_info(Comp, What, _))),
% do not redraw contents if parent changed -- offset will be wrong
	\+ saved_state(Model, Slot, add(subsystem(_, Comp))),
	member(What, [bounding_box, internal_extent]),
	image><add_to_translation([0,0,1,1], Comp, Was).
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
	set_save_status(Model, safe),
	draw><update_ability(Model, file, ['Save'], [0]),
	draw><update_ability(Model, edit, ['Undo', 'Redo'], [0,0]),
	(is_toplevel(Model), !,
	    initialize_ring(Model),
	    make_auto_name(Name, ".smx", AutoName),
	    assert(autosave_file_is(Model, AutoName)),
	    (output><my_file_exists(AutoName),
               query(offer_restore, question, top, [ignore, apply], apply), !,
		open_native(AutoName, read, Load),
		(IdSwaps = copy, !,
		    setof(Comp-Comp, contains(Model, Comp), UseIdSwaps);
		 UseIdSwaps = [Model-Model | IdSwaps]),
		restore_save_file(Model, Load, UseIdSwaps),
		Tweaked = 1,
		set_edit_abilities(Model),
		set_save_status(Model, risky),
		retractall(autosave_file_is(Model, _)),
		assert(autosave_file_is(Model, AutoName));
	     output><my_delete_file(AutoName),
	     (IdSwaps = copy, !,
		 assert(translation_info(Model, [top_level_is(Model)]));
	     assert(translation_info(Model, [top_level_is(Model),
				     translated([Model-Model | IdSwaps])]))));
	finish_move(Model, 0)).
	    
scrub_autosave(Model) :-
	(is_toplevel(Model),
%	    retractall(genint(_,_)),
	    retract(autosave_file_is(Model, AutoName)),
	    output><my_file_exists(AutoName),
	    output><my_delete_file(AutoName),
	    fail;
	true).

is_toplevel(Model) :-
	m_class><has_part(root, Model).

/* This is one place where you have to take account of the fact that you
cannot rely on Windows to give you the file name extension in any particular
case... */

make_auto_name(Name, NewExtn, AutoName) :-
	name(Name, NameStr),
	(member(Extn, [".sml", ".SML", ".sim", ".SIM", ".ame", ".AME",
		      ".pl", ".PL", ".ses", ".SES"]),
	    append(BaseStr, Extn, NameStr);
	BaseStr = NameStr), !,
	append(BaseStr, NewExtn, AutoNameStr),
	name(AutoName, AutoNameStr).
