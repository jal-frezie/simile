# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Shapes3D20141208
itcl::class similescript::$newHelperClass {
    inherit Helper
    public variable inTitle tbc
    variable template {}

    proc Identify {} {
	return "3-D Shape Plotter"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	variable ::gen3d1::scaleVector
	variable ::gen3d1::viewVector

	if {[AmLayer]} {
	    set winId [winfo parent [lindex $winTitle 2]]
	    set viewVector($winId,X) 500
	    set viewVector($winId,Y) 500
	    foreach {x y} [lrange $winTitle 3 4] {}
	    array set scaleVector [list $winId,xoff [expr {250.0/$x}] \
				       $winId,xmag [expr {500.0/$x}] \
				       $winId,yoff [expr {-250.0/$y}] \
				       $winId,ymag [expr {500.0/$y}] \
				       $winId,zoff 0 $winId,zmag 150.0]
	    array set viewVector [list $winId,angle 0 $winId,elevation 1.57 \
				      $winId,cos_angle 1 $winId,cos_elevation 0 \
				      $winId,sin_angle 0 $winId,sin_elevation 1]
	} else {
	    canvas $winId.c -width 1 -height 1 -bg white
	    ::canvasnotes20070919::MakeCanvasAnnotatable $winId.c
	    array set scaleVector [list $winId,xoff 0 $winId,xmag 150.0 \
				       $winId,yoff 0 $winId,ymag 150.0 \
				       $winId,zoff 0 $winId,zmag 150.0]
	    ::gen3d1::DefineGrid $winId
	    array set viewVector [list $winId,angle -0.3 $winId,elevation 0.5 \
				      $winId,cos_angle 1 $winId,cos_elevation 1 \
				      $winId,sin_angle -0.3 $winId,sin_elevation 0.5]
	}
	set pi 3.14
#	scale $winId.elv -orient v -from [expr $pi/2] -to [expr -$pi/2] \
#	    -resolution 0.01 \
#	    -command "$this TweakScale elevation"
	#	$winId.elv set 0.5
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	} else {
	    set State {}
#	    $modelInst GrabClicks $this
	}
	if {[AmLayer]} {
	    if {![string length $state]} {
		AddItem [lindex $winTitle 1]
		tkwait window $winId.ms
	    }
	    array set titlePosns {spheres 4 lines 7 ellipses 4}
	    set inTitle [lindex $State  0 $titlePosns([lindex $State 0 0])]
	    Display 0 0 0
	    return
	}	
	frame $winId.buttons -relief raised -bd 1
	button $winId.buttons.but_print -text "Print..." \
	    -command "PrintNow $winId.c"
#	pack [label $winId.buttons.anglab -text "View angle:"] -side left
#	scale $winId.buttons.ang -orient h -from -$pi -to $pi \
#	    -resolution 0.01 \
#	    -command "$this TweakScale angle"
#	$winId.buttons.ang set -0.3
#	pack $winId.buttons.ang -side left -fill x -expand true
#	pack [label $winId.buttons.elvlab -text "View\nelev."] -side right
	pack $winId.buttons.but_print -side right
	pack $winId.buttons -side bottom -fill x
#	pack $winId.elv -side right -fill y
	pack $winId.c -fill both -expand true
	
#	set ::frameCount 10000
#	package require img::window

	bind $winId.c <Configure> "$this WindowSizeChanged"
# New Three.js-style drag controls
	bind $winId.c <Button-1> \
	    [list namespace eval ::gen3d1 "DropAnchor $winId l %x %y"]
	bind $winId.c <B1-Motion> \
	    [list namespace eval ::gen3d1 "Haul $winId l %x %y 1"]
	CrossPlatformBind $winId.c \
	    [list namespace eval ::gen3d1 "DropAnchor $winId r %x %y"] \
	    [list namespace eval ::gen3d1 "Haul $winId r %x %y 1"]
	BindMouseWheel $winId.c 0 \
	    [list namespace eval ::gen3d1 "Zoom $winId %D %x %y"]

	menu $winId.m -tearoff 0
	$winId.m add command -label "Sphere" -command "$this AddItem spheres"
	$winId.m add command -label "Line" -command "$this AddItem lines"
	$winId.m add command -label "Polygon" -command "$this AddItem polygons"
	$winId.m add command -label "Ellipse" -command "$this AddItem ellipses"
	$winId.m add command -label "Surface" -command "$this AddItem surface"
	# $winId.m add command -label "Old Ellipse" -command "$this AddItem oldellipses"
	pack [::ttk::menubutton $winId.buttons.mb -text "Select new item type" \
		  -menu $winId.m]
    }

    public method AddItem {type} {
	if {![AmLayer]} {
	    pack forget $winId.buttons.mb
	}
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
			  {colour colour}}
		 polygons {{type "Select new item type"} \
			  {component "X vertex position lists"} \
			  {component "Y vertex position lists"} \
			  {component "Z vertex position lists"} \
			  {colour outline} \
			  {colour fill}}
		 oldellipses {{type "Select new item type"} \
			  {component "centre X positions"} \
			  {component "centre Y positions"} \
			  {component "centre Z positions"} \
			  {component "tip X positions"} \
			  {component "tip Y positions"} \
			  {component "tip Z positions"} \
			  {component "side X positions"} \
			  {component "side Y positions"} \
			  {component "side Z positions"} \
			  {colour outline} \
			  {colour fill}}
		 ellipses {{type "Select new item type"} \
			  {component "centre X positions"} \
			  {component "centre Y positions"} \
			  {component "centre Z positions"} \
			  {component "Major radius"} \
			  {component "Eccentricity"} \
			  {component "X rotations"} \
			  {component "Y rotations"} \
			  {component "Z rotations"} \
			  {colour FRONT} \
			  {colour BACK}}
		 surface {{type "Select new item type"} \
			  {component "node X positions"} \
			  {component "node Y positions"} \
			  {component "node Z positions"} \
			  {colour outline} \
			  {colour fill}}}
	set template $all_templates($type)
	pack [message $winId.ms]
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
	    destroy $winId.ms
	    if {![AmLayer]} {
		pack $winId.buttons.mb
	    }
	} else {
	    set descrip [lindex $template $i 1]
	    switch [lindex $template $i 0] {
		component {
		    if {[AmLayer] && [lsearch {"Z positions" "start Z positions" "end Z positions" "Z vertex position lists" "centre Z positions" "X rotations" "Y rotations"} $descrip]>-1} {
			MakeSelection null
		    } else {
			$winId.ms configure -text "Click on component with $descrip of [lindex $template 0]"
			$modelInst GrabClicks $this
		    }
		} colour {
		    set msg "Choose $descrip of [lindex $template 0]"
		    $winId.ms configure -text $msg
		    MakeSelection [tk_chooseColor -title $msg]
		}
	    }
	}
    }
    
    public method GetCanvas {} {
        return $winId.c
    }

    public method Click {path} {
	$modelInst ReleaseClicks
	MakeSelection $path
    }

#    public method Flatten {pairs} {
#	if {[llength $pairs]==1} {
#	    return [list {} $pairs]
#	} else {
#	    set result {}
#	    foreach {i sub} $pairs {
#		foreach {is v} [Flatten $sub] {
#		    lappend result [linsert $is 0 $i] $v
#		}
#	    }
#	    return $result
#	}
#    }
#	    
    method PolyInsts {id vx vy vz tail} {
	if {[llength [lindex $vz 1]]==1} {
	    set op [list polygon $id]
	    set allz 0
	    foreach {idx nx} $vx {idy ny} $vy {idz nz} $vz {
		    lappend op [list $nx $ny $nz]
		    set allz [expr {$allz+$nz}]
		}
	    lappend op [lindex $tail 0] [lindex $tail 1]
	    return [list $op]
	} else {
	    set result {}
	    foreach {idx nx} $vx {idy ny} $vy {idz nz} $vz {
		eval lappend result [PolyInsts $id,$idz $nx $ny $nz $tail]
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
	set layerId [namespace tail [string range $this 0 end-7]].main
	$winId.c delete -withtag $layerId

	set lower {}
	set upper {}
	foreach instruct $State {
	    set rawList {}
	    switch [lindex $instruct 0] {
		spheres {
#		    foreach arr {x y z r} {
#			array unset $arr
#		    }
		    foreach arr [lrange $instruct 1 4] {
#			array set [lindex {0 x y z r} $i] \
#			    [Flatten [lindex [$modelInst GetValue \
#						  [lindex $instruct $i]] 0]]
			if {$arr eq "null"} {
			    lappend rawList 0
			} else {
			    lappend rawList [$modelInst GetValue $arr -all 1]
			}
		    }
		    set quadlist {}
		    eval [list ::maptools2::GetQuadList {}] $rawList
#		    foreach iV [array names r] {}
		    foreach {iV data} $quadlist {
			if {[llength $iV]} {
			    set id "index: [join $iV ,]"
			} else {
			    set id [lindex $instruct 4]
			}
			foreach {x y z r} $data {}
			set op [list sphere $id [list $x $y $z] \
				 $r 1 [lindex $instruct 5] gray25]
			if {$z < 0} {
			    lappend lower $op
			} else {
			    lappend upper $op
			}
		    }
		} lines {
#		    foreach arr {sx sy sz fx fy fz w} {
#			array unset $arr
#		    }
		    foreach arr [lrange $instruct 1 7] {
			if {$arr eq "null"} {
			    lappend rawList 0
			} else {
			    lappend rawList [$modelInst GetValue $arr -all 1]
			}
		    }
		    set quadlist {}
		    eval [list ::maptools2::GetQuadList {}] $rawList
		    foreach {iV data} $quadlist {
			if {[llength $iV]} {
			    set id "index: [join $iV ,]"
			} else {
			    set id [lindex $instruct 7]
			}
			foreach {x1 y1 z1 x2 y2 z2 w} $data {}
			set op [list line $id [list $x1 $y1 $z1] \
				 [list $x2 $y2 $z2] $w [lindex $instruct 8]]
			if {$z1+$z2 < 0} {
			    lappend lower $op
			} else {
			    lappend upper $op
			}
		    }
		} polygons {
		    foreach arr {vx vy vz} {
			array unset $arr
		    }
		    for {set i 1} {$i<4} {incr i} {
			set [lindex {0 vx vy vz} $i] \
			    [$modelInst GetValue [lindex $instruct $i] -all 1]
		    }
		    eval lappend upper [PolyInsts p $vx $vy $vz \
						  [lrange $instruct 4 5]]
		} oldellipses {
		    foreach arr {cx cy cz tx ty tz sx sy sz} {
			array unset $arr
		    }
		    for {set i 1} {$i<10} {incr i} {
			array set [lindex {0 cx cy cz tx ty tz sx sy sz} $i] \
			    [Flatten [$modelInst GetValue [lindex $instruct $i] -all 1]]
		    }
		    foreach iV [array names cz] {
			if {[llength $iV]} {
			    set id "index: [join $iV ,]"
			} else {
			    set id [lindex $instruct 3]
			}
			set op [list ellipse $id \
				    [list $cx($iV) $cy($iV) $cz($iV)] \
				    [list $tx($iV) $ty($iV) $tz($iV)] \
				    [list $sx($iV) $sy($iV) $sz($iV)] 1 \
				    [lindex $instruct 10] [lindex $instruct 11]]
			if {$cz($iV) < 0} {
			    lappend lower $op
			} else {
			    lappend upper $op
			}
		    }
		} ellipses {
		    foreach arr [lrange $instruct 1 8] {
			if {$arr eq "null"} {
			    lappend rawList 0
			} else {
			    lappend rawList [$modelInst GetValue $arr -all 1]
			}
		    }
		    set quadlist {}
		    eval [list ::maptools2::GetQuadList {}] $rawList
		    foreach {iV data} $quadlist {
			if {[llength $iV]} {
			    set id "index: [join $iV ,]"
			} else {
			    set id [lindex $instruct 4]
			}
			foreach {cx cy cz mr ec rx ry rz} $data {}
			set tx [expr {$cx + cos($ry)*cos($rz)*$mr}]
			set ty [expr {$cy + cos($ry)*sin($rz)*$mr}]
			set tz [expr {$cz + sin($ry)*$mr}]
			set mx [expr {$cx + (sin($rx)*sin($ry)*cos($rz) - cos($rx)*sin($rz))*$mr/$ec}]
			set my [expr {$cy + (cos($rx)*cos($rz) + sin($rx)*sin($ry)*sin($rz))*$mr/$ec}]
			set mz [expr {$cz + sin($rx)*cos($ry)*$mr/$ec}]	
			# hmm perhaps we would be better off altering the camera angle
			set op [list ellipse $id \
				    [list $cx $cy $cz] \
				    [list $tx $ty $tz] \
				    [list $mx $my $mz] 1 \
				    [lindex $instruct 9] [lindex $instruct 10]]
			if {$cz < 0} {
			    lappend lower $op
			} else {
			    lappend upper $op
			}
		    }
		} surface {
		    foreach {var posn} {x 1 y 2 z 3} {
			set $var [$modelInst GetValue [lindex $instruct $posn] \
				      -all 1]
		    }
		    set bx [lindex $x 1]
		    set by [lindex $y 1]
		    set bz [lindex $z 1]
		    for {set u 3} {$u < [llength $z]} {incr u 2} {
			set fx [lindex $x $u]
			set fy [lindex $y $u]
			set fz [lindex $z $u]
			for {set v 3} {$v < [llength $fz]} {incr v 2} {
			    set op [list polygon [expr $u/2],[expr $v/2] \
					[list [lindex $bx $v-2] [lindex $by $v-2] [lindex $bz $v-2]] \
					[list [lindex $bx $v] [lindex $by $v] [lindex $bz $v]] \
					[list [lindex $fx $v] [lindex $fy $v] [lindex $fz $v]] \
					[list [lindex $fx $v-2] [lindex $fy $v-2] [lindex $fz $v-2]] \
					[lindex $instruct 4] [lindex $instruct 5]]
                            lappend upper $op
			}
			set bx $fx
			set by $fy
			set bz $fz
		    }
		}
	    }
	}
	if {$viewVector($winId,sin_elevation) <= 0} {
	    set spare $upper
	    set upper $lower
	    set lower $spare
	}
	::gen3d1::DrawShapes $winId $lower $layerId
	$winId.c raise graticule
	::gen3d1::DrawShapes $winId $upper $layerId
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
	$winId.c delete -withtag graticule
	::gen3d1::DrawGrid $winId graticule
	Display 0 0 0
    }    
    public method WindowSizeChanged {} {
	variable ::gen3d1::viewVector

	set viewVector($winId,X) [winfo width $winId.c]
	set viewVector($winId,Y) [winfo height $winId.c]
	$winId.c delete -withtag graticule
	::gen3d1::DrawGrid $winId graticule
	Display 0 0 0
    }

    public method AmLayer {} {
	return [string match *_3dinst $this]
    }
}
