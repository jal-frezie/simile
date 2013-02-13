/* forms.pl
-----------
Code for putting up dialogue boxes, progress boxes, etc */

sicstus_module(forms, [pick_equation/2, eqn_for/2, do_equation_dialog/2,
		       do_disag_dialog/4, do_relation_dialog/9,
		       do_text_item_dialog/5,
		       get_load_file/2, get_save_file/2,
		       get_program_file/3, get_import_file/3,
		       start_progress_dialogue/1,
		       finish_progress_dialogue/0, reassure_user/2]).

sicstus_use_module([library(lists),
		    output, m_update, ame_gen, sp_only, utility]).

pick_equation(Comp, Eqn) :-
	find_node_with_data(Comp, _, Func),
	(find_type(Comp, state),
	    get_av_pair(Func, 0, spec, PairList), !,
	    expand_spec(PairList, Eqn);
	Comp is_of_sort has_function,
	    (eqn_for(Func, Eqn), !;
		Eqn = '')).

eqn_for(Func, Eqn) :-
	(get_av_pair(Func, 0, spec, Eqn), atom(Eqn), \+ Eqn = [], !;
	 get_av_pair(Func, 0, value, EqnExpr),
	    sicstus_write_to_chars(EqnExpr, EqnStr),
	    name(Eqn, EqnStr)).

expand_spec(B on A, [[A, B]]).
expand_spec((B on A, MoreSpec), [[A, B] | MorePairs]) :-
	expand_spec(MoreSpec, MorePairs).

/* the equation dialogue will only exit when a coherent set of 
inputs have been 
entered; if they are not, then update_equation fill fail after 
putting new info 
into the dialog box, and interact_equation will be called again and 
return new 
values. */

do_equation_dialog(Win, Part) :-
	caption_for(Part, Caption),
	get_host(Part, ClickedObj),
	(find_type(ClickedObj, state), !,
	    TitleForm = rules_for;
	 ClickedObj is_of_sort discrete, !,
	    TitleForm = cause_for;
	ClickedObj is_of_sort init_eval, !,
	    TitleForm = init_val_for;
	TitleForm = equation_for),
	list_index_meanings(Part, ISpecs),
	all(forms, index_names_and_sizes, [build(ISpecs), build(IndexList),
					      build(_Sz)]),
	pick_equation(ClickedObj, Equation),
	(get_av_pair(Part, 0, units, Units), !,
	    analyze_array(Units, Base, Dims);
	Base = '',
	    Dims = []),
	(get_av_pair(Part, 0, table_data, TableSpec),
	    permutation(TableSpec, [file=FilePath, data=DataField,
				    indices=Indices, current=Values,
				    units=TUnits, bounds=Bounds | _R]), !,
	    (FilePath = '/graph/', !,
		append([FilePath | DataField], [Bounds | Indices], TableList),
		TableTrans = [[], []],
		TableVals = br(Values);
	    TableList = [FilePath, DataField | Indices],
		append(Bounds, [TUnits], TableTypes), 
		all(event, insert_mem_list,
		    [build(TableTypes), unify(ClickedObj), build(TableTrans)]),
		dialogue'><'reverse_engineer(Values, TableTrans, 1, TableVals));
	TableList = '', TableTrans = '', TableVals = '{}'),

	(ClickedObj is_of_sort line -> AttType = 2; AttType = 0),
	(get_av_pair(ClickedObj, AttType, description, Desc), !; Desc = ''),
	(get_av_pair(ClickedObj, AttType, comment, Comment), !; Comment = ''),

	(get_av_pair(Part, 0, min_val, Min), !;
		get_default_lower_limit(Part, Min)),
	(get_av_pair(Part, 0, max_val, Max), !;
		get_default_upper_limit(Part, Max)),
	/* Node is an input parameter if a ghost whose base has no
		associated function */
	find_all_comps(Parent, Part),
	get_all_enum_types(Parent, ETList),
	is_parameter(ClickedObj, Is_P),
	
	create_equation(Win, TitleForm, Caption, IndexList, ETList),
	(TitleForm = rules_for, !,
	    list_evt_captions(Part, EvtCapts),
	    all(forms, list_evt_efct_pairs,
		[unify(Equation), build(EvtCapts), append(ToPass, [])]);
	  ToPass = Equation),
	fill_equation(ToPass, Base, Dims, Is_P, Desc, Comment, Min, Max),
	fill_table(Part, TableList, TableVals), % calls interaction from tcl
	destroy_equation.

list_evt_efct_pairs(AVList, Capt, [Capt, Efct]) :-
	member([Capt, Efct], AVList), !;
	Efct = ''.

index_names_and_sizes(ind_spec(Name, Posn, Dim, _Link), Meaning, Dim) :-
	sicstus_format_to_chars("Dimension ~d of ~a (~w)", [Posn, Name, Dim],
				MeaningStr),
	name(Meaning, MeaningStr).

/* might change these one day so, e.g., compartments have
automatic lower limit of 0, but not yet. */

get_default_lower_limit(_, '').

get_default_upper_limit(_, '').

/* do_disag_dialog/4: This is called when disaggregate is selected. 
First it asks for the disaggregation parameters (this shouldn't 
really be necessary). */

do_disag_dialog(Win, Model, P_list, New_P_List) :-
	caption_for(Model, Capt),
	tk_do_disag_dialog(Win, Capt, P_list, New_P_Strs),
	strings_to_atoms(New_P_Strs, New_P_List).

do_relation_dialog(Win, Relation, Type, Fields, State, OldComment,
		   OKd, NewStat, NewComment) :-
	caption_for(Relation, Capt),
	tk_do_relation_dialog(Win, Capt, Type, Fields, State, OldComment,
			      OKdStr, NewStr, NewCommentStr),
	strings_to_atoms([OKdStr, NewCommentStr | NewStr],
			 [OKd, NewComment | NewStat]).

do_text_item_dialog(Win, Text, State, OKd, NewState) :-
	caption_for(Text, Capt),
	tk_do_text_item_dialog(Win, Capt, State, OKdStr, NewStr),
	strings_to_atoms([OKdStr | NewStr],
			 [OKd | NewState]).

strings_to_atoms([], '').

strings_to_atoms(StNest, ANest) :-
        StNest = [St | Sts],
        (member(St, [[], [_|_]]), !, /* nested */
            all(forms, strings_to_atoms, [build(StNest), build(ANest)]);
        (St = 123,
	/* If tcl has put it in curlies remove them */
	    append(InS, [125], Sts), !;
	 InS = StNest),
            name(ANest, InS)).

get_load_file(Parent, FileName) :-
	get_file_name('untitled.sml', 'Open file:', 0, Parent, FileName).

get_save_file(Model, FileName) :-
	get_file_name('untitled.sml', 'Save as:', 1, Model, FileName).

get_import_file(Preferred, Model, FileName) :-
	get_file_name(Preferred, 'Import from:', 0, Model, FileName),
        \+ FileName = ''.

get_program_file(Preferred, Model, FileName) :-
	get_file_name(Preferred, 'Export to:', 1, Model, FileName),
        \+ FileName = ''.

start_progress_dialogue(Win) :-
	tk_start_progress_dialogue(Win).

reassure_user(Key, Lits) :-
	tk_update_infobox(Key, Lits).

finish_progress_dialogue :-
	tk_finish_progress_dialogue.
