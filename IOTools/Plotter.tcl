################################################################################
#
# plotter.tcl
#
################################################################################


set keyValue "plotter1.25"

namespace eval ::$keyValue {
    
    proc identify {} {
        return "Plotter"
    }
    
    proc LoadTools {} {
	namespace import -force ::graphtools::*
	namespace import -force ::canvasnotes20070919::*
    }

    proc initialize {w} {
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        variable runCount
        
        LoadTools
	InitPlotVars $w
        InitPlatformDependentPlotVars $w
        set YYold($w) {}
        set YYnew($w) {}
        set Told($w) 0
        set Tnew($w) 0
        
        set runCount($w) 1
        SetState $w {}
        UpdateState $w
        
        ShowHelper $w
    }
    
    proc InitPlotVars {w} {
        global ::graphtools::plot
        variable ynodes
        variable NColours
        
        set ynodes($w) {}
        
        set plot($w,nodeCount) 0
        
        set plot($w,xwindow_size) 0
        set plot($w,ywindow_size) 0
        
        # Number of graticule divisions on axis.
        set plot($w,AxisDivisions) 10
        
        # choose colours for variables
        set plot($w,YColours) {blue orange green brown purple red black DeepSkyBlue \
                    HotPink ForestGreen}
        set NColours [llength $plot($w,YColours)]
        set plot($w,Xmax_axis) -1e100
        set plot($w,Xmin_axis) 1e100
        set plot($w,Xmajorstep) 1
        set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,Xmax_data) -1e20
        set plot($w,Xmin_data) 1e20
        set plot($w,Ymax_axis) -1e100; #max is 1e300
        set plot($w,Ymin_axis) 1e100
        set plot($w,Ymax_data) -1e100
        set plot($w,Ymin_data) 1e100
        set plot($w,Ymajorstep) 2
        set plot($w,Yminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,Ylabels) {}
        set plot($w,Yvars)   {}
        set plot($w,redraw) 0
        set plot($w,topright) 1
        set plot($w,grid) on
        set plot($w,xlength) 330
        set plot($w,ylength) 200
        set plot($w,xborder_left) 70
        set plot($w,xborder_right) 15
        set plot($w,yborder_top) 40
        set plot($w,yborder_bottom) 40
        set plot($w,x_Ylabels) 25
        set plot($w,xstep_Ylabels) 120
        set plot($w,ystep_Ylabels) 12
        set plot($w,x_Xlabel) 100
        set plot($w,y_Xlabel) 10
        set plot($w,canvas_colour) #e0e0e0
        set plot($w,grapharea_colour) white
        set plot($w,pointer) 1
        set plot($w,X_scalestep) 0
        set plot($w,Y_min_scalestep) 0
        set plot($w,Y_max_scalestep) 0
        set plot($w,Xprecision) 0
        set plot($w,Yprecision) 0
        set plot($w,IdArrayElements) false; # option should plot but need legend
        set plot($w,FewXAxisTicks) false
        set plot($w,AutoAxisScaling) 1; #use ints "true" doesn't  to work with check button
        set plot($w,DrawLegend) 1
        set plot($w,highlittrace) {}
	set plot($w,usedLegend) 0
    }
    
    proc InitPlatformDependentPlotVars {w} {
        global ::graphtools::plot tcl_platform
        if [string match Darwin $tcl_platform(os)] {
            set plot($w,y_Ylabels) 5
        } else {
            set plot($w,y_Ylabels) 0
        }
        if [string match Darwin $tcl_platform(os)] {
            set plot($w,fontValues) [list Helvetica 12 normal]
            set plot($w,fontLabels) [list Helvetica 12 normal]
            set plot($w,fontTitle) [list Helvetica 12 normal]
        } else {
            set plot($w,fontValues) [list Helvetica 8 normal]
            set plot($w,fontLabels) [list Helvetica 8 normal]
            set plot($w,fontTitle) [list Helvetica 8 normal]
        }
    }
    
    proc AddVarsToVarMenu {winId} {
        global ::graphtools::plot
        $winId.vars delete 0 end
        foreach var $plot($winId,Yvars) {
            if {[llength $var]} {
                $winId.vars add command -label [file tail $var] \
                        -command [namespace code [list DoRemove $winId $var]]
            }
        }
    }
    
    proc DoRemove {w path} {
        global ::graphtools::plot
        variable ynodes
        
        set index [lsearch $plot($w,Yvars) $path]
        set rootLabel [file tail $path]
        set plot($w,Yvars) [lreplace $plot($w,Yvars) $index $index]
        set ynodes($w) [lreplace $ynodes($w) $index $index]
# keep labels, otherwise colours change
#        set plot($w,Ylabels) [lreplace $plot($w,Ylabels) $index $index]
#        while {[set index [lsearch -glob $plot($w,Ylabels) ${rootLabel}* ]]>-1} {
#            set plot($w,Ylabels) [lreplace $plot($w,Ylabels) $index $index]
#        }
        UpdateState $w
# so may as well keep plots too
#        drawGraphpad $w
    }
    
    proc Restore {winId} {
        #    ShowMess debug info "plotter.tcl Restore $winId" ok
	
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        variable runCount
        variable ynodes
        
        LoadTools
        InitPlotVars $winId
        set plot($winId,Xmin_data) [GetModelTime]
        set plot($winId,Xmax_data) [GetModelEndTime]
        set YYold($winId) {}
        set YYnew($winId) {}
        set Told($winId) 0
        set Tnew($winId) 0
        
        regsub -all /WIN/ [GetState $winId] $winId restoreString
        array set plot $restoreString
        
        InitPlatformDependentPlotVars $winId
        set ynodes($winId) {}
        foreach path $plot($winId,Yvars) {
            set node [GetIdFromCaptionPath $path]
            set plot(caption,$node) [file tail $path]
            lappend ynodes($winId) $node
        }
        set runCount($winId) 1
        ShowHelper $winId
        display $winId [GetModelTime] 0 0
	if {![info exists plot($winId,stringInfo)]} return
	RestoreNotesFromList [GetCanvas $winId] $plot($winId,stringInfo)
     }
    
    proc GetCanvas {winId} {
        return $winId.canvas
    }
    
    proc click {w node caption} {
        global ::graphtools::plot
        variable ynodes
        
        set path [GetCaptionPathFromId $node]
        #ShowMess debug info "node $node; caption $caption; path $path" ok
        
        set testResult [GetModelValue $node]
        #ShowMess debug info "testResult $testResult" ok
        if {[string compare $testResult novalue]} {
            if {[lsearch $plot($w,Yvars) $path]==-1} {
                set plot(caption,$node) $caption
                lappend plot($w,Yvars) $path
                lappend ynodes($w) $node
                
                UpdateState $w
                display $w [GetModelTime] 0 0
            }
        } else {
            #    $ms configure -text "This component does not have a value; please choose a variable to be plotted."
        }
        ReleaseClicks $w
        $w.mess config -text {}; # delete prompt
        pack forget $w.mess
    }
    
    # Called at start up only
    proc ShowHelper {w} {
        #tk_messageBox -message "ShowHelper winid $w" -type ok
        constructControlPanel $w
        drawGraphpad $w;
    }
    
    proc reset {winId} {
        variable runCount
        global ::graphtools::plot
        global ::graphtools::YYnew
        
        if {!$plot($winId,IdArrayElements)} {
	    if {$plot($winId,usedLegend)} {
		incr runCount($winId)
		set plot($winId,usedLegend) 0
	    }
        }
        # prevent flyback
        set YYnew($winId) {}
    }
    
    # Invoked at every time interval.
    proc display {w time step remainder} {
        # remainder isn't time remaining to run (seems to be usually 1) use $runState(execTime)
        global ::graphtools::plot
        global ::graphtools::Told
        global ::graphtools::Tnew
        global runState
        
        get_Yvalues $w
        
        set Told($w) $Tnew($w)
        set Tnew($w) $time
        
        #redraw axis and graph if necessary; otherwise just extend plots
        if {$plot($w,redraw)} {
            #drawGraphpad $w
            #		drawGraph $w
        } else {
            plot_YY $w
        }
    }
    
    # Draw panel (window) containing controls and canvas for the graph.
    proc constructControlPanel {w} {
        global checkstates
        global ::graphtools::plot
        
        foreach child [winfo children $w] {
            destroy $child
        }
        
        menu $w.vars -tearoff 0 -postcommand \
                [namespace code [list AddVarsToVarMenu $w]]
        
        set toolbarItems [list \
                [list clear.gif "Clear" [namespace code "clear $w"] ] \
                [list add.gif "Add a variable"   [namespace code "AddVariable $w"]]\
                [list remove.gif "Remove variable" [namespace code "RemoveVariable $w" ]]\
                [list property.gif " Properties " [namespace code "Settings $w"]]\
			      [list text.gif " Add text " [namespace code "DialogInMiddle $w"]]]
        #    [list " redraw " [namespace code "resetGraph $w"]]
        ::graphtools::MakeToolBar $w $toolbarItems
        
        label $w.mess; # for instructions need to pack before use
        
        # create canvas for graph
        canvas $w.canvas -bg $plot($w,canvas_colour) -relief solid
	MakeCanvasAnnotatable $w.canvas
        if {![string match [winfo toplevel $w] $w]} {
            pack $w -fill both -expand true -side bottom
        }
        pack $w.canvas -fill both -expand true -side bottom
    }
    
    proc AddVariable { winId } {
        $winId.mess config -text "Click on a variable in the Explorer window or a Model Diagram."
        pack $winId.mess -side top
        GrabClicks $winId
    }
    
    proc Settings {w} {
        global ::graphtools::plot
        # copy the values of the variables to be edited to temp, but namespace accessible, variables
        variable FewXAxisTicks
        variable IdArrayElements
        variable AutoAxisScaling
        variable DrawLegend
        set FewXAxisTicks $::graphtools::plot($w,FewXAxisTicks)
        set IdArrayElements $::graphtools::plot($w,IdArrayElements)
        set AutoAxisScaling $::graphtools::plot($w,AutoAxisScaling)
        set DrawLegend $::graphtools::plot($w,DrawLegend)
        
        set dlg [Dialog .plotxyprop -parent $w -title "Plotter properties" \
                -modal local -default 0 -cancel 1]
        $dlg add -name ok; # buttons 0
        $dlg add -name cancel
        
        # Create entry boxes
################################################################################
#         set entryF [frame [GetFrame $dlg].entries]
#         #[list xinterval "X interval" 1]
#         #[list yinterval "Y interval" 1]]
#         foreach item [list \
#                 [list xlow "X low" $plot($w,Xmin_axis)] \
#                 [list xhigh "X high" $plot($w,Xmax_axis)] \
#                 [list ylow "Y low" $plot($w,Ymin_axis)] \
#                 [list yhigh "Y high" $plot($w,Ymax_axis)] ] {
#                     set name [lindex $item 0]
#                     set caption [lindex $item 1]
#                     frame "$entryF.$name"
#                     label "$entryF.$name.label" -text $caption
#                     entry "$entryF.$name.entry"
#                     "$entryF.$name.entry" insert 0 [lindex $item 2]
#                     pack "$entryF.$name" -fill x
#                     pack "$entryF.$name.label" -side left
#                     pack "$entryF.$name.entry" -side right
#                 }
#         pack $entryF -side top
################################################################################
        
        set chkF [frame [GetFrame $dlg].checkbuttons -relief groove -width 300]
        #pack [LabelFrame $chkF.automaticScalingF -text "Automatic scaling"] -fill x
        #pack [checkbutton $chkF.automaticScalingF.cbutton -variable [namespace current]::AutoAxisScaling] -side right
        pack [LabelFrame $chkF.fewXAxisTicksF -text "Few x-axis ticks"] -fill x
        pack [checkbutton $chkF.fewXAxisTicksF.cbutton -variable [namespace current]::FewXAxisTicks] -side right
################################################################################
#         pack [LabelFrame $chkF.idArrayElementsF -text "Different colours for each element of arrays"] -fill x
#         pack [checkbutton $chkF.idArrayElementsF.cbutton -variable [namespace current]::IdArrayElements] -side right
################################################################################
        pack [LabelFrame $chkF.legendF -text "Draw legend"] -fill x
        pack [checkbutton $chkF.legendF.cbutton -variable [namespace current]::DrawLegend] -side right
        
        pack $chkF -padx 10
        
        # copy the values from the temp values to those to be edited if OK clicked
        if {[$dlg draw] == 0} {
            # OK button was clicked
            
            # redraw the x-axis according to FewXAxisTicks must be done only when FewXAxisTicks
            # has been changed but here to it anyway instead of checking if changed
            set ::graphtools::plot($w,FewXAxisTicks) $FewXAxisTicks
            #set ::graphtools::plot($w,AutoAxisScaling) $AutoAxisScaling
            set ::graphtools::plot($w,IdArrayElements) $IdArrayElements
            if {$IdArrayElements} {
                set $plot($w,Ylabels) {}
            }
            
            set ::graphtools::plot($w,DrawLegend) $DrawLegend
################################################################################
#             set OldXRange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
#             set OldXmin_axis $plot($w,Xmin_axis)
#             set OldXmax_axis $plot($w,Xmax_axis)
#             set OldYRange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
#             set OldYmax_axis $plot($w,Ymax_axis)
#             set $plot($w,Xmin_axis)] ["$entryF.xlow.entry" get]
#             set $plot($w,Xmax_axis)] ["$entryF.xhigh.entry" get]
#             set $plot($w,Ymin_axis)] ["$entryF.ylow.entry" get]
#             set $plot($w,Ymax_axis)] ["$entryF.yhigh.entry" get]
#             set numInt 0; set numMinorInt 0
#             if {!$::graphtools::plot($w,AutoAxisScaling)} {
#                 #AxisRound $plot($w,Xmin_axis) $plot($w,Xmax_axis) $plot($w,FewXAxisTicks) \
#                         plot($w,Xmin_axis) plot($w,Xmax_axis) \
#                         plot($w,Xmajorstep) numInt plot($w,Xminorstep) numMinorInt plot($w,Xprecision)
#                 RescaleGraphX $w $OldXRange $OldXmax_axis
#                             
#                 #AxisRound $plot($w,Ymin_axis) $plot($w,Ymax_axis) 0 \
#                         plot($w,Ymin_axis) plot($w,Ymax_axis) \
#                         plot($w,Ymajorstep) numInt plot($w,Yminorstep) numMinorInt plot($w,Yprecision)
#                 RescaleGraphY $w $OldYRange $OldYmax_axis
#             }
################################################################################
            if {$::graphtools::plot($w,DrawLegend)} {
                drawLegend $w
            } else {
                $w.canvas delete legend
            }
            #draw_Xaxis $w
            #draw_Yaxis $w
            
            UpdateState $w
        }
        destroy $dlg
    }
    
    proc PrepareSaveString {w} {
	set ::graphtools::plot($w,stringInfo) [ListNotes [GetCanvas $w]]
	UpdateState $w
    }

    ### Draw on the graph canvas everything except the actual data points.
    proc drawGraphpad {w} {
        global ::graphtools::plot
        
        ### rub out previous graph but leave messages
	$w.canvas addtag togo all
	$w.canvas dtag annotation togo
        $w.canvas delete togo
        
        ### Convenience variables
        set x0 $plot($w,xborder_left)
        set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
        set x1 [expr $plot($w,xborder_left)+$plot($w,xlength)]
        set y1 $plot($w,yborder_top)
        
        ### Make the graph area
        $w.canvas create rectangle $x0 $y0 $x1 $y1 \
                -fill $plot($w,grapharea_colour) \
                -outline {} -tags {scalable /background/}
        
        ### Draw the X axis
        $w.canvas create line $x0 $y0 $x1 $y0 \
                -tags {axis_line scalable markable xslidable}
        draw_Xaxis $w
        
        ### Draw the Y axis
        $w.canvas create line $x0 $y0 $x0 $y1 \
                -tags {axis_line scalable markable yslidable}
        draw_Yaxis $w
        
        ### Draw the top and right edges of the graph area
        if {$plot($w,topright)} {
            $w.canvas create line $x0 $y1 $x1 $y1 \
                    -tags {scalable topright}
            $w.canvas create line $x1 $y0 $x1 $y1 \
                    -tags {scalable topright}
        }
        
        ### Label the two axes
        $w.canvas create text [expr $x0+$plot($w,xlength)/2.0] \
                [expr $y0+$plot($w,yborder_bottom)-5] \
                -text "Time" -anchor s \
                -tags {movable scalable xaxis_label markable toplevel}
        
        if {$plot($w,DrawLegend)} {
            drawLegend $w
        }   
        
        ### Apply graticule and values to axis.
        # drawGraticule $w $Xintercept $Yintercept
        
        $w.canvas raise toplevel
        $w.canvas raise annotation
        
        ### Bindings
        #$w.canvas bind grapharea <Button-1> [namespace code "TraceUnhighlight $w"]
        #$w.canvas bind axis_line <Double-1> \
        #        [namespace code "settings_axis $w"]
        ################################################################################
        #         $w.canvas bind all <Button-1> \
        #                 [namespace code "CanvasMark $w %x %y %W"]
        #         $w.canvas bind movable <B1-Motion> \
        #                 [namespace code "CanvasDrag %x %y %W"]
        ################################################################################
        
        ################################################################################
        #         for {set i 0} {$i<$nYlabel} {incr i} {
        #             set vartag {}
        #             append vartag var $i
        #             $w.canvas bind $vartag <B1-Motion> \
        #                     [namespace code "Ylabel_move %W %x %y"]
        #         }
        #         $w.canvas bind Ylabel
        ################################################################################
        
        bind $w <Configure> [namespace code "resize $w %W %x %y %w %h"]
        bind $w.canvas <Configure> [namespace code "resize $w %W %x %y %w %h"]
        
    }
    
    proc TraceHighlight {w node id} {
        global ::graphtools::plot
        ################################################################################
        #         set path [GetCaptionPathFromId $node]
        #         if {$plot($w,$path,width)==2} {
        #             set plot($w,$path,width) 1
        #         } else  {
        #              set plot($w,$path,width) 2
        #         }
        #         $w.canvas itemconfigure $node.$id -width $plot($w,$path,width)
        ################################################################################
        
        set index [lsearch $plot($w,highlittrace) $node.$id]
        if {$index>-1} {
            $w.canvas itemconfigure $node.$id -width 1
            set plot($w,highlittrace) \
               [lreplace $plot($w,highlittrace)  $index $index]
        } else  {
            lappend  plot($w,highlittrace)  $node.$id
            $w.canvas itemconfigure $node.$id -width 2
        }
    }
    
    proc TracePopup {winId node id X Y x y} {
        global ::graphtools::plot
        
        set caption $plot(caption,$node)
	if {[llength $id]} {
	    append caption \[[join $id ,]\]
	}
        if {[catch {
	    set lastval [lindex [GetModelValue $node] 0]
	    while {[llength $lastval]>1} {
		array set valArray $lastval
		set lastval $valArray([lindex $id 0])
		set id [lrange $id 1 end]
	    }
	}]} {
	    set lastval unavailable
	}
        #::graphtools::get_datax {w Xc Xscale}
        #plot($w,Tscale)

# Make sure values are nice -- retreive graph segment and use its coords
	set canvas [GetCanvas $winId]
	set segment [$canvas find closest \
			 [$canvas canvasx $x] [$canvas canvasy $y] 1]
	set origin [$canvas coords $segment]
        set nearestval [::graphtools::get_datay $winId [lindex $origin 1] \
			    $plot($winId,Yscale)]
        set nearesttime [::graphtools::get_datax $winId [lindex $origin 0] \
			     $plot($winId,Tscale)]
	PostPopup $X $Y
#         if {![winfo exists .popup]} {
#             toplevel .popup -width 1 -height 1 -bd 2 -relief raised
#             wm overrideredirect .popup 1 
	AddPopupMessage "$caption \n\
                x     : $nearesttime\n\
                y     : $nearestval\n\
                last y: $lastval" \#ffffc0
#             pack [message .popup.message -aspect 400 -bg \#ffffc0] \
#                     -fill x -expand true
#             raise .popup
#         }
#         .popup.message config -text "$caption \n\
#                 x     : $nearesttime\n\
#                 y     : $nearestval\n\
#                 last y: $lastval"
#         set xpoint [expr $X+15]
#         set ypoint [expr $Y+43]
#         wm geometry .popup +$xpoint+$ypoint
#         update
    }
    
    proc drawLegend {w} {
        global ::graphtools::plot
        #ShowMess debug info "font [font families -displayof $w.canvas]" ok
        # legend vars only, not elements of arrays
        set nYlabel [llength $plot($w,Ylabels)]
        set longestlbl 0
        foreach label $plot($w,Ylabels) {
            if {[string length $label]>$longestlbl} {
                set longestlbl $label
            }
        }
        set plot($w,xstep_Ylabels) \
                [expr {15+\
                    [font measure $plot($w,fontLabels) -displayof $w.canvas $longestlbl]}]
        set j 0
        set k 0
        for {set i 0} {$i<$nYlabel} {incr i} {
            set x [expr $plot($w,x_Ylabels)+$k*$plot($w,xstep_Ylabels)]
            set y [expr $plot($w,y_Ylabels)+$j*$plot($w,ystep_Ylabels)]
            set xa [expr $x-15]
            set xb [expr $x-2]
            set ya [expr $y+8]
            set vartag {}
            append vartag var $i
            $w.canvas create line $xa $ya $xb $ya \
                    -fill [lindex $plot($w,YColours) $i] \
                    -width 2 \
                    -tags [list $vartag legend markable toplevel]
            $w.canvas create text $x $y \
                    -text [lindex $plot($w,Ylabels) $i] \
                    -anchor nw -font $plot($w,fontLabels)\
                    -tags [list $vartag legend markable toplevel]
            incr j
            if {$j==2} {
                incr k
                set j 0
            }
        }
    }
    
    proc Reset_Xaxis {w} {
        global ::graphtools::plot
        
        # reset slide
        set canvas($w.canvas,x) [get_x $w 0 $plot($w,Tscale)]
        set x [get_x $w $plot($w,Xmin_axis) $plot($w,Tscale)]
        Xslide $w $w.canvas $x 0
        
        # reset stretch
        
        
    }
    
    proc resize {w win x y width height} {
        global ::graphtools::plot
        global ::graphtools::YYnew
        
        if {[string match Canvas [winfo class $win]]} {
            set x0 $plot($w,xborder_left)
            set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
            set x1 [expr $plot($w,xborder_left)+$plot($w,xlength)]
            set y1 $plot($w,yborder_top)
            
            set old_width $plot($w,xlength)
            set old_height $plot($w,ylength)
            
            set new_width [expr $width-$plot($w,xborder_left)- \
			       $plot($w,xborder_right)]
            set new_height [expr 2*round(($height-$plot($w,yborder_top)- \
					      $plot($w,yborder_bottom))/2)]
	    # ensure even to avoid jitter
            
            set width_diff [expr $new_width-$old_width]
            set height_diff [expr $new_height-$old_height]
            
            set Xmult [expr 1.0*$new_width/$old_width]
            set Ymult [expr 1.0*$new_height/$old_height]
            
            $win scale scalable $x0 $y1 $Xmult $Ymult
            
            set plot($w,xlength) [expr $plot($w,xlength)+$width_diff]
            set plot($w,ylength) [expr $plot($w,ylength)+$height_diff]
            set xlabel [expr $plot($w,xborder_left)+$plot($w,xlength)/2.0]
            set ylabel [expr $plot($w,yborder_top)+$plot($w,ylength) \
                    +$plot($w,yborder_bottom)-5]
            $w.canvas coords xaxis_label $xlabel $ylabel
            
            set x1 [expr $plot($w,xborder_left)+$plot($w,xlength)]; #jmm
            set x2 [expr $x1+5]; # todo 2000 seems a bit big jmm
            ##$w.canvas coords blanket_right $x2 0 500 500
            
            set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]; #jmm
            set y2 [expr $y0+5]
            ##$w.canvas coords blanket_bottom 0 $y2 500 500

# next bit for scaling popup info
#	    set YYnew($w) {}
#	    plot_YY $w
        set Trange [expr {1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)}]
        set Yrange [expr {1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)}]
        set plot($w,Tscale) [expr {$Trange/$plot($w,xlength)}]
        set plot($w,Yscale) [expr {$Yrange/$plot($w,ylength)}]
        
        }
    }
    
    ### apply graticule and grid to graph
    proc drawGraticule {w Xintercept Yintercept} {
        global ::graphtools::plot
        
        # distance between each graticule.
        set Xgraticule  [expr ($plot($w,Width)  - 2*$plot($w,Xborder)) / double($plot($w,AxisDivisions))]
        set Ygraticule  [expr ($plot($w,Height) - 2*$plot($w,Yborder)) / double($plot($w,AxisDivisions))]
        
        # value per division ( set to 0.1 if a division = 0)
        set Xdivision [expr (abs($plot($w,Xmax))+abs($plot($w,Xmin)))  / double($plot($w,AxisDivisions))]
        set Ydivision [expr (abs($plot($w,Ymax))+abs($plot($w,Ymin)))  / double($plot($w,AxisDivisions))]
        
        # draw values and grid lines
        set i [expr -1*$plot($w,AxisDivisions)]
        while {$i<= $plot($w,AxisDivisions)} {
            set x [expr floor( $Xintercept + $i * $Xgraticule) ]
            set y [expr floor( $Yintercept - $i * $Ygraticule) ]
            
            # draw Y axis values and vertical grid lines
            if {($x <= [expr $plot($w,Width)-$plot($w,Xborder)]) && ($x >= $plot($w,Xborder)) } {
                set dec [decimalPlaces [expr $i*$Xdivision]]
                if {$plot($w,grid)=="on"} {
                    $w.canvas create line $x $plot($w,Yborder) $x [expr $plot($w,Height)-$plot($w,Yborder)] -width 1 -fill gray -tags graph
                }
                $w.canvas create text $x [expr $Yintercept+10] -text [format $dec [expr $i*$Xdivision]] -tags graph
            }
            # draw X axis values and horizontal grid lines
            if {($y <= [expr $plot($w,Height)-$plot($w,Yborder)]) && ($y >= $plot($w,Yborder)) } {
                set dec [decimalPlaces [expr $i*$Ydivision]]
                if {$plot($w,grid)=="on"} {
                    $w.canvas create line $plot($w,Xborder) $y [expr $plot($w,Width)-$plot($w,Xborder)] $y  -width 1 -fill gray -tags graph
                }
                $w.canvas create text [expr $Xintercept-15] $y -text [format $dec [expr $i*$Ydivision]] -tags graph
            }
            incr i
        }
    }
    
    
    ############################################################################
    ######         DYNAMIC BIT
    ############################################################################
    
    
    
    ##########################################################################
    # proc plot_YY	Plots all the Y variables, by calling...
    # proc plot_Y	Plots one Y variable, which calls...
    # proc drawPoint	Plots one point (with a line from the previous point)
    #
    # This should be seen as a general-purpose mechanism for iterating over
    # all variables currently loaded into the helper and, for each variable,
    # picking up its current and previous values.   The values may be scalars
    # or a list of values, nested if the variable is in nested multiple-instance
    # submodels.   In the latter case, the 'plot_Y' procedure recurses over all
    # levels.
    #
    # This is designed for displays which *require* the previous value (e.g. a
    # graph which must draw a line from the previous point).   It is *not*
    # suitable for displays which make use only of the current value (e.g.
    # the lollipop display), since processing only continues if it knows that
    # there is a previous value.   It is easy to modify this code to make
    # another general-purpose mechanism for when you do just want to process
    # the current value.
    
    proc plot_YY {w} {
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
	array set Yold_array $YYold($w)
        foreach {node Ynew} $YYnew($w) {
            #puts "plot_YY Ynew $Ynew"
#            foreach Yold $YYold($w) {
#                if {$node==[lindex $Yold 0]} {
	    if {![info exists Yold_array($node)]} {
		set Yold_array($node) {}
	    }
	    plot_Y $w [captionNo $w $node] $Told($w) $Yold_array($node) \
		$Tnew($w) $Ynew $node {}
#                }
#            }
        }
    }
    
    proc captionNo {w node} {
        global ::graphtools::plot
        variable runCount
        #ShowMess debug info "captionNo" ok
        if {$plot($w,IdArrayElements)} {
            set capt "$plot(caption,$node)"
        } else  {
            set capt "$plot(caption,$node), run $runCount($w)"
        }
        set posn [lsearch $plot($w,Ylabels) $capt]
        if {$posn==-1} {
            set posn [llength $plot($w,Ylabels)]
            lappend plot($w,Ylabels) $capt
            if {$plot($w,DrawLegend)} {
                drawLegend $w
            }
        }
        
        return $posn
    }
    
    proc plot_Y {w iplot Told Yold Tnew Ynew node id} {
        global ::graphtools::plot
        global errorInfo
        variable NColours
        
        if {[llength $Ynew]==1} then {
            set colour [lindex $plot($w,YColours) [expr {int(fmod($iplot,$NColours))}]]
            #puts "plot_Y iplot $iplot; lindex $plot($w,YColours) $iplot [lindex $plot($w,YColours) $iplot]"
	    set ident [join $id ,]
	    if {[dodgyValue $Ynew]} {
		set xm [expr $plot($w,xborder_left)+60]
		set ym [expr $plot($w,yborder_top)+60]
		$w.canvas create text $xm $ym -tags prompt -width 100 \
		    -justify center -text "Some values resulting from maths errors have not been plotted"
	    } else {
		if $plot($w,AutoAxisScaling) {
		    adjustLimits $w $Tnew $Ynew
		}
		if {![dodgyValue $Yold]} {
		    drawPoint $w $Told $Yold $Tnew $Ynew $colour $node $ident
		} else { ;# will plot next time so add binding for it
		    $w.canvas bind $node.$ident <Button-1> \
			 [namespace code [list TraceHighlight $w $node $ident]]
		    $w.canvas bind $node.$ident <Enter> \
			 [namespace code [list TracePopup $w $node $id %X %Y \
					      %x %y]]
		    $w.canvas bind $node.$ident <Leave> RemovePopup
		}
	    }
        } else {
            array set Ynew_array $Ynew
            array set Yold_array $Yold
            foreach element [array names Ynew_array] {
		set identList [concat $id [list $element]]
                if {![info exists Yold_array($element)]} {
		    set Yold_array($element) {}
		}
		plot_Y $w $iplot $Told $Yold_array($element) $Tnew \
		    $Ynew_array($element) $node $identList
		# WRONG COLOURS  -VAR1 -(4) -(2) ETC!!!
		if {$plot($w,IdArrayElements)} {
		    incr iplot; #give element of an array a unique id, eg for colour
		    set posn [lsearch $plot($w,Ylabels) ($iplot)]
		    if {$posn==-1} {
			#set posn [llength $plot($w,Ylabels)]
			lappend plot($w,Ylabels) ($iplot)
			if {$plot($w,DrawLegend)} {
			    drawLegend $w
			}
		    }
		}
            }
        }
        
    }
    
    proc dodgyValue {val} {
        return [expr ![string is double -strict $val] || \
                [lsearch {inf nan +inf +nan -inf -nan} $val]>-1]
    }
    
    # Connect two points on the graph
    proc drawPoint { w X0 Y0 X1 Y1 Colour node id} {
        global ::graphtools::plot
        #ShowMess debug info "draw $node.$id" ok
#puts "Drawing from $X0 $Y0 to $X1 $Y1"
        set x0 [get_x $w $X0 $plot($w,Tscale)]
        set x1 [get_x $w $X1 $plot($w,Tscale)]
        set y0 [get_y $w $Y0 $plot($w,Yscale)]
        set y1 [get_y $w $Y1 $plot($w,Yscale)]
        #set path [GetCaptionPathFromId $node]
        # should be a parameter for each variable
        set index [lsearch $plot($w,highlittrace) $node.$id]
        if {$index>-1} {
            set width 2
        } else  {
            set width 1
        }
	set plot($w,usedLegend) 1
        $w.canvas create line $x0 $y0 $x1 $y1 \
                -fill $Colour -width $width\
                -tags "graph scalable xaxis_item yaxis_item $node.$id"
    }
    
    
    # clear graph
    proc clear { w } {
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::plot
        variable runCount
        
        if $plot($w,AutoAxisScaling) {
            set plot($w,Xmax_axis) -1e100
            set plot($w,Xmin_axis) 1e100
            set plot($w,Xmajorstep) 1
            set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
            set plot($w,Xmax_data) -1e20
            set plot($w,Xmin_data) 1e20
            set plot($w,Ymax_axis) -1e100; #max is 1e300
            set plot($w,Ymin_axis) 1e100
            set plot($w,Ymax_data) -1e100
            set plot($w,Ymin_data) 1e100
            set plot($w,Ymajorstep) 2
            set plot($w,Yminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
            set plot($w,Xprecision) 0
            set plot($w,Yprecision) 0
            set plot($w,usedLegend) 0
        }
        set YYold($w) {}
        set YYnew($w) {}
        
        set runCount($w) 1
        set plot($w,Ylabels) {}
        
        $w.canvas delete prompt
        drawGraphpad $w
        display $w [GetModelTime] 0 0
    }
    
    proc adjustLimits {w Tnew Ynew} {
        global ::graphtools::plot
        
        if { ( $Tnew>$plot($w,Xmax_axis) || ($Tnew<$plot($w,Xmin_axis)) )} {
            if {$Tnew>$plot($w,Xmax_axis)} {
                set plot($w,Xmax_data) [GetModelEndTime]
            }
            if {$Tnew<$plot($w,Xmin_axis)} {
                set plot($w,Xmin_data) $Tnew
            }
            set OldRange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
            set OldXmin_axis $plot($w,Xmin_axis)
            
            set numInt 0
            set numMinorInt 0
            #puts "adjustX lim Tnew $Tnew; plot(w,Xmin_data) $plot($w,Xmin_data); \
            #        plot(w,Xmax_data) $plot($w,Xmax_data)\n\
            #        plot(w,Xmin_axis) $plot($w,Xmin_axis); plot(w,Xmax_axis) $plot($w,Xmax_axis)"
            AxisRound $plot($w,Xmin_data) $plot($w,Xmax_data) $plot($w,FewXAxisTicks) \
                    plot($w,Xmin_axis) plot($w,Xmax_axis) \
                    plot($w,Xmajorstep) numInt plot($w,Xminorstep) numMinorInt plot($w,Xprecision)
            RescaleGraphX $w $OldRange $OldXmin_axis
        }
        if { ( ($Ynew>$plot($w,Ymax_axis)) || ($Ynew<$plot($w,Ymin_axis)) )} {
            #       ShowMess debug info "$Ynew $plot($w,Ymin_data) $plot($w,Ymax_data)\
            #                $plot($w,Ymin_axis) $plot($w,Ymax_axis)" ok
            if {$Ynew>$plot($w,Ymax_axis)} {
                set plot($w,Ymax_data) $Ynew
            }
            if {$Ynew<$plot($w,Ymin_axis)} {
                set plot($w,Ymin_data) $Ynew
            }
            set numInt 0
            set numMinorInt 0
            set OldYrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
            set OldYmax_axis $plot($w,Ymax_axis)
            AxisRound $plot($w,Ymin_data) $plot($w,Ymax_data) 0 \
                    plot($w,Ymin_axis) plot($w,Ymax_axis) \
                    plot($w,Ymajorstep) numInt plot($w,Yminorstep) numMinorInt plot($w,Yprecision)
            RescaleGraphY $w $OldYrange $OldYmax_axis
        }
    }
    
    proc RescaleGraphX {w OldRange OldXmin_axis} {
        global ::graphtools::plot
        set Trange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
        
        set scaleChange [expr {$OldRange/$Trange}]
        set plot($w,Tscale) [expr $Trange/$plot($w,xlength)]
        set x0 $plot($w,xborder_left)
#        set y0 $plot($w,yborder_top)
#        $w.canvas scale xaxis_item $x0 $y0 $scaleChange 1
        
        set xmove [expr {\
            [get_x $w $OldXmin_axis $plot($w,Tscale)] \
                    -[get_x $w $plot($w,Xmin_axis) $plot($w,Tscale)] }]
	if {$scaleChange==1} {
	    $w.canvas move xaxis_item $xmove 0
        } else {
# single move for greater speed?
	    set baseLine [expr {$x0+$xmove/(1-$scaleChange)}]
	    $w.canvas scale xaxis_item $baseLine 0 $scaleChange 1
	}
        draw_Xaxis $w
    }
    
    proc RescaleGraphY {w OldYrange OldYmax_axis} {
        global ::graphtools::plot
        set plot($w,Yminorstep) [expr {$plot($w,Ymajorstep)/2}]
        set Yrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
        set scaleChange [expr {$OldYrange/$Yrange}]
        
        set plot($w,Yscale) [expr {$Yrange/$plot($w,ylength)}]
#        set x0 $plot($w,xborder_left)
        
        set y0 $plot($w,yborder_top)
#        $w.canvas scale yaxis_item $x0 $y0 1 $scaleChange
        
        set ymove [expr {\
            -[get_y $w $plot($w,Ymax_axis) $plot($w,Yscale)]\
                    +[get_y $w $OldYmax_axis $plot($w,Yscale)] }]
	if {$scaleChange==1} {
	    $w.canvas move yaxis_item 0 $ymove
	} else {
# single move for greater speed?
	    set baseLine [expr {$y0+$ymove/(1-$scaleChange)}]
	    $w.canvas scale yaxis_item 0 $baseLine 1 $scaleChange
	}
        draw_Yaxis $w
    }
    
    proc marker {} {tk_messageBox -message "proc marker"}
    
    
    # redraw graph after adjusting limits to Coordinates range. Not yet used
    proc resetGraph { w } {
        global ::graphtools::plot
        
        drawGraphpad $w
        #	drawGraph $w
    }
    
    
    ######################################################################
    # proc get_Yvalues
    #
    # All the data is held in a 1D array, with 2 elements.
    # Each element consists of a list of 2 elements:
    # - the first element holds the node ID (not its label);
    # - the second element holds all the values for the node at one
    #   point in time (a scalar, or an indexed list, etc).
    # The 2 elements of the array are for holding the 'old' and 'new' values
    # respectively.   Rather than copying the 'new' into the 'old' every
    # point in time, we use the trick of having a pointer indicating which element
    # of the array holds the current values.  The value for this pointer starts
    # off at 0, then alternates 1 0 1 0 etc.
    
    proc get_Yvalues {w} {
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        variable ynodes
        set YYold($w) $YYnew($w)
        
        set YYnew($w) [list 1 2]
        set YYnew($w) [lreplace $YYnew($w) 0 end]
        foreach node $ynodes($w) {
            set values [GetModelValue $node]
            set values [lindex $values 0]
            if {[llength $values]} {
                lappend YYnew($w) $node $values
            }
        }
    }
    
    proc RemoveVariable { winId } {
        tk_popup $winId.vars \
                [winfo pointerx $winId] [winfo pointery $winId]
    }
    
    
    # end of namespace
} ;

