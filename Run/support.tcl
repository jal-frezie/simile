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
    global nodedata
    foreach record [array names nodedata] {
	if {[string equal $dest [burrow_to ::AME_model<> \
				     [lindex $nodedata($record) 6] $indices]]} {
	    return [lindex $nodedata($record) 0]
	}
    }
    return unavailable
}

proc collect {tgt index count args} {
    global paramLocns
    set val [BringParameter $paramLocns($index,arr) $paramLocns($index,nod) \
		  $args]
    if {[llength $val]} {
# Check that input source exists, it will not if model is being initialized
	set $tgt $val
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

proc tcl_setparamarray {model node} {
    global paramLocns

    set paramIdx [getinfo $node 6]
puts "tcl_setparamarray $model $node $paramIdx"
    set paramLocns($paramIdx,nod) $node
    set paramLocns($paramIdx,arr) tclParmData ;# was [InputVarFor $model $node]
}

proc tcl_cleartimeseries {node} {
    global paramLocns

    set paramIdx [getinfo $node 6]
    upvar #0 $paramLocns($paramIdx,arr) varData
    array unset varData $node*
}

proc tcl_setparamelement {node inds val} {
    global paramLocns

    set paramIdx [getinfo $node 6]
    upvar #0 $paramLocns($paramIdx,arr) varData
    set varData([join [concat [list $node] $inds] ,]) $val
} 
 

proc tcl_settimepointelement {node inds val} {
    global paramData

    set paramData([join [concat [list $node] $inds] ,]) $val
} 
 

proc InputVarFor {topNode node} {
    switch -glob [GetTclCompProperty $topNode Type $node] {
	FLAG {
	    return checkStates
	} ENUM(*) {
	    return comboChoices
	} default {
	    if {[string equal TABLE [GetTclCompProperty $topNode Eval $node]]} {
		return paramData
	    } else {
		return sliderVals
	    }
	}
    }
}
   
proc oldcollect {tgt node count args} {
    global myNode
# ShowMess debug info "Collecting...$tgt...$node...$count...$args" ok
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
	if {[string equal REAL [getinfo $node 0]]} {
	    set $tgt $val
	} else {
	    set $tgt [expr int($val)]
	}
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

proc old_stage_incr {ns_extras step v} {
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

proc stage_incr {ns_extras step v} {
    global adapt
    upvar \#0 $ns_extras extras
    if {[info exists extras]} {
	scan $extras "%f %f %f" t1 t2 t3
    } else {
	set t1 [set t2 [set t3 0]]
    }
# In this version, the three intermediate increments are kept in t1-t3 while
# building the full R-K increment. After this is complete they are assigned:
# t1 = initial rate of change (used when redoing step with different dt)
# t2 = last increment (used to undo step)
# t3 = estimate of next initial increment
    if {[glob_element dts 0]<0} {
        set dv [step_incr $step $t1]
    } else {
        set dv [step_incr $step $v]
    }
    switch -- [expr int([glob_element dts 0])] {
        0 { ;# Euler
            set t1 $v
            set t2 $dv
            set t3 $dv
            set result $dv
        } 1 { ;# these 4 are R-K
            set result [expr [set t1 $dv]/2.0]
        } 2 {
            set result [expr ([set t2 $dv]-$t1)/2.0]
        } 3 {
            set result [expr [set t3 $dv]-$t2/2.0]
        } 4 {
            set t2 [expr $t1/6 + $t2/3 + \
                                $t3/3 + $dv/6]
            set mid [expr $t2 - $t3]
            set t3 [expr (-$t1 + 2*$t3 + 2*$dv)/3]
            set t1 [expr $t1/[glob_element dts $step]]
            set result $mid
        } -1 { ;# undoes previous change Euler
            set last_incr $t2
            set t3 $dv
            set result [expr [set t2 $dv]-$last_incr]
        } -2 { ;# undoes previous change R-K
            set result [expr [expr [set t1 $dv]/2.0]-$t2]
        } 10 { ;# does not change compartment, just checks for errors
#            if {$dv} {
	        set errMagn [expr abs($dv-$t3)]
#puts "p10 pred_change $extras(pred_change) dv $dv errMagn $errMagn"
	        if {$errMagn > $adapt(maxErr)} {
		    set adapt(maxErr) $errMagn
	        }
#            }
            set result 0
        }
    }
    set extras [list $t1 $t2 $t3]
    return $result
}

proc do_model {what mstep} {
#puts "do_model $what $mtime $mstep"
    if {[catch {eval ::AME_model<>::${what} $mstep}]} {
	RaiseTclExecError $what $mstep
    }
}

proc RaiseTclExecError {mproc mstep} {
    global myNode errorInfo model_prog ts phasecount

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
    error [list tcl_model_err $mproc $dest $ts($phasecount) $mstep $whoopsie] \
	$errorInfo
}

proc CheckGUI {node modelTime thisOp} {
    global GUILog dispDone
    
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
	if {[string equal ext $thisOp]} {
	    set col 2
	} else {
	    set col 1
	}
	set result [InteractGUI $node $modelTime $col]
	set thisUpdate [clock clicks -milliseconds] ;# GUI may have taken time
	set GUILog(lastUpdate) $thisUpdate
    } else {
	set result 0
    }
    set GUILog(lastExit) $thisUpdate
    return $result
}
    
proc abort_check {args} {
    global myNode
    if {[AbortCheck $myNode]} {
	error "abort request from the user"
    }
}

proc TclResetModel {node topPhase} {
    global myNode ts dts steps phasecount

    set myNode $node
    if {$topPhase <= 0} {
        for {set tweakPhase 1} {$tweakPhase <= $phasecount} {incr tweakPhase} {
            set ts($tweakPhase) 0
            set dts($tweakPhase) [expr $steps($tweakPhase)]
        }
    }
    do_model evalmodel $topPhase
    return 1
}

proc TclExecuteModel {node howInt start end errLim} {
    global dts steps phasecount adapt
#    if {[string equal cancel [ShowMess debug info "XM from $start to $end" okcancel]]} {
#	error cancelled
#    }
    set freq [expr $steps($phasecount)*pow(2,-$adapt(doublings))]
    set xtime $start
    while {($end-$xtime)*$freq>0} { ;# freq only affects sign
	set madeStep 0
	set firstPass 1
	set bigPhase [PhaseFor $xtime $freq $phasecount]
# that is the biggest phase we will try to run, we may not succeed
	if {[CheckGUI $node $xtime ph$bigPhase]} {
	    return [list 0 $xtime]
	}
        while {!$madeStep} {
            # stretch interval to hit end if necssary
            if {$xtime/$freq+1.0625>$end/$freq} {
                set freq [expr $end-$xtime]
                set xtime $end
            } else {
                set xtime [expr $xtime+$freq]
            }
	    SetDTs $bigPhase $xtime

	    do_model advancemodel $bigPhase
	    if {[string equal Euler $howInt]} {
                if {$firstPass} {
 		    set dts(0) 0
                } else {
                    set dts(0) -1
                }
                AdvanceTime $node $bigPhase 1
		do_model updatemodel $bigPhase
	    } else {
                if {$firstPass} {
                    set dts(0) 1
                } else {
                    set dts(0) -2
                }
                do_model updatemodel $bigPhase
		RKUpdate $node $bigPhase
	    }
            set firstPass 0
            if {!$errLim} {
                set madeStep 1
            } else {
                # get the model to generate its error estimate
                do_model evalmodel $bigPhase
                set adapt(maxErr) 0
                set dts(0) 10
                do_model updatemodel $bigPhase
#puts "time $xtime max error $adapt(maxErr) doublings $adapt(doublings)"
                if {$adapt(maxErr)>$errLim} {
                # error too great; put comps back and try shorter
                    if {$adapt(doublings)<30} {
                        AdvanceTime $node $bigPhase -1 ;# back to the start
                        set xtime [expr $xtime-$freq]
                        incr adapt(doublings)
                        set freq [expr $steps($phasecount) * \
                                      pow(2,-$adapt(doublings))]
                        set bigPhase [PhaseFor $xtime $freq $phasecount]
                    } else {
                        # signal problem
                        error [list tcl_model_err evalmodel unknown $xtime $bigPhase \
				  discontinuity]
                    }
                } else {
                    set madeStep 1
                    if {$adapt(doublings) && $adapt(maxErr)<$errLim/16} {
                        # low error; try longer next time if poss
                        incr adapt(doublings) -1
                        set freq [expr $steps($phasecount) * \
                                      pow(2,-$adapt(doublings))]
                    } ;# lengthen time step
                } ;# timestep too short or not
            } ;# error limit exists
        } ;# made progress
	do_model evalmodel $bigPhase
    }
    if {[CheckGUI $node $end ext]} {
	return [list 0 $xtime]
    }
    return [list 1 $xtime]
}
	    
proc PhaseFor {current step soFar} {
    global steps

#ShowMess debug info "PhaseFor $current $step $soFar" ok
    if {$soFar == 1} {
	return 1
    }
    set try [expr $soFar-1]
    set nextStep $steps($try)
    set last [expr $current+($step/2.0)]
    set next [expr $last+$step]

    set tryCurrent [expr $nextStep*floor($last/$nextStep)]
    set tryNext [expr $nextStep*floor($next/$nextStep)]
    if {$tryCurrent == $tryNext} {
	return $soFar
    } else {
	return [PhaseFor $tryCurrent $nextStep $try]
    }
}

proc RKUpdate {node phase} {
    global dts
    AdvanceTime $node $phase 0.5
    set dts(0) 2
    do_model evalmodel $phase
    do_model updatemodel $phase
    set dts(0) 3
    do_model evalmodel $phase
    do_model updatemodel $phase
    AdvanceTime $node $phase 0.5
    set dts(0) 4
    do_model evalmodel $phase
    do_model updatemodel $phase
    set dts(0) 1
}
    
proc SetDTs {phase current} {
    global ts dts phasecount
    for {set tweakPhase $phase} {$tweakPhase<=$phasecount} {incr tweakPhase} {
	set dts($tweakPhase) [expr $current-$ts($tweakPhase)]
    }
}

proc AdvanceTime {node phase fraction} {
    global ts dts phasecount setFromSeries
    for {set tweakPhase $phase} {$tweakPhase<=$phasecount} {incr tweakPhase} {
	set ts($tweakPhase) [expr $ts($tweakPhase)+$dts($tweakPhase)*$fraction]
    }
#    set seriesPt [expr $ts($phasecount)+$dts($phasecount)*$fraction/2]
    UpdateTimeSeries $node $ts($phasecount)
    set setFromSeries($node,current) $ts($phasecount)
}

# try to minimize effort at runtime -- list timepoints for each node...
proc InitTimeSeries {topNode} {
    global setFromSeries paramData
    array unset setFromSeries
    foreach node [GetTclCompProperty $topNode Objects] {
	if {[string match INPUT [GetTclCompProperty $topNode Eval $node]]} {
#puts "node $node timePts [array names paramData $node,*]"
	    foreach timePt [array names paramData $node,*] {
		set ${node}([lindex [split $timePt ,] 1]) 1
	    }
	    if {[array size $node]} {
		set setFromSeries($topNode,$node,times) \
		    [lsort -real [array names $node]]
		set setFromSeries($topNode,$node,next) -1 ;# no data yet loaded
		set setFromSeries($topNode,$node,wraps) 0 ;# wraparound count
#puts "initted $setFromSeries($topNode,$node,times)"
	    }
	}
    }
    set setFromSeries($topNode,current) 0
}

proc ResetTimeSeries {topNode} {
    global setFromSeries
    foreach pt [array names setFromSeries $topNode,*,next] {
	set setFromSeries($pt) -1
	set node [lindex [split $pt ,] 1]
	set setFromSeries($topNode,$node,wraps) 0 ;# wraparound count
    }
    set setFromSeries($topNode,current) 0
}

# for each node we have a list of times in the time series, and a pointer to 
# where we are in the list. If the time has gone past that pointed to, signal 
# the data to be written and look at the next one...see update_from_points in
# shank.cpp...

proc UpdateTimeSeries {topNode newTime} {
    global setFromSeries paramData comboTypes
    foreach list [array names setFromSeries $topNode,*,times] {
	set ptCount [llength $setFromSeries($list)]
	if {!$ptCount} continue ;# no time points so go to next param
        set node [lindex [split $list ,] 1]
        #puts "node $node times $setFromSeries($list) next $setFromSeries($topNode,$node,next) newTime $newTime"

	set hiWraps $setFromSeries($topNode,$node,wraps)

	set loBound $setFromSeries($topNode,$node,next)
	if ($loBound>-1) {
	    set hiBound [expr $loBound+1]
	    if {$hiBound >= $ptCount} {
		if {$paramData(wrapAroundPoint,$node)} {
		    set hiBound 0
		    incr hiWraps
		} else {
		    set hiBound -1
		}
	    }
	} else {
	    set hiBound 0 ;# first point
	}

	if {$newTime>=$setFromSeries($topNode,current)} {
	    while {$hiBound>-1 && $newTime>=[lindex $setFromSeries($list) $hiBound]+$hiWraps*$paramData(wrapAroundPoint,$node)} {
		set loBound $hiBound
		set setFromSeries($topNode,$node,wraps) $hiWraps
		incr hiBound
		if {$hiBound >= $ptCount} {
		    if {$paramData(wrapAroundPoint,$node)} {
			set hiBound 0
			incr hiWraps
		    } else {
			set hiBound -1
		    }
		}
	    }
	} else {
	    while {$loBound>-1 && $newTime<[lindex $setFromSeries($list) $loBound]+$setFromSeries($topNode,$node,wraps)*$paramData(wrapAroundPoint,$node)} {
		set hiBound $loBound
		set hiWraps $setFromSeries($topNode,$node,wraps)
		incr loBound -1
		if {$paramData(wrapAroundPoint,$node) && $loBound==-1} {
		    incr setFromSeries($topNode,$node,wraps) -1
		    set loBound [expr $ptCount-1]
		}
	    }
	}

	if {$loBound>-1 && $hiBound>-1 && \
		![string equal use_last \
		      [string tolower $paramData(fillMethod,$node)]]} {
	    set interFract [expr ($newTime-$setFromSeries($topNode,$node,wraps)*$paramData(wrapAroundPoint,$node)-[lindex $setFromSeries($list) $loBound])/([lindex $setFromSeries($list) $hiBound]+($hiWraps-$setFromSeries($topNode,$node,wraps))*$paramData(wrapAroundPoint,$node)-[lindex $setFromSeries($list) $loBound])]
	    if {[string equal interpolate \
		     [string tolower $paramData(fillMethod,$node)]]} {
		set setFromSeries($topNode,$node,next) $loBound
		# cos that's what wraps refers to...now do interpolation
		set loTime [lindex $setFromSeries($list) $loBound]
		set hiTime [lindex $setFromSeries($list) $hiBound]
		set inC [RunningInC $topNode]
		foreach loValue [concat [array names paramData $node,$loTime] \
				     [array names paramData $node,$loTime,*]] \
			hiValue	[concat [array names paramData $node,$hiTime] \
				     [array names paramData $node,$hiTime,*]] {
		    set midValue [expr $paramData($hiValue)*$interFract + \
				      $paramData($loValue)*(1-$interFract)]
		    set tgtIndex [join [lreplace [split $loValue ,] 1 1] ,]
		    PlaceInArray $tgtIndex $midValue 0 $inC
		}
		return
	    }
	    if {$interFract>0.5} { ;# fillMethod is USE_CLOSEST
		set loBound $hiBound
		set setFromSeries($topNode,$node,wraps) $hiWraps
	    }
	}
	if {$loBound>-1 && $loBound!=$setFromSeries($topNode,$node,next)} {
	    set useTime [lindex $setFromSeries($list) $loBound]
	    set setFromSeries($topNode,$node,next) $loBound
            set inC [RunningInC $topNode]
            foreach tsValue [concat [array names paramData $node,$useTime] \
                                 [array names paramData $node,$useTime,*]] {
                set tgtIndex [join [lreplace [split $tsValue ,] 1 1] ,]
                PlaceInArray $tgtIndex $paramData($tsValue) 0 $inC
            }
	}
    }
}



proc OldUpdateTimeSeries {topNode newTime} {
    global setFromSeries paramData comboTypes
    foreach list [array names setFromSeries $topNode,*,times] {
        set loopOffset [expr $setFromSeries($topNode,$node,wraps) * \
                            $paramData(wrapAroundPoint,$node)]
	upvar 0 setFromSeries($topNode,$node,next) series
        set jumping 1
        while {$jumping} {
            if {$newTime>=$setFromSeries($topNode,current)} {
                if {$series < $ptCount} {
                    set mkTime [lindex $setFromSeries($list) $series]
                    set actTime [expr $mkTime+$loopOffset]
                    if {$newTime >= $actTime} {
                        set useTime $mkTime
                        incr series
                    } else {
                        set jumping 0
                    }
                } elseif {$paramData(wrapAroundPoint,$node)} {
                    set series 0
                    incr setFromSeries($topNode,$node,wraps)
                    set loopOffset \
                        [expr $loopOffset+$paramData(wrapAroundPoint,$node)]
                } else {
                    set jumping 0
                }
            } else {
                if {$series > 0} {
                    set mkTime [lindex $setFromSeries($list) [expr $series-1]]
                    set actTime [expr $mkTime+$loopOffset]
                    if {$newTime < $actTime} {
                        incr series -1
                        if {$series==0 && $paramData(wrapAroundPoint,$node)} {
                            set series $ptCount
                            incr setFromSeries($topNode,$node,wraps) -1
                            set loopOffset \
                                [expr $loopOffset-$paramData(wrapAroundPoint,$node)]
                        }
                        if {$series > 0} {
                            set useTime [lindex $setFromSeries($list) \
                                             [expr $series-1]]
                        }
                    } else {
                        set jumping 0
                    }
                } elseif {$paramData(wrapAroundPoint,$node)} {
                    set series $ptCount
                    incr setFromSeries($topNode,$node,wraps) -1
                    set loopOffset \
                        [expr $loopOffset-$paramData(wrapAroundPoint,$node)]
                } else {
                    set jumping 0
                }
            }
        }
	    
        if {[info exists useTime]} {
            set inC [RunningInC $topNode]
            #            upvar \#0 $tgtVar inputSrc
            #puts "inputSrc stands for [do_for_node $topNode InputVarFor $node]"
            # do it the easy way if a scalar
            #puts "looking for paramData($node,$useTime)"
            #            if {[info exists paramData($node,$useTime)]} {
            #                set inputSrc($node) $paramData($node,$useTime)
            #puts "set inputSrc($useTime) $paramData($node,$useTime)"
            #                return
            #            }
            set trans [lindex [GetTransTable $node] end]
            foreach tsValue [concat [array names paramData $node,$useTime] \
                                 [array names paramData $node,$useTime,*]] {
                #puts "setting inputSrc([join [lreplace [split $tsValue ,] 1 1] ,])"

# OK next job is to select right between-points action. useTime has the lower
# time point, series the index of the higher one (but may be off end)
                set tgtIndex [join [lreplace [split $tsValue ,] 1 1] ,]
                #                set inputSrc($tgtIndex) $paramData($tsValue)
                PlaceInArray $tgtIndex $paramData($tsValue) 0 $inC
            }
        }
    }
}

#proc at_time_step {} {
#    return [expr [glob_element dts 0]<=1]
#}
#
proc loses {prob phase} {
    global dts
    if {$prob <= 0 || $dts(0)==-1} {
	return 0
    } elseif {$prob >= 1} {
	return 1
    } else {
	set kills_per_step [expr $dts(0)?4:1]
	return [expr [ame_rand 0 1] > \
		    pow(1-$prob, $dts($phase)/$kills_per_step)]
    }
}

# delete_list is a dummy procedure. What it should do is clear the
# submodel instances from the list supplied, but since (a) it would also
# need the parent namespace and (b) they tend to get reused anyway in
# tcl, I have not bothered.

proc delete_list {list_id} {
}

# makes things that look like pointers for tcl
set ptrCount 0
proc HexPtr {} {
    return [format ptr%08x [incr ::ptrCount]]
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

proc init_pop {metaTxt crNode ptCount channelId maker} {
    upvar 1 $metaTxt meta
    set lastIndx [expr $ptCount+int([max 0 $crNode])]
    while {$ptCount<$lastIndx} {
	incr ptCount
	if {[prune $ptCount meta 1]} {
	    set submodelptr [set $meta]
	    set ${submodelptr}::new_instance 0
	    set $meta [set ${submodelptr}::next]
	} else { ;# Instance exists
#	    ${byrecspointer}::submodel1maker submodel1<$loop>
#	    set submodel1pointer ${byrecspointer}::submodel1<$loop>
	    # fantasy cmd replacing above:
	    set submodelptr [eval [list $maker] [HexPtr]]
	    set ${submodelptr}::instanceid $ptCount
	    set ${submodelptr}::new_instance 1
	} ;# end(cond,Instance exists)
	set ${submodelptr}::parentId 0
	set ${submodelptr}::channelId $channelId

	set ${submodelptr}::next [set $meta]
	set $meta $submodelptr
	set meta ${submodelptr}::next
    }
    return $lastIndx
}

proc compare_instance_status {testInstName refInst num} {
    upvar 1 $testInstName testInst
    #    ShowMess debug info "testInst $testInst refInst $refInst" ok
    if {[string match 0 $testInst]} {return 1}
    for {set ptr 0} {$ptr < $num} {incr ptr} {
        if {[lindex $testInst $ptr]<[lindex $refInst $ptr]} {return -1}
        if {[lindex $testInst $ptr]>[lindex $refInst $ptr]} {return 1}
    }
    return 0
}

proc compare_values {v1 indexTxt v2 length step} {
    # ShowMess debug info "compare_values\n$v1\n$indexTxt\n$v2\n$length\n$step" ok
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

proc assign_if_max {sample payload runner pick} {
    upvar 1 $runner runnerV
    if {$sample > $runnerV} {
	upvar 1 $pick pickV
	set runnerV $sample
	set pickV $payload
    }
}

proc assign_if_min {sample payload runner pick} {
    upvar 1 $runner runnerV
    if {$sample < $runnerV} {
	upvar 1 $pick pickV
	set runnerV $sample
	set pickV $payload
    }
}

proc ame_rand {lowBound highBound} {
    return [expr $lowBound +[random01]*($highBound - $lowBound)]
}


proc stop_on_id {compId code} {
    error "User-defined interruption code $code"
}

proc stop {code} {
    stop_on_id 0 $code
}

proc GetTclCompProperty {topNode prop args} {
    global nodecount nodedata phasecount steps
    set node [lindex $args 0]
    set set [lrange $args 1 end]
#    set nodecount [set nodecount]
    # first do cases that don't need any other data
    switch -regexp $prop {
	Objects {
	    set result {}
# objects must be in order for ModelInspector to work
	    for {set record 2} {$record<=$nodecount} {incr record} {
		lappend result [lindex $nodedata($record) 0]
	    }
	    return $result
	} SetStep { ;# node is actually time
	    set steps($set) $node
	    return $phasecount
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
	    if {[llength $set]} {
		eval {setup_graph_data $index} $set
	    } else {
		return [graph_table 21 $index]
	    }
	} Caption {
	    return [GetFullCaption [findRecord $node]]
#ShowMess debug info "node $node data [array get nodedata] npath $numericPath" ok
	} IdFromCapt {
	    foreach record [array names nodedata] {
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
	} Spec|Desc|Comment {
	    set which [lsearch {Name Spec Desc Comment} $prop]
	    set targetVar [lindex [getinfo $node 10] $which]
	    if {![string equal NULL $targetVar]} {
		return [set ::$targetVar]
	    }
	} Value {
	    return [tcl_insert $node [lindex $set 0]]
	} default {
	    error "Property $prop not available in debug mode"
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
    foreach record [array names nodedata] {
	if {[ListSameNumbers [lindex $nodedata($record) 6] $ptHand]} {
	    return $nodedata($record)
	}
    }
}    

proc ListSameNumbers {list1 list2} {
    set target [llength $list1]
    if {$target != [llength $list2]} {return 0}
    for {set count 0} {$count < $target} {incr count} {
        if {[lindex $list1 $count] != [lindex $list2 $count]} {return 0}
    }
    return 1
}

proc GetFullCaption {line} {
    if {[llength [lindex $line 6]] < 3} {
	return {}
    } else {
	set parentCapt [GetFullCaption [ParentLine $line]]
	append parentCapt / [set ::[lindex [lindex $line 11] 0]]
	return $parentCapt
    }
}				      

proc TypeAsList {arrName count} {
    upvar \#0 $arrName arrVal
    upvar \#0 $arrVal($count,2) tName
    set result [list $arrVal($count,1) $tName]
    upvar \#0 $arrVal($count,3) arrTypes
    for {set elt 1} {$elt<=$arrVal($count,1)} {incr elt} {
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
	lappend localETs [TypeAsList [lindex $line 3] $count]
	incr count -1
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
    do_in_editor after 1 $args
}

if {![info exists runHow(where)]} { ;# we are not at home, so call
proc do_in_editor {args} {
    global masterId
    return [thread::send $masterId [lrange [info level 0] 1 end]]
}

proc old_do_in_editor {args} {
    global runHow sender fromEditor
#    tk_messageBox -message "callback $args"
    if {[string equal send_sync $runHow(return)]} {
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
}

proc res {value} {
    global fromEditor
    set fromEditor [list res $value]
}

proc err {value} {
    global fromEditor
    set fromEditor [list err $value]
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
    switch $runHow(return) {
	interp {
	    return $result
	} send_async {
	    eval $sender {after idle [list FeedModel $myNode [list $result]]}
	} send_sync {
	    catch {eval $sender {FeedModel $myNode [list $result]}}
	} pipe {
	    puts [split $result \n]
	}
    }
    return done
}

########################### stuff for both languages below ###############
proc PlaceInArray {where what when inC} {
    #puts "PlaceInArray $where $what $inC"
    set map [split $where ,]
    if {$inC} {
	if {[catch {
	    if {$when} {
		c_settimepointelement [lindex $map 0] \
		    [lrange $map 2 end] [lindex $map 1] $what
	    } else {
		c_setparamelement [lindex $map 0] \
		    [lrange $map 1 end] $what
	    }
	} urr]} {
	    FPError $urr {}
	}
    } else {
	if {$when} {
	    tcl_settimepointelement [lindex $map 0] [lrange $map 1 end] $what
	} else {
	    tcl_setparamelement [lindex $map 0] [lrange $map 1 end] $what
	}
    }
}

proc SetWrapTime {inC where args} {
    global paramData
    if {$inC} {
	eval c_setwraparoundtime $where $args
    } else {
	eval set paramData(wrapAroundPoint,$where) $args
    }
}

# this one takes numerical for c and textual for tcl
proc SetFillMethod {inC where {what {}}} {
    global paramData

    set fillMtds {use_last use_closest interpolate}
    if {[string length $what]} {
	if {[set which [lsearch $fillMtds [string tolower $what]]]<0} {
	    error "bad fill method: $what"
	}
    } else {
	set which {}
    }
    if {$inC} {
	lindex $fillMtds [eval c_setfillmethod $where $which]
    } else {
	eval set paramData(fillMethod,$where) [string toupper $what]
    }
}

