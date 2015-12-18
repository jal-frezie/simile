at_init(Exp) --> at_phase(0,Exp).
iterations(Alarm) --> st=sofar(if Alarm then 0 else st+1),st.

const_delay(val,duration,initial) -->
	count_through = round(10.0*time(0)),
	shift = count_through - last(count_through),
	[array] = makearray(if place_in(1)>10*duration-shift then
			   val
			   elseif time(0)==at_init(time(0)) then
			   initial
			   else element(sofar([array]),place_in(1)+shift),
			10*duration),
	element([array],1).
const_delay(val,duration) -->
    const_delay(val,duration,at_init(val)).

var_delay(val,time) -->
	ptw = round(simile_mod(10*time(0),1000))+1,
	ptr = round(simile_mod(10*(time(0)-time),1000))+1,
	[array] = makearray(if wrapped(last(ptw),ptw,place_in(1))
			   then val
			   else last(element([array],place_in(1))),
			1000),
	element([array],ptr).

parent('') -->
    at_init(in_progenitor(index(1))).
parent(dummy) -->
    at_init(in_progenitor(index(1))).

/* Added for XMILE compatibility -- functions with last arg are in fragments
DELAY1(input, duration) -->
    DELAY1(input, duration, at_init(input)).
DELAY3(input, duration) -->
    DELAY3(input, duration, at_init(input)).
DELAYN(input, duration, n) -->
    DELAYN(input, duration, n, at_init(input)).
 */
