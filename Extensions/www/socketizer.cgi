#!/usr/bin/tclsh
foreach local {sPath sHome mdl shLib} val $argv {
    set $local $val
}

source [file join [file dirname [info script]] client5d.tcl]
set env(HOME) $sHome


# Stuff that needs doing only once
UseSimileAt $sPath
set mH [loadmodel [file join $sHome $shLib] evaluation]
set iH [CreateModel $mH]
set hook {}
set catalog [ListObjPaths $mH]
foreach obj $catalog {
    if {[lsearch {INPUT TABLE} [GetModelProperty $mH $obj Eval]]>-1} {
	lappend hook $obj
	set aH($obj) [CreateParamArray $iH $obj]
    }
}

# now create a server that executes everything it gets at global scope 
# (add security later) and returns the response

proc Server {channel clientaddr clientport} {
    gets $channel parrot
    puts $channel [uplevel #0 $parrot]
    close $channel
}

set typho [socket -server Server 0]
puts [lindex [fconfigure $typho -sockname] end]
vwait forever
