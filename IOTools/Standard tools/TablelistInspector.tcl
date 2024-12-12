# Version of model explorer using Csaba Nemethi's Tablelist megawidget
# to allow editing and images in multiple columns without widget count
# overload

set newHelperClass TablelistInspector20240911
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "Explorer (Tablelist version)"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	global iconImages

	package require tablelist 5-
	switch -glob $winTitle {
	    "file parameter" {
#	        check if relocating param or measurement data
		set typesToShow {INPUT TABLE BLOCK POPULATION GRID HONEYCOMB}
	    } submodel {
		set typesToShow {BLOCK GRID HONEYCOMB TABLE}
		set showTopLevel 1
#		$tableframe.table insert {} end -id $::myNode -open 1 \
#		    -text "TOP LEVEL" -image $iconImages(new)
		# probably no need to nest others in here, just put at top
	    } "model output" {
		set typesToShow {RECALL DERIVED BLOCK POPULATION GRID HONEYCOMB}
	    } parameters {
		set paramEdits 1
		set typesToShow {INPUT TABLE}
	    } explorer {
		set paramEdits 1
		set incExpts 1
		set typesToShow {INPUT TABLE}
	    } default {
		# outputs, or user added instance: show all
		set doPops [PrefValue custom(compValPop) compValPop]
		set typesToShow {RECALL DERIVED INPUT TABLE LIMIT \
				     BLOCK POPULATION GRID HONEYCOMB}
	    }
	}

	set tableframe $winId.inspFrame
	frame $tableframe
	scrollbar $tableframe.bar -command "$tableframe.table yview"
	pack $tableframe.bar -side right -fill y
	set tbl [tablelist::tablelist $tableframe.table \
		     -columns {0 C left 0 H right} -showlabels 0 \
		     -stretch all -yscrollcommand "$tableframe.bar set"]
	$tbl columnconfig 0 -maxwidth 32
        pack $tbl -fill both -expand 1
        pack $tableframe -fill both -expand 1
	if {[info exists showTopLevel]} {
	    set new [$tbl insertchild root end [list "TOP LEVEL"]]
	    $tbl rowconfig $new -name [GetNode]
	    $tbl cellconfig $new,0 -image $iconImages(new)
	}
	set context [GetState $winId] ;# caption path of submodel to go at top
	set chop [string length $context]
	set universe {}
        foreach component [GetObjectList] {
	    set fullCapt [GetCaptionPathFromId $component]
	    if {(![string length $state] || \
		    ![string first $state $fullCapt]) && \
		    [lsearch $typesToShow [GetModelEval $component]]>=0} {
		lappend universe [list $component [string range $fullCapt \
						       $chop end]]
	    }
	}
	set sorted [lsort -dictionary -index 1 $universe]
	foreach makeTree {1 0} {
	    if {!$makeTree && $winTitle eq "submodel"} break
	    foreach pair $sorted {
		set component [lindex $pair 0]
		set type [GetModelClass $component]; # Simile 2.7+
		if {($type eq "SUBMODEL") != $makeTree || $type eq "INTERNAL"} \
		    continue
		set image $iconImages([string tolower $type])
		if {$type eq "VARIABLE"} {
		    switch [GetModelEval $component] {
			INPUT {set image $iconImages(input)}
			TABLE {set image $iconImages(file)}
		    }
		}

		set path [PreparePath $context [lindex $pair 1]]
		set pathLength [llength $path]
		if {$pathLength == 1} {
		    set parent root
		} else  {
		    set parentLabel [lrange $path 0 [expr {$pathLength-2}]]; # indexed from 0
		    set parent $submodel($parentLabel)
		}
		set submodel($path) $component
		set bkgnd $parent
		if {$makeTree} {
		    set bkgnd $component
		}
		set fColour [GetFromProlog tk_get_info($bkgnd,colour)]
		if {$fColour eq "clear"} {set fColour {}}
		set capt [BlankCrs [lindex $path end]]
		set new [$tbl insertchild $parent end [list $capt]]
		$tbl rowconfig $new -name $component -bg $fColour
		$tbl cellconfig $new,0 -image $image
	    }
	}
	bind [$tbl bodytag] <Button-1> [::itcl::code ProdIfComp %W %x %y]
	bind [$tbl bodytag] <Motion> [::itcl::code MoveInInsp %W %X %Y %x %y]
	bind [$tbl bodytag] <Leave> RemovePopup
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
    }

    public method HelperLeaf {node hlpr add} {
	variable curHelpers
    
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
	set tbl $winId.inspFrame.table
	if {$add} {
	    $tbl cellconfigure $node,1 -image $::iconImages($img)
	    set curHelpers($node) $hlpr
	} else {
	    $tbl cellconfigure $node,1 -image {}
	    unset curHelpers($node)
	}
    }
    
    proc ProdIfComp {w x y} {
	variable curHelpers
    
	foreach {tbl x y} [tablelist::convEventFields $w $x $y] {}
	set pair [$tbl containingcell $x $y]
	foreach {row col} [split $pair ,] {}
	if {$row<0} return
	set node [$tbl rowcget $row -name]
	if {$col==1 && [info exists curHelpers($node)]} {
	    ::RunEnv::FocusTool $curHelpers($node)
	} else {
	    ProdFromHelper [winfo parent [winfo parent $tbl]] \
		[$tbl rowcget $row -name] [GetCaptionPathFromId $node]
	}
    }
    
    proc DoInspPopup {winId X Y x y} {
	global helperTable runState myNode

	set plName $helperTable($winId,whatPopped)
	if {![llength $plName]} {
	    return
	}
	if {$runState($myNode,modelRunning)>1} {
	    PostPopup $winId $X $Y
#	    set trans [GetTransTable $plName]
#	    if {[catch {GetModelValue $plName} mVal]} {
##		set missing [lindex [split $mVal \"] 1]
##		set value \
##		    "Missing value: [lindex [DescribeComponent $missing] 0]"
#		set value no_value
#	    } else {
#		set value [lindex $mVal 0]
#		#puts "trans $trans value $value"
#	    }
	    AddPopupMessage novalue \#ffffc0 GetShortVals $myNode $plName
	}
    }
    
    proc MoveInInsp {w X Y x y} {
	global helperTable
	variable curHelpers
	
	foreach {tbl x y} [tablelist::convEventFields $w $x $y] {}
	set pair [$tbl containingcell $x $y]
	foreach {row col} [split $pair ,] {}
	if {$row<0} {
	    RemovePopup
	    return
	}

	set plName [$tbl rowcget $row -name]
	if {$col==1 && [info exists curHelpers($plName)]} {
	    set toShow [[$curHelpers($plName) info class]::Identify]
	    RemovePopup
	    eval QueuePopup AddWidgetPopup $tbl $X $Y [list $toShow]
	    return
	}
	if {[info exists helperTable($tbl,whatPopped)]} {
	    if {[string equal $plName $helperTable($tbl,whatPopped)]} {
		return; #; it's already queueued
	    }
	}
	set helperTable($tbl,whatPopped) $plName
	    # changed row; renew popup
	RemovePopup
	eval QueuePopup [namespace code DoInspPopup] $tbl $X $Y $x $y
    }

    proc PreparePath {context SubbedComp} {
	# substitute " " for <cr>s so entry goes on one line # no - need the crs
	set SubbedCompList [split $SubbedComp /]
	if {[string length $context]} {
	    set path [concat $context [lrange $SubbedCompList 1 end]]
	} else {
	    set path [lrange $SubbedCompList 1 end]
	}
    }
}
