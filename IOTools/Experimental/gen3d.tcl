set keyValue gen3d

namespace eval ::$keyValue {
variable useNodes


proc identify {} {
	return "New lollipop diagram"
}

proc initialize {winId} {
    set ms [message $winId.intro -text "Click on the array value \
			representing the X coordinates of the treelike objects to be \
			displayed."]
	GrabClicks $winId
	pack $ms
	SetState $winId xcoord
}

proc Restore {winId} {
}

proc click {winId node caption} {
    variable useNodes
    set ms $winId.intro
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
	set state [GetState $winId]
	switch $state {
	    xcoord {
		$ms configure -text "Now click on the value representing the Y coordinates."
		set useNodes($winId,xcoord) $node
		SetState $winId ycoord
	    }
	    ycoord {
		$ms configure -text "Now select a value to display as the size of the objects."
		set useNodes($winId,ycoord) $node
		SetState $winId sizeval
	    }
	    sizeval {
		pack forget $ms
		ReleaseClicks $winId
		set useNodes($winId,size) $node
		set xnode $useNodes($winId,xcoord)
		set ynode $useNodes($winId,ycoord)
		catch {wm geometry $winId 650x500}
		InitializeForest $winId $xnode $ynode $node
		SetState $winId displaying
		SaveState $winId
	    }
	}
    } else {
	$ms configure -text \
	    "This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc SaveState {winId} {
}

proc InitializeForest {winId xs ys hs} {
    variable grid
    variable viewVector
    set pi 3.1416
    array set viewVector {angle -0.3 elevation 0.5}
    scale $winId.elv -orient v -from [expr $pi/2] -to [expr -$pi/2] \
	-resolution 0.01 \
	-command [namespace code "TweakScale $winId elevation"]
    $winId.elv set 0.5
   canvas $winId.c -width 1 -height 1 -bg white
   frame $winId.buttons -relief raised -bd 1
   button $winId.buttons.but_print -text "Print..." \
      -command "PrintNow $winId.c"
    pack [label $winId.buttons.anglab -text "View angle:"] -side left
    scale $winId.buttons.ang -orient h -from -$pi -to $pi \
	-resolution 0.01 \
	-command [namespace code "TweakScale $winId angle"]
    $winId.buttons.ang set -0.3
    pack $winId.buttons.ang -side left -fill x -expand true
    pack [label $winId.buttons.elvlab -text "View\nelev."] -side right
    pack $winId.buttons.but_print -side right
    pack $winId.buttons -side bottom -fill x
    pack $winId.elv -side right -fill y
    pack $winId.c -fill both -expand true
            
    bind $winId.c <Configure> \
                [namespace code " WindowSizeChanged $winId"]

#Grid is always displayed so only define it once
    set grid {}
    for {set x -50} {$x <= 50} {incr x 10} {
	lappend grid [list line "$x -50 0" "$x 50 0" 1 red]
    }
    for {set y -50} {$y <= 50} {incr y 10} {
	lappend grid [list line "-50 $y 0" "50 $y 0" 1 red]
    }
    LoadPosns $winId
}

proc TweakScale {winId which where} {
    variable viewVector
    set viewVector($which) $where
    WindowSizeChanged $winId
}

proc display {winId time step remainder} {
    variable trunks
    LoadPosns $winId
    $winId.c delete -withtag trunks
    DrawShapes $winId $trunks trunks
}

proc LoadPosns {winId} {
    variable useNodes
    variable trunks
    set quadlist {}
    polygon375::GetQuadList {} \
	[lindex [GetModelValue $useNodes($winId,xcoord)] 0] \
	[lindex [GetModelValue $useNodes($winId,ycoord)] 0] \
	[lindex [GetModelValue $useNodes($winId,size)] 0]
    set trunks {}
    foreach {id data} $quadlist {
	set x [expr [lindex $data 0]-50]
	set y [expr [lindex $data 1]-50]
	set z [lindex $data 2]
	lappend trunks [list line "$x $y 0" "$x $y $z" 4 brown]
	lappend trunks [list sphere "$x $y [expr 1.5*$z]" [expr $z/2] 1 green]
    }
}

proc DrawShapes {winId solids tag} {
    variable viewVector

    set insts {}
    foreach object3d $solids {
#ShowMessage debug info $object3d ok
	switch [lindex $object3d 0] {
	    line {
		set startMap [project [lindex $object3d 1]]
		set endMap [project [lindex $object3d 2]]
		set startx [lindex $startMap 0]
		set starty [lindex $startMap 1]
		set endx [lindex $endMap 0]
		set endy [lindex $endMap 1]
#ShowMessage debug info "$startMap $endMap" ok
		lappend insts [list [list \
		$winId.c create line $startx $starty $endx $endy -tag $tag \
		    -width [lindex $object3d 3] -fill [lindex $object3d 4]] \
			   [expr ([lindex $startMap 2]+[lindex $endMap 2])/2]]
	    } sphere {
		set middle [project [lindex $object3d 1]]
		set midx [lindex $middle 0]
		set midy [lindex $middle 1]
		set rad [expr $viewVector(winX)*[lindex $object3d 2]/150.0]
		lappend insts [list [list \
		$winId.c create oval [expr $midx-$rad] [expr $midy-$rad] \
		     [expr $midx+$rad] [expr $midy+$rad] -tag $tag \
		     -width [lindex $object3d 3] -fill [lindex $object3d 4]] \
				   [lindex $middle 2]]
			       
	    }
	}
    }
    set ordered [lsort -decreasing -real -index 1 $insts]
    foreach combo $ordered {
	eval [lindex $combo 0]
    }
}

proc project {pt3d} {
    variable viewVector
    set ptx [lindex $pt3d 0]
    set pty [lindex $pt3d 1]
    set ptz [lindex $pt3d 2]

    set multx [expr cos($viewVector(angle))]
    set multy [expr sin($viewVector(angle))]

    set rotx [expr $multx*$ptx - $multy*$pty]
    set roty [expr -$multx*$pty - $multy*$ptx]

    set multx [expr cos($viewVector(elevation))]
    set multy [expr sin($viewVector(elevation))]

    set scx [expr $viewVector(winX)*($rotx/150.0 + .5)]
    set scy [expr $viewVector(winY)*(($multx*$ptz - $multy*$roty)/-150.0 + .5)]
    set depth [expr -$multx*$roty - $multy*$ptz]

#ShowMessage debug info "pt3d $pt3d rots $rotx $roty cams $scx $scy $depth" ok
    return [list $scx $scy $depth]
}
    
proc WindowSizeChanged {winId} {
    variable grid
    variable viewVector
    variable trunks
    if {[winfo viewable $winId.c]} {
	$winId.c delete all
	set viewVector(winX) [winfo width $winId.c]
	set viewVector(winY) [winfo height $winId.c]
	if {$viewVector(elevation)>=0} {
	    DrawShapes $winId $grid grid
	}
	DrawShapes $winId $trunks trunks
	if {$viewVector(elevation)<0} {
	    DrawShapes $winId $grid grid
	}
    }
}
}