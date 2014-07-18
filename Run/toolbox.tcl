# Simile source code file: Run/toolbox.tcl
#
# (c) Simulistics Ltd. 2001-2007
# (c) University of Edinburgh 1995-2001
#
# This file loads all procedures, and sets up the model building environment.
#
package require mime
if {!$headless} {
if {![info exists simplify]} {
# BWidget should be removed in favour of native Tk commands and the
# Tile widget set, which look better. For the time it is still needed
# for the ScrolledWindow/ScrollableFrame pair in MakeFrames in params.tcl, and
# the drag'n'drop column headings in graphs.tcl, as well as in a few
# other places round the app. Like ButtonBoxes in IO tools...

#package require BWidget
#catch {namespace import BWidget::*}

# support drag'n'drop text exchange with other apps
    if {[catch {package require tkdnd 2.4}]} {
	package require BWidget
	namespace import BWidget::*
    }

if {[info tclversion]>=8.5} {
# use our own
#    package require ttk::dialog
} else {
    package require tile 0.8.2
}
package require style::as
style::as::enable mousewheel global
}

# tile creates: TkCaptionFont TkTooltipFont TkFixedFont TkHeadingFont 
#               TkMenuFont TkIconFont TkTextFont TkDefaultFont
# ...on Linux. On the Mac it makes:
# TkCaptionFont TkClassicDefaultFont TkTooltipFont TkHeadingFont TkTextFont 
# TkDefaultFont
# ...so...
if {[string equal aqua [tk windowingsystem]]} {
    set menuFont TkDefaultFont
    set niceSize 12
} else {
    set menuFont TkMenuFont
    set niceSize 9
}
# OK, let Simile join every other app out there and look silly when dpi != 96
# (when scaling is 4/3) -- might add after testing Windows/MacOS
# set niceSize [expr {round($niceSize*[tk scaling])}]

# This normalizes fonts of older widgets to look like Tile widgets
option add *Button.font TkDefaultFont widgetDefault
option add *Radiobutton.font TkDefaultFont widgetDefault
option add *Checkbutton.font TkDefaultFont widgetDefault
option add *Scale.font TkDefaultFont widgetDefault
option add *Label.font TkDefaultFont widgetDefault
option add *Listbox.font TkDefaultFont widgetDefault
option add *Message.font TkDefaultFont widgetDefault
option add *Menu.font $menuFont widgetDefault
option add *Entry.font TkTextFont widgetDefault
option add *Text.font TkTextFont widgetDefault
option add *TLabel.font TkCaptionFont widgetDefault
# ...and this makes sure they all scale when the screen metrics change
font configure TkDefaultFont -size $niceSize
font configure $menuFont -size $niceSize
if {[string equal x11 [tk windowingsystem]] && \
	[info tclversion]<8.5} {
    font configure TkDefaultFont -weight bold
    font configure $menuFont -weight bold
}
font configure TkTextFont -size $niceSize
font configure TkCaptionFont -size $niceSize
# Now here's one of my own...
eval font create EquationFont [font actual TkTextFont]
set eqnSize [expr {[font configure EquationFont -size]*5/4}]
font configure EquationFont -size $eqnSize

# Now add the focus level to the toolbutton style so we can see when one is 
# selected by keyboard traversal (on Mac this is unnecessary and makes the 
# buttons the wrong shape)
if {[tk windowingsystem] ne "aqua"} {
    ttk::style layout Toolbutton [ttk::style layout TButton]
}
set inCocoa [string match CG* [winfo server .]]

event add <<Del>> <Delete> <BackSpace>

# Test new Windows printing technology -- see file for credits/licence
if {[string match windows $tcl_platform(platform)]} {
    #    set tempDir [file attributes $tempDir -shortname]
    #    set tempDir [file join [file dirname $tempDir] [file tail $tempDir]]
    
    #   pkg_mkIndex ../System/lib/Extras
    source $libDir/Extras/prntcanv.tcl
    source $libDir/Extras/prntproc.tcl ;# needed for eqn listings
    
    # Make Simile a DDE server under Windows. Jonathan autotesting
    # Must be after the sourcing or Simile fails
    package require dde 1
# after idle speeds startup with tcltk 8.5
    after idle dde servername Simile
} elseif {[string match Linux $tcl_platform(os)]} {
    # avoid loading buggy Trf if ActiveTcl present on system
    # package ifneeded Trf 2.1 {}
    bind Text <Control-Key-v> [list event generate %W <<Paste>>]
}

menu .openrecent -tearoff 0

wm protocol . WM_DELETE_WINDOW {close $plPipe(stream); destroy .}

} else { ;# headless
# still need some display metrics for making SVG
    set niceSize 9
} ;# headless

source ../Run/window.tcl
source ../Run/shapes.tcl
source ../Run/forms.tcl
source ../Run/equation.tcl
source ../Run/prefs.tcl
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
#         set ans [ShowMess "Simile error" error "Simile encountered an unexpected problem:\n $retVal \nDo you want to see more information?" yesno]
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

# Copy any current executables to names where they will be saved; delete 
# previous files in these posns as they are obsolete, and only copies
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
	foreach runnableExtn {.cpp .tcl .dll .so .dylib} {
	    set tgt ${prefx}$runnableExtn
	    if {[file exists $tgt]} {
		file delete -force $tgt
	    }
	    if {$Rep && [file exists ${prefx}${Rep}$runnableExtn]} {
		file copy -force ${prefx}${Rep}$runnableExtn $tgt
	    }
	}
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

set equation(fnDefs) {} ;# in case none loaded
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
        set fnLine [lsearch -inline $equation(fnDefs) "{Local *} * $functor"]
        if {![llength $fnLine]} {
            set fnLine [lsearch -inline $equation(fnDefs) \
                    "{Local *} * $functor * returns *"]
        }

	if {[llength $fnLine]} {
            set fnSpec [lindex $fnLine 0]
            set fnBase $custom(prefDir)/Functions/[lindex $fnSpec 1]
	    if {[string equal fragment [lindex $fnLine 1]]} {
		set defnFile [lindex [glob ${fnBase}/${functor},*.sml] 0]
		# use glob because metadata part of name not known
	    } else {
		set defnFile ${fnBase}.pl
	    }
            if {[file mtime $defnFile]>$date && $stat<2} {
                set stat 2 ;# Declaration out of date
            }
            if {[string equal procedure [lindex $fnLine 2]]} {
                set file ${fnBase}$procXtn
                if {![file exists $file]} {
                    return [list 3 $func $file] ;# Missing or misplaced definition
                } else {
                    if {[lsearch $files $file]==-1} {
                        lappend files $file
                    }
                    if {[file mtime $file]>$date && ![string equal tcl $L] && \
			    $stat<2} {
                        set stat 2 ;# Definition out of date
                        # no problem with tcl definitions, included at run time
                    }
                }
            }
	} else {
            return [list 4 $func <unknown>] ;# missing function declaration
            # should never happen because we read them when starting up
        }
    }
    return [concat $stat $files]
}

# In the executable interpreter, do_in_editor means execute in this
# interpreter. But there are some functions shared between the interps
# that need to do this, so in this interp it just evaluates its
# arguments. If exec uses same interp it will not load another...

proc do_in_editor {args} {
    global runState
    return [eval $args]
}

# load the whole execution code rather than just the common bits
source ../Run/runmodel.tcl
# experimental way to stop hangs -- this does something in the execution process and
# does it again as long as it works. With blind execution processes this is no
# longer needed, but still used to keep Mac window list current

proc tickle {} {
    global regularActs
    if {![catch {eval $regularActs}]} {
	after 1000 tickle
    }
}

# the 'queue' is necessary because threads stopped by tkwait variable must
# be re-started in the reverse order they were stopped. This means that if
# one call gets a result while another is waiting to start, the second must be
# started -- and finished -- before the first can use its result.

proc do_for_node {node args} {
    global myNode runState

    if {[info exists myNode]} {
	set helpersNode $myNode
    }
    set myNode $node
    set res [eval $args]
    unset myNode
    if {[info exists helpersNode]} {
	set myNode $helpersNode
    }
    return $res
}

proc HaveValues {node} {
    global runState
    if {[info exists runState($node,modelRunning)]} {
	return $runState($node,modelRunning)
    } else {
	return 0
    }
}

# Pass on Prolog calls meant for model
proc ScrubRun {node times} {
    global runState execThread execInterp

    if {![info exists execThread($node,id)] && \
	    ![info exists execInterp($node,id)]} {
	# exec code not loaded, or threaded but no exec for this node
	return
    }
    set runState($node,modelRunning) 0
    ExScrubRun $node $times
    ToggleIOToolMenu $node
}

# Called from Prolog when losing a model: no point keeping helper setup
# so don't ask
proc DestroyHelpers {node} {
    global helperTable
    
    set helperTable($node,keepSetup) 0
    LeaveHelpers $node
}

proc LeaveHelpers {node} {
    ExDestroyHelpers $node
}

proc load_dll {topNode lang progDir id node incs} {
    global execThread execInterp

    if {![info exists execThread($node,id)] && \
	    ![info exists execInterp($node,id)]} {
	# exec code not loaded, or threaded but no exec for this node
	InitExecThread $node
    }
    if {[catch {ex_load_dll $topNode $lang [GetUsableName $progDir] $id \
		    $::userinfo(edn) $incs} new_model_id]} {
	if {[PrefValue custom(hackBreak) hackBreak]} {
	    Query [list new_exec_needed $::errorInfo] info top {} {ok}
	}
	return 0
    }
    return $new_model_id
}

proc ReuseSourceCode {workingDir currentKey} {
    set oldDir [pwd]
    cd $workingDir
    if {[file exists model$currentKey.cpp]} {
	file rename -force model$currentKey.cpp model.cpp
	set result 1
    } else {
	set result 0
    }
    cd $oldDir
    return $result
}

proc compile_c {workingDir extLibs complain} {
    global sendvars tcl_platform env SIMILE_PATH

    if {$::headless} {
	set useComp [tr. Default]
    } else {
	set useComp [CheckCompilerLocation]
	if {!$::headless && [PrefValue custom(hackBreak) hackBreak]} {
	    Query [list hack_break $workingDir] question top {} ok
	}
    }
    set shLibExt [info sharedlibextension]
    set lDirs {}
    set lFiles {}
    foreach lPath $extLibs {
	if {[string equal [linkableExt $shLibExt] [file extension $lPath]]} {
	    set newLib -L[file dirname $lPath]
	    if {[lsearch $lDirs $newLib]==-1} {
		lappend lDirs $newLib
	    }
	    lappend lFiles -l[string range [file rootname [file tail $lPath]] \
				  3 end] ;# trim off "lib..."
	}
    }
    set oldDir [pwd]
    cd $workingDir
# get a so far unused file name
    set serial [newInt]
    set TARGET model${serial}$shLibExt
    while {[file exists $TARGET]} {
	set serial [newInt]
	set TARGET model${serial}$shLibExt
    }
    set TOOLDIR [file join $SIMILE_PATH Run]
    #set TCL [file dirname [file dirname [info library]]]
    #ShowMess debug info "TCL is $TCL, TOOLDIR is $TOOLDIR" ok
    if {[catch {switch $tcl_platform(platform) {
        unix {
	    if {[string equal Darwin $tcl_platform(os)]} {
# try doing it all in a special shell so I can bundle the compiler
		set spout [open "|bash 2> returns" r+]
		if {[string equal [tr. Default] $useComp]} {
		    puts $spout "export PATH=\"[file nativename [file join $env(SYSDIR) bin]]\""
		    puts $spout "export CPLUS_INCLUDE_PATH=\"[file nativename [file join $env(SYSDIR) include MacOS]]\""
		}
		puts $spout "g++ $sendvars(arflags) -fPIC -c -I\"$TOOLDIR\" -o objtmp.o model.cpp" 
		set switchForLib -bundle 
		puts $spout "g++ $sendvars(arflags) $switchForLib -o $TARGET objtmp.o $lDirs $lFiles"
		flush $spout
		close $spout
	    } else {
		eval {exec g++} $sendvars(arflags) [list -fPIC -c -I$TOOLDIR \
							-o objtmp.o model.cpp]
		set switchForLib -shared
		eval {exec g++} $sendvars(arflags) \
		    [list $switchForLib -o $TARGET objtmp.o] $lDirs $lFiles
	    }
        }
        windows {
            set TOOLDIR [file attributes $TOOLDIR -shortname]
# use a script even when starting a properly installed GNU just in case
# an error results
#            GNU {
#                switch $tcl_platform(os) {
#                    {Windows NT} {
#                        exec cmd /c start /min g++ -c -o objtmp.o -I$TOOLDIR -I. model.cpp
#                        exec cmd /c start /min dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtmp.o
#                    }
#                    {Windows 95} {
#                       exec start /m g++ -c -o objtmp.o -I$TOOLDIR -I. model.cpp
#                       exec start /m dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtmp.o
#                   }
#                }
#            } 
	    switch -regexp -- $useComp \
		[list [tr. GNU]|[tr. Default] {
	    set vistaFix 0
	    set batSt [open runmingw.bat w]
	    if {[string equal [tr. Default] $useComp]} {
		puts $batSt "set PATH=[file nativename \
                        [file join $env(SYSDIR) bin]]"
		    # One day Vista fixup will be removed, because either:
		    # (a) people have stopped using Vista, or
		    # (b) newer mingw gcc works on it anyway
		    # Today is not that day
		if {[string equal {Windows NT} $tcl_platform(os)] && \
			$tcl_platform(osVersion)==6.0 && \
			$::tclBitness==32} {
# extra paths etc for Vista might make it more fragile so avoid if not needed
# -- assume a separately installed compiler will be set up right and not need
# them
		    set LIBDIR [file join $env(SYSDIR) lib]
		    set compLocn [file join gcc mingw32 4.8.1]
		    puts $batSt "set PATH=[file nativename [file join \
                            $env(SYSDIR) libexec $compLocn]];%PATH%"
		    puts $batSt "copy \"[file nativename [file join \
                            $LIBDIR dllcrt*.o]]\" ."
		    puts $batSt "copy \"[file nativename [file join \
                            $env(SYSDIR) lib $compLocn crt*.o]]\" ."
		}
	    } else {
# Do not supply a path, modeller should add it to their environment
		# puts $batSt "set PATH=c:\\mingw\\bin;%PATH%"
	    }
	    if {[info exists LIBDIR]} { ;# continue with Vista fixup
		puts $batSt "g++ $sendvars(arflags) -c -o objtmp.o \
                        -I\"[file nativename $TOOLDIR]\" \
                        -I\"[file nativename [file join $env(SYSDIR) mingw32 \
                                include]]\" \
                        -I\"[file nativename [file join $LIBDIR \
                            $compLocn include]]\" model.cpp"
		set libOpt1 -L\"[file nativename $LIBDIR]\"
		set libOpt2 -L\"[file nativename \
				     [file join $LIBDIR $compLocn]]\"
		puts $batSt "g++ -shared -o $TARGET \
                        $libOpt1 $libOpt2 objtmp.o [concat $lDirs $lFiles]"
	    } else {
		puts $batSt "g++ $sendvars(arflags) -c -o objtmp.o \
                        -I\"[file nativename $TOOLDIR]\" model.cpp"
#        puts $batSt "dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtmp.o"
		puts $batSt [concat [list g++ -shared -o $TARGET objtmp.o] \
				 $lDirs $lFiles]
	    }
	    close $batSt
	    exec runmingw.bat
	    file delete runmingw.bat
	    file delete exptemp.exp

                # Method using command line calls to MSVC 4.0 or later -- works well
	    } [tr. Microsoft] {
	    set TOOLS32 [file dirname $env(MSVCDIR)/bin]
	    exec $TOOLS32/bin/cl.exe -GX -Ox -c -W1 -nologo \
		-DWIN32 -D_WIN32 -D_DLL -D_X86_=1 \
		-I. -I$TOOLS32/include -I$TOOLDIR \
		-Foobjtmp.o model.cpp
	    
	    exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO \
		-align:0x1000 /MACHINE:IX86 \
		-entry:_DllMainCRTStartup@12 -dll -out:$TARGET \
		$TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib \
		$TOOLS32/lib/oldnames.lib objtmp.o
	    }]
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
	if {$complain} {
	    if {[file exists returns]} {
		set errStr [open returns r]
		set chuckup [read $errStr]
		close $errStr
		file delete returns
	    }
	    cd $oldDir ;#Change back to Run directory in order to access Help file for subsequent dialogue
	    Query [list compile_failed $chuckup] warning execution {} ok
	    cd $workingDir
	    set serial -1
	} else {
	    set serial 0
	}
    } else {
	# file delete model.cpp
	# (no, we might be copying)
	file rename -force model.cpp model$serial.cpp
	file delete objtmp.o
    }
    # do not allow an old dcf to be saved with a new model
    cd $oldDir
    return $serial
}

proc LoadProgram {node lang} {
    global runState myNode
    set runState($node,updated) 0
    set runState($node,lang) $lang
    if {[info exists runState($node,runParams)] && \
	    ![info exists runState($node,currentTime)]} {
	SetRunParams $node $runState($node,runParams)
    }
    update_executable $node $lang
    if {[StartRun $node]} {
        ToggleIOToolMenu $node
	set myNode $node ;# cos new MRE will have focus
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

if {[info tclversion] > 8.5 && $tcl_platform(platform) eq "windows"} {
    set itclVers 4.0
} elseif {[info tclversion] > 8.4} {
    set itclVers 3.4
} else {
    set itclVers 3.3
}
# Not clear why this need only be set on MacOS, but it seems to work without on other platforms
# so no sense in tinkering.  Probably because of different auto_path setting mechanisms.
if [string match Darwin $tcl_platform(os)] {
  set env(ITCL_LIBRARY) $libDir/itcl$itclVers
}
package require Itcl $itclVers
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
	    Query [list extn_bug [pwd]/$extension $wibble] warning top {} ok
        }
    }
    cd $origDir
}

proc Respond {relayProc} {
    global checkFor

    gets $relayProc action
    close $relayProc

    if {[catch {set strm [open $checkFor r]}]} {
	return ;# file deleted, we are closing
    }
    set action [gets $strm]
    set action [gets $strm] ;# second line is last command passed
    close $strm
#puts "Responding to: $action"
    switch -regexp [lindex $action 0] {
        AreYouThere {
# another instance checking I am responding -- do so
            StartComms 0
        } OhNeverMind|Sender { ;# process is already dead
# response to above -- it gave up waiting. Nothing to reply to.
            StartComms 1
        } NewTopLevel|OpenTopLevel {
# an actual command. Respond, because process may be left hanging (not needed
# if relay proc pauses by waiting for console input, use arg 1 in that case)
            StartComms 0
            eval $action
	} default {
	    puts "Warning -- relay exited with no command. Not restarting."
# no command, probably crash -- restart may cause nasty loop
        }
    }
}
    
proc StartComms {firstTime} {
    global custom checkFor tcl_platform env SIMILE_PATH

    if {[string equal Darwin $tcl_platform(os)] || \
	    [info exists env(OPEN_MODEL)] && \
	    [string equal -stealth [file tail $env(OPEN_MODEL)]]} {
	return ;# MacOS takes care of this stuff -- well?
    }
    set relay [file join $env(SYSDIR) bin relay]
    switch -- $firstTime {
        1 {
# initializing -- set old proc to 0
            set dump [NetOpen $checkFor w]
            puts $dump 0
            close $dump
        } -1 {
# terminating -- send 'done' and do not wait for answer
            exec $relay $checkFor done
            file delete $checkFor
            return
        }
    }
    set outgoing "Ready [pid]"
    set cmd "\"$relay\" \"$checkFor\" \"$outgoing\""
#puts "Opening: $cmd"
    set relayProc [open |$cmd r+]
    fconfigure $relayProc -blocking 0
    fileevent $relayProc readable [list Respond $relayProc]
}

proc ControlDraw {prologVersion} {
    global sendvars custom tcl_platform env userinfo openModel simtmpdir
    global regularActs tclBitness looks

    if {$::headless} {
	set looks(buttonColor) \#d9d9d9
    } else {
	button .b
	set looks(buttonColor) [Desystematize [.b cget -bg]]
	set looks(windowColor) white
	destroy .b
	LoadIconImages
    }
    # Defaults to use if debugging
#    if {![info exists env(SIMILE_VERSION)]} {
#        set env(SIMILE_VERSION) 4.6
#        set env(licensee_name) "Support team"
#        set env(licensee_corp) "Simulistics Ltd"
#        set env(license_code) 28d4d4e4fd34b1407995899c5e655ad5
#    }
    
    set userinfo(Version) $env(SIMILE_VERSION)
    set sendvars(simV) $env(SIMILE_VERSION)
    set sendvars(proV) $prologVersion
    
    # set up to compile stub and models with same bitness as tcltk
    set sendvars(arflags) [list -Wno-trigraphs] ;# [list -O3]
    if {!$::headless && ![string equal [tr. Default] \
			    [PrefValue custom(compChoice) compChoice]]} {
# using local compiler, check if we have to tell it our bitnesss
	set gccBitness 32
	catch {exec g++ -v} gppInfo
	set relevant [string first host= $gppInfo]
	if {$relevant==-1} {
	    set relevant [string first arget $gppInfo]
	}
	set mentions64 [string first 64 $gppInfo $relevant]
	if {$relevant>-1 && $mentions64>-1 && \
		$mentions64<$relevant+16} {
	    set gccBitness 64
	} ;# assume any 64-bit gcc will be proud enough to proclaim itself
	if {$tclBitness != $gccBitness} {
	    lappend sendvars(arflags) -m$tclBitness
	}
    }

    # no longer have a separate floating toolbar
    
    if {![info exists custom(prefDir)]} {
	set foldErr home_not_set
    } else {
	set clipSpc [file join $custom(prefDir) clipboard.pl]
	if {[catch {file mkdir $custom(prefDir); \
			file delete $clipSpc} pWibble]} {
	    set foldErr [list cannot_use_home $pWibble]
	}
# above used to include this but now we make sure Prolog can handle anything:
#			prolog check_use('$clipSpc'); \
    }
    if {[info exists foldErr]} {
	catch {wm withdraw .splash}
	Query $foldErr warning top {} ok
        set custom(prefDir) [pwd]/../Prefs
    }
#   ShowMess debug info "prefdir is $custom(prefDir)" ok

# load function help messages
    set oldDir [pwd]
    foreach dir [list ../Functions/Help $custom(prefDir)/Functions/Help] {
	catch {cd $dir
	    foreach file [glob -nocomplain *.tcl] {
		if [catch {source $file} wibble] {
		    # done at startup -- make sure dialog is not concealed
		    tk_messageBox -title "Error loading user function help" -icon warning \
                        -message "help messages file [pwd]/$file had a $wibble" -type ok
		}
	    }
	}
    }
    cd $oldDir

    if {[file exists $custom(prefDir)/.version]} {
        set UserStream [NetOpen $custom(prefDir)/.version r]
        gets $UserStream userinfo(name)
        gets $UserStream userinfo(corp)
        gets $UserStream userinfo(oldVersion)
        gets $UserStream userinfo(done)
        close $UserStream
    } else {
        set userinfo(oldVersion) 0
        set userinfo(done) 0
    }
#   ShowMess debug info "Got old version $userinfo(oldVersion)" ok

    if {[catch {package require Unpacker} dummy]} {
	error "Could not find an unpacker for Simile -- $dummy"
    }

    if {[string match windows $tcl_platform(platform)]} {
	c_testlicense
	if {[catch {set userinfo(name) $env(licensee_name)}]} {
	    set userinfo(name) {}
	}
	if {[catch {set userinfo(corp) $env(licensee_corp)}]} {
	    set userinfo(corp) {}
	}
    } else {
# (include ff in Windows anyway in case some twerp runs it with userinfo.tpl)
# Windows installers can ask the user for a license code and stick it in
# userinfo.txt (formerly the registry). On other platforms we have to DIY.
	if {[string equal {<insert license code here>} $env(license_code)]} {
	    if {![DoUserDialogue]} {
		error "No license supplied"
	    }
	    set env(licensee_name) $userinfo(name)
	    set env(licensee_corp) $userinfo(corp)
	    set env(license_code) $userinfo(license_code)
	    set installTime [clock seconds]
	    set env(install_time) "$installTime :: [clock format $installTime -gmt true]"
	    c_testlicense
	    if {[catch {open [file join $custom(prefDir) userinfo.txt] w} \
		     UserStream]} {
		error "Simile failed to create a file to keep the user authorization data. If you are using the Mac version, be sure to copy the application to a folder on your hard disk before attempting to run it. See the README for details. The error was: $UserStream"
	    }
	    puts $UserStream $env(prologId)
	    puts $UserStream $env(interfaceId)
	    puts $UserStream $env(install_time)
	    puts $UserStream $env(license_code)
	    puts $UserStream $userinfo(name)
	    puts $UserStream $userinfo(corp)
	    puts $UserStream $userinfo(Version)
	    close $UserStream
	} else {
	    c_testlicense
	}
    }

    loadcommands

    if {![info exists userinfo(name)]} { ;# settings directory has come to grief
	set userinfo(name) $env(licensee_name)
	set userinfo(corp) $env(licensee_corp)
    }
    array set userinfo [list name $userinfo(name) corp $userinfo(corp) \
			    built $env(user,built) edn $env(user,edn)]
    
    # eezi-hack implementation of time limit: to do this anything like
    # properly, have stub dll check unix time against clock time
    
    set baseTime [clock scan [clock format $userinfo(built) -format %Y-%m-01]]
    array set duration {evaluation "9 months" teaching "21 months"}
    if {[info exists duration($userinfo(edn))]} {
	set expTime [clock scan $duration($userinfo(edn)) -base $baseTime]
        set userinfo(exp_time) $expTime
        set toGo [expr $expTime-[clock seconds]]

	if {$toGo<7*24*60*60} {
            #       ShowMess "Expiry imminent" warning "This version of Simile will expire on [clock format $expTime]. Please contact www.simulistics.com for an update." ok
            ShowExpiryImminent $expTime $toGo
        }
	if {$toGo<0} {
	    send_pl_cmd {error:Product has expired} ;# arrange graceful exit
	    exit
	}
    }
    
    set simtmpdir $custom(prefDir)/sim
    set go [clock clicks]
    while {[file exists $simtmpdir]} {
        set guess_free [expr [clock clicks]-$go]
        set simtmpdir $custom(prefDir)/sim$guess_free
    }
    file mkdir $simtmpdir

    set UserStream [NetOpen $custom(prefDir)/.version w]
    puts $UserStream $userinfo(name)
    puts $UserStream $userinfo(corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream
    
    set sendvars(running) 0
    
# that's startup complete now -- set up the process that communicates with
# other instances of Simile (unless stealth mode chosen)
    StartComms 1

    package require fileutil
    if {![string match windows $tcl_platform(platform)]} {
	set custom(prefDir) [::fileutil::fullnormalize $custom(prefDir)]
    }

    set custom(hotlist) {}
# v6: switch to keeping paths relative to dereferenced prefdir. I don't want
# older versions failing to read this then emptying it, so move the file...
    set cache [file join $custom(prefDir) .recent6]
    if {![file exists $cache]} {
	set cache [file join $custom(prefDir) .recent]
    }
    if {[file exists $cache]} {
        set cacheStream [NetOpen $cache r]
	fconfigure $cacheStream -encoding utf-8
        while {[gets $cacheStream oldFile]>0} {
	    if {[string equal relative [file pathtype $oldFile]]} {
		set oldFile [file normalize \
				 [file join $custom(prefDir) $oldFile]]
	    }
            if {[file exists $oldFile] && \
                        [lsearch $custom(hotlist) $oldFile]==-1} {
                lappend custom(hotlist) $oldFile
            }
        }
        close $cacheStream
    }
    
    if {[string match windows $tcl_platform(platform)]} {
        set compOptions [list CHOICE [tr. Default] [tr. Microsoft] [tr. GNU]]
	file attributes $simtmpdir -hidden true
	file attributes $custom(prefDir)/.version -hidden true
    } elseif {[string equal Darwin $tcl_platform(os)]} {
	set compOptions [list CHOICE [tr. Default] [tr. GNU]]
    } else {
	set compOptions [list CHOICE [tr. GNU]]
    }
    LoadModelWindowExtensions
    if {!$::headless} {
    Pref_Init $custom(prefDir)/.prefs
    Pref_Add [list [list custom(winPosn) winPosn [list CHOICE [tr. "Where it was last time"]  [tr. "OS default position"]]  [tr. "Place initial window:"]] \
		  [list custom(initNavbar) initNavbar ON [tr. "Tool bar"]] \
		  [list custom(initToolbar) initToolbar ON [tr. "Component bar"]] \
		  [list custom(initEqnbar) initEqnbar ON [tr. "Equation bar"]] \
		  [list custom(initGrid) initGrid ON [tr. "Grid"]] \
		  [list custom(gridH) gridH {15 1 1000} [tr. "Horizontal pitch"]] \
		  [list custom(gridV) gridV {15 1 1000} [tr. "Vertical pitch"]] \
		  [list custom(gridD) gridD {10 -100 100} [tr. "Depth"]] \
		  [list custom(maxPopupSize) maxPopupSize {500 10 10000} [tr. "Size limit"]] \
		  [list custom(bigButtons) bigButtons OFF [tr. "Use large buttons"]] \
		  [list custom(saveExtras) saveExtras [list CHOICE [tr. "Canvas file"] [tr. "Model file only"]] [tr. "Save models as..."]] \
		  [list custom(recentCount) recentCount {10 0 200} [tr. "Entries on recently used file list"]] \
		  [list custom(quickExit) quickExit [list CHOICE [tr. "Full dialogue"] [tr. "Short dialogue"]] [tr. "Closing model..."]] \
		  [list custom(leaveEqnBar) leaveEqnBar [list CHOICE [tr. "Apply change"] [tr. "Abandon change"] [tr. "Ask what to do"]] [tr. "Leaving equation bar..."]] \
		  [list custom(gridSnap) gridSnap OFF [tr. "Snap to grid"]] \
		  [list custom(quickDrag) quickDrag OFF  [tr. "Quick drag"]] \
		  [list custom(myButton) myButton \u03bc [tr. "Custom keypad button"]] \
		  [list custom(defBackground) defBackground [list CHOICE [tr. "White"] [tr. "Black"] [tr. "Clear"]] [tr. "Default background"]] \
		  [list custom(flowRouting) flowRouting ON [tr. "Kink flows"]] \
		  [list custom(infRouting) infRouting {20 -100 100} [tr. "Curve influences"]] \
		  [list custom(roleRouting) roleRouting {20 -100 100} [tr. "Curve role arrows"]] \
		  [list custom(deleteEndToEnd) deleteEndToEnd ON [tr. "Select links end-to-end"]] \
		  [list custom(helperManager) helperManager ON [tr. "Use single window manager"]] \
		  [list custom(popupPrecision) popupPrecision {0 0 16} [tr. "Value popups"]] \
		  [list custom(snapPrecision) snapPrecision {0 0 16} [tr. "Snapshots"]] \
		  [list custom(runControlPosition) runControlPosition "+0-20" [tr. "Position of run control"]] \
		  [list custom(showPauseInfo) showPauseInfo [list CHOICE [tr. "In log tab only"] [tr. "In dialogue interactions"]] [tr. "Show info about pauses"]] \
		  [list custom(slidersPosition) slidersPosition "+0+0" [tr. "Position of sliders"]] \
		  [list custom(hackBreak) hackBreak OFF [tr. "Pause to edit C++ code?"]] \
		  [list custom(compChoice) compChoice \
		       $compOptions [tr. "Use which C++ compiler?"]] \
		  [list custom(popupHelp) popupHelp ON [tr. "Popup help text"]] \
		  [list custom(compDescPop) compDescPop ON [tr. "Equation"]] \
		  [list custom(compValPop) compValPop ON [tr. "Value"]] \
		  [list custom(compCmtPop) compCmtPop ON [tr. "Comment"]] \
		  [list custom(eqListWhere) eqListWhere ON [tr. "Parameter origins"]] \
		  [list custom(eqListETDefns) eqListETDefns ON [tr. "Enumerated type definitions"]] \
		  [list custom(eqListComments) eqListComments ON [tr. "Comments"]] \
		 ]
    CheckCompilerLocation
    MakeHelperMenu

    set regularActs "ListWindows .windowchoice"
    menu .windowchoice -tearoff 0 -postcommand $regularActs
    if {[string equal aqua [tk windowingsystem]]} {
	tickle
    }
    
    # Base window has menu to display on Mac when no model windows open
    menu .hitop
    frame .hi
    . config -menu .hitop	
    AddMainMenu .hi _ 0 1 {}
    } ;# headless
    # Bogosity alert -- setting an env var to {} causes it to stay
    # (or be) unset (in windows) otherwise lappend env(OPEN_MODEL)
    # would do here...
    if {[info exists env(OPEN_MODEL)] && \
	    ![string equal -stealth [file tail $env(OPEN_MODEL)]]} {
        set openModel [brainwash $env(OPEN_MODEL)]
        # Add to path and recently opened files data
        RecordPathChoice .sml $openModel {}
    } else {
        set openModel [lindex [glob -nocomplain $custom(prefDir)/*.smx] 0]
# if there are any logfiles from unsaved models, pick one
    }
    
    # Take the opportunity to pass the temp directory name etc to Prolog
    return [list $sendvars(simV) [brainwash $simtmpdir] \
            $openModel $userinfo(edn)]
}

proc InitExecThread {node} {
    global execThread execInterp SIMILE_PATH simplify

    set useThreads [expr {[info exists ::tcl_platform(threaded)] && \
			      ![info exists simplify] && \
			      ![catch {package require Thread}]}]
    if {$useThreads} {
	set execThread($node,id) [thread::create]
# puts "Created thread $execThread($node,id) for $node from [thread::id]"
    } else {
	set execInterp($node,id) [interp create]
# puts "Created interp $execInterp($node,id) for $node"
    }

    foreach stubCmd {load_c_stub_1 c_setparamarray tcl_setparamarray c_getparamall c_gettimepointall PlaceInArray ListToArray InitTimeSeries ResetTimeSeries UpdateTimeSeries MarkEvtParamActive SetWrapTime SetFillMethod SetInterval ex_load_dll update_executable ReleaseHandle GetHandle RunningInC GetTclCompExecData GetCompProperty ExScrubRun} {
	if {$useThreads} {
	    proc $stubCmd {node args} {
		global execThread
		#puts "exec bother [lindex [info level 0] 0]"
		return [thread::send $execThread($node,id) [info level 0]]
	    }
	} else {
	    proc $stubCmd {node args} {
		global execInterp
		return [$execInterp($node,id) eval [info level 0]]
	    }
	}
    }

    foreach stubSgst {ResetModel ExecuteTo} {
	if {$useThreads} {
	    proc $stubSgst {node args} {
		global execThread
		thread::send -async $execThread($node,id) \
		    [concat Nappy [info level 0]] execThread($node,reply)
		vwait execThread($node,reply)
		# can process events and incoming messages
		if {[lindex $execThread($node,reply) 0]} {
# get rid of MRE now, easier than trying to unset 'busy'
		    ScrubRun $node 1
		    ExDestroyHelpers $node
		    error "Mishap in execution thread" \
			[lindex $execThread($node,reply) 2]
		} else {
		    return [lindex $execThread($node,reply) 1]
		}
	    }
	} else {
	    proc $stubSgst {node args} {
		global execInterp
		return [$execInterp($node,id) eval [info level 0]]
	    }
	}
    }

    if {$useThreads} {
	thread::send $execThread($node,id) [list set masterId [thread::id]]
	thread::send $execThread($node,id) \
	    [list source [file join $SIMILE_PATH Run support.tcl]]
	thread::send $execThread($node,id) \
	    [list source [file join $SIMILE_PATH Run exec.tcl]]
    } else {
	$execInterp($node,id) eval \
	    [list source [file join $SIMILE_PATH Run support.tcl]]
	$execInterp($node,id) eval \
	    [list source [file join $SIMILE_PATH Run exec.tcl]]
	foreach callbackCmd {AbortCheck InteractGUI ShiftDisplays \
				 AddLogEntry ExecQuery TransEnums InDays} {
	    $execInterp($node,id) alias $callbackCmd $callbackCmd
	}
    }
    if {[catch {load_c_stub_1 $node $::auto_path}]} {
	if {[string match Linux $::tcl_platform(os)]} {
# try rebuilding 5d dll if in Linux -- c++ libraries may have changed!
	    if {!$::headless && [PrefValue custom(hackBreak) hackBreak]} {
		Query [list new_exec_needed "Updating 5-d library"] \
		    info top {} {ok}
	    }
	    set shank $::libDir/lib5d.so
	    eval {exec g++} $::sendvars(arflags) \
		[list -fPIC -I../Run -shared -o $shank ../Run/shank.cpp]
	}
    }
# now just do it again so error gets raised as per usual if still bad
    load_c_stub_1 $node $::auto_path
}

proc CheckCompilerLocation {} {
    global tcl_platform custom env
    if {$::headless} return ;# and hope for the best
    if {![string match Linux $tcl_platform(os)]} {
        if {[string mat [tr. Microsoft] [PrefValue custom(compChoice) compChoice]]} {
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
        set custom(compChoice) [tr. GNU]
    }

    if {[string mat [tr. GNU] [PrefValue custom(compChoice) compChoice]]} {
        set compiler gcc
	# This is hacky. If I check for g++ in Windows I will find the
	# bundled version since it is in the same dir as the Simile
	# executable. There is no bundled gcc (waste of space) but any
	# separate g++ installation would include gcc, so check for
	# that instead.
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
		set compChoice [PrefValue custom(compChoice) compChoice]
		Query [list no_compiler $compChoice $compiler $possDirs] \
		    warning top {} ok
                set custom(compChoice) [tr. none]
            }
        }
    }
    return [PrefValue custom(compChoice) compChoice]
}

# After the initial model has been loaded we don't want to allow the window
# to change size when something different is loaded
# This is also a convenient time at which to hide the console
# if it is showing

# If this is a slave interp, keep the OS choice of window posn, as moving it
# may well sit it exactly on top of the previous one

proc FixSize {c} {
    global custom openModel
    set win [winfo parent $c]
    # seems necessary for console to hide
    #    catch {console hide}
    if {[file exists $custom(prefDir)/.layout] && \
	    [string equal [tr. {Where it was last time}] \
		 [PrefValue custom(winPosn) winPosn]]} {
        set stream [NetOpen $custom(prefDir)/.layout r]
        gets $stream whetherMaxed
        #ShowMess debug info $whetherMaxed ok
	catch { ;# in case file is not what we think
	    if {$whetherMaxed} {
		wm state $win zoomed
	    } else {
		gets $stream oldGeom
		scan $oldGeom "%dx%d%1s%d%1s%d" w h lr l tb t
		if {$w>200 && $h>200 && \
			$l>=0 && $l+$w<=[winfo screenwidth $win] && \
			$t>=0 && $t+$h<=[winfo screenheight $win]} {
		    # these give wrong values on multi-screen Windows setup
		    wm geometry $win $oldGeom
		} else {
		    # puts "$w $h $lr $l $tb $t"
		}
	    }
	}
        close $stream
    }
    update

    destroy .splash
    if {[string match $openModel {}]} {
        DoRegDialog $win
    }
}

proc AlterModel {topNode} {
    global runState
    set runState($topNode,updated) 1
}

proc PathFromDispo {bit} {
    set Disposition [mime::getheader $bit Content-Disposition]
    if {![regexp \"(.*)\" $Disposition all oldPath]} {
	set oldPath [lindex [lindex $Disposition 0] 1]
    }
    return $oldPath
}

# treat .cpp files as runnables to make sure obsoletes are removed
proc IsRunnableModel {fileName} {
    return [expr {[lsearch {.cpp .tcl .dll .so .dylib} \
		       [file extension $fileName]]!=-1}]
}

proc SaveFile {topNode tree tgt {noPkg 0}} {
    #ShowMess debug info "SaveFile $tree $tgt" ok
    global errorInfo runState projectInfo
    
    if {!$noPkg} {
	set projectInfo {}
	SaveProjectFile $topNode $tree $tgt
	# shfs to $tree
	# spfs to $tree
    }

    if {[catch {
	set parts [GetParts $tree $tree $noPkg]
	#ShowMess debug info "SaveFile GetParts $tree" ok
	if {[info exists runState($topNode,runParams)]} {
	    lappend parts [mime::initialize -canonical application/x-simile \
			   -header [list "Content-Description" "Run Status"] \
			   -encoding base64 \
			   -string $runState($topNode,runParams)]
	    lappend projectInfo "Model execution parameters"
	}
	if {!$::headless && [PrefValue custom(hackBreak) hackBreak] && \
		!$noPkg} {
	    set resp [Query [list pkg_contents [join $projectInfo \n]] info \
			  top {} {ok cancel}]
	    if {![string equal ok $resp]} {
		set cancelled 1
	    }
	}
        if {![info exists cancelled]} {
	    set multiT [mime::initialize -canonical multipart/mixed \
			    -parts $parts]
	    set stream [NetOpen $tgt w]
	    fconfigure $stream -translation binary
	    mime::copymessage $multiT $stream
	    # clean everything up
	    close $stream
	    mime::finalize $multiT -subordinates all
        }
    } Lossage]} {
        return $errorInfo
    } else {
        return $Lossage
    }
}

proc SaveMimeBit {body newPath} {
    file mkdir [file dirname $newPath]
    set mimeSquirter [NetOpen $newPath w]
    fconfigure $mimeSquirter -translation binary
# little point as it has to be unpacked in memory to process the auth code
#    mime::getbody $bit -command SquirtMime -blocksize 256
    puts -nonewline $mimeSquirter $body
    close $mimeSquirter
    if {![catch {mime::getheader $bit Date-Modified} Date]} {
	file mtime $newPath [clock scan [lindex $Date 0]]
    }
}

proc OurEdition {text} {
    global userinfo

    string equal $userinfo(edn) [IdentField $text edition]
}

proc LoadFile {topNode tree tgt} {
    global errorInfo runState
    global loadingProject mimedir
    #ShowMess debug info "LoadFile $tree $tgt" ok
    set CodeChecked no
    if {[catch {
            set multiT [mime::initialize -file $tgt]
            if {[catch {set intent [mime::getheader $multiT Readability]}]} {
                set intent standard
            }
            foreach bit [mime::getproperty $multiT parts] {
                set Desc [mime::getheader $bit Content-Description]
                #ShowMess debug info $Desc ok
		if {[catch {PathFromDispo $bit} oldPath]} {
		    set oldPath /none/
		}
		set boddledy [mime::getbody $bit]
                switch [lindex $Desc 0] {
                    "Run Status" {
                        set runState($topNode,runParams) $boddledy
# make sure they are used...good how 'array unset' never raises error
			array unset runState $topNode,currentTime
# do next bit when starting exec proc
#                        do_for_node $topNode SetRunParams $topNode $runParams
                    } "Authentication Code" { ;# old method: separate part
                        set codes $boddledy
		    } "Simile model" {
			catch {set codes [mime::getheader $bit \
					      Authentication-Code]} foo
#puts "Code result $foo"
			if {[info exists codes]} {
			    check_auth_code $boddledy [string trim $codes]
			    set CodeChecked yes
                        }
			SaveMimeBit $boddledy $tree$oldPath
		    } "Simile helper configuration file" {
# as of 5.6 these are no longer included in the .sml file for reasons of
# consistency, so this is an earlier saved model. Attempt to copy the .shf
# relative to saved model file so it will open.
			SaveMimeBit $boddledy [file dirname $tgt]$oldPath
                    } default {
			# If no auth code, do not keep executable, but
			# dont crash either -- could be innocent
			if {[IsRunnableModel [file tail $oldPath]]} {
			    if {[catch {string trimright [mime::getheader \
				    $bit Authentication-Code]} AuthCode]} {
				continue
			    } else {
				check_auth_code $boddledy $AuthCode
# now insert 1 in its name so we are not forced to save it next time
				set oldPath [file rootname $oldPath]1[file extension $oldPath]
			    }
			}
			SaveMimeBit $boddledy $tree$oldPath
		    }
                }
            }
            #ShowMess debug info "LoadFile after unpack\n[glob $tree/*]" ok
            # if there is a project file
            if {[file exists $tree/model.spj]} {
                #ShowMess debug info "LoadFile file is package" ok
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

proc GetParts {top tree noPkg} {
    global projectInfo

    set mimes {}
    foreach subtree [glob -nocomplain ${tree}/*] {
        #ShowMess debug info "GetParts subtree $subtree" ok
        if {[file isdirectory $subtree]} {
            set mimes [concat $mimes [GetParts $top $subtree $noPkg]]
        } else {
            set ext [file tail $subtree]

            switch -glob $ext {
                *.png {
                    set PartType "image/png"
                    set Description "Image"
                    set style inline
                }
                *.gif { ;# legacy
                    set PartType "image/gif"
                    set Description "Image"
                    set style inline
                }
                *.jpeg { ;# legacy
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
                model.svg {
                    set PartType "application/x-simile"
                    set Description "Simile diagram"
                    set style attachment
                }
                #*.spf {
# .spfs contain relative paths so are referenced, not moved into the tree
# (note exra hashes because match string cannot be commented out)
                    set PartType "application/x-simile"
                    set Description "Simile parameter file"
                    set style attachment
                }
                #*.shf {
# reference .shfs as well, for consistency
                    set PartType "application/x-simile"
                    set Description "Simile helper configuration file"
                    set style attachment
                }
                *.spj {
                    set PartType "application/x-simile"
                    set Description "Simile package description"
                    set style attachment
                }
                model.* {
                    set PartType "application/x-simile"
                    if {$noPkg} {
			set Description junk
		    } else {
			set Description Data
		    }
                    set style attachment
                } 
		default {
                    set Description junk
                }
            }
            # when saving, save all relevant files from current level but only
            # parameter files for submodels -- everything else is included in top level
            if {[string equal Data $Description] || \
                        [string equal $top $tree] && \
                        ![string match junk $Description]} {
                set relPath [string range $subtree [string length $top] end]
		if {[string equal Data $Description]} {
		    set extExt [file extension $ext]
		    if {[string equal .cpp $extExt]} {
			set Description "C++ source code"
		    } else {
			set OS [lindex {Linux MacOS Windows Tcl} \
				    [lsearch {.so .dylib .dll .tcl} $extExt]]
			set Description "$OS executable"
		    }
		}
		if {[llength $relPath]>1} {
		    set smTree [join / [lrange $relPath 0 end-1]]
		    append Description " for $smTree"
		}
		lappend projectInfo $Description
                set Disposition "${style}; filename=\"$relPath\""
                set Date [clock format [file mtime $subtree] \
                  -format "%Y-%m-%d %T %Z" -gmt true]
# we need the body for authorization checks, so save effort by creating mime
# from it too
		set flStream [open $subtree r]
		fconfigure $flStream -translation binary
		set boddledy [read $flStream]
		close $flStream
		set newM [mime::initialize -canonical $PartType \
			      -encoding base64 -string $boddledy]
		set headers [list "Content-Disposition" $Disposition \
				 "Content-Description" $Description \
				 "Date-Modified" $Date]
                if {[string match "Simile model" $Description]} {
                    set HmacCode [get_auth_code $boddledy]
# this was for versions up to 4.6 that need separate code
#                    set codeT [mime::initialize -canonical text/plain \
#                            -header [list "Content-Description" \
#                            "Authentication Code"] \
#                            -string $HmacCode]
#                    lappend mimes $codeT
		    lappend headers "Authentication-Code" $HmacCode
                }
		if {[IsRunnableModel $ext]} {
		    if {![OurEdition $boddledy]} {
			continue
		    }
		    lappend headers "Authentication-Code" \
			[get_auth_code $boddledy]
		}
		foreach {key val} $headers {
		    ::mime::setheader $newM $key $val
		}
		lappend mimes $newM
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

proc ConvertSSxml {node} {
    global simtmpdir SIMILE_PATH
    package require xslt

    if {![string length [package provide Trf]} {
	puts "Warning -- using Mime in fallback mode: $errorInfo"
    }

	set importSrc [ChooseFile spreadsheet.xml \
			   [tr. "Import spreadsheet from:"] 0 $node]
    set mm1 [mime::initialize -canonical application/x-xml 
	     -encoding base64 -file $importSrc]
    set XML [mime::getbody $mm1]
    set source_doc [::dom::libxml2::parse $XML]
    set mm2 [mime::initialize -canonical application/x-xml \
		 -encoding base64 -file ${SIMILE_PATH}/Run/xml2pl01.xsl]
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
    if {[scan $str %g%n floatVal floatSize]>0} {
	if {[scan $str %d%n intVal intSize]>0} {
	    if {$intSize == $floatSize && abs($intVal)<268435456} {
		return [list $intVal $intSize]
	    }
	}
# make sure it has float type -- cannot use # as prolog barfs if last char
# is decimal point. But not using it can leave out point altogether, which
# also screws it, so use e instead of g -- after all, the user never sees this
# format -- it only exists to get the value into Prolog.
#	set floatVal [format %.16e $floatVal]

# Except of course they do if there's a syntax error...the solution
# appears to be to use expr, which makes sure the printed string is
# taken afresh from the numeric value, and thus:

# carries its full precision (and no more), 
# uses point to show whether float or int,
# happily does not start with a point!

# this never happens now
#	if {[string is integer $floatVal]} {
#	    append floatVal .0
#	}

# however, scientific notation values may not get a point, so check
# for this and insert .0 before the e if so...
	set fltResult [expr {$floatVal}]
	if {[string first . $fltResult]==-1} {
	    set fltResult [string map {e .0e} $fltResult]
	}
	return [list $fltResult $floatSize]
    }
}

# and with the OS character encoding...

proc GetSystemChars {string} {
    set sysbag [encoding convertto [encoding system] $string]
    binary scan $sysbag c[string length $sysbag] list
#ShowMess debug info "Getting codes for $string got $list" ok
    foreach char $list {
	if {$char<0} {
	    lappend ulist [expr $char+256]
	} else {
	    lappend ulist $char
	}
    }
    return \[[join $ulist ,]\].
}

proc GetUsableName {string} {
    if {[string equal windows $::tcl_platform(platform)]} {
	if {![file exists $string]} {
	    close [open $string a] ;# create it empty
	}
	set string [file attributes $string -shortname]
    }
    return $string
}

proc GetSystemName {string} {
    return [GetSystemChars [GetUsableName $string]]
}

# Path names derived from Windows environment variables must be
# 'brainwashed' i.e., stripped of their native culture and turned
# into blank-faced Unix-style forward-slash-separated automata.
# Otherwise mingw gcc variably gets culture shock.

proc brainwash {ethnic} {
    return [file join [file dirname $ethnic] [file tail $ethnic]]
}

proc RaiseWinMRE {win} {
    global window_info
    
    set node $window_info($win,top_node)
    RaiseMREFor $node
}

proc FinishExec {win} {
    global window_info helperTable hideQuery

    set node $window_info($win,top_node)
    $helperTable(RunControl)::AbortFromMenu $node
}

proc ExecQuery {specifics icon helpRef parent opts} {
    if {[PrefValue custom(showPauseInfo) showPauseInfo] eq \
	    [tr. "In log tab only"] && \
	    $icon eq "info" || [info exists ::hideQuery]} {
	return ok
# rely on log entry
    } else {
	return [Query $specifics $icon $helpRef $parent $opts]
    }
}

proc OpenAll {win} {
    MenuSelect $win file open
    if {![info exists ::SimileAutoObjLoaded] && \
	    $::window_info($win,is_top_level)} {
	RunIfPackage
    }
}

proc RunIfPackage {} {
    global loadingProject mimedir
    if {[info exists loadingProject]} {
        OpenProjectFile $mimedir
    }
}

proc OpenProjectFile {path} {
    global loadingProject runState helperTable
    set pFile [file join $path model.spj]
    set projectF [NetOpen $pFile r]
    #gets $projectF SimileProjectData
    set SimileProjectData [read $projectF] ;# may be line breaks in sm names
    close $projectF
    file delete $pFile
    array set SimileProject $SimileProjectData
    
    # if params it should load the spfs
    # MergeParams {smPath metaFile interactive}
    set topNode [lindex $loadingProject 0]
    set baseDir [file dirname [lindex $loadingProject 1]]
    # unset it before doing anything clever in case it goes wrong
    unset loadingProject
    if {[info exists SimileProject(modelRunning)]} {
	set win [FindNodeTopWin $topNode].canvas
#puts "win $win topNode ÃÂ£topNode"
	if {[info exists SimileProject(spfList)]} {
        # file params cannot be loaded until model is ready, so set this
        # variable which will be read before opening the dialogue
#puts "retrieved SimileProject(spfList) $SimileProject(spfList)"
	    foreach {smPath spfRelPath} $SimileProject(spfList) {
		set ::projectParams($smPath) [file join $baseDir $spfRelPath]
	    }
	}
        if {$SimileProject(running_c)} {
            MenuSelect $win code run_c
        } else  {
            MenuSelect $win code run_tcl
        }
	update
        if {$runState($topNode,modelRunning)>=3 && \
		[info exists SimileProject(nameOfHelperStateFile)]} {
	    set helperTable($topNode,stateName) \
		[file normalize [file join $baseDir \
				     $SimileProject(nameOfHelperStateFile)]]
            set command [ChooseText \
			     [PrefValue custom(helperManager) helperManager] \
			     ::RunEnv::LoadSHF CreateView]
            $command $topNode $helperTable($topNode,stateName)
	    ::RunEnv::PreserveSetup 0
        }
    }
}

proc SaveProjectFile {topNode path tgt} {
    global runState helperTable projectInfo
    #ShowMess debug info "SaveProjectFile $path" ok
    # save any current spf names to the spj file
    # save any shf files names
    
    set ProjectFile $path/model.spj
#    set topCapt [GetExecTitle $topNode]
    
    # is it builtC|builtTcl|notbuilt
    if {[HaveValues $topNode] && !$runState($topNode,updated)} {
        set SimileProject(modelRunning) 1
	set SimileProject(running_c) [string equal c $runState($topNode,lang)]
    }
    if {[info exists helperTable($topNode,keepSetup)] && \
	    $helperTable($topNode,keepSetup)} {
	set choices {lose_shf update_shf}
	if {[info exists helperTable($topNode,stateName)]} {
	    set choices [linsert $choices 0 keep_shf]
	}
	set helperAction [Query save_helper_setup question top {} $choices]
	switch $helperAction {
	    update_shf {
		::RunEnv::SaveView 0
	    } lose_shf {
		array unset helperTable $topNode,stateName
	    }
	}
    }
    set tgtDir [file dirname $tgt]
    if {[info exists helperTable($topNode,stateName)]} {
# old method: include helper state in saved model, just because we could...
#	if {![string equal $path \
#		  [file dirname $helperTable($topNode,stateName)]]} {
#	    file copy -force $helperTable($topNode,stateName) $path
#	}
        set SimileProject(nameOfHelperStateFile) \
	    [::fileutil::relative $tgtDir $helperTable($topNode,stateName)]
    }
    # shf file name loaded
    
    set spfList [array get ::SimileProject fileparam,/${topNode}/*]
    foreach {varName spfPath} $spfList {
	set smPart [Submodelize $varName]
	set relPath [::fileutil::relative $tgtDir $spfPath]
	set pmData "Reference to parameter metafile $relPath"
	if {[llength $smPart]} {
	    append pmData " for [string range $smPart 1 end]"
	}
	lappend projectInfo $pmData
	lappend SimileProject(spfList) $smPart $relPath
    }
    set projectF [NetOpen $ProjectFile w]
    set statLine [array get SimileProject]
    puts $projectF $statLine
    close $projectF
}

# convert fileparam,/foo/bar/xxx/ into /bar/xxx
proc Submodelize {path} {
    return [join [concat [list {}] [lrange [split $path /] 2 end-1]] /]
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
    global window_info

    set psfile [ChooseFile image.ps [tr. "Name of postscript file"] 1 \
		   $window_info($winId,top_node)]
    # check for cancel
    if {![string match */ $psfile]} {
        
        # force .ps extension
        if {[string compare [file extension $psfile] .ps]} {
            set psfile [file root $psfile].ps
        }
        SpitPS $winId $psfile
    }
}

proc GetPrintZone {winId} {
    foreach cmd [list "$winId bbox size_on_this" "$winId bbox all" \
		     "$winId cget -scrollregion"] {
	set result [eval $cmd]
	if {[string length $result]} {
	    return $result
	}
    }
    return [list 0 0 [winfo width $winId] [winfo height $winId]]
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
	set jiggles(oldScroll) [$winId cget -scrollregion]
        scan [GetPrintZone $winId] "%g %g %g %g" sl st sr sb
        set jiggles(bl) $sl
        set jiggles(bt) $st
        
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
        $winId configure -scrollregion $jiggles(oldScroll)
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
        if {[catch "exec $env(PRINTCMD) {[file nativename $tempPSFile]}" \
		 result]} {
	    Query [list linuxPrintFail $result] warning top $winId {ok}
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
    MenuSelect $winId model insert
}

proc UniqueId {base {used {}}} {
    global instCount

    set new 0
    while {!$new} {
	if {[info exists instCount($base)]} {
	    incr instCount($base)
	} else {
	    set instCount($base) 0
	}
	set try $base$instCount($base)
	set new [expr [lsearch $used $try]==-1]
    }
    return $try
}

# called from constructor
proc MakeNodeInProlog {newInstance} {
    global classTable fromProlog

    prolog tk_make_desktop_node($::headless)
# secret run instance for use by system helpers
    set newRunInstance [UniqueId modelRun]
    similescript::RunControl $newRunInstance $newInstance
    set node [lindex $fromProlog 0]

    set lookers [list generic compartment channel text \
		     variable function submodel flow influence \
		     ghost_link relation]
    if {[info exists ::do_events]} {
	lappend lookers event state squirt
    }
    foreach nodeType $lookers {
	# add event squirt state to above
	ResetLooks $node $nodeType
    }

    set classTable(run,$node) $newRunInstance
#this didn't work so stomp it
    $newRunInstance configure -modelNode $node
    return $fromProlog
}

# GUI tells Simile to make a new desktop
proc MakeDesktopNode {} {
    global classTable
    if {[info exists ::SimileAutoObjLoaded]} {return {none dummy}} ;# called in Simile initialization
    set newInstance [UniqueId modelWin]
    similescript::ModelWindow $newInstance
    set node [$newInstance cget -modelNode]
    set classTable(model,$node) $newInstance
    return [list $node [$newInstance cget -modelCanvas]]
}

proc Reopen {canvas oldFile op} {
    global custom userinfo welcomeDone preSelect
    
    if {!$::headless && [winfo exists .register]} {
        set userinfo(done) $welcomeDone
    }
    set preSelect $oldFile
    OpenAll $canvas
}

proc FillReopen {winId} {
    global custom

    if {[string equal .hi $winId]} return ;# models canot open here anyway
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
# Also need to check selection because of "Save seln..."
    prolog tk_bar_edit_menu('$winId.canvas')
    update idletasks
}

proc Rerun {winId go} {
    global runState window_info
    
    set node $window_info($winId,top_node)
    if {![HaveValues $node] || $runState($node,updated) || \
	    $runState($node,modelRunning)==4} {
        if {[info exists runState($node,lang)]} {
            set runType run_$runState($node,lang)
        } else {
            set runType run_c
        }

        MenuSelect $winId code $runType
    } else {
        StartRun $node
        # assume if model was running before it will run again
    }
    # Only proceed if it worked
    if {![HaveValues $node]} {
        return fail
    }
    if {$go} {
        StartNow $node start
    }
    return yes
}

proc UpdateAbility {c what where which whether} {
    global window_info menuPosns
    set winId $window_info($c,parent)
    set newState [ChooseText $whether normal disabled]
    ${winId}top.$where entryconfigure $menuPosns($where,$which) -state $newState
    AcceleratorState $winId $where $which $newState
    if {![string equal none $what]} {
        set navBar $winId.toolSlot.navbar
        $navBar.$what configure -state $newState
    }
}

proc ToggleIOToolMenu {node} {
    global window_info custom tcl_platform
    
    if {$::headless} return
    foreach win [array names window_info *,top_node] {
        if {[string equal $node $window_info($win)]} {
            set c [string range $win 0 end-9]
            set winData $window_info($c,parent)
            set topMenu ${winData}top
# MacOS defines the Help menu for the application, so there is one fewer menu
# -- removed because it is so hard to use the MacOS-defined menu
#            if [string match Darwin $tcl_platform(os)] {
#                set numberOfMenus 7
#            } else {
                set numberOfMenus 8
#            }
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
                        set menuSpec [ListMenuContents .helpers]
                        ReconstituteMenu $topMenu.helpers $menuSpec $node
                    }
# Add menu at end if using MacOS, since Help menu is not defined by application
# (oh yes it is)
#                    if [string match Darwin $tcl_platform(os)] {
#                        $topMenu insert end cascade -label "I/O tools" \
#                                -underline 0 -menu $topMenu.helpers
#                    } else {
                        $topMenu insert "Window" cascade -label "I/O tools" \
                                -underline 0 -menu $topMenu.helpers
#                    }
                }
            } else {
                set newState disabled
            }
            $winData.toolSlot.toolbar.snap configure -state $newState
	    set snapIndx $::menuPosns(tools,Inspect\ elements)
            $topMenu.tools entryconfigure $snapIndx -state $newState
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

proc UpdateCursors {newCurs} {
    global window_info
    foreach {can win} [array get window_info *,parent] {
	$win.canvas config -cursor $newCurs
    }
}

set window_info(defCurs) arrow
proc ShowWatchWhileDoing {cmd} {
    global window_info

    if {[info exists window_info(oldCurs)]} { ;# watch already shows so just do
	uplevel \#0 $cmd
    } else {
	set window_info(oldCurs) arrow ;# value irrelevant
	UpdateCursors watch
	update idletasks
	uplevel \#0 $cmd
	UpdateCursors $window_info(defCurs)
	unset window_info(oldCurs)
    }
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
    foreach eqnButton {equation min max tick cross inputs function} {
        $bar.$eqnButton configure -state $newState
    }
}

proc RaiseModelWindow {node} {
#    global tcl_platform
    set win [FindNodeTopWin $node]
    wm deiconify $win
    raise $win
#    if {[string equal Darwin $tcl_platform(os)]} {
#	tclAE::send -s misc actv
#    }
   # carbon::processHICommand bfrt $win
}

proc FindNodeTopWin {node} {
    global window_info
    foreach {key win} [array get window_info *,parent] {
        set c [string range $key 0 end-7]
        if {[string equal $node $window_info($c,top_node)] && \
                    [info exists window_info($c,is_top_level)]} {
# latter clause just weeds out silly answers
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

set equation(prevs) {}

proc accept_equation {winId text} {
    global equation
    global equationbar
    set equationbar(current_action) tick
    set equationbar(equation) [string trimright [$text get]]
# do if a combobox -- not now cos no cursor insert
# (huh? Seems OK with ttk::combobox)
    set equation(prevs) [AddIfAbsent $equationbar(equation) $equation(prevs)]
    $text configure -values $equation(prevs)
    set node $equationbar($winId,node)
    prolog [list tk_click_obj('$winId.canvas',  doubleclick, 0 , 0 , $node, 0)]
    set equationbar($winId,initText) $equationbar(equation)
#    focus $winId.canvas
}

proc AddInputs {winId bar} {
    global equationbar

    set node $equationbar($winId,node)
    $bar.inputs.menu delete 0 end
    set equationbar(params) {} ;# for autocomplete
    set paramData [GetFromProlog tk_get_params('$winId',$node)]
    set popupTable {}
    foreach paramList [lsort -dictionary -index 1 $paramData] {
	set paramName [lindex $paramList 1]
	$bar.inputs.menu add command -label $paramName \
	    -command [list InsertParam $bar.equation $paramName]
	lappend equationbar(params) $paramName
	lappend popupTable "$paramName: [DescribeInputParam [lindex $paramList 0]] ([lindex $paramList 2])"
    }
    MenuBindPopup $bar.inputs.menu $popupTable
}

proc InsertParam {bar paramName} {
# only used for equation bar so assume validation on
    $bar configure -validate none
    $bar insert insert $paramName
    $bar configure -validate key
}

proc DescribeInputParam {paramSpec} {
    if {[string equal in_hierarchy [lindex $paramSpec 2]] ||
	[string equal /none/ [lindex $paramSpec 1]]} { 
# no roles or role not used
	set template [tr. {Value(s) of %1$s}]
    } elseif {[string equal in_base [lindex $paramSpec 2]]} {
	set template [tr. {Value(s) of %1$s from submodel "%2$s" in role "%3$s"}]
    } else { ;# in_assoc
	set template [tr. {Value(s) of %1$s for submodel "%2$s" in role "%3$s"}]
    }
    format $template [BlankCrs [lindex $paramSpec 0]] \
	[BlankCrs [lindex $paramSpec 1]] [BlankCrs [lindex $paramSpec 3]]
}

proc restore_equation {winId bar} {
    global equationbar
# for combobox version
#    $bar.equation configure -text $equationbar($winId,initText)
    $bar.equation configure -validate none
    $bar.equation delete 0 end
    set evts [$bar.events cget -values]
    $bar.equation insert 0 $equationbar($winId,initText)
    $bar.equation configure -validate key
    focus $bar.equation
}

##############################    Formula bar    #############################

proc RecordPathChoice {fileType chosenFile context} {
    global chosenPaths custom simtmpdir
    
    set tgtDir [file dirname $chosenFile]
    if {[string equal $simtmpdir $tgtDir]} return ;# preselected
    if {[string equal .sml $fileType]} { ;# we are opening a model file
	set custom(hotlist) [linsert $custom(hotlist) 0 $chosenFile]
	array unset chosenPaths *,$context
    }
    set chosenPaths($fileType,$context) \
	[set chosenPaths(latest,$context) $tgtDir]
}

proc GetPathChoice {fileType context} {
    global chosenPaths custom

# defaults in ascending order of preference -- pick best that exists
    set ch [pwd] ;# current directory
    if {[file exists [set test $custom(prefDir)/Examples]]} {
	 set ch $test
    } ;# examples directory
    foreach prevChoice $custom(hotlist) {
	if {[file exists $prevChoice]} {
	    set ch [file dirname $prevChoice]
	    break
	}
    } ;# previous model choices, most recent best
    if {[llength $context]} {
	if {[info exists chosenPaths($fileType,$context)]} {
	    set ch $chosenPaths($fileType,$context) ;# last file same type
	} elseif {[info exists chosenPaths(latest,$context)]} {
	    set ch $chosenPaths(latest,$context) ;# last file any type
	}
    }
# make sure it existsss
    while {![file exists $ch]} {
	set ch [file dirname $ch]
    }
    return $ch
}
