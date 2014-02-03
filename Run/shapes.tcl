# Simile source code file: Run/shapes.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures to set up the model canvas and for the Customise dialogue.
#
# PutRectangle: standard procedure for creating a rectangle. Arguments are:
#  Handle of canvas to put it on
#  x and y coords of centre
#  diameter (width when normal aspect ratio)
#  Aspect ratio (unity corresponds to 4:3)
#  Caption, to be written in centre

set pi 3.14159
set cornerPts 6
set faceAngle [expr $pi/2/$cornerPts]
set splinePts [expr {2*$cornerPts+1}]

set expansion [expr (1 - cos($faceAngle/2))/2]
for {set pt 1} {$pt < $cornerPts} {incr pt} {
    lappend arcPts [expr 1-(1+$expansion)*cos($faceAngle*$pt)]
}
lappend arcPts [expr 1-$expansion*(1-[lindex $arcPts end])/[lindex $arcPts 0]]

proc GetPoints {lo rad} {
    global arcPts
    foreach pt $arcPts {
        lappend result [expr $lo+$pt*$rad]
    }
    return $result
}

proc GetObjectSize {w type fatness} {
    global looks window_info
    return [expr [Scale $w $looks($window_info($w,top_node),$type,objectsize)]*$fatness/100.0]
}

proc GetLineSize {w type fatness} {
    global looks window_info
    return [expr [Scale $w $looks($window_info($w,top_node),$type,lines)]*$fatness/100.0]
}

proc ScaleRect {w l t r b} {
    return [list [Scale $w $l] [Scale $w $t] [Scale $w $r] [Scale $w $b]]
}

proc PutRectangle { w l t r b extras fatness density colourScheme tagSet} {
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set width [GetLineSize $w compartment $fatness]
    $w create rect $ml $mt $mr $mb -outline {} -tag "$tagSet has_info"
    set stackDepth 0
    $w create line $mr $mt $ml $mt $ml $mb -width $width \
            -tag "$tagSet size_on_this realwidth($width)"

    set decor [expr $extras/10] ;# no decor yet for input param compartments
    set stack [expr $extras-10*$decor]

    while {$stackDepth < $stack} {
        set stackDistance [expr $stackDepth*$width*2]
        set sl [expr $ml+$stackDistance]
        set st [expr $mt+$stackDistance]
        set sr [expr $mr+$stackDistance]
        set sb [expr $mb+$stackDistance]
        $w create line $sr $st $sr $sb $sl $sb -width $width \
                -tag "$tagSet size_on_this realwidth($width)"
        incr stackDepth
    }
    ResetColours $w compartment $density $colourScheme [lindex $tagSet 0]
}

proc PutShape {c l t r b file fatness colourScheme title} {
    global window_info
    set nameList {condition cond creation creation \
                immigration immig reproduction repro loss loss alarm alarm}
    set point [expr [lsearch $nameList $file] + 1]
    set fileName [lindex $nameList $point]
    
    source "../Images/$fileName.cnv"
    set growth [expr {max(0.001,($r-$l)/30.0)}]
# use Inner...we don't need hourglass and the refresh may allow customization
# dialogue to get its threads in a twist
    InnerZoomImage $c unscaled $growth
    $c move unscaled [expr ($l+$r)/2] [expr ($t+$b)/2]
    InnerZoomImage $c unscaled $window_info($c,scale)
    $c addtag $title withtag unscaled
    $c addtag has_info withtag unscaled
    $c dtag unscaled
    
    ResetColours $c channel {} $colourScheme [lindex $title 0]
}

proc PutHexagon { w l t r b stack fatness density colourScheme tagSet} {
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    
    set my [expr ($mt + $mb)/2]
    set m75 [expr ($ml + 3*$mr)/4]
    set m25 [expr (3*$ml + $mr)/4]
    
    set width [GetLineSize $w function $fatness]
    $w create poly $mr $my $m75 $mt $m25 $mt $ml $my $m25 $mb $m75 $mb \
            -width $width -tag "$tagSet size_on_this realwidth($width)"
    ResetColours $w function $density $colourScheme [lindex $tagSet 0]
}


proc PutBowTie { w l t r b fatness density colourScheme tagSet} {
    set width [GetLineSize $w flow $fatness]
    
    set poly [$w create poly 0 0 0 0 -tag "$tagSet bowtie has_info"]
    set line [$w create line 0 0 0 0 -width $width \
	       -tag "$tagSet bowtie realwidth($width)"]
    PositionBowtie $w [list $l $t $r $b] [list $poly $line]
    ResetColours $w flow $density $colourScheme [lindex $tagSet 0]
}

# Circles are drawn as many-hedrons until the bug that stops ovals
# stippling is fixed -- still buggy as hell in TclTk 8.4.6...actually
# not, it just needs outlinestipple as well as stipple -- so its
# rectangles that are buggy? No, I'm drawing the outlines separately
# for them.

# The bugs are in Windows -- if part of an item has a circular border
# it never gets stippled, e.g., if you stipple an arc only the radial
# outline sections will be stippled. Let's hope 8.5 is better.

proc PutCrossedCirc { w l t r b extras fatness density colourScheme tagSet} {
    set width [GetLineSize $w variable $fatness]
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set rad [expr ($mr-$ml)/2]
    set hm [expr $ml+$rad]
    set vm [expr $mt+$rad]

    set p1 [DrawBlob $w $hm $vm [expr 2*$rad+$width] "$tagSet has_info"]

    set style [expr $extras/100]
    set extras [expr $extras-100*$style]
    set generic [list -width $width \
		     -tag "$tagSet size_on_this realwidth($width) has_info"]
    # second approximation to fill
    scan [GetPoints $ml $rad] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
    scan [GetPoints $mt $rad] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
    scan [GetPoints $mr -$rad] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
    scan [GetPoints $mb -$rad] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7

    if {$style} {
	set outer [expr 3*($rad+$width/2)/5+$width/2]
	set ol [expr $hm-$outer]
	set ot [expr $vm-$outer]
	set or [expr $hm+$outer]
	set ob [expr $vm+$outer]
	eval {$w create oval $ol $ot $or $ob -outline {}} $generic
#	scan [GetPoints $ol $outer] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
#	scan [GetPoints $ot $outer] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
#	scan [GetPoints $or (-$outer)] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
#	scan [GetPoints $ob (-$outer)] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7
	
#	eval {$w create poly $h3 $v3 $h4 $v2 $h5 $v1 $h6 $ot $h8 $v1 $h9 $v2 $h10 $v3 $h11 $v4 $h12 $v5 $or $v6 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h6 $ob $h5 $v12 $h4 $v11 $h3 $v10 $h2 $v9 $h1 $v8 $ol $v6 $h1 $v5 $h2 $v4 $h3 $v3 -outline {}} $generic
	DrawBlob $w $hm $vm [expr 2*($rad+$width/2)/5] "$tagSet has_info"
    } else {
#    set p1 [eval {$w create oval $ml $mt $mr $mb} $generic]

	eval {$w create poly $hm $vm $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt $h8 $v1 $h9 $v2 $h10 $v3 $hm $vm -outline {}} $generic
	eval {$w create poly $hm $vm $h3 $v10 $h4 $v11 $h5 $v12 $h6 $mb $h8 $v12 $h9 $v11 $h10 $v10 $hm $vm -outline {}} $generic
	eval {$w create line $h3 $v10 $h2 $v9 $h1 $v8 \
		  $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt \
		  $h8 $v1 $h9 $v2 $h10 $v3} $generic
    }
    set decor [expr $extras/10]
    set stack [expr $extras-10*$decor]
    
    switch $decor {
	1 {
	    set sl [expr $ml-2*$rad]
	    set sr [expr $mr+2*$rad]
	    set st [expr $mt+$rad/2]
	    set sb [expr $mb-$rad/2]

	    eval {$w create line $sl $st $sl $sb} $generic
	    eval {$w create line $sl $vm $ml $vm} $generic
	    eval {$w create line $mr $vm $sr $vm} $generic
	    eval {$w create line $sr $st $sr $sb} $generic
	} 2 {
	    set st [expr $mt-2*$rad]
	    eval {$w create poly $ml $st $hm $st $ml $vm} $generic
	    eval {$w create line $ml $st $hm $st $ml $vm $ml $st} $generic
	} 3 {
	    set sl [expr $ml+$rad/2]
	    set sr [expr $mr-$rad/2]
	    set st [expr $mt-2*$rad]
	    set sb [expr $mb+2*$rad]

	    eval {$w create line $sl $st $sr $st} $generic
	    eval {$w create line $hm $st $hm $mt} $generic
	    eval {$w create line $hm $mb $hm $sb} $generic
	    eval {$w create line $sl $sb $sr $sb} $generic
	}
    }
	    
    set stackDepth 0
    while {$stackDepth < $stack} {
        set stackDistance [expr $stackDepth*$width*2]
        set stackSide [eval {$w create line $h10 $v3 $h11 $v4 $h12 $v5 $mr $v6 \
                $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 \
                $h6 $mb $h5 $v12 $h4 $v11 $h3 $v10} $generic]
         if {$stackDepth} {
            $w lower $stackSide $p1
            $w move $stackSide $stackDistance $stackDistance
            set p1 $stackSide
        }
        incr stackDepth
    }
    ResetColours $w variable $density $colourScheme [lindex $tagSet 0]
}

proc PutCloud { w l t r b stack fatness density colourScheme tagSet} {
    set width [GetLineSize $w flow $fatness]
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    
    set mtb13 [expr ($mb + 2*$mt)/3]
    set arcTags [concat $tagSet [list size_on_this realwidth($width)]]
    $w create oval $ml $mtb13 [expr (2*$mr + $ml)/3] $mb -outline {} \
            -tag $tagSet
    $w create oval [expr ($mr + 2*$ml)/3] $mtb13 $mr $mb -outline {} \
            -tag $tagSet
    $w create oval [expr ($mr + 5*$ml)/6] $mt [expr (5*$mr + $ml)/6] \
            [expr (2*$mb + $mt)/3] -outline {} -tag $tagSet
    $w create arc $ml $mtb13 [expr (2*$mr + $ml)/3] $mb -width $width \
            -style arc -start 120 -extent 210 -tag $arcTags
    $w create arc [expr ($mr + 2*$ml)/3] $mtb13 $mr $mb -width $width \
            -style arc -start 240 -extent 210 -tag $arcTags
    $w create arc [expr ($mr + 5*$ml)/6] $mt [expr (5*$mr + $ml)/6] \
            [expr (2*$mb + $mt)/3] -width $width \
            -style arc -start -10 -extent 225 -tag $arcTags
    ResetColours $w flow $density $colourScheme [lindex $tagSet 0]
}


proc PutRoundedRect {w l t r b stack fatness fillColour fillImage layout \
			  origX origY bgColour inFat colourScheme tagSet} {
    global looks window_info custom
    #puts "drawing submodel with fill $fillColour"
    #    previously had min width of 1 to ensure stack visibility
    #    set width [expr $width0>1?$width0:1]
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    
    if {$mr < $ml} {set temp $mr ; set mr $ml ; set ml $temp}
    if {$mb < $mt} {set temp $mb ; set mb $mt ; set mt $temp}
    
    set shortSide [expr ($mr - $ml)<($mb - $mt) ? ($mr - $ml) : ($mb - $mt)]
    if {$fatness == 0} {
        set cornerDiam 0
    } else {
        set cornerDiam [expr $looks($window_info($w,top_node),submodel,objectsize)*$shortSide/200]
    }
    set cornerRad [expr $cornerDiam/2]
    set h6 [expr $ml+$cornerRad]
    set v6 [expr $mt+$cornerRad]
    set h7 [expr $mr-$cornerRad] 
    set v7 [expr $mb-$cornerRad]
    set il [expr $ml+$cornerDiam]
    set it [expr $mt+$cornerDiam]
    set ir [expr $mr-$cornerDiam] 
    set ib [expr $mb-$cornerDiam]
    # This is the diameter of the rounded corner as fraction of the box width
    
    set width [GetLineSize $w submodel $fatness]
    set dots [expr !$stack] ;# conditional
    set pile [expr $stack==-1] ;# population
    set wedge [expr $stack==-2] ;# per-record
    set wings [expr $stack==-3] ;# from value
    if {$dots} {
        set stack 4
    }
    if {$wedge || $wings} {
	set stack 1
    }
    if {$pile} {
        set stack 2
	set back 2
	set stackSpacing [expr 4*$width]
	set backSpacing [expr -2*$width]
    } else {
	set back 1
	set stackSpacing [expr 2*$width]
	set backSpacing 0
    }
    
    # second approximation to fill
#    scan [GetPoints $ml $cornerRad] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
#    scan [GetPoints $mt $cornerRad] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
#    scan [GetPoints $mr -$cornerRad] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
#    scan [GetPoints $mb -$cornerRad] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7
    
# Now make sure submodel background is behind its contents. Old system
# just assumed everything bagged by the model border was part of it;
# now we are more strict. We find the top background component behind
# the model, and put it just in front of that.

    set tgts [$w find overlapping $ml $v6 $ml $v6] ;# any point on the border
    set stackOn {}
    foreach tgt $tgts {
	if {[string match "*/background/*" [$w gettags $tgt]]} {
	    set stackOn [ExtractPrologName $w $tgt]
	}
    }
    if {![llength $stackOn]} {
	$w addtag target_and_background withtag /base/
    } else {
# you cannot 'and' the submodel id tag with the background tag
# so 'or' it with the inverse...oh yes you can
#	$w addtag target_and_background withtag $stackOn
#	$w addtag not_background withtag $stackOn
#	$w dtag /background/ not_background
#	$w dtag not_background target_and_background
	$w addtag target_and_background withtag $stackOn&&/background/
    }
    
    if {[string equal clear $fillColour]} {
	set fillColour {}
    }
#    set poly [$w create polygon \
#		  $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 \
#		  $h6 $mt $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 $h11 $v4 \
#		  $h12 $v5 $mr $v6 $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 \
#		  $h9 $v11 $h8 $v12 $h7 $mb $h6 $mb $h5 $v12 $h4 $v11 \
#		  $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 -outline {} \
#		  -fill $fillColour -tag "$tagSet /background/"]
# These make up the fill shape
    $w create polygon $ml $v6 $h6 $mt $h7 $mt $mr $v6 \
	$mr $v7 $h7 $mb $h6 $mb $ml $v7 \
	-outline {} -fill $fillColour -tag /new_bg/
    $w create arc $ir $mt $mr $it -start 0 -extent 90 \
		   -style pieslice -outline {} -fill $fillColour -tag /new_bg/
    $w create arc $ml $mt $il $it -start 90 -extent 90 \
		   -style pieslice -outline {} -fill $fillColour -tag /new_bg/
    $w create arc $ml $ib $il $mb -start 180 -extent 90 \
		   -style pieslice -outline {} -fill $fillColour -tag /new_bg/
    $w create arc $ir $ib $mr $mb -start 270 -extent 90 \
		   -style pieslice -outline {} -fill $fillColour -tag /new_bg/
    if {$wedge} {
	$w create polygon $ml $v6 $ml $mt [expr $ml+$cornerRad/4] \
	    $mt [expr {$ml+$cornerRad/8}] [expr {($mt+$v6)/2}] \
	    -outline {} -fill $fillColour -tag /new_bg/
    }
    # Now to stick it behind anything that might be drawn inside
    $w raise /new_bg/ target_and_background
    $w dtag target_and_background
    set stackOn /new_bg/

    if {![string equal none $fillImage]} {
        set poly [$w create image $ml $mt -anchor nw \
                -tag "$tagSet /background/ source($fillImage) posn($layout)"]
        set mw [expr int($mr-$ml)]
        set mh [expr int($mb-$mt)]
        set smbg sm$poly$w
        image create photo $smbg -width $mw -height $mh
        $w itemconfig $poly -image $smbg
        set intRad [expr int($cornerRad)]
        
        FillSmImage $fillImage $layout $smbg $mw $mh $intRad
	# Now to stick it behind anything that might be drawn inside
	$w raise $poly $stackOn
	set stackOn $poly
    }

    if {$wedge} {
	$w create line $ml $v6 $ml $mt [expr $ml+$cornerRad/4] $mt \
	    [expr {$ml+$cornerRad/8}] [expr {($mt+$v6)/2}] \
	    -width $width -tag /new_bd/
    }
    if {$wings} {
	set mm [expr {($mt+$mb)/2}]
	$w create line [expr {$ml-$cornerRad}] [expr {$mm-$cornerRad}] \
	    [expr {$ml-$cornerRad}] [expr {$mm+$cornerRad}] \
	    -width $width -tag /new_bd/
	$w create line [expr {$mr+$cornerRad}] [expr {$mm-$cornerRad}] \
	    [expr {$mr+$cornerRad}] [expr {$mm+$cornerRad}] \
	    -width $width -tag /new_bd/
	$w create line [expr {$ml-$cornerRad}] $mm $ml $mm \
	    -width $width -tag /new_bd/
	$w create line [expr {$mr+$cornerRad}] $mm $mr $mm \
	    -width $width -tag /new_bd/
    }
    foreach tag [concat $tagSet /background/] {
	$w addtag $tag withtag /new_bg/
    }
    set tabs 0
    while {$tabs < $back} {
	if {$tabs} {
	    $w dtag /new_bd/ /encs/
	    $w move /new_bd/ $backSpacing $backSpacing
	}
	$w create arc $ml $ib $il $mb -start 180 -extent 45 \
	    -style arc -width $width -tag "/new_bd/ /encs/"
	$w create line $ml $v7 $ml $v6 -width $width -tag "/new_bd/ /encs/"
	$w create arc $ml $mt $il $it -start 90 -extent 90 \
	    -style arc -width $width -tag "/new_bd/ /encs/"
	$w create line $h6 $mt $h7 $mt -width $width -tag "/new_bd/ /encs/"
	$w create arc $ir $mt $mr $it -start 45 -extent 45 \
	    -style arc -width $width -tag "/new_bd/ /encs/"
        incr tabs
    }
    set tabs 0
    while {$tabs < $stack} {
        if {$dots && $tabs} {
            $w create line $mr [expr $mt + $cornerRad] \
                    [expr $mr + $width] [expr $mt + $cornerRad + $width] \
                    -width $width -tag "$tagSet realwidth($width)"
            $w create line $mr [expr $mb - $cornerRad] \
                    [expr $mr + $width] [expr $mb - $cornerRad + $width] \
                    -width $width -tag "$tagSet realwidth($width)"
            $w create line [expr $ml + $cornerRad] $mb \
                    [expr $ml + $cornerRad + $width] [expr $mb + $width] \
                    -width $width -tag "$tagSet realwidth($width)"
            $w create line [expr $mr - $cornerRad] $mb \
                    [expr $mr - $cornerRad + $width] [expr $mb + $width] \
                    -width $width -tag "$tagSet realwidth($width)"
            set ml [expr $ml + $stackSpacing]
            set mt [expr $mt + $stackSpacing]
            set mr [expr $mr + $stackSpacing]
            set mb [expr $mb + $stackSpacing]
        } else {
	    if {$tabs} {
		$w dtag /new_br/ /encs/
		$w move /new_br/ $stackSpacing $stackSpacing
	    }
	    $w create arc $ml $ib $il $mb -start 225 -extent 45 \
		-style arc -width $width -tag "/new_br/ /encs/"
	    $w create line $mr $v7 $mr $v6 -width $width \
			   -tag "/new_br/ /encs/"
	    $w create arc $mr $mb $ir $ib -start 270 -extent 90 \
		-style arc -width $width -tag "/new_br/ /encs/"
	    $w create line $h6 $mb $h7 $mb -width $width \
			   -tag "/new_br/ /encs/"
	    $w create arc $ir $mt $mr $it -start 0 -extent 45 \
		-style arc -width $width -tag "/new_br/ /encs/"
        }
        incr tabs
    }
    
#    if {$pile} {
#        set stackDistance [expr -$stackSpacing]
#        set upper [$w create line $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 \
#                $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt \
#                $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 -width $width \
#		       -tag "$tagSet size_on_this realwidth($width) has_info"]
#        $w move $upper $stackDistance $stackDistance
#        set stackDistance [expr 3*$stackSpacing]
#        set lower [$w create line $h10 $v3 $h11 $v4 $h12 $v5 $mr $v6 \
#                $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h7 $mb \#
#                $h6 $mb $h5 $v12 $h4 $v11 $h3 $v10 -width $width \
#		       -tag "$tagSet size_on_this realwidth($width) has_info"]
#        $w move $lower $stackDistance $stackDistance
#    }

#    MakeSubmodelGrid $w $l $t $r $b $fatness $origX $origY $bgColour
    if {[string equal incomplete $colourScheme] || !$inFat} {
#	set window_info($w,temporary) $i
    } else {
	set plRad [expr $cornerRad/$window_info($w,scale)]
	set nCol [Gradient $bgColour $w]
	set gTagSet "$tagSet /background/ /grid/"
	if {$custom(showgrids,$w)} {
	    set gStat normal
	} else {
	    set gStat hidden
	}

	set flags {-state $gStat -width 0 -fill $nCol -tag $gTagSet}
	set interval [expr [PrefValue custom(gridH) gridH]*$inFat/100.0]
	for {set x [expr $origX+$interval*ceil(($l+1-$origX)/$interval)]} \
	    {$x<$r} {set x [expr $x+$interval]} {
		set fromEdge [expr {max($l+$plRad-$x,$x+$plRad-$r)}]
		if {$fromEdge>0} {
		    set inStep [expr $plRad - sqrt($plRad*$plRad - $fromEdge*$fromEdge)]
		} else {
		    set inStep 0
		}
		set linePts [ScaleRect $w $x ($t+$inStep) $x ($b-$inStep)]
		set line [eval {$w create line} $linePts $flags]
		# Now to stick it behind anything that might be drawn inside
		$w raise $line $stackOn
		set stackOn $line
	    }			    
	set interval [expr [PrefValue custom(gridV) gridV]*$inFat/100.0]
	for {set y [expr $origY+$interval*ceil(($t+1-$origY)/$interval)]} \
	    {$y<$b} {set y [expr $y+$interval]} {
		set fromEdge [expr {max($t+$plRad-$y,$y+$plRad-$b)}]
		if {$fromEdge>0} {
		    set inStep [expr $plRad - sqrt($plRad*$plRad - $fromEdge*$fromEdge)]
		} else {
		    set inStep 0
		}
		set linePts [ScaleRect $w ($l+$inStep) $y ($r-$inStep) $y]
		set line [eval {$w create line} $linePts $flags]
		# Now to stick it behind anything that might be drawn inside
		$w raise $line $stackOn
		set stackOn $line
	    }			    
    }
    $w dtag /new_bg/
    set fullLoad [concat $tagSet "size_on_this realwidth($width) has_info"]
    foreach marker {/new_bd/ /new_br/} {
	foreach tag $fullLoad {
	    $w addtag $tag withtag $marker
	}
	$w dtag $marker
    }
    ResetColours $w submodel {} $colourScheme [lindex $tagSet 0]
}

proc PutThinArrow { w ptz stack fatness density colourScheme tagSet} {
    # Have to use eval because points are packed in a list -- what a language
    set width [GetLineSize $w influence $fatness]
    set features [GetObjectSize $w influence $fatness]
    set mptz [ScaleList $w $ptz]
    eval {$w create line} $mptz {-arrow last \
                -arrowshape [list [expr $features/6] [expr $features/5] \
                [expr $features/16]] -smooth true -splinesteps $::splinePts \
		-width $width -tag "$tagSet realwidth($width) has_info"}
    
    # next few lines put blob with diameter equal to width of
    # arrowhead at start of line
    DrawBlob $w [lindex $mptz 0] [lindex $mptz 1] [expr $features/10] \
            "$tagSet startblob"
# now experimental bit to draw extra lines around middle to indicate stack
    if {$stack>1} {
	foreach level {-9 -3 3 9} {
	    eval {$w create line} [CurveStackEnds $mptz [expr {$level*$width/2.0}]] \
	    {-width $width -tag "$tagSet stackdecor($level)"}
	}
    }
    ResetColours $w influence $density $colourScheme [lindex $tagSet 0]
}

proc PutRelation { w ptz fatness colourScheme tagSet} {
    # Have to use eval because points are packed in a list -- what a language
    set width [expr 5*[GetLineSize $w relation $fatness]]
    set arrowRad [expr [GetObjectSize $w relation $fatness]/10]
    
    set mptz [ScaleList $w $ptz]
    eval {$w create line} $mptz {-arrow last \
                -arrowshape [list $arrowRad [expr 1.5*$arrowRad] $arrowRad] \
                -smooth true -splinesteps $::splinePts -width $width \
				     -tag "$tagSet realwidth($width) has_info"}
    # next few lines put blob with diameter equal to width of arrowhead at start of
    # line
    DrawBlob $w [lindex $mptz 0] [lindex $mptz 1] [expr 2*$arrowRad] \
            "$tagSet startblob"
    ResetColours $w relation gray50 $colourScheme [lindex $tagSet 0]
}

proc PutFatArrow { w ptz stack fatness colourScheme tagSet} {
    set width [expr 5*[GetLineSize $w flow $fatness]]
    set features [GetObjectSize $w flow $fatness]
    #    set width [Scale $w [expr $fatness/10.0]]
    set mptz [ScaleList $w $ptz]
    set arrowRad [expr $features/10]
    eval {$w create line} $mptz {-arrow last -arrowshape \
		[list $arrowRad [expr 1.5*$arrowRad] $arrowRad] -smooth false \
		-width $width -tag "$tagSet realwidth($width) no_stipple has_info"}
    DrawBlob $w [lindex $mptz 0] [lindex $mptz 1] \
		   [expr 2*$arrowRad] "$tagSet no_stipple startblob"
    set stackWidth [expr {$features/50}]
    set stackDepth 2
    while {$stackDepth <= $stack} {
        set stackDistance [expr {$stackDepth*$features/25}]
	set levelLine {}
	foreach pt $mptz {
	    lappend levelLine [expr $pt+$stackDistance]
	}
	$w create line $levelLine -width $stackWidth \
	    -tag [list $tagSet size_on_this realwidth($stackWidth) no_stipple]
        incr stackDepth
    }
    ResetColours $w flow {} $colourScheme [lindex $tagSet 0]
}

# OK now watch carefully. Here we copy a rounded-rect area of an image
# into the submodel background. First copy the image to a temporary one
# the size of the submodel rectangle, so it can be tiled/stretched as
# necessary...

proc FillSmImage {fCol layout smbg mw mh intRad} {
    if {[string equal Scaled $layout]} {
	set fCol [GrowImage $fCol $mw $mh]
	set layout Centred
	set usingSpare 1
    }
    set srcWidth [$fCol cget -width]
    set srcHeight [$fCol cget -height]

    $smbg blank
    # Now copy the middle bit over
    MyTile $smbg $layout $mw $mh 0 $intRad $mw [expr $mh-$intRad] $fCol \
            $srcWidth $srcHeight
    
    # And now the shorter end bits, line by line
    for {set line 0} {$line < $intRad} {incr line} {
        set side [expr int(sqrt($intRad*$intRad - $line*$line))]
        set fl [expr $intRad-$side]
        set fr [expr $mw-$fl]
        set ft [expr $intRad-$line]
        set fb [expr $ft+1]
        MyTile $smbg $layout $mw $mh $fl $ft $fr $fb $fCol $srcWidth $srcHeight
        set ft [expr $mh-$ft]
        set fb [expr $ft+1]
        MyTile $smbg $layout $mw $mh $fl $ft $fr $fb $fCol $srcWidth $srcHeight
    }
    if {[info exists usingSpare]} {
	image delete $fCol
    }
}

proc MyTile {dest pos dw dh l t r b src w h} {
    switch $pos {
	Tiled {
	    for {set qt [expr ($t/$h)*$h]} {$qt < $b} {incr qt $h} {
		if {$qt<$t} {
		    set dt $t
		    set st [expr $t-$qt]
		} else {
		    set dt $qt
		    set st 0
		}
		if {$qt+$h>$b} {
		    set sb [expr $b-$qt]
		} else {
		    set sb $h
		}
		for {set ql [expr ($l/$w)*$w]} {$ql < $r} {incr ql $w} {
		    if {$ql<$l} {
			set dl $l
			set sl [expr $l-$ql]
		    } else {
			set dl $ql
			set sl 0
		    }
		    if {$ql+$w>$r} {
			set sr [expr $r-$ql]
		    } else {
			set sr $w
		    }
		    $dest copy $src -from $sl $st $sr $sb -to $dl $dt
		}
	    }
	} Centred {
	    set osl [expr ($dw-$w)/2] ;# left of source on dest
	    set ost [expr ($dh-$h)/2] ;# top of source on dest
	    
	    set sl [expr {max( 0, $l-$osl)}] ;# left of source area to copy
	    set st [expr {max( 0, $t-$ost)}]
	    set sr [expr {min( $w, $r-$osl)}]
	    set sb [expr {min( $h, $b-$ost)}]

	    if {$sl<=$sr && $st<=$sb} {
		set dl [expr {max($l,$osl)}]
		set dt [expr {max($t,$ost)}]
		$dest copy $src -from $sl $st $sr $sb -to $dl $dt
	    }
	} Scaled {
	    # copy pixel by pixel -- not used, instead image is preprocessed
	    # with zoom/subsample, then displayed centred
	    for {set y $t} {$y<$b} {incr y} {
		set sy [expr $y*$h/$dh]
		for {set x $l} {$x<$r} {incr x} {
		    set sx [expr $x*$w/$dw]
		    $dest copy $src -from $sx $sy [incr sx] [expr $sy+1] \
			-to $x $y
		}
	    }
	}
    }
}

proc MoveText {w id ptz} {
    set mptz [ScaleList $w $ptz]
    set textItem [GetCaptionItem $w $id]
    eval {$w move $textItem} $mptz
    FixBackBox $w $textItem
}

proc MoveObj {w id ptz} {
    set mptz [ScaleList $w $ptz]
    eval {$w move $id} $mptz
}

proc MoveLine {w id ptz} {
    set mptz [ScaleList $w $ptz]
    foreach item [$w find withtag $id] {
        set taglist [$w gettags $item]
        if {[string match *startblob* $taglist]} {
            set x1 [lindex $mptz 0]
            set y1 [lindex $mptz 1]
            $w coords $item $x1 $y1 $x1 $y1
        } elseif {[string match *endblob* $taglist]} {
            set xn [lindex $mptz [expr [llength $mptz] - 2]]
            set yn [lindex $mptz end]
            $w coords $item $xn $yn $xn $yn
	} elseif {[regexp {stackdecor\(([0-9\-]+)\)} $taglist tag level]>0} {
	    set distOff [expr {$level*[$w itemcget $item -width]/2.0}]
            $w coords $item [CurveStackEnds $mptz $distOff]
        } elseif {[string match line [$w type $item]] && \
                    ![string match *bowtie* $taglist]} {
            eval "$w coords $item" $mptz
        }
    }
}

proc CurveStackEnds {mptz distOff} {
    global splinePts
    set fc1 [expr {$splinePts-2}]
    set fc3 [expr {$splinePts+2}]
    set fc4 [expr {$splinePts*2}]
    set fc8 [expr {$splinePts*4}]

    set x1 [expr {($fc3*[lindex $mptz 0] + $fc4*[lindex $mptz 2] + \
		      $fc1*[lindex $mptz 4])/$fc8}]
    set y1 [expr {($fc3*[lindex $mptz 1] + $fc4*[lindex $mptz 3] + \
		      $fc1*[lindex $mptz 5])/$fc8}]
    set x2 [expr {($fc1*[lindex $mptz 0] + $fc4*[lindex $mptz 2] + \
		      $fc3*[lindex $mptz 4])/$fc8}]
    set y2 [expr {($fc1*[lindex $mptz 1] + $fc4*[lindex $mptz 3] + \
		      $fc3*[lindex $mptz 5])/$fc8}]
    set xtent [expr {$x2-$x1}]
    set ytent [expr {$y2-$y1}]
    set len [expr {sqrt($xtent*$xtent + $ytent*$ytent)}]
    set xOff [expr {$ytent/$len}]
    set yOff [expr {-$xtent/$len}]
    return [list [expr {$x1+($distOff+3)*$xOff}] [expr {$y1+($distOff+3)*$yOff}] \
		[expr {$x2+($distOff-3)*$xOff}] [expr {$y2+($distOff-3)*$yOff}]]
}

proc MoveBowtie {w id ptz} {
    foreach item [$w find withtag $id] {
        set taglist [$w gettags $item]
        if {[string match *bowtie* $taglist]} {
            lappend bits $item
	}
    }
    if {[info exists bits]} {
	PositionBowtie $w $ptz $bits
    }
}

proc PositionBowtie {w ptz items} {
    scan [ScaleList $w $ptz] {%f %f %f %f} ml mt mr mb
    if {($mb - $mt) > ($mr - $ml)} {
        set bounds "$ml $mt $mr $mt $ml $mb $mr $mb $ml $mt"
    } else {
        set bounds "$ml $mt $ml $mb $mr $mt $mr $mb $ml $mt"
    }
    foreach item $items {
	eval {$w coords $item} $bounds
    }
}

proc DrawBlob {w startX startY size tags} {
    $w create line $startX $startY $startX $startY -width $size \
            -capstyle round -tag "$tags realwidth($size)"
}

# This puts random bits of normally non-editable text on the screen...

proc PutText { w ptz ptype tagSet fatness specials colourScheme capt } {
    global looks window_info
    
    if {[string equal vflow $ptype]} {
	set type flow
    } else {
	set type $ptype
    }
    set n $window_info($w,top_node)
    if {[string compare $colourScheme normal]} {
        set textColor $looks($n,$type,$colourScheme)
    } else {
        set textColor $looks($n,$type,text)
    }
    
    set fontData [ExtractFontData $looks($n,$type,font)]
    set realFont [Scale $w [lindex $fontData 3]*$fatness/100]
#    if {$realFont<10} {
#        set closeFont 10
#    } else {
#        set closeFont [expr round($realFont)]
#    }
    set useFont [AssembleFont [lindex $fontData 0] [lindex $fontData 1] \
            [lindex $fontData 2] $realFont]
    set textX [Scale $w [expr [lindex $ptz 0] + $looks($n,$type,xoffset)*$fatness/100]]
    set textY [Scale $w [expr [lindex $ptz 1] + $looks($n,$type,yoffset)*$fatness/100]]
# experimental background box for text
    if {$looks($n,$type,txtbg)} {
	set txtbg \#ffffc0
    } else {
	set txtbg {}
    }
    set backBox [$w create rect 0 0 1 1 -outline {} -fill $txtbg \
		     -tag "$tagSet /${type}_text/"]
    $w dtag $backBox editable
    $w dtag $backBox currently_editable
    if {$looks($n,$type,txtbd)} {
	$w create line 0 0 1 1 -fill $textColor -tag [$w gettags $backBox]
    }
    set ankh $looks($n,$type,textanchor)
# rotate clockwise for horizontal flow
    if {![string equal $type $ptype] && ![string equal c $ankh]} {
	set compass {e ne n nw w sw s se e ne}
	set ankh [lindex $compass [expr {[lsearch $compass $ankh]+2}]]
    }
    if {[string match *e $ankh]} {
	set tjust right
    } elseif {[string match *w $ankh]} {
	set tjust left
    } else {
	set tjust center ;# Blooaaargh! Spell it right dudes!
    }
    set textItem [$w create text $textX $textY -text $capt -fill $textColor \
		      -width [expr {$realFont*[lindex $specials 0]}] \
		      -font $useFont -anchor $ankh -justify $tjust \
		      -tag "$tagSet is_caption size_on_this realwidth([expr {$realFont*12.0}]) has_info"]
    FixBackBox $w $textItem
}

# This is called when a new node with a caption is added. The caption should be
# initially selected and editable, but if the mode is not select, nothing else
# should be editable

proc SelectText {w node} {
    global pushedbutton
    set new [GetCaptionItem $w $node]
    if {![llength $new]} {return} ;# item has no text
    if {![string equal select $pushedbutton]} {
	$w dtag currently_editable
	$w itemconfig $new -tag [concat currently_editable [$w gettags $new]]
    }
    focus $w
    $w focus $new
    $w select from $new 0
    $w select to $new end
}

# This procedure colours the symbol outline with the given identifier, by first
# searching for all the graphical components that make it up and then
# either filling or outlining them depending on the method appropriate to their
# type.

proc ColorSymbol { w name type density colorSpec } {
    global looks window_info
    
    set n $window_info($w,top_node)
    if {[string match cloud $type]} {
        set type flow
    }
    if {[string equal influence $type] && [string equal gray50 $density]} {
	set type ghost_link
    }
    if {[string compare $colorSpec normal]} {
        set outlineColor $looks($n,$type,$colorSpec)
        set textColor $outlineColor
    } else {
        set outlineColor $looks($n,$type,outline)
        set textColor $looks($n,$type,text)
    }
    FlashAndStippleSymbol $w $name $outlineColor $textColor $density $colorSpec
}

proc FlashAndStippleSymbol {w name outlineColor textColor density selected} {
    foreach object [$w find withtag $name] {
        switch -regexp [$w type $object] {
            text {$w itemconfigure $object -fill $textColor}
            line {
		if {[string match */*_text/* [$w gettags $object]]} {
		    $w itemconfigure $object -fill $textColor
		} elseif {![string match */background/* [$w gettags $object]]} {
		    $w itemconfigure $object -fill $outlineColor
		}
            } oval {
# clouds have separate arcs too now
#                if {![string match */background/* [$w gettags $object]]} {
#		    $w itemconfigure $object -outline $outlineColor
#		}
            } arc {
		if {[string equal arc [$w itemcget $object -style]] && \
			![string match */background/* [$w gettags $object]]} {
		    $w itemconfigure $object -outline $outlineColor
		}
	    }
        }

	switch -regexp $selected {
	    highlight {
		$w dtag $object tocopy
		$w itemconfigure $object -tag \
		    [concat selected [$w gettags $object]]
	    } select {
		$w itemconfigure $object -tag \
		    [concat tocopy selected [$w gettags $object]]
	    } default {
		$w dtag $object selected
		$w dtag $object tocopy
	    }
	}
	if {[string equal unchanged $density]} {
	    continue
	}
	if {[string equal dashed $density]} {
	    $w itemconfigure $object -dash {-}
	} elseif  {![string match *no_stipple* [$w gettags $object]]} {
	    if {[string equal aqua [tk windowingsystem]]} {
# stippling doesn't work, and crashes PostScript generation, so dash instead
		if {[lsearch {line rectangle arc polygon} \
			 [$w type $object]]>-1} {
		    if {[llength $density]} {
			$w itemconfigure $object -dash {1 3}
		    } else {
			$w itemconfigure $object -dash {}
		    }
		}
	    } else {
		switch -regexp [$w type $object] {
		    line {
			$w itemconfigure $object -stipple $density
		    }
		    rectangle|arc|oval|polygon {
			$w itemconfigure $object -outlinestipple $density \
			    -stipple $density
		    }
		}
	    }
        }
    }
}

proc FillSymbol { w name color } {
    foreach object [$w find withtag $name] {
	set tags [$w gettags $object]
	if {[lsearch "rectangle oval polygon" [$w type $object]]!=-1 && \
		![string match *_text/* $tags] && \
		![string match */background/* $tags]} {
	    $w itemconfigure $object -fill $color
        }
    }
}

proc ResetColours { w type density colourScheme name } {
    global looks window_info
    
    set n $window_info($w,top_node)
    ColorSymbol $w $name $type $density $colourScheme
    set fillColor $looks($n,$type,fill)
    FillSymbol $w $name $fillColor
}

proc ColourExists {col} {
    if {[catch {winfo rgb . $col}]} {
	return 0
    } else {
	return 1
    }
}

proc CanvasDefBG {} {
    switch [PrefValue custom(defBackground) defBackground] \
	[list [tr. {White}] {
	    return white
	} [tr. {Black}] {
	    return black
	} default {
	    return clear
	}
	]
}

proc CanvasSavesSelected {} {
    if {[string equal [tr. {Canvas file}] \
	     [PrefValue custom(saveExtras) saveExtras]]} {
	return 1
    } else {
	return 0
    }
}

# adapted from Welch p265
proc WriteDesc {canvas canvasFile date args} {
    global window_info
    
    set stream [NetOpen $canvasFile w]
    fconfigure $stream -translation lf
    set title [wm title [winfo parent $canvas]]
    puts $stream "# written on $date"
#    puts $stream [list array set looks [array get looks *,*]]
# needs special to preserve top-level node name...like this
    puts $stream [concat LoadModelLooks \$c \
		      [list [MakeLooksSaver $window_info($canvas,top_node)]]]
    puts $stream [concat TweakWindow \$c \{$title\} \
            $window_info($canvas,scale) \
            [$canvas cget -scrollregion] clear $args]
# Now make sure Prolog knows the screen extent of what is loaded
    puts $stream [concat ResizeDesktop \$c [$canvas cget -scrollregion]]
    # background colour parameter now ignored because the background is
    # a rectangle and as such is listed in the .cnv file...not...
    foreach object [$canvas find all] {
        # Insert special command to re-create any photos used
        if {[string match image [$canvas type $object]]} {
	    set tags [$canvas gettags $object]
            regexp {source\(([^\)]+)\)} $tags all sourceImage
            if {![regexp {posn\(([^\)]+)\)} $tags all posn]} {
		set posn Tiled
	    }
            set localImage [$canvas itemcget $object -image]
            puts $stream [concat MakeImage \$c $sourceImage $localImage \
                    [$localImage cget -width] [$localImage cget -height] $posn]
        }
        # Do not write base objs they get re-created...actually do, so I can
	# use diag in helper. Kill after reloading.
#        if {[string match */base/* [$canvas gettags $object]]} {
#        } else {
	set config {}
            foreach conf [$canvas itemconfigure $object] {
                set default [lindex $conf 3]
                set value [lindex $conf 4]
                # Evade grotesque bugs in tk8.3
                if {[string match bezier $value]} {
                    set value 1
                }
                if {[string match $default $value.0]} {
                    set value $default
                }
		# this should allow Unicode to be independent of system
		# encoding. 'Bad' characters also substituted so we can use
		# concat to stop Tcl making it a list member (sensible?)
		if {[string equal -text [lindex $conf 0]]} {
		    # for some reason, breaking next line with \ causes error
		    set config [concat $config [list -text] [EscapeNasties $value]]
		} elseif {[string compare $default $value]} {
		    # Don't bother writing default values
                    lappend config [lindex $conf 0] $value
                }
            }
	    puts $stream [concat \$c create [$canvas type $object] \
			      [$canvas coords $object] $config]
#	}
    }
    close $stream
}

proc MakeImage {c base inst w h args} {
    global looks window_info
    
    set n $window_info($c,top_node)
    #    if {![info exists imageSources($base)]} {
    #	image create photo $base
    #	$base read $file -shrink
    #	PutSize $base
    #	set imageSources($base) $file
    #    }
    image create photo $inst -width $w -height $h
    set shortSide [expr $w<$h?$w:$h]
    set intRad [expr int($looks($n,submodel,objectsize)*$shortSide/400)]
    if {![llength $args]} {
	set args Tiled
    }
    FillSmImage $base $args $inst $w $h $intRad
}

# this is called from Prolog to load/save images with a model. Prolog does not
# know difference between an image and a colour so this has to sort them out

proc ShiftImages {topDir way args} {
    foreach image $args {
        #ShowMess debug info "Moving $image $way" ok
        if {[string compare image none]} {
            set imgFile $topDir/${image}
            switch $way {
                in {
                    image create photo $image
                    foreach fmt {png gif jpeg jpg none} { ;# all but png legacy
                        if {[catch {$image read $imgFile.$fmt -shrink} spew]} {
#			    ShowMess debug info "$spew loading $imgFile.$fmt" ok
			} else {
                            PutSize $image
                            file delete $imgFile
			    break
                        }
                    }
                    # prevent crasho if reading fails
		    if {[string match none $fmt]} {
			$image read ../Images/bigsimile.gif -shrink
			PutSize $image
		    }
                } out {
                    # try gif first, if too many colours try jpeg
#                    foreach fmt {gif jpeg} {
#                        if {![catch {$image write $imgFile.$fmt \
#					 -format $fmt} err]} {
#			    break
#			} else {
#			    puts "Failed to write $imgFile.$fmt -- $err"
#			}
#		    }
		    # ...actually why suffer patent worries when there's .png?
		    $image write $imgFile.png -format png
                }
            }
        }
    }
}

proc GetGhostCursor {} {
    global tcl_platform
    if {[string equal Linux $tcl_platform(os)]} {
	return {@../Images/ghost.xbm ../Images/ghost.mask.xbm black white}
    } else {
	return gumby
    }
}

# this needs because the canvas is called $c in the file

proc InjectGraphics {c canvasFile} {
    global window_info looks
#    set w [expr $window_info($c,width)+4]
#    set h [expr $window_info($c,height)+4]
    source $canvasFile
# following does same thing but allows encoding to happen
# not needed now cos we set system encoding, which source uses
#    set stream [NetOpen $canvasFile r]
#    while {[gets $stream line]>=0} {
#	eval $line
#    }
#    close $stream

    # At this point we may have loaded something with a scrollregion smaller than
    # the current window. In this case TweakWindow (from the .cnv file) will have
    # loaded this region as the new window size, so we 'grow' the window back to
    # its previous size which we saved. The xview and yview cmds here work around
    # a tcl bug that if the scrollregion is smaller than the window it may not all
    # be displayed.
    # $c delete withtag /base/ ;# these may be deleted and re-created
    update idletasks
    CanvasSee $c [lindex [$c find all] end] \
	[expr $window_info($c,width)/2] [expr $window_info($c,height)/2]
# view topmost item
#puts "Rolling back to 0 0 $window_info($c,width) $window_info($c,height)"
    RollBack $c 1 0 0 $window_info($c,width) $window_info($c,height)
    return DoneInjectGraphics
}

proc GetCaptionItem {w name} {
    if {[winfo exists $w]} {
	foreach object [$w find withtag $name] {
	    if {[string compare [$w type $object] text] == 0} {
		set taglist [$w gettags $object]
		if {[string match *is_caption* $taglist]} {
		    return $object
		}
	    }
        }
    }
}

proc GetText { w name } {
    set nameItem [GetCaptionItem $w $name]
    if {[string compare $nameItem {}]} {
        return [$w itemcget $nameItem -text]
    } else {
        return /no_caption/
    }
}

# GetEdit returns the node ID of the canvas item with input focus

proc GetEdit { w } {
    set current [$w focus]
    if {[string compare $current {}]} {
        return [ExtractPrologName $w $current]
    } else {
        return 0
    }
}

proc GoEdit { w comp } {
    $w focus [GetCaptionItem $w $comp]
}

proc EnableEdits { w } {
#    focus $w
    $w addtag currently_editable withtag editable
}

proc DisableEdits { w } {
#    focus [winfo parent $w]
    $w dtag currently_editable
}

proc ChangeObjectTitle { w name title} {
    set capt [GetCaptionItem $w $name]
    $w dchars $capt 0 end
    $w insert $capt end $title
}

# This zooms canvas in or out. Because it cannot be done in response to a
# resize request from Prolog we do not need a special parameter (arg 3) to stop
# Prolog being called back in this instance, because a loop would not happen
# sometimes due to rounding errors.

proc DoZoom { winId factor {invX none} {invY none}} {
    global window_info looks doneZoom

    set width $window_info($winId,width)
    set height $window_info($winId,height)
    # First, find canvas point at centre of zoom action 
    # (default = centre of window)
    if {[string equal none $invX]} {
	set invX [expr $width/2]
    }
    if {[string equal none $invY]} {
	set invY [expr $height/2]
    }
    set target_x [$winId canvasx $invX]
    set target_y [$winId canvasy $invY]
# Mark the centre of the zoom. When doing mousewheel zooms, several ops 
# can fall over each other, so do not re-create marker if already there.
    if {[info exists doneZoom]} {
	after cancel $doneZoom
    } else {
	$winId create line $target_x $target_y $target_x $target_y \
	    -tag /zoom_centre/
    }
    set doneZoom [after 100 DeleteMarker $winId]

    # next make sure that enough canvas exists for the outcome of the operation
    set extraMargin [expr {1/$factor-1}]
    RollBack $winId 1 [expr {$invX-$invX/$factor}] \
	[expr {$invY-$invY/$factor}] \
	[expr {$invX+($width-$invX)/$factor}] \
	[expr {$invY+($height-$invY)/$factor}]

    # Next, scale all the window objects (centre must be 0 because all canvas/desktop
    # translation is done relative to 0)

    ZoomImage $winId all $factor

    # Change the canvas area in accordance with the change in scale

    set oldSize [$winId cget -scrollregion]
    set newL [expr [lindex $oldSize 0]*$factor]
    set newT [expr [lindex $oldSize 1]*$factor]
    set newR [expr [lindex $oldSize 2]*$factor]
    set newB [expr [lindex $oldSize 3]*$factor]
    $winId configure -scrollregion [list $newL $newT $newR $newB]
# no need for the following, RollBack takes care of it
#    eval [list ResizeBackgnd $winId] $newReg

    CanvasSee $winId /zoom_centre/ $invX $invY
    return
}

proc DeleteMarker {winId} {
    $winId delete withtag /zoom_centre/
    unset ::doneZoom
}

# ZoomImage: Scale the graphical stuff in the window, and explicitly
# change line thicknesses, arrowhead sizes and font sizes
# of all components for new display size (Tcl does not change these
# when zooming). Font sizes have a separate parameter to enable them to come
# out right when zooming prior to Postscript export.

proc ZoomImage {args} {
    ShowWatchWhileDoing [concat InnerZoomImage $args]
}

proc InnerZoomImage {winId which factor {optFontor none}} {
    #ShowMess debug info "ZoomImage $winId $which $factor $fontor" ok
    global window_info looks niceSize
    switch [tk windowingsystem] {
	x11 {
	    set hideTinies 40
	} win32 {
	    set hideTinies 6
	} aqua {
	    set hideTinies 6
	}
    }
    set n $window_info($winId,top_node)
    $winId scale $which 0 0 $factor $factor
    if {[string compare $which all]} {
        set objList [$winId find withtag $which]
    } else {
        # and update the info...(if it's there)
        catch {set window_info($winId,scale) \
                    [expr $window_info($winId,scale) * $factor]}

#	scan [$winId cget -scrollregion] "%g %g %g %g" bl bt br bb
        set objList [$winId find all]
    }
    if {[string match none $optFontor]} {
        set fontor $factor
    } else {
        set fontor $optFontor
    }
    foreach object $objList {
	switch [$winId type $object] {
        text {
	    set fontData [ExtractFontData [$winId itemcget $object -font]]
	    set newTextSize [expr round([AdjustWidth $winId $object $fontor])]
#puts "Caption [$winId itemcget $object -text] font $fontData newsize $newTextSize"
	    if {$newTextSize < $hideTinies} {
		$winId itemconfigure $object -state hidden
	    } else {
		$winId itemconfigure $object -font \
		    [AssembleFont [lindex $fontData 0] [lindex $fontData 1] \
			 [lindex $fontData 2] \
			 [expr {round($newTextSize/12.0)}]]
		$winId itemconfigure $object -state normal
	    }
	    set oldWidth [$winId itemcget $object -width]
	    $winId itemconfigure $object -width [expr {$fontor*$oldWidth}]
	    FixBackBox $winId $object
	} line {
	    if {![string match "*/grid/*" [$winId gettags $object]]} {
		set newWidth [AdjustWidth $winId $object $factor]
		set minWidth 0.1
		if {[string match */encs/* [$winId gettags $object]]} {
		    set minWidth 0.01
		}
		if {$hideTinies && $newWidth<$minWidth} {
		    $winId itemconfigure $object -state hidden
		} else {
		    $winId itemconfigure $object -width $newWidth
		    $winId itemconfigure $object -state normal
		}
		AdjustArrow $winId $object $factor
	    }
	} image {
	    set tgtImage [$winId itemcget $object -image]
	    set newWidth [expr round($factor*[$tgtImage cget -width])]
	    set newHt [expr round($factor*[$tgtImage cget -height])]
	    scan [$winId coords $object] {%f %f} newX newY
	    
	    if {[string match "*/base/*" [$winId gettags $object]]} {
	    } elseif {[string compare none $optFontor]} {
# Doing clever stuff with fonts, this zoom op is for a print
# so scale image rather tha re-tiling it
		if {$factor > 1} {
		    image create photo temp
		    temp copy $tgtImage
		    $tgtImage config -width $newWidth -height $newHt
		    $tgtImage copy temp -zoom [expr round($factor)]
		} else {
		    $tgtImage copy $tgtImage \
			-subsample [expr round(1.0/$factor)]
		}
	    } else {
		set shortSide [expr $newWidth<$newHt?$newWidth:$newHt]
		set intRad [expr int($looks($n,submodel,objectsize)* \
					 $shortSide/400)]
		$tgtImage config -width $newWidth -height $newHt
		regexp {source\(([^\)]+)\)} [$winId gettags $object] \
		    all sourceImage
		if {![regexp {posn\(([^\)]+)\)} [$winId gettags $object] \
			  all layout]} {
		    set layout Tiled
		}
		FillSmImage $sourceImage $layout $tgtImage $newWidth $newHt \
		    $intRad
	    }
	} arc {
	    set newWidth [AdjustWidth $winId $object $factor]
	    set minWidth 0.1
	    if {[string match */encs/* [$winId gettags $object]]} {
		set minWidth 0.01
	    }
	    if {$hideTinies && $newWidth<$minWidth} {
		$winId itemconfigure $object -state hidden
	    } else {
		$winId itemconfigure $object -width $newWidth
		$winId itemconfigure $object -state normal
	    }
	}
	}
    }
}

# Used to check that a clicked obj actually shows, and therefore might have been
# the user's intended target
proc Visible {winId obj} {
    if {[string equal hidden [$winId itemcget $obj -state]]} {return 0}
    catch {set mark [$winId itemcget $obj -outline]}
    append mark [$winId itemcget $obj -fill]
    return [string length $mark]
}

# This updates the width of a canvas object when it is zoomed. The actual width
# is rounded internally to an integer, so we store the full value in a tag called
# realwidth(...) which is also updated by this procedure.

# If there is no realWidth tag we try to make one up from the actual line
# width or font size as appropriate.

proc AdjustWidth {winId object factor} {
    if {[regexp {realwidth\(([0-9\.]+)\)} [$winId gettags $object] \
                tag oldWidth]<1} {
        if {[string match text [$winId type $object]]} {
            set currentFont [$winId itemcget $object -font]
            set oldWidth [expr {[font actual $currentFont -size]*12.0}]
        } else {
            set oldWidth [$winId itemcget $object -width]
        }
    } else {
        $winId dtag $object $tag
    }
    set width [expr $oldWidth*$factor]
    $winId addtag realwidth($width) withtag $object
    return $width
}

proc AdjustArrow {winId object factor} {
    set oldArrow [$winId itemcget $object -arrowshape]
    foreach arrowVal $oldArrow {
        lappend newArrow [expr $arrowVal*$factor]
    }
    $winId itemconfigure $object -arrowshape $newArrow
}

proc ZoomBitsIn {winId node factor invx invy args} {
# Contents now passed from prolog, no need to look in region
#    ShowMess debug info "ZBI $winId $node $factor $invx $invy" ok
#    foreach target [$winId find withtag $node] {
#	if {[string equal polygon [$winId type $target]] && \
#		[string match "*/background/*" [$winId gettags $target]]} {
#	    set reejun [$winId bbox $target]
#	}
#    }
#ShowMess debug info "Picked region $reejun" ok
#    eval {$winId addtag /squeeze/ enclosed} $reejun
#    $winId dtag $node /squeeze/
    foreach bit $args {
	$winId addtag /squeeze/ withtag $bit
    }
    set invx [Scale $winId $invx]
    set invy [Scale $winId $invy]
    if {$factor != 1.0} {
	InnerZoomImage $winId /squeeze/ $factor
    }
    $winId move /squeeze/ $invx $invy
    $winId dtag /squeeze/
}

# Move a window's display area to include all its contents
proc DisplayAll { winId } {
    global window_info

    # get desired display area
    if {[scan [$winId bbox size_on_this] "%d %d %d %d" bl bt br bb] == 4} {
        # ShowMess debug info "Bounds are $bl $bt $br $bb" ok
        set clearBorder [expr 15*$window_info($winId,scale)]

        set bl [expr $bl - $clearBorder]
        set bt [expr $bt - $clearBorder]
        set br [expr $br + $clearBorder]
        set bb [expr $bb + $clearBorder]
        set allowScrollBar 0.0 ;# [winfo reqwidth [winfo parent $winId].yscroll]
        # zoom to correct size
	set w [expr {$window_info($winId,width) - $allowScrollBar}]
	set h [expr {$window_info($winId,height) - $allowScrollBar}]
	set keepAspect [expr {!$window_info($winId,is_top_level)}]
        if {$keepAspect} {
# zoom image to smallest size that causes scroll region to fill window
	    set oldReg [$winId cget -scrollregion]
	    set scrollW [expr {[lindex $oldReg 2]-[lindex $oldReg 0]}]
	    set scrollH [expr {[lindex $oldReg 3]-[lindex $oldReg 1]}]
	    set xReScroll [expr {$w/$scrollW}]
	    set yReScroll [expr {$h/$scrollH}]
	    set reScroll [expr {$xReScroll>$yReScroll?$xReScroll:$yReScroll}]
	    set xscale [expr {$reScroll*$scrollW/($br - $bl)}]
	    set yscale [expr {$reScroll*$scrollH/($bb - $bt)}]
	} else {
	    set xscale [expr {$w/($br - $bl)}]
	    set yscale [expr {$h/($bb - $bt)}]
	}
	set scale [expr {$xscale<$yscale ? $xscale : $yscale}]
        # ShowMess debug info "xscale $xscale yscale $yscale scale $scale" ok

        ZoomImage $winId all $scale

        set bl [expr $bl*$scale]
        set bt [expr $bt*$scale]
        set br [expr $br*$scale]
        set bb [expr $bb*$scale]
	if {!$keepAspect} {
# resize desktop to a larger shape that matches the window so it all shows...
# (not if a submodel because that will shrink it in parent diagram)
	    set bw [expr {$br-$bl}]
	    set bh [expr {$bb-$bt}]
	    set overSquare [expr {$bw*$h/$bh/$w}]
#puts "overSquare $overSquare"
	    if {$overSquare<1} {
		set bm [expr {($bl+$br)/2}]
		set bl [expr {$bm-$bw/$overSquare/2}]
		set br [expr {$bm+$bw/$overSquare/2}]
	    } else {
		set bm [expr {($bt+$bb)/2}]
		set bt [expr {$bm-$bh*$overSquare/2}]
		set bb [expr {$bm+$bh*$overSquare/2}]
	    }
	}
        ResizeDesktop $winId $bl $bt $br $bb
    }
}

proc DisplayArea {winId} {
    global window_info looks
    if {[scan [$winId bbox tocopy] "%d %d %d %d" bl bt br bb] < 4} {
        return
    }
    set allowScrollBar [winfo reqwidth [winfo parent $winId].yscroll]
    # zoom to correct size
    set xscale [expr ($window_info($winId,width) - $allowScrollBar)/double($br - $bl)]
    set yscale [expr ($window_info($winId,height) - $allowScrollBar)/double($bb - $bt)]
    set factor [expr $xscale>$yscale?$yscale:$xscale]

    ZoomImage $winId all $factor
    # Change the canvas area in accordance with the change in scale

    set oldSize [$winId cget -scrollregion]
    set newReg [list [expr [lindex $oldSize 0]*$factor] \
            [expr [lindex $oldSize 1]*$factor] \
            [expr [lindex $oldSize 2]*$factor] \
            [expr [lindex $oldSize 3]*$factor]]
    $winId configure -scrollregion $newReg
    eval [list ResizeBackgnd $winId] $newReg

    # First, find canvas point at centre of display
    set CurrentX [$winId canvasx [expr $window_info($winId,width)/2]]
    set CurrentY [$winId canvasy [expr $window_info($winId,height)/2]]

    # Now find canvas point at centre of selected rectangle after zoom
    set centre_x [expr $factor*($bl+$br)/2]
    set centre_y [expr $factor*($bt+$bb)/2]

    # Now scroll it so what should be in the middle of the display is there

    $winId xview scroll [expr round(($centre_x - $CurrentX)/$looks(scrollIncr))] units
    $winId yview scroll [expr round(($centre_y - $CurrentY)/$looks(scrollIncr))] units
}

set adds none

proc FindCaption {canvas} {
    global find
    set findable [GetFindText $canvas]
    if {!$find(done)} return
    set find(List,$canvas) {}
    if {$find(done)==10} {
	#follow infs back
	set find(List,$canvas) \
	    [GetFromProlog tk_get_info('$canvas',selection,in)]
    } elseif {$find(done)==11} {
	#follow infs on
	set find(List,$canvas) \
	    [GetFromProlog tk_get_info('$canvas',selection,none)]
    } elseif {$find(done)==12} {
	#follow infs on
	set find(List,$canvas) \
	    [GetFromProlog tk_get_info('$canvas',selection,out)]
    } elseif {[string compare $findable {}]} {
	set find(List,$canvas) \
	    [GetFromProlog tk_context_find('$canvas','$findable',$find(where))]
#        foreach caption [$canvas find withtag is_caption] {
#	    set toLookIn [BlankCrs [ForSearchType $canvas $caption]]
#            if {[string match -nocase *$findable* $toLookIn]} {
##		puts "Found $findable in $toLookIn"
#                lappend find(List,$canvas) $caption
#            }
#        }
    }
    if {[info exists find(now,$canvas)]} {
	unset find(now,$canvas)
    }
    UpdateAbility $canvas findmore edit "Find next" 1
    NextCaption $canvas
}

proc NextCaption {canvas} {
    global window_info find
    if {[info exists find(now,$canvas)]} {
	prolog tk_do_colours($find(now,$canvas),base)
    } else {
	MenuSelect $canvas edit unselall
    }
    if {![llength $find(List,$canvas)]} {
	Query [list finished_matches $find(where)] info search $canvas ok
        array unset find *,$canvas
	UpdateAbility $canvas findmore edit "Find next" 0
    } else {
        set this [lindex $find(List,$canvas) 0]
        set find(List,$canvas) [lrange $find(List,$canvas) 1 end]
        #	$canvas itemconfigure $this -fill blue
        # left in in case the thing fails to highlight, or is exec_only

	CanvasSee $canvas $this [expr $window_info($canvas,width)/2] \
	    [expr $window_info($canvas,height)/2]
        set find(now,$canvas) $this
	prolog tk_do_colours($find(now,$canvas),seln)
#        FlashSymbol $canvas $find(now,$canvas) orange orange
        #	HandleObjClick $canvas $this clicktext $tgtX $tgtY
        #	ReleaseObj $canvas $tgtX $tgtY
    }
}

proc CanvasSee {canvas this scnX scnY} {
    global window_info

    # Now to pervert the 'scan' command to make an ad-hoc 'see'...
    # note this could also be done using canvas x/yview moveto, but only
    # if the values they return are updated by resizing the window (which
    # the reported width and height aren't).
    
    set middleX [$canvas canvasx $scnX]
    set middleY [$canvas canvasy $scnY]
    scan [$canvas bbox $this] {%d %d %d %d} tgtL tgtT tgtR tgtB
    if {[info exists tgtL]} {
	$canvas scan mark [expr int(-0.1*$middleX)] [expr int(-0.1*$middleY)]
	$canvas scan dragto [expr int(-0.05*($tgtL+$tgtR))] \
	    [expr int(-0.05*($tgtT+$tgtB))]
    } else {
	puts "Missed with $this coords [$canvas coords $this]"
    }
}

# Create image at load time to avoid confusion caused by possible changed directory
# (But then I can't change its colour...)
# set looks(brushmap) [image create bitmap -file brush.xbm]

proc Customize {winId mode} {
    global looks done window_info custom
    
    set n $window_info($winId.canvas,top_node)
    set looks(width) 180
    
    set t [PutItThere .customize $winId]
    wm protocol $t WM_DELETE_WINDOW "set done 0"
    
    switch -regexp $mode {
        condition|creation|immigration|reproduction|loss {
            set object channel
            wm title $t "Customize conditions and channels"
        } select|snap {
            set object generic
            wm title $t "Customize all components"
        } default {
            set object $mode
            wm title $t "Customize $object appearance"
        }
    }
    
    canvas $t.canvas -width [expr $looks(width) + 120] \
            -height [expr $looks(width) + 60]
    set window_info($t.canvas,scale) 1
    set window_info($t.canvas,top_node) $n
    set custom(showgrids,$t.canvas) 1
    pack $t.canvas
    AddGrid $t.canvas [Gradient white $t.canvas]  0 0 \
	[expr $looks(width)+120] [expr $looks(width)+60]

    if {[string compare $object influence]} {
	TitleFrame $t.text -text "Text: "
	set text [GetFrame $t.text]
	label $text.tell \
	    -text "Drag text by chosen anchor to set default position"
	pack $text.tell
        set ts [frame $text.size]
        label $ts.what -text "Text size: "
        pack $ts.what -side left
        scale $ts.scale -from 1 -to 25 -length $looks(width) \
                -orient horizontal -showvalue false -resolution 1 \
                -command "ZotFont $t"
        pack $ts.scale -side left
        pack $ts
        
        set tf [frame $text.font]
        label $tf.what -text "Font: "
        pack $tf.what -side left
        tk_optionMenu $tf.family looks($n,$object,family) \
                helvetica times system courier symbol
        bind $tf.family.menu <Leave> "ZotFont $t 120"
        pack $tf.family -side left
        tk_optionMenu $tf.weight looks($n,$object,weight) \
                bold normal
        bind $tf.weight.menu <Leave> "ZotFont $t 120"
        pack $tf.weight -side left
        tk_optionMenu $tf.style looks($n,$object,style) \
                italic roman
        bind $tf.style.menu <Leave> "ZotFont $t 120"
        pack $tf.style -side left
        pack $tf

	set tb [frame $text.backbox]
	label $tb.bdwhat -text "Show border"
	pack $tb.bdwhat -side left
	set looks(txtbd) $looks($n,$object,txtbd)
	checkbutton $tb.bd -variable looks(txtbd) \
	    -command "ZotObjectSize $t $n $object 0"
	pack $tb.bd -side left
	label $tb.bgwhat -text "Show background"
	pack $tb.bgwhat -side left
	set looks(txtbg) $looks($n,$object,txtbg)
	checkbutton $tb.bg -variable looks(txtbg) \
	    -command "ZotObjectSize $t $n $object 0"
	pack $tb.bg -side left
        button $tb.col -text "Set colour" \
                -command "ZotColor $t $n $tb.col $object"
        pack $tb.col -side left
	pack $tb
	pack $t.text -fill x
    }
    
    if {[string compare $object text]} {
	TitleFrame $t.graphics -text "Graphics: "
	set graphics [GetFrame $t.graphics]
	frame $graphics.setcolours
	foreach flashType {outline fill incomplete} {
	    button $graphics.setcolours.$flashType -text "Set $flashType" \
                -command "ZotColor $t $n $graphics.setcolours.$flashType $object"
	    pack $graphics.setcolours.$flashType -side left
	}
	pack $graphics.setcolours
	pack [frame $graphics.trwhite]
	pack [checkbutton $graphics.trwhite.chk -variable looks($n,trwhite)] -side left
	pack [label $graphics.trwhite.lbl -text "Show white as transparent"] -side left
	
	frame $graphics.flashcolours
	foreach flashType {select highlight target} {
	    button $graphics.flashcolours.$flashType -text "Set $flashType" \
                -command "ZotColor $t $n $graphics.flashcolours.$flashType $object"
	    pack $graphics.flashcolours.$flashType -side left
	}
	pack $graphics.flashcolours
    
	frame $graphics.objectsize
	label $graphics.objectsize.what -text "Relative size: "
	pack $graphics.objectsize.what -side left
	scale $graphics.objectsize.scale -from 0 -to $looks(width) \
            -length $looks(width) -orient horizontal -showvalue false \
            -resolution 1 -command "ZotObjectSize $t $n $object"
	pack $graphics.objectsize.scale -side left
	pack $graphics.objectsize
    
	frame $graphics.lines
	label $graphics.lines.what -text "Line thickness: "
	pack $graphics.lines.what -side left
	scale $graphics.lines.scale -from 0 -to 10 -length $looks(width) \
            -orient horizontal -showvalue false -resolution 0.05 \
            -command "ZotObjectSize $t $n $object"
	pack $graphics.lines.scale -side left
	pack $graphics.lines
	pack $t.graphics -fill x
    }
    
    frame $t.actions
#    button $t.actions.load -text "Load" \
#	-command "ReadLooks $t $n $object"
#    pack $t.actions.load -side left
#    button $t.actions.save -text "Save" \
#	-command "SaveLooks $t $object"
#    pack $t.actions.save -side left
    button $t.actions.normal -text "Normalize" \
	-command "ResetLooks $n $object; LoadLooks $t $n $object"
    pack $t.actions.normal -side left
    button $t.actions.done -text "Done" -command "set done 1"
    pack $t.actions.done -side left
    button $t.actions.apply -text "Apply" \
	-command "ApplyLooks $t $n $object"
    pack $t.actions.apply -side left
    button $t.actions.cancel -text "Cancel" -command "set done 0"
    pack $t.actions.cancel -side left
    pack $t.actions
    LoadLooks $t $n $object
    RememberLooks $n
    
    LetItShow $t
    grab $t
    tkwait variable done
    grab release $t
    if {$done} {
        ApplyLooks $t $n $object
    } else {
        UseLooksSaver $n $looks(safe)
    }
    unset window_info($t.canvas,top_node)
    PackItUp $t
}

proc LoadLooks {t n object} {
    global looks
    
    if {[string compare $object influence]} {
#        puts "ExtractFontData looks($n,$object,font) [ExtractFontData $looks($n,$object,font)]"
	set fontData [ExtractFontData $looks($n,$object,font)]
	set looks($n,$object,family) [lindex $fontData 0]
	set looks($n,$object,weight) [lindex $fontData 1]
	set looks($n,$object,style) [lindex $fontData 2]
	set textsize [lindex $fontData 3]
        [GetFrame $t.text].size.scale set $textsize
	[GetFrame $t.text].backbox.col configure \
	    -activebackground $looks($n,$object,text)
    }
    
    set middlex [expr $looks(width)/2 + 60]
    set middley [expr $looks(width)/2 + 30]
    
    if {[string compare $object text]} {
	set g [GetFrame $t.graphics]
	foreach flash {outline fill incomplete} {
	    set attack $looks($n,$object,$flash)
	    if {![llength $attack]} {
		set attack white
	    }
	    $g.setcolours.$flash configure -activebackground $attack
	}
	foreach flash {select highlight target} {
	    $g.flashcolours.$flash configure -activebackground $looks($n,$object,$flash)
	}
    
	$g.objectsize.scale set $looks($n,$object,objectsize)
	$g.lines.scale set $looks($n,$object,lines)
	set looks(newXOff) $looks($n,$object,xoffset)
	set looks(newYOff) $looks($n,$object,yoffset)
	set looks(captAnchor) $looks($n,$object,captanchor)
	DoGraphics $t $object $middlex $middley $looks($n,$object,objectsize) \
	    $looks(captAnchor)
    } else {
	$t.canvas delete sample
        PutText $t.canvas [list $middlex $middley] \
                text "sample" 100 0 normal "Sample text box"
    }
    $t.canvas configure -background $looks(windowColor)
    #	TweakObject $t target
}

# textsize is not used, we now keep track of it separately to avoid rounding
################################################################################
# proc ExtractFontData {font} {
#     scan $font {-Adobe-%[^-]-%[^-]-%[^-]-Normal--*-%d-*-*-*-*-*-*} \
#         family weight style textsize
#     return [list $family $weight $style $textsize]
#
# }
#
proc ExtractFontData {font} {
    set family [font actual $font -family]
    set weight [font actual $font -weight]
    set style [font actual $font -slant]
    set textsize [font actual $font -size]
    #ShowMess debug info "ExtractFontData [list $family $weight $style $textsize]" ok
    return [list $family $weight $style $textsize]
}

proc CopyLooks {t n object nta} {
    global looks
    if {[string compare $object text]} {
	set g [GetFrame $t.graphics]
	foreach colour {outline fill incomplete} {
	    set looks($n,$object,$colour) \
                [$g.setcolours.$colour cget -activebackground]
	    if {[string equal [Desystematize white] [Desystematize $looks($n,$object,$colour)]] && \
		    $looks($n,trwhite)} {
		set looks($n,$object,$colour) {}
	    }
	}
	foreach colour {select highlight target} {
	    set looks($n,$object,$colour) \
                [$g.flashcolours.$colour cget -activebackground]
	}
	set looks($n,$object,objectsize) [$g.objectsize.scale get]
	set looks($n,$object,lines) [$g.lines.scale get]
	if {[string equal generic $object]} {
	    set looks($n,compartment,lines) [$g.lines.scale get] ;# for sample
	}
    }
    if {[lsearch {influence ghost_link} $object]==-1} {
        set looks($n,$object,font) [ResetFont $t]
        if {[string compare $object text]} {
	    UpdateOffsets $t $n $object $nta
	}
	set looks($n,$object,text) \
	    [[GetFrame $t.text].backbox.col cget -activebackground]
	set looks($n,$object,txtbd) $looks(txtbd)
	set looks($n,$object,txtbg) $looks(txtbg)
    }
}

proc DoGraphics {box type middlex middley size captAnchor} {
    global looks
    $box.canvas delete sample

    switch -regexp $type {
        compartment|generic {
            set l [expr $middlex - 2*$size/5]
            set r [expr $middlex + 2*$size/5]
            set t [expr $middley - 3*$size/10]
            set b [expr $middley + 3*$size/10]
	    PutRectangle $box.canvas $l $t $r $b 1 100 {} normal \
		"sample targetable"
        } state {
            set l [expr $middlex - 3*$size/5]
            set r [expr $middlex + 3*$size/5]
            set t [expr $middley - 2*$size/10]
            set b [expr $middley + 2*$size/10]
	    PutRectangle $box.canvas $l $t $r $b 1 100 {} normal \
		"sample targetable"
        } submodel {
            set l [expr $middlex - 90]
            set r [expr $middlex + 90]
            set t [expr $middley - 60]
            set b [expr $middley + 60]
	    PutRoundedRect $box.canvas $l $t $r $b 3 100 clear \
		none none 0 0 white 100 normal "sample targetable"
	} flow {
            set l [expr $middlex - $size/8]
            set r [expr $middlex + $size/8]
            set t [expr $middley - $size/4]
            set b [expr $middley + $size/4]
            PutBowTie $box.canvas $l $t $r $b 100 {} normal "sample targetable"
#            PutFatArrow $box.canvas "30 [expr $middley-30] $middlex \
#                    [expr $middley - 30] $middlex [expr $middley + 30] \
#                    [expr 2*$middlex - 30] [expr $middley + 30]" \
#                    100 normal "sample"

# Above drew bowtie on vertical section -- do horizontal for easy life
	    PutFatArrow $box.canvas \
		"30 $middley [expr 2*$middlex - 30] $middley" \
		1 100 normal "sample"
        } variable {
            set l [expr $middlex - 3*$size/20]
            set r [expr $middlex + 3*$size/20]
            set t [expr $middley - 3*$size/20]
            set b [expr $middley + 3*$size/20]
	    PutCrossedCirc $box.canvas $l $t $r $b 1 100 {} normal \
		"sample targetable"
        } channel {
            set l [expr $middlex - 3*$size/10]
            set r [expr $middlex + 3*$size/10]
            set t [expr $middley - 3*$size/10]
            set b [expr $middley + 3*$size/10]
	    PutShape $box.canvas $l $t $r $b condition 100 normal \
		"sample targetable"
        } influence {PutThinArrow $box.canvas 1 "30 $middley $middlex \
                    [expr $middley-30] [expr 2*$middlex - 30] $middley" \
                    100 {} normal "sample"
        } ghost_link {PutThinArrow $box.canvas 1 "30 $middley $middlex \
                    [expr $middley-30] [expr 2*$middlex - 30] $middley" \
                    100 gray50 normal "sample"
        } relation {
	    PutRelation $box.canvas "30 $middley $middlex \
                    [expr $middley-30] [expr 2*$middlex - 30] $middley" \
		100 normal "sample"
	    set l [set r $middlex]
	    set t [set b [expr $middley-15]]
	    $box.canvas create rectangle $l $t $r $b -outline {} \
		-tags "targetable" ;# dummy for caption anchor
        }
    }

    if {[info exists b]} {
# side to put caption on -- this is fixed for now, but one day...
	set capt "Sample $type"
	set anchorPt [FindAnchor $l $t $r $b $captAnchor]
# old way of getting anchor
#	switch $type {
#	    submodel {
#		set xbase $l
#		set ybase $t
#	    } flow {
#		set xbase $r
#		set ybase $middley
#		set type vflow ;# text offset as for bowtie on vertical section
#	    } default {
#		set xbase $middlex
#		set ybase $b
#	    }
#	}
        PutText $box.canvas $anchorPt \
                $type "sample movable" 100 0 normal $capt
        $box.canvas bind movable <Button-1> {SampleMark %x %y %W}
        $box.canvas bind movable <B1-Motion> {SampleMove %x %y %W}
# A third binding is required, one that on release will get the bbox of the 
# drawing, find the compass point closest to the drop, and make that the 
# caption anchor. How hard can it be? Let's try --
	$box.canvas bind movable <ButtonRelease-1> {SampleDrop %x %y %W}
    }
}

proc FindAnchor {l t r b captAnchor} {
    switch -regexp $captAnchor {
	nw|w|sw {
	    set ptx $l
	} ne|e|se {
	    set ptx $r
	} n|c|s {
	    set ptx [expr {($l+$r)/2}]
	}
    }
    switch -regexp $captAnchor {
	ne|n|nw {
	    set pty $t
	} se|s|sw {
	    set pty $b
	} e|c|w {
	    set pty [expr {($t+$b)/2}]
	}
    }
    return [list $ptx $pty]
}

# First stab - make generic proc to get compass point nearest action
proc FindClosestCompassPoint {w tgtFlag x y} {
    set textbox [$w bbox $tgtFlag]
    set vline1 [expr (2*[lindex $textbox 0] + [lindex $textbox 2])/3]
    set vline2 [expr ([lindex $textbox 0] + 2*[lindex $textbox 2])/3]
    set hline1 [expr (2*[lindex $textbox 1] + [lindex $textbox 3])/3]
    set hline2 [expr ([lindex $textbox 1] + 2*[lindex $textbox 3])/3]
    
    if {$y < $hline1} {
        set a1 n
    } else {
        if {$y > $hline2} {
            set a1 s
        } else {
            set a1 ""
        }
    }
    
    if {$x < $vline1} {
        set a2 w
    } else {
        if {$x > $vline2} {
            set a2 e
        } else {
            set a2 ""
        }
    }
    
    if {[string compare d$a1 d$a2] == 0} {
        return c
    }
    return $a1$a2
}

proc SampleMark { x y w } {
    # during drag xoffset and yoffset are relative to its start...not any more!
    # now we pick the closest apex to the clicked point, snap to that and then do
    # an absolute drag!
    
    
    set textItem [GetCaptionItem $w sample]
    $w itemconfigure $textItem \
	-anchor [FindClosestCompassPoint $w movable $x $y]
    $w coords $textItem $x $y
    FixBackBox $w $textItem
}

proc SampleMove {x y w} {
    set oldPosn [$w coords [GetCaptionItem $w sample]]
    $w move movable [expr $x-[lindex $oldPosn 0]] [expr $y-[lindex $oldPosn 1]]
}

proc SampleDrop {x y w} {
# update hotspot on component -- need to do after every drop cos user may then
# tweak component size
    global looks

    set looks(captAnchor) [FindClosestCompassPoint $w targetable $x $y]
# now we just have to find out where that is...again I already do it somewhere
    set tgtBox [$w bbox targetable]
    set baseAnchor [eval FindAnchor $tgtBox $looks(captAnchor)]

    set looks(newXOff) [expr {$x-[lindex $baseAnchor 0]}]
    set looks(newYOff) [expr {$y-[lindex $baseAnchor 1]}]
}

proc ResetFont { top } {
    set t [GetFrame $top.text]
    return [AssembleFont [$t.font.family cget -text] \
            [$t.font.weight cget -text] \
            [$t.font.style cget -text] \
            [$t.size.scale get]]
            #[string index [$tf.style cget -text] 0]
}

# proc AssembleFont {family weight style textsize} {
#     return [format "-Adobe-%s-%s-%1s-Normal--*-%d-*-*-*-*-*-*" \
#             $family $weight $style $textsize]
# }
################################################################################

# use -ve (pixel) numbers for font sizes because the tk scaling is already
# built into the canvas scaling?

proc AssembleFont {family weight style textsize} {
    set newFont [list -family $family -weight $weight -slant $style \
		-size [expr {round($textsize)}]]

    return $newFont
}

proc ZotFont { t param } {
    set txt [GetCaptionItem $t.canvas sample]
    $t.canvas itemconfigure $txt -font [ResetFont $t]
    FixBackBox $t.canvas $txt
}

proc ZotColor {t n role type} {
    set newColour [tk_chooseColor -initialcolor \
            [$role cget -activebackground]]
    if {[llength $newColour]} {
	$role configure -activebackground $newColour
	CopyLooks $t $n $type 0
	ResetColours $t.canvas $type {} normal sample
    }
}

proc ZotObjectSize {t n type size} {
    global looks
    

    set middlex [expr $looks(width)/2 + 60]
    set middley [expr $looks(width)/2 + 30]
#    if {[string match generic $type]} {
#        set useLooks compartment
#    } else {
        set useLooks $type
#    }
    
    CopyLooks $t $n $useLooks 0
    if {[string compare text $type]} {
	DoGraphics $t $useLooks $middlex $middley \
	    [[GetFrame $t.graphics].objectsize.scale get] \
	    $looks(captAnchor)
    } else {
	$t.canvas delete sample
        PutText $t.canvas [list $middlex $middley] \
                text "sample" 100 0 normal "Sample text box"
    }
}

proc UpdateOffsets {t n type nta} {
    global looks
# Do not need to update all because it gets called for each on closure --
# actually you do because the baseline (cheat) gets updated on first call
# ... not any more!
#    if {[string equal generic $type]} {
#        foreach object {generic compartment channel function variable \
#			    submodel flow relation} {
#	    set looks($n,$object,xoffset) $looks(newXOff)
#	    set looks($n,$object,yoffset) $looks(newYOff)
#	}
#    } else {
	set looks($n,$type,xoffset) $looks(newXOff)
	set looks($n,$type,yoffset) $looks(newYOff)
#    }
    if {!$nta} {
	set looks($n,$type,textanchor) [GetTextAnchor $t]
	set looks($n,$type,captanchor) $looks(captAnchor)
    }
}

proc GetTextAnchor {t} {
    $t.canvas itemcget [GetCaptionItem $t.canvas sample] -anchor
}

proc ResetLooks {c type} {
    global looks niceSize
    
    set looks($c,$type,font) [AssembleFont Helvetica bold roman $niceSize]
    set looks($c,$type,txtbd) 0
    set looks($c,$type,txtbg) 0
    set looks($c,$type,outline) black
    set looks($c,$type,fill) $looks(buttonColor)
    set looks($c,$type,text) black
    set looks($c,$type,select) blue3
    set looks($c,$type,highlight) green4
    set looks($c,$type,target) green2
#    set looks($type,affect) green2
    set looks($c,$type,incomplete) red3
    
    set looks($c,$type,objectsize) 50
    set looks($c,$type,lines) 1
    set looks($c,$type,xoffset) 0
    set looks($c,$type,yoffset) 0
    set looks($c,$type,textanchor) n
    set looks($c,$type,captanchor) s
#
#
#proc CustomizeLooks {c type} 
#    global looks
#    
    #    prolog tk_set_new_size(compartment,30,0,0)
    #    prolog tk_set_new_size(variable,15,0,0)
    #    prolog tk_set_new_size(function,15,0,0)
    #    prolog tk_set_new_size(cloud,25,0,0)
    #    prolog tk_set_new_size(channel,30,0,0)
    switch $type {
	flow { ;# default is vertical, so...
	    set looks($c,flow,xoffset) 2
	} submodel {
	    set looks($c,submodel,textanchor) sw
	    set looks($c,submodel,captanchor) nw
	} text {
	    set looks($c,text,textanchor) c
	}
    }
}

proc Desystematize {colorSpec} {
    set rgb [winfo rgb . $colorSpec]
    return [format "#%04x%04x%04x" [lindex $rgb 0] \
            [lindex $rgb 1] [lindex $rgb 2]]
}

proc ApplyLooks {t topNode type} {
    RememberLooks $topNode
    if {[string compare $type generic]} {
	CopyLooks $t $topNode $type 0
        ExportLooks $t $topNode $type
    } else {
# add state to next line
        foreach object {generic compartment channel function variable text \
			    ghost_link submodel flow influence relation} {
	    CopyLooks $t $topNode $object [string equal submodel $object]
            ExportLooks $t $topNode $object
        }
    }
}

proc RememberLooks {n} {
    global looks
    set looks(safe) [MakeLooksSaver $n]
}

proc ExportLooks {t topNode type} {
    global looks window_info
    
    prolog [format "tk_change_size(%s,%s,%d,%s)" $topNode $type $looks($topNode,$type,objectsize) $looks($topNode,$type,captanchor)]
    if {[string match flow $type]} {
        prolog [format "tk_change_size(%s,%s,%d,%s)" $topNode cloud $looks($topNode,$type,objectsize) $looks($topNode,$type,captanchor)]
    }
    #	foreach windae [array name window_info *,parent] {
    #		set canvas [string trimright $windae ,parent]
    #	}
}

#proc ReadLooks {t n topNode type} {
#    global looks
#    
#    set customFile [ChooseFile looks.cus "Choose a customization file" 0]
#    set stream [NetOpen $customFile r]
#    
#    while {[gets $stream elementName] >= 0} {
#        gets $stream elementValue
#        if {[string match "$type,*" $elementName] || \
#                    [string compare $type generic] == 0} {
#            set looks($elementName) $elementValue
#        }
#    }
#    
#    close $stream
#    LoadLooks $t $n $type $type
#    if {[string match generic $type]} {
#        foreach object {generic compartment channel function variable text \
#                    submodel flow influence} {
#            ExportLooks $t $topNode $object
#        }
#        destroy $t
#    }
#}

# next needs fix to translate node ids
#proc SaveLooks {t type} {
#    global looks
#    
#    set customFile [ChooseFile looks.cus "Name for customization file" 1]
#    set stream [NetOpen $customFile w]
#    
#    foreach element [array names looks] {
#        puts $stream $element
#        puts $stream $looks($element)
#    }
#    close $stream
#}

proc MakeLooksSaver {n} {
    global looks
# add state to next line
    set objects {generic compartment channel text \
		     variable function submodel flow influence \
		     ghost_link relation}
    set aspects {font txtbd txtbg outline fill text select highlight target \
		     incomplete objectsize lines xoffset yoffset textanchor \
		     captanchor}
    for {set obj 0} {$obj < [llength $objects]} {incr obj} {
	set sublist {}
	for {set asp 0} {$asp < [llength $aspects]} {incr asp} {
	    lappend sublist \
		$looks($n,[lindex $objects $obj],[lindex $aspects $asp])
	}
	lappend result $sublist
    }
    return [list $objects $aspects $result]
}

proc UseLooksSaver {n state} {
    global looks
    set objects [lindex $state 0]
    set aspects [lindex $state 1]
    set values [lindex $state 2]
    for {set obj 0} {$obj < [llength $objects]} {incr obj} {
	set sublist [lindex $values $obj]
	for {set asp 0} {$asp < [llength $aspects]} {incr asp} {
	    set looks($n,[lindex $objects $obj],[lindex $aspects $asp]) \
		[lindex $sublist $asp]
	}
    }
}

proc LoadModelLooks {w state} {
    global looks window_info
    set top $window_info($w,top_node)
    UseLooksSaver $top $state
    foreach type [lindex $state 0] {
# now tell Prolog what we got (but not to redraw) -- normal is legacy
	if {[string equal normal $type]} continue
	prolog [format "tk_set_new_size(%s,%s,%d,%s)" $top $type \
		$looks($top,$type,objectsize) $looks($top,$type,captanchor)]
    }
}

button .b
set looks(buttonColor) [Desystematize [.b cget -bg]]
set looks(windowColor) white
destroy .b

