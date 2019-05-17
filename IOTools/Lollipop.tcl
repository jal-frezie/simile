set keyValue gen3d1

namespace eval ::$keyValue {
    variable useNodes
    variable colours {\#00ff00 \#f1da7e \#36b694 \#ec9844 \#94a646 \#d9d095}

proc identify {} {
	return "Lollipop diagram"
}

proc initialize {winId} {
    variable useNodes
    variable trunks

    namespace import -force ::maptools2::*
    namespace import -force ::canvasnotes20070919::*
    set toolbarItems [list \
			  [list new.gif "Clear" \
			       [namespace code "detach $winId"]] \
			  [list add.gif "Add a variable" \
			       [namespace code "AddVariable $winId"]]\
			  [list text.gif " Add text " \
			       [namespace code "DialogInMiddle $winId"]]]
    
    ::graphtools::MakeToolBar $winId $toolbarItems
    pack [message $winId.intro -aspect 800] -fill x
    variable scaleVector
    array set scaleVector [list $winId,xoff 50 $winId,xmag 150.0 \
			       $winId,yoff 50 $winId,ymag 150.0 \
			       $winId,zoff 25 $winId,zmag 150.0]
    variable viewVector
    set pi 3.14
    array set viewVector [list $winId,angle -0.3 $winId,elevation 0.5 \
			      $winId,cos_angle 1 $winId,cos_elevation 1 \
			      $winId,sin_angle -0.3 $winId,sin_elevation 0.5]
#    scale $winId.elv -orient v -from [expr $pi/2] -to [expr -$pi/2] \
#	-resolution 0.01 \
#	-command [namespace code "TweakScale $winId elevation"]
#    $winId.elv set 0.5
    canvas $winId.c -width 1 -height 1 -bg white
    MakeCanvasAnnotatable $winId.c
#    frame $winId.buttons -relief raised -bd 1
#    pack [label $winId.buttons.anglab -text "View angle:"] -side left
#    scale $winId.buttons.ang -orient h -from -$pi -to $pi \
#	-resolution 0.01 \
#	-command [namespace code "TweakScale $winId angle"]
#    $winId.buttons.ang set -0.3
#    pack $winId.buttons.ang -side left -fill x -expand true
#    pack [label $winId.buttons.elvlab -text "View\nelev."] -side right
#    pack $winId.buttons -side bottom -fill x
#    pack $winId.elv -side right -fill y
    pack $winId.c -fill both -expand true
            
    bind $winId.c <Configure> \
                [namespace code " WindowSizeChanged $winId"]
# New Three.js-style drag controls
    bind $winId.c <Button-1> \
	[namespace code "DropAnchor $winId l %x %y"]
    bind $winId.c <B1-Motion> \
	[namespace code "Haul $winId l %x %y 1"]
    CrossPlatformBind $winId.c [namespace code "DropAnchor $winId r %x %y"] \
	[namespace code "Haul $winId r %x %y 1"]
    BindMouseWheel $winId.c 0 [namespace code "Zoom $winId %D %x %y"]

#Grid is always displayed so only define it once
    DefineGrid $winId 0 100 10 0 100 10 -20 60 20

    SetState $winId initial
    set useNodes($winId,selected) {}
    set useNodes($winId,captions) {}
    set trunks {}
    catch {wm geometry $winId 650x500}
    set viewVector($winId,X) [winfo width $winId.c]
    set viewVector($winId,Y) [winfo height $winId.c]
}

proc GetCanvas {winId} {
    return $winId.c
}

proc clear {winId} {
}

proc detach {winId} {
    variable useNodes
    set useNodes($winId,selected) {}
    set useNodes($winId,captions) {}
    display $winId 0 0 0
    ShowKey $winId
}

proc reset {winId} {
}

proc AddVariable {winId} {
    $winId.intro configure -text "Click on the array value representing the X coordinates of the treelike objects to be displayed."
    GrabClicks $winId
    SetState $winId xcoord
}

proc click {winId node caption} {
    variable useNodes
    set ms $winId.intro
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
	lappend useNodes($winId,selected) $node
	lappend useNodes($winId,captions) $caption
	set state [GetState $winId]
	switch $state {
	    xcoord {
		$ms configure -text "Now click on the value representing the Y coordinates."
		SetState $winId ycoord
	    }
	    ycoord {
		$ms configure -text "Now select a value to display as the size of the objects."
		SetState $winId sizeval
	    }
	    sizeval {
		ReleaseClicks $winId
		$ms configure -text {}
		SaveState $winId
		display $winId 0 0 0
		ShowKey $winId
	    }
	}
    } else {
	$ms configure -text \
	    "This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc SaveState {winId} {
    variable useNodes
    variable viewVector
    set state displaying
    lappend state $viewVector($winId,angle) $viewVector($winId,elevation)
    foreach node $useNodes($winId,selected) {
	lappend state [GetCaptionPathFromId $node]
    }
    lappend state /annotation/ [ListNotes [GetCanvas $winId]]
    SetState $winId $state
}

proc Restore {winId} {
    variable useNodes
    set state [GetState $winId]
    initialize $winId
    if {[string match displaying [lindex $state 0]]} {
#	$winId.buttons.ang set [lindex $state 1]
	set topNode [$::helperTable($winId,whichInstance) GetNode]
	foreach path [lrange $state 3 end] {
	    if {$path eq "/annotation/"} {
		# next entry (currently always last) is note date
		RestoreNotesFromList [GetCanvas $winId] [lindex $state end]
		break
	    }
	    set sortedPath [ExistCheck $topNode $path {} -2 "saved setup"]
	    switch $sortedPath {
		break {
		    error [tr. {Failed to initialize helper}]
		} continue {
		    continue
		} default {
		    set path [lindex $sortedPath 0]
		    set node [lindex $sortedPath 1]
		}
	    }
	    lappend useNodes($winId,selected) $node
	    lappend useNodes($winId,captions) [lindex [split $path /] end]
	}
	variable trunks
	set trunks [LoadPosns $winId]
#	$winId.elv set [lindex $state 2]
    } else {
	GrabClicks $winId
    }
    event generate $winId.c <Configure>
    SaveState $winId
}

#proc TweakScale {winId which where} {
#    variable viewVector
#    set viewVector($winId,$which) $where
#    SaveState $winId
#
#    set viewVector($winId,cos_angle) [expr cos($viewVector($winId,angle))]
#    set viewVector($winId,sin_angle) [expr sin($viewVector($winId,angle))]
#    set viewVector($winId,cos_elevation) \
#	[expr cos($viewVector($winId,elevation))]
#    set viewVector($winId,sin_elevation) \
#	[expr sin($viewVector($winId,elevation))]
#    event generate $winId.c <Configure>
#}
#
proc DropAnchor {winId btn x y} {
    variable curPosn
    set curPosn($winId,x) $x
    set curPosn($winId,y) $y
}

proc Haul {winId btn x y done} {
    variable curPosn
    variable scaleVector
    variable viewVector

    set motnx [expr {1.0*($x-$curPosn($winId,x))/$viewVector($winId,X)}]
    set motny [expr {1.0*($y-$curPosn($winId,y))/$viewVector($winId,Y)}]
    switch $btn {
	l {
	    set viewVector($winId,elevation) \
		[expr {$viewVector($winId,elevation)+$motny}]
	    set viewVector($winId,angle) \
		[expr {$viewVector($winId,angle)+$motnx}]
	    set viewVector($winId,cos_angle) \
		[expr cos($viewVector($winId,angle))]
	    set viewVector($winId,sin_angle) \
		[expr sin($viewVector($winId,angle))]
	    set viewVector($winId,cos_elevation) \
		[expr cos($viewVector($winId,elevation))]
	    set viewVector($winId,sin_elevation) \
		[expr sin($viewVector($winId,elevation))]
	    event generate $winId.c <Configure>
	} r {
	    set scaleVector($winId,xoff) [expr {$scaleVector($winId,xoff)-$scaleVector($winId,xmag)*($motnx*$viewVector($winId,cos_angle)-$motny*$viewVector($winId,sin_angle)*$viewVector($winId,sin_elevation))}]
	    set scaleVector($winId,yoff) [expr {$scaleVector($winId,yoff)+$scaleVector($winId,xmag)*($motnx*$viewVector($winId,sin_angle)+$motny*$viewVector($winId,cos_angle)*$viewVector($winId,sin_elevation))}]
	    set scaleVector($winId,zoff) [expr {$scaleVector($winId,zoff)+$scaleVector($winId,zmag)*$motny*$viewVector($winId,cos_elevation)}]
	    if {$done} {
		event generate $winId.c <Configure>
	    }
	}
    }
    set curPosn($winId,x) $x
    set curPosn($winId,y) $y
}

proc Zoom {winId power scx scy} {
# use pointer location somehow?
    variable scaleVector
    variable viewVector

    set factor [expr 1-$power/100.0]
    set ctrx [expr {$viewVector($winId,X)/2}]
    set ctry [expr {$viewVector($winId,Y)/2}]
    DropAnchor $winId r $scx $scy
    Haul $winId r $ctrx $ctry 0
    foreach axis {x y z} {
	set scaleVector($winId,${axis}mag) \
	    [expr {$factor*$scaleVector($winId,${axis}mag)}]
    }
    Haul $winId r $scx $scy 1
}    
    
proc display {winId time step remainder} {
    variable trunks
    set trunks [LoadPosns $winId]
    $winId.c delete -withtag trunks
    DrawShapes $winId $trunks trunks
}

proc LoadPosns {winId} {
    variable useNodes
    variable colours

    set col 0
    set trunks {}
    foreach {px py h} $useNodes($winId,selected) {
	set quadlist {}
	GetQuadList {} [lindex [GetModelValue $px] 0] \
	    [lindex [GetModelValue $py] 0] \
	    [lindex [GetModelValue $h] 0]
#ShowMess debug info "List is $quadlist" ok
	foreach {id data} $quadlist {
#	    if {![string match nil [lindex $data 0]]} {
		foreach {x y z} $data {}
		if {[llength $id]} {
		    set pop "index: $id"
		} else {
		    set pop {}
		}
		lappend trunks [list line $pop "$x $y 0" \
				    "$x $y $z" 4 brown]
		lappend trunks [list sphere $pop "$x $y [expr 3*$z/2]" \
				    [expr $z/2] 1 [lindex $colours $col]]
#	    }
	}
	incr col
	if {$col==6} {set col 0}
    }
    return $trunks
}

proc DrawGrid {winId tag} {
    variable grid

    DrawShapes $winId $grid($winId) $tag
}

proc DrawShapes {winId solids tag} {
    global cornerPts
    variable viewVector
    variable scaleVector

    set xAsp [expr {$viewVector($winId,X)/$scaleVector($winId,xmag)}]
    set yAsp [expr {$viewVector($winId,Y)/$scaleVector($winId,ymag)}]
    set insts {}
    foreach object3d $solids {
#ShowMess debug info $object3d ok
	switch [lindex $object3d 0] {
	    line {
		# format is "line popupTxt startPt endPt thickness colour"
		set startMap [project $winId [lindex $object3d 2]]
		set endMap [project $winId [lindex $object3d 3]]
		set startx [lindex $startMap 0]
		set starty [lindex $startMap 1]
		set endx [lindex $endMap 0]
		set endy [lindex $endMap 1]
		set squareOnX [expr {pow($endx-$startx,2)}]
		set squareOnY [expr {pow($endy-$starty,2)}]
		if {$squareOnX+$squareOnY==0} continue
		set width [expr {0.3*[lindex $object3d 4]*\
				     ($xAsp*$squareOnY + $yAsp*$squareOnX) / \
				     ($squareOnX+$squareOnY)}]
#ShowMess debug info "$startMap $endMap" ok
		lappend insts [list [list \
		$winId.c create line $startx $starty $endx $endy -width $width \
				 -fill [lindex $object3d 5] -capstyle round \
				 -arrow [lindex $object3d 6] -tag $tag] \
			   [expr ([lindex $startMap 2]+[lindex $endMap 2])/2] \
				   [lindex $object3d 1]]
	    } polygon {
		set ptList {}
		set sumz 0
		foreach pt [lrange $object3d 2 end-2] {
		    set projd [project $winId $pt]
		    lappend ptList [lrange $projd 0 1]
		    set sumz [expr {$sumz+[lindex $projd 2]}]
		}
		set z [expr {$sumz/[llength $ptList]}]
		lappend insts [list [concat $winId.c create poly \
					 [eval concat $ptList] -tag $tag \
					 -outline  [lindex $object3d end-1] \
					 -fill [lindex $object3d end]] $z \
				   [lindex $object3d 1]:$z]
	    } ellipse {
		# format is "ellipse popupTxt centrePt borderPt1 borderPt2
		# thickness backColour frontColour
		set ctr [project $winId [lindex $object3d 2]]
		set bdr1 [project $winId [lindex $object3d 3]]
		set bdr2 [project $winId [lindex $object3d 4]]
		set cx [lindex $ctr 0]
		set cy [lindex $ctr 1]
		set l1 [lindex $bdr1 0]
		set t1 [lindex $bdr1 1]
		set l2 [lindex $bdr2 0]
		set t2 [lindex $bdr2 1]
		if {($l1-$cx)*($t2-$cy)>($l2-$cx)*($t1-$cy)} {
		    set fillColIdx 7
		} else {
		    set fillColIdx 6
		}

		set ptList [list $l1 $t1]
		for {set roll 1} {$roll<4*$cornerPts} {incr roll} {
		    set theta [expr {3.14159*$roll/$cornerPts/2}]
		    set co [expr {cos($theta)}]
		    set si [expr {sin($theta)}]
		    
		    lappend ptList [expr {$cx+($l1-$cx)*$co+($l2-$cx)*$si}]
		    lappend ptList [expr {$cy+($t1-$cy)*$co+($t2-$cy)*$si}]
		}
		lappend ptList $l1 $t1
		lappend insts [list [concat \
		$winId.c create poly $ptList -tag $tag \
		     -width [lindex $object3d 5] -outline black \
					 -fill [lindex $object3d $fillColIdx]] \
				   [lindex $ctr 2] [lindex $object3d 1]]
			       
 	    } sphere {
		set middle [project $winId [lindex $object3d 2]]
		set midx [lindex $middle 0]
		set midy [lindex $middle 1]
		set radX [expr $xAsp*[lindex $object3d 3]]
		set radY [expr $yAsp*[lindex $object3d 3]]
		lappend insts [list [list \
		$winId.c create oval [expr $midx-$radX] [expr $midy-$radY] \
		     [expr $midx+$radX] [expr $midy+$radY] -tag $tag \
		     -width [lindex $object3d 4] -fill [lindex $object3d 5] \
					-stipple [lindex $object3d 6]] \
				   [lindex $middle 2] \
				   [lindex $object3d 1]]
			       
	    } text {
		set middle [project $winId [lindex $object3d 2]]
		set midx [lindex $middle 0]
		set midy [lindex $middle 1]
		lappend insts [list [list \
		$winId.c create text $midx $midy -tag $tag \
		     -text [lindex $object3d 3] -fill [lindex $object3d 4]] \
				   [lindex $middle 2] \
				   [lindex $object3d 1]]
	    }
	}
    }
    set ordered [lsort -decreasing -real -index 1 $insts]
    foreach combo $ordered {
	set canvObj [eval [lindex $combo 0]]
	if {[llength [lindex $combo 2]]} {
	    CanvasBindPopup $winId.c $canvObj [lindex $combo 2]
	}
    }
}

proc applyScale {winId pt3d} {
    variable scaleVector
    return [list [expr {([lindex $pt3d 0]-$scaleVector($winId,xoff))/$scaleVector($winId,xmag)}] \
		[expr {([lindex $pt3d 1]-$scaleVector($winId,yoff))/$scaleVector($winId,ymag)}] \
		[expr {([lindex $pt3d 2]-$scaleVector($winId,zoff))/$scaleVector($winId,zmag)}]]
}

proc project {winId pt3d} {
    variable viewVector
    foreach {ptx pty ptz} [applyScale $winId $pt3d] {}

    set multx $viewVector($winId,cos_angle)
    set multy $viewVector($winId,sin_angle)

    set rotx [expr $multx*$ptx - $multy*$pty]
    set roty [expr -$multx*$pty - $multy*$ptx]

    set multx $viewVector($winId,cos_elevation)
    set multy $viewVector($winId,sin_elevation)

    set scx [expr $viewVector($winId,X)*($rotx + .5)]
    set scy [expr $viewVector($winId,Y)*($multy*$roty + .5 - $multx*$ptz)]
    set depth [expr -$multx*$roty - $multy*$ptz]

#ShowMess debug info "pt3d $pt3d rots $rotx $roty cams $scx $scy $depth" ok
    return [list $scx $scy $depth]
}

proc ShowKey {winId} {
    variable useNodes
    variable colours
    variable viewVector

    set col 0
    set atx 20
    set aty $viewVector($winId,Y)
    
    $winId.c delete -withtag key
    foreach {x y sz} $useNodes($winId,captions) {
	$winId.c create line $atx $aty $atx [expr $aty-16] -width 4 \
	    -fill brown -tag key
	$winId.c create oval [expr $atx-8] [expr $aty-32] [expr $atx+8] \
	    [expr $aty-16] -fill [lindex $colours $col] -tag key
	$winId.c create text [expr $atx+16] $aty -anchor sw -tag key \
	    -text "z: $sz\nx: $x\ny: $y"
	incr col
	incr atx 100
    }
}

proc WindowSizeChanged {winId} {
    variable viewVector
    variable trunks
    set viewVector($winId,X) [winfo width $winId.c]
    set viewVector($winId,Y) [winfo height $winId.c]
#    if {[winfo viewable $winId.c]} {
	$winId.c delete trunks key grid
	if {$viewVector($winId,elevation)>=0} {
	    DrawGrid $winId grid
	}
	DrawShapes $winId $trunks trunks
	if {$viewVector($winId,elevation)<0} {
	    DrawGrid $winId grid
	}
	ShowKey $winId
	$winId.c raise annotation
#    }
}

proc DefineGrid {winId {x0 -50} {xn 50} {xtic 10} \
		     {y0 -50} {yn 50} {ytic 10} \
		     {z0 -40} {zn 40} {ztic 20}} {
    variable scaleVector
    variable grid

    set xh [expr {$x0-0.5*$xtic}]
    set xt [expr {$xn+0.5*$xtic}]
    set yh [expr {$y0-0.5*$ytic}]
    set yt [expr {$yn+0.5*$ytic}]
    set grid($winId) {}
    for {set num [expr {$xtic*ceil($x0/$xtic)}]} {$num <= $xn} \
	    {set num [expr {$num+$xtic}]} {
	set txt [format %-6g $num]
	lappend grid($winId) \
	    [list line "Grid X=$txt" "$num $y0 0" "$num $yn 0" 0 red] \
	    [list text "X posn" "$num $yh 0" $txt red] \
	    [list text "X posn" "$num $yt 0" $txt red]
    }

    for {set num [expr {$ytic*ceil($y0/$ytic)}]} {$num <= $yn} \
	    {set num [expr {$num+$ytic}]} {
	set txt [format %-6g $num]
	lappend grid($winId) \
	    [list line "Grid Y=$txt" "$x0 $num 0" "$xn $num 0" 0 red] \
	    [list text "Y posn" "$xh $num 0" $txt blue] \
	    [list text "Y posn" "$xt $num 0" $txt blue]
    }

    for {set num [expr {$ztic*ceil($z0/$ztic)}]} {$num <= $zn} \
	    {set num [expr {$num+$ztic}]} {
	set txt [format %-6g $num]
	lappend grid($winId) [list text "Z posn" "$x0 $y0 $num" $txt black] \
		[list text "Z posn" "$x0 $yn $num" $txt black] \
		[list text "Z posn" "$xn $yn $num" $txt black] \
		[list text "Z posn" "$xn $y0 $num" $txt black]
	}
}
}
