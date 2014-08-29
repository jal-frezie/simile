# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass TextView20140827
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "Text viewer"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	pack [text $winId.tx] -fill both -expand 1
	if {[string length $state]} { ;# we are restoring 
	    $winId.tx insert end $state
	}
    }

    public method PrepareSaveString {} {
	set State [$winId.tx get 1.0 end]
    }

    public method Display {time dispInt step} {
    }
}
