set keyValue gen3d

namespace eval ::$keyValue {
variable useNodes


proc identify {} {
	return "Generic 3-d helper"
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
   canvas $winId.c -width 1 -height 1 -bg white
   frame $winId.buttons -relief raised -bd 1
   button $winId.buttons.but_print -text "Print..." \
      -command "PrintNow $winId.c"
   button $winId.buttons.but_view -text "aboveBelow" \
      -command " [namespace current]::toggleViewpoint $winId"
   button $winId.buttons.but_order -text "Swap Z Order" \
      -command " [namespace current]::toggleZOrder $winId"
   label $winId.buttons.label_draw -text "Ready  " -relief sunken
      
	pack $winId.c -fill both -expand true
    pack $winId.buttons.but_view -side right
    pack $winId.buttons.but_order -side right
    pack $winId.buttons.but_print -side right
    pack $winId.buttons.label_draw -side left -padx 2
    pack $winId.buttons -fill x
            
    bind $winId.c <Configure> \
                [namespace code " WindowSizeChanged $winId $xs $ys $hs"]
    set pi 3.14159
    array set viewVector [list angle -0.3 elevation 0.5]

#Grid is always displayed so only define it once
    set grid {}
    for {set x -50} {$x <= 50} {incr x 10} {
	lappend grid [list line "$x -50 0" "$x 50 0" 1 red]
    }
    for {set y -50} {$y <= 50} {incr y 10} {
	lappend grid [list line "-50 $y 0" "50 $y 0" 1 red]
    }
}

proc display {winId time step remainder} {
    variable grid
    if {[string match display [lindex [GetState $winId] 0]]} {
    }
}

proc DrawShapes {winId solids tag} {
    variable viewVector

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
		$winId.c create line $startx $starty $endx $endy -tag $tag \
		    -width [lindex $object3d 3] -fill [lindex $object3d 4]
	    }
	}
    }
}

proc project {pt3d} {
    variable viewVector
    set ptx [lindex $pt3d 0]
    set pty [lindex $pt3d 1]
    set ptz [lindex $pt3d 2]

    set multx [expr cos($viewVector(angle))]
    set multy [expr sin($viewVector(angle))]

    set rotx [expr $multx*$ptx + $multy*$pty]
    set roty [expr $multx*$pty - $multy*$ptx]

    set multx [expr cos($viewVector(elevation))]
    set multy [expr sin($viewVector(elevation))]

    set scx [expr $viewVector(winX)*($rotx/150.0 + .5)]
    set scy [expr $viewVector(winY)*(($multx*$ptz - $multy*$roty)/-150.0 + .5)]
    set depth [expr -$multx*$roty - $multy*$ptz]

#ShowMessage debug info "pt3d $pt3d rots $rotx $roty cams $scx $scy $depth" ok
    return [list $scx $scy $depth]
}
    
proc WindowSizeChanged {winId xs ys hs} {
    variable grid
    variable viewVector
    $winId.c delete all
    set viewVector(winX) [winfo width $winId.c]
    set viewVector(winY) [winfo height $winId.c]
    DrawShapes $winId $grid grid
}

proc OrderHs {quad1 quad2} {
variable zOrder
	set p [lindex $quad1 2]
	set q [lindex $quad2 2]
   if { "$zOrder"=="UP" } {
      return [expr ($p>$q) - ($q>$p)]
   } else {
      return [expr ($p<$q) - ($q<$p)]
   }
}

} ;# end namespace
