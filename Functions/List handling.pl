subtotals(Arr) --> [st]=makearray((if place_in(1)==1 then 0 else
    element(sofar([st]),place_in(1)-1))+element(Arr,place_in(1)),
    count(Arr)),[st].
et_subtotals(Arr) --> [st]=makearray((if first(place_in(1)) then 0 else
    element(sofar([st]),preceding(place_in(1))))+element(Arr,place_in(1)),
    count(Arr)),[st].

rankings(ExL) --> [L] = ExL,
    sum(makearray(
        makearray(
	    if element([L],place_in(2))<element([L],place_in(1)) then 0 else 1,
	count([L])),
    count([L]))).

colin(List) --> legg=rand_var(0,sum(List)),1+howmanytrue(subtotals(List)<legg).
et_colin(List) --> 
	[st0]=makearray(if first(place_in(1)) then 0 else
		       element(sofar([st0])+List,preceding(place_in(1))),
			count(List)),
	legg=rand_var(0,element([st0]+List,count(List))),
	[st]=makearray(if legg>element([st0],place_in(1)) then place_in(1)
		      else element(sofar([st]),preceding(place_in(1))),
		       count(List)),
    element([st],count(List)).

howmanytrue(BoolList) --> sum(if BoolList then 1 else 0).

firsttrue(BoolArr) --> [clear]=makearray(if element(BoolArr,place_in(1)) then 0
				    elseif place_in(1)==1 then 1
				    else element(sofar([clear]),place_in(1)-1),
				     count(BoolArr)),sum([clear])+1.
et_firsttrue(BoolArr) --> [st]=makearray(
	if !(first(place_in(1)) or
		element(sofar([st]),preceding(place_in(1))) == '"NULL"')
	    then element(sofar([st]),preceding(place_in(1)))
	elseif element(BoolArr,place_in(1)) then place_in(1)
	else '"NULL"', count(BoolArr)),
    element([st],count(BoolArr)).

posgreatest(Incoming) --> [local]=Incoming,[records]=makearray(
			if place_in(1)==1 then 1
			elseif element([local],place_in(1))>element([local],element(sofar([records]),place_in(1)-1)) then place_in(1)
			else element(sofar([records]),place_in(1)-1),count([local])),
            element([records],count([local])).
et_posgreatest(Incoming) --> [local]=Incoming,[records]=makearray(
			if first(place_in(1)) or
			element([local],place_in(1))>element([local],element(sofar([records]),preceding(place_in(1)))) then place_in(1)
			else element(sofar([records]),preceding(place_in(1))),count([local])),
            element([records],count([local])).

posleast(Incoming) --> [local]=Incoming,[records]=makearray(
            if place_in(1)==1 then 1
            elseif element([local],place_in(1))<element([local],element(sofar([records]),place_in(1)-1)) then place_in(1)
            else element(sofar([records]),place_in(1)-1),count([local])),
            element([records],count([local])).
et_posleast(Incoming) --> [local]=Incoming,[records]=makearray(
			if first(place_in(1)) or
			element([local],place_in(1))<element([local],element(sofar([records]),preceding(place_in(1)))) then place_in(1)
			else element(sofar([records]),preceding(place_in(1))),count([local])),
            element([records],count([local])).
