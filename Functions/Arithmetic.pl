%function( name_of_function, return type, list_of_parameter_types).
function(wrapped, boolean, [int, int, int]).
function(simile_mod, real, [real, real]).
function(gaussian, real, [real, real, real]).
function(wrapped, boolean, [int, int, int]).
function(simile_mod, real, [real, real]).

newton_raphson(Lo_start, Hi_start, Poly) --> (if time(1)==0 then Lo_start elseif time(1)==dt(0) then Hi_start elseif prev(1)==prev(2) then prev(1) else prev(2)+(prev(1)-prev(2))*last(last(Poly))/(last(last(Poly))-last(Poly))).

rand_const(Lo, Hi) --> at_init(rand_var(Lo, Hi)).

rand_const(Lo, Hi) --> at_init(rand_var(Lo, Hi)).

% returns the sign of a number, -1 if negative or 1 if positive
sgn(real) --> choose(real==0,1,int(real/abs(real))).
