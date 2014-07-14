# Tcl package index file, version 1.0

if {![package vsatisfies [package provide Tcl] 8.6]} {return}
switch [info sharedlibextension] {
    .dylib {
	package ifneeded itcl 4.0b4 [list load [file join $dir \
						    "libitcl4.0b4.dylib"] itcl]
    } .so {
	package ifneeded Itcl 4.0b3 [list load [file join $dir \
						    "libitcl4.0b3.so"] itcl]
    } .dll {
        package ifneeded Itcl 4.0b7 [list load [file join $dir \
						    "itcl40b7.dll"] itcl]
    }
}
