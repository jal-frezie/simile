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

/* FUNCTIONS WHOSE DEFINITION SETS STATISTICAL MODEL BEHAVIOUR
Use these definitions for DETERMINISTIC:
binome_equiv(Prob, Num) --> Prob*Num.

hypergeom_equiv(Pop, Seln1, Seln2) -->
	if Pop==0 then 0 else Seln1*Seln2/Pop. */

/* Use these definitions for STOCHASTIC: */
binome_equiv(Prob, Num) --> binome(Prob, int(Num)).

hypergeom_equiv(Pop, Seln1, Seln2) -->
	hypergeom(int(Pop), int(Seln1), int(Seln2)).

/* Definitions for INTEGER-DETERMINISTIC need to hold state, so
/* currently need separate macro definition for each argument
/* dimensionality. Model should really process them in submodels
/* rather than as array components... */