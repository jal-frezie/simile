# Interfacing the model
# =====================

# When running a model in c, the helper application commands must do slightly different
# things to pass information to and from the executing model. These are the new
# definitions that rae required for this purpose.

proc do_model {node what args} {
    global running_c errorInfo model_id instance_id varName model_prog
    
    if {![info exists model_id($node)]} {
	ShowMessage "Model not loaded" error \
	"This operation cannot be done as there is no model program loaded." \
	ok
	return 0
    }
    set mtime [lindex $args 0]
    set mstep [lindex $args 1]
    if {$mstep == -1} {
	set running_c($node) $model_id($node)
    } elseif {![info exists running_c($node)]} {
	ShowMessage "Model not running" error \
	"This operation cannot be done as there is no model program running." \
	ok
	return 0
    }

    if {$model_id($node)} {
	set head [list c_${what}model $model_id($node) $instance_id($node)]
    } else {
	if {[string match eval $what]}  {
	    set mproc int_evalmodel
	} else {
	    set mproc ${what}model
	}
	set head ::AME_model<>::$mproc
    }

    if [catch {eval do_for_node $node $head $args} whoopsie] {
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

	if {$model_id($node)} {
	    set target "a value"
	} else {
	    set modelLine [lindex [split $errorInfo \n] end-10] ;# was 5
	    regexp { (\d+)\)$} $modelLine spare lineNo
	    set mStream [open $model_prog($node) r]
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
		set dest [do_for_node $node namespace eval AME_model<> \
			      "set spare $targetName"]
		set targetList [DescribeComponent $dest]
		if {[catch {do_for_node $node GetNodeIdFromRef $dest \
				[lindex $targetList 1]} TargetId]} {
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
		if {[catch {do_for_node $node GetNodeIdFromRef $ref \
				[lindex $sourceList 1]} TargetId]} {
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
		ScrubRun $node 0
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

proc SetStep {node time phase} {
    global model_id
    if {![info exists model_id($node)]} {
	WarnNoProgram $node
    }
    
    if {$model_id($node)} {
#puts "setstep $time $phase"
	do_for_node $node c_setstepmodel $time $phase
    } elseif {$phase<0} { ;# lazy
	do_for_node $node set ts([expr -$phase]) $time
    } else {
	do_for_node $node set dts($phase) $time
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
    return [GetModelProperty $winId CurrentTime]
}

proc GetModelEndTime { winId } {
    return [GetModelProperty $winId EndTime]
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

proc ProdFromHelper {winId node caption} {
    global helperTable
    ProdObj $helperTable($winId,whichModel) $node $caption
}

proc GetModelProperty {winId args} {
    global helperTable
    set topNode $helperTable($winId,whichModel)
# translate from helper window to top node here
    return [eval GetCompProperty $topNode $args]
}
    
proc GetCompProperty {topNode prop args} {
    global runState model_id
#    puts "Getting top $topNode prop $prop arg0 [lindex $args 0] rest [lrange $args 1 end] interps [interp slaves]"	
    if {![info exists model_id($topNode)]} {
	WarnNoProgram $topNode
    }
    switch -regexp $prop {
	CurrentTime {
	    return $runState($topNode,currentTime)
	} EndTime {
	    return [expr $runState($topNode,currentTime) + \
			$runState($topNode,execTime)]
	}
    }
       
    if {$model_id($topNode)} {
	set result [eval GetCCompProperty $topNode $prop $args]
    } else {
	set result [eval GetTclCompProperty $topNode $prop $args]
    }
#puts "result $result"
return $result
}

proc GetCCompProperty {topNode prop args} {
    global running_c model_id instance_id
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Objects {
	    return [lrange [do_for_node $topNode listobjects \
				$model_id($topNode)] 1 end]
	} Class|Type|Eval {
	    array set propData [list Class,cIdx 11 Class,names \
			    {SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION \
			       CREATION REPRODUCTION IMMIGRATION LOSS ALARM} \
			    Type,cIdx 1 Type,names \
			    {VALUELESS REAL INTEGER FLAG EXTERNAL ENUMERATED} \
			    Eval,cIdx 2 Eval,names \
			    {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST}]
	    return [lindex $propData($prop,names) \
			    [c_getvalue $topNode $node $propData($prop,cIdx)]]
	} Dims {
	    set specials {RECORDS MEMBERS SEPARATE}
	    set fullList [c_getvalue $topNode $node 0]
	    
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
	    set index [c_getvalue $topNode $node 3]
	    if {[llength $set]} {
		eval {do_for_node $topNode setup_graph_data $index} $set
	    } else {
		return [do_for_node $topNode graph_table 21 $index]
	    }
	} Caption {
	    return [c_getvalue $topNode $node 5]
	} IdFromCapt {
	    if {[catch {do_for_node $topNode getnodeid $model_id($topNode) \
			    $node} match]} {
		return nomatch
	    }
	    return $match
	} MinVal {
	    return [c_getvalue $topNode $node 6]
	} MaxVal {
	    return [c_getvalue $topNode $node 8]
	} Value {
	    if {![info exists running_c]} {
		WarnNoData $topNode
	    }	
	    set newVs [lindex $set 0]
	    # new version -- remove list wrapping sometime
	    if {[string length $newVs]} {
		return [list [do_for_node $topNode insert $model_id($topNode) \
				  $instance_id($topNode) $node $newVs]]
	    } else {
		return [list [do_for_node $topNode extract \
				  $model_id($topNode) $instance_id($topNode) \
				  $node]]
	    }
	}
    }
}

# wraps c++ defined version in different interp
proc c_getvalue {topNode node action} {
    global model_id
    return [do_for_node $topNode getvalue $model_id($topNode) $node $action]
}
	    
proc GetTclCompProperty {topNode prop args} {
    global running_c
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    set nodecount [do_for_node $topNode set nodecount]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Objects {
	    set result {}
	    for {set record 1} {$nodecount>$record} {incr record} {
		lappend result [lindex [do_for_node $topNode \
					    set nodedata($record)] 0]
	    }
	    return $result
	} Class|Type|Eval {
	    array set propData [list Class 7 Type 0 Eval 1]
	    return [getinfo $topNode $node $propData($prop)]
	} Dims {
	    return [getinfo $topNode $node 2]
	} Graph {
	    set index [getinfo $topNode $node 4]
	    if {[llength $set]} {
		eval {do_for_node $topNode setup_graph_data $index} $set
	    } else {
		return [do_for_node $topNode graph_table 21 $index]
	    }
	} Caption {
	    set numericPath [getinfo $topNode $node 3]
#ShowMessage debug info "node $node data [array get nodedata] npath $numericPath" ok
	    for {set level 1} {$level < [llength $numericPath] - 1} \
		{incr level} {
		    set subpath [lrange $numericPath 0 $level]
		    lappend subpath 0
		    for {set record 1} {$nodecount>$record} {incr record} {
			set line [do_for_node $topNode set nodedata($record)]
			if {[ListSameNumbers [lindex $line 4] $subpath]} {
			    append fullPath / [lindex $line 9]
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
	    for {set record 1} {$nodecount>$record} {incr record} {
		set id [lindex [do_for_node $topNode set nodedata($record)] 0]
		if {[string compare $node \
			 [GetTclCompProperty $topNode Caption $id]] == 0} {
		    return $id
		}
	    }
	    return nomatch
	} MinVal {
	    getinfo $topNode $node 5
	} MaxVal {
	    getinfo $topNode $node 6
	} Value {
	    if {![info exists running_c]} {
		WarnNoData $topNode
	    }	
	    return [do_for_node $topNode tcl_insert $node [lindex $set 0]]
	}
    }
}
	    
proc getinfo {topNode node field} {
    do_for_node $topNode getinfo $node $field
}

# this could be more efficient

proc GetPhaseCount {topNode} {
    global model_id phasecount
    if {![info exists model_id($topNode)]} {
	WarnNoProgram $topNode
	return nomatch
    }	
    if {$model_id($topNode)} {
	return [do_for_node $topNode c_setstepmodel 0 0]
    } else {
	return [do_for_node $topNode set phasecount]
    }
}

proc WarnNoProgram {node} {
    global errorInfo
    error "This operation cannot be done as there is no model program loaded for node $node."
}

proc WarnNoData {node} {
    error "This operation cannot be done as there is no model program running for node $node."
}

proc BringParameter {array sub} {
#puts "looking for $array\($sub\)"
    upvar \#0 $array inputSrc
    return $inputSrc($sub)
}
