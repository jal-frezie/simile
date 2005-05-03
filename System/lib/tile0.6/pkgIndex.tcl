# This package is built with Tk stubs for 8.4.6+ but we also provide a version
# for that is linked to tk84.dll for Tk 8.4.0-8.4.5.
# The package cannot be used with Tk < 8.4
#

# customized by Jasper to load appropriate executable for OS
switch [info sharedlibext] {
    .dll {
    if {![package vsatisfies [package provide Tcl] 8.4]} {return}
    set S {}
    if {[info exists ::tcl_platform(threaded)]} {append S t}
    if {[info exists ::tcl_platform(debug)]} {append S g}
    if {[package vsatisfies [package provide Tcl] 8.5] 
	|| [package vsatisfies [info patchlevel] 8.4.6]} {
	package ifneeded tile 0.6 \
	    "namespace eval tile {variable library \"$dir\"};\
       load \"[file join $dir tile06$S.dll]\""
    } else {
	package ifneeded tile 0.6 \
	    "namespace eval tile {variable library \"$dir\"};\
       load \"[file join $dir tile06ns$S.dll]\""
    }
    unset S
    } .so {
    package ifneeded tile 0.6.2 \
	[list load [file join $dir tile[info sharedlibext]]]
    } .dylib {
    package ifneeded tile 0.6.2 \
	[list load [file join $dir libtile0.6[info sharedlibext]]]
    }
}
