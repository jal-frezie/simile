# Polygons.TCL 
# Option to input co-ordinates from a file Robert Muetzelfeldt April 2002
# Option to set the value of the displayed variable Jonathan Massheder August 2001

# Very simple polygon drawer for Simile, complies to 4.x helper
# app interface standard
# This version enables polygon coordinate data to come from
# a file containing a tcl 'list of lists' for the x coords, and another
# for the y coords.
# Adapted from original polygon mapper, written by Jasper Taylor


set keyValue polygon375

namespace eval ::polygon375 {
	variable useNodes
    variable newVal
    variable editMode
    
proc identify {} {
	return "Polygon diagram"
}

proc initialize {winId} {
    variable useNodes
    variable editMode 0

    namespace import -force ::maptools2::*

    set useNodes($winId,cbot) black
    set useNodes($winId,cmid) green
    set useNodes($winId,ctop) white
   

########## start polyfile changes
    set useNodes($winId,sourcefile) [coords_source]

    if {[string compare $useNodes($winId,sourcefile) model]==0} then {
	set ms [message $winId.intro -text "Click on the array value \
			representing the X coordinates of the polygon vertices."]
	GrabClicks $winId
	pack $ms
	set useNodes($winId,state) xcoord
    } else {
      set chxy [open $useNodes($winId,sourcefile) r]
      set useNodes($winId,xys) [read $chxy]
	set ms [message $winId.intro -text "Click on the array value \
			representing the data to be mapped."]
	GrabClicks $winId
	pack $ms
	set useNodes($winId,state) sizeval
    }
########## end polyfile changes

	SetState $winId {}
}

proc OptionsDialog { winId } {
    variable useNodes
    set dlg [Dialog .polygonOptionsDlg -parent . -modal local \
            -separator 0 \
            -title   "Polygon diagram options" \
            -parent  $winId  \
            -default 0 -cancel 1]
    $dlg add -name ok
    $dlg add -name cancel
    
    set scaleF [TitleFrame $dlg.scalef -text Scale]
    SpinBox $scaleF.minSB -label "Minimum" -underline 0 \
            -labelwidth 10 -labelanchor w \
            -range {1 100 1} -textvariable {} \
            -helptext "Minimum value on the scale"
    SpinBox $scaleF.maxSB -label "Maximum" -underline 2 \
            -labelwidth 10 -labelanchor w \
            -range {1 100 1} -textvariable {} \
            -helptext "Maximum value on the scale"
            
    pack $scaleF.minSB $scaleF.maxSB -pady 4 -fill x
    
    set coloursF [TitleFrame $dlg.coloursf -text "Colour gradient"]
    set toplabf  [LabelFrame $coloursF.topf -text "Top colour"]
    set topcolor [SelectColor [$toplabf getframe].topcol -type menubutton]
    set midlabf  [LabelFrame $coloursF.midf -text "Middle colour"]
    set midcolor [SelectColor [$midlabf getframe].midcol -type menubutton]
    set lowlabf  [LabelFrame $coloursF.lowf -text "Low colour"]
    set lowcolor [SelectColor [$lowlabf getframe].lowcol -type menubutton]
    
    pack $topcolor $midcolor $lowcolor -side left -padx 5 -anchor w
    pack $toplabf $midlabf $lowlabf -side left -padx 5 -anchor w
    

    pack $scaleF $coloursF -pady 4 -fill x
    
    $dlg draw
    destroy $dlg
}

proc Restore {winId} {
    variable useNodes
    variable editMode 0
    
    namespace import -force ::maptools::*

    regsub -all /WIN/ [GetState $winId] $winId restoreString
    array set useNodes $restoreString

    DrawPolys $winId $useNodes($winId,xcoord) \
        $useNodes($winId,ycoord) \
        $useNodes($winId,color)
}

proc GetCanvas {winId} {
    return $winId.viewport.c
}

proc click {winId node caption} {
    variable useNodes

	set ms $winId.intro
	set testResult [GetModelValue $node]

# This tests for the user having clicked on a suitable element 
# of the model diagram
	if {[string compare $testResult novalue]} {

########## Start polyfile changes
# This tests for whether the polygon coordinates come from variables
# in the model diagram (first option) or from file.
    if {[string compare $useNodes($winId,sourcefile) model]==0} then {

	switch $useNodes($winId,state) {
		xcoord {
			$ms configure -text "Now click on the value representing the Y coordinates."
			set useNodes($winId,xcoord) $node
			set useNodes($winId,state) ycoord
			}
		ycoord {
			$ms configure -text "Now select a value to determine the colour of the objects."
			set useNodes($winId,ycoord) $node
			set useNodes($winId,state) sizeval
			}
		sizeval {
			pack forget $ms
			ReleaseClicks $winId
            set useNodes($winId,color) $node
            catch {wm title $winId "$caption (polygon diagram)"}; # if not a toplevel, ie MRE
            SetColours2 $winId $node
            DrawPolys $winId $useNodes($winId,xcoord) \
				$useNodes($winId,ycoord) \
				$node
			set useNodes($winId,state) displaying
		}
         }
      } else {

	switch $useNodes($winId,state) {
		sizeval {
			pack forget $ms
			ReleaseClicks $winId
			set useNodes($winId,color) $node
            catch {wm title $winId "$caption (polygon diagram)"}; # if not a toplevel, ie MRE
            SetColours2 $winId $node
			DrawPolys $winId {} {} $node
			set useNodes($winId,state) displaying
            }
	     }
      }
########## end polyfile changes

	UpdateState $winId
} else {
		$ms configure -text \
			"This component does not have a value; please choose a compartment, variable or flow."
    }
}

proc SetColours2 {winId node} {
    variable useNodes
    set useNodes($winId,integer) [string match INTEGER [GetModelType $node]]
    set useNodes($winId,min) [GetMinValue $node]
    set useNodes($winId,max) [GetMaxValue $node]
    set useNodes($winId,range) \
            [expr $useNodes($winId,max)-$useNodes($winId,min)]
    if [expr !$useNodes($winId,integer) || [expr $useNodes($winId,range) > 32]] {
        set useNodes($winId,nswatches) 32
    } else  {
        set useNodes($winId,nswatches) \
                [expr int($useNodes($winId,range)+fmod($useNodes($winId,range),2))]
        set useNodes($winId,max) \
                [expr $useNodes($winId,max)\
                +fmod($useNodes($winId,range),2)]
    }
#    ShowMessage debug info "min $useNodes($winId,min); \
#            max $useNodes($winId,max); $useNodes($winId,range); \
#            $useNodes($winId,nswatches)" ok
    SetColours useNodes $winId
}

proc UpdateState {winId} {
    variable useNodes

    regsub -all $winId [array get useNodes $winId,*] /WIN/ saveString
    SetState $winId $saveString
}

proc display {winId time step remainder} {
	variable useNodes
	Repaint $winId $useNodes($winId,color)
}

proc Recolour {winId whichCol} {
    variable useNodes
    set useNodes($winId,c$whichCol) \
	    [tk_chooseColor -initialcolor $useNodes($winId,c$whichCol)]
    SetColours useNodes $winId
    UpdateState $winId
    ColourScale useNodes $winId
    Repaint $winId $useNodes($winId,color)
    display $winId 0 0 0
}

proc Repaint {winId hs} {
    variable useNodes
    set values [lindex [GetModelValue $hs] 0]
    set quadlist {}
    GetQuadList {} $values
    array set quadarray $quadlist
    foreach id [array names quadarray] {
        set indxs [join $id ,]
        set value [lindex $quadarray($id) 0]
        set polyId [$winId.viewport.c find withtag n$indxs]
        CanvasBindPopup $winId.viewport.c $polyId \
                [list Index $id Value [lindex $quadarray($id) 0]]
        set newColour [ColourFor $winId [lindex $quadarray($id) 0]]
        if {![string match $newColour \
                    [$winId.viewport.c itemcget $polyId -fill]]} {
            $winId.viewport.c itemconfigure $polyId -fill $newColour
        }
    }
}
    
proc DrawPolys {winId xs ys hs} {
    variable viewpoint
    variable useNodes

    InsertLegend useNodes $winId
    ColourScale useNodes $winId
    
# not finished yet    bind $winId.legend.scale <Double-Button-1> \
#            [namespace code "OptionsDialog $winId"]

    catch {wm geometry $winId 650x500}; # if not a toplevel, ie MRE
    pack [set vp [frame $winId.viewport]] -fill both -expand true
    scrollbar $vp.xsc -orient horizontal -command [list $vp.c xview]
    pack $vp.xsc -side bottom -fill x
    scrollbar $vp.ysc -orient vertical -command [list $vp.c yview]
    pack $vp.ysc -side right -fill y
    canvas $vp.c -width 10 -height 10 -xscrollcommand [list $vp.xsc set] \
	    -yscrollcommand [list $vp.ysc set] -bg beige \
	    -scrollregion {0 0 10 10}
    pack $vp.c -fill both -expand true

    frame $winId.buttons
    pack $winId.buttons -side bottom -fill x -pady 2m
    button $winId.buttons.colbot -text "Low colour" \
    	-command [namespace code "Recolour $winId bot"]
    button $winId.buttons.colmid -text "Middle colour" \
    	-command [namespace code "Recolour $winId mid"]
    button $winId.buttons.coltop -text "Top colour" \
    	-command [namespace code "Recolour $winId top"]
    button $winId.buttons.zoomin -text "Zoom in" \
    	-command [namespace code "Zoom $vp.c 2 2"]
    button $winId.buttons.zoomout -text "Zoom out" \
    	-command [namespace code "Zoom $vp.c 0.5 0.5"]
    button $winId.buttons.zoomfit -text "Zoom to fit" \
    -command [namespace code "Fit $winId $vp.c"]
    button $winId.buttons.edit -text "Enter edit mode" \
            -command [namespace code "ChangeEditMode $winId"]
    message $winId.buttons.msg -aspect 1000
    pack $winId.buttons.msg -fill x -side bottom -expand 1
    pack $winId.buttons.colbot $winId.buttons.colmid $winId.buttons.coltop \
    	$winId.buttons.zoomin $winId.buttons.zoomout $winId.buttons.zoomfit \
        $winId.buttons.edit -side left
    
########## start polyfile changes
if {[string compare $useNodes($winId,sourcefile) model]==0} then {
   set xcoords [lindex [GetModelValue $xs] 0]
   set ycoords [lindex [GetModelValue $ys] 0]
} else {
   set xcoords [lindex $useNodes($winId,xys) 0]
   set ycoords [lindex $useNodes($winId,xys) 1]
}
########## end polyfile changes

   for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
       bind $winId.legend.pop$swatch <Double-Button-1> \
               [namespace code "SetSwatchColour $winId %W"]
   }

    set quadlist {}
	GetQuadList {} [lindex [GetModelValue $hs] 0] $xcoords $ycoords

# previous line appended variable quadlist at this level, now to use it
# ShowMessage debug info "Got quadlist $quadlist" ok
	array set quadarray $quadlist
	foreach id [array names quadarray] {
	    set quad $quadarray($id)
        set corners ""
#        ShowMessage debug info [lindex $quad 2] ok
        set polyycorrds {}
        set i 0
        set j 1
        set tmp [lindex $quad 2]
#        ShowMessage debug info $tmp ok
        while {$i < [llength [lindex $quad 2]]} {
            lappend polyycorrds [lindex $tmp $i]
            incr i 2
            set ttmp [lindex $tmp $j]
#        ShowMessage debug info "ttmp $ttmp" ok
            lappend polyycorrds [expr $ttmp * -1]
            incr j 2
        }
#        ShowMessage debug info $polyycorrds ok
        Interweave corners [lindex $quad 1] $polyycorrds
	    set indxs [join $id ,]
#        ShowMessage debug info $corners ok
        set polyId [eval {$winId.viewport.c create polygon} $corners \
                {-outline black -tag n$indxs }] ;
    }
    Repaint $winId $hs
    Zoom $vp.c 0.5 0.5
}

proc ColourFor {winId value} {
    variable useNodes
    if {[string match nil $value]} {
        set newColour gray
    } else {
        set newColour $useNodes($winId,c[expr int(\
                $value*$useNodes($winId,nswatches)\
                /$useNodes($winId,range)-$useNodes($winId,min) )])
    }
}

proc ChangeEditMode {winId} {
    variable editMode
    variable useNodes
    if $editMode==1 {
        set editMode 0
        $winId.buttons.msg configure -text ""
        $winId.buttons.edit configure -text "Enter edit mode"
        for  {set j 0} {$j <= $useNodes($winId,nswatches)} {incr j} {
            $winId.legend.pop$j configure -borderwidth 0
        }
        bind $winId.viewport.c <B1-Motion> {}
    } else  {
        set editMode 1
        $winId.buttons.msg configure -text \
                "Click on the colour bar to select the value to \
                'paint' polygons."
        $winId.buttons.edit configure -text "Leave edit mode"
        #  bind mouse click to get the value to assign from the colour clicked upon
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            bind $winId.legend.pop$swatch <ButtonPress> \
                    [namespace code "GetNewVal $winId $swatch"]
        }
   }
}

proc ChangeValue {winId X Y } {
    variable useNodes
    variable newVal
    
    set X [$winId.viewport.c canvasx $X]
    set Y [$winId.viewport.c canvasy $Y]
    set overlapping [$winId.viewport.c find closest $X $Y 1]
    set tags [$winId.viewport.c gettags $overlapping]
    # should check to see if the tags are different before processing them to speed things up
    set end [expr {[string first "current" $tags ]-1}] ; # index of space delimeter after first tag
    
    # chop the leading n off the tag e.g. n12
    # and trailing "current"
    # chop the leading n off the tag e.g. n12
    
    if {$end > 0} then {
        set index [string range $tags 1 $end]
    } else  {
        set index [string range $tags 1 end]
    }
    set tags [string trim $tags]
    
#$winId.buttons.msg configure -text \
#    "X $X; Y $Y; tags $tags; overlapping $overlapping; index $index"
    
    if {[string length $index]>0} {
        set vals [lindex [GetModelValue $useNodes($winId,color)] 0]
        set i [expr {2*$index - 1}]
        set pilot [lindex $vals $i]
        if {[llength $pilot]==1} {
            set newvals [lreplace $vals $i $i $newVal]
        } elseif {[llength $pilot]==2} {
            set newvals [lreplace $vals $i $i [list {} $newVal]]
        }
        
        if [info exists newvals] {
            SetModelValue $useNodes($winId,color) $newvals
        }
    }   
    Repaint $winId $useNodes($winId,color)
}

proc GetNewVal {winId i} {
    variable newVal
    variable useNodes
    set newVal [expr {int($useNodes($winId,min) + 0.5 + \
                $i * $useNodes($winId,range) /$useNodes($winId,nswatches))}]
    for  {set j 0} {$j <= $useNodes($winId,nswatches)} {incr j} {
        $winId.legend.pop$j configure -borderwidth 0
    }
    $winId.legend.pop$i configure -relief ridge -borderwidth 2
    $winId.buttons.msg configure -text \
            "Drag over the polygons you wish \
            to change the colour (value) of."
    #    $winId.buttons.msg configure -text "new value $newVal"; # 1 $1 todo; debug line
    $winId.viewport.c configure -cursor spraycan
    bind $winId.viewport.c <B1-Motion> [namespace code "ChangeValue $winId %x %y"]
    bind $winId.viewport.c <Button-1> [namespace code "ChangeValue $winId %x %y"]
}

proc Fit {winId canId} {
    scan [winfo geometry $winId] {%dx%d+} boxw boxh
    scan [$canId bbox all] {%d %d %d %d} cl ct cr cb
    Zoom $canId [expr ($boxw-30.0)/($cr-$cl)] [expr ($boxh-30.0)/($cb-$ct)]
}

proc Zoom {id fx fy} {
    variable useNodes
    $id scale all [$id canvasx 325] [$id canvasy 250] $fx $fy
    $id configure -scrollregion [$id bbox all]
}

proc OldGetQuadList {heights xcoords ycoords} {

	upvar 1 quadlist quadlist
	if {[llength $heights] == 1} {
		lappend quadlist [list $xcoords $ycoords $heights]
	} else {
		array set newxs $xcoords
		array set newys $ycoords
		array set newhs $heights

		foreach elt [array names newhs] {
			OldGetQuadList $newhs($elt) $newxs($elt) $newys($elt)
		}
	}
}

#proc GetQuadList {args}
proc GetQuadList {inds args} {
	upvar 1 quadlist quadlist
    
    set pilot [lindex $args 0]
    if {![llength $pilot]} {
        set args [lreplace $args 0 0 nil]
    } elseif {[llength $pilot]==2 && ![llength [lindex $pilot 0]]} {
        set args [lreplace $args 0 0 [lindex $pilot 1]]
    }
    if {[llength [lindex $args 0]] == 1} {
		lappend quadlist $inds $args
	} else {
	    set arrcount 0
	    foreach arg $args {
		array set new$arrcount $arg
		incr arrcount
	    }

	    foreach elt [array names new0] {
		set arrcount 0
		set newargs {}
		foreach arg $args {
		    upvar 0 new$arrcount newarr
		    lappend newargs $newarr($elt)
		    incr arrcount
		}
#		eval GetQuadList $newargs
		eval GetQuadList [list [concat $inds $elt]] $newargs
	    }
	}
}

# this is not used, because what it does needs to be integrated with
# the last one
proc GetIdList {listNest} {
    if {[llength $listNest]==1} {
	return {}
    } else {
	set results {}
	for {set pt 0} {$pt < [llength $listNest]} {incr pt 2} {
	    foreach subResult [GetIdList [lindex $listNest [expr $pt+1]]] {
		lappend results [concat [lindex $listNest $pt] $subResult]
	    }
	}
	return $results
    }
}

proc Interweave {target xs ys} {
	upvar 1 $target outlist
	if {[llength $xs]} {
    lappend outlist [lindex $xs 1] [lindex $ys 1]
#ShowMessage debug info "$xs; $ys; $outlist" ok
		Interweave outlist [lrange $xs 2 end] [lrange $ys 2 end]
	}
}
		

proc coords_source {} {
   after idle {.dialog1.msg configure -wraplength 4i}
   set i [tk_dialog .dialog1 "Source of polygon coordinates" {Click on a button to select the source of the polygon coordinates.} \
info 0 {Coords from file} {Coords from model}]

   switch $i {
     0 {set sourcefile [tk_getOpenFile]}
     1 {set sourcefile model} 
    }
    return $sourcefile
}

proc SetSwatchColour { winId swatchId } {
    variable useNodes
    set i [string range $swatchId 19 end]; # remove .helper3.legend.pop5
#    ShowMessage debug info "$swatchId; $i; $useNodes($winId,c$i)" ok
    set useNodes($winId,c$i) \
            [tk_chooseColor -initialcolor $useNodes($winId,c$i) \
            -title "Choose colour" -parent $winId]
#    ShowMessage debug info "$swatchId; $i; $useNodes($winId,c$i)" ok
    $swatchId  configure -bg $useNodes($winId,c$i)
    UpdateState $winId
    Repaint $winId $useNodes($winId,color)
    display $winId 0 0 0
}

} ;
# end of namespace
