# Go for closest thing to the old 'agroforestry' colours?
# tk_bisque
# No, it's horrible...

# First few procedures in here are utilities used by both the 
# helper applications and the AME interface: put these in a new file.


source ../Run/graphs.tcl
source ../Run/utility.tcl
source ../Run/hai2mmii.tcl

proc AdjustScroll {canvas dir args} {
	if {[string compare [lindex $args 2] units] == 0} {
		set jump [expr 10*[lindex $args 1]]
		$canvas $dir [lindex $args 0] $jump units
	} else {
		eval {$canvas $dir} $args
	}
}

proc AdjustCanvas {winId dir args} {
    set tgt $winId.${dir}scroll
# hide scrollbar if full size
    if {[string match {0 1} $args]} {
	pack forget $tgt
    } else {
	if {[string match x $dir]} {
	    set placing {-side bottom -after $winId.toolSlot}
	} else {
	    set placing {-side right -before $winId.canvas}
	}
	eval {pack $tgt} $placing {-fill $dir}
	eval {$tgt set} $args
    }
}

proc TraceObj {winId x y} {
    global helperTable
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set target [$winId find closest $canx $cany]
    set node [ExtractPrologName $winId $target]

    if {[string compare $helperTable(current) none]} {
	ProdObj $node [ExtractCaption $winId $node]
    }
}

proc ModelWindow {winName} {
global tcl_platform
    menu ${winName}top
    toplevel $winName -menu ${winName}top
    
    switch $tcl_platform(platform) {
        windows { wm iconbitmap $winName -default ../Run/similev2.ico }
        unix { wm iconbitmap $winName @../Images/dribble.xbm}
    }
    # Create a scrollable canvas
    set c [canvas $winName.canvas \
	       -confine 1 \
	       -xscrollcommand "AdjustCanvas $winName x" \
	       -yscrollcommand "AdjustCanvas $winName y" \
	       -xscrollincrement 1 -yscrollincrement 1]
    # scrollincrements set the only way we can get precise scrolling...

# this rectangle will be resized to fill the scrollable area and coloured to
# show the background
    $c create rect 0 0 100 100 -outline {} -tag {/base/ /background/}

    # space for toolbar
    frame $winName.toolSlot
    pack $winName.toolSlot -fill x
    
    scrollbar $winName.xscroll -orient horizontal \
	-command [list AdjustScroll $c xview]
    scrollbar $winName.yscroll -orient vertical \
	-command [list AdjustScroll $c yview]
    
    pack $c -fill both -expand true
    
    bind $c <Configure> {SetSpace %W %w %h}
    return $c
}

proc TweakWindow {c winTitle scale wl wt wr wb bg args} {
    global window_info rads
#    put back if Windows users want respite from their gash placement system
#    wm geometry $winName +0+84
    
# set the display depths to those we recorded
    set cats {ghost_link influence variable flow \
	    compartment submodel caption sections}
    for {set depthParam 0} {$depthParam < [llength $args]} {incr depthParam} {
	set rads($c,[lindex $cats $depthParam]) [lindex $args $depthParam]
	WindowDetail $c [lindex $cats $depthParam] \
	    [lindex $args $depthParam] 0
    }

    $c configure -scrollregion "$wl $wt $wr $wb" \
	-width [expr $wr-$wl] -height [expr $wb-$wt]
# set initial scaling factors
    set window_info($c,width) [expr $wr - $wl]
    set window_info($c,height) [expr $wb - $wt]
    set window_info($c,scale) $scale
# last will be overwritten if drawing from Prolog

# Now just in case we are loading this from a .cnv file and Prolog doesnt
# know how big the canvas is...or something else funny is happening...
#    ResizeDesktop $c $wl $wt $wr $wb

    if {[string match image [$c type /base/]]} {
	$c coords /base/ $wl $wt
	base$c configure -width [expr int($wr-$wl)]
	base$c configure -height [expr int($wb-$wt)]
    } else {
	$c coords /base/ $wl $wt $wr $wb
    }
    ChangeParentTitle $c $winTitle $bg

    set topWin [winfo parent $c]
    scan [wm maxsize $topWin] "%d %d" mw mh
#ShowMessage debug info "$wl $wt $wr $wb <> $mw $mh" ok
    if {[pack propagate $topWin] &&
		($wr-$wl >= $mw-8 || $wb-$wt >= $mh-8)} {
	focus $c
	update
	maximize_fg_win 1
    }
#ShowMessage debug info "Just done [$c coords 1]" ok
}

proc ChangeParentTitle { wc title colour } {
    wm title [winfo parent $wc] $title
    if {[string match clear $colour]} {
	set colour {}
    }
# ok now base item can be an image or a rect...
    if {[string match image [$wc type /base/]]} {
	scan [$wc coords /base/] {%f %f} bl bt
	set br [expr $bl+[base$wc cget -width]]
	set bb [expr $bt+[base$wc cget -height]]
	image delete base$wc
    } else {
	scan [$wc coords /base/] {%f %f %f %f} bl bt br bb
    }
    $wc delete /base/
    if {[catch {image type $colour}]} {
	$wc create rectangle $bl $bt $br $bb -outline {} -fill $colour \
	    -tag "/base/ /background/"
    } else {
	image create photo base$wc
	$wc create image $bl $bt -anchor nw -image base$wc \
	    -tag "/base/ /background/ source($colour)"
    }
    $wc lower /base/
    ResizeBackgnd $wc $bl $bt $br $bb
}

proc ResizeBackgnd {wc l t r b} {
    if {[string match image [$wc type /base/]]} {
	set oldW [base$wc cget -width]
	set oldH [base$wc cget -height]
	$wc coords /base/ $l $t
	set w [expr int($r-$l)]
	set h [expr int($b-$t)]
	base$wc configure -width $w -height $h
	regexp {source\(([^\)]+)\)} [$wc gettags /base/] all sourceImage
	base$wc copy $sourceImage -to 0 0 $w $h ;# clever stuff later
    } else {
	$wc coords /base/ $l $t $r $b
    }
}

# SetSpace: this command is called when the canvas is 'configured' by attacking
# its window's borders and so forth. It saves the new width and height of the
# canvas (This is Tk 4.0 which is too dumb to do it itself) and informs Prolog
# of the visible area of the scrollregion. We don't get any information about
# which way the window was grown so the diagram is kept in the middle.

proc SetSpace {c w h} {
    global window_info
    set cx $window_info($c,width)
    set cy $window_info($c,height)
    set window_info($c,width) [expr $w - 4]
    set window_info($c,height) [expr $h - 4]
#ShowMessage debug info "New size is $w $h" ok
    RollBack $c 1 [expr ($cx - $w)/2 + 2] [expr ($cy - $h)/2 + 2] \
	[expr ($cx + $w)/2 - 2] [expr ($cy + $h)/2 - 2]
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

    ZoomImage $winId all $factor $factor

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

proc ZoomImage {winId which factor fontor} {
    global window_info looks

    $winId scale $which 0 0 $factor $factor
    if {[string compare $which all]} {
	set objList [$winId find withtag $which]
    } else {
	set objList [$winId find all]
	# and update the info...
	set window_info($winId,scale) \
		[expr $window_info($winId,scale) * $factor]

    }
	foreach object $objList {
	    switch [$winId type $object] {
		text {
		   set fontData [ExtractFontData [$winId itemcget $object -font]]
			set newTextSize [expr round([AdjustWidth $winId $object $fontor])]
			if {$newTextSize < 10} {
				set newTextSize 10
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

		    if {[string match */base/* [$winId gettags $object]]} {
			ResizeBackgnd $winId $newX $newY \
			    [expr $newX+$newWidth] [expr $newY+$newHt]
		    } else {
			set shortSide [expr $newWidth<$newHt?$newWidth:$newHt]
			set intRad [expr int($looks(submodel,objectsize)* \
						 $shortSide/400)]
			$tgtImage config -width $newWidth -height $newHt
			regexp {source\(([^\)]+)\)} [$winId gettags $object] \
			    all sourceImage
			FillSmImage $sourceImage $tgtImage $newWidth $newHt \
			    $intRad
		    }
		} default {
		    $winId itemconfigure $object \
					-width [AdjustWidth $winId $object $factor]
		}
	    }
	}
}

# textsize is not used, we now keep track of it separately to avoid rounding
proc ExtractFontData {font} {
	scan $font {-Adobe-%[^-]-%[^-]-%[^-]-Normal--*-%d-*-*-*-*-*-*} \
		family weight style textsize
	return [list $family $weight $style $textsize]
}

proc AssembleFont {family weight style textsize} {
	return [format "-Adobe-%s-%s-%1s-Normal--*-%d-*-*-*-*-*-*" \
			$family $weight $style $textsize]
}

# This updates the width of a canvas object when it is zoomed. The actual width
# is rounded internally to an integer, so we store the full value in a tag called
# realwidth(...) which is also updated by this procedure.

proc AdjustWidth {winId object factor} {
    if {[regexp {realwidth\(([0-9\.]+)\)} [$winId gettags $object] \
	    tag oldWidth]} {
	$winId dtag $object $tag
	set width [expr $oldWidth*$factor]
	$winId addtag realwidth($width) withtag $object
	return $width
    } else {
	return 1
    }
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
    if {[scan [$winId bbox size_on_this] "%d %d %d %d" \
		bl bt br bb] == 4} {
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

    ZoomImage $winId all $scale $scale

    set bl [expr $bl*$scale]
    set bt [expr $bt*$scale]
    set br [expr $br*$scale]
    set bb [expr $bb*$scale]

    ResizeDesktop $winId $bl $bt $br $bb
    }
}

proc DisplayArea {winId} {
    global window_info
    if {[scan [$winId bbox unfinished_component] "%d %d %d %d" bl bt br bb] < 4} {
	return
    }
    set allowScrollBar [winfo reqwidth [winfo parent $winId].yscroll]
# zoom to correct size
    set xscale [expr ($window_info($winId,width) - $allowScrollBar)/double($br - $bl)]
    set yscale [expr ($window_info($winId,height) - $allowScrollBar)/double($bb - $bt)]
    set factor [expr $xscale>$yscale?$yscale:$xscale]
    
    ZoomImage $winId all $factor $factor
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

proc ExtractPrologName { winId target } {
    set tagList [$winId gettags $target]
    set objNamePosn [lsearch -regexp $tagList {(node)|(arc)[0-9]*}]
    return [lindex $tagList $objNamePosn]
}

proc ExtractCaption {win variable} {
    set capt $variable
    foreach obj [$win find withtag $variable] {
	if {[string compare [$win type $obj] text] == 0} {
	    set capt [$win itemcget $obj -text]
	}
    }
    return $capt
}

set adds none

proc AddZoomMenu {canvas menu tellProlog} {
	$menu add cascade -label Zoom -menu $menu.sub2
	set fm2 [menu $menu.sub2 -tearoff 0]
	$fm2 add command -label "In lots" -command "DoZoom \
			$canvas 1.953125 $tellProlog"
	$fm2 add command -label "In a bit" -command "DoZoom \
			$canvas 1.25 $tellProlog"
        $fm2 add command -label "To fit" -command "DisplayAll $canvas"
	$fm2 add command -label "Out a bit" -command "DoZoom \
			$canvas 0.8 $tellProlog"
	$fm2 add command -label "Out lots" -command "DoZoom \
			$canvas 0.512 $tellProlog"

}

proc AddFindMenu {canvas menu} {
    $menu add separator
    $menu add command -label Find... -command "FindCaption $canvas" \
                -accelerator "Ctrl+F"
    $menu add command -label "Find next" -command "NextCaption $canvas" \
                -accelerator "F3"
}

proc FindCaption {canvas} {
    global find
    set findable [GetFindText $canvas]
    if {[string compare $findable {}]} {
	set find(List,$canvas) {}
	foreach caption [$canvas find withtag is_caption] {
	    if {[string match *$findable* [$canvas itemcget $caption -text]]} {
		lappend find(List,$canvas) $caption
	    }
	}
	NextCaption $canvas
    }
}

proc NextCaption {canvas} {
    global looks find window_info
    if {![info exists find(List,$canvas)]} {
	ShowMessage "Operation failed" error "No search in progress!" ok
	return
    }
    if {[info exists find(now,$canvas)]} {
	FlashSymbol $canvas $find(now,$canvas) $looks(variable,outline) \
		$looks(variable,text)
    }
    if {![llength $find(List,$canvas)]} {
	ShowMessage "Caption finder" info \
		"No more matching captions in this window" ok
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
	FlashSymbol $canvas $find(now,$canvas) orange orange
#	HandleObjClick $canvas $this clicktext $tgtX $tgtY
#	ReleaseObj $canvas $tgtX $tgtY
    }
}

proc MakeHelperMenu {} {
	set fm [menu .helpers -tearoff 0]

	$fm add command -label "Load" -command LoadView
	$fm add command -label "Save" -command SaveView
	$fm add command -label "Clear" -command ClearView
	$fm add command -label "Close" -command KillHelpers
    $fm add command -label "Parameters..." \
    		    -command {FileParamDialogue 1 [focus]}

    set oldDir [pwd]
	cd ../IOTools
	AddHelperSublist $fm "Add tool" 2
	cd $oldDir
}

# OK I have been having problems with people duplicating IO tool programs
# and not changing the key values, thus allowing one to overwrite the other.
# So one day, IO tools will not include a namespace spec, but this code
# will load them into one, so they should still use [namespace code ...] to
# make callbacks.

proc AddHelperSublist {fm title ct} {
    global custom helperTable ;# custom used at toplevel in iotools
    $fm add cascade -label $title... -menu $fm.sub$ct
    set m [menu $fm.sub$ct -tearoff 0]
    set nct 0
    set helperList [glob -nocomplain *.tcl]
    foreach helperApp [lsort $helperList] {
	if [catch {source $helperApp} wibble] {
	    ShowMessage "Error loading I/O tool" warning \
		    "I/O tool [pwd]/$helperApp had a $wibble" ok
	} else {
	    if {[info exists keyValue]} {
		set action [${keyValue}::identify]
		if {[string match {Run control} $action]} {
		    set helperTable(RunControl) $keyValue
		}
		if {[string match {Slider control} $action]} {
		    set helperTable(SliderControl) $keyValue
		}
		if {[string match {Storing data table} $action]} {
		    set helperTable(TableViewer) $keyValue
		}
		$m add command -label $action \
			-command [list CreateHelperWindow $keyValue $action]
		unset keyValue
	    }
	}
    }
    foreach subDir [glob -nocomplain *] {
	if [file isdirectory $subDir] {
	    cd $subDir
	    AddHelperSublist $m $subDir $nct
	    cd ..
	    incr nct
	}
    }
}

# new technology -- just one copy of the helper menu is made on startup
# and it is put in all menubars

MakeHelperMenu

set helperTable(current) none

proc CreateHelperWindow {helperId helperTitle} {
	${helperId}::initialize [NewHelperWindow $helperId $helperTitle]
}

proc NewHelperWindow {helperId helperTitle} {
    global helperTable tcl_platform
    
# ShowMessage debug info "Making $helperId $helperTitle" ok
    if {[PrefValue custom(helperManager) helperManager]} {
        set winId [NewMreHelperWindow $helperId $helperTitle]
    } else {
        set winId .helper[newInt]
        set helperTable($winId,whichHelper) $helperId
        toplevel $winId
        wm title $winId $helperTitle
	wm iconbitmap $winId @../Images/weegraph.xbm
        wm protocol $winId WM_DELETE_WINDOW "kill_helper_window $winId"
    }
    return $winId
}

# modelRunning is a global variable that indicates the status of the model
# program: 0 = none, 1 = out of date, 2 = up to date.

set runState(modelRunning) 0

# RunDialog is called when the user builds a new model program. It marks the
# current model as up to date, initializes the model and makes sure there is
# an instance of the run control on the screen

proc RunDialog {canvas} {
    global runState helperTable

#    ShowMessage debug info enter(RunDialog) ok

    set defHelper $helperTable(RunControl)
    set runState(modelRunning) 2
    set runState(activeWindow) $canvas
# old location for this step
#    if {[UsingBLT]} {
#	Makemre $canvas
#    }
    if {[regexp "(.helper\[0-9\]+),whichHelper $defHelper" \
	    [array get helperTable] spare helperId]} {
	kill_helper_window $helperId
    }
    set helperId [NewHelperWindow $defHelper "Default run control"]
    ${defHelper}::initialize $helperId

    ${defHelper}::SetMode $helperId reset
    set runState(helperId) $helperId
    
    MakeSlidersForInputs

    if {[PrefValue custom(helperManager) helperManager]} {
        CreateHelperWindow $helperTable(VariableList) "Variables"; # JMM
    }
}

# If running a model which includes input parameters, we must
# make sure that these are somehow provided with inputs before
# trying to evaluate expressions in which they occur. This is
# done by creating a slider panel for them here.

# switch and switchd are binary inputs so should be set by
# toggles rather than sliders. Later...

proc UnMakeSlidersForInputs { } {
    global helperTable checkStates sliderVals
    # puts $inlist
    if {[info exists helperTable(autosliders)]} {
	kill_helper_window $helperTable(autosliders)
	unset helperTable(autosliders)
    }

    if {[info exists checkStates]} {
	unset checkStates
    }
    if {[info exists sliderVals]} {
	unset sliderVals
    }
}

proc MakeSlidersForInputs { } {
    global helperTable
    set helperTable(autosliders) [NewHelperWindow $helperTable(SliderControl) \
	    "Sliders for inputs"]
    $helperTable(SliderControl)::initialize $helperTable(autosliders)
}

# grab_clicks and release_clicks enable helper apps to ask
# the model to send mouse clicks to them while they are setting
# themselves up, or to the editor once they are done.

proc GrabClicks {winId} {
    global helperTable

    set helperTable(current) $winId
}

proc ReleaseClicks {winId} {
	global helperTable

	set helperTable(current) none
}

proc kill_helper_window { winId } {
# ShowMessage debug info "Killing $winId" ok
    global helperTable
    if {[info exists helperTable($winId,whichHelper)]} {
	if {[string compare $helperTable(current) $winId]==0} {
		set helperTable(current) none
	}
	unset helperTable($winId,whichHelper)
	destroy $winId
#	if {[PrefValue custom(helperManager) helperManager]} {
#	    RunEnv::OnDestroyHelper $winId
#	}
# ShowMessage debug info "Killed $winId" ok
    }
}

proc GetState {winId} {
	global helperTable
    return $helperTable($winId,status)
}

proc SetState {winId newState} {
	global helperTable
    set helperTable($winId,status) $newState
}

proc ProdObj {nodeId caption} {
    global helperTable

    switch -regexp [GetModelType $nodeId] {
	REAL|INTEGER|FLAG {
	    set target $helperTable(current)

	    set helperId $helperTable($target,whichHelper)
	    ${helperId}::click $target $nodeId $caption
	} default {
	    ShowMessage "Clicked on $caption" error \
		    "This component cannot be selected for an I/O tool because it has no associated value." ok
	}
    }
}

# GetClickedObj: returns the object at the target position. We want to return
# the closest object within a certain number of pixels. Since there is always
# something in the background we will get that if our search radius is too 
# small, so we gradually increase it until we find a non-background thing or
# we reach the edge of our search radius.

proc GetClickedObj { winId canx cany range} {
    for {set halo 1} {$halo < $range} {incr halo 2} {
	set target [$winId find closest $canx $cany $halo]
	if {![string match */background/* [$winId gettags $target]]} {
	    return $target
	}
    }
    return 0
}

proc BindPopup {widget keywd} {
    bind $widget <Enter> [list QueuePopup "AddWidgetPopup $keywd %X %Y"]
    bind $widget <Leave> RemovePopup
}

proc MenuBindPopup {widget keyList} {
    bind $widget <Enter> [list QueuePopup \
			      [list AddMenuPopup $widget $keyList %y %X %Y 1]]
    bind $widget <Motion> [list AddMenuPopup $widget $keyList %y %X %Y 0]
    bind $widget <Leave> RemovePopup
}

# This is used for items on IO tool canvases -- model components have eqnpopups
proc CanvasBindPopup {canvas widget keywd} {
    $canvas bind $widget <Enter> [list QueuePopup \
	    [list AddWidgetPopup $keywd %X %Y]]
    $canvas bind $widget <Leave> RemovePopup
}

proc QueuePopup {cmd} {
    global popper
#puts "queueing $cmd"
    set popper [after 500 $cmd]
}

proc AddEqnPopup {x y winId X Y} {
    global pushedbutton running_c equationbar
    set doDesc [PrefValue custom(compDescPop) compDescPop]
    set doVal [PrefValue custom(compValPop) compValPop]
    set doCmt [PrefValue custom(compCmtPop) compCmtPop]
    if {[string compare select $pushedbutton] || \
	    !$doDesc && !$doVal && !$doCmt} {
	return
    }
    set canx [$winId canvasx $x]
    set cany [$winId canvasy $y]
    set target [GetClickedObj $winId $canx $cany 2]
#    set target [$winId find closest $canx $cany 1]
#puts "targeting $target"
    if {$target} {
	PostPopup $X $Y
	set plName [ExtractPrologName $winId $target]
	if {$doDesc} {
	    set fromProlog [GetFromProlog tk_get_info('$winId',$plName,eqn)]
	    if {![string length $fromProlog] || \
		    [string match $fromProlog <none>]} {
		set fromProlog \
		    [GetFromProlog tk_get_info('$winId',$plName,desc)]
	    }
# after going Prolog, check popup window still there
# note colour etc are not comments though they look like them in emacs
	    if {![winfo exists .popup]} return
	    AddPopupMessage $fromProlog #c0ffc0 0
	}
	if {$doCmt} {
	    set fromProlog [GetFromProlog tk_get_info('$winId',$plName,comment)]
	    if {![winfo exists .popup]} return
	    AddPopupMessage $fromProlog #ffe0c0 0
	}
        if {[expr [info exists running_c] && $doVal]} {
	    AddPopupMessage [lindex [GetModelValue $plName] 0] #ffffc0 1
# we might want to prettify this a bit first
	}
    }

}

proc AddPopupMessage {text colour isValue} {
    set verbosity [string length $text]
    if {$verbosity<20} {
	pack [label .popup.message$colour \
		-text $text -bg $colour] -fill x -expand true
    } else {
	if {$verbosity>500} {
	    if {$isValue} {
		set nvals " ([CountValues $text] values)"
	    } else {
		set nvals " ($verbosity characters)"
	    }
	    set text [string range $text 0 240].....[string range $text \
		    [expr $verbosity-240] end]
	    append text $nvals
	}
	pack [message .popup.message$colour -aspect 400 \
		-text $text -bg $colour] -fill x -expand true
    }
}

proc CountValues {text} {
    set len [llength $text]
    if {$len==1} {
	return 1
    } else {
	set tot 0
	for {set n 1} {$n<$len} {incr n 2} {
	    incr tot [CountValues [lindex $text $n]]
	}
	return $tot
    }
}

# # character in colour spec is escaped purely for the benefit of the Emacs
# tcl mode parser

proc AddWidgetPopup {key X Y} {
    global msgs
    PostPopup $X $Y
    if {[info exists msgs($key)]} {
	set message $msgs($key)
    } else {
	set message $key
    }
    pack [message .popup.message -aspect 400 \
	    -text $message -bg \#ffffc0] -fill x -expand true
}

proc AddMenuPopup {widget list y X Y new} {
    if {$new} {
	PostPopup $X $Y
	pack [message .popup.message -aspect 400 -bg \#ffffc0] \
	    -fill x -expand true
    }
    set entry [$widget index @$y]
    if {[string match none $entry] || ![winfo exists .popup.message]} {
	return
    }
    set line [lindex $list $entry]
    set message "[lindex $line 1]: [lindex $line 0]"
    .popup.message configure -text $message
}
    

proc PostPopup {X Y} {
    if {[winfo exists .popup]} {
	destroy .popup
    }
    toplevel .popup -width 1 -height 1 -bd 2 -relief raised
    wm overrideredirect .popup 1

# This moves the popup window to whichever quadrant of the moused-over
# component is all on the screen. It sticks it to the bottom left to start with
# so it doesn't grab the focus, then updates so the requested size can be found
# then uses this size to move it to the right place

    if {$X>[winfo screenwidth .popup]/2} {
	set xpoint -[expr [winfo screenwidth .popup]+10-$X]
    } else {

	set xpoint +[expr $X+10]
    }
    if {$Y>[winfo screenheight .popup]/2} {
	set ypoint -[expr [winfo screenheight .popup]+10-$Y]
    } else {
	set ypoint +[expr $Y+10]
    }
    wm geometry .popup ${xpoint}${ypoint}
    raise .popup
}

# args are not used -- when binding to a table wigdet we cannot avoid getting
# the item name on the end of the call

proc RemovePopup {args} {
    global popper
    if {[winfo exists .popup]} {
	destroy .popup
    } elseif {[info exists popper]} {
	after cancel $popper
    }
}

proc Prettify {value} {
    if {[llength $value]==1} {
	return $value
    } else {
	set newValue {}
	while {[llength $value]} {
	    lappend newValue [join [list [lindex $value 0] \
		    [Prettify [lindex $value 1]]] :]
	    set value [lrange $value 2 end]
	}
	return $newValue
    }
}

proc UpdateTimes { current left } {
	global sendvars
	set sendvars(currentTime) $current
	set sendvars(execTime) $left
}

# After the initial model has been loaded we don't want to allow the window
# to change size when something different is loaded
# This is also a convenient time at which to hide the console
# if it is showing
proc FixSize {c} {
    global custom
    update idletasks
    maximize_fg_win 0 ;# seems necessary for console to hide
    catch {console hide}	
    if {[file exists $custom(prefDir)/layout]} {
	set stream [open $custom(prefDir)/layout r]
	gets $stream whetherMaxed
#ShowMessage debug info $whetherMaxed ok
	maximize_fg_win $whetherMaxed
	close $stream
    }
    pack propagate [winfo parent $c] 0
}
    
proc DestroyHelpers {} {
    global modelWin
    KillHelpers
    if {[winfo exists .mre]} {
    ::RunEnv::Destroy
    }
}

proc KillHelpers {} {
	global helperTable
	foreach graphBox [array name helperTable *,whichHelper] {
		scan $graphBox {%[^,]} window
		kill_helper_window $window
	}
}

proc ClearView {} {
	global helperTable

	foreach displayBox [array name helperTable *,whichHelper] {
		scan $displayBox {%[^,]} winId
		set helperId $helperTable($displayBox)
        catch {${helperId}::clear $winId}; # in case helper has no clear proc
   }
}

proc BlankCrs {withCrs} {
    regsub -all \n $withCrs { } noCrs
    return $noCrs
}

proc StripCrs {withCrs} {
    regsub -all \n $withCrs \\n noCrs
    return $noCrs
}

proc RestoreCrs {noCrs} {
    regsub -all \\\\n $noCrs \n withCrs

    return $withCrs
}

proc SaveView {} {
    global helperTable
    set savedView [ChooseFile iotools.shf "Save view specification file" 1]
    if {[llength $savedView]} {
	set stream [open $savedView w]
	foreach displayBox [array name helperTable *,whichHelper] {
	    scan $displayBox {%[^,]} winId
	    set helperId $helperTable($displayBox)
	    if {!([string match $helperId $helperTable(RunControl)] || \
		    [string match $helperId $helperTable(SliderControl)])} {
		puts $stream $helperId
		# substitute <cr>s so entry goes on one line
		puts $stream [StripCrs [wm title $winId]]
		puts $stream [wm geometry $winId]
		set clickedPaths {}
		if {[info exists helperTable($winId,status)]} {
		    puts $stream [StripCrs $helperTable($winId,status)]
		} else {
		    puts $stream {}
		}
	    }
	}
	close $stream
    }
}

proc LoadView {} {
    global helperTable
    set savedView [ChooseFile iotools.shf "Open view specification file" 0]
    if {[llength $savedView]} {
	set stream [open $savedView r]
	while {[gets $stream helperId] >= 0} {
	    gets $stream helperTitle
	    set winId [NewHelperWindow $helperId [RestoreCrs $helperTitle]]
	    gets $stream geometry
	    wm geometry $winId $geometry
	    gets $stream oldStatus
	    set helperTable($winId,status) [RestoreCrs $oldStatus]
	    ${helperId}::Restore $winId
	}
	close $stream
    }
}

proc DoDisplay {current display exec} {
	global helperTable

	foreach displayBox [array name helperTable *,whichHelper] {
		scan $displayBox {%[^,]} winId
		set helperId $helperTable($displayBox)
		${helperId}::display $winId $current $display $exec
	}
}

proc AlterModel {} {
    global runState
    set runState(modelRunning) 1
}

proc ScrubRun {times} {
    global runState running_c model_id instance_id
#    if {![string match ok [ShowMessage debug info Scrubbing okcancel]]} {
#	error Bombed
#    }
    set runState(modelRunning) 0
    if {$times && [info exists runState(currentTime)]} {
	unset runState(currentTime)
    }
    if {[info exists model_id]} {
	if {$model_id} {
	    if {[info exists instance_id]} {
#ShowMessage debug info "Exiting $model_id $instance_id" ok
		c_exitmodel $model_id $instance_id
		unset instance_id
	    } else {
#ShowMessage debug info "Exiting $model_id 0" ok
		c_exitmodel $model_id 0
	    }
	} else {
	    namespace delete ::AME_model<>
	}
	unset model_id
	ToggleIOToolMenu 0
    }
    if {[info exists running_c]} {unset running_c}
}

proc GetModelTime {} {
	global runState
	return $runState(currentTime)
}

proc start_run {lang winId} {
    global runState
    global window_info

# ShowMessage debug info enter(start_run) ok
    if {[PrefValue custom(helperManager) helperManager]} {
#    ShowMessage debug info "About to make MRE [array name window_info *,parent]" ok
    set mre [Makemre $winId]
    foreach winData [array name window_info *,parent] {
        set toolBar $window_info($winData).toolSlot.toolbar
        $toolBar.snap configure -state active
        set navBar $window_info($winData).toolSlot.navbar
        $navBar.runenv configure -state active
    }
    }
    if {[info exists runState(currentTime)]} {
	if {$runState(execTime) != $runState(currentTime)} {
	    set runState(execTime) \
		    [expr $runState(execTime)+$runState(currentTime)]
	}
	for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
	    if {![info exists runState(prev_update$phase)]} {
		set runState(update$phase) 0.1
		set runState(prev_update$phase) 0.1
	    }
	    SetStep $runState(prev_update$phase) $phase
	}
    } else {
	set runState(execTime) 100
	set runState(displayInt) 1
	for {set phase 1} {$phase <= [GetPhaseCount]} {incr phase} {
	    set runState(update$phase) 0.1
	    set runState(prev_update$phase) 0.1
	    SetStep 0.1 $phase
	}
    }
    set runState(currentTime) 0.0
    set runState(currentWin) $winId ;# enables rebuild from run control
    FileParamDialogue 0 $winId
    if {[PrefValue custom(helperManager) helperManager]} {
        raise $mre
    } else {

	ToggleIOToolMenu 1
    }
    
    set runState(reloadParams) 1 

# MakeSlidersForInputs is currently done after initializing the
# model, so default values calculated from eqns can be loaded to the
# sliders. Here we must clear any old input tool values so they are not used.

    UnMakeSlidersForInputs
}

proc FileParamDialogue {mustShow parent} {
    global paramData widgetNames
    set allNodes [GetObjectList] 
# do it now to shake out errors before opening window

    set t [toplevel .fpdialogue]
    wm transient $t $parent
    wm title $t "Enter file parameters"
    set needed {}
    MakeFrames $t
    foreach node $allNodes {
	if {[string match TABLE [GetModelEval $node]]} {
	    set compName [GetCaptionPathFromId $node]

	    set levels [lrange [split $compName /] 1 end]
	    pack [set slot [frame [MakeSubFrames $t.sliderframe $levels]]]
	    pack [label $slot.l -text [lindex $levels end]:] -side left
	    pack [button $slot.b -text "Read table" \
		    -command [list GetFromTable $t $compName]] -side right
	    
#	    pack [entry $slot.e -textvariable paramData($compName)]
# Using entries played merry hell with very long arrays -- texts work better
	    pack [text $slot.e -width 30 -height 1]
	    if {[info exists paramData($compName)]} {
		$slot.e insert 1.0 $paramData($compName)
	    } else {
		set paramData($compName) {}
	    }
	    set widgetNames($compName) $slot.e

# note whether we need to enter a parameter here...
	    if {![llength $paramData($compName)]} {
		lappend needed $compName
	    }
	}
    }
    if {$mustShow || [llength $needed]} {
	pack [set bfrm [frame .fpdialogue.buttons ]] \
		-fill x
	pack [message $bfrm.banner \
		-text "All values must be set to run the model." -width 400]
    pack [frame $bfrm.lpad] -side left -fill x -expand true
    pack [button $bfrm.ok -text "OK" -command [list DoneParams $needed] -width 10] \
        -side left -padx 2 -pady 2
    pack [button $bfrm.merge -text "Load file" -command MergeParams -width 10] \
        -side left -padx 2 -pady 2
	pack [button $bfrm.save -text "Save file" -command SaveParams -width 10] \
        -side left -padx 2 -pady 2
    pack [button $bfrm.help -text "Help" -command {ContextSensitiveHelp .fpdialogue data/index.htm} -width 10] \
        -side left -padx 2 -pady 2            
	pack [frame $bfrm.rpad] -side left -fill x -expand true
	set_size $t
	raise .fpdialogue
	grab $t
	tkwait variable paramData(/done/)
	grab release $t

    }
    destroy $t
}

proc MakeFrames {windowId} {
    frame $windowId.c
    set canId $windowId.c.canvas
    ScrollableFrame $canId -width 10 -height 10 -yscrollincrement 1 \
	-yscrollcommand [list $windowId.c.yscroll set] -constrainedwidth true
    scrollbar $windowId.c.yscroll -orient v -command [list $canId yview]

    pack $windowId.c.yscroll -side right -fill y
    pack $canId -side left -fill both -expand true
    pack $windowId.c -side top -fill both -expand true

    pack [frame $windowId.buttonframe] -side bottom
#    $canId create window 0 0 -anchor ne -window [frame $windowId.checkframe]
#    $canId create window 0 0 -anchor nw -window [frame $windowId.sliderframe]
    pack [frame $windowId.checkframe] -in [$canId getframe] -side left
    pack [frame $windowId.sliderframe] -in [$canId getframe] -side right \
	-fill x -expand true
}

proc MakeSubFrames {parent hierarchy} {
    if {[llength $hierarchy]<=1} {
	return $parent.box$hierarchy
    } else {
	set level [lindex $hierarchy 0]
	set nextLevel $parent.frame$level
	if {![winfo exists $nextLevel]} {
	    pack [frame $nextLevel -bd 2 -relief sunken] -fill x -expand true
	    pack [label $nextLevel.label -text $level:]
	}
	return [MakeSubFrames $nextLevel [lrange $hierarchy 1 end]]
    }
}

proc set_size {winId} {
    update
# This pauses the process until all widgets are drawn. Previously I had a
# tkwait visibility for the one I just added, but for some mysterious reason
# this waited forever when applied to the checkbutton widgets.
    set cwidth [winfo reqwidth $winId.checkframe]
    set swidth [winfo reqwidth $winId.sliderframe]
    set height [max [winfo reqheight $winId.checkframe] \
	    [winfo reqheight $winId.sliderframe]]
    $winId.c.canvas configure -areawidth [expr $cwidth+$swidth] \
	-areaheight $height -width [expr $cwidth+$swidth] \
	-height [min $height 200]
}

proc DoneParams {oldMissing} {
    global paramData widgetNames runState running_c

    foreach node [GetObjectList] {
	if {[string match TABLE [GetModelEval $node]]} {
	    set compName [GetCaptionPathFromId $node]
	    set paramData($compName) [$widgetNames($compName) get 1.0 1.end]
#ShowMessage debug info "-paramData($compName)- is -$paramData($compName)-" ok
	    if {![llength $paramData($compName)]} {
		set empties 1
# for each constant value, check whether it has been changed, and if so,
# flag a complete model rebuild. Do same if running_c lost due to crash
	    } elseif {[lsearch $oldMissing $compName] > -1} {
		set runState(reloadParams) 1
	    } elseif {![info exists running_c]} {
		set runState(reloadParams) 1
	    } elseif {[string compare [lindex [GetModelValue $node] 0] \
		    $paramData($compName)]} {
		set runState(reloadParams) 1
	    }
	}
    }
    if {[info exists empties]} {
	.fpdialogue.buttons.banner configure -text "Some values still missing!"
    } else {
	set paramData(/done/) 1
    }
}

proc FileCollect {tgt node argList} {
    global paramData
    set compName [GetCaptionPathFromId $node]

    set field $paramData($compName)
    while {[string compare $argList {}]} {
#ShowMessage debug info "Array setting $field" ok
	array set items $field
	set field $items([lindex $argList 0])
	set argList [lrange $argList 1 end]
    }
    set $tgt $field ;# tgt is passed by reference
}

proc SaveParams {} {
    global paramState paramData widgetNames

    set metaFile [ChooseFile params.spf "Save parameters as:" 1]
    if {[llength $metaFile]} {
	set pStr [open $metaFile w]




	foreach node [GetObjectList] {
	    if {[string match TABLE [GetModelEval $node]]} {
		set compName [GetCaptionPathFromId $node]
		set paramData($compName) [$widgetNames($compName) get 1.0 1.end]
		
		if {[info exists paramState($compName)]} {
		    if {[string compare $paramData($compName) \
			    [LoadTableData $paramState($compName)]]} {
			unset paramState($compName)
		    }
		}
		set SubbedComp [StripCrs $compName]
		if {[info exists paramState($compName)]} {
		    set relName [Relativize $metaFile \
			    [lindex $paramState($compName) 0]]
		    puts $pStr "$SubbedComp=[lreplace $paramState($compName) \
			    0 0 $relName]"
		} else {
		    puts $pStr "$SubbedComp=$paramData($compName)"
		}
	    }
	}
	close $pStr
    }
}	

# merge a parameter metafile. These are saved with the pathnames of the .csv files
# relative to the location of the metafile, so in order to reload the .csvs we need to
# reconnect them with this pathname...trouble is, if I save in a new directory I'll need
# new relative pathnames and I can only generate these starting from the absolute
# pathname. And the only way to get that without a hack is to cd to it...

proc MergeParams {} {
    global paramState paramData widgetNames


    set oldDir [pwd]
    set metaFile [ChooseFile params.spf "Merge parameters from:" 0]
    if {[llength $metaFile]} {
	set pStr [open $metaFile r]
	while {[gets $pStr savedValue] != -1} {
#ShowMessage debug info "Restoring $savedValue" ok
	    set IdAndValue [split $savedValue =]
	    set restoredComp [RestoreCrs [lindex $IdAndValue 0]]
#ShowMessage debug info "Component is $restoredComp, looking in [winfo children .fpdialogue.sliderframe]" ok
	    if {[info exists paramData($restoredComp)]} {
		set paramData($restoredComp) [lindex $IdAndValue 1]
#ShowMessage debug info "Param data is $paramData($restoredComp)" ok
		set FileOrVal [lindex $paramData($restoredComp) 0]

# OK here we go...try and follow this...first go to the starting point..
		cd [file dirname $metaFile]
		if {[file exists $FileOrVal]} {
# Now use the saved relative path to move to the .csv file's directory
		    cd [file dirname $FileOrVal]
# ...and stick the new absolute pathname into the spec! Easy!!
		    set paramState($restoredComp) \
			[concat [list [pwd]/[file tail $FileOrVal]] \
			     [lrange $paramData($restoredComp) 1 end]]
# now just load up the data
#ShowMessage debug info "Field spec set to $paramState($restoredComp)" ok
		    set paramData($restoredComp) \
			    [LoadTableData $paramState($restoredComp)]
		} elseif {![SensibleValue $FileOrVal]} {
		    set paramData($restoredComp) {}
		    ShowMessage "Error merging parameters" error "Parameterization file contained the entry $FileOrVal for component $restoredComp. This entry is not the name of an existing file, nor is it a sensible value for a Simile component." ok
		}
		$widgetNames($restoredComp) delete 1.0 end
		$widgetNames($restoredComp) insert 1.0 $paramData($restoredComp)
	    } 
	}
	close $pStr

    }
    cd $oldDir
}	

# This tests for sensible model values.  
# 0: not sensible 

# 1: an integer
# 2: a float 
# 3: a list

proc SensibleValue {list} {
    if {[llength $list]==1} {
	return [VarType $list]
    } else {
	for {set idx 0} {$idx < [llength $list]} {incr idx 2} {
	    if {[VarType [lindex $list $idx]] != 1 || \
		    ![SensibleValue [lindex $list [expr $idx+1]]]} {
		return 0
	    }   
	}
	return 3
    }
}

# useful proc which returns 1 for an int, 2 for a float and 0 for all else

proc VarType {testVar} {
    if {[scan $testVar {%d %s} number spare]==1} {
	return 1
    } elseif {[scan $testVar {%f %s} number spare]==1} {
	return 2
    } else {
	return 0
    }
}

# takes two file names and returns the second relative to the first
proc Relativize {current remote} {
#	ShowMessage debug info "relativizing $current $remote" ok
	set currentList [file split $current]
	set remoteList [file split $remote]
	set parted 0
	set base {}
	for {set sameCount 0} {$sameCount < [llength $currentList]} {incr sameCount} {
		if {$parted} {
			lappend base ..
		} elseif {[string compare [lindex $currentList $sameCount] \
				[lindex $remoteList $sameCount]]} {
			set tail [lrange $remoteList $sameCount end]
			set parted 1
		}
	}
	return [eval {file join} $base $tail]
}	

proc GetFromTable {parent compName} {
    global paramState paramData widgetNames equation table_entry
    set equation(table_data) {}

    if {[equationDoTable $parent]} {

	set paramState($compName) \
		[concat [list $table_entry(fileName) $table_entry(dataField)] \
		$table_entry(indices)]
	set paramData($compName) [LoadTableData $paramState($compName)]
	$widgetNames($compName) delete 1.0 end
	$widgetNames($compName) insert 1.0 $paramData($compName)
    }
}

proc LoadTableData {tableSpec} {

# ShowMessage debug info "Loading table with data $tableSpec" ok
    set tStr [open [lindex $tableSpec 0] r]
    gets $tStr headerLine
    set headerList [split $headerLine ,]
# ShowMessage debug info "Headers are $headerList" ok
    
    set indexCount 0
    set maxIndices(0) 0
    foreach headerIndex [lrange $tableSpec 2 end] {
	lappend indexColumns [lsearch $headerList $headerIndex]
	set maxIndices($indexCount) 0
	incr indexCount
    }
    set headerColumn [lsearch $headerList [lindex $tableSpec 1]]
# ShowMessage debug info "Columns: header $headerColumn" ok

    while {[gets $tStr entryLine] != -1} {
	set entryList [split $entryLine ,]
# ShowMessage debug info "Data line is $entryList" ok

	if {[info exists indexColumns]} {
	    set arrayIndex {}
	    set indexCount 0
	    foreach column $indexColumns {
		set newIndex [lindex $entryList $column]
		lappend arrayIndex $newIndex
		if {$newIndex > $maxIndices($indexCount)} {
		    set maxIndices($indexCount) $newIndex
		}
		incr indexCount
	    }
	} else {
	    incr maxIndices(0)
	    set arrayIndex $maxIndices(0)
	    set indexCount 1
	}

	set paramArray(top,[join $arrayIndex ,]) \
		[lindex $entryList $headerColumn]
    }

    for {set idxIdx 0} {$idxIdx < $indexCount} {incr idxIdx} {
	lappend indexList $maxIndices($idxIdx)
    }
    
# ShowMessage debug info "Converting [array get paramArray] with $indexList" ok
    close $tStr
    return [ArrayToList paramArray top $indexList]
}

proc ArrayToList {topArray indexSoFar otherMaxes} {
# ShowMessage debug info "$indexSoFar $otherMaxes" ok
    upvar 1 $topArray array
    if {[llength $otherMaxes]} {
	for {set pt 1} {$pt <= [lindex $otherMaxes 0]} {incr pt} {
	    lappend result $pt [ArrayToList array $indexSoFar,$pt \
		    [lrange $otherMaxes 1 end]]
	}
	return $result
    } else {
	if {[info exists array($indexSoFar)]} {
	    return $array($indexSoFar)
	} else {
	    return 0
	}
    }
}

# this gets rid of a c program that has been loaded into
# the interpreter, to allow a new one to replace it --
# loadmodel with no args unloads model (this crashes Windows)

proc remove_c_model {} {
# The following is not done cos it removes the stub as well
#    package forget ame_dll
#
#    foreach c_command {c_resetmodel c_evalmodel c_updatemodel c_exitmodel \
#	    getvalue getnodeid listobjects} {
#	rename $c_command {}
#    }
}

proc CheckExec {Lang Dir} {
    if {[string match tcl $Lang]} {
	set Extn .tcl
    } else {
	set Extn [info sharedlibextension]
    }
    if {[file exists $Dir/model$Extn]} {
	return yes
    }
}

# Path names derived from Windows environment variables must be
# 'brainwashed' i.e., stripped of their native culture and turned
# into blank-faced Unix-style forward-slash-separated automata.
# Otherwise mingw gcc variably gets culture shock. 

proc brainwash {ethnic} {
	return [file join [file dirname $ethnic] [file tail $ethnic]]
}

# TopDirFor gets the name of the directory in which to stick extra
# information generated by simile in relation to a model. This used to
# be just the model name without its extension, but I found this
# looked confusing when opening models, so now this directory is a
# subdirectory of 'sim_bits' in the model directory.

# will be obsolete when mime saves are finished

proc TopDirFor {model} {
    set nDir [file dirname $model]/sim_bits/[file rootname [file tail $model]]
    file mkdir $nDir
    return $nDir
}

proc AttachTree {Load Top Point} {
    set meat [TopDirFor $Load]
    if {[file exists $meat]} {
	file mkdir $Top/$Point
	foreach file [glob -nocomplain $meat/*] {
	    file copy $file $Top/$Point
	}
    }
}

proc TrimTree {Top Point} {
    if {[llength $Point]} {
	foreach file [glob -nocomplain $Top/$Point/*] {
	    file delete -force $file
	}
    } else {
	file delete -force [file rootname $Top]
    }
}

proc ShiftDll {Point Top Loc Rep} {
    if {[llength $Loc]} {
	set AddLoc /$Loc
    } else {
	set AddLoc $Loc
    }
    
    set base $Top/$Point$AddLoc
    file mkdir $base
    if {!$Rep} {
	file delete -force ${base}/model.dll
	file delete -force ${base}/model.so
    }
}

proc build_tcl_program {winId} {
    global model_id
#   model_id set to 0 cos its existence is tested when getting model structure

    set model_id 0
    start_run 0 $winId
    RunDialog "Current model"
}

proc update_c_executable {winId} {
#    ShowMessage debug info "References are $finderList" ok
    global model_id instance_id

# For the toplevel model, make an instance. This will also make
# instances of any fixed-membership submodels immediately, so they had
# better already be loaded

    set instance_id [c_createmodel $model_id]
#    ShowMessage debug info "model instance $instance_id created" ok

    start_run 1 $winId
    RunDialog "Current model"
}

# load_dll adds a dll to the system. Trees are added bottom up, so model_id
# is always that most recently added (even if not recompiled)

proc load_dll {lang progFileDir modelPath node} {
#   phasecount and nodedata are set in generated code
    global phasecount nodedata nodecount model_id model_ids
    set nameBase $progFileDir$modelPath/model
    if {[string match tcl $lang]} {
	foreach fnFile [glob -nocomplain ../Functions/*.tcl] {
	    source $fnFile
	}
	source $nameBase.$lang
	if {[info exists simile_version]} {



	    return $simile_version
	} else {
	    return 0
	}
    } else {
	if {[catch {loadmodel $nameBase[info sharedlibextension] $node} \
		model_id]} {
	    ShowMessage {Loading model dll} info "Failed to load the compiled model program. The operating system returned the following message: $model_id -- the program will attempt to build another one." ok
	    unset model_id
	    return 0
	}
#        set model_id [loadmodel $nameBase[info sharedlibextension] $node]
        set model_ids($node) $model_id
        return $model_id
    }
}

proc set_connections {connects} {
    global model_id model_ids instance_id
# ShowMessage debug info "Trimming..." ok
    if {[info exists instance_id]} {
	c_exitmodel $model_id $instance_id
	unset instance_id
	unset model_ids
    }
#ShowMessage debug info "About to load: $connects" ok
    set_connection_database $connects
#ShowMessage debug info "...loaded." ok
#   now...dont set running_c till instance made -- use model_id till then
#    set running_c 1
}

# FindPhase tells us when a node in a separate submodel will be
# available. The submodel indicates this by its eval phase. If DERIVED, INPUT
# or TABLE it can be used any time; if EXOGENOUS we must wait till that
# submodel has been called. If it is in a nested submodel, then it is
# usable after the phase in which the submodel is executed, or after
# its own phase if that is SPLIT. -1 means node not found.

# Note that because the top level model dll may not yet be loaded, we have
# to set model_id to the model we are searching in (model_ids keeps track of
# dlls loaded so far)

proc FindPhase {node submodel} {
    global model_id model_ids

    set model_id $model_ids($submodel)
    foreach subnode [listobjects $model_id] {
	set subtype [GetModelEval $subnode]
	if {[string match $node $subnode]} {
	    if {[string match EXOGENOUS $subtype]} {
		return 1
	    } else {
		return 0
	    }
	}
	if {[string match EXTERNAL [GetModelType $subnode]]} {
	    lappend subs [list $subnode $subtype]
	}
    }
    foreach nodeTypePair $subs {
	set subFind [FindPhase $node [lindex $subs 0]]

	if {$subFind != -1} {
	    switch [lindex $subs 1] {
		EXOGENOUS {
		    return 1
		} DERIVED {
		    return 0
		} SPLIT {
		    return $subFind
		}
	    }
	}
    }
    return -1
}

proc compile_c {workingDir modelPath} {
    global tcl_platform env
        
    set oldDir [pwd]
    cd $workingDir$modelPath
    ShowMessage {Code editing opportunity} info \
	"About to compile model.cpp in [pwd]" ok
    set TARGET model[info sharedlibextension]

    set TOOLDIR $oldDir/../Run
    set TCL [file dirname [file dirname [info library]]]
#ShowMessage debug info "TCL is $TCL, TOOLDIR is $TOOLDIR" ok
    scan [info tclversion] {%d.%d} MAJ MIN
    switch $tcl_platform(platform) {
	unix {
	    exec g++ -fPIC -c -O -I$TOOLDIR -I$TCL/include -o objtemp.o model.cpp
	    exec g++ -shared -o $TARGET objtemp.o
	    file delete model.cpp
	    file delete objtemp.o
	}
	windows {
	    set TOOLDIR [file attributes $TOOLDIR -shortname]
	    if {[string match GNU [PrefValue custom(compChoice) compChoice]]} {
		set dll ame_dll${MAJ}${MIN}
	        exec g++ -c -o objtemp.o -I$TOOLDIR -I. model.cpp
		exec dllwrap --dllname=$TARGET --def=$TOOLDIR/model.def --driver-name=g++ objtemp.o
		file delete exptemp.exp
		
# Method using command line calls to MSVC 4.0 or later -- works well
	    } else {
		set TOOLS32 [file dirname $env(MSVCDIR)/any]
		exec $TOOLS32/bin/cl.exe -Ox -c -W3 -nologo \
			-DWIN32 -D_WIN32 -D_DLL -D_X86_=1 \
			-I. -I$TOOLS32/include -I$TCL/include \
			-Foobjtemp.o model.cpp
		exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO \
			-align:0x1000 /MACHINE:IX86 \
			-entry:_DllMainCRTStartup@12 -dll -out:$TARGET \
			ame_dll${MAJ}${MIN}.lib \
			$TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib \
			$TOOLS32/lib/oldnames.lib objtemp.o
	    }
# Method using command line calls to Borland C++ 4.0 or later -- not finished

#	set TOOLS32 "c:/program files/borland/cbuilder4"
#	exec $TOOLS32/bin/bcc32.exe -Ox -c -nologo -o$object \
#		-DWIN32 -D_WIN32 -D_DLL -D_X86_=1 -DMODELCODE="$c_prog" \
#		-I. -I$TOOLS32/include -I$TCL/include $TOOLDIR/support.cpp



#	exec $TOOLS32/bin/ilink32.exe -Tpd $object $TARGET $TCL/lib/tcl${MAJ}${MIN}.lib
# Method using MSVC's auto-generated Make file -- hangs for some
# reason

#	exec $TOOLS32/bin/nmake $TOOLDIR/amemodel/amemodel.mak
#	file rename $TOOLDIR/amemodel/debug/amemodel.dll $TARGET

	}   
    }
#    file delete $c_prog
    file delete objtemp.o

# do not allow an old dcf to be saved with a new model
    cd $oldDir
}

# This makes the extra bit that goes onto Tcl to run C programs. We don't
# really need to build it every time we run the program, that's just while
# it's being debugged, once it's right we'll just load it. This component
# itself loads dlls for the actual models as they are built.

proc build_c_stub {targetDir make_new_stub} {
    global tcl_platform env

    scan [info tclversion] {%d.%d} MAJ MIN
    set onUnix [string match unix $tcl_platform(platform)]
    set stubPkg ${MAJ}.${MIN}.$env(SIMILE_VERSION).$onUnix
    if {!$make_new_stub} {
#	Next line allows start on new o/s without rebuild but slows
#	pkg_mkIndex $targetDir *.dll *.so
	if {![catch {package require -exact Ame_dll $stubPkg} dummy]} {
	    return
	} else {
#	    ShowMessage {Loading dll} info "Loading stub dll caused a $dummy -- program will now attempt to build a new one" ok
	}
    }

    set old_dir [pwd]
    cd $targetDir
#    set TCL [file dirname [file dirname [info library]]]
#	To build for Tcl dll included under distribution directory...
    set TCL ../System

    if $onUnix {
# You may be asking yourself why I need to explicitly specify a location for
# the Tcl library files, since they should be in LD_LIBRARY_PATH. It is because
# some people find it easier to build the stub from exec_only.tcl, which gives
# them error messages to the console but does not set LD_LIBRARY_PATH.
	set TARGET $targetDir/libame_dll$MAJ.$MIN.so
	exec g++ -c -O -fPIC -I$targetDir -I$TCL/include ./ame_cmx.cpp
	exec g++ -shared -o $TARGET ame_cmx.o -L$TCL/lib -ltcl$MAJ.$MIN
    } else {
	set TCL [file attributes $TCL -shortname]
	set TARGET [file attributes $targetDir -shortname]/ame_dll$MAJ$MIN.dll
	set dll tcl${MAJ}${MIN}

# Older TclTks may have a special library for Visual C, which is also used by mingw
	set tclLib $TCL/lib/${dll}vc.lib
	if {![file exists $tclLib]} {
	    set tclLib $TCL/lib/$dll.lib
	}

# Method using MingW32 gcc: Dlls refuse to load into tcl when
# it is running under Prolog. However it seems to work OK in WinNT.
	if {$make_new_stub != 1} {
	    exec g++ -c -o obj.o -I. -I$TCL/include ./ame_cmx.cpp
	    exec dllwrap --dllname=$TARGET --def=stub.def --driver-name=g++ obj.o $tclLib

# Method using command line calls to MSVC 4.0 or later -- works well
	} else {
	    set TOOLS32 [file dirname $env(MSVCDIR)/any]
	    exec $TOOLS32/bin/cl.exe -Ox -c -W3 -nologo -DWIN32 -D_WIN32 -D_DLL -D_X86_=1 -I$targetDir -I$TOOLS32/include -I$TCL/include ./ame_cmx.cpp
	    exec $TOOLS32/bin/link.exe /RELEASE /NODEFAULTLIB /NOLOGO -align:0x1000 /MACHINE:IX86 -entry:_DllMainCRTStartup@12 -dll -out:$TARGET $tclLib $TOOLS32/lib/msvcrt.lib $TOOLS32/lib/kernel32.lib $TOOLS32/lib/oldnames.lib ./ame_cmx.obj
	}

# Also if in Windows we need to prepare a way for gcc to link the
# tcl dll into the model program. The MSVC compiler is used to
# build the stub (for now) because it makes life easier, but users
# should not have to buy it...
#	    exec impdef /windows/system/tcl80.dll >tcl80.def
#	    exec dlltool --dllname tcl80.dll --def tcltk.def \
#		--output-lib libtcl80.a
# and likewise to link the model dll into the stub...
#	    exec dlltool --dllname ame_dll.dll --def ame_dll.def \
#		--output-lib libame_dll.a
    }
    pkg_mkIndex $targetDir *.dll *.so
    package require -exact Ame_dll $stubPkg
    cd $old_dir
}

proc ListSameNumbers {list1 list2} {
	set target [llength $list1]
	if {$target != [llength $list2]} {return 0}
	for {set count 0} {$count < $target} {incr count} {
		if {[lindex $list1 $count] != [lindex $list2 $count]} {return 0}
	}
	return 1
}

# procedures to handle graph data

proc insert_graph_data {graph_data_pointer xlow xhigh xspan ylow yhigh yspan \
	xsize array_data} {
   variable graphdata
   set $graph_data_pointer [format "%f %f %d %f %f %d %d %s" \
	$xlow $xhigh $xspan $ylow $yhigh $yspan $xsize $array_data]
}

proc setup_graph_data {graph_data_pointer xlow xhigh xspan ylow yhigh yspan \
	xsize args} {
   insert_graph_data $graph_data_pointer $xlow $xhigh $xspan $ylow $yhigh $yspan \
	 $xsize $args
}

proc release_graph_data {graph_data_pointer} {
# no need to release in tcl
}

# this procedure takes the data describing a function entered as a graph, and a
# point on the x axis, and returns the y axis point. It is called from the
# procedure that executes the model.


proc graphpoint {xval graph_data_pointer} {
    variable graphdata

	scan [set $graph_data_pointer] {%f %f %d %f %f %d %d %d %[^.]} \
	    xlow xhigh xspan ylow yhigh yspan range xsize array_data
	set length [expr $xsize - 1]

	set interval [expr $length*double($xval-$xlow)/($xhigh-$xlow)]

	switch $range {
		0 {
			if {$interval < 0} {set interval 0}
			if {$interval > $length} {set interval $length}
		} 2 {
			set interval [expr $length*($interval/$length - floor($interval/$length))]
		}
	}
	set left [expr int($interval)]
	if {$left < 0} {set left 0}
	if {$left >= $length} {set left [expr $length - 1]}
	set right [expr $left + 1]
	set height [expr ($right - $interval)*[lindex $array_data $left] + \
		($interval - $left)*[lindex $array_data $right]]
	return [expr $ylow + ($yhigh - $ylow)*$height/$yspan]
}

proc getinstance {varName dest newvalue} {
# If newvalue exists, it should be copied to target and returned
	upvar 1 $varName target
	upvar 1 $dest returnList

        if {[string compare $newvalue NULL]} {
            set target $newvalue

        } ;# end(if,$set)
        lappend returnList $target
    return $returnList
} ;# end(procedure,getinstance)

proc min {first last} {
    return [expr $first<$last?$first:$last]
}

proc max {first last} {
    return [expr $first>$last?$first:$last]
}

proc do_setstepmodel {value level} {
    global dts
    set dts($level) $value
}

# delete_list is a dummy procedure. What it should do is clear the
# submodel instances from the list supplied, but since (a) it would also
# need the parent namespace and (b) they tend to get reused anyway in
# tcl, I have not bothered.  

proc delete_list {list_id} { 
}

proc glob_element {arrptr phase} {
    upvar #0 $arrptr arr
    return $arr($phase)
}

# When there are multiple models, prune will be called with some reference
# to the source namespace. For now we add that inside the proc...

proc prune {target metaTxt idCount} {
    upvar 1 $metaTxt meta
    set context ::AME_model<>
    set status 1
    while {[string compare [set ${context}::$meta] 0] && \
	    [set status [compare_instance_status \
	    [set submodelptr ${context}::[set ${context}::$meta]]::instanceid \
	    $target $idCount]]==-1} {
	set ${context}::$meta [set ${submodelptr}::next]
	namespace delete $submodelptr
    }
    return [expr !$status]
}

proc compare_instance_status {testInstName refInst num} {
    upvar 1 $testInstName testInst
    #    ShowMessage debug info "testInst $testInst refInst $refInst" ok
    if {[string match 0 $testInst]} {return 1}
    for {set ptr 0} {$ptr < $num} {incr ptr} {
	if {[lindex $testInst $ptr]<[lindex $refInst $ptr]} {return -1}
	if {[lindex $testInst $ptr]>[lindex $refInst $ptr]} {return 1}
    }
    return 0
}

proc compare_values {v1 indexTxt v2 length step} {
# ShowMessage debug info "compare_values\n$v1\n$indexTxt\n$v2\n$length\n$step" ok
    upvar 1 $indexTxt index
    compare_lists 1 $v1 index $v2 $length $step
}
	
proc compare_lists {count nestlist1 indexTxt list2 length step} {
    upvar 1 $indexTxt index

    set hunting 2

    while {$hunting==2} {
	if {$index >= $length} {
	    set hunting 0
	} else {
	    set list1 [lindex $nestlist1 $index]
	    set hunting [compare_tcl_lists $count $list1 $list2]
	    if {$hunting == 2} {
		incr index $step
	    }
	}
    }
    return $hunting
}

proc compare_tcl_lists {count list1 list2} {

	for {set ptr 0} {$ptr < $count} {incr ptr} {
		set diff [expr [lindex $list1 $ptr]-[lindex $list2 $ptr]]
		if {$diff < 0} {
			return 2 ; Dead parent condition
		}
		if {$diff > 0} {
			return 0 ; Non-existence condition
		}
	}
	return 1
}
proc init_pop_member {new_one index parent channel} {
    upvar 1 $new_one tail
    set tgt AME_model<>::$tail
    set ${tgt}::instanceid $index
    set ${tgt}::parentId $parent
    set ${tgt}::channelId $channel
    set ${tgt}::new_instance 1
    set ${tgt}::next 0
}

proc ame_rand {lowBound highBound} {
	return [expr $lowBound +[random01]*($highBound - $lowBound)]
}

proc SampleFrom {a} {
   if {[llength $a] == 1} {
	return $a
   } else {
	array set fun $a
	foreach index [array names fun] {
	   set b [SampleFrom $fun($index)]
	   if {$b} {
		return $b
	   }
	}
	return 0
   }
}

proc IsArray {a} {
	string compare $a [lindex $a 0]
}

# utility procedure to fill in some holes in Tcl8.0


proc ChooseText {choice ifTrue ifFalse} {
	if {$choice} {
		return $ifTrue
	} else {
		return $ifFalse
	}
}

set intCount 0

proc newInt {} {
	global intCount
	return [incr intCount]
}

# Ultra crappy random alg now replaced by c library version

#set randfoob [expr exp(-1)]
#proc random01 {} {
#	global randfoob
#	return [set randfoob [expr fmod(1/$randfoob,1)]]
#}

proc FilterErrors {args} {
    global errorInfo
    set oldDir [pwd]
    if {[catch $args retVal]} {
	set ans [ShowMessage "Simile error" error "Simile encountered an unexpected problem:\n $retVal \nDo you want to see more information?" yesno]
	if {[string match yes $ans]} {
	    ErrorHelp $errorInfo
	}
	cd $oldDir
	return -1
    } else {
	return $retVal
    }

}

build_c_stub "[pwd]/../Run" 0

