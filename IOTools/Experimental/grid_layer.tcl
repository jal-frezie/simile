# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass RectGrid20131119
itcl::class similescript::$newLayerClass {
    inherit Layer
    variable useNodes
    variable transform

    proc Identify {} {
	return "Grid map"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	namespace import -force ::maptools2::*
	array set transform [list xzoom $xzoom yzoom $yzoom]
	image create photo $this.original 
	if {[string length $state]} { ;# we are restoring 
	    foreach {att val} $state {
		set useNodes($winId,$att) $val
	    }
	    if {$useNodes($winId,state) eq "displaying"} {
		Display 0 0 0
		return
	    }
	} else {
	    set useNodes($winId,xoff) 0
	    set useNodes($winId,yoff) 0
	    set useNodes($winId,xscale) 1
	    set useNodes($winId,yscale) 1
	    set useNodes($winId,title) [Identify]
	    set useNodes($winId,editMode) 0
	    set useNodes($winId,orient) n
	    set useNodes($winId,imgs) 0
	    set useNodes($winId,displayUpdate) 1
	    
	    set useNodes($winId,min) 0
	    set useNodes($winId,max) 100
	    set useNodes($winId,datamin) 1e100
	    set useNodes($winId,datamax) 1e-100
	    set useNodes($winId,bw) 1
	    
	    set useNodes($winId,cbot) black
	    set useNodes($winId,cmid) red
	    set useNodes($winId,ctop) white
	}
	AddVariable
    }

    destructor {
	$winId delete [namespace tail $this].main
    }

    public method AddVariable {} {
	set useNodes($winId,ms) [$winId create text 0 0 -anchor nw -text \
				     [tr. "Click on the variable whose values are to be displayed on the grid."]]
	$modelInst GrabClicks $this
	set useNodes($winId,state) display0
    }

    public method Click {path} {
        set testResult [$modelInst GetValue $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
        if {[string compare $testResult novalue]} {
            switch $useNodes($winId,state) {
		display0 {
                    set useNodes($winId,color) $path
		    SetColourMap useNodes $winId [GetIdFromCaptionPath $path]
		    SetColours useNodes $winId
		    set useNodes($winId,tgtDims) [$modelInst GetModelDims $path]
		    if {[IsTwoDee $winId $useNodes($winId,tgtDims)]} {
			set useNodes($winId,colvals) USE_INDICES
			FinishClicking
		    } else {
			$winId itemconfigure $ useNodes($winId,ms)-text "Now click on a variable giving the column IDs."
			set useNodes($winId,state) display1
		    }
		} display1 {
                    NumDistinct $winId $path
		    set useNodes($winId,colvals) $node
		    FinishClicking
		}
	    }
	} else {
            $ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
        }
    }
   
    public method FinishClicking {} {
	$winId delete $useNodes($winId,ms)
	unset useNodes($winId,ms)
	$modelInst ReleaseClicks
	pack forget $winId.msg
	set useNodes($winId,state) displaying
	Display 0 0 0
    }

    public method GetTitle {} {
	return $useNodes($winId,title)
    }

    public method IsTwoDee {winId dimList} {
	variable useNodes
	
	foreach dim $dimList {
	    if {[string is integer -strict $dim]} {
		foreach space [list useNodes($winId,nrow) \
				   useNodes($winId,ncol) terminator] {
		    if {![info exists $space]} {
			set $space $dim
			break
		    }
		}
	    }
	}
	return [expr {[info exists terminator] && !$terminator}]
    }

    public method NumDistinct {winId testPath} {
	variable useNodes
        variable colvals

	if {![catch {$modelInst ListDistinctValues $testPath} vList]} {
	    set useNodes($winId,ncol) [llength [lrange $vList 1 end]]
	    set useNodes($winId,nrow) \
		[expr {[lindex $vList 0]/$useNodes($winId,ncol)}]
	} else {
	    DoForData {} CollectVals [lindex [$modelInst GetValue $testPath] 0]
	    if {[info exists colvals()]} {
		unset colvals()
	    }
	    set useNodes($winId,ncol) [array size colvals]
	    set useNodes($winId,nrow) \
		[expr {[llength $columns]/$useNodes($winId,ncol)}]
	}
    }

    public method CollectVals {val} {
	variable colvals

	array set colvals($val) 1
    }

    public method Display {time dispInt step} {
	if {[string equal displaying $useNodes($winId,state)] && \
		$useNodes($winId,displayUpdate)} {
            DrawGrid8
# will update visible part of canvas if whole scrollregion not displayed
	    ZoomTo $transform(xzoom) $transform(yzoom)
	    $winId raise [namespace tail $this].main
	}
    }

    public method DrawGrid8 {} {
# do not use image mode for inputs cos we will want to edit them...
# hah, just fixed it so we can anyway
	set node [GetIdFromCaptionPath $useNodes($winId,color)]
	if {[lsearch $useNodes($winId,tgtDims) START_VM]>-1 || \
		[catch {GetBinaryModelValue $node $useNodes($winId,min) \
			$useNodes($winId,max)} rawBinary]} {
	    DrawGrid7
	    return
	}
#puts "Binary is of size [string bytelength $rawBinary]"
	set rows $useNodes($winId,nrow)
	set cols $useNodes($winId,ncol)
	set bitCols [expr 4*int(($cols+3)/4)]
	set fullSize [expr 1078+$bitCols*$rows]
	set bmpData [binary format a2is2iiiissiiiiii \
		 BM $fullSize {0 0} 1078 40 $cols $rows 1 8 0 0 0 0 0 0]
	for {set rgbQuad 0} {$rgbQuad<256} {incr rgbQuad} {
	    set colourIndex [expr $rgbQuad*($useNodes($winId,nswatches)+1)/256]
	    set colourStr [Desystematize $useNodes($winId,c$colourIndex)]
	    append bmpData [binary format H2H2H2c \
				[string range $colourStr 9 12] \
				[string range $colourStr 5 8] \
				[string range $colourStr 1 4] 0]
	}
	set filling [string repeat 0 [expr $bitCols-$cols]]
	if {[string length $filling]} {
	    for {set row 0} {$row<$rows} {incr row} {
		append bmpData [string range $rawBinary \
		        [expr $row*$cols] [expr $row*$cols+$cols-1]] $filling
	    }
	} else {
	    append bmpData $rawBinary
	}
	$this.original configure -data $bmpData
	PutSize $this.original
   }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
	set stickIt [list [expr {$useNodes($winId,xoff)*$xzoom}] \
			 [expr {-$useNodes($winId,yoff)*$yzoom}]]
	set tmpImg [GrowImage $this.original \
	    [expr {round([$this.original cget -width]*$useNodes($winId,xscale)*$xzoom)}] \
	    [expr {round([$this.original cget -height]*$useNodes($winId,yscale)*$yzoom)}]]
	set myTag [namespace tail $this].main
	if {[catch {$this.derived blank}]} { ;# not yet exist
	    image create photo $this.derived
	    $winId create image $stickIt -anchor sw -image $this.derived \
						 -tag $myTag
	} else {
	    $winId coords [$winId find withtag $myTag] $stickIt
	}
	$this.derived copy $tmpImg -shrink
    }

    public method PrepareSaveString {} {
	regsub -all $winId, [array get useNodes] {} State
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
        
	set rg [labelframe $dlg.relgeom -text "Offset and scaling"]
	grid [label $rg.lxo -text [tr. {X offset:}]] \
	    [ttk::entry $rg.exo -width 8 \
		 -textvar [itcl::scope useNodes($winId,xoff)]] \
	    [label $rg.lyo -text [tr. {Y offset:}]] \
	    [ttk::entry $rg.eyo -width 8 \
		 -textvar [itcl::scope useNodes($winId,yoff)]]
	grid [label $rg.lxs -text [tr. {X scale:}]] \
	    [ttk::entry $rg.exs -width 8 \
		 -textvar [itcl::scope useNodes($winId,xscale)]] \
	    [label $rg.lys -text [tr. {Y scale:}]] \
	    [ttk::entry $rg.eys -width 8 \
		 -textvar [itcl::scope useNodes($winId,yscale)]]
	pack $rg -fill x

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
		-var [itcl::scope useNodes($winId,orient)]
	}
	grid x $oriF.t
	grid $oriF.l $oriF.n $oriF.r
	grid x $oriF.b
        pack $oriF -padx 10 -pady 10 -fill x
        
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
    }
    
    public method LegendPosn {} {
	return $useNodes($winId,orient)
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
