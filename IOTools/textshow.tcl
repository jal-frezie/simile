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
	bind $winId.tx <Shift-Return> [namespace code [list my RunCmd]]
	if {[string length $state]} { ;# we are restoring 
	    $winId.tx insert end $state
	}
    }

    method RunCmd {} {
	set cmd [$winId.tx get 1.0 1.end]
	catch $cmd spill
	$winId.tx insert end $spill\n
    }

    method PrepareSaveString {} {
	set State [$winId.tx get 1.0 end]
    }

    method Display {time dispInt step} {
    }
}
