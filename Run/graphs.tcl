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

package require BWidget

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
    
    catch {wm title $t "Sketch graph"}
    
    TitleFrame $t.gph -text "Graph pad"
    set gph [GetFrame $t.gph]
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
    set current [GetFrame $t.right.current]
    
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
    set right [GetFrame $t.right.options]
    
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
proc equationDoTable {parent mdl tgt dims startLine} {
    global table_entry iconImages tcl_platform
    
    PutItThere .table $parent
    wm title .table "Table data for [BlankCrs "$tgt $dims"]"
    wm protocol .table WM_DELETE_WINDOW {set table_entry(done) 0}
    set table_entry(source) 0
    
    set t [::ttk::notebook .table.notebook]
    $t add [set fc [frame $t.columns]] -text "Data in column"
    # Data file and data column heading
    label $fc.instructions -wrap 400 -text "Choose a data file, select a worksheet if mecessary, then create table from file by dragging \
            column headings to act either as indices or as data."
    pack $fc.instructions -side top -anchor w -padx 2 -pady 2
    TitleFrame $fc.fdata -text "Data file "
    set fdata [GetFrame $fc.fdata]
    set dfile [Entry $fdata.dfile -textvariable table_entry(fileName)]
    bind $dfile <Return> "LoadDataFile columns 0 $mdl"
    bind $dfile <Double-1> "LoadDataFile columns 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text Browse \
            -command "LoadDataFile columns 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $fc.fdata -fill x
    # new frame December 2008 for the choice of data table in a database JMM
    TitleFrame $fc.ftable -text "Database table or worksheet "
    set ftable [GetFrame $fc.ftable]
    pack $ftable -side top -expand true -fill x
    pack $fc.ftable
    # dropdown combobox for table names
    set tablecb [ttk::combobox $ftable.tablecb -state readonly  -width 50 -textvariable table_entry(dbtable)]
    pack $tablecb -side left
    # end new frame December 2008 for the choice of data table in a database JMM
    TitleFrame $fc.fheads -text "Table column headings"
    set fheads [GetFrame $fc.fheads]
    set lheads [ListBox $fheads.lheads -dragenabled true -dropenabled true \
            -selectmode single -dropcmd DeleteIndex \
            -yscrollcommand [list AdjustCanvas $fheads lheads y]]
    scrollbar $fheads.yscroll -orient v -command [list $fheads.lheads yview]
    pack $fheads.yscroll -side right -fill y
    
    frame $fc.select
    TitleFrame $fc.select.idxs -text "Use as indices"
    set fidx [GetFrame $fc.select.idxs]
    set lidx [ListBox $fidx.lidx -dragenabled true -dropenabled true \
            -selectmode single \
            -dropcmd AddIndex]
    pack $lheads  -expand true -fill both
    pack $fc.fheads -side left -expand true -fill both -anchor w -padx 2 -pady 2
    pack $lidx -expand true -fill both -anchor w
    pack $fc.select.idxs -expand true -fill both -anchor w \
            -padx 2 -pady 2
    
    TitleFrame $fc.select.data -text "Use as data"
    set didx [GetFrame $fc.select.data]
    set dhead [Entry $didx.dhead \
            -textvariable table_entry(dataField) \
            -dropenabled true -droptypes LISTBOX_ITEM \
            -dropcmd ChooseDataHeader]
    bind $lheads <Double-1> [list PutInDataField $lheads $dhead]
    pack $dhead -side top -expand true -fill x
    pack $fc.select.data -expand true -fill x -anchor w \
            -padx 2 -pady 2
    pack $fc.select -side left -expand true -fill both
    
    $t add [set fg [frame $t.grid]] -text "Data in grid"
    label $fg.instructions -wrap 400 -text "Choose a data file, then select row and column at which to start and finish loading data."
    pack $fg.instructions -side top -anchor w -padx 2 -pady 2
    TitleFrame $fg.fdata -text "Data file "
    set fdata [GetFrame $fg.fdata]
    set dfile [Entry $fdata.dfile -textvariable table_entry(fileName)]
    bind $dfile <Return> "LoadDataFile grid 0 $mdl"
    bind $dfile <Double-1> "LoadDataFile grid 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text Browse \
            -command "LoadDataFile grid 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $fg.fdata -fill x
    TitleFrame $fg.limits -text "Boundaries of area to load "
    set flim [GetFrame $fg.limits]
    pack [ttk::checkbutton $flim.transpose -variable table_entry(xpose) \
	      -text "Transpose (so columns are outer dimension)"] -side bottom
    pack [frame $flim.ycapt] -side left -fill both -expand true
    pack [frame $flim.yval] -side left -fill both -expand true
    pack [frame $flim.xcapt] -side left -fill both -expand true
    pack [frame $flim.xval] -side left -fill both -expand true
    
    pack [label $flim.ycapt.lo -text "Start at row:"] \
            -expand true -fill x
    pack [label $flim.ycapt.hi -text "Finish at row:"] \
            -expand true -fill x
    pack [label $flim.xcapt.lo -text "Start at column:"] \
            -expand true -fill x
    pack [label $flim.xcapt.hi -text "Finish at column:"] \
            -expand true -fill x
    
    pack [Entry $flim.yval.lo -textvariable table_entry(row1)] \
            -expand true -fill x
    pack [Entry $flim.yval.hi -textvariable table_entry(rown)] \
            -expand true -fill x
    pack [Entry $flim.xval.lo -textvariable table_entry(col1)] \
            -expand true -fill x
    pack [Entry $flim.xval.hi -textvariable table_entry(coln)] \
            -expand true -fill x
    pack $fg.limits -fill both -expand true
    
    $t add [set fi [frame $t.image]] -text "Data from image"
    label $fi.instructions -wrap 400 -text "Choose an image file, then select row and column at which to start and finish loading data, and method for interpreting colours."
    pack $fi.instructions -side top -anchor w -padx 2 -pady 2
    TitleFrame $fi.fdata -text "Image file "
    set fdata [GetFrame $fi.fdata]
    set dfile [Entry $fdata.dfile -textvariable table_entry(fileName)]
    bind $dfile <Return> "LoadDataFile image 0 $mdl"
    bind $dfile <Double-1> "LoadDataFile image 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text Browse \
            -command "LoadDataFile image 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $fi.fdata -fill x
    TitleFrame $fi.limits -text "Boundaries of area to load "
    set flim [GetFrame $fi.limits]
    pack [ttk::checkbutton $flim.transpose -variable table_entry(xpose) \
	      -text "Transpose (so X positions are outer dimension)"] \
	-side bottom
    pack [frame $flim.ycapt] -side left -fill both -expand true
    pack [frame $flim.yval] -side left -fill both -expand true
    pack [frame $flim.xcapt] -side left -fill both -expand true
    pack [frame $flim.xval] -side left -fill both -expand true
    
    pack [label $flim.ycapt.lo -text "Start at Y position:"] \
            -expand true -fill x
    pack [label $flim.ycapt.hi -text "Finish at Y position:"] \
            -expand true -fill x
    pack [label $flim.xcapt.lo -text "Start at X position:"] \
            -expand true -fill x
    pack [label $flim.xcapt.hi -text "Finish at X position:"] \
            -expand true -fill x
    
    pack [Entry $flim.yval.lo -textvariable table_entry(row1)] \
            -expand true -fill x
    pack [Entry $flim.yval.hi -textvariable table_entry(rown)] \
            -expand true -fill x
    pack [Entry $flim.xval.lo -textvariable table_entry(col1)] \
            -expand true -fill x
    pack [Entry $flim.xval.hi -textvariable table_entry(coln)] \
            -expand true -fill x
    pack $fi.limits -fill both -expand true
    
    TitleFrame $fi.interp -text "Values for colours: "
    set fterp [GetFrame $fi.interp]
    set fbounds [frame $fterp.bounds]
    pack [label $fbounds.bklabel -text "Value for black:"] \
            -side left -expand true -fill x
    pack [Entry $fbounds.bkentry -textvariable table_entry(blkval)] \
            -side left -expand true -fill x
    pack [label $fbounds.wtlabel -text "Value for white:"] \
            -side left -expand true -fill x
    pack [Entry $fbounds.wtentry -textvariable table_entry(whtval)] \
            -side left -expand true -fill x
    pack $fbounds
    
    set fcols [frame $fterp.cols]
    pack [label $fcols.trlabel -text "Value for clear:"] \
            -side left -expand true -fill x
    pack [Entry $fcols.trentry -textvariable table_entry(trnval)] \
            -side left -expand true -fill x
    pack [label $fcols.clabel -text "For other colours:"] \
            -side left -expand true -fill x
    pack [::ttk::combobox $fcols.c -textvariable table_entry(othval) \
            -values {"Use luminosity" "Use red level" "Use green level" \
                "Use blue level" "Use 8-bit colourmap"} \
            -width 16 -state readonly]
    set table_entry(othval) "Use luminosity"
    pack $fcols
    pack $fi.interp -fill both -expand true
    
    $t add [set ft [frame $t.gdal]] -text "Data from GeoTIFF etc."
    label $ft.instructions -wrap 400 -text "Choose a georeferenced data file, then select row and column at which to start and finish loading data."
    pack $ft.instructions -side top -anchor w -padx 2 -pady 2
    TitleFrame $ft.fdata -text "Data file "
    set fdata [GetFrame $ft.fdata]
    set dfile [Entry $fdata.dfile -textvariable table_entry(fileName)]
    bind $dfile <Return> "LoadDataFile gdal 0 $mdl"
    bind $dfile <Double-1> "LoadDataFile gdal 0 $mdl"
    pack $dfile -side left -expand true -fill x
    button $fdata.new -compound left -image $iconImages(open) -text Browse \
            -command "LoadDataFile gdal 1 $mdl"
    pack $fdata.new -side bottom -padx 4 -pady 4
    pack $fdata -fill x
    pack $ft.fdata -fill x
    TitleFrame $ft.limits -text "Boundaries of area to load "
    set flim [GetFrame $ft.limits]
    pack [ttk::checkbutton $flim.transpose -variable table_entry(xpose) \
	      -text "Transpose (so columns are outer dimension)" \
	      -state disabled] -side bottom ;# not working yet
    pack [frame $flim.ycapt] -side left -fill both -expand true
    pack [frame $flim.yval] -side left -fill both -expand true
    pack [frame $flim.xcapt] -side left -fill both -expand true
    pack [frame $flim.xval] -side left -fill both -expand true
    
    pack [label $flim.ycapt.lo -text "Start at row:"] \
            -expand true -fill x
    pack [label $flim.ycapt.hi -text "Finish at row:"] \
            -expand true -fill x
    pack [label $flim.xcapt.lo -text "Start at column:"] \
            -expand true -fill x
    pack [label $flim.xcapt.hi -text "Finish at column:"] \
            -expand true -fill x
    
    pack [Entry $flim.yval.lo -textvariable table_entry(row1)] \
            -expand true -fill x
    pack [Entry $flim.yval.hi -textvariable table_entry(rown)] \
            -expand true -fill x
    pack [Entry $flim.xval.lo -textvariable table_entry(col1)] \
            -expand true -fill x
    pack [Entry $flim.xval.hi -textvariable table_entry(coln)] \
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
    } elseif {![info exists dimsFromData]} {
        if {[llength $arrayDims]!=2} {
            $t tab $t.grid -state disabled
            $t tab $t.image -state disabled
            $t tab $t.gdal -state disabled
        }
    }
    
    #
    # OK, Cancel and Help buttons
    frame .table.fbuttons
    if {!$startLine} {
        pack [TitleFrame .table.fbuttons.wrapf -text "Other times: "] \
                -padx 4 -pady 4 -expand true -fill x
        set wrapf [GetFrame .table.fbuttons.wrapf]
        pack [label $wrapf.bm -text "Between points:"]
        pack [::ttk::combobox $wrapf.bc -textvariable table_entry(others) \
                -width 10 -values {"Use last" "Use closest" Interpolate} \
                -state readonly]
        pack [label $wrapf.wm -text "Wraparound at:"]
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
    if {[string equal .fpdialogue $parent]} {
        pack [checkbutton .table.fbuttons.keepvals -var table_entry(bytes) \
                -text "Include values\nin scenario files" \
                -command "set table_entry(source) 1"] -padx 4 -pady 4
    }
    
    button .table.fbuttons.load -text Reload -width 10 \
            -command [list AcquireTableData 1 $startLine]
    button .table.fbuttons.edit -text View/Edit -width 10 \
            -command [list EditTableData $startLine $arrayDims]
    button .table.fbuttons.ok -text OK -width 10 \
            -command [list DoneTableData $startLine]
    button .table.fbuttons.cancel -text Cancel -width 10 \
            -command "set table_entry(done) 0"
    button .table.fbuttons.help -text Help -width 10 \
            -command {ContextSensitiveHelp .table equations/table.htm}
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
                        [TagToName [lindex $table_entry(data) 9]]
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
                        $lidx insert end id$i -text $idx
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
    if {[info exists table_entry(others)] && [llength $table_entry(others)] && \
                ![string equal others [lindex $table_entry(values) end-1]]} {
        lappend table_entry(values) others [NameToTag $table_entry(others)]
    }
    if {[info exists table_entry(wrapPt)] && [Numeric $table_entry(wrapPt)] && \
                ![string equal restart [lindex $table_entry(values) end]]} {
        lappend table_entry(values) $table_entry(wrapPt) restart
    }
    return $table_entry(done)
}

proc PutInDataField {source dest} {
    $dest delete 0 end
    $dest insert 0 [$source itemcget [$source selection get] -text]
}

proc TagToName {tag} {
    string totitle [string map {_ { }} $tag]
}

proc NameToTag {name} {
    string map {{ } _} [string tolower $name]
}

# array dims are now passed to this -- for now we only use them to scale the
# data in a gdal file but we could use them to get the table helper to display
# a table with the right dims in other cases!
proc EditTableData {startLine dims} {
    global table_entry
    AcquireTableData 0 $startLine
    upvar 0 table_entry(values) values
    if {[llength $values]} {
        if {[string equal ,gdal [lindex $values 1]]} {
            set oldValues $values
            set values [NumberElements [ReadGdalRefToList $values \
                    [lindex $dims 0] [lindex $dims 1]]]
        }
        if {[EditListAsTable .table values]} {
            set table_entry(source) 1
        } elseif {[info exists oldValues]} {
            set values $oldValues
        }
    }
}

proc DoneTableData {startLine} {
    global table_entry
    AcquireTableData 0 $startLine
    if {([info exists table_entry(wrapPt)] && \
                ![string equal $table_entry(wrapPt) $table_entry(oldWrapPt)] || \
                [info exists table_entry(others)] && \
                ![string equal $table_entry(others) $table_entry(oldOthers)]) && \
                !$table_entry(source)} {
        set table_entry(source) 0.5
    }
    set table_entry(done) $table_entry(source)
}

proc AcquireTableData {redo startLine} {
    global table_entry
    
    switch [set pane [.table.notebook select]] {
        .table.notebook.columns {
            if {![llength $table_entry(dataField)]} {
                return
            }
            set lidx [GetFrame $pane.select.idxs].lidx
            set idcs {}
            foreach itm [$lidx items] {
                lappend idcs [$lidx itemcget $itm -text]
            }
            set table_entry(indices) $idcs
            # jmm need to add table_entry(dbtable) to the tableSpec for ODBC sources with tables
            # BUT indices may be empty and so, effectively no list item
            # handle as table_entry(others) and table_entry(indices) inserted
            set tableSpec [concat [list $table_entry(fileName) \
                    $table_entry(dataField)] $table_entry(indices)]
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
            set tableSpec [list $table_entry(fileName) ,grid \
                    $table_entry(row1) $table_entry(rown) \
                    $table_entry(col1) $table_entry(coln) $table_entry(xpose)]
        } .table.notebook.image {
            set tableSpec [list $table_entry(fileName) ,image \
                    $table_entry(row1) $table_entry(rown) \
                    $table_entry(col1) $table_entry(coln) \
                    $table_entry(blkval) $table_entry(whtval) \
                    $table_entry(trnval) \
                    [NameToTag $table_entry(othval)] $table_entry(xpose)]
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
    
    set viewerId $::helperTable(TableViewer)
    set ::${viewerId}::editMode($t) $parent
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
    ${viewerId}::EditCellIs $t.t 0 0 ;# get final edit
    grab release .table_edit
    if {![set ${viewerId}::editMode($t,tweaked)]} {
        set table_viewer(done) 0 ;# treat OK as Cancel if no change
    }
    PackItUp .table_edit
    # extract step at end so window still gone if it fails
    if {$table_viewer(done)} {
        set values [${viewerId}::ExtractEdits $t]
    }
    return $table_viewer(done)
}

proc LoadDataFile {mode query mdl} {
    global table_entry
    #ShowMess debug info "LoadDataFile $mode $query $mdl" ok
    #    wm title .table "Create table from file $table_entry(fileName)"
    set fc .table.notebook.columns
    set fheads [GetFrame $fc.fheads]
    set ftable [GetFrame $fc.ftable]
    $fheads.lheads delete [$fheads.lheads items]
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
        set info "Select new $mode file"
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
        set info "Cannot read $mode file $table_entry(fileName)"
        if {![llength [set table_entry(fileName) \
                    [ChooseFile data$type $info 0 $mdl]]]} {
            return 0
        }
    }
    
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
                            $fheads.lheads insert end hd$i -text [string trim $hd]
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
    $fidx.lidx delete [$fidx.lidx items]
    return 1
}

proc DoOnDataBaseColumnsLoaded { connectString tablecb fheads } {
    $fheads.lheads delete [$fheads.lheads items]
    
    database db $connectString
    set fields [db columns [$tablecb get]]; #table name
    
    #each column {TABLE_QUALIFIER TABLE_OWNER TABLE_NAME COLUMN_NAME DATA_TYPE TYPE_NAME PRECISION LENGTH SCALE RADIX NULLABLE REMARKS}
    set i 1
    #ShowMess debug info "fields $fields" ok
    foreach field $fields {
        # just the column name
        $fheads.lheads insert end hd$i -text [lindex $field 3]
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
    set tStr [NetOpen [lindex $tableSpec 0] r]
    if {[string equal ,grid [lindex $tableSpec 1]]} {
        set rowList {}
        set colList {}
	set transpose [expr {[string equal 1 [lindex $tableSpec 6]]}]
	set yflip [expr {[lindex $tableSpec 2]>[lindex $tableSpec 3]}]
	set xflip [expr {[lindex $tableSpec 4]>[lindex $tableSpec 5]}]
	if {$yflip} {
	    set yfirst [lindex $tableSpec 3]
	    set ylast [lindex $tableSpec 2]
	} else {
	    set yfirst [lindex $tableSpec 2]
	    set ylast [lindex $tableSpec 3]
	}
	if {$xflip} {
	    set xfirst [lindex $tableSpec 5]
	    set xlast [lindex $tableSpec 4]
	} else {
	    set xfirst [lindex $tableSpec 4]
	    set xlast [lindex $tableSpec 5]
	}
        for {set rowInd 1} {$rowInd <= $ylast} {incr rowInd} {
            gets $tStr entryLine
            if {$rowInd >= $yfirst} {
		if {$yflip} {
		    set yInd [expr {$lineCount+$ylast-$rowInd}]
		} else {
		    set yInd [expr {$lineCount+$rowInd-$yfirst}]
		}
                lappend rowList $yInd
                set usePts [TrimFields [split ,$entryLine ,]]
                for {set colInd $xfirst} {$colInd<=$xlast} {incr colInd} {
		    if {$xflip} {
			set xInd [expr 1+$xlast-$colInd]
		    } else {
			set xInd [expr 1+$colInd-$xfirst]
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
        set indexList [list $rowList $colList]
    } elseif {[string equal ,image [lindex $tableSpec 1]]} {
        set rowList {}
        set colList {}
	set transpose [expr {[string equal 1 [lindex $tableSpec 10]]}]
	set yflip [expr {[lindex $tableSpec 2]>[lindex $tableSpec 3]}]
	set xflip [expr {[lindex $tableSpec 4]>[lindex $tableSpec 5]}]
	if {$yflip} {
	    set yfirst [lindex $tableSpec 3]
	    set ylast [lindex $tableSpec 2]
	} else {
	    set yfirst [lindex $tableSpec 2]
	    set ylast [lindex $tableSpec 3]
	}
	if {$xflip} {
	    set xfirst [lindex $tableSpec 5]
	    set xlast [lindex $tableSpec 4]
	} else {
	    set xfirst [lindex $tableSpec 4]
	    set xlast [lindex $tableSpec 5]
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
			    warning top {} ok
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
        set indexList [list $rowList $colList]
    } elseif {[string equal ,gdal [lindex $tableSpec 1]]} {
        #	set indexList [ReadGdalRefToArray paramArray $tableSpec]
        return $tableSpec
    } else {
# tableSpec should be:
# fileName dataHeader ?dbtableId? ?wrapTime? ?fillMethod? indHeaders...
	set indexStart 2
	if {[string match ,dbtable:* [lindex $tableSpec 2]]} {
	    regexp ,dbtable:(.*) [lindex $tableSpec 2] match dbtable
	    incr indexStart
	}
	if {[string match ,wrap:* [lindex $tableSpec 2]]} {
	    # its a special point
	    set wrapPt [string range [lindex $tableSpec 2] 6 end]
	    incr indexStart
	}
	if {[string match ,others:* [lindex $tableSpec $indexStart]]} {
	    set fillMtd [string range [lindex $tableSpec $indexStart] 8 end]
	    incr indexStart
	}
        # csv handled by existing code other extensions handled with ODBC
        #ShowMess debug info "Loading table with data $tableSpec; ext $ext" ok
        if { $ext == {.csv} } {
	    gets $tStr headerLine
	    set headerList [TrimFields [split $headerLine ,]]
	    #ShowMess debug info "Headers are $headerList" ok
	    
	    foreach headerIndex [lrange $tableSpec $indexStart end] {
		lappend indexColumns [lsearch -exact $headerList $headerIndex]
	    }
	    set headerColumn [lsearch -exact $headerList [lindex $tableSpec 1]]
	    #ShowMess debug info "Columns: header $headerColumn indxs $indexColumns" ok
	    if {$headerColumn==-1} {
		Query [concat no_data_col [lrange $tableSpec 0 1] \
			   [list $headerList]] warning data_in_cols {} ok
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
	    foreach headerIndex [lrange $tableSpec $indexStart end] {
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
    }
    
    #ShowMess debug info "Converting [array get paramArray] with $indexList" ok
    close $tStr
    set result [ArrayToList paramArray]
    if {$addSpecials} {
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

