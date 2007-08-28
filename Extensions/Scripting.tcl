package require Itcl
if {[string equal windows $::tcl_platform(platform)]} {
    package require dde
    dde servername Simile
}

itcl::class similescript::ModelWindow {
    variable modelNode
    variable modelCanvas
    variable model
    
    private method GetModelWindow {} {
        global window_info
	return $window_info($modelCanvas,parent)
    }

    public method GetNodeAndCanvas {} {
	return [list $modelNode $modelCanvas]
    }

    public method CreateHelperWindow {helperId helperTitle} {
redo with object
        set winId [do_for_node $modelNode NewHelperWindow $modelNode $helperId $helperTitle]
        do_for_node $modelNode ${helperId}::initialize $winId
        if {[PrefValue custom(helperManager) helperManager]} {
            ::RunEnv::ChildrenFocusParent $winId
        }
        return $winId
    }
    
    public method CreateSnapWindow {path} {
        set winId [do_for_node $modelNode snap $modelNode [do_for_node $modelNode GetIdFromCaptionPath $path]]
        return $winId
    }
    
    constructor {} {
	global class_for_node fromProlog

	prolog tk_make_desktop_node
        #tk_messageBox -message "ModelWin constructor"
	set modelNode [lindex $fromProlog 0]
	set modelCanvas [lindex $fromProlog 1]
	set class_for_node($modelNode) $this
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
#        MenuClose [GetModelWindow].canvas
# following replaces above...
	ByeByeNode $modelCanvas
    }
    
    public method Hide {} {
        wm withdraw [GetModelWindow]
    }
    
    public method Show {} {
        wm deiconify [GetModelWindow]
    }
    
    public method UseMRE {bool} {
        # IS THIS GOING TO HAVE A TYPE PROBLEM???
        global custom
        set custom(helperManager) $bool
    }
    
    # File Menu
    public method New {} {
        MenuSelect [GetModelWindow].canvas file new
        if {[info exists model]} {
            unset model
        }
    }
    
    public method FileOpenDlg {} {
        #if {[info exists model]} {
        #    $this FileNew"
        #}
        #$c local open_all
        MenuSelect [GetModelWindow].canvas local open_all
        #set model $modelFile
    }
    
    public method Open {modelFile} {
        if {[info exists model]} {
            $this New
        }
        Reopen [GetModelWindow].canvas $modelFile reopen
        set model $modelFile
    }
    
    public method Print {} {
        MenuSelect PrintNow [GetModelWindow].canvas
    }
    
    public method Destroy {} {
        itcl::delete object $this
    }
    
    private method RemoveRunControl {} {
        if {[string match ::runControl [itcl::find object ::runControl]]} {
            itcl::delete object ::runControl
        }
    }
    
    # Model Menu
    public method Run {} {
	global botches
        # builds the model with CPP and returns a run control command/object
        #RemoveRunControl
        MenuSelect [GetModelWindow].canvas file run_c
        #set rc [similescript::RunControl ::runControl $this]
        #return $rc
	set botches(modelJustRun) $this
    }
    
    public method Debug {} {
        # builds the model with Tcl and returns a run control command/object
        #RemoveRunControl
        MenuSelect [GetModelWindow].canvas file run_tcl
        #set rc [similescript::RunControl ::runControl $this]
        #return $rc
    }
    
    public method ListEquations {} {
        MenuSelect [GetModelWindow].canvas file list_eqns
    }
    
    public method LoadParams {filepath {smPath {}}} {
        do_for_node $modelNode set ::projectParams($smPath) $filepath
    }
    
}

itcl::class similescript::HelperController {
    # Class providing basic control of existing helpers
    # The constructor DOES NOT create a helper use class Helper
    variable winId;    #Tk path to RunControl window
    variable modelNode
    
    destructor {
        destroy $winId
    }
    
    public method Show {} {
	if {[string equal $winId [winfo toplevel $winId]]} {
	    do_for_node $modelNode wm deiconify $winId
	}
    }
    
    public method Hide {} {
        #puts "HelperController Hide $winId; $modelNode"
	if {[string equal $winId [winfo toplevel $winId]]} {
	    do_for_node $modelNode wm withdraw $winId
	}
    }

    public method GetNode {} {
	return $modelNode
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
	do_for_node $modelNode SaveSnapToFile $winId $myNode $filename
    }

    public method Update {} {
	set updateCmd [$winId.bbframe.buttonBox itemcget 1 -command]
	uplevel #0 $updateCmd
    }

    public method StartLogging {filename} {
	set myId [do_for_node $modelNode GetIdFromCaptionPath $myNode]
	do_for_node $modelNode StartLogging $winId $modelNode $myId $filename
    }

    public method StopLogging {} {
	set myId [do_for_node $modelNode GetIdFromCaptionPath $myNode]
	do_for_node $modelNode StopLogging $winId $modelNode $myId
    }
}
    
itcl::class similescript::Helper {
    inherit HelperController
    public variable State {}
    
    constructor {modelWindow helperTitle} {
	global tcl_platform SimileAutoObjLoaded helperTable

	set modelNode [lindex [$modelWindow GetNodeAndCanvas] 0]
        #puts "Helper constr $modelWindow [KeyValue] $winTitle"

    # ShowMessage debug info "Making $helperId $helperTitle" ok
	if {[PrefValue custom(helperManager) helperManager]} {
	    set winId ${::RunEnv::CurrentContainer}.container
	    pack [frame $winId] -fill both -expand true
	    bind $winId <Destroy>  "itcl::delete object $this"
# needed because gui can remove parent widget
	} else {
	    set winId .helper[newInt]
	    toplevel $winId
	    if {[info exists SimileAutoObjLoaded]} {
		wm state $winId withdrawn
	    }
	    if {[string length $helperTitle]} {
		wm title $winId [BlankCrs $helperTitle]
	    } else {
		wm title $winId [Identify]
	    }
	    if {![string match windows $tcl_platform(platform)]} {
		wm iconbitmap $winId @../Images/weegraph.xbm
	    }
	    wm protocol $winId WM_DELETE_WINDOW "itcl::delete object $this"
	}
	set helperTable($winId,whichInstance) $this
        #puts "Helper constr winId $winId"
    }
    
    destructor {
	# ShowMessage debug info "Killing $winId" ok
	global helperTable runState
	if {[info exists helperTable($modelNode,current)]} {
	    if {[string equal $winId  $helperTable($modelNode,current)]} {
		unset helperTable($modelNode,current)
	    }
	}
	if {[info exists runState($modelNode,helperId)]} {
	    if {[string equal $winId $runState($modelNode,helperId)]} {
		unset runState($modelNode,cnvs)
		unset runState($modelNode,helperId)
	    }
	}
	unset helperTable($winId,whichInstance)
	bind $winId <Destroy> {} ;# prevent destructor calling itself when...
	# (done by base destructor)	    destroy $winId
    }

    # All derived classes must reimplement with correct keyvalue
    public method KeyValue {} {
        return abstractHelper
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

    public method GetWindow {} {
	return $winId
    }

}

itcl::class similescript::OldStyleHelper {
    inherit Helper
    
    constructor {modelWindow winTitle {state {}}} {
	Helper::constructor $modelWindow $winTitle
    } {
	global helperTable

	set helperTable(beingCalled) $this
	if {[llength $state]} {
	    set State $state
	    [KeyValue]::Restore $winId
	} else {
	    [KeyValue]::initialize $winId
	}
	set helperTable(beingCalled) {}
    }

# compulsory
    public method Identify {} {
	return [[KeyValue]::identify]
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
    public method Click {node caption} {
	return [[KeyValue]::click $winId $node $caption]
    }

    public method PrepareSaveString {} {
	if {[llength [info procs [KeyValue]::PrepareSaveString]]} {
	    [KeyValue]::PrepareSaveString $winId
	}
    }
}

itcl::class similescript::RunControl {
    
    inherit HelperController
    
    constructor {} {
	global botches
        set modelWindow $botches(modelJustRun)
	set modelNode [lindex [$modelWindow GetNodeAndCanvas] 0]
        set keyvalue [do_for_node $modelNode set ::helperTable(RunControl)]
	set winId  [do_for_node $modelNode set ::runState($modelNode,helperId)]
        Hide
    }
    
    public method Start {} {
        # returns the time to complete (to run the simulation)
        set timestr [time [list do_for_node $modelNode ${keyvalue}::SetMode $modelNode start]]
        set musec [lindex $timestr 0]
        return "[expr {$musec/1e6}] sec"
    }
    
    public method Reset {} {
        do_for_node $modelNode ${keyvalue}::SetMode $modelNode reset
    }
    
    public method MergeParams {filepath {smPath {}}} {
        do_for_node $modelNode ZapParams $modelNode $smPath $filepath
    }
    
    public method SetTimeUnits {units} {
        # units: unit second minute hour day week month year Ma
        do_for_node $modelNode set ::runState($modelNode,timeUnit) $units
    }
    
    public method GetTimeUnits {} {
        global runState
        return [do_for_node $modelNode set ::runState($modelNode,timeUnit)]
    }
    
    public method GetIntegrationMethod {} {
        #return $runState($modelNode,intMethod)
        return [do_for_node $modelNode set ::runState($modelNode,intMethod)]
    }
    public method SetIntegrationMethod {method} {
        do_for_node $modelNode set ::runState($modelNode,intMethod) $method
    }
    
    public method SetIntegrationMethodEuler {} {
        do_for_node $modelNode set ::runState($modelNode,intMethod) Euler
    }
    
    public method SetIntegrationMethodRungeKutta {} {
        do_for_node $modelNode set ::runState($modelNode,intMethod) {4th-order Runge-Kutta}
    }
    
    public method SetExecuteFor {time} {
        do_for_node $modelNode set ::runState($modelNode,execTime) $time
    }
    
    public method GetExecuteFor {} {
        return [do_for_node $modelNode set ::runState($modelNode,execTime)]
    }
    
    public method GetCurrentTime {} {
        return [do_for_node $modelNode set ::runState($modelNode,currentTime)]
    }
    
    public method SetDisplayInterval {timeStep} {
        do_for_node $modelNode set ::runState($modelNode,displayInt) $timeStep
    }
    
    public method GetDisplayInterval {} {
        return [do_for_node $modelNode set ::runState($modelNode,displayInt)]
    }
    
    public method GetNumberOfTimeSteps {} {
        return [do_for_node $modelNode GetPhaseCount $modelNode]
    }
    
    public method SetTimeStep {index timestep} {
        if {0<$index && $index<=[GetNumberOfTimeSteps]} {
            do_for_node $modelNode set ::runState($modelNode,update${index}) $timestep
        } elseif {$index==0 || $index==-1}  {
            puts "Timestep 0 and -1 cannot be specified."
        } else  {
            puts "Timestep $index is not in use."
        }
    }
    
    public method GetTimeStep {index} {
        if {0<$index && $index<=[do_for_node $modelNode GetPhaseCount $modelNode]} {
            return [do_for_node $modelNode set ::runState($modelNode,update${index})]
        } elseif {$index==0 || $index==-1}  {
            puts "Timestep 0 and -1 cannot be specified."
        } else  {
            puts "Timestep $index is not in use."
        }
    }
    
    public method GetValue {path} {
        return [do_for_node $modelNode GetModelValue [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    public method SetValue {path value} {
        set nodeId [do_for_node $modelNode GetIdFromCaptionPath $path]
        switch -- [$this GetModelEval $path] {
            INPUT {
		if {[RunningInC $modelNode]} {
		    c_setparamelement $nodeId {} $value
		}
                switch -glob -- [$this GetModelType $path] {
                    FLAG {
                        do_for_node $modelNode set ::checkStates($nodeId) $value
                    }
                    ENUM(*) {
                        set trans [GetTransTable $nodeId]
                        set comboChoices($nodeId) $defVal
                    }
                    default {
                        do_for_node $modelNode set ::sliderVals($nodeId) $value
                    }
                }
            }
            TABLE {
		if {[RunningInC $modelNode]} {
		    c_setparamelement $nodeId {} $value
		}
		do_for_node $modelNode set ::paramData(/[GetExecTitle $modelNode]$path) $value
                do_for_node $modelNode set ::runState($modelNode,reloadParams) -1 ;# this makes sure the value is propagated in the model
                Reset
            }
            default {
                if {[string match [$this GetModelClass $path]  COMPARTMENT]} {
                    do_for_node $modelNode SetModelValue $nodeId $value
                } else  {
                    puts "$path is not a parameter (variable or fixed) or compartment so it's value cannot be changed."
                }
            }
        }
        return [do_for_node $modelNode GetModelValue $nodeId]
    }
    
    public method GetMinValue {path} {
        global runState
        return [do_for_node $modelNode GetMinValue [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    public method GetMaxValue {path} {
        global runState
        return [do_for_node $modelNode GetMaxValue [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    #paths
    public method GetModelType {path} {
        return [do_for_node $modelNode GetModelType [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    public method GetModelEval {path} {
        return [do_for_node $modelNode GetModelEval [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    public method GetModelDims {path} {
        return [do_for_node $modelNode GetModelDims [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    public method GetModelClass {path} {
        return [do_for_node $modelNode GetModelClass [do_for_node $modelNode GetIdFromCaptionPath $path]]
    }
    
    ################################################################################
    # # what would a scripter do with this?
    #     public method GetObjectList {} {
    #         return [do_for_node $modelNode GetObjectList $winId]
    #     }
    ################################################################################
    
    # any use??
    public method GetPhaseCount {} {
        return [do_for_node $modelNode GetPhaseCount $modelNode]
    }
    
    public method GetAllPaths {} {
        set nodes [do_for_node $modelNode GetObjectList]
        set paths {}
        foreach node $nodes {
            lappend paths [do_for_node $modelNode GetCaptionPathFromId $node]
        }
        return $paths
    }
    
    #proc GetModelGraph {node}
    #proc SetModelGraph {node args}
    #proc GetModelTime {}
    #proc GetModelEndTime {}
}

#set keyvalue tabular11510
#set winId [$modelWindow CreateHelperWindow $keyvalue {Table}]
#Hide
#chain
#SetUpdateAtDisplayInterval false

itcl::class similescript::TableHelper {
    
    inherit Helper
    
    constructor {modelWindow winTitle} {
        similescript::Helper::constructor $modelWindow $winTitle
    } {
        #puts "TableHelperImpl constr: $modelWindow [KeyValue] $winTitle"
    }
    
    public method KeyValue {} {
        return tabular11510
    }
    
    public method AddVariable {path} {
        do_for_node $modelNode set ::helperTable($modelNode,current) $winId
        do_for_node $modelNode [KeyValue]::click $winId [do_for_node $modelNode GetIdFromCaptionPath $path] $path
    }
    
    public method RemoveVariable {path} {
        set var $path; # prop needs nodeId TODO
        do_for_node $modelNode [KeyValue]::Remove $winId $var
    }
    
    public method SetUpdateAtDisplayInterval {value} {
        # value 0 or 1
        do_for_node $modelNode set [KeyValue]::displayUpdate($winId) $value
    }
    
    public method GetUpdateAtDisplayInterval {} {
        return  [do_for_node $modelNode set [KeyValue]::displayUpdate($winId)]
    }
    
    public method SetShowingRowsForTimes {value} {
        # value 0 or 1
	if {$value} {
	    set timeHdr rows
	} else {
	    set timeHdr none
	}
        do_for_node $modelNode lset [KeyValue]::orientList($winId) 0 $timeHdr
	do_for_node $modelNode [KeyValue]::Reconbobulate $winId	
    }
    
    public method GetShowingRowsForTimes {} {
        return [string equal rows [lindex \
	    [do_for_node $modelNode set [KeyValue]::orientList($winId)] 0]]
    }
    
    public method Update {} {
        do_for_node $modelNode [KeyValue]::Update $winId
    }
    
    public method SaveToFile {filename} {
        Update
        do_for_node $modelNode [KeyValue]::SaveToNamedFile $winId $filename
    }
    
    public method AppendToFile {filename sectionId} {
        Update
        do_for_node $modelNode [KeyValue]::SaveToNamedFile \
	    $winId $filename $sectionId
    }
    
}

itcl::class similescript::Plotter {
    inherit Helper
    constructor {modelWindow winTitle} {
        Helper::constructor $modelWindow $winTitle
    } {
        puts "Plotter constr: $modelWindow [KeyValue]"
    }
    
    public method KeyValue {} {
        return plotter1.25
    }
}

itcl::class similescript::FileWriter {
    inherit Helper
    constructor {modelWindow winTitle} {
        Helper::constructor $modelWindow $winTitle
    } {
        puts "FileWriter constr: $modelWindow [KeyValue]"
    }
    
    public method KeyValue {} {
        return filewriter220604
    }
}
