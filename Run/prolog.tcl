# Simile source code file: Run/prolog.tcl
#
# (c) Simulistics Ltd. 2001-2009
# (c) University of Edinburgh 1995-2001
#
# A completely compilation-free Prolog/Tcl interface that
# will work with any implementation of either language. This file is
# sourced into the Tcl interpreter where it starts the Prolog
# interpreter in a non-blocking pipe. Commands are then passed between
# the two along the pipe.

set plPipe(debug) 0
if $plPipe(debug) {
    set plPipe(debug_log) [file join $env(HOME) .simile log]
    set plPipe(debug_stream) [NetOpen $plPipe(debug_log) w]
}

proc KeepLooking {} {
    global plPipe
    while {![info exists prologExit]} {
	if {[eof $plPipe(stream)]} {
	    ClosePipe
	    set prologExit -2
	} elseif {[gets $plPipe(stream) noCrs] >= 0} {
	    regsub -all \\\\u000a $noCrs \n line
#	    puts [concat [string repeat -- $plPipe(recur)] pl: $line <br>]
	    if {$plPipe(debug)} {
		puts $plPipe(debug_stream) [concat < $line]
	    }
	    set definitelyList [split $line { }]
	    set cmd [lindex $definitelyList 0]
	    switch $cmd {
		exit {
		    set prologExit 1
		} fail {
		    set prologExit 0
		} send_tcl_cmd {
		    incr plPipe(recur) 
		    eval do_tail $definitelyList
		    incr plPipe(recur) -1
		} slipup {
		    error [lreplace $line 0 0 slip-up]
		} default {
		    error $line
		}
	    }
	}
    }
    return $prologExit
}

set debugBoxes 0
proc DebugMess {Mess} {
    global debugBoxes
    if {$debugBoxes} {
	tk_messageBox -title debug -icon info -message $Mess -type ok
    } else {
	puts [concat ! $Mess]
    }
}

#proc prolog {args} {
#    ShowWatchWhileDoing [concat innerProlog $args]
#}

proc prolog {plCmd} {
    global plPipe window_info
    send_pl_cmd call:$plCmd
    set plOutcome [KeepLooking]
    return $plOutcome
}

proc do_tail {header args} {
    global errorInfo
    set oldDir [pwd]
    if {[catch [join $args { }] retVal]} {
	puts $retVal
        cd $oldDir
        if {[string equal -length 7 slip-up $retVal]} {
	    set response slipup:[lrange $retVal 1 end]
	} else {
	    Query [list unhandled_tcl_error $retVal $errorInfo] error top {} ok
	    set response error:$errorInfo
	}
    } elseif {[string length $retVal]>=8388608} {
	Query too_much_data error top {} ok
	set response result: ;# emulate a cancel
    } else {
	set response result:$retVal
    }
    send_pl_cmd $response
}

proc send_pl_cmd {withCrs} {
    global plPipe
    set plCmd [string map [list \n \\u000a \r \\r] $withCrs]
#    puts [concat [string repeat -- $plPipe(recur)] tk: $plCmd <br>]
    if {$plPipe(debug)} {
	puts $plPipe(debug_stream) [concat > $plCmd]
    }
    if {![eof $plPipe(stream)]} {
	puts $plPipe(stream) $plCmd
	flush $plPipe(stream)
    }
}

proc ClosePipe {} {
    global plPipe simtmpdir
    if {[catch {close $plPipe(stream)} spew]} {
	puts $spew
        destroy .splash ;# banner will hide error mesg if not yet withdrawn
	ShowMess "Prolog process exited" error $spew ok
    }
    if {[catch {file delete -force $simtmpdir}]} {
	Query [list cannot_delete_temp_folder $simtmpdir] warning top {} ok
    }
    if {$plPipe(debug)} {
	close $plPipe(debug_stream)
    }
    exit
}

set env(MAX_ATOM) 131072
# These allow GNU prolog to use a decent amount of memory -- 64bit OSes are
# especially voracious and run on big machines so give them more
set vm_usage [expr $::tclBitness*$::tclBitness/4+16] ;# in megs
set spraf {}
while {![string match ready $spraf]} {
    incr vm_usage -16
    if {!$vm_usage} {
	error $loss
    }

    set env(GLOBALSZ) [expr 512*$vm_usage]
    set env(LOCALSZ) [expr 256*$vm_usage]
    set env(TRAILSZ) [expr 192*$vm_usage]
    set plPipe(stream) [open |$PROLOG_CMD r+]
#set plPipe [open "|m:/progra~1/GNU-Prolog/bin/gprolog.exe --init-goal load('../Run/gsimile.wbc') 2> $PROLOG_ERR" r+]
    fconfigure $plPipe(stream) -translation {auto lf} -encoding utf-8

#send_pl_cmd restore('../System/bin/main.sav').
#send_pl_cmd main.
    while {![string match ready $spraf]} {
	if {[gets $plPipe(stream) spraf]<0} {
	    catch {close $plPipe(stream)} loss
#puts "Tried with vm $vm_usage -- got $loss"
	    # crash -- do not err, just try with less VM
	    break
	}
    }
}
set plPipe(recur) 0
KeepLooking
