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
				      database] 0]
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
    MakeFrames $t
    array unset widgetNames
    foreach node $allNodes {
        set notInput [FirstIndexCheck $topNode $node]
        if {$notInput != -1} {
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
        LetItShow $t
        grab $t
        tkwait variable paramData(done)
        grab release $t
        
    } else {
        # Dialogue not needed because data OK so return good
        set paramData(done) 1
    }
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

proc MakeFrames {windowId} {
    ScrolledWindow $windowId.c
    set canId [ScrollableFrame $windowId.c.canvas -constrainedwidth true]
    $windowId.c setwidget $canId

    pack $windowId.c -side top -fill both -expand true
    return [$canId getframe]
}

proc DIYMakeFrames {windowId} {
    frame $windowId.c
    set canId [canvas $windowId.c.canvas \
		   -yscrollcommand [list $windowId.c.yscroll set]]
    pack [scrollbar $windowId.c.yscroll -orient vertical \
	      -command [list $canId yview]] -side right -fill y
    pack $canId -fill both -expand 1
    pack $windowId.c -side top -fill both -expand 1
    set sf [$canId create window 0 0 -anchor nw \
		-window [frame $windowId.c.canvas.frame]]
    bind $canId <Configure> [list $canId itemconfigure $sf -width %w]
    bind $windowId.c.canvas.frame <Configure> \
	[list $canId configure -scrollregion {0 0 %w %h}]
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
    if {[string match SUBMODEL [GetCompProperty $topNode Class $node]]} {
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
    pack [label $slot.l1 -text [lindex $levels end] -fg red -bg $lbg \
	      -width 12] -side left
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
    # Look at the code that gets the information for the variable's
    # popup in the model window -- it's in window.tcl, procedure AddEqnPopup --
    # look for the calls to Prolog proc tk_get_info
    #set desc [do_in_editor GetFromProlog tk_get_info('$winId',$node,desc)]
    set userDesc [GetFromProlog tk_get_info(dummy,$node,description)]
    set comment [do_in_editor GetFromProlog tk_get_info('$winId',$node,comment)]
    set desc "[lindex $levels end] ($dimList)"
    if {![string equal {} $userDesc]} {
	append desc { -- } $userDesc
    }
    BindPopup $slot.l1 $desc $comment
#    BindPopup $slot.l2 "$comment"
            
    #       pack [entry $slot.e -textvariable paramData($compName)]
    # Using entries played merry hell with very long arrays -- texts work better
    pack [::ttk::entry $slot.e -width 1] -side left -fill x -expand on
    BindPopup $slot.e param_source_$compName comment_$compName
    bind $slot.e <Return> [list $slot.tick invoke]
    KoreanClick $slot.e 1 {}
    bind $slot.e <Double-1> [list EditValueComment $topFrame $compName]
    if {[info exists suppliedData($compName)]} {
        FillIfSmall $slot.e $suppliedData($compName)
    } else {
        set suppliedData($compName) {}
    }
    if {[string match normal [$slot.e cget -state]]} {
        pack [::ttk::button $slot.tick -style style$holder \
		  -image $iconImages(tick) \
		  -command [namespace code [list AcceptData $topNode $compName \
						$notInput 1]]] -side left
        BindPopup $slot.tick [tr. "Accept these values"]
        pack [::ttk::button $slot.cross -style style$holder \
		  -image $iconImages(cross) \
		  -command [namespace code [list RevertData $winId $compName \
						$notInput]]] -side left
        BindPopup $slot.cross [tr. "Revert to old values"]
    }
    if {[llength $nodeDims]>1} {
	::ttk::button $slot.b -style style$holder -image $iconImages(edit) \
	    -command [namespace code [list GetFromTable $winId $topNode \
					  $compName $notInput]]
	BindPopup $slot.b [tr. "Get values from file"]
	pack $slot.b -side right
    }
    set outNames($compName) $slot
    # note whether we need to enter a parameter here...
    if {$mustShow} {
        if {[lsearch $suppliedData(needed) $compName]==-1} {
            ColourCaptions $slot black
        }
    } else {
        AcceptData $topNode $compName $notInput 0
    }
}

proc EditValueComment {topFrame compName} {
    global msgs

    set oldComment $msgs(comment_$compName)
    if {[string equal $oldComment $msgs(ncfv)]} {
	set oldComment {}
    }
    set roll [RelationCheck $topFrame "value for $compName" \
		  param_value {} $oldComment]
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
    $slot.l1 configure -fg $colour
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
		pack [::ttk::button $nextLevel.head.open -style $bStyle \
			  -image $iconImages(open) \
			  -command [list ${ns}::Open $clientId $path]] \
		    -side right
		BindPopup $nextLevel.head.open \
		    [format [tr. {Load values for submodel "%1$s"}] $level]
		lower $nextLevel.head.open
	    }
            if {[string equal fileparams $ns]} {
                pack [::ttk::button $nextLevel.head.clear -style $bStyle \
			  -image $iconImages(new) \
			  -command [list ${ns}::Clear $clientId $path]] \
		    -side right
                BindPopup $nextLevel.head.clear \
		    [tr. "Clear values in this submodel"]
		lower $nextLevel.head.clear
            }
            pack [label $nextLevel.head.label -text $level:]
#	    $nextLevel configure -text $level: -labelanchor n

#set bg colour from submodel: rejected because not all widgets can have their
#colours set so it looks odd, but then I discovered ttk styles...

	    set node [IdFromTail $topNode $path 0]
# take advantage to have header pop submodel comment
	    set msgs(comment_$path) \
		[GetFromProlog tk_get_info(dummy,$node,comment)]
	    BindPopup $nextLevel.head.label \
		[GetFromProlog tk_get_info(dummy,$node,desc)] comment_$path
	    set fColour [GetFromProlog tk_get_info(dummy,$node,colour)]
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

proc purge {list toGo} {
    set done {}
    foreach item $list {
        if {[string compare $toGo $item]} {
            lappend done $item
        }
    }
    return $done
}

proc ZapParams {topNode smPath metaFile} {
    global whichParamsAffected
    
    array unset whichParamsAffected
    MergeParams $topNode /$topNode$smPath $metaFile 0 0
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
	    set whatMaking target
	    set useCppArray 0
	} else {
	    set whatMaking parameter
        }
	if {$useCppArray} {
	    #puts "c_setparamarray b $node"
	    c_setparamarray $topNode $node
	} else {
	    tcl_setparamarray $topNode $node
	}
	if {$complain>0} {
	    set errorData [list [lindex {none load check} $complain] \
			       $whatMaking $compLocal]
	} else {
	    set errorData {}
	}
	if {$complain==2 && ![string length $newData]} {
	    # accept empty field for saving data
	    set result {} ;# handle as error
	} elseif {[catch {ListToArray $topNode $node {} $trans $recordDims \
                        $newData $readMany($compName) \
			$useCppArray $errorData} result]} {
	    if {[string equal aborted $result]} {
		set abort 1
		set result {}
            } else { ;# a bug rather than a bad user entry
		error $result $::errorInfo
	    }
	}

	if {![string length $result]} { ;# there were errors
            # new bit for using it as an input tool: notify that we have values
            if {[lsearch $suppliedData(needed) $compName]<0} {
		lappend suppliedData(needed) $compName
	    }
	    if {$complain>-1} {
		ColourCaptions $outNames($compName) red
	    }
	    if {[info exists abort]} {
		return 0
	    }
        } else { ;# all went well
	    if {[info exists entryChanged]} {
		set suppliedData($compName) $newData
	    }
            if {$complain>-1} {
                ColourCaptions $outNames($compName) black
            }
            set suppliedData(needed) [purge $suppliedData(needed) $compName]
	    if {[info exists runState($topNode,reloadParams)]} {
		if {$result<$runState($topNode,reloadParams)} {
# do not set if we already found an update needing a bigger reset than this one
		    set runState($topNode,reloadParams) $result
		}
            } elseif {$result<1} {
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

proc ListToArray {topNode tgt subs trans dims list when useCppArray errorData} {
#ShowMess debug info  "Go! tgt $tgt subs $subs trans $trans dims $dims list $list cpp $useCppArray" ok
    # skip over any vm arrays, their indices will not appear
    # in calls for values, but keep the translation list in sync
    # ... string match stops cleanly at end of list
    global comboTypes
    
    if {[string equal ,bytes [lindex $list 1]]} {
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1} {
	    if {$when} {
		c_settimepointall $topNode $tgt [lindex $list end]
		SetWrapTime $topNode $useCppArray $tgt [lindex $list end-2]
		SetFillMethod $topNode $useCppArray $tgt [lindex $list end-1]
	    } else {
		c_setparamall $topNode $tgt [lindex $list end] \
		    [lrange $list 3 end-3]
	    }
	    return -1 ;# do nothing more, the data has now been loaded to c
	} else {
	    # DO THE fallback thing (inefficient placeholder version)
	    if {[string equal REAL [lindex $list 2]]} {
		set fieldChar d
		set fieldSize 8
	    } else {
		set fieldChar i
		set fieldSize 4
	    }
	    set offset 0
	    set newList [NumberElements \
			     [DoByteArrayToList $fieldChar $fieldSize \
				  [lrange $list 3 end-3] [lindex $list end]]]
	    if {$when} {
		lappend newList [lindex $list end-2] restart \
		    others [lindex $list end-1]
	    }
	    set list $newList
	}
    } elseif {[string equal ,gdal [lindex $list 1]]} {
	# transposition not yet handled
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1 && !$when} {
	    DoNotPassTcl $topNode $tgt $dims $list
	    return -1 ;# typical fixed parameter
	} else {
	    set list [concat [NumberElements [ReadGdalRefToList $list \
						  [lindex $dims 0] \
						  [lindex $dims 1]] \
				  [expr {!$when}]] [lrange $list 7 end]]
	}
    }
# do not do this, ve no longer allow params in VM submodels...
    while {[set specialId [lsearch {START_VM MEMBERS} [lindex $dims 0]]]!=-1} {
        if {$specialId} {
            set dims [lrange $dims 1 end]
            set trans [lrange $trans 1 end]
        } else {
            set endGap [lsearch $dims END_VM]
            set dims [lreplace $dims 0 $endGap]
            set trans [lrange $trans [expr $endGap-1] end]
        }
    }
    set nextDim [lindex $dims 0]
    
    set thisTrans [lindex $trans 0]
    if {![llength $dims]} { ;# no more dims, this should be a single value
        switch [llength $list] {
            0 {
                FPError [tr. "Empty list supplied instead of value"] \
		    $subs $errorData
            } 1 {
                if {![string last ,NOW [string toupper $subs] 3]} {
		    # setting current value for var param
                    set idAndSubs $tgt[string range $subs 4 end]
		    if {[string match ENUM(*) \
			     [GetCompProperty $topNode Type $tgt]]} {
			set comboTypes($idAndSubs) $list
		    }
                    if {[EnumTypeToNumber $topNode $idAndSubs $list $thisTrans \
			     0 $useCppArray $subs $errorData]} {
			return 1
		    }
		} else {
		    # setting value for fixed param or time point
                    if {[EnumTypeToNumber $topNode $tgt$subs $list $thisTrans \
			     $when $useCppArray $subs $errorData]} {
			return -1 ;# should be 0 if a comp
		    }
                }
            } default {
                FPError [format [tr. {Array %1$s supplied instead of scalar}] \
			     $list] $subs $errorData
            }
        }
	return {}
    }

    if {[llength $list]==1} {
        #puts "setting paramData($tgt) to $headNum"
        set userDims [join $dims { x }]
        FPError [format [tr. {scalar %1$s supplied instead of array of %2$s}] \
		     $list $userDims] $subs $errorData
	return {}
    }
    set redoStep 1
    if {[llength $list]%2} {
        FPError [tr. "Expecting a value"] $subs,[list [lindex $list end]] \
	    $errorData
	set redoStep {}
    }
    
    #puts "dims remaining $dims"
    if {[string match TIME $nextDim]} {
        # If time, we can have as many or as few vals as we want, and
        # they can be any number, although negative ones may not take
        # effect at start of simulation.
	array set sub $list

        # Next call removes old time series data from the system
        EnumTypeToNumber $topNode $tgt {} {} 1 $useCppArray $subs $errorData
	SetWrapTime $topNode $useCppArray $tgt 0 ;# clear old wraparound point
# do not allow OTHERS if an event series

	if {[string equal DERIVED [GetCompProperty $topNode Eval $tgt]]} {
	    set specialPts {} ;# loading measurements for PEST
	} elseif {[string equal EVENT [GetCompProperty $topNode Class $tgt]]} {
	    set specialPts NOW
	} else {
	    set specialPts [list NOW OTHERS]
	    SetFillMethod $topNode $useCppArray $tgt use_last ;# and fill method
	}
    
        foreach arrayPt [array names sub] {
            if {[set pt [lsearch $specialPts [string toupper $arrayPt]]]>-1} {
# Following never happens, TIME is always outermost dimension
#		if {[llength $subs]} {
#		    FPError [format [tr. {"%1$s" must be outermost index.}] \
#					 $arrayPt] $subs $errorData
#		}
		if {!$pt} { ;# NOW: mark param active so it clears after event
		    MarkEvtParamActive $topNode $tgt $useCppArray
		}
            } elseif {![Numeric $arrayPt]} {
                FPError [format [tr. {Time point index must be one of %1$s or a number.}] $specialPts] $subs,[list $arrayPt] $errorData
		set redoStep {}
            } elseif {[string equal RESTART [string toupper $sub($arrayPt)]]} {
		SetWrapTime $topNode $useCppArray $tgt $arrayPt
		continue
	    } elseif {$useCppArray && [Numeric $arrayPt]} {
# If there are values other than NOW, do an init step
                c_settimepointarray $topNode $tgt $arrayPt
            }
# check for fill method if one might be appropriate
	    if {[lsearch $specialPts OTHERS]>-1} {
		set noMtd [catch {SetFillMethod $topNode $useCppArray $tgt \
				      $sub($arrayPt)} badFill]
		if {$pt==1} { ;# fill method expected
		    if {$noMtd} {
			FPError $badFill $subs,[list $arrayPt] $errorData
		    }
		    continue
		} elseif {!$noMtd} { ;# fill method found but expected
		    FPError [format [tr. {Fill method "%1$s" must be preceded by OTHERS.}] $sub($arrayPt)] $subs,[list $arrayPt] $errorData
		    set redoStep {}
		}
	    }

	    set redoStep [JoinSteps $redoStep \
			      [ListToArray $topNode $tgt $subs,$arrayPt $trans \
				   [lrange $dims 1 end] $sub($arrayPt) $when \
				   $useCppArray $errorData]]
        }
        return $redoStep
    }

    # Not time points: check the indices are good
    foreach {indx sublist} $list {
        # was array set sub $list...above would allow us to check that all indices were
        # the right type if we could be bothered...OK then...
	if {[string compare {} $thisTrans]} {
            set poss [lsearch $thisTrans $indx]
            if {$poss == -1} {
                FPError [format [tr. {The entry "%1$s" appears where an index value of type %2$s is expected. This must be one of %3$s.}] $indx [lindex $thisTrans 0] [lrange $thisTrans 1 end]] \
		    $subs $errorData
		set redoStep {}
            }
        } elseif {![string is integer -strict $indx]} {
            FPError [format [tr. {The entry "%1$s" appears where an index value of type integer is needed.}] $indx] $subs $errorData
	    set redoStep {}
        } elseif {$indx<=0} {
            FPError [format [tr. {Index value %1$s is zero or negative.}] $indx] $subs $errorData
	    set redoStep {}
        }
        if {[info exists sub($indx)]} {
            FPError [format [tr. {Index value %1$s appears more than once.}] $indx] $subs $errorData
	    set redoStep {}
        }
        set sub($indx) $sublist
    }
    if {[string equal {} $redoStep]} { ;# do not proceed with bad time step
	return $redoStep
    }

    if {[llength $nextDim]==2 && \
                [string match RECORDS [lindex $nextDim 0]]} {
        # by-record submodel; check up to biggest. OK hows this for branez...use
        # the number of elements, because if there is an element larger than the
        # number of elements, one the same or smaller will be missing!
        set last [array size sub]
        if {!$last} {
            FPError [tr. "Per-record submodel must have values for at least one member."] $subs $errorData
	    set redoStep {}
        }
        
	# Record counts do not need to be set in Tcl
        if {$useCppArray} {
	    if {$when} {
		set map [split $subs ,]
		c_settimepointrecords $topNode $tgt [lrange $map 2 end] \
		    [lindex $map 1] $last
		# if {[catch {c_settimepointrecords $tgt [lrange $map 2 end] \
		# 		[lindex $map 1] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    } else {
		c_setrecordlist $topNode $tgt [lrange [split $subs ,] 1 end] \
		    $last
		# if {[catch {c_setrecordlist $tgt [lrange [split $subs ,] \
		# 				      1 end] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    }
	} else { ;# use old system for Tcl
	    set recordNode [lindex $nextDim 1]
	    EnumTypeToNumber $topNode $recordNode$subs $last {} $when \
		     $useCppArray $subs $errorData ;# cannot fail
	}

# Hopefully, with the universal data structure, once we have set the
# record count for the outer submodel level, we will be able to access
# its contents as if they were a fixed membership array, so this
# should be redundant
#            foreach nested [lrange $dims 1 end] {
#                if {[llength $nested]==2 && \
#                            [string match RECORDS [lindex $nested 0]]} {
##puts "c_setrecordlist [lindex $nested 1] $outers $last"
#                    c_setrecordlist [lindex $nested 1] $outers $last
#                }
#            }
# So should this
#        EnumTypeToNumber paramData [lindex $nextDim 1]$subs $last \
#                {} $useCppArray
        # probably wouldn't have worked anyway for time series
    } else {
        set last $nextDim
    }
    for {set arrayPt 1} {$arrayPt <= $last} {incr arrayPt} {
        set indx [NumberToEnumType $arrayPt $thisTrans]
        if {![info exists sub($indx)]} {
            #puts "No $indx in [array names sub]"
            FPError [tr. "Missing index and value"] $subs,[list $indx] \
		$errorData
	    set redoStep {}
        } else {
	    set redoStep [JoinSteps $redoStep \
			      [ListToArray $topNode $tgt $subs,$arrayPt \
				   [lrange $trans 1 end] [lrange $dims 1 end] \
				   $sub($indx) $when $useCppArray $errorData]]
	}
    }
    return $redoStep
}

proc JoinSteps {stepA stepB} {
    if {![llength [concat $stepA $stepB]]} {
	return {}
    } else {
	return [expr {$stepA<$stepB?$stepA:$stepB}]
    }
}

proc EnumTypeToNumber {topNode tgt head trans when useCppArray subs errorData} {
    if {![llength $head]} {
        # empty head, signal to clear out old values
        if {$useCppArray} {
            c_cleartimeseries $topNode $tgt
        } else {
	    tcl_cleartimeseries $topNode $tgt
        }
    } else {
	if {[string compare {} $trans]} {
	    set poss [lsearch $trans [lindex $head 0]]
	    if {$poss == -1} {
		if {[string equal false [lindex $trans 0]]} {
		    FPError [format [tr. {Data value %1$s is not a member of type boolean, pick one of %2$s.}] $head $trans] $subs $errorData
		} else {
		    FPError [format [tr. {Data value %1%s is not a member of type %2$s, pick one of %3$s.}] $head [lindex $trans 0] [lrange $trans 1 end]] $subs $errorData
		}
		return 0
	    } 
	    set head $poss
	} elseif {![Numeric $head]} {
	    FPError [format [tr. {Data value %1$s is not a number.}] $head] \
		$subs $errorData
	    return 0
	}
	PlaceInArray $topNode $tgt $head $when $useCppArray
    }
    #puts "just went set paramData($tgt) $paramData($tgt)"
    return 1
}

proc FPError {occurrence inds errorData} {
    if {![llength $errorData]} {
	error aborted ;# quick way out
    }
    if {[llength $inds]} {
	set where [format [tr. { at indices %1$s}] [string range $inds 1 end]]
	# exclude leading ,
    } else {
	set where {}
    }
    set query [concat param_load_fail $errorData [list $where $occurrence]]
    if {[string equal abort [Query $query warning spf {} abort]]} {
	error aborted
    } else {
	return {} ;# in hope ListParamArray will return same
    }
}

proc NumberToEnumType {idx trans} {
    if {[llength $trans]} {
        return [lindex $trans $idx]
    } else {
        return $idx
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
	    set defFile [GetExecTitle $topNode].smf
	} else {
	    set dataLocn paramData
	    set widgetLocn widgetNames
	    set defFile [GetExecTitle $topNode].spf
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
	set title [format [tr. {Save %1$s parameters as:}] \
		       [LevelForTitle $smPath]]
        set metaFile [ChooseFile $defFile $title 1 $topNode]
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
	    } elseif {[DataInScenario $compName] && \
		    ($haveBytes || $recordLevel==-1)} {
		set type [GetCompProperty $topNode Type $nodeId]
		puts -nonewline $pStr \
		    "$indent<byte_array $genericAVs type=[Entitize $type]"
		set inC [RunningInC $topNode]
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
		puts $pStr ">"
		set dimCount 0
		if {$recordLevel==-1} {
		    set dimList $nodeDims ;# remove vm ones or bug
		} else {
		    set dimList [lrange $outData($compName) 3 end-3]
		}
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
		set relName [Relativize $metaFile \
				 [lindex $paramState($compName) 0]]
		switch -exact [lindex $paramState($compName) 1] {
		    ,image {
			puts -nonewline $pStr "$indent<image $genericAVs filename=[Entitize $relName]"
			foreach att {rowmin rowmax colmin colmax blackval whiteval transpval use xpose} val [lrange $paramState($compName) 2 10] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr />
		    } ,gdal {
			puts -nonewline $pStr "$indent<geotiff $genericAVs filename=[Entitize $relName]"
			foreach att {rowmin rowmax colmin colmax xpose} val [lrange $paramState($compName) 2 6] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr />
		    } ,grid {
			puts -nonewline $pStr "$indent<csv_grid $genericAVs filename=[Entitize $relName]"
			foreach val [lrange $paramState($compName) 2 8] \
			    att {rowmin rowmax colmin colmax xpose irow icol} {
				puts -nonewline $pStr " $att=[Entitize $val]"
			    }
			puts $pStr />
		    } default {
			puts $pStr "$indent<csv_columns $genericAVs filename=[Entitize $relName] data_column=[Entitize [lindex $paramState($compName) 1]]>"
			set dimCount 0
			foreach dim [lrange $paramState($compName) 2 end] {
			    puts $pStr "$indent<value index=\"[incr dimCount]\" val=[Entitize $dim]/>"
			}
			puts $pStr $indent</csv_columns>
		    }
		}
		set msgs(param_source_$compName) \
		    [format $msgs(metafile_ref) $relName $metaFile]
	    } elseif {[llength $outData($compName)]==1} {
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
	    if {[llength $val]==1} {
		puts $pStr "$indent<value index=[Entitize $idx] value=[Entitize [lindex $val 0]]/>"
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
	set title [format [tr. {Load %1$s measurements from:}] \
		       [LevelForTitle $titlePath]]
	set metaFile [ChooseFile [GetExecTitle $topNode]$extn $title 0 $topNode]
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
    return \"[lindex $levels end]\"
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
    set broke [catch {$parseStatus(spfParser) parse $dada} feedback]
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
		    $attVals(index) [EnquoteIfNotElement $attVals(value)]
	    }
	} csv_columns {
	    puts -nonewline $parseStatus(outStr) $path=reference=
	    set parseStatus(translateExtras) \
		[list $attVals(filename) $attVals(data_column)]
	    LogXMLAction "$logLabel,from column $attVals(data_column) in file $attVals(filename),$logComment"
	} csv_grid {
	    puts $parseStatus(outStr) $path=reference=[list $attVals(filename) ,grid $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(xpose) $attVals(irow) $attVals(icol)]
	    LogXMLAction "$logLabel,from grid in file $attVals(filename),$logComment"
	} image {
	    puts $parseStatus(outStr) $path=reference=[list $attVals(filename) ,image $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(blackval) $attVals(whiteval) $attVals(transpval) $attVals(use) $attVals(xpose)]
	} geotiff {
	    puts $parseStatus(outStr) $path=reference=[list $attVals(filename) ,gdal $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(xpose)]
	} byte_array {
	    set parseStatus(loadByteArray) $attVals(label) 
	    set parseStatus(translateExtras) $attVals(type)
	    array set parseStatus {wrapTime 0 fillMtd 0}
	    if {[info exists attVals(wrap_time)]} {
		set parseStatus(wrapTime) $attVals(wrap_time)
	    } 
	    if {[info exists attVals(fill_method)]} {
		set parseStatus(fillMtd) \
		    [lsearch {X USE_CLOSEST INTERPOLATE} $attVals(fill_method)]
	    }
	    # No need to put anything in the old-style file
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
	} csv_columns {
	    puts $parseStatus(outStr) $parseStatus(translateExtras)
	    unset parseStatus(translateExtras)
	} single_value - csv_grid - image - geotiff - value - variables - \
	    submodels - spf {
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
    set relPath $parseStatus(submodel)/$parseStatus(loadByteArray)
    set compName $parseStatus(smPath)$relPath

    set nodeId [ExistCheck $parseStatus(topNode) $relPath \
		    $parseStatus(smPath) 0 metafile]
    switch $nodeId {
	break {error aborted}
	continue {return}
    }

#    set nodeId [IdFromTail $parseStatus(topNode) $compName 0]
#puts "got node $nodeId from $compName"
    set decoded [base64 -mode decode -- $encoded]
    set paramData($compName) \
	[concat {scenario ,bytes} $parseStatus(translateExtras) \
	 [list  $parseStatus(wrapTime)  $parseStatus(fillMtd) $decoded]]
# will now load when loading other data, or not if Tcl
    set msgs(param_source_$compName) [format $msgs(metafile_bin) \
					  $parseStatus(oldPath)]
    set paramMetadata($compName,saveBinary) 1
    if {[info exists widgetNames($compName)]} { ;# should imply widget exists
	FillIfSmall $widgetNames($compName).e \
	    [concat $paramData($compName)]
	$widgetNames($compName).e configure -state disabled
    }
#    set whichParamsAffected($compName) 1
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

proc MergeParams {topNode smPath oldPath notInput interactive} {
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
		puts "assuming v3x spf because: $crypt"
		set metaFile $oldPath
		set paramState(origVersion) 0.0
	    }
	}
    }
    # If neither of the above, XML file successfully converted
    set anyGood 1
    set pStr [NetOpen $metaFile r]
    if {$paramState(origVersion)>=5.0} { ;# converted from xml so will be...
	fconfigure $pStr -encoding utf-8
    }
    while {[gets $pStr savedValue] != -1} {
        # ShowMess debug info "Restoring $savedValue" ok
        # ignore blank lines
        if {![llength $savedValue]} {
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
		set anyGood 0
		break
	    }
            continue {continue}
        }
	set restoredComp [lindex $move 0]
	set node [lindex $move 1]
        set startLine [FirstIndexCheck $topNode $node]
        if {($startLine!=-1)==($notInput!=-1)} {
	    # change back now in case .spf filename is relative (possible
	    # if merging params from script)
	    cd $oldDir
	    if {$notInput>-1} {
		set restoredComp /$topNode$restoredComp
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
                # Now use the saved relative path to move to the .csv file's directory
		set seekDir [file join [file dirname $oldPath] \
				 [file dirname $VFile]]
		if {[catch {cd $seekDir}]} {
		    set act [list failed_dir_reference [file tail $VFile] \
				 $restoredComp [file dirname $VFile] \
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
				 $restoredComp [file dirname $VFile] \
				 [file normalize $seekDir]]
		    switch [Query $act warning spf {} abort] {
			abort {break}
			more {continue}
		    }
		}
                set paramState($restoredComp) \
                        [concat [list [pwd]/[file tail $VFile]] \
                        [lrange $suppliedData($restoredComp) 1 end]]
                # now just load up the data
                #ShowMess debug info "Field spec set to $paramState($restoredComp)" ok
		if {[string equal ,image \
			 [lindex $suppliedData($restoredComp) 1]]} {
		    catch {image delete tableImage}
		    image create photo tableImage \
			-file [lindex $paramState($restoredComp) 0]
		}
                set suppliedData($restoredComp) \
		    [LoadTableData $paramState($restoredComp) $startLine 1]
                set whichParamsAffected($restoredComp) 1
                set msgs(param_source_$restoredComp) \
		    [format $msgs(metafile_ref) $VFile $oldPath]
		set paramMetadata($restoredComp,saveBinary) 0
		set paramMetadata($restoredComp,saveReference) 1
            } else {
                set trans [GetCompProperty $topNode Trans $node]
                if {!$startLine || ($startLine==-1 && 
				    $readMany($restoredComp))} {
		    set trans [lreplace $trans 0 0 time \
				   [linsert [lindex $trans 0] 0 timePt]]
		    # allow special time points and values to be recognized
                 }
                if {[SensibleValue $trans $suppliedData($restoredComp)]>0} {
                    set whichParamsAffected($restoredComp) 1
                    set msgs(param_source_$restoredComp) \
			[format $msgs(metafile_lit) $oldPath]
		    set paramMetadata($restoredComp,saveBinary) 0
		    set paramMetadata($restoredComp,saveReference) 0
                } else {
		    if {![llength $trans]} {
			set trans numerical
		    }
                    set act [list bad_v3x_param $suppliedData($restoredComp) \
				 $restoredComp $trans]
                    set suppliedData($restoredComp) {}
		    switch [Query $act warning spf {} abort] {
			abort {
			    set anyGood 0
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
    if {$anyGood} {
#puts "setting SimileProject(fileparam,$smPath/) to $SimileProject(fileparam,$smPath/)"
        set SimileProject(fileparam,$smPath/) $oldPath
    }
}

proc ExistCheck {topNode path level notInput source} {
    global bermudaTriangle

    if {$notInput>-1} {
	set relevanceCheck {expr {[FirstIndexCheck $topNode $node]>-1}}
	set tgtCap [TrimDTFromPath $level]
	set lostType {file parameter}
    } else {
	set tgtCap $level
	set relevanceCheck {info exists ::targetNames($restoredComp)}
	set lostType {output measurement}
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
        set act [Query [list unused_param $source $lostType $badPt $nextLook] \
		     warning spf {} {forget abort reassign}]
	switch $act {
	    abort {
		return break
	    } reassign {
		set newPath [ChooseByInspection $topNode $lostBit $lostType]
	    } forget {
		set newPath none
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

    LetItShow $t
    grab $t
    tkwait variable paramData(newPath,done)
    grab release $t
        
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
    if {[llength $list]==1} {
        return [VarType [lindex $list 0] $curLevel]
    } else {
        for {set idx 0} {$idx < [llength $list]} {incr idx 2} {
            if {[lsearch {1 2} [VarType [lindex $list $idx] $curLevel]] == -1 \
                        || ![SensibleValue [lrange $trans 1 end] \
                        [lindex $list [expr $idx+1]]]} {
                return 0
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
	if {[lsearch {NOW OTHERS} [string toupper $testVar]]!=-1} {
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
    }
    return 0
}

proc GetFromTable {parent topNode compName startLine} {
    global paramState readMany table_entry msgs paramMetadata \
	widgetNames whichParamsAffected

    if {$startLine==-1} {
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
    set tablCapt [string range $compName [string first / $compName 1] end]
    set newSource [equationDoTable [winfo toplevel $parent] $topNode $tablCapt \
		       ($paramMetadata($compName,dimList)) \
		       [expr {!$readMany($compName)}] [expr {$startLine==0}]]

# If loading data for PEST there is no parent dialogue so do not keep grab
    if {$startLine==-1} {
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

proc DoNotPassTcl {topNode node dims tableSpec} {
#puts "dims $dims spec $tableSpec"
    if {[string equal REAL [GetCompProperty $topNode Type $node]]} {
	set gdalType GDT_Float64
    } else {
	set gdalType GDT_Int32
    }

    package require gdal
    set hg [gdal_open_read_only [lindex $tableSpec 0]]
    set hdl [gdal_get_raster_band $hg 1]
    set dataRows [expr 1+[lindex $tableSpec 3]-[lindex $tableSpec 2]]
    set dataCols [expr 1+[lindex $tableSpec 5]-[lindex $tableSpec 4]]
    set fillRows [lindex $dims 0]
    set fillCols [lindex $dims 1]
    set bytesFromGdal [gdal_get_raster_data $hdl \
		     [expr [lindex $tableSpec 4]-1] \
		     [expr [lindex $tableSpec 2]-1] \
		     $dataCols $dataRows $gdalType $fillCols $fillRows]
    gdal_close $hg
    
    c_setparamall $topNode $node $bytesFromGdal [list $fillRows $fillCols]
}