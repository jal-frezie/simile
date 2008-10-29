# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

set auto_path [list [file join $env(SP_PATH) lib] \
		   [file join $env(SP_PATH) lib tcl[info tclversion]]]
package require Trf ;# loads right version of Trf (fingers crossed)

source [file join [file dirname $env(SP_PATH)] Run support.tcl]

proc load_c_stub_1 {{callerId {}}} {
    global env tcl_platform masterId

    set masterId $callerId
    scan [info tclversion] {%d.%d} MAJ MIN
    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN}.$env(SIMILE_VERSION).$onUnix
    if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
	error "Could not find a stub for Simile $env(SIMILE_VERSION) and TclTk ${MAJ}.${MIN} under $tcl_platform(platform) -- $dummy"
    }
}

proc load_c_stub_2 {} {
    global env

    loadcommands
    randseed [clock scan now]
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
	set funs [file join [file dirname $env(SP_PATH)] Functions *.tcl]
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
	set progFile $progDir/model${id}[info sharedlibextension]
	if {![file exists $progFile]} {
	    return 0
	}
        if {[catch {loadmodel $progFile $node} new_model_id]} {
	    if {[PrefValue custom(hackBreak) hackBreak]} {
		ShowMessage {Loading model dll} info "Failed to load the compiled model program. The operating system returned the following message: $new_model_id -- the program will attempt to build another one." ok
	    }
            return 0
        }
	set model_id($topNode) $new_model_id
        #        set model_id [loadmodel $nameBase[info sharedlibextension] $node]
        set model_ids($node) $new_model_id
        return $new_model_id
    }
}

proc update_executable {node lang} {
    #    ShowMessage debug info "References are $finderList" ok
    global model_id instance_id

    # For the toplevel model, make an instance. This will also make
    # instances of any fixed-membership submodels immediately, so they had
    # better already be loaded
    switch $lang {
	c {
	    set instance_id($node) [c_createmodel \
					$model_id($node)]
	} tcl {
    #    ShowMessage debug info "model instance $instance_id created" ok
	    set model_id($node) 0
	    set instance_id($node) 0
	}
    }
}

proc ExecuteTo {node current pause unitLength display foci intMethod maxErr} {
    global adapt dispDone actDone

    set dispDone 0
    set actDone 0 ;# nothing so far
    set forward [expr {$pause>$current}]
    set scaled_current [expr {$current*$unitLength}]
    set adapt(doublings) 0 ;# only relevant for tcl
    if {$display} {
	set lastDisp [expr int($current/$display)]
    }
    set currentMode start
    set payload {}
    while {[lsearch {exit stop} $currentMode]==-1} {
	if {$display} {
	    set nextDisp [expr 1.0*$display*[incr lastDisp \
						 [expr $forward*2-1]]]
	} else {
	    set nextDisp [expr 2*$pause-$current]
	}
	set current $nextDisp ;# INCREMENT IS HERE
	if {($current>$pause) == $forward} {
	    set current $pause
	}
	set scaled_next [expr {$current*$unitLength}]
	set howAndWhen [ExecuteModel $node $intMethod \
			    $scaled_current $scaled_next $maxErr]
	set current [lindex $howAndWhen 1]
	switch -- [lindex $howAndWhen 0] {
	    -1 {
		set currentMode exit
	    } 0 {
		set currentMode stop
	    }
	} ;# default: keep going
#	if {![info exists runState($node,cnvs)]} {
#	    return $currentMode ;# run control window killed?
#	}
	if {$current==$nextDisp && ![string equal exit $currentMode]} {
	    set oldPayload $payload
	    set payload {}
	    foreach point $foci {
		lappend payload $point
		if {[RunningInC $node]} {
		    # redundant fields make list of unique length
		    lappend payload [list ptr 0 [GetHandle $node $point]]
		} else {
		    lappend payload [lindex [tcl_insert $point {}] 0]
		}
	    }
	    if {[ShiftDisplays $node $payload $current $display]} {
		set currentMode stop
	    }

#	    if {![TellAllHelpers $node $payload Display $current $display 1]} {
#		set currentMode stop
#	    }
	    # now it is done, previous one must have finished, if any
	    FreeAll $oldPayload
	}
	set scaled_current $scaled_next
	if {$current==$pause} {
	    set currentMode stop
	}
    }
    waitForDisps
#    InteractGUI $instanceId $scaled_next 1 ;# must do it at end
    FreeAll $payload
    return $currentMode
}

proc GetHandle {node point} {
    global model_id instance_id
    return [handle_data $model_id($node) $instance_id($node) $point]
}

proc FreeAll {load} {
    foreach {id hdl} $load {
	if {[llength $hdl]==3} {
	    free_data_handle [lindex $hdl 2]
	}
    }
}

proc ResetModel {myNode redo} {
    global model_id instance_id
    if {[catch {
	if {$model_id($myNode)} {
#	    set model_id(running) $myNode
	    c_resetmodel $model_id($myNode) $instance_id($myNode) $redo
	} else {
	    TclResetModel $redo
	}
    } errList]} {
	ExplainError $errList
	set done 0
    } else {
	set done 1
    }
#    set ::userAction 1
#    InteractGUI $instance_id 0 2 ;# put somewhere else?
    return $done
}

proc ExecuteModel {myNode howInt start finish errLim} {
    global model_id instance_id
    if {[catch {
	if {$model_id($myNode)} {
	    set model_id(running) $myNode
	    c_executemodel $model_id($myNode) $instance_id($myNode) \
		[expr ![string equal Euler $howInt]] $start $finish $errLim
	} else {
	    TclExecuteModel $myNode $howInt $start $finish $errLim
	}
    } errList]} {
	InteractGUI $myNode [lindex $errList 3] 2
	return [ExplainError $errList]
# This will also need to raise an exception so we can retrieve stop time etc
#    } elseif {$errList==-1} {
#        start_in_editor BuildProblem "Execution notice" info "Model execution has been paused at a discontinuity which could not be dealt with by adaptive step size control." execution
#        do_in_editor RaiseModelWindow $myNode
#        return 0
    } else {
	return $errList
    }
}

proc waitForDisps {} {
    global dispDone
    if {![info exists dispDone]} {
	vwait dispDone
    }
}

proc OuteractGUI {id time mode} {
    return [InteractGUI [DecodeInstance $id] $time $mode]
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

if {![info exists runHow]} { ;# we are in separate interp
    proc PullAction {inst} {
	if {[tsv::exists action $inst]} {
	    tsv::unset action $inst
	    return 1
	} 
	return 0
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
}
# placeholder
proc ExplainError {errList} {
    global errorInfo
    error $errList $errorInfo
}

proc RunningInC {myNode} {
    global model_id
    return $model_id($myNode) ;# it is ready
} 
    
proc GetCCompProperty {topNode prop args} {
    global model_id instance_id
    set node [lindex $args 0]
    set set [lrange $args 1 end]
    # first do cases that don't need any other data
    set numberWangs Caption|MinVal|MaxVal|Trans|Spec|Desc|Comment
    switch -regexp $prop [list \
	Objects {
	    return [lrange [listobjects \
				$model_id($topNode)] 1 end]
	} SetStep { ;# node is actually time
	    return [c_setstepmodel $model_id($topNode) $node $set]
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
	} $numberWangs {
	    set dataWang [lindex {5 6 8 12 13 14 15} \
			      [lsearch [split $numberWangs |] $prop]]
	    return [c_getvalue $topNode $node $dataWang]
	} IdFromCapt {
	    # node is actually caption in this case
	    if {[catch {getnodeid $model_id($topNode) $node} id]} {
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
    set res [getvalue $model_id($topNode) $node $action]
    return $res
}
	    
#proc getinfo {topNode node field} {
#    getinfo $node $field
#}

# this could be more efficient

proc ExScrubRun {node times} {
    global runState model_id instance_id
    #    if {![string match ok [ShowMessage debug info Scrubbing okcancel]]} {
    #	error Bombed
    #    }
    set runState($node,modelRunning) 0
    if {$times && [info exists runState($node,currentTime)]} {
        unset runState($node,currentTime)
    }
    if {[info exists runState($node,cnvs)]} {
	$runState($node,cnvs) itemconfigure 1 -fill [RestingColour $node]
    }
    if {[info exists model_id($node)]} {
        if {$model_id($node)} {
            if {[info exists instance_id($node)]} {
                #ShowMessage debug info "Exiting $model_id($node) $instance_id($node)" ok
                c_exitmodel $model_id($node) \
		    $instance_id($node)
                unset instance_id($node)
            } else {
                #ShowMessage debug info "Exiting $model_id 0" ok
                c_exitmodel $model_id($node) 0
            }
        } else {
            if {[info exists instance_id($node)]} {
                #ShowMessage debug info "Exiting $model_id $instance_id" ok
		namespace delete ::AME_model<>
		array unset nodedata
                unset instance_id($node)
	    }
        }
        unset model_id($node)
    }

}

