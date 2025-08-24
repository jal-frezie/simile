# ModelInspector.tcl

# Based on SaveState.tcl
# Added Treeview of sub-models and table view of variables  Jonathan Massheder 22/4/01

# SaveState.tcl Jasper Taylor, 28/5/99
# AME Helper app to record or retrieve the state of a model. This is
# to be used both as a general modelling tool, and in conjunction with
# the GCLMI interface or other interface requiring creation and
# initialization of multiple instances of the model.

set keyValue TileInspector0

namespace eval ::$keyValue {
    proc identify {} {
        return "Explorer (Tile version)"
    }
    
    proc display {args} {
    }
    
    proc clear {winId} {
    }
    
    proc initialize {winId} {
        global tcl_platform iconImages
	variable chop
        
        set tableframe $winId.tableframe
#        ScrolledWindow $tableframe -scrollbar vertical
	frame $tableframe
#        Tree $tableframe.table -showlines yes
	scrollbar $tableframe.bar -command "$tableframe.table yview"
	pack $tableframe.bar -side right -fill y
	::ttk::treeview $tableframe.table -show tree \
	    -yscrollcommand "$tableframe.bar set"
        pack $tableframe.table -fill both -expand true
#        $tableframe setwidget [::ttk::treeview $tableframe.table]
        pack $tableframe -expand true -fill both
        $tableframe.table column \#0 -width 270
        
#        tk_messageBox -message [GetObjectList] -type ok
        #get submodel nodeIds for parents
	set universe {}
	set context [GetState $winId] ;# caption path of submodel to go at top
	set chop [string length $context]
	set doPops 0
	switch -glob $winId { ;# check if relocating param or measurement data
	    .newfile* {
		set typesToShow {INPUT TABLE BLOCK POPULATION GRID HONEYCOMB}
	    } .newsub* {
		set typesToShow {BLOCK POPULATION GRID HONEYCOMB}
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
        foreach component [GetObjectList] {
	    set fullCapt [GetCaptionPathFromId $component]
	    if {(![string length $context] || \
		    ![string first $context $fullCapt]) && \
		    [lsearch $typesToShow [GetModelEval $component]]>=0} {
		lappend universe [list $component [string range $fullCapt \
						      $chop end]]
	    }
	}
	set sorted [lsort -dictionary -index 1 $universe]
	set fColour [GetFromProlog tk_get_info($::myNode,colour)]
	set tColour $::looks($::myNode,submodel,text)
	$tableframe.table tag configure bg_$fColour \
	    -background $fColour -foreground $tColour
	$tableframe.table tag add bg_$fColour {{}}
	foreach pair $sorted {
	    set component [lindex $pair 0]
            if {[llength [info commands GetModelClass]] >0} {
                set type [GetModelClass $component]; # Simile 2.7+
            } else  {
                set type [GetModelType $component]; # Simile < 2.7 - not very good
            }
            if {[string match SUBMODEL $type]} then {
		set path [PreparePath $context [lindex $pair 1]]
                set pathLength [llength $path]
                if {$pathLength == 1} {
                    set parent {}
                } else  {
                    set parentLabel [lrange $path 0 [expr {$pathLength-2}]]; # indexed from 0
                    set parent $submodel($parentLabel)
                }
                set submodel($path) $component
		set fColour [GetFromProlog tk_get_info($component,colour)]
		set tColour $::looks($::myNode,submodel,text)
		if {$fColour eq "clear"} {set fColour {}}
		$tableframe.table tag configure bg_$fColour -background $fColour -foreground $tColour
                $tableframe.table insert $parent end -id $component \
		    -text [BlankCrs [lindex $path end]] -open 1 \
		    -image $iconImages(submodel) -tag bg_$fColour
            }
        }
	foreach pair $sorted {
	    set component [lindex $pair 0]
	    set path [PreparePath $context [lindex $pair 1]]
            #        ShowMess debug info "GetModelValue $component = [GetModelValue $component]" ok
            if {[llength [info commands GetModelClass]] >0} {
                set type [GetModelClass $component]; # Simile 2.7+
            } else  {
                set type [GetModelType $component]; # Simile < 2.7 - not very good
            }
            switch $type {
                INTERNAL { continue ;# don't show internal variables
		}
                SUBMODEL     {set image $iconImages(submodel) }
                VARIABLE     {set image $iconImages(variable) }
                COMPARTMENT  {set image $iconImages(compartment) }
                FLOW         {set image $iconImages(flow)}
                CONDITION    {set image $iconImages(condition)}
                CREATION     {set image $iconImages(creation)}
                REPRODUCTION {set image $iconImages(reproduction)}
                IMMIGRATION  {set image $iconImages(immigration)}
                LOSS         {set image $iconImages(loss)}
                ALARM        {set image $iconImages(alarm)}
                EVENT        {set image $iconImages(event)}
                STATE        {set image $iconImages(state)}
                SQUIRT       {set image $iconImages(squirt)}
                default      {set image $iconImages(variable)}
            }
            if {$type eq "VARIABLE"} {
		switch [GetModelEval $component] {
		    INPUT {set image $iconImages(input)}
		    TABLE {set image $iconImages(file)}
		}
	    }
            set pathLength [llength $path]
            #ShowMess debug info "$component; $type; path $path;" ok
            if {$pathLength <= 1} {
                set parent {}
            } else  {
                set parentLabel [lrange $path 0 [expr {$pathLength-2}]]; # indexed from 0
                set parent $submodel($parentLabel)
            }
            #        ShowMess debug info "$component; $parent; path $path" ok
            if {![$tableframe.table exists $component]} {
                # search parent for node with same text
                set text [BlankCrs [lindex $path end]]
                set sameText 0
                foreach node [$tableframe.table children $parent] {
                    #ShowMess debug info "$node" ok ; # Simile node IDs
                    if {[string match [$tableframe.table item $node -text] $text]} {
                        set sameText 1
                    }
                }
                if {!$sameText} {
		    set ptags [$tableframe.table item $parent -tags]
                    $tableframe.table insert $parent end -id $component \
			-text $text -image $image -tag $ptags
                }
            }
        }
        
#	OpenLevel 0; # open up level 0 only (so can see level 1)
#        
	bind $tableframe.table <Button-1> \
	    [namespace code "OnElementClick $winId %x %y"]
	CrossPlatformBind $tableframe.table \
	    [namespace code "OnElementContext $winId %X %Y %x %y"]
#	$tableframe.table bindImage <Button-1> \
#	    [namespace code "OnElementClick $winId"]
#        $tableframe.table bindText <Button-1> \
#	    [namespace code "OnElementClick $winId"]
        if {$doPops} {
#	    bind $tableframe.table <Enter> \
#	        [list QueuePopup [namespace code DoInspPopup] \
#		     $winId %X %Y %x %y]
#	    $tableframe.table bindImage <Enter> \
#	        [list QueuePopup [namespace code DoInspPopup] $winId %X %Y]
#	    $tableframe.table bindText <Enter> \
#	        [list QueuePopup [namespace code DoInspPopup] $winId %X %Y]
	    bind $tableframe.table <Motion> \
		[namespace code [list MoveInInsp $winId %X %Y %x %y]]
	    bind $tableframe.table <Leave> RemovePopup
#	    $tableframe.table bindImage <Leave> RemovePopup
#	    $tableframe.table bindText <Leave> RemovePopup
        }
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

    proc GetCanvas {winId} {
        return ""
    }

# Hah, would like to make the full reference by combining the captions like
# this, but we have stripped them of CRs so they no longer match the model.
#    proc GetFullPath {tree node} {
#	set local [$tree item $node -text]
#	if {[string length [set parent [$tree parent $node]]]} {
#	    set base [GetFullPath $tree $parent]
#	} else {
#	    set base {}
#	}
#	return $base/$local
#    }
#
    menu .inspContext -tearoff 0
    menu .inspContext.param -tearoff 0
    
    .inspContext add command -label "View in model diagram"
    .inspContext add separator
    .inspContext add command -label "(Helper setup goes here)"
    .inspContext add separator
    .inspContext add cascade -menu .inspContext.param -label "Set parameter values"
    .inspContext.param add radio -variable paramSrc -value table -label "Edit as table"
    .inspContext.param add radio -variable paramSrc -value column -label "Get from column"
    .inspContext.param add radio -variable paramSrc -value grid -label "Get from grid/image"
    
    proc OnElementContext { winId X Y x y } {
	set node [$winId.tableframe.table identify row $x $y]
	if {[regexp ^\(.*\)\\. $node spare hlpr]} {
	    ::RunEnv::FocusTool $hlpr
	} else {
	    # display context menu
	    .inspContext entryconfigure 0 \
		-command [namespace code "ShowInModel $winId $node"]
	    .inspContext.param entryconfigure 0 \
		-command [namespace code "EditAsTable $winId $node"]
	    .inspContext post $X $Y
	}
    }

    proc ShowInModel {winId node} {
	global window_info
	# hardest bit is finding the canvas
	set topNode [$::helperTable($winId,whichInstance) GetNode]
	RaiseModelWindow $topNode
	foreach {topRef someNode} [array get window_info *,top_node] {
	    if {$someNode eq $topNode} {
		set canvas [string range $topRef 0 end-9]
		# check node appears in each canvas
		if {[GetFromProlog tk_locate('$canvas',$node)] eq {}} continue
		CanvasSee $canvas $node [expr $window_info($canvas,width)/2] \
		    [expr $window_info($canvas,height)/2]
	    }
	}
	prolog tk_do_colours($node,seln)
    }
    
    proc EditAsTable {winId node} {
	global table_entry paramData

	set topNode [$::helperTable($winId,whichInstance) GetNode]
	set tgt [GetCaptionPathFromId $node]
	set compName /$topNode$tgt
	set table_entry(fileName) {}
	set table_entry(values) $paramData($compName)
	SeparateTimeExtras
	set startLine [expr {[GetModelEval $node] ne "INPUT"}]
	set dims [lrange [GetCompProperty Dims $node] 0 end-1]
	set trans [GetCompProperty Trans $node]
	if {!$startLine} {
	    set dims [linsert $dims 0 TIME]
	    set trans [linsert $trans 0 {}]
	}
	EditTableData $startLine $tgt $dims $trans
	CombineTimeExtras
	set paramData($compName) $table_entry(values)
	set ::whichParamsAffected($compName) 1
	AcceptData $topNode $compName $startLine -1
	# do something to metadata too
    }

    proc OnElementClick { winId x y } {
	variable chop
	set node [$winId.tableframe.table identify row $x $y]
	if {[regexp ^\(.*\)\\. $node spare hlpr]} {
	    ::RunEnv::FocusTool $hlpr
	} else {
	    ProdFromHelper $winId $node \
		[string range [GetCaptionPathFromId $node] $chop end]
	}
    }
    
    proc DoInspPopup {winId X Y x y} {
	#	    ShowMess debug info $args ok
	global helperTable runState myNode

	set plName $helperTable($winId,whatPopped)
#puts "setting helperTable($winId,whatPopped)"
	if {![llength $plName]} {
	    return
	}
#	set node [$helperTable($winId,whichInstance) GetNode]
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
    
    proc MoveInInsp {winId X Y x y} {
	global helperTable

	set plName [$winId.tableframe.table identify row $x $y]
	if {[info exists helperTable($winId,whatPopped)]} {
	    if {[string equal $plName $helperTable($winId,whatPopped)]} {
		return; #; it's already queueued
	    }
	}
	set helperTable($winId,whatPopped) $plName
	    # changed row; renew popup
	RemovePopup
	eval QueuePopup [namespace code DoInspPopup] $winId $X $Y $x $y
    }

    proc Restore {winId} {initialize $winId}
    
    proc OpenLevel {level} {
        # only works for level = 0
	set tableframe $winId.tableframe
	
        $tableframe.table closetree node00001; # recursively close all nodes
        set nodes node00001; # root or Desktop
        for {set i 0} {$i <= $level} {incr i} {
            foreach node $nodes {
                $tableframe.table itemconfigure $node -open 1
                set nodes [$tableframe.table children $node]
            }
        }
    }

    proc AddHelperLeaf {winId node hlpr} {
	set tableframe $winId.tableframe
	if {[$tableframe.table exists $hlpr.$node]} return
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
	set ptags [$tableframe.table item $node -tags]
	$tableframe.table insert $node end -id $hlpr.$node \
	    -text $id -image $::iconImages($img) -tag "$ptags disp($hlpr)"
	$tableframe.table item $node -open 1
    }
}; # end namespace
