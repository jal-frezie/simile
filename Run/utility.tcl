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

proc BuildProblem {name autoName msg fault} {
    global iconImages

    toplevel .buildprob
    switch $fault {
        user {
            set Title "Problem with model"
            set errLevel warning
            set buttonCmd {ContextSensitiveHelp .buildprob run/index.htm}
        } system {
            set Title "Build failure"
            set errLevel error
            set buttonCmd {ContextSensitiveHelp .buildprob files/problem.htm}
        } tcl {
            set Title "User interface problem"
            set errLevel error
            set buttonCmd {ContextSensitiveHelp .buildprob files/problem.htm}
        }
    }
    wm title .buildprob $Title
    wm protocol .buildprob WM_DELETE_WINDOW {set ack 1}
    global tcl_platform
    if {[string match windows $tcl_platform(platform)]} {
        wm attributes .buildprob -toolwindow true
    }
    
    set labf1 [frame .buildprob.labf1]
    pack [label $labf1.img -image $iconImages($errLevel)] -side left
    pack [label $labf1.lab1 -text "Warning:" \
            -font {-weight bold -family helvetica -size 10}] -side left
    pack [scrollbar $labf1.yscroll -orient v \
            -command [list AdjustScroll $labf1.lab2 yview]] -fill y
    pack [text $labf1.lab2 -width 48 -height 10 -wrap word \
            -yscrollcommand [list AdjustCanvas $labf1 lab1 y]]
    $labf1.lab2 insert 1.0 $msg
    $labf1.lab2 config -state disabled
    #    pack [label $labf1.lab2 -text $msg -wraplength 320 \
    #            -font {-family helvetica -size 10} -justify left] -side left
    pack $labf1 -padx 8 -pady 2
    
    set buttons [frame .buildprob.buttons]
    pack [button $buttons.ok -text OK -width 10 \
            -command {set ack 1}] \
            -side left -padx 4 -pady 4
    if {![string match $fault user]} {
        pack [button $buttons.report -text {Send bug report} -width 20 \
                -command [list ReportProblem $name $autoName $msg]] \
                -side left -padx 4 -pady 4
    }
    pack [button $buttons.help -text Help -width 10 \
            -command "set ack 1; $buttonCmd"] \
            -side left -padx 4 -pady 8
    pack $buttons
    
    set height [winfo reqheight .buildprob]
    set width [winfo reqwidth .buildprob]
    set sheight [winfo screenheight .buildprob]
    set swidth [winfo screenwidth .buildprob]
    wm geometry .buildprob +[expr ($swidth-$width)/2]+[expr ($sheight-$height)/2]
    update
    grab .buildprob
    tkwait variable ack
    grab release .buildprob
    destroy .buildprob
}

# ChooseFile -- this is a wrapper for the Tcl file dialog, which sets
# the path name to start looking in explicitly as use of the
# -initialdir switch under Linux causes horrible misbehaviour if the
# filename has spaces in it.

proc ChooseFile { preferred title canbenew } {
    global __tk_filedialog chosenPaths

    set fileType [file extension $preferred]
    set egDir [PrefValue custom(prefDir) prefDir]/Examples
    if {[info exists chosenPaths($fileType)]} {
	set __tk_filedialog(selectPath) $chosenPaths($fileType)
    } elseif {[info exists chosenPaths(latest)]} {
	set __tk_filedialog(selectPath) $chosenPaths(latest)
    } elseif {[info exists $egDir]} {
	set __tk_filedialog(selectPath) $egDir
    } else {
	set __tk_filedialog(selectPath) [pwd]
    }
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
	RecordPathChoice $fileType $chosenFile $recordEntry
    }
    return $chosenFile
}

proc RecordPathChoice {fileType chosenFile recordEntry} {
    global chosenPaths custom
    set chosenPaths($fileType) \
	    [set chosenPaths(latest) [file dirname $chosenFile]]
    if {$recordEntry} {
	set custom(hotlist) [linsert $custom(hotlist) 0 $chosenFile]
    }
}

# utility procedure to fill in some holes in Tcl8.0


proc ChooseText {choice ifTrue ifFalse} {
    if {$choice} {
        return $ifTrue
    } else {
        return $ifFalse
    }
}

# This deals with the quirk of Netware file systems that if the user has
# read/write access to a file it cannot be opened readonly, or something...

proc NetOpen {name way} {
    if {[catch {open $name $way} stream]} {
	if {[catch {open $name r+} stream]} {
	    error "Could not open $name $way or r/w"
	}
    }
    return $stream
}

# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

proc load_c_stub {} {
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
        # maybe we built the package index for a different os, try again
        catch {pkg_mkIndex ../System/lib/Stubs *[info sharedlibextension]}
        if {[catch {package require -exact Ame_dll $stubPkg} dummy]} {
            error "Could not find a stub for Simile $env(SIMILE_VERSION) and TclTk ${MAJ}.${MIN} under $tcl_platform(platform)"
        }
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
    toplevel .popup -width 1 -height 1 -bd 2 -relief raised
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

proc EndsOnly {text isValue verbosity leave} {
    set size [expr ($leave-20)/2]
    if {$isValue} {
	set nvals " ([CountValues $text] values)"
    } else {
	set nvals " ($verbosity characters)"
    }
    set text [string range $text 0 $size].....[string range $text \
						 [expr $verbosity-$size] end]
    append text $nvals
    return $text
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

proc LoadIconImages {} {
    global iconImages
    foreach fn {tick cross function} {
	set iconImages($fn) \
	    [image create photo -file "../Images/Eqnbar/${fn}.gif"]
    }
    foreach fn {graph table open save edit} {
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
