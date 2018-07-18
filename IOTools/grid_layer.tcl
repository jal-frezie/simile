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
	    incr useNodes($winId,nswatches)
	    if {$useNodes($winId,state) eq "displaying"} {
		Display 0 0 0
		return
	    }
	} else {
	    set useNodes($winId,xoff) 0
	    set useNodes($winId,yoff) 0
	    set useNodes($winId,xscale) 1
	    set useNodes($winId,yscale) 1
	    set useNodes($winId,hex) 0
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
	    set useNodes($winId,cmid) red
	    set useNodes($winId,ctop) white
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
	    [tr. "Click on the variable whose values are to be displayed on the grid."]
	$winId create window $vx $vy -window $winId.ms -anchor nw \
	    -tag instruct
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
		    set useNodes($winId,title) "[file tail $path] (rectangular grid diagram)"
		    SetColourMap useNodes $winId [GetIdFromCaptionPath $path]
		    SetColours useNodes $winId
		    set useNodes($winId,tgtDims) [$modelInst GetModelDims $path]
		    if {[IsTwoDee $winId $useNodes($winId,tgtDims)]} {
			set useNodes($winId,colvals) USE_INDICES
			set parentPath [join [lrange [split $path /] 0 end-1] /]
			if {[$modelInst GetModelEval $parentPath] eq \
				"HONEYCOMB"} {
			    set useNodes($winId,hex) 1
			    set useNodes($winId,xscale) 1.7320508
			    set useNodes($winId,yscale) 1.5
			}
			FinishClicking
		    } else {
			$winId.ms configure -text "Now click on a variable giving the column IDs."
			set useNodes($winId,state) display1
		    }
		} display1 {
                    NumDistinct $winId $path
		    set useNodes($winId,colvals) $path ;# not that it gets used
		    FinishClicking
		}
	    }
	} else {
            $winId.ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
        }
    }
   
    public method FinishClicking {} {
	$winId delete instruct
	destroy $winId.ms
	$modelInst ReleaseClicks
	set useNodes($winId,state) displaying
	Display 0 0 0
    }

    public method GetTitle {} {
	return $useNodes($winId,title)
    }

    public method IsTwoDee {winId dimList} {
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
	set node [GetIdFromCaptionPath $testPath]
	if {![catch {ListDistinctModelValues $node} vList]} {
	    set useNodes($winId,ncol) [llength [lrange $vList 1 end]]
	    set useNodes($winId,nrow) \
		[expr {[lindex $vList 0]/$useNodes($winId,ncol)}]
	} else {
	    set count [DoForData [$modelInst GetValue $testPath] colvals]
	    set useNodes($winId,ncol) [array size colvals]
	    set useNodes($winId,nrow) \
		[expr {$count/$useNodes($winId,ncol)}]
# puts "prang $vList col $useNodes($winId,ncol) row $useNodes($winId,nrow)"
	}
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
	set useNodes(temp,curValues) \
	    [$modelInst GetValue $useNodes($winId,color) -numeric 1]
	set node [GetIdFromCaptionPath $useNodes($winId,color)]
	if {$useNodes($winId,hex) || \
		[lsearch $useNodes($winId,tgtDims) START_VM]>-1 || \
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
	    set colourIndex [expr $rgbQuad*$useNodes($winId,nswatches)/256]
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

    public method DrawGrid7 {} {
	set ncol $useNodes($winId,ncol)
	set nrow $useNodes($winId,nrow)
	set data $useNodes(temp,curValues)
	if {$useNodes($winId,colvals) eq "USE_INDICES"} {
	    set colShift -1
	    if {$useNodes($winId,hex)} {
		incr colShift $ncol
	    }
	    $this.original blank
	    foreach {y row} $data {
		set tgtRow [expr {$nrow-$y}]
		foreach {x celval} $row {
		    $this.original put [ForGrid $celval] \
			-to [incr x $colShift] $tgtRow
		}
		if {$useNodes($winId,hex)} {
		    set xShift [expr {$y%2}]
		    $this.original copy $this.original -from $ncol $tgtRow \
			[expr {2*$ncol}] [expr {$tgtRow+1}] \
			-to $xShift $tgtRow -zoom 2 1 -compositingrule set
		}
	    }
	    $this.original config -height $nrow \
		-width [expr {$useNodes($winId,hex)?2*$ncol+1:$ncol}] \
		
	} else {
	    set values [Flatten $data]
        
	    set allData {}
	    for {set row 1} {$row<=$nrow} {incr row} {
		set rowData($row) {}
		for {set col 1} {$col<=$ncol} {incr col} {
		    set cell [expr ($row-1)*$ncol+$col-1]
		    set celval [lindex [lindex $values $cell] 1]
		    set length [llength $celval]
                
		    if {$length} {
			lappend rowData($row) [ForGrid $celval]
		    } else {
			lappend rowData($row) grey
		    }
		}
	    }
	    for {set row $nrow} {$row>=1} {incr row -1} {
		lappend allData $rowData($row)
	    }
	    $this.original put $allData
	    PutSize $this.original
        }
    }

    public method ForGrid {celval} {
        set min $useNodes($winId,min)
	set max $useNodes($winId,max)
        set range [expr {$max-$min}]
	set nswatches [expr {$useNodes($winId,nswatches)-1}]
        
	if {$celval<$useNodes($winId,datamin)} {
	    set useNodes($winId,datamin) $celval
	}
	if {$celval>$useNodes($winId,datamax)} {
	    set useNodes($winId,datamax) $celval
	}
	if {$celval<=$min} {
	    set icolour 0
	} elseif {$celval>=$max} {
	    set icolour $nswatches
	} else {
	    set icolour [expr {int($nswatches*($celval-$min)/$range)}]
	}
	return $useNodes($winId,c$icolour)
    }

    method SeekValue {inds vals} {
	if {$inds eq ""} {
	    return $vals
	} else {
	    array set indexed $vals
	    set subL indexed([lindex $inds 0])
	    if {![info exists $subL]} {
		return "no instance"
	    }
	    return [SeekValue [lrange $inds 1 end] [set $subL]]
	}
    }
	    
    method CurrentPopup {x y} {
	set col [expr int(1+([$winId canvasx $x]/$transform(xzoom)-$useNodes($winId,xoff))/$useNodes($winId,xscale))]
	set row [expr int(1+(-[$winId canvasy $y]/$transform(yzoom)-$useNodes($winId,yoff))/$useNodes($winId,yscale))]
	set col [expr {min(max($col, 1), $useNodes($winId,ncol))}]
	set row [expr {min(max($row, 1), $useNodes($winId,nrow))}]
	if {$useNodes($winId,colvals) eq "USE_INDICES"} {
	    set inds [list $row $col]
	    set value [SeekValue $inds $useNodes(temp,curValues)]
	} else {
	    set inds [expr {$useNodes($winId,ncol)*($row-1)+$col}]
	    set value [lindex \
			   [lindex [Flatten $useNodes(temp,curValues)] $inds] 1]
	}
	return "Index $row,$col Value $value"
    }

    public method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
	set stickIt [list [expr {$useNodes($winId,xoff)*$xzoom}] \
			 [expr {-$useNodes($winId,yoff)*$yzoom}]]
	set tmpImg [GrowImage $this.original \
	    [expr {round([$this.original cget -width]*$useNodes($winId,xscale)*$xzoom)/(1+$useNodes($winId,hex))}] \
	    [expr {round([$this.original cget -height]*$useNodes($winId,yscale)*$yzoom)}]]
	set myTag [namespace tail $this].main
	if {[catch {$this.derived blank}]} { ;# not yet exist
	    image create photo $this.derived
	    $winId create image $stickIt -anchor sw -image $this.derived \
						 -tag $myTag
	    $winId bind $myTag <Enter> "QueuePopup AddWidgetPopup %W %X %Y \
					\[$this CurrentPopup %x %y\]"
	    $winId bind $myTag <Motion> "QueuePopup AddWidgetPopup %W %X %Y \
					\[$this CurrentPopup %x %y\]"
	    $winId bind $myTag <Leave> RemovePopup
	    
	} else {
	    $winId coords [$winId find withtag $myTag] $stickIt
	}
	$this.derived copy $tmpImg -shrink
    }

    public method PrepareSaveString {} {
	incr useNodes($winId,nswatches) -1
	regsub -all $winId, [array get useNodes] {} State
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
	    Display 0 0 0	    
	}
	PackItUp $subDlg
    }

    public method Settings {} {
	set dlg [PutItThere .polyprop [winfo toplevel $winId]]
	wm title $dlg [tr. "Grid display properties"]
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
	$host PosnLegends
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

    public method DoForData {key return} {
	upvar 1 $return dest
	if {[llength $key]==1} {
	    set dest($key) 1
	    return 1
	} else {
	    set tot 0
	    foreach {ind val} $key {
		incr tot [DoForData $val dest]
	    }
	    return $tot
	}
    }

#     public method ColourFor {winId value} {
#        if {[string match nil $value]} {
#            set newColour gray
#        } else {
#	    set clipVal [expr {max($useNodes($winId,min),
#				   min($useNodes($winId,max),$value))}]
#	    set colNum [expr int(($clipVal-$useNodes($winId,min))* \
#				     ($useNodes($winId,nswatches)-1) / \
#				     $useNodes($winId,range))]
#            set newColour $useNodes($winId,c$colNum)
#        }
##puts "Colour for $value is $colNum (range $useNodes($winId,range))"
#    }
#    
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
