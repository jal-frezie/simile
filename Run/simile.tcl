# SIMILE batch file

# replace /./ in path with / to avoid confusing file dirname
regsub -all /\\./ [info script] / scriptCmd

#tk_messageBox -title Invocation -icon info -message "$scriptCmd $argv" -type ok
set SIMILE_PATH [file dirname [file dirname $scriptCmd]]
set env(SP_PATH) $SIMILE_PATH/System

switch $tcl_platform(platform) {
    windows {
# This is needed for dll interface with tcl later than 8.0p2
	set env(TCL_LIBRARY) [info library]

# Try to find the location of the compiler
	if {[info exists env(MSVCDIR)]} {
	    # No problem, all is well
	} elseif {[info exists env(MSDEVDIR)]} {
	    # later msvc -- move the variable
	    set env(MSVCDIR) $env(MSDEVDIR)
	} else {
	    # guess the location
	    set env(MSDEVDIR) d:/progra~1/micros~1/vc98
	    set env(MSVCDIR) $env(MSDEVDIR)
	}
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
package require Img
image create photo splash
splash read $SIMILE_PATH/Images/splash.jpg
pack [canvas .c -width 510 -height 340]
.c create image 255 170 -image splash
.c create text 392.0 285.0 -font {-weight bold -family helvetica -size 12} -text "Version $env(SIMILE_VERSION)"
.c create text 392.0 320.0 -font {-family helvetica -size 10} -text "© 2002 Simulistics Ltd."

wm geometry . +[expr [winfo screenwidth .]/2-255]+[expr [winfo screenheight .]/2-170]
wm overrideredirect . 1
update

# Find a new temporary directory
if {[info exists env(TMP)]} {
    set tempDir $env(TMP)
} else {
    if {[info exists env(TEMP)]} {
	set tempDir $env(TEMP)
    } else {
	if {[string match windows $tcl_platform(platform)]} {
	    set tempDir /temp
	} else {
	    set tempDir /tmp
	}
    }
}

if [string match windows $tcl_platform(platform)] {
    set tempDir [file attributes $tempDir -shortname]
    set tempDir [file join [file dirname $tempDir] [file tail $tempDir]]
}

set tester $tempDir/sim
set go [clock clicks]
while {[file exists $tester]} {
    set guess_free [expr [clock clicks]-$go]
    set tester $tempDir/sim$guess_free
}
#tk_messageBox -title debug -icon info \
#	-message "Temp dir is $tester" -type ok

set env(SIMTMPDIR) $tester
file mkdir $env(SIMTMPDIR)/.lock

# If there is an arg, it is the model to start with. Because this is sourced
# from a script or special .exe there is never more than 1 arg
if {$argc} {
    if {[string match relative [file pathtype $argv]]} {
	set env(OPEN_MODEL) [pwd]/$argv
    } else {
	set env(OPEN_MODEL) $argv
    }
}

# Directory to start in
set env(START_DIR) $SIMILE_PATH/Examples ; # was $SIMILE_PATH/Tutorial or [pwd]

# This is the folder that AME should start looking for model
# files in -- must be a subfolder of the installation folder
cd $SIMILE_PATH/Run

set prolog [lindex [split $prologId =] 1]
set interface [lindex [split $interfaceId =] 1]

# tk_messageBox -title debug -icon info \
#	-message "TCL library is [info library]\n \
#	Temp dir is is $env(SIMTMPDIR)\n \
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
	source toolbox.tcl
	source prolog.tcl
    } dll {
	exec $SIMILE_PATH/$tgt$execExtn &
	# wait till prog is going before removing splash
	set pause 0
	while {[file exists $env(SIMTMPDIR)/.lock] && $pause<3000} {
	    incr pause 100
	    after 100
	}
    }
}
