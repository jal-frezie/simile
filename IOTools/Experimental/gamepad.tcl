set keyValue moopneek

namespace eval $keyValue {

    proc identify {} {
	return "GamePad"
    }

    proc initialize {winId} {
	pack [message $winId.m -text "Click on the input you want to control with this pad"]
	GrabClicks $winId
    }

    proc Restore {winId} {
	initialize $winId
	click $winId [GetIdFromCaptionPath [GetState $winId]] {}
    }

    proc reset {winId} {
    }

    proc click {winId node caption} {
	ReleaseClicks $winId
	pack forget $winId.m
	pack [frame $winId.f -bg green3 -bd 2 -relief raised] \
	    -fill both -expand 1
	bind $winId.f <Button-1> [namespace code "Stick $winId"]
	bind $winId.f <ButtonRelease-1> [namespace code "Unstick $winId"]
	SetState $winId [GetCaptionPathFromId $node]
    }

    proc display {winId time display remainder} {
    }

    proc Stick {winId} {
	global checkStates
	set checkStates([GetIdFromCaptionPath [GetState $winId]]) 1
	$winId.f config -relief sunken
    }

    proc Unstick {winId} {
	global checkStates
	set checkStates([GetIdFromCaptionPath [GetState $winId]]) 0
	$winId.f config -relief raised
    }

} ;# end of namespace

