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
    
    proc initialize {w} {
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        namespace import -force ::graphtools::*; # todo make graphtools common
        
        set plot($w,nodeCount) 0
        
        set plot($w,xwindow_size) 0
        set plot($w,ywindow_size) 0
        
        # Number of graticule divisions on axis.
        set plot($w,AxisDivisions) 10
        
        # choose colours for variables
        set plot($w,YColours) [list #0000ff #ff0000 #00ff00 #007777 #777700 \
                #770077 #222244 #442222 #224422]
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
        set plot($w,xlength) 350
        set plot($w,ylength) 200
        set plot($w,xborder_left) 50
        set plot($w,xborder_right) 15
        set plot($w,yborder_top) 30
        set plot($w,yborder_bottom) 30
        set plot($w,x_Ylabels) 25
        set plot($w,y_Ylabels) 0
        set plot($w,xstep_Ylabels) 120
        set plot($w,ystep_Ylabels) 12
        set plot($w,x_Xlabel) 100
        set plot($w,y_Xlabel) 10
        set plot($w,fontValues) [list Helvetica 8 normal]
        set plot($w,fontLabels) [list Helvetica 8 normal]
        set plot($w,fontTitle) [list Helvetica 8 normal]
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
        
        set YYold($w) {}
        set YYnew($w) {}
        set Told($w) 0
        set Tnew($w) 0
        
        SetState $w {}
        UpdateState $w
        
        ShowHelper $w
    }
    
    proc Restore {winId} {
        #    ShowMessage debug info "plotter.tcl Restore $winId" ok
        namespace import -force ::graphtools::*
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        global runState
        
        #initialize $winId; #allows default values for vars missing from GetState
        # loses vars to plot
        
        set plot($winId,Xmin_data) [GetModelTime]; # 0 jan 03  set plot($w,Xmin_data) $Tnew
        set plot($winId,Xmax_data) [expr {[GetModelTime]+$runState(execTime)}]; # 0 jan 03  set plot($w,Xmin_data) $Tnew
        ################################################################################
        set YYold($winId) {}
        set YYnew($winId) {}
        set Told($winId) 0
        set Tnew($winId) 0
        ################################################################################
        
        regsub -all /WIN/ [GetState $winId] $winId restoreString
        array set plot $restoreString
        #    ShowMessage debug info $restoreString ok
        ShowHelper $winId
        display $winId [GetModelTime] 0 0
        display $winId [GetModelTime] 0 0
    }
    
    proc GetCanvas {winId} {
        return $winId.canvas
    }
    
    proc click {w node caption} {
        #tk_messageBox -message "Click node $node" -type ok
        global ::graphtools::plot
        
        set name [GetCaptionPathFromId $node]
        
        set testResult [GetModelValue $node]
        if {[string compare $testResult novalue]} {
            lappend plot($w,Ylabels) $caption
            lappend plot($w,Yvars)   $node
            
            drawGraphpad $w
            UpdateState $w
            display $w [GetModelTime] 0 0
            display $w [GetModelTime] 0 0
        } else {
            #    $ms configure -text "This component does not have a value; please choose a variable to be plotted."
        }
        ReleaseClicks $w
        $w.mess config -text {}; # delete prompt
    }
    
    # Called at start up only
    proc ShowHelper {w} {
        #tk_messageBox -message "ShowHelper winid $w" -type ok
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        constructControlPanel $w
        
        # Initialise values list.
        # jan 03 set Told($w) 0
        # jan 03 set Tnew($w) 0
        
        drawGraphpad $w;
    }
    
    # Invoked at every time interval.
    proc display {w time step remainder} {
        # remainder isn't time remaining to run (seems to be usually 1) use $runState(execTime)
        global ::graphtools::plot
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        global runState
        
        #puts "display $w $time $step $remainder $runState(execTime) [expr {$time+$runState(execTime)}]; plot(w,Xmax_data) $plot($w,Xmax_data)"
        
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
        #tk_messageBox -message "constructControlPanel winid $w" -type ok
        global checkstates
        global ::graphtools::plot
        
        foreach child [winfo children $w] {
            destroy $child
        }
        
        set toolbarItems [list \
                [list clear.gif "Clear" [namespace code "clear $w"] ] \
                [list add.gif "Add a variable"   [namespace code "AddVariable $w"]]\
                [list remove.gif "Remove variable" [namespace code "RemoveVariableDlg $w" ]]\
                [list property.gif " Properties " [namespace code "Settings $w"]]]
        #    [list " redraw " [namespace code "resetGraph $w"]]
        ::graphtools::MakeToolBar $w $toolbarItems
        
        pack [label $w.mess] ;# for instructions
                
        # create canvas for graph
        canvas $w.canvas -bg $plot($w,canvas_colour) -relief solid ;#\
                #-width [expr $plot($w,xborder_left)+$plot($w,xlength)+ \
                #	$plot($w,xborder_right)] \
                #-height [expr $plot($w,yborder_bottom)+$plot($w,ylength)+ \
                #	$plot($w,yborder_top)] \
                #-bg $plot($w,canvas_colour) -relief solid
                #ShowMessage debug info "[winfo toplevel $w]" ok
                if {![string match [winfo toplevel $w] $w]} {
                    pack $w -fill both -expand true -side bottom
                }
        pack $w.canvas -fill both -expand true -side bottom
    }
    
    proc AddVariable { winId } {
        $winId.mess config -text "Click on a variable in the Explorer window or a Model Diagram."
        GrabClicks $winId
    }
    
    proc NoMoreVar {w} {
        ReleaseClicks $w
        $w.canvas delete prompt
    }
    
    
    proc Settings {w} {
        global ::graphtools::plot
        # copy the values of the variables to be edited to temp, but namespace accessible, variables
        variable FewXAxisTicks $::graphtools::plot($w,FewXAxisTicks)
        
        
        set dlg [Dialog .plotxyprop -parent $w -title "Plotter properties" \
                -modal local -default 0 -cancel 1]
        $dlg add -name ok; # buttons 0
        $dlg add -name cancel
        
        # Create entry boxes
################################################################################
#         set entryF [frame [$dlg getframe].entries]
#         foreach item [list \
#                 [list xlow "X low" 0] \
#                 [list xhigh "X high" 10] \
#                 [list xinterval "X interval" 1] \
#                 [list ylow "Y low" 0] \
#                 [list yhigh "Y high" 10] \
#                 [list yinterval "Y interval" 1]] {
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

        set chkF [frame [$dlg getframe].checkbuttons -relief groove -width 300]
        pack [LabelFrame $chkF.fewXAxisTicksF -text "Few x-axis ticks"] -fill x
        pack [checkbutton $chkF.fewXAxisTicksF.cbutton -variable [namespace current]::FewXAxisTicks] -side right
        pack $chkF -padx 10
        
        # copy the values from the temp values to those to be edited if OK clicked
        if {[$dlg draw] == 0} {
            # OK button was clicked
            
            # redraw the x-axis according to FewXAxisTicks must be done only when FewXAxisTicks
            # has been changed but here to it anyway instead of checking if changed
            set ::graphtools::plot($w,FewXAxisTicks) $FewXAxisTicks
            set numInt 0; set numMinorInt 0
            AxisRound $plot($w,Xmin_data) $plot($w,Xmax_data) $plot($w,FewXAxisTicks) \
                    plot($w,Xmin_axis) plot($w,Xmax_axis) \
                    plot($w,Xmajorstep) numInt plot($w,Xminorstep) numMinorInt plot($w,Xprecision)
            draw_Xaxis $w
            
            UpdateState $w
        }
        #ShowMessage debug info "$::graphtools::plot($w,DrawLines) $::graphtools::plot($w,DrawPoints)" ok
        
        destroy $dlg
    }
        
    ### Draw on the graph canvas everything except the actual data points.
    proc drawGraphpad {w} {
        global ::graphtools::plot
        
        ### rub out previous graph
        $w.canvas delete all
        
        ### Convenience variables
        set x0 $plot($w,xborder_left)
        set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
        set x1 [expr $plot($w,xborder_left)+$plot($w,xlength)]
        set y1 $plot($w,yborder_top)
        
        ### Make the graph area
        $w.canvas create rectangle $x0 $y0 $x1 $y1 \
                -fill $plot($w,grapharea_colour) \
                -outline {} -tags {scalable grapharea}
        
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
        
        # legend vars only, not elements of arrays
        set nYlabel [llength $plot($w,Ylabels)]
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
                    -tags [list $vartag axis_label markable toplevel]
            $w.canvas create text $x $y \
                    -text [lindex $plot($w,Ylabels) $i] \
                    -anchor nw \
                    -tags [list $vartag axis_label markable toplevel]
            incr j
            if {$j==2} {
                incr k
                set j 0
            }
        }
        
        ### Apply graticule and values to axis.
        # drawGraticule $w $Xintercept $Yintercept
        
        $w.canvas raise toplevel
        
        ### Bindings
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
    
    proc Reset_Xaxis {w} {
        global ::graphtools::plot
        
        # reset slide
        set canvas($w.canvas,x) [get_x $w 0 $plot($w,Tscale)]
        set x [get_x $w $plot($w,Xmin_axis) $plot($w,Tscale)]
        Xslide $w $w.canvas $x 0
        
        # reset stretch
        
        
    }
    
    proc ring_bell {} {
        bell
    }
    
    proc resize {w win x y width height} {
        global ::graphtools::plot
        
        if {[string match Canvas [winfo class $win]]} {
            set x0 $plot($w,xborder_left)
            set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
            set x1 [expr $plot($w,xborder_left)+$plot($w,xlength)]
            set y1 $plot($w,yborder_top)
            
            set old_width $plot($w,xlength)
            set old_height $plot($w,ylength)
            
            set new_width [expr $width-$plot($w,xborder_left)- \
                    $plot($w,xborder_right)]
            set new_height [expr $height-$plot($w,yborder_top)- \
                    $plot($w,yborder_bottom)]
            
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
        
        set Trange [expr {1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)}]
        set Yrange [expr {1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)}]
        set plot($w,Tscale) [expr {$Trange/$plot($w,xlength)}]
        set plot($w,Yscale) [expr {$Yrange/$plot($w,ylength)}]
        
        set iplot 0
        foreach Ynew $YYnew($w) {
            #puts "plot_YY Ynew $Ynew"
            set node [lindex $Ynew 0]
            foreach Yold $YYold($w) {
                if {$node==[lindex $Yold 0]} {
                    plot_Y $w $iplot $Told($w) $Yold $Tnew($w) $Ynew
                    incr iplot; #each var gets an id NOT each element here
                }
            }
        }
    }
    
    proc plot_Y {w iplot Told Yold Tnew Ynew} {
        global ::graphtools::plot
        global errorInfo
        
        if {[llength $Ynew]==1} then {
            set colour [lindex $plot($w,YColours) $iplot]
            #puts "plot_Y iplot $iplot; lindex $plot($w,YColours) $iplot [lindex $plot($w,YColours) $iplot]"
            if {[catch {
                    adjustLimits $w $Tnew $Ynew
                    drawPoint $w $Told $Yold $Tnew $Ynew $colour
                } errMessage]} {
                if {[string is integer %Ynew] || [string is double $Ynew]} {
                    ErrorHelp $errorInfo
                } else  {
                    set xm [expr $plot($w,xborder_left)+60]
                    set ym [expr $plot($w,yborder_top)+60]
                    $w.canvas create text $xm $ym -tags prompt -width 100 -justify center\
                            -text "Some values resulting from maths errors have not been plotted"
                }
            }
        } else {
            array set Ynew_array $Ynew
            array set Yold_array $Yold
            foreach element [array names Ynew_array] {
                if {[info exists Yold_array($element)]} {
                    plot_Y $w $iplot $Told $Yold_array($element) $Tnew \
                            $Ynew_array($element)
                    ################################################################################
                    #                     if {$plot($w,IdArrayElements)} {
                    #                         incr iplot; # would give element of an array a unique id, eg for colour
                    #                     }
                    ################################################################################
                }
            }
        }
    }
    
    
    
    # Connect two points on the graph
    proc drawPoint { w X0 Y0 X1 Y1 Colour } {
        global ::graphtools::plot
        
        set x0 [get_x $w $X0 $plot($w,Tscale)]
        set x1 [get_x $w $X1 $plot($w,Tscale)]
        set y0 [get_y $w $Y0 $plot($w,Yscale)]
        set y1 [get_y $w $Y1 $plot($w,Yscale)]
        
        if {$x0<$x1} {
            $w.canvas create line $x0 $y0 $x1 $y1 \
                    -fill $Colour -tags {graph scalable xaxis_item yaxis_item}
        }
    }
    
    
    
    # clear graph
    proc clear { w } {
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::plot
        
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
        set YYold($w) {}
        set YYnew($w) {}
        
        $w.canvas delete prompt
        drawGraphpad $w
        display $w [GetModelTime] 0 0
        display $w [GetModelTime] 0 0
    }
    
    proc adjustLimits {w Tnew Ynew} {
        global ::graphtools::plot
        global runState
        
        if { ( $Tnew>$plot($w,Xmax_axis) || ($Tnew<$plot($w,Xmin_axis)) )} {
            if {$Tnew>$plot($w,Xmax_axis)} {
                set plot($w,Xmax_data) [expr {[GetModelTime]+$runState(execTime)}]
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
            
            set Trange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
            
            set scaleChange [expr {$OldRange/$Trange}]
            set plot($w,Tscale) [expr $Trange/$plot($w,xlength)]
            set x0 $plot($w,xborder_left)
            set y0 $plot($w,yborder_top)
            $w.canvas scale xaxis_item $x0 $y0 $scaleChange 1
            
            set xmove [expr {\
                [get_x $w $OldXmin_axis $plot($w,Tscale)] \
                        -[get_x $w $plot($w,Xmin_axis) $plot($w,Tscale)] }]
            $w.canvas move xaxis_item $xmove 0
            
            draw_Xaxis $w
        }
        if { ( ($Ynew>$plot($w,Ymax_axis)) || ($Ynew<$plot($w,Ymin_axis)) )} {
            #       ShowMessage debug info "$Ynew $plot($w,Ymin_data) $plot($w,Ymax_data)\
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
            #puts "adjustLimits plot($w,Yprecision) $plot($w,Yprecision)"
            set plot($w,Yminorstep) [expr {$plot($w,Ymajorstep)/2}]
            set Yrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
            set scaleChange [expr {$OldYrange/$Yrange}]
            #        ShowMessage debug info "$plot($w,Ymin_data) $plot($w,Ymax_data) \
            #                $plot($w,Ymin_axis) $plot($w,Ymax_axis) \
            #                $plot($w,Ymajorstep) $numInt $scaleChange" ok
            
            set plot($w,Yscale) [expr {$Yrange/$plot($w,ylength)}]
            set x0 $plot($w,xborder_left)
            #        ShowMessage debug info "$plot($w,Ymax_axis) $OldYmax_axis \
            #                $plot($w,Yscale)\
            #                [expr {($plot($w,Ymax_axis)-$OldYmax_axis)*$plot($w,Yscale)}]" ok
            
            set y0 $plot($w,yborder_top)
            $w.canvas scale yaxis_item $x0 $y0 1 $scaleChange
            
            set ymove [expr {\
                -[get_y $w $plot($w,Ymax_axis) $plot($w,Yscale)]\
                        +[get_y $w $OldYmax_axis $plot($w,Yscale)] }]
            $w.canvas move yaxis_item 0 $ymove
            
            draw_Yaxis $w
        }
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
        
        set YYold($w) $YYnew($w)
        
        set YYnew($w) [list 1 2]
        set YYnew($w) [lreplace $YYnew($w) 0 end]
        foreach node $plot($w,Yvars) {
            set values [GetModelValue $node]
            set values [lindex $values 0]
            lappend YYnew($w) [list $node $values]
            #        ShowMessage debug info "$YYnew($w)" ok
        }
    }
    
    proc RemoveVariableDlg {w} {
        global ::graphtools::plot
        
        set dlg [Dialog .plotterRemoveDlg -parent $w -title "Remove variable" \
                -modal local -default 0 -cancel 1]
        $dlg add -name ok; # buttons 0
        $dlg add -name cancel
        
        set mainF [$dlg getframe]
        
        listbox $mainF.listbox
        pack $mainF.listbox -padx 10 -pady 10 -expand on -fill both
        
        foreach item $plot($w,Ylabels) {
            $mainF.listbox insert end $item
        }
        
        # copy the values from the temp values to those to be edited if OK clicked
        if {[$dlg draw] == 0} {
            # OK button was clicked
            set index [$mainF.listbox curselection]
            if {![string match "" $index]} {
                set plot($w,Ylabels) [lreplace $plot($w,Ylabels) $index $index]
                set plot($w,Yvars) [lreplace $plot($w,Yvars) $index $index]
                drawGraphpad $w
            }
        }
        #ShowMessage debug info "$::graphtools::plot($w,DrawLines) $::graphtools::plot($w,DrawPoints)" ok
        
        destroy $dlg
        
    }
    
    
    # end of namespace
} ;

