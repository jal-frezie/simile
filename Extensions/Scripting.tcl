package require Itcl
if {[string equal windows $::tcl_platform(platform)]} {
    package require dde
    dde servername Simile
}

itcl::class script::Model {
    
    variable modelNode 
    variable modelWindowCanvas
    variable runControlKeyValue 
#    variable model
    
    
    constructor {{fname ""}} {
        global window_info
        NewTopLevel
        set modelWindowCanvas $window_info(current)
        set modelNode $window_info($modelWindowCanvas,top_node)
        set runControlKeyValue [do_for_node $modelNode set ::helperTable(RunControl)]
        if {[file exists $fname]} {
            Open $fname
        } 
        UseMRE false
    }
    
    destructor {
        MenuClose $modelWindowCanvas
    }
    
    private method GetModelWindow {} {
        global window_info
        return $window_info($modelWindowCanvas,parent)
    }
    
    private method GetRunState {} {
        # modelRunning is a global variable that indicates the status of the model
        # program: 0 = none, 1 = awaiting fixed params, 2 awaiting initialization,
        # 3 = up to date, 4 = out of date
        global runState
        if {[info exists runState($modelNode,modelRunning)]} {
            return $runState($modelNode,modelRunning)
        } else {
            return 0
        }
    }
    
    private method readyToGo {
        if {[GetRunState]==3} {
            return true
        } else {
            return false
        }
    }
    
    public method Hide {} {
        wm withdraw [GetModelWindow]
    }
    
    public method Show {} {
        wm deiconify [GetModelWindow]
    }
    
    public method GetModelNode {} {
        # Returns top node of model, needed for helpers
        return $modelNode
    }
    
    public method CreateHelperWindow {helperId helperTitle} {
        set winId [do_for_node $modelNode NewHelperWindow $modelNode $helperId $helperTitle]
        do_for_node $modelNode ${helperId}::initialize $winId
        if {[PrefValue custom(helperManager) helperManager]} {
            ::RunEnv::ChildrenFocusParent $winId
        }
        return $winId
    }
    
    
    public method UseMRE {bool} {
        global custom
        set custom(helperManager) $bool
    }
    
    # File menu commands
    public method New {} {
        MenuSelect $modelWindow file new
#        if {[info exists model]} {
#            unset model
#        }
    }
    
    public method FileOpenDlg {} {
        MenuSelect $modelWindow local open_all
    }
    
    public method Open {modelFile} {
#        if {[info exists model]} {
#            $this New
#        }
        Reopen $modelWindowCanvas $modelFile reopen
#        set model $modelFile
    }
    
    public method Close {} {
        itcl::delete object $this
    }
    
    public method Print {} {
        MenuSelect PrintNow $modelWindowCanvas
    }

# These all cause a file selection dialog to appear
#     public method ExportProlog {} {
#         MenuSelect [GetModelWindow].canvas file export_prolog
#     }
#     
#     public method ExportCompiledBinary {} {
#         MenuSelect [GetModelWindow].canvas file compile_c
#     }
#     
#     public method ExportPostScriptGraphics {} {
#         ExportPostscript [GetModelWindow].canvas
#     }
#     

    public method Destroy {} {
        itcl::delete object $this
    }
    
    
    # Model menu commands
    public method Build {{language "C++"}} {
        switch $language {
            "C++" {
                MenuSelect $modelWindowCanvas file run_c
            }
            "Tcl" {
                MenuSelect $modelWindowCanvas file run_tcl
            }
        }
    }
    
    public method Debug {} {
        MenuSelect $modelWindowCanvas file run_tcl
    }
    
    public method ListEquations {} {
        MenuSelect $modelWindowCanvas file list_eqns
    }
    
    public method LoadParams {filepath {smPath {}}} {
        do_for_node $modelNode set ::projectParams($smPath) $filepath
    }
    
    # Run control commands
    public method HideRunControl {} {
        global runState
        wm withdraw $runState($modelNode,helperId)
    }
    
    public method ShowRunControl {} {
        global runState
        wm deiconify $runState($modelNode,helperId)
    }
    public method Start {{script ""}} {
        global helperTable
        if {([string length $script] != 0) && [info complete $script]} {
            set helperTable($modelNode,callbackScript) $script
        }
        do_for_node $modelNode ${runControlKeyValue}::SetMode $modelNode start
    }
    
    public method Reset {} {
        do_for_node $modelNode ${runControlKeyValue}::SetMode $modelNode reset
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
    
    public method DefineDisplayCallback {script} {
        global helperTable
        set helperTable($modelNode,callbackScript) $script
        return
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
    
# What would a scripter do with this?
#    public method GetObjectList {} {
#        return [do_for_node $modelNode GetObjectList $winId]
#    }
    
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
    
#    proc GetModelGraph {node}
#    proc SetModelGraph {node args}
#    proc GetModelTime {}
#    proc GetModelEndTime {}
    
}

# HELPERS

itcl::class similescript::HelperController {
    # Class providing basic control of existing helpers
    # The constructor DOES NOT create a helper use class Helper

    # Tk path to window
    variable winId 
    
    # Top node of model window
    variable modelNode
    
    destructor {
        destroy $winId
    }
    
    public method Show {} {
        do_for_node $modelNode wm deiconify $winId
    }
    
    public method Hide {} {
        do_for_node $modelNode wm withdraw $winId
    }
    
    public method Destroy {} {
        itcl::delete object $this
    }
}

itcl::class similescript::Helper {
    
    inherit HelperController
    
    constructor {modelWindowObj winTitle keyValue} {
        set modelNode [$modelWindowObj GetModelNode]
        set winId [do_for_node $modelNode NewHelperWindow $modelNode $keyValue $winTitle]
        do_for_node $modelNode ${keyValue}::initialize $winId
        if {[PrefValue custom(helperManager) helperManager]} {
            ::RunEnv::ChildrenFocusParent $winId
        }
        return $winId
    }
    
    # All derived classes must reimplement with correct keyvalue
    public method KeyValue {} {
        return abstractHelper
    }

    public method Clear {} {
        [KeyValue]::clear $winId
    }
    
}

itcl::class similescript::TableHelper {
    
    inherit Helper
    
    constructor {modelWindowObj winTitle} {
        similescript::Helper::constructor $modelWindowObj $winTitle "tabular11510"
    } {
        # This empty body is used only to indicate that the previous script is 
        # an "init" script, which invokes the base constructor with arguments
    }
    
    public method KeyValue {} {
        return "tabular11510"
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
