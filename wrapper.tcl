policy home
set workingDir /

proc fileSeek {fore aft} {
    if {[string equal relative [file pathtype $aft]]} {
        foreach bit [file split $aft] {
            switch -exact $bit {
                .. {
                    set fore [file dirname $fore]
                    if {[string equal . $fore]} {
                        set fore {}
                    }
                } . {
                } default {
                    set fore [file join $fore $bit]
                }
            }
        }
        return $fore
    } else {
        return $aft
    }
}

proc cd {newDir} {
    global workingDir
    set workingDir [fileSeek $workingDir $newDir]
}

proc pwd {} {
    global workingDir
    return $workingDir
}

proc checkLikelihood {name} {
    set levels [file split $name]
    if {[string equal tclIndex [lindex $levels end]] || \
            [string equal Run [lindex $levels 0]] && \
            [string equal pkgIndex.tcl [lindex $levels end]]} {
        error "Unlikely filename $name"
    }
}

proc myURL {url} {
    if {[catch {::browser::getURL [MessURL $url] 10000} loss]} {
        error "Experienced $loss getting $url"
    } else {
        return $loss
    }
}

proc ReadFile {file} {
    global workingDir fileCount
    set fullFile [string range [fileSeek $workingDir $file] 1 end]
    checkLikelihood $fullFile
    ::browser::status "Loading $fullFile"
    incr fileCount
    .splash.c coords 1 [list 2 59 [expr {int(3*$fileCount)}] 79]
#    .splash.c itemconfig 4 -text $fileCount
    raise .splash
    update idletasks
    return [myURL $fullFile]
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
#            eval {place forget $win} $args
        } overrideredirect|transient|deiconify {
            raise $win
        } geometry {
# Once I have ascertained this will work, put something here to position it
        } default {
            return [eval {oldWm $act $win} $args]
        }
    }
}

proc TidyURL {name} {
    while {[set special [string first % $name]]!=-1} {
        set end [expr {$special+2}]
        if {[scan [string range $name $special $end] "%%%x" num]>0} {
            set name [string replace $name $special $end [format %c $num]]
        } else {
            error $name
        }
    }
    return $name
}
                     
proc MessURL {name} {
    while {[set spec [string first { } $name]]!=-1} {
        if {[scan [string range $name $spec $spec] "%c" num]>0} {
            set name [string replace $name $spec $spec [format %%%x $num]]
        } else {
            error $name
        }
    }
    return $name
}
                     
rename glob oldGlob

proc glob {args} {
    global fileCount

    set tpt [lindex $args end]
    set dir [string range [pwd] 1 end]
    set pat $tpt
    
    if {[string equal Run $dir]} {
        error "unexpectedly globbed $args"
    }

    ::browser::status "Listing $dir"
    incr fileCount
    .splash.c coords 1 [list 2 59 [expr {int(3*$fileCount)}] 79]
#    .splash.c itemconfig 4 -text $fileCount
    raise .splash
    update idletasks
    set rawData [myURL $dir/?]
    ::browser::status "Done"

    set results {}
    set file 0
    while {[set file [string first "<a href=\"" $rawData $file]]>-1} {
        set refStart [expr $file+9]
        set file [string first "\">" $rawData $refStart]
        set refEnd [expr $file-1]
        set file [expr [string first "</a>" $rawData $file]+4]
        set ref [string range $rawData $refStart $refEnd]
        if {[string first ? $ref] && [string match $pat $ref] && \
                [string match relative [file pathtype $ref]]} {
            lappend results [TidyURL $ref]
        }
    }
    return $results
}

set fileCount 0
set env(HOME) {}
set tcl_platform(os) plugin

set graph(font) [list helvetica 8]

# Put splash screen up
toplevel .splash
pack [canvas .splash.c -width 400 -height 316 -bd 2] -padx 0 -pady 0
.splash.c create rect 2 59 2 79 -outline \#99cc99 -fill \#99cc99 ;# item 1
image create photo splash -data [ReadFile Images/splash.gif]
.splash.c create image 200 158 -image splash
.splash.c create text 245.0 50.0 -font $graph(font) -fill \#99cc99 -anchor w \
    -text "Simulistics Ltd. 2001-2006"
.splash.c create text 270.0 275.0 -font $graph(font) -fill \#660066 -text "Model Web Interface"
set regInfo "Web Users"
catch {append regInfo ", Everywhere"}
.splash.c create text 270.0 295.0 -font $graph(font) -fill \#660066 -text "Registered to $regInfo"
.splash.c raise 1
rename source oldsource

cd /System/lib
foreach libDir [glob */] {
    lappend auto_path [file join /System lib $libDir]
}
cd /Run

proc source {file} {
    uplevel 1 [ReadFile $file]
#    if {[catch {uplevel 1 $code} oops]} {
#        error "$oops sourcing file $file"
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

source mymenu.tcl
proc menu {args} {
    eval mymenu $args
}

source exec_only.tcl

destroy .splash
