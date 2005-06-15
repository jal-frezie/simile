/* units.pl --- yet another shiny, efficient new module written by Jasper to 
replace a huge steaming pile of convoluted entrails spewed up by Geraint. */

sicstus_module(units, [get_conversion/4, extract_units_root/4,
         default_tick_is/1, sort_units/3, defined_as_unit/2]).

default_tick_is(day).

get_conversion(Source, Source_units, Dest_units, Converted_source) :-
	standard_name(Source_units, SourceU),
	standard_name(Dest_units, DestU),
	add_conversion(SourceU/DestU, *, 1, 1, Mnum, Qnum),
	(Mnum = Qnum, !,
	    Converted_source = Source;
	    /* gcd with floats sometimes causes crashes in Linux
	    Common is gcd(Mnum, Qnum),
	    New_Mnum is Mnum/Common,
	    New_Qnum is Qnum/Common, */
	Converted_source = Source*(Mnum/Qnum)).

/* add_conversion/6: This takes a unit and a combination of baseline units, and
returns a new combination of baseline units and a multiplier and quotient, which
correspond to the original combination multiplied or divided, according to the 
given sign, by the given unit...

March 2001: Initial values changed from 1 to 1.0 because converting rainfall
in mm/month to mks was producing integers too large for Tcl execution. */

add_conversion(Unit, Sign, BaseIn, BaseOut, Mnum, Qnum) :-
	(number(Unit), Factor = Unit;
	    Unit = _^0, Factor = 1.0),
	BaseOut = BaseIn,
	(Sign = (*), Mnum = Factor, Qnum = 1.0;
	    Sign = (/), Mnum = 1.0, Qnum = Factor);
	unit_expansion(Unit, Defn),
	    add_conversion(Defn, Sign, BaseIn, BaseOut, Mnum, Qnum);
	break_product(Unit, Op, Top, Bottom),
	    add_conversion(Top, Sign, BaseIn, BaseMid, M1, Q1),
	    combine_signs(Sign, Op, Sign2),
	    add_conversion(Bottom, Sign2, BaseMid, BaseOut, M2, Q2),
	    Mnum is M1*M2, Qnum is Q1*Q2;
	baseline(Unit, Dimension),
	    Mnum = 1.0, Qnum = 1.0,
	    (combine_signs(Sign, '/', Sign2),
		select_factor_from(BaseIn, Dimension, Sign2, BaseOut), !;
		join_without_ones(Sign, BaseIn, Dimension, BaseOut)).


break_product(Unit, Op, Top, Bottom) :-
	Unit =.. [Op, Top, Bottom],
	    (Op = (*); Op = (/));   
	Unit = Bottom^Exp,
	    (Exp > 0, NextExp is Exp-1, Op = (*);
	    Exp < 0, NextExp is Exp+1, Op = (/)),
	    (NextExp = 0, !, Top = 1;
		Top = Bottom^NextExp).

/* select_factor_from: extracts a factor from an expression. Args are:
+Expr The source expression
?Factor The factor extracted
?Sign * if Expr was multiplied by factor, / if divided
-Rest Remainder of Expr not containing Factor
*/

select_factor_from(Expr, Factor, Sign, Rest) :-
	Expr = 1, !, fail;
	atomic(Expr), Factor = Expr, Sign = (*), Rest = 1, !;
	break_product(Expr, Op, Ex1, Ex2),
	(select_factor_from(Ex1, Factor, Sign, Rest_of_Ex1),
	    Rest =..[Op, Rest_of_Ex1, Ex2];
	    combine_signs(Op, Sign, Sign2),
	    select_factor_from(Ex2, Factor, Sign2, Rest_of_Ex2),
	    (Rest_of_Ex2 = 1, !,
		Rest = Ex1;
		Rest =..[Op, Ex1, Rest_of_Ex2])).

/* 2003 effort : after combining units, standardize the form, then add
conversion factors for any pairs whose dimensions cancel or combine. */

sort_units(Before, After, Conv) :-
	select_factor_from(Before, F1, Op1, Step1),
	select_factor_from(Step1, F2, Op2, Mid),
	get_conversion(1, F1, F2, SomeConv),
	(Op1 = (*), Op2 = (/), !,
	    Simpler = Mid;
	    Op1 = Op2, SomeConv > 1, !,
	    join_without_ones(Op1, F2, Mid, Step2),
	    Simpler =.. [Op2, F2, Step2]),
	sort_units(Simpler, After, MoreConv),
	    Conv =.. [Op1, MoreConv, SomeConv];
	After = Before, Conv = 1.

extract_units_root(Units, Depth, Root, Conv) :-
	(Depth < 0,
	    Sign = (/),
	    UseDepth is -Depth;
	    Sign = (*),
	    UseDepth = Depth),
	implode_units(Units, Depth, NonConvRoot, Left),
	add_conversion(Left, Sign, 1, Bases, M, Q),
	implode_units(Bases, Depth, ConvRoot, WontGo),
	(WontGo = 1, !,
	    join_without_ones(Sign, ConvRoot, NonConvRoot, Root),
	    Conv is M/Q;
	    raise_exception(no_nth_root_for_units(Units, UseDepth))).

implode_units(Bases, Depth, Root, Remains) :-
	get_n_times(Bases, Depth, Factor, Sign, Left), !,
	implode_units(Left, Depth, MoreRoot, Remains),
	join_without_ones(Sign, MoreRoot, Factor, Root);
	Root = 1, Remains = Bases.
 
get_n_times(Units, Depth, Factor, Sign, Left) :-
	select_factor_from(Units, Factor, Sign, More),
	(Depth = 1, !,
	    More = Left;
	    Deeper is Depth-1,
	    get_n_times(More, Deeper, Factor, Sign, Left)).

combine_signs(*, *, *).
combine_signs(*, /, /).
combine_signs(/, *, /).
combine_signs(/, /, *).

join_without_ones(Sign, P, Q, All) :-
 Sign = (*), (P=1,All=Q; Q=1,All=P), !;
 All =.. [Sign, P, Q].

:- dynamic(baseline/2).
:- dynamic(unit_definition/2).
:- dynamic(longhand/2).

%unit prefixes, most common first
unit_prefixes(10, deca, da ).
unit_prefixes(0.1, deci, d ).
unit_prefixes(100, hecto, h ).
unit_prefixes(0.01, centi, c ).
unit_prefixes(1000, kilo, k ).
unit_prefixes(0.001, milli, m ).
unit_prefixes(1.0e6, mega, 'M' ).
unit_prefixes(1.0e-6, micro, U ) :- name(U, [181]).    %%%%%%%%%%% 
unit_prefixes(1.0e9, giga, 'G' ).
unit_prefixes(1.0e-9, nano, n ).
unit_prefixes(1.0e12, tera, 'T' ).
unit_prefixes(1.0e-12, pico, p ).
unit_prefixes(1.0e15, peta, 'P' ).
unit_prefixes(1.0e-15, femto, f ).
unit_prefixes(1.0e18, exa, 'E' ).
unit_prefixes(1.0e-18, atto, a ).
unit_prefixes(1.0e21, zetta, 'Z'). 
unit_prefixes(1.0e-21, zepto, z ).
unit_prefixes(1.0e24, yotta, 'Y').
unit_prefixes(1.0e-24, yocto, y ).

/* longhands are case insensitive */
standard_name(Unit, AbbrevUnit) :-
	(atom(Unit),
	    name(Unit, UnitStr),
	    ame_gen:lower(UnitStr, LowUnitStr),
	    name(LowUnit, LowUnitStr),
	    longhand(LowUnit, AbbrevUnit), !;
	    AbbrevUnit = Unit).

unit_expansion(Unit, Def) :-
	atom(Unit),
	(unit_definition(Unit, Def), !;
	    unit_prefixes(Multiplier, _Long, Pre),
	    atom_concat(Pre, InnerUnit, Unit),
	    stands_for(InnerUnit, InnerDef),
	    Def = Multiplier*InnerDef).

defined_as_unit(FullName, Def) :-
	standard_name(FullName, Name),
	stands_for(Name, Def).

stands_for(Unit, Def) :-
	baseline(Unit, _Dim), Def = Unit;
	unit_definition(Unit, Def).

