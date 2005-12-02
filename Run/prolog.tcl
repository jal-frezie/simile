# Simile source code file: Run/prolog.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# A completely compilation-free Prolog/Tcl interface that
# will work with any implementation of either language. This file is
# sourced into the Tcl interpreter where it starts the Prolog
# interpreter in a non-blocking pipe. Commands are then passed between
# the two along the pipe.

wm protocol . WM_DELETE_WINDOW {close $plPipe(stream); destroy .}

set plPipe(stack) {}
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
	    regsub -all \\\\n $noCrs \n line
#	    puts [concat < $line]
	    if {$plPipe(debug)} {
		puts $plPipe(debug_stream) [concat < $line]
	    }
	    if {[catch {set cmd [lindex $line 0]} mess]} {
		DebugMess "Could not parse $line : $mess"
		send_pl_cmd result:-1
	    } elseif {[string match get_tcl_cmd $cmd]} {
		set prologExit 1
	    } elseif {[string match send_tcl_cmd $cmd]} {
		eval do_tail $line
	    } else {
		error $line
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
    global plPipe
    set oldStack $plPipe(stack)
    set plPipe(stack) [AddCurrentToPipe $oldStack]
#puts "Prolog starting $plCmd"
    send_pl_cmd command:$plCmd
    KeepLooking
#puts "Prolog finished $plCmd"
    set plPipe(stack) $oldStack
}

proc AddCurrentToPipe {stack} {
    for {set l 1} {$l < [info level]} {incr l} {
	lappend stack [info level $l]
    }
    return $stack
}

proc ShowStack {} {

    global plPipe
    ShowMessage "Stack is..." info [AddCurrentToPipe $plPipe(stack)] ok
}

proc do_tail {header args} {
    global errorInfo
    regsub -all \\\\n $args \n withCrs
    set oldDir [pwd]
    if {[catch $withCrs retVal]} {
        set ans [ShowMessage "Simile error" error "Simile encountered an unexpected problem:\n $retVal \nDo you want to see more information?" yesno]
        if {[string match yes $ans]} {
            BuildProblem "User interface problem" error $errorInfo execution \
		unsaved none
        }
        cd $oldDir
	set response error:$retVal
    } else {
	set response result:$retVal
    }
    send_pl_cmd $response
}

proc send_pl_cmd {withCrs} {
    global plPipe
    regsub -all \n $withCrs \\n plCmd
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
	error $spew
    }
    if {[catch {file delete $simtmpdir}]} {
	ShowMessage debug warning "Simile could not delete its temporary directory $simtmpdir. This probably means that it failed to unload a model executable. Any saved models will not be affected, and you can delete the temporary directory after Simile has exited." ok
    }
    if {$plPipe(debug)} {
	close $plPipe(debug_stream)
    }
    destroy .
}

# These allow GNU prolog to use a decent amount of memory
set vm_usage 262144
set env(GLOBALSZ) [expr $vm_usage/2]
set env(LOCALSZ) [expr $vm_usage/4]
set env(TRAILSZ) [expr $vm_usage*3/16]

set plPipe(stream) [open |[ShellFileRef $PROLOG_CMD] r+]
#set plPipe [open "|m:/progra~1/GNU-Prolog/bin/gprolog.exe --init-goal load('../Run/gsimile.wbc') 2> $PROLOG_ERR" r+]
fconfigure $plPipe(stream) -encoding utf-8 -translation {auto lf}

#send_pl_cmd restore('../System/bin/main.sav').
#send_pl_cmd main.
set spraf {}
while {![string match ready $spraf]} {
    if {[gets $plPipe(stream) spraf]<0} {
	ClosePipe
    }
}
KeepLooking

