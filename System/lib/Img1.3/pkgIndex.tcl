# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

# Customized by Jasper Taylor, Simulistics Ltd. to be dual purpose 
# Windows/Unix

set suff [info sharedlibextension]
if {[string match .so $suff]} {
	set pref lib
	set vers 1.3
	set sysvers 1.0
} else {
	set pref {}
	set vers 13
	set sysvers 10
}

package ifneeded zlibtcl 1.0 [list load [file join $dir ${pref}zlibtcl${sysvers}${suff}]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded zlibtcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ ${pref}zlibtcl${sysvers}${suff}]}]} {
    load [file join @dir@ ${pref}zlibtcl${sysvers}${suff}]
}"]
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded pngtcl 1.0 [list load [file join $dir ${pref}pngtcl${sysvers}${suff}]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded pngtcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ ${pref}pngtcl${sysvers}${suff}]}]} {
    load [file join @dir@ ${pref}pngtcl${sysvers}${suff}]
}"]
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded tifftcl 1.0 [list load [file join $dir ${pref}tifftcl${sysvers}${suff}]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded tifftcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ ${pref}tifftcl${sysvers}${suff}]}]} {
    load [file join @dir@ ${pref}tifftcl${sysvers}${suff}]
}"]
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded jpegtcl 1.0 [list load [file join $dir ${pref}jpegtcl${sysvers}${suff}]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded jpegtcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ ${pref}jpegtcl${sysvers}${suff}]}]} {
    load [file join @dir@ ${pref}jpegtcl${sysvers}${suff}]
}"]
}
# -*- tcl -*- Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded img::base 1.3 [list load [file join $dir ${pref}tkimg${vers}${suff}]]

package ifneeded Img   1.3 {
    # Compatibility hack. When asking for the old name of the package
    # then load all format handlers and base ${pref}raries provided by tkImg.
    # Actually we ask only for the format handlers, the required base
    # packages will be loaded automatically through the usual package
    # mechanism.

# We only need .jpeg for simile -- JAT
#    package require img::bmp
#    package require img::gif
#    package require img::ps
#    package require img::window
#    package require img::xbm
#    package require img::xpm
#    package require img::ico
#    package require img::pcx
#    package require img::ppm
#    package require img::sgi
#    package require img::sun
#    package require img::tga
    package require img::jpeg
#    package require img::png
#    package require img::tiff
#    package require img::pixmap

    package provide Img 1.3
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::bmp" 1.3 [list load [file join $dir ${pref}tkimgbmp${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::gif" 1.3 [list load [file join $dir ${pref}tkimggif${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::ico" 1.3 [list load [file join $dir ${pref}tkimgico${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::jpeg" 1.3 [list load [file join $dir ${pref}tkimgjpeg${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::pcx" 1.3 [list load [file join $dir ${pref}tkimgpcx${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::pixmap" 1.3 [list load [file join $dir ${pref}tkimgpixmap${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::png" 1.3 [list load [file join $dir ${pref}tkimgpng${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::ppm" 1.3 [list load [file join $dir ${pref}tkimgppm${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::ps" 1.3 [list load [file join $dir ${pref}tkimgps${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::sgi" 1.3 [list load [file join $dir ${pref}tkimgsgi${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::sun" 1.3 [list load [file join $dir ${pref}tkimgsun${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::tga" 1.3 [list load [file join $dir ${pref}tkimgtga${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::tiff" 1.3 [list load [file join $dir ${pref}tkimgtiff${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::window" 1.3 [list load [file join $dir ${pref}tkimgwindow${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::xbm" 1.3 [list load [file join $dir ${pref}tkimgxbm${vers}${suff}]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.1 2004/03/23 15:32:30 jaspert Exp $

package ifneeded "img::xpm" 1.3 [list load [file join $dir ${pref}tkimgxpm${vers}${suff}]]
