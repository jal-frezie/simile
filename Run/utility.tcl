# Simile source code file: Run/utility.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains general purpose utilities, which are used both in 
# the model diagram editor and the stand-alone run time environment.

# Thanks to tk_abandon, I sometimes put several dialogues up at once, which,
# thanks to a bug in tcltk, gets the wrong results for the lower ones...

proc ShowMess { title icon string resps {parent {}}} {
    set mBoxCmd [list tk_messageBox -title $title -icon $icon \
		     -message $string -type $resps]
    if {[winfo exists .splash]} {
	destroy .splash ;# ensure mess is not obscured by splash screen
    }
    RemovePopup
    set progressUp [winfo exists .progress]
    if {$progressUp} { ;# avoid yet another potential MacOS stuffup
	set progBag [wm transient .progress]
	set progMess [.progress.message cget -text]
	CloseProgressBox
    }
    set active [focus]
    if {[string length $parent]>0} {
	lappend mBoxCmd -parent $parent
    } elseif {[string length $active]>1} { ;# window . is hidden so must not
	lappend mBoxCmd -parent [winfo toplevel $active]
    }
    set act [eval $mBoxCmd]
    if {$progressUp} {
	OpenProgressBox $progBag
	.progress.message configure -text $progMess
    }
    update idletasks
    return $act
}

# ChooseFile -- this is a wrapper for the Tcl file dialog, which sets
# the path name to start looking in explicitly as use of the
# -initialdir switch under Linux causes horrible misbehaviour if the
# filename has spaces in it.

proc ChooseFile { preferred title canbenew context} {
    global __tk_filedialog preSelect

    set fileType [file extension $preferred]
#    set __tk_filedialog(selectPath) [do_in_editor GetPathChoice $fileType]

# __tk_etc should set starting directory, but just in case...
#    set prevDir [pwd]
#    cd $__tk_filedialog(selectPath)
    switch $fileType {
	.sml {
	    set typeList [list .sml .sim .ame]
	    set desc [tr. Models]
	} .gif {
	    set typeList [list .gif .jpg .JPG .jpeg .png .tif .tiff]
	    set desc [tr. Images]
	} {} {
	    set typeList {}
	    set desc [tr. Directories]
	} .cpp {
	    set typeList [list .cpp .c .h]
	    set desc [tr. "Source or header files"]
	} .txt {
	    set typeList [list .txt]
	    set desc [tr. "Text files"]
	} .csv {
	    set typeList [list .csv .xls .xlsb .xlsm .xlsx .mdb .dbf *.db]
	    set desc [tr. "Data files" ]
	} .spf {
	    set typeList [list .spf .smf]
	    set desc [tr. "Parameter or measurement metafiles" ]
	} .smf {
	    set typeList [list .spf .smf]
	    set desc [tr. "Parameter or measurement metafiles" ]
	} .txt {
	    set typeList [list .bgx]
	    set desc [tr. "Idiosyncratic polygon vertices"]
	} default {
	    set typeList [list $fileType]
	    set desc "$fileType [tr. files]"
	}
    }
    set typeList [list [list $desc $typeList] [list [tr. {All files}] *]]
    set currentDir [do_in_editor GetPathChoice $fileType $context]
#puts "Got path for $context"
    if {[info exists preSelect]} {
	set chosenFile $preSelect
	unset preSelect
    } else {
	set switches [list -title $title -defaultextension $fileType \
			  -filetypes $typeList \
			  -initialdir $currentDir]
	set active [focus]
	if {[tk windowingsystem] eq "aqua"} {
	    lappend switches -message $title ;# -title does not show!
	} elseif {[llength $active]} {
	    # Problems on Aqua if parent is itself modal
	    lappend switches -parent [winfo toplevel $active]
	}
	if {$canbenew} {
	    set cmd tk_getSaveFile
	    lappend switches  -initialfile $preferred
	} else {
	    set cmd tk_getOpenFile
	}
#ShowMess debug info "will eval $cmd $switches" ok
	set chosenFile [eval $cmd $switches]
    }
    
#    cd $prevDir
#puts "Recording path for $context"
    if {[string length $chosenFile]} {
# Now work around a MacTcl bug whereby sometimes the path returned includes
# the preferred file as the directory...
	set chosenDir [file dirname $chosenFile]
	if {[file isfile $chosenDir]} {
	    set choice [file tail $chosenFile]
	    set chosenFile [file join [file dirname $chosenDir] $choice]
	    if {[file exists $chosenFile] && [tk_messageBox -icon warning -message "\"$choice\" already exists. Do you want to replace it?" -detail "A file or folder with the same name already exists in the folder [lindex [split $chosenFile /] end-1]. Replacing it will overwrite its current contents." -type okcancel -default cancel] eq "cancel"} { ;# replicate existence warning
		return [ChooseFile $chosenFile $title $canbenew $context]
	    } 
	}
	do_in_editor RecordPathChoice $fileType $chosenFile $context
    }
    return $chosenFile
}

proc linkableExt {defLib} {
    if {[string equal .dll $defLib]} {
	set defLib .a
    }
    return $defLib
}

# utility procedure to fill in some holes in Tcl8.0

proc ChooseText {choice ifTrue ifFalse} {
    if {$choice} {
        return $ifTrue
    } else {
        return $ifFalse
    }
}

# takes two file names (NOT dirs) and returns the second relative to the first

# using fileutil instead for now
proc Relativize  {current remote} {
    return [::fileutil::relative [file dirname $current] $remote]
}

#proc Relativize {current remote} {
#    #	ShowMess debug info "relativizing $current $remote" ok
#    set currentList [file split $current]
#    set remoteList [file split $remote]
#    set parted 0
#    set base {}
#    for {set sameCount 0} {$sameCount < [llength $currentList]} {incr sameCount} {
#        if {$parted} {
#            lappend base ..
#        } elseif {[string compare [lindex $currentList $sameCount] \
#                    [lindex $remoteList $sameCount]]} {
#            set tail [lrange $remoteList $sameCount end]
#            set parted 1
#        }
#    }
#    return [eval {file join} $base $tail]
#}

# reverses the above
proc Relate {startPt offset} {
    return [file join [file dirname $startPt] $offset]
}

# This deals with the quirk of Netware file systems that if the user has
# read/write access to a file it cannot be opened readonly, or something...

proc NetOpen {name way} {
    if {[catch {open $name $way} stream]} {
	set err $stream
	if {[catch {open $name r+} stream]} {
	    error "Could not open $name $way or r/w -- $err"
	}
    }
    return $stream
}

proc IdentField {text field} {
    global userinfo

    set field0 [expr {[string first ,${field}= $text]+[string length $field]+2}]
    set fieldEnd [expr {[string first , $text $field0]-1}]
    string range $text $field0 $fieldEnd
}

proc AdjustCanvas {winId pt dir args} {
#    global noScroll
    set tgt $winId.${dir}scroll
# hide scrollbar if full size...even the most mundane procedure can act as
# the trigger to unleash gibbering weirdness. Occasionally, a textbox will
# send a non-full scrollbar move even when it isn't full, in which case adding
# the scrollbar and thus shrinking its window will make it send another request
# this time a full one, removing the scrollbar again and starting a loop. To
# avoid this, do not display the scrollbar till two requests are received.

# system disabled due to unlikelihood of using TclTk 8.5 before this is fixed

    if {[lindex $args 0]<0.01 && [lindex $args 1]>0.99} {
#	set noScroll($winId,$dir) 1
	pack forget $tgt
    } else {
#	if {[info exists noScroll($winId,$dir)]} {
#	    unset noScroll($winId,$dir)
#	    return
#	}
	if {[string match x $dir]} {
	    set placing {-side bottom -after $winId.$pt}
	} else {
	    set placing {-side right -before $winId.$pt}
	}
	eval {pack $tgt} $placing {-fill $dir}
	eval {$tgt set} $args
    }
}

proc CopyCanvasToWindowsClipboard {canvas seln_only} {
    global tcl_platform selnImages simtmpdir
    
    if {[string match windows $tcl_platform(platform)]} {
        package require gdi
        package require printer
        package require wmf
        

        set hdc [wmf open]; #Opens a memory metafile
        if {$seln_only} {
	    ::printer::print_select $hdc $canvas withtag tocopy
	} else {
	    ::printer::print_canvas $hdc $canvas
	}
        set wmfdc [ wmf close $hdc ]; # Turn the context into a metafile handle
        wmf copy $wmfdc; # Copy to the clipboard
    } elseif {[string match Linux $tcl_platform(os)]} { 
# unix: own clipboard and set up request handler
	package require img::window
	update ;# get canvas displayed again
	# Easy, teenage, New York version
	#clipboard clear
	#set img [image create photo -format window -data $canvas]
	#clipboard append -type "image/png" [$img data -format png]
	
	if {[catch {image create photo -format window -data $canvas} img]} {
	    Query [list get_graphics_failed $img] warning top {} ok
	} else {
	    # now if I just get it to yack up the data like this...
	    #set selnImages [$img data -format png]
	    # it converts it to base64 which other apps go derrr over
	    # so put in file and reread for all gory 8bit details
	    set hi8dump [file join $simtmpdir temp_out.bmp]
	    $img write $hi8dump -format bmp

	    set feed [open $hi8dump r]
	    fconfigure $feed -translation binary
	    set selnImages [read $feed]
	    close $feed

	    selection handle -selection CLIPBOARD -type image/bmp . Regurgitate
	    selection handle -selection CLIPBOARD -type text/uri-list . SpitURI
	    selection own -selection CLIPBOARD .
	}
    }
}

proc Regurgitate {{offset 0} {blksize 100}} {
    global selnImages
#    puts "Off $offset, size $blksize."
    set sought [string range $selnImages $offset [expr {$offset+$blksize-1}]]
#    puts "Sending $sought"
    return $sought
}

proc SpitURI {{offset 0} {blksize 100}} {
    global simtmpdir

    set hi8dump [file join $simtmpdir temp_out.bmp]
    return file://$hi8dump
}

# Easy, teenage, New York version that works for any canvas rather than
# being specialized for model diagrams

proc PrintRandomCanvas {canvas} {
    global tcl_platform simtmpdir env
    if {[string match windows $tcl_platform(platform)]} {
	package require gdi
        package require printer
        printer::print_widget $canvas 0
    } else {    
        set tempPSFile $simtmpdir/temp.ps
	set strm [NetOpen $tempPSFile w]
	puts $strm [$canvas postscript]
	close $strm
	exec $env(PRINTCMD) [file nativename $tempPSFile]
        file delete $tempPSFile
    }
}
	
# Export a postscript file from a window. Only the bit of the diagram showing in
# the viewport is included, and the output is in landscape mode, sized so 100
# pixels = 1 inch (so my beautiful 1152x864 screen will be about a sheet of A4)

proc PostScrog { win node format} {
    set tgt [ChooseFile image.$format [tr. "Name of graphics file:"] 1 $node]
    # check for cancel
    if {![string match */ $tgt]} {
        
        # force .ps/.svg extension
        if {[string compare [file extension $tgt] .$format]} {
            set tgt [file root $tgt].$format
        }

	set useWidth [winfo width $win]
	set useHeight [winfo height $win]
    
	switch $format {
	    ps {
		$win postscript -file $tgt -rotate true -pageanchor nw \
		    -pagex 0 -pagey 0 -width $useWidth -height $useHeight \
		    -pagewidth [expr $useWidth/100.0]i \
		    -pageheight [expr $useHeight/100.0]i
	    } svg {
		package require can2svg
		set scrogion [$win cget -scrollregion]
		if {[llength $scrogion]} {
		    foreach {l t r b} $scrogion break
		} else {
		    foreach {l t r b} [list 0 0 [winfo width $win] [winfo height $win]] break
		}
		set xpos [$win xview]
		set ypos [$win yview]
		$win configure -scrollregion [list 0 0 [expr $r-$l] [expr $b-$t]]          
		$win move all [expr -$l] [expr -$t]
		can2svg::canvas2file $win $tgt
		$win move all $l $t
		$win configure -scrollregion $scrogion
		$win yview moveto [lindex $ypos 0]
		$win xview moveto [lindex $xpos 0]
	    }
	}
    }
}

# popup stuff -- here because both model windows and helpers use them

proc BindPopup {widget args} {
# any % will be subbed by binding process unless we double it
    regsub -all % $args %% keyWd
    bind $widget <Enter> [concat [list QueuePopup AddWidgetPopup %W %X %Y] $keyWd]
    bind $widget <Leave> RemovePopup
}

proc MenuBindPopup {widget keyList} {
# any % will be subbed by binding process unless we double it
    regsub -all % $keyList %% keyList
    bind $widget <Enter> [list QueuePopup \
            AddMenuPopup $widget $keyList %y %X %Y 1]
    bind $widget <Motion> [list AddMenuPopup $widget $keyList %y %X %Y 0]
    bind $widget <Leave> RemovePopup
#    bind $widget <<MenuSelect>> {puts see-lected1}
    # only one working in Aqua but not until menu is closed so no use
}

proc QueuePopup {args} {
    global popper
    # Only allow one cmd in pipeline at a time -- two added if dragging an
    # incomplete obj which Prolog then deletes (Tk bug workaround - 10 points)
    if {[info exists popper(cmd)]} {
        after cancel $popper(cmd)
    }
    set popper(cmd) [after 500 $args]
    bind all <Motion> "set popper(latestX) %X; set popper(latestY) %Y"
# seems not needed in recent Mac TclTks
#    if {![winfo exists .popup]} {
#	set popper(foc) [focus]
#    }
}

proc AddWidgetPopup {wid X Y args} {
    global msgs
    if {![PrefValue custom(popupHelp) popupHelp]} {
	return
    }
    PostPopup $wid $X $Y
    set empty yes
    foreach key $args colour {#ffffc0 #c0ffc0 #ffe0c0} {
	if {[info exists msgs($key)]} {
	    set message $msgs($key)
	} else {
	    #	    regsub -all % $key %% message ;# err, too late now
	    set message $key
	}
	if {![string is space $message]} {    
	    AddPopupMessage $message $colour
	    set empty no
	}
#    pack [message .popup.message -aspect 400 \
#            -text $message -bg \#ffffc0] -fill x -expand true
    }
    if {$empty} RemovePopup
}

proc AddMenuPopup {widget list y X Y new} {
    global msgs

    if {![PrefValue custom(popupHelp) popupHelp]} {
	return
    }
    if {$new} {
        PostPopup $widget $X $Y
	set msg $::popper(cur).popup.message
        pack [message $msg -aspect 400 -bg \#ffffc0] -fill x -expand true
    } else {
	set msg $::popper(cur).popup.message
    }
    
    set entry [$widget index @$y]
    if {[string match none $entry] || ![winfo exists $msg]} {
        return
    }
    if {[llength $list]} {
	set message [lindex $list $entry]
    } else {
	set key [$widget entrycget $entry -label]
	if {[string equal command [$widget type $entry]]} {
	    set key [string range $key 0 end-2]
	}
	if {[info exists msgs($key)]} {
	    set message $msgs($key)
	} else {
	    set message $key
	}
    }
    if {[string equal {} $message]} {
#	destroy .popup
    } else {
	$msg configure -text $message
    }
}

set popper(cur) {}
proc PostPopup {w X Y} {
    global tcl_platform popper

    RemovePopup
    set popper(cur) [winfo toplevel $w]
    set popup $popper(cur).popup
    if {![PrefValue custom(tlPopups) tlPopups]} {
	frame $popup -bd 1 -relief raised
    } elseif [string match Darwin $tcl_platform(os)] {
        toplevel $popup -width 1 -height 1
        ::tk::unsupported::MacWindowStyle style $popup help none
    } else {
        toplevel $popup -width 1 -height 1 -bd 1 -bg black
# leaves one pixel of black showing round edge of messages
        wm overrideredirect $popup 1
    }

    update idletasks
    bind all <Motion> {}
    if {[info exists popper(latestX)]} {
	set X $popper(latestX)
	set Y $popper(latestY)
	array unset popper latest?
    }
    if {![PrefValue custom(tlPopups) tlPopups]} {
	set relx [expr {$X-[winfo rootx $popper(cur)]}]
	if {$relx>[winfo width $popper(cur)]/2} {
	    set xsgn -
	    set xdir e
	} else {
	    set xsgn +
	    set xdir w
	}
	set rely [expr {$Y-[winfo rooty $popper(cur)]}]
	if {$rely>[winfo height $popper(cur)]/2} {
	    set ysgn -
	    set ydir s
	} else {
	    set ysgn +
	    set ydir n
	}
	set offset 10
	place $popup -in $popper(cur) -anchor $ydir$xdir \
	    -x [expr $relx$xsgn$offset] -y [expr $rely$ysgn$offset]
	return
    }
    set xpoint +[expr $X+10]
    set ypoint +[expr $Y+10]
    if {![string match Darwin $tcl_platform(os)]} {
	if {$X>[winfo screenwidth $popup]/2} {
	    set xpoint -[expr [winfo screenwidth $popup]+10-$X]
	}
	if {$Y>[winfo screenheight $popup]/2} {
	    set ypoint -[expr [winfo screenheight $popup]+10-$Y]
	}
    }
    wm geometry $popup ${xpoint}${ypoint}
    raise $popup
}

proc RemovePopup {args} {
    global popper
    #puts "Removing popup"
    if {[winfo exists $popper(cur).popup]} {
        destroy $popper(cur).popup
#	if {[string match aqua [tk windowingsystem]]} {
#	    focus -force $popper(foc)
#	}
    }
    if {[info exists popper(cmd)]} {
        after cancel $popper(cmd)
    }
}

proc AddPopupMessage {text colour args} {
# note the model editor still processes events while waiting for the executable

    # so check window is still there
    set popup $::popper(cur).popup
    if {![winfo exists $popup]} return
    set limit [PrefValue custom(maxPopupSize) maxPopupSize]
    if {[llength $args]} {
	set combo [eval $args $limit]
	set count [lindex $combo 0]
	set text [lindex $combo 1]
    } else {
	set count 0
    }
    set bag $popup.message$colour
    if {[EndsOnly text $count $limit]==-1} {
	pack [text $bag -bd 0 -bg $colour -width 4 -height 1 -wrap none] \
	    -fill both -expand 1
	$bag insert 1.0 $text
	$bag config -xscroll "Rebag $bag width $count" \
	    -yscroll "Rebag $bag height 0"
	# config was done after idle but that blew up if window gone
    } elseif {[string length $text]<20} {
	pack [label $bag -text $text -bg $colour] -fill x -expand true
    } else {
	pack [message $bag -aspect 400 \
		  -text $text -bg $colour] -fill x -expand true
    }
}


proc EndsOnly {outerText count leave} {
    upvar 1 $outerText text
    
    if {$count<0} { ;# not a real value; tell caller to grey it out
	return -1
    }
    set verbosity [string length $text] 
    if {$verbosity>$leave} {
	set size [expr ($leave-20)/2]
	
	if {$count} {
	    set nvals " ($count values)"
	} else {
	    set nvals " ($verbosity characters)"
	}
	set text [string range $text 0 $size].....[string range $text \
						 [expr $verbosity-$size] end]
	append text $nvals
	return 1
    } else {
	return 0
    }
}

proc Rebag {bag axis tab lo hi} {
    #puts "$hi-$lo==1 || [winfo $axis $bag]<[winfo req$axis $bag] ($tab)"
    
    # Note that the appalling TclTk8.6.9 in MacOS can generate a new
    # configure event from a setting change even if the new setting is
    # the same, so check first and don't do it if it is...
    
    if {$hi-$lo==1} return
    set finalWidth [winfo req$axis $bag]
    if {[winfo $axis $bag]<$finalWidth} {
	if {$tab} {
	    set newTab [expr {$finalWidth/-$tab}]
	    if {[$bag cget -tabs]!=$newTab} { 
		$bag configure -tabs $newTab
	    }
	}
	return
    }
    set newSize [expr {round([$bag cget -$axis]/($hi-$lo))}]
    if {[$bag cget -$axis]!=$newSize} {
	$bag configure -$axis $newSize
    }
}

proc ReadGdalRefToList {tableSpec {y {}} {x {}}} {
    package require gdal
#puts "RGRTL $tableSpec $x $y"
    set hg [gdal_open_read_only [lindex $tableSpec 0]]
    set hdl [gdal_get_raster_band $hg 1]
    set l [expr [lindex $tableSpec 4]-1]
    set t [expr [lindex $tableSpec 2]-1]
    set w [expr [lindex $tableSpec 5]-$l]
    set h [expr [lindex $tableSpec 3]-$t]
    if {![Numeric $x]} {
	set x $w
    }
    if {![Numeric $y]} {
	set y $h
    }
    set nValues [gdal_get_raster_values $hdl $l $t $w $h $x $y]    
    gdal_close $hg
    return $nValues
}

proc ShrinkValueList {outerList limit} {
    set manage [expr $limit/4]
    set range [expr $manage/2]
    upvar 1 $outerList list

    if {[string equal ,gdal [lindex $list 1]]} {
	set topRow [lindex $list 2]
	set bottomRow [lindex $list 3]
	set rowCount [expr 1+$bottomRow-$topRow]
	set colCount [expr 1+[lindex $list 5]-[lindex $list 4]]
	set allVals [expr $rowCount*$colCount]
	if {$allVals<=$range} {
	    set list [NumberElements [ReadGdalRefToList $list]]
	} else {
	    set rowEnds [expr int($range/$colCount)]
	    lset list 3 [expr $topRow+$rowEnds]
# first use of Gdal lib for this param -- fail gracefully if not there
	    if {[catch {set startRange [ReadGdalRefToList $list]}]} {
		set list failed_gdal_reference
		return -1 ;# indicates not a real value
	    }
	    lset list 2 [expr $bottomRow-$rowEnds]
	    lset list 3 $bottomRow
	    set endRange [ReadGdalRefToList $list]
	    set list [concat [NumberElements $startRange] \
			  [NumberElements $endRange [lindex $list 2]]\
			  [lrange $list 7 end]]
# transpose not working, or enabled
	}
    } elseif {[string equal ,bytes [lindex $list 1]]} {
# in this case the list format is:
# scenario ,bytes type idx1 ... idxn uftsi restart others raw_data
	if {[lsearch [lrange $list 3 end-4] RECORDS]>=0} {
	    set list "Per-record data specified by byte array"
	    return -1
	}
	if {[string equal REAL [lindex $list 2]]} {
	    set fieldChar d
	    set fieldSize 8
	} else {
	    set fieldChar i
	    set fieldSize 4
	}
	set allVals [expr [string length [lindex $list end]]/$fieldSize]
# fix this up later
	if {[string equal TIME [lindex $list 3]]} {
	    set list "Time series specified by byte array"
	    return -1
	}
	set offset 0
	if {$allVals<$manage} {
	    set fullRange [DoByteArrayToList $fieldChar $fieldSize \
			       [lrange $list 3 end-4] [lindex $list end]]
	    set list [NumberElements $fullRange]
	    return $allVals
	}
	set splitLevel [expr {[llength $list]-4}]
	set availAtLevel 1
	while {$availAtLevel<$range} {
	    set splitBound [lindex $list [incr splitLevel -1]]
	    set availAtLevel [expr $availAtLevel*$splitBound]
	}
	set fatLines [expr int(1+$splitBound*$range/$availAtLevel)]
	set bounds [concat $fatLines [lrange $list [expr $splitLevel+1] end-4]]
	set startRange [DoByteArrayToList $fieldChar $fieldSize $bounds \
			    [lindex $list end]]
	set offset [expr $fieldSize*($allVals - \
					 $fatLines*$availAtLevel/$splitBound)]
	set endRange [DoByteArrayToList $fieldChar $fieldSize $bounds \
			    [lindex $list end]]
	set list [concat [NumberElements $startRange] \
		      [NumberElements $endRange [expr 1+$splitBound-$fatLines]]]
    } else {    
	set allVals [CountValues $list]
	if {$allVals>$manage} {
	    set startRange [GetNVals $list first $range]
	    set endRange [GetNVals $list last $range]
	    set list [concat $startRange $endRange]
	}
    }
    return $allVals
}

proc DoByteArrayToList {fieldChar fieldSize bounds rawData} {
    upvar 1 offset offset
    if {[llength $bounds]==1} {
	set fieldSpec @${offset}${fieldChar}${bounds}
#puts $fieldSpec
	if {![binary scan $rawData $fieldSpec spit]} {
	    set spit {<scan failed>}
	    error "Failed to scan $rawData for $fieldSpec"
	}
	incr offset [expr $fieldSize*$bounds]
    } else {
	set subBounds [lrange $bounds 1 end]
	set spit {}
	for {set outer 0} {$outer<[lindex $bounds 0]} {incr outer} {
	    lappend spit [DoByteArrayToList $fieldChar $fieldSize \
			      $subBounds $rawData]
	}
    }
    return $spit
}

proc NumberElements {list {startNum 1}} {
    if {[string equal $list [lindex $list 0]]} {
	return $list
    } else {
	set result {}
	set num [incr startNum -1]
	foreach elt $list {
	    if {[llength $elt]} {
		lappend result [incr num] [NumberElements $elt 1]
	    }
	}
	return $result
    }
}

proc GetNVals {list side need} {
    set subLength -1 ;# first value to try will be 1
    set got 0
    while {$got<$need} {
	incr subLength 2
	if {[string equal first $side]} {
	    set startList 0
	    set endList $subLength
	} else {
	    set startList end-$subLength
	    set endList end
	}
	set subList [lrange $list $startList $endList]
	set got [CountValues $subList]
    }
    if {$subLength==1} {
	return [list [lindex $list $startList] \
			[GetNVals [lindex $list $endList] $side $need]]
    } else {
	return $subList
    }
}
	
proc CountValues {text} {
    set len [llength $text]
    if {$len==1} {
        return 1
    } else {
        set tot 0
	foreach {n v} $text {
            incr tot [CountValues $v]
        }
        return $tot
    }
}

proc SquirtMime {args} {
    global mimeSquirter


    if {[string match end [lindex $args 0]]} {
        close $mimeSquirter
    } elseif {[string match error [lindex $args 0]]} {
        error [lindex $args 1]
    } else {
        puts -nonewline $mimeSquirter [lindex $args 1]
    }
}

proc LoadIconImages {} {
    global iconImages
    foreach fn {tick cross function} {
	set iconImages($fn) \
	    [image create photo -file "../Images/Eqnbar/${fn}.gif"]
    }
    foreach fn {graph table new open save edit reel noreel text zap \
		    submodel compartment flow variable condition \
		    creation reproduction immigration loss alarm} {
        set iconImages($fn) \
	    [image create photo -file "../Images/Toolbar/${fn}.gif"]
    }
    if {[info exists ::do_events]} {
	foreach fn {event state squirt} {
	    set iconImages($fn) \
		[image create photo -file "../Images/Toolbar/${fn}.gif"]
	}
    }
    foreach icon {info question warning error} {
	set iconImages($icon) \
	    [image create photo -file "../Images/Icons/dialog-$icon.png"]
    }
}

proc BlankCrs {withCrs} {
    regsub -all \n $withCrs { } noCrs
    return $noCrs
}

proc StripCrs {withCrs} {
    regsub -all \n $withCrs \\n noCrs
    return $noCrs
}

proc EscapeNasties {str} {
# straight from tcl regsub docs
# this has the advantage of not needing a reverse substitution
#    return [subst [regsub -all {[][{};\#\\\$\s\u0080-\uffff]} $withBads \
#		       {[format \\\\u%04x [scan & %c]]}]]
# This one is all my own work -- does % as well cos that messes formatting
    set RE {][{};\"\#\\\$\%\s\u0080-\uffff} ;# everything "bad"
    set scn [regsub -all \[$RE\] $str %c]
    set fmt [regsub -all \[$RE\] $str {\u%04x}]
    return [eval [list format $fmt] [scan $str $scn]]
}

proc RestoreCrs {noCrs} {
    regsub -all \\\\n $noCrs \n withCrs

    return $withCrs
}

#proc min {first last} {
#    return [expr $first<$last?$first:$last]
#}
#
#proc max {first last} {
#    return [expr $first>$last?$first:$last]
#}
#
# "string is double" returns TRUE for {} so use this instead
proc Numeric {str} {
    return [string is double -strict $str]
}

# This takes care of the ways of getting a good-looking transient
# window on different platforms. Currently the extra MacOS command is
# necessary to make sure dialogue boxes have titlebars, but if there
# is no parent window it instead stops entry widgets in the dialogue
# boxes getting text, and leads to a hang

proc PutItThere {t parent} {
    global tcl_platform
    toplevel $t -bd 4
    if {[winfo exists $parent] && [string compare . $parent]} {
	wm transient $t $parent
    } else {
	wm transient $t
    }
    if [string match Darwin $tcl_platform(os)] {
	::tk::unsupported::MacWindowStyle style $t moveableModal resizable
# was floatGrowProc but that crashed when messageboxes opened inside
#	::tk::unsupported::MacWindowStyle style $t moveableModal {}
	if {[string length $parent]} {
#	    AbleAllEntries $parent disabled
	    set ::concealedMenu($t) [[winfo toplevel $parent] cget -menu] 
#	    puts "Saving $::concealedMenu($t) for $t"
	    [winfo toplevel $parent] configure -menu [. cget -menu]
	}
    }
    if {![string eq x11 [tk windowingsystem]]} {
	wm geometry $t +0+[winfo screenheight $t]
    }
# supposed to reduce flicker but stuffs placement under Gnome
    return $t
}

# This actually isnt much use, because if a script creates a window then makes
# it a slave of another withdrawn window, then calls this, the 'state' will
# come up as 'normal' until an update happens. Adding 'update idletasks'
# may have sorted this.

# Added functionality to move window to the centre of its parent, or
# the screen if it has none

proc LetItShow {t {doneVar {}}} {
    if {[string length $doneVar] && [info exists ::SimileAutoObjLoaded]} {
	puts [wm title $t]
	set ::$doneVar 1
	return
    }
    update idletasks
#puts "$t: viewable [winfo viewable $t]; state [wm state $t]"
    if {![winfo viewable $t] && ![string equal withdrawn [wm state $t]]} {
	tkwait visibility $t
    }
    set scw [winfo screenwidth $t]
    set sch [winfo screenheight $t]
    set wotParent [wm transient $t]
#puts "Parent of $t is $wotParent"
    if {[llength $wotParent]} {
# OK note special geometry scanning to cope with -ve geom offsets! It should
# be done like this everywhere else too.
	scan [wm geometry [winfo toplevel $wotParent]] {%dx%d%1s%d%1s%d} \
	    tgtw tgth sgnx tgtx sgny tgty
    } else {
	set tgtx 0; set tgty 0
	set sgnx +; set sgny +
	set tgtw $scw
	set tgth $sch
    }
    set fillw [winfo reqwidth $t]
    set fillh [winfo reqheight $t]
    set left [expr {max(0, min($scw-$fillw, $tgtx+($tgtw-$fillw)/2))}]
    set top [expr {max(0, min($sch-$fillh, $tgty+($tgth-$fillh)/2))}]
    wm geometry $t $sgnx$left$sgny$top
    if {[string length $doneVar]} {
# have variable that gets set on exit, if scripting just set it
# otherwise do interaction here
        set oldGrab [grab current]
	grab $t
	tkwait variable $doneVar
        if {[string length $oldGrab]} {
	    grab $oldGrab
	} else {
	    grab release $t
	}
    }
    return [winfo viewable $t]
}

proc PackItUp {t} {
    global tcl_platform
    set parent [wm transient $t]
    if {![winfo exists $parent]} {
	set parent .
    }
    destroy $t
# The need for these lines was removed by a TkAqua patch applied 10 March 2005.
# But the lines are still here, for the benefit of the sketch graph window 
    if {[string match Darwin $tcl_platform(os)]} {
	focus -force [winfo toplevel $parent]
#	AbleAllEntries $parent normal
#	puts "Restoring $::concealedMenu($t) for $t"
	if {[info exists ::concealedMenu($t)]} {
# setting menu empty allows crash if it is posted
	    [winfo toplevel $parent] configure -menu $::concealedMenu($t)
	    unset ::concealedMenu($t)
	}
# Make menu updates happen before something else does same thing
	update idletasks
    }
}

proc AbleAllEntries {parent newState} {
    set menu [[winfo toplevel $parent] cget -menu]
    if {[winfo exists $menu]} {
	set lastId [$menu index last]
	for {set id 0} {$id <= $lastId} {incr id} {
	    $menu entryconfigure $id -state $newState
	}
    }
}

proc UnderlineUniquely {mu} {
    # first make a string of all those so  far used
    set used {}
    set last [$mu index last]
    if {![string is integer $last]} return ;# no entries
    for {set line 0} {$line<=$last} {incr line} {
	if {[catch {$mu entrycget $line -label} hdr]} continue ;# no text
	# now list positions of the letters in the order we will try them
	set posns 0 ;# start of label
	set next 0
	while {[set next [expr {[string first { } $hdr $next]+1}]]>0} {
	    lappend posns $next ;# start of each word in label
	}
	for {set next 1} {$next < [string length $hdr]} {incr next} {
	    lappend posns $next ;# each other letter in label
	}
	foreach place $posns {
	    set try [string tolower [string index $hdr $place]]
	    if {[string is alpha $try] && [string first $try $used]==-1} {
		$mu entryconfigure $line -underline $place
		append used $try
		break
	    }
	}
    }
}

# not good enough, must respond to getframe too
proc TitleFrame {args} {
    eval ttk::labelframe $args
}

# this should fix it
proc GetFrame {special} {
#    return [$special getframe] ;# bwidget TitleFrame version
    return $special
}

#proc TranslateFormatting {key params} {
#    eval [list format [tr. $key]] $params
#}

# on loading, create a temporary directory in a useful place
package require fileutil
set simtmpdir [file join [::fileutil::tempdir] sim[pid]]
file mkdir $simtmpdir

# use this to look after the single clicks and the doubleclicks will
# look after themselves    
set ::clickKO(x) 0
set ::clickKO(y) 0
set ::clickKO(time) 0
proc KoreanClick {widget buttonNo cmd} {
    if {[string match windows $::tcl_platform(platform)]} {
	bind $widget <Button-$buttonNo> [subst -nocommands {
	    set gap [expr {[clock milliseconds]-[set clickKO(time)]}]
	    set motn [expr {abs(%X-[set clickKO(x)])+abs(%Y-[set clickKO(y)])}]
	    incr clickKO(time) [set gap]
	    set clickKO(x) %X
	    set clickKO(y) %Y
	    if {[set gap]<500 && [set motn]<5} {
		event generate [list $widget] <Button-$buttonNo> \
		    -rootx %X -rooty %Y -x %x -y %y
		# which will be converted to double
	    } else {
		eval [list $cmd]
	    }
	}]
    } else { # no bug to work around
	bind $widget <Button-$buttonNo> $cmd
    }
}

# procedure to bind to a window's scroll action if we don't want it scrolling
# due to axxidental mousewheel turns
proc Unscroll {w dim t b} {
# only way to find out if it has moved
    if {abs([$w canvas$dim 0])>1} {
	$w ${dim}view moveto 0
    }
}

proc DeDot {cb} {
    return [string map {. dot do dodo} $cb]
}

proc FixMacComboBox {} {
### replace toplevel window for combobox with a placed frame to avoid 
### Mac crash if at -ve coords

bind ComboboxListbox <FocusOut>		{ttk::combobox::LBCancel %W }

namespace eval ::ttk::combobox {
    foreach cbProc {PopdownToplevel PlacePopdown PopdownWindow \
			Post Unpost LBMaster} {
	rename $cbProc Old$cbProc

	proc $cbProc {args} {
	    set me [namespace tail [lindex [info level 0] 0]]
	    if {[PrefValue custom(tlPopups) tlPopups]} {
		eval Old$me $args
	    } else {
		eval New$me $args
	    }
	}
    }

    proc NewPopdownToplevel {w} {
	set cb [string range $w 0 [string last . $w]-1]
	set f [frame [winfo toplevel $cb].[DeDot $cb]]
	$f configure -relief solid -borderwidth 0
	return $f
    }

    proc NewPlacePopdown {cb popdown} {
	set base [winfo toplevel $cb]
	set x [winfo rootx $cb]
	set y [winfo rooty $cb]
	set w [winfo width $cb]
	set h [winfo height $cb]
	set postoffset [ttk::style lookup TCombobox -postoffset {} {0 0 0 0}]
	foreach var {x y w h} delta $postoffset {
	    incr $var $delta
	}

	set H [winfo reqheight $popdown]
	if {$y + $h + $H > [winfo height $base]} {
	    set Y [expr {$y - $H}]
	} else {
	    set Y [expr {$y + $h}]
	}
	#wm geometry $popdown ${w}x${H}+${x}+${Y}
	place $popdown -in $base -x [expr {$x-[winfo rootx $base]}] \
	    -y [expr {$Y-[winfo rooty $base]}] -width $w -height $H
    }

    proc NewPopdownWindow {cb} {
	variable Values

	if {[winfo exists $cb.popdown]} {
	    # from default version in case preference just changed
	    set Values([LBMaster $cb.popdown.f.l]) dummy
	    # prevent error when unsetting
	    destroy $cb.popdown
	}
	set realPopdown [winfo toplevel $cb].[DeDot $cb]
	if {![winfo exists $realPopdown]} {
	    OldPopdownWindow $cb
	}
	return $realPopdown
    }

    proc NewPost {cb} {
	# Don't do anything if disabled:
	#
	$cb instate disabled { return }

	# ASSERT: ![$cb instate pressed]

	# Run -postcommand callback:
	#
	uplevel #0 [$cb cget -postcommand]

	set popdown [PopdownWindow $cb]
	ConfigureListbox $cb
	update idletasks    ;# needed for geometry propagation.
	PlacePopdown $cb $popdown
    }

    proc NewUnpost {cb} {
	set w [winfo toplevel $cb].[DeDot $cb]
	if {[winfo exists $w]} {
	    place forget $w
	}
    }

    proc NewLBMaster {lb} {
	set w [winfo parent [winfo parent $lb]]
	set tail [string range $w [string first . $w 1]+1 end]
	return [string map {dodo do dot .} $tail] ;# ReDot
    }
}
}
