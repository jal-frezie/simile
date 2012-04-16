# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Discs3D20120313
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "3-D Ellipse Plotter"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	variable ::gen3d1::viewVector
	set pi 3.14
	array set viewVector [list $winId,angle -0.3 $winId,elevation 0.5 \
				  $winId,cos_angle 1 $winId,cos_elevation 1 \
				  $winId,sin_angle -0.3 $winId,sin_elevation 0.5]
	scale $winId.elv -orient v -from [expr $pi/2] -to [expr -$pi/2] \
	    -resolution 0.01 \
	    -command "$this TweakScale elevation"
	$winId.elv set 0.5
	canvas $winId.c -width 1 -height 1 -bg white
	frame $winId.buttons -relief raised -bd 1
	button $winId.buttons.but_print -text "Print..." \
	    -command "PrintNow $winId.c"
	pack [label $winId.buttons.anglab -text "View angle:"] -side left
	scale $winId.buttons.ang -orient h -from -$pi -to $pi \
	    -resolution 0.01 \
	    -command "$this TweakScale angle"
	$winId.buttons.ang set -0.3
	pack $winId.buttons.ang -side left -fill x -expand true
	pack [label $winId.buttons.elvlab -text "View\nelev."] -side right
	pack $winId.buttons.but_print -side right
	pack $winId.buttons -side bottom -fill x
	pack $winId.elv -side right -fill y
	pack $winId.c -fill both -expand true
	
#	set ::frameCount 10000
#	package require img::window

	bind $winId.c <Configure> "$this WindowSizeChanged"
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    update
	    Display 0 0 0
	} else {
	    # new instance so request data from model
	    set State {}
	    pack [message $winId.message \
		      -text "Click on model component for shafts"]
	    $modelInst GrabClicks $this
	}
    }

    public method Click {path} {
	if {[llength $State]} {
	    lappend State $path [$modelInst GetMinValue $path] \
		[$modelInst GetMaxValue $path]
	    destroy $winId.message
	    $modelInst ReleaseClicks
	    Display 0 0 0
	} else {
	    set State [list $path [$modelInst GetMinValue $path] \
			   [$modelInst GetMaxValue $path]]
	    $winId.message configure -text \
		"Now click on model component for discs"
	}
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	if {[llength $State]<6} return
	$winId.c delete -withtag graph
	set allvals [lindex [$modelInst GetValue [lindex $State 0]] 0]	
	foreach {foo bar} $allvals {
	    lappend bars [list line "index: $foo" \
			      "[lindex $bar 1] [lindex $bar 3] [lindex $bar 5]" \
			      "[lindex $bar 7] [lindex $bar 9] [lindex $bar 11]" \
			      4 green4]
	}
	if {[info exists bars]} {
	    ::gen3d1::DrawShapes $winId $bars graph
	}
	set allvals [lindex [$modelInst GetValue [lindex $State 3]] 0]	
	foreach {foo bar} $allvals {
	    lappend bars [list ellipse "index: $foo" \
			      "[lindex $bar 1] [lindex $bar 3] [lindex $bar 5]" \
			      "[lindex $bar 7] [lindex $bar 9] [lindex $bar 11]" \
			      "[lindex $bar 13] [lindex $bar 15] [lindex $bar 17]" \
			  1 black green]
	}
	if {[info exists bars]} {
	    ::gen3d1::DrawShapes $winId $bars graph
	}
#	update
#	set img [image create photo -format window -data $winId]
#	set hi8dump [file join $::simtmpdir temp_out[incr ::frameCount].bmp]
#	$img write $hi8dump -format bmp
    }

    public method TweakScale {which where} {
	variable ::gen3d1::viewVector

	set viewVector($winId,$which) $where
       	set viewVector($winId,cos_angle) [expr cos($viewVector($winId,angle))]
	set viewVector($winId,sin_angle) [expr sin($viewVector($winId,angle))]
	set viewVector($winId,cos_elevation) \
	    [expr cos($viewVector($winId,elevation))]
	set viewVector($winId,sin_elevation) \
	    [expr sin($viewVector($winId,elevation))]
	Display 0 0 0
    }    
    public method WindowSizeChanged {} {
	variable ::gen3d1::viewVector

	set viewVector($winId,X) [winfo width $winId.c]
	set viewVector($winId,Y) [winfo height $winId.c]
	Display 0 0 0
    }
}