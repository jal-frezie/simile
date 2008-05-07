# Simile source code file: Run/params.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for reading and editing tables of data at run-time.
#

proc FileParamDialogue {topWin mustShow} {
    global paramData widgetNames myNode

    set topNode $myNode
    set topCapt [GetExecTitle $topNode]
    set allNodes [GetCompProperty $topNode Objects]
    # do it now to shake out errors before opening window
    set t [PutItThere .fpdialogue $topWin]
    wm protocol .fpdialogue WM_DELETE_WINDOW CancelParams
    wm title $t "File parameters for $topCapt"
    if {!$mustShow} {
        set paramData(needed) {}
    }
    MakeFrames $t
    array unset widgetNames
    foreach node $allNodes {
        set notInput [FirstIndexCheck $topNode $node]
        if {$notInput != -1} {
            AddEntry $t $topNode $node $mustShow $notInput Top
        }
    }
    # now check for any parameter values that are no longer needed
    set ::bermudaTriangle {}
    foreach curVal [array names paramData /$topCapt/*] {
        if {[llength $paramData($curVal)]} {
	    set shortVal [TrimDTFromPath $curVal]
            switch [ExistCheck $topNode $shortVal /$topCapt 0 database] {
                break {
                    CancelParams
                    break
                } continue {
                    unset paramData($curVal)
                }
            }
        }
    }
    if {$mustShow || [llength $paramData(needed)]} {
        pack [set bfrm [frame .fpdialogue.buttons ]] \
                -fill x
        pack [frame $bfrm.banner]
        pack [label $bfrm.banner.1 -text "All values"] -side left
        pack [label $bfrm.banner.2 -fg red -text "with red captions"] \
                -side left
        pack [label $bfrm.banner.3 -text "must be set to run the model."] \
                -side left
        pack [frame $bfrm.lpad] -side left -fill x -expand true
        pack [button $bfrm.ok -text "OK" \
                -command [list DoneParams $topNode] -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.cancel -text "Cancel" -command CancelParams -width 10] \
                -side left -padx 2 -pady 2
        #        pack [button $bfrm.merge -text "Load file" -command MergeParams -width 10] \
        -side left -padx 2 -pady 2
        #        pack [button $bfrm.save -text "Save file" -command SaveParams -width 10] \
        -side left -padx 2 -pady 2
        pack [button $bfrm.help -text "Help" -command {ContextSensitiveHelp .fpdialogue data/index.htm} -width 10] \
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

# ScrolledWindow and ScrollableFrame allow any widget to be scrolled, but need
# the bwidget package. Need to revive our own version based on a frame in a 
# canvas.
proc MakeFrames {windowId} {
    ScrolledWindow $windowId.c
    set canId $windowId.c.canvas
    ScrollableFrame $canId -yscrollincrement 1 -constrainedwidth true ;# \
            -yscrollcommand [list AdjustCanvas $windowId.c canvas y]
    $windowId.c setwidget $canId
    pack $windowId.c -side top -fill both -expand true
    
    pack [frame $windowId.checkframe] -in [$canId getframe] -side top -expand true -fill x -padx 2 -pady 2
    pack [frame $windowId.sliderframe] -in [$canId getframe] -side top \
            -fill x -expand true -padx 2 -pady 2
    
    #    $canId create window 0 0 -anchor ne -window [frame $windowId.checkframe]
    #    $canId create window 0 0 -anchor nw -window [frame $windowId.sliderframe]
}

proc AddEntry {winId topNode node mustShow notInput args} {
    global paramDims iconImages msgs
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
    set levels [concat $args [split [string range $compName 1 end] /]]
    if {[llength $args]} {
	set compName /[lindex $args 0]$compName
    } else {
	set levels [concat [list {}] $levels]
    }
    if {[string match SUBMODEL [GetCompProperty $topNode Class $node]]} {
        set suppliedData($compName) {}
        return
    }
    set nodeDims [GetCompProperty $topNode Dims $node]
#ShowMessage debug info "Creating compname $compName" ok
    # bit of voodoo...get table relating numerical indices of node to enumerated
    # types (from model) and use to translate array bounds. Do this first because
    # there will be null entries in the table for vm model levels.
    set trans [GetTransTable $node]
    if {!$notInput} {
        set nodeDims [linsert $nodeDims 0 TIME]
        set trans [linsert $trans 0 {}]
    }
    set paramDims($compName) $nodeDims
    
    #ShowMessage debug info "$node $trans $nodeDims" ok
    set nodeDims [TransBounds $trans $nodeDims]
    
    set origDims [llength $nodeDims]
    set nodeDims [RemoveVMLevels $nodeDims $notInput]
    if {$notInput==-1 && [llength $nodeDims]<$origDims} {
	return "This value has variable dimensions, and therefore cannot be optimized by parameter estimation."
    }
    set dimList [MakeDimsLegible $nodeDims \
		     [GetCompProperty $topNode Type $node]]
    pack [set slot [frame [MakeSubFrames $topNode $winId.sliderframe $levels \
            fileparams 0]]] -fill x -expand on
    pack [label $slot.l1 -text [lindex $levels end] -fg red] -side left
    pack [label $slot.l2 -text ($dimList) -fg red] -side left
    if {![info exists msgs(param_source_$compName)]} {
        set msgs(param_source_$compName) Unsaved
    }
    #Show description and comments
    # Look at the code that gets the information for the variable's
    # popup in the model window -- it's in window.tcl, procedure AddEqnPopup --
    # look for the calls to Prolog proc tk_get_info
    #set desc [do_in_editor GetFromProlog tk_get_info('$winId',$node,desc)]
    set comment [do_in_editor GetFromProlog tk_get_info('$winId',$node,comment)]
    BindPopup $slot.l1 "$comment"
    BindPopup $slot.l2 "$comment"
            
    ::ttk::button $slot.b -style Toolbutton -image $iconImages(edit) \
       -command [namespace code [list GetFromTable $winId $topNode \
				     $compName $notInput]]
    BindPopup $slot.b "Get values from file"
    if {[llength $nodeDims]>1} {
	pack $slot.b -side right
    }
    #       pack [entry $slot.e -textvariable paramData($compName)]
    # Using entries played merry hell with very long arrays -- texts work better
    pack [::ttk::entry $slot.e -width 1] -side left -fill x -expand on
    BindPopup $slot.e param_source_$compName
    bind $slot.e <Return> [list $slot.tick invoke]
    if {[info exists suppliedData($compName)]} {
        FillIfSmall $slot.e $suppliedData($compName)
    } else {
        set suppliedData($compName) {}
    }
    if {[string match normal [$slot.e cget -state]]} {
        pack [::ttk::button $slot.cross -style Toolbutton \
		  -image $iconImages(cross) \
		  -command [namespace code [list RevertData $winId \
						$compName $notInput]]] \
	    -side right
        BindPopup $slot.cross "Revert to old values"
        pack [::ttk::button $slot.tick -style Toolbutton -image $iconImages(tick) \
                -command [namespace code [list AcceptData $topNode $compName \
					      $notInput 1]]] -side right
        BindPopup $slot.tick "Accept these values"
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

proc RemoveVMLevels {nodeDims notInput} {
    set nodeDims [purge $nodeDims MEMBERS]
    if {!$notInput} {
        set nodeDims [purge $nodeDims RECORDS]
    }
    while {[set hackOpen [lsearch $nodeDims START_VM]]!=-1} {
        set nodeDims [lreplace $nodeDims $hackOpen [lsearch $nodeDims END_VM]]
    }
    return $nodeDims
}

proc ColourCaptions {slot colour} {
    $slot.l1 configure -fg $colour
    $slot.l2 configure -fg $colour
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

# MakeSubFrames puts up a load and a save button for each submodel frame, and
# gives them the Load and Save commands in a given namespace. So we must put
# the commands in a matching one...

proc MakeSubFrames {clientId parent hierarchy ns pt} {
    global iconImages
    set level [lindex $hierarchy $pt]
    set nextPt [expr $pt+1]
    if {[llength $hierarchy]<=$nextPt} {
        return $parent.box$level
    } else {
        set nextLevel $parent.frame$level
        if {![winfo exists $nextLevel]} {
            pack [frame $nextLevel -bd 2 -relief sunken] -fill x -expand true -padx 2 -pady 2 -side bottom
            pack [frame $nextLevel.head] -fill x -expand true
            set path /[join [lrange $hierarchy 0 $pt] /]
            # added setting of SimileProject element to store spf path
	    if {[llength $ns]} {
		pack [::ttk::button $nextLevel.head.save -style Toolbutton \
			  -image $iconImages(save) \
			  -command [list ${ns}::Save $clientId $path]] \
		    -side right
		BindPopup $nextLevel.head.save "Save values for this submodel"
		pack [::ttk::button $nextLevel.head.open -style Toolbutton \
			  -image $iconImages(open) \
			  -command [list ${ns}::Open $clientId $path]] \
		    -side right
		BindPopup $nextLevel.head.open "Load values for this submodel"
	    }
            if {[string equal fileparams $ns]} {
                pack [::ttk::button $nextLevel.head.clear -style Toolbutton -image $iconImages(new) \
                        -command [list ${ns}::Clear $clientId $path]] -side right
                BindPopup $nextLevel.head.clear "Clear values in this submodel"
            }
            if {!$pt} {
                set level "TOP LEVEL"
            }
            pack [label $nextLevel.head.label -text $level:]
        }
        return [MakeSubFrames $clientId $nextLevel $hierarchy $ns $nextPt]
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
    MergeParams $topNode /Top$smPath $metaFile 0 0
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
	AcceptData $topNode $compName $notInput $complain
    }
}

proc AcceptData {topNode compName notInput complain} {
#puts "AcceptData $topNode $compName $notInput $complain"
    global paramDims runState msgs paramLocns whichParamsAffected
    if {$notInput==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames

    set node [IdFromTail $topNode $compName $notInput]
    set dataChanged 0
    if {$complain > -1} {
        if {![string equal disabled [$outNames($compName).e cget -state]]} {
            set newData [UglifyValList [$outNames($compName).e get]]
            if {![string equal $newData $suppliedData($compName)]} {
                set msgs(param_source_$compName) Unsaved
                set suppliedData($compName) $newData
		set dataChanged 1
            }
        }
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
        set trans [GetTransTable $node]
        
        # Now replace each -1 in the dims with the id of the by-record
        # submodel it represents
        set recordDims [lrange $paramDims($compName) 0 end-1]
        set afterTIME [string equal TIME [lindex $recordDims 0]]
        set useCppArray [expr ([RunningInC $topNode]!=0)*($afterTIME+1)]
        # 0 = no arrays, 1 = array for current only, 2 = arrays for time points
        #puts "node $compName has dims $recordDims"
        while {[set recordDepth [rsearch $recordDims RECORDS]] != -1} {
            if {$afterTIME} {
                set recordDims [lset recordDims $recordDepth MEMBERS]
            } else {
                #do_in_editor puts "recordDims $recordDims recordDepth $recordDepth"
                foreach recordId [array names suppliedData] {
                    #puts "recordId is $recordId"
                    if {[string first $recordId $compName]==0 && \
                                ![string equal $recordId $compName]} {
                        set recordNode [IdFromTail $topNode $recordId $notInput]
                        if {$useCppArray} {
                            c_setparamarray $recordNode
                        } else {
			    set paramIdx [getinfo $recordNode 6]
			    set paramLocns($paramIdx,nod) $recordNode
			    set paramLocns($paramIdx,arr) \
				[InputVarFor $topNode $recordNode]
			}
                        set outerDims [lrange [GetCompProperty $topNode Dims \
                                $recordNode] 0 end-1]
                        #puts "node $recordNode outer dims $outerDims"
                        if {[string match $outerDims \
                                    [lrange $recordDims $afterTIME $recordDepth]]} {
                            set recordDims [lset recordDims $recordDepth \
                                    [list RECORDS $recordNode]]
                            break
                        }
                    }
                }
            }
        }
        #puts "About to ListToArray $node {} $trans $recordDims $paramData($compName)"
        if {[string equal targetData $dataLocn]} {
	    if {![llength $suppliedData($compName)]} {
		ShowMessage "No target values given" warning "You must supply at least one target value for each selected output"  ok
		return
	    }
	    set whatMaking target
	    set useCppArray 0
	} else {
	    set whatMaking parameter
	    if {$useCppArray} {
		c_setparamarray $node
	    } else {
		set paramIdx [getinfo $node 6]
		set paramLocns($paramIdx,nod) $node
		set paramLocns($paramIdx,arr) [InputVarFor $topNode $node]
	    }
        }
        if {[catch {ListToArray $topNode $node {} $trans $recordDims \
                        $suppliedData($compName) $useCppArray} result]} {
            # new bit for using it as an input tool: notify that we have values
            lappend suppliedData(needed) $compName
	    if {[string match BadFP* $result]} {
		if {$complain>-1} {
		    ColourCaptions $outNames($compName) red
		    if {$complain>0} {
			if {[llength [lindex $result 2]]} {
			    set where " at indices [lindex $result 2]"
			} else {
			    set where {}
			}
			ShowMessage "Problem setting $whatMaking value" warning "While attempting to load the $whatMaking value \"$compName\"$where the following problem occurred: [lindex $result 1]" ok
		    }
                }
            } else { ;# a bug rather than a bad user entry
		error $result $::errorInfo
	    }
        } else {
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

proc ListToArray {topNode tgt subs trans dims list useCppArray} {
    # ShowMessage debug info  "Go! tgt $tgt trans $trans dims $dims list $list" ok
    # skip over any vm arrays, their indices will not appear
    # in calls for values, but keep the translation list in sync
    # ... string match stops cleanly at end of list
    global comboTypes
    
    if {[string equal ,bytes [lindex $list 1]]} {
	if {$useCppArray} {
	    return -1 ;# do nothing, the data has already been loaded to c
	} else {
	    # DO THE fallback thing
	}
    } elseif {[string equal ,gdal [lindex $list 1]]} {
	set startIdx [expr {![string equal TIME [lindex $dims 0]]}]
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1 && $startIdx} {
	    DoNotPassTcl $topNode $tgt $dims $list
	    return -1 ;# typical fixed parameter
	} else {
	    set list [concat [NumberElements [ReadGdalRefToList $list \
						  [lindex $dims 0] \
						  [lindex $dims 1]] \
				  $startIdx] [lrange $list 6 end]]
	}
    }
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
    if {![llength $dims]} {
        switch [llength $list] {
            0 {
                FPError "Missing value" {}
            } 1 {
                if {![string last ,now [string tolower $subs] 3]} {
                    set idAndSubs $tgt[string range $subs 4 end]
		    set tgtVar [InputVarFor $topNode $tgt]
		    if {[string match comboChoices $tgtVar]} {
			set comboTypes($idAndSubs) $list
		    }
                    EnumTypeToNumber $tgtVar $idAndSubs \
                            $list $thisTrans [expr $useCppArray/2]
                    return 1
		} else {
                    EnumTypeToNumber paramData $tgt$subs \
			$list $thisTrans $useCppArray
                    return -1 ;# should be 0 if a comp
                }
            } default {
                FPError "Array $list supplied instead of scalar" {}
            }
        }
    }
    if {[llength $list]==1} {
        #puts "setting paramData($tgt) to $headNum"
        set userDims [join $dims { x }]
        FPError "scalar $list supplied instead of array of $userDims" {}
    }
    if {[llength $list]%2} {
        FPError "Missing value" [list [lindex $list end]]
    }
    
    foreach {indx sublist} $list {
        # was array set sub $list...above would allow us to check that all indices were
        # the right type if we could be bothered...OK then...
        set role "Index value"
        if {[string match TIME $nextDim]} {
            set role "Time point"
            if {!([Numeric $indx] || \
		      [lsearch {now others} [string tolower $indx]]>-1)} {
                FPError "$role $indx must be NOW, OTHERS or a number." {}
            }
        } elseif {[string compare {} $thisTrans]} {
            set poss [lsearch $thisTrans $indx]
            if {$poss == -1} {
                FPError "$role $indx is not a member of type [lindex $thisTrans 0], pick one of [lrange $thisTrans 1 end]." {}
            }
        } elseif {![string is integer $indx]} {
            FPError "$role $indx is not an integer." {}
        } elseif {$indx<=0} {
            FPError "$role is zero or negative." {}
        }
        if {[info exists sub($indx)]} {
            FPError "$role $indx appears more than once." {}
        }
        set sub($indx) $sublist
    }
    
    #puts "dims remaining $dims"
    if {[string match TIME $nextDim]} {
        # If time, we can have as many or as few vals as we want, and they can be
        # any positive number. If there are values other than NOW, do an init step
        
        # not quite working, note that later dimensions for a time point are treated
        # just like other dimensions, i.e., all must be set
        set redoStep 1
        # Next call removes old time series data from the system
        EnumTypeToNumber paramData $tgt {} {} $useCppArray
	SetWrapTime $tgt 0 $useCppArray ;# clear old wraparound point
	SetFillMethod $tgt 0 use_last $useCppArray ;# and fill method
        foreach arrayPt [array names sub] {
            if {[set pt [lsearch {now others} [string tolower $arrayPt]]]>-1} {
		if {[llength $subs]} {
		    FPError "NOW or OTHERS must be outermost index." {}
		}
            } elseif {![Numeric $arrayPt]} {
                FPError "Time point must be NOW, OTHERS or a number." \
		    [list $arrayPt] 
            } elseif {[string equal restart [string tolower $sub($arrayPt)]]} {
		SetWrapTime $tgt $arrayPt $useCppArray
		continue
	    } elseif {$useCppArray>1} {
                c_settimepointarray $tgt $arrayPt
            }

	    if {[set mtd [lsearch {use_last use_closest interpolate} \
			      [string tolower $sub($arrayPt)]]]>-1} {
		if {$pt==1} {
		    SetFillMethod $tgt $mtd $arrayPt $useCppArray
		    continue
		}
		FPError "Fill method must be preceded by OTHERS." \
		    [list $arrayPt] 
	    } elseif {$pt==1} {
		FPError "Action $sub($arrayPt) is not USE_LAST, USE_CLOSEST or INTERPOLATE" {}
	    }

	    if {[catch {ListToArray $topNode $tgt $subs,$arrayPt $trans \
                            [lrange $dims 1 end] $sub($arrayPt) $useCppArray} step]} {
                PassFPError $step [list $arrayPt]
            } elseif {$step<1} {
                set redoStep 0
            }
        }
        return $redoStep
    }
    if {[llength $nextDim]==2 && \
                [string match RECORDS [lindex $nextDim 0]]} {
        # by-record submodel; check up to biggest. If new data here, only a reset
        # needed to set it
        
        # OK hows this for branez...use
        # the number of elements, because if there is an element larger than the
        # number of elements, one the same or smaller will be missing!
        set last [array size sub]
        if {!$last} {
            FPError "Per-record submodel must have values for at least one member." {}
        }
        
        #do_in_editor puts "Setting [lindex $nextDim 1]$subs to $last"
        if {$useCppArray} {
            set outers [lrange [split $subs ,] 1 end]
            if {[catch {c_setrecordlist $tgt $outers $last} \
                        err]} {
                FPError $err {}
            }
            foreach nested [lrange $dims 1 end] {
                if {[llength $nested]==2 && \
                            [string match RECORDS [lindex $nested 0]]} {
                    c_setrecordlist [lindex $nested 1] $outers $last
                }
            }
        }
        EnumTypeToNumber paramData [lindex $nextDim 1]$subs $last \
                {} $useCppArray
        # probably won't work anyway for time series
        set requireStep 0
    } else {
        set last $nextDim
        set requireStep -1
    }
    set redoStep 1
    for {set arrayPt 1} {$arrayPt <= $last} {incr arrayPt} {
        set indx [NumberToEnumType $arrayPt $thisTrans]
        if {![info exists sub($indx)]} {
            #puts "No $indx in [array names sub]"
            FPError "Missing value" [list $indx]
        }
        if {[catch {ListToArray $topNode $tgt $subs,$arrayPt \
                        [lrange $trans 1 end] [lrange $dims 1 end] \
                        $sub($indx) $useCppArray} mis]} {
            PassFPError $mis [list $indx]
        } elseif {$mis<1} {
            set redoStep $requireStep
        }
    }
    return $redoStep
}

proc EnumTypeToNumber {varData tgt head trans useCppArray} {
    global $varData
    
    if {![llength $head]} {
        # empty head, signal to clear out old values
        if {$useCppArray} {
            c_cleartimeseries $tgt
        } else {
            foreach oldEntry [array names $varData $tgt*] {
                unset ${varData}($oldEntry)
            }
        }
    } elseif {[string compare {} $trans]} {
        set poss [lsearch $trans [lindex $head 0]]
        if {$poss == -1} {
            if {[string equal false [lindex $trans 0]]} {
                FPError "Data value $head is not a member of type boolean, pick one of $trans." {}
            } else {
                FPError "Data value $head is not a member of type [lindex $trans 0], pick one of [lrange $trans 1 end]." {}
            }
        } else {
            PlaceInArray $tgt $poss $varData $useCppArray
        }
    } elseif {![Numeric $head]} {
        FPError "Data value $head is not a number." {}
    } else {
        PlaceInArray $tgt $head $varData $useCppArray
        #   set ${varData}($tgt) $head
    }
    #puts "just went set paramData($tgt) $paramData($tgt)"
}

proc PlaceInArray {where what varData inC} {
    #puts "PlaceInArray $where $what $varData $inC"
    switch $inC {
        1 {
            set map [split $where ,]
            if {[catch {c_setparamelement [lindex $map 0] \
                            [lrange $map 1 end] $what} urr]} {
                FPError $urr {}
            }
        } 2 {
            set map [split $where ,]
            if {[catch {c_settimepointelement [lindex $map 0] \
                            [lrange $map 2 end] [lindex $map 1] $what} urr]} {
                FPError $urr {}
            }
        } 0 {
            global $varData
            set ${varData}($where) $what
        }
    }
}

proc SetWrapTime {where when inC} {
    global paramData
    if {$inC>1} {
	c_setwraparoundtime $where $when
    } else {
	set paramData(wrapAroundPoint,$where) $when
    }
}

proc SetFillMethod {where which what inC} {
    global paramData
    if {$inC>1} {
	c_setfillmethod $where $which
    } else {
	set paramData(fillMethod,$where) [string tolower $what]
    }
}

proc FPError {occurrence inds} {
    error [list BadFP $occurrence $inds]
}

proc PassFPError {oldError newInds} {
    if {[string match BadFP* $oldError]} { ;# one of ours
	FPError [lindex $oldError 1] [concat $newInds [lindex $oldError 2]]
    } else {
	error $oldError $::errorInfo
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

    $outNames($compName).e delete 0 end
    if {[info exists suppliedData($compName)]} {
        $outNames($compName).e insert 0 \
	    [PrettifyValList $suppliedData($compName)]
    }
}

proc FillIfSmall {entry text} {
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

proc CancelParams {} {
    global paramData
    set paramData(done) $paramData(complete)
}

namespace eval fileparams {
    
    proc Clear {spare smPath} {
        global widgetNames SimileProject msgs
        foreach spfName [array names SimileProject fileparam,$smPath*] {
            unset SimileProject($spfName)
        }
        foreach compName [array names widgetNames $smPath*] {
            $widgetNames($compName).e configure -state normal
            $widgetNames($compName).e delete 0 end
            set msgs(param_source_$compName) Unsaved
        }
    }
    
    proc Save {topNode smPath args} {
# Needs some clever stuff to avoid trying to save record count info
        global SimileProject env
	set notInput [expr -[llength $args]]
	if {$notInput} {
	    set dataLocn targetData
#	    set widgetLocn targetNames
	    set smPath [string range $smPath 1 end]
	    set defFile measures.spf
	} else {
	    set dataLocn paramData
#	    set widgetLocn widgetNames
	    set defFile params.spf
	}
	upvar \#0 $dataLocn suppliedData
#	upvar \#0 $widgetLocn outNames

#ShowMessage debug info "Save $smPath" ok
#puts "Need outNames cos have suppliedData for [array names suppliedData]"
# first, make sure all values to be saved are up-to-date and well-formed
	foreach smItem [array names suppliedData $smPath/*] {
	    if {![IsRecordCount $smItem]} {
		AcceptData $topNode $smItem $notInput 1
	    }
	}
	if {[lsearch $suppliedData(needed) $smPath*]!=-1} {
	    return
	}
        set metaFile [ChooseFile $defFile "Save parameters as:" 1 $topNode]
        set SimileProject(fileparam,$smPath) $metaFile
#puts "setting SimileProject(fileparam,$smPath) to $SimileProject(fileparam,$smPath)"
        if {[llength $metaFile]} {
#            set part [file join $simtmpdir temp_out.spf]
#            set pStr [NetOpen $part w]
            set pStr [NetOpen $metaFile w]
            
	    puts $pStr {<?xml version="1.0"?>}
	    puts $pStr "<spf simile_version=\"$env(SIMILE_VERSION)\">"
	    puts $pStr {<submodel label="top">}
	    WriteSubmodelParams suppliedData $topNode $metaFile $pStr $smPath {}
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
    
    proc WriteSubmodelParams {outerData topNode metaFile pStr smPath indent} {
	global paramState paramDims msgs

	puts $pStr $indent<variables>
	upvar 1 $outerData outData
	foreach compName [array names outData $smPath*] {
	    if {[IsRecordCount $compName]} continue
	    set compTail [string range $compName [string length $smPath] end]
	    if {[set slashPosn [string first / $compTail 1]]>-1} {
		set inners([string range $compTail 1 [incr slashPosn -1]]) 1
		continue
	    }
	    set subbedComp [Entitize [StripCrs [string range $compTail 1 end]]]
	    set newPopup  "Specified by $metaFile"
	    if {[DataInScenario $compName]} {
		set nodeId [IdFromTail $topNode $compName 0]
		set type [GetCompProperty $topNode Type $nodeId]
		puts -nonewline $pStr \
		    "$indent<byte_array label=$subbedComp type=[Entitize $type]"
		if {[set wrapTime [c_setwraparoundtime $nodeId]]} {
		    puts -nonewline $pStr " wrap_time=[Entitize $wrapTime]"
		}
		if {[set fillMtd [c_setfillmethod $nodeId]]} {
		    puts -nonewline $pStr " fill_method=\"[lindex {USE_LAST USE_CLOSEST INTERPOLATE} $fillMtd]\""
		}
		puts $pStr ">"
		set dimCount 0
		foreach dim $paramDims($compName) {
		    if {[string equal 0 $dim]} break
		    puts $pStr "  $indent<value index=\"[incr dimCount]\" val=[Entitize $dim]/>"
		}
		puts $pStr "  $indent<!\[CDATA\["
		if {[string equal TIME [lindex $paramDims($compName) 0]]} {
		    set raw [c_gettimepointall $nodeId]
		} else {
		    set raw [c_getparamall $nodeId]
		}
		puts $pStr [base64 -mode encode -- $raw]
		puts $pStr "  $indent\]\]>"
		puts $pStr "$indent</byte_array>"
	    } elseif {[ReferenceWorks $compName]} {
		set relName [Relativize $metaFile \
				 [lindex $paramState($compName) 0]]
		switch -exact [lindex $paramState($compName) 1] {
		    ,image {
			puts -nonewline $pStr "$indent<image label=$subbedComp filename=[Entitize $relName]"
			foreach att {rowmin rowmax colmin colmax blackval whiteval transpval use} val [lrange $paramState($compName) 2 9] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr />
		    } ,gdal {
			puts -nonewline $pStr "$indent<geotiff label=$subbedComp filename=[Entitize $relName]"
			foreach att {rowmin rowmax colmin colmax} val [lrange $paramState($compName) 2 5] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr />
		    } ,grid {
			puts -nonewline $pStr "$indent<csv_grid label=$subbedComp filename=[Entitize $relName]"
			foreach att {rowmin rowmax colmin colmax} val [lrange $paramState($compName) 2 5] {
			    puts -nonewline $pStr " $att=[Entitize $val]"
			}
			puts $pStr />
		    } default {
			puts $pStr "$indent<csv_columns label=$subbedComp filename=[Entitize $relName] data_column=[Entitize [lindex $paramState($compName) 1]]>"
			set dimCount 0
			foreach dim [lrange $paramState($compName) 2 end] {
			    puts $pStr "$indent<value index=\"[incr dimCount]\" val=[Entitize $dim]/>"
			}
			puts $pStr $indent</csv_columns>
		    }
		}
		set msgs(param_source_$compName) \
		    [concat $newPopup (reference to $relName)]
	    } elseif {[llength $outData($compName)]==1} {
		puts $pStr "$indent<single_value label=$subbedComp val=[Entitize $outData($compName)]/>"
	    } else {
		puts $pStr "$indent<multi_value label=$subbedComp>"
		WriteLiteralParam $pStr $outData($compName) "  $indent"
		#		    puts $pStr "<literal label=\"$SubbedComp\" \
		    #				    spec=\"$outData($compName)\"/>"
		puts $pStr "$indent</multi_value>"
		set msgs(param_source_$compName) "$newPopup (literal)"
	    }
	}
	puts $pStr $indent</variables>
 	puts $pStr $indent<submodels>
	foreach sm [array names inners] {
	    puts $pStr "$indent<submodel label=[Entitize [StripCrs $sm]]>"
	    WriteSubmodelParams outData $topNode $metaFile $pStr $smPath/$sm \
		"  $indent"
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

    proc Entitize {str} {
	regsub -all & $str {\&amp;} str ;# do first because subs add them
	regsub -all \" $str {\&quot;} str
	regsub -all ' $str {\&apos;} str
	regsub -all < $str {\&lt;} str
	regsub -all > $str {\&gt;} str
	return \"$str\"
    }

    # merge a parameter metafile. These are saved with the pathnames of the .csv files
    # relative to the location of the metafile, so in order to reload the .csvs we need to
    # reconnect them with this pathname...trouble is, if I save in a new directory I'll need
    # new relative pathnames and I can only generate these starting from the absolute
    # pathname. And the only way to get that without a hack is to cd to it...
    
    proc Open {topNode smPath args} {
	set notInput [expr -[llength $args]]
        set smName [file tail $smPath]
        set metaFile [ChooseFile params.spf "Load $smName parameters from:" \
			  0 $topNode]
        if {[llength $metaFile]} {
            MergeParams $topNode $smPath $metaFile $notInput 1
            
        }
    }
}

proc IsRecordCount {compName} {
    global msgs

    return [expr {![info exists msgs(param_source_$compName)]}]
}

package require xml
set parseStatus(spfParser) [::xml::parser -ignorewhitespace true \
				-elementstartcommand StartElement \
				-elementendcommand FinishElement \
				-characterdatacommand LoadBase64CharData]

proc RevertXMLParams {oldPath newPath topNode smPath} {
    global parseStatus

    array unset parseStatus simV
    array set parseStatus [list oldPath $oldPath topNode $topNode \
			       smPath $smPath submodel {} valNesting 0]
    set parseStatus(outStr) [open $newPath w]
    $parseStatus(spfParser) reset
    set pStr [open $oldPath r]
    set broke [catch {$parseStatus(spfParser) parse [read $pStr]} feedback]
    close $pStr
    close $parseStatus(outStr)
    if {$broke} {
	if {[info exists parseStatus(simV)]} { ;# a bad XML file
	    error $feedback
	} else { ;# an earlier style of param file
	    return 0
	}
    } else {
	return $parseStatus(simV)
    }
}

proc StartElement {name attList args} {
    global parseStatus
#    puts "Started a $name, atts -$attList-, args -$args-"
    array set attVals $attList
    switch $name {
	submodel {
	    if {[string equal top $attVals(label)]} return;
	    append parseStatus(submodel) /$attVals(label)
	} single_value {
	    puts $parseStatus(outStr) \
		$parseStatus(submodel)/$attVals(label)=literal=$attVals(val)
	} multi_value {
	    set parseStatus(literal,0) $attVals(label)
	    set parseStatus(literal,1) {}
	    set parseStatus(valNesting) 1
	} values {
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
	    puts -nonewline $parseStatus(outStr) \
		"$parseStatus(submodel)/$attVals(label)=reference=$attVals(filename) "
	    set parseStatus(translateExtras) [list $attVals(data_column)]
	} csv_grid {
	    puts $parseStatus(outStr) "$parseStatus(submodel)/$attVals(label)=reference=$attVals(filename) ,grid $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax)"
	} image {
	    puts $parseStatus(outStr) "$parseStatus(submodel)/$attVals(label)=reference=$attVals(filename) ,image $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax) $attVals(blackval) $attVals(whiteval) $attVals(transpval) $attVals(use)"
	} geotiff {
	    puts $parseStatus(outStr) "$parseStatus(submodel)/$attVals(label)=reference=$attVals(filename) ,gdal $attVals(rowmin) $attVals(rowmax) $attVals(colmin) $attVals(colmax)"
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
	    set lastSlash [expr [string last / $parseStatus(submodel)]-1]
	    set parseStatus(submodel) [string range $parseStatus(submodel) \
					    0 $lastSlash]
	} multi_value {
#puts "writing $parseStatus(submodel)/[lindex $vp 0]=literal=[lindex $vp 1]"
	    puts $parseStatus(outStr) \
		$parseStatus(submodel)/$parseStatus(literal,0)=literal=$parseStatus(literal,1)
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
    global parseStatus paramData widgetNames whichParamsAffected msgs

    if {![info exists parseStatus(loadByteArray)]} return
    set relPath [RestoreCrs $parseStatus(submodel)/$parseStatus(loadByteArray)]
    set compName $parseStatus(smPath)$relPath
    set nodeId [IdFromTail $parseStatus(topNode) $compName 0]
#puts "got node $nodeId from $compName"
    set decoded [base64 -mode decode -- $encoded]
    set paramData($compName) [concat {scenario ,bytes} \
				  $parseStatus(translateExtras)]
    if {[string equal TIME [lindex $parseStatus(translateExtras) 1]]} {
	c_settimepointall $nodeId $decoded
	c_setwraparoundtime $nodeId $parseStatus(wrapTime)
	c_setfillmethod $nodeId $parseStatus(fillMtd)
    } else {
	c_setparamall $nodeId $decoded
    }
    set msgs(param_source_$compName) \
	"Specified by $parseStatus(oldPath) (literal) -- keep data in scenario file"
    if {[winfo exists $widgetNames($compName)]} {
	FillIfSmall $widgetNames($compName).e \
	    [concat $paramData($compName) [list $decoded]]
	$widgetNames($compName).e configure -state disabled
    }
#    set whichParamsAffected($compName) 1
}

proc MergeParams {topNode smPath oldPath notInput interactive} {
    global paramDims paramState mimeSquirter simtmpdir whichParamsAffected msgs
    global SimileProject
    if {$notInput==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
	set smPath [string range $smPath 1 end]
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
        set SimileProject(fileparam,$smPath) $oldPath
    }
    upvar \#0 $dataLocn suppliedData
    upvar \#0 $widgetLocn outNames
    
    #do_in_editor puts "MergeParams $topNode $smPath $oldPath $interactive"
    set oldDir [pwd]
    set metaFile [file join $simtmpdir temp_in.spf]
    set origVersion [RevertXMLParams $oldPath $metaFile $topNode $smPath]
    if {$origVersion} {
	# XML file successfully converted
    } elseif {[catch {
	set multiT [mime::initialize -file $oldPath]
	set origVersion [mime::getheader $multiT Simile-Version]
	set mimeSquirter [NetOpen $metaFile w]
	fconfigure $mimeSquirter -translation binary
	mime::getbody $multiT -command SquirtMime -blocksize 256}]
	  } {
	set metaFile $oldPath
	set origVersion 0.0
    }
    set ::bermudaTriangle {}
    set pStr [NetOpen $metaFile r]
    while {[gets $pStr savedValue] != -1} {
        #ShowMessage debug info "Restoring $savedValue" ok
        # ignore blank lines
        if {![llength $savedValue]} {
            continue
        }
        set IdAndValue [split $savedValue =]
        if {$origVersion<4.0} {
	    set restoredComp [RestoreCrs [lindex $IdAndValue 0]]
            # pre-multiple desktop -- trim outermost model
            if {[string equal /Desktop/ [string range $restoredComp 0 8]]} {
                set restoredComp [string range $restoredComp 8 end]
            }
        } else {
	    set restoredComp [RestoreCrs [join [lrange $IdAndValue 0 end-2] =]]
	    # allows parameter names to contain the = sign
	}
        #ShowMessage debug info "Component is $restoredComp" ok
        set node [ExistCheck $topNode $restoredComp $smPath $notInput file]
        switch $node {
            break {break}
            continue {continue}
        }
        set startLine [FirstIndexCheck $topNode $node]
        if {($startLine!=-1)==($notInput!=-1)} {
	    # change back now in case .spf filename is relative (possible
	    # if merging params from script)
	    cd $oldDir
	    set restoredComp $smPath$restoredComp
            if {$origVersion>=4.0} {
                set suppliedData($restoredComp) [lindex $IdAndValue end]
                set reference [string eq reference [lindex $IdAndValue end-1]]
                if {$reference} {
                    set VFile [lindex $suppliedData($restoredComp) 0]
                }
            } else {
                set suppliedData($restoredComp) [TrimFields \
                        [lindex $IdAndValue 1]]
                set VFile [lindex $suppliedData($restoredComp) 0]
                set reference [file exists [file join [file dirname $oldPath] \
                        $VFile]]
            }
            #ShowMessage debug info "Param data is $paramData($restoredComp)" ok
            
            set newPopup "Specified by $oldPath"
            # OK here we go...try and follow this...first go to the starting point..
            if {$reference} {
                # Now use the saved relative path to move to the .csv file's directory
		set seekDir [file join [file dirname $oldPath] \
				 [file dirname $VFile]]
		if {[catch {cd $seekDir}]} {
		    set act [ShowMessage "Missing data directory" warning "The parameterization file contains a reference to data file \"[file tail $VFile]\" for the parameter values for the component $restoredComp. This reference specifies the file path \"[file dirname $VFile]\" relative to the location of the parameterization file itself, so the file is being sought in the directory \"[file normalize $seekDir]\", which does not exist on this computer. Do you want to skip the values for this component and continue loading the parameterization file?" okcancel]
		    switch $act {
			cancel {break}
			ok {continue}
		    }
		}
                cd [file join [file dirname $oldPath] [file dirname $VFile]]
                # ...and stick the new absolute pathname into the spec! Easy!!
		if {![file exists [file tail $VFile]]} {
		    set act [ShowMessage "Missing data file" warning "The parameterization file contains a reference to data file \"[file tail $VFile]\" for the parameter values for the component $restoredComp, which does not exist in this folder. Do you want to skip the values for this component and continue loading the parameterization file?" okcancel]
		    switch $act {
			cancel {break}
			ok {continue}
		    }
		}
                set paramState($restoredComp) \
                        [concat [list [pwd]/[file tail $VFile]] \
                        [lrange $suppliedData($restoredComp) 1 end]]
                # now just load up the data
                #ShowMessage debug info "Field spec set to $paramState($restoredComp)" ok
		if {[string equal ,image \
			 [lindex $suppliedData($restoredComp) 1]]} {
		    catch {image delete tableImage}
		    image create photo tableImage \
			-file [lindex $paramState($restoredComp) 0]
		}
                set suppliedData($restoredComp) \
                        [LoadTableData $paramState($restoredComp) $startLine 1]
                set whichParamsAffected($restoredComp) 1
                set msgs(param_source_$restoredComp) [concat $newPopup \
                        (reference to $VFile)]
            } else {
                set trans [GetTransTable $node]
                if {!$startLine || ($startLine==-1 && 
				    $paramDims($restoredComp,readMany))} {
		    set trans [lreplace $trans 0 0 time \
				   [linsert [lindex $trans 0] 0 timePt]]
		    # allow special time points and values to be recognized
                 }
                if {[SensibleValue $trans $suppliedData($restoredComp)]>0} {
                    set whichParamsAffected($restoredComp) 1
                    set msgs(param_source_$restoredComp) "$newPopup (literal)"
                } else {
		    if {![llength $trans]} {
			set trans numerical
		    }
                    ShowMessage "Error merging parameters" error "Parameterization file contained the entry $suppliedData($restoredComp) for component $restoredComp. This entry does not start with the name of an existing file, nor is it an allowed value for this component, which are $trans." ok
                    set suppliedData($restoredComp) {}
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
    if {$origVersion>=4.0} {
        file delete $metaFile
    }
}

proc ExistCheck {topNode restoredComp tgtCap notInput source} {
    global bermudaTriangle
    
    set lostAtSea 0
    foreach ship $bermudaTriangle {
        if {![string first $ship $restoredComp]} {
            set lostAtSea 1
        }
    }
    if {$lostAtSea} {
        return continue
    }
    
    if {$notInput>-1} {
	set relevanceCheck {expr {[FirstIndexCheck $topNode $node]>-1}}
	set tgtCap [TrimDTFromPath $tgtCap]
	set lostType {file parameter}
    } else {
	set relevanceCheck {info exists ::targetNames($tgtCap$restoredComp)}
	set lostType {output measurement}
    }
#puts "checking $tgtCap$restoredComp"
    set node [GetCompProperty $topNode IdFromCapt $tgtCap$restoredComp]
    if {![string equal nomatch $node]} {
	if {![eval $relevanceCheck]} {
	    set node nomatch
	}
    }
    if {[string equal nomatch $node]} {
        set nextLook $restoredComp
        while {[string equal nomatch $node]} {
            set lostBit $nextLook
            set nextLook [join [lrange [split $lostBit /] 0 end-1] /]
            if {[llength $nextLook]} {
                set node [GetCompProperty $topNode IdFromCapt $tgtCap$nextLook]
            } else {
                set node $topNode
            }
        }
        if {![string equal $lostBit $restoredComp]} {
            set lostType submodel
        }
        set act [ShowMessage "Unused parameters" warning "The $source contains parameter values for the $lostType $lostBit, which does not exist in the target model $tgtCap. Do you want to ignore these values and continue loading the $source?" okcancel]
        if {[string equal cancel $act]} {
            return break
        }
        if {[string equal submodel $lostType]} {
            lappend bermudaTriangle $lostBit
        }
        return continue
    }
    return $node
}

proc IdFromTail {topNode fullCapt notInput} {
    if {$notInput>-1} {
	set fullCapt [TrimDTFromPath $fullCapt]
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
    global msgs
    
    return [string equal " -- keep data in scenario file" \
		[string range $msgs(param_source_$compName) end-29 end]]
}

# This checks whether a parameter really has the value specified by its
# .csv file reference

proc ReferenceWorks {compName} {
    global msgs
    
    return [expr !([string match *(literal) $msgs(param_source_$compName)] \
            || [string equal Unsaved $msgs(param_source_$compName)])]
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
    if {[string equal time $types]} {
	if {[lsearch {now others} [string tolower $testVar]]!=-1} {
	    return 1
	} elseif {[Numeric $testVar]} {
	    return 2
	}
    } elseif {[string equal timePt [lindex $types 0]]} {
	if {[lsearch {restart use_last use_closest interpolate} \
		 [string tolower $testVar]]!=-1} {
	    return 2
	} else {
	    return [VarType $testVar [lrange types 1 end]]
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
    global paramState paramDims table_entry msgs widgetNames whichParamsAffected

    if {$startLine==-1} {
	set dataLocn targetData
	set widgetLocn targetNames
	set notSeries [string is double [lindex $paramDims($compName) 0]]
    } else {
	set dataLocn paramData
	set widgetLocn widgetNames
	set notSeries $startLine
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
    set newSource [equationDoTable [winfo toplevel $parent] $topNode $compName \
		       [$outNames($compName).l2 cget -text] $notSeries]
# If loading data for PEST there is no parent dialogue so do not keep grab
    if {$startLine==-1} {
	grab release [winfo toplevel $parent]
    }
    if {$newSource} {
        set suppliedData($compName) $table_entry(values)
	set whichParamsAffected($compName) 1
        FillIfSmall $outNames($compName).e $suppliedData($compName)
        switch $newSource {
            2 {
		set paramState($compName) $table_entry(data)
                set msgs(param_source_$compName) \
		    "Loaded from $table_entry(fileName)"
	    } 1 {
                set msgs(param_source_$compName) Unsaved
            }
        }
	if {$table_entry(bytes)} {
	    append msgs(param_source_$compName) " -- keep data in scenario file"
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
    
    c_setparamall $node $bytesFromGdal
}