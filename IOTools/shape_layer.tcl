
# 2-d shapes layer helper -- basically will use the 3-d engine with
# 0 for the z coords

oo::class create iotool::ShapeLayer {
    superclass iotool::Layer
    variable host useNodes winId engine
    
    constructor {modelInst mainCanvas type xzoom yzoom {state {}}} {
	next $modelInst $mainCanvas
	
	set useNodes(curZoom) [list $xzoom $yzoom]
	if {[lindex $state end 0] eq "layer_transform"} {
	    # recent enough to have transform info
	    set useNodes(transform) [lrange [lindex $state end] 1 end]
	    set state [lrange $state 0 end-1]
	} else {
	    set useNodes(transform) {0 0 1 1}
	}
	my SetScaling
	set engine [self object]_3dinst
	::iotool::Shapes3D20141208 create $engine $modelInst \
	    [list layer $type $winId $host $xzoom $yzoom] $state
    }

### Public methods ###
    method zoomTo {x y} {
	variable host
	variable engine
	set useNodes(curZoom) [list $x $y]
	set spec [lindex [$engine getState] 0]
	if {[lindex $spec 0] eq "lines"} {
	    set field [$host getCanvas]
	    set newWidth [expr {0.3*$x*[lindex $spec 7]}]p
	    $field itemconfig [namespace tail [self]].main -width $newWidth
	}
	my SetScaling
    }

    method display {time dispInt step} {
	my SetScaling ;# avoid interference from other shape layers
	$engine display $time $dispInt $step
    }
    
    method prepareSaveString {} {
	set State [$engine getState]
	lappend State [concat layer_transform $useNodes(transform)]
	# will not break legacy drawing, at end to avoid inTitle choice
	return $State
    }

    method settings {} {
	set dlg [PutItThere .shapeprop [winfo toplevel $winId]]
	wm title $dlg "[my getTitle] properties"
        
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
		  -command [namespace code [list my AdjRange $rg]]] \
		  -side left
        pack [ttk::button $dlg.btns.done -text [tr. Done] \
		  -command "set polyProps(xdone) 1"] -side right
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
    }

### Private methods ###
    method GetTitle {} {
	return [GetSortTitle abstract]
    }

    method GetSortTitle {sort} {
	return "$sort for [join [lrange [split [$engine getInTitle] /] end-1 end] /]"
    }

    method SetScaling {} {
	set subWin [winfo parent $winId]
	foreach {x y} $useNodes(curZoom) {}
	foreach {xo yo xs ys} $useNodes(transform) {} ;# add use later
	array set ::gen3d1::scaleVector \
	    [list $subWin,xoff [expr {(250.0/$x-$xo)/$xs}] \
		 $subWin,yoff [expr {-(250.0/$y+$yo)/$ys}] \
		 $subWin,xmag [expr {500.0/$xs/$x}] \
		 $subWin,ymag [expr {500.0/$ys/$y}]]
    }

    method AdjRange {rg} {
	set useNodes(transform) [list [$rg.exo get]  [$rg.eyo get] \
				     [$rg.exs get]  [$rg.eys get]]
	my SetScaling
	my display 0 0 0
    }
}
