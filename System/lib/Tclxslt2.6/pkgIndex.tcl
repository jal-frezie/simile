# pkgIndex.tcl --
#
#       Handcrafted for TclXSLT.
#
# Copyright (c) 2001-2003 Zveno Pty Ltd
# http://ww.zveno.com/
#
# $Id: pkgIndex.tcl,v 1.1 2004/07/07 14:24:25 jaspert Exp $

# edited by Jasper for dual-boot use and to work with spaces in dirname

switch [info sharedlibextension] {
    .dll {set sharedLib Tclxslt26.dll}
    .so {set sharedLib libTclxslt2.6.so}
}

package ifneeded xslt 2.6 "
    load [file join $dir $sharedLib] Xslt
    source [file join $dir tclxslt.tcl]
"

package ifneeded xslt::cache 2.6 [list source [file join $dir xsltcache.tcl]]

