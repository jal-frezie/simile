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

    set fullFile [file join $workingDir $file]
    ::browser::status "Loading $fullFile"
    incr fileCount
    .splash.c coords 2 [list 2 148 [expr {5*$fileCount}] 168]
    update idletasks
    return [::browser::getURL $fullFile 3000]
    ::browser::status "Done"
}

set graph(font) [list helvetica 8]

# Put splash screen up
frame .splash
place .splash -x [expr {[winfo width .]/2}] \
    -y [expr {[winfo height .]/2}] -anchor c
pack [canvas .splash.c -width 400 -height 316 -bd 2] -padx 0 -pady 0
.splash.c create rect 2 148 398 168 -outline \#999999 -fill \#999999 ;# item 1
.splash.c create rect 2 148 2 168 -outline \#99cc99 -fill \#99cc99 ;# item 2
image create photo splash -data [ReadFile ../Images/splash.gif]
.splash.c create image 200 158 -image splash
.splash.c create text 245.0 50.0 -font $graph(font) -fill \#99cc99 -anchor w \
    -text "Simulistics Ltd. 2001-2006"
.splash.c create text 270.0 275.0 -font $graph(font) -fill \#660066 -text "Model Web Interface"
set regInfo "Web Users"
catch {append regInfo ", Everywhere"}
.splash.c create text 270.0 295.0 -font $graph(font) -fill \#660066 -text "Registered to $regInfo"
.splash.c raise 1
.splash.c raise 2
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
set ::RunEnv::helperData [ReadFile ../Examples/forestpp.shf]
::RunEnv::LoadViewFile $myNode helperData 4.9

