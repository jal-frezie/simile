#!/usr/bin/tclsh
foreach local {sPath sHome mdl shLib} val $argv {
    set $local $val
}

set env(HOME) $sHome
lappend auto_path [file join $sPath System lib] ;# ce qui compte...
source [file join $sPath Extensions R Simile exec client5d.tcl]


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
	# Not needed if loading from .spf, and can mess up per-record
	# set aH($obj) [CreateParamArray $iH $obj]
    }
 }
 llength $catalog} res
 return $res
}

InstallModelExec $shLib

# now create a server that executes everything it gets at global scope 
# (add security later) and returns the response

# Version using INET sockets -- ungainly and insecure
#proc Server {channel clientaddr clientport} {
#    gets $channel parrot
#    if {[catch {uplevel #0 $parrot} resp]} {
#	puts $channel "ERROR: $::errorInfo"
#    } else {
#        puts $channel $resp
#    }
#    close $channel
#}
#
#set typho [socket -server Server 0]
#set sockId [lindex [fconfigure $typho -sockname] end]
#
## OLD php: the php proc_open() will not return till the process finishes,
## so use file to send socket id
## set dmp [open ${mdl}.rdy w]
## puts $dmp $sockId
## close $dmp
#
## SENSIBLE php: we can just echo the server ID
#puts $sockId
#vwait forever

# Version using UNIX sockets -- add .uxs extension to model name base
# shell command version 
# set tpond [open "|/usr/bin/nc -Ulk ${mdl}.uxs" r+]
# while {![eof $tpond]} {
#     gets $tpond parrot
#     if {[catch {uplevel #0 $parrot} resp]} {
# 	puts $tpond "ERROR: $::errorInfo"
#     } else {
#         puts $tpond $resp
#     }
#     flush $tpond
# }
# 
# package version
package require unix_sockets

proc accept {tpond} {
    gets $tpond parrot
    # set stm [open ${::mdl}.log a]
    # puts $stm "> $parrot"
    # flush $stm
    if {[catch {uplevel #0 $parrot} resp]} {
	puts $tpond "ERROR: $::errorInfo"
    } else {
	# puts $stm "< $resp"
        puts $tpond $resp
    }
    # close $stm
    close $tpond
}

unix_sockets::listen ${mdl}.uxs accept
vwait forever
