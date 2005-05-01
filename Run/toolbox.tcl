# Simile source code file: Run/toolbox.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file loads all procedures, and sets up the model building environment.
#
package require BWidget
catch {namespace import BWidget::*}
package require tile

source ../Run/window.tcl
source ../Run/shapes.tcl
source ../Run/forms.tcl
source ../Run/equation.tcl
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
#   set tempDir $env(TEMP)
#    } else {
#   if {[string match windows $tcl_platform(platform)]} {
#       set tempDir /temp
#   } else {
#       set tempDir /tmp
#   }
#    }
#}

# Test new Windows printing technology -- see file for credits/licence
if {[string match windows $tcl_platform(platform)]} {
    #    set tempDir [file attributes $tempDir -shortname]
    #    set tempDir [file join [file dirname $tempDir] [file tail $tempDir]]
    
    #   pkg_mkIndex ../System/lib/Extras
    source ../System/lib/Extras/prntcanv.tcl
    source ../System/lib/Extras/prntproc.tcl
    
    # Make Simile a DDE server under Windows. Jonathan autotesting
    # Must be after the sourcing or Simile fails
    package require dde 1
# after idle speeds startup with tcltk 8.5
    after idle dde servername Simile
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
    MenuSelect dummy open_toplevel [brainwash $model]
    #    set newInstance [interp create]
    #    $newInstance eval package require Tk
    #    $newInstance eval set argc 1
    #    $newInstance eval [list set argv $model]
    #    $newInstance eval source ../Run/simile.tcl
}

proc AttackGlobalVariable {array elt val} {
    global $array
#puts "Setting $array$elt to $val"
    set $array$elt $val
    return ;# because letting it return an array causes a crash
}

# Prolog typically called this to make error handling prettier

# proc FilterErrors {args} {
#     global errorInfo
#     set oldDir [pwd]
#     if {[catch $args retVal]} {
#         set ans [ShowMessage "Simile error" error "Simile encountered an unexpected problem:\n $retVal \nDo you want to see more information?" yesno]
#         if {[string match yes $ans]} {
#             BuildProblem "User interface problem" error $errorInfo execution \
#          unsaved none
#         }
#         cd $oldDir
#         return -1
#     } else {
#         return $retVal
#     }
# }

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
        #   foreach file [glob -nocomplain ${prefx}*] {
        #       if {![string match ${prefx}.* $file]} {
        #       file delete $file
        #       }
        #   }
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
            return [list 4 $func <unknown>] ;# missing function declaration
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
                    return [list 3 $func $file] ;# Missing or misplaced definition
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

# set this to exec or open depending on what command is used to start the
# execution process -- must be open if pipes are used
set runHow(launch) open

# set this to interactive or script, for how to do the initialization
set runHow(init) script

# set this to send or pipe, for the way to pass data to the exec
# process send must be async because a sync send will not allow
# callbacks to be handled note that if init is interactive this cannot
# be send because there is no way to set the exec process's
# application name
set runHow(call) pipe

# set this to send_sync, send_async or pipe, for the way to get data from
# the exec process
if [string match Darwin $tcl_platform(os)] {
  set runHow(return) pipe
} else {
  set runHow(return) send_sync
}

# Set this to await_cmd or get_data to decide how the exec process
# expects to get commands. It only makes a difference if call is pipe
# -- otherwise the exec gets commands directly anyway. If return is
# pipe it must be get_data because it cannot process another command
# from stdin while waiting for the last one to finish. Also if init is
# script it must be get_data because the process does not accept
# commands from stdin after initializing from a script.
set runHow(readpipe) get_data

# this is obsolete and must be 'parallel'
set runHow(time) parallel

# this exists in case I don't want to exploit the concat in eval
proc do_for_node {node args} {
    global runState tcl_platform runHow simtmpdir

    if {![info exists runState($node,interp)]} {
	if {[string equal interp $runHow(call)]} {
	    set runState($node,interp) [interp create]
	    $runState($node,interp) eval set runHow $runHow(return)
	    $runState($node,interp) eval source ../Run/support.tcl
	} else {
	    scan [info tclversion] {%d.%d} MAJ MIN
	    if {[string equal windows $tcl_platform(platform)]} {
		set sep {}
	    } else {
		set sep .
	    }
            if [string match Darwin $tcl_platform(os)] {
		set makeExec ../../MacOS/Simile
		#              catch {file rename ../Scripts/AppMain.tcl ../Scripts/AppMain.hide}
            } else {
		set makeExec ../System/bin/wish$MAJ$sep$MIN
            }
            set srcLoc ../Run/runmodel.tcl          
	    if {![info exists runHow(sendCmd)]} { ;# fix debug env
		set runHow(sendCmd) [list send [tk appname]]
	    }
	    set scArgs [list $node $simtmpdir $runHow(sendCmd) $runHow(return) \
			    $runHow(readpipe)]
	    if {[string equal script $runHow(init)]} {
		set launchArgs [concat $srcLoc $scArgs]
	    } else {
		set launchArgs {}
	    }
	    if {[string equal open $runHow(launch)]} {
		set runState($node,interp) \
		    [open [concat |$makeExec $launchArgs] r+]
	    } else {
		set runState($node,interp) \
		    [eval exec $makeExec $launchArgs &]
	    }
	    if {[string equal pipe $runHow(return)]} {
		fileevent $runState($node,interp) readable \
		    [list FeedModel $node pipe]
	    }
	    if {[string equal interactive $runHow(init)]} {
		tell_runner $node [list set argv $scArgs]
		tell_runner $node [list source $srcLoc]
	    }
	    tkwait variable runState($node,modelReady)
	    #tk_messageBox -message "Go! mr is '$runState($node,modelReady)'"
            if [string match Darwin $tcl_platform(os)] {
		#              catch {file rename ../Scripts/AppMain.hide ../Scripts/AppMain.tcl}
		#      carbon::processHICommand hide {}
            }
	    set runState($node,queueSize) 0
	}
	tickle $node
	if {[info exists runState($node,runParams)]} {
	    do_in_node $node SetRunParams $node $runState($node,runParams)
	}
	RaiseModelWindow $node
    }
    return [eval do_in_node $node $args]
}

# experimental way to stop hangs -- this does something in the execution process and
# does it again as long as it works

proc tickle {node} {
    global runState
    if {![catch {do_in_node $node expr 1}]} {
    after 1000 tickle $node
    }
}

# the 'queue' is necessary because threads stopped by tkwait variable must
# be re-started in the reverse order they were stopped. This means that if
# one call gets a result while another is waiting to start, the second must be
# started -- and finished -- before the first can use its result.

proc do_in_node {node args} {
    global runState runHow

    set command [list do $args]
    if {[string equal interp $runHow(call)]} {
    set result [$runState($node,interp) eval $command]
    } else {
    if {[string equal parallel $runHow(time)]} {
        while {!$runState($node,modelReady)} {
        tkwait variable runState($node,modelReady)
        }
    }
    if {$runState($node,modelReady)==1} {
    tell_runner $node $command
    incr runState($node,queueSize)
#puts "put: $command"
    set runState($node,modelReady) 0
    upvar \#0 runState($node,response$runState($node,queueSize)) result
    if {[string equal parallel $runHow(time)]} {
        tkwait variable \
        runState($node,response$runState($node,queueSize))
    } else {
        fileevent $runState($node,interp) readable {}
        while {!$runState($node,modelReady)} {
        FeedModel $node pipe
        }
        fileevent $runState($node,interp) readable \
        [list FeedModel $node pipe]
    }
#puts "Got $result"
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

proc FeedModel {node incoming} {
    global runState errorInfo

    if {[string equal pipe $incoming]} {
	gets $runState($node,interp) incoming_lines
        set incoming [join $incoming_lines \n]
    }
#puts "Received \"$incoming\" from $node exec"
    if {[string equal get [lindex $incoming 0]]} {
    if {[catch [lindex $incoming 1] response]} {
        set result [list err [split $errorInfo \n]]
    } else {
        set result [list res $response]
    }
    tell_runner $node $result
#   eval $runHow(sendOp) exec_for_$node {$result}
    } else {
    set runState($node,modelReady) 1
    set runState($node,response$runState($node,queueSize)) $incoming
    }
}

proc KillInterpFor {node} {
    global runState runHow
    if {[info exists runState($node,interp)]} {
    if {[string equal interp $runHow(call)]} {
        interp delete $runState($node,interp)
    } else {
#       tell_runner $node {wm deiconify .}
#       do_in_node $node exit_exec    
#       tell_runner $node exit
        TryToKill $node
        if {[string equal pipe $runHow(call)]} {
#       gets $runState($node,interp)
#       close $runState($node,interp)
        }
    }
#       unset runState($node,interp)
    }
}

proc tell_runner {node action} {
    global runState runHow
#puts "Sending \"$action\" to $node exec"
    if {[string equal pipe $runHow(call)]} {
	if {[string equal get_data $runHow(readpipe)]} {
	    set action [split $action \n] ;# command must be on one line
	}
	puts $runState($node,interp) $action
	flush $runState($node,interp)
    } else {
	eval $runHow(sendOp) -async exec_for_$node {after idle [list $action]}
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
    global runState runHow
#puts "Trying to kill $node"
    if {[info exists runState($node,interp)]} {
    if {[string equal open $runHow(launch)]} {
        c_killmodel [pid $runState($node,interp)]
        catch {close $runState($node,interp)}
    } else {
        c_killmodel $runState($node,interp)
    }
    unset runState($node,interp)
    }
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

proc load_dll {topNode lang progDir id node incs} {
    do_for_node $topNode load_dll $topNode $lang $progDir $id $node $incs
}

proc compile_c {workingDir} {
    global tcl_platform env

    CheckCompilerLocation
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
    if {[catch {switch $tcl_platform(platform) {
        unix {
            if {[string match Darwin $tcl_platform(os)]} {
                exec g++ -fPIC -c -O -I$TOOLDIR -o objtemp.o model.cpp
                exec g++ -bundle -o $TARGET objtemp.o
            } else {
                exec g++ -fPIC -c -O -I$TOOLDIR -o objtemp.o model.cpp
                exec g++ -shared -o $TARGET objtemp.o
            }
        }
        windows {
            set TOOLDIR [file attributes $TOOLDIR -shortname]
        switch [PrefValue custom(compChoice) compChoice] {
            GNU {
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
            } Default {
        set batSt [open runmingw.bat w]
        puts $batSt "set PATH=[file nativename [file join [file join \
                        [file dirname $TOOLDIR] System] bin]]"
        puts $batSt "g++ -c -o objtemp.o -I$TOOLDIR -I. model.cpp"
        puts $batSt "dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtemp.o"
        close $batSt
        exec runmingw.bat
        file delete runmingw.bat
                file delete exptemp.exp

                # Method using command line calls to MSVC 4.0 or later -- works well
            } Microsoft {
                set TOOLS32 [file dirname $env(MSVCDIR)/bin]
                exec $TOOLS32/bin/cl.exe -Ox -c -W1 -nologo \
                        -DWIN32 -D_WIN32 -D_DLL -D_X86_=1 \
                        -I. -I$TOOLS32/include -I$TOOLDIR \



                        -Foobjtemp.o model.cpp

                exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO \
                        -align:0x1000 /MACHINE:IX86 \
                        -entry:_DllMainCRTStartup@12 -dll -out:$TARGET \
                        $TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib \
                        $TOOLS32/lib/oldnames.lib objtemp.o
        }}
            # Method using command line calls to Borland C++ 4.0 or later -- not finished

            #   set TOOLS32 "c:/program files/borland/cbuilder4"
            #   exec $TOOLS32/bin/bcc32.exe -Ox -c -nologo -o$object \
            #       -DWIN32 -D_WIN32 -D_DLL -D_X86_=1 -DMODELCODE="$c_prog" \
            #       -I. -I$TOOLS32/include -I$TCL/include $TOOLDIR/support.cpp



            #   exec $TOOLS32/bin/ilink32.exe -Tpd $object $TARGET $TCL/lib/tcl${MAJ}${MIN}.lib
            # Method using MSVC's auto-generated Make file -- hangs for some
            # reason

            #   exec $TOOLS32/bin/nmake $TOOLDIR/amemodel/amemodel.mak
            #   file rename $TOOLDIR/amemodel/debug/amemodel.dll $TARGET

        }
    }} chuckup]} {
      set badCompile "The compiler raised a problem with the code generated for this model. This might be due to a bad compiler setup, or it could be due to mathematical problems in the model. The error was: $chuckup. It may help to try the 'Debug' option."
      cd $oldDir; #Change back to Run directory in order to access Help file for subsequent dialogue
      BuildProblem "Problem during compilation" warning $badCompile execution
      cd $workingDir
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

proc UpdateExecution {node action} {
    Rerun [FindNodeTopWin $node].canvas [string equal start $action]
}
# Not clear why this need only be set on MacOS, but it seems to work without on other platforms
# so no sense in tinkering.  Probably because of different auto_path setting mechanisms.
if [string match Darwin $tcl_platform(os)] {
  set env(ITCL_LIBRARY) [pwd]/../System/lib/itcl3.3
}
package require Itcl
itcl::class ModelWindowExtn {
    variable winId
    constructor {awinId} {
        set winId $awinId
    }
}

proc LoadModelWindowExtensions {} {
    set origDir [pwd]
    cd ../Extensions
    #tk_messageBox -message "LoadModelWindowExtensions pwd [pwd]" -type ok
    set extensionList [glob -nocomplain *.tcl]
    foreach extension [lsort $extensionList] {
        if [catch {source $extension} wibble] {
            ShowMessage "Error loading Extension" warning \
                    "Extension [pwd]/$extension had a $wibble" ok
        }
    }
    cd $origDir
}

proc ControlDraw {prologVersion} {
    global sendvars custom tcl_platform env userinfo openModel simtmpdir
    
    LoadIconImages
    
    # Defaults to use if debugging
    if {![info exists env(SIMILE_VERSION)]} {
        set env(SIMILE_VERSION) 4.3
        set env(licensee_name) "Support team"
        set env(licensee_corp) "Simulistics Ltd"
        set env(license_code) default_license=fa4c55b7105171de89d44c78a33cdc28
    }
    
    set sendvars(simV) $env(SIMILE_VERSION)
    set sendvars(proV) $prologVersion
    
    # no longer have a separate floating toolbar
    
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
            file rename $oldPrefs/$sysB $custom(prefDir)/.$sysB
            }
            foreach subD [glob $oldPrefs/*] {
            file rename $subD $custom(prefDir)/[file tail $subD]
            }
            file delete $oldPrefs
        }
        }
    } elseif [string match Darwin $tcl_platform(os)] {
        set custom(prefDir) [file join $env(HOME) "Simile"]
    } else {
        set custom(prefDir) $oldPrefs
    }
    } else {
        set custom(prefDir) [pwd]/../Prefs
    }
    
    if {[file exists $custom(prefDir)/.version]} {
        set UserStream [NetOpen $custom(prefDir)/.version r]
        gets $UserStream userinfo(oldname)
        gets $UserStream userinfo(oldcorp)
        gets $UserStream userinfo(oldVersion)
        gets $UserStream userinfo(done)
        close $UserStream
    } else {
        set userinfo(oldVersion) 0
        set userinfo(done) 0
    }

    if {[string match Linux $tcl_platform(os)]} {
    set shank ../System/lib/lib5d.so
    if {$sendvars(simV)>$userinfo(oldVersion) || ![file exists $shank]} {  
        exec g++ -c -O -fPIC -I. ./shank.cpp
        exec g++ -shared -o $shank shank.o
    }
    }
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
            #       ShowMessage "Expiry imminent" warning "This version of Simile will expire on [clock format $expTime]. Please contact www.simulistics.com for an update." ok
            ShowExpiryImminent $expTime

        }
    }
    
    set simtmpdir $custom(prefDir)/sim
    set go [clock clicks]
    while {[file exists $simtmpdir]} {
        set guess_free [expr [clock clicks]-$go]
        set simtmpdir $custom(prefDir)/sim$guess_free
    }

    if {![file exists $custom(prefDir)]} {
        file mkdir $custom(prefDir)
    }
    file mkdir $simtmpdir

    set UserStream [NetOpen $custom(prefDir)/.version w]
    puts $UserStream $userinfo(name)
    puts $UserStream $userinfo(corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream
    
    set sendvars(running) 0
    
    set custom(hotlist) {}
    if {[file exists $custom(prefDir)/.recent]} {
        set cacheStream [NetOpen $custom(prefDir)/.recent r]
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
    
    Pref_Init $custom(prefDir)/.prefs
    Pref_Add {  {custom(initNavbar) initNavbar ON "Tool bar"} \
                {custom(initToolbar) initToolbar ON "Component bar"} \
                {custom(initEqnbar) initEqnbar ON "Equation bar"} \
                {custom(initGrid) initGrid ON "Grid"} \
                {custom(bigButtons) bigButtons OFF "Use large buttons"} \
                {custom(saveExtras) saveExtras {CHOICE {Model file only} {Canvas file}} "Save models as..."} \
                {custom(recentCount) recentCount 10 "Entries on recently used file list"} \
                {custom(gridSnap) gridSnap OFF "Snap to grid"} \
                {custom(defBackground) defBackground {CHOICE White Clear} "Default background"} \
                {custom(flowRouting) flowRouting ON "Rectilinear flow routing"} \
                {custom(deleteEndToEnd) deleteEndToEnd ON "Select links end-to-end"} \
                {custom(helperManager) helperManager ON "Use single window manager"} \
                {custom(runControlPosition) runControlPosition "+0-20" "Position of run control"} \
                {custom(slidersPosition) slidersPosition "+0+0" "Position of sliders"} \
                {custom(hackBreak) hackBreak OFF "Pause to edit C++ code?"} \
    }
    if [string match Darwin $tcl_platform(os)] {
        Pref_Add {  {custom(popupHelp) popupHelp OFF "Popup help text"} \
                    {custom(compDescPop) compDescPop OFF "Equation"} \
                    {custom(compValPop) compValPop OFF  "Value"} \
                    {custom(compCmtPop) compCmtPop OFF  "Comment"} \
        }
    } else {
        Pref_Add {  {custom(popupHelp) popupHelp ON "Popup help text"} \
                    {custom(compDescPop) compDescPop ON "Equation"} \
                    {custom(compValPop) compValPop ON  "Value"} \
                    {custom(compCmtPop) compCmtPop ON  "Comment"} \
        }
    }
    if {[string match windows $tcl_platform(platform)]} {
        Pref_Add {  {custom(compChoice) compChoice {CHOICE Default Microsoft GNU} \
                        "Use which C++ compiler?"} \
    }
    file attributes $simtmpdir -hidden true
    file attributes $custom(prefDir)/.version -hidden true
    }
    CheckCompilerLocation
#    MakeHelperMenu
    LoadModelWindowExtensions
    
    # Bogosity alert -- setting an env var to {} causes it to stay
    # (or be) unset (in windows) otherwise lappend env(OPEN_MODEL)
    # would do here...
    if {[info exists env(OPEN_MODEL)]} {
        set openModel [brainwash $env(OPEN_MODEL)]
        # Add to path and recently opened files data


        RecordPathChoice .sml $openModel 1
    } else {
        set openModel [lindex [glob -nocomplain $custom(prefDir)/*.smx] 0]
# if there are any logfiles from unsaved models, pick one
    }
    
    # Base window has menu to display on Mac when no model windows open
    menu .hitop
    frame .hi
    . config -menu .hitop	
    AddMainMenu .hi _ 0 1 {}

    # Take the opportunity to pass the temp directory name etc to Prolog
    return [list $sendvars(simV) [brainwash $simtmpdir] \
            $openModel $userinfo(edn)]
}

proc CheckCompilerLocation {} {
    global tcl_platform custom env
    if {[string match windows $tcl_platform(platform)]} {
        if {[string mat Microsoft [PrefValue custom(compChoice) compChoice]]} {
            set compiler cl.exe
            set possDirs {}
            if {[info exists env(MSVCDIR)]} {
                set possDirs [split $env(MSVCDIR) \;]
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
                set env(MSVCDIR) $possDir
            } else {
                ShowMessage "C++ compiler setup problem" warning \
                        "c++ compiler preference set to [PrefValue \
                        custom(compChoice) compChoice] but no executable $compiler found in command \
                        path or any of $possDirs" ok
                set custom(compChoice) none
            }
        }
    }
}

# After the initial model has been loaded we don't want to allow the window
# to change size when something different is loaded
# This is also a convenient time at which to hide the console
# if it is showing

# If this is a slave interp, keep the OS choice of window posn, as moving it
# may well sit it exactly on top of the previous one

proc FixSize {c} {
    global custom openModel whatCalled
    update idletasks
    set win [winfo parent $c]
    wm state $win normal
    # seems necessary for console to hide
    #    catch {console hide}
    if {[file exists $custom(prefDir)/.layout]} {
        set stream [NetOpen $custom(prefDir)/.layout r]
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

    destroy .splash
    if {[string match $openModel {}] && \
	    ![string equal SimileScript $whatCalled]} {
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
    global errorInfo runState

    global SimileProjectDo
    
    if {[info exists SimileProjectDo]} {
        SaveProjectFile $topNode $tree $tgt
        # shfs to $tree
        # spfs to $tree
        unset SimileProjectDo
    }
    if {[catch {
	set parts [GetParts $tree $tree]
	#ShowMessage debug info "SaveFile GetParts $tree" ok
	if {[info exists runState($topNode,runParams)]} {
	    lappend parts [mime::initialize -canonical text/plain \
			   -header [list "Content-Description" "Run Status"] \
			   -string $runState($topNode,runParams)]
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
    global mimeSquirter errorInfo runState
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
                        set runState($topNode,runParams) [mime::getbody $bit]
# do next bit when starting exec proc
#                        do_for_node $topNode SetRunParams $topNode $runParams
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
                set loadingProject [list $topNode $tgt]
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
                set Date [clock format [file mtime $subtree] \
                  -format "%Y-%m-%d %T %Z" -gmt true]
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
            #       if {[string compare "Data" $Description]} {
            #       file delete $subtree
            #       }
            
            # Debug: write the body to see if it's baaad...yes it was
            # Workaround: don't save anything as text/plain, stick to application/x-simile
            #       set debugname ${subtree}.mim
            #       set stream [NetOpen $debugname w]
            #       fconfigure $stream -translation binary
            #       mime::copymessage $newMime $stream
            #       close $stream
        }

    }
    return $mimes
}

proc RecordRunParams {node paramList} {
    global runState
    set runState($node,runParams) $paramList
    prolog tk_run_settings_tweaked($node)
}

proc ConvertSSxml {} {
    global simtmpdir
    package require xslt
    package require mime

    set importSrc [ChooseFile spreadsheet.xml "Import spreadsheet from:" 0]
    set mm1 [mime::initialize -canonical application/x-xml -file $importSrc]
    set XML [mime::getbody $mm1]
    set source_doc [::dom::libxml2::parse $XML]
    set mm2 [mime::initialize -canonical application/x-xml \
         -file ../Run/xml2pl01.xsl]
    set XSLstylesheet [mime::getbody $mm2]
    set ssheet_doc [::dom::libxml2::parse $XSLstylesheet]
    set ssheet [::xslt::compile $ssheet_doc]
    set result_doc [$ssheet transform $source_doc]
    set result_xml [::dom::libxml2::serialize $result_doc \
            -method [$ssheet cget -method]]
    set importDest [NetOpen [file join $simtmpdir ss_decls.pl] w]
    puts $importDest [regsub -all {\[\.([^\]]+)\]} $result_xml {'\1'}]
    close $importDest
}

# Prolog may need some help recognizing Tcular number formats...

proc EatNumber {str} {
    if {[scan $str %g%n floatVal floatSize]} {
    if {[scan $str %d%n intVal intSize]} {

        if {$intSize == $floatSize} {
        return [list $intVal $intSize]
        }
    }
    return [list [format %\#.8g $floatVal] $floatSize]
    }
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
    MenuSelect $win file open
    RunIfPackage
}

proc RunIfPackage {} {
    global loadingProject mimedir
    if {[info exists loadingProject]} {
        OpenProjectFile $mimedir
    }
}

proc OpenProjectFile {path} {
    global SimileProject loadingProject window_info
    set pFile [file join $path model.spj]
    set projectF [NetOpen $pFile r]
    gets $projectF SimileProjectData
    close $projectF
    file delete $pFile
    #ShowMessage debug info "open_all win $win; $SimileProjectData" ok
    array set SimileProject $SimileProjectData
    #ShowMessage debug info "open_all SimileProject(ModelFile) $SimileProject(ModelFile)" ok
    
    # if params it should load the spfs
    # MergeParams {smPath metaFile interactive}
    if {[info exists SimileProject(modelRunning)]} {
    set topNode [lindex $loadingProject 0]
    set win [FindNodeTopWin $topNode].canvas
#puts "win $win topNode £topNode"
    if {[info exists SimileProject(spfList)]} {
        # file params cannot be loaded until model is ready, so set this
        # variable which will be read before opening the dialogue
        set baseDir [file dirname [lindex $loadingProject 1]]
        foreach {smPath spfRelPath} $SimileProject(spfList) {
        do_for_node $topNode set ::projectParams($smPath) \
            [file join $baseDir $spfRelPath]
        }
    }
        if {$SimileProject(running_c)} {
            MenuSelect $win file run_c
        } else  {
            MenuSelect $win file run_tcl
        }
    update
        if {[info exists SimileProject(nameOfHelperStateFile)]} {
            set command [ChooseText \
                    [PrefValue custom(helperManager) helperManager] \
                    ::RunEnv::LoadSHF CreateView]
            do_in_node $topNode $command $topNode \
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

proc SaveProjectFile {topNode path tgt} {
    global custom runState nameOfHelperStateFile
    global SimileProject model_id
#puts [array get nameOfHelperStateFile]
    #ShowMessage debug info "SaveProjectFile $path" ok
    # save any current spf names to the spj file
    # save any shf files names
    
    set ProjectFile $path/model.spj
    array unset SimileProject
    
    # is it builtC|builtTcl|notbuilt
    if {[HaveValues $topNode]} {
        set SimileProject(modelRunning) 1
    set SimileProject(running_c) [string equal c $runState($topNode,lang)]
    }
    if {[info exists nameOfHelperStateFile($topNode)]} {
    if {![string equal $path \
          [file dirname $nameOfHelperStateFile($topNode)]]} {
        file copy -force $nameOfHelperStateFile($topNode) $path
    }
        set SimileProject(nameOfHelperStateFile) \
                [file tail $nameOfHelperStateFile($topNode)]
    }
    # shf file name loaded
    
    #ShowMessage debug info "SaveProjectFile [array get SimileProject]\n\
    #            $path/[file tail $nameOfHelperStateFile($topNode)]" ok
    set spfList [do_in_node $topNode array get ::SimileProject fileparam,*]
    foreach {varName spfPath} $spfList {
    lappend SimileProject(spfList) [string range $varName 10 end] \
        [Relativize $tgt $spfPath]
    }
    set projectF [NetOpen $ProjectFile w]
    set statLine [array get SimileProject]
    puts $projectF $statLine
    close $projectF
}

proc UnOrReDo {curWin fwd} {
    global window_info
    foreach win [array names window_info *,parent] {
        set spareWin [lindex [split $win ,] 0]
    if {[string equal $window_info($spareWin,top_node) \
         $window_info($curWin,top_node)]} {
        lappend canList '$spareWin'
    }
    }
    set curPos [lsearch $canList '$curWin']
    set canArgs [join $canList ,]
    if {$fwd} {
        prolog tk_redo($curPos,\[$canArgs\])
    } else {
        prolog tk_undo($curPos,\[$canArgs\])
    }
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

proc PrintNow {winId} {
    global simtmpdir env tcl_platform
    
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
    RunIfPackage
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
    update idletasks
}

proc Rerun {winId go} {
    global runState window_info
    
    set node $window_info($winId,top_node)
    if {![HaveValues $node] || \
                $runState($node,updated) == 1} {
        if {[info exists runState($node,lang)]} {
            set runType run_$runState($node,lang)
        } else {
            set runType run_c
        }

        MenuSelect $winId file $runType
    } else {
        do_in_node $node StartRun $node
        # assume if model was running before it will run again
    }
    # Only proceed if it worked
    if {![HaveValues $node]} {
        return fail
    }
    if {$go} {
        do_in_node $node StartNow $node start
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
    global window_info custom model_id tcl_platform
    
    foreach win [array names window_info *,top_node] {
        if {[string equal $node $window_info($win)]} {
            set c [string range $win 0 end-9]
            set winData $window_info($c,parent)
            set topMenu ${winData}top
# MacOS defines the Help menu for the application, so there is one fewer menu
            if [string match Darwin $tcl_platform(os)] {
                set numberOfMenus 6
            } else {
                set numberOfMenus 7
            }
            if {[$topMenu index last]==$numberOfMenus} {
                $topMenu delete "I/O tools"
            }
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
# Add menu at end if using MacOS, since Help menu is not defined by application
                    if [string match Darwin $tcl_platform(os)] {
                        $topMenu insert end cascade -label "I/O tools" \
                                -underline 0 -menu $topMenu.helpers
                    } else {
                        $topMenu insert "Help" cascade -label "I/O tools" \
                                -underline 0 -menu $topMenu.helpers
                    }
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
        $toolBar.$pushedbutton state !selected
        $toolBar.$newAction state selected
        #$toolBar.$pushedbutton configure -relief flat
        #$toolBar.$newAction configure -relief sunken
    SafeEqnBarEdit $window_info($winData)
        ResetEqnBar $window_info($winData)
    }
}

proc ResetEqnBar {winid} {
    set bar $winid.toolSlot.eqnbar
# for combobox version
#    $bar.equation configure -text {}
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
    global tcl_platform
    set win [FindNodeTopWin $node]
    wm deiconify $win
    raise $win
    if {[string equal Darwin $tcl_platform(os)]} {
    package require tclAE
    tclAE::send -s misc actv
    }
   # carbon::processHICommand bfrt $win
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
proc AddIfAbsent {entry list} {
    set oldPlace [lsearch $list $entry]
    if {$oldPlace==-1} {
    return [lrange [concat [list $entry] $list] 0 9]
    } else {
    return [concat [list $entry] [lreplace $list $oldPlace $oldPlace]]
    }
}

proc accept_equation {winId text} {
    global equation
    global equationbar
    set equationbar(current_action) tick
    set equationbar(equation) [string trimright [$text get]]
# do if a combobox -- not now cos no cursor insert
#    $text configure -values [AddIfAbsent $equationbar(equation) \
                 [$text cget -values]]
    set node $equationbar($winId,node)
    prolog [list tk_click_obj('$winId.canvas',  doubleclick, 0 , 0 , $node, 0)]
    set equationbar($winId,initText) $equationbar(equation)
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
# for combobox version
#    $bar.equation configure -text $equationbar($winId,initText)
    $bar.equation delete 0 end
    $bar.equation insert 0 $equationbar($winId,initText)
    focus $bar.equation
}

##############################    Formula bar    #############################

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
    set ch $chosenPaths($fileType)
    } elseif {[info exists chosenPaths(latest)]} {
    set ch $chosenPaths(latest)
    } elseif {[file exists $egDir]} {
    set ch $egDir
    } else {
    set ch [pwd]
    }
# make sure it existsss
    while {![file exists $ch]} {
    set ch [file dirname $ch]
    }
    return $ch
}
