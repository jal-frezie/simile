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

    package require -exact tile 0.5
    
    proc identify {} {
        return "Run control"
    }
    
    proc Restore {winId} {
        initialize $winId
    }
    
    proc clear {t} {
        # does nothing
    }
    
    proc SwapDistVar {win pt} {
        variable sendvars
	variable myModel
        set widget $win.nb.rsf
	set node $myModel($win)

        #set pt [$widget.edit.capt cget -text]
        $widget.edit.num configure -textvar runState($node,update[expr $pt])
        $widget.edit.capt.menu delete 0 end
        set sendvars($node,captList) {}
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            lappend sendvars($node,captList) \
		[list Time step \#$phase {(} $::runState($node,update$phase) {)}]
                $widget.edit.capt.menu add command -label [list Time step \#$phase {(} $::runState($node,update$phase) {)}] \
                      -command [list [namespace current]::SwapDistVar $win $phase]                
        }
        $widget.edit.capt configure -text [list Time step $pt {(} $::runState($node,update$pt) {)}]
        focus $widget.edit.num
    }
    
    proc initialize {t} {
        variable sendvars
	variable myModel
        global runState
        global stopImg
        global pauseImg
        global playImg
        #	global runState
        
        upvar 1 node node
	set myModel($t) $node
	if {![info exists runState($node,intMethod)]} {
	    set runState($node,intMethod) Euler
	}
	set runState($node,oldIntMethod) $runState($node,intMethod)
	set runState($node,timeUnit) unit
        set runState($node,oldUnit) $runState($node,timeUnit)

        if {[string match $t [winfo toplevel $t]]} {
            wm title $t "Run control"; # $t isn't a toplevel under MRE
            set geom [PrefValue custom(runControlPosition) runControlPosition]
            if {[string compare default $geom]} {
                wm geometry $t $geom
            }
        }
        
        ::ttk::notebook $t.nb
        
        $t.nb add [frame $t.nb.rcf] -text "Run control"
        set rcf $t.nb.rcf
        ttk::frame $rcf.upper -class Toolbar
        foreach mode {play pause stop} {
            set ${mode}Img [image create photo -file ../Images/Control/${mode}.gif]
        }
        frame $rcf.upper.topbuttons
        ::ttk::button $rcf.upper.topbuttons.reset -image $stopImg -width 32 \
                -command "[namespace current]::SetMode $t reset"
        pack $rcf.upper.topbuttons.reset -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $rcf.upper.topbuttons.reset "Reset simulation"
        ::ttk::button $rcf.upper.topbuttons.start -image $playImg -width 32  \
                -command "[namespace current]::SetMode $t start"
        pack $rcf.upper.topbuttons.start -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $rcf.upper.topbuttons.start "Run or pause simulation"
        pack $rcf.upper.topbuttons -side left
        
        frame $rcf.upper.bf
        set runState($node,cnvs) [canvas $rcf.upper.bf.flag -width 18 -height 18]
        $runState($node,cnvs) create oval 6 6 12 12 -fill [RestingColour $node]
        $runState($node,cnvs) create oval 6 6 12 12 -outline grey
        pack $runState($node,cnvs) -side right -anchor e
        after idle set runState($node,fractDone) 0
        pack [set runState($node,progressBar) [::ttk::progress $rcf.upper.bf.bar -from 0 -to 100]] \
                -fill x -expand true -side top -padx 4 -pady 4
        pack $rcf.upper.bf -side left -fill x -expand true
        pack $rcf.upper -side top -anchor n -fill x -padx 4 -pady 4
        set captWidth 17
        frame $rcf.editBoxes
        foreach {name capt var} {exec {Execute for } execTime \
                    current {Current time } currentTime \
                    disp {Display interval } displayInt} {
            frame $rcf.editBoxes.$name
            label $rcf.editBoxes.$name.capt -text $capt -width $captWidth -anchor w
            pack $rcf.editBoxes.$name.capt -side left -anchor nw
            ::ttk::entry $rcf.editBoxes.$name.num -relief sunken \
                    -textvar runState($node,$var) -width 8
            pack $rcf.editBoxes.$name.num -side left -expand on -fill x -anchor nw
            label $rcf.editBoxes.$name.unit -textvar runState($node,timeUnit)
            pack $rcf.editBoxes.$name.unit -side left
            pack $rcf.editBoxes.$name  -anchor nw -pady 2 -fill x
        }
        pack $rcf.editBoxes -side bottom -pady 2 -expand on -fill both
        
        $t.nb add [frame $t.nb.rsf] -text "Run settings"
        set rsf $t.nb.rsf
        pack [frame $rsf.unitselection] -pady 2 -fill x
        pack [label $rsf.unitselection.caption -text "Time units:" -width $captWidth -anchor w] -side left -anchor nw
        ::ttk::menubutton $rsf.unitselection.pulldown
        set timeUnitMenu [menu $rsf.unitselection.pulldown.menu -tearoff 0]
        foreach unit {unit second minute hour day week month year Ma} {
          $timeUnitMenu add command -label $unit -command "set runState($node,timeUnit) $unit"
        }
        $rsf.unitselection.pulldown configure -menu $timeUnitMenu -width 11 \
              -textvariable runState($node,timeUnit)
        pack $rsf.unitselection.pulldown -side left -anchor nw
        
        pack [frame $rsf.integration] -pady 2 -fill x
        pack [label $rsf.integration.caption -text "Integration method:" -width $captWidth -anchor w] -side left -anchor nw
        ::ttk::menubutton $rsf.integration.pulldown
        set intMethodMenu [menu $rsf.integration.pulldown.menu -tearoff 0]
        foreach method {Euler {Runge-Kutta}} {
          $intMethodMenu add command -label $method -command "set runState($node,intMethod) {$method}"
        }
        $rsf.integration.pulldown configure -menu $intMethodMenu -width 11 \
              -textvariable runState($node,intMethod)
        pack $rsf.integration.pulldown -side left -anchor nw
        
        set sendvars($node,captList) {}
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            lappend sendvars($node,captList) \
                    [list Time step \#$phase {(} $::runState($node,update$phase) {)}]
        }
        pack [frame $rsf.edit] -pady 2 -expand on -fill both
        ::ttk::menubutton $rsf.edit.capt
        set timeStepMenu [menu $rsf.edit.capt.menu -tearoff 0]
        foreach timeStep $sendvars($node,captList) index {1 2 3 4 5 6 7 8 9} {
          $timeStepMenu add command -label $timeStep -command [list [namespace current]::SwapDistVar $t $index]
        }
        $rsf.edit.capt configure -menu $timeStepMenu -width 16
        pack $rsf.edit.capt -side left -anchor nw
        pack [label $rsf.edit.colon -text " "] -side left
        pack [::ttk::entry $rsf.edit.num -width 8] -side left -expand on -fill x -anchor nw
        SwapDistVar $t 1
        pack $t.nb -padx 2 -pady 2 -fill both -expand true
        
        #        set sendvars($node,timeUnit) unit
        set sendvars($node,expected_end) 0
        SendData $t
        set sendvars($node,prevDisplay) 0.0
        set sendvars($node,currentMode) stop
    }
    
    proc SetMode { winId action } {
	global runState
        variable sendvars
	variable myModel
        
	set node $myModel($winId)
        if {[string match stop $sendvars($node,currentMode)] && \
		    $runState($node,modelRunning) || \
                [string match reset $action]} {
            set widget $winId.nb.rcf

	    if {[do_in_editor set runState($node,updated)]} {
		set updateChoice [ShowMessage "Model out of date" warning \
				      "The model has been altered since the curent runnable version was built. Rebuild it now?" yesnocancel]
		switch $updateChoice {
		    yes {
			start_in_editor UpdateExecution $node $action
			return
		    } no {
			if {$runState($node,modelRunning)==3} {
			    set runState($node,modelRunning) 4
			}
			do_in_editor set runState($node,updated) 0
		    } cancel {
			return
		    }
		}
	    }
            switch $runState($node,modelRunning) {
		0 {
		    ShowMessage "Cannot run model" warning \
                        "The current model could not be built, or it failed to initialize, or it has been aborted." ok
		    return
		} 1 {
		    ShowMessage "Fixed parameters not loaded" warning \
                        "The model cannot be run because it contains fixed input parameters for which no source is defined." ok
		    return
		} 2 {
		    if {[string match start $action]} {
			ShowMessage "Model has exited" warning \
			    "The model has run into a problem during execution and needs to be reset before it can run again." ok
			return
		    }
		}
	    }
            if {[string match start $action] && \
                        [info exists runState($node,reloadParams)]} {
                if {[string compare [ShowMessage "Parameters out of date" warning \
                            "New file parameters will not take effect until the model is reset. Start anyway?" okcancel] ok]} {
                    return
                }
            }
            
            SendData $winId
            set sendvars($node,currentMode) $action
            RollSimulation $winId
        } elseif {[string equal start $sendvars($node,currentMode)]} {
	    set sendvars($node,currentMode) $action
        }
    }
    
    proc SendData { winId } {
        global runState redoPhase
        variable sendvars
	variable myModel
        
	set node $myModel($winId)        
        set phases [GetPhaseCount $node]
	set sendvars($node,newData) {}
	foreach entered [list displayInt update$phases currentTime execTime] {
# for some reason tcl thinks an empty string is a number
	    if {![llength $runState($node,$entered)] || \
		    ![string is double $runState($node,$entered)]} {
		ShowMessage "Bad run parameter" warning "Non-numeric value \"$runState($node,$entered)\" entered for run parameter $entered -- replacing with 1" ok
		set runState($node,$entered) 1
	    }
	    lappend sendvars($node,newData) $runState($node,$entered)
	}

        # This loop sets the array of dts in the model
        set unitLength [expr [SecondsInA $runState($node,timeUnit)]/[SecondsInA day]]
        set tweaked 0
        set newBalls [expr ![string equal $runState($node,timeUnit) \
                      $runState($node,oldUnit)]]
        set runState($node,oldUnit) $runState($node,timeUnit)
        for {set setPhase $phases} {$setPhase > 0} {incr setPhase -1} {
            set tick $runState($node,update$setPhase)
            #puts "Checking $tick is $runState($node,prev_update$setPhase) and $runState($node,currentTime) is $runState($node,timeAtEval)"
            if {$newBalls || ($runState($node,prev_update$setPhase)!=$tick)} {
                set runState($node,prev_update$setPhase) $tick
                SetStep $node [expr $tick*$unitLength] $setPhase
                set redoPhase($node) $setPhase
                set tweaked 1
                #	    ShowMessage debug info "Twiddling $redoPhase($node)" ok
            }
            if {$runState($node,timeAtEval) != $runState($node,currentTime)} {
                set runState($node,time$setPhase) $runState($node,currentTime)
                SetStep $node $runState($node,currentTime) -$setPhase
                set redoPhase($node) $setPhase
                #	    ShowMessage debug info "Twiddling $redoPhase($node)" ok
            }
        }
	# allow model to be saved if run settings are changed
        if {$tweaked || ![string match $runState($node,oldIntMethod) $runState($node,intMethod)]} {
            do_in_editor prolog tk_run_settings_tweaked($node)
        }
        SetStep $node 0 0
        SetState $winId $sendvars($node,newData)
    }
    
    # Current time display is updated as an idle callback because altering it causes the
    # progress bar to update, which would do all idle callbacks anyway
    proc UpdateTimes { node current left length } {
        global runState
        if {[info exists runState($node,oldTimeCopy)]} {
            after cancel $runState($node,oldTimeCopy)
        }
        set runState($node,timeAtEval) $current
        set runState($node,currentTime) $current
	set runState($node,oldTimeCopy) [set runState($node,fractDone) [expr 1-(double($left)/$length)]]
        after idle $runState($node,progressBar) set [expr 100*$runState($node,fractDone)]
        set runState($node,execTime) $left
    }
    
    proc PhaseFor {node current step soFar} {
        global runState
        set last [expr $current-($step/2.0)]
        set next [expr $last+$step]
        if {$soFar == 1} {
            return 1
        }
        set try [expr $soFar-1]
        set nextStep $runState($node,update$try)
        
        set tryCurrent [expr $nextStep*floor($last/$nextStep)]
        set tryNext [expr $nextStep*floor($next/$nextStep)]
        if {$tryCurrent == $tryNext} {
            return $soFar
        } else {
            return [PhaseFor $node $tryNext $nextStep $try]
        }
    }
    
    # Execution is isolated from this box
    
    proc RollSimulation { winId } {
        variable sendvars
        global errorInfo redoPhase runState
	global pauseImg playImg
	variable myModel
        
	set node $myModel($winId)        
        set phases [GetPhaseCount $node]
        set unitLength [expr [SecondsInA $runState($node,timeUnit)]/[SecondsInA day]]
        set widget $winId.nb.rcf
	$widget.upper.topbuttons.start configure -image $pauseImg
	$widget.upper.topbuttons.start configure -command \
	    "[namespace current]::SetMode $winId stop"

        while {[lsearch {exit stop} $sendvars($node,currentMode)]==-1} {
            # Collect any changes that have been made by the user
            if {[info exists sendvars($node,newData)]} {
#do_in_editor puts data:$sendvars($node,newData):data
		foreach {idx param} \
		    {0 display 1 update 2 current 3 exec} {
			set $param [lindex $sendvars($node,newData) $idx]
		    }
		unset sendvars($node,newData)
		set scaled_current [expr $current*$unitLength]
		set timeToEnd [expr $update>=0?$exec:-$exec]
		if {abs($current + $exec - $sendvars($node,expected_end)) > abs($update/2.0) || ![info exists sendvars($node,run_length)]} {
		    set sendvars($node,run_length) $exec
		    set sendvars($node,expected_end) \
			[expr $current + $timeToEnd]
		}
            }
            switch $sendvars($node,currentMode) {
                reset {
                    for {set tweakPhase 1} {$tweakPhase <= $phases} \
                            {incr tweakPhase} {
                                set runState($node,time$tweakPhase) 0.0
                                SetStep $node 0.0 -$tweakPhase
                            }
                    set current 0.0
                    set exec $sendvars($node,run_length)
                    UpdateTimes $node $current $exec $sendvars($node,run_length)
                    set scaled_current 0.0
                    if {[info exists runState($node,reloadParams)]} {
                        set redoPhase($node) -1
                        unset runState($node,reloadParams)
                    } else {
                        set redoPhase($node) 0
                    }
                    set sendvars($node,prevDisplay) 0.0
                    set sendvars($node,currentMode) stop
                    #		    if ![do_model advance $scaled_current $redoPhase($node)] {
                    #			set sendvars($node,currentMode) exit
                    #		    }
                }
            }
            
            # On reset and at start, initialize the model
            # to make sure all the values are set, and initialize displays
            
            if {[info exists redoPhase($node)]} {
                $widget.upper.bf.flag itemconfigure 1 -fill yellow
                update
                if {$redoPhase($node) == -1} {
                    InitTimeSeries $node
                } elseif {$redoPhase($node) == 0} {
                    ResetTimeSeries $node
                }
                UpdateTimeSeries $node 0
                if {[do_model $node eval $scaled_current $redoPhase($node)]} {
		    if {$runState($node,modelRunning)<3} {
			set runState($node,modelRunning) 3
		    }
                if {$redoPhase($node) < 1} {
                    TellAllHelpers $node reset
                }
                TellAllHelpers $node display $current $display $update
		} else {
                    set sendvars($node,currentMode) exit
                }
                unset redoPhase($node)
            }
            
            # Now run the model
            if {[string match start $sendvars($node,currentMode)]} {
                if {$exec < abs(1.001*$update)} {
                    set step $timeToEnd
                    set sendvars($node,currentMode) stop
                    set exec $sendvars($node,run_length)
                } else {
                    set step $update
                    set exec [expr $exec - abs($step)]
                }
                set timeToEnd [expr $update>=0?$exec:-$exec]
                
                # Advance time to the end of the tick
                
                set current [expr $current + $step]
                UpdateTimeSeries $node $current
                set scaled_current [expr $current*$unitLength]
                UpdateTimes $node $current $exec $sendvars($node,run_length)
                
                set bigPhase [PhaseFor $node $current $step [expr $phases+1]]
                if {$bigPhase <= $phases} {
                    $widget.upper.bf.flag itemconfigure 1 -fill green
                    CondUpdate $node $bigPhase
                    if {![do_model $node advance $scaled_current $bigPhase]} {
                        set sendvars($node,currentMode) exit
                    }
                    switch -exact -- $runState($node,intMethod) {
                        Euler {
                            SetStep $node 0 0
                            if {![do_model $node update $scaled_current $bigPhase]} {
                                set sendvars($node,currentMode) exit
                            }
                        } {Runge-Kutta} {
                            if {![RKUpdate $node $scaled_current \
				      $bigPhase $phases]} {
                                set sendvars($node,currentMode) exit
                            }
                        } default {
			    ShowMessage "Execution problem" error "Integration method $runState($node,intMethod) not supported" ok
			    set sendvars($node,currentMode) exit
			}
                    }
                    
                    # If time is used at all in update phase it is in a
                    # state variable, where the model refers to it inside
                    # a last(...) function. So it is the time of the last
                    # step we need -- so dont change it till now
                    
                    for {set tweakPhase $bigPhase} {$tweakPhase <= $phases} \
                            {incr tweakPhase} {
                                set runState($node,time$tweakPhase) $scaled_current
                                SetStep $node $scaled_current -$tweakPhase
                            }
                    if ![do_model $node eval $scaled_current $bigPhase] {
                        set sendvars($node,currentMode) exit
                    }
		    # check run control etc are still there before going on
		    if {![winfo exists $widget]} {
			return
		    }
                    # display the results if at a new time, or every time if in static mode
                    set numDisplays [expr floor(($current + $step/2)/$display)]
                    if {$numDisplays != $sendvars($node,prevDisplay) || $step == 0} {
                        $widget.upper.bf.flag itemconfigure 1 -fill blue
                        CondUpdate $node disp
                        set sendvars($node,prevDisplay) $numDisplays
                        TellAllHelpers $node display $current $display $step
                        CondUpdate $node loop
                    }
                }
                
                # Finally, see if the allotted time has elapsed and swap modes if it has
                # set step [expr $exec>$update?$update:$exec]
            } 
        }
	if {[string equal exit $sendvars($node,currentMode)]} {
	    if {$runState($node,modelRunning)==2} {
		set runState($node,modelRunning) 0
	    } else {
		set runState($node,modelRunning) 2
	    }
	}
#        switch $sendvars($node,currentMode) {
#            kill {
#		destroy $winId
#            } default {
	$widget.upper.topbuttons.start configure -image $playImg
	$widget.upper.topbuttons.start configure -command \
	    "[namespace current]::SetMode $winId start"
	$widget.upper.bf.flag itemconfigure 1 -fill [RestingColour $node]
#            }
#        }
	set sendvars($node,currentMode) stop
    }
    
    proc RKUpdate {node current phase phases} {
        global runState
        SetStep $node 1 0
        if ![do_model $node update $current $phase] {
            return 0
        }
        for {set tweakPhase $phase} {$tweakPhase <= $phases} \
                {incr tweakPhase} {
                    set interTime [expr ($runState($node,time$tweakPhase)+$current)/2]
                    SetStep $node $interTime -$tweakPhase
                }
        SetStep $node 2 0
        if ![do_model $node eval $current $phase] {
            return 0
        }
        if ![do_model $node update $current $phase] {
            return 0
        }
        SetStep $node 3 0
        if ![do_model $node eval $current $phase] {
            return 0
        }
        if ![do_model $node update $current $phase] {
            return 0
        }
        for {set tweakPhase $phase} {$tweakPhase <= $phases} \
                {incr tweakPhase} {
                    SetStep $node $current -$tweakPhase
                }
        SetStep $node 4 0
        if ![do_model $node eval $current $phase] {
            return 0
        }
        if ![do_model $node update $current $phase] {
            return 0
        }
        SetStep $node 1 0
        return 1
    }
    
    
    proc CondUpdate {node thisOp} {
        global runState
        
        set flash 20
        # first record how much time the last op took
        set thisUpdate [clock clicks -milliseconds]
        if {[info exists runState($node,lastCall)]} {
            set runState($node,$runState($node,lastOp),took) \
                    [expr $thisUpdate-$runState($node,lastCall)]
            set currentOld [expr $thisUpdate-$runState($node,lastUpdate)>$flash]
        } else {
            set currentOld 1
        }
        set runState($node,lastOp) $thisOp
        set runState($node,lastCall) $thisUpdate
        
        if {[info exists runState($node,$thisOp,took)]} {
            set startingLong [expr $runState($node,$thisOp,took)>$flash]
        } else {
            set startingLong 1
        }
        
        if {$currentOld || $startingLong} {
            update
            set runState($node,lastUpdate) $thisUpdate
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
    
    # No need to do anything for update, because it updates itself
    proc reset {winId} {
    }
    
    proc display {args} {
    }
    
} ;# end of namespace

