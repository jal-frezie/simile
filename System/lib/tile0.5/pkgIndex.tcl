if {[catch {package require Tcl 8.4}]} return
switch [info sharedlibextension] {
    .so {
	set lib libtile0.5.so
    } .dll {
	set lib tile05.dll
    }
}
package ifneeded tile 0.5  [list load [file join $dir $lib] tile]
