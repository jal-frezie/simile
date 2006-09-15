#!/usr/bin/wish

# replace /./ in path with / to avoid confusing file dirname

# non-tclet should use c stub, but license is tricky
proc random01 {} {
    return [expr rand()]
}

if {[info exists embed_args]} {
    set custom(prefDir) {}
} else {
    set initDir [pwd]
    regsub -all /\\./ [file join $initDir [info script]] / scriptCmd
    set SIMILE_PATH [file dirname [file dirname $scriptCmd]]
    cd $SIMILE_PATH/Run
    
    if {[file exists $env(HOME)]} {
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
}
set runHow(where) home
source runmodel.tcl
MakeHelperMenu

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

# now load the required helpers explicitly, as we cannot get directory listings
#set helperList [list DisplayFormats.tcl graphtools.tcl Standard/Control.tcl Standard/ModelInspector.tcl Standard/Slider.tcl Plotter.tcl two_table.tcl maps2.tcl Lollipop.tcl modeldiagram.tcl]

#foreach helperApp [lsort $helperList] {
#    source [file join ../IOTools $helperApp]
#    if {[info exists keyValue]} {
#	set action [${keyValue}::identify]
#	if {[string match {Run control} $action]} {
#	    set helperTable(RunControl) $keyValue
#	}
#	if {[string match {Explorer} $action]} {
#	    set helperTable(VariableList) $keyValue ;# for MRE
#	}
#	if {[string match {Data table} $action]} {
#	    set table_viewer(id) $keyValue
#	}
#    }
#}

#set modelProg [tk_getOpenFile -filetypes [list [list "Tcl model files" .tcl]]]
#if {![llength $modelProg]} {
#    exit
#}

# used by ChooseFile
proc GetPathChoice {args} {
    return [pwd]
}
proc RecordPathChoice {args} {
}

package require MyTrf ;# use md5 for plugin
package require mime
if {[InPlugin]} {
    set initMenu .initButt.models
# list directories into menus, choose with button and load contents into mime
    pack [mybutton .initButt -text "Choose model to execute" -menu $initMenu]
    mymenu $initMenu
    foreach package [glob ../Examples/*.sml] {
	$initMenu add command -label [file tail $package] \
	    -command "set tgt $package"
    }
    tkwait variable tgt
} else {
    if {[llength $argv]} {
	set tgt [file join $initDir [lindex $argv 0]]
    } else {
	set tgt [ChooseFile "../Examples/forest.sml" "Model to execute" 0]
    }
    set goodieBag  [mime::initialize -file $tgt]
}

foreach bit [mime::getproperty $goodieBag parts] {
    catch {mime::getheader $bit Content-Disposition} Disposition
    if {![regexp \"(.*)\" $Disposition all oldPath]} {
	set oldPath [lindex [lindex $Disposition 0] 1]
    }
    switch [file extension $oldPath] {
	.tcl {
	    uplevel 0 [mime::getbody $bit]
	} .shf {
	    set shfBag [mime::initialize -string [mime::getbody $bit]]
	    set ::RunEnv::helperData [mime::getbody $shfBag]
#	} .cnv {
#	    set ::RunEnv::diagSpec [mime::getbody $bit]
	}
    }
}

# from ex_load_dll
# This won't catch defns in subdirectories

set myNode [lindex $nodedata(0) 0]
set model_id($myNode) 0
set instance_id($myNode) 0
set runState($myNode,updated) 0

StartRun $myNode
::RunEnv::LoadViewFile $myNode helperData 4.9
