# graphs.tcl library of procedures for use in graph (chart) helpers,
# e.g. plotter and timeprofiles

namespace eval ::graphtools {

namespace export UpdateState draw_Xaxis draw_Yaxis Xstretch Ystretch \
        Xslide Yslide CanvasMark CanvasDrag Ylabel_move settings_axis \
        do_axis_settings horizlines vertlines boxed \
        delist decimalPlaces myAssembleFont get_x get_y get_Yvalues \
        resetGraph AxisRound
        
# protected       gridOnOff myAssembleFont

################################################################################
# calculateXintercept calculateYintercept decimalPlaces \
#         get_x get_y get_Yvalues gridOnOff marker \
#         resetGraph
# 
################################################################################

    variable plot
    variable Xvalues
    variable YYold
    variable YYnew
    variable Told
    variable Tnew
    
    global ::graphtools::karray
    
    set klist [list 1 1  2 1  3 1  4 1  5 1  6 1  7 1  8 1  9 1  5 2 \
            6 2  6 2  7 2  7 2  8 2  8 2  9 2  9 2 	4 5  4 5 \
            5 5  5 5  5 5  5 5  5 5  6 5  6 5  6 5  6 5  6 5 \
            7 5  7 5  7 5  7 5  7 5  8 5  8 5  8 5  8 5  8 5 \
            9 5  9 5  9 5  9 5  9 5 ]
    for {set i 1} {$i <= 2} {incr i} {
        for {set j 1} {$j <= 45} {incr j} {
            set karray($i,$j) [lindex $klist [expr {2*($j-1)+$i-1}]]
            #puts "i $i; j $j; karray($i,$j) $karray($i,$j)"
        }
    }
    
}; # end namespace

proc ::graphtools::MakeToolBar {w toolbarItems} {
    pack [Separator $w.abovebbox -orient horizontal] -side top
    set f [frame $w.bbframe  -relief raised]
    set bbox [ButtonBox $f.buttonBox -spacing 0 -padx 1 -pady 1]
    # build the toolbar  from the toolbarItems list
    foreach item $toolbarItems {
        set gif [lindex $item 0 ]
        set helptext [lindex $item 1]
        set command [lindex $item 2]
        $bbox add -image [image create photo  -file "../Images/Toolbar/$gif"] \
                -highlightthickness 0 -takefocus 0 -relief link -borderwidth 1 -padx 1 -pady 1 \
                -helptext $helptext -command $command
    }
    pack $f -side top -fill x
    pack $bbox -side left -anchor w
    pack [Separator $w.belowbbox -orient horizontal] -side top
    
}

proc ::graphtools::UpdateState {winId} {
    global ::graphtools::plot
    
    regsub -all $winId [array get plot $winId,*] /WIN/ saveString
    #    ShowMessage debug info "graphs.tcl UpdateState $saveString" ok
    SetState $winId $saveString
}


proc ::graphtools::marker {} {tk_messageBox -message "hello"}


# redraw graph after adjusting limits to Coordinates range
proc ::graphtools::resetGraph { w } {
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

######################################################################
# Scales data X and Y values to canvas coordinates (pixels)

proc ::graphtools::get_x { w X Xscale} {
    global ::graphtools::plot
    expr $plot($w,xborder_left)+($X-$plot($w,Xmin_axis))/$Xscale
}

proc ::graphtools::get_y { w Y Yscale} {
    global ::graphtools::plot
    expr $plot($w,yborder_top)+$plot($w,ylength) \
            -($Y-$plot($w,Ymin_axis))/$Yscale
}

### Calculate the position of X where Y-axis intersects X-axis
proc ::graphtools::calculateXintercept {Min Max Width Border} {
    if {$Min >= 0 } {return $Border}
    if {$Max <= 0 } {return [expr $Width - $Border]}
    expr abs($Min)/double($Max-$Min)*($Width-2*$Border)+$Border
}

### Calculate the position of Y where X-axis intersects Y-axis
proc ::graphtools::calculateYintercept {Min Max Height Border} {
    if {$Min >= 0 } {return [expr $Height - $Border]}
    if {$Max <= 0 } {return $Border}
    expr abs($Max)/double($Max-$Min)*($Height-2*$Border)+$Border
}

# return format specifier for optimum display of a graph value.
proc ::graphtools::decimalPlaces {N} {
    if {($N == 0) || (abs($N) >= 10)} {return %.0f}
    if {(abs($N) >= 1)} {return %.1f}
    #cater for any absolute numbers < 1
    set d 1
    while {abs($N)<1} {set N [expr $N*10]; incr d}
    set p %.$d; set q f; return $p$q
}

# Convert list of elements that may be numbers or arrays to a sorted list of values.
# eg: {1 {4 5 6 7} 2  {8 9 10} 3} to {1 2 3 4 5 6 7 8 9 10}
proc ::graphtools::flattenList {List} {
    foreach element $List {
        set item [delist $element]
        if {[IsArray $item]} {
            foreach n $item {lappend Y $n}
        } else {lappend Y $item}
    }
    return [lsort -increasing -real $Y]
}

# remove extra list nesting eg: list of form {{{...}}} to list {...}
# or {{{...}} {{...}}} to {{...} {...}}
proc ::graphtools::delist {List} {
    if {([IsArray $List]) && ([llength $List]==1)} {delist [lindex $List 0]
    } else {return $List}
}

# switch grid lines on/off
proc ::graphtools::gridOnOff {  w } {
    global ::graphtools::plot
    if {$plot($w,grid)=="on"} {set plot($w,grid) off} else {set plot($w,grid) on}
    drawGraphpad $w
    drawGraph $w
}


proc ::graphtools::myAssembleFont {family weight style textsize} {
    set font [format "-Adobe-%s-%s-%1s-Normal--*-%d-*-*-*-*-*-*" \
            $family $weight $style $textsize]
    #tk_messageBox -message "font $font"
    return $font
}

proc ::graphtools::draw_Xaxis { w } {
    global ::graphtools::plot
    
    if {$plot($w,Xmax_axis)<$plot($w,Xmin_axis)} {
        set Xmax_axis 10
        set Xmin_axis 0
        set Xmajorstep 2
        set Xminorstep 1
    } else  {
        set Xmax_axis $plot($w,Xmax_axis)
        set Xmin_axis $plot($w,Xmin_axis)
        set Xmajorstep $plot($w,Xmajorstep)
        set Xminorstep $plot($w,Xminorstep)
    }
    
    $w.canvas delete xtick
    
    set x0 $plot($w,xborder_left)
    set y0 [expr {$plot($w,yborder_top)+$plot($w,ylength)}]
    set x1 [expr {$plot($w,xborder_left)+$plot($w,xlength)}]
    
    set step [expr {1.0*$plot($w,xlength)*$Xmajorstep \
                / ($Xmax_axis-$Xmin_axis)}]
    set value $Xmin_axis
    set y [expr {$y0+2}]
#    ShowMessage debug info "Maj $Xmajorstep min $Xminorstep -- Going from $x0 up to $x1 in steps of $step" ok
    for {set x $x0} {$x<=$x1} {set x [expr $x+$step]} {
        $w.canvas create line $x $y0 $x [expr $y0-6] \
                -tags {scalable axis_line xaxis_item xtick markable \
                    xaxis_movable}
        $w.canvas create text $x $y \
                -text [VarPrecRender $w $value $plot($w,Xprecision)] \
                -font $plot($w,fontValues) \
                -tags {scalable axis_value xaxis_item xaxis_movable xtick \
                    toplevel markable} -anchor n
        set value [expr $value+$Xmajorstep]
    }
    set step [expr $step/2]
#    set step [expr 1.0*$plot($w,xlength)*$Xminorstep \
#            / ($Xmax_axis-$Xmin_axis)]
#ShowMessage debug info "Going from $x0 up to $x1 in steps of $step" ok
    for {set x $x0} {$x<$x1} {set x [expr $x+$step]} {
        $w.canvas create line $x $y0 $x [expr $y0-4] \
                -tags {scalable axis_line xaxis_item xtick markable \
                    xaxis_movable}
    }
}

proc ::graphtools::draw_Yaxis { w} {
    global ::graphtools::plot
    global ::graphtools::Tnew
    #ShowMessage debug info "draw_Yaxis $plot($w,Ymin_axis) $plot($w,Ymax_axis); dp $plot($w,Yprecision)" ok
    if {$plot($w,Ymax_axis)<$plot($w,Ymin_axis)} {
        set Ymax_axis 10
        set Ymin_axis 0
        set Ymajorstep 2
        set Yminorstep 1
    } else  {
        set Ymax_axis $plot($w,Ymax_axis)
        set Ymin_axis $plot($w,Ymin_axis)
        set Ymajorstep $plot($w,Ymajorstep)
        set Yminorstep $plot($w,Yminorstep)
    }
    
    $w.canvas delete ytick
    
    set x0 $plot($w,xborder_left)
    set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
    set y1 $plot($w,yborder_top)
    
    set step [expr 1.0*$plot($w,ylength)*$Ymajorstep \
            / ($Ymax_axis-$Ymin_axis)]
    set value $Ymin_axis
    set x [expr $x0-2]
#ShowMessage debug info "Going from $y0 down to [expr $y1-2] in steps of [expr -$step]" ok
    for {set y $y0} {$y>=[expr $y1-2]} {set y [expr $y-$step]} {
        $w.canvas create line $x0 $y [expr $x0+6] $y \
                -tags {scalable axis_line yaxis_item ytick markable \
                    yaxis_movable}
        $w.canvas create text $x [expr $y-1] \
                -text [VarPrecRender $w $value $plot($w,Yprecision)] \
                -font $plot($w,fontValues) \
                -tags {scalable  axis_value yaxis_item yaxis_movable ytick \
                    toplevel markable} -anchor e
        set value [expr $value+$Ymajorstep]
    }
    set step [expr $step/2]
#    set step [expr 1.0*$plot($w,ylength)*$Yminorstep \
#            / ($Ymax_axis-$Ymin_axis)]
#ShowMessage debug info "Going from $y0 down to [expr $y1-2] in steps of [expr -$step]" ok
    for {set y $y0} {$y>=$y1} {set y [expr $y-$step]} {
        $w.canvas create line $x0 $y [expr $x0+4] $y \
                -tags {scalable axis_line yaxis_item ytick markable \
                    yaxis_movable}
    }
}

proc ::graphtools::Xstretch { w can x y width height} {
    global ::graphtools::canvas
    global ::graphtools::plot
    
    $can raise blanket
    $can raise toplevel
    
    set item $canvas($can,obj)
    set oldx [lindex [$can coords $item] 0]
    set oldxpos [expr $oldx-$plot($w,xborder_left)]
    set newxpos [expr $x-$plot($w,xborder_left)]
    
    set Xmult [expr 1.0*$newxpos/$oldxpos]
    
    set x0 $plot($w,xborder_left)
    set y0 $plot($w,yborder_top)
    
    $can scale xaxis_item $x0 $y0 $Xmult 1
    
    set plot($w,Xmax_axis) [expr $plot($w,Xmax_axis)/$Xmult]
    set plot($w,Xmajorstep) [expr {$plot($w,Xmajorstep)/$Xmult}]
    set plot($w,Xminorstep) [expr {$plot($w,Xminorstep)/$Xmult}]
    
    set Trange [expr {1.0*$plot($w,Xmax_axis)-$plot($w,Xmin_axis)}]
    set plot($w,Tscale) [expr {$Trange/$plot($w,xlength)}]
}


proc ::graphtools::Ystretch { w can x y width height} {
    global ::graphtools::canvas
    global ::graphtools::plot
    
    $can raise blanket
    $can raise toplevel
    
    set Yrange [expr 1.0*$plot($w,Ymax_axis)-$plot($w,Ymin_axis)]
    set x0 $plot($w,xborder_left)
    set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
    
    set item $canvas($can,obj)
    set oldy [lindex [$can coords $item] 1]
    set oldypos [expr $y0-$oldy]
    set newypos [expr $y0-$y]
    
    set Ymult [expr 1.0*$newypos/$oldypos]
    
    $can scale yaxis_item $x0 $y0 1 $Ymult
    
    set Yrange [expr 1.0*$Yrange/$Ymult]
    set plot($w,Ymax_axis) [expr {$plot($w,Ymin_axis)+$Yrange}]
    set plot($w,Ymajorstep) [expr {$plot($w,Ymajorstep)/$Ymult}]
    set plot($w,Yminorstep) [expr {$plot($w,Yminorstep)/$Ymult}]
    
    set plot($w,Yscale) [expr {$Yrange/$plot($w,ylength)}]
}


proc ::graphtools::Xslide { w can x y} {
    global ::graphtools::canvas
    global ::graphtools::plot
    
    $can raise blanket
    $can raise toplevel
    
    set item $canvas($can,obj)
    set oldx $canvas($can,x)
    set canvasShift [expr $x - $oldx]
    set axisShift [expr {[get_datax $w $oldx $plot($w,Tscale)]\
                -[get_datax $w $x $plot($w,Tscale)]}]
    
    $can move xaxis_item $canvasShift 0
    
    set canvas($can,x) $x
    
    set plot($w,Xmax_axis) [expr $plot($w,Xmax_axis) + $axisShift]
    set plot($w,Xmin_axis) [expr $plot($w,Xmin_axis) + $axisShift]
}

proc ::graphtools::Yslide { w can x y} {
    global ::graphtools::canvas
    global ::graphtools::plot
    
    $can raise blanket
    $can raise toplevel
    
    set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
    
    set item $canvas($can,obj)
    set oldy $canvas($can,y)
    set canvasShift [expr $y - $oldy]
    set axisShift [expr {[get_datay $w $oldy $plot($w,Yscale)]\
                -[get_datay $w $y $plot($w,Yscale)]}]
    
    $can move yaxis_item 0 $canvasShift
    set canvas($can,y) $y
    
    set plot($w,Ymax_axis) [expr $plot($w,Ymax_axis) - $axisShift]
    set plot($w,Ymin_axis) [expr $plot($w,Ymin_axis) - $axisShift]
}


proc ::graphtools::CanvasMark { w x y can} {
    global ::graphtools::canvas
    global ::graphtools::plot
    
    set canvas($can,x) $x; # set in CanvasMark bound to B1
    set canvas($can,y) $y
    #    ShowMessage debug info "$x $y" ok
    
    set y0 [expr $plot($w,yborder_top)+$plot($w,ylength)]
    if {[expr {abs($y-$y0)}]<4} then {
        set canvas($can,obj) [lindex [$can find withtag xslidable] 0]
        return
    }
    set canvas($can,obj) [$can find closest $x $y]
    set canvas($can,tag) [lindex [$can gettags $canvas($can,obj)] 0]
    set canvas($can,x) $x
    set canvas($can,y) $y
    set canvas($can,dx) 0
    set canvas($can,dy) 0
    #puts$line "Mark: $canvas($can,tag)"
}

proc ::graphtools::CanvasDrag {x y can} {
    global ::graphtools::canvas
    #set x [$can canvasx $x]
    #set y [$can canvasy $y]
    set dx [expr $x-$canvas($can,x)]
    set dy [expr $y-$canvas($can,y)]
    $can move $canvas($can,obj) $dx $dy
    set canvas($can,x) $x
    set canvas($can,y) $y
}


proc ::graphtools::Ylabel_move {can x y} {
    global ::graphtools::canvas
    #set x [$can canvasx $x]
    #set y [$can canvasy $y]
    set dx [expr $canvas($can,dx)+$x-$canvas($can,x)]
    set dy [expr $canvas($can,dy)+$y-$canvas($can,y)]
    set dx1 [expr 3*floor($dx/3.0)]
    set dy1 [expr 3*floor($dy/3.0)]
    $can move $canvas($can,tag) $dx1 $dy1
    
    set canvas($can,x) $x
    set canvas($can,y) $y
    set canvas($can,dx) [expr $dx-$dx1]
    set canvas($can,dy) [expr $dy-$dy1]
}


proc ::graphtools::settings_axis { w} {
    global ::graphtools::plot
    
    set wset .settings
    catch {destroy $wset}
    toplevel $wset -bg #e0e0e0
    wm title $wset "Plotter tool settings"
    
    frame $wset.min
    label $wset.min.label -text "Minimum"
    entry $wset.min.entry
    $wset.min.entry insert 0 $plot($w,Xmin_axis)
    pack $wset.min -side top
    pack $wset.min.label -side top -anchor w
    pack $wset.min.entry -side top -anchor w
    
    frame $wset.max
    label $wset.max.label -text "Maximum"
    entry $wset.max.entry
    $wset.max.entry insert 0 $plot($w,Xmax_axis)
    pack $wset.max -side top
    pack $wset.max.label -side top -anchor w
    pack $wset.max.entry -side top -anchor w
    
    frame $wset.interval
    label $wset.interval.label -text "Interval"
    entry $wset.interval.entry
    $wset.interval.entry insert 0 $plot($w,Xmajorstep)
    pack $wset.interval -side top
    pack $wset.interval.label -side top -anchor w
    pack $wset.interval.entry -side top -anchor w
    
    frame $wset.buttons
    foreach item  [list \
            [list "cancel" "Cancel" \
            [namespace code "do_axis_settings plot $w $wset cancel"]] \
            [list "ok" "OK" \
            [namespace code "do_axis_settings plot $w $wset ok"]] \
            [list "apply" "Apply" \
            [namespace code "do_axis_settings plot $w $wset apply"]]] {
                set name [lindex $item 0]
                set label [lindex $item 1]
                button $wset.buttons.$name -text $label  \
                        -command [lindex $item 2]
        pack $wset.buttons.$name -side right
    }
    pack $wset.buttons -side top
    pack $wset.buttons.cancel -side right
    pack $wset.buttons.ok -side right
    pack $wset.buttons.apply -side right
    
}

# procedure to scale an axis to data values
# Input: dataMin dataMax are the minimum and maximum values of the data to displayed on the axis
# Output:
# axisMin axisMax are variables to contain the values for the minimum and maximum axis values
# interval and numInt are variables to hold the values of the tick spacing in the axis
# scale and number of intervals, respectively
# Adapted from code from Robert Muetzelfeldt, IERM, University of Edinburgh
# Jonathan Massheder, IERM, University of Edinburgh
# xaxis true if xazis false if y
proc ::graphtools::AxisRound { dataMin dataMax xaxis axisMin axisMax interval numInt \
            decimalPlaces } {
    upvar 1 $axisMin rmin $axisMax rmax $interval inter $numInt nint \
            $decimalPlaces decmlPos
    global graphtools::karray
#ShowMessage debug info "$dataMin $dataMax $rmin $rmax $inter $nint $decmlPos" ok
    if $xaxis {
        set axis 2; # dealing with x axis for use with karray($axis,$?)
    } else  {
        set axis 1; # dealing with y axis
    }
    
    if {$dataMin==0} {set dataMin 0.0000000001}; # prevent div by zero errors
    
    if { $dataMin > $dataMax } {
        set min $dataMax
        set max $dataMin
    } else {
        set min $dataMin
        set max $dataMax
    }
    #    ShowMessage debug info "$min $max" ok
    # check if all data is negative, if so, use absolute values
    if {$max < 0.0} {
        set neg 1
        set min [expr {-$dataMax}]
        set max [expr {-$dataMin}]
    } else  {
        set neg 0
    }
    #ShowMessage debug info "= min $min; max $max" ok
        
    # the range is zero (=max-min) add a 1 to the end of the decimal representation to max
    # to make max > min.
    if {$min == $max } {
        #ShowMessage debug info "= min $min; max $max" ok
        set max [expr {$max*1.1}]
        set min [expr {0.9*$min}]
        #ShowMessage debug info "after doctor =; min $min; max $max" ok
    }
#    set intFactor [expr {log10($max - $min)}]
    #ShowMessage debug info "= min $min; max $max" ok
    if {$max-$min < 1e-10} {
        set intFactor -10.0
    } else {
        set intFactor [expr {log10($max - $min)}]
    }
    set decmlPos [expr {int($intFactor)}]
    #    puts "1 intFactor $intFactor; decmlPos $decmlPos"
    
    if {[expr {$intFactor - int($intFactor)}] < 0} {
        incr decmlPos -1
    }
    #    puts "2 intFactor $intFactor; decmlPos $decmlPos"
    #ShowMessage debug info "AxisRound $min $max; intfactor $intFactor; dp $decmlPos" ok
    if  { $decmlPos > 6 } {
        set decmlPos 6
    } elseif  { $decmlPos < -6 } {
        set decmlPos -6
    }
    if { $decmlPos == 0 } {
        set intFactor [expr {int(pow(10,$decmlPos))}]
    } elseif { $decmlPos > 0 } {
        set intFactor [expr {1 / pow(10,$decmlPos)}]
    } else {
        set intFactor [expr {int(pow(10, -($decmlPos)))}]
    }
    #    puts "3 intFactor $intFactor; decmlPos $decmlPos"
    #    puts "min $min; max $max"
    set imin [expr {$min * $intFactor}]
    #ShowMessage debug info "AxisRound imin $imin" ok
    #jmm   set frac [expr {$imin - int($imin)}]
    set frac [expr {$imin - floor($imin)}]
    #    puts "frac $frac; imin $imin "
    if {$frac < 0 } {
        set imin [expr {floor($imin) - 1 }]
    }  else {
        set imin [expr {floor($imin)}]
    }
    
    set imax [expr {$max * $intFactor}]
    #jmm    set frac [expr {$imax - int($imax)}]
    set frac [expr {$imax - floor($imax)}]
    #    puts "frac $frac; imax $imax"
    if { $frac < 0 } {
        set imax [expr {floor($imax)}]
    } else {
        set imax [expr {floor($imax) + 1}]
    }
    #    puts "imin $imin; imax $imax; intFactor $intFactor; decmlPos $decmlPos"
    #ShowMessage debug info "imin $imin; imax $imax; intFactor $intFactor; decmlPos $decmlPos" ok
    set intdiff [expr {int($imax - $imin)}]
    #    puts "intdiff $intdiff"
    
    set rmin [expr {$imin * 1.0 / $intFactor}]; # floating point
    set rmax [expr {$imax * 1.0 / $intFactor}]
    set rounddiff [expr {$rmax - $rmin}]
    set nint $karray($axis,$intdiff)
    set inter [expr {$rounddiff/$nint}]
    if {$decmlPos > 0} {
        set decmlPos 0
    } else  {
        set decmlPos [expr {abs($decmlPos)}]
    }
    
    #ShowMessage debug info  "rmin $rmin; rmax $rmax; inter $inter; nint $nint;\
    #    decmlPos $decmlPos" ok
    if {$neg==1} {
        set temp $rmin
        set rmin [expr {-1.0*$rmax}]
        set rmax [expr {-1.0*$temp}]
    }
    
}

proc ::graphtools::do_axis_settings { w wset action} {
    global ::graphtools::plot
    
    bell
    
    switch $action {
        cancel {
            pack forget $wset
            destroy $wset
        }
        apply {
            set plot($w,xlength) [$wset.interval.entry get]
            drawGraphpad $w
        }
        ok {
            set plot($w,xlength) [$wset.interval.entry get]
            pack forget $wset
            destroy $wset
            drawGraphpad $w
        }
    }
    
}

proc ::graphtools::horizlines {w} {
    bell
}

proc ::graphtools::vertlines {w} {
    bell
}

proc ::graphtools::boxed {w} {
    bell
}

# from tabular.tcl Jasper May 2002
proc ::graphtools::VarPrecRender {winId val precision} {
    global ::graphtools::plot
    
    set regular [format %.${precision}f $val]
    set scientific [format %.${precision}e $val]
    if {[string length $scientific]<[string length $regular]} {
        return $scientific
    } else {
        return $regular
    }
}

# Scales data x and y pixel co-ord to x and y data values

proc ::graphtools::get_datax {w Xc Xscale} {
    global ::graphtools::plot
    expr {($Xc-$plot($w,xborder_left))*$Xscale+$plot($w,Xmin_axis)}
}

proc ::graphtools::get_datay {w Yc Yscale} {
    global ::graphtools::plot
    expr {($Yc-$plot($w,yborder_top)-$plot($w,ylength))*$Yscale \
                +$plot($w,Ymin_axis)}
}

