# Tcl package index file, version 1.0
# dual-boot version by Jasper Taylor

switch [info sharedlibextension] {
    .dll {
	set sharedLib itcl32.dll
    } .so {
	set sharedLib libitcl3.2.so
    }
}
package ifneeded Itcl 3.2 [list load [file join $dir $sharedLib] Itcl]
