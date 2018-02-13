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
	variable frames
        set widget $frames($node,rcf)

        #set pt [$widget.edit.capt cget -text]
        $widget.edit.capt.menu delete 0 end
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
	    set step runState($node,update$phase)
	    if {!$pt && [string equal $step [$widget.edit.num cget -textvar]]} {
		# posting command, this is current entry
		set pt $phase
	    }
	    set label [format [tr. {Time step #%1$d ( %2$s )}] \
			   $phase [set ::$step]]
	    $widget.edit.capt.menu add command -label $label \
		-command [list [namespace current]::SwapDistVar $node $phase]
	    if {$phase==$pt} {
		$widget.edit.capt configure -text $label
		$widget.edit.num configure -textvar $step
	    }
        }
        focus $widget.edit.num
    }
    
    proc initialize {t} {
	variable frames
        global runState
        global stopImg
        global pauseImg
        global playImg
        #	global runState

	upvar 1 this4 inst ;# note Itcl 4 bug workaround
	set node [lindex [$inst GetNode] 0]
# if cannot do above because trying to live without RunControl instance
#	upvar 2 node node
	if {![info exists runState($node,intMethod)]} {
	    set runState($node,intMethod) Euler
	}
	if {![info exists runState($node,timeUnit)]} {
	    set runState($node,timeUnit) unit
	}
        set runState($node,oldUnit) $runState($node,timeUnit)
        set runState($node,newUnit) $runState($node,timeUnit)
        if {[string match $t [winfo toplevel $t]]} {
#            wm title $t "Run control"; # $t isn't a toplevel under MRE
            set geom [PrefValue custom(runControlPosition) runControlPosition]
            catch {wm geometry $t $geom}
        }
        
        ::ttk::notebook $t.nb
        
        $t.nb add [frame $t.nb.rcf] -text [tr. "Run control"]
        set rcf $t.nb.rcf
	set frames($node,rcf) $rcf
        ttk::frame $rcf.upper -class Toolbar
        foreach mode {play pause stop} {
            set ${mode}Img [image create photo -file $::SIMILE_PATH/Images/Control/${mode}.gif]
        }
        frame $rcf.upper.topbuttons
        ::ttk::button $rcf.upper.topbuttons.reset -image $stopImg -width 32 \
                -command "[namespace current]::SetMode $node reset"
        pack $rcf.upper.topbuttons.reset -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $rcf.upper.topbuttons.reset [tr. "Reset simulation"]
        ::ttk::button $rcf.upper.topbuttons.start -image $playImg -width 32  \
                -command "[namespace current]::SetMode $node start"
        pack $rcf.upper.topbuttons.start -side left  -padx 1 -pady 2 -expand true -fill x
        BindPopup $rcf.upper.topbuttons.start [tr. "Run or pause simulation"]
        pack $rcf.upper.topbuttons -side left
        
        frame $rcf.upper.bf
        set runState($node,cnvs) [canvas $rcf.upper.bf.flag -width 18 -height 18]
        $runState($node,cnvs) create oval 6 6 12 12 -fill [RestingColour $node]
        $runState($node,cnvs) create oval 6 6 12 12 -outline grey
        pack $runState($node,cnvs) -side right -anchor e
        after idle set runState($node,fractDone) 0
	set runState($node,progressBar) \
	    [::ttk::progressbar $rcf.upper.bf.bar -maximum 100]
	pack $runState($node,progressBar) \
	    -fill x -expand true -side top -padx 4 -pady 4
        pack $rcf.upper.bf -side left -fill x -expand true
        pack $rcf.upper -side top -anchor n -fill x -padx 4 -pady 4
        set captWidth 17
        frame $rcf.editBoxes
        foreach {name capt var} {exec {Execute for:} execTime \
                    current {Current time:} currentTime \
                    disp {Display each} displayInt} {
            frame $rcf.editBoxes.$name
            label $rcf.editBoxes.$name.capt -text [tr. $capt] \
		-width $captWidth -anchor w
# TRANSLATOR: $capt is one of doubly bracketed strings after foreach above
            pack $rcf.editBoxes.$name.capt -side left -anchor nw
            ::ttk::entry $rcf.editBoxes.$name.num \
                    -textvar runState($node,$var) -width 8
            pack $rcf.editBoxes.$name.num -side left -expand on -fill x -anchor nw
            label $rcf.editBoxes.$name.unit -textvar runState($node,timeUnit)
            pack $rcf.editBoxes.$name.unit -side left
            pack $rcf.editBoxes.$name  -anchor nw -pady 2 -fill x
        }
	set runState($node,evtDisp) 0
	set squeezed $rcf.editBoxes.disp.capt
	pack [ttk::checkbutton $rcf.editBoxes.disp.evts -text [tr. {event;}] \
		  -variable runState($node,evtDisp)] -side left \
	    -after $squeezed
	$squeezed config -width 10
        pack $rcf.editBoxes -side top -pady 2 -expand on -fill both
	set runState($node,timeReached) $runState($node,currentTime)
        pack [frame $rcf.edit] -pady 2 -expand on -fill both
        ::ttk::menubutton $rcf.edit.capt
	set tCd [namespace code [list SwapDistVar $node 0]]
	set timeStepMenu [menu $rcf.edit.capt.menu -tearoff 0 -postcommand $tCd]
# This is done in SwapDistVar
#        foreach timeStep $runState($node,captList) index {1 2 3 4 5 6 7 8 9} {
#          $timeStepMenu add command -label $timeStep -command [list [namespace current]::SwapDistVar $node $index]
#        }
        $rcf.edit.capt configure -menu $timeStepMenu -width 18
        pack $rcf.edit.capt -side left -anchor nw
        pack [label $rcf.edit.colon -text " "] -side left
	set stepField [::ttk::entry $rcf.edit.num -width 8]
        pack $stepField -side left -expand on -fill x -anchor nw
	bind $stepField <Return> $tCd
        SwapDistVar $node [GetPhaseCount $node]
        
        $t.nb add [frame $t.nb.rsf] -text [tr. "Run settings"]
        set rsf $t.nb.rsf
        set frames($node,rsf) $rsf
        pack [frame $rsf.unitselection] -pady 2 -fill x
        pack [label $rsf.unitselection.caption -text [tr. "Time units:"] \
		  -width $captWidth -anchor w] -side left -anchor nw
#        ::ttk::menubutton $rsf.unitselection.pulldown
#        set timeUnitMenu [menu $rsf.unitselection.pulldown.menu -tearoff 0]
#        foreach unit [concat unit $::commonTimes] {
#	    $timeUnitMenu add command -label $unit \
#		-command [namespace code [list AlterUnit $node $unit]]
#        }
#        $rsf.unitselection.pulldown configure -menu $timeUnitMenu -width 12 \
#              -textvariable runState($node,timeUnit)
	set unitCB $rsf.unitselection.pulldown
	::ttk::combobox $unitCB -state readonly \
	    -values [concat unit $::commonTimes] \
	    -textvariable runState($node,newUnit)
	bind $unitCB <<ComboboxSelected>> \
	    [namespace code [list AlterUnit $node]]
        pack $rsf.unitselection.pulldown -side left -anchor nw
        
        pack [frame $rsf.integration] -pady 2 -fill x
        pack [label $rsf.integration.caption -text [tr. "Integration method:"] \
		  -width $captWidth -anchor w] -side left -anchor nw
#        ::ttk::menubutton $rsf.integration.pulldown
#        set intMethodMenu [menu $rsf.integration.pulldown.menu -tearoff 0]
#        foreach method {Euler Runge-Kutta} {
# TRANSLATOR: these methods need translation
#	    $intMethodMenu add command -label [tr. $method] \
#		-command [namespace code [list UpdateIntMethod $intMethodMenu \
#					      $node $method]]
#        }
#        $rsf.integration.pulldown configure -menu $intMethodMenu -width 12 \
#	    -text [tr. $runState($node,intMethod)] ;# TRANSLATOR done
        pack [::ttk::combobox $rsf.integration.pulldown -state readonly \
	       -values [list Euler Runge-Kutta] \
	       -textvariable runState($node,intMethod)] -side left -anchor nw

# This is done in SwapDistVar
#        set runState($node,captList) {}
#        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
#            lappend runState($node,captList) \
#                    [list Time step \#$phase {(} $::runState($node,update$phase) {)}]
#        }

        pack [frame $rsf.stepsize] -pady 4 -expand on -fill both
	pack [ttk::checkbutton $rsf.stepsize.adapt \
		  -variable runState($node,adapt) \
		  -text [tr. "Adaptive\; Error limit:"] \
		  -command "set runState($node,tweaked) 1"] \
	    -side left
	pack [::ttk::entry $rsf.stepsize.maxerr \
		  -textvariable runState($node,errLimit) -width 8] \
	    -side right -expand on -fill x
	bind $rsf.stepsize.maxerr <Key> "set runState($node,tweaked) 1"

	pack [frame $rsf.speedlim] -pady 4 -expand on -fill both
	pack [ttk::checkbutton $rsf.speedlim.use \
		  -variable runState($node,splimit) \
		  -text [tr. "Limit updates/sec to:"] \
		  -command "set runState($node,tweaked) 1"] -side left
	pack [::ttk::entry $rsf.speedlim.val \
		  -textvariable runState($node,speedLimit) -width 8] \
	    -side right -expand on -fill x
	bind $rsf.speedlim.val <Key> "set runState($node,tweaked) 1"

	pack [frame $rsf.resetTo] -anchor nw -pady 2 -fill x
	label $rsf.resetTo.capt -text [tr. {Time at reset:}] \
	    -width $captWidth -anchor w
	pack $rsf.resetTo.capt -side left -anchor nw
	::ttk::entry $rsf.resetTo.num \
	    -textvar runState($node,resetTo) -width 8
	pack $rsf.resetTo.num -side left -expand on -fill x -anchor nw

	frame $rsf.pauses
	pack [label $rsf.pauses.capt -text [tr. "Pause on:"] -anchor w] \
	    -side left -padx 4 -anchor w
	pack [ttk::checkbutton $rsf.pauses.event \
		  -variable runState($node,evtpause) \
		  -text [tr. "Events"] \
		  -command "set runState($node,tweaked) 1"] -side left -padx 4
	pack [ttk::checkbutton $rsf.pauses.limit \
		  -variable runState($node,lmtpause) \
		  -text [tr. "Under/Overruns"] \
		  -command "set runState($node,tweaked) 1"] -side left -padx 4
	if {[info exists ::do_events]} {
	    pack $rsf.pauses -pady 4 -expand on -fill both
	}
        $t.nb add [frame $t.nb.log] -text [tr. "Log"]
        set log $t.nb.log
	pack [scrollbar $log.scroll -orient vert -command "$log.text yview"] \
	    -side right -fill y
	pack [text $log.text -yscrollcommand "$log.scroll set" -state disabled \
		  -height 10] -fill both

        pack $t.nb -padx 2 -pady 2 -fill both -expand true
        
        #        set runState($node,timeUnit) unit
        set runState($node,expected_end) 0.0
        SendData $node
        set runState($node,prevDisplay) 0.0
        set runState($node,currentMode) stop
	set runState($node,busy) 0
    }
    
#    proc UpdateIntMethod {menu node method} {
#	global runState
#	
#	[winfo parent $menu] configure -text [tr. $method] ;# TRANSLATOR done
#	set runState($node,intMethod) $method
#    }

    proc AlterUnit {node} {
	global runState
	set newUnit $runState($node,newUnit)
	set timeFactor [expr {[InDays $runState($node,timeUnit)]/ \
				  [InDays $newUnit]}]
	set runState($node,timeUnit) $newUnit
	foreach var {currentTime execTime expected_end} {
	    set runState($node,$var) [format %.8g [expr {$runState($node,$var)*$timeFactor}]]
	}
    }

    proc ShareAction {node defcon} {
	global execThread

	if {[info exists execThread]} {
	    tsv::set action $node $defcon
	}
    }

    proc SetMode { node action } {
        global runState

	set runState($node,currentMode) $action
	if {!$runState($node,busy)} { ;# do action now
	    switchMode $node
	} else {
	    ShareAction $node 1
	}
    }

    proc AbortFromMenu {node action} {
	global hideQuery runState

	if {[info exists runState($node,busy)] && $runState($node,busy)} {
	    set hideQuery $action
	    ShareAction $node 10 ;# rest done on exit
	} else {
	    ScrubRun $node 1
	    eval $action
	}
    }

    proc switchMode {node} {
	global runState

	set action $runState($node,currentMode)
	if {[do_in_editor set runState($node,updated)]} {
	    switch [Query model_out_of_date warning top {} {yes no cancel}] {
		yes {
		    UpdateExecution $node $action
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
		Query not_runnable warning top {} ok
		return
	    } 1 {
		Query params_not_loaded warning top {} ok
		return
	    } 2 {
		if {[string match start $action]} {
		    Query model_has_exited warning top {} ok
		    return
		}
	    }
	}
	if {[string match start $action] && $runState($node,reloadParams)<1} {
	    set paramChoice [Query params_out_of_date warning top {} {yes no}]
	    if {[string equal yes $paramChoice]} {
		# reset the model
		SendData $node
		set runState($node,currentMode) reset
		RollSimulation $node
	    }
	}
	SendData $node
	set runState($node,currentMode) $action
	RollSimulation $node
    }
    
    proc SendData { node } {
        global runState redoPhase
        
	if {$runState($node,currentTime)==0 && \
		$runState($node,timeReached)!=0} {
	    Query manual_zero warning execution {} ok
	}
        set phases [GetPhaseCount $node]
	set runState($node,newData) {}
	foreach entered \
	    {displayInt currentTime execTime errLimit speedLimit resetTo} {
# for some reason tcl thinks an empty string is a number
	    set globName runState($node,$entered)
	    if {![string is double -strict [set $globName]]} {
		Query [list run_param_not_number [set $globName] \
			   $entered] warning execution {} ok
		set $globName 1
	    }
# last two not used from list, included just for format check
	    lappend runState($node,newData) [set $globName]
	}
	if {$runState($node,execTime)<0} {
	    set phaseFlip -1
	} else {
	    set phaseFlip 1
	}

        # This loop sets the array of dts in the model
        set runState($node,unitLength) \
	    [expr {[InDays $runState($node,timeUnit)]}]
        set newBalls [expr ![string equal $runState($node,timeUnit) \
                      $runState($node,oldUnit)]]
        set runState($node,oldUnit) $runState($node,timeUnit)
        for {set setPhase $phases} {$setPhase > 0} {incr setPhase -1} {
	    set globName runState($node,update$setPhase)
	    if {![string is double -strict [set $globName]]} {
		Query [list run_param_not_number [set $globName] \
			   [list time step $setPhase]] warning execution {} ok
		set $globName 1
	    }
            set tick [expr [set $globName]*$phaseFlip]
            #puts "Checking $tick is $runState($node,prev_update$setPhase) and $runState($node,currentTime) is $runState($node,timeAtEval)"
            if {$newBalls || ($runState($node,prev_update$setPhase)!=$tick)} {
                set runState($node,prev_update$setPhase) $tick
                SetStep $node [expr $tick*$runState($node,unitLength)] \
		    $setPhase
                set redoPhase($node) $setPhase
		if {$setPhase==$phases} {
		    incr redoPhase($node) ;# only do RK substep
		}
                #	    ShowMess debug info "Twiddling $redoPhase($node)" ok
            }
        }
        SetStep $node 0 0
	SwapDistVar $node 0 ;# in case any non-numeric phases fixed
#        SetState $winId $runState($node,newData)
    }
    
    proc SetupBar {node start finish} {
	global runState
	set runState($node,remembered_start) $start
	set runState($node,expected_end) $finish
	set runState($node,run_length) [expr $finish-$start]
    }

    proc UpdateBar {node now col} {
	global runState
        set runState($node,currentTime) [format %.8g $now]
        set runState($node,timeReached) [format %.8g $now]
	# so I can check if entry edited
	set runState($node,execTime) [format %.8g [expr {$runState($node,expected_end)-$now}]]
	if {$runState($node,run_length)} {
	    $runState($node,progressBar) configure -value \
		[expr 100*($now-$runState($node,remembered_start))/ \
		     $runState($node,run_length)]
	}
	$runState($node,cnvs) itemconfigure 1 -fill $col
	return [string compare start $runState($node,currentMode)]
    }

# This is called back from the model execution process whenever
# sufficient time has elapsed for the user to start noticing that the
# display has gone out of date, or whenever it is about to embark on a
# task that it suspects will take a long time and allow the user to
# notice that it is out of date. Returns nonzero if user has stopped
# or reset execution

    proc RCInteractGUI {myNode current col} {
	DebugMess [info level 0]
	global runState

	set endRun [UpdateBar $myNode \
			[expr $current/$runState($myNode,unitLength)] $col]
	if {[winfo exists .shortDlg]} {
	    SetDlgRes no ;# closes short dlg
	    set ::dialogues(ack) 1 ;# closes long dlg
	}
	UpdateIfFreezy
	return $endRun
    }

# This is similar but is called if a model step is taking a long time, to check
# if the run has been aborted.

    proc RCAbortCheck {node} {
	global updateLastDone runState

	if {[string equal stop $runState($node,currentMode)] && \
		[clock clicks -milliseconds]-$updateLastDone>3000 && \
	    	![winfo exists .shortDlg]} {
	    # pretend button never pushed
	    # ShareAction $node 0
	    # set runState($node,currentMode) start
	    
	    if {[Query model_stuck info execution {} ok] eq "ok"} {
		ShareAction $node 10
		set runState($node,currentMode) exit
		return 1
	    } ;# if not, it was auto closed by above proc at end of time step
	}
	return 0
    }

    proc RollSimulation { node } {
        global errorInfo redoPhase runState updateLastDone
	global pauseImg playImg hideQuery
        variable frames

	set widget $frames($node,rcf)
        set phases [GetPhaseCount $node]
	$widget.upper.topbuttons.start configure -image $pauseImg
	$widget.upper.topbuttons.start configure -command \
	    "[namespace current]::SetMode $node stop"
	set runState($node,busy) 1

	foreach param {display current exec} val $runState($node,newData) {
	    set $param $val
	}
	set forward [expr $exec>0]
	if {![info exists runState($node,run_length)] || \
		abs($current + $exec - $runState($node,expected_end)) > \
			abs($runState($node,run_length) * 1e-8)} {
# check if fields edited
	    SetupBar $node $current [expr $current + $exec]
	}
	do_in_editor RecordRunParams $node
	if {[string equal reset $runState($node,currentMode)]} {
	    set current $runState($node,resetTo)
	    set exec $runState($node,run_length)
	    SetupBar $node $current [expr $current + $exec]

	    set log $runState($node,helperId).nb.log.text
	    $log configure -state normal
	    $log delete 1.0 end
	    $log configure -state disabled

	    set redoPhase($node) [expr {min(0,$runState($node,reloadParams))}]
	    set runState($node,reloadParams) 10
	}
	set finish [expr {$current+$exec}]

	ShareAction $node 0
	set runState(pacer) [set updateLastDone [clock clicks -milliseconds]]
	if {[info exists redoPhase($node)]} {
	    UpdateBar $node $current yellow
	    if {[ResetModel $node $runState($node,intMethod) \
		     [expr {$current*$runState($node,unitLength)}] \
		     $redoPhase($node)]} {
		if {$runState($node,modelRunning)<3} {
		    set runState($node,modelRunning) 3
		}
                if {$redoPhase($node) < 1} {
		    if {$display} {
			TellAllHelpers $node {} 1 Reset
		    }
		    set runState($node,currentMode) stop
                }
                if {$display} {
		    TellAllHelpers $node {} 1 Display $current $display 1
		}
	    } else {
		set runState($node,currentMode) exit
	    }
	    unset redoPhase($node)
	}
	set pause $finish
	if {[info exists runState($node,pause)]} {
	    if {($runState($node,pause)<$finish) == $forward} {
		set pause $runState($node,pause)
	    }
	    unset runState($node,pause)
	}
	if {$runState($node,adapt)} {
	    set maxErr $runState($node,errLimit)
	} else {
	    set maxErr 0
	}
	if {[string equal start $runState($node,currentMode)]} {
	    set modelAct \
		[ExecuteTo $node $current $pause $runState($node,unitLength) \
		     $display [ListFoci $node] $runState($node,intMethod) \
		     $maxErr $runState($node,lmtpause) \
		     $runState($node,evtpause) $runState($node,evtDisp)]
	    if {[string equal start $runState($node,currentMode)]} {
		set runState($node,currentMode) $modelAct
	    }
#	    switchMode $node
# don't know what the above was for, it caused spurious display updates
	}
	set current $runState($node,currentTime)
	if {[string equal exit $runState($node,currentMode)]} {
	    if {$runState($node,modelRunning)==2} {
		set runState($node,modelRunning) 0
	    } else {
		set runState($node,modelRunning) 2
	    }
	} else {
	    if {abs($current-$finish)<1e-6} { ;# allow for min freq overshoot
		set exec $runState($node,run_length)
		SetupBar $node $finish [expr $finish+$exec]
	    } else {
		UpdateBar $node $current green
	    }
	}
	$widget.upper.topbuttons.start configure -image $playImg
	$widget.upper.topbuttons.start configure -command \
	    "[namespace current]::SetMode $node start"
	UpdateBar $node $current [RestingColour $node]
	set runState($node,busy) 0
	if {[info exists hideQuery]} { ;# finish aborting execution
	    ScrubRun $node 1
	    set chainCmd $hideQuery
	    unset hideQuery ;# Make sure only happens once even if recursion
	    eval $chainCmd ;#ExDestroyHelpers $node
	}
    }

	    
#    proc ResultsToGUI {node current display} {
#	variable runState
#	global runState
#
#	UpdateBar $node $current blue ;# so GetModelTime does right
#	set success [TellAllHelpers $node Display $current $display 1]
#	
#	if {$runState($node,splimit)} {
#	    set minStep [expr {1000/$runState($node,speedLimit)}]
#	    set extraDelay [expr {$minStep-([clock clicks]-$runState($node,kickTime))/1000}]
#	    after $extraDelay [namespace code [list StoreTime $node]]
#	    set runState($node,busy) 0
#	    vwait [namespace current]::runState($node,kickTime)
#	    set runState($node,busy) 1
#	}
#	return $success
#    }
#
    proc ListFoci {node} {
	global helperTable runState

	set allFoci {}
	foreach {name inst} [array get helperTable *,whichInstance] {
	    if {[string equal $node [$inst GetNode]]} {
		foreach focus $helperTable($inst,foci) {
		    if {[lsearch $allFoci $focus]==-1} {
			lappend allFoci $focus
		    }
		}
	    }
	}
# now add nodes being logged by snapshot tools
	foreach logger [array names runState log*] {
	    if {[string equal $node [lindex $runState($logger) 0]]} {
		set focus [string range $logger 3 end]
		if {[lsearch $allFoci $focus]==-1} {
		    lappend allFoci $focus
		}
	    }
	}
# and those for scripted callback requests
	foreach {callback nodes} [array get runState *,scriptReqs] {
	    foreach focus $nodes {
		if {[lsearch $allFoci $focus]==-1} {
		    lappend allFoci $focus
		}
	    }
	}
	return $allFoci
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
    
    # No need to do anything for update, because it updates itself
    proc reset {winId} {
    }
    
    proc display {args} {
    }
    
} ;# end of namespace

