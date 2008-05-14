# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass AcroExp20080408
itcl::class similescript::$newHelperClass {
    inherit Helper
    public variable table

    proc Identify {} {
	return "Acronym expander"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
        set toolbarItems [list \
                [list clear.gif "Clear" [namespace code "clear $winId"] ] \
                [list add.gif "Add a variable" \
                [namespace code "$this AddVariable"]] \
                [list remove.gif "Remove a variable" \
                [namespace code "RemoveVariable $winId"]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
	CreateTable $winId
	LoadAcros
	if {[string length $state]} { ;# we are restoring 
	    set State $state ;# keep it local
	    Display 0 0 0
	}
    }

    public method LoadAcros {} {
	set acroTable [ChooseFile acronyms.txt "Acronym definition file:" 0 \
			   $winId]
	set acroFile [open $acroTable r]
	while {![eof $acroFile]} {
	    set acros [read $acroFile]
	}
	# Now expand the trickier constructs used in the file
	# first remove all parenthetic comments
	
	regsub -all { \([^\)]+\)} $acros {} acros
	
	# Next, duplicate any line defining multiple acronyms for one expansion
	foreach acro [split $acros \n] {
	    set acexplist [split $acro :]
	    # get rid of 'see...' entries, do not need them to find meanings
	    if {[string equal { see } [string range [lindex $acexplist 1] 0 4]]} continue
	    regsub -all {, } [lindex $acexplist 0] { } shorts
	    foreach short $shorts {
		set newacro [list $short [string range [lindex $acexplist 1] 1 end]]
		lappend newacros $newacro
	    }
	}
	# next, separate definitions combining opposites (or up to 4 variations)
	foreach acro $newacros {
	    foreach short [split [lindex $acro 0] /] posn {0 1 2 3} {
		if {[string equal {} $short]} continue
		lappend allacros [list $short [variant $posn [lindex $acro 1]]]
	    }
	}
	# finally, unpack any 'Same as...' definitions...
	foreach acro $allacros {
	    if {[string match {Same as *} [lindex $acro 1]]} {
		set newKey [lindex [lindex $acro 1] 2] 
		lappend table [list [lindex $acro 0] \
				   [lindex [ExpandAcro $newKey $allacros] 1]]
	    } else {
		lappend table $acro
	    }
	}
    }

    public method AddVariable {} {
	# new instance so request data from model
	$winId.f.message config \
	    -text "Click on model component to list its acronym and expansion"
	$modelInst GrabClicks $this
    }

    public method Click {path} {
	lappend State $path
	$winId.f.message config -text {}
	set capt [split [lindex [split $path /] end] " \n\t"]
	set tabLen [$winId.t cget -rows]
	$winId.t config -rows [expr {$tabLen+1}]
	$winId.t set $tabLen,0 [join $capt { }]
	foreach word $capt {
	    lappend expn [ExpandAll $word $table]
	}
	$winId.t set $tabLen,1 [join $expn { }]
	$winId.t see $tabLen,1
	$modelInst ReleaseClicks
	Display 0 0 0
    }

    public method Display {time dispInt step} {
    }

    proc CreateTable {winId} {
        scrollbar $winId.yscroll -command [list $winId.t yview]
        scrollbar $winId.xscroll -command [list $winId.t xview] \
                -orient horizontal
        pack [frame $winId.f] -fill both
	pack [message $winId.f.message]
        pack $winId.xscroll -side bottom -fill x
        pack $winId.yscroll -side right -fill y
        table $winId.t -rows 1 -cols 2 -variable data$winId -bg \#ffffa0 \
		-titlerows 1 -selectmode extended -sparsearray 0 \
                -rowtagcommand [namespace code rowProc] \
                -coltagcommand [namespace code colProc] \
                -rowseparator \n -colseparator \t \
                -yscrollcommand [list AdjustCanvas $winId t y] \
                -xscrollcommand [list AdjustCanvas $winId f x] \
                -selecttitle true
        
        pack $winId.t -fill both -expand true
	$winId.t set 0,0 Acronym
	$winId.t set 0,1 Expansion
        
        #	$winId.t set 0,0 Time
        #	$winId.t tag cell base 0,0
        #	$winId.t tag raise base
        #	$winId.t tag config base -fg black
        $winId.t tag config title -relief raised
        $winId.t tag config OddRow -bg \#ffffe0
        $winId.t tag config OddCol -bg \#ffffc0
	bind $winId.t <Configure> [namespace code {SplitWidth %W}]
    }
    
    proc rowProc row { if {$row>0 && $row%2} { return OddRow } }
    proc colProc col { if {$col>0 && $col%2} { return OddCol } }

    proc SplitWidth {t} {
	set fullW [winfo width $t]
	$t width 0 [expr {-$fullW/4}] 1 [expr {-3*$fullW/4}]
    }

    proc variant {posn plate} {
	set res {}
	foreach word $plate {
	    set choices [split $word /]
	    if {$posn>=[llength $choices]} {
		lappend res [lindex $choices end]
	    } else {
		lappend res [lindex $choices $posn]
	    }
	}
	return $res
    }

    proc ExpandAll {key table} {
	set remainingKey $key
	set result {}
	while {[string length $remainingKey]} {
	    for {set checkLength 8} {$checkLength} {incr checkLength -1} {
		set foundExp [ExpandAcro [string range $remainingKey 0 \
					     [expr {$checkLength-1}]] $table]
		if {[string length $foundExp]} {
		    append result [lindex $foundExp 1] { }
		    set remainingKey \
			[string range $remainingKey $checkLength end]
		    break
		}
	    }
	    if {!$checkLength} { ;# no expansion found, give up
		return $key
	    }
	}
	return $result
    }

    proc ExpandAcro {key table} {
	return [lsearch -inline $table "$key *"]
    }
}