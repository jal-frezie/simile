set keyValue oneslider212

namespace eval $keyValue {

    proc identify {} {
	return "Duplicate slider"
    }

    proc initialize {winId} {
	pack [message $winId.m -text "Click on the input you want to add an extra slider for. It will work together with the one in the sliders box."]
	GrabClicks $winId
    }

    proc Restore {winId} {
	set capt [GetState $winId]
	slide139::InsertSlider $winId [GetIdFromCaptionPath $capt] $capt 0
    }

    proc reset {winId} {
    }

    proc click {winId node caption} {
	if {[llength [slide139::InsertSlider $winId $node /$caption 0]]} {
	    ReleaseClicks $winId
	    pack forget $winId.m
	    SetState $winId [GetCaptionPathFromId $node]
	} else {
	    $winId.m configure -text "This component is not a variable parameter, or if it is, it has too many dimensions to show a set of graphical input tools for it."
	}
    }    

    proc display {winId time display remainder} {
    }
    
} ;# end of namespace

