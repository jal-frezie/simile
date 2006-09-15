policy home
set workingDir Run
set fileCount 0
set env(HOME) {}
set tcl_platform(os) plugin
set auto_path [list ../System/lib/bwidget1.7 ../System/lib/calendar]

proc pwd {} {
    global workingDir
    return $workingDir
}

proc menu {args} {}

proc ReadFile {file} {
    global workingDir fileCount
    if {[string equal tclIndex [file tail $file]]} {error}
    set fullFile [file join $workingDir $file]
    ::browser::status "Loading $fullFile"
    incr fileCount
    .splash.c coords 1 [list 2 59 [expr {int(4*$fileCount)}] 79]
#    .splash.c itemconfig 4 -text $fileCount
    raise .splash
    update idletasks
    return [::browser::getURL $fullFile 10000]
    ::browser::status "Done"
}

proc toplevel {win args} {
    eval {frame $win} $args
    place $win -x [expr {[winfo width .]/2}] \
	-y [expr {[winfo height .]/2}] -anchor c
}

proc grab {args} {
}

rename wm oldWm

proc wm {act win args} {
    switch -regexp -- $act {
	withdraw {
#	    eval {place forget $win} $args
	} overrideredirect|transient|deiconify {
	    raise $win
	} geometry {
# Once I have ascertained this will work, put something here to position it
	} default {
	    return [eval {oldWm $act $win} $args]
	}
    }
}

rename glob oldGlob

proc glob {args} {
    set tpt [lindex $args end]
    set dir [file join [pwd] [file dirname $tpt]]
    set pat [file tail $tpt]
    
    ::browser::status "Listing $dir"
    set rawData [::browser::getURL $dir 10000]
    ::browser::status "Done"

    set results {}
    set file 0
    while {[set file [string first "<a href=\"" $rawData $file]]>-1} {
	set refStart [expr $file+10]
	set file [string first "\">" $rawData $refStart]
	set refEnd [expr $file-1]
	set file [expr [string first "</a>" $rawData $file]+4]
	set ref [string range $rawData $refStart $refEnd]
	if {[string match $pat $ref]} {
	    lappend results $ref
	}
    }
    return $results
}

set graph(font) [list helvetica 8]

# Put splash screen up
toplevel .splash
pack [canvas .splash.c -width 400 -height 316 -bd 2] -padx 0 -pady 0
.splash.c create rect 2 59 2 79 -outline \#99cc99 -fill \#99cc99 ;# item 1
image create photo splash -data [ReadFile ../Images/splash.gif]
.splash.c create image 200 158 -image splash
.splash.c create text 245.0 50.0 -font $graph(font) -fill \#99cc99 -anchor w \
    -text "Simulistics Ltd. 2001-2006"
.splash.c create text 270.0 275.0 -font $graph(font) -fill \#660066 -text "Model Web Interface"
set regInfo "Web Users"
catch {append regInfo ", Everywhere"}
.splash.c create text 270.0 295.0 -font $graph(font) -fill \#660066 -text "Registered to $regInfo"
.splash.c raise 1
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

source mymenu.tcl
source exec_only.tcl

destroy .splash
