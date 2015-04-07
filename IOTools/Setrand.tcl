#############################################################################
# Reset the random number seed                                              #
#############################################################################

# This allows the user to start the random number generator on a predictable
# sequence

set newHelperClass setrand92383
itcl::class similescript::$newHelperClass {
    inherit Helper

    proc Identify {} {
	return "Initialize pseudo-random"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	set ms [message $winId.intro -aspect 400 -text "Enter an integer value for the random number seed:"]
	pack $ms -padx 4 -pady 4
	set exit [list $this Done]
	set en [entry $winId.entry -textvariable [namespace current]::value]
	bind $en <Return> $exit
	pack $en -padx 4 -pady 4
	set bt [button $winId.bt -text "Set seed" -default active -width 10 -command $exit]
	pack $bt -padx 4 -pady 4
    }

    public method Done {} {
	variable value
	$modelInst SeedRandoms $value
    }

# No need to do anything when displays update
    public method Display {time dispInt step} {
    }
} ;# end of helper class
