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

proc GetObjectSize {w type fatness} {
    global looks
    return [expr [Scale $w $looks($type,objectsize)]*$fatness/100.0]
}

proc GetLineSize {w type fatness} {
    global looks
    return [expr [Scale $w $looks($type,lines)]*$fatness/100.0]
}

proc ScaleRect {w l t r b} {
    return [list [Scale $w $l] [Scale $w $t] [Scale $w $r] [Scale $w $b]]
}

proc PutRectangle { w l t r b stack fatness density colourScheme tagSet} {
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set width [GetLineSize $w compartment $fatness]
    $w create rect $ml $mt $mr $mb -outline {} -tag "$tagSet has_info"
    set stackDepth 0
    $w create line $mr $mt $ml $mt $ml $mb -width $width \
            -tag "$tagSet size_on_this realwidth($width)"
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
    set nameList {compartment comp condition cond creation creation \
                immigration immig reproduction repro loss loss alarm alarm}
    set point [expr [lsearch $nameList $file] + 1]
    set fileName [lindex $nameList $point]
    
    source "../Images/$fileName.cnv"
    set growth [expr ($r-$l)/30.0]
    ZoomImage $c unscaled $growth
    $c move unscaled [expr ($l+$r)/2] [expr ($t+$b)/2]
    ZoomImage $c unscaled $window_info($c,scale)
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
    global looks
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set width [GetLineSize $w flow $fatness]
    
    if {($mb - $mt) > ($mr - $ml)} {
        set bounds "$ml $mt $mr $mt $ml $mb $mr $mb $ml $mt"
    } else {
        set bounds "$ml $mt $ml $mb $mr $mt $mr $mb $ml $mt"
    }
    eval {$w create poly} $bounds {-tag "$tagSet bowtie has_info"}
    eval {$w create line} $bounds {-width $width \
                -tag "$tagSet bowtie realwidth($width)"}
    ResetColours $w flow $density $colourScheme [lindex $tagSet 0]
}

# Circles are drawn as many-hedrons until the bug that stops ovals stippling
# is fixed

proc PutCrossedCirc { w l t r b stack fatness density colourScheme tagSet} {
    set width [GetLineSize $w variable $fatness]
    
    scan [ScaleRect $w $l $t $r $b] {%f %f %f %f} ml mt mr mb
    set rad [expr ($mr-$ml)/2]
    set hm [expr $ml+$rad]
    set vm [expr $mt+$rad]
    set bulge [expr 1.2*$rad]
    set bounds [list $hm [expr $vm-$bulge] [expr $hm+.866*$bulge] [expr $vm-.5*$bulge] \
            [expr $hm+.866*$bulge] [expr $vm+.5*$bulge] $hm [expr $vm+$bulge] \
            [expr $hm-.866*$bulge] [expr $vm+.5*$bulge] [expr $hm-.866*$bulge] \
            [expr $vm-.5*$bulge] $hm [expr $vm-$bulge]]
    set p1 [eval {$w create polygon} $bounds {-smooth true -outline {} \
						  -tag "$tagSet has_info"}]
    set bulge [expr 0.707*$rad]
    set xl [expr $hm-$bulge]
    set xt [expr $vm-$bulge]
    set xr [expr $hm+$bulge]
    set xb [expr $vm+$bulge]
    $w create line $xl $xt $xr $xb -width $width \
            -tag "$tagSet realwidth($width) has_info"
    $w create line $xr $xt $xl $xb -width $width \
            -tag "$tagSet realwidth($width) has_info"
    
    
    #    $w create oval $ml $mt $mr $mb -outline {} -tag $tagSet
    #    scan [GetPoints $ml $rad] {%f %f %f %f %f} h0 h1 h2 h3 h4
    #    scan [GetPoints $mt $rad] {%f %f %f %f %f} v0 v1 v2 v3 v4
    #    scan [GetPoints $mr -$rad] {%f %f %f %f %f} h9 h8 h7 h6 h5
    #    scan [GetPoints $mb -$rad] {%f %f %f %f %f} v9 v8 v7 v6 v5
    #    $w create polygon $h2 $v7 $h1 $v6 $h0 $v5 \
    #	    $ml $vm $h0 $v4 $h1 $v3 $h2 $v2 $h3 $v1 $h4 $v0 \
    #	    $hm $mt $h5 $v0 $h6 $v1 $h7 $v2 $h8 $v3 $h9 $v4 \
    #	    $mr $vm $h9 $v5 $h8 $v6 $h7 $v7 $h6 $v8 $h5 $v9 \
    #	    $hm $mb $h4 $v9 $h3 $v8 -outline {} -tag $tagSet
    #    $w create line $h2 $v2 $h7 $v7 -width $width \
    #	    -tag "$tagSet realwidth($width)"
    #    $w create line $h2 $v7 $h7 $v2 -width $width \
    #	    -tag "$tagSet realwidth($width)"
    #    $w create line $h2 $v7 $h1 $v6 $h0 $v5 \
    #	    $ml $vm $h0 $v4 $h1 $v3 $h2 $v2 $h3 $v1 $h4 $v0 \
    #	    $hm $mt $h5 $v0 $h6 $v1 $h7 $v2 \
    #	-width $width -tag "$tagSet size_on_this realwidth($width)"
    
    set stackDepth 0
    while {$stackDepth < $stack} {
        set stackDistance [expr $stackDepth*$width*2]
        set stackSide [eval {$w create line} $bounds \
                {-smooth true -width $width -tag "$tagSet size_on_this realwidth($width)"}]
        #	set stackSide [$w create line $h7 $v2 $h8 $v3 $h9 $v4 \
        #		$mr $vm $h9 $v5 $h8 $v6 $h7 $v7 $h6 $v8 $h5 $v9 \
        #		$hm $mb $h4 $v9 $h3 $v8 $h2 $v7 \
        #		-width $width -tag "$tagSet size_on_this realwidth($width)"]
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
    $w create oval $ml $mtb13 [expr (2*$mr + $ml)/3] $mb -width $width \
            -tag "$tagSet size_on_this realwidth($width)"
    $w create oval [expr ($mr + 2*$ml)/3] $mtb13 $mr $mb -width $width \
            -tag "$tagSet size_on_this realwidth($width)"
    $w create oval [expr ($mr + 5*$ml)/6] $mt [expr (5*$mr + $ml)/6] \
            [expr (2*$mb + $mt)/3] -width $width \
            -tag "$tagSet size_on_this realwidth($width)"
    ResetColours $w flow $density $colourScheme [lindex $tagSet 0]
}

proc PutRoundedRect {w l t r b stack fatness fillColour fillImage layout \
			  colourScheme tagSet} {
    global looks
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
        set cornerDiam [expr $looks(submodel,objectsize)*$shortSide/200]
    }
    set cornerRad [expr 0.5*$cornerDiam]
    # This is the diameter of the rounded corner as fraction of the box width
    
    set dots [expr !$stack]
    set pile [expr $stack==-1]
    if {$dots} {
        set stack 4
    }
    if {$pile} {
        set stack 1
    }
    
    # second approximation to fill
    scan [GetPoints $ml $cornerRad] {%f %f %f %f %f %f} h1 h2 h3 h4 h5 h6
    scan [GetPoints $mt $cornerRad] {%f %f %f %f %f %f} v1 v2 v3 v4 v5 v6
    scan [GetPoints $mr -$cornerRad] {%f %f %f %f %f %f} h12 h11 h10 h9 h8 h7
    scan [GetPoints $mb -$cornerRad] {%f %f %f %f %f %f} v12 v11 v10 v9 v8 v7
    
    set contents [$w find enclosed $ml $mt $mr $mb]
    if {![string match clear $fillColour]} {
        set poly [$w create polygon \
                $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 \
                $h6 $mt $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 $h11 $v4 \
                $h12 $v5 $mr $v6 $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 \
                $h9 $v11 $h8 $v12 $h7 $mb $h6 $mb $h5 $v12 $h4 $v11 \
                $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 -outline {} \
                -fill $fillColour -tag "$tagSet /background/"]
	# Now to stick it behind anything that might be drawn inside
	if {[llength $contents]} {
	    $w lower $poly [lindex $contents 0]
	}
    }
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
	if {[llength $contents]} {
	    $w lower $poly [lindex $contents 0]
	}
    }
    set width [GetLineSize $w submodel $fatness]
    $w create line $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 \
            $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt \
            $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 -width $width \
	-tag "$tagSet size_on_this realwidth($width) has_info"
    
    set tabs 0
    set stackSpacing [expr 2*$width]
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
            set stackDistance [expr $tabs*$stackSpacing]
            set lower [$w create line $h10 $v3 $h11 $v4 $h12 $v5 $mr $v6 \
                $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h7 $mb \
                $h6 $mb $h5 $v12 $h4 $v11 $h3 $v10 -width $width \
		       -tag "$tagSet size_on_this realwidth($width) has_info"]
            $w move $lower $stackDistance $stackDistance
        }
        incr tabs
    }
    
    if {$pile} {
        set stackDistance [expr -$stackSpacing]
        set upper [$w create line $h3 $v10 $h2 $v9 $h1 $v8 $ml $v7 \
                $ml $v6 $h1 $v5 $h2 $v4 $h3 $v3 $h4 $v2 $h5 $v1 $h6 $mt \
                $h7 $mt $h8 $v1 $h9 $v2 $h10 $v3 -width $width \
		       -tag "$tagSet size_on_this realwidth($width) has_info"]
        $w move $upper $stackDistance $stackDistance
        set stackDistance [expr 3*$stackSpacing]
        set lower [$w create line $h10 $v3 $h11 $v4 $h12 $v5 $mr $v6 \
                $mr $v7 $h12 $v8 $h11 $v9 $h10 $v10 $h9 $v11 $h8 $v12 $h7 $mb \
                $h6 $mb $h5 $v12 $h4 $v11 $h3 $v10 -width $width \
		       -tag "$tagSet size_on_this realwidth($width) has_info"]
        $w move $lower $stackDistance $stackDistance
    }
    ResetColours $w submodel {} $colourScheme [lindex $tagSet 0]
}

proc PutThinArrow { w ptz fatness density colourScheme tagSet} {
    # Have to use eval because points are packed in a list -- what a language
    set width [GetLineSize $w influence $fatness]
    set features [GetObjectSize $w influence $fatness]
    set mptz [ScaleList $w $ptz]
    if {[string equal dashed $density]} {
	set density {}
	set dashClause "-dash -"
    } else {
	set dashClause {}
    }
    eval {$w create line} $mptz $dashClause {-arrow last \
                -arrowshape [list [expr $features/6] [expr $features/5] \
                [expr $features/16]] -smooth true -width $width \
                -tag "$tagSet realwidth($width) has_info"}
    
    # next few lines put blob with diameter equal to width of
    # arrowhead at start of line
    DrawBlob $w [lindex $mptz 0] [lindex $mptz 1] [expr $features/10] \
            "$tagSet startblob"
    ResetColours $w influence $density $colourScheme [lindex $tagSet 0]
}

proc PutRelation { w ptz fatness colourScheme tagSet} {
    global looks
    # Have to use eval because points are packed in a list -- what a language
    set width [expr 5*[GetLineSize $w relation $fatness]]
    set arrowRad [expr [GetObjectSize $w relation $fatness]/10]
    
    set mptz [ScaleList $w $ptz]
    eval {$w create line} $mptz {-arrow last \
                -arrowshape [list $arrowRad [expr 1.5*$arrowRad] $arrowRad] \
                -smooth true -width $width \
				     -tag "$tagSet realwidth($width) has_info"}
    # next few lines put blob with diameter equal to width of arrowhead at start of
    # line
    DrawBlob $w [lindex $mptz 0] [lindex $mptz 1] [expr 2*$arrowRad] \
            "$tagSet startblob"
    ResetColours $w relation gray50 $colourScheme [lindex $tagSet 0]
}

proc PutFatArrow { w ptz fatness colourScheme tagSet} {
    global looks
    
    set width [expr 5*[GetLineSize $w flow $fatness]]
    set features [GetObjectSize $w flow $fatness]
    #    set width [Scale $w [expr $fatness/10.0]]
    set mptz [ScaleList $w $ptz]
    set arrowRad [expr $features/10]
    eval {$w create line} $mptz {-arrow last -arrowshape \
                [list $arrowRad [expr 1.5*$arrowRad] $arrowRad] -smooth false \
		      -width $width -tag "$tagSet realwidth($width) has_info"}
    DrawBlob $w [lindex $mptz 0] [lindex $mptz 1] [expr 2*$arrowRad] \
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
#	Scaled {
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
#	} Tiled {
	    # Using builtin tiling is slow when starting from a small image --
	    # This version was inspired by the opening titles of Dilbert

    # note that actually tiling is slow because it creates images with
    # complicated transparent areas -- the Dilbert process just slows it
    # down more by adding overheads so has been removed

#	    image create photo spare2
#	    spare2 copy $fCol
#	    while {$srcWidth<$mw} {
#		puts [list spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#			  -to $srcWidth 0]
#		spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#		    -to $srcWidth 0 -compositingrule set
#		set srcWidth [expr 2*$srcWidth]
#	    }
#	    while {$srcHeight<$mh} {
#		puts [list spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#			  -to 0 $srcHeight]
#		spare2 copy spare2 -from 0 0 $srcWidth $srcHeight \
#		    -to 0 $srcHeight -compositingrule set
#		set srcHeight [expr 2*$srcHeight]
#	    }
#	}
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
    set mptz [ScaleList $w $ptz]
    eval {$w move [GetCaptionItem $w $id]} $mptz
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
        } elseif {[string match line [$w type $item]] && \
                    ![string match *bowtie* $taglist]} {
            eval "$w coords $item" $mptz
        }
    }
}

proc MoveBowtie {w id ptz} {
    scan [ScaleList $w $ptz] {%f %f %f %f} ml mt mr mb
    
    foreach item [$w find withtag $id] {
        set type [$w type $item]
        if {[string match *bowtie* [$w gettags $item]] || \
                    [string match polygon $type]} {
            scan [$w coords $item] {%f %f} oldl oldt
            if {($mb - $mt) > ($mr - $ml)} {
                $w coords $item $ml $mt $mr $mt $ml $mb $mr $mb $ml $mt
            } else {
                $w coords $item $ml $mt $ml $mb $mr $mt $mr $mb $ml $mt
            }
        } elseif {[string match text $type]} {
            set captionId $item
        }
    }
    if {[info exists captionId]} {
        $w move $captionId [expr $ml - $oldl] [expr $mt - $oldt]
    }
}

proc DrawBlob {w startX startY size tags} {
     $w create line $startX $startY $startX $startY -width $size \
            -capstyle round -tag "$tags realwidth($size)"
}

# This puts random bits of normally non-editable text on the screen...

proc PutText { w ptz type tagSet fatness colourScheme capt } {
    global looks
    
    if {[string compare $colourScheme normal]} {
        set textColor $looks($type,$colourScheme)
    } else {
        set textColor $looks($type,text)
    }
    
    set fontData [ExtractFontData $looks($type,font)]
    set realFont [Scale $w [lindex $fontData 3]*$fatness/100]
#    if {$realFont<10} {
#        set closeFont 10
#    } else {
#        set closeFont [expr round($realFont)]
#    }
    set useFont [AssembleFont [lindex $fontData 0] [lindex $fontData 1] \
            [lindex $fontData 2] $realFont]
    set textX [Scale $w [expr [lindex $ptz 0] \
            + $looks($type,xoffset)*$fatness/100]]
    set textY [Scale $w [expr [lindex $ptz 1] \
            + $looks($type,yoffset)*$fatness/100]]
    $w create text $textX $textY -text $capt -fill $textColor \
	-font $useFont -anchor $looks($type,textanchor) \
	-tag "$tagSet is_caption size_on_this realwidth($realFont) has_info"
}

# This is called when a new node with a caption is added. The caption should be
# initially selected and editable, but if the mode is not select, nothing else
# should be editable

proc SelectText {w node} {
    global pushedbutton
    set new [GetCaptionItem $w $node]
    if {![string equal select $pushedbutton]} {
	$w dtag currently_editable
	$w itemconfig $new -tag [concat currently_editable [$w gettags $new]]
    }
    $w focus $new
    $w select from $new 0
    $w select to $new end
}

# This procedure colours the symbol outline with the given identifier, by first
# searching for all the graphical components that make it up and then
# either filling or outlining them depending on the method appropriate to their
# type.

proc ColorSymbol { w name type density colorSpec } {
    global looks
    
    if {[string match cloud $type]} {
        set type flow
    }
    if {[string compare $colorSpec normal]} {
        set outlineColor $looks($type,$colorSpec)
        set textColor $outlineColor
    } else {
        set outlineColor $looks($type,outline)
        set textColor $looks($type,text)
    }
    FlashSymbol $w $name $outlineColor $textColor
    StippleSymbol $w $name $density $colorSpec
}

proc FlashSymbol {w name outlineColor textColor} {
    foreach object [$w find withtag $name] {
        switch -regexp [$w type $object] {
            text {$w itemconfigure $object -fill $textColor}
            line {
                $w itemconfigure $object -fill $outlineColor
            } oval {
                $w itemconfigure $object -outline $outlineColor
            }
        }
    }
}

proc StippleSymbol {w name density selected} {
    foreach object [$w find withtag $name] {
        switch -regexp [$w type $object] {
            line {
                $w itemconfigure $object -stipple $density
            }
            rectangle|arc|polygon {
                $w itemconfigure $object -stipple $density
            }
        }
	switch -regexp $selected {
	    highlight|target {
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
    }
}

proc FillSymbol { w name color } {
    foreach object [$w find withtag $name] {
        foreach outlinable_type "rectangle oval polygon" {
            if {[string compare [$w type $object] $outlinable_type] == 0 && \
		    ![string match */background/* [$w gettags $object]]} {
                $w itemconfigure $object -fill $color
            }
        }
    }
}

proc ResetColours { w type density colourScheme name } {
    global looks
    
    ColorSymbol $w $name $type $density $colourScheme
    set fillColor $looks($type,fill)
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
    fconfigure $stream -translation binary
    set title [wm title [winfo parent $canvas]]
    puts $stream "# written on $date"
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
            puts $stream [list MakeImage $sourceImage $localImage \
                    [$localImage cget -width] [$localImage cget -height] $posn]
        }
        # Do not write base objs they get re-created
        if {[string match */base/* [$canvas gettags $object]]} {
        } else {
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
        }
    }
    close $stream
}

proc MakeImage {base inst w h args} {
    global looks
    #    if {![info exists imageSources($base)]} {
    #	image create photo $base
    #	$base read $file -shrink
    #	PutSize $base
    #	set imageSources($base) $file
    #    }
    image create photo $inst -width $w -height $h
    set shortSide [expr $w<$h?$w:$h]
    set intRad [expr int($looks(submodel,objectsize)*$shortSide/400)]
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
                    foreach fmt {gif jpeg} {
                        if {![catch {$image read $imgFile.$fmt -shrink}]} {
                            $image config -format $fmt
                            PutSize $image
                            file delete $imgFile
                        }
                    }
                    # prevent crasho if reading fails
		    if {[string match {} [$image cget -format]]} {
			$image read ../Images/splash.gif -shrink
			$image config -format gif
			PutSize $image
		    }
                } out {
                    set fmt [$image cget -format]
                    #ShowMessage debug info "Writing $imgFile.$fmt" ok
                    $image write $imgFile.$fmt -format $fmt
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
    global window_info
    set w [expr $window_info($c,width)+4]
    set h [expr $window_info($c,height)+4]
    source $canvasFile
    # At this point we may have loaded something with a scrollregion smaller than
    # the current window. In this case TweakWindow (from the .cnv file) will have
    # loaded this region as the new window size, so we 'grow' the window back to
    # its previous size which we saved. The xview and yview cmds here work around
    # a tcl bug that if the scrollregion is smaller than the window it may not all
    # be displayed.
    update idletasks
    $c xview moveto 0
    $c yview moveto 0
    SetSpace $c $w $h
}

proc GetCaptionItem {w name} {
    foreach object [$w find withtag $name] {
        if {[string compare [$w type $object] text] == 0} {
            set taglist [$w gettags $object]
            if {[string match *is_caption* $taglist]} {
                return $object
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

# This zooms canvas in or out. Because it can be done in response to a
# resize request from Prolog we need a special parameter (arg 3) to stop
# Prolog being called back in this instance, because a loop would happen
# sometimes due to rounding errors.

proc DoZoom { winId factor toProlog} {
    global window_info

    # First, find canvas point at centre of display
    set centre_x [expr $window_info($winId,width)/2]
    set centre_y [expr $window_info($winId,height)/2]

    # Now work out where this should be in the image, so I can put it back in the
    # centre afterwards

    set target_x [expr [$winId canvasx $centre_x]*$factor]
    set target_y [expr [$winId canvasy $centre_y]*$factor]

    # next make sure that enough canvas exists for the outcome of the operation
    RollBack $winId $toProlog [expr (1 - 1/$factor)*$centre_x] \
            [expr (1 - 1/$factor)*$centre_y] \
            [expr (1 + 1/$factor)*$centre_x] \
            [expr (1 + 1/$factor)*$centre_y]

    # Next, scale all the window objects (centre must be 0 because all canvas/desktop
    # translation is done relative to 0)

    ZoomImage $winId all $factor

    # Change the canvas area in accordance with the change in scale

    set oldSize [$winId cget -scrollregion]
    set newReg [list [expr [lindex $oldSize 0]*$factor] \
            [expr [lindex $oldSize 1]*$factor] \
            [expr [lindex $oldSize 2]*$factor] \
            [expr [lindex $oldSize 3]*$factor]]
    $winId configure -scrollregion $newReg

    # Find what is in the middle now

    set currentX [$winId canvasx $centre_x]
    set currentY [$winId canvasy $centre_y]

    # Now scroll it so what was previously in the middle of the display is still there

    $winId xview scroll [expr round($target_x - $currentX)] units
    $winId yview scroll [expr round($target_y - $currentY)] units
}

# ZoomImage: Scale the graphical stuff in the window, and explicitly
# change line thicknesses, arrowhead sizes and font sizes
# of all components for new display size (Tcl does not change these
# when zooming). Font sizes have a separate parameter to enable them to come
# out right when zooming prior to Postscript export.

proc ZoomImage {winId which factor {optFontor none}} {
    #ShowMessage debug info "ZoomImage $winId $which $factor $fontor" ok
    global window_info looks

    $winId scale $which 0 0 $factor $factor
    if {[string compare $which all]} {
        set objList [$winId find withtag $which]
    } else {
        set objList [$winId find all]
        # and update the info...(if it's there)
        catch {set window_info($winId,scale) \
                    [expr $window_info($winId,scale) * $factor]}

	scan [$winId cget -scrollregion] "%g %g %g %g" bl bt br bb
	ResizeBackgnd $winId $bl $bt $br $bb
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
		set intRad [expr int($looks(submodel,objectsize)* \
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
    global window_info
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

    # First, find canvas point at centre of display
    set CurrentX [$winId canvasx [expr $window_info($winId,width)/2]]
    set CurrentY [$winId canvasy [expr $window_info($winId,height)/2]]

    # Now find canvas point at centre of selected rectangle after zoom
    set centre_x [expr $factor*($bl+$br)/2]
    set centre_y [expr $factor*($bt+$bb)/2]

    # Now scroll it so what should be in the middle of the display is there

    $winId xview scroll [expr round($centre_x - $CurrentX)] units
    $winId yview scroll [expr round($centre_y - $CurrentY)] units
}

set adds none

proc FindCaption {canvas} {
    global find
    set findable [GetFindText $canvas]
    if {[string compare $findable {}]} {
        set find(List,$canvas) {}
        foreach caption [$canvas find withtag is_caption] {
            if {[string match *$findable* [ForSearchType $canvas $caption]]} {
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
    global looks find window_info
    if {![info exists find(List,$canvas)]} {
        ShowMessage "Operation failed" error "No search in progress!" ok
        return
    }
#    if {[info exists find(now,$canvas)]} {
#	prolog event:do_colours($find(now,$canvas),off)
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
        unset find
    } else {
        set this [lindex $find(List,$canvas) 0]
        set find(List,$canvas) [lrange $find(List,$canvas) 1 end]
        #	$canvas itemconfigure $this -fill blue
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
        #	HandleObjClick $canvas $this clicktext $tgtX $tgtY
        #	ReleaseObj $canvas $tgtX $tgtY
    }
}

# Create image at load time to avoid confusion caused by possible changed directory
# (But then I can't change its colour...)
# set looks(brushmap) [image create bitmap -file brush.xbm]

proc Customize {winId mode} {
    global looks done window_info
    
    set looks(width) 200
    
    set t [toplevel .customize -bd 4]
    wm transient $t $winId
    
    switch -regexp $mode {
        condition|creation|immigration|reproduction|loss {
            set object channel
            wm title $t "Customize conditions and channels"
        } move|copy|ghost|select|delete {
            set object generic
            wm title $t "Customize all components"
        } default {
            set object $mode
            wm title $t "Customize $object appearance"
        }
    }
    
    if {[string compare $object influence]} {
        frame $t.textsize
        label $t.textsize.what -text "Text size: "
        pack $t.textsize.what -side left
        scale $t.textsize.scale -from 10 -to 250 -length $looks(width) \
                -orient horizontal -showvalue false -resolution 1 \
                -command "ZotFont $t"
        pack $t.textsize.scale -side left
        pack $t.textsize
        
        frame $t.font
        label $t.font.what -text "Font: "
        pack $t.font.what -side left
        tk_optionMenu $t.font.family looks($object,family) \
                helvetica times system courier symbol
        bind $t.font.family.menu <Leave> "ZotFont $t 120"
        pack $t.font.family -side left
        tk_optionMenu $t.font.weight looks($object,weight) \
                bold normal
        bind $t.font.weight.menu <Leave> "ZotFont $t 120"
        pack $t.font.weight -side left
        tk_optionMenu $t.font.style looks($object,style) \
                italic roman
        bind $t.font.style.menu <Leave> "ZotFont $t 120"
        pack $t.font.style -side left
        pack $t.font
    }
    
    canvas $t.canvas -width [expr $looks(width) + 50] \
            -height [expr $looks(width) + 50]
    set window_info($t.canvas,scale) 1
    pack $t.canvas
    
    label $t.tell -text "Drag text by chosen anchor to set default position"
    pack $t.tell
    
    frame $t.setcolours
    foreach flashType {outline fill text} {
        button $t.setcolours.$flashType -text "Set $flashType" \
                -command "ZotColor $t setcolours $flashType $object"
        pack $t.setcolours.$flashType -side left
    }
    pack $t.setcolours
    
    frame $t.flashcolours
    foreach flashType {select highlight target incomplete} {
        button $t.flashcolours.$flashType -text "Set $flashType" \
                -command "ZotColor $t flashcolours $flashType $object"
        pack $t.flashcolours.$flashType -side left
    }
    pack $t.flashcolours
    
    frame $t.objectsize
    label $t.objectsize.what -text "Relative size: "
    pack $t.objectsize.what -side left
    scale $t.objectsize.scale -from 0 -to $looks(width) \
            -length $looks(width) -orient horizontal -showvalue false \
            -resolution 1 -command "ZotObjectSize $t $object"
    pack $t.objectsize.scale -side left
    pack $t.objectsize
    
    frame $t.lines
    label $t.lines.what -text "Line thickness: "
    pack $t.lines.what -side left
    scale $t.lines.scale -from 0 -to 10 -length $looks(width) \
            -orient horizontal -showvalue false -resolution 0.05 \
            -command "ZotObjectSize $t $object"
    pack $t.lines.scale -side left
    pack $t.lines
    
    frame $t.actions
    button $t.actions.load -text "Load" -command "ReadLooks $t $object"
    pack $t.actions.load -side left
    button $t.actions.save -text "Save" -command "SaveLooks $t $object"
    pack $t.actions.save -side left
    button $t.actions.normal -text "Normalize" -command "LoadLooks $t $object normal"
    pack $t.actions.normal -side left
    button $t.actions.done -text "Done" -command "set done 1"
    pack $t.actions.done -side left
    button $t.actions.apply -text "Apply" -command "ApplyLooks $t $object"
    pack $t.actions.apply -side left
    button $t.actions.cancel -text "Cancel" -command "set done 0"
    pack $t.actions.cancel -side left
    pack $t.actions
    LoadLooks $t $object $object
    RememberLooks $object
    
    grab $t
    tkwait variable done
    grab release $t
    if {$done} {
        ApplyLooks $t $object
    } else {
        array set looks $looks(safe)
    }
    destroy $t
}

proc LoadLooks {t target object} {
    global looks
    
    if {[string compare $target influence]} {
        #ShowMessage debug info "ExtractFontData looks($object,font) [ExtractFontData $looks($object,font)]" ok
        scan [ExtractFontData $looks($object,font)] "%s %s %s %d" \
                looks($target,family) looks($target,weight) \
                looks($target,style) textsize
        $t.textsize.scale set $textsize
    }
    
    foreach flash {outline fill text} {
        $t.setcolours.$flash configure -activebackground $looks($object,$flash)
    }
    foreach flash {select highlight target incomplete} {
        $t.flashcolours.$flash configure -activebackground $looks($object,$flash)
    }
    
    $t.objectsize.scale set $looks($object,objectsize)
    $t.lines.scale set $looks($object,lines)
    
    set middle [expr $looks(width)/2 + 25]
    DoGraphics $t $target $middle $looks($object,objectsize)
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
    set textsize [expr [font actual $font -size]*12.0]
    #ShowMessage debug info "ExtractFontData [list $family $weight $style $textsize]" ok
    return [list $family $weight $style $textsize]
}
proc CopyLooks {t object} {
    global looks
    if {[string compare $object influence]} {
        set looks($object,font) [ResetFont $t]
        UpdateOffsets $t $object
        set looks($object,textanchor) [GetTextAnchor $t]
    }
    foreach colour {outline fill text} {
        set looks($object,$colour) \
                [$t.setcolours.$colour cget -activebackground]
    }
    foreach colour {select highlight target incomplete} {
        set looks($object,$colour) \
                [$t.flashcolours.$colour cget -activebackground]
    }
    set looks($object,objectsize) [$t.objectsize.scale get]
    set looks($object,lines) [$t.lines.scale get]
}

proc DoGraphics {box type middle size} {
    global looks
    $box.canvas delete sample
    
    switch -regexp $type {
        compartment {
            set l [expr $middle - 2*$size/5]
            set r [expr $middle + 2*$size/5]
            set t [expr $middle - 3*$size/10]
            set b [expr $middle + 3*$size/10]
        }
        submodel {
            set l [expr $middle - 80]
            set r [expr $middle + 80]
            set t [expr $middle - 60]
            set b [expr $middle + 60]
        }
        flow {
            set l [expr $middle - $size/4]
            set r [expr $middle + $size/4]
            set t [expr $middle - $size/8]
            set b [expr $middle + $size/8]
        }
        function | variable {
            set l [expr $middle - 3*$size/20]
            set r [expr $middle + 3*$size/20]
            set t [expr $middle - 3*$size/20]
            set b [expr $middle + 3*$size/20]
        }
        channel {
            set l [expr $middle - 3*$size/10]
            set r [expr $middle + 3*$size/10]
            set t [expr $middle - 3*$size/10]
            set b [expr $middle + 3*$size/10]
        }
        default {
            set l [expr $middle - $size/2]
            set r [expr $middle + $size/2]
            set t [expr $middle - $size/2]
            set b [expr $middle + $size/2]
        }
    }
    
    if {[string compare $type submodel]} {
        set xbase $middle
        set ybase $middle
    } else {
        set xbase $l
        set ybase $t
    }
    
    if {[string compare $type influence]} {
        PutText $box.canvas [list $xbase $ybase] \
                $type "sample movable" 100 normal "Sample $type"
        set looks(cheat) [$box.canvas coords movable]
        $box.canvas bind movable <Button-1> {SampleMark %x %y %W}
        $box.canvas bind movable <B1-Motion> {%W coords movable %x %y}
    }
    
    switch -regexp $type {
        compartment {PutRectangle $box.canvas $l $t $r $b 1 100 {} \
                    normal "sample"}
        channel {PutShape $box.canvas $l $t $r $b \
                    condition 100 normal "sample"}
        function {PutHexagon $box.canvas $l $t $r $b 100 1 {} \
                    normal "sample"}
        variable {PutCrossedCirc $box.canvas $l $t $r $b 100 1 {} \
                    normal "sample"}
        submodel {PutRoundedRect $box.canvas $l $t $r $b 3 100 clear \
                    none none normal "sample"}
        flow {
            PutBowTie $box.canvas $l $t $r $b 100 {} normal "sample"
            PutFatArrow $box.canvas "25 [expr $middle-25] $middle \
                    [expr $middle - 25] $middle [expr $middle + 25] \
                    [expr 2*$middle - 25] [expr $middle + 25]" \
                    100 normal "sample"
        }
        influence {PutThinArrow $box.canvas "25 $middle $middle \
                    [expr $middle-25] [expr 2*$middle - 25] $middle" \
                    100 {} normal "sample"
        }
        relation {PutRelation $box.canvas "25 $middle $middle \
                    [expr $middle-25] [expr 2*$middle - 25] $middle" \
                    100 normal "sample"
        }
    }
}

proc SampleMark { x y w } {
    # during drag xoffset and yoffset are relative to its start...not any more!
    # now we pick the closest apex to the clicked point, snap to that and then do
    # an absolute drag!
    
    global looks
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
    
    $w itemconfigure movable -anchor $a1$a2
    $w coords movable $x $y
}

proc ResetFont { t } {
    return [AssembleFont [$t.font.family cget -text] \
            [$t.font.weight cget -text] \
            [$t.font.style cget -text] \
            [$t.textsize.scale get]]
            #[string index [$t.font.style cget -text] 0]
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
    $t.canvas itemconfigure movable -font [ResetFont $t]
}

proc ZotColor {t frame role type} {
    set newColour [tk_chooseColor -initialcolor \
            [$t.$frame.$role cget -activebackground]]
    $t.$frame.$role configure -activebackground $newColour
    CopyLooks $t $type
    ResetColours $t.canvas $type {} normal sample
}

proc ZotObjectSize {t type size} {
    global looks
    
    set middle [expr $looks(width)/2 + 25]
    if {[string match generic $type]} {
        set useLooks compartment
    } else {
        set useLooks $type
    }
    
    CopyLooks $t $useLooks
    DoGraphics $t $useLooks $middle [$t.objectsize.scale get]
}

proc UpdateOffsets {t type} {
    global looks
    set offsets [$t.canvas coords movable]
    set looks($type,xoffset) [expr $looks($type,xoffset) + \
            [lindex $offsets 0] - [lindex $looks(cheat) 0]]
    set looks($type,yoffset) [expr $looks($type,yoffset) + \
            [lindex $offsets 1] - [lindex $looks(cheat) 1]]
}

proc GetTextAnchor {t} {
    $t.canvas itemcget movable -anchor
}

proc ResetLooks {type} {
    global looks
    
    set looks($type,font) [AssembleFont Helvetica bold roman 120]
    set looks($type,outline) black
    set looks($type,fill) $looks(buttonColor)
    set looks($type,text) black
    set looks($type,select) blue3
    set looks($type,highlight) cyan4
    set looks($type,target) green4
    set looks($type,affect) green2
    set looks($type,incomplete) red3
    
    set looks($type,objectsize) 50
    set looks($type,lines) 1
    set looks($type,xoffset) 0
    set looks($type,yoffset) 0
    set looks($type,textanchor) n
}

proc CustomizeLooks {} {
    global looks
    
    #    prolog tk_set_new_size(compartment,30,0,0)
    #    prolog tk_set_new_size(variable,15,0,0)
    #    prolog tk_set_new_size(function,15,0,0)
    #    prolog tk_set_new_size(cloud,25,0,0)
    #    prolog tk_set_new_size(channel,30,0,0)
    set looks(flow,xoffset) 12
    set looks(flow,yoffset) 12
    set looks(flow,textanchor) nw
    set looks(compartment,yoffset) 16
    set looks(channel,yoffset) 16
    set looks(variable,yoffset) 8
    set looks(submodel,textanchor) sw
}

proc Desystematize {colorSpec} {
    set rgb [winfo rgb . $colorSpec]
    return [format "#%02x%02x%02x" [lindex $rgb 0] \
            [lindex $rgb 1] [lindex $rgb 2]]
}

proc ApplyLooks {t type} {
    RememberLooks $type
    if {[string compare $type generic]} {
	CopyLooks $t $type
        ExportLooks $t $type
    } else {
        foreach object {generic compartment channel function variable \
                    submodel flow influence relation} {
            CopyLooks $t $object
            ExportLooks $t $object
        }
    }
}

proc RememberLooks {object} {
    global looks
    set looks(safe) [array get looks $object,*]
}

proc ExportLooks {t type} {
    global looks window_info
    
    prolog [format "tk_change_size(%s,%d,%f,%f)" $type $looks($type,objectsize) \
            $looks($type,xoffset) $looks($type,yoffset)]
    if {[string match flow $type]} {
        prolog [format "tk_change_size(%s,%d,%f,%f)" cloud $looks($type,objectsize) \
                $looks($type,xoffset) $looks($type,yoffset)]
    }
    #	foreach windae [array name window_info *,parent] {
    #		set canvas [string trimright $windae ,parent]
    #	}
}

proc ReadLooks {t type} {
    global looks
    
    set customFile [ChooseFile looks.cus "Choose a customization file" 0]
    set stream [NetOpen $customFile r]
    
    while {[gets $stream elementName] >= 0} {
        gets $stream elementValue
        if {[string match "$type,*" $elementName] || \
                    [string compare $type generic] == 0} {
            set looks($elementName) $elementValue
        }
    }
    
    close $stream
    LoadLooks $t $type $type
    if {[string match generic $type]} {
        foreach object {generic compartment channel function variable \
                    submodel flow influence} {
            ExportLooks $t $object
        }
        destroy $t
    }
}

proc SaveLooks {t type} {
    global looks
    
    set customFile [ChooseFile looks.cus "Name for customization file" 1]
    set stream [NetOpen $customFile w]
    
    foreach element [array names looks] {
        puts $stream $element
        puts $stream $looks($element)
    }
    close $stream
}

button .b
set looks(buttonColor) [Desystematize [.b cget -bg]]
set looks(darkerColor) [Desystematize [.b cget -disabledforeground]]
set looks(windowColor) white
destroy .b

