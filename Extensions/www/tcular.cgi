#!/usr/bin/tclsh
encoding system utf-8
foreach local {sPath sHome mdl shLib} val $argv {
    set $local $val
}
puts "Here [pwd] args $argv<br>"
exec echo {} > /tmp/error-output.txt
lappend auto_path [file join $sPath System lib]
if {![file exists [file join $sHome .simile userinfo.txt]]} {
    file delete -force $sHome
    file mkdir $sHome
    file copy /var/www/tmplate/.simile $sHome
}
set env(HOME) $sHome
catch {file delete [file join $sHome $shLib]}
catch {file delete [file join $sHome .simile Desktop1.smx]}
# puts $auto_path<br>
if {[catch {
    package require SimileAutoObj

    similescript::ModelWindow modelWin
    modelWin Open $mdl.sml
    modelWin BuildShareLib [file join $sHome $shLib]
# now export the svg not over the original model
    puts "svg to $mdl.svg"
    modelWin BuildSVGDiagram $mdl.svg

    # try returning the runParams if we have them...as json of course
    array set runParams {execTime 100.0 timeUnit unit displayInt 1 \
			     intMethod Euler phaseList 0.1 resetTo 0}
    # defaults
    set node [modelWin cget -modelNode]
    if {[info exists runState($node,runParams)] && \
	     [lindex $runState($node,runParams) 0] eq "execTime"} {
	array set runParams $runState($node,runParams) ;# overwrite
    }
    set rps \{
    foreach {role val} [array get runParams] {
	append rps \"$role\":\"$val\",
    }
    puts -nonewline [string replace $rps end end \}]
}]} {
    puts $errorInfo
}
#if {[catch exit lastGasp]} {
#    exec echo $lastGasp >> /tmp/error-output.txt
#    puts $lastGasp
#}
