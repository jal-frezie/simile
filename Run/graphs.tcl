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
    global graph equation
    toplevel .graph -class graphEntry -bd 4
    wm transient .graph $parent
    wm protocol .graph WM_DELETE_WINDOW {set graph(done) 0}
    # One way to set the window size is to do it explicitly: the other is to use a large initial graph pad size
    #    wm geometry .graph 640x480
    focus .graph
    grab .graph
    if {![info exists graph(pts)]} {
        # set default values for new graph
        # Changed default size to 50x50 to let it fit into MRE
        GraphEntry .graph 0 100 400 100 0 400 0 21 200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200
    } else {
        GraphEntry .graph $graph(lowx) \
                $graph(highx) $graph(width) \
                $graph(lowy) $graph(highy) \
                $graph(height) $graph(range) $graph(size) \
                $graph(pts)
    }
    grab release .graph
    destroy .graph
    grab $equation(top)
    return $graph(done)
}

proc ExtractGraphData { formula } {
    global graph
    #ShowMessage debug info "Getting graph from $formula" ok
    while {[regexp "graph\\( *(\[^,\]*), *(\[^,\]*), *(\[^,\]*), *(\[^,\]*), *(\[^,\]*),\
                *(\[^,\]*), *(\[^,\]*), *(\[^,\]*), *points\\((\[^)\]*)\\)," \
                $formula match graph(lowx) \
                graph(highx) graph(width) \
                graph(lowy) graph(highy) \
                graph(height) graph(range) graph(size) \
                graph(pts)]} {
        # next line puts backslashes before chars in match expr which would
        # otherwise be special to regsub (I may not have them all)
        #ShowMessage debug info "Got expr $match" ok
        regsub -all \[\\(\\)\\+\] $match \\\\\\0 match
        #ShowMessage debug info "Subbed it to $match" ok
        regsub $match $formula graph( formula
    }
    return $formula
}

proc CombineGraphData { formula } {
    global graph
    if {[string match *graph\(* $formula]} {
        regsub -all "graph\\(" $formula \
                [format graph(%g,%g,%g,%g,%g,%g,%g,%g,points(%s), \
                $graph(lowx) \
                $graph(highx) $graph(width) \
                $graph(lowy) $graph(highy) \
                $graph(height) $graph(range) $graph(size) \
                $graph(pts)] formula
    }
    return $formula
}

proc GraphEntry { t xlow xhigh xspan ylow yhigh yspan range size points \
            {target {}}} {
    global graph tcl_platform
    
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
    set rangeChoices "Truncate Extrapolate Wraparound"
    
    set graph(rangeact) [lindex $rangeChoices $range]
    set graph(points) [split $points ,]
    set graph(lowy) $ylow
    set graph(highy) $yhigh
    set graph(height) $yspan
    set graph(lowx) $xlow
    set graph(highx) $xhigh
    set graph(width) $xspan
    
    catch {wm title $t "Sketch graph"}
    
    TitleFrame $t.gph -text "Graph pad"
    set gph [$t.gph getframe]
    frame $gph.yentry
    entry $gph.yentry.topentry -relief sunken -textvar graph(lowy) -width 8
    pack $gph.yentry.topentry -side top -pady 2
    label $gph.yentry.toplabel -text "Y max"
    pack $gph.yentry.toplabel -side top -pady 2
    label $gph.yentry.label -text "Value"
    pack $gph.yentry.label -side top -fill y -expand true
    label $gph.yentry.bottomlabel -text "Y min"
    pack $gph.yentry.bottomlabel -side top -pady 2
    entry $gph.yentry.bottomentry -relief sunken -textvar graph(highy) -width 8
    pack $gph.yentry.bottomentry -side top -pady 2
    grid $gph.yentry -column 0 -row 0 -sticky ns -padx 2 -pady 2
    
    frame $gph.gridf
    set grid [canvas $gph.gridf.canvas -width [expr $graph(width)+1] \
            -height [expr $graph(height)+1] -bd $graph(bd) -relief groove]
    set graph(increment) [expr $graph(width)/([llength $graph(points)] - 1.0)]
    
    bind $grid <Button-1> "GClick %W %x %y"
    bind $grid <B1-Motion> "GDrag %W %x %y"
    bind $grid <Configure> "AttackShape %W %w %h"
    
    frame $gph.xentry
    entry $gph.xentry.leftentry -relief sunken -textvar graph(lowx) -width 8
    pack $gph.xentry.leftentry -side left -padx 2
    label $gph.xentry.xmin -text "X min"
    pack $gph.xentry.xmin -side left -padx 2
    label $gph.xentry.arg -text "Argument"
    pack $gph.xentry.arg  -side left -fill x -expand true
    label $gph.xentry.rightlabel -text "X max"
    pack $gph.xentry.rightlabel -side left -padx 2
    entry $gph.xentry.rightentry -relief sunken -textvar graph(highx) -width 8
    pack $gph.xentry.rightentry -side left -padx 2
    grid $gph.xentry -column 1 -row 1 -sticky we -padx 2 -pady 2
    
    frame $t.right
    
    set buttons [frame $t.right.buttons]
    button $buttons.enter -text OK -width 10 -command {set graph(done) 1}
    pack $buttons.enter -padx 4 -pady 4 -anchor e
    button $buttons.cancel -text Cancel -width 10 -command {set graph(done) 0}
    pack $buttons.cancel -padx 4 -pady 4 -anchor e
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
    
    set out [frame $right.out]
    label $out.outrange -text "Out of range:"
    pack $out.outrange
    pack [ComboBox $out.rangeopts -values $rangeChoices -editable 0 -textvariable graph(rangeact) -width 12]
    pack $out -pady 8 -padx 4
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
    
    RedrawGrid $grid $graph(width) $graph(height) $graph(increment)
    
    set niceFormat 0
    while {!$niceFormat} {
        tkwait variable graph(done)
        
        if {$graph(done)} {
            if {[CheckFloaty $graph(lowy) $graph(highy) \
                        $graph(lowx) $graph(highx)]} {
                # tk_messageBox -message "$rangeChoices $graph(rangeact)"
                set graph(range) [lsearch $rangeChoices $graph(rangeact)]
                set graph(size) [llength $graph(points)]
                regsub -all " " $graph(points) , graph(pts)
                # Target is set to variable id if editing sketch at run time
                if {[llength $target]} {
                    eval {SetModelGraph $target $graph(lowx) \
                                $graph(highx) $graph(width) \
                                $graph(lowy) $graph(highy) \
                                $graph(height) $graph(range) $graph(size)} \
                            [split $graph(pts) ,]
                } else {
                    set niceFormat 1
                }
            }
        } else {
            if {[llength $target]} {
                set lastSaved [GetModelGraph $target]
                scan $lastSaved "%g %g %d %g %g %d %d" graph(lowx) \
                        graph(highx) graph(width) \
                        graph(lowy) graph(highy) \
                        graph(height) range
                set graph(rangeact) [lindex $rangeChoices $range]
                set graph(points) [lrange $lastSaved 8 end]
                AttackShape $grid [winfo width $grid] [winfo height $grid]
            } else {
                set niceFormat 1
            }
        }
    }
    return $graph(done)
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

proc AddLine {c section} {
    global graph
    set miss [expr $graph(bd)+$graph(origin)]
    
    $c delete section$section
    $c create line [expr round($graph(increment)*($section-1))+$miss] \
            [expr [lindex $graph(points) [expr $section - 1]]+$miss] \
            [expr round($graph(increment)*$section)+$miss] \
            [expr [lindex $graph(points) $section]+$miss] \
            -tags "graph section$section"
}

proc GClick {c x y} {
    global graph
    set x [expr $x-$graph(bd)-$graph(origin)]
    set y [expr $y-$graph(bd)-$graph(origin)]
    set zone [expr round($x/$graph(increment))]
    set graph(oldzone) $zone
    set graph(oldy) $y
    GStick $c $zone $y
}

proc YEntry {c} {
    global graph xvalue yvalue
    if {![CheckFloaty $graph(lowy) $graph(highy) $graph(lowx) $graph(highx) \
                $xvalue $yvalue]} {
        return
    }
    set zone [expr round(([llength $graph(points)]-1.0)*\
            ($xvalue-$graph(lowx))/($graph(highx)-$graph(lowx)))]
    set y [expr round($graph(height)*\
            ($yvalue-$graph(lowy))/($graph(highy)-$graph(lowy)))]
    GStick $c $zone $y
}

proc GDrag {c ox oy} {
    global graph
    
    set x [expr $ox-$graph(bd)-$graph(origin)]
    set y [expr $oy-$graph(bd)-$graph(origin)]
    set zone [expr round($x/$graph(increment))]
    set gmove [expr abs($zone - $graph(oldzone))]
    if {$gmove} {
        set step [expr ($zone - $graph(oldzone))/$gmove]
        set incr [expr ($y - $graph(oldy))/$gmove]
        while {$graph(oldzone) != $zone} {
            set graph(oldzone) [expr $graph(oldzone) + $step]
            set graph(oldy) [expr $graph(oldy) + $incr]
            GStick $c $graph(oldzone) $graph(oldy)
        }
    } else {
        GClick $c $ox $oy
    }
}

proc GStick {c zone y} {
    global graph xvalue yvalue
    
    if {![CheckFloaty $graph(lowy) $graph(highy) $graph(lowx) $graph(highx)]} {
        return
    }
    set y [max 0 [min $graph(height) $y]]
    if {$zone >= 0 && $zone < [llength $graph(points)]} {
        set graph(points) [lreplace $graph(points) $zone $zone $y]
        if {$zone != 0} {
            AddLine $c $zone
        }
        if {$zone != [expr [llength $graph(points)] - 1]} {
            AddLine $c [expr $zone + 1]
        }
    }
    set xvalue [expr $graph(lowx) + \
            ($graph(highx)-$graph(lowx))*$zone/([llength $graph(points)]-1.0)]
    set yvalue [expr $graph(lowy) + \
            ($graph(highy)-$graph(lowy))*($y*1.0)/$graph(height)]
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

proc AttackShape {c w h} {
    global graph
    
    # This version used to change the axis labels when the
    # graph window was resized. Now we keep them the same and stretch the graph
    
    set exag [expr 2*$graph(bd)+$graph(exag)]
    set graph(increment) [expr $graph(increment)*($w-$exag)/$graph(width)]
    set graph(width) [expr $w-$exag]
    
    set vchange [expr double($h-$exag)/$graph(height)]
    set graph(height) [expr $h-$exag]
    RedrawGrid $c $graph(width) $graph(height) $graph(increment)
    
    set graph(points) [lreplace $graph(points) 0 0 \
            [expr round([lindex $graph(points) 0]*$vchange)]]
    set section 1
    while {$section < [llength $graph(points)]} {
        set graph(points) [lreplace $graph(points) $section $section \
                [expr round([lindex $graph(points) $section]*$vchange)]]
        AddLine $c $section
        set section [expr $section + 1]
    }
}

proc CoarseX { c } {
    global graph
    
    if {[llength $graph(points)] > 2} {
        $c delete graph
        set el 1
        set graph(increment) [expr $graph(increment)*2]
        while {$el < [llength $graph(points)]} {
            set graph(points) [lreplace $graph(points) \
                    $el [expr $el + 1] [lindex $graph(points) $el]]
            AddLine $c $el
            set el [expr $el + 1]
        }
        RedrawGrid $c $graph(width) $graph(height) $graph(increment)
    }
}

proc FineX { c } {
    global graph
    
    if {$graph(increment) >= 2.0} {
        $c delete graph
        set el 1
        set graph(increment) [expr $graph(increment)/2]
        while {$el < [llength $graph(points)]} {
            set graph(points) [linsert $graph(points) $el \
                    [expr ([lindex $graph(points) [expr $el - 1]] + \
                    [lindex $graph(points) $el])/2]]
            AddLine $c $el
            AddLine $c [expr $el + 1]
            set el [expr $el + 2]
        }
        RedrawGrid $c $graph(width) $graph(height) $graph(increment)
    }
}

#####################################################################
# TABLE LOADING
#####################################################################

proc equationDoTable {parent} {
    global equation table_entry
    
    if {[llength $equation(table_data)]} {
        set table_entry(fileName) [lindex $equation(table_data) 0]
        set table_entry(dataField) [lindex $equation(table_data) 1]
        set table_entry(indices) [lrange $equation(table_data) 2 end]
    } else {
        if {![string compare \
                    [GetDataFile "No data file yet specified"] {}]} {
            return 0
        }
        set table_entry(indices) {}
    }
    
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
    set i 1
    foreach idx $table_entry(indices) {
        $lidx insert end id$i -text $idx
        incr i
    }
    pack $lheads  -expand true -fill both
    pack .table.top.fheads -side left -expand true -fill both -anchor w -padx 2 -pady 2
    pack $lidx -expand true -fill both -anchor w
    pack .table.top.fidx -side left -expand true -fill both -anchor w -padx 2 -pady 2
    #
    # OK, Cancel and Help buttons
    frame .table.top.fbuttons
    button .table.top.fbuttons.ok -text OK -width 10 \
            -command FinishTableSelection
    button .table.top.fbuttons.cancel -text Cancel -width 10 \
            -command "set table_entry(done) 0"
    button .table.top.fbuttons.help -text Help -width 10 \
            -command {ContextSensitiveHelp .table equations/table.htm}
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
    pack $fdata.dfile.dfilelabel -side left -anchor w
    pack $dfile -side left -anchor w -expand true -fill x
    set tbl [image create photo -file "../Images/Toolbar/table.gif" ]
    set opn [image create photo -file "../Images/Toolbar/open.gif" ]
    button $fdata.dfile.new -compound left -image $opn -text Browse \
            -command {GetDataFile "Select new data file"; LoadDataFile}
    button $fdata.dfile.view -compound left -image $tbl -text View \
            -command ViewTable
    pack $fdata.dfile.new -side left -padx 4 -pady 4
    pack $fdata.dfile.view -side left -padx 4 -pady 4
    pack $fdata.dfile -side top -anchor w -expand true -fill x
    pack .table.bottom -side top -fill x
    
    set t .table
    tkwait visibility .table
    if {![LoadDataFile]} {
        return 0
    }
    
    focus $t
    grab $t
    tkwait variable table_entry(done)
    grab release $t
    set idcs {}
    foreach itm [$lidx items] {
        lappend idcs [$lidx itemcget $itm -text]
    }
    set table_entry(indices) $idcs
    destroy $t
    return $table_entry(done)
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
            destroy .table
            return 0
        }
    }
    gets $stream firstLine
    set table_entry(allHeads) [split $firstLine ,]
    set i 1
    foreach hd $table_entry(allHeads) {
        $fheads.lheads insert end hd$i -text $hd
        incr i
    }
    close $stream
    return 1
}

proc FinishTableSelection {} {
    global table_entry
    
    if {[lsearch $table_entry(allHeads) $table_entry(dataField)]<0} {
        ShowMessage {Data column not found} warning \
                "Your selection for data column is not in the headers of this table." ok
    } else {
        set table_entry(done) 1
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

proc ViewTable {} {
    global helperTable table_entry data.viewer
    toplevel .viewer -bd 4
    wm transient .viewer .table
    $helperTable(TableViewer)::initialize .viewer
    
    set stream [open $table_entry(fileName) r]
    set row 0
    while {[gets $stream line] >= 0} {
        set col 0
        foreach field [split $line ,] {
            set data.viewer($row,$col) $field
            incr col
        }
        incr row
    }
    close $stream
    .viewer.t configure -rows $row -cols $col -titlerows 1 -state disabled
    focus .viewer
    grab .viewer
}

proc FileParamDialogue {mustShow parent} {
    global paramData widgetNames
    set allNodes [GetObjectList]
    # do it now to shake out errors before opening window
    
    set t [toplevel .fpdialogue]
    wm transient $t $parent
    wm protocol .fpdialogue WM_DELETE_WINDOW CancelParams
    wm title $t "Enter file parameters"
    set needed {}
    MakeFrames $t
    foreach node $allNodes {
        if {[string match TABLE [GetModelEval $node]]} {
            set compName [GetCaptionPathFromId $node]
            set levels [lrange [split $compName /] 1 end]
            set nodeDims [GetModelDims $node]
            while {[set sep [lsearch $nodeDims -1]]>-1} {
                set nodeDims [lreplace $nodeDims $sep $sep]
            }
# bit of voodoo...get table relating numerical indices of node to enymerated
# types (from prolog) and use to translate array bounds
	    set trans [GetFromProlog tk_get_info('$t',$node,types)]
#ShowMessage debug info "$node $trans $nodeDims" ok
	    set nodeDims [TransBounds $trans $nodeDims]
            set dimList [join [lrange $nodeDims 0 end-1] { x }]
	    set last [lindex $nodeDims end]
	    if {[string compare $last 0]} {
		if {[llength $dimList]} {
		    append dimList " of $last"
		} else {
		    set dimList "a $last"
		}
	    }
            if {[string length $dimList]} {
                set slotCaption "[lindex $levels end] ($dimList):"
            } else {
                set slotCaption [lindex $levels end]
            }
            pack [set slot [frame [MakeSubFrames $t.sliderframe $levels]]] -fill x -expand on
            pack [label $slot.l -text $slotCaption] -side left
            if {$nodeDims>1} {
                pack [button $slot.b -text "Read table" \
                        -command [list GetFromTable $t $compName]] -side right
            }
            
            #	    pack [entry $slot.e -textvariable paramData($compName)]
            # Using entries played merry hell with very long arrays -- texts work better
            pack [text $slot.e -width 30 -height 1] -side right -fill x -expand on
            if {[info exists paramData($compName)]} {
                $slot.e insert 1.0 $paramData($compName)
            } else {
                set paramData($compName) {}
            }
            set widgetNames($compName) $slot.e
            
            # note whether we need to enter a parameter here...
            if {![llength $paramData($compName)]} {
                lappend needed $compName
            }
        }
    }
    if {$mustShow || [llength $needed]} {
        pack [set bfrm [frame .fpdialogue.buttons ]] \
                -fill x
        pack [message $bfrm.banner \
                -text "All values must be set to run the model." -width 400]
        pack [frame $bfrm.lpad] -side left -fill x -expand true
        pack [button $bfrm.ok -text "OK" -command [list DoneParams $needed] -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.cancel -text "Cancel" -command CancelParams -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.merge -text "Load file" -command MergeParams -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.save -text "Save file" -command SaveParams -width 10] \
                -side left -padx 2 -pady 2
        pack [button $bfrm.help -text "Help" -command {ContextSensitiveHelp .fpdialogue data/index.htm} -width 10] \
                -side left -padx 2 -pady 2
        pack [frame $bfrm.rpad] -side left -fill x -expand true
        raise .fpdialogue
        grab $t
        tkwait variable paramData(/done/)
        grab release $t
        
    } else {
        # Dialogue not needed because data OK so return good
        set paramData(/done/) 1
    }
    destroy $t
    return $paramData(/done/)
}

proc MakeFrames {windowId} {
    frame $windowId.c
    set canId $windowId.c.canvas
    #    pack [frame $windowId.buttonframe] -side bottom
    ScrollableFrame $canId -yscrollincrement 1 \
            -yscrollcommand [list AdjustCanvas $windowId.c canvas y] \
            -constrainedwidth true
    scrollbar $windowId.c.yscroll -orient v -command [list $canId yview]
    
    pack $windowId.c.yscroll -side right -fill y
    pack $canId -side left -fill both -expand true
    pack $windowId.c -side top -fill both -expand true
    pack [frame $windowId.checkframe] -in [$canId getframe] -side top -expand true -fill x -padx 2 -pady 2
    pack [frame $windowId.sliderframe] -in [$canId getframe] -side top \
            -fill x -expand true -padx 2 -pady 2
    
    #    $canId create window 0 0 -anchor ne -window [frame $windowId.checkframe]
    #    $canId create window 0 0 -anchor nw -window [frame $windowId.sliderframe]
}

proc MakeSubFrames {parent hierarchy} {
    if {[llength $hierarchy]<=1} {
        return $parent.box$hierarchy
    } else {
        set level [lindex $hierarchy 0]
        set nextLevel $parent.frame$level
        if {![winfo exists $nextLevel]} {
            pack [frame $nextLevel -bd 2 -relief sunken] -fill x -expand true -padx 2 -pady 2
            pack [label $nextLevel.label -text $level:]
        }
        return [MakeSubFrames $nextLevel [lrange $hierarchy 1 end]]
    }
}

proc DoneParams {oldMissing} {
    global paramData widgetNames runState running_c
    
    foreach node [GetObjectList] {
        if {[string match TABLE [GetModelEval $node]]} {
            set compName [GetCaptionPathFromId $node]
            set paramData($compName) [$widgetNames($compName) get 1.0 1.end]
            #ShowMessage debug info "-paramData($compName)- is -$paramData($compName)-" ok
            if {![llength $paramData($compName)]} {
                set empties 1
                # for each constant value, check whether it has been changed, and if so,
                # flag a complete model rebuild. Do same if running_c lost due to crash
            } elseif {[lsearch $oldMissing $compName] > -1} {
                set runState(reloadParams) 1
            } elseif {![info exists running_c]} {
                set runState(reloadParams) 1
            } elseif {[string compare [lindex [GetModelValue $node] 0] \
                        $paramData($compName)]} {
                set runState(reloadParams) 1
            }
        }
    }
    if {[info exists empties]} {
        .fpdialogue.buttons.banner configure -text "Some values still missing!"
    } else {
        set paramData(/done/) 1
    }
}

proc CancelParams {} {
    global paramData
    set paramData(/done/) 0
}

proc SaveParams {} {
    global paramState paramData widgetNames
    
    set metaFile [ChooseFile params.spf "Save parameters as:" 1]
    if {[llength $metaFile]} {
        set pStr [open $metaFile w]
        
        
        
        
        foreach node [GetObjectList] {
            if {[string match TABLE [GetModelEval $node]]} {
                set compName [GetCaptionPathFromId $node]
                set paramData($compName) [$widgetNames($compName) get 1.0 1.end]
                
                if {[info exists paramState($compName)]} {
                    if {[string compare $paramData($compName) \
                                [LoadTableData $paramState($compName) 0]]} {
                        unset paramState($compName)
                    }
                }
                set SubbedComp [StripCrs $compName]
                if {[info exists paramState($compName)]} {
                    set relName [Relativize $metaFile \
                            [lindex $paramState($compName) 0]]
                    puts $pStr "$SubbedComp=[lreplace $paramState($compName) \
                            0 0 $relName]"
                } else {
                    puts $pStr "$SubbedComp=$paramData($compName)"
                }
            }
        }
        close $pStr
    }
}

# merge a parameter metafile. These are saved with the pathnames of the .csv files
# relative to the location of the metafile, so in order to reload the .csvs we need to
# reconnect them with this pathname...trouble is, if I save in a new directory I'll need
# new relative pathnames and I can only generate these starting from the absolute
# pathname. And the only way to get that without a hack is to cd to it...

proc MergeParams {} {
    global paramState paramData widgetNames
    
    
    set oldDir [pwd]
    set metaFile [ChooseFile params.spf "Merge parameters from:" 0]
    if {[llength $metaFile]} {
        set pStr [open $metaFile r]
        while {[gets $pStr savedValue] != -1} {
            #ShowMessage debug info "Restoring $savedValue" ok
            set IdAndValue [split $savedValue =]
            set restoredComp [RestoreCrs [lindex $IdAndValue 0]]
            #ShowMessage debug info "Component is $restoredComp, looking in [winfo children .fpdialogue.sliderframe]" ok
            if {[info exists paramData($restoredComp)]} {
                set paramData($restoredComp) [lindex $IdAndValue 1]
                #ShowMessage debug info "Param data is $paramData($restoredComp)" ok
                set FileOrVal [lindex $paramData($restoredComp) 0]
                
                # OK here we go...try and follow this...first go to the starting point..
                cd [file dirname $metaFile]
                if {[file exists $FileOrVal]} {
                    # Now use the saved relative path to move to the .csv file's directory
                    cd [file dirname $FileOrVal]
                    # ...and stick the new absolute pathname into the spec! Easy!!
                    set paramState($restoredComp) \
                            [concat [list [pwd]/[file tail $FileOrVal]] \
                            [lrange $paramData($restoredComp) 1 end]]
                    # now just load up the data
                    #ShowMessage debug info "Field spec set to $paramState($restoredComp)" ok
                    set paramData($restoredComp) \
                            [LoadTableData $paramState($restoredComp) 0]
                } elseif {![SensibleValue $FileOrVal]} {
                    set paramData($restoredComp) {}
                    ShowMessage "Error merging parameters" error "Parameterization file contained the entry $FileOrVal for component $restoredComp. This entry is not the name of an existing file, nor is it a sensible value for a Simile component." ok
                }
                $widgetNames($restoredComp) delete 1.0 end
                $widgetNames($restoredComp) insert 1.0 $paramData($restoredComp)
            }
        }
        close $pStr
        
    }
    cd $oldDir
}

# This tests for sensible model values.
# 0: not sensible

# 1: an integer
# 2: a float
# 3: a list

proc SensibleValue {list} {
    if {[llength $list]==1} {
        return [VarType $list]
    } else {
        for {set idx 0} {$idx < [llength $list]} {incr idx 2} {
            if {[VarType [lindex $list $idx]] != 1 || \
                        ![SensibleValue [lindex $list [expr $idx+1]]]} {
                return 0
            }
        }
        return 3
    }
}

# useful proc which returns 1 for an int, 2 for a float and 0 for all else

proc VarType {testVar} {
    if {[scan $testVar {%d %s} number spare]==1} {
        return 1
    } elseif {[scan $testVar {%f %s} number spare]==1} {
        return 2
    } else {
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
    global paramState paramData widgetNames equation table_entry
    set equation(table_data) {}
    
    if {[equationDoTable $parent]} {
        
        set paramState($compName) \
                [concat [list $table_entry(fileName) $table_entry(dataField)] \
                $table_entry(indices)]
        set paramData($compName) [LoadTableData $paramState($compName) 0]
        $widgetNames($compName) delete 1.0 end
        $widgetNames($compName) insert 1.0 $paramData($compName)
    }
}

proc LoadTableData {tableSpec doQuoting} {
    
#ShowMessage debug info "Loading table with data $tableSpec" ok
    set tStr [open [lindex $tableSpec 0] r]
    gets $tStr headerLine
    set headerList [split $headerLine ,]
#ShowMessage debug info "Headers are $headerList" ok
    
    set indexCount 0
    set lineCount 0
    set maxIndices(0) 0
    foreach headerIndex [lrange $tableSpec 2 end] {
        lappend indexColumns [lsearch $headerList $headerIndex]
        set maxIndices($indexCount) {}
        incr indexCount
    }
    set headerColumn [lsearch $headerList [lindex $tableSpec 1]]
#ShowMessage debug info "Columns: header $headerColumn" ok
    
    while {[gets $tStr entryLine] != -1} {
        set entryList [split $entryLine ,]
#ShowMessage debug info "Data line is $entryList" ok
        
        if {[info exists indexColumns]} {
            set arrayIndex {}
            set indexCount 0
            foreach column $indexColumns {
                set newIndex [lindex $entryList $column]
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
                [lindex $entryList $headerColumn]
    }
    
    for {set idxIdx 0} {$idxIdx < $indexCount} {incr idxIdx} {
        lappend indexList $maxIndices($idxIdx)
    }
    
#ShowMessage debug info "Converting [array get paramArray] with $indexList" ok
    close $tStr
    return [ArrayToList paramArray top $indexList $doQuoting]
}

proc ArrayToList {topArray indexSoFar otherMaxes doQuoting} {
#ShowMessage debug info "$indexSoFar $otherMaxes" ok
    upvar 1 $topArray array
    if {[llength $otherMaxes]} {
        foreach pt [lindex $otherMaxes 0] {
            lappend result [QuoteNonNumeric $pt $doQuoting] \
		[ArrayToList array $indexSoFar,$pt \
		     [lrange $otherMaxes 1 end] $doQuoting]
        }
    } else {
        if {[info exists array($indexSoFar)]} {
	    set result [QuoteNonNumeric $array($indexSoFar) $doQuoting]
        } else {
            set result 0
        }
    }
    return $result
}

proc QuoteNonNumeric {val doIt} {
    if {$doIt && [catch {expr 1*$val}]} {
	return \"$val\"
    } else {
	return $val
    }
}
