# Simile source code file: Run/support.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures that have to go in the same interpreter as
# the model, e.g., because they are called from it, or pass data using upvar.
# Actually none of them have to but it makes things more consistent with the
# c++ implementation.

# var containing namespace id called 'this' for compatibility with c++
set this ::AME_model<>

# searching through records like this is not the best way -- try and change
# the tcl model code so the node id is the index

proc findRecord {node} {
    global nodedata

    foreach record [array names nodedata] {
	if {[string equal $node [lindex $nodedata($record) 0]]} {
	    return $nodedata($record)
	}
    }
}

proc getinfo {node field} {
    return [lindex [findRecord $node] [expr $field+1]]
}

# Graph handling stuff

proc setup_graph_data {args} {
    eval {graph_table 22} $args
}

proc release_graph_data {graph_data_pointer} {
    # no need to release in tcl
}

# this procedure takes the data describing a function entered as a graph, and a
# point on the x axis, and returns the y axis point. It is called from the
# procedure that executes the model.


proc graphpoint {xval index} {
    graph_table 23 $index $xval
}

# Stuff related to getting values

proc setup_enum_type_data {args} {
}

proc tcl_insert {node newVs} {
    global nodedata

    foreach record [array names nodedata] {
	if {[string equal $node [lindex $nodedata($record) 0]]} {
	    set tree [lindex $nodedata($record) 6]
	    set type [lindex $nodedata($record) 1]
	    set dims [GetTclCompProperty dummy Dims $node]
	    return [list [FillValue ::AME_model<> $tree $type $dims \
			      {} 0 $newVs]]
	}
    }
    return novalue
}

# right now to get the node id
proc GetNodeIdFromRef {dest indices} {
    global nodedata nodecount
    for {set record 0} {$nodecount>$record} {incr record} {
	if {[string equal $dest [burrow_to ::AME_model<> \
				    [lindex $nodedata($record) 6] $indices]]} {
	    return [lindex $nodedata($record) 0]
	}
    }
}

proc collect {tgt node count args} {
    global myNode
# ShowMessage debug info "Collecting...$tgt...$node...$count...$args" ok
    if {[string match TABLE [getinfo $node 3]]} {
	set inputSrc paramData
    } else {
	set inputSrc [InputVarFor $myNode $node]
#	switch [getinfo $node 0] {
#	    FLAG {
#		set inputSrc checkStates
#	    } ENUMERATED {
#		set inputSrc comboChoices
#	    } default {
#		set inputSrc sliderVals
#	    }
#	}
    }
#    set sub [join [concat $node $args] ,]
    set val [BringParameter $inputSrc $node $args]
    if {[llength $val]} {
# Check that input source exists, it will not if model is being initialized
	set $tgt $val
    }
}

proc getinstance {varName dest newvalue} {
    # If newvalue exists, it should be copied to target and returned
    upvar 1 $varName target
    upvar 1 $dest returnList

    if {[string compare $newvalue NULL]} {
        set target $newvalue

    } ;# end(if,$set)
    lappend returnList $target
    return $returnList
} ;# end(procedure,getinstance)

proc step_incr {step v} {
    return [expr $v*[glob_element dts $step]]
}

proc stage_incr {ns_extras step v} {
    upvar \#0 $ns_extras extras
    if {![info exists extras]} {
	set extras [list 0 0]
    }

    set dv [step_incr $step $v]
    switch [expr int([glob_element dts 0])] {
	0 {
	    return $dv
	} 1 {
	    set current_offset [expr $dv/2.0]
	    set extras [list [expr $dv/6.0] $current_offset]
	    return $current_offset
	} 2 {
	    set current_offset [expr $dv/2.0]
	    set old_offset [lindex $extras 1]
	    set extras [list [expr [lindex $extras 0]+$dv/3.0] $current_offset]
	    return [expr $current_offset-$old_offset]
	} 3 {
	    set old_offset [lindex $extras 1]
	    set extras [list [expr [lindex $extras 0]+$dv/3.0] $dv]
	    return [expr $dv-$old_offset]
	} 4 {
	    return [expr [lindex $extras 0]+$dv/6.0-[lindex $extras 1]]
	}
    }
}

proc do_model {what mtime mstep} {
    if {[catch {eval ::AME_model<>::${what} $mtime $mstep}]} {
	RaiseTclExecError $what $mtime $mstep
    }
}

proc RaiseTclExecError {mproc mtime mstep} {
    global myNode errorInfo model_prog

    set errorList [split $errorInfo \n]
    set whoopsie [lindex $errorList 0]
    set modelLine [lindex $errorList end-5]
    regexp { (\d+)\)$} $modelLine spare lineNo
    set mStream [open $model_prog($myNode) r]
    set mLine {}
    while {![string match "proc $mproc *" $mLine]} {
	gets $mStream mLine
    }
#puts "found proc $mLine"
    for {set procLine 1} {$procLine < $lineNo} {incr procLine} {
	gets $mStream mLine
    }
#puts "picked line $mLine"
    close $mStream
    if {[regexp {set ([^ ]*) .*} $mLine spare targetName]} {
	set dest [namespace eval AME_model<> "set spare $targetName"]
    } else {
	set dest none
    }
    error [list $mproc $dest $mtime $mstep $whoopsie] $errorInfo
}

proc CheckGUI {modelTime thisOp} {
    global GUILog
    
    set flash 20
    # first record how much time the last op took
    set thisUpdate [clock clicks -milliseconds]
    if {[info exists GUILog(lastExit)]} {
	set GUILog($GUILog(lastOp),took) [expr $thisUpdate-$GUILog(lastExit)]
	set currentOld [expr $thisUpdate-$GUILog(lastUpdate)>$flash]
    } else {
	set currentOld 1
    }
    set GUILog(lastOp) $thisOp
    
    if {[info exists GUILog($thisOp,took)]} {
	set startingLong [expr $GUILog($thisOp,took)>$flash]
    } else {
	set startingLong 1
    }
    
    if {$currentOld || $startingLong} {
	set result [InteractGUI $modelTime]
	set thisUpdate [clock clicks -milliseconds] ;# GUI may have taken time
	set GUILog(lastUpdate) $thisUpdate
    } else {
	set result 0
    }
    set GUILog(lastExit) $thisUpdate
    return $result
}
    
proc TclResetModel {topPhase} {
    global ts steps phasecount
    for {set tweakPhase 1} {$tweakPhase <= $phasecount} {incr tweakPhase} {
	set ts($tweakPhase) [expr -$steps($tweakPhase)]
    }
    SetDTs 1 0
    AdvanceTime 1 1
    do_model int_evalmodel 0 $topPhase
    return 1
}

proc TclExecuteModel {howInt start end} {
    global dts steps phasecount
#    if {[string equal cancel [ShowMessage debug info "XM from $start to $end" okcancel]]} {
#	error cancelled
#    }
    set freq $steps($phasecount)
    for {set xtime [expr (floor($start/$freq+1.5))*$freq]} \
	{$xtime<=$end+0.5*$freq} {set xtime [expr $xtime+$freq]} {
	    set bigPhase [PhaseFor $xtime $freq [expr $phasecount+1]]
	    if {[CheckGUI $xtime ph$bigPhase]} {
		return 0
	    }
	    SetDTs $bigPhase $xtime
	    do_model advancemodel $xtime $bigPhase
	    switch -exact -- $howInt {
		Euler {
		    AdvanceTime $bigPhase 1
		    set dts(0) 0
		    do_model updatemodel $xtime $bigPhase
		} {Runge-Kutta} {
		    RKUpdate $xtime $bigPhase
		} default {
		    ShowMessage "Execution problem" error "Integration method $howInt not supported" ok
		}
	    }
	    do_model int_evalmodel $xtime $bigPhase
	}
    CheckGUI $end ext
    return 1
}
	    
proc PhaseFor {current step soFar} {
#ShowMessage debug info "PhaseFor $current $step $soFar" ok
    global steps
    if {$soFar == 1} {
	return 1
    }
    set try [expr $soFar-1]
    set nextStep $steps($try)
    set last [expr $current-($step/2.0)]
    set next [expr $last+$step]

    set tryCurrent [expr $nextStep*floor($last/$nextStep)]
    set tryNext [expr $nextStep*floor($next/$nextStep)]
    if {$tryCurrent == $tryNext} {
	return $soFar
    } else {
	return [PhaseFor $tryNext $nextStep $try]
    }
}

proc RKUpdate {current phase} {
    global dts
    set dts(0) 1
    do_model updatemodel $current $phase
    AdvanceTime $phase 0.5
    set dts(0) 2
    do_model int_evalmodel $current $phase
    do_model updatemodel $current $phase
    set dts(0) 3
    do_model int_evalmodel $current $phase
    do_model updatemodel $current $phase
    AdvanceTime $phase 0.5
    set dts(0) 4
    do_model int_evalmodel $current $phase
    do_model updatemodel $current $phase
    set dts(0) 1
}
    
proc SetDTs {phase current} {
    global ts dts phasecount
    for {set tweakPhase $phase} {$tweakPhase<=$phasecount} {incr tweakPhase} {
	set dts($tweakPhase) [expr $current-$ts($tweakPhase)]
    }
}

proc AdvanceTime {phase fraction} {
    global ts dts phasecount
    for {set tweakPhase $phase} {$tweakPhase<=$phasecount} {incr tweakPhase} {
	set ts($tweakPhase) [expr $ts($tweakPhase)+$dts($tweakPhase)*$fraction]
    }
}

#proc at_time_step {} {
#    return [expr [glob_element dts 0]<=1]
#}
#
proc loses {prob phase} {
    if {$prob >= 1} {
	return 1
    } else {
	set kills_per_step [expr [glob_element dts 0]?4:1]
	return [expr [ame_rand 0 1] > \
		    pow(1-$prob, [glob_element dts $phase]/$kills_per_step)]
    }
}

# delete_list is a dummy procedure. What it should do is clear the
# submodel instances from the list supplied, but since (a) it would also
# need the parent namespace and (b) they tend to get reused anyway in
# tcl, I have not bothered.

proc delete_list {list_id} {
}

# When there are multiple models, prune will be called with some reference
# to the source namespace. For now we add that inside the proc...

proc prune {target metaTxt idCount} {
    upvar 1 $metaTxt meta
    set status 1
    while {[string compare [set $meta] 0] && \
                [set status [compare_instance_status \
                [set submodelptr [set $meta]]::instanceid \
                $target $idCount]]==-1} {
        set $meta [set ${submodelptr}::next]
        namespace delete $submodelptr
    }
    return [expr !$status]
}

proc compare_instance_status {testInstName refInst num} {
    upvar 1 $testInstName testInst
    #    ShowMessage debug info "testInst $testInst refInst $refInst" ok
    if {[string match 0 $testInst]} {return 1}
    for {set ptr 0} {$ptr < $num} {incr ptr} {
        if {[lindex $testInst $ptr]<[lindex $refInst $ptr]} {return -1}
        if {[lindex $testInst $ptr]>[lindex $refInst $ptr]} {return 1}
    }
    return 0
}

proc compare_values {v1 indexTxt v2 length step} {
    # ShowMessage debug info "compare_values\n$v1\n$indexTxt\n$v2\n$length\n$step" ok
    upvar 1 $indexTxt index
    compare_lists 1 $v1 index $v2 $length $step
}

proc compare_lists {count nestlist1 indexTxt list2 length step} {
    upvar 1 $indexTxt index

    set hunting 2

    while {$hunting==2} {
        if {$index >= $length} {
            set hunting 0
        } else {
            set list1 [lindex $nestlist1 $index]
            set hunting [compare_tcl_lists $count $list1 $list2]
            if {$hunting == 2} {
                incr index $step
            }
        }
    }
    return $hunting
}

proc compare_tcl_lists {count list1 list2} {

    for {set ptr 0} {$ptr < $count} {incr ptr} {
        set diff [expr [lindex $list1 $ptr]-[lindex $list2 $ptr]]
        if {$diff < 0} {
            return 2 ; Dead parent condition
        }
        if {$diff > 0} {
            return 0 ; Non-existence condition
        }
    }
    return 1
}
proc init_pop_member {new_one index parent channel} {
    upvar 1 $new_one tgt

    set ${tgt}::instanceid $index
    set ${tgt}::parentId $parent
    set ${tgt}::channelId $channel
    set ${tgt}::new_instance 1
    set ${tgt}::next 0
}

proc ame_rand {lowBound highBound} {
    return [expr $lowBound +[random01]*($highBound - $lowBound)]
}


proc stop {code} {
    error "User-defined interruption code $code"
}

proc FillListValues {nextRefPtr newTree type innerDims listDims dimPlace} {
    upvar 1 $nextRefPtr nextRef
#puts "FLV $nextRef $listDims $dimPlace"
    set result {}
    set smHandle $nextRef
    set nextElt [set [burrow_to $smHandle {2 0} {}]]
    set newDimPlace [expr $dimPlace+1]
    while {[string match $listDims [lrange $nextElt 0 $dimPlace]]} {
	if {[llength $nextElt] == $newDimPlace} {
	    set result [FillValue $smHandle $newTree $type $innerDims {} 0 {}]
	    set nextRef [set [burrow_to $smHandle {1 0} {}]]
	} else {
	    set newIndex [lindex $nextElt $newDimPlace]
	    set subVals [FillListValues nextRef $newTree $type $innerDims \
				[concat $listDims $newIndex] $newDimPlace]
	    if {[llength $subVals]} {
		lappend result $newIndex $subVals
	    }
	}
	if {[string compare $nextRef 0]} {
	    set smHandle $nextRef
	    set nextElt [set [burrow_to $smHandle {2 0} {}]]
	} else {
	    break
	}
    }
    return $result
}

proc FillValue {smHandle tree type useDims dims dimPlace newVals} {
#do_in_editor puts \
	   "filling tree $tree bounds $useDims inds $dims place $dimPlace"
    set nextUseDim [lindex $useDims 0]
    if {[lsearch {RECORDS MEMBERS START_VM} $nextUseDim]!=-1} {
	set breakPt [lsearch $tree -1]
	set oldTree [lrange $tree 0 [expr $breakPt-1]]
	set newTree [lrange $tree [expr $breakPt+1] end]
	set nextRef [set [burrow_to $smHandle $oldTree $dims]]
	set result {}
	array set arrayVals $newVals

	if {[string compare $nextRef 0]} {
	    if {[string equal START_VM $nextUseDim]} {
		set cutDim [expr [lsearch $useDims END_VM]+1]
	    } else {
		set cutDim 1
	    }
	    return [FillListValues nextRef $newTree $type \
			[lrange $useDims $cutDim end] {} -1]
	} else {
	    return
	}

#	while {[string compare $nextRef 0]} {
#	    set smHandle do_model $nextRef
#	    set nextElt [set [burrow_to $smHandle {2 0} {}]]
#	    lappend result $nextElt
#	    if {[info exists arrayVals($nextElt)]} {
#		set eltVals $arrayVals($nextElt)
#	    } else {
#		set eltVals {}
#	    }
#	    lappend result [FillValue $smHandle $newTree $type \
#		    [lrange $useDims 1 end] {} 0 $eltVals]
#	    set nextRef [set [burrow_to $smHandle {1 0} {}]]
#	}
#	return $result	    
    }  elseif {!$nextUseDim} {
	if {[string match VALUELESS $type]} {
	    return sm
	} else {
	    set tgtVar [burrow_to $smHandle $tree $dims]
	    set oldVal [set $tgtVar]
	    if {[llength $newVals]} {
		set $tgtVar $newVals
	    }
	    return $oldVal
	}
    } else {
	array set arrayVals $newVals
	set result {}
	for {set nextDim 1} {$nextUseDim>=$nextDim} \
		{incr nextDim} {
	    if {[info exists arrayVals($nextDim)]} {
		set eltVals $arrayVals($nextDim)
	    } else {
		set eltVals {}
	    }
	    set subVals [FillValue $smHandle $tree $type \
		    [lrange $useDims 1 end] \
		    [concat $dims $nextDim] [expr $dimPlace+1] $eltVals]
	    if {[llength $subVals]} {
		lappend result $nextDim $subVals
	    }
		    
	}
	return $result
    }
}

proc burrow_to {level id_meta dim_list} {
    while {[lindex $id_meta 0]>0} {
	append level ::[${level}::get_pointer [step_list id_meta 1] dim_list]
	if {[lindex $id_meta 0]==-1} {
	    set inst1 [set ::$level]
	    set nInds [llength [set ${inst1}::instanceid]]
	    append level <[lrange $dim_list 0 [expr $nInds-1]]>
	    set dim_list [lrange $dim_list $nInds end]
	    set id_meta [lrange $id_meta 1 end]
	}
    }
    return $level
}
	
proc step_list {dimList climb} {    
    upvar $climb $dimList useList
    set head [lindex $useList 0]
    set useList [lrange $useList 1 end]
    return $head
}

proc glob_element {arrptr phase} {
    upvar #0 $arrptr arr
    return $arr($phase)
}

# utility procs needed in both interps

proc min {first last} {
    return [expr $first<$last?$first:$last]
}

proc max {first last} {
    return [expr $first>$last?$first:$last]
}

proc following {lo} {
    return [expr $lo+1] ;# fn will accept floats so better work with them
}

proc preceding {lo} {
    return [expr $lo-1] ;# fn will accept floats so better work with them
}

proc first {lo} {
    return [expr $lo==1] ;# fn will accept floats so better work with them
}

# this version allowed supposedly unlimited nested callbacks, but the 
# rest of the system could not cope...
#
#proc do_in_editor {args} {
#    global runHow edResponse
#
#    remote [list get $args]
#    while (1) { ;# this loop onle ever once if dde/send
#	if {[string equal pipe $runHow]} {
#	    set edResponse [gets stdin]
#	} else {
#	    if {[info exists edResponse]} {unset edResponse}
#	    tkwait variable edResponse
#	} 
#	set info [lindex $edResponse 1]
#	switch [lindex $edResponse 0] {
#	    do { ;# will not happen if dde/send
#		do $info
#	    } err {
#		error [lindex $info 0] [join $info \n]
#	    } res {
#		return $info
#	    }
#	}
#    }
#}
#
#proc err {info} {
#    global edResponse
#    set edResponse [list err $info]
#}
#
#proc res {info} {
#    global edResponse
#    set edResponse [list res $info]
#}
#
# so now only simple callbacks are allowed and these are done synchronously

# set to get_data or await_cmd -- if the former, then after sending commands
# to the editor this will execute a get to read the pipe, otherwise it waits
# for a command to set the return value
#set readPipe get_data

# 'after idle' doesn't quite work in MacOS X
proc start_in_editor {args} {
    eval do_in_editor after 1 $args
}

proc do_in_editor {args} {
    global runHow sender fromEditor
#    tk_messageBox -message "callback $args"
    if {[string equal send_sync $runHow]} {
	return [eval $sender {$args}]
    }
    remote [list get $args]
#    if {[string match get_data $readPipe]} {
#	set gotResp 0
#	while {!$gotResp} {
#	    set fromEditor [gets stdin]
#	    if {[string equal do [lindex $fromEditor 0]]} {
#		eval $fromEditor
#	    } else {
#		set gotResp 1
#	    }
#	}
#    } else {
	tkwait variable fromEditor
#    }
    set info [lindex $fromEditor 1]
    switch [lindex $fromEditor 0] {
	err {
	    error [lindex $info 0] [join $info \n]
	} res {
	    return $info
	}
    }
}

proc res {value} {
    global fromEditor
    set fromEditor [list res $value]
}

proc err {value} {
    global fromEditor
    set fromEditor [list err $value]
}

proc PrefValue {arrVal val} {
    return [do_in_editor PrefValue $arrVal $val]
}

proc ContextSensitiveHelp {xcontext page} {
    global myNode
    set context [do_in_editor FindNodeTopWin $myNode]
    return [do_in_editor ContextSensitiveHelp $context $page]
}

proc exit_exec {} {
	remote done
	wm deiconify .
	after idle exit
}

proc do {argList} {
    global errorInfo
    if {[catch $argList response]} {
	set result [list err [split $errorInfo \n]]
    } else { 
	set result [list res $response]
    }
    return [remote $result]
}

proc remote {result} {
    global runHow myNode sender
    switch $runHow {
	interp {
	    return $result
	} send_async {
	    eval $sender {after idle [list FeedModel $myNode [list $result]]}
	} send_sync {
	    eval $sender {FeedModel $myNode [list $result]}
	} pipe {
	    puts [split $result \n]
	}
    }
    return done
}

