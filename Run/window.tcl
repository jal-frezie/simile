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
    
    return [ExtractPrologName $winId [GetClickedObj $winId $canx $cany 6]]
}

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
    prolog $prologCmd
    return $fromProlog
}

# This does similar to the above but gets the translation table, specially
# for aliasing into the execution interpreters. It's a stopgap, as the
# translation table should really be in the model code.

proc GetTransTable {node} {
    global fromProlog
    prolog tk_get_info({},$node,types)
    return $fromProlog
}

# Procedure for when Tcl recognizes what object is clicked but being a
# maleficent pile of junk refuses to pass on this information so we have
# to interrogate it to find what is closest to the click point

proc ClickObj { x y winId X Y action} {
    global clicktime equationbar pushedbutton window_info looks
    
    #puts "$action it!"
    
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
            set RB 0
            set CD 0
        }
    }
    
    set clicktime [clock clicks -milliseconds]
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set xco [Unscale $winId $canx]
    set yco [Unscale $winId $cany]
#    if {$looks(gridPitch)} {
#	set xco [expr $looks(gridPitch)*round($xco/$looks(gridPitch))]
#	set yco [expr $looks(gridPitch)*round($yco/$looks(gridPitch))]
#	set looks(lastXnode) $xco
#	set looks(lastYnode) $yco
#    }
    
    focus $winId
    set target [GetClickedObj $winId $canx $cany 6]
    if {!$target} {
        # a background click
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
    if {[do_if_running $topNode ProdObj $topNode {} $context]} {
	return
    }
    # IO tool took the click, so do no more
    if {[string compare $pushedbutton snap]==0} then {
        do_in_node $topNode snap $topNode $node
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
		    set action clicktext
		}
            }
            
        }
        prolog [list tk_click_obj('$winId',  $action , $xco , $yco , $node \
                , $CD)]
        # Right button puts up context menu.
        if {$RB && [string equal select $pushedbutton]} {
            tk_popup [winfo parent $winId]top.edit $X $Y
            prolog [list tk_unclick( $xco , $yco )]
        }
        
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
            set oldEqn [GetFromProlog tk_get_info('$winId',$node,eqn)]
            if {![string match <none> $oldEqn]} {
                set label [BlankCrs [GetFromProlog \
					 tk_get_info('$winId',$node,desc)]]
		set label [string range $label 0 \
			       [expr [string last : $label]-1]]=
                $bar.label configure -text $label
                
                set winid [winfo parent $winId]
                set equationbar($winid,node) $node
                set equationbar($winid,initText) $oldEqn
                set equationbar(current_action) null
                SetEqnButtonState $bar normal
                restore_equation $winid $bar
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
    #    puts "debug info Rolling from $cl $ct $cr $cb to $l $t $r $b ok"
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
    global window_info looks
    global clicktime
    
    set dragtime [clock clicks -milliseconds]
    if {$dragtime>$clicktime && $dragtime-$clicktime<100} {
        return
    }
    
    set canx [$winId canvasx $xco]
    set cany [$winId canvasy $yco]
    set virtx [Unscale $winId $canx]
    set virty [Unscale $winId $cany]
#    if {$looks(gridPitch)} {
#	set virtx [expr $looks(gridPitch)*round($virtx/$looks(gridPitch))]
#	set virty [expr $looks(gridPitch)*round($virty/$looks(gridPitch))]
#
#	if {$virtx==$looks(lastXnode) && $virty==$looks(lastYnode)} {
#	    return
#	} else {
#	    set looks(lastXnode) $virtx
#	    set looks(lastYnode) $virty
#	}
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
    if {[llength $nodeId]} {
	prolog [list tk_embrace( '$winId' , $nodeId )]
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
# some time -- OK! 3rd param now cuts out Prolog if 0.

proc ChangeRegion {w l t r b} {
    global window_info
    
    set allowScrollBar [winfo reqwidth [winfo parent $w].yscroll]
    set hcomp [expr [Unscale $w [expr $window_info($w,width)-$allowScrollBar]]/($r - $l)]
    set vcomp [expr [Unscale $w [expr $window_info($w,height)-$allowScrollBar]]/($b - $t)]
    set comp [expr $hcomp>$vcomp?$hcomp:$vcomp]
    set newReg [list [Scale $w $l] [Scale $w $t] [Scale $w $r] [Scale $w $b]]
    $w configure -scrollregion $newReg
    eval {ResizeBackgnd $w} $newReg
    #ShowMessage debug info "Just done [$w coords 1]" ok
    #    puts $comp
    if {$comp>1.01} {
        DoZoom $w $comp 0
    }
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
    
    wm protocol $winName WM_DELETE_WINDOW \
            [list byebye $c]
    
    set window_info($c,top_node) $topNode
    if {[set window_info($c,is_top_level) $isTopLevel]} {
	set window_info($c,topCapt) {}
    } else {
	set window_info($c,topCapt) $window_info(lastClickCapt)
    }
    
    TweakWindow $c $winTitle $initialScale $wl $wt $wr $wb $colour
    #    wm maxsize $winName [winfo screenwidth $winName] \
    #	[winfo screenheight $winName]
    
    AddMainMenu $winName $topNode [expr $wr-$wl] $isTopLevel $args
    AddCanvasBindings $c $topNode

    ####### Model window extensions
    set modelWindowExtensions [itcl::find classes ::ModelWindowExtn::*]
    #ShowMessage debug info "ModelWindow $winName\n\
    #        $modelWindowExtensions" ok
    foreach extClass $modelWindowExtensions {
        #ShowMessage debug info "$extClass " ok
        set extn [$extClass $winName.#auto $winName]; # create an extension object for the new model window
        $extn MergeMenu
    }
    ################
    
    
    #    tkwait visibility $winName
    set window_info($c,parent) $winName
    
    InterpMenu $c off
    focus $c
    #    ShowMessage debug info "Messing with [wm frame $winName]" ok
    #    maximize_fg_win
    return $c
}

proc ModelWindow {winName} {
    global tcl_platform
    menu ${winName}top
    toplevel $winName -menu ${winName}top
    
    switch $tcl_platform(platform) {
        windows { wm iconbitmap $winName -default ../Run/simile16.ico }
        unix { wm iconbitmap $winName @../Images/dribble.xbm}
    }
    # Create a scrollable canvas
    set c [canvas $winName.canvas -bg white -confine 1 \
            -xscrollcommand "AdjustCanvas $winName toolSlot x" \
            -yscrollcommand "AdjustCanvas $winName canvas y" \
            -xscrollincrement 1 -yscrollincrement 1]
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
    set cx $window_info($c,width)
    set cy $window_info($c,height)
    set window_info($c,width) [expr $w - 4]
    set window_info($c,height) [expr $h - 4]
    #    ShowMessage debug info "New size is $w $h" ok
    RollBack $c 1 [expr ($cx - $w)/2 + 2] [expr ($cy - $h)/2 + 2] \
            [expr ($cx + $w)/2 - 2] [expr ($cy + $h)/2 - 2]
}

proc TransCnvNames {c swaps} {
    foreach pair $swaps {
	set oldie [lindex [split $pair -] 0]
	$c addtag $pair withtag $oldie
	$c dtag all $oldie
    }
    foreach pair $swaps {
	set newbie [lindex [split $pair -] 1]
	$c addtag $newbie withtag $pair
	$c dtag all $pair
    }
}

proc TweakWindow {c winTitle scale wl wt wr wb bg args} {
    global window_info rads
    #    put back if Windows users want respite from their gash placement system
    #    wm geometry $winName +0+84
    
    # set the display depths to those we recorded
    #ShowMessage debug info "TweakWindow $c $winTitle $scale $wl $wt $wr $wb $bg $args" ok
    set cats {ghost_link influence variable flow \
                compartment submodel caption sections}
    for {set depthParam 0} {$depthParam < [llength $args]} {incr depthParam} {
        set rads($c,[lindex $cats $depthParam]) [lindex $args $depthParam]
        WindowDetail $c [lindex $cats $depthParam] \
                [lindex $args $depthParam] 0
    }
    
    $c configure -width 1 -height 1
    $c configure -scrollregion "$wl $wt $wr $wb" \
            -width [expr $wr-$wl] -height [expr $wb-$wt]
    set window_info($c,width) [expr $wr - $wl]
    set window_info($c,height) [expr $wb - $wt]
    set window_info($c,scale) $scale
    # last will be overwritten if drawing from Prolog
    
    ChangeParentTitle $c $winTitle $bg
    
    set topWin [winfo parent $c]
    scan [wm maxsize $topWin] "%d %d" mw mh
    #ShowMessage debug info "$wl $wt $wr $wb <> $mw $mh" ok
    if {[pack propagate $topWin] &&
        ($wr-$wl >= $mw-8 || $wb-$wt >= $mh-8)} {
        catch {winfo state $topWin zoomed}
    }
    #ShowMessage debug info "Just done [$c coords 1]" ok
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

set looks(gridPitch) 15.0

proc AddGrid {c onCol wl wt wr wb} {
    global looks window_info custom
    if {$custom(showgrids,$c)} {
	set col $onCol
    } else {
	set col {}
    }
    set interval [expr $looks(gridPitch)*$window_info($c,scale)]
    for {set x [expr $interval*ceil($wl/$interval)]} {$x<$wr} \
	{set x [expr $x+$interval]} {
	set nearx [expr int($x)]
	$c create line $nearx $wt $nearx $wb -fill $col \
	    -tag "realcolour($onCol) /background/ /base/ /grid/"
    }
    for {set y [expr $interval*ceil($wt/$interval)]} {$y<$wb} \
	{set y [expr $y+$interval]} {
	set neary [expr int($y)]
	$c create line $wl $neary $wr $neary -fill $col \
	    -tag "realcolour($onCol) /background/ /base/ /grid/"
    }
}

# following is pulled from tclers wiki
    proc Gradient {rgb factor {window .}} {

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
		#	    set oldW [base$wc cget -width]
		#	    set oldH [base$wc cget -height]
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
    AddGrid $wc [Gradient $baseColor -0.1 $wc] $l $t $r $b
    $wc lower /base/ ;# should keep them in order
    global window_info
    if {$window_info($wc,is_top_level)} {
	prolog tk_resize_top_win('$wc',[expr $r-$l],[expr $b-$t])
    }
}

proc AcceleratorState {winName menu item state} {
    global accelerator
    #puts "AcceleratorState {winName menu item state} $winName $menu $item $state [info exists accelerator($menu,$item)]"
    if {[info exists accelerator($menu,$item)]} {
        if {[string match normal $state]} {
            bind $winName $accelerator($menu,$item) \
                    [list if "\[DoingSelection $winName\]" \
                    [${winName}top.$menu entrycget $item -command]]
        } else  {
            bind $winName $accelerator($menu,$item) {}
        }
    }
}

proc AddAccelerator {winName menu item event} {
    #puts "AddAccelerator {winName menu item event} $winName $menu $item $event"
    global accelerator
    set accelerator($menu,$item) $event
    AcceleratorState $winName $menu $item [${winName}top.$menu entrycget $item -state]
}

proc DoingSelection {winName} {
    return [expr ![llength [$winName.canvas focus]] \
            && [string match [focus] $winName.canvas]]
}

proc AddCanvasBindings { c topNode } {
    bind $c <Button-1> {ClickObj %x %y %W %X %Y click}
    bind $c <Control-Button-1> {ClickObj %x %y %W %X %Y ctrl}
    # Doubleclicks now bound to objects not canvas
    bind $c <Double-1> {ClickObj %x %y %W %X %Y doubleclick}
    
    bind $c <B1-Motion> {DragObj %W %x %y}
    bind $c <ButtonRelease-1> {ReleaseObj %W %x %y}
    bind $c <Button-3> {ClickObj %x %y %W %X %Y right}
    bind $c <Control-Button-3> {ClickObj %x %y %W %X %Y ctrl-right}
    bind $c <ButtonRelease-3> {ReleaseObj %W %x %y}
    bind $c <FocusIn> {EmbraceObj %W}
    bind $c <FocusOut> {AbandonObj}
    
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
    $c bind has_info <Leave> RemovePopup
}

proc AddEqnPopup {node x y winId X Y} {
    global pushedbutton errorInfo runState
    set doDesc [PrefValue custom(compDescPop) compDescPop]
    set doVal [expr [HaveValues $node] && \
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
            set desc [GetFromProlog tk_get_info('$winId',$plName,desc)]
            
            # after going Prolog, check popup window still there
            # note colour etc are not comments though they look like them in emacs
            # actually new technology should make this unnecessary
            #if {![winfo exists .popup]} return
            AddPopupMessage $desc \#c0ffc0
        }
        if {$doCmt} {
            set fromProlog [GetFromProlog tk_get_info('$winId',$plName,comment)]
            #if {![winfo exists .popup]} return
            AddPopupMessage $fromProlog \#ffe0c0
        }
        if {$doVal} {
	    set cptPath [GetClickCapt $winId $canx $cany $plName]
	    set execName [do_for_node $node GetIdFromCaptionPath $cptPath]
	    AddPopupMessage novalue \#ffffc0 $node GetShortVals $node $execName
	}
    }
}

# Canvas chapter (of Welch)

# Bindings for canvas Text items

# when we paste we do not know whether the selection has been encoded as utf-8
# or not, but Tcl knows and will do the right thing if pasting into an entry
# box. So why struggle -- make an entry box where no-one can see it, and when
# pasting into canvas text, paste into that then read the text from it.

entry .hidden_e
pack .hidden_e

proc CanvasEditBind { c } {
    
    $c bind currently_editable <B1-Motion> {
        if {[lsearch [%W gettags [%W focus]] selected] != -1} {
            %W select to current \
                    @[join [canvasTLDistance %W [%W canvasx %x] \
                    [%W canvasy %y]] ,]
        }
    }
    $c bind currently_editable <Delete> {
        if {![CanvasDelSeln %W]} {
            %W dchars [%W focus] insert
        }
	FixBackBox %W [%W focus]
    }
    $c bind currently_editable <Control-d> {
        if {[%W focus] != {}} {
            %W dchars [%W focus] insert
	    FixBackBox %W [%W focus]
        }
    }
    $c bind currently_editable <Control-h> {
        if {![CanvasDelSeln %W]} {
            set _t [%W focus]
            if {[%W index $_t insert]} {
                %W icursor $_t [expr [%W index $_t insert]-1]
                %W dchars $_t insert
            }
        }
	FixBackBox %W [%W focus]
    }
    $c bind currently_editable <BackSpace> \
            [$c bind currently_editable <Control-h>]
    
    $c bind currently_editable <Control-Delete> {
        %W delete [%W focus]
	FixBackBox %W [%W focus]
    }
    $c bind currently_editable <Return> {
        %W insert [%W focus] insert \n
	FixBackBox %W [%W focus]
    }
    $c bind currently_editable <Any-Key> {
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
    $c bind currently_editable <Key-Right> {
        %W select clear
        %W icursor [%W focus] [expr [%W index [%W focus] insert]+1]
    }
    $c bind currently_editable <Shift-Right> {
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
    $c bind currently_editable <Control-f> \
            [$c bind currently_editable <Key-Right>]
    
    $c bind currently_editable <Key-Left> {
        %W select clear
        %W icursor [%W focus] [expr [%W index [%W focus] insert]-1]
    }
    $c bind currently_editable <Shift-Left> {
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
    
    $c bind currently_editable <<Cut>> {CanvasTextCopy %W; CanvasDelete %W
	FixBackBox %W [%W focus]
    }
    $c bind currently_editable <<Copy>> {CanvasTextCopy %W}
    $c bind currently_editable <<Paste>> {
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
    set nid [ExtractPrologName $c $textItem]
    scan [$c bbox $textItem] "%g %g %g %g" l t r b
    foreach backBox [$c find withtag $nid] {
	if {[regexp {/[^ ]*_text/} [$c gettags $backBox] spare]} {
	    if {[string equal line [$c type $backBox]]} {
		$c coords $backBox $r $t $l $t $l $b $r $b $r $t
	    } else {
		$c coords $backBox $l $t $r $b
	    }
	}
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
        prolog tk_menu('$window',$button,'$item')
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
        zoomin {DoZoom $win 1.414214 1}
        tosel {DisplayArea $win}
        tofit {DisplayAll $win}
        zoomout {DoZoom $win .707107 1}
        find {FindCaption $win}
        findnext {NextCaption $win}
        raiseMRE {RaiseMREFor $win}
        open_all {OpenAll $win}
        save_all {SaveAll $win}
        insert {InsertModel $win}
    }
}

proc AddMainMenu { winid topNode initWidth isTopLevel initDepths} {
    global custom pushedbutton tcl_platform runState iconImages
    
    set c $winid.canvas
    set fm [menu ${winid}top.file -tearoff 0 \
            -postcommand "FillReopen $winid"]
    ${winid}top add cascade -label File -underline 0 -menu ${winid}top.file
    if {$isTopLevel} {
	set newCmd NewTopLevel
    } else {
	set newCmd "MenuSelect $c file new"
    }
    $fm add command -label New -command $newCmd -accelerator "Ctrl+N"
    AddAccelerator $winid file New "<Control-n>"
#    $fm add command -label "New top-level" -command "NewTopLevel"
    $fm add command -label Open... -command "MenuSelect $c local open_all"\
            -accelerator "Ctrl+O"
    AddAccelerator $winid file Open... "<Control-o>"
    $fm add cascade -label "Reopen" -menu .openrecent
    $fm add command -label Save -command "MenuSelect $c file save" \
            -accelerator "Ctrl+S"
    AddAccelerator $winid file Save "<Control-s>"
    
    $fm add command -label "Save as..." \
            -command "MenuSelect $c file save_as"
    $fm add command -label "Save selection as..." \
            -command "MenuSelect $c file save_seln_as"
    $fm add command -label "Save package" \
            -command "MenuSelect $c local save_all"
    
    $fm add separator
    $fm add command -label "Print..." \
            -command "PrintNow $c"\
            -accelerator "Ctrl+P"
    AddAccelerator $winid file "Print..." "<Control-p>"
    $fm add cascade -label "Import" -menu $fm.sub0
    set fm1 [menu $fm.sub0 -tearoff 0]
#    $fm1 add command -label "Spreadsheet..." \
#            -command "MenuSelect $c file import_ss"
    $fm add cascade -label "Export" -menu $fm.sub1
    set fm2 [menu $fm.sub1 -tearoff 0]
    $fm2 add command -label "Model declarations" \
            -command "MenuSelect $c file export_prolog"
    $fm2 add command -label "C++ code" \
            -command "MenuSelect $c file build_c"
    $fm2 add command -label "executable binary" \
            -command "MenuSelect $c file compile_c"
    $fm2 add command -label "PostScript graphics" \
            -command "ExportPostscript $c"
    $fm add separator
    
    $fm add command -label Close -command "MenuClose $c" \
            -accelerator "Alt+x"
    AddAccelerator $winid file Close "<Alt-x>"
    $fm add command -label Exit -command "prolog tk_kill_everything('$c')"
    
    
    # edit menu: purpose of postcommand is to enable/disable cut/copy/paste items
    # for what is available, overridden later if it is popup
    set fm [menu ${winid}top.edit -tearoff 0 \
            -postcommand "prolog tk_bar_edit_menu('$c')"]
    ${winid}top add cascade -label Edit -underline 0 -menu ${winid}top.edit
    
    $fm add cascade -label "Create new" -menu $fm.add
    set em1 [menu $fm.add -tearoff 0]
    foreach type {Compartment Variable Flow Influence} {
        $em1 add command -label $type -command \
                "MenuSelect $c edit [string tolower $type]"
    }
    $em1 add command -label "Role arrow" -command \
            "MenuSelect $c edit relation"
    $em1 add cascade -label "Membership control" -menu $em1.sub
    $em1 add command -label "Text box" -command \
            "MenuSelect $c edit text"
    set em2 [menu $em1.sub -tearoff 0]
    foreach type {Creation Immigration Reproduction Loss} {
        $em2 add command -label $type -command \
                "MenuSelect $c edit [string tolower $type]"
    }
    $em2 add command -label "Existence condition" -command \
            "MenuSelect $c edit condition"
    $em2 add command -label "Iteration condition" -command \
            "MenuSelect $c edit alarm"
    $fm add separator
    
    $fm add command -label Undo -command "UnOrReDo $c 0" \
            -state disabled -accelerator "Ctrl+Z"
    AddAccelerator $winid edit Undo "<Control-z>"
    $fm add command -label Redo -command "UnOrReDo $c 1" \
            -state disabled
    # no need for this as cut/copy now does it -- keep so we can have non blue
    if {[string match windows $tcl_platform(platform)]} {
        $fm add separator
        $fm add command -label "Copy diagram" -command "CopyCanvasToWindowsClipboard $c 0"
    }
    $fm add separator
    
    $fm add command -label Cut -command "CopyCanvasToWindowsClipboard $c 1; \
            MenuSelect $c edit cut" -accelerator "Ctrl+X"
    AddAccelerator $winid edit Cut "<Control-x>"
    $fm add command -label Copy -command "CopyCanvasToWindowsClipboard $c 1; \
            MenuSelect $c edit copy" -accelerator "Ctrl+C"
    AddAccelerator $winid edit Copy "<Control-c>"
    $fm add command -label Paste -command "MenuSelect $c edit paste" \
            -accelerator "Ctrl+V"
    AddAccelerator $winid edit Paste "<Control-v>"
    $fm add command -label {Reroute links} \
            -command "MenuSelect $c edit reroute"
    $fm add command -label {Align to grid} \
            -command "MenuSelect $c edit snap"
    $fm add command -label Delete -command "MenuSelect $c edit delete" \
            -accelerator "Del"
    AddAccelerator $winid edit Delete "<Delete>"
    $fm add separator
    
    $fm add command -label "Select all" -command "MenuSelect $c edit selall" \
            -accelerator "Ctrl+A"
    AddAccelerator $winid edit "Select all" "<Control-a>"
    $fm add command -label "Unselect all" \
            -command "MenuSelect $c edit unselall" -accelerator "Ctrl+U"
    AddAccelerator $winid edit "Unselect all" "<Control-u>"
    $fm add command -label "Invert selection" \
            -command "MenuSelect $c edit invsel" -accelerator "Ctrl+*"
    AddAccelerator $winid edit "Invert selection" "<Control-Shift-8>"
    
    AddFindMenu $c $fm
    $fm add separator
    $fm add command -label "Properties..." \
            -command "MenuSelect $c edit properties"
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
    $fm add check -command "UpdateGrid $c" \
            -label "Grids" -variable custom(showgrids,$c)
    
    $fm add separator
    AddZoomMenu $c $fm 1
    $fm add cascade -label "Show detail" -menu $fm.sub3
    set fm3 [menu $fm.sub3 -tearoff 0]
    AddDetailMenu $c $fm3 $initDepths
    menu $fm.sub4 -tearoff 0
    $fm add cascade -label "Customize" -menu $fm.sub4
    foreach category { \
                {compartment "Compartments..."} \
                {variable "Variables..."} \
                {flow "Flows, bowties and clouds..."} \
		{influence "Influences..."} \
                {submodel "Submodels..."} \
                {relation "Relations..."} \
                {condition "Channels..."}
                {text "Text boxes..."}
                {select "All components..."}} {
	$fm.sub4 add command -command "Customize $winid [lindex $category 0]" \
	    -label [lindex $category 1]
    }

    set fm [menu ${winid}top.model -tearoff 0 -postcommand "AbleComp $winid"]
    if {$isTopLevel} {
        set execEntryState normal
    } else {
        set execEntryState disabled
    }
    ${winid}top add cascade -label Model -underline 0 \
            -menu ${winid}top.model
    $fm add command -label "Run" -state $execEntryState \
                    -command "MenuSelect $c file run_c" \
                    -accelerator "Ctrl+R"
    AddAccelerator $winid model "Run" "<Control-r>"
    $fm add command -label "Debug" -state $execEntryState \
                    -command "MenuSelect $c file run_tcl" \
                    -accelerator "Ctrl+D"
    AddAccelerator $winid model "Debug" "<Control-d>"
    $fm add command -label "Abort execution" -state $execEntryState \
                    -command "FinishExec $c"
    $fm add separator
    $fm add command -label "List equations" \
            -command "MenuSelect $c file list_eqns" \
            -accelerator "Ctrl+L"
    AddAccelerator $winid model "List equations" "<Control-l>"
    $fm add separator
    $fm add cascade -label Add -menu $fm.sub1
    set fm1 [menu $fm.sub1 -tearoff 0]
    
    # The radiobuttons use MIpushedbutton as their variable because
    # the command procedure has to know what the old pushedbutton was
    # so it can unpress it, so they cannot use that
    
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
    $fm1 add radiobutton -label Migration -command "ItemSelect immigration"\
            -variable MIpushedbutton -value immigration
    $fm1 add radiobutton -label Reproduction -command "ItemSelect reproduction"\
            -variable MIpushedbutton -value reproduction
    $fm1 add radiobutton -label Extermination -command "ItemSelect loss"\
            -variable MIpushedbutton -value loss
    $fm1 add radiobutton -label Condition -command "ItemSelect condition"\
            -variable MIpushedbutton -value condition
    $fm1 add radiobutton -label Alarm -command "ItemSelect alarm"\
            -variable MIpushedbutton -value alarm
    $fm1 add radiobutton -label "Text box" -command "ItemSelect text"\
            -variable MIpushedbutton -value text
    $fm add cascade -label Flip -menu $fm.sub2
    set fm2 [menu $fm.sub2 -tearoff 0]
    $fm2 add command -label Horizontal \
            -command "MenuSelect $c edit flip_h"
    $fm2 add command -label Vertical \
            -command "MenuSelect $c edit flip_v"
    
    $fm add command -label "Insert..." \
            -command "MenuSelect $c local insert"
    $fm add separator
    $fm add command -label "Save interface" \
            -command "MenuSelect $c file save_interface"
    $fm add command -label "Load interface" \
            -command "MenuSelect $c edit set_interface"
    
    
    set fm [menu ${winid}top.tools -tearoff 0]
    ${winid}top add cascade -label Tools -underline 0 \
            -menu ${winid}top.tools
    $fm add radiobutton -label "Label/move elements" \
            -command "ModeSelect select" -variable MIpushedbutton -value select
    #    $fm add radiobutton -label "Move elements" -command "ModeSelect move"\
    -variable MIpushedbutton -value move
    #    $fm add radiobutton -label "Delete elements" -command "ModeSelect delete"\
    -variable MIpushedbutton -value delete
    #    $fm add radiobutton -label "Duplicate submodels" -command "ModeSelect copy"\
    -variable MIpushedbutton -value copy
    $fm add radiobutton -label "Create ghost nodes"  -command "ModeSelect ghost"\
            -variable MIpushedbutton -value ghost
    $fm add radiobutton -label "Inspect elements"  -command "ModeSelect snap"\
            -variable MIpushedbutton -value snap -state disabled
    
    if {[HaveValues $topNode]} {
        ${winid}top add  cascade -label "I/O tools" -underline 0 \
	    -menu ${winid}top.helpers
        $fm entryconfigure "Inspect elements" -state normal
    }
    
    set fm [menu ${winid}top.help -tearoff 0]
    ${winid}top add cascade -label Help -underline 0 -menu ${winid}top.help
    $fm add command -label Contents -command "ContextSensitiveHelp $winid index.htm" \
            -accelerator "F1"
    AddAccelerator $winid help Contents "<F1>"
#    $fm add command -label Huh? -command {ShowMessage debug info $errorInfo ok}
    $fm add command -label About... -command [list ShowAbout $winid]
    
    set nb [frame $winid.toolSlot.navbar -border 2]
    pack [Separator $nb.afterSeparator -orient horizontal] -fill x -side bottom
    if {[PrefValue custom(bigButtons) bigButtons]} {
        set buttonImages ../Images/Toolbar/Large
    } else {
        set buttonImages ../Images/Toolbar
    }
    
    foreach navCmd {{new {file new}} {open {file open}} \
                {save {file save}}  {print {local print}} {separator1}\
                {undo {local undo}} {redo {local redo}} {separator2}\
                {flip_h {edit flip_h}} {flip_v {edit flip_v}} {separator3}\
			{tog_grid {local tog_grid}} {separator4} \
			{zoomin {local zoomin}} {zoomsel {local tosel}} \
                {zoomfit {local tofit}} {zoomout {local zoomout}} \
                {separator5}   } {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised\
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    if {[PrefValue custom(initGrid) initGrid]} {
	$nb.tog_grid configure -state active -relief sunken
    }
    
    foreach navCmd {{rerun {local rerun}} {separator6} \
                {find {local find}} {findmore {local findnext}} {separator7}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    
    # button to raise single-window run env (ready for more tools in this section)
    foreach navCmd {{runenv {local raiseMRE}}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised \
                    -command [concat "MenuSelect $c" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    $nb.runenv configure -state disabled
    
    set tb [frame $winid.toolSlot.toolbar -border 2]
    pack [Separator $tb.afterSeparator -orient horizontal] -fill x -side bottom
    foreach mode {compartment variable flow influence separator1 submodel \
                relation separator2 creation immigration reproduction loss condition alarm separator3 text} {
        if {[string match separator* $mode]} {
            
            pack [Separator $tb.$mode -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${mode}.gif]
            set bt [button $tb.$mode -command "ItemSelect $mode" -image $testImg -borderwidth 1 -relief flat -overrelief raised]
            pack $bt -side left -padx 2 -pady 2
            BindPopup $bt $mode
            bind $bt <ButtonRelease-1> "DragComponentIn $c $bt %X %Y"
        }
    }
    pack [Separator $tb.spacer -orient vertical] -fill y -side left
    
    foreach mode {select ghost snap} {
        set testImg [image create photo -file $buttonImages/${mode}.gif]
        pack [button $tb.$mode -image $testImg -command "ModeSelect $mode" \
                -borderwidth 1 -relief flat -overrelief raised] \
                -side left -padx 2 -pady 2
        BindPopup $tb.$mode $mode
    }
    if {![HaveValues $topNode]} {
        $tb.snap configure -state disabled
    }
    
    $tb.$pushedbutton configure -relief sunken
    $tb.$pushedbutton configure -state active
    
    
    ### Formula bar section
    ### Robert Muetzelfeldt
    ### Started 4/3/02
    set eb [frame $winid.toolSlot.eqnbar -border 1 -relief flat]; # raised
    
    label $eb.label -anchor e
    pack $eb.label -side left
    
    global equation msgs
#    ComboBox $eb.equation -editable 1 -state disabled -width 40
    entry $eb.equation -state disabled -width 40
    pack $eb.equation -side left -expand 1 -fill x
    bind $eb.equation <Return> [list accept_equation $winid $eb.equation]
    bind $eb.equation <FocusIn> "EmbraceEqn $winid"
    bind $eb.equation <FocusOut> AbandonEqn
    pack [button $eb.tick -state disabled -image $iconImages(tick) \
            -borderwidth 1 \
            -command [list accept_equation $winid $eb.equation]] -side left
    
    pack [button $eb.cross -state disabled -image $iconImages(cross) \
            -borderwidth 1 \
            -command [list restore_equation $winid $eb]] -side left
    
    frame $eb.padding -width 10
    pack $eb.padding -side left
    pack [Separator $eb.afterSeparator -orient horizontal] -fill x -side bottom
    
    set image [image create photo -file "../Images/Eqnbar/inputs.gif"]
    menubutton $eb.inputs -state disabled -menu $eb.inputs.menu \
            -borderwidth 2 -relief raised -image $image
    pack $eb.inputs -side left
    set m [menu $eb.inputs.menu -tearoff 0 \
            -postcommand [list AddInputs $winid $eb]]
    #    $m add command -label biomass -command bell
    #    $m add command -label k -command bell
    #BindPopup $m foobar
    
    menubutton $eb.function -state disabled -menu $eb.function.menu \
            -borderwidth 2 -relief raised -image $iconImages(function)
    pack $eb.function -side left
    set m [menu $eb.function.menu -tearoff 0]
    foreach funk [concat {{{{Built-in} {Model properties}} index}} \
            $equation(fnDefs)] {
                set box $m
                #puts "Adding $funk to $box"
                foreach level [split [join [lindex $funk 0] /] /] {
                    set lname $box.[string tolower [join $level _]]
                    if {[catch {$box index $level}]} {
                        menu $lname -tearoff 0
                        MenuBindPopup $lname {}
                        $box add cascade -menu $lname -label $level
                    }
                    set box $lname
                }
                set component [lindex $funk 1]
                if {[catch {$box index $component\(\)}]} {
                    $box add command -label $component\(\) \
                    -command [list InsertFunction $eb.equation $component]
                }
            }
    
    
    #    set useFunctions [lrange $equation(fnDefs) 0 9]
    #    foreach defn $useFunctions {
    #        set cmd [lindex $defn 1]
    #        $m add command -label $cmd\(\) \
    -command [list InsertFunction $eb.equation $cmd]
    #    }
    #    $m add command -label "All functions..." -command bell
    
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
    
    pack [Separator $winid.toolSlot.topseparator -orient horizontal] -fill x -side top
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

proc AddFindMenu {canvas menu} {
    $menu add separator
    $menu add command -label Find... -command "FindCaption $canvas" \
            -accelerator "Ctrl+F"
    AddAccelerator [winfo parent $canvas] edit "Find..." "<Control-f>"
    $menu add command -label "Find next" -command "NextCaption $canvas" \
            -accelerator "F3"
    AddAccelerator [winfo parent $canvas] edit "Find next" "<F3>"
}

proc AddZoomMenu {canvas menu tellProlog} {
    $menu add cascade -label Zoom -menu $menu.sub2
    set fm2 [menu $menu.sub2 -tearoff 0]
    $fm2 add command -label "In lots" -command "DoZoom \
            $canvas 1.953125 $tellProlog"
    $fm2 add command -label "In a bit" -command "DoZoom \
            $canvas 1.25 $tellProlog"
    $fm2 add command -label "To selection" -command "DisplayArea $canvas"
    $fm2 add command -label "To fit" -command "DisplayAll $canvas"
    $fm2 add command -label "Out a bit" -command "DoZoom \
            $canvas 0.8 $tellProlog"
    $fm2 add command -label "Out lots" -command "DoZoom \
            $canvas 0.512 $tellProlog"
    
}

proc ReconstituteMenu {newMenu mList tgtNode} {
    menu $newMenu -tearoff 0
    set subs 0
    foreach entrySpec $mList {
	set type [lindex $entrySpec 0]
	$newMenu add $type -label [lindex $entrySpec 1]
	switch $type {
	    command {
		$newMenu entryconfigure last -command \
		    [concat do_in_node $tgtNode [lindex $entrySpec 2]]
	    } cascade {
		set subMenu $newMenu.sub$subs
		incr subs
		ReconstituteMenu $subMenu [lindex $entrySpec 2] $tgtNode
		$newMenu entryconfigure last -menu $subMenu
	    }
	}
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

proc DragComponentIn {winId button x y} {
    global looks
    set whatToAdd [winfo name $button]
    #    set top [winfo parent $winId]
    #puts $x,$y
    #    foreach level [list $top $winId] {
    #	scan [winfo geometry $level] %dx%d+%d+%d w h ox oy
    #puts $level,$ox,$oy
    #	incr x [expr -$ox]
    #	incr y [expr -$oy]
    #    }
    set x [expr $x-[winfo rootx $winId]]
    set y [expr $y-[winfo rooty $winId]]
    
    if {$x<0 || $x>[winfo width $winId] || $y<0 || $y>[winfo height $winId]} {
        # not in canvas, ignore
        return
    }
    
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set xco [Unscale $winId $canx]
    set yco [Unscale $winId $cany]
#    if {$looks(gridPitch)} {
#	set xco [expr $looks(gridPitch)*round($xco/$looks(gridPitch))]
#	set yco [expr $looks(gridPitch)*round($yco/$looks(gridPitch))]
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
        set target [$winId find closest $canx $cany $halo]
        if {![string match "*/background/*" [$winId gettags $target]]} {
            return $target
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
    
    #    if {[string match $winid $custom(first_up)]} {
    #	if {[string match None [PrefValue custom(compChoice) compChoice]]} {
    #	    set cCompOption disabled
    #	} else {
    #	    set cCompOption normal
    #	}
    #	${winid}top.model entryconfigure "Build In C++" -state $cCompOption
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

proc AbandonEqn {} {
    prolog tk_abandon_eqn
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
        $toolBar.tog_grid configure -state active -relief sunken
    } else {
        $toolBar.tog_grid configure -state normal -relief flat
    }
    
    foreach gridLine [$winId find withtag /grid/] {
	if {$custom(showgrids,$winId)} {
	    regexp {realcolour\(([^\)]+)\)} [$winId gettags $gridLine] \
                tag oldColour
	} else {
	    set oldColour {}
	}
	$winId itemconfigure $gridLine -fill $oldColour
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
                {caption "Captions..."}
	        {text "Text boxes..."}} {
        
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

proc MenuClose {winId} {
    global window_info
    foreach tlItem [array names window_info *,is_top_level] {
	if {$window_info($tlItem) && [string last $winId $tlItem]} {
	    set notLastTl 1
	}
    }
    if {[info exists notLastTl]} {
	byebye $winId
    } else {
	MenuSelect $winId file new
    }
# if it is tl we should kill its submodel windows too
}

proc byebye {winId} {
    prolog [list tk_off_window( '$winId' )]
}

proc exit_simile {} {
    global custom
    
    set cacheStream [NetOpen $custom(prefDir)/recent w]
    foreach oldFile $custom(hotlist) {
        puts $cacheStream $oldFile
    }
    close $cacheStream
}

proc ZapWindow { fullName } {
    global custom window_info
    
    upvar 0 window_info($fullName,parent) target
    #ShowMessage debug info "$winId $custom(first_up)" ok
    if {$window_info($fullName,is_top_level)} {
        focus $target.canvas
        update
        set cacheStream [NetOpen $custom(prefDir)/layout w]
        puts $cacheStream [string match zoomed [wm state $target]]
        puts $cacheStream [wm geometry $target]
        close $cacheStream
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
    ResetEqnBar [winfo parent $winId].toolSlot.eqnbar
}
