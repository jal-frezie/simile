subtotals(Arr) --> [st]=makearray((if first(place_in(1)) then 0 else
    element(sofar([st]),preceding(place_in(1))))+element(Arr,place_in(1)),
    count(Arr)),[st].

rankings(ExL) --> [L] = ExL,
    sum(makearray(
        makearray(
	    if element([L],place_in(2))<element([L],place_in(1)) then 0 else 1,
	count([L])),
    count([L]))).

howmanytrue(BoolList) --> sum(if BoolList then 1 else 0).

firsttrue(BoolArr) --> [st]=makearray(
	if not (first(place_in(1)) or
		element(sofar([st]),preceding(place_in(1))) == '"NULL"')
	    then element(sofar([st]),preceding(place_in(1)))
	elseif element(BoolArr,place_in(1)) then place_in(1)
	else '"NULL"', count(BoolArr)),
    element([st],count(BoolArr)).

posgreatest(Incoming) --> [local]=Incoming,[records]=makearray(
			if first(place_in(1)) or
			element([local],place_in(1))>element([local],element(sofar([records]),preceding(place_in(1)))) then place_in(1)
			else element(sofar([records]),preceding(place_in(1))),count([local])),
            element([records],count([local])).

posleast(Incoming) --> posgreatest(-Incoming).