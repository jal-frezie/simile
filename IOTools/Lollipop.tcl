# Tree01
# Tcl vertical-line display for spatially-referenced individuals
# Oct 97 -- version works with Tcl 8.0 and uses namespaces

########################
# 
# 270298 - modified to allow plan view of the scene. Also coloured the 'stems'
# brown and changed bg to white.
# a: Changed the ordering for the 2 views.
# RTE version nasty loop in Classic environment

set keyValue lollipopRTE05657

namespace eval ::$keyValue {
variable useNodes
variable width; # of canvas 
variable height; # of canvas
variable sx; # x scale factor
variable sy


proc identify {} {
	return "Lollipop diagram"
}

proc initialize {winId} {
variable viewpoint "ELEVATION"
variable zOrder "UP"
variable redrawLines 1
#    if ![winfo exists .mre] {
#        ShowMessage Warning info "Lollipop diagram (RTE) only works in the\
#                Run Time Environment (RTE)" ok
#        destroy $winId
#    }
    set ms [message $winId.intro -text "Click on the array value \
			representing the X coordinates of the treelike objects to be \
			displayed."]
	GrabClicks $winId
	pack $ms
	SetState $winId xcoord
}

proc Restore {winId} {
    variable useNodes
    variable viewpoint
    variable zOrder

    variable width; # of canvas
    variable height; # of canvas
    variable redrawLines

    set width($winId) 650; # of canvas
    set height($winId) 500; # of canvas
    set redrawLines 1

    set nodeList [GetState $winId]
    if {[string match displaying [lindex $nodeList 0]]} {
	set useNodes($winId,xcoord) [GetIdFromCaptionPath [lindex $nodeList 1]]
	set useNodes($winId,ycoord) [GetIdFromCaptionPath [lindex $nodeList 2]]
	set useNodes($winId,size) [GetIdFromCaptionPath [lindex $nodeList 3]]
	set viewpoint [lindex $nodeList 4]
	set zOrder [lindex $nodeList 5]
	InitializeForest $winId $useNodes($winId,xcoord) \
	    $useNodes($winId,ycoord) $useNodes($winId,size)
    } else {
	GrabClicks $winId
    }
}

proc GetCanvas {winId} {
    return $winId.c
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
		InitializeForest $winId $xnode $ynode $node
		catch {wm geometry $winId 650x500}
		SaveState $winId
	    }
	}
    } else {
	$ms configure -text \
	    "This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc SaveState {winId} {
    variable useNodes
    variable viewpoint
    variable zOrder

    set state displaying
    foreach node {xcoord ycoord size} {
	lappend state [GetCaptionPathFromId $useNodes($winId,$node)]
    }
    lappend state $viewpoint $zOrder
    SetState $winId $state
}

proc display {winId time step remainder} {
	variable useNodes
	if {[string compare [lindex [GetState $winId] 0] \
			displaying] == 0} {
		DropTrees $winId $useNodes($winId,xcoord) $useNodes($winId,ycoord) \
			$useNodes($winId,size)  
	}
}

proc toggleViewpoint { winId } {
variable redrawLines 1
variable viewpoint
variable old_xs
variable old_ys
variable old_hs
    set viewpoint [expr ("$viewpoint"=="PLAN")?"ELEVATION":"PLAN"]
    DropTrees $winId $old_xs $old_ys $old_hs
    SaveState $winId
}

proc toggleZOrder { winId } {
variable viewpoint
variable old_xs
variable old_ys
variable old_hs
variable zOrder
    if { "$viewpoint"=="PLAN" } {
	set zOrder [expr ("$zOrder"=="UP")?"DOWN":"UP"]
	DropTrees $winId $old_xs $old_ys $old_hs
    }
    SaveState $winId
}

proc InitializeForest {winId xs ys hs} {
variable viewpoint
variable width; # of canvas
variable height; # of canvas
   
   canvas $winId.c -width 1 -height 1 -bg white
   frame $winId.buttons -relief raised -bd 1
   button $winId.buttons.but_view -text "aboveBelow" \
      -command " [namespace current]::toggleViewpoint $winId"
   button $winId.buttons.but_order -text "Swap Z Order" \
      -command " [namespace current]::toggleZOrder $winId"
   label $winId.buttons.label_draw -text "Ready  " -relief sunken
      
	pack $winId.c -fill both -expand true
    pack $winId.buttons.but_view -side right
    pack $winId.buttons.but_order -side right
    pack $winId.buttons.label_draw -side left -padx 2
    pack $winId.buttons -fill x

    set width($winId) [winfo width $winId.c]; #650 of canvas buttons should show buttons
    set height($winId) [winfo height $winId.c]; #500 of canvas
            
    DropTrees $winId $xs $ys $hs
    bind $winId <Configure> \
                [namespace code " WindowSizeChanged $winId $xs $ys $hs"]
}

proc WindowSizeChanged {winId xs ys hs} {
    variable redrawLines
    set redrawLines 1
    DropTrees $winId $xs $ys $hs    
}

# resizes canvas
proc resize { winId tag newWidth newHeight } {
	error Resizing
    variable width; # of canvas
    variable height; # of canvas
    set xscale [expr {(1.0*$newWidth)/(1.0*$width($winId))}]
    set yscale [expr {(1.0*$newHeight)/(1.0*$height($winId))}]
################################################################################
#     ShowMessage debug info "width $width\n\
#             height $height\n\
#             newWidth $newWidth\n\
#             newHeight $newHeight\n\
#             xscale $xscale\n\
#             yscale $yscale" ok
################################################################################
    $winId.c scale $tag 0 0 $xscale $yscale
    set width($winId) $newWidth
    set height($winId) $newHeight

}

proc drawLines { winId } {
    variable redrawLines 0
    variable sx
    variable sy
    set y 0
    while {$y<=100} {
        $winId.c create line [expr $sx($winId)*[canvasx 0 $y]]\
                [expr $sy($winId)*[canvasy 0 $y]] [expr $sx($winId)*[canvasx 100 $y]]\
                [expr $sy($winId)*[canvasy 100 $y]] -fill red -tag line
#        update idletasks
        set y [expr $y+10]
    }
    
    set x 0
    while {$x<=100} {
        $winId.c create line [expr $sx($winId)*[canvasx $x 0]] [expr $sy($winId)*[canvasy $x 0]] \
                [expr $sx($winId)*[canvasx $x 100]] [expr $sy($winId)*[canvasy $x 100]] -fill red -tag line
#        update idletasks
        set x [expr $x+10]
    }
}

proc DropTrees {winId xs ys hs} {
variable redrawLines
variable viewpoint
variable old_xs
variable old_ys
variable old_hs
variable sx
variable sy
   $winId.buttons.label_draw configure -text "DRAWING" -bg red
#   update idletasks

   set old_xs $xs
   set old_ys $ys
   set old_hs $hs
    
    set sx($winId) [expr (1.0*[winfo width $winId.c])/(650.0)]
    set sy($winId) [expr (1.0*[winfo height $winId.c])/(500.0)]
    
	eval $winId.c delete [$winId.c find withtag tree]

   if { $redrawLines } {
      eval $winId.c delete [$winId.c find withtag line]
      drawLines $winId


   }
	set quadlist {}
	GetQuadList [lindex [GetModelValue $xs] 0] \
			[lindex [GetModelValue $ys] 0] \
			[lindex [GetModelValue $hs] 0]
# previous line appended variable quadlist at this level, now to use it
   if { "$viewpoint"=="ELEVATION" } {
      set quadlist [lsort -command OrderYs $quadlist]
   } else {
      set quadlist [lsort -command OrderHs $quadlist]
   }
   foreach quad $quadlist {
    set height [lindex $quad 2]
    set x [lindex $quad 0]
    set y [lindex $quad 1]
    set cx [expr [canvasx $x $y]*$sx($winId)]
    set cy [expr [canvasy $x $y]*$sy($winId)]
    set rx [expr [expr $height/2]*$sx($winId)]
    set ry [expr [expr $height/2]*$sy($winId)]
    set top [expr $cy-5*$height*$sy($winId)]

       if { "$viewpoint"=="ELEVATION" } {
          $winId.c create line $cx $cy $cx $top -fill brown -width 4 \
         -tag tree
          $winId.c create oval [expr $cx-5*$rx] [expr $top-5*$ry] \
         [expr $cx+5*$rx] [expr $top+5*$ry]  -fill green \
         -tag tree
       } else {
          $winId.c create oval [expr $cx-5*$rx] [expr $cy-5*$ry] \
         [expr $cx+5*$rx] [expr $cy+5*$ry]  -fill green \
         -tag tree
       }
       # END if { "$variable"=="ELEVATION" }
  }
  $winId.buttons.label_draw configure -text "Ready  " -bg grey
}

proc GetQuadList {xcoords ycoords heights} {

	upvar 1 quadlist quadlist
	if {[llength $heights] == 1} {
		lappend quadlist [list $xcoords $ycoords $heights]
	} else {
		array set newxs $xcoords
		array set newys $ycoords
		array set newhs $heights

		foreach elt [array names newhs] {
			GetQuadList $newxs($elt) $newys($elt) $newhs($elt)
		}
	}
}

proc OrderYs {quad1 quad2} {
	set p [lindex $quad1 1]
	set q [lindex $quad2 1]
	return [expr ($p<$q) - ($q<$p)]
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

proc canvasx {x y} {
variable viewpoint
  if { "$viewpoint" == "PLAN" } {
      return [expr int(120+(4*$x))]
  } else {
     return [expr int(20+4*$x+2*$y)]
  }
}

proc canvasy {x y} {
variable viewpoint
  if { "$viewpoint" == "PLAN" } {
      return [expr int(440-(4*$y))]
  } else {
     return [expr int(400-2*$y)]
  }
} 

} ;
# end of namespace
