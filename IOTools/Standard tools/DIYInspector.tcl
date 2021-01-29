# Version of model explorer using subframes for greater flexibility and
# functionality

set newHelperClass DIYInspector20210125
itcl::class similescript::$newHelperClass {
    inherit Helper

    variable topFrame

    proc Identify {} {
	return "Explorer (DIY version)"
    }
    
    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	variable chop

	set chop [string length $state]
	set doPops 0
	switch -glob $winId { ;# check if relocating param or measurement data
	    .newfile* {
		set typesToShow {INPUT TABLE BLOCK POPULATION GRID HONEYCOMB}
	    } .newsub* {
		set typesToShow {BLOCK GRID HONEYCOMB}
		set showTopLevel 1
		$tableframe.table insert {} end -id $::myNode -open 1 \
		    -text "TOP LEVEL" -image $iconImages(new)
		# probably no need to nest others in here, just put at top
	    } .newout* {
		set typesToShow {RECALL DERIVED BLOCK POPULATION GRID HONEYCOMB}
	    } default {
		set doPops [PrefValue custom(compValPop) compValPop]
		set typesToShow {RECALL DERIVED INPUT TABLE LIMIT \
				     BLOCK POPULATION GRID HONEYCOMB}
	    }
	}
	set topFrame [DIYMakeFrames $winId]
        foreach component [GetObjectList] {
	    set fullCapt [GetCaptionPathFromId $component]
	    if {(![string length $state] || \
		    ![string first $state $fullCapt]) && \
		    [lsearch $typesToShow [GetModelEval $component]]>=0} {

		# AddEntry $winId $::myNode $component / 1 1
		set levels [split $fullCapt /]
		set capt [lindex $levels end]
		set type [GetModelClass $component]
		if {$type eq "SUBMODEL"} {
		    lappend levels {}
		} elseif {$type eq "VARIABLE"} {
		    switch [GetModelEval $component] {
			INPUT {set type input}
			TABLE {set type file}
		    }
		}
		set f [MakeSubFrames insp $topFrame $levels \
			   [namespace current] 0]
		bind $f <Button-1> [list ProdFromHelper $winId $component \
					[string range $fullCapt $chop end]]
		if {$type eq "SUBMODEL"} {
		    set label $f.head.label
		    $label configure -image $::iconImages(submodel) \
			-compound left
		    pack $label -side left
		} else {
		    set beeGee [[winfo parent $f].head cget -bg]
		    set bStyle [[winfo parent $f].head.vis cget -style]
		    $f configure -bg $beeGee
		    pack [ttk::label $f.label -text $capt -style $bStyle \
			      -image $::iconImages([string tolower $type]) \
			      -compound left] -side left
		    bindtags $f.label [linsert [bindtags $f.label] 0 $f]
		    if {$doPops} {
			LabelPopup $f.label $component $capt
		    }		    
		}
	    }
	}
    }
    destructor {
    }
    
    proc LabelPopup {widget node capt} {
	bind $widget <Enter> [::itcl::code AddPopup %W %X %Y $::myNode $node]
	bind $widget <Leave> RemovePopup
    }

    proc AddPopup {wid X Y node capt} {
	PostPopup $wid $X $Y
	AddPopupMessage novalue \#ffffc0 GetShortVals $node $capt
    }
    
    public method Click {path} {
	global myNode
	variable curFrame
	variable clickPath

	set node [IdFromTail $myNode $path -1]
	set caseName [GetCaseName $path]
	if {$caseName ne {}} {
	    set notInput [expr {[GetModelEval $node] ne "INPUT"}]
	    AddEntry $winId $myNode [IdFromTail $myNode $path -1] \
		$clickPath 0 $notInput $caseName
	    destroy $winId.label
	}
	$modelInst ReleaseClicks
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
    }

    public method AddHelperLeaf {node hlpr} {
	set id [[$hlpr info class]::Identify]
	array set hlprIcons {Plotter graph \
				 "XY Plotter" plotxy \
				 "Polygon diagram" polys \
				 "Data table" table \
				 "Data logger" table \
				 "Spatial grid display" grid \
				 "Lollipop diagram" 3d_objects \
				 "Slider control" slider \
				 "Multi-layer 2-D display" multi \
				 "3-D Shape Plotter" 3d_objects}
	if {[catch {set img $hlprIcons($id)}]} {
	    set img display
	}

	set fullCapt [GetCaptionPathFromId $node]
	set levels [split $fullCapt /]
	set f [MakeSubFrames insp $topFrame $levels [namespace current] 0]
	set neWidg [UniqueId hlpr]
	set bStyle [[winfo parent $f].head.vis cget -style]
	pack [ttk::button $f.$neWidg -style $bStyle -image $::iconImages($img) \
		  -command [list ::RunEnv::FocusTool $hlpr]] \
	    -side right -padx 1p
	BindPopup $f.$neWidg $id
    }
}
