set keyValue gen3d1

namespace eval ::$keyValue {
    variable useNodes
    variable colours {\#00ff00 \#f1da7e \#36b694 \#ec9844 \#94a646 \#d9d095}
    variable base -25

proc identify {} {
	return "Lollipop diagram"
}

LoadIconImages Toolbar {new add}

proc initialize {winId} {
    variable useNodes
    variable trunks
    variable base
    namespace import -force ::maptools2::*
    set toolbarItems [list \
			  [list new "Clear" \
			       [namespace code "clear $winId"]] \
			  [list add "Add a variable" \
			       [namespace code "AddVariable $winId"]]]
    
    ::graphtools::MakeToolBar $winId $toolbarItems
    pack [message $winId.intro -aspect 800] -fill x
    variable grid
    variable viewVector
    set pi 3.14
    array set viewVector [list $winId,angle -0.3 $winId,elevation 0.5 \
			      $winId,cos_angle 1 $winId,cos_elevation 1 \
			      $winId,sin_angle -0.3 $winId,sin_elevation 0.5]
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
	lappend grid [list line {} "$x -50 $base" "$x 50 $base" 1 red]\
	    [list text "X posn" "$x -60 $base" [expr $x+50] red] \
	    [list text "X posn" "$x 60 $base" [expr $x+50] red]
    }
    for {set y -50} {$y <= 50} {incr y 10} {
	lappend grid [list line {} "-50 $y $base" "50 $y $base" 1 red]\
	    [list text "Y posn" "-60 $y $base" [expr $y+50] blue] \
	    [list text "Y posn" "60 $y $base" [expr $y+50] blue]
    }
    for {set z 10} {$z <= 50} {incr z 10} {
	set zposn [expr $base+2*$z]
	lappend grid [list text "Z posn" "-50 -50 $zposn" $z black] \
	    [list text "Z posn" "-50 50 $zposn" $z black] \
	    [list text "Z posn" "50 50 $zposn" $z black] \
	    [list text "Z posn" "50 -50 $zposn" $z black]
    }

    SetState $winId initial
    set useNodes($winId,selected) {}
    set useNodes($winId,captions) {}
    set trunks {}
    catch {wm geometry $winId 650x500}
    set viewVector($winId,X) [winfo width $winId.c]
    set viewVector($winId,Y) [winfo height $winId.c]
}

proc GetCanvas {winId} {
    return $winId.c
}

proc clear {winId} {
    variable useNodes
    set useNodes($winId,selected) {}
    set useNodes($winId,captions) {}
    display $winId 0 0 0
    ShowKey $winId
}

proc reset {winId} {
}

proc AddVariable {winId} {
    $winId.intro configure -text "Click on the array value representing the X coordinates of the treelike objects to be displayed."
    GrabClicks $winId
    SetState $winId xcoord
}

proc click {winId node caption} {
    variable useNodes
    set ms $winId.intro
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
	lappend useNodes($winId,selected) $node
	lappend useNodes($winId,captions) $caption
	set state [GetState $winId]
	switch $state {
	    xcoord {
		$ms configure -text "Now click on the value representing the Y coordinates."
		SetState $winId ycoord
	    }
	    ycoord {
		$ms configure -text "Now select a value to display as the size of the objects."
		SetState $winId sizeval
	    }
	    sizeval {
		ReleaseClicks $winId
		$ms configure -text {}
		SaveState $winId
		display $winId 0 0 0
		ShowKey $winId
	    }
	}
    } else {
	$ms configure -text \
	    "This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc SaveState {winId} {
    variable useNodes
    variable viewVector
    set state displaying
    lappend state $viewVector($winId,angle) $viewVector($winId,elevation)
    foreach node $useNodes($winId,selected) {
	lappend state [GetCaptionPathFromId $node]
    }
    SetState $winId $state
}

proc Restore {winId} {
    variable useNodes
    set state [GetState $winId]
    initialize $winId
    if {[string match displaying [lindex $state 0]]} {
	$winId.buttons.ang set [lindex $state 1]
	foreach node [lrange $state 3 end] {
	    lappend useNodes($winId,selected) [GetIdFromCaptionPath $node]
	    lappend useNodes($winId,captions) [lindex [split $node /] end]
	}
	LoadPosns $winId
	$winId.elv set [lindex $state 2]
    } else {
	GrabClicks $winId
    }
    SaveState $winId
}

proc TweakScale {winId which where} {
    variable viewVector
    set viewVector($winId,$which) $where
    SaveState $winId

    set viewVector($winId,cos_angle) [expr cos($viewVector($winId,angle))]
    set viewVector($winId,sin_angle) [expr sin($viewVector($winId,angle))]
    set viewVector($winId,cos_elevation) \
	[expr cos($viewVector($winId,elevation))]
    set viewVector($winId,sin_elevation) \
	[expr sin($viewVector($winId,elevation))]
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
    variable base
    set col 0
    set trunks {}
    foreach {px py h} $useNodes($winId,selected) {
	set quadlist {}
	GetQuadList {} [lindex [GetModelValue $px] 0] \
	    [lindex [GetModelValue $py] 0] \
	    [lindex [GetModelValue $h] 0]
#ShowMessage debug info "List is $quadlist" ok
	foreach {id data} $quadlist {
	    if {![string match nil [lindex $data 0]]} {
		set x [expr [lindex $data 0]-50]
		set y [expr [lindex $data 1]-50]
		set z [lindex $data 2]
		if {[llength $id]} {
		    set pop "index: $id"
		} else {
		    set pop {}
		}
		lappend trunks [list line $pop "$x $y $base" \
				    "$x $y [expr $base+$z]" 4 brown]
		lappend trunks [list sphere $pop "$x $y [expr $base+3*$z/2]" \
				    [expr $z/2] 1 [lindex $colours $col]]
	    }
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
		set startMap [project $winId [lindex $object3d 2]]
		set endMap [project $winId [lindex $object3d 3]]
		set startx [lindex $startMap 0]
		set starty [lindex $startMap 1]
		set endx [lindex $endMap 0]
		set endy [lindex $endMap 1]
#ShowMessage debug info "$startMap $endMap" ok
		lappend insts [list [list \
		$winId.c create line $startx $starty $endx $endy -tag $tag \
		    -width [lindex $object3d 4] -fill [lindex $object3d 5]] \
			   [expr ([lindex $startMap 2]+[lindex $endMap 2])/2] \
				   [lindex $object3d 1]]
	    } sphere {
		set middle [project $winId [lindex $object3d 2]]
		set midx [lindex $middle 0]
		set midy [lindex $middle 1]
		set rad [expr $viewVector($winId,Y)*[lindex $object3d 3]/150.0]
		lappend insts [list [list \
		$winId.c create oval [expr $midx-$rad] [expr $midy-$rad] \
		     [expr $midx+$rad] [expr $midy+$rad] -tag $tag \
		     -width [lindex $object3d 4] -fill [lindex $object3d 5]] \
				   [lindex $middle 2] \
				   [lindex $object3d 1]]
			       
	    } text {
		set middle [project $winId [lindex $object3d 2]]
		set midx [lindex $middle 0]
		set midy [lindex $middle 1]
		lappend insts [list [list \
		$winId.c create text $midx $midy -tag $tag \
		     -text [lindex $object3d 3] -fill [lindex $object3d 4]] \
				   [lindex $middle 2] \
				   [lindex $object3d 1]]
	    }
	}
    }
    set ordered [lsort -decreasing -real -index 1 $insts]
    foreach combo $ordered {
	set canvObj [eval [lindex $combo 0]]
	if {[llength [lindex $combo 2]]} {
	    CanvasBindPopup $winId.c $canvObj [lindex $combo 2]
	}
    }
}

proc project {winId pt3d} {
    variable viewVector
    set ptx [lindex $pt3d 0]
    set pty [lindex $pt3d 1]
    set ptz [lindex $pt3d 2]

    set multx $viewVector($winId,cos_angle)
    set multy $viewVector($winId,sin_angle)

    set rotx [expr $multx*$ptx - $multy*$pty]
    set roty [expr -$multx*$pty - $multy*$ptx]

    set multx $viewVector($winId,cos_elevation)
    set multy $viewVector($winId,sin_elevation)

    set scx [expr $viewVector($winId,X)*($rotx/150.0 + .5)]
    set scy [expr $viewVector($winId,Y)*(($multx*$ptz - $multy*$roty)/-150.0 + .5)]
    set depth [expr -$multx*$roty - $multy*$ptz]

#ShowMessage debug info "pt3d $pt3d rots $rotx $roty cams $scx $scy $depth" ok
    return [list $scx $scy $depth]
}

proc ShowKey {winId} {
    variable useNodes
    variable colours
    variable viewVector

    set col 0
    set atx 20
    set aty $viewVector($winId,Y)
    
    $winId.c delete -withtag key
    foreach {x y sz} $useNodes($winId,captions) {
	$winId.c create line $atx $aty $atx [expr $aty-16] -width 4 \
	    -fill brown -tag key
	$winId.c create oval [expr $atx-8] [expr $aty-32] [expr $atx+8] \
	    [expr $aty-16] -fill [lindex $colours $col] -tag key
	$winId.c create text [expr $atx+16] $aty -anchor sw -tag key \
	    -text "z: $sz\nx: $x\ny: $y"
	incr col
	incr atx 100
    }
}

proc WindowSizeChanged {winId} {
    variable grid
    variable viewVector
    variable trunks
    set viewVector($winId,X) [winfo width $winId.c]
    set viewVector($winId,Y) [winfo height $winId.c]
    if {[winfo viewable $winId.c]} {
	$winId.c delete all
	if {$viewVector($winId,elevation)>=0} {
	    DrawShapes $winId $grid grid
	}
	DrawShapes $winId $trunks trunks
	if {$viewVector($winId,elevation)<0} {
	    DrawShapes $winId $grid grid
	}
	ShowKey $winId
    }
}
}
