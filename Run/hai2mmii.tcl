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
    if {[llength $curLevel]} {
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
# Something should go in around here to deal with the fact that user input is
# not necessarily a list
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
	    return [list [extract_list [lindex $subbedPlots($node) 2] \
			      16777216]] ;# enough to freeze a 4 gig machine
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
    lappend helperTable($inst,lost) $lostBit
    set helperType [[$inst info class]::Identify]

    if {[string equal abort [Query [list missing_var_requested $helperType \
					$lostType $lostBit $lostType] \
				 warning helpers {} abort]]} {
	error aborted
    }
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
    if {[string first .newParamTgt $winId]==0 && [string length $node]} { 
	# choosing new target for lost param data 
	set ::paramData(newPath,done) [list $caption $node]
    } else {
	set inst $helperTable($winId,whichInstance)
	ProdObj [$inst GetNode] $node $caption
    }
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
	    if {[catch {GetHandle $topNode [lindex $args 0]} hdl]} {
		return novalue
	    }
	    switch -regexp $prop {
		Value {
		    set result [list [extract_list $hdl 16777216]]
		} Binary {
		    set result [eval extract_binary [list $hdl] \
				    [lrange $args 1 end]]
		} Distinct {
		    set result [distinct_values $hdl]
		}
	    }
	    ReleaseHandle $topNode $hdl
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

proc AbortCheck {node} {
    global helperTable
    return [$helperTable(RunControl)::RCAbortCheck $node]
}

proc WarnNoProgram {node} {
    global errorInfo
    error "This operation cannot be done as there is no model program loaded for node $node."
}

proc WarnNoData {node} {
    error "This operation cannot be done as there is no model program running for node $node."
}
