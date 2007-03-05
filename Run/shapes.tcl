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

proc CustomAs {type} {
    global borrowLooksFor
    foreach {is use} $borrowLooksFor {
        if {[string equal $is $type]} {
            return $use
        }
    }
    return $type
}

proc GetObjectSize {w type fatness} {
    global looks window_info
    set typeScale $looks($window_info($w,top_node),[CustomAs $type],objectsize)
    return [expr $typeScale*$fatness/100.0]
}

proc GetLineSize {w type fatness} {
    global looks window_info
    set typeScale $looks($window_info($w,top_node),[CustomAs $type],lines)
    return [expr $typeScale*$fatness/100.0]
}

proc ScaleRect {w l t r b} {
    return [list [Scale $w $l] [Scale $w $t] [Scale $w $r] [Scale $w $b]]
}

proc RotateList {angle coords} {
    global pi

    set ortho [expr {cos($angle*$pi/180)}]
    set meta [expr {sin($angle*$pi/180)}]
    foreach {x y} $coords {
        lappend out [expr {$ortho*$x+$meta*$y}] [expr {$ortho*$y-$meta*$x}] 
    }
    return $out
}

proc PutRectangle { w id l t r b extras fatness density colourScheme tagSet} {
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set width [GetLineSize $w compartment $fatness]
    set g [GetGroupItem $w $id]
    $w add rectangle $g "$ml $mt $mr $mb" -filled 1 -linewidth 0 \
	-tags "$tagSet has_info"
    set stackDepth 0
    $w add curve $g [list "$mr $mt" "$ml $mt" "$ml $mb"] -linewidth $width \
            -tags "$tagSet size_on_this realwidth($width)"

    set decor [expr $extras/10] ;# no decor yet for input param compartments
    set stack [expr $extras-10*$decor]

    while {$stackDepth < $stack} {
        set stackDistance [expr $stackDepth*$width*2]
        set sl [expr $ml+$stackDistance]
        set st [expr $mt+$stackDistance]
        set sr [expr $mr+$stackDistance]
        set sb [expr $mb+$stackDistance]
        $w add curve $g [list "$sr $st" "$sr $sb" "$sl $sb"] -linewidth $width \
                -tags "$tagSet size_on_this realwidth($width)"
        incr stackDepth
    }
    if {$b-$t>$r-$l} {
        set type state
    } else {
        set type compartment
    }
    ResetColours $w $type $density $colourScheme [lindex $tagSet 0]
}

proc PutShape {c id l t r b file fatness colourScheme title} {
    global window_info
    set g [GetGroupItem $c $id]
    set nameList {condition cond creation creation \
                immigration immig reproduction repro loss loss alarm alarm}
    set point [expr [lsearch $nameList $file] + 1]
    set fileName [lindex $nameList $point]
    
    source "../Images/$fileName.cnv"
    $c translate unscaled [expr ($l+$r)/2] [expr ($t+$b)/2]
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
            -width $width -tags "$tagSet size_on_this realwidth($width)"
    ResetColours $w function $density $colourScheme [lindex $tagSet 0]
}


proc PutBowTie { w n l t r b fatness density colourScheme tagSet} {
    set g [GetGroupItem $w $n]
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set width [GetLineSize $w flow $fatness]
    
    if {($mb - $mt) > ($mr - $ml)} {
        set bounds [list "$ml $mt" "$mr $mt" "$ml $mb" "$mr $mb" "$ml $mt"]
    } else {
        set bounds [list "$ml $mt" "$ml $mb" "$mr $mt" "$mr $mb" "$ml $mt"]
    }
    $w add curve $g $bounds -linewidth $width -filled 1 \
	    -tags "$tagSet bowtie has_info"
    ResetColours $w variable $density $colourScheme [lindex $tagSet 0]
}

# Circles are drawn as many-hedrons until the bug that stops ovals
# stippling is fixed -- still buggy as hell in TclTk 8.4.6...actually
# not, it just needs outlinestipple as well as stipple -- so its
# rectangles that are buggy? No, I'm drawing the outlines separately
# for them.

# The bugs are in Windows -- if part of an item has a circular border
# it never gets stippled, e.g., if you stipple an arc only the radial
# outline sections will be stippled. Let's hope 8.5 is better.

proc PutCrossedCirc { w id l t r b extras fatness density colourScheme tagSet} {
    set width [GetLineSize $w variable $fatness]
    set g [GetGroupItem $w $id]
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set rad [expr ($mr-$ml)/2]
    set hm [expr $ml+$rad]
    set vm [expr $mt+$rad]

    set p1 [DrawBlob $w $g $hm $vm [expr 2*$rad+$width] "$tagSet has_info"]

    set style [expr $extras/100]
    set extras [expr $extras-100*$style]
    # second approximation to fill
    scan [GetPoints $ml $rad] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
    scan [GetPoints $mt $rad] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
    scan [GetPoints $mr -$rad] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
    scan [GetPoints $mb -$rad] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7

    if {$style} {
        set type event
        set outer [expr 3*($rad+$width/2)/5+$width/2]
        set ol [expr $hm-$outer]
        set ot [expr $vm-$outer]
        set or [expr $hm+$outer]
        set ob [expr $vm+$outer]
	$w add arc $g "$ol $ot $or $ob" -extent 359 -linewidth 0 -filled 1 \
	    -tags "$tagSet has_info"
	
#	DrawBlob $w $g $hm $vm [expr 3*($rad+$width/2)/5+$width/2] "$tagSet has_info"
#        scan [GetPoints $ol $outer] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
#        scan [GetPoints $ot $outer] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
#        scan [GetPoints $or (-$outer)] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
#        scan [GetPoints $ob (-$outer)] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7
        
#        eval {$w create poly $h3 $v3 $h4 $v2 $h5 $v1 $h6 $ot $h8 $v1 $h9 $v2 $h10 $v3 $h11 $v4 $h12 $v5 $or $v6 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h6 $ob $h5 $v12 $h4 $v11 $h3 $v10 $h2 $v9 $h1 $v8 $ol $v6 $h1 $v5 $h2 $v4 $h3 $v3 -outline {}} $generic
        DrawBlob $w $g $hm $vm [expr 2*($rad+$width/2)/5] "$tagSet has_info"
    } else {
        set type variable
#    set p1 [eval {$w create oval $ml $mt $mr $mb} $generic]

#        eval {$w create poly $hm $vm $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt $h8 $v1 $h9 $v2 $h10 $v3 $hm $vm -outline {}} $generic
#        eval {$w create poly $hm $vm $h3 $v10 $h4 $v11 $h5 $v12 $h6 $mb $h8 $v12 $h9 $v11 $h10 $v10 $hm $vm -outline {}} $generic
#        eval {$w create line $h3 $v10 $h2 $v9 $h1 $v8 \
                  $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt \
                  $h8 $v1 $h9 $v2 $h10 $v3} $generic
        
        $w add arc $g "$ml $mt $mr $mb" -startangle 45 -extent 90 -pieslice 1 \
	    -linewidth 0 -filled 1 -tags "$tagSet has_info"    
        $w add arc $g "$ml $mt $mr $mb" -startangle 225 -extent 90 \
	    -pieslice 1 -linewidth 0 -filled 1 -tags "$tagSet has_info"    
        set stackSide [$w add arc $g "$ml $mt $mr $mb" -startangle -45 \
			   -extent 359 -filled 0 -linewidth $width \
			   -tags "$tagSet has_info"]
    }
    set decor [expr $extras/10]
    set stack [expr $extras-10*$decor]
    
    switch $decor {
        1 {
            set sl [expr $ml-2*$rad]
            set sr [expr $mr+2*$rad]
            set st [expr $mt+$rad/2]
            set sb [expr $mb-$rad/2]

            $w add curve $g [list "$sl $st" "$sl $sb"] -linewidth $width \
		-tags "$tagSet has_info"
            $w add curve $g [list "$sl $vm" "$ml $vm"] -linewidth $width \
		-tags "$tagSet has_info"
            $w add curve $g [list "$mr $vm" "$sr $vm"] -linewidth $width \
		-tags "$tagSet has_info"
            $w add curve $g [list "$sr $st" "$sr $sb"] -linewidth $width \
		-tags "$tagSet has_info"
        } 2 {
            set st [expr $mt-2*$rad]
            $w add curve $g [list "$ml $st" "$hm $st" "$ml $vm"] -closed 1 \
		-filled 1 -linewidth $width -tags "$tagSet has_info"	    
#            eval {$w create line $ml $st $hm $st $ml $vm $ml $st} $generic
        }
    }

    set stackDepth 0
    while {$stackDepth < $stack} {
        set stackDistance [expr $stackDepth*$width*2]
        set stackSide [$w add arc $g "$ml $mt $mr $mb" -startangle -45 -extent 180 \
			  -filled 0 -linewidth $width -tags "$tagSet has_info"]
         if {$stackDepth} {
            $w lower $stackSide $p1
            $w translate $stackSide $stackDistance $stackDistance
            set p1 $stackSide
        }
        incr stackDepth
    }
    ResetColours $w $type $density $colourScheme [lindex $tagSet 0]
}

proc PutCloud { w id l t r b stack fatness density colourScheme tagSet} {
    set g [GetGroupItem $w $id]
    set width [GetLineSize $w flow $fatness]
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    
    set mtb13 [expr ($mb + 2*$mt)/3]
    $w add arc $g [list $ml $mtb13 [expr (2*$mr + $ml)/3] $mb] \
	-extent 359 -linewidth $width -filled 1 \
	-tags "$tagSet size_on_this"
    $w add arc $g [list [expr ($mr + 2*$ml)/3] $mtb13 $mr $mb] \
	-extent 359 -linewidth $width -filled 1 \
	-tags "$tagSet size_on_this"
    $w add arc $g [list [expr ($mr + 5*$ml)/6] $mt [expr (5*$mr + $ml)/6] \
            [expr (2*$mb + $mt)/3]] -extent 359 -linewidth $width -filled 1 \
	-tags "$tagSet size_on_this"
    ResetColours $w compartment $density $colourScheme [lindex $tagSet 0]
}

proc PutRoundedRect {w n l t r b stack fatness fillColour fillImage layout \
                          colourScheme tagSet} {
    global looks window_info custom
    #puts "drawing submodel with fill $fillColour"
    #    previously had min width of 1 to ensure stack visibility
    #    set width [expr $width0>1?$width0:1]
    
# null dimensions cause crash so...
    if {$l==$r || $t==$b} return
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    
    if {$mr < $ml} {set temp $mr ; set mr $ml ; set ml $temp}
    if {$mb < $mt} {set temp $mb ; set mb $mt ; set mt $temp}
    
    set shortSide [expr ($mr - $ml)<($mb - $mt) ? ($mr - $ml) : ($mb - $mt)]
    if {$fatness == 0} {
        set cornerDiam 0
	set fatness 1 ;# 0 means do not show
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
    set dots [expr $stack==-1]
    set pile [expr $stack==-2]
    if {$dots} {
        set stack 4
    }
    if {$pile} {
        set stack 2
        set back 2
        set stackSpacing [expr 4*$width]
        set backSpacing [expr -2*$width]
    } elseif {$stack} {
        set back 1
        set stackSpacing [expr 2*$width]
        set backSpacing 0
    } else {
        set back 0
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
# so 'or' it with the inverse
        $w addtag target_and_background withtag $stackOn
        $w addtag not_background all
        $w dtag /background/ not_background
        $w dtag not_background target_and_background
    }
    
    if {[string equal clear $fillColour]} {
        set fillColour white
	set filled 0
    } else {
	set filled 1
    }
#    set poly [$w create polygon \
#                  $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 \
#                  $h6 $mt $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 $h11 $v4 \
#                  $h12 $v5 $mr $v6 $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 \
#                  $h9 $v11 $h8 $v12 $h7 $mb $h6 $mb $h5 $v12 $h4 $v11 \
#                  $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 -outline {} \
#                  -fill $fillColour -tags "$tagSet /background/"]
    set g [GetGroupItem $w $n]
    $w add curve $g [list "$ml $v6" "$h6 $mt" "$h7 $mt" "$mr $v6" \
			"$mr $v7" "$h7 $mb" "$h6 $mb" "$ml $v7"] -closed 1 \
	-linewidth 0 -filled $filled -fillcolor $fillColour -tags /new_bg/
    $w add arc $g "$ir $mt $mr $it" -startangle 270 -extent 90 -closed true \
        -linewidth 0 -filled $filled -fillcolor $fillColour -tags /new_bg/
    $w add arc $g "$ml $mt $il $it" -startangle 180 -extent 90 -closed true \
        -linewidth 0 -filled $filled -fillcolor $fillColour -tags /new_bg/
    $w add arc $g "$ml $ib $il $mb" -startangle 90 -extent 90 -closed true \
        -linewidth 0 -filled $filled -fillcolor $fillColour -tags /new_bg/
    $w add arc $g "$ir $ib $mr $mb" -startangle 0 -extent 90 -closed true \
        -linewidth 0 -filled $filled -fillcolor $fillColour -tags /new_bg/
    foreach tag [concat $tagSet /background/] {
        $w addtag $tag withtag /new_bg/
    }

    # Now to stick it behind anything that might be drawn inside
# for some reason the raise command hangs it -- this will all be redone
# once the hierarchy is used so leave it for now
#    $w raise /new_bg/ target_and_background
#    $w dtag target_and_background
    set stackOn /new_bg/

    if {![string equal none $fillImage]} {
        set poly [$w create image $ml $mt -anchor nw \
                -tags "$tagSet /background/ source($fillImage) posn($layout)"]
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

    set tabs 0
    while {$tabs < $back} {
        $w translate /new_bd/ $backSpacing $backSpacing
        $w add arc $g "$ml $ib $il $mb" -startangle 135 -extent 45 \
            -linewidth $width -tags /new_bd/
        $w add curve $g [list "$ml $v7" "$ml $v6"] -linewidth $width -tags /new_bd/
        $w add arc $g "$ml $mt $il $it" -startangle 180 -extent 90 \
            -linewidth $width -tags /new_bd/
        $w add curve $g [list "$h6 $mt" "$h7 $mt"] -linewidth $width -tags /new_bd/
        $w add arc $g "$ir $mt $mr $it" -startangle 270 -extent 45 \
            -linewidth $width -tags /new_bd/
        incr tabs
    }
    set tabs 0
    while {$tabs < $stack} {
        if {$dots && $tabs} {
            $w add curve $g [list "$mr [expr $mt + $cornerRad]" \
		    "[expr $mr + $width] [expr $mt + $cornerRad + $width]"] \
                    -linewidth $width -tags "$tagSet realwidth($width)"
            $w add curve $g [list "$mr [expr $mb - $cornerRad]" \
		    "[expr $mr + $width] [expr $mb - $cornerRad + $width]"] \
                    -linewidth $width -tags "$tagSet realwidth($width)"
            $w add curve $g [list "[expr $ml + $cornerRad] $mb" \
		    "[expr $ml + $cornerRad + $width] [expr $mb + $width]"] \
                    -linewidth $width -tags "$tagSet realwidth($width)"
            $w add curve $g [list "[expr $mr - $cornerRad] $mb" \
                    "[expr $mr - $cornerRad + $width] [expr $mb + $width]"] \
                    -linewidth $width -tags "$tagSet realwidth($width)"
            set ml [expr $ml + $stackSpacing]
            set mt [expr $mt + $stackSpacing]
            set mr [expr $mr + $stackSpacing]
            set mb [expr $mb + $stackSpacing]
        } else {
            $w translate /new_br/ $stackSpacing $stackSpacing
            $w add arc $g "$ml $ib $il $mb" -startangle 90 -extent 45 \
                -linewidth $width -tags /new_br/
            $w add curve $g [list "$mr $v7" "$mr $v6"] -linewidth $width \
		-tags /new_br/
            $w add arc $g "$ir $ib $mr $mb" -startangle 0 -extent 90 \
                -linewidth $width -tags /new_br/
            $w add curve $g [list "$h6 $mb" "$h7 $mb"] -linewidth $width \
		-tags /new_br/
            $w add arc $g "$ir $mt $mr $it" -startangle 315 -extent 45 \
                -linewidth $width -tags /new_br/
        }
        incr tabs
    }
    
#    if {$pile} {
#        set stackDistance [expr -$stackSpacing]
#        set upper [$w create line $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 \
#                $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt \
#                $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 -width $width \
#                       -tags "$tagSet size_on_this realwidth($width) has_info"]
#        $w move $upper $stackDistance $stackDistance
#        set stackDistance [expr 3*$stackSpacing]
#        set lower [$w create line $h10 $v3 $h11 $v4 $h12 $v5 $mr $v6 \
#                $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h7 $mb \#
#                $h6 $mb $h5 $v12 $h4 $v11 $h3 $v10 -width $width \
#                       -tags "$tagSet size_on_this realwidth($width) has_info"]
#        $w move $lower $stackDistance $stackDistance
#    }

    set fullLoad [concat $tagSet "size_on_this realwidth($width) has_info"]
    foreach marker {/new_bd/ /new_br/} {
        foreach tag $fullLoad {
            $w addtag $tag withtag $marker
        }
        $w dtag $marker
    }
# this will hold submodel contents -- must be above backgnd
    if {![catch {GetGroupItem $w [lindex $tagSet 0]} subg]} {
	$w raise $subg $stackOn
    }
    $w dtag /new_bg/
    ResetColours $w submodel {} $colourScheme [lindex $tagSet 0]
}

proc KillGroup {w id} {
    if {![catch {GetGroupItem $w $id} g]} {
	$w remove $g ;# tolerate error, it won't be there if submodel new
    }
}

proc PutGroup {w n id x y f1 f2} {
    set g [$w add group [GetGroupItem $w $n] -tags $id]
    $w translate $g $x $y
    $w scale $g $f1 $f2
}

proc MakeSubmodelGrid {w id l t r b fillColour} {
    global looks window_info custom

    set g [GetGroupItem $w $id]
    $w remove *${g}./grid/ ;# remove old grid using pathtag
    set stackOn $g
    set shortSide [expr ($r - $l)<($b - $t) ? ($r - $l) : ($b - $t)]
    set plRad [expr $looks($window_info($w,top_node),submodel,objectsize)*$shortSide/400]
    set pitch [expr $looks(gridPitch)]

    set nCol [Gradient $fillColour -0.1 $w]
    set gTagSet "realcolour($nCol) /background/ /grid/"
    if {$custom(showgrids,$w)} {
	set gCol $nCol
    } else {
	set gCol {}
    }
    
    for {set x [expr $pitch*floor($l/$pitch+1)]} {$x<$r} {set x [expr $x+$pitch]} {
	set fromEdge [max [expr $l+$plRad-$x] [expr $x+$plRad-$r]]
	if {$fromEdge>0} {
	    set inStep [expr $plRad - sqrt($plRad*$plRad-$fromEdge*$fromEdge)]
	} else {
	    set inStep 0
	}
	set line [$w add curve $g [list "$x [expr $t+$inStep]" "$x [expr $b-$inStep]"] \
		      -linecolor $gCol -tags $gTagSet]
	# Now to stick it behind anything that might be drawn inside
	$w raise $line $stackOn
	set stackOn $line
    }                            
    for {set y [expr $pitch*floor($t/$pitch+1)]} {$y<$b} {set y [expr $y+$pitch]} {
	set fromEdge [max [expr $t+$plRad-$y] [expr $y+$plRad-$b]]
	if {$fromEdge>0} {
	    set inStep [expr $plRad - sqrt($plRad*$plRad-$fromEdge*$fromEdge)]
	} else {
	    set inStep 0
	}
	set line [$w add curve $g [list "[expr $l+$inStep] $y" "[expr $r-$inStep] $y"] \
		      -linecolor $gCol -tags $gTagSet]
	# Now to stick it behind anything that might be drawn inside
	$w raise $line $stackOn
	set stackOn $line
    }                            
}

proc PutInfPin {w x y type dir fatness colourScheme tagSet} {
    set width [GetLineSize $w influence $fatness]
    set features [GetObjectSize $w influence $fatness]
    set mptz [ScaleList $w [list $x $y]]
    set diam [expr {$features/2}]
    set rad [expr {$diam/2}]
    switch $type {
        3 {
            set coords [list 0 $rad $diam 0 0 -$rad]
        } 4 {
            set coords [list 0 $rad $diam $rad $diam -$rad  0 -$rad]
        }
    }
    set screw [expr {90*[lsearch {w s e n} $dir]}]
    set twisted [RotateList $screw $coords]

    eval {$w create poly} $twisted \
        {-width $width -tags "$tagSet realwidth($width) has_info /not_placed/"}
    eval {$w move /not_placed/} $mptz
    $w dtag /not_placed/
}

proc ScaleList {winId clist bend} {
    set output {}
    foreach {eltx elty} $clist {
	set elt [list $eltx $elty]
	if {[llength $output]>0 && [llength $output]<[llength $clist]/2-1 && \
		$bend} {
	    lappend elt c
	}
        lappend output $elt
    }
    return $output
}

proc PutThinArrow { w n ptz fatness density colourScheme tagSet} {
    # Have to use eval because points are packed in a list -- what a language
    set g [GetGroupItem $w $n]
    set width [GetLineSize $w influence $fatness]
    set features [GetObjectSize $w influence $fatness]
    set mptz [ScaleList $w $ptz 1]
    if {[string equal dashed $density]} {
        set density {}
        set dashClause "-dash -"
    } else {
        set dashClause {}
    }
    $w add curve $g $mptz \
	-lastend [list [expr $features/6] [expr $features/5] \
		      [expr $features/16]] -linewidth $width \
	-tags "$tagSet has_info curvy"
    
    # next few lines put blob with diameter equal to width of
    # arrowhead at start of line
    DrawBlob $w $g [lindex $ptz 0] [lindex $ptz 1] [expr $features/10] \
            "$tagSet startblob"
    ResetColours $w influence $density $colourScheme [lindex $tagSet 0]
}

proc PutRelation { w n ptz fatness colourScheme tagSet} {
    # Have to use eval because points are packed in a list -- what a language
    set g [GetGroupItem $w $n]
    set width [expr 5*[GetLineSize $w relation $fatness]]
    set arrowRad [expr [GetObjectSize $w relation $fatness]/10]
    
    set mptz [ScaleList $w $ptz 1]
    $w add curve $g $mptz \
	-lastend [list $arrowRad [expr 1.5*$arrowRad] $arrowRad] -linewidth $width \
	-tags "$tagSet has_info curvy"
     # next few lines put blob with diameter equal to width of arrowhead at start of
    # line
    DrawBlob $w $g [lindex $ptz 0] [lindex $ptz 1] [expr 2*$arrowRad] \
            "$tagSet startblob"
    ResetColours $w relation gray50 $colourScheme [lindex $tagSet 0]
}

proc PutFatArrow { w n ptz fatness colourScheme tagSet} {
    set g [GetGroupItem $w $n]
    set width [expr 5*[GetLineSize $w flow $fatness]]
    set features [GetObjectSize $w flow $fatness]
    #    set width [Scale $w [expr $fatness/10.0]]
    set mptz [ScaleList $w $ptz 0]
    set arrowRad [expr $features/10]
    $w add curve $g $mptz -lastend \
                [list $arrowRad [expr 1.5*$arrowRad] $arrowRad] \
                      -linewidth $width -tags "$tagSet has_info"
    DrawBlob $w $g [lindex $ptz 0] [lindex $ptz 1] [expr 2*$arrowRad] \
            "$tagSet startblob"
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
            
            set sl [max 0 $l-$osl] ;# left of source area to copy
            set st [max 0 $t-$ost]
            set sr [min $w $r-$osl]
            set sb [min $h $b-$ost]

            if {$sl<=$sr && $st<=$sb} {
                set dl [max $l $osl]
                set dt [max $t $ost]
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

proc GrowImage {fCol mw mh} {
    set srcWidth [$fCol cget -width]
    set srcHeight [$fCol cget -height]
#    switch $layout {
#        Scaled {
            # Resize X and Y axes separately to avoid making too large an
            # intermediate image
            set xrat [ChooseIntegerRatio [expr 1.0*$mw/$srcWidth]]
            image create photo spare1
            spare1 copy $fCol -zoom [lindex $xrat 0] 1 -shrink
            image create photo spare2
            spare2 copy spare1 -subsample [lindex $xrat 1] 1 -shrink
            
            set yrat [ChooseIntegerRatio [expr 1.0*$mh/$srcHeight]]
            spare1 blank
            spare1 copy spare2 -zoom 1 [lindex $yrat 0] -shrink
            spare2 blank
            spare2 copy spare1 -subsample 1 [lindex $yrat 1] -shrink
            
            image delete spare1
            # copying does not update image's size parameter -- do it by hand
            set srcWidth [expr $srcWidth*[lindex $xrat 0]/[lindex $xrat 1]]
            set srcHeight [expr $srcHeight*[lindex $yrat 0]/[lindex $yrat 1]]
#        } Tiled {
            # Using builtin tiling is slow when starting from a small image --
            # This version was inspired by the opening titles of Dilbert

    # note that actually tiling is slow because it creates images with
    # complicated transparent areas -- the Dilbert process just slows it
    # down more by adding overheads so has been removed

#            image create photo spare2
#            spare2 copy $fCol
#            while {$srcWidth<$mw} {
#                puts [list spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#                          -to $srcWidth 0]
#                spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#                    -to $srcWidth 0 -compositingrule set
#                set srcWidth [expr 2*$srcWidth]
#            }
#            while {$srcHeight<$mh} {
#                puts [list spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#                          -to 0 $srcHeight]
#                spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#                    -to 0 $srcHeight -compositingrule set
#                set srcHeight [expr 2*$srcHeight]
#            }
#        }
#    }
    spare2 config -width $srcWidth
    spare2 config -height $srcHeight
    return spare2
}

proc ChooseIntegerRatio {fraction} {
    set m 1
    while {1} {
        set d [max round($m/$fraction) 1]
        set close [expr $m/($fraction*$d)]
        if {$close > 0.95 && $close < 1.05} {
            return [list $m $d]
        }
        incr m
    }
}
        
proc MoveText {w id ptz} {
    set textItem [GetCaptionItem $w $id]
    eval {$w translate $textItem} $ptz
    FixBackBox $w $textItem
}

proc MoveObj {w ids ptz} {
    foreach id $ids {
        $w addtag /moving/ withtag $id
    }
    eval {$w translate /moving/} $ptz
    $w dtag /moving/
}

proc MoveLine {w id ptz} {
    foreach item [$w find withtag $id] {
        set taglist [$w gettags $item]
        if {[string match *startblob* $taglist]} {
            set x1 [lindex $ptz 0]
            set y1 [lindex $ptz 1]
            $w coords $item [list [expr $x1-1] [expr $y1-1] \
				 [expr $x1+1] [expr $y1+1]]
        } elseif {[string match *endblob* $taglist]} {
            set x1 [lindex $ptz [expr [llength $mptz] - 2]]
            set y1 [lindex $ptz end]
            $w coords $item [list [expr $x1-1] [expr $y1-1] \
				 [expr $x1+1] [expr $y1+1]]
        } elseif {[string match line [$w type $item]] && \
                    ![string match *bowtie* $taglist]} {
	    set mptz [ScaleList $w $ptz [string match *curvy* $taglist]]
            eval "$w coords $item" $mptz
        }
    }
}

proc DrawBlob {w g startX startY size tags} {
#     $w create line $startX $startY $startX $startY -width $size \
#            -capstyle round -tags $tags
# Hold on...bigger news than that...
    set rad [expr $size/2]
    set ol [expr $startX-$rad]
    set ot [expr $startY-$rad]
    set or [expr $startX+$rad]
    set ob [expr $startY+$rad]
    $w add arc $g "$ol $ot $or $ob" -extent 359 \
	-linewidth 0 -filled 1 -tags [lappend tags /flashes/]
#    scan [GetPoints $ol $rad] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
#    scan [GetPoints $ot $rad] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
#    scan [GetPoints $or -$rad] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
#    scan [GetPoints $ob -$rad] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7
#    $w create poly $h3 $v3 $h4 $v2 $h5 $v1 $h6 $ot $h8 $v1 $h9 $v2 $h10 $v3 $h11 $v4 $h12 $v5 $or $v6 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h6 $ob $h5 $v12 $h4 $v11 $h3 $v10 $h2 $v9 $h1 $v8 $ol $v6 $h1 $v5 $h2 $v4 $h3 $v3 -outline {} -tags [lappend tags /flashes/]
}

# This puts random bits of normally non-editable text on the screen...

proc PutText { w n ptz ptype tagSet fatness colourScheme capt } {
    global looks window_info
    
    if {[lsearch {vflow hflow} $ptype]>-1} {
        set type [CustomAs flow]
    } else {
        set type [CustomAs $ptype]
    }
    set node $window_info($w,top_node)
    if {[string compare $colourScheme normal]} {
        set textColor $looks($node,$type,$colourScheme)
    } else {
        set textColor $looks($node,$type,text)
    }
    
    set fontData [ExtractFontData $looks($node,$type,font)]
    set realFont [Scale $w [lindex $fontData 3]*$fatness/100]
#    if {$realFont<10} {
#        set closeFont 10
#    } else {
#        set closeFont [expr round($realFont)]
#    }
    set useFont [AssembleFont [lindex $fontData 0] [lindex $fontData 1] \
            [lindex $fontData 2] $realFont]
    set textX [Scale $w [expr [lindex $ptz 0] \
            + $looks($node,$ptype,xoffset)*$fatness/100]]
    set textY [Scale $w [expr [lindex $ptz 1] \
            + $looks($node,$ptype,yoffset)*$fatness/100]]
# experimental background box for text
    set g [GetGroupItem $w $n]
    set backBox [$w add rectangle $g {0 0 1 1} -linewidth 0 \
		     -fillcolor \#ffffc0 -tags "$tagSet /${type}_text/"]
    if {$looks($node,$type,txtbg)} {
        $w itemconfig backBox -filled 1
    }
    $w dtag $backBox editable
    $w dtag $backBox currently_editable
    if {$looks($node,$type,txtbd)} {
        $w add curve $g {{0 0} {1 1}} -linecolor $textColor \
	    -tags [$w gettags $backBox]
    }
    set ankh $looks($node,$ptype,textanchor)
    set anchsp [string first realanchor\( $tagSet]
    if {$anchsp != -1} {
        set anchltr [expr {$anchsp+11}]
        set ankh [string range $tagSet $anchltr $anchltr]
        set depth [GetObjectSize $w influence $fatness]
        switch $ankh {
            e {
                set textX [expr {$textX-$depth/2}]
            } w {
                set textX [expr {$textX+$depth/2}]
            } s {
                set textY [expr {$textY-$depth/2}]
            } n {
                set textY [expr {$textY+$depth/2}]
            }
        }
    }
    if {[string match *e $ankh]} {
        set tjust right
    } elseif {[string match *w $ankh]} {
        set tjust left
    } else {
        set tjust center ;# Blooaaargh! Spell it right dudes!
    }
    set textItem [$w add text $g -position "$textX $textY" -text $capt \
		      -color $textColor -composescale 1 \
		      -font $useFont -anchor $ankh -alignment $tjust \
		      -tags "$tagSet is_caption size_on_this has_info"]
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
        $w itemconfig $new -tags [concat currently_editable [$w gettags $new]]
    }
    $w focus $new
    $w select from $new 0
    $w select to $new end
}

# This procedure colours the symbol outline with the given identifier, by first
# searching for all the graphical components that make it up and then
# either filling or outlining them depending on the method appropriate to their
# type.

set borrowLooksFor {cloud compartment flow variable squirt event}
proc ColorSymbol { w name type density colorSpec } {
    global looks window_info
    
    set n $window_info($w,top_node)
    set type [CustomAs $type]
    if {[string compare $colorSpec normal]} {
        set outlineColor $looks($n,$type,$colorSpec)
        set textColor $outlineColor
    } else {
        set outlineColor $looks($n,$type,outline)
        set textColor $looks($n,$type,text)
    }
    FlashSymbol $w $name $outlineColor $textColor

    StippleSymbol $w $name $density $colorSpec
}

proc FlashSymbol {w name outlineColor textColor} {
    foreach object [$w find withtag $name] {
        switch -regexp [$w type $object] {
            text {$w itemconfigure $object -color $textColor}
            curve {
                if {[string match */*_text/* [$w gettags $object]]} {
                    $w itemconfigure $object -linecolor $textColor
                } elseif {![string match */background/* [$w gettags $object]]} {
                    $w itemconfigure $object -linecolor $outlineColor
                }
            } oval {
                if {![string match */background/* [$w gettags $object]]} {
                    $w itemconfigure $object -linecolor $outlineColor
                }
            } arc {
                if {[string match */flashes/* [$w gettags $object]]} {
		    $w itemconfigure $object -fillcolor $outlineColor
		} elseif {![$w itemcget $object -filled] && \
                        ![string match */background/* [$w gettags $object]]} {
                    $w itemconfigure $object -linecolor $outlineColor
                }
            }
        }
    }
}

proc StippleSymbol {w name density selected} {
    foreach object [$w find withtag $name] {
        switch -regexp [$w type $object] {
            line {
                $w itemconfigure $object -linepattern $density
            }
            rectangle|arc|polygon {
                $w itemconfigure $object -linepattern $density \
                    -fillpattern $density
            }
        }
        switch -regexp $selected {
            highlight {
                $w dtag $object tocopy
                $w itemconfigure $object -tags \
                    [concat selected [$w gettags $object]]
            } select {
                $w itemconfigure $object -tags \
                    [concat tocopy selected [$w gettags $object]]
            } default {
                $w dtag $object selected
                $w dtag $object tocopy
            }
        }
    }
}

proc FillSymbol { w name color } {
    foreach object [$w find withtag $name] {
        set tags [$w gettags $object]
        if {[lsearch "rectangle arc curve" [$w type $object]]!=-1 && \
                ![string match *_text/* $tags] && \
                ![string match */background/* $tags] && \
                ![string match */flashes/* $tags]} {
            $w itemconfigure $object -fillcolor $color
        }
    }
}

proc ResetColours { w type density colourScheme name } {
    global looks window_info
    
    set n $window_info($w,top_node)
    ColorSymbol $w $name $type $density $colourScheme
    set fillColor $looks($n,[CustomAs $type],fill)
    FillSymbol $w $name $fillColor
}

proc ColourExists {col} {
    if {[catch {winfo rgb . $col}]} {
        return 0
    } else {
        return 1
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
            set config ""
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
                # Don't bother writing default values
                if {[string compare $default $value]} {
                    append config [list [lindex $conf 0] $value] " "
                }
            }
            puts $stream [concat \$c create [$canvas type $object] \
                              [$canvas coords $object] $config]
#        }
    }
    close $stream
}

proc MakeImage {c base inst w h args} {
    global looks window_info
    
    set n $window_info($c,top_node)
    #    if {![info exists imageSources($base)]} {
    #        image create photo $base
    #        $base read $file -shrink
    #        PutSize $base
    #        set imageSources($base) $file
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
        #ShowMessage debug info "Moving $image $way" ok
        if {[string compare image none]} {
            set imgFile $topDir/${image}
            switch $way {
                in {
                    image create photo $image
                    # others than .png are for legacy
                    foreach fmt {png gif jpeg none} {
                        if {![catch {$image read $imgFile.$fmt -shrink}]} {
                            PutSize $image
                            file delete $imgFile
                            break
                        }
                    }
                    # prevent crasho if reading fails
                    if {[string match none $fmt]} {
                        $image read ../Images/splash.gif -shrink
                        PutSize $image
                    }
                } out {
                    # try gif first, if too many colours try jpeg
                    # --as of 2/5/06 only try .png
                    foreach fmt {png} {
                        if {![catch {$image write $imgFile.$fmt \
                                         -format $fmt}]} {
                            break
                        } else {
                            puts "Failed to write $imgFile.$fmt -- $err"
                        }
                    }
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
    set w [expr $window_info($c,width)+4]
    set h [expr $window_info($c,height)+4]
    source $canvasFile
# following does same thing but allows encoding to happen
# not needed now cos we set system encoding, which source uses
#    set stream [NetOpen $canvasFile r]
#    while {[gets $stream line]>=0} {
#        eval $line
#    }
#    close $stream

    # At this point we may have loaded something with a scrollregion smaller than
    # the current window. In this case TweakWindow (from the .cnv file) will have
    # loaded this region as the new window size, so we 'grow' the window back to
    # its previous size which we saved. The xview and yview cmds here work around
    # a tcl bug that if the scrollregion is smaller than the window it may not all
    # be displayed.
    $c delete withtag /base/ ;# these will be re-created
    update idletasks
    $c xview moveto 0
    $c yview moveto 0
    SetSpace $c $w $h
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

# GetEdit returns the node ID of the canvas item with input focus

proc GetEdit { w } {
    set current [$w focus]
    if {[string compare $current {}]} {
        return [ExtractPrologName $w [lindex $current 0]]
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

# This zooms canvas in or out. Because it can be done in response to a
# resize request from Prolog we need a special parameter (arg 3) to stop
# Prolog being called back in this instance, because a loop would happen
# sometimes due to rounding errors.

proc DoZoom { winId factor toProlog} {
    
    global window_info looks

# Right, hard bit is keeping the middle of the display in the middle
# after the zoom. We need to find out where the middle is in space 1
# (roughly equiv of canvasx canvasy) and what it is in space 2. Then
# after moving, find out where the same poing in space 2 has gone in
# space 1 and scroll it to its previous space 1 posn...simple
# really...

# This should be a bit simpler now...

    # First, find canvas point at centre of display
    set centre_x [expr $window_info($winId,width)/2]
    set centre_y [expr $window_info($winId,height)/2]

#    RollBack $winId $toProlog [expr (1 - 1/$factor)*$centre_x] \
            [expr (1 - 1/$factor)*$centre_y] \
            [expr (1 + 1/$factor)*$centre_x] \
            [expr (1 + 1/$factor)*$centre_y]

    # Now...aw, fuck it
    $winId scale 1 $factor $factor $centre_x $centre_y

    # next make sure that enough canvas exists for the outcome of the operation
    eval {RollBack $winId $toProlog} [$winId transform 1 "0 0
$window_info($winId,width) $window_info($winId,height)"]
}

# ZoomImage: Scale the graphical stuff in the window, and explicitly
# change line thicknesses, arrowhead sizes and font sizes
# of all components for new display size (Tcl does not change these
# when zooming). Font sizes have a separate parameter to enable them to come
# out right when zooming prior to Postscript export.

proc ZoomImage {winId which factor {optFontor none}} {
    #ShowMessage debug info "ZoomImage $winId $which $factor $fontor" ok
    global window_info looks

    set n $window_info($winId,top_node)
    $winId scale $which 0 0 $factor $factor
    if {[string compare $which all]} {
        set objList [$winId find withtag $which]
    } else {
        # and update the info...(if it's there)
        catch {set window_info($winId,scale) \
                    [expr $window_info($winId,scale) * $factor]}

        scan [$winId cget -scrollregion] "%g %g %g %g" bl bt br bb
        set objList [$winId find all]
    }
    if {[string match none $optFontor]} {
        set fontor $factor
    } else {
        set fontor $optFontor
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
            if {$newTextSize < 1} {
                set newTextSize 1
            }
            $winId itemconfigure $object -font \
                [AssembleFont [lindex $fontData 0] [lindex $fontData 1] \
                     [lindex $fontData 2] $newTextSize]
            FixBackBox $winId $object
        } line {
            $winId itemconfigure $object \
                -width [AdjustWidth $winId $object $factor]
            AdjustArrow $winId $object $factor
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
        } default {
            $winId itemconfigure $object \
                -width [AdjustWidth $winId $object $factor]
        }
        }
    }
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
            set oldWidth [expr [font actual $currentFont -size]*12.0]
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
#    ShowMessage debug info "ZBI $winId $node $factor $invx $invy" ok
#    foreach target [$winId find withtag $node] {
#        if {[string equal polygon [$winId type $target]] && \
#                [string match "*/background/*" [$winId gettags $target]]} {
#            set reejun [$winId bbox $target]
#        }
#    }
#ShowMessage debug info "Picked region $reejun" ok
#    eval {$winId addtag /squeeze/ enclosed} $reejun
#    $winId dtag $node /squeeze/
    foreach bit $args {
        $winId addtag /squeeze/ withtag $bit
    }
    set invx [Scale $winId $invx]
    set invy [Scale $winId $invy]
    if {$factor != 1.0} {
        ZoomImage $winId /squeeze/ $factor
    }
    $winId move /squeeze/ $invx $invy
    $winId dtag /squeeze/
}

# Move a window's display area to include all its contents
proc DisplayAll { winId } {
    global window_info

    # get desired display area
    if {[scan [$winId bbox size_on_this] "%d %d %d %d" bl bt br bb] == 4} {
        # ShowMessage debug info "Bounds are $bl $bt $br $bb" ok
        set clearBorder [expr 15*$window_info($winId,scale)]

        set bl [expr $bl - $clearBorder]
        set bt [expr $bt - $clearBorder]
        set br [expr $br + $clearBorder]
        set bb [expr $bb + $clearBorder]
        set allowScrollBar [winfo reqwidth [winfo parent $winId].yscroll]
        # zoom to correct size
        set xscale [expr ($window_info($winId,width) - $allowScrollBar)/double($br - $bl)]
        set yscale [expr ($window_info($winId,height) - $allowScrollBar)/double($bb - $bt)]
        set scale [expr $xscale>$yscale?$yscale:$xscale]

        # ShowMessage debug info "xscale $xscale yscale $yscale scale $scale" ok

        ZoomImage $winId all $scale

        set bl [expr $bl*$scale]
        set bt [expr $bt*$scale]
        set br [expr $br*$scale]
        set bb [expr $bb*$scale]

        ResizeDesktop $winId $bl $bt $br $bb
    }
}

proc DisplayArea {winId} {
    global window_info looks
    if {[scan [$winId bbox selected] "%d %d %d %d" bl bt br bb] < 4} {
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
    if {[string compare $findable {}]} {
        set find(List,$canvas) {}
        foreach caption [$canvas find withtag is_caption] {
            if {[string match -nocase *$findable* \
                     [BlankCrs [ForSearchType $canvas $caption]]]} {
                lappend find(List,$canvas) $caption
            }
        }
        if {[info exists find(now,$canvas)]} {
            unset find(now,$canvas)
        }
        NextCaption $canvas
    }
}

proc ForSearchType {winId item} {
    global find
    set plName [ExtractPrologName $winId $item]
    switch $find(where) {
        caption {
            return [$winId itemcget $item -text]
        } equation {
            return [GetFromProlog tk_get_info('$winId',$plName,eqn)]
        } description {
            return [GetFromProlog tk_get_info('$winId',$plName,comment)]
        }
    }
}

proc NextCaption {canvas} {
    global find window_info
    if {![info exists find(List,$canvas)]} {
        ShowMessage "Operation failed" error "No search in progress!" ok
        return
    }
#    if {[info exists find(now,$canvas)]} {
#        prolog event:do_colours($find(now,$canvas),off)
#        FlashSymbol $canvas $find(now,$canvas) $looks(variable,outline) \
#                $looks(variable,text)
#    }
    if {[info exists find(now,$canvas)]} {
        prolog event:do_colours($find(now,$canvas),off)
    } else {
        MenuSelect $canvas edit unselall
    }
    if {![llength $find(List,$canvas)]} {
        ShowMessage "Caption finder" info \
                "No more matching $find(where)s in this window" ok
        array unset find *,$canvas
    } else {
        set this [lindex $find(List,$canvas) 0]
        set find(List,$canvas) [lrange $find(List,$canvas) 1 end]
        #        $canvas itemconfigure $this -fill blue
        # left in in case the thing fails to highlight, or is exec_only

        # Now to pervert the 'scan' command to make an ad-hoc 'see'...
        # note this could also be done using canvas x/yview moveto, but only
        # if the values they return are updated by resizing the window (which
        # the reported width and height aren't).

        set middleX [$canvas canvasx [expr $window_info($canvas,width)/2]]
        set middleY [$canvas canvasy [expr $window_info($canvas,height)/2]]
        scan [$canvas coords $this] {%f %f} tgtX tgtY
        $canvas scan mark [expr int(-0.1*$middleX)] [expr int(-0.1*$middleY)]
        $canvas scan dragto [expr int(-0.1*$tgtX)] [expr int(-0.1*$tgtY)]

        set find(now,$canvas) [ExtractPrologName $canvas $this]
        prolog tk_do_colours($find(now,$canvas),on)
#        FlashSymbol $canvas $find(now,$canvas) orange orange
        #        HandleObjClick $canvas $this clicktext $tgtX $tgtY
        #        ReleaseObj $canvas $tgtX $tgtY
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
    
    switch -regexp $mode {
        condition|creation|immigration|reproduction|loss {
            set object channel
            wm title $t "Customize conditions and channels"
        } ghost|select|snap {
            set object generic
            wm title $t "Customize all components"
        } default {
            set object $mode
            wm title $t "Customize $object appearance"
        }
    }
    
    zinc $t.canvas -width [expr $looks(width) + 120] \
            -height [expr $looks(width) + 60] -render 1
    set window_info($t.canvas,scale) 1
    set window_info($t.canvas,top_node) $n
    set custom(showgrids,$t.canvas) 1
    pack $t.canvas
    AddGrid $t.canvas [Gradient white -0.1 $t.canvas]  0 0 \
        [expr $looks(width)+120] [expr $looks(width)+60]

    if {[string compare $object influence]} {
        TitleFrame $t.text -text "Text: "
        set text [$t.text getframe]
        label $text.tell \
            -text "Drag text by chosen anchor to set default position"
        pack $text.tell
        set ts [frame $text.size]
        label $ts.what -text "Text size: "
        pack $ts.what -side left
        scale $ts.scale -from 10 -to 250 -length $looks(width) \
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
        set graphics [$t.graphics getframe]
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
#        -command "ReadLooks $t $n $object"
#    pack $t.actions.load -side left
#    button $t.actions.save -text "Save" \
#        -command "SaveLooks $t $object"
#    pack $t.actions.save -side left
    button $t.actions.normal -text "Normalize" \
        -command "LoadLooks $t $n $object normal"
    pack $t.actions.normal -side left
    button $t.actions.done -text "Done" -command "set done 1"
    pack $t.actions.done -side left
    button $t.actions.apply -text "Apply" \
        -command "ApplyLooks $t $n $object"
    pack $t.actions.apply -side left
    button $t.actions.cancel -text "Cancel" -command "set done 0"
    pack $t.actions.cancel -side left
    pack $t.actions
    LoadLooks $t $n $object $object
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

proc LoadLooks {t n target object} {
    global looks
    
    if {[string compare $target influence]} {
        #ShowMessage debug info "ExtractFontData looks($object,font) [ExtractFontData $looks($object,font)]" ok
        scan [ExtractFontData $looks($n,$object,font)] "%s %s %s %d" \
                looks($n,$target,family) looks($n,$target,weight) \
                looks($n,$target,style) textsize
        [$t.text getframe].size.scale set $textsize
        [$t.text getframe].backbox.col configure \
            -activebackground $looks($n,$object,text)
    }
    
    set middlex [expr $looks(width)/2 + 60]
    set middley [expr $looks(width)/2 + 30]
    
    if {[string compare $object text]} {
        set g [$t.graphics getframe]
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
        DoGraphics $t $target $middlex $middley $looks($n,$object,objectsize)
    } else {
        $t.canvas remove sample
        PutText $t.canvas sample [list $middlex $middley] \
                text "sample" 100 normal "Sample text box"
    }
    $t.canvas configure -backcolor $looks(windowColor)
    #        TweakObject $t target
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
    set textsize [expr [font actual $font -size]*12.0]
    #ShowMessage debug info "ExtractFontData [list $family $weight $style $textsize]" ok
    return [list $family $weight $style $textsize]
}

proc CopyLooks {t n object} {
    global looks
    if {[string compare $object text]} {
        set g [$t.graphics getframe]
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
    if {[string compare $object influence]} {
        set looks($n,$object,font) [ResetFont $t]
#        if {[string compare $object text]} {
#            UpdateOffsets $t $n $object
#        }
        set looks($n,$object,text) \
            [[$t.text getframe].backbox.col cget -activebackground]
        set looks($n,$object,txtbd) $looks(txtbd)
        set looks($n,$object,txtbg) $looks(txtbg)
        if {[string equal flow $object]} {set object vflow}
        set looks($n,$object,textanchor) [GetTextAnchor $t]
    }
}

proc DoGraphics {box type middlex middley size} {
    global looks
    $box.canvas remove sample

    switch -regexp $type {
        compartment|generic {
            set l [expr $middlex - 2*$size/5]
            set r [expr $middlex + 2*$size/5]
            set t [expr $middley - 3*$size/10]
            set b [expr $middley + 3*$size/10]
            PutRectangle $box.canvas sample $l $t $r $b 1 100 {} normal "sample"
        } state {
            set l [expr $middlex - 3*$size/10]
            set r [expr $middlex + 3*$size/10]
            set t [expr $middley - 2*$size/5]
            set b [expr $middley + 2*$size/5]
            PutRectangle $box.canvas sample $l $t $r $b 1 100 {} normal "sample"
        } submodel {
            set l [expr $middlex - 90]
            set r [expr $middlex + 90]
            set t [expr $middley - 60]
            set b [expr $middley + 60]
            PutRoundedRect $box.canvas sample $l $t $r $b 3 100 clear \
                none none 0 0 100 normal "sample"
        } flow {
            set l [expr $middlex - $size/4]
            set r [expr $middlex + $size/4]
            set t [expr $middley - $size/8]
            set b [expr $middley + $size/8]
            PutBowTie $box.canvas $l $t $r $b 100 {} normal "sample"
            PutFatArrow $box.canvas "30 [expr $middley-30] $middlex \
                    [expr $middley - 30] $middlex [expr $middley + 30] \
                    [expr 2*$middlex - 30] [expr $middley + 30]" \
                    100 normal "sample"
        } variable|event {
            set l [expr $middlex - 3*$size/20]
            set r [expr $middlex + 3*$size/20]
            set t [expr $middley - 3*$size/20]
            set b [expr $middley + 3*$size/20]
            if {[string equal event $type]} {
                set sty 101
            } else {
                set sty 1
            }
            PutCrossedCirc $box.canvas sample $l $t $r $b $sty 100 {} normal "sample"
        } channel {
            set l [expr $middlex - 3*$size/10]
            set r [expr $middlex + 3*$size/10]
            set t [expr $middley - 3*$size/10]
            set b [expr $middley + 3*$size/10]
            PutShape $box.canvas $l $t $r $b condition 100 normal "sample"
        } influence {PutThinArrow $box.canvas "30 $middley $middlex \
                    [expr $middley-30] [expr 2*$middlex - 30] $middley" \
                    100 {} normal "sample"
        } relation {
            set b $middley
            PutRelation $box.canvas sample "30 $middley $middlex \
                    [expr $middley-30] [expr 2*$middlex - 30] $middley" \
                100 normal "sample"
        }
    }

    if {[string compare $type influence]} {
# side to put caption on -- this is fixed for now
        set capt "Sample $type"
        switch $type {
            submodel {
                set xbase $l
                set ybase $t
            } flow {
                set xbase $r
                set ybase $middley
                set type vflow ;# text offset as for bowtie on vertical section
            } default {
                set xbase $middlex
                set ybase $b
            }
        }

        PutText $box.canvas sample [list $xbase $ybase] \
                $type "sample movable" 100 normal $capt
        set looks(cheat) [$box.canvas coords [GetCaptionItem $box.canvas sample]]
        $box.canvas bind movable <Button-1> {SampleMark %x %y %W}
        $box.canvas bind movable <B1-Motion> {SampleMove %x %y %W}
    }
}

proc SampleMark { x y w } {
    # during drag xoffset and yoffset are relative to its start...not any more!
    # now we pick the closest apex to the clicked point, snap to that and then do
    # an absolute drag!
    
    set textbox [$w bbox movable]
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
        set a1 c
    }
    
    set textItem [GetCaptionItem $w sample]
    $w itemconfigure $textItem -anchor $a1$a2
    $w coords $textItem $x $y
    FixBackBox $w $textItem
}

proc SampleMove {x y w} {
    set oldPosn [$w coords [GetCaptionItem $w sample]]
    $w move movable [expr $x-[lindex $oldPosn 0]] [expr $y-[lindex $oldPosn 1]]
}

proc ResetFont { top } {
    set t [$top.text getframe]
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

proc AssembleFont {family weight style textsize} {
    return [list -family $family -weight $weight -slant $style \
            -size [expr round($textsize/12.0)]]
}

proc ZotFont { t param } {
    set txt [GetCaptionItem $t.canvas sample]
    $t.canvas itemconfigure $txt \
        -font [ResetFont $t]
    FixBackBox $t.canvas $txt
}

proc ZotColor {t n role type} {
    set newColour [tk_chooseColor -initialcolor \
            [$role cget -activebackground]]
    if {[llength $newColour]} {
        $role configure -activebackground $newColour
        CopyLooks $t $n $type
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
    
    CopyLooks $t $n $useLooks
    if {[string compare text $type]} {
        DoGraphics $t $useLooks $middlex $middley \
            [[$t.graphics getframe].objectsize.scale get]
    } else {
        $t.canvas delete sample
        PutText $t.canvas sample [list $middlex $middley] \
                text "sample" 100 normal "Sample text box"
    }
}

# not used, flows and squirts not customized separately and squirts need fixing
# best would be to include in sample box with variable/event and own caption
#proc UpdateOffsets {t n type} {
#    global looks
#    set offsets [$t.canvas coords [GetCaptionItem $t.canvas sample]]
#    if {[string equal flow $type]} {set type vflow}
#    set looks($n,$type,xoffset) [expr $looks($n,$type,xoffset) + \
#            [lindex $offsets 0] - [lindex $looks(cheat) 0]]
#    set looks($n,$type,yoffset) [expr $looks($n,$type,yoffset) + \
#            [lindex $offsets 1] - [lindex $looks(cheat) 1]]
#    set looks(cheat) $offsets
#}
#
proc GetTextAnchor {t} {
    $t.canvas itemcget [GetCaptionItem $t.canvas sample] -anchor
}

proc ResetLooks {c type} {
    global looks
    
    set looks($c,$type,font) [AssembleFont Helvetica bold roman 120]
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
}

proc CustomizeLooks {c} {
    global looks
    
    #    prolog tk_set_new_size(compartment,30,0,0)
    #    prolog tk_set_new_size(variable,15,0,0)
    #    prolog tk_set_new_size(function,15,0,0)
    #    prolog tk_set_new_size(cloud,25,0,0)
    #    prolog tk_set_new_size(channel,30,0,0)
    set looks($c,hflow,xoffset) 0
    set looks($c,hflow,yoffset) 2
    set looks($c,hflow,textanchor) n
    set looks($c,vflow,xoffset) 2
    set looks($c,vflow,yoffset) 0
    set looks($c,vflow,textanchor) w
    set looks($c,submodel,textanchor) sw
    set looks($c,text,textanchor) c
}

proc Desystematize {colorSpec} {
    set rgb [winfo rgb . $colorSpec]
    return [format "#%04x%04x%04x" [lindex $rgb 0] \
            [lindex $rgb 1] [lindex $rgb 2]]
}

proc ApplyLooks {t topNode type} {
    RememberLooks $topNode
    if {[string compare $type generic]} {
        CopyLooks $t $topNode $type
        ExportLooks $t $topNode $type
    } else {
# add state to next line
        foreach object {generic compartment state channel function variable \
                        event text submodel flow squirt influence relation} {
            CopyLooks $t $topNode $object
            ExportLooks $t $topNode $object
        }
    }
}

proc RememberLooks {n} {
    global looks
    set looks(safe) [MakeLooksSaver $n]
}

proc ExportLooks {t topNode type} {
    global looks window_info borrowLooksFor
    
    prolog [format "tk_change_size(%s,%s,%d)" $topNode $type $looks($topNode,$type,objectsize)]
    foreach {is use} $borrowLooksFor {
        if {[string equal $use $type]} {
            prolog [format "tk_change_size(%s,%s,%d)" $topNode \
                                $is $looks($topNode,$type,objectsize)]
        }
    }
    #        foreach windae [array name window_info *,parent] {
    #                set canvas [string trimright $windae ,parent]
    #        }
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
    set objects $looks(customSet)
    set aspects {font txtbd txtbg outline fill text select highlight target \
                     incomplete objectsize lines xoffset yoffset textanchor}
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
# now tell Prolog what we got (but not to redraw)
        prolog [format "tk_set_new_size(%s,%s,%d)" $top $type \
                $looks($top,$type,objectsize)]
    }
}

button .b
set looks(buttonColor) [Desystematize [.b cget -bg]]
set looks(windowColor) white
destroy .b

