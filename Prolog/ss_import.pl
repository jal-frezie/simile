sicstus_module(ss_import, [convert_ss/2]).

sicstus_use_module([utility, m_update, library(lists)]).

convert_ss(SSFile, Model) :-
	open(SSFile, read, Eam),
	read(Eam, document(Term)),
	close(Eam),
	locate_table(Term, Table),
	convert_table(Table, Model).

locate_table(element(Name, _,_, Content), Table) :-
	Name = table,
	    Table = Content;
	member(Nested, Content),
	    locate_table(Nested, Table).

convert_table([CElt | RElts], Model) :-
	CElt = element(table-column, Attrs, _,_),
	member(number-columns-repeated=NCols, Attrs),
	make_rows(RElts, 0, Model).

make_rows([], _,_).

make_rows([element(table-row, _,_, Cells) | RElts], N, Model) :-
	M is N+1,
	L = 15,
	T is 60*N+15,
	length(Cells, X),
	R is 60*X,
	B is 60*M,
	event:attempt_addition(submodel, Model, [L,T,R,B], NComp, yes, yes),
	add_parameter(NComp, 0, fill_colour, '#f0fff0'),
	append_atoms('Row', M, RName),
	add_parameter(NComp, 0, name, RName),
	make_rows(RElts, M, Model).
