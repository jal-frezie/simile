# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Animals20131029
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable useNodes
    variable transform

    proc Identify {} {
	return "Moving individuals"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	array set transform [list xzoom $xzoom yzoom $yzoom]
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

    public method AddVariable {} {
	set cnvFile [ChooseFile animal.cnv "Image for individuals:" 0 \
			       [GetNode]]
	set useNodes(title) [file rootname [file tail $cnvFile]]s
	set stm [open $cnvFile r]
	set useNodes(cmds) [read $stm]
	close $stm
	set useNodes(ms) [$winId create text 0 0 -anchor nw -text \
				     [tr. "Click on the array value \
                    representing the X coordinates of the individuals."]]
	$modelInst GrabClicks $this
	set useNodes(state) xcoord
    }

    public method Click {path} {
        set testResult [$modelInst GetValue $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
        if {[string compare $testResult novalue]} {
            switch $useNodes(state) {
		xcoord {
		    $winId itemconfigure $useNodes(ms) -text "Now click on the value representing the Y coordinates."
		    set useNodes(xcoord) $path
		    set useNodes(state) ycoord
		} ycoord {
		    $winId itemconfigure $useNodes(ms) -text "Now select a value to determine the size of the animals."
		    set useNodes(ycoord) $path
		    set useNodes(state) sizeval
		} sizeval {
		    $winId itemconfigure $useNodes(ms) -text "Now select a value to determine their direction of movement."
		    set useNodes(size) $path
		    set useNodes(title) "[file tail $path] (moving $useNodes(title))"
		    set useNodes(state) dirval
		} dirval {
		    $winId delete $useNodes(ms)
		    $modelInst ReleaseClicks
		    set useNodes(dir) $path
		    set useNodes(state) displaying
		    unset useNodes(ms)
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

    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
	if {$useNodes(state) eq "displaying"} {
	    $winId delete [namespace tail $this].main
	    DoForRXYData {} DrawAnimal \
		[lindex [$modelInst GetValue $useNodes(size)] 0] \
		[lindex [$modelInst GetValue $useNodes(dir)] 0] \
		[lindex [$modelInst GetValue $useNodes(xcoord)] 0] \
		[lindex [$modelInst GetValue $useNodes(ycoord)] 0]
	    $winId dtag all positioned
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

    public method DrawAnimal {inds key dir xposn yposn} {
	set c $winId
	eval $useNodes(cmds)
	foreach {hotx hoty} $hotspot {} ;# sets them

	set compx [expr sin($dir)]
	set compy [expr cos($dir)]
	foreach newItem [$winId find withtag unpositioned] {
	    set newCoords {}
	    foreach {x y} [$winId coords $newItem] {
		set absx [expr $x-$hotx]
		set absy [expr $y-$hoty]
		lappend newCoords [expr {$transform(xzoom)*((-$compx*$absx-$compy*$absy)*$key+$xposn)}] [expr {-$transform(yzoom)*(($compy*$absx-$compx*$absy)*$key+$yposn)}] 
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
	$winId dtag all unpositioned
    }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
    }

    public method IdToTag {ids} {
	set result {}
	foreach id $ids {
	    lappend result [format %06d $id]
	}
	return [namespace tail $this]BLK[join $result ,]
    }

    public method TagToId {tags} {
	set myTag [namespace tail $this]BLK
	set end [expr [string first $myTag $tags]+[string length $myTag]]
	set idTag [lindex [string range $tags $end end] 0]
	foreach val [split $idTag ,] {
	    scan $val %06d index
	    lappend result $index
	}
	return [join $result ,]
    }
}
