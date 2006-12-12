/* Next line shows how to write 0-ary macros (leave parentheses out) and
macros calling 0-ary functions or macros (put empty atom in parentheses). */
init_time --> at_init(ind_time('')).
/* same macro for unary case */
init_time(Level) --> at_init(time(Level)).

iterations(Alarm) --> st=sofar(if Alarm then 0 else st+1),st.

delay(val,steps) -->
	ptw = (if last(ptw)==1000 then 1 else last(ptw)+1),
	ptr = ptw-steps-1000*floor((ptw-steps-1)/1000),
	[array] = makearray(if place_in(1)==ptw then
			   val
		  else
			   last(element([array],place_in(1))),
			1000),
	element([array],ptr).

const_delay(val,time) -->
	count_through = int(10*time(0)),
	shift = count_through - last(count_through),
	[array] = makearray(if place_in(1)<=shift then
			   val
			   else
                          element(last([array]),place_in(1)-shift),
			    10*time),
	element([array],10*time).

var_delay(val,time) -->
	ptw = int(simile_mod(10*time(0),1000))+1,
	ptr = int(simile_mod(10*(time(0)-time),1000))+1,
	[array] = makearray(if wrapped(last(ptw),ptw,place_in(1))
			   then val
			   else last(element([array],place_in(1))),
			    1000),
	element([array],ptr).
