# grid4 == grid3.tcl modified by Jasper for photo image type
# grid5 == grid4.tcl modified by Robert for more compact, more
#          professional-looking display

# grid3.tcl		--	Robert Muetzelfeldt   10 August 2000
# SimCity-style spatial grid display, complies to 4.x helper
# app interface standard

# todo
# zoom scale and grid +/- synch but jumps cause scale float and grid nearest int
# increase/decrease range, freeze icons
# Does it restore properly?

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
        SetState $winId {}
        AddToolbar $winId
        set NToolButtons [$winId.bbframe.buttonBox index last]
        for {set i 1} {$i<=$NToolButtons} {incr i} {
            $winId.bbframe.buttonBox itemconfigure $i -state disable
        }
        SetColours useNodes $winId
    }
    
    proc AddToolbar {winId} {
        set toolbarItems [list \
                [list add.gif "Add a variable"   [namespace code "AddVariable $winId"]]\
                [list zoomin.gif "Zoom in" [namespace code "zoomin $winId"] ]\
                [list zoomout.gif "Zoom out" [namespace code "zoomout $winId"] ]\
                [list property.gif " Properties " [namespace code "Settings $winId"]]\
                [list colourrcontr.gif "Decrease range" [namespace code "DecreaseRange $winId"] ]\
                [list colourrexp.gif "Increase range" [namespace code "IncreaseRange $winId"] ]\
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
        
        scan [GetState $winId] "displaying %s colourmap %s %s %s aspect %d %d %d" \
                nodePath \
                useNodes($winId,cbot) useNodes($winId,cmid) useNodes($winId,ctop) \
                useNodes($winId,nrow) useNodes($winId,ncol) useNodes($winId,nswatches)
        set useNodes($winId,display1) [GetIdFromCaptionPath $nodePath]
        SetColours useNodes $winId
        AddToolbar $winId
        $winId.bbframe.buttonBox itemconfigure 0 -state disable
        InitialiseGrid $winId $useNodes($winId,display1)
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
                    set columns [Flatten [lindex $testResult 0] {}]
                    foreach col $columns {
                        set colvals($col) 1
                    }
                    if {[info exists colvals()]} {
                        unset colvals()
                    }
                    set useNodes($winId,nrow) [array size colvals]
                    set useNodes($winId,ncol) \
                            [expr {[llength $columns]/$useNodes($winId,nrow)}]
                    $ms configure -text "Grid has $useNodes($winId,nrow) columns and $useNodes($winId,ncol) rows. Now click on the variable to be displayed."
                    SetState $winId display1
                } display1 {
                    pack forget $ms
                    ReleaseClicks $winId
                    set useNodes($winId,display1) $node
                    set full_label [GetCaptionPathFromId $node]
                    set full_label1 [string range $full_label 9 end]
                    set last_slash [string last / $full_label1]
                    set start_label [expr {$last_slash+1}]
                    set label [string range $full_label1 $start_label end]
                    catch {wm title $winId $label}
                    InitialiseGrid $winId $node
                    UpdateState $winId
                    destroy $winId.intro
                    set NToolButtons [$winId.bbframe.buttonBox index last]
                    for {set i 1} {$i<=$NToolButtons} {incr i} {
                        $winId.bbframe.buttonBox itemconfigure $i -state normal
                    }
                    
                }
            }
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc UpdateState {winId} {
        variable useNodes
        SetState $winId [list displaying \
                [GetCaptionPathFromId $useNodes($winId,display1)] colourmap \
                $useNodes($winId,cbot) $useNodes($winId,cmid) $useNodes($winId,ctop) \
                aspect $useNodes($winId,nrow) $useNodes($winId,ncol) $useNodes($winId,nswatches)]
    }
    
    proc display {winId time step remainder} {
        variable useNodes
        if {[string match [lindex [GetState $winId] 0] displaying] && \
                    !$useNodes($winId,freeze)} then {
            DrawGrid5 $winId $useNodes($winId,display1)
        }
    }
    
    proc InitialiseGrid {winId display1} {
        
        variable useNodes
        
        set useNodes($winId,min) [GetMinValue $display1]
        if {$useNodes($winId,min)==-1e100} {
            set useNodes($winId,min) -10
        }
        set useNodes($winId,max) [GetMaxValue $display1]
        if {$useNodes($winId,max)==1e100} {
            set useNodes($winId,max) 10
        }
        set useNodes($winId,range) [expr {$useNodes($winId,max)-$useNodes($winId,min)}]
        
        frame $winId.f
        scrollbar $winId.hscroll -orient horiz -command "$winId.c xview"
        scrollbar $winId.vscroll -command "$winId.c yview"
        canvas $winId.c \
                -relief sunken \
                -borderwidth 2 \
                -xscrollcommand "$winId.hscroll set"\
                -yscrollcommand "$winId.vscroll set"
        pack $winId.f -expand yes -fill both -padx 1 -pady 1
        grid rowconfig    $winId.f 0 -weight 1 -minsize 0
        grid columnconfig $winId.f 0 -weight 1 -minsize 0
        
        grid $winId.c -padx 1 -in $winId.f -pady 1 \
                -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
        grid $winId.vscroll -in $winId.f -padx 1 -pady 1 \
                -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
        grid $winId.hscroll -in $winId.f -padx 1 -pady 1 \
                -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
        
        # This is an experimental section to set up the grid display just once,
        # when the helper is initialised, so that subsequently all that happens
        # is that cell colours are re-set.
        if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
            set n $useNodes($winId,nrow)
        } else {
            set n $useNodes($winId,ncol)
        }
        
        set mult [expr {int(400/$n)}]
        set useNodes($winId,mult) $mult
        set xwidth [expr {$mult*$useNodes($winId,ncol)}]
        set yheight [expr {$mult*$useNodes($winId,nrow)+20}]
        set useNodes($winId,xwidth) $xwidth
        set useNodes($winId,yheight) $yheight
        $winId.c configure -width $xwidth -height $yheight
        
        
        recolour_scale $winId
        
        $winId.c bind all <Button-3> [namespace code "Settings $winId"]
        $winId.c bind all <B1-Motion> [namespace code "value_popup $winId $mult %x %y"]
        $winId.c bind all <ButtonPress-1> [namespace code "value_popup $winId $mult %x %y"]
        $winId.c bind all <B1-ButtonRelease> [namespace code "RemovePopup"]
        
        set useNodes($winId,hiddenMap) [image create photo]
        set useNodes($winId,visibleMap) [image create photo]
        $winId.c create image 0 0 -anchor nw -image $useNodes($winId,visibleMap)
        
        DrawGrid5 $winId $display1
        $winId.c configure -scrollregion [$winId.c bbox all]
        # bind $winId <Configure> [namespace code "resize $winId %W %x %y %w %h"]
        # bind $winId.c <Configure> [namespace code "resize $winId %W %x %y %w %h"]
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
        set mult $useNodes($winId,mult)
        set xwidth [expr {$mult*$useNodes($winId,ncol)}]
        set yheight [expr {$mult*$useNodes($winId,nrow)+20}]
        
        $winId.c create text 47 $yheight -text $useNodes($winId,min) -anchor se -tag colour_scale
        $winId.c create text [expr {$xwidth-48}] $yheight -text $useNodes($winId,max) \
                -anchor sw -tag colour_scale
        
        set xmin 50
        set xmax [expr {$xwidth-50}]
        set xincr [expr {($xmax-$xmin)/33}]
        for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
            set x0 [expr {$xmin+$icolour*$xincr}]
            set x1 [expr {$x0+$xincr}]
            set colour $useNodes($winId,c$icolour)
            $winId.c create rectangle $x0 $yheight $x1 [expr {$yheight-16}] -outline {} \
                    -fill $colour -tag colour_scale
        }
        
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
        set useNodes($winId,range) [expr {$useNodes($winId,max)-$useNodes($winId,min)}]
        SetColours useNodes $winId
        recolour_scale $winId
        UpdateState $winId
        display $winId 0 0 0
    }
    
    proc DecreaseRange {winId} {
        variable useNodes
        set useNodes($winId,min) [expr {0.1*$useNodes($winId,min)}]
        set useNodes($winId,max) [expr {0.1*$useNodes($winId,max)}]
        set useNodes($winId,range) [expr {$useNodes($winId,max)-$useNodes($winId,min)}]
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
        $dlg add -name ok; # buttons 0
        $dlg add -name cancel
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min $useNodes($winId,min)
        set max $useNodes($winId,max)
        
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
        pack [entry $rangeF.minF.entry -textvar [namespace current]::min -width 20] -side right -padx 10
        pack [LabelFrame $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [entry $rangeF.maxF.entry -textvar [namespace current]::max -width 20] -side right -padx 10
        pack $rangeF -padx 10 -pady 10
        
        # copy the values from the temp values to those to be edited if OK clicked
        if {[$dlg draw] == 0} {
            # OK button was clicked
            set useNodes($winId,ctop) [$coloursF.topcolourF.colF cget -bg]
            set useNodes($winId,cmid) [$coloursF.midcolourF.colF cget -bg]
            set useNodes($winId,cbot) [$coloursF.lowcolourF.colF cget -bg]
            set useNodes($winId,min) $min
            set useNodes($winId,max) $max
            set useNodes($winId,range) [expr {$max-$min}]
            
            SetColours useNodes $winId
            recolour_scale $winId
            UpdateState $winId
            display $winId 0 0 0
        }
        
        destroy $dlg
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
        set range $useNodes($winId,range)
        
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
        set mult [expr {int($useNodes($winId,mult))}]
        $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
                -zoom $mult $mult
    }
    proc zoomin {winId} {
        variable useNodes
        set useNodes($winId,mult) [expr {1.2*$useNodes($winId,mult)}]
        set mult [expr {int($useNodes($winId,mult))}]
        #ShowMessage debug info "zoomin mult $useNodes($winId,mult)" ok
        if {$useNodes($winId,mult)> 64} {
            return
            set useNodes($winId,mult) 64
        } elseif {$useNodes($winId,mult) < 2} {
            set useNodes($winId,mult) 2
        }
        
        $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
                -zoom $mult $mult
        $winId.c scale all 0 0 1.2 1.2
        $winId.c configure -scrollregion [$winId.c bbox all]
    }
    
    proc zoomout {winId} {
        variable useNodes
        set useNodes($winId,mult) [expr {$useNodes($winId,mult)/1.2}]
        set mult [expr {int($useNodes($winId,mult))}]
        if {$useNodes($winId,mult)<1} {
            return
            set useNodes($winId,mult) 1
        }
        #ShowMessage debug info "zoomout mult $useNodes($winId,mult)" ok
        $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
                -zoom $mult $mult -shrink
        $winId.c scale all 0 0 0.8333333333333333 0.83333333333333333333333333
        $winId.c configure -scrollregion [$winId.c bbox all]
    }
    
    #### Handle value popup
    proc value_popup {winId mult X Y} {
        variable useNodes
        
        PostValuePopup $winId $X $Y
        set height1 [expr $useNodes($winId,yheight)-19]
        if {$X>1&&$X<$useNodes($winId,xwidth)&&$Y>1&&$Y<$height1} {
            set ncol $useNodes($winId,ncol)
            set nrow $useNodes($winId,nrow)
            set col [expr int(($X-2)/$mult+1)]
            set row [expr $nrow-int(($Y-2)/$mult)]
            set cell [expr ($row-1)*$ncol+$col-1]
            set value [lindex $useNodes($winId,values) $cell]
            set index [expr $cell+1]
            
            pack [message .popup.message -aspect 400 \
                    -text "Index=$index\nCol,row=($col,$row)\nValue=$value" -bg #ffffc0] -fill x -expand true
            set x0 [winfo x $winId]
            set y0 [winfo y $winId]
            set xpoint [expr $X+$x0+15]
            set ypoint [expr $Y+$y0+43]
            wm geometry .popup +$xpoint+$ypoint
            update
        }
    }
    
    proc PostValuePopup {winId X Y} {
        variable useNodes
        
        if {[winfo exists .popup]} {
            destroy .popup
        }
        set height1 [expr $useNodes($winId,yheight)-19]
        if {$X>1&&$X<$useNodes($winId,xwidth)&&$Y>1&&$Y<$height1} {
            toplevel .popup -width 1 -height 1 -bd 2 -relief raised
            wm overrideredirect .popup 1
            raise .popup
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
