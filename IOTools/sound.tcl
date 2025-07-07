# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass Sound20220921
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper
    variable winId modelInst State
    
    self {
	method identify {} {
	    return "Sound wave output"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	next $modelInst $winTitle

	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    pack [message $winId.message \
		      -text "Generating sound wave for [lindex $State 0]"]
	    set useNode [GetIdFromCaptionPath [lindex $State 0]]
	    AddWaveCommand [$modelInst getNode] $useNode "/model/"
	    my display 0 0 0
	} else {
	    # new instance so request data from model
	    pack [message $winId.message \
		      -text "Click on model component for sound"]
	    $modelInst grabClicks $this
	}
    }

    destructor {
	if {[info exists State]} {
	    catch {AddWaveCommand [$modelInst getNode]
		[GetIdFromCaptionPath [lindex $State 0]] "/none/"}
	}
	next
    }

    method Click {path} {
	set State [list $path [$modelInst getMinValue $path] \
		       [$modelInst getMaxValue $path]]
	SetState $winId $State
	$winId.message configure -text "Generating sound wave for $path"
	AddWaveCommand [$modelInst getNode] [GetIdFromCaptionPath $path] "/model/"
	$modelInst releaseClicks
	my display 0 0 0
    }

    method Reset {} {
	# node id may be out of date or lost due to rebuild --
	if {[info exists State]} {
	    set topNode [$modelInst getNode]
	    set useNode [GetIdFromCaptionPath [lindex $State 0]]
	    AddWaveCommand $topNode $useNode "/model/"
	}
    }

    method display {time dispInt step} {
# time is current model time
# dispInt is time to next display call
# step is a spare parameter
	set wav [$modelInst getValue [lindex $State 0]]
	set min [lindex $State 1]
	if {[llength $wav]==1} {
	    set val [expr {200*($wav-$min) \
			       / ([lindex $State 2]-$min) - 100}]
	    set flash [Gradient green $winId $val]
	} else {
	    set flash [format #80%02x%02x \
			   [expr {128+round(127*[lindex $wav 1])}] \
			   [expr {128+round(127*[lindex $wav 3])}]]
	}
	if {[string length $flash]==7} {
#	    $winId configure -bg $flash
	}
    }
}
