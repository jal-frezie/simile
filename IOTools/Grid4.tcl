# grid4 == grid3.tcl modified by Jasper for photo image type

# grid3.tcl		--	Robert Muetzelfeldt   10 August 2000
# SimCity-style spatial grid display, complies to 4.x helper
# app interface standard

set keyValue grid004a
namespace eval ::$keyValue {

    variable useNodes
    variable cell_ids
    variable old_icolour

proc identify {} {
	return "Spatial grid display v4"
}

proc initialize {winId} {
    variable useNodes
    namespace import -force ::maptools::*

    set useNodes($winId,nswatches) 32
    set useNodes($winId,cbot) black
    set useNodes($winId,cmid) red
    set useNodes($winId,ctop) white
    set ms [message $winId.intro -text \
	    "Click on the variable containing the positions or IDs of the columns."]
    GrabClicks $winId
    pack $ms
    SetState $winId display0
}

proc Recolour {winId whichCol} {
    variable useNodes
    set useNodes($winId,c$whichCol) \
	    [tk_chooseColor -initialcolor $useNodes($winId,c$whichCol)]
    SetColours useNodes $winId
    ColourScale useNodes $winId
    UpdateState $winId
    display $winId 0 0 0
}

proc Restore {winId} {
    variable useNodes
    namespace import -force ::maptools::*

    scan [GetState $winId] "displaying %s colourmap %s %s %s aspect %d %d" \
	    nodePath \
	    useNodes($winId,cbot) useNodes($winId,cmid) useNodes($winId,ctop) \
	    useNodes($winId,nrow) useNodes($winId,ncol)
    set useNodes($winId,display1) [GetIdFromCaptionPath $nodePath] 
    SetColours useNodes $winId
    InitialiseGrid $winId $useNodes($winId,display1) 
}

proc GetCanvas {winId} {
    return $winId.c
}

proc click {winId node caption} {
    variable useNodes
    
    set ms $winId.intro
    set testResult [GetModelValue $node]
    if {[string compare $testResult novalue]} {
	set state [GetState $winId]
	switch $state {
	    display0 {
		set columns [Flatten [lindex $testResult 0] {}]
		foreach col $columns {
		    set colvals($col) 1
		}
		if {[info exists colvals()]} {
		    unset colvals()
		}
		set useNodes($winId,nrow) [array size colvals]
		set useNodes($winId,ncol) \
			[expr [llength $columns]/$useNodes($winId,nrow)]
		$ms configure -text "Grid has $useNodes($winId,nrow) columns and $useNodes($winId,ncol) rows. Now click on the variable to be displayed."
		SetState $winId display1
	    } display1 {
		pack forget $ms
		ReleaseClicks $winId
		set useNodes($winId,display1) $node
		set useNodes($winId,integer) [string match INTEGER \
			[GetModelType $node]]
		SetColours useNodes $winId
		InitialiseGrid $winId $node
		UpdateState $winId
	    }
	}
    } else {
	$ms configure -text \
		"This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc UpdateState {winId} {
    variable useNodes
    SetState $winId [list displaying \
	    [GetCaptionPathFromId $useNodes($winId,display1)] colourmap \
	    $useNodes($winId,cbot) $useNodes($winId,cmid) $useNodes($winId,ctop) \
	    aspect $useNodes($winId,nrow) $useNodes($winId,ncol)]
}

proc display {winId time step remainder} {
    variable useNodes

    if {[string compare [lindex [GetState $winId] 0] displaying] == 0 && \
		!$useNodes($winId,freeze)} {
	DrawGrid4 $winId $useNodes($winId,display1)
    }
}

proc InitialiseGrid {winId display1} {

variable useNodes

set useNodes($winId,min) [GetMinValue $display1]
set useNodes($winId,max) [GetMaxValue $display1]
set useNodes($winId,range) [expr $useNodes($winId,max)-$useNodes($winId,min)]
InsertLegend useNodes $winId
ColourScale useNodes $winId

frame $winId.buttons
pack $winId.buttons -side bottom -fill x -pady 2m
button $winId.buttons.colbot -text "Low colour" \
	-command [namespace code "Recolour $winId bot"]
button $winId.buttons.colmid -text "Middle colour" \
	-command [namespace code "Recolour $winId mid"]
button $winId.buttons.coltop -text "High colour" \
	-command [namespace code "Recolour $winId top"]
button $winId.buttons.zoomin -text "Zoom in" \
	-command [namespace code "zoomin $winId"]
button $winId.buttons.zoomout -text "Zoom out" \
	-command [namespace code "zoomout $winId"]
checkbutton $winId.buttons.freeze -text "Freeze" \
	-command [namespace code "display $winId 0 0 0"] \
	-variable [namespace current]::useNodes($winId,freeze)
pack $winId.buttons.colbot $winId.buttons.colmid $winId.buttons.coltop \
	$winId.buttons.zoomin $winId.buttons.zoomout $winId.buttons.freeze \
	-side left -expand 1

frame $winId.f
scrollbar $winId.hscroll -orient horiz -command "$winId.c xview"
scrollbar $winId.vscroll -command "$winId.c yview"
canvas $winId.c \
	-relief sunken \
	-borderwidth 2 \
	-xscrollcommand "$winId.hscroll set"\
	-yscrollcommand "$winId.vscroll set"
pack $winId.f -expand yes -fill both -padx 1 -pady 1
grid rowconfig    $winId.f 0 -weight 1 -minsize 0
grid columnconfig $winId.f 0 -weight 1 -minsize 0

grid $winId.c -padx 1 -in $winId.f -pady 1 \
    -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
grid $winId.vscroll -in $winId.f -padx 1 -pady 1 \
    -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
grid $winId.hscroll -in $winId.f -padx 1 -pady 1 \
    -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news

# This is an experimental section to set up the grid display just once,
# when the helper is initialised, so that subsequently all that happens
# is that cell colours are re-set.

set useNodes($winId,mult) 8

set useNodes($winId,hiddenMap) [image create photo]
set useNodes($winId,visibleMap) [image create photo]
# blow up a single red pixel to make initial map
# $useNodes($winId,visibleMap) put {{red}}
# $useNodes($winId,hiddenMap) copy $useNodes($winId,visibleMap) \
#	-zoom $useNodes($winId,nrow) $ncolumn
# $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
#	-zoom $useNodes($winId,mult) $useNodes($winId,mult)
$winId.c create image 0 0 -anchor nw -image $useNodes($winId,visibleMap)

set imWidth [expr $useNodes($winId,nrow)*$useNodes($winId,mult)]
set imHeight [expr $useNodes($winId,ncol)*$useNodes($winId,mult)]
for {set textpt 0} {$textpt <= $useNodes($winId,nrow)} {incr textpt 10} {
    set offset [expr $textpt*$useNodes($winId,mult)]
    $winId.c create text $offset 0 -text $textpt -anchor s
    $winId.c create text $offset $imHeight -text $textpt -anchor n
}
for {set textpt 0} {$textpt <= $useNodes($winId,ncol)} {incr textpt 10} {
    set offset [expr $textpt*$useNodes($winId,mult)]
    $winId.c create text 0 $offset -text $textpt -anchor e
    $winId.c create text $imWidth $offset -text $textpt -anchor w
}
DrawGrid4 $winId $display1
$winId.c configure -scrollregion [$winId.c bbox all]
}

proc click_cell {winId c} {
variable useNodes
bell
$c itemconfigure current -fill red
set tags [$c gettags current]
$c create text 250 180 -text "TAGS $tags"
set cell [string range $tags 4 [expr [string first " " $tags]-1]]
$c create text 250 200 -text "xxx $cell xxx"
set cella [expr $cell*2]
$c create text 250 210 -text $cella

set dis1 $useNodes($winId,display1)
set display1 [lindex [GetModelValue $dis1] 0]
set this_colour [expr int([lindex $display1 [expr $cell*2-1]])]
$c create text 250 230 -text "xx $this_colour xx"
}

proc DrawGrid4 {winId dis1} {

variable useNodes

set display1 [Flatten [lindex [GetModelValue $dis1] 0] {}]

set ncell [llength $display1]

# Data must be from a singly-nested fixed membership model, 
# or an indexless conditional model inside one

set allData {}
set rowData {}
for {set cell 0} {$cell<$ncell} {incr cell} {
    set celval [lindex $display1 $cell]
    if {![llength $celval]} {
	lappend rowData grey
    } else {
	if {[llength $celval]>1} {
	    set celval [lindex $celval 1]
	}
	set icolour [expr int(32*($celval-$useNodes($winId,min))/\
		$useNodes($winId,range))]
	lappend rowData $useNodes($winId,c$icolour)
    }
    if {[llength $rowData] == $useNodes($winId,nrow)} {
	lappend allData $rowData
	set rowData {}
    }
}
$useNodes($winId,hiddenMap) put $allData
$useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
	-zoom $useNodes($winId,mult) $useNodes($winId,mult)
}

proc zoomin {winId} {
bell
variable useNodes
set useNodes($winId,mult) [expr 2*$useNodes($winId,mult)]
$useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
	-zoom $useNodes($winId,mult) $useNodes($winId,mult)
$winId.c scale all 0 0 2 2
$winId.c configure -scrollregion [$winId.c bbox all]
}

proc zoomout {winId} {
bell
variable useNodes
set useNodes($winId,mult) [expr $useNodes($winId,mult)/2]
$useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
	-zoom $useNodes($winId,mult) $useNodes($winId,mult) -shrink
$winId.c scale all 0 0 0.5 0.5
$winId.c configure -scrollregion [$winId.c bbox all]
}

proc Flatten {nested flat} {
    for {set i 1} {$i < [llength $nested]} {incr i 2} {
	set subi [lindex $nested $i]
	if {[string match {} $subi]} {
	    lappend flat {}
	} elseif {[llength $subi] == 1} {
	    lappend flat $subi
	} else {
	    set flat [Flatten $subi $flat]
	}
    }
    return $flat
}

} ;
# end of namespace
