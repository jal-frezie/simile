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

proc makeProgress {} {
    global fileCount

    if {[winfo exists .splash.c]} {
	incr fileCount
	.splash.c coords 1 [list 2 59 [expr {int(2.5*$fileCount)}] 79]
	#    .splash.c itemconfig 4 -text $fileCount
	.splash.c raise 1
	raise .splash
	update idletasks
    }
}

proc ReadFile {file} {
    global workingDir
    set fullFile [string range [fileSeek $workingDir $file] 1 end]
    checkLikelihood $fullFile
    ::browser::status "Loading $fullFile"
    makeProgress
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
    set tpt [lindex $args end]
    set dir [string range [pwd] 1 end]
    set pat $tpt
    
    if {[string equal Run $dir]} {
        error "unexpectedly globbed $args"
    }

    ::browser::status "Listing $dir"
    makeProgress
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

rename source oldsource

cd /System/lib
foreach libDir [glob */] {
    lappend auto_path [file join /System lib $libDir]
}
cd /

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

source Run/mymenu.tcl
proc menu {args} {
    eval mymenu $args
}

# non-tclet should use c stub, but license is tricky
proc random01 {} {
    return [expr rand()]
}

proc graph_table {action indx args} {
    global graph_lists

    switch $action {
	21 {
	    return $graph_lists($indx)
	} 22 {
	    set graph_lists($indx) $args
	} 23 {
	    set xval [lindex $args 0]
	    for {set i 0} {$i<8} {incr i} {
		set gpt [lindex $graph_lists($indx) $i]
		set [lindex {xlow xhigh xspan ylow yhigh yspan range xsize} $i] $gpt
	    }
	    set spaces [expr {$xsize-1}]
	# Interval is distance from left of graph in point units
	    set interval [expr {$spaces*($xval-$xlow)/($xhigh-$xlow)}]
	    switch -regexp $range {
		0|4|5 { ;# truncate to fit on graph
		    set interval [expr {$interval<0?0:($interval>$spaces?$spaces:$interval)}]
		} 2|6 { ;# wrap around graph range */
		    set interval [expr {$spaces*($interval/$spaces - floor($interval/$spaces))}]
		    #case 1: extrapolate end sections of graph
		}
	    }
#	/* right = use_graph_pointer->points;
#	interval++;
#
#	for (length=spaces;length;length--) {
#		left = right;
#		right++;
#		if (--interval <= 1) break;
#	}
#	*/
	    if {$range > 3} {
		set lower [max 0 [min $spaces [expr {round($interval)}]]]
		set intersection [lindex $graph_lists($indx) [expr {8+$lower}]]
	    } else {
		set lower [max 0 [min [expr {$spaces-1}] [expr {int($interval)}]]]
		set interval [expr {$interval-$lower}]
		set left [lindex $graph_lists($indx) [expr {8+$lower}]]
		set right [lindex $graph_lists($indx) [expr {9+$lower}]]
		set intersection [expr {$interval*$right+(1-$interval)*$left}]
	    }
	    return [expr {$ylow + ($yhigh - $ylow)*$intersection/$yspan}]
	} default {
	    error "No action $action for graph $indx withdata $args"
	}
    }
}

source Run/simile.tcl
