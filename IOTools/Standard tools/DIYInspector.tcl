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
	global iconImages
	variable chop
	variable cMenu
	variable decor

	set chop [string length $state]
	set doPops 0
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
		set incExpts 1
		set typesToShow {INPUT TABLE}
	    } outputs {
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
			   clist [tr. "List of cases"] caselist \
			   compound [tr. "Multi-factor case(s)"] compfact \
			   perm [tr. "Set of permutations"] permut]
	    if {![winfo exists .expt_context]} {
		set cMenu [menu .expt_context -tearoff 0]
		set iMenu [menu $cMenu.insert -tearoff 0]
		foreach {key txt img} $decor {
		    $iMenu add command -label $txt -compound left \
			-image $iconImages($img) -command "$this InsertLevel $key"
		}
		$cMenu add cascade -label [tr. Insert] -menu $iMenu
		$cMenu add command -label [tr. Delete] \
		    -command "$this delete"
	    }
	    
	    set f [MakeSubFrames insp $topFrame {expt {}} [namespace current] 0]
	    $f.head.label configure -text [tr. {Experimental conditions}] \
		-image $iconImages(flask) -compound left
	    pack $f.head.label -side left -expand 0
	    CrossPlatformBind $f \
		[namespace code [list OnElementContext {expt} %X %Y]]
	    set f [MakeSubFrames $::myNode $topFrame [list $::myNode {}] \
		       fileparams 0]
	    $f.head.label configure -text [tr. {Default case}] \
		-image $iconImages(globe) -compound left
	    pack $f.head.label -side left -expand 0
	}
	set f [MakeSubFrames insp $topFrame [list $::myNode {}] \
		   [namespace current] 0]

        foreach component [GetObjectList] {
	    set fullCapt [GetCaptionPathFromId $component]
	    if {(![string length $state] || \
		    ![string first $state $fullCapt]) && \
		    [lsearch $typesToShow [GetModelEval $component]]>=0} {

		# AddEntry $winId $::myNode $component / 1 1
		set notInput -1
		set levels [split $fullCapt /]
		set capt [lindex $levels end]
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
		if {$incExpts && $notInput>-1} {
		    set e [AddEntry $winId $::myNode $component $::myNode 0 $notInput]
# do this in AE so it also worx for expt conds
#		    if {$notInput>-1} {
#			bind $e.e <FocusOut> [list $e.tick invoke]
#		    }
		}
		set f [MakeSubFrames insp $topFrame [lreplace $levels 0 0 $::myNode] \
			   [namespace current] 0]
		bind $f <Button-1> [list ProdFromHelper $winId $component \
					[string range $fullCapt $chop end]]
		if {$type eq "SUBMODEL"} {
		    set label $f.head.label
		    $label configure -image $iconImages(submodel) \
			-compound left
		    pack $label -expand 0
		} else {
		    set beeGee [[winfo parent $f].head cget -bg]
		    set bStyle [[winfo parent $f].head.vis cget -style]
		    $f configure -bg $beeGee
		    if {$incExpts && $notInput>-1} {
		    } else {
			pack [ttk::label $f.caption -text $capt \
				  -style $bStyle] -side left
		    }
		    $f.caption configure -image $iconImages([string tolower $type]) -compound left
		    bindtags $f.caption [linsert [bindtags $f.caption] 0 $f]
		    if {$doPops} {
			LabelPopup $f.caption $component $capt
		    }		    
		}
	    }
	}
    }
    destructor {
	destroy .expt_context
    }
        
    proc OnElementContext {path X Y} {
	variable cMenu
	variable clickPath
	# We have a hierarchy of frames below the click, need to find which
	$cMenu post $X $Y
	set clickPath $path
    }

    public method InsertLevel {type} {
	variable clickPath
	variable decor
	variable compCases
	
	set anchor [lsearch $decor $type]
	
	switch -regexp $type {
	    param|plist {
		pack [label $winId.label -text [tr. "Select a parameter from the model diagram or explorer"] -fg red]
		$modelInst GrabClicks $this
	    } default {
		set newLevel [UniqueId $type]
		lappend clickPath $newLevel
		set f [MakeSubFrames $winId $topFrame [concat $clickPath {{}}] \
			   [namespace current] 0]
		set lab $f.head.label
		set leafName [lindex $decor $anchor+1]
		if {$type eq "compound"} {
		    set compCase [GetCaseName combination]
		    AddCase $::myNode $compCase
		    set compCases($newLevel) $compCase
		    set leafName "$compCase: $leafName"
		}
		$lab configure -compound left -text $leafName \
		    -image $::iconImages([lindex $decor $anchor+2])
		pack $lab -side left
		CrossPlatformBind $f \
		    [namespace code [list OnElementContext  $clickPath %X %Y]]
	    }
	}
    }

    public method delete {} {
	variable clickPath
	
	set f [MakeSubFrames $winId $topFrame [concat $clickPath {{}}] \
		   [namespace current] 0]
	# todo: destroy instance for case
	destroy $f
    }
    
    proc LabelPopup {widget node capt} {
	bind $widget <Enter> [::itcl::code AddPopup %W %X %Y $::myNode $node]
	bind $widget <Leave> RemovePopup
    }

    proc AddPopup {wid X Y node capt} {
	PostPopup $wid $X $Y
	AddPopupMessage novalue \#ffffc0 GetShortVals $node $capt
    }
    
    public method GetCaseName {path} {	
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
	global myNode
	variable curFrame
	variable clickPath
	variable compCases

	set node [IdFromTail $myNode $path -1]
	if {[catch {set caseName $compCases([lindex $clickPath end])}]} {
	    set caseName [GetCaseName $path]
	}
	if {$caseName ne {}} {
	    set notInput [expr {[GetModelEval $node] ne "INPUT"}]
	    set type [lindex {input file} $notInput]
	    set f [AddEntry $winId $myNode [IdFromTail $myNode $path -1] \
		       $clickPath 0 $notInput $caseName]
	    $f.caption configure -image $::iconImages([string tolower $type]) \
		-compound left
	    destroy $winId.label
	}
	$modelInst ReleaseClicks
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

	set fullCapt [GetCaptionPathFromId $node]
	set levels [split $fullCapt /]
	set f [MakeSubFrames insp $topFrame [lreplace $levels 0 0 [GetNode]] \
		   [namespace current] 0]
	set cmd [list ::RunEnv::FocusTool $hlpr]
	foreach prev [winfo children $f] {
	    if {[winfo class $prev] eq "TButton" && \
		    [$prev cget -command] eq $cmd} {
		if {!$add} {
		    destroy $prev
		}
		return ;# is already there		    
	    }
	}
	if {!$add} {return} ;# is already gone
	set neWidg [UniqueId hlpr]
	set bStyle [[winfo parent $f].head.vis cget -style]
	pack [ttk::button $f.$neWidg -style $bStyle -image $::iconImages($img) \
		  -command [list ::RunEnv::FocusTool $hlpr]] \
	    -side right -padx 1p
	BindPopup $f.$neWidg $id
    }
}
