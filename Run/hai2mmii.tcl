# Interfacing the model
# =====================

# When running a model in c, the helper application commands must do slightly different
# things to pass information to and from the executing model. These are the new
# definitions that rae required for this purpose.

proc update_model {args} {
    global running_c errorInfo model_id instance_id
    
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
	set head [list c_updatemodel $model_id $instance_id]
    } else {
	set head ::AME_model<>::updatemodel
    }

    if [catch {eval $head $args} whoopsie] {
	switch -- $mstep {
	    -1 {
		set action Initialization
		unset running_c
	    } 0 {
		set action Reset
	    } default {
		set action Evaluation
	    }
	}
	ShowMessage "$whoopsie running model" error \
	    "$action of the model at time $mtime caused this error: \
	    $errorInfo" ok
	return 0
    } else {
	return 1
    }
}

proc eval_model {args} {
    global running_c errorInfo model_id instance_id
    
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
	set head [list c_evalmodel $model_id $instance_id]
    } else {
	set head ::AME_model<>::int_evalmodel
    }

    if [catch {eval $head $args} whoopsie] {
	switch -- $mstep {
	    -1 {
		set action Initialization
		unset running_c
	    } 0 {
		set action Reset
	    } default {
		set action Evaluation
	    }
	}
	ShowMessage "$whoopsie running model" error \
	    "$action of the model at time $mtime caused this error: \
	    $errorInfo" ok
	return 0
    } else {
	return 1
    }
}

proc SetStep {time phase} {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }
    
    if {$model_id} {
	c_setstepmodel $time $phase
    } else {
	do_setstepmodel $time $phase
    }
}

proc TransEnums {transList vals} {
#puts "Translating $vals with $transList"
    if {[llength $vals]==1} {
	set curLevel [lindex $transList 0]
	if {[llength $curLevel]} {
	    return [lindex $curLevel $vals]
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
	    set header [lindex $level 0]
	} else {
	    set header [lindex $vals 0]
	}
	return [concat $header \
	    [TransBounds [lrange $transList 1 end] [lrange $vals 1 end]]]
    } else {
	return {}
    }
}
	    
# GetModelValue returns the current value of a node. This is numerical if the
# node is scalar, a (possibly empty) list of alternating indices and values if
# the node is an array or list, and 'novalue' if it does not have one, e.g., a
# cloud or submodel.

proc GetModelValue { node } {
# puts "get $node"
    global running_c model_id instance_id
    if {![info exists running_c]} {
	WarnNoData
    }	
    if {$model_id} {
	#	    return [getvalue $model_id $instance_id $node 0]
	# new version -- remove list wrapping sometime
	return [list [extract $model_id $instance_id $node]]
    } else {
	set nodeData [getinfo $node]
	if {[string compare [lindex $nodeData 0] NULL]} {
	    set type [lindex $nodeData 0]
	    set dims [lindex $nodeData 2]
	    set tree [lindex $nodeData 3]
	    set retval [list [FillValue ::AME_model<> $tree $type $dims \
		    {} 0 {}]]
	} else {
	    return novalue
	}
    }
}

proc SetModelValue { node newVals } {
# puts "get $node"
    global running_c model_id instance_id
    if {![info exists running_c]} {
	WarnNoData
    }	
    if {$model_id} {
	#	    return [getvalue $model_id $instance_id $node 0]
	# new version -- remove list wrapping sometime
	return [list [insert $model_id $instance_id $node $newVals]]
    } else {
	set nodeData [getinfo $node]
	if {[string compare [lindex $nodeData 0] NULL]} {
	    set type [lindex $nodeData 0]
	    set dims [lindex $nodeData 2]
	    set tree [lindex $nodeData 3]
	    set retval [list [FillValue ::AME_model<> $tree $type $dims \
	    {} 0 $newVals]]
	} else {
	    return novalue
	}
    }
}

proc FillValue {smHandle tree type useDims dims dimPlace newVals} {
#    puts "filling tree $tree bounds $useDims inds $dims place $dimPlace"
    set nextUseDim [lindex $useDims 0]
    if {$nextUseDim == -1} {
	set newTree [lrange $tree [expr [lsearch $tree -1]+1] end]
	set nextRef [set [burrow_to $smHandle $tree $dims]]
	set result {}
	array set arrayVals $newVals
	while {[string compare $nextRef 0]} {
	    set smHandle ::AME_model<>::$nextRef
	    set nextElt [set [burrow_to $smHandle {2 0} {}]]
	    lappend result $nextElt
	    if {[info exists arrayVals($nextElt)]} {
		set eltVals $arrayVals($nextElt)
	    } else {
		set eltVals {}
	    }
	    lappend result [FillValue $smHandle $newTree $type \
		    [lrange $useDims 1 end] {} 0 $eltVals]
	    set nextRef [set [burrow_to $smHandle {1 0} {}]]
	}
	return $result	    
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
	for {set nextDim 1} {$nextUseDim>=$nextDim} \
		{incr nextDim} {
	    lappend result $nextDim
	    if {[info exists arrayVals($nextDim)]} {
		set eltVals $arrayVals($nextDim)
	    } else {
		set eltVals {}
	    }
	    lappend result [FillValue $smHandle $tree $type \
		    [lrange $useDims 1 end] \
		    [concat $dims $nextDim] [expr $dimPlace+1] $eltVals]
	}
	return $result
    }
}

proc burrow_to {level id_meta dim_list} {
    while {[lindex $id_meta 0]>0} {
	append level ::[${level}::get_pointer [step_list id_meta 1] dim_list]
    }
    return $level
}
	
proc step_list {dimList climb} {    
    upvar $climb $dimList useList
    set head [lindex $useList 0]
    set useList [lrange $useList 1 end]
    return $head
}

# Something like this which just gets model structure we want to be
# able to do as soon as the model program is loaded. So check
# existence of model_id; don't wait for instance_id or running_c
 
proc GetObjectList { } {
    global model_id nodedata nodecount
    if {![info exists model_id]} {
	WarnNoProgram
    }
    if {$model_id} {
	return [listobjects $model_id]
    } else {
	for {set record 0} {$nodecount>$record} {incr record} {
	    lappend result [lindex $nodedata($record) 0]
	}
	return $result
    }
}

proc GetModelType { node } {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	set nodeType [getvalue $model_id $node 1]
	if {[string match noitem $nodeType]} {
	    return noitem
	} else {
	    return [lindex {VALUELESS REAL INTEGER FLAG EXTERNAL} $nodeType]
	}
    } else {
	lindex [getinfo $node] 0
    }
}

proc GetModelEval { node } {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	return [lindex {EXOGENOUS DERIVED TABLE INPUT SPLIT GHOST} \
		[getvalue $model_id $node 2]]
    } else {
	lindex [getinfo $node] 1
    }
}

proc GetModelDims { node } {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
# helper apps don't need to know about separate submodels so...
	set fullList [getvalue $model_id $node 0]
	while {[set sep [lsearch $fullList -2]]>-1} {
	    set fullList [lreplace $fullList $sep $sep]
	}
	return $fullList
    } else {
	lindex [getinfo $node] 2
    }
}

proc GetMinValue { node } {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	return [getvalue $model_id $node 6]
    } else {
	lindex [getinfo $node] 5
    }
}

proc GetMaxValue { node } {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	return [getvalue $model_id $node 8]
    } else {
	lindex [getinfo $node] 6
    }
}

proc GetModelClass { node } {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	return [lindex {SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION \
		CREATION REPRODUCTION IMMIGRATION LOSS} \
		[getvalue $model_id $node 11]]
    } else {
	lindex [getinfo $node] 7
    }
}

proc GetModelGraph {node} {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	return [getvalue $model_id $node 3]
    } else {
	variable graphdata
	
	set nodeData [getinfo $node]
	if {[string compare [lindex $nodeData 4] NULL]} {
	    return $graphdata([lindex $nodeData 4])
	} else {
	    return nograph
	}
    }
}

proc SetModelGraph {node args} {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	eval {getvalue $model_id $node 4} $args
    } else {
	eval {setup_graph_data graphdata([lindex [getinfo $node] 4])} $args
    }
}

# because the data is all in order, this would be nicer if I only went through
# the table once, adding the names as I found them, but...
	
proc GetCaptionPathFromId {node} {
    global model_id
    if {![info exists model_id]} {
	WarnNoData
	return nomatch
    }	
    if {$model_id} {
	return [getvalue $model_id $node 5]
    } else {
	global nodedata nodecount
	
	set numericPath [lindex [getinfo $node] 3]
#ShowMessage debug info "node $node data [array get nodedata] npath $numericPath" ok
	for {set level 0} {$level < [llength $numericPath] - 1} {incr level} {
	    set subpath [lrange $numericPath 0 $level]
	    lappend subpath 0
	    for {set record 0} {$nodecount>$record} {incr record} {
		if {[ListSameNumbers [lindex $nodedata($record) 4] $subpath]} {
		    append fullPath / [lindex $nodedata($record) 9]
		    break
		}
	    }
	}
	return $fullPath
    }
}

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

proc GetIdFromCaptionPath {caption} {
    global model_id
    if {![info exists model_id]} {
	WarnNoProgram
    }	
    if {$model_id} {
	return [getnodeid $model_id $caption]
    } else {
	global nodedata nodecount
	
	for {set line 0} {$nodecount>$line} {incr line} {
	    set id [lindex $nodedata($line) 0]
	    if {[string compare $caption \
		    [GetCaptionPathFromId $id]] == 0} {
		return $id
	    }
	}
	return nomatch
    }
}

proc GetPhaseCount {} {
    global model_id phasecount
    if {![info exists model_id]} {
	WarnNoProgram
	return nomatch
    }	
    if {$model_id} {
	return [getvalue $model_id node00001 9]
    } else {
	return $phasecount
    }
}

proc WarnNoProgram {} {
    global errorInfo
    error "This operation cannot be done as there is no model program loaded. \
($errorInfo)"
}

proc WarnNoData {} {
    error "This operation cannot be done as there is no model program running."
}

# Boot on the other foot now: this is called by the model to get values from
# the helpers

proc collect {tgt node count args} {
# ShowMessage debug info "Collecting...$tgt...$node...$count...$args" ok
    if {[string match TABLE [GetModelEval $node]]} {
	FileCollect ::AME_model<>::$tgt $node $args
    } else {
	set sub [join [concat $node $args] ,]
	if {[string match FLAG [GetModelType $node]]} {
	    upvar #0 checkStates inputSrc
	} else {
	    upvar #0 sliderVals inputSrc
	}
# Check that input source exists, it will not if model is being initialized
	if {[info exists inputSrc($sub)]} {
	    set ::AME_model<>::$tgt $inputSrc($sub)
	}
    }
}

proc FileCollect {tgt node argList} {
    global paramData
    set compName [GetCaptionPathFromId $node]
    
    set field $paramData($compName)
    while {[string compare $argList {}]} {
        #ShowMessage debug info "Array setting $field" ok
        array set items $field
        set field $items([lindex $argList 0])
        set argList [lrange $argList 1 end]
    }
    set $tgt $field ;# tgt is passed by reference
}

