namespace eval ::threedtools {
    
    namespace export SetBaseVectors project DrawShapes

proc SetBaseVectors {winId ang elv} {
    variable viewVector
    set viewVector($winId,cos_angle) [expr cos($ang)]
    set viewVector($winId,sin_angle) [expr sin($ang)]
    set viewVector($winId,cos_elevation) [expr cos($elv)]
    set viewVector($winId,sin_elevation) [expr sin($elv)]
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

    set scx [expr [winfo width $winId.c]*($rotx/150.0 + .5)]
    set scy [expr [winfo height $winId.c]*(($multx*$ptz - $multy*$roty)/-150.0 + .5)]
    set depth [expr -$multx*$roty - $multy*$ptz]

#ShowMessage debug info "pt3d $pt3d rots $rotx $roty cams $scx $scy $depth" ok
    return [list $scx $scy $depth]
}

proc DrawShapes {winId solids tag} {
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
		set rad [expr [winfo height $winId.c]*[lindex $object3d 3]/150.0]
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

}
