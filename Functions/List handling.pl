subtotals(Arr) --> [st]=makearray((if place_in(1)==1 then 0 else
element(sofar([st]),place_in(1)-1))+element(Arr,place_in(1)),
count(Arr)),[st].
rankings(ExL) --> [L] = ExL,
    sum(makearray(
        makearray(
	    if element([L],place_in(2))<element([L],place_in(1)) then 0 else 1,
	count([L])),
    count([L]))).
colin(List) --> legg=rand_var(0,sum(List)),
1+sum(if subtotals(List)<legg then 1 else 0).
howmanytrue(BoolList) --> sum(if BoolList then 1 else 0).

first(BoolArr) --> [clear]=makearray(if place_in(1)==1 then 1
				    elseif element(BoolArr,place_in(1)) then 0
				    else element(sofar([clear]),place_in(1)-1),
				     count(BoolArr)),sum([clear])+1.
posgreatest(Incoming) --> [local]=Incoming,[records]=makearray(
			if place_in(1)==1 then 1
			elseif element([local],place_in(1))>element([local],element(sofar([records]),place_in(1)-1)) then place_in(1)
			else element(sofar([records]),place_in(1)-1),count([local])),
            element([records],count([local])).
posleast(Incoming) --> [local]=Incoming,[records]=makearray(
            if place_in(1)==1 then 1
            elseif element([local],place_in(1))<element([local],element(sofar([records]),place_in(1)-1)) then place_in(1)
            else element(sofar([records]),place_in(1)-1),count([local])),
            element([records],count([local])).
