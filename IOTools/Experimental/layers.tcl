# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Layers20131022
itcl::class similescript::$newHelperClass {
    inherit Helper

    variable planes
    variable transform
    variable serialActive

    proc Identify {} {
	return "Multi-layer 2-D display"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	# menu
	menu $winId.add -tearoff 0
	$winId.add add cascade -label [tr. "New layer here"] \
	    -menu .layers.sub2
	bind $winId.add <<MenuSelect>> [list $this LayerReady]
	menu $winId.edit -tearoff 0
	$winId.edit add command -label [tr. "Move to top"] \
	    -command [list $this MoveCurrentToTop]
	$winId.edit add command -label [tr. "Move up a level"] \
	    -command [list $this MoveUpALevel]
	$winId.edit add command -label [tr. "Move down a level"] \
	    -command [list $this MoveDownALevel]
	$winId.edit add command -label [tr. "Move to bottom"] \
	    -command [list $this MoveCurrentToBottom]
	$winId.edit add command -label [tr. "Delete"] \
	    -command [list $this DeleteCurrent]
	$winId.edit add command -label [tr. "Properties..."] \
	    -command [list $this EditCurrent]

        set toolbarItems [list \
                [list zoomin.gif "Zoom in" "$this Zoom 2 2"] \
                [list zoomout.gif "Zoom out" "$this Zoom 0.5 0.5"] \
                [list zoomfit.gif "Zoom to fit" "$this Fit"] \
		[list text.gif "Add text" \
		     [list ::canvasnotes20070919::DialogInMiddle $winId]]]
        ::graphtools::MakeToolBar $winId $toolbarItems

# now create the canvas and sliders
	pack [set vp [frame $winId.viewport]] -fill both -expand true
        scrollbar $vp.xsc -orient horizontal \
	    -command [list $vp.c xview]
        pack $vp.xsc -side bottom -fill x
        scrollbar $vp.ysc -orient vertical \
	    -command [list $vp.c yview]
        pack $vp.ysc -side right -fill y
        canvas $vp.c -xscrollcommand [list $this SetWithLegends x] \
	    -yscrollcommand [list $this SetWithLegends y] -bg beige
	::canvasnotes20070919::MakeCanvasAnnotatable $vp.c
	bind $vp.c <Configure> [list $this PosnLegends]
        pack $vp.c -fill both -expand true

	set planes {}
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    # local version probably NOT want to be XML...unlike saved...
	    foreach geomer {offx offy zoomx zoomy bounds} val $state {
		set transform($geomer) $val
	    }
	    $vp.c configure -scrollregion $transform(bounds)
	    set serialActive 0
	    foreach {layerType layerState} [lrange $state 5 end] {
		NewLayer $layerType $layerState
	    }
	    foreach {l t r b} $transform(bounds) {
		$vp.c xview moveto [expr {($transform(offx)-$l)*1.0/($r-$l)}]
		$vp.c yview moveto [expr {($transform(offy)-$t)*1.0/($b-$t)}]
	    }
	    update
	    PosnLegends
	} else {
	    $vp.c config -scrollregion \
		[list 0 0 [winfo width $winId] [winfo height $winId]]
	    array set transform {offx 0 offy 0 zoomx 1 zoomy 1}
	    # new instance so request data from model
	    pack [message $winId.message \
		      -text "Select a plane display tool from the Layers menu"]
	}
    }

    public method SetWithLegends {axis newLo newHi} {
	set vp $winId.viewport
	foreach {lo hi} [$vp.${axis}sc get] {}
	$vp.${axis}sc set $newLo $newHi
	if {abs($newLo+$hi-$lo-$newHi)>1e-6} return
	# scrollregion changed, zoom proc takes care of legends

	foreach {l t r b} [$vp.c cget -scrollregion] {
	    if {$axis eq "y"} {
		set mag [expr {$b-$t}]
		set tail {0 $motn}
	    } else {
		set mag [expr {$r-$l}]
		set tail {$motn 0}
	    }	    
	    set motn [expr {$mag*($newLo-$lo)}]
	    foreach layer $planes {
		eval {$vp.c move $layer.legend} $tail
	    }
	}
    }

    public method LegendFollows {side moveTo newFr} {
	# puts [info level 0]
	set cnv $winId.viewport.c
	foreach {l t r b} [$cnv cget -scrollregion] {}
	if {$side eq "yview"} {
	    set mag [expr {$b-$t}]
	    set tail {0 $motn}
	} else {
	    set mag [expr {$r-$l}]
	    set tail {$motn 0}
	}
	foreach {lo hi} [$cnv $side] {}
	if {$newFr < 0 || $newFr > 1+$lo-$hi} return ;# over limit
	set motn [expr {$mag*($newFr-$lo)}]
	foreach layer $planes {
	    eval {$cnv move $layer.legend} $tail
	}
	$cnv $side moveto $newFr
    }

    public method CustomizeAddMenu {bar entry} {
	$bar insert $entry cascade -label Layers -menu $winId.add
	return normal
    }

    public method LayerReady {} {
#	set chng [$winId.add index active]
# The above does not work, because TclTk is rapidly crumbling to dust.
# Here is a workaround...
	set chng $::tk::Priv(activeItem)
	
	if {$chng ne "none"} {
	    set serialActive $chng
	}
    }

    public method GetCanvas {} {
	return $winId.viewport.c
    }

    public method Print {} {
	PrintRandomCanvas [GetCanvas]
    }
    public method CopyToClipboard {} {
	# if {[string match windows $tcl_platform(platform)]} {
	    CopyCanvasToWindowsClipboard [GetCanvas] 0
	# }
    }

    public method NewLayer {type {state {}}} {
	set id [UniqueId layer]
	set layerObj [$type $id $modelInst $this \
			  $transform(zoomx) $transform(zoomy) $state]
	set cnv $winId.viewport.c
	pack forget $winId.message
	set planes [linsert $planes end-[expr {$serialActive/2}] $layerObj]
	$winId.add insert $serialActive cascade -label [$layerObj GetTitle] \
	    -menu $winId.edit
	$winId.add insert $serialActive cascade -label [tr. "New layer here"] \
	    -menu .layers.sub2
    }

    public method MoveCurrentToTop {} {
	set oldIdx end-[expr {$serialActive/2}]
	set layerObj [lindex $planes $oldIdx]
	$winId.viewport.c raise $layerObj.main
	set planes [linsert [lreplace $planes $oldIdx $oldIdx] end $layerObj]
	$winId.add delete $serialActive [incr serialActive]
	$winId.add insert 0 cascade -label [$layerObj GetTitle] \
	    -menu $winId.edit
	$winId.add insert 0 cascade -label [tr. "New layer here"] \
	    -menu .layers.sub2
    }

    public method MoveCurrentToBottom {} {
	set oldIdx end-[expr {$serialActive/2}]
	set layerObj [lindex $planes $oldIdx]
	$winId.viewport.c lower $layerObj.main
	set planes [linsert [lreplace $planes $oldIdx $oldIdx] 0 $layerObj]
	$winId.add delete $serialActive [incr serialActive]
	$winId.add add cascade -label [$layerObj GetTitle] \
	    -menu $winId.edit
	$winId.add add cascade -label [tr. "New layer here"] \
	    -menu .layers.sub2
    }

    public method DeleteCurrent {} {
	set oldIdx end-[expr {$serialActive/2}]
	itcl::delete object [lindex $planes $oldIdx]
	set planes [lreplace $planes $oldIdx $oldIdx]
	$winId.add delete $serialActive [incr serialActive]
    }

    public method EditCurrent {} {
	puts [info level 0]
	set oldIdx end-[expr {$serialActive/2}]
	[lindex $planes $oldIdx] Settings
    }

    public method Click {path} {
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	foreach plane $planes {
	    $plane Display $time $dispInt $step
	}
	foreach plane $planes {
	    $winId.viewport.c raise $plane.legend
	}
	$winId.viewport.c raise annotation
    }

    public method PrepareSaveString {} {
	set id $winId.viewport.c
	set State [list [$id canvasx 0] [$id canvasy 0] \
		       $transform(zoomx) $transform(zoomy) \
		       [$id cget -scrollregion]] ;# offset zoom and bounds
	foreach layer $planes {
	    $layer PrepareSaveString
	    lappend State [$layer info class] [$layer cget -State]
	}
    }

    public method Zoom {fx fy} {
	set id $winId.viewport.c
# first, find where canvas point at middle ends up
	set ww [winfo width $id]
	set wh [winfo height $id]
#	if {[$id cget -scrollregion] eq {}} {
#	    $id config -scrollregion [list 0 0 $ww $wh]
#	}
	set xfroml [expr {$ww/2}]
	set yfromt [expr {$wh/2}]
	set oldMidX [$id canvasx $xfroml]
	set oldMidY [$id canvasy $yfromt]
	set middleX [expr {$fx*$oldMidX}]
	set middleY [expr {$fy*$oldMidY}]
# update zoom state
	set transform(zoomx) [expr {$fx*$transform(zoomx)}]
	set transform(zoomy) [expr {$fy*$transform(zoomy)}]
# throw a scale command at everything on the canvas
# then contact indiviual layers to sort out stuff like line widths
	foreach layer $planes {
	    $id scale $layer.main 0 0 $fx $fy
	    $layer ZoomTo $transform(zoomx) $transform(zoomy) 
	    $id move $layer.legend \
		[expr {$middleX-$oldMidX}] [expr {$middleY-$oldMidY}]
	}
	$id scale annotation 0 0 $fx $fy
# finally scroll so old middle is still in middle
# 	foreach {l t r b} [BboxForGroup $id main] {}
 	foreach side {l t r b} edge [$id cget -scrollregion] \
	    z [list $fx $fy $fx $fy] {
		set $side [expr {$z*$edge}]
	    }
	if {$r-$l<$ww} {
	    set l [expr {($l+$r-$ww)/2}]
	    set r [expr {$l+$ww}]
	}
	if {$b-$t<$wh} {
	    set t [expr {($t+$b-$wh)/2}]
	    set b [expr {$t+$wh}]
	}
	$id config -scrollregion [list $l $t $r $b]
	set newMidX [expr {(($middleX-$xfroml)-$l)/($r-$l)}]
	set newMidY [expr {(($middleY-$yfromt)-$t)/($b-$t)}]
	$id xview moveto $newMidX
	$id yview moveto $newMidY
    }

    public method Fit {} {
	set id $winId.viewport.c
	foreach {l t r b} [BboxForGroup $id main] {}
	$id config -scrollregion [list $l $t $r $b]
	set scale [expr {[winfo width $id]/(0.0+$r-$l)}]
	set vscale [expr {[winfo height $id]/(0.0+$b-$t)}]
	if {$vscale<$scale} {
	    set scale $vscale
	}
	Zoom $scale $scale
	PosnLegends
    }

    method BboxForGroup {id style} {
	foreach plane $planes {
	    lappend mains $plane.$style
	}
	return [eval {$id bbox} $mains]
    }

    public method PosnLegends {} {
# all legends must be positioned at once because changing one may change posns
# of others
	set id $winId.viewport.c
	set legendWidth 40

	set l 0
	set t 0
	set r 0
	set b 0
	set w [winfo width $id]
	set h [winfo height $id]

	foreach plane $planes {
	    $id delete $plane.legend
	    set side [$plane GetNewLegendSide]
# right...legend will be drawn bottom or right across full width/height
# ..now we have to shove it to its alloted posn
	    if {$side eq "n"} continue
	    $id itemconfigure caption -text [$plane GetTitle]
	    switch -regexp $side {
		l|r {
		    set py $t
		    set sx 1
		    set sy [expr {1.0*($h+$b-$t)/$h}]
		    if {$side eq "l"} {
			set px [expr {$l+$legendWidth-$w}]
		    } else {
			set px $r
		    }
		} t|b {
		    set px $l
		    set sy 1
		    set sx [expr {1.0*($w+$r-$l)/$w}]
		    if {$side eq "t"} {
			set py [expr {$t+$legendWidth-$h}]
		    } else {
			set py $b
		    }
		}
	    }
	    $id addtag $plane.legend withtag colour_scale
	    $id dtag colour_scale
	    $id addtag $plane.legend withtag caption
	    $id dtag caption
	    $id move $plane.legend $px $py
	    $id scale $plane.legend [$id canvasx $l] [$id canvasy $t] $sx $sy

	    switch -regexp $side {
		l|t {
		    set $side [expr {[set $side]+$legendWidth}]
		} r|b {
		    set $side [expr {[set $side]-$legendWidth}]
		}
	    }
	}
	set transform(aperture) [list $l $t $r $b]
    }
}
