# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Polygon20131026
itcl::class similescript::$newLayerClass {
    inherit Layer
    public variable useNodes
    variable transform

    proc Identify {} {
	return "Polygon map"
    }

    constructor {modelInst layerTool xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $layerTool
    } {
	namespace import -force ::maptools2::*
	array set transform [list xzoom $xzoom yzoom $yzoom]
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
	    set useNodes($winId,legendSide) n
	    set useNodes($winId,imgs) 0
	    set useNodes($winId,displayUpdate) 1
	    
	    set useNodes($winId,min) 0
	    set useNodes($winId,max) 100
	    set useNodes($winId,datamin) 1e100
	    set useNodes($winId,datamax) 1e-100
	    set useNodes($winId,bw) 1
	    
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
	$winId delete [namespace tail $this].legend
    }

    public method GetCanvas {} {
	return $winId
    }

    public method AddVariable {} {
	set useNodes($winId,ms) [$winId create text 0 0 -anchor nw -text \
				     [tr. "Click on a value to determine the colour of the polygons."]]
	$modelInst GrabClicks $this
	set useNodes($winId,state) sizeval
    }

    public method Click {path} {
        set testResult [$modelInst GetValue $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
        if {[string compare $testResult novalue]} {
            switch $useNodes($winId,state) {
		sizeval {
		    $winId itemconfigure $useNodes($winId,ms) -text "Now select the array value \
                    representing the X coordinates of the polygon vertices."
		    set useNodes($winId,color) $path
		    set useNodes($winId,title) "[file tail $path] (polygon diagram)"
		    set parentPath [join [lrange [split $path /] 0 end-1] /]
		    if {[$modelInst GetModelEval $parentPath] eq "HONEYCOMB"} {
			set useNodes($winId,xcoord) HEX_CTRS
			FinishClicking
		    } else {
			set useNodes($winId,state) xcoord
		    }
		}
		xcoord {
		    $winId itemconfigure $useNodes($winId,ms) -text "Now click on the value representing the Y coordinates."
		    set useNodes($winId,xcoord) $path
		    set useNodes($winId,state) ycoord
		} ycoord {
		    set useNodes($winId,ycoord) $path
		    set useNodes($winId,state) sizeval
		    FinishClicking
		}
	    }
	} else {
            $ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
        }
    }
   
    method FinishClicking {} {
	$winId delete $useNodes($winId,ms)
	$modelInst ReleaseClicks
	SetColourMap useNodes $winId \
	    [GetIdFromCaptionPath $useNodes($winId,color)]
	SetColours useNodes $winId
	set useNodes($winId,state) displaying
	unset useNodes($winId,ms)
	ReTile
    }

    public method GetTitle {} {
	return $useNodes($winId,title)
    }

    method SeekValue {inds vals} {
	if {$inds eq ""} {
	    return $vals
	} else {
	    return [SeekValue [lrange $inds 1 end] \
			[lindex $vals [lsearch $vals [lindex $inds 0]]+1]]
	}
    }
	    
    public method CurrentPopup {} {
	set indices [TagToId [$winId gettags current]]
	set value [TransValue $useNodes($winId,dataETs) \
		       [SeekValue [split $indices ,] $useNodes(temp,curValues)]]
	return "Index: $indices Value: $value"
    }

    public method ReTile {} {
	set myTag [namespace tail $this].main
	$winId delete $myTag
	set useNodes(temp,curValues) \
	    [lindex [$modelInst GetValue $useNodes($winId,color)] 0]
	if {$useNodes($winId,xcoord) eq "HEX_CTRS"} {
	    DoForData {} AddPolygon $useNodes(temp,curValues)
	} else {
	    DoForXYData {} AddPolygon $useNodes(temp,curValues) \
		[lindex [$modelInst GetValue $useNodes($winId,ycoord)] 0] \
		[lindex [$modelInst GetValue $useNodes($winId,xcoord)] 0]
	}
	$winId bind $myTag <Enter> "QueuePopup AddWidgetPopup %X %Y \
					\[$this CurrentPopup\]"
	$winId bind $myTag <Leave> RemovePopup
    }

    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
	if {[string equal displaying $useNodes($winId,state)] && \
		$useNodes($winId,displayUpdate)} {
	    set useNodes(temp,curValues) \
		[lindex [$modelInst GetValue $useNodes($winId,color)] 0]
	    DoForData {} ColourPolygon $useNodes(temp,curValues)
	}
	$winId raise [namespace tail $this].main
    }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
    }

    public method PrepareSaveString {} {
	regsub -all $winId [array get useNodes $winId,*] /WIN/ State
    }

    public method Settings {} {
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
        pack [checkbutton $dlg.update -text "Update at display intervals" \
		  -variable [itcl::scope useNodes($winId,displayUpdate)]]
        
        set oriF [labelframe $dlg.orient -text "Legend position:"]
	foreach legendPosn {l t r b n} desc {Left Top Right Bottom None} {
	    radiobutton $oriF.$legendPosn -text $desc -value $legendPosn \
		-var [itcl::scope useNodes($winId,legendSide)]
	}
	grid x $oriF.t
	grid $oriF.l $oriF.n $oriF.r
	grid x $oriF.b
        pack $oriF -padx 10 -pady 10 -fill x
        
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
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
	switch -regexp $useNodes($winId,legendSide) {
	    l|r {
		set useNodes($winId,orient) v
	    } t|b {
		set useNodes($winId,orient) h
	    }
	}
	# now a callback to layer manager to draw and posn it
	$host PosnLegends
    }

    public method GetSwatchColour {swId} {
	::maptools2::SetSwatchColour ::$this $winId $swId
    }

    public method GetNewLegendSide {} {
	if {$useNodes($winId,legendSide) ne "n"} {
	    recolour_scale ::$this $winId
	}
	return $useNodes($winId,legendSide)
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
	set tgt [$winId find withtag [IdToTag $inds]] ;# faster?
	$winId itemconfigure $tgt -fill $newColour
#	CanvasBindPopup $winId $tgt [list Index $inds Value \
#			 [TransValue $useNodes($winId,dataETs) $key]]
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

    method VerticesFromInds {row col} {
	set hex_centre_y [expr {1.5*$row}]
	set hex_centre_x [expr {1.7320508*($col+($row%2)/2.0)}]
	foreach yoff {1 0.5 -0.5 -1 -0.5 0.5} xoff {0 0.5 0.5 0 -0.5 -0.5} {
# indices not used, just added for compatibility with model data
	    lappend yval 0 [expr {$hex_centre_y+$yoff}]
	    lappend xval 0 [expr {$hex_centre_x+1.7320508*$xoff}]
	}
	return [list $yval $xval]
    }

    public method AddPolygon {inds key args} {
	if {$args eq {}} {
	    set args [eval VerticesFromInds $inds]
	}
	foreach {yverts xverts} $args {}
	foreach {yind yval} $yverts {xind xval} $xverts {
	    lappend outlist \
		[expr $transform(xzoom)*$xval] [expr -$transform(yzoom)*$yval]
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
	set myTag $[namespace tail $this]BLK
	set end [expr [string first $myTag $tags]+[string length $myTag]]
	set idTag [lindex [string range $tags $end end] 0]
	foreach val [split $idTag ,] {
	    scan $val %06d index
	    lappend result $index
	}
	return [join $result ,]
    }
}
