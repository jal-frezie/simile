# grid4 == grid3.tcl modified by Jasper for photo image type
# grid5 == grid4.tcl modified by Robert for more compact, more
#          professional-looking display

# grid3.tcl		--	Robert Muetzelfeldt   10 August 2000
# SimCity-style spatial grid display

set keyValue grid005
namespace eval grid005 {
    
    variable useNodes
    variable cell_ids
    variable old_icolour
    variable min; # edit var for entry widget
    variable max; # edit var for entry widget
    
    
    proc identify {} {
        return "Spatial grid display"
    }
    
    proc initialize {winId} {
        variable useNodes
        namespace import -force ::maptools2::*
        set useNodes($winId,cbot) black
        set useNodes($winId,cmid) red
        set useNodes($winId,ctop) white
        set useNodes($winId,nswatches) 32
        set useNodes($winId,integer) 0
        set useNodes($winId,freeze) false
        set useNodes($winId,min) 0
        set useNodes($winId,max) 100
        SetState $winId {}
        AddToolbar $winId
        set NToolButtons [$winId.bbframe.buttonBox index last]
        for {set i 1} {$i<=$NToolButtons} {incr i} {
            $winId.bbframe.buttonBox itemconfigure $i -state disable
        }
        SetColours useNodes $winId
        if {[string match $winId [winfo toplevel $winId]]} {
            wm geometry $winId 500x500
        }
        
    }

    proc reset {winId} {
    }

    proc AddToolbar {winId} {
        set toolbarItems [list \
                [list add.gif "Add a variable"   [namespace code "AddVariable $winId"]]\
                [list zoomin.gif "Zoom in" [namespace code "zoomio $winId 1.25"] ]\
                [list zoomout.gif "Zoom out" [namespace code "zoomio $winId 0.8"] ]\
                [list property.gif " Properties " [namespace code "Settings $winId"]]\
                [list less.gif "Decrease range" [namespace code "DecreaseRange $winId"] ]\
                [list greater.gif "Increase range" [namespace code "IncreaseRange $winId"] ]\
                [list pause.gif " Freeze " [namespace code "ToggleFreeze $winId"]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
    }
    
    proc AddVariable {winId} {
        set ms [message $winId.intro -text \
                "Click on the variable containing the positions or IDs of the columns."]
        GrabClicks $winId
        pack $ms
        $winId.bbframe.buttonBox itemconfigure 0 -state disable; #disable the add var button
        SetState $winId display0
    }
    
    proc Recolour {winId whichCol exampleWidget} {
        variable useNodes
        set colour [tk_chooseColor -initialcolor $useNodes($winId,c$whichCol)]
        $exampleWidget configure -bg $colour
        return $colour
    }
    
    proc Restore {winId} {
        variable useNodes
        namespace import -force ::maptools2::*
	set state [GetState $winId]
# looks like "displaying %s %s colourmap %s %s %s aspect %d %g %g"
	set useNodes($winId,display1) [GetIdFromCaptionPath [lindex $state 1]]
	set useNodes($winId,colvals) [GetIdFromCaptionPath [lindex $state 2]]
	set colourBase [lsearch $state colourmap]
	foreach colourPt {cbot cmid ctop} {
	    set useNodes($winId,$colourPt) [lindex $state [incr colourBase]]
	}
	set rangeBase [lsearch $state aspect]
	foreach rangePt {nswatches min max} {
	    set useNodes($winId,$rangePt) [lindex $state [incr rangeBase]]
	}
        set useNodes($winId,caption) [lindex $state 1]
        
        SetColours useNodes $winId
        AddToolbar $winId
        $winId.bbframe.buttonBox itemconfigure 0 -state disable
	NumDistinct $winId [GetModelValue $useNodes($winId,colvals)]
        InitialiseGrid $winId $useNodes($winId,display1)
        set useNodes($winId,freeze) false
    }
    
    proc GetCanvas {winId} {
        return $winId.c
    }
    
    proc click {winId node caption} {
        variable useNodes
        
        set ms $winId.intro
        set testResult [GetModelValue $node]
        if {[string compare $testResult novalue]} {
            set state [GetState $winId]
            switch $state {
                display0 {
                    NumDistinct $winId $testResult
		    set useNodes($winId,colvals) $node
		    $ms configure -text "Grid currently has $useNodes($winId,ncol) columns and $useNodes($winId,nrow) rows. Now click on the variable to be displayed."
                    SetState $winId display1
                } display1 {
                    pack forget $ms
                    ReleaseClicks $winId
                    set useNodes($winId,display1) $node

		    set min [GetMinValue $node]
		    if {$min!=-1e100} {
			set useNodes($winId,min) $min
		    }
		    set max [GetMaxValue $node]
		    if {$max!=1e100} {
			set useNodes($winId,max) $max
		    }
                    catch {wm title $winId $caption}
                    InitialiseGrid $winId $node
                    UpdateState $winId
                    destroy $winId.intro
                    set NToolButtons [$winId.bbframe.buttonBox index last]
                    for {set i 1} {$i<=$NToolButtons} {incr i} {
                        $winId.bbframe.buttonBox itemconfigure $i -state normal
                    }
                    raise $winId
                }
            }
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc NumDistinct {winId testResult} {
	variable useNodes

	set columns [Flatten [lindex $testResult 0] {}]
	foreach col $columns {
	    set colvals($col) 1
	}
	if {[info exists colvals()]} {
	    unset colvals()
	}
	set useNodes($winId,ncol) [array size colvals]
	set useNodes($winId,nrow) \
	    [expr {[llength $columns]/$useNodes($winId,ncol)}]
    }

    proc UpdateState {winId} {
        variable useNodes
        SetState $winId [list displaying \
                [GetCaptionPathFromId $useNodes($winId,display1)] \
		[GetCaptionPathFromId $useNodes($winId,colvals)] colourmap \
                $useNodes($winId,cbot) $useNodes($winId,cmid) $useNodes($winId,ctop) \
                aspect $useNodes($winId,nswatches)\
                $useNodes($winId,min) $useNodes($winId,max)]
        
    }
    
    proc display {winId time step remainder} {
        variable useNodes
        if {[string match [lindex [GetState $winId] 0] displaying] && \
                    !$useNodes($winId,freeze)} then {
	    if {!$time} {
		NumDistinct $winId [GetModelValue $useNodes($winId,colvals)]
	    }
            DrawGrid5 $winId $useNodes($winId,display1)
            FillCanvas $winId
            UpdateCaption $winId
        }
    }
    
    proc InitialiseGrid {winId display1} {
        variable useNodes
        
        frame $winId.f
        scrollbar $winId.hscroll -orient horiz -command "$winId.c xview"
        scrollbar $winId.vscroll -command "$winId.c yview"
        canvas $winId.c \
                -relief sunken \
                -borderwidth 2 \
                -xscrollcommand [namespace code "ScrollPhoto $winId h"] \
                -yscrollcommand [namespace code "ScrollPhoto $winId v"]
        pack $winId.f -expand yes -fill both -padx 1 -pady 1
        grid rowconfig    $winId.f 0 -weight 1 -minsize 0
        grid columnconfig $winId.f 0 -weight 1 -minsize 0
        
        grid $winId.c -padx 1 -in $winId.f -pady 1 \
                -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
        grid $winId.vscroll -in $winId.f -padx 1 -pady 1 \
                -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
        grid $winId.hscroll -in $winId.f -padx 1 -pady 1 \
                -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
        
        if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
            set n $useNodes($winId,nrow)
        } else {
            set n $useNodes($winId,ncol)
        }
        
        set mult [expr {int(380/$n)}]
	if {$mult<2} {
	    set mult 1
	    $winId.bbframe.buttonBox itemconfigure 2 -state disable
	}
        set useNodes($winId,mult) $mult
        set xwidth [expr {$mult*$useNodes($winId,ncol)}]
        set yheight [expr {$mult*$useNodes($winId,nrow)+20}]
        set useNodes($winId,xwidth) $xwidth
        set useNodes($winId,yheight) $yheight
        $winId.c configure -width $xwidth -height $yheight
        
        $winId.c bind all <Button-3> [namespace code "Settings $winId"]
        $winId.c bind all <B1-Motion> [namespace code "value_popup $winId %X %Y %x %y"]
        $winId.c bind all <ButtonPress-1> [namespace code "value_popup $winId %X %Y %x %y"]
        $winId.c bind all <B1-ButtonRelease> [namespace code "RemovePopup"]
        
        set useNodes($winId,hiddenMap) [image create photo]
        set useNodes($winId,visibleMap) [image create photo]
        $winId.c create image 0 0 -anchor nw -image $useNodes($winId,visibleMap)
        
        DrawGrid5 $winId $display1
#        $winId.c configure -scrollregion [$winId.c bbox all]
    }
    
    proc recolour_scale {winId} {
        variable useNodes
        
        #ShowMessage debug info "recolour_scale " ok
        $winId.c delete colour_scale
        if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
            set n $useNodes($winId,nrow)
        } else {
            set n $useNodes($winId,ncol)
        }
        set leftSc [$winId.c canvasx 0]
        set rightSc [$winId.c canvasx [winfo width $winId.c]]
        set bottomSc [$winId.c canvasy [winfo height $winId.c]]
        set topSc [expr $bottomSc-40]
        set midSc [expr $bottomSc-20]
        
        # blank over bottom of display
        $winId.c create rect $leftSc $topSc $rightSc $bottomSc \
                -outline {} -fill [$winId.c cget -bg] -tag colour_scale
        $winId.c create text [expr ($leftSc+$rightSc)/2] [expr $bottomSc-30] \
                -anchor c -tag {colour_scale caption}
        UpdateCaption $winId
        $winId.c create text [expr $leftSc+47] [expr $bottomSc-10] \
                -text $useNodes($winId,min) -anchor e -tag colour_scale
        $winId.c create text [expr $rightSc-48] [expr $bottomSc-10] \
                -text $useNodes($winId,max) -anchor w -tag colour_scale
        
        set xmin [expr $leftSc+50]
        set xmax [expr $rightSc-50]
        set xincr [expr {($xmax-$xmin)/33}]
        for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
            set x0 [expr {$xmin+$icolour*$xincr}]
            set x1 [expr {$x0+$xincr}]
            set colour $useNodes($winId,c$icolour)
            $winId.c create rectangle $x0 $midSc $x1 $bottomSc \
                    -outline {} -fill $colour -tag colour_scale
        }
        
    }
    
    proc UpdateCaption {winId} {
        variable useNodes
        $winId.c itemconfig caption -text "[file tail [GetCaptionPathFromId $useNodes($winId,display1)]] ($useNodes($winId,ncol)x$useNodes($winId,nrow), time = [GetModelTime])"
    }
    
    proc ToggleFreeze {winId} {
        variable useNodes
        if {$useNodes($winId,freeze)} {
            set useNodes($winId,freeze) false
            $winId.bbframe.buttonBox itemconfigure end -relief flat; #disable the add var button
        } else  {
            set useNodes($winId,freeze) true
            $winId.bbframe.buttonBox itemconfigure end -relief sunken; #disable the add var button
        }
    }
    
    proc IncreaseRange {winId} {
        variable useNodes
        
        DataMinMax $winId datamin datamax
        set useNodes($winId,min) [expr {$useNodes($winId,min)*10}]
        set useNodes($winId,max) [expr {$useNodes($winId,max)*10}]
        SetColours useNodes $winId
        recolour_scale $winId
        UpdateState $winId
        display $winId 0 0 0
    }
    
    proc DecreaseRange {winId} {
        variable useNodes
        set useNodes($winId,min) [expr {0.1*$useNodes($winId,min)}]
        set useNodes($winId,max) [expr {0.1*$useNodes($winId,max)}]
        SetColours useNodes $winId
        recolour_scale $winId
        UpdateState $winId
        display $winId 0 0 0
    }

    proc Settings {winId} {
        variable useNodes
        variable min
        variable max
        set dlg [Dialog .gridprop -parent $winId -title "Grid display properties" \
                -modal local -default 0 -cancel 1]
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
        set coloursF [labelframe [$dlg getframe].colours -text "Colour scale"]
        pack [LabelFrame $coloursF.lowcolourF -text "Low colour"] -fill x  -padx 10
        frame $coloursF.lowcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cbot)
        pack [button $coloursF.lowcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId bot $coloursF.lowcolourF.colF"]] -side right
        pack $coloursF.lowcolourF.colF -side right -padx 10
        
        pack [LabelFrame $coloursF.midcolourF -text "Middle colour"] -fill x -padx 10
        frame $coloursF.midcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cmid)
        pack [button $coloursF.midcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId mid $coloursF.midcolourF.colF"]] -side right
        pack $coloursF.midcolourF.colF -side right -padx 10
        
        pack [LabelFrame $coloursF.topcolourF -text "High colour"] -fill x -padx 10
        frame $coloursF.topcolourF.colF -width 20 -height 15 -bg $useNodes($winId,ctop)
        pack [button $coloursF.topcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId top $coloursF.topcolourF.colF"]] -side right
        pack $coloursF.topcolourF.colF -side right -padx 10
        
        pack $coloursF -padx 10 -pady 10 -fill x
        
        set rangeF [labelframe [$dlg getframe].range -text "Scale range"]
        DataMinMax $winId datamin datamax
        pack [label $rangeF.dataminL -text "Data min. so far: $datamin"] -fill x  -padx 10
        pack [label $rangeF.datamaxL -text "Data max. so far: $datamax"] -fill x  -padx 10
        pack [LabelFrame $rangeF.minF -text "Min"] -fill x  -padx 10 -pady 5
        pack [entry $rangeF.minF.entry -textvar [namespace current]::min($winId) -width 20] -side right -padx 10
        pack [LabelFrame $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [entry $rangeF.maxF.entry -textvar [namespace current]::max($winId) -width 20] -side right -padx 10
        pack $rangeF -padx 10 -pady 10
        
        $dlg add -name ok \
                -command [namespace code "OnClickSettingOkBtn $winId $coloursF $rangeF $dlg"]; # buttons 0
        $dlg add -name cancel -command "$dlg enddialog 1"
        $dlg draw; # waits for a button to be clicked. Button command must call $dlg enddialog _result_
        destroy $dlg
    }
    
    proc OnClickSettingOkBtn {winId coloursF rangeF dlg} {
        
        variable useNodes
        variable min
        variable max
        
        # copy the values from the temp values to those to be edited if OK clicked
        set useNodes($winId,ctop) [$coloursF.topcolourF.colF cget -bg]
        set useNodes($winId,cmid) [$coloursF.midcolourF.colF cget -bg]
        set useNodes($winId,cbot) [$coloursF.lowcolourF.colF cget -bg]
        if {[IsNumber $min($winId)]} {
            set useNodes($winId,min) $min($winId)
        } else  {
            ShowMessage Error error "Value must be a number." ok
            $rangeF.minF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
        }
        if {[IsNumber $max($winId)]} {
            set useNodes($winId,max) $max($winId)
        } else  {
            ShowMessage Error error "Value must be a number." ok
            $rangeF.maxF.entry selection range 0 end
            focus $rangeF.maxF.entry
            return
        }
        $dlg enddialog 0
        SetColours useNodes $winId
        recolour_scale $winId
        UpdateState $winId
        display $winId 0 0 0
    }
    
    
    proc DataMinMax {winId dmin dmax} {
        upvar $dmin datamin
        upvar $dmax datamax
        
        variable useNodes
        
        set datamin 1e100
        set datamax 1e-100
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set values $useNodes($winId,values)
        
        for {set row 1} {$row<=$nrow} {incr row} {
            set rowData($row) {}
            for {set col 1} {$col<=$ncol} {incr col} {
                set cell [expr ($row-1)*$ncol+$col-1]
                set celval [lindex $values $cell]
                set length [llength $celval]
                
                if {$length} {
                    if {$length>1} {set celval [lindex $celval 1]}
                    if {$celval>$datamax} {
                        set datamax $celval
                    } elseif {$celval<$datamin} {
                        set datamin $celval
                    }
                }
            }
        }
        
    }
    
    proc click_cell {winId c} {
        variable useNodes
        bell
        $c itemconfigure current -fill red
        set tags [$c gettags current]
        $c create text 250 180 -text "TAGS $tags"
        set cell [string range $tags 4 [expr {[string first " " $tags]-1}]]
        $c create text 250 200 -text "xxx $cell xxx"
        set cella [expr {$cell*2}]
        $c create text 250 210 -text $cella
        
        set dis1 $useNodes($winId,display1)
        set display1 [lindex [GetModelValue $dis1] 0]
        set this_colour [expr {int([lindex $display1 [expr $cell*2-1]])}]
        $c create text 250 230 -text "xx $this_colour xx"
    }
    
    
    
    
    proc DrawGrid5 {winId node} {
        variable useNodes
        
        set values [Flatten [lindex [GetModelValue $node] 0] {}]
        set useNodes($winId,values) $values
        
        set ncell [llength $values]
        
        # Data must be from a singly-nested fixed membership model,
        # or an indexless conditional model inside one
        # Note: tried to optimise (e.g. by use of holding variables for array
        # elements), since this is the time-critical part.
        
        set allData {}
        set min $useNodes($winId,min)
        set range [expr $useNodes($winId,max)-$useNodes($winId,min)]
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set nswatches $useNodes($winId,nswatches)
        
        for {set row 1} {$row<=$nrow} {incr row} {
            set rowData($row) {}
            for {set col 1} {$col<=$ncol} {incr col} {
                set cell [expr ($row-1)*$ncol+$col-1]
                set celval [lindex $values $cell]
                set length [llength $celval]
                
                if {$length} {
                    if {$length>1} {set celval [lindex $celval 1]}
                    if [catch {set icolour [expr {int($nswatches*($celval-$min)/$range)}]}] {
                        return
                    }
                    
                    if {$icolour < 1} {
                        set icolour 1
                    } elseif {$icolour > $nswatches} {
                        set icolour $nswatches
                    }
                    lappend rowData($row) $useNodes($winId,c$icolour)
                } else {
                    lappend rowData($row) grey
                }
            }
        }
        
        for {set row $nrow} {$row>=1} {incr row -1} {
            lappend allData $rowData($row)
        }
        
        $useNodes($winId,hiddenMap) put $allData
    }
    
    proc zoomio {winId factor} {
        variable useNodes
        set view [$winId.c xview]
        set xmiddle [expr ([lindex $view 0]+[lindex $view 1])/2]
        set view [$winId.c yview]
        set ymiddle [expr ([lindex $view 0]+[lindex $view 1])/2]
        set next [expr round($factor*$useNodes($winId,mult))]
        if {$next==$useNodes($winId,mult)} {
            if $factor>1 {
                incr useNodes($winId,mult)
            } else {
                incr useNodes($winId,mult) -1
            }
        } else {
            set useNodes($winId,mult) $next
        }
        if {$useNodes($winId,mult)==1} {
            $winId.bbframe.buttonBox itemconfigure 2 -state disable
            # disable zoom out button
        } else {
            $winId.bbframe.buttonBox itemconfigure 2 -state normal
        }
        
        $winId.c configure -scroll "0 0 \
                [expr $useNodes($winId,ncol)*$useNodes($winId,mult)] \
                [expr $useNodes($winId,nrow)*$useNodes($winId,mult)+40]"
        set view [$winId.c xview]
        $winId.c xview moveto [expr $xmiddle-([lindex $view 1]-[lindex $view 0])/2]
        set view [$winId.c yview]
        $winId.c yview moveto [expr $ymiddle-([lindex $view 1]-[lindex $view 0])/2]
    }
    
    proc ScrollPhoto {winId axis args} {
        #	puts $visible
        if {[string match h $axis]} {
            FillCanvas $winId
        }
        eval {$winId.${axis}scroll set} $args
        recolour_scale $winId
    }
    
    proc FillCanvas {winId} {
        variable useNodes
        
        set visible [concat [$winId.c xview] [$winId.c yview]]
        set dataL [expr [lindex $visible 0]*$useNodes($winId,ncol)]
        set dataR [expr int(ceil([lindex $visible 1]*$useNodes($winId,ncol)))]
        set dataT [expr [lindex $visible 2]*$useNodes($winId,nrow)]
        set dataB [expr int(ceil([lindex $visible 3]*$useNodes($winId,nrow)))]
        $winId.c coords 1 \
	    [$winId.c canvasx [expr -fmod($dataL,1)*$useNodes($winId,mult)]] \
	    [$winId.c canvasy [expr -fmod($dataT,1)*$useNodes($winId,mult)]]
#puts "Displaying $dataL $dataT $dataR $dataB"
        $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
	    -from [expr int($dataL)] [expr int($dataT)] $dataR $dataB -to 0 0 \
                -zoom $useNodes($winId,mult) -shrink
    }
    
    #### Handle value popup
    proc value_popup {winId X Y x y} {
        variable useNodes
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set col [expr int(1+([$winId.c canvasx $x])/$useNodes($winId,mult))]
        set row [expr int(1+$nrow-([$winId.c canvasy $y])/$useNodes($winId,mult))]
        if {$row>0&&$row<=$nrow&&$col>0&&$col<=$ncol} {
            if {![winfo exists .popup]} {
                toplevel .popup -width 1 -height 1 -bd 2 -relief raised
                wm overrideredirect .popup 1
                pack [message .popup.message -aspect 400 -bg \#ffffc0] \
                        -fill x -expand true
                raise .popup
            }
            set cell [expr ($row-1)*$ncol+$col-1]
            set value [lindex $useNodes($winId,values) $cell]
            set index [expr $cell+1]
            
            .popup.message config -text "Index=$index\nCol,row=($col,$row)\nValue=$value"
            set xpoint [expr $X+15]
            set ypoint [expr $Y+43]
            wm geometry .popup +$xpoint+$ypoint
            update
        }
    }
    
    proc RemovePopup {} {
        if {[winfo exists .popup]} {
            destroy .popup
        }
    }
    
    # need to recode for this legend
    proc ColourScale {winData winId} {
        #    ShowMessage debug info "proc ColourScale" ok
        upvar 1 $winData useNodes
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            $winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
        }
    }
    
} ;
# end of namespace
