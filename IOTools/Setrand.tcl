#############################################################################
# Reset the random number seed                                              #
#############################################################################

# This allows the user to start the random number generator on a predictable
# sequence

set keyValue setrand92383

namespace eval setrand92383 {

proc identify {} {
	return "Initialize pseudo-random"
}

proc initialize {winId} {
	set ms [message $winId.intro -text "Enter your value for the random number seed (integer)."]
	pack $ms
	set exit [namespace code "Done $winId"]
	set en [entry $winId.entry -textvariable [namespace current]::value]
	bind $en <Return> $exit
	pack $en
	set bt [button $winId.bt -text OK -command $exit]
	pack $bt
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
