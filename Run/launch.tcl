set invoc [info script]

if {[string first / $invoc]==-1} { ;# it's a command
    set invoc [exec which $invoc]
}

if {![catch {file link $invoc} tgt]} { ;# it's a link
    if {[file pathtype $tgt] eq "relative"} {
        set invoc [file normalize [file join [file dirname $invoc] $tgt]]
    } else {
      	set invoc $tgt
    }
} else {
    set invoc [file normalize $invoc] ;# must be abs in case try changes dir
}

source [file join [file dirname [file dirname [file dirname $invoc]]] \
		  Run simile.tcl]
