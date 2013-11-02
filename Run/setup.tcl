# Location of Simile configuration folder
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
	if {[string equal "Windows NT" $tcl_platform(os)]} {
	    if {[info exists ::loadedFromR]} {
		set docsDir . ;# home dir already includes "Documents"
	    } elseif {$tcl_platform(osVersion)>=6.0} {
		set docsDir Documents
	    } else {
		set docsDir "My Documents"
	    }
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

if {![file exists $custom(prefDir)]} {
    file mkdir $custom(prefDir)
}

# Load licensing information
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

set installedCreds [file join $SIMILE_PATH Run userinfo.txt]
set creds [file join $custom(prefDir) userinfo.txt]
if {![file exists $creds] || [file atime $installedCreds]>[file atime $creds]} {
    file copy -force $installedCreds $creds
}

set UserStream [open $creds r]
foreach regEntry $savedCredentials {
    gets $UserStream env($regEntry)
}
close $UserStream
# }

# Set bitness
set tclBitness [expr {8*$tcl_platform(wordSize)}]
if {[info exists tcl_platform(pointerSize)]} {
    set tclBitness [expr {8*$tcl_platform(pointerSize)}]
}

# Set location of Tcl extension packages
set env(SYSDIR) [file join $SIMILE_PATH System]
if {$tcl_platform(os) ne "Linux" && $tclBitness==64} {
    append env(SYSDIR) 64
}
set libDir [file join $env(SYSDIR) lib]

set use_system_tcltk 0 ;# use separately installed tcltk and tools
if {$tcl_platform(os) eq "Linux" || \
	$tcl_platform(os) eq "Darwin" && $tclBitness==64} {
    set use_system_tcltk 1
}
if {$use_system_tcltk} {
    lappend auto_path [file join $libDir Stubs]
# special Simile things that cannot be found in standard TclTk
} elseif {[info exists prolog_in_console]} {
    set auto_path [linsert $auto_path 0 $libDir] ;# must be 8.4, look everywhere
} else {
# may be needed if using included tcltk, but should get it from 
# location of executable
    set auto_path [list $libDir]
# May need to reinstate this for non-system-tcl case to avoid msgcat err
    if {[string equal Darwin $tcl_platform(os)]} {
	lappend auto_path [file dirname $SIMILE_PATH]/Frameworks/Tcl.framework/Resources/Scripts [file dirname $SIMILE_PATH]/Frameworks/Tk.framework/Resources/Scripts
    } else {
	lappend auto_path [file join $libDir tcl[info tclversion]] \
	    [file join $libDir tk[info tclversion]]
    }
}
