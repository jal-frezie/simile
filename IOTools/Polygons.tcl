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
    
    proc LoadTools {} {
	namespace import -force ::maptools2::*
	namespace import -force ::canvasnotes20070919::*
    }

    proc initialize {winId} {
        variable useNodes
        set useNodes($winId,editMode) 0
	set useNodes($winId,orient) h
	LoadTools
        
        set useNodes($winId,min) 0
        set useNodes($winId,max) 100
        set useNodes($winId,bw) 1

        set useNodes($winId,cbot) black
        set useNodes($winId,cmid) green
        set useNodes($winId,ctop) white
        set useNodes($winId,cbord) black
        
	set useNodes($winId,scalex) 1.0
	set useNodes($winId,scaley) 1.0

	AddToolBar $winId
#        set NToolButtons [$winId.bbframe.buttonBox index last]
#        for {set i 1} {$i<=$NToolButtons} {incr i} {
#            $winId.bbframe.buttonBox itemconfigure $i -state disable
#        }
	AddVariable $winId
    }
    
    proc AddToolBar {winId} {
        variable displayUpdate
	set displayUpdate($winId) 1
        set toolbarItems [list \
                [list zoomin.gif "Zoom in" [namespace code "Zoom $winId 2 2"] ]\
                [list zoomout.gif "Zoom out" [namespace code "Zoom $winId 0.5 0.5"] ]\
                [list zoomfit.gif "Zoom to fit" [namespace code "Fit $winId"] ]\
			      [list save.gif "Save polygon shapes" \
				   [namespace code [list SaveShapes $winId]]] \
	            [list property.gif " Properties " [namespace code "Settings $winId"] ]\
			      [list edit.gif "Enter edit mode " [namespace code "ChangeEditMode [namespace current] $winId"]] \
                [list refresh.gif Update [namespace code "Update $winId"]]\
			  [list text.gif " Add text " \
			       [namespace code "DialogInMiddle $winId"]]]

        ::graphtools::MakeToolBar $winId $toolbarItems
        message $winId.msg -aspect 1000
    }

    proc AddVariable {winId} {
        variable useNodes
        ########## start polyfile changes
        set useNodes($winId,sourcefile) [coords_source $winId]
        
        if {[string compare $useNodes($winId,sourcefile) model]==0} then {
            set ms [message $winId.intro -text "Click on the array value \
                    representing the X coordinates of the polygon vertices."]
            GrabClicks $winId
            pack $ms
            set useNodes($winId,state) xcoord
        } else {
            set ms [message $winId.intro -text "Now select a value to determine the colour of the polygons."]
            GrabClicks $winId
            pack $ms
            set useNodes($winId,state) sizeval
        }
        ########## end polyfile changes
        
        SetState $winId {}
    }
    
    proc Restore {winId} {
        variable useNodes
# defaults for things perhaps added in newer version than created saved state
        set useNodes($winId,editMode) 0
        set useNodes($winId,orient) h
        set useNodes($winId,bw) 1
        set useNodes($winId,cbord) black
 	LoadTools
        
        AddToolBar $winId
	regsub -all /WIN/ [GetState $winId] $winId restoreString
        array set useNodes $restoreString
	CaptionsToNodeIds $winId
	SetColourMap useNodes $winId $useNodes($winId,color)
        
        if {[string compare $useNodes($winId,sourcefile) model]==0} then {
	    DrawPolys $winId $useNodes($winId,xcoord) \
		$useNodes($winId,ycoord) \
		$useNodes($winId,color) 0
	} else {
	    DoFrame $winId
	    foreach {type coords tags} $useNodes($winId,shapes) {
		if {[string match poly* $type]} {
		    eval {$winId.viewport.c create $type} $coords \
			{-outline black -tag $tags}
		}
	    }
	    Repaint $winId $useNodes($winId,color)
	}
	set ZoomCmd [list Zoom $winId $useNodes($winId,scalex) \
			 $useNodes($winId,scaley)]
	set useNodes($winId,scalex) 1.0
	set useNodes($winId,scaley) 1.0
	eval $ZoomCmd
	if {$useNodes($winId,editMode)} {
	    set useNodes($winId,editMode) 0
	    ChangeEditMode [namespace current] $winId
	}
	if {![info exists useNodes($winId,stringInfo)]} return
	RestoreNotesFromList [GetCanvas $winId] $useNodes($winId,stringInfo)
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
                        $ms configure -text "Now select a value to determine the colour of the polygons."
                        set useNodes($winId,ycoord) $node
                        set useNodes($winId,state) sizeval
                    }
                    sizeval {
                        pack forget $ms
                        ReleaseClicks $winId
                        set useNodes($winId,color) $node
                        catch {wm title $winId "$caption (polygon diagram)"}; # if not a toplevel, ie MRE
                        SetColourMap useNodes $winId $node
                        SetColours useNodes $winId
                        DrawPolys $winId $useNodes($winId,xcoord) \
                                $useNodes($winId,ycoord) \
                                $node 1
                        set useNodes($winId,state) displaying
			PrepareSaveString $winId
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
                        SetColours useNodes $winId
                        DrawPolys $winId {} {} $node 1
                        set useNodes($winId,state) displaying
			PrepareSaveString $winId
                    }
                }
            }
            ########## end polyfile changes
            
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc PrepareSaveString {winId} {
        variable useNodes
        NodeIdsToCaptions $winId
        regsub -all $winId [array get useNodes $winId,*] /WIN/ saveString
	lappend saveString /WIN/,stringInfo [ListNotes [GetCanvas $winId]]
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
	if {[string equal displaying $useNodes($winId,state)] && \
		$displayUpdate($winId)} {
	    Repaint $winId $useNodes($winId,color)
	}
    }
    
    proc Recolour {winId whichCol exampleWidget} {
        variable useNodes
	set col [tk_chooseColor -parent .polyprop \
		     -initialcolor $useNodes($winId,c$whichCol)]
	if {![string length $col]} return
        set useNodes($winId,c$whichCol) $col
	$exampleWidget configure -bg $useNodes($winId,c$whichCol)
	if {![string equal bord $whichCol]} {
	    SetColours useNodes $winId
	    recolour_scale [namespace current] $winId
	}
        PrepareSaveString $winId
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
		if {$useNodes($winId,bw)} {
		    set newBord $useNodes($winId,cbord)
		} else {
		    set newBord {}
		}
		$winId.viewport.c itemconfigure $polyId \
		    -width $useNodes($winId,bw) -outline $newBord
		set newColour [ColourFor $winId $value]
		if {![string match $newColour \
			  [$winId.viewport.c itemcget $polyId -fill]]} {
		    $winId.viewport.c itemconfigure $polyId -fill $newColour
		}
            }
        }
	$winId.viewport.c itemconfig caption -text "[file tail [GetCaptionPathFromId $hs]], time = [GetModelTime]" 
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
	MakeCanvasAnnotatable $vp.c
        pack $vp.c -fill both -expand true
	recolour_scale [namespace current] $winId
	bind $vp.c <Configure> \
	    [namespace code "recolour_scale [namespace current] $winId"]
    }

    proc ScrollMe {winId way args} {
	eval {$winId.viewport.${way}sc set} $args
	reposn_scale [namespace current] $winId
    }

	
    proc DrawPolys {winId xs ys hs fit} {
        variable viewpoint
        variable useNodes
        
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
        # ShowMess debug info "Got quadlist $quadlist" ok
	    array set quadarray $quadlist
	    foreach id [array names quadarray] {
		set quad $quadarray($id)
		set corners ""
		#        ShowMess debug info [lindex $quad 2] ok
		set polyycorrds {}
		set i 0
		set j 1
		set tmp [lindex $quad 2]
		#        ShowMess debug info $tmp ok
		while {$i < [llength [lindex $quad 2]]} {
		    lappend polyycorrds [lindex $tmp $i]
		    incr i 2
		    set ttmp [lindex $tmp $j]
		    #        ShowMess debug info "ttmp $ttmp" ok
		    lappend polyycorrds [expr $ttmp * -1]
		    incr j 2
		}
		#        ShowMess debug info $polyycorrds ok
		Interweave corners [lindex $quad 1] $polyycorrds
		set indxs [join $id ,]
		#        ShowMess debug info $corners ok
		set polyId [eval {$winId.viewport.c create polygon} $corners \
			    {-width $useNodes($winId,bw) \
				 -outline $useNodes($winId,cbord) \
				 -tag [list map [IdToTag $indxs]]}]
	    }
	}

	if {$coordSource != 0} {
	    # Now copy the poly info into the state so it can be saved
	    set useNodes($winId,shapes) {}
	    foreach poly [$winId.viewport.c find withtag map] {
		lappend useNodes($winId,shapes) \
		    [$winId.viewport.c type $poly] \
		    [$winId.viewport.c coords $poly] \
		    [$winId.viewport.c gettags $poly]
	    }
        }
        ########## end polyfile changes

#	set NToolButtons [$winId.bbframe.buttonBox index last]
#        $winId.bbframe.buttonBox itemconfigure 0 -state disable; #disable the add var button
#	for {set i 1} {$i<=$NToolButtons} {incr i} {
#	    $winId.bbframe.buttonBox itemconfigure $i -state normal
#	}
        Repaint $winId $hs
	if {$fit} {
	    if {![GoodFit $useNodes($winId,min) $useNodes($winId,max) \
		      $useNodes($winId,datamin) $useNodes($winId,datamax)] && \
		    !$useNodes($winId,ETCount)} { ;# do not tweak scale if ETs
		::graphtools::AxisRound \
		    $useNodes($winId,datamin) $useNodes($winId,datamax) 0 \
		    useNodes($winId,min) useNodes($winId,max) s1 s2 s3 s4 s5
		set useNodes($winId,range) \
		    [expr {$useNodes($winId,max)-$useNodes($winId,min)}]
		recolour_scale [namespace current] $winId
		Repaint $winId $hs
	    }
	    update
	    Fit $winId
	}
    }
    
    proc GoodFit {smin smax dmin dmax} {
	return 0
    }

    proc ColourFor {winId value} {
        variable useNodes
        if {[string match nil $value]} {
            set newColour gray
        } elseif {$value<=$useNodes($winId,min)} {
	    set newColour $useNodes($winId,c0)
        } elseif {$value>=$useNodes($winId,max)} {
	    set newColour $useNodes($winId,c$useNodes($winId,nswatches))
	} else {
	    set colNum [expr int(($value-$useNodes($winId,min))* \
				     $useNodes($winId,nswatches) / \
				     $useNodes($winId,range))]
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
	set dlg [Dialog .polyprop -parent [winfo toplevel $winId] \
		     -title "Polygon display properties" \
		     -modal local -default 0 -cancel 1]
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
        set coloursF [labelframe [GetFrame $dlg].colours -text "Colour scale"]
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
        
        set borderF [labelframe [GetFrame $dlg].border -text "Borders"]
        pack [LabelFrame $borderF.widF -text "Width"] -fill x  -padx 10 -pady 5
        pack [entry $borderF.widF.entry -textvar [namespace current]::useNodes($winId,bw) -width 20] -side left -padx 10
        pack [LabelFrame $borderF.colourF -text "Colour"] -fill x -padx 10
        frame $borderF.colourF.colF -width 20 -height 15 -bg $useNodes($winId,cbord)
        pack [button $borderF.colourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId bord $borderF.colourF.colF"]] -side right
        pack $borderF.colourF.colF -side right -padx 10
        pack $borderF -padx 10 -pady 10
        
        set rangeF [labelframe [GetFrame $dlg].range -text "Scale range"]
        pack [label $rangeF.dataminL -text "Data min. so far: $useNodes($winId,datamin)"] -fill x  -padx 10
        pack [label $rangeF.datamaxL -text "Data max. so far: $useNodes($winId,datamax)"] -fill x  -padx 10
        pack [LabelFrame $rangeF.minF -text "Min"] -fill x  -padx 10 -pady 5
        pack [entry $rangeF.minF.entry -textvar [namespace current]::min($winId) -width 20] -side right -padx 10
        pack [LabelFrame $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [entry $rangeF.maxF.entry -textvar [namespace current]::max($winId) -width 20] -side right -padx 10
        pack $rangeF -padx 10 -pady 10
        pack [checkbutton [GetFrame $dlg].update -variable ${winId}l5 \
		  -text "Update at display intervals"]
        
        set oriF [labelframe [GetFrame $dlg].orient -text "Orientation"]
	pack [radiobutton $oriF.h -text Horizontal -var [namespace current]::useNodes($winId,orient) -value h] -side left
	pack [radiobutton $oriF.v -text Vertical -var [namespace current]::useNodes($winId,orient) -value v] -side right
        pack $oriF -padx 10 -pady 10 -fill x
        
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
            ShowMess Error error "Value must be a number." ok
            $rangeF.minF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
        }
        if {[IsNumber $max($winId)]} {
            set useNodes($winId,max) $max($winId)
        } else  {
            ShowMess Error error "Value must be a number." ok
            $rangeF.maxF.entry selection range 0 end
            focus $rangeF.maxF.entry
            return
        }
        set useNodes($winId,range) [expr {$max($winId)-$min($winId)}]
        recolour_scale [namespace current] $winId
        $dlg enddialog 0
        PrepareSaveString $winId
	
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
        
	PokeValue $useNodes($winId,color) [split $index ,] $newVal
	$winId.viewport.c itemconfigure $overlapping \
	    -fill $useNodes($winId,paintColour)
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
	variable useNodes
	
        scan [winfo geometry $winId.viewport.c] {%dx%d+} boxw boxh
# make room for legend
	if {[string equal h $useNodes($winId,orient)]} {
	    incr boxh -40
	} else {
	    incr boxw -40
	}
        scan [$winId.viewport.c bbox map] {%d %d %d %d} cl ct cr cb
#puts "fitting $cl $ct $cr $cb to $boxw $boxh"
        Zoom $winId [expr ($boxw-2.0)/($cr-$cl)] [expr ($boxh-2.0)/($cb-$ct)]
    }
    
    proc SaveShapes {winId} {
	variable useNodes

	if {![llength \
		  [ChooseFile polys.bgx [tr. "Save polygon boundaries as:"] 1 \
		       [$::helperTable($winId,whichInstance) GetNode]]]} return
	set strm [open $file w]
	puts $strm [concat [GetModelValue $useNodes($winId,xcoord)] \
				[GetModelValue $useNodes($winId,ycoord)]]
	close $strm
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
#        if {[llength $xs]} {
#            lappend outlist [lindex $xs 1] [lindex $ys 1]
            #ShowMess debug info "$xs; $ys; $outlist" ok
#            Interweave outlist [lrange $xs 2 end] [lrange $ys 2 end]
#        }
# naaah...
	foreach {xind xval} $xs {yind yval} $ys {
	    lappend outlist $xval $yval
	}
    }
    
    
    proc coords_source {winId} {
        after idle {.dialog1.msg configure -wraplength 4i}
        set i [tk_dialog .dialog1 "Source of polygon coordinates" {Click on a button to select the source of the polygon coordinates.} \
                info 0 {Coords from file} {Coords from model}]
        
        switch $i {
            0 {set sourcefile \
		   [ChooseFile polys.bgx [tr. "Load polygon boundaries from:"] \
			0 [$::helperTable($winId,whichInstance) GetNode]]}
            1 {set sourcefile model}
        }
        return $sourcefile
    }
    
} ;
# end of namespace

