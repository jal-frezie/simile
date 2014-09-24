:- op(850, xfy, [?, :]).

main :-
        argument_value(1, PlFile),
	catch(
	      read_term(SystoModel, [end_of_term(eof)]),
	      Error,
	      (atom_concat(PlFile, '.err', ErrFile),
	       	open(ErrFile, write, StmW),
	        write_term(StmW, Error, [quoted(true)]),
	       close(StmW),
	       fail)),
	systo_to_simile(SystoModel, [nodes : SmNs, arcs : SmAs], _Eqs),
	list_roots(SmNs, AllSmNs, ExtraAs, Roots),
	append(SmAs, ExtraAs, AllSmAs),
	date_time(dt(Y,M,D,H,T,S)),
        nth(M, ['Jan','Feb','Mar','Apr','May','Jun',
		'Jul','Aug','Sep','Oct','Nov','Dec'], Mn),
        format_to_atom(Date, "~a ~d ~d:~d:~d GMT ~d", [Mn, D, H,T,S, Y]),
	open(PlFile, write, StmW),
	write_all(StmW, [source(program='SystoConvertor',version= 10.0,edition=enterprise,date=Date)]), nl(StmW),
	write_all(StmW, [roots(Roots)]), nl(StmW),
	write_all(StmW, [properties([fill_colour-beige,name-miniworld])]),
	nl(StmW),
	write_all(StmW, AllSmNs), nl(StmW),
	write_all(StmW, AllSmAs), nl(StmW),
	close(StmW).

list_roots([], [], [], []).
list_roots([Node | More], Full, Arcs, Roots) :-
	list_roots(More, MoreFull, MoreArcs, MoreRoots),
	Node = node(Id, Type, [], Math, Graph),
	(Type = cloud,
	    NewFull = [Node],
	    NewArcs = [],
	    NewRoots = [Id];
	  member(Type, [compartment, variable]),
	    Id = Impl-Vis,
	    select(name=Name, Math, ImplMath),
	    new_capt(fn, FnName),
	    NewFull = [node(Vis, Type, [], [name=Name], Graph),
		       node(Impl, function, [], [name=FnName | ImplMath], [])],
	    new_capt(i, NewArc),
	    new_simile_id(arc, NewId),
	    NewArcs = [arc(NewId, Impl, Vis, influence,
			   [attached=[], name=NewArc], [])],
	    NewRoots = [Vis, Impl];
	  Type = function,
	    NewFull = [Node],
	    NewArcs = [],
	    NewRoots = []),
	append(NewFull, MoreFull, Full),
	append(NewArcs, MoreArcs, Arcs),
	append(NewRoots, MoreRoots, Roots).

write_all(_, []).
write_all(StmW, [Line | More]) :-
	write_term(StmW, Line, [quoted(true)]),
	write(StmW, '.'), nl(StmW),
	write_all(StmW, More).

systo_to_simile(Systo, Simile, Eqs) :-
	Systo = {meta : {_SyMs}, nodes : {SyNs}, arcs : {SyAs}},
	Simile = [nodes : SmNs, arcs : SmAs],
	nodes_systo_to_simile(SyNs, SmNs, Eqs),
	arcs_systo_to_simile(SyAs, SmAs, SmNs, Eqs).

meta_systo_to_simile(SMs, SMs, _Eqs).
nodes_systo_to_simile(SyNs, SmNs, Eqs) :-
	(SyNs = (SyN, MoreSyNs),
	   SmNs = [SmN | MoreSmNs],
	   nodes_systo_to_simile(MoreSyNs, MoreSmNs, Eqs);
	 SyN = SyNs,
	   SmNs = [SmN]),
	node_systo_to_simile(SyN, SmN, Eqs).

node_systo_to_simile(SyId : {id : SyId, type : SyType, label : Lbl,
			     centrex : CtrX, centrey : CtrY,
			     text_shiftx : TexX, text_shifty : TexY,
			     extras : SyExs},
		     node(SmId, SmType, [], SmProps, RealSmGraph),
		     Eqs) :-
	member(SyType-SmType, [cloud-cloud, stock-compartment,
			       variable-variable, valve-function]),
	make_id_match(SyId, SmId, SyType, node, Eqs),
	(SyType = valve -> DefUnits = 1/day, RealSmGraph = [along=550];
	 DefUnits = 1, RealSmGraph = SmGraph),
	(select_if_there(complete=_T, SmProps, SmProps1), !;
	  SmProps1 = SmProps),
	select(name=Lbl, SmProps1, SmProps2),
	select(centre=[CtrX, CtrY], SmGraph, SmGraph1),

	(SmType = cloud, !,
	    SyExs = {},
	    SmProps2 = [],
	    SmGraph1 = [];
	  (select(caption_offset=[TexX, TexY], SmGraph1, SmGraph2), !;
	        [TexX, TexY] = [0,0],
	      SmGraph2 = SmGraph1),
	    SmGraph2 = [],
	    SyExs = {equation : SySpec, min_value : SyMin, max_value : SyMax,
		     documentation : SyDoc, comments : SyCmt},
	    SySpec = {type : long_text, default_value : '', value : SmSpc},
	    select(value=SmEqn, SmProps2, SmProps3),
	    select(spec=SmSpc, SmProps3, SmProps4),
	    (var(SmEqn) ->
	        read_term_from_atom(SmSpc, SyEqn, 
                                    [variable_names(VPs), end_of_term(eof)]),
	        join(VPs);
	      true),
	    convert_equation(SyEqn, SmEqn),
	    select(units=SmUnits, SmProps4, SmProps5),
	    (nonvar(SmUnits);
	     SmUnits = DefUnits), !,
	 
	    SyMin = {type : short_text, default_value : MinD, value : SmMinA},
	    ((\+ SmMinA = MinD,
	            select(min_val=SmMin, SmProps5, SmProps6);
	          select_if_there(min_val=SmMin, SmProps5, SmProps6),
	            MinD = '0'),
	      write_to_atom(SmMin, SmMinA);
	    SmProps6 = SmProps5, SmMinA = MinD, member(MinD, ['0', _])), !,

	    SyMax = {type : short_text, default_value : MaxD, value : SmMaxA},
	    ((\+ SmMaxA = MaxD,
	            select(max_val=SmMax, SmProps6, SmProps7);
	        select_if_there(max_val=SmMax, SmProps6, SmProps7),
	            MaxD = '5'),
	      write_to_atom(SmMax, SmMaxA);
	    SmProps7 = SmProps6, SmMaxA = MaxD, member(MaxD, ['5', _])), !,

	 
	    SyDoc = {type : long_text, default_value : '', value : SmDoc},
	    (\+ SmDoc = '',
	        select(description=SmDoc, SmProps7, SmProps8);
	      select_if_there(description=SmDoc, SmProps7, SmProps8);
	      SmProps8 = SmProps7, SmDoc = ''), !,
	 
	    SyCmt = {type : long_text, default_value : '', value : SmCmt},
	    (\+ SmCmt = '',
	        select(comment=SmCmt, SmProps8, SmProps9);
	      select_if_there(comment=SmCmt, SmProps8, SmProps9);
	      SmProps9 = SmProps8, SmDoc = ''), !,
	 
	    SmProps9 = []).

join([]).
join([V=V | More]) :-
	join(More).

convert_equation(A, A) :-
	atom(A); number(A).
% actual format translation goes here
convert_equation(Sy, Sm) :-
	Sy = (A?B:C), Sm = choose(A, B, C), !.

convert_equation([Hy | Ty], [Hm | Tm]) :- !,
	convert_equation(Hy, Hm), convert_equation(Ty, Tm).

convert_equation(Sy, Sm) :-
	(var(Sm) -> Sy =.. [H | Ty]; Sm =.. [H | Tm]),
	convert_equation(Ty, Tm),
	(var(Sy) -> Sy =.. [H | Ty]; Sm =.. [H | Tm]).

select_if_there(Entry, List, Rest) :-
	append(Fix, [Float | Tail], List),
	var(Float), !,
	select(Entry, Fix, FixRest),
	append(FixRest, [Float | Tail], Rest).
	
make_id_match(SyId, SmId, SyType, SmType, Eqs) :-
	append(Old, [New | _], Eqs),
	var(New), !,
	(member(SyId-SmId, Old), !;
	 member(SyType-SmType, [cloud-node, stock-node, variable-node,
				valve-node, flow-arc, influence-arc]),
	 (var(SmId), !,
	     Type = SmType,
	     new_simile_id(Type, SmVis),
	     (member(SyType, [stock, variable]),
	         new_simile_id(node, SmImpl),
	         SmId = SmImpl-SmVis;
	       SmId = SmVis);
	   Type = SyType,
	     new_capt(Type, SyId)),
	 New = SyId-SmId).

new_capt(Type, SyId) :-
	(retract(next(Type, N)), !; N=1),
	number_codes(N, Sig),
	atom_codes(Type, Root),
	append(Root, Sig, SyStr),
	name(SyId, SyStr),
	M is N+1,
	asserta(next(Type, M)).

new_simile_id(Type, SmId) :-
	(retract(next(Type, N)), !; N=1),
	number_codes(N, Sig),
	append("0000", Sig, Trailed),
	append(_, Rect, Trailed),
	length(Rect, 5),
	atom_codes(Type, Root),
	append(Root, Rect, SmIdStr),
	name(SmId, SmIdStr),
	M is N+1,
	asserta(next(Type, M)).

arcs_systo_to_simile(SyAs, SmAs, SmNs, Eqs) :-
	(SyAs = (SyA, MoreSyAs),
	   SmAs = [SmA | MoreSmAs],
	   arcs_systo_to_simile(MoreSyAs, MoreSmAs, SmNs, Eqs);
	 SyA = SyAs,
	   SmAs = [SmA]),
	arc_systo_to_simile(SyA, SmA, SmNs, Eqs).

arc_systo_to_simile(SyId : {id : SyId, type : SyType, label : Lbl,
			     start_node_id : SySrc, end_node_id : SyDest, Rest},
		     arc(SmId, SmSrc, SmDest, SmType, SmProps, SmGraph),
		     SmNs, Eqs) :-
	member(SyType-SmType, [flow-flow, influence-influence]),
	make_id_match(SyId, SmId, SyType, arc, Eqs),
	make_id_match(SySrc, SmSrcs, _, node, Eqs),
	(SmSrcs = _-SmSrc, !; SmSrcs = SmSrc),
	make_id_match(SyDest, SmDests, _, node, Eqs),
	(SyType = flow, SmDests = _-SmDest, !;
	 SmDests = SmDest-_, !; SmDest = SmDests),

	(SyType = flow, !,
	    Rest = (node_id : SyTap),
	    select(attached=[SmTap], SmProps, SmProps1),
	    make_id_match(SyTap, SmTap, valve, node, Eqs),
	    select(curve=[550,1000], SmGraph, []),
	    % flow label is always 'consumption_level' so use valve label
	    member(node(SmTap, _,_, TProps, _), SmNs),
	    member(name=TCapt, TProps),
	    select(name=TCapt, SmProps1, []);
	  SyType = influence,
	    Rest = (curvature : SyC, along : SyA),
	    select(complete=true, SmProps, SmProps1),
	    select(role=[use(none,in_hierarchy,SrcCapt,1)], SmProps1, SmProps2),
	    member(node(_-SmSrc, _, _, NProps, _), SmNs),
	    member(name=SrcCapt, NProps),
	    select(name=Lbl, SmProps2, []),
	    select(curve=[SmCX, SmCY], SmGraph, []),
	    (var(SyC) ->		% calculate Systo coords from Simile
	        SyC = 0.3,
	        SyA = 0.5;
	      SmCX is round(100*SyA),
	        SmCY is round(100*SyC))). % 'attached' must come 1st
:- initialization(main).
