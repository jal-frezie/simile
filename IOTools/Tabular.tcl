#############################################################################
# Tabular display                                                           #
#############################################################################

# Menus removed because they don't show up in a tabsheet.
# Buttons added to Add a variable to display in a column,
# Remove variable (columns) and and Save. (Use commands the menus used.)
# If data input is required will have to add buttons or is this
# feature no longer possible/wanted - file parameters etc.
# Helpers should have a similar user inferface where possible.

#$Log: Tabular.tcl,v $
#Revision 1.1  2002/05/23 15:33:18  jmm
#*** empty log message ***
#
#Revision 1.8  2002-05-03 17:34:45+01  jmm
#Removed menu - will replace later with a RTE (MRE) compatible system
#Added a toolbar instead of the menu - removed read from file and variable value setting
#

set keyValue tabular11508

namespace eval tabular11508 {

proc identify {} {
	return "Data table"
}

proc initialize {winId} {
	variable cf
	variable yscrollers
	variable maxdims
	variable fillers
	variable latestLine
	variable nodeMode
	variable precision 4

# global debug
# pack [set debug [text $winId.debug]] -fill x

	# create sub-namespace for this window ID
	namespace eval $winId {
		set status(nodeCount) 0
	}
	SetState $winId {nodeCount 0}

set toolbarItems [list \
        [list new.gif "Clear" [namespace code [list clear $winId]] ]\
        [list add.gif "Add a variable" [namespace code [list AddNode $winId read]] ]\
        [list remove.gif "Remove a variable" [namespace code [list KillColumns $winId]] ]\
        [list save.gif "Save" [namespace code [list WriteFile $winId]] ] \
        [list mprec.gif "Increase precision" [namespace code [list ChangePrecision 1]] ]\
        [list lprec.gif "Decrease precision" [namespace code [list ChangePrecision -1]] ]\
]
    ::graphtools::MakeToolBar $winId $toolbarItems
    
    pack [frame $winId.fiddle] -fill x -expand true
	set ms [message $winId.fiddle.intro -aspect 1000 \
			-text "No values currently selected"]
	pack $ms -fill x -expand true
	set nodeMode($winId) none

	scrollbar $winId.xscroll -orient horizontal \
		-command [namespace code [list $winId.bigtext xview]]
	pack $winId.xscroll -side bottom -fill x

	set tf [frame $winId.timeframe]
	scrollbar $winId.yscroll -orient vertical \
		-command [namespace code [list ScrollAll $winId]]
	pack $winId.yscroll -side right -fill y

	set maxdims($winId) 0
	pack [set fillers($winId) [frame $tf.fill]]
	tk_optionMenu $tf.time [namespace current]::nodeMode($winId,action) \
		Time Index
	$tf.time configure -bd 0 -bg grey
	pack $tf.time
	frame $tf.dimheaders
	pack $tf.dimheaders
	listbox $tf.text -yscrollcommand [namespace code [list DragBox $winId]] \
			-width 12
	bind $tf.text <Button-1> [namespace code [list ClickTime $winId %x %y]]
	set yscrollers($winId) $tf.text
	pack $tf.text -side bottom -fill y -expand true
	$tf.text insert end [GetModelTime]
	pack $tf -side left -fill y

	set lcf [text $winId.bigtext -xscrollcommand [list $winId.xscroll set] \
			-height 100 -wrap none -state disabled]
	bind $lcf <Configure> [namespace code {SizeText %W %x %y %w %h}]
	pack $lcf -side left -fill both -expand true
# Woolaa woolaa! Next, a special canvas whose only job is to stretch the
# text line so the listboxes can expand into space
	$lcf window create end -window [canvas $lcf.c -width 0]
# and here is the frame into which the subframes containing headers and listboxes
# will be inserted
	$lcf window create end -window [set cf($winId) [frame ${lcf}.f]] \
			-stretch true
	set latestLine($winId) 0
}

proc Restore {winId} {

    variable nodeMode

    array set oldStatus [GetState $winId]
    initialize $winId
    for {set boxno 1} {$boxno <= $oldStatus(nodeCount)} {incr boxno} {
	if {[info exists oldStatus(nodebox$boxno)]} {
	    set targetLine $oldStatus(nodebox$boxno)
	    set nodeMode($winId) [lindex $targetLine 2]
	    click $winId [GetIdFromCaptionPath [lindex $targetLine 1]] foo
	}
    }
}

proc ChangePrecision {diff} {
	variable precision
	incr precision $diff
	if {$precision<0} {
	    set precision 0
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

proc ClickTime {winId x y} {
	TimeSelect $winId [$winId.timeframe.text index @$x,$y]
}

proc AddNode {winId action} {
	variable nodeMode
	switch $action {
		read {
			set message "Click on a node to display its value(s)."
		} write {
			set message "Click on a node to set its value(s)."
		}
	}
	$winId.fiddle.intro configure -text $message
	set nodeMode($winId) $action
	GrabClicks $winId
}

# This executes the menu selection for writing data from an existing column
# to a new node in the model

proc WriteNode {winId} {
	variable nodeMode
	set message "Click on the top-level title (node caption) in the column you \
			wish to write to a new node." 
	$winId.fiddle.intro configure -text $message
	set nodeMode($winId) write_node
}

# The following procedure to add a row for a so-far-undefined time uses a service
# provided in a global procedure to query the user for the time at which the new
# row applies.

proc AddRow {winId} {
	set newTime [RequestValue "Enter information" \
			"Please give a point in time for the new row" Add]

	for {set targetRow 0} {$targetRow < [$winId.timeframe.text index end]} \
			{incr targetRow} {
		if {$newTime < [set oldTime [$winId.timeframe.text get $targetRow]]} {
			break
		}
	}
	if {abs($newTime-$oldTime) < 0.000001} {
		$winId.fiddle.intro configure -text "A row for time $newTime already exists."
	} else {
		$winId.timeframe.text insert $targetRow $newTime
		AddBlankToAll $winId.bigtext $targetRow 1
		$winId.fiddle.intro configure -text "New row created for time $newTime"
	}
}

proc KillColumns {winId} {
	variable nodeMode

	$winId.fiddle.intro configure -text "Click on the header \
			at which to start deleting"
	set nodeMode($winId) delete_cols
} 

# clear spoofs a two-click delete of the whole table
proc clear {winId} {
	variable nodeMode
	set nodeMode($winId) "delete_from 0"
	TimeSelect $winId end
}

proc KillRows {winId} {
	variable nodeMode

	$winId.fiddle.intro configure -text "Click on the time entry of the row \
			at which to start deleting"
	set nodeMode($winId) delete_times
} 

proc SizeText {id x y w h} {
	$id.c configure -height [expr $h-8]
}

# This is called when text in a box is dragged up or down. It makes the scrollbar
# and text in the other boxes follow. Relies on the fact that when text is moved
# externally, no scroll command is generated if the new position is same as the 
# old -- otherwise it would loop infinitely

proc DragBox {winId above in} {
	$winId.yscroll set $above $in
	ScrollAll $winId moveto $above
}
	
proc ScrollAll {winId args} {
	variable yscrollers
	foreach item $yscrollers($winId) {
		eval {$item yview} $args
	}
}

proc InsertListBox {winId boxId writer} {
	variable yscrollers
	listbox $boxId -yscrollcommand [namespace code [list DragBox $winId]] \
			-width 12 -height 1
	pack $boxId -side bottom -fill y -expand true
	# Make inputs to model a different colour (greeny) and enable
	# editing of their active members
	if {$writer} {
		$boxId configure -background #c0ffc0
		$boxId configure -selectbackground #80c080
		AddEditBindings $boxId
	}
	lappend yscrollers($winId) $boxId
}

proc click {winId node caption} {
	variable cf
	variable maxdims
	variable fillers
	variable latestLine
	variable nodeMode
	variable yscrollers

	global [namespace current]::${winId}::status

	set newBoxName nodebox[incr status(nodeCount)]
	set fullCaption [GetCaptionPathFromId $node]
    ReleaseClicks $winId
	switch -glob $nodeMode($winId) {
		none {
			$winId.fiddle.intro configure -text \
					"Please select a mode from the edit menu before \
					adding a node to the table."
			return
		} read {
			set writing 0
			set status($newBoxName) [list $node $fullCaption read]
		} write {
			set writing 1
			set status($newBoxName) [list $node $fullCaption write]
		} "write_to *" {
		    set writing -1
			set frameId [lindex $nodeMode($winId) 1]
			set status($frameId) [list $node $fullCaption write]
		}
	}
	if {$writing == -1} {
			# now change header text of column to new node caption
			set hitFrame $cf($winId).$frameId
			$hitFrame.header configure -text $fullCaption
			# now change listbox colourscheme to green for write
			foreach lb $yscrollers($winId) {
				if {[string match ${hitFrame}* $lb]} {
					$lb configure -background #c0ffc0
					$lb configure -selectbackground #80c080
					AddEditBindings $lb
				}
			}
		    } else {
	set newBox [frame $cf($winId).$newBoxName]

	pack $newBox -side left -fill y -expand true
	pack [frame $newBox.fill] 
	set title [label $newBox.header -text $fullCaption -relief sunken]
	pack $title -fill x
	bind $title <Button-1> [namespace code [list MarkTitle $winId $newBox]]
	set testResult [lindex [GetModelValue $node] 0]
	set time [GetModelTime]
			if {[string match Index $nodeMode($winId,action)]} {
			    set insertPoint indexed
			} else {
			    set insertPoint $latestLine($winId) 
			}
	set dims [FillColumns $winId $newBox testResult $insertPoint \
		0 $writing]

	# The next loop puts extra lines above the new column if it has fewer
	# header levels than there currently are. The one after that does the
	# reverse -- puts extra lines above existing columns if the new one has
	# more header levels.

	while {$dims < $maxdims($winId)} {
		incr dims
		pack [label $newBox.fill.stuffing$dims]
	}
	while {$dims > $maxdims($winId)} {
		incr maxdims($winId)
		foreach spacer $fillers($winId) {
			pack [label $spacer.stuffing$maxdims($winId)]
		}
	}
	lappend fillers($winId) $newBox.fill
    }
    $winId.fiddle.intro configure -text {}
    set nodeMode($winId) none
    SetState $winId [array get status]
}

# TimeSelect is called when user clicks on something in the time column. It uses
# the mode variable to go through the start and finish steps of deleting a set
# of horizontal lines in the data table.

proc TimeSelect {winId index} {
	variable nodeMode
	variable yscrollers
	variable latestLine

	switch -glob $nodeMode($winId) {
		delete_times {
			$winId.fiddle.intro configure -text \
					"Now click the last time entry to delete, \
					or the same again to delete just one"
			set nodeMode($winId) "delete_from $index"
		} "delete_from *" {
			set end [lindex $nodeMode($winId) 1] 
			if {$end < $index} {
				set hi $index
			} else {
				set hi $end
				set end $index
			}
			# Do not delete the line for the current time, this messes
			# up the insertion
			set now $latestLine($winId)
			if {$now >= $end && $now <= $hi} {
				foreach target $yscrollers($winId) {
					# hi side first for obvious reasons
					$target delete [expr $now+1] $hi
					$target delete $end [expr $now-1]
				}
				set latestLine($winId) $end
			} else {
				foreach target $yscrollers($winId) {
					$target delete $end $hi
				}
				if {$now >= $end} {
					set latestLine($winId) [expr $now+$end-$hi-1]
				}
			}
			set nodeMode($winId) none
			$winId.fiddle.intro configure -text {}
		}
	}
}

proc MarkTitle {winId hitFrame} {
	variable nodeMode
	variable yscrollers
	variable latestLine

	global [namespace current]::${winId}::status

	switch -glob $nodeMode($winId) {
		delete_cols {
			$winId.fiddle.intro configure -text \
					"Now click the title of the last column to delete, \
					or the same again to delete just one"
			$hitFrame.header configure -bg red
			$hitFrame.header configure -fg white
			set nodeMode($winId) "kill_cols_from $hitFrame"
		} "kill_cols_from *" {
			set end [lindex $nodeMode($winId) 1]
			set endList [split $end .]
			set indexList [split $hitFrame .]
			for {set numberSame 0} \
					{$numberSame < [llength $endList] && \
					![string compare [lindex $endList $numberSame] \
					[lindex $indexList $numberSame]]} \
					{incr numberSame} {
			}
			set commonFrame [join [lrange $endList 0 [expr $numberSame-1]] .]
			if {$numberSame == [llength $endList] || \
					$numberSame == [llength $indexList]} {
				KillFrame $winId $commonFrame
			} else {
				set highestList [pack slaves $commonFrame]
				set endPt [lsearch $highestList \
						$commonFrame.[lindex $endList $numberSame]]
				set indexPt	[lsearch $highestList \
						$commonFrame.[lindex $indexList $numberSame]]
				if {$endPt < $indexPt} {
					set loPt $endPt
					set loList $endList
					set hiPt $indexPt
					set hiList $indexList
				} else {
					set hiPt $endPt
					set hiList $endList
					set loPt $indexPt
					set loList $indexList
				}
				set loFrame $commonFrame
				foreach subFrame [lrange $loList $numberSame end] {
					set loPt [lsearch $highestList $loFrame.$subFrame]
					for {set zap [expr $loPt+1]} {$zap < $hiPt} \
							{incr zap} {
						KillFrame $winId [lindex $highestList $zap]
					}
					set loFrame $loFrame.$subFrame
					set highestList [pack slaves $loFrame]
					set hiPt [llength $highestList]
				}
				KillFrame $winId $loFrame
				set highestList {}
				set hiFrame $commonFrame
				foreach subFrame [lrange $hiList $numberSame end] {
					set hiPt [lsearch $highestList $hiFrame.$subFrame]
					for {set zap 0} {$zap < $hiPt} {incr zap} {
						KillFrame $winId [lindex $highestList $zap]
					}
					set hiFrame $hiFrame.$subFrame
					set highestList [pack slaves $hiFrame]
				}
				KillFrame $winId $hiFrame
			}
			set nodeMode($winId) none
			$winId.fiddle.intro configure -text {}
		} write_node {
			set frameId [winfo name $hitFrame]
			if {[info exists status($frameId)]} {
				set message "Now click on a node \
						in the model which is to receive data from \
						this column."
				set nodeMode($winId) "write_to $frameId"
			# if you can't guess, the next exciting installment of this
			# story can be found in the 'click' procedure
			} else {
				set message "Please pick a top level (node caption) \
						header for this operation."
			}
			$winId.fiddle.intro configure -text $message
		}
	}
}

# When a frame is deleted, this removes any listboxes it may have contained
# from the list of things affected by the vertical scrollbar...and bumps it off.

proc KillFrame {winId frame} {
    variable yscrollers
    global [namespace current]::${winId}::status

# puts "killing $frame from [array get status]"

    # only kill visible frames, i.e., those with header labels
    if {[winfo exists $frame.header]} {
	while {[set tgt [lsearch -glob $yscrollers($winId) ${frame}*]] != -1} {
	    set yscrollers($winId) [lreplace $yscrollers($winId) $tgt $tgt]
	}
	# If frame corresponded to a node, node is removed from database.
	set record [winfo name $frame]
	if {[info exists status($record)]} {
	    unset status($record)
	}
	destroy $frame
    }
}

# ReadFile will add any new headers and lines to the existing stuff

proc ReadFile {winId} {
	variable cf
	variable maxdims
	variable fillers

	global [namespace current]::${winId}::status

    set inFile [ChooseFile tabular.csv "Name for tabular file" 0]
	set in [open $inFile r]

	# Go through header lines
	set lineIn {}
	set headerDepth 0
	while {![string match Time,* $lineIn]} {
		gets $in lineIn
		set headers([incr headerDepth]) [split $lineIn ,]
	}
	while {$headerDepth > $maxdims($winId)} {
		incr maxdims($winId)
		foreach spacer $fillers($winId) {
			pack [label $spacer.stuffing$maxdims($winId)]
		}
	}
	for {set across 1} {$across < [llength $headers(1)]} {incr across} {
		for {set down 1} {$down <= $headerDepth} {incr down} {
			set header [lindex $headers($down) $across]
			if {![string compare $header {}]} continue
			if [regexp {^(.+) \((read|write|none)\)$} $header spare \
					title mode] {
				set frameName nodebox[incr status(nodeCount)]
				set nodeId [GetIdFromCaptionPath $title]
				if {[string compare $nodeId nomatch]} {
					set status($frameName) \
							[list $nodeId $title $mode]
				} else {
					set status($frameName) [list $nodeId $title none]
				}
				set newBox [frame $cf($winId).$frameName]
				pack $newBox -side left -fill y -expand true
				pack [frame $newBox.fill] 
				lappend fillers($winId) $newBox.fill
				for {set pad 1} \
						{$pad < $down+$maxdims($winId)-$headerDepth} \
						{incr pad} {
					pack [label $newBox.fill.stuffing$pad]
				}
				set headerList $frameName
			} else {
				set title $header
				set frameName h[expr 999999999+$header]
				set headerList [lrange $headerList 0 \
						[expr $down-$headerDepth]]
				lappend headerList $frameName
				set newBox [frame $cf($winId).[join $headerList .]]
				pack $newBox -side left -fill y -expand true
			}
			set title [label $newBox.header -text $title -relief sunken]
			pack $title -fill x
			bind $title <Button-1> [namespace code [list MarkTitle \
					$winId $newBox]]

			if {$down == $headerDepth} {
				InsertListBox $winId $newBox.t [string match $mode write]
				lappend newListboxes $newBox.t
			}
		}
	}
	# OK, now the easy bit, actually inserting the stored data into the boxes...
	set targetRow -1
	set scale $winId.timeframe.text
	while {![eof $in]} {
		gets $in lineIn
		set numberLine [split $lineIn ,]
		set time [lindex $numberLine 0]
		while {[incr targetRow] < [$scale index end]} {
			set lineTime [$scale get $targetRow]
			if {$time < $lineTime+0.000001} {
				break
			}
			# Otherwise time has skipped over this line so add a blank
			# to all new columns...
			foreach currentNode $newListboxes {
				# Stuff in a blank line
				AddBlankToAll $currentNode $targetRow 1
			}
		}
		if {$time != $lineTime} {
			# This time is to be inserted; add blanks to all then remove
			# them again from the new rows
			$scale insert $targetRow $time
			AddBlankToAll $cf($winId) $targetRow 1
			foreach currentNode $newListboxes {
				$currentNode delete $targetRow $targetRow
			}
		}
		# now put new values from file in
		for {set column 1} {$column < [expr [llength $numberLine] - 1]} \
				{incr column} {
			[lindex $newListboxes [expr $column-1]] insert $targetRow \
					[VarPrecRender [lindex $numberLine $column]]
		} 
	}
}

# This writes the contents of the table to a file in .csv format. Each column in
# the display is separated by a comma, wide columns have extra commas indicating
# the number of the narrowest columns they cover. Headers have (read) or (write)
# appended to them to indicate their status.

proc WriteFile {winId} {
	variable maxdims
	variable cf

    set outFile [ChooseFile tabular.csv "Name for tabular file" 1]
	set out [open $outFile w]

	# Go through header lines
	for {set column 1} {$column<=$maxdims($winId)} {incr column} {
		# write leftmost column
		if {$column == $maxdims($winId)} {
			append lineout Time,
		} else {
			append lineout ,
		}
		# write other columns
		foreach targetFrame [pack slaves $cf($winId)] {
			AddHeadersToLine $winId $targetFrame lineout \
					[expr $maxdims($winId)-$column]
		}
		puts $out $lineout
		unset lineout
	}
	# write data fields
	for {set column 0} {$column<[$winId.timeframe.text index end]} {incr column} {
		append lineout [$winId.timeframe.text get $column],
		foreach targetFrame [pack slaves $cf($winId)] {
			AddEntriesToLine $targetFrame lineout $column
		}
		puts $out $lineout
		unset lineout
	}
	close $out
}

# This takes a frame id and a number indicating how many lines above the lowest
# level header line we are writing. It recursively creates a field for each
# subframe, separated by commas, and joins them up so there are the same number of
# commas as lowest-level headers. During the joining process, it counts the levels
# going up from the lowest, and adds the headers themselves when it reaches the
# level corresponding to the line being written. For node headers, the status is
# also added in brackets.

# The line is returned by upvar, because the return value is the number of lines
# we are currently above the lowest header level.

proc AddHeadersToLine {winId targetFrame fillThis linesToHeader} {
	global [namespace current]::${winId}::status

	upvar 1 $fillThis lineout
	set fillThat {}
	# Add a comma for each bottom-level header
	if {[winfo exists $targetFrame.t]} {
		set fillThat ,
		set depth 0
	} else {
		set depth 1
		foreach subFrame [pack slaves $targetFrame] {
			if {[winfo exists $subFrame.header]} {
				set newDepth [expr [AddHeadersToLine $winId $subFrame \
						fillThat $linesToHeader] + 1]
				if {$newDepth > $depth} {
					set depth $newDepth
				}
			}
		}
	}
	# prepend header text, with status if a node header
	if {$depth == $linesToHeader} {
		append lineout [$targetFrame.header cget -text]
		set possNodeName [winfo name $targetFrame]
		if {[info exists status($possNodeName)]} {
			# This is a node title, append read/write info
			append lineout { } ( [lindex $status($possNodeName) 2] )
		}
	}
	append lineout $fillThat
	unset fillThat
	return $depth
}

proc AddEntriesToLine {targetFrame fillThis lineNo} {
	upvar 1 $fillThis lineout
	if {[winfo exists $targetFrame.t]} {
		append lineout [$targetFrame.t get $lineNo],
	} else {
		foreach subFrame [pack slaves $targetFrame] {
			AddEntriesToLine $subFrame lineout $lineNo
		}
	}
}

proc FillColumns {winId targetFrame refValues insertPoint \
	createLine updateList} {
    variable latestLine

    upvar 1 $refValues values
# global debug
# puts "fill $targetFrame $values $insertPoint $createLine $updateList"
    switch [llength $values] {
	0 {
	    return 0
	} 1 {
	    if {![winfo exists $targetFrame.t]} {
		InsertListBox $winId $targetFrame.t $updateList
	    }
	    # Append blank lines to make frame same length as time frame
	    while {[$targetFrame.t index end]+$createLine < \
		    [$winId.timeframe.text index end]} {
		$targetFrame.t insert end {}
	    }
	    if {$updateList} {
		if {$createLine} {
		    $targetFrame.t insert $insertPoint {}
		} else {
		    set newValue [$targetFrame.t get $insertPoint]
		    if {[string compare $newValue {}]} {
			set values $newValue
		    }
		}
	    } else {
		if {!$createLine} {
		    $targetFrame.t delete $insertPoint
		}
		$targetFrame.t insert $insertPoint [VarPrecRender $values]
	    }
	    return 0
	} default {
	    set depth 0
	    set oldPointer 0
	    set oldContents [pack slaves $targetFrame]
	    for {set indx 0} {$indx < [llength $values]} {incr indx 2} {
		set subscript [lindex $values $indx]
		set targetPoint [expr $indx+1]
		set newSublist [lindex $values $targetPoint] 
		
		if {[string match indexed $insertPoint]} {
		    set nextFrame $targetFrame
		    set subCreateLine [expr ![ResetInsertPoint $winId \
			    $subscript [winfo name $nextFrame] {}]]
		    set subInsertPoint $latestLine($winId)
		} else {
		    set subCreateLine $createLine
		    set subInsertPoint $insertPoint
		    
		    set headerId {}
		    foreach index $subscript {
			lappend headerId [expr 999999999+$index]
		    }
		    set nextFrame $targetFrame.h$headerId
		    set comparison -1
		    while {$comparison == -1 && \
			    [llength $oldContents] > $oldPointer} {
			set prevFrame [lindex $oldContents $oldPointer]
			if {[IsFrame $prevFrame]} {
			    set comparison [string compare \
				    $prevFrame $nextFrame]
			    if {$comparison == -1} {
				AddBlankToAll $prevFrame $insertPoint \
					$createLine
				incr oldPointer
			    }
			} else {
			    incr oldPointer
			}
		    }
		    if {$comparison} {
			if { $comparison == 1} {
			    # Insert frame amongst contents
			    pack [frame $nextFrame] -side left -fill y -expand true \
				    -before $prevFrame
			} else {
			    # At end of old contents
			    pack [frame $nextFrame] -side left -fill y -expand true
			}
			set title [label $nextFrame.header -text $subscript \
				-relief sunken]
			pack $title -fill x
			bind $title <Button-1> [namespace code \
				[list MarkTitle $winId $nextFrame]]
			
		    } else {
			incr oldPointer
		    }
		}
		set newDepth [FillColumns $winId $nextFrame newSublist \
			$subInsertPoint $subCreateLine $updateList]
		if {$newDepth > $depth} {set depth $newDepth}
		if {$updateList} {
		    set values [lreplace $values $targetPoint $targetPoint \
			    $newSublist]
		}
	    }

	    if {[string match indexed $insertPoint]} {
		return $depth
	    } else {
		# now just fill out any spare columns on the right
		
		while {[llength $oldContents] > $oldPointer} {
		    set prevFrame [lindex $oldContents $oldPointer]
		    AddBlankToAll $prevFrame $insertPoint $createLine
		    incr oldPointer
		}
		return [expr $depth+1]
	    }
	}
    }
}

# This confers editability on the active line of a listbox. Because Tcl does not
# allow manipulation of listbox text this has to be done by pulling the elt out,
# editing it and stuffing it back. There is no cursor, only the end of the line
# can be played with.

proc AddEditBindings {lb} {
	bind $lb <Button-1> {focus %W}
	bind $lb <Delete> [namespace code {AttackActive %W del}]
	bind $lb <BackSpace> [namespace code {AttackActive %W del}]
	bind $lb <Control-Delete> [namespace code {AttackActive %W wipe}]
	bind $lb <Key> [namespace code {AttackActive %W %A}]
}

proc AttackActive {lb act} {
	set elmnt [$lb index active]
	set text [$lb get $elmnt]
	switch $act {
		wipe {
			set text {}
		} del {
			set text [string range $text 0 [expr [string length $text]-2]]
		} default {
			append text $act
		}
	}
	$lb delete $elmnt
	$lb insert $elmnt $text
	$lb activate $elmnt
}

proc IsFrame {entity} {
	expr [string compare [winfo class $entity] Frame] == 0
}

proc AddBlankToAll {frame insertLine createLine} {
	set contents [winfo children $frame]
	foreach subframe $contents {
		if {[string compare [winfo class $subframe] Listbox]} {
			AddBlankToAll $subframe $insertLine $createLine
		} else {
			if {!$createLine} {
				$subframe delete $insertLine
			}
			$subframe insert $insertLine {}
		}
	}
}

proc ResetInsertPoint {winId value readNodes writeNodes} {
    variable cf
    variable latestLine

    set scale $winId.timeframe.text
    set lineTime [$scale get $latestLine($winId)]
    while {[SmallerList $value $lineTime]} {
	incr latestLine($winId) -1
	set lineTime [$scale get $latestLine($winId)]
    }

    while {[incr latestLine($winId)] < [$scale index end]} {
	set lineTime [$scale get $latestLine($winId)]
	if {[SmallerList $value  $lineTime]} {break}
# Otherwise time has skipped over this line so eradicate its contents
# or collect updates if writing to model...
	foreach currentFrame $readNodes {
# Stuff in a blank line (line must exist, so overwrite it?)
	    AddBlankToAll $cf($winId).$currentFrame \
		    $latestLine($winId) 0
	}
	foreach currentFrame $writeNodes {
# Get any new values from the line being skipped
# (This can happen several times, model is updated with table made from
# all of them)
	    FillColumns $winId $cf($winId).$currentFrame \
		    values($currentFrame) $latestLine($winId) 0 1
	}
    }
    if {[set overwrite [string match $value $lineTime]]} {
	$scale delete $latestLine($winId)
    }
    $scale insert $latestLine($winId) $value ;# not VarPrecRendered
    $scale see $latestLine($winId)
    return $overwrite
}

proc SmallerList {foo bar} {
    if {![llength $foo]} {
	return 1
    } elseif {![llength $bar]} {
	return 0
    } elseif {[lindex $foo 0] == [lindex $bar 0]} {
	return [SmallerList [lrange $foo 1 end] [lrange $bar 1 end]]
    } else {
	return [expr [lindex $foo 0]<[lindex $bar 0]]
    }
}

proc display {winId time display remainder} {
    variable cf
    variable latestLine
    variable nodeMode
    variable maxdims
    variable fillers

    global [namespace current]::${winId}::status

    # First list the nodes we are reading and writing, and get the original
    # values for those we are writing...

    set readNodes {}
    set writeNodes {}
    foreach currentFrame [array names status] {
	switch [lindex $status($currentFrame) 2] {
	    write {
		lappend writeNodes $currentFrame
		set values($currentFrame) \
			[lindex [GetModelValue \
			[lindex $status($currentFrame) 0]] 0]
	    } read {
		lappend readNodes $currentFrame
	    }
	}
    }
    
    if {[string match Index $nodeMode($winId,action)]} {
	set overwrite 1
	set insertPoint indexed
    } else {
	set overwrite [ResetInsertPoint $winId $time \
		$readNodes $writeNodes]
	set insertPoint $latestLine($winId)
    }
    
    # Now the line for the current time. Writes before reads, so if I have
    # one of each, the read column gets the values from the write column
    foreach currentFrame $writeNodes {
	FillColumns $winId $cf($winId).$currentFrame values($currentFrame) \
		$insertPoint [expr !$overwrite] 1
	SetModelValue [lindex $status($currentFrame) 0] $values($currentFrame)
    }
    foreach currentFrame $readNodes {
	set readValues [lindex [GetModelValue \
		[lindex $status($currentFrame) 0]] 0]
	set readBox $cf($winId).$currentFrame
	set dims [FillColumns $winId $readBox \
		readValues $insertPoint [expr !$overwrite] 0]
	while {$dims > $maxdims($winId)} {
	    incr maxdims($winId)
	    foreach spacer $fillers($winId) {
		pack [label $spacer.stuffing$maxdims($winId)]
	    }
	}
	foreach fillSlot [winfo children $readBox.fill] {
	    scan $fillSlot $readBox.fill.stuffing%d fillLevel
	    if {$fillLevel<=$dims} {
# Next line used to be "destroy $fillslot" but this caused hang in mre, so...
		pack forget $fillSlot
	    }
	}
    }
}

proc Done {winId} {
	variable value
	RandomInit $value
	kill_helper_window $winId
}

} ;# end of namespace
