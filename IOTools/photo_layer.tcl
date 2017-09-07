# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Photo20131023
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable transform

    proc Identify {} {
	return "Background photo"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	array set transform [list xzoom $xzoom yzoom $yzoom]
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    # format of state is offx offy zoomx zoomy pngdata
	    image create photo $this.orig -data [lindex $State 5]
	    PutSize $this.orig
	} else {
	    # new instance so request data from model
	    set photoFile [ChooseFile aerial.gif "Image for base photo:" 0 \
			       [GetNode]]
	    image create photo $this.orig -file $photoFile
	    PutSize $this.orig
# scale down image if would be very large
	    set scale 1.0
	    while {[$this.orig cget -width]*$xzoom*$scale>1000} {
		set scale [expr {$scale/10}]
	    }
	    set State [list 0 0 $scale $scale [file tail $photoFile] \
			   [$this.orig data -format png]]
	}
#	puts [$this.orig configure]
	ZoomTo $xzoom $yzoom
    }

    destructor {
	$winId delete $this.main
	image delete $this.derived $this.orig
    }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
	set stickX [expr {[lindex $State 0]*$xzoom}]
	set stickY [expr {[lindex $State 1]*$yzoom}]
	set tmpImg [GrowImage $this.orig \
			[expr {int([$this.orig cget -width]*[lindex $State 2]*$xzoom)}] \
			[expr {int([$this.orig cget -height]*[lindex $State 3]*$yzoom)}]]
	set myTag [namespace tail $this].main
	if {[catch {$this.derived blank}]} { ;# not yet exist
	    image create photo $this.derived
	    $winId create image $stickX $stickY -anchor sw -tag $myTag \
						 -image $this.derived
	} else {
	    $winId coords [$winId find withtag $myTag] [list $stickX $stickY]
	}
	$this.derived copy $tmpImg -shrink
    }

    public method GetTitle {} {
	return "Photo: [lindex $State 4]"
    }

    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
#	if {[string equal displaying $useNodes($winId,state)]} {
	    $winId raise [namespace tail $this].main
#	}
    }

    public method Settings {} {
	set dlg [PutItThere .polyprop [winfo toplevel $winId]]
	wm title $dlg [tr. "Photo layer properties"]
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
	foreach key {exo eyo exs eys} elt [lrange $State 0 3] {
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

    public method AdjRange {rg} {
	set rg .polyprop.relgeom

	lset State 0 [$rg.exo get]
	lset State 1 [$rg.eyo get]
	lset State 2 [$rg.exs get]
	lset State 3 [$rg.eys get]

	ZoomTo $transform(xzoom) $transform(yzoom)
    }
}