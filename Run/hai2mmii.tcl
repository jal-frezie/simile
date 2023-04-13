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

source [file join $SIMILE_PATH Run jsonplus.tcl]

proc SetStep {node time phase} {
    GetCompProperty $node SetStep $time $phase
}

proc TransEnums {transList vals} {
#puts "Translating $vals with $transList"
    set curLevel [lindex $transList 0]
    if {[llength $vals]==1} {
#	return [EnquoteIfNonNumeric [TransValue $curLevel $vals]]
	return [TransValue $curLevel $vals]
    } else {
# speed: if no defns, just return arg
	if {[lsearch -regexp $transList .] == -1} {return $vals}
# multiple indices per value no longer used
#	set indxCount [llength [lindex $vals 0]]
	set argTrans [lrange $transList 1 end]
	set result {}
	foreach {index subVals} $vals {
	    lappend result [TransValue $curLevel $index] \
		[TransEnums $argTrans $subVals]
	}
	return $result
    }
}

# No call for this
#
#proc UntransEnums {transList mem} {
##puts "Untranslating $vals with $transList"
#    if {[lsearch $transList ?*]<0} {return $mem} ;# no translations to do
#    set curLevel [lindex $transList 0]
#    set moreLevels [lrange $transList 1 end]
#    if {[llength $moreLevels]} {
#	foreach {index subMems} $mem {
#	    lappend result [UntransVal $curLevel $index index] \
#		[UntransEnums $argTrans $subMems]
#	}
#	return $result
#    } else {
#	return [UntransVal $curLevel $mem data]
#    }
#}
#
proc TransValue {curLevel val} {
    if {[llength $curLevel]} {
	return [lindex $curLevel $val]
    } else {
	return $val
    }
}

proc IsPretty {bride} {
    expr {[string first [string index $bride 0] \{\[]+1}
}

proc PrettifyValList {ugly txtVals} {
    #puts [info level 0]
    if {[string is double -strict $ugly] || $ugly eq "sm"} {
	set result $ugly
    } elseif {[llength $ugly]==1 || [lsearch $txtVals $ugly]>-1} {
	# do mind even length ET mem mangling
	set result \"$ugly\"
    } else {
	set result {}
	foreach {indx val} $ugly {
	    if {[string length $result]} {
		append result {, }
	    } else {
		set result \{
	    }
	    if {[llength $indx]!=1} {
		set indx \"$indx\"
	    }
	    append result $indx:\ [PrettifyValList $val $txtVals]
	}
	if {[string length $result]} {
	    append result \}
	}
    }
    return $result
}

proc UglifyValList {pretty isTimes} {
    set p [IsPretty $pretty]
    if {!$p} {
	return $pretty
    }
    set hugTree [::json::json2dict $pretty]
    if {$p==2 && $isTimes} { # array for time series, indices start from 0
	set science {}
	foreach {ind val} $hugTree {
	    lappend science [expr {$ind-1}] $val
	}
	return $science
    }
    return $hugTree
}

proc OldUglifyValList {pretty} {
#puts "pretty $pretty"
# Something should go in around here to deal with the fact that user input is
# not necessarily a list
    set midlin [regsub -all {: ([^\#\{\}]+)( \#|\}|$)} $pretty \
		    {: {\1}\2}]
#puts "midlin $midlin"
    set ugly [regsub -all {\#([^:]+):} $midlin {{\1}}]
#puts "ugly $ugly"
    return [NormalizeQuotes $ugly]
}

proc NormalizeQuotes {table} {
    if {[catch {llength $table} len]} {
	return [list $table]
    } elseif {$len==1} {
	return $table
    } else {
	set result {}
	foreach entry $table {
	    lappend result [NormalizeQuotes $entry]
	}
	return $result
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
    return $::runState($::myNode,currentTime)
}

proc GetModelEndTime {} {
    return [expr {[GetModelTime]+$::runState($::myNode,execTime)}]
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
    if {$helperTable(beingCalled) eq ""} {error "stealth helper"}
#    $helperTable(VariableList)::AddHelperLeaf $::runState($::myNode,inspId) \
	#	$node $helperTable(beingCalled)
    $::runState($::myNode,inspId) HelperLeaf $node $helperTable(beingCalled) 1
}

proc ListFoci {node} {
	global helperTable runState

	foreach {name inst} [array get helperTable *,whichInstance] {
	    if {[string equal $node [$inst GetNode]]} {
		foreach focus $helperTable($inst,foci) {
		    set allFoci($focus) 1
		}
	    }
	}
# now add nodes being logged by snapshot tools
	foreach logger [array names runState log*] {
	    if {[string equal $node [lindex $runState($logger) 0]]} {
		set focus [string range $logger 3 end]
		set allFoci($focus) 1
	    }
	}
# and those for scripted callback requests
	foreach {callback nodes} [array get runState *,scriptReqs] {
	    foreach focus $nodes {
		set allFoci($focus) 1
	    }
	}
	return [array names allFoci]
}

proc ExtractCList {dH count loseZeros} {
    if {[llength $dH]==1} {
	return [extract_list $dH $count $loseZeros]
    } ;# else
    set runTot {}
    set ortho -1
    set snip [expr {2*$count/[llength $dH]}]
    foreach {case hdl} $dH {
	set sector [extract_list $hdl $snip $loseZeros]
	lappend runTot [incr ortho] $sector ;# 1st is 0
    }
    return $runTot
}

proc ExtractJList {dH count loseZeros} {
    if {[llength $dH]==1} {
	return [extract_json $dH $count $loseZeros]
    } ;# else
    set runTot {}
    set snip [expr {2*$count/[llength $dH]}]
    foreach {case hdl} $dH {
	lappend runTot $case [extract_json $hdl $snip $loseZeros]
    }
    return $runTot
}

# GetModelValue returns the current value of a node. This is numerical if the
# node is scalar, a (possibly empty) list of alternating indices and values if
# the node is an array or list, and 'novalue' if it does not have one, e.g., a
# cloud or submodel.

proc GetModelValue { node {keepEvtZeros 0}} {
    global subbedPlots

    if {[info exists subbedPlots($node)]} {
	if {[llength $subbedPlots($node)]==3} { # is pointer to univ struct
	    set loseZeros [expr {!$keepEvtZeros && \
		 [lsearch {EVENT SQUIRT} [lindex $subbedPlots($node) 1]]>-1}]
	    # G_M_C horribly slow, keep node class with handle
	    return [list [ExtractCList [lindex $subbedPlots($node) 2] \
			      16777216 $loseZeros]] ;# enough I hope
	} else { # from tcl model or measured value from pest interface
	    return [list $subbedPlots($node)]
	}
    } 
    AddToWatched $node
    return [SetModelValue $node {}]
}

proc SetModelValue { node newVals } {
    global myNode
    
    return [GetCompExecData $myNode Value $node $newVals]
}

proc DefFrom {hdlList} {
    if {[llength $hdlList]==1} {
	return $hdlList
    } else {
        return [lindex $hdlList [lsearch $hdlList default]+1]
    }
}

proc GetBinaryModelValue { node args } {
    global myNode subbedPlots
    if {[info exists subbedPlots($node)]} {
	if {[llength $subbedPlots($node)]==3} { # is pointer to univ struct
	    return [eval extract_binary [DefFrom [lindex $subbedPlots($node) 2]] \
		       $args]
	} else { # from tcl model or measured value from pest interface
	    error "binary values not available"
	}
    }
    AddToWatched $node
    return [eval GetCompExecData $myNode Binary $node $args]
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
    return [eval GetCompExecData $myNode Distinct $node]
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

proc GetModelBase { node } {
    global myNode
    return [GetCompProperty $myNode Base $node]
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
	return aborted
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
    set result [GetCompProperty $myNode Trans $node]
    if {[llength [ListCases $myNode]]} {
	set caseNames default
	foreach {case mH} [ListCases $myNode] {
	    lappend caseNames $case
	}
	set result [linsert $result 0 $caseNames]
    }
    return $result
#    return [do_in_editor GetTransTable $node]
}

proc MakeSubFrames {clientId nextLevel hierarchy ns nextPt} {
    AddSubFrames $::myNode $clientId $nextLevel $hierarchy $ns $nextPt
}

proc ProdFromHelper {winId node caption} {
    global helperTable
    if {[string first .new $winId]==0 && [string length $node]} { 
	# choosing new target for lost param data 
	set ::paramData(newPath,done) [list $caption $node]
    } else {
	set inst $helperTable($winId,whichInstance)
	ProdObj [$inst GetNode] $node $caption
    }
}

proc GetCompExecData {topNode prop args} {
    global runState
       
    if {[RunningInC $topNode]} {
	if {$runState($topNode,modelRunning)<=1} {
	    WarnNoData $topNode
	    return nodata
	}
	if {[catch {GetHandle $topNode [lindex $args 0]} hdl]} {
	    return novalue
	}
	switch -regexp $prop {
	    Value {
		set result [list [ExtractCList $hdl 16777216 0]]
	    } Binary {
		set result [eval extract_binary [DefFrom $hdl] \
				[lrange $args 1 end]]
	    } Distinct {
		set result [distinct_values $hdl]
	    }
	}
	ReleaseHandle $topNode $hdl
    } else {
	set result [eval GetTclCompExecData $topNode $prop $args]
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
		$modelTime [lindex {black yellow green blue} $flCol]]
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
