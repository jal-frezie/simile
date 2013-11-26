# Simile source code file: Run/window.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for drawing the main window.
#

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

proc ChangeScale {winId factor} {
    global window_info

    set window_info($winId,scale) [expr $window_info($winId,scale)/$factor]
}

# procedure called when Prolog wants to know what object is at a point

proc FindObj { winId x y } {
    set canx [Scale $winId $x]
    set cany [Scale $winId $y]
    
    return [ExtractPrologName $winId [GetClickedObj $winId $canx $cany 6]]
}

# New to 4.8: get nodular component overlaps from GUI, in a list
# This would be worth fixing with tag logic if still used)
# proc FindAllObjs {winId l t r b} {
#     set box [ScaleRect $winId $l $t $r $b]
#     $winId addtag /no_collide/ all
#     eval {$winId addtag /on_target/ overlapping} $box
#     $winId dtag size_on_this /no_collide/
#     $winId dtag /no_collide/ /on_target/
#     set bitz [$winId find withtag /on_target/]
#     $winId dtag /no_collide/
#     $winId dtag /on_target/

#     set proggles {}
#     foreach bit $bitz {
# 	set plName [ExtractPrologName $winId $bit]
# 	if {[lsearch $proggles $plName]==-1} {
# 	    lappend $proggles $plName
# 	}
#     }    
#     return $proggles
# }

# canvasTLDistance returns the offset of a canvas coordinate from its top
# left corner. If you are going to use @x,y to refer to a point in a canvas
# text item, these are the values you need (this is a bug in TclTk)

proc canvasTLDistance {winId x y} {
    if {[scan [$winId cget -scrollregion] "%g %g" cl ct]==2} {
        return [list [expr $x-$cl] [expr $y-$ct]]
    } else {
        return [list $x $y]
    }
}

# This is used when Tcl wants to get a result from Prolog, e.g., for the
# equation bar. The prolog procedure has to set fromProlog. It should stop
# the thread until it returns, but something is wrong -- occasionally
# fromProlog doesn't get set. Answer: set it first. Or fix the actual
# bug -- it seems 'update idletasks' somehow interferes with this,
# resulting in the variable not getting set, or something. Bug seems fixed now
# by new pipe interface technology -- might still do funnies if the Prolog
# command calls Tcl back though...

proc GetFromProlog {prologCmd} {
    global fromProlog
    set fromProlog {}
    prolog $prologCmd
    return $fromProlog
}

# This does similar to the above but gets the translation table, specially
# for aliasing into the execution interpreters. It's a stopgap, as the
# translation table should really be in the model code (it is now).
#
#proc GetTransTable {node} {
#    global fromProlog
#    prolog tk_get_info({},$node,types)
#    return $fromProlog
#}
#
# Non-Linux platforms supply extra clicks instead of doubleclicks if
# processing the initial click or release takes too long, so we keep
# track with this variable in order to convert it back into a
# doubleclick if necessary. Values are:
# quiet: nothing happening
# stabbed: clicked and released at this posn

set debounce(down) quiet

# Procedure for when Tcl recognizes what object is clicked but being a
# maleficent pile of junk refuses to pass on this information so we have
# to interrogate it to find what is closest to the click point
# (actually "$canvas find withtag current" does this, but no point changing now)

set equationbar(enumTypes) {}
proc ClickObj { x y winId X Y action} {
    global debounce equationbar pushedbutton window_info looks
    global tcl_platform
    
    #puts "$action it!"
    
    RemovePopup
    set window_info($winId,lastx) [expr $x/$looks(scrollIncr)]
    set window_info($winId,lasty) [expr $y/$looks(scrollIncr)]
    switch $action {
        ctrl {
            set action click
            set RB 0
            set CD 1
        } right {
            set action click
            set RB 1
            set CD 0
        } ctrl-right {
            set action click
            set RB 1
            set CD 1
        } default {
	    if {[string equal Darwin $tcl_platform(os)]} {
# Removed following line because it stopped doubleclick generating under Linux
# in large models; surely clicking should focus winId anyway? See if WFUW. Was
# needed to edit capt immediately after adding node; do elsewhere in this case
		focus $winId
		if {[string equal busy $debounce(down)]} {
		    set action doubleclick
		}
	    } 
	    set debounce(down) busy
	    # Nothing works perfectly to restore Windows doubleclicks;
	    # this works a fair amount of the time
	    after idle {after idle {set debounce(down) quiet}}
	    set RB 0
            set CD 0
        }
    }
    
    set debounce(clicktime) [clock clicks -milliseconds]
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set xco [Unscale $winId $canx]
    set yco [Unscale $winId $cany]
#    if {$looks(gridPitch)} {
#   set xco [expr $looks(gridPitch)*round($xco/$looks(gridPitch))]
#   set yco [expr $looks(gridPitch)*round($yco/$looks(gridPitch))]
#   set looks(lastXnode) $xco
#   set looks(lastYnode) $yco
#    }
    set target [GetClickedObj $winId $canx $cany 6]
    if {!$target} {
        # a background click
	focus $winId
        $winId select clear
        $winId focus {}
        if {$RB && [string equal select $pushedbutton]} {
            prolog [list tk_${action}('$winId', $xco , $yco , 2)]
            tk_popup [winfo parent $winId]top.edit $X $Y
            prolog [list tk_unclick( $xco , $yco )]
        } else {
            prolog [list tk_${action}('$winId', $xco , $yco , $CD)]
        }
        return
    }
    # if we have loaded an already built model, its node names may not match
    # the ones given it in Prolog, so get them from the canvas
    set node [ExtractPrologName $winId $target]
    set context [GetClickCapt $winId $canx $cany $node]
    set topNode $window_info($winId,top_node)
    if {[ProdObj $topNode $node $context]} {
	return
    }
    # IO tool took the click, so do no more
    if {[string compare $pushedbutton snap]==0} then {
        snap $topNode $node
    } else {
	set window_info(lastClickCapt) $context
        if {[string equal click $action]} {
            set obj [GetCaptionItem $winId $node]
            
            # This bit used to start a drag selecting some caption text
            if {[string compare $obj {}]} {
                set realPlace @[join [canvasTLDistance $winId $canx $cany] ,]
                $winId icursor $obj $realPlace
                $winId select clear
                if {[lsearch [$winId gettags $obj] selected] != -1} {
                    $winId select from $obj $realPlace
                }
                if {[lsearch [$winId gettags $obj] backbox_is($target)]!=-1} {
                    set CD -1
                }
                if {!$RB && ([string equal $target $obj] || $CD==-1)} {
		    focus $winId ;# get ready to edit canvas text
                    set action clicktext
                }
            }
        }
        prolog [list tk_click_obj('$winId',  $action , $xco , $yco , \
					   $node , $CD)]
        # Right button puts up context menu.
        if {$RB && [string equal select $pushedbutton]} {
	    update
# work round bug in windows menu posning
	    if {[string equal windows $tcl_platform(platform)] && \
		    $Y>[winfo screenheight $winId]/2} {
		tk_popup [winfo parent $winId]top.edit $X $Y 99
	    } else {
		tk_popup [winfo parent $winId]top.edit $X $Y
	    }
            prolog [list tk_unclick( $xco , $yco )]
        }
        
        ### Formula bar
        ### Added by Jasper: ignore all eqnbar stuff if none in current window or
        ### not in pointer mode
        
	set winid [winfo parent $winId]
        set bar $winid.toolSlot.eqnbar
        if {[info exists equationbar(special)]} {
	    unset equationbar(special)
            set equationbar(current_action) null
	} elseif {[catch {pack info $bar}] || \
		      [string compare $pushedbutton select]} {
            set equationbar(current_action) null
        } else {
	    set equationbar(current_action) $action
            #   ModeSelect move
            #   ModeSelect select
        }
        if {[string match $equationbar(current_action) click]} {
	    if {[SafeEqnBarEdit $winid]} { ;# unclick event lost due to dialogue
		prolog [list tk_unclick( $xco , $yco )]
	    }
            set oldEqn [GetFromProlog tk_get_info('$winId',$node,eqn)]
            if {![string match <none> $oldEqn]} {
                set label "[file tail [BlankCrs $context]] = "
                $bar.label configure -text $label
                set equationbar($winid,node) $node
# converts CRs to \n -- use BlankCrs for spaces (non reversible)
                set equationbar(current_action) null
		AddInputs $winid $bar
# now add relevant enumerated types to menu
		set enumTypes \
		    [GetFromProlog tk_get_info('$winId',$node,enum_type_defns)]
		if {![string equal $enumTypes $equationbar(enumTypes)]} {
		    set equationbar(enumTypes) $enumTypes
		    set lname $bar.function.menu.enumtypes
# empty previous ones
		    while {![string equal none [$lname index end]]} {
			destroy [$lname entrycget end -menu]
			$lname delete end
		    }
		    foreach enumType [linsert $enumTypes 0 \
					  [list boolean false true]] {
			set type [lindex $enumType 0]
			set kname $lname.mn[join $type _]
			menu $kname -tearoff 0
			$lname add cascade -menu $kname -label $type
			# put type at top of submenu to insert its text
			$kname add command -label $type \
			    -command [list InsertQuoted $bar $type]
			$kname add separator
			foreach member [lrange $enumType 1 end] {
			    $kname add command -label $member \
				-command [list InsertQuoted $bar $member]
			}
		    }
		}
		array unset equationbar curEvt
		array unset equationbar haveMinMax
		$bar.events configure -values {}
		pack forget $bar.events
		$bar.min delete 0 end
		pack forget $bar.minlabel
		pack forget $bar.min
		array unset equationbar min_entry
		$bar.max delete 0 end
		pack forget $bar.maxlabel
		pack forget $bar.max
		array unset equationbar max_entry
		set type [GetFromProlog tk_get_info('$winId',$node,type)]
                SetEqnButtonState $bar normal
		if {[string equal state $type]} { ;# load the event combobox
		    set evts [GetFromProlog tk_get_triggers('$winId',$node)]
		    if {![llength $evts]} return ;# no equation to enter
		    $bar.events configure -values $evts
		    # display string for first empty or 'red' effect
		    $bar.events current 0
		    pack $bar.events -side left -before $bar.equation
		    set equationbar(curEvt) [$bar.events get]
		    set equationbar($winid,initText) [StripCrs [GetRuleEfct \
								    $oldEqn]]
		} else {
		    set equationbar($winid,initText) [StripCrs $oldEqn]
		    if {$type eq "limit"} {
			$bar.max insert 0 \
			    [GetFromProlog tk_get_info('$winId',$node,max_val)]
			pack $bar.max -side left -after $bar.equation
			pack $bar.maxlabel -side left -after $bar.equation
			$bar.min insert 0 \
			    [GetFromProlog tk_get_info('$winId',$node,min_val)]
			pack $bar.min -side left -after $bar.equation
			pack $bar.minlabel -side left -after $bar.equation
		    }
		}
# next two will be null throughout unless type is limit
		set equationbar($winid,initMax) [$bar.max get]
		set equationbar($winid,initMin) [$bar.min get]
                restore_equation $winid $bar
            }
        }
        ### End equation bar
    }
}

proc SwitchEvent {winId bar} {
    global equationbar

    accept_equation $winId $bar.equation
# now the eqn bar is already up but we need to update the value that was just
# entered, and cancel the switch if Prolog has objected to our new one...
    
    set node $equationbar($winId,node)
    set newEqn [GetFromProlog tk_get_info('$winId',$node,eqn)]
#puts "string equal [$bar.equation get] [GetRuleEfct $newEqn]"
#puts $equationbar(current_action)
    if {[string equal [$bar.equation get] [GetRuleEfct $newEqn]]} {
	# update new local effect
	set equationbar(curEvt) [$bar.events get]
	set equationbar($winId,initText) [GetRuleEfct $newEqn]
    } else {
	# prolog did not use new string, an error must have occurred
	$bar.events set $equationbar(curEvt) ;# reverse user selection
    }
    restore_equation $winId $bar
}

proc GetRuleEfct {pairList} {
    global equationbar

    set pair [lsearch -index 0 -inline -exact $pairList $equationbar(curEvt)]
    return [lindex $pair 1]
}

proc InsertQuoted {field string} {
    InsertParam $field.equation \"$string\"
}

# make sure modeller really wanted to discard any previous edit
# returns whether or not dialogue was displayed
proc SafeEqnBarEdit {winId} {
    global equationbar
    set bar $winId.toolSlot.eqnbar
    if {[string equal normal [$bar.equation cget -state]]} {
	SetEqnButtonState $bar disabled ;# do not do twice
#puts [list [$bar.equation get] is $equationbar($winId,initText)]
        if {[$bar.equation get] ne $equationbar($winId,initText) || \
	    [$bar.max get] ne $equationbar($winId,initMax) || \
	    [$bar.min get] ne $equationbar($winId,initMin)} {
	    set capt [string range [$bar.label cget -text] 0 end-3]
	    switch [PrefValue custom(leaveEqnBar) leaveEqnBar] \
		[tr. {Apply change}] {
		    set choix yes
		} [tr. {Abandon change}] {
		    set choix no
		} default {
		    set choix [Query [list save_eqn_bar $capt] question top \
				   $winId {yes no}]
		}
            if {[string equal yes $choix]} {
                accept_equation $winId $bar.equation
            } else {
		restore_equation $winId $bar ;# avoids asking again
	    }
	    return yes
        }
    }
    return no
}

# This is called when an operatio may have brought into view an area of canvas
# the existence of which was previously unknown to Prolog; it sends the virtual
# coordinates of the current area. l, t, r, b are relative to window.

proc RollBack { winId toProlog l t r b } {
    set newSpace 0
    scan [$winId cget -scrollregion] "%g %g %g %g" cl ct cr cb
        #puts "debug info Rolling from $cl $ct $cr $cb to [$winId canvasx $l] [$winId canvasy $t] [$winId canvasx $r] [$winId canvasy $b]  ok"
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

# Dragging: as well as the Prolog dragging, we implement
# natively the feature that dragging causes the visible area
# of the window to follow the mouse.

proc DragObj {winId xco yco} {
    global window_info looks pushedbutton
    global debounce

    if {[string equal move $pushedbutton]} {
	$winId xview scroll [expr ($window_info($winId,lastx)-$xco/$looks(scrollIncr))] units
	$winId yview scroll [expr ($window_info($winId,lasty)-$yco/$looks(scrollIncr))] units
	set window_info($winId,lastx) [expr $xco/$looks(scrollIncr)]
	set window_info($winId,lasty) [expr $yco/$looks(scrollIncr)]
	return
    }

    set dragtime [clock clicks -milliseconds]
#    if {$dragtime>$debounce(clicktime) && $dragtime-$debounce(clicktime)<100}
    if {[string equal busy $debounce(down)]} {
        return
    }
    set debounce(realdrag) 1

    set canx [$winId canvasx $xco]
    set cany [$winId canvasy $yco]
    set virtx [Unscale $winId $canx]
    set virty [Unscale $winId $cany]
#    if {$looks(gridPitch)} {
#   set virtx [expr $looks(gridPitch)*round($virtx/$looks(gridPitch))]
#   set virty [expr $looks(gridPitch)*round($virty/$looks(gridPitch))]
#
#   if {$virtx==$looks(lastXnode) && $virty==$looks(lastYnode)} {
#       return
#   } else {
#       set looks(lastXnode) $virtx
#       set looks(lastYnode) $virty
#   }
#    }

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
    
    prolog [list tk_drag( $virtx , $virty )] ;# no cursor change
#    update
}

proc ReleaseObj {winId xco yco} {
    global tcl_platform debounce

# this is here because Windows can sometimes generate a drag at a point 
# after the unclick, so it makes it drag back to the actual unclick position
    if {[info exists debounce(realdrag)]} {
	if {[string equal windows $tcl_platform(platform)]} {
	    DragObj $winId $xco $yco
	}
	unset debounce(realdrag)
    }
    set canx [Unscale $winId [$winId canvasx $xco]]
    set cany [Unscale $winId [$winId canvasy $yco]]
    prolog [list tk_unclick( $canx , $cany )]
}

# This allows Prolog to highlight an object in order to treat its text as being
# edited, if focusing on the window causes a cursor to start flashing in one.

proc EmbraceObj {winId} {
    global window_info
    if {![string equal $winId $window_info(current)]} {
	set window_info(current) $winId
	set nodeId [GetEdit $winId]
	if {[llength $nodeId]} {
	    prolog [list tk_embrace( '$winId' , $nodeId )]
	}
    }
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
# some time -- OK! 3rd param now cuts out Prolog if 0. Right thing now done --
# remove it because ResizeBackground does the necessary.

proc ChangeRegion {w l t r b} {
    global window_info
    
    set allowScrollBar [winfo reqwidth [winfo parent $w].yscroll]
    set vw [expr {0.0+$window_info($w,width)-$allowScrollBar}]
    set vh [expr {0.0+$window_info($w,height)-$allowScrollBar}]
#    set hcomp [expr {[Unscale $w $vw]/($r - $l)}]
#    set vcomp [expr {[Unscale $w $vh]/($b - $t)}]
#    set comp [expr $hcomp>$vcomp?$hcomp:$vcomp]
# these ensure new region at least as big as window
    set hSpare [max [expr {([Unscale $w $vw]+$l-$r)/2}] 0]
    set vSpare [max [expr {([Unscale $w $vh]+$t-$b)/2}] 0]
    set newReg [ScaleList $w [list [expr {$l-$hSpare}] [expr {$t-$vSpare}] \
				  [expr {$r+$hSpare}] [expr {$b+$vSpare}]]]
    $w configure -scrollregion $newReg
    eval {ResizeBackgnd $w} $newReg
    #ShowMess debug info "Just done [$w coords 1]" ok
    #    puts $comp
#    if {$comp>1.01} {
#        DoZoom $w $comp 0
#    }
}

#######################################################################
#                                                                     #
# MainWindowDraw: puts a new model window on the screeen              #
#                                                                     #
#######################################################################

proc MainWindowDraw {topNode winName winTitle wl wt wr wb \
            colour initialScale isTopLevel args} {
    global window_info looks env custom
    set c [ModelWindow $winName]
    set custom(showgrids,$c) [PrefValue custom(initGrid) initGrid]
    
    wm protocol $winName WM_DELETE_WINDOW [list byebye $c]
    set window_info($c,top_node) $topNode
    set window_info($c,width) [expr $wr - $wl]
    set window_info($c,height) [expr $wb - $wt]
    if {[set window_info($c,is_top_level) $isTopLevel]} {
	set window_info($c,topCapt) {}
	set lookers [list generic compartment channel text \
			      variable function submodel flow influence \
			 ghost_link relation]
	if {[info exists ::do_events]} {
	    lappend lookers event state squirt
	}
	foreach nodeType $lookers {
	    # add event squirt state to above
	    ResetLooks $topNode $nodeType
	}
    } else {
	set window_info($c,topCapt) $window_info(lastClickCapt)
    }
    
    TweakWindow $c $winTitle $initialScale $wl $wt $wr $wb $colour
    #    wm maxsize $winName [winfo screenwidth $winName] \
    #   [winfo screenheight $winName]
    
    AddMainMenu $winName $topNode [expr $wr-$wl] $isTopLevel $args
    $winName configure  -menu ${winName}top
    set window_info(current) $c
    AddCanvasBindings $c $topNode

    ####### Model window extensions
    set modelWindowExtensions [itcl::find classes ::ModelWindowExtn::*]
    #ShowMess debug info "ModelWindow $winName\n\
    #        $modelWindowExtensions" ok
    foreach extClass $modelWindowExtensions {
        #ShowMess debug info "$extClass " ok
        set extn [$extClass $winName.\#auto $winName]; # create an extension object for the new model window
        if {[catch {$extn MergeMenu} wibble] } {
            ShowMess debug info "Extension $extn failed to merge its menu items.\n\
                   Details: $wibble" ok
        }
    }
    ################
    
    
    #    tkwait visibility $winName
    set window_info($c,parent) $winName
    ToggleIOToolMenu $topNode ;# insert IO tool menu if needed

    InterpMenu $c off
    #    ShowMess debug info "Messing with [wm frame $winName]" ok
    #    maximize_fg_win
    return $c
}

proc ModelWindow {winName} {
    global tcl_platform looks SimileAutoObjLoaded SIMILE_PATH
    menu ${winName}top
    toplevel $winName
    if {[info exists SimileAutoObjLoaded]} {
	wm state $winName withdrawn
    }

#    switch $tcl_platform(platform) {
#        windows { wm iconbitmap $winName \
#		      -default ${SIMILE_PATH}/Run/simile16.ico }
#        unix { wm iconbitmap $winName @${SIMILE_PATH}/Images/dribble.xbm}
#    }
    wm iconphoto $winName splash
    # Create a scrollable canvas
    set c [canvas $winName.canvas -bg white -confine 1 \
	       -xscrollcommand "AdjustCanvas $winName toolSlot x" \
	       -yscrollcommand "AdjustCanvas $winName canvas y" \
	       -xscrollincrement $looks(scrollIncr) \
	       -yscrollincrement $looks(scrollIncr)]
    # scrollincrements set the only way we can get precise scrolling...
    
    # this rectangle will be resized to fill the scrollable area and coloured to
    # show the background
    # $c create rect 0 0 100 100 -outline {} -tag {/base/ /background/}
    
    # space for toolbar
    frame $winName.toolSlot
    pack $winName.toolSlot -fill x
    
    scrollbar $winName.xscroll -orient horizontal \
            -command [list AdjustScroll $c xview]
    scrollbar $winName.yscroll -orient vertical \
            -command [list AdjustScroll $c yview]
    
    pack $c -fill both -expand true
    
    bind $c <Configure> {SetSpace %W %w %h}
    return $c
}

proc AdjustScroll {canvas dir args} {
    if {[string compare [lindex $args 2] units] == 0} {
        set jump [expr 10*[lindex $args 1]]
        $canvas $dir [lindex $args 0] $jump units
    } else {
        eval {$canvas $dir} $args
    }
}

# SetSpace: this command is called when the canvas is 'configured' by attacking
# its window's borders and so forth. It saves the new width and height of the
# canvas (This is Tk 4.0 which is too dumb to do it itself) and informs Prolog
# of the visible area of the scrollregion. We don't get any information about
# which way the window was grown so the diagram is kept in the middle.

proc SetSpace {c w h} {
    global window_info
#puts "SetSpace $c $w $h"
    set cx $window_info($c,width)
    set cy $window_info($c,height)
    set window_info($c,width) [expr $w - 4]
    set window_info($c,height) [expr $h - 4]
    #    ShowMess debug info "New size is $w $h" ok
    RollBack $c 1 [expr ($cx - $w)/2 + 2] [expr ($cy - $h)/2 + 2] \
            [expr ($cx + $w)/2 - 2] [expr ($cy + $h)/2 - 2]
}

proc TransCnvNames {c oldie newbie} {
    $c addtag $newbie withtag $oldie
    $c dtag all $oldie
    return DonePair
}

proc TweakWindow {c winTitle scale wl wt wr wb bg args} {
    global window_info rads
    #    put back if Windows users want respite from their gash placement system
    #    wm geometry $winName +0+84
    
    # set the display depths to those we recorded
    # ShowMess debug info "TweakWindow $c $winTitle $scale $wl $wt $wr $wb $bg $args" ok
    set cats {ghost_link influence variable flow \
                compartment submodel caption sections}
    for {set depthParam 0} {$depthParam < [llength $args]} {incr depthParam} {
        set rads($c,[lindex $cats $depthParam]) [lindex $args $depthParam]
        WindowDetail $c [lindex $cats $depthParam] \
                [lindex $args $depthParam] 0
    }
    
    $c configure -scrollregion "$wl $wt $wr $wb" \
	-width [expr $wr-$wl] -height [expr $wb-$wt]
    set window_info($c,scale) $scale
    # last will be overwritten if drawing from Prolog
    
    ChangeParentTitle $c $winTitle $bg
    
    set topWin [winfo parent $c]
    scan [wm maxsize $topWin] "%d %d" mw mh
    #ShowMess debug info "$wl $wt $wr $wb <> $mw $mh" ok
    if {[pack propagate $topWin] &&
        ($wr-$wl >= $mw-8 || $wb-$wt >= $mh-8)} {
        catch {winfo state $topWin zoomed}
    }
    #ShowMess debug info "Just done [$c coords 1]" ok
}

proc ChangeParentTitle {wc title bg} {
    wm title [winfo parent $wc] [BlankCrs $title]
    if {[string match clear $bg]} {
        set bg {}
    }
    $wc delete /base/
    scan [$wc cget -scrollregion] "%g %g %g %g" bl bt br bb
    
    foreach colour $bg {
        if {[llength $colour]>1} {
            set posn [lindex $colour 1]
            set colour [lindex $colour 0]
        } else {
            set posn Tiled
        }
        set tag "/base/ /background/"
        if {[string equal clear $colour]} {
        } elseif {[catch {image type $colour}]} {
            $wc create rectangle $bl $bt $br $bb -outline {} -fill $colour \
                    -tag $tag
        } else {
            $wc create image $bl $bt -anchor nw -image [image create photo] \
                    -tag [concat $tag "source($colour) posn($posn)"]
        }
    }
    ResizeBackgnd $wc $bl $bt $br $bb
}

set looks(scrollIncr) 10

proc AddGrid {c onCol wl wt wr wb} {
    global looks window_info custom

    if {$custom(showgrids,$c)} {
	set stat normal
    } else {
	set stat hidden
    }
    set interval [expr {[PrefValue custom(gridH) gridH]*$window_info($c,scale)}]
    for {set x [expr $interval*ceil($wl/$interval)]} {$x<$wr} \
	    {set x [expr $x+$interval]} {
	set nearx [expr int($x)]
	$c create line $nearx $wt $nearx $wb -state $stat -fill $onCol \
	    -tag "/background/ /base/ /grid/"
    }
    set interval [expr {[PrefValue custom(gridV) gridV]*$window_info($c,scale)}]
    for {set y [expr $interval*ceil($wt/$interval)]} {$y<$wb} \
	    {set y [expr $y+$interval]} {
	set neary [expr int($y)]
	$c create line $wl $neary $wr $neary -state $stat -fill $onCol \
	    -tag "/background/ /base/ /grid/"
    }
}

set inCocoa [string match CG* [winfo server .]]
proc FixDisabledImgBug {ttkButton} {
# Only do for Cocoa so disabled images greyed elsewhere
    if {$::inCocoa} {
	set origImg [$ttkButton cget -image]
	$ttkButton config -image [list $origImg disabled $origImg]
    }
}

# following is pulled from tclers wiki
proc Gradient {rgb {window .} {swing 0}} {

        foreach {r g b} [winfo rgb $window $rgb] {break}

        ### Figure out color depth and number of bytes to use in
        ### the final result.
        if {($r > 255) || ($g > 255) || ($b > 255)} {
            set max 65535
            set len 4
        } else {
            set max 255
            set len 2
        }

        ### Compute new red value by incrementing the existing
        ### value by a value that gets it closer to either 0 (black)
        ### or $max (white)
	if {$swing==0} {
	    set swing [PrefValue custom(gridD) gridD]
	}
	set factor [expr {-$swing/100.0}]
        set range [expr {$factor >= 0.0 ? $max - $r : $r}]
        set increment [expr {int($range * $factor)}]
        incr r $increment

        ### Compute a new green value in a similar fashion
        set range [expr {$factor >= 0.0 ? $max - $g : $g}]
        set increment [expr {int($range * $factor)}]
        incr g $increment

        ### Compute a new blue value in a similar fashion
        set range [expr {$factor >= 0.0 ? $max - $b : $b}]
        set increment [expr {int($range * $factor)}]
        incr b $increment

        ### Format the new rgb string
        set rgb \
            [format "#%.${len}X%.${len}X%.${len}X" \
                 [expr {($r>$max)?$max:(($r<0)?0:$r)}] \
                 [expr {($g>$max)?$max:(($g<0)?0:$g)}] \
                 [expr {($b>$max)?$max:(($b<0)?0:$b)}]]

        ### Return the new rgb string
        return $rgb
    }

proc ResizeBackgnd {wc l t r b} {
    global window_info looks
    set baseColor $looks(windowColor)
    foreach baseItem [$wc find withtag /base/] {
    switch [$wc type $baseItem] {
        image {
        set baseImg [$wc itemcget $baseItem -image]
        #       set oldW [base$wc cget -width]
        #       set oldH [base$wc cget -height]
        $wc coords $baseItem $l $t
        set w [expr int($r-$l)]
        set h [expr int($b-$t)]
        $baseImg configure -width $w -height $h
        set tags [$wc gettags $baseItem]
        regexp {source\(([^\)]+)\)} $tags all sourceImage
        if {[regexp {posn\(([^\)]+)\)} $tags all sourcePosn]} {
            if {[string equal Scaled $sourcePosn]} {
            set sourceImage [GrowImage $sourceImage $w $h]
            set usingTemp 1
            }
        }
        $baseImg blank
        $baseImg copy $sourceImage -to 0 0 $w $h ;# clever stuff later
        if {[info exists usingSpare]} {
            image delete $sourceImage
        }
        } rectangle {
        $wc coords $baseItem $l $t $r $b
        set baseColor [$wc itemcget $baseItem -fill]
        } line {
        $wc delete $baseItem
        }
        }
    }
    AddGrid $wc [Gradient $baseColor $wc] $l $t $r $b
    $wc lower /base/ ;# should keep them in order
    global window_info
    if {$window_info($wc,is_top_level)} {
	prolog tk_resize_top_win('$wc',[expr $r-$l],[expr $b-$t])
    }
}

proc AcceleratorState {winName menu item state} {
    global accelerator menuPosns
#puts "$item going $state"
    if {[info exists accelerator($menu,$item)]} {
        if {[string match normal $state]} {
	    set numItem $menuPosns($menu,$item)
	    set action [${winName}top.$menu entrycget $numItem -command]
            bind $winName $accelerator($menu,$item) \
		[list DoIfApplicable $winName $item $action]
        } else  {
            bind $winName $accelerator($menu,$item) {}
        }
    }
}

proc AddAccelerator {winName menuName item event} {
#puts "AddAccelerator {winName menu item event} $winName $menu $item $event"
    global accelerator menuPosns
# assume the corresponding entry has just been added to the menu
    set menu ${winName}top.$menuName
    set menuPosns($menuName,$item) [$menu index last]
    if {[string equal none $event]} return
    set accelerator($menuName,$item) $event
    AcceleratorState $winName $menuName $item [$menu entrycget last -state]
}

proc AddCmdAndAccel {winId menuName item command {state normal}} {
    set menu ${winId}top.$menuName
    $menu add command -label [tr. $item] -state $state -command $command
# TRANSLATOR: The following 15 strings can be translated here: $item may be
    # {Save selection as...} Compartment Variable Flow Influence Submodel
    # State Event Squirt {Role arrow} {Text box} Redo {Reroute links}
    # {Align to grid} {Properties...}
    AddAccelerator $winId $menuName $item none
}

proc NotEditingText {winName} {
    set editingCapt [expr [llength [$winName.canvas focus]] \
            && [string match [focus] $winName.canvas]]
    set editingEqn [string match $winName.toolSlot.eqnbar.* [focus]]
    return [expr !$editingCapt && !$editingEqn]
}

proc DoIfApplicable {winName item action} {
# if action is applicable to text, check text edit not in progress before
# applying it to diagram -- not strictly true of Select All but emacsers may
# use ctrl-A to go to beginning of line
#puts $action
    if {[lsearch {Cut Copy Paste Delete "Select all"} $item]==-1 || \
	    [NotEditingText $winName]} {
	eval $action
    }
}

proc AddCanvasBindings { c topNode } {
    global tcl_platform

    KoreanClick $c 1 {ClickObj %x %y %W %X %Y click}
# Bindings are slightly different in the MacVersion because many users have
# one button mice.  Thus ctrl-left click is used to simulate right click,
# and command-left click replaces the function of ctrl-left.    
    if [string match Darwin $tcl_platform(os)] {
        bind $c <Control-Button-1> {ClickObj %x %y %W %X %Y right}
        bind $c <Command-Button-1> {ClickObj %x %y %W %X %Y ctrl}
    } else {
        bind $c <Control-Button-1> {ClickObj %x %y %W %X %Y ctrl}
    }
    bind $c <Double-1> {ClickObj %x %y %W %X %Y doubleclick}
    
    bind $c <B1-Motion> {DragObj %W %x %y}
    bind $c <ButtonRelease-1> {ReleaseObj %W %x %y}
# Bindings are also confused on the Mac by a convention that Tcl/Tk
# has accidentally adopted, that the mouse-wheel is Button-3    
    if [string match Darwin $tcl_platform(os)] {
        bind $c <Button-2> {ClickObj %x %y %W %X %Y right}
        bind $c <Command-Button-2> {ClickObj %x %y %W %X %Y ctrl-right}
        bind $c <ButtonRelease-2> {ReleaseObj %W %x %y}     
    } else {
        bind $c <Button-3> {ClickObj %x %y %W %X %Y right}
        bind $c <Control-Button-3> {ClickObj %x %y %W %X %Y ctrl-right}
        bind $c <ButtonRelease-3> {ReleaseObj %W %x %y}
    }
    bind $c <FocusIn> {EmbraceObj %W}
    bind $c <Leave> {AbandonObj}
#    BindMouseWheel $c
# as style binds mousewheel for all, so to stop this making events for
# ctrl-mousewheel we have to define a non-empty binding for ctrl-mousewheel
# at that level, but it do nothing because errors would result otherwise
    switch [tk windowingsystem] {
	x11 {
	    bind all <Control-Button-4> {return}
	    bind $c <Control-Button-4> {WheelZoom %W 5 %x %y}
	    bind all <Control-Button-5> {return}
	    bind $c <Control-Button-5> {WheelZoom %W -5 %x %y}
	} aqua {
	    bind all <Command-MouseWheel> {return}
	    bind $c <Command-MouseWheel> {WheelZoom %W %D %x %y}
	} default  {
	    bind all <Control-MouseWheel> {return}
	    bind $c <Control-MouseWheel> {WheelZoom %W %D %x %y}
	}
    }
    
    # text/clipboard action from Welch example
    # commented because we can now cut/copy parts of a model
    #    bind $c <<Cut>> {CanvasTextCopy %W; CanvasDelete %W}
    #    bind $c <<Copy>> {CanvasTextCopy %W}
    #    bind $c <<Paste>> {CanvasPaste %W}
    
    # let's be sure never to show the highlight border...
    # (except for debugging)
    
    $c configure -highlightcolor white
    # now confer editability on the editable text items on this canvas
    CanvasEditBind $c
    
    # Stuff to put a popup help window on a canvas item
    # (could use tag 'has_info' for this)
    $c bind has_info <Enter> [list QueuePopup AddEqnPopup $topNode \
            %x %y %W %X %Y]
    $c bind has_info <B1-Enter> RemovePopup ;# make sure it does nothing
    $c bind has_info <Leave> RemovePopup
}

proc WheelZoom {win change x y} {
#    puts [info level 0]
    DoZoom $win [expr {exp($change/100.0)}] $x $y
}

proc AddEqnPopup {node x y winId X Y} {
    global pushedbutton errorInfo runState
    set doDesc [PrefValue custom(compDescPop) compDescPop]
    set doVal [expr [HaveValues $node]>1 && \
            [PrefValue custom(compValPop) compValPop]]
    set doCmt [PrefValue custom(compCmtPop) compCmtPop]
    if {[string compare select $pushedbutton] || \
                !$doDesc && !$doVal && !$doCmt} {
        return
    }
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set target [GetClickedObj $winId $canx $cany 2]
    #puts "Adding for $target"
    #    set target [$winId find closest $canx $cany 1]
    #puts "targeting $target"
    if {$target} {
        set plName [ExtractPrologName $winId $target]
 #       if {$doVal} {
 #           if {[catch {GetCompProperty $node Value $plName} value]} {
 #               set missing [lindex [split $value \"] 1]
 #               set value "Missing value: $missing"
 #           }
 #       }
        PostPopup $X $Y
        if {$doDesc} {
            set desc [GetFromProlog tk_get_info('$winId',$plName,context)]
	    set userDesc [GetFromProlog tk_get_info(dummy,$plName,description)]
            if {[string equal {} $userDesc]} {
		set userDesc [GetFromProlog tk_get_info(dummy,$plName,desc)]
		# same property has different name for submodels
	    }
            if {![string equal {} $userDesc]} {
		append desc { -- } $userDesc
	    }
            # after going Prolog, check popup window still there
            # note colour etc are not comments though they look like them in emacs
            # actually new technology should make this unnecessary
            #if {![winfo exists .popup]} return
            AddPopupMessage $desc \#c0ffc0
        }
        if {$doCmt} {
            set fromProlog [GetFromProlog tk_get_info('$winId',$plName,comment)]
            #if {![winfo exists .popup]} return
	    if {![string length $fromProlog]} {
		set fromProlog [tr. {No comment}]
	    }
            AddPopupMessage $fromProlog \#ffe0c0
        }
        if {$doVal} {
	    set cptPath [GetClickCapt $winId $canx $cany $plName]
	    set execName [GetCompProperty $node IdFromCapt $cptPath]
	    if {[string equal nomatch $execName]} {
		set execName $plName
	    }
            AddPopupMessage novalue \#ffffc0 GetShortVals $node $execName
	    
	}
    }
}

# BWidget::bindMouseWheel --
#
#	Bind mouse wheel actions to a given widget.
#
# Arguments:
#	widget - The widget to bind.
#
# Results:
#	None.
#
# Simile-specific version, with fewer bugs
# Now replaced with style::as from the tklib
#
#proc BindMouseWheel { widget } {
#    if {[string equal aqua [tk windowingsystem]]} {
#	bind $widget <MouseWheel> {%W yview scroll [expr %D/-1] units}
#	bind $widget <Shift-MouseWheel> {%W xview scroll [expr %D/-1] units}
#    } else {
#	bind $widget <MouseWheel> {%W yview scroll [expr %D/-24] units}
#	bind $widget <Shift-MouseWheel> {%W xview scroll [expr %D/-24] units}
#    }
#
##    bind $widget <Button-4> {event generate %W <MouseWheel> -delta  120}
##    bind $widget <Button-5> {event generate %W <MouseWheel> -delta -120}
##    bind $widget <Shift-Button-4> {event generate %W <Shift-MouseWheel> -delta  120}
##    bind $widget <Shift-Button-5> {event generate %W <Shift-MouseWheel> -delta -120}
## event generate mw seems to have stopped working on Linux so go directly to...
#    bind $widget <Button-4> {%W yview scroll -5 units}
#    bind $widget <Button-5> {%W yview scroll 5 units}
#    bind $widget <Shift-Button-4> {%W xview scroll -5 units}
#    bind $widget <Shift-Button-5> {%W xview scroll 5 units}
#
#    bind $widget <Control-Button-4> {event generate %W <Control-MouseWheel> -delta  120}
#    bind $widget <Control-Button-5> {event generate %W <Control-MouseWheel> -delta -120}
#}
#

# Canvas chapter (of Welch)

event add <<Del>> <Delete> <BackSpace>
# Bindings for canvas Text items

proc CanvasEditBind { c } {
    
    $c bind editable <B1-Motion> {
        if {[lsearch [%W gettags [%W focus]] selected] != -1} {
            %W select to [%W focus] \
                    @[join [canvasTLDistance %W [%W canvasx %x] \
                    [%W canvasy %y]] ,]
        }
    }
    $c bind editable <Delete> {
        if {![CanvasDelSeln %W]} {
            %W dchars [%W focus] insert
        }
    FixBackBox %W [%W focus]
    }
    $c bind editable <Control-d> {
        if {[%W focus] != {}} {
            %W dchars [%W focus] insert
        FixBackBox %W [%W focus]
        }
    }
    $c bind editable <Control-h> {
        if {![CanvasDelSeln %W]} {
            set _t [%W focus]
            if {[%W index $_t insert]} {
                %W icursor $_t [expr [%W index $_t insert]-1]
                %W dchars $_t insert
            }
        }
    FixBackBox %W [%W focus]
    }
    $c bind editable <BackSpace> \
            [$c bind editable <Control-h>]
    
    $c bind editable <Control-Delete> {
        %W delete [%W focus]
    FixBackBox %W [%W focus]
    }
    $c bind editable <Return> {
        %W insert [%W focus] insert \n
    FixBackBox %W [%W focus]
    }
    $c bind editable <Any-Key> {
        # do not allow control chars other than the above mentioned
        if {[string compare %A { }] > -1} {
            CanvasDelSeln %W
            %W insert [%W focus] insert %A
        }
    FixBackBox %W [%W focus]
    }
    bind $c <<PasteSelection>> {
    .hidden_e delete 0 end
    event generate .hidden_e <<PasteSelection>>
    if {[%W focus] != {}} {
        %W insert [%W focus] insert [.hidden_e get]
        FixBackBox %W [%W focus]
    }
    }
    $c bind editable <Key-Right> {
        %W select clear
        %W icursor [%W focus] [expr [%W index [%W focus] insert]+1]
    }
    $c bind editable <Shift-Right> {
        set farEnd [%W index [%W focus] insert]
        if {[llength [%W select item]]} {
            set newEnd [%W index [%W focus] sel.first]
            if {$newEnd==$farEnd} {
                set newEnd [%W index [%W focus] sel.last]
            }
        } else {
            set newEnd $farEnd
            %W select from [%W focus] $newEnd
        }
        %W select to [%W focus] [expr $newEnd+1]
    }
    $c bind editable <Control-f> \
            [$c bind editable <Key-Right>]
    
    $c bind editable <Key-Left> {
        %W select clear
        %W icursor [%W focus] [expr [%W index [%W focus] insert]-1]
    }
    $c bind editable <Shift-Left> {
        set farEnd [%W index [%W focus] insert]
        if {[llength [%W select item]]} {
            set newEnd [%W index [%W focus] sel.first]
            if {$newEnd==$farEnd} {
                set newEnd [%W index [%W focus] sel.last]
            }
        } else {
            set newEnd $farEnd
            %W select from [%W focus] $newEnd
        }
        %W select to [%W focus] [expr $newEnd-1]
    }
    $c bind editable <Control-b> \
            [$c bind editable <Key-Left>]
    
    $c bind editable <Key-Home> {
        %W icursor [%W focus] 0
    }
    $c bind editable <Control-a> \
            [$c bind editable <Key-Home>]
    
    $c bind editable <Key-End> {
        %W icursor [%W focus] end
    }
    $c bind editable <Control-e> \
            [$c bind editable <Key-End>]
    
    $c bind editable <<Cut>> {CanvasTextCopy %W; CanvasDelete %W
    FixBackBox %W [%W focus]
    }
    $c bind editable <<Copy>> {CanvasTextCopy %W}
    $c bind editable <<Paste>> {
    .hidden_e delete 0 end
    event generate .hidden_e <<Paste>>
    CanvasDelSeln %W
    if {[%W focus] != {}} {
        %W insert [%W focus] insert [.hidden_e get]
        FixBackBox %W [%W focus]
    }
    }
}

proc FixBackBox {c textItem} {
#    set nid [ExtractPrologName $c $textItem]
# above no longer needed due to change below
    if {[scan [$c bbox $textItem] "%g %g %g %g" l t r b]==4} {
#	foreach backBox [$c find withtag $nid] {
# for some reason that is very slow, and we know where they are...
	foreach backBox [list [expr $textItem-2] [expr $textItem-1]] {
	    if {[regexp {/[^ ]*_text/} [$c gettags $backBox] spare]} {
		if {[string equal line [$c type $backBox]]} {
		    $c coords $backBox $r $t $l $t $l $b $r $b $r $t
		} else {
		    $c coords $backBox $l $t $r $b
		}
	    }
	}
#	}
    }
}

# Next three procs are from Welch examples

proc CanvasDelete {c} {
    CanvasDelSeln $c
    if {[$c focus] != {}} {
        $c dchars [$c focus] insert
    }
}

proc CanvasDelSeln {c} {
    if {[llength [$c select item]]} {
        $c dchars [$c select item] sel.first sel.last
    $c select clear
        return 1
    } else {
        return 0
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
    #   set hiding 1
    #   foreach cat $cats {
    #       if {[string match $category $cat]} {
    #       set hiding 0
    #       } elseif {$hiding && $rads($cat)>$level || \
    #           !$hiding && $rads($cat)<$level} {
    #       set rads($cat) $level
    #       MenuSelect $window window \[detail,$cat,$level\]
    #       }
    #   }
    #    }
}

# This patches a bug with error reporting in Tk 8.0. Also puts up a
# feedback window allowing progress reports on long activities.

proc MenuSelect { window button item } {
    if {$window ne "dummy"} {
	SafeEqnBarEdit [winfo parent $window] ;# use latest edit
    }
    switch $button {
	local {
	    DoLocalCmd $window $item
	} code {
	    set node $::window_info($window,top_node)
	    switch $item {
		build_c {
		    set extn .cpp
		} compile_c {
		    set extn [info sharedlibextension]
		} default {
		    set lang [string range $item 4 end]
		}
	    }
	    if {[info exists extn]} {
		set tgt [ChooseFile [GetExecTitle $node]$extn \
			     [tr. "Export code to:"] 1 $node]
	    } else {
		set tgt dummy
	    }
	    OpenProgressBox $window
	    set builtOK [prolog tk_code($node,$item,'$tgt')]
	    CloseProgressBox
	    if {$builtOK && [info exists lang]} {
		LoadProgram $node $lang
	    }
	} default {
	    prolog tk_menu('$window',$button,'$item')
# note this causes a problem with the dll interface as hi-8 chars in the item
# get a representation in Prolog that then screws up when passed back via 
# tcl_eval
	}
    }
}

proc DoLocalCmd {win item} {
    global pushedbutton
    switch $item {
        undo {UnOrReDo $win 0}
        redo {UnOrReDo $win 1}
        print {PrintNow $win}
        rerun {Rerun $win 1}
	tog_grid {ToggleGrid $win}
        zoomin {DoZoom $win 1.414214}
        tosel {DisplayArea $win}
        tofit {DisplayAll $win}
        zoomout {DoZoom $win .707107}
        find {prolog tk_bar_edit_menu('$win'); FindCaption $win}
        findnext {NextCaption $win}
        raiseMRE {RaiseWinMRE $win}
        open_all {OpenAll $win}
	compile_c {ExportCode $win compile_c}
	build_c {ExportCode $win build_c}
        insert {InsertModel $win}
	empty {EmptyWindow $win}
	import_xml {TradeXML $win 0}
	export_xml {TradeXML $win 1}
	export_svg {ExportSVG $win}
	extra_run {ExtraRun $win}
    }
}

proc ExportSVG {win} {
    package require can2svg
    set node $::window_info($win,top_node)

    set tgt [ChooseFile [GetExecTitle $node].svg \
		 [tr. "Export code to:"] 1 $node]
# SVG does not like -ve coords so shift to origin
    foreach {l t r b} [$win cget -scrollregion] break
    set xpos [$win xview]
    set ypos [$win yview]
    $win configure -scrollregion [list 0 0 [expr $r-$l] [expr $b-$t]]
    $win move all [expr -$l] [expr -$t]
    can2svg::canvas2file $win $tgt
    $win move all $l $t
    $win configure -scrollregion [list $l $t $r $b]
    $win yview moveto [lindex $ypos 0]
    $win xview moveto [lindex $xpos 0]
}

# This one added to remove file parameters when clearing model
proc EmptyWindow {c} {
    global window_info paramData

    if {$window_info($c,is_top_level)} {
	set nodeId $window_info($c,top_node)
	array unset paramData /$nodeId/*
    }
    prolog tk_menu('$c',file,new)
}

#
# MacOS X specific procedures for the main window
# Alastair 31 Jan 2005
#

if {[string match "Darwin" $tcl_platform(os)]} {
#
# The Quit command in the application menu ALWAYS calls exit, so we must quit 
# by that route however it is invoked (keyboard shortcut or mouse click) -- 
# although it helpfully calls ::tk::mac::Quit first
#
#  rename exit wishExit
  bind all <Command-q> exit
  proc ::tk::mac::Quit {} {
      global window_info
      set currentDesk _
      catch {set currentDesk \
         $window_info([winfo toplevel [focus]].canvas,top_node)}
# following is after 100 because funny things happen to the event loop while
# actually executing the exit procedure in the Cocoa version, and 'after idle'
# has never quite worked properly on the Mac
      after 100 prolog tk_kill_everything($currentDesk)
#...should not be needed now using ::tk::mac::Quit, but ww1t+a...
      return 0
  }
#
# Enable the Preferences command in the application menu using Carbon extension
#
#  package require tclCarbonHICommand
#  carbon::enableMenuCommand pref 0
  proc ::tk::mac::ShowPreferences {} {
    Pref_Dialog
  }
#
# Commands to raise window to front
#
}

proc AddMainMenu { winid topNode initWidth isTopLevel initDepths} {
    global custom pushedbutton tcl_platform runState iconImages msgs
    
    set c $winid.canvas
    set topm ${winid}top

    if [string match "Darwin" $tcl_platform(os)] {
	set accKey [tr. Cmd]
	set accSym Command
	set fm [menu $topm.apple -tearoff 0]
#	$fm delete 0 7
	$fm add command -label [tr. "About Simile..."] -command "ShowAbout $winid"
	$fm add separator
	$topm add cascade -menu $fm
    } else {
	set accKey [tr. Ctrl]
	set accSym Control
    }
    
    set fm [menu $topm.file -tearoff 0 \
            -postcommand "FillReopen $winid"]
    $topm add cascade -label [tr. File] -menu $fm
    if {$isTopLevel} {
	set newCmd NewTopLevel
    } else {
	set newCmd "MenuSelect $c local empty"
    }
    $fm add command -label [tr. New] -command $newCmd -accelerator "$accKey+N"
    AddAccelerator $winid file New "<$accSym-n>"
#    $fm add command -label [tr. "New top-level"] -command "NewTopLevel"
    $fm add command -label [tr. Open...] -command "MenuSelect $c local open_all" \
            -accelerator "$accKey+O"
    AddAccelerator $winid file Open... "<$accSym-o>"

   $fm add cascade -label [tr. "Reopen"] -menu .openrecent
    if {[string equal .hi $winid]} {
    return
    }
    $fm add command -label [tr. Save] -command "MenuSelect $c file save" \
            -accelerator "$accKey+S"
    AddAccelerator $winid file Save "<$accSym-s>"
    
    $fm add command -label [tr. "Save as..."] \
            -command "MenuSelect $c file save_as"
    AddCmdAndAccel $winid file "Save selection as..." \
	"MenuSelect $c file save_seln_as"
#    $fm add command -label [tr. "Save package"] \
#            -command "MenuSelect $c local save_all"
    
    $fm add separator
    $fm add command -label [tr. "Print..."] \
            -command "PrintNow $c" \
            -accelerator "$accKey+P"
    AddAccelerator $winid file "Print..." "<$accSym-p>"
    #$fm add cascade -label [tr. "Import"] -menu $fm.sub0
    #set fm1 [menu $fm.sub0 -tearoff 0]
#    $fm1 add command -label [tr. "Spreadsheet..."] \
#            -command "MenuSelect $c file import_ss"
    $fm add cascade -label [tr. "Import"] -menu $fm.sub0
    set fm0 [menu $fm.sub0 -tearoff 0]
    # XML im/export via web service is local; replace with file to use built-in
    # convertor
    $fm0 add command -label [tr. "XML Model Description"] \
            -command "MenuSelect $c local import_xml"

    $fm add cascade -label [tr. "Export"] -menu $fm.sub1
    set fm2 [menu $fm.sub1 -tearoff 0]
    $fm2 add command -label [tr. "Model declarations"] \
            -command "MenuSelect $c file export_prolog"
    $fm2 add command -label [tr. "XML Model Description"] \
            -command "MenuSelect $c local export_xml"
    $fm2 add command -label [tr. "SVG Image"] \
            -command "MenuSelect $c local export_svg"
    $fm2 add command -label [tr. "C++ code"] \
            -command "MenuSelect $c code build_c"
    $fm2 add command -label [tr. "Compiled binary"] \
	-command "MenuSelect $c code compile_c"
    $fm2 add command -label [tr. "PostScript graphics"] \
            -command "ExportPostscript $c"
    if {[info exists ::support_sessions]} {
	$fm0 add command -label [tr. "Session record"] \
            -command "MenuSelect $c file run_session"
	$fm2 add command -label [tr. "Session record"] \
            -command "MenuSelect $c file export_session"
    }
    UnderlineUniquely $fm2

    $fm add separator
    
    $fm add command -label [tr. Close] -command "MenuClose $c" \
	-accelerator "[tr. Alt]+x"
    AddAccelerator $winid file Close "<Alt-x>"
    if ![string match "Darwin" $tcl_platform(os)] {
      $fm add command -label [tr. Exit] -command "MenuExit $topNode $c"
    }
    UnderlineUniquely $fm
    
    # edit menu: purpose of postcommand is to enable/disable cut/copy/paste items
    # for what is available, overridden later if it is popup
    set fm [menu $topm.edit -tearoff 0 \
		-postcommand "prolog tk_bar_edit_menu('$c')"]
    $topm add cascade -label [tr. Edit] -menu $topm.edit
    
    $fm add cascade -label [tr. "Create new"] -menu $fm.add
    set ::menuPosns(edit,Create\ new) [$fm index last]
    set em1 [menu $fm.add -tearoff 0]
# add state, event and squirt
    set lookers [list Compartment Variable Flow Influence Submodel]
    if {[info exists ::do_events]} {
	lappend lookers State Event Squirt
    }
    foreach type $lookers {
	AddCmdAndAccel $winid edit.add $type \
	    "MenuSelect $c edit [string tolower $type]"
    }
    AddCmdAndAccel $winid edit.add "Role arrow" "MenuSelect $c edit relation"
    $em1 add cascade -label [tr. "Membership control"] -menu $em1.sub
    set ::menuPosns(edit.add,Membership\ control) [$fm index last]
    AddCmdAndAccel $winid edit.add "Text box" "MenuSelect $c edit text"
    set em2 [menu $em1.sub -tearoff 0]
    foreach type {Creation Immigration Reproduction Loss} {
        $em2 add command -label $type -command \
                "MenuSelect $c edit [string tolower $type]"
    }
    $em2 add command -label [tr. "Existence condition"] -command \
            "MenuSelect $c edit condition"
    $em2 add command -label [tr. "Iteration condition"] -command \
            "MenuSelect $c edit alarm"
    $fm add separator
    
    $fm add command -label [tr. Undo] -command "UnOrReDo $c 0" \
            -state disabled -accelerator "$accKey+Z"
    AddAccelerator $winid edit Undo "<$accSym-z>"
    AddCmdAndAccel $winid edit Redo "UnOrReDo $c 1" disabled
    # no need for this as cut/copy now does it -- keep so we can have non blue
#    if {[string match windows $tcl_platform(platform)]} {
        $fm add separator
        $fm add command -label [tr. "Copy diagram"] -command "CopyCanvasToWindowsClipboard $c 0"
#    }
    $fm add separator
    
    $fm add command -label [tr. Cut] -command "CopyCanvasToWindowsClipboard $c 1; \
            MenuSelect $c edit cut" -accelerator "$accKey+X"
    AddAccelerator $winid edit Cut "<$accSym-x>"
    $fm add command -label [tr. Copy] -command "CopyCanvasToWindowsClipboard $c 1; \
            MenuSelect $c edit copy" -accelerator "$accKey+C"
    AddAccelerator $winid edit Copy "<$accSym-c>"
    $fm add command -label [tr. Paste] -command "MenuSelect $c edit paste" \
            -accelerator "$accKey+V"
    AddAccelerator $winid edit Paste "<$accSym-v>"
    unset ::accelerator(edit,Paste) ;# do not disable it later
    foreach cmd {{Reroute links} {Align to grid}} key {reroute snap} {
	AddCmdAndAccel $winid edit $cmd "MenuSelect $c edit $key"
    }
    $fm add command -label [tr. Delete] -command "MenuSelect $c edit delete" \
	-accelerator [tr. Del]
    AddAccelerator $winid edit Delete "<<Del>>"
    $fm add separator
    
    $fm add command -label [tr. "Select all"] -command "MenuSelect $c edit selall" \
            -accelerator "$accKey+A"
    AddAccelerator $winid edit "Select all" "<$accSym-a>"
    $fm add command -label [tr. "Unselect all"] \
            -command "MenuSelect $c edit unselall" -accelerator "$accKey+U"
    AddAccelerator $winid edit "Unselect all" "<$accSym-u>"
    $fm add command -label [tr. "Invert selection"] \
            -command "MenuSelect $c edit invsel" -accelerator "$accKey+!"
    AddAccelerator $winid edit "Invert selection" "<$accSym-exclam>"
    
    AddFindMenu $winid $c $fm
    $fm add separator
    AddCmdAndAccel $winid edit "Properties..." "MenuSelect $c edit properties"
    if ![string match "Darwin" $tcl_platform(os)] {
      $fm add command -label [tr. Preferences...] -command Pref_Dialog
    }
    UnderlineUniquely $fm
    
    set fm [menu $topm.view -tearoff 0]
    $topm add cascade -label [tr. View] -menu $topm.view
    $fm add check -label [tr. Toolbar] -variable custom(shownavbar,$winid) \
            -command "toggleBar $winid"
    $fm add check -command "toggleBar $winid" \
            -label [tr. "Component bar"] -variable custom(showtoolbar,$winid)
    $fm add check -command "toggleBar $winid" \
            -label [tr. "Equation bar"] -variable custom(showeqnbar,$winid)
    $fm add check -command "UpdateGrid $c" \
            -label [tr. "Grids"] -variable custom(showgrids,$c)
    
    $fm add separator
# zoom submenu
    set fm2 [menu $fm.zoom -tearoff 0]
    $fm add cascade -label [tr. Zoom] -menu $fm2
    $fm2 add command -label [tr. "In lots"] -command "DoZoom \
            $c 1.953125" -accelerator "$accKey+*"
    AddAccelerator $winid view.zoom "In lots" "<$accSym-KP_Multiply>"
    AddAccelerator $winid view.zoom "In lots" "<$accSym-asterisk>"
    $fm2 add command -label [tr. "In a bit"] -command "DoZoom \
            $c 1.25" -accelerator "$accKey++"
    AddAccelerator $winid view.zoom "In a bit" "<$accSym-KP_Add>"
    AddAccelerator $winid view.zoom "In a bit" "<$accSym-plus>"
    $fm2 add command -label [tr. "To selection"] -command "DisplayArea $c" \
	-accelerator "$accKey+@"
    AddAccelerator $winid view.zoom "To selection" "<$accSym-at>"
    $fm2 add command -label [tr. "To fit"] -command "DisplayAll $c" \
	-accelerator "$accKey+t"
    AddAccelerator $winid view.zoom "To fit" "<$accSym-t>"
    $fm2 add command -label [tr. "Out a bit"] -command "DoZoom \
            $c 0.8" -accelerator "$accKey+-"
    AddAccelerator $winid view.zoom "Out a bit" "<$accSym-KP_Subtract>"
    AddAccelerator $winid view.zoom "Out a bit" "<$accSym-minus>"
    $fm2 add command -label [tr. "Out lots"] -command "DoZoom \
            $c 0.512" -accelerator "$accKey+/"
    AddAccelerator $winid view.zoom "Out lots" "<$accSym-KP_Divide>"
    AddAccelerator $winid view.zoom "Out lots" "<$accSym-slash>"
    UnderlineUniquely $fm2

    $fm add cascade -label [tr. "Show detail"] -menu $fm.sub3
    set fm3 [menu $fm.sub3 -tearoff 0]
    AddDetailMenu $c $fm3 $initDepths
    UnderlineUniquely $fm3

    menu $fm.sub4 -tearoff 0
    $fm add cascade -label [tr. "Customize"] -menu $fm.sub4
    foreach {category loc_label} \
	[list compartment [tr. "Compartments..."] \
	     variable [tr. "Variables..."] \
	     flow [tr. "Flows, bowties and clouds..."] \
	     influence [tr. "Influences..."] \
	     submodel [tr. "Submodels..."] \
	     relation [tr. "Relations..."] \
	     condition [tr. "Channels..."] \
	     text [tr. "Text boxes..."] \
	     ghost_link [tr. "Ghost links..."] \
	     select [tr. "All components..."]] {
    $fm.sub4 add command -command "Customize $winid $category" \
        -label $loc_label
    }
    UnderlineUniquely $fm.sub4

    menu $fm.sub5 -tearoff 0
    $fm add cascade -label [tr. "Highlight back"] -menu $fm.sub5

    menu $fm.sub6 -tearoff 0
    $fm add cascade -label [tr. "Highlight forward"] -menu $fm.sub6

    set levelCapts [list "Bases only" "One level" "Two levels" "Three levels"]
    for {set levels 0} {$levels<4} {incr levels} {
	$fm.sub5 add radio -command "SetHalo $c back $levels" \
	    -label [tr. [lindex $levelCapts $levels]] \
	    -variable rads(back) -value $levels
	$fm.sub6 add radio -command "SetHalo $c fwd $levels" \
	    -label [tr. [lindex $levelCapts $levels]] \
	    -variable rads(fwd) -value $levels
    }
    $fm.sub6 entryconfigure 0 -label [tr. "Ghosts only"]
    UnderlineUniquely $fm.sub5
    UnderlineUniquely $fm.sub6

    if {$isTopLevel} {
#	$fm.sub5 invoke "Bases only"
#	$fm.sub6 invoke "Ghosts only"
# didnt work, do in prolog
	set execEntryState normal
    } else {
        set execEntryState disabled
    }
    UnderlineUniquely $fm

    if {[info exists ::support_sessions]} {
	$fm add separator
	set fmsesp [menu $fm.sesp -tearoff 0]
	$fm add cascade -label [tr. {In replay}] -menu $fmsesp
	$fmsesp add command -label [tr. Pause] \
	    -command "prolog tk_append_to_log($topNode,pause)"
    }

    set fm [menu $topm.model -tearoff 0 -postcommand "AbleComp $winid"]
    $topm add cascade -label [tr. Model] -menu $topm.model
    $fm add command -label [tr. "Run"] -state $execEntryState \
                    -command "MenuSelect $c code run_c" \
                    -accelerator "$accKey+R"
    AddAccelerator $winid model "Run" "<$accSym-r>"
    $fm add command -label [tr. "Debug"] -state $execEntryState \
                    -command "MenuSelect $c code run_tcl" \
                    -accelerator "$accKey+D"
    AddAccelerator $winid model "Debug" "<$accSym-d>"
# Not as low-hanging a fruit as I thought!
#    $fm add command -label [tr. "Extra run instance"] -state $execEntryState \
#                    -command "MenuSelect $c local extra_run" \
#                    -accelerator "$accKey+E"
#    AddAccelerator $winid model "Extra run instance" "<$accSym-e>"
#Model now aborted by closing run control
#    $fm add command -label [tr. "Abort execution"] -state $execEntryState \
#                    -command "FinishExec $c"
    $fm add separator
    $fm add command -label [tr. "List equations"] \
            -command "MenuSelect $c file list_eqns" \
            -accelerator "$accKey+L"
    AddAccelerator $winid model "List equations" "<$accSym-l>"
    $fm add separator
    $fm add cascade -label [tr. "Add new"] -menu $fm.sub1
    set fm1 [menu $fm.sub1 -tearoff 0]
    
    # The radiobuttons use MIpushedbutton as their variable because
    # the command procedure has to know what the old pushedbutton was
    # so it can unpress it, so they cannot use that
    
# add state event squirt separator3 before creation for v5
    set lookers [list compartment variable flow influence separator1 \
		      submodel relation separator2 \
		      creation immigration reproduction loss condition alarm \
		     separator4 text]
    if {[info exists ::do_events]} {
	set lookers [linsert $lookers 8 state event squirt separator3]
    }
    foreach itemType $lookers {
	if {[string match separator* $itemType]} continue
	$fm1 add radiobutton -label [tr. [string totitle $itemType]] \
	    -command "ItemSelect $itemType" \
            -variable MIpushedbutton -value $itemType
# TRANSLATOR: Strings are any of those following "set lookers [list..." above,
# or "event", "squirt" or "state" -- but always starting with uppercase letter
    }
    UnderlineUniquely $fm1

    $fm add cascade -label [tr. Flip] -menu $fm.sub2
    set fm2 [menu $fm.sub2 -tearoff 0]
    $fm2 add command -label [tr. Horizontal] \
            -command "MenuSelect $c edit flip_h"
    $fm2 add command -label [tr. Vertical] \
            -command "MenuSelect $c edit flip_v"
    UnderlineUniquely $fm2
    
    $fm add command -label [tr. "Insert..."] \
            -command "MenuSelect $c local insert"
    $fm add separator
    $fm add command -label [tr. "Save interface"] \
            -command "MenuSelect $c file save_interface"
    $fm add command -label [tr. "Load interface"] \
            -command "MenuSelect $c edit set_interface"
    UnderlineUniquely $fm
    
    set fm [menu $topm.tools -tearoff 0]
    $topm add cascade -label [tr. Tools] -menu $topm.tools
    $fm add radiobutton -label [tr. "Label/move elements"] \
            -command "ModeSelect select" -variable MIpushedbutton -value select
    #    $fm add radiobutton -label [tr. "Move elements"] -command "ModeSelect move" \
    -variable MIpushedbutton -value move
    #    $fm add radiobutton -label [tr. "Delete elements"] -command "ModeSelect delete" \
    -variable MIpushedbutton -value delete
    #    $fm add radiobutton -label [tr. "Duplicate submodels"] -command "ModeSelect copy" \
    -variable MIpushedbutton -value copy
    $fm add radiobutton -label [tr. "Move canvas"]  -command "ModeSelect move" \
            -variable MIpushedbutton -value move
    $fm add radiobutton -label [tr. "Create ghost nodes"]  -command "ModeSelect ghost" \
            -variable MIpushedbutton -value ghost
    $fm add radiobutton -label [tr. "Inspect elements"]  -command "ModeSelect snap" \
            -variable MIpushedbutton -value snap -state disabled
    set ::menuPosns(tools,Inspect\ elements) [$fm index last]
    UnderlineUniquely $fm


#    if {[HaveValues $topNode] && \
#	    ![PrefValue custom(helperManager) helperManager]} {
#        $topm add  cascade -label [tr. "I/O tools"] -menu $topm.helpers
#        $fm entryconfigure "Inspect elements" -state normal
#    }
#
# Help menu must be called help in Carbon or else we get two 'Help' pulldowns, but not in 
# Cocoa or else we get a spurious 'Simile Help' entry
    $topm add cascade -label [tr. Window] -menu .windowchoice
    if {$::inCocoa} {
	set helpMenuW myhelp
    } else {
	set helpMenuW help
    }
        set fm [menu $topm.$helpMenuW -tearoff 0]
        $topm add cascade -label [tr. Help] -menu $fm
        $fm add command -label [tr. Contents] -command "ContextSensitiveHelp $winid index.htm" \
                -accelerator "F1"
        AddAccelerator $winid $helpMenuW Contents "<F1>"
#        $fm add command -label Huh? -command {ShowMess debug info $errorInfo ok}
    if ![string match aqua [tk windowingsystem]] {
        $fm add command -label [tr. About...] -command [list ShowAbout $winid]
    } else {
	#$topm.help itemconfig 0 -accelerator "F1"
    }
    UnderlineUniquely $topm

    set nb [::ttk::frame $winid.toolSlot.navbar -class Toolbar]
    pack [ttk::separator $nb.afterSeparator -orient horizontal] \
	-fill x -side bottom
    if {[PrefValue custom(bigButtons) bigButtons]} {
        set buttonImages ../Images/Toolbar/Large
    } else {
        set buttonImages ../Images/Toolbar
    }
    foreach navCmd {{new {local empty}} {open {local open_all}} \
                {save {file save}}  {print {local print}} {separator1}\
                {undo {local undo}} {redo {local redo}} {separator2}\
                {flip_h {edit flip_h}} {flip_v {edit flip_v}} {separator3}\
                {zoomin {local zoomin}} {zoomsel {local tosel}} \
                {zoomfit {local tofit}} {zoomout {local zoomout}} \
                {separator5}   } {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [ttk::separator $nb.$handle -orient vertical] \
		-fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [::ttk::button $nb.$handle -image $testImg -style Toolbutton \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
	    FixDisabledImgBug $nb.$handle
            BindPopup $nb.$handle $handle
        }
    }
    set testImg [image create photo -file $buttonImages/tog_grid.gif]
    pack [::ttk::checkbutton $nb.tog_grid -image $testImg -style Toolbutton \
           -command [concat "MenuSelect $c" {local tog_grid}]] \
           -side left -padx 2 -pady 2
    if {[PrefValue custom(initGrid) initGrid]} {
      $nb.tog_grid state selected
    }
    BindPopup $nb.tog_grid tog_grid
    
    foreach navCmd {{rerun {local rerun}} {separator6} \
                {find {local find}} {findmore {local findnext}} {separator7}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [ttk::separator $nb.$handle -orient vertical] \
		-fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [::ttk::button $nb.$handle -image $testImg -style Toolbutton \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
	    FixDisabledImgBug $nb.$handle
            BindPopup $nb.$handle $handle
        }
    }
    $nb.findmore configure -state disabled
    
    # button to raise single-window run env (ready for more tools in this section)
    foreach navCmd {{runenv {local raiseMRE}}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [ttk::separator $nb.$handle -orient vertical] \
		-fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [::ttk::button $nb.$handle -image $testImg -style Toolbutton \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
	    FixDisabledImgBug $nb.$handle
            BindPopup $nb.$handle $handle
        }
    }
    $nb.runenv configure -state disabled
    
    set tb [::ttk::frame $winid.toolSlot.toolbar -class Toolbar]
    pack [ttk::separator $tb.afterSeparator -orient horizontal] \
	-fill x -side bottom
    foreach mode $lookers {
        if {[string match separator* $mode]} {
            
            pack [ttk::separator $tb.$mode -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${mode}.gif]
            set bt [::ttk::radiobutton $tb.$mode -command "ItemSelect $mode"  \
                -variable MIpushedbutton -value $mode -image $testImg -style Toolbutton]
            pack $bt -side left -padx 2 -pady 2
            BindPopup $bt add_$mode
            bind $bt <ButtonRelease-1> "DragComponentIn $c $bt %X %Y yes"
        }
    }
    pack [ttk::separator $tb.spacer -orient vertical] -fill y -side left
    
    foreach mode {select move ghost snap} {
        set testImg [image create photo -file $buttonImages/${mode}.gif]
        set bt [::ttk::button $tb.$mode -image $testImg -command "ModeSelect $mode" -style Toolbutton]
	pack $bt -side left -padx 2 -pady 2
	FixDisabledImgBug $bt
        BindPopup $bt $mode
	bind $bt <ButtonRelease-1> "DragComponentIn $c $bt %X %Y no"
    }
    if {![HaveValues $topNode]} {
        $tb.snap configure -state disabled
    }
    
    $tb.$pushedbutton state selected
    #$tb.$pushedbutton configure -state active
    
    
    ### Formula bar section
    ### Robert Muetzelfeldt
    ### Started 4/3/02
    set eb [::ttk::frame $winid.toolSlot.eqnbar -class Toolbar]
    pack [ttk::separator $eb.afterSeparator -orient horizontal] \
	-fill x -side bottom
    pack [frame $eb.gap1 -class Toolbar -height 2] -fill x -side bottom
    
    ::ttk::label $eb.label -anchor e
    pack $eb.label -side left
    
    global equation msgs
    # create but only pack while state being edited
    ::ttk::combobox $eb.events -width 8 -font EquationFont -state readonly
    bind $eb.events <<ComboboxSelected>> [list SwitchEvent $winid $eb]
    ::ttk::label $eb.minlabel -anchor w -text below:
    ::ttk::entry $eb.min -width 6 -font EquationFont \
	-textvariable equationbar(min_entry)
    ::ttk::label $eb.maxlabel -anchor w -text above:
    ::ttk::entry $eb.max -width 6 -font EquationFont \
     	-textvariable equationbar(max_entry)

#    ComboBox $eb.equation -editable 1 -state disabled -width 40
    ::ttk::combobox $eb.equation -state disabled -width 32 -font EquationFont \
	-values $equation(prevs)
    pack $eb.equation -side left -expand 1 -fill x
    bind $eb.equation <Return> [list EnterEqn $winid $eb.equation]
    bind $eb.equation <FocusIn> "EmbraceEqn $winid"
    bind $eb.equation <FocusOut> "AbandonEqn $winid"
    bind $eb.min <FocusIn> "EmbraceEqn $winid"
    bind $eb.min <FocusOut> "AbandonEqn $winid"
    bind $eb.max <FocusIn> "EmbraceEqn $winid"
    bind $eb.max <FocusOut> "AbandonEqn $winid"
    bind $eb.equation <Button-1> "after 10 FlashOnClick 0 %W"

    frame $eb.padding1 -width 3
    pack $eb.padding1 -side left
    switch [tk windowingsystem] {
        aqua {set buttonStyle ""}
        win32 {set buttonStyle Toolbutton}
        x11 {set buttonStyle Toolbutton}
    }
    pack [::ttk::button $eb.tick -state disabled -image $iconImages(tick) \
            -style $buttonStyle \
            -command [list accept_equation $winid $eb.equation]] -side left
    FixDisabledImgBug $eb.tick
    
    pack [::ttk::button $eb.cross -state disabled -image $iconImages(cross) \
            -style $buttonStyle \
            -command [list restore_equation $winid $eb]] -side left
    FixDisabledImgBug $eb.cross
    
    frame $eb.padding2 -width 3
    pack $eb.padding2 -side left
    
    set image [image create photo -file "../Images/Eqnbar/inputs.gif"]
    ::ttk::menubutton $eb.inputs -state disabled -menu $eb.inputs.menu -image $image
    FixDisabledImgBug $eb.inputs
    pack $eb.inputs -side left
    set m [menu $eb.inputs.menu -tearoff 0]
# now done when bar filled            -postcommand [list AddInputs $winid $eb]
    #    $m add command -label [tr. biomass] -command bell
    #    $m add command -label [tr. k] -command bell
    #BindPopup $m foobar
    
    ::ttk::menubutton $eb.function -state disabled -menu $eb.function.menu -image $iconImages(function)
    pack $eb.function -side left
    FixDisabledImgBug $eb.function
    set m [menu $eb.function.menu -tearoff 0]
    foreach funk $equation(fnDefs) {
	set box $m
	#puts "Adding $funk to $box"
	foreach level [split [join [lindex $funk 0] /] /] {
	    set lname $box.[string tolower [join $level _]]
	    set capt [tr. $level]
# TRANSLATOR: String $level may be "Built-in", "Macros" or
# the name of any directory under Functions
	    if {[catch {$box index $capt}]} {
		menu $lname -tearoff 0
		$box add cascade -menu $lname -label $capt
		set key [string tolower [join $level _]]
		if {[info exists msgs($key)]} {
		    lappend popLists($box) $msgs($key)
		} else {
		    lappend popLists($box) $level
		}
	    }
	    set box $lname
	}
	set component [lindex $funk 2]
	set wParen $component\(\)
	if {[catch {$box index $wParen}]} {
	    $box add command -label $wParen \
		-command [list InsertFunction $eb.equation $component]
	    catch {set component $msgs($component)} ;# may not exist
	    lappend popLists($box) $component
	    lappend fnList $wParen
	}
    }
    set lname [menu $m.enumtypes -tearoff 0]
    $m add cascade -menu $lname -label [tr. "Enum. type constants"]
    lappend popLists($m) $msgs(et_top_level)
    foreach {lname pops} [array get popLists] {
	MenuBindPopup $lname $pops
    }

    $eb.equation configure -validatecommand \
	[list autocomplete %W %d %i %P %S [lsort -dictionary $fnList]]
    bind $eb.equation <Key-Up> [list ScrollCompletion %W -1]
# do not bind to down arrow cos that activates drop-down list
#    bind $eb.equation <Key-Down> [list ScrollCompletion %W 1]
    
    #    set useFunctions [lrange $equation(fnDefs) 0 9]
    #    foreach defn $useFunctions {
    #        set cmd [lindex $defn 1]
    #        $m add command -label $cmd\(\) \
    -command [list InsertFunction $eb.equation $cmd]
    #    }
    #    $m add command -label [tr. "All functions..."] -command bell
    
    #   set image [image create photo -file "../Images/eqnbar/props.gif"]
    #   pack [button $eb.properties -state disabled -image $image -borderwidth 1] \
    #           -side left
    
    ### End of formula bar section
    
    update idletasks ;# to allow reqwidth to be calculated
    #set navWidth [winfo reqwidth $tb] ;# tool bar is widest
    #ShowMess debug info "Toolbar has $initWidth, needs $navWidth" ok
    set custom(showtoolbar,$winid) [expr \
            [PrefValue custom(initToolbar) initToolbar]]
    set custom(shownavbar,$winid) [expr  \
            [PrefValue custom(initNavbar) initNavbar]]
    set custom(showeqnbar,$winid) [expr \
            [PrefValue custom(initEqnbar) initEqnbar]]
    
    pack [ttk::separator $winid.toolSlot.topseparator -orient horizontal] \
	-fill x -side top
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

proc autocomplete {win action pt value change valuelist} {
    global equationbar
#    puts [lrange [info level 0] 0 end-1]
    after idle [list $win configure -validate key]
    if {[string length $value]==[$win index end]+1} {
# only try to match current group of alphas
	set final [$win index insert]
	# was [string wordend $value $pt]
	set close [expr {$final+1}]
# new bit: try to flash matching open bracket
	set testChar [string index $value $final]
	FlashMatchingBracket 0 $win $final $testChar
	if {[string is wordchar -strict $testChar]} {
	    set origin [string wordstart $value $pt]
	    # add any leading \['s or \{'s to search string
	    set wordMap [string map [list \[ _ \{ _] $value]
	    set trigStart [string wordstart $wordMap $pt]
	    set trigger [string range $value $trigStart $final]
	    # now all leading brackets must be escaped, and leading ['s made
	    # optional because they could be starting an itemized array
	    set trigger [string map [list \[ \\\[? \{ \\\{] $trigger]

	    set valuelist [concat $equationbar(params) $valuelist]
# right now for some innovation. Up and down arrows will scroll through 
# possible matches so we need to get all...only include completion if it adds
# at least one alphanumeric character
#	    set key ^$trigger\[\[:alnum:\]\]
# actually its awkward having a completion appear if you have entered the whole
# item, so drop this restriction (on the restriction? comment makes no sense. 
# perhaps its about case where the whole item is one possibility -- if it is 
# allowed as a completion, longer item will not show. But this is confusing and
# contrary to other apps behaviour, so...)
	    set key ^$trigger.
# currently allow any completion that adds anything -- have to delete if you
# want substring
	    set matches [lsearch -all -inline -regexp $valuelist $key]
	    if {[llength $matches]} {
		foreach match $matches {
		    lappend tails [string range [string trimleft $match \[\{] \
				      [expr {$close-$origin}] end]
		}
		set pop [string trimleft [lindex $matches 0] \[\{]
#		$win delete $origin $final; $win insert $origin $pop
# ignore previous contents, we may have pasted lots of text
		$win delete 0 end
		$win insert 0 [string replace $value $origin $final $pop]
		set selend [expr {$origin+[string length $pop]}]
		$win selection range $close $selend
		$win icursor $selend
		focus $win ;# prevent problems with state trigger pulldown
	    }
	}
    }
    if {[info exists tails]} {
	set equationbar(tails) $tails
	set equationbar(currentMatch) 0
    } else {
	array unset equationbar tails ;# former roll options no longer valid
    }
    return 1
}

proc ScrollCompletion {win hop} {
    global equationbar

#    if {[$win selection present] && [info exists equationbar(tails)]}
# selection not present if whole string matches, drop condition
    if {[info exists equationbar(tails)]} {
	$win configure -validate none
	if {[$win select present]} {
	    $win delete sel.first sel.last
	}
	set turn [llength $equationbar(tails)]
	set equationbar(currentMatch) \
	    [expr {int(fmod($equationbar(currentMatch)+$turn+$hop,$turn))}]
	set newTail [lindex $equationbar(tails) $equationbar(currentMatch)]
	set origin [$win index insert]
	$win insert insert $newTail
	$win select range $origin insert
	$win configure -validate key
    }
}

proc EnterEqn {winid eb} {
    global equationbar

# If there is an autocomplete active, 'enter' just accepts this
    if {[info exists equationbar(tails)]} {
	$eb selection clear
	array unset equationbar tails
	return
    }
    focus [winfo parent $eb].tick
# remove from eqnbar without save dialogue
    accept_equation $winid $eb
}

proc AddFindMenu {winid canvas menu} {
    global tcl_platform
    if [string match "Darwin" $tcl_platform(os)] {
	set accKey [tr. Cmd]
	set accSym Command
    } else {
	set accKey [tr. Ctrl]
	set accSym Control
    }
    $menu add separator
    $menu add command -label [tr. Find...] -command "FindCaption $canvas" \
            -accelerator "$accKey+F"
    AddAccelerator $winid edit "Find..." "<$accSym-f>"
    $menu add command -label [tr. "Find next"] -command "NextCaption $canvas" \
            -accelerator "F3" -state disabled
    AddAccelerator $winid edit "Find next" "<F3>"
}

proc ReconstituteMenu {newMenu mList tgtNode} {
    menu $newMenu -tearoff 0
    set subs 0
    foreach entrySpec $mList {
    set type [lindex $entrySpec 0]
    $newMenu add $type -label [lindex $entrySpec 1]
    switch $type {
        command {
        $newMenu entryconfigure last -command [lindex $entrySpec 2]
        } cascade {
        set subMenu $newMenu.sub$subs
        incr subs
        ReconstituteMenu $subMenu [lindex $entrySpec 2] $tgtNode
        $newMenu entryconfigure last -menu $subMenu
        }
    }
    }
}

proc ListWindows {fm} {
    global window_info

# now window whose menu was clicked has focus even in Windows...but somehow
# Windows can invoke this from right click on toolbar button even with welcome
# dialogue displayed, so verify...
#    set top [lindex [wm stackorder .] end]
#    if {[wm overrideredirect $top]} { ;# menu is in use
#	return
#    }
    if {[string length [focus]]} {
	set window_info(uppermost) [winfo toplevel [focus]]
    }
    $fm delete 0 end
    foreach win [winfo children .] {
	if {[string equal Toplevel [winfo class $win]]} {
	    $fm insert 0 radiobutton -variable window_info(uppermost) \
		-value $win -label [wm title $win] \
		-command [list MyRaise $win]
	}
    }
#    update
}

proc RaiseAny {node win} {
    if {[string equal editor $node]} {
	raise $win
    } else {
	after idle MyRaise $win
    }
}

#proc PostRealHelperMenu {winId} {
#    global window_info runState
#    
#    set dotlessWinName [string range $winId 1 end]
#    set bloodyClone $winId.\#${dotlessWinName}top.\#$dotlessWinName\#helpers
#    set tgtx [winfo rootx $bloodyClone]
#    set tgty [winfo rooty $bloodyClone]
#    event generate $bloodyClone <ButtonRelease-1>
#    
#    set node $window_info($winId.canvas,top_node)
#    do_for_node $node .helpers post $tgtx $tgty
#    do_for_node $node focus .helpers
#}

# below used to find out what the bloody clone is called when writing above
#proc allwins {win} {
#    puts $win
#    puts [winfo geometry $win]
#    foreach n [winfo children $win] {
#        allwins $n
#    }
#}

# # character in colour spec is escaped purely for the benefit of the Emacs
# tcl mode parser

proc DragComponentIn {winId button x y addOne} {
    global looks equationbar
    set whatToAdd [winfo name $button]
    #    set top [winfo parent $winId]
    #puts $x,$y
    #    foreach level [list $top $winId] {
    #   scan [winfo geometry $level] %dx%d+%d+%d w h ox oy
    #puts $level,$ox,$oy
    #   incr x [expr -$ox]
    #   incr y [expr -$oy]
    #    }
    set x [expr $x-[winfo rootx $winId]]
    set y [expr $y-[winfo rooty $winId]]
    
    if {$x<0 || $x>[winfo width $winId] || \
	    $y<-[winfo y $winId] || $y>[winfo height $winId]} {
        # not in canvas or parent, ignore
        return
    }
    if {$y<0} {
        # in parent but not in canvas, select clicked button
	$button invoke
        return
    }
    if {!$addOne} return

    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set xco [Unscale $winId $canx]
    set yco [Unscale $winId $cany]
#    if {$looks(gridPitch)} {
#   set xco [expr $looks(gridPitch)*round($xco/$looks(gridPitch))]
#   set yco [expr $looks(gridPitch)*round($yco/$looks(gridPitch))]
#    }
    focus $winId
    set target [GetClickedObj $winId $canx $cany 6]

    # Now simulate what Prolog would get from an add component menu selection
    if {$target} {
        set node [ExtractPrologName $winId $target]
        prolog [list tk_click_obj('$winId', click , $xco , $yco , $node , 2)]
    } else {
        # a background drop
        prolog [list tk_click('$winId', $xco , $yco , 2)]
    }
    prolog tk_bar_edit_menu('$winId')
    prolog [list tk_unclick( $xco , $yco )]
    MenuSelect $winId edit $whatToAdd
    if {[lsearch {flow influence relation} $whatToAdd]>-1} {
    set equationbar(special) 1
    }
}

proc ExtractPrologName { winId target } {
    set tagList [$winId gettags $target]
    set objNamePosn [lsearch -regexp $tagList {((node)|(arc)[0-9]*)|(sample)}]
    return [lindex $tagList $objNamePosn]
}

# GetClickedObj: returns the object at the target position. We want to return
# the closest object within a certain number of pixels. Since there is always
# something in the background we will get that if our search radius is too
# small, so we gradually increase it until we find a non-background thing or
# we reach the edge of our search radius.

proc GetClickedObj { winId canx cany range} {
    for {set halo 1} {$halo < $range} {incr halo 2} {
        set tgt1 [set target [$winId find closest $canx $cany $halo]]
	set looped 0
	while {!$looped} {
	    if {![string match "*/background/*" [$winId gettags $target]] && \
		    [Visible $winId $target]} {
		return $target
	    }
	    set target [$winId find closest $canx $cany $halo $target]
	    set looped [expr {$target==$tgt1}]
        }
    }
    return 0
}

proc GetClickCapt { winId canx cany node} {
    global window_info
    set result $window_info($winId,topCapt)
    set tgts [$winId find overlapping $canx $cany $canx $cany]
    set lastNod none
    foreach tgt $tgts {
    if {[string match "*/background/*" [$winId gettags $tgt]] && \
        ![string match "*/base/*" [$winId gettags $tgt]]} {
        set thisNod [ExtractPrologName $winId $tgt]
        if {![string equal $thisNod $lastNod]} {
        set lastNod $thisNod
        set newText [GetText $winId $thisNod]
        append result /$newText
        if {[string equal $node $thisNod]} {
            return $result
        }
        }
    }
    }
    append result /[GetText $winId $node]
    return $result
}    

proc AbleComp {winid} {
    global custom
    # Not done now because compiler choice not given in Unix, and we need to load
    # pre-built executables even if we have no compiler ourselves

    # (also it should use UpdateAbility)
    
    #    if {[string match $winid $custom(first_up)]} {
    #   if {[string match None [PrefValue custom(compChoice) compChoice]]} {
    #       set cCompOption disabled
    #   } else {
    #       set cCompOption normal
    #   }
    #   $topm.model entryconfigure "Build In C++" -state $cCompOption
    #    }
}

proc EmbraceEqn {winId} {
    global equationbar
    if {[info exists equationbar($winId,node)]} {
    if {[llength $equationbar($winId,node)]} {
        prolog tk_embrace('$winId.canvas',$equationbar($winId,node))
    }
    }
}

proc AbandonEqn {winId} {
# Only query save if new focus is a 'rival', otherwise no bother as the eqnbar
# will get it back anyway
    set newFocus [focus]
    set eb $winId.toolSlot.eqnbar
    if {[string length $newFocus] && \
	    [string first $eb $newFocus]} { ;# i.e. not prefix
	SafeEqnBarEdit $winId
	prolog tk_abandon_eqn
    }
}


if {![info exists interface]} {
    set interface dll
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

proc ToggleGrid {winId} {
    global custom

    set custom(showgrids,$winId) [expr !$custom(showgrids,$winId)]
    UpdateGrid $winId
}

proc UpdateGrid {winId} {
    global custom window_info

    set toolBar $window_info($winId,parent).toolSlot.navbar
    if {$custom(showgrids,$winId)} {
        $toolBar.tog_grid state selected
    } else {
        $toolBar.tog_grid state !selected
    }
    
    if {$custom(showgrids,$winId)} {
	$winId itemconfigure /grid/ -state normal
    } else {
	$winId itemconfigure /grid/ -state hidden
    }
}

proc SetHalo {winId way level} {
    MenuSelect $winId window halo($way,$level)
}

set rads(back) 0
set rads(fwd) 0

proc AddDetailMenu {winId fm3 initVals} {
    
    global rads
    set posn 0
    foreach {cat loc_label} \
        [list ghost_link [tr. "Ghost links..."] \
	     influence [tr. "Influences..."] \
	     variable [tr. "Variables..."] \
	     flow [tr. "Flows and clouds..."] \
	     compartment [tr. "Compartments, states..."] \
	     submodel [tr. "Submodels and relations..."] \
	     caption [tr. "Captions..."] \
	     text [tr. "Text boxes..."]] {
	     
        set rads($winId,$cat) [lindex $initVals $posn]
        incr posn
        $fm3 add cascade -label $loc_label \
                -menu $fm3.$cat
        set lastmenu [menu $fm3.$cat -tearoff 0]
        $lastmenu add radio -label [tr. "None"] -variable rads($winId,$cat) \
                -value 0 -command "WindowDetail $winId $cat 0 1"
        $lastmenu add radio -label [tr. "One level"] \
	    -variable rads($winId,$cat) \
	    -value 1 -command "WindowDetail $winId $cat 1 1"
	set tr_plural_levels [tr. {%1$s levels}]
        foreach depth {2 3 4 5 6} {
            $lastmenu add radio -label [format $tr_plural_levels $depth] \
                    -variable rads($winId,$cat) -value $depth \
                    -command "WindowDetail $winId $cat $depth 1"
            

        }
        $lastmenu add radio -label [tr. "All"] -variable rads($winId,$cat) \
                -value 32 -command "WindowDetail $winId $cat 32 1"
    }
    $fm3 add cascade -label [tr. "Influence sections..."] -menu $fm3.sections
    set lastmenu [menu $fm3.sections -tearoff 0]
    set rads($winId,sections) [lindex $initVals $posn]
    foreach sectType {Local Terminal All} {
        $lastmenu add radio -label [tr. $sectType] \
                -variable rads($winId,sections) -value show$sectType \
                -command "WindowDetail $winId sections show$sectType 1"
# TRANSLATOR: $sectType may be Local, Terminal or All
    }
}

proc MenuClose {winId} {
#    global window_info
#    foreach tlItem [array names window_info *,is_top_level] {
#   if {$window_info($tlItem) && [string last $winId $tlItem]} {
#       set notLastTl 1
#   }
#    }
#    if {[info exists notLastTl]} {
    byebye $winId
#    } else {
#   MenuSelect $winId file new
#    }
# if it is tl we should kill its submodel windows too
}

proc GetTransients {win} {
    set trannies {}
    foreach subWin [winfo children .] {
	if {[string equal $subWin [winfo toplevel $subWin]]} {
	    if {[string equal $win [wm transient $subWin]]} {
		eval {lappend trannies} [GetTransients $subWin] {$subWin}
	    }
	} 
    }
    return $trannies
}

proc KillTransients {winId} {
    foreach tranny [GetTransients [winfo toplevel $winId]] {
	set customKiller [wm protocol $tranny WM_DELETE_WINDOW]
	if {[llength $customKiller]} {
	    uplevel #0 $customKiller
	} else {
	    destroy $tranny
	}
	update
    }
}

proc MenuExit {topNode winId} {
    SafeEqnBarEdit [winfo parent $winId]
    prolog tk_kill_everything($topNode)
}

proc byebye {winId} {
    KillTransients $winId
    SafeEqnBarEdit [winfo parent $winId]
    set runOnEmpty [string equal aqua [tk windowingsystem]]
    prolog [list tk_off_window( '$winId' , $runOnEmpty)]
}

proc CertainDeathNode {winId} {
    global window_info classTable

    set node $window_info($winId,top_node)
    itcl::delete object $classTable(model,$node)
    unset classTable(model,$node)
}

proc KillNodeInProlog {winId} {
    # Prolog proc for when desktop is definitely going; called by destructor,
    # causes Prolog to call next proc
    prolog tk_certain_death_node('$winId')
}

proc ZapWindow { fullName } {
    global custom window_info tcl_platform
    
    upvar 0 window_info($fullName,parent) target
    #ShowMess debug info "$winId $custom(first_up)" ok
    if {$window_info($fullName,is_top_level)} {
        focus $target.canvas
        update
        set cacheStream [NetOpen $custom(prefDir)/.layout w]
        puts $cacheStream [string match zoomed [wm state $target]]
        puts $cacheStream [wm geometry $target]
# under Linux this will be the geom of the client window not the frame -- fix
        close $cacheStream
    if {[string equal windows $tcl_platform(platform)]} {
        file attributes $custom(prefDir)/.layout -hidden true
    }
    }
    destroy ${target}top
    
    destroy $target
    foreach oldData [array names window_info $fullName,*] {
        unset window_info($oldData)
    }
}

proc ClearWindow {winId} {
    # Bit of tricky manoovering to delete all but window background
    $winId addtag doomed all
    $winId dtag /base/ doomed
    $winId delete doomed
    ResetEqnBar [winfo parent $winId]
}

proc exit_simile {} {
    global custom tcl_platform execThread
    
    set cache [file join $custom(prefDir) .recent6]
    set cacheStream [NetOpen $cache w]
    fconfigure $cacheStream -encoding utf-8
    set cwd [file normalize [pwd]/dummy]
    foreach oldFile $custom(hotlist) {
# experimental: save relative to prefdir
	if {![string match windows $tcl_platform(platform)]} {
	    set oldFile [::fileutil::fullnormalize $oldFile]
	}
        puts $cacheStream [::fileutil::relative $custom(prefDir) $oldFile]
    }
    close $cacheStream
# remove eqn dialogue layout, it might be wrong when we restart
    set eqnLayout [file join $custom(prefDir) .layouts equation]
    if {[file exists $eqnLayout]} {
	file delete $eqnLayout
    }
    if {[string equal windows $tcl_platform(platform)]} {
	file attributes $cache -hidden true
    }
    foreach {name runner} [array get execThread *,id] {
	thread::release $runner
    }
    StartComms -1
    SaveTrans
}
