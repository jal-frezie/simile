# Interfacing the model
# =====================

# When running a model in c, the helper application commands must do slightly different
# things to pass information to and from the executing model. These are the new
# definitions that rae required for this purpose.

proc do_model {what args} {
    global running_c errorInfo model_id instance_id varName model_prog
    
    if {![info exists model_id]} {
	ShowMessage "Model not loaded" error \
	"This operation cannot be done as there is no model program loaded." \
	ok
	return 0
    }
    set mtime [lindex $args 0]
    set mstep [lindex $args 1]
    if {$mstep == -1} {
	set running_c $model_id
    } elseif {![info exists running_c]} {
	ShowMessage "Model not running" error \
	"This operation cannot be done as there is no model program running." \
	ok
	return 0
    }

    if {$model_id} {
	set head [list c_${what}model $model_id $instance_id]
    } else {
	if {[string match eval $what]}  {
	    set mproc int_evalmodel
	} else {
	    set mproc ${what}model
	}
	set head ::AME_model<>::$mproc
    }

    if [catch {eval $head $args} whoopsie] {
#	ShowMessage "$whoopsie doing model $what" error \
#	    "$what during $action of the model at time $mtime caused this: \
#	    $errorInfo" ok
#	set mess "The $what step during $action of the model at time $mtime caused this problem:\n$errorInfo"
#puts "Urrr!! Urrr!! Urrr!! $errorInfo"
	switch $what {
	    eval {set operation "calculate the value of"}
	    update {set operation "update the state"}
	    advance {set operation "advance the time point for"}
	}

	if {$model_id} {
	    set target "a value"
	} else {
	    set modelLine [lindex [split $errorInfo \n] end-5]
	    regexp { (\d+)\)$} $modelLine spare lineNo
	    set mStream [open $model_prog r]
	    set mLine {}
	    while {![string match "proc $mproc *" $mLine]} {
		gets $mStream mLine
	    }
	    for {set procLine 1} {$procLine < $lineNo} {incr procLine} {
		gets $mStream mLine
	    }
	    close $mStream
	    if {[regexp {set ([^ ]*) .*} $mLine spare targetName]} {
		set dest [namespace eval AME_model<> "set spare $targetName"]
		set targetList [DescribeComponent $dest]
		if {[catch {GetNodeIdFromRef $dest [lindex $targetList 1]} \
			 TargetId]} {
		    set target [lindex $targetList 0]
		    set whoopsie dest_missing
		} else {
		    set target "[lindex $targetList 0] (node $TargetId)"
		}
            } else {
                set whoopsie unknown
            }
	}

	switch -glob -- $whoopsie {
	    "can't read \"*\": no such element in array" - 
	    "can't read \"*\": no such variable" {
		set ref [lindex [split $whoopsie \"] 1]
                set sourceList [DescribeComponent $ref] 
		if {[catch {GetNodeIdFromRef $ref [lindex $sourceList 1]} \
			 TargetId]} {
		    set problem "it found that there was no submodel instance when trying to get [lindex $sourceList 0]"
		} else {
		    set vdesc "[lindex $sourceList 0] (node $TargetId)"
		    set problem "it found that there was no value for $vdesc"
		}
	    } dest_missing {
		set problem "it found there was no instance with these indices. This may mean that you have specified a base model instance by an index which is out of range"
	    } "User-defined interruption code *" {
		set code [lindex $whoopsie end]
		set problem "there was a user-defined interruption: $code"
	    } "Illegal operation signal *" {
		set code [lindex $whoopsie end]
		set which [lindex {SIGEOF SIGHUP SIGINT SIGQUIT SIGILL SIGTRAP 
		    SIGIOT SIGEMT SIGFPE SIGKILL SIGBUS SIGSEGV SIGSYS SIGPIPE 
		    SIGALRM SIGTERM SIGUSR1 SIGUSR2 SIGCHLD SIGPWR SIGWINCH 
		    SIGURG SIGIO SIGSTOP SIGTSTP SIGCONT SIGTTIN
		    SIGTTOU SIGVTALRM SIGPROF} $code]
		set problem "there was an OS signal: $code ($which)"
	    } "domain error: argument not in valid range" -
	    "floating-point value too large to represent" -
	    "divide by zero" {
		set problem "there was a math error: $whoopsie"
	    } default {
		# could not get cause of error, raise again as general problem
		error $errorInfo
	    }
	}

	switch -- $mstep {
	    -1 {
		set action initialization
		set timing {}
		ScrubRun 0
	    } 0 {
		set action reset
		set timing {}
	    } default {
		set action execution
		set timing " at time $mtime"
	    }
	}
	set mess "Simile ran into a problem trying to run this model. 
While it was trying to $operation $target during $action of the model$timing, $problem."
	BuildProblem none none $mess user
	return 0
    } else {
	return 1
    }
}

# right now to get the node id
proc GetNodeIdFromRef {dest indices} {
    global nodedata nodecount
    for {set record 0} {$nodecount>$record} {incr record} {
	if {[string equal $dest [burrow_to ::AME_model<> \
				    [lindex $nodedata($record) 4] $indices]]} {
	    return [lindex $nodedata($record) 0]
	}
    }
}

proc DescribeComponent {ref} {
    set hierarchy [split $ref :]
    set inds {}
    set context [MakeContext [lrange $hierarchy 6 end-1]]
    set variable [lindex $hierarchy end]
    set br [string first \( $variable]
    if {$br == -1} {
	set vdesc "variable $variable"
    } else {
	set vdesc "variable [string range $variable 0 [incr br -1]]"
	set locals [string range $variable [incr br 2] end-1]
	set vdesc "element [join $locals ,] of $vdesc"
	eval {lappend inds} $locals
    }
    return [list $vdesc$context $inds]
}

proc MakeContext {levels} {
    upvar 1 inds inds
    if {![llength $levels]} {
	return {}
    } else {
	set this [lindex $levels 0]
	set obr [string first < $this]
	set cbr [string first > $this]
	set submodel "submodel [string range $this 0 [incr obr -1]]"
	if {$cbr-$obr > 2} {
	    set locals [string range $this [incr obr 2] [incr cbr -1]]
	    set submodel "instance [join $locals ,] of $submodel"
	    eval {lappend inds} $locals
	}
	return "[MakeContext [lrange $levels 2 end]] in $submodel"
    }
}

proc SetStep {time phase} {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }
    
    if {$model_id} {
#puts "setstep $time $phase"
	c_setstepmodel $time $phase
    } else {
	do_setstepmodel $time $phase
    }
}

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

proc TransEnums {transList vals} {
#puts "Translating $vals with $transList"
    if {[llength $vals]==1} {
	set curLevel [lindex $transList 0]
	if {[llength $curLevel]} {
	    return [list [lindex $curLevel $vals]]
	} else {
	    return $vals
	}
    } else {
	set indxCount [llength [lindex $vals 0]]
	set argTrans [lrange $transList $indxCount end]
	set result {}
	foreach {index subVals} $vals {
	    lappend result [TransIndices $transList $index] \
		[TransEnums $argTrans $subVals]
	}
	return $result
    }
}

# below probly unnnecesssary cos indices always single values now
proc TransIndices {transList vals} {
    if {[llength $vals]} {
	return [concat [TransEnums $transList [lindex $vals 0]] \
	    [TransIndices [lrange $transList 1 end] [lrange $vals 1 end]]]
    } else {
	return {}
    }
}

proc TransBounds {transList vals} {
    if {[llength $vals]} {
	set level [lindex $transList 0]
	if {[llength $level]} {
	    set header [list [lindex $level 0]]
	} else {
	    set header [lindex $vals 0]
	}
	return [concat $header \
	    [TransBounds [lrange $transList 1 end] [lrange $vals 1 end]]]
    } else {
	return {}
    }
}
	    
proc GetModelTime { winId } {
    return [GetModelProperty $winId Time]
}

# Something like this which just gets model structure we want to be
# able to do as soon as the model program is loaded. So check
# existence of model_id; don't wait for instance_id or running_c
 
proc GetObjectList { winId } {
    return [GetModelProperty $winId Objects]
}

# GetModelValue returns the current value of a node. This is numerical if the
# node is scalar, a (possibly empty) list of alternating indices and values if
# the node is an array or list, and 'novalue' if it does not have one, e.g., a
# cloud or submodel.

proc GetModelValue { winId node } {
    SetModelValue $winId $node {}
}

proc SetModelValue { winId node newVals } {
    return [GetModelProperty $winId Value $node $newVals]
}

proc GetModelGraph {winId node} {
    SetModelGraph $winId $node
}

proc SetModelGraph {winId node $args} {
    return [eval GetModelProperty $winId Graph $node $args]
}

proc GetModelType { winId node } {
    return [GetModelProperty $winId Type $node]
}

proc GetModelEval { winId node } {
    return [GetModelProperty $winId Eval $node]
}

proc GetModelDims { winId node } {
    return [GetModelProperty $winId Dims $node]
}

proc GetModelClass { winId node } {
    return [GetModelProperty $winId Class $node]
}

proc GetCaptionPathFromId { winId node } {
    return [GetModelProperty $winId Caption $node]
}

proc GetIdFromCaptionPath { winId caption } {
    return [GetModelProperty $winId IdFromCapt $caption]
}

proc GetMinValue {winId node } {
    return [GetModelProperty $winId MinVal $node]
}

proc GetMaxValue {winId node } {
    return [GetModelProperty $winId MaxVal $node]
}

proc GetModelProperty {winId args} {
# translate from helper window to top node here
    return [eval GetCompProperty topNode $args]
}
    
proc GetCompProperty {topNode prop args} {
    global model_id
#puts "Getting top $topNode prop $prop arg0 [lindex $args 0] rest [lrange $args 1 end]"	
    if {![info exists model_id]} {
	WarnNoProgram
    }
    if {$model_id} {
	return [eval GetCCompProperty $topNode $prop $args]
    } else {
	return [eval GetTclCompProperty $topNode $prop $args]
    }
}

proc GetCCompProperty {topNode prop args} {
    global runState running_c model_id instance_id
    global nodedata nodecount
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Time {
	    return $runState(currentTime)
	} Objects {
	    return [lrange [listobjects $model_id] 1 end]
	} Class|Type|Eval {
	    array set propData [list Class,cIdx 11 Class,names \
			    {SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION \
			       CREATION REPRODUCTION IMMIGRATION LOSS ALARM} \
			    Type,cIdx 1 Type,names \
			    {VALUELESS REAL INTEGER FLAG EXTERNAL ENUMERATED} \
			    Eval,cIdx 2 Eval,names \
			    {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST}]
	    return [lindex $propData($prop,names) \
			    [getvalue $model_id $node $propData($prop,cIdx)]]
	} Dims {
	    set specials {RECORDS MEMBERS SEPARATE}
	    set fullList [getvalue $model_id $node 0]
	    
	    set idx 0
	    foreach elt $fullList {
		if {$elt<0} {
		    lset fullList $idx [lindex $specials [expr -$elt-1]]
		}
	    }
	    # helper apps don't need to know about separate submodels so...
	    while {[set sep [lsearch $fullList SEPARATE]]>-1} {
		set fullList [lreplace $fullList $sep $sep]
	    }
	    return $fullList
	} Graph {
	    set index [getvalue $model_id $node 3]
	    if {[llength $set]} {
		eval {setup_graph_data $index} $set
	    } else {
		return [graph_table 21 $index]
	    }
	} Caption {
	    return [getvalue $model_id $node 5]
	} IdFromCapt {
	    if {[catch {getnodeid $model_id $node} match]} {
		return nomatch
	    }
	    return $match
	} MinVal {
	    return [getvalue $model_id $node 6]
	} MaxVal {
	    return [getvalue $model_id $node 8]
	} Value {
	    if {![info exists running_c]} {
		WarnNoData
	    }	
	    set newVs [lindex $set 0]
	    # new version -- remove list wrapping sometime
	    if {[string length $newVs]} {
		return [list [insert $model_id $instance_id $node $newVs]]
	    } else {
		return [list [extract $model_id $instance_id $node]]
	    }
	}
    }
}
	    
proc GetTclCompProperty {topNode prop args} {
    global runState running_c
    global nodedata nodecount
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Time {
	    return $runState(currentTime)
	} Objects {
	    set result {}
	    for {set record 1} {$nodecount>$record} {incr record} {
		lappend result [lindex $nodedata($record) 0]
	    }
	    return $result
	} Class|Type|Eval {
	    array set propData [list Class 7 Type 0 Eval 1]
	    return [lindex [getinfo $node] $propData($prop)]
	} Dims {
	    return [lindex [getinfo $node] 2]
	} Graph {
	    set index [lindex [getinfo $node] 4]
	    if {[llength $set]} {
		eval {setup_graph_data $index} $set
	    } else {
		return [graph_table 21 $index]
	    }
	} Caption {
	    set numericPath [lindex [getinfo $node] 3]
#ShowMessage debug info "node $node data [array get nodedata] npath $numericPath" ok
	    for {set level 1} {$level < [llength $numericPath] - 1} \
		{incr level} {
		    set subpath [lrange $numericPath 0 $level]
		    lappend subpath 0
		    for {set record 1} {$nodecount>$record} {incr record} {
			if {[ListSameNumbers \
				 [lindex $nodedata($record) 4] $subpath]} {
			    append fullPath / [lindex $nodedata($record) 9]
			    break
			}
		    }
		}
	    if {[info exists fullPath]} {
		return $fullPath
	    } else {
		error "Could not find caption for node $node"
	    }
	} IdFromCapt {
	    for {set line 1} {$nodecount>$line} {incr line} {
		set id [lindex $nodedata($line) 0]
		if {[string compare $node \
			 [GetTclCompProperty $topNode Caption $id]] == 0} {
		    return $id
		}
	    }
	    return nomatch
	} MinVal {
	    lindex [getinfo $node] 5
	} MaxVal {
	    lindex [getinfo $node] 6
	} Value {
	    if {![info exists running_c]} {
		WarnNoData
	    }	
	    set newVs [lindex $set 0]
	    set nodeData [getinfo $node]
	    if {[string compare [lindex $nodeData 0] NULL]} {
		set type [lindex $nodeData 0]
		set dims [lindex $nodeData 2]
		set tree [lindex $nodeData 3]
		return [list [FillValue ::AME_model<> $tree $type $dims \
				  {} 0 $newVs]]
	    } else {
		return novalue
	    }
	}
    }
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
#    puts "filling tree $tree bounds $useDims inds $dims place $dimPlace"
    set nextUseDim [lindex $useDims 0]
    if {[lsearch {RECORDS MEMBERS} $nextUseDim]!=-1} {
	set breakPt [lsearch $tree -1]
	set oldTree [lrange $tree 0 [expr $breakPt-1]]
	set newTree [lrange $tree [expr $breakPt+1] end]
	set nextRef [set [burrow_to $smHandle $oldTree $dims]]
	set result {}
	array set arrayVals $newVals

	if {[string compare $nextRef 0]} {
	    return [FillListValues nextRef $newTree $type \
			[lrange $useDims 1 end] {} -1]
	} else {
	    return
	}

#	while {[string compare $nextRef 0]} {
#	    set smHandle ::AME_model<>::$nextRef
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

# because the data is all in order, this would be nicer if I only went through
# the table once, adding the names as I found them, but...

# Also note that we start with the numerical path of the top level model so
# its caption is _not_ included
	
# getinfo: this used to be generated, indeed what follows comes from the generator
# but the value of nodecount was the only thing that ever changed, so now this is
# just written as a global, as is the data table.

proc getinfo  {nodeName} {
    global nodedata nodecount
    for {set record 0} {$nodecount>$record} {incr record} {
        if {![string compare $nodeName [lindex $nodedata($record) 0]]} {
            return [lrange $nodedata($record) 1 end]
        } ;# end(if,![string compare $nodeName [lindex $nodedata($count) 0]])
    } ;# end(for,count)
    return [list NULL NULL NULL NULL NULL]
} ;# end(procedure,getinfo)

# and now that nodedata are variable, I can do interesting stuff
# like get a node's internal id from its caption pathname, like this. This must
# have a nice name because it's part of the helper app interface.

# this could be more efficient

proc GetPhaseCount {} {
    global model_id phasecount
    if {![info exists model_id]} {
	WarnNoProgram
	return nomatch
    }	
    if {$model_id} {
	return [c_setstepmodel 0 0]
    } else {
	return $phasecount
    }
}

proc WarnNoProgram {} {
    global errorInfo
    error "This operation cannot be done as there is no model program loaded."
}

proc WarnNoData {} {
    error "This operation cannot be done as there is no model program running."
}

# Boot on the other foot now: this is called by the model to get values from
# the helpers

proc collect {tgt node count args} {
# ShowMessage debug info "Collecting...$tgt...$node...$count...$args" ok
    if {[string match TABLE [GetCompProperty topNode Eval $node]]} {
	upvar \#0 paramData inputSrc
    } else {
	upvar \#0 [InputVarFor topNode $node] inputSrc
    }
    set sub [join [concat $node $args] ,]
# Check that input source exists, it will not if model is being initialized
    if {[info exists inputSrc($sub)]} {
	set $tgt $inputSrc($sub)
    }
}

proc InputVarFor {topNode node} {	
    switch [GetCompProperty $topNode Type $node] {
	FLAG {
	    return checkStates
	} ENUMERATED {
	    return comboChoices
	} default {
	    return sliderVals
	}
    }
    
}
