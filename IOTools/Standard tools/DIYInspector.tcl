# Version of model explorer using subframes for greater flexibility and
# functionality

set newHelperClass DIYInspector20210125
itcl::class similescript::$newHelperClass {
    inherit Helper

    public variable topFrame
    public variable permMembers
    
    proc Identify {} {
	return "Explorer (DIY version)"
    }
    
    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	global iconImages
	variable chop
	variable cMenu
	variable decor

	set chop [string length $state]
	set doPops 0
	set paramEdits 0
	set incExpts 0
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
	set topFrame [DIYMakeFrames $winId]
	# Attempt to add experiment node as peer of default top level
	if {$incExpts} {
	    set decor [list param [tr. "Parameter value"] file \
			   plist [tr. "List for parameter"] list \
			   compound [tr. "Multi-factor case"] compfact \
			   perm [tr. "Set of permutations"] permut]
	    set cMenu $winId.expt_context
	    if {![winfo exists $cMenu]} {
		menu $cMenu -tearoff 0
		set iMenu [menu $cMenu.insert -tearoff 0]
		foreach {key txt img} $decor {
		    $iMenu add command -label $txt -compound left \
			-image $iconImages($img) -command "$this InsertLevel $key"
		}
		$cMenu add cascade -label [tr. Insert] -menu $iMenu
		$cMenu add command -label [tr. Delete] \
		    -command "$this delete"
	    }
	    
	    set f [MakeSubFrames $::myNode $topFrame [list $::myNode {}] \
		       fileparams 0]
	    $f.head.label configure -text [tr. {Default case}] \
		-image $iconImages(globe) -compound left
	    pack $f.head.label -side left -expand 0

	    set f [MakeSubFrames $this $topFrame {expt {}} \
		       [namespace current] 0]
	    $f.head.label configure -text [tr. {Experimental conditions}] \
		-image $iconImages(flask) -compound left
	    pack $f.head.label -side left -expand 0
	    CrossPlatformBind $f \
		[namespace code [list OnElementContext {expt} %X %Y]]
	}
	#set f [MakeSubFrames insp $topFrame [list $::myNode {}] \
	#	   [namespace current] 0]

        foreach component [GetObjectList] {
	    set fullCapt [GetCaptionPathFromId $component]
	    if {(![string length $state] || \
		    ![string first $state $fullCapt]) && \
		    [lsearch $typesToShow [GetModelEval $component]]>=0} {

		# AddEntry $winId $::myNode $component / 1 1
		set notInput -1
		set levels [split $fullCapt /]
		set capt [lindex $levels end]
		set levels [string map {. :} $levels]
		set type [GetModelClass $component]
		if {$type eq "SUBMODEL"} {
		    lappend levels {}
		    set notInput 1
		} else {
		    set notInput [lsearch {INPUT TABLE} \
				      [GetModelEval $component]]
		    if {$notInput>-1 && $type eq "VARIABLE"} {
			set type [lindex {input file} $notInput]
		    }
		}
		if {$paramEdits} {
		    set e [AddEntry $winId $::myNode $component $::myNode 0 $notInput]
		    if {![winfo exists $e]} continue
		}
		set f [MakeSubFrames insp $topFrame [lreplace $levels 0 0 $::myNode] \
			   {} 0]
		bind $f <Button-1> [list ProdFromHelper $winId $component \
					[string range $fullCapt $chop end]]
		bind $f <Button-2> {puts "Behold the %W"}
		if {$type eq "SUBMODEL"} {
		    set label $f.head.label
		    $label configure -image $iconImages(submodel) \
			-compound left
		    pack $label -expand 0
		    if {[string first . $capt]>=0} { ;# frag submodel
			$label configure -text $capt:
		    }
		} else {
		    set beeGee [[winfo parent $f].head cget -bg]
#		    set bStyle [[winfo parent $f].head.vis cget -style]
		    $f configure -bg $beeGee
		    set label $f.caption
		    if {$paramEdits} {
		    } else {
#			pack [ttk::label $f.caption -text $capt \
#				  -style $bStyle] -side left
			pack [label $label -text $capt -bg $beeGee] -side left
		    }
		    $label configure -image $iconImages([string tolower $type]) -compound left
		    bindtags $label [linsert [bindtags $label] 0 $f]
		    }		    
		    if {$doPops} {
			InspLabelPopup $label $component $capt
		}
	    }
	}
	set dad [winfo parent $winId]
	set grandad [winfo parent $dad]
	if {[winfo class $grandad] eq "TNotebook"} {
	    if {[info exists notInput]} {
		$grandad add $dad
	    } else {
		$grandad hide $dad
	    }
	}
    }
    destructor {
	destroy .expt_context
    }

    proc OnElementContext {path X Y} {
	variable cMenu
	variable clickPath

	$cMenu entryconfig Insert -state normal
	# We have a hierarchy of frames below the click, need to find which
	set clickPath $path
	switch [lindex $clickPath end] {
	    param {
		$cMenu entryconfig Insert -state disabled
	    }
	}
	tk_popup $cMenu $X $Y
    }

    proc Combinations {sets} {
        if {$sets eq {}} return
	set result {}
	set bases [Combinations [lrange $sets 1 end]]
	set additions [lindex $sets 0]
	foreach part $bases {
	    foreach extn $additions {
		lappend result [concat $part [list $extn]]
	    }
	}
	return [concat $result $bases $additions]
    }

    public method ExtendPerms {src case levels} {
	if {$levels eq {}} return
	set lvl [lindex $levels end]
	if {[TypeFromLevel frame$lvl] eq "perm"} {
	    set oldMembers {}
	    set added 0
	    foreach {locn oldCases} [array get permMembers $lvl,*] {
		if {$locn eq "$lvl,$src"} {
		    # is addition to list of alternatives
		    lappend permMembers($locn) $case
		    set added 1
		} else {
		    lappend oldMembers $oldCases
		}
	    }
	    foreach oldCombo [Combinations $oldMembers] { ;# only add new ones
		set oldCase [join [lsort $oldCombo] +]
		AddCase [GetNode] [join [lsort [linsert $oldCombo end $case]] +] $oldCase
	    }
	    if {!$added} {
		array set permMembers [list $lvl,$src [list $case]]
	    }
	} else {
	    ExtendPerms $src $case [lrange $levels 0 end-1]
	}
    }

    public method ReducePerms {src case levels} {
	if {$levels eq {}} return
	set lvl [lindex $levels end]
	if {[TypeFromLevel frame$lvl] eq "perm"} {
	    set oldMembers {}
	    set added 0
	    foreach {locn oldCases} [array get permMembers $lvl,*] {
		if {$locn eq "$lvl,$src"} {
		    # is addition to list of alternatives
		    set place [lsearch $oldCases $case]
		    set remain [lreplace $oldCases $place $place]
		    if {$remain eq {}} {
			unset permMembers($locn)
		    } else {
			set permMembers($locn) $remain
		    }
		} else {
		    lappend oldMembers $oldCases
		}
	    }
	    foreach oldCombo [Combinations $oldMembers] { ;# only add new ones
		DeleteCase [GetNode] [join [lsort [linsert $oldCombo end $case]] +]
	    }
	} else {
	    ReducePerms $src $case [lrange $levels 0 end-1]
	}
    }

    # can probably improve the logic of this next bit
    method InsertLevel {type} {
	global myNode compCases
	variable clickPath
	variable decor
	
	set anchor [lsearch $decor $type]
	
	switch -regexp $type {
	    param|plist {
		set paramEdits 1
		set f [MakeSubFrames $this $topFrame [concat $clickPath {{}}] \
			   [namespace current] 0]
		if {[CaseForExpt $myNode $clickPath] ne ""} {
		} elseif {$type eq "param"} {
		    set parmCase [GetCaseName {alternative value case}]
		    if {$parmCase eq {}} return
		    AddCase $myNode $parmCase
		    set newLevel [UniqueId $type]
		    lappend clickPath $newLevel
		    set compCases($myNode,$newLevel) $parmCase
		    ExtendPerms $newLevel $parmCase $clickPath
		}
		pack [label $f.label -wrap 250 -text [tr. "Select the parameter to vary in this case from the model diagram or explorer"] -fg red]
		lappend clickPath $type
		$modelInst GrabClicks $this
	    } default {
		set newLevel [UniqueId $type]
		lappend clickPath $newLevel
		set f [MakeSubFrames $this $topFrame [concat $clickPath {{}}] \
			   [namespace current] 0]
		set lab $f.head.label
		set leafName [lindex $decor $anchor+1]
		if {$type eq "compound"} {
		    set compCase [GetCaseName combination]
		    AddCase $myNode $compCase
		    set compCases($myNode,$newLevel) $compCase
		    set leafName "$compCase: $leafName"
		    ExtendPerms $newLevel $compCase $clickPath
		}
		$lab configure -compound left -text $leafName \
		    -image $::iconImages([lindex $decor $anchor+2])
		pack $lab -side left
		CrossPlatformBind $f \
		    [namespace code [list OnElementContext $clickPath %X %Y]]
	    }
	}
    }

    public method delete {} {
	# needs to handle case lists
	global myNode compCases
	variable clickPath

	set f [MakeSubFrames $winId $topFrame [concat $clickPath {{}}] \
		   [namespace current] 0]
	set leaf [lindex $clickPath end]
	#puts "cC [array get compCases] leaf $leaf"
	set endNodes [string first {, } $leaf]
	if {$endNodes>=0} {
	    if {[string range $leaf $endNodes end] eq ", s"} {
		$f.e delete 0 end
		$f.tick invoke
	    } else {
		set case [string range $leaf $endNodes+2 end]
		set byLevel [array get compCases $myNode,*]
		set oldLevel [string range [lindex $byLevel [lsearch $byLevel $case]-1] 10 end]
		ReducePerms $oldLevel $case $clickPath
		DeleteCase $myNode $case
		unset compCases($myNode,$oldLevel)
	    }
	} elseif {[info exists compCases($myNode,$leaf)]} {
	    set lvl [string range [winfo name $f] 5 end]
	    ReducePerms $lvl $compCases($myNode,$leaf) $clickPath
	    DeleteCase $myNode $compCases($myNode,$leaf)
	    unset compCases($myNode,$leaf)
	} elseif {[winfo exists $f.e]} {
	    # parameter value in compound case, case will survive so clear it
	    $f.e delete 0 end
	    AcceptData $myNode /[join [lrange $clickPath end-1 end] /] 0 1 \
		[CaseForExpt $myNode $clickPath]
	} else {
	    set safePath $clickPath
	    foreach subF [winfo children $f] {
		set lvl [string range $subF [string length ${f}.] end]
		if {[string first frame $lvl]} continue
		set clickPath [concat $safePath [list [string range $lvl 5 end]]]
		$this delete ;# does child
	    }
	}
	after 40 [list destroy $f] ;# destroying inline inexplicably fails
    }
    
    proc InspLabelPopup {widget node capt} {
	bind $widget <Enter> [::itcl::code AddPopup %W %X %Y $::myNode $node]
	bind $widget <Leave> RemovePopup
    }

    proc AddPopup {wid X Y node capt} {
	PostPopup $wid $X $Y
	AddPopupMessage novalue \#ffffc0 GetShortVals $node $capt
    }

    proc Empty {inst path} {
	variable clickPath
	variable cMenu

	set topF [MakeSubFrames $inst [$inst cget -topFrame] $path {} 0]
	set safePath [lindex [CrossPlatformBind $topF] 0 3 1]
	foreach subF [winfo children $topF] {
	    set lvl [string range $subF [string length ${topF}.] end]
	    if {[lsearch {head body tree caption tick cross} $lvl]>-1} \
		continue
	    set clickPath [concat $safePath [list [string range $lvl 5 end]]]
	    $cMenu invoke Delete ;# does child
	}
    }

    public method StartElement {type avPairs} {
	variable clickPath
	variable preSelected
	variable filling
	
	array set attrs $avPairs
	if {[info exists attrs(case)]} {
	    set preSelected $attrs(case)
	} elseif {[info exists preSelected]} {
	    unset preSelected
	}
	
	switch $type {
	    sxf {
		set clickPath expt
	    } value {
		$filling.e insert end " [list $attrs(index) $attrs(value)]"
	    } default {
		InsertLevel $type
		if {[info exists attrs(tgt)]} {
		    # will be awaiting a click, so supply one
		    Click /$attrs(tgt)
		}
		if {$type eq "plist" || [info exists attrs(val)]} {
		    set f [MakeSubFrames $this $topFrame $clickPath \
			       [namespace current] 0]
		    if {$type eq "plist"} {
			set filling $f
		    } else {
			$f.e insert 0 $attrs(val)
			$f.tick invoke
		    }
		}
	    }
	}
    }

    public method FinishElement {type} {
	variable clickPath
	variable filling
	
	if {$type eq "plist"} {
	    $filling.e delete 0 1 ;# trim initial space
	    $filling.tick invoke
	    unset filling
	}
	if {$type ne "value"} {
	    set clickPath [lrange $clickPath 0 end-1]
	}
    }

    proc Open {inst path} {
	variable sxfParser
	set sxfParser [::xml::parser -ignorewhitespace true \
			   -elementstartcommand [list $inst StartElement] \
			   -elementendcommand [list $inst FinishElement]]
	set title [tr. {Load experiment setup from:}]
	set topNode [$inst GetNode]
        set exptFile [ChooseFile model.sxf $title 0 $topNode]
	if {[llength $exptFile]} {
	    set pStr [open $exptFile r]
	    set dada [DefuseXmlBombs [read $pStr]]
	    close $pStr
	    $sxfParser parse $dada
	}
    }

    proc Save {inst path} {
	set title [tr. {Save experiment setup as:}]
	set topNode [$inst GetNode]
        set metaFile [ChooseFile model.sxf $title 1 $topNode]
	if {[llength $metaFile]} {
	    set SimileProject(expt_setup,$topNode/) $metaFile
            set pStr [NetOpen $metaFile w]
            
	    puts $pStr {<?xml version="1.0"?>}
	    puts $pStr {<?xml-stylesheet type="text/xsl" href="sxf1.xsl"?>}
	    puts $pStr "<sxf simile_version=\"$::env(SIMILE_VERSION)\">"
	    set topF [MakeSubFrames $inst [$inst cget -topFrame] $path {} 0]
	    SaveLevel $topF $pStr "  "
	    puts $pStr {</sxf>}
	    close $pStr
	}
    }

    proc TypeFromLevel {lvl} {
	if {[regexp {frame([a-z]+)[0-9]+} $lvl spare type]} {
	    return $type
	} else {
	    return leaf
	}
    }

    proc SaveLevel {topF pStr indent} {
	foreach subF [winfo children $topF] {
	    set lvl [string range $subF [string length ${topF}.] end]
	    if {[lsearch {head body tree caption tick cross} $lvl]>-1} continue
	    set type [TypeFromLevel $lvl]
	    if {[lsearch {compound perm} $type]>-1} {
		if {$type eq "compound"} {
		    set compCase [$subF.head.label cget -text]
		    set trim [string length xx[tr. "Multi-factor case"]]
		    set compCase " case=\"[string range $compCase 0 end-$trim]\""
		} else {
		    set compCase ""
		}
		puts $pStr "$indent<$type label=\"[string range $lvl 5 end]\"$compCase>"
		SaveLevel $subF $pStr "  $indent"
		puts $pStr "$indent</$type>"
	    } elseif {[string range $lvl end-2 end] eq ", s"} {
		puts $pStr "$indent<plist tgt=\"[string range $lvl 5 end-3]\">"
		WriteLiteralParam $pStr [$subF.e get] "  $indent"
	        puts $pStr $indent</plist>
	    } else {
		set npt [string first ", " $lvl]
		if {$npt>-1} {
		    puts $pStr "$indent<param tgt=\"[string range $lvl 5 $npt-1]\" case=\"[string range $lvl $npt+2 end]\" val=\"[$subF.e get]\"/>"
		} else { ;# inside a compound case so no case name here
		    puts $pStr "$indent<param tgt=\"[string range $lvl 5 end]\" val=\"[$subF.e get]\"/>"
		}
	    }
	}
    }

    public method GetCaseName {path} {
	variable preSelected
	if {[info exists preSelected]} {
	    set result $preSelected
	    unset preSelected
	    return $result
	}
	set t [PutItThere .caseentry $winId]
	wm protocol $t WM_DELETE_WINDOW {set case(done) 0}
	wm title $t "Case name"
	wm resizable $t 0 0
	
	set ft [frame .caseentry.ft]
	pack [message $ft.m -text "Parameter $path selected. Now supply a name for this case in the experiment:" -width 300] \
	    -padx 4 -pady 6 -anchor nw 
	pack [ttk::entry $ft.e -width 40] \
	    -padx 4 -pady 6 -anchor nw -side left
	
	bind $ft.e <Return> "set case(done) 1"
	pack .caseentry.ft -anchor nw -fill both

	pack [set bs [frame .caseentry.buttframe]]
    #pack [button $bs.clear -text Clear -width 10 -command ".caseentry.e delete 0 end"] -padx 2 -pady 2 -side left
	pack [button $bs.ok -text [tr. OK] -default active -width 10 \
		  -command "set case(done) 1"] -padx 2 -pady 4 -side left
	pack [button $bs.cancel -text [tr. Cancel] -width 10 \
		  -command "set case(done) 0"] -padx 2 -pady 4 -side left
	pack [button $bs.help -text [tr. Help] -width 10 \
		  -command "ContextSensitiveHelp .caseentry experiments.htm"] \
	-padx 2 -pady 4 -side left
    
	focus $ft.e
	LetItShow .caseentry case(done)
	set result [$ft.e get]
	PackItUp .caseentry
	if {$::case(done)==1} {
	    return $result
	}
	
    }

    public method Click {path} {
	global myNode compCases
	variable curFrame
	variable clickPath
	variable listStrings

	set node [IdFromTail $myNode $path -1]
	set action [lindex $clickPath end]
	set clickPath [lrange $clickPath 0 end-1]

	$modelInst ReleaseClicks
	
	if {$action eq "plist"} {
	    set listStrings($path) {}
	    set compCases($myNode,$path) {}
	    set f [AddEntry $winId $myNode $node $clickPath 0 0 s]
	    # just like a regular entry except...
	    $f.caption configure -image $::iconImages(list) -compound left
	    $f.tick configure -command [list $this DecodeListSpec \
					    $f $path $clickPath]
	    $f.cross configure -command [list $this RevertListSpec $f $path]
	} else {
	    set caseName ""
	    if {[string match param* [lindex $clickPath end]]} {
		set caseName [CaseForExpt $myNode $clickPath]
		set clickPath [lrange $clickPath 0 end-1]
	    }
	#    if {[CaseForExpt $myNode $clickPath] eq ""} {
	#	set caseName [GetCaseName $path]
	#	# Add case for this entry
	#	if {$caseName eq {}} return
	#	AddCase $myNode $caseName
	#    }
	    set notInput [expr {[GetModelEval $node] ne "INPUT"}]
	    set type [lindex {input file} $notInput]
	    set f [AddEntry $winId $myNode $node \
		       $clickPath 0 $notInput $caseName]
	    $f.caption configure -image $::iconImages($type) \
		-compound left
	}
	destroy [winfo parent $f].label
	lappend clickPath [$f.caption cget -text]
	CrossPlatformBind $f.caption \
	    [namespace code [list OnElementContext  $clickPath %X %Y]]
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
    }


    public method RevertListSpec {box path} {
	variable listStrings

	$box.e delete 0 end
	$box.e insert 0 $listStrings($path)
    }

    public method InterpList {listExpr} {
	set range [scan $listExpr "%f to %f step %f" start end step]
	if {$range>1} {
	    if {$range==2} {
		set step 1
	    }
	    if {!($end-$start)/$step>1} {
		error "Too few steps"
	    }
	    for {set val $start} {$val/$step<=$end/$step} \
		{set val [expr $val+$step]} {
		    lappend compound $name=$val $val
		}
	} else {
	    set alt [UglifyValList $listExpr 0]
	    if {[IsPretty $listExpr]==2} { ;# a json array, legibilize indices
		foreach {ind val} $alt {
		    lappend compound $name=$val $val
		}
	    } else {
		set compound $alt
	    }
	}
	return $compound
    }

    public method DecodeListSpec {box path hitPath} {
	global myNode compCases
	variable listStrings
	variable clickPath

	if {[focus] eq "$box.cross"} {return 0}
	# tick invoked by clicking on cross, not what user wanted
	#bind $box.e <FocusOut> {} ;# in case of error message
	set oldCases $compCases($myNode,$path)
	set lvl [string range [winfo name $box] 5 end]
	set listExpr [$box.e get]
	if {$listExpr eq $listStrings($path)} return
	
   	set compCases($myNode,$path) {}
	set fullPath "/[lindex $hitPath end]$path, s"
        foreach {name val} [InterpList $listExpr] {
	    set found [lsearch $oldCases $name]
	    if {$found>=0} {
		set oldCases [lreplace $oldCases $found $found]
	    } else {
		AddCase $myNode $name
		ExtendPerms $lvl $name $hitPath
	    }
	    # set the actual parameter in the case!
	    $box.e delete 0 end
	    $box.e insert 0 $val
	    AcceptData $myNode $fullPath 0 1 $name
	    
	    lappend compCases($myNode,$path) $name
	}
	$box.e delete 0 end
	$box.e insert 0 $listExpr
	foreach case $oldCases {
	    ReducePerms $lvl $case $hitPath
	    DeleteCase $myNode $case
	}
	
	set listStrings($path) $listExpr
	#bind $box.e <FocusOut> [list $box.tick invoke]
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

	set fullCapt [GetCaptionPathFromId $node]
	set levels [split $fullCapt /]
	set f [MakeSubFrames insp $topFrame [lreplace $levels 0 0 [GetNode]] \
		   {} 0]
	set cmd [list ::RunEnv::FocusTool $hlpr]
	foreach prev [winfo children $f] {
	    if {[string match *Button [winfo class $prev]] && \
		    [$prev cget -command] eq $cmd} {
		if {!$add} {
		    destroy $prev
		}
		return ;# is already there		    
	    }
	}
	if {!$add} {return} ;# is already gone
	set neWidg [UniqueId hlpr]
	#	set bStyle [[winfo parent $f].head.vis cget -style]
	set beeGee [[winfo parent $f].head.vis cget -bg]
	pack [button $f.$neWidg -bg $beeGee -image $::iconImages($img) \
		  -command [list ::RunEnv::FocusTool $hlpr]] \
	    -side right -padx 1p
	BindPopup $f.$neWidg $id
    }
}
