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

sicstus_module(dialogue,
	       [interactively_parse/1, test_eqn/8, check_param_usage/5]).

sicstus_use_module([library(lists),
		    sp_only, m_update, ame_gen, output, utility, inters]).

/* helpers for sending function list */
pass_functions(LibFuns) :-
	setof(FnAtom, atomize_function(FnAtom), FuncList),
	append(FuncList, LibFuns, AllFns),
	prepare_equation(AllFns).
	
atomize_function(FnAtom) :-
	inters'><'builtin(Category, Functor, ResultSort, ArgSorts),
	spell_out([ResultSort | ArgSorts], 1),
	make_arg_list(ArgSorts, String),
	sicstus_format_to_chars("{Built-in {~a}} internal ~a (~s) returns ~w",
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

:- dynamic([table_data_is/1, def_unit_and_index_type_list_are/2]).

interactively_parse(Part) :-
	get_input_info(Part, Input_list),
	fill_inputs(Input_list),
	get_host(Part, ClickedObj),
	(default_units(ClickedObj, TypeBase, TypeDims), !; true),
	list_index_meanings(Part, ISpecs),
	all(dialogue, index_types, [build(ISpecs), build(IndxCount)]),
	asserta(def_unit_and_index_type_list_are(TypeBase-TypeDims, IndxCount)),
	(get_av_pair(Part, 0, table_data, TableSpec), !;
	    TableSpec = ''),
	(find_type(ClickedObj, state), !,
	    extract_rule_forms(Part, Input_list, Rules);
	  Rules = []),
	handle_eqn_interaction(Part, Input_list, TableSpec, Rules),
	    retractall(def_unit_and_index_type_list_are(_,_)).

handle_eqn_interaction(Part, Input_list, TableSpec, Rules) :-
	interact_equation(Result_list),
	(Result_list = [], !; % dialogue cancelled
	  (TableSpec = '', !;
	      asserta(table_data_is(TableSpec))), % needed in parser
	    update_equation(Part, Input_list, Result_list, Effect),
	    retractall(table_data_is(_TableSpec)),  
		((Effect = new_effect_accepted(Cause, NewSpec, NewVal, ArrSpec),
		    ArrSpec = Units-Dims,
		    safe_tcl_eval(['RedoChangeOfCause', Units, br(Dims)], _);
		  Effect = rule_list_accepted(Cause, NewSpec, NewVal, ArrSpec,
					      _,_,_,_,_,_)), !,
		    update_rules(Rules, Cause-NewSpec-NewVal-ArrSpec,
				 NewRules);
		  NewRules = Rules),
	      (Effect = input_list_changed_to(NewInputList), !,
		  fill_inputs(NewInputList);
		  NewInputList = Input_list),
		(Effect = table_spec_changed_to(NewTableSpec), !;
		    % Tcl data already updated, no need to change it
		    NewTableSpec = TableSpec),
		(Effect = user_advice_generated(Mess),
		    query(Mess, warning, fill_equation, [ok], _);
		    true),
	    ((Effect = eqn_accepted(Is_P, Result, UserFnList, OldEqn,
				    NewArrSpec, TabDat, MinVal, MaxVal,
				    Desc, Comment, NewInputs),
		update_parameterhood(Part, Is_P, AffectedNode),
		add_parameter(AffectedNode, 0, value, Result),
		add_parameter(AffectedNode, 0, spec, OldEqn),
		(\+ TabDat = 0, TableAttr = TableSpec, !;
		    TableAttr = ''), /* no tables/graphs found */
		add_parameter(AffectedNode, 0, table_data, TableAttr),
		add_parameter(AffectedNode, 0, uses_local_fns, UserFnList);
	      Effect = rule_list_accepted(_,_,_,_, Is_P, MinVal, MaxVal,
					  Desc, Comment, NewInputs),
		update_parameterhood(Part, Is_P, AffectedNode),
	        add_rule_specs_and_vals(AffectedNode, NewRules, NewArrSpec)),
		% decide how to save specs and values -- merge with above
	      
		add_parameter(AffectedNode, 0, units, NewArrSpec),
		add_parameter(AffectedNode, 0, min_val, MinVal),
		add_parameter(AffectedNode, 0, max_val, MaxVal),
		get_host(AffectedNode, Visible),
		(Visible is_of_sort box, !, CAttrType = 0; CAttrType = 2),
		add_parameter(Visible, CAttrType, description, Desc),
		add_parameter(Visible, CAttrType, comment, Comment),
		update_links_and_vars(NewInputs); % and finish
		handle_eqn_interaction(Part, NewInputList, NewTableSpec,
				       NewRules))).

index_types(ind_spec(_Name, _Posn, Ind, _Link), Type) :-
	inters'><'type_ind(Ind, Type).

update_rules(Old, C-S-V-D, [C-S-V-D | Left]) :-
	select(C-_S-_V-_D, Old, Left), !;
	Left = Old.

extract_rule_forms(Part, InputList, Rules) :-
	(get_av_pair(Part, 0, spec, SpecList),
	    get_av_pair(Part, 0, value, ValueList), !,
	    convert_rule_format(SpecList, ValueList, OldRules),
	    all(dialogue, initialize_dims,
		[build(OldRules), unify(Part), unify(InputList)]);
	  OldRules = []),
	list_evt_captions(Part, Triggers),
	select_current_triggers(OldRules, Triggers, Rules).

select_current_triggers(_, [], []).
select_current_triggers(Old, [T1 | Triggers], [T1-S-V-D | Rules]) :-
	(member(T1-S-V-D, Old), !; S = "", V = '', D = any-[]),
	select_current_triggers(Old, Triggers, Rules).

initialize_dims(_C-_S-Equation-GotUnits, Fn, InterInputs) :-
	def_unit_and_index_type_list_are(_, IndxCount),
	test_eqn(Equation, Fn, IndxCount, InterInputs,
		 Type, Dims, _ParamList, ParseError),
	(ParseError = [], !,
	    GotUnits = Type-Dims;
	  GotUnits = any-[]).

add_rule_specs_and_vals(Node, Rules, CommonUnits) :-
	purge(Rules, [_C-_S-''-_D], RulesWithEfx),
	convert_rule_format(SpecList, ValueList, RulesWithEfx),
	combine_dims(RulesWithEfx, CommonBase-CommonDims),
	build_array(CommonBase, CommonDims, CommonUnits),
	add_parameter(Node, 0, value, ValueList),
	add_parameter(Node, 0, spec, SpecList).

combine_dims([], any-[]).
combine_dims([_C-_S-_V-(Base-Dims) | RuleList], CommonType-CommonDims) :-
	combine_dims(RuleList, Gen-SoFar),
	inters'><'value(Any),
	inters'><'try_units(Any, [Any, Any], [Base, Gen], CommonType),
	inters'><'longest_path([Dims, SoFar], CommonDims).	
	
convert_rule_format(Spec, Value, Rules) :-
	Spec = '', Value = '', Rules = [];
	Rules = [C-S-V-_D | MoreR],
	(Spec = (S on C), Value = (V on C),
	  MoreR = [];
	Spec = (S on C, MoreS), Value = (V on C, MoreV),
	    convert_rule_format(MoreS, MoreV, MoreR)), !.
	
/* update_equation/5: This makes sure that if the user has entered a
new destination name or units for an existing variable they are added
to the model; it also adds them to the triples and checks that the
function makes sense. If it does not, it pops up a message in a
separate dialog box, then hands back to the main one, otherwise it
updates the actual values and removes the box. Cancel (signalled by
all args being empty) escapes from here.

Note that interact_equation should return strings for all these
things. */

% sketch graph or table edited -- 2 elts
update_equation(Function,_, [Table_st, Data_st], Effect) :-
	get_term(Table_st, TableData, _),
	/* should be no errors as it is auto generated */
	TableData = [FileName | DataSpec],
	(FileName = '/graph/', !,
	    length(DataField, 3),
	    append(DataField, [Dims | Indices], DataSpec),
	    output'><'chop_list(Data_st, DataStrs),
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

% name or units for an input parameter edited -- 3 elts
update_equation(_, Input_list, [LineIndxStr, Parm_st, New_unit_st], Effect) :-
	name(LineIndx, LineIndxStr),
	append(EarlyInputs,
	       [input_link(Link, New_var, _, Current_unit, _) | LateInputs],
	       Input_list),
	length(EarlyInputs, LineIndx), !,
	get_term(Parm_st, New_param, Complaint0),
	(\+ Complaint0 = [], !,
	    text'><'expand_message(param, [], TrField),
	    Complaint2 = bad_syntax(TrField, Complaint0);
	    get_term(New_unit_st, NewUnits, Complaint1),
	    (Complaint1 = [], !;
		text'><'expand_message(in_units, [], TrField),
		Complaint2 = bad_syntax(TrField, Complaint1))),
	
	(Complaint2 = [], !,
	    text'><'expand_message(ip_name, [], TrParam),
	    (check_param_brackets(TrParam, New_param, Current_unit,
				  Complaint), !;
		(NewUnits = '', !,
		    NewInputUnit = Current_unit;
		    analyze_array(Current_unit, CurrentBase, CurrentDims),
		    build_array(NewUnits, CurrentDims, NewInputUnit),
		    check_unit(CurrentBase, NewUnits, 2, Complaint)));
	    Complaint = Complaint2),
	
	(Complaint = [], !,
	    warn_dimless_scaler(NewUnits),
	    append(EarlyInputs, [input_link(Link, New_var, New_param,
		    Current_unit, NewInputUnit) | LateInputs], NewInputs),
	    Effect = input_list_changed_to(NewInputs);
	Effect = user_advice_generated(Complaint)).

% Normal equation entry -- 7 elts
update_equation(Function, InterInputs,
		[Eqn_st, Unit_st, Is_P_st, Desc_st, Cmt_st, Min_st, Max_st],
		Effect) :-
	def_unit_and_index_type_list_are(TypeBase-TypeDims, IndxCount),
	get_host(Function, Ev),
	name(Is_P, Is_P_st),
	(Ev is_of_sort discrete, !,
	    ParamAllowances = [[-1,1,1], [0,1,1], [1,1,0], [2,0,0]];
	  ParamAllowances = [[-1,1,0], [0,1,0], [1,0,0], [2,0,0]]),
	member([Is_P, ParamsAllowed, _EventInsAllowed], ParamAllowances),
	get_term(Unit_st, Units, UnitFormError),
	get_term(Eqn_st, Result, EqnFormError),
	(Result = '', !,
	    ParseError = [];
	  EqnFormError = [], !,
	    test_eqn(Result, Function, IndxCount, InterInputs,
		      EqnBase, EqnDims, ParamList, ParseError);
	  ParseError = bad_syntax('Equation', EqnFormError)),
	(ParamsAllowed = 0,
	    nonvar(ParamList),
	    member(ParamName, ParamList), !,
	    EqnError = bad_link_use(ParamName);
	 EqnError = ParseError),

	(\+ EqnError = [], !,
	    Complaint5 = EqnError;
	EqnBase == cond_spec, \+ TypeBase == cond_spec,
	    Complaint5 = misplaced_cond_spec;
	(Is_P = 1, find_type(Ev, event), !, % limit-type
	    MinMaxNeeded = 1; % at least
	  Is_P = 1, \+ inherently_bound(Units),
	    \+ inherently_bound(EqnBase), !, MinMaxNeeded = 2;
	  MinMaxNeeded = 0),
	text'><'expand_message(minval, [], TrMin),
	text'><'expand_message(maxval, [], TrMax),
	check_bound(Min_st, TrMin, Function, MinMaxNeeded, [],
		    Min, MinVal, MinBase, MinErr),
	    (\+ MinErr = [], !,
		Complaint5 = MinErr;
	      (Min = '', !,
		  Alts = [TrMin];
		Alts = []),
		check_bound(Max_st, TrMax, Function, MinMaxNeeded, Alts,
			Max, MaxVal, MaxBase, Complaint5))),

	(Complaint5 = [], !,
	(Unit_st = "", Eqn_st = "", Min_st = "", Max_st = "",
	    /* If no eqn, bounds or units supplied, assume real */
	    (Is_P > 0, NewArrSpec = 1; NewArrSpec = ''), TypeError = [], !;
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
/* This is a very roundabout way of checking unit consistency of min/max
	-- it works, but is pretty opaque */
	on_exception(_PropError, propagate_units(min(Max, max(Min, Result)),
						any, [any, any, any],
			[EqnBase, MinBase, MaxBase], RawBase),
		     TypeError = minmax_wrong(EqnBase)),
	(nonvar(TypeError);
	    /* First, check that the equation can have the units
	       given, or set given units to the default units for the
	       equation if there are none. */
	  \+ UnitFormError = [],
	    TypeError = bad_syntax('Units', UnitFormError);

	    ((InterInputs = [], % If there are no incoming influences...
	      (EqnBase = 1; % ...and the equation evaluates to a dimensionless
		  promote_unit(EqnBase, real)); % quantity,
	      use_units_in(Function, 'No')), % or else if math checking is off,
		CheckLevel = 1; % allow it to have any given physical units
	      CheckLevel = 2), % otherwise dimensions must match
	    appropriate_units(Units, TypeBase, RawBase, CheckLevel,
			      NewUnits, TypeError))),

	    build_array(NewUnits, EqnDims, NewArrSpec),
	    (\+ var(TypeDims),
		\+ EqnDims = TypeDims,
		build_array(TypeBase, TypeDims, Target),
		UnitError = mismatched_arrays(Target, TypeDims, EqnDims);
	      UnitError = TypeError),

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
					       quoted, _V, _U),
			      name(Hiccup, Complaint6)),
		    member(Dim, MultInts),
		    (nonvar(Complaint6);
		    Dim = var, !,
			Complaint6 = expr_denotes_list;
		    \+ (integer(Dim), Dim > 1), !,
		    % should never happen, parser now checks subexps for this
		    Complaint6 = bad_array_size(Result, Dim));
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
	sicstus_atom_chars(OldEqn, OrigSt), % crash here if eqn too big

	warn_dimless_scaler(NewUnits),
	(FinalComplaint = [], !,
	    Effect = eqn_accepted(Is_P, Result, UserFnList, OldEqn, NewArrSpec,
				  TabDat, MinVal, MaxVal, Desc, Comment,
				  New_inputs);
%	fill_equation(OldEqn, Units, EqnDims, Is_P, Desc, Comment, Min, Max),
	 FinalComplaint = continue, !,
	    Effect = input_list_changed_to(New_inputs);
	 Effect = user_advice_generated(FinalComplaint)).

% new trigger selected for a state-change rule -- has 5 elts
update_equation(Function, InterInputs, [Eqn_st, Evt_st, Unit_st,
					_Min_st, _Max_st],
		Effect) :-
	name(EvtId, Evt_st),
	def_unit_and_index_type_list_are(_, IndxCount),
	get_term(Eqn_st, Result, EqnFormError),
	(Result = '', !,
	    EqnBase = any,
	    ParseError = [];
	  EqnFormError = [], !,
	    test_eqn(Result, Function, IndxCount, InterInputs,
		      EqnBase, EqnDims, _ParamList, ParseError);
	  ParseError = bad_syntax('Rule outcome', EqnFormError)),
	(ParseError = [], !,
	    get_term(Unit_st, GivenUnits, UnitParseError),
	    (UnitParseError = [], !,
		appropriate_units(GivenUnits, any, EqnBase, 2,
				  NewUnits, FinalError);
	      FinalError = UnitParseError);
	  FinalError = ParseError),

	(FinalError = [], !,
	    purge(Eqn_st, "\\", OrigSt),
	    sicstus_atom_chars(OldEqn, OrigSt),
	    Effect = new_effect_accepted(EvtId, OldEqn, Result,
					 NewUnits-EqnDims);
	 Effect = user_advice_generated(FinalError)).

% OK to rule dialogue -- has 8 elts
update_equation(Function, Inputs, [Eqn_st, Evt_st, Unit_st, Is_P_st,
				   Desc_st, Cmt_st, Min_st, Max_st], Effect) :-
	update_equation(Function, Inputs, [Eqn_st, Evt_st, Unit_st,
					   Min_st, Max_st], SubEffect),
	(SubEffect = new_effect_accepted(EvtId, OldEqn, Result, NewUnits), !,
	    name(Is_P, Is_P_st),
	    name(MinVal, Min_st),
	    name(MaxVal, Max_st),
	    name(Desc, Desc_st),
	    name(Comment, Cmt_st),

% have to check the other stuff some time but later
	    purge(Eqn_st, "\\", OrigSt),
	    sicstus_atom_chars(OldEqn, OrigSt),
	    Effect = rule_list_accepted(EvtId, OldEqn, Result, NewUnits, Is_P,
					MinVal, MaxVal, Desc, Comment, Inputs);
	  Effect = SubEffect).

warn_dimless_scaler(NewUnits) :-
	units'><'check_and_report_units(NewUnits, TargetDims, ScaleFactor),
% flag up dimensionless conversions; here is not really the place, but...
	(\+ TargetDims = 1; ScaleFactor = 1.0;
	query(is_scale_factor(NewUnits, ScaleFactor),
	    warning, top, [ok], ok)), !; true.

appropriate_units(Units, TypeBase, RawBase, CheckLevel,
                  NewUnits, TypeError) :-
	promote_unit(RawBase, ComboBase),
	\+ member(ComboBase, [const_int, const_ratio]),
		% variables cannot have constant units even if constant
	(\+ member(Units, ['', any]), !,
	    (Units = int, ComboBase = 1,
	        NewUnits = 1;
		% num constant changed from int to float -- allow
	      NewUnits = Units); % otherwise if units were given, use them
	    nonvar(TypeBase), \+ TypeBase = any,
		(\+ TypeBase = 1; ComboBase = int), !,
	      NewUnits = TypeBase; % interesting default units, use them
	    NewUnits = ComboBase), % last resort, use units from eqn
	check_unit(ComboBase, NewUnits, CheckLevel, EqnToUnitError),
	
	(\+ EqnToUnitError == [],
	    TypeError = EqnToUnitError;
	    /* Next check that the value's units,however they were
	       specified, are appropriate for this component */
	
	    (TypeBase = any, !,
	        Strict = 0;
	      TypeBase = 1, !,
	        Strict = 1;	% allow original physical units
	      Strict = 2),
	    check_unit(NewUnits, TypeBase, Strict, TypeError)).

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
		Fn =.. [Functor | TptArgs];
		fragment_expansion(Cat, _File, Functor, _RetVal, TptArgs)),
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
	output'><'chop_list(Data, Alternator),
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

check_bound(Eqn_st, FieldName, Function, Needed,
            Alternatives, Eqn, Value, Base, Error) :-
	Eqn_st = [], !,
	    Base = any,
	    Eqn = '',
	    Value = '',
	    (Needed = 2, !,
		Error = field_needs_value(FieldName);
	    Needed = 1, \+ Alternatives = [],
		Error = some_field_needs_value([FieldName | Alternatives]);
	    Error = []);
	get_term(Eqn_st, Eqn, ParseError),
	(ParseError = [], !,
	    (on_exception(Error,
			  get_actual_size(Function, Eqn, quoted,
					  Values, S, [Base]),
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
	
	DummyDest = [sm(_,_,_, fm_loop(IndxSzs, IndxSzs, _,_))],
	% remove old function fragment submodels --
	% these will be re-created
	m_update'><'superfast_delete(Fn),
	on_exception(ParseExcp,
		     (make_intermediates(FullExpr, Fn, ['/dest/'],
		                        DummyDest, _, [],
					[], dummy, _, Type, _I,
					part_result(Context, _,_,_)),
		     inters'><'get_model_and_loops(Context, DummyDest, _,
						   Loops, _)),
	(replace_subexps(ParseExcp, dialogue, collapse_params,
			 _, top_down, _, ParseError);
			     ParseError = ParseExcp))),
	(nonvar(ParseError), !;
	(member(input_link(_,_, Param, _-PLoops, _), ExpInters),
	    nth(N, PLoops, set(_, loop(Bound,_))),
	    var(Bound),
	    ParseError = cannot_set_dims(N, Param);
	    Type == cond_spec,
	    \+ instance'><'is_lookup_cond(Equation, _),
	    ParseError = bad_cond_spec_form;
	    %sicstus_format_to_chars("Dimension ~d of explicit intermediate variable ~w cannot be determined from its definition", [N, Param], ParseError);
	  get_dims_from_loops(Loops, Dims, _),
		 (member(var, Dims), !,
		    ParseError = expr_denotes_list;
		 \+ member(records, Dims), !;
		    ParseError = expr_denotes_per_record_array))).
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
/*		    (units'><'get_conversion(_, Base, Base, _), !,
		        Type = real;
		    Type = Base), */
		    make_inds_for(Dims, PLoops, Inds);
	        (Param = '/dest/', !,
		        get_ground_part(LRefs, GRefs),
		        length(GRefs, L);
		    m_update'><'analyze_array(Depth, any, Dims),
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
		text'><'expand_message(exp_inter, [], TrXIR),
		check_param_brackets(TrXIR, ExpInt, Array, ParseError), !,
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
	(list(Param),
	    length(Param, N), 
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
			role_texts(SourceCaption,_,_,_), _,_,_), Current),
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
		event'><'off(LinkName),
		event'><'delete_by_dlg(LinkName),
		check_param_usage(FromOthers, AllowLinks, Used, Left, Challenge);
	     Choice = cancel,
		Left = Current,
		Challenge = continue);
	Left = Current,
		Challenge = [].

update_parameterhood(Function, Is_P, AffectedNode) :-
	(member(Function, [Has, Is]),
	implicit_function(Has, Is), !,
	    UsedFn = yes;
	Function = Has,
	    UsedFn = no),
	is_parameter(Has, Was_P),
	((Is_P = Was_P; Was_P = -1), !,
	    AffectedNode = Function;
	  paramness_setup(Has, Is_P, HasFpType, UsesFn),
	  (UsedFn = yes,
	      (UsesFn = yes,
		  AffectedNode = Is;
		m_update'><'delete_implicit_node(Has),
		  AffectedNode = Has);
	    UsedFn = no,
	      (UsesFn = yes,
		  add_implicit_function(Function, AffectedNode);
	        AffectedNode = Function)),
	    add_parameter(AffectedNode, 0, param_type, HasFpType)).

can_build_with(SubValue) :-
	\+ var(SubValue),
	(number(SubValue); SubValue = size(_); SubValue = size(_,_)).

work_out(==, [X,Y], 0) :-
	(X>Y; X<Y), !.
work_out(==, _, 1).

/* Back to realtive normality... */

integer_between(Lo, Hi, Int) :-
	Lo < Hi,
	(Int = Lo;
	NotSoLo is Lo + 1, 
		integer_between(NotSoLo, Hi, Int)).

get_array_nesting(Current_unit, Depth) :-
	analyze_array(Current_unit, _, Dims),
	length(Dims, Depth).
