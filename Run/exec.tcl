# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

# earlier versions tried to reproduce the master's auto_path minus the
# Tk-specific bits, but much easier just to pass it -- the Tk bits do
# no harm

source [file join [file dirname $env(SYSDIR)] Run support.tcl]

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
	    source $fnFile
	}
	foreach fnFile $incs {
	    source $fnFile
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
		    intMethod maxErr evtMsg evtDisp} {
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
			    $scaled_next $maxErr $evtPause]
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

proc ExecuteModel {myNode howInt start finish errLim evtPause} {
    global model_id instance_id
    if {[catch {
	if {[string bytelength $model_id]} {
#	    set model_id $myNode
	    c_executemodel $model_id $instance_id \
		[expr ![string equal Euler $howInt]] \
		$start $finish $errLim $evtPause
	} else {
	    TclExecuteModel $myNode $howInt $start $finish $errLim $evtPause
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
			    {EXOGENOUS DERIVED TABLE INPUT \
				 SPLIT GHOST LIMIT RECALL}]
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

