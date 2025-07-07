# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Photo20131023
oo::class create iotool::$newLayerClass {
    superclass iotool::Layer
    variable transform State winId

    self {
	method identify {} {
	    return "Background photo"
	}
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
	next $modelInst $mainCanvas
	
	array set transform [list xzoom $xzoom yzoom $yzoom]
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    # format of state is offx offy zoomx zoomy pngdata
	    image create photo [self].orig \
		-data [base64::decode [lindex $State 5]] -format png
	    PutSize [self].orig
	} else {
	    # new instance so request data from model
	    set photoFile [ChooseFile aerial.gif "Image for base photo:" 0 \
			       [GetNode]]
	    image create photo [self].orig -file $photoFile
	    PutSize [self].orig
# scale down image if would be very large
	    set scale 1.0
	    while {[[self].orig cget -width]*$xzoom*$scale>1000} {
		set scale [expr {$scale/10}]
	    }
	    set State [list 0 0 $scale $scale [file tail $photoFile] \
			   [base64::encode [[self].orig data -format png]]]
	}
#	puts [[self].orig configure]
	my zoomTo $xzoom $yzoom
    }

    destructor {
	foreach mine {derived orig} {
	    if {[lsearch [image names] [self].$mine]>=0} {
		image delete [self].$mine
	    }
	}
	next
    }

### Public methods ###
    method settings {} {
	set dlg [PutItThere .polyprop [winfo toplevel $winId]]
	wm title $dlg [tr. "Photo layer properties"]
        
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
		  -command [list [self] AdjRange $rg]] -side left
        pack [ttk::button $dlg.btns.done -text [tr. Done] \
		  -command "set polyProps(xdone) 1"] -side right
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
    }

    method zoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
	set stickX [expr {[lindex $State 0]*$xzoom}]
	set stickY [expr {[lindex $State 1]*$yzoom}]
	set tmpImg [GrowImage [self].orig \
			[expr {int([[self].orig cget -width]*[lindex $State 2]*$xzoom)}] \
			[expr {int([[self].orig cget -height]*[lindex $State 3]*$yzoom)}]]
	set myTag [namespace tail [self]].main
	if {[catch {[self].derived blank}]} { ;# not yet exist
	    image create photo [self].derived
	    $winId create image $stickX $stickY -anchor sw -tag $myTag \
						 -image [self].derived
	} else {
	    $winId coords [$winId find withtag $myTag] [list $stickX $stickY]
	}
	[self].derived copy $tmpImg -shrink
    }

    method display {time dispInt step} {
# nothing to do at display time -- it's a photo
#	if {[string equal displaying $useNodes($winId,state)]} {
	    $winId raise [namespace tail [self]].main
#	}
    }
    
    method prepareSaveString {} {
	return $State
    }

    method getTitle {} {
	return "Photo: [lindex $State 4]"
    }
    
    method AdjRange {rg} {
	set rg .polyprop.relgeom

	lset State 0 [$rg.exo get]
	lset State 1 [$rg.eyo get]
	lset State 2 [$rg.exs get]
	lset State 3 [$rg.eys get]

	my zoomTo $transform(xzoom) $transform(yzoom)
    }
}
