package require Tktable

set keyValue tabular11509

namespace eval tabular11509 {

    proc identify {} {
	return "Widget-based data table"
    }

    proc initialize {winId} {
	variable precision
	set precision($winId) 4
	variable orientList
	set orientList($winId) {rows cols cols cols}

	set toolbarItems [list \
            [list new.gif "Clear" [namespace code "clear $winId"] ] \
            [list add.gif "Add a variable" \
		 [namespace code "AddVariable $winId"]] \
	    [list mprec.gif "Increase precision" \
		 [namespace code [list ChangePrecision $winId 1]]] \
	    [list lprec.gif "Decrease precision" \
		 [namespace code [list ChangePrecision $winId -1]]]]

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
	set vars {}
	for {set col 1} {$col < [$winId.t cget -cols]} {incr col} {
	    if {[string length [$winId.t get 0,$col]]} {
		lappend vars [$winId.t get 0,$col]
	    }
	}
	return $vars
    }
	
    proc CreateTable {winId} {
	table $winId.t -rows 1 -cols 1 -bg \#a0a0ff -variable data$winId \
	    -titlerows 0 -titlecols 0 -selectmode extended -sparsearray 0 \
	    -rowtagcommand [namespace code rowProc] \
	    -coltagcommand [namespace code colProc] \
	    -rowseparator \n -colseparator \t \
	    -yscrollcommand [list $winId.sy set] \
	    -xscrollcommand [list $winId.sx set]
    
	pack $winId.t -fill both -expand true

#	$winId.t set 0,0 Time
#	$winId.t tag cell base 0,0
#	$winId.t tag raise base
#	$winId.t tag config base -fg black
	$winId.t tag config title -relief raised
	$winId.t tag config OddRow -bg \#e0e0ff
	$winId.t tag config OddCol -bg \#c0c0ff
    }

    proc AddVariable { winId } {
	pack [label $winId.f.mess -text "Click on a variable in the Explorer window\ or a Model Diagram."]
	GrabClicks $winId
    }

    proc click {winId node caption} {
	variable orientList

	set varOrient [lindex $orientList($winId) 0]
	set newHeader [GetCaptionPathFromId $node]

	# would like to start with 0 rows and 0 columns, failing this use the
	# 1st for the 1st variable
	if {![$winId.t cget -title[Opp $varOrient]]} {
	    set newLine 1
	} else {
	    set newLine [$winId.t cget -$varOrient]
	    $winId.t configure -$varOrient [expr $newLine+1]
	}
#	$winId.t width $newCol [string length $newHeader]
	MakeHeaderSpace $winId 0
	$winId.t set [MakeCoord $varOrient $newLine 0] $newHeader
	destroy $winId.f.mess
	ReleaseClicks $winId

# Insert values for current time
	set varVal [lindex [GetModelValue $node] 0]
#	set fillRow [InsertTime $winId [GetModelTime]]

	# temporary botch
	switch $varOrient {
	    cols {
		set fillRow 0
		set fillCol $newLine
	    } rows {
		set fillCol 0
		set fillRow [expr $newLine-[$winId.t cget -titlecols]]
	    } default {
		puts "No orient as $varOrient !"
	    }
	}	
	InsertVals $winId [list [GetModelTime] $varVal] $fillRow $fillCol
    }

    proc Opp {norm} {
	if {[string match cols $norm]} {
	    return rows
	} else {
	    return cols
	}
    }

    proc MakeCoord {first c0 c1} {
	if {[string match cols $first]} {
	    return $c1,$c0
	} else {
	    return $c0,$c1
	}
    }

    proc display {winId tCur tStep tRem} {

	# spans do not get pushed by new columns so clear them all first
#	for {set cPt 1} {$cPt < [$winId.t cget -cols]} {incr cPt} {
#	    for {set rPt 0} {$rPt < $headerLines($winId)} {incr rPt} {
#		$winId.t spans $rPt,$cPt 0,0
#	    }
#	}

#	set fillRow [InsertTime $winId $tCur]
	set fillRow 0
	set fillCol 0
	while {$fillCol < [$winId.t cget -cols]} {
	    set varCapt [$winId.t get 0,$fillCol]
	    if {[string length $varCapt]} {
		set varId [GetIdFromCaptionPath $varCapt]
		set varVal [lindex [GetModelValue $varId] 0]
		set fillCol [InsertVals $winId [list $tCur $varVal] \
				 $fillRow $fillCol]
	    } else {
		incr fillCol
	    }
	}
    }

    proc InsertVals {winId varVal fillRow args} {
	set headerLines [$winId.t cget -titlecols]
puts "InsertVals $winId $varVal $fillRow $args"
	set fillPt [lindex $args end]
	set hLevel [llength $args]
	if {[llength $varVal] == 1} {
	    $winId.t set [expr $fillRow+$headerLines],$fillPt \
                [VarPrecRender $winId $varVal]
	    # luxury extra -- fill out headers and span down over spare lines
	    set headerPt [expr $hLevel-1],$fillPt
	    $winId.t spans $headerPt [expr $headerLines-$hLevel],0
	    set headerSize [string length [$winId.t get $headerPt]]
	    if {$headerSize>10} {
		$winId.t width $fillPt $headerSize
	    }
	    incr fillPt
	} else {
	    MakeHeaderSpace $winId $hLevel
	   
	    set startPt $fillPt
	    $winId.t spans [expr $hLevel-1],$startPt 0,0
	    foreach {index value} $varVal {
		while {[skipCol $winId $index $startPt $fillPt $hLevel]} {
		    if {$hLevel != 1} {
			$winId.t spans $hLevel,$fillPt \
			    [expr $headerLines-$hLevel-1],0
			$winId.t set \
			    [expr $fillRow+$headerLines],$fillPt {}
		    }
		    incr fillPt
		}
		$winId.t set $hLevel,$fillPt $index
		set fillPt [eval {InsertVals $winId $value $fillRow} \
				$args {$fillPt}]
	    }
	    # now put blank in any remaining slots at this level
	    while {[skipCol $winId end  $startPt $fillPt $hLevel]} {
		if {$hLevel != 1} {
		    $winId.t set [expr $fillRow+$headerLines],$fillPt {}
		}
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
	    return 0
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
		return 0
	    }
	}
# do not claim empty headers
# well, only if at starting col
	return [expr $fillPt>$startPt]
    }

    proc  MakeHeaderSpace {winId hLevel} {
	variable orientList

	set fieldOrient [lindex $orientList($winId) $hLevel]
	set headerOrient [Opp $fieldOrient]

	set hCount [$winId.t cget -title$headerOrient]
	if {$hLevel == $hCount+[$winId.t cget -title$fieldOrient]} {
	    $winId.t insert $headerOrient $hCount -1
	    $winId.t configure -title$headerOrient [expr $hCount+1]
	}
    }

    proc InsertCol {winId fillPt} {
	$winId.t insert cols [expr $fillPt-1]
	# now do what the bloody thing ought to do for me with the spans
	for {set c [expr [$winId.t cget -cols]-1]} {$c > $fillPt} \
	        {incr c -1} {
		    for {set r 0} {$r < [$winId.t cget -titlecols]} {incr r} {
		set span [$winId.t spans $r,[expr $c-1]]
		if {[string length $span]} {
		    $winId.t spans $r,[expr $c-1] 0,0
		    $winId.t spans $r,$c $span
		}
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
	}
    }
    
    proc VarPrecRender {winId val} {
	variable precision
	set prec $precision($winId)
	set regular [format %.${prec}f $val]
	set scientific [format %.${prec}e $val]
	set shortSci [format %.[expr $prec-3]e $val]
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

