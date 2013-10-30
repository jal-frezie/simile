# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Polygon20131026
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable useNodes

    proc Identify {} {
	return "Polygon map"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	namespace import -force ::maptools2::*
	if {[string length $state]} { ;# we are restoring 
	    regsub -all /WIN/ $state $winId restoreString
	    array set useNodes $restoreString
	    if {$useNodes($winId,state) eq "displaying"} {
		ReTile
		return
	    }
	} else {
	    set useNodes($winId,title) [Identify]
	    set useNodes($winId,editMode) 0
	    set useNodes($winId,orient) h
	    set useNodes($winId,imgs) 0
	    set useNodes($winId,displayUpdate) 1
	    
	    set useNodes($winId,min) 0
	    set useNodes($winId,max) 100
	    set useNodes($winId,datamin) 1e100
	    set useNodes($winId,datamax) 1e-100
	    set useNodes($winId,bw) {}
	    
	    set useNodes($winId,cbot) black
	    set useNodes($winId,cmid) green
	    set useNodes($winId,ctop) white
	    set useNodes($winId,cbord) black
	    
	    set useNodes($winId,scalex) 1.0
	    set useNodes($winId,scaley) 1.0
	}
	AddVariable
    }

    destructor {
	$winId delete [namespace tail $this].main
    }

    public method AddVariable {} {
	set useNodes($winId,ms) [$winId create text 0 0 -anchor nw -text \
				     [tr. "Click on the array value \
                    representing the X coordinates of the polygon vertices."]]
	$modelInst GrabClicks $this
	set useNodes($winId,state) xcoord
    }

    public method Click {path} {
        set testResult [$modelInst GetValue $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
        if {[string compare $testResult novalue]} {
            switch $useNodes($winId,state) {
		xcoord {
		    $winId itemconfigure $useNodes($winId,ms) -text "Now click on the value representing the Y coordinates."
		    set useNodes($winId,xcoord) $path
		    set useNodes($winId,state) ycoord
		} ycoord {
		    $winId itemconfigure $useNodes($winId,ms) -text "Now select a value to determine the colour of the polygons."
		    set useNodes($winId,ycoord) $path
		    set useNodes($winId,state) sizeval
		}
		sizeval {
		    $winId delete $useNodes($winId,ms)
		    $modelInst ReleaseClicks
		    set useNodes($winId,color) $path
		    set useNodes($winId,title) "[file tail $path] (polygon diagram)"
		    SetColourMap useNodes $winId [GetIdFromCaptionPath $path]
		    SetColours useNodes $winId
		    set useNodes($winId,state) displaying
		    unset useNodes($winId,ms)
		    ReTile
		}
	    }
	} else {
            $ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
        }
    }
   
    public method GetTitle {} {
	return $useNodes($winId,title)
    }

    public method ReTile {} {
	$winId delete [namespace tail $this].main
	DoForXYData {} AddPolygon \
	    [lindex [$modelInst GetValue $useNodes($winId,color)] 0] \
	    [lindex [$modelInst GetValue $useNodes($winId,xcoord)] 0] \
	    [lindex [$modelInst GetValue $useNodes($winId,ycoord)] 0]
    }

    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
	if {[string equal displaying $useNodes($winId,state)] && \
		$useNodes($winId,displayUpdate)} {
	    DoForData {} ColourPolygon \
		[lindex [$modelInst GetValue $useNodes($winId,color)] 0]
	}
    }

    public method PrepareSaveString {} {
	regsub -all $winId [array get useNodes $winId,*] /WIN/ State
    }

    public method Settings {} {
        set ${winId}l5 $useNodes($winId,displayUpdate)
	set dlg [PutItThere .polyprop [winfo toplevel $winId]]
	wm title $dlg [tr. "Polygon display properties"]
	wm protocol $dlg WM_DELETE_WINDOW "set polyProps(xdone) 0"
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
        set coloursF [labelframe $dlg.colours -text "Colour scale"]
	foreach {ptName ptId} {Low bot Middle mid High top} {
	    pack [ttk::labelframe $coloursF.${ptId}colourF \
		      -text "$ptName  colour"] -fill x -padx 10
	    frame $coloursF.${ptId}colourF.colF -width 20 -height 15 \
		-bg $useNodes($winId,c${ptId})
	    pack [button $coloursF.${ptId}colourF.cbutton -text "..." \
		      -command [list $this Recolour $ptId \
				    $coloursF.${ptId}colourF.colF]] -side right
	    pack $coloursF.${ptId}colourF.colF -side right -padx 10
        }
        pack $coloursF -padx 10 -pady 10 -fill x
        
        set borderF [labelframe $dlg.border -text "Borders"]
        pack [ttk::labelframe $borderF.widF -text "Width"] -fill x  -padx 10 -pady 5
        pack [entry $borderF.widF.entry -textvar [itcl::scope useNodes($winId,bw)] -width 20] -side left -padx 10
        pack [ttk::labelframe $borderF.colourF -text "Colour"] -fill x -padx 10
        frame $borderF.colourF.colF -width 20 -height 15 -bg $useNodes($winId,cbord)
        pack [button $borderF.colourF.cbutton -text "..." \
		  -command [list $this Recolour bord $borderF.colourF.colF]] -side right
        pack $borderF.colourF.colF -side right -padx 10
        pack $borderF -padx 10 -pady 10
        
        set rangeF [labelframe $dlg.range -text "Scale range"]
        pack [label $rangeF.dataminL -text "Data min. so far: $useNodes($winId,datamin)"] -fill x  -padx 10
        pack [label $rangeF.datamaxL -text "Data max. so far: $useNodes($winId,datamax)"] -fill x  -padx 10
        pack [ttk::labelframe $rangeF.minF -text "Min"] -fill x  -padx 10 -pady 5
        pack [ttk::entry $rangeF.minF.entry -width 20] -side right -padx 10
	$rangeF.minF.entry insert 0 $useNodes($winId,min)
        pack [ttk::labelframe $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [ttk::entry $rangeF.maxF.entry -width 20] -side right -padx 10
	$rangeF.maxF.entry insert 0 $useNodes($winId,max)
	pack [ttk::button $rangeF.apply -text [tr. Apply] \
		  -command [list $this AdjRange $rangeF]]
        pack $rangeF -padx 10 -pady 10
        pack [checkbutton $dlg.update -variable ${winId}l5 \
		  -text "Update at display intervals"]
        
        set oriF [labelframe $dlg.orient -text "Orientation"]
	pack [radiobutton $oriF.h -text Horizontal -var [itcl::scope useNodes($winId,orient)] -value h] -side left
	pack [radiobutton $oriF.v -text Vertical -var [itcl::scope useNodes($winId,orient)] -value v] -side right
        pack $oriF -padx 10 -pady 10 -fill x
        
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
	set useNodes($winId,displayUpdate) [set ${winId}l5]
    }
    
    public method AdjRange {rangeF} {
	set min [$rangeF.minF.entry get]
	set max [$rangeF.maxF.entry get]

	if {![IsNumber $min]} {
            $rangeF.minF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
	}
	if {![IsNumber $max]} {
            $rangeF.maxF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
	}
        set useNodes($winId,min) $min
        set useNodes($winId,max) $max
        set useNodes($winId,range) [expr {$max-$min}]
	SetColours useNodes $winId
	Display 0 0 0
    }

    public method Recolour {whichCol exampleWidget} {
	set col [tk_chooseColor -parent .polyprop \
		     -initialcolor $useNodes($winId,c$whichCol)]
	if {![string length $col]} return
        set useNodes($winId,c$whichCol) $col
	$exampleWidget configure -bg $useNodes($winId,c$whichCol)
	if {[string equal bord $whichCol]} {
	    if {$useNodes($winId,bw)<=0} {
		set useNodes($winId,cbord) {}
	    }
	    ReTile
	} else {
	    SetColours useNodes $winId
#	    recolour_scale [namespace current] $winId
	}
	Display 0 0 0
    }

    public method DoForData {inds proc key} {
	if {[llength $key]==1} {
	    $proc $inds $key
	} else {
	    foreach {ind val} $key {
		DoForData [concat $inds $ind] $proc $val
	    }
	}
    }

    public method ColourPolygon {inds key} {
	if {$key<$useNodes($winId,datamin)} {
	    set useNodes($winId,datamin) $key
	}
	if {$key>$useNodes($winId,datamax)} {
	    set useNodes($winId,datamax) $key
	}

	set newColour [ColourFor $winId $key]
	$winId itemconfigure [IdToTag $inds] -fill $newColour
    }

    public method DoForXYData {inds proc key argx argy} {
	if {[llength $key]==1} {
	    $proc $inds $key $argx $argy
	} else {
	    foreach {ind val} $key {spare1 x} $argx {spare2 y} $argy {
		DoForXYData [concat $inds $ind] $proc $val $x $y
	    }
	}
    }

    public method AddPolygon {inds key xverts yverts} {
	foreach {xind xval} $xverts {yind yval} $yverts {
	    lappend outlist $xval $yval
	}
	set newColour [ColourFor $winId $key]
	$winId create polygon $outlist -outline $useNodes($winId,cbord) \
	    -width $useNodes($winId,bw) -fill $newColour \
	    -tag [list [namespace tail $this].main [IdToTag $inds]]
    }

     public method ColourFor {winId value} {
        variable useNodes
        if {[string match nil $value]} {
            set newColour gray
        } elseif {$value<=$useNodes($winId,min)} {
	    set newColour $useNodes($winId,c0)
        } elseif {$value>=$useNodes($winId,max)} {
	    set newColour $useNodes($winId,c$useNodes($winId,nswatches))
	} else {
	    set colNum [expr int(($value-$useNodes($winId,min))* \
				     $useNodes($winId,nswatches) / \
				     $useNodes($winId,range))]
            set newColour $useNodes($winId,c$colNum)
        }
#puts "Colour for $value is $colNum (range $useNodes($winId,range))"
    }
    
    public method IdToTag {ids} {
	set result {}
	foreach id $ids {
	    lappend result [format %06d $id]
	}
	return $[namespace tail $this]BLK[join $result ,]
    }

    public method TagToId {tags} {
	set myTag $[namespace tail $this]
	set end [expr [string first $myTag $tags]+[string length $myTag]]
	set idTag [lindex [string range $tags $end end] 0]
	foreach val [split $idTag ,] {
	    scan $val %06d index
	    lappend result $index
	}
	return [join $result ,]
    }
}
