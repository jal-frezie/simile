# Simile source code file: Run/graphs.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for entering a function graphically or as a table.
#
# This is what happens when the graph button is pushed. It reads the parameter
# name and units from the boxes above the parameter list, then tries to find a
# graph(...) naming that parameter in the equation. If it succeeds it sends off
# the data about that graph to the graphing box, otherwise a null graph. On return
# the graph data is inserted or appended to the equation.

# graph function is graph(param, xlow, xhigh, xspan,
#	ylow, yhigh, yspan, [pt1, pt2 ... ptn])

proc GraphEntry { t xlow xhigh xspan ylow yhigh yspan range size points \
            {target {}}} {
    global tcl_platform graph looks
    
    set graph(bd) 3
    
    switch $tcl_platform(platform) {
        unix {
            set graph(exag) 3
            set graph(origin) 1
        } windows {
            set graph(exag) 5
            set graph(origin) 2
        }
    }
    set graph($t,points) [split $points ,]
    set graph($t,lowy) $ylow
    set graph($t,highy) $yhigh
    set graph($t,height) $yspan
    set graph($t,lowx) $xlow
    set graph($t,highx) $xhigh
    set graph($t,width) $xspan
    
    catch {wm title $t "Sketch graph"}
    
    TitleFrame $t.gph -text "Graph pad"
    set gph [$t.gph getframe]
    frame $gph.yentry
    ::ttk::entry $gph.yentry.topentry -textvar graph($t,lowy) -width 8
    pack $gph.yentry.topentry -side top -pady 2
    label $gph.yentry.toplabel -text "Y max"
    pack $gph.yentry.toplabel -side top -pady 2
    label $gph.yentry.label -text "Value"
    pack $gph.yentry.label -side top -fill y -expand true
    label $gph.yentry.bottomlabel -text "Y min"
    pack $gph.yentry.bottomlabel -side top -pady 2
    ::ttk::entry $gph.yentry.bottomentry -textvar graph($t,highy) -width 8
    pack $gph.yentry.bottomentry -side top -pady 2
    grid $gph.yentry -column 0 -row 0 -sticky ns -padx 2 -pady 2
    
    frame $gph.gridf
    set grid [canvas $gph.gridf.canvas -width [expr $graph($t,width)+1] \
            -height [expr $graph($t,height)+1] -bd $graph(bd) -relief groove]
    set graph($t,increment) [expr $graph($t,width)/([llength $graph($t,points)] - 1.0)]
    
    bind $grid <Button-1> "GClick %W %x %y"
    bind $grid <B1-Motion> "GDrag %W %x %y"
    bind $grid <Configure> "AttackShape %W %w %h"
    
    frame $gph.xentry
    ::ttk::entry $gph.xentry.leftentry -textvar graph($t,lowx) -width 8
    pack $gph.xentry.leftentry -side left -padx 2
    label $gph.xentry.xmin -text "X min"
    pack $gph.xentry.xmin -side left -padx 2
    label $gph.xentry.arg -text "Argument"
    pack $gph.xentry.arg  -side left -fill x -expand true
    label $gph.xentry.rightlabel -text "X max"
    pack $gph.xentry.rightlabel -side left -padx 2
    ::ttk::entry $gph.xentry.rightentry -textvar graph($t,highx) -width 8
    pack $gph.xentry.rightentry -side left -padx 2
    grid $gph.xentry -column 1 -row 1 -sticky we -padx 2 -pady 2
    
    frame $t.right
    
    set buttons [frame $t.right.buttons]
    button $buttons.enter -text OK -width 10
    pack $buttons.enter -padx 4 -pady 4 -anchor e
    button $buttons.cancel -text Cancel -width 10
    pack $buttons.cancel -padx 4 -pady 4 -anchor e
    button $buttons.edit -text "Edit as table" -width 10 \
	-command [list EditAsTable $t $grid]
    pack $buttons.edit -padx 4 -pady 4 -anchor e
    button $buttons.help -text Help -width 10 -command {ContextSensitiveHelp .graph equations/graph.htm}
    pack $buttons.help -padx 4 -pady 4 -anchor e
    pack $buttons -fill x -padx 8 -pady 8
    set looks(darkerColor) [$buttons.enter cget -disabledforeground]

    if {[llength $target]} {
	$buttons.enter configure -command \
	    [namespace code [list UpdateGraph $t $target]]
	$buttons.cancel configure -command \
	    [namespace code [list RestoreSketch $t $target]]
    } else {
	$buttons.enter configure -command [list set graph($t,done) 1]
	$buttons.cancel configure -command [list set graph($t,done) 0]
	bind $t <Destroy> "set graph($t,done) -1"
    }

    TitleFrame $t.right.current -text "Current Position: "
    set current [$t.right.current getframe]
    
    frame $current.y
    label $current.y.yvalue -text "Y:"
    pack $current.y.yvalue -side left -padx 2 -pady 4
    ::ttk::entry $current.y.yvaluebox -textvar yvalue -width 8
    bind $current.y.yvaluebox <Return> [list YEntry $grid]
    pack $current.y.yvaluebox -side left -padx 2 -pady 4
    pack $current.y -pady 4
    frame $current.x
    label $current.x.xvalue -text "X:"
    pack $current.x.xvalue -side left -padx 2 -pady 4
    ::ttk::entry $current.x.xvaluebox -textvar xvalue -width 8
    pack $current.x.xvaluebox -side left  -padx 2 -pady 4
    pack $current.x -pady 4
    pack $current -pady 8 -padx 4 -fill x
    pack $t.right.current -pady 2 -padx 2 -fill x
    pack $t.right -side right -fill y
    
    TitleFrame $t.right.options -text "Options: "
    set right [$t.right.options getframe]
    
    set between [frame $right.between]
    label $between.outrange -text "Between points:"
    pack $between.outrange
# Code fragment to switch to using menubutton from ComboBox
# Work in progress / Alastair 9 Feb 2005
#    set m [menu $between.outrangeMenu]
#    foreach item {Interpolate Round} {
#      $m add command -label $item -command "Reshape $t $item"
#    }
#    set mb [::ttk::menubutton $between.rangeopts -menu $m -text Interpolate] 
#    pack $mb

#    pack [ComboBox $between.rangeopts -values "Interpolate Round" -editable 0 \
#	      -modifycmd "Reshape $t" -width 12]
    ::ttk::menubutton $between.rangeopts
    set betweenMenu [menu $between.rangeopts.menu -tearoff 0]
    foreach unit {Interpolate Round} {
	$betweenMenu add command -label $unit \
	    -command "set graph($t,betweenOpt) $unit;Reshape $t"
    }
    $between.rangeopts configure -menu $betweenMenu -width 11 \
	-textvariable graph($t,betweenOpt)
    pack $between.rangeopts -side left -anchor nw

    pack $between -pady 8 -padx 4
    set out [frame $right.out]
    label $out.outrange -text "Out of range:"
    pack $out.outrange
#    pack [ComboBox $out.rangeopts -values "Truncate Extrapolate Wraparound" \
#	      -editable 0 -width 12]
    ::ttk::menubutton $out.rangeopts
    set outMenu [menu $out.rangeopts.menu -tearoff 0]
    foreach unit {Truncate Extrapolate Wraparound} {
	$outMenu add command -label $unit -command "set graph($t,outOpt) $unit"
    }
    $out.rangeopts configure -menu $outMenu -width 11 \
	-textvariable graph($t,outOpt)
    pack $out.rangeopts -side left -anchor nw

    pack $out -pady 8 -padx 4
    SetCombos $t $range

    set resolution [frame $right.resolution]
    label $resolution.detail -text "X axis resolution:"
    pack $resolution.detail
    frame $resolution.detailbox
    #    button $resolution.detailbox.less -text Less -command "CoarseX $grid"
    ArrowButton $resolution.detailbox.arrowleft -type button -dir \
            left -command "CoarseX $grid" -width 25 -height 25 -clean 2
    pack $resolution.detailbox.arrowleft -side left
    #    button $resolution.detailbox.more -text More -command "FineX $grid"
    ArrowButton $resolution.detailbox.arrowright -type button -dir right \
            -command "FineX $grid" -width 25 -height 25 -clean 2
    pack $resolution.detailbox.arrowright -side left
    pack $resolution.detailbox
    pack $resolution -pady 8 -padx 4 -fill both
    pack $right -fill both
    pack $t.right.options -fill both -padx 2 -pady 2 -expand true
    
    pack $gph -expand on -fill both -side left
    pack $t.gph -side left -expand on -fill both -padx 2 -pady 2
    grid rowconfigure $gph 0 -weight 1
    grid columnconfigure $gph 1 -weight 1
    
    grid $gph.gridf -column 1 -row 0 -sticky nesw  -padx 2 -pady 2
    frame $gph.dummy
    grid $gph.dummy -column 0 -row 1 -padx 2 -pady 2 -sticky nesw
    pack $grid -fill both -expand true
    
    RedrawGrid $grid $graph($t,width) $graph($t,height) $graph($t,increment)
    
    if {![llength $target]} {
	while {1} {
	    LetItShow $t
	    tkwait variable graph($t,done)
	    if {$graph($t,done)==1} {
		if {[CheckFloaty $graph($t,lowy) $graph($t,highy) \
			 $graph($t,lowx) $graph($t,highx)]} {
		    set graph($t,range) [SetCombos $t]
		    set graph($t,size) [llength $graph($t,points)]
		    # regsub -all " " $graph($t,points) , graph($t,pts)

                    SetDefaultGraph $graph($t,lowx) $graph($t,highx) $graph($t,width) \
			$graph($t,lowy) $graph($t,highy) $graph($t,height) \
			$graph($t,range) $graph($t,size) $graph($t,points)
                    return 1
                }
            } else {
		return 0
	    }
        }
    }
}

proc UpdateGraph {t node} {
    global graph

    if {[CheckFloaty $graph($t,lowy) $graph($t,highy) \
	     $graph($t,lowx) $graph($t,highx)]} {
	# tk_messageBox -message "$rangeChoices $graph($t,rangeact)"
	set graph($t,range) [SetCombos $t]
	set graph($t,size) [llength $graph($t,points)]
	# regsub -all " " $graph($t,points) , graph($t,pts)
	# Target is set to variable id if editing sketch at run time
	eval {SetModelGraph $node $graph($t,lowx) \
		  $graph($t,highx) $graph($t,width) \
		  $graph($t,lowy) $graph($t,highy) \
		  $graph($t,height) $graph($t,range) \
		  $graph($t,size)} $graph($t,points)
    }
}

proc RestoreSketch {t node} {
    global graph

    set lastSaved [GetModelGraph $node]
    scan $lastSaved "%g %g %d %g %g %d %d" graph($t,lowx) \
	graph($t,highx) graph($t,width) \
	graph($t,lowy) graph($t,highy) \
	graph($t,height) range
    SetCombos $t $range
    set graph($t,points) [lrange $lastSaved 8 end]
    set graph($t,increment) \
	[expr $graph($t,width)/([llength $graph($t,points)] - 1.0)]
# above must be set so AttackShape gets current one right
    set grid [$t.gph getframe].gridf.canvas
    AttackShape $grid [winfo width $grid] [winfo height $grid]
}

proc SetCombos {t args} {
    global graph
    set right [$t.right.options getframe]
    set bCombo $right.between.rangeopts
    set rCombo $right.out.rangeopts
    if {[llength $args]} {
	set between [expr $args/4]
#	$bCombo configure -text [lindex [$bCombo cget -values] $between]
	set graph($t,betweenOpt) [${bCombo}.menu entrycget $between -label]
#	$rCombo configure -text [lindex [$rCombo cget -values] \
#				  [expr $args-4*$between]]
	set graph($t,outOpt) [${rCombo}.menu entrycget \
				  [expr $args-4*$between] -label]
    } else {
#	set between [lsearch [$bCombo cget -values] [$bCombo cget -text]]
	set between [${bCombo}.menu index $graph($t,betweenOpt)]
    }
    set graph($t,between) $between
#    return [expr 4*$between+[lsearch [$rCombo cget -values] \
#				[$rCombo cget -text]]]
    return [expr 4*$between+[${rCombo}.menu index $graph($t,outOpt)]]
}
				  
proc EditAsTable {t canvas} {
    global graph
    set size [llength $graph($t,points)]
    set range [expr $graph($t,highx)-$graph($t,lowx)]
    for {set index 0} {$index < $size} {incr index} {
	lappend table \
	    [expr $graph($t,lowx)+$range*$index/($size-1.0)] \
	    [PointToYValue $t [lindex $graph($t,points) $index]]
    }
    if {[EditListAsTable $t table]} {
	foreach {index y} $table {
	    set zone [expr round(($size-1.0)*$index/$range)]
	    GStick $canvas $zone [YValueToPoint $t $y]
	}
    }
}

proc SetDefaultGraph {xlow xhigh xspan ylow yhigh yspan range size points} {
    global equation
    set equation(table_data) [list /graph/ $ylow $yhigh $yspan $size \
				  $xlow $xhigh $xspan $range]
    set equation(table_values) $points
}

proc CheckFloaty {args} {
    if {![llength $args]} {
        return 1
    } elseif {[catch {format %g [lindex $args 0]}]} {
        ShowMessage "Numeric value required" warning "This operation could not be completed because a numeric value must be placed in the entry field that currently contains this text: [lindex $args 0]" ok
        return 0
    } else {
        return [eval CheckFloaty [lrange $args 1 end]]
    }
}

proc GetWidFromCanvas {c} {
    return [winfo parent [winfo parent [winfo parent [winfo parent $c]]]]
}

proc AddLine {c section} {
    global graph
    set miss [expr $graph(bd)+$graph(origin)]
    set t [GetWidFromCanvas $c]
    
    $c delete section$section
    if {$graph($t,between)} {
	$c create line [expr round($graph($t,increment)*($section-1))+$miss] \
            [expr [lindex $graph($t,points) [expr $section - 1]]+$miss] \
	    [expr round($graph($t,increment)*($section-0.5))+$miss] \
            [expr [lindex $graph($t,points) [expr $section - 1]]+$miss] \
	    [expr round($graph($t,increment)*($section-0.5))+$miss] \
            [expr [lindex $graph($t,points) $section]+$miss] \
            [expr round($graph($t,increment)*$section)+$miss] \
            [expr [lindex $graph($t,points) $section]+$miss] \
            -tags "graph section$section"
    } else {
	$c create line [expr round($graph($t,increment)*($section-1))+$miss] \
            [expr [lindex $graph($t,points) [expr $section - 1]]+$miss] \
            [expr round($graph($t,increment)*$section)+$miss] \
            [expr [lindex $graph($t,points) $section]+$miss] \
            -tags "graph section$section"
    }
}

proc GClick {c x y} {
    global graph
    set t [GetWidFromCanvas $c]

    set x [expr $x-$graph(bd)-$graph(origin)]
    set y [expr $y-$graph(bd)-$graph(origin)]
    set zone [expr round($x/$graph($t,increment))]
    set graph($t,oldzone) $zone
    set graph($t,oldy) $y
    GStick $c $zone $y
}

proc YEntry {c} {
    global graph xvalue yvalue
    set t [GetWidFromCanvas $c]

    if {![CheckFloaty $graph($t,lowy) $graph($t,highy) $graph($t,lowx) $graph($t,highx) \
                $xvalue $yvalue]} {
        return
    }
    set zone [expr round(([llength $graph($t,points)]-1.0)*\
            ($xvalue-$graph($t,lowx))/($graph($t,highx)-$graph($t,lowx)))]
    set y [YValueToPoint $t $yvalue]
    GStick $c $zone $y
}

proc YValueToPoint {t yvalue} {
    global graph
    return [expr round($graph($t,height)*\
	       ($yvalue-$graph($t,lowy))/($graph($t,highy)-$graph($t,lowy)))]
}

proc GDrag {c ox oy} {
    global graph
    set t [GetWidFromCanvas $c]
    
    set x [expr $ox-$graph(bd)-$graph(origin)]
    set y [expr $oy-$graph(bd)-$graph(origin)]
    set zone [expr round($x/$graph($t,increment))]
    set gmove [expr abs($zone - $graph($t,oldzone))]
    if {$gmove} {
        set step [expr ($zone - $graph($t,oldzone))/$gmove]
        set incr [expr ($y - $graph($t,oldy))/$gmove]
        while {$graph($t,oldzone) != $zone} {
            set graph($t,oldzone) [expr $graph($t,oldzone) + $step]
            set graph($t,oldy) [expr $graph($t,oldy) + $incr]
            GStick $c $graph($t,oldzone) $graph($t,oldy)
        }
    } else {
        GClick $c $ox $oy
    }
}

proc GStick {c zone y} {
    global graph xvalue yvalue
    
    set t [GetWidFromCanvas $c]
    if {![CheckFloaty $graph($t,lowy) $graph($t,highy) $graph($t,lowx) $graph($t,highx)]} {
        return
    }
    set y [max 0 [min $graph($t,height) $y]]
    if {$zone >= 0 && $zone < [llength $graph($t,points)]} {
        set graph($t,points) [lreplace $graph($t,points) $zone $zone $y]
        if {$zone != 0} {
            AddLine $c $zone
        }
        if {$zone != [expr [llength $graph($t,points)] - 1]} {
            AddLine $c [expr $zone + 1]
        }
    }
    set xvalue [expr $graph($t,lowx) + \
            ($graph($t,highx)-$graph($t,lowx))*$zone/([llength $graph($t,points)]-1.0)]
    set yvalue [PointToYValue $t $y]
}

proc PointToYValue {t y} {
    global graph
    return [expr $graph($t,lowy) + \
            ($graph($t,highy)-$graph($t,lowy))*($y*1.0)/$graph($t,height)]
}

proc RedrawGrid {c w h inc} {
    global looks graph
    
#do_in_editor puts [list RedrawGrid $c $w $h $inc]
    $c delete grid
    set ylevel 0
    while {$ylevel <= 10} {
        set height [expr round($ylevel*$h/10.0)]
        $c create line 0 $height $w $height \
                -fill $looks(darkerColor) -tags grid
        set ylevel [expr $ylevel + 1]
    }
    set xlevel 0
    while {$xlevel <= $w} {
        $c create line [expr round($xlevel)] 0 [expr round($xlevel)] \
                $h -fill $looks(darkerColor) -tags grid
        set xlevel [expr $xlevel + $inc]
    }
    set miss [expr $graph(bd)+$graph(origin)]
    $c move grid $miss $miss
}

proc Reshape {t} {
    set gph [$t.gph getframe]
    set grid $gph.gridf.canvas

    SetCombos $t
    AttackShape $grid [winfo width $grid] [winfo height $grid]
}
    
proc AttackShape {c w h} {
    global graph
    
#do_in_editor puts [list AttackShape $c $w $h]
    # This version used to change the axis labels when the
    # graph window was resized. Now we keep them the same and stretch the graph
    set t [GetWidFromCanvas $c]
    
    set exag [expr 2*$graph(bd)+$graph(exag)]
    set graph($t,increment) [expr $graph($t,increment)*($w-$exag)/$graph($t,width)]
    set graph($t,width) [expr $w-$exag]
    
    set vchange [expr double($h-$exag)/$graph($t,height)]
    set graph($t,height) [expr $h-$exag]
    RedrawGrid $c $graph($t,width) $graph($t,height) $graph($t,increment)
    
    set graph($t,points) [lreplace $graph($t,points) 0 0 \
            [expr round([lindex $graph($t,points) 0]*$vchange)]]
    set section 1
    while {$section < [llength $graph($t,points)]} {
        set graph($t,points) [lreplace $graph($t,points) $section $section \
                [expr round([lindex $graph($t,points) $section]*$vchange)]]
        AddLine $c $section
        set section [expr $section + 1]
    }
}

proc CoarseX { c } {
    global graph
    
    set t [GetWidFromCanvas $c]
    if {[llength $graph($t,points)]%2} {
        $c delete graph
        set el 0
        set graph($t,increment) [expr $graph($t,increment)*2]
        while {$el < [llength $graph($t,points)]} {
            set graph($t,points) [lreplace $graph($t,points) \
                    $el [expr $el + 1] [lindex $graph($t,points) $el]]
            set el [expr $el + 1]
            AddLine $c $el
        }
        RedrawGrid $c $graph($t,width) $graph($t,height) $graph($t,increment)
    }
}

proc FineX { c } {
    global graph
    
    set t [GetWidFromCanvas $c]
    if {$graph($t,increment) >= 2.0} {
        $c delete graph
        set el 1
        set graph($t,increment) [expr $graph($t,increment)/2]
        while {$el < [llength $graph($t,points)]} {
            set graph($t,points) [linsert $graph($t,points) $el \
                    [expr ([lindex $graph($t,points) [expr $el - 1]] + \
                    [lindex $graph($t,points) $el])/2]]
            AddLine $c $el
            AddLine $c [expr $el + 1]
            set el [expr $el + 2]
        }
        RedrawGrid $c $graph($t,width) $graph($t,height) $graph($t,increment)
    }
}

#####################################################################
# TABLE LOADING
#####################################################################
proc equationDoTable {parent tgt startLine} {
    global table_entry iconImages tcl_platform
    PutItThere .table $parent
    wm title .table "Table data for [BlankCrs $tgt]"
    wm protocol .table WM_DELETE_WINDOW {set table_entry(done) 0}
    set table_entry(source) 0
    
    frame .table.top
    label .table.top.instructions -text "Create table from file by dragging \
            column headings to act as either indices or as data."
    pack .table.top.instructions -side top -anchor w -padx 2 -pady 2
    TitleFrame .table.top.fheads -text "Table column headings"
    set fheads [.table.top.fheads getframe]
    set lheads [ListBox $fheads.lheads -dragenabled true -dropenabled true \
            -selectmode single -dropcmd DeleteIndex \
            -yscrollcommand [list AdjustCanvas $fheads lheads y]]
    scrollbar $fheads.yscroll -orient v -command [list $fheads.lheads yview]
    pack $fheads.yscroll -side right -fill y
    
    TitleFrame .table.top.fidx -text "Use as indices"
    set fidx [.table.top.fidx getframe]
    set lidx [ListBox $fidx.lidx -dragenabled true -dropenabled true \
            -selectmode single \
            -dropcmd AddIndex]
    pack $lheads  -expand true -fill both
    pack .table.top.fheads -side left -expand true -fill both -anchor w -padx 2 -pady 2
    pack $lidx -expand true -fill both -anchor w
    if {!$startLine} {
	pack [set betweenf [frame $fidx.betweenf]] -expand true -fill x
	pack [label $betweenf.m -text "Between points:"] -side left
	pack [::ttk::combobox $betweenf.c -textvariable table_entry(others) \
		  -width 10 -values {"Use last" "Use closest" Interpolate} \
		  -state readonly]

	pack [set wrapf [frame $fidx.wrapf]] -expand true -fill x
	pack [label $wrapf.m -text "Wraparound at:"] -side left
	pack [entry $wrapf.e -width 1 -textvariable table_entry(wrapPt)] \
	    -side right -expand true -fill x
	if {[string equal restart [string tolower \
				       [lindex $table_entry(values) end]]]} {
	    set table_entry(oldWrapPt) [lindex $table_entry(values) end-1]
	    set table_entry(wrapPt) $table_entry(oldWrapPt)
	    set table_entry(values) [lrange $table_entry(values) 0 end-2]
	} else {
	    set table_entry(oldWrapPt) {}
	}
	if {[string equal others [string tolower \
				      [lindex $table_entry(values) end-1]]]} {
	    set table_entry(oldOthers) [TagToName \
					    [lindex $table_entry(values) end]]
	    set table_entry(others) $table_entry(oldOthers)
	    set table_entry(values) [lrange $table_entry(values) 0 end-2]
	} else {
	    set table_entry(oldOthers) {}
	}

    }
    pack .table.top.fidx -side left -expand true -fill both -anchor w -padx 2 -pady 2
    #
    # OK, Cancel and Help buttons
    frame .table.top.fbuttons
    button .table.top.fbuttons.edit -text View/Edit -width 10 \
	-command [list EditTableData $lidx $startLine]
    button .table.top.fbuttons.ok -text OK -width 10 \
	-command [list DoneTableData $lidx $startLine]
    button .table.top.fbuttons.cancel -text Cancel -width 10 \
	-command "set table_entry(done) 0"
    button .table.top.fbuttons.help -text Help -width 10 \
	-command {ContextSensitiveHelp .table equations/table.htm}
    pack .table.top.fbuttons.edit -side top -padx 4 -pady 4
    pack .table.top.fbuttons.ok -side top -padx 4 -pady 4
    pack .table.top.fbuttons.cancel -side top -padx 4 -pady 4
    pack .table.top.fbuttons.help -side top -padx 4 -pady 4
    pack .table.top.fbuttons -side left  -anchor e
    pack .table.top -side top -expand true -fill both -anchor w
    #
    # Data file and data column heading
    frame .table.bottom
    TitleFrame .table.bottom.fdata -text "Data file and column heading "
    set fdata [.table.bottom.fdata getframe]
    frame $fdata.captions 
    frame $fdata.entries
    frame $fdata.buttons 
    pack $fdata.captions -side left -fill y
    pack $fdata.entries -side left -expand true -fill both
    pack $fdata.buttons -side left -fill y

    label $fdata.captions.dheadlabel -text "Use as data column:"
    set dhead [Entry $fdata.entries.dhead \
            -textvariable table_entry(dataField) \
            -dropenabled true -droptypes LISTBOX_ITEM \
            -dropcmd ChooseDataHeader]
    pack $fdata.captions.dheadlabel -side top -anchor w -fill y -expand true
    pack $dhead -side top -expand true -fill x
    button $fdata.buttons.load -text Load -width 10 \
	-command [list AcquireTableData $lidx 1 $startLine]
    pack $fdata.buttons.load -side top -padx 4 -pady 4
    label $fdata.captions.dfilelabel -text "Data file:"
    set dfile [Entry $fdata.entries.dfile \
            -textvariable table_entry(fileName)]
    bind $dfile <Return> LoadDataFile
    pack $fdata.captions.dfilelabel -side bottom -anchor w -fill y -expand true
    pack $dfile -side bottom -expand true -fill x
    button $fdata.buttons.new -compound left -image $iconImages(open) \
	-text Browse -command {GetDataFile "Select new data file";LoadDataFile}
    pack $fdata.buttons.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack .table.bottom.fdata -fill x
    pack .table.bottom -side top -fill x
    
    set t .table
    LetItShow .table
    if {[llength $table_entry(data)]} {
        set table_entry(fileName) [lindex $table_entry(data) 0]
	set table_entry(dataField) [lindex $table_entry(data) 1]
	set table_entry(indices) [lrange $table_entry(data) 2 end]

	set i 1
	foreach idx $table_entry(indices) {
	    if {![string match ,* $idx]} { ;# this is wrap info
		$lidx insert end id$i -text $idx
	    }
	    incr i
	}
#	if {![LoadDataFile]} {
#	    destroy $t
#	    return 0
#	}
    } else {
#        if {![string compare \
#                    [GetDataFile "No data file yet specified"] {}]} {
#            return 0
#        }
        set table_entry(indices) {}
    }
    
#    if {![LoadDataFile]} {
#        return 0
#    }
    
    focus $t
    grab $t
    tkwait variable table_entry(done)
    grab release $t
    PackItUp $t
    grab $parent
    if {[info exists table_entry(others)] && [llength $table_entry(others)]} {
	lappend table_entry(values) others [NameToTag $table_entry(others)]
    }
    if {[info exists table_entry(wrapPt)] && [Numeric $table_entry(wrapPt)]} {
	lappend table_entry(values) $table_entry(wrapPt) restart
    }
    return $table_entry(done)
}

proc TagToName {tag} {
    string totitle [string map {_ { }} $tag]
}

proc NameToTag {name} {
    string map {{ } _} [string tolower $name]
}

proc EditTableData {lidx startLine} {
    global table_entry
    AcquireTableData $lidx 0 $startLine
    if {[llength $table_entry(values)]} {
	if {[EditListAsTable .table table_entry(values)]} {
	    set table_entry(source) 1
	}
    }
}

proc DoneTableData {lidx startLine} {
    global table_entry
    AcquireTableData $lidx 0 $startLine
    if {!$table_entry(source) && \
	    [info exists table_entry(wrapPt)] && \
	    ![string equal $table_entry(wrapPt) $table_entry(oldWrapPt)]} {
	set table_entry(source) 0.5
    }
    set table_entry(done) $table_entry(source)
}

proc AcquireTableData {lidx redo startLine} {
    global table_entry

    if {![llength $table_entry(dataField)]} {
	return
    }
    set idcs {}
    foreach itm [$lidx items] {
        lappend idcs [$lidx itemcget $itm -text]
    }
    set table_entry(indices) $idcs
    set tableSpec [concat [list $table_entry(fileName) \
			       $table_entry(dataField)] $table_entry(indices)]
    if {$redo || ![string equal $tableSpec $table_entry(data)]} {
#do_in_editor puts "Loading with $tableSpec not $table_entry(data)"
	set table_entry(values) [LoadTableData $tableSpec $startLine]
	set table_entry(source) 2
	set table_entry(data) $tableSpec
    }
}

proc EditListAsTable {parent valueArray} {
    global table_viewer

    PutItThere .table_edit $parent
    set t .table_edit.helperzone
    set b .table_edit.buttonzone
    wm title .table_edit "Table Editor"
    wm protocol .table_edit WM_DELETE_WINDOW {set table_viewer(done) 0}

    pack [frame $b] -side bottom
# button frame packed first so it is not squeeeezed if window dragged smaller
    pack [frame $t] -fill x -expand true
    pack [button $b.ok -text OK \
	      -command "set table_viewer(done) 1" -width 10] -padx 2 -pady 2 -side left
    pack [button $b.cancel -text Cancel \
	      -command "set table_viewer(done) 0" -width 10] -padx 2 -pady 2 -side left
    
    set viewerId $table_viewer(id)
    set ::${viewerId}::editMode($t) 1
    ${viewerId}::initialize $t

    upvar 1 $valueArray values
    set ${viewerId}::dataStore($t,0,0.0) $values
    set ${viewerId}::displayList($t) eqn_table
    set ${viewerId}::orientList($t) {none cols rows cols}
    set ${viewerId}::displayFormat($t,0) {General 4 0}
    ${viewerId}::Reconbobulate $t

    focus .table_edit
    LetItShow .table_edit
    grab .table_edit
    tkwait variable table_viewer(done)
    grab release .table_edit
    PackItUp .table_edit
# extract step at end so window still gone if it fails
    if {$table_viewer(done)} {
	set values [${viewerId}::ExtractEdits $t]
    }
    return $table_viewer(done)
}

proc GetDataFile {info} {
    global table_entry
    set table_entry(fileName) [ChooseFile graph.csv $info 0]
}

proc LoadDataFile {} {
    global table_entry
    
#    wm title .table "Create table from file $table_entry(fileName)"
    set fheads [.table.top.fheads getframe]
    $fheads.lheads delete [$fheads.lheads items]
    
    while {[catch {open $table_entry(fileName) r} stream]} {
        if {![string compare \
		 [GetDataFile "Cannot read file $table_entry(fileName)"] {}]} {
            return 0
        }
    }
    gets $stream firstLine
    set table_entry(allHeads) [split $firstLine ,]
    set i 1
    foreach hd $table_entry(allHeads) {
        $fheads.lheads insert end hd$i -text [string trim $hd]
        incr i
    }
    close $stream
    set fidx [.table.top.fidx getframe]
    $fidx.lidx delete [$fidx.lidx items]
    return 1
}

proc AddIndex {lb pth where op dtype data} {
    # work around an apparent bug where .c is appended to path name
    set path [string range $pth 0 [expr [string length $pth]-3]]
    if ![$lb exists $data] {
        $lb insert end $data -text [$path itemcget $data -text]
    }
}

proc DeleteIndex {lb pth where op dtype data} {
    # work around an apparent bug where .c is appended to path name
    set path [string range $pth 0 [expr [string length $pth]-3]]
    if ![string equal $lb $path] {
        $path delete $data
    }
}

proc ChooseDataHeader {eb pth where op dtype data} {
    # work around an apparent bug where .c is appended to path name
    set path [string range $pth 0 [expr [string length $pth]-3]]
    $eb configure -text [$path itemcget $data -text]
}

proc LoadTableData {tableSpec lineCount} {
    
#ShowMessage debug info "Loading table with data $tableSpec" ok
    set tStr [NetOpen [lindex $tableSpec 0] r]
    gets $tStr headerLine
    set headerList [TrimFields [split $headerLine ,]]
#ShowMessage debug info "Headers are $headerList" ok
    
    set headerCount 0
    set indexStart 2
    if {[string match ,wrap:* [lindex $tableSpec 2]]} { ;# its a special point
	set wrapPt [string range [lindex $tableSpec 2] 6 end]
	incr indexStart
    }
    if {[string match ,others:* [lindex $tableSpec $indexStart]]} {
	set fillMtd [string range [lindex $tableSpec $indexStart] 8 end]
	incr indexStart
    }
    foreach headerIndex [lrange $tableSpec $indexStart end] {
        lappend indexColumns [lsearch -exact $headerList $headerIndex]
        set maxIndices($headerCount) {}
        incr headerCount
    }
    if {!$headerCount} {
	# use line number as index
	set headerCount 1
	set maxIndices(0) {}
    }
    set headerColumn [lsearch -exact $headerList [lindex $tableSpec 1]]
#ShowMessage debug info "Columns: header $headerColumn indxs $indexColumns" ok
    if {$headerColumn==-1} {
	ShowMessage "Data column not found" warning "The file \"[lindex $tableSpec 0]\" does not contain a column with \"[lindex $tableSpec 1]\" as a heading. Please supply a heading to identify the data column from this list: $headerList." ok
	return
    }
    while {[gets $tStr entryLine] != -1} {
	set entryList [TrimFields [split $entryLine ,]]
#ShowMessage debug info "Data line is $entryList" ok
        if {![llength $entryList]} {
	    continue ;# ignore blank lines anywhere
	}
        if {[info exists indexColumns]} {
            set arrayIndex {}
            set indexCount 0
            foreach column $indexColumns {
                set newIndex [lindex $entryList $column]
		# enquote the above if indices of llength 1 are needed
		if {[llength $newIndex]} {
		    lappend arrayIndex $newIndex
		    if {[lsearch $maxIndices($indexCount) $newIndex] == -1} {
			lappend maxIndices($indexCount) $newIndex
		    }
		    incr indexCount
		} else {
		    # if there is an empty index field ignore the line
		    set badIndex 1
		    break
		}
            }
        } else {
	    lappend maxIndices(0) $lineCount
            set arrayIndex $lineCount
            incr lineCount
        }
        
        # ignore empty entries
	if {[info exists badIndex]} {
	    unset badIndex
	} else {
	    set potEntry [lindex $entryList $headerColumn]
	    if {[llength $potEntry]} {
		set paramArray(top,[join $arrayIndex ,]) \
		    [EnquoteIfNonNumeric $potEntry]
	    }
	}
    }
    
    for {set idxIdx 0} {$idxIdx < $headerCount} {incr idxIdx} {
        lappend indexList $maxIndices($idxIdx)
    }
    
#ShowMessage debug info "Converting [array get paramArray] with $indexList" ok
    close $tStr
    set result [ArrayToList paramArray top $indexList]
    if {[info exists fillMtd]} {
	lappend result others $fillMtd
    }
    if {[info exists wrapPt]} {
	lappend result $wrapPt restart
    }
    return $result
}

proc TrimFields {dataLine} {
    set entryList {}
    foreach entry $dataLine {
	lappend entryList [string trim $entry]
    }
    return $entryList
}

proc EnquoteIfNonNumeric {item} {
    if {[Numeric $item]} {
	return $item
    } else {
	return \"[string trim $item]\"
    }
}

proc ArrayToList {topArray indexSoFar otherMaxes} {
#ShowMessage debug info "$indexSoFar $otherMaxes" ok
    upvar 1 $topArray array
    if {[llength $otherMaxes]} {
        foreach pt [lindex $otherMaxes 0] {
            lappend result $pt [ArrayToList array $indexSoFar,$pt \
				    [lrange $otherMaxes 1 end]]
        }
    } else {
# See if we can get away without setting missing values to 0
        if {[info exists array($indexSoFar)]} {
	    set result $array($indexSoFar)
        } else {
            set result (empty)
        }
    }
    return $result
}
