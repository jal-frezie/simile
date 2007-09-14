# This contains generic procedures used by various other IO tools that
# draw coloured maps, e.g., the polygon and grid tools.

# It will not be picked up as a menu item when the tools ar loadede because
# it does not contain a set keyValue instruction.

# Only the useful procedures are exported so a tool that uses them can import
# everything from this namespace.

# by Jasper Taylor, March 2001


namespace eval ::maptools2 {
    
    proc SetColourMap {winData winId node} {
        upvar 1 $winData useNodes
# OK, do things differently if it is an enumerated type
	set useNodes($winId,allETs) [GetTransTable $node]
	set useNodes($winId,dataETs) [lindex $useNodes($winId,allETs) end]
	set useNodes($winId,ETCount) [llength $useNodes($winId,dataETs)]
	if {$useNodes($winId,ETCount)>2} {
	    set useNodes($winId,min) 1
	    set useNodes($winId,max) [expr $useNodes($winId,ETCount)-1]
	    set useNodes($winId,range) [expr $useNodes($winId,max)-1]
	    set useNodes($winId,nswatches) $useNodes($winId,range)
	} elseif {$useNodes($winId,ETCount)} { ;# a boolean
	    set useNodes($winId,min) 0
	    set useNodes($winId,max) 1
	    set useNodes($winId,range) 1
	    set useNodes($winId,nswatches) 1
	} else {
	    set useNodes($winId,integer) \
		[string match INTEGER [GetModelType $node]]
	    if {$useNodes($winId,integer)} {
		set bigNum 268435455
	    } else {
		set bigNum 1e100
	    }
	    set min [GetMinValue $node]
	    if {$min!=-$bigNum} {
		set useNodes($winId,min) $min
	    }
	    set max [GetMaxValue $node]
	    if {$max!=$bigNum} {
		set useNodes($winId,max) $max
	    }
	    set useNodes($winId,range) \
                [expr $useNodes($winId,max)-$useNodes($winId,min)]
	    if [expr !$useNodes($winId,integer) || [expr $useNodes($winId,range) > 32]] {
		set useNodes($winId,nswatches) 32
	    } else  {
		set useNodes($winId,nswatches) \
		    [expr int($useNodes($winId,range))]
	    }
        }
#	ShowMessage debug info "min $useNodes($winId,min); \
#                    max $useNodes($winId,max); dataETs $useNodes($winId,dataETs); $useNodes($winId,range); \
#                    $useNodes($winId,nswatches)" ok
	if {[info exists useNodes($winId,cbot)]} {
	    SetColours useNodes $winId
	}
    }
    
    proc SetColours {winData winId} {
        #    ShowMessage debug info "proc SetColours" ok
        upvar 1 $winData useNodes
        
	if {$useNodes($winId,ETCount)>2} {
	    set defCols {blue orange green brown purple red black DeepSkyBlue \
                    HotPink ForestGreen}
	    for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
		if {$icolour<[llength $defCols]} {
		    set useNodes($winId,c$icolour) [lindex $defCols $icolour]
		} else {
		    set useNodes($winId,c$icolour) gray44
		}
	    }
	} elseif {$useNodes($winId,ETCount)} {
	    set useNodes($winId,c0) gray20
	    set useNodes($winId,c1) gray80
	} else {
	    scan [winfo rgb $winId $useNodes($winId,cbot)] "%d %d %d" botr botg botb
	    scan [winfo rgb $winId $useNodes($winId,cmid)] "%d %d %d" midr midg midb
	    scan [winfo rgb $winId $useNodes($winId,ctop)] "%d %d %d" topr topg topb
        
	    set max $useNodes($winId,nswatches); #[expr int($useNodes($winId,max))]
	    set min 0; #[expr int($useNodes($winId,min))]
	    set med [expr $useNodes($winId,nswatches)/2.0]
        #    ShowMessage debug info "$min $max $med" ok
        # make the colour descriptions, this should improve speed
	    for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
		if {$icolour<$med} {
		    set red [expr int(($icolour*$midr+($med-$icolour)*$botr)/$med)]
		    set green [expr int(($icolour*$midg+($med-$icolour)*$botg)/$med)]
		    set blue [expr int(($icolour*$midb+($med-$icolour)*$botb)/$med)]
		} elseif {$icolour<=$max} {
		    set red [expr int((($icolour-$med)*$topr+($max-$icolour)*$midr)/$med)]
		    set green [expr int((($icolour-$med)*$topg+($max-$icolour)*$midg)/$med)]
		    set blue [expr int((($icolour-$med)*$topb+($max-$icolour)*$midb)/$med)]
		}
		set useNodes($winId,c$icolour) [format \#%04x%04x%04x $red $green $blue]
	    }
	}
	set useNodes($winId,colourMapTweaked) 0
    }
    
    proc recolour_scale {parentSpc winId} {
        variable ${parentSpc}::useNodes
        
	set cnv [${parentSpc}::GetCanvas $winId]
        #ShowMessage debug info "recolour_scale " ok
        $cnv delete colour_scale
#        if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
#            set n $useNodes($winId,nrow)
#        } else {
#            set n $useNodes($winId,ncol)
#        }
        set leftSc [$cnv canvasx 0]
        set rightSc [$cnv canvasx [winfo width $cnv]]
        set bottomSc [$cnv canvasy [winfo height $cnv]]
        set topSc [expr $bottomSc-40]
        set midSc [expr $bottomSc-20]
        
        # blank over bottom of display
        $cnv create rect $leftSc $topSc $rightSc $bottomSc \
	    -outline {} -fill [$cnv cget -bg] -tag {colour_scale scale_base}
        $cnv create text [expr ($leftSc+$rightSc)/2] [expr $bottomSc-30] \
                -anchor c -tag {colour_scale caption}
#        UpdateCaption useNodes $winId
        $cnv create text [expr $leftSc+47] [expr $bottomSc-10] \
                -text $useNodes($winId,min) -anchor e -tag colour_scale
        $cnv create text [expr $rightSc-48] [expr $bottomSc-10] \
                -text $useNodes($winId,max) -anchor w -tag colour_scale
        set useNodes($winId,range) [expr $useNodes($winId,max)-$useNodes($winId,min)]
        set xmin [expr $leftSc+50]
        set xmax [expr $rightSc-50]
        set xincr [expr {($xmax-$xmin)/($useNodes($winId,nswatches)+1)}]
        for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
            set x0 [expr {$xmin+$icolour*$xincr}]
            set x1 [expr {$x0+$xincr}]
            set colour $useNodes($winId,c$icolour)
            set polyId [$cnv create rectangle $x0 $midSc $x1 $bottomSc \
			    -outline {} -fill $colour \
			    -tag "colour_scale swatch COL$icolour"]
	    set newVal [expr {$useNodes($winId,min) + \
				  $icolour * $useNodes($winId,range) \
				  / $useNodes($winId,nswatches)}]
	    CanvasBindPopup $cnv $polyId \
                    [list Colour for value: \
			 [TransValue $useNodes($winId,dataETs) $newVal] \
			(doubleclick to change)]
	    $cnv bind $polyId <Double-Button-1> \
		[namespace code "SetSwatchColour $parentSpc $winId $icolour"]
        }
        
    }
    
    proc SetSwatchColour { parentSpc winId icolour } {
        variable ${parentSpc}::useNodes

	set newCol [tk_chooseColor -initialcolor $useNodes($winId,c$icolour) \
			-title "Choose colour" -parent $winId]
	if {[string length $newCol]} {
	    set useNodes($winId,c$icolour) $newCol
	    recolour_scale $parentSpc $winId
	    set useNodes($winId,colourMapTweaked) 1
	    ${parentSpc}::UpdateState $winId
	    ${parentSpc}::display $winId 0 0 0
	}
    }
    
    proc reposn_scale {parentSpc winId} {
	set cnv [${parentSpc}::GetCanvas $winId]
        set leftSc [$cnv canvasx 0]
        set bottomSc [$cnv canvasy [winfo height $cnv]]

	set oldPt [$cnv coords scale_base]
	set xoff [expr $leftSc-[lindex $oldPt 0]]
	set yoff [expr $bottomSc-[lindex $oldPt 3]]

	$cnv move colour_scale $xoff $yoff
    }

    proc UpdateCaption {winData winId} {
        upvar 1 $winData useNodes

        $winId.c itemconfig caption -text "[file tail [GetCaptionPathFromId $useNodes($winId,color)]] ($useNodes($winId,ncol)x$useNodes($winId,nrow), time = [GetModelTime])"
    }
    
    proc ChangeEditMode {ParentSpc winId} {
        variable ${ParentSpc}::useNodes
	set cnv [${ParentSpc}::GetCanvas $winId]
        if $useNodes($winId,editMode)==1 {
            set useNodes($winId,editMode) 0
            pack forget $winId.msg
	    $winId.bbframe.buttonBox itemconfigure 5 -state normal -relief raised
	    $cnv bind swatch <ButtonPress> {}
#            for  {set j 0} {$j <= $useNodes($winId,nswatches)} {incr j} {
#                $winId.legend.pop$j configure -borderwidth 0
#                bind $winId.legend.pop$j <ButtonPress> {}
#            }
            $cnv bind map <Button-1> {}
            $cnv bind map <B1-Motion> {}
	    $cnv configure -cursor {}
        } else  {
            set useNodes($winId,editMode) 1
            $winId.msg configure -text \
                    "Click on the colour bar to select the value to \
                    'paint' polygons."
	    pack $winId.msg -side bottom -fill x

	    $winId.bbframe.buttonBox itemconfigure 5 -state active -relief sunken
            #  bind mouse click to get the value to assign from the colour clicked upon
	    $cnv bind swatch <ButtonPress> \
		[namespace code "CnvGetNewVal $ParentSpc $winId %x %y"]
#            for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
#                bind $winId.legend.pop$swatch <ButtonPress> \
#                        [namespace code "GetNewVal $winId $swatch"]
#            }
        }
    }
    
    proc CnvGetNewVal {ParentSpc winId tgx tgy} {
	variable ${ParentSpc}::useNodes
	set cnv [${ParentSpc}::GetCanvas $winId]
	set bndlist [$cnv coords scale_base]
        set X [$cnv canvasx $tgx]
        set Y [$cnv canvasy $tgy]
	set zapped [$cnv find closest $X $Y]
	for {set n 0} {$n <= $useNodes($winId,nswatches)} {incr n} {
	    set byng [$cnv find withtag COL$n]
	    if {$byng==$zapped} {
		$cnv itemconfig $byng -outline black
		set useNodes($winId,paintColour) $useNodes($winId,c$n)
		set newVal [expr {int($useNodes($winId,min) + 0.5 + \
					  $n * $useNodes($winId,range) \
					  / $useNodes($winId,nswatches))}]
	    } else {
		$cnv itemconfig $byng  -outline {}
	    }
	}
        $winId.msg configure -text \
                "Click on the polygon(s) whose colour (value) you wish \
                to change."
	pack $winId.msg -side bottom -fill x
        #    $winId.buttons.msg configure -text "new value $newVal"; # 1 $1 todo; debug line
        $cnv configure -cursor spraycan
        $cnv bind map <B1-Motion> "${ParentSpc}::ChangeValue $winId $newVal %x %y"
        $cnv bind map <Button-1> "${ParentSpc}::ChangeValue $winId $newVal %x %y"
    }

# redundant
    proc InsertLegend {winData winId} {
        #    ShowMessage debug info "proc InsertLegend" ok
        upvar 1 $winData useNodes
        set max [expr int($useNodes($winId,max))]
        set min [expr int($useNodes($winId,min))]
        #ShowMessage debug info "min $min; max $max" ok
        frame $winId.legend
        pack $winId.legend -side right -fill y -pady 2m
        if $useNodes($winId,integer) {
            set tickinterval 1
            set resolution 1
        } else  {
            set tickinterval [expr 1.0*$useNodes($winId,range)/$useNodes($winId,nswatches)]
            set resolution [expr $tickinterval/10.0]
        }
        #-tickinterval [expr $useNodes($winId,range)/10.0] TODO
        #-resolution [expr $useNodes($winId,range)/100.0] TODO
        #ShowMessage debug info "min $min; max $max; $tickinterval; $resolution" ok
        scale $winId.legend.scale -from $max \
                -to $min -showvalue false -sliderlength 2 \
                -width 5 -tickinterval $tickinterval \
                -borderwidth 1 -resolution $resolution
        pack $winId.legend.scale -side left -fill y -expand true
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            pack [frame $winId.legend.pop$swatch -width 10] -fill y -expand true \
                    -side bottom
        }
    }
    
# redundant
    proc ColourScale {winData winId} {
        #    ShowMessage debug info "proc ColourScale" ok
        upvar 1 $winData useNodes
        set max [expr int($useNodes($winId,max))]
        set min [expr int($useNodes($winId,min))]
        $winId.legend.scale config -from $max \
                -to $min
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            $winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
        }
    }
    
    proc GetQuadList {inds args} {
        # requires an empty list, quadlist, at the calling stack level
        upvar 1 quadlist quadlist
        
        set pilot [lindex $args 0]
        if {![llength $pilot]} {
            set args [lreplace $args 0 0 nil]
        } elseif {[llength $pilot]==2 && ![llength [lindex $pilot 0]]} {
            set args [lreplace $args 0 0 [lindex $pilot 1]]
        }
        if {[llength [lindex $args 0]] == 1} {
            lappend quadlist $inds $args
        } else {
            set arrcount 0
            foreach arg $args {
                array set new$arrcount $arg
                incr arrcount
            }
            
            foreach elt [array names new0] {
                set arrcount 0
                set newargs {}
                foreach arg $args {
                    upvar 0 new$arrcount newarr
                    lappend newargs [set new${arrcount}($elt)]; # $newarr($elt); ####
                    incr arrcount
                }
                eval GetQuadList [list [concat $inds $elt]] $newargs
            }
        }
    }
    
    proc Flatten {nested flat} {
        for {set i 1} {$i < [llength $nested]} {incr i 2} {
            set subi [lindex $nested $i]
            if {[string match {} $subi]} {
                lappend flat {}
            } elseif {[llength $subi] == 1} {
                lappend flat $subi
            } else {
                set flat [Flatten $subi $flat]
            }
        }
        return $flat
    }

    proc Flatten {nested} {
	if {[llength $nested]==1} {
	    return [list [list {} $nested]]
	} else {
	    set result {}
	    foreach {indx val} $nested {
		set eltResult [Flatten $val]
		foreach pair $eltResult {
		    lappend result [list [concat [list $indx] [lindex $pair 0]] [lindex $pair 1]]
		}
	    }
	    return $result
	}
    }

    proc PokeValue {node index newVal} {
	if {[RunningInC $::myNode] && 
	    [string equal INPUT [GetModelEval $node]]} {
	    c_setparamelement $node $index $newVal
        } elseif {[llength $index]>0} {
            set vals [lindex [GetModelValue $node] 0]
	    set oddList {}
	    foreach idx $index {
		lappend oddList [expr 2*$idx-1]
	    }
	    lset vals $oddList $newVal
	    SetModelValue $node $vals
	}
    }

    proc IsNumber {str} {
        return [expr {[string is integer $str] || [string is double $str]}]
    }
    
    namespace export SetColourMap SetColours recolour_scale reposn_scale UpdateCaption ChangeEditMode InsertCaption InsertLegend ColourScale GetQuadList Flatten PokeValue IsNumber
}
