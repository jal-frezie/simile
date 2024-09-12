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

	package require tablelist
	switch -glob $winTitle {
	    "file parameter" {
#	        check if relocating param or measurement data
		set typesToShow {INPUT TABLE BLOCK POPULATION GRID HONEYCOMB}
	    } submodel {
		set typesToShow {BLOCK GRID HONEYCOMB}
#		set showTopLevel 1
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
		     -columns {0 "Component" 0 "Helper icons"} -stretch all \
		     -yscrollcommand "$tableframe.bar set"]
        pack $tbl -fill both -expand true
#        $tableframe setwidget [::ttk::treeview $tbl]
        pack $tableframe -expand true -fill both

	set context [GetState $winId] ;# caption path of submodel to go at top
	set chop [string length $context]
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
		set new [$tbl insertchild $parent end [list [BlankCrs [lindex $path end]]]]
		$tbl rowconfig $new -name $component
		$tbl cellconfig $new,0 -image $image
	    }
	}
	bind [$tbl bodytag] <Button-1> [::itcl::code ProdIfComp %W %x %y]
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
    }

    public method HelperLeaf {node hlpr add} {
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
	} else {
	    $tbl cellconfigure $node,1 -image {}
	}
    }
    
    proc ProdIfComp {w x y} {
	foreach {tbl x y} [tablelist::convEventFields $w $x $y] {}
	set row [$tbl containing $y]
	ProdFromHelper [winfo parent [winfo parent $tbl]] \
	    [$tbl rowcget $row -name] [lindex [$tbl rowcget $row -text] 0]
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
