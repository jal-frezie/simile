policy home
set workingDir Run
set env(HOME) {}
set tcl_platform(os) plugin
set auto_path [list ../System/lib/bwidget1.7 ../System/lib/calendar]

proc pwd {} {
    global workingDir
    return $workingDir
}

proc ReadFile {file} {
    global workingDir

    set fullFile [file join $workingDir $file]
    ::browser::status "Loading $fullFile"
    return [::browser::getURL $fullFile 3000]
    ::browser::status "Done"
}

rename source oldsource

proc source {file} {
    uplevel 1 [ReadFile $file]
#    if {[catch {uplevel 1 $code} oops]} {
#	error "$oops sourcing file $file"
#    }
}

rename option oldoption

proc option {args} {
    if {[string equal read [lindex $args 0]]} {
	# get it from the server and execute it
    } else {
	uplevel 1 oldoption $args
    }
}

proc cd {newDir} {
    global workingDir
    set workingDir [file join $workingDir $newDir]
}

source exec_only.tcl
