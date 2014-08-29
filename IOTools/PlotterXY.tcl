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
    
    proc LoadTools {} {
	namespace import -force ::graphtools::*
	namespace import -force ::canvasnotes20070919::*
    }

    proc initialize {w} {
        global ::graphtools::plot
        #    global ::graphtools::Xvalues
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        variable ynodes
        variable xnodes
        
        LoadTools
        InitPlotVars $w
        InitPlatformDependentPlotVars $w
        
        set YYold($w) {}
        set YYnew($w) {}
        set Told($w) {}
        set Tnew($w) {}
        set ynodes($w) {}
        set xnodes($w) {}
        
        SetState $w {}
        
        ShowHelper $w
	AddVariable $w
    }
    
    proc InitPlotVars {w} {
        global ::graphtools::plot
        set plot($w,nodeCount) 0
        
        set plot($w,xwindow_size) 0
        set plot($w,ywindow_size) 0
        
        # Number of graticule divisions on axis.
        set plot($w,AxisDivisions) 10
        
        # choose colours for variables
        set plot($w,YColours) [list #0000ff #ff0000 #00ff00 #007777 #777700 \
                #770077 #222244 #442222 #224422]
                set plot($w,Xmax_axis) -1e20
        set plot($w,Xmin_axis) 1e20
        set plot($w,Xmax_data) -1e20
        set plot($w,Xmin_data) 1e20
        set plot($w,Xmajorstep) 0.5
        set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,XaxisLabel) {}
        set plot($w,Ymax_axis) -1e20
        set plot($w,Ymin_axis) 1e20
        set plot($w,Ymax_data) -1e20
        set plot($w,Ymin_data) 1e20
        set plot($w,Ymajorstep) 2
        set plot($w,Yminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
        set plot($w,Ylabels) {}
        set plot($w,Yvars)   {}
        set plot($w,Xvars)   {}
        set plot($w,redraw) 0
        set plot($w,topright) 1
        set plot($w,xlength) 350
        set plot($w,ylength) 200
        set plot($w,xborder_left) 50
        set plot($w,xborder_right) 15
        set plot($w,yborder_top) 30
        set plot($w,yborder_bottom) 30
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
        
        set plot($w,grid) off
        set plot($w,DrawLines) 1
        set plot($w,DrawPoints) 0
        set plot($w,CurrentOnly) 0
        set plot($w,ordinal) 0
    }
    
    proc Restore {winId} {
        #    ShowMess debug info "plotter.tcl Restore $winId" ok
        global ::graphtools::plot
        #    global ::graphtools::Xvalues
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        variable ynodes
        variable xnodes
        
        LoadTools
        InitPlotVars $winId
        set YYold($winId) {}
        set YYnew($winId) {}
        set Told($winId) {}
        set Tnew($winId) {}
        
        regsub -all /WIN/ [GetState $winId] $winId restoreString
        array set plot $restoreString
        InitPlatformDependentPlotVars $winId
        #ShowMess debug info "ys $plot($winId,Yvars) xs $plot($winId,Xvars)" ok
# 'foreach' changed to 'set' -- only one node can be plotted so all it did was
# cause errors if the names had spaces
        set path $plot($winId,Yvars) ;# {
            set node [GetIdFromCaptionPath $path]
            if {[string equal nomatch $node]} {
                set node $path
            }
            lappend ynodes($winId) $node
#        }
        set path $plot($winId,Xvars) ;# {
            set node [GetIdFromCaptionPath $path]
            if {[string equal nomatch $node]} {
                set node $path
            }
            lappend xnodes($winId) $node
#        }
        ShowHelper $winId
        display $winId [GetModelTime] 0 0
        display $winId [GetModelTime] 0 0
	if {![info exists plot($winId,stringInfo)]} return
	RestoreNotesFromList [GetCanvas $winId] $plot($winId,stringInfo)
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
    
    proc GetCanvas {winId} {
        return $winId.canvas
    }
    
    proc click {w node caption} {
        #       tk_messageBox -message "Click node $caption $node" -type ok
        global ::graphtools::plot
        variable ynodes
        variable xnodes
        
        set newbox nodebox[incr plot($w,nodeCount)]
        set name [GetCaptionPathFromId $node]
        
        set testResult [GetModelValue $node]
        if {[string compare $testResult novalue]} {
            switch $plot($w,state) {
                xcoord {
                    set plot($w,Xvars) $name
                    set xnodes($w) $node
                    set plot($w,XaxisLabel) $caption
                    set plot($w,state) ycoord
                    
                    $w.mess config -text "Select y variable: click on a variable in \
                            the Explorer window or a Model Diagram."
                    GrabClicks $w
                }
                ycoord {
                    set plot($w,Yvars) $name
                    #ShowMess debug info "x $xnodes($w) [GetModelDims $xnodes($w)]" ok
                    #ShowMess debug info "y $node [GetModelDims $node]" ok
                    #############  GET DIMENSIONS
                    set xdim  [GetModelDims $xnodes($w)]
                    set ydim  [GetModelDims $node]
                    if {$xdim != $ydim} {
                        ShowMess Error info \
                        "x and y dimensions do not match lease choose another y variable." ok
                        return
                    }
                    set ynodes($w) $node
                    lappend plot($w,Ylabels) $caption; # allow more than one pair of var
                    set useNodes($w,state) display
                    drawGraphpad $w
                    UpdateState $w
                    ReleaseClicks $w
                    $w.mess config -text {}; # clear prompt
                    display $w [GetModelTime] 0 0
                    display $w [GetModelTime] 0 0
#                    $w.bbframe.buttonBox itemconfigure 1 -state disable; #disable the add var button
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
    
    proc reset {winId} {
        global ::graphtools::YYold
        global ::graphtools::YYnew
        global ::graphtools::Told
        global ::graphtools::Tnew
        
        set YYold($winId) {}
        set YYnew($winId) {}
        set Told($winId) {}
        set Tnew($winId) {}
    }
    
    # Invoked at every time interval.
    proc display {w time step remainder} {
        global ::graphtools::plot
        #    global ::graphtools::Xvalues
        
        get_Yvalues $w
        get_Xvalues $w
        
# remove plots that are over persistence limit -- currently counts in displays
	set seq [incr plot($w,ordinal)]
	set plot($w,time$seq) $time
        if {$plot($w,CurrentOnly)} {
	    set expired [expr {$seq-$plot($w,CurrentOnly)}]
            $w.canvas delete trace$expired
        }
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
        
        if {[string match [winfo toplevel $w] $w] && \
		![string length [$w cget -use]]} {
            menu $w.menubar -tearoff 0
            $w.menubar add cascade -label Menu -menu $w.menu
            $w configure -menu $w.menubar
        } else  {
            # not yet todo        .mre.menubar insert Help cascade -label Plotter -menu $w.menu
        }
        
        set toolbarItems [list \
                [list clear.gif "Clear" [namespace code "clear $w"] ] \
                [list property.gif " Properties " [namespace code "Settings $w"]]\
			  [list text.gif " Add text " \
			       [namespace code "DialogInMiddle $w"]]]
        #            [list remove.gif "Remove variable" [namespace code "RemoveVariable $w" ]]]
        #    [list " settings " [namespace code "settings $w"]] \
        #    [list " redraw " [namespace code "resetGraph $w"]]
        ::graphtools::MakeToolBar $w $toolbarItems
        
        pack [label $w.mess] ;# for instructions
        
        # create canvas for graph
        canvas $w.canvas \
	    -width [expr $plot($w,xborder_left)+$plot($w,xlength)+ \
			$plot($w,xborder_right)] \
	    -height [expr $plot($w,yborder_bottom)+$plot($w,ylength)+ \
			 $plot($w,yborder_top)] \
	    -bg $plot($w,canvas_colour) -relief solid
	$w.canvas bind graph <Enter> [namespace code [list TracePopup $w %X %Y]]
	$w.canvas bind graph <Leave> RemovePopup
	MakeCanvasAnnotatable $w.canvas
        pack $w.canvas -fill both -expand true -side bottom
    }
	
	proc AddVariable { winId } {
	    global ::graphtools::plot
	    
	    #set xm [expr $plot($winId,xborder_left)+60]
	    #set ym [expr $plot($winId,yborder_top)+20]
	    #$winId.canvas create text $xm $ym -tags prompt -width 100 -justify center\
		-text "Select the x axis variable by clicking on a variable in the Explorer window\
                or a Model Diagram."
	    $winId.mess config -text "Select x variable: click on a variable in \
                the Explorer window or a Model Diagram."
	    
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
	
	proc Settings {w} {
	    # copy the values of the variables to be edited to temp, but namespace accessible, variables
	    variable DrawLines $::graphtools::plot($w,DrawLines)
	    variable DrawPoints $::graphtools::plot($w,DrawPoints)
	    variable CurrentOnly $::graphtools::plot($w,CurrentOnly)
	    
	    
	    set dlg [PutItThere .plotxyprop $w]
	    wm title $dlg [tr. "XY Plotter properties"]
	    
	    set chkF [frame [GetFrame $dlg].checkbuttons -relief groove]
	    
	    pack [ttk::labelframe $chkF.drawlinesF -text "Draw lines between points"] -fill x
	    pack [checkbutton $chkF.drawlinesF.cbutton -variable [namespace current]::DrawLines] -side right
	    pack [ttk::labelframe $chkF.drawpointsF -text "Draw points"] -fill x
	    pack [checkbutton $chkF.drawpointsF.cbutton -variable [namespace current]::DrawPoints] -side right
	    pack [ttk::labelframe $chkF.currentOnlyF -text "Persistence (0 for indefinite)"] -fill x
	    pack [entry $chkF.currentOnlyF.cbutton -textvariable [namespace current]::CurrentOnly] -side right
	    
	    pack $chkF -padx 10
	    
	    pack [frame $dlg.btnfr]
	    pack [button $dlg.btnfr.ok -text [tr. OK] \
		      -command "set ::graphtools::plot(xdone) 1"] -side right
	    pack [button $dlg.btnfr.cancel -text [tr. Cancel] \
		      -command "set ::graphtools::plot(xdone) 0"] -side right
	    LetItShow $dlg
	    grab $dlg
	    tkwait variable ::graphtools::plot(xdone)
	    grab release $dlg
	    PackItUp $dlg
	    # copy the values from the temp values to those to be edited if OK clicked
	    if {$::graphtools::plot(xdone)} {
 		# OK button was clicked
		set ::graphtools::plot($w,DrawLines) $DrawLines
		set ::graphtools::plot($w,DrawPoints) $DrawPoints
		set ::graphtools::plot($w,CurrentOnly) $CurrentOnly
		UpdateState $w
	    }
	}
	
	proc PrepareSaveString {w} {
	    set ::graphtools::plot($w,stringInfo) [ListNotes [GetCanvas $w]]
	    UpdateState $w
	}

	### Draw everything except the actual data points.
	proc drawGraphpad {w} {
	    global ::graphtools::plot
	    
	    # save text
	    set notes [ListNotes $w.canvas]
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
		-text $plot($w,XaxisLabel) -anchor s \
		-tags {movable scalable xaxis_label markable toplevel}
	    $w.canvas create text 5 [expr $y0-$plot($w,ylength)/2.0] \
		-text [lindex $plot($w,Ylabels) 0] -anchor w \
		-tags {movable scalable xaxis_label markable toplevel}
	    
	    # legend vars only not elements of arrays
	    # for now, legend nothing
	    #        set nYlabel [llength $plot($w,Ylabels)]
	    #        set j 0
	    #        set k 0
	    #        for {set i 0} {$i<$nYlabel} {incr i} {
	    #            set x [expr $plot($w,x_Ylabels)+$k*$plot($w,xstep_Ylabels)]
	    #            set y [expr $plot($w,y_Ylabels)+$j*$plot($w,ystep_Ylabels)]
	    #            set xa [expr $x-15]
	    #            set xb [expr $x-2]
	    #            set ya [expr $y+8]
	    #            set vartag {}
	    #            append vartag var $i
	    #            $w.canvas create line $xa $ya $xb $ya \
		#                    -fill [lindex $plot($w,YColours) $i] \
		#                    -width 2 \
		#                    -tags [list $vartag axis_label markable toplevel]
	    #            $w.canvas create text $x $y \
		#                    -text [lindex $plot($w,Ylabels) $i] \
		#                    -anchor nw \
		#                    -tags [list $vartag axis_label markable toplevel]
	    #            incr j
	    #            if {$j==2} {
	    #                incr k
	    #                set j 0
	    #            }
	    #        }
	    
	    ### Apply graticule and values to axis.
	    # drawGraticule $w $Xintercept $Yintercept
	    
	    $w.canvas raise toplevel
	    
	    ### Bindings
	    #$w.canvas bind axis_line <Double-1> \
		[namespace code "settings_axis $w"]
	    $w.canvas bind all <Button-1> \
                [namespace code "CanvasMark $w %x %y %W"]
	    $w.canvas bind movable <B1-Motion> \
                [namespace code "CanvasDrag %x %y %W"]
	    #$w.canvas bind xaxis_movable <B1-Motion> \
		[namespace code "Xstretch $w %W %x %y %w %h"]
	    #$w.canvas bind xslidable <B1-Motion> \
		[namespace code "Xslide $w %W %x %y; draw_Xaxis $w "]
	    ##    $w.canvas bind all <B1-Motion> \
		##            [namespace code "Ystretch $w %W %x %y %w %h"]
	    #$w.canvas bind yaxis_movable <B1-Motion> \
		[namespace code "Ystretch $w %W %x %y %w %h"]
	    #$w.canvas bind yslidable <B1-Motion> \
		[namespace code "Yslide $w %W %x %y; draw_Yaxis $w "]
	    #    $w.canvas bind xslidable <ButtonRelease-1> \
		#                    [namespace code "Reset_Xaxis $w"]; # event gets lost
	    #$w.canvas bind yaxis_movable <ButtonRelease-1> \
		[namespace code "draw_Yaxis $w"]
	    #$w.canvas bind xaxis_movable <ButtonRelease-1> \
		[namespace code "draw_Xaxis $w"]
	    
	    # whatever this is supposed to do, it fails to, even if nYlabel set
	    #        for {set i 0} {$i<$nYlabel} {incr i} {
	    #            set vartag {}
	    #            append vartag var $i
	    #            $w.canvas bind $vartag <B1-Motion> \
		#                    [namespace code "Ylabel_move %W %x %y"]
	    #        }
	    #        $w.canvas bind Ylabel
	    
	    
	    #$w.canvas bind graph <Motion> [namespace code ring_bell]
	    
	    bind $w <Configure> [namespace code "resize $w %W %x %y %w %h"]
	    bind $w.canvas <Configure> [namespace code "resize $w %W %x %y %w %h"]
	    
	    ################################################################################
	    #         $w.canvas bind xslidable <Enter> \
		#                 [namespace code "$w.canvas configure -cursor sb_h_double_arrow"]
	    #         $w.canvas bind yslidable <Enter> \
		#                 [namespace code "$w.canvas configure -cursor sb_v_double_arrow"]
	    #         $w.canvas bind yaxis_movable <Enter> \
		#                 [namespace code "$w.canvas configure -cursor fleur"]
	    #         $w.canvas bind xaxis_movable <Enter> \
		#                 [namespace code "$w.canvas configure -cursor fleur"]
	    #         $w.canvas bind all <Leave> \
		#                 [namespace code "$w.canvas configure -cursor arrow"]
	    ################################################################################
	    RestoreNotesFromList $w.canvas $notes
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
		
		set new_width [expr {max($width-$plot($w,xborder_left)- \
				   $plot($w,xborder_right),2)}]
		set new_height [expr {max($height-$plot($w,yborder_top)- \
				    $plot($w,yborder_bottom),2)}]
		
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
		
		set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]; #jmm
		set y2 [expr $y0+5]
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
		if {[llength [lindex $YYold($w) $i]]} {
		    set Ynew [lindex [lindex $YYnew($w) $i] 1]
		    set Yold [lindex [lindex $YYold($w) $i] 1]
		    set Xnew [lindex [lindex $Tnew($w) $i] 1]
		    set Xold [lindex [lindex $Told($w) $i] 1]
		    plot_Y $w $iplot $Xold $Yold $Xnew $Ynew {}
		}
		incr iplot
	    }
	    
	    ################################################################################
	    #             foreach {node Ynew} $YYnew($w) {node Yold} $YYold($w) \
		#                     {node Xnew} $Tnew($w) {node Xold} $Told($w) {
	    #             plot_Y $w $iplot $Xold $Yold $Xnew $Ynew
	    #             incr iplot
	    #         }
	    ################################################################################
	    ################################################################################
	    # set iplot 0
	    # foreach Ynew $YYnew($w) {
	    #     #puts "plot_YY Ynew $Ynew"
	    #     set node [lindex $Ynew 0]
	    #     foreach Yold $YYold($w) {
	    #         if {$node==[lindex $Yold 0]} {
	    #             plot_Y $w $iplot $Told($w) $Yold $Tnew($w) $Ynew
	    #             incr iplot; #each var gets an id NOT each element here
	    #         }
	    #     }
	    # }
	    # ###############################################################################
	    ################################################################################
	}
	###############################################################################
	
	proc plot_Y {w iplot Told Yold Tnew Ynew id} {
	    global ::graphtools::plot
	    
	    #ShowMess debug info "plt_Y_in Told $Told Yold $Yold Tnew $Tnew Ynew $Ynew" ok
	    if {[llength $Ynew]==1} then {
		if {[dodgyValue $Tnew] || [dodgyValue $Ynew]} {
		    set xm [expr $plot($w,xborder_left)+60]
		    set ym [expr $plot($w,yborder_top)+60]
		    $w.canvas delete prompt
		    $w.canvas create text $xm $ym -tags prompt -width 100 \
			-justify center -text [tr. "Some values resulting from maths errors have not been plotted"]
		} else {
		    set colour [lindex $plot($w,YColours) [expr {int(fmod($iplot,9))}]]
		    adjustLimits $w $Tnew $Ynew
		    #ShowMess debug info "drawPoint Told $Told Yold $Yold Tnew $Tnew Ynew $Ynew" ok
		    drawPoint $w $Told $Yold $Tnew $Ynew $colour $id
		}
	    } else {
		array set allYOld $Yold
		array set allTOld $Told
		array set allYNew $Ynew
		array set allTNew $Tnew
		foreach {i YnewV} $Ynew {
		    set TnewV $allTNew($i)
		    if {[info exists allYOld($i)]} {
			set YoldV $allYOld($i)
			set ToldV $allTOld($i)
			plot_Y $w [expr $iplot+$i] $ToldV $YoldV $TnewV $YnewV \
			    [concat $id [list $i]]
		    }
		}
	    }
	}
	
	proc TracePopup {w X Y} {
	    global ::graphtools::plot
	    
	    set tags [[GetCanvas $w] itemcget current -tags]
	    set timePt [string range [lsearch -inline $tags trace*] 5 end]
	    set idxPt [split [lsearch -inline $tags indices*] ,]
	    PostPopup $X $Y
	    set msg "Plot for value "
	    if {[llength $idxPt]>1} {
		append msg "with indices [join [lrange $idxPt 1 end] ,] "
	    }
	    append msg "at time $plot($w,time$timePt)"
	    AddPopupMessage $msg \#ffffc0
	}
	
	# Connect two points on the graph
	proc drawPoint { w X0 Y0 X1 Y1 Colour id } {
	    global ::graphtools::plot
	    
	    set x0 [get_x $w $X0 $plot($w,Tscale)]
	    set x1 [get_x $w $X1 $plot($w,Tscale)]
	    set y0 [get_y $w $Y0 $plot($w,Yscale)]
	    set y1 [get_y $w $Y1 $plot($w,Yscale)]
        
	set cTag trace$plot($w,ordinal)
	set iTag [join [concat indices $id] ,]
        if $plot($w,DrawLines) {
            $w.canvas create line $x0 $y0 $x1 $y1 -fill $Colour \
		-tags [list graph scalable xaxis_item yaxis_item $cTag $iTag]
            
        }
        if $plot($w,DrawPoints) {
            $w.canvas create text $x1 $y1 -text X -fill $Colour \
		-tags [list graph scalable xaxis_item yaxis_item $cTag $iTag]
            
        }
    }
    
    
    
    # clear graph
    proc clear { w } {
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
        display $w [GetModelTime] 0 0
        display $w [GetModelTime] 0 0
    }
    
    proc adjustLimits {w Tnew Ynew} {
        global ::graphtools::plot
        
        #    ShowMess debug info "adjustLimits $Tnew $Ynew" ok
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
            set numMinorInt 0
            AxisRound $plot($w,Xmin_data) $plot($w,Xmax_data) 0 \
                    plot($w,Xmin_axis) plot($w,Xmax_axis) \
                    plot($w,Xmajorstep) numInt plot($w,Xminorstep) numMinorInt plot($w,Xprecision)
            
            #set plot($w,Xmajorstep) [expr {$plot($w,Xmajorstep)/2}]
            #set plot($w,Xminorstep) [expr {$plot($w,Ymajorstep)/2}]
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
            set numMinorInt 0
            set OldYrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
            set OldYmax_axis $plot($w,Ymax_axis)
            #ShowMess debug info "$plot($w,Ymin_data) $plot($w,Ymax_data)" ok
            AxisRound $plot($w,Ymin_data) $plot($w,Ymax_data) 0 \
                    plot($w,Ymin_axis) plot($w,Ymax_axis) \
                    plot($w,Ymajorstep) numInt plot($w,Yminorstep) numMinorInt plot($w,Yprecision)
            #set plot($w,Yminorstep) [expr {$plot($w,Ymajorstep)/2}]
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
        global ::graphtools::YYold
        global ::graphtools::YYnew
        variable ynodes
        
        set YYold($w) $YYnew($w)
        
        set YYnew($w) {}
        foreach node $ynodes($w) {
            set values [GetModelValue $node]
            set values [lindex $values 0]
            lappend YYnew($w) [list $node $values]
            #        ShowMess debug info "$YYnew($w)" ok
        }
    }
    
    proc get_Xvalues {w} {
        global ::graphtools::Told
        global ::graphtools::Tnew
        variable xnodes
        
        set Told($w) $Tnew($w)
        set Tnew($w) {}
        foreach node $xnodes($w) {
            set values [GetModelValue $node]
            set values [lindex $values 0]
            lappend Tnew($w) [list $node $values]
            #        ShowMess debug info "$YYnew($w)" ok
        }
        
    }
    
    # end of namespace
} ;

