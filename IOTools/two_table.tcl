package require Tktable

set keyValue tabular11510

namespace eval tabular11510 {

    proc identify {} {
	return "Storing data table"
    }

    proc initialize {winId} {
	variable precision
	set precision($winId) 4
	variable orientList
	set orientList($winId) {rows cols cols cols}
	variable displayList
	set displayList($winId) {}
	variable lastDisplay
	set lastDisplay($winId) 0.0

	menu $winId.tablevars -tearoff 0 -postcommand \
	    [namespace code [list AddVars $winId]]

	set toolbarItems [list \
            [list clear.gif "Clear" [namespace code "clear $winId"] ] \
            [list add.gif "Add a variable" \
		 [namespace code "AddVariable $winId"]] \
            [list remove.gif "Remove a variable" \
		 [namespace code "RemoveVariable $winId"]] \
	    [list mprec.gif "Increase precision" \
		 [namespace code [list ChangePrecision $winId 1]]] \
	    [list lprec.gif "Decrease precision" \
		 [namespace code [list ChangePrecision $winId -1]]] \
            [list property.gif "Layout" [namespace code "Layout $winId"] ]]

	if {![string match .viewer $winId]} {
	    ::graphtools::MakeToolBar $winId $toolbarItems
	}

	scrollbar $winId.yscroll -command [list $winId.t yview]
	scrollbar $winId.xscroll -command [list $winId.t xview] \
	    -orient horizontal

	pack [frame $winId.f] -fill both
	pack [label $winId.f.mess] ;# for instructions
	pack $winId.xscroll -side bottom -fill x
	pack $winId.yscroll -side right -fill y
	CreateTable $winId
	clear $winId ;# cos MRE can re-use same frame
	SaveState $winId
    }

    proc CreateTable {winId} {
	table $winId.t -rows 1 -cols 1 -bg \#a0ffa0 -variable data$winId \
	    -selectmode extended -sparsearray 0 \
	    -rowtagcommand [namespace code rowProc] \
	    -coltagcommand [namespace code colProc] \
	    -rowseparator \n -colseparator \t \
	    -yscrollcommand [list AdjustCanvas $winId t y] \
	    -xscrollcommand [list AdjustCanvas $winId f x]
	pack $winId.t -fill both -expand true

#	$winId.t set 0,0 Time
#	$winId.t tag cell base 0,0
#	$winId.t tag raise base
#	$winId.t tag config base -fg black
	$winId.t tag config title -relief raised
	$winId.t tag config OddRow -bg \#e0ffe0
	$winId.t tag config OddCol -bg \#c0ffc0
    }

    proc Restore {winId} {
	variable displayList
	variable orientList
	variable precision
	set oldState [GetState $winId]
	initialize $winId
	set displayList($winId) [lindex $oldState 0]
	set orientList($winId) [lindex $oldState 1]
	set precision($winId) [lindex $oldState 2]
	display $winId [GetModelTime] 0 0
	SaveState $winId
    }

    proc SaveState {winId} {
	variable displayList
	variable orientList
	variable precision
	SetState $winId [list $displayList($winId) $orientList($winId) \
			    $precision($winId)]
    }

    proc AddVariable { winId } {
	$winId.f.mess config -text "Click on a variable in the Explorer window or a Model Diagram."
	GrabClicks $winId
    }

    proc RemoveVariable { winId } {
	tk_popup $winId.tablevars \
	    [winfo pointerx $winId] [winfo pointery $winId]
    }

    proc AddVars {winId} {
	variable displayList
	$winId.tablevars delete 0 end
	foreach var $displayList($winId) {
	    if {[llength $var]} {
		$winId.tablevars add command -label $var \
		    -command [namespace code [list Remove $winId $var]]
	    }
	}
    }

    proc Remove {winId var} {
	variable displayList
	variable dataStore
	variable orientList

	set ind [lsearch $displayList($winId) $var]
	set displayList($winId) [lreplace $displayList($winId) $ind $ind {}]
	foreach entry [array names dataStore $winId,$ind,*] {
	    unset dataStore($entry)
	}
	set xScrollPosn [$winId.t xview]
	set yScrollPosn [$winId.t yview]
	Reconbobulate $winId
	switch [lindex $orientList($winId) 1] {
	    rows {
		$winId.t xview moveto [lindex $xScrollPosn 0]
	    } cols {
		$winId.t yview moveto [lindex $yScrollPosn 0]
	    }
	}
    }

    proc click {winId node caption} {
	variable dataStore
	variable displayList
	variable lastDisplay
	variable orientList
	variable varNamePosns

	ReleaseClicks $winId
	$winId.f.mess config -text {}
	set newHeader [GetCaptionPathFromId $node]
	set varIndex [lsearch $displayList($winId) $newHeader]
	set xScrollPosn [$winId.t xview]
	set yScrollPosn [$winId.t yview]
	if {$varIndex<0} {
	    set varIndex [llength $displayList($winId)]
	    lappend displayList($winId) $newHeader
	    if {[GetModelTime]==$lastDisplay($winId)} {
		set dataStore($winId,$varIndex,$lastDisplay($winId)) \
		    [lindex [GetModelValue $node] 0]
		Reconbobulate $winId
	    }
	    SaveState $winId
	}
#puts "vi $varIndex"
	set lineToSee [lindex $varNamePosns($winId) $varIndex]
	if {[llength $lineToSee]} {
#puts $lineToSee
	    switch [lindex $orientList($winId) 1] {
		rows {
		    $winId.t see $lineToSee,0
		    $winId.t xview moveto [lindex $xScrollPosn 0]
		} cols {
		    $winId.t see 0,$lineToSee
		    $winId.t yview moveto [lindex $yScrollPosn 0]
		}
	    }
	}
    }

    proc clear {winId} {
	variable dataStore
	foreach entry [array names dataStore $winId,*,*] {
	    unset dataStore($entry)
	}
	display $winId [GetModelTime] 0 0
    }

    proc display {winId tCur tStep tRem} {
	variable dataStore
	variable displayList
	variable lastDisplay
	variable orientList

	set lastDisplay($winId) $tCur
	set varIndex 0
	foreach varCapt $displayList($winId) {
	    if {[llength $varCapt]} { ;# check not deleted
		set varId [GetIdFromCaptionPath $varCapt]
		set dataStore($winId,$varIndex,$tCur) \
					  [lindex [GetModelValue $varId] 0]
	    }
	    incr varIndex
	}
	set xScrollPosn [$winId.t xview]
	set yScrollPosn [$winId.t yview]
	Reconbobulate $winId
	switch [lindex $orientList($winId) 0] {
	    rows {
		$winId.t xview moveto [lindex $xScrollPosn 0]
	    } cols {
		$winId.t yview moveto [lindex $yScrollPosn 0]
	    } none {
		$winId.t xview moveto [lindex $xScrollPosn 0]
		$winId.t yview moveto [lindex $yScrollPosn 0]
	    }
	}
    }
	
    proc Reconbobulate {winId} {
	variable dataStore
	variable orientList
	variable displayList
	variable lastDisplay
	variable varNamePosns

	variable values
	variable rowNames
	variable colNames
	if {[info exists rowNames]} {unset rowNames}
	if {[info exists colNames]} {unset colNames}
	if {[info exists values]} {unset values}

	foreach valId [array names dataStore] {
	    set valDims [split $valId ,]
	    if {[string match $winId [lindex $valDims 0]]} {
		if {[string match none [lindex $orientList($winId) 0]]} {
		    if {[lindex $valDims 2]==$lastDisplay($winId)} {
			GrabIndices $winId 1 {} {} [lindex $valDims 1] \
			    $dataStore($valId)
		    }
		} else {
		    GrabIndices $winId 0 {} {} [lindex $valDims 2] \
			[list [lindex $valDims 1] $dataStore($valId)]
		}
	    }
	}
#puts "Data transferred to 2-d table mirror array"

        set curHeaderRows 0
	set colList [lsort -command [namespace code ReComp] \
			 [array names colNames]]
	foreach item $colList {
	    set len [llength $item]
	    if {$len>$curHeaderRows} {
		set curHeaderRows $len
	    }
	}

	set curHeaderCols 0
	set rowList [lsort -command [namespace code ReComp] \
			 [array names rowNames]]
	foreach item $rowList {
	    set len [llength $item]
	    if {$len>$curHeaderCols} {
		set curHeaderCols $len
	    }
	}
	set levels [expr $curHeaderRows+$curHeaderCols]
	if {!$curHeaderRows} {set curHeaderRows 1}
	if {!$curHeaderCols} {set curHeaderCols 1}

#puts "Header rows and columns counted"

	unset ::data$winId
	foreach {span old} [$winId.t spans] {
	    $winId.t spans $span 0,0
	}
	$winId.t config -rows $curHeaderRows -cols $curHeaderCols \
	    -titlerows $curHeaderRows -titlecols $curHeaderCols
	set rowsTop 0
	set colsTop 0
	set hideTime [string match none [lindex $orientList($winId) 0]]
	set level $hideTime
	while {$level-$hideTime < $levels} {
	    switch $level {
		0 {set topCapt Time}
		1 {set topCapt Name}
		default {set topCapt "Index [expr $level-1]"}
	    }
	
	    if {$level<4} {set orient [lindex $orientList($winId) $level]}
	    if {[string match rows $orient]} {
		set tgtSq [expr $curHeaderRows-1],$rowsTop
		set oldCapt [$winId.t get $tgtSq]
		if {[llength $oldCapt]} {
		    $winId.t set $tgtSq "$topCapt \\ $oldCapt"
		} else {
		    $winId.t set $tgtSq $topCapt
		}
		incr rowsTop
	    } else {
		set tgtSq $colsTop,[expr $curHeaderCols-1]
		set oldCapt [$winId.t get $tgtSq]
		if {[llength $oldCapt]} {
		    $winId.t set $tgtSq "$oldCapt \\ $topCapt"
		} else {
		    $winId.t set $tgtSq $topCapt
		}
		incr colsTop
	    }
	    $winId.t tag cell base $tgtSq
	    incr level
	}
	if {[info exists tgtSq]} {
	    set rcolWidth [string length [$winId.t get $tgtSq]]
	    if {$rcolWidth>10} {
		$winId.t width [expr $curHeaderCols-1] $rcolWidth
	    }
	    $winId.t tag raise base
	    $winId.t tag config base -fg black
	}
	if {$curHeaderRows>1 && $curHeaderCols>1} {
	    $winId.t spans 0,0 [expr $curHeaderRows-2],[expr $curHeaderCols-2]
	}
#puts "Meta-headers inserted"
	set timeSide [lindex $orientList($winId) 0]
	set lineToShow 0
	set translateSide [lindex $orientList($winId) 1]
	set translateLevel [string match $translateSide \
				[lindex $orientList($winId) 0]]
	set timeToShow [GetModelTime]
	set varNamePosns($winId) {}
    
	set lastEntry(0) none
	set count $curHeaderRows
	foreach item $rowList {
	    set rowIds($item) $count
	    $winId.t insert rows end

	    set headerCol 0
	    foreach headerElt $item {
		if {[string match $headerElt $lastEntry($headerCol)]} {
		    # header same as prev line so span it over
		    $winId.t spans $lastLine($headerCol),$headerCol \
			[expr $count-$lastLine($headerCol)],0
		} else {
		    set lastEntry($headerCol) $headerElt
		    set lastEntry([expr $headerCol+1]) none
		    set lastLine($headerCol) $count
		    if {[string match rows $translateSide] && \
			    $headerCol==$translateLevel} {
			set headerElt [lindex $displayList($winId) $headerElt]
			if {!$headerCol} {
			    lappend varNamePosns($winId) $count
			}
		    }
		    if {!$headerCol && [string match rows $timeSide] && \
			    $headerElt==$timeToShow} {
			set lineToShow $count
		    }
		    $winId.t set $count,$headerCol \
			[lindex [split $headerElt /] end]
		}
		incr headerCol
	    }
	    incr count
	}
#puts "Column headers inserted"
	set lastEntry(0) none
	set count $curHeaderCols
	foreach item $colList {
	    set colIds($item) $count
	    $winId.t insert cols end

	    set headerRow 0
	    foreach headerElt $item {
		if {[string match $headerElt $lastEntry($headerRow)]} {
		    # header same as prev line so span it over
		    $winId.t spans $headerRow,$lastLine($headerRow) \
			0,[expr $count-$lastLine($headerRow)]
		} else {
		    set lastEntry($headerRow) $headerElt
		    set lastEntry([expr $headerRow+1]) none
		    set lastLine($headerRow) $count
		    if {[string match cols $translateSide] && \
			    $headerRow==$translateLevel} {
			set headerElt [lindex $displayList($winId) $headerElt]
			if {!$headerRow} {
			    lappend varNamePosns($winId) $count
			}
		    }
		    if {!$headerRow && [string match cols $timeSide] && \
			    $headerElt==$timeToShow} {
			set lineToShow $count
		    }
		    $winId.t set $headerRow,$count \
			[lindex [split $headerElt /] end]
		}
		incr headerRow
	    }
	    incr count
	}
#puts "vnps $varNamePosns($winId)"
#puts "row headers inserted"
	foreach value [array names values] {
	    set headers [split $value ,]
	    set rowHead $rowIds([lindex $headers 0])
	    set colHead $colIds([lindex $headers 1])
	    $winId.t set $rowHead,$colHead \
		[VarPrecRender $winId $values($value)]
	}
#puts "Table values inserted"
	switch $timeSide {
	    rows {
		$winId.t see $lineToShow,0
	    } cols {
		$winId.t see 0,$lineToShow
	    }
	}
    }

    proc ReComp {l1 l2} {
	if {[string match $l1 $l2]} {
	    return 0
	}
	if {![llength $l1]} {
	    return -1
	}
	if {![llength $l2]} {
	    return 1
	}
	if {[catch {expr ($l2<$l1)-($l2>$l1)} math]} {
	    set recurse [ReComp [lindex $l1 0] [lindex $l2 0]]
	    if {$recurse} {
		return $recurse
	    } else {
		return [ReComp [lrange $l1 1 end] [lrange $l2 1 end]]
	    }
	} else {
	    return $math
	}
    }

    proc GrabIndices {winId depth rowsList colsList index struct} {
	variable orientList
	variable values
	variable rowNames
	variable colNames

	set nextAxis [lindex $orientList($winId) $depth]
	lappend ${nextAxis}List $index
    	
	if {[llength $struct] == 1} {
	    set values($rowsList,$colsList) $struct
	    set rowNames($rowsList) {}
	    set colNames($colsList) {}
	} else {
	    if {$depth < 3} {incr depth}
	    foreach {newIndex newStruct} $struct {
		GrabIndices $winId $depth $rowsList $colsList $newIndex \
		    $newStruct
	    }
	}
    }
		
    proc rowProc row { if {$row>0 && $row%2} { return OddRow } }
    proc colProc col { if {$col>0 && $col%2} { return OddCol } }

    proc ChangePrecision {winId diff} {
	variable precision
	incr precision($winId) $diff
	if {$precision($winId)<3} {
	    set precision($winId) 3
	} else {
	    Reconbobulate $winId
	    SaveState $winId
	}
    }
    
    proc VarPrecRender {winId val} {
	variable precision
	set prec $precision($winId)
# if a c model is built with Windows math libraries, the numerical
# values might not format as floats. Watch out for this problemette
# and just return them as they are if it happens
	if {[catch {
	    set regular [format %.${prec}f $val]
	    set scientific [format %.${prec}e $val]
	    set shortSci [format %.[expr $prec-3]e $val]
	}]} { return $val }
	if {[string length $scientific]<[string length $regular]} {
	    return $scientific
	} else {
	    if {$scientific && !$regular} {
		return $shortSci
	    } else {
		return $regular
	    }
	}
    }

    proc Layout {winId} {
	variable orientList

    set t [toplevel $winId.layout]
    wm transient $t $winId
    wm title $t "Table properties"
    wm resizable $t 0 0
    set ::${t}l1 [lindex $orientList($winId) 0]
	set ::${t}l2 [lindex $orientList($winId) 1]
	set ::${t}l3 [lindex $orientList($winId) 2]
	set ::${t}l4 [lindex $orientList($winId) 3]
    
    pack [label $t.toplbl -text "For each possible dimension listed,\
            select between including it on the rows or on the columns of the table." \
            -wraplength 300] -pady 4
    
    pack [frame $t.l1]  -anchor w -padx 2 -pady 4
    pack [label $t.l1.lbl -text "Times:" -width 20] -side left  -anchor w
    pack [label $t.l1.lbl2 -text "On Rows"] -side left -anchor w
    pack [radiobutton $t.l1.rowb -variable ${t}l1 -value rows] -side left  -anchor w
    pack [label $t.l1.coll -text "On Columns"] -side left -anchor w
    pack [radiobutton $t.l1.colb -variable ${t}l1 -value cols] -side left -anchor w
    pack [label $t.l1.nonel1 -text "Current values only"] -side left -anchor w
    pack [radiobutton $t.l1.noneb -variable ${t}l1 -value none] -side left -anchor w

    pack [frame $t.l2]  -anchor w -padx 2 -pady 4
    pack [label $t.l2.lbl -text "Element names:" -width 20] -side left  -anchor w
    pack [label $t.l2.lbl2 -text "On Rows"] -side left -anchor w
    pack [radiobutton $t.l2.rowb -variable ${t}l2 -value rows] -side left  -anchor w
    pack [label $t.l2.coll -text "On Columns"] -side left  -anchor w
    pack [radiobutton $t.l2.colb -variable ${t}l2 -value cols] -side left  -anchor w

    pack [frame $t.l3]  -anchor w -padx 2 -pady 4
    pack [label $t.l3.lbl -text "First index:" -width 20] -side left  -anchor w
    pack [label $t.l3.lbl2 -text "On Rows"] -side left -anchor w
    pack [radiobutton $t.l3.rowb -variable ${t}l3 -value rows] -side left  -anchor w
    pack [label $t.l3.coll -text "On Columns"] -side left  -anchor w
    pack [radiobutton $t.l3.colb -variable ${t}l3 -value cols] -side left  -anchor w

    pack [frame $t.l4]  -anchor w -padx 2 -pady 4
    pack [label $t.l4.lbl -text "Other indices:" -width 20] -side left  -anchor w
    pack [label $t.l4.lbl2 -text "On Rows"] -side left -anchor w
    pack [radiobutton $t.l4.rowb -variable ${t}l4 -value rows] -side left  -anchor w
    pack [label $t.l4.coll -text "On Columns"] -side left -anchor w
	pack [radiobutton $t.l4.colb -variable ${t}l4 -value cols] -side left -anchor w
    
    pack [frame $t.b]  
    pack [button $t.b.ok -text OK -width 10 -command "set ${t}done 1"] \
        -side left -padx 2 -pady 4
	pack [button $t.b.cancel -text Cancel -width 10 -command "set ${t}done 0"] \
        -side left -padx 2 -pady 4

	grab $t
	tkwait variable ${t}done

	if {[set ::${t}done]} {
	    set orientList($winId) [list [set ::${t}l1] [set ::${t}l2] \
				[set ::${t}l3] [set ::${t}l4]]
	    Reconbobulate $winId
	    SaveState $winId
	}
	destroy $t
    }
} ;# end of namespace
