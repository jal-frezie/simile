rand_const(Lo, Hi) --> at_init(rand_var(Lo, Hi)).

%function( name_of_function, return type, list_of_parameter_types).
function(factorial, real, [real]).

ways_to_pick(chosen,all) -->
	factorial(all)/(factorial(chosen)*factorial(all-chosen)).
%sample/3 same syntax but declares func that gives different result each call

sample(gaussian_var, real, [real, real]).
sample(poidev, int, [real]).
%function(bnldev, int, [real, int]).
sample(binome, int, [real, int]).
sample(hypergeom, int, [int, int, int]).

colin(List) --> 
	[st0]=makearray(if first(place_in(1)) then 0 else
		       element(sofar([st0])+List,preceding(place_in(1))),
			count(List)),
	legg=rand_var(0,element([st0]+List,count(List))),
	[st]=makearray(if legg>element([st0],place_in(1)) then place_in(1)
		      else element(sofar([st]),preceding(place_in(1))),
		       count(List)),
    element([st],count(List)).

with_colin({Distribution},{Payload}) -->
	with_greatest(if {Distribution}>0
		     then pow(rand_var(0,1),1/{Distribution})
		     else 0, {Payload}).

quantize(v) --> out = (
			tot = last(1.0*tot-1*out)+v*dt(''), round(tot)
		      ), out/dt('').