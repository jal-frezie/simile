# SIMILE batch file

# If there is an arg, it is the model to start with. Because this is sourced
# from a script or special .exe there is never more than 1 arg. Windows has
# a buggy implementation of file pathtype so hope that simile.exe always
# gets us an absolute path...

if {[string match windows $tcl_platform(platform)]} {
    package require dde 1.2
    set oldProc Simile
    dde servername $oldProc
    set argv [lindex $argv 0]
} else {
    set oldProc simile.tcl
}

if {$argc && ![string match Darwin $tcl_platform(os)] } {
    if {[string match relative [file pathtype $argv]]} {
	set env(OPEN_MODEL) [pwd]/$argv
    } else {
	set env(OPEN_MODEL) $argv
    }
}

# If simile is already running, make a new window there and exit. Note that
# on Macs the system takes care of this and we don't even get this far

if {![info exists IAmASlave]} {
    if {[info exists env(OPEN_MODEL)]} {
	set remStartCmd [list send $oldProc OpenTopLevel $env(OPEN_MODEL)]
    } else {
	set remStartCmd [list send $oldProc NewTopLevel]
    }
    if {![catch {eval $remStartCmd}]} {
	exit
    }
}

# replace /./ in path with / to avoid confusing file dirname
regsub -all /\\./ [info script] / scriptCmd

#tk_messageBox -title Invocation -icon info -message "$scriptCmd $argv" -type ok
set SIMILE_PATH [file dirname [file dirname $scriptCmd]]
set env(SP_PATH) $SIMILE_PATH/System
# Above seems unnecessary for sicstus 3.10

# temporary to get wkng with local tcltk
# lappend auto_path $SIMILE_PATH/System/lib

switch $tcl_platform(platform) {
    windows {
# This is needed for dll interface with tcl later than 8.0p2
	set env(TCL_LIBRARY) [info library]
# Now, win95 etc needs the tcltk binaries in the path
	set env(PATH) "[file dirname [file dirname [info library]]]/bin;$env(PATH)"
	set env(PRINTCMD) {{c:/program files/ghostgum/gsview/gsprint} -colour -query}
    } unix {
	set env(LD_LIBRARY_PATH) \
		$env(SP_PATH)/library:[file dirname [info library]]
	# the following can be edited for your configuration
	set env(PRINTCMD) lpr
    }
}

set UserStream [open $SIMILE_PATH/Run/userinfo.txt r]
gets $UserStream prologId
gets $UserStream interfaceId
gets $UserStream env(install_time)
gets $UserStream env(license_code)
gets $UserStream env(licensee_name)
gets $UserStream env(licensee_corp)
gets $UserStream env(SIMILE_VERSION)
close $UserStream

# first put up the splash screen
image create photo splash
if {[string match Darwin $tcl_platform(os)]} {
    splash read $SIMILE_PATH/Images/MacSplash.gif
    set auto_path [linsert $auto_path 0 $SIMILE_PATH/System/lib]
} else {
    package require Img
    splash read $SIMILE_PATH/Images/splash.jpg
}
pack [canvas .c -width 510 -height 340]
if {![info exists IAmASlave]} {
    .c create image 255 170 -image splash
    .c create text 392.0 285.0 -font {-weight bold -family helvetica -size 12} -text "Version $env(SIMILE_VERSION)"
    .c create text 392.0 320.0 -font {-family helvetica -size 10} -text "© 2003 Simulistics Ltd."
    
    wm geometry . +[expr [winfo screenwidth .]/2-255]+[expr [winfo screenheight .]/2-170]
    wm overrideredirect . 1
    update
}

# This is the folder that AME should start looking for model
# files in -- must be a subfolder of the installation folder
cd $SIMILE_PATH/Run

set prolog [lindex [split $prologId =] 1]
set interface [lindex [split $interfaceId =] 1]

# tk_messageBox -title debug -icon info \
#	-message "TCL library is [info library]\n \
#	Model is $env(OPEN_MODEL)" -type ok

# this runs a program which starts AME from a saved state
# -- must be concurrent because script causes Windows problems if
# not finished

switch $prolog {
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
    }
}

switch $interface {
    pipe {
	set PROLOG_CMD $SIMILE_PATH/$tgt$execExtn
	source ../Run/toolbox.tcl
	source ../Run/prolog.tcl
    } dll {
	exec $SIMILE_PATH/$tgt$execExtn &
    }
}


