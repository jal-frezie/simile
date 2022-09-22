# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Sound20220921
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "Sound wave output"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    pack [message $winId.message \
		      -text "Generating sound wave for [lindex $State 0]"]
	    AddWaveCommand [$modelInst cget -modelNode] \
				[GetIdFromCaptionPath [lindex $State 0]]
	    Display 0 0 0
	} else {
	    # new instance so request data from model
	    pack [message $winId.message \
		      -text "Click on model component for sound"]
	    $modelInst GrabClicks $this
	}
    }

    public method Click {path} {
	set State [list $path [$modelInst GetMinValue $path] \
		       [$modelInst GetMaxValue $path]]
	SetState $winId $State
	$winId.message configure -text "Generating sound wave for $path"
	AddWaveCommand [$modelInst cget -modelNode] [GetIdFromCaptionPath $path]
	$modelInst ReleaseClicks
	Display 0 0 0
    }

    public method Display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	set min [lindex $State 1]
	set val [expr {200*([$modelInst GetValue [lindex $State 0]]-$min) / \
			   ([lindex $State 2]-$min) - 100}]
	set flash [Gradient green $winId $val]
	$winId configure -bg $flash
    }

    public method Play {} {
	set node [GetIdFromCaptionPath [lindex $State 0]]
	AddWaveCommand $topNode $node
    }
}
