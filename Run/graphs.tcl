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

    if {![info exists graph(pts)]} {
	# set default values for new graph
	GraphEntry .graph 0 100 400 100 0 400 0 21 200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200
    } else {
	GraphEntry .graph $graph(lowx) \
		$graph(highx) $graph(width) \
		$graph(lowy) $graph(highy) \
		$graph(height) $graph(range) $graph(size) \
		$graph(pts)
    }
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

proc GraphEntry { t xlow xhigh xspan ylow yhigh yspan range size points} {
    global graph
    
    regsub -all , $points " " graph(points)

    wm title $t "Sketch graph"
    
    TitleFrame $t.left -text "Graph pad"
    set left [$t.left getframe]
    frame $left.upper
    frame $left.upper.yentry
    entry $left.upper.yentry.topentry -relief sunken -textvar graph(lowy) -width 8
    pack $left.upper.yentry.topentry -side top
    label $left.upper.yentry.toplabel -text "Y max"
    pack $left.upper.yentry.toplabel -side top
    entry $left.upper.yentry.bottomentry -relief sunken -textvar graph(highy) -width 8
    pack $left.upper.yentry.bottomentry -side bottom
    label $left.upper.yentry.bottomlabel -text "Y min"
    pack $left.upper.yentry.bottomlabel -side bottom
    pack $left.upper.yentry -side left -fill y
    
    frame $left.upper.gridf
    set graph(width) $xspan
    set graph(height) $yspan
    set grid [canvas $left.upper.gridf.canvas -width $graph(width) -height $graph(height)]
    set graph(increment) [expr $graph(width)/([llength $graph(points)] - 1.0)]
    
    set graph(lowy) $ylow
    set graph(highy) $yhigh
    set graph(lowx) $xlow
    set graph(highx) $xhigh
    
    bind $grid <Button-1> "GClick %W %x %y"
    bind $grid <B1-Motion> "GDrag %W %x %y"
    bind $grid <Configure> "AttackShape %W %w %h"
    pack $grid -fill both -expand true
    pack $left.upper.gridf -fill both -expand true -side left
    pack $left.upper -fill both -expand true -side top

    frame $left.xentry
    label $left.xentry.startlabel -text " " -width 8
    pack $left.xentry.startlabel -side left
    entry $left.xentry.leftentry -relief sunken -textvar graph(lowx) -width 8
    pack $left.xentry.leftentry -side left -padx 2
    label $left.xentry.xmin -text "X min"
    pack $left.xentry.xmin -side left -padx 2
    entry $left.xentry.rightentry -relief sunken -textvar graph(highx) -width 8
    pack $left.xentry.rightentry -side right -padx 2
    label $left.xentry.rightlabel -text "X max"
    pack $left.xentry.rightlabel -side right -padx 2
    pack $left.xentry -side top -fill x
    pack $left -expand on -fill both -side left
    pack $t.left -side left -expand on -fill both -padx 2 -pady 2

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
    pack $t.right -fill both -expand true
    
    TitleFrame $t.right.options -text "Options: "
    set right [$t.right.options getframe]
    
    set out [frame $right.out]
    label $out.outrange -text "Out of range:"
    pack $out.outrange
    set rangeChoices "Truncate Extrapolate Wraparound"
    pack [ComboBox $out.rangeopts -values $rangeChoices -editable 0 -textvariable graph(rangeact) -width 12]
    set graph(rangeact) [lindex $rangeChoices $range]
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
    
    
    
    RedrawGrid $grid $graph(width) $graph(height) $graph(increment)
    
    focus $t
    grab $t
    tkwait variable graph(done)
    grab release $t
    
    if {$graph(done)} {
	# tk_messageBox -message "$rangeChoices $graph(rangeact)"
	set graph(range) [lsearch $rangeChoices $graph(rangeact)]
	set graph(size) [llength $graph(points)]
	regsub -all " " $graph(points) , graph(pts)
    }
    return $graph(done)
}

proc AddLine {c section} {
	global graph

	$c delete section$section
	$c create line [expr round($graph(increment)*($section - 1))] \
		[lindex $graph(points) [expr $section - 1]] \
		[expr round($graph(increment)*$section)] \
		[lindex $graph(points) $section] \
		-tags "graph section$section"
}

proc GClick {c x y} {
	global graph
	set zone [expr round($x/$graph(increment))]
	set graph(oldzone) $zone
	set graph(oldy) $y
	GStick $c $zone $y
}

proc YEntry {c} {
	global graph xvalue yvalue
	set zone [expr round(([llength $graph(points)]-1.0)*\
		($xvalue-$graph(lowx))/($graph(highx)-$graph(lowx)))]
	set y [expr $graph(height)*\
		($yvalue-$graph(lowy))/($graph(highy)-$graph(lowy))]
	GStick $c $zone $y
}

proc GDrag {c x y} {
	global graph

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
		GClick $c $x $y
	}
}

proc GStick {c zone y} {
	global graph xvalue yvalue

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
    global looks

	$c delete grid
	set ylevel 0
	while {$ylevel < 10} {
		set height [expr round($ylevel*($h - 4)/10.0)+1]
		$c create line 2 $height $w $height -fill $looks(darkerColor) \
			-tags grid
		set ylevel [expr $ylevel + 1]
	}
	set xlevel 0
	while {$xlevel < $w} {
		$c create line [expr round($xlevel)] 2 [expr round($xlevel)] $h \
				-fill $looks(darkerColor) -tags grid
		set xlevel [expr $xlevel + $inc]
	}
}

proc NewAttackShape {c w h} {
	global graph

	set x0 [expr $graph(width)*$graph(lowx)/($graph(lowx) - $graph(highx))]
	set y0 [expr $graph(height)*$graph(lowy)/($graph(lowy) - $graph(highy))]

	$c scale all $x0 $y0 [expr ($w - 4.0)/$graph(width)] \
			[expr ($h - 4.0)/$graph(height)]

	set $graph(width) [expr $w - 4]
	set graph(height) [expr $h - 4]
}

proc AttackShape {c w h} {
	global graph

# This version which is no longer called used to change the axis labels when the
# graph window was resized. Now we keep them the same and stretch the graph

	set graph(increment) [expr $graph(increment)*($w - 4)/$graph(width)]
	set graph(width) [expr $w - 4]

	set vchange [expr double($h - 4)/$graph(height)]
	set graph(height) [expr $h - 4]
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
        -selectmode single -dropcmd DeleteIndex]
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
            -command "set table_entry(done) 1"
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
set tbl [image create photo -file "C:/My Documents/table.gif" ]
set opn [image create photo -file "C:/My Documents/open.gif" ]
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
    set hds [split $firstLine ,]
    set i 1
    foreach hd $hds {
        $fheads.lheads insert end hd$i -text $hd
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

proc ViewTable {} {
    package require Tktable
    toplevel .viewer -bd 4
    wm transient .viewer .table
    table .viewer.t
    pack .viewer.t
}