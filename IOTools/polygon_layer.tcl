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
	set useNodes($winId,stipple) none
	set useNodes($winId,resetDone) 1 ;# always do one update
	if {[string length $state]} { ;# we are restoring 
	    regsub -all /WIN/ $state $winId restoreString
	    array set useNodes $restoreString
	    incr useNodes($winId,nswatches)
	    if {$useNodes($winId,state) eq "displaying"} {
		ReTile
		return
	    }
	} else {
	    set useNodes($winId,title) [Identify]
	    set useNodes($winId,editMode) 0
	    set useNodes($winId,legendSide) n
	    set useNodes($winId,imgs) 0
	    set useNodes($winId,displayRetile) 0
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
	
	set vx [$winId canvasx 0]
	set vy [$winId canvasy 0]
	label $winId.ms -bg white -text \
	    [tr. "Click on a value to determine the colour of the polygons."]
	$winId create window $vx $vy -window $winId.ms -anchor nw \
	    -tag instruct
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
		    $winId.ms configure -text "Now select the array value \
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
		    $winId.ms configure -text "Now click on the value representing the Y coordinatesl."
		    set useNodes($winId,xcoord) $path
		    set useNodes($winId,state) ycoord
		} ycoord {
		    set useNodes($winId,ycoord) $path
		    set useNodes($winId,state) sizeval
		    FinishClicking
		}
	    }
	} else {
            $winId.ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
        }
    }
   
    method FinishClicking {} {
	$winId delete instruct
	destroy $winId.ms
	$modelInst ReleaseClicks
	SetColourMap useNodes $winId \
	    [GetIdFromCaptionPath $useNodes($winId,color)]
	SetColours useNodes $winId
	set useNodes($winId,state) displaying
	ReTile
    }

    public method GetTitle {} {
	return $useNodes($winId,title)
    }
#
#    method SeekValue {inds vals} {
#	if {$inds eq ""} {
#	    return $vals
#	} else {
#	    array set indexed $vals
#	    return [SeekValue [lrange $inds 1 end] $indexed([lindex $inds 0])]
#	}
#    }
	    
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
	    [$modelInst GetValue $useNodes($winId,color) -numeric 1]
	if {$useNodes($winId,xcoord) eq "HEX_CTRS"} {
	    DoForData {} AddPolygon $useNodes(temp,curValues)
	} else {
	    DoForXYData {} AddPolygon $useNodes(temp,curValues) \
		[$modelInst GetValue $useNodes($winId,ycoord)] \
		[$modelInst GetValue $useNodes($winId,xcoord)]
	}
	$winId bind $myTag <Enter> "QueuePopup AddWidgetPopup %W %X %Y \
					\[$this CurrentPopup\]"
	$winId bind $myTag <Leave> RemovePopup
	$this Restipple
    }

    method SeekValue {idList data} {
	if {![llength $idList]} {
	    return $data
	} else {
	    foreach {ind subData} $data {
		if {$ind eq [lindex $idList 0]} {
		    return [SeekValue [lrange $idList 1 end] $subData]
		}
	    }
	    return nil
	}
    }

    public method Reset {} {
	# want to update display even if updates over time disabled
	set useNodes($winId,resetDone) 1
    }
	    
    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
	if {[string equal displaying $useNodes($winId,state)] && \
		($useNodes($winId,displayUpdate) || $useNodes($winId,resetDone))} {
	    set useNodes(temp,curValues) \
		[$modelInst GetValue $useNodes($winId,color) -numeric 1]
	    if {$useNodes($winId,displayRetile)} {
		ReTile
		return
	    }
#	    DoForData {} ColourPolygon $useNodes(temp,curValues)
	    # very slow because needs to search for every polygon by tag
	    foreach tgt [$winId find withtag [namespace tail $this].main] {
		set key [SeekValue [split [TagToId [$winId gettags $tgt]] ,] \
			     $useNodes(temp,curValues)]
		$winId itemconfigure $tgt -fill [ColourFor $winId $key]
	    }
	}
	$winId raise [namespace tail $this].main
	set useNodes($winId,resetDone) 0
    }

    method Flatten2D {tree} {
	if {[llength $tree]==1} {
	    return $tree
	} else {
	    foreach {ind subtree} $tree {
		eval {lappend vine} [Flatten2D $subtree] ;# fastest?
	    }
	    return $vine
	}
    }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
    }

    public method PrepareSaveString {} {
	incr useNodes($winId,nswatches) -1
	regsub -all $winId [array get useNodes $winId,*] /WIN/ State
	incr useNodes($winId,nswatches)
    }

    public method EditKey {parent} {
	set subDlg [PutItThere .colourkey $parent]
	wm title $subDlg [tr. "Colour key editor"]
	set flc 0
	while {[info exists useNodes($winId,c$flc)]} {
	    lappend map $useNodes($winId,c$flc)
	    incr flc
	}
	if {[info exists map]} {
	    ::EditLegend::ReverseEngineerFlags $map
	} else {
	    set ::EditLegend::flags {{0 black} {16 red} {31 white}}
	}
	set ::EditLegend::nswatches \
	    [expr {[lindex $::EditLegend::flags end 0]+1}]
	::EditLegend::Initialize $subDlg
	LetItShow $subDlg
	grab $subDlg
	tkwait variable ::EditLegend::done
	grab release $subDlg

	if {$::EditLegend::done} {
	    # OK button was clicked -- import results
	    set map [::EditLegend::MakeColours]
	    set useNodes($winId,nswatches) [llength $map]
	    for {set prog 0} {$prog<$useNodes($winId,nswatches)} {incr prog} {
		set useNodes($winId,c$prog) [lindex $map $prog]
	    }
	    array unset useNodes $winId,c$prog ;# leave gap to stop loading
	    Display 0 0 0	    
	}
	PackItUp $subDlg
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
	pack [button $coloursF.change -text "Edit colour key" \
		  -command [namespace code [list $this EditKey $dlg]]]
#	foreach {ptName ptId} {Low bot Middle mid High top} {
#	    pack [ttk::labelframe $coloursF.${ptId}colourF \
#		      -text "$ptName  colour"] -fill x -padx 10
#	    frame $coloursF.${ptId}colourF.colF -width 20 -height 15 \
#		-bg $useNodes($winId,c${ptId})
#	    pack [button $coloursF.${ptId}colourF.cbutton -text "..." \
#		      -command [list $this Recolour $ptId \
#				    $coloursF.${ptId}colourF.colF]] -side right
#	    pack $coloursF.${ptId}colourF.colF -side right -padx 10
#        }
        pack $coloursF -padx 10 -pady 10 -fill x
        
        set stippleF [labelframe $dlg.stipple -text "Stipple pattern"]
	pack [ttk::combobox $dlg.stipple.cbox \
		  -values {none gray75 gray50 gray25 gray12} \
		  -textvar [itcl::scope useNodes($winId,stipple)]] 
	bind $dlg.stipple.cbox <<ComboboxSelected>> [list $this Restipple]
        pack $stippleF -padx 10 -pady 10 -fill x
        
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
        pack $rangeF -padx 10 -pady 10
        pack [checkbutton $dlg.retile -text "Re-tile at display intervals" \
		  -variable [itcl::scope useNodes($winId,displayRetile)]]
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
	pack [frame $dlg.btns] -fill x
	pack [ttk::button $dlg.btns.apply -text [tr. Apply] \
		  -command [list $this AdjRange $rangeF]] -side left
        pack [ttk::button $dlg.btns.done -text [tr. Done] \
		  -command "set polyProps(xdone) 1"] -side right
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
#	SetColours useNodes $winId
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
	set tgt [$winId find withtag [IdToTag $inds]] ;# faster? er, no
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
	if {[llength $yverts] == 1 || [llength $xverts] == 1} {
	    Query vertices_not_array warning helpers $winId ok
	    return 0
	}
	foreach {yind yval} $yverts {xind xval} $xverts {
	    if {$xval == {} || $yval == {} || $xind != $yind} {
		Query "vertices_unmatched $id] warning helpers $winId ok"
		return 0
	    }
	    lappend outlist \
		[expr $transform(xzoom)*$xval] [expr -$transform(yzoom)*$yval]
	}
	set newColour [ColourFor $winId $key]
	if {$useNodes($winId,bw)} {
	    set newBord $useNodes($winId,cbord)
	} else {
	    set newBord {}
	}
	$winId create polygon $outlist -outline $newBord \
	    -width $useNodes($winId,bw) -fill $newColour \
	    -tag [list [namespace tail $this].main [IdToTag $inds]]
    }

      public method ColourFor {winId value} {
	  if {$value eq "nil"} {
	      set newColour {}
        } else {
	    set clipVal [expr {max($useNodes($winId,min),
				   min($useNodes($winId,max),$value))}]
	    set colNum [expr int(($clipVal-$useNodes($winId,min))* \
				     ($useNodes($winId,nswatches)-1) / \
				     $useNodes($winId,range))]
            set newColour $useNodes($winId,c$colNum)
        }
#puts "Colour for $value is $colNum (range $useNodes($winId,range))"
    }
    
    method Restipple {} {
	if {$useNodes($winId,stipple) eq "none"} {
	    $winId itemconfig [namespace tail $this].main -stipple {}
	} else {
	    $winId itemconfig [namespace tail $this].main \
		-stipple $useNodes($winId,stipple)
	}
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
