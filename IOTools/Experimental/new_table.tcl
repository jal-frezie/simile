package require Tktable

set keyValue tabular11509

namespace eval tabular11509 {
    variable tableVars
    variable precision 4

    proc identify {} {
	return "Widget-based data table"
    }

    proc initialize {winId} {
	variable tableVars

	set toolbarItems [list \
            [list new.gif "Clear" [namespace code "clear $winId"] ] \
            [list add.gif "Add a variable" \
		 [namespace code "AddVariable $winId"]] \
	    [list mprec.gif "Increase precision" \
		 [namespace code [list ChangePrecision 1]]] \
	    [list lprec.gif "Decrease precision" \
		 [namespace code [list ChangePrecision -1]]]]

	::graphtools::MakeToolBar $winId $toolbarItems

	scrollbar $winId.sy -command [list $winId.t yview]
	scrollbar $winId.sx -command [list $winId.t xview] \
	    -orient horizontal

	pack [frame $winId.f] ;# for instructions
	pack $winId.sx -side bottom -fill x -expand true
	pack $winId.sy -side right -fill y -expand true
	CreateTable $winId
    }

    proc clear {winId} {
	set curVars [ListCurVars $winId]
	destroy $winId.t
	CreateTable $winId
	
	foreach caption $curVars {
	    set newCol [$winId.t cget -cols]
	    $winId.t configure -cols [expr $newCol+1]
	    $winId.t set 0,$newCol $caption
	}
	display $winId [GetModelTime] 0 0
    }

    proc ListCurVars {winId} {
	variable headerLines

	set vars {}
	for {set col 1} {$col < [$winId.t cget -cols]} {incr col} {
	    if {[string length [$winId.t get 0,$col]]} {
		lappend vars [$winId.t get 0,$col]
	    }
	}
	return $vars
    }
	
    proc CreateTable {winId} {
	variable headerLines

	set headerLines($winId) 1
	table $winId.t -rows 1 -cols 1 -bg \#a0a0ff -variable data$winId \
	    -titlerows 1 -titlecols 1 -selectmode extended -sparsearray 0 \
	    -rowtagcommand [namespace code rowProc] \
	    -coltagcommand [namespace code colProc] \
	    -rowseparator \n -colseparator \t \
	    -yscrollcommand [list $winId.sy set] \
	    -xscrollcommand [list $winId.sx set]
    
	pack $winId.t -fill both -expand true

	$winId.t set 0,0 Time
	$winId.t tag cell base 0,0
	$winId.t tag raise base
	$winId.t tag config base -fg black
	$winId.t tag config title -relief raised
	$winId.t tag config OddRow -bg \#e0e0ff
	$winId.t tag config OddCol -bg \#c0c0ff
    }

    proc AddVariable { winId } {
	pack [label $winId.f.mess -text "Click on a variable in the Explorer window\ or a Model Diagram."]
	GrabClicks $winId
    }

    proc click {winId node caption} {
	variable tableVars

	set newHeader [GetCaptionPathFromId $node]
	set newCol [$winId.t cget -cols]
	$winId.t configure -cols [expr $newCol+1]
#	$winId.t width $newCol [string length $newHeader]
	$winId.t set 0,$newCol $newHeader
	destroy $winId.f.mess
	ReleaseClicks $winId

# Insert values for current time
	set varVal [lindex [GetModelValue $node] 0]
	set fillRow [InsertTime $winId [GetModelTime]]
	InsertVals $winId $varVal $fillRow $newCol
    }

    proc display {winId tCur tStep tRem} {
	variable headerLines

	# spans do not get pushed by new columns so clear them all first
	for {set cPt 1} {$cPt < [$winId.t cget -cols]} {incr cPt} {
	    for {set rPt 0} {$rPt < $headerLines($winId)} {incr rPt} {
		$winId.t spans $rPt,$cPt 0,0
	    }
	}

	set fillRow [InsertTime $winId $tCur]
	set fillCol 1 
	while {$fillCol < [$winId.t cget -cols]} {
	    set varCapt [$winId.t get 0,$fillCol]
	    if {[string length $varCapt]} {
		set varId [GetIdFromCaptionPath $varCapt]
		set varVal [lindex [GetModelValue $varId] 0]
		set fillCol [InsertVals $winId $varVal $fillRow $fillCol]
	    } else {
		incr fillCol
	    }
	}
    }

    proc InsertTime {winId tCur} {
	variable headerLines

	set curHt [$winId.t cget -rows]
#puts "InsertTime: headerLines $headerLines($winId) curHt $curHt tCur $tCur"
	set rowVal -1
	for {set fillRow $headerLines($winId)} {$fillRow < $curHt} \
	    {incr fillRow} {
		set rowVal [$winId.t get $fillRow,0]
		if {$rowVal >= $tCur} {
		    break
		}
	    }

	if {$rowVal != $tCur} {
	    $winId.t insert rows -- [expr $fillRow-1]
	}
	$winId.t set $fillRow,0 $tCur
	return [expr $fillRow-$headerLines($winId)]
    }

    proc InsertVals {winId varVal fillRow args} {
	variable headerLines
#puts "InsertVals $winId $varVal $fillRow $args"
	set fillPt [lindex $args end]
	set hLevel [llength $args]
	if {[llength $varVal] == 1} {
	    $winId.t set [expr $fillRow+$headerLines($winId)],$fillPt \
                [VarPrecRender $varVal]
	    # luxury extra -- fill out headers and span down over spare lines
	    set headerPt [expr $hLevel-1],$fillPt
	    $winId.t spans $headerPt [expr $headerLines($winId)-$hLevel],0
	    set headerSize [string length [$winId.t get $headerPt]]
	    if {$headerSize>10} {
		$winId.t width $fillPt $headerSize
	    }
	    incr fillPt
	} else {
	    if {$hLevel == $headerLines($winId)} {
		$winId.t insert rows [expr $hLevel-1]
		incr headerLines($winId)
		$winId.t configure -titlerows $headerLines($winId)
		$winId.t spans 0,0 $hLevel,0
	    }
	   
	    set startPt $fillPt
	    foreach {index value} $varVal {
		while {[skipCol $winId $index $startPt $fillPt $hLevel]} {
		    $winId.t spans $hLevel,$fillPt \
			[expr $headerLines($winId)-$hLevel-1],0
		    $winId.t set [expr $fillRow+$headerLines($winId)],$fillPt \
			{}
		    incr fillPt
		}
		set fillPt [eval {InsertVals $winId $value $fillRow} \
				$args {$fillPt}]
	    }
	    # now put blank in any remaining slots at this level
	    while {[skipCol $winId end  $startPt $fillPt $hLevel]} {
		$winId.t set [expr $fillRow+$headerLines($winId)],$fillPt {}
		incr fillPt
	    }

	    # grow header cell above to cover all cols
	    $winId.t spans [expr $hLevel-1],$startPt \
		0,[expr $fillPt-$startPt-1]
	}
	return $fillPt
    }

    proc skipCol {winId index startPt fillPt hLevel} {
	set prevHeader [$winId.t get [expr $hLevel-1],$fillPt]
	if {$fillPt >= [$winId.t cget -cols] || \
		$fillPt > $startPt && [string length $prevHeader]} {
# finished our space so make new column
	    if {[string match end $index]} {
		return 0
	    }
	    InsertCol $winId $fillPt
	}
	if {[string match end $index]} {
	    return 1
	}
	set curHeader [$winId.t get $hLevel,$fillPt]
	if {[string length $curHeader]} {
	    # make comparison work for multi-elt indices
	    if {$curHeader < $index} {
		return 1
	    } elseif {$curHeader == $index} {
		return 0
	    } else {
		InsertCol $winId $fillPt
		if {$startPt==$fillPt} {
		    # Yeep, inserted a new col @ start -- move headers left
		    for {set hiLevel [expr $hLevel-1]} {$hiLevel >= 0} \
			{incr hiLevel -1} {
			    $winId.t set $hiLevel,$fillPt \
				[$winId.t get $hiLevel,[expr $fillPt+1]]
			    $winId.t set $hiLevel,[expr $fillPt+1] {}
			}
		}
	    }
	}
	$winId.t set $hLevel,$fillPt $index
	return 0
    }

    proc InsertCol {winId fillPt} {
	$winId.t insert cols [expr $fillPt-1]
    }

    proc rowProc row { if {$row>0 && $row%2} { return OddRow } }
    proc colProc col { if {$col>0 && $col%2} { return OddCol } }

    proc ChangePrecision {diff} {
	variable precision
	incr precision $diff
	if {$precision<3} {
	    set precision 3
	}
    }
    
    proc VarPrecRender {val} {
	variable precision
	set regular [format %.${precision}f $val]
	set scientific [format %.${precision}e $val]
	set shortSci [format %.[expr $precision-3]e $val]
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

} ;# end of namespace

