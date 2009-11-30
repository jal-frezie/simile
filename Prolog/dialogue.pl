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

sicstus_module(dialogue, [pick_equation/2, do_equation_dialog/2, 
	do_disag_dialog/4, do_relation_dialog/8, test_eqn/8,
			  check_param_usage/5,
	get_load_file/2, get_save_file/2,
	get_program_file/3, get_import_file/3, 
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

make_arg_list([], "").

make_arg_list([Arg], Str) :- !,
	sicstus_format_to_chars("~w", [Arg], Str).

make_arg_list([Arg | Args], Str) :-
	make_arg_list([Arg], Str1),
	make_arg_list(Args, Str2),
	append(Str1, [44, 32 | Str2], Str).

pick_equation(Part, Equation) :-
	(get_av_pair(Part, 0, spec, Equation),
	    atom(Equation), \+ Equation = [],
	    /* do not use old string version */ !;
	get_av_pair(Part, 0, value, Equation), !;
		Equation = '').

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
	(ClickedObj is_of_sort init_eval, !,
	    TitleForm = 'Initial value';
	TitleForm = 'Equation'),
	list_index_meanings(Part, ISpecs),
	all(dialogue, index_names_and_sizes, [build(ISpecs), build(IndexList),
					      build(_Sz)]),
	pick_equation(Part, Equation),
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
		reverse_engineer(Values, TableTrans, 1, TableVals));
	TableList = '', TableTrans = '', TableVals = '{}'),
	get_desc_and_comment(ClickedObj, Desc, Comment, ''),
	(get_av_pair(Part, 0, min_val, Min), !;
		get_default_lower_limit(Part, Min)),
	(get_av_pair(Part, 0, max_val, Max), !;
		get_default_upper_limit(Part, Max)),
	/* Node is an input parameter if a ghost whose base has no
		associated function */
	get_all_enum_types(Part, ETList),
	is_parameter(ClickedObj, Is_P),
	
	create_equation(Win, TitleForm, Caption, IndexList, ETList),
	fill_equation(Equation, Base, Dims, Is_P, Desc, Comment, Min, Max),
	fill_table(Part, TableList, TableVals), % calls interaction from tcl
	destroy_equation.

interactively_parse(Part) :-
	get_input_info(Part, Input_list),
	fill_inputs(Input_list),
	get_host(Part, ClickedObj),
	(default_units(ClickedObj, ITypeBase, TypeDims), !; true),
	list_index_meanings(Part, ISpecs),
	all(dialogue, index_types, [build(ISpecs), build(IndxCount)]),
	(get_av_pair(Part, 0, table_data, TableSpec), !;
	    TableSpec = ''),
	handle_eqn_interaction(Part, ITypeBase-TypeDims, IndxCount,
			       Input_list, TableSpec).

:- dynamic(table_data_is/1).

handle_eqn_interaction(Part, DefUnit, IndxCount, Input_list, TableSpec) :-
	interact_equation(Result_list),
	(Result_list = [], !; % dialogue cancelled
	  asserta(table_data_is(TableSpec)),  % needed in parser
	    update_equation(Part, IndxCount, Input_list,
			    DefUnit, Result_list, Effect),
	    retractall(table_data_is(_TableSpec)),  
	    (Effect = eqn_accepted(Is_P, Result, UserFnList, OldEqn, NewArrSpec,
				   TabDat, MinVal, MaxVal, Desc, Comment,
				   NewInputs),
		update_parameterhood(Part, Is_P, AffectedNode),
		add_parameter(AffectedNode, 0, value, Result),
		add_parameter(AffectedNode, 0, uses_local_fns, UserFnList),
		add_parameter(AffectedNode, 0, spec, OldEqn),
		add_parameter(AffectedNode, 0, units, NewArrSpec),
		(\+ TabDat = 0, TableAttr = TableSpec, !;
		    TableAttr = ''), /* no tables/graphs found */
		add_parameter(AffectedNode, 0, table_data, TableAttr),
		add_parameter(AffectedNode, 0, min_val, MinVal),
		add_parameter(AffectedNode, 0, max_val, MaxVal),
		get_host(AffectedNode, Visible),
		(Visible is_of_sort box, !, CAttrType = 0; CAttrType = 2),
		add_parameter(Visible, CAttrType, description, Desc),
		add_parameter(Visible, CAttrType, comment, Comment),
		update_links_and_vars(NewInputs); % and finish
	      (Effect = input_list_changed_to(NewInputList), !,
		  fill_inputs(NewInputList);
		  NewInputList = Input_list),
		(Effect = table_spec_changed_to(NewTableSpec), !;
		    % Tcl data already updated, no need to change it
		    NewTableSpec = TableSpec),
		(Effect = user_advice_generated(Mess),
		    query(Mess, warning, fill_equation, [ok], _);
		    true),
		handle_eqn_interaction(Part, DefUnit, IndxCount,
				       NewInputList, NewTableSpec))).

index_names_and_sizes(ind_spec(Name, Posn, Dim, _Link), Meaning, Dim) :-
	sicstus_format_to_chars("Dimension ~d of ~a (~w)", [Posn, Name, Dim],
				MeaningStr),
	name(Meaning, MeaningStr).

index_types(ind_spec(_Name, _Posn, Ind, _Link), Type) :-
	inters:type_ind(Ind, Type).

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

update_equation(Function,_,_,_, [Table_st, Data_st], Effect) :-
	get_term(Table_st, TableData, _),
	/* should be no errors as it is auto generated */
	TableData = [FileName | DataSpec],
	(FileName = '/graph/', !,
	    length(DataField, 3),
	    append(DataField, [Dims | Indices], DataSpec),
	    output:chop_list(Data_st, DataStrs),
	    all(user, sicstus_atom_chars, [build(DataTable), build(DataStrs)]),
	    Units = 1,
	    Bounds = 1,
	    ComplaintStr = [];
	DataSpec = [DataField | Indices],
	    get_table_data(Function, Data_st, DataTable,
			   Units, Bounds, Dims, ComplaintStr)),
	(ComplaintStr = [], !,
	    Effect = table_spec_changed_to([file = FileName, data = DataField,
				indices = Indices, current = DataTable,
				units=Units, bounds=Bounds, dims=Dims]);
	  name(Complaint, ComplaintStr),
		Effect = user_advice_generated(bad_table_data(Complaint))).

update_equation(_,_, Input_list, _, [Node_st, Parm_st, New_unit_st],
		Effect) :-
	name(New_var, Node_st),
	sicstus_format_to_chars("local name for ~w", [New_var], ShowParam),
	name(ShowParamAtom, ShowParam),
	sicstus_format_to_chars("local units for ~w", [New_var], ShowUnits),
	append(EarlyInputs,
	       [input_link(Link, New_var, _, Current_unit, _) | LateInputs],
	       Input_list), !,
	get_term(Parm_st, New_param, Complaint0),
	(\+ Complaint0 = [], !,
	    Complaint2 = bad_syntax(ShowParamAtom, Complaint0);
	    get_term(New_unit_st, NewUnits, Complaint1),
	    (Complaint1 = [], !;
		name(ShowUnitsAtom, ShowUnits),
		Complaint2 = bad_syntax(ShowUnitsAtom, Complaint1))),
	
	(Complaint2 = [], !,
	    (check_param_brackets(ShowParamAtom, New_param, Current_unit,
				  Complaint), !;
		(NewUnits = '', !,
		    NewInputUnit = Current_unit;
		    analyze_array(Current_unit, CurrentBase, CurrentDims),
		    build_array(NewUnits, CurrentDims, NewInputUnit),
		    check_unit(CurrentBase, NewUnits, 2, Complaint)));
	    Complaint = Complaint2),
	
	(Complaint = [], !,
	    append(EarlyInputs, [input_link(Link, New_var, New_param,
		    Current_unit, NewInputUnit) | LateInputs], NewInputs),
	    Effect = input_list_changed_to(NewInputs);
	Effect = user_advice_generated(Complaint)).

update_equation(Function, IndxCount, InterInputs, TypeBase-TypeDims,
		[Eqn_st, Unit_st, Is_P_st, Desc_st, Cmt_st, Min_st, Max_st],
		Effect) :-
	name(Is_P, Is_P_st),
	member([Is_P, ParamsAllowed], [[-1,1], [0,1], [1,0], [2,0]]),
	get_term(Unit_st, Units, UnitFormError),
	check_exp(Eqn_st, Function, InterInputs, EqnBase, EqnDims,
		  IndxCount, ParamList, Result, EqnError),
/*	(ParamsAllowed = 0,
	    member(input_link(_, SourceCapt, _,_,_), InterInputs), !,
	    EqnError = unwanted_links(SourceCapt);
	 EqnError = ParseError), */
	(Is_P = 1, \+ member(Units, [boolean, a(_)]), \+ member(EqnBase, [boolean, a(_)]), !,
	    MinMaxNeeded = 1;
	MinMaxNeeded = 0),

	(\+ EqnError = [], !,
	    Complaint5 = EqnError;
	EqnBase = cond_spec, \+ TypeBase == cond_spec,
	    Complaint5 = misplaced_cond_spec;
	check_limit(Min_st, 'Min. value', Function,
		    MinMaxNeeded, Min, MinVal, MinBase, MinErr),
	    (\+ MinErr = [], !,
		Complaint5 = MinErr;
	    check_limit(Max_st, 'Max. value', Function,
			MinMaxNeeded, Max, MaxVal, MaxBase, Complaint5))),

	(Complaint5 = [], !,
	(Unit_st = "", Eqn_st = "", Min_st = "", Max_st = "",
	    /* If no eqn, bounds or units supplied, assume real */
	    (Is_P > 0, NewArrSpec = 1; NewArrSpec = ''), UnitError = [], !;
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
			[EqnBase, MinBase, MaxBase], RawBase),
		     UnitError = minmax_wrong(EqnBase)),
	    
	(nonvar(UnitError);
	    /* First, check that the equation can have the units
	       given, or set given units to the default units for the
	       equation if there are none. */
	  \+ UnitFormError = [],
	    UnitError = bad_syntax('Units', UnitFormError);
	  promote_unit(RawBase, ComboBase),
	    \+ member(ComboBase, [const_int, const_ratio]),
		% variables cannot have constant units even if constant
	    (\+ member(Units, ['', any]), !,
	      (Units = int, ComboBase = 1,
		  NewUnits = 1;
		% num constant changed from int to float -- allow
	      NewUnits = Units); % otherwise if units were given, use them
	    nonvar(TypeBase), (\+ TypeBase = 1; ComboBase = int), !,
	      NewUnits = TypeBase; % interesting default units, use them
	    NewUnits = ComboBase), % last resort, use units from eqn
	    ((InterInputs = [], % If there are no incoming influences...
	      (EqnBase = 1; % ...and the equation evaluates to a dimensionless
		  promote_unit(EqnBase, real)); % quantity,
	      use_units_in(Function, 'No')), % or else if math checking is off,
		CheckLevel = 1; % allow it to have any given physical units
	      CheckLevel = 2), % otherwise dimensions must match
	    check_unit(ComboBase, NewUnits, CheckLevel, EqnToUnitError)),
	    (\+ EqnToUnitError == [],
		UnitError = EqnToUnitError;
	    /* Next check that the value's units,however they were
	       specified, are appropriate for this component */
	
	      build_array(NewUnits, EqnDims, NewArrSpec),
		(var(TypeDims), !,
		    [Test, Target] = [NewUnits, TypeBase];
		 Test = NewArrSpec,
		    build_array(TypeBase, TypeDims, Target)),
		(TypeBase = any, !,
		    Strict = 0;
		 TypeBase = 1, !,
		    Strict = 1; % allow original physical units
		 Strict = 2),
		check_unit(Test, Target, Strict, UnitError))),

/* Pre-5.4 version which conflated these tasks together
            ((nonvar(TypeBase);
	      var(TypeBase),
	          (\+ (member(Units, ['', any]), ComboBase = any, Is_P = 2),
			  member(TypeBase, [any, a(_), int, boolean]);
		      TypeBase = real)),
		promote_arg(ComboBase, TypeBase, ComboUnits), !,
		% fix this if boolean to cond_spec promotion removed
		(nonvar(ComboUnits); ComboUnits = TypeBase);
           sicstus_format_to_chars("The equation for a component of this type must have units which can be used as ~w. The values entered have units of ~w, which cannot be converted.", [TypeBase,ComboBase], UnitError));
	    true),
	    (nonvar(UnitError),
		NewUnits = Units;
	     (member(Units, ['', any]);
		 % Units field left empty or had no value
	     Units = int, ComboUnits = 1),
		% num constant changed from int to float -- allow
		 
		NewUnits = ComboUnits,
		UnitError = [];
	    ((InterInputs = [], member(EqnBase, [any, const_int, const_ratio,
						 int, 1]);
	      use_units_in(Function, 'No')),
		CheckLevel = 1;
	    CheckLevel = 2),
	    % Allow numerical or empty entries to have any physical units
	    check_unit(ComboUnits, Units, CheckLevel, UnitMatchError),
		% Result can be promoted/converted to given units -- ok
		NewUnits = Units,
		append(UnitMatchError, UnitFormError, UnitError))),
*/
	    (UnitError = [], !,
		(on_exception(Hiccup,
			      get_actual_sizes(Function, EqnDims, MultInts,
					       _V, _U),
			      name(Hiccup, Complaint6)),
		    member(Dim, MultInts),
		    (nonvar(Complaint6);
		    Dim = var, !,
			Complaint6 = expr_denotes_list;
		    \+ (integer(Dim), Dim > 1), !,
		    % should never happen, parser now checks subexps for this
		    Complaint6 = bad_array_size(Dim));
		true /* ,
		    this check now done by generating default units for flows
		    check_flow_ends(Function, NewArraySpec, Complaint6) */ );
	    Complaint6 = UnitError);
	get_term(Unit_st, NewUnits, _),
	    Complaint6 = Complaint5),
	/* units cannot be const_int because we do not uet have the
	technology to get values at build time */

	/* Now, is there a reference to a table or graph? If so, load the data 
	for it. Otherwise ignore any data. This also lists user-defined
	functions (macros and procedures) */
	replace_subexps(Result, dialogue, table_ref, got(UserFnOpen, TabDat),
			top_down, _,_),
	(var(UserFnOpen), !,
	    UserFnList = '';
	get_ground_part(UserFnOpen, UserFnList)),
	/* table data is auto-generated so should be well formed.
	Missing table will already have been picked up by parser */

	(Complaint6 = [], \+ (Eqn_st = [], ParamsAllowed = 1) , !,
	    check_param_usage(InterInputs, ParamsAllowed,
			      ParamList, New_inputs, FinalComplaint);
	New_inputs = InterInputs,
	    FinalComplaint = Complaint6),

	sicstus_atom_chars(Desc, Desc_st),
	sicstus_atom_chars(Comment, Cmt_st),
	purge(Eqn_st, "\\", OrigSt),
	sicstus_atom_chars(OldEqn, OrigSt),

	(FinalComplaint = [], !,
	    Effect = eqn_accepted(Is_P, Result, UserFnList, OldEqn, NewArrSpec,
				  TabDat, MinVal, MaxVal, Desc, Comment,
				  New_inputs);
%	fill_equation(OldEqn, Units, EqnDims, Is_P, Desc, Comment, Min, Max),
	 FinalComplaint = continue, !,
	    Effect = input_list_changed_to(New_inputs);
	 Effect = user_advice_generated(FinalComplaint)).

/* This fails if the brackets are right */
check_param_brackets(ShowParam, New_param, Current_unit, Complaint) :-
	get_solo_list_depth(New_param, Depth), !,
	explain_brackets(Current_unit, Desc2, no, SP, OKN),
	(OKN = New_param, atom(SP), !, fail;
	    explain_brackets(Depth, Desc1, no, SP, New_param),
	    Complaint = wrong_bracket_count(ShowParam, New_param, Desc1,
					     Desc2, OKN));
	    Complaint = unwanted_syntax(ShowParam, New_param).

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
	(Many = yes, append([" of ", TypeStr, "s", SubType], Desc);
	    Many = no, append([PL1, TypeStr, SubType], Str), name(Desc, Str)).
	    
	
table_ref(got(Datta, Tabs), Ref, DumFn, Recurse) :-
	Ref =.. [Functor | Args],
	(member(Functor, [table, graph]),
	    Tabs = 1,
	    Recurse = 0;	 
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
	    Recurse = 1).

get_table_data(Function, Data, Table, Units, Dims, Sizes, Complaint) :-
	on_exception(Complaint,
		     (get_table_part(Function, Data, Table,
				     Units, Dims, Sizes),
		     zero_empties(Table, Sizes)), true).

get_table_part(Function, Data, Table, Units, Dims, Sizes) :-
	length(Data, Len), Len<255,
	name(Num, Data),
	enum_type_ref(Num, Function, bare, Table, Units, _),
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
	    enum_type_ref(Ind, Fn, bare, Posn, TUnit, _),
	    (TUnit = a(_), IUnit = TUnit;
		IUnit = int);
	append(["Table contained the index item ", IndStr,
		", which is not a recognizable constant."], Loss),
	    raise_exception(Loss)),
	nth(Posn, Table, Line),
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
	    length(Table, Top),
	    all(dialogue, zero_empties, [build(Table), unify(Lower)]);
	ground(Table), !;
	Table = 0.

/* clever stuff in here is to undo what zero_empties did, because the zeros
mess up translation if using enumerated types. As of 4.8, arrays start at 0
so that bit is no longer needed. */

reverse_engineer(Table, [Trans | MoreTrans], Here, TclRep) :-
	Table = [Val | Rest], !,
	    reverse_engineer(Val, MoreTrans, 1, TclHead),
	    There is Here+1,
	    reverse_engineer(Rest, [Trans | MoreTrans], There, TclTail),
	    make_e_t(Here, Trans, HereTxt),
	    (Here = 1, !,
		TclRep = br([HereTxt, TclHead | TclTail]);
	    TclRep = [HereTxt, TclHead | TclTail]);
	member(Table, [0, []]), !,
	    TclRep = Table;
	make_e_t(Table, Trans, TclRep).

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
		Error = field_needs_value(FieldName);
	    Error = []);
	get_term(Eqn_st, Eqn, ParseError),
	(ParseError = [], !,
	    (on_exception(Error,
			 get_actual_size(Function, Eqn, Values, S, [Base]),
			 true), !;
	    Error = field_not_const(FieldName)),	    
	    (var(Error), !,
		(\+ S = Values, !,
		    Error = field_not_number(FieldName);
		Values = [Value], !,
		    Error = [];
		 Error = field_not_scalar(FieldName));
		true);
	    Error = bad_syntax(FieldName, ParseError)).
	
check_exp(Eqn_st, Function, InterInputs, Base, Dims,
	  IndxCount, ParamList, Equation, Error) :-
	Eqn_st = [], !,
	    Base = any,
	    Dims = [],
	    ParamList = [],
	    Equation = '',
	    Error = [];
	get_term(Eqn_st, Equation, ParseError),
	    (ParseError = [], !,
		test_eqn(Equation, Function, IndxCount, InterInputs, 
			 Base, Dims, ParamList, TestError),
		(\+ TestError = [],
		    Error = TestError;
		 Base = cond_spec,
		    \+ instance:is_lookup_cond(Equation, _),
		    Error = bad_cond_spec_form;
		 member(var, Dims), !,
		    Error = expr_denotes_list;
		 Error = []);
	    Error = bad_syntax('Equation', ParseError)).

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
	append(InterInputs, [input_link(_, DimL, '/dest/', _-DLoops,_)],
	       AllInputs),
	
	on_exception(ParseException,
		     replace_subexps(Equation, dialogue, expand_params,
			dim_data(DimL, ParamList, AllInputs, ExpInters),
				     top_down, _ParamSubs, FullExpr),
		     ParseError = ParseException),
	
	(nonvar(ParseError), !;
	length(ParamList, _LenP),
	    get_ground_part(DimL, DimDG),
	    length(DimDG, LenD),
	    length(DimDV, LenD),
	    make_inds_for(DimDV, DLoops, _),
	    length(ExpInters, _), !, /* close list end */

	/* hack alert: We are using the parser to get the dimensions of the
		result. Thses should include enumerated type references,
		so we do not want to convert these into numbers. Since we
		are not making code we can use the time step field to tell it
		this by setting it to 'dummy'. */
	
	DummyDest = [sm(_,_,_, fm_loop(IndxSzs, IndxSzs, _))],
	    on_exception(ParseExcp,
			 (make_intermediates(FullExpr, Fn, ['/dest/'],
					     DummyDest, _, [],
					     [], dummy, _, Type, _I,
					     part_result(Context, _,_,_)),
			     inters:get_model_and_loops(Context, DummyDest, _,
							Loops, _)),
			 (replace_subexps(ParseExcp, dialogue, collapse_params,
					  _, top_down, _, ParseError);
			     ParseError = ParseExcp))),
	(nonvar(ParseError), !;
	(member(input_link(_,_, Param, _-PLoops, _), ExpInters),
	    nth(N, PLoops, set(_, loop(Bound,_))),
	    var(Bound),
	    ParseError = cannot_set_dims(N, Param);
	    %sicstus_format_to_chars("Dimension ~d of explicit intermediate variable ~w cannot be determined from its definition", [N, Param], ParseError);
	    get_dims_from_loops(Loops, Dims, _))).
	/* real_dims_only(XDims, Dims).
	Hack alert. The term representing the dest context has indices
	(   so index(n) will work) but no loops, so we don't need to add it
	to the relative source contexts */

expand_params(dim_data(DimL, PsUsed, AllInputs, ExpInters),
	      Param, DoneExpr, Recurse) :-
	(get_solo_list_depth(Param, Depth),
	/* when making dummy links for explicit intermediate results, check
	the 1st field (influence id) is a free var, and if so, use the
	4th field to hold the dims */
	    (member(input_link(Link, LRefs, Param, Loops, Units), AllInputs),!,
	        (nonvar(Link), !,
		    member(Param, PsUsed),
		    analyze_array(Units, Type, Dims),
/*		    (units:get_conversion(_, Base, Base, _), !,
		        Type = real;
		    Type = Base), */
		    make_inds_for(Dims, PLoops, Inds);
	        (Param = '/dest/', !,
		        get_ground_part(LRefs, GRefs),
		        length(GRefs, L);
		    m_update:analyze_array(Depth, any, Dims),
	                make_inds_for(Dims, PLoops, Inds)),
	            Type-PLoops = Loops,
	            Units = param_history(_Defn, 1)),
	        /* pass dims up the recursion loop */
	        length(Dims, L),
	        list_of(x, L, DimB),
	        append(DimB, _, DimL),
	        DoneExpr = param(arr(_, Param, Inds), Type, PLoops, _, true);
	    raise_exception(undefined_parameter(Param)));
	Param = (ExpInt=Defn), !, % '=' subexp not arg of ',' --
	% complain now or missing parameter error may be raised instead
	    throw(wrong_format_of_args(Param, =, (a=b), (a=b,c)));
	Param = (ExpInt=Defn,Use),
            NewLink = input_link(_,SubL, ExpInt, OldType, PrevDims),
	    (member(NewLink, AllInputs),
		(PrevDims = param_history(OldDefn, Used),
		    (var(OldDefn), !,
			DefnInputs = AllInputs;
		     raise_exception(parameter_name_recurs(ExpInt)));
		raise_exception(parameter_name_reused(ExpInt)));
	    DefnInputs = [NewLink | AllInputs]),
	    OldType=Type-Loops,
	    PrevDims = param_history(Defn, Used),
	    member(NewLink, ExpInters),
	    replace_subexps(Defn, dialogue, expand_params,
			    dim_data(SubL, PsUsed, DefnInputs, ExpInters),
			    top_down, _, DefnExpr),
            length(DefnInputs, _), !,
	    replace_subexps(Use, dialogue, expand_params,
			    dim_data(DimL, PsUsed, DefnInputs, ExpInters),
			    top_down, _, UseExpr),
	    (get_ground_part(SubL, DimG),
		build_array(1, DimG, Array),
		check_param_brackets('explicit intermediate result',
				     ExpInt, Array, ParseError), !,
		raise_exception(ParseError);
	    member(input_link(_,_, FPar, param_history(FDef, _)), DefnInputs),
		var(FDef), !,
		raise_exception(undefined_parameter(FPar));
	    var(Used), !,
		raise_exception(unused_inter(ExpInt));
	    DoneExpr = (param(arr(_,ExpInt,_), Type, Loops,_,_)=DefnExpr,
			   UseExpr));
	Param =.. [Cumulative | Items],
	    member(Cumulative, [sum, product, least, greatest,
				any, all, count, with_least, with_greatest]), !,
	    replace_all_subexps(Items, dialogue, expand_params,
			    dim_data(SubL, PsUsed, AllInputs, ExpInters),
			    top_down, _, DsDone),
	    DoneExpr =.. [Cumulative | DsDone],
	    SubL = [x | DimL];
	(length(Param, N), 
	    DParam =.. [do | Param], % conversion to fn avoids recursion
	    length(DoneExpr, N),
	    DDone =.. [do | DoneExpr];
	 Param = makearray(Elt, Count),
	    DParam = do(Elt, Count),
	    DDone = do(EltExpr, CountExpr),
	    DoneExpr = makearray(EltExpr, CountExpr)),
	    replace_subexps(DParam, dialogue, expand_params,
			    dim_data(SubL, PsUsed, AllInputs, ExpInters),
			    top_down, _, DDone),
	    DimL = [x | SubL];
	Param = element(List, Index),
% work out dimty as if:
% element([[a,b,c],[d,e,f]],[x,y,z]) is [element([a,d],x)...element([c,f],z)].
	    replace_subexps(List, dialogue, expand_params,
			    dim_data([x | DimL], PsUsed, AllInputs, ExpInters),
			    top_down, _, ListExpr),
	    replace_subexps(Index, dialogue, expand_params,
			    dim_data(DimL, PsUsed, AllInputs, ExpInters),
			    top_down, _, IndXpr),
	    DoneExpr = element(ListExpr, IndXpr)),
	    Recurse = 0;
	expand_library('/dest/', Param, DoneExpr),
	    Recurse = 1.

collapse_params(_, param(arr(_, Param, _), _,_,_,_), Param, 0).

check_param_usage(Current, AllowLinks, Used, Left, Challenge) :-
	member(input_link(id(LinkName, _,_), 
			SourceCaption,_,_,_), Current),
	/* Really we only need one reference to each link, but since Bob
	decided it was confusing to have role-free references where there were
	roles I don't know how to be sure of getting exactly one... */
	sort_for_link(Current, LinkName, FromThat, FromOthers),
	\+ (member(SpareParam, Used), 
	       member(input_link(_,_, SpareParam, _,_), FromThat)), !,
	    \+ AllowLinks = [], % just fail if checking on propagation
	    (AllowLinks = 0, Prob = unwanted_links(SourceCaption);
		AllowLinks = 1, Prob = extra_links(SourceCaption)),
	    query(Prob, question, fill_equation, [ok, cancel], Choice),
	    (Choice = ok,
		event:off(LinkName),
		event:delete_by_dlg(LinkName),
		check_param_usage(FromOthers, AllowLinks, Used, Left, Challenge);
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

/*
Version that did not work on singly-nested lists
strings_to_atoms([],[]).

strings_to_atoms([S | SR], [A | AR]) :-
	(\+ S = [],
	    all(dialogue, strings_to_atoms, [build(S), build(A)]), !;
	(append([123 | InS], [125], S), !; InS = S),
	name(A, InS)),
	strings_to_atoms(SR, AR).
*/
strings_to_atoms([], '').

strings_to_atoms(StNest, ANest) :-
        StNest = [St | Sts],
        (member(St, [[], [_|_]]), !, /* nested */
            all(dialogue, strings_to_atoms, [build(StNest), build(ANest)]);
        (St = 123,
	/* If tcl has put it in curlies remove them */
	    append(InS, [125], Sts), !;
	 InS = StNest),
            name(ANest, InS)).

integer_between(Lo, Hi, Int) :-
	Lo < Hi,
	(Int = Lo;
	NotSoLo is Lo + 1, 
		integer_between(NotSoLo, Hi, Int)).

get_array_nesting(Current_unit, Depth) :-
	analyze_array(Current_unit, _, Dims),
	length(Dims, Depth).

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

reassure_user(String) :-
	tk_update_infobox(String).

finish_progress_dialogue :-
	tk_finish_progress_dialogue.
