# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass VUMeter200070828
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "Level indicator"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	pack [::ttk::progressbar $winId.pb -orient v] -fill both -expand true
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    Display 0 0 0
	} else {
	    # new instance so request data from model
	    pack [message $winId.message \
		      -text "Click on model component for bar graph"]
	    $modelInst GrabClicks $this
	}
    }

    public method Click {path} {
	set State [list $path [$modelInst GetMinValue $path] \
		       [$modelInst GetMaxValue $path]]
	destroy $winId.message
	$modelInst ReleaseClicks
	Display 0 0 0
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	set min [lindex $State 1]
	set val [expr {100*([$modelInst GetValue [lindex $State 0]]-$min) / \
			   ([lindex $State 2]-$min)}]
	$winId.pb configure -value $val
    }
}