/* files.pl
-----------
Reads data from files other than .sml files, notably tables from .csv files.
*/

sicstus_module(files, [get_table_info/5]).

sicstus_use_module([library(charsio), library(lists),
	       ame_gen]).

get_table_info(Path, Indices, DataField, Table, Error) :-
	on_exception(Prang, open(Path, read, Stream),
		     sicstus_format_to_chars("Attempting to open the table file caused a ~w. Has the table been moved or deleted since last time you edited this component?", [Prang], Error)),
	(nonvar(Error), !;
	get_index_column_numbers(Stream, [DataField | Indices],
			 [DataColumn | IndexColumns], Error),
	(nonvar(Error), !;
	fill_table(Stream, 1, IndexColumns, DataColumn, Table, _, Dims, Error)),
	close(Stream)),
	(\+ Error = [];
	zero_undefined_slots(Table, Dims)).

get_index_column_numbers(Stream, Indices, IndexColumns, Error) :-
	read_line_to_string(Stream, FirstLine),
	make_list(FirstLine, Headers),
	(get_indices(Indices, Headers, IndexColumns), !;
	Indices = [Datum | Rest],
	sicstus_format_to_chars("Could not find datum field ~w and index fields ~w in table headers ~w", 
	[Datum, Rest, Headers], Error)).

read_line_to_string(Stream, String) :-
	\+ at_end_of_stream(Stream),
	get0(Stream, Char),
	(   Char = -1, !, fail;
	    Char = 10, !, String = [];
	    read_line_to_string(Stream, Rest), !, String = [Char | Rest];
	    String = [Char]).

make_list(CommaSepString, [First | Rest]) :-
	append(CommaFree, [44 | Commad], CommaSepString), !,
	make_list(CommaFree, [First]),
	make_list(Commad, Rest).

/* If get_term produces an error, just make an atom of the string */
make_list(CommaFreeString, [Term]) :-
	get_term(CommaFreeString, ReadTerm, Error),
	(Error = [], !,
		Term = ReadTerm;
	name(Term, CommaFreeString)).

/* get_indices is used in both directions */
get_indices([], _, []).

get_indices([IndexTitle | R1], Columns, [IndexNumber | R2]) :-
	nth(IndexNumber, Columns, IndexTitle),
	get_indices(R1, Columns, R2).

fill_table(Stream, Line, IndexColumns, DataColumn,
	   Table, Dims, NewDims, Error) :-
	read_line_to_string(Stream, String), !,
	(String = [], !,
	    InterDims = Dims;
	make_list(String, List),
	get_indices([DataValue | IndexValues], List,
		    [DataColumn | IndexColumns]),
	(nth(RoguePosn, [DataValue | IndexValues], Rogue),
	\+ number(Rogue), !,
	    nth(RoguePosn, [DataColumn | IndexColumns], Posn),
	    sicstus_format_to_chars("Element ~d of line ~d which reads ~w is non-numeric", [Posn, Line, List], Error);
	(IndexValues = [], !,
	    UseValues = [Line];
	UseValues = IndexValues),    
	zap_table_and_dims(UseValues, DataValue, Table,
			       Dims, InterDims, Error))),
	(nonvar(Error), !;
	NextLine is Line+1,
	    fill_table(Stream, NextLine, IndexColumns, DataColumn, Table,
		       InterDims, NewDims, Error));
	NewDims = Dims,
	    Error = [].

zap_table_and_dims([], Table, Table, [], [], _).

zap_table_and_dims([IndexValue | R1], DataValue, Table, [Dim | R2],
		   [NewDim | R3], Error) :-
	nth(IndexValue, Table, SubTable), !,
	    ((var(Dim); IndexValue > Dim), !,
		NewDim = IndexValue;
	    NewDim = Dim),
	    zap_table_and_dims(R1, DataValue, SubTable, R2, R3, Error);
	sicstus_format_to_chars("Table data contains index value ~w which is not a positive integer.", [IndexValue], Error).

zero_undefined_slots(Val, []) :-
	ground(Val); Val = 0.

zero_undefined_slots([], [0 | _]) :- !.

zero_undefined_slots([First | Rest], [This | Others]) :-
	zero_undefined_slots(First, Others),
	Next is This - 1,
	zero_undefined_slots(Rest, [Next | Others]).
