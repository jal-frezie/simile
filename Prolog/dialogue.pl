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
	do_disag_dialog/4, do_relation_dialog/9, test_eqn/7,
	get_load_file/1, get_save_file/1,
	get_program_file/2, get_import_file/2, 
        start_progress_dialogue/0,
	finish_progress_dialogue/0, warn_runtime/0, 
reassure_user/1]).

sicstus_use_module([library(lists),
		    sp_only, m_update, ame_gen, output, utility, inters]).

/* helpers for sending function list */
pass_functions(LibFuns) :-
	setof(FnAtom, atomize_function(FnAtom), FuncList),
	append(LibFuns, FuncList, AllFns),
	prepare_equation(AllFns).
	
atomize_function(FnAtom) :-
	inters:function(Functor, ResultSort, ArgSorts),
	spell_out([ResultSort | ArgSorts], 1),
	make_arg_list(ArgSorts, String),
	sicstus_format_to_chars("~a (~s) returns ~w", [Functor, String, 
ResultSort],
			FnChars),
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
	name(Arg, Str).

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

do_equation_dialog(Win, Part) :-
	caption_for(Part, Caption),
	get_host(Part, ClickedObj),
	(find_type(ClickedObj, compartment), !,
	    TypeBase = real,
	    TitleForm = 'Initial value';
	TitleForm = 'Equation'),
	sicstus_format_to_chars("~a for ~a", [TitleForm, Caption], 
BoxHeaderStr),
	name(BoxHeader, BoxHeaderStr),
	list_index_meanings(Part, IndexList),
	length(IndexList, IndxCount),
	create_equation(Win, BoxHeader, IndexList),
	(get_av_pair(Part, 0, spec, EquationStr), !,
	    name(Equation, EquationStr);
	get_av_pair(Part, 0, value, Equation), !;
		Equation = ''),
	(get_av_pair(Part, 0, units, Units), !,
	    analyze_array(Units, Base, Dims);
	(var(TypeBase), !,
	    Base = '';
	Base = 1),
	    Dims = []),
	(get_av_pair(Part, 0, table_data,
			      [file=FilePath, data=DataField,
			       indices=Indices, current=Values]), !,
	    TableList = [FilePath, DataField | Indices],
	    reverse_engineer(Values, 0, TableVals);
	TableList = '', TableVals = '{}'),
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
	fill_equation(Equation, Base, Dims, Is_P, TableList, TableVals,
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
			    check_unit(NewUnits, CurrentBase, 2, Complaint)));
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

update_equation(Function, IndxCount, InterInputs, TypeBase,
		[Eqn_st, Unit_st, Is_P_st,
		 Table_st, Data_st, Desc_st, Comment_st, Min_st, Max_st]) :-
	name(Is_P, Is_P_st),
	member([Is_P, ParamsAllowed, EqnNeeded],
	       [[-1,1,0], [0,1,0], [1,0,0], [2,0,0]]),
	(ParamsAllowed = 0, !,
	    ParamWibble = "but parameter default values are not allowed to have input variables themselves.",
	    UsableInputs = [];
	ParamWibble = "which is not referred to by any of its parameter names in the equation.",
	    UsableInputs = InterInputs),
	(Unit_st = "", !,
	    UnitFormError = [];
	get_term(Unit_st, Units, UnitFormError)),
	check_exp(Eqn_st, "Equation", UsableInputs, EqnBase, EqnDims,
		  EqnNeeded, IndxCount, EqParamList, Result, EqnError),
	(Is_P = 1, \+ Unit_st = "boolean", \+ EqnBase = boolean, !,
	    MinMaxNeeded = 1;
	MinMaxNeeded = 0),
	check_exp(Min_st, "Min. value", UsableInputs, MinBase, _MinDims,
		  MinMaxNeeded, IndxCount, MinParamList, Min, Min_term_error),
	check_exp(Max_st, "Max. value", UsableInputs, MaxBase, _MaxDims,
		  MinMaxNeeded, IndxCount, MaxParamList, Max,
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
	on_exception(PropError, propagate_units([eqn=Result, min=Min, max=Max,
						 type=TypeBase], any,
						[any, any, any, any],
			[EqnBase, MinBase, MaxBase, TypeBase], ComboType),
		     decode_error(PropError, UnitError)),
	    (ComboType = real, !, ComboUnits = 1; 
		ComboType = ComboUnits),
	    (nonvar(UnitError),
		NewUnits = Units;
	     (Units = ComboUnits;
	      /* next line allows an int to be quietly made into a real if the
	      expression is now real */
	      check_unit(ComboUnits, Units, 2, [])), !,
		NewUnits = ComboUnits,
		UnitError = [];
	    check_unit(Units, ComboUnits, 2, UnitMatchError),
		NewUnits = Units,
		append(UnitMatchError, UnitFormError, UnitError))),

	    (UnitError = [], !,
		(get_actual_sizes(EqnDims, MultInts),
		    member(Dim, MultInts),
		    (Dim = var, !,
			Complaint6 = "This equation evaluates to a list or an array of lists. Model components are not allowed to have list values.";
		    \+ (integer(Dim), Dim > 1), !,
		    sicstus_format_to_chars("This equation evaluates to a data structure which includes an array of size ~w, which is not a valid dimension for a model component -- they must be integers greater than 1.",
				   [Dim], Complaint6));
		Complaint6 = []);   
	    Complaint6 = UnitError);
	get_term(Unit_st, NewUnits, _),
	    Complaint6 = Complaint5),

	/* Now, is there a reference to a table? If so, load the data 
for it,
	complaining if it is not there. Otherwise ignore any data. */
	(replace_subexps(Result, dialogue, table_ref, 0, top_down, [_ 
| _], _),
	    !,
	    get_term(Table_st, TableData, _),
	/* should be no errors as it is auto generated */
	    (\+ Data_st = [], !,
		get_table_data(Data_st, DataTable, TableVals),
	        TableData = [FileName, DataField | Indices], 
		TableAttr = [file = FileName, data = DataField,
			     indices = Indices, current = DataTable],
		FileError = [];
	    FileError = "Equation refers to a data table, but no table specification has been entered.\n"),
	    append(Complaint6, FileError, Complaint7);
		
	TableAttr = '',
	    TableData = '',
	    TableVals = '{}',
	    Complaint7 = Complaint6),
	/* table data is auto-generated so should be well formed */

	(Complaint7 = [], !,
	    check_param_usage(Function, InterInputs, ParamWibble,
				  ParamList, New_inputs, FinalComplaint);
	New_inputs = InterInputs,
	    FinalComplaint = Complaint7),

	name(Desc, Desc_st),
	name(Comment, Comment_st),

	(FinalComplaint = [], !,
	    update_parameterhood(Function, Is_P, AffectedNode),
	    build_array(NewUnits, EqnDims, NewArraySpec),
		add_parameter(AffectedNode, 0, value, Result),
		add_parameter(AffectedNode, 0, spec, Eqn_st),
		add_parameter(AffectedNode, 0, units, NewArraySpec),
		add_parameter(AffectedNode, 0, description, Desc),
		add_parameter(AffectedNode, 0, comment, Comment),
		add_parameter(AffectedNode, 0, table_data, 
TableAttr),
		add_parameter(AffectedNode, 0, min_val, Min),
		add_parameter(AffectedNode, 0, max_val, Max),
		update_links_and_vars(New_inputs);
	fill_equation(Result, NewUnits, EqnDims, Is_P, TableData, TableVals,
		      Desc, Comment, Min, Max),
	    fill_inputs(New_inputs),
	    assert(input_list_is(New_inputs)),
	    (FinalComplaint = continue, !;
		do_dialogue("Problem with equation", warning, 
FinalComplaint,
			    ok, _)),
	    !, /* green */ fail).

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
	    
	
table_ref(_, table(_), _, 0).

get_table_data(Data, Table, Orig) :-
	get_table_part(Data, Table, Orig, Dims),
	zero_empties(Table, Dims).

get_table_part(Data, Table, Orig, Dims) :-
	name(Num, Data),
	number(Num), !,
	    Table = Num,
	    Orig = Num,
	    Dims = [];
	output:chop_list(Data, Alternator),
	    feed_items(Alternator, Table, SubOrig, Dims),
	    Orig = br(SubOrig).

feed_items([], _, [], []).
feed_items([IndStr, ValStr | More], Table, [Ind, VOrig | TOrig], Dims) :-
	feed_items(More, Table, TOrig, LoDims),
	name(Ind, IndStr),
	nth(Ind, Table, Line),
	get_table_part(ValStr, Line, VOrig, HiDims),
	max_all(LoDims, [Ind | HiDims], Dims).

max_all(A, B, X) :-
	A = [I1 | C], !,
	    (B = [I2 | D], !,
		I is max(I1, I2),
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

reverse_engineer(Table, Here, TclRep) :-
	Table = [Val | Rest], !,
	    reverse_engineer(Val, 0, TclHead),
	    There is Here+1,
	    reverse_engineer(Rest, There, TclTail),
	    TclInner = [There, TclHead | TclTail],
	    (Here = 0, !,
		TclRep = br(TclInner);
	    TclRep = TclInner);
	TclRep = Table.

check_exp(Eqn_st, FieldName, InterInputs, Base, Dims, Needed,
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
		test_eqn(Equation, IndxCount, InterInputs, 
			 Base, Dims, ParamList, TestError),
		(TestError = [],
		    ((member(var, Dims), !,
		            append(["The expression for field ", FieldName, " evaluates to a list, or array of lists. A model variable cannot represent a list."], Error);
			\+ FieldName = "Equation",
			    (Base = boolean; \+ Dims = []), !,
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

test_eqn(Equation, IndxCount, InterInputs, Type, Dims, ParamList, TestError) :-
	list_of(_, IndxCount, DestInds),
	append(InterInputs, ExpInters, AllInputs),
	
	on_exception(ParseException,
	    (replace_subexps(Equation, dialogue, expand_params,
			     AllInputs, top_down, ParamSubs, FullExpr),
		length(ExpInters, _), !, /* close list end */
	        (member(input_link(_,_, Param, _, PDims), ExpInters),
		    \+ Param = '/dest/',
		    var(PDims), !,
		    raise_exception(undefined_parameter(Param));
		make_intermediates(FullExpr, '/dest/',
				   [sm(_,_,_, fm_loop(DestInds))], _, [],
				   [], 1, _, Type, Inters,
				   part_result(Context, _,_,_)))),
	    decode_error(ParseException, ParseError)),
	(ParseError = [], !,
	    get_dims_from_loops(Context, XDims, _),
	    Dest = instance(internal,_, use_inter('/dest/'),_, Type-XDims),
	    match_param_dims(ExpInters, [Dest | Inters], TestError),
	    real_dims_only(XDims, Dims),
	    all(dialogue, get1st, [build(ParamSubs), build(ParamList)]);
	    /* Hack alert. The term representing the dest context has indices
	    (so index(n) will work) but no loops, so we don't need to add it
	    to the relative source contexts */
	TestError = ParseError).

match_param_dims([], _, []).
match_param_dims([input_link(_,_, Name, LType-LDims, _) | MoreLinks],
		 Inters, Err) :-
	select(I, Inters, MoreInters),
	I = instance(internal, _, use_inter(Name), _, IType-IDims),
	real_dims_only(IDims, Dims),
	(prefix(IDims, LDims), !,
	    (promote_unit(IType, LType), !,
		(\+ Name = '/dest/',
		    build_array(IType, Dims, Array),
		    check_param_brackets("explicit intermediate result",
					 Name, Array, Err), !;
		    match_param_dims(MoreLinks, MoreInters, Err));
		      
		sicstus_format_to_chars("This equation is badly formed because it contains the explicit intermediate result ~w which is used in a context where it needs to have type ~w. However the definition of this value produces a result with type ~w, which cannot be used in this context.", [Name, LType, IType], Err));
	real_dims_only(LDims, FixedLDims),
	sicstus_format_to_chars("This equation is badly formed because it contains the explicit intermediate result ~w which is used in a context where it needs to have dimensions ~w. However the definition of this value produces a result with dimensions ~w, which do not match.", [Name, FixedLDims, Dims], Err)).
/* also check name of exp inter for right brackets */

real_dims_only(IDims, Dims) :-
	append(Dims, ISpares, IDims),
	\+ (member(Var, ISpares), nonvar(Var)), !.

check_dim_match(P, Q) :- P=Q; Q=0.

get1st(var_pair(A, _), A).

expand_params(InterInputs, Param, DoneExpr, Recurse) :-
	get_solo_list_depth(Param, _),
	/* when making dummy links for explicit intermediate results, check
	the 1sr field (influence id) uis a free var, and if so, use the
	4th field to hold the dims */
	    member(input_link(Link,_, Param, IDims, Units), InterInputs), !,
	        (nonvar(Link), !,
		    analyze_array(Units, Base, Dims),
                    (units:get_conversion(_, Base, Base, _), !,
		        Type = real;
		    Type = Base);
		IDims = Type-Dims,
		    length(Dims, 4)),
		make_inds_for(Dims, Loops, Inds),
		DoneExpr = param(arr(_, Param, Inds), Type, Loops, _, true),
	    Recurse = 0;
	(Param = (ExpInt=_,_),
	    member(input_link(_,_, ExpInt,_, Dims), InterInputs), !,
	    var(Dims), /* only checked so we dont stick on the recursion */
	    Dims = something,
	    DoneExpr = Param;
	expand_library('/dest/', Param, DoneExpr)),
	    Recurse = 1.

decode_error(ParseError, TestError) :-
	ParseError =.. [Type, Cause | More],
	replace_subexps(Cause, dialogue, collapse_params, _, top_down,
			_, SimpleError),
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
	Type = needs_number_index, !,
	    SimpleError =.. [Functor, _, Ind],
	    sicstus_format_to_chars("The function \"~a\" needs a numerical value for it's second argument. \"~w\" does not fit -- it evaluates to a boolean or something.",
			   [Functor, Ind], TestError);
	Type = got_list_for_array, !,
	    SimpleError =.. [Functor, Arr | _],
	    sicstus_format_to_chars("The function \"~a\" needs a fixed membership array (of anything) for its first argument. \"~w\" does not fit -- it represents a variable membership list.", [Functor, Arr], TestError);
	Type = got_scalar_for_array, !,
	    SimpleError =.. [Functor, Arr | _],
	    sicstus_format_to_chars("The function \"~a\" needs a fixed membership array (of anything) for its first argument. \"~w\" does not fit -- it represents a single value.", [Functor, Arr], TestError);
	Type = only_works_on_array, !,
	    SimpleError =.. [Functor, Arr | _],
	    sicstus_format_to_chars("The function \"~a\" needs a fixed membership array (of anything) for its first argument. \"~w\" does not fit -- it represents either a single value or a variable membership list.", [Functor, Arr], TestError);
	Type = no_such_function, !,
	    More = [Op],
	    sicstus_format_to_chars("Attempting to process subexpression \"~w\": Simile does not include \"~a\" as a function.",
			   [SimpleError, Op], TestError);
	Type = wrong_no_of_args, !,
	    More = [Op, Arity, FnArity],
	    sicstus_format_to_chars("Attempting to process subexpression \"~w\": You have tried to use the function \"~a\" with ~d arguments, but it must take ~d",
			   [SimpleError, Op, Arity, FnArity], TestError);
	Type = cannot_combine_argument_dimensions, !,
	    sicstus_format_to_chars("Simile cannot work out what dimensions the result of \"~w\" should have -- the dimensions of the arguments are incompatible.",
			   [SimpleError], TestError);
	Type = mismatched_units, !,
	    More = [Get, Want],
	    sicstus_format_to_chars("The arguments of \"~w\" have the following types: ~w. These cannot be matched to the expected argument types for this function, which are ~w.", [SimpleError, Get, Want], TestError);
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
			member(input_link(_,_, SpareParam, _,_), 
FromThat)), !,
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

start_progress_dialogue :-
	tk_start_progress_dialogue.

reassure_user(String) :-
	tk_update_infobox(String).

finish_progress_dialogue :-
	tk_finish_progress_dialogue.

warn_runtime :-
	tk_alter_model.
