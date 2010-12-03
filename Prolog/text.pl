/*******************************************************************************
**** Text Processing - utlities for building the compiled output
*******************************************************************************/

sicstus_module(text, [split_path_chars/4, replace_char/4, alphanumeric_only/3,
		      starter_only/3, continuer_only/3, argify/2,
		      translate_message/2, translate_message/3]).

sicstus_use_module( [library( lists ), utility, sp_only] ).

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

alphanumeric_only( Input, L, Output ) :-
	sicstus_format_to_chars( "~w", [Input], InputChars),
	trim_nonprinters(InputChars, [In1 | InList] ),
	starter_only(In1, L, Out1),
	continuer_only( InList, L, OutList ),
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
	Char > 32.
	
starter_only(H, L, C) :-
	(uppercase(L, H);
	    lowercase(L, H)), !,
	    C = H; /* used to add 32 to make all start with lowercase */
	C is "_".

continuer_only( [], _L, [] ).
continuer_only( [H|T1], L, [H|T2] ) :-
	(uppercase(L, H);
	    lowercase(L, H);
	    "0" =< H, H =< "9"),
	!,
	continuer_only( T1, L, T2 ).
continuer_only( [_|T1], L, [95 | T2] ) :- /* replace with underscore */
	continuer_only( T1, L, T2 ).

uppercase(L, H) :-
	"A" =< H, H =< "Z";
	\+ L = c, (192=< H,H =< 214;216=<H, H=<222).

lowercase(L, H) :-
	"a" =< H, H =< "z";
	\+ L = c, (H = 181; 223 =< H, H =< 246; 248=<H, H=<255).

/* This one is a real sledgehammer -- turn the chars into something
that will form a single argument when put on the Tcl command line, by
using backslashes to escape everything that might stop it. Note that
escaping a line break just turns it into whitespace -- need to replace
it with \n. */

argify(Chars, ArgChars) :-
	Chars = "",
	ArgChars = "{}";
	escape_nasties(Chars, ArgChars).

escape_nasties(Chars, ArgChars) :-
	append(Go, [CB | Stop], Chars),
	(member([CB]-BS, ["\n"-"\\n", "\t"-"\\t"]), % char with own escape seq
	    append(Go, BS, Mid),
	    append(Mid, Rest, ArgChars);
	member(CB, "\"{}[] \\;$"),
		% doublequote, curly bracket, square bracket, backslash or space
		% semicolon added cos it ends command
	   [BS] = "\\",
	   append(Go, [BS, CB | Rest], ArgChars)),
	!,
	escape_nasties(Stop, Rest);
	ArgChars = Chars.
	      
translate_message(Word, Trans) :-
	output'><'safe_tcl_eval(['tr.', br(Word)], Trans).

translate_message(Word, Args, Trans) :-
	translate_message(Word, Template),
	argify(Template, SafeTemplate),
	output'><'safe_list(Args, br(SafeArgs)),
	output'><'safe_tcl_eval([format, chars(SafeTemplate) | SafeArgs],
			     TransStr),
	name(Trans, TransStr).
			      
