sicstus_module(ss_import, [convert_ss/2]).

sicstus_use_module([draw, image, utility, m_update, ame_gen, sp_only,
		    library(lists)]).

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
	CElt = element(table-column, _,_,_), !,
	    convert_table(RElts, Model);
	NewExtent = [0,0,1000,1000],
	change_shape(Model, internal_extent, NewExtent),
	make_rows([CElt | RElts], 0, Model, Links),
	/* use setof to avoid making duplicates */
	all(ss_import, link_node, [unify(Model), build(Links)]),
	adjust_toplevel_windows(Model, NewExtent).

make_rows([], _,_, []).

make_rows([element(table-row, Attrs, A3, Cells) | RElts], N, Model,
	  AllLinks) :-
	M is N+1,
	make_cells(Cells, 0, M, Model, Links),
	(select(number-rows-repeated=RStr, Attrs, XAttrs),
	    name(R, RStr),
	    R>1, !,
	    NR is R-1,
	    name(NR, NRStr),
	    ToDo = [element(table-row, [number-rows-repeated=NRStr | XAttrs],
			    A3, Cells) | RElts];
	    ToDo = RElts),
	make_rows(ToDo, M, Model, MoreLinks),
	append(Links, MoreLinks, AllLinks).

make_cells([], _,_,_, []).

make_cells([element(table-cell, Attrs, A3, A4) | RElts], N1, M2, Model,
	   AllLinks) :-
	(select(number-columns-repeated=RStr, Attrs, XAttrs), !,
	    name(R, RStr),
	    (R>2, member(value=_V, XAttrs), !,
		M1 is N1+1,
		NR is R-1,
		name(NR, NRStr),
		ToDo = [element(table-cell, [number-columns-repeated=NRStr
					| XAttrs], A3, A4) | RElts];
	    M1 is N1+R-1,
		ToDo = [element(table-cell, XAttrs, A3, A4) | RElts]);
	XAttrs = Attrs,
	    M1 is N1+1,
	    ToDo = RElts),
	make_cells(ToDo, M1, M2, Model, MoreLinks),
	(member(value=_V, XAttrs), !,
	    X is 45*M1-15,
	    Y is 45*M2-15,
	    event:add_at_point(X, Y, variable, Model, NComp),
	    convert_to_alpha(M1, ColID),
	    append_atoms(ColID, M2, CName),
	    add_parameter(NComp, 0, name, CName),
	    add_equation(NComp, Attrs, Links),
	    AllLinks = [Links | MoreLinks];
	AllLinks = MoreLinks).

convert_to_alpha(N, Id) :-
	(N<27, !,
	    Ltr is 64+N,
	    IdStr = [Ltr];
	 C1 is 64+(N-1)//26,
	    C2 is N-26*(C1-64),
	    IdStr = [C1, C2]),
	name(Id, IdStr).

add_equation(NComp, Attrs, Links) :-
	implicit_function(NComp, Fn),
	(member(formula=[61 | FStr], Attrs), !,
	    get_term(FStr, OrigEqn, Err),
	    (Err = [], !,
		replace_subexps(OrigEqn, ss_import, convert_params, [],
				top_down, Pairs, NewEqn);
	    caption_for(NComp, Name),
		sicstus_format_to_chars("Equation for cell ~a could not be translated: ~s", [Name, Err], Whine),
		do_dialogue("Problem importing spreadsheet equation", warning,
			    Whine, ok, _),
		NewEqn = '',
		Pairs = []);
	member(value=VStr, Attrs),
	    name(NewEqn, VStr),
	    Pairs = []),
	Links = links(NComp, Fn, Pairs),
	member(value-type=OrigUnitStr, Attrs),
	name(OrigUnits, OrigUnitStr),
	(OrigUnits = float, !, Units = 1;
	    Units = OrigUnits),
	add_parameter(Fn, 0, value, NewEqn),
	add_parameter(Fn, 0, units, Units).


convert_params(_, SSForm, SmlForm, 0) :-
	atom(SSForm),
	name(SSForm, OldStr),
	[Dollar, Zero, Nine, A, Z] = "$09AZ",
	append(Letters, Numbers, OldStr),
	(Lets = Letters; [Dollar | Lets] = Letters),
	\+ (member(Let, Lets), (Let < A; Let > Z)),
	(Nums = Numbers; [Dollar | Nums] = Numbers),
	\+ (member(Num, Nums), (Num < Zero; Num > Nine)), !,
	append(Lets, Nums, NewStr),
	name(SmlForm, NewStr).

link_node(Model, links(NComp, Fn, Pairs)) :-
	(setof(Src, OrigSrc^member(var_pair(OrigSrc, Src), Pairs), Srcs), !,
	    all(ss_import, add_link,
		[unify([Model, NComp, Fn]), build(Srcs)]);
	 true),
	redisplay(NComp).

add_link([Model, Dest, Fn], Source) :-
	find_all_comps(Model, SrcVar),
	appears(SrcVar),
	get_av_pair(SrcVar, 0, name, Source), !,
	    event:draw_line_to(SrcVar, influence, Dest),
	    event:tie_ends(influence, SrcVar, Fn),
	    remove_old_incomplete;
	caption_for(Dest, DestCapt),
	    sicstus_format_to_chars("Cell ~a has a reference to cell ~a, which does not have a numeric value", [DestCapt, Source], Whine),

	    do_dialogue("Problem importing spreadsheet equation", warning,
			    Whine, ok, _).
