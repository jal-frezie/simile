# Attempt at a completely compilation-free Prolog/Tcl interface that
# will work with any implementation of either language. This file is
# sourced into the Tcl interpreter where it starts the Prolog
# interpreter in a non-blocking pipe. Commands are then passed between
# the two along the pipe.

wm protocol . WM_DELETE_WINDOW {close $plPipe; destroy .}

proc Reader {} {
    global plPipe running
    if {[eof $plPipe]} {
	catch {close $plPipe}
	destroy .
    }
    if {[gets $plPipe noCrs] >= 0} {
	regsub -all \\\\n $noCrs \n line
#	puts [concat < $line]
	if {[string match get_tcl_cmd $line]} {
	    send_tcl_cmd
	} elseif {[string match send_tcl_cmd [lindex $line 0]]} {
	    eval do_tail $line
	} elseif {[string match debug [lindex $line 0]]} {
	} else {
	    tk_messageBox -title {Unexpected Prolog output} -icon warning \
		-message $line -type ok
	}
    }
}

proc prolog {plCmd} {
    global plQueue prologWaiting
    if {$prologWaiting} {
	set prologWaiting 0
	send_pl_cmd $plCmd
	KeepLooking
    } else {
	lappend plQueue $plCmd
   }
}

proc send_tcl_cmd {} {
    global plQueue prologWaiting
    if {![llength $plQueue]} {
	set prologWaiting 1
    } else {
	set plCmd [lindex $plQueue 0]
	set plQueue [lrange $plQueue 1 end]
	send_pl_cmd $plCmd
    }
}

proc do_tail {header args} {
    regsub -all \\\\n $args \n withCrs
    send_pl_cmd [eval $withCrs]
}

proc send_pl_cmd {withCrs} {
    global plPipe
    regsub -all \n $withCrs \\n plCmd
#    puts [concat > $plCmd]
    puts $plPipe $plCmd
    flush $plPipe
}

proc KeepLooking {} {
    global prologWaiting
    while {!$prologWaiting} {
	Reader
    }
}

set running 0
set plQueue {}
set prologWaiting 0
set callback 0

# These allow GNU prolog to use a decent amount of memory
set env(GLOBALSZ) 131072
set env(LOCALSZ) 65536
set env(TRAILSZ) 49152

# Pop a backslash before chars that would break tcl lists
regsub -all {([ ])} $PROLOG_CMD {\\\1} PROLOG_CMD

set plPipe [open "|$PROLOG_CMD 2> $PROLOG_ERR" r+]
#set plPipe [open "|m:/progra~1/GNU-Prolog/bin/gprolog.exe --init-goal load('../Run/gsimile.wbc') 2> $PROLOG_ERR" r+]
fconfigure $plPipe -translation {auto lf}
#fileevent $plPipe readable Reader

# send_pl_cmd main.
set spraf {}
while {![string match ready $spraf]} {
    if {[gets $plPipe spraf]<0} {
	exit
    }
}
KeepLooking
