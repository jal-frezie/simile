proc FileParamDialogue {topNode topWin mustShow} {
    global paramData widgetNames
    set allNodes [GetCompProperty $topNode Objects]
    # do it now to shake out errors before opening window
    set t [toplevel .fpdialogue]
    wm transient $t $topWin
    wm protocol .fpdialogue WM_DELETE_WINDOW CancelParams
    wm title $t "Enter file parameters"
    if {!$mustShow} {
	set paramData(needed) {}
    }
    MakeFrames $t
    array unset widgetNames
    foreach node $allNodes {
        set notInput [lsearch {INPUT TABLE} \
			 [GetCompProperty $topNode Eval $node]]
	if {$notInput != -1} {
	    AddEntry $t $topNode $node $mustShow $notInput
        }
    }
# now check for any parameter values that are no longer needed
    set ::bermudaTriangle {}
    foreach curVal [array names paramData /*] {
	if {[llength $paramData($curVal)]} {
	    switch [ExistCheck $topNode $curVal {Current database}] {
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
        grab $t
        tkwait variable paramData(done)
        grab release $t
        
    } else {
        # Dialogue not needed because data OK so return good
        set paramData(done) 1
    }
    destroy $t
    return $paramData(done)
}

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

proc AddEntry {winId topNode node mustShow notInput} {
    global paramData paramDims widgetNames iconImages msgs
    set compName [GetCompProperty $topNode Caption $node]
    if {[string match SUBMODEL [GetCompProperty $topNode Class $node]]} {
	set paramData($compName) {}
	return
    }
    set levels [split $compName /]
    set nodeDims [GetCompProperty $topNode Dims $node]

# bit of voodoo...get table relating numerical indices of node to enymerated
# types (from prolog) and use to translate array bounds. Do this first because
# there will be null entries in the table for vm model levels.
    set trans [GetTransTable $node]
    if {!$notInput} {
	set nodeDims [linsert $nodeDims 0 TIME]
	set trans [linsert $trans 0 {}]
    }
    if {![info exists msgs(param_source_$compName)]} {
	set msgs(param_source_$compName) Unsaved
    }
    set paramDims($compName) [lrange $nodeDims 0 end-1]

#ShowMessage debug info "$node $trans $nodeDims" ok
    set nodeDims [TransBounds $trans $nodeDims]

    set nodeDims [purge $nodeDims MEMBERS]
    set dimList [join [lrange $nodeDims 0 end-1] { x }]
    set last [lindex $nodeDims end]
    if {[string compare $last 0]} {
	if {[string match false $last]} {
	    set last boolean
	}
    } else {
	set last [GetCompProperty $topNode Type $node]
    }
    if {[llength $dimList]} {
	append dimList " of $last"
    } else {
	set dimList "a $last"
    }

    if {[string length $dimList]} {
	set slotCaption "[lindex $levels end] ($dimList):"
    } else {
	set slotCaption [lindex $levels end]
    }
    pack [set slot [frame [MakeSubFrames $topNode $winId.sliderframe $levels \
			       fileparams 0]]] -fill x -expand on
    pack [label $slot.l -text $slotCaption -fg red] -side left
    if {$nodeDims>1} {
	pack [button $slot.b -image $iconImages(edit) -command [namespace code [list GetFromTable $winId $compName $notInput]]] -side right
	BindPopup $slot.b "Get values from file"
    }
            #	    pack [entry $slot.e -textvariable paramData($compName)]
            # Using entries played merry hell with very long arrays -- texts work better
    pack [entry $slot.e -width 30] -side left -fill x -expand on
    BindPopup $slot.e param_source_$compName
    bind $slot.e <Return> [list $slot.tick invoke]
    if {[info exists paramData($compName)]} {
	FillIfSmall $slot.e $paramData($compName)
    } else {
	set paramData($compName) {}
    }
    if {[string match normal [$slot.e cget -state]]} {
    pack [button $slot.cross -image $iconImages(cross) -borderwidth 1 \
	      -command [namespace code [list RevertData $winId $compName]]] \
	-side right
    BindPopup $slot.cross "Revert to old values"
    pack [button $slot.tick -image $iconImages(tick) -borderwidth 1 \
	      -command [namespace code [list AcceptData $winId $topNode \
					    $compName 1]]] \
	-side right
    BindPopup $slot.tick "Accept these values"
    }
    set widgetNames($compName) $slot
            # note whether we need to enter a parameter here...
    if {$mustShow} {
	if {[lsearch $paramData(needed) $compName]==-1} {
	    $slot.l configure -fg black
	}
    } else {
	AcceptData $winId $topNode $compName 0
    }
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
	    set path [join [lrange $hierarchy 0 $pt] /]
	    # added setting of SimileProject element to store spf path
	    pack [button $nextLevel.head.save -image $iconImages(save) \
		      -command [list ${ns}::Save $clientId $path]] -side right
	    BindPopup $nextLevel.head.save "Save values for this submodel"
	    pack [button $nextLevel.head.open -image $iconImages(open) \
		      -command [list ${ns}::Open $clientId $path]] -side right
	    BindPopup $nextLevel.head.open "Load values for this submodel"
	    if {[string equal fileparams $ns]} {
		pack [button $nextLevel.head.clear -image $iconImages(new) \
		      -command [list ${ns}::Clear $clientId $path]] -side right
		BindPopup $nextLevel.head.clear "Clear values in this submodel"
	    }
	    if {![string length $level]} {
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
    MergeParams $topNode $smPath $metaFile 0

    foreach inputPath [array names whichParamsAffected] {
	AcceptData winId $topNode $inputPath -1
    }
}

proc DoneParams {topNode} {
    global widgetNames paramData

    foreach compName [array names widgetNames] {
	AcceptData winId $topNode $compName 1
    }
    if {![llength $paramData(needed)]} {
	set paramData(done) 1
    } else {
	set paramData(complete) -1
    }
}

proc AcceptData {winId topNode compName complain} {
    global paramDims paramData widgetNames runState inputHelper msgs

    set node [GetCompProperty $topNode IdFromCapt $compName]
    if {$complain > -1} {
	if {![string equal disabled [$widgetNames($compName).e cget -state]]} {
	    set newData [UglifyValList [$widgetNames($compName).e get]]
	    if {![string equal $newData $paramData($compName)]} {
		set msgs(param_source_$compName) Unsaved
		set paramData($compName) $newData
	    }
	}
    }
    
    set dataChanged 0
# for each constant value, check whether it has been changed, and if so,
# flag a complete model rebuild. Do same if running_c lost due to crash
# or model not yet started
    if {$runState($topNode,modelRunning)<=2} {
	set dataChanged 1
    } elseif {[catch {GetCompProperty $topNode Value $node} oldVal]} {
	set dataChanged 1
    } elseif {[string compare [lindex $oldVal 0] $paramData($compName)]} {
	set dataChanged 1
    }
    # Make array form if data has changed
    if {$dataChanged} {
#	set msgs(param_source_$compName) Unsaved
# only if the actual entry field has been edited
	set trans [GetTransTable $node]

	# Now replace each -1 in the dims with the id of the by-record
	# submodel it represents
	set recordDims $paramDims($compName)
	set afterTIME [string equal TIME [lindex $recordDims 0]]
#puts "node $compName has dims $recordDims"
	while {[set recordDepth [rsearch $recordDims RECORDS]] != -1} {
#puts "recordDims $recordDims recordDepth $recordDepth" 
	    foreach recordId [array names paramData] {
#puts "recordId is $recordId"
		if {[string first $recordId $compName]==0 && \
		    ![string equal $recordId $compName]} {
		    set recordNode [GetCompProperty $topNode \
					IdFromCapt $recordId]
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
#puts "About to ListToArray $node {} $trans $recordDims $paramData($compName)"
	if {[catch {ListToArray $topNode $node {} $trans $recordDims \
			$paramData($compName)} result]} {
# new bit for using it as an input tool: notify that we have values
	    lappend paramData(needed) $compName
	    if {$complain>-1} {
		$widgetNames($compName).l configure -fg red
		if {$complain>0} {
		    if {[llength $result]>1} {
			set where " at indices [lrange $result 0 end-1]"
		    } else {
			set where {}
		    }
		    ShowMessage "Setting $compName" warning "While attempting to load the parameter value$where the following problem occurred: [lindex $result end]" ok
		}
	    }
	} else {
	    if {$complain>-1} {
		$widgetNames($compName).l configure -fg black
	    }
	    set paramData(needed) [purge $paramData(needed) $compName]
	    if {$result<1} {
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

proc ListToArray {topNode tgt subs trans dims list} {
#do_in_editor puts "Go! tgt $tgt trans $trans list $list"
# skip over any vm arrays, their indices will not appear
# in calls for values, but keep the translation list in sync
# ... string match stops cleanly at end of list
    global comboTypes
    while {[string match MEMBERS [lindex $dims 0]]} {
	set trans [lrange $trans 1 end]
	set dims [lrange $dims 1 end]
    }
    set thisTrans [lindex $trans 0]
    if {![llength $dims]} {
	switch [llength $list] {
	    0 {
		error [list "Missing value"]
	    } 1 {
		if {![string last ,NOW $subs 3]} {
		    set idAndSubs $tgt[string range $subs 4 end]
		    set comboTypes($idAndSubs) $list
		    EnumTypeToNumber [InputVarFor $topNode $tgt] $idAndSubs \
			$list $thisTrans
		    return 1
		} else {
		    EnumTypeToNumber paramData $tgt$subs $list $thisTrans
		    return 0
		}
	    } default {
		error [list "Array $list supplied instead of scalar"]
	    }
	}
    }
    if {[llength $list]==1} {
#puts "setting paramData($tgt) to $headNum"
	set userDims [join $dims { x }]
	error [list "scalar $list supplied instead of array of $userDims"]
    }
    if {[llength $list]%2} {
	error [list [lindex $list end] "Missing value"]
    }
	
    foreach {indx sublist} $list {
# was array set sub $list...above would allow us to check that all indices were
# the right type if we could be bothered...OK then...
	set role "Index value"
	if {[string match TIME [lindex $dims 0]]} {
	    set role "Time point"
	    if {!([string is double $indx] || [string equal NOW $indx])} {
		error [list "$role $indx must be NOW or a number."]
	    }
	} elseif {[string compare {} $thisTrans]} {
	    set poss [lsearch $thisTrans $indx]
	    if {$poss == -1} {
		error [list "$role $indx is not a member of type [lindex $thisTrans 0], pick one of [lrange $thisTrans 1 end]."]
	    }
	} elseif {![string is integer $indx]} {
	    error [list "$role $indx is not an integer."]
	}
	if {[info exists sub($indx)]} {
	    error [list "$role $indx appears more than once."]
	}
	set sub($indx) $sublist
    }

#puts "dims remaining $dims"
    if {[string match TIME [lindex $dims 0]]} {
# If time, we can have as many or as few vals as we want, and they can be
# any positive number. If there are values other than NOW, do an init step

# not quite working, note that later dimensions for a time point are treated
# just like other dimensions, i.e., all must be set
	set redoStep 1
# Next call removes old time series data from the system
	EnumTypeToNumber [InputVarFor $topNode $tgt] $tgt {} {}
	foreach arrayPt [array names sub] {
	    if {[string equal NOW $arrayPt]} {
		if {[llength $subs]} {
		    error [list "NOW must be outermost index."]
		}
	    } elseif {![string is double $arrayPt]} {
		error [list $arrayPt "Time point must be NOW or a number."]
	    }
	    if {[catch {ListToArray $topNode $tgt $subs,$arrayPt $trans \
			    [lrange $dims 1 end] $sub($arrayPt)} step]} {
		error [concat $arrayPt $step]
	    } elseif {$step<1} {
		set redoStep -1
	    }
	}
	return $redoStep
    } 
    if {[llength [lindex $dims 0]]==2 && \
	    [string match RECORDS [lindex [lindex $dims 0] 0]]} {
# by-record submodel; check up to biggest. If new data here, only a reset
# needed to set it

# OK hows this for branez...use
# the number of elements, because if there is an element larger than the
# number of elements, one the same or smaller will be missing!
	set last [array size sub]
	if {!$last} {
	    error [list "Per-record submodel must have values for at least one member."]
	}

#puts "Setting [lindex [lindex $dims 0] 1]$subs to $last"
	EnumTypeToNumber paramData [lindex [lindex $dims 0] 1]$subs $last {}
# probably won't work anyway for time series
	set requireStep 0
    } else {
	set last [lindex $dims 0]
	set requireStep -1
    }
    set redoStep 1
    for {set arrayPt 1} {$arrayPt <= $last} {incr arrayPt} {
	set indx [NumberToEnumType $arrayPt $thisTrans]
	if {![info exists sub($indx)]} {
#puts "No $indx in [array names sub]"
	    error [list $indx "Missing value"]
	}
	if {[catch {ListToArray $topNode $tgt $subs,$arrayPt \
			[lrange $trans 1 end] [lrange $dims 1 end] \
			$sub($indx)} mis]} {
	    error [concat $indx $mis]
	} elseif {$mis<1} {
	    set redoStep $requireStep
	}
    }
    return $redoStep
}
	    
proc EnumTypeToNumber {varData tgt head trans} {
    global $varData

    if {![llength $head]} {
# empty head, signal to clear out old values
	foreach oldEntry [array names $varData $tgt*] {
	    unset ${varData}($oldEntry)
	}
    } elseif {[string compare {} $trans]} {
	set poss [lsearch $trans [lindex $head 0]]
	if {$poss == -1} {
	    if {[string equal false [lindex $trans 0]]} {
		error [list "Data value $head is not a member of type boolean, pick one of $trans."]
	    } else {
		error [list "Data value $head is not a member of type [lindex $trans 0], pick one of [lrange $trans 1 end]."]
	    }
	} else {
	    set ${varData}($tgt) $poss
	}
    } elseif {![string is double $head]} {
	error [list "Data value $head is not a number."]
    } else {
	set ${varData}($tgt) $head
    }
#puts "just went set paramData($tgt) $paramData($tgt)"
}

proc NumberToEnumType {idx trans} {
    if {[llength $trans]} {
	return [lindex $trans $idx]
    } else {
	return $idx
    }
}

proc RevertData {winId compName} {
    global paramData widgetNames
    $widgetNames($compName).e delete 0 end
    if {[info exists paramData($compName)]} {
	$widgetNames($compName).e insert 0 $paramData($compName)
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
    global paramState paramData widgetNames SimileProject msgs
    foreach spfName [array names SimileProject fileparam,$smPath*] {
	unset SimileProject($spfName)
    }
    foreach compName [array names widgetNames $smPath*] {
#	array unset paramState $compName
#	array unset paramData $compName
	$widgetNames($compName).e configure -state normal
	$widgetNames($compName).e delete 0 end
	set msgs(param_source_$compName) Unsaved
    }
}

proc Save {spare smPath} {
    global paramState paramData widgetNames SimileProject simtmpdir env msgs
#ShowMessage debug info "Save $smPath" ok
    
    set metaFile [ChooseFile params.spf "Save parameters as:" 1]
    set SimileProject(fileparam,$smPath) $metaFile
    if {[llength $metaFile]} {
	set part [file join $simtmpdir temp_out.spf]
        set pStr [NetOpen $part w]
        
        foreach compName [array names widgetNames $smPath*] {
	    set compTail [string range $compName [string length $smPath] end]
	    set SubbedComp [StripCrs $compTail]
	    set newPopup  "Specified by $metaFile"
	    if {[ReferenceWorks $compName]} {
		set relName [Relativize $metaFile \
				 [lindex $paramState($compName) 0]]
		puts $pStr "$SubbedComp=reference=[lreplace \
                                $paramState($compName) 0 0 $relName]"
		set msgs(param_source_$compName) [concat $newPopup \
						      (reference to $relName)]
	    } else {
		puts $pStr "$SubbedComp=literal=$paramData($compName)"
		set msgs(param_source_$compName) "$newPopup (literal)"
	    }
	}
        close $pStr
	set PartType "application/x-simile"
	set Description "Simile parameter file"
	set style attachment
	set newMime [mime::initialize -canonical $PartType \
			 -header [list "Content-Disposition" $style] \
			 -header [list "Content-Description" $Description] \
			 -header [list "Simile-Version" $env(SIMILE_VERSION)] \
			 -header [list "Simile-Origin" file-param-dialogue] \
			 -file $part]
	set stream [NetOpen $metaFile w]
        fconfigure $stream -translation binary
        mime::copymessage $newMime $stream
        # clean everything up
        close $stream
        mime::finalize $newMime
	file delete $part
    }
}

# merge a parameter metafile. These are saved with the pathnames of the .csv files
# relative to the location of the metafile, so in order to reload the .csvs we need to
# reconnect them with this pathname...trouble is, if I save in a new directory I'll need
# new relative pathnames and I can only generate these starting from the absolute
# pathname. And the only way to get that without a hack is to cd to it...

proc Open {topNode smPath} {
    global SimileProject
    set smName [file tail $smPath]
    set metaFile [ChooseFile params.spf "Load $smName parameters from:" 0]
    set SimileProject(fileparam,$smPath) $metaFile
    if {[llength $metaFile]} {
	MergeParams $topNode $smPath $metaFile 1

    }
}
}

proc MergeParams {topNode smPath oldPath interactive} {
    global paramState paramData widgetNames mimeSquirter simtmpdir \
	whichParamsAffected msgs

#do_in_editor puts "MergeParams $topNode $smPath $oldPath $interactive"    
    set oldDir [pwd]
    if {[catch { 
	set multiT [mime::initialize -file $oldPath]
	set origVersion [mime::getheader $multiT Simile-Version]
	set metaFile [file join $simtmpdir temp_in.spf]
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
	set IdAndValue [split $savedValue =]
	set restoredComp [RestoreCrs $smPath[lindex $IdAndValue 0]]
	if {$origVersion<4.0} {
	    # pre-multiple desktop -- trim outermost model
	    if {[string equal /Desktop/ [string range $restoredComp 0 8]]} {
		set restoredComp [string range $restoredComp 8 end]
	    }
	}
        #ShowMessage debug info "Component is $restoredComp" ok
	set node [ExistCheck $topNode $restoredComp {The file}]
	switch $node {
	    break {break}
	    continue {continue}
	}
	set nType [GetCompProperty $topNode Eval $node]
	set startLine [lsearch {INPUT TABLE} $nType]
	if {$startLine!=-1} {
	    if {$origVersion>=4.0} {
		set paramData($restoredComp) [lindex $IdAndValue 2]
		set reference [string equal reference [lindex $IdAndValue 1]]
		if {$reference} {
		    set VFile [lindex $paramData($restoredComp) 0]
		}
	    } else {
		set paramData($restoredComp) [TrimFields \
						  [lindex $IdAndValue 1]]
		set VFile [lindex $paramData($restoredComp) 0]
		set reference [file exists [file join [file dirname $oldPath] \
						$VFile]]
	    }
	    #ShowMessage debug info "Param data is $paramData($restoredComp)" ok
                
	    set newPopup "Specified by $oldPath"
                # OK here we go...try and follow this...first go to the starting point..
	    if {$reference} {
		# Now use the saved relative path to move to the .csv file's directory
		cd [file join [file dirname $oldPath] [file dirname $VFile]]
		# ...and stick the new absolute pathname into the spec! Easy!!
		set paramState($restoredComp) \
		    [concat [list [pwd]/[file tail $VFile]] \
			 [lrange $paramData($restoredComp) 1 end]]
                    # now just load up the data
                    #ShowMessage debug info "Field spec set to $paramState($restoredComp)" ok
		set paramData($restoredComp) \
		    [LoadTableData $paramState($restoredComp) $startLine]
		set whichParamsAffected($restoredComp) 1
		set msgs(param_source_$restoredComp) [concat $newPopup \
			  (reference to $VFile)]
	    } else {
		set trans [GetTransTable $node]
		if {[string equal INPUT $nType]} {
		    set trans [linsert $trans 0 {}] ;# dont translate times
		}
		if {[SensibleValue $trans $paramData($restoredComp)]>1} {
		    set whichParamsAffected($restoredComp) 1
		    set msgs(param_source_$restoredComp) "$newPopup (literal)"
		} else {
		    ShowMessage "Error merging parameters" error "Parameterization file contained the entry $paramData($restoredComp) for component $restoredComp. This entry does not start with the name of an existing file, nor is it a numerical value, boolean, or one of the enumerated types defined for this component, which are $trans." ok
		    set paramData($restoredComp) {}
		}
	    }
        if {$interactive} {
        #$widgetNames($restoredComp).e 
		FillIfSmall $widgetNames($restoredComp).e \
		    $paramData($restoredComp)
	    }
	}
    }
    close $pStr
    if {$origVersion>=4.0} {
	file delete $metaFile
    }
    cd $oldDir
}

proc ExistCheck {topNode restoredComp source} {
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

    set node [GetCompProperty $topNode IdFromCapt $restoredComp]
    if {[string equal nomatch $node]} {
	set nextLook $restoredComp
	while {[string equal nomatch $node]} {
	    set lostBit $nextLook
	    set nextLook [join [lrange [split $lostBit /] 0 end-1] /]
	    if {[llength $nextLook]} {
		set node [GetCompProperty $topNode IdFromCapt $nextLook]
	    } else {
		set node $topNode
	    }
	}
	if {[string equal $lostBit $restoredComp]} {
	    set lostType component
	} else {
	    set lostType submodel
	}
	set act [ShowMessage "Unused parameters" warning "$source contains parameter values for the $lostType $lostBit, which does not exist in the model. Do you want to ignore these values and continue reading the file?" okcancel]
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

# This checks whether a parameter really has the value specified by its
# .csv file reference

proc ReferenceWorks {compName} {
#    global paramState paramData widgetNames 
    global msgs

#    if {[string equal normal [$widgetNames($compName).e cget -status]]} {
# if entry is editable, check match for table data
#	if {[info exists paramState($compName)]} {
#	    return [string equal $paramData($compName) \
#			[LoadTableData $paramState($compName)]]
#	} else {
#	    return 0
#	}
#    } else {
# if not, get its status from the popup info -- it will not have changed
	return [expr !([string match *(literal) $msgs(param_source_$compName)] \
		   || [string equal Unsaved $msgs(param_source_$compName)])]
#    }
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

# useful proc which returns 1 for an int, 2 for a float, 1 for a member of the 
# supplied list (used for enum types) and 0 for all else

proc VarType {testVar types} {
    if {[string is integer $testVar]} {
        return 2
    } elseif {[string is double $testVar]} {
        return 3
    } elseif {[lsearch $types $testVar]!=-1} {
	return 2
    } elseif {[string equal NOW $testVar]} {
	return 1
    } else {
	puts "No $testVar in $types"
        return 0
    }
}

proc GetFromTable {parent compName startLine} {
    global paramState paramData widgetNames table_entry msgs
    if {[info exists paramState($compName)]} {
	set table_entry(data) $paramState($compName)
    } else {
	set table_entry(data) {}
    }
    if {[string match normal [$widgetNames($compName).e cget -state]]} {
	set table_entry(values) [UglifyValList [$widgetNames($compName).e get]]
    } else {
	set table_entry(values) $paramData($compName)
    }
    set newSource [equationDoTable $parent $compName $startLine]
    if {$newSource} {
        if {[llength $table_entry(dataField)]} {
	    set paramState($compName) [concat [list $table_entry(fileName) \
						   $table_entry(dataField)] \
					   $table_entry(indices)]
	}
        set paramData($compName) $table_entry(values)
        FillIfSmall $widgetNames($compName).e $paramData($compName)
	switch $newSource {
	    2 {
		set msgs(param_source_$compName) \
		    [list Loaded from $table_entry(fileName) \
			 Column: $table_entry(dataField)]
		if {[llength $table_entry(indices)]} {
		    lappend msgs(param_source_$compName) \
			[concat \(index columns: $table_entry(indices)\)]
		}
	    } 1 {
		set msgs(param_source_$compName) Unsaved
	    }
	}
    }
}

# try to minimize effort at runtime -- list timepoints for each node...
proc InitTimeSeries {topNode} {
    global setFromSeries paramData
    array unset setFromSeries
    foreach node [GetCompProperty $topNode Objects] {
	if {[string match INPUT [GetCompProperty $topNode Eval $node]]} {
#puts "node $node timePts [array names paramData $node,*]"
	    foreach timePt [array names paramData $node,*] {
		set ${node}([lindex [split $timePt ,] 1]) 1
	    }
	    if {[array size $node]} {
		set setFromSeries($topNode,$node,times) \
		    [lsort -real [array names $node]]
		set setFromSeries($topNode,$node,next) 0
#puts "initted $setFromSeries($topNode,$node,times)"
	    }
	}
    }
}

proc ResetTimeSeries {topNode} {
    global setFromSeries
    foreach pt [array names setFromSeries $topNode,*,next] {
	set setFromSeries($pt) 0
    }
}

# for each node we have a list of times in the time series, and a pointer to 
# where we are in the list. If the time has gone past that pointed to, signal 
# the data to be written and look at the next one...
proc UpdateTimeSeries {topNode newTime} {
    global setFromSeries paramData comboTypes
    foreach list [array names setFromSeries $topNode,*,times] {
	set node [lindex [split $list ,] 1]
#puts "node $node times $setFromSeries($list) next $setFromSeries($topNode,$node,next) newTime $newTime"
	set jumping 1
	while {$jumping} {
	    upvar 0 setFromSeries($topNode,$node,next) series
	    if {[llength $setFromSeries($list)] > $series} {
		set oldTime [lindex $setFromSeries($list) $series]
		if {$newTime >= $oldTime} {
		    set useTime $oldTime
		    incr series
		} else {
		    set jumping 0
		}
	    } else {
		set jumping 0
	    }
	}

	if {[info exists useTime]} {
	    set tgtVar [InputVarFor $topNode $node]
	    upvar \#0 $tgtVar inputSrc
#puts "inputSrc stands for [do_for_node $topNode InputVarFor $node]"
	    # do it the easy way if a scalar
#puts "looking for paramData($node,$useTime)"
#	    if {[info exists paramData($node,$useTime)]} {
#		set inputSrc($node) $paramData($node,$useTime)
#puts "set inputSrc($useTime) $paramData($node,$useTime)"
#		return
#	    }
	    set trans [lindex [GetTransTable $node] end]
	    foreach tsValue [concat [array names paramData $node,$useTime] \
				 [array names paramData $node,$useTime,*]] {
#puts "setting inputSrc([join [lreplace [split $tsValue ,] 1 1] ,])"
		set tgtIndex [join [lreplace [split $tsValue ,] 1 1] ,]
		set inputSrc($tgtIndex) $paramData($tsValue)
		if {[string match comboChoices $tgtVar]} {
		    set comboTypes($tgtIndex) \
			[TransValue $trans $paramData($tsValue)]
		}
	    }
	}
    }
}

