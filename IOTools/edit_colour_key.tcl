namespace eval ::EditLegend {
    
    proc MakeColours {} {
	variable nswatches
	variable flags
	
    set result {}
    set section 0
    set locols {0 0 0}
    set lopt -1
    set hicols [winfo rgb . [lindex $flags $section 1]]
    set hipt 0

    for {set sw 0} {$sw<$nswatches} {incr sw} {
	while {$sw>$hipt} {
	    set locols $hicols
	    set lopt $hipt
	    incr section
	    set hipt [lindex $flags $section 0]
	    set hicols [winfo rgb . [lindex $flags $section 1]]
	}
	set fract [expr {1.0*($sw-$lopt)/($hipt-$lopt)}]
	set col #
	for {set ch 0} {$ch<3} {incr ch} {
	    append col [format %04x [expr {round($fract*[lindex $hicols $ch] + (1-$fract)*[lindex $locols $ch])}]]
	}
	lappend result $col
    }
    return $result
}

proc DrawScale {c map} {
    set nswatches [llength $map]
    set bd 4

    $c delete withtag scale
    set r $bd
    for {set count 1} {$count <= $nswatches} {incr count} {
	set l $r
	set r [PosnFromInd $count]
	$c create rect $l [expr {40+$bd}] $r [expr {60+$bd}] \
	    -outline {} -fill [lindex $map $count-1] -tag scale
    }
}

proc IndFromPosn {l} {
    variable nswatches

    set bd 4
    return [expr {int(($l-$bd)*$nswatches/512)}]
}

proc PosnFromInd {n} {
    variable nswatches

    set bd 4
    return [expr {$bd + 512.0*$n/$nswatches}]
}

proc Recolour {c item} {
    variable flags

    set swpos [IndFromPosn [lindex [$c coords $item] 0]]
    set newCol [tk_chooseColor -title "New colour for swatch $swpos" \
		    -parent [winfo parent $c] \
		    -initialcolor [$c itemcget $item -fill]]
    if {$newCol eq {}} return
    $c itemconfig $item -fill $newCol

     set swidx [lsearch -index 0 $flags $swpos]
    lset flags $swidx 1 $newCol
    DrawScale $c [MakeColours]
}

proc RecolourHere {c} {
    set item [$c find withtag current]
    Recolour $c $item
}

proc DrawFlag {c flind col} {
    set bd 4
    set flpos [PosnFromInd $flind]
    $c create line $flpos $bd $flpos [expr {40+$bd}] -arrow last
    return [$c create rect $flpos $bd [expr $flpos+20] [expr {20+$bd}] \
		-outline black -fill $col -tag flag]
}

proc AddFlag {c x} {
    variable flags
    
    set swno [IndFromPosn $x]
    set pos 0
    foreach old $flags {
	if {[lindex $old 0]<$swno} {
	    set icol [lindex $old 1]
	    incr pos
	}
    }
    if {$swno==[lindex $flags $pos 0]} {
	tk_messageBox -parent [winfo parent $c] -icon info \
	    -message "This swatch already has a flag"
	return
    }
    set flags [linsert $flags $pos [list $swno $icol]]
    [winfo parent $c].ctrls.sc config -from [llength $flags]
    Recolour $c [DrawFlag $c $swno $icol]
}

proc SaveMover {c x} {
    variable flags
    variable moverIndex
    variable movingItem
    
    set movingItem [$c find withtag current]
    set l [lindex [$c coords $movingItem] 0]
    set moverIndex [lsearch -index 0 $flags [IndFromPosn $l]]
#    set moverColour [$c itemcget $doomedItem -fill]
#    puts "save $doomedItem $moverIndex $moverColour"
}

proc Reposition {c x} {
    variable flags
    variable moverIndex
    variable movingItem
    
    if {$moverIndex == 0 || $moverIndex == [llength $flags]-1} return
    set newPosn [IndFromPosn $x]
    if {$newPosn != [lindex $flags $moverIndex 0] && \
	    $newPosn > [lindex $flags [expr $moverIndex-1] 0] && \
	    $newPosn < [lindex $flags [expr $moverIndex+1] 0]} {
	set jmp [expr {[PosnFromInd $newPosn] - \
			   [lindex [$c coords $movingItem] 0]}]
	$c move $movingItem $jmp 0
	$c move [expr {$movingItem-1}] $jmp 0
	lset flags $moverIndex 0 $newPosn

	DrawScale $c [MakeColours]
    }
}

proc OfferDeleteAt {c X Y} {
    variable nswatches
    variable flags
    variable doomedItem
    variable doomedIdx
    
    set doomedItem [$c find withtag current]
    set swno [IndFromPosn [lindex [$c coords $doomedItem] 0]]
    if {$swno==0 || $swno==$nswatches-1} return
    set doomedIdx [lsearch -index 0 $flags $swno] 
    $c.flagm post $X $Y
}

proc DeleteFlag {c} {
    variable flags
    variable doomedItem
    variable doomedIdx
    
    $c delete $doomedItem [incr doomedItem -1]
    set flags [lreplace $flags $doomedIdx $doomedIdx]
    [winfo parent $c].ctrls.sc config -from [llength $flags]
    DrawScale $c [MakeColours] 
}

proc AdjustSwatchCount {f pos} {
    variable flags
    variable nswatches

    set nswatches [expr {round($pos)}]
    $f.l configure -text "Swatches: $nswatches"

    set flags {}
    set c [winfo parent $f].c
    foreach flag [$c find withtag flag] {
	lappend flags [list [IndFromPosn [lindex [$c coords $flag] 0]] \
			   [$c itemcget $flag -fill]]
    }
    set flags [lsort -integer -index 0 $flags]
    lset flags end 0 [expr {$nswatches-1}]
    DrawScale $c [MakeColours]
}

proc ReverseEngineerFlags {map} {
    variable flags

    set count 0
    set flags {}
    foreach swatch $map {
	set cols [winfo rgb . $swatch]
	if {!$count} {
	    lappend flags [list $count $swatch]
	    set startCols [set lastCols $cols]
	} else {
	    set mark 0
	    set run [expr {$count-[lindex $flags end 0]}]
	    foreach col $cols startCol $startCols lastCol $lastCols {
		set guessLast [expr {(($run-1)*$col + $startCol)/$run}]
		#puts -nonewline "$guessLast "
		set mark [expr {$mark || abs($lastCol-$guessLast)>255}]
	    }
	    #puts "guessed for $lastCols"
	    if {$mark} {
		lappend flags [list [expr {$count-1}] $lastSwatch]
		set startCols $lastCols
	    }
	}
	set lastCols $cols
	set lastSwatch $swatch
	incr count
    }
    lappend flags [list [expr {$count-1}] $lastSwatch]
}

proc LoadFile {c} {
    variable nswatches
    variable flags

    set RGBfile [ChooseFile scale.rgb [tr. "Load colour scale from:"] 0 {}]
    if {$RGBfile eq {}} return
    set stm [open $RGBfile r]
    while {![eof $stm]} {
	gets $stm line
	set line [string trim $line]
	if {$line eq {} || ![string first \# $line]} continue
	if {[string first ncolors $line]>=0} {
	    regexp {[0-9]+} $line nswatches
	    set map {}
	} else {
	    if {[scan $line %d%d%d r g b]==3} {
		lappend map [format \#%02x%02x%02x $r $g $b]
	    } elseif {[scan $line %f%f%f r g b]==3} {
		lappend map [format \#%02x%02x%02x [expr {int(255*$r)}] \
				 [expr {int(255*$g)}] [expr {int(255*$b)}]]
	    } else {
		DebugMess "dodgd line $line"
	    }
	}
    }
    close $stm
    set fr [winfo parent $c].ctrls
    $fr.sc configure -value $nswatches
    $fr.l configure -text "Swatches: $nswatches"
    DrawScale $c $map
    ReverseEngineerFlags $map

    foreach fltag [$c find withtag flag] {
	$c delete $fltag [incr fltag -1]
    }
    foreach fl $flags {
	DrawFlag $c [lindex $fl 0] [lindex $fl 1]
    }
}

proc SaveFile {} {
    variable nswatches
    variable flags
    
    set RGBfile [ChooseFile scale.rgb [tr. "Save colour scale as:"] 1 {}]
    if {$RGBfile eq {}} return
    set stm [open $RGBfile w]
    puts $stm "\# Created by Simile -- simulistics.com"
    puts $stm ""
    puts $stm "ncolors = $nswatches"
    puts $stm ""
    puts $stm "#   r    g    b"
    foreach col [MakeColours] {
	puts $stm [scan $col #%2x%*2x%2x%*2x%2x%*2x] ;# throw away low byte
    }
    close $stm
}

proc Initialize {topl} {
    variable flags
    variable nswatches

    set bd 4
    pack [set f [ttk::frame $topl.f]] -fill both -expand 1
    pack [message $f.howto -aspect 600 -text {The colour legend is defined by the positions and colours of the flags, changing linearly between them. Double click on a flag to set its colour, or on background of flags to add a new one. Drag a flag to move it, or right click to delete it (except end flags). The slider sets number of swatches (distinct colours) which must be at least the number of flags.}] -fill x -expand true

    pack [set fr [ttk::frame $f.ctrls]] -fill x
    pack [ttk::label $fr.l -width 12 -text "Swatches: $nswatches"] -side left
    pack [ttk::scale $fr.sc -from [llength $flags] -to 256 -value $nswatches \
	      -command [namespace code [list AdjustSwatchCount $fr]]] \
	-side left -fill x -expand 1
    
    pack [set c [canvas $f.c -width [expr {512+2*$bd}] \
		     -height [expr {60+2*$bd}] -bg grey]]
    $c create rect $bd $bd [expr {512+$bd}] [expr {40+$bd}] \
	-outline {} -fill beige -tag addhere

    menu $c.flagm -tearoff 0
    $c.flagm add command -label Delete \
	-command [namespace code [list DeleteFlag $c]]
    
    pack [set fr [ttk::frame $f.btns]] -fill x
    pack [ttk::button $fr.load -text "Load..." \
	      -command [namespace code [list LoadFile $c]]] -side left
    pack [ttk::button $fr.save -text "Save..." \
	      -command [namespace code SaveFile]] -side left
    pack [ttk::button $fr.done -text OK -default active \
	      -command [namespace code "set done 1"]] -side right
    pack [ttk::button $fr.cancel -text Cancel \
	      -command [namespace code "set done 0"]] -side right

    foreach fl $flags {
	DrawFlag $c [lindex $fl 0] [lindex $fl 1]
    }
    
    $c bind flag <Double-1> [namespace code {RecolourHere %W}]
    $c bind addhere <Double-1> [namespace code {AddFlag %W %x}]
    
    $c bind flag <Button-1> [namespace code {SaveMover %W %x}]
    $c bind flag <B1-Motion> [namespace code {Reposition %W %x}]
    $c bind flag <Button-3> [namespace code {OfferDeleteAt %W %X %Y}]
    
    set map [MakeColours]
    DrawScale $c $map
}
}
