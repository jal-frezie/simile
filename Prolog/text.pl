/*******************************************************************************
**** Text Processing - utlities for building the compiled output
*******************************************************************************/

sicstus_module( text, [split_path_chars/4, replace_char/4, alphanumeric_only/2] ).

sicstus_use_module( [library( lists ), utility, library( charsio) ] ).

/* Split_path_chars may have to be customized for OS other than DOS, what it does it
takes a string from the file selector box and turns into a path atom usable by
Prolog, also returning the directory and file components as strings. */

split_path_chars(RetVal, Filename, NewDirString, FileString) :-
	":/" = [Colon, Stroke],
	(append(NewDirString, [Stroke | FileString], RetVal),
		name(Filename, RetVal);
	append([DriveLetter, Colon], FileString, RetVal),
		NewDirString = [DriveLetter, Colon],
		/* Now insert stroke to avoid bug in Prolog */
		name(Filename, [DriveLetter, Colon, Stroke | FileString])),
	\+ member(Stroke, FileString).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% replaces all occurrences of char1 in atom1 with char2 to give atom2

replace_char( Char1, Atom1, Char2, Atom2 ) :-
	name( Atom1, AtomL1 ), name( Char1, [C1] ), name( Char2, [C2] ),
	replace_in_list( C1, AtomL1, C2, AtomL2 ),
	name( Atom2, AtomL2 ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Makes a nice quoteless Prolog atom from a variable name

alphanumeric_only( Input, Output ) :-
	sicstus_format_to_chars( "~w", [Input], InputChars),
	trim_nonprinters(InputChars, [In1 | InList] ),
	starter_only(In1, Out1),
	continuer_only( InList, OutList ),
	name( Output, [Out1 | OutList] ).

/* trim_nonprinters gets rid of non-printing chars from both ends of the string.
CR is non-printing if at either end -- well, isn't that obvious? */

trim_nonprinters(All, Trimmed) :-
	append(Starters, [Prints | Rest], All),
	prints(Prints),
	\+ (member(White, Starters), prints(White)),
	append(Middle, [Prints2 | End], [Prints | Rest]),
	prints(Prints2),
	\+ (member(White, End), prints(White)),
	append(Middle, [Prints2], Trimmed), !;
	/* if the above clause fails, there are no printing characers, so... */
	Trimmed = "anon".

prints(Char) :-
	Char > 32,
	Char < 127.
	
starter_only(H, C) :-
	"a" =< H, H =< "z", !,
		C = H;
	"A" =< H, H =< "Z", !,
		C = H; /* used to add 32 to make all start with lowercase */
	C is "x".

continuer_only( [], [] ).
continuer_only( [H|T1], [H|T2] ) :-
	"a" =< H, H =< "z",
	!,
	continuer_only( T1, T2 ).
continuer_only( [H|T1], [H|T2] ) :-
	"A" =< H, H =< "Z",
	!,
	continuer_only( T1, T2 ).
continuer_only( [H|T1], [H|T2] ) :-
	"0" =< H, H =< "9",
	!,
	continuer_only( T1, T2 ).
continuer_only( [_|T1], [95 | T2] ) :- /* replace with underscore */
	continuer_only( T1, T2 ).
