# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass InputPointer20210609
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable useNodes
    variable transform
    variable temp

    proc Identify {} {
	return "Pointer input zone"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	array set transform [list xzoom $xzoom yzoom $yzoom]
	set useNodes(transform) {0 0 1 1}
	$winId create text 0 0 -text "" -tag [namespace tail $this].main
	# needed so reordering works
	if {[string length $state]} { ;# we are restoring 
	    array set useNodes $state
	    foreach comp {xcoord ycoord tgt} {
		set temp($comp) [GetIdFromCaptionPath $useNodes($comp)]
	    }
	    AddBindings
	} else {
            set useNodes(xoff) 0
            set useNodes(yoff) 0
            set useNodes(xscale) 1
            set useNodes(yscale) 1
	    set useNodes(title) [Identify]
	    AddVariable
	}
	array set temp {act {} count 0}
    }

    destructor {
	$winId delete [namespace tail $this].main
	bind $winId <Button-1> {}
	bind $winId <B1-Motion> {}
	bind $winId <ButtonRelease-1> {}
    }

    public method AddVariable {} {
	set ms [winfo parent $winId].bottom.ms
	pack [ttk::label $ms -wraplength [$winId cget -width] -text \
		  [tr. "Click on the input parameter to set to the X co-ordinate:"]]
	$modelInst GrabClicks $this
	set useNodes(state) xcoord
	# need to allow modeller to click on 3-element array at this point so
	# only a single ListToArray needed, as this appears to be bottleneck
    }

    public method Click {path} {
        set node [GetIdFromCaptionPath $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
	set ms [winfo parent $winId].bottom.ms
	set bn [winfo parent $winId].bottom.bn

        if {[GetModelEval $node] eq "INPUT"} {
            switch $useNodes(state) {
		xcoord {
		    $ms configure -text "Now click on the input parameter to set to the Y co-ordinate:"
		    set temp(xcoord) $node
		    set useNodes(state) ycoord
		} ycoord {
		    $ms configure -text "Now select an input parameter to set when clicked:"
		    set temp(ycoord) $node
		    set useNodes(state) valset
		} valset {
		    set temp(tgt) $node
		    set useNodes(title) "Pointer input to [file tail $path]"
		    set useNodes(state) displaying
	            destroy $ms
		    destroy $bn
		    $modelInst ReleaseClicks

		    AddBindings 
		}
	    }
	} else {
            $ms configure -text \
		"This component must be an input parameter with a single (scalar) value."
	    # make it so
        }
    }

    public method AddBindings {} {
	bind $winId <Button-1> [namespace code [list $this SetPosn %x %y 1]]
	bind $winId <B1-Motion> [namespace code [list $this SetPosn %x %y 0]]
	bind $winId <ButtonRelease-1> [namespace code [list $this SetPosn %x %y -1]]
    }

    public method SetPosn {x y action} {
	set temp(act) [list $x $y $action]
	if {$action} {
	    SendPosn $x $y $action
	    RedoRatesAndDisplay [GetNode]
	}
    }


    public method SendPosn {x y action} {
	set myNode [GetNode]
	set InC [RunningInC $myNode]
	set col [expr {1+([$winId canvasx $x]/$transform(xzoom)-$useNodes(xoff))/$useNodes(xscale)}]
        set row [expr {1+(-[$winId canvasy $y]/$transform(yzoom)-$useNodes(yoff))/$useNodes(yscale)}]
	ListToArray $myNode {} $temp(xcoord) {} {} {} {} $col 0 $InC
	ListToArray $myNode {} $temp(ycoord) {} {} {} {} $row 0 $InC
	if {$action==-1} {
	    set temp(count) $action
	}
	ListToArray $myNode {} $temp(tgt) {} {} {} {} [incr temp(count)] 0 $InC
    }

    public method GetTitle {} {
	return $useNodes(title)
    }

    public method Display {time dispInt step} {
	#puts "state $useNodes(state) old $useNodes(oldAct) new $useNodes(act)"
# nothing to do at display time -- it's an input field
	if {$useNodes(state) eq "displaying"} {
	    if {$temp(count)} {
		eval SendPosn $temp(act)
	    }
	}
    }

    public method PrepareSaveString {} {
	    foreach comp {xcoord ycoord tgt} {
		set useNodes($comp) [GetCaptionPathFromId $temp($comp)]
	    }
	set State [array get useNodes]
    }

    public method AdjRange {rg} {
	set useNodes(transform) [list [$rg.exo get]  [$rg.eyo get] \
				     [$rg.exs get]  [$rg.eys get]]
	Display 0 0 0
    }

    public method Settings {} {
	set dlg [PutItThere .inpprop [winfo toplevel $winId]]
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
		  -command "set inpProps(xdone) 1"] -side right
	LetItShow $dlg inpProps(xdone)
	PackItUp $dlg
    }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
    }

}
