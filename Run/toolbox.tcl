# Welcome to toolbox.tcl, the file containing the bits of tcl and tk
# needed to supply the graphical interface to the modelling environment.
# Just to give you an idea of (a) the sort of thing you can do in tcl,
# and (b) my preferred programming style, check this out....

package require BWidget

source ../Run/window.tcl
source ../Run/shapes.tcl
source ../Run/forms.tcl
source ../Run/prefs.tcl
#source ../Run/runmodel.tcl
source ../Run/graphs.tcl
source ../Run/utility.tcl

source ../Run/messages.tcl

# Find a new temporary directory
#if {[info exists env(TMP)]} {
#    set tempDir $env(TMP)
#} else {
#    if {[info exists env(TEMP)]} {
#	set tempDir $env(TEMP)
#    } else {
#	if {[string match windows $tcl_platform(platform)]} {
#	    set tempDir /temp
#	} else {
#	    set tempDir /tmp
#	}
#    }
#}

# Test new Windows printing technology -- see file for credits/licence
if {[string match windows $tcl_platform(platform)]} {
    #    set tempDir [file attributes $tempDir -shortname]
    #    set tempDir [file join [file dirname $tempDir] [file tail $tempDir]]
    
    #   pkg_mkIndex ../System/lib/Extras
    source ../System/lib/Extras/prntcanv.tcl
    
    # Make Simile a DDE server under Windows. Jonathan autotesting
    # Must be after the sourcing or Simile fails
    package require dde 1.2
    dde servername Simile
} elseif {[string match Linux $tcl_platform(os)]} {
    # avoid loading buggy Trf if ActiveTcl present on system
    # package ifneeded Trf 2.1 {}
}

set equationbar(current_action) null

proc NewTopLevel {} {
    MenuSelect dummy file new_toplevel
    #    set newInstance [interp create]
    #    $newInstance eval package require Tk
    #    $newInstance eval set argc 0
    #    $newInstance eval source ../Run/simile.tcl
    
}

proc OpenTopLevel {model} {
    MenuSelect dummy open_toplevel $model
    #    set newInstance [interp create]
    #    $newInstance eval package require Tk
    #    $newInstance eval set argc 1
    #    $newInstance eval [list set argv $model]
    #    $newInstance eval source ../Run/simile.tcl
}

proc AttackGlobalVariable {array elt val} {
    global $array
    #ShowMessage debug info "Setting $array$elt" ok
    set $array$elt $val
    return ;# because letting it return an array causes a crash
}

# Prolog typically calls this to make error handling prettier

proc FilterErrors {args} {
    global errorInfo
    set oldDir [pwd]
    if {[catch $args retVal]} {
	wm withdraw . ;# ensure error mess is not obscured by splash screen
        set ans [ShowMessage "Simile error" error "Simile encountered an unexpected problem:\n $retVal \nDo you want to see more information?" yesno]
        if {[string match yes $ans]} {
            BuildProblem unsaved none $errorInfo tcl
        }
        cd $oldDir
        return -1
    } else {
        return $retVal
    }
}

# Now to switch off all error reporting from Tcl (Unintended feature of
# Version 8.0p2, any image file will do)
# image create photo open -file "../Images/mailbox.gif"
# Actually I think not, it seems to prevent the window menu appearing as well

proc ShiftDll {Point Top Loc Rep} {
    if {[llength $Loc]} {
        set AddLoc /$Loc
    } else {
        set AddLoc $Loc
    }
    
    set base $Top/$Point$AddLoc
    file mkdir $base
    if {[llength $Rep]} {
        set prefx $base/model
        if {$Rep && [file exists ${prefx}${Rep}[info sharedlibextension]]} {
            file copy -force ${prefx}${Rep}[info sharedlibextension] \
                    ${prefx}[info sharedlibextension]
        } else {
            file delete -force ${prefx}[info sharedlibextension]
            file delete -force ${prefx}.tcl
        }
        #	foreach file [glob -nocomplain ${prefx}*] {
        #	    if {![string match ${prefx}.* $file]} {
        #		file delete $file
        #	    }
        #	}
    }
}

proc TrimTree {Top Point} {
    if {[llength $Point]} {
        foreach file [glob -nocomplain "$Top/$Point/*"] {
            file delete -force $file
        }
    } else {
        file delete -force [file rootname $Top]
    }
}

# this takes the spec for a model executable file and a list of user-defined
# functions. It gets the date on which the executable was made, then looks
# up which file contains the function definition (for procedures we assume
# that is the same base as the one containing its declaration) and drops out
# if the latter is newer

proc CheckFnsFresh {L progDir id userFnList} {
    global equation custom
    
    if {[string equal tcl $L]} {
        set procXtn .tcl
        set progFile $progDir/model.tcl
    } else {
        set procXtn .cpp
        set progFile $progDir/model${id}[info sharedlibextension]
    }
    set stat 0
    set files {}
    if {[file exists $progFile]} {
        set date [file mtime $progFile]
    } else {
        set date 0
    }
    foreach func $userFnList {
        set functor [lindex [split $func /] 0] ;# remove arity
        set posn [lsearch $equation(fnDefs) "{Macros *} $functor"]
        if {$posn == -1} {
            set posn [lsearch $equation(fnDefs) \
                    "{Procedures *} $functor * returns *"]
        }
        if {$posn == -1} {
            return "4 $func" ;# missing function declaration
            # should never happen because we read them when starting up
        } else {
            set fnSpec [lindex [lindex $equation(fnDefs) $posn] 0]
            set fnBase $custom(prefDir)/Functions/[lindex $fnSpec 1]
            if {[file mtime ${fnBase}.pl]>$date} {
                set stat [max $stat 2] ;# Declaration out of date
            }
            if {[string equal Procedures [lindex $fnSpec 0]]} {
                set file ${fnBase}$procXtn
                if {![file exists $file]} {
                    return "3 $func $file";# Missing or misplaced definition
                } else {
                    if {[lsearch $files $file]==-1} {
                        lappend files $file
                    }
                    if {[file mtime $file]>$date && ![string equal tcl $L]} {
                        set stat [max $stat 2] ;# Definition out of date
                        # no problem with tcl definitions, included at run time
                    }
                }
            }
        }
    }
    return [concat $stat $files]
}

# set this to interp or process to run models in a separate interpreter
# or process
set runHow(type) process
set runHow(time) parallel

# this exists in case I don't want to exploit the concat in eval
proc do_for_node {node args} {
    global runState tcl_platform runHow simtmpdir

    if {![info exists runState($node,interp)]} {
	if {[string equal interp $runHow(type)]} {
	    set runState($node,interp) [interp create]
	    $runState($node,interp) alias BringParameter BringParameter
	    $runState($node,interp) eval set runHow $runHow(type)
	    $runState($node,interp) eval source ../Run/support.tcl
	} else {
	    scan [info tclversion] {%d.%d} MAJ MIN
	    if {[string equal windows $tcl_platform(platform)]} {
		set sep {}
	    } else {
		set sep .
	    }
	    set makeExec ../System/bin/wish$MAJ$sep$MIN
#puts "starting $makeExec"
	    set runState($node,interp) [open |$makeExec r+]
	    fileevent $runState($node,interp) readable \
		[list FeedModel $node]
	    
	    puts $runState($node,interp) "source ../Run/runmodel.tcl"
	    flush $runState($node,interp)
	    puts $runState($node,interp) \
		[list KickOff $node $runHow(type) $simtmpdir]
	    flush $runState($node,interp)
#puts "initialized"
	    set runState($node,modelReady) 1
	    set runState($node,queueSize) 0
	}
    }
    return [eval do_in_node $node $args]
}

proc do_in_node {node args} {
    global runState runHow

    set command [list do $args]
    if {[string equal interp $runHow(type)]} {
	set result [$runState($node,interp) eval $command]
    } else {
	if {[string equal parallel $runHow(time)]} {
	    while {!$runState($node,modelReady)} {
		tkwait variable runState($node,modelReady)
	    }
	}
	if {$runState($node,modelReady)==1} {
	    puts $runState($node,interp) $command
	    flush $runState($node,interp)
	    incr runState($node,queueSize)
#puts "put: $command for $runState($node,queueSize)"
	    set runState($node,modelReady) 0
	    upvar \#0 runState($node,response$runState($node,queueSize)) result
	    if {[string equal parallel $runHow(time)]} {
		tkwait variable \
		    runState($node,response$runState($node,queueSize))
	    } else {
		fileevent $runState($node,interp) readable {}
		while {!$runState($node,modelReady)} {
		    FeedModel $node
		}
		fileevent $runState($node,interp) readable \
		    [list FeedModel $node]
	    }
#puts "Got $result for $runState($node,queueSize)"
	    incr runState($node,queueSize) -1
	} else {
	    set result {res 0}
#puts "$command: model dead"
	}
    }
    set info [lindex $result 1]
    switch [lindex $result 0] {
	err {
	    error [lindex $info 0] [join $info \n]
	} res {
	    return $info
	}
    }
}

proc FeedModel {node} {
    global runState errorInfo

    gets $runState($node,interp) incoming
    if {[string equal get [lindex $incoming 0]]} {
#puts "get: $incoming"
	if {[catch [lindex $incoming 1] response]} {
	    set result [list err [split $errorInfo \n]]
	} else {
	    set result [list res $response]
	}
#puts "put: $result"
	puts $runState($node,interp) $result
	flush $runState($node,interp)
    } else {
	set runState($node,modelReady) 1
	set runState($node,response$runState($node,queueSize)) $incoming
    }
}

proc KillInterpFor {node} {
    global runState runHow
    if {[info exists runState($node,interp)]} {
	if {[string equal interp $runHow(type)]} {
	    interp delete $runState($node,interp)
	} else {
	    puts $runState($node,interp) exit
	    flush $runState($node,interp)
	    close $runState($node,interp)
	}
        unset runState($node,interp)
    }
}

proc do_if_running {node args} {
    global runState

    if {[info exists runState($node,interp)]} {
	return [eval do_in_node $node $args]
    } else {
	return 0
    }
}

# In the executable interpreter, do_in_editor means execute in this
# interpreter. But there are some functions shared between the interps
# that need to do this, so in this interp it just evaluates its
# arguments.

proc do_in_editor {args} {
    return [eval $args]
}

proc HaveValues {node} {
    set globRef \$::runState($node,modelRunning)
    return [do_if_running $node expr $globRef>2]
}

proc TryToKill {node} {
    global runState
#puts "Trying to kill $node"
    c_killmodel [pid $runState($node,interp)]
    catch {close $runState($node,interp)}
    unset runState($node,interp)
# now supply bogus result to interrupted model call
    set runState($node,response$runState($node,queueSize)) {res 0}
#puts "get: model killed"
# and unstick anything still waiting for it
    set runState($node,modelReady) -1
#    set runState($node,modelRunning) 0

#    unset instance_id($node)
#    unset model_id($node)
    ToggleIOToolMenu $node
}

# Pass on Prolog calls meant for model
proc ScrubRun {node times} {
    set optKill [after 3000 TryToKill $node]
    do_if_running $node ScrubRun $node $times
    after cancel $optKill
    ToggleIOToolMenu $node
}

proc DestroyHelpers {node} {
    do_if_running $node DestroyHelpers $node
}

proc GetRunParams {node} {
    global runState
    if {[info exists runState($node,interp)]} {
	if {$runState($node,modelReady)} {
	    return [do_in_node $node GetRunParams $node]
	}
    }
}


proc load_dll {topNode lang progDir id node incs} {
    do_for_node $topNode load_dll $topNode $lang $progDir $id $node $incs
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
    if {[catch {switch $tcl_platform(platform) {
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
    }} chuckup]} {
	set badCompile "The compiler raised a problem with the code generated for this model. This might be due to a bad compiler setup, or it could be due to mathematical problems in the model. The error was: $chuckup. It may help to try running the model in Tcl."
	BuildProblem none none $badCompile user
	set serial -1
    } else {
    #    file delete $c_prog
	file delete objtemp.o
    }
    # do not allow an old dcf to be saved with a new model
    cd $oldDir
    return $serial
}

proc LoadProgram {node lang} {
    global runState
    set runState($node,updated) 0
    set runState($node,lang) $lang
    if {[do_for_node $node update_executable $node $lang]} {
        ToggleIOToolMenu $node
    }
}

set intCount 0

proc newInt {} {
    global intCount
    return [incr intCount]
}

proc CheckUpToDate {node action} {
    global runState window_info
    
    if {$runState($node,updated) == 1} {
        set updateChoice [ShowMessage "Model out of date" warning \
                "The model has been altered since the curent runnable version was built. Rebuild it now?" yesnocancel]
        switch $updateChoice {
            yes {
                # grits teeth
                foreach win [array names window_info *,top_node] {
                    if {[string equal $node $window_info($win)]} {
                        set winId [string range $win 0 end-9]
                        if {$window_info($winId,is_top_level)} {
                            return [Rerun $winId [string match start $action]]
                        }
                    }
                }
            } no {
                set runState($node,updated) 0 ;# do not ask again
            }
        }
        return $updateChoice
    } else {
        return true
    }
}

proc ControlDraw {prologVersion} {
    global sendvars custom tcl_platform env userinfo openModel simtmpdir
    
    LoadIconImages
    
    # Defaults to use if debugging
    if {![info exists env(SIMILE_VERSION)]} {
        set env(SIMILE_VERSION) 4.0
        set env(licensee_name) "Support team"
        set env(licensee_corp) "Simulistics, inc."
        set env(license_code) default_license=072ccc96dced2bef53403afd67fe7782
    }
    
    set sendvars(simV) $env(SIMILE_VERSION)
    set sendvars(proV) $prologVersion
    
    # no longer have a separate floating toolbar
    
    # loading stub sets license entries
    load_c_stub
    
    # substitutes for license entries if we want to avoid loading stub
    #set userinfo(final_expiry) 0
    #set userinfo(days_after_install) 0
    #set userinfo(edn) standard
    
    # eezi-hack implementation of time limit: to do this anything like
    # properly, have stub dll check unix time against clock time
    
    set day [expr 24*60*60]
    if {$userinfo(final_expiry)} {
        set expTime $userinfo(final_expiry)
    }
    if {$userinfo(days_after_install)} {
        set installTime [lindex [lindex [split $env(install_time) =] 1] 0]
        set relExpTime [expr $installTime+$userinfo(days_after_install)*$day]
        if {$userinfo(final_expiry)} {
            set expTime [min $expTime $relExpTime]
        } else {
            set expTime $relExpTime
        }
    }
    if {[info exists expTime]} {
        set userinfo(exp_time) $expTime
        set toGo [expr $expTime-[clock seconds]]
        
        if {$toGo<0} {
            set crumble "This version of Simile has passed its expiry date."
            error $crumble
        } elseif {$toGo<7*$day} {
            #	    ShowMessage "Expiry imminent" warning "This version of Simile will expire on [clock format $expTime]. Please contact www.simulistics.com for an update." ok
            ShowExpiryImminent $expTime
        }
    }
    
    
    if {[file exists $env(HOME)]} {
        set custom(prefDir) [file join $env(HOME) .simile]
    } else {
        set custom(prefDir) [pwd]/../Prefs
    }
    
    if {![file exists $custom(prefDir)]} {
        file mkdir $custom(prefDir)
    }
    
    set simtmpdir $custom(prefDir)/sim
    set go [clock clicks]
    while {[file exists $simtmpdir]} {
        set guess_free [expr [clock clicks]-$go]
        set simtmpdir $custom(prefDir)/sim$guess_free
    }
    file mkdir $simtmpdir
    
    if {[file exists $custom(prefDir)/version]} {
        set UserStream [NetOpen $custom(prefDir)/version r]
        gets $UserStream userinfo(name)
        gets $UserStream userinfo(corp)
        gets $UserStream userinfo(oldVersion)
        gets $UserStream userinfo(done)
        close $UserStream
    } else {
        set userinfo(oldVersion) 0
        set userinfo(done) 0
    }
    
    set UserStream [NetOpen $custom(prefDir)/version w]
    puts $UserStream $userinfo(name)
    puts $UserStream $userinfo(corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream
    
    set sendvars(running) 0
    
    set custom(hotlist) {}
    if {[file exists $custom(prefDir)/recent]} {
        set cacheStream [NetOpen $custom(prefDir)/recent r]
        while {[gets $cacheStream oldFile]>0} {
            if {[file exists $oldFile] && \
                        [lsearch $custom(hotlist) $oldFile]==-1} {
                lappend custom(hotlist) $oldFile
            }
        }
        close $cacheStream
    }
    if {[llength $custom(hotlist)]} {
        RecordPathChoice .sml [lindex $custom(hotlist) 0] 0
    }
    
    Pref_Init $custom(prefDir)/prefs ../Run/sysprefs
    Pref_Add {{custom(initNavbar) initNavbar ON "Tool bar"} \
                {custom(initToolbar) initToolbar ON "Component bar"} \
                {custom(initEqnbar) initEqnbar ON "Equation bar"} \
                {custom(bigButtons) bigButtons OFF "Use large buttons"} \
                {custom(popupHelp) popupHelp ON "Popup help text"} \
                {custom(saveExtras) saveExtras {CHOICE {Model file only} {Canvas file}} "Save models as..."} \
                {custom(compDescPop) compDescPop ON "Equation"} \
                {custom(compValPop) compValPop ON  "Value"}
        {custom(compCmtPop) compCmtPop ON  "Comment"} \
                {custom(recentCount) recentCount 10 "Entries on recently used file list"} \
                {custom(flowRouting) flowRouting ON "Rectilinear flow routing"} \
                {custom(deleteEndToEnd) deleteEndToEnd ON "Select links end-to-end"}}
    # JMM change wording and change default to ON
    Pref_Add {{custom(helperManager) helperManager ON \
                    "Use single window manager"}};
    #JMM add postions for run control and slider
    Pref_Add {{custom(runControlPosition) runControlPosition "+0-20" "Position of run control"} \
                {custom(slidersPosition) slidersPosition "+0+0" "Position of sliders"}}
    Pref_Add {{custom(hackBreak) hackBreak OFF \
                    "Pause to edit C++ code?"}}
    if {[string match windows $tcl_platform(platform)]} {
        Pref_Add {{custom(compChoice) compChoice {CHOICE None Microsoft GNU} \
                        "Use which C++ compiler?"}}
        file attributes $custom(prefDir) -hidden true
        if {[string mat Microsoft [PrefValue custom(compChoice) compChoice]]} {
            set compiler cl.exe
            set possDirs {}
            if {[info exists env(MSVCDIR)]} {
                set possDirs [concat $possDirs [split $env(MSVCDIR) \;]]
            }
            if {[info exists env(MSDEVDIR)]} {
                set possDirs [concat $possDirs [split $env(MSDEVDIR) \;]]
            }
            lappend possDirs {c:/progra~1/micros~1/vc98} {}
        }
    } else {
        set custom(compChoice) GNU
    }
    if {[string mat GNU [PrefValue custom(compChoice) compChoice]]} {
        set compiler g++
        set possDirs {{}}
    }
    if {[info exists compiler]} {
        if {[llength [set execLoc [auto_execok $compiler]]]} {
            # compiler tools are in path, hope libs and includes are nearby
            set env(MSVCDIR) [file dirname [file dirname [lindex $execLoc 0]]]
        } else {
            foreach possDir $possDirs {
                if {[llength [auto_execok $possDir/bin/$compiler]]} {
                    break
                }
            }
            if {[llength $possDir]} {
                set env(MSVCDIR) [lindex $possdir 0]
            } else {
                ShowMessage "C++ compiler setup problem" warning \
                        "c++ compiler preference set to [PrefValue \
                        custom(compChoice) compChoice] but no executable $compiler found in command \
                        path or any of $possDirs" ok
                set custom(compChoice) none
            }
        }
    }
    foreach nodeType {normal generic compartment channel \
                variable function submodel flow influence \
                ghost_link relation} {
        ResetLooks $nodeType
    }
    CustomizeLooks
#    MakeHelperMenu
    
    # Bogosity alert -- setting an env var to {} causes it to stay
    # (or be) unset (in windows) otherwise lappend env(OPEN_MODEL)
    # would do here...
    if {[info exists env(OPEN_MODEL)]} {
        set openModel [brainwash $env(OPEN_MODEL)]
        # Add to path and recently opened files data
        RecordPathChoice .sml $openModel 1
    } else {
        set openModel {}
    }
    
    # Take the opportunity to pass the temp directory name etc to Prolog
    return [list $sendvars(simV) [brainwash $simtmpdir] \
            $openModel $userinfo(edn)]
}

# After the initial model has been loaded we don't want to allow the window
# to change size when something different is loaded
# This is also a convenient time at which to hide the console
# if it is showing

# If this is a slave interp, keep the OS choice of window posn, as moving it
# may well sit it exactly on top of the previous one

proc FixSize {c} {
    global custom openModel
    update idletasks
    set win [winfo parent $c]
    wm state $win normal
    # seems necessary for console to hide
    #    catch {console hide}
    if {[file exists $custom(prefDir)/layout]} {
        set stream [NetOpen $custom(prefDir)/layout r]
        gets $stream whetherMaxed
        #ShowMessage debug info $whetherMaxed ok
        catch {
            if {$whetherMaxed} {
                wm state $win zoomed
            } else {
                gets $stream oldGeom
                wm geometry $win $oldGeom
            }}
        close $stream
    }
    pack propagate $win 0
    update
    wm withdraw .
    if {[string match $openModel {}]} {
        DoRegDialog $win
    }
    
}

proc AlterModel {topNode} {
    global runState
    set runState($topNode,updated) 1
}

package require mime

proc SaveFile {topNode tree tgt} {
    #ShowMessage debug info "SaveFile $tree $tgt" ok
    global errorInfo
    global SimileProjectDo
    
    if {[info exists SimileProjectDo]} {
        SaveProjectFile $topNode $tree
        # shfs to $tree
        # spfs to $tree
        unset SimileProjectDo
    }
    if {[catch {
            set parts [GetParts $tree $tree]
            #ShowMessage debug info "SaveFile GetParts $tree" ok
	set runParams [GetRunParams $topNode]
            if {[llength $runParams]} {
                lappend parts [mime::initialize -canonical text/plain \
                        -header [list "Content-Description" "Run Status"] \
                        -string $runParams]
            }
            set multiT [mime::initialize -canonical multipart/mixed \
                    -parts $parts]
            set stream [NetOpen $tgt w]
            fconfigure $stream -translation binary
            mime::copymessage $multiT $stream
            # clean everything up
            close $stream
            mime::finalize $multiT -subordinates all
        } Lossage]} {
        return $errorInfo
    } else {
        return $Lossage
    }
}

proc LoadFile {topNode tree tgt} {
    global mimeSquirter errorInfo
    global loadingProject mimedir
    #ShowMessage debug info "LoadFile $tree $tgt" ok
    set CodeChecked no
    if {[catch {
            set multiT [mime::initialize -file $tgt]
            if {[catch {set intent [mime::getheader $multiT Readability]}]} {
                set intent standard
            }
            foreach bit [mime::getproperty $multiT parts] {
                set Desc [mime::getheader $bit Content-Description]
                #ShowMessage debug info $Desc ok
                switch [lindex $Desc 0] {
                    "Run Status" {
                        set runParams [mime::getbody $bit]
                        do_for_node $topNode SetRunParams $topNode $runParams
                    } "Authentication Code" {
                        set AuthCode [string trimright [mime::getbody $bit]]
                    } default {
                        if {[string match "Simile model" [lindex $Desc 0]] && \
                                    [info exists AuthCode]} {
                            check_auth_code $bit
                            set CodeChecked yes
                        }
                        set Disposition [mime::getheader $bit Content-Disposition]
                        if {![regexp \"(.*)\" $Disposition all oldPath]} {
                            set oldPath [lindex [lindex $Disposition 0] 1]
                        }
                        set newPath $tree$oldPath
                        file mkdir [file dirname $newPath]
                        set mimeSquirter [NetOpen $newPath w]
                        fconfigure $mimeSquirter -translation binary
                        mime::getbody $bit -command SquirtMime -blocksize 256
                        if {![catch {mime::getheader $bit Date-Modified} \
                                    Date]} {
                            file mtime $newPath [clock scan [lindex $Date 0]]
                        }
                    }
                }
            }
            #ShowMessage debug info "LoadFile after unpack\n[glob $tree/*]" ok
            # if there is a project file
            if {[file exists $tree/model.spj]} {
                #ShowMessage debug info "LoadFile file is package" ok
                set loadingProject 1
                set mimedir $tree
                #OpenProjectFile $tree
            }
        } Lossage]} {
        return $Lossage
    } else {
        return $CodeChecked
    }
}

#                model.spj {
#                    set PartType "application/x-simile"
#                    set Description "Simile project file"
#                    set style attachment
#               }

proc GetParts {top tree} {
    set mimes {}
    foreach subtree [glob -nocomplain ${tree}/*] {
        #ShowMessage debug info "GetParts subtree $subtree" ok
        if {[file isdirectory $subtree]} {
            set mimes [concat $mimes [GetParts $top $subtree]]
        } else {
            set ext [file tail $subtree]
            switch -glob $ext {
                *.gif {
                    set PartType "image/gif"
                    set Description "Image"
                    set style inline
                }
                *.jpeg {
                    set PartType "image/jpeg"
                    set Description "Image"
                    set style inline
                }
                model.pl {
                    set PartType "application/x-simile"
                    set Description "Simile model"
                    set style inline
                }
                model.cnv {
                    set PartType "application/x-simile"
                    set Description "Simile canvas description"
                    set style attachment
                }
                *.shf {
                    set PartType "application/x-simile"
                    set Description "Simile helper configuration file"
                    set style attachment
                }
                *.spf {
                    set PartType "application/x-simile"
                    set Description "Simile parameter file"
                    set style attachment
                }
                model.* {
                    set PartType "application/x-simile"
                    set Description "Data"
                    set style attachment
                } default {
                    set Description junk
                }
            }
            # when saving, save all relevant files from current level but only
            # program files for submodels -- everything else is included in top level
            if {[string equal Data $Description] || \
                        [string equal $top $tree] && \
                        ![string match junk $Description]} {
                set relPath [string range $subtree [string length $top] end]
                set Disposition "${style}; filename=\"$relPath\""
                set Date [clock format [file mtime $subtree] -gmt true]
                set newMime [mime::initialize -canonical $PartType \
                        -header [list "Content-Disposition" \
                        $Disposition] \
                        -header [list "Content-Description" \
                        $Description] \
                        -header [list "Date-Modified" $Date] \
                        -file $subtree]
                if {[string match "Simile model" $Description]} {
                    set HmacCode [get_auth_code $newMime]
                    set codeT [mime::initialize -canonical text/plain \
                            -header [list "Content-Description" \
                            "Authentication Code"] \
                            -string $HmacCode]
                    lappend mimes $codeT
                }
                lappend mimes $newMime
            }
            # cannot delete the component files yet, they will be accessed when the
            # main file is written
            #	    if {[string compare "Data" $Description]} {
            #		file delete $subtree
            #	    }
            
            # Debug: write the body to see if it's baaad...yes it was
            # Workaround: don't save anything as text/plain, stick to application/x-simile
            #	    set debugname ${subtree}.mim
            #	    set stream [NetOpen $debugname w]
            #	    fconfigure $stream -translation binary
            #	    mime::copymessage $newMime $stream
            #	    close $stream
        }
    }
    return $mimes
}

# Path names derived from Windows environment variables must be
# 'brainwashed' i.e., stripped of their native culture and turned
# into blank-faced Unix-style forward-slash-separated automata.
# Otherwise mingw gcc variably gets culture shock.

proc brainwash {ethnic} {
    return [file join [file dirname $ethnic] [file tail $ethnic]]
}

proc RaiseMREFor {win} {
    global window_info
    
    set node $window_info($win,top_node)
    do_if_running $node RaiseMREFor $node
}

proc FinishExec {win} {
    global window_info

    set oldCursor [$win cget -cursor]
    $win config -cursor watch
    set node $window_info($win,top_node)
    ScrubRun $node 1
    DestroyHelpers $node
    $win config -cursor $oldCursor
}

proc OpenAll {win} {
    global loadingProject mimedir
    MenuSelect $win file open
    if {[info exists loadingProject]} {
        OpenProjectFile $win $mimedir
    }
}

proc OpenProjectFile {win path} {
    global SimileProject loadingProject window_info
    set projectF [NetOpen $path/model.spj r]
    gets $projectF SimileProjectData
    close $projectF
    #ShowMessage debug info "open_all win $win; $SimileProjectData" ok
    array set SimileProject $SimileProjectData
    #ShowMessage debug info "open_all SimileProject(ModelFile) $SimileProject(ModelFile)" ok
    
    # if params it should load the spfs
    # MergeParams {smPath metaFile interactive}
    if {[info exists SimileProject(modelRunning)]} {
        if {[info exists SimileProject(running_c)]} {
            MenuSelect $win file run_c
        } else  {
            MenuSelect $win file run_tcl
        }
        if {[info exists SimileProject(nameOfHelperStateFile)]} {
            set command [ChooseText \
                    [PrefValue custom(helperManager) helperManager] \
                    ::RunEnv::LoadSHF CreateView]
            $command $window_info($win,top_node) \
                    ${path}/$SimileProject(nameOfHelperStateFile)
        }
    }
    unset loadingProject
}

proc SaveAll {win} {
    global SimileProjectDo
    #ShowMessage debug info "SaveAll win $win" ok
    set SimileProjectDo 1
    MenuSelect $win file save_as
}

proc SaveProjectFile {topNode path} {
    global custom runState nameOfHelperStateFile
    global SimileProject model_id
    #ShowMessage debug info "SaveProjectFile $path" ok
    # save any current spf names to the spj file
    # save any shf files names
    
    set ProjectFile $path/model.spj
    
    # is it builtC|builtTcl|notbuilt
    if {[HaveValues $topNode]} {
        set SimileProject(modelRunning) 1
        if {$model_id($topNode)} {
            set SimileProject(running_c) 1
        }
    }
    if {[info exists nameOfHelperStateFile($topNode)]} {
        file copy -force $nameOfHelperStateFile($topNode) $path
        set SimileProject(nameOfHelperStateFile) \
                [file tail $nameOfHelperStateFile($topNode)]
    }
    # shf file name loaded
    
    #ShowMessage debug info "SaveProjectFile [array get SimileProject]\n\
    #            $path/[file tail $nameOfHelperStateFile]" ok
    set projectF [NetOpen $ProjectFile w]
    puts $projectF [array get SimileProject]
    close $projectF
}



proc UnOrReDo {curWin fwd} {
    global window_info
    foreach win [array names window_info *,parent] {
        lappend canList '[lindex [split $win ,] 0]'
    }
    set curPos [lsearch $canList '$curWin']
    set canArgs [join $canList ,]
    if {$fwd} {
        prolog tk_redo($curPos,\[$canArgs\])
    } else {
        prolog tk_undo($curPos,\[$canArgs\])
    }
}

# I think the only reason for having this is to work around a Windows bug
# where the Prolog errors didn't come up properly...
proc DoWithErrors {args} {
    eval $args
    #    if [catch $args err] {
    #        bgerror $err
    #    }
}

# Export a postscript file from a window. Only the bit of the diagram showing in
# the viewport is included, and the output is in landscape mode, sized so 100
# pixels = 1 inch (so my beautiful 1152x864 screen will be about a sheet of A4)

proc ExportPostscript { winId } {
    set psfile [ChooseFile image.ps "Name of postscript file" 1]
    # check for cancel
    if {![string match */ $psfile]} {
        
        # force .ps extension
        if {[string compare [file extension $psfile] .ps]} {
            set psfile [file root $psfile].ps
        }
        SpitPS $winId $psfile
    }
}

proc PrepForExport {winId way} {
    global jiggles tcl_platform
    
    # now, zoom in by detail factor to get the line thickness resolution decent
    set detail 1.0
    # For font scale 1 seems right for Unix -- Windows takes about 1.6
    if {[string match windows $tcl_platform(platform)]} {
        set textBoost 1.6
    } else {
        set textBoost 1.0
    }
    set textscale [expr $detail*$textBoost]
    if {[string match there $way]} {
        if {[scan [$winId cget -scrollregion] "%g %g %g %g" sl st sr sb]<4} {
            set sl 0; set st 0
            set sr [winfo width $winId]; set sb [winfo height $winId]
        }
        set jiggles(bl) $sl
        set jiggles(bt) $st
        set jiggles(br) $sr
        set jiggles(bb) $sb
        
        set jiggles(sl) [lindex [$winId xview] 0]
        set jiggles(st) [lindex [$winId yview] 0]
        set xbase [expr [$winId canvasx 0]-$sl]
        set ybase [expr [$winId canvasy 0]-$st]
        $winId move all [expr -$sl] [expr -$st]
        # Don't bother moving the scrollregion, it will not be staying like this
        # -- actually we need to move it because print_widget scales to it
        $winId configure -scrollregion [list 0 0 \
                [expr $detail*($sr-$sl)] [expr $detail*($sb-$st)]]
        ZoomImage $winId all $detail $textscale
        return [list $xbase $ybase $detail]
    } else {
        ZoomImage $winId all [expr 1/$detail] [expr 1/$textscale]
        $winId configure -scrollregion [list $jiggles(bl) $jiggles(bt) \
                $jiggles(br) $jiggles(bb)]
        $winId xview moveto $jiggles(sl)
        $winId yview moveto $jiggles(st)
        $winId move all $jiggles(bl) $jiggles(bt)
    }
}

proc CopyCanvasToWindowsClipboard {canvas} {
    global tcl_platform
    
    if {[string match windows $tcl_platform(platform)]} {
        package require gdi
        package require printer
        package require wmf
        
        set hdc [wmf open]; #Opens a memory metafile
        printer::print_select $hdc $canvas withtag tocopy
        set wmfdc [ wmf close $hdc ]; # Turn the context into a metafile handle
        wmf copy $wmfdc; # Copy to the clipboard
    }
}

proc PrintNow {winId} {
    global simtmpdir tcl_platform
    
    if {[string match windows $tcl_platform(platform)]} {
        set oldDir [pwd] ;# apparently printing can change directory
        package require gdi
        package require printer
        
        # print routines still seem unable to handle negative coordinates so
        # put image through prep mech
        PrepForExport $winId there
        printer::print_widget $winId 0
        PrepForExport $winId back
        cd $oldDir
    } else {
        set tempPSFile $simtmpdir/temp.ps
        SpitPS $winId $tempPSFile
        if {[catch "exec $env(PRINTCMD) {[file nativename $tempPSFile]}" result]} {
            ShowMessage "Print command result" warning \
                    "Printing seems to have failed. \
                    The result returned by the print command was:
            
            $result
            
            Please see the online help to find out more about setting up printing from Simile. Alternatively you can export the model diagram as a PostScript file (use the File...Export menu command) and then print that using another package." ok
        }
        file delete $tempPSFile
    }
}

proc SpitPS {winId psfile} {
    scan [PrepForExport $winId there] "%g %g %g" xbase ybase detail
    set useWidth [winfo width $winId]
    set useHeight [winfo height $winId]
    
    $winId postscript -file $psfile -rotate true -pageanchor nw \
            -pagex 0 -pagey 0 -x [expr $detail*$xbase] -y [expr $detail*$ybase] \
            -width [expr $detail*$useWidth] -height [expr $detail*$useHeight] \
            -pagewidth [expr $useWidth/100.0]i -pageheight [expr $useHeight/100.0]i
    PrepForExport $winId back
}

proc InsertModel {winId} {
    set insertion [ChooseFile model.sml "Model file to insert" 0]
    if {![string match */ $insertion]} {
        Reopen $winId $insertion insert
    }
}

proc Reopen {canvas oldFile op} {
    global custom userinfo welcomeDone
    
    if [winfo exists .register] {
        set userinfo(done) $welcomeDone
    }
    
    RecordPathChoice .sml $oldFile 1
    set custom(hotlist) [linsert $custom(hotlist) 0 $oldFile]
    MenuSelect $canvas $op $oldFile
    global loadingProject mimedir
    if {[info exists loadingProject]} {
        OpenProjectFile $canvas $mimedir
    }
}

menu .openrecent -tearoff 0

proc FillReopen {winId} {
    global custom
    .openrecent delete 0 end
    set posted {}
    foreach hottie $custom(hotlist) {
        if {[llength $posted] >= [PrefValue custom(recentCount) recentCount]} {
            break
        }
        if {[file exists $hottie] && [lsearch $posted $hottie]==-1} {
            .openrecent add command -label [file tail $hottie] \
                    -command [list Reopen $winId.canvas $hottie reopen]
            lappend posted $hottie
        }
    }
}

proc Rerun {winId go} {
    global runState window_info
    
    set node $window_info($winId,top_node)
    if {![HaveValues $node] || \
                $runState($node,updated) == 1} {
        if {[info exists runState($node,lang)]} {
            set runType run_$runState($node,lang)
        } else {
            set runType run_tcl
        }
        MenuSelect $winId file $runType
    } else {
        StartRun $node
        # assume if model was running before it will run again
    }
    # Only proceed if it worked
    if {[HaveValues $node]} {
        return fail
    }
    if {$go} {
        StartNow $node start
    }
    return yes
}

proc UpdateAbility {c what where which whether} {
    global window_info
    set winId $window_info($c,parent)
    set newState [ChooseText $whether normal disabled]
    ${winId}top.$where entryconfigure $which -state $newState
    AcceleratorState $winId $where $which $newState
    if {![string equal none $what]} {
        set navBar $winId.toolSlot.navbar
        $navBar.$what configure -state $newState
    }
}

proc ToggleIOToolMenu {node} {
    global window_info custom model_id
    
    foreach win [array names window_info *,top_node] {
        if {[string equal $node $window_info($win)]} {
            set c [string range $win 0 end-9]
            set winData $window_info($c,parent)
            
            set topMenu ${winData}top
            catch {$topMenu delete "I/O tools"}
            $winData.toolSlot.navbar.runenv configure -state disabled
            if {[HaveValues $node]} {
                set newState normal
                if {[PrefValue custom(helperManager) helperManager]} {
                    $winData.toolSlot.navbar.runenv configure -state normal
                } else {
		    if {![winfo exists $topMenu.helpers]} {
			set menuSpec [do_in_node $node ListMenuContents .helpers]
			ReconstituteMenu $topMenu.helpers $menuSpec $node
		    }
                    $topMenu insert "Help" cascade -label "I/O tools" \
                            -underline 0 -menu $topMenu.helpers
                }
            } else {
                set newState disabled
            }
            $winData.toolSlot.toolbar.snap configure -state $newState
            $topMenu.tools entryconfigure {Inspect elements} -state $newState
        }
    }
}

proc InterpMenu {winId state} {
    global sendvars
    set sendvars(boxsize) 240
}

#initialize this variable, any button will do (if it is sunken)

set pushedbutton select

proc ModeSelect {modes} {
    global pushedbutton MIpushedbutton
    UpdateToolbars $modes
    set pushedbutton $modes
    set MIpushedbutton $modes
    prolog [list tk_mode_select( $modes )]
}

proc ItemSelect {newItem} {
    global adds
    global pushedbutton MIpushedbutton
    set adds $newItem
    UpdateToolbars $newItem
    set pushedbutton $newItem
    set MIpushedbutton $newItem
    prolog [list tk_menu_select( $newItem , from_box)]
}

# Change indentation of toolbar buttons. Apply in all desktop windows
# ie. those not in helper list

proc UpdateToolbars {newAction} {
    global pushedbutton window_info tcl_platform
    #puts "UpdateToolbars $pushedbutton $newAction"
    foreach winData [array name window_info *,parent] {
        set toolBar $window_info($winData).toolSlot.toolbar
        $toolBar.$pushedbutton configure -state normal
        $toolBar.$newAction configure -state active
        $toolBar.$pushedbutton configure -relief flat
        $toolBar.$newAction configure -relief sunken
        ResetEqnBar $window_info($winData).toolSlot.eqnbar
    }
}

proc ResetEqnBar {bar} {
    $bar.equation delete 0 end
    $bar.label configure -text {}
    SetEqnButtonState $bar disabled
}

proc SetEqnButtonState {bar newState} {
    foreach eqnButton {equation tick cross inputs function} {
        $bar.$eqnButton configure -state $newState
    }
}

proc RaiseModelWindow {node} {
    set win [FindNodeTopWin $node]
    wm deiconify $win
    raise $win
}

proc FindNodeTopWin {node} {
    global window_info
    foreach {key win} [array get window_info *,parent] {
        set c [string range $key 0 end-7]
        if {[string equal $node $window_info($c,top_node)] && \
                    [info exists window_info($c,is_top_level)]} {
            return $win
        }
    }
}

##############################    Formula bar    #############################

proc accept_equation {winId text} {
    
    global equation
    global equationbar
    
    set equationbar(current_action) tick
    set equationbar(equation) [string trimright [$text get]]
    set node $equationbar($winId,node)
    prolog [list tk_click_obj('$winId.canvas',  doubleclick, 0 , 0 , $node, 0)]
    focus $winId.canvas
}

proc AddInputs {winId bar} {
    global equationbar
    $bar.inputs.menu delete 0 end
    set node $equationbar($winId,node)
    set paramData [GetFromProlog tk_get_params('$winId',$node)]
    foreach paramList $paramData {
        set paramName [lindex $paramList 1]
        $bar.inputs.menu add command -label $paramName \
                -command [list InsertParam $bar $paramName]
    }
    MenuBindPopup $bar.inputs.menu $paramData
}

proc InsertParam {bar paramName} {
    
    $bar.equation insert insert $paramName
    focus $bar.equation
}

proc restore_equation {winId bar} {
    global equationbar
    $bar.equation delete 0 end
    $bar.equation insert end $equationbar($winId,initText)
    focus $bar.equation
}

##############################    Formula bar    #############################


proc GetTransValues {topNode node} {
    global runState
    
    set value [GetCompProperty $topNode Value $node]
    if {![string match novalue $value]} {
        set trans [GetTransTable $node]
        return [TransEnums $trans [lindex $value 0]]
    } else {
        return novalue
    }
}

proc RecordPathChoice {fileType chosenFile recordEntry} {
    global chosenPaths custom
    set chosenPaths($fileType) \
	    [set chosenPaths(latest) [file dirname $chosenFile]]
    if {$recordEntry} {
	set custom(hotlist) [linsert $custom(hotlist) 0 $chosenFile]
    }
}

proc GetPathChoice {fileType} {
    global chosenPaths custom
    set egDir $custom(prefDir)/Examples
    if {[info exists chosenPaths($fileType)]} {
	return $chosenPaths($fileType)
    } elseif {[info exists chosenPaths(latest)]} {
	return $chosenPaths(latest)
    } elseif {[info exists $egDir]} {
	return $egDir
    } else {
	return [pwd]
    }
}
