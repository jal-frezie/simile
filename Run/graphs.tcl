#############################################################################
# Routines for entering a function graphically or as a table                #
#############################################################################

# This is what happens when the graph button is pushed. It reads the parameter
# name and units from the boxes above the parameter list, then tries to find a
# graph(...) naming that parameter in the equation. If it succeeds it sends off
# the data about that graph to the graphing box, otherwise a null graph. On return
# the graph data is inserted or appended to the equation.

# graph function is graph(param, xlow, xhigh, xspan,
#	ylow, yhigh, yspan, [pt1, pt2 ... ptn])

proc equationGraph {parent} {
    global equation
    toplevel .graph -class graphEntry -bd 4
    wm transient .graph $parent
    # One way to set the window size is to do it explicitly: the other is to use a large initial graph pad size
    #    wm geometry .graph 640x480
    focus .graph
    grab .graph
    # set default values for new graph
    set graphArgs {0 100 400 100 0 400 0 21 200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200}
    if {[info exists equation(table_data)]} {
	if {[string equal /graph/ [lindex $equation(table_data) 0]]} {
	    set graphArgs [concat [lrange $equation(table_data) 5 7] \
			       [lrange $equation(table_data) 1 3] \
			       [lindex $equation(table_data) 8] \
			       [lindex $equation(table_data) 4] \
			       [join $equation(table_values) ,]]
	}
    }
    set done [eval {GraphEntry .graph} $graphArgs]
    grab release .graph
    destroy .graph
    grab $equation(top)
    return $done
}

proc GraphEntry { t xlow xhigh xspan ylow yhigh yspan range size points \
            {target {}}} {
    global tcl_platform graph
    bind $t <Destroy> "set graph($t,done) -1"
    
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
    entry $gph.yentry.topentry -relief sunken -textvar graph($t,lowy) -width 8
    pack $gph.yentry.topentry -side top -pady 2
    label $gph.yentry.toplabel -text "Y max"
    pack $gph.yentry.toplabel -side top -pady 2
    label $gph.yentry.label -text "Value"
    pack $gph.yentry.label -side top -fill y -expand true
    label $gph.yentry.bottomlabel -text "Y min"
    pack $gph.yentry.bottomlabel -side top -pady 2
    entry $gph.yentry.bottomentry -relief sunken -textvar graph($t,highy) -width 8
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
    entry $gph.xentry.leftentry -relief sunken -textvar graph($t,lowx) -width 8
    pack $gph.xentry.leftentry -side left -padx 2
    label $gph.xentry.xmin -text "X min"
    pack $gph.xentry.xmin -side left -padx 2
    label $gph.xentry.arg -text "Argument"
    pack $gph.xentry.arg  -side left -fill x -expand true
    label $gph.xentry.rightlabel -text "X max"
    pack $gph.xentry.rightlabel -side left -padx 2
    entry $gph.xentry.rightentry -relief sunken -textvar graph($t,highx) -width 8
    pack $gph.xentry.rightentry -side left -padx 2
    grid $gph.xentry -column 1 -row 1 -sticky we -padx 2 -pady 2
    
    frame $t.right
    
    set buttons [frame $t.right.buttons]
    button $buttons.enter -text OK -width 10 \
	-command [list set graph($t,done) 1]
    pack $buttons.enter -padx 4 -pady 4 -anchor e
    button $buttons.cancel -text Cancel -width 10 \
	-command [list set graph($t,done) 0]
    pack $buttons.cancel -padx 4 -pady 4 -anchor e
    button $buttons.edit -text "Edit as table" -width 10 \
	-command [list EditAsTable $t $grid]
    pack $buttons.edit -padx 4 -pady 4 -anchor e
    button $buttons.help -text Help -width 10 -command {ContextSensitiveHelp .graph equations/graph.htm}
    pack $buttons.help -padx 4 -pady 4 -anchor e
    pack $buttons -fill x -padx 8 -pady 8
    
    TitleFrame $t.right.current -text "Current Position: "
    set current [$t.right.current getframe]
    
    frame $current.y
    label $current.y.yvalue -text "Y:"
    pack $current.y.yvalue -side left -padx 2 -pady 4
    entry $current.y.yvaluebox -relief sunken -textvar yvalue -width 8
    bind $current.y.yvaluebox <Return> [list YEntry $grid]
    pack $current.y.yvaluebox -side left -padx 2 -pady 4
    pack $current.y -pady 4
    frame $current.x
    label $current.x.xvalue -text "X:"
    pack $current.x.xvalue -side left -padx 2 -pady 4
    entry $current.x.xvaluebox -relief sunken -textvar xvalue -width 8
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
    pack [ComboBox $between.rangeopts -values "Interpolate Round" -editable 0 \
	      -modifycmd "Reshape $t" -width 12]
    pack $between -pady 8 -padx 4
    set out [frame $right.out]
    label $out.outrange -text "Out of range:"
    pack $out.outrange
    pack [ComboBox $out.rangeopts -values "Truncate Extrapolate Wraparound" \
	      -editable 0 -width 12]
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
    
    set niceFormat 0
    while {!$niceFormat} {
        tkwait variable graph($t,done)
        
        if {$graph($t,done)==-1} {
	    return 0
	}
        if {$graph($t,done)} {
            if {[CheckFloaty $graph($t,lowy) $graph($t,highy) \
                        $graph($t,lowx) $graph($t,highx)]} {
                # tk_messageBox -message "$rangeChoices $graph($t,rangeact)"
                set graph($t,range) [SetCombos $t]
                set graph($t,size) [llength $graph($t,points)]
                # regsub -all " " $graph($t,points) , graph($t,pts)
                # Target is set to variable id if editing sketch at run time
                if {[llength $target]} {
                    eval {SetModelGraph $t $target $graph($t,lowx) \
			      $graph($t,highx) $graph($t,width) \
			      $graph($t,lowy) $graph($t,highy) \
			      $graph($t,height) $graph($t,range) \
			      $graph($t,size)} $graph($t,points)
                } else {
                    SetDefaultGraph $graph($t,lowx) $graph($t,highx) $graph($t,width) \
			$graph($t,lowy) $graph($t,highy) $graph($t,height) \
			$graph($t,range) $graph($t,size) $graph($t,points)
                    set niceFormat 1
                }
            }
        } else {
            if {[llength $target]} {
                set lastSaved [GetModelGraph $t $target]
                scan $lastSaved "%g %g %d %g %g %d %d" graph($t,lowx) \
                        graph($t,highx) graph($t,width) \
                        graph($t,lowy) graph($t,highy) \
                        graph($t,height) range
		SetCombos $t $range
                set graph($t,points) [lrange $lastSaved 8 end]
                AttackShape $grid [winfo width $grid] [winfo height $grid]
            } else {
                set niceFormat 1
            }
        }
    }
    return $graph($t,done)
}

proc SetCombos {t args} {
    global graph
    set right [$t.right.options getframe]
    set bCombo $right.between.rangeopts
    set rCombo $right.out.rangeopts
    if {[llength $args]} {
	set between [expr $args/4]
	$bCombo configure -text [lindex [$bCombo cget -values] $between]
	$rCombo configure -text [lindex [$rCombo cget -values] \
				  [expr $args-4*$between]]
    } else {
	set between [lsearch [$bCombo cget -values] [$bCombo cget -text]]
    }
    set graph($t,between) $between
    return [expr 4*$between+[lsearch [$rCombo cget -values] \
				[$rCombo cget -text]]]
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
    set newList [EditListAsTable $t $table]
    foreach {index y} $newList {
	set zone [expr round(($size-1.0)*$index/$range)]
	GStick $canvas $zone [YValueToPoint $t $y]
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
    if {[llength $graph($t,points)] > 2} {
        $c delete graph
        set el 1
        set graph($t,increment) [expr $graph($t,increment)*2]
        while {$el < [llength $graph($t,points)]} {
            set graph($t,points) [lreplace $graph($t,points) \
                    $el [expr $el + 1] [lindex $graph($t,points) $el]]
            AddLine $c $el
            set el [expr $el + 1]
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

proc equationDoTable {parent} {
    global table_entry iconImages
    
    toplevel .table -bd 4
    wm transient .table $parent
    wm protocol .table WM_DELETE_WINDOW {set table_entry(done) 0}
    
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
    pack .table.top.fidx -side left -expand true -fill both -anchor w -padx 2 -pady 2
    #
    # OK, Cancel and Help buttons
    frame .table.top.fbuttons
    button .table.top.fbuttons.load -text Load -width 10 \
	-command [list AcquireTableData $lidx]
    button .table.top.fbuttons.edit -text View/Edit -width 10 \
	-command {set table_entry(values) \
		      [EditListAsTable .table $table_entry(values)]}
    button .table.top.fbuttons.ok -text OK -width 10 \
	-command {set table_entry(done) 1}
    button .table.top.fbuttons.cancel -text Cancel -width 10 \
	-command "set table_entry(done) 0"
    button .table.top.fbuttons.help -text Help -width 10 \
	-command {ContextSensitiveHelp .table equations/table.htm}
    pack .table.top.fbuttons.load -side top -padx 4 -pady 4
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
    frame  $fdata.dhead
    label $fdata.dhead.dheadlabel -text "Use as data column "
    set dhead [Entry $fdata.dhead.dhead \
            -textvariable table_entry(dataField) \
            -dropenabled true -droptypes LISTBOX_ITEM \
            -dropcmd ChooseDataHeader]
    pack $fdata.dhead.dheadlabel -side left -anchor w
    pack $dhead -side left -anchor w -expand true -fill x
    pack $fdata.dhead -side top -anchor w -expand true -fill x
    pack $fdata -fill x
    pack .table.bottom.fdata -fill x
    frame $fdata.dfile
    label $fdata.dfile.dfilelabel -text "Data file                    "
    set dfile [Entry $fdata.dfile.dfile \
            -textvariable table_entry(fileName)]
    bind $dfile <Return> LoadDataFile
    pack $fdata.dfile.dfilelabel -side left -anchor w
    pack $dfile -side left -anchor w -expand true -fill x
    button $fdata.dfile.new -compound left -image $iconImages(open) \
	-text Browse -command {GetDataFile "Select new data file";LoadDataFile}
    pack $fdata.dfile.new -side left -padx 4 -pady 4
    pack $fdata.dfile -side top -anchor w -expand true -fill x
    pack .table.bottom -side top -fill x
    
    set t .table
    tkwait visibility .table
    if {[llength $table_entry(data)]} {
        set table_entry(fileName) [lindex $table_entry(data) 0]
        set table_entry(dataField) [lindex $table_entry(data) 1]
        set table_entry(indices) [lrange $table_entry(data) 2 end]
	set i 1
	foreach idx $table_entry(indices) {
	    $lidx insert end id$i -text $idx
	    incr i
	}
	if {![LoadDataFile]} {
	    destroy $t
	    return 0
	}
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
    destroy $t
    return $table_entry(done)
}

proc AcquireTableData {lidx} {
    global table_entry

    set idcs {}
    foreach itm [$lidx items] {
        lappend idcs [$lidx itemcget $itm -text]
    }
    set table_entry(indices) $idcs
    set tableSpec [concat [list $table_entry(fileName) \
			       $table_entry(dataField)] $table_entry(indices)]
#puts "Loading with $tableSpec"
    set table_entry(values) [LoadTableData $tableSpec]
}

proc EditListAsTable {parent values} {
    global table_viewer

    set t .table_edit
    toplevel $t -bd 4
    wm transient $t $parent
    wm protocol $t WM_DELETE_WINDOW {set table_viewer(done) 0}
    
    set viewerId $table_viewer(id)
    set ::${viewerId}::editMode($t) 1
    ${viewerId}::initialize $t

    set ${viewerId}::dataStore($t,0,0.0) $values
    set ${viewerId}::displayList($t) eqn_table
    set ${viewerId}::orientList($t) {none cols rows cols}
    set ${viewerId}::displayFormat($t,0) {General 4 0}
    ${viewerId}::Reconbobulate $t

    focus $t
    grab $t
    tkwait variable table_viewer(done)
    grab release $t
    destroy $t
# extract step at end so window still gone if it fails
    return [${viewerId}::ExtractEdits $t]
}

proc GetDataFile {info} {
    global table_entry
    set table_entry(fileName) [ChooseFile graph.csv $info 0]
}

proc LoadDataFile {} {
    global table_entry
    
    wm title .table "Create table from file $table_entry(fileName)"
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

proc FileParamDialogue {topNode topWin mustShow} {
    global paramData widgetNames loadingProject
    set allNodes [GetCompProperty $topNode Objects]
    # do it now to shake out errors before opening window
        
    set t [toplevel .fpdialogue]
    wm transient $t $topWin
    wm protocol .fpdialogue WM_DELETE_WINDOW CancelParams
    wm title $t "Enter file parameters"
    if {!$mustShow} {
	set paramData(needed) {}
    }
    MakeFrames $t
    array unset widgetNames
    foreach node $allNodes {
        set isInput [lsearch {TABLE INPUT} \
			 [GetCompProperty $topNode Eval $node]]
	if {$isInput != -1} {
	    AddEntry $t $topNode $node $mustShow $isInput
        }
    }
    if {$mustShow || [llength $paramData(needed)]} {
        pack [set bfrm [frame .fpdialogue.buttons ]] \
                -fill x
        pack [message $bfrm.banner \
                -text "All values must be set to run the model." -width 400]
        pack [frame $bfrm.lpad] -side left -fill x -expand true
        pack [button $bfrm.ok -text "OK" \
		  -command [list DoneParams $topNode $t] -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.cancel -text "Cancel" -command CancelParams -width 10] \
                -side left -padx 2 -pady 2
#        pack [button $bfrm.merge -text "Load file" -command MergeParams -width 10] \
                -side left -padx 2 -pady 2
#        pack [button $bfrm.save -text "Save file" -command SaveParams -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.help -text "Help" -command {ContextSensitiveHelp .fpdialogue data/index.htm} -width 10] \
                -side left -padx 2 -pady 2
        pack [frame $bfrm.rpad] -side left -fill x -expand true
        raise .fpdialogue
        grab $t
        tkwait variable paramData(done)
        grab release $t
        
    } else {
        # Dialogue not needed because data OK so return good
        set paramData(done) 1
    }
    destroy $t
    return $paramData(done)
}

proc MakeFrames {windowId} {
    ScrolledWindow $windowId.c
    set canId $windowId.c.canvas
    ScrollableFrame $canId -yscrollincrement 1 -constrainedwidth true ;# \
            -yscrollcommand [list AdjustCanvas $windowId.c canvas y]
    $windowId.c setwidget $canId
    pack $windowId.c -side top -fill both -expand true

    pack [frame $windowId.checkframe] -in [$canId getframe] -side top -expand true -fill x -padx 2 -pady 2
    pack [frame $windowId.sliderframe] -in [$canId getframe] -side top \
            -fill x -expand true -padx 2 -pady 2
    
    #    $canId create window 0 0 -anchor ne -window [frame $windowId.checkframe]
    #    $canId create window 0 0 -anchor nw -window [frame $windowId.sliderframe]
}

proc AddEntry {winId topNode node mustShow isInput} {
    global paramData paramDims widgetNames iconImages
    set compName [GetCompProperty $topNode Caption $node]
    if {[string match SUBMODEL [GetCompProperty $topNode Class $node]]} {
	set paramData($compName) {}
	return
    }
    set levels [split $compName /]
    set nodeDims [GetCompProperty $topNode Dims $node]

# bit of voodoo...get table relating numerical indices of node to enymerated
# types (from prolog) and use to translate array bounds. Do this first because
# there will be null entries in the table for vm model levels.
    set trans [GetTransTable $node]
    if {$isInput} {
	set nodeDims [linsert $nodeDims 0 TIME]
	set trans [linsert $trans 0 {}]
    }
    set paramDims($compName) [lrange $nodeDims 0 end-1]

#ShowMessage debug info "$node $trans $nodeDims" ok
    set nodeDims [TransBounds $trans $nodeDims]

    set nodeDims [purge $nodeDims MEMBERS]
    set dimList [join [lrange $nodeDims 0 end-1] { x }]
    set last [lindex $nodeDims end]
    if {[string compare $last 0]} {
	if {[string match false $last]} {
	    set last boolean
	}
    } else {
	set last [GetCompProperty $topNode Type $node]
    }
    if {[llength $dimList]} {
	append dimList " of $last"
    } else {
	set dimList "a $last"
    }

    if {[string length $dimList]} {
	set slotCaption "[lindex $levels end] ($dimList):"
    } else {
	set slotCaption [lindex $levels end]
    }
    pack [set slot [frame [MakeSubFrames $topNode $winId.sliderframe $levels \
			       fileparams 0]]] -fill x -expand on
    pack [label $slot.l -text $slotCaption -fg red] -side left
    if {$nodeDims>1} {
	pack [button $slot.b -image $iconImages(edit) -command [namespace code [list GetFromTable $winId $compName]]] -side right
    }
            #	    pack [entry $slot.e -textvariable paramData($compName)]
            # Using entries played merry hell with very long arrays -- texts work better
    pack [entry $slot.e -width 30] -side left -fill x -expand on
    bind $slot.e <Return> "$slot.tick invoke"
    if {[info exists paramData($compName)]} {
	FillIfSmall $slot.e $paramData($compName)
    } else {
	set paramData($compName) {}
    }
    if {[string match normal [$slot.e cget -state]]} {
    pack [button $slot.cross -image $iconImages(cross) -borderwidth 1 \
	      -command [namespace code [list RevertData $winId $compName]]] \
	-side right
    pack [button $slot.tick -image $iconImages(tick) -borderwidth 1 \
	      -command [namespace code [list AcceptData $winId $topNode \
					    $compName 1]]] \
	-side right
    }
    set widgetNames($compName) $slot
            # note whether we need to enter a parameter here...
    if {$mustShow} {
	if {[lsearch $paramData(needed) $compName]==-1} {
	    $slot.l configure -fg black
	}
    } else {
	AcceptData $winId $topNode $compName 0
    }
}

# MakeSubFrames puts up a load and a save button for each submodel frame, and
# gives them the Load and Save commands in a given namespace. So we must put
# the commands in a matching one...

proc MakeSubFrames {clientId parent hierarchy ns pt} {
    global iconImages
    set level [lindex $hierarchy $pt]
    set nextPt [expr $pt+1]
    if {[llength $hierarchy]<=$nextPt} {
        return $parent.box$level
    } else {
        set nextLevel $parent.frame$level
        if {![winfo exists $nextLevel]} {
            pack [frame $nextLevel -bd 2 -relief sunken] -fill x -expand true -padx 2 -pady 2 -side bottom
	    pack [frame $nextLevel.head] -fill x -expand true
        set path [join [lrange $hierarchy 0 $pt] /]
        # added setting of SimileProject element to store spf path
	    pack [button $nextLevel.head.save -image $iconImages(save) \
		      -command [list ${ns}::Save $clientId $path]] -side right
	    pack [button $nextLevel.head.open -image $iconImages(open) \
		      -command [list ${ns}::Open $clientId $path]] -side right
	    if {![string length $level]} {
		set level "TOP LEVEL"
	    }
            pack [label $nextLevel.head.label -text $level:]
        }
        return [MakeSubFrames $clientId $nextLevel $hierarchy $ns $nextPt]
    }
}

proc purge {list toGo} {
    set done {}
    foreach item $list {
	if {[string compare $toGo $item]} {
	    lappend done $item
	}
    }
    return $done
}

proc DoneParams {topNode winId} {
    global widgetNames paramData

    foreach compName [array names widgetNames] {
	AcceptData $winId $topNode $compName 1
    }
    if {![llength $paramData(needed)]} {
	set paramData(done) 1
    }
}

proc AcceptData {winId topNode compName complain} {
    global paramDims paramData widgetNames runState inputHelper running_c

    set node [GetCompProperty $topNode IdFromCapt $compName]
    if {![string equal disabled [$widgetNames($compName).e cget -state]]} {
	set paramData($compName) \
	    [UglifyValList [$widgetNames($compName).e get]]
    }
    
    set dataChanged 0
# for each constant value, check whether it has been changed, and if so,
# flag a complete model rebuild. Do same if running_c lost due to crash
# or model not yet started
    if {![info exists running_c]} {
	set dataChanged 1
    } elseif {[catch {GetCompProperty $topNode Value $node} oldVal]} {
	set dataChanged 1
    } elseif {[string compare [lindex $oldVal 0] $paramData($compName)]} {
	set dataChanged 1
    }
    # Make array form if data has changed
    if {$dataChanged} {
	set runState($topNode,reloadParams) 1
	set trans [GetTransTable $node]

	# Now replace each -1 in the dims with the id of the by-record
	# submodel it represents
	set recordDims $paramDims($compName)
	set afterTIME [string equal TIME [lindex $recordDims 0]]
#puts "node $compName has dims $recordDims"
	while {[set recordDepth [rsearch $recordDims RECORDS]] != -1} {
#puts "recordDims $recordDims recordDepth $recordDepth" 
	    foreach recordId [array names paramData] {
#puts "recordId is $recordId"
		if {[string first $recordId $compName]==0 && \
		    ![string equal $recordId $compName]} {
		    set recordNode [GetCompProperty $topNode \
					IdFromCapt $recordId]
		    set outerDims [lrange [GetCompProperty $topNode Dims \
					       $recordNode] 0 end-1]
#puts "node $recordNode outer dims $outerDims"
		    if {[string match $outerDims \
			     [lrange $recordDims $afterTIME $recordDepth]]} {
			set recordDims [lset recordDims $recordDepth \
					    [list RECORDS $recordNode]]
			break
		    }
		}
	    }
	}

	set misses [ListToArray $node {} $trans $recordDims \
			$paramData($compName)]
# new bit for using it as an input tool: notify that we have values
	if {[llength $misses]} {
	    lappend paramData(needed) $compName
	    $widgetNames($compName).l configure -fg red
	    if {$complain} {
		ShowMessage "Setting $compName" warning "Problem with value at indices [lrange $misses 0 end-1]: [lindex $misses end]" ok
	    }
	} else {
	    $widgetNames($compName).l configure -fg black
	    set paramData(needed) [purge $paramData(needed) $compName]
	}
    }
}

# rsearch gives index of last value
proc rsearch {list tgt} {
    set all [lsearch -all $list $tgt]
    if {[llength $all]} {
	return [lindex $all end]
    } else {
	return -1
    }
}

# need new version that 
proc ListToArray {tgt subs trans dims list} {
#puts "Go! tgt $tgt trans $trans list $list"
# skip over any vm arrays, their indices will not appear
# in calls for values, but keep the translation list in sync
# ... string match stops cleanly at end of list
    while {[string match MEMBERS [lindex $dims 0]]} {
	set trans [lrange $trans 1 end]
	set dims [lrange $dims 1 end]
    }
    set thisTrans [lindex $trans 0]
    if {![llength $dims]} {
	switch [llength $list] {
	    0 {
		return [list "Missing value"]
	    } 1 {
		return [EnumTypeToNumber $tgt$subs $list $thisTrans]
	    } default {
		return [list "Array $list supplied instead of scalar"]
	    }
	}
    }
    if {[llength $list]==1} {
#puts "setting paramData($tgt) to $headNum"
	set userDims [join $dims { x }]
	return [list "scalar $list supplied instead of array of $userDims"]
    }
    if {[llength $list]%2} {
	return [list [lindex $list end] "Missing value"]
    }
	
    foreach {indx sublist} $list {
	set sub($indx) $sublist
    }
# was array set sub $list
#puts "dims remaining $dims"
    if {[string match TIME [lindex $dims 0]]} {
# If time, we can have as many or as few vals as we want, and they can be
# any positive number
	foreach arrayPt [array names sub] {
	    if {![string is double $arrayPt]} {
		return [list $timePoint "Time point must be a number."]
	    }
	    set mis [ListToArray $tgt $subs,$arrayPt $trans \
			 [lrange $dims 1 end] $sub($arrayPt)]
	    if {[llength $mis]} {
		return [concat $arrayPt $mis]
	    }
	}
	return {}
    } 
    if {[llength [lindex $dims 0]]==2 && \
	    [string match RECORDS [lindex [lindex $dims 0] 0]]} {
# by-record submodel; check up to biggest

# OK hows this for branez...use
# the number of elements, because if there is an element larger than the
# number of elements, one the same or smaller will be missing!
	set last [array size sub]
	if {!$last} {
	    return [list "Per-record submodel must have values for at least one member."]
	}

#puts "Setting [lindex [lindex $dims 0] 1]$subs to $last"
	EnumTypeToNumber [lindex [lindex $dims 0] 1]$subs $last {}
    } else {
	set last [lindex $dims 0]
    }
    for {set arrayPt 1} {$arrayPt <= $last} {incr arrayPt} {
	set indx [NumberToEnumType $arrayPt $thisTrans]
	if {![info exists sub($indx)]} {
#puts "No $indx in [array names sub]"
	    return [list $indx "Missing value"]
	}
	set mis [ListToArray $tgt $subs,$arrayPt [lrange $trans 1 end] \
		     [lrange $dims 1 end] $sub($indx)]
	if {[llength $mis]} {
	    return [concat $indx $mis]
	}
    }
    return {}
}
	    
proc EnumTypeToNumber {tgt head trans} {
    global paramData
    if {[string compare {} $trans]} {
	set poss [lsearch $trans [lindex $head 0]]
	if {$poss == -1} {
	    return [list "$head is not a member of type [lindex $trans 0], pick one of [lrange $trans 1 end]."]
	}
	set paramData($tgt) $poss
    } else {
	set paramData($tgt) $head
    }
#puts "just went set paramData($tgt) $paramData($tgt)"
    return {}
}

proc NumberToEnumType {idx trans} {
    if {[llength $trans]} {
	return [lindex $trans $idx]
    } else {
	return $idx
    }
}

proc RevertData {winId compName} {
    global paramData widgetNames
    $widgetNames($compName).e delete 0 end
    if {[info exists paramData($compName)]} {
	$widgetNames($compName).e insert 0 $paramData($compName)
    }
}

proc FillIfSmall {entry text} {
    $entry delete 0 end
    set limit 500
    set count [ShrinkValueList text $limit]
    set text [PrettifyValList $text]

    set shrunken [EndsOnly text $count $limit]
    $entry insert 0 $text
    if {$shrunken} {
	$entry configure -state disabled
    }
}

proc CancelParams {} {
    global paramData
    set paramData(done) 0
}

namespace eval fileparams {

proc Save {spare smPath} {
    global paramState paramData widgetNames SimileProject simtmpdir env
#ShowMessage debug info "Save $smPath" ok
    
    set metaFile [ChooseFile params.spf "Save parameters as:" 1]
    set SimileProject(fileparam,$smPath) $metaFile
    if {[llength $metaFile]} {
	set part [file join $simtmpdir temp_out.spf]
        set pStr [NetOpen $part w]
        
        foreach compName [array names widgetNames $smPath*] {
	    set compTail [string range $compName [string length $smPath] end]
	    set SubbedComp [StripCrs $compTail]
	    if {[info exists paramState($compName)]} {
		if {[string equal $paramData($compName) \
			 [LoadTableData $paramState($compName)]]} {
		    set relName [Relativize $metaFile \
				     [lindex $paramState($compName) 0]]
		    puts $pStr "$SubbedComp=reference=[lreplace \
                                $paramState($compName) 0 0 $relName]"
		    continue
		}
	    }
	    puts $pStr "$SubbedComp=literal=$paramData($compName)"
	}
        close $pStr
	set PartType "application/x-simile"
	set Description "Simile parameter file"
	set style attachment
	set newMime [mime::initialize -canonical $PartType \
			 -header [list "Content-Disposition" $style] \
			 -header [list "Content-Description" $Description] \
			 -header [list "Simile-Version" $env(SIMILE_VERSION)] \
			 -header [list "Simile-Origin" file-param-dialogue] \
			 -file $part]
	set stream [NetOpen $metaFile w]
        fconfigure $stream -translation binary
        mime::copymessage $newMime $stream
        # clean everything up
        close $stream
        mime::finalize $newMime
	file delete $part
    }
}

# merge a parameter metafile. These are saved with the pathnames of the .csv files
# relative to the location of the metafile, so in order to reload the .csvs we need to
# reconnect them with this pathname...trouble is, if I save in a new directory I'll need
# new relative pathnames and I can only generate these starting from the absolute
# pathname. And the only way to get that without a hack is to cd to it...

proc Open {topNode smPath} {
    global SimileProject
    set metaFile [ChooseFile params.spf "Load parameters from:" 0]
    set SimileProject(fileparam,$smPath) $metaFile
    if {[llength $metaFile]} {
	MergeParams $topNode $smPath $metaFile 1

    }
}
}

proc MergeParams {topNode smPath oldPath interactive} {
    global paramState paramData widgetNames mimeSquirter simtmpdir
    
    set oldDir [pwd]
    if {[catch { 
	set multiT [mime::initialize -file $oldPath]
	set origVersion [mime::getheader $multiT Simile-Version]
	set metaFile [file join $simtmpdir temp_in.spf]
	set mimeSquirter [NetOpen $metaFile w]
	fconfigure $mimeSquirter -translation binary
	mime::getbody $multiT -command SquirtMime -blocksize 256}]
    } {
	set metaFile $oldPath
	set origVersion 0.0
    }
    set pStr [NetOpen $metaFile r]
    while {[gets $pStr savedValue] != -1} {
	#ShowMessage debug info "Restoring $savedValue" ok
	set IdAndValue [split $savedValue =]
	set restoredComp [RestoreCrs $smPath[lindex $IdAndValue 0]]
	if {$origVersion<4.0} {
	    # pre-multiple desktop -- trim outermost model
	    if {[string equal /Desktop/ [string range $restoredComp 0 8]]} {
		set restoredComp [string range $restoredComp 8 end]
	    }
	}
            #ShowMessage debug info "Component is $restoredComp, looking in [winfo children .fpdialogue.sliderframe]" ok
	if {[info exists paramData($restoredComp)]} {
	    if {$origVersion>=4.0} {
		set paramData($restoredComp) [lindex $IdAndValue 2]
		set reference [string equal reference [lindex $IdAndValue 1]]
		if {$reference} {
		    set VFile [lindex $paramData($restoredComp) 0]
		}
	    } else {
		set paramData($restoredComp) [TrimFields \
						  [lindex $IdAndValue 1]]
		set VFile [lindex $paramData($restoredComp) 0]
		set reference [file exists [file join [file dirname $oldPath] \
						$VFile]]
	    }
                #ShowMessage debug info "Param data is $paramData($restoredComp)" ok
                
                # OK here we go...try and follow this...first go to the starting point..
	    if {$reference} {
		# Now use the saved relative path to move to the .csv file's directory
		cd [file join [file dirname $oldPath] [file dirname $VFile]]
		# ...and stick the new absolute pathname into the spec! Easy!!
		set paramState($restoredComp) \
		    [concat [list [pwd]/[file tail $VFile]] \
			 [lrange $paramData($restoredComp) 1 end]]
                    # now just load up the data
                    #ShowMessage debug info "Field spec set to $paramState($restoredComp)" ok
		set paramData($restoredComp) \
		    [LoadTableData $paramState($restoredComp)]
	    } else {
		set node [GetCompProperty $topNode IdFromCapt $restoredComp]
		set trans [GetTransTable $node]
		if {![SensibleValue $trans $paramData($restoredComp)]} {
		    ShowMessage "Error merging parameters" error "Parameterization file contained the entry $paramData($restoredComp) for component $restoredComp. This entry does not start with the name of an existing file, nor is it a numerical value, boolean, or one of the enumerated types defined for this component, which are $trans." ok
		    set paramData($restoredComp) {}
		}
	    }
	    if {$interactive} {
		FillIfSmall $widgetNames($restoredComp).e \
		    $paramData($restoredComp)
	    }
	}
    }
    close $pStr
    if {$origVersion>=4.0} {
	file delete $metaFile
    }
    cd $oldDir
}

# This tests for sensible model values.
# 0: not sensible

# 1: an integer
# 2: a float
# 3: a list

proc SensibleValue {trans list} {
    set curLevel [lindex $trans 0]
    if {[llength $list]==1} {
        return [VarType [lindex $list 0] $curLevel]
    } else {
        for {set idx 0} {$idx < [llength $list]} {incr idx 2} {
            if {[VarType [lindex $list $idx] $curLevel] != 1 || \
		    ![SensibleValue [lrange $trans 1 end] \
			  [lindex $list [expr $idx+1]]]} {
                return 0
            }
        }
        return 3
    }
}

# useful proc which returns 1 for an int, 2 for a float, 1 for a member of the 
# supplied list (used for enum types) and 0 for all else

proc VarType {testVar types} {
    if {[string is integer $testVar]} {
        return 1
    } elseif {[string is double $testVar]} {
        return 2
    } elseif {[lsearch $types $testVar]!=-1} {
	return 1
    } else {
	puts "No $testVar in $types"
        return 0
    }
}

# takes two file names and returns the second relative to the first
proc Relativize {current remote} {
    #	ShowMessage debug info "relativizing $current $remote" ok
    set currentList [file split $current]
    set remoteList [file split $remote]
    set parted 0
    set base {}
    for {set sameCount 0} {$sameCount < [llength $currentList]} {incr sameCount} {
        if {$parted} {
            lappend base ..
        } elseif {[string compare [lindex $currentList $sameCount] \
                    [lindex $remoteList $sameCount]]} {
            set tail [lrange $remoteList $sameCount end]
            set parted 1
        }
    }
    return [eval {file join} $base $tail]
}

proc GetFromTable {parent compName} {
    global paramState paramData widgetNames table_entry
    if {[info exists paramState($compName)]} {
	set table_entry(data) $paramState($compName)
    } else {
	set table_entry(data) {}
    }
    if {[string match normal [$widgetNames($compName).e cget -state]]} {
	set table_entry(values) [UglifyValList [$widgetNames($compName).e get]]
    } else {
	set table_entry(values) $paramData($compName)
    }
    if {[equationDoTable $parent]} {
        if {[llength $table_entry(dataField)]} {
	    set paramState($compName) [concat [list $table_entry(fileName) \
						   $table_entry(dataField)] \
					   $table_entry(indices)]
	}
        set paramData($compName) $table_entry(values)
        FillIfSmall $widgetNames($compName).e $paramData($compName)
    }
}

# try to minimize effort at runtime -- list timepoints for each node...
proc InitTimeSeries {topNode} {
    global setFromSeries paramData
    array unset setFromSeries
    foreach node [GetCompProperty $topNode Objects] {
	if {[string match INPUT [GetCompProperty $topNode Eval $node]]} {
#puts "timePts [array names paramData $node,*]"
	    foreach timePt [array names paramData $node,*] {
		set ${node}([lindex [split $timePt ,] 1]) 1
	    }
	    if {[array size $node]} {
		set setFromSeries($topNode,$node,times) \
		    [lsort [array names $node]]
		set setFromSeries($topNode,$node,next) 0
#puts "initted $setFromSeries($node,times)"
	    }
	}
    }
}

proc ResetTimeSeries {topNode} {
    global setFromSeries
    foreach pt [array names setFromSeries $topNode,*,next] {
	set setFromSeries($pt) 0
    }
}

# for each node we have a lsit of times in the time series, and a pointer to 
# where we are in the list. If the time has gone past that pointed to, signal 
# the data to be written and look at the next one...
proc UpdateTimeSeries {topNode newTime} {
    global setFromSeries paramData
    foreach list [array names setFromSeries $topNode,*,times] {
	set node [lindex [split $list ,] 1]
#puts "node $node times $setFromSeries($list) next $setFromSeries($node,next) newTime $newTime"
	set jumping 1
	while {$jumping} {
	    upvar 0 setFromSeries($topNode,$node,next) series
	    if {[llength $setFromSeries($list)] > $series} {
		set oldTime [lindex $setFromSeries($list) $series]
		if {$newTime >= $oldTime} {
		    set useTime $oldTime
		    incr series
		} else {
		    set jumping 0
		}
	    } else {
		set jumping 0
	    }
	}

	if {[info exists useTime]} {
	    upvar \#0 [InputVarFor $node] inputSrc
	    # do it the easy way if a scalar
#puts "looking for paramData($node,$useTime)"
	    if {[info exists paramData($node,$useTime)]} {
		set inputSrc($node) $paramData($node,$useTime)
#puts "set inputSrc($useTime) $paramData($node,$useTime)"
		return
	    }
	    foreach tsValue [array names paramData $node,$useTime,*] {
		set inputSrc([join [lreplace [split $tsValue ,] 1 1] ,]) \
		    $paramData($tsValue)
	    }
	}
    }
}

proc LoadTableData {tableSpec} {
    
#ShowMessage debug info "Loading table with data $tableSpec" ok
    set tStr [NetOpen [lindex $tableSpec 0] r]
    gets $tStr headerLine
    set headerList [TrimFields [split $headerLine ,]]
#ShowMessage debug info "Headers are $headerList" ok
    
    set indexCount 0
    set lineCount 0
    set maxIndices(0) {}
    foreach headerIndex [lrange $tableSpec 2 end] {
        lappend indexColumns [lsearch $headerList $headerIndex]
        set maxIndices($indexCount) {}
        incr indexCount
    }
    set headerColumn [lsearch $headerList [lindex $tableSpec 1]]
#ShowMessage debug info "Columns: header $headerColumn" ok
    
    while {[gets $tStr entryLine] != -1} {
	set entryList [TrimFields [split $entryLine ,]]
#ShowMessage debug info "Data line is $entryList" ok
        
        if {[info exists indexColumns]} {
            set arrayIndex {}
            set indexCount 0
            foreach column $indexColumns {
                set newIndex [lindex $entryList $column]
		# enquote the above if indices of llength 1 are needed
                lappend arrayIndex $newIndex
                if {[lsearch $maxIndices($indexCount) $newIndex] == -1} {
                    lappend maxIndices($indexCount) $newIndex
                }
                incr indexCount
            }
        } else {
            incr lineCount
	    lappend maxIndices(0) $lineCount
            set arrayIndex $lineCount
            set indexCount 1
        }
        
        set paramArray(top,[join $arrayIndex ,]) \
	    [EnquoteIfNonNumeric [lindex $entryList $headerColumn]]
    }
    
    for {set idxIdx 0} {$idxIdx < $indexCount} {incr idxIdx} {
        lappend indexList $maxIndices($idxIdx)
    }
    
#ShowMessage debug info "Converting [array get paramArray] with $indexList" ok
    close $tStr
    return [ArrayToList paramArray top $indexList]
}
proc TrimFields {dataLine} {
    foreach entry $dataLine {
	lappend entryList [string trim $entry]
    }
    return $entryList
}

proc EnquoteIfNonNumeric {item} {
    if {[string is double $item]} {
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
        if {[info exists array($indexSoFar)]} {
	    set result $array($indexSoFar)
        } else {
            set result 0
        }
    }
    return $result
}
