# Welcome to toolbox.tcl, the file containing the bits of tcl and tk
# needed to supply the graphical interface to the modelling environment.
# Just to give you an idea of (a) the sort of thing you can do in tcl,
# and (b) my preferred programming style, check this out....

lappend auto_path [pwd]/../Run [pwd]/../System/lib/Extras
package require BWidget

#tk_messageBox -message "library [info library] path $auto_path"

source ../Run/shapes.tcl
source ../Run/forms.tcl
source ../Run/messages.tcl
source ../Run/prefs.tcl
source ../Run/runmodel.tcl

# botch -- mre.tcl has to be loaded after the other tcls or it doesn't
# work properly

source ../Run/mre.tcl

# Test new Windows printing technology -- see file for credits/licence
if {[string match windows $tcl_platform(platform)]} {
#   pkg_mkIndex ../System/lib/Extras
    source ../System/lib/Extras/prntcanv.tcl
}

# Make Simile a DDE server under Windows. Jonathan
# Must be after the sourcing or Simile fails
#### Commented out for now. Pending outcome of bug fixing (winfo exists "")
#tk_messageBox -message [tk appname] -type ok
#catch {
#    package require dde 2.0
#    dde register Simile
#}

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

proc ControlDraw {prologVersion edition} {
    global sendvars custom tcl_platform env userinfo
    # geometry XY help message JMM
    #            "Position of Run Control when not using the Run Time \
    #                    Environment in the form +/-x+/-y." \
    
    wm withdraw .
    set sendvars(simV) $env(SIMILE_VERSION)
    set sendvars(proV) $prologVersion
    set sendvars(edn) $edition
    
    # no longer have a separate floating toolbar
    
    # On startup, check run count and offer registration if 0
    set UserStream [open ../Run/userinfo.txt r]
    # First two lines not used here


    gets $UserStream userinfo(prologId)
    gets $UserStream userinfo(interface)
    gets $UserStream userinfo(name)
    gets $UserStream userinfo(corp)
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
        gets $UserStream userinfo(name)
        gets $UserStream userinfo(corp)
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
                    set regData [::http::formatQuery Name $userinfo(name) \
                            Organisation $userinfo(corp) Email $userinfo(email) \
                            Version $userinfo(Version) OS $tcl_platform(os)]
                    ::http::geturl http://www.simulistics.com/products/SendMail.asp \
                            -query $regData}]} {
                set userinfo(done) 0
            }
        }
    }
    set UserStream [open $custom(prefDir)/version w]
    puts $UserStream $userinfo(name)
    puts $UserStream $userinfo(corp)
    puts $UserStream $userinfo(Version)
    puts $UserStream $userinfo(done)
    close $UserStream
    
    set sendvars(running) 0
    
    set custom(hotlist) {}
    if {[file exists $custom(prefDir)/recent]} {
        set cacheStream [open $custom(prefDir)/recent r]
        while {[gets $cacheStream oldFile]>0} {
            if {[file exists $oldFile] && \
		    [lsearch $custom(hotlist) $oldFile]==-1} {
                lappend custom(hotlist) $oldFile
            }
        }
    }
    if {[llength $custom(hotlist)]} {
	RecordPathChoice .sml [lindex $custom(hotlist) 0]
    }
    
    Pref_Init $custom(prefDir)/prefs ../Run/sysprefs
    Pref_Add {{custom(initNavbar) initNavbar ON "Tool bar"} \
                {custom(initToolbar) initToolbar ON "Component bar"} \
                {custom(initEqnbar) initEqnbar ON "Equation bar"} \
                {custom(bigButtons) bigButtons OFF "Use large buttons"} \
                {custom(saveExtras) saveExtras {CHOICE {Model file only} {Canvas file}} "Save models as..."} \
                {custom(compDescPop) compDescPop ON "Equation"} \
                {custom(compValPop) compValPop ON  "Value"}
        {custom(compCmtPop) compCmtPop ON  "Comment"} \
                {custom(recentCount) recentCount 10 "Entries on recently used file list"} \
                {custom(flowRouting) flowRouting ON "Rectilinear flow routing"} \
                {custom(deleteEndToEnd) deleteEndToEnd ON "Delete links end-to-end"}}
    # JMM change wording and change default to ON
    Pref_Add {{custom(helperManager) helperManager ON \
                    "Use single window manager"}};
    #JMM add postions for run control and slider
    Pref_Add {{custom(runControlPosition) runControlPosition "+0-20" "Position of run control"} \
                {custom(slidersPosition) slidersPosition "+0+0" "Position of sliders"}}
    if {[string match windows $tcl_platform(platform)]} {
        Pref_Add {{custom(compChoice) compChoice {CHOICE None Microsoft GNU} \
                        "Use which C++ compiler?"}}
        file attributes $custom(prefDir) -hidden true
    }
    
    foreach nodeType {normal generic compartment channel \
                variable function submodel flow influence \
                ghost_link relation} {
        ResetLooks $nodeType
    }
    CustomizeLooks
    
    # Bogosity alert -- setting an env var to {} causes it to stay
    # (or be) unset (in windows) otherwise lappend env(OPEN_MODEL)
    # would do here...
    if {[info exists env(OPEN_MODEL)]} {
        set openModel $env(OPEN_MODEL)
    } else {
        set openModel {}
    }
    # Take the opportunity to pass the temp directory name etc to Prolog
    return [list $sendvars(simV) [brainwash $env(SIMTMPDIR)] $openModel]
}

package require mime 1.3.1


proc SaveFile {tree tgt using} {
    global mimeSquirter runState errorInfo model_id
    catch {
	set parts [GetParts $tree $tree]
	if {[info exists runState(currentTime)]} {
	    if {$runState(execTime) != $runState(currentTime)} {
		set runState(execDur) \
		    [expr $runState(execTime)+$runState(currentTime)]
	    } else {
		set runState(execDur) $runState(execTime)
	    }
	    set runParams [list $runState(execDur) $runState(displayInt)]
	    if {[info exists model_id]} {
		set runState(phases) [GetPhaseCount]
	    }
	    for {set phase 1} {$phase <= $runState(phases)} {incr phase} {
		lappend runParams $runState(update$phase)
	    }
	    lappend parts [mime::initialize -canonical text/plain \
			   -header [list "Content-Description" "Run Status"] \
			   -string $runParams]
	}
	set multiT [mime::initialize -canonical multipart/mixed \
			-header [list "Readability" $using] -parts $parts]
	set stream [open $tgt w]
	fconfigure $stream -translation binary
	mime::copymessage $multiT $stream
	# clean everything up
	close $stream
	mime::finalize $multiT -subordinates all
    } Lossage
    return $Lossage
}

proc LoadFile {tree tgt using} {
    global mimeSquirter runState errorInfo model_id
    catch {
	set multiT [mime::initialize -file $tgt]
	if {[catch {set intent [mime::getheader $multiT Readability]}]} {
	    set intent standard
	}
	if {[string match evaluation $using] && \
		![string match evaluation $intent]} {
	    error "You cannot load this model with the evaluation edition because it contains more than 15 components, and it was not created with the enterprise edition."
	}
	foreach bit [mime::getproperty $multiT parts] {
	    set Description [mime::getheader $bit Content-Description]
	    #ShowMessage debug info $Description ok
	    if {[string match "Run Status" [lindex $Description 0]]} {
		set runParams [mime::getbody $bit]
		set runState(currentTime) 0.0
		#ShowMessage debug info set ok
		set runState(execTime) [lindex $runParams 0]
		set runState(displayInt) [lindex $runParams 1]
		for {set others 2} {$others < [llength $runParams]} \
		    {incr others} {
			set runState(update[expr $others-1]) \
			    [lindex $runParams $others]
			set runState(prev_update[expr $others-1]) \
			    [lindex $runParams $others]
		    }
		set runState(phases) [expr $others-2]
	    } else {
		set Disposition [mime::getheader $bit Content-Disposition]
		if {![regexp \"(.*)\" $Disposition all oldPath]} {
			set oldPath [lindex [lindex $Disposition 0] 1]
		}
		set newPath $tree$oldPath
		file mkdir [file dirname $newPath]
		set mimeSquirter [open $newPath w]
		fconfigure $mimeSquirter -translation binary
		mime::getbody $bit -command SquirtMime -blocksize 256
	    }
	}
    } Lossage
    return $Lossage
}

proc GetParts {top tree} {
    set mimes {}
    foreach subtree [glob -nocomplain ${tree}/*] {
	if {[file isdirectory $subtree]} {
	    set mimes [concat $mimes [GetParts $top $subtree]]
	} else {
            set ext [file extension $subtree]
            switch $ext {
                .gif {
                    set PartType "image/gif"
                    set Description "Image"
		    set style inline
                }
                .pl {
                    set PartType "application/x-simile"
                    set Description "Simile model"
		    set style inline
                }
                .cnv {
                    set PartType "application/x-simile"
                    set Description "Simile canvas description"
		    set style attachment
                }
                default {
                    set PartType "application/x-simile"
                    set Description "Data"
		    set style attachment
                }
            }
	    set relPath [string range $subtree [string length $top] end]
            set Disposition "${style}; filename=\"$relPath\""
	    set newMime [mime::initialize -canonical $PartType \
                    -header [list "Content-Disposition" $Disposition] \
                    -header [list "Content-Description" $Description] \
                    -file $subtree]
	    lappend mimes $newMime
# Debug: write the body to see if it's baaad...yes it was
# Workaround: don't save anything as text/plain, stick to application/x-simile
#	    set debugname ${subtree}.mim
#	    set stream [open $debugname w]
#	    fconfigure $stream -translation binary
#	    mime::copymessage $newMime $stream
#	    close $stream
	}
    }
    return $mimes
}
	    
proc SquirtMime {args} {
    global mimeSquirter
    if {[string match end [lindex $args 0]]} {
	close $mimeSquirter
    } else {
	puts -nonewline $mimeSquirter [lindex $args 1]
    }
}
    
proc byebye {winId} {
    prolog [list tk_off_window( '$winId.canvas' )]
}

proc exit_simile {} {
    global custom model_id instance_id
    if {[info exists instance_id]} {
        c_exitmodel $model_id $instance_id
    }
    
    set cacheStream [open $custom(prefDir)/recent w]
    foreach oldFile $custom(hotlist) {
        puts $cacheStream $oldFile
    }
    close $cacheStream
}

proc ZapWindow { fullName } {
    global custom window_info
    
    upvar 0 window_info($fullName,parent) target
    #ShowMessage debug info "$winId $custom(first_up)" ok
    if {[string match $target $custom(first_up)]} {
        focus $target.canvas
        update
        set cacheStream [open $custom(prefDir)/layout w]
        puts $cacheStream [string match zoomed [wm state $target]]
	puts $cacheStream [wm geometry $target]
        close $cacheStream
    }
    destroy ${target}top
    
    destroy $target
    unset target
}

proc ClearWindow {winId} {
    # Bit of tricky manoovering to delete all but window background
    $winId addtag doomed all
    $winId dtag /base/ doomed
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

# This is used when Tcl wants to get a result from Prolog, e.g., for the
# equation bar. The prolog procedure has to set fromProlog. It should stop
# the thread until it returns, but something is wrong -- occasionally 
# fromProlog doesn't get set. Answer: don't clear it...

proc GetFromProlog {prologCmd} {
    global fromProlog
    prolog $prologCmd
    return $fromProlog
}

# Procedure for when Tcl recognizes what object is clicked but being a
# maleficent pile of junk refuses to pass on this information so we have
# to interrogate it to find what is closest to the click point

proc ClickObj { x y winId action} {
    global helperTable
    global pushedbutton
    global awaitBogusClick

    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set target [GetClickedObj $winId $canx $cany 10]
    
    if {!$target} {
        return
    }
    
    # because the canvas is also bound to generate clicks, we must
    # supress any action resulting from this if we are handling the
    # event generated by the canvas item

    set awaitBogusClick 1
    
    set node [ExtractPrologName $winId $target]
    if {[string compare $pushedbutton snap]==0} then {
        snap $node
        return
    }
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
    
    set awaitBogusClick 1
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
    #    ShowMessage debug info "Messing with [wm frame $winName]" ok
    #    maximize_fg_win
    return $c
}

proc AddAccelerators { winName } {
    # file
    bind $winName <Control-n> "MenuSelect $winName.canvas file new"
    bind $winName <Control-o> "MenuSelect $winName.canvas file open"
    bind $winName <Control-s> "MenuSelect $winName.canvas file save"
    bind $winName <Control-p> "PrintNow $winName.canvas"
    bind $winName <Alt-x> "byebye $winName"
    
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
        print {PrintNow $win}
        rerun {Rerun $win 1}
        undo {prolog tk_undo}
        redo {prolog tk_redo}
        zoomin {DoZoom $win 1.414214 1}
        tofit {DisplayAll $win}
        zoomout {DoZoom $win .707107 1}
        customize {Customize $win $pushedbutton}
        find {FindCaption $win}
        findnext {NextCaption $win}
        raiseMRE {raise .mre}
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

proc PrepForExport {winId way} {
    global jiggles tcl_platform

    # now, zoom in by detail factor to get the line thickness resolution decent
    set detail 16.0
    # For font scale 1 seems right for Unix -- Windows takes about 1.6
    if {[string match windows $tcl_platform(platform)]} {
        set textBoost 1.6
    } else {
        set textBoost 1
    }
    set ltBorder 20
    set textscale [expr $detail*$textBoost]
    if {[string match there $way]} {
	set jiggles(sr) [$winId cget -scrollregion]
	if {[scan $jiggles(sr) "%g %g %g %g" sl st sr sb]<4} {
	    set sl 0; set st 0 
	    set sr [winfo width $winId]; set sb [winfo height $winId]
	}
#ShowMessage debug info "Use scrollregion: $sl $st $sr $sb" ok
	if {[scan [$winId bbox size_on_this] "%d %d" \
	      jiggles(bl) jiggles(bt)]<2} {
	    scan [$winId bbox all] "%d %d" jiggles(bl) jiggles(bt)
	}
	set jiggles(bl) [expr $jiggles(bl)-$ltBorder]
	set jiggles(bt) [expr $jiggles(bt)-$ltBorder]
#ShowMessage debug info "Use corner: $jiggles(bl) $jiggles(bt)" ok
	$winId move all [expr -$jiggles(bl)] [expr -$jiggles(bt)]
	$winId configure -scrollregion [list \
	    [expr $detail*($sl-$jiggles(bl))] [expr $detail*($st-$jiggles(bt))] \
	    [expr $detail*($sr-$jiggles(bl))] [expr $detail*($sb-$jiggles(bt))]]
	ZoomImage $winId all $detail $textscale
    } else {
	ZoomImage $winId all [expr 1/$detail] [expr 1/$textscale]
	$winId configure -scrollregion $jiggles(sr)
	$winId move all $jiggles(bl) $jiggles(bt)
    }
    return $detail
}
	
proc CopyCanvasToWindowsClipboard {canvas} {
    global tcl_platform
    
    if {[string match windows $tcl_platform(platform)]} {
        package require gdi
        package require printer
        package require wmf
        
	PrepForExport $canvas there
        set hdc [wmf open]; #Opens a memory metafile
        printer::print_canvas $hdc $canvas
        set wmfdc [ wmf close $hdc ]; # Turn the context into a metafile handle        
	PrepForExport $canvas back

        #ShowMessage debug info "[ wmf info $wmfdc ]" ok        
        wmf copy $wmfdc; # Copy to the clipboard        
    }
}

proc PrintNow {winId} {
    global env tcl_platform
    
    if {[string match windows $tcl_platform(platform)]} {
	package require gdi
	package require printer
#	package require Tkprint

	PrepForExport $winId there
	printer::print_widget $winId 0
	PrepForExport $winId back
   } else {
    set tempPSFile $env(SIMTMPDIR)/temp.ps
    SpitPS $winId $tempPSFile
    if {[catch "exec $env(PRINTCMD) {[file nativename $tempPSFile]}" result]} {
        ShowMessage "Print command result" warning \
                "Printing seems to have failed. \
                The result returned by the print command was:
        
        $result
        
        Please see the online help to find out more about setting up printing from Simile. Alternatively you can export the model diagram as a PostScript file (use the File...Export menu command) and then print that using another package." ok
    }
    file delete $tempPSFile
   }
}

proc SpitPS {winId psfile} {
    global window_info
    set detail [PrepForExport $winId there]
    if {[info exists window_info($winId,width)]} {
	set useWidth window_info($winId,width)
	set useHeight window_info($winId,height)
    } else {
	set useWidth [winfo width $winId]
	set useHeight [winfo height $winId]
    }
    $winId postscript -file $psfile -rotate true -pageanchor nw \
            -pagex 0 -pagey 0 \
            -x [expr $detail*[$winId canvasx 0]] \
            -y [expr $detail*[$winId canvasy 0]] \
            -width [expr $detail*([$winId canvasx $useWidth] \
				      - [$winId canvasx 0])] \
            -height [expr $detail*([$winId canvasy $useHeight] \
				       - [$winId canvasy 0])] \
            -pagewidth [expr $useWidth/100.0]i \
            -pageheight [expr $useHeight/100.0]i
    PrepForExport $winId back
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
    global custom MIpushedbutton tcl_platform
    
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
            -command "PrintNow $winid.canvas"\
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
        $fm add command -label Close -command "byebye $winid" \
                -accelerator "Alt+x"
    } else {
        $fm add command -label Exit -command "byebye $winid" \
                -accelerator "Alt+x"
    }
    set fm [menu ${winid}top.edit -tearoff 0]
    ${winid}top add cascade -label Edit -underline 0 -menu ${winid}top.edit
    $fm add command -label Undo -command "prolog tk_undo" \
            -state disabled -accelerator "Ctrl+Z"
    $fm add command -label Redo -command "prolog tk_redo" \
            -state disabled -accelerator "Ctrl+Y"
    if {[string match windows $tcl_platform(platform)]} {
        $fm add separator
        $fm add command -label "Copy diagram" -command "CopyCanvasToWindowsClipboard $winid.canvas" ;#\
            # -state disabled -accelerator "Ctrl+Y"
    }
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
    
    set fm [menu ${winid}top.model -tearoff 0 -postcommand "AbleComp $winid"]
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
    $fm1 add radiobutton -label Migration -command "ItemSelect immigration"\
            -variable MIpushedbutton -value immigration
    $fm1 add radiobutton -label Reproduction -command "ItemSelect reproduction"\
            -variable MIpushedbutton -value reproduction
    $fm1 add radiobutton -label Extermination -command "ItemSelect loss"\
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
    $fm add radiobutton -label "Label elements" -command "ModeSelect select"\
            -variable MIpushedbutton -value select
    $fm add radiobutton -label "Move elements" -command "ModeSelect move"\
            -variable MIpushedbutton -value move
    $fm add radiobutton -label "Delete elements" -command "ModeSelect delete"\
            -variable MIpushedbutton -value delete
    $fm add radiobutton -label "Duplicate submodels" -command "ModeSelect copy"\
            -variable MIpushedbutton -value copy
    $fm add radiobutton -label "Create ghost nodes"  -command "ModeSelect ghost"\
         -variable MIpushedbutton -value ghost
    
    set fm [menu ${winid}top.help -tearoff 0]
    ${winid}top add cascade -label Help -underline 0 -menu ${winid}top.help
    $fm add command -label Contents -command LaunchHelp \
            -accelerator "F1"
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
                {zoomin {local zoomin}} {zoomfit {local tofit}} \
                {zoomout {local zoomout}} {separator4}   } {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised\
                    -command [concat "MenuSelect $winid.canvas" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    
    foreach navCmd {{rerun {local rerun}} {separator5} \
                {find {local find}} {findmore {local findnext}} {separator6}} {
        set handle [lindex $navCmd 0]
        if {[string match separator* $handle]} {
            pack [Separator $nb.$handle -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${handle}.gif]
            pack [button $nb.$handle -image $testImg -borderwidth 1 -relief flat -overrelief raised \
                -command [concat "MenuSelect $winid.canvas" [lindex $navCmd 1]]] \
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
                    -command [concat "MenuSelect $winid.canvas" [lindex $navCmd 1]]] \
                    -side left -padx 2 -pady 2
            BindPopup $nb.$handle $handle
        }
    }
    $nb.runenv configure -state disabled
    
    set tb [frame $winid.toolSlot.toolbar -border 2]
    pack [Separator $tb.afterSeparator -orient horizontal] -fill x -side bottom
    foreach mode {compartment variable flow influence separator1 submodel \
                relation separator2 creation immigration reproduction loss condition} {
        if {[string match separator* $mode]} {

            pack [Separator $tb.$mode -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${mode}.gif]
            pack [button $tb.$mode -image $testImg -command "ItemSelect $mode" \
                    -borderwidth 1 -relief flat -overrelief raised] -side left -padx 2 -pady 2
            BindPopup $tb.$mode $mode
        }
    }
    pack [Separator $tb.spacer -orient vertical] -fill y -side left
    
    foreach mode {select move delete copy ghost separator3 snap} {
        if {[string match separator* $mode]} {
            pack [Separator $tb.$mode -orient vertical] -fill y -side left
        } else  {
            set testImg [image create photo -file $buttonImages/${mode}.gif]
            pack [button $tb.$mode -image $testImg -command "ModeSelect $mode" \
                    -borderwidth 1 -relief flat -overrelief raised] -side left -padx 2 -pady 2
            BindPopup $tb.$mode $mode
        }
    }
    $tb.snap configure -state disabled
        
    $tb.select configure -relief sunken
    # heheheh...must be in select mode to make new window, except first
    
    ### Formula bar section
    ### Robert Muetzelfeldt
    ### Started 4/3/02
    set eb [frame $winid.toolSlot.eqnbar -border 1 -relief flat]; # raised
    
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
    pack [Separator $eb.afterSeparator -orient horizontal] -fill x -side bottom
        
    set image [image create photo -file "../Images/Eqnbar/inputs.gif"]
    menubutton $eb.inputs -state disabled -menu $eb.inputs.menu \
            -borderwidth 2 -relief raised -image $image
    pack $eb.inputs -side left
    set m [menu $eb.inputs.menu -tearoff 0 -postcommand [list AddInputs $eb]]
    #    $m add command -label biomass -command bell
    #    $m add command -label k -command bell
    #BindPopup $m foobar
    
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

proc EmbraceEqn {winid} {
    global equationbar
    if {[info exists equationbar(node)]} {
        prolog tk_embrace('$winid.canvas',$equationbar(node))
    }
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

if {![info exists interface]} {
    set interface dll
}

proc ShowAbout {winId} {
    global sendvars userinfo interface
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
    pack [label .about.f.l4 -text Version\ $sendvars(simV)\ $sendvars(edn)]
    #    pack [label .about.f.l5 -text [clock format [file mtime ../Run/main.sav]]]
    pack [label .about.f.l6 -text "Prolog: $sendvars(proV)"]
    pack [label .about.f.l7 -text "TclTk: [info patchlevel] (by $interface)"]
    pack [label .about.l6]
    pack [label .about.l7 -text "This product is registered to \
            $userinfo(name), $userinfo(corp)"]
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
	start_run $winId
        RunDialog $winId
        set widget [$runState(helperId).rcf getframe]
        $widget.topbuttons.reset invoke
    }
    # Only proceed if it worked
    if {$go && $runState(modelRunning) == 2} {
        set widget [$runState(helperId).rcf getframe]
        $widget.topbuttons.start invoke
    }
}

proc UpdateAbility {what where which whether} {
    global window_info
    foreach winData [array name window_info *,parent] {
	set winId $window_info($winData)
	set newState [ChooseText $whether normal disabled]
	${winId}top.$where entryconfigure $which -state $newState
        set navBar $winId.toolSlot.navbar
        $navBar.$what configure -state $newState
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
        $toolBar.$pushedbutton configure -relief flat
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
    set paramData [GetFromProlog tk_get_params('$winId',$node)]
    foreach paramList $paramData {
        set paramName [lindex $paramList 1]
        $bar.inputs.menu add command -label $paramName \
                -command [list InsertParam $bar $paramName]
    }
    MenuBindPopup $bar.inputs.menu $paramData
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




############################## snap: start ###################################
proc snap {node} {
    global runState
    
    set w .snap[clock seconds]
    toplevel $w
    set full_label [GetCaptionPathFromId $node]
    set full_label1 [string range $full_label 9 end]
    set last_slash [string last / $full_label1]
    set start_label [expr $last_slash+1]
    set end_submodels [expr $last_slash-1]
    set submodels [string range $full_label1 0 $end_submodels]
    set label [string range $full_label1 $start_label end]
    wm title $w "$label at time $runState(currentTime)"
    
    text $w.text -yscrollcommand "$w.yscroll set" -setgrid true \
            -xscrollcommand "$w.xscroll set" \
            -width 30 -height 20 -wrap none\
            -tabs {5c right 6.8c right 8.6c right 10.4c right}
    $w.text tag configure colour1 -background #ff9090 -foreground black
    $w.text tag configure colour2 -background #ffffff -foreground blue \
            -font {arial 10 bold}
    $w.text tag configure colour3 -font {arial 9 bold}
    $w.text tag configure colour4 -background #ffffff -foreground red \
            -font {arial 10 bold}
    scrollbar $w.yscroll -command "$w.text yview"
    pack $w.yscroll -side right -fill y
    scrollbar $w.xscroll -orient horiz -command "$w.text xview"
    pack $w.xscroll -side bottom -fill x
    pack $w.text -expand yes -fill both
    
    set values(1) [lindex [GetModelValue $node] 0]
    set length(1) [llength $values(1)]
    
    # Find number of levels of nesting
    for {set level 1} {$level<10} {incr level} {
        set nextlevel [expr $level+1]
        set values($nextlevel) [lindex $values($level) 1]
        set length($nextlevel) [llength $values($nextlevel)]
        if {$length($nextlevel)<=1} then {break}
    }
    set maxlevel $level
    
    $w.text insert end "Variable "
    $w.text insert end "$label\n" colour3
    if {[string length $submodels]>0} then {
        $w.text insert end "in submodel "
        $w.text insert end "$submodels\n" colour3
    }
    $w.text insert end "at time "
    $w.text insert end "$runState(currentTime)\n" colour3
    $w.text insert end "[clock format [clock seconds]]\n"
    $w.text insert end "Maxlevel=$maxlevel\n"
    if {$maxlevel==1} then {
        snap_down1 $w $values(1)
    } elseif {$maxlevel==2} then {
        snap_down2 $w $values(1)
    } else {
        snap_down3 $w $values(1)
    }
}


proc snap_down1 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            $w.text insert end $value colour2
        } else {
            $w.text insert end {   }
            $w.text insert end $value
            $w.text insert end \n
        }
        incr i
        if {$i==2} then {set i 0}
    }
}


proc snap_down2 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            $w.text insert end $value colour2
        } else {
            if {[llength $value]>1} then {
                $w.text insert end {    }
                set j 0
                foreach val $value {
                    if {$j==0} then {
                        $w.text insert end $val colour3
                    } else {
                        $w.text insert end { }
                        $w.text insert end $val
                        $w.text insert end {   }
                    }
                    incr j
                    if {$j==2} then {set j 0}
                }
                $w.text insert end \n
            } else {
                $w.text insert end {   }
                $w.text insert end $value
                $w.text insert end \n
            }
        }
        incr i
        if {$i==2} then {set i 0}
    }
}

proc snap_down3 {w values} {
    set i 0
    foreach value $values {
        if {$i==0} then {
            set first_value $value
        } else {
            set j 0
            foreach val $value {
                if {$j==0} then {
                    $w.text insert end $first_value colour2
                    $w.text insert end {  }
                    $w.text insert end $val colour4
                    $w.text insert end {    }
                } else {
                    set k 0
                    foreach v $val {
                        if {$k==0} then {
                            $w.text insert end $v colour3
                        } else {
                            $w.text insert end { }
                            $w.text insert end $v
                            $w.text insert end {   }
                        }
                        incr k
                        if {$k==2} then {set k 0}
                    }
                    $w.text insert end \n
                }
                incr j
                if {$j==2} then {set j 0}
            }
        }
        incr i
        if {$i==2} then {
            $w.text insert end \n
            set i 0
        }
    }
}
