# pkgIndex.tcl - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sf.net>
#
# This package requires Tk 8.4. On Windows we have a further requirement for 
# 8.4.6 due to some internal stubs table additions.
#
# The package will simply not be provided on incompatible versions.

namespace eval ::platform {
    proc platform {} {
        global tcl_platform
        set plat [lindex $tcl_platform(os) 0]
        set mach $tcl_platform(machine)
        switch -glob -- $mach {
            sun4* { set mach sparc }
            intel -
            i*86* { set mach x86 }
            "Power Macintosh" { set mach ppc }
	    x86_64 { if {$tcl_platform(wordSize)==4} { set mach x86 }}
        }
        switch -- $plat {
          AIX   { set mach ppc }
          HP-UX { set mach hppa }
        }
        if {[string equal $plat "Darwin"] \
                && [llength [info command ::tk]] != 0} {
            append mach -[::tk windowingsystem]
        }
        return "$plat-$mach"
    }
}

if {![package vsatisfies [package provide Tcl] 8.4]} {return}
if {[string equal $::tcl_platform(platform) "windows"]
    && ![package vsatisfies [info patchlevel] 8.4.6]} { return }
package ifneeded tile 0.7.8 \
        "namespace eval ::tile { variable library [list $dir] };\
         load \[file join [list $dir] \[::platform::platform\] \
             tile078[info sharedlibextension]\] tile"
