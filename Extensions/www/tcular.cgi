#!/usr/bin/tclsh
foreach local {sPath sHome mdl shLib} val $argv {
    set $local $val
}
puts "Here [pwd] args $argv<br>"
catch {
    puts [exec cat /tmp/error-output.txt]
    file delete /tmp/error-output.txt
}
lappend auto_path [file join $sPath System lib]
if {![file exists [file join $sHome .simile userinfo.txt]]} {
    file mkdir $sHome
    file copy /var/www/tmplate/.simile $sHome
}
set env(HOME) $sHome
catch {file delete [file join $sHome $shLib]}
catch {file delete [file join $sHome .simile Desktop1.smx]}
puts $auto_path<br>
if {[catch {
    package require SimileAutoObj

    similescript::ModelWindow modelWin
    modelWin Open $mdl
    modelWin BuildShareLib [file join $sHome $shLib]
# now export the svg over the original model
    puts "svg to $mdl.svg"
    modelWin BuildSVGDiagram $mdl.svg
}]} {
    puts $errorInfo
    exit
}
