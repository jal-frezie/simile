# Polygons.TCL
# Option to input co-ordinates from a file Robert Muetzelfeldt April 2002
# Option to set the value of the displayed variable Jonathan Massheder August 2001

# Very simple polygon drawer for Simile, complies to 4.x helper
# app interface standard
# This version enables polygon coordinate data to come from
# a file containing a tcl 'list of lists' for the x coords, and another
# for the y coords.
# Adapted from original polygon mapper, written by Jasper Taylor

# settings colours see grid5

set keyValue polygon375

namespace eval ::polygon375 {
    variable useNodes
    variable newVal
    
    proc identify {} {
        return "Polygon diagram"
    }
    
    proc initialize {winId} {
        variable useNodes
        set useNodes($winId,editMode) 0
        namespace import -force ::maptools2::*
        
        set useNodes($winId,min) 0
        set useNodes($winId,max) 100

        set useNodes($winId,cbot) black
        set useNodes($winId,cmid) green
        set useNodes($winId,ctop) white
        
	set useNodes($winId,scalex) 1.0
	set useNodes($winId,scaley) 1.0

	AddToolBar $winId
        set NToolButtons [$winId.bbframe.buttonBox index last]
        for {set i 1} {$i<=$NToolButtons} {incr i} {
            $winId.bbframe.buttonBox itemconfigure $i -state disable
        }
    }
    
    proc AddToolBar {winId} {
        variable displayUpdate
	set displayUpdate($winId) 1
        set toolbarItems [list \
                [list add.gif "Add a variable"   [namespace code "AddVariable $winId"]]\
                [list zoomin.gif "Zoom in" [namespace code "Zoom $winId 2 2"] ]\
                [list zoomout.gif "Zoom out" [namespace code "Zoom $winId 0.5 0.5"] ]\
                [list zoomfit.gif "Zoom to fit" [namespace code "Fit $winId"] ]\
	            [list property.gif " Properties " [namespace code "Settings $winId"] ]\
			      [list edit.gif "Enter edit mode " [namespace code "ChangeEditMode [namespace current] $winId"]] \
                [list refresh.gif Update [namespace code "Update $winId"]]]

        ::graphtools::MakeToolBar $winId $toolbarItems
    }

    proc AddVariable {winId} {
        variable useNodes
        ########## start polyfile changes
        set useNodes($winId,sourcefile) [coords_source]
        
        if {[string compare $useNodes($winId,sourcefile) model]==0} then {
            set ms [message $winId.intro -text "Click on the array value \
                    representing the X coordinates of the polygon vertices."]
            GrabClicks $winId
            pack $ms
            set useNodes($winId,state) xcoord
        } else {
            set ms [message $winId.intro -text "Click on the array value \
                    representing the data to be mapped."]
            GrabClicks $winId
            pack $ms
            set useNodes($winId,state) sizeval
        }
        ########## end polyfile changes
        
        SetState $winId {}
    }
    
    proc Restore {winId} {
        variable useNodes
        set useNodes($winId,editMode) 0
        namespace import -force ::maptools2::*
        
        AddToolBar $winId
	regsub -all /WIN/ [GetState $winId] $winId restoreString
        array set useNodes $restoreString
	CaptionsToNodeIds $winId
        
        if {[string compare $useNodes($winId,sourcefile) model]==0} then {
	    DrawPolys $winId $useNodes($winId,xcoord) \
		$useNodes($winId,ycoord) \
		$useNodes($winId,color)
	    set ZoomCmd "Zoom $winId $useNodes($winId,scalex) \
$useNodes($winId,scaley)"
	    set useNodes($winId,scalex) 1.0
	    set useNodes($winId,scaley) 1.0
	    eval $ZoomCmd
	} else {
	    DoFrame $winId
	    foreach {type coords tags} $useNodes($winId,shapes) {
		eval {$winId.viewport.c create $type} $coords {-outline black \
								  -tag $tags}
	    }
	    Repaint $winId $useNodes($winId,color)
	}
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
                        SetColourMap useNodes $winId $node
                        DrawPolys $winId $useNodes($winId,xcoord) \
                                $useNodes($winId,ycoord) \
                                $node
                        set useNodes($winId,state) displaying
			UpdateState $winId
                    }
                }
            } else {
                
                switch $useNodes($winId,state) {
                    sizeval {
                        pack forget $ms
                        ReleaseClicks $winId
                        set useNodes($winId,color) $node
                        catch {wm title $winId "$caption (polygon diagram)"}; # if not a toplevel, ie MRE
                        SetColourMap useNodes $winId $node
                        DrawPolys $winId {} {} $node
                        set useNodes($winId,state) displaying
			UpdateState $winId
                    }
                }
            }
            ########## end polyfile changes
            
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc UpdateState {winId} {
        variable useNodes
        NodeIdsToCaptions $winId
        regsub -all $winId [array get useNodes $winId,*] /WIN/ saveString
	CaptionsToNodeIds $winId
        SetState $winId $saveString
    }
    
    proc NodeIdsToCaptions {winId} {
	variable useNodes
	foreach nodeRole [UsedNodes $winId] {
	    set useNodes($winId,$nodeRole) \
		[GetCaptionPathFromId $useNodes($winId,$nodeRole)]
	}
    }

    proc CaptionsToNodeIds {winId} {
	variable useNodes
	foreach nodeRole [UsedNodes $winId] {
	    set useNodes($winId,$nodeRole) \
		[GetIdFromCaptionPath $useNodes($winId,$nodeRole)]
	}
    }

    proc UsedNodes {winId} {
	variable useNodes
	if {[string equal model $useNodes($winId,sourcefile)]} {
	    return {xcoord ycoord color}
	} else {
	    return {color}
	}
    }

    proc reset {winId} {
    }

    proc display {winId time step remainder} {
        variable useNodes
	variable displayUpdate
	if {$displayUpdate($winId)} {
	    Repaint $winId $useNodes($winId,color)
	}
    }
    
    proc Recolour {winId whichCol exampleWidget} {
        variable useNodes
        set useNodes($winId,c$whichCol) \
	    [tk_chooseColor -initialcolor $useNodes($winId,c$whichCol)]
	$exampleWidget configure -bg $useNodes($winId,c$whichCol)
        SetColours useNodes $winId
        UpdateState $winId
	recolour_scale [namespace current] $winId
#        ColourScale useNodes $winId
        Repaint $winId $useNodes($winId,color)
    }

    proc Update {winId} {
        variable useNodes
        Repaint $winId $useNodes($winId,color)
    }

    proc Repaint {winId hs} {
        variable useNodes
	set useNodes($winId,datamin) 1e100
	set useNodes($winId,datamax) -1e100
        set values [lindex [GetModelValue $hs] 0]
        set quadlist {}
        GetQuadList {} $values
        array set quadarray $quadlist
        foreach id [array names quadarray] {
            set indxs [join $id ,]
            set dispIndxs [join [TransEnums $useNodes($winId,allETs) $id] ,]
            set value [lindex $quadarray($id) 0]
	    if {$value < $useNodes($winId,datamin)} {
		set useNodes($winId,datamin) $value
	    }
	    if {$value > $useNodes($winId,datamax)} {
		set useNodes($winId,datamax) $value
	    }
            foreach polyId [$winId.viewport.c find withtag [IdToTag $indxs]] {
		CanvasBindPopup $winId.viewport.c $polyId \
                    [list Index $dispIndxs Value \
			 [TransValue $useNodes($winId,dataETs) $value]]
		set newColour [ColourFor $winId $value]
		if {![string match $newColour \
			  [$winId.viewport.c itemcget $polyId -fill]]} {
		    $winId.viewport.c itemconfigure $polyId -fill $newColour
		}
            }
        }
    }
    
    proc DoFrame {winId} {
        pack [set vp [frame $winId.viewport]] -fill both -expand true
        scrollbar $vp.xsc -orient horizontal -command [list $vp.c xview]
        pack $vp.xsc -side bottom -fill x
        scrollbar $vp.ysc -orient vertical -command [list $vp.c yview]
        pack $vp.ysc -side right -fill y
        canvas $vp.c -width 10 -height 10 \
	    -xscrollcommand [namespace code [list ScrollMe $winId x]] \
	    -yscrollcommand [namespace code [list ScrollMe $winId y]] \
	    -bg beige -scrollregion {0 0 10 10}
        pack $vp.c -fill both -expand true
	recolour_scale [namespace current] $winId
	bind $vp.c <Configure> \
	    [namespace code "recolour_scale [namespace current] $winId"]
    }

    proc ScrollMe {winId way args} {
	eval {$winId.viewport.${way}sc set} $args
	reposn_scale [namespace current] $winId
    }

	
    proc DrawPolys {winId xs ys hs} {
        variable viewpoint
        variable useNodes
        
        message $winId.msg -aspect 1000
#        InsertLegend useNodes $winId
        
        
        # not finished yet    bind $winId.legend.scale <Double-Button-1> \
        #            [namespace code "OptionsDialog $winId"]
        
        catch {wm geometry $winId 650x500}; # if not a toplevel, ie MRE
        DoFrame $winId

        ################################################################################
        #         frame $winId.buttons
        #         pack $winId.buttons -side bottom -fill x -pady 2m
        #         button $winId.buttons.colbot -text "Low colour" \
        #                 -command [namespace code "Recolour $winId bot"]
        #         button $winId.buttons.colmid -text "Middle colour" \
        #                 -command [namespace code "Recolour $winId mid"]
        #         button $winId.buttons.coltop -text "Top colour" \
        #                 -command [namespace code "Recolour $winId top"]
        #         button $winId.buttons.zoomin -text "Zoom in" \
        #                 -command [namespace code "Zoom $vp.c 2 2"]
        #         button $winId.buttons.zoomout -text "Zoom out" \
        #                 -command [namespace code "Zoom $vp.c 0.5 0.5"]
        #         button $winId.buttons.zoomfit -text "Zoom to fit" \
        #                 -command [namespace code "Fit $winId $vp.c"]
        #         button $winId.buttons.edit -text "Enter edit mode" \
        #                 -command [namespace code "ChangeEditMode $winId"]
        #         pack $winId.buttons.colbot $winId.buttons.colmid $winId.buttons.coltop \
        #                 $winId.buttons.zoomin $winId.buttons.zoomout $winId.buttons.zoomfit \
        #                 $winId.buttons.edit -side left
        ################################################################################
        
#        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
#            bind $winId.legend.pop$swatch <Double-Button-1> \
#                    [namespace code "SetSwatchColour $winId %W"]
#        }
        
        ########## start polyfile changes

# If coords are from file, try to draw the polygons using the dxf tool. If this
# fails, load the coords in the model output format and continue as per drawing
# from model data

        if {[string compare $useNodes($winId,sourcefile) model]} then {
	    if {[lsearch {.dxf .DXF} \
		     [file extension $useNodes($winId,sourcefile)]] != -1} {
		set coordSource 2
		::dxf::AddMap $useNodes($winId,sourcefile) $winId.viewport.c
	    } else {
		set coordSource 1		
		set chxy [open $useNodes($winId,sourcefile) r]
		set useNodes($winId,xys) [read $chxy]
		set xcoords [lindex $useNodes($winId,xys) 0]
		set ycoords [lindex $useNodes($winId,xys) 1]
		close $chxy
	    }
        } else {
	    set coordSource 0
            set xcoords [lindex [GetModelValue $xs] 0]
            set ycoords [lindex [GetModelValue $ys] 0]
	}		

	if {$coordSource != 2} {
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
			    {-outline black -tag [list map [IdToTag $indxs]]}]
	    }
	}

	if {$coordSource != 0} {
	    # Now copy the poly info into the state so it can be saved
	    set useNodes($winId,shapes) {}
	    foreach poly [$winId.viewport.c find all] {
		lappend useNodes($winId,shapes) \
		    [$winId.viewport.c type $poly] \
		    [$winId.viewport.c coords $poly] \
		    [$winId.viewport.c gettags $poly]
	    }
        }
        ########## end polyfile changes

	set NToolButtons [$winId.bbframe.buttonBox index last]
        $winId.bbframe.buttonBox itemconfigure 0 -state disable; #disable the add var button
	for {set i 1} {$i<=$NToolButtons} {incr i} {
	    $winId.bbframe.buttonBox itemconfigure $i -state normal
	}
        Repaint $winId $hs
    }
    
    proc ColourFor {winId value} {
        variable useNodes
        if {[string match nil $value]} {
            set newColour gray
        } else {
	    set colNum [max 0 [min $useNodes($winId,nswatches) [expr \
		        int(($value-$useNodes($winId,min))* \
			$useNodes($winId,nswatches)/$useNodes($winId,range))]]]
            set newColour $useNodes($winId,c$colNum)
        }
#puts "Colour for $value is $colNum (range $useNodes($winId,range))"
    }
    
    proc Settings {winId} {
        variable useNodes
        variable min
        variable max
	variable displayUpdate
	global ${winId}l5

        set ${winId}l5 $displayUpdate($winId)
	set dlg [Dialog .polyprop -parent $winId -title "Polygon display properties" \
                -modal local -default 0 -cancel 1]
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
        set coloursF [labelframe [$dlg getframe].colours -text "Colour scale"]
        pack [LabelFrame $coloursF.lowcolourF -text "Low colour"] -fill x  -padx 10
        frame $coloursF.lowcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cbot)
        pack [button $coloursF.lowcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId bot $coloursF.lowcolourF.colF"]] -side right
        pack $coloursF.lowcolourF.colF -side right -padx 10
        
        pack [LabelFrame $coloursF.midcolourF -text "Middle colour"] -fill x -padx 10
        frame $coloursF.midcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cmid)
        pack [button $coloursF.midcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId mid $coloursF.midcolourF.colF"]] -side right
        pack $coloursF.midcolourF.colF -side right -padx 10
        
        pack [LabelFrame $coloursF.topcolourF -text "High colour"] -fill x -padx 10
        frame $coloursF.topcolourF.colF -width 20 -height 15 -bg $useNodes($winId,ctop)
        pack [button $coloursF.topcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId top $coloursF.topcolourF.colF"]] -side right
        pack $coloursF.topcolourF.colF -side right -padx 10
        
        pack $coloursF -padx 10 -pady 10 -fill x
        
        set rangeF [labelframe [$dlg getframe].range -text "Scale range"]
        pack [label $rangeF.dataminL -text "Data min. so far: $useNodes($winId,datamin)"] -fill x  -padx 10
        pack [label $rangeF.datamaxL -text "Data max. so far: $useNodes($winId,datamax)"] -fill x  -padx 10
        pack [LabelFrame $rangeF.minF -text "Min"] -fill x  -padx 10 -pady 5
        pack [entry $rangeF.minF.entry -textvar [namespace current]::min($winId) -width 20] -side right -padx 10
        pack [LabelFrame $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [entry $rangeF.maxF.entry -textvar [namespace current]::max($winId) -width 20] -side right -padx 10
        pack $rangeF -padx 10 -pady 10
        pack [checkbutton [$dlg getframe].update -variable ${winId}l5 \
		  -text "Update at display intervals"]
        
        $dlg add -name ok \
                -command [namespace code "OnClickSettingOkBtn $winId $coloursF $rangeF $dlg"]; # buttons 0
        $dlg add -name cancel -command "$dlg enddialog 1"
        $dlg draw; # waits for a button to be clicked. Button command must call $dlg enddialog _result_
	set displayUpdate($winId) [set ${winId}l5]
        destroy $dlg
    }
    
    proc OnClickSettingOkBtn {winId coloursF rangeF dlg} {
        
        variable useNodes
        variable min
        variable max
        
        # copy the values from the temp values to those to be edited if OK clicked
        set useNodes($winId,ctop) [$coloursF.topcolourF.colF cget -bg]
        set useNodes($winId,cmid) [$coloursF.midcolourF.colF cget -bg]
        set useNodes($winId,cbot) [$coloursF.lowcolourF.colF cget -bg]
        if {[IsNumber $min($winId)]} {
            set useNodes($winId,min) $min($winId)
        } else  {
            ShowMessage Error error "Value must be a number." ok
            $rangeF.minF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
        }
        if {[IsNumber $max($winId)]} {
            set useNodes($winId,max) $max($winId)
        } else  {
            ShowMessage Error error "Value must be a number." ok
            $rangeF.maxF.entry selection range 0 end
            focus $rangeF.maxF.entry
            return
        }
        set useNodes($winId,range) [expr {$max($winId)-$min($winId)}]
        $dlg enddialog 0
        UpdateState $winId
	
        display $winId 0 0 0
    }
    
    proc ChangeValue {winId newVal X Y } {
        variable useNodes
        
        set X [$winId.viewport.c canvasx $X]
        set Y [$winId.viewport.c canvasy $Y]
        set overlapping [$winId.viewport.c find closest $X $Y 1]
        set tags [$winId.viewport.c gettags $overlapping]
        # should check to see if the tags are different before processing them to speed things up
	set index [TagToId $tags]

        #$winId.buttons.msg configure -text \
        #    "X $X; Y $Y; tags $tags; overlapping $overlapping; index $index"
        
        if {[string length $index]>0} {
            set vals [lindex [GetModelValue $useNodes($winId,color)] 0]
	    set oddList {}
	    foreach idx [split $index ,] {
		lappend oddList [expr 2*$idx-1]
	    }
	    lset vals $oddList $newVal
	    SetModelValue $useNodes($winId,color) $vals
	}
        Repaint $winId $useNodes($winId,color)
    }
    
    proc IdToTag {ids} {
	set result {}
	foreach id [split $ids ,] {
	    lappend result [format %06d $id]
	}
	return BLK[join $result ,]
    }

    proc TagToId {tags} {
	set end [expr [string first BLK $tags]+3]
	set idTag [lindex [string range $tags $end end] 0]
	foreach val [split $idTag ,] {
	    scan $val %06d index
	    lappend result $index
	}
	return [join $result ,]
    }

# redundant
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
                "Click on the polygon(s) whose colour (value) you wish \
                to change."
        #    $winId.buttons.msg configure -text "new value $newVal"; # 1 $1 todo; debug line
        $winId.viewport.c configure -cursor spraycan
        $winId.viewport.c bind map <B1-Motion> [namespace code "ChangeValue $winId %x %y"]
        $winId.viewport.c bind map <Button-1> [namespace code "ChangeValue $winId %x %y"]
    }
    
    proc Fit {winId} {
        scan [winfo geometry $winId.viewport.c] {%dx%d+} boxw boxh
        scan [$winId.viewport.c bbox map] {%d %d %d %d} cl ct cr cb
        Zoom $winId [expr ($boxw-2.0)/($cr-$cl)] [expr ($boxh-42.0)/($cb-$ct)]
    }
    
    proc Zoom {winId fx fy} {
        variable useNodes
	set useNodes($winId,scalex) [expr $fx*$useNodes($winId,scalex)]
	set useNodes($winId,scaley) [expr $fy*$useNodes($winId,scaley)]
	set id $winId.viewport.c
        $id scale map [$id canvasx 325] [$id canvasy 230] $fx $fy
        $id configure -scrollregion [$id bbox map]
	recolour_scale [namespace current] $winId
    }
    
    # new version in map tools
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
    
} ;
# end of namespace

