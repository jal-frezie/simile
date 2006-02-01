# Simile source code file: Run/hai2mmii.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file provides procedures to interface between the model and the IOTools.
# When running a model in c, the helper application commands must do slightly different
# things to pass information to and from the executing model. These are the definitions 
# that are required for this purpose.
#
proc old_do_model {node what args} {
    global errorInfo model_id instance_id model_prog
    
    if {![info exists model_id($node)]} {
	WarnNoProgram $node
    }
    set mtime [lindex $args 0]
    set mstep [lindex $args 1]

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

    if {[catch {eval $head $args}]} {
	set errorList [split $errorInfo \n]
	set whoopsie [lindex $errorList 0]
#	ShowMessage "$whoopsie doing model $what" error \
#	    "$what during $action of the model at time $mtime caused this: \
#	    $errorInfo" ok
#	set mess "The $what step during $action of the model at time $mtime caused this problem:\n$errorInfo"
#tk_messageBox -message "Urrr!! Urrr!! Urrr!! $errorInfo"
	switch $what {
	    eval {set operation "calculate the value of"}
	    update {set operation "update the state"}
	    advance {set operation "advance the time point for"}
	}

	if {$model_id($node)} {
	    set target "a value"
	} else {
	    set modelLine [lindex $errorList end-5]
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
		set dest [namespace eval AME_model<> \
			      "set spare $targetName"]
		set targetList [DescribeComponent $dest]
		if {[catch {GetNodeIdFromRef $dest \
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
    }
}

proc RunningInC {myNode} {
    global model_id
#    return 0
    return $model_id($myNode) ;# it is ready
} 
    
proc ExplainError {what dest mtime mstep whoopsie} {
    global myNode
    set origError $::errorInfo
    switch $what {
	int_evalmodel {set operation "calculate the value of"}
	updatemodel {set operation "update the state"}
	advancemodel {set operation "advance the time point for"}
    }
    if {![string equal none $dest]} {
	set targetList [DescribeComponent $dest]
	if {[catch {GetNodeIdFromRef $dest [lindex $targetList 1]} TargetId]} {
	    set target [lindex $targetList 0]
	    set whoopsie dest_missing
	} else {
	    set target "[lindex $targetList 0] (node $TargetId)"
	}
    } else {
	set target something
    }

    switch -glob -- $whoopsie {
	"can't read \"*\": no such element in array" - 
	"can't read \"*\": no such variable" {
	    set ref [lindex [split $whoopsie \"] 1]
	    set sourceList [DescribeComponent $ref] 
	    if {[catch {GetNodeIdFromRef $ref \
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
	    set problem "there was an $whoopsie"
	}
    }
    
    switch -- $mstep {
	-1 {
	    set action initialization
	    set timing {}
	    #		ScrubRun $node 0
	} 0 {
	    set action reset
	    set timing {}
	} default {
	    set action execution
	    set timing " at time $mtime"
	}
    }
    set mess "Simile ran into a problem trying to run this model. 
While it was trying to $operation $target during $action of the model$timing, $problem. Original error message follows:\n$origError"
    # do it after idle so this process is not hung till user responds
    start_in_editor BuildProblem "Problem with model" warning $mess execution
    do_in_editor RaiseModelWindow $myNode
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
    global model_id steps ts
    if {![info exists model_id($node)]} {
	WarnNoProgram $node
    }
    
    if {$model_id($node)} {
#puts "setstep $time $phase"
	c_setstepmodel $model_id($node) $time $phase
    } elseif {$phase>=0} { ;# lazy
	set steps($phase) $time
#    } else {
#	set ts([expr {-$phase}]) $time
    }
}

proc TransEnums {transList vals} {
#puts "Translating $vals with $transList"
    set curLevel [lindex $transList 0]
    if {[llength $vals]==1} {
	return [EnquoteIfNonNumeric [TransValue $curLevel $vals]]
    } else {
	set indxCount [llength [lindex $vals 0]]
	set argTrans [lrange $transList $indxCount end]
	set result {}
	foreach {index subVals} $vals {
	    lappend result [TransValue $curLevel $index] \
		[TransEnums $argTrans $subVals]
	}
	return $result
    }
}

proc TransValue {curLevel val} {
    if {[llength $curLevel] && [string is integer $val]} {
	return [lindex $curLevel $val]
    } else {
	return $val
    }
}

proc PrettifyValList {ugly args} {
#puts "Trying to tidy up $ugly"
    if {[llength $ugly]==1} {
	set result [lindex $ugly 0]
    } else {
	set result {}
	foreach {indx val} $ugly {
	    if {[string length $result]} {
		append result { }
	    } elseif {[llength $args]} {
		set result \{
	    }
	    append result \#$indx:\ [PrettifyValList $val 1]
	}
	if {[llength $args]} {
	    append result \}
	}
    }
    return $result
}

proc UglifyValList {pretty} {
#puts "pretty $pretty"
    set midlin [regsub -all {: ([^\#\{\}]+)( \#|\}|$)} $pretty \
		    {: {"\1"}\2}]
#puts "midlin $midlin"
    set ugly [regsub -all {\#([^:]+):} $midlin {{\1}}]
#puts "ugly $ugly"
    return [NormalizeQuotes $ugly]
}

proc NormalizeQuotes {table} {
    if {[llength $table]==1} {
	return [DequoteNumeric $table]
    } else {
	set result {}
	foreach {indx val} $table {
	    lappend result [DequoteNumeric $indx] [NormalizeQuotes $val]
	}
	return $result
    }
}

proc DequoteNumeric {val} {
    if {[llength $val]==1 && [string is double [lindex $val 0]]} {
	return [lindex $val 0]
    } else {
	return $val
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
	    
proc GetModelTime {} {
    global myNode
    return [GetCompProperty $myNode CurrentTime]
}

proc GetModelEndTime {} {
    global myNode
    return [GetCompProperty $myNode EndTime]
}

# Something like this which just gets model structure we want to be
# able to do as soon as the model program is loaded. So check
# existence of model_id; don't wait for instance_id or running_c
 
proc GetObjectList {} {
    global myNode
    return [GetCompProperty $myNode Objects]
}

# GetModelValue returns the current value of a node. This is numerical if the
# node is scalar, a (possibly empty) list of alternating indices and values if
# the node is an array or list, and 'novalue' if it does not have one, e.g., a
# cloud or submodel.

proc GetModelValue { node } {
    SetModelValue $node {}
}

proc SetModelValue { node newVals } {
    global myNode
    return [GetCompProperty $myNode Value $node $newVals]
}

proc GetModelGraph {node} {
    SetModelGraph $node
}

proc SetModelGraph {node args} {
    global myNode
    return [eval GetCompProperty $myNode Graph $node $args]
}

proc GetModelType { node } {
    global myNode
    return [GetCompProperty $myNode Type $node]
}

proc GetModelEval { node } {
    global myNode
    return [GetCompProperty $myNode Eval $node]
}

proc GetModelDims { node } {
    global myNode
    return [GetCompProperty $myNode Dims $node]
}

proc GetModelClass { node } {
    global myNode
    return [GetCompProperty $myNode Class $node]
}

proc GetCaptionPathFromId { node } {
    global myNode
    return [GetCompProperty $myNode Caption $node]
}

proc GetIdFromCaptionPath { caption } {
    global myNode
    return [GetCompProperty $myNode IdFromCapt $caption]
}

proc GetMinValue { node } {
    global myNode
    return [GetCompProperty $myNode MinVal $node]
}

proc GetMaxValue { node } {
    global myNode
    return [GetCompProperty $myNode MaxVal $node]
}

proc GetTransTable { node } {
    global myNode
    return [GetCompProperty $myNode Trans $node]
#    return [do_in_editor GetTransTable $node]
}

proc ProdFromHelper {winId node caption} {
    global helperTable
    ProdObj $helperTable($winId,whichModel) $node $caption
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
	} Value {
	    if {$runState($topNode,modelRunning)<=2} {
		WarnNoData $topNode
	    }
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
    global model_id instance_id
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Objects {
	    return [lrange [listobjects \
				$model_id($topNode)] 1 end]
	} Class|Type|Eval {
	    array set propData [list Class,cIdx 11 Class,names \
			    {SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION \
			       CREATION REPRODUCTION IMMIGRATION LOSS ALARM} \
			    Type,cIdx 1 Type,names \
			    {VALUELESS REAL INTEGER FLAG EXTERNAL} \
			    Eval,cIdx 2 Eval,names \
			    {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST}]
	    set numericVal [c_getvalue $topNode $node $propData($prop,cIdx)]
	    if {$numericVal<=-10} {
		return ENUM([expr -10-$numericVal])
	    } else {
		return [lindex $propData($prop,names) $numericVal]
	    }
	} Dims {
	    set specials {RECORDS MEMBERS SEPARATE START_VM END_VM}
	    set fullList [c_getvalue $topNode $node 0]
	    
	    set idx 0
	    foreach elt $fullList {
		if {$elt<0} {
		    lset fullList $idx [lindex $specials [expr -$elt-1]]
		}
		incr idx
	    }
	    # helper apps don't need to know about separate submodels so...
	    while {[set sep [lsearch $fullList SEPARATE]]>-1} {
		set fullList [lreplace $fullList $sep $sep]
	    }
	    return $fullList
	} Graph {
	    if {[llength $set]} {
		eval {getvalue $model_id($topNode) $node 4} $set
	    } else {
		return [c_getvalue $topNode $node 3]
	    }
	} Caption {
	    return [c_getvalue $topNode $node 5]
	} IdFromCapt {
	    if {[catch {getnodeid $model_id($topNode) \
			    $node} match]} {
		return nomatch
	    }
	    return $match
	} MinVal {
	    return [c_getvalue $topNode $node 6]
	} MaxVal {
	    return [c_getvalue $topNode $node 8]
	} Trans {
	    return [c_getvalue $topNode $node 12]
	} Value {
	    set newVs [lindex $set 0]
	    # new version -- remove list wrapping sometime
	    if {[string length $newVs]} {
		return [list [insert $model_id($topNode) \
				  $instance_id($topNode) $node $newVs]]
	    } else {
		set res [list [extract \
				  $model_id($topNode) $instance_id($topNode) \
				  $node]]
		return $res
	    }
	}
    }
}

# wraps c++ defined version in different interp
proc c_getvalue {topNode node action} {
    global model_id
    set res [getvalue $model_id($topNode) $node $action]
    return $res
}
	    
proc GetTclCompProperty {topNode prop args} {
    global nodecount nodedata
    set node [lindex $args 0]
    set set [lrange $args 1 end]
#    set nodecount [set nodecount]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Objects {
	    set result {}
	    for {set record 1} {$nodecount>$record} {incr record} {
		lappend result [lindex $nodedata($record) 0]
	    }
	    return $result
	} Class|Type|Eval {
	    array set propData [list Class 9 Type 0 Eval 3]
	    set extracted [getinfo $node $propData($prop)]
	    if {[string is integer $extracted]} {
		return ENUM([expr -10-$extracted])
	    } else {
		return $extracted
	    }
	} Dims|Trans {
	    set dimRefs [GetFullDims [findRecord $node] typeList]
	    set count 0
	    set transList {}
	    while {$count<[llength $dimRefs]-1} {
		set aDim [lindex $dimRefs $count]
		if {[lsearch {START_VM END_VM} $aDim]>-1} {
		} elseif {$aDim<=-10} {
		    set usedET [lindex $typeList \
				    [expr [llength $typeList]+$aDim+9]]
		    lset dimRefs $count [lindex $usedET 0]
		    lappend transList [lrange $usedET 1 end]
		} else {
		    lappend transList {}
		}
		incr count
	    }
	    if {[string equal Dims $prop]} {
		return $dimRefs
	    } else {
		set vType [getinfo $node 0]
		if {[string is integer $vType]} {
		    set usedET [lindex $typeList \
				    [expr [llength $typeList]+$vType+9]]
		    lappend transList [lrange $usedET 1 end]
		} elseif {[string equal FLAG $vType]} {
		    lappend transList [list false true]
		}
		return $transList
	    }
	} Graph {
	    set index [getinfo $node 6]
	    if {!$index} {
		error "No graph associated with node [getinfo $node 10]."
	    }
	    if {[llength $set]} {
		eval {setup_graph_data $index} $set
	    } else {
		return [graph_table 21 $index]
	    }
	} Caption {
	    return [GetFullCaption [findRecord $node]]
#ShowMessage debug info "node $node data [array get nodedata] npath $numericPath" ok
	} IdFromCapt {
	    for {set record 1} {$nodecount>$record} {incr record} {
		if {![string equal GHOST [lindex $nodedata($record) 4]]} {
		    if {[string equal $node \
			     [GetFullCaption $nodedata($record)]]} {
			return [lindex $nodedata($record) 0]
		    }
		}
	    }
	    return nomatch
	} MinVal {
	    getinfo $node 7
	} MaxVal {
	    getinfo $node 8
	} Value {
	    return [tcl_insert $node [lindex $set 0]]
	}
    }
}

proc ParentLine {line} {
    global nodedata
    set handle [lindex $line 6]
    if {[lindex $handle end-1]<0} {
	set ptHand [lreplace $handle end-2 end 0]
    } else {
	set ptHand [lreplace $handle end-1 end 0]
    }
    foreach {n ptLine} [array get nodedata] {
	if {[ListSameNumbers [lindex $ptLine 6] $ptHand]} {
	    return $ptLine
	}
    }
}    

proc GetFullCaption {line} {
    global nodedata
    if {[llength [lindex $line 6]] < 3} {
	return {}
    } else {
	set parentCapt [GetFullCaption [ParentLine $line]]
	append parentCapt / [lindex $line 11]
	return $parentCapt
    }
}				      

proc TypeAsList {arrName count} {
    upvar \#0 $arrName arrVal
    upvar \#0 $arrVal($count,1) tName
    set result [list $arrVal($count,0) $tName]
    upvar \#0 $arrVal($count,2) arrTypes
    for {set elt 0} {$elt<$arrVal($count,0)} {incr elt} {
	upvar \#0 $arrTypes($elt) arrTxt
	lappend result $arrTxt
    }
    return $result
}

proc GetFullDims {line ETptrs} {
#do_in_editor puts $handle
    upvar 1 $ETptrs localETs
    if {[llength [lindex $line 6]] < 3} {
	set parentDims 0
	set localETs {}
    } else {
	set ptLine [ParentLine $line]
	set parentDims [GetFullDims $ptLine localETs]
    }
# add this levels type data -- reverse order cos outer models start list
    set count [lindex $line 2]
    while {$count} {
	incr count -1
	lappend localETs [TypeAsList [lindex $line 3] $count]
    }
# correct earlier enum type references to take account of this level
    set count [llength $parentDims]
    while {$count} {
	incr count -1
	set oVal [lindex $parentDims $count]
	if {$oVal<=-10} {
	    lset parentDims $count [expr $oVal-[lindex $line 2]]
	}
    }
    set parentDims [concat [lrange $parentDims 0 end-1] [lindex $line 5]]
    return $parentDims
}				      
	    
#proc getinfo {topNode node field} {
#    getinfo $node $field
#}

# this could be more efficient

proc GetPhaseCount {topNode} {
    global model_id phasecount
    if {![info exists model_id($topNode)]} {
	WarnNoProgram $topNode
	return nomatch
    }	
    if {$model_id($topNode)} {
	return [c_setstepmodel $model_id($topNode) 0 0]
    } else {
	return $phasecount
    }
}

# these two are called from the model and handled by the client
proc InteractGUI {handle modelTime flCol} {
    global helperTable
    return [$helperTable(RunControl)::RCInteractGUI [DecodeInstance $handle] \
		$modelTime [lindex {{} green blue} $flCol]]
}

proc AbortCheck {handle} {
    global helperTable
    return [$helperTable(RunControl)::RCAbortCheck [DecodeInstance $handle]]
}

proc DecodeInstance {handle} {
    global instance_id
    foreach {model h_id} [array get instance_id] {
	if {$h_id==$handle} {
	    return $model
	}
    }
    return $handle
}

proc ResetModel {myNode redo} {
    global model_id instance_id
    if {![info exists model_id($myNode)]} {
	WarnNoProgram $myNode
	return 0
    }	
    if {[catch {
	if {$model_id($myNode)} {
	    c_resetmodel $model_id($myNode) $instance_id($myNode) $redo
	} else {
	    TclResetModel $redo
	}
    } errList]} {
	eval ExplainError $errList
	set done 0
    } else {
	set done 1
    }
    InteractGUI $instance_id($myNode) 0 2
    return $done
}

proc ExecuteModel {myNode howInt start finish errLim} {
    global model_id instance_id
    if {[catch {
	if {$model_id($myNode)} {
	    c_executemodel $model_id($myNode) $instance_id($myNode) \
		[expr ![string equal Euler $howInt]] $start $finish $errLim
	} else {
	    TclExecuteModel $myNode $howInt $start $finish $errLim
	}
    } errList]} {
	InteractGUI $instance_id($myNode) [lindex $errList 2] 2
	eval ExplainError $errList
	return -1
    } elseif {$errList==-1} {
	start_in_editor BuildProblem "Execution notice" info "Model execution has been paused at a discontinuity which could not be dealt with by adaptive step size control." execution
	do_in_editor RaiseModelWindow $myNode
	return 0
    } else {
	return $errList
    }
}

proc WarnNoProgram {node} {
    global errorInfo
    error "This operation cannot be done as there is no model program loaded for node $node."
}

proc WarnNoData {node} {
    error "This operation cannot be done as there is no model program running for node $node."
}

proc InputVarFor {topNode node} {
    switch -glob [GetCompProperty $topNode Type $node] {
	FLAG {
	    return checkStates
	} ENUM(*) {
	    return comboChoices
	} default {
	    return sliderVals
	}
    }
}

proc BringParameter {array node inds} {
#puts "looking for $array\($sub\)"
    upvar \#0 $array inputSrc
    for {set ind1 0} {$ind1<=[llength $inds]} {incr ind1} {
	set sub [join [concat $node [lrange $inds $ind1 end]] ,]
	if {[info exists inputSrc($sub)]} {
	    return $inputSrc($sub)
	}
    }
}

