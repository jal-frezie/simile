# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass RectGrid20131119
oo::class create iotool::$newLayerClass {
    superclass iotool::Layer
    variable useNodes transform curValues modelInst winId host
    
    self {
	method identify {} {
	    return "Grid map"
	}
    }

    constructor {modelWindow mainCanvas xzoom yzoom {state {}}} {
	next $modelWindow $mainCanvas

	namespace import -force ::maptools2::*
	array set transform [list xzoom $xzoom yzoom $yzoom]
	image create photo [self object].original 
	set useNodes($winId,resetDone) 1 ;# always do one update
	if {[string length $state]} { ;# we are restoring
	    set useNodes($winId,bpp) 8 ;# in case saved before this invented
	    foreach {att val} $state {
		set useNodes($winId,$att) $val
		if {![string first / $val]} {
		    set useNodes(nC,$att) [GetIdFromCaptionPath $val]
		}
	    }
	    incr useNodes($winId,nswatches)
	    MakeHexColours useNodes $winId
	    if {$useNodes($winId,state) eq "displaying"} {
		my Display 0
		return
	    }
	} else {
	    set useNodes($winId,xoff) 0
	    set useNodes($winId,yoff) 0
	    set useNodes($winId,xscale) 1
	    set useNodes($winId,yscale) 1
	    set useNodes($winId,hex) 0
	    set useNodes($winId,title) [[self class] identify]
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
	my AddVariable
    }

### Public methods ###
    method getTitle {} {
	return $useNodes($winId,title)
    }

    method settings {} {
	set dlg [PutItThere .polyprop [winfo toplevel $winId]]
	wm title $dlg [tr. "Grid display properties"]
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
        set coloursF [labelframe $dlg.colours -text "Colour scale"]
	pack [button $coloursF.change -text "Edit colour key" \
		  -command [namespace code [list my EditKey $dlg]]]
#	foreach {ptName ptId} {Low bot Middle mid High top} {
#	    pack [ttk::labelframe $coloursF.${ptId}colourF \
#		      -text "$ptName  colour"] -fill x -padx 10
#	    frame $coloursF.${ptId}colourF.colF -width 20 -height 15 \
#		-bg $useNodes($winId,c${ptId})
#	    pack [button $colploursF.${ptId}colourF.cbutton -text "..." \
#		      -command [list [self object] Recolour $ptId \
#				    $coloursF.${ptId}colourF.colF]] -side right
#	    pack $coloursF.${ptId}colourF.colF -side right -padx 10
#        }
        pack $coloursF -padx 10 -pady 10 -fill x
        
	set rg [labelframe $dlg.relgeom -text "Offset and scaling"]
	grid [label $rg.lxo -text [tr. {X offset:}]] \
	    [ttk::entry $rg.exo -width 8 \
		 -textvar [self namespace]::useNodes($winId,xoff)] \
	    [label $rg.lyo -text [tr. {Y offset:}]] \
	    [ttk::entry $rg.eyo -width 8 \
		 -textvar [self namespace]::useNodes($winId,yoff)]
	grid [label $rg.lxs -text [tr. {X scale:}]] \
	    [ttk::entry $rg.exs -width 8 \
		 -textvar [self namespace]::useNodes($winId,xscale)] \
	    [label $rg.lys -text [tr. {Y scale:}]] \
	    [ttk::entry $rg.eys -width 8 \
		 -textvar [self namespace]::useNodes($winId,yscale)]
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
        pack [ttk::checkbutton $dlg.update -text "Update at display intervals" \
		  -variable [self namespace]::useNodes($winId,displayUpdate)]
        pack [ttk::checkbutton $dlg.popups -text "Pop up indices and values" \
		  -variable [self namespace]::useNodes($winId,doPopup)]
        
        set oriF [labelframe $dlg.orient -text "Legend position:"]
	foreach legendPosn {l t r b n} desc {Left Top Right Bottom None} {
	    radiobutton $oriF.$legendPosn -text $desc -value $legendPosn \
		-var [self namespace]::useNodes($winId,legendSide)
	}
	grid x $oriF.t
	grid $oriF.l $oriF.n $oriF.r
	grid x $oriF.b
        pack $oriF -padx 10 -pady 10 -fill x
        
	pack [frame $dlg.btns] -fill x
	set adjCmd [namespace code [list my AdjRange $rangeF]]
	pack [ttk::button $dlg.btns.apply -text [tr. Apply] \
		  -command $adjCmd] -side left
        pack [ttk::button $dlg.btns.done -text [tr. Done] \
		  -command "set polyProps(xdone) 1"] -side right
	LetItShow $dlg polyProps(xdone)
	PackItUp $dlg
    }

    method zoomTo {x y} {
	my ZoomTo $x $y
    }
    
    method display {time dispInt step} {
	my Display $time
    }
    
    method prepareSaveString {} {
	if {[info exists useNodes($winId,colourMap)]} {
	    set hide $useNodes($winId,colourMap)
	    unset useNodes($winId,colourMap)
	}
	incr useNodes($winId,nswatches) -1
	regsub -all $winId, [array get useNodes] {} State
	incr useNodes($winId,nswatches)
	if {[info exists hide]} {
	    set useNodes($winId,colourMap) $hide
	}
	return $State
    }

### Private methods ###
    method getCanvas {} {
	return $winId
    }

    method AddVariable {} {
	set vx [$winId canvasx 0]
	set vy [$winId canvasy 0]
	label $winId.ms -bg white -text \
	    [tr. "Click on the variable whose values are to be displayed on the grid."]
	$winId create window $vx $vy -window $winId.ms -anchor nw \
	    -tag instruct
	$modelInst grabClicks [self object]
	set useNodes($winId,state) display0
    }

    method click {path} {
        set testResult [$modelInst getValue $path]
        # This tests for the user having clicked on a suitable element
        # of the model diagram
        if {[string compare $testResult novalue]} {
            set compon [GetIdFromCaptionPath $path]
	    switch $useNodes($winId,state) {
		display0 {
                    set useNodes(nC,color) $compon
                    set useNodes($winId,color) $path
		    set useNodes($winId,title) "[file tail $path] (rectangular grid diagram)"
		    SetColourMap useNodes $winId [GetIdFromCaptionPath $path]
		    SetColours useNodes $winId
		    set useNodes($winId,tgtDims) [$modelInst getModelDims $path]
		    if {[my IsTwoDee $winId]} {
			set useNodes($winId,colvals) USE_INDICES
			set parentPath [join [lrange [split $path /] 0 end-1] /]
			if {[$modelInst getModelEval $parentPath] eq \
				"HONEYCOMB"} {
			    set useNodes($winId,hex) 1
			    set useNodes($winId,xscale) 1.7320508
			    set useNodes($winId,yscale) 1.5
			}
			my FinishClicking
		    } else {
			$winId.ms configure -text "Now click on a variable giving the column IDs."
			set useNodes($winId,state) display1
		    }
		} display1 {
                    NumDistinct $winId $compon
                    set useNodes(nC,colvals) $compon
		    set useNodes($winId,colvals) $path ;# not that it gets used
		    my FinishClicking
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
	$modelInst releaseClicks
	set useNodes($winId,state) displaying
	my Display 0
    }

    method IsTwoDee {winId} {
	foreach dim $useNodes($winId,tgtDims) {
	    if {[string is integer -strict $dim]} {
		foreach space [list useNodes($winId,nrow) \
				   useNodes($winId,ncol) subxel terminator] {
		    if {![info exists $space]} {
			set $space $dim
			break
		    }
		}
	    }
	}
	set useNodes($winId,bpp) 8
	if {[info exists subxel]} {
	    if {!$subxel} {return 1} ;# 2-D array of values
	    if {$subxel==3 && !$terminator} {
		set useNodes($winId,bpp) 24
		return 1
	    } ;# of triplets
	}
	return 0
    }

    method NumDistinct {winId node} {
	if {![catch {ListDistinctModelValues $node} vList]} {
	    set useNodes($winId,ncol) [llength [lrange $vList 1 end]]
	    set useNodes($winId,nrow) \
		[expr {[lindex $vList 0]/$useNodes($winId,ncol)}]
	} else {
	    set count [DoForData [$modelInst getValue $node] colvals]
	    set useNodes($winId,ncol) [array size colvals]
	    set useNodes($winId,nrow) \
		[expr {$count/$useNodes($winId,ncol)}]
# puts "prang $vList col $useNodes($winId,ncol) row $useNodes($winId,nrow)"
	}
    }

    method Reset {} {
	# want to update display even if updates over time disabled
	set useNodes($winId,resetDone) 1
    }
	    
    method Display {time} {
	if {[string equal displaying $useNodes($winId,state)] && \
		($useNodes($winId,displayUpdate) || $useNodes($winId,resetDone))} {
            my DrawGrid8
# will update visible part of canvas if whole scrollregion not displayed
	    my ZoomTo $transform(xzoom) $transform(yzoom)
	    $winId raise [namespace tail [self object]].main
	}
	set useNodes($winId,resetDone) 0
    }

    method DrawGrid8 {} {
# do not use image mode for inputs cos we will want to edit them...
# hah, just fixed it so we can anyway
	set node $useNodes(nC,color)
	set bpp $useNodes($winId,bpp)
	set hex $useNodes($winId,hex)
	if {[lsearch $useNodes($winId,tgtDims) START_VM]>-1 || \
		[catch {grid005::ConcoctImage $winId $node [self object].original}]} {
	    my DrawGrid7
	    return
	}

        if {0 && $useNodes($winId,hex)} {
	    set w [expr 2*{[[self object].original cget -width]}]
	    set h [[self object].original cget -height]
	    [self object].original configure -width $w
	    [self object].original copy [self object].original -zoom 2 1
	    for {set shift 0} {$shift < $h} {incr shift 2} {
		[self object].original copy [self object].original -from 0 $shift $w [expr {$shift+1}] -to 1 $shift
	    }
	}
    }

    method DrawGrid7 {} {
	set ncol $useNodes($winId,ncol)
	set nrow $useNodes($winId,nrow)
	set curValues [$modelInst getValue $useNodes(nC,color) -numeric 1]
        if {$curValues eq "unstable"} return
        if {$useNodes($winId,colvals) eq "USE_INDICES"} {
	    set colShift -1
	    if {$useNodes($winId,hex)} {
		incr colShift $ncol
	    }
	    [self object].original blank
	    [self object].original config -height $nrow \
		-width [expr {$useNodes($winId,hex)?2*$ncol+1:$ncol}]
		
	    foreach {y row} $curValues {
		foreach {x celval} $row {
		    [self object].original put [my ForGrid $celval] \
			-to [incr x $colShift] [expr {$y-1}]
		}
		if {$useNodes($winId,hex)} {
		    set xShift [expr {$y%2}]
		    [self object].original copy [self object].original -from $ncol [expr {$y-1}] \
			[expr {2*$ncol}] $y \
			-to $xShift [expr {$y-1}] -zoom 2 1 -compositingrule set
		}
	    }
	} else {
	    set values [Flatten $curValues]
        
	    set allData {}
	    for {set row 1} {$row<=$nrow} {incr row} {
		set rowData($row) {}
		for {set col 1} {$col<=$ncol} {incr col} {
		    set cell [expr ($row-1)*$ncol+$col-1]
		    set celval [lindex [lindex $values $cell] 1]
		    set length [llength $celval]
                
		    if {$length} {
			lappend rowData($row) [my ForGrid $celval]
		    } else {
			lappend rowData($row) grey
		    }
		}
	    }
	    for {set row 1} {$row<=$nrow} {incr row} {
		lappend allData $rowData($row)
	    }
	    [self object].original put $allData
	    # PutSize [self object].original
        }
    }

    method ForGrid {celval} {
        set min $useNodes($winId,min)
	set max $useNodes($winId,max)
        set range [expr {$max-$min}]
	set nswatches [expr {$useNodes($winId,nswatches)-1}]

        if {$useNodes($winId,bpp)==24} {
	    return [eval format {#%6$.2X%4$.2X%2$.2X} $celval]
	}
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
	    
    method CurrentPopup {x y} {
	set col [expr int(1+([$winId canvasx $x]/$transform(xzoom)-$useNodes($winId,xoff))/$useNodes($winId,xscale))]
	set row [expr int(1+(-[$winId canvasy $y]/$transform(yzoom)-$useNodes($winId,yoff))/$useNodes($winId,yscale))]
	set col [expr {min(max($col, 1), $useNodes($winId,ncol))}]
	set row [expr {min(max($row, 1), $useNodes($winId,nrow))}]
	if {[info exists curValues]} {
	    if {$useNodes($winId,colvals) eq "USE_INDICES"} {
		array set curArr $curValues
		array set rowArr $curArr($row)
		if {[catch {set value $rowArr($col)}]} {
		    set value none
		}
	    } else {
		set inds [expr {$useNodes($winId,ncol)*($row-1)+$col-1}]
		set value [lindex [lindex [Flatten $curValues] $inds] 1]
	    }
	} else {
	    set value [GetModelValue $useNodes(nC,color) 0 1 \
			   [list $row $col]]
	}
	return "Index $row,$col Value $value"
    }

    method ZoomTo {xzoom yzoom} {
	array set transform [list xzoom $xzoom yzoom $yzoom]
# will adjust line widths
	set stickIt [list [expr {$useNodes($winId,xoff)*$xzoom}] \
			 [expr {-$useNodes($winId,yoff)*$yzoom}]]
	if {$useNodes($winId,hex)} {
	    set xzoom [expr {$xzoom/2.0}]
	}
	set tmpImg [GrowImage [self object].original \
	    [expr {round([[self object].original cget -width]*$useNodes($winId,xscale)*$xzoom)}] \
	    [expr {round([[self object].original cget -height]*$useNodes($winId,yscale)*$yzoom)}] -1]
	set myTag [namespace tail [self object]].main
	if {[catch {[self object].derived blank}]} { ;# not yet exist
	    image create photo [self object].derived
	    $winId create image $stickIt -anchor sw -image [self object].derived \
						 -tag $myTag
	    set popCmd "\[[namespace code [list my CurrentPopup %x %y]]\]"
	    $winId bind $myTag <Enter> "QueuePopup AddWidgetPopup %W %X %Y \
					$popCmd"
	    $winId bind $myTag <Motion> "QueuePopup AddWidgetPopup %W %X %Y \
					$popCmd"
	    $winId bind $myTag <Leave> RemovePopup
	    
	} else {
	    $winId coords [$winId find withtag $myTag] $stickIt
	}
	[self object].derived copy $tmpImg -shrink
    }

    method EditKey {parent} {
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
	    my Display 0
	}
	PackItUp $subDlg
    }
    
    method AdjRange {rangeF} {
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
	my Display 0
	switch -regexp $useNodes($winId,legendSide) {
	    l|r {
		set useNodes($winId,orient) v
	    } t|b {
		set useNodes($winId,orient) h
	    }
	}
	# now a callback to layer manager to draw and posn it
	$host posnLegends
    }

    method getSwatchColour {swId} {
	::maptools2::SetSwatchColour ::[self object] $winId $swId
	$host posnLegends
    }

    method getNewLegendSide {} {
	if {$useNodes($winId,legendSide) ne "n"} {
	    recolour_scale ::[self object] $winId
	}
	return $useNodes($winId,legendSide)
    }

    method Recolour {whichCol exampleWidget} {
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
	my Display 0
    }

    method DoForData {key return} {
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

#     method ColourFor {winId value} {
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
    method IdToTag {ids} {
	set result {}
	foreach id $ids {
	    lappend result [format %06d $id]
	}
	return $[namespace tail [self object]]BLK[join $result ,]
    }

    method TagToId {tags} {
	set myTag $[namespace tail [self object]]
	set end [expr [string first $myTag $tags]+[string length $myTag]]
	set idTag [lindex [string range $tags $end end] 0]
	foreach val [split $idTag ,] {
	    scan $val %06d index
	    lappend result $index
	}
	return [join $result ,]
    }
}
