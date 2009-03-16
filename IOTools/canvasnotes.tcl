# This adds procedures that may be useful to many different helpers
# (and indeed other bits of Simile) for creating and managing notes
# that can be stuck on a canvas. We need a procedure that can be bound
# to a canvas right click that adds a text item at that point. The
# text then responds like a component caption but without selection,
# i.e., left-click goes edit, drag moves (no select range?), right
# click puts up menu with properties and delete. Also we need to save
# and restore these from our own save string.

namespace eval canvasnotes20070919 {

    set am [menu .annotationMenu -tearoff 0]
    $am add command -label "Text properties..." \
	-command [namespace code Properties]
    $am add command -label Delete -command [namespace code Delete]

    proc MakeCanvasAnnotatable {c {props {}}} {
	set cm [menu $c.contextMenu -tearoff 0]
	bind $c <Button-3> [namespace code {StickMenuHere %W %X %Y %x %y}]
	$c bind annotation <Button-1> [namespace code {StartDrag %W %x %y}]
	$c bind annotation <B1-Motion> [namespace code {StepDrag %W %x %y}]
	$c bind annotation <Button-3> \
	    [namespace code {MessTextHere %W %X %Y %x %y}]
	$cm add command -label "Add text here" \
	    -command [namespace code StickTextHere]
	if {[string length $props]} {
	    $cm add command -label "Properties..." -command $props
	}
    }

    proc StickMenuHere {c X Y x y} {
	variable whatNotes

	if {[info exists whatNotes(textProps)]} {
	    # doing text menu so do not do context menu
	    unset whatNotes(textProps)
	} else {
	    set whatNotes(canvas) $c
	    set whatNotes(clkx) $x
	    set whatNotes(clky) $y
	    tk_popup $c.contextMenu $X $Y
	}
    }

    
    proc StartDrag {c x y} {
	variable whatNotes

	set whatNotes(canvas) $c
	set whatNotes(text) [$c find withtag current]
	set whatNotes(clkx) $x
	set whatNotes(clky) $y
    }

    proc StepDrag {c x y} {
	variable whatNotes

	$c move $whatNotes(text) [expr $x-$whatNotes(clkx)] \
	    [expr $y-$whatNotes(clky)]
	set whatNotes(clkx) $x
	set whatNotes(clky) $y
    }

    proc StickTextHere {} {
	global looks
	variable whatNotes

	set whatNotes(text) [$whatNotes(canvas) create text \
				 [$whatNotes(canvas) canvasx $whatNotes(clkx)] \
				 [$whatNotes(canvas) canvasy $whatNotes(clky)] \
				 -tags annotation]
	Properties
    }

    proc MessTextHere {c X Y x y} {
	variable whatNotes

	set whatNotes(canvas) $c
	set whatNotes(text) [$c find withtag current]
	set whatNotes(textProps) 1 ;# do not do context menu
	tk_popup .annotationMenu $X $Y
    }

    proc DialogInMiddle {c} {
	variable whatNotes

	set whatNotes(canvas) $c.canvas
	set whatNotes(clkx) 100
	set whatNotes(clky) 100

	StickTextHere
    }

    proc Properties {} {
	variable whatNotes

	Dialog .annotationprop -title "Annotation properties" \
	    -parent [winfo parent $whatNotes(canvas)] -modal local \
	    -default 0 -cancel 1
        .annotationprop add -name ok ;# buttons 0
        .annotationprop add -name cancel
	set dlg [GetFrame .annotationprop]
	pack [set txtFrame [labelframe $dlg.txtframe -text Text]]
	pack [text $txtFrame.text -width 40 -height 4] -fill both -expand 1
	set oldText [$whatNotes(canvas) itemcget $whatNotes(text) -text]
	if {![string length $oldText]} {
	    set oldText "New text"
	}
	$txtFrame.text insert 1.0 $oldText	    
	set whatNotes(col) \
	    [$whatNotes(canvas) itemcget $whatNotes(text) -fill]
	pack [scale $txtFrame.scale -orient h -from 1 -to 36 -showvalue 0 \
		  -variable whatNotes(size) -label Size: -resolution 1] \
	    -fill x -expand 1
	set font [$whatNotes(canvas) itemcget $whatNotes(text) -font]
	$txtFrame.scale set [font actual $font -size]
	pack [button $txtFrame.colour -text "Set colour" \
		  -command [namespace code ChangeColour]] -padx 10 -pady 10
	TweakText [.annotationprop draw]
	destroy .annotationprop
    }

    proc BumpSize {bigs} {
# not used because the entry window changes size and looks messy
	[GetFrame .annotationprop].txtframe.text config -font "-size $bigs"
    }

    proc TweakText {btn} {
	variable whatNotes

	if {!$btn} { ;# ok
	    set dlg [GetFrame .annotationprop]
	    $whatNotes(canvas) itemconfigure $whatNotes(text) -text \
		[$dlg.txtframe.text get 1.0 end] -fill $whatNotes(col) \
			 -font "-size [$dlg.txtframe.scale get]"
	}
# in any case do not leave null strings around
	if {![string length [$whatNotes(canvas) itemcget \
				 $whatNotes(text) -text]]} {
	    $whatNotes(canvas) delete $whatNotes(text)
	}

    }

    proc ChangeColour {} {
	variable whatNotes
	
	if {[string length \
		 [set col [tk_chooseColor -initialcolor $whatNotes(col)]]]} {
	    set whatNotes(col) $col
	}
    }

    proc Delete {} {
	variable whatNotes

	$whatNotes(canvas) delete $whatNotes(text)
    }

    proc ListNotes {c} {
# adapted from WriteDesc in shapes.tcl
	set saveString {}
	foreach object [$c find withtag annotation] {
	    set config {}
	    foreach conf [$c itemconfigure $object] {
                set default [lindex $conf 3]
                set value [lindex $conf 4]
                if {[string match $default $value.0]} {
                    set value $default
                }
                if {[string compare $default $value]} {
                    lappend config [lindex $conf 0] $value
                }
	    }
	    lappend saveString [$c coords $object] $config
	}
	return $saveString
    }

    proc RestoreNotesFromList {c saveString} {
	foreach {coords opts} $saveString {
	    eval [list $c create text] $coords $opts
	} 
    }

    namespace export MakeCanvasAnnotatable DialogInMiddle \
	ListNotes RestoreNotesFromList
}
