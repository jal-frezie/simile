#############################################################################
# Routines for entering a function graphically                              #
#############################################################################

# This is what happens when the graph button is pushed. It reads the parameter
# name and units from the boxes above the parameter list, then tries to find a
# graph(...) naming that parameter in the equation. If it succeeds it sends off
# the data about that graph to the graphing box, otherwise a null graph. On return
# the graph data is inserted or appended to the equation.

# graph function is graph(param, xlow, xhigh, xspan,
#	ylow, yhigh, yspan, [pt1, pt2 ... ptn])

set keyValue origsketch17650

namespace eval origsketch17650 {

proc identify {} {
	return "Edit function sketch"
}

proc initialize {winId} {
	set ms [message $winId.intro -text "Click on the node containing \
		the sketched function you wish to edit."]
	pack $ms
	GrabClicks $winId
}

proc Restore {windowId} {
    initialize $windowId
    set fullCapt [RestoreCrs [GetState $windowId]]
    click $windowId [GetIdFromCaptionPath $fullCapt] \
	[lindex [split $fullCapt /] end]
}

proc click {windowId nodename caption} {

    set graphData [GetModelGraph $nodename]
    if {![string compare $graphData nograph]} {
	$windowId.intro configure -text "There is no sketch graph associated with component $caption -- try another."
	return
    }
    ReleaseClicks $windowId
    pack forget $windowId.intro
    SetState $windowId [StripCrs [GetCaptionPathFromId $nodename]]
    set length [lindex $graphData 7]
    set graphPoints [join [lrange $graphData 8 end] ,]
    eval [list GraphEntry $windowId] [lrange $graphData 0 6] \
	[list $length $graphPoints $nodename]
#    kill_helper_window $windowId
}
    
# No need to do anything to graph sketch when displays update
    proc reset {winId} {
    }

proc display {args} {
}

} ;# end of namespace

