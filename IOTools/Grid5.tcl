# grid4 == grid3.tcl modified by Jasper for photo image type
# grid5 == grid4.tcl modified by Robert for more compact, more 
#          professional-looking display

# grid3.tcl		--	Robert Muetzelfeldt   10 August 2000
# SimCity-style spatial grid display, complies to 4.x helper
# app interface standard

set keyValue grid005
namespace eval grid005 {

    variable useNodes
    variable cell_ids
    variable old_icolour

proc identify {} {
	return "Spatial grid display v5"
}

proc initialize {winId} {
    variable useNodes
    namespace import -force ::maptools::*
    set useNodes($winId,cbot) black
    set useNodes($winId,cmid) red
    set useNodes($winId,ctop) white
    set useNodes($winId,nswatches) 32
    set useNodes($winId,integer) 0
    SetColours useNodes $winId
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
    recolour_scale $winId
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
   set full_label [GetCaptionPathFromId $node]
   set full_label1 [string range $full_label 9 end]
   set last_slash [string last / $full_label1]
   set start_label [expr $last_slash+1]
    set label [string range $full_label1 $start_label end]
    catch {wm title $winId $label}
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

    if {[string compare [lindex [GetState $winId] 0] displaying] == 0} then {
	DrawGrid5 $winId $useNodes($winId,display1)
    }
}

proc InitialiseGrid {winId display1} {

variable useNodes

set useNodes($winId,min) [GetMinValue $display1]
set useNodes($winId,max) [GetMaxValue $display1]
set useNodes($winId,range) [expr $useNodes($winId,max)-$useNodes($winId,min)]
#InsertLegend useNodes $winId
#ColourScale useNodes $winId


frame $winId.f
canvas $winId.c 
pack $winId.f -expand yes -fill both -padx 1 -pady 1
grid rowconfig    $winId.f 0 -weight 1 -minsize 0
grid columnconfig $winId.f 0 -weight 1 -minsize 0

grid $winId.c -padx 1 -in $winId.f -pady 1 \
    -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news

# This is an experimental section to set up the grid display just once,
# when the helper is initialised, so that subsequently all that happens
# is that cell colours are re-set.

if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
   set n $useNodes($winId,nrow)
} else {
   set n $useNodes($winId,ncol)
}
set mult [expr int(250/$n)]
set useNodes($winId,mult) $mult
set xwidth [expr $mult*$useNodes($winId,ncol)]
set yheight [expr $mult*$useNodes($winId,nrow)+20]
set useNodes($winId,xwidth) $xwidth
set useNodes($winId,yheight) $yheight
$winId.c configure -width $xwidth -height $yheight

$winId.c create text 47 $yheight -text $useNodes($winId,min) -anchor se
$winId.c create text [expr $xwidth-48] $yheight -text $useNodes($winId,max) \
   -anchor sw

set xmin 50
set xmax [expr $xwidth-50]
set xincr [expr ($xmax-$xmin)/33]
for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
   set x0 [expr $xmin+$icolour*$xincr]
   set x1 [expr $x0+$xincr]
   set colour $useNodes($winId,c$icolour)
   $winId.c create rectangle $x0 $yheight $x1 [expr $yheight-16] -outline {} \
      -fill $colour -tag colour_scale
}


$winId.c bind all <Button-3> [namespace code "show_window $winId"]
$winId.c bind all <B1-Motion> [namespace code "value_popup $winId $mult %x %y"]
$winId.c bind all <ButtonPress-1> [namespace code "value_popup $winId $mult %x %y"]
$winId.c bind all <B1-ButtonRelease> [namespace code "RemovePopup"]

set useNodes($winId,hiddenMap) [image create photo]
set useNodes($winId,visibleMap) [image create photo]
$winId.c create image 0 0 -anchor nw -image $useNodes($winId,visibleMap)

DrawGrid5 $winId $display1
$winId.c configure -scrollregion [$winId.c bbox all]
}



proc show_value {winId x y} {
}



proc recolour_scale {winId} {
variable useNodes

$winId.c delete colour_scale

if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
   set n $useNodes($winId,nrow)
} else {
   set n $useNodes($winId,ncol)
}
set mult [expr int(250/$n)]
set xwidth [expr $mult*$useNodes($winId,ncol)]
set yheight [expr $mult*$useNodes($winId,nrow)+20]

set xmin 50
set xmax [expr $xwidth-50]
set xincr [expr ($xmax-$xmin)/33]
for {set icolour 0} {$icolour <= $useNodes($winId,nswatches)} {incr icolour} {
   set x0 [expr $xmin+$icolour*$xincr]
   set x1 [expr $x0+$xincr]
   set colour $useNodes($winId,c$icolour)
   $winId.c create rectangle $x0 $yheight $x1 [expr $yheight-16] -outline {} \
      -fill $colour -tag colour_scale
}

}



proc show_window {winId} {
   set winopts .gridoptions
   toplevel $winopts
frame $winopts.buttons
pack $winopts.buttons -side bottom -fill x -pady 2m
button $winopts.buttons.colbot -text "Low colour" \
	-command [namespace code "Recolour $winId bot"]
button $winopts.buttons.colmid -text "Middle colour" \
	-command [namespace code "Recolour $winId mid"]
button $winopts.buttons.coltop -text "High colour" \
	-command [namespace code "Recolour $winId top"]
button $winopts.buttons.zoomin -text "Zoom in" \
	-command [namespace code "zoomin $winId"]
button $winopts.buttons.zoomout -text "Zoom out" \
	-command [namespace code "zoomout $winId"]
checkbutton $winopts.buttons.freeze -text "Freeze" \
	-command [namespace code "display $winId 0 0 0"] \
	-variable [namespace current]::useNodes($winId,freeze)
pack $winopts.buttons.colbot $winopts.buttons.colmid $winopts.buttons.coltop \
	$winopts.buttons.zoomin $winopts.buttons.zoomout $winopts.buttons.freeze \
	-side top -expand 1
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




proc DrawGrid5 {winId node} {
variable useNodes

set values [Flatten [lindex [GetModelValue $node] 0] {}]
set useNodes($winId,values) $values

set ncell [llength $values]

# Data must be from a singly-nested fixed membership model, 
# or an indexless conditional model inside one
# Note: tried to optimise (e.g. by use of holding variables for array
# elements), since this is the time-critical part.

set allData {}
#set rowData {}
set min $useNodes($winId,min)
set range $useNodes($winId,range)

#for {set cell 0} {$cell<$ncell} {incr cell} {
#    set celval [lindex $values $cell]
#    set length [llength $celval]
#
#    if {$length} {
#	if {$length>1} {set celval [lindex $celval 1]}
#	set icolour [expr int(32*($celval-$min)/$range)]
#	lappend rowData $useNodes($winId,c$icolour)
#    } else {
#      lappend rowData grey
#    }
#
#    if {[llength $rowData] == $useNodes($winId,nrow)} {
#	lappend allData $rowData
#	set rowData {}
#    }
#}

set ncol $useNodes($winId,ncol)
set nrow $useNodes($winId,nrow)

for {set row 1} {$row<=$nrow} {incr row} {
   set rowData($row) {}
   for {set col 1} {$col<=$ncol} {incr col} {
      set cell [expr ($row-1)*$ncol+$col-1]
      set celval [lindex $values $cell]
      set length [llength $celval]

      if {$length} {
         if {$length>1} {set celval [lindex $celval 1]}
         set icolour [expr int(32*($celval-$min)/$range)]
         lappend rowData($row) $useNodes($winId,c$icolour)
      } else {
         lappend rowData($row) grey
      }
    }
 }

for {set row $nrow} {$row>=1} {incr row -1} {
   lappend allData $rowData($row)
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


#### Handle value popup
proc value_popup {winId mult X Y} {
    variable useNodes

    PostValuePopup $winId $X $Y
    set height1 [expr $useNodes($winId,yheight)-19]
    if {$X>1&&$X<$useNodes($winId,xwidth)&&$Y>1&&$Y<$height1} {    
       set ncol $useNodes($winId,ncol)
       set nrow $useNodes($winId,nrow)
       set col [expr int(($X-2)/$mult+1)]
       set row [expr $nrow-int(($Y-2)/$mult)]
       set cell [expr ($row-1)*$ncol+$col-1]
       set value [lindex $useNodes($winId,values) $cell]
       set index [expr $cell+1]
    
       pack [message .popup.message -aspect 400 \
	    -text "Index=$index\nCol,row=($col,$row)\nValue=$value" -bg #ffffc0] -fill x -expand true
       set x0 [winfo x $winId]
       set y0 [winfo y $winId]
       set xpoint [expr $X+$x0+15]
        set ypoint [expr $Y+$y0+43]
        wm geometry .popup +$xpoint+$ypoint
       update
    }
}
 
proc PostValuePopup {winId X Y} {
    variable useNodes

    if {[winfo exists .popup]} {
	destroy .popup
    }
    set height1 [expr $useNodes($winId,yheight)-19]
    if {$X>1&&$X<$useNodes($winId,xwidth)&&$Y>1&&$Y<$height1} {
       toplevel .popup -width 1 -height 1 -bd 2 -relief raised
       wm overrideredirect .popup 1
       raise .popup
   }
}

proc RemovePopup {} {
    if {[winfo exists .popup]} {
	destroy .popup
    }
}


} ;
# end of namespace
