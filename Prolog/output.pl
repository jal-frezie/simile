/*
screen_output.pl
- - - - - - - - -
This implements the routines that actually draw stuff on the
screen. It calls the actual writing functions which are written in
Tk. To stop the screen getting cluttered when the program draws
something multiple times, every draw is preceded by a test to see if
the object being drawn is in some way shape or form already on the
screen; if it is, the draw is cancelled. Changes to an object are not
normally possible so the Tk change features are not used; objects are
changed only by deleting and redrawing them.  */

sicstus_module(output, [safe_tcl_eval/2, tk_cursor_is/1, tk_callback/1,
			tk_append_callback/1,
	tk_make_desktop/2, get_file_name/5, list_matching_files/2,
	enable_text_editing_in/1, disable_text_editing_in/1, select_text/2,
	compartment/7, channel/7, function/7, variable/7, event/7, cloud/7, 
	submodel/13, bowtie/6, flow/5, influence/5, broken_influence/5,
			ghost_link/5, relation/5, text/7,
	shift_text/3, shift_obj/3, mark_obj/2, unmark_objs/1,
			zap_route/3, zap_bowtie/3,
	tk_add_window/9, change_title_to/3, current_edit/2, force_edit/2,
	get_component_from_gui/4, tk_get_group_from_gui/3,
	get_text/3, change_text_to/3, 
	inject_graphics/2, translate_canvas_pl_names/2, save_canvas/4,
	tk_grow_canvas/2, tk_refatten/2, zoom_bits_in/5,
			tk_display_area/1, tk_update_ability/5,  update_tk/0,
	tk_display_mode/1, tk_display_menu/1,
	tk_change_color/5, kill_featured/2, shift_images/3,
	clear_display/1, set_interpreter/1, unset_interpreter/0,
	prepare_equation/1, create_equation/5,
	fill_equation/8, fill_inputs/1, fill_table/3,
	interact_equation/1, destroy_equation/0,
	tk_start_progress_dialogue/1, tk_update_infobox/2, 
	tk_finish_progress_dialogue/0, tk_alter_model/1,
	tk_scrub_run/2, tk_kill_helpers/1,
	update_tk_variable/3, tk_clear_graph/1, handle_tk_events/0, 
	set_interp_menu_state/1,
	tk_update_sim_display/3, my_file_exists/1, my_delete_file/1,
	tk_do_disag_dialog/4, tk_do_relation_dialog/8, get_tcl_shpiel/1,
	tk_get_pref/2, load_tcl_program/2,
	check_directory/1, windowize/2,
	compile_c_program/4, check_exec_fns_fresh/5, load_executable/6,
	find_phase/4, tk_kill_window/1, tk_certain_death/1, exit_AME/0]).

sicstus_use_module([library(lists), sp_only, state, text, utility]).

safe_tcl_eval(Cmd, Result) :-
	user'><'any_tcl_eval(Cmd, 0, Result).
/********safe_tcl_eval(Cmd, Result) :-
	user'><'tcl_eval(['FilterErrors' | Cmd], Result),
	(Result = "-1",
	    raise_exception("Tcl callback produced an exception");
	true).
	(\+ input'><'log_interaction, !;
	    backup'><'into_save_file(safe_tcl_eval(Cmd, Result))). */

tk_cursor_is(Cursor) :-
	safe_tcl_eval(['AttackGlobalVariable window_info (defCurs)', Cursor],
		      _),
	safe_tcl_eval(['UpdateCursors', Cursor], _).

tk_callback(Data) :-
	safe_tcl_eval(['AttackGlobalVariable fromProlog {}', Data], _).

tk_append_callback(Data) :-
	safe_tcl_eval([lappend, '::fromProlog', Data], _).

new_chop_list(Left, Done, Depth, Args) :-
	Left = [Here | More], !,
	    (Here = 92, /* backslash: next char escaped */
	        More = [Escd | YetMore], !,
		append(Done, [Here, Escd], NewDone),
		new_chop_list(YetMore, NewDone, Depth, Args);
	    Here = 32,
	    Depth = 0, !,
		new_chop_list(More, [], 0, MoreArgs),
		(Done = [], !,
		    Args = MoreArgs;
		    (	append([123 | NewArg], [125], Done), !;
		    NewArg = Done),
		Args = [NewArg | MoreArgs]);
	    (Here = 123, !,
		NewDepth is Depth+1;
	    Here = 125, !,
		NewDepth is Depth-1;
	    NewDepth = Depth),
		append(Done, [Here], NewDone),
		new_chop_list(More, NewDone, NewDepth, Args));
	\+ Done = [], !,
	    sicstus_format_to_chars("Incomplete argument ~s at end of line", [Done],
			    ErrorStr),
	    name(Error, ErrorStr),
	    raise_exception(Error);   
	Args = [].

full_chop_list([], 0, [], []).
full_chop_list([92, C | More], N, [92, C | CurArg], MoreArgs) :-
	full_chop_list(More, N, CurArg, MoreArgs).
full_chop_list([Here | More], NewDepth, NewDone, Args) :-
	full_chop_list(More, Depth, Done, MoreArgs),
	(Here = 32, Depth = 0, !,
	    NewDepth = 0,
	    NewDone = [],
	    (Done = [], !,
		Args = MoreArgs;
	    (append([123 | NewArg], [125], Done), !;
		    NewArg = Done),
		Args = [NewArg | MoreArgs]);
	 (Here = 123, !,
		NewDepth is Depth+1;
	    Here = 125, !,
		NewDepth is Depth-1;
	    NewDepth = Depth),
	    NewDone = [Here | Done],
	    Args = MoreArgs).
	 
pl_chop_list(String, Args) :-
	full_chop_list([32 | String], 0, [], Args).

chop_list(String, Args) :-
	safe_tcl_eval(['AttackGlobalVariable choppingForProlog {}',
		       br(chars(String))], _),
	safe_tcl_eval([llength, '$::choppingForProlog'], LStr),
	name(L, LStr),
	get_elts_from_tcl(0, L, Args), !.

get_elts_from_tcl(P, L, Args) :-
	L = P,
	    Args = [];
	safe_tcl_eval([lindex, '$::choppingForProlog', P], Top),
	    Q is P+1,
	    get_elts_from_tcl(Q, L, Rest),
	    Args = [Top | Rest].

/* curly(P, Text) :-
	append([123 | Text], [125], P),
	curly_text(Text).

curly_text([]).

curly_text([H | T]) :-
	\+ H = 123, \+ H = 125,
	curly_text(T).

curly_text(T) :-
	append(P, Q, T),
	curly(P, _),
	curly_text(Q).

chop_list([], []).

/* argument enclosed in curlybrackets 
chop_list([123 | TclText], [Arg | Prolog_rest]) :-
	append(Curly, TclRest, [123 | TclText]),
	curly(Curly, Arg), !,

	chop_list(TclRest, Prolog_rest).

/* throw away inter-arg space 
chop_list([32 | P], Q) :-
	!, chop_list(P, Q).

/* arg terminated by space or end of string 
chop_list(Tcl_string, [Arg | Rest]) :-
	append(Arg, [32 | Tcl_rest], Tcl_string), !,
		chop_list(Tcl_rest, Rest);
	\+ Tcl_string = [],
		Arg = Tcl_string,
		Rest = [].
*/

bracketize([H | T], br([BrH | BrT])) :-
	!, bracketize(H, BrH), sub_bracketize(T, BrT).

bracketize([], br([])) :- !.

bracketize(Construct, br(write(Construct))).

sub_bracketize([], []).

sub_bracketize([H | T], [SuH | SuT]) :-
	bracketize(H, SuH),
	sub_bracketize(T, SuT).

tk_make_desktop(Node, Canvas) :-
	safe_tcl_eval('MakeDesktopNode', NodeAndCanvas),
	chop_list(NodeAndCanvas, ArgStrs),
	all(user, name, [build([Node, Canvas]), build(ArgStrs)]).

get_file_name(Preferred, Action, CanBeNew, Model, FileName) :-
	safe_tcl_eval(['ChooseFile',
			  br(write(Preferred)), br(write(Action)),
			  CanBeNew, Model], RetVal),
	name(FileName, RetVal).

list_matching_files(Template, Matches) :-
	safe_tcl_eval([glob, '-nocomplain', br(write(Template))], GotStr),
	chop_list(GotStr, MatchStrs),
	all(user, name, [build(Matches), build(MatchStrs)]).

enable_text_editing_in(Wid) :-
	safe_tcl_eval(
		['EnableEdits', Wid], _).

disable_text_editing_in(Wid) :-
	safe_tcl_eval(['DisableEdits', Wid], _).

select_text(Wid, Node) :-
	safe_tcl_eval(['SelectText', Wid, Node], _).

compartment(Wid, [L, T, R, B], Num, Fatness, Density, Colour_scheme, Features) :-
	safe_tcl_eval(['PutRectangle', Wid, L, T, R, B, Num, Fatness, Density, 
			Colour_scheme, br(Features)], _).

channel(Wid, [L, T, R, B], _, Fatness, Decor, Colour_scheme, Features) :-
	safe_tcl_eval(['PutShape', Wid, L, T, R, B, Decor, Fatness, 
			Colour_scheme, br(Features)], _).

function(Wid, [L, T, R, B], Num, Fatness, Density, Colour_scheme, Features) :-
	safe_tcl_eval(['PutHexagon', Wid, L, T, R, B, Num, Fatness, Density, 
			Colour_scheme, br(Features)], _).

variable(Wid, [L, T, R, B], Num, Fatness, Density, Colour_scheme, Features) :-
	safe_tcl_eval(['PutCrossedCirc', Wid, L, T, R, B, Num,
		       Fatness, Density, Colour_scheme, br(Features)], _).

event(Wid, [L, T, R, B], Num, Fatness, Density, Colour_scheme, Features) :-
	FullNum is Num+100,
	safe_tcl_eval(['PutCrossedCirc', Wid, L, T, R, B, FullNum,
		       Fatness, Density, Colour_scheme, br(Features)], _).

cloud(Wid, [L, T, R, B], Num, Fatness, Density, Colour_scheme, Features) :-
	safe_tcl_eval(['PutCloud', Wid, L, T, R, B, Num, Fatness, Density, 
			Colour_scheme, br(Features)], _).

submodel(Wid, [L, T, R, B], Stack, Fatness, FillColour, FillImage, Posn,
	 OrigX, OrigY, BgColour, InFat, Colour_scheme, Features) :-
	safe_tcl_eval(['PutRoundedRect', Wid, L, T, R, B, Stack, Fatness,
		       FillColour, FillImage, Posn, OrigX, OrigY, BgColour,
		       InFat, Colour_scheme, br(Features)], _).

bowtie(Wid, [L, T, R, B], Fatness, Density, Colour_scheme, Features) :-
	safe_tcl_eval(['PutBowTie', Wid, L, T, R, B, Fatness, Density,
		 Colour_scheme, br(Features)], _).

flow(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutFatArrow', Wid, br(Singleton_list),
		      Fatness, Colour_scheme, br(Features)], _).

influence(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutThinArrow', Wid, br(Singleton_list),
		       Fatness, {}, Colour_scheme, br(Features)], _).

broken_influence(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutThinArrow', Wid, br(Singleton_list),
		       Fatness, dashed, Colour_scheme, br(Features)], _).

ghost_link(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutThinArrow', Wid, br(Singleton_list),
		       Fatness, gray50, Colour_scheme, br(Features)], _).

relation(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutRelation', Wid, br(Singleton_list),
		       Fatness, Colour_scheme, br(Features)], _).

text(Wid, Coords, Type, Features, Fatness, Colour_scheme, Content) :-
	name(Content, ContentStr),
	argify(ContentStr, ContentArg),
	safe_tcl_eval(['PutText', Wid, br(Coords), br(Type), br(Features),
		       Fatness, Colour_scheme, chars(ContentArg)], _).

shift_text(Wid, Obj, Vector) :-
	safe_tcl_eval(['MoveText', Wid, Obj, br(Vector)], _).

shift_obj(Wid, Obj, Vector) :-
	safe_tcl_eval(['MoveObj', Wid, Obj, br(Vector)], _).

mark_obj(Wid, Obj) :-
	safe_tcl_eval([Wid, addtag, '/moving/', withtag, Obj], _).

unmark_objs(Wid) :-
	safe_tcl_eval([Wid, dtag, '/moving/'], _).

zap_route(Wid, Obj, Coords) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['MoveLine', Wid, Obj, br(Singleton_list)], _).
		
zap_bowtie(Wid, Obj, Coords) :-
	safe_tcl_eval(['MoveBowtie', Wid, Obj, br(Coords)], _).
		
tk_add_window(Wid, TopNode, Title, [L, T, R, B], Cname, BG, Scale, InitDepths,
	      IsTL) :-
	bracketize(BG, BGList),
	safe_tcl_eval(['MainWindowDraw', TopNode, Wid, br(write(Title)), 
			L, T, R, B, BGList, Scale, IsTL | InitDepths],
		      CanvasString),
	name(Cname, CanvasString).

change_title_to(Wid, New_title, NewBG) :-
	bracketize(NewBG, NewBGList),
	safe_tcl_eval(['ChangeParentTitle', Wid, br(write(New_title)),
		       NewBGList], _).

current_edit(Wid, Comp) :-
	safe_tcl_eval(['GetEdit', Wid], CompStr),
	\+ CompStr = [48],
	name(Comp, CompStr).
 
force_edit(Wid, Comp) :-
	safe_tcl_eval(['GoEdit', Wid, Comp], _).
 
/* get_component_from_gui/4: This invokes a Tcl command which looks
under the point referred to to see what component is there. It is
merely a shortcut as the information should all be kept in Prolog;
unfortunately Tk is idiosyncratic about where it draws e.g., splines,
so Prolog cannot find them. Note that this routine cannot replace
Prolog finds, as some components e.g., rounded rectangles, include
space that is empty in Tk. */

get_component_from_gui(Wid, Xpt, Ypt, Comp) :-
	safe_tcl_eval(['FindObj', Wid, Xpt, Ypt], ObjString),
	\+ ObjString = [], /* fail if nothing at target */
	name(Comp, ObjString).

/* same as above but lists all those overlapping an area */

tk_get_group_from_gui(Wid, [L, T, R, B], CompList) :-
	safe_tcl_eval(['FindAllObjs', Wid, L, T, R, B], Str),
	chop_list(Str, CompList).

/* get_text retrieves the current value of the bit of text that goes
with the component in the specified window. The 'itemcget' command is
not documented in Welch; I inferred its existence by reading between
the lines. */

get_text(Wid, Comp, Text) :-
	safe_tcl_eval(['GetText', Wid, Comp], TextString),
	sicstus_atom_chars(Text, TextString).

tk_grow_canvas(Wid, [L, T, R, B]) :-
	safe_tcl_eval(['ChangeRegion', Wid, L, T, R, B], _).

tk_refatten(Wid, F) :-
	safe_tcl_eval(['ChangeScale', Wid, F], _).

zoom_bits_in(Win, Model, Scale, [X, Y], Comps) :-
	safe_tcl_eval(['ZoomBitsIn', Win, Model, Scale, X, Y | Comps], _).

tk_display_area(Wid) :-
	safe_tcl_eval(['DisplayArea', Wid], _).

inject_graphics(Wid, File) :-
	safe_tcl_eval(['InjectGraphics', Wid, br(write(File))], _).

translate_canvas_pl_names(_Wid, []).

translate_canvas_pl_names(Wid, [Before-After | TList]) :-
	select(After-Later, TList, ToDo), !,
	    translate_canvas_pl_names(Wid, [After-Later, Before-After | ToDo]);
	(Before = After, !;
	        safe_tcl_eval(['TransCnvNames', Wid, Before, After], _)),
	    translate_canvas_pl_names(Wid, TList).
		       
date_is(Date) :-
	/* gmt is specified because some systems have bug-inducing 8-bit
	characters in their local time zone names !! */
	safe_tcl_eval(['clock format [clock seconds] -gmt true'], DateStr),
	name(Date, DateStr).

save_canvas(Wid, File, Depths, Date) :-
	safe_tcl_eval(['WriteDesc', Wid, br(write(File)), br(write(Date))
			 | Depths], _).

change_text_to(Wid, Comp, NewTitle) :-
	name(NewTitle, NewTitleStr),
	argify(NewTitleStr, NewTitleArg),
	safe_tcl_eval(['ChangeObjectTitle', Wid, Comp, chars(NewTitleArg)], _).

tk_update_ability(Wid, Un, Men, Itm, Re) :-
	safe_tcl_eval(['UpdateAbility', Wid, Un, Men, Itm, Re], _).

update_tk :-
	safe_tcl_eval([update, idletasks], _).

tk_display_mode(New_mode) :-
	safe_tcl_eval(['AttackGlobalVariable modes {}', New_mode], _).

tk_display_menu(New_shape) :-
	safe_tcl_eval(['AttackGlobalVariable adds {}', New_shape], _).

tk_change_color(Wid, Obj, Type, Density, Value) :-
	safe_tcl_eval(['ColorSymbol', Wid, Obj, Type, Density, Value], _).

shift_images(TopDir, Fillers, Way) :-
	windowize(TopDir, WTopDir),
	safe_tcl_eval(['ShiftImages', br(WTopDir), Way | Fillers], _).

kill_featured(Wid, Victim_id) :-
	safe_tcl_eval([Wid, delete, Victim_id], _).

clear_display(Wid) :-
	safe_tcl_eval(['ClearWindow', Wid], _).

/* unscramble_coords/2: Translates between a list of coordinates in my
format (Pairs, end of line at beginning of list) into tcl format
(Single items, beginning of line at beginning of list). */

unscramble_coords([], Tcl_style, Tcl_style).

unscramble_coords([[X, Y] | Prolog_style], Prev_tcl_style, Tcl_style) :-
	unscramble_coords(Prolog_style, [X, Y | Prev_tcl_style], Tcl_style).

prepare_equation(Ops) :-
	bracketize(Ops, BrOps),
	safe_tcl_eval(['AttackGlobalVariable equation (fnDefs)', BrOps], _).

create_equation(Win, Use, Caption, Indices, ETs) :-
	safe_list(Caption, CaptArg),
	safe_list(Indices, BrIndices),
	safe_list(ETs, EnumLists),
	safe_tcl_eval(['create_equation', Win, br(write(Use)), CaptArg,
			BrIndices, EnumLists], _).
/*
fill_equation(Cur_eqn, Cur_units, MultList, IsParam, List, TableData,
	      Desc, Comment, Min, Max) :-
	get_from_list(List, Table),
	bracketize(Table, Tk_table),
	bracketize(TableData, Tk_tableData),
	safe_tcl_eval(['fill_equation',
			  br(write(Cur_eqn)), br(write(Cur_units)), br(Mult), 
			  br(write(IsParam)), Tk_table, Tk_tableData,
			  br(write(Desc)), br(write(Comment)),
			  br(write(Min)), br(write(Max))], _).
*/
fill_equation(BadCurEqn, CurUnits, MultList, IsParam, BadDesc, BadCmt,
	      Min, Max) :-
	safe_list([BadCurEqn, CurUnits, BadDesc, MultList, BadCmt],
		  br([E, U, D, M, C])),
	safe_tcl_eval(['fill_equation', E, U, M,
		       br(write(IsParam)), D, C,
		       br(write(Min)), br(write(Max))], _).

fill_inputs(List) :-
	get_from_list(List, Table),
	safe_tcl_eval(['fill_inputs', br(Table)], _).

fill_table(Part, TableData, TableVals) :-
	bracketize(TableData, Tk_tableData),
	safe_tcl_eval(['fill_table', Part, Tk_tableData, TableVals], _).

/* Do a bit of processing to the parameter name column so the square/curly
brackets appear as text. */

get_from_list([input_link(_, RTs, P, _, I) | R1],
	      [br([AV, br(write(FP)), br(write(U)), br(write(FD))])
	      | R2]) :-
	RTs =.. [role_texts | Items],
	safe_list(Items, AV),
	sicstus_write_to_chars(P, SP),
	name(FP, SP),
	m_update'><'analyze_array(I, U, D),
	(D = [], !, FD = '';
	    render'><'comma_separate(D, SD),
	    name(FD, SD)),
	get_from_list(R1, R2).

get_from_list([], []).

interact_equation(Result_list) :-
	safe_tcl_eval(['interact_equation'], Return_string),
	chop_list(Return_string, Result_list).

destroy_equation :-
	safe_tcl_eval(['destroy_equation'], _).

/* Next procedures provide commentary on what is going on. Because I
sometimes call commands that run a long time from the console, I have
this write to the console if in this mode, i.e., there is no Tcl/Tk
interpreter running. */

tk_start_progress_dialogue(Win) :-
	safe_tcl_eval(['OpenProgressBox', Win], _).

tk_update_infobox(Key, Lits) :-
	safe_list(Lits, LitList),
	safe_tcl_eval(['FillProgressBox', Key, LitList], _).

tk_finish_progress_dialogue :-
	safe_tcl_eval(['CloseProgressBox'], _).

/* general purpose utility */

update_tk_variable(Nodename, Val, Time) :-
	safe_tcl_eval(['UpdateDisplay', Nodename, Val, Time], _).

tk_alter_model(TopNode) :-
	safe_tcl_eval(['AlterModel', TopNode], _).

tk_scrub_run(Node, Times) :-
	safe_tcl_eval(['ScrubRun', Node, Times], _).
	
tk_kill_helpers(Node) :-
	safe_tcl_eval(['DestroyHelpers', Node], _).
	
tk_clear_graph(Win) :-
	safe_tcl_eval(['ClearGraph', Win], _).

handle_tk_events :- repeat, \+ tk_do_one_event, !.

tk_update_sim_display(Win, Current, Left) :-
	safe_tcl_eval(['UpdateTimes', Win, Current, Left], _).
	
tk_do_disag_dialog(Win, Caption,
		   [Colour, Image, ImgPos, Type, Fatness, CountList, Step,
		    Desc, Comment, EnumSpecs, Proc, Inc, LibList | Choices],
		   ResultList) :-
	name(Caption, CaptStr),
	argify(CaptStr, CaptArg),
	safe_list(CountList, Count),
%	all(utility, wrap, [build(LibList), unify(write), build(Libs)]),
	bracketize(LibList, Libs),
% Q&D fix for bad enum type chars
	safe_list(EnumSpecs, EnumLists),
	safe_tcl_eval(['Disaggregate', Win, chars(CaptArg), Colour, Image,
		       ImgPos, Type, Fatness, Count, Step, br(write(Desc)),
		       br(write(Comment)), EnumLists,
		       br(write(Proc)), br(write(Inc)), Libs | Choices],
		      New_P_string),
	chop_list(New_P_string, ResultListN),
	(append(ResultList0, [LibFileStList, EnumTypeList], ResultListN), !,
	    chop_list(LibFileStList, LibFileList),
	    chop_list(EnumTypeList, EnumTypeSpecLists),
	    all(output, chop_list,
		[build(EnumTypeSpecLists), build(EnumTypes)]),
	    append(ResultList0, [LibFileList, EnumTypes], ResultList);
	ResultList = []).

safe_list(Bad, Good) :-
	(Bad = []; Bad = [_|_]), !,
	    all(output, safe_list, [build(Bad), build(IndGoods)]),
	    Good = br(IndGoods);
	  sicstus_write_to_chars(Bad, BadChars),
	    argify(BadChars, GoodChars),
	    Good = chars(GoodChars).

tk_do_relation_dialog(Win, Caption, Type, State, OldComment,
		      OKd, NewState, NewComment) :-
	bracketize(State, StateList),
	safe_tcl_eval(['RelationCheck', Win, br(write(Caption)),
			  Type, StateList, br(write(OldComment))],
		 New_P_string),
	chop_list(New_P_string, [OKd, NewComment | NewState]).

tk_get_pref(ResourceName, ResourceValue) :-
	safe_tcl_eval(['PrefValue', write(custom(ResourceName)),
			  ResourceName], ResValStr),
	name(ResourceValue, ResValStr).

/* replace chars not allowed in Windows filenames with spaces */
windowize(Name, WName) :-
	name(Name, NameStr),
	all(output, replace_bad_char, [build(NameStr), build(WNameStr)]),
	stuff_blank_levels(WNameStr, WName).

stuff_blank_levels(String, Name) :-
	[Break, Spc, Exc] = "/ _",
	append(Head, [Break | Body], String),
	append(Level, Tail, Body),
	(Tail = []; Tail = [Break | _]),
	\+ Level = [], /* double forward slash precedes a network drive spec */
	\+ (member(Prints, Level), \+ Prints = Spc), !,
	append(Head, [Break, Exc | Tail], NewString),
	stuff_blank_levels(NewString, Name);
	name(Name, String).

replace_bad_char(Bad, Good) :-
	member(Bad, "\\*?\"<>|\n"), !, [Good] = " ";
	Good = Bad.

my_file_exists(TestFile) :-
	windowize(TestFile, WTestFile),
	safe_tcl_eval([file, exists, br(WTestFile)], "1").

my_delete_file(DelFile) :-
	windowize(DelFile, WDelFile),
	safe_tcl_eval([file, delete, '-force', br(WDelFile)], _).

save_file(Node, From, To, NoPkg, Oops) :-
	windowize(From, WFrom),
	windowize(To, WTo),
	safe_tcl_eval(['SaveFile', Node, br(WFrom), br(WTo), NoPkg], Oops).

load_file(Node, From, To, Oops) :-
	windowize(From, WFrom),
	windowize(To, WTo),
	safe_tcl_eval(['LoadFile', Node, br(WFrom), br(WTo)], Oops).

run_if_package :-
        safe_tcl_eval(['RunIfPackage'], _).

check_directory(Dir) :-
	windowize(Dir, WDir),
	safe_tcl_eval([file, mkdir, br(WDir)], _).

attach_tree(Load, Top, Point) :-
	windowize(Point, WPoint),
	safe_tcl_eval(['AttachTree', br(Load), br(Top), br(WPoint)], _).

trim_tree(Top, Point) :-
	windowize(Point, WPoint),
	safe_tcl_eval(['TrimTree', br(Top), br(WPoint)], _).

shift_dll(Point, Top, Loc, Repl) :-
	windowize(Point, WPoint),
	windowize(Loc, WLoc),
	safe_tcl_eval(['ShiftDll', br(WPoint), br(Top), br(WLoc), br(Repl)],_).

/* Only works for an all-in-one model for now...
prepare_execution(Node, Lang) :-
	safe_tcl_eval(['LoadProgram', Node, Lang], _).

build_interconnects(TopNode, FinderList) :-
	bracketize(FinderList, FinderTclList),
	safe_tcl_eval([do_for_node, TopNode, set_connection_database,
		       FinderTclList], _).
*/
compile_c_program(ModelPath, ExtLibs, Fuss, Err) :-
	windowize(ModelPath, WModelPath),
	all(output, windowize, [build(ExtLibs), build(WExtLibs)]),
	bracketize(WExtLibs, WExtList),
	safe_tcl_eval([compile_c, br(WModelPath), WExtList, Fuss], ErrStr),
	name(Err, ErrStr).

check_exec_fns_fresh(L, WModelPath, Id, Fns, Stat) :-
	bracketize(Fns, BrFns),
	safe_tcl_eval(['CheckFnsFresh',  L, br(WModelPath), Id, BrFns], RVal),
	chop_list(RVal, Stat).

load_executable(L, ModelPath, Id, Node, TopNode, Incs) :-
	windowize(ModelPath, WModelPath),
	bracketize(Incs, BrIncs),
	safe_tcl_eval([load_dll, TopNode, L, br(WModelPath), Id, Node, BrIncs],
		      MStr),
	\+ MStr = "0".
					
load_tcl_program(List, Response) :-
	separate_with_crs(List, DigestibleList),
	safe_tcl_eval(DigestibleList, Response).

find_phase(Node, SourceId, SubmodelId, Phase) :-
	safe_tcl_eval([do_for_node, Node, 'FindPhase', SourceId, SubmodelId],
		      PhaseStr),
	name(Phase, PhaseStr).
	
separate_with_crs([], []).

separate_with_crs([L | Lrest], [L, chars("\n") | Drest]) :-
	separate_with_crs(Lrest, Drest).

get_tcl_shpiel(ErrChars) :-
	safe_tcl_eval([set, errorInfo], ErrChars).

tk_certain_death(Win) :-
	safe_tcl_eval(['CertainDeathNode', Win], _).

tk_kill_window(Win) :-
	safe_tcl_eval(['ZapWindow', Win], _).

exit_AME :-
	safe_tcl_eval([exit_simile], _).
