#!/usr/bin/tclsh
foreach local {sPath sHome mdl shLib} val $argv {
    set $local $val
}

set env(HOME) $sHome
lappend auto_path [file join $sPath System lib] ;# ce qui compte...
source [file join $sPath Extensions Simile exec client5d.tcl]


# Stuff that needs doing only once
UseSimileAt $sPath

proc InstallModelExec {shLib} {
catch {
 global mH iH aH catalog
 set mH [loadmodel [file join $::sHome $shLib] evaluation]
 set iH [CreateModel $mH]
 set hook {}
 set catalog [ListObjPaths $mH]
 foreach obj $catalog {
    if {[lsearch {INPUT TABLE} [GetModelProperty $mH $obj Eval]]>-1} {
	lappend hook $obj
	set aH($obj) [CreateParamArray $iH $obj]
    }
 }
 llength $catalog} res
 return $res
}

# now create a server that executes everything it gets at global scope 
# (add security later) and returns the response

proc Server {channel clientaddr clientport} {
    gets $channel parrot
    if {[catch {uplevel #0 $parrot} resp]} {
	puts $channel "ERROR: $::errorInfo"
    } else {
        puts $channel $resp
    }
    close $channel
}

InstallModelExec $shLib
set typho [socket -server Server 0]
set sockId [lindex [fconfigure $typho -sockname] end]

# OLD php: the php proc_open() will not return till the process finishes,
# so use file to send socket id
# set dmp [open ${mdl}.rdy w]
# puts $dmp $sockId
# close $dmp

# SENSIBLE php: we can just echo the server ID
puts $sockId
vwait forever
