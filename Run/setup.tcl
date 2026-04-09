# Location of Simile configuration folder
if {[string equal windows $tcl_platform(platform)]} {
#    set homeDir [file attributes $env(HOME) -shortname] ;# is Ascii
    package require registry
    set homeDir [string map [list %USERPROFILE% $env(USERPROFILE)] \
		     [registry get {HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders} {Personal}]] ;# who cares if Ascii
} else {
    set homeDir $env(HOME)
}
if {[info exists embed_args]} {
    set custom(prefDir) {}
} elseif {[file exists $homeDir]} {
# 4.1 moved SimileUserDirectory for Windows -- check in old position and update
    set oldPrefs [file join $homeDir .simile]
    if {[string equal windows $tcl_platform(platform)]} {
        set custom(prefDir) [file join $homeDir "My Simile files"]
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
			  name corp old_version]
# from v5.5, windows installer creates usrinfo.txt rather than writing registry
# if {[string equal windows $tcl_platform(platform)]} {
#     package require registry
#     set regKey HKEY_LOCAL_MACHINE\\Software\\Simulistics\\Simile
#     foreach regEntry $savedCredentials {
# 	catch {set env($regEntry) [registry get $regKey $regEntry]}
#     }
# } else {

proc Newer {is than t} {
    if {![file exists $than]} {
	return 1
    }
    file stat $is foo
    file stat $than bar
    #tk_messageBox -message "$is $foo(${t}time) > $than $bar(${t}time)"
    return [expr {$foo(${t}time) > $bar(${t}time)}]
}

set creds [file join $custom(prefDir) mdlrinfo.txt]
if {$tcl_platform(platform) eq "windows"} {
    set installedCreds [file join $SIMILE_PATH Run mdlrinfo.txt]
    set refreshCreds {[Newer $installedCreds $creds m]}
} else {
    set installedCreds [file join $SIMILE_PATH Run mdlrinfo.tpl]
    set refreshCreds {![file exists $creds]}
}
if $refreshCreds {
    file copy -force $installedCreds $creds
}

set UserStream [open $creds r]
foreach regEntry $savedCredentials {
    gets $UserStream userinfo($regEntry)
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
#if {$tcl_platform(os) ne "Linux" && $tclBitness==64} {
#    append env(SYSDIR) 64
#}
set libDir [file join $env(SYSDIR) lib]

set use_system_tcltk 0 ;# use separately installed tcltk and tools
# MacOS and Windows: tools are bundled iff running binary distro
if {$tcl_platform(os) eq "Linux" || \
	$tcl_platform(os) eq "Darwin" && [file tail [info nameofexecutable]] ne "Simile" || \
    	$tcl_platform(platform) eq "windows" && [file tail [info nameofexecutable]] ne "Simile.exe"} {
    set use_system_tcltk 1
}
# Avoid system TclTk on MacOS, it's modtly broken and will be removed

if {$use_system_tcltk} {
    set auto_path [linsert $auto_path 0 $libDir]
# special Simile things that cannot be found in standard TclTk
# (or can but they wouldn't be as much use as the bundled version)

# ...also MacOS dosn't actually use system TclTk, just system packages, so
# make sure they are in the path (for e.g. R TclTk extn)
    if {$tcl_platform(os) eq "Darwin"} {
	package require md5 ;# Do now because even querying system package barfs
	lappend auto_path "/System/Library/Tcl"
    }
} elseif {[info exists prolog_in_console]} {
    set auto_path [linsert $auto_path 0 $libDir] ;# must be 8.4, look everywhere
} else {
# may be needed if using included tcltk, but should get it from 
# location of executable
    set auto_path [list $libDir]
# May need to reinstate this for non-system-tcl case to avoid msgcat err
    lappend auto_path $tcl_library $tk_library
}

# read layout data now so scaling can be set before GUI started
if {[file exists $custom(prefDir)/.layout]} {
    set stm [open $custom(prefDir)/.layout r]
    foreach item {full geom theme text} {
	gets $stm custom(layout,$item)
    }
    close $stm
}

set ::headless 1 ;# for R etc

