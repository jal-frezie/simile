switch [info sharedlibextension] {
    .so {set trfPkg libTrf2.1.2.so}
    .dylib {set trfPkg libTrf2.1.dylib}
    .dll {set trfPkg Trf21.dll}
}
set dir [file dirname [info script]]
load [file join $dir $trfPkg]
package provide Trf 2.1
