# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Layers20131022
itcl::class similescript::$newHelperClass {
    inherit Helper

    variable planes
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

	pack [canvas $winId.c] -fill both -expand true
	# add sliders
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
	} else {
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
	set layerObj [$type $id $modelInst $winId.c 1 1 $state]
	pack forget $winId.message
	set planes [linsert $planes end-[expr {$serialActive/2}] $layerObj]
	$winId.add insert $serialActive cascade -label [$layerObj GetTitle] \
	    -menu $winId.edit
	$winId.add insert $serialActive cascade -label [tr. "New layer here"] \
	    -menu .layers.sub2
    }

    public method DeleteCurrent {} {
	set oldIdx end-[expr {$serialActive/2}]
	itcl::delete object [lindex $planes $oldIdx]
	set planes [lreplace $planes $oldIdx $oldIdx]
	$winId.add delete $serialActive [incr serialActive]
    }
    public method Click {path} {
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	foreach plane $planes {
	    $plane::Display $time $dispInt $step
	}
    }

    public method PrepareSaveString {} {
	set State {0 0 1 1} ;# offset and zoom
	foreach layer $planes {
	    $layer PrepareSaveString
	    lappend State [$layer info class] [$layer cget -State]
	}
    }
}