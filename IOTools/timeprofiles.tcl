################################################################################
#
# timeprofiles.tcl
#
################################################################################

# Robert Muetzelfeldt
# 21/3/01
#
# This produces a separate time plot for each instance.   The time plot shows
# the value for each of several variables as a set of solid blocks stacked
# on top of each other, for each display interval.   A typical use would be
# to show the household composition (number of children, makes, females,
# oldies) for a number of households, changing over time.
#
# It's derived from the 'Plotter' display tool (since the setup and display
# issues are pretty similar).
#
# Conventions used:
# X,Y signify coordinates in user terms (year, kg or whatever),
#     or the actual X (time) and Y variables themselves, depending
#     on context.
# x,y signify canvas co-ordinates, in pixels.

set keyValue "timeprofiles1.0"

namespace eval ::$keyValue {

proc identify {} {
	return "Time profiles"
}

proc initialize {w} {
    global ::graphtools::plot
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
    namespace import -force ::graphtools::*; # todo make graphtools common
    
    set plot($w,xwindow_size) 0
    set plot($w,ywindow_size) 0
    
    # Number of graticule divisions on axis.
    set plot($w,AxisDivisions) 10
    
    # choose colours for variables
    set plot($w,YColours) [list #0000ff #ff0000 #00ff00 #007777 #777700 \
            #770077 #222244 #442222 #224422]
            set plot($w,Xmax_axis) 10
    set plot($w,Xmin_axis) 0
    set plot($w,Xmajorstep) 2
    set plot($w,Xminorstep) [expr $plot($w,Xmajorstep)/2.0]
    set plot($w,Ymax_axis) 500
    set plot($w,Ymin_axis) 0
    set plot($w,Ymajorstep) 2
    set plot($w,Yminorstep) [expr $plot($w,Ymajorstep)/2.0]
    set plot($w,Ylabels) {}
    set plot($w,Yvars)   {}
    set plot($w,redraw) 0
    set plot($w,topright) 1
    set plot($w,grid) on
    set plot($w,xlength) 350
    set plot($w,ylength) 500
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
    set plot($w,fontValues) [myAssembleFont Helvetica Bold R 120]
    set plot($w,fontLabels) [myAssembleFont Helvetica Bold R 120]
    set plot($w,fontTitle) [myAssembleFont Helvetica Bold R 120]
    set plot($w,canvas_colour) #e0e0e0
    set plot($w,grapharea_colour) white
    set plot($w,pointer) 1
    set plot($w,X_scalestep) 0
    set plot($w,Y_scalestep) 0
    set plot($w,Xprecision) 1
    set plot($w,Yprecision) 1
    
    set plot($w,x0) $plot($w,xborder_left)
    set plot($w,x1) [expr $plot($w,xborder_left)+$plot($w,xlength)]
    set plot($w,y0) [expr $plot($w,yborder_top)+$plot($w,ylength)]
    set plot($w,y1) $plot($w,yborder_top)
    
    set Xvalues {}
    set YYold($w) {}
    set YYnew($w) {}
    set Told($w) 0
    set Tnew($w) 0
    
    set ms [message $w.intro -text "Click on the variable giving a unique ID for each instance."]
    
    # attach procedure 'ShowHelper' to 'OK' button.
    button $w.ok -text "OK" -command [namespace code "OnOk $w"]
    set plot($w,i) -1
    GrabClicks $w
    pack $ms
    set plot($w,State) firstYvariable
    SetState $w {}
}

proc OnOk { w } {
    pack forget $w.intro $w.ok
#    destroy $w.intro $w.ok; # causes hang in mre!! todo
    ReleaseClicks $w
    ShowHelper $w
}

proc Restore {winId} {
    #ShowMessage debug info "timeprofiles.tcl Restore $winId" ok
    namespace import -force ::graphtools::*; # todo make graphtools common
    global ::graphtools::plot
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
    set Xvalues {}
    set YYold($winId) {}
    set YYnew($winId) {}
    set Told($winId) 0
    set Tnew($winId) 0
    
    regsub -all /WIN/ [GetState $winId] $winId restoreString
    array set plot $restoreString
    #ShowMessage debug info $restoreString ok
    ShowHelper $winId
}

proc GetCanvas {winId} {
    return $winId.canvas
}

proc click {w node caption} {
    global ::graphtools::plot
    set ithlist [list 1st 2nd 3rd 4th 5th 6th 7th 8th 9th 10th]
    set ms $w.intro
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
        incr plot($w,i)
        set ith [lindex $ithlist $plot($w,i)]
        switch $plot($w,State)   {
            firstYvariable {
                $ms configure -text "Click on the 1st profile variable."
                pack $ms $w.ok
                lappend plot($w,Ylabels) $caption
                lappend plot($w,Yvars)   $node
                set plot($w,State) Yvariable
            }
            Yvariable {
                lappend plot($w,Ylabels) $caption
                lappend plot($w,Yvars)   $node
                $ms configure -text "Click on the $ith profile variable, or \
                        click on the OK button to finish."}
        }
        UpdateState $w
        #ShowMessage debug info "Click after UpdateState" ok
    } else { $ms configure -text "This component does not have a value; please choose a variable to be plotted." }
}

# Called at start up only
proc ShowHelper {w} {
    global ::graphtools::plot
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
################################################################################
#     if [winfo exists $w.ok] {
#         destroy $w.ok
#     }
# #    ShowMessage debug info "ShowHelper ere constructControlPanel" ok
################################################################################
    constructControlPanel $w
#    ShowMessage debug info "ShowHelper af constructControlPanel" ok
    
    # Initialise values list.
    set Told($w) 0
    set Tnew($w) 0
    set Xvalues 0
    get_Yvalues $w
    #puts$line "YYnew $YYnew($w)"
    
    set plot($w,Xmin_data) 0
    set plot($w,Xmax_data) 0
    set min 0; # scaling todo
    set plot($w,Ymin_data) $min
    set max 10; # scaling todo
    set plot($w,Ymax_data) $max
    
    #adjustLimits $w
    
#    ShowMessage debug info "ShowHelper ere drawGraphpad ok
    drawGraphpad $w
#    ShowMessage debug info "ShowHelper af drawGraphpad ok
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

	lappend Xvalues $time

	set Told($w) $Tnew($w)
	set Tnew($w) $time
	set plot($w,Xmax_data) $time

	set min 0
	if {$min<$plot($w,Ymin_data)} {
		set plot($w,Ymin_data) $min
	}
	set max 10
	if {$max>$plot($w,Ymax_data)} {
		set plot($w,Ymax_data) $max
	}

	# Reset graph limits if any of new values exceed existing limits.
	#adjustLimits $w 

	#redraw axis and graph if necessary; otherwise just extend plots
	if {$plot($w,redraw)} {
		bell
	
		drawGraphpad $w
		drawGraph $w
	} else {
		plot_YY $w
	}
}
	
# Draw panel containing controls and canvas for the graph.
proc constructControlPanel {w} {
    #	global checkstates ; # isnt used jmm 20/4
#    ShowMessage debug info "constructControlPanel $w" ok
    global ::graphtools::plot
    
    frame $w.control -width 150 -height 24
    
    # create buttons
    frame $w.control.buttons
    foreach item  [list \
            [list "  clear   "   [namespace code "clear $w"]]] {
                set name [lindex $item 0]
                button $w.control.buttons.$name -text $name  \
                        -command [lindex $item 1]
        pack $w.control.buttons.$name -side left
    }
    pack propagate $w.control false
    pack $w.control -fill y -side bottom -fill y
    pack $w.control.buttons -side left
    
    
    
    # create canvas for graph
    canvas $w.canvas \
            -width [expr $plot($w,xborder_left)+$plot($w,xlength)+ \
            $plot($w,xborder_right)] \
            -height [expr $plot($w,yborder_bottom)+$plot($w,ylength)+ \
            $plot($w,yborder_top)] \
            -bg $plot($w,canvas_colour) -relief solid
    pack $w.canvas -fill both -expand true -side bottom
#    ShowMessage debug info "end of constructControlPanel $w" ok
}

proc settings {w} {
	set wset .settings
	catch {destroy $wset}
	toplevel $wset
	wm title $wset "Plotter tool settings"

	# Create entry boxes
	frame $wset.entries 
	foreach item [list \
			[list xlow "X low" 0] \
			[list xhigh "X high" 10] \
			[list xinterval "X interval" 1] \
			[list ylow "Y low" 0] \
			[list yhigh "Y high" 10] \
			[list yinterval "Y interval" 1]] {
		set name [lindex $item 0]
		entry $wset.entries.$name
		$wset.entries.$name insert 0 [lindex $item 2] 
		pack $wset.entries.$name }
	pack $wset.entries -side top
   
	# create checkbutton options
	frame $wset.checkbuttons
	foreach item [list \
			[list horizlines "Horizontal lines" \
				-command [namespace code "horizlines $w"]] \
			[list vertlines "Vertical lines" \
				-command [namespace code "vertlines $w"]] \
			[list box "Boxed" \
				-command [namespace code "boxed $w"]]] {
		set name [lindex $item 0]
		checkbutton $wset.checkbuttons.$name
		pack $wset.checkbuttons.$name }
	pack $wset.checkbuttons -side top
}


### Draw everything except the actual data points.
proc drawGraphpad {w} {
    global ::graphtools::plot
    #ShowMessage debug info "dGP" ok
	### rub out previous graph
	$w.canvas delete all

	### Convenience variables
	set x0 $plot($w,xborder_left)
	set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
	set x1 [expr $plot($w,xborder_left)+$plot($w,xlength)]
	set y1 $plot($w,yborder_top)
	set x2 [expr $x1+$plot($w,xborder_right)]
	set y2 [expr $y0+$plot($w,yborder_bottom)]

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
	#draw_Yaxis $w

	### Blanking rectangles
	$w.canvas create rectangle [expr $x1+5] 0 $x2 $y2\
		-tags {blanket blanket_right} \
		-outline $plot($w,canvas_colour) \
		-fill $plot($w,canvas_colour)
	$w.canvas create rectangle 0 0 [expr $x0-1] $y2 \
		-tags {blanket blanket_left yslidable} \
		-outline $plot($w,canvas_colour) \
		-fill $plot($w,canvas_colour)
	$w.canvas create rectangle 0 0 $x2 [expr $y1-1] \
		-tags {blanket blanket_top} \
		-outline $plot($w,canvas_colour) \
		-fill $plot($w,canvas_colour)
	$w.canvas create rectangle 0 [expr $y0+5] $x2 $y2 \
		-tags {blanket blanket_bottom xslidable} \
		-outline $plot($w,canvas_colour) \
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
		-text "Time" -anchor s \
		-font $plot($w,fontValues) \
		-tags {movable scalable xaxis_label markable toplevel}
	set nYlabel [llength $plot($w,Ylabels)]
	set j 0
	set k 0
	for {set i 1} {$i<$nYlabel} {incr i} {
		set x [expr $plot($w,x_Ylabels)+$k*$plot($w,xstep_Ylabels)]
		set y [expr $plot($w,y_Ylabels)+$j*$plot($w,ystep_Ylabels)]
		set xa [expr $x-18]
		set xb [expr $x-2]
		set ya [expr $y+3]
		set yb [expr $y+11]
		set vartag {}
		append vartag var $i
		$w.canvas create rectangle $xa $ya $xb $yb \
			-fill [lindex $plot($w,YColours) $i] \
			-tags [list $vartag axis_label markable toplevel swatch$i]
		$w.canvas create text $x $y \
			-text [lindex $plot($w,Ylabels) $i] \
			-font $plot($w,fontValues) \
			-anchor nw \
			-tags [list $vartag axis_label markable toplevel]
		incr j
		if {$j==2} {
			incr k
			set j 0
		}
	}
	#$w.canvas create text 4 100 \
	#	-text "Vars" \
	#	-anchor nw \
	#	-width $plot($w,xborder_left) \
	#	-tags {movable markable toplevel Ylabel}

	### Apply graticule and values to axis.
	# drawGraticule $w $Xintercept $Yintercept

	$w.canvas raise blanket
	$w.canvas raise toplevel

	set plot($w,tagids) {}

### Bindings
    $w.canvas bind axis_line <Double-1> \
		[namespace code "settings_axis $w"]
	$w.canvas bind all <Button-1> \
        [namespace code "CanvasMark $w %x %y %W"]
#    $w.canvas bind movable <B1-Motion> \
#        [namespace code "CanvasDrag %x %y %W"]
	$w.canvas bind xaxis_movable <B1-Motion> \
        [namespace code "Xstretch $w %W %x %y %w %h"]
    $w.canvas bind yaxis_movable <B1-Motion> \
        [namespace code "Ystretch $w %W %x %y %w %h"]
	$w.canvas bind xslidable <B1-Motion> \
        [namespace code "Xslide $w %W %x %y"]
	$w.canvas bind yslidable <B1-Motion> \
        [namespace code "Yslide $w %W %x %y"]
	for {set i 0} {$i<$nYlabel} {incr i} {
		set vartag {}
		append vartag var $i
		$w.canvas bind $vartag <B1-Motion> \
            [namespace code "Ylabel_move %W %x %y"]
        $w.canvas bind swatch$i <Double-1> \
            [namespace code "ChangeColour $w $i"]
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

proc ChangeColour {w i} {
    global ::graphtools::plot
    
    set newColour [tk_chooseColor -initialcolor [lindex $plot($w,YColours) $i] -parent $w \
            -title "Choose colour for [lindex $plot($w,Ylabels) $i]" ]
    if ![string match "" $newColour] {
        set plot($w,YColours) [lreplace $plot($w,YColours) $i $i $newColour]
    UpdateState $w
    drawGraphpad $w
    }
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
		set x2 [expr $x1+$plot($w,xborder_right)]
		set y2 [expr $y0+$plot($w,yborder_bottom)]

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

		$w.canvas coords blanket_right [expr $x1+5] 0 $x2 $y2

		$w.canvas coords blanket_bottom 0 [expr $y0+5] $x2 $y2

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
			$w.canvas create line $x $plot($w,Yborder) $x \
				[expr $plot($w,Height)-$plot($w,Yborder)] \
				-width 1 -fill gray -tags graph
			}
			$w.canvas create text $x [expr $Yintercept+10] 
				-text [format $dec [expr $i*$Xdivision]] \
				-font $plot($w,fontValues) -tags graph
		}
		# draw X axis values and horizontal grid lines
		if {($y <= [expr $plot($w,Height)-$plot($w,Yborder)]) && ($y >= $plot($w,Yborder)) } {
			set dec [decimalPlaces [expr $i*$Ydivision]]
			if {$plot($w,grid)=="on"} {
				$w.canvas create line $plot($w,Xborder) $y \
				[expr $plot($w,Width)-$plot($w,Xborder)] $y  \
				-width 1 -fill gray -tags graph
			}
			$w.canvas create text [expr $Xintercept-15] $y \
				-text [format $dec [expr $i*$Ydivision]] \
				-font $plot($w,fontValues) -tags graph
 		}
		incr i
	}
}


############################################################################
######         DYNAMIC BIT
############################################################################



##########################################################################

proc plot_YY {w} {
    global ::graphtools::plot
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    global ::graphtools::Told
    global ::graphtools::Tnew
    
	if {$Told($w)<$Tnew($w)} then {

	foreach tagid $plot($w,tagids) {
		set coords [$w.canvas coords $tagid]
# The following bit is to deal with a weird quirk.   Tck/tk seems to reverse the
# y coordinates - but only for the first display interval of a run!   If you 
# don't believe me, check out the value for [$w.canvas coords $tagid] in proc
# drawblob, comparing it with the ordering of ya, yb that is used to create 
# the rectangle.   Anyway, the following hack is designed to deal with that.
# Note also that the *lower* y coordinate actually has the higher value!
		set ya [lindex $coords 1]
		set yb [lindex $coords 3]
		if {$ya>$yb} then {
			set ylower $ya
		} else {
			set ylower $yb
		}
		set yshift [expr $plot($w,y0)-$ylower]
		$w.canvas move $tagid 0 $yshift
		$w.canvas move y$tagid 0 $yshift
	}

	set Trange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
	set Yrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
	set plot($w,Tscale) [expr $Trange/$plot($w,xlength)]
	set plot($w,Yscale) [expr $Yrange/$plot($w,ylength)]

	set iplot 0
	set plot($w,ntrack) 0
	foreach Ynew $YYnew($w) {
		set node [lindex $Ynew 0]
		foreach Yold $YYold($w) {
			if {$node==[lindex $Yold 0]} {
				set plot($w,itrack) 0
				plot_Y $w $iplot $Told($w) $Yold $Tnew($w) $Ynew
				incr iplot
			}
		}
	}
	}

	set yshift 0
	set tagids [lsort $plot($w,tagids)]
	foreach tagid $tagids {
		$w.canvas move $tagid 0 $yshift
		$w.canvas move y$tagid 0 $yshift
		set yshift [expr $yshift-$plot($w,overallmax,$tagid)-3]
	}
}

# proc plotY
#
# This procedure recurses through the data structure holding the value or values 
# for one variable. You might expect it to plot this value (like Plotter does)
# but it doesn't.  Instead, it simply stores the value in the array variable
# 'plot'.   The first variable specified by the user (the unique ID) is stored
# in plot($w,id,$itrack) for the current track.   The actual data value is
# stored in plot($w,value,$itrack,$iplot) (where $iplot is the number of the
# variable).
#
# This first bit handles the case where you have recursed down to a scalar
# value.
# The bit after the else handles the case where the data structure is a list.
# It then recurses over each element of this list.

proc plot_Y {w iplot Told Yold Tnew Ynew} {
    global ::graphtools::plot
    
	if {[llength $Ynew]==1} then {
		#set colour [lindex $plot($w,YColours) $iplot]
		adjustLimits $w $Tnew [expr 10*$Ynew]
		set plot($w,itrack) [expr $plot($w,itrack)+1]
		set itrack $plot($w,itrack)
		if {$iplot==0} then {
			set plot($w,ntrack) [expr $plot($w,ntrack)+1]
			set id $Ynew
			set plot($w,id,$itrack) $id
			set plot($w,max,$itrack) 0
			#set tagid id$id
			set tagid [format id%06d [expr int($id)]]
			if {[lsearch $plot($w,tagids) $tagid]==-1} then {
				set plot($w,overallmax,$tagid) 0
				lappend plot($w,tagids) $tagid
				$w.canvas create line [expr $plot($w,x0)-5] \
					$plot($w,y0) $plot($w,x0) $plot($w,y0) \
					-tags "scalable axis_line yaxis_item ytick \
						markable yaxis_movable y$tagid"
				$w.canvas create text [expr $plot($w,x0)-3] \
					[expr $plot($w,y0)+3] \
					-text $id -anchor se \
					-font [myAssembleFont Helvetica Bold R 120] \
					-tags "scalable axis_value yaxis_item \
						yaxis_movable ytick toplevel markable \
						y$tagid"
			}
		} else {
			#set plot($w,value,$itrack,$iplot) $Ynew
			set id $plot($w,id,$itrack)
			set colour [lindex $plot($w,YColours) $iplot]
			set id $plot($w,id,$itrack)
			drawblob $w $Told $Tnew $Ynew $id $itrack $iplot $colour
			set plot($w,max,$itrack) [expr $plot($w,max,$itrack)+$Ynew]
		}
	} else {
		array set Ynew_array $Ynew
		array set Yold_array $Yold
		foreach element [array names Ynew_array] {
			if {[info exists Yold_array($element)]} {
				plot_Y $w $iplot $Told $Yold_array($element) \
					$Tnew $Ynew_array($element)
			}
		}
	}
}


# Draw one blob
#
# Note that this procedure returns the new y co-ordinate value.   This enables
# all the time-profiles to be drawn as close together as possible (rather
# than having them arranged at constant y increments).

proc drawblob {w Told Tnew Ynew id itrack ivar colour} {

    global ::graphtools::plot
    
	#set tagid "id$id"
	set tagid [format id%06d [expr int($id)]] 
	set Tscale $plot($w,Tscale)
	set Yscale $plot($w,Yscale)
    set xa [get_x $w $Told $Tscale ]
    set xb [get_x $w $Tnew $Tscale]
	set max_so_far $plot($w,max,$itrack)
	set y0 $plot($w,y0)
	set ya [expr $y0-$max_so_far/$Yscale]
	set yb [expr $ya-$Ynew/$Yscale]
	set ydiff [expr $y0-$yb]
	if {$ydiff>$plot($w,overallmax,$tagid)} then {
		set plot($w,overallmax,$tagid) $ydiff
	}
	$w.canvas create rectangle $xa $ya $xb $yb \
		-fill $colour \
		-tags "graph scalable xaxis_item yaxis_item $tagid"	
	if {$id==1} then {
#tk_messageBox -message "id itrack ivar $id $itrack $ivar; max $max_so_far; y0 ya yb $y0 $ya $yb; coords [$w.canvas coords $tagid]"
	}
}

# clear graph
proc clear { w } {
    global ::graphtools::Xvalues
    global ::graphtools::YYold
    global ::graphtools::YYnew
    
	set Xvalues {}
	set YYold($w) {}
	set YYnew($w) {}

	drawGraphpad $w
}



# Update any axis limit if value is exceeded.
proc adjustLimits {w Tnew Ynew} {
    global ::graphtools::plot
    variable scale_factor [list 2.0 2.5 2.0]

	if {$Tnew>$plot($w,Xmax_axis)} {
		set plot($w,Xmax_data) $Tnew
		set sf [lindex $scale_factor $plot($w,X_scalestep)]
		set plot($w,Xmax_axis) [expr $sf*$plot($w,Xmax_axis)]
		set plot($w,Xmajorstep) [expr $sf*$plot($w,Xmajorstep)]
		set plot($w,Xminorstep) [expr $sf*$plot($w,Xminorstep)]
		set Trange [expr 1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)]
		set plot($w,Tscale) [expr $Trange/$plot($w,xlength)]
		set x0 $plot($w,xborder_left)
		set y0 $plot($w,yborder_top)
		$w.canvas scale xaxis_item $x0 $y0 [expr 1.0/$sf] 1
		draw_Xaxis $w
		incr plot($w,X_scalestep)
		if {$plot($w,X_scalestep)>2} {set plot($w,X_scalestep) 0}
	}
}

proc get_Yvalues {w} {
#    ShowMessage debug info "[namespace current]" ok
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
    }
}


# end of namespace
} ;


