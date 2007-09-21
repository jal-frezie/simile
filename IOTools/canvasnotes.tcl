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
	global helperTable

	set cm [menu $c.contextMenu -tearoff 0]
	bind $c <Button-3> [namespace code {StickMenuHere %W %X %Y %x %y}]
	$c bind annotation <Button-1> [namespace code {StartDrag %W %x %y}]
	$c bind annotation <B1-Motion> [namespace code {StepDrag %W %x %y}]
	$c bind annotation <Button-3> \
	    [namespace code {MessTextHere %W %X %Y %x %y}]
	while {![info exists helperTable($c,whichInstance)]} {
	    set c [winfo parent $c]
	}
	set node [$helperTable($c,whichInstance) GetNode]
	$cm add command -label "Add text here" \
	    -command [namespace code "StickTextHere $node"]
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
	set whatNotes(text) [$c find closest [$c canvasx $x] [$c canvasy $y]]
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

    proc StickTextHere {node} {
	global looks
	variable whatNotes

	set whatNotes(text) [$whatNotes(canvas) create text \
				 [$whatNotes(canvas) canvasx $whatNotes(clkx)] \
				 [$whatNotes(canvas) canvasy $whatNotes(clky)] \
				 -fill $looks($node,text,text) \
				 -font $looks($node,text,font) \
				 -text "New text" -tags annotation]
	Properties
    }

    proc MessTextHere {c X Y x y} {
	variable whatNotes

	set whatNotes(canvas) $c
	set whatNotes(text) [$c find closest [$c canvasx $x] [$c canvasy $y]]
	set whatNotes(textProps) 1 ;# do not do context menu
	tk_popup .annotationMenu $X $Y
    }

    proc Properties {} {
	variable whatNotes

	::ttk::dialog .annotationprop -title "Annotation properties" \
	    -detail "Set the content and properties of the text" \
	    -type okcancel -command [namespace code TweakText] \
	    -parent [winfo toplevel $whatNotes(canvas)]
	set dlg [::ttk::dialog::clientframe .annotationprop]
	pack [set txtFrame [labelframe $dlg.txtframe -text Text]]
	pack [text $txtFrame.text -width 40 -height 4] -fill both -expand 1
	$txtFrame.text insert 1.0 \
	    [$whatNotes(canvas) itemcget $whatNotes(text) -text]
	set whatNotes(col) \
	    [$whatNotes(canvas) itemcget $whatNotes(text) -fill]
	pack [button $txtFrame.colour -text "Set colour" \
		  -command [namespace code ChangeColour]] -padx 10 -pady 10
    }

    proc TweakText {btn} {
	variable whatNotes

	if {[string equal ok $btn]} {
	    set dlg [::ttk::dialog::clientframe .annotationprop]
	    $whatNotes(canvas) itemconfigure $whatNotes(text) -text \
		[$dlg.txtframe.text get 1.0 end] -fill $whatNotes(col)
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

    namespace export MakeCanvasAnnotatable ListNotes RestoreNotesFromList
}
