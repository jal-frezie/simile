#############################################################################
# Reset the random number seed                                              #
#############################################################################

# This allows the user to start the random number generator on a predictable
# sequence

set keyValue setrand92383

namespace eval ::setrand92383 {

proc identify {} {
	return "Initialize pseudo-random"
}

proc initialize {winId} {
	set ms [message $winId.intro -aspect 400 -text "Enter an integer value for the random number seed:"]
	pack $ms -padx 4 -pady 4
	set exit [namespace code "Done $winId"]
	set en [entry $winId.entry -textvariable [namespace current]::value]
	bind $en <Return> $exit
	pack $en -padx 4 -pady 4
	set bt [button $winId.bt -text "Set seed" -default active -width 10 -command $exit]
	pack $bt -padx 4 -pady 4
}

proc Done {winId} {
	variable value
	randseed $value
#	kill_helper_window $winId
}

# No need to do anything to graph sketch when displays update
proc display {args} {
}

} ;# end of namespace
