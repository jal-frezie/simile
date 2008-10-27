# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

set auto_path [list [file join $env(SP_PATH) lib] \
		   [file join $env(SP_PATH) lib tcl[info tclversion]]]
package require Trf ;# loads right version of Trf (fingers crossed)

proc load_c_stub_1 {} {
    global env tcl_platform
    scan [info tclversion] {%d.%d} MAJ MIN
    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN}.$env(SIMILE_VERSION).$onUnix
    if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
	error "Could not find a stub for Simile $env(SIMILE_VERSION) and TclTk ${MAJ}.${MIN} under $tcl_platform(platform) -- $dummy"
    }
}

proc load_c_stub_2 {} {
    global env

    loadcommands
    randseed [clock scan now]
}

proc ExecuteTo {node modelId instanceId current pause \
		    unitLength display foci intMethod maxErr {callerId {}}} {
    global adapt masterId dispDone userAction

    set masterId $callerId
    set dispDone 0
    set userAction 0 ;# nothing so far
    set forward [expr {$pause>$current}]
    set scaled_current [expr {$current*$unitLength}]
    set adapt(doublings) 0 ;# only relevant for tcl
    if {$display} {
	set lastDisp [expr int($current/$display)]
    }
    set currentMode start
    set payload {}
    while {[lsearch {exit stop} $currentMode]==-1} {
	if {$display} {
	    set nextDisp [expr 1.0*$display*[incr lastDisp \
						 [expr $forward*2-1]]]
	} else {
	    set nextDisp [expr 2*$pause-$current]
	}
	set current $nextDisp ;# INCREMENT IS HERE
	if {($current>$pause) == $forward} {
	    set current $pause
	}
	set scaled_next [expr {$current*$unitLength}]
	set howAndWhen [ExecuteModel $node $modelId $instanceId $intMethod \
			    $scaled_current $scaled_next $maxErr]
	set current [lindex $howAndWhen 1]
	switch -- [lindex $howAndWhen 0] {
	    -1 {
		set currentMode exit
	    } 0 {
		set currentMode stop
	    }
	} ;# default: keep going
#	if {![info exists runState($node,cnvs)]} {
#	    return $currentMode ;# run control window killed?
#	}
	if {$current==$nextDisp && ![string equal exit $currentMode]} {
	    set oldPayload $payload
	    set payload {}
	    foreach point $foci {
		lappend payload $point [handle_data $modelId $instanceId $point]
	    }
	    if {[ShiftDisplays $node $payload $current $display]} {
		set currentMode stop
	    }

#	    if {![TellAllHelpers $node $payload Display $current $display 1]} {
#		set currentMode stop
#	    }
	    # now it is done, previous one must have finished, if any
	    FreeAll $oldPayload
	}
	set scaled_current $scaled_next
	if {$current==$pause} {
	    set currentMode stop
	}
    }
    waitForDisps
#    InteractGUI $instanceId $scaled_next 1 ;# must do it at end
    FreeAll $payload
    return $currentMode
}

proc FreeAll {load} {
    foreach {id hdl} $load {
	free_data_handle $hdl
    }
}

proc ExecuteModel {myNode modelId instanceId howInt start finish errLim} {
    global dispDone
    if {[catch {
	if {$modelId} {
	    set model_id(running) $myNode
	    c_executemodel $modelId $instanceId \
		[expr ![string equal Euler $howInt]] $start $finish $errLim
	} else {
	    TclExecuteModel $myNode $howInt $start $finish $errLim
	}
    } errList]} {
	InteractGUI $instanceId [lindex $errList 3] 2
	return [ExplainError $errList]
# This will also need to raise an exception so we can retrieve stop time etc
#    } elseif {$errList==-1} {
#        start_in_editor BuildProblem "Execution notice" info "Model execution has been paused at a discontinuity which could not be dealt with by adaptive step size control." execution
#        do_in_editor RaiseModelWindow $myNode
#        return 0
    } else {
	return $errList
    }
}

proc waitForDisps {} {
    global dispDone
    if {![info exists dispDone]} {
	vwait dispDone
    }
}

if {![info exists runHow]} { ;# we are in separate interp
    proc InteractGUI {args} {
	global masterId userAction
#	return 0
#	return [thread::send $masterId [info level 0]]
	thread::send -async $masterId [info level 0] userAction
	return $userAction ;# from last time
    }
 
# This one needs to wait till previous call finished    
    proc ShiftDisplays {args} {
	global masterId dispDone userAction
	waitForDisps
	set userAction $dispDone
	unset dispDone
	thread::send -async $masterId [info level 0] dispDone
	return $userAction ;# from last time
    }
}