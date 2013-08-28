#
# Encoding of uri's and file names. Some code from tcllib.
# Parts: Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
# extend the uri package to deal with URN (RFC 2141)
# see http://www.normos.org/ietf/rfc/rfc2141.txt
#
# $Id: uriencode.tcl,v 1.1 2013/08/28 07:52:26 u45169214 Exp $

package require uri::urn

package provide uriencode 1.0

namespace eval uriencode {}

# uriencode::quotepath --
#
# Need to carefully avoid encoding any / in volume specifiers.
# /root/... or C:/disk/...
# Always return path using unix separators "/"

proc uriencode::quotepath {path} {
    
    set isrel [string equal [file pathtype $path] "relative"]

    if {!$isrel} {

# An absolute path.
# Be sure to get rid of unix style "/" and windows "C:/"
   set plist [file split [string trimleft $path /]]
set qpath [::uri::urn::quote [string trimright [lindex $plist 0] /]]
foreach str [lrange $plist 1 end] {
lappend qpath [::uri::urn::quote $str]
}	
    } else {

# A relative path.
set qpath [list]
foreach str [file split $path] {
lappend qpath [::uri::urn::quote $str]
}
    }
    
    # Build unix style path
    set qpath [join $qpath /]
    if {!$isrel} {
set qpath "/$qpath"
    }
    return $qpath
}

proc uriencode::quoteurl {url} {

    # Only the file path part shall be encoded.
    if {![regexp {([^:]+://[^:/]+(:[0-9]+)?)(/.*)} $url \
match prepath x path]} {
return -code error "Is not a valid url: $url"
    }
    set path [string trimleft $path /]
    return "${prepath}/[uriencode::quotepath $path]"
}

proc uriencode::decodefile {file} {
    return [::uri::urn::unquote $file]
}

proc uriencode::decodeurl {url} {
    return [::uri::urn::unquote $url]
}

#-----------------------------------------------------------------------

