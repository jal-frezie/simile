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

sicstus_module(dialogue, [do_equation_dialog/2, 
	do_disag_dialog/4, do_relation_dialog/8, test_eqn/8,
	get_load_file/1, get_save_file/1,
	get_program_file/2, get_import_file/2, 
        start_progress_dialogue/1,
	finish_progress_dialogue/0, reassure_user/1]).

sicstus_use_module([library(lists),
		    sp_only, m_update, ame_gen, output, utility, inters]).

/* helpers for sending function list */
pass_functions(LibFuns) :-
	setof(FnAtom, atomize_function(FnAtom), FuncList),
	append(FuncList, LibFuns, AllFns),
	prepare_equation(AllFns).
	
atomize_function(FnAtom) :-
	inters:builtin(Category, Functor, ResultSort, ArgSorts),
	spell_out([ResultSort | ArgSorts], 1),
	make_arg_list(ArgSorts, String),
	sicstus_format_to_chars("{Built-in {~a}} ~a (~s) returns ~w",
			[Category, Functor, String, ResultSort], FnChars),
	name(FnAtom, FnChars).

spell_out([], _).

spell_out([Dooda | Rest], N) :-
	((var(Dooda), Type = Dooda; Dooda =.. [_, Type]), !, 
		sicstus_format_to_chars("type~d", [N], String),
		name(Type, String),
		M is N+1;
	M = N),
	spell_out(Rest, M).

make_arg_list([Arg], Str) :- !,
	sicstus_format_to_chars("~w", [Arg], Str).

make_arg_list([Arg | Args], Str) :-
	make_arg_list([Arg], Str1),
	make_arg_list(Args, Str2),
	append(Str1, [44, 32 | Str2], Str).

/* the equation dialogue will only exit when a coherent set of 
inputs have been 
entered; if they are not, then update_equation fill fail after 
putting new info 
into the dialog box, and interact_equation will be called again and 
return new 
values. */

:- dynamic(table_data_is/1).

do_equation_dialog(Win, Part) :-
	caption_for(Part, Caption),
	get_host(Part, ClickedObj),
	(ClickedObj is_of_sort cond_value, !,
	    TypeBase = cond_spec,
	    TitleForm = 'Condition/Specifiation';
	ClickedObj is_of_sort boolean_value, !,
	    TypeBase = boolean,
	    TitleForm = 'Condition';
	(\+ ClickedObj is_of_sort level, !; /* other than the above */
	    TypeBase = real),
	(ClickedObj is_of_sort init_eval, !,
	    TitleForm = 'Initial value';
	TitleForm = 'Equation')),
	(ClickedObj is_of_sort channel, !,
	    TypeDims = [];
	true),
	sicstus_format_to_chars("~a for ~a", [TitleForm, Caption], 
BoxHeaderStr),
	name(BoxHeader, BoxHeaderStr),
	list_index_meanings(Part, ISpecs),
	all(dialogue, index_names_and_sizes,
	    [build(ISpecs), build(IndexList), build(IndxCount)]),
	(get_av_pair(Part, 0, spec, Equation),
	    atom(Equation), \+ Equation = [],
	    /* do not use old string version */ !;
	get_av_pair(Part, 0, value, Equation), !;
		Equation = ''),
	(get_av_pair(Part, 0, units, Units), !,
	    analyze_array(Units, Base, Dims);
	(var(TypeBase), !,
	    Base = '';
	Base = 1),
	    Dims = []),
	retractall(table_data_is(_)),
	(get_av_pair(Part, 0, table_data, TableSpec),
	    TableSpec = [file=FilePath, data=DataField, indices=Indices,
			 current=Values, units=TUnits, bounds=Bounds | _R], !,
	    assert(table_data_is(TableSpec)),
	    (FilePath = '/graph/', !,
		append([FilePath | DataField], [Bounds | Indices], TableList),
		TableTrans = [[], []],
		TableVals = br(Values);
	    TableList = [FilePath, DataField | Indices],
		get_host(Part, Visible),
		append(Bounds, [TUnits], TableTypes), 
		all(event, insert_mem_list,
		    [build(TableTypes), unify(Visible), build(TableTrans)]),
		reverse_engineer(Values, TableTrans, 0, TableVals, _));
	TableList = '', TableTrans = '', TableVals = '{}'),
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
	
	create_equation(Win, BoxHeader, IndexList),
	fill_equation(Equation, Base, Dims, Is_P, Desc, Comment, Min, Max),
	fill_inputs(Input_list),
	fill_table(TableList, TableVals),
	retractall(input_list_is(_)),
	assert(input_list_is(Input_list)),
	repeat,
	interact_equation(Result_list),
	retract(input_list_is(Updated_list)),
	(Result_list = [], !, destroy_equation, fail; 
	update_equation(Part, IndxCount, Updated_list, TypeBase-TypeDims,
			Result_list)),
		/* fails if action does not complete edit */
	!, destroy_equation.
	/* last cut necessary because otherwise a retry will cause 
errors */

index_names_and_sizes(ind_spec(Name, Posn, Dim), Meaning, DimN) :-
	sicstus_format_to_chars("Dimension ~d of ~a (~w)", [Posn, Name, Dim],
				MeaningStr),
	name(Meaning, MeaningStr),
	(Dim = pop, !, DimN = 0; DimN = Dim).

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

update_equation(Function,_, InList,_, [Table_st, Data_st]) :-
	assert(input_list_is(InList)),
	get_term(Table_st, TableData, _),
	/* should be no errors as it is auto generated */
	TableData = [FileName | DataSpec],
	(FileName = '/graph/', !,
	    length(DataField, 3),
	    append(DataField, [Dims | Indices], DataSpec),
	    output:chop_list(Data_st, DataStrs),
	    all(user, sicstus_atom_chars, [build(DataTable), build(DataStrs)]),
	    Units = 1,
	    Bounds = 1;
	get_table_data(Function, Data_st, DataTable,
		       Units, Bounds, Dims, Complaint),
	    (\+ Complaint = [], !,
		do_dialogue("Problem with input data", warning, Complaint, ok,
			    _),
		fail;
	    DataSpec = [DataField | Indices])),
	retractall(table_data_is(_)),
	assert(table_data_is([file = FileName, data = DataField,
			      indices = Indices, current = DataTable,
			      units=Units, bounds=Bounds, dims=Dims])),
	fail.

update_equation(_,_, Input_list, _, [Node_st, Parm_st, New_unit_st]) :-
	(name(New_var, Node_st),
	    append(EarlyInputs,
		   [input_link(Link, New_var, _, Current_unit, _) | 
LateInputs],
		   Input_list), !,
		get_term(Parm_st, New_param, Complaint0),
		get_term(New_unit_st, NewUnits, Complaint1),
		append(Complaint0, Complaint1, Complaint2),
		(Complaint2 = [], !,
		    sicstus_format_to_chars("local name for ~w", [New_var],
					    ShowParam),
		    (check_param_brackets(ShowParam, New_param, Current_unit,
					 Complaint), !;
			(NewUnits = '', !,
			    NewInputUnit = Current_unit;
			analyze_array(Current_unit, CurrentBase, CurrentDims),
			    build_array(NewUnits, CurrentDims, NewInputUnit),
			    check_unit(CurrentBase, NewUnits, 2, Complaint)));
		Complaint = Complaint2);
	    Complaint = "Select an input before supplying its new parameter name and/or local units"),
			
	(Complaint = [], !,
	    append(EarlyInputs, [input_link(Link, New_var, New_param,
		    Current_unit, NewInputUnit) | LateInputs], NewInputs),
	    fill_inputs(NewInputs),
	    assert(input_list_is(NewInputs));
	do_dialogue("Problem with input data", warning, Complaint,
		    ok, _),
	    assert(input_list_is(Input_list))),
	fail.

update_equation(Function, IndxCount, InterInputs, TypeBase-TypeDims,
		[Eqn_st, Unit_st, Is_P_st, Desc_st, Cmt_st, Min_st, Max_st]) :-
	name(Is_P, Is_P_st),
	member([Is_P, ParamsAllowed, EqnNeeded],
	       [[-1,1,0], [0,1,0], [1,0,0], [2,0,0]]),
	(ParamsAllowed = 0, !,
	    ParamWibble = "but parameter default values are not allowed to have input variables themselves.";
	ParamWibble = "which is not referred to by any of its parameter names in the equation."),
	get_term(Unit_st, Units, UnitFormError),
	(ParamsAllowed = 0, \+ InterInputs = [], !,
	    EqnError = "You cannot have influences going to a component representing a file or input parameter.";
	check_exp(Eqn_st, "Equation", Function, InterInputs, EqnBase, EqnDims,
		  EqnNeeded, IndxCount, ParamList, Result, EqnError)),
	(Is_P = 1, \+ member(Units, [boolean, a(_)]), \+ member(EqnBase, [boolean, a(_)]), !,
	    MinMaxNeeded = 1;
	MinMaxNeeded = 0),

	check_limit(Min_st, "Min. value", Function,
		    MinMaxNeeded, Min, MinVal, MinBase, MinErr),
	check_limit(Max_st, "Max. value", Function,
		    MinMaxNeeded, Max, MaxVal, MaxBase, MaxErr),

	append(MinErr, MaxErr, MinMaxError),
	append(EqnError, MinMaxError, Complaint5),
	
	(Complaint5 = [], !,
	(fail, Unit_st = "", Eqn_st = "",
	    /* If no eqn or units supplied, assume real */
	    (Is_P > 0, NewUnits = 1; NewUnits = ''), UnitError = [], !;
	/* If units but no eqn or limits supplied, accept any */
/*	MinBase = any, EqnBase = any, MaxBase = any, var(TypeBase), !,
	    NewUnits = Units,
	    UnitError = UnitFormError;
	on_exception(PropError, propagate_units([eqn=Result, min=Min, max=Max,
						 type=TypeBase], any,
						[any, any, any, any],
			[EqnBase, MinBase, MaxBase, TypeBase], ComboType),
		     decode_error(PropError, UnitError)), 
	    (ComboType = real, !, ComboUnits = 1;
		member(ComboType, [n(_), const_int]), ComboUnits = int;
		ComboType = ComboUnits), */

	on_exception(_PropError, propagate_units(min(Max, max(Min, Result)),
						any, [any, any, any],
			[EqnBase, MinBase, MaxBase], ComboBase),
		     sicstus_format_to_chars("Equation has non-numeric units ~w, so minimum or maximum values cannot be used.", [EqnBase], UnitError)), 
	(var(UnitError),
            ((nonvar(TypeBase);
	      var(TypeBase),
	          (\+ (ComboBase = any, Is_P = 2),
			  member(TypeBase, [any, a(_), int, boolean]);
		      TypeBase = real)),
		promote_arg(ComboBase, TypeBase, ComboUnits), !,
		/* fix this if boolean to cond_spec promotion removed */
		(nonvar(ComboUnits); ComboUnits = TypeBase);
           sicstus_format_to_chars("The equation for a component of this type must have units which can be used as ~w. The values entered have units of ~w, which cannot be converted.", [TypeBase,ComboBase], UnitError));
	    true),
	    (nonvar(UnitError),
		NewUnits = Units;
	     (member(Units, ['', any]);
		 /* Units field left empty or had no value */
	     Units = int, ComboUnits = 1), /* num constant changed from int
	                                      to float -- allow */
		 
		NewUnits = ComboUnits,
		UnitError = [];
	    ((InterInputs = [], member(EqnBase, [const_int, const_ratio,
						 int, 1]);
	      use_units_in(Function, 'No')),
		CheckLevel = 1;
	    CheckLevel = 2),
		/* Allow numerical entries to have any physical units */
	    check_unit(ComboUnits, Units, CheckLevel, UnitMatchError),
		/* Result can be promoted/converted to given units -- ok */
		NewUnits = Units,
		append(UnitMatchError, UnitFormError, UnitError))),

	    (UnitError = [], !,
		(get_actual_sizes(Function, EqnDims, MultInts, _V, _U),
		    member(Dim, MultInts),
		    (Dim = var, !,
			Complaint6 = "This equation evaluates to a list or an array of lists. Model components are not allowed to have list values.";
		    \+ (integer(Dim), Dim > 1), !,
		    sicstus_format_to_chars("This equation evaluates to a data structure which includes an array of size ~w, which is not a valid dimension for a model component -- they must be integers greater than 1.",
				   [Dim], Complaint6);
		    \+ TypeDims = MultInts, !,
		    Complaint6 = "This type of component cannot be an array.");
		check_flow_ends(Function, NewUnits, Complaint6));   
	    Complaint6 = UnitError);
	get_term(Unit_st, NewUnits, _),
	    Complaint6 = Complaint5),
	/* units cannot be const_int because we do not uet have the
	technology to get values at build time */

	/* Now, is there a reference to a table or graph? If so, load the data 
	for it. Otherwise ignore any data. This also lists user-defined
	functions (macros and procedures) */
	replace_subexps(Result, dialogue, table_ref, UserFnOpen,
			top_down, AllMatch, _),
	(var(UserFnOpen), !,
	    UserFnList = '';
	get_ground_part(UserFnOpen, UserFnList)),
	purge(AllMatch, [var_pair(table(_),_), var_pair(graph(_),_)], TGMatch),
	(\+ TGMatch = AllMatch, /* some tables/graphs removed */
	    table_data_is(TableAttr), !;
	 TableAttr = ''),
	/* table data is auto-generated so should be well formed */

	(Complaint6 = [], \+ Eqn_st = [], !,
	    check_param_usage(Function, InterInputs, ParamWibble,
				  ParamList, New_inputs, FinalComplaint);
	New_inputs = InterInputs,
	    FinalComplaint = Complaint6),

	name(Desc, Desc_st),
	name(Comment, Cmt_st),
	purge(Eqn_st, "\\", OrigSt),
	sicstus_atom_chars(OldEqn, OrigSt),

	(FinalComplaint = [], !,
	    update_parameterhood(Function, Is_P, AffectedNode),
	    build_array(NewUnits, EqnDims, NewArraySpec),
		add_parameter(AffectedNode, 0, value, Result),
		add_parameter(AffectedNode, 0, uses_local_fns, UserFnList),
		add_parameter(AffectedNode, 0, spec, OldEqn),
		add_parameter(AffectedNode, 0, units, NewArraySpec),
		add_parameter(AffectedNode, 0, description, Desc),
		add_parameter(AffectedNode, 0, comment, Comment),
	        add_parameter(AffectedNode, 0, table_data, TableAttr),
		add_parameter(AffectedNode, 0, min_val, MinVal),
		add_parameter(AffectedNode, 0, max_val, MaxVal),
		update_links_and_vars(New_inputs);
%	fill_equation(OldEqn, Units, EqnDims, Is_P, Desc, Comment, Min, Max),
	    fill_inputs(New_inputs),
	    assert(input_list_is(New_inputs)),
	    (FinalComplaint = continue, !;
		do_dialogue("Problem with equation", warning, FinalComplaint,
			    ok, _)),
	    !, /* green */ fail).

/* This fails if the brackets are right */
check_param_brackets(ShowParam, New_param, Current_unit, Complaint) :-
	get_solo_list_depth(New_param, Depth), !,
	explain_brackets(Current_unit, Desc2, no, SP, OKN),
	(OKN = New_param, atom(SP), !, fail;
	    explain_brackets(Depth, Desc1, no, SP, New_param),
	    sicstus_format_to_chars("Your ~s, ~w, has brackets round it that would indicate ~s. However it actually stands for ~s so should appear as follows: ~w. ", [ShowParam, New_param, Desc1, Desc2, OKN], Complaint));
	    sicstus_format_to_chars("Your ~s, ~w, contains characters that might cause the interpreter to mistake it for an expression, or vice versa. ",
				    [ShowParam, New_param], Complaint).

explain_brackets(Dims, Desc, Many, BaseName, RightBrs) :-
	(nonvar(Dims), Dims =.. [Type, Middle | _],
	    (Type = list, PL1 = "a ",
		RightBrs = {InnerBrs};
	    Type = array, PL1 = "an ",
		RightBrs = [InnerBrs]), !,
	    name(Type, TypeStr),
	    explain_brackets(Middle, SubType, yes, BaseName, InnerBrs);
	PL1 = "a ",
	    TypeStr = "single value",
	    SubType = "",
	    RightBrs = BaseName),
	(Many = yes, Pref = " of ", Plural = "s";
	    Many = no, PL1 = Pref, Plural = ""),
	append([Pref, TypeStr, Plural, SubType], Desc).
	    
	
table_ref(Datta, Ref, DumFn, Recurse) :-
	member(Ref, [table(_), graph(_)]),
	    Recurse = 0;	 
	Ref =.. [Functor | Args],
	    length(Args, Arity),
	    (function(Cat, Functor, _R, TptArgs);
		macro_expansion(Cat, (Fn --> _Defn)),
		Fn =.. [Functor | TptArgs]),
	    \+ Cat = 'Built-in',
	    length(TptArgs, Arity),
	    (Args = [''], UseArity = 0;
		UseArity = Arity),
	    DumFn =.. [userfnsubbedhere | Args],
	    member(Functor/UseArity, Datta), !,
	    Recurse = 1.

get_table_data(Function, Data, Table, Units, Dims, Sizes, Complaint) :-
	on_exception(Complaint,
		     (get_table_part(Function, Data, Table,
				     Units, Dims, Sizes),
		     zero_empties(Table, Sizes)), true).

get_table_part(Function, Data, Table, Units, Dims, Sizes) :-
	name(Num, Data),
	enum_type_ref(Num, Function, Table, Units, _),
	    Dims = [],
	    Sizes = [];
	output:chop_list(Data, Alternator),
	    feed_items(Function, Alternator, Table, Units, Dims, Sizes), !;
	append(["Table contained the data item ", Data,
		", which is not a recognizable constant."], Loss),
	    raise_exception(Loss).

feed_items(_, [], _, _, _, []).
feed_items(Fn, [IndStr, ValStr | More], Table, Units, Dims, Sizes) :-
	feed_items(Fn, More, Table, DUnit, Dims, LoSizes),
	(name(Ind, IndStr),
	    enum_type_ref(Ind, Fn, Posn, TUnit, _),
	    (TUnit = a(_), IUnit = TUnit;
		IUnit = int);
	append(["Table contained the index item ", IndStr,
		", which is not a recognizable constant."], Loss),
	    raise_exception(Loss)),
	nth0(Posn, Table, Line),
	get_table_part(Fn, ValStr, Line, NUnit, HiDims, HiSizes),
	(promote_arg(NUnit, DUnit, _), !,
	    Units = DUnit;
	 promote_arg(DUnit, NUnit, _), !,
	    Units = NUnit;
	 raise_exception("Data units mismatch.")),
	 (Dims = [IUnit | HiDims], !;
	    raise_exception("Index units mismatch.")),
	max_all(LoSizes, [Posn | HiSizes], Sizes).

max_all(A, B, X) :-
	A = [I1 | C], !,
	    (B = [I2 | D], !,
		(I1=I, I2=I, !; I is max(I1, I2);
		    sicstus_format_to_chars("Cannot match index dimensions ~w and ~w.",
				    [I1, I2], Loss),
		    raise_exception(Loss)),
		max_all(C, D, Y),
		X = [I | Y];
	    X = A);
	X = B.

zero_empties(Table, Dims) :-
	Dims = [Top | Lower], !,
	    NCount is Top+1,
	    length(Table, NCount),
	    all(dialogue, zero_empties, [build(Table), unify(Lower)]);
	ground(Table), !;
	Table = 0.

/* clever stuff in here is to undo what zero_empties did, because the zeros
mess up translation if using enumerated types */

reverse_engineer(Table, [Trans | MoreTrans], Here, TclRep, NonZ) :-
	Table = [Val | Rest], !,
	    reverse_engineer(Val, MoreTrans, 0, TclHead, SubZ),
	    There is Here+1,
	    reverse_engineer(Rest, [Trans | MoreTrans], There, TclTail, NonZ),
	    make_e_t(Here, Trans, HereTxt),
	    TclInner = [HereTxt, TclHead | TclTail],
	    (Here = 0,
		(SubZ = no,
		    TclRep = br(TclTail);
		TclRep = br(TclInner)), !;
	    TclRep = TclInner);
	member(Table, [0, []]), !,
	    TclRep = Table;
	make_e_t(Table, Trans, TclRep),
	     NonZ = yes.

make_e_t(Table, Trans, TclRep) :-
	Trans = [],
	    TclRep = Table;
	nth0(Table, Trans, Enum),
	    append_atoms(['{"', Enum, '"}'], TclRep).

check_limit(Eqn_st, FieldName, Function, Needed, Eqn, Value, Base, Error) :-
	Eqn_st = [], !,
	    Base = any,
	    Eqn = '',
	    Value = '',
	    (Needed = 1, !,
		append("You must supply a value for field ", FieldName, Error);
	    Error = []);
	get_term(Eqn_st, Eqn, ParseError),
	(ParseError = [], !,
	    (on_exception(Error,
			 get_actual_size(Function, Eqn, Values, S, [Base]),
			 true), !;
	    sicstus_format_to_chars("Entry for ~s must be a numeric constant.",
			[FieldName], Error)),	    
	    (var(Error), !,
		(\+ S = Values, !,
		    sicstus_format_to_chars("Entry for ~s must have a numerical value", [FieldName], Error);
		Values = [Value], !,
		    Error = [];
		 sicstus_format_to_chars("Entry for ~s must have a single value.", [FieldName], Error));
		true);
	    Error = ParseError).
	
check_exp(Eqn_st, FieldName, Function, InterInputs, Base, Dims, Needed,
	  IndxCount, ParamList, Equation, Error) :-
	Eqn_st = [], !,
	    Base = any,
	    Dims = [],
	    ParamList = [],
	    Equation = '',
	    (Needed = 1, !,
		append("You must supply a value for field ", FieldName, Error);
	    Error = []);
	get_term(Eqn_st, Equation, ParseError),
	    (ParseError = [], !,
		test_eqn(Equation, Function, IndxCount, InterInputs, 
			 Base, Dims, ParamList, TestError),
		(TestError = [],
		    ((member(var, Dims), !,
		            append(["The expression for field ", FieldName, " evaluates to a list, or array of lists. A model variable cannot represent a list."], Error);
			\+ FieldName = "Equation",
			    (Base = a(_); \+ Dims = []), !,
		            append(["The expression for field ", FieldName,
				    " must evaluate to a scalar quantity."],
				   Error));
			    Error = []);
			append(["Testing ", FieldName, 
				" field produced the following error: ",
				TestError], Error));
		append(["Parsing ", FieldName, 
				" field produced the following error: ",
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

test_eqn(Equation, Fn, IndxCount, InterInputs, Type, Dims,
	 ParamList, ParseError) :-
	reverse(IndxCount, IndxSzs),
	append(InterInputs, [input_link(_, DimL, '/dest/', _-DLoops,_)
			    | ExpInters], AllInputs),
	
	on_exception(ParseException,
		     replace_subexps(Equation, dialogue, expand_params,
				     dim_data(DimL, ParamList, AllInputs),
				     top_down, _ParamSubs, FullExpr),
		     decode_error(ParseException, ParseError)),
	length(ParamList, _LenP),
	get_ground_part(DimL, DimDG),
	length(DimDG, LenD),
	length(DimDV, LenD),
	make_inds_for(DimDV, DLoops, _),
	length(ExpInters, _), !, /* close list end */
	(nonvar(ParseError), !;
	 member(input_link(_, DimP, Param, _, PDims), ExpInters),
	    (var(PDims), !,
		decode_error(undefined_parameter(Param), ParseError);
	    get_ground_part(DimP, DimG),
		build_array(1, DimG, Array),
		check_param_brackets("explicit intermediate result",
					 Param, Array, ParseError)), !;

	/* hack alert: We are using the parser to get the dimensions of the
		result. Thses should include enumerated type references,
		so we do not want to convert these into numbers. Since we
		are not making code we can use the time step field to tell it
		this by setting it to 'dummy'. */
	
	DummyDest = [sm(_,_,_, fm_loop(IndxSzs, _))],
	    on_exception(ParseException,
			 (make_intermediates(FullExpr, Fn, '/dest/',
					     DummyDest, _, [],
					     [], dummy, _, Type, _I,
					     part_result(Context, _,_,_)),
			     inters:get_model_and_loops(Context, DummyDest, _,
							Loops, _)),
	    decode_error(ParseException, ParseError))),
	(member(input_link(_,_, Param, _-PLoops, _), ExpInters),
	    nth(N, PLoops, set(_, loop(Bound))),
	    var(Bound),
	    sicstus_format_to_chars("Dimension ~d of explicit intermediate variable ~w cannot be determined from its definition", [N, Param], ParseError);
	get_dims_from_loops(Loops, Dims, _)).
	/* real_dims_only(XDims, Dims).
	Hack alert. The term representing the dest context has indices
	(   so index(n) will work) but no loops, so we don't need to add it
	to the relative source contexts */

expand_params(dim_data(DimL, PsUsed, AllInputs), Param, DoneExpr, Recurse) :-
	(get_solo_list_depth(Param, Depth),
	/* when making dummy links for explicit intermediate results, check
	the 1st field (influence id) is a free var, and if so, use the
	4th field to hold the dims */
	member(input_link(Link, LRefs, Param, Loops, Units), AllInputs), !,
	    (nonvar(Link), !,
		member(Param, PsUsed),
		analyze_array(Units, Type, Dims),
/*		(units:get_conversion(_, Base, Base, _), !,
		    Type = real;
		Type = Base), */
		make_inds_for(Dims, PLoops, Inds);
	    (Param = '/dest/', !,
		    get_ground_part(LRefs, GRefs),
		    length(GRefs, L);
		m_update:build_array(any, Dims, Depth),
	        make_inds_for(Dims, PLoops, Inds)),
		    Type-PLoops = Loops),
	    /* pass dims up the recursion loop */
	    length(Dims, L),
	    list_of(x, L, DimB),
	    append(DimB, _, DimL),
	    DoneExpr = param(arr(_, Param, Inds), Type, PLoops, _, true);
	Param = (ExpInt=Defn,Use),
	    member(input_link(_,SubL, ExpInt, Type-Loops, something),
		   AllInputs), !,
	    replace_subexps(Use, dialogue, expand_params,
			     dim_data(DimL, PsUsed, AllInputs), top_down, _,
			     UseExpr),
	    replace_subexps(Defn, dialogue, expand_params,
			     dim_data(SubL, PsUsed, AllInputs), top_down, _,
			     DefnExpr),
	    DoneExpr = (param(arr(_,ExpInt,_), Type, Loops,_,_)=DefnExpr,
			   UseExpr);
	Param =.. [Cumulative, Item],
	    member(Cumulative, [sum, product, least, greatest,
				any, all, count]), !,
	    replace_subexps(Item, dialogue, expand_params,
			     dim_data(SubL, PsUsed, AllInputs), top_down, _,
			     DDone),
	    DoneExpr =.. [Cumulative, DDone],
	    SubL = [x | DimL];
	(length(Param, N), 
	    DParam =.. [do | Param],
	    length(DoneExpr, N),
	    DDone =.. [do | DoneExpr];
	 Param = makearray(Elt, Count),
	    DParam = do(Elt, Count),
	    DDone = do(EltExpr, CountExpr),
	    DoneExpr = makearray(EltExpr, CountExpr)),
	    replace_subexps(DParam, dialogue, expand_params,
			    dim_data(SubL, PsUsed, AllInputs), top_down, _,
			    DDone),
	    DimL = [x | SubL];
	Param = element(List, Index),
	    replace_subexps(List, dialogue, expand_params,
			    dim_data(ListL, PsUsed, AllInputs), top_down, _,
			    ListExpr),
	    replace_subexps(Index, dialogue, expand_params,
			    dim_data(IndxL, PsUsed, AllInputs), top_down, _,
			    IndXpr),
	    DoneExpr = element(ListExpr, IndXpr),
	    ListL = [x | DimL],
	    suffix(Tail, DimL),
	    var(Tail), !,
	    Tail = IndxL),
	    Recurse = 0;
	expand_library('/dest/', Param, DoneExpr),
	    Recurse = 1.

decode_error(ParseError, TestError) :-
	ParseError =.. [Type | Causes],
	(Causes = [Cause | More], !,
	    replace_subexps(Cause, dialogue, collapse_params, _, top_down,
			    _, SimpleError);
	SimpleError = 'consistency check'),
	(Type = undefined_parameter, !,
	    sicstus_format_to_chars("This expression contains the term ~w, which appears to be used as a parameter, but it does not appear as a parameter name.", [SimpleError], TestError);
	Type = needs_array_or_list, !,
	    SimpleError =.. [Functor, SoleArg],
	    sicstus_format_to_chars("The function \"~a\" performs an operation over a list or array of values represented by its argument. The argument \"~w\" however represents only one value.", [Functor, SoleArg], TestError);
	Type = avoid_var_size_inter, !,
	    More = [TotalDims],
	    sicstus_format_to_chars("This formula can only run by making an intermediate variable for the subexpression \"~w\".\n This subexpression has dimensions ~w, where \"var\" represents a list. Since this has a changing membership, it cannot be represented by a variable -- you need to do some more work inside the variable-membership submodel it comes from.", [SimpleError, TotalDims], TestError);
	Type = needs_channel_parameter, !,
	    sicstus_format_to_chars("The argument of \"channel_is\" must be a value from a channel (creation, immigration, reproduction) for the population submodel containing its node. \"~w\" does not fit.",
			   [SimpleError], TestError);
	Type = bad_index_number, !,
	    More = [Functor],
	    sicstus_format_to_chars("The function \"~a\" sets or accesses some property of the model, and needs a non-negative integer constant as an argument to allow the right code to be built into the model to do this. \"~w\" does not fit.", [Functor, SimpleError], TestError);
	Type = index_number_out_of_range, !,
	    More = [Avail],
	    sicstus_format_to_chars("You have used the index number ~d, but it must be between 1 and the number of available indices, which is ~d.", [SimpleError, Avail], TestError);
	Type = needs_index_of_type, !,
	    SimpleError =.. [Functor, Arr, Ind],
	    More = [TypeNeeded, TypeGiven],
	    sicstus_format_to_chars("The function \"~a\", when applied to the array \"~w\", needs a value of type ~w for its second argument. \"~w\" does not fit -- it has a value of type ~w, which cannot be converted to a value of the required type.",
		[Functor, Arr, TypeNeeded, Ind, TypeGiven], TestError);
	Type = got_list_for_array, !,
	    SimpleError =.. [Functor, Arr | _],
	    sicstus_format_to_chars("The function \"~a\" needs a fixed membership array (of anything) for its first argument. \"~w\" does not fit -- it represents a variable membership list.", [Functor, Arr], TestError);
	Type = got_scalar_for_array, !,
	    SimpleError =.. [Functor, Arr | _],
	    sicstus_format_to_chars("The function \"~a\" needs a fixed membership array (of anything) for its first argument. \"~w\" does not fit -- it represents a single value.", [Functor, Arr], TestError);
	Type = only_works_on_array, !,
	    SimpleError =.. [Functor, Arr | _],
	    sicstus_format_to_chars("The function \"~a\" needs a fixed membership array (of anything) for its first argument. \"~w\" does not fit -- it represents either a single value or a variable membership list.", [Functor, Arr], TestError);
	Type = lost_user_defined_fn, !,
	    More = [Op, Arity],
	    sicstus_format_to_chars("Attempting to process subexpression \"~w\": When this was entered, \"~a\" was a user-defined function (a procedure or macro) with ~d arguments, but currently there is no definition for it.",
			   [SimpleError, Op, Arity], TestError);
	Type = no_such_function, !,
	    More = [Op],
	    sicstus_format_to_chars("Attempting to process subexpression \"~w\": Simile does not include \"~a\" as a function.",
			   [SimpleError, Op], TestError);
	Type = wrong_format_of_args, !,
	    More = [Op, Args, MacroArgs],
	    sicstus_format_to_chars("Attempting to process subexpression \"~w\": You have tried to use the macro \"~a\" with arguments ~w, but it must take arguments of the form ~w",
			   [SimpleError, Op, Args, MacroArgs], TestError);
	Type = wrong_no_of_args, !,
	    More = [Op, Arity, FnArity],
	    sicstus_format_to_chars("Attempting to process subexpression \"~w\": You have tried to use the macro or function \"~a\" with ~d arguments, but it must take ~d",
			   [SimpleError, Op, Arity, FnArity], TestError);
	Type = missing_graph_or_table_data, !,
	    sicstus_format_to_chars("Subexpression \"~w\" is a reference to a data table or sketch graph, but no data has been entered for it.",
			   [SimpleError], TestError);
	Type = cannot_combine_argument_dimensions, !,
	    sicstus_format_to_chars("Simile cannot work out what dimensions the result of \"~w\" should have -- the dimensions of the arguments are incompatible.",
			   [SimpleError], TestError);
	Type = mismatched_units, !,
	    More = [Get, Want],
	    SimpleError =.. [Fn | _],
	    sicstus_format_to_chars("The arguments of the function \"~a\" in the term \"~w\" have the following types: ~w. These cannot be matched to the expected argument types for this function, which are ~w.", [Fn, SimpleError, Get, Want], TestError);
	Type = wrong_param_units, !,
	    More = [UseType, DefType],
	    sicstus_format_to_chars("The equation is badly formed because it contains the explicit intermediate result ~w which is used in a context where it needs to have type ~w. However the definition of this value produces a result with type ~w, which cannot be used in this context.", [SimpleError, UseType, DefType], TestError);
	Type = undecipherable_operand, !,
	    More = [Var],
	    find_all_comps(Sm, Var),
	    caption_for(Sm, SmCapt),
	    sicstus_format_to_chars("There is no definition for ~w in submodel ~a", [SimpleError, SmCapt], TestError);
	/* default case */
	    sicstus_format_to_chars("~w : ~a", [SimpleError, Type], TestError)).

collapse_params(_, param(arr(_, Param, _), _,_,_,_), Param, 0).

check_param_usage(Node, Current, WhyNoLinks, Used, Left, Challenge) :-
	member(input_link(id(LinkName, _,_), 
			SourceCaption,_,_,_), Current),
	/* Really we only need one reference to each link, but since Bob
	decided it was confusing to have role-free references where there were
	roles I don't know how to be sure of getting exactly one... */
	sort_for_link(Current, LinkName, FromThat, FromOthers),
	\+ (member(SpareParam, Used), 
	       member(input_link(_,_, SpareParam, _,_), FromThat)), !,
		sicstus_format_to_chars("This node has a link from ~w, ~s Remove this link?",
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

do_relation_dialog(Win, Relation, Type, State, OldComment,
		   OKd, NewStat, NewComment) :-
	caption_for(Relation, Capt),
	tk_do_relation_dialog(Win, Capt, Type, State, OldComment,
			      OKdStr, NewStr, NewCommentStr),
	strings_to_atoms([OKdStr, NewCommentStr | NewStr],
			 [OKd, NewComment | NewStat]).

strings_to_atoms([],[]).

strings_to_atoms([S | SR], [A | AR]) :-
	(\+ S = [],
	    all(dialogue, strings_to_atoms, [build(S), build(A)]), !;
	/* If tcl has put it in curlies remove them */
	(append([123 | InS], [125], S), !; InS = S),
	name(A, InS)),
	strings_to_atoms(SR, AR).

integer_between(Lo, Hi, Int) :-
	Lo < Hi,
	(Int = Lo;
	NotSoLo is Lo + 1, 
		integer_between(NotSoLo, Hi, Int)).

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
	get_file_name(Preferred, 'Export to:', 1, FileName),
        \+ FileName = ''.

start_progress_dialogue(Win) :-
	tk_start_progress_dialogue(Win).

reassure_user(String) :-
	tk_update_infobox(String).

finish_progress_dialogue :-
	tk_finish_progress_dialogue.
