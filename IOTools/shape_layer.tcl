# 2-d shapes layer helper -- basically will use the 3-d engine with
# 0 for the z coords

itcl::class similescript::ShapeLayer {
    inherit Layer
    variable useNodes

    constructor {modelInst mainCanvas type xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	set useNodes(curZoom) [list $xzoom $yzoom]
	if {[lindex $state end 0] eq "layer_transform"} {
	    # recent enough to have transform info
	    set useNodes(transform) [lrange [lindex $state end] 1 end]
	    set state [lrange $state 0 end-1]
	} else {
	    set useNodes(transform) {0 0 1 1}
	}
	SetScaling
	::similescript::Shapes3D20141208 ${this}_3dinst $modelInst \
	    [list layer $type $winId $xzoom $yzoom] $state
    }

    destructor {
	itcl::delete object ${this}_3dinst
	$winId delete [namespace tail $this].main
    }

    public method GetTitle {} {
	return [GetSortTitle abstract]
    }

    public method GetSortTitle {sort} {
	return "$sort for [join [lrange [split [${this}_3dinst cget -inTitle] /] end-1 end] /]"
    }

    public method Display {time dispInt step} {
	SetScaling ;# avoid interference from other shape layers
	${this}_3dinst Display $time $dispInt $step
    }

    public method SetScaling {} {
	set subWin [winfo parent $winId]
	foreach {x y} $useNodes(curZoom) {}
	foreach {xo yo xs ys} $useNodes(transform) {} ;# add use later
	array set ::gen3d1::scaleVector \
	    [list $subWin,xoff [expr {(250.0/$x-$xo)/$xs}] \
		 $subWin,yoff [expr {-(250.0/$y+$yo)/$ys}] \
		 $subWin,xmag [expr {500.0/$xs/$x}] \
		 $subWin,ymag [expr {500.0/$ys/$y}]]
    }
    
    public method ZoomTo {x y} {
	set useNodes(curZoom) [list $x $y]
	SetScaling
    }
    
    public method PrepareSaveString {} {
	set State [${this}_3dinst cget -State]
	lappend State [concat layer_transform $useNodes(transform)]
	# will not break legacy drawing, at end to avoid inTitle choice
    }

    public method AdjRange {rg} {
	set useNodes(transform) [list [$rg.exo get]  [$rg.eyo get] \
				     [$rg.exs get]  [$rg.eys get]]
	SetScaling
	Display 0 0 0
    }

    public method Settings {} {
	set dlg [PutItThere .shapeprop [winfo toplevel $winId]]
	wm title $dlg "[GetTitle] properties"
	wm protocol $dlg WM_DELETE_WINDOW "set polyProps(xdone) 0"
        
	set rg [labelframe $dlg.relgeom -text "Offset and scaling"]
	grid [label $rg.lxo -text [tr. {X offset:}]] \
	    [ttk::entry $rg.exo -width 8] \
	    [label $rg.lyo -text [tr. {Y offset:}]] \
	    [ttk::entry $rg.eyo -width 8]
	grid [label $rg.lxs -text [tr. {X scale:}]] \
	    [ttk::entry $rg.exs -width 8] \
	    [label $rg.lys -text [tr. {Y scale:}]] \
	    [ttk::entry $rg.eys -width 8]
	pack $rg -fill x
	foreach key {exo eyo exs eys} elt $useNodes(transform) {
	    $rg.$key insert 0 $elt
	}
	pack [frame $dlg.btns] -fill x
	pack [ttk::button $dlg.btns.apply -text [tr. Apply] \
		  -command [list $this AdjRange $rg]] -side left
        pack [ttk::button $dlg.btns.done -text [tr. Done] \
		  -command "set polyProps(xdone) 1"] -side right
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
    }
}
