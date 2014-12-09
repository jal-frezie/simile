# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Shapes3D20141208
itcl::class similescript::$newHelperClass {
    inherit Helper
    variable template {}

    proc Identify {} {
	return "3-D Shape Plotter"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	variable ::gen3d1::viewVector

	set pi 3.14
	set ::gen3d1::base 0
	::gen3d1::DefineGrid -40 40
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
	menu $winId.m -tearoff 0
	$winId.m add command -label "Sphere" -command "$this AddItem spheres"
	$winId.m add command -label "Line" -command "$this AddItem lines"
	pack [::ttk::menubutton $winId.mb -text "Select new item type" \
		  -menu $winId.m]
	message $winId.ms
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	} else {
	    set State {}
#	    $modelInst GrabClicks $this
	}
	update
	Display 0 0 0
    }

    public method AddItem {type} {
	pack forget $winId.mb
	array set all_templates \
	    {spheres {{type "Select new item type"} \
			  {component "X positions"} \
			  {component "Y positions"} \
			  {component "Z positions"} \
			  {component "size values"} \
			  {colour colour}} \
		 lines {{type "Select new item type"} \
			  {component "start X positions"} \
			  {component "start Y positions"} \
			  {component "start Z positions"} \
			  {component "end X positions"} \
			  {component "end Y positions"} \
			  {component "end Z positions"} \
			  {component "width values"} \
			  {colour colour}}}
	set template $all_templates($type)
	MakeSelection $type
    }

    public method MakeSelection {selected} {
	for {set i 0} {$i < [llength $template]} {incr i} {
	    if {[lsearch {type component colour} [lindex $template $i 0]]>-1} {
		lset template $i $selected
		break
	    }
	}
	incr i
	if {$i == [llength $template]} { ;# finished
	    lappend State $template
	    pack forget $winId.ms
	    pack $winId.mb
	} else {
	    switch [lindex $template $i 0] {
		component {
		    $winId.ms configure -text "Click on component with [lindex $template $i 1] of [lindex $template 0]"
		    pack $winId.ms
		    $modelInst GrabClicks $this
		} colour {
		    set msg "Choose [lindex $template $i 1] of [lindex $template 0]"
		    $winId.ms configure -text $msg
		    MakeSelection [tk_chooseColor -title $msg]
		}
	    }
	}
    }
    
    public method Click {path} {
	$modelInst ReleaseClicks
	MakeSelection $path
    }

    public method Flatten {pairs} {
	if {[llength $pairs]==1} {
	    return [list {} $pairs]
	} else {
	    foreach {i sub} $pairs {
		foreach {is v} [Flatten $sub] {
		    lappend result [linsert $is 0 $i] $v
		}
	    }
	    return $result
	}
    }

    public method Display {time dispInt step} {
	variable ::gen3d1::grid
	variable ::gen3d1::viewVector

# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	$winId.c delete -withtag graph
	::gen3d1::DrawShapes $winId $grid graph

	set stack {}
	foreach instruct $State {
	    switch [lindex $instruct 0] {
		spheres {
		    for {set i 1} {$i<5} {incr i} {
			array set [lindex {0 x y z r} $i] \
			    [Flatten [lindex [$modelInst GetValue \
						  [lindex $instruct $i]] 0]]
		    }
		    foreach iV [array names r] {
			if {[llength $iV]} {
			    set id "index: [join $iV ,]"
			} else {
			    set id [lindex $instruct 4]
			}
			lappend stack \
			    [list sphere $id [list $x($iV) $y($iV) $z($iV)] \
				 $r($iV) 1 [lindex $instruct 5] {}]
		    }
		    
		} lines {
		    for {set i 1} {$i<8} {incr i} {
			array set [lindex {0 sx sy sz fx fy fz w} $i] \
			    [Flatten [lindex [$modelInst GetValue \
						  [lindex $instruct $i]] 0]]
		    }
		    foreach iV [array names w] {
			if {[llength $iV]} {
			    set id "index: [join $iV ,]"
			} else {
			    set id [lindex $instruct 7]
			}
			lappend stack \
			    [list line $id [list $sx($iV) $sy($iV) $sz($iV)] \
				 [list $fx($iV) $fy($iV) $fz($iV)] $w($iV) \
				 [lindex $instruct 8]]
		    }
		}
	    }
	}
	::gen3d1::DrawShapes $winId $stack graph
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
