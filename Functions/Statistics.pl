rand_const(Lo, Hi) --> at_init(rand(Lo, Hi)).
rand_var(Lo, Hi) --> at_phase(rand(Lo, Hi)).

%function( name_of_function, return type, list_of_parameter_types).
function(factorial, real, [real]).

ways_to_pick(chosen,all) -->
	factorial(all)/(factorial(chosen)*factorial(all-chosen)).
%sample/3 same syntax but declares func that gives different result each call

sample(gaussian, real, [real, real]).
gaussian_const(mean, SD) --> at_init(gaussian(mean, SD))
gaussian_var(mean, SD) --> at_phase(gaussian(mean, SD))
sample(poidev, int, [real]).
poidev_const(density) --> at_init(poidev(density)).
poidev_var(density) --> at_phase(poidev(density)).

%function(bnldev, int, [real, int]).
sample(binome, int, [real, int]).
binome_const(prob,throws) --> at_init(binome(prob,throws))
binome_var(prob,throws) --> at_phase(binome(prob,throws))
sample(hypergeom, int, [int, int, int]).
hypergeom_const(pop, seln1, seln2) --> at_init(hypergeom(pop, seln1, seln2))
hypergeom_var(pop, seln1, seln2) --> at_phase(hypergeom(pop, seln1, seln2))

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