package require Tktable

# this is copied from the Tktable 2.9 distribution but has extra bit to call
# the validatecommand each time a cell is changed
proc ::tk_tablePasteHandler {w cell data} {
    #
    # Don't allow pasting into the title cells
    #
    if {[$w tag includes title $cell]} {
        return
    }

    set rows	[expr {[$w cget -rows]-[$w cget -roworigin]}]
    set cols	[expr {[$w cget -cols]-[$w cget -colorigin]}]
    set r	[$w index $cell row]
    set c	[$w index $cell col]
    set rsep	[$w cget -rowseparator]
    set csep	[$w cget -colseparator]

# new bit:
    set vldCmdTplt [regsub -all {([^%])%W} [$w cget -validatecommand] \\1$w]
# end of new bit
    ## Assume separate rows are split by row separator if specified
    ## If you were to want multi-character row separators, you would need:
    # regsub -all $rsep $data <newline> data
    # set data [join $data <newline>]
    if {[string compare {} $rsep]} { set data [split $data $rsep] }
    set row	$r
    foreach line $data {
	if {$row > $rows} break
# new bit:
	set vldCmdRow [regsub -all {([^%])%r} $vldCmdTplt \\1$row]
# end of new bit
	set col	$c
	## Assume separate cols are split by col separator if specified
	## Unless a -separator was specified
	if {[string compare {} $csep]} { set line [split $line $csep] }
	## If you were to want multi-character col separators, you would need:
	# regsub -all $csep $line <newline> line
	# set line [join $line <newline>]
	foreach item $line {
	    if {$col > $cols} break
# new bit: 
	    set oldTxt [$w get $row,$col]
	    if {![string equal $item $oldTxt]} {
		set vldCmd [regsub -all {([^%])%c} $vldCmdRow \\1$col]
		set vldCmd [regsub -all {([^%])%s} $vldCmd \\1$oldTxt]
		set vldCmd [regsub -all {([^%])%S} $vldCmd \\1$item]
		set vldCmd [regsub -all %% $vldCmd %]
		if {![eval $vldCmd]} {
		    incr col
		    continue ;# skip update
		}
	    }
# end of new bit
	    $w set $row,$col $item
	    incr col
	}
	incr row
    }
}

set keyValue tabular11510

# column widths
# format by column (or row)

global tcl_platform
################################################################################
# causes some Windows 98 machines to crash on slecting variables for plotter
# if {[string match windows $tcl_platform(platform)]} {
#     source ../System/lib/Extras/prntproc.tcl
# }
################################################################################

namespace eval $keyValue {
    namespace import ::DisplayFormat::*

    variable displayFormat; # array of list $formatName $decimalplaces $ShowNegInRed
    # Lists of format names stored in the format array - array names are categories
    # PropertiesDlg uses these categorised lists to fill the list boxes
    # Format names correspond to procs of the same name that do the formatting.
    # Spaces are allowed in the format name and will be removed to compute the proc name
    # format($Category) $format
    variable format
    set format(Number) {General Fixed Scientific Percent}
    set format(Angle)  {DMS "Rad in DMS"}
    set format(Time)   { HHMM HHMMSS YYYYMMDDHHMMSS}
    set format(Date)   { YYYYMMDD YYYYMMDDHHMMSS}
    set format(Boolean) Boolean
    
    proc identify {} {
        return "Data table"
    }
    
    proc initialize {winId} {
        variable orientList
        set orientList($winId) {rows cols cols cols}
        variable displayList
        set displayList($winId,paths) {}
        set displayList($winId,ids) {}
        set displayList($winId,transes) {}
        variable lastDisplay
        set lastDisplay($winId) 0.0
        variable displayUpdate
        set displayUpdate($winId) 1
        variable displayFormat
	set displayFormat($winId,-1) {General 4 0}; # format dp Neg_in_red
        variable editMode
        
        menu $winId.formatMenu -tearoff 0 -postcommand \
                [namespace code [list AddVars $winId]]
        
        menu $winId.tablevars -tearoff 0 -postcommand \
                [namespace code [list AddVars $winId]]
        
        set toolbarItems [list \
                [list clear.gif "Clear" [namespace code "clear $winId"] ] \
                [list add.gif "Add a variable" \
                [namespace code "AddVariable $winId"]] \
                [list remove.gif "Remove a variable" \
                [namespace code "RemoveVariable $winId"]] \
                [list save.gif "Save to file" [namespace code "Save $winId"] ] \
                [list property.gif "Properties" [namespace code "PropertiesDlg $winId"] ] \
                [list refresh.gif Update [namespace code "Update $winId"]]]
        
        if {![string match .viewer $winId]} {
            ::graphtools::MakeToolBar $winId $toolbarItems
        }
        if {[info exists editMode($winId)]} {
            foreach surplus {clear add remove refresh} {
                ::graphtools::SetButtonState $winId $surplus disabled
            }
	    set editMode($winId,tweaked) 0
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
        # note the above line is not intrusive
        PrepareSaveString $winId
    }
    
    proc Update {winId} {
        set topWin [winfo toplevel $winId]
        set origCursor [$topWin cget -cursor]
        $topWin configure -cursor watch
        update
        Reconbobulate $winId
        $topWin configure -cursor $origCursor
    }
    
    proc CreateTable {winId} {
        table $winId.t -rows 1 -cols 1 -variable data$winId -bg \#a0ffa0 \
	    -selectmode extended -sparsearray 0 \
	    -rowtagcommand [namespace code rowProc] \
	    -coltagcommand [namespace code colProc] \
	    -rowseparator \n -colseparator \t \
	    -yscrollcommand [list AdjustCanvas $winId t y] \
	    -xscrollcommand [list AdjustCanvas $winId f x] \
	    -validatecommand [namespace code [list EditCellIs %W %r %c %S]] \
	    -validate 1 -selecttitle true
        
        pack $winId.t -fill both -expand true
        $winId.t tag configure red -fg red
        
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
        variable displayFormat
        variable displayUpdate
        #variable colWidths
        
        set oldState [GetState $winId]
        initialize $winId
        set displayList($winId,oldPaths) [lindex $oldState 0]
        set displayList($winId,paths) {}
        set displayList($winId,ids) {}
        set displayList($winId,transes) {}
	foreach varCapt $displayList($winId,oldPaths) {
            if {![llength $varCapt]} continue ;# check not legacy deleted
	    set sortedPath [ExistCheck [GetTopNode $winId] $varCapt {} -2 \
				"saved setup"]
	    switch $sortedPath {
		break {
		    error [tr. {Failed to initialize helper}]
		} continue {
		    continue
		} default {
		    set varCapt [lindex $sortedPath 0]
		    set id [lindex $sortedPath 1]
		}
	    }
	    lappend displayList($winId,paths) $varCapt
	    lappend displayList($winId,ids) $id
	    lappend displayList($winId,transes) [GetTransTable $id]
	}
        set orientList($winId) [lindex $oldState 1]
        foreach {id val} [lindex $oldState 2] {
            if {[string first , $id] != -1} { ;# generated by buggy version
                set id [lindex [split $id ,] 1]
            }
            set displayFormat($winId,$id) $val
        }
        set displayUpdate($winId) [lindex $oldState 3]
        if {[string match $displayUpdate($winId) {}]} {
           set displayUpdate($winId) 1
        }
        set colWidths($winId) [lindex $oldState 4]
        set rowHeights($winId) [lindex $oldState 5]
        #ShowMess debug info "colWidths" ok
        eval [list $winId.t width] [eval concat $colWidths($winId)]
        eval [list $winId.t height] [eval concat $rowHeights($winId)]
        display $winId [GetModelTime] 0 0
        PrepareSaveString $winId
    }
    
    proc PrepareSaveString {winId} {
        variable displayList
        variable orientList
        variable displayFormat
        variable editMode
        variable displayUpdate
        #variable colWidths
        
        set colWidths($winId) [$winId.t width]
        set rowHeights($winId) [$winId.t height]
        
        set clip [string length $winId,]
        set winDisplayFormat {}
        foreach {id val} [array get displayFormat $winId,*] {
            lappend winDisplayFormat [string range $id $clip end] $val
        }
        if {![info exists editMode($winId)]} {
            SetState $winId [list $displayList($winId,paths) \
				 $orientList($winId) \
				 $winDisplayFormat $displayUpdate($winId) \
				 $colWidths($winId) $rowHeights($winId)]
        }
    }
    
    proc AddVariable { winId } {
        $winId.f.mess config -text "Click on a variable in the Explorer window or a Model Diagram."
        GrabClicks $winId
    }
    
    proc RemoveVariable { winId } {
        tk_popup $winId.tablevars \
                [winfo pointerx $winId] [winfo pointery $winId]
    }
    
    proc ChangeFormat { winId } {
        tk_popup $winId.formatMenu \
                [winfo pointerx $winId] [winfo pointery $winId]
    }
    
    proc AddVars {winId} {
        variable displayList
        $winId.tablevars delete 0 end
        foreach var $displayList($winId,paths) {
            if {[llength $var]} {
                $winId.tablevars add command -label $var \
                        -command [namespace code [list Remove $winId $var]]
            }
        }
    }

# we keep the values array and update it when a cell is edited. This means
# we do not lose precision when loading the edited array.
    proc EditCellIs {t row col {newVal {}}} {
	variable editMode
	variable rowIds
	variable colIds
	variable values

	set winId [winfo parent $t]
#	if {[info exists editMode($winId,lastVal)]} {
#	    set newVal [set ::data${winId}($editMode($winId,lastRow),$editMode($winId,lastCol))]
#	    if {![string equal $editMode($winId,lastVal) $newVal]} {
	foreach rowEntry [array names rowIds $winId,*] {
	    if {$rowIds($rowEntry)==$row} {
		set rowsHeaders [lindex [split $rowEntry ,] 1]
		foreach colEntry [array names colIds $winId,*] {
		    if {$colIds($colEntry)==$col} {
			set colsHeaders [lindex [split $colEntry ,] 1]
			set values([list $rowsHeaders $colsHeaders]) $newVal
			#puts "set values($rowsHeaders,$colsHeaders) $newVal"
			set editMode($winId,tweaked) 1
		    }
		}
	    }
	}
#	    }
#	}
#	set editMode($winId,lastRow) $row
#	set editMode($winId,lastCol) $col
#	catch {set editMode($winId,lastVal) [set ::data${winId}($row,$col)]}
# catch is in case field is empty -- val will not exist
	return 1
    }
    
    proc Remove {winId var} {
        variable displayList
        variable dataStore
        variable orientList
        
        set ind [lsearch -exact $displayList($winId,paths) $var]
	set id [lindex $displayList($winId,ids) $ind]
        set displayList($winId,paths) \
	    [lreplace $displayList($winId,paths) $ind $ind]
        set displayList($winId,ids) \
	    [lreplace $displayList($winId,ids) $ind $ind]
        set displayList($winId,transes) \
	    [lreplace $displayList($winId,transes) $ind $ind]
        foreach entry [array names dataStore $winId,$id,*] {
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
        variable displayFormat
        
        ReleaseClicks $winId
        $winId.f.mess config -text {}
        set newHeader [GetCaptionPathFromId $node]
        set varIndex [lsearch -exact $displayList($winId,paths) $newHeader]
        set xScrollPosn [$winId.t xview]
        set yScrollPosn [$winId.t yview]
        if {$varIndex<0} {
            set varIndex [llength $displayList($winId,paths)]
            lappend displayList($winId,paths) $newHeader
	    set varId [GetIdFromCaptionPath $newHeader]
            lappend displayList($winId,ids) $varId
	    set trans [GetTransTable $varId]
	    lappend displayList($winId,transes) $trans
            ################################################################################
            #             #ShowMess debug info "[GetModelType $node]" ok
            #             # auto set display format doesn't work
            #             switch {[GetModelType $node]} {
            #                 INTEGER {set displayFormat($winId,$varIndex) {Fixed 0 0}}
            #                 FLAG    {set displayFormat($winId,$varIndex) {Boolean 4 0}}
            #                 default {set displayFormat($winId,$varIndex) {General 4 0}}
            #             }; # format dp Neg_in_red
            ################################################################################
            set displayFormat($winId,$varIndex) $displayFormat($winId,-1)
            if {[GetModelTime]==$lastDisplay($winId)} {
		set vals [lindex [GetModelValue $varId] 0]
		if {[llength $vals]} {
		    set dataStore($winId,$varId,$lastDisplay($winId)) \
			[TransEnums $trans $vals]
		}
            }
            Reconbobulate $winId
            PrepareSaveString $winId
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
        variable editMode
        foreach entry [array names dataStore $winId,*,*] {
            unset dataStore($entry)
        }
        if {![info exists editMode($winId)]} {
            display $winId [GetModelTime] 0 0
        }
    }
    
    proc reset {winId} {
    }
    
    proc display {winId tCur tStep tRem} {
        variable dataStore
        variable displayList
        variable lastDisplay
        variable orientList
        variable displayUpdate
	
        set lastDisplay($winId) $tCur
        set varIndex 0
	if {[string match none [lindex $orientList($winId) 0]]} {
# if displaying current values only, we do not want to keep previous values
# as they may consume very much memory (and stop headers appearing)
	    foreach entry [array names dataStore $winId,*,*] {
		unset dataStore($entry)
	    }
	}
#puts "start display at [clock milliseconds]"
        foreach varCapt $displayList($winId,paths) {
	    set varId [lindex $displayList($winId,ids) $varIndex]
	    set vals [lindex [GetModelValue $varId] 0]
#puts "got values at [clock milliseconds]"
	    if {[llength $vals]} {
# do not add empty lists they make finding dataless variables harder
		set trans [lindex $displayList($winId,transes) $varIndex]
		set dataStore($winId,$varId,$tCur) \
		    [TransEnums $trans $vals]
	    }
                
            incr varIndex
        }
#puts "loaded datastore at [clock milliseconds]"
        if {$displayUpdate($winId) || !$tStep} {
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
    }
    
    proc CopyToClipboard {winId} {
        set titlecols [$winId.t cget -titlecols]
        set titlerows [$winId.t cget -titlerows]
        $winId.t configure -titlecols 0
        $winId.t configure -titlerows 0; # to allow all table to be selected by selection command
        $winId.t selection set origin end
        event generate $winId.t <<Copy>>
        $winId.t configure -titlecols $titlecols
        $winId.t configure -titlerows $titlerows
        # should deselect all cells
    }
    
    # save table contents as CSV file
    proc Save {winId} {
        set filename [ChooseFile table.csv [tr. "Save table contents as.."] 1 \
			  [GetTopNode $winId]]
        SaveToNamedFile $winId $filename
    }
    
    proc GetTopNode {winId} {
	global helperTable
	variable editMode

	if {[info exists editMode($winId)]} {
	    return $editMode($winId)
	} else {
	    return [$helperTable($winId,whichInstance) GetNode]
	}
    }

    proc SaveToNamedFile {winId filename args} {
	variable curRows
	variable curCols

	package require csv
	set listVersion [lrepeat $curRows [lrepeat $curCols {}]]
	foreach {idxPair val} [array get ::data$winId] {
	    if {[string equal active $idxPair]} continue
	    lset listVersion [split $idxPair ,] $val
	}
	set fileId [open $filename w]
	foreach line $listVersion {
	    puts $fileId [::csv::join $line]
	}
	close $fileId
    }

# old version needs table widget to be displaying the data
    proc OldSaveToNamedFile {winId filename args} {
        global custom
        set rsep [$winId.t cget -rowseparator]
        set csep [$winId.t cget -colseparator]
        $winId.t configure -rowseparator \n -colseparator ,
        set titlecols [$winId.t cget -titlecols]
        set titlerows [$winId.t cget -titlerows]
        $winId.t configure -titlecols 0
        $winId.t configure -titlerows 0; # to allow all table to be selected by selection command
        $winId.t selection set origin end
        event generate $winId.t <<Copy>>
        set data [selection get -displayof $winId.t -selection CLIPBOARD]
        if {$filename != ""} {
	    if {[llength $args]} {
		set fileid [open $filename a]
		puts $fileid [lindex $args 0]
	    } else {
		set fileid [open $filename w]
	    }
            puts $fileid $data
            close $fileid
        }
        
        $winId.t configure -titlecols $titlecols
        $winId.t configure -titlerows $titlerows
        $winId.t configure -rowseparator $rsep -colseparator $csep
    }
    
    
    proc Print {winId} {ShowMess Warning warning \
                "[identify] does not support printing.\n\
                However, you can copy the contents and paste them into another application for printing." ok
    }
    
    ################################################################################
    # requires prntproc.tcl
    #         proc Print {winId} {
    #             global printargs
    #             set hdc [printer dialog select]
    #             if { [lindex $hdc 1] == 0 } {
    #                 # User has canceled printing
    #                 return
    #             }
    #             set printargs(hDC) [ lindex $hdc 0 ]
    #
    #             set titlecols [$winId.t cget -titlecols]
    #             set titlerows [$winId.t cget -titlerows]
    #             $winId.t configure -titlecols 0
    #             $winId.t configure -titlerows 0; # to allow all table to be selected by selection command
    #             $winId.t selection set origin end
    #             event generate $winId.t <<Copy>>
    #             #ShowMess debug info "[selection get -displayof $winId.t -selection CLIPBOARD]" ok
    #             set data [selection get -displayof $winId.t -selection CLIPBOARD]
    #             print_data $data
    #         $winId.t configure -titlecols $titlecols
    #         $winId.t configure -titlerows $titlerows
    #     }
    ################################################################################
    
    proc Reconbobulate {winId} {
	global data$winId

        variable dataStore
        variable orientList
        variable displayList
        variable lastDisplay
        variable varNamePosns
        variable editMode
        
        variable values
        variable rowNames
        variable colNames
        variable rowIds
        variable colIds

	variable curRows
	variable curCols
        
        if {[info exists rowNames]} {unset rowNames}
        if {[info exists colNames]} {unset colNames}
        if {[info exists values]} {unset values}
        
        set varIndex 0
	set dummied {}
	set allPts [array names dataStore $winId,*,*]
	if {[llength $allPts]} {
	    set dummyTime [lindex [split [lindex $allPts 0] ,] 2]
	} else {
	    set dummyTime $lastDisplay($winId)
	}
        foreach varCapt $displayList($winId,paths) {
	    set varId [lindex $displayList($winId,ids) $varIndex]
	    if {![llength [array names dataStore $winId,$varId,*]]} {
# component is selected for tabulation but no values recorded --
# insert empty value for existing or current time so header appears.
		lappend dummied $varId
		set dataStore($winId,$varId,$dummyTime) [list " "]
	    }
            incr varIndex
        }

        foreach valId [array names dataStore $winId,*,*] {
            set valDims [split $valId ,]
            set varId [lindex $valDims 1]
	    set varIndex [lsearch $displayList($winId,ids) $varId]
            if {[string match none [lindex $orientList($winId) 0]]} {
                if {[lindex $valDims 2]==$lastDisplay($winId)} {
                    GrabIndices $winId 1 {} {} $varIndex $dataStore($valId) \
			$varIndex
                }
            } else {
                GrabIndices $winId 0 {} {} [lindex $valDims 2] \
                        [list $varIndex $dataStore($valId)] $varIndex
            }
        }
        
#puts "Data transferred to 2-d table mirror array at [clock milliseconds]"
#	ShowMess debug info "Table has [llength [array names rowNames]] rows and [llength [array names colNames]] columns" ok
	set lineMax 10000
	set boxMax 1000000
	set rowCount [llength [array names rowNames]]
	set colCount [llength [array names colNames]]
	if {$rowCount>$lineMax} {
	    set scaryFact tooManyRows
        }
	if {$colCount>$lineMax} {
	    set scaryFact tooManyColumns
        }
	if {$rowCount*$colCount>$boxMax} {
	    set scaryFact tooManyCells
	    set lineMax $boxMax
        }
	if {[info exists scaryFact]} {
	    $winId.t configure -state normal -variable spare$winId
	    $winId.t set 0,0 "$::msgs(tableWimpOut)\n$::msgs($scaryFact) $lineMax"
	    $winId.t width 0 48
	    $winId.t height 0 2
	    $winId.t tag cell red 0,0
	    if {![info exists editMode($winId)]} {
		$winId.t configure -state disabled
	    }
	} else {
	    $winId.t configure -state normal -variable data$winId
	}

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
	set curRows [expr $curHeaderRows+$rowCount]
	set curCols [expr $curHeaderCols+$colCount]
        
#puts "Header rows and columns sorted at [clock milliseconds]"
        
        unset data$winId
 	if {![info exists scaryFact]} {
	    foreach {span old} [$winId.t spans] {
		$winId.t spans $span 0,0
	    }

# Following is faster but flickers too much
#	destroy $winId.t
#	CreateTable $winId
	    $winId.t config  -rows $curRows -cols $curCols \
		-titlerows $curHeaderRows -titlecols $curHeaderCols
	    $winId.t configure -state normal
	}

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
                set oldCapt [lindex [array get data$winId $tgtSq] 1]
                if {[llength $oldCapt]} {
                    set data${winId}($tgtSq) "$topCapt \\ $oldCapt"
                } else {
		    set data${winId}($tgtSq) $topCapt
                }
                incr rowsTop
            } else {
                set tgtSq $colsTop,[expr $curHeaderCols-1]
#                set oldCapt [$winId.t get $tgtSq]
                set oldCapt [lindex [array get data$winId $tgtSq] 1]
                if {[llength $oldCapt]} {
#                    $winId.t set $tgtSq "$oldCapt \\ $topCapt"
                    set data${winId}($tgtSq) "$oldCapt \\ $topCapt"
                } else {
#                    $winId.t set $tgtSq $topCapt
		    set data${winId}($tgtSq) $topCapt
                }
                incr colsTop
            }
            $winId.t tag cell base $tgtSq
            incr level
        }
	if {![info exists scaryFact]} {
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
	}
#puts "Meta-headers inserted at [clock milliseconds]"
        set timeSide [lindex $orientList($winId) 0]
        set lineToShow 0
        set translateSide [lindex $orientList($winId) 1]
        set translateLevel [string match $translateSide \
                [lindex $orientList($winId) 0]]
        if {[string compare none $timeSide]} {
            set timeToShow [GetModelTime]
        }
        set varNamePosns($winId) {}
        
        set lastEntry(0) none
        set count $curHeaderRows
        foreach entry [array names rowIds $winId,*] {
            unset rowIds($entry)
        }
        foreach item $rowList {
            set rowIds($winId,$item) $count
            #            $winId.t insert rows end
            # changed to preserve widths/heights
            set headerCol 0
            foreach headerElt $item {
                if {[string match $headerElt $lastEntry($headerCol)]} {
                    # header same as prev line so span it over
                    if {![info exists scaryFact]} {
			$winId.t spans $lastLine($headerCol),$headerCol \
                            [expr $count-$lastLine($headerCol)],0
		    }
                } else {
                    set lastEntry($headerCol) $headerElt
                    set lastEntry([expr $headerCol+1]) none
                    set lastLine($headerCol) $count
                    # For header columns, put in duplicate values that are spanned over
                    # so saved files can be used for file parameters
                }
                if {[string match rows $translateSide] && \
                            $headerCol==$translateLevel} {
                    set headerElt [lindex $displayList($winId,paths) $headerElt]
                    if {!$headerCol} {
                        lappend varNamePosns($winId) $count
                    }
                }
                if {!$headerCol && [string match rows $timeSide] && \
                            $headerElt==$timeToShow} {
                    set lineToShow $count
                }
                set data${winId}($count,$headerCol) \
                        [lindex [split $headerElt /] end]
                incr headerCol
            }
            incr count
        }
#puts "Column headers inserted at [clock milliseconds]"
        set lastEntry(0) none
        set count $curHeaderCols
        foreach entry [array names colIds $winId,*] {
            unset colIds($entry)
        }
        foreach item $colList {
            set colIds($winId,$item) $count
            #            $winId.t insert cols end
            # changed to preserve widths/heights
            set headerRow 0
            foreach headerElt $item {
                if {[string match $headerElt $lastEntry($headerRow)]} {
                    # header same as prev line so span it over
		    if {![info exists scaryFact]} {
			$winId.t spans $headerRow,$lastLine($headerRow) \
                            0,[expr $count-$lastLine($headerRow)]
		    }
                } else {
                    set lastEntry($headerRow) $headerElt
                    set lastEntry([expr $headerRow+1]) none
                    set lastLine($headerRow) $count
                    if {[string match cols $translateSide] && \
                                $headerRow==$translateLevel} {
                        set headerElt \
			    [lindex $displayList($winId,paths) $headerElt]
                        if {!$headerRow} {
                            lappend varNamePosns($winId) $count
                        }
                    }
                    if {!$headerRow && [string match cols $timeSide] && \
                                $headerElt==$timeToShow} {
                        set lineToShow $count
                    }
                    set data${winId}($headerRow,$count) \
                            [lindex [split $headerElt /] end]
                }
                incr headerRow
            }
            incr count
        }
        #puts "vnps $varNamePosns($winId)"
        #puts "row headers inserted at [clock milliseconds]"
	#puts "table now looks like [array get ::data$winId]"
	
	RestoreFromMirror $winId
	if {![info exists scaryFact]} {
	    switch $timeSide {
		rows {
		    $winId.t see $lineToShow,0
		} cols {
		    $winId.t see 0,$lineToShow
		}
	    }
	    if {![info exists editMode($winId)]} {
		$winId.t configure -state disabled
	    }
	}
# now remove dummy values added to ensure appearance of useful headers
	foreach varId $dummied {
	    array unset dataStore $winId,$varId,$dummyTime
	}
    }
    
    proc RestoreFromMirror {winId} {
	variable values
	variable rowIds
	variable colIds
        variable cellFormatKey
	variable displayFormat

        foreach value [array names values] {
#            set headers [split $value ,]
            set rowHead $rowIds($winId,[lindex $value 0])
            set colHead $colIds($winId,[lindex $value 1])
	    set id $cellFormatKey($winId,[join $value ,])
	    set cellFormat $displayFormat($winId,$id)
            set ::data${winId}($rowHead,$colHead) \
		[FormatValue $values($value) [lindex $cellFormat 0] \
		     [lindex $cellFormat 1]]
            if {[lindex $cellFormat 2]==1 & $values($value)<0} {
                $winId.t tag cell red $rowHead,$colHead
            } else {
                $winId.t tag cell {} $rowHead,$colHead
	    }
        }
        #puts "Table values inserted"
    }

    # OK you thought that was tricky, now we need one to go the other way and
    # get the nested list format back from the table if it has been edited. What
    # are we working with? RowIds and ColIds list the table line for each set of
    # headers so we are probably best looping over these making an intermediate
    # array format (and perhaps picking out bounds) then converting that.
    
    proc ExtractEdits {winId} {
        variable rowIds
        variable colIds
        variable orientList
        variable indices
        variable values

        set rowsPt 0
        set colsPt 0
        set nonePt 0
        # First, make a command that will convert ids into array subscripts
        foreach level $orientList($winId) {
            if {![string match none $level]} {
                if {$rowsPt+$colsPt+$nonePt+1==[llength $orientList($winId)]} {
                    append subscriptTemplate \
                            "\[lrange \$${level}Headers [set ${level}Pt] end\]"
                } elseif {$rowsPt+$colsPt+$nonePt+1!=2} {
		    # do not include index of variable id
                    append subscriptTemplate \
                            "\[lrange \$${level}Headers [set ${level}Pt] [set ${level}Pt]\] "
                }
            }
            incr ${level}Pt
        }
        #puts "Orient list $orientList($winId)"
	#puts "subscript template: $subscriptTemplate"
        #puts "rowIds [array get rowIds] colIds [array get colIds]"
        # next copy the 2-d table to an n-d array using these
        foreach value [array names values] {
	    if {[string length $values($value)]} {
#		set headers [split $value ,]
		set rowsHeaders [lindex $value 0]
		set colsHeaders [lindex $value 1]
		set subscript [eval {concat} $subscriptTemplate]
		set newValues($subscript) [EnquoteIfNonNumeric $values($value)]
	    }
	}
# Old version that actually got the values out the table widget
#        foreach rowEntry [array names rowIds $winId,*] {
#            set rowsHeaders [lindex [split $rowEntry ,] 1]
#            foreach colEntry [array names colIds $winId,*] {
#                set colsHeaders [lindex [split $colEntry ,] 1]
#                set subscript [eval {concat} $subscriptTemplate]
## puts "$subscriptTemplate evalled to $subscript"
#                set src ::data${winId}($rowIds($rowEntry),$colIds($colEntry))
#                if {[info exists $src]} {
#                    set newValues($subscript) [EnquoteIfNonNumeric [set $src]]
#                }
#            }
#        }
	#puts "values: [array get values] newValues: [array get newValues]"
        return [ArrayToList newValues]
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
        if {[string compare $l1 [lindex $l1 0]] || \
                    [string compare $l2 [lindex $l2 0]]} {
            set recurse [ReComp [lindex $l1 0] [lindex $l2 0]]
            if {$recurse} {
                return $recurse
            }
            return [ReComp [lrange $l1 1 end] [lrange $l2 1 end]]
        }
        if {[catch {expr ($l2<$l1)-($l2>$l1)} math]} {
            return [string compare $l1 $l2]
        }
        return $math
    }
    
    proc GrabIndices {winId depth rowsList colsList index struct varId} {
        variable orientList
        variable values
        variable rowNames
        variable colNames
        variable cellFormatKey
        
        if {[llength $index]} {
            set nextAxis [lindex $orientList($winId) [expr {min($depth,3)}]]
            lappend ${nextAxis}List $index
            incr depth
        }
        
        if {[string is list $struct] && [llength $struct]>1} {
            foreach {newIndex newStruct} $struct {
                GrabIndices $winId $depth $rowsList $colsList $newIndex \
                        $newStruct $varId
            }
        } else {
            set values([list $rowsList $colsList]) $struct
            set cellFormatKey($winId,$rowsList,$colsList) $varId
            
            set rowNames($rowsList) {}
            set colNames($colsList) {}
        }
    }
    
    proc rowProc row { if {$row>0 && $row%2} { return OddRow } }
    proc colProc col { if {$col>0 && $col%2} { return OddCol } }
    
    # FormatValue replaces VarPrecRender which is now DisplayFormat::General
    proc FormatValue {val format prec} {
        # if a c model is built with Windows math libraries, the numerical
        # values might not format as floats. Watch out for this problemette
        # and just return them as they are if it happens
	if {![string is double -strict $val]} {
	    return $val
	}
        set format [regsub -all { } $format {}]; # spaces removed from format name to make a proc name
        switch $format {
            #General { General $val $prec}
            default { return [$format $val $prec]}
        }
    }
    
    proc PropertiesDlg {winId} {
        variable orientList
        variable displayList
        variable format
        variable displayUpdate
        variable editMode
        variable dataStore
        
        set t [toplevel $winId.propertiesDlg]
        wm transient $t $winId
        wm title $t "Table properties"
        wm resizable $t 0 0
        set ::${t}l1 [lindex $orientList($winId) 0]
        set ::${t}l2 [lindex $orientList($winId) 1]
        set ::${t}l3 [lindex $orientList($winId) 2]
        set ::${t}l4 [lindex $orientList($winId) 3]
        set ::${t}l5 $displayUpdate($winId)
        
        set nb [::ttk::notebook $t.nb]
        pack $nb -expand on -fill both -padx 10 -pady 10
        
        # layout page
        set layoutP [frame $nb.layout]
	$nb add $layoutP -text Layout
        
        pack [label $layoutP.toplbl -text "For each possible dimension listed,\
                select between including it on the rows or on the columns of the table." \
                -wraplength 300] -pady 4
        
        pack [frame $layoutP.l1]  -anchor w -padx 2 -pady 4
        pack [label $layoutP.l1.lbl -text "Times:" -width 20] -side left  -anchor w
        pack [label $layoutP.l1.lbl2 -text "On Rows"] -side left -anchor w
        pack [radiobutton $layoutP.l1.rowb -variable ${t}l1 -value rows] -side left  -anchor w
        pack [label $layoutP.l1.coll -text "On Columns"] -side left -anchor w
        pack [radiobutton $layoutP.l1.colb -variable ${t}l1 -value cols] -side left -anchor w
        pack [label $layoutP.l1.nonel1 -text "Current values only"] -side left -anchor w
        pack [radiobutton $layoutP.l1.noneb -variable ${t}l1 -value none] -side left -anchor w
        
        pack [frame $layoutP.l2]  -anchor w -padx 2 -pady 4
        pack [label $layoutP.l2.lbl -text "Element names:" -width 20] -side left  -anchor w
        pack [label $layoutP.l2.lbl2 -text "On Rows"] -side left -anchor w
        pack [radiobutton $layoutP.l2.rowb -variable ${t}l2 -value rows] -side left  -anchor w
        pack [label $layoutP.l2.coll -text "On Columns"] -side left  -anchor w
        pack [radiobutton $layoutP.l2.colb -variable ${t}l2 -value cols] -side left  -anchor w
        
        pack [frame $layoutP.l3]  -anchor w -padx 2 -pady 4
        pack [label $layoutP.l3.lbl -text "First index:" -width 20] -side left  -anchor w
        pack [label $layoutP.l3.lbl2 -text "On Rows"] -side left -anchor w
        pack [radiobutton $layoutP.l3.rowb -variable ${t}l3 -value rows] -side left  -anchor w
        pack [label $layoutP.l3.coll -text "On Columns"] -side left  -anchor w
        pack [radiobutton $layoutP.l3.colb -variable ${t}l3 -value cols] -side left  -anchor w
        
        pack [frame $layoutP.l4]  -anchor w -padx 2 -pady 4
        pack [label $layoutP.l4.lbl -text "Other indices:" -width 20] -side left  -anchor w
        pack [label $layoutP.l4.lbl2 -text "On Rows"] -side left -anchor w
        pack [radiobutton $layoutP.l4.rowb -variable ${t}l4 -value rows] -side left  -anchor w
        pack [label $layoutP.l4.coll -text "On Columns"] -side left -anchor w
        pack [radiobutton $layoutP.l4.colb -variable ${t}l4 -value cols] -side left -anchor w
        
        pack [frame $layoutP.l5]  -anchor w -padx 2 -pady 4
        pack [checkbutton $layoutP.l5.update -variable ${t}l5 \
                -text "Update at display intervals"]
        
        #set newHeader [GetCaptionPathFromId $node]
        #set varIndex [lsearch $displayList($winId) $newHeader]
        
        # format page
        set formatP [frame $nb.format]
	$nb add $formatP -text "Variable Formats"
        set varF [frame $formatP.varF]
        pack $varF -side top -fill x
        
        set varL [label $varF.label -text Variable]
        set varCB [ttk::combobox $varF.comboBox -state readonly \
		       -values [concat All... $displayList($winId,paths)]]
	$varCB current 0
        pack $varL $varCB -side left
        
        set formatF [frame $formatP.formatF]
        pack $formatF -side bottom -fill both -expand on -pady 10
        
        set catF [frame $formatF.catF]
        label $catF.label -text Category
        listbox $catF.listbox -exportselection false -selectmode single
        foreach cat [array names format] {
            $catF.listbox insert 0 $cat
        }
        pack $catF.label $catF.listbox -anchor w
        
        set formF [frame $formatF.formF]
        label $formF.label -text Format
        listbox $formF.listbox -exportselection off -selectmode single
        pack $formF.label $formF.listbox -anchor w
        
        # options
        set optionsF [labelframe $formatF.optionsF -text Options]
        
        frame $optionsF.decimalPlacesF
        pack [label $optionsF.decimalPlacesF.label -text "Decimal places"] -side left
        
        set DecimalPlacesSB [spinbox $optionsF.decimalPlacesF.decimalPlacesSB -from 0 -to 20 -width 5]
        pack $DecimalPlacesSB -side right
        
        set NegInRedCB [checkbutton $optionsF.negInRedCB -text "Show negative numbers in red"]
        pack $optionsF.decimalPlacesF $NegInRedCB -fill x -pady 15
        
        pack $catF $formF $optionsF -side left -padx 10 -fill y
        
	bind $varCB <ButtonRelease-1> [namespace code \
                "SetFormatWidgets $winId $varCB $catF.listbox $formF.listbox $optionsF"]
        bind $catF.listbox <ButtonRelease-1> +[namespace code \
                [list OnCatListBoxClick $winId $varCB $catF.listbox $formF.listbox]]
        bind $formF.listbox <ButtonRelease-1> +[namespace code \
                [list OnFormatListBoxClick $winId $varCB $formF.listbox]]
        
        SetFormatWidgets $winId $varCB $catF.listbox $formF.listbox $optionsF
        
        # buttons
        pack [frame $t.b]
        pack [button $t.b.ok -text OK -width 10 -command "set ${t}done 1"] \
                -side left -padx 2 -pady 4
        pack [button $t.b.cancel -text Cancel -width 10 -command "set ${t}done 0"] \
                -side left -padx 2 -pady 4
        ################################################################################
        #                 pack [button $t.b.apply -text Apply -width 10 \
        #                         -command [namespace code "Reconbobulate $winId"]] \
        #                 -side left -padx 2 -pady 4
        ################################################################################
        
# One of life's little mysteries. Unless you do the next three lines,
# it is impossible to switch between tabs on the Mac -- even though
# the same thing works fine in the equation dialogue.
        $nb select 1
	update
        $nb select 0
	grab $t
        tkwait variable ${t}done
        
        if {[set ::${t}done]} {
	    set newOrients [list [set ::${t}l1] [set ::${t}l2] \
                    [set ::${t}l3] [set ::${t}l4]]
            set displayUpdate($winId) [set ::${t}l5]
            if {[string equal $newOrients $orientList($winId)]} {
		$winId.t configure -state normal
		RestoreFromMirror $winId
		if {![info exists editMode($winId)]} {
		    $winId.t configure -state disabled
		}
	    } else {
		# only do if table is editable
		if {[info exists editMode($winId)]} {
#		    EditCellIs $winId.t 0 0 ;# get final edit
		    unset dataStore
		    # need tweaking if time/var in use
		    # (removed, what to do now 2nd subscript is id not index)
		    set dataStore($winId,dummyId,0.0) [ExtractEdits $winId]
		}
		set orientList($winId) $newOrients
		Reconbobulate $winId
	    }
            PrepareSaveString $winId
        }
        destroy $t
    }
    
    
    
    proc SetCatListboxSelection {listbox formatSpec} {
        variable format
        
        set category ""
        $listbox selection clear 0 end
        foreach cat [array names format] {
            if {[lsearch $format($cat) $formatSpec]>=0} {
                set category $cat
                continue
            }
        }
        set catIndex [lsearch [$listbox get 0 end] $category]
        $listbox selection set $catIndex
    }
    
    proc SetFormatListboxSelection {listbox formatSpec} {
        $listbox selection set [lsearch [$listbox get 0 end] $formatSpec]
    }
    
    proc OnCatListBoxClick {winId varCB catListbox formListbox} {
        FillFormatListBox $catListbox $formListbox
        #$formListbox selection set 0; # can't get back from cancel - dlg should save state so can restore on cance
        #OnFormatListBoxClick $winId $varCB $formListbox
    }
    
    proc FillFormatListBox {catListbox formListbox } {
        variable format
        $formListbox delete 0 end
        foreach form $format([$catListbox get [$catListbox curselection]]) {
            $formListbox insert 0 $form
        }
    }
    
    proc OnFormatListBoxClick {winId varCB formatListbox} {
	AdjustCurrentFormatList $winId $varCB 0 \
	    [lindex [$formatListbox get 0 end] [$formatListbox curselection]]
    }
    
    proc SetFormatWidgets {winId varCB catlistbox formlistbox optionsF} {
        variable displayList
        variable displayFormat
	set varIndex [lsearch -exact $displayList($winId,paths) [$varCB get]]
#        if {$varIndex==-1} {
#	    set varIndex 0
#	}
# caused error if no variables yet listed
	set formatSpec [lindex $displayFormat($winId,$varIndex) 0]
	SetCatListboxSelection $catlistbox $formatSpec
	FillFormatListBox $catlistbox $formlistbox
	SetFormatListboxSelection $formlistbox $formatSpec
	$optionsF.decimalPlacesF.decimalPlacesSB set [lindex $displayFormat($winId,$varIndex) 1]
	if {[lindex $displayFormat($winId,$varIndex) 2]} {
	    $optionsF.negInRedCB select
	} else  {
	    $optionsF.negInRedCB deselect
	}
	$optionsF.decimalPlacesF.decimalPlacesSB configure -command \
	    [namespace code "AdjustCurrentFormatList $winId $varCB 1 %s"]
	$optionsF.negInRedCB configure -command \
	    [namespace code "OnNegInRedCBClick $optionsF.negInRedCB $winId $varCB"]
    }
    
    proc OnNegInRedCBClick {CB winId varCB} {
        global negInRedCB

	AdjustCurrentFormatList $winId $varCB 2 $negInRedCB
    }
    
    proc AdjustCurrentFormatList {winId varCB posn val} {
        variable displayList
        variable displayFormat

	set selected [$varCB get]
	set varIndex 0
	foreach varId $displayList($winId,paths) {
	    if {[string equal $varId $selected]} {
		lset displayFormat($winId,$varIndex) $posn $val
	    }
	    if {[string equal "All..." $selected]} {
		lset displayFormat($winId,-1) $posn $val
		lset displayFormat($winId,$varIndex) $posn $val
	    }
	    incr varIndex
	}
    }
} ;# end of namespace
