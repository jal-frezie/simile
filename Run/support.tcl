# this file contains tcl routines that have to go in the same interpreter as
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
	    set tree [lindex $nodedata($record) 4]
	    set type [lindex $nodedata($record) 1]
	    set dims [lindex $nodedata($record) 3]
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
				    [lindex $nodedata($record) 4] $indices]]} {
	    return [lindex $nodedata($record) 0]
	}
    }
}

proc collect {tgt node count args} {
# ShowMessage debug info "Collecting...$tgt...$node...$count...$args" ok
    if {[string match TABLE [getinfo $node 1]]} {
	set inputSrc paramData
    } else {
	set inputSrc [InputVarFor $node]
    }
    set sub [join [concat $node $args] ,]
    set val [BringParameter $inputSrc $sub]
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

proc at_time_step {} {
    return [expr [glob_element dts 0]<=1]
}

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

proc InputVarFor {node} {	
    switch [getinfo $node 0] {
	FLAG {
	    return checkStates
	} ENUMERATED {
	    return comboChoices
	} default {
	    return sliderVals
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

# This is in both interps cos they both need stub functions

proc load_c_stub {} {
    package require Trf

    global tcl_platform env userinfo ;# last needed in stub
    # On startup, check run count and offer registration if 0
    if [catch {set userinfo(name) $env(licensee_name)}] {
        set userinfo(name) " "
    }
    if [catch {set userinfo(corp) $env(licensee_corp)}] {
        set userinfo(corp) " "
    }
    set userinfo(Version) $env(SIMILE_VERSION)
    
    set userinfo(license_code) \
            [join [lrange [split $env(license_code) =] 1 end] =]
    scan [info tclversion] {%d.%d} MAJ MIN
    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN}.$env(SIMILE_VERSION).$onUnix
    if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
        # maybe we built the package index for a different os, try again
        catch {pkg_mkIndex ../System/lib/Stubs *[info sharedlibextension]}
        if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
            error "Could not find a stub for Simile $env(SIMILE_VERSION) and TclTk ${MAJ}.${MIN} under $tcl_platform(platform)"
        }
    }
    loadcommands
    randseed [clock clicks]
}

load_c_stub

#if {[string equal process $runHow]} {
#    proc BringParameter {args} {
#	puts [list get $args]
#	return [gets stdin]
#    }
#}
#

proc do_in_editor {args} {
    puts [list get $args]
    while {1} {
	set result [gets stdin]
	set info [lindex $result 1]
	switch [lindex $result 0] {
	    do {
		do $info
	    } err {
		error [lindex $info 0] [join $info \n]
	    } res {
		return $info
	    }
	}
    }
}

proc PrefValue {arrVal val} {
    return [do_in_editor PrefValue $arrVal $val]
}

proc GetTransTable {val} {
    return [do_in_editor GetTransTable $val]
}

proc do {argList} {
    global runHow errorInfo

    if {[catch $argList response]} {
	set result [list err [split $errorInfo \n]]
    } else { 
	set result [list res $response]
    }
    if {[string equal interp $runHow]} {
	return $result
    } else {
	puts $result
    }
}
