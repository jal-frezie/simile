if {[catch {package require Tcl 8.2}]} return
switch [info sharedlibextension] {
    .dll {set imgLib Tktable29.dll}
    .so {set imgLib libTktable2.9.so}
    .dylib {set imgLib libTktable2.9.dylib}
}

package ifneeded Tktable 2.9  [list load [file join $dir $imgLib] Tktable]

