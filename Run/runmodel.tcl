# Go for closest thing to the old 'agroforestry' colours?
# tk_bisque
# No, it's horrible...

# First few procedures in here are utilities used by both the
# helper applications and the AME interface: put these in a new file.

package require BWidget

source ../Run/graphs.tcl
source ../Run/utility.tcl
source ../Run/hai2mmii.tcl

# botch -- mre.tcl has to be loaded after the other tcls or it doesn't
# work properly

source ../Run/mre.tcl

package require Tk
wm withdraw .

proc MakeHelperMenu {} {
    set fm [menu .helpers -tearoff 0]

    $fm add command -label "Load" -command LoadView
    $fm add command -label "Save" -command SaveView
    $fm add command -label "Clear" -command ClearView
    $fm add command -label "Close" -command KillHelpers
    $fm add command -label "Parameters..." \
            -command {FileParamDialogue 1 [focus]}

    set oldDir [pwd]
    cd ../IOTools
    AddHelperSublist $fm "Add tool" 2
    set ioDir [PrefValue custom(prefDir) prefDir]
    if {[file exists $ioDir]} {
	cd $ioDir
	AddHelperSublist $fm.sub2 "Local" l
    }
    cd $oldDir
}

# OK I have been having problems with people duplicating IO tool programs
# and not changing the key values, thus allowing one to overwrite the other.
# So one day, IO tools will not include a namespace spec, but this code
# will load them into one, so they should still use [namespace code ...] to
# make callbacks.

proc AddHelperSublist {fm title ct} {
    global helperTable table_viewer

    $fm add cascade -label $title -menu $fm.sub$ct
    set m [menu $fm.sub$ct -tearoff 0]
    set nct 0
    set helperList [glob -nocomplain *.tcl]
    foreach helperApp [lsort $helperList] {
        if [catch {source $helperApp} wibble] {
            # done at startup -- make sure dialog is not concealed
            wm withdraw .
            ShowMessage "Error loading I/O tool" warning \
                    "I/O tool [pwd]/$helperApp had a $wibble" ok
        } else {
            if {[info exists keyValue]} {
                set action [${keyValue}::identify]
                if {[string match {Run control} $action]} {
                    set helperTable(RunControl) $keyValue
                }
                if {[string match {Explorer} $action]} {
                    set helperTable(VariableList) $keyValue ;# for MRE
                }
#                if {[string match {Slider control} $action]} {
#                    set helperTable(SliderControl) $keyValue
#                }
                if {[string match {Data table} $action]} {
                    set table_viewer(id) $keyValue
                }
                $m add command -label $action \
                        -command [list CreateHelperWindow $keyValue $action]
                unset keyValue
            }
        }
    }
    foreach subDir [glob -nocomplain *] {
        if [file isdirectory $subDir] {
            cd $subDir
            AddHelperSublist $m $subDir $nct
            cd ..
            incr nct
        }
    }
}

MakeHelperMenu
set helperTable(current) none

proc CreateHelperWindow {helperId helperTitle} {
    set winId [NewHelperWindow $helperId $helperTitle]
    ${helperId}::initialize $winId
    if {[PrefValue custom(helperManager) helperManager]} {
        ::RunEnv::ChildrenFocusParent $winId
    }
    return $winId
}

proc NewHelperWindow {helperId helperTitle} {
    global helperTable tcl_platform

    # ShowMessage debug info "Making $helperId $helperTitle" ok
    if {[PrefValue custom(helperManager) helperManager]} {
        set winId [NewMreHelperWindow $helperId $helperTitle]
    } else {
        set winId .helper[newInt]
        set helperTable($winId,whichHelper) $helperId
        toplevel $winId
        wm title $winId $helperTitle
        if {![string match windows $tcl_platform(platform)]} {
            wm iconbitmap $winId @../Images/weegraph.xbm
        }
        wm protocol $winId WM_DELETE_WINDOW "kill_helper_window $winId"
    }
    return $winId
}

# If running a model which includes input parameters, we must
# make sure that these are somehow provided with inputs before
# trying to evaluate expressions in which they occur. This is
# done by creating a slider panel for them here.

# switch and switchd are binary inputs so should be set by
# toggles rather than sliders. Later...

#proc UnMakeSlidersForInputs { } {
#    global helperTable checkStates sliderVals
    # puts $inlist
#    if {[info exists helperTable(autosliders)]} {
#        kill_helper_window $helperTable(autosliders)
#        unset helperTable(autosliders)
#    }

#    if {[info exists checkStates]} {
#        unset checkStates
#    }
#    if {[info exists sliderVals]} {
#        unset sliderVals
#    }
#}

#proc MakeSlidersForInputs { } {
#    global helperTable
#    set helperTable(autosliders) [NewHelperWindow $helperTable(SliderControl) \
#            "Sliders for inputs"]
#   $helperTable(SliderControl)::initialize $helperTable(autosliders)
#}

# grab_clicks and release_clicks enable helper apps to ask
# the model to send mouse clicks to them while they are setting
# themselves up, or to the editor once they are done.

proc GrabClicks {winId} {
    global helperTable window_info

    set helperTable(current) $winId
    foreach whosyadaddy [array names window_info *,parent] {
	set c [string range $whosyadaddy 0 end-7]
	set window_info(cursor_was) [$c cget -cursor]
	$c config -cursor hand1
    }
}

proc ReleaseClicks {winId} {
    global helperTable window_info

    set helperTable(current) none
    foreach whosyadaddy [array names window_info *,parent] {
	set c [string range $whosyadaddy 0 end-7]
	$c config -cursor $window_info(cursor_was)
    }
}

proc kill_helper_window { winId } {
    # ShowMessage debug info "Killing $winId" ok
    global helperTable
    if {[info exists helperTable($winId,whichHelper)]} {
        if {[string compare $helperTable(current) $winId]==0} {
            set helperTable(current) none
        }
        unset helperTable($winId,whichHelper)
        destroy $winId
        #	if {[PrefValue custom(helperManager) helperManager]} {
        #	    RunEnv::OnDestroyHelper $winId
        #	}
        # ShowMessage debug info "Killed $winId" ok
    }
}

proc GetState {winId} {
    global helperTable
    return $helperTable($winId,status)
}

proc SetState {winId newState} {
    global helperTable
    set helperTable($winId,status) $newState
}

proc ProdObj {nodeId caption} {
    global helperTable
    if {[string equal none $helperTable(current)]} {
	return 0
    } else {
	switch -regexp [GetModelType $nodeId] {
	    REAL|INTEGER|FLAG|ENUMERATED {
		set target $helperTable(current)
		
		set helperId $helperTable($target,whichHelper)
		${helperId}::click $target $nodeId $caption
	    } default {
		ShowMessage "Clicked on $caption" error \
                    "This component cannot be selected for an I/O tool because it has no associated value." ok
	    }
	}
	return 1
    }
}

# This is used for items on IO tool canvases -- model components have eqnpopups
proc CanvasBindPopup {canvas widget keywd} {
    $canvas bind $widget <Enter> [list QueuePopup AddWidgetPopup $keywd %X %Y]
    $canvas bind $widget <Leave> RemovePopup
}

# args are not used -- when binding to a table wigdet we cannot avoid getting
# the item name on the end of the call

proc Prettify {value} {
    if {[llength $value]==1} {
        return $value
    } else {

        set newValue {}
        while {[llength $value]} {
            lappend newValue [join [list [lindex $value 0] \
                    [Prettify [lindex $value 1]]] :]
            set value [lrange $value 2 end]
        }
        return $newValue
    }
}

proc DestroyHelpers {} {
    global modelWin
    if {[winfo exists .mre]} {
        ::RunEnv::Destroy
    } else {
        KillHelpers
    }
}

proc KillHelpers {} {
    global helperTable
    foreach graphBox [array name helperTable *,whichHelper] {
        scan $graphBox {%[^,]} window
        kill_helper_window $window
    }
}

proc ClearView {} {
    global helperTable

    foreach displayBox [array name helperTable *,whichHelper] {
        scan $displayBox {%[^,]} winId
        set helperId $helperTable($displayBox)
        catch {${helperId}::clear $winId}; # in case helper has no clear proc
    }
}

#  nameOfHelperStateFile is global because helpers might want to save names of
# other files they need relative to it, e.g., file param helper

proc SaveView {} {
    global helperTable nameOfHelperStateFile
    set nameOfHelperStateFile \
	[ChooseFile iotools.shf "Save view specification file" 1]
    if {[llength $nameOfHelperStateFile]} {
        set stream [NetOpen $nameOfHelperStateFile w]
        foreach displayBox [array name helperTable *,whichHelper] {
            scan $displayBox {%[^,]} winId
            set helperId $helperTable($displayBox)
            if {![string match $helperId $helperTable(RunControl)]} {
                puts $stream $helperId
                # substitute <cr>s so entry goes on one line
                puts $stream [StripCrs [wm title $winId]]
                puts $stream [wm geometry $winId]
                set clickedPaths {}
                if {[info exists helperTable($winId,status)]} {
                    puts $stream [StripCrs $helperTable($winId,status)]
                } else {
                    puts $stream {}
                }
            }
        }
        close $stream
    }
}

proc LoadView {} {
    global helperTable nameOfHelperStateFile errorInfo
    set nameOfHelperStateFile \
	[ChooseFile iotools.shf "Open view specification file" 0]
    if {[llength $nameOfHelperStateFile]} {
        set stream [NetOpen $nameOfHelperStateFile r]
        while {[gets $stream helperId] >= 0} {
            if {[llength $helperId]==4} {
                set response [ShowMessage {Inappropriate view specification} \
                        warning \
                        "This view specification file was created within the integrated Model Run \
                        Environment. Do you wish to launch a view-only version of MRE to view it?" \
                        yesnocancel]
                switch $response {
                    yes {
                        Makemre UnusedArg
                        RunEnv::LoadViewFile $stream $helperId
                    } no {
                        LoadMREFormatView $stream
                    } cancel {
                    }
                }
                close $stream
                return
            }
            gets $stream helperTitle
            set winId [NewHelperWindow $helperId [RestoreCrs $helperTitle]]
            gets $stream geometry
            wm geometry $winId $geometry
            gets $stream oldStatus
            set helperTable($winId,status) [RestoreCrs $oldStatus]
	    if {[catch {${helperId}::Restore $winId}]} {
	        kill_helper_window $winId
		ShowMessage "Problem restoring helper" warning $errorInfo ok
	    }
        }
        close $stream
    }
}

proc LoadMREFormatView {stream} {
    global helperTable
    while {[gets $stream helperId] >= 0} {
        if {[namespace exists $helperId]} {
            set helperTitle [${helperId}::identify]
            set winId [NewHelperWindow $helperId $helperTitle]
            gets $stream oldStatus
            set helperTable($winId,status) [RestoreCrs $oldStatus]
            ${helperId}::Restore $winId
        }
    }
}

proc TellAllHelpers {fun args} {
    global helperTable

    foreach displayBox [array name helperTable *,whichHelper] {
        scan $displayBox {%[^,]} winId
        set helperId $helperTable($displayBox)
        eval {${helperId}::$fun $winId} $args
    }
}

proc ScrubRun {times} {
    global runState running_c model_id instance_id window_info
    #    if {![string match ok [ShowMessage debug info Scrubbing okcancel]]} {
    #	error Bombed
    #    }
    set runState(modelRunning) 0
    if {$times && [info exists runState(currentTime)]} {
        unset runState(currentTime)
    }
    if {[info exists model_id]} {
        if {$model_id} {
            if {[info exists instance_id]} {
                #ShowMessage debug info "Exiting $model_id $instance_id" ok
                c_exitmodel $model_id $instance_id
                unset instance_id
            } else {
                #ShowMessage debug info "Exiting $model_id 0" ok
                c_exitmodel $model_id 0
            }
        } else {
            if {[info exists instance_id]} {
                #ShowMessage debug info "Exiting $model_id $instance_id" ok
		namespace delete ::AME_model<>
                unset instance_id
	    }
        }
#        unset model_id
        foreach winData [array name window_info *,parent] {
            set toolBar $window_info($winData).toolSlot.toolbar
            $toolBar.snap configure -state disable
            set navBar $window_info($winData).toolSlot.navbar
            $navBar.runenv configure -state disable
            $window_info($winData)top.tools entryconfigure {Inspect elements} -state disable
        }
#        ToggleIOToolMenu 0
    }
    if {[info exists running_c]} {unset running_c}
}

proc GetModelTime {} {
    global runState
    return $runState(currentTime)
}

# modelRunning is a global variable that indicates the status of the model
# program: 0 = none, 1 = awaiting fixed params, 2 = up to date, 3 = out of date

set runState(modelRunning) 0
set this ::AME_model<>
# var containing namespace id called 'this' for compatibility with c++

proc StartRun {} {
    global runState helperTable running_c window_info
    # ShowMessage debug info enter(start_run) ok
    if {[info exists runState(currentTime)]} {
        if {$runState(execTime) != $runState(currentTime)} {
            set runState(execTime) \
                    [expr $runState(execTime)+$runState(currentTime)]
        }
        for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
            if {![info exists runState(prev_update$phase)]} {
                set runState(update$phase) 0.1
                set runState(prev_update$phase) 0.1
            }
            SetStep $runState(prev_update$phase) $phase
        }
    } else {
        set runState(execTime) 100
        set runState(displayInt) 1
        for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
            set runState(update$phase) 0.1
	    set runState(time$phase) 0
            set runState(prev_update$phase) 0.1
            SetStep 0.1 $phase
	    SetStep 0 -$phase
        }
    }

    set runState(currentTime) 0.0
    set runState(timeAtEval) 0.0
#    set runState(currentWin) $winId ;# enables rebuild from run control
    if {![FileParamDialogue 0]} {
	return 0
    }
    if {[PrefValue custom(helperManager) helperManager]} {
        #    ShowMessage debug info "About to make MRE [array name window_info *,parent]" ok
        raise [Makemre]
    } else {
#	ToggleIOToolMenu 1
    }
#    Now have to do this in Prolog so only running windows change
#    foreach winData [array name window_info *,parent] {
#        set toolBar $window_info($winData).toolSlot.toolbar
#        $toolBar.snap configure -state active
#        set navBar $window_info($winData).toolSlot.navbar
#        $navBar.runenv configure -state active
#        $window_info($winData)top.tools entryconfigure {Inspect elements} -state active
#    }
    set runState(reloadParams) 1
    set runState(modelRunning) 2
#    EnableTools Fix
    set runState(modelUpdated) 0

    # MakeSlidersForInputs is currently done after initializing the
    # model, so default values calculated from eqns can be loaded to the
    # sliders. Here we must clear any old input tool values so they are not used.
#    UnMakeSlidersForInputs

    set defHelper $helperTable(RunControl)
    
    if {[regexp "(.helper\[0-9\]+),whichHelper $defHelper" \
                [array get helperTable] spare helperId]} {
        kill_helper_window $helperId
    }
    set helperId [NewHelperWindow $defHelper "Default run control"]
    ${defHelper}::initialize $helperId
    set runState(helperId) $helperId

# Do not put up mre, sliders, etc if model has failed to start
#    if {![info exists running_c]} {
#	return
#    }

# remake notebook page for sliders if earlier deleted
#    if {[PrefValue custom(helperManager) helperManager]} {
#	set sliderBook ${::RunEnv::explorerPane}.notebook
#	if {![info exists ::RunEnv::sliderControlFrame]} {
#	    $sliderBook insert end "InputSliders" -text "Input sliders"
#	    pack [set ::RunEnv::sliderControlFrame [frame [$sliderBook getframe "InputSliders"].sliders]] -fill both -expand yes
#	    $sliderBook raise InputSliders
#	}
#    }

#    MakeSlidersForInputs
    
    if {[PrefValue custom(helperManager) helperManager]} {
        CreateHelperWindow $helperTable(VariableList) "Variables"; # JMM
#	if {![winfo exists $helperTable(autosliders)]} {
# No sliders in model, so delete notebook page
#	    $sliderBook delete InputSliders
#	    $sliderBook raise Explorer
#	    unset ::RunEnv::sliderControlFrame
#	}
	set ctrlPane [winfo parent [winfo parent [winfo parent [winfo parent \
					$::RunEnv::runControlFrame]]]]
	update ;# so reqheight works next
	$ctrlPane sash place 0 \
	    10 [expr [winfo reqheight $ctrlPane.runcontrolPane]+10]
    }
# Now list all the inputs in the model, so we can avoid running it until
# all have tools attached to provide their values
#    if {[info exists inputHelper]} {
#	array set oldInputHelper [array get inputHelper]
#	unset inputHelper
#    }
#    foreach node [GetObjectList] {
#	if {[string match TABLE [GetModelEval $node]]} {
#	    set name [GetCaptionPathFromId $node]
#	    if {[info exists oldInputHelper($name)]} {
#		set inputHelper($name) $oldInputHelper($name)
#		unset oldInputHelper($name)
#	    } else {
#		set inputHelper($name) {}
#	    }
#	}
#    }
#    foreach removedInput [array names oldInputHelper] {
#	TellHelperItsGone $oldInputHelper($removedInput) $removedInput
#    }
#    CheckFixedParamState
    set widget [$runState(helperId).rcf getframe]
    $widget.topbuttons.reset invoke
}

proc TellHelperItsGone {helperWin captionPath} {
# for compatibility, call a helper proc and if the helper doesn't have it
# delete it
}

proc CheckFixedParamState {} {
    global inputHelper runState
    if {$runState(modelRunning)==1 && \
	    [lsearch [array get inputHelper] {}] == -1} { 
	# fixed param with no src
	set runState(modelRunning) 2
	# this initializes the model
        set widget [$runState(helperId).rcf getframe]
        $widget.topbuttons.reset invoke
	EnableTools IO
    }
}

proc EnableTools {group} {
    set tgt .helpers.sub2
    for {set entry 0} {$entry <= [$tgt index last]} {incr entry} {
	set text [$tgt entrycget $entry -label]
	if {[string match Fix $group]==[string match {Set fixed parameters...} $text]} {
	    $tgt entryconfigure $entry -state normal
	} else {
	    $tgt entryconfigure $entry -state disabled
	}
    }
}

# this gets rid of a c program that has been loaded into
# the interpreter, to allow a new one to replace it --
# loadmodel with no args unloads model (this crashes Windows)

proc remove_c_model {} {
    # The following is not done cos it removes the stub as well
    #    package forget ame_dll
    #
    #    foreach c_command {c_resetmodel c_evalmodel c_updatemodel c_exitmodel \
    #	    getvalue getnodeid listobjects} {
    #	rename $c_command {}
    #    }
}

proc build_tcl_program {} {
    global model_id instance_id
    #   model_id set to 0 cos its existence is tested when getting model structure

    set model_id 0
    set instance_id 0
    StartRun
}

proc update_c_executable {} {
    #    ShowMessage debug info "References are $finderList" ok
    global model_id instance_id

    # For the toplevel model, make an instance. This will also make
    # instances of any fixed-membership submodels immediately, so they had
    # better already be loaded

    set instance_id [c_createmodel $model_id]
    #    ShowMessage debug info "model instance $instance_id created" ok

    StartRun
}

# load_dll adds a dll to the system. Trees are added bottom up, so model_id
# is always that most recently added (even if not recompiled)

proc load_dll {lang progDir id node} {
    #   phasecount and nodedata are set in generated code
    global phasecount nodedata nodecount model_id model_ids model_prog env
    if {[string match tcl $lang]} {
	if {![file exists $progDir/model.tcl]} {
	    return 0
	}
        foreach fnFile [glob -nocomplain "../Functions/*.tcl"] {
            source $fnFile
        }
        source [set model_prog $progDir/model.tcl]
        if {[info exists simile_version]} {
	    return [expr $simile_version==$env(SIMILE_VERSION)]
        } else {
            return 0
        }
    } else {
	set progFile $progDir/model${id}[info sharedlibextension]
	if {![file exists $progFile]} {
	    return 0
	}
        if {[catch {loadmodel $progFile $node} model_id]} {
	    if {[PrefValue custom(hackBreak) hackBreak]} {
		ShowMessage {Loading model dll} info "Failed to load the compiled model program. The operating system returned the following message: $model_id -- the program will attempt to build another one." ok
	    }
            unset model_id
            return 0
        }
        #        set model_id [loadmodel $nameBase[info sharedlibextension] $node]
        set model_ids($node) $model_id
        return $model_id
    }
}

proc set_connections {connects} {
    global model_id model_ids instance_id
# Run is always scrubbed, this should not need to
    # ShowMessage debug info "Trimming..." ok
#    if {[info exists instance_id]} {
#        c_exitmodel $model_id $instance_id
#        unset instance_id
#        unset model_ids
#    }
    #ShowMessage debug info "About to load: $connects" ok
    set_connection_database $connects
    #ShowMessage debug info "...loaded." ok
    #   now...dont set running_c till instance made -- use model_id till then
    #    set running_c 1
}

# FindPhase tells us when a node in a separate submodel will be
# available. The submodel indicates this by its eval phase. If DERIVED, INPUT
# or TABLE it can be used any time; if EXOGENOUS we must wait till that
# submodel has been called. If it is in a nested submodel, then it is
# usable after the phase in which the submodel is executed, or after
# its own phase if that is SPLIT. -1 means node not found.

# Note that because the top level model dll may not yet be loaded, we have
# to set model_id to the model we are searching in (model_ids keeps track of
# dlls loaded so far)

proc FindPhase {node submodel} {
    global model_id model_ids

    set model_id $model_ids($submodel)
    foreach subnode [listobjects $model_id] {
        set subtype [GetModelEval $subnode]
        if {[string match $node $subnode]} {
            if {[string match EXOGENOUS $subtype]} {
                return 1
            } else {
                return 0
            }
        }
        if {[string match EXTERNAL [GetModelType $subnode]]} {
            lappend subs [list $subnode $subtype]
        }
    }
    foreach nodeTypePair $subs {
        set subFind [FindPhase $node [lindex $subs 0]]

        if {$subFind != -1} {
            switch [lindex $subs 1] {
                EXOGENOUS {
                    return 1
                } DERIVED {
                    return 0
                } SPLIT {
                    return $subFind
                }
            }
        }
    }
    return -1
}

proc compile_c {workingDir} {
    global tcl_platform env

    if {[PrefValue custom(hackBreak) hackBreak]} {
        ShowMessage {Code editing opportunity} info \
                "About to compile model.cpp in $workingDir" ok
    }
    set oldDir [pwd]
    cd $workingDir
# get a so far unused file name
    set serial [newInt]
    set TARGET model${serial}[info sharedlibextension]
    while {[file exists $TARGET]} {
	set serial [newInt]
	set TARGET model${serial}[info sharedlibextension]
    }
    set TOOLDIR $oldDir/../Run
    set TCL [file dirname [file dirname [info library]]]
    #ShowMessage debug info "TCL is $TCL, TOOLDIR is $TOOLDIR" ok
    scan [info tclversion] {%d.%d} MAJ MIN
    switch $tcl_platform(platform) {
        unix {
            if {[string match Darwin $tcl_platform(os)]} {
                exec g++ -fPIC -c -O -I$TOOLDIR -o objtemp.o model.cpp
                exec g++ -dynamiclib -o $TARGET objtemp.o
            } else {
                exec g++ -fPIC -c -O -I$TOOLDIR -o objtemp.o model.cpp
                exec g++ -shared -o $TARGET objtemp.o
            }
        }
        windows {
            set TOOLDIR [file attributes $TOOLDIR -shortname]
            if {[string match GNU [PrefValue custom(compChoice) compChoice]]} {
                set dll ame_dll${MAJ}${MIN}
                switch $tcl_platform(os) {
                    {Windows NT} {
                        exec cmd /c start /min g++ -c -o objtemp.o -I$TOOLDIR -I. model.cpp
                        exec cmd /c start /min dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtemp.o
                    }
                    {Windows 95} {
                        exec start /m g++ -c -o objtemp.o -I$TOOLDIR -I. model.cpp
                        exec start /m dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtemp.o
                    }
                }
                file delete exptemp.exp

                # Method using command line calls to MSVC 4.0 or later -- works well
            } else {
                set TOOLS32 [file dirname $env(MSVCDIR)/any]
                exec $TOOLS32/bin/cl.exe -Ox -c -W3 -nologo \
                        -DWIN32 -D_WIN32 -D_DLL -D_X86_=1 \
                        -I. -I$TOOLS32/include -I$TOOLDIR \
                        -Foobjtemp.o model.cpp
                exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO \
                        -align:0x1000 /MACHINE:IX86 \
                        -entry:_DllMainCRTStartup@12 -dll -out:$TARGET \
                        $TOOLDIR/../System/lib/Stubs/ame_dll${MAJ}${MIN}.lib \
                        $TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib \
                        $TOOLS32/lib/oldnames.lib objtemp.o
            }
            # Method using command line calls to Borland C++ 4.0 or later -- not finished

            #	set TOOLS32 "c:/program files/borland/cbuilder4"
            #	exec $TOOLS32/bin/bcc32.exe -Ox -c -nologo -o$object \
            #		-DWIN32 -D_WIN32 -D_DLL -D_X86_=1 -DMODELCODE="$c_prog" \
            #		-I. -I$TOOLS32/include -I$TCL/include $TOOLDIR/support.cpp



            #	exec $TOOLS32/bin/ilink32.exe -Tpd $object $TARGET $TCL/lib/tcl${MAJ}${MIN}.lib
            # Method using MSVC's auto-generated Make file -- hangs for some
            # reason

            #	exec $TOOLS32/bin/nmake $TOOLDIR/amemodel/amemodel.mak
            #	file rename $TOOLDIR/amemodel/debug/amemodel.dll $TARGET

        }
    }
    #    file delete $c_prog
    file delete objtemp.o

    # do not allow an old dcf to be saved with a new model
    cd $oldDir
    return $serial
}

proc ListSameNumbers {list1 list2} {
    set target [llength $list1]
    if {$target != [llength $list2]} {return 0}
    for {set count 0} {$count < $target} {incr count} {
        if {[lindex $list1 $count] != [lindex $list2 $count]} {return 0}
    }
    return 1
}

# procedures to handle graph data

#proc insert_graph_data {graph_data_pointer xlow xhigh xspan ylow yhigh yspan \
\#            xsize array_data} {
 #   variable graphdata
 #   set $graph_data_pointer [format "%f %f %d %f %f %d %d %s" \
 \#           $xlow $xhigh $xspan $ylow $yhigh $yspan $xsize $array_data]
#}


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

proc do_setstepmodel {value level} {
    global ts dts
    if {$level<0} { ;# lazy
	set ts([expr -$level]) $value
    } else {
	set dts($level) $value
    }
}

proc at_time_step {} {
    return [expr [glob_element dts 0]<=1]
}

proc loses {prob phase} {
    if {$prob >= 1} {
	return 1
    } else {
	set kills_per_step [expr [glob_element dts 0]?4:1]
	return [expr [ame_rand 0 1] > \
		    pow(1-$prob, [glob_element dts $phase]/$kills_per_step)]
    }
}

# delete_list is a dummy procedure. What it should do is clear the
# submodel instances from the list supplied, but since (a) it would also
# need the parent namespace and (b) they tend to get reused anyway in
# tcl, I have not bothered.

proc delete_list {list_id} {
}

proc glob_element {arrptr phase} {
    upvar #0 $arrptr arr
    return $arr($phase)
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

proc compare_instance_status {testInstName refInst num} {
    upvar 1 $testInstName testInst
    #    ShowMessage debug info "testInst $testInst refInst $refInst" ok
    if {[string match 0 $testInst]} {return 1}
    for {set ptr 0} {$ptr < $num} {incr ptr} {
        if {[lindex $testInst $ptr]<[lindex $refInst $ptr]} {return -1}
        if {[lindex $testInst $ptr]>[lindex $refInst $ptr]} {return 1}
    }
    return 0
}

proc compare_values {v1 indexTxt v2 length step} {
    # ShowMessage debug info "compare_values\n$v1\n$indexTxt\n$v2\n$length\n$step" ok
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

proc ame_rand {lowBound highBound} {
    return [expr $lowBound +[random01]*($highBound - $lowBound)]
}


proc stop {code} {
    error "User-defined interruption code $code"
}

proc SampleFrom {a} {
    if {[llength $a] == 1} {
        return $a
    } else {
        array set fun $a
        foreach index [array names fun] {
            set b [SampleFrom $fun($index)]
            if {$b} {
                return $b
            }
        }
        return 0
    }
}

proc IsArray {a} {
    string compare $a [lindex $a 0]
}

package require Trf
load_c_stub
set intCount 0

proc newInt {} {
    global intCount
    return [incr intCount]
}

# Ultra crappy random alg now replaced by c library version

#set randfoob [expr exp(-1)]
#proc random01 {} {
#	global randfoob
#	return [set randfoob [expr fmod(1/$randfoob,1)]]
#}

proc ModelDirectory {} {
    global custom
    return [file dirname [lindex $custom(hotlist) 0]]
}

