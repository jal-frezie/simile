# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

# earlier versions tried to reproduce the master's auto_path minus the
# Tk-specific bits, but much easier just to pass it -- the Tk bits do
# no harm

# Do not include tcl support -- debug not needed in client5d, R or SimiLive
# source [file join [file dirname $env(SYSDIR)] Run support.tcl]

proc load_c_stub_1 {node ap} {
    set ::auto_path $ap
    scan [info tclversion] {%d.%d} MAJ MIN
#    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN} ;# .$env(SIMILE_VERSION).$onUnix
    package require -exact Ame_dll $stubPkg
    randseed [clock seconds]
    # above was previously [clock scan now] but this had the disadvantage that
    # it immediately loaded a whole lot of on-demand parsing packages into the 
    # exec thread which aren't used anywhere else and sometimes cannot be found
}

# load_dll adds a dll to the system. Trees are added bottom up, so model_id
# is always that most recently added (even if not recompiled)

proc ex_load_dll {topNode lang progDir id node incs} {
    #   phasecount and nodedata are set in generated code
    global model_id model_ids model_prog env execThread
    if {[string match tcl $lang]} {
	if {![file exists $progDir/model.tcl]} {
	    return 0
	}
	set model_prog($topNode) $progDir/model.tcl
	# This won't catch defns in subdirectories
	set funs [file join [file dirname $env(SYSDIR)] Functions *.tcl]
	foreach fnFile [glob -nocomplain $funs] {
	    namespace eval ::tcl::mathfunc [list source $fnFile]
	}
	foreach fnFile $incs {
	    namespace eval ::tcl::mathfunc [list source $fnFile]
	}
	source $model_prog($topNode)
	if {![catch {IdentField $simile_identifier version} buildV]} {
	    return [expr $buildV==$env(SIMILE_VERSION)]
        } else {
            return 1 ;# works if no IdentField in interp
        }
    } else {
	set progFile [file join $progDir model${id}[info sharedlibextension]]
	if {![file exists $progFile]} {
	    return 0
	}
	set new_model_id [loadmodel $progFile $node]
	set model_id $new_model_id
        #        set model_id [loadmodel $nameBase[info sharedlibextension] $node]
        set model_ids($node) $new_model_id
	return 1 ;# was $new_model_id but bytecodes bad for swi
    }
}

proc Nappy {args} {
    if {[catch $args poop]} {
	return [list 1 $poop $::errorInfo]
    } else {
	return [list 0 $poop]
    }
}

proc update_executable {node lang} {
    #    ShowMess debug info "References are $finderList" ok
    global nodeId model_id instance_id

    set nodeId $node
    # For the toplevel model, make an instance. This will also make
    # instances of any fixed-membership submodels immediately, so they had
    # better already be loaded
    switch $lang {
	c {
	    set instance_id [c_createmodel $model_id]
	} tcl {
    #    ShowMess debug info "model instance $instance_id created" ok
	    set model_id {}
	    set instance_id {}
	}
    }
}

proc ExecuteTo {node current pause unitLength display foci \
		    intMethod maxErr lmtPause evtMsg evtDisp} {
    global dispDone actDone

    set dispDone 0
    set actDone 0 ;# nothing so far
    set forward [expr {($pause>$current)*2-1}] ;# 1 for forward, -1 for back
    set scaled_current [expr {$current*$unitLength}]
    if {$display} {
	set lastDisp [expr int($current/$display)]
	set timedDisp 1
    }
    set currentMode start
    set evtPause [expr {$evtMsg || $evtDisp}]
    set payload {}
    while {[lsearch {exit stop} $currentMode]==-1} {
	if {$display} {
	    if {$timedDisp} {
		set nextDisp [expr 1.0*$display*[incr lastDisp $forward]]
# ensure display updated at end of run -- make optional?
		if {($nextDisp-$pause)*$forward>0} {
		    set nextDisp $pause
		}
		set scaled_next [expr {$nextDisp*$unitLength}]
	    }
	} else {
	    set nextDisp [expr 2*$pause-$current]
	    set scaled_next [expr {$pause*$unitLength}]
	}
	set howAndWhen [ExecuteModel $node $intMethod $scaled_current \
			    $scaled_next $maxErr $lmtPause $evtPause]
	set scaled_current [lindex $howAndWhen 1]
	set displayNow 0
	switch -- [lindex $howAndWhen 0] {
	    -1 {
		set currentMode exit
	    } 0 {
		set currentMode stop
	    } 2 { ;# event
		if {$evtDisp} {
		    set displayNow 1
		}
		if {$evtMsg} {
		    ExplainError $node [lrange $scaled_current 1 end] unused
		    set currentMode stop
		}
		set scaled_current [lindex $scaled_current 3]
	    } 4 { ;# compartment out of range
		ExplainError $node [lrange $scaled_current 1 end] unused
		set currentMode stop
	    }
	} ;# default: keep going
	set current [expr {$scaled_current/$unitLength}]
#	if {![info exists runState($node,cnvs)]} {
#	    return $currentMode ;# run control window killed?
#	}
	set timedDisp [expr {($current-$nextDisp)*$forward > -1e-12}]
	if {($timedDisp || $displayNow) && \
		![string equal exit $currentMode]} { ;# do a display update
	    set oldPayload $payload
	    set payload {}
	    foreach point $foci {
		if {[catch {GetPayload $node $point} dataHand]} {
# data has gone, so hope it is no longer needed
		} else {
		    lappend payload $point $dataHand
		}
	    }
	    if {[ShiftDisplays $node $payload [format %.8g $current] \
		     $display]} {
		set currentMode stop
	    }

#	    if {![TellAllHelpers $node $payload Display $current $display 1]} {
#		set currentMode stop
#	    }
	    # now it is done, previous one must have finished, if any
	    FreeAll $oldPayload
	}
	if {($current-$pause)*$forward > -1e-12} {
	    set currentMode stop
	}
    }
    InteractGUI $node $scaled_current 1
# above is required to leave right time in progress display if not finishing
# on display interval boundary
    waitForDisps
    FreeAll $payload
    return $currentMode
}

proc GetPayload {node point} {
    if {[RunningInC $node]} {
	return [list ptr 0 [GetHandle $node $point]]
# redundant fields make list of unique length
    } else {
	return [lindex [tcl_insert $point {}] 0]
    }
}

proc GetHandle {node point} {
    global model_id instance_id
    return [handle_data $model_id $instance_id $point]
}
  
proc ReleaseHandle {node handle} {
    free_data_handle $handle
}

proc FreeAll {load} {
    foreach {id hdl} $load {
	if {[llength $hdl]==3} {
	    free_data_handle [lindex $hdl 2]
	}
    }
}

proc ResetModel {myNode howInt initTime redo} {
    global model_id instance_id dispDone

    set dispDone 0 ;# allow execution to call back
    set readyForRK [expr {![string equal Euler $howInt]}]
    if {[catch {
	if {[string bytelength $model_id]} {
#	    set model_id $myNode
	    c_resetmodel $model_id $instance_id $initTime \
		$readyForRK $redo
	} else {
	    TclResetModel $myNode $initTime $readyForRK $redo
	}
    } errList]} {
	if {[string match tcl_model_err* $errList]} {
	    set severity [ExplainError $myNode [lrange $errList 1 end] \
			  $::errorInfo]
	} else {
	    error "Unexpected problem in Tcl model initialization" $::errorInfo
	}
	set done 0
    } else {
	set done 1
    }
#    set ::userAction 1
#    InteractGUI $instance_id 0 2 ;# put somewhere else?
    return $done
}

proc ExecuteModel {myNode howInt start finish errLim lmtPause evtPause} {
    global model_id instance_id
    if {[catch {
	if {[string bytelength $model_id]} {
#	    set model_id $myNode
	    c_executemodel $model_id $instance_id \
		[expr ![string equal Euler $howInt]] \
		$start $finish $errLim $lmtPause $evtPause
	} else {
	    TclExecuteModel $myNode $howInt $start $finish $errLim \
		$lmtPause $evtPause
	}
    } errList]} {
	if {[string match tcl_model_err* $errList]} {
#	    set severity [ExplainError $myNode [lrange $errList 1 end] \
			  $::errorInfo]
	} else {
	    error "Unexpected problem in Tcl model execution" $::errorInfo
	}
    } elseif {[lindex $errList 0]>-1} { ;# requires no message
	return $errList
    } elseif {[lindex $errList 5] eq "event"} {
	return [list 2 $errList]
    }
    set severity [ExplainError $myNode [lrange $errList 1 end] $::errorInfo]
    InteractGUI $myNode [lindex $errList 3] 2
    return [list $severity [lindex $errList 3]]
}

proc waitForDisps {} {
    global dispDone
    if {![info exists dispDone]} {
	vwait dispDone
    }
}

proc OuterCheck {} {
    global nodeId

    set abortLevel [AbortCheck $nodeId]
    return [expr {$abortLevel>=10}]
}

proc OuteractGUI {time mode} {
    global nodeId

    return [InteractGUI $nodeId $time $mode]
}

if {[info exists masterId]} { ;# we are in separate interp
    proc PullAction {inst} {
	return [tsv::get action $inst]
    }

    proc AbortCheck {nodeId args} {
	global masterId
	thread::send -async $masterId [info level 0]
	return [PullAction $nodeId]
    }
 
    proc InteractGUI {nodeId args} {
	global masterId
	thread::send -async $masterId [info level 0]
	return [PullAction $nodeId]
    }
 
# This one needs to wait till previous call finished    
    proc ShiftDisplays {nodeId args} {
	global masterId dispDone
	waitForDisps
	if {$dispDone} { ;# helper has stuffed up
	    return 1
	} else {
	    unset dispDone
	    thread::send -async $masterId [info level 0] dispDone
	    return [PullAction $nodeId]
	}
    }
# these are straight copies
    foreach straight {AddLogEntry ExecQuery TransEnums InDays} {
	proc $straight {args} {
	    global masterId

	    waitForDisps
	    return [thread::send $masterId [info level 0]]
	}
    }
}

proc RunningInC {myNode} {
    global model_id
    return [string bytelength $model_id] ;# it is ready
} 
    
proc GetCCompProperty {topNode prop args} {
    global model_id instance_id
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    set numberWangs Caption|MinVal|MaxVal|Trans|Spec|Desc|Comment|Base
    switch -regexp $prop [list \
	Objects {
	    return [lrange [listobjects \
				$model_id] 1 end]
	} SetStep { ;# node is actually time
	    return [c_setstepmodel $instance_id $node $set]
	} Class|Type|Eval {
	    array set propData [list Class,cIdx 11 Class,names \
			    {SUBMODEL VARIABLE COMPARTMENT FLOW CONDITION \
			       CREATION REPRODUCTION IMMIGRATION LOSS ALARM \
			       EVENT SQUIRT STATE} \
			    Type,cIdx 1 Type,names \
			    {VALUELESS REAL INTEGER FLAG EXTERNAL} \
			    Eval,cIdx 2 Eval,names \
			    {EXOGENOUS DERIVED TABLE INPUT GHOST LIMIT RECALL \
				 BLOCK POPULATION GRID HONEYCOMB}]
	    set numericVal [c_getvalue $topNode $node $propData($prop,cIdx)]
	    if {![string is integer -strict $numericVal]} {
		return $numericVal
	    }
	    if {[string equal Type $prop] && $numericVal>=10} {
		return ENUM([expr $numericVal-10])
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
		eval {getvalue $model_id $node 4} $set
	    } else {
		return [c_getvalue $topNode $node 3]
	    }
	} $numberWangs {
	    set dataWang [lindex {5 6 8 12 13 14 15 16} \
			      [lsearch [split $numberWangs |] $prop]]
	    return [c_getvalue $topNode $node $dataWang]
	} IdFromCapt {
	    # node is actually caption in this case
	    if {[catch {getnodeid $model_id $node} id]} {
		set id nomatch
	    }
	    return $id
	} default {
#puts "GetCCompProperty $topNode $prop $args"
	}
			  ]
}

# wraps c++ defined version in different interp
proc c_getvalue {topNode node action} {
    global model_id
    set res [getvalue $model_id $node $action]
    return $res
}
	    
#proc getinfo {topNode node field} {
#    getinfo $node $field
#}

proc ListToArray {topNode tgt subs numSubs trans dims list when useCppArray} {
#ShowMess debug info  "Go! tgt $tgt subs $subs trans $trans dims $dims list $list cpp $useCppArray" ok
    # skip over any vm arrays, their indices will not appear
    # in calls for values, but keep the translation list in sync
    # ... string match stops cleanly at end of list
#    global comboTypes
    
    if {[string equal ,bytes [lindex $list 1]]} {
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1} {
	    if {$when} {
		c_settimepointall $topNode $tgt [lindex $list end]
		SetInterval $topNode $useCppArray $tgt unit [lindex $list end-3]
		SetWrapTime $topNode $useCppArray $tgt [lindex $list end-2]
		SetFillMethod $topNode $useCppArray $tgt [lindex $list end-1]
	    } else {
		c_setparamall $topNode $tgt [lindex $list end] \
		    [lrange $list 3 end-3]
	    }
	    return -1 ;# do nothing more, the data has now been loaded to c
	} else {
	    # DO THE fallback thing (inefficient placeholder version)
	    if {[string equal REAL [lindex $list 2]]} {
		set fieldChar d
		set fieldSize 8
	    } else {
		set fieldChar i
		set fieldSize 4
	    }
	    set offset 0
	    set newList [NumberElements \
			     [DoByteArrayToList $fieldChar $fieldSize \
				  [lrange $list 3 end-3] [lindex $list end]]]
	    if {$when} {
		lappend newList [lindex $list end-2] restart \
		    others [lindex $list end-1]
	    }
	    set list $newList
	}
    } elseif {[string equal ,gdal [lindex $list 1]]} {
	# transposition not yet handled
	if {$useCppArray && [lsearch $dims {RECORDS *}]==-1 && !$when} {
	    DoNotPassTcl $topNode $tgt $dims $list
	    return -1 ;# typical fixed parameter
	} else {
	    set list [concat [NumberElements [ReadGdalRefToList $list \
						  [lindex $dims 0] \
						  [lindex $dims 1]] \
				  [expr {!$when}]] [lrange $list 7 end]]
	}
    }
# do not do this, ve no longer allow params in VM submodels...
    while {[set specialId [lsearch {START_VM MEMBERS} [lindex $dims 0]]]!=-1} {
        if {$specialId} {
            set dims [lrange $dims 1 end]
            set trans [lrange $trans 1 end]
        } else {
            set endGap [lsearch $dims END_VM]
            set dims [lreplace $dims 0 $endGap]
            set trans [lrange $trans [expr $endGap-1] end]
        }
    }
    set nextDim [lindex $dims 0]
    
    set thisTrans [lindex $trans 0]
    if {![llength $dims]} { ;# no more dims, this should be a single value
        if {[llength $list]} {
	    if {![string last ,NOW [string toupper $subs] 3]} {
		# setting current value for var param
		set idAndSubs $tgt[string range $numSubs 4 end]
		if {[catch {EnumTypeToNumber $topNode $idAndSubs $list \
				$thisTrans 0 $useCppArray} woops]} {
		    return [AddErrorTo {} $woops $subs]
		} else {
		    return 1
		}
	    } else {
		# setting value for fixed param or time point
		if {[catch {EnumTypeToNumber $topNode $tgt$numSubs $list \
				$thisTrans $when $useCppArray} woops]} {
		    return [AddErrorTo {} $woops $subs]
		} else {
		    return -1 ;# should be 0 if a comp
		}
	    }
	} else {
	    return [AddErrorTo {} missing_param_data $subs]
        }
    }

    if {[llength $list]==1} {
        #puts "setting paramData($tgt) to $headNum"
        set userDims [join $dims { x }]
	return [AddErrorTo {} [list scalar_instead_of_array $list $userDims] \
		    $subs]
    }
    if {[llength $list]%2} {
	return [AddErrorTo {} odd_index_at_end $subs,[list [lindex $list end]]]
    }
    
    set redoStep 1
    #puts "dims remaining $dims"
    if {[string match TIME $nextDim]} {
        # If time, we can have as many or as few vals as we want, and
        # they can be any number, although negative ones may not take
        # effect at start of simulation.
	# array set sub $list ;# was this faster?

        # Next call removes old time series data from the system (no throws)
        EnumTypeToNumber $topNode $tgt {} {} 1 $useCppArray
	SetWrapTime $topNode $useCppArray $tgt 0 ;# clear old wraparound point
# do not allow OTHERS if an event series

	set tgtEval [GetCompProperty $topNode Eval $tgt]
	set tgtClass [GetCompProperty $topNode Class $tgt]

	if {[string equal DERIVED $tgtEval]} {
	    set specialPts {} ;# loading measurements for PEST
	} elseif {[string equal EVENT $tgtClass]} {
	    set specialPts [list NOW INTERVAL]
	} else {
	    set specialPts [list NOW INTERVAL OTHERS]
	    SetFillMethod $topNode $useCppArray $tgt use_last ;# and fill method
	}
	SetInterval $topNode $useCppArray $tgt unit 1
    
        foreach {indx subList} $list {
	    set nextSubs $subs,[list $indx]
            if {[set pt [lsearch $specialPts [string toupper $indx]]]>-1} {
# Following never happens, TIME is always outermost dimension
#		if {[llength $subs]} {
#		    FPError [format [tr. {"%1$s" must be outermost index.}] \
#					 $indx] $subs $errorData
#		}
		if {!$pt} { ;# NOW: mark param active so it clears after event
# active is set to 2 because the param updater will be called before the model
# collects the parameter, and must clear the value the following time
		    MarkEvtParamActive $topNode $tgt $useCppArray
		}
            } elseif {![string is double -strict $indx]} {
                set redoStep [AddErrorTo $redoStep \
				  [list bad_time_point_index $specialPts] \
				  $nextSubs]
            } elseif {[string equal RESTART [string toupper $subList]]} {
		SetWrapTime $topNode $useCppArray $tgt $indx
		continue
	    } elseif {$useCppArray} {
# If there are values other than NOW, do an init step
                c_settimepointarray $topNode $tgt $indx
            }
# check for fill method if one might be appropriate
	    if {[lsearch $specialPts OTHERS]>-1} {
		set noMtd [catch {SetFillMethod $topNode $useCppArray $tgt \
				      $subList} badFill]
		if {$pt==2} { ;# fill method expected
		    if {$noMtd} {
			set redoStep [AddErrorTo $redoStep $badFill $nextSubs]
		    }
		    continue
		} elseif {!$noMtd} { ;# fill method found but not expected
		    set redoStep [AddErrorTo $redoStep \
				      [list misplaced_fill_method $subList] \
				      $nextSubs]
		}
	    }
# do same for interval (units for time series index) -- trying to call Prolog 
# from here can only lead to trouble
	    if {[string is double -strict $subList]} { ;# save time by not going Prolog
		set TSI 0
	    } else {
		set TSI [lsearch {{} s second min minute hr hour day week month year} $subList] ;# not [InDays $subList]
	    }

	    if {$pt==1} { 
# units for time series index expected -- we cannot go Prolog to parse
# them from here, so raise an "error" which will try to parse them
# before alerting the modeller
		set redoStep [AddErrorTo $redoStep [list check_uftsi $subList] \
				  $nextSubs]
		continue
	    } elseif {$TSI>0} { ;# found but not expected
		set redoStep [AddErrorTo $redoStep \
				  [list misplaced_uftsi $subList] $nextSubs]
	    }
	    set redoStep [JoinSteps $redoStep \
			      [ListToArray $topNode $tgt $subs,$indx \
				   $numSubs,$indx $trans [lrange $dims 1 end] \
				   $subList $when $useCppArray]]
        }
        return $redoStep
    }
    
    # Not time points: check the indices are good
    foreach {indx sublist} $list {
        # was array set sub $list...above would allow us to check that all indices were
        # the right type if we could be bothered...OK then...
	if {[catch {UntransVal $thisTrans $indx index} poss]} {
	    set redoStep [AddErrorTo $redoStep $poss $subs]
	} ;# seems we do not need actual position!?
        if {[info exists sub($indx)]} {
	    set redoStep [AddErrorTo $redoStep \
			      [list repeated_index $indx] $subs]
        }
        set sub($indx) $sublist
    }
    if {$redoStep != 1} { ;# do not proceed with bad time step
	return $redoStep
    }

    if {[llength $nextDim]==2 && \
                [string match RECORDS [lindex $nextDim 0]]} {
        # by-record submodel; check up to biggest. OK hows this for branez...use
        # the number of elements, because if there is an element larger than the
        # number of elements, one the same or smaller will be missing!
        set last [array size sub]
        if {!$last} {
	    set redoStep [AddErrorTo $redoStep record_count_undefined $subs]
        }
        
	# Record counts do not need to be set in Tcl
        if {$useCppArray} {
	    if {$when} {
		set map [split $subs ,]
		c_settimepointrecords $topNode $tgt [lrange $map 2 end] \
		    [lindex $map 1] $last
		# if {[catch {c_settimepointrecords $tgt [lrange $map 2 end] \
		# 		[lindex $map 1] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    } else {
		c_setrecordlist $topNode $tgt [lrange [split $subs ,] 1 end] \
		    $last
		# if {[catch {c_setrecordlist $tgt [lrange [split $subs ,] \
		# 				      1 end] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    }
	} else { ;# use old system for Tcl
	    set recordNode [lindex $nextDim 1]
	    EnumTypeToNumber $topNode $recordNode$numSubs $last {} $when \
		     $useCppArray ;# cannot fail
	}

# Hopefully, with the universal data structure, once we have set the
# record count for the outer submodel level, we will be able to access
# its contents as if they were a fixed membership array, so this
# should be redundant
#            foreach nested [lrange $dims 1 end] {
#                if {[llength $nested]==2 && \
#                            [string match RECORDS [lindex $nested 0]]} {
##puts "c_setrecordlist [lindex $nested 1] $outers $last"
#                    c_setrecordlist [lindex $nested 1] $outers $last
#                }
#            }
# So should this
#        EnumTypeToNumber paramData [lindex $nextDim 1]$subs $last \
#                {} $useCppArray
        # probably wouldn't have worked anyway for time series
    } else {
        set last $nextDim
    }
    # just post one error if no vals at all to save time
    if {![array exists sub]} {
	return [AddErrorTo $redoStep missing_array $subs]
    }
    for {set arrayPt 1} {$arrayPt <= $last} {incr arrayPt} {
        set indx [NumberToEnumType $arrayPt $thisTrans]
	set newSubs $subs,[list $indx]
        if {![info exists sub($indx)]} {
            #puts "No $indx in [array names sub]"
            set redoStep [AddErrorTo $redoStep gap_in_data $newSubs]
        } else {
	    set redoStep [JoinSteps $redoStep \
			      [ListToArray $topNode $tgt $subs,$indx \
				   $numSubs,$arrayPt \
				   [lrange $trans 1 end] [lrange $dims 1 end] \
				   $sub($indx) $when $useCppArray]]
	}
    }
    return $redoStep
}

proc DoNotPassTcl {topNode node dims tableSpec} {
#puts "dims $dims spec $tableSpec"
    if {[string equal REAL [GetCCompProperty $topNode Type $node]]} {
	set gdalType GDT_Float64
    } else {
	set gdalType GDT_Int32
    }

    package require gdal
    set hg [gdal_open_read_only [lindex $tableSpec 0]]
    set hdl [gdal_get_raster_band $hg 1]
    set dataRows [expr 1+[lindex $tableSpec 3]-[lindex $tableSpec 2]]
    set dataCols [expr 1+[lindex $tableSpec 5]-[lindex $tableSpec 4]]
    set fillRows [lindex $dims 0]
    set fillCols [lindex $dims 1]
    set bytesFromGdal [gdal_get_raster_data $hdl \
		     [expr [lindex $tableSpec 4]-1] \
		     [expr [lindex $tableSpec 2]-1] \
		     $dataCols $dataRows $gdalType $fillCols $fillRows]
    gdal_close $hg
    
    c_setparamall $topNode $node $bytesFromGdal [list $fillRows $fillCols]
}

proc JoinSteps {stepA stepB} {
    switch \
	[string is integer -strict $stepA],[string is integer -strict $stepB] {
	    0,0 {
		return [concat $stepA $stepB]
	    } 0,1 {
		return $stepA
	    } 1,0 {
		return $stepB
	    } 1,1 {
		return [expr {$stepA<$stepB?$stepA:$stepB}]
	    }
	}
}

proc AddErrorTo {old woops subs} {
    if {[catch {lrange $woops 1 end} tailList]} { ;# error msg is not a list
	set error [list [concat $woops [list $subs]]]
    } else {
	set error [list [concat [lindex $woops 0] [list $subs] $tailList]]
    }
    return [JoinSteps $old $error]
}

proc UntransVal {trans mem type} {
    if {[string compare {} $trans]} {
	if {[llength $mem]==1} {
	    set mem [lindex $mem 0]
	} ;# remove quotes or curlies
	set poss [lsearch $trans $mem]
	if {$poss == -1} {
	    if {[string equal {false true} $trans] && \
		    [string equal data $type]} {
		set trans [linsert $trans 0 boolean]
	    }
	    error [list bad_enum_type_mem $mem [lindex $trans 0] [lrange $trans 1 end] $type] 
	} else {
	    return $poss
	}
    } 
    if {[string equal index $type]} {
	if {![string is integer -strict $mem]} {
	    error [list non_integer_index $mem]
	} elseif {$mem<=0} {
	    error [list zero_or_negative_index $mem]
	}
    }
    return $mem
}

proc EnumTypeToNumber {topNode tgt head trans when useCppArray} {
    if {![llength $head]} {
        # empty head, signal to clear out old values
        if {$useCppArray} {
            c_cleartimeseries $topNode $tgt
        } else {
	    tcl_cleartimeseries $topNode $tgt
        }
    } else {
	set head [UntransVal $trans $head data]
	if {[llength $head]>1} {
	    error [list unwanted_param_array $head]
	} elseif {![string is double -strict $head]} {
	    error [list data_not_number $head]
	}
	PlaceInArray $topNode $tgt $head $when $useCppArray
    }
    #puts "just went set paramData($tgt) $paramData($tgt)"
}

########################### stuff for both languages below ###############
proc PlaceInArray {topNode where what when inC} {
    #puts "PlaceInArray $where $what $inC"
    set map [split $where ,]
    if {$inC} {
	if {$when} {
	    c_settimepointelement $topNode [lindex $map 0] \
		[lrange $map 2 end] [lindex $map 1] $what
	} else {
	    c_setparamelement $topNode [lindex $map 0] \
		[lrange $map 1 end] $what
	}
    } else {
	if {$when} {
	    tcl_settimepointelement [lindex $map 0] [lrange $map 1 end] $what
	} else {
	    tcl_setparamelement [lindex $map 0] [lrange $map 1 end] $what
	}
    }
}

proc MarkEvtParamActive {topNode node inC} {
    if {$inC} {
	c_markevtparamactive $topNode $node
    } else {
	set ::setFromSeries($topNode,$node,active) 2
    }
}

proc SetWrapTime {topNode inC where args} {
    global paramData
    if {$inC} {
	eval c_setwraparoundtime $topNode $where $args
    } else {
	eval set paramData(wrapAroundPoint,$where) $args
    }
}

# this one takes numerical for c and textual for tcl
proc SetFillMethod {topNode inC where {what {}}} {
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
	lindex $fillMtds [eval c_setfillmethod $topNode $where $which]
    } else {
	eval set paramData(fillMethod,$where) [string toupper $what]
    }
}

proc SetInterval {topNode inC where {what {}} {howLong {}}} {
    global paramData

    if {[string length $what]} {
	set paramData(uftsi,$where) $what
	if {$inC} {
	    eval c_setinterval $topNode $where $howLong
	} else {
	    set paramData(timePointInterval,$where) $howLong
	}
    } else {
	return $paramData(uftsi,$where)
    }
}

#proc FPError {occurrence inds errorData} {
#    if {![llength]} {
#	error aborted ;# quick way out
#    }
#    set query [concat param_load_fail $errorData [list $where $occurrence]]
#    if {[string equal abort [ExecQuery $query warning spf {} abort]]} {
#	error aborted
#    } else {
#	return {} ;# in hope ListParamArray will return same
#    }
#}

proc NumberToEnumType {idx trans} {
    if {[llength $trans]} {
        return [lindex $trans $idx]
    } else {
        return $idx
    }
}

proc c_setparamarray {topNode tgtNode} {
    global instance_id param_id

    set param_id($tgtNode) [c_createparamarray $instance_id $tgtNode]
}

# Old versions of these (identifying parameters by target node id) are passed
# to the exec thread. These calls now also have the top node to identify the
# right exec thread, so strip it off here
foreach oldCProc {setparamelement settimepointelement settimepointarray \
		      cleartimeseries setwraparoundtime setfillmethod \
		      setinterval \
		      setrecordlist settimepointrecords markevtparamactive \
		      setparamall getparamall settimepointall gettimepointall} {
    proc c_$oldCProc {args} {
	global param_id
	set cmd [info level 0]
	
	return [eval [list new[lindex $cmd 0] $param_id([lindex $cmd 2])] \
		    [lrange $cmd 3 end]] ;# elt 1 (2nd) is top node
    }
}

#proc c_setparamelement {tgtNode args} {
#    global param_id
#
#    return [eval [list newc_setparamelement $param_id($tgtNode)] $args]
#}
#
#proc c_settimepointelement {tgtNode args} {
#    global param_id
#
#    return [eval [list newc_settimepointelement $param_id($tgtNode)] $args]
#}
#
# this could be more efficient
proc ExScrubRun {node times} {
    global runState model_id instance_id
    #    if {![string match ok [ShowMess debug info Scrubbing okcancel]]} {
    #	error Bombed
    #    }
    if {$times && [info exists runState($node,currentTime)]} {
        unset runState($node,currentTime)
    }
    if {[info exists runState($node,cnvs)]} {
	$runState($node,cnvs) itemconfigure 1 -fill [RestingColour $node]
    }
    if {[info exists model_id]} {
        if {[string bytelength $model_id]} {
            if {[info exists instance_id]} {
                #ShowMess debug info "Exiting $model_id $instance_id" ok
                c_exitmodel $model_id $instance_id
                unset instance_id
            } else {
                #ShowMess debug info "Exiting $model_id 0" ok
                c_exitmodel $model_id \u00\u00\u00\u00\u00\u00\u00\u00
            }
        } else {
            if {[info exists instance_id]} {
                #ShowMess debug info "Exiting $model_id $instance_id" ok
		namespace delete ::AME_model<>
		array unset ::nodedata
                unset instance_id
	    }
        }
        unset model_id
    }
}

