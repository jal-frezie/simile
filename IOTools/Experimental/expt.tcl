# This is a dead simple helper designed to test the object-oriented helper app
# interface.

itcl::class ExptLevel {
    constructor {} {
    }
    destructor {
    }
}

set newHelperClass ExptSetup20210104
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "Set up experiment"
    }
    
    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	global iconImages
	variable cMenu
	variable frameZone
	variable decor
	
	set decor [list param [tr. "Parameter value"] file \
		       plist [tr. "List for parameter"] list \
		       clist [tr. "List of cases"] caselist \
		       compound [tr. "Multi-factor case(s)"] compfact \
		       perm [tr. "Set of permutations"] permut]
	set cMenu [menu .expt_context -tearoff 0]
	set iMenu [menu $cMenu.insert -tearoff 0]
	foreach {key txt img} $decor {
	    $iMenu add command -label $txt -compound left \
		-image $iconImages($img) -command "$this InsertLevel $key"
	}
	$cMenu add cascade -label [tr. Insert] -menu $iMenu
	$cMenu add command -label [tr. Delete] -command "$this delete"
	
	set frameZone [DIYMakeFrames $winId]
	set f [MakeSubFrames $winId $frameZone {{} {}} [namespace current] 0]
	$f.head.label configure -image $iconImages(flask) -compound left
	pack $f.head.label -side left
	CrossPlatformBind $f \
	    [namespace code [list OnElementContext {{}} %X %Y]]
    }
    destructor {
	destroy .expt_context.insert
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
	variable frameZone
	variable curFrame
	variable decor
	
	set anchor [lsearch $decor $type]
	
	if {[lsearch {param plist} $type]>-1} {
	    pack [label $winId.label -text [tr. "Select a parameter from the model diagram or explorer"] -fg red]
	    $modelInst GrabClicks $this
	} else {
	    set newLevel [UniqueId $type]
	    lappend clickPath $newLevel
	    set f [MakeSubFrames $winId $frameZone [concat $clickPath {{}}] \
		       [namespace current] 0]
	    set lab $f.head.label
	    $lab configure -text [lindex $decor $anchor+1] \
		-image $::iconImages([lindex $decor $anchor+2]) -compound left
	    pack $lab -side left
	    CrossPlatformBind $f \
		[namespace code [list OnElementContext  $clickPath %X %Y]]
	}

	
    }

    public method GetCaseName {path} {
	variable frameZone
	
	set t [PutItThere .caseentry $frameZone]
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

    public method delete {} {
	variable clickPath
	variable frameZone

	lappend clickPath {}
	set f [MakeSubFrames $winId $frameZone $clickPath  [namespace current] 0]
	destroy $f
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
    }
}
