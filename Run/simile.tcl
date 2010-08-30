#set simplify 1 ;# avoid loading anything awkward
#set do_events 1 ;# include event symbols
#!/home/jaspert/Simile/System/bin/wish
# Simile source code file: Run/simile.tcl
#
# (c) Simulistics Ltd. 2001-2010
# (c) University of Edinburgh 1995-2001
#
# This file contains the code initially sourced into the Tcl interpreter and
# itself sources toolbox.tcl to define all model diagram editor procedures, and
# prolog.tcl to initiate communication with the Prolog component.
#
# If there is an arg, it is the model to start with. Because this is sourced
# from a script or special .exe there is never more than one arg. Windows has
# a buggy implementation of file pathtype so hope that simile.exe always
# gets us an absolute path...
#
# Now I am trying to use the relay system to pass messages between new and 
# existing Simile processes. This means I need to know where my temporary
# files are...
if {[string equal windows $tcl_platform(platform)]} {
    set homeDir [file attributes $env(HOME) -shortname] ;# is Ascii
} else {
    set homeDir $env(HOME)
}
if {[info exists embed_args]} {
    set custom(prefDir) {}
} elseif {[file exists $homeDir]} {
# 4.1 moved SimileUserDirectory for Windows -- check in old position and update
    set oldPrefs [file join $homeDir .simile]
    if {[string equal windows $tcl_platform(platform)]} {
	if {[string equal "Windows NT" $tcl_platform(os)] && 
	    $tcl_platform(osVersion)>=6.0} {
		set docsDir Documents
	    } else {
		set docsDir "My Documents"
	    }
        set custom(prefDir) [file join $homeDir $docsDir "My Simile files"]
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
    } elseif [string match Darwin $tcl_platform(os)] {
	set custom(prefDir) [file join $homeDir "Simile"]
    } else {
	set custom(prefDir) $oldPrefs
    }
}

if {[string match windows $tcl_platform(platform)]} {
    package require dde 1.2
    set runHow(sendOp) {dde eval}
    set argv [lindex $argv 0]
} else {
    set runHow(sendOp) send
}
set oldProc Simile
set runHow(sendCmd) [concat $runHow(sendOp) $oldProc]

# replace /./ in path with / to avoid confusing file dirname
regsub -all /\\./ [info script] / scriptCmd

#tk_messageBox -title Invocation -icon info -message "$scriptCmd $argv" -type ok
# Awkward: you want to normalize to get rid of ..'s in path, but that also
# resolves any pointers except for the complete argument, which can stop the
# development version starting
set SIMILE_PATH [file normalize [file dirname [file dirname $scriptCmd]]]
set env(SP_PATH) $SIMILE_PATH/System
# Above seems unnecessary for sicstus 3.10

proc ChooseIntegerRatio {fraction accu} {
    set m 1
    while {1} {
	if {$m<$fraction} {
	    set d 1
	} else {
	    set d [expr {round($m/$fraction)}]
	}
	# set d [max round($m/$fraction) 1]
	set close [expr $m/($fraction*$d)]
	if {$close > $accu && $close < 1/$accu} {
	    return [list $m $d]
	}
	incr m
    }
}
	
set defScaling [tk scaling]
set savedCredentials [list prologId interfaceId install_time license_code \
			  licensee_name licensee_corp]
# from v5.5, windows installer creates usrinfo.txt rather than writing registry
# if {[string equal windows $tcl_platform(platform)]} {
#     package require registry
#     set regKey HKEY_LOCAL_MACHINE\\Software\\Simulistics\\Simile
#     foreach regEntry $savedCredentials {
# 	catch {set env($regEntry) [registry get $regKey $regEntry]}
#     }
# } else {
    set UserStream [open $SIMILE_PATH/Run/userinfo.txt r]
    foreach regEntry $savedCredentials {
	gets $UserStream env($regEntry)
    }
    close $UserStream
# }
# set env(prologId) gnu ;# goodbye forever Sicstus
if {[info exists prolog_in_console]} {
    set SIMILE_PATH [file dirname [pwd]] ;# otherwise it is relative
    set env(interfaceId) console
# this will simply let the script run out after loading the rest of the Tcl
# so control goes back to Prolog
} else {
# v5.7: try to keep even Linux and Windows from loading any TclTk packages they
# find on the system, to avoid buggy XML or inappropriate Itcl?
    set auto_path {}
}
lappend auto_path [file join $SIMILE_PATH System lib]
if {[string match Darwin $tcl_platform(os)]} {
    lappend auto_path $SIMILE_PATH/../Frameworks/Tcl.framework/Resources/Scripts $SIMILE_PATH/../Frameworks/Tk.framework/Resources/Scripts
#    package require tclAE

    if {[string match \-psn_* [lindex $argv 0]]} {
# Process ID added by MacOS -- discard
	incr argc -1
	set argv [lrange $argv 1 end]
    }

    proc ::tk::mac::OpenDocument {args} {
        global env
# only opens the first of a group of files dropped or double-clicked,
# but at least it handles files with spaces in the name.      
        if {[catch {OpenTopLevel [lindex $args 0]} splat]} {
# fails (because proc not yet loaded?) if Simile started by drag/drop
	    set env(OPEN_MODEL) [lindex $args 0]
	}
    }
#    proc handleOpenApp {foo bar} {
#	tk_messageBox -message "open foo $foo bar $bar"
#    }
#    tclAE::installEventHandler aevt oapp handleOpenApp
    proc ::tk::mac::ReopenApplication {} {
	global window_info
	if {![llength [array names window_info *,parent]]} {
	    NewTopLevel
	}
    }
#    tclAE::installEventHandler aevt rapp handleReopenApp
#    tk scaling 1.0
} else {
    lappend auto_path [file join $SIMILE_PATH System lib tk[info tclversion]]
# If Simile is already running, make a new window there and exit. Note that
# on Macs the OpenDocument takes care of this and we don't even get this far
# OTOH, if Simile is not running already, need to skip the following on Macs.

    proc HandOver {relayProc} {
        global relay checkFor startAnew env
        gets $relayProc action
        close $relayProc
#puts "New instance read string $action"
        if {[string equal "Sender process is already dead" $action]} {
            set startAnew 1
        } else {
            if {[info exists env(OPEN_MODEL)]} {
                set remStartArgs [list OpenTopLevel $env(OPEN_MODEL)]
            } else {
                set remStartArgs NewTopLevel
            }
# do not use execExtn -- its not defined yet, not needed for Windows,
# null for Linux and we don't do this in MacOS
            set cmd "\"$relay\" \"$checkFor\" \"$remStartArgs\""
            open |$cmd r+
            set startAnew -1
        }
    }

    proc FailedHandoverQuery {hungProc} {
        global relay checkFor
        
        set act [tk_messageBox -title "Simile is not responding" -icon info \
                     -message "Simile is already running, but is currently not responding. Do you want to kill it and start again?" -type okcancel]
        if {[string equal ok $act]} {
# There is an unresponsive instance: how to kill it? make a dummy file
# so it looks like a relay proc then call relay with "done" so it does
# not start anew
            set strm [open $checkFor w]
            puts $strm $hungProc
            close $strm
# if this fails, I hope it means the old Simile is already dead
            catch {exec $relay $checkFor done}
        } else {
# Action cancelled. If I am still waiting for a response I now write
# OhNeverMind, to tell any new procs the old one is hung. If I had a response,
# do nothing. Because I turned off own query (if it was my own) I can only
# check for response by reading the file again...
            set strm [open $checkFor r]
            set tellProc [gets $strm]
            set tellProc [gets $strm] ;# second line is last command passed
            close $strm
#puts "Cancelling: 2nd line is $tellProc"
            if {[string equal AreYouThere [lindex $tellProc 0]]} {
# yep, still waiting...
                set strm [open $checkFor w]
                puts $strm 0
                puts $strm "OhNeverMind $hungProc"
                close $strm
            }
            exit
        }
    }
            
# Scaling affects some metrics but not all, so squash it FTTB
# to ensure consistency (do now cos about to put up dialogues)

# Fixed in 5.4 by explicitly making it apply to everything.
# Silly val for testing: 3.0
# Make conversion easier: pick nice ratio
    set scalRat [ChooseIntegerRatio $defScaling 0.9]
    tk scaling [expr {1.0*[lindex $scalRat 0]/[lindex $scalRat 1]}]

# These are needed for platforms where they would other wise be a fixed number
# of pixels (i.e., -ve size), e.g., X
#    button .b
#    eval font create TkDefaultFont [font actual [.b cget -font]]
#    font configure TkDefaultFont -size 30
#    destroy .b
#    option add *Button.font TkDefaultFont

# ok, is anybody out there?

    set checkFor [file join $SIMILE_PATH Examples handover.txt]
    if {![file exists $checkFor] && [info exists custom(prefDir)]} {
        set checkFor [file join $custom(prefDir) handover.txt]
    } 
    if {[file exists $checkFor]} {
        set strm [open $checkFor r]
        set tellProc [gets $strm]
        set tellProc [gets $strm] ;# second line is last command passed
        close $strm
#puts "Starting up: 2nd line is $tellProc"
# ping to see if old proc there
        set relay [file join $SIMILE_PATH System bin relay]
        switch -regexp [lindex $tellProc 0] {
            OhNeverMind {
# we already did the hung instance dialogue and chose to cancel. No resolution
# since, so do it again.
                FailedHandoverQuery [lindex $tellProc 1]
            } AreYouThere {
# One instance is waiting for another, probably hung, instance to respond, or
# displaying the dialogue box. Don't confuse issues by starting a third.
#                exit
# Actually something more sinister may have happened, e.g. both instances were
# killed while the dilaogue box was up, so wait 5, then check again, and if
# no change, assume the worst.
		after 5000
                set strm [open $checkFor r]
                set tellProc [gets $strm]
                set tellProc [gets $strm] ;# second line is last command passed
                close $strm
		if {[string equal AreYouThere [lindex $tellProc 0]]} {
		    FailedHandoverQuery 0
		} else {
		    exit
		}
            } Ready {
# Another instance appears ready and waiting, ask it to take over...we have to check it is running first as we cannot take back a command that we abandon cos the wait is too long
                set remStartArgs "AreYouThere"
                set cmd "\"$relay\" \"$checkFor\" \"$remStartArgs\""
# relay waits on stdin so it exits when Simile does, so must open it r+ or it
# tries to use console stdin, hanging simile
                set relayProc [open |$cmd r+]
                fconfigure $relayProc -blocking 0
                fileevent $relayProc readable "HandOver $relayProc"
# but be ready in case it fails to do so
                set escapeDlg [after 3000 set startAnew 0]
                tkwait variable startAnew
                switch -- $startAnew {
                    1 {
			after cancel $escapeDlg ;# process was dead
		    } 0 {
			fileevent $relayProc readable {} ;# no longer care
			close $relayProc
			FailedHandoverQuery [lindex $tellProc 1]
		    } -1 {
			exit ;# handed over successfully
		    }
                }
                unset startAnew
            }
        }
    }
}

    if {$argc} {
#	if {[string match relative [file pathtype $argv]]} {
#	    set env(OPEN_MODEL) [pwd]/$argv
#	} else {
#	    set env(OPEN_MODEL) $argv
#	}
	set env(OPEN_MODEL) [file normalize $argv]
    } 

switch $tcl_platform(platform) {
    windows {
# This is needed for dll interface with tcl later than 8.0p2
	dde servername $oldProc
#	set env(TCL_LIBRARY) [info library]
# Now, win95 etc needs the tcltk binaries in the path
	set env(PATH) "[file dirname [file dirname [info library]]]/bin;$env(PATH)"
	set env(PRINTCMD) {{c:/program files/ghostgum/gsview/gsprint} -colour -query}
	set graph(origin) 2
    } unix {
	tk appname $oldProc ;# in case starting it from SimileAutoObj
# library path now set in launcher script
#   set env(LD_LIBRARY_PATH) \
#       $env(SP_PATH)/library:[file dirname [info library]]
    # the following can be edited for your configuration
	set env(PRINTCMD) lpr
        if [string match Darwin $tcl_platform(os)] {
            set graph(origin) 3
        } else {
	    set graph(origin) 1
        }
    }
}

set env(SIMILE_VERSION) 5.7
set sendvars(simP) {}

# KDE launch feedback will fail unless root window is displayed
# briefly, causing annoying eye candy to persist while program is
# running.  It may be necessary to have the launch icon execute this
# file rather than the launcher script to avoid this effect -- make
# sure the first line points to <Simile>/System/bin/wish This is also
# the reason why this file must have Unix style line ends

# Sadly we cannot use the root window for the splash screen because
# that needs overrideredirect, which also stops launch feedback
# working. And do not think we can turn off redirect after displaying
# it, that does not work.  So we do our best to hide the brief
# appearance of the root window by giving it the same coordinates as
# the splash screen so it is hidden behind. (This does not work in XP
# so instead try putting it off the screen)

# Also, when we paste we do not know whether the selection has been
# encoded as utf-8 or not, but Tcl knows and will do the right thing
# if pasting into an entry box. So why struggle -- make an entry box
# where no-one can see it, and when pasting into canvas text, paste
# into that then read the text from it. However this does not work
# under Linux unless the entry box has been displayed -- at least
# briefly -- and my hopes that the problem would be fixed by not
# changing the system encoding were groundless. So add the entrybox
# here.

# of course, none of these apply if using the scripting interface.

entry .hidden_e
pack .hidden_e

# Here because needed for splash screen
proc GrowImage {fCol mw mh} {
    set srcWidth [$fCol cget -width]
    set srcHeight [$fCol cget -height]
    # Resize X and Y axes separately to avoid making too large an
    # intermediate image
    set xrat [ChooseIntegerRatio [expr {$mw/0.9/$srcWidth}] 0.9]
    image create photo spare1
    spare1 copy $fCol -zoom [lindex $xrat 0] 1 -shrink
    image create photo spare2
    spare2 copy spare1 -subsample [lindex $xrat 1] 1 -shrink
    
    set yrat [ChooseIntegerRatio [expr {$mh/0.9/$srcHeight}] 0.9]
    spare1 blank
    spare1 copy spare2 -zoom 1 [lindex $yrat 0] -shrink
    spare2 blank
    spare2 copy spare1 -subsample 1 [lindex $yrat 1] -shrink
    
    image delete spare1
    # copying does not update image's size parameter -- do it by hand
    set srcWidth [expr $srcWidth*[lindex $xrat 0]/[lindex $xrat 1]]
    set srcHeight [expr $srcHeight*[lindex $yrat 0]/[lindex $yrat 1]]
    spare2 config -width $srcWidth
    spare2 config -height $srcHeight
    return spare2
}

set sphXdiam [expr {int(400*[tk scaling])}]
set sphYdiam [expr {int(316*[tk scaling])}]
set iconDiam [expr {int(30*[tk scaling])}]

set startGeom +[expr ([winfo screenwidth .]-$sphXdiam)/2]+[expr ([winfo screenheight .]-$sphYdiam)/2-200]
if {[string equal Linux $tcl_platform(os)]} {
    wm geometry . $startGeom
} else {
    wm geometry . +0+[winfo screenheight .]
}

# first put up the splash screen
source $SIMILE_PATH/Run/language.tcl
image create photo splash -width 90 -height 90

splash read $SIMILE_PATH/Images/bigsimile.gif -shrink
set splash [GrowImage splash $iconDiam $iconDiam]

set graph(font) [list helvetica 12 bold]
set graph(megafont) [list helvetica 36 bold]
toplevel .splash
pack [canvas .splash.c -width $sphXdiam -height $sphYdiam -bd -$graph(origin) \
	 -bg \#f0f8ff] -padx 0 -pady 0

for {set y 0} {$y < $sphYdiam} {incr y 4} {
    if {$y>=$sphYdiam*0.18 && $y<$sphYdiam*0.27} {
	set r 400
	set shade \#ccffcc
    } else {
	set r 84
	set shade \#339933
    }
    .splash.c create rectangle 0p $y ${r}p [expr {$y+2}] \
	-outline {} -fill $shade
}
.splash.c create image 36p 28p -image $splash
set graph(anality) "\ua9 [tr. {Copyright Simulistics Ltd.}] 2001-2010"
.splash.c create text 395.0p 45.0p -font $graph(font) -fill \#99cc99 -anchor e \
    -text $graph(anality)
.splash.c create text 250.0p 225.0p -font $graph(megafont) -fill #660066 \
    -text [tr. "Simile"]
.splash.c create text 250.0p 290.0p -font $graph(font) -fill #660066 -anchor s \
    -text "[tr. Version] $env(SIMILE_VERSION)$sendvars(simP)"
set regInfo $env(licensee_name)
catch {append regInfo ", $env(licensee_corp)"}
.splash.c create text 250.0p 310.0p -font $graph(font) -fill #660066 -anchor s \
    -text "[tr. {Registered to}] $regInfo"

wm geometry .splash $startGeom
wm overrideredirect .splash 1

if {[info exists SimileAutoObjLoaded]} {
    wm withdraw .splash
} else {
    update
}

# now before we put up any regular Simile windows, reset the scaling, because
# a change in monitor layout may cause it to be reset for us, resulting in bad
# screen coordinates
tk scaling $defScaling

wm withdraw . ;# already withdrawn if not Linux
# after 5000 ;# pause to admire

# This is the folder that AME should start looking for model
# files in -- must be an existing subfolder of the installation folder
cd $SIMILE_PATH/Examples

# tk_messageBox -title debug -icon info \
#   -message "TCL library is [info library]\n \
#   Model is $env(OPEN_MODEL)" -type ok

# this runs a program which starts AME from a saved state
# -- must be concurrent because script causes Windows problems if
# not finished

switch $env(prologId) {
    gnu {
	set tgt Run/xgsimile
    } sicstus {
	set tgt System/bin/sprt
    }
}

switch $tcl_platform(platform) {
    windows {
	set archExtn {}
	set execExtn .exe
    } unix {
	if {[string equal Darwin $tcl_platform(os)]} {
# experiment with fatties
	    set archExtn _mac
	} else {
	    set archExtn {}
	}
	set execExtn {}
    }
}

switch $env(interfaceId) {
    pipe {
#	set whatCalled [file rootname [file tail [info nameofexecutable]]]
	set PROLOG_CMD $SIMILE_PATH/$tgt$archExtn$execExtn
	source ../Run/toolbox.tcl
	source ../Run/prolog.tcl
# next bit was to enable same file as simile.exe to use as script launcher
# Abandoned because it didn't start the COM interface properly
#    if {[string equal SimileScript $whatCalled]} {
#	package require SimileAutoObj
#	foreach parent [array name window_info *,parent] {wm withdraw $window_info($parent)}
#	console title SimileScript
#	console eval {wm protocol . WM_DELETE_WINDOW {consoleinterp eval {prolog tk_kill_everything(_)}}}
#	console eval {puts -nonewline "Welcome to Simile Scripting\n% "}
#	console show
#    }
    } dll {
	exec $SIMILE_PATH/$tgt$archExtn$execExtn &
    } console {
	set ::argv0 {} ;# stops error message loading tclmath
	source ../Run/toolbox.tcl
#	rename prolog innerProlog
#	proc prolog {args} {
#	    ShowWatchWhileDoing [concat innerProlog $args]
#	}
    } none {
	source ../Run/toolbox.tcl
# now we must replace some procedure definitions that don't work without Prolog
	proc prolog {plCmd} {
	    global fromProlog
	    switch -glob $plCmd {
		tk_get_info(*,*,*) {
		    set fromProlog "Model declarations unavailable"
		} check_use(*) {
		} tk_run_settings_tweaked(*) {
		} tk_menu(*,*,'run_*') {
		    set lPtr [expr {[string last _ $plCmd]+1}]
		    set lang [string range $plCmd $lPtr end-2]
		    load_dll $::dummyNode $lang $::myDir {} {} {}
		    LoadProgram $::dummyNode $lang
		} default {
		    error "Unhandled Prolog command $plCmd"
		}
	    }
	}
#	proc GetExecTitle {node} {return $node}
	proc RunEnv::Destroy {args} {
	    exit
	}
# Cheekily try initializing the whole works
	set dummyNode none
	ControlDraw $dummyNode
# now open up
	set myDir [file join $::simtmpdir exec]
	destroy .splash
	if {![info exists env(OPEN_MODEL)]} {
	    set env(OPEN_MODEL) [ChooseFile any.sml "Model to execute:" 0 {}]
	}
	LoadFile $dummyNode $myDir $env(OPEN_MODEL)
	OpenProjectFile $myDir
    }
}
