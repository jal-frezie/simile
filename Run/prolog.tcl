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

wm protocol . WM_DELETE_WINDOW {close $plPipe(stream); destroy .}

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
	    set prologExit 1
	} elseif {[gets $plPipe(stream) noCrs] >= 0} {
	    regsub -all \\\\u000a $noCrs \n line
#	    puts [concat < $line]
	    if {$plPipe(debug)} {
		puts $plPipe(debug_stream) [concat < $line]
	    }
	    if {[catch {set cmd [lindex $line 0]} mess]} {
		DebugMess "Could not parse $line : $mess"
		send_pl_cmd result:-1
	    } elseif {[string match exit $cmd]} {
		set prologExit 1
	    } elseif {[string match fail $cmd]} {
		set prologExit 0
	    } elseif {[string match send_tcl_cmd $cmd]} {
		eval do_tail $line
	    } elseif {[lsearch "debug_c" $cmd]!=-1} {
		DebugMess $line
	    } else {
		DebugMess $line
		set prologExit -1
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
    set oldStack $plPipe(stack)
    set plPipe(stack) [AddCurrentToPipe $oldStack]
    send_pl_cmd call:$plCmd
    set plOutcome [KeepLooking]
    set plPipe(stack) $oldStack
    if {![string length $plPipe(stack)]} {
	ResetProgressBox
    }
    return $plOutcome
}

proc AddCurrentToPipe {stack} {
    for {set l 1} {$l < [info level]} {incr l} {
	lappend stack [info level $l]
    }
    return $stack
}

proc ShowStack {} {

    global plPipe
    ShowMess "Stack is..." info [AddCurrentToPipe $plPipe(stack)] ok
}

proc do_tail {header args} {
    global errorInfo
    set oldDir [pwd]
    if {[catch $args retVal]} {
	Query [list unhandled_tcl_error $retVal $errorInfo] error top {} ok
        cd $oldDir
	set response error:$retVal
    } else {
	set response result:$retVal
    }
    send_pl_cmd $response
}

proc send_pl_cmd {withCrs} {
    global plPipe
    set plCmd [string map [list \n \\n \r \\r] $withCrs]
#    puts [concat > $plCmd]
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
        destroy .splash ;# banner will hide error mesg if not yet withdrawn
	ShowMess "Prolog process exited" error $spew ok
    }
    if {[catch {file delete -force $simtmpdir}]} {
	Query [list cannot_delete_temp_folder $simtmpdir] warning top {} ok
    }
    if {$plPipe(debug)} {
	close $plPipe(debug_stream)
    }
    destroy .
}

# These allow GNU prolog to use a decent amount of memory -- 64bit OSes are
# especially voracious and run on big machines so give them more
set bitness 32
if {[string equal x86_64 $tcl_platform(machine)]} {
    set bitness 64
}
set vm_usage [expr $bitness*$bitness/4+16] ;# in megs
set spraf {}
while {![string match ready $spraf]} {
    incr vm_usage -16
    if {!$vm_usage} {
	error $loss
    }

    set env(GLOBALSZ) [expr 512*$vm_usage]
    set env(LOCALSZ) [expr 256*$vm_usage]
    set env(TRAILSZ) [expr 192*$vm_usage]
    set plPipe(stream) [open |[ShellFileRef $PROLOG_CMD] r+]
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
set plPipe(stack) [list "Prolog initialization"]
KeepLooking
set plPipe(stack) {}
