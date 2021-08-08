# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

# earlier versions tried to reproduce the master's auto_path minus the
# Tk-specific bits, but much easier just to pass it -- the Tk bits do
# no harm

# Do not include tcl support -- debug not needed in client5d, R or SimiLive
# source [file join [file dirname $env(SYSDIR)] Run support.tcl]

proc load_c_stub_1 {node ap xd} {
    if {$::tcl_platform(platform) eq "windows"} {
	cd $xd ;# prevents spurious error message finding 5d.dll on Win7/XP
    }
    set ::auto_path $ap
    scan [info tclversion] {%d.%d} MAJ MIN
    package require -exact Ame_dll $::env(SIMILE_VERSION)
    SeedRandoms $node [clock seconds]
    # above was previously [clock scan now] but this had the disadvantage that
    # it immediately loaded a whole lot of on-demand parsing packages into the 
    # exec thread which aren't used anywhere else and sometimes cannot be found
}

proc SeedRandoms {node val} {
    randseed $val
}

proc loadmodel {exec ident} {
    global captionCache

    set modelId [loadshlib $exec $ident]
    array unset captionCache $modelId,*
    foreach itemId [listobjects $modelId] {
	set captionCache($modelId,[getvalue $modelId $itemId 5]) $itemId
    }
    return $modelId
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
#	source $model_prog($topNode)
# File is utf-8 so rather than sourcing, read in and eval
	set stm [open $model_prog($topNode) r]
	fconfigure $stm -encoding utf-8
	set modelCode [read $stm] ;# read first to make sure we close
	close $stm
	eval $modelCode

	if {![catch {IdentField $simile_identifier version} buildV]} {
	    return [expr $buildV==$env(SIMILE_VERSION)]
        } else {
            return 1 ;# works if no IdentField in interp
        }
    } else {
	set progFile [file join $progDir model${id}[info sharedlibextension]]
	if {![file exists $progFile]} {
	    puts "Shared library $progFile appears not to exist!"
	    return 0
}
# Some APIs are determined to do what they think we really want rather than
# what we actually ask for. So rename the shared library before reloading it,
# otherwise we may get an earlier version back.
        set OSBaffler [file join [file dirname $progFile] bamf[random01]]
        file rename $progFile $OSBaffler
        set new_model_id [loadmodel $OSBaffler $node]
        file rename $OSBaffler $progFile

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
    global model_id instance_id

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

proc InsertExptlCase {node caseId} {
    global instance_id exptl_case

    return [set exptl_case($caseId) [c_addmodeltogroup $instance_id]]
}

proc DeleteExptlCase {node caseId} {
    global exptl_case

    c_deletemodel $exptl_case($caseId)
    unset exptl_case($caseId)
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
    set evtPause [expr {$evtMsg || $evtDisp}] ;# event sounds selected
    set ptClasses {}
    set payload {}
    foreach point $foci {
	lappend ptClasses [GetCompProperty dummy Class $point]
    }
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
	if {$scaled_next == $scaled_current} {
	    ResetModel $node 0 $scaled_current 1
	    set howAndWhen 0
	} else {
	    set howAndWhen [ExecuteModel $node $intMethod $scaled_current \
				$scaled_next $maxErr $lmtPause $evtPause]
	    set scaled_current [lindex $howAndWhen 1]
	}
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
		# do sounds
		# foreach {evt sound} [array get ::eventSounds] {
		#     set hdl [GetHandle $node $evt]
		#     set evtVals [extract_list $hdl 16777216]
		#     ReleaseHandle $node $hdl
		#     if {[SumVals $evtVals]} {
		# 	exec aplay $sound &
		#     }
		# }
		set scaled_current [lindex $scaled_current 3]
	    }
	} ;# default: keep going
	set current [expr {$scaled_current/$unitLength}]
	set timedDisp [expr {($current-$nextDisp)*$forward > -1e-12}]
	if {($current-$pause)*$forward > -1e-12} {
	    set currentMode stop
	}
	if {![string equal exit $currentMode]} { ;# do a display update
	    set oldPayload $payload
	    set payload {}
	    foreach point $foci class $ptClasses {
		if {[catch {GetPayload $node $point $class} dataHand]} {
# data has gone, so hope it is no longer needed
		} else {
		    lappend payload $point $dataHand
		}
	    }
#	    if {[ShiftDisplays $::nodeId $payload [format %.8g $current] \
#		     $display [expr {$timedDisp || $displayNow}]]} {
#		set currentMode stop
	    #	    }
	    set shiftCmd [list ShiftDisplays $::nodeId $payload [format %.8g $current] \
			      $display [expr {$timedDisp || $displayNow}]]
	    if {$currentMode eq "start"} {
		after idle $shiftCmd
	    } else {
		eval $shiftCmd
	    }

#	    if {![TellAllHelpers $node $payload Display $current $display 1]} {
#		set currentMode stop
#	    }
	    # now it is done, previous one must have finished, if any
	    FreeAll $oldPayload
	}
    }
#    OuteractGUI $scaled_current 1
# above is required to leave right time in progress display if not finishing
# on display interval boundary
    waitForDisps
    FreeAll $payload
    return $currentMode
}

proc GetPayload {node point class} {
    if {[RunningInC $node]} {
	return [list ptr $class [GetHandle $node $point]]
# redundant fields make list of unique length
    } else {
	return [lindex [tcl_insert $point {}] 0]
    }
}

proc ListCases {node} {
    return [array get ::exptl_case]
}
    
proc GetHandle {node point} {
    global model_id instance_id
    set result [handle_data $model_id $instance_id $point]
    set expts [ListCases $node]
    if {[llength $expts]} {
	set result [list default $result]
	foreach {caseId hdl} $expts {
	    lappend result $caseId [handle_data $model_id $hdl $point]
	}
    }
    return $result
}
  
proc ReleaseHandle {node handle} {
    if {[llength $handle]==1} {
	set handle [list default $handle]
    }
    foreach {case sub} $handle {
	free_data_handle $sub
    }
}

proc FreeAll {load} {
    foreach {id hdl} $load {
	if {[llength $hdl]==3} {
	    ReleaseHandle dummy [lindex $hdl 2]
	}
    }
}

proc CResetModel {initTime args} {
    global model_id instance_id modelStopped
    eval [list c_resetmodel $model_id $instance_id] $initTime $args
    after idle WatchModel 0 $initTime

    vwait modelStopped
    if {[llength $modelStopped]>2} { # error -- re-throw
	error $modelStopped
    }
    return $::modelStopped
}

proc ResetModel {myNode howInt initTime redo} {
    set preserveSliders [expr {$howInt-1}] ;# -1 selects new slider rollover
    if {[catch {
	if {[RunningInC $myNode]} {
#	    set model_id $myNode
	    CResetModel $initTime $preserveSliders $redo
	} else {
	    TclResetModel $myNode $initTime $preserveSliders $redo
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
    InteractGUI $myNode $initTime 0 ;# put somewhere else?
    return $done
}

proc RepeatReset {myNode time} {
    global model_id instance_id
    if {[string bytelength $model_id]} {
#	    set model_id $myNode
	c_repeatreset $model_id $instance_id $time
    } else {
	ResetTimeSeries $myNode
    }
}

proc WatchModel {gui end} {
    global model_id instance_id
    # should work for any model operation
    if {![catch {c_checkmodel $model_id $instance_id $gui} status]} {
	# puts "Send $gui recv \"$status\""
	if {$status eq ""} { # has run to end
	    set status [list [expr {1-($gui==2)}] $end]
	}
	set gui [OuteractGUI [lindex $status 1] [lindex $status 0]]
	set going [expr {[lindex $status 0]==2}]
	if {$going} {
	    after 1 WatchModel $gui $end
	    return
	}
    } else { puts $::errorInfo }
    if {[lindex $status 0]==1 && $gui==2} { # model step done but paused
	lset status 0 0
    }
    set ::modelStopped $status
}

proc CExecuteModel {isRK start finish args} {
    global model_id instance_id modelStopped
    eval [list c_executemodel $model_id $instance_id $isRK $start $finish] $args
    after idle WatchModel 0 $finish

    vwait modelStopped
    if {[llength $modelStopped]>2} { # error -- re-throw
	error $modelStopped
    }
    return $::modelStopped
}

proc ExecuteModel {myNode howInt start finish errLim lmtPause evtPause} {
    if {[catch {
	if {[RunningInC $myNode]} {
#	    set model_id $myNode
	    CExecuteModel [expr ![string equal Euler $howInt]] \
		$start $finish $errLim $lmtPause $evtPause
	} else {
	    TclExecuteModel $myNode $howInt $start $finish $errLim \
		$lmtPause $evtPause
	}
    } errList]} {
	if {[string match tcl_model_err* $errList]} {
	    set severity [ExplainError $myNode [lrange $errList 1 end] \
			  $::errorInfo]
	} else {
	    error "Unexpected problem in Tcl model execution" $::errorInfo
	}
    } elseif {[lindex $errList 0]>-1} { ;# requires no message
	return $errList
    } elseif {[lindex $errList 5] eq "event"} {
	return [list 2 $errList]
    } else {
	set severity [ExplainError $myNode [lrange $errList 1 end] unused]
    }
    OuteractGUI [lindex $errList 3] 2
    return [list $severity [lindex $errList 3]]
}

proc waitForDisps {} {
    global dispDone
    if {![info exists dispDone]} {
	vwait dispDone
    }
}

proc OuteractGUI {time mode} {
    global nodeId

    return [InteractGUI $nodeId $time $mode]
}

proc InMaster {cmd result} {
    thread::send -async $::masterId [lreplace $cmd 1 1 $::nodeId] $result
}

if {[info exists masterId]} { ;# we are in separate interp
    proc PullAction {inst} {
	return [tsv::get action $inst]
    }

    proc AbortCheck {nodeId args} {
	InMaster [info level 0] dummy
	return [PullAction $nodeId]
    }
 
    proc InteractGUI {nodeId args} {
	if {![info exists ::dispDone]} { ;# GUI is busy
	    update ;# in case GUI waiting for this thread
	    return 0
	}

	InMaster [info level 0] dummy
	return [PullAction $nodeId]
    }
 
    proc AddLogEntry {nodeId args} {
	InMaster [info level 0] dummy
    }
 
# This one needs to wait till previous call finished    
    proc ShiftDisplays {nodeId args} {
	global dispDone
	waitForDisps
	if {$dispDone} { ;# helper has stuffed up
	    return 1
	} else {
	    unset dispDone
	    InMaster [info level 0] dispDone
	    return [PullAction $nodeId]
	}
    }
# these are straight copies
    foreach straight {ExecQuery TransEnums} { ;# InDays not needed
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

proc getnodeid {modelId capt} {
    return $::captionCache($modelId,$capt)
}

proc GetCCompProperty {prop args} {
    global model_id instance_id
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    set numberWangs Caption|MinVal|MaxVal|Trans|Spec|Units|Comment|Base
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
	    set numericVal [c_getvalue $node $propData($prop,cIdx)]
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
	    set fullList [c_getvalue $node 0]
	    
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
	    set gphId [c_getvalue $node 17]
	    if {[llength $set]} {
		eval {graph_table $instance_id 22 $gphId} $set
	    } else {
		return [graph_table $instance_id 21 $gphId]
	    }
	} $numberWangs {
	    set dataWang [lindex {5 6 8 12 13 14 15 16} \
			      [lsearch [split $numberWangs |] $prop]]
	    return [c_getvalue $node $dataWang]
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
proc c_getvalue {node action} {
    global model_id
    set res [getvalue $model_id $node $action]
    return $res
}
	    
#proc getinfo {topNode node field} {
#    getinfo $node $field
#}

proc ListToArray {dummy caseId tgt subs numSubs trans dims list when \
		      useCppArray} {
    # skip over any vm arrays, their indices will not appear
    # in calls for values, but keep the translation list in sync
    # ... string match stops cleanly at end of list
#    global comboTypes
    
    if {[string equal ,bytes [lindex $list 1]]} {
	if {$useCppArray} {
	    if {$when} {
		c_settimepointall $caseId $tgt [lindex $list end]
		SetInterval dummy $caseId $useCppArray $tgt \
		    [lindex $list end-3]*day [lindex $list end-3]
		SetWrapTime $caseId $useCppArray $tgt [lindex $list end-2]
		SetFillMethod $caseId $useCppArray $tgt [lindex $list end-1]
	    } else {
		c_setparamall $caseId $tgt [lindex $list end] \
		    [lrange $list 3 end-3]
	    }
	    return -1 ;# do nothing more, the data has now been loaded to c
	} else {
	    # DO THE fallback thing (inefficient placeholder version)
	    if {[string equal REAL [lindex $list 2]]} {
		set fieldChar d
		set fieldSize 8
	    } elseif {[string equal FLAG [lindex $list 2]]} {
		set fieldChar c
		set fieldSize 1
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
	    DoNotPassTcl $caseId $tgt $dims $list
	    return -1 ;# typical fixed parameter
	} else {
	    set list [concat [NumberElements [ReadGdalRefToList $list \
						  [lindex $dims 0] \
						  [lindex $dims 1]] \
				  [expr {!$when}]] [lrange $list 8 end]]
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
		if {[catch {EnumTypeToNumber $caseId $idAndSubs $list \
				$thisTrans 0 $useCppArray} woops]} {
		    return [AddErrorTo {} $woops $subs]
		} else {
		    return 1
		}
	    } else {
		# setting value for fixed param or time point
		if {[catch {EnumTypeToNumber $caseId $tgt$numSubs $list \
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
        EnumTypeToNumber $caseId $tgt {} {} 1 $useCppArray
	SetWrapTime $caseId $useCppArray $tgt 0 ;# clear old wraparound point
# do not allow OTHERS if an event series

	set tgtEval [GetCompProperty dummy Eval $tgt]
	set tgtClass [GetCompProperty dummy Class $tgt]

	if {[string equal DERIVED $tgtEval]} {
	    set specialPts {} ;# loading measurements for PEST
	} elseif {[string equal EVENT $tgtClass]} {
	    set specialPts [list NOW INTERVAL]
	} else {
	    set specialPts [list NOW INTERVAL OTHERS]
	    SetFillMethod $caseId $useCppArray $tgt use_last ;# and fill method
	}
	SetInterval dummy $caseId $useCppArray $tgt unit 1
    
        foreach {indx subList} $list {
	    set nextSubs $subs,[list $indx]
            if {[set pt [lsearch $specialPts [string toupper $indx]]]>-1} {
# Following never happens, TIME is always outermost dimension
#		if {[llength $subs]} {
#		    FPError [format [tr. {"%1$s" must be outermost index.}] \
#					 $indx] $subs $errorData
#		}
		if {!$pt && $tgtClass eq "EVENT"} {
		    # NOW: mark param active so it clears after event
		    MarkEvtParamActive $caseId $tgt $useCppArray 1
		}
            } elseif {![string is double -strict $indx]} {
                set redoStep [AddErrorTo $redoStep \
				  [list bad_time_point_index $specialPts] \
				  $nextSubs]
            } elseif {[string equal RESTART [string toupper $subList]]} {
		SetWrapTime $caseId $useCppArray $tgt $indx
		continue
	    } elseif {$useCppArray} {
# If there are values other than NOW, do an init step
                c_settimepointarray $caseId $tgt $indx
            }
	    if {[string equal DEFAULT [string toupper $subList]]} {
# Values return to default as before first time point -- index -1 clears data
		EnumTypeToNumber $caseId $tgt,$indx,-1 0 {} 1 $useCppArray
		continue
	    }
# check for fill method if one might be appropriate
	    if {[lsearch $specialPts OTHERS]>-1} {
		set noMtd [catch {SetFillMethod $caseId $useCppArray $tgt \
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
	    if {[string is double -strict $subList]} {
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
			      [ListToArray dummy $caseId $tgt $subs,$indx \
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
		c_settimepointrecords $caseId $tgt [lrange $map 2 end] \
		    [lindex $map 1] $last
		# if {[catch {c_settimepointrecords $tgt [lrange $map 2 end] \
		# 		[lindex $map 1] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    } else {
		c_setrecordlist $caseId $tgt \
		    [lrange [split $numSubs ,] 1 end] $last
		# if {[catch {c_setrecordlist $tgt [lrange [split $subs ,] \
		# 				      1 end] $last} err]} {
		#     FPError $err $subs $errorData
		#     set redoStep {}
		# } 
	    }
	} else { ;# use old system for Tcl
	    set recordNode [lindex $nextDim 1]
	    EnumTypeToNumber $caseId $recordNode$numSubs $last {} $when \
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
			      [ListToArray dummy $caseId $tgt $subs,$indx \
				   $numSubs,$arrayPt \
				   [lrange $trans 1 end] [lrange $dims 1 end] \
				   $sub($indx) $when $useCppArray]]
	}
    }
    return $redoStep
}

proc DoNotPassTcl {caseId node dims tableSpec} {
#puts "dims $dims spec $tableSpec"
    if {[string equal REAL [GetCCompProperty Type $node]]} {
	set gdalType GDT_Float64
    } else {
	set gdalType GDT_Int32
    }

    package require gdal
    set hg [gdal_open_read_only [lindex $tableSpec 0]]
    set hdl [gdal_get_raster_band $hg [lindex $tableSpec 6]]
    set dataRows [expr 1+[lindex $tableSpec 3]-[lindex $tableSpec 2]]
    set dataCols [expr 1+[lindex $tableSpec 5]-[lindex $tableSpec 4]]
    set fillRows [lindex $dims 0]
    set fillCols [lindex $dims 1]
    set bytesFromGdal [gdal_get_raster_data $hdl \
		     [expr [lindex $tableSpec 4]-1] \
		     [expr [lindex $tableSpec 2]-1] \
		     $dataCols $dataRows $gdalType $fillCols $fillRows]
    gdal_close $hg
    
    c_setparamall $caseId $node $bytesFromGdal [list $fillRows $fillCols]
}

# duplicate of procedure in utility.tcl
proc DoByteArrayToList {fieldChar fieldSize bounds rawData} {
    upvar 1 offset offset
    if {[llength $bounds]==1} {
	set fieldSpec @${offset}${fieldChar}${bounds}
#puts $fieldSpec
	if {![binary scan $rawData $fieldSpec spit]} {
	    set spit {<scan failed>}
	    puts "Failed to scan $rawData for $fieldSpec"
	}
	incr offset [expr $fieldSize*$bounds]
    } else {
	set subBounds [lrange $bounds 1 end]
	set spit {}
	for {set outer 0} {$outer<[lindex $bounds 0]} {incr outer} {
	    lappend spit [DoByteArrayToList $fieldChar $fieldSize \
			      $subBounds $rawData]
	}
    }
    return $spit
}

proc NumberElements {list {startNum 1}} {
    if {[string equal $list [lindex $list 0]]} {
	return $list
    } else {
	set result {}
	set num [incr startNum -1]
	foreach elt $list {
	    if {[llength $elt]} {
		lappend result [incr num] [NumberElements $elt 1]
	    }
	}
	return $result
    }
}

proc ReadGdalRefToList {tableSpec {y {}} {x {}}} {
    package require gdal
#puts "RGRTL $tableSpec $x $y"
    set hg [gdal_open_read_only [lindex $tableSpec 0]]
    set hdl [gdal_get_raster_band $hg [lindex $tableSpec 6]]
    set l [expr [lindex $tableSpec 4]-1]
    set t [expr [lindex $tableSpec 2]-1]
    set w [expr [lindex $tableSpec 5]-$l]
    set h [expr [lindex $tableSpec 3]-$t]
    if {![string is double -strict $x]} {
	set x $w
    }
    if {![string is double -strict $y]} {
	set y $h
    }
    set nValues [gdal_get_raster_values $hdl $l $t $w $h $x $y]    
    gdal_close $hg
    return $nValues
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

proc EnumTypeToNumber {caseId tgt head trans when useCppArray} {
    if {![llength $head]} {
        # empty head, signal to clear out old values
        if {$useCppArray} {
            c_cleartimeseries $caseId $tgt
        } else {
	    tcl_cleartimeseries $tgt
        }
    } else {
	set head [UntransVal $trans $head data]
	if {[llength $head]>1} {
	    error [list unwanted_param_array $head]
	} elseif {![string is double -strict $head]} {
	    error [list data_not_number $head]
	}
	PlaceInArray $caseId $tgt $head $when $useCppArray
    }
    #puts "just went set paramData($tgt) $paramData($tgt)"
}

########################### stuff for both languages below ###############
proc PlaceInArray {caseId where what when inC} {
    set map [split $where ,]
    if {$inC} {
	if {$when} {
	    c_settimepointelement $caseId [lindex $map 0] \
		[lrange $map 2 end] [lindex $map 1] $what
	} else {
	    c_setparamelement $caseId [lindex $map 0] \
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

proc MarkEvtParamActive {caseId node inC wait} {
# active was set to 2 because the param updater was called before the
#    model collected the parameter, but as of 6.7p1 anything that calls this
    #    also does an extra rate pass collecting it immediately so only need 1
    # (except while model executing!)
    if {$inC} {
	c_markevtparamactive $caseId $node $wait
    } else {
	set ::setFromSeries($node,active) $wait
    }
}

proc AddEventCommand {topNode node cmd} {
    add_event_command $::instance_id $node $cmd
    global eventSounds
    if {$cmd eq ""} {
	unset eventSounds($node)
    } else {
	set eventSounds($node) cmd	
    }
}

proc SetWrapTime {caseId inC where args} {
    global paramData
    if {$inC} {
	eval [list c_setwraparoundtime $caseId $where] $args
    } else {
	eval set paramData(wrapAroundPoint,$where) $args
    }
}

# this one takes numerical for c and textual for tcl
proc SetFillMethod {caseId inC where {what {}}} {
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
	lindex $fillMtds [eval [list c_setfillmethod $caseId $where] $which]
    } else {
	eval set paramData(fillMethod,$where) [string toupper $what]
    }
}

proc SetInterval {dummy caseId inC where {what {}} {howLong {}}} {
    global paramData

    if {[string length $what]} {
	set paramData(uftsi,$where) $what
	if {$inC} {
	    c_setinterval $caseId $where $howLong
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

proc c_setparamarray {topNode tgtNode caseId create} {
    global instance_id param_id exptl_case exptl_params

    if {$caseId ne {}} {
	set useInst $exptl_case($caseId)
	set keepPrm exptl_params($tgtNode,$caseId)
    } else {
	set useInst $instance_id
	set keepPrm param_id($tgtNode)
    }
    if {$create} {
	set $keepPrm [c_createparamarray $useInst $tgtNode]
    } elseif {[info exists $keepPrm]} {
	c_forgetparamarray [set $keepPrm]
	unset $keepPrm
    }
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
	global param_id exptl_params
	set cmd [info level 0]
	if {[lindex $cmd 1] ne {}} { ;# experiment case id
	    set usePrm $exptl_params([lindex $cmd 2],[lindex $cmd 1])
	} else {
	    set usePrm $param_id([lindex $cmd 2])
	}
	return [eval [list new[lindex $cmd 0] $usePrm] [lrange $cmd 3 end]]
		# elt 1 (2nd) is top node, not needed here
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
proc ParamsFromGUI {inst} {
    # not used as it causes a deadly embrace
    global instance_id

    set instance_id $inst
    thread::send -async $::masterId [list FileParamDialogue \
					 $::web_service(node) {} 0] params_done
    vwait params_done
    unset instance_id
    return $::params_done
}

proc StartWebService {node scratch {runParams {}}} {
    array set ::web_service [list local $scratch node $node]
    start_server localhost 7464 similive.simulistics.com $runParams
    switch $::tcl_platform(os) {
	Linux {
#	    exec xdg-open file://[file join $scratch load_tools.html]
	}
    }
}

# this could be more efficient
proc ExScrubRun {node times} {
    global model_id instance_id
    #    if {![string match ok [ShowMess debug info Scrubbing okcancel]]} {
    #	error Bombed
    #    }
    if {[info exists model_id]} {
        if {[string bytelength $model_id]} {
            if {[info exists instance_id]} {
                #ShowMess debug info "Exiting $model_id $instance_id" ok
                c_exitmodel $model_id $instance_id
		array unset ::param_id
		array unset ::exptl_case
                unset instance_id
            } else {
                #ShowMess debug info "Exiting $model_id 0" ok
                #c_exitmodel $model_id \u00\u00\u00\u00\u00\u00\u00\u00
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

proc ExplainError {myNode errList origError} {
    global introspect
    
    set severity -1
    set what [lindex $errList 0]
    set dest [lindex $errList 1]
    set mtime [lindex $errList 2]
    set mstep [lindex $errList 3]
    set whoopsie [lindex $errList 4]
    switch $what {
	evalmodel {set operation "calculating the value of"}
	updatemodel {set operation "updating the state"}
	resetmodel {set operation "resetting"}
	default {set operation "doing $what for"}
    }
#	advancemodel {set operation "advancing the time point for"}
    set target something
    if {[string is integer -strict $dest]} { ;# graph id (tcl only for now)
	foreach {n record} [array get ::nodedata] {
	    if {[lindex $record 9]==$dest} {
		set target "[GetFullCaption $record] (node [lindex $record 0])"
		break;
	    }
	}
	if {[llength $introspect]} {
	    append target " at indices [join $introspect ,]"
	}
    } elseif {[string first :: $dest]>-1} { ;# a Tcl namespace hierarchy
	set targetList [DescribeComponent $myNode $dest]
	if {![namespace exists [join [lrange [split $dest :] 0 end-2] :]]} {
	    set whoopsie dest_missing
# Just remind me, when does this happen? 
# Probably never, due to base index range checking
	}
	set target [lindex $targetList 0]
    } elseif {![string equal none $dest]} { ;# caption extracted by c++ error handling
	if {[llength $dest] == 1} {
	    set target $dest
	} else {
	    set target \
		"[lindex $dest 0] at indices [join [lrange $dest 1 end] ,]"
	}
    }

    switch -glob -- $whoopsie {
	"can't read \"*\": no such element in array" - 
	"can't read \"*\": no such variable" {
	    set ref [lindex [split $whoopsie \"] 1]
	    set sourceList [DescribeComponent $myNode $ref] 
	    if {![namespace exists [join [lrange [split $ref :] 0 end-2] :]]} {
		set problem "it found that there was no submodel instance when trying to get [lindex $sourceList 0]"
	    } else {
		set problem "it found that there was no value for [lindex $sourceList 0]"
	    }
	} dest_missing {
	    set problem "it found there was no instance with these indices. This may mean that you have specified a base model instance by an index which is out of range"
	} "User-defined interruption code *" {
	    set code [lindex $whoopsie end]
	    set problem "there was a user-defined interruption: $code"
	    set severity 0
	} "abort request from the user" {
	    set problem "the user chose to abort a long operation"
	    set severity 0
	} discontinuity {
	    set problem "there was a discontinuity which could not be dealt with by adaptive step size control"
	    set severity 0
	} event {
	    set problem "there was a limit event, producing a pause"
	    set severity 0
	} min {
	    set problem "the compartment value went below its minimum"
	    set severity 0
	} max {
	    set problem "the compartment value went above its maximum"
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
	    set problem "there was a $whoopsie"
	}
    }
    
    switch -- $mstep {
	-2 {
	    set action initialization
	    set timing {}
	    #		ScrubRun $node 0
	} -1 {
	    set action parameterization
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
	    set specifics [list model_crash $operation $target $action $timing \
		       $problem $origError]
	    set icon warning
	} 0 {
	    set specifics [list model_pause $operation $target $action $timing \
		       $problem]
	    set icon info
	}
    }
    AddLogEntry $::nodeId $specifics
    ExecQuery $specifics $icon top {} ok
    # do it after idle so this process is not hung till user responds
#    RaiseModelWindow $myNode
    return $severity
}

proc tcl_insert {node newVs} {
    global nodedata

    set line [FindRecord $node]
    if {[llength $line]} {
	set tree [lindex $line 8]
	set type [lindex $line 1]
	set dims [GetTclCompProperty Dims $node]
	return [list [FillValue ::AME_model<> $tree $type $dims {} 0 $newVs]]
    }
    return novalue
}

proc DescribeComponent {topNode ref} {
    set hierarchy [split $ref :] ;# joins actually :: so every other elt null
    set inds {} ;# inds no longer needed, kept as spare part
    set context [MakeContext $topNode [lrange $hierarchy 0 end-2]]
    set variable [lindex $hierarchy end]
    set br [string first \( $variable]
    if {$br == -1} {
	set captPath [NewCaptionIfAvail $topNode $hierarchy 1 $variable]
	set vdesc "variable [lindex $captPath 0]"
    } else {
	set locals [split [string range $variable [incr br 1] end-1] ,]
	eval {lappend inds} $locals
	set captPath [NewCaptionIfAvail $topNode $hierarchy \
			  [concat $locals [list 1]] \
			  [string range $variable 0 [incr br -2]]]
	set vdesc "element [join [lrange $captPath 1 end-1] ,] of variable [lindex $captPath 0]"
    }
# next turn last arg into node
    return [list $vdesc$context $inds]
}
