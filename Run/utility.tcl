# utility.tcl
# ===========

# This file contains general purpose utilities in Tcl, which are
# likely to be used both in the AME editor interface and the
# stand-alone run time environment.

#############################################################################

# Just so I know where this is...
# Thanks to tk_abandon, I sometimes put several dialogues up at once, which,
# thanks to a bug in tcltk, gets the wrong results for the lower ones...

proc ShowMessage { title icon string resps {parent {}}} {
    set mBoxCmd [list tk_messageBox -title $title -icon $icon \
		     -message $string -type $resps]
    if {[winfo exists .splash]} {
	destroy .splash ;# ensure mess is not obscured by splash screen
    }
    set active [focus]
    if {[llength $active]} {
	lappend mBoxCmd -parent $active
    }
    set act [eval $mBoxCmd]
    update
    return $act
}

# general error handling -- note that only user errors will be raised from
# execution interps, so the reporting stuff can be kept in the editor interp

proc BuildProblem {Title errLevel msg key args} {
    global iconImages help

    set ProbWin .bprob[clock clicks]
    toplevel $ProbWin
    wm transient $ProbWin [focus]
#    switch $fault {
#        user {
#            set Title "Problem with model"
#            set errLevel warning
#            set buttonCmd {ContextSensitiveHelp $ProbWin run/index.htm}
#        } system {
#            set Title "Build failure"
#            set errLevel error
#            set buttonCmd {ContextSensitiveHelp $ProbWin files/problem.htm}
#        } tcl {
#            set Title "User interface problem"
#            set errLevel error
#            set buttonCmd {ContextSensitiveHelp $ProbWin files/problem.htm}
#        }
#    }
    wm title $ProbWin $Title
    wm protocol $ProbWin WM_DELETE_WINDOW {set ack 1}
    global tcl_platform
    if {[string match windows $tcl_platform(platform)]} {
        wm attributes $ProbWin -toolwindow true
    }
    
    set labf1 [frame $ProbWin.labf1]
    pack [label $labf1.img -image $iconImages($errLevel)] -side left 
    pack [label $labf1.lab1 -text "Warning:" \
            -font {-weight bold -family helvetica -size 10}] -side left
    pack [scrollbar $labf1.yscroll -orient v \
            -command [list AdjustScroll $labf1.lab2 yview]] -fill y -expand on
    pack [text $labf1.lab2 -width 48 -height 10 -wrap word \
            -yscrollcommand [list AdjustCanvas $labf1 lab1 y]] -fill both -expand on
    $labf1.lab2 insert 1.0 $msg
    $labf1.lab2 config -state disabled
    #    pack [label $labf1.lab2 -text $msg -wraplength 320 \
    #            -font {-family helvetica -size 10} -justify left] -side left
    pack $labf1 -padx 8 -pady 2 -fill both -expand on
    
    set buttons [frame $ProbWin.buttons]
    pack [button $buttons.ok -text OK -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    if {[llength $args]==2} {
        pack [button $buttons.report -text {Send bug report} -width 20 \
		  -command [concat ReportProblem $args [list $msg]]] \
                -side left -padx 4 -pady 4
    }
    pack [button $buttons.help -text Help -width 10 \
           -command "set ack 1; ContextSensitiveHelp $ProbWin $help($key)"] \
           -side left -padx 4 -pady 8
    pack $buttons
    
    set height [winfo reqheight $ProbWin]
    set width [winfo reqwidth $ProbWin]
    set sheight [winfo screenheight $ProbWin]
    set swidth [winfo screenwidth $ProbWin]
    wm geometry $ProbWin +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    update
    grab $ProbWin
    tkwait variable ack
    grab release $ProbWin
    destroy $ProbWin
}

# ChooseFile -- this is a wrapper for the Tcl file dialog, which sets
# the path name to start looking in explicitly as use of the
# -initialdir switch under Linux causes horrible misbehaviour if the
# filename has spaces in it.

proc ChooseFile { preferred title canbenew } {
    global __tk_filedialog chosenPaths

    set fileType [file extension $preferred]
    set __tk_filedialog(selectPath) [do_in_editor GetPathChoice $fileType]

# __tk_etc should set starting directory, but just in case...
    set prevDir [pwd]
    cd $__tk_filedialog(selectPath)
    switch $fileType {
	.sml {
	    set typeList [list .sml .sim .ame]
	    set desc Models
	    set recordEntry 1
	} .gif {
	    set typeList [list .gif .jpg .jpeg]
	    set desc Images
	    set recordEntry 0
	} {} {
	    set typeList {}
	    set desc Directories
	    set recordEntry 0
	} default {
	    set typeList [list $fileType]
	    set desc "$fileType files"
	    set recordEntry 0
	}
    }
    set typeList [list [list $desc $typeList]]
    set switches [list -title $title -defaultextension $fileType \
		      -filetypes $typeList]
    set active [focus]
    if {[llength $active]} {
	lappend switches -parent $active
    }
    if {$canbenew} {
        set cmd tk_getSaveFile
	lappend switches  -initialfile $preferred
    } else {
        set cmd tk_getOpenFile
    }
    set chosenFile [eval $cmd $switches]
    cd $prevDir
    if {[string compare $chosenFile {}]} {
	do_in_editor RecordPathChoice $fileType $chosenFile $recordEntry
    }
    return $chosenFile
}

# utility procedure to fill in some holes in Tcl8.0


proc ChooseText {choice ifTrue ifFalse} {
    if {$choice} {
        return $ifTrue
    } else {
        return $ifFalse
    }
}

# takes two file names and returns the second relative to the first
proc Relativize {current remote} {
    #	ShowMessage debug info "relativizing $current $remote" ok
    set currentList [file split $current]
    set remoteList [file split $remote]
    set parted 0
    set base {}
    for {set sameCount 0} {$sameCount < [llength $currentList]} {incr sameCount} {
        if {$parted} {
            lappend base ..
        } elseif {[string compare [lindex $currentList $sameCount] \
                    [lindex $remoteList $sameCount]]} {
            set tail [lrange $remoteList $sameCount end]
            set parted 1
        }
    }
    return [eval {file join} $base $tail]
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

# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

proc load_c_stub {} {
    package require Trf

    global tcl_platform env userinfo ;# last needed in stub
    # On startup, check run count and offer registration if 0
    if [catch {set userinfo(name) $env(licensee_name)}] {
        set userinfo(name) " "
    }
    if [catch {set userinfo(corp) $env(licensee_corp)}] {
        set userinfo(corp) " "
    }
    set userinfo(Version) $env(SIMILE_VERSION)
    
    set userinfo(license_code) \
            [join [lrange [split $env(license_code) =] 1 end] =]
    scan [info tclversion] {%d.%d} MAJ MIN
    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN}.$env(SIMILE_VERSION).$onUnix
    if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
	error "Could not find a stub for Simile $env(SIMILE_VERSION) and TclTk ${MAJ}.${MIN} under $tcl_platform(platform) -- $dummy"
    }
    loadcommands
    randseed [clock clicks]
}

proc AdjustCanvas {winId pt dir args} {
    set tgt $winId.${dir}scroll
    # hide scrollbar if full size
    if {[lindex $args 0]<0.01 && [lindex $args 1]>0.99} {
        pack forget $tgt
    } else {
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
    global tcl_platform
    
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
    }
}

# popup stuff -- here because both model windows and helpers use them

proc BindPopup {widget keywd} {
    bind $widget <Enter> [list QueuePopup AddWidgetPopup $keywd %X %Y]
    bind $widget <Leave> RemovePopup
}

proc MenuBindPopup {widget keyList} {
    bind $widget <Enter> [list QueuePopup \
            AddMenuPopup $widget $keyList %y %X %Y 1]
    bind $widget <Motion> [list AddMenuPopup $widget $keyList %y %X %Y 0]
    bind $widget <Leave> RemovePopup
}

proc QueuePopup {args} {
    global popper
    #puts "queueing $cmd"
    # Only allow one cmd in pipeline at a time -- two added if dragging an
    # incomplete obj which Prolog then deletes (Tk bug workaround - 10 points)
    if {[info exists popper]} {
        after cancel $popper
    }
    set popper [after 500 $args]
}

proc AddWidgetPopup {key X Y} {
    global msgs
    if {![PrefValue custom(popupHelp) popupHelp]} {
	return

    }
    PostPopup $X $Y
    if {[info exists msgs($key)]} {
        set message $msgs($key)
    } else {
        set message $key
    }
    pack [message .popup.message -aspect 400 \
            -text $message -bg \#ffffc0] -fill x -expand true
}

proc AddMenuPopup {widget list y X Y new} {
    global msgs
    if {$new} {
        PostPopup $X $Y
        pack [message .popup.message -aspect 400 -bg \#ffffc0] \
                -fill x -expand true
    }
    set entry [$widget index @$y]
    if {[string match none $entry] || ![winfo exists .popup.message]} {
        return
    }
    if {[llength $list]} {
	set line [lindex $list $entry]
	set message "[lindex $line 1]: [lindex $line 0]"
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
    .popup.message configure -text $message
}

proc PostPopup {X Y} {
    if {[winfo exists .popup]} {
        destroy .popup
    }
    toplevel .popup -width 1 -height 1 -bd 1 -bg black
# leaves one pixel of black showing round edge of messages
    wm overrideredirect .popup 1

    # This moves the popup window to whichever quadrant of the moused-over
    # component is all on the screen. It sticks it to the bottom left to start with
    # so it doesn't grab the focus, then updates so the requested size can be found
    # then uses this size to move it to the right place

    if {$X>[winfo screenwidth .popup]/2} {
        set xpoint -[expr [winfo screenwidth .popup]+10-$X]
    } else {

        set xpoint +[expr $X+10]
    }
    if {$Y>[winfo screenheight .popup]/2} {
        set ypoint -[expr [winfo screenheight .popup]+10-$Y]
    } else {
        set ypoint +[expr $Y+10]
    }
    wm geometry .popup ${xpoint}${ypoint}
    raise .popup
}

proc RemovePopup {args} {
    global popper
    #puts "Removing popup"
    if {[winfo exists .popup]} {
        destroy .popup
    }
    if {[info exists popper]} {
        after cancel $popper
    }
}

proc AddPopupMessage {text colour args} {
    set limit 500
    if {[llength $args]} {
	set combo [eval do_for_node $args $limit]
	set count [lindex $combo 0]
	set text [lindex $combo 1]
    } else {
	set count 0
    }
    EndsOnly text $count $limit
# note the model editor still processes events while waiting for the executable
# so check window is still there
    if {[winfo exists .popup]} {
	if {[string length $text]<20} {
	    pack [label .popup.message$colour \
		      -text $text -bg $colour] -fill x -expand true
	} else {
	    pack [message .popup.message$colour -aspect 400 \
		      -text $text -bg $colour] -fill x -expand true
	}
    }
}

proc EndsOnly {outerText count leave} {
    upvar 1 $outerText text

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

proc ShrinkValueList {outerList limit} {
    set manage [expr $limit/4]
    upvar 1 $outerList list
    set allVals [CountValues $list]
    if {$allVals>$manage} {
	set range [expr $manage/2]
	set startRange [GetNVals $list first $range]
	set endRange [GetNVals $list last $range]
	set list [concat $startRange $endRange]
    }
    return $allVals
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
        for {set n 1} {$n<$len} {incr n 2} {
            incr tot [CountValues [lindex $text $n]]
        }
        return $tot
    }
}

proc SquirtMime {args} {
    global mimeSquirter

    if {[string match end [lindex $args 0]]} {
        close $mimeSquirter
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
    foreach fn {graph table new open save edit} {
        set iconImages($fn) \
	    [image create photo -file "../Images/Toolbar/${fn}.gif"]
    }
    foreach fn {warning error} {
        set iconImages($fn) \
	    [image create photo -file "${::BWIDGET::LIBRARY}/images/${fn}.gif"]
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


proc RestoreCrs {noCrs} {
    regsub -all \\\\n $noCrs \n withCrs

    return $withCrs
}

proc min {first last} {
    return [expr $first<$last?$first:$last]
}

proc max {first last} {
    return [expr $first>$last?$first:$last]
}

