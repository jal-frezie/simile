set keyValue gen3d

namespace eval ::$keyValue {
    variable useNodes
    variable colours {\#00ff00 \#f1da7e \#36b694 \#ec9844 \#94a646 \#d9d095}


proc identify {} {
	return "New lollipop diagram"
}

proc initialize {winId} {
    variable useNodes
    variable trunks
    set toolbarItems [list \
			  [list new.gif "Clear" \
			       [namespace code "clear $winId"]] \
			  [list add.gif "Add a variable" \
			       [namespace code "AddVariable $winId"]]]
    
    ::graphtools::MakeToolBar $winId $toolbarItems
    pack [message $winId.intro]
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
	lappend grid [list line "$x -50 0" "$x 50 0" 1 red] \
	    [list text "$x -60 0" [expr $x+50] red] \
	    [list text "$x 60 0" [expr $x+50] red]
    }
    for {set y -50} {$y <= 50} {incr y 10} {
	lappend grid [list line "-50 $y 0" "50 $y 0" 1 red] \
	    [list text "-60 $y 0" [expr $y+50] blue] \
	    [list text "60 $y 0" [expr $y+50] blue]
    }
    SetState $winId initial
    set useNodes($winId,selected) {}
    set trunks {}
    catch {wm geometry $winId 650x500}
}

proc clear {winId} {
    variable useNodes
    set useNodes($winId,selected) {}
    display $winId 0 0 0
}

proc AddVariable {winId} {
    $winId.intro configure -text "Click on the array value representing the X coordinates of the treelike objects to be displayed."
    GrabClicks $winId
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
		lappend useNodes($winId,selected) $node
		SetState $winId ycoord
	    }
	    ycoord {
		$ms configure -text "Now select a value to display as the size of the objects."
		lappend useNodes($winId,selected) $node
		SetState $winId sizeval
	    }
	    sizeval {
		$ms configure -text {}
		lappend useNodes($winId,selected) $node
		SetState $winId displaying
		SaveState $winId
		display $winId 0 0 0
	    }
	}
    } else {
	$ms configure -text \
	    "This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc SaveState {winId} {
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
    variable colours
    set col 0
    set trunks {}
    foreach {px py h} $useNodes($winId,selected) {
	set quadlist {}
	polygon375::GetQuadList {} [lindex [GetModelValue $px] 0] \
	    [lindex [GetModelValue $py] 0] [lindex [GetModelValue $h] 0]
	foreach {id data} $quadlist {
	    set x [expr [lindex $data 0]-50]
	    set y [expr [lindex $data 1]-50]
	    set z [lindex $data 2]
	    lappend trunks [list line "$x $y 0" "$x $y $z" 4 brown]
	    lappend trunks [list sphere "$x $y [expr 1.5*$z]" [expr $z/2] \
				1 [lindex $colours $col]]
	}
	incr col
	if {$col==6} {set col 0}
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
			       
	    } text {
		set middle [project [lindex $object3d 1]]
		set midx [lindex $middle 0]
		set midy [lindex $middle 1]
		lappend insts [list [list \
		$winId.c create text $midx $midy -tag $tag \
		     -text [lindex $object3d 2] -fill [lindex $object3d 3]] \
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
