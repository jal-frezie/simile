#!/usr/bin/wish

# replace /./ in path with / to avoid confusing file dirname

if {[info exists embed_args]} {
    set custom(prefDir) {}
    set fnFiles [list ../Functions/procs.tcl ../stubreplace.tcl]
} else {
regsub -all /\\./ [file join [pwd] [info script]] / scriptCmd
set SIMILE_PATH [file dirname [file dirname $scriptCmd]]
cd $SIMILE_PATH/Run

if {[info exists embed_args]} {
    set custom(prefDir) {}
} elseif {[file exists $env(HOME)]} {
# 4.1 moved SimileUserDirectory for Windows -- check in old position and update
    set oldPrefs [file join $env(HOME) .simile]
    if {[string equal windows $tcl_platform(platform)]} {
        set custom(prefDir) [file join $env(HOME) "My Documents" \
				 "My Simile files"]
        if {[file exists $oldPrefs]} {
	    if {![file exists $custom(prefDir)]} {
		file mkdir $custom(prefDir)
		foreach sysB {layout prefs recent version} {
		    catch {file rename $oldPrefs/$sysB $custom(prefDir)/.$sysB}
		}
		foreach subD [glob $oldPrefs/*] {
		    file rename $subD $custom(prefDir)/[file tail $subD]
		}
		file delete $oldPrefs
	    }
        }
    } elseif {[string match Darwin $tcl_platform(os)]} {
        set custom(prefDir) [file join $env(HOME) "Simile"]
    } else {
        set custom(prefDir) $oldPrefs
    }
}
MakeHelperMenu
}
set runHow(where) home
source runmodel.tcl

# now we must replace some procedure definitions that don't work without Prolog
proc GetExecTitle {node} {return $node}
proc do_in_editor {args} {namespace eval :: $args}
proc GetFromProlog {args} {return no_prolog}
proc RecordRunParams {args} {}

proc PrefValue {long short} {
    switch -regexp $short {
	popupHelp|helperManager|compValPop {
	    return 1
	} default {
	    error "No preference suplied in exec_only for $short"
	}
    }
}

LoadIconImages
# now load the required helpers explicitly, as we cannot get directory listings
set helperList [list DisplayFormats.tcl graphtools.tcl Standard/Control.tcl Standard/ModelInspector.tcl Standard/Slider.tcl Plotter.tcl two_table.tcl maps2.tcl Lollipop.tcl modeldiagram.tcl]

foreach helperApp [lsort $helperList] {
    source [file join ../IOTools $helperApp]
    if {[info exists keyValue]} {
	set action [${keyValue}::identify]
	if {[string match {Run control} $action]} {
	    set helperTable(RunControl) $keyValue
	}
	if {[string match {Explorer} $action]} {
	    set helperTable(VariableList) $keyValue ;# for MRE
	}
	if {[string match {Data table} $action]} {
	    set table_viewer(id) $keyValue
	}
    }
}

#set modelProg [tk_getOpenFile -filetypes [list [list "Tcl model files" .tcl]]]
#if {![llength $modelProg]} {
#    exit
#}
set modelProg ../Examples/forest.tcl

# from ex_load_dll
# This won't catch defns in subdirectories

foreach fnFile $fnFiles {
    source $fnFile
}

source $modelProg
set myNode [lindex $nodedata(0) 0]
set model_id($myNode) 0
set instance_id($myNode) 0
set runState($myNode,updated) 0

StartRun $myNode
