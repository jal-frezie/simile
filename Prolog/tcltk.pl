%%% tcl_eval(+Cmd, -Result) evaluates the Tcl command represented by Cmd
%%% (roughly as SICStus, but smarter handling of chars/1).

sicstus_use_module(library(charsio)).

tcl_eval(Cmd, Result) :-
        decode_command(Cmd, BrokenString, []),
	remove_crs(BrokenString, String),
	append("send_tcl_cmd ", String, PlString),
	name(TkCmd, PlString),
	write(TkCmd), nl,
	flush_output,
	read_codes(JoinedResult),
/*	write('debug '), write(JoinedResult), nl, */
	restore_crs(Result, JoinedResult).

read_codes(Result) :-
	get0(C),
	(C = 10, !,
	    Result = [];
        read_codes(More),
	    Result = [C | More]).

remove_crs([], []).

remove_crs([Cr | R1], New) :-
	([Cr] = "\n", !,
	    New = [Esc, N | R2],
	    [Esc, N] = "\\n";
	New = [Cr | R2]),
	remove_crs(R1, R2).

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

*/
        
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
        decode_command(C, L0, [32|L1]),
        decode_command(Cs, L1, L).
decode_command(WTorA, L0, L) :-
	(WTorA = write(Term); atomic(WTorA), Term = WTorA), !, 
        sicstus_write_to_chars(Term, Chars),
        append(Chars, L, L0).
decode_command(_X, L0, L) :-
        L = L0.

tk_main_loop :-
/* main loop: execute commands from Tcl to the default stream */
        repeat,
	write(get_tcl_cmd), nl,
	flush_output,
	read_codes(JoinedCmdStr),
	restore_crs(CmdStr, JoinedCmdStr),
	append(CmdStr, ".", TermStr),
	do_cmd(TermStr),
	fail.

do_cmd(TermStr) :-
	on_exception(PlError,
	(sicstus_read_from_chars(TermStr, Cmd),
	call(Cmd), !),
	(write(PlError), nl)).
