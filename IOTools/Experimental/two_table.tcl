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

    proc CreateTable {winId} {
	table $winId.t -rows 1 -cols 1 -bg \#a0ffa0 -variable data$winId \
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
	$winId.t tag config OddRow -bg \#e0ffe0
	$winId.t tag config OddCol -bg \#c0ffc0
    }

    proc AddVariable { winId } {
	pack [label $winId.f.mess -text "Click on a variable in the Explorer window\ or a Model Diagram."]
	GrabClicks $winId
    }

    proc click {winId node caption} {
	variable orientList
	variable dataStore
	variable displayList

	set newHeader [GetCaptionPathFromId $node]
	if {[lsearch $displayList($winId) $newHeader]>=0} {
	    # Var already displayed, see it
	} else {
	    lappend displayList($winId) $newHeader
	    set dataStore($winId,$newHeader,[GetModelTime]) \
		[lindex [GetModelValue $node] 0]
	    Reconbobulate $winId
	}
    }

    proc Reconbobulate {winId} {
	variable dataStore
	variable orientList

	variable values
	variable rowNames
	variable colNames

	$winId.t delete rows 0 [$winId.t cget -rows]
	$winId.t delete cols 0 [$winId.t cget -cols]
	set values {}; set rowNames {}; set colNames {}
	set nameAxis [lindex $orientList 0]

	foreach valId [array names dataStore] {
	    set rowsList {}
	    set colsList {}
	    set valDims [split $valId ,]
	    lappend ${nameAxis}List [lindex $valDims 1]

	    GrabIndices 1 $rowsList $colsList [lindex $valDims 2] \
		$dataStore($valId)
	}
	set count 0
	foreach item [lsort $rowNames] {
	    set rowIds($item) $count
	    incr count
	}
	$winId.t config -rows count
	set count 0
	foreach item [lsort $colNames] {
	    set colIds($item) $count
	    incr count
	}
	$winId.t config -cols count

	foreach value [array names values] {
	    set headers [split $value ,]
	    set rowHead $rowIds([lindex headers 0])
	    set colHead $colIds([lindex headers 1])
	    $winId.t set $rowHead,$colHead [VarPrecRender $values($headers)]
	}
    }

    proc GrabIndices {depth rowsList colsList index struct} {
	variable orientList

	variable values
	variable rowNames
	variable colNames

	set nextAxis [lindex orientList $depth]
	lappend ${nextAxis}List $index
	
	if {[llength $struct] == 1} {
	    set values($rowsList,$colsList) $struct
	    if {[lsearch $rowNames $rowsList]<0} {
		lappend rowNames $rowsList
	    }
	    if {[lsearch $colNames $colssList]<0} {
		lappend colNames $colsList
	    }
	} else {
	    incr depth
	    foreach {newIndex newStruct} $struct {
		GrabIndices $depth $rowsList $colsList $newIndex $newStruct
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
