if {[string equal windows $::tcl_platform(platform)]} {
    package require dde
    dde servername Simile
}

oo::class create similescript::ModelWindow {
    variable modelNode modelCanvas model

    constructor {} {
	set fromProlog [MakeNodeInProlog [self object]]
        #tk_messageBox -message "ModelWin constructor"
	set modelNode [lindex $fromProlog 0]
	set modelCanvas [lindex $fromProlog 1]
	set ::window_info($modelCanvas,top_node) $modelNode ;# in case headless
#        Hide ;# default is to show
#        UseMRE false
# can't have creation of model windows overwriting users' preferences!!
    }
    
    destructor {
        if {![string match "" [itcl::find object similescript::RunControl]]} {
            delete object similescript::RunControl
        }
        #tk_messageBox -message "model win destructor"
        #Exit
#        MenuClose $modelCanvas
# following replaces above...
	KillNodeInProlog $modelCanvas
    }

    method getNode {} {
	return $modelNode
    }
    
    method getModelCanvas {} {
        global window_info
	return $modelCanvas
    }
    
#    method getModelWindow {} {
#        global window_info
#	return $window_info([getModelCanvas],parent)
#    }
#    
#    method Hide {} {
#        wm withdraw [getModelWindow]
#    }
#    
#    method Show {} {
#        wm deiconify [getModelWindow]
#    }
#    
#    # File Menu
#    method New {} {
#        MenuSelect $modelCanvas file new
#        if {[info exists model]} {
#            unset model
#        }
#    }
#    
#    method FileOpenDlg {} {
#        #if {[info exists model]} {
#        #    $this FileNew"
#        #}
#        #$c local open_all
#        MenuSelect $modelCanvas local open_all
#        #set model $modelFile
#    }
#    
#    method Open {modelFile} {
#        if {[info exists model]} {
#            $this New
#        }
#        Reopen $modelCanvas $modelFile reopen
#        set model $modelFile
#    }
## disable -- there is little point printing from script as you cannot alter 
## diagram
##    method Print {} {
##        MenuSelect PrintNow $modelCanvas
##    }
##    
#    method ListEnumTypes {} {
#	GetFromProlog tk_get_info(dummy,$modelNode,enum_type_defns)
#    }
#
#    method GetEnumTypeMembers {ident} {
#	foreach typeDef [ListEnumTypes] {
#	    if {[string equal $ident [lindex $typeDef 0]]} {
#		return [lrange $typeDef 1 end]
#	    }
#	}
#	error "Model does not include type $ident"
#    }
#
#    method ChangeEnumType {args} {
#	if {[llength $args]<2} {
#	    error "Type definition needs identifier and at least one member"
#	}
#	GetEnumTypeMembers [lindex $args 0] ;# check it exists
#	prolog tk_change_enum_type($modelNode,'$args')
#    }
#
#    method Destroy {} {
#        itcl::delete object $this
#    }
#    
#    # added for building models on web server -- do not document
#    method ExportCppCode {cppFile} {
#	set ::preSelect $cppFile
#        if {[catch {MenuSelect $modelCanvas code build_c} spew]} {
#	    set missingFile [lindex [split $::errorInfo \n] 2 0 3]
#	    puts [glob [file join [file dirname $missingFile] *]]
#	}
#    }
#
#    # added for building models on web server -- do not document
#    method BuildShareLib {shlibFile} {
#	set ::preSelect $shlibFile
#        MenuSelect $modelCanvas code compile_c
#    }
#
#    # added for diaplaying models on web server -- do not document
#    method BuildSVGDiagram {shlibFile} {
#	set ::preSelect $shlibFile
#	ExportSVGDirect $modelNode
#    }
#
#    # Model Menu
#    method Run {} {
#	global botches
#        # builds the model with CPP and returns a run control command/object
#        #RemoveRunControl
#        MenuSelect $modelCanvas code run_c
#        #set rc [similescript::RunControl ::runControl $this]
#        #return $rc
#	set botches(modelJustRun) $this
#    }
#    
#    method Debug {} {
#        # builds the model with Tcl and returns a run control command/object
#        #RemoveRunControl
#        MenuSelect $modelCanvas code run_tcl
#        #set rc [similescript::RunControl ::runControl $this]
#        #return $rc
#    }
#    
#    method ListEquations {} {
#        MenuSelect $modelCanvas file list_eqns
#    }
#    
#    method LoadParams {filepath {smPath {}}} {
#	if {![file exists $filepath]} {
#	    error "Could not find file $filepath"
#	}
#        do_for_node $modelNode set ::projectParams($smPath) $filepath
#    }
}

itcl::class similescript::HelperController {
    # Class providing basic control of existing helpers
    # The constructor DOES NOT create a helper use class Helper
    public variable winId;    #Tk path to RunControl window
    variable modelInst
    
    destructor {
        if {![string match *_3dinst $this]} {
	    destroy $winId
	}
    }
    
    public method Show {} {
	if {[string equal $winId [winfo toplevel $winId]]} {
	    do_for_node [GetNode] wm deiconify $winId
	}
    }
    
    public method Hide {} {
        #puts "HelperController Hide $winId; $modelNode"
	if {[string equal $winId [winfo toplevel $winId]]} {
	    do_for_node [GetNode] wm withdraw $winId
	}
    }

    public method GetNode {} {
	return [$modelInst getNode]
    }
}

itcl::class similescript::Snap {
    
    inherit HelperController
    
    variable myNode
    constructor {modelWindow path} {
        set winId [$modelWindow CreateSnapWindow $path]
	set myNode $path
        Hide
    }

    public method SaveCurrent {filename} {
	do_for_node [GetNode] SaveSnapToFile $winId $myNode $filename
    }

    public method Update {} {
	set updateCmd [$winId.bbframe.buttonBox itemcget 1 -command]
	uplevel #0 $updateCmd
    }

    public method StartLogging {filename} {
	set myId [do_for_node [GetNode] GetIdFromCaptionPath $myNode]
	do_for_node [GetNode] StartLogging $winId [GetNode] $myId $filename
    }

    public method StopLogging {} {
	set myId [do_for_node [GetNode] GetIdFromCaptionPath $myNode]
	do_for_node [GetNode] StopLogging $winId [GetNode] $myId
    }
}
    
itcl::class similescript::Layer {
    public variable State {}
    public variable host;
    public variable winId;    # canvas 
    variable modelInst
    
    constructor {modelWindow layerTool} {
	global helperTable

	set modelInst $modelWindow
	set host $layerTool
	set winId [$host GetCanvas]
	set helperTable($this,foci) {}
     }

    destructor {
	#ShowMess debug info "Killing $winId" ok
	global helperTable

	if {[string equal $this [$modelInst hasClicks]]} {
	    $modelInst releaseClicks
	}
	foreach node $helperTable($this,foci) {
	    $::runState([GetNode],inspId) HelperLeaf $node $this 0
	}
	unset helperTable($this,foci)
	bind $winId <Destroy> {} ;# prevent destructor calling itself when...
	# (done by base destructor)	    destroy $winId
    }

    public method GetNode {} {
	return [$modelInst getNode]
    }

    # All derived classes must reimplement with correct keyvalue
    public method KeyValue {} {
        return abstractLayer
    }
# only old-style helpers have keyvalues, but this is needed for some reason

    # likewise
    public method Identify {} {
        return abstractLayerTitle
    }

# This is optional, some helpers do not store earlier values
    public method Clear {} {
    }

# This is optional, some helpers do not distinguish data from different runs
    public method Reset {} {
    }

# This is optional, some helpers may keep their state permanently up to date
    public method PrepareSaveString {} {
    }

# default is no legend
    public method GetNewLegendSide {} {
	return n
    }

}

itcl::class similescript::Helper {
    inherit HelperController
    public variable State {}
    
    constructor {modelWindow helperTitle} {
	global tcl_platform SimileAutoObjLoaded helperTable

	set modelInst $modelWindow
        #puts "Helper constr $modelWindow [KeyValue] $winTitle"

	# ShowMessage debug info "Making $helperId $helperTitle" ok
	if {[string match *_3dinst $this]} {
	    set winId placeholder
	    return
	} else {
	    set winId ${::RunEnv::CurrentContainer}.container
	    pack [ttk::frame $winId] -fill both -expand true
	    bind $winId <Destroy>  "itcl::delete object $this"
# needed because gui can remove parent widget
	}
	set helperTable($this,foci) {}
	set helperTable($winId,whichInstance) $this
        #puts "Helper constr $this winId $winId"
    }
    
    destructor {
	#ShowMess debug info "Killing $winId" ok
	global helperTable runState

	if {[string equal $this [$modelInst hasClicks]]} {
	    $modelInst releaseClicks
	}
	set modelNode [GetNode]
	if {[llength [array names runState $modelNode,helperId]]} {
	    # 'info exists' buggy in itcl4
	    if {[string equal $winId $runState($modelNode,helperId)]} {
		unset runState($modelNode,cnvs)
		unset runState($modelNode,helperId)
	    }
	    foreach node $helperTable($this,foci) {
		$runState($modelNode,inspId) HelperLeaf $node $this 0
	    }
	}
	bind $winId <Destroy> {} ;# prevent destructor calling itself when...
	# (done by base destructor)	    destroy $winId
	if {[string match *_3dinst $this]} return
	unset helperTable($winId,whichInstance)
	unset helperTable($this,foci)
    }

    # All derived classes must reimplement with correct keyvalue
    public method KeyValue {} {
        return abstractHelper
    }
# only old-style helpers have keyvalues, but this is needed for some reason

    # likewise
    public method Identify {} {
        return abstractTitle
    }

# This is optional, some helpers do not store earlier values
    public method Clear {} {
    }

# This is optional, some helpers do not distinguish data from different runs
    public method Reset {} {
    }

# This is optional, some helpers may keep their state permanently up to date
    public method PrepareSaveString {} {
    }

    public method Introspect {cmd} {
	return [eval $cmd]
    }
}

itcl::class similescript::OldStyleHelper {
    inherit Helper
    
# compulsory
    public proc Identify {} {
	return [[KeyValue]::identify]
    }

    constructor {modelWindow winTitle {state {}}} {
	Helper::constructor $modelWindow $winTitle
    } {
	global helperTable

	set this4 $this ;# flagrant Itcl4 bug workaround
	set helperTable(beingCalled) $this
	if {[llength $state]} {
	    set State $state
	# need to catch error here because catching later leaves inconsistency
	    if {[catch {[KeyValue]::Restore $winId} hiccup]} {
		Query [list iotool_restore_fail [[KeyValue]::identify] \
                           $::errorInfo] warning helpers {} abort
	    }
	} else {
	    [KeyValue]::initialize $winId
	}
	set helperTable(beingCalled) {}
    }

# optional (but all old-style helpers have it)
    public method Reset {} {
	return [[KeyValue]::reset $winId]
    }

# optional (but all old-style helpers have it)
    public method Display {current display update} {
	return [[KeyValue]::display $winId $current $display $update]
    }

# optional if you never call GrabClicks (but all old-style helpers have it)
    public method Click {path} {
	set node [do_for_node [GetNode] GetIdFromCaptionPath $path]
	set caption [lindex [split $path /] end]
	return [[KeyValue]::click $winId $node $caption]
    }
}

### RUN OBJECT -- no longer a kind of helper
oo::class create similescript::RunControl {
    variable modelNode
    
    constructor {{modelInst {}}} {
	global botches

	if {[string equal {} $modelInst]} {
	    set modelInst $botches(modelJustRun)
	}
	# set modelNode [$modelInst getNode] ; may not be set yet
    }
    
    method CreateHelperWindow {helperId helperTitle} {
redo with helper object
        set winId [do_for_node $modelNode NewHelperWindow $modelNode \
		       $helperId $helperTitle]
        do_for_node $modelNode ${helperId}::initialize $winId
	::RunEnv::ChildrenFocusParent $winId
        return $winId
    }

    method setNode {node} {
	set modelNode $node
    }

    method getNode {} {
	return $modelNode
    }
    
    method seedRandoms {seedval} {
	::SeedRandoms $modelNode $seedval
    }

# Methods for helper apps to call
    method grabClicks {helperInst} {
	global helperTable

	set helperTable($modelNode,current) $helperInst
	UpdateCursors hand2
	if {[info exists ::RunEnv::variableListFrame($modelNode)]} {
	    $::RunEnv::variableListFrame($modelNode) config -cursor hand2
	}
    }

    method hasClicks {} {
	global helperTable

	if {[info exists helperTable($modelNode,current)]} {
	    return $helperTable($modelNode,current)
	} else {
	    return {}
	}
    }

    method releaseClicks {} {
	global helperTable

	unset helperTable($modelNode,current)
	UpdateCursors $::window_info(defCurs)
	if {[info exists ::RunEnv::variableListFrame($modelNode)]} {
	    $::RunEnv::variableListFrame($modelNode) config -cursor arrow
	}
    }

    method getValue {path args} {
	array set opts $args
	if {[string first / $path]} { ;# already a node id
	    set node $path
	} else {
	    set node [do_for_node $modelNode GetIdFromCaptionPath $path]
	}
	set keepZeros [expr {[info exists opts(-all)] && $opts(-all)}]
        set numerics \
	    [lindex [do_for_node $modelNode GetModelValue $node $keepZeros] 0]
	if {[info exists opts(-numeric)] && $opts(-numeric)} {
	    return $numerics
	}
	set trans [GetCompProperty $modelNode Trans $node]
	return [TransEnums $trans $numerics]
    }
    
    method getMinValue {path} {
        global runState
        return [do_for_node $modelNode GetMinValue [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    method getMaxValue {path} {
        global runState
        return [do_for_node $modelNode GetMaxValue [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
   
    method getModelEval {path} {
        return [do_for_node $modelNode GetModelEval [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    method getModelDims {path} {
        return [do_for_node $modelNode GetModelDims [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    method GetModelClass {path} {
        return [do_for_node $modelNode GetModelClass [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }

#    method CreateSnapWindow {path} {
#redo with snap object
#        set winId [do_for_node $modelNode snap $modelNode [do_for_node $modelNode GetIdFromCaptionPath $path]]
#        return $winId
#    }
#    method Hide {} {
#	global runState
#	wm withdraw [winfo toplevel $runState($modelNode,helperId)]
#    }
#	
#    method Show {} {
#	global runState
#	wm deiconify [winfo toplevel $runState($modelNode,helperId)]
#    }
#	
#    method Start {} {
#        # returns the time to complete (to run the simulation)
#	global runState helperTable
#
##	set rcf $runState($modelNode,helperId).nb.rcf
##        set timestr [time [list $rcf.upper.topbuttons.start invoke]]
#        set timestr [time [list $helperTable(RunControl)::SetMode $modelNode start]]
#        set musec [lindex $timestr 0]
#        return "[expr {$musec/1e6}] sec"
#    }
#    
#    method Reset {} {
#	global runState
#
#	set rcf $runState($modelNode,helperId).nb.rcf
#	$rcf.upper.topbuttons.reset invoke
#    }
#    
#    method MergeParams {filepath {smPath {}}} {
#        do_for_node $modelNode ZapParams $modelNode $smPath $filepath 0
#    }
#    
#    method SetTimeUnits {units} {
#        # units: unit second minute hour day week month year Ma
#        do_for_node $modelNode set ::runState($modelNode,timeUnit) $units
#    }
#    
#    method GetTimeUnits {} {
#        global runState
#        return [do_for_node $modelNode set ::runState($modelNode,timeUnit)]
#    }
#    
#    method GetIntegrationMethod {} {
#        #return $runState($modelNode,intMethod)
#        return [do_for_node $modelNode set ::runState($modelNode,intMethod)]
#    }
#    method SetIntegrationMethod {method} {
#        do_for_node $modelNode set ::runState($modelNode,intMethod) $method
#    }
#    
#    method SetIntegrationMethodEuler {} {
#        do_for_node $modelNode set ::runState($modelNode,intMethod) Euler
#    }
#    
#    method SetIntegrationMethodRungeKutta {} {
#        do_for_node $modelNode set ::runState($modelNode,intMethod) {4th-order Runge-Kutta}
#    }
#    
#    method GetStepAdaptLimit {} {
#	if {[do_for_node $modelNode set ::runState($modelNode,adapt)]} {
#	    return [do_for_node $modelNode set ::runState($modelNode,errLimit)]
#	} else {
#	    return 0
#	}
#    }
#
#    method SetStepAdaptLimit {limit} {
#	do_for_node $modelNode set ::runState($modelNode,adapt) \
#	    [expr {$limit!=0}]
#	do_for_node $modelNode set ::runState($modelNode,errLimit) $limit
#    }
#
#    method SetExecuteFor {time} {
#        do_for_node $modelNode set ::runState($modelNode,execTime) $time
#    }
#    
#    method GetExecuteFor {} {
#        return [do_for_node $modelNode set ::runState($modelNode,execTime)]
#    }
#    
#    method SetTimeAtReset {time} {
#        do_for_node $modelNode set ::runState($modelNode,resetTo) $time
#    }
#    
#    method GetTimeAtReset {} {
#        return [do_for_node $modelNode set ::runState($modelNode,resetTo)]
#    }
#    
#    method GetCurrentTime {} {
#        return [do_for_node $modelNode set ::runState($modelNode,currentTime)]
#    }
#    
#    method SetDisplayInterval {timeStep} {
#        do_for_node $modelNode set ::runState($modelNode,displayInt) $timeStep
#    }
#    
#    method GetDisplayInterval {} {
#        return [do_for_node $modelNode set ::runState($modelNode,displayInt)]
#    }
#    
#    method GetNumberOfTimeSteps {} {
#        return [do_for_node $modelNode GetPhaseCount $modelNode]
#    }
#    
#    method SetTimeStep {index timestep} {
#        if {0<$index && $index<=[GetNumberOfTimeSteps]} {
#            do_for_node $modelNode set ::runState($modelNode,update${index}) $timestep
#        } elseif {$index==0 || $index==-1}  {
#            puts "Timestep 0 and -1 cannot be specified."
#        } else  {
#            puts "Timestep $index is not in use."
#        }
#    }
#    
#    method GetTimeStep {index} {
#        if {0<$index && $index<=[do_for_node $modelNode GetPhaseCount $modelNode]} {
#            return [do_for_node $modelNode set ::runState($modelNode,update${index})]
#        } elseif {$index==0 || $index==-1}  {
#            puts "Timestep 0 and -1 cannot be specified."
#        } else  {
#            puts "Timestep $index is not in use."
#        }
#    }
#    
#    method RequestValues {args} {
#	global runState
#
#	array unset runState $this,scriptReqs
#	foreach path $args {
#	    set nodeId [do_for_node $modelNode GetIdFromCaptionPath $path]
#	    if {[string equal nomatch $nodeId]} {
#		error "Could not find node $path"
#	    }
#	    lappend runState($this,scriptReqs) $nodeId
#	}
#    }
#    
#    method SetValue {path value} {
#        set nodeId [do_for_node $modelNode GetIdFromCaptionPath $path]
#        switch -- [$this GetModelEval $path] {
#            INPUT {
#		PlaceInArray $modelNode $nodeId $value 0 [RunningInC $modelNode]
#                switch -glob -- [$this GetModelType $path] {
#                    FLAG {
#                        do_for_node $modelNode set ::checkStates($nodeId) $value
#                    }
#                    ENUM(*) {
#                        set comboChoices($nodeId) $defVal
#                    }
#                    default {
#                        do_for_node $modelNode set ::sliderVals($nodeId) $value
#                    }
#                }
#            }
#            TABLE {
#		PlaceInArray $modelNode $nodeId $value 0 [RunningInC $modelNode]
#		do_for_node $modelNode set ::paramData(/$modelNode$path) $value
#                do_for_node $modelNode set ::runState($modelNode,reloadParams) -1 ;# this makes sure the value is propagated in the model
#                Reset
#            }
#            default {
#                if {[string match [$this GetModelClass $path]  COMPARTMENT]} {
#                    do_for_node $modelNode SetModelValue $nodeId $value
#                } else  {
#                    puts "$path is not a parameter (variable or fixed) or compartment so its value cannot be changed."
#                }
#            }
#        }
#        return [do_for_node $modelNode GetModelValue $nodeId]
#    }
#    
#    #paths
#    method GetModelType {path} {
#        return [do_for_node $modelNode GetModelType [do_for_node $modelNode GetIdFromCaptionPath $path]]
#    }
#    
#    ################################################################################
#    # # what would a scripter do with this?
#    #     method GetObjectList {} {
#    #         return [do_for_node $modelNode GetObjectList $winId]
#    #     }
#    ################################################################################
#    
#    # any use??
#    method GetPhaseCount {} {
#        return [do_for_node $modelNode GetPhaseCount $modelNode]
#    }
#    
#    method GetAllPaths {} {
#        set nodes [do_for_node $modelNode GetObjectList]
#        set paths {}
#        foreach node $nodes {
#            lappend paths [do_for_node $modelNode GetCaptionPathFromId $node]
#        }
#        return $paths
#    }
    
    #proc GetModelGraph {node}
    #proc SetModelGraph {node args}
    #proc GetModelTime {}
    #proc GetModelEndTime {}
}
