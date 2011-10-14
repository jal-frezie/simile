/* delay is deprecated because it works in time steps, meaning model
behaviour is setup-dependent. Use const_delay or var_delay instead. */
delay(val,steps) -->
	ptw = (if last(ptw)==1000 then 1 else last(ptw)+1),
	ptr = ptw-steps-1000*floor((ptw-steps-1)/1000),
	[array] = makearray(if place_in(1)==ptw then
			   val
		  else
			   last(element([array],place_in(1))),
			1000),
	element([array],ptr).
	
/* init_time used to be used to get at_init with time()==init_time(),
which may not be true if time runs backwards. To help deprecate this,
init_time has been deprecated.

Next line shows how to write 0-ary macros (leave parentheses out) and
macros calling 0-ary functions or macros (put empty atom in parentheses). */
init_time --> at_init(time('')).
/* same macro for unary case */
init_time(Level) --> at_init(time(Level)).

function(wrapped, boolean, [int, int, int]).
function(simile_mod, real, [real, real]).

%Legacy -- needed idler variable trig
gaussian(Trig, Mean, SD) --> gaussian_var(Mean, SD).

% These are the actual sampling functions, returning a new value on
% each evaluation. They should not be used in models, instead use
% e.g., gaussian_const, binome_var, for constants or values that
% behave right in RK and/or ASV.

sample(inst_gaussian, real, [real, real]).
sample(poidev, int, [real]).
sample(binome, int, [real, int]).
sample(hypergeom, int, [int, int, int]).

%Hack to allow 3 EM wards th MRSA model:
dual_hypergeom(pop, mark, samples) -->
	all1=element(samples,1),
	to1=hypergeom_equiv(pop,mark,all1),
	[to1, hypergeom(pop-all1,mark-to1,element(samples,2))].

poly_hypergeom(pop, mark, samples) -->
	[all]=makearray(if place_in(1)==1 then pop 
		       else element(sofar([all])-samples,place_in(1)-1),
		count(samples)),
	[result]=([marks]=makearray(if place_in(1)==1 then mark
			 else element(sofar([marks])-sofar([result]),
				      place_in(1)-1),
		    count(samples)),
		  hypergeom([all],[marks],samples)),
	[result].

/* This is similar to above, but works on binomial rather than hypergeometric
sampling. It takes a list of fractions and gives a binomial deviate for the
first, then one for the second using the remaining population, and so on. It
should make things simpler where there are multiple possibilities each
involving a flow. Order is important. */

poly_binome(probs, num) -->
	[result]=([left]=makearray(if place_in(1)==1 then num
				  else element(sofar([left])-sofar([result]),
					       place_in(1)-1),
				   count(probs)),
		  binome(probs, [left])),
	[result].

% FUNCTIONS WHOSE DEFINITION SETS STATISTICAL MODEL BEHAVIOUR
% Args and result real for interchangeability
% Use these definitions for DETERMINISTIC:
/*
binome_equiv(Prob, Num) --> Prob*Num.

hypergeom_equiv(Pop, Seln1, Seln2) -->
	if Pop==0 then 0 else Seln1*Seln2/Pop.

poly_hypergeom_equiv(Pop, Mark, Samples) -->
	if Pop==0 then 0 else Mark*Samples/Pop.

poly_binome_equiv(probs, num) -->
	[result]=([left]=makearray(if place_in(1)==1 then num
				  else element(sofar([left])-sofar([result]),
					       place_in(1)-1),
				   count(probs)),
		  probs*[left]),
	[result].
*/
% Use these definitions for STOCHASTIC:
binome_equiv(Prob, Num) --> 1.0*binome(Prob, int(Num)).

hypergeom_equiv(Pop, Seln1, Seln2) -->
	1.0*hypergeom(int(Pop), int(Seln1), int(Seln2)).

poly_hypergeom_equiv(Pop, Mark, Samples) -->
	1.0*poly_hypergeom(int(Pop), int(Mark), int(Samples)).

poly_binome_equiv(Probs, Num) --> 1.0*poly_binome(Probs, int(Num)).
/*
Definitions for INTEGER-DETERMINISTIC need to hold state, so
currently need separate macro definition for each argument
dimensionality. Model should really process them in submodels
rather than as array components... */

% subtotals over 1-d arrays
subtotals1(Arr) --> [[st]]=makearray((if first(place_in(1)) then 0 else
    element(sofar([[st]]),preceding(place_in(1))))+element(Arr,place_in(1)),
    count(Arr)),[[st]].

