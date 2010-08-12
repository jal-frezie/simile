switch [info sharedlibextension] {
    .so {
	package ifneeded Trf 2.1.2  [list load [file join $dir libTrf2.1.so]]
    } .dll {
	package ifneeded Trf 2.1  [list load [file join $dir Trf21.dll]]
    } .dylib {
	package ifneeded Trf 2.1  [list load [file join $dir libTrf2.1.dylib]]
    }
}