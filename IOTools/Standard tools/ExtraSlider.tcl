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
	ReleaseClicks $winId
	pack forget $winId.m
	slide139::InsertSlider $winId $node /$caption 0
	SetState $winId [GetCaptionPathFromId $node]
    }    

    proc display {winId time display remainder} {
    }
    
} ;# end of namespace

