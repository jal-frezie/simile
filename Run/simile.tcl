#!/home/jaspert/Simile/System/bin/wish
# Simile source code file: Run/simile.tcl
#
# (c) Simulistics Ltd. 2001-2005
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
set SIMILE_PATH [file dirname [file dirname $scriptCmd]]
set env(SP_PATH) $SIMILE_PATH/System
# Above seems unnecessary for sicstus 3.10


if {$argc && ![string match Darwin $tcl_platform(os)] } {
    if {[string match relative [file pathtype $argv]]} {
    set env(OPEN_MODEL) [pwd]/$argv
    } else {
    set env(OPEN_MODEL) $argv
    }
} 
if [string match Darwin $tcl_platform(os)] {
    lappend auto_path $SIMILE_PATH/System/lib
    proc ::tk::mac::OpenDocument {args} {
        global env
# only opens the first of a group of files dropped or double-clicked,
# but at least it handles files with spaces in the name.      
        set env(OPEN_MODEL) [lindex $args 0]
        OpenTopLevel [lindex $args 0]
    }
}

# If Simile is already running, make a new window there and exit. Note that
# on Macs the OpenDocument takes care of this and we don't even get this far
# OTOH, if Simile is not running already, need to skip the following on Macs.

if ![string match aqua [tk windowingsystem]] {
    if {[info exists env(OPEN_MODEL)]} {
        set remStartArgs [list after idle [list OpenTopLevel $env(OPEN_MODEL)]]
    } else {
        set remStartArgs NewTopLevel
    }
 
    if {[catch [concat $runHow(sendCmd) {$remStartArgs}]]} {
# Simile not already running, so just continue
    } else {
# Simile already running, so quit this fresh start
        exit
    }   
}

switch $tcl_platform(platform) {
    windows {
# This is needed for dll interface with tcl later than 8.0p2
    dde servername $oldProc
    set env(TCL_LIBRARY) [info library]
# Now, win95 etc needs the tcltk binaries in the path
    set env(PATH) "[file dirname [file dirname [info library]]]/bin;$env(PATH)"
    set env(PRINTCMD) {{c:/program files/ghostgum/gsview/gsprint} -colour -query}
    set graph(origin) 2
        set graph(font) [list helvetica 10]
    } unix {
    tk appname $oldProc ;# in case starting it from SimileAutoObj
# library path now set in launcher script
#   set env(LD_LIBRARY_PATH) \
#       $env(SP_PATH)/library:[file dirname [info library]]
    # the following can be edited for your configuration
    set env(PRINTCMD) lpr
        if [string match Darwin $tcl_platform(os)] {
            set graph(origin) 3
            set graph(font) [list helvetica 12]
        } else {
        set graph(origin) 1
            set graph(font) [list helvetica 10]
        }
    }
}

if {[string equal windows $tcl_platform(platform)]} {
    package require registry
    foreach regEntry {prologId interfaceId install_time license_code \
			licensee_name licensee_corp SIMILE_VERSION} {
	set regKey HKEY_LOCAL_MACHINE\\Software\\Simulistics\\Simile
	set env($regEntry) [registry get $regKey $regEntry]
    }
} else {
    set UserStream [open $SIMILE_PATH/Run/userinfo.txt r]
    gets $UserStream env(prologId)
    gets $UserStream env(interfaceId)
    gets $UserStream env(install_time)
    gets $UserStream env(license_code)
    gets $UserStream env(licensee_name)
    gets $UserStream env(licensee_corp)
    gets $UserStream env(SIMILE_VERSION)
    close $UserStream
}

# KDE launch feedback will fail unless root window is displayed briefly,
# causing annoying eye candy to persist while program is running.
# It may be necessary to have the launch icon execute this file rather than the
# launcher script to avoid this effect -- make sure the first line points to
# <Simile>/System/bin/wish
# This is also the reason why this file must have Unix style line ends

# first put up the splash screen
image create photo splash
splash read $SIMILE_PATH/Images/splash.gif

# Sadly we cannot use the root window for the splash screen because that
# needs overrideredirect, which also stops launch feedback working. And do
# not think we can turn off redirect after displaying it, that does not work.
# So we do our best to hide the brief appearance of the root window by giving
# it the same geometry as the splash screen...

set startGeom +[expr [winfo screenwidth .]/2-200]+[expr [winfo screenheight .]/2-158]
if {[string equal Linux $tcl_platform(os)]} {
    wm geometry . $startGeom
    update
}
wm withdraw .

toplevel .splash
pack [canvas .splash.c -width 400 -height 316 -bd -$graph(origin)] -padx 0 -pady 0
.splash.c create image 200 158 -image splash
.splash.c create text 270.0 275.0 -font $graph(font) -fill #660066 -text "Version $env(SIMILE_VERSION)"
set regInfo $env(licensee_name)
catch {append regInfo ", $env(licensee_corp)"}
.splash.c create text 270.0 295.0 -font $graph(font) -fill #660066 -text "Registered to $regInfo"
    
wm geometry .splash $startGeom
wm overrideredirect .splash 1
update

# temporary to get wkng with local tcltk
# lappend auto_path $SIMILE_PATH/System/lib

# This is the folder that AME should start looking for model
# files in -- must be a subfolder of the installation folder
cd $SIMILE_PATH/Run

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
    set execExtn .exe
    } unix {
    set execExtn {}
# Currently cannot distribute Sicstus for Unix so use GNU anyway
    set tgt Run/xgsimile
    }
}

switch $env(interfaceId) {
    pipe {
	set whatCalled [file rootname [file tail [info nameofexecutable]]]
	set PROLOG_CMD $SIMILE_PATH/$tgt$execExtn
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
	exec $SIMILE_PATH/$tgt$execExtn &
    }
}
