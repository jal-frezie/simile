################################################################################
#
# piechart.tcl
#
################################################################################


# Conventions used:
# X,Y signify coordinates in user terms (year, kg or whatever),
#     or the actual X (time) and Y variables themselves, depending
#     on context.
# x,y signify canvas co-ordinates, in pixels.

# Draws ONE piechart any array or multi-instance submodel values get added to the ONE pie


set keyValue "piechart1.0"
    
namespace eval ::$keyValue {
    variable piesum
    variable pievalues
    
        
proc identify {} {
	return "Pie Chart"
}

proc initialize {w} {
    global ::graphtools::plot
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
    namespace import -force ::graphtools::*
    
    set plot($w,nodeCount) 0
    
    # puts $line "Start" ;#Bob
    
    set plot($w,xwindow_size) 0
    set plot($w,ywindow_size) 0
    
    # Number of graticule divisions on axis.
    set plot($w,AxisDivisions) 10
    
    # choose colours for variables
    set plot($w,YColours) [list #0000ff #ff0000 #00ff00 #007777 #777700 \
            #770077 #222244 #442222 #224422 #C0C0C0 #FFFFFF #FF00FF #00FFFF \
            #FFFF00 #FF3300 #FF9933 #0066CC #669999 #99FF66 ]
    set plot($w,Xmax_axis) 1
    set plot($w,Xmin_axis) 0
    set plot($w,Xmajorstep) 0.5
    set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
    set plot($w,XaxisLabel) {}
    set plot($w,Ymax_axis) -1e200; #max is 1e300
    set plot($w,Ymin_axis) 1e200
    set plot($w,Ymax_data) -1e200
    set plot($w,Ymin_data) 1e200
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
    set plot($w,xborder_right) 50
    set plot($w,yborder_top) 50
    set plot($w,yborder_bottom) 50
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
    set plot($w,linestyle) full
    set plot($w,pointstyle) circle
    set plot($w,LabelDistance) 30
    
    set Xvalues($w) {}
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
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
    set Xvalues($winId) {}
    set YYold($winId) {}
    set YYnew($winId) {}
    set Told($winId) {}
    set Tnew($winId) {}
    
    
    regsub -all /WIN/ [GetState $winId] $winId restoreString
    array set plot $restoreString
    #    ShowMessage debug info $restoreString ok
    ShowHelper $winId
    get_Yvalues $winId
    
    plot_YY $winId
}

proc GetCanvas {winId} {
    return $winId.canvas
}

proc click {w node caption} {
    #tk_messageBox -message "Click node $node" -type ok
    global ::graphtools::plot
    global ::graphtools::YYnew
    
    set newbox nodebox[incr plot($w,nodeCount)]
    set name [GetCaptionPathFromId $node]
    
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
        set values [lindex [GetModelValue $node] 0]
        #ShowMessage debug info "[llength $values] $values" ok
        #lappend plot($w,Ylabels) $caption
        if {[llength $values]==1} then {
            lappend plot($w,Ylabels) $caption
        } else {
            ArrayLabeling $w $caption $values {}
        }
        
        lappend plot($w,Yvars)   $node
        drawGraphpad $w
        UpdateState $w
    } else {
        #    $ms configure -text "This component does not have a value; please choose a variable to be plotted."
    }
    ReleaseClicks $w
    $w.canvas delete prompt
    
    get_Yvalues $w
            
    plot_YY $w        
}

proc ArrayLabeling { w caption values index } {
    global ::graphtools::plot
#    ShowMessage debug info "ArrayLabeling [llength $values] $values" ok
    if {[llength $values]==1} then {
        lappend plot($w,Ylabels) ${caption}/$index
    } else {
        array set val_array $values
        foreach element [lsort -decreasing [array names val_array]] {
            ArrayLabeling $w $caption $val_array($element) $element;
        }
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
    
    variable piesum
    variable pievalues
    
    constructControlPanel $w
    
    # Initialise values list.
    set Told($w) {}
    set Tnew($w) {}
    set Xvalues($w) {}
    
    set piesum($w) 0
    set pievalues($w) {}

    drawGraphpad $w;
    
    update
    resize $w win [winfo x $w.canvas] [winfo y $w.canvas] \
            [winfo width $w.canvas] [winfo height $w.canvas]
    Repaint $w
}

# Invoked at every time interval.
proc display {w time step remainder} {
    global ::graphtools::plot
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
    get_Yvalues $w 
#    get_Xvalues $w
    
	#redraw axis and graph if necessary; otherwise just extend plots
	if {$plot($w,redraw)} {
		bell
	
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
            [list add.gif "Add a variable"   [namespace code "AddVariable $w"]]]
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
            -text "Click on a variable in the Explorer window\
            or a Model Diagram."
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
    

################################################################################
#     set nYlabel [llength $plot($w,Ylabels)]
#     set j 0
#     set k 0
#     for {set i 0} {$i<$nYlabel} {incr i} {
#         set x [expr $plot($w,x_Ylabels)+$k*$plot($w,xstep_Ylabels)]
#         set y [expr $plot($w,y_Ylabels)+$j*$plot($w,ystep_Ylabels)]
#         set xa [expr $x-15]
#         set xb [expr $x-2]
#         set ya [expr $y+8]
#         set vartag {}
#         append vartag var $i
#         $w.canvas create line $xa $ya $xb $ya \
#                 -fill [lindex $plot($w,YColours) $i] \
#                 -width 2 \
#                 -tags [list $vartag axis_label markable toplevel]
#         $w.canvas create text $x $y \
#                 -text [lindex $plot($w,Ylabels) $i] \
#                 -anchor nw \
#                 -tags [list $vartag axis_label markable toplevel]
#         incr j
#         if {$j==2} {
#             incr k
#             set j 0
#         }
#     }
#     
################################################################################

    bind $w <Configure> [namespace code "resize $w %W %x %y %w %h; Repaint $w"]
}

proc resize {w win x y width height} {
  global ::graphtools::plot
    
#    ShowMessage debug info "resize" ok
    
    set old_width $plot($w,xlength)
    set old_height $plot($w,ylength)

    set new_width [expr $width-$plot($w,xborder_left)- \
            $plot($w,xborder_right)]
    set new_height [expr $height-$plot($w,yborder_top)- \
            $plot($w,yborder_bottom)]
    
    set width_diff [expr $new_width-$old_width]
    set height_diff [expr $new_height-$old_height]
    
    set plot($w,xlength) [expr $plot($w,xlength)+$width_diff]
    set plot($w,ylength) [expr $plot($w,ylength)+$height_diff]
}

proc Repaint {w} {
    global ::graphtools::plot
    global ::graphtools::YYnew
    global ::graphtools::Tnew
    variable piesum
    variable pievalues

    if  {$plot($w,xlength)>$plot($w,ylength)} {
        set length $plot($w,ylength)
    } else  {
        set length $plot($w,xlength)
    }
    set plot($w,length) $length
    
    set x1 $plot($w,xborder_left)
    set y1 [expr {$plot($w,yborder_top)}]
    set x2 [expr {$plot($w,xborder_left)+$length}]
    set y2 [expr {$plot($w,yborder_top)+$length}]

    set plot($w,cx) [expr {($x1+$x2)/2}]
    set plot($w,cy) [expr {($y1+$y2)/2}]
    
    $w.canvas delete all
    
    DrawPie $w $x1 $y1 $x2 $y2 $pievalues($w) $piesum($w)
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
    global ::graphtools::YYnew
    global ::graphtools::Tnew
    variable piesum
    variable pievalues
    
#    ShowMessage debug info "plot_YY" ok            
    set piesum($w) 0
    set pievalues($w) {}
    foreach Ynew $YYnew($w) {
#        ShowMessage debug info "$Ynew" ok
        plot_Y $w {} $Tnew($w) $Ynew
    }
    
    Repaint $w 
}

proc plot_Y {w index Tnew Ynew} {
    global ::graphtools::plot
    variable piesum
    variable pievalues
    
    if {[llength $Ynew]==1} then {
        if {$Ynew<0} { set Ynew 0 }
        set piesum($w) [expr {$piesum($w)+$Ynew}]
        lappend pievalues($w) $Ynew
    } else {
        array set Ynew_array $Ynew
        foreach element [lsort -decreasing [array names Ynew_array]] {
#            ShowMessage debug info "Ynew_array($element) $Ynew_array($element)" ok
            plot_Y $w $element $Tnew $Ynew_array($element)
        }
    }
}

proc DrawPie { w x1 y1 x2 y2 pievalues piesum } {
    global ::graphtools::plot
    
    if {($piesum==0) && ([llength $pievalues] > 0)} {
#        return
        $w.canvas create text $plot($w,cx) $plot($w,cy) -text "Sum of all values is negative" -tag label
    } else  {
    set iplot 0
    set StartAngle 0
    foreach value $pievalues {
        set colour [lindex $plot($w,YColours) \
                [expr {int(fmod($iplot,[llength $plot($w,YColours)]))}]]
        set Angle [expr {360*$value/$piesum}]
        set LabelAngle [expr {$Angle/2+$StartAngle}]; # degrees
        set r [expr {$plot($w,LabelDistance)+$plot($w,length)/2}]
        set x [expr {$r*cos($LabelAngle*3.14159/180.0)+$plot($w,cx)}]
        set y [expr {-1.0*$r*sin($LabelAngle*3.14159/180.0)+$plot($w,cy)}]
        $w.canvas create arc $x1 $y1 $x2 $x2 \
                -fill $colour -start $StartAngle -extent $Angle -tags "scalable slice"
        $w.canvas create text $x $y -text [lindex $plot($w,Ylabels) $iplot] -tag label
        incr iplot
        set StartAngle [expr {$StartAngle+$Angle}]
    }
}
}

# clear graph
proc clear { w } {
	bell
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::plot
    
    set plot($w,Ymax_axis) -1e200
    set plot($w,Ymin_axis) 1e200
    set plot($w,Ymax_data) -1e200
    set plot($w,Ymin_data) 1e200
    set plot($w,Ymajorstep) 2
    set plot($w,Yminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
    set plot($w,Xmax_axis) 1
    set plot($w,Xmin_axis) 0
    set plot($w,Xmajorstep) 0.5
    set plot($w,Xmax_data) 0
    set plot($w,Xmin_data) 0
    set plot($w,Xmajorstep) 0.5
    set plot($w,Xminorstep) [expr {$plot($w,Xmajorstep)/2.0}]
    set plot($w,Xprecision) 0
    set plot($w,Yprecision) 0
    set Xvalues($w) {}
	set YYold($w) {}
	set YYnew($w) {}

	drawGraphpad $w
}

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
##        set YYnew($w) [lindex $values 0]
        
        lappend YYnew($w) [list $node $values]
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

