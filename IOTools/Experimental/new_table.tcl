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
	$winId.t tag cell base @0,0
	$winId.t tag raise base
	$winId.t tag config base -fg black
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
	$winId.t width $newCol [string length $newHeader]
	$winId.t set 0,$newCol $newHeader
	destroy $winId.f.mess
    }

    proc display {winId tCur tStep tRem} {

	set curHt [$winId.t cget -rows]
	set rowVal -1
	for {set fillRow 1} {$fillRow < $curHt} {incr fillRow} {
	    set rowVal [$winId.t get $fillRow,0]
	    if {$rowVal >= $tCur} {
		break
	    }
	}

	if {$rowVal != $tCur} {
	    $winId.t insert rows [expr $fillRow-1]
	}
	$winId.t set $fillRow,0 $tCur
	    
	for {set fillCol 1} {$fillCol < [$winId.t cget -cols]} {incr fillCol} {
	    set varCapt [$winId.t get 0,$fillCol]
	    set varId [GetIdFromCaptionPath $varCapt]
	    set varVal [lindex [GetModelValue $varId] 0]
	    $winId.t set $fillRow,$fillCol [VarPrecRender $varVal]
	}
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

