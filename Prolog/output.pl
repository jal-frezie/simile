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

sicstus_module(output, [safe_tcl_eval/2, tk_cursor_in/2, tk_callback/1,
	get_file_name/4, enable_text_editing_in/1, disable_text_editing_in/1, 
	compartment/7, channel/7, function/7, variable/7, cloud/7, 
	submodel/7, bowtie/6, 
	flow/5, influence/5, ghost_link/5, relation/5, text/7,
	shift_text/3, shift_obj/3, zap_route/3, zap_bowtie/3,
	tk_add_window/8, tk_delete_window/1, 
	change_title_to/3, current_edit/2, force_edit/2,
	get_component_from_gui/4, 
	get_text/3, change_text_to/3, 
	inject_graphics/2, save_canvas/4,
	tk_grow_canvas/2, tk_display_area/1, tk_update_ability/4,  update_tk/0,
	tk_display_mode/1, tk_display_menu/1,
	tk_change_color/5, kill_featured/2, shift_images/3,
	clear_display/1, set_interpreter/1, unset_interpreter/0,
	prepare_equation/1, create_equation/3,
	fill_equation/8, fill_inputs/1, fill_table/3,
	interact_equation/1, destroy_equation/0,
	tk_start_progress_dialogue/0, tk_update_infobox/1, 
	tk_finish_progress_dialogue/0, tk_alter_model/0,
	tk_scrub_run/1, tk_kill_helpers/0,
	update_tk_variable/3, tk_clear_graph/1, handle_tk_events/0, 
	set_interp_menu_state/1,
	tk_update_sim_display/3, my_file_exists/1, my_delete_file/1,
	tk_do_disag_dialog/4, tk_do_relation_dialog/9, get_tcl_shpiel/1,
	tk_get_pref/2, load_tcl_program/2, build_interconnects/1,
	check_directory/1, windowize/2,
	compile_c_program/2, load_executable/4, find_phase/3,
	kill_window/1, exit_AME/0]).

sicstus_use_module([library(lists), sp_only, state, text, utility]).

safe_tcl_eval(Cmd, Result) :-
	user:tcl_eval(['FilterErrors' | Cmd], Result),
	(\+ input:log_interaction, !;
	    backup:into_save_file(safe_tcl_eval(Cmd, Result))).

tk_cursor_in(Win, Cursor) :-
	safe_tcl_eval([Win, 'config -cursor', Cursor], _).

tk_callback(Data) :-
	safe_tcl_eval(['AttackGlobalVariable fromProlog {}', Data], _).

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

chop_list(String, Args) :-
	append(String, [32], NeatStr),
	new_chop_list(NeatStr, [], 0, Args).

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

get_file_name(Preferred, Action, CanBeNew, FileName) :-
	safe_tcl_eval(['ChooseFile',
			  br(write(Preferred)), br(write(Action)),
			  CanBeNew], RetVal),
	name(FileName, RetVal).

list_matching_files(Template, Matches) :-
	safe_tcl_eval([glob, '-nocomplain', Template], GotStr),
	chop_list(GotStr, MatchStrs),
	all(user, name, [build(Matches), build(MatchStrs)]).

enable_text_editing_in(Wid) :-
	safe_tcl_eval(
		['EnableEdits', Wid], _).

disable_text_editing_in(Wid) :-
	safe_tcl_eval(['DisableEdits', Wid], _).

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

cloud(Wid, [L, T, R, B], Num, Fatness, Density, Colour_scheme, Features) :-
	safe_tcl_eval(['PutCloud', Wid, L, T, R, B, Num, Fatness, Density, 
			Colour_scheme, br(Features)], _).

submodel(Wid, [L, T, R, B], Stack, Fatness,
	 FillColour, Colour_scheme, Features) :-
	safe_tcl_eval(['PutRoundedRect', Wid, L, T, R, B, Stack, Fatness,
		 FillColour, Colour_scheme, br(Features)], _).

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

ghost_link(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutThinArrow', Wid, br(Singleton_list),
		       Fatness, gray50, Colour_scheme, br(Features)], _).

relation(Wid, Coords, Fatness, Colour_scheme, Features) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['PutRelation', Wid, br(Singleton_list),
		       Fatness, Colour_scheme, br(Features)], _).

text(Wid, Coords, Type, Features, Fatness, Colour_scheme, Content) :-
	safe_tcl_eval(['PutText', Wid, br(Coords), br(Type), br(Features),
		       Fatness, Colour_scheme, br(write(Content))], _).

shift_text(Wid, Obj, Vector) :-
	safe_tcl_eval(['MoveText', Wid, Obj, br(Vector)], _).

shift_obj(Wid, Obj, Vector) :-
	safe_tcl_eval(['MoveObj', Wid, Obj, br(Vector)], _).

zap_route(Wid, Obj, Coords) :-
	unscramble_coords(Coords, [], Singleton_list),
	safe_tcl_eval(['MoveLine', Wid, Obj, br(Singleton_list)], _).
		
zap_bowtie(Wid, Obj, Coords) :-
	safe_tcl_eval(['MoveBowtie', Wid, Obj, br(Coords)], _).
		
tk_add_window(Wid, Title, [L, T, R, B], Cname, BG, Scale, InitDepths, IsTL) :-
	safe_tcl_eval(['MainWindowDraw', Wid, br(write(Title)), 
			L, T, R, B, BG, Scale, IsTL | InitDepths],
		      CanvasString),
	name(Cname, CanvasString).

tk_delete_window(Cname) :-
	safe_tcl_eval([destroy, sqb([winfo, parent, Cname])], _).

change_title_to(Wid, New_title, NewBG) :-
	safe_tcl_eval(['ChangeParentTitle', Wid, br(write(New_title)), NewBG], _).

current_edit(Wid, Comp) :-
	safe_tcl_eval(['GetEdit', Wid], CompStr),
	\+ CompStr = [],
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

/* get_text retrieves the current value of the bit of text that goes
with the component in the specified window. The 'itemcget' command is
not documented in Welch; I inferred its existence by reading between
the lines. */

get_text(Wid, Comp, Text) :-
	safe_tcl_eval(['GetText', Wid, Comp], TextString),
	name(Text, TextString).

tk_grow_canvas(Wid, [L, T, R, B]) :-
	safe_tcl_eval(['ChangeRegion', Wid, L, T, R, B], _).

tk_display_area(Wid) :-
	safe_tcl_eval(['DisplayArea', Wid], _).

inject_graphics(Wid, File) :-
	safe_tcl_eval(['InjectGraphics', Wid, br(write(File))], _).

date_is(Date) :-
	safe_tcl_eval(['clock format [clock seconds]'], DateStr),
	name(Date, DateStr).

save_canvas(Wid, File, Depths, Date) :-
	safe_tcl_eval(['WriteDesc', Wid, br(write(File)), br(write(Date))
			 | Depths], _).

change_text_to(Wid, Comp, New_title) :-
	safe_tcl_eval(['ChangeObjectTitle', Wid, Comp, br(write(New_title))], _).

tk_update_ability(Un, Men, Itm, Re) :-
	safe_tcl_eval(['UpdateAbility', Un, Men, Itm, Re], _).

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
	safe_tcl_eval(['ShiftImages', WTopDir, Way | Fillers], _).

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

create_equation(Win, Function, Indices) :-
	bracketize(Indices, BrIndices),
	safe_tcl_eval(['create_equation', Win, br(write(Function)),
			BrIndices], _).
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
fill_equation(Cur_eqn, Cur_units, MultList, IsParam, Desc, Cmt, Min, Max) :-
	all(utility, wrap, [build(MultList), unify(write), build(Mult)]),
	safe_tcl_eval(['fill_equation',
			  br(write(Cur_eqn)), br(write(Cur_units)), br(Mult),
			  br(write(IsParam)), br(write(Desc)), br(write(Cmt)),
			  br(write(Min)), br(write(Max))], _).

fill_inputs(List) :-
	get_from_list(List, Table),
	bracketize(Table, Tk_table),
	safe_tcl_eval(['fill_inputs', Tk_table], _).

fill_table(Node, TableData, TableVals) :-
	bracketize(TableData, Tk_tableData),
	safe_tcl_eval(['fill_table', Node, Tk_tableData, TableVals], _).

/* Do a bit of processing to the parameter name column so the square/curly
brackets appear as text. */

get_from_list([input_link(_, V, P, _, I) | R1], [[V, FP, U, FD] | R2]) :-
	sicstus_write_to_chars(P, SP),
	name(FP, SP),
	m_update:analyze_array(I, U, D),
	(D = [], !, FD = [];
	    render:comma_separate(D, SD),
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

tk_start_progress_dialogue :-
	safe_tcl_eval(['OpenProgressBox'], _).

tk_update_infobox(String) :-
	name(Text, String),
	safe_tcl_eval(['.progress.message configure -text', 
				br(write(Text))], _),
	safe_tcl_eval(['update idletasks'], _).

tk_finish_progress_dialogue :-
	safe_tcl_eval(['CloseProgressBox'], _).

/* general purpose utility */

update_tk_variable(Nodename, Val, Time) :-
	safe_tcl_eval(['UpdateDisplay', Nodename, Val, Time], _).

tk_alter_model :-
	safe_tcl_eval(['AlterModel'], _).

tk_scrub_run(Times) :-
	safe_tcl_eval(['ScrubRun', Times], _).
	
tk_kill_helpers :-
	safe_tcl_eval(['DestroyHelpers'], _).
	
tk_clear_graph(Win) :-
	safe_tcl_eval(['ClearGraph', Win], _).

handle_tk_events :- repeat, \+ tk_do_one_event, !.

tk_update_sim_display(Win, Current, Left) :-
	safe_tcl_eval(['UpdateTimes', Win, Current, Left], _).
	
tk_do_disag_dialog(Win, Caption, [Colour, Type, Fatness, CountList, Step,
			    Comment, EnumSpecs | Choices], ResultList) :-
	all(utility, wrap, [build(CountList), unify(write), build(Count)]),
	bracketize(EnumSpecs, EnumLists),
	safe_tcl_eval(['Disaggregate', Win, br(write(Caption)), Colour, Type,
		       Fatness, br(Count), Step, br(write(Comment)),
		       EnumLists | Choices], New_P_string),
	chop_list(New_P_string, ResultListN),
	(append(ResultList0, [EnumTypeList], ResultListN), !,
	    chop_list(EnumTypeList, EnumTypeSpecLists),
	    all(output, chop_list,
		[build(EnumTypeSpecLists), build(EnumTypes)]),
	    append(ResultList0, [EnumTypes], ResultList);
	ResultList = []).

tk_do_relation_dialog(Win, Caption, IsExcl, IsDelay, OldComment,
		      OKd, IsNowExcl, IsNowDelay, NewComment) :-
	safe_tcl_eval(['RelationCheck', Win, br(write(Caption)),
			  IsExcl, IsDelay, br(write(OldComment))],
		 New_P_string),
	chop_list(New_P_string, [OKd, IsNowExcl, IsNowDelay, NewComment]).

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

save_file(From, To, Oops) :-
	windowize(From, WFrom),
	windowize(To, WTo),
	safe_tcl_eval(['SaveFile', br(WFrom), br(WTo)], Oops).

load_file(From, To, Oops) :-
	windowize(From, WFrom),
	windowize(To, WTo),
	safe_tcl_eval(['LoadFile', br(WFrom), br(WTo)], Oops).

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

/* Only works for an all-in-one model for now...*/
prepare_tcl_execution(Wid) :-
	safe_tcl_eval([build_tcl_program, Wid], _).

prepare_c_execution(Wid) :-
	safe_tcl_eval([update_c_executable, Wid], _).

build_interconnects(FinderList) :-
	bracketize(FinderList, FinderTclList),
	safe_tcl_eval([set_connections, FinderTclList], _).
	
compile_c_program(ModelPath, Err) :-
	windowize(ModelPath, WModelPath),
	safe_tcl_eval([compile_c, br(WModelPath)], ErrStr),
	name(Err, ErrStr).

load_executable(L, ModelPath, Id, Node) :-
	windowize(ModelPath, WModelPath),
	safe_tcl_eval([load_dll, L, br(WModelPath), Id, Node], MStr),
	\+ MStr = "0".
					
load_tcl_program(List, Response) :-
	separate_with_crs(List, DigestibleList),
	safe_tcl_eval(DigestibleList, Response).

find_phase(SourceId, SubmodelId, Phase) :-
	safe_tcl_eval(['FindPhase', SourceId, SubmodelId], PhaseStr),
	name(Phase, PhaseStr).
	
separate_with_crs([], []).

separate_with_crs([L | Lrest], [L, chars("\n") | Drest]) :-
	separate_with_crs(Lrest, Drest).

get_tcl_shpiel(ErrChars) :-
	safe_tcl_eval([set, errorInfo], ErrChars).

kill_window(Win) :-
	safe_tcl_eval(['ZapWindow', Win], _).

exit_AME :-
	safe_tcl_eval([exit_simile], _).
