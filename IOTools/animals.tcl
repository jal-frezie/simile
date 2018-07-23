# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Animals20131029
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable useNodes
    variable transform
    variable temp

    proc Identify {} {
	return "Moving individuals"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	array set transform [list xzoom $xzoom yzoom $yzoom]
	set useNodes(transform) {0 0 1 1}
	$winId bind [namespace tail $this].main <Enter> \
	    "QueuePopup AddWidgetPopup %W %X %Y \[$this CurrentPopup\]"
	$winId bind [namespace tail $this].main <Leave> RemovePopup
	if {[string length $state]} { ;# we are restoring 
	    array set useNodes $state
	    if {$useNodes(state) eq "displaying"} {
		Display 0 0 0
		return
	    }
	} else {
	}
	AddVariable
    }

    destructor {
	$winId delete [namespace tail $this].main
    }

    method CurrentPopup {} {
	set ind [TagToId [$winId gettags current]]
	return "Index: [join $ind ,] x: [SeekValue $ind $temp(xcoord)] y: [SeekValue $ind $temp(ycoord)] Size: [SeekValue $ind $temp(size)] Heading: [SeekValue $ind $temp(dir)]"
    }

    method SeekValue {inds vals} {
	if {$inds eq ""} {
	    return $vals
	} else {
	    array set indexed $vals
	    return [SeekValue [lrange $inds 1 end] $indexed([lindex $inds 0])]
	}
    }
	    
    public method AddVariable {} {
	set cnvFile [ChooseFile animal.cnv "Image for individuals:" 0 [GetNode]]
	set useNodes(title) [file rootname [file tail $cnvFile]]s
	set stm [open $cnvFile r]
	set useNodes(cmds) [subst -novariables [regsub -line -all {^\$c create .*$} [read $stm] {& -tag unpositioned}]]
# subst allows eg tk_chooseColor to be done just once
	close $stm
# now adjust each command to tag the item

	set vx [$winId canvasx 0]
	set vy [$winId canvasy 0]
	set ms [winfo parent $winId].bottom.ms
	pack [ttk::label $ms -wraplength [$winId cget -width] -text \
		  [tr. "Click on the value representing the X coordinates of the individuals."]]
	$modelInst GrabClicks $this
	set useNodes(state) xcoord
    }

    public method Click {{path {}}} {
        set testResult [$modelInst GetValue $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
	set ms [winfo parent $winId].bottom.ms
	set bn [winfo parent $winId].bottom.bn
	if {$path eq ""} {
	    set path [$bn get]
	}
        if {[string compare $testResult novalue]} {
            switch $useNodes(state) {
		xcoord {
		    $ms configure -text "Now click on the value representing the Y coordinates."
		    set useNodes(xcoord) $path
		    set useNodes(state) ycoord
		} ycoord {
		    $ms configure -text "Now select a component whose value determines the size of the animals, or enter fixed value here:"
		    pack [ttk::entry $bn] -side bottom
		    bind $bn <Return> [list $this Click]
		    set useNodes(ycoord) $path
		    set useNodes(state) sizeval
		} sizeval {
		    $ms configure -text "Now select a component whose value determines their orientation, or enter fixed value here:"
		    $bn delete 0 end
		    set useNodes(size) $path
		    set useNodes(title) "[file tail $path] (moving $useNodes(title))"
		    set useNodes(state) dirval
		} dirval {
	            destroy $ms
		    destroy $bn
		    $modelInst ReleaseClicks
		    set useNodes(dir) $path
		    set useNodes(state) displaying
		    Display 0 0 0
		}
	    }
	} else {
            $ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
        }
    }
   
    public method GetTitle {} {
	return $useNodes(title)
    }

    proc ReplicateAsX {replicand x} {
	if {[llength $x]==1} {
	    return $replicand
	} else {
	    foreach {i subx} $x {
		lappend result $i [ReplicateAsX $replicand $subx]
	    }
	    return $result
	}
    }

    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
	if {$useNodes(state) eq "displaying"} {
	    $winId delete [namespace tail $this].main
	    foreach aspect {xcoord ycoord size dir} {
		if {[string first / $useNodes($aspect)]} {
		    set temp($aspect) [ReplicateAsX $useNodes($aspect) \
					   $temp(xcoord)]
		} else {
		    set temp($aspect) [$modelInst GetValue $useNodes($aspect)]
		}
	    }
	    DoForRXYData {} DrawAnimal $temp(size) $temp(dir) \
		$temp(xcoord) $temp(ycoord)
	}
    }

    public method PrepareSaveString {} {
	set State [array get useNodes]
    }

    public method DoForRXYData {inds proc size dir argx argy} {
	if {[llength $size]==1} {
	    $proc $inds $size $dir $argx $argy
	} else {
	    foreach {ind val} $size {spare0 r} $dir \
		{spare1 x} $argx {spare2 y} $argy {
		DoForRXYData [concat $inds $ind] $proc $val $r $x $y
	    }
	}
    }

    public method ToRadians {axis} {
        if {[string is double -strict $axis]} {
            return $axis
        } elseif {[set ct [lsearch {e ne n nw w sw s se} \
                                   [lindex $axis 0]]]>-1} {
            return [expr {$ct*6.283/8}]
        } elseif {[set ct [lsearch {3h 2h 1h 12h 11h 10h 9h 8h 7h 6h 5h 4h} \
                                   [lindex $axis 0]]]>-1} {
            return [expr {$ct*6.283/12}]
        } else {
            error "Unrecognized axis $axis"
        }
    }

    public method AdjRange {rg} {
	set useNodes(transform) [list [$rg.exo get]  [$rg.eyo get] \
				     [$rg.exs get]  [$rg.eys get]]
	Display 0 0 0
    }

    public method DrawAnimal {inds key dir xposn yposn} {
	set c $winId
	eval $useNodes(cmds)
	foreach {hotx hoty} $hotspot {} ;# sets them
        set dir [expr {[ToRadians $dir]-[ToRadians $axis]}]
	set compx [expr cos($dir)]
	set compy [expr sin($dir)]
	foreach newItem [$winId find withtag unpositioned] {
	    set oldCoords {}
	    set newCoords {}
            set type [$winId type $newItem]
	    foreach {x y} [$winId coords $newItem] {
		set absx [expr ($x-$hotx)/$scale]
		set absy [expr ($y-$hoty)/$scale]
		lappend oldCoords $absx $absy
		lappend newCoords [expr {$transform(xzoom)*((($compx*$absx+$compy*$absy)*$key+$xposn)*[lindex $useNodes(transform) 2]+[lindex $useNodes(transform) 0])}] \
		    [expr {-$transform(yzoom)*((($compy*$absx-$compx*$absy)*$key+$yposn)*[lindex $useNodes(transform) 3]+[lindex $useNodes(transform) 1])}] 
	    }
            if {[lsearch {arc oval} $type] > -1} {
                if {$type eq "arc"} {
                    $winId itemconfig $newItem -start [expr {[$winId itemcget $newItem -start]+$dir*360/6.283}]
                }
                foreach {l t r b} $oldCoords {}
                set hypo [expr {($b-$t)**2+($r-$l)**2}]
                set aspect [expr {($b-$t)**2/$hypo}]
                foreach {l t r b} $newCoords {}
                set cx [expr {($l+$r)/2}]
                set cy [expr {($t+$b)/2}]
                set hypo [expr {($b-$t)**2+($r-$l)**2}]
                set xtent [expr {sqrt((1-$aspect)*$hypo)/2}]
                set ytent [expr {sqrt($aspect*$hypo)/2}]
                set newCoords [list [expr {$cx-$xtent}] [expr {$cy-$ytent}] \
		   [expr {$cx+$xtent}] [expr {$cy+$ytent}]]
	    }
	    $winId coords $newItem $newCoords
	}
# simple version with no rotation about 2x as fast
#	set xscale [expr {$key*$transform(xzoom)}]
#	set xbase [expr {($xposn-$key*$hotx)*$transform(xzoom)/(1-$xscale)}]
#	set yscale [expr {$key*$transform(yzoom)}]
#	set ybase [expr {($yposn-$key*$hoty)*$transform(yzoom)/(1-$yscale)}]
#	$winId scale unpositioned $xbase $ybase $xscale $yscale
# also try keeping data and moving individuals?
	$winId addtag [namespace tail $this].main withtag unpositioned
	$winId addtag [IdToTag $inds] withtag unpositioned
	$winId dtag unpositioned
    }

    public method Settings {} {
	set dlg [PutItThere .polyprop [winfo toplevel $winId]]
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

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
    }

    public method IdToTag {ids} {
	set result {}
	foreach id $ids {
	    if {[string is integer -strict $id]} {
		lappend result [format %06d $id]
	    } else { ;# is an enum type member
		lappend result $id
	    }
	}
	return [namespace tail $this]BLK[join $result ,]
    }

    public method TagToId {tags} {
	set myTag [namespace tail $this]BLK
	set end [expr [string first $myTag $tags]+[string length $myTag]]
	set idTag [lindex [string range $tags $end end] 0]
	foreach val [split $idTag ,] {
	    if {![scan $val %06d index]} {
		set index $val
	    }
	    lappend result $index
	}
	return $result
    }
}
