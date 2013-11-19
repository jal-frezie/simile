# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newLayerClass Photo20131023
itcl::class similescript::$newLayerClass {
    inherit Layer

    proc Identify {} {
	return "Background photo"
    }

    constructor {modelInst mainCanvas xzoom yzoom {state {}}} {
# perverse extra body because base class constructor has args
	Layer::constructor $modelInst $mainCanvas
    } {
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    # format of state is offx offy zoomx zoomy pngdata
	    image create photo $this.original -data [lindex $State 5]
	} else {
	    # new instance so request data from model
	    set photoFile [ChooseFile aerial.gif "Image for base photo:" 0 \
			       [GetNode]]
	    image create photo $this.original -file $photoFile
	    set State [list 0 0 1 1 [file tail $photoFile] \
			   [$this.original data -format png]]
	}
	PutSize $this.original
#	puts [$this.original configure]
	ZoomTo $xzoom $yzoom
    }

    destructor {
	$winId delete $this.main
	image delete $this.derived $this.original
    }

    public method ZoomTo {xzoom yzoom} {
	set stickIt [list [expr {[lindex $State 0]*$xzoom}] \
			 [expr {[lindex $State 1]*$yzoom}]]
	set tmpImg [GrowImage $this.original \
	    [expr {[$this.original cget -width]*[lindex $State 2]*$xzoom}] \
	    [expr {[$this.original cget -height]*[lindex $State 3]*$yzoom}]]
	set myTag [namespace tail $this].main
	if {[catch {$this.derived blank}]} { ;# not yet exist
	    image create photo $this.derived
	    $winId create image $stickIt -anchor sw -image $this.derived \
						 -tag $myTag
	} else {
	    $winId coords [$winId find withtag $myTag] $stickIt
	}
	$this.derived copy $tmpImg -shrink
    }

    public method GetTitle {} {
	return "Photo: [lindex $State 4]"
    }

    public method Display {time dispInt step} {
# nothing to do at display time -- it's a photo
	if {[string equal displaying $useNodes($winId,state)]} {
	    $winId raise [namespace tail $this].main
	}
    }
}