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
	while {[regexp "graph\\( *(\[^,\]*), *(\[^,\]*), *(\[^,\]*), *(\[^,\]*), *(\[^,\]*),\
 *(\[^,\]*), *(\[^,\]*), *(\[^,\]*), *points\\((\[^)\]*)\\)," \
				$formula match graph(lowx) \
				graph(highx) graph(width) \
				graph(lowy) graph(highy) \
				graph(height) graph(range) graph(size) \
				graph(pts)]} {
# next line puts backslashes before chars in match expr which would
# otherwise be special to regsub (I may not have them all)
		regsub -all \[\\(\\)\] $match \\\\\\0 match
# tk_messageBox -message $match
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
    
    frame $t.left
    entry $t.left.topentry -relief sunken -textvar graph(lowy)
    pack $t.left.topentry -fill x
    label $t.left.toplabel -text (Top)
    pack $t.left.toplabel
    
    label $t.left.startlabel -text Start: -justify right
    pack $t.left.startlabel -side bottom -fill x
    entry $t.left.bottomentry -relief sunken -textvar graph(highy)
    pack $t.left.bottomentry -side bottom -fill x
    label $t.left.bottomlabel -text (Bottom)
    pack $t.left.bottomlabel -side bottom
    
    set b [frame $t.left.buttons]
    button $b.enter -text Enter -command {set graph(done) 1}
    pack $b.enter
    button $b.cancel -text Cancel -command {set graph(done) 0}
    pack $b.cancel
    label $b.yvalue -text "Current Y value"
    pack $b.yvalue
    entry $b.yvaluebox -relief sunken -textvar yvalue
    bind $b.yvaluebox <Return> [list YEntry $t.canvas]
    pack $b.yvaluebox
    label $b.xvalue -text "Current X value"
    pack $b.xvalue
    entry $b.xvaluebox -relief sunken -textvar xvalue
    pack $b.xvaluebox
    label $b.detail -text "X axis resolution:"
    pack $b.detail
    frame $b.detailbox
    button $b.detailbox.less -text Less -command "CoarseX $t.canvas"
    pack $b.detailbox.less -side left
    button $b.detailbox.more -text More -command "FineX $t.canvas"
    pack $b.detailbox.more -side left
    pack $b.detailbox
    label $b.outrange -text "Out of range:"
    pack $b.outrange
    set rangeChoices "Truncate Extrapolate Wraparound"
    eval {tk_optionMenu $b.rangeopts graph(rangeact)} $rangeChoices
    pack $b.rangeopts
    set graph(rangeact) [lindex $rangeChoices $range]
    pack $b -side left
    
    pack $t.left -side left -fill y
    
    frame $t.bottom
    entry $t.bottom.leftentry -relief sunken -textvar graph(lowx)
    pack $t.bottom.leftentry -side left
    entry $t.bottom.rightentry -relief sunken -textvar graph(highx)
    pack $t.bottom.rightentry -side right
    label $t.bottom.rightlabel -text End:
    pack $t.bottom.rightlabel -side right
    pack $t.bottom -side bottom -fill x
    
    set graph(width) $xspan
    # was [expr round($graph(increment)*([llength $graph(points)] - 1))]
    set graph(height) $yspan
    #	set cwidth [expr $graph(width)>400?$graph(width):400]
    canvas $t.canvas -width $graph(width) -height $graph(height)
    set graph(increment) [expr $graph(width)/([llength $graph(points)] - 1.0)]
    
    set graph(lowy) $ylow
    set graph(highy) $yhigh
    set graph(lowx) $xlow
    set graph(highx) $xhigh
    
    bind $t.canvas <Button-1> "GClick %W %x %y"
    bind $t.canvas <B1-Motion> "GDrag %W %x %y"
    bind $t.canvas <Configure> "AttackShape %W %w %h"
    pack $t.canvas -fill both -expand true
    
    RedrawGrid $t.canvas $graph(width) $graph(height) $graph(increment)
    
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
    pack [set t [frame .table.headerlist]] -side left -fill both -expand true
    pack [message $t.info -text "Column headings: click to add to indices, doubleclick to select data column"]

    set lbf [listbox $t.flist \
	    -yscrollcommand [list $t.scrollf set]]
    scrollbar $t.scrollf -command [list $lbf yview]
    
    pack $t.flist -side left -fill both
    pack $t.scrollf -side left -fill y
    bind $t.flist <Button-1> "selectIndex %W %y"
    bind $t.flist <Double-1> "selectData %W %y"

    pack [set t [frame .table.others]] -side left -fill both -expand true
    pack [message $t.info -text "Current indices: click to remove. If none selected, row number will be used."]
    pack [set t [frame $t.indices]] -fill both -expand true
    set lbf [listbox $t.flist \
	    -yscrollcommand [list $t.scrollf set]]
    scrollbar $t.scrollf -command [list $lbf yview]
    
    pack $t.flist -side left -fill both
    pack $t.scrollf -side left -fill y
    bind $t.flist <Double-1> "deleteIndex %W %y"
    eval {$t.flist insert end} $table_entry(indices)
    set t .table.others
    pack [message $t.info2 -text "Column header of data field"] -fill x -expand true
    pack [entry $t.indicator2 -textvariable table_entry(dataField)]
    pack [message $t.info3 -text "Data file:"] -fill x -expand true
    pack [entry $t.indicator3 -textvariable table_entry(fileName)]
    pack [set t [frame $t.buttons]] -fill both -expand true
    pack [button $t.newfile -text "New file" \
	    -command {GetDataFile "Select new data file"; LoadDataFile}] -side left
    pack [button $t.ok -text "OK" -command "set table_entry(done) 1"] \
	    -side left
    pack [button $t.cancel -text "Cancel" -command "set table_entry(done) 0"] \
	    -side left

    set t .table
    tkwait visibility .table
    if {![LoadDataFile]} {
	return 0
    }

    focus $t
    grab $t
    tkwait variable table_entry(done)
    grab release $t
    set table_entry(indices) [.table.others.indices.flist get 0 end]
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
    .table.headerlist.flist delete 0 end

    while {[catch {open $table_entry(fileName) r} stream]} {
	if {![string compare \
	    [GetDataFile "Cannot read file $table_entry(fileName)"] {}]} {
		destroy .table
		return 0
	}
    }
    gets $stream firstLine
    eval {.table.headerlist.flist insert end} [split $firstLine ,]
    close $stream
	return 1
}

proc selectIndex {src y} {
    set index [$src get [$src nearest $y]]
    set t .table.others.indices.flist
    set match [lsearch -exact $index [$t get 0 end]]
    if {$match != -1} {
	$t delete $match
    }
    $t insert end $index
}

proc deleteIndex {src y} {
    $src delete [$src nearest $y]
}

proc selectData {src y} {
    set index [$src get [$src nearest $y]]
# undo effects of first click of pair
    .table.others.indices.flist delete end
    .table.others.indicator2 delete 0 end
    .table.others.indicator2 insert end $index
}
