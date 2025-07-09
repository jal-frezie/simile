# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Layers20131022
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper

    variable planes transform working winId modelInst State

    self {
	method identify {} {
	    return "Multi-layer 2-D display"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	next $modelInst $winTitle

	# menu
	menu $winId.add -tearoff 0
	# bind $winId.add <<MenuSelect>> [list $this LayerReady %W]
	set working(layerTypes) [ListMenuContents .layers.sub2]
	set newAdd .layer[UniqueId type]
	ReconstituteMenu $newAdd $working(layerTypes) $newAdd
	$winId.add add cascade -label [tr. "New layer here"] \
	    -menu $newAdd
	menu $winId.edit -tearoff 0
	$winId.edit add command -label [tr. "Move to top"] \
	    -command [namespace code [list my TweakLayer MoveCurrentToTop]]
	$winId.edit add command -label [tr. "Move up a level"] \
	    -command [namespace code [list my TweakLayer MoveUpALevel]]
	$winId.edit add command -label [tr. "Move down a level"] \
	    -command [namespace code [list my TweakLayer MoveDownALevel]]
	$winId.edit add command -label [tr. "Move to bottom"] \
	    -command [namespace code [list my TweakLayer MoveCurrentToBottom]]
	$winId.edit add command -label [tr. "Delete"] \
	    -command [namespace code [list my TweakLayer DeleteCurrent]]
	$winId.edit add command -label [tr. "Properties..."] \
	    -command [namespace code [list my TweakLayer EditCurrent]]
	set working(editActs) [ListMenuContents $winId.edit]
	
        set toolbarItems [list \
			      [list save.gif "Save image" [namespace code [list my SaveAsFile]]] \
			      [list reel.gif "Save video" [namespace code [list my SaveSequence]]] \
			      [list zoomin.gif "Zoom in" [namespace code [list my Zoom 2 2]]] \
			      [list zoomout.gif "Zoom out" [namespace code [list my Zoom 0.5 0.5]]] \
			      [list zoomfit.gif "Zoom to fit" [namespace code [list my Fit]]] \
		[list text.gif "Add text" \
		     [list ::canvasnotes20070919::DialogInMiddle $winId]]]
        ::graphtools::MakeToolBar $winId $toolbarItems

# now create the canvas and sliders
	pack [set vp [frame $winId.viewport]] -fill both -expand true
	pack [frame $winId.viewport.bottom] -side bottom ;# for shape messages
	pack [frame $winId.viewport.bottom.nothing] ;# so above hides after use
        scrollbar $vp.xsc -orient horizontal \
	    -command [list $vp.c xview]
        pack $vp.xsc -side bottom -fill x
        scrollbar $vp.ysc -orient vertical \
	    -command [list $vp.c yview]
        pack $vp.ysc -side right -fill y
        canvas $vp.c -xscrollcommand [namespace code [list my SetWithLegends x]] \
					  -yscrollcommand [namespace code [list my SetWithLegends y]] -bg beige
	::canvasnotes20070919::MakeCanvasAnnotatable $vp.c
			     bind $vp.c <Configure> [namespace code [list my posnLegends]]
        pack $vp.c -fill both -expand true

	set planes {}
	if {[string length $state]} { ;# we are restoring 
	    # set State $state ;# keep it local, rebuild later
	    # local version probably NOT want to be XML...unlike saved...
	    foreach geomer {offx offy zoomx zoomy bounds} val $state {
		set transform($geomer) $val
		lappend State $geomer
	    }
	    $vp.c configure -scrollregion $transform(bounds)
	    foreach {layerType layerState} [lrange $state 5 end] {
		if {$layerType eq "annotation"} {
		    ::canvasnotes20070919::RestoreNotesFromList $vp.c $layerState
		} else {
		    set layerType iotool::[namespace tail $layerType]
		    set layerName [${layerType} identify]
		    set updatedLS [::gen3d1::VerifyVariables [my GetNode] \
				       $layerName $layerState]
		    if {[llength $updatedLS]} {
			if {[catch {my newLayer $layerType 0 $updatedLS}]} {
			    if {[string equal abort \
				     [Query [list iotool_restore_fail \
						 "layer $layerName" \
						 $::errorInfo] \
					  warning helpers {} abort]]} {
				break
			    }
			} else {
			    lappend State $layerType $updatedLS
			}
		    } else {
			tk_messageBox -message "$layerName not restored"
		    }
		}
	    }
	    foreach {l t r b} $transform(bounds) {
		$vp.c xview moveto [expr {($transform(offx)-$l)*1.0/($r-$l)}]
		$vp.c yview moveto [expr {($transform(offy)-$t)*1.0/($b-$t)}]
	    }
	    UpdateByOS
	    my posnLegends
	} else {
	    array set transform {offx 0 offy 0 zoomx 1 zoomy 1}
	    # new instance so request data from model
	    pack [message $vp.bottom.message \
		      -text "Select a plane display tool from the Layers menu"]
	}
    }
    
    method SetWithLegends {axis newLo newHi} {
	set vp $winId.viewport
	foreach {lo hi} [$vp.${axis}sc get] {}
	$vp.${axis}sc set $newLo $newHi
	if {abs($newLo+$hi-$lo-$newHi)>1e-6} return
	# scrollregion changed, zoom proc takes care of legends

	foreach {l t r b} [$vp.c cget -scrollregion] {
	    if {$axis eq "y"} {
		set mag [expr {$b-$t}]
		set tail {0 $motn}
	    } else {
		set mag [expr {$r-$l}]
		set tail {$motn 0}
	    }	    
	    set motn [expr {$mag*($newLo-$lo)}]
	    foreach layer $planes {
		eval {$vp.c move $layer.legend} $tail
	    }
	    eval {$vp.c move instruct} $tail	    
	}
    }

    method LegendFollows {side moveTo newFr} {
	# puts [info level 0]
	set cnv $winId.viewport.c
	foreach {l t r b} [$cnv cget -scrollregion] {}
	if {$side eq "yview"} {
	    set mag [expr {$b-$t}]
	    set tail {0 $motn}
	} else {
	    set mag [expr {$r-$l}]
	    set tail {$motn 0}
	}
	foreach {lo hi} [$cnv $side] {}
	if {$newFr < 0 || $newFr > 1+$lo-$hi} return ;# over limit
	set motn [expr {$mag*($newFr-$lo)}]
	foreach layer $planes {
	    eval {$cnv move $layer.legend} $tail
	}
	eval {$cnv move instruct} $tail
	$cnv $side moveto $newFr
    }

    method customizeAddMenu {bar entry} {
	$bar insert $entry cascade -label Layers -menu $winId.add
	return normal
    }

    # Used to be bound to MenuSelect but was useless on Mac
    # method LayerReady {callr} {
# note it is necessary to pass the calling widget id as it will be a clone of
# $winId.add for arcane reasons known only to the developers of Tk
# 	set chng [$callr index active]
# 	if {$chng ne "none"} {
# 	    set serialActive $chng
# 	    ::RunEnv::PreserveSetup 1 ;# assume state will be updated
# 	}
    # }

    method getCanvas {} {
	return $winId.viewport.c
    }

    method Print {} {
	PrintRandomCanvas [my getCanvas]
    }
    method copyToClipboard {} {
	# if {[string match windows $tcl_platform(platform)]} {
	    CopyCanvasToWindowsClipboard [my getCanvas] 0
	# }
    }

    method locateCascade {parentMenu subMenu} {
	for {set serialActive 0} {$serialActive <= [$parentMenu index end]} \
	    {incr serialActive} {
		if {[$parentMenu entrycget $serialActive -menu] eq $subMenu} {
		    return $serialActive
		}
	    }
	return none
    }

    method GrowMenuList {tgt layerObj} {
	set newActions .layer[UniqueId act]
	ReconstituteMenu $newActions $working(editActs) $newActions
	$winId.add insert $tgt cascade -label [$layerObj getTitle] \
	    -menu $newActions
	set newEntries .layer[UniqueId type]
	ReconstituteMenu $newEntries $working(layerTypes) $newEntries
	$winId.add insert $tgt cascade -label [tr. "New layer here"] \
	    -menu $newEntries
    }
    
    method newLayer {type lvl {state {}}} {
	set id [UniqueId layer]
	pack forget $winId.viewport.bottom.message
	set layerObj [$type create $id $modelInst [self] \
			  $transform(zoomx) $transform(zoomy) $state]
	set putBelow [expr {[llength $planes]-$lvl/2}]
# cannot use 'end' cos it means different things for lindex and linsert!
	set aboveNew [lindex $planes $putBelow]
	if {$state eq {} && $aboveNew ne {}} {
	    $winId.viewport.c lower $id.main [namespace tail $aboveNew].main
	}
	set planes [linsert $planes $putBelow $layerObj]
	my GrowMenuList $lvl $layerObj
	my MarkChanged
    }

    method TweakLayer {action calledFrom} {
	set serialActive [my locateCascade $winId.add $calledFrom]
	set oldIdx [expr {[llength $planes]-1-$serialActive/2}]
	set layerObj [lindex $planes $oldIdx]
	switch $action {
	    MoveCurrentToTop  {
		$winId.viewport.c raise [namespace tail $layerObj].main
		set planes [linsert [lreplace $planes $oldIdx $oldIdx] end \
				$layerObj]
		$winId.add delete $serialActive [incr serialActive]
		my GrowMenuList 0 $layerObj
	    } MoveCurrentToBottom {
		set oldIdx end-[expr {$serialActive/2}]
		set layerObj [lindex $planes $oldIdx]
		$winId.viewport.c lower [namespace tail $layerObj].main
		set planes [linsert [lreplace $planes $oldIdx $oldIdx] 0 \
				$layerObj]
		$winId.add delete $serialActive [incr serialActive]
		my GrowMenuList end $layerObj ;# wrong order?
	    } MoveUpALevel {
		if {$serialActive==1} return ;# already at top
		set planes [linsert [lreplace $planes $oldIdx $oldIdx] \
				$oldIdx+1 $layerObj]
		set subbedObj [lindex $planes $oldIdx]
		$winId.viewport.c raise [namespace tail $layerObj].main \
		    [namespace tail $subbedObj].main
		$winId.add entryconfig $serialActive \
		    -label [$subbedObj getTitle]
		$winId.add entryconfig [expr {$serialActive-2}] \
		    -label [$layerObj getTitle]
	    } MoveDownALevel {
		if {$oldIdx==0} return ;# already at bottom
		set planes [linsert [lreplace $planes $oldIdx $oldIdx] \
				$oldIdx-1 $layerObj]
		set subbedObj [lindex $planes $oldIdx]
		$winId.viewport.c lower [namespace tail $layerObj].main \
		    [namespace tail $subbedObj].main
		$winId.add entryconfig $serialActive \
		    -label [$subbedObj getTitle]
		$winId.add entryconfig [expr {$serialActive+2}] \
		    -label [$layerObj getTitle]
	    } DeleteCurrent {
		set id [lindex $planes $oldIdx]
		$id destroy
		set planes [lreplace $planes $oldIdx $oldIdx]
		$winId.add delete $serialActive [incr serialActive]
	    } EditCurrent {
# space here seems to improve reliability
		[lindex $planes $oldIdx] settings
	    }
	}
	my MarkChanged
    }

    method Click {path} {
    }

    method MarkChanged {} {
	set ::helperTable([my GetNode],keepSetup) 1
    }
    
    method Reset {args} {
	foreach plane $planes {
	    $plane reset
	}
    }
    
    method display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	foreach plane $planes {
	    set ::helperTable(beingCalled) [self] ;# [namespace current]::$plane
	    $plane display $time $dispInt $step
	}
	foreach plane $planes {
	    $winId.viewport.c raise $plane.legend
	}
	$winId.viewport.c raise annotation
	$winId.viewport.c raise instruct

	if {[info exists working(frameNo)]} {
	    set fmt [file extension $working(frameTpt)]
	    set log [format %s%05d%s [file rootname $working(frameTpt)] \
			 [incr working(frameNo)] $fmt]
	    set img [image create photo -format window -data $winId.viewport.c]
	    $img write $log -format [string range $fmt 1 end]
	}
    }

    method prepareSaveString {} {
	set id $winId.viewport.c
	set State [list [$id canvasx 0] [$id canvasy 0] \
		       $transform(zoomx) $transform(zoomy) \
		       [$id cget -scrollregion]] ;# offset zoom and bounds
	foreach layer $planes {
	    # change namespace for back compat
	    lappend State ::similescript::[namespace tail [info object class $layer]] [$layer prepareSaveString]
	}
	set noteList [::canvasnotes20070919::ListNotes $id]
	if {[llength $noteList]} {
	    lappend State annotation $noteList
	}
    }

    method SaveAsFile {} {
	if {[tk windowingsystem] eq "broken"} {
	    # photo load from canvas was broken on Mac so did PostScript instead
	    PostScrog $winId.viewport.c [my GetNode] ps
	} else {
	    # should have dialog to set for options
	    set filename [ChooseFile image.png [tr. "Save image as:"] 1 [my GetNode]]
	    if {[string length $filename]} {
		set fmt [string range [file extension $filename] 1 end]
		if {[lsearch {svg ps} $fmt]>-1} {
		    set ::preSelect $filename
		    PostScrog $winId.viewport.c dummy $fmt
		} else {
		    package require img::window
		    set img [image create photo -format window -data $winId.viewport.c]
		    $img write $filename \
			-format [string range [file extension $filename] 1 end]
		}
	    }
	}
    }

    method SaveSequence {} {
	global iconImages
	package require img::window

	if {[info exists working(frameNo)]} {
	    unset working(frameNo)
	    $winId.bbframe.reel configure -image $iconImages(reel)
	} else {
	    set id $winId.viewport.c
	    set working(frameTpt) \
		[ChooseFile image.gif [tr. "Save image series as:"] 1 [my GetNode]]
	    if {[string length $working(frameTpt)]} {
		set working(frameNo) 0
		$winId.bbframe.reel configure -image $iconImages(noreel)
	    }
	}
    }

    method Zoom {fx fy} {
	set id $winId.viewport.c
# first, find where canvas point at middle ends up
	set ww [winfo width $id]
	set wh [winfo height $id]
#	if {[$id cget -scrollregion] eq {}} {
#	    $id config -scrollregion [list 0 0 $ww $wh]
#	}
	set xfroml [expr {$ww/2}]
	set yfromt [expr {$wh/2}]
	set oldMidX [$id canvasx $xfroml]
	set oldMidY [$id canvasy $yfromt]
	set middleX [expr {$fx*$oldMidX}]
	set middleY [expr {$fy*$oldMidY}]
# update zoom state
	set transform(zoomx) [expr {$fx*$transform(zoomx)}]
	set transform(zoomy) [expr {$fy*$transform(zoomy)}]
# throw a scale command at everything on the canvas
# then contact indiviual layers to sort out stuff like line widths
	foreach layer $planes {
	    $id scale [namespace tail $layer].main 0 0 $fx $fy
	    $layer zoomTo $transform(zoomx) $transform(zoomy) 
	    $id move $layer.legend \
		[expr {$middleX-$oldMidX}] [expr {$middleY-$oldMidY}]
	}
	$id move instruct [expr {$middleX-$oldMidX}] [expr {$middleY-$oldMidY}]
	$id scale annotation 0 0 $fx $fy
# finally scroll so old middle is still in middle
# 	foreach {l t r b} [BboxForGroup $id main] {}
 	foreach side {l t r b} edge [$id cget -scrollregion] \
	    z [list $fx $fy $fx $fy] {
		set $side [expr {$z*$edge}]
	    }
	if {$r-$l<$ww} {
	    set l [expr {($l+$r-$ww)/2}]
	    set r [expr {$l+$ww}]
	}
	if {$b-$t<$wh} {
	    set t [expr {($t+$b-$wh)/2}]
	    set b [expr {$t+$wh}]
	}
	$id config -scrollregion [list $l $t $r $b]
	set newMidX [expr {(($middleX-$xfroml)-$l)/($r-$l)}]
	set newMidY [expr {(($middleY-$yfromt)-$t)/($b-$t)}]
	$id xview moveto $newMidX
	$id yview moveto $newMidY
    }

    method Fit {} {
	set id $winId.viewport.c
	foreach {l t r b} [my BboxForGroup $id main] {}
	$id config -scrollregion [list $l $t $r $b]
	set scale [expr {[winfo width $id]/(0.0+$r-$l)}]
	set vscale [expr {[winfo height $id]/(0.0+$b-$t)}]
	if {$vscale<$scale} {
	    set scale $vscale
	}
	my Zoom $scale $scale
	my posnLegends
    }

    method BboxForGroup {id style} {
	foreach plane $planes {
	    lappend mains [namespace tail $plane].$style
	}
	return [eval {$id bbox} $mains]
    }

    method posnLegends {} {
# all legends must be positioned at once because changing one may change posns
# of others
	set id $winId.viewport.c
	set legendWidth 40

	set l 0
	set t 0
	set r 0
	set b 0
	set w [winfo width $id]
	set h [winfo height $id]
	if {![llength [$id cget -scrollregion]]} {
	    $id configure -scrollregion [list 0 -$h $w 0]
	}

	foreach plane $planes {
	    $id delete $plane.legend
	    set side [$plane getNewLegendSide]
# right...legend will be drawn bottom or right across full width/height
# ..now we have to shove it to its alloted posn
	    if {$side eq "n"} continue
	    $id itemconfigure caption -text [$plane getTitle]
	    switch -regexp $side {
		l|r {
		    set py $t
		    set sx 1
		    set sy [expr {1.0*($h+$b-$t)/$h}]
		    if {$side eq "l"} {
			set px [expr {$l+$legendWidth-$w}]
		    } else {
			set px $r
		    }
		} t|b {
		    set px $l
		    set sy 1
		    set sx [expr {1.0*($w+$r-$l)/$w}]
		    if {$side eq "t"} {
			set py [expr {$t+$legendWidth-$h}]
		    } else {
			set py $b
		    }
		}
	    }
	    $id addtag $plane.legend withtag colour_scale
	    $id dtag colour_scale
	    $id addtag $plane.legend withtag caption
	    $id dtag caption
	    $id move $plane.legend $px $py
	    $id scale $plane.legend [$id canvasx $l] [$id canvasy $t] $sx $sy

	    switch -regexp $side {
		l|t {
		    set $side [expr {[set $side]+$legendWidth}]
		} r|b {
		    set $side [expr {[set $side]-$legendWidth}]
		}
	    }
	}
	set transform(aperture) [list $l $t $r $b]
    }
}
