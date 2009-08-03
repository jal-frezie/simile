iterations(Alarm) --> st=sofar(if Alarm then 0 else st+1),st.

const_delay(val,time) -->
	count_through = int(10*time(0)),
	shift = count_through - last(count_through),
	[array] = makearray(if place_in(1)>10*time-shift then
			   val
			   elseif time(0)==at_init(time(0)) then
			   default(val)
			   else element(sofar([array]),place_in(1)+shift),
			10*time),
	element([array],1).

var_delay(val,time) -->
	ptw = int(simile_mod(10*time(0),1000))+1,
	ptr = int(simile_mod(10*(time(0)-time),1000))+1,
	[array] = makearray(if wrapped(last(ptw),ptw,place_in(1))
			   then val
			   else last(element([array],place_in(1))),
			1000),
	element([array],ptr).

