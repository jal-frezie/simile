# Welcome to toolbox.tcl, the file containing the bits of tcl and tk
# needed to supply the graphical interface to the modelling environment.
# Just to give you an idea of (a) the sort of thing you can do in tcl,
# and (b) my preferred programming style, check this out....

lappend auto_path [pwd]/../System/library/Extras

source ../Run/shapes.tcl
source ../Run/forms.tcl
source ../Run/messages.tcl
source ../Run/prefs.tcl
source ../Run/runmodel.tcl

# botch -- mre.tcl has to be loaded after the other tcls or it doesn't
# work properly

source ../Run/mre.tcl


proc AttackGlobalVariable {array elt val} {
    global $array
#ShowMessage debug info "Setting $array$elt" ok
    set $array$elt $val
    return ;# because letting it return an array causes a crash
}

# Now to switch off all error reporting from Tcl (Unintended feature of
# Version 8.0p2, any image file will do)
# image create photo open -file "../Images/mailbox.gif"
# Actually I think not, it seems to prevent the window menu appearing as well

proc ControlDraw {simileVersion prologVersion} {
    global sendvars custom tcl_platform env userinfo
    # geometry XY help message JMM
    #            "Position of Run Control when not using the Run Time \
    #                    Environment in the form +/-x+/-y." \
    
    wm withdraw .
    set sendvars(simV) $simileVersion
    set sendvars(proV) $prologVersion

    # no longer have a separate floating toolbar

    # On startup, check run count and offer registration if 0
    set UserStream [open ../Run/userinfo.txt r]
    gets $UserStream userinfo(Name)
    gets $UserStream userinfo(Corp)
    gets $UserStream userinfo(Version)
    close $UserStream

    if {[file exists ~]} {
        set custom(prefDir) ~/.simile
    } else {
        set custom(prefDir) [pwd]/../Prefs
    }
    
    if {![file exists $custom(prefDir)]} {
        file mkdir $custom(prefDir)
    }

    if {[file exists $custom(prefDir)/version]} {
	set UserStream [open $custom(prefDir)/version r]
	gets $UserStream userinfo(Name)
	gets $UserStream userinfo(Corp)
	gets $UserStream userinfo(oldVersion)
	gets $UserStream userinfo(done)
    } else {
	set userinfo(oldVersion) 0
	set userinfo(done) 0
    }
    if {!$userinfo(done) || $userinfo(Version)>$userinfo(oldVersion)} {
	DoRegDialog
	if {$userinfo(done) == 2} {
	    if {[catch {package require http
	    set regData [::http::formatQuery Name $userinfo(Name) \
			     Organisation $userinfo(Corp) Email $userinfo(email) \
			    Version $userinfo(Version) OS $tcl_platform(os)]
	    ::http::geturl http://www.simulistics.com/products/SendMail.asp \
		    -query $regData}]} {
	    set userinfo(done) 0
	    }
	}
    }
    set UserStream [open $custom(prefDir)/version w]
    puts $UserStream $userinfo(Name)
    puts $UserStream $userinfo(Corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream

    set sendvars(running) 0
    
    set custom(hotlist) {}
    if {[file exists $custom(prefDir)/recent]} {
        set cacheStream [open $custom(prefDir)/recent r]
        while {[gets $cacheStream oldFile]>0} {
            if {[file exists $oldFile]} {
                lappend custom(hotlist) $oldFile
            }
        }
    }
    
    Pref_Init $custom(prefDir)/prefs ../Run/sysprefs
    Pref_Add {{custom(initNavbar) initNavbar ON \
                    "Toolbar in new model windows"} \
                {custom(initToolbar) initToolbar ON \
                    "Component bar in new model windows"} \
                {custom(initEqnbar) initEqnbar ON \
                    "Equation bar in new model windows"} \
                {custom(bigButtons) bigButtons OFF \
                    "Bigger buttons for tool and component bars"} \
                {custom(saveExtras) saveExtras {CHOICE {Model file only} \
                        {Canvas file}} "Save models as..."} \
                {custom(compDescPop) compDescPop ON \
                    "Model component description popups"}
        {custom(compValPop) compValPop ON \
                    "Model component value popups"}
        {custom(compCmtPop) compCmtPop ON \
                    "Model component comment popups"} \
                {custom(recentCount) recentCount 10 \
                    "Show how many reopen options"} \
                {custom(flowRouting) flowRouting ON \
                    "Rectilinear flow routing"} \
                {custom(deleteEndToEnd) deleteEndToEnd ON \
                    "Delete links end-to-end"}}
    #JMM add postions for run control and slider
    # How is popup text set?
    Pref_Add {{custom(runControlPosition) \
                    runControlPosition "+0-20" \
                    "Position of Run Control (when seperate window)"} \
                {custom(slidersPosition) \
                    slidersPosition "+0+0" \
                    "Position of Input Sliders (when seperate window)"}}
    if {[string match windows $tcl_platform(platform)]} {
	file attributes $custom(prefDir) -hidden true
        Pref_Add {{custom(compChoice) compChoice {CHOICE None Microsoft GNU} \
                        "Use which C++ compiler?"}}
    }
    # JMM change wording and change default to ON
    Pref_Add {{custom(helperManager) helperManager ON \
	    "Use single window Run Time Environment"}};

    foreach nodeType {normal generic compartment channel \
                variable function cloud submodel flow influence \
                ghost_link relation} {
        ResetLooks $nodeType
    }
    CustomizeLooks
# Take the opportunity to pass the temp directory name to Prolog
    return [brainwash $env(SIMTMPDIR)]
}

proc byebye {winId} {
    prolog [list tk_off_window( '$winId.canvas' )]
}

proc exit_simile {Dir} {
    global custom model_id instance_id
    if {[info exists instance_id]} {
	c_exitmodel $model_id $instance_id
    }

    file delete -force $Dir
    set cacheStream [open $custom(prefDir)/recent w]
    foreach oldFile $custom(hotlist) {
	puts $cacheStream $oldFile
    }
    close $cacheStream
    destroy .
}

proc ZapWindow { fullName } {
    global custom window_info

    upvar 0 window_info($fullName,parent) target
#ShowMessage debug info "$winId $custom(first_up)" ok
    if {[string match $target $custom(first_up)]} {
	focus $target.canvas
	update
	set cacheStream [open $custom(prefDir)/layout w]
	puts $cacheStream [maximize_fg_win]
	close $cacheStream
    } 
    destroy ${target}top
    destroy $target
    unset target
}

proc ClearWindow {winId} {
# Bit of tricky manoovering to delete all but 1st obj (window background)
    $winId addtag doomed all
    $winId dtag 1 doomed
    $winId delete doomed
}

# Scale translates coordinates in desktop space to canvas space. Used to include
# 'round' because some floating point values caused trouble, but later Tcls do
# not seem to mind them, and they help when things are made very small then zoomed.

proc Scale {winId can} {
    global window_info
    expr $can*$window_info($winId,scale)
}

proc ScaleList {winId clist} {
    set output {}
    foreach elt $clist {
	    lappend output [Scale $winId $elt]
    }
    return $output
}

# Reverse of scale -- still contains round(...) cos is used to send
# stuff to Prolog.does not contain round(...) either because the
# latest Prologs (well at least the Linux ones) seem immune to
# floating-point values.

proc Unscale {winId can} {
    global window_info
    expr $can/$window_info($winId,scale)
}

# procedure called when Prolog wants to know what object is at a point

proc FindObj { winId x y } {
    set canx [Scale $winId $x]
    set cany [Scale $winId $y]

    return [ExtractPrologName $winId [GetClickedObj $winId $canx $cany 10]]
}

# canvasTLDistance returns the offset of a canvas coordinate from its top
# left corner. If you are going to use @x,y to refer to a point in a canvas
# text item, these are the values you need (this is a bug in TclTk)

proc canvasTLDistance {winId x y} {
    scan [$winId cget -scrollregion] "%g %g" cl ct
    return [list [expr $x-$cl] [expr $y-$ct]]
}

proc GetFromProlog {prologCmd} {
    global fromProlog
    prolog $prologCmd
#    while {![info exists fromProlog]} {
#	tkwait variable fromProlog
#    }
    set result $fromProlog
    unset fromProlog
    return $result
}

# Procedure for when Tcl recognizes what object is clicked but being a
# maleficent pile of junk refuses to pass on this information so we have
# to interrogate it to find what is closest to the click point

proc ClickObj { x y winId action} {
    global helperTable 

    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set target [GetClickedObj $winId $canx $cany 10]

    if {!$target} {
	return
    }

# because the canvas is also bound to generate clicks, we must 
# supress any action resulting from this if we are handling the 
# event generated by the canvas item (feature seems redundant)
#    set awaitBogusClick 1

    set node [ExtractPrologName $winId $target]
    global equationbar
    global pushedbutton

    if {[string compare $helperTable(current) none]} {
# go directly to helpers, do not pass Prolog, do not collect 200 error messages
	ProdObj $node [ExtractCaption $winId $node]
    } else {

	set xco [Unscale $winId $canx]
	set yco [Unscale $winId $cany]
	
	if {[string compare $action click] == 0} {
	    set obj [GetCaptionItem $winId $node]
	    
	    if {[string compare $obj {}] && ![string compare [focus] $winId]} {
		set realPlace @[join [canvasTLDistance $winId $canx $cany] ,]
		$winId icursor $obj $realPlace
		$winId select clear
		$winId select from $obj $realPlace
	    }
	    
	    if {![string compare $target $obj]} {
		set action clicktext
		focus $winId
	    }
	}
	prolog [list tk_click_obj('$winId',  $action , $xco , $yco , $node)]

### Formula bar
### Added by Jasper: ignore all eqnbar stuff if none in current window or
### not in pointer mode

    set bar [winfo parent $winId].toolSlot.eqnbar
    if {[catch {pack info $bar}] || [string compare $pushedbutton select]} {
	set equationbar(current_action) null
    } else {
	set equationbar(current_action) $action
#	ModeSelect move
#	ModeSelect select



    }

    if {[string match $equationbar(current_action) click]} {
	set fromProlog [GetFromProlog tk_get_info('$winId',$node,eqn)]
	if {![string match <none> $fromProlog]} {
	    set label [BlankCrs [ExtractCaption $winId $node]]
	    $bar.label configure -text "$label = "

	    set equationbar(winId) $winId
	    set equationbar(xco) $xco
	    set equationbar(yco) $yco
	    set equationbar(node) $node
	    
	    set equationbar(initText) $fromProlog
	    set equationbar(current_action) null
	    set equationbar($bar) $equationbar(initText)
	    SetEqnButtonState $bar normal
	    restore_equation $bar
	}
    }
### End equation bar
  }
}

# This is called when an operatio may have brought into view an area of canvas
# the existence of which was previously unknown to Prolog; it sends the virtual
# coordinates of the current area. l, t, r, b are relative to window.

proc RollBack { winId toProlog l t r b } {
    set newSpace 0
    scan [$winId cget -scrollregion] "%g %g %g %g" cl ct cr cb
#ShowMessage debug info "Rolling from $cl $ct $cr $cb to $l $t $r $b" ok
    set pt [$winId canvasx $l]
    if {$pt < $cl-2} {
	set cl $pt
	set newSpace 1
    }
    
    set pt [$winId canvasx $r]
    if {$pt > $cr+2} {
	set cr $pt
	set newSpace 1
    }
    
    set pt [$winId canvasy $t]
    if {$pt < $ct-2} {
	set ct $pt
	set newSpace 1
    }
    
    set pt [$winId canvasy $b]
    if {$pt > $cb+2} {
	set cb $pt
	set newSpace 1
    }

    if {$newSpace && $toProlog} {
	ResizeDesktop $winId $cl $ct $cr $cb
    }
}

proc ResizeDesktop {winId cl ct cr cb} {
    set canl [Unscale $winId $cl]
    set cant [Unscale $winId $ct]
    set canr [Unscale $winId $cr]
    set canb [Unscale $winId $cb]
    prolog [list tk_visible( '$winId' , $canl , $cant , $canr , $canb )]
}

set awaitBogusClick 0

proc DropObj {winId xco yco} {
	global awaitBogusClick

	if {$awaitBogusClick} {
	    set awaitBogusClick 0
	} else {
#	    focus $winId
    set x [$winId canvasx $xco]
    set y [$winId canvasy $yco]
    set canx [Unscale $winId $x]
    set cany [Unscale $winId $y]
#		if {[$winId find overlapping [expr $x-2] [expr $y-2] \
#				[expr $x+2] [expr $y+2]] == {}} {
#			$winId focus {}
#		}
    prolog [list tk_click('$winId', $canx , $cany )]
	}
}

proc ZapObj {winId xco yco} {
	global awaitBogusClick

#	set awaitBogusClick 1
    set canx [Unscale $winId [$winId canvasx $xco]]
    set cany [Unscale $winId [$winId canvasy $yco]]
    prolog [list tk_doubleclick( $canx , $cany )]

}

# Dragging: as well as the Prolog dragging, we implement
# natively the feature that dragging causes the visible area 
# of the window to follow the mouse.

proc DragObj {winId xco yco} {
	global window_info

    set canx [$winId canvasx $xco]
    set cany [$winId canvasy $yco]
    set virtx [Unscale $winId $canx]
    set virty [Unscale $winId $cany]
    set sloth 5

    RollBack $winId 1 $xco $yco $xco $yco

        if {$xco < 0} {
	    $winId xview scroll [expr $xco/$sloth] units
        }
        if {$yco < 0} {
	    $winId yview scroll [expr $yco/$sloth] units
        }
        if {$xco > $window_info($winId,width)} {
	    $winId xview scroll \
		    [expr int($xco-$window_info($winId,width))/$sloth] units
        }
        if {$yco > $window_info($winId,height)} {
	    $winId yview scroll \
		    [expr int($yco-$window_info($winId,height))/$sloth] units
        }
    prolog [list tk_drag( $virtx , $virty )]
}

proc ReleaseObj {winId xco yco} {
    set canx [Unscale $winId [$winId canvasx $xco]]
    set cany [Unscale $winId [$winId canvasy $yco]]
    prolog [list tk_unclick( $canx , $cany )]
}

# This allows Prolog to highlight an object in order to treat its text as being
# edited, if focusing on the window causes a cursor to start flashing in one.

proc EmbraceObj {winId} {
    set nodeId [GetEdit $winId]

    prolog [list tk_embrace( '$winId' , $nodeId )]
}

# This allows prolog to save the values of editing when the window is exited.
# Comment it out to debug edit procedure from separate window.
proc AbandonObj {} {
    prolog tk_abandon
}

# ChangeRegion causes a window to respond to a change in the size of its canvas.
# Strange things can happen if the canvas is shrunk below the size of the viewport
# so a little zoom is slipped in if this looks like happening. This is commented
# out for now because it can send a cmd back to Prolog, which calls this again,
# eventually bursting the stack and bombing out most horribly. Fix it properly
# some time -- OK! 3rd param now cuts out Prolog if 0.

proc ChangeRegion {w l t r b} {
    global window_info
    
    set hcomp [expr [Unscale $w $window_info($w,width)]/($r - $l)]
    set vcomp [expr [Unscale $w $window_info($w,height)]/($b - $t)]
    set comp [expr $hcomp>$vcomp?$hcomp:$vcomp]
    set newReg [list [Scale $w $l] [Scale $w $t] [Scale $w $r] [Scale $w $b]]
    $w configure -scrollregion $newReg
    eval {$w coords 1} $newReg
#ShowMessage debug info "Just done [$w coords 1]" ok
    if {$comp>1} {
	DoZoom $w $comp 0
    }
}

#######################################################################
#                                                                     #
# MainWindowDraw: puts a new model window on the screeen              #
#                                                                     #
#######################################################################

proc MainWindowDraw {winName winTitle wl wt wr wb \
	colour initialScale args} {
    global window_info looks env custom

    set c [ModelWindow $winName]
    global modelWin 
    set modelWin $winName
    
    TweakWindow $c $winTitle 1 $wl $wt $wr $wb $colour
#    wm maxsize $winName [winfo screenwidth $winName] \
#	[winfo screenheight $winName]
    
    wm protocol $winName WM_DELETE_WINDOW \
	    [list byebye $winName]
    
    AddMainMenu $winName [expr $wr-$wl] $args
    AddAccelerators $winName
    AddCanvasBindings $c

    set window_info($c,scale) $initialScale

#    tkwait visibility $winName
    set window_info($c,parent) $winName
    
    InterpMenu $c off
    focus $c
    if {[file exists $custom(prefDir)/layout]} {
	set stream [open $custom(prefDir)/layout r]
	gets $stream whetherMaxed
#ShowMessage debug info $whetherMaxed ok
	maximize_fg_win $whetherMaxed
	close $stream
    }
#    ShowMessage debug info "Messing with [wm frame $winName]" ok
#    maximize_fg_win
    return $c
}

proc AddAccelerators { winName } {
    # file
    bind $winName <Control-n> "MenuSelect $winName.canvas file new"
    bind $winName <Control-o> "MenuSelect $winName.canvas file open"
    bind $winName <Control-s> "MenuSelect $winName.canvas file save"
    bind $winName <Control-p> "PrintNow $winName.canvas PRINTCMD"
    bind $winName <Alt-x> "prolog tk_finish"
    
    #edit
    bind $winName <Control-z> "prolog tk_undo"
    bind $winName <Control-y> "prolog tk_redo"
    bind $winName <Control-f> "FindCaption $winName.canvas"
    bind $winName <F3> "NextCaption $winName.canvas"; # todo
    
    #model
    bind $winName <Control-t> "MenuSelect $winName.canvas file run_tcl"
    bind $winName <Control-b> "MenuSelect $winName.canvas file run_c"
    
    #help
    bind $winName <F1> LaunchHelp; # todo
}

proc AddCanvasBindings { c } {
    bind $c <Button-1> {DropObj %W %x %y}
# Doubleclicks now bound to objects not canvas
    bind $c <Double-1> {ZapObj %W %x %y}
    bind $c <B1-Motion> {DragObj %W %x %y}
    bind $c <ButtonRelease-1> {ReleaseObj %W %x %y}
    bind $c <Button-3> {PostMenu %W %X %Y}
    bind $c <FocusIn> {EmbraceObj %W}
    bind $c <FocusOut> {AbandonObj}

# text/clipboard action from Welch example
    bind $c <<Cut>> {CanvasTextCopy %W; CanvasDelete %W}
    bind $c <<Copy>> {CanvasTextCopy %W}
    bind $c <<Paste>> {CanvasPaste %W}

# let's be sure never to show the highlight border...
# (except for debugging)

    $c configure -highlightcolor white
# now confer editability on the editable text items on this canvas
    CanvasEditBind $c
# and clickability, for things where Prolog doesn't know where they
# are (Motion not in use...if prolog wants to know it can ask)
    $c bind all <Button-1> {ClickObj %x %y %W click}
    $c bind all <Double-1> {ClickObj %x %y %W doubleclick}

# Stuff to put a popup help window on a canvas item
    $c bind all <Enter> [list QueuePopup "AddEqnPopup %x %y %W %X %Y"]
    $c bind all <Leave> RemovePopup
}

# Canvas chapter (of Welch)

# Bindings for canvas Text items

proc CanvasEditBind { c } {

	$c bind currently_editable <B1-Motion> {
		%W select to current \
			@[join [canvasTLDistance %W [%W canvasx %x] \
			[%W canvasy %y]] ,]
	}
	$c bind currently_editable <Delete> {
		if {[%W select item] != {}} {
			%W dchars [%W select item] sel.first sel.last
		} elseif {[%W focus] != {}} {
			%W dchars [%W focus] insert
		}
	}
	$c bind currently_editable <Control-d> {
		if {[%W focus] != {}} {
			%W dchars [%W focus] insert
		}
	}
	$c bind currently_editable <Control-h> {
		if {[%W select item] != {}} {
			%W dchars [%W select item] sel.first sel.last
		} elseif {[%W focus] != {}} {
			set _t [%W focus]
			%W icursor $_t [expr [%W index $_t insert]-1]
			%W dchars $_t insert
			unset _t
		}
	}
	$c bind currently_editable <BackSpace> \
		[$c bind currently_editable <Control-h>]

	$c bind currently_editable <Control-Delete> {
		%W delete [%W focus]
	}
	$c bind currently_editable <Return> {
		%W insert [%W focus] insert \n
	}
	$c bind currently_editable <Any-Key> {
	    # do not allow control chars other than the above mentioned
	    if {[string compare %A { }] > -1} {
		if {[%W select item] != {}} {
		    %W dchars [%W select item] sel.first sel.last
		}
		%W insert [%W focus] insert %A
	    }
	}
	bind $c <Button-2> {
		if {[catch {selection get} _s] == 0} {
			if {[%W focus] != {}} {
			    %W insert [%W focus] insert $_s
			}
			unset _s
		}
	}
	$c bind currently_editable <Key-Right> {
		%W icursor [%W focus] [expr [%W index [%W focus] insert]+1]
	}
	$c bind currently_editable <Control-f> \
		[$c bind currently_editable <Key-Right>]

	$c bind currently_editable <Key-Left> {
		%W icursor [%W focus] [expr [%W index [%W focus] insert]-1]
	}
	$c bind currently_editable <Control-b> \
		[$c bind currently_editable <Key-Left>]

	$c bind currently_editable <Key-Home> {
		%W icursor [%W focus] 0
	}
	$c bind currently_editable <Control-a> \
		[$c bind currently_editable <Key-Home>]

	$c bind currently_editable <Key-End> {
		%W icursor [%W focus] end
	}
	$c bind currently_editable <Control-e> \
		[$c bind currently_editable <Key-End>]
}

# Next three procs are from Welch examples

proc CanvasDelete {c} {
	if {[$c select item] != {}} {
		$c dchars [$c select item] sel.first sel.last
	} elseif {[$c focus] != {}} {
		$c dchars [$c focus] insert
	}
}

proc CanvasTextCopy {c} {
	if {[$c select item] != {}} {
		clipboard clear
		set t [$c select item]
		set text [$c itemcget $t -text]
		set start [$c index $t sel.first]
		set end [$c index $t sel.last]
		clipboard append [string range $text $start $end]
	} elseif {[$c focus] != {}} {
		clipboard clear
		set t [$c focus]
		set text [$c itemcget $t -text]
		clipboard append $text
	}
}

proc CanvasPaste {c {x {}} {y {}}} {
	if {[catch {selection get} _s] &&
		 [catch {selection get -selection CLIPBOARD} _s]} {
		return		;# No selection
	}
	$c insert [$c focus] insert $_s
}


# update display detail. This process sets the display depth of component
# types more important than the one that has been adjusted to be at
# least as deep, and those less important to be at least as shallow,
# as the one explicitly changed. Second MenuSelect is commented out as
# Prolog does the same thing itself to avoid many redraws (aargh!)

proc WindowDetail {window category level redraw} {
#    global rads
    MenuSelect $window window detail($category,$level,$redraw)
#    set cats {ghost_link influence variable flow compartment submodel}
#    if {[lsearch $cats $category]>-1} {
#	set hiding 1
#	foreach cat $cats {
#	    if {[string match $category $cat]} {
#		set hiding 0
#	    } elseif {$hiding && $rads($cat)>$level || \
#		    !$hiding && $rads($cat)<$level} {
#		set rads($cat) $level
#		MenuSelect $window window \[detail,$cat,$level\]
#	    }
#	}
#    }
}

proc PostMenu {canvas x y} {
    tk_popup [winfo parent $canvas]top.edit $x $y
}

# This patches a bug with error reporting in Tk 8.0. Also puts up a
# feedback window allowing progress reports on long activities.

proc MenuSelect { window button item } {
	global exports
	if {[lsearch "run_c run_tcl load_exec" $item] != -1} {
	    set exports(running_window) $window
	}
	if [string match local $button] {
	    DoLocalCmd $window $item
	} else {
	    set command tk_menu('$window',$button,'$item')
	    DoWithErrors prolog $command
	}
}

proc DoLocalCmd {win item} {
    global pushedbutton
    switch $item {
	print {PrintNow $win PRINTCMD}
	rerun {Rerun $win 1}
	undo {prolog tk_undo}
	redo {prolog tk_redo}
	zoomin {DoZoom $win 1.414214 1}
	tofit {DisplayAll $win}
	zoomout {DoZoom $win .707107 1}
	customize {Customize $win $pushedbutton}
	find {FindCaption $win}
	findnext {NextCaption $win}
    }
}

# I think the only reason for having this is to work around a Windows bug
# where the Prolog errors didn't come up properly...
proc DoWithErrors {args} {
    if [catch $args err] {
	bgerror $err
    }
}

# Export a postscript file from a window. Only the bit of the diagram showing in
# the viewport is included, and the output is in landscape mode, sized so 100
# pixels = 1 inch (so my beautiful 1152x864 screen will be about a sheet of A4)

proc ExportPostscript { winId } {
    set psfile [ChooseFile image.ps "Name of postscript file" 1]
    # check for cancel
    if {![string match */ $psfile]} {

	# force .ps extension
	if {[string compare [file extension $psfile] .ps]} {
	    set psfile [file root $psfile].ps
	}
	SpitPS $winId $psfile
    }
}

proc PrintNow {winId toDo} {
	global env tcl_platform

#    if {[string match windows $tcl_platform(platform)]} {
#	set detail 4
#	scan [$winId bbox size_on_this] "%d %d %d %d" bl bt br bb
#	$winId move all [expr -$bl] [expr -$bt]
#	ZoomImage $winId all $detail $detail
#	ide_print_canvas $winId
#	ZoomImage $winId all [expr 1.0/$detail] [expr 1.0/$detail]
#	$winId move all $bl $bt
#   } else {
    set tempPSFile $env(SIMTMPDIR)/temp.ps
    SpitPS $winId $tempPSFile
    if {[catch "exec $env($toDo) {[file nativename $tempPSFile]}" result]} {
	ShowMessage "Print command result" warning \
		"Printing seems to have failed. \
The result returned by the print command was:

$result

Please see the online help to find out more about setting up printing from Simile. Alternatively you can export the model diagram as a PostScript file (use the File...Export menu command) and then print that using another package." ok
    }
    file delete $tempPSFile
#   } for some reason comment braces have to match
}
	
proc SpitPS {winId psfile} {
	global window_info tcl_platform
# now, zoom in by detail factor to get the line thickness resolution decent
	set detail 16
# For font scale 1 seems right for Unix -- Windows takes about 1.6
    if {[string match windows $tcl_platform(platform)]} {
	set fontscale 1.6
    } else {
	set fontscale 1
    }
	ZoomImage $winId all $detail [expr $fontscale*$detail]
	$winId postscript -file $psfile -rotate true -pageanchor nw \
		-pagex 0 -pagey 0 \
		-x [expr $detail*[$winId canvasx 0]] \
		-y [expr $detail*[$winId canvasy 0]] \
		-width [expr $detail*([$winId canvasx $window_info($winId,width)] \
		- [$winId canvasx 0])] \
		-height [expr $detail*([$winId canvasy $window_info($winId,height)] \
		- [$winId canvasy 0])] \
		-pagewidth [expr $window_info($winId,width)/100.0]i \
		-pageheight [expr $window_info($winId,height)/100.0]i
	ZoomImage $winId all [expr 1.0/$detail] [expr 1.0/($fontscale*$detail)]
}

proc Reopen {canvas oldFile} {
    global custom

    RecordPathChoice .sml $oldFile
    set custom(hotlist) [linsert $custom(hotlist) 0 $oldFile]
    MenuSelect $canvas reopen $oldFile
}

menu .openrecent -tearoff 0

proc FillReopen {winId} {
    global custom

    .openrecent delete 0 end
    set posted {}
    foreach hottie $custom(hotlist) {
	if {[llength $posted] >= [PrefValue custom(recentCount) recentCount]} {
	    break
	}
	if {[file exists $hottie] && [lsearch $posted $hottie]==-1} {
	    .openrecent add command -label [file tail $hottie] \
		    -command [list Reopen $winId.canvas $hottie]
	    lappend posted $hottie
	}
    }
}

proc AddMainMenu { winid initWidth initDepths} {
    global custom MIpushedbutton

    set fm [menu ${winid}top.file -tearoff 0 \
            -postcommand "FillReopen $winid"]
    ${winid}top add cascade -label File -underline 0 -menu ${winid}top.file
    $fm add command -label New -command "MenuSelect $winid.canvas file new"\
            -accelerator "Ctrl+N"
    $fm add command -label Open... -command "MenuSelect $winid.canvas file open"\
            -accelerator "Ctrl+O"
    $fm add cascade -label "Reopen" -menu .openrecent
    $fm add command -label Save -command "MenuSelect $winid.canvas file save" \
            -accelerator "Ctrl+S"
    $fm add command -label "Save as..." \
            -command "MenuSelect $winid.canvas file save_as"
    $fm add separator
    $fm add command -label "Print..." \
            -command "PrintNow $winid.canvas PRINTCMD"\
            -accelerator "Ctrl+P"
    $fm add cascade -label "Export" -menu $fm.sub1
    set fm2 [menu $fm.sub1 -tearoff 0]
    $fm2 add command -label "C program" \
            -command "MenuSelect $winid.canvas file compile_c"
    $fm2 add command -label "Tcl/Tk script" \
            -command "MenuSelect $winid.canvas file compile_tcl"
    $fm2 add command -label "PostScript file" \
            -command "DoWithErrors ExportPostscript $winid.canvas"
    $fm2 add cascade -label "Equation list" -menu $fm.sub1a
    set fm2a [menu $fm.sub1a -tearoff 0]
    $fm2a add command -label "Legible" \
            -command "MenuSelect $winid.canvas file list_eqns"

    $fm2a add command -label "Prolog" \
            -command "MenuSelect $winid.canvas file prolog_eqns"
    $fm add separator
    if {[info exists custom(first_up)]} {
        $fm add command -label Close -command "byebye $winid"
    } else {
        $fm add command -label Exit -command "prolog tk_finish"\
                -accelerator "Alt+x"
    }
    set fm [menu ${winid}top.edit -tearoff 0]
    ${winid}top add cascade -label Edit -underline 0 -menu ${winid}top.edit
    $fm add command -label Undo -command "prolog tk_undo" \
            -state disabled -accelerator "Ctrl+Z"
    $fm add command -label Redo -command "prolog tk_redo" \
            -state disabled -accelerator "Ctrl+Y"
    AddFindMenu $winid.canvas $fm
    $fm add separator
    $fm add command -label Preferences... -command Pref_Dialog
    
    
    set fm [menu ${winid}top.view -tearoff 0]
    ${winid}top add cascade -label View -underline 0 \
            -menu ${winid}top.view
    $fm add check -label Toolbar -variable custom(shownavbar,$winid) \
            -command "toggleBar $winid"
    $fm add check -command "toggleBar $winid" \
            -label "Component bar" -variable custom(showtoolbar,$winid)
    $fm add check -command "toggleBar $winid" \
            -label "Equation bar" -variable custom(showeqnbar,$winid)
    $fm add separator
    AddZoomMenu $winid.canvas $fm 1
    $fm add cascade -label "Show detail" -menu $fm.sub3
    set fm3 [menu $fm.sub3 -tearoff 0]
    AddDetailMenu $winid.canvas $fm3 $initDepths
    $fm add command -label "Customize..." \
	    -command "DoLocalCmd $winid customize"
    
    set fm [menu ${winid}top.model -tearoff 0]
    ${winid}top add cascade -label Model -underline 0 \
            -menu ${winid}top.model
    $fm add command -label "Build In Tcl" \
            -command "MenuSelect $winid.canvas file run_tcl" \
            -accelerator "Ctrl+T"
    $fm add command -label "Build In C++" \
            -command "MenuSelect $winid.canvas file run_c" \
            -accelerator "Ctrl+B"
    if {[info exists custom(first_up)]} {
        $fm entryconfigure "Build In Tcl" -state disabled
        $fm entryconfigure "Build In C++" -state disabled
    } else {
        set custom(first_up) $winid
    }
    $fm add separator
    $fm add cascade -label Add -menu $fm.sub1
    set fm1 [menu $fm.sub1 -tearoff 0]
    $fm1 add radiobutton -label Compartment -command "ItemSelect compartment"\
            -variable MIpushedbutton -value compartment
    $fm1 add radiobutton -label Variable -command "ItemSelect variable"\
            -variable MIpushedbutton -value variable
    $fm1 add radiobutton -label Flow -command "ItemSelect flow"\
            -variable MIpushedbutton -value flow
    $fm1 add radiobutton -label Influence -command "ItemSelect influence"\
            -variable MIpushedbutton -value influence
    $fm1 add radiobutton -label Submodel -command "ItemSelect submodel"\
            -variable MIpushedbutton -value submodel
    $fm1 add radiobutton -label Relation -command "ItemSelect relation"\
            -variable MIpushedbutton -value relation
    $fm1 add radiobutton -label Creation -command "ItemSelect creation"\
            -variable MIpushedbutton -value creation
    $fm1 add radiobutton -label Immigration -command "ItemSelect immigration"\
            -variable MIpushedbutton -value immigration
    $fm1 add radiobutton -label Reproduction -command "ItemSelect reproduction"\
            -variable MIpushedbutton -value reproduction
    $fm1 add radiobutton -label Loss -command "ItemSelect loss"\
            -variable MIpushedbutton -value loss
    $fm1 add radiobutton -label Condition -command "ItemSelect condition"\
            -variable MIpushedbutton -value condition
    $fm add command -label "Properties..." \
            -command "MenuSelect $winid.canvas edit properties"
    $fm add cascade -label Flip -menu $fm.sub2
    set fm2 [menu $fm.sub2 -tearoff 0]
    $fm2 add command -label Horizontal \
            -command "MenuSelect $winid.canvas edit flip_h"
    $fm2 add command -label Vertical \
            -command "MenuSelect $winid.canvas edit flip_v"
    $fm add separator
    $fm add command -label "Save interface" \
            -command "MenuSelect $winid.canvas file save_interface"
    $fm add command -label "Load interface" \
            -command "MenuSelect $winid.canvas edit set_interface"
    
    
    set fm [menu ${winid}top.tools -tearoff 0]
    ${winid}top add cascade -label Tools -underline 0 \
            -menu ${winid}top.tools
    $fm add radiobutton -label Move -command "ModeSelect move"\
            -variable MIpushedbutton -value move
    $fm add radiobutton -label "Copy submodel" -command "ModeSelect copy"\
            -variable MIpushedbutton -value copy
    $fm add radiobutton -label Ghost -command "ModeSelect ghost"\
            -variable MIpushedbutton -value ghost
    $fm add radiobutton -label Annotate -command "ModeSelect select"\
            -variable MIpushedbutton -value annotate
    $fm add radiobutton -label Delete -command "ModeSelect delete"\
            -variable MIpushedbutton -value delete
    
    set fm [menu ${winid}top.help -tearoff 0]
    ${winid}top add cascade -label Help -underline 0 -menu ${winid}top.help
    $fm add command -label Contents -command LaunchHelp \
            -accelerator "F1"
    $fm add command -label About... -command [list ShowAbout $winid]
    
    set nb [frame $winid.toolSlot.navbar -border 2]
    if {[PrefValue custom(bigButtons) bigButtons]} {
	set buttonImages ../Images/Toolbar/Large
    } else {
	set buttonImages ../Images/Toolbar
    }
    foreach navCmd {{new {file new}} {open {file open}} \
                {save {file save}}  {print {local print}} \
                {undo {local undo}} {redo {local redo}} \
                {flip_h {edit flip_h}} {flip_v {edit flip_v}} \
                {zoomin {local zoomin}} {zoomfit {local tofit}} \
                {zoomout {local zoomout}}   } {
        set handle [lindex $navCmd 0]
        set testImg [image create photo -file $buttonImages/${handle}.gif]
        pack [button $nb.$handle -image $testImg -borderwidth 3 \
                -command [concat "MenuSelect $winid.canvas" [lindex $navCmd 1]]] \
                -side left
        BindPopup $nb.$handle $handle
    }
    pack [frame $nb.spacer -width 12 -height 24] -side left
    
    foreach navCmd {{rerun {local rerun}} {find {local find}} {findmore {local findnext}}} {
        set handle [lindex $navCmd 0]
        set testImg [image create photo -file $buttonImages/${handle}.gif]
        pack [button $nb.$handle -image $testImg -borderwidth 3 \
                -command [concat "MenuSelect $winid.canvas" [lindex $navCmd 1]]] \
                -side left
        BindPopup $nb.$handle $handle
    }
    set tb [frame $winid.toolSlot.toolbar -border 2]
    foreach mode {compartment variable flow influence submodel \
                relation creation immigration reproduction loss condition} {
        set testImg [image create photo -file $buttonImages/${mode}.gif]
        pack [button $tb.$mode -image $testImg -command "ItemSelect $mode" \
                -borderwidth 3] -side left
        BindPopup $tb.$mode $mode
    }
    pack [frame $tb.spacer -width 12 -height 24] -side left
    foreach mode {select move delete copy ghost} {
        set testImg [image create photo -file $buttonImages/${mode}.gif]
        pack [button $tb.$mode -image $testImg -command "ModeSelect $mode" \
                -borderwidth 3] -side left
        BindPopup $tb.$mode $mode
    }
    $tb.select configure -relief sunken
    # heheheh...must be in select mode to make new window, except first    

### Formula bar section
### Robert Muetzelfeldt
### Started 4/3/02
    set eb [frame $winid.toolSlot.eqnbar -border 1 -relief raised]
    
    label $eb.label -anchor e
    pack $eb.label -side left

    
    entry $eb.equation -width 40
    pack $eb.equation -side left -expand 1 -fill x
    bind $eb.equation <Return> [list accept_equation $eb.equation]
    bind $eb.equation <FocusIn> "EmbraceEqn $winid"
    bind $eb.equation <FocusOut> AbandonEqn
    set image [image create photo -file "../Images/Eqnbar/tick.gif"]
    pack [button $eb.tick -state disabled -image $image -borderwidth 1 \
            -command [list accept_equation $eb.equation]] -side left
    
    set image [image create photo -file "../Images/Eqnbar/cross.gif"]
    pack [button $eb.cross -state disabled -image $image -borderwidth 1 \
            -command [list restore_equation $eb]] -side left
    
    frame $eb.padding -width 10
    pack $eb.padding -side left
    
    set image [image create photo -file "../Images/Eqnbar/inputs.gif"]
    menubutton $eb.inputs -state disabled -menu $eb.inputs.menu \
	    -borderwidth 2 -relief raised -image $image
    pack $eb.inputs -side left
    set m [menu $eb.inputs.menu -tearoff 0 -postcommand [list AddInputs $eb]]
#    $m add command -label biomass -command bell
#    $m add command -label k -command bell
    
    set image [image create photo -file "../Images/Eqnbar/function.gif"]
    menubutton $eb.function -state disabled -menu $eb.function.menu \
	    -borderwidth 2 -relief raised -image $image
    pack $eb.function -side left
    set m [menu $eb.function.menu -tearoff 0]
    global equation
    set useFunctions [lrange $equation(fnDefs) 0 9]
    foreach defn $useFunctions {
	set cmd [lindex $defn 0]
	$m add command -label $cmd\(\) \
		-command [list InsertFunction $eb.equation $cmd]
    }
    $m add command -label "All functions..." -command bell
    
#   set image [image create photo -file "../Images/eqnbar/props.gif"]
#   pack [button $eb.properties -state disabled -image $image -borderwidth 1] \
#           -side left

### End of formula bar section

    update idletasks ;# to allow reqwidth to be calculated
    set navWidth [winfo reqwidth $tb] ;# tool bar is widest
#ShowMessage debug info "Toolbar needs $navWidth" ok
    set custom(showtoolbar,$winid) [expr $initWidth>=$navWidth && \
            [PrefValue custom(initToolbar) initToolbar]]
    set custom(shownavbar,$winid) [expr $initWidth>=$navWidth && \
            [PrefValue custom(initNavbar) initNavbar]]
    set custom(showeqnbar,$winid) [expr $initWidth>=$navWidth && \
            [PrefValue custom(initEqnbar) initEqnbar]]

    if {$custom(shownavbar,$winid)} {
        pack $nb -fill x
    }
    if {$custom(showtoolbar,$winid)} {
        pack $tb -fill x
    }
    if {$custom(showeqnbar,$winid)} {
	pack $eb -fill x
    }

    $nb.undo configure -state disabled
    $nb.redo configure -state disabled
}

proc EmbraceEqn {winid} {
    global equationbar
    prolog tk_embrace('$winid.canvas',$equationbar(node))
}

proc AbandonEqn {} {
    prolog tk_abandon_eqn
}
    
# should check env to get system directory
proc LaunchHelp {} {
    global tcl_platform
    if {[string match windows $tcl_platform(platform)]} {
	exec hh.exe ../Help/simile.chm &
    } else {
	exec netscape ../Help/HTML/index.htm &
    }
}

proc ShowAbout {winId} {
    global sendvars userinfo
    toplevel .about
    wm transient .about $winId
    wm title .about About\ SIMILE
    image create photo drip
    drip read ../Images/drip.gif

    pack [frame .about.f] -fill x -expand true
    pack [label .about.f.dl -image drip] -side left
    pack [label .about.f.dr -image drip] -side right
    pack [label .about.f.l0]
    pack [label .about.f.l1 -text SIMILE]
    pack [label .about.f.l2 -text Simulistics\ Ltd.]
    pack [label .about.f.l3]
    pack [label .about.f.l4 -text Version\ $sendvars(simV)]
#    pack [label .about.f.l5 -text [clock format [file mtime ../Run/main.sav]]]
    pack [label .about.f.l6 -text "Prolog: $sendvars(proV)"]
    pack [label .about.f.l7 -text "TclTk: [info patchlevel]"]
    pack [label .about.l6]
    pack [label .about.l7 -text "This product is registered to \
$userinfo(Name), $userinfo(Corp)"]
#    pack [label .about.l8 -text "for NON-COMMERCIAL use only."]
    pack [label .about.l9]
    pack [label .about.l10 -text "(C) Copyright 2002, Simulistics Ltd."]
    pack [message .about.l12 -width 400 -text "Acknowledgements. \
    Portions of this software are copyright University of Edinburgh, \
    and Crown Copyright, Department for International Development."]
    pack [label .about.l13]
    pack [label .about.l14 -text "Supplied under licence."]
    pack [label .about.l15]

#    append mess "Version $sendvars(simV), \
#	[clock format [file mtime ../Run/main.sav]]\n"
#    append mess "using Prolog $sendvars(proV)\n"
#    append mess "and TclTk [info patchlevel]\n"
    pack [button .about.b -text OK -command "set sendvars(doneAbout) 1"]
    pack [label .about.l16]
    wm geometry .about +[expr [winfo screenwidth .]/2-200]+[expr [winfo screenheight .]/2-250]
    grab .about
    tkwait variable sendvars(doneAbout)
    grab release .about
    destroy .about
}

# toggler unpacks and repacks all bars to keep order right
proc toggleBar {winId} {
    global custom
    foreach which {nav tool eqn} {
	set barname $winId.toolSlot.${which}bar
	if {![catch {pack info $barname}]} {
	    pack forget $barname
	}
	$winId.toolSlot configure -height 1
	if {$custom(show${which}bar,$winId)} {
	    pack $barname -fill x
	}
    }
}

proc AddDetailMenu {winId fm3 initVals} {
	global rads
	set posn 0
	foreach category { \
		{ghost_link "Ghost links..."} \
		{influence "Influences..."} \
		{variable "Variables..."} \
		{flow "Flows and clouds..."} \
		{compartment "Compartments..."} \
		{submodel "Submodels and relations..."} \
		{caption "Captions..."}} {
	    set cat [lindex $category 0]
	    set rads($winId,$cat) [lindex $initVals $posn]
		incr posn
	    $fm3 add cascade -label [lindex $category 1] \
		    -menu $fm3.$cat
	    set lastmenu [menu $fm3.$cat -tearoff 0]
	    $lastmenu add radio -label "None" -variable rads($winId,$cat) \
		    -value 0 -command "WindowDetail $winId $cat 0 1"
	    foreach depth {1 2 3 4 5 6} {
		$lastmenu add radio -label "$depth levels" \
			-variable rads($winId,$cat) -value $depth \
			-command "WindowDetail $winId $cat $depth 1"

	    }
	    $lastmenu add radio -label "All" -variable rads($winId,$cat) \
		    -value 32 -command "WindowDetail $winId $cat 32 1"
	}
	$fm3 add cascade -label "Influence sections..." -menu $fm3.sections
	set lastmenu [menu $fm3.sections -tearoff 0]
	set rads($winId,sections) [lindex $initVals $posn]
	foreach sectType {Local Terminal All} {
	    $lastmenu add radio -label $sectType \
		    -variable rads($winId,sections) -value show$sectType \
		    -command "WindowDetail $winId sections show$sectType 1"
	}
}

proc Rerun {winId go} {
    global runState running_c

    if {$runState(modelRunning)!=2} {
	if {![info exists running_c]} {
	    set runType run_tcl
	} else { 
	    if {$running_c} {
		set runType run_c
	    } else {
		set runType run_tcl
	    }
	}
	MenuSelect $winId file $runType
    } else {
	RunDialog $winId
	$runState(helperId).topbuttons.reset invoke
    }
    # Only proceed if it worked
    if {$go && $runState(modelRunning) == 2} {
	$runState(helperId).topbuttons.start invoke
    }
}

proc UpdateDoButtons {un re} {
    global window_info
    foreach winData [array name window_info *,parent] {
	set navBar $window_info($winData).toolSlot.navbar
	$navBar.undo configure -state [ChooseText $un normal disabled]
	$navBar.redo configure -state [ChooseText $re normal disabled]
    }   
}

proc ToggleIOToolMenu {on} {
    global window_info
    foreach winData [array name window_info *,parent] {
	set topMenu $window_info($winData)top
	if {$on} {
	    $topMenu insert "Help" cascade -label "I/O tools" -underline 0 \
		    -menu .helpers
# note Welch says put 'insert' and index other way round and give index to
# left of new one rather than right. He's wrong.
	} else { 
	    catch {$topMenu delete "I/O tools"}
	}
    }
}

proc UpdateDoMenu {canId un re} {
	set winId [winfo parent $canId]
	${winId}top.edit entryconfigure Undo \
			-state [ChooseText $un normal disabled]
	${winId}top.edit entryconfigure Redo \
			-state [ChooseText $re normal disabled]
}

proc InterpMenu {winId state} {
	global sendvars
	set sendvars(boxsize) 240
}

#initialize this variable, any button will do (if it is sunken)

set pushedbutton select

proc ModeSelect {modes} {
   global pushedbutton
   UpdateToolbars $modes
   set pushedbutton $modes
   prolog [list tk_mode_select( $modes )]
}

proc ItemSelect {newItem} {
    global adds
    set adds $newItem
    global pushedbutton
    UpdateToolbars $newItem
    set pushedbutton $newItem
    prolog [list tk_menu_select( $newItem , from_box)]
}

# Change indentation of toolbar buttons. Apply in all desktop windows
# ie. those not in helper list

proc UpdateToolbars {newAction} {
    global pushedbutton window_info MIpushedbutton
    set MIpushedbutton $newAction
    foreach winData [array name window_info *,parent] {
	set toolBar $window_info($winData).toolSlot.toolbar
	$toolBar.$pushedbutton configure -relief raised
	$toolBar.$newAction configure -relief sunken
	ResetEqnBar $window_info($winData).toolSlot.eqnbar
    }
}

proc ResetEqnBar {bar} {
    $bar.equation delete 0 end
    $bar.label configure -text {}
    SetEqnButtonState $bar disabled
}

proc SetEqnButtonState {bar newState} {
    foreach eqnButton {tick cross inputs function} {
	$bar.$eqnButton configure -state $newState
    }
}

proc RaiseModelWindow {} {
    global modelWin
    raise $modelWin
}

##############################    Formula bar    #############################

proc accept_equation {text} {
    global equation
    global equationbar
    
    set equationbar(current_action) tick
    set equationbar(equation) [string trimright [$text get]]
    set winId $equationbar(winId)
    set xco $equationbar(xco)
    set yco $equationbar(yco)
    set node $equationbar(node)
    prolog [list tk_click_obj('$winId',  doubleclick, $xco , $yco , $node)]
    focus $winId
}

proc AddInputs {bar} {
    global equationbar
    $bar.inputs.menu delete 0 end
    set winId $equationbar(winId)
    set node $equationbar(node)
    foreach paramName [GetFromProlog tk_get_params('$winId',$node)] {
	$bar.inputs.menu add command -label $paramName \
		-command [list InsertParam $bar $paramName]
    }
}

proc InsertParam {bar paramName} {
    $bar.equation insert insert $paramName
    focus $bar.equation
}

proc restore_equation {bar} {
    global equationbar
    $bar.equation delete 0 end
    $bar.equation insert end $equationbar($bar)
    focus $bar.equation
}

##############################    Formula bar    #############################

