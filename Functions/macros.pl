subtotals(Arr) --> makearray((if place_in(1)==1 then 0 else
	element(sofar(prev(0)),place_in(1)-1))+element(Arr,place_in(1)),
	count(Arr)).
rankings(L) --> sum(makearray(if element(L,place_in(1))>=L then 1 else 0,
				count(L))).
colin(List) --> legg=rand_var(0,sum(List)),
		1+sum(if subtotals(List)<legg then 1 else 0).
newton_raphson(Lo_start, Hi_start, Poly) --> (if time(1)==0 then Lo_start elseif time(1)==dt(0) then Hi_start else prev(2)+(prev(1)-prev(2))*last(last(Poly))/(last(last(Poly))-last(Poly))).
npv(Earnings, Rate) --> sum(Earnings*makearray(Rate^(1-place_in(1)),count(Earnings))).
true(_) --> 1==1.
false(_) --> 1==0.
