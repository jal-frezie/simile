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
                [list zoomfit.gif "Zoom to fit" "$this Fit"]]
        ::graphtools::MakeToolBar $winId $toolbarItems

# now create the canvas and sliders
	pack [set vp [frame $winId.viewport]] -fill both -expand true
        scrollbar $vp.xsc -orient horizontal -command [list $vp.c xview]
        pack $vp.xsc -side bottom -fill x
        scrollbar $vp.ysc -orient vertical -command [list $vp.c yview]
        pack $vp.ysc -side right -fill y
        canvas $vp.c -xscrollcommand [list $vp.xsc set] \
	    -yscrollcommand [list $vp.ysc set] -bg beige
	::canvasnotes20070919::MakeCanvasAnnotatable $vp.c
        pack $vp.c -fill both -expand true

	set planes {}
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    # local version probably NOT want to be XML...unlike saved...
	    foreach geomer {offx offy zoomx zoomy} val $state {
		set transform($geomer) $val
	    }
	    set serialActive 0
	    foreach {layerType layerState} [lrange $state 4 end] {
		NewLayer $layerType $layerState
	    }
	    set bounds [$vp.c bbox all]
	    $vp.c configure -scrollregion $bounds
	    foreach {l t r b} $bounds {}
	    $vp.c xview moveto [expr {($transform(offx)-$l)*1.0/($r-$l)}]
	    $vp.c yview moveto [expr {($transform(offy)-$t)*1.0/($b-$t)}]
	} else {
	    array set transform {offx 0 offy 0 zoomx 1 zoomy 1}
	    # new instance so request data from model
	    pack [message $winId.message \
		      -text "Select a plane display tool from the Layers menu"]
	}
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
	
    public method NewLayer {type {state {}}} {
	set id [UniqueId layer]
	set cnv $winId.viewport.c
	set layerObj [$type $id $modelInst $cnv \
			  $transform(zoomx) $transform(zoomy) $state]
	$cnv configure -scrollregion [$cnv bbox all]
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
    }

    public method PrepareSaveString {} {
	set id $winId.viewport.c
	set State [list [$id canvasx 0] [$id canvasy 0] \
		       $transform(zoomx) $transform(zoomy)] ;# offset and zoom
	foreach layer $planes {
	    $layer PrepareSaveString
	    lappend State [$layer info class] [$layer cget -State]
	}
    }

    public method Zoom {fx fy} {
	set id $winId.viewport.c
# first, find where canvas point at middle ends up
	set xfroml [expr {[winfo width $id]/2}]
	set yfromt [expr {[winfo height $id]/2}]
	set middleX [expr {$fx*[$id canvasx $xfroml]}]
	set middleY [expr {$fy*[$id canvasx $yfromt]}]
# update zoom state
	set transform(zoomx) [expr {$fx*$transform(zoomx)}]
	set transform(zoomy) [expr {$fy*$transform(zoomy)}]
# throw a scale command at everything on the canvas
	$id scale all 0 0 $fx $fy
# then contact indiviual layers to sort out stuff like line widths
	foreach layer $planes {
	    $layer ZoomTo $transform(zoomx) $transform(zoomy) 
	}
# finally scroll so old middle is still in middle
	set sr [$id bbox all]
	$id configure -scrollregion $sr
	foreach {l t r b} $sr {}
	set newMidX [expr {(($middleX-$xfroml)-$l)/($r-$l)}]
	set newMidY [expr {(($middleY-$yfromt)-$t)/($t-$b)}]
	$id xview moveto $newMidX
	$id yview moveto $newMidY
    }

    public method Fit {} {
	set id $winId.viewport.c
	foreach {l t r b} [$id bbox all] {}
	set scale [expr {[winfo width $id]/(0.0+$r-$l)}]
	set vscale [expr {[winfo height $id]/(0.0+$b-$t)}]
	if {$vscale<$scale} {
	    set scale $vscale
	}
	Zoom $scale $scale
    }
}
