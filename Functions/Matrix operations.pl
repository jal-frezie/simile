% multiplying a 3-element vector by a 3x3 matrix
transform3([[ier]],[vect]) -->
	makearray(sum(
            element([[ier]],place_in(1))*[vect]
        ),3).

% multiplication of two 3x3 matrices
product3([[ier]],[[icand]]) -->
	makearray(makearray(sum(
            element([[ier]],place_in(2))*
            makearray(element(element([[icand]],place_in(1)),place_in(2)),3)
        ),3),3).
