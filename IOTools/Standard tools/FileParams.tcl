set keyValue fileparams7836

namespace eval $keyValue {

    proc identify {} {
	return "File parameter editor"
    }

    proc initialize {t} {
	set toolbarItems [list \
			      [list add.gif "Add a variable" \
				   [namespace code "AddVariable $t"]]]
	
	::graphtools::MakeToolBar $t $toolbarItems
	
	#wm title $t "Enter file parameters"
	set needed {}
	MakeFrames $t

        pack [set bfrm [frame $t.buttons ]] \
	-fill x
        pack [message $bfrm.banner \
                -text "All values must be set to run the model." -width 400]
        pack [frame $bfrm.lpad] -side left -fill x -expand true
        pack [button $bfrm.ok -text "OK" \
		  -command [namespace code [list OK $t $needed]] -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.merge -text "Load file" -command MergeParams -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.save -text "Save file" -command SaveParams -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.help -text "Help" -command {ContextSensitiveHelp $t data/index.htm} -width 10] \
                -side left -padx 2 -pady 2
        pack [frame $bfrm.rpad] -side left -fill x -expand true
        raise $t
    }

proc SaveState {winId} {
    global paramState paramData widgetNames nameOfHelperStateFile
    
    set state editing
    foreach compName [array names widgetNames] {
	set node [GetIdFromCaptionPath $compName]
	if {[string match normal [$widgetNames($compName) cget -state]]} {
	    set paramData($compName) [$widgetNames($compName) get 1.0 1.end]
	    
	    if {[info exists paramState($compName)]} {
		if {[string compare $paramData($compName) \
			 [LoadTableData $paramState($compName) 0]]} {
		    unset paramState($compName)
		}
	    }
	}
	set SubbedComp [StripCrs $compName]
	if {[info exists paramState($compName)]} {
	    set relName [Relativize $nameOfHelperStateFile \
			     [lindex $paramState($compName) 0]]
	    lappend state "$SubbedComp=[lreplace $paramState($compName) \
                            0 0 $relName]"
	} else {
	    lappend state "$SubbedComp=$paramData($compName)"
	}
    }
    SetState $winId $state
}

    proc Restore {winId} {
    global paramState paramData widgetNames nameOfHelperStateFile
	set state [GetState $winId]
    
    set oldDir [pwd]
	initialize $winId
	foreach savedValue [lrange $state 1 end] {
	    #ShowMessage debug info "Restoring $savedValue" ok
            set IdAndValue [split $savedValue =]
            set restoredComp [RestoreCrs [lindex $IdAndValue 0]]
            #ShowMessage debug info "Component is $restoredComp, looking in [winfo children .fpdialogue.sliderframe]" ok
	    set node [GetIdFromCaptionPath $restoredComp]
	    AddEntry $winId $node

	    set paramData($restoredComp) [lindex $IdAndValue 1]
                #ShowMessage debug info "Param data is $paramData($restoredComp)" ok
	    set FileOrVal [lindex $paramData($restoredComp) 0]
                
                # OK here we go...try and follow this...first go to the starting point..
	    cd [file dirname $nameOfHelperStateFile]
	    if {[file exists $FileOrVal]} {
                    # Now use the saved relative path to move to the .csv file's directory
		cd [file dirname $FileOrVal]
                    # ...and stick the new absolute pathname into the spec! Easy!!
		set paramState($restoredComp) \
		    [concat [list [pwd]/[file tail $FileOrVal]] \
			 [lrange $paramData($restoredComp) 1 end]]
                    # now just load up the data
                    #ShowMessage debug info "Field spec set to $paramState($restoredComp)" ok
		set paramData($restoredComp) \
		    [LoadTableData $paramState($restoredComp) 0]
	    } elseif {![SensibleValue $FileOrVal]} {
		set paramData($restoredComp) {}
		ShowMessage "Error merging parameters" error "Parameterization file contained the entry $FileOrVal for component $restoredComp. This entry is not the name of an existing file, nor is it a sensible value for a Simile component." ok
	    }
	    FillIfSmall $widgetNames($restoredComp) $paramData($restoredComp)
        }
	cd $oldDir
    }

    proc reset {winId} {
    }

    proc AddVariable {winId} {
	$winId.buttons.banner configure -text "Click on a fixed parameter component in the explorer window or model diagram."
	GrabClicks $winId
    }

    proc click {winId node caption} {

        if {[string match TABLE [GetModelEval $node]]} {
	    ReleaseClicks $winId
	    $winId.buttons.banner configure -text {};# leave empty if add fails
	    AddEntry $winId $node
	    $winId.buttons.banner configure -text "Be sure to enter values for this parameter."
        }
    }    

proc 	    AddEntry {winId node} {
    global paramData widgetNames
    set compName [GetCaptionPathFromId $node]
    set levels [lrange [split $compName /] 1 end]
    set nodeDims [GetModelDims $node]
    while {[set sep [lsearch $nodeDims -1]]>-1} {
	set nodeDims [lreplace $nodeDims $sep $sep]
    }
# bit of voodoo...get table relating numerical indices of node to enymerated
# types (from prolog) and use to translate array bounds
    set trans [GetFromProlog tk_get_info('$winId',$node,types)]
#ShowMessage debug info "$node $trans $nodeDims" ok
    set nodeDims [TransBounds $trans $nodeDims]
    set dimList [join [lrange $nodeDims 0 end-1] { x }]
    set last [lindex $nodeDims end]
    if {[string compare $last 0]} {
	if {[llength $dimList]} {
	    append dimList " of $last"
	} else {
	    set dimList "a $last"
	}
    }
    if {[string length $dimList]} {
	set slotCaption "[lindex $levels end] ($dimList):"
    } else {
	set slotCaption [lindex $levels end]
    }
    pack [set slot [frame [MakeSubFrames $winId.sliderframe $levels]]] -fill x -expand on
    pack [label $slot.l -text $slotCaption] -side left
    if {$nodeDims>1} {
	pack [button $slot.b -text "Read table" \
		  -command [list GetFromTable $winId $compName]] -side right
    }
    
            #	    pack [entry $slot.e -textvariable paramData($compName)]
            # Using entries played merry hell with very long arrays -- texts work better
    pack [text $slot.e -width 30 -height 1] -side right \
	-fill x -expand on
    if {[info exists paramData($compName)]} {
	FillIfSmall $slot.e $paramData($compName)
    } else {
	set paramData($compName) {}
    }
    set widgetNames($compName) $slot.e
    
            # note whether we need to enter a parameter here...
    if {![llength $paramData($compName)]} {
	lappend needed $compName
    }
}

proc OK {winId oldMissing} {
    global paramData widgetNames runState running_c inputHelper
    
    foreach compName [array names widgetNames] {
	set node [GetIdFromCaptionPath $compName]
	    if {[string match normal [$widgetNames($compName) cget -state]]} {
	       set paramData($compName) [$widgetNames($compName) get 1.0 1.end]
	    }
            #ShowMessage debug info "-paramData($compName)- is -$paramData($compName)-" ok
	    set dataChanged 0
	    if {![llength $paramData($compName)]} {
		set empties 1
		# for each constant value, check whether it has been changed, and if so,
		# flag a complete model rebuild. Do same if running_c lost due to crash
	    } elseif {[lsearch $oldMissing $compName] > -1} {
		set dataChanged 1
	    } elseif {![info exists running_c]} {
		set dataChanged 1
	    } elseif {[string compare [lindex [GetModelValue $node] 0] \
			   $paramData($compName)]} {
		set dataChanged 1
	    }
	    # Make array form if data has changed
	    if {$dataChanged} {
		set runState(reloadParams) 1
		set trans [GetFromProlog tk_get_info({},$node,types)]
		ListToArray $node $trans $paramData($compName)
# new bit for using it as an input tool: notify that we have values
		set inputHelper($compName) winId
	    }
    }
    if {[info exists empties]} {
	$winId.buttons.banner configure -text "Some values still missing!"
    } else {
	set paramData(/done/) 1
# new bit for using it as an input tool: notify that we have values
	CheckFixedParamState
    }
    SaveState $winId
}

    proc display {winId time display remainder} {
    }
    
} ;# end of namespace

