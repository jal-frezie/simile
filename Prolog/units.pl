/* units.pl --- yet another shiny, efficient new module written by Jasper to 
replace a huge steaming pile of convoluted entrails spewed up by Geraint. */

sicstus_module(units, [get_conversion/4, default_tick_is/1]).

default_tick_is(day).

get_conversion(Source, Source_units, Dest_units, Converted_source) :-
	add_conversion(Source_units/Dest_units, *, 1, 1, Mnum, Qnum),
	(Mnum = Qnum, !,
		Converted_source = Source;
/* gcd with floats sometimes causes crashes in Linux
	Common is gcd(Mnum, Qnum),
		New_Mnum is Mnum/Common,
		New_Qnum is Qnum/Common,
*/		Converted_source = Source*(Mnum/Qnum)).

/* add_conversion/6: This takes a unit and a combination of baseline units, and
returns a new combination of baseline units and a multiplier and quotient, which
correspond to the original combination multiplied or divided, according to the 
given sign, by the given unit...

March 2001: Initial values changed from 1 to 1.0 because converting rainfall
in mm/month to mks was producing integers too large for Tcl execution. */

add_conversion(Unit, Sign, BaseIn, BaseOut, Mnum, Qnum) :-
	number(Unit), BaseOut = BaseIn,
		(Sign = (*), Mnum = Unit, Qnum = 1.0;
		Sign = (/), Mnum = 1.0, Qnum = Unit);
	unit_definition(Unit, Defn),
		add_conversion(Defn, Sign, BaseIn, BaseOut, Mnum, Qnum);
	Unit =.. [Op, Top, Bottom],
		add_conversion(Top, Sign, BaseIn, BaseMid, M1, Q1),
		combine_signs(Sign, Op, Sign2),
		add_conversion(Bottom, Sign2, BaseMid, BaseOut, M2, Q2),
		Mnum is M1*M2, Qnum is Q1*Q2;
	baseline(Unit),
		Mnum = 1.0, Qnum = 1.0,
		(combine_signs(Sign, '/', Sign2),
			select_factor_from(BaseIn, Unit, Sign2, BaseOut), !;
		BaseOut =.. [Sign, BaseIn, Unit]).

/* select_factor_from: extracts a factor from an expression. Args are:
+Expr	The source expression
?Factor	The factor extracted
?Sign	* if Expr was multiplied by factor, / if divided
-Rest	Remainder of Expr not containing Factor
*/

select_factor_from(Expr, Factor, Sign, Rest) :-
	Expr = 1, !, fail;
	atomic(Expr), Factor = Expr, Sign = (*), Rest = 1, !;
	Expr =.. [Op, Ex1, Ex2],
		(select_factor_from(Ex1, Factor, Sign, Rest_of_Ex1),
			Rest =..[Op, Rest_of_Ex1, Ex2];
		combine_signs(Op, Sign, Sign2),
			select_factor_from(Ex2, Factor, Sign2, Rest_of_Ex2),
			(Rest_of_Ex2 = 1, !,
				Rest = Ex1;
			Rest =..[Op, Ex1, Rest_of_Ex2])).

combine_signs(*, *, *).
combine_signs(*, /, /).
combine_signs(/, *, /).
combine_signs(/, /, *).

baseline(metre).
baseline(kilogramme).
baseline(second).
baseline(radian).

/* shorthands */
unit_definition(mm, millimetre).
unit_definition(cm, centimetre).
unit_definition(m, metre).
unit_definition(km, kilometre).
unit_definition(g, gramme).
unit_definition(kg, kilogramme).
unit_definition(s, second).
unit_definition(sec, second).
unit_definition(lb, pound).
unit_definition(ha, hectare).

unit_definition(degree, radian*22/1260).
unit_definition(litre,	metre*metre*metre/1000).
unit_definition(pint,	litre*4/7). /* not in USA */
unit_definition(gallon,	pint*8).

unit_definition(minute,	second*60).
unit_definition(hour,	minute*60).
unit_definition(day,	hour*24).
unit_definition(week,	day*7).
unit_definition(month,	year/12).
unit_definition(year,	day*365). /* not quite right */

unit_definition(millimetre, metre/1000).
unit_definition(centimetre, metre/100).
unit_definition(kilometre, metre*1000).
unit_definition(inch,	metre*10/394).
unit_definition(foot,	inch*12).
unit_definition(yard,	foot*3).
unit_definition(mile,   yard*1760).

unit_definition(hectare, 10000*metre*metre).
unit_definition(gramme,	kilogramme/1000).
unit_definition(pound,	gramme*454). /* avoirdupois */
unit_definition(ounce,	pound/16).
unit_definition(stone,	pound*14).
unit_definition(cwt,	stone*8).
unit_definition(ton,	cwt*20).

unit_definition(newton,	kilogramme*metre/second/second).
unit_definition(gravity,	(metre/second/second)*(98/10)). 
	/* Acceleration due to gravity */
unit_definition(kgf,	kilogramme*gravity).
unit_definition(lbf,	pound*gravity).

unit_definition(joule,	newton*metre).
unit_definition(kilocalorie,	joule*4200).
unit_definition(calorie,	kilocalorie/1000).
unit_definition(kwh,	kilowatt*hour). /* energy to power and back again, wtfn? */

unit_definition(watt,	joule/second).
unit_definition(kilowatt,	watt*1000).

unit_definition(kelvin, 1).
