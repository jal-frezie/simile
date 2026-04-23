# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass TextView20140827
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper

    variable winId

    self {
	method identify {} {
	    return "Text viewer"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	next $modelInst $winTitle

	pack [text $winId.tx] -fill both -expand 1
	if {[string length $state]} { ;# we are restoring 
	    $winId.tx insert end $state
	}
    }

    method PrepareSaveString {} {
	set State [$winId.tx get 1.0 end]
    }

    method Display {time dispInt step} {
    }
}
