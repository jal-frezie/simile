# SetValue is called with the name of a variable node, and produces a permanent
# window, known only to Tcl, containing a slider, two buttons and a numerical entry
# field. The slider and number both connect to the same value, and twiddling either
# calls Prolog back with the new value. The buttons change the scale of the slider
# by a factor of 10.

# We also put in a square canvas above the slider which records its value.

# Show which variable being plotted in MRE JMM

set keyValue origplot72514

namespace eval ::origplot72514 {
    variable canvasMargin 5.0
    variable timeplotvars
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "Plot value against time"
    }
    
    proc initialize {windowId} {
        set ms [message $windowId.intro -text "Click on the node whose value(s) \
                you wish to plot against time."]
        pack $ms
        GrabClicks $windowId
        SetState $windowId plotThis
    }

    proc reset {winId} {
	variable timeplotvars
	AdvanceColour timeplotvars($winId,colour)
	    #		ShowMessage debug info "colour now $timeplotvars($winName,colour)" ok
	set timeplotvars($winId) {}
    }

    proc Restore {winId} {
        set name [lindex [GetState $winId] 2]
        set node [GetIdFromCaptionPath $name]
        set units [lindex [GetState $winId] 3]
        SetState $winId [list displaying $node $name $units]
        MakeTimePlot $winId $node $units
    }
    
    proc GetCanvas {winId} {
        return $winId.right.canvas
    }
    
    proc click {winId node caption} {
        if {[string compare [lindex [GetState $winId] 0] displaying]} {
            set testResult [GetModelValue $node]
            if {[string compare $testResult novalue]} {
                ReleaseClicks $winId
                pack forget $winId.intro
                # Show which variable being plotted change for MRE JMM
                if {[PrefValue custom(helperManager) helperManager]} {
                    #                ShowMessage debug info "FindHelperPage [RunEnv::FindHelperPage $winId]; Caption $caption" ok
#                    set notebookPage [RunEnv::FindHelperPage $winId]; #sdoesn't work anymore todo
#                    set notebook [lindex $notebookPage 0]
#                    set page [lindex $notebookPage 1]
                    #ShowMessage debug info "$notebook itemconfigure $page -text" ok; #" "$caption (plot against time)"
                } else  {
                    wm title $winId "$caption (plot against time)"
                }
                MakeTimePlot $winId $node real
                UpdateDisplay $winId [lindex $testResult 0] \
		    [GetModelTime]
                SetState $winId [list displaying $node \
				     [GetCaptionPathFromId $node] real]
            } else {
                $winId.intro configure -text \
                        "This component, $caption, does not have a value; please choose a compartment, variable or flow."
            }
        }
    }
    
    proc display {winId time display remainder} {
        set status [GetState $winId]
        if {[string compare [lindex $status 0] displaying] == 0} {
            UpdateDisplay $winId \
		[lindex [GetModelValue [lindex $status 1]] 0] $time
        }
    }
    
    proc clear {winId} {
        variable timeplotvars
        ClearGraph $winId
    }
    
    proc MakeTimePlot { t tree unit} {
        variable timeplotvars
        variable canvasMargin
        
        set timeplotvars(sliderLength) 30
        set timeplotvars($t,colour) blue
        set timeplotvars($t,tree) $tree
        set timeplotvars($t,unit) $unit
        set isReal [string compare $unit flag]
        set timeplotvars($t) [lindex [GetModelValue $tree] 0]
        
        frame $t.left
        frame $t.left.top
        set buttons [frame $t.left.top.buttons]
        button $buttons.clear -text Clear -command [namespace code "ClearGraph $t"]
        pack $buttons.clear -fill x
        if {$isReal} {
            button $buttons.valup -text >Var< \
                    -command [namespace code "Rescale y $t up"]
            pack $buttons.valup -fill x
            button $buttons.valdown -text <Var> \
                    -command [namespace code "Rescale y $t down"]
            pack $buttons.valdown -fill x
        } else {
            button $buttons.maketrue -text True \
                    -command [namespace code "SetBoolean $t"] \
                    -background [ChooseText $timeplotvars($t) green red]
            pack $buttons.maketrue -fill x
            button $buttons.makefalse -text False \
                    -command [namespace code  "ResetBoolean $t"] \
                    -background [ChooseText $timeplotvars($t) red green]
            pack $buttons.makefalse -fill x
        }
        button $buttons.timeup -text >Time< -command [namespace code "Rescale x $t up"]
        pack $buttons.timeup -fill x
        button $buttons.timedown -text <Time> \
                -command [namespace code "Rescale x $t down"]
        pack $buttons.timedown -fill x
        button $buttons.viewall -text "View all" \
                -command [namespace code "ViewAll $t"]
        pack $buttons.viewall -fill x
        
        pack $buttons -side left
        pack $t.left.top -fill y -expand true
        
        frame $t.left.values
        frame $t.left.values.index
        label $t.left.values.index.label -text "Index:"
        pack $t.left.values.index.label -side left
        set timeplotvars($t,showIndex) ""
        set indEnt [entry $t.left.values.index.entry -width 1 \
                -textvar [namespace current]::timeplotvars($t,showIndex)]
        bind $indEnt <Return> [namespace code "ShowIndexedValue $t"]
        pack $t.left.values.index.entry -side right -fill x -expand true
        pack $t.left.values.index -fill x
        frame $t.left.values.value
        label $t.left.values.value.label -text "Value:"
        pack $t.left.values.value.label -side left
        set timeplotvars($t,entry) $timeplotvars($t)
        entry $t.left.values.value.entry \
                -textvar [namespace current]::timeplotvars($t,entry) -width 1
        bind $t.left.values.value.entry <Return> [namespace code "UpdateModel $t"]
        pack $t.left.values.value.entry -side right -fill x -expand true
        pack $t.left.values.value -fill x
        pack $t.left.values -fill x
        pack $t.left -side left -fill y
        
        if {$isReal} {
            set timeplotvars($t,scale) [SampleFrom $timeplotvars($t)]
            if {$timeplotvars($t,scale) == 0} {
                set high_end 10.0
            } else {
                set high_end [ScaleFor $timeplotvars($t,scale)]
            }
            if {$timeplotvars($t,scale) < 0} {
                set low_end [expr -$high_end]
            } else {
                set low_end 0
            }
            set magnitude [expr $high_end - $low_end]
            set resolution [expr $magnitude/100]
            set timeplotvars($t,expectedValue) $timeplotvars($t,scale)
            scale $t.left.top.scale \
                    -variable [namespace current]::timeplotvars($t,scale) \
                    -orient vertical -showvalue false \
                    -sliderlength 2 -width 5 -borderwidth 1 \
                    -from $high_end -to $low_end \
                    -tickinterval [expr $magnitude/10] \
                    -resolution [expr $magnitude/100]
            pack $t.left.top.scale -side right -fill y -expand true
        } else {
            if {[llength $timeplotvars($t)]} {
                AlterModel $t 1
            } else {
                AlterModel $t 0
            }
            
        }
        
        frame $t.right
        scale $t.right.xscale -from 0 -to 10 \
                -variable [namespace current]::timeplotvars($t,timemark) \
                -showvalue false -sliderlength 2 -orient horizontal \
                -width 5 -tickinterval 2 -resolution 0.1 -borderwidth 1
        set canvasSide [expr 200.0+2*$canvasMargin]
        frame $t.right.spacer -width $canvasSide -height [expr 10-$canvasMargin]
        pack $t.right.spacer
        set can [canvas $t.right.canvas \
                -bg [ChooseText $isReal white yellow] \
                -width $canvasSide -height $canvasSide]
        set timeplotvars($t,lit) 0
        $can bind graph <Button-1> [namespace code "ChangeLit $t %x %y %W"]
        # To recolour on clicks that start anywhere, bind canvas not graph
        $can bind graph <B1-Motion> [namespace code "ChangeLit $t %x %y %W"]
        #	$can bind graph <ButtonRelease-1> [namespace code "UndoLit $t %x %y %W"]
        
        scrollbar $t.right.xscroll -orient horizontal \
                -command [namespace code [list ScrollMove x $t]]
        scrollbar $t.right.yscroll -orient vertical \
                -command [namespace code [list ScrollMove y $t]]
        pack $t.right.xscroll -side bottom -fill x
        pack $t.right.yscroll -side right -fill y
        $t.right.yscroll set 0.0 1.0
        pack $t.right.xscale -side bottom -fill x
        pack $can -fill both -expand true
        
        pack $t.right -side left -fill both -expand true
        bind $t <Configure> [namespace code "WhoopCanvas %W %x %y %w %h $isReal"]
        bind $t.right.canvas <Configure> [namespace code "WhoopCanvas %W %x %y %w %h $isReal"]
        
        set timeplotvars($t,width) 200.0
        set timeplotvars($t,height) 200.0
        set timeplotvars($t,early) false
        set timeplotvars($t) {}
        AddGraticule $t 10.0 $isReal 200.0
    }
    # This is the scale command. It calls it whenever it is updated, so we have to
    # check that it is a genuine drag (old value not updated) before updating the
    # model from it.
    
    proc WhoopCanvas {item x y w h isReal} {
        variable timeplotvars
        variable canvasMargin
        
        if {[regexp ^(.*)\.right\.canvas$ $item full id]} {
            #		puts "$x $y $w $h $timeplotvars($id,width) $timeplotvars($id,height)"
            set newWidth [expr $w-4.0-2*$canvasMargin]
            $item scale all [expr $canvasMargin+2.0] 0 \
                    [expr $newWidth/$timeplotvars($id,width)] 1.0
            set newHeight [expr $h-4.0-2*$canvasMargin]
            if {$isReal} {
                $item scale all 0 [expr $canvasMargin+2.0] \
                        1.0 [expr $newHeight/$timeplotvars($id,height)]
            } else {
                $item move all 0 [expr $newHeight-$timeplotvars($id,height)]
            }
            set timeplotvars($id,width) $newWidth
            set timeplotvars($id,height) $newHeight
            UpdateSlider $id
        }
    }
    
    proc AddGraticule {t scale isReal drawHeight} {
        variable canvasMargin
        
        set verticalDensity [expr $isReal?10:4]
        set verticalIncrement [expr $drawHeight/$verticalDensity]
        set lineHeight [expr $canvasMargin + 2.0 + ($isReal?0:-0.875*$drawHeight)]
        set ylevel $lineHeight
        set highBound [expr $drawHeight+$canvasMargin+2.0]
        while {$ylevel <= $highBound} {
            $t.right.canvas create line [expr $canvasMargin+2.0] $ylevel \
                    $highBound $ylevel -fill gray -tags grid
            set ylevel [expr $ylevel + $verticalIncrement]
        }
        set currentNumber 0
        set scaleInterval [expr $scale/10]
        while {$currentNumber <= $scale} {
            set lineOffset [expr $canvasMargin + 2.0 + $currentNumber*$drawHeight/$scale]
            $t.right.canvas create line $lineOffset $lineHeight \
                    $lineOffset $highBound \
                    -fill gray -tags grid
            #		$t.right.canvas create text $lineOffset $drawHeight -text $currentNumber \
            #			-anchor n -font system -tags scale
            set currentNumber [expr $currentNumber + $scaleInterval]
        }
    }
    
    proc ClearGraph {winName} {
        variable timeplotvars
        
        set canvas $winName.right.canvas
        $canvas delete graph
        set timeplotvars($winName,colour) blue
    }
    
    proc MoveGraph {winName fraction} {
        variable timeplotvars
        $winName.right.canvas move graph 0 \
                [expr $fraction*$timeplotvars($winName,height)]
    }
    
    proc Rescale {axis winName direction} {
        variable timeplotvars
        
        if {[string compare $axis x]} {
            set scale $winName.left.top.scale
        } else {
            set scale $winName.right.xscale
        }
        
        set oldFrom [$scale cget -from]
        set oldTo [$scale cget -to]
        set old_mag [expr abs($oldFrom - $oldTo)]
        set new_mag [jiggle $old_mag $direction]
        set factor [expr $new_mag/$old_mag]
        
        if {! $oldTo} {
            set newFrom [expr $oldFrom*$factor]
            set newTo 0
        } else {
            if {! $oldFrom} {
                set newTo [expr $oldTo*$factor]
                set newFrom 0
            } else {
                set midPt [expr ($oldFrom+$oldTo)/2]
                set newFrom [expr $midPt + $factor*($oldFrom - $midPt)]
                set newTo [expr $midPt + $factor*($oldTo - $midPt)]
            }
        }
        
        AdjustGraph $axis $winName $oldFrom $oldTo $newFrom $newTo
    }
    
    proc AdjustGraph {axis winName oldFrom oldTo newFrom newTo} {
        variable timeplotvars
        variable canvasMargin
        
        set resolution [expr ($newFrom-$newTo)/100]
        set target [SampleFrom $timeplotvars($winName,entry)]
        if {[string compare $axis x]} {
            set timeplotvars($winName,expectedValue) $target
            if {$target>$newFrom} {
                set timeplotvars($winName,expectedValue) $newFrom
            }
            if {$target<$newTo} {
                set timeplotvars($winName,expectedValue) $newTo
            }
            set scale $winName.left.top.scale
            set listSlot 3
            set oldDim $timeplotvars($winName,height)
            set tickDensity 10
        } else {
            set scale $winName.right.xscale
            set listSlot 2
            set oldDim $timeplotvars($winName,width)
            #		foreach object [$winName.right.canvas find withtag scale] {
            #			set oldVal [$winName.right.canvas itemcget $object -text]
            #			set fract [expr ($oldVal - $oldFrom)/($oldTo-$oldFrom)]
            #			set newVal [expr $newFrom + $fract*($newTo - $newFrom)]
            #			$winName.right.canvas itemconfigure $object -text $newVal
            #		}
            set tickDensity 5
        }
        $scale configure -from $newFrom
        $scale configure -to $newTo
        $scale configure -tickinterval [expr ($newFrom-$newTo)/$tickDensity]
        $scale configure -resolution $resolution
        
        # If value was outside previous scale range, move toward it if poss
        set timeplotvars($winName,scale) $target
        
        set newSpan [expr 1.0*$newFrom-$newTo]
        set factor [expr $newSpan/($oldFrom-$oldTo)]
        
        set baseLine [expr $canvasMargin + 2.0]
        eval {$winName.right.canvas scale graph} \
                [lreplace [list $baseLine $baseLine 1.0 1.0] \
                $listSlot $listSlot [expr 1.0/$factor]]
        
        set listSlot [expr $listSlot - 2]
        set currentTo [expr $oldFrom - ($oldFrom-$oldTo)*$factor]
        set displace [expr ($newTo-$currentTo)*$oldDim/$newSpan]
        eval {$winName.right.canvas move graph} [lreplace [list 0 0] \
                $listSlot $listSlot $displace]
        
        UpdateSlider $winName
    }
    
    proc ValueFor {winName canvasPoint} {
        variable timeplotvars
        set scale $winName.left.top.scale
        set screenWorth [expr [$scale cget -from] - [$scale cget -to]]
        return [expr (1 - $canvasPoint/$timeplotvars($winName,height))*screenWorth]
    }
    
    proc ScrollMove {axis winName action jump args} {
        
        if {[string compare $axis x]} {
            set scale $winName.left.top.scale
        } else {
            set scale $winName.right.xscale
        }
        set oldFrom [$scale cget -from]
        set oldTo [$scale cget -to]
        set range [expr $oldTo-$oldFrom]
        set pair [$winName.right.${axis}scroll get]
        set base [lindex $pair 0]
        set span [expr [lindex $pair 1]-$base]
        if {!$span} {set span 1}
        #	set max [expr -$range*$base/$span]
        #	set min [expr $range*(1 - ($base + $span))/$span]
        if {[string compare $action scroll] == 0} {
            if {[string compare $args units] == 0} {
                set quantum [expr $jump*$range/10]
            } else {
                set quantum [expr $jump*$range]
            }
        } else {
            
            set screens [expr ($jump-$base)/$span]
            set quantum [expr int(10*$screens)*$range/10.0]
        }
        #	if {$quantum < $min} {set quantum $min}
        #	if {$quantum > $max} {set quantum $max}
        
        AdjustGraph $axis $winName $oldFrom $oldTo [expr $oldFrom+$quantum] \
                [expr $oldTo+$quantum]
    }
    
    proc ViewAll {winName} {
        variable timeplotvars
        if {[scan [$winName.right.canvas bbox graph] {%d %d %d %d} \
                    left top right bottom] == 4} {
            set lowVal [$winName.right.xscale cget -from]
            set highVal [$winName.right.xscale cget -to]
            set gsize $timeplotvars($winName,width)
            set realLowest [expr $lowVal + ($highVal - $lowVal)*$left/$gsize]
            set realHighest [expr $lowVal + ($highVal - $lowVal)*$right/$gsize]
            set span [ScaleFor [expr $realHighest-$realLowest]]
            set base [expr floor($realLowest*10/$span)*$span/10]
            AdjustGraph x $winName $lowVal $highVal $base [expr $base+$span]
            
            set lowVal [$winName.left.top.scale cget -from]
            set highVal [$winName.left.top.scale cget -to]
            set gsize $timeplotvars($winName,height)
            set realLowest [expr $lowVal + ($highVal - $lowVal)*$bottom/$gsize]
            set realHighest [expr $lowVal + ($highVal - $lowVal)*$top/$gsize]
            set span [ScaleFor [expr $realHighest-$realLowest]]
            set base [expr floor($realLowest*10/$span)*$span/10]
            AdjustGraph y $winName $lowVal $highVal [expr $base+$span] $base
        }
    }
    
    proc UpdateSlider {winName} {
        variable timeplotvars
        set canvas $winName.right.canvas
        if {[scan [$canvas bbox graph] {%d %d %d %d} left top right bottom] == 4} {
            set lowend [expr (0.0-$top)/($bottom-$top)]
            set highend [expr ($timeplotvars($winName,height)-$top)/($bottom-$top)]
            $winName.right.yscroll set $lowend $highend
            set lowend [expr (0.0-$left)/($right-$left)]
            set highend [expr ($timeplotvars($winName,width)-$left)/($right-$left)]
            $winName.right.xscroll set $lowend $highend
        }
    }
    
    proc jiggle {mag direction} {
        if {[string compare $direction down]} {
            set midpoint [expr $mag*1.5]
        } else {
            set midpoint [expr $mag/3.0]
        }
        return [ScaleFor $midpoint]
    }
    
    proc ScaleFor {value} {
        set magnitude [expr pow(10,ceil(log10(abs($value))))]
        set fraction [expr abs($value)/$magnitude]
        set scale $magnitude
        foreach multiplier {0.5 0.2} {
            if {$multiplier >= $fraction} {
                set scale [expr $magnitude*$multiplier]
            }
        }
        return $scale
    }
    
    proc UpdateDisplay {winName value time} {
        variable timeplotvars
        
        # destroy the window if its node no longer sends a value
        if {![string compare $value novalue]} {
            kill_helper_window $winName
            return
        }
        
        set can $winName.right.canvas
        
        set isReal [string compare $timeplotvars($winName,unit) flag]
        
        if {[llength $timeplotvars($winName)] && [llength $value] && \
		[string compare $time false]} {
	    if {$isReal} {
		PlotFloats $value $timeplotvars($winName) $time \
		    $timeplotvars($winName,early) $winName $can index black
	    } else {
		set theight [expr $timeplotvars($winName,height)-45]
		set fheight [expr $timeplotvars($winName,height)-5]
		$can create line \
		    $timeplotvars($winName,early) \
		    [expr $timeplotvars($winName)?$theight:$fheight] \
		    $timeplotvars($winName,early) \
		    [expr $value?$theight:$fheight] \
		    $time \
		    [expr $value?$theight:$fheight] -tags graph
	    }
	}
        if {$isReal} {
            set timeplotvars($winName,scale) [SampleFrom $timeplotvars($winName,entry)]
            set timeplotvars($winName,expectedValue) $timeplotvars($winName,scale)
        } else {
            $winName.left.top.buttons.maketrue configure -background \
                    [ChooseText $value green red]
            $winName.left.top.buttons.makefalse configure -background \
                    [ChooseText $value red green]
        }
        set timeplotvars($winName) $value
        if [string compare $time false] {
            if {[string compare $timeplotvars($winName,early) false] && \
                        (! $isReal) && ($time < $timeplotvars($winName,early))} {
                $can move graph 0 -50
            }
            set timeplotvars($winName,early) $time
            set timeplotvars($winName,timemark) $time
        }
    }
    
    proc AdvanceColour {colref} {
        upvar 1 $colref col
        set cols {blue orange green brown purple red}
        set ind [lsearch $cols $col]
        set next [expr $ind==5?0:$ind+1]
        set col [lindex $cols $next]
    }
    
    proc PlotFloats {newVal oldVal newX oldX winName can chain plotColor} {
        variable timeplotvars
        
        if {![string compare [string range $chain 6 end] \
                    $timeplotvars($winName,showIndex)]} {
            if [string compare [focus] $winName.left.values.value.entry] {
                set timeplotvars($winName,entry) $newVal
            }
            set plotColor $timeplotvars($winName,colour)	}
        
        if {[llength $newVal] == 1} {
            # puts "exp at plot $timeplotvars($winName,expectedValue)"
            set scale $winName.left.top.scale
            set highEnd [$scale cget -from]
            set lowEnd [$scale cget -to]
            set scale $winName.right.xscale
            set lowSide [$scale cget -from]
            set highSide [$scale cget -to]
            
            $can create line \
                    [point $oldX $timeplotvars($winName,width) $lowSide $highSide] \
                    [point $oldVal $timeplotvars($winName,height) $highEnd $lowEnd] \
                    [point $newX $timeplotvars($winName,width) $lowSide $highSide] \
                    [point $newVal $timeplotvars($winName,height) $highEnd $lowEnd] \
                    -fill $plotColor -tags [list graph $chain]
            
            if {$lowEnd > $newVal} {
                set newSpan [ScaleFor [expr $highEnd-$newVal]]
                set newHigh [expr $newSpan*ceil(10.0*$highEnd/$newSpan)/10]
                set newLow [expr $newHigh-$newSpan]
                
                AdjustGraph y $winName $highEnd $lowEnd $newHigh $newLow
            }
            if {$newVal > $highEnd} {
                set newSpan [ScaleFor [expr $newVal-$lowEnd]]
                #			puts $newSpan
                set newLow [expr $newSpan*floor(10.0*$lowEnd/$newSpan)/10]
                set newHigh [expr $newLow+$newSpan]
                
                AdjustGraph y $winName $highEnd $lowEnd $newHigh $newLow
            }
            if {$newX > $highSide} {
                set newSpan [ScaleFor [expr $newX-$lowSide]]
                set newLow [expr $newSpan*floor(10.0*$lowSide/$newSpan)/10]
                set newHigh [expr $newLow+$newSpan]
                
                AdjustGraph x $winName $lowSide $highSide $newLow $newHigh
            }
            if {$newX < $lowSide} {
                set newSpan [expr $highSide-$lowSide]
                set newLow [expr $newSpan*floor(10.0*$newX/$newSpan)/10]
                set newHigh [expr $newLow+$newSpan]
                
                AdjustGraph x $winName $lowSide $highSide $newLow $newHigh
            }
        } else {
            array set oldValArray $oldVal
            array set newValArray $newVal
            foreach index [array names newValArray] {
                if {[info exists oldValArray($index)]} {
                    PlotFloats $newValArray($index) $oldValArray($index) \
                            $newX $oldX $winName $can [concat $chain $index] \
                            $plotColor
                }
            }
        }
    }
    
    proc SetLit {win x y can} {
        #	puts "set $x $y"
        variable timeplotvars
        set timeplotvars($win,lit) [$can find closest $x $y]
        set timeplotvars($win,showIndex) \
                [LightLine $can $timeplotvars($win,lit) $timeplotvars($win,colour)]
        set timeplotvars($win,entry) [ExtractLatest $timeplotvars($win) \
                $timeplotvars($win,showIndex)]
    }
    
    proc ChangeLit {win x y can} {
        #	puts "change $x $y"
        variable timeplotvars
        LightLine $can $timeplotvars($win,lit) black
        set timeplotvars($win,lit) [$can find closest $x $y]
        set timeplotvars($win,showIndex) \
                [LightLine $can $timeplotvars($win,lit) $timeplotvars($win,colour)]
        set timeplotvars($win,entry) [ExtractLatest $timeplotvars($win) \
                $timeplotvars($win,showIndex)]
    }
    
    proc UndoLit {win x y can} {
        #	puts "undo $x $y"
        variable timeplotvars
        LightLine $can $timeplotvars($win,lit) black
    }
    
    proc LightLine {can obj col} {
        #	puts "light $can $obj $col"
        foreach idtag [$can gettags $obj] {
            if {![string first index $idtag]} {
                #			puts $idtag
                foreach segment [$can find withtag $idtag] {
                    $can itemconfigure $segment -fill $col
                }
                return [string range $idtag 6 end]
            }
        }
    }
    
    proc ShowIndexedValue {win} {
        variable timeplotvars
        set timeplotvars($win,entry) \
                [ExtractLatest $timeplotvars($win) $timeplotvars($win,showIndex)]
    }
    
    proc ExtractLatest {value index} {
        if {![llength $index]} {
            return $value
        } else {
            array set spare $value
            if {[info exists spare([lindex $index 0])]} {
                return [ExtractLatest $spare([lindex $index 0]) \
                        [lrange $index 1 end]]
            }
        }
    }
    
    proc point {val winSize low high} {
        variable canvasMargin
        return [expr $canvasMargin + 2.0 + $winSize*($val-$low)/($high-$low)]
    }
    
} ;# end of namespace
