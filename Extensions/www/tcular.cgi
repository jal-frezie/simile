#!/usr/bin/tclsh8.6

encoding system utf-8
foreach local {sPath sHome mdl} val $argv {
    set $local $val
}
puts "Here [pwd] args $argv<br>"
exec echo {} > /tmp/error-output.txt
lappend auto_path [file join $sPath System lib] /usr/share/tcl9.0 /usr/lib64/tcl9.0
if {![file exists [file join $sHome .simile userinfo.txt]]} {
    file delete -force $sHome
    file mkdir $sHome
    file copy /var/www/tmplate/.simile $sHome
    exec touch $sHome/userinfo.txt ;# make sure its newer than Simile install
}
set env(HOME) $sHome
catch {file delete $mdl.so}
catch {file delete [file join $sHome .simile Desktop1.smx]}
# puts $auto_path<br>
if {[catch {
    package require SimileAutoObj

    similescript::ModelWindow create modelWin
    modelWin open $mdl.sml
    file delete {*}[glob -nocomplain [file join $mimedir *.so]]
    # do not run bundled sharelib, obvs
    modelWin buildShareLib $mdl.so ;# was [file join $sHome $shLib]
# now export the svg not over the original model
    puts "svg to $mdl.svg"
    modelWin buildSVGDiagram $mdl.svg
    foreach bundled {.spf .shf} {
	set dest $mdl$bundled
	set src [file join $mimedir model$bundled]
	puts "$src $dest [file exists $src] && ![file exists $dest]"
	if {[file exists $src] && ![file exists $dest]} {
	    file copy $src $dest
	}
    }

    # try returning the runParams if we have them...as json of course
    array set runParams {execTime 100.0 timeUnit unit displayInt 1 errLimit 0 \
			     intMethod Euler phaseList 0.1 resetTo 0}
    # defaults
    set node [modelWin getNode]
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
