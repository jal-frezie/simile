set keyValue xyz_plotter_00

namespace eval ::$keyValue {
    variable useNodes
    variable colours {green orange blue brown purple red}
    variable base -25

proc identify {} {
	return "3-D Plotter"
}

proc initialize {winId} {
    variable useNodes
    variable trunks
    variable base
    namespace import -force ::maptools2::*
    namespace import -force ::threedtools::*
    set toolbarItems [list \
			  [list new.gif "Clear" \
			       [namespace code "clear $winId"]] \
			  [list add.gif "Add a variable" \
			       [namespace code "AddVariable $winId"]]]
    
    ::graphtools::MakeToolBar $winId $toolbarItems
    pack [message $winId.intro -aspect 800] -fill x
    variable grid
    variable viewVector
    set pi 3.14
    array set viewVector [list $winId,angle -0.3 $winId,elevation 0.5]
    scale $winId.elv -orient v -from [expr -$pi/2] -to [expr $pi/2] \
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

proc AddVariable {winId} {
    $winId.intro configure -text "Click on the array value representing the X components of the values to be displayed."
    $winId.bbframe.buttonBox itemconfigure 1 -state disabled
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
		$ms configure -text "Now click on the value representing the Y components."
		SetState $winId ycoord
	    }
	    ycoord {
		$ms configure -text "Now click on the value representing the Z components."
		SetState $winId sizeval
	    }
	    sizeval {
		ReleaseClicks $winId
		$ms configure -text {}
		SaveState $winId
		$winId.bbframe.buttonBox itemconfigure 1 -state normal
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

    SetBaseVectors $winId $viewVector($winId,angle) \
	$viewVector($winId,elevation)
    MoveDisplay $winId
}

proc display {winId time step remainder} {
    variable trunks
    set newTrunks [LoadPosns $winId]
    if {$time==0} {
	set trunks {}
	set newTrunks {}
	$winId.c delete -withtag trunks
    }
    DrawShapes $winId $newTrunks trunks
    set trunks [concat $trunks $newTrunks]
}

proc LoadPosns {winId} {
    variable useNodes
    variable colours
    variable base
    set col 0
    set trunks {}
    foreach {px py h} $useNodes($winId,selected) {
	set quadlist {}
	GetQuadList {} [lindex [GetModelValue $px] 0] \
	    [lindex [GetModelValue $py] 0] [lindex [GetModelValue $h] 0]
#ShowMessage debug info "List is $quadlist" ok

	set oldQuadName useNodes($winId,oldQuadList,$px,$py,$h)
	if {[info exists $oldQuadName]} {
	    array set quadArray [set $oldQuadName]
	    foreach {id data} $quadlist {
		if {[info exists quadArray($id)] && \
			![string match nil [lindex $data 0]]&& \
			![string match nil [lindex $quadArray($id) 0]]} {
		    set ox [expr [lindex $quadArray($id) 0]-50]
		    set oy [expr [lindex $quadArray($id) 1]-50]
		    set oz [expr $base+[lindex $quadArray($id) 2]]
		    set x [expr [lindex $data 0]-50]
		    set y [expr [lindex $data 1]-50]
		    set z [expr $base+[lindex $data 2]]
		    if {[llength $id]} {
			set pop "index: $id"
		    } else {
			set pop {}
		    }
		    
		    lappend trunks [list line $pop "$ox $oy $oz" \
					"$x $y $z" 1 [lindex $colours $col]]
		}
	    }
	}
	set $oldQuadName $quadlist
	incr col
	if {$col==6} {set col 0}
    }
    return $trunks
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

proc MoveDisplay {winId} {
    variable grid
    variable viewVector
    variable trunks
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

proc WindowSizeChanged {winId} {
    variable viewVector
    if {[info exists viewVector($winId,X)]} {
	set OldX $viewVector($winId,X)
	set OldY $viewVector($winId,Y)
	set viewVector($winId,X) [winfo width $winId.c]
	set viewVector($winId,Y) [winfo height $winId.c]
	
	$winId.c delete key
	$winId.c scale all 0 0 [expr 1.0*$viewVector($winId,X)/$OldX] \
	    [expr 1.0*$viewVector($winId,Y)/$OldY]
	ShowKey $winId
    } else {
	set viewVector($winId,X) [winfo width $winId.c]
	set viewVector($winId,Y) [winfo height $winId.c]
	MoveDisplay $winId
    }
}
}
