package ifneeded gdal 1.0  [list gdal::gdal_load $dir]

namespace eval gdal {
    proc gdal_load {dir} {
	global tcl_platform

	switch [info sharedlibextension] {
	    .dll {set imgLib gdal_tcl.dll}
	    .so {set imgLib libgdal_tcl.so}
# 	    .dylib {set imgLib libgdal_tcl_$tcl_platform(machine).dylib}
# Mac: Try to use a fattie 
	    .dylib {set imgLib libgdal_tcl.dylib}
	}
	
	load [file join $dir $imgLib] gdal
    }
}

