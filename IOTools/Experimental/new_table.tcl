package require Tktable

set keyValue tabular11509

namespace eval tabular11509 {
    variable tableVars
    variable precision 4
    variable headerLines 1

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

	table $winId.t -rows 1 -cols 1 -bg \#a0a0ff -variable data$winId \
	    -titlerows 1 -titlecols 1 -selectmode extended -sparsearray 0 \
	    -rowtagcommand [namespace code rowProc] \
	    -coltagcommand [namespace code colProc] \
	    -rowseparator \n -colseparator \t \
	    -yscrollcommand [list $winId.sy set] \
	    -xscrollcommand [list $winId.sx set]
    
	scrollbar $winId.sy -command [list $winId.t yview]
	scrollbar $winId.sx -command [list $winId.t xview] \
	    -orient horizontal

	pack [frame $winId.f] ;# for instructions
	pack $winId.sx -side bottom -fill x -expand true
	pack $winId.sy -side right -fill y -expand true
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
    }

    proc display {winId tCur tStep tRem} {
	variable headerLines

	set curHt [$winId.t cget -rows]
	set rowVal -1
	for {set fillRow $headerLines} {$fillRow < $curHt} {incr fillRow} {
	    set rowVal [$winId.t get $fillRow,0]
	    if {$rowVal >= $tCur} {
		break
	    }
	}

	if {$rowVal != $tCur} {
	    $winId.t insert rows -- [expr $fillRow-1]
	}
	$winId.t set $fillRow,0 $tCur
	    
	set fillCol 1 
	while {$fillCol < [$winId.t cget -cols]} {
	    set varCapt [$winId.t get 0,$fillCol]
	    if {[string length $varCapt]} {
		set varId [GetIdFromCaptionPath $varCapt]
		set varVal [lindex [GetModelValue $varId] 0]
		set fillCol [InsertVals $winId $varVal \
				 [expr $fillRow-$headerLines] $fillCol]
	    } else {
		incr fillCol
	    }
	}
    }

    proc InsertVals {winId varVal fillRow args} {
	variable headerLines

	set fillPt [lindex $args end]
	if {[llength $varVal] == 1} {
	    $winId.t set [expr $fillRow+$headerLines],$fillPt \
                [VarPrecRender $varVal]
	    incr fillPt
	} else {
	    set hLevel [llength $args]
	    if {$hLevel == $headerLines} {
		$winId.t insert rows [expr $headerLines-1]
		$winId.t spans 0,0 $headerLines,0
		incr headerLines
		$winId.t configure -titlerows $headerLines
	    }
	   
	    set startPt $fillPt
	    $winId.t spans [expr $hLevel-1],$startPt 0,0
	    foreach {index value} $varVal {
		while {[skipCol $winId $index $startPt $fillPt $hLevel]} {
		    incr fillPt
		}
		set fillPt [eval {InsertVals $winId $value $fillRow} \
				$args {$fillPt}]
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
	    $winId.t insert cols [expr $fillPt-1]
	}
	set curHeader [$winId.t get $hLevel,$fillPt]
	if {[string length $curHeader]} {
	    # make comparison work for multi-elt indices
	    if {$curHeader < $index} {
		return 1
	    } elseif {$curHeader == $index} {
		return 0
	    } else {
		$winId.t insert cols [expr $fillPt-1]
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

