# Go for closest thing to the old 'agroforestry' colours?
# tk_bisque
# No, it's horrible...

# First few procedures in here are utilities used by both the
# helper applications and the AME interface: put these in a new file.

package require BWidget

source ../Run/graphs.tcl
source ../Run/utility.tcl
source ../Run/hai2mmii.tcl

# botch -- mre.tcl has to be loaded after the other tcls or it doesn't
# work properly

source ../Run/mre.tcl

proc MakeHelperMenu {} {
    global custom
    set fm [menu .helpers -tearoff 0]

    $fm add command -label "Load" -command LoadView
    $fm add command -label "Save" -command SaveView
    $fm add command -label "Clear" -command ClearView
    $fm add command -label "Close" -command KillHelpers
    $fm add command -label "Parameters..." \
	-command {FileParamDialogue [GetNodeFromFocus] \
		      [winfo toplevel [focus]] 1}

    set oldDir [pwd]
    cd ../IOTools
    AddHelperSublist $fm "Add tool" 2
    set ioDir [file join $custom(prefDir) IOTools]
    if {[file exists $ioDir]} {
	cd $ioDir
	AddHelperSublist $fm.sub2 "Local" l
    }
    cd $oldDir
}

proc GetNodeFromFocus {} {
    global window_info helperTable
    set mHost [winfo toplevel [focus]]
    if {[info exists window_info($mHost.canvas,top_node)]} {
	return $window_info($mHost.canvas,top_node)
    } else {
#	do same thing for mre
#puts "mHost $mHost pairs [array get helperTable *,whichRunEnv]"
	foreach {inds val} [array get helperTable *,whichRunEnv] {
	    if {[string equal $val $mHost]} {
		return [string range $inds 0 end-12]
	    }
	}
    }
}

# OK I have been having problems with people duplicating IO tool programs
# and not changing the key values, thus allowing one to overwrite the other.
# So one day, IO tools will not include a namespace spec, but this code
# will load them into one, so they should still use [namespace code ...] to
# make callbacks.

proc AddHelperSublist {fm title ct} {
    global helperTable table_viewer
#puts "Adding helpers in [pwd]"
    set m [menu $fm.sub$ct -tearoff 0]
    set nct 0
    set helperList [glob -nocomplain *.tcl]
    foreach helperApp [lsort $helperList] {
        if [catch {source $helperApp} wibble] {
            # done at startup -- make sure dialog is not concealed
            wm withdraw .
            ShowMessage "Error loading I/O tool" warning \
                    "I/O tool [pwd]/$helperApp had a $::errorInfo" ok
        } else {
            if {[info exists keyValue]} {
                set action [${keyValue}::identify]
                if {[string match {Run control} $action]} {
                    set helperTable(RunControl) $keyValue
                }
                if {[string match {Explorer} $action]} {
                    set helperTable(VariableList) $keyValue ;# for MRE
                }
#                if {[string match {Slider control} $action]} {
#                    set helperTable(SliderControl) $keyValue
#                }
                if {[string match {Data table} $action]} {
                    set table_viewer(id) $keyValue
                }
                $m add command -label $action \
                        -command [list CreateHelperWindow $keyValue $action]
                unset keyValue
            }
        }
    }
    foreach subDir [glob -nocomplain *] {
        if [file isdirectory $subDir] {
            cd $subDir
            AddHelperSublist $m $subDir $nct
            cd ..
            incr nct
        }
    }
    if {[string equal none [$m index 0]]} {
	destroy $m
    } else {
	$fm add cascade -label $title -menu $m
    }
}

proc CreateHelperWindow {helperId helperTitle} {
    set winId [NewHelperWindow [GetNodeFromFocus] $helperId $helperTitle]
    ${helperId}::initialize $winId
    if {[PrefValue custom(helperManager) helperManager]} {
        ::RunEnv::ChildrenFocusParent $winId
    }
    return $winId
}

proc NewHelperWindow {node helperId helperTitle} {
    global helperTable tcl_platform

    # ShowMessage debug info "Making $helperId $helperTitle" ok
    if {[PrefValue custom(helperManager) helperManager]} {
        set winId [NewMreHelperWindow $node $helperId $helperTitle]
    } else {
        set winId .helper[newInt]
        toplevel $winId
        wm title $winId $helperTitle
        if {![string match windows $tcl_platform(platform)]} {
            wm iconbitmap $winId @../Images/weegraph.xbm
        }
        wm protocol $winId WM_DELETE_WINDOW "kill_helper_window $winId"
    }
    set helperTable($winId,whichHelper) $helperId
    set helperTable($winId,whichModel) $node
    return $winId
}

# If running a model which includes input parameters, we must
# make sure that these are somehow provided with inputs before
# trying to evaluate expressions in which they occur. This is
# done by creating a slider panel for them here.

# switch and switchd are binary inputs so should be set by
# toggles rather than sliders. Later...

#proc UnMakeSlidersForInputs { } {
#    global helperTable checkStates sliderVals
    # puts $inlist
#    if {[info exists helperTable(autosliders)]} {
#        kill_helper_window $helperTable(autosliders)
#        unset helperTable(autosliders)
#    }

#    if {[info exists checkStates]} {
#        unset checkStates
#    }
#    if {[info exists sliderVals]} {
#        unset sliderVals
#    }
#}

#proc MakeSlidersForInputs { } {
#    global helperTable
#    set helperTable(autosliders) [NewHelperWindow $helperTable(SliderControl) \
#            "Sliders for inputs"]
#   $helperTable(SliderControl)::initialize $helperTable(autosliders)
#}

# grab_clicks and release_clicks enable helper apps to ask
# the model to send mouse clicks to them while they are setting
# themselves up, or to the editor once they are done.

proc GrabClicks {winId} {
    global helperTable

    set topNode $helperTable($winId,whichModel)
    set helperTable($topNode,current) $winId
}

proc ReleaseClicks {winId} {
    global helperTable

    set topNode $helperTable($winId,whichModel)
    unset helperTable($topNode,current)
}

proc kill_helper_window { winId } {
    # ShowMessage debug info "Killing $winId" ok
    global helperTable runState sendvars
    if {[info exists helperTable($winId,whichHelper)]} {
	set topNode $helperTable($winId,whichModel)
	if {[info exists helperTable($topNode,current)]} {
	    if {[string compare $helperTable($topNode,current) $winId]==0} {
		unset helperTable($topNode,current)
	    }
        }
	if {[info exists runState($topNode,helperId)]} {
	    if {[string equal $winId $runState($topNode,helperId)]} {
		set sendvars($topNode,currentMode) kill
		unset runState($topNode,helperId)
	    }
	}
        unset helperTable($winId,whichHelper)
        destroy $winId
        #	if {[PrefValue custom(helperManager) helperManager]} {
        #	    RunEnv::OnDestroyHelper $winId
        #	}
        # ShowMessage debug info "Killed $winId" ok
    }
}

proc GetState {winId} {
    global helperTable
    return $helperTable($winId,status)
}

proc SetState {winId newState} {
    global helperTable
    set helperTable($winId,status) $newState
}

proc ProdObj {topNode nodeId caption} {
    global helperTable
    if {[info exists helperTable($topNode,current)]} {
	switch -regexp [GetCompProperty $topNode Type $nodeId] {
	    REAL|INTEGER|FLAG|ENUMERATED {
		set target $helperTable($topNode,current)
		
		set helperId $helperTable($target,whichHelper)
		${helperId}::click $target $nodeId $caption
	    } default {
		ShowMessage "Clicked on $caption" error \
                    "This component cannot be selected for an I/O tool because it has no associated value." ok
	    }
	}
	return 1
    } else {
	return 0
    }
}

# This is used for items on IO tool canvases -- model components have eqnpopups
proc CanvasBindPopup {canvas widget keywd} {
    $canvas bind $widget <Enter> [list QueuePopup AddWidgetPopup $keywd %X %Y]
    $canvas bind $widget <Leave> RemovePopup
}

# args are not used -- when binding to a table wigdet we cannot avoid getting
# the item name on the end of the call

proc Prettify {value} {
    if {[llength $value]==1} {
        return $value
    } else {

        set newValue {}
        while {[llength $value]} {
            lappend newValue [join [list [lindex $value 0] \
                    [Prettify [lindex $value 1]]] :]
            set value [lrange $value 2 end]
        }
        return $newValue
    }
}

proc DestroyHelpers {node} {
    if {[info exists helperTable($node,whichRunEnv)]} {
        ::RunEnv::Destroy $node
    } else {
        KillHelpers $node
    }
}

proc KillHelpers {node} {
    global helperTable
    foreach graphBox [array name helperTable *,whichHelper] {
        scan $graphBox {%[^,]} window
	if {[string equal $node $helperTable($window,whichModel)]} {
	    kill_helper_window $window
	}
    }
}

proc ClearView {} {
    global helperTable

    foreach displayBox [array name helperTable *,whichHelper] {
        scan $displayBox {%[^,]} winId
        set helperId $helperTable($displayBox)
        catch {${helperId}::clear $winId}; # in case helper has no clear proc
    }
}

#  nameOfHelperStateFile is global because helpers might want to save names of
# other files they need relative to it, e.g., file param helper

proc SaveView {} {
    global helperTable nameOfHelperStateFile

    set topNode [GetNodeFromFocus]
    set nameOfHelperStateFile($topNode) \
	[ChooseFile iotools.shf "Save view specification file" 1]
    if {[llength $nameOfHelperStateFile($topNode)]} {
        set stream [NetOpen $nameOfHelperStateFile($topNode) w]
        foreach displayBox [array name helperTable *,whichHelper] {
            scan $displayBox {%[^,]} winId
            set helperId $helperTable($displayBox)
            if {[string equal $topNode $helperTable($winId,whichModel)] && \
		    ![string match $helperId $helperTable(RunControl)]} {
                puts $stream $helperId
                # substitute <cr>s so entry goes on one line
                puts $stream [StripCrs [wm title $winId]]
                puts $stream [wm geometry $winId]
                set clickedPaths {}
                if {[info exists helperTable($winId,status)]} {
                    puts $stream [StripCrs $helperTable($winId,status)]
                } else {
                    puts $stream {}
                }
            }
        }
        close $stream
    }
}

proc LoadView {} {
    global helperTable nameOfHelperStateFile errorInfo
    set topNode [GetNodeFromFocus]
    set nameOfHelperStateFile($topNode) \
	[ChooseFile iotools.shf "Open view specification file" 0]
    if {[llength $nameOfHelperStateFile($topNode)]} {
	CreateView $topNode $nameOfHelperStateFile($topNode)
    }
}

proc CreateView {node nameOfHelperStateFile} {
    set stream [NetOpen $nameOfHelperStateFile r]
    while {[gets $stream helperId] >= 0} {
	if {[llength $helperId]==4} {
	    set response [ShowMessage {Inappropriate view specification} \
			      warning \
			      "This view specification file was created within the integrated Model Run \
                        Environment. Do you wish to launch a view-only version of MRE to view it?" \
			      yesnocancel]
	    switch $response {
		yes {
		    raise [Makemre $node]
		    RunEnv::LoadViewFile $stream $helperId
		} no {
		    LoadMREFormatView $stream
		} cancel {
		}
	    }
	    close $stream
	    return
	}
	gets $stream helperTitle
	set winId [NewHelperWindow $node $helperId [RestoreCrs $helperTitle]]
	gets $stream geometry
	wm geometry $winId $geometry
	gets $stream oldStatus
	set helperTable($winId,status) [RestoreCrs $oldStatus]
	if {[catch {${helperId}::Restore $winId}]} {
	    kill_helper_window $winId
	    ShowMessage "Problem restoring helper" warning $errorInfo ok
	}
    }
    close $stream
}

proc LoadMREFormatView {stream} {
    global helperTable
    while {[gets $stream helperId] >= 0} {
        if {[namespace exists $helperId]} {
            set helperTitle [${helperId}::identify]
            set winId [NewHelperWindow $node $helperId $helperTitle]
            gets $stream oldStatus
            set helperTable($winId,status) [RestoreCrs $oldStatus]
            ${helperId}::Restore $winId
        }
    }
}

proc TellAllHelpers {node fun args} {
    global helperTable

    foreach displayBox [array name helperTable *,whichHelper] {
        scan $displayBox {%[^,]} winId
	if {[string equal $node $helperTable($winId,whichModel)]} {
	    set helperId $helperTable($displayBox)
	    eval {${helperId}::$fun $winId} $args
	}
    }
}

proc ScrubRun {node times} {
    global runState model_id instance_id
    #    if {![string match ok [ShowMessage debug info Scrubbing okcancel]]} {
    #	error Bombed
    #    }
    set runState($node,modelRunning) 0
    if {$times && [info exists runState($node,currentTime)]} {
        unset runState($node,currentTime)
    }
    if {[info exists model_id($node)]} {
        if {$model_id($node)} {
            if {[info exists instance_id($node)]} {
                #ShowMessage debug info "Exiting $model_id $instance_id" ok
                do_for_node $node c_exitmodel $model_id($node) \
		    $instance_id($node)
                unset instance_id($node)
            } else {
                #ShowMessage debug info "Exiting $model_id 0" ok
                do_for_node $node c_exitmodel $model_id($node) 0
            }
        } else {
            if {[info exists instance_id($node)]} {
                #ShowMessage debug info "Exiting $model_id $instance_id" ok
		do_for_node $node namespace delete ::AME_model<>
                unset instance_id($node)
	    }
        }
        unset model_id($node)
	ToggleIOToolMenu $node
    }
}

############################## snap: start ###################################
proc snap {topNode node} {
    global runState
    
    if {[catch {GetCompProperty topNode Caption $node} full_label]} {
        return; ## no good
    }
    
    set w .snap[clock seconds]
    toplevel $w
    set last_slash [string last / $full_label]
    set start_label [expr $last_slash+1]
    set end_submodels [expr $last_slash-1]
    set submodels [string range $full_label 0 $end_submodels]
    set label [string range $full_label $start_label end]
    wm title $w "$label at time $runState($topNode,currentTime)"
    
    text $w.text -yscrollcommand "$w.yscroll set" -setgrid true \
            -xscrollcommand "$w.xscroll set" \
            -width 30 -height 20 -wrap none\
            -tabs {5c right 6.8c right 8.6c right 10.4c right}
    $w.text tag configure colour1 -background #ff9090 -foreground black
    $w.text tag configure colour2 -background #ffffff -foreground blue \
            -font {arial 10 bold}
    $w.text tag configure colour3 -font {arial 9 bold}
    $w.text tag configure colour4 -background #ffffff -foreground red \
            -font {arial 10 bold}
    scrollbar $w.yscroll -command "$w.text yview"
    pack $w.yscroll -side right -fill y
    scrollbar $w.xscroll -orient horiz -command "$w.text xview"
    pack $w.xscroll -side bottom -fill x
    pack $w.text -expand yes -fill both
    
    set values(1) [TransEnums [GetTransTable $node] \
		       [lindex [GetCompProperty $topNode Value $node] 0]]
    set length(1) [llength $values(1)]
    
    # Find number of levels of nesting
    for {set level 1} {$level<10} {incr level} {
        set nextlevel [expr $level+1]
        set values($nextlevel) [lindex $values($level) 1]
        set length($nextlevel) [llength $values($nextlevel)]
        if {$length($nextlevel)<=1} then {break}
    }
    set maxlevel $level
    
    $w.text insert end "Variable "
    $w.text insert end "$label\n" colour3
    if {[string length $submodels]>0} then {
        $w.text insert end "in submodel "
        $w.text insert end "$submodels\n" colour3
    }
    $w.text insert end "at time "
    $w.text insert end "$runState($topNode,currentTime)\n" colour3
    $w.text insert end "[clock format [clock seconds]]\n"
    $w.text insert end "Maxlevel=$maxlevel\n"
    if {$maxlevel==1} then {
        snap_down1 $w $values(1)
    } elseif {$maxlevel==2} then {
        snap_down2 $w $values(1)
    } else {
        snap_down3 $w $values(1)
    }
}


proc snap_down1 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            $w.text insert end $value colour2
        } else {
            $w.text insert end {   }
            $w.text insert end $value
            $w.text insert end \n
        }
        incr i
        if {$i==2} then {set i 0}
    }
}


proc snap_down2 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            $w.text insert end $value colour2
        } else {
            if {[llength $value]>1} then {
                $w.text insert end {    }
                set j 0
                foreach val $value {
                    if {$j==0} then {
                        $w.text insert end $val colour3
                    } else {
                        $w.text insert end { }
                        $w.text insert end $val
                        $w.text insert end {   }
                    }
                    incr j
                    if {$j==2} then {set j 0}
                }
                $w.text insert end \n
            } else {
                $w.text insert end {   }
                $w.text insert end $value
                $w.text insert end \n
            }
        }
        incr i
        if {$i==2} then {set i 0}
    }
}

proc snap_down3 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            set first_value $value
        } else {
            set j 0
            foreach val $value {
                if {$j==0} then {
                    $w.text insert end $first_value colour2
                    $w.text insert end {  }
                    $w.text insert end $val colour4
                    $w.text insert end {    }
                } else {
                    set k 0
                    foreach v $val {
                        if {$k==0} then {
                            $w.text insert end $v colour3
                        } else {
                            $w.text insert end { }
                            $w.text insert end $v
                            $w.text insert end {   }
                        }
                        incr k
                        if {$k==2} then {set k 0}
                    }
                    $w.text insert end \n
                }
                incr j
                if {$j==2} then {set j 0}
            }
        }
        incr i
        if {$i==2} then {
            $w.text insert end \n
            set i 0
        }
    }
}

proc GetRunParams {node} {
    global runState model_id

    if {[info exists runState($node,currentTime)]} {
	if {$runState($node,execTime) != $runState($node,currentTime)} {
	    set runState($node,execDur) \
		[expr $runState($node,execTime)+$runState($node,currentTime)]
	} else {
	    set runState($node,execDur) $runState($node,execTime)
	}
	set runParams [list execTime $runState($node,execDur) \
			   timeUnit $runState($node,timeUnit) \
			   displayInt $runState($node,displayInt) intMethod \
			   [set runState($node,oldIntMethod) $runState($node,intMethod)]]
	if {[info exists model_id($node)]} {
	    set runState($node,phases) [GetPhaseCount $node]
	    for {set phase 1} {$phase <= $runState($node,phases)} {incr phase} {
		lappend params $runState($node,update$phase)
                }
	    lappend runParams phaseList $params
	}
	return $runParams
    }
    return {}
}

proc SetRunParams {node runParams} {
    global runState
    
    set runState($node,currentTime) 0.0
    #ShowMessage debug info set ok
    if {[string match execTime [lindex $runParams 0]]} {
	# no longer as simple as "array set runState $runParams"
	foreach {feature value} $runParams {
	    set runState($node,$feature) $value
	}
	set runState($node,phases) 0
	if {[info exists runState($node,phaseList)]} {
	    foreach phase $runState($node,phaseList) {
		incr runState($node,phases)
		set runState($node,update$runState($node,phases)) $phase
		set runState($node,prev_update$runState($node,phases)) $phase
	    }
	}
	set runState($node,oldIntMethod) $runState($node,intMethod)
    } else {
	set runState($node,execTime) [lindex $runParams 0]
	set runState($node,displayInt) [lindex $runParams 1]
	for {set others 2} {$others < [llength $runParams]} {incr others} {
	    set runState($node,update[expr $others-1]) [lindex $runParams $others]
	    set runState($node,prev_update[expr $others-1]) \
		[lindex $runParams $others]
	}
	set runState($node,phases) [expr $others-2]
	set runState($node,timeUnit) day
	set runState($node,intMethod) Euler
    }
    #puts [array get runState]
}

# modelRunning is a global variable that indicates the status of the model
# program: 0 = none, 1 = awaiting fixed params, 2 = up to date, 3 = out of date

proc StartRun {node} {
    global runState helperTable running_c
    # ShowMessage debug info enter(start_run) ok
    if {[info exists runState($node,currentTime)]} {
        if {$runState($node,execTime) != $runState($node,currentTime)} {
            set runState($node,execTime) [expr $runState($node,execTime) + \
					      $runState($node,currentTime)]
        }
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            if {![info exists runState($node,prev_update$phase)]} {
                set runState($node,update$phase) 0.1
                set runState($node,prev_update$phase) 0.1
            }
            SetStep $node $runState($node,prev_update$phase) $phase
        }
    } else {
        set runState($node,execTime) 100
        set runState($node,displayInt) 1
        for {set phase 1} {$phase <= [GetPhaseCount $node]} {incr phase} {
            set runState($node,update$phase) 0.1
	    set runState($node,time$phase) 0
            set runState($node,prev_update$phase) 0.1
            SetStep $node 0.1 $phase
	    SetStep $node 0 -$phase
        }
    }

    set runState($node,currentTime) 0.0
    set runState($node,timeAtEval) 0.0
#    set runState($node,currentWin) $winId ;# enables rebuild from run control
    if {![FileParamDialogue $node [winfo toplevel [focus]] 0]} {
	return 0
    }
    if {[PrefValue custom(helperManager) helperManager]} {
        #    ShowMessage debug info "About to make MRE [array name window_info *,parent]" ok
        raise [set topWin [Makemre $node]]
    }
#    Now have to do this in Prolog so only running windows change
#    foreach winData [array name window_info *,parent] {
#        set toolBar $window_info($winData).toolSlot.toolbar
#        $toolBar.snap configure -state active
#        set navBar $window_info($winData).toolSlot.navbar
#        $navBar.runenv configure -state active
#        $window_info($winData)top.tools entryconfigure {Inspect elements} -state active
#    }
    set runState($node,reloadParams) 1
    set runState($node,modelRunning) 2
#    EnableTools Fix

    # MakeSlidersForInputs is currently done after initializing the
    # model, so default values calculated from eqns can be loaded to the
    # sliders. Here we must clear any old input tool values so they are not used.
#    UnMakeSlidersForInputs

    if {![info exists runState($node,helperId)]} {
	set defHelper $helperTable(RunControl)
    
#    if {[regexp "(.helper\[0-9\]+),whichHelper $defHelper" \
#                [array get helperTable] spare helperId]} {
#       kill_helper_window $helperId
#   }
	set helperId [NewHelperWindow $node $defHelper "Default run control"]
	${defHelper}::initialize $helperId
	set runState($node,helperId) $helperId
    }
# Do not put up mre, sliders, etc if model has failed to start
#    if {![info exists running_c]} {
#	return
#    }

# remake notebook page for sliders if earlier deleted
#    if {[PrefValue custom(helperManager) helperManager]} {
#	set sliderBook ${::RunEnv::explorerPane}.notebook
#	if {![info exists ::RunEnv::sliderControlFrame]} {
#	    $sliderBook insert end "InputSliders" -text "Input sliders"
#	    pack [set ::RunEnv::sliderControlFrame [frame [$sliderBook getframe "InputSliders"].sliders]] -fill both -expand yes
#	    $sliderBook raise InputSliders
#	}
#    }

#    MakeSlidersForInputs
    
    if {[PrefValue custom(helperManager) helperManager]} {
	set helperId $helperTable(VariableList)
	set winId [NewHelperWindow $node $helperId "Variables"]
	${helperId}::initialize $winId
        ::RunEnv::ChildrenFocusParent $winId
#	if {![winfo exists $helperTable(autosliders)]} {
# No sliders in model, so delete notebook page
#	    $sliderBook delete InputSliders
#	    $sliderBook raise Explorer
#	    unset ::RunEnv::sliderControlFrame
#	}
	set ctrlPane [winfo parent [winfo parent [winfo parent [winfo parent \
					$::RunEnv::runControlFrame($node)]]]]
	update ;# so reqheight works next
	$ctrlPane sash place 0 \
	    10 [expr [winfo reqheight $ctrlPane.runcontrolPane]+10]
    }
# Now list all the inputs in the model, so we can avoid running it until
# all have tools attached to provide their values
#    if {[info exists inputHelper]} {
#	array set oldInputHelper [array get inputHelper]
#	unset inputHelper
#    }
#    foreach node [GetObjectList] {
#	if {[string match TABLE [GetModelEval $node]]} {
#	    set name [GetCaptionPathFromId $node]
#	    if {[info exists oldInputHelper($name)]} {
#		set inputHelper($name) $oldInputHelper($name)
#		unset oldInputHelper($name)
#	    } else {
#		set inputHelper($name) {}
#	    }
#	}
#    }
#    foreach removedInput [array names oldInputHelper] {
#	TellHelperItsGone $oldInputHelper($removedInput) $removedInput
#    }
#    CheckFixedParamState
    set widget [$runState($node,helperId).rcf getframe]
    $widget.topbuttons.reset invoke
    return 1
}

proc StartNow {node} {
    global runState

    set widget [$runState($node,helperId).rcf getframe]
    $widget.topbuttons.start invoke
}

proc TellHelperItsGone {helperWin captionPath} {
# for compatibility, call a helper proc and if the helper doesn't have it
# delete it
}

#proc CheckFixedParamState {node} {
#    global inputHelper runState
#    if {$runState($node,modelRunning)==1 && \
#	    [lsearch [array get inputHelper] {}] == -1} { 
#	# fixed param with no src
#	set runState($node,modelRunning) 2
#	# this initializes the model
#        set widget [$runState($node,helperId).rcf getframe]
#        $widget.topbuttons.reset invoke
#	EnableTools IO
#    }
#}

proc EnableTools {group} {
    set tgt .helpers.sub2
    for {set entry 0} {$entry <= [$tgt index last]} {incr entry} {
	set text [$tgt entrycget $entry -label]
	if {[string match Fix $group]==[string match {Set fixed parameters...} $text]} {
	    $tgt entryconfigure $entry -state normal
	} else {
	    $tgt entryconfigure $entry -state disabled
	}
    }
}

# this gets rid of a c program that has been loaded into
# the interpreter, to allow a new one to replace it --
# loadmodel with no args unloads model (this crashes Windows)

proc remove_c_model {} {
    # The following is not done cos it removes the stub as well
    #    package forget ame_dll
    #
    #    foreach c_command {c_resetmodel c_evalmodel c_updatemodel c_exitmodel \
    #	    getvalue getnodeid listobjects} {
    #	rename $c_command {}
    #    }
}

proc update_executable {node lang} {
    #    ShowMessage debug info "References are $finderList" ok
    global model_id instance_id

    # For the toplevel model, make an instance. This will also make
    # instances of any fixed-membership submodels immediately, so they had
    # better already be loaded
    switch $lang {
	c {
	    set instance_id($node) [do_for_node $node c_createmodel \
					$model_id($node)]
	} tcl {
    #    ShowMessage debug info "model instance $instance_id created" ok
	    set model_id($node) 0
	    set instance_id($node) 0
	}
    }
    return [StartRun $node]
}

# load_dll adds a dll to the system. Trees are added bottom up, so model_id
# is always that most recently added (even if not recompiled)

proc load_dll {topNode lang progDir id node incs} {
    #   phasecount and nodedata are set in generated code
    global model_id model_ids model_prog env
    if {[string match tcl $lang]} {
	if {![file exists $progDir/model.tcl]} {
	    return 0
	}
	# This won't catch defns in subdirectories
        foreach fnFile [glob -nocomplain "../Functions/*.tcl"] {
            do_for_node $topNode source $fnFile
        }
        foreach fnFile $incs {
            do_for_node $topNode source $fnFile
        }
        set model_prog($topNode) $progDir/model.tcl
	do_for_node $topNode source $model_prog($topNode)
	if {![catch {do_for_node $topNode set simile_version} buildV]} {
	    return [expr $buildV==$env(SIMILE_VERSION)]
        } else {
            return 0
        }
    } else {
	set progFile $progDir/model${id}[info sharedlibextension]
	if {![file exists $progFile]} {
	    return 0
	}
        if {[catch {do_for_node $topNode loadmodel $progFile $node} \
		 new_model_id]} {
	    if {[PrefValue custom(hackBreak) hackBreak]} {
		ShowMessage {Loading model dll} info "Failed to load the compiled model program. The operating system returned the following message: $new_model_id -- the program will attempt to build another one." ok
	    }
            return 0
        }
	set model_id($topNode) $new_model_id
        #        set model_id [loadmodel $nameBase[info sharedlibextension] $node]
        set model_ids($node) $new_model_id
        return $new_model_id
    }
}

proc set_connections {connects} {
    global model_id model_ids instance_id
# Run is always scrubbed, this should not need to
    # ShowMessage debug info "Trimming..." ok
#    if {[info exists instance_id]} {
#        c_exitmodel $model_id $instance_id
#        unset instance_id
#        unset model_ids
#    }
    #ShowMessage debug info "About to load: $connects" ok
    set_connection_database $connects
    #ShowMessage debug info "...loaded." ok
    #   now...dont set running_c till instance made -- use model_id till then
    #    set running_c 1
}

# FindPhase tells us when a node in a separate submodel will be
# available. The submodel indicates this by its eval phase. If DERIVED, INPUT
# or TABLE it can be used any time; if EXOGENOUS we must wait till that
# submodel has been called. If it is in a nested submodel, then it is
# usable after the phase in which the submodel is executed, or after
# its own phase if that is SPLIT. -1 means node not found.

# Note that because the top level model dll may not yet be loaded, we have
# to set model_id to the model we are searching in (model_ids keeps track of
# dlls loaded so far)

proc FindPhase {node submodel} {
    global model_id model_ids

    set model_id $model_ids($submodel)
    foreach subnode [listobjects $model_id] {
        set subtype [lindex {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST} \
			 [get_value $model_id $subnode 2]]
        if {[string match $node $subnode]} {
            if {[string match EXOGENOUS $subtype]} {
                return 1
            } else {
                return 0
            }
        }
        if {[get_value $model_id $subnode 1]==4} { ;# EXTERNAL
            lappend subs [list $subnode $subtype]
        }
    }
    foreach nodeTypePair $subs {
        set subFind [FindPhase $node [lindex $subs 0]]

        if {$subFind != -1} {
            switch [lindex $subs 1] {
                EXOGENOUS {
                    return 1
                } DERIVED {
                    return 0
                } SPLIT {
                    return $subFind
                }
            }
        }
    }
    return -1
}

proc compile_c {workingDir} {
    global tcl_platform env

    if {[PrefValue custom(hackBreak) hackBreak]} {
        ShowMessage {Code editing opportunity} info \
                "About to compile model.cpp in $workingDir" ok
    }
    set oldDir [pwd]
    cd $workingDir
# get a so far unused file name
    set serial [newInt]
    set TARGET model${serial}[info sharedlibextension]
    while {[file exists $TARGET]} {
	set serial [newInt]
	set TARGET model${serial}[info sharedlibextension]
    }
    set TOOLDIR $oldDir/../Run
    set TCL [file dirname [file dirname [info library]]]
    #ShowMessage debug info "TCL is $TCL, TOOLDIR is $TOOLDIR" ok
    scan [info tclversion] {%d.%d} MAJ MIN
    if {[catch {switch $tcl_platform(platform) {
        unix {
            if {[string match Darwin $tcl_platform(os)]} {
                exec g++ -fPIC -c -O -I$TOOLDIR -o objtemp.o model.cpp
                exec g++ -dynamiclib -o $TARGET objtemp.o
            } else {
                exec g++ -fPIC -c -O -I$TOOLDIR -o objtemp.o model.cpp
                exec g++ -shared -o $TARGET objtemp.o
            }
        }
        windows {
            set TOOLDIR [file attributes $TOOLDIR -shortname]
            if {[string match GNU [PrefValue custom(compChoice) compChoice]]} {
                set dll ame_dll${MAJ}${MIN}
                switch $tcl_platform(os) {
                    {Windows NT} {
                        exec cmd /c start /min g++ -c -o objtemp.o -I$TOOLDIR -I. model.cpp
                        exec cmd /c start /min dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtemp.o
                    }
                    {Windows 95} {
                        exec start /m g++ -c -o objtemp.o -I$TOOLDIR -I. model.cpp
                        exec start /m dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtemp.o
                    }
                }
                file delete exptemp.exp

                # Method using command line calls to MSVC 4.0 or later -- works well
            } else {
                set TOOLS32 [file dirname $env(MSVCDIR)/any]
                exec $TOOLS32/bin/cl.exe -Ox -c -W3 -nologo \
                        -DWIN32 -D_WIN32 -D_DLL -D_X86_=1 \
                        -I. -I$TOOLS32/include -I$TOOLDIR \
                        -Foobjtemp.o model.cpp
                exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO \
                        -align:0x1000 /MACHINE:IX86 \
                        -entry:_DllMainCRTStartup@12 -dll -out:$TARGET \
                        $TOOLDIR/../System/lib/Stubs/ame_dll${MAJ}${MIN}.lib \
                        $TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib \
                        $TOOLS32/lib/oldnames.lib objtemp.o
            }
            # Method using command line calls to Borland C++ 4.0 or later -- not finished

            #	set TOOLS32 "c:/program files/borland/cbuilder4"
            #	exec $TOOLS32/bin/bcc32.exe -Ox -c -nologo -o$object \
            #		-DWIN32 -D_WIN32 -D_DLL -D_X86_=1 -DMODELCODE="$c_prog" \
            #		-I. -I$TOOLS32/include -I$TCL/include $TOOLDIR/support.cpp



            #	exec $TOOLS32/bin/ilink32.exe -Tpd $object $TARGET $TCL/lib/tcl${MAJ}${MIN}.lib
            # Method using MSVC's auto-generated Make file -- hangs for some
            # reason

            #	exec $TOOLS32/bin/nmake $TOOLDIR/amemodel/amemodel.mak
            #	file rename $TOOLDIR/amemodel/debug/amemodel.dll $TARGET

        }
    }} chuckup]} {
	set badCompile "The compiler raised a problem with the code generated for this model. This might be due to a bad compiler setup, or it could be due to mathematical problems in the model. The error was: $chuckup. It may help to try running the model in Tcl."
	BuildProblem none none $badCompile user
	set serial -1
    } else {
    #    file delete $c_prog
	file delete objtemp.o
    }
    # do not allow an old dcf to be saved with a new model
    cd $oldDir
    return $serial
}

proc ListSameNumbers {list1 list2} {
    set target [llength $list1]
    if {$target != [llength $list2]} {return 0}
    for {set count 0} {$count < $target} {incr count} {
        if {[lindex $list1 $count] != [lindex $list2 $count]} {return 0}
    }
    return 1
}

# procedures to handle graph data

#proc insert_graph_data {graph_data_pointer xlow xhigh xspan ylow yhigh yspan \
\#            xsize array_data} {
 #   variable graphdata
 #   set $graph_data_pointer [format "%f %f %d %f %f %d %d %s" \
 \#           $xlow $xhigh $xspan $ylow $yhigh $yspan $xsize $array_data]
#}


proc SampleFrom {a} {
    if {[llength $a] == 1} {
        return $a
    } else {
        array set fun $a
        foreach index [array names fun] {
            set b [SampleFrom $fun($index)]
            if {$b} {
                return $b
            }
        }
        return 0
    }
}

proc IsArray {a} {
    string compare $a [lindex $a 0]
}

set intCount 0

proc newInt {} {
    global intCount
    return [incr intCount]
}

# Ultra crappy random alg now replaced by c library version

#set randfoob [expr exp(-1)]
#proc random01 {} {
#	global randfoob
#	return [set randfoob [expr fmod(1/$randfoob,1)]]
#}

proc ModelDirectory {} {
    global custom
    return [file dirname [lindex $custom(hotlist) 0]]
}

