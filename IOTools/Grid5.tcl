# grid4 == grid3.tcl modified by Jasper for photo image type
# grid5 == grid4.tcl modified by Robert for more compact, more
#          professional-looking display

# grid3.tcl		--	Robert Muetzelfeldt   10 August 2000
# SimCity-style spatial grid display

set keyValue grid005
namespace eval grid005 {
    variable useNodes
    variable cell_ids
    variable old_icolour
    variable min; # edit var for entry widget
    variable max; # edit var for entry widget
    
    
    proc identify {} {
        return "Spatial grid display"
    }
    
    proc LoadTools {} {
	namespace import -force ::maptools2::*
	namespace import -force ::canvasnotes20070919::*
    }

    proc initialize {winId} {
        variable useNodes

        array unset useNodes $winId,*
	LoadTools
	DefaultColours $winId
	set useNodes($winId,editMode) 0
        set useNodes($winId,integer) 0
        set useNodes($winId,freeze) false
        set useNodes($winId,min) 0
        set useNodes($winId,max) 100
        set useNodes($winId,dataMin) 1e100
        set useNodes($winId,dataMax) -1e100
        set useNodes($winId,orient) h
        set useNodes($winId,imgs) 0
        SetState $winId {}
	message	$winId.msg -aspect 1000
        AddToolbar $winId
#        set NToolButtons [$winId.bbframe.buttonBox index last]
#        for {set i 0} {$i<=$NToolButtons} {incr i} {
#            $winId.bbframe.buttonBox itemconfigure $i -state disable
#        }
        if {[string match $winId [winfo toplevel $winId]]} {
            wm geometry $winId 500x500
        }
        AddVariable $winId
    }

    proc reset {winId} {
    }

    proc DefaultColours {winId} {
        variable useNodes
        set useNodes($winId,cbot) black
        set useNodes($winId,cmid) red
        set useNodes($winId,ctop) white
    }

    proc AddToolbar {winId} {
        set toolbarItems \
	    [list \
		 [list save.gif "Save image" [namespace code "SaveAsFile $winId"]]\
		 [list zoomin.gif "Zoom in" [namespace code "zoomio $winId 1.25"] ]\
		 [list zoomout.gif "Zoom out" [namespace code "zoomio $winId 0.8"] ]\
		 [list property.gif " Properties " [namespace code "Settings $winId"]]\
		 [list text.gif " Add text " \
		      [namespace code "DialogInMiddle $winId"]]\
		 [list edit.gif "Enter edit mode " [namespace code "ChangeEditMode [namespace current] $winId"]] \
		 [list less.gif "Decrease range" [namespace code "DecreaseRange $winId"] ]\
		 [list greater.gif "Increase range" [namespace code "IncreaseRange $winId"] ]\
		 [list pause.gif " Freeze " [namespace code "ToggleFreeze $winId"]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
	::graphtools::SetButtonState $winId zoomin disabled
	::graphtools::SetButtonState $winId zoomout disabled
	::graphtools::SetButtonState $winId property disabled
	::graphtools::SetButtonState $winId edit disabled
    }
    
    proc AddVariable {winId} {
	set ms $winId.msg
        $ms configure -text \
    "Click on the variable whose values are to be displayed on the grid."
        GrabClicks $winId
        pack $ms
#        $winId.bbframe.buttonBox itemconfigure 0 -state disable; #disable the add var button
        SetState $winId display0
    }
    
    proc Recolour {winId whichCol exampleWidget} {
        variable useNodes
        set colour [tk_chooseColor -parent .gridprop \
			-initialcolor $useNodes($winId,c$whichCol)]
        if {[string length $colour]} {
	    $exampleWidget configure -bg $colour
	    set useNodes($winId,colourMapTweaked) 0
	}
        return $colour
    }
    
    proc Restore {winId} {
        variable useNodes

        array unset useNodes $winId,*
        LoadTools
        set useNodes($winId,editMode) 0
        set useNodes($winId,orient) h
        set useNodes($winId,imgs) 0
	message	$winId.msg -aspect 1000
	set state [GetState $winId]
# looks like "displaying %s %s colourmap %s %s %s aspect %d %g %g magnification %d"
	set useNodes($winId,color) [GetIdFromCaptionPath [lindex $state 1]]
	set useNodes($winId,tgtDims) [GetModelDims $useNodes($winId,color)]
	if {[IsTwoDee $winId $useNodes($winId,tgtDims)]} {
	    set useNodes($winId,colvals) USE_INDICES
	} else {
	    set useNodes($winId,colvals) \
		[GetIdFromCaptionPath [lindex $state 2]]
	    NumDistinct $winId $useNodes($winId,colvals)
	}
	set mapBase [lsearch $state colourmap]
	if {$mapBase > -1} {
	    foreach colourPt {cbot cmid ctop} {
		set useNodes($winId,$colourPt) [lindex $state [incr mapBase]]
	    }
	}
	set rangeBase [lsearch $state aspect]
	foreach rangePt {nswatches min max} {
	    set useNodes($winId,$rangePt) [lindex $state [incr rangeBase]]
	}
	SetColourMap useNodes $winId $useNodes($winId,color)
	set swatchBase [lsearch $state swatches]
	if {$swatchBase > -1} {
	    for {set col 0} {$col<=$useNodes($winId,nswatches)} {incr col} {
		set useNodes($winId,c$col) [lindex $state [incr swatchBase]]
	    }
	    set useNodes($winId,colourMapTweaked) 1
	} else {
	    SetColours useNodes $winId
	}
	set multBase [lsearch $state magnification]
	if {$multBase != -1} {
	    set useNodes($winId,mult) [lindex $state [incr multBase]]
	}
	set orientBase [lsearch $state orient]
	if {$orientBase != -1} {
	    set useNodes($winId,orient) [lindex $state [incr orientBase]]
	}
	set annotationBase [lsearch $state annotation]
	if {$annotationBase != -1} {
	    set annot [lindex $state [incr annotationBase]]
	}
	set imgBase [lsearch $state images]
	if {$imgBase>-1} {
	    set useNodes($winId,imgs) [lindex $state [incr imgBase]]
	    while {[string is integer -strict \
			[set imgNo [lindex $state [incr imgBase]]]]} {
		set imgData [lindex $state [incr imgBase]]
		set useNodes($winId,i$imgNo) [image create photo -data $imgData]
		PutSize $useNodes($winId,i$imgNo)
	    }
	}
        set useNodes($winId,caption) [lindex $state 1]
        
        AddToolbar $winId
#        $winId.bbframe.buttonBox itemconfigure 0 -state disable
        set useNodes($winId,dataMin) 1e100
        set useNodes($winId,dataMax) -1e100
        InitialiseGrid $winId
        if {[info exists annot]} {
	    RestoreNotesFromList $winId.c $annot
	}
	set useNodes($winId,freeze) false
    }
    
    proc GetCanvas {winId} {
        return $winId.c
    }
    
    proc click {winId node caption} {
        variable useNodes
        
        set ms $winId.msg
        set testResult [GetModelType $node]
        if {[string compare $testResult VALUELESS]} {
            set state [GetState $winId]
            switch $state {
                display0 {
                    set useNodes($winId,color) $node
		    SetColourMap useNodes $winId $node
		    if {$useNodes($winId,ETCount)} {
			foreach notForET {less greater} {
			    ::graphtools::SetButtonState $winId $notForET disabled
			}
		    }
                    catch {wm title $winId $caption}
		    SetColours useNodes $winId
		    set useNodes($winId,tgtDims) [GetModelDims $node]
		    if {[IsTwoDee $winId $useNodes($winId,tgtDims)]} {
			set useNodes($winId,colvals) USE_INDICES
			FinishClicking $winId
		    } else {
			$winId.msg configure -text "Now click on a variable giving the column IDs."
			SetState $winId display1
		    }
                } display1 {
                    NumDistinct $winId $node
		    set useNodes($winId,colvals) $node
		    FinishClicking $winId
#		    if {![info exists useNodes($winId,values)]} {
#disable the edit mode as we do not know the model indices...we do now
#			$winId.bbframe.buttonBox itemconfigure 5 -state disable
#		    }
                }
            }
        } else {
            $ms configure -text \
                    "This component does not have a value; please choose a compartment, variable or flow."
        }
    }
    
    proc FinishClicking {winId} {
	ReleaseClicks $winId
	pack forget $winId.msg

	InitialiseGrid $winId
	PrepareSaveString $winId

	raise $winId
    }

    proc IsTwoDee {winId dimList} {
	variable useNodes
	
	foreach dim $dimList {
	    if {[string is integer -strict $dim]} {
		foreach space [list useNodes($winId,nrow) \
				   useNodes($winId,ncol) terminator] {
		    if {![info exists $space]} {
			set $space $dim
			break
		    }
		}
	    }
	}
	return [expr {[info exists terminator] && !$terminator}]
    }

    proc NumDistinct {winId testNode} {
	variable useNodes

	if {![catch {ListDistinctModelValues $testNode} vList]} {
	    set useNodes($winId,ncol) [llength [lrange $vList 1 end]]
	    set useNodes($winId,nrow) \
		[expr {[lindex $vList 0]/$useNodes($winId,ncol)}]
	} else {
	    set columns [Flatten [lindex [GetModelValue $testNode] 0]]
	    foreach col $columns {
		set colvals([lindex $col 1]) 1
	    }
	    if {[info exists colvals()]} {
		unset colvals()
	    }
	    set useNodes($winId,ncol) [array size colvals]
	    set useNodes($winId,nrow) \
		[expr {[llength $columns]/$useNodes($winId,ncol)}]
	}
    }

    proc PrepareSaveString {winId} {
        variable useNodes
	
	set state [list displaying \
		       [GetCaptionPathFromId $useNodes($winId,color)] \
		       [GetCaptionPathFromId $useNodes($winId,colvals)]]
	if {$useNodes($winId,colourMapTweaked)} {
	    lappend state swatches
	    for {set col 0} {$col<=$useNodes($winId,nswatches)} {incr col} {
		lappend state $useNodes($winId,c$col)
	    }
	} else {
	    lappend state colourmap $useNodes($winId,cbot) \
		$useNodes($winId,cmid) $useNodes($winId,ctop)
	}
	lappend state images $useNodes($winId,imgs)
	foreach possImg [array names useNodes $winId,i*] {
	    set thei [string last i $possImg]
	    set indx [string range $possImg [incr thei] end]
	    if {[string is integer -strict $indx]} {
		lappend state $indx [$useNodes($possImg) data -format png]
	    }
	}
	lappend state aspect $useNodes($winId,nswatches) \
                $useNodes($winId,min) $useNodes($winId,max) \
		magnification $useNodes($winId,mult) \
	    orient $useNodes($winId,orient) annotation [ListNotes $winId.c]
	SetState $winId $state
    }
    
    proc display {winId time step remainder} {
        variable useNodes
        if {[string match [lindex [GetState $winId] 0] displaying] && \
                    !$useNodes($winId,freeze)} then {
#	    if {!$time} { ;# wrong, should only be done on reset if at all
#		NumDistinct $winId $useNodes($winId,colvals)
#	    }
            DrawGrid6 $winId $useNodes($winId,color)
            FillCanvas $winId
	    if {[info exists useNodes($winId,regSave)]} {
		if {$useNodes($winId,regSave)} {
		    WriteImage $winId $time
		}
	    }
        }
    }
    
    proc InitialiseGrid {winId} {
	variable useNodes
        
	set display1 $useNodes($winId,color)
        set useNodes($winId,hiddenMap) [image create photo]
        DrawGrid6 $winId $display1
# This must now be done before we create the canvas because otherwise the
# canvas might try to redraw while this is waiting for data from the model
        frame $winId.f
        scrollbar $winId.hscroll -orient horiz -command "$winId.c xview"
        scrollbar $winId.vscroll -command "$winId.c yview"
        canvas $winId.c \
                -relief sunken \
                -borderwidth 2 \
                -xscrollcommand [namespace code "ScrollPhoto $winId h"] \
                -yscrollcommand [namespace code "ScrollPhoto $winId v"]
	MakeCanvasAnnotatable $winId.c \
	    [namespace code "Settings $winId"]
        pack $winId.f -expand yes -fill both -padx 1 -pady 1
        grid rowconfig    $winId.f 0 -weight 1 -minsize 0
        grid columnconfig $winId.f 0 -weight 1 -minsize 0
        
        grid $winId.c -padx 1 -in $winId.f -pady 1 \
                -row 0 -column 0 -rowspan 1 -columnspan 1 -sticky news
        grid $winId.vscroll -in $winId.f -padx 1 -pady 1 \
                -row 0 -column 1 -rowspan 1 -columnspan 1 -sticky news
        grid $winId.hscroll -in $winId.f -padx 1 -pady 1 \
                -row 1 -column 0 -rowspan 1 -columnspan 1 -sticky news
        
        if {$useNodes($winId,nrow)>$useNodes($winId,ncol)} then {
            set n $useNodes($winId,nrow)
        } else {
            set n $useNodes($winId,ncol)
        }
        
        if {[info exists useNodes($winId,mult)]} {
	    set mult $useNodes($winId,mult)
	} else {
	    set mult [expr {int(380/$n)}]
	}
	::graphtools::SetButtonState $winId zoomin normal
	if {$mult<2} {
	    set mult 1
	    ::graphtools::SetButtonState $winId zoomout disabled
	} else {
	    ::graphtools::SetButtonState $winId zoomout normal
	} 
        set useNodes($winId,mult) $mult
        set xwidth [expr {$mult*$useNodes($winId,ncol)}]
        set yheight [expr {$mult*$useNodes($winId,nrow)}]
        set useNodes($winId,xwidth) $xwidth
        set useNodes($winId,yheight) $yheight
#        $winId.c configure -width $xwidth -height $yheight

#        $winId.c bind all <Button-3> [namespace code "Settings $winId"]
# this is passed to the annotator which handles context menu and text additon
        $winId.c bind all <B1-Motion> [namespace code "value_popup $winId %X %Y %x %y"]
        $winId.c bind all <ButtonPress-1> [namespace code "value_popup $winId %X %Y %x %y"]
        $winId.c bind all <B1-ButtonRelease> RemovePopup
        
        set useNodes($winId,visibleMap) [image create photo]
        $winId.c create image 0 0 -image $useNodes($winId,visibleMap) \
	    -anchor nw -tag map
	recolour_scale $::helperTable($winId,whichInstance) $winId ;# do here for scrollers
	bind $winId.c <Configure> \
	    [namespace code "recolour_scale $::helperTable($winId,whichInstance) $winId"]
#        $winId.c configure -scrollregion [$winId.c bbox all]
        $winId.c configure -scroll "0 0 $xwidth $yheight"
	::graphtools::SetButtonState $winId property normal
	if {[lsearch {INPUT TABLE} [GetModelEval $display1]]>-1} {
	    ::graphtools::SetButtonState $winId edit normal
	}
    }
    
    proc ToggleFreeze {winId} {
        variable useNodes
        if {$useNodes($winId,freeze)} {
            set useNodes($winId,freeze) false
	    ::graphtools::SetButtonState $winId pause flat
#            $winId.bbframe.buttonBox itemconfigure end -relief flat; #disable the add var button
        } else  {
            set useNodes($winId,freeze) true
	    ::graphtools::SetButtonState $winId pause sunken
#            $winId.bbframe.buttonBox itemconfigure end -relief sunken; #disable the add var button
        }
    }
    
    proc IncreaseRange {winId} {
        variable useNodes
        set useNodes($winId,min) [expr {$useNodes($winId,min)*10}]
        set useNodes($winId,max) [expr {$useNodes($winId,max)*10}]
#        SetColours useNodes $winId
        recolour_scale $::helperTable($winId,whichInstance) $winId
        PrepareSaveString $winId
        display $winId 0 0 0
    }
    
    proc DecreaseRange {winId} {
        variable useNodes
        set useNodes($winId,min) [expr {0.1*$useNodes($winId,min)}]
        set useNodes($winId,max) [expr {0.1*$useNodes($winId,max)}]
#        SetColours useNodes $winId
        recolour_scale $::helperTable($winId,whichInstance) $winId
        PrepareSaveString $winId
        display $winId 0 0 0
    }

    proc Settings {winId} {
	global gridprops

        variable useNodes
        variable min
        variable max
	set dlg [PutItThere .gridprop [winfo toplevel $winId]]
	wm title $dlg [tr. {Grid display properties}]
        
        # copy display parameters to temp values
        # colours are stored by frames used as example colour swatch (eg $coloursF.lowcolourF.colF)
        set min($winId) $useNodes($winId,min)
        set max($winId) $useNodes($winId,max)
        
        #create widgets
	pack [set t [::ttk::notebook $dlg.notebook]] -fill both -expand true
	$t add [set fd [frame $t.disp]] -text "Display"
        set coloursF [labelframe $fd.colours -text "Colour scale"]
        pack [ttk::labelframe $coloursF.lowcolourF -text "Low colour"] -fill x  -padx 10
	if {$useNodes($winId,colourMapTweaked)} {
	    DefaultColours $winId
	}
        frame $coloursF.lowcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cbot)
        pack [button $coloursF.lowcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId bot $coloursF.lowcolourF.colF"]] -side right
        pack $coloursF.lowcolourF.colF -side right -padx 10
        
        pack [ttk::labelframe $coloursF.midcolourF -text "Middle colour"] -fill x -padx 10
        frame $coloursF.midcolourF.colF -width 20 -height 15 -bg $useNodes($winId,cmid)
        pack [button $coloursF.midcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId mid $coloursF.midcolourF.colF"]] -side right
        pack $coloursF.midcolourF.colF -side right -padx 10
        
        pack [ttk::labelframe $coloursF.topcolourF -text "High colour"] -fill x -padx 10
        frame $coloursF.topcolourF.colF -width 20 -height 15 -bg $useNodes($winId,ctop)
        pack [button $coloursF.topcolourF.cbutton -text "..." \
                -command [namespace code "Recolour $winId top $coloursF.topcolourF.colF"]] -side right
        pack $coloursF.topcolourF.colF -side right -padx 10
	pack [checkbutton $coloursF.imgs -text [tr. {Superimpose images}] \
		  -variable [namespace current]::useNodes($winId,imgs)]
        
        pack $coloursF -padx 10 -pady 10 -fill x
        
        set rangeF [labelframe $fd.range -text "Scale range"]
        pack [label $rangeF.dataminL -text "Data min. so far: $useNodes($winId,dataMin)"] -fill x  -padx 10
        pack [label $rangeF.datamaxL -text "Data max. so far: $useNodes($winId,dataMax)"] -fill x  -padx 10
        pack [ttk::labelframe $rangeF.minF -text "Min"] -fill x  -padx 10 -pady 5
        pack [entry $rangeF.minF.entry -textvar [namespace current]::min($winId) -width 20] -side right -padx 10
        pack [ttk::labelframe $rangeF.maxF -text "Max"] -fill x -padx 10 -pady 5
        pack [entry $rangeF.maxF.entry -textvar [namespace current]::max($winId) -width 20] -side right -padx 10
        pack $rangeF -padx 10 -pady 10
        
        set oriF [labelframe $fd.orient -text "Legend orientation"]
	pack [radiobutton $oriF.h -text Horizontal -var [namespace current]::useNodes($winId,orient) -value h] -side left
	pack [radiobutton $oriF.v -text Vertical -var [namespace current]::useNodes($winId,orient) -value v] -side right
        pack $oriF -padx 10 -pady 10 -fill x
        
	$t add [set fr [frame $t.rec]] -text "Record"
        set targetF [labelframe $fr.target -text "Target:"]
	pack [entry $targetF.e \
		  -textvar [namespace current]::useNodes($winId,target)] \
	    -padx 10 -pady 10 -fill x -expand true
	pack [button $targetF.b -text Browse -command \
		  [namespace code [list GetImg $winId]]] -padx 10 -pady 10 
        pack $targetF -padx 10 -pady 10 -fill x -expand true
        set templateF [labelframe $fr.template -text "Template:"]
	pack [entry $templateF.e -textvar \
		  [namespace current]::useNodes($winId,template)] \
	    -padx 10 -pady 10 -fill x -expand true
	bind $templateF.e <Return> \
	    [namespace code [list SetGDALTemplateHandle $winId]]
	pack [button $templateF.b -text Browse -command \
		  [namespace code [list SetImg $winId]]] -padx 10 -pady 10 
        pack $templateF -padx 10 -pady 10 -fill x -expand true
        set actionF [labelframe $fr.action -text "Actions:"]
	pack [button $actionF.b -text "Save current" \
		  -command [namespace code [list WriteImage $winId now]]] \
	    -padx 10 -pady 10 
	pack [checkbutton $actionF.cb -text "Save at display update" \
		  -variable [namespace current]::useNodes($winId,regSave)] \
	    -padx 10 -pady 10 
        pack $actionF -padx 10 -pady 10 -fill x -expand true
	set useNodes($winId,actions) $actionF
	if {![info exists useNodes($winId,GDALTemplate)]} {
	    $actionF.b configure -state disabled
	    $actionF.cb configure -state disabled
	}

	pack [frame $dlg.btnfr]
	pack [button $dlg.btnfr.ok -text [tr. OK] \
		  -command "set gridprops(xdone) 1"] -side right
	pack [button $dlg.btnfr.cancel -text [tr. Cancel] \
		  -command "set gridprops(xdone) 0"] -side right
	LetItShow $dlg
	grab $dlg
	tkwait variable gridprops(xdone)
	grab release $dlg
	if {$gridprops(xdone)} {
# transfer data back to variables
	    OnClickSettingOkBtn $winId $coloursF $rangeF $dlg
	}
	PackItUp $dlg
    }
    
    proc GetImg {winId} {
	global helperTable
	variable useNodes

	set useNodes($winId,target) \
	    [ChooseFile image.tif [tr. "File to save:"] 1 \
		 [$helperTable($winId,whichInstance) GetNode]]
    }

    proc SetImg {winId} {
	global helperTable
	variable useNodes

	set useNodes($winId,template) \
	    [ChooseFile image.tif [tr. "Copy metadata from:"] 0 \
		 [$helperTable($winId,whichInstance) GetNode]]
	if {[string length $useNodes($winId,template)]} { ;# no cancel
	    SetGDALTemplateHandle $winId
	}
    }

    proc SetGDALTemplateHandle {winId} {
	variable useNodes

	package require gdal

	set useNodes($winId,GDALTemplate) \
	    [gdal_open_read_only $useNodes($winId,template)]
	set actionF $useNodes($winId,actions)
	$actionF.b configure -state normal
	$actionF.cb configure -state normal
    }

    proc WriteImage {winId time} {
	variable useNodes
	
	set dest $useNodes($winId,target)
	if {![string equal now $time]} {
	    set extn [file extension $dest]
	    set dest [file rootname $dest]
	    append dest $time $extn
	}
	
	set newTemplate [gdal_create_copy $dest GTiff \
			     $useNodes($winId,GDALTemplate)]
	set targetArea [gdal_get_raster_band $newTemplate 1]
	
	set ncol $useNodes($winId,ncol)
	set nrow $useNodes($winId,nrow)
	if {[catch {GetBinaryModelValue $useNodes($winId,color) 0 0} fltData]} {
	    if {[info exists useNodes($winId,values)]} {
		set values $useNodes($winId,values)
	    } else {
		set values [Flatten [lindex [GetModelValue \
					     $useNodes($winId,color)] 0]]
	    }

	    for {set row 1} {$row<=$nrow} {incr row} {
		set rowData {}
		for {set col 1} {$col<=$ncol} {incr col} {
		    set cell [expr ($row-1)*$ncol+$col-1]
		    set celval [lindex [lindex $values $cell] 1]
		    
		    lappend rowData $celval
		}
		lappend allData $rowData
	    }
	    gdal_set_raster_values $targetArea 0 0 $ncol $nrow $allData
	} else {
	    gdal_set_raster_data $targetArea 0 0 $ncol $nrow GDT_Float64 \
		$ncol $nrow $fltData
	}
	gdal_close $newTemplate
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
	    Query [list not_number Min] error top {} ok
            $rangeF.minF.entry selection range 0 end
            focus $rangeF.minF.entry
            return
        }
        if {[IsNumber $max($winId)]} {
            set useNodes($winId,max) $max($winId)
        } else  {
	    Query [list not_number Max] error top {} ok
            $rangeF.maxF.entry selection range 0 end
            focus $rangeF.maxF.entry
            return
        }
	if {!$useNodes($winId,colourMapTweaked)} {
	    SetColours useNodes $winId
	}
        recolour_scale $::helperTable($winId,whichInstance) $winId
        PrepareSaveString $winId
        display $winId 0 0 0
    }
    
    proc click_cell {winId c} {
        variable useNodes
        bell
        $c itemconfigure current -fill red
        set tags [$c gettags current]
        $c create text 250 180 -text "TAGS $tags"
        set cell [string range $tags 4 [expr {[string first " " $tags]-1}]]
        $c create text 250 200 -text "xxx $cell xxx"
        set cella [expr {$cell*2}]
        $c create text 250 210 -text $cella
        
        set dis1 $useNodes($winId,color)
        set display1 [lindex [GetModelValue $dis1] 0]
        set this_colour [expr {int([lindex $display1 [expr $cell*2-1]])}]
        $c create text 250 230 -text "xx $this_colour xx"
    }
    
# Old version -- actually extracted model data as Tcl numbers and stuck them
# one by one into the photo. Crawled, of course.    
    
    proc DrawGrid5 {winId node} {
        variable useNodes
        
        # Data must be from a singly-nested fixed membership model,
        # or an indexless conditional model inside one
        # Note: tried to optimise (e.g. by use of holding variables for array
        # elements), since this is the time-critical part.
        
	set ncol $useNodes($winId,ncol)
	set nrow $useNodes($winId,nrow)
        set allData {}
	array unset useNodes $winId,values,*
	set useNodes($winId,values) 1
	if {$useNodes($winId,colvals) eq "USE_INDICES"} {
	    set allData [lrepeat $nrow [lrepeat $ncol grey]]

	    foreach {y row} [lindex [GetModelValue $node] 0] {
		foreach {x celval} $row {
		    lset allData [list $nrow-$y $x-1] [ForGrid $winId $celval]
		    set useNodes($winId,values,$y,$x) \
			[list [list $y $x] $celval]
		}
	    }
	} else {
	    set values [Flatten [lindex [GetModelValue $node] 0]]
        
	    for {set row 1} {$row<=$nrow} {incr row} {
		set rowData($row) {}
		for {set col 1} {$col<=$ncol} {incr col} {
		    set cell [expr ($row-1)*$ncol+$col-1]
		    set celval [lindex [lindex $values $cell] 1]
		    set useNodes($winId,values,$row,$col) [lindex $values $cell]
		    set length [llength $celval]
                
		    if {$length} {
			lappend rowData($row) [ForGrid $winId $celval]
		    } else {
			lappend rowData($row) grey
		    }
		}
	    }
	    for {set row $nrow} {$row>=1} {incr row -1} {
		lappend allData $rowData($row)
	    }
        }
        
        $useNodes($winId,hiddenMap) put $allData
    }

    proc ForGrid {winId celval} {
        variable useNodes
	
        set min $useNodes($winId,min)
	set max $useNodes($winId,max)
        set range [expr {$max-$min}]
	set nswatches $useNodes($winId,nswatches)
        
	if {$celval<$useNodes($winId,dataMin)} {
	    set useNodes($winId,dataMin) $celval
	}
	if {$celval>$useNodes($winId,dataMax)} {
	    set useNodes($winId,dataMax) $celval
	}
	if {$celval<=$min} {
	    set icolour 0
	} elseif {$celval>=$max} {
	    set icolour $nswatches
	} else {
	    set icolour [expr {int($nswatches*($celval-$min)/$range)}]
	}
	return $useNodes($winId,c$icolour)
    }

    proc DrawGrid6 {winId node} {
        variable useNodes


# do not use image mode for inputs cos we will want to edit them...
# hah, just fixed it so we can anyway
	if {[lsearch $useNodes($winId,tgtDims) START_VM]>-1 || \
		[catch {GetBinaryModelValue $node $useNodes($winId,min) \
			$useNodes($winId,max)} useNodes($winId,rawBinary)]} {
	    DrawGrid5 $winId $node
	    return
	}
#puts "Binary is of size [string bytelength $useNodes($winId,rawBinary)]"
	set rows $useNodes($winId,nrow)
	set cols $useNodes($winId,ncol)
	set bitCols [expr 4*int(($cols+3)/4)]
	set fullSize [expr 1078+$bitCols*$rows]
	set bmpData [binary format a2is2iiiissiiiiii \
		 BM $fullSize {0 0} 1078 40 $cols $rows 1 8 0 0 0 0 0 0]
	for {set rgbQuad 0} {$rgbQuad<256} {incr rgbQuad} {
	    set colourIndex [expr $rgbQuad*($useNodes($winId,nswatches)+1)/256]
	    set colourStr [Desystematize $useNodes($winId,c$colourIndex)]
	    append bmpData [binary format H2H2H2c \
				[string range $colourStr 9 12] \
				[string range $colourStr 5 8] \
				[string range $colourStr 1 4] 0]
	}
	set filling [string repeat 0 [expr $bitCols-$cols]]
	if {[string length $filling]} {
	    for {set row 0} {$row<$rows} {incr row} {
		append bmpData [string range $useNodes($winId,rawBinary) \
		        [expr $row*$cols] [expr $row*$cols+$cols-1]] $filling
	    }
	} else {
	    append bmpData $useNodes($winId,rawBinary)
	}
	$useNodes($winId,hiddenMap) configure -data $bmpData
    }

    proc zoomio {winId factor} {
        variable useNodes
        set view [$winId.c xview]
        set xmiddle [expr ([lindex $view 0]+[lindex $view 1])/2]
        set view [$winId.c yview]
        set ymiddle [expr ([lindex $view 0]+[lindex $view 1])/2]
        set next [expr round($factor*$useNodes($winId,mult))]
        if {$next==$useNodes($winId,mult)} {
            if $factor>1 {
                incr useNodes($winId,mult)
            } else {
                incr useNodes($winId,mult) -1
            }
        } else {
            set useNodes($winId,mult) $next
        }
        if {$useNodes($winId,mult)==1} {
	    ::graphtools::SetButtonState $winId zoomout disabled
            # disable zoom out button
        } else {
	    ::graphtools::SetButtonState $winId zoomout normal
        }
        
        $winId.c configure -scroll "0 0 \
                [expr $useNodes($winId,ncol)*$useNodes($winId,mult)] \
                [expr $useNodes($winId,nrow)*$useNodes($winId,mult)]"
        set view [$winId.c xview]
        $winId.c xview moveto [expr $xmiddle-([lindex $view 1]-[lindex $view 0])/2]
        set view [$winId.c yview]
        $winId.c yview moveto [expr $ymiddle-([lindex $view 1]-[lindex $view 0])/2]
        recolour_scale $::helperTable($winId,whichInstance) $winId
        PrepareSaveString $winId
    }
    
    proc ScrollPhoto {winId axis args} {
        #	puts $visible
	variable useNodes

        eval {$winId.${axis}scroll set} $args
        reposn_scale [namespace current] $winId
	if {$axis eq "v" && ![info exists useNodes($winId,groJob)]} {
	    set useNodes($winId,groJob) \
		[after 10 [namespace code [list FillCanvas $winId]]]
	}
    }
    
    proc FillCanvas {winId} {
	global graph
        variable useNodes
        
#	if {![winfo viewable $winId.c]} return
# was this to make it go faster or avoid some heinous Tk bug?
# removed 1/9/09 so grid not out-of-date when restored to view
	array unset useNodes $winId,groJob
	set mult $useNodes($winId,mult) ;# shorthand
        set visible [concat [$winId.c xview] [$winId.c yview]]
        set dataL [expr [lindex $visible 0]*$useNodes($winId,ncol)]
        set dataR [expr int(ceil([lindex $visible 1]*$useNodes($winId,ncol)))]
        set dataT [expr [lindex $visible 2]*$useNodes($winId,nrow)]
        set dataB [expr int(ceil([lindex $visible 3]*$useNodes($winId,nrow)))]
	set miss [expr {$graph(origin)+2}] ;# 2 is border width
	set atLeft [expr {-fmod($dataL,1)*$mult+$miss}]
	set atTop [expr {-fmod($dataT,1)*$mult+$miss}]
        $winId.c coords 1 [$winId.c canvasx $atLeft] [$winId.c canvasy $atTop]
#puts "Displaying $dataL $dataT $dataR $dataB"
        $useNodes($winId,visibleMap) copy $useNodes($winId,hiddenMap) \
	    -from [expr int($dataL)] [expr int($dataT)] $dataR $dataB -to 0 0 \
                -zoom $mult -shrink
	UpdateCaption useNodes $winId
# Above was commented out till 5.5 -- messy? Buggy?

# now superpose images if needed...first sort them by colour they replace
	if {$useNodes($winId,imgs)} {
# images can be all different sizes and shapes, so regularize
	    for {set c 0} {$c<=$useNodes($winId,nswatches)} {incr c} {
		if {[info exists useNodes($winId,i$c)]} {
		    set new [image create photo]
		    $new copy [GrowImage $useNodes($winId,i$c) $mult $mult]
		    set imgFor([winfo rgb $winId $useNodes($winId,c$c)]) $new
		}
	    }
	    for {set row [expr {int($dataT)}]} {$row<$dataB} {incr row} {
		for {set col [expr {int($dataL)}]} {$col<$dataR} {incr col} {
		    set dataPt [winfo rgb $winId [lindex [$useNodes($winId,hiddenMap) data -from $col $row [expr {$col+1}] [expr {$row+1}]] 0]]
		    if {[info exists imgFor($dataPt)]} {
#puts "Using image $imgFor($dataPt) for $dataPt"
			$useNodes($winId,visibleMap) copy $imgFor($dataPt) \
			    -to [expr {($col-int($dataL))*$mult}] \
			    [expr {($row-int($dataT))*$mult}]
		    }
		}
	    }
# tidy up
	    foreach new [array names imgFor] {
		image delete $imgFor($new)
	    }
	}
    }
    
    #### Handle value popup
    proc value_popup {winId X Y x y} {
        variable useNodes
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set col [expr int(1+([$winId.c canvasx $x])/$useNodes($winId,mult))]
        set row [expr int(1+$nrow-([$winId.c canvasy $y])/$useNodes($winId,mult))]
        if {$row>0&&$row<=$nrow&&$col>0&&$col<=$ncol} {
            if {![winfo exists .popup]} {
                toplevel .popup -width 1 -height 1 -bd 2 -relief raised
                wm overrideredirect .popup 1
                pack [message .popup.message -aspect 400 -bg \#ffffc0] \
                        -fill x -expand true
                raise .popup
            }
	    if {[info exists useNodes($winId,values)]} {
		if {[catch {set vLine $useNodes($winId,values,$row,$col)}]} {
		    set value none
		    set index none
		} else  {
		    set value [TransValue $useNodes($winId,dataETs) \
				   [lindex $vLine 1]]
		    set index [join [TransEnums $useNodes($winId,allETs) \
					 [lindex $vLine 0]] ,]
		}
		.popup.message config -text "Index=$index\nCol,row=($col,$row)\nValue=$value"
	    } else { # get approx value from raw data
		set cell [expr ($row-1)*$ncol+$col-1]
		if {![binary scan $useNodes($winId,rawBinary) \
			  x${cell}H2 hexo]} return
		set numValue [expr $useNodes($winId,min)+0x$hexo*($useNodes($winId,range))/255]
		set value [TransValue $useNodes($winId,dataETs) $numValue]
#puts "dot $hexo min $useNodes($winId,min) range $useNodes($winId,range)"
		.popup.message config -text "Col,row=($col,$row)\nValue=$value approx"
            }
            set xpoint [expr $X+15]
            set ypoint [expr $Y+43]
            wm geometry .popup +$xpoint+$ypoint
            update
        }
    }
    
    proc ChangeValue {winId newVal x y } {
        variable useNodes
        
        set ncol $useNodes($winId,ncol)
        set nrow $useNodes($winId,nrow)
        set col [expr int(1+([$winId.c canvasx $x])/$useNodes($winId,mult))]
        set row [expr int(1+$nrow-([$winId.c canvasy $y])/$useNodes($winId,mult))]
        if {$row>0&&$row<=$nrow&&$col>0&&$col<=$ncol} {
	    if {[info exists useNodes($winId,values)]} {
		set idx [lindex $useNodes($winId,values,$row,$col) 0]
	    } else {
		set cell [expr ($row-1)*$ncol+$col-1]
		set idx [lindex [FindIndices $useNodes($winId,tgtDims) $cell] 1]
	    }
	    PokeValue $useNodes($winId,color) $idx $newVal
#	DrawGrid6 $winId $useNodes($winId,color)
	    $useNodes($winId,hiddenMap) put $useNodes($winId,paintColour) \
		-to [expr $col-1] [expr $nrow-$row]
	    FillCanvas $winId
#puts "row,col $row,$col cell $cell idx $idx"
	}
    }
    
    proc FindIndices {bounds count} {
	set thisBound [lindex $bounds 0]
	if {$thisBound} {
	    set subs [FindIndices [lrange $bounds 1 end] $count]
	    set thisCount [lindex $subs 0]
	    set innerInds [lindex $subs 1]
	    return [list [expr $thisCount/$thisBound] \
			[concat [expr 1+$thisCount%$thisBound] $innerInds]]
	} else {
	    return [list $count {}]
	}
    }

    # need to recode for this legend
    proc ColourScale {winData winId} {
        #    ShowMess debug info "proc ColourScale" ok
        upvar 1 $winData useNodes
        for {set swatch 0} {$swatch<=$useNodes($winId,nswatches)} {incr swatch} {
            $winId.legend.pop$swatch configure -bg $useNodes($winId,c$swatch)
        }
    }
    
    
    proc SaveAsFile {winId} {
        global helperTable
        variable useNodes 

        # should have dialog to set for options
        set filename [ChooseFile image.gif [tr. "Save image as:"] 1 \
		 [$helperTable($winId,whichInstance) GetNode]]
        if {[string length $filename]} {
	    $useNodes($winId,visibleMap) write $filename \
		-format [string range [file extension $filename] 1 end]
	}
    }
} ;
# end of namespace
# VUK887468
