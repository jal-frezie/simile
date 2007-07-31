# Simile source code file: Run/utility.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains general purpose utilities, which are used both in 
# the model diagram editor and the stand-alone run time environment.

# Thanks to tk_abandon, I sometimes put several dialogues up at once, which,
# thanks to a bug in tcltk, gets the wrong results for the lower ones...

proc ShowMessage { title icon string resps {parent {}}} {
    set mBoxCmd [list tk_messageBox -title $title -icon $icon \
		     -message $string -type $resps]
    if {[winfo exists .splash]} {
	destroy .splash ;# ensure mess is not obscured by splash screen
    }
    if {[winfo exists .popup]} {
	destroy .popup ;# avoid weird hang under Aqua, or at least try
    }
    set active [focus]
    if {[string length $parent]>0} {
	lappend mBoxCmd -parent $parent
    } elseif {[string length $active]>1} { ;# window . is hidden so must not
	lappend mBoxCmd -parent [winfo toplevel $active]
    }
    set act [eval $mBoxCmd]
    update idletasks
    return $act
}

# ChooseFile -- this is a wrapper for the Tcl file dialog, which sets
# the path name to start looking in explicitly as use of the
# -initialdir switch under Linux causes horrible misbehaviour if the
# filename has spaces in it.

proc ChooseFile { preferred title canbenew } {
    global __tk_filedialog chosenPaths

    set fileType [file extension $preferred]
#    set __tk_filedialog(selectPath) [do_in_editor GetPathChoice $fileType]

# __tk_etc should set starting directory, but just in case...
#    set prevDir [pwd]
#    cd $__tk_filedialog(selectPath)
    switch $fileType {
	.sml {
	    set typeList [list .sml .sim .ame]
	    set desc Models
	    set recordEntry 1
	} .gif {
	    set typeList [list .gif .jpg .jpeg .png .tif .tiff]
	    set desc Images
	    set recordEntry 0
	} {} {
	    set typeList {}
	    set desc Directories
	    set recordEntry 0
	} .cpp {
	    set typeList [list .cpp .c .h]
	    set desc "Source or header files"
	    set recordEntry 0
	} default {
	    set typeList [list $fileType]
	    set desc "$fileType files"
	    set recordEntry 0
	}
    }
    set typeList [list [list $desc $typeList]]
    set switches [list -title $title -defaultextension $fileType \
		      -filetypes $typeList \
		      -initialdir [do_in_editor GetPathChoice $fileType]]
    set active [focus]
    if {[llength $active]} {
	lappend switches -parent [winfo toplevel $active]
    }
    if {$canbenew} {
        set cmd tk_getSaveFile
	lappend switches  -initialfile $preferred
    } else {
        set cmd tk_getOpenFile
    }
#ShowMessage debug info "will eval $cmd $switches" ok
    set chosenFile [eval $cmd $switches]
#    cd $prevDir
    if {[string compare $chosenFile {}]} {
	do_in_editor RecordPathChoice $fileType $chosenFile $recordEntry
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

proc IdentField {text field} {
    global userinfo

    set field0 [expr {[string first ${field}= $text]+[string length $field]+1}]
    set fieldEnd [expr {[string first , $text $field0]-1}]
    string range $text $field0 $fieldEnd
}

# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

proc load_c_stub_1 {} {
    global env tcl_platform userinfo
    scan [info tclversion] {%d.%d} MAJ MIN
    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN}.$env(SIMILE_VERSION).$onUnix
    if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
	error "Could not find a stub for Simile $userinfo(Version) and TclTk ${MAJ}.${MIN} under $tcl_platform(platform) -- $dummy"
    }
}

package require MyTrf ;# loads right version of Trf

proc load_c_stub_2 {} {
    global env userinfo ;# last needed in stub
    # On startup, check run count and offer registration if 0
    if [catch {set userinfo(name) $env(licensee_name)}] {
        set userinfo(name) " "
    }
    if [catch {set userinfo(corp) $env(licensee_corp)}] {
        set userinfo(corp) " "
    }
    
    catch {set userinfo(license_code) $env(license_code)}
    loadcommands
    randseed [clock scan now]
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

proc PostScrog { winId } {
    set psfile [ChooseFile image.ps "Name of postscript file" 1]
    # check for cancel
    if {![string match */ $psfile]} {
        
        # force .ps extension
        if {[string compare [file extension $psfile] .ps]} {
            set psfile [file root $psfile].ps
        }

	set useWidth [winfo width $winId]
	set useHeight [winfo height $winId]
    
	$winId postscript -file $psfile -rotate true -pageanchor nw \
            -pagex 0 -pagey 0 \
            -width $useWidth -height $useHeight \
            -pagewidth [expr $useWidth/100.0]i -pageheight [expr $useHeight/100.0]i
    }
}

# popup stuff -- here because both model windows and helpers use them

proc BindPopup {widget keywd} {
# any % will be subbed by binding process unless we double it
    regsub -all % $keywd %% keywd
    bind $widget <Enter> [list QueuePopup AddWidgetPopup $keywd %X %Y]
    bind $widget <Leave> RemovePopup
}

proc MenuBindPopup {widget keyList} {
# any % will be subbed by binding process unless we double it
    regsub -all % $keyList %% keyList
    bind $widget <Enter> [list QueuePopup \
            AddMenuPopup $widget $keyList %y %X %Y 1]
    bind $widget <Motion> [list AddMenuPopup $widget $keyList %y %X %Y 0]
    bind $widget <Leave> RemovePopup
}

proc QueuePopup {args} {
    global popper
    # Only allow one cmd in pipeline at a time -- two added if dragging an
    # incomplete obj which Prolog then deletes (Tk bug workaround - 10 points)
    if {[info exists popper(cmd)]} {
        after cancel $popper(cmd)
    }
    set popper(cmd) [after 500 $args]
    bind all <Motion> "set latestmouse(X) %X; set latestmouse(Y) %Y"
    if {![winfo exists .popup]} {
	set popper(foc) [focus]
    }
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
    global tcl_platform latestmouse
    if {[winfo exists .popup]} {
        destroy .popup
    }
    if [string match Darwin $tcl_platform(os)] {
        toplevel .popup -width 1 -height 1
        ::tk::unsupported::MacWindowStyle style .popup help none
    } else {
        toplevel .popup -width 1 -height 1 -bd 1 -bg black
# leaves one pixel of black showing round edge of messages
        wm overrideredirect .popup 1
    }

    update idletasks
    bind all <Motion> {}
    if {[info exists latestmouse(X)]} {
	set X $latestmouse(X)
	set Y $latestmouse(Y)
	array unset latestmouse
    }
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
	if {[string match aqua [tk windowingsystem]]} {
	    focus -force $popper(foc)
	}
    }
    if {[info exists popper(cmd)]} {
        after cancel $popper(cmd)
    }
}

proc AddPopupMessage {text colour args} {
    set limit 500
    if {[llength $args]} {
	set combo [eval $args $limit]
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
    foreach fn {graph table new open save edit reel noreel} {
        set iconImages($fn) \
	    [image create photo -file "../Images/Toolbar/${fn}.gif"]
    }
    foreach fn {info warning error} {
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
    toplevel .$t -bd 4
    if {[winfo exists $parent] && [string compare . $parent]} {
	wm transient $t $parent
	if [string match Darwin $tcl_platform(os)] {
	    ::tk::unsupported::MacWindowStyle style $t floatGrowProc
#	    ::tk::unsupported::MacWindowStyle style $t moveableModal {}
	    AbleAllEntries $parent disabled
	}
    } else {
	wm transient $t
    }
    wm geometry $t +0+[winfo screenheight $t]
    return $t
}

# This actually isnt much use, because if a script creates a window then makes
# it a slave of another withdrawn window, then calls this, the 'state' will
# come up as 'normal' until an update happens. Adding 'update idletasks'
# may have sorted this.

# Added functionality to move window to the centre of its parent, or
# the screen if it has none

proc LetItShow {t} {
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
	scan [wm geometry [winfo toplevel $wotParent]] {%dx%d+%d+%d} \
	    tgtw tgth tgtx tgty
    } else {
	set tgtx 0; set tgty 0
	set tgtw $scw
	set tgth $sch
    }
    set fillw [winfo reqwidth $t]
    set fillh [winfo reqheight $t]
    set left [max 0 [min [expr $scw-$fillw] [expr $tgtx+($tgtw-$fillw)/2]]]
    set top [max 0 [min [expr $sch-$fillh] [expr $tgty+($tgth-$fillh)/2]]]
    wm geometry $t +$left+$top
    return [winfo viewable $t]
}

proc PackItUp {t} {
    global tcl_platform
    set parent [wm transient $t]
    destroy $t
# The need for these lines was removed by a TkAqua patch applied 10 March 2005.
# But the lines are still here, for the benefit of the sketch graph window 
    if {[winfo exists $parent] && [string match Darwin $tcl_platform(os)]} {
	focus -force [winfo toplevel $parent]
	AbleAllEntries $parent normal
    }
}

proc ShellFileRef {spaced} {
# Pop a backslash before chars that would break tcl lists
    regsub -all {([ ])} $spaced {\\\1} straight
    return $straight
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