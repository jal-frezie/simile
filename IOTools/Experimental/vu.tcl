# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass VUMeter200070828
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper

    self {
	method identify {} {
	    return "Level indicator"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	next $modelInst $winTitle

	pack [::ttk::progressbar $winId.pb -orient v] -fill both -expand true
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    Display 0 0 0
	} else {
	    # new instance so request data from model
	    pack [message $winId.message \
		      -text "Click on model component for bar graph"]
	    $modelInst grabClicks $this
	}
    }

    method Click {path} {
	set State [list $path [$modelInst getMinValue $path] \
		       [$modelInst getMaxValue $path]]
	destroy $winId.message
	$modelInst releaseClicks
	Display 0 0 0
    }

    method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	set min [lindex $State 1]
	set val [expr {100*([$modelInst getValue [lindex $State 0]]-$min) / \
			   ([lindex $State 2]-$min)}]
	$winId.pb configure -value $val
    }
}
