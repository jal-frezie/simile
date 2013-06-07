# Simile source code file: Run/graphs.tcl
#
# (c) Simulistics Ltd. 2001-2008
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

proc odbcdriverFromExt { ext } {
    # e.g. [odbcdriverFromExt .xls] -> Microsoft Excel Driver (*.xls)
    package require tclodbc; #jmm ODBC

    set odbcdrivers [database drivers]
    set index [lsearch  -regexp $odbcdrivers ".*FileExtns=.*$ext.*"]
    if {$index == -1} {
	Query [list no_odbc_driver $ext] warning data_via_odbc {} ok
	return {}
    }
    return [lindex [lindex $odbcdrivers $index] 0]
}

# find all extensions there is driver to read

proc GraphEntry { t xlow xhigh xspan ylow yhigh yspan range size points \
            {target {}}} {
    global tcl_platform graph looks
    
    set graph(bd) 3
    
    switch $tcl_platform(platform) {
        unix {
            set graph(exag) 3
        } windows {
            set graph(exag) 5
        }
    }
    set graph($t,points) [split $points ,]
    set graph($t,lowy) $ylow
    set graph($t,highy) $yhigh
    set graph($t,height) $yspan
    set graph($t,lowx) $xlow
    set graph($t,highx) $xhigh
    set graph($t,width) $xspan
    
    catch {wm title $t [tr. "Sketch graph"]}
    
    TitleFrame $t.gph -text [tr. "Graph pad"]
    set gph [GetFrame $t.gph]
    frame $gph.yentry
    ::ttk::entry $gph.yentry.topentry -textvar graph($t,lowy) -width 8
    pack $gph.yentry.topentry -side top -pady 2
    label $gph.yentry.toplabel -text [tr. "Y max"]
    pack $gph.yentry.toplabel -side top -pady 2
    label $gph.yentry.label -text [tr. "Value"]
    pack $gph.yentry.label -side top -fill y -expand true
    label $gph.yentry.bottomlabel -text [tr. "Y min"]
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
    label $gph.xentry.xmin -text [tr. "X min"]
    pack $gph.xentry.xmin -side left -padx 2
    label $gph.xentry.arg -text [tr. "Argument"]
    pack $gph.xentry.arg  -side left -fill x -expand true
    label $gph.xentry.rightlabel -text [tr. "X max"]
    pack $gph.xentry.rightlabel -side left -padx 2
    ::ttk::entry $gph.xentry.rightentry -textvar graph($t,highx) -width 8
    pack $gph.xentry.rightentry -side left -padx 2
    grid $gph.xentry -column 1 -row 1 -sticky we -padx 2 -pady 2
    
    frame $t.right
    
    set buttons [frame $t.right.buttons]
    button $buttons.enter -text [tr. OK] -width 10
    pack $buttons.enter -padx 4 -pady 4 -anchor e
    button $buttons.cancel -text [tr. Cancel] -width 10
    pack $buttons.cancel -padx 4 -pady 4 -anchor e
    button $buttons.edit -text [tr. "Edit as table"] -width 10 \
            -command [list EditAsTable $t $grid]
    pack $buttons.edit -padx 4 -pady 4 -anchor e
    button $buttons.help -text [tr. Help] -width 10 -command {ContextSensitiveHelp .graph equations/graph.htm}
    pack $buttons.help -padx 4 -pady 4 -anchor e
    pack $buttons -fill x -padx 8 -pady 8
    set looks(darkerColor) [$buttons.enter cget -disabledforeground]
    
    if {[llength $target]} {
	set graph($t,mode) helper
        $buttons.enter configure -command \
                [namespace code [list UpdateGraph $t $target]]
        $buttons.cancel configure -command \
                [namespace code [list RestoreSketch $t $target]]
    } else {
	set graph($t,mode) equation
        $buttons.enter configure -command [list set graph($t,done) 1]
        $buttons.cancel configure -command [list set graph($t,done) 0]
        bind $t <Destroy> "set graph($t,done) -1"
    }
    
    TitleFrame $t.right.current -text [tr. "Current Position: "]
    set current [GetFrame $t.right.current]
    
    frame $current.y
    label $current.y.yvalue -text [tr. "Y:"]
    pack $current.y.yvalue -side left -padx 2 -pady 4
    ::ttk::entry $current.y.yvaluebox -textvar yvalue -width 8
    bind $current.y.yvaluebox <Return> [list YEntry $grid]
    pack $current.y.yvaluebox -side left -padx 2 -pady 4
    pack $current.y -pady 4
    frame $current.x
    label $current.x.xvalue -text [tr. "X:"]
    pack $current.x.xvalue -side left -padx 2 -pady 4
    ::ttk::entry $current.x.xvaluebox -textvar xvalue -width 8
    pack $current.x.xvaluebox -side left  -padx 2 -pady 4
    pack $current.x -pady 4
    pack $current -pady 8 -padx 4 -fill x
    pack $t.right.current -pady 2 -padx 2 -fill x
    pack $t.right -side right -fill y
    
    TitleFrame $t.right.options -text [tr. "Options: "]
    set right [GetFrame $t.right.options]
    
    set between [frame $right.between]
    label $between.outrange -text [tr. "Between points:"]
    pack $between.outrange
    # Code fragment to switch to using menubutton from ComboBox
    # Work in progress / Alastair 9 Feb 2005
    #    set m [menu $between.outrangeMenu]
    #    foreach item {Interpolate Round} {
    #      $m add command -label $item -command "Reshape $t $item"
    #    }
    #    set mb [::ttk::menubutton $between.rangeopts -menu $m -text [tr. Interpolate]]
    #    pack $mb
    
    #    pack [ComboBox $between.rangeopts -values "Interpolate Round" -editable 0 \
    #	      -modifycmd "Reshape $t" -width 12]
    ::ttk::menubutton $between.rangeopts
    set betweenMenu [menu $between.rangeopts.menu -tearoff 0]
    foreach unit {Interpolate Round} {
	set trUnit [tr. $unit]
# TRANSLATOR: values in brackets above
        $betweenMenu add command -label $trUnit \
                -command "set graph($t,betweenOpt) $trUnit;Reshape $t"
    }
    $between.rangeopts configure -menu $betweenMenu -width 11 \
            -textvariable graph($t,betweenOpt)
    pack $between.rangeopts -side left -anchor nw
    
    pack $between -pady 8 -padx 4
    set out [frame $right.out]
    label $out.outrange -text [tr. "Out of range:"]
    pack $out.outrange
    #    pack [ComboBox $out.rangeopts -values "Truncate Extrapolate Wraparound" \
    #	      -editable 0 -width 12]
    ::ttk::menubutton $out.rangeopts
    set outMenu [menu $out.rangeopts.menu -tearoff 0]
    foreach unit {Truncate Extrapolate Wraparound} {
	set trUnit [tr. $unit]
# TRANSLATOR: values in brackets above
        $outMenu add command -label $trUnit \
	    -command "set graph($t,outOpt) $trUnit"
    }
    $out.rangeopts configure -menu $outMenu -width 11 \
            -textvariable graph($t,outOpt)
    pack $out.rangeopts -side left -anchor nw
    
    pack $out -pady 8 -padx 4
    SetCombos $t $range
    
    set resolution [frame $right.resolution]
    label $resolution.detail -text [tr. "X axis resolution:"]
    pack $resolution.detail
    set db [frame $resolution.detailbox]
# ArrowButtons reverted as they are BWidgets
    ::ttk::button $resolution.detailbox.less -text [tr. Less] -width 0 \
	-command "CoarseX $db $grid"
    #    ArrowButton $resolution.detailbox.arrowleft -type button -dir \
            left -command "CoarseX $db $grid" -width 25 -height 25 -clean 2
    pack $resolution.detailbox.less -side left
    ::ttk::button $resolution.detailbox.more -text [tr. More] -width 0 \
	-command "FineX $db $grid"
    #    ArrowButton $resolution.detailbox.arrowright -type button -dir right \
            -command "FineX $db $grid" -width 25 -height 25 -clean 2
    pack $resolution.detailbox.more -side left
    pack $resolution.detailbox
    pack $resolution -pady 8 -padx 4 -fill both
    pack $right -fill both
    pack $t.right.options -fill both -padx 2 -pady 2 -expand true
    AbleArrows $db $t
    
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
    set grid [GetFrame $t.gph].gridf.canvas
    AttackShape $grid [winfo width $grid] [winfo height $grid]
}

proc SetCombos {t args} {
    global graph
    set right [GetFrame $t.right.options]
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
    if {[EditListAsTable $t Value 1 table]} {
        foreach {index y} $table {
            set zone [expr round(($size-1.0)*($index-$graph($t,lowx))/$range)]
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
        Query [list number_needed [lindex $args 0]] warning top {} ok
        return 0
    } else {
        return [eval CheckFloaty [lrange $args 1 end]]
    }
}

proc GetWidFromCanvas {c} {
    return [winfo parent [GetFrame [winfo parent [winfo parent $c]]]]
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
    set wrapLine [string equal [tr. Wraparound] $graph($t,outOpt)]
    set y [max 0 [min $graph($t,height) $y]]
    set pts [expr {[llength $graph($t,points)]-1}]
    if {$zone >= 0 && $zone <= $pts} {
        set graph($t,points) [lreplace $graph($t,points) $zone $zone $y]
        if {$zone == 0} {
	    if {$wrapLine} {
		lset graph($t,points) $pts $y
		AddLine $c $pts
	    }
	} else {
            AddLine $c $zone
        }
        if {$zone == $pts} {
	    if {$wrapLine} {
		lset graph($t,points) 0 $y
		AddLine $c 1
	    }
	} else {
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
    set gph [GetFrame $t.gph]
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

proc CoarseX { db c } {
    global graph
    
    set t [GetWidFromCanvas $c]
    $c delete graph
    set el 0
    set graph($t,increment) [expr $graph($t,increment)*2]
    while {$el < [llength $graph($t,points)]} {
	set graph($t,points) [lreplace $graph($t,points) $el [expr $el + 1] \
				  [lindex $graph($t,points) $el]]
	set el [expr $el + 1]
	AddLine $c $el
    }
    RedrawGrid $c $graph($t,width) $graph($t,height) $graph($t,increment)
    AbleArrows $db $t
}

proc FineX { db c } {
    global graph
    
    set t [GetWidFromCanvas $c]
    $c delete graph
    set el 1
    set graph($t,increment) [expr $graph($t,increment)/2]
    while {$el < [llength $graph($t,points)]} {
	set graph($t,points) \
	    [linsert $graph($t,points) $el \
		 [expr ([lindex $graph($t,points) [expr $el - 1]] + \
			    [lindex $graph($t,points) $el])/2]]
	AddLine $c $el
	AddLine $c [expr $el + 1]
	set el [expr $el + 2]
    }
    RedrawGrid $c $graph($t,width) $graph($t,height) $graph($t,increment)
    AbleArrows $db $t
}

proc AbleArrows {db t} {
    global graph

    if {[llength $graph($t,points)]%2} {
	$db.less configure -state normal
    } else {
	$db.less configure -state disabled
    }
    if {$graph($t,increment) < 2.0 || \
	    [string equal equation $graph($t,mode)] && \
	    [llength $graph($t,points)]>120} {
	$db.more configure -state disabled
    } else {
	$db.more configure -state normal
    }
}
#####################################################################
# TABLE LOADING
#####################################################################
set commonTimes [list second minute hour day week month year]
proc equationDoTable {parent mdl tgt dims dlgStyle} {
    global table_entry iconImages tcl_platform
    
    PutItThere .table $parent
    set haveDND [llength [package provide tkdnd]]
    wm title .table "Table data for [BlankCrs "$tgt $dims"]"
    wm protocol .table WM_DELETE_WINDOW {set table_entry(done) 0}
    set table_entry(source) -1
    
    set t [::ttk::notebook .table.notebook]
    $t add [set fc [frame $t.columns]] -text [tr. "Data in column"]
    # Data file and data column heading
    label $fc.instructions -wrap 400 \
	-text [tr. "Choose a data file, select a worksheet if necessary, then create table from file by dragging column headings to act either as indices or as data."]
    pack $fc.instructions -side top -padx 2 -pady 2
    TitleFrame $fc.fdata -text [tr. "Data file "]
    set fdata [GetFrame $fc.fdata]
    set dfile [ttk::entry $fdata.dfile -textvariable table_entry(fileName)]
# xview end not working (8.5.11) so xview moveto 1 instead
    $dfile xview moveto 1
    bind $dfile <Return> "LoadDataFile columns 0 $mdl"
    KoreanClick $dfile 1 {}
    bind $dfile <Double-1> "LoadDataFile columns 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text [tr. Browse] \
            -command "LoadDataFile columns 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $fc.fdata -fill x
    # new frame December 2008 for the choice of data table in a database JMM
    TitleFrame $fc.ftable -text [tr. "Database table or worksheet "]
    set ftable [GetFrame $fc.ftable]
    pack $ftable -side top -expand true -fill x
    pack $fc.ftable
    # dropdown combobox for table names
    set tablecb [ttk::combobox $ftable.tablecb -state readonly  -width 50 -textvariable table_entry(dbtable)]
    pack $tablecb -side left
    # end new frame December 2008 for the choice of data table in a database JMM
    TitleFrame $fc.fheads -text [tr. "Table column headings"]
    set fheads [GetFrame $fc.fheads]
    if {$haveDND} {
	set lheads [listbox $fheads.lheads -selectmode single \
			-yscrollcommand [list AdjustCanvas $fheads lheads y]]
	tkdnd::drag_source register $lheads DND_Text
	bind $lheads <<DragInitCmd>> {DragElementOut %W %X %Y}
    } else {
	set lheads [ListBox $fheads.lheads -dragenabled true -dropenabled true \
		    -selectmode single -dropcmd DeleteIndex \
		    -yscrollcommand [list AdjustCanvas $fheads lheads y]]
    }
    scrollbar $fheads.yscroll -orient v -command [list $fheads.lheads yview]
    pack $fheads.yscroll -side right -fill y
    
    frame $fc.select
    TitleFrame $fc.select.idxs -text [tr. "Use as indices"]
    set fidx [GetFrame $fc.select.idxs]
    if {$haveDND} {
	set lidx [listbox $fidx.lidx -selectmode single]
	tkdnd::drop_target register $lidx DND_Text
	bind $lidx <<DropPosition>> {TrackDropCoords %X %Y move}
	bind $lidx <<Drop>> {InsertElement %W %D move}
	tkdnd::drag_source register $lidx DND_Text
	bind $lidx <<DragInitCmd>> {DragElementOut %W %X %Y}
	bind $lidx <<DragEndCmd>> {RemoveExtractedElt %W}
    } else {
	set lidx [ListBox $fidx.lidx -dragenabled true -dropenabled true \
		  -selectmode single \
		  -dropcmd AddIndex]
    }
    pack $lheads  -expand true -fill both
    pack $fc.fheads -side left -expand true -fill both -anchor w -padx 2 -pady 2
    pack $lidx -expand true -fill both -anchor w
    pack $fc.select.idxs -expand true -fill both -anchor w \
            -padx 2 -pady 2
    
    TitleFrame $fc.select.data -text [tr. "Use as data"]
    set didx [GetFrame $fc.select.data]
    if {$haveDND} {
	set dhead [ttk::entry $didx.dhead \
		   -textvariable table_entry(dataField)]
	tkdnd::drop_target register $dhead DND_Text
	bind $dhead <<DropPosition>> {TrackDropCoords %X %Y move}
	bind $dhead <<Drop>> {ReplaceText %W %D move}
    } else {
	set dhead [Entry $didx.dhead \
		       -textvariable table_entry(dataField) \
		       -dropenabled true -droptypes LISTBOX_ITEM \
		       -dropcmd ChooseDataHeader]
    }
    KoreanClick $lheads 1 {}
    bind $lheads <Double-1> [list PutInDataField $lheads $dhead $haveDND]
    pack $dhead -side top -expand true -fill x
    pack $fc.select.data -expand true -fill x -anchor w \
            -padx 2 -pady 2
    pack $fc.select -side left -expand true -fill both
    
    $t add [set fg [frame $t.grid]] -text [tr. "Data in grid"]
    label $fg.instructions -wrap 400 -text [tr. "Choose a data file, then select row and column at which to start and finish loading data."]
    pack $fg.instructions -side top -padx 2 -pady 2
    TitleFrame $fg.fdata -text [tr. "Data file "]
    set fdata [GetFrame $fg.fdata]
    set dfile [ttk::entry $fdata.dfile -textvariable table_entry(fileName)]
    $dfile xview moveto 1
    bind $dfile <Return> "LoadDataFile grid 0 $mdl"
    KoreanClick $dfile 1 {}
    bind $dfile <Double-1> "LoadDataFile grid 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text [tr. Browse] \
            -command "LoadDataFile grid 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $fg.fdata -fill x
    TitleFrame $fg.limits -text [tr. "Boundaries of area to load "]
    set flim [GetFrame $fg.limits]
    pack [ttk::checkbutton $flim.transpose -variable table_entry(xpose) \
	      -text [tr. "Transpose (so columns are outer dimension)"]] -side bottom
    pack [frame $flim.ycapt] -side left -fill both -expand true
    pack [frame $flim.yval] -side left -fill both -expand true
    pack [frame $flim.xcapt] -side left -fill both -expand true
    pack [frame $flim.xval] -side left -fill both -expand true
    
    pack [label $flim.ycapt.lo -text [tr. "Start at row:"]] \
            -expand true -fill x
    pack [label $flim.ycapt.hi -text [tr. "Finish at row:"]] \
            -expand true -fill x
    pack [label $flim.ycapt.idx -text [tr. "Row index from:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.lo -text [tr. "Start at column:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.hi -text [tr. "Finish at column:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.idx -text [tr. "Column index from:"]] \
            -expand true -fill x
    
    pack [ttk::entry $flim.yval.lo -textvariable table_entry(row1)] \
            -expand true -fill x
    pack [ttk::entry $flim.yval.hi -textvariable table_entry(rown)] \
            -expand true -fill x
    pack [ttk::combobox $flim.yval.idx -width 16 -state readonly \
	      -textvariable table_entry(irow) -values $table_entry(irow_txts)] \
	-expand true -fill x
    set table_entry(irow) [lindex $table_entry(irow_txts) 0]
# in case not used before
    pack [ttk::entry $flim.xval.lo -textvariable table_entry(col1)] \
            -expand true -fill x
    pack [ttk::entry $flim.xval.hi -textvariable table_entry(coln)] \
            -expand true -fill x
    pack [ttk::combobox $flim.xval.idx -width 16 -state readonly \
	      -textvariable table_entry(icol) -values $table_entry(icol_txts)] \
	-expand true -fill x
    set table_entry(icol) [lindex [$flim.xval.idx cget -values] 0]
# in case not used before
    pack $fg.limits -fill both -expand true
    
    $t add [set fi [frame $t.image]] -text [tr. "Data from image"]
    label $fi.instructions -wrap 400 -text [tr. "Choose an image file, then select row and column at which to start and finish loading data, and method for interpreting colours."]
    pack $fi.instructions -side top -padx 2 -pady 2
    TitleFrame $fi.fdata -text [tr. "Image file "]
    set fdata [GetFrame $fi.fdata]
    set dfile [ttk::entry $fdata.dfile -textvariable table_entry(fileName)]
    $dfile xview moveto 1
    bind $dfile <Return> "LoadDataFile image 0 $mdl"
    KoreanClick $dfile 1 {}
    bind $dfile <Double-1> "LoadDataFile image 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text [tr. Browse] \
            -command "LoadDataFile image 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $fi.fdata -fill x
    TitleFrame $fi.limits -text [tr. "Boundaries of area to load "]
    set flim [GetFrame $fi.limits]
    pack [ttk::checkbutton $flim.transpose -variable table_entry(xpose) \
	      -text [tr. "Transpose (so X positions are outer dimension)"]] \
	-side bottom
    pack [frame $flim.ycapt] -side left -fill both -expand true
    pack [frame $flim.yval] -side left -fill both -expand true
    pack [frame $flim.xcapt] -side left -fill both -expand true
    pack [frame $flim.xval] -side left -fill both -expand true
    
    pack [label $flim.ycapt.lo -text [tr. "Start at Y position:"]] \
            -expand true -fill x
    pack [label $flim.ycapt.hi -text [tr. "Finish at Y position:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.lo -text [tr. "Start at X position:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.hi -text [tr. "Finish at X position:"]] \
            -expand true -fill x
    
    pack [ttk::entry $flim.yval.lo -textvariable table_entry(row1)] \
            -expand true -fill x
    pack [ttk::entry $flim.yval.hi -textvariable table_entry(rown)] \
            -expand true -fill x
    pack [ttk::entry $flim.xval.lo -textvariable table_entry(col1)] \
            -expand true -fill x
    pack [ttk::entry $flim.xval.hi -textvariable table_entry(coln)] \
            -expand true -fill x
    pack $fi.limits -fill both -expand true
    
    TitleFrame $fi.interp -text [tr. "Values for colours: "]
    set fterp [GetFrame $fi.interp]
    set fbounds [frame $fterp.bounds]
    pack [label $fbounds.bklabel -text [tr. "Value for black:"]] \
            -side left -expand true -fill x
    pack [ttk::entry $fbounds.bkentry -textvariable table_entry(blkval)] \
            -side left -expand true -fill x
    pack [label $fbounds.wtlabel -text [tr. "Value for white:"]] \
            -side left -expand true -fill x
    pack [ttk::entry $fbounds.wtentry -textvariable table_entry(whtval)] \
            -side left -expand true -fill x
    pack $fbounds
    
    set fcols [frame $fterp.cols]
    pack [label $fcols.trlabel -text [tr. "Value for clear:"]] \
            -side left -expand true -fill x
    pack [ttk::entry $fcols.trentry -textvariable table_entry(trnval)] \
            -side left -expand true -fill x
    pack [label $fcols.clabel -text [tr. "For other colours:"]] \
            -side left -expand true -fill x
    pack [::ttk::combobox $fcols.c -textvariable table_entry(othval) \
	      -values $table_entry(oth_txts) -width 16 -state readonly]
    set table_entry(othval) [lindex $table_entry(oth_txts) 0]
    pack $fcols
    pack $fi.interp -fill both -expand true
    
    $t add [set ft [frame $t.gdal]] -text [tr. "Data from GeoTIFF etc."]
    label $ft.instructions -wrap 400 -text [tr. "Choose a georeferenced data file, then select row and column at which to start and finish loading data."]
    pack $ft.instructions -side top -padx 2 -pady 2
    TitleFrame $ft.fdata -text [tr. "Data file "]
    set fdata [GetFrame $ft.fdata]
    set dfile [ttk::entry $fdata.dfile -textvariable table_entry(fileName)]
    $dfile xview moveto 1
    bind $dfile <Return> "LoadDataFile gdal 0 $mdl"
    KoreanClick $dfile 1 {}
    bind $dfile <Double-1> "LoadDataFile gdal 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text [tr. Browse] \
            -command "LoadDataFile gdal 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $ft.fdata -fill x
    TitleFrame $ft.limits -text [tr. "Boundaries of area to load "]
    set flim [GetFrame $ft.limits]
    pack [ttk::checkbutton $flim.transpose -variable table_entry(xpose) \
	      -text [tr. "Transpose (so columns are outer dimension)"] \
	      -state disabled] -side bottom ;# not working yet
    pack [frame $flim.ycapt] -side left -fill both -expand true
    pack [frame $flim.yval] -side left -fill both -expand true
    pack [frame $flim.xcapt] -side left -fill both -expand true
    pack [frame $flim.xval] -side left -fill both -expand true
    
    pack [label $flim.ycapt.lo -text [tr. "Start at row:"]] \
            -expand true -fill x
    pack [label $flim.ycapt.hi -text [tr. "Finish at row:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.lo -text [tr. "Start at column:"]] \
            -expand true -fill x
    pack [label $flim.xcapt.hi -text [tr. "Finish at column:"]] \
            -expand true -fill x
    
    pack [ttk::entry $flim.yval.lo -textvariable table_entry(row1)] \
            -expand true -fill x
    pack [ttk::entry $flim.yval.hi -textvariable table_entry(rown)] \
            -expand true -fill x
    pack [ttk::entry $flim.xval.lo -textvariable table_entry(col1)] \
            -expand true -fill x
    pack [ttk::entry $flim.xval.hi -textvariable table_entry(coln)] \
            -expand true -fill x
    pack $ft.limits -fill both -expand true
    
    set arrayDims {}
    switch $dims {
        "(defined by values)" {
            set needsETs 1
        } "(data determines dimensions)" {
            set dimsFromData 1
        } default {
            foreach {dimVal sep} [string range $dims 1 end-1] { ;# dequote
                #puts "arrayType -$dimVal- sep -$sep-"
                if {[string length $sep]} {
                    lappend arrayDims $dimVal
                    if {![Numeric $dimVal]} {
                        if {[lsearch {TIME RECORDS} $dimVal]==-1} {
                            set needsETs 1
                        } else {
                            set dimsFromData 1
                        }
                    }
                } else {
                    set arrayType $dimVal
                    if {[lsearch {REAL INTEGER BOOLEAN} $dimVal]==-1} {
                        set needsETs 1
                    }
                }
            }
        }
    }
    if {[info exists needsETs]} {
        $t tab $t.image -state disabled
        $t tab $t.gdal -state disabled
    } elseif {[llength $arrayDims]!=2} {
	$t tab $t.grid -state disabled
	$t tab $t.image -state disabled
	$t tab $t.gdal -state disabled
    }
    
    #
    # OK, Cancel and Help buttons
    frame .table.fbuttons
    set startLine [expr {[lsearch {fixed result} $dlgStyle]>-1}]
# 0 for times, 1 for array indices
    if {!$startLine} {
        pack [TitleFrame .table.fbuttons.wrapf -text [tr. "Time options: "]] \
                -padx 4 -pady 4 -expand true -fill x
        set wrapf [GetFrame .table.fbuttons.wrapf]
        pack [label $wrapf.um -text [tr. "Units for indices:"]]
        pack [::ttk::combobox $wrapf.uc -textvariable table_entry(uftsi) \
		  -width 10 -values [concat unit $::commonTimes] \
		  -state normal]
	set table_entry(uftsi) unit
	if {$dlgStyle eq "continuous"} {
	    pack [label $wrapf.bm -text [tr. "Between points:"]]
	    pack [::ttk::combobox $wrapf.bc -textvariable table_entry(others) \
		      -width 10 -values $table_entry(between_txts) \
		      -state readonly]
	    set table_entry(others) [lindex $table_entry(between_txts) 0]
	}
	if {!($dlgStyle eq "measure")} {
	    pack [label $wrapf.wm -text [tr. "Wraparound at:"]]
	    pack [entry $wrapf.we -width 1 -textvariable table_entry(wrapPt)] \
                -expand true -fill x
	    if {[string equal restart [string tolower \
					   [lindex $table_entry(values) end]]]} {
		set table_entry(oldWrapPt) [lindex $table_entry(values) end-1]
		set table_entry(wrapPt) $table_entry(oldWrapPt)
		set table_entry(values) [lrange $table_entry(values) 0 end-2]
	    } else {
		set table_entry(oldWrapPt) {}
	    }
        }
        if {[string equal others [string tolower \
				      [lindex $table_entry(values) end-1]]]} {
            set table_entry(oldOthers) \
		[lindex $table_entry(between_txts) \
		     [lsearch $table_entry(between_keys) \
			  [lindex $table_entry(values) end]]]
            set table_entry(others) $table_entry(oldOthers)
            set table_entry(values) [lrange $table_entry(values) 0 end-2]
        } else {
            set table_entry(oldOthers) {}
        }
        if {[string equal interval [string tolower \
					[lindex $table_entry(values) end-1]]]} {
            set table_entry(oldUftsi) [lindex $table_entry(values) end]
	    set table_entry(uftsi) $table_entry(oldUftsi)
            set table_entry(values) [lrange $table_entry(values) 0 end-2]
        } else {
            set table_entry(oldUftsi) {}
        }
    } else {
	array unset table_entry others
	array unset table_entry wrapPt
	array unset table_entry uftsi
    }
    if {![string equal .equation $parent]} {
        pack [checkbutton .table.fbuttons.keepvals -var table_entry(bytes) \
                -text [tr. "Include values in scenario files"] -wrap 200 \
                -command "set table_entry(source) 1"] -padx 4 -pady 4
# comments section : new for 5.6 : should be scrollable!
	pack [text .table.commentt -height 4] -side bottom -fill x -expand 1
	if {[info exists table_entry(comment)]} {
	    .table.commentt insert end $table_entry(comment)
	}
	AllowTextDrags .table.commentt
	
	label .table.commentl -text [tr. "Comments regarding values:"]
	pack .table.commentl -side bottom
    }
    
    button .table.fbuttons.clear -text [tr. Clear] -width 10 \
            -command [list ClearTableData]
    button .table.fbuttons.load -text [tr. Reload] -width 10 \
            -command [list AcquireTableData 1 $startLine]
    button .table.fbuttons.edit -text [tr. View/Edit] -width 10 \
            -command [list EditTableData $startLine $tgt $arrayDims]
    button .table.fbuttons.ok -text [tr. OK] -width 10 \
            -command [list DoneTableData $startLine]
    button .table.fbuttons.cancel -text [tr. Cancel] -width 10 \
            -command "set table_entry(done) 0"
    button .table.fbuttons.help -text [tr. Help] -width 10 \
            -command {ContextSensitiveHelp .table data/table.htm}
    pack .table.fbuttons.clear -side top -padx 4 -pady 4
    pack .table.fbuttons.load -side top -padx 4 -pady 4
    pack .table.fbuttons.edit -side top -padx 4 -pady 4
    pack .table.fbuttons.ok -side top -padx 4 -pady 4
    pack .table.fbuttons.cancel -side top -padx 4 -pady 4
    pack .table.fbuttons.help -side top -padx 4 -pady 4
    pack .table.fbuttons -side right  -anchor e
    pack $t -side left -expand true -fill both
    #

    set t .table
    LetItShow .table
    if {[llength $table_entry(data)]} {
        set table_entry(fileName) [lindex $table_entry(data) 0]
        switch [lindex $table_entry(data) 1] {
            ,grid {
                .table.notebook select .table.notebook.grid
                set table_entry(row1) [lindex $table_entry(data) 2]
                set table_entry(rown) [lindex $table_entry(data) 3]
                set table_entry(col1) [lindex $table_entry(data) 4]
                set table_entry(coln) [lindex $table_entry(data) 5]
		set table_entry(xpose) [lindex $table_entry(data) 6]
                set table_entry(irow) \
		    [lindex $table_entry(irow_txts) \
			 [lsearch $table_entry(irow_keys) \
			      [lindex $table_entry(data) 7]]]
                set table_entry(icol) \
		    [lindex $table_entry(icol_txts) \
			 [lsearch $table_entry(icol_keys) \
			      [lindex $table_entry(data) 8]]]
            } ,image {
                .table.notebook select .table.notebook.image
                set table_entry(row1) [lindex $table_entry(data) 2]
                set table_entry(rown) [lindex $table_entry(data) 3]
                set table_entry(col1) [lindex $table_entry(data) 4]
                set table_entry(coln) [lindex $table_entry(data) 5]
                set table_entry(blkval) [lindex $table_entry(data) 6]
                set table_entry(whtval) [lindex $table_entry(data) 7]
                set table_entry(trnval) [lindex $table_entry(data) 8]
                set table_entry(othval) \
		    [lindex $table_entry(oth_txts) \
			 [lsearch $table_entry(oth_keys) \
			      [lindex $table_entry(data) 9]]]
		set table_entry(xpose) [lindex $table_entry(data) 10]
            } ,gdal {
                .table.notebook select .table.notebook.gdal
                set table_entry(row1) [lindex $table_entry(data) 2]
                set table_entry(rown) [lindex $table_entry(data) 3]
                set table_entry(col1) [lindex $table_entry(data) 4]
                set table_entry(coln) [lindex $table_entry(data) 5]
		set table_entry(xpose) [lindex $table_entry(data) 6]
            } default {
                .table.notebook select .table.notebook.columns
                set table_entry(dataField) [lindex $table_entry(data) 1]
                set table_entry(indices) [lrange $table_entry(data) 2 end]
                set i 1
                foreach idx $table_entry(indices) {
                    if {![string match ,* $idx]} { ;# this is wrap or db info
                        $lidx insert end $idx
                    }
                    incr i
                }
            }
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
	set table_entry(xpose) 0 ;# ttk checkbutton doesnt set this unless hit
        if {[info exists table_entry(indices)] && \
		[llength $table_entry(indices)]} {
	    LoadDataFile columns 0 $mdl
	    set i 1
	    foreach idx $table_entry(indices) {
		if {![string match ,* $idx]} { ;# this is wrap or db info
		    $lidx insert end $idx
		}
		incr i
	    }
	} else {
	    set table_entry(indices) {}
	}
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
    if {[info exists table_entry(uftsi)] && [llength $table_entry(uftsi)] && \
	    ![string equal unit $table_entry(uftsi)] && \
	    ![string equal interval [lindex $table_entry(values) end-1]]} {
        lappend table_entry(values) interval $table_entry(uftsi)
    }
    if {[info exists table_entry(others)] && [llength $table_entry(others)] && \
                ![string equal others [lindex $table_entry(values) end-1]]} {
        lappend table_entry(values) others \
	    [lindex $table_entry(between_keys) \
		 [lsearch $table_entry(between_txts) $table_entry(others)]]
    }
    if {[info exists table_entry(wrapPt)] && [Numeric $table_entry(wrapPt)] && \
                ![string equal restart [lindex $table_entry(values) end]]} {
        lappend table_entry(values) $table_entry(wrapPt) restart
    }
    return $table_entry(done)
}

proc TrackDropCoords {x y act} {
    array set ::dropPosn [list x $x y $y]
    return $act
}

proc InsertElement {win data act} {
    set localY [expr {$::dropPosn(y)-[winfo rooty $win]}]
    $win insert end mark
    $win insert [$win nearest $localY] $data
    $win delete end
    return $act
}

proc ReplaceText {win data act} {
    $win delete 0 end
    $win insert end $data
    return $act
}


proc AllowTextDrags {txt} {
    if {![llength [package provide tkdnd]]} return

    tkdnd::drop_target register $txt DND_Text
    bind $txt <<DropPosition>> {TrackDropCoords %X %Y copy}
    bind $txt <<Drop>> {InsertText %W %D copy}
# do not allow drag out of text widgets because dragging sweeps a selection
}

proc InsertText {win data act} {
    set localX [expr {$::dropPosn(x)-[winfo rootx $win]}]
    set localY [expr {$::dropPosn(y)-[winfo rooty $win]}]
    $win insert @$localX,$localY $data
    return $act
}

proc DragElementOut {wid x y} {
#    set localX [expr {$x-[winfo rootx $wid]}]
#    set localY [expr {$y-[winfo rooty $wid]}]
#    $wid activate @$localX,$localY 
# above gets it wrong sometimes...should already be active from click?
    return [list move DND_Text [$wid get [$wid curselection]]]
}

proc RemoveExtractedElt {wid} {
    $wid delete [$wid curselection]
}

proc PutInDataField {source dest haveDND} {
    $dest delete 0 end
    if {$haveDND} {
	$dest insert 0 [$source get [$source curselection]]
    } else {
	$dest insert 0 [$source itemcget [$source selection get] -text]
    }
}

proc TagToName {tag} {
    string totitle [string map {_ { }} $tag]
}

proc NameToTag {name} {
    string map {{ } _} [string tolower $name]
}

foreach comboboxEng [list "Position in data area" \
			 "First column in grid" \
			 "Column to left of data"] {
# TRANSLATOR: do the above strings
    lappend table_entry(irow_txts) [tr. $comboboxEng]
    lappend table_entry(irow_keys) [NameToTag $comboboxEng]
}
foreach comboboxEng [list "Position in data area" \
			 "First row in grid" \
			 "Row above data"] {
# TRANSLATOR: do the above strings
    lappend table_entry(icol_txts) [tr. $comboboxEng]
    lappend table_entry(icol_keys) [NameToTag $comboboxEng]
}
foreach comboboxEng [list "Use luminosity" "Use red level" "Use green level" \
			 "Use blue level" "Use 8-bit colourmap"] {
# TRANSLATOR: do the above strings
    lappend table_entry(oth_txts) [tr. $comboboxEng]
    lappend table_entry(oth_keys) [NameToTag $comboboxEng]
}

foreach comboboxEng [list "Use last" "Use closest" "Interpolate"] {
# TRANSLATOR: do the above strings
    lappend table_entry(between_txts) [tr. $comboboxEng]
    lappend table_entry(between_keys) [NameToTag $comboboxEng]
}

# array dims are now passed to this -- for now we only use them to scale the
# data in a gdal file but we could use them to get the table helper to display
# a table with the right dims in other cases!
proc EditTableData {startLine capt dims} {
    global table_entry
    AcquireTableData 0 $startLine
    upvar 0 table_entry(values) values
    if {[llength $values]} {
        if {[string equal ,gdal [lindex $values 1]]} {
            set oldValues $values
            set values [NumberElements [ReadGdalRefToList $values \
                    [lindex $dims 0] [lindex $dims 1]]]
        }
        if {[EditListAsTable .table $capt $startLine values]} {
            set table_entry(source) 1
        } elseif {[info exists oldValues]} {
            set values $oldValues
        }
    }
}

proc DoneTableData {startLine} {
    global table_entry
    if {([info exists table_entry(wrapPt)] && \
	     ![string equal $table_entry(wrapPt) $table_entry(oldWrapPt)] || \
	     [info exists table_entry(others)] && \
	     ![string equal $table_entry(others) $table_entry(oldOthers)] || \
	     [info exists table_entry(uftsi)] && \
	     ![string equal $table_entry(uftsi) $table_entry(oldUftsi)]) && \
	     $table_entry(source)<=0} {
        set table_entry(source) 0.5
    }
    AcquireTableData $table_entry(source) $startLine
    if {[winfo exists .table.commentt]} {
	set table_entry(comment) \
	    [string trimright [.table.commentt get 1.0 end]]
    }
    set table_entry(done) $table_entry(source)
}

proc ClearTableData {} {
    global table_entry

    set table_entry(fileName) {}
    set table_entry(dataField) {}
    set table_entry(values) {}

    set table_entry(source) 0
}

proc AcquireTableData {redo startLine} {
    global table_entry
    
    switch [set pane [.table.notebook select]] {
        .table.notebook.columns {
            if {![llength $table_entry(dataField)]} {
                return
            }
            set lidx [GetFrame $pane.select.idxs].lidx
	    if {[llength [package provide tkdnd]]} {
		set idcs [$lidx get 0 end]
	    } else {
		set idcs {}
		foreach itm [$lidx items] {
		    lappend idcs [$lidx itemcget $itm -text]
		    
		}
	    }
            set table_entry(indices) $idcs
            # jmm need to add table_entry(dbtable) to the tableSpec for ODBC sources with tables
            # BUT indices may be empty and so, effectively no list item
            # handle as table_entry(others) and table_entry(indices) inserted
            set tableSpec [concat [list $table_entry(fileName) \
                    $table_entry(dataField)] $table_entry(indices)]
            if {[info exists table_entry(uftsi)] && \
		    [llength $table_entry(uftsi)] && \
		    ![string equal unit $table_entry(uftsi)]} {
                set tableSpec [linsert $tableSpec 2 \
                        ,interval:$table_entry(uftsi)]
            }
            if {[info exists table_entry(others)] && \
                        [llength $table_entry(others)]} {
                set tableSpec [linsert $tableSpec 2 \
                        ,others:[NameToTag $table_entry(others)]]
            }
            if {[info exists table_entry(wrapPt)] && \
                        [Numeric $table_entry(wrapPt)]} {
                set tableSpec [linsert $tableSpec 2 ,wrap:$table_entry(wrapPt)]
            }
# JAT: If there is a dbtable it must be item 2 so insert it last
            if {[info exists table_entry(dbtable)] && \
                        [llength $table_entry(dbtable)]} {
                set tableSpec [linsert $tableSpec 2 \
                        ,dbtable:$table_entry(dbtable)]
            }
        } .table.notebook.grid {
            set tableSpec \
		[list $table_entry(fileName) ,grid \
		     $table_entry(row1) $table_entry(rown) \
		     $table_entry(col1) $table_entry(coln) $table_entry(xpose) \
		     [lindex $table_entry(irow_keys) \
			  [lsearch $table_entry(irow_txts) \
			       $table_entry(irow)]] \
		     [lindex $table_entry(icol_keys) \
			  [lsearch $table_entry(icol_txts) \
			       $table_entry(icol)]]]
        } .table.notebook.image {
            set tableSpec [list $table_entry(fileName) ,image \
			       $table_entry(row1) $table_entry(rown) \
			       $table_entry(col1) $table_entry(coln) \
			       $table_entry(blkval) $table_entry(whtval) \
			       $table_entry(trnval) \
			       [lindex $table_entry(oth_keys) \
				    [lsearch $table_entry(oth_txts) \
					 $table_entry(othval)]] \
			       $table_entry(xpose)]
        } .table.notebook.gdal {
            set tableSpec [list $table_entry(fileName) ,gdal \
                    $table_entry(row1) $table_entry(rown) \
                    $table_entry(col1) $table_entry(coln) $table_entry(xpose)]
        }
    }
    if {$redo || ![string equal $tableSpec $table_entry(data)]} {
        #do_in_editor puts "Loading with $tableSpec not $table_entry(data)"
        set table_entry(values) [LoadTableData $tableSpec $startLine 0]
        set table_entry(source) 2
        set table_entry(data) $tableSpec
    }
}

proc EditListAsTable {parent caption startLine valueArray} {
    global table_viewer
    PutItThere .table_edit $parent
    set t .table_edit.helperzone
    set b .table_edit.buttonzone
    wm title .table_edit "Table Editor"
    wm protocol .table_edit WM_DELETE_WINDOW {set table_viewer(done) 0}
    
    pack [frame $b] -side bottom
    # button frame packed first so it is not squeeeezed if window dragged smaller
    pack [frame $t] -fill x -expand true
    pack [button $b.ok -text [tr. OK] \
            -command "set table_viewer(done) 1" -width 10] -padx 2 -pady 2 -side left
    pack [button $b.cancel -text [tr. Cancel] \
            -command "set table_viewer(done) 0" -width 10] -padx 2 -pady 2 -side left
    
    set viewerId $::helperTable(TableViewer)
    set ::${viewerId}::editMode($t) $parent
    ${viewerId}::initialize $t
    
    upvar 1 $valueArray values
    set ${viewerId}::displayList($t) eqn_table
    set ${viewerId}::displayList($t,paths) [list $caption]
    if {$startLine} {
	set ${viewerId}::dataStore($t,0,0.0) $values
	set ${viewerId}::orientList($t) {none cols rows cols}
    } else {
	foreach {idx val} $values {
	    set ${viewerId}::dataStore($t,0,$idx) $val
	}
	set ${viewerId}::orientList($t) {rows cols cols cols}
    }
    set ${viewerId}::displayFormat($t,0) {General 4 0}
    ${viewerId}::Reconbobulate $t
    
    focus .table_edit
    LetItShow .table_edit
    grab .table_edit
    tkwait variable table_viewer(done)
#    ${viewerId}::EditCellIs $t.t 0 0 ;# get final edit
    grab release .table_edit
    if {![set ${viewerId}::editMode($t,tweaked)]} {
        set table_viewer(done) 0 ;# treat OK as Cancel if no change
    }
    PackItUp .table_edit
    # extract step at end so window still gone if it fails
    if {$table_viewer(done)} {
        set values [${viewerId}::ExtractEdits $t]
    }
    grab $parent
    return $table_viewer(done)
}

proc LoadDataFile {mode query mdl} {
    global table_entry
    #ShowMess debug info "LoadDataFile $mode $query $mdl" ok
    #    wm title .table "Create table from file $table_entry(fileName)"

    set haveDND [llength [package provide tkdnd]]
    set fc .table.notebook.columns
    set fheads [GetFrame $fc.fheads]
    set ftable [GetFrame $fc.ftable]
    if {$haveDND} {
	$fheads.lheads delete 0 end
    } else {
	$fheads.lheads delete [$fheads.lheads items]
    }
    $ftable.tablecb configure -values {}
    set tablecb $ftable.tablecb
    $tablecb set {}
    
    if {[string equal image $mode]} {
        set type .gif
    } elseif {[string equal gdal $mode]} {
        set type .tif
    } else {
        set type .csv
    }
    
    # can use file extnsn to set datasourc type for file DB
    # dbf
    # set driver {Microsoft dBase Driver *.dbf)}
    # xls
    
    if {$query} {
        set info [format [tr. {Select new %1$s file}] $mode]
        if {![llength [set table_entry(fileName) \
                    [ChooseFile data$type $info 0 $mdl]]]} {
            return 0
        }
    }
    
    # mode columns read non-csv files using ODBC
    set ext [file extension $table_entry(fileName)]
    
    #ShowMess debug info "LoadDataFile mode $mode data$type $table_entry(fileName) \
    #$ext" ok ; # jmm
    
    while {[catch {open $table_entry(fileName) r} stream]} {
        set info [format [tr. {Cannot read %1$s file "%2$s"}] \
		      $mode $table_entry(fileName)]
        if {![llength [set table_entry(fileName) \
                    [ChooseFile data$type $info 0 $mdl]]]} {
            return 0
        }
    }
    [GetFrame .table.notebook.$mode.fdata].dfile xview moveto 1
    
    if {[string equal gdal $mode]} {
        close $stream
        package require gdal
        set hdl [gdal_open_read_only $table_entry(fileName)]
        set table_entry(col1) 1
        set table_entry(coln) [gdal_get_x_size $hdl]
        set table_entry(row1) 1
        set table_entry(rown) [gdal_get_y_size $hdl]
        gdal_close $hdl
    } else {
        gets $stream firstLine
        switch $mode {
            columns {
                # csv handled by existing code other extensions handled with ODBC
                if {$ext == {.csv}} {
                        set i 1
                        foreach hd [split $firstLine ,] {
                            if {$haveDND} {
				$fheads.lheads insert end [string trim $hd]
			    } else {
				$fheads.lheads insert end hd$i -text [string trim $hd]
			    }
                            incr i
                        }
                    } else {
                        #ODBC get database tables and find headers for selected table
                        close $stream
                        
                        #set driver "Microsoft Excel Driver (*.xls)"
                        if {![llength [set driver [odbcdriverFromExt $ext]]]} {
			    return 0
			}
                        set dbfile $table_entry(fileName)
                        set connectString "DRIVER=$driver;DBQ=$dbfile"
                        #ShowMess debug info $connectString ok
                        database db $connectString
                        #ShowMess debug info "tables [db tables]" ok
                        set dbtables [db tables]
                        set tablenames {}
                        foreach table $dbtables {
                            lappend tablenames [lindex $table 2]
                        }
                        # set to the first sheet
                        set fc .table.notebook.columns
                         $tablecb set [lindex $tablenames 0]
                        $tablecb configure -values $tablenames
                        #ShowMess debug info "DoOnDataBaseColumnsLoaded $connectString $tablecb $fheads" ok
                        DoOnDataBaseColumnsLoaded $connectString $tablecb $fheads
                        bind $tablecb <<ComboboxSelected>> "DoOnDataBaseColumnsLoaded \{$connectString\} $tablecb $fheads"
                    }
                    # was a bracket
            } grid {
                set table_entry(col1) 1
                set table_entry(coln) [llength [split $firstLine ,]]
                set table_entry(row1) 1
                set table_entry(rown) 1
                while {[gets $stream firstLine]!=-1} {
		    set coln [llength [split $firstLine ,]]
		    if {$coln>$table_entry(coln)} {
			set table_entry(coln) $coln
		    }
                    incr table_entry(rown)
                }
            } image {
                catch {image delete tableImage}
                image create photo tableImage -file $table_entry(fileName)
                set table_entry(col1) 1
                set table_entry(coln) [image width tableImage]
                set table_entry(row1) 1
                set table_entry(rown) [image height tableImage]
            }
        }
        catch {close $stream}
        if {[info commands db] == {db}} {
            db disconnect
        }
        
    }
    set fidx [GetFrame $fc.select.idxs]; ######################
    if {$haveDND} {
	$fidx.lidx delete 0 end
    } else {
	$fidx.lidx delete [$fidx.lidx items]
    }
    return 1
}

proc DoOnDataBaseColumnsLoaded { connectString tablecb fheads } {
    set haveDND [llength [package provide tkdnd]]

    if {$haveDND} {
	$fheads.lheads delete 0 end
    } else {
	$fheads.lheads delete [$fheads.lheads items]
    }
    database db $connectString
    set fields [db columns [$tablecb get]]; #table name
    
    #each column {TABLE_QUALIFIER TABLE_OWNER TABLE_NAME COLUMN_NAME DATA_TYPE TYPE_NAME PRECISION LENGTH SCALE RADIX NULLABLE REMARKS}
    set i 1
    #ShowMess debug info "fields $fields" ok
    foreach field $fields {
        # just the column name
	if {$haveDND} {
	    $fheads.lheads insert end [lindex $field 3]
	} else {
	    $fheads.lheads insert end hd$i -text [lindex $field 3]
	}
        incr i
    }
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

proc LoadTableData {tableSpec lineCount addSpecials} {
    #ShowMess debug info "LoadTableData $tableSpec $lineCount $addSpecials" ok; # jmm remove
    # if its an ODBC database file  (database server later!)
    # need the connection string, if have file name with extension can work out driver
    # what about Linux and Mac - file extensions! - have csv files
    set filename [lindex $tableSpec 0]
    set ext [file extension $filename]
    #set mode [lindex $tableSpec 1]
    
    # end JMM ODBC

    foreach {keyWd tgtVar} \
	{dbtable dbtable wrap wrapPt others fillMtd interval tpiUnit} {
	    if {[regexp ,$keyWd:(.*) [lindex $tableSpec 2] match $tgtVar]} {
		set tableSpec [lreplace $tableSpec 2 2]
	    }
	}

    switch -exact [lindex $tableSpec 1] {
    ,grid {
        set rowList {}
        set colList {}
	set transpose [expr {[string equal 1 [lindex $tableSpec 6]]}]
	if {$transpose} {
	    set rowCount 1
	    set colCount $lineCount
	} else {
	    set rowCount $lineCount
	    set colCount 1
	}
	set rown 0
	set coln 0
	set stream [NetOpen [lindex $tableSpec 0] r]
	while {[gets $stream firstLine]!=-1} {
	    set acoln [llength [split $firstLine ,]]
	    if {$acoln>$coln} {
		set coln $acoln
	    }
	    incr rown
	}
	close $stream
	foreach {bd v} [eval SubEndRefs $rown $coln [lrange $tableSpec 2 5]] {
	    set $bd $v
	}

	switch [lindex $tableSpec 7] {
	    first_column_in_grid {
		set idxCol 1
	    } column_to_left_of_data {
		set idxCol [expr {$xfirst-1}]
	    } default {
		set idxCol -1
	    }
	}
	switch [lindex $tableSpec 8] {
	    first_row_in_grid {
		set idxRow 1
	    } row_above_data {
		set idxRow [expr {$yfirst-1}]
	    } default {
		set idxRow -1
	    }
	}
	if {$idxCol==$xfirst || $idxCol==0 || $idxRow==$yfirst || $idxRow==0} {
	    Query wayward_grid_index warning data_in_grid {} ok
	    return
	}

	set tStr [NetOpen [lindex $tableSpec 0] r]
        for {set rowInd 1} {$rowInd <= $ylast} {incr rowInd} {
            gets $tStr entryLine
	    if {$rowInd == $idxRow} {
		set xIndPts [TrimFields [split ,$entryLine ,]]
	    }
            if {$rowInd >= $yfirst} {
                set usePts [TrimFields [split ,$entryLine ,]]
		if {$idxCol>-1} {
		    set yInd [lindex $usePts $idxCol]
		} elseif {$yflip} {
		    set yInd [expr {$rowCount+$ylast-$rowInd}]
		} else {
		    set yInd [expr {$rowCount+$rowInd-$yfirst}]
		}
                lappend rowList $yInd
                for {set colInd $xfirst} {$colInd<=$xlast} {incr colInd} {
		    if {$idxRow>-1} {
			set xInd [lindex $xIndPts $colInd]
		    } elseif {$xflip} {
			set xInd [expr $colCount+$xlast-$colInd]
		    } else {
			set xInd [expr $colCount+$colInd-$xfirst]
		    }
		    if {$yInd==1} {
			lappend colList $xInd
		    }
		    set cell [lindex $usePts $colInd]
		    if {[string length $cell]} {
			if {$transpose} {
			    set paramArray([list top $xInd $yInd]) \
				[EnquoteIfNonNumeric $cell]
			} else {
			    set paramArray([list top $yInd $xInd]) \
				[EnquoteIfNonNumeric $cell]
			}
		    }
		}
            }
        }
        # set indexList [list $rowList $colList]
	close $tStr
    } ,image {
        set rowList {}
        set colList {}
	set transpose [expr {[string equal 1 [lindex $tableSpec 10]]}]
	set rown [image height tableImage]
	set coln [image width tableImage]
	foreach {bd v} [eval SubEndRefs $rown $coln [lrange $tableSpec 2 5]] {
	    set $bd $v
	}

        for {set rowInd [expr $yfirst-1]} {$rowInd<=$ylast-1} {incr rowInd} {
	    if {$yflip} {
		set yInd [expr $lineCount+$rowInd-$yfirst+1]
	    } else {
		set yInd [expr $lineCount+$ylast-$rowInd-1]
	    }
	    lappend rowList $yInd
	    for {set colInd [expr $xfirst-1]} {$colInd<$xlast} {incr colInd} {
		if {$xflip} {
		    set xInd [expr $xlast-$colInd]
		} else {
		    set xInd [expr 2+$colInd-$xfirst]
		}
		if {$transpose} {
		    set subscriptList [list top $xInd $yInd]
		} else {
		    set subscriptList [list top $yInd $xInd]
		}
		if {$yInd==1} {
		    lappend colList $xInd
		}
		if {[tableImage transparency get $colInd $rowInd]} {
		    if {![string length [lindex $tableSpec 8]]} {
			Query [list no_clear_val [lindex $tableSpec 0]]\
			    warning data_in_image {} ok
			return
		    }
		    set paramArray($subscriptList) [lindex $tableSpec 8]
		    continue
		}
		set ptColours [tableImage get $colInd $rowInd]
		switch [lindex $tableSpec 9] {
		    use_red_level {
			set fract [lindex $ptColours 0]
		    } use_green_level {
			set fract [lindex $ptColours 1]
		    } use_blue_level {
			set fract [lindex $ptColours 2]
		    } use_luminosity {
			set fract [expr ([lindex $ptColours 0]+\
					     [lindex $ptColours 1]+\
					     [lindex $ptColours 2])/3]
		    } use_8-bit_colourmap {
			set fract [expr 35*[lindex $ptColours 0]*7/256+5*[lindex $ptColours 1]*7/256+[lindex $ptColours 2]*5/256]
		    } default {
			error "Unrecognized conversion [lindex $tableSpec 9]"
		    }
		}
		set level [expr {[lindex $tableSpec 6]+$fract*([lindex $tableSpec 7]-[lindex $tableSpec 6])/255.0}]
		set paramArray($subscriptList) $level
	    }
	}
        # set indexList [list $rowList $colList]
    } ,gdal {
        #	set indexList [ReadGdalRefToArray paramArray $tableSpec]
        return $tableSpec
    } default {
# tableSpec should be:
# fileName dataHeader ?dbtableId? ?wrapTime? ?fillMethod? ?tpiUnits? indHeaders...
        # csv handled by existing code other extensions handled with ODBC
        #ShowMess debug info "Loading table with data $tableSpec; ext $ext" ok
        if { $ext == {.csv} } {
	    set tStr [NetOpen [lindex $tableSpec 0] r]
	    gets $tStr headerLine
	    set headerList [TrimFields [split $headerLine ,]]
	    #ShowMess debug info "Headers are $headerList" ok
	    
	    foreach headerIndex [lrange $tableSpec 2 end] {
		set indexColumn  [lsearch -exact $headerList $headerIndex]
		if {$indexColumn==-1} {
		    Query [concat no_info_col index [lrange $tableSpec 0 0] \
			       [list $headerIndex $headerList]] warning \
			data_in_cols {} ok
		return
	    }
		lappend indexColumns $indexColumn
	    }
	    set headerColumn [lsearch -exact $headerList [lindex $tableSpec 1]]
	    #ShowMess debug info "Columns: header $headerColumn indxs $indexColumns" ok
	    if {$headerColumn==-1} {
		Query [concat no_info_col data [lrange $tableSpec 0 1] \
			   [list $headerList]] warning data_in_cols {} ok
		close $tStr
		return
	    }
	    while {[gets $tStr entryLine] != -1} {
		set entryList [TrimFields [split $entryLine ,]]
		#ShowMess debug info "Data line is $entryList" ok
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
			    lappend arrayIndex [Sink $newIndex]
			    incr indexCount
			} else {
			    # if there is an empty index field ignore the line
			    set badIndex 1
			    break
			}
		    }                       
		} else {
		    set arrayIndex $lineCount
		    incr lineCount
		}
		
		# ignore empty entries
		if {[info exists badIndex]} {
		    unset badIndex
		} else {
		    set potEntry [lindex $entryList $headerColumn]
		    if {[llength $potEntry]} {
			set paramArray([concat [list top] $arrayIndex]) \
			    [EnquoteIfNonNumeric $potEntry]
		    }
		}
	    }
	    close $tStr
	} else { ;# data is from a tclodbc-connected database
	    #set driver "Microsoft Excel Driver (*.xls)"
	    if {![llength [set driver [odbcdriverFromExt $ext]]]} {
		return
	    }
	    set connectString "DRIVER=$driver;DBQ=$filename"
	    #ShowMess debug info $connectString ok
	    database db $connectString

	    set field [lindex $tableSpec 1]
	    #ShowMess debug info "$connectString dbtable $dbtable field $field"  ok
	    set datalist [db "select `$field` from `$dbtable`"]
	    set indexArgs {}
	    foreach headerIndex [lrange $tableSpec 2 end] {
		lappend indexArgs ${headerIndex}elt \
		    [db "select `$headerIndex` from `$dbtable`"]
	    }
	    eval [list foreach datum $datalist] $indexArgs [list {
		set arrayIndex {}
		if {[llength $indexArgs]} {
		    foreach {item list} $indexArgs {
			lappend arrayIndex [Sink [set $item]]
		    }
		} else {
		    set arrayIndex $lineCount
		}
		set paramArray([concat [list top] $arrayIndex]) \
		    [EnquoteIfNonNumeric $datum]
		incr lineCount
	    }]
	    #ShowMess debug info "datalist $datalist" ok
	    # todo add error messages!!!
	    # make sure have some data
	}
    }}
    
    #ShowMess debug info "Converting [array get paramArray]" ok
    if {![info exists paramArray]} {
	Query area_misses_data warning data_in_grid {} ok
	return
    }
    set result [ArrayToList paramArray]
    if {$addSpecials} {
        if {[info exists tpiUnit]} {
            lappend result interval $tpiUnit
        }
        if {[info exists fillMtd]} {
            lappend result others $fillMtd
        }
        if {[info exists wrapPt]} {
            lappend result $wrapPt restart
        }
    }
    #ShowMess debug info "result $result" ok
    return $result
}

proc SubEndRefs {rown coln rfirst rlast cfirst clast} {
    set rfirst [expr [string map [list end $rown] $rfirst]]
    set rlast [expr [string map [list end $rown] $rlast]]
    set cfirst [expr [string map [list end $coln] $cfirst]]
    set clast [expr [string map [list end $coln] $clast]]

    set yflip [expr {$rfirst>$rlast}]
    set xflip [expr {$cfirst>$clast}]
    if {$yflip} {
	set yfirst $rlast
	set ylast $rfirst
    } else {
	set yfirst $rfirst
	set ylast $rlast
    }
    if {$xflip} {
	set xfirst $clast
	set xlast $cfirst
    } else {
	set xfirst $cfirst
	set xlast $clast
    }
    return [list xfirst $xfirst xlast $xlast yfirst $yfirst ylast $ylast \
		xflip $xflip yflip $yflip]
}

proc TrimFields {dataLine} {
    set entryList {}
    foreach entry $dataLine {
        lappend entryList [string trim $entry]
    }
    return $entryList
}

proc EnquoteIfNonNumeric {item} {
# ...and not already enquoted...
    if {[Numeric $item] || ![string first \" $item]} {
        return $item
    } else {
        return \"[string trim $item]\"
    }
}

proc Sink {val} {
# stop it being a float if it equals an integer
    if {[string is double -strict $val] && floor($val)==ceil($val)} {
	return [expr {round($val)}]
    } else {
	return $val
    }
}
  
proc ArrayToList {topArray} {
    #ShowMess debug info "ArrayToList $topArray" ok
    # Now copy array values into lists with one less index
    # Any with fewer indices than rest will get ignoredddd
    upvar 1 $topArray values
    while {![info exists values()]} {
        set vlist [ArrayGetSorted values]
        unset values
        foreach {indcol val} $vlist {
            set shortcol [lrange $indcol 0 end-1]
            lappend values($shortcol) \
                    [lindex $indcol end] $val
        }
    }
    return [lindex $values() 1]
}

proc ArrayGetSorted {arrayPtr} {
    set result {}
    upvar 1 $arrayPtr arrayName
    set nameList [array names arrayName ?*]
    # puts "About to sort $nameList"
    if {[string is double -strict [lindex [lindex $nameList 0] end]]} {
        set order real
    } else {
        set order ascii ;# index is enumerated type
    }
    foreach name [lsort -$order -index end $nameList] {
        lappend result $name $arrayName($name)
    }
    return $result
}

