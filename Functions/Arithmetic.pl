newton_raphson(Lo_start, Hi_start, Poly) --> (if time(1)==0 then Lo_start elseif time(1)==dt(0) then Hi_start elseif prev(1)==prev(2) then prev(1) else prev(2)+(prev(1)-prev(2))*last(last(Poly))/(last(last(Poly))-last(Poly))).

% returns the sign of a number, -1 if negative or 1 if positive
sgn(real) --> choose(real==0,1,int(real/abs(real))).
