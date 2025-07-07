#############################################################################
# Reset the random number seed                                              #
#############################################################################

# This allows the user to start the random number generator on a predictable
# sequence

set newHelperClass setrand92383
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper

    self {
	method identify {} {
	    return "Initialize pseudo-random"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	next $modelInst $winTitle

	set ms [message $winId.intro -aspect 400 -text "Enter an integer value for the random number seed:"]
	pack $ms -padx 4 -pady 4
	set exit [list $this Done]
	set en [entry $winId.entry]
	bind $en <Return> $exit
	pack $en -padx 4 -pady 4
	set bt [button $winId.bt -text "Set seed" -default active -width 10 -command $exit]
	pack $bt -padx 4 -pady 4
    }

    method Done {} {
	$modelInst seedRandoms [$winId.entry get]
    }

# No need to do anything when displays update
    method Display {time dispInt step} {
    }
} ;# end of helper class
