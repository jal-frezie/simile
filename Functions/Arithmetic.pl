% returns the sign of a number, -1 if negative or 1 if positive
sgn(real) --> choose(real==0,1,int(real/abs(real))).
