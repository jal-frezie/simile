if {[catch {package require Tcl 8.2}]} return
switch [info sharedlibextension] {
    .dll {set imgLib Tktable28.dll}
    .so {set imgLib libTktable2.8.so}
}
package ifneeded Tktable 2.8  [list load [file join $dir $imgLib] Tktable]
