###############################################################################
#
# plotterxy.tcl
#
################################################################################

################################################################################
#Plotter bugs
#
#Not correct size initially
#scaling - use the auto-scale routines
################################################################################

# Conventions used:
# X,Y signify coordinates in user terms (year, kg or whatever),
#     or the actual X (time) and Y variables themselves, depending
#     on context.
# x,y signify canvas co-ordinates, in pixels.

set keyValue "plotterXY1.0"

namespace eval ::$keyValue {
    
    proc identify {} {
        return "XY Plotter"
    }
    
    proc initialize {w} {
        global ::graphtools::plot
        #    global ::graphtools::Xvalues
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        namespace import -force ::graphtools::*; # todo make graphtools common
        
        set plot($w,nodeCount) 0
        
        # puts $line "Start" ;#Bob
        
        set plot($w,xwindow_size) 0
        set plot($w,ywindow_size) 0
        
        # Number of graticule divisions on axis.
        set plot($w,AxisDivisions) 10
        
        # choose colours for variables
        set plot($w,YColours) [list #0000ff #ff0000 #00ff00 #007777 #777700 \
                #770077 #222244 #442222 #224422]
                set plot($w,Xmax_axis) -1e20; #max is 1e300
        set plot($w,Xmin_axis) 1e20
        set plot($w,Xmax_data) -1e20
        set plot($w,Xmin_data) 1e20
        set plot($w,Xmajorstep) 0.5
        set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,XaxisLabel) {}
        set plot($w,Ymax_axis) -1e20; #max is 1e300
        set plot($w,Ymin_axis) 1e20
        set plot($w,Ymax_data) -1e20
        set plot($w,Ymin_data) 1e20
        set plot($w,Ymajorstep) 2
        set plot($w,Yminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,Ylabels) {}
        set plot($w,Yvars)   {}
        set plot($w,redraw) 0
        set plot($w,topright) 1
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
        
        set plot($w,grid) off
        set plot($w,DrawLines) 1
        set plot($w,DrawPoints) 0
        
        #    set Xvalues($w) {}
        set YYold($w) {}
        set YYnew($w) {}
        set Told($w) {}
        set Tnew($w) {}
        
        SetState $w {}
        
        ShowHelper $w
    }
    
    proc Restore {winId} {
        #    ShowMessage debug info "plotter.tcl Restore $winId" ok
        namespace import -force ::graphtools::*; # todo make graphtools common
        global ::graphtools::plot
        #    global ::graphtools::Xvalues
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        #    set Xvalues($winId) {}
        set YYold($winId) {}
        set YYnew($winId) {}
        set Told($winId) {}
        set Tnew($winId) {}
        
        regsub -all /WIN/ [GetState $winId] $winId restoreString
        array set plot $restoreString
        #    ShowMessage debug info $restoreString ok
        ShowHelper $winId
    }
    
    proc GetCanvas {winId} {
        return $winId.canvas
    }

    proc click {w node caption} {
    #       tk_messageBox -message "Click node $caption $node" -type ok
    global ::graphtools::plot
    
    set xm [expr $plot($w,xborder_left)+60]
    set ym [expr $plot($w,yborder_top)+20]
    
    set newbox nodebox[incr plot($w,nodeCount)]
    set name [GetCaptionPathFromId $node]
    
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
        switch $plot($w,state) {
            xcoord {
                #               $ms configure -text "Now click on the value representing the Y coordinates."
                set plot($w,Xvars) $node
                set plot($w,XaxisLabel) $caption
                set plot($w,state) ycoord
                $w.canvas delete prompt
                $w.canvas create text $xm $ym -tags prompt -width 100 -justify center\
                        -text "Select the y axis variable by clicking on a variable in the Explorer window\
                        or a Model Diagram."
                GrabClicks $w
            }
            ycoord {
                #               $ms configure -text "Now select a value to determine the colour of the objects."
                set plot($w,Yvars) $node
                set plot($w,Ylabels) $caption
                set useNodes($w,state) display
                drawGraphpad $w
                UpdateState $w
                ReleaseClicks $w
                $w.canvas delete prompt
                raise $w; # bring the plotter back on top when it is a toplevel
            }
        }
        
        
        } else {
            #    $ms configure -text "This component does not have a value; please choose a variable to be plotted."
        }
    }
    
    proc Menu { winId } {
        set m [menu $winId.menu -tearoff 0]
        $m add command -label "Add variable" -command [namespace code "AddVariable $winId"]
        $m add command -label "Clear" -command [namespace code "clear $winId"]
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
        #    set Told($w) {}
        #    set Tnew($w) {}
        #    set Xvalues($w) {}
        
        drawGraphpad $w;
        
    }
    
    # Invoked at every time interval.
    proc display {w time step remainder} {
        global ::graphtools::plot
        #    global ::graphtools::Xvalues
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        get_Yvalues $w
        get_Xvalues $w
        
        #redraw axis and graph if necessary; otherwise just extend plots
        if {$plot($w,redraw)} {
            bell
            error {How did we get here?}
            drawGraphpad $w
            #		drawGraph $w
        } else {
            plot_YY $w
        }
    }
    
    # Draw panel containing controls and canvas for the graph.
    proc constructControlPanel {w} {
        #tk_messageBox -message "constructControlPanel winid $w" -type ok
        global checkstates
        global ::graphtools::plot
        
        Menu $w
        
        if {[PrefValue custom(helperManager) helperManager] } {
            # not yet todo        .mre.menubar insert Help cascade -label Plotter -menu $w.menu
        } else  {
            menu $w.menubar -tearoff 0
            $w.menubar add cascade -label Menu -menu $w.menu
            $w configure -menu $w.menubar
        }
        
        set toolbarItems [list \
                [list new.gif "Clear" [namespace code "clear $w"] ] \
                [list add.gif "Add a variable"   [namespace code "AddVariable $w"]] \
                [list property.gif " Properties " [namespace code "Settings $w"]]]
        #            [list remove.gif "Remove variable" [namespace code "RemoveVariable $w" ]]]
        #    [list " settings " [namespace code "settings $w"]] \
        #    [list " redraw " [namespace code "resetGraph $w"]] \
        
        
        ::graphtools::MakeToolBar $w $toolbarItems
        
        # create canvas for graph
        canvas $w.canvas \
                -width [expr $plot($w,xborder_left)+$plot($w,xlength)+ \
                $plot($w,xborder_right)] \
                -height [expr $plot($w,yborder_bottom)+$plot($w,ylength)+ \
                $plot($w,yborder_top)] \
                -bg $plot($w,canvas_colour) -relief solid
        pack $w.canvas -fill both -expand true -side bottom
    }
    
    proc AddVariable { winId } {
        global ::graphtools::plot
        
        set xm [expr $plot($winId,xborder_left)+60]
        set ym [expr $plot($winId,yborder_top)+20]
        $winId.canvas create text $xm $ym -tags prompt -width 100 -justify center\
                -text "Select the x axis variable by clicking on a variable in the Explorer window\
                or a Model Diagram."
        set plot($winId,state) xcoord
        GrabClicks $winId
    }
    
    proc RemoveVariable { winId } {
        global ::graphtools::plot
        
        set xm [expr $plot($winId,xborder_left)+60]
        set ym [expr $plot($winId,yborder_top)+20]
        $winId.canvas create text $xm $ym -tags prompt -width 100 -justify center\
                -text "Click  in legend area on the variable you want to remove."
        #    set plot($winId,Ylabels) [lreplace $plot($winId,Ylabels) $index $index]
        #tk_messageBox -message "plot($w,Ylabels) $plot($w,Ylabels)" -type ok
        #    set plot($winId,Yvars) [lreplace $plot($winId,Yvars) $index $index]
        #    drawGraphpad $winId
    }
    
    proc NoMoreVar {w} {
        ReleaseClicks $w
        $w.canvas delete prompt
    }
    
    proc Settings {w} {
        # copy the values of the variables to be edited to temp, but globally accessible, variables
        variable DrawLines $::graphtools::plot($w,DrawLines)
        variable DrawPoints $::graphtools::plot($w,DrawPoints)
        
        
        set dlg [Dialog .plotxyprop -parent $w -title "XY Plotter properties" \
                -modal local -default 0 -cancel 1]
        $dlg add -name ok; # buttons 0
        $dlg add -name cancel
        
        set chkF [frame [$dlg getframe].checkbuttons -relief groove]
        
        pack [LabelFrame $chkF.drawlinesF -text "Draw lines between points"] -fill x
        pack [checkbutton $chkF.drawlinesF.cbutton -variable [namespace current]::DrawLines] -side right
        pack [LabelFrame $chkF.drawpointsF -text "Draw points"] -fill x
        pack [checkbutton $chkF.drawpointsF.cbutton -variable [namespace current]::DrawPoints] -side right
        
        pack $chkF -padx 10
        
        # copy the values from the temp values to those to be edited if OK clicked
        if {[$dlg draw] == 0} {
            # OK button was clicked
            set ::graphtools::plot($w,DrawLines) $DrawLines
            set ::graphtools::plot($w,DrawPoints) $DrawPoints
        }
        #ShowMessage debug info "$::graphtools::plot($w,DrawLines) $::graphtools::plot($w,DrawPoints)" ok
        
        destroy $dlg
    }
    
    
    ### Draw everything except the actual data points.
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
        
        ### Blanking rectangles; # todo 2000 too big? jmm elsewhere too
        set x2 [expr $x1+5]
        $w.canvas create rectangle $x2 0 2000 2000 \
                -tags {blanket blanket_right} -outline {}\
                -fill $plot($w,canvas_colour)
        $w.canvas create rectangle 0 0 $x0 2000 \
                -tags {blanket blanket_left yslidable} -outline {}\
                -fill $plot($w,canvas_colour)
        set y2 [expr $y1]
        $w.canvas create rectangle 0 0 2000 $y2 \
                -tags {blanket blanket_top} -outline {}\
                -fill $plot($w,canvas_colour)
        set y2 [expr $y0+5]
        $w.canvas create rectangle 0 $y2 2000 2000 \
                -tags {blanket blanket_bottom xslidable} -outline {}\
                -fill $plot($w,canvas_colour)
        
        
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
                -text $plot($w,XaxisLabel) -anchor s \
                -tags {movable scalable xaxis_label markable toplevel}
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
        
        $w.canvas raise blanket
        $w.canvas raise toplevel
        
        ### Bindings
        $w.canvas bind axis_line <Double-1> \
                [namespace code "settings_axis $w"]
        $w.canvas bind all <Button-1> \
                [namespace code "CanvasMark $w %x %y %W"]
        $w.canvas bind movable <B1-Motion> \
                [namespace code "CanvasDrag %x %y %W"]
        $w.canvas bind xaxis_movable <B1-Motion> \
                [namespace code "Xstretch $w %W %x %y %w %h"]
        $w.canvas bind xslidable <B1-Motion> \
                [namespace code "Xslide $w %W %x %y; draw_Xaxis $w "]
        ##    $w.canvas bind all <B1-Motion> \
        ##            [namespace code "Ystretch $w %W %x %y %w %h"]
        $w.canvas bind yaxis_movable <B1-Motion> \
                [namespace code "Ystretch $w %W %x %y %w %h"]
        $w.canvas bind yslidable <B1-Motion> \
                [namespace code "Yslide $w %W %x %y; draw_Yaxis $w "]
        #    $w.canvas bind xslidable <ButtonRelease-1> \
        #                    [namespace code "Reset_Xaxis $w"]; # event gets lost
        $w.canvas bind yaxis_movable <ButtonRelease-1> \
                [namespace code "draw_Yaxis $w"]
        $w.canvas bind xaxis_movable <ButtonRelease-1> \
                [namespace code "draw_Xaxis $w"]
        
        for {set i 0} {$i<$nYlabel} {incr i} {
            set vartag {}
            append vartag var $i
            $w.canvas bind $vartag <B1-Motion> \
                    [namespace code "Ylabel_move %W %x %y"]
        }
        $w.canvas bind Ylabel
        
        
        #$w.canvas bind graph <Motion> [namespace code ring_bell]
        
        bind $w <Configure> [namespace code "resize $w %W %x %y %w %h"]
        
        $w.canvas bind xslidable <Enter> \
                [namespace code "$w.canvas configure -cursor sb_h_double_arrow"]
        $w.canvas bind yslidable <Enter> \
                [namespace code "$w.canvas configure -cursor sb_v_double_arrow"]
        $w.canvas bind yaxis_movable <Enter> \
                [namespace code "$w.canvas configure -cursor fleur"]
        $w.canvas bind xaxis_movable <Enter> \
                [namespace code "$w.canvas configure -cursor fleur"]
        $w.canvas bind all <Leave> \
                [namespace code "$w.canvas configure -cursor arrow"]
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

        if {[regexp (\.\[^.\]*)\.canvas $win full id]} {
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
            $w.canvas coords blanket_right $x2 0 2000 2000
            
            set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]; #jmm
            set y2 [expr $y0+5]
            $w.canvas coords blanket_bottom 0 $y2 2000 2000
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
        for  {set i 0} {$i < [llength $YYnew($w)]} {incr i} {
            set Ynew [lindex $YYnew($w) $i]
            set Yold [lindex $YYold($w) $i]
            set Xnew [lindex $Tnew($w) $i]
            set Xold [lindex $Told($w) $i]
            plot_Y $w $iplot $Xold $Yold $Xnew $Ynew
            incr iplot
        }
    }
    
    proc plot_Y {w iplot Told Yold Tnew Ynew} {
        global ::graphtools::plot
        
        #    ShowMessage debug info "plt_Y_in Told $Told Yold $Yold Tnew $Tnew Ynew $Ynew" ok
        if {[llength $Ynew]==1} then {
            set colour [lindex $plot($w,YColours) $iplot]
            adjustLimits $w $Tnew $Ynew
            #        ShowMessage debug info "drawPoint Told $Told Yold $Yold Tnew $Tnew Ynew $Ynew" ok
            drawPoint $w $Told $Yold $Tnew $Ynew $colour
        } else {
            for  {set i 1} {$i < [llength $Ynew] } {incr i 2} {
                set YnewV [lindex $Ynew $i]
                set YoldV [lindex $Yold $i]
                set TnewV [lindex $Tnew $i]
                set ToldV [lindex $Told $i]
                if {![string match "" $ToldV]} {
                    plot_Y $w $iplot $ToldV $YoldV $TnewV $YnewV
                }
                incr iplot
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
        
        if $plot($w,DrawLines) {
            $w.canvas create line $x0 $y0 $x1 $y1 \
                    -fill $Colour -tags {graph scalable xaxis_item yaxis_item}
            
        }
        if $plot($w,DrawPoints) {
            $w.canvas create text $x1 $y1 -text X \
                    -fill $Colour -tags {graph scalable xaxis_item yaxis_item}
            
        }
    }
    
    
    
    # clear graph
    proc clear { w } {
        bell
        #    global ::graphtools::Xvalues
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        global ::graphtools::plot
        
        set plot($w,Ymax_axis) -1e200
        set plot($w,Ymin_axis) 1e200
        set plot($w,Ymax_data) -1e200
        set plot($w,Ymin_data) 1e200
        set plot($w,Ymajorstep) 2
        set plot($w,Yminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,Xmax_axis) -1e200
        set plot($w,Xmin_axis) 1e200
        set plot($w,Xmajorstep) 0.5
        set plot($w,Xmax_data) -1e200
        set plot($w,Xmin_data) 1e200
        set plot($w,Xmajorstep) 2
        set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,Xprecision) 0
        set plot($w,Yprecision) 0
        #   set Xvalues($w) {}
        set YYold($w) {}
        set YYnew($w) {}
        set Told($w) {}
        set Tnew($w) {}
        
        drawGraphpad $w
    }
    
    proc adjustLimits {w Tnew Ynew} {
        global ::graphtools::plot
        variable scale_factor [list 2.0 2.5 2.0]
        
        #    ShowMessage debug info "adjustLimits $Tnew $Ynew" ok
        if { ( $Tnew>$plot($w,Xmax_axis) || ($Tnew<$plot($w,Xmin_axis)) )} {
            if {$Tnew>$plot($w,Xmax_axis)} {
                set plot($w,Xmax_data) $Tnew
            }
            if {$Tnew<$plot($w,Xmin_axis)} {
                set plot($w,Xmin_data) $Tnew
            }
            set OldRange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
            set OldXmin_axis $plot($w,Xmin_axis)
            
            set numInt 0
            AxisRound $plot($w,Xmin_data) $plot($w,Xmax_data) 1 \
                    plot($w,Xmin_axis) plot($w,Xmax_axis) \
                    plot($w,Xmajorstep) numInt plot($w,Xprecision)
            
            set plot($w,Xmajorstep) [expr {$plot($w,Xmajorstep)/2}]
            set plot($w,Xminorstep) [expr {$plot($w,Ymajorstep)/2}]
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
            if {$Ynew>$plot($w,Ymax_axis)} {
                set plot($w,Ymax_data) $Ynew
            }
            if {$Ynew<$plot($w,Ymin_axis)} {
                set plot($w,Ymin_data) $Ynew
            }
            set numInt 0
            set OldYrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
            set OldYmax_axis $plot($w,Ymax_axis)
#ShowMessage debug info "$plot($w,Ymin_data) $plot($w,Ymax_data)" ok
            AxisRound $plot($w,Ymin_data) $plot($w,Ymax_data) 0 \
                    plot($w,Ymin_axis) plot($w,Ymax_axis) \
                    plot($w,Ymajorstep) numInt plot($w,Yprecision)
            set plot($w,Yminorstep) [expr {$plot($w,Ymajorstep)/2}]
            set Yrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
            set scaleChange [expr {$OldYrange/$Yrange}]
            
            set plot($w,Yscale) [expr {$Yrange/$plot($w,ylength)}]
            set x0 $plot($w,xborder_left)
            
            set y0 $plot($w,yborder_top)
            $w.canvas scale yaxis_item $x0 $y0 1 $scaleChange
            
            set ymove [expr {\
                -[get_y $w $plot($w,Ymax_axis) $plot($w,Yscale)]\
                        +[get_y $w $OldYmax_axis $plot($w,Yscale)] }]
            $w.canvas move yaxis_item 0 $ymove
            
            draw_Yaxis $w
        }
    }
    
    proc marker {} {tk_messageBox -message "hello"}
    
    
    # redraw graph after adjusting limits to Coordinates range
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
    
    proc get_Xvalues {w} {
        global ::graphtools::plot
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        set Told($w) $Tnew($w)
        set Tnew($w) [list 1 2]
        set Tnew($w) [lreplace $Tnew($w) 0 end]
        foreach node $plot($w,Xvars) {
            set values [GetModelValue $node]
            set values [lindex $values 0]
            lappend Tnew($w) [list $node $values]
            #        ShowMessage debug info "$YYnew($w)" ok
        }
        
    }
    
    ######################################################################
    # proc get_x
    # proc get_y
    #
    # Scales data X and Y values to canvas coordinates (pixels)
    
    proc get_x {w X Xscale} {
        global ::graphtools::plot
        expr {$plot($w,xborder_left)+($X-$plot($w,Xmin_axis))/$Xscale}
    }
    
    proc get_y {w Y Yscale} {
        global ::graphtools::plot
        expr {$plot($w,yborder_top)+$plot($w,ylength) \
                    -($Y-$plot($w,Ymin_axis))/$Yscale}
    }
    
    # end of namespace
} ;

