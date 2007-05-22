rand_const(Lo, Hi) --> at_init(rand_var(Lo, Hi)).

%function( name_of_function, return type, list_of_parameter_types).
%sample/3 same syntax but declares func that gives different result each call

sample(gaussian_var, real, [real, real]).
sample(poidev, int, [real]).
%function(bnldev, int, [real, int]).
sample(binome, int, [real, int]).
sample(hypergeom, int, [int, int, int]).

%Legacy
gaussian(Trig, Mean, SD) --> gaussian_var(Mean, SD).

colin(List) --> 
	[st0]=makearray(if first(place_in(1)) then 0 else
		       element(sofar([st0])+List,preceding(place_in(1))),
			count(List)),
	legg=rand_var(0,element([st0]+List,count(List))),
	[st]=makearray(if legg>element([st0],place_in(1)) then place_in(1)
		      else element(sofar([st]),preceding(place_in(1))),
		       count(List)),
    element([st],count(List)).

/* Use these definitions for DETERMINISTIC:
binome_equiv(Prob, Num) --> Prob*Num.

hypergeom_equiv(Pop, Seln1, Seln2) -->
	if Pop==0 then 0 else Seln1*Seln2/Pop. */

/* Use these definitions for STOCHASTIC: */
binome_equiv(Prob, Num) --> binome(Prob, int(Num)).

hypergeom_equiv(Pop, Seln1, Seln2) -->
	hypergeom(int(Pop), int(Seln1), int(Seln2)).