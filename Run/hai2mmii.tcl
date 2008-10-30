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
proc ExplainError {errList} {
    global myNode
    set origError $::errorInfo
    if {![string match tcl_model_err* $errList]} {
	error "Unexpected problem in Tcl model execution" $origError
    }
    set severity -1
    set what [lindex $errList 1]
    set dest [lindex $errList 2]
    set mtime [lindex $errList 3]
    set mstep [lindex $errList 4]
    set whoopsie [lindex $errList 5]
    switch $what {
	evalmodel {set operation "calculating the value of"}
	updatemodel {set operation "updating the state"}
	advancemodel {set operation "advancing the time point for"}
	resetmodel {set operation "resetting"}
	default {set operation "doing $what for"}
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
	    set severity 0
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
    switch -- $severity {
	-1 {
	    set graphic warning
	    set header "Problem with model"
	    set mess "Simile ran into a problem trying to run this model. 
While $operation $target during $action of the model$timing, $problem. Original error message follows:\n$origError"
	} 0 {
	    set graphic info
	    set header "Model execution paused"
	    set mess "While $operation $target during $action of the model$timing, $problem."
	}
    }
    # do it after idle so this process is not hung till user responds
    start_in_editor BuildProblem $header $graphic $mess execution
    do_in_editor RaiseModelWindow $myNode
    return $severity
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
    GetCompProperty $node SetStep $time $phase
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
    set paramKeys {restart use_last use_closest interpolate}
    if {[llength $val]==1 && ([string is double [lindex $val 0]] || \
				  [lsearch $paramKeys [lindex $val 0]]>-1)} {
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

proc AddToWatched {node} {
    global helperTable

    lappend helperTable($helperTable(beingCalled),foci) $node
}

# GetModelValue returns the current value of a node. This is numerical if the
# node is scalar, a (possibly empty) list of alternating indices and values if
# the node is an array or list, and 'novalue' if it does not have one, e.g., a
# cloud or submodel.

proc GetModelValue { node } {
    global subbedPlots
    if {[info exists subbedPlots($node)]} {
	if {[llength $subbedPlots($node)]==3} { # is pointer to univ struct
	    return [list [extract_list [lindex $subbedPlots($node) 2]]]
	} else { # from tcl model or measured value from pest interface
	    return [list $subbedPlots($node)]
	}
    } 
    AddToWatched $node
    return [SetModelValue $node {}]
}

proc SetModelValue { node newVals } {
    global myNode
    return [GetCompProperty $myNode Value $node $newVals]
}

proc GetBinaryModelValue { node args } {
    global myNode subbedPlots
    if {[info exists subbedPlots($node)]} {
	if {[llength $subbedPlots($node)]==3} { # is pointer to univ struct
	    return [eval extract_binary [lrange $subbedPlots($node) 2 2] \
		       $args]
	} else { # from tcl model or measured value from pest interface
	    error "binary values not available"
	}
    }
    AddToWatched $node
    return [eval GetCompProperty $myNode Binary $node $args]
}

proc ListDistinctModelValues { node } {
    global myNode subbedPlots
    if {[info exists subbedPlots($node)]} {
	if {[llength $subbedPlots($node)]==3} { # is pointer to univ struct
	    return [distinct_values [lindex $subbedPlots($node) 2]]
	} else { # from tcl model or measured value from pest interface
	    error "binary values not available"
	}
    }
# do not add to watched list, this is only needed during setup
    return [eval GetCompProperty $myNode Distinct $node]
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
    global helperTable myNode

    set inst $helperTable(beingCalled)
    set node [GetCompProperty $myNode IdFromCapt $caption]
    if {![string equal nomatch $node] || ![string length $inst]} {
	return $node
    }
# failed to get caption, have we already tried this submodel
    if {[info exists helperTable($inst,lost)]} {
	foreach lostModel $helperTable($inst,lost) {
	    if {[string match $lostModel* $caption]} {
		return nomatch ;# yes, user has been warned
	    }
	}
    }
# no, warn and add highest missing submodel to lost list -- adapted from
# similar bit in params.tcl
    set nextLook $caption
    while {[string equal nomatch $node]} {
	set lostBit $nextLook
	set nextLook [join [lrange [split $lostBit /] 0 end-1] /]
	if {[llength $nextLook]} {
	    set node [GetCompProperty $myNode IdFromCapt $nextLook]
	} else {
	    set node $myNode
	}
    }
    if {[string equal $lostBit $caption]} {
	set lostType component
    } else {
	set lostType submodel
    }
    set helperType [[$inst info class]::Identify]
    BuildProblem "Missing values for helper" warning "An instance of the I/O tool \"$helperType\" has requested information about the $lostType $lostBit, but there is no $lostType of this name in the current model. If the model has changed since the I/O tools were set up, you should adjust the settings of the I/O tools to reflect these changes, otherwise more warnings may appear and the model may stop running." helpers
    lappend helperTable($inst,lost) $lostBit
    return nomatch
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
    set inst $helperTable($winId,whichInstance)
    ProdObj [$inst GetNode] $node $caption
}

proc GetCompProperty {topNode prop args} {
    global runState
    switch -regexp $prop {
	CurrentTime {
	    return $runState($topNode,currentTime)
	} EndTime {
	    return [expr $runState($topNode,currentTime) + \
			$runState($topNode,execTime)]
	}
    }
       
    if {[RunningInC $topNode]} {
	if {[lsearch {Value Binary Distinct} $prop]>-1} {
	    if {$runState($topNode,modelRunning)<=2} {
		WarnNoData $topNode
		return nodata
	    }
	    set hdl [GetHandle $topNode [lindex $args 0]]
	    switch -regexp $prop {
		Value {
		    set result [list [extract_list $hdl]]
		} Binary {
		    set result [eval extract_binary [list $hdl] \
				    [lrange $args 1 end]]
		} Distinct {
		    set result [distinct_values $hdl]
		}
	    }
	    free_data_handle $hdl
	} else {
	    set result [eval GetCCompProperty $topNode $prop $args]
	}
    } else {
	set result [eval GetTclCompProperty $topNode $prop $args]
    }
#puts "result $result"
    return $result
}

proc GetPhaseCount {topNode} {
    GetCompProperty $topNode SetStep 0 0
}

# these two are called from the model and handled by the client
proc InteractGUI {node modelTime flCol} {
    global helperTable

    set key [$helperTable(RunControl)::RCInteractGUI $node \
		$modelTime [lindex {{} green blue} $flCol]]
    return $key
}

proc AbortCheck {handle} {
    global helperTable model_id
    return [$helperTable(RunControl)::RCAbortCheck $model_id(running)]
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
	    if {[string equal TABLE [GetCompProperty $topNode Eval $node]]} {
		return paramData
	    } else {
		return sliderVals
	    }
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

