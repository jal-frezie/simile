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
        variable sendvars
        variable timeSteps
        set widget [$win.rsf getframe]
        set pt [$widget.edit.capt getvalue]
        $widget.edit.num configure -textvar runState(update[expr $pt+1])
        set sendvars(captList) {}
        for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
            lappend sendvars(captList) \
                    [list Time step \#$phase {(} $::runState(update$phase) {)}]
        }
        $timeSteps configure -values $sendvars(captList)
        focus $widget.edit.num
    }
    
    proc initialize {t} {
        variable sendvars
        variable timeSteps
        catch {wm title $t "Run control"}; # $t isn't a toplevel under MRE
        set geom [PrefValue custom(runControlPosition) runControlPosition]
        catch {wm geometry $t $geom}
        
        TitleFrame $t.rcf -text "Run status and control"
        set rcf [$t.rcf getframe]
        
        foreach mode {play pause stop} {
            set ${mode}Img [image create photo -file ../Images/Control/${mode}.gif]
        }
        frame $rcf.topbuttons
        Button $rcf.topbuttons.reset -image $stopImg -width 32 \
                -command "[namespace current]::SetMode $t reset"
        pack $rcf.topbuttons.reset -side left  -padx 1 -expand true -fill x
        Button $rcf.topbuttons.start -image $playImg -width 32  \
                -command "[namespace current]::SetMode $t start"
        pack $rcf.topbuttons.start -side left  -padx 1 -expand true -fill x
        Button $rcf.topbuttons.stop -image $pauseImg -state disabled -width 32  \
                -command "[namespace current]::SetMode $t stop"
        pack $rcf.topbuttons.stop -side left -padx 1 -expand true -fill x
        pack $rcf.topbuttons -side left
        
        frame $rcf.bf
        set cnvs [canvas $rcf.bf.flag -width 10 -height 10]
        $cnvs create oval 2 2 8 8 -fill [RestingColour]
        $cnvs create oval 0 0 10 10 -outline grey
        pack $rcf.bf.flag -side right -anchor e
        tk_optionMenu $rcf.bf.pulldown [namespace current]::sendvars(timeUnit) \
                unit second minute hour day week month year Ma
        pack $rcf.bf.pulldown -side right
        pack [ProgressBar $rcf.bf.bar -variable runState(currentTime)] \
                -fill x -expand true -side top -padx 4 -pady 4
        pack $rcf.bf -side left -fill x
        
        pack $rcf -fill x
        pack $t.rcf -fill x -padx 1 -pady 1
        
        
        TitleFrame $t.rsf -text "Run settings"
        set rsf [$t.rsf getframe]
        foreach {name capt var} {exec {Execute for } execTime \
                    current {Current time } currentTime \
                    disp {Display interval } displayInt} {
            frame $rsf.$name
            label $rsf.$name.capt -text $capt -width 24 -anchor w
            pack $rsf.$name.capt -side left
            entry $rsf.$name.num -relief sunken \
                    -textvar runState($var) -width 8
            pack $rsf.$name.num -side left
            label $rsf.$name.unit -textvar [namespace current]::sendvars(timeUnit)
            pack $rsf.$name.unit -side left
            pack $rsf.$name  -anchor w -pady 2
        }
        set sendvars(captList) {}
        for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
            lappend sendvars(captList) \
                    [list Time step \#$phase {(} $::runState(update$phase) {)}]
        }
        pack [frame $rsf.edit] -anchor w -pady 2
        set timeSteps [ComboBox $rsf.edit.capt -values $sendvars(captList) -editable 0 \
                -width 20 -modifycmd [list [namespace current]::SwapDistVar $t]]
        pack $timeSteps -side left
        pack $rsf.edit.capt -side left
        pack [label $rsf.edit.colon -text " "] -side left
        pack [entry $rsf.edit.num -relief sunken -width 8] -side left
        $rsf.edit.capt setvalue first
        SwapDistVar $t
        pack $rsf -fill x
        pack $t.rsf -padx 1 -pady 1 -fill x
        
        
        set sendvars(timeUnit) unit
        set sendvars(expected_end) 0
        
        SendData $t
        set sendvars(prevDisplay) 0.0
        set sendvars(currentMode) stop
	catch {wm protocol $t WM_DELETE_WINDOW \
		   "[namespace code Terminate]; destroy $t"}
    }

    proc Terminate {} {
	variable sendvars
	set sendvars(currentMode) kill
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
            set sendvars(currentMode) $action
            set widget [$winId.rcf getframe]
            $widget.topbuttons.start configure -state disabled
            $widget.topbuttons.stop configure -state normal
            RollSimulation $winId
	    if {[string match kill $sendvars(currentMode)]} {
		set sendvars(currentMode) stop
	    } else {
		$widget.topbuttons.start configure -state normal
		$widget.topbuttons.stop configure -state disabled
	    }
        } else {
            set sendvars(currentMode) $action
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
    
# Current time display is updated as an idle callback because altering it causes the 
# progress bar to update, which would do all idle callbacks anyway
    proc UpdateTimes { current left } {
        global runState
	if {[info exists runState(oldTimeCopy)]} {
	    after cancel $runState(oldTimeCopy)
	}
        set runState(oldTimeCopy) [after idle set runState(currentTime) $current]
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
        
        set unitLength [expr [SecondsInA $sendvars(timeUnit)]/[SecondsInA day]]
        set widget [$winId.rcf getframe]
        while {[lsearch {exit stop kill} $sendvars(currentMode)]==-1} {
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
                    $widget.bf.bar configure \
                            -maximum [expr int(ceil($sendvars(expected_end)))]
                }
            }
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
            
            # On reset and at start, initialize the model
            # to make sure all the values are set, and initialize displays
            
            if {[info exists redoPhase]} {
                $widget.bf.flag itemconfigure 1 -fill yellow
                update
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
                    $widget.bf.flag itemconfigure 1 -fill green
		    CondUpdate $bigPhase
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
                        $widget.bf.flag itemconfigure 1 -fill blue
			CondUpdate disp
                        set sendvars(prevDisplay) $numDisplays
                        DoDisplay $current $display $step
			CondUpdate loop
                    }
                }
                
                # Finally, see if the allotted time has elapsed and swap modes if it has
                set step [expr $exec>$update?$update:$exec]
            }
        }
        switch $sendvars(currentMode) {
	    kill {
	    } exit {
		$widget.bf.flag itemconfigure 1 -fill black
	    } default {
		$widget.bf.flag itemconfigure 1 -fill [RestingColour]
	    }
	}
    }

    proc CondUpdate {thisOp} {
	global runState

	set flash 20
	# first record how much time the last op took
	set thisUpdate [clock clicks -milliseconds]
	if {[info exists runState(lastCall)]} {
	    set runState($runState(lastOp),took) \
		[expr $thisUpdate-$runState(lastCall)]
	    set currentOld [expr $thisUpdate-$runState(lastUpdate)>$flash]
	} else {
	    set currentOld 1
	}
	set runState(lastOp) $thisOp
	set runState(lastCall) $thisUpdate

	if {[info exists runState($thisOp,took)]} {
	    set startingLong [expr $runState($thisOp,took)>$flash]
	} else {
	    set startingLong 1
	}

	if {$currentOld || $startingLong} {
	    update
	    set runState(lastUpdate) $thisUpdate
	}
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
            Ma {return 31536000000000.0}
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
