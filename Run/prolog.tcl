# Attempt at a completely compilation-free Prolog/Tcl interface that
# will work with any implementation of either language. This file is
# sourced into the Tcl interpreter where it starts the Prolog
# interpreter in a non-blocking pipe. Commands are then passed between
# the two along the pipe.

wm protocol . WM_DELETE_WINDOW {close $plPipe; destroy .}

proc KeepLooking {} {
    global plPipe
    while {![info exists prologExit]} {
	if {[eof $plPipe]} {
	    ClosePipe
	}
	if {[gets $plPipe noCrs] >= 0} {
	    regsub -all \\\\n $noCrs \n line
#	    puts [concat < $line]
	    if {[catch {set cmd [lindex $line 0]} mess]} {
		DebugMess "Could not parse $line : $mess"
	    } elseif {[string match get_tcl_cmd $cmd]} {
		set prologExit 1
	    } elseif {[string match send_tcl_cmd $cmd]} {
		eval do_tail $line
	    } else {
		DebugMess $line
		set prologExit 1
	    }
	}
    }
}

set debugBoxes 1
proc DebugMess {Mess} {
    global debugBoxes
    if {$debugBoxes} {
	tk_messageBox -title debug -icon info -message $Mess -type ok
    } else {
	puts [concat ! $Mess]
    }
}

proc prolog {plCmd} {
#puts "Prolog starting $plCmd"
    send_pl_cmd command:$plCmd
    KeepLooking
#puts "Prolog finished $plCmd"
}

proc do_tail {header args} {
    regsub -all \\\\n $args \n withCrs
#puts "Tcl starting $withCrs"
    set res [eval $withCrs]
#puts "Tcl got $res from $withCrs"
    send_pl_cmd result:$res
}

proc send_pl_cmd {withCrs} {
    global plPipe
    regsub -all \n $withCrs \\n plCmd
#    puts [concat > $plCmd]
    puts $plPipe $plCmd
    flush $plPipe
}

proc ClosePipe {} {
    global plPipe env
    file delete -force $env(SIMTMPDIR)
    if {[catch {close $plPipe} spew]} {
	wm withdraw . ;# banner will hide error mesg if not yet withdrawn
	bgerror $spew
    }
    exit
}

# These allow GNU prolog to use a decent amount of memory
set env(GLOBALSZ) 131072
set env(LOCALSZ) 65536
set env(TRAILSZ) 49152

# Pop a backslash before chars that would break tcl lists
regsub -all {([ ])} $PROLOG_CMD {\\\1} PROLOG_CMD

set plPipe [open |$PROLOG_CMD r+]
#set plPipe [open "|m:/progra~1/GNU-Prolog/bin/gprolog.exe --init-goal load('../Run/gsimile.wbc') 2> $PROLOG_ERR" r+]
fconfigure $plPipe -translation {auto lf}
#fileevent $plPipe readable Reader

# send_pl_cmd main.
set spraf {}
while {![string match ready $spraf]} {
    if {[gets $plPipe spraf]<0} {
	ClosePipe
    }
}
KeepLooking
