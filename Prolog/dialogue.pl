/* dialogues.pl
---------------
This contains all the code for interacting with the model 
representation via dialogue boxes. It uses the modules model_update 
(for querying and updating the database) and screen_output (to 
interact with the user interface). Note that only _modal_ dialogue 
boxes are handled here, i.e., those that won't leave the
user alone until values have been entered: the sort that sit quietly 
alongside
the rest of the program are handled through gui_input. */

:- module(dialogue, [do_equation_dialog/2, 
	do_disag_dialog/4, do_relation_dialog/9, test_eqn/8,
	get_load_file/1, get_save_file/1,
	get_program_file/2, get_import_file/2, 
start_progress_dialogue/1,
	finish_progress_dialogue/0, warn_runtime/0, 
reassure_user/1]).

:- use_module([library(lists), library(charsio), 
		m_update, ame_gen, files, output, utility, inters]).

/* helpers for sending function list */
pass_functions(LibFuns) :-
	setof(FnAtom, atomize_function(FnAtom), FuncList),
	BuiltIns = ['sum (array/list of scalars) returns scalar', 
		'product (array/list of scalars) returns scalar', 
		'count (array/list of any type) returns integer',
		'any (array/list of booleans) returns boolean',
		'all (array/list of booleans) returns boolean',
		'parent (numeral) returns integer',
		'channel_is (numeral) returns boolean',
		'init_time (numeral) returns numeral',
		'time (numeral) returns numeral',
		'dt (numeral) returns numeral',
		'last (any type) returns any type',
		'prev (numeral) returns scalar',
		'makearray (any type, numeral) returns array of type',
		'place_in (numeral) returns integer',
		'element (array of any type, integer) returns type',
		'size (submodel name) returns integer',
		'size (submodel name, numeral) returns integer',
		'least (array/list of scalars) returns scalar', 
		'greatest (array/list of scalars) returns scalar'],
	append([BuiltIns, LibFuns, FuncList], AllFns),
	prepare_equation(AllFns).
	
atomize_function(FnAtom) :-
	function(Functor, ResultSort, ArgSorts),
	spell_out([ResultSort | ArgSorts], 1),
	make_list(ArgSorts, String),
	format_to_chars("~a (~s) returns ~w", [Functor, String, 
ResultSort],
			FnChars),
	name(FnAtom, FnChars).

spell_out([], _).

spell_out([Dooda | Rest], N) :-
	((var(Dooda), Type = Dooda; Dooda =.. [_, Type]), !, 
		format_to_chars("type~d", [N], String),
		name(Type, String),
		M is N+1;
	M = N),
	spell_out(Rest, M).

make_list([Arg], Str) :- !,
	name(Arg, Str).

make_list([Arg | Args], Str) :-
	make_list([Arg], Str1),
	make_list(Args, Str2),
	append(Str1, [44, 32 | Str2], Str).

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
	(find_type(ClickedObj, compartment), !,
	    TypeBase = real,
	    TitleForm = 'Initial value';
	TitleForm = 'Equation'),
	format_to_chars("~a for ~a", [TitleForm, Caption], 
BoxHeaderStr),
	name(BoxHeader, BoxHeaderStr),
	list_index_meanings(Part, IndexList),
	length(IndexList, IndxCount),
	create_equation(Win, BoxHeader, IndexList),
	(get_av_pair(Part, 0, value, Equation), !;
		Equation = ''),
	(get_av_pair(Part, 0, units, Units), !;
	    Units = ''),
	(get_av_pair(Part, 0, table_data,
			      [file=FilePath, data=DataField,
			       indices=Indices | _Values]), !,
	    TableList = [FilePath, DataField | Indices];
	TableList = ''),
	(get_av_pair(Part, 0, description, Desc), !;
		Desc = ''),
	(get_av_pair(Part, 0, comment, Comment), !;
		Comment = ''),
	(get_av_pair(Part, 0, min_val, Min), !;
		get_default_lower_limit(Part, Min)),
	(get_av_pair(Part, 0, max_val, Max), !;
		get_default_upper_limit(Part, Max)),
	/* Node is an input parameter if a ghost whose base has no
		associated function */
	is_parameter(ClickedObj, Is_P),
	get_input_info(Part, Input_list),
	fill_equation(Equation, Units, Is_P, TableList,
		      Desc, Comment, Min, Max),
	fill_inputs(Input_list),
	retractall(input_list_is(_)),
	assert(input_list_is(Input_list)),
	repeat,
	interact_equation(Result_list),
	retract(input_list_is(Updated_list)),
	(Result_list = [], !, destroy_equation, fail; 
	update_equation(Part, IndxCount, Updated_list, TypeBase, Result_list)),
		/* fails if action does not complete edit */
	!, destroy_equation.
	/* last cut necessary because otherwise a retry will cause 
errors */

/* might change these one day so, e.g., compartments have
automatic lower limit of 0, but not yet. */

get_default_lower_limit(_, '').

get_default_upper_limit(_, '').

/* update_equation/5: This makes sure that if the user has entered a
new destination name or units for an existing variable they are added
to the model; it also adds them to the triples and checks that the
function makes sense. If it does not, it pops up a message in a
separate dialog box, then hands back to the main one, otherwise it
updates the actual values and removes the box. Cancel (signalled by
all args being empty) escapes from here.

Note that interact_equation should return strings for all these
things. */

update_equation(_,_, Input_list, _, [Node_st, Parm_st, New_unit_st]) :-
	(name(New_var, Node_st),
	    append(EarlyInputs,
		   [input_link(Link, New_var, _, Current_unit, _) | 
LateInputs],
		   Input_list), !,
		append(EarlyInputs, LateInputs, Other_inputs),
		get_term(Parm_st, New_param, Complaint0),
		get_term(New_unit_st, Units_for_new, Complaint1),
		append(Complaint0, Complaint1, Complaint2),
		(Complaint2 = [], !,
			(get_solo_list_depth(New_param, Depth), !,
				get_array_nesting(Current_unit, 
RealDepth),
				(\+ RealDepth = Depth, !,
					format_to_chars("Your local 
name for ~w,\c
~w, has ~d sets of brackets round it while it indicates an array 
nested to depth\c
~d -- this could be confusing. ", [New_var, New_param, Depth, 
RealDepth], 
							Complaint);
				(Units_for_new = '', !,
					NewInputUnit = Current_unit;
				NewInputUnit = Units_for_new,
					check_unit(Units_for_new, 
Current_unit, 2, Complaint)));
			format_to_chars("Your local name for ~w, ~w, 
contains characters that might cause the interpreter to mistake it 
for an expression, or vice versa. ", [New_var, New_param], 
Complaint));
		Complaint = Complaint2);
	    Complaint = "Select an input before supplying its new 
parameter name and/or local units"),
			
	(Complaint = [], !,
	    NewInputs = [input_link(Link, New_var, New_param, 
				      Current_unit, NewInputUnit)
			  | Other_inputs],
	    fill_inputs(NewInputs),
	    assert(input_list_is(NewInputs));
	do_dialogue("Problem with input data", warning, Complaint,
		    ok, _),
	    assert(input_list_is(Input_list))),
	fail.

	
update_equation(Function, IndxCount, InterInputs, TypeBase,
		[Eqn_st, Unit_st, Is_P_st,
		 Table_st, Desc_st, Comment_st, Min_st, Max_st]) :-
	name(Is_P, Is_P_st),
	member([Is_P, ParamsAllowed, EqnNeeded, MinmaxNeeded],
	       [[-1,1,1,0], [0,1,1,0], [1,0,0,1], [2,0,0,0]]),
	(ParamsAllowed = 0, !,
	    ParamWibble = "but parameter default values are not 
allowed to have input variables themselves.",
	    UsableInputs = [];
	ParamWibble = "which is not \c
referred to by any of its parameter names in the equation.",
	    UsableInputs = InterInputs),
	(Unit_st = "", !,
	    UnitError = [];
	get_term(Unit_st, Units, UnitFormError),
	    analyze_array(Units, Base, Dims)),
	check_exp(Eqn_st, Units, "Equation", UsableInputs, EqnBase, EqnDims,
		  EqnNeeded, IndxCount, EqParamList, Result, EqnError),
	
	check_exp(Min_st, Base, "Min. value", UsableInputs, MinBase, _MinDims,
		  MinmaxNeeded, IndxCount, MinParamList, Min, Min_term_error),
	check_exp(Max_st, Base, "Max. value", UsableInputs, MaxBase, _MaxDims,
		  MinmaxNeeded, IndxCount, MaxParamList, Max,
		  Max_term_error),

	merge_lists(MinParamList, MaxParamList, LimitParamList),
	merge_lists(EqParamList, LimitParamList, ParamList),
	append(Min_term_error, Max_term_error, MinMaxError),
	append(EqnError, MinMaxError, Complaint5),
	
	(Complaint5 = [], !,
	(Unit_st = "", Eqn_st = "", !,
	    /* If no eqn or units supplied, assume real */
	    NewUnits = 1, UnitError = [];
	var(MinBase), var(EqnBase), var(MaxBase), var(TypeBase), !,
	    /* If units but no eqn or limits supplied, accept any */
	    NewUnits = Units,
	    UnitError = UnitFormError;
	propagate_units(min(max(Min,Result),Max), any, [any, any, any, any],
			[MinBase, EqnBase, MaxBase, TypeBase], ComboType),
	    (ComboType = real, !, ComboBase = 1; 
		ComboType = ComboBase),
	    (EqnDims = Dims, !; true), /* if no eqn, use dims from unit --
	    if this match fails, so will check_unit! */
	    build_array(ComboBase, EqnDims, Combo_units),
	    ((Units = Combo_units;
	      /* next line allows an int to be quietly made into a real if the
	      expression is now real */
	      check_unit(Combo_units, Units, 1, [])), !,
		NewUnits = Combo_units,
		UnitError = [];
	    check_unit(Units, Combo_units, 2, UnitMatchError),
		append(UnitMatchError, UnitFormError, UnitError))),

	    (UnitError = [], !,
		(analyze_array(Units, _Base, Multiples),
		    get_actual_sizes(Multiples, MultInts),
		    member(Dim, MultInts),
		    (Dim = var, !,
		    format_to_chars("The unit expression ~w represents a \c
				   list or an array of lists. Model \c
				   components are not allowed to have list \c
				   values.", [Units], Complaint6);
		    \+ (integer(Dim), Dim > 1), !,
		    format_to_chars("The unit expression ~w includes an \c
				   array of size ~w, which is not a valid \c
				   dimension for a model component -- they \c
				   must be integers greater than 1.",
				   [Units, Dim], Complaint6));
		Complaint6 = []);   
	    Complaint6 = UnitError);
	get_term(Unit_st, Units, _),
	    Complaint6 = Complaint5),

	(Complaint6 = [], !,
	    check_param_usage(Function, InterInputs, ParamWibble,
				  ParamList, New_inputs, Complaint7);
	New_inputs = InterInputs,
	    Complaint7 = Complaint6),

	/* Now, is there a reference to a table? If so, load the data 
for it,
	complaining if it is not there. Otherwise ignore any data. */
	(replace_subexps(Result, dialogue, table_ref, 0, top_down, [_ 
| _], _),
	    !,
	    get_term(Table_st, TableData, _),
	/* should be no errors as it is auto generated */
	    (TableData = [FileName, DataField | Indices], !,
		get_table_info(FileName, Indices, DataField, 
DataTable,
			       FileError),
		TableAttr = [file = FileName, data = DataField,
			     indices = Indices, current = DataTable];
	    FileError = "Equation refers to a data table, but no 
table specification has been entered.\n"),
	    append(Complaint7, FileError, FinalComplaint);
		
	TableAttr = '',
	    TableData = '',
	    FinalComplaint = Complaint6),
	
	/* table data is auto-generated so should be well formed */
	name(Desc, Desc_st),
	name(Comment, Comment_st),

	(FinalComplaint = [], !,
		update_parameterhood(Function, Is_P, AffectedNode),
		add_parameter(AffectedNode, 0, value, Result),
		add_parameter(AffectedNode, 0, units, NewUnits),
		add_parameter(AffectedNode, 0, description, Desc),
		add_parameter(AffectedNode, 0, comment, Comment),
		add_parameter(AffectedNode, 0, table_data, 
TableAttr),
		add_parameter(AffectedNode, 0, min_val, Min),
		add_parameter(AffectedNode, 0, max_val, Max),
		update_links_and_vars(New_inputs);
	fill_equation(Result, Units, Is_P, TableData, Desc, Comment, 
Min, Max),
	    fill_inputs(New_inputs),
	    assert(input_list_is(New_inputs)),
	    (FinalComplaint = continue, !;
		do_dialogue("Problem with equation", warning, 
FinalComplaint,
			    ok, _)),
	    !, /* green */ fail).

table_ref(_, table(_), _, 0).

check_exp(Eqn_st, GivenUnits, FieldName, InterInputs, Base, Dims, Needed,
	  IndxCount, ParamList, Equation, Error) :-
	Eqn_st = [], !,
		ParamList = [],
		Equation = '',
		(Needed = 1, !,
			append("You must supply a value for field ", 
FieldName,
					Error);
		Error = []);
	get_term(Eqn_st, Equation, ParseError),
		(ParseError = [], !,
			test_eqn(Equation, GivenUnits, IndxCount, 
InterInputs, 
					Base, Dims, ParamList, 
TestError),
			(TestError = [],
			    ((member(var, Dims), !,
				    append(["The expression for field ", FieldName, " evaluates to a list, or array of lists. A model variable cannot represent a list."], Error);
				\+ FieldName = "Equation",
				(Base = boolean; \+ Dims = []), !,
				    append(["The expression for field ",
					    FieldName, " must evaluate to a scalar quantity."], Error));
			    Error = []);
			append(["Testing ", FieldName, 
				" field produced the following error: ",
				TestError], Error));
		append(["Parsing ", FieldName, 
				" field produced the following error: 
",
				ParseError], Error)).

/* test_eqn: replaces the old parse_eqn. Because make_intermediates 
now
includes full type checking, it can be used to make sure the 
equation
makes sense, so there is no longer any point in having a separate 
parser here.
We just have to make the eqn look like we are in the middle of the 
generation
process. */

test_eqn(Equation, GivenUnits, IndxCount, InterInputs,
	Type, Dims, ParamList, TestError) :-
	list_of(_, IndxCount, DestInds),
	(var(GivenUnits), !, TgtUnits = undefined; TgtUnits = 
GivenUnits),
	replace_subexps(Equation, dialogue, expand_params,
			[input_link(_,_, '/dest/', _, TgtUnits) | 
InterInputs],
			top_down, ParamSubs, FullExpr),
	(member(var_pair(_, Param), ParamSubs),
	 get_solo_list_depth(Param, _),
	    \+ Param = '/dest/', !,
	    format_to_chars("Reference to undefined parameter ~w", 
[Param],
			    TestError);
	on_exception(ParseError,
		     make_intermediates(FullExpr, '/dest/',
					[sm(_,_,_, fm_loop(DestInds))], 
_, [],
					[], 1, _, Type, _,
					part_result(XContext, _,_,_)),
		     decode_error(ParseError, TestError))),
	(TestError = [], !,
	    all(dialogue, get1st, [build(ParamSubs), build(ParamList)]),
	    /* Hack alert. The term representing the dest context has indices
	    (so index(n) will work) but no loops, so we don't need to add it
	    to the relative source contexts */
	    get_dims_from_loops(XContext, Dims, _);
	true).

get1st(var_pair(A, _), A).

expand_params(InterInputs, Param, DoneExpr, Recurse) :-
	get_solo_list_depth(Param, _),
	    (member(input_link(_,_, Param, _, Units), InterInputs), 
!,
		analyze_array(Units, Base, Dims),
		make_inds_for(Dims, Loops, Inds),
		(units:get_conversion(_, Base, Base, _), !,
		    Type = real;
		Type = Base),
		DoneExpr = param(arr(_,Param, Inds), Type, Loops, _, 
true);
	    DoneExpr = Param), /* just puts it in list so we can 
check later */
	    Recurse = 0;
	expand_library('/dest/', Param, DoneExpr),
	    Recurse = 1.

decode_error(ParseError, TestError) :-
	ParseError =.. [Type, Cause | More],
	replace_subexps(Cause, dialogue, collapse_params, _, top_down,
			_, SimpleError),
	(Type = needs_array_or_list, !,
		SimpleError =.. [Functor, SoleArg],
		format_to_chars("The function \"~a\" performs an operation \c
			       over a list or array of values represented by \c
			       its argument. The argument \"~w\" however \c
			       represents only one value.", [Functor, SoleArg],
			       TestError);
	    Type = avoid_var_size_inter, !,
	    More = [TotalDims],
	    format_to_chars("This formula can only run by making an \c
			   intermediate variable for the subexpression \"\c
			   ~w\".\n This subexpression has dimensions ~w, \c
			   where \"var\" represents a list. Since this has \c
			   a changing membership, it cannot be represented \c
			   by a variable -- you need to do some more work \c
			   inside the variable-membership submodel it comes \c
			   from.", [SimpleError, TotalDims], TestError);
	Type = needs_channel_parameter, !,
	    format_to_chars("The argument of \"channel_for\" must be a value \c
			   from a channel (creation, immigration, \c
			   reproduction) for the population submodel \c
			   containing its node. \"~w\" does not fit.",
			   [SimpleError], TestError);
	Type = bad_index_number, !,
	    More = [Functor],
	    format_to_chars("The function \"~a\" sets or accesses some \c
			   property of the model, and needs a non-negative \c
			   integer constant as an argument to allow the \c
			   right code to be built into the model \c
			   to do this. \"~w\" \c
			   does not fit.", [Functor, SimpleError], TestError);
	Type = index_number_out_of_range, !,
	    More = [Avail],
	    format_to_chars("You have used the index number ~d, but it must \c
			   be between 1 and the number of available indices, \c
			   which is ~d.", [SimpleError, Avail], TestError);
	Type = needs_number_index, !,
	    SimpleError =.. [Functor, _, Ind],
	    format_to_chars("The function \"~a\" needs a numerical value for \c
			   it's second argument. \"~w\" does not fit -- it \c
			   evaluates to a boolean or something.",
			   [Functor, Ind], TestError);
	Type = only_works_on_array, !,
	    SimpleError =.. [Functor, Arr, _],
	    format_to_chars("The function \"~a\" needs a fixed membership \c
			   array (of anything) for \c
			   its first argument. \"~w\" does not fit -- it \c
			   represents either a single value or a variable \c
			   membership list.", [Functor, Arr], TestError);
	Type = no_such_function, !,
	    More = [Op],
	    format_to_chars("Attempting to process subexpression \"~w\": \c
			   Simile does not include \"~a\" as a function.",
			   [SimpleError, Op], TestError);
	Type = wrong_no_of_args, !,
	    More = [Op, Arity, FnArity],
	    format_to_chars("Attempting to process subexpression \"~w\": \c
			   You have tried to use the function \"~a\" with ~d \c
			   arguments, but it must take ~d",
			   [SimpleError, Op, Arity, FnArity], TestError);
	Type = cannot_combine_argument_dimensions, !,
	    format_to_chars("Simile cannot work out what dimensions the \c
			   result of \"~w\" should have -- the dimensions of \c
			   the arguments are incompatible.",
			   [SimpleError], TestError);
	Type = mismatched_units, !,
	    More = [Get, Want],
	    format_to_chars("The arguments of \"~w\" have the following \c
			   types: ~w. These cannot be matched to the \c
			   expected argument types for this function, which \c
			   are ~w.", [SimpleError, Get, Want], TestError);
	/* default case */
	    format_to_chars("~w : ~a", [SimpleError, Type], TestError)).

collapse_params(_, param(arr(_, Param, _), _,_,_,_), Param, 0).

check_param_usage(Node, Current, WhyNoLinks, Used, Left, Challenge) :-
	member(input_link(id(LinkName, _,_), 
			SourceCaption,_,_,_), Current),
	/* Really we only need one reference to each link, but since Bob
	decided it was confusing to have role-free references where there were
	roles I don't know how to be sure of getting exactly one... */
	sort_for_link(Current, LinkName, FromThat, FromOthers),
	\+ (member(SpareParam, Used), 
			member(input_link(_,_, SpareParam, _,_), 
FromThat)), !,
		format_to_chars("This node has a link from ~w, ~s 
Remove this link?",
				[SourceCaption, WhyNoLinks], Wibble),
		do_dialogue("Too many inputs", question, Wibble,
			okcancel, Choice),
		(Choice = ok,
			event:off(LinkName),
			event:delete_by_dlg(LinkName),
			check_param_usage(Node, FromOthers, 
WhyNoLinks, Used, 
					Left, Challenge);
		Choice = cancel,
			Left = Current,
			Challenge = continue);
	Left = Current,
		Challenge = [].


update_parameterhood(Function, Is_P, AffectedNode) :-
	is_parameter(Function, Was_P),
	((Is_P = Was_P; Is_P = -1), !,
	    AffectedNode = Function;
	((Was_P = 0, !,
	        implicit_function(AffectedNode, Function),
	        m_update:delete_implicit_node(AffectedNode);
	    Is_P = 0, !,
	        add_implicit_function(Function, AffectedNode);
	        AffectedNode = Function),
	    (Is_P = 2, !,
		add_parameter(AffectedNode, 0, param_type, file);
	    add_parameter(AffectedNode, 0, param_type, '')))).

can_build_with(SubValue) :-
	\+ var(SubValue),
	(number(SubValue); SubValue = size(_); SubValue = size(_,_)).

work_out(==, [X,Y], 0) :-
	(X>Y; X<Y), !.
work_out(==, _, 1).

/* Back to realtive normality... */

/* do_disag_dialog/4: This is called when disaggregate is selected. 
First it asks for the disaggregation parameters (this shouldn't 
really be necessary). */

do_disag_dialog(Win, Model, P_list, New_P_List) :-
	caption_for(Model, Capt),
	tk_do_disag_dialog(Win, Capt, P_list, New_P_Strs),
	strings_to_atoms(New_P_Strs, New_P_List).

do_relation_dialog(Win, Relation, OldExcStat, OldLastStat, 
OldComment,
		   OKd, ExcStat, LastStat, NewComment) :-
	caption_for(Relation, Capt),
	tk_do_relation_dialog(Win, Capt, OldExcStat, OldLastStat, 
OldComment,
			      OKdStr, ExcStr, LastStr, NewCommentStr),
	strings_to_atoms([OKdStr, ExcStr, LastStr, NewCommentStr],
			 [OKd, ExcStat, LastStat, NewComment]).

strings_to_atoms([],[]).

strings_to_atoms([S | SR], [A | AR]) :-
	name(A,S),
	strings_to_atoms(SR, AR).

integer_between(Lo, Hi, Int) :-
	Lo < Hi,
	(Int = Lo;
	NotSoLo is Lo + 1, 
		integer_between(NotSoLo, Hi, Int)).

get_solo_list_depth(List,Depth) :-
	atom(List), Depth = 0;
	(List = [Ellie]; List = {Ellie}),
		get_solo_list_depth(Ellie, D), Depth is D+1.

get_array_nesting(Current_unit, Depth) :-
	analyze_array(Current_unit, _, Dims),
	length(Dims, Depth).

get_load_file(FileName) :-
	get_file_name('untitled.sml', 'Open file:', 0, FileName).

get_save_file(FileName) :-
	get_file_name('untitled.sml', 'Save as:', 1, FileName).

get_import_file(Preferred, FileName) :-
	get_file_name(Preferred, 'Import from:', 0, FileName).

get_program_file(Preferred, FileName) :-
	get_file_name(Preferred, 'Export to:', 1, FileName).

start_progress_dialogue(Win) :-
	tk_start_progress_dialogue(Win).

reassure_user(String) :-
	tk_update_infobox(String).

finish_progress_dialogue :-
	tk_finish_progress_dialogue.

warn_runtime :-
	tk_alter_model.
