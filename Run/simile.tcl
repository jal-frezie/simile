#!/usr/bin/wish
# SIMILE batch file
# Make sure the first line refers to a version of TclTk with shared libraries

set prolog sicstus
set interface dll

proc GetRealFile {link} {
    if {[catch {set base [file readlink $link]}]} {
	return $link
    }
    if {[string match relative [file pathtype $base]]} {
	set newLink [file dirname $link]/$base
    } else {
	set newLink $base
    }
    return [GetRealFile $newLink]
}

set scriptCmd [info script]
if {[string match relative [file pathtype $scriptCmd]]} {
    set scriptCmd [pwd]/$scriptCmd
}
# replace /./ in path with / to avoid confusing file dirname
regsub -all /\./ [GetRealFile $scriptCmd] / scriptCmd

set SIMILE_PATH [file dirname [file dirname $scriptCmd]]
set env(SP_PATH) $SIMILE_PATH/System
set env(SIMILE_VERSION) 2.93

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
	set env(PATH) "[file dirname [file dirname [info library]]]/bin;c:/progra~1/mingw-2.95.3/bin;$env(PATH)"
	set env(PRINTCMD) {{c:/program files/ghostgum/gsview/gsprint} -colour -query}
    } unix {
	set env(LD_LIBRARY_PATH) \
		$env(SP_PATH)/library:[file dirname [info library]]
	# the following can be edited for your configuration
	set env(PRINTCMD) lpr
    }
}
# first put up the splash screen
image create photo splash
splash read $SIMILE_PATH/Images/splash.gif
pack [canvas .c -width 640 -height 480]
.c create image 320 240 -image splash
# .c create text 450.0 240.0 -font {-weight bold -family helvetica -size 30} -text SIMILE
.c create text 450.0 273.0 -font {-weight bold -family helvetica -size 16} -text "Version $env(SIMILE_VERSION)"
.c create text 450.0 340.0 -font {-family helvetica -size 12} -text "© 2002 Simulistics Ltd."

# pack [label .l -image splash]
wm geometry . +[expr [winfo screenwidth .]/2-320]+[expr [winfo screenheight .]/2-240]
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

# If there is an arg, it is the model to start with. 
if {$argc} {
    set arg1 [lindex $argv 0]
    if {[string match relative [file pathtype $arg1]]} {
	set env(OPEN_MODEL) [pwd]/$arg1
    } else {
	set env(OPEN_MODEL) $arg1
    }
}

# Directory to start in
set env(START_DIR) [pwd] ;# was $SIMILE_PATH/Tutorial

# This is the folder that AME should start looking for model
# files in -- must be a subfolder of the installation folder
cd $SIMILE_PATH/Run

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
	set PROLOG_ERR $tempDir/simerror.txt
	source toolbox.tcl
	source prolog.tcl
    } dll {
	exec $SIMILE_PATH/$tgt$execExtn &
	# wait till prog is going before removing splash
	while {[file exists $env(SIMTMPDIR)/.lock]} {after 100}
	exit
    }
}
