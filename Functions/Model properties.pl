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
