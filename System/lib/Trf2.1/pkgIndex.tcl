switch [info sharedlibextension] {
    .so {set trfPkg libTrf2.1.so}
    .dylib {set trfPkg libTrf2.1.dylib}
    .dll {set trfPkg Trf21.dll}
}
package ifneeded Trf 2.1  [list load [file join $dir $trfPkg]]
