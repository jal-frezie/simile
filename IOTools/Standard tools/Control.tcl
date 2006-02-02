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
    
    proc SwapDistVar {node pt} {
        variable sendvars
	variable frames
        set widget $frames($node,rsf)

        #set pt [$widget.edit.capt cget -text]
        $widget.edit.num configure -textvar runState($node,update[expr $pt])
        $widget.edit.capt.menu delete 0 end
        set sendvars($node,captList) {}
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            lappend sendvars($node,captList) \
		[list Time step \#$phase {(} $::runState($node,update$phase) {)}]
                $widget.edit.capt.menu add command -label [list Time step \#$phase {(} $::runState($node,update$phase) {)}] \
                      -command [list [namespace current]::SwapDistVar $node $phase]                
        }
        $widget.edit.capt configure -text [list Time step $pt {(} $::runState($node,update$pt) {)}]
        focus $widget.edit.num
    }
    
    proc initialize {t} {
        variable sendvars
	variable frames
        global runState
        global stopImg
        global pauseImg
        global playImg
        #	global runState
        
	upvar 1 node node
	if {![info exists runState($node,intMethod)]} {
	    set runState($node,intMethod) Euler
	}
	set runState($node,timeUnit) unit
        set runState($node,oldUnit) $runState($node,timeUnit)

        if {[string match $t [winfo toplevel $t]]} {
#            wm title $t "Run control"; # $t isn't a toplevel under MRE
            set geom [PrefValue custom(runControlPosition) runControlPosition]
            if {[string compare default $geom]} {
                wm geometry $t $geom
            }
        }
        
        ::ttk::notebook $t.nb
        
        $t.nb add [frame $t.nb.rcf] -text "Run control"
        set rcf $t.nb.rcf
	set frames($node,rcf) $rcf
        ttk::frame $rcf.upper -class Toolbar
        foreach mode {play pause stop} {
            set ${mode}Img [image create photo -file ../Images/Control/${mode}.gif]
        }
        frame $rcf.upper.topbuttons
        ::ttk::button $rcf.upper.topbuttons.reset -image $stopImg -width 32 \
                -command "[namespace current]::SetMode $node reset"
        pack $rcf.upper.topbuttons.reset -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $rcf.upper.topbuttons.reset "Reset simulation"
        ::ttk::button $rcf.upper.topbuttons.start -image $playImg -width 32  \
                -command "[namespace current]::SetMode $node start"
        pack $rcf.upper.topbuttons.start -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $rcf.upper.topbuttons.start "Run or pause simulation"
        pack $rcf.upper.topbuttons -side left
        
        frame $rcf.upper.bf
        set runState($node,cnvs) [canvas $rcf.upper.bf.flag -width 18 -height 18]
        $runState($node,cnvs) create oval 6 6 12 12 -fill [RestingColour $node]
        $runState($node,cnvs) create oval 6 6 12 12 -outline grey
        pack $runState($node,cnvs) -side right -anchor e
        after idle set runState($node,fractDone) 0
        pack [set runState($node,progressBar) \
		  [::ttk::progress $rcf.upper.bf.bar -from 0 -to 100]] \
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
	    bind $rcf.editBoxes.$name.num <Key> "set runState($node,tweaked) 1"
            pack $rcf.editBoxes.$name.num -side left -expand on -fill x -anchor nw
            label $rcf.editBoxes.$name.unit -textvar runState($node,timeUnit)
            pack $rcf.editBoxes.$name.unit -side left
            pack $rcf.editBoxes.$name  -anchor nw -pady 2 -fill x
        }
        pack $rcf.editBoxes -side bottom -pady 2 -expand on -fill both
        
        $t.nb add [frame $t.nb.rsf] -text "Run settings"
        set rsf $t.nb.rsf
        set frames($node,rsf) $rsf
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
        set intMethodMenu [menu $rsf.integration.pulldown.menu -tearoff 0 \
			      -postcommand "set runState($node,tweaked) 1"]
        foreach method {Euler {Runge-Kutta}} {
	    $intMethodMenu add command -label $method -command \
		"set runState($node,intMethod) {$method}"
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
          $timeStepMenu add command -label $timeStep -command [list [namespace current]::SwapDistVar $node $index]
        }
        $rsf.edit.capt configure -menu $timeStepMenu -width 16
        pack $rsf.edit.capt -side left -anchor nw
        pack [label $rsf.edit.colon -text " "] -side left
        pack [::ttk::entry $rsf.edit.num -width 8] -side left -expand on -fill x -anchor nw
        SwapDistVar $node 1

        pack [frame $rsf.stepsize] -pady 2 -expand on -fill both
	pack [checkbutton $rsf.stepsize.adapt -variable runState($node,adapt) \
		  -text Adaptive\; -command "set runState($node,tweaked) 1"] \
	    -side left
	if {![info exists runState($node,errLimit)]} {
	    set runState($node,errLimit) 1e-6
	}
	pack [::ttk::entry $rsf.stepsize.maxerr \
		  -textvariable runState($node,errLimit) -width 8] \
	    -side right -expand on -fill x
	bind $rsf.stepsize.maxerr <Key> "set runState($node,tweaked) 1"
        pack [label $rsf.stepsize.caption -text "Error limit:"] -side right
        pack $t.nb -padx 2 -pady 2 -fill both -expand true
        
        #        set sendvars($node,timeUnit) unit
        set runState($node,expected_end) 0
        SendData $node
        set sendvars($node,prevDisplay) 0.0
        set sendvars($node,currentMode) stop
	set sendvars($node,busy) 0
    }
    
    proc SetMode { node action } {
	global runState
        variable sendvars
        
# Do not allow button actions if merely checking for abort
#	while {$sendvars($node,busy)} {
#	    tkwait variable sendvars($node,busy)
#	}

	if {[info exists sendvars($node,waitFrom)]} {
	    set sendvars($node,checkOn) 1
	} else {
	    if {[string match stop $sendvars($node,currentMode)]} {
		switchMode $node $action
	    } else {
		if {[string match reset $sendvars($node,currentMode)]} {
		    set sendvars($node,currentMode) stop
		} else {
		    set sendvars($node,currentMode) $action
		}
		set sendvars($node,waitFrom) [clock clicks -milliseconds]
		set sendvars($node,checkOn) 0
	    } 
	}
    }

    proc switchMode {node action} {
	global runState
        variable sendvars

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
	    set paramChoice [ShowMessage "Parameters out of date" warning \
				 "New file parameters will not take effect until the model is reset. Do you want to reset the model now before running it?" yesno]
	    if {[string equal yes $paramChoice]} {
		# reset the model
		set sendvars($node,currentMode) reset
		RollSimulation $node
	    }
	}
	
	SendData $node
	set sendvars($node,currentMode) $action
	RollSimulation $node
    }
    
    proc SendData { node } {
        global runState redoPhase
        variable sendvars
        
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
        set sendvars(unitLength) \
	    [expr [SecondsInA $runState($node,timeUnit)]/[SecondsInA day]]
        set newBalls [expr ![string equal $runState($node,timeUnit) \
                      $runState($node,oldUnit)]]
        set runState($node,oldUnit) $runState($node,timeUnit)
        for {set setPhase $phases} {$setPhase > 0} {incr setPhase -1} {
            set tick $runState($node,update$setPhase)
            #puts "Checking $tick is $runState($node,prev_update$setPhase) and $runState($node,currentTime) is $runState($node,timeAtEval)"
            if {$newBalls || ($runState($node,prev_update$setPhase)!=$tick)} {
                set runState($node,prev_update$setPhase) $tick
                SetStep $node [expr $tick*$sendvars(unitLength)] $setPhase
                set redoPhase($node) $setPhase
                #	    ShowMessage debug info "Twiddling $redoPhase($node)" ok
		set runState($node,tweaked) 1
            }
        }
	# allow model to be saved if run settings are changed
	if {[info exists runState($node,tweaked)]} {
	    do_in_editor RecordRunParams $node
	    unset runState($node,tweaked)
	}
        SetStep $node 0 0
#        SetState $winId $sendvars($node,newData)
    }
    
    proc SetupBar {node start finish} {
	global runState
	$runState($node,progressBar) config -from $start -to $finish
	set runState($node,expected_end) $finish
    }

    proc UpdateBar {node now col} {
	global runState
        set runState($node,currentTime) $now
	set runState($node,execTime) [expr $runState($node,expected_end)-$now]
	$runState($node,progressBar) set $now
	$runState($node,cnvs) itemconfigure 1 -fill $col
    }

# This is called back from the model execution process whenever
# sufficient time has elapsed for the user to start noticing that the
# display has gone out of date, or whenever it is about to embark on a
# task that it suspects will take a long time and allow the user to
# notice that it is out of date. Returns nonzero if user has stopped
# or reset execution

    proc RCInteractGUI {myNode current col} {
	variable sendvars
	UpdateBar $myNode [expr $current/$sendvars(unitLength)] $col
	set sendvars($myNode,busy) 0
	update
	set sendvars($myNode,busy) 1
	if {[info exists sendvars($myNode,waitFrom)]} {
	    unset sendvars($myNode,waitFrom)
	    if {[string compare stop $sendvars($myNode,currentMode)]} {
		switchMode $myNode $sendvars($myNode,currentMode)
	    }
	    return 1
	}
	return 0
    }

# This is similar but is called if a model step is taking a long time, to check
# if the run has been aborted.

    proc RCAbortCheck {myNode} {
	variable sendvars
	update
	if {[info exists sendvars($myNode,waitFrom)] && \
		[info exists sendvars($myNode,checkOn)]} {
	    set now [clock clicks -milliseconds]
	    if {$sendvars($myNode,checkOn) || \
		    $now-$sendvars($myNode,waitFrom)>3000} {
		set scrog [string equal yes [ShowMessage "Model stuck" info \
			 "This model appears to have got stuck with an endless or very long operation. Do you want to exit it now?" yesno]]
		if {$scrog} {
		    unset sendvars($myNode,waitFrom)
		}
		unset sendvars($myNode,checkOn)
		return $scrog
	    }
	}
	return 0
    }

    proc RollSimulation { node } {
        variable sendvars
        global errorInfo redoPhase runState adapt
	global pauseImg playImg
        variable frames

	set widget $frames($node,rcf)
        set phases [GetPhaseCount $node]
	$widget.upper.topbuttons.start configure -image $pauseImg
	$widget.upper.topbuttons.start configure -command \
	    "[namespace current]::SetMode $node stop"
	set sendvars($node,busy) 1

	foreach {idx param} \
	    {0 display 1 update 2 current 3 exec} {
		set $param [lindex $sendvars($node,newData) $idx]
	    }
	if {abs($current + $exec - $runState($node,expected_end)) > abs($update/2.0) || ![info exists sendvars($node,run_length)]} {
	    set sendvars($node,run_length) $exec
	    SetupBar $node $current [expr $current + $exec]
	}
	if {[string equal reset $sendvars($node,currentMode)]} {
	    set current 0.0
	    set exec $sendvars($node,run_length)
	    SetupBar $node $current [expr $current + $exec]
	    if {[info exists runState($node,reloadParams)]} {
		set redoPhase($node) $runState($node,reloadParams)
		unset runState($node,reloadParams)
		if {![RunningInC $node]} {
		    InitTimeSeries $node
		}
	    } else {
		set redoPhase($node) 0
	    }
	}
	set scaled_current [expr {$current*$sendvars(unitLength)}]
	set finish [expr {$current+$exec}]

	if {[info exists redoPhase($node)]} {
	    UpdateBar $node $current yellow
	    if {![RunningInC $node]} {
		if {$redoPhase($node) == 0} {
		    ResetTimeSeries $node
		}
		UpdateTimeSeries $node 0 0
	    }
	    if {[ResetModel $node $redoPhase($node)]} {
		if {$runState($node,modelRunning)<3} {
		    set runState($node,modelRunning) 3
		}
                if {$redoPhase($node) < 1 && $display} {
                    TellAllHelpers $node reset
                }
                if {$display} {
		    TellAllHelpers $node display $current $display $update
		}
		set sendvars($node,currentMode) stop
	    } else {
		set sendvars($node,currentMode) exit
	    }
	    unset redoPhase($node)
	}
	if {$display} {
	    set lastDisp [expr int($current/$display)]
	}
	if {[info exists runState($node,pause)]} {
	    set pause [min $finish $runState($node,pause)]
	    unset runState($node,pause)
	} else {
	    set pause $finish
	}
	set adapt(doublings) 0
	while {[lsearch {exit stop} $sendvars($node,currentMode)]==-1} {
	    if {$display} {
		set nextDisp [expr 1.0*$display*[incr lastDisp]]
	    } else {
		set nextDisp [expr 2*$pause-$current]
	    }
	    if {[RunningInC $node]} {
		set current $nextDisp
	    } else {
		set timeCheck [UpdateTimeSeries $node $current $nextDisp]
		if {$nextDisp>$timeCheck} {
		    set current $timeCheck
		} else {
		    set current $nextDisp
		}
	    }
	    if {$current>$pause} {
		set current $pause
	    }
	    set scaled_next [expr {$current*$sendvars(unitLength)}]
	    if {$runState($node,adapt)} {
		set limit $runState($node,errLimit)
	    } else {
		set limit 0
	    }
	    switch -- [ExecuteModel $node $runState($node,intMethod) \
			 $scaled_current $scaled_next $limit] {
			     -1 {
				 set current $runState($node,currentTime)
				 set sendvars($node,currentMode) exit
			     } 0 {
				 set current $runState($node,currentTime)
				 set sendvars($node,currentMode) stop
			     }
			 } ;# default: keep going
	    if {![info exists runState($node,cnvs)]} {
		return
	    }
            if {$current==$nextDisp && \
		    [string match start $sendvars($node,currentMode)]} {
		UpdateBar $node $current blue ;# so GetModelTime does right
		if {![TellAllHelpers $node display $current $display 1]} {
		    set sendvars($node,currentMode) stop
		}
	    }
	    set scaled_current $scaled_next
	    if {$current>=$pause} {
		set sendvars($node,currentMode) stop
		if {$current>=$finish} {
		    set exec $sendvars($node,run_length)
		    SetupBar $node $finish [expr $finish+$exec]
		} else {
		    UpdateBar $node $current green
		}
	    }
	}
	if {[string equal exit $sendvars($node,currentMode)]} {
	    if {$runState($node,modelRunning)==2} {
		set runState($node,modelRunning) 0
	    } else {
		set runState($node,modelRunning) 2
	    }
	}
	$widget.upper.topbuttons.start configure -image $playImg
	$widget.upper.topbuttons.start configure -command \
	    "[namespace current]::SetMode $node start"
	UpdateBar $node $current [RestingColour $node]
	set sendvars($node,currentMode) stop
	set sendvars($node,busy) 0
    }
	    
# This now only used in debug mode; c++ has its own interaction regulator
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

