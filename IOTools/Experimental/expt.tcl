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

	set decor {param "Parameter value(s)" file \
		       list "List of cases" caselist \
		       compound "Multi-factor case(s)" compfact \
		       perm "Set of permutations" permut}
	set newLevel [UniqueId $type]
	set anchor [lsearch $decor $type]
	
	lappend clickPath $newLevel {}
	set f [MakeSubFrames $winId $frameZone $clickPath  [namespace current] 0]
	set lab $f.head.label
	$lab configure -text [lindex $decor $anchor+1] \
	    -image $::iconImages([lindex $decor $anchor+2]) -compound left
	pack $lab -side left
	CrossPlatformBind $f \
	    [namespace code [list OnElementContext [lrange $clickPath 0 end-1] %X %Y]]

	
    }
	
    public method delete {} {
	variable clickPath
	variable frameZone

	lappend clickPath {}
	set f [MakeSubFrames $winId $frameZone $clickPath  [namespace current] 0]
	destroy $f
    }
    
    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	global iconImages
	variable cMenu
	variable frameZone
	
	set cMenu [menu .expt_context -tearoff 0]
	set iMenu [menu $cMenu.insert -tearoff 0]
	$iMenu add command -label [tr. "Parameter value(s)"] -compound left \
	    -image $iconImages(file) -command "$this InsertLevel param"
	$iMenu add command -label [tr. "List of cases"] -compound left \
	    -image $iconImages(file) -command "$this InsertLevel list"
	$iMenu add command -label [tr. "Multi-factor case(s)"] -compound left \
	    -image $iconImages(file) -command "$this InsertLevel compound"
	$iMenu add command -label [tr. "Set of permutations"] -compound left \
	    -image $iconImages(file) -command "$this InsertLevel perm"
	
	$cMenu add cascade -label [tr. Insert] -menu $iMenu
	$cMenu add command -label [tr. Delete] -command "$this delete"
	
	set frameZone [DIYMakeFrames $winId]
	set f [MakeSubFrames $winId $frameZone {{} {}} [namespace current] 0]
	$f.head.label configure -image $iconImages(flask) -compound left
	pack $f.head.label -side left
	CrossPlatformBind $f \
	    [namespace code [list OnElementContext {{}} %X %Y]]
    }

    public method Click {path} {
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
    }
}
