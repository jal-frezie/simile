# This helper provides the 'run control' box.
# It used to be part of the main AME but I took it out so
# people could write their own run controls, for instance
# to do sensitivity analysis.

# An instance of this is created if a run is started while none
# is on the screen.

#31/1/02 Change status colours to icons, simulate-cogs, display-graph, error-bomb
# RIM, JMM
# labels changed, position of window (if toplevel) fixed

set keyValue runcontrol33857

namespace eval runcontrol33857 {
	variable sendvars

proc identify {} {
	return "Run control"
}

proc Restore {winId} {
	initialize $winId
}

proc clear {t} {
    # does nothing
}

proc SwapDistVar {win} {
# ShowMessage debug info [list [set $sv] $win $w] ok
    set pt [$win.edit.capt getvalue]
    if {$pt > 2} {
	set nextVar update[expr $pt-2]
    } else {
	set nextVar [lindex {execTime currentTime displayInt} $pt]
    }
    $win.edit.num configure -textvar runState($nextVar)
    focus $win.edit.num
}
    
proc initialize {t} {
    variable sendvars
    wm title $t "Run control"
    set geom [PrefValue custom(runControlPosition) runControlPosition]
    catch {wm geometry $t $geom}

# example of old style
#
#        frame $t.exec
#        label $t.exec.capt -text "Execute for " -width 15 -anchor w
#        pack $t.exec.capt -side left
#        entry $t.exec.num -relief sunken \
#                        -textvar runState(execTime) -width 10
#        pack $t.exec.num -side left
#        label $t.exec.unit -textvar [namespace current]::sendvars(timeUnit)
#        pack $t.exec.unit -side left
#jmm            label $t.exec.plural -text (s)
#jmm            pack $t.exec.plural -side left
#    pack $t.exec  -pady 2; #6 -fill x

    set sendvars(captList) {{Execute for} {Current time} {Display interval}}
    for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
	lappend sendvars(captList) [list Time step #$phase]
    }
    pack [frame $t.edit]
    pack [ComboBox $t.edit.capt -values $sendvars(captList) -editable 0 \
	    -width 20 -modifycmd [list [namespace current]::SwapDistVar $t]] \
	    -side left
    pack $t.edit.capt -side left
    pack [label $t.edit.colon -text :] -side left
    pack [entry $t.edit.num -relief sunken -width 10] -side left
    $t.edit.capt setvalue first
    SwapDistVar $t

    pack [ProgressBar $t.bar -variable runState(currentTime)] \
	    -fill x -expand true

    foreach mode {play pause stop} {
	set ${mode}Img [image create photo -file ../Images/Control/${mode}.gif]
    }
    frame $t.topbuttons
    button $t.topbuttons.reset -image $stopImg \
	    -command "[namespace current]::SetMode $t reset"
    pack $t.topbuttons.reset -side left
    button $t.topbuttons.start -image $playImg \
	    -command "[namespace current]::SetMode $t start"
    pack $t.topbuttons.start -side left
    button $t.topbuttons.stop -image $pauseImg -state disabled \
	    -command "[namespace current]::SetMode $t stop"
    pack $t.topbuttons.stop -side left
    pack $t.topbuttons -side left

	frame $t.top
	canvas $t.top.flag -width 30 -height 30 -bg [RestingColour]
	pack $t.top.flag -side left
#jmm	label $t.top.caption -text "Time units: "
#jmm	pack $t.top.caption -side left
	tk_optionMenu $t.top.pulldown [namespace current]::sendvars(timeUnit) \
		unit second minute hour day week month year
	pack $t.top.pulldown -side right
	pack $t.top -side left

	set sendvars(timeUnit) unit
	set sendvars(expected_end) 0

	SendData $t
	set sendvars(prevDisplay) 0.0
	set sendvars(currentMode) stop
#	SetMode $t reset

}

proc SetMode { winId action } {
    global runState
    variable sendvars

    if {[string match stop $sendvars(currentMode)] || \
	    [string match exit $sendvars(currentMode)] && \
	    [string match reset $action]} {

	if {$runState(modelRunning) == 1} {
	    set updateChoice [ShowMessage "Model out of date" warning \
		    "The model has been altered since the curent runnable version was built. Rebuild it now?" yesnocancel]
	    switch $updateChoice {
		cancel {
		    return
		} yes {
		    Rerun $runState(currentWin) [string match start $action]
		    return
		} no {
		    set runState(modelRunning) 2
		}
	    } ;# switch
	}
	if {[string match start $action] && \
		[info exists runState(reloadParams)]} {
	    if {[string compare [ShowMessage "Parameters out of date" warning \
		    "New file parameters will not take effect until the model is reset. Start anyway?" okcancel] ok]} {
		return
	    }
	}
	
	SendData $winId
	set sendvars(newMode) $action
	$winId.topbuttons.start configure -state disabled
	$winId.topbuttons.stop configure -state normal
	RollSimulation $winId
	$winId.topbuttons.start configure -state normal
	$winId.topbuttons.stop configure -state disabled
    } else {
	set sendvars(newMode) $action
    }   
}

proc SendData { winId } {
    global runState redoPhase
    variable sendvars
    
    set phases [GetPhaseCount]
    set sendvars(newData) \
            "$sendvars(timeUnit) $runState(displayInt) \
            $runState(update$phases) $runState(currentTime) \
            $runState(execTime)"
    # This loop sets the array of dts in the model
    set unitLength [expr [SecondsInA $sendvars(timeUnit)]/[SecondsInA day]]
    for {set setPhase $phases} {$setPhase > 0} {incr setPhase -1} {
        set tick [expr $runState(update$setPhase)*$unitLength]
        if {$runState(prev_update$setPhase) != $tick} {
            set runState(prev_update$setPhase) $tick
            SetStep $tick $setPhase
            set redoPhase $setPhase
            #	    ShowMessage debug info "Twiddling $redoPhase" ok
        }
    }
    
    SetState $winId $sendvars(newData)
}

proc UpdateTimes { current left } {
    global runState
    set runState(currentTime) $current
    set runState(execTime) $left
}

proc PhaseFor {current step soFar} {
    global runState
    set last [expr $current-($step/2.0)]
    set next [expr $last+$step]
    if {$soFar == 1} {
	return 1
    }
    set try [expr $soFar-1]
    set nextStep $runState(update$try)

    set tryCurrent [expr $nextStep*floor($last/$nextStep)]
    set tryNext [expr $nextStep*floor($next/$nextStep)]
    if {$tryCurrent == $tryNext} {
	return $soFar
    } else {
	return [PhaseFor $tryNext $nextStep $try]
    }
}

# Execution is isolated from this box

proc RollSimulation { winId } {
	variable sendvars
	global errorInfo redoPhase runState
    
    set sendvars(currentMode) reset ;# a botch
    set unitLength [expr [SecondsInA $sendvars(timeUnit)]/[SecondsInA day]]
    while {[string compare $sendvars(currentMode) exit] && \
	    [string compare $sendvars(currentMode) stop]} {
# Collect any changes that have been made by the user
	if {[info exists sendvars(newData)]} {
	    scan $sendvars(newData) "%s %s %s %s %s" \
		    unit display update current exec
	    unset sendvars(newData)
	    set scaled_current [expr $current*$unitLength]
	    
	    if {abs($current + $exec - $sendvars(expected_end)) \
		    > $update/2} {
		set sendvars(run_length) $exec
		set sendvars(expected_end) [expr $current + $exec]
		$winId.bar configure \
			-maximum [expr int(ceil($sendvars(expected_end)))]
	    }
	}
	if {[info exists sendvars(newMode)]} {
	    set sendvars(currentMode) $sendvars(newMode)
	    unset sendvars(newMode)
	    switch $sendvars(currentMode) {
		reset {
		    set current 0.0
		    set exec $sendvars(run_length)
		    UpdateTimes $current $exec
		    set scaled_current 0.0
		    if {[info exists runState(reloadParams)]} {
			set redoPhase -1
			unset runState(reloadParams)
		    } else {
			set redoPhase 0
		    }
		    set sendvars(prevDisplay) 0.0
		    set sendvars(currentMode) stop
		}
	    }
	}
		
# On reset and at start, initialize the model
# to make sure all the values are set, and initialize displays

	if {[info exists redoPhase]} {
	    $winId.top.flag configure -bg yellow
	    update idletasks
	    if ![eval_model $scaled_current $redoPhase] {
		set sendvars(currentMode) exit
	    }
	    unset redoPhase
	    DoDisplay $current $display $update
	}

# Now run the model
	if {[string match start $sendvars(currentMode)]} {
	    if {$exec < 1.001*$update} {
		set step $exec
		set sendvars(currentMode) stop
		set exec $sendvars(run_length)
	    } else {
		set step $update
		set exec [expr $exec - $step]
	    }

# Advance time to the end of the tick

	    set current [expr $current + $step]
	    UpdateTimes $current $exec

	    set bigPhase [PhaseFor $current $step [expr [GetPhaseCount]+1]]
	    if {$bigPhase <= [GetPhaseCount]} {
		$winId.top.flag configure -bg green
		update
		if ![update_model $scaled_current $bigPhase] {
		    set sendvars(currentMode) exit
		}

		# If time is used at all in update phase it is in a
		# state variable, where the model refers to it inside
		# a last(...) function. So it is the time of the last
		# step we need -- so dont change it till now

		set scaled_current [expr $current*$unitLength]
		if ![eval_model $scaled_current $bigPhase] {
		    set sendvars(currentMode) exit
		}
    # display the results if at a new time, or every time if in static mode
		set numDisplays [expr floor(($current + $step/2)/$display)]
		if {$numDisplays != $sendvars(prevDisplay) || $step == 0} {
		    $winId.top.flag configure -bg blue
		    update idletasks
		    set sendvars(prevDisplay) $numDisplays
		    DoDisplay $current $display $step
		}
	    }
	    
# Finally, see if the allotted time has elapsed and swap modes if it has
	    set step [expr $exec>$update?$update:$exec]
	}
    }

    $winId.top.flag configure -bg [lindex "[RestingColour] black" \
	    [string match exit $sendvars(currentMode)]]
}

proc SecondsInA {time} {
	switch $time {
		second {return 1.0}
		minute {return 60.0}	
		hour {return 3600.0}
		day {return 86400.0}
		unit {return 86400.0}
		week {return 604800.0}
		month {return 2628000.0}
		year {return 31536000.0}
	}
}

proc RestingColour {} {
    global runState
    return [lindex "grey purple red" $runState(modelRunning)]
}

# No need to do anything for update, because it updates itself
proc display {args} {
}

} ;# end of namespace
