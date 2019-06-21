# Simile source code file: Run/params.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for reading and editing tables of data at run-time.
#

proc FileParamDialogue {topNode topWin mustShow} {
    global paramData widgetNames myNode

    set topCapt [GetExecTitle $topNode]
    set allNodes [GetCompProperty $topNode Objects]
    # first check for any parameter values that are no longer needed
    # do it now to shake out errors before opening window
    set ::bermudaTriangle {}
    foreach curVal [array names paramData /$topNode/*] {
        if {[llength $paramData($curVal)]} {
	    set shortVal [TrimDTFromPath $curVal]
            set hitsPath [lindex [ExistCheck $topNode $shortVal /$topNode 0 \
				      "current database"] 0]
            switch $hitsPath {
                break {
		    return 0
                } continue {
                    unset paramData($curVal)
                } default {
		    if {![string equal $shortVal $hitsPath]} {
			set newPath /$topNode$hitsPath
			set paramData($newPath) $paramData($curVal)
			unset paramData($curVal)
		    }
		}
            }
        } else {
	    unset paramData($curVal)
	}
    }
    set t [PutItThere .fpdialogue $topWin]
    wm protocol .fpdialogue WM_DELETE_WINDOW CancelParams
    wm title $t [format [tr. {File parameters for "%1$s"}] $topCapt]
    if {!$mustShow} {
        set paramData(needed) {}
    }
    DIYMakeFrames $t
    set useCppArray [RunningInC $topNode]
    set ::helperTable($topNode,paramAble) disabled
    foreach node $allNodes {
        set notInput [FirstIndexCheck $topNode $node]
        if {$notInput != -1} {
	    set ::helperTable($topNode,paramAble) normal
            AddEntry $t $topNode $node $mustShow $notInput
        }
    }
    if {$mustShow || [llength $paramData(needed)]} {
        pack [set bfrm [frame .fpdialogue.buttons ]] -fill x
        pack [label $bfrm.banner -fg red -text [tr. "All values with red captions must be set to run the model."]]
        pack [frame $bfrm.lpad] -side left -fill x -expand true
	pack [button $bfrm.ok -text [tr. OK] \
                -command [list DoneParams $topNode] -width 10] \
                -side left -padx 2 -pady 2
		    pack [button $bfrm.cancel -text [tr. Cancel] -command CancelParams -width 10] \
                -side left -padx 2 -pady 2
	# next two now available for every submodel level
        #        pack [button $bfrm.merge -text "Load file" -command MergeParams -width 10] \
        -side left -padx 2 -pady 2
        #        pack [button $bfrm.save -text "Save file" -command SaveParams -width 10] \
        -side left -padx 2 -pady 2
		    pack [button $bfrm.help -text [tr. Help] -command {ContextSensitiveHelp .fpdialogue data/index.htm} -width 10] \
                -side left -padx 2 -pady 2
        pack [frame $bfrm.rpad] -side left -fill x -expand true
        raise .fpdialogue
        set paramData(complete) 0
        LetItShow $t paramData(done)
        
    } else {
        # Dialogue not needed because data OK so return good
        set paramData(done) 1
    }
    array unset widgetNames
    PackItUp $t
    return $paramData(done)
}

# ScrolledWindow and ScrollableFrame allow any widget to be scrolled,
# but need the bwidget package. So have revived our own version based
# on a frame in a canvas (see below). However, the ScrollableFrame
# supports the 'see' command which allows it to be automatically
# scrolled to show a particular sub-widget, while the canvas version
# would need a lot of pi^H^Hmessing about with yview to achieve
# this. So hang on to bwidget for the time being. On the other hand, widget
# traversal is buggy in BWidget, so unless actually using 'see', choose the
# DIY version.

# Note that in neither case does BindMouseWheel do anything useful, because
# for some reason the subframes stop the event getting to the top frame or
# canvas. However, style::as will do the job provided you do not pack anything
# -in anything...
# 
# proc MakeFrames {windowId} {
#     ScrolledWindow $windowId.c
#     set canId [ScrollableFrame $windowId.c.canvas -constrainedwidth true]
#     $windowId.c setwidget $canId
# 
#     pack $windowId.c -side top -fill both -expand true
#     return [$canId getframe]
# }
# 
proc DIYMakeFrames {windowId} {
    frame $windowId.c
    set canId [canvas $windowId.c.canvas \
		   -yscrollcommand [list $windowId.c.yscroll set]]
    pack [scrollbar $windowId.c.yscroll -orient vertical \
	      -command [list $canId yview]] -side right -fill y
    pack $canId -fill both -expand 1
    pack $windowId.c -side top -fill both -expand 1
    set sf [$canId create window 0 0 -anchor nw \
		-window [frame $canId.frame]]
    bind $canId <Configure> [list $canId itemconfigure $sf -width %w]
    bind $canId.frame <Configure> \
	[list $canId configure -scrollregion {0 0 %w %h}]
    return $canId.frame
}

# with a normal scrollable widget you can 'see' an embedded widget, but this 
# does not work on canvas. So here we do it in a roundabout way...

proc ScrollToSee {canvas w} {
    set current [winfo rooty $w]
    set goesTo [winfo rooty $canvas]
    set cbox [$canvas cget -scrollregion]
    set height [expr {0.0+[lindex $cbox 3]-[lindex $cbox 1]}] ;# make float
    set move [expr {($current-$goesTo)/$height}] ;# +ve move makes rooty lower
    set start [lindex [$canvas yview] 0]
    $canvas yview moveto [expr {$start+$move}]
#puts "current $current goesTo $goesTo cbox $cbox height $height move $move start $start"
}

proc AddEntry {winId topNode node mustShow notInput} {
    global iconImages msgs paramMetadata readMany
    if {$notInput==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames

    set compName [GetCompProperty $topNode Caption $node]
    set levels [split $compName /]
    if {$notInput>-1} {
	set compName /$topNode$compName
	set levels [concat $topNode [lrange $levels 1 end]]
	set readMany($compName) [expr {$notInput==0}]
    } ;# otherwise it has been set by the PEST interface GUI
    set compClass [GetCompProperty $topNode Class $node]
    if {$compClass eq "SUBMODEL"} {
        set suppliedData($compName) {}
        return
    }
	
#ShowMess debug info "Creating compname $compName" ok
    # bit of voodoo...get table relating numerical indices of node to enumerated
    # types (from model) and use to translate array bounds. Do this first because
    # there will be null entries in the table for vm model levels.
    set nodeDims [GetCompProperty $topNode Dims $node]
    set trans [GetCompProperty $topNode Trans $node]
    if {$readMany($compName)} {
        set nodeDims [linsert $nodeDims 0 TIME]
        set trans [linsert $trans 0 {}]
    }
	
    set origDims [llength $nodeDims]
    set nodeDims [RemoveVMLevels $nodeDims]
    if {$notInput==-1 && [llength $nodeDims]<$origDims} {
	return "This value has variable dimensions, and therefore cannot be optimized by parameter estimation."
    }
    
    #ShowMess debug info "$node $trans $nodeDims" ok
    set nodeDims [TransBounds $trans $nodeDims]
    
    set dimList [MakeDimsLegible $nodeDims \
		     [GetCompProperty $topNode Type $node]]
    set topFrame $winId.c.canvas.frame
    set slot [frame [AddSubFrames $topNode $topNode $topFrame $levels \
			 fileparams 0]]
    set holder [winfo parent $slot]
# holder always contains header frame, which is packed at top
    foreach fellow [pack slaves $holder] {
	if {[string compare -nocase $fellow $slot]<0} {
	    break
	}
    }
    set lbg [$holder.head cget -bg]
    $slot configure -bg $lbg

    pack $slot -before $fellow -side bottom -fill x -expand on
    raise $slot $fellow ;# for keyboard traversal
    pack [label $slot.caption -text [lindex $levels end] -foreground red \
	      -background $lbg] -side left
#    pack [label $slot.l2 -text ($dimList) -fg red] -side left
    set paramMetadata($compName,dimList) $dimList
    if {![info exists msgs(param_source_$compName)]} {
        set msgs(param_source_$compName) [tr. Unsaved]
	set paramMetadata($compName,saveReference) 0
    }
    if {![info exists msgs(comment_$compName)]} {
        set msgs(comment_$compName) $msgs(ncfv)
    }
    #Show description and comments
    ParamLabelPopup $slot.caption $node [lindex $levels end]
            
    #       pack [entry $slot.e -textvariable paramData($compName)]
    # Using entries played merry hell with very long arrays -- texts work better
    pack [::ttk::entry $slot.e -width 1] -side left -fill x -expand on
    BindPopup $slot.e param_source_$compName comment_$compName
    bind $slot.e <Return> [list $slot.tick invoke]
    KoreanClick $slot.e 1 {}
    bind $slot.e <Double-1> [list EditValueComment $topFrame $compName]

    ::ttk::button $slot.tick -style style$holder \
	-image $iconImages(tick) \
	-command [namespace code [list AcceptData $topNode $compName \
				      $notInput 1]]
    BindPopup $slot.tick [tr. "Accept these values"]
    FixDisabledImgBug $slot.tick
    ::ttk::button $slot.cross -style style$holder \
	-image $iconImages(cross) \
	-command [namespace code [list RevertData $winId $compName \
				      $notInput]]
    BindPopup $slot.cross [tr. "Revert to old values"]
    FixDisabledImgBug $slot.cross

    if {[info exists suppliedData($compName)]} {
        FillIfSmall $slot.e $suppliedData($compName)
    } else {
        set suppliedData($compName) {}
	AbleHandEditControls $slot ;# they are not packed yet
    }

    if {[llength $nodeDims]>1} {
# T   nI   rM
# r   -1    0
# m   -1    1
# f    1    0
# c    0    1
# d    0    1    EVT
	set dlgStyle [lindex {result measure discrete continuous fixed} \
			  [expr {2*$notInput+$readMany($compName) \
				 -($compClass eq "EVENT")+2}]]
	::ttk::button $slot.b -style style$holder -image $iconImages(edit) \
	    -command [namespace code [list GetFromTable $winId $topNode \
					  $compName $trans $dlgStyle]]
	BindPopup $slot.b [tr. "Get values from file"]
	pack $slot.b -side right
	FixDisabledImgBug $slot.b
    }
    set outNames($compName) $slot
    GrowCaptionsTo $holder
    # note whether we need to enter a parameter here...
    if {$mustShow} {
        if {[lsearch $suppliedData(needed) $compName]==-1} {
            ColourCaptions $slot black
        }
    } else {
        AcceptData $topNode $compName $notInput 0
    }
}

proc GrowCaptionsTo {sm} {
    # horrible hack to grow all labels to the same size, should use grid instead
    set newWidth 48 ;# min width
    foreach widg [winfo children $sm] {
	set lab $widg.caption
	if {[winfo exists $lab]} {
	    lappend mob $lab
	    $lab configure -width 0
	    set newWidth [expr {max([winfo reqwidth $lab]+4,$newWidth)}]
	}
    }
    label .unseen -width 60
    set regularWidth [expr {$newWidth*60/[winfo reqwidth .unseen]}]
    destroy .unseen
    foreach lab $mob {
	$lab configure -width $regularWidth
    }
}

proc AbleHandEditControls {slot} {
    if {[string match normal [$slot.e cget -state]]} {
        pack $slot.tick -side left
        pack $slot.cross -side left
    } else {
        pack forget $slot.tick
        pack forget $slot.cross
    }
}

proc EditValueComment {topFrame compName} {
    global msgs

    set oldComment $msgs(comment_$compName)
    if {[string equal $oldComment $msgs(ncfv)]} {
	set oldComment {}
    }
    set roll [RelationCheck $topFrame "value for $compName" \
		  param_value {} {} $oldComment]
    if {[lindex $roll 0]} {
	set oldComment [lindex $roll 1]
    }
    if {![string length $oldComment]} {
	set oldComment $msgs(ncfv)
    }
    set msgs(comment_$compName) $oldComment
}

proc RemoveVMLevels {nodeDims} {
    set nodeDims [purge $nodeDims MEMBERS]
# Time series can now have different values for different records
#    if {!$notInput} {
#        set nodeDims [purge $nodeDims RECORDS]
#    }
    while {[set hackOpen [lsearch $nodeDims START_VM]]!=-1} {
        set nodeDims [lreplace $nodeDims $hackOpen [lsearch $nodeDims END_VM]]
    }
    return $nodeDims
}

proc ColourCaptions {slot colour} {
    $slot.caption configure -foreground $colour
#    $slot.l2 configure -fg $colour
}

proc EnquoteIfNotElement {item} {
    if {![string equal $item [lindex $item 0]]} {
	return \"$item\"
    } else {
	return $item
    }
}

proc MakeDimsLegible {dimList dataType} {
    foreach dim $dimList {
	lappend nodeDims [EnquoteIfNotElement $dim]
    }
    set dimList [join [lrange $nodeDims 0 end-1] { x }]
    set last [lindex $nodeDims end]
    if {[string compare $last 0]} {
        if {[string match false $last]} {
            set last boolean
        }
    } else {
        set last $dataType
    }
    if {[llength $dimList]} {
        append dimList " of $last"
    } else {
        set dimList "a $last"
    }
    return $dimList
}

# AddSubFrames puts up a load and a save button for each submodel frame, and
# gives them the Load and Save commands in a given namespace. So we must put
# the commands in a matching one...

proc AddSubFrames {topNode clientId parent hierarchy ns pt} {
    global msgs iconImages
    set level [lindex $hierarchy $pt]
    set nextPt [expr $pt+1]
    if {[llength $hierarchy]<=$nextPt} {
        return $parent.box$level
    } else {
        set nextLevel $parent.frame$level
        if {![winfo exists $nextLevel]} {
#            pack [ttk::labelframe $nextLevel -borderwidth 2 -relief sunken]
            frame $nextLevel -bd 2 -relief sunken
	    if {$pt} {
		foreach fellow [pack slaves $parent] {
		    if {[string compare -nocase $fellow $nextLevel]<0} {
			break
		    }
		}
# parent always contains header frame, which is packed at top
		pack $nextLevel -before $fellow -side bottom \
		    -fill x -expand true -padx 2 -pady 2
		raise $nextLevel $fellow ;# for keyboard traversal
	    } else {
		set level [tr. "TOP LEVEL"]
		pack $nextLevel -side bottom \
		    -fill x -expand true -padx 2 -pady 2
	    }
# now create a style for this level which we will use for the buttons
# to set their background colour to that of the appropriate submodel
	    set bStyle style$nextLevel
	    eval [list ttk::style configure $bStyle] \
		[ttk::style configure Toolbutton]
	    eval [list ttk::style map $bStyle] [ttk::style map Toolbutton]
	    ttk::style layout $bStyle [ttk::style layout Toolbutton]

            pack [frame $nextLevel.head] -fill x -expand true
            set path /[join [lrange $hierarchy 0 $pt] /]
            # added setting of SimileProject element to store spf path
	    if {[llength $ns]} {
		pack [::ttk::button $nextLevel.head.save -style $bStyle \
			  -image $iconImages(save) \
			  -command [list ${ns}::Save $clientId $path]] \
		    -side right
		BindPopup $nextLevel.head.save \
		    [format [tr. {Save values for submodel "%1$s"}] $level]
		FixDisabledImgBug $nextLevel.head.save
		pack [::ttk::button $nextLevel.head.open -style $bStyle \
			  -image $iconImages(open) \
			  -command [list ${ns}::Open $clientId $path]] \
		    -side right
		BindPopup $nextLevel.head.open \
		    [format [tr. {Load values for submodel "%1$s"}] $level]
		FixDisabledImgBug $nextLevel.head.open
		lower $nextLevel.head.open
	    }
            if {[string equal fileparams $ns]} {
                pack [::ttk::button $nextLevel.head.clear -style $bStyle \
			  -image $iconImages(new) \
			  -command [list ${ns}::Clear $clientId $path]] \
		    -side right
                BindPopup $nextLevel.head.clear \
		    [tr. "Clear values in this submodel"]
		FixDisabledImgBug $nextLevel.head.clear
		lower $nextLevel.head.clear
            }
            pack [label $nextLevel.head.label -text $level:]
#	    $nextLevel configure -text $level: -labelanchor n

#set bg colour from submodel: rejected because not all widgets can have their
#colours set so it looks odd, but then I discovered ttk styles...

	    set node [IdFromTail $topNode $path 0]
# take advantage to have header pop submodel comment
	    ParamLabelPopup $nextLevel.head.label $node $level
	    set fColour [GetFromProlog tk_get_info($node,colour)]
	    if {[lsearch {white clear} $fColour]<0} {
		$nextLevel configure -bg $fColour
		$nextLevel.head configure -bg $fColour
		$nextLevel.head.label configure -bg $fColour
		ttk::style map $bStyle -background \
		    [list pressed [Gradient $fColour $nextLevel 15] \
			 active [Gradient $fColour $nextLevel -75] {} $fColour]
	    }
        }
        return [AddSubFrames $topNode $clientId $nextLevel $hierarchy \
		    $ns $nextPt]
    }
}

proc ParamLabelPopup {label node capt} {
    # Look at the code that gets the information for the variable's
    # popup in the model window -- it's in window.tcl, procedure AddEqnPopup --
    # look for the calls to Prolog proc tk_get_info
    #set desc [do_in_editor GetFromProlog tk_get_info('$winId',$node,desc)]
    set dimReqs [GetFromProlog tk_get_info($node,units)]
    set userDesc [GetFromProlog tk_get_info($node,description)]
    set comment [do_in_editor GetFromProlog tk_get_info($node,comment)]
    set desc "$capt ($dimReqs)"
    if {![string equal {} $userDesc]} {
	append desc { -- } $userDesc
    }
    BindPopup $label $desc $comment
#    BindPopup $slot.l2 "$comment"
}

proc purge {list toGo} {
    set done {}
    foreach item $list {
        if {[string compare $toGo $item]} {
            lappend done $item
        }
    }
    return $done
}

proc ZapParams {topNode smPath metaFile makePartOfProject} {
    global whichParamsAffected
    
    array unset whichParamsAffected
    MergeParams $topNode /$topNode$smPath $metaFile 0 0 $makePartOfProject
    AcceptAll $topNode [array names whichParamsAffected] 1 -1
}

proc DoneParams {topNode} {
    global widgetNames paramData
    
    AcceptAll $topNode [array names widgetNames] 1 1
    if {![llength $paramData(needed)]} {
        set paramData(done) 1
    } else {
        set paramData(complete) -1
    }
}

proc AcceptAll {topNode compNames notInput complain} {
    foreach compName $compNames {
	if {![AcceptData $topNode $compName $notInput $complain]} {
	    break
	}
    }
}

proc AcceptData {topNode compName notInput complain} {
#puts "AcceptData $topNode $compName $notInput $complain"
    global runState msgs whichParamsAffected readMany paramMetadata
    if {$notInput==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
	set compLocal $compName
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
	set compLocal [TrimDTFromPath $compName]
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames

    set node [IdFromTail $topNode $compName $notInput]
    set dataChanged 0
    if {$complain > -1 && \
	    ![string equal disabled [$outNames($compName).e cget -state]]} {
	set newData [UglifyValList [$outNames($compName).e get]]
	if {![string equal $newData $suppliedData($compName)]} {
	    set msgs(param_source_$compName) [tr. Unsaved]
	    set paramMetadata($compName,saveReference) 0
	    #                set suppliedData($compName) $newData
	    # will do that later _if_ it is error free
	    set dataChanged 1
	    set entryChanged 1
	} elseif {[string toupper [lindex $newData 0]] eq "NOW" || \
		      [info exists suppliedData(slid,$compName)]} {
	    array unset suppliedData slid,$compName
	    set dataChanged 1
	}
    } else {
	upvar 0 suppliedData($compName) newData
    }

    # for each constant value, check whether it has been changed, and if so,
    # flag a complete model rebuild. Do same if running_c lost due to crash
    # or model not yet started
    
    # refinement needed: changes to compartments or time series only need a reset
    
# Old version compared data to current model contents to check for changes --
# very wasteful
#    if {$runState($topNode,modelRunning)<=2} {
#        set dataChanged 1
#    } elseif {[catch {GetCompProperty $topNode Value $node} oldVal]} {
#        set dataChanged 1
#    } elseif {[string compare [lindex $oldVal 0] $suppliedData($compName)]} {
#        set dataChanged 1
#    }
#
# Now this should work...
#
    if {[info exists whichParamsAffected($compName)]} {
	unset whichParamsAffected($compName)
	set dataChanged 1
    } elseif {$runState($topNode,modelRunning)<=2} {
	set dataChanged 1
    }
	
    # Make array form if data has changed
    if {$dataChanged} {
        #   set msgs(param_source_$compName) Unsaved
        # only if the actual entry field has been edited
	set recordDims [lrange [GetCompProperty $topNode Dims $node] 0 end-1]
        set trans [GetCompProperty $topNode Trans $node]
        if {$readMany($compName)} {
	    set recordDims [linsert $recordDims 0 TIME]
	}
#        # Now replace each -1 in the dims with the id of the by-record
#        # submodel it represents...no longer needed

        set useCppArray [RunningInC $topNode]

#puts "node $compName has dims $recordDims"
	while {[set recordDepth [rsearch $recordDims RECORDS]] != -1} {
#            if {$afterTIME} {
#                set recordDims [lset recordDims $recordDepth MEMBERS]
#            } else {
#puts "recordDims $recordDims recordDepth $recordDepth"
	    foreach globalRecordId [array names ::paramData] {
		set recordId [TrimDTFromPath $globalRecordId]
		if {[string first $recordId $compLocal]==0 && \
			![string equal $recordId $compLocal]} {
		    set recordNode [IdFromTail $topNode $recordId -1]
		    if {$useCppArray} {
#puts "c_setparamarray a $recordNode"
#                            c_setparamarray $recordNode
# not needed with universal structure, but might help -- later
		    } else {
			tcl_setparamarray $topNode $recordNode
		    }
# Not sure how this condition would ever fail...does if TIME added above
#		    set outerDims [lrange [GetCompProperty $topNode Dims \
#					       $recordNode] 0 end-1]
#puts "node $recordNode outer dims $outerDims"
#		    if {[string match $outerDims \
#			     [lrange $recordDims 0 $recordDepth]]} {
# note afterTime will always be 0 here as RECORDS levels removed otherwise NOT
		    set recordDims [lset recordDims $recordDepth \
					    [list RECORDS $recordNode]]
		    break
#		    }
		}
	    }
#            }
	}
        #puts "About to ListToArray $node {} $trans $recordDims $suppliedData($compName)"
        if {[string equal targetData $dataLocn]} {
	    if {![llength $newData]} {
		Query pest_measurements_missing warning pest_setup {} ok
		return
	    }
	    set making target
	    set useCppArray 0
	} else {
	    set making parameter
        }
	if {$useCppArray} {
	    #puts "c_setparamarray b $node"
	    c_setparamarray $topNode $node
	} else {
	    tcl_setparamarray $topNode $node
	}
	if {$complain==2 && ![string length $newData]} {
	    # accept empty field for saving data
	    set result {} ;# handle as error
	} else {
	    set result [ListToArray $topNode $node {} {} $trans $recordDims \
			    $newData $readMany($compName) $useCppArray]
	    if {![string is integer -strict $result]} { # list of errors
		set action [lindex {none load check} $complain]
		foreach errorSpec $result {
		    if {[string equal check_uftsi [lindex $errorSpec 0]]} {
			set txtUftsi [lindex $errorSpec 2]
			set numUftsi [InDays $txtUftsi]
			if {$numUftsi} {
			    SetInterval $topNode $useCppArray $node \
				$txtUftsi $numUftsi
			    continue
			} else {
			    lset errorSpec 0 bad_uftsi
			}
		    }
		    if {$complain<=0} {
			set boredom abort
			break
		    } else {
			set inds [lindex $errorSpec 1]
			if {[llength $inds]} {
			    set where [format [tr. { at indices %1$s}] \
					   [string range $inds 1 end]]
			    # exclude leading ,
			} else {
			    set where {}
			}
			set fullError [concat [lrange $errorSpec 0 0] $action \
					   [list $making $compLocal $where] \
					   [lrange $errorSpec 2 end]]
			set boredom [Query $fullError warning spf {} abort]
			if {[string equal abort $boredom]} break
		    }
		}
	    }
	}

	if {[info exists boredom]} { ;# there were errors
            # new bit for using it as an input tool: notify that we have values
            if {[lsearch $suppliedData(needed) $compName]<0} {
		lappend suppliedData(needed) $compName
	    }
	    if {$complain>-1} {
		ColourCaptions $outNames($compName) red
	    }
	    if {[string equal abort $boredom]} {
		return 0
	    }
        } else { ;# all went well
	    if {![string is integer -strict $result]} { # errs were check_uftsis
		set result -1 ;# ...so reload time series
	    }
	    if {[info exists entryChanged]} {
		set suppliedData($compName) $newData
	    }
            if {$complain>-1} {
                ColourCaptions $outNames($compName) black
            }
            set suppliedData(needed) [purge $suppliedData(needed) $compName]
	    if {![info exists runState($topNode,reloadParams)] || \
		    $result<$runState($topNode,reloadParams)} {
# do not set if we already found an update needing a bigger reset than this one
		set runState($topNode,reloadParams) $result
	    }
            # currently this always causes an init, which may be unnecessary
        }
    }
    #puts "paramData now [array get paramData]"
    return 1 ;# means no abort
}

# rsearch gives index of last value
proc rsearch {list tgt} {
    set all [lsearch -all $list $tgt]
    if {[llength $all]} {
        return [lindex $all end]
    } else {
        return -1
    }
}

proc RevertData {winId compName notInput} {
    if {$notInput==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames

    set oldData [UglifyValList [$outNames($compName).e get]]
    $outNames($compName).e delete 0 end
    if {[info exists suppliedData($compName)]} {
        $outNames($compName).e insert 0 \
	    [PrettifyValList $suppliedData($compName)]
	set suppliedData($compName) $oldData
    }
    
}

proc FillIfSmall {entry text} {
#ShowMess debug info "Shrinking $text" ok
    $entry configure -state normal
    $entry delete 0 end
    set limit 500
    set count [ShrinkValueList text $limit]
    set text [PrettifyValList $text]
    
    set shrunken [EndsOnly text $count $limit]
    $entry insert 0 $text
    if {$shrunken} {
        $entry configure -state disabled
    }
    AbleHandEditControls [winfo parent $entry]
}

proc ClearSubParamRefs {smPath} {
    global SimileProject
    foreach spfName [array names SimileProject fileparam,$smPath/*] {
	unset SimileProject($spfName)
    }
}

proc CancelParams {} {
    global paramData
    set paramData(done) $paramData(complete)
}

namespace eval fileparams {
    
    proc Clear {spare smPath} {
        global widgetNames msgs paramState paramMetadata
	ClearSubParamRefs $smPath
        foreach compName [array names widgetNames $smPath*] {
            $widgetNames($compName).e configure -state normal
            $widgetNames($compName).e delete 0 end
            set msgs(param_source_$compName) [tr. Unsaved]
	    set paramMetadata($compName,saveReference) 0
	    array unset paramState $compName
	    AbleHandEditControls $widgetNames($compName)
        }
    }
    
    proc Save {topNode smPath args} {
# Needs some clever stuff to avoid trying to save record count info
        global SimileProject env
	set notInput [expr -[llength $args]]
	if {$notInput} {
	    set dataLocn targetData
	    set widgetLocn targetNames
	    set smPath [string range $smPath 1 end]
	    set defExtn .smf
	} else {
	    set dataLocn paramData
	    set widgetLocn widgetNames
	    set defExtn .spf
	}
	upvar \#0 $dataLocn suppliedData
	upvar \#0 $widgetLocn outNames

#ShowMess debug info "Save $smPath" ok
#puts "Need outNames cos have suppliedData for [array names suppliedData]"
# first, make sure all values to be saved are up-to-date and well-formed
	foreach smItem [array names outNames $smPath/*] {
	    if {![AcceptData $topNode $smItem $notInput 2]} {
# complain of 2 means accept empty entry but keep in needed list
		return
	    }
	}
	set defBase [LevelForTitle $smPath]
	set title [format [tr. {Save "%1$s" parameters as:}] $defBase]
        set metaFile [ChooseFile $defBase$defExtn $title 1 $topNode]
	ClearSubParamRefs $smPath ;# old spfs below this are superseded
        if {[llength $metaFile]} {
	    set SimileProject(fileparam,$smPath/) $metaFile
#puts "setting SimileProject(fileparam,$smPath/) to $SimileProject(fileparam,$smPath/)"
#            set part [file join $simtmpdir temp_out.spf]
#            set pStr [NetOpen $part w]
            set pStr [NetOpen $metaFile w]
            
	    puts $pStr {<?xml version="1.0"?>}
	    puts $pStr {<?xml-stylesheet type="text/xsl" href="spf1.xsl"?>}
	    puts $pStr "<spf simile_version=\"$env(SIMILE_VERSION)\">"
	    puts $pStr {<submodel label="top">}
	    WriteSubmodelParams suppliedData outNames $topNode $metaFile \
		$pStr $smPath {}
	    puts $pStr {</submodel>}
	    puts $pStr {</spf>}
#            foreach compName [array names outNames $smPath*] {
#		set compTail [string range $compName [string length $smPath] end]
#                set SubbedComp [StripCrs $compTail]
#                set newPopup  "Specified by $metaFile"
#                if {[ReferenceWorks $compName]} {
#                    set relName [Relativize $metaFile \
#                            [lindex $paramState($compName) 0]]
#                    puts $pStr "$SubbedComp=reference=[lreplace \
#                            $paramState($compName) 0 0 $relName]"
#                    set msgs(param_source_$compName) [concat $newPopup \
#                            (reference to $relName)]
#                } else {
#                    puts $pStr "$SubbedComp=literal=$suppliedData($compName)"
#                    set msgs(param_source_$compName) "$newPopup (literal)"
#                }
#            }
#            close $part
            close $pStr
#            set PartType "application/x-simile"
#            set Description "Simile parameter file"
#            set style attachment
#            set newMime [mime::initialize -canonical $PartType \
#                    -header [list "Content-Disposition" $style] \
#                    -header [list "Content-Description" $Description] \
#                    -header [list "Simile-Version" $env(SIMILE_VERSION)] \
#                    -header [list "Simile-Origin" file-param-dialogue] \
#                    -file $part]
#            set stream [NetOpen $metaFile w]
#            fconfigure $stream -translation binary
#            mime::copymessage $newMime $stream
            # clean everything up
#            close $stream
#            mime::finalize $newMime
#            file delete $part
        }
    }
    
    proc WriteSubmodelParams {outerData outerWidgets topNode metaFile \
				  pStr smPath indent} {
	global paramState msgs readMany

	puts $pStr $indent<variables>
	upvar 1 $outerData outData
	upvar 1 $outerWidgets outWidgets
	set inC [RunningInC $topNode]
	foreach compName [array names outData $smPath/*] {
	    if {[IsRecordCount $compName]} continue
	    set compTail [string range $compName [string length $smPath] end]
	    if {[set slashPosn [string first / $compTail 1]]>-1} {
		set inners([string range $compTail 1 [incr slashPosn -1]]) 1
		continue
	    }
	    set subbedComp [Entitize [string range $compTail 1 end]]
	    # if parameter is per-record, only write CDATA if we already have it
	    set haveBytes [string equal scenario [lindex $outData($compName) 0]]
	    set nodeId [IdFromTail $topNode $compName 0]
	    set nodeDims [lrange [GetCompProperty $topNode Dims $nodeId] \
			      0 end-1]
	    set recordLevel [lsearch $nodeDims RECORDS]
	    set genericAVs label=$subbedComp
	    if {![string equal $msgs(ncfv) $msgs(comment_$compName)]} {
		append genericAVs { } \
		    comment=[Entitize $msgs(comment_$compName)]
	    }
	    if {![string length [$outWidgets($compName).e get]]} {
# visible entry is empty, probably cleared, so skip writing
	    } elseif {[DataInScenario $compName]} {
		set type [GetCompProperty $topNode Type $nodeId]
		puts -nonewline $pStr \
		    "$indent<byte_array $genericAVs type=[Entitize $type]"
		if {$readMany($compName)} { ;# add time series specials
		    if {[set wrapTime [SetWrapTime $topNode $inC $nodeId]]} {
			puts -nonewline $pStr " wrap_time=[Entitize $wrapTime]"
		    }
		    if {![string equal EVENT \
			      [GetCompProperty $topNode Class $nodeId]]} {
			set fillMtd [SetFillMethod $topNode $inC $nodeId]
			if {![string equal use_last $fillMtd]} {
			    puts -nonewline $pStr " fill_method=\"$fillMtd\""
			}
		    }
		    if {[set uftsi [SetInterval $topNode $inC $nodeId]]!=1} {
			puts -nonewline $pStr " interval=[Entitize $uftsi]"
		    }
		}
		puts $pStr ">"
		set dimCount 0
#		if {$recordLevel==-1} {
		    set dimList $nodeDims ;# remove vm ones or bug
#		} else {
#		    set dimList [lrange $outData($compName) 3 end-3]
#		}
		if {$readMany($compName)} { ;# add TIME as outermost dimension
		    puts $pStr "  $indent<value index=\"[incr dimCount]\" val=\"TIME\"/>"
		}
		foreach dim $dimList {
		    if {[string equal 0 $dim]} break
		    puts $pStr "  $indent<value index=\"[incr dimCount]\" val=[Entitize $dim]/>"
		}
		puts $pStr "  $indent<!\[CDATA\["
		if {$haveBytes} { ;# do not bother c++, we already have it
		    set raw [lindex $outData($compName) end]
		} elseif {$readMany($compName)} {
		    set raw [c_gettimepointall $topNode $nodeId]
		} else {
		    set raw [c_getparamall $topNode $nodeId]
		}
		puts $pStr [base64 -mode encode -- $raw]
		puts $pStr "  $indent\]\]>"
		puts $pStr "$indent</byte_array>"
		set msgs(param_source_$compName) \
		    [format $msgs(metafile_bin) $metaFile]
	    } elseif {[ReferenceWorks $compName]} {
		set typePairs [list csv_columns ,image image ,gdal geotiff \
				   ,grid csv_grid]
		set ident [lindex $paramState($compName) 1]
		set mark [lsearch $typePairs $ident]
		set eltType [lindex $typePairs [incr mark]]
		set relName [lindex $paramState($compName) 0]
		if {![IsBogusURL $relName]} {
		    set relName [Relativize $metaFile $relName]
		}
		puts -nonewline $pStr "$indent<$eltType $genericAVs filename=[Entitize $relName]"
		switch -exact $ident {
		    ,image {
			foreach att {rowmin rowmax colmin colmax blackval whiteval transpval use xpose} val [lrange $paramState($compName) 2 10] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr >
		    } ,gdal {
			foreach att {rowmin rowmax colmin colmax band xpose} val [lrange $paramState($compName) 2 7] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr >
		    } ,grid {
			foreach val [lrange $paramState($compName) 2 8] \
			    att {rowmin rowmax colmin colmax xpose irow icol} {
				puts -nonewline $pStr " $att=[Entitize $val]"
			    }
			puts $pStr >
		    } default {
			puts $pStr " data_column=[Entitize $ident]>"
			set dimCount 0
			
			# v6.8p10: dbtable has been inserted back into
			# tail of paramState because both file name
			# and data column header may be lists already,
			# however it cannot be saved as an index
			# because it must come before series_control
			# elts after reload. So it is pulled out here
			# and saved as 1st s_c elt even though this
			# may not be a time series
			
			set startRealIdxs [expr {2+[regexp ,dbtable:(.*) [lindex $paramState($compName) 2] match dbtable]}]
			foreach dim [lrange $paramState($compName) $startRealIdxs end] {
			    puts $pStr "$indent<value index=\"[incr dimCount]\" val=[Entitize $dim]/>"
			}
		    }
		}
		if {[info exists dbtable]} {
		    puts $pStr "$indent<series_control field=\"dbtable\" value=[Entitize $dbtable]/>"
		}
# insert bit copied from haveBytes case above with different output
# -- could probably be more efficient
		if {$readMany($compName)} { ;# add time series specials
		    if {[set wrapTime [SetWrapTime $topNode $inC $nodeId]]} {
			puts $pStr "$indent<series_control field=\"wrap\" value=[Entitize $wrapTime]/>"
		    }
		    if {![string equal EVENT \
			      [GetCompProperty $topNode Class $nodeId]]} {
			set fillMtd [SetFillMethod $topNode $inC $nodeId]
			if {![string equal use_last $fillMtd]} {
			    puts $pStr "$indent<series_control field=\"others\" value=\"$fillMtd\"/>"
			}
		    }
		    set uftsi [SetInterval $topNode $inC $nodeId]
		    if {[lsearch {1 unit} $uftsi]==-1} {
			puts $pStr "$indent<series_control field=\"interval\" value=[Entitize $uftsi]/>"
		    }
		}

		puts $pStr $indent</$eltType>

		set msgs(param_source_$compName) \
		    [format $msgs(metafile_ref) $relName $metaFile]
	    } elseif {fmod([llength $outData($compName)],2)==1} {
		puts $pStr "$indent<single_value $genericAVs val=[Entitize $outData($compName)]/>"
		set msgs(param_source_$compName) \
		    [format $msgs(metafile_lit) $metaFile]
	    } elseif {[llength $outData($compName)]} {
# do not write if no data, can only cause trouble
		puts $pStr "$indent<multi_value $genericAVs>"
		WriteLiteralParam $pStr $outData($compName) "  $indent"
		#		    puts $pStr "<literal label=\"$SubbedComp\" \
		    #				    spec=\"$outData($compName)\"/>"
		puts $pStr "$indent</multi_value>"
		set msgs(param_source_$compName) \
		    [format $msgs(metafile_lit) $metaFile]
	    }
	}
	puts $pStr $indent</variables>
 	puts $pStr $indent<submodels>
	foreach sm [array names inners] {
	    puts $pStr "$indent<submodel label=[Entitize $sm]>"
	    WriteSubmodelParams outData outWidgets $topNode $metaFile \
		$pStr $smPath/$sm " $indent"
	    puts $pStr $indent</submodel>
	}
 	puts $pStr $indent</submodels>
    }

    proc WriteLiteralParam {pStr data indent} {
	foreach {idx val} $data {
	    if {fmod([llength $val],2)==1} {
		puts $pStr "$indent<value index=[Entitize $idx] value=[Entitize $val]/>"
	    } else {
		puts $pStr "$indent<values index=[Entitize $idx]>"
		WriteLiteralParam $pStr $val "  $indent"
		puts $pStr "$indent</values>"
	    }
	}
    }

    # merge a parameter metafile. These are saved with the pathnames of the .csv files
    # relative to the location of the metafile, so in order to reload the .csvs we need to
    # reconnect them with this pathname...trouble is, if I save in a new directory I'll need
    # new relative pathnames and I can only generate these starting from the absolute
    # pathname. And the only way to get that without a hack is to cd to it...
    
    proc Open {topNode smPath args} {
	set notInput [expr -[llength $args]]
	if {$notInput} {
	    set titlePath [file normalize /$topNode$smPath]
	    set extn .smf
	} else {
	    set titlePath $smPath
	    set extn .spf
	}
	set defBase [LevelForTitle $titlePath]
	set title [format [tr. {Load "%1$s" measurements from:}] $defBase]
	set metaFile [ChooseFile $defBase$extn $title 0 $topNode]
        if {[llength $metaFile]} {
            MergeParams $topNode $smPath $metaFile $notInput 1
            
        }
    }
}

proc Entitize {str} {
    regsub -all & $str {\&amp;} str ;# do first because subs add them
    regsub -all \" $str {\&quot;} str
    regsub -all ' $str {\&apos;} str
    regsub -all < $str {\&lt;} str
    regsub -all > $str {\&gt;} str
	
    # now to make the character references for non-Ascii stuff.
    # Force no iteration in script and no command substitution
    # This also substitutes newlines 
    set ascii \u0000-\u0009\u000b-\u007f ;# ascii characters excluding newline
    # note string must contain those that stay unchanged because if it is
    # the other way round, the substitution will itself be substituted
    set scn [regsub -all \[^$ascii\] [regsub -all \[$ascii\]+ $str %\[$ascii\]] %c]
    set fmt [regsub -all \[^$ascii\] [regsub -all \[$ascii\]+ $str %s] {\&#%d;}]
    return \"[eval [list format $fmt] [scan $str $scn]]\"
}

proc IsRecordCount {compName} {
    global msgs

    return [expr {![info exists msgs(param_source_$compName)]}]
}

proc LevelForTitle {path} {
    set levels [split $path /]
    catch {set levels [lreplace $levels 1 1 [GetExecTitle [lindex $levels 1]]]}
    return [lindex $levels end]
}

if {![info exists simplify]} {
package require xml
set parseStatus(spfParser) [::xml::parser -ignorewhitespace true \
				-elementstartcommand StartElement \
				-elementendcommand FinishElement \
				-characterdatacommand LoadBase64CharData]
}
proc RevertXMLParams {oldPath newPath topNode smPath} {
    global parseStatus widgetNames errorInfo

    array unset parseStatus simV
    array set parseStatus [list oldPath $oldPath topNode $topNode \
			       smPath $smPath submodel {} valNesting 0]
    $parseStatus(spfParser) reset
#    set logFile [tk_getSaveFile]
#    if {[string length $logFile]} {
#	set parseStatus(logStm) [open $logFile w]
#    }
    set pStr [open $oldPath r]
    set dada [read $pStr]
    close $pStr
    if {[string first {<?xml version=} $dada]} { ;# is not 0
	return 0 ;# catch pre-XML .spf before it crashes parser
    }
    set parseStatus(outStr) [open $newPath w]
    fconfigure $parseStatus(outStr) -encoding utf-8
    set broke [catch {$parseStatus(spfParser) parse [DefuseXmlBombs $dada]} \
		   feedback]
    close $parseStatus(outStr)
    if {[info exists parseStatus(logStm)]} {
	close $parseStatus(logStm)
    }
    if {$broke} {
#	if {[info exists parseStatus(simV)]} { ;# parsing at least started
# ... have already found xml header so I should hope so
	    if {![string equal aborted $feedback]} { ;# a bad XML file
		Query [list xml_parse_fail $errorInfo [array get parseStatus]] \
							 error spf {} ok
	    } ;# otherwise user aborted parsing at mismatched component name
	    return -1
#	} else { ;# an earlier style of param file
#	    return 0
#	}
    } else {
	if {[info exists parseStatus(simV)]} {
	    return $parseStatus(simV)
	} else { ;# no simile version in file
	    Query [list bad_xml_spf oldPath] error spf {} ok
	    return -1;
	}
    }
}

# alters "<?xml-stylesheet...>" line to avoid buggy parser restriction
proc DefuseXmlBombs {xmlData} {
    set bombLocn [string first xml- $xmlData]
    return [string replace $xmlData $bombLocn $bombLocn]
}

proc LogXMLAction {str} {
    global parseStatus
    if {[info exists parseStatus(logStm)]} {
	puts $parseStatus(logStm) $str
    }
}

proc StartElement {name attList args} {
    global parseStatus
#    puts "Started a $name, atts -$attList-, args -$args-"
    set attVals(xpose) 0 ;# in case older spf does not include it
    set attVals(band) 1 ;# likewise
    set attVals(irow) [set attVals(icol) position_in_data_area] ;# ditto
    array set attVals $attList
    if {[info exists attVals(label)]} {
	set logLabel [BlankCrs $attVals(label)]
	set attVals(label) [StripNewCrs $attVals(label)]
	set path $parseStatus(submodel)/$attVals(label)
	if {[info exists attVals(comment)]} {
	    set ::msgs(comment_[RestoreCrs $parseStatus(smPath)$path]) \
		[RestoreOldCrs $attVals(comment)]
# add comments before lines for reporting (simile cannot read resulting temp_in)
#	    puts $parseStatus(outStr) "\n# [RestoreCrs $attVals(comment)]"
	    set logComment [BlankCrs $attVals(comment)]
	} else {
	    set logComment {} ;# for reporting
	}
    }
    switch $name {
	submodel {
	    if {[string equal top $attVals(label)]} return;
	    append parseStatus(submodel) /$attVals(label)
	    LogXMLAction $logLabel,submodel,starts
	} single_value {
	    puts $parseStatus(outStr) $path=literal=$attVals(val)
	    LogXMLAction $logLabel,$attVals(val),$logComment
	} multi_value {
	    set parseStatus(literal,0) $attVals(label)
	    set parseStatus(literal,l) $logLabel
	    set parseStatus(literal,1) {}
	    set parseStatus(literal,c) $logComment
	    set parseStatus(valNesting) 1
	} values { ;# for multidimensional literal
	    lappend parseStatus(literal,$parseStatus(valNesting)) \
		$attVals(index)
	    set parseStatus(literal,[incr parseStatus(valNesting)]) {}
	} value {
	    if {[info exists parseStatus(translateExtras)]} {
		lappend parseStatus(translateExtras) $attVals(val)
	    } else {
		lappend parseStatus(literal,$parseStatus(valNesting)) \
		    $attVals(index) $attVals(value)
		if {[info exists attVals(fraction)]} { ;# numeric uftsi
		}
	    }
	} csv_columns {
	    puts -nonewline $parseStatus(outStr) $path=reference=[list $attVals(filename) $attVals(data_column)]
	    set parseStatus(translateExtras) {}
	    LogXMLAction "$logLabel,from column $attVals(data_column) in file $attVals(filename),$logComment"
	} csv_grid {
	    puts -nonewline $parseStatus(outStr) $path=reference=[list $attVals(filename) ,grid]
	    set parseStatus(translateExtras) [list $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(xpose) $attVals(irow) $attVals(icol)]
	    LogXMLAction "$logLabel,from grid in file $attVals(filename),$logComment"
	} image {
	    puts -nonewline $parseStatus(outStr) $path=reference=[list $attVals(filename) ,image]
	    set parseStatus(translateExtras) [list $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(blackval) $attVals(whiteval) $attVals(transpval) $attVals(use) $attVals(xpose)]
	} geotiff {
	    puts -nonewline $parseStatus(outStr) $path=reference=[list $attVals(filename) ,gdal]
	    set parseStatus(translateExtras) [list $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(band) $attVals(xpose)]
	} byte_array {
	    set parseStatus(loadByteArray) $attVals(label) 
	    set parseStatus(translateExtras) $attVals(type)
	    array set parseStatus {interval 1 wrapTime 0 fillMtd USE_LAST}
	    if {[info exists attVals(interval)]} {
		if {[info exists attVals(fraction)]} { ;# numeric uftsi
		    set parseStatus(interval) $attVals(fraction)
		} else {
		    set parseStatus(interval) [InDays $attVals(interval)]
		}
	    }
	    if {[info exists attVals(wrap_time)]} {
		set parseStatus(wrapTime) $attVals(wrap_time)
	    } 
	    if {[info exists attVals(fill_method)]} {
		set parseStatus(fillMtd) $attVals(fill_method)
	    }
	    # No need to put anything in the old-style file
	} series_control {
	    # this puts them at index 2 in tableSpec starting with 1st in file
	    puts -nonewline $parseStatus(outStr) \
		" ,$attVals(field):[EscapeNasties $attVals(value)]"
	} submodels - variables {
	} spf {
	    set parseStatus(simV) $attVals(simile_version)
	} default {
	    error "Unknown element $name contents $attList"
	}
    }
}

proc FinishElement {name args} {
    global parseStatus
#    puts "Finished a $name, args -$args-"
    switch $name {
	submodel {
	    set lastSlash [string last / $parseStatus(submodel)]
	    set ending [string range $parseStatus(submodel) \
			    [incr lastSlash] end]
	    set parseStatus(submodel) [string range $parseStatus(submodel) \
					   0 [incr lastSlash -2]]
	    LogXMLAction $ending,submodel,ends
	} multi_value {
#puts "writing $parseStatus(submodel)/[lindex $vp 0]=literal=[lindex $vp 1]"
	    puts $parseStatus(outStr) \
		$parseStatus(submodel)/$parseStatus(literal,0)=literal=$parseStatus(literal,1)
	    LogXMLAction $parseStatus(literal,l),$parseStatus(literal,1),$parseStatus(literal,c)
	} values {
	    set oldList $parseStatus(literal,$parseStatus(valNesting))
	    unset parseStatus(literal,$parseStatus(valNesting))
	    incr parseStatus(valNesting) -1
	    lappend parseStatus(literal,$parseStatus(valNesting)) $oldList
	} csv_columns - csv_grid - image - geotiff {
	    puts $parseStatus(outStr) " $parseStatus(translateExtras)"
	    unset parseStatus(translateExtras)
	} single_value - value - series_control - variables - submodels - spf {
	} byte_array {
	    unset parseStatus(loadByteArray)
	    unset parseStatus(translateExtras)
	} default {
	    error "Unknown element $name"
	}
    }						
}

proc LoadBase64CharData {encoded} {
    global parseStatus paramData widgetNames whichParamsAffected msgs \
	paramMetadata

    if {![info exists parseStatus(loadByteArray)]} return
    set relPath [RestoreCrs $parseStatus(submodel)/$parseStatus(loadByteArray)]
#    set compName $parseStatus(smPath)$relPath

    set nodeId [ExistCheck $parseStatus(topNode) $relPath \
		    $parseStatus(smPath) 0 metafile]
    switch $nodeId {
	break {error aborted}
	continue {return}
    }
#puts "$compName replaced with $parseStatus(smPath)[lindex $nodeId 0]"
    set compName $parseStatus(smPath)[lindex $nodeId 0]
#    set nodeId [IdFromTail $parseStatus(topNode) $compName 0]
#puts "got node $nodeId from $compName"
    set decoded [base64 -mode decode -- $encoded]
    set paramData($compName) \
	[concat {scenario ,bytes} $parseStatus(translateExtras) \
	 [list $parseStatus(interval) $parseStatus(wrapTime) \
	      $parseStatus(fillMtd) $decoded]]
# will now load when loading other data, or not if Tcl
    set msgs(param_source_$compName) [format $msgs(metafile_bin) \
					  $parseStatus(oldPath)]
    set paramMetadata($compName,saveBinary) 1
    if {[info exists widgetNames($compName)]} { ;# should imply widget exists
	FillIfSmall $widgetNames($compName).e \
	    [concat $paramData($compName)]
	$widgetNames($compName).e configure -state disabled
	AbleHandEditControls $widgetNames($compName)
    }
    set whichParamsAffected($compName) 1 ;# re-enabled so works in client5d
#...quick test shows no performance reduction elsewhere
}

proc RestoreOldCrs {txt} {
    if {$::parseStatus(simV)<5.7} {
	return [RestoreCrs $txt]
    }
    return $txt
}

proc StripNewCrs {txt} {
    if {$::parseStatus(simV)<5.7} {
	return $txt
    }
    return [StripCrs $txt]
}

proc MergeParams {topNode smPath oldPath notInput interactive {noneBad 1}} {
    global readMany paramState mimeSquirter simtmpdir whichParamsAffected msgs \
	paramMetadata
    global SimileProject
    if {$notInput==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
	set smPath [string range $smPath 1 end]
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames
    
    #do_in_editor puts "MergeParams $topNode $smPath $oldPath $interactive"
    set anyGood [array size whichParamsAffected]
    set oldDir [pwd]
    set metaFile [file join $simtmpdir temp_in.spf]
    set ::bermudaTriangle {}
    set paramState(origVersion) [RevertXMLParams $oldPath $metaFile $topNode $smPath]
    set smPath [string trimright $smPath /] ;# in case any added for slider spf
    switch -- $paramState(origVersion) {
	-1 { ;# User aborted because XML full of unusable bytearrays
	    return 0
	} 0 { ;# File failed to parse as XML, try older formats
	    if {[catch {
		package require mime ;# not done yet if in client5d
		set multiT [mime::initialize -file $oldPath]
		set paramState(origVersion) [mime::getheader $multiT Simile-Version]
		set paramState(whatFrom) [mime::getheader $multiT Simile-Origin]
		if {[string equal input-param-tool $paramState(whatFrom)]} {
# due to a historical accident, the caption paths in these do not have a
# leading slash -- so add a trailing one to the target submodel.
# From v6 on, these too will be XML
		    append smPath /
		}
# puts "origin was $paramState(whatFrom), target sm now $smPath"
		set mimeSquirter [NetOpen $metaFile w]
		fconfigure $mimeSquirter -translation binary
		mime::getbody $multiT -command SquirtMime -blocksize 256} crypt]
	    } {
		# really trying to load a pre-MIME version...?
		DebugMess "assuming v3x spf because: $crypt"
		set metaFile $oldPath
		set paramState(origVersion) 0.0
	    }
	}
    }
    # If neither of the above, XML file successfully converted
    set pStr [NetOpen $metaFile r]
    if {$paramState(origVersion)>=5.0} { ;# converted from xml so will be...
	fconfigure $pStr -encoding utf-8
    }
    while {[gets $pStr savedValue] != -1} {
        # puts "Restoring $savedValue"
        # ignore blank lines
        if {![string length $savedValue]} {
            continue
        }
	# treat leading # as denoting a comment (as in Flores catalogue model!)
        if {![string first # $savedValue]} {
	    append precedingComment [string range $savedValue 1 end] " " 
            continue
        }
        set IdAndValue [split $savedValue =]
        if {$paramState(origVersion)<4.0} {
	    set restoredComp [RestoreCrs [lindex $IdAndValue 0]]
            # pre-multiple desktop -- trim outermost model
            if {[string equal /Desktop/ [string range $restoredComp 0 8]]} {
                set restoredComp [string range $restoredComp 8 end]
            }
        } else {
	    set restoredComp [RestoreCrs [join [lrange $IdAndValue 0 end-2] =]]
	    # allows parameter names to contain the = sign
	}
        #ShowMess debug info "Component is $restoredComp" ok
        set move [ExistCheck $topNode $restoredComp $smPath $notInput file]
        switch $move {
            break {
		set noneBad 0
		break
	    }
            continue {continue}
        }
	set relativeComp [lindex $move 0]
	set node [lindex $move 1]
        set startLine [FirstIndexCheck $topNode $node]
        if {($startLine!=-1)==($notInput!=-1)} {
	    # change back now in case .spf filename is relative (possible
	    # if merging params from script)
	    cd $oldDir
	    if {$notInput>-1} {
		set restoredComp /$topNode$relativeComp
	    }
	    if {[info exists precedingComment]} {
		set msgs(comment_$restoredComp) [string trim $precedingComment]
		unset precedingComment
	    }
            if {$paramState(origVersion)>=4.0} {
		set dataFinder [lindex $IdAndValue end]
                set reference [string eq reference [lindex $IdAndValue end-1]]
                if {$reference} {
                    set VFile [lindex $dataFinder 0]
		    if {[string equal scenario $VFile]} continue
                }
                set suppliedData($restoredComp) $dataFinder
            } else {
                set suppliedData($restoredComp) [TrimFields \
                        [lindex $IdAndValue 1]]
                set VFile [lindex $suppliedData($restoredComp) 0]
                set reference [file exists [file join [file dirname $oldPath] \
                        $VFile]]
            }
            #ShowMess debug info "Param data is $paramData($restoredComp)" ok
            
            # OK here we go...try and follow this...first go to the starting point..
            if {$reference} {
		if {[IsBogusURL $VFile]} {
		    set locn $VFile
		} else {
		    # Now use the saved relative path to move to the .csv file's directory
		    set seekDir [file join [file dirname $oldPath] \
				     [file dirname $VFile]]
		    if {[catch {cd $seekDir}]} {
			set act [list failed_dir_reference [file tail $VFile] \
				     $relativeComp [file dirname $VFile] \
				     [file normalize $seekDir]]
			switch [Query $act warning spf {} abort] {
			    abort {break}
			    more {continue}
			}
		    }
		    cd [file join [file dirname $oldPath] [file dirname $VFile]]
		    # ...and stick the new absolute pathname into the spec! Easy!!
		    if {![file exists [file tail $VFile]]} {
			set act [list failed_param_reference [file tail $VFile] \
				     $relativeComp [file dirname $VFile] \
				     [file normalize $seekDir]]
			switch [Query $act warning spf {} abort] {
			    abort {break}
			    more {continue}
			}
		    }
		    set locn [list [pwd]/[file tail $VFile]]
		}
                set paramState($restoredComp) \
		    [concat $locn [lrange $suppliedData($restoredComp) 1 end]]
                # now just load up the data
                #ShowMess debug info "Field spec set to $paramState($restoredComp)" ok
		if {[string equal ,image \
			 [lindex $suppliedData($restoredComp) 1]]} {
		    catch {image delete tableImage}
		    image create photo tableImage \
			-file [lindex $paramState($restoredComp) 0]
		}
                set suppliedData($restoredComp) \
		    [LoadTableData paramState($restoredComp) $startLine 1]
                set whichParamsAffected($restoredComp) 1
                set msgs(param_source_$restoredComp) \
		    [format $msgs(metafile_ref) $VFile $oldPath]
		set paramMetadata($restoredComp,saveBinary) 0
		set paramMetadata($restoredComp,saveReference) 1
            } else {
                set trans [GetCompProperty $topNode Trans $node]
                if {!$startLine || ($startLine==-1 && \
				    $readMany($restoredComp))} {
		    set trans [lreplace $trans 0 0 time \
				   [linsert [lindex $trans 0] 0 timePt]]
		    # allow special time points and values to be recognized
		}
                set litPosn [SensibleValue $trans $suppliedData($restoredComp)]
		if {[lindex $litPosn 0]>0} {
                    set whichParamsAffected($restoredComp) 1
                    set msgs(param_source_$restoredComp) \
			[format $msgs(metafile_lit) $oldPath]
		    set paramMetadata($restoredComp,saveBinary) 0
		    set paramMetadata($restoredComp,saveReference) 0
                } else {
		    set choices [lindex $trans [llength $litPosn]-1]
		    if {![llength $choices]} {
			set choices numerical
		    }
                    set act [list bad_v3x_param $suppliedData($restoredComp) \
				 $relativeComp [lrange $litPosn 1 end] $choices]
                    set suppliedData($restoredComp) {}
		    switch [Query $act warning spf {} abort] {
			abort {
			    set noneBad 0
			    break
			}
			more {continue}
		    }
                }
            }
            if {$interactive} {
                #$widgetNames($restoredComp).e
                FillIfSmall $outNames($restoredComp).e \
		    $suppliedData($restoredComp)
            }
        }
    }
    close $pStr
    cd $oldDir
    if {$paramState(origVersion)>=4.0} {
        file delete $metaFile
    }
    if {[array size whichParamsAffected]>$anyGood && $noneBad} {
	#puts "setting SimileProject(fileparam,$smPath/) to $SimileProject(fileparam,$smPath/)"
        set SimileProject(fileparam,$smPath/) $oldPath
    }
}

proc ExistCheck {topNode path level notInput source} {
    global bermudaTriangle

    if {$notInput==-2} { # reloading a helper saved state
	set relevanceCheck {expr 1} ;# accept any model component for now
	set tgtCap $level
	set lostRole [tr. {display arrangements}]
	set lostType {model output}
	set fix_act relocate
    } elseif {$notInput>-1} {
	set relevanceCheck {expr {[FirstIndexCheck $topNode $node]>-1}}
	set tgtCap [TrimDTFromPath $level]
	set lostRole [tr. {values}]
	set lostType {file parameter}
	set fix_act redirect
    } else {
	set tgtCap $level
	set relevanceCheck {info exists ::targetNames($restoredComp)}
	set lostRole [tr. {values}]
	set lostType {output measurement}
	set fix_act redirect
    }

    set restoredComp $tgtCap$path
    set lostAtSea 0
    foreach {lost found} $bermudaTriangle {
        if {![string first $lost $restoredComp]} {
	    if {[string equal none $found]} {
		set lostAtSea 1
	    } else {
		set restoredComp $found[string range $restoredComp \
					    [string length $lost] end]
	    }
        }
    }
    if {$lostAtSea} {
        return continue
    }
    
    set node [GetCompProperty $topNode IdFromCapt $restoredComp]
    if {![string equal nomatch $node]} {
	if {![eval $relevanceCheck]} {
	    set node nomatch
	}
    }
    if {[string equal nomatch $node]} {
        set nextLook $restoredComp
        while {[string equal nomatch $node]} {
            set lostBit $nextLook
	    set listVers [split $lostBit /]
	    set badPt [lindex $listVers end]
            set nextLook [join [lrange $listVers 0 end-1] /]
            if {[llength $nextLook]} {
                set node [GetCompProperty $topNode IdFromCapt $nextLook]
            } else {
                set node $topNode
            }
        }
        if {![string equal $lostBit $restoredComp]} {
            set lostType submodel
        }
        set act [Query [list moved_component $source $lostRole $lostType \
			    $badPt $nextLook] \
		     warning spf {} [list forget abort $fix_act]]
	switch $act {
	    abort {
		return break
	    } forget {
		set newPath none
	    } default { # fix act
		set newPath [ChooseByInspection $topNode $lostBit $lostType]
	    }
	}
        if {[string equal submodel $lostType]} {
            lappend bermudaTriangle $lostBit [lindex $newPath 0]
	    if {![string equal none $newPath]} { ;# check remaining nest levels
		return [ExistCheck $topNode $path $level $notInput $source]
	    }
	} else {
	    if {![string equal none $newPath]} {
		#puts "shoved $path to $newPath"
		return $newPath
	    }
        }
        return continue
    }
    #puts "moved $path to $restoredComp"
    return [list $restoredComp $node]
}

# this gets a new location for the values of any parameters which were lying 
# around in the model, or loaded from a file, but do not have a model component
# in their current location. The component found need not use the part of
# the previous location which does make sense, but must be inside the submodel
# for which data is being loaded. Achieve this later by setting the last arg to
# the required top level path.

proc ChooseByInspection {topNode oldObj type} {
    # types are file parameter, output measurement or submodel
    global helperTable classTable paramData

    set parent [grab current]
    set t [PutItThere .new[NameToTag $type] $parent] ;# window id used to bring clix here
    wm protocol $t WM_DELETE_WINDOW \
	[list set paramData(newPath,done) none]
    wm title $t "$type for $oldObj values:" 

    # go through gymnastix to put a Model Inspector in ths window
    set ::myNode $topNode ;# for inspector helper
    set ::RunEnv::CurrentContainer $t
    set hlp [UniqueId helper]
    set helperId $helperTable(VariableList)
    set runClass $classTable(run,$topNode)
    similescript::$helperId $hlp $runClass Variables {}

    LetItShow $t paramData(newPath,done)
    PackItUp $t
    if {[string length $parent]} {
	grab $parent
    }
    return $paramData(newPath,done)
}

proc IdFromTail {topNode fullCapt notInput} {
    if {$notInput>-1} {
	set fullCapt [TrimDTFromPath $fullCapt]
    }
    if {![string length $fullCapt]} {
	return $topNode
    }
    return [GetCompProperty $topNode IdFromCapt $fullCapt]
}

proc TrimDTFromPath {fullCapt} {
    return [string range $fullCapt [string first / $fullCapt/ 1] end]
}

proc FirstIndexCheck {topNode node} {
    return [lsearch {INPUT TABLE} [GetCompProperty $topNode Eval $node]]
}

proc DataInScenario {compName} {
    global paramMetadata
    
    if {[info exists paramMetadata($compName,saveBinary)]} {
	return $paramMetadata($compName,saveBinary)
    }
    return 0
}

# This checks whether a parameter really has the value specified by its
# .csv file reference

proc ReferenceWorks {compName} {
    global paramMetadata
    
    if {[info exists paramMetadata($compName,saveReference)]} {
	return $paramMetadata($compName,saveReference)
    }
    return 0
}

# This tests for sensible model values.
# 0: not sensible
# 1: the timepoint NOW (not acceptable as datum)
# 2: an integer
# 3: a float
# 4: a list

proc SensibleValue {trans list} {
    set curLevel [lindex $trans 0]
    if {[llength $trans]==1} {
        return [VarType $list $curLevel]
    } else {
        foreach {idx val} $list {
            if {[lsearch {1 2} [VarType $idx $curLevel]] == -1} {
		return [list -1 $idx] ;# error this level -- bad index
	    }
	    set deeperRes [SensibleValue [lrange $trans 1 end] $val]
	    if {[lindex $deeperRes 0]<=0} {
                return [linsert $deeperRes 1 $idx]
            }
        }
        return 4
    }
}

# useful proc which returns 1 for a valid string, 2 for a valid
# numerical index, 3 for a numerical entry and 0 for all else

proc VarType {testVar types} {
#puts "checking $testVar is of $types"
    if {[string equal time $types]} {
	if {[lsearch {NOW OTHERS INTERVAL} [string toupper $testVar]]!=-1} {
	    return 1
	} elseif {[Numeric $testVar]} {
	    return 2
	}
    } elseif {[string equal timePt [lindex $types 0]]} {
	if {[lsearch {RESTART USE_LAST USE_CLOSEST INTERPOLATE} \
		 [string toupper $testVar]]!=-1} {
	    return 2
	} else {
	    return [VarType $testVar [lrange $types 1 end]]
	}
    } elseif {[llength $types]} {
	if {[lsearch $types $testVar]!=-1} {
	    return 1
	}
    } elseif {[string is integer $testVar]} {
        return 2
    } elseif {[Numeric $testVar]} {
        return 3
    } elseif {[InDays $testVar]} {
	return 1
    }
    return 0
}

proc GetFromTable {parent topNode compName trans dlgStyle} {
    global paramState table_entry msgs paramMetadata \
	widgetNames whichParamsAffected

    if {$dlgStyle eq "result" || $dlgStyle eq "measure"} {
	set dataLocn targetData
	set widgetLocn targetNames
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames
    
    if {[info exists paramState($compName)]} {
        set table_entry(data) $paramState($compName)
    } else {
        set table_entry(data) {}
    }
    if {[string match normal [$outNames($compName).e cget -state]]} {
        set table_entry(values) [UglifyValList [$outNames($compName).e get]]
    } else {
        set table_entry(values) $suppliedData($compName)
    }
    set table_entry(bytes) [DataInScenario $compName]
    if {![string equal $msgs(ncfv) $msgs(comment_$compName)]} {
	set table_entry(comment) $msgs(comment_$compName)
    }
# trim off model name from caption cos it is ugly
    set tablCapt [TrimDTFromPath $compName]
    set newSource [equationDoTable [winfo toplevel $parent] $topNode $tablCapt \
		       ($paramMetadata($compName,dimList)) $trans $dlgStyle]

# If loading data for PEST there is no parent dialogue so do not keep grab
    if {$dlgStyle eq "result" || $dlgStyle eq "measure"} {
	grab release [winfo toplevel $parent]
    }
    if {$newSource>0} {
        set suppliedData($compName) $table_entry(values)
	set whichParamsAffected($compName) 1
        FillIfSmall $outNames($compName).e $suppliedData($compName)
        switch $newSource {
            2 {
		# data loaded from separate file and not altered
		set paramState($compName) $table_entry(data)
                set msgs(param_source_$compName) \
		    [format $msgs(direct_ref) $table_entry(fileName)]
		set paramMetadata($compName,saveReference) 1
	    } 1 {
		# data altered in table editor
                set msgs(param_source_$compName) [tr. Unsaved]
		set paramMetadata($compName,saveReference) 0
            }
        }
	set paramMetadata($compName,saveBinary) $table_entry(bytes)
    }
    if {$newSource} {
	set msgs(comment_$compName) $msgs(ncfv)
	if {[string length $table_entry(comment)]} {
	    set msgs(comment_$compName) $table_entry(comment)
	}
    }
}
