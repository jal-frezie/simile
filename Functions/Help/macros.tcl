# help messages for macros.pl
set msgs(subtotals) "subtotals(Arr): Takes an array and returns another array of the same size \
        containing the totals of all the values up to that point in the original array. e.g., \
        subtotals([1,2,4,3]) = [1,3,7,10]."

set msgs(rankings) "rankings(Arr): Takes an array and returns an array of integers of the same \
        size each representing the position in the sequence of largest to smallest \
        (largest = 1) of the corresponding value in the original array. e.g., \
        rankings([8.2, -5.1, 2.5]) = [1,3,2]."

set msgs(newton_raphson) "newton_raphson(Lo_start, Hi_start, Poly): takes two starting values, \
        and a value that is derived from its result by other variables in the model. It returns \
        a new value on each time step, attempting by linear extrapolation from the last two \
        values to return a value for which Poly will be zero."

set msgs(colin) "colin(ArrList): Takes as its one argument an array/list of n scalar elements and \
        returns a random integer between 1 and n with probability proportional to the corresponding \
        elements in the input array/list, calculating a new value each local time step."
        set msgs(newton_raphson) "newton_raphson(Lo_start, Hi_start, Poly) takes two starting values, \
                and a value that is derived from its result by other variables in the model. It returns \
                a new value on each time step, attempting by linear extrapolation from the last two \
                values to return a value for which Poly will be zero."
set msgs(true) "true(): returns the Boolean value for true"
set msgs(false)  "false(): returns the Boolean value for false"
set msgs(pi) "pi(): returns Pi "
set msgs(howmanytrue) "howmanytrue(BoolList): returns the number of elements in a list of Boolean \
        values, BoolList, that have the value true."
set msgs(sgn) "sgn(real): returns the sign of a number, -1 if negative or 1 if positive (or zero)"
