%%% tcl_eval(+Cmd, -Result) evaluates the Tcl command represented by Cmd
%%% (roughly as SICStus, but smarter handling of chars/1).

sicstus_module(tcltk, [tk_main_loop/0, any_tcl_eval/3, all_ttfn_to_utf8/2]).
sicstus_use_module([library(lists), sp_only]).

any_tcl_eval(Cmd, Except, Result) :-
        decode_command(Cmd, BrokenString),
	remove_crs(BrokenString, TtfnString),
	all_ttfn_to_utf8(TtfnString, String),
	append("send_tcl_cmd ", String, PlString),
	sicstus_write_chars(PlString), nl,
	flush_output,
	wait_for_tcl(Except, Response),
	Result = Response.

read_codes(Result) :-
	on_exception(_, get_code(C), C=33),
	(C = 10, !,
	    Result = [];
        read_codes(More),
	    Result = [C | More]).

remove_crs([], []).

/* Convert line breaks to \u00a, but string might actually include a \u so also
convert \ to \u05c (add last bit later) */

remove_crs([H | T], New) :-
	[Cr, Esc, U, O, A] = "\n\\u0a",
	(H = Cr, !,
	    New = [Esc, U, O, O, O, A | T2];
	New = [H | T2]),
	remove_crs(T, T2).

restore_crs([], []).

restore_crs([Cr | R1], New) :-
	(New = [Esc, N | R2],
	    [Esc, N] = "\\n", !,
	    [Cr] = "\n";
	New = [Cr | R2]),
	restore_crs(R1, R2).




/* Many thanks to this guy for supplying me with an earlier version of
what follows -- Jasper

Anders Andersson           Phone: +46 18 471 32 39        Address: Box 480
Department of Mathematics  Room:  MIC 2:141                        S-751 06
Uppsala University         email: andand@math.uu.se                Uppsala 
SWEDEN                     http://www.math.uu.se/~andand           SWEDEN

decode_command(chars(Codes), L0, L) :- !,
        append(Codes, L, L0).
decode_command(format(Fmt,Args0), L0, L) :- !,
        (  atomic(Args0)
        -> Args = [Args0]
        ;  Args = Args0
        ),
        sicstus_format_to_chars(Fmt, Args, Chars),
        append(Chars, L, L0).
decode_command(br(Cmd), L0, L) :- !,
        L0 = [123|L1],
        decode_command(Cmd, L1, [125|L]).
decode_command(sqb(Cmd), L0, L) :- !,
        L0 = [91|L1],
        decode_command(Cmd, L1, [93|L]).
decode_command(dq(Cmd), L0, L) :- !,
        L0 = [34|L1],
        decode_command(Cmd, L1, [34|L]).
decode_command([], L0, L) :- !,
        L = L0.
decode_command([C], L0, L) :- !,
        decode_command(C, L0, L).
decode_command([C|Cs], L0, L) :- !,
        decode_command(C, L0, [37|L1]),
        decode_command(Cs, L1, L).
decode_command(WTorA, L0, L) :-
	(WTorA = write(Term); atomic(WTorA), Term = WTorA), !, 
        sicstus_write_to_chars(Term, Chars),
        append(Chars, L, L0).
decode_command(_X, L0, L) :-
        L = L0.

*/
decode_command(chars(Codes), Codes) :- !.

decode_command(format(Fmt,Args0), Chars) :- !,
        (  atomic(Args0)
        -> Args = [Args0]
        ;  Args = Args0
        ),
        sicstus_format_to_chars(Fmt, Args, Chars).
decode_command(br(Cmd), Res) :- !,
	decode_command(Cmd, In),
        append([123 | In], [125], Res).
decode_command(sqb(Cmd), Res) :- !,
	decode_command(Cmd, In),
        append([91 | In], [93], Res).
decode_command(dq(Cmd), Res) :- !,
	decode_command(Cmd, In),
        append([34 | In], [34], Res).
decode_command([], []) :- !.
decode_command([C], Res) :- !,
        decode_command(C, Res).
decode_command([C|Cs], Res) :- !,
        decode_command(C, R1),
        decode_command(Cs, Rx),
	append(R1, [32 | Rx], Res).
decode_command(Float, Chars) :-
	utility'><'trim_float(Float, Chars), !.
decode_command(WTorA, Chars) :-
	(WTorA = write(Term);
	    atomic(WTorA), Term = WTorA), !, 
        sicstus_write_to_chars(Term, Chars).
decode_command(WTorA, Chars) :-
	WTorA = writeq(Term), !, 
        sicstus_writeq_to_chars(Term, Chars).
decode_command(_X, []).

tk_main_loop :-
	do_cmd("true."),
/* main loop: execute commands from Tcl to the default stream */
	wait_for_tcl(1, _).

wait_for_tcl(Except, Result) :-
        repeat,
	read_codes(JoinedTclStr),
	all_utf8_to_ttfn(JoinedTclStr, TclStr),
	(append("call:", CmdStr, TclStr),
	    append(CmdStr, ".", TermStr),
	    do_cmd(TermStr),
	    fail;
	append("result:", Joined, TclStr),
	    restore_crs(Result, Joined);
	append("error:", ResultBase, TclStr),
	    name(ResultAtom, ResultBase),
	    (Except = 1, !,
		raise_exception(ResultAtom);
	    Result = -1)), !.
	
	
do_cmd(TermStr) :-
	on_exception(PlError,
	(sicstus_read_from_chars(TermStr, Cmd),
	(call(Cmd),
	    write(exit);
	write(fail))),
	format("~w calling ~s", [PlError, TermStr])), !,
	nl, flush_output.

/* cannot use all because of variable length source */
all_utf8_to_ttfn([], []).

all_utf8_to_ttfn(String, NewString) :-
	append(Code, Rest, String),
	utf8_to_unicode(Code, Char), !,
	unicode_to_ttfn(Char, Start),
	all_utf8_to_ttfn(Rest, More),
	append(Start, More, NewString).

utf8_to_unicode([H | String], Char) :-
	H < 192, !,
	    Char = H,
	    String = [];
	Spares is floor(7-log(256-H)/log(2))//1,
	    length(String, Spares),
	    TopVal is 128+(H /\ (63 >> Spares)),
	    base64([TopVal | String], Char).

base64([], 0).

base64(String, All) :-
	append(Rest, [Last], String),
	Last>=128,
	base64(Rest, Tail),
	All is 64*Tail + (Last-128).

unicode_to_utf8(Char, [Key | String]) :-
	Char < 128, !,
	    Key = Char,
	    String = [];
	Length is floor(log(Char)/log(2)-1)//5,
	    Key is (Char >> (6*Length)) \/ (255 >> (7-Length) << (7-Length)),
	    length(String, Length),
	    fill_chars(String, Char).

fill_chars([], _Char).

fill_chars(St, Char) :-
	append(More, [Hole], St),
	Hole is 128 \/ (Char /\ 63),
	LChar is Char >> 6,
	fill_chars(More, LChar).

/* Now let's see how much easier this is with a properly designed encoding
system... */

/* cannot use all because of variable length source */
all_ttfn_to_utf8([], []).

all_ttfn_to_utf8(String, NewString) :-
	append(Code, Rest, String),
	ttfn_to_unicode(Code, Char), !,
	unicode_to_utf8(Char, Start),
	all_ttfn_to_utf8(Rest, More),
	append(Start, More, NewString).

ttfn_to_unicode([H | String], Val) :-
	[H] = "X", !,
	    convert_ttfn(String, Val);
	String = [], Val = H.

atom_heart("0123456789_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz").

convert_ttfn([C1 | Rest], Val) :-
	atom_heart(AtomMakers),
	nth0(N, AtomMakers, C1),
	(N >= 32, !,
	    Val is N-31,
	    Rest = [];
	 convert_ttfn(Rest, TailVal),
	    Val is N+32*TailVal).

unicode_to_ttfn(Val, Chars) :-
	(Val > 6, Val < 14; Val >= 32, Val < 192, \+ [Val] = "X"), !,
	    Chars = [Val];
	spinout_ttfn(Val, Spun),
	    append("X", Spun, Chars).

spinout_ttfn(Val, [First | Rest]) :-
	(Val < 32, !,
	    Posn is 31+Val,
	    Rest = [];
	 Posn is Val /\ 31,
	    Tail is Val >> 5,
	    spinout_ttfn(Tail, Rest)),
	atom_heart(AtomMakers),
	nth0(Posn, AtomMakers, First).

deEncode(_, TtfnAtom, Utf8Atom, 0) :-
	atom(TtfnAtom),
	name(TtfnAtom, TtfnStr),
	all_ttfn_to_utf8(TtfnStr, Utf8Str),
	name(Utf8Atom, Utf8Str).

reEncode(_, Utf8Atom, TtfnAtom, 0) :-
	atom(Utf8Atom),
	name(Utf8Atom, Utf8Str),
	(all_utf8_to_ttfn(Utf8Str, TtfnStr), !;
	all(user, unicode_to_ttfn, [build(Utf8Str), append(TtfnStr, [])])),
	/* if cannot convert from utf8, was probably Unicode (Hi8) already */
	name(TtfnAtom, TtfnStr).

