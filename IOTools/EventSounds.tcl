# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass EventSounds20180124
oo::class create iotool::$newHelperClass {
    superclass iotool::Helper

    variable useNodes winId modelInst

    self {
	method identify {} {
	    return "Event sounds"
	}
    }

    constructor {modelInst winTitle {state {}}} {
	next $modelInst $winTitle

	set ::helperTable($winId,wantEvents) 1
	set toolbarItems \
	    [list [list new.gif "Clear" [namespace code [list my Clear]]] \
                [list add.gif "Set sound for event" \
		     [namespace code [list my AddEvent]]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
	pack [message $winId.message -aspect 500 -text {}]
	pack [canvas $winId.traces -bg white] -fill both -expand 1
	menu $winId.traces.context -tearoff 0
	$winId.traces.context add command -label "Change sound" \
	    -command [namespace code [list my SetSound]]
	$winId.traces.context add command -label "Remove" \
	    -command [namespace code [list my Remove]]
	CrossPlatformBind $winId.traces {tk_popup %W.context %X %Y}
	set useNodes(lastDisp) [GetModelTime]
	set useNodes(sounds) {}
	$winId.message configure \
	    -text "Use + button to add sounds to model events"
	if {[string length $state]} { ;# we are restoring 
	    #puts $state
	    package require xml
	    set hsfParser [::xml::parser -ignorewhitespace true \
			       -elementstartcommand [namespace code [list my StartElement]] \
			       -characterdatacommand [namespace code [list my Stuff]]]
	    $hsfParser parse $state
	    SetState $winId displaying
	}
    }

    destructor {
	set topNode [my getNode]
	foreach {path act} $useNodes(sounds) {
	    catch {AddWaveCommand $topNode [GetIdFromCaptionPath $path] \
		       "/none/"}
	}
	next
    }

    method IndFromY {} {
	set canvY [expr {[winfo rooty $winId.traces.context] - \
			     [winfo rooty $winId.traces]}]
	return [expr {min(int($canvY/50)*2, [llength $useNodes(sounds)]-2)}]
    }

    method SetSound {} {
	set resonorize [IndFromY]
	set path [lindex $useNodes(sounds) $resonorize]
	set topNode [my getNode]
	set sound [ChooseFile sound.wav "New sound file for $path" 0 $topNode]
	lset useNodes(sounds) [incr resonorize] $sound
	AddWaveCommand $topNode [GetIdFromCaptionPath $path] \
	    [file nativename $sound]
	$winId.traces itemconfig $path&&capt -text "$path ([file tail $sound])"
    }

    method Remove {} {
	set oblit [IndFromY]
	set path [lindex $useNodes(sounds) $oblit]
	$winId.traces delete $path
	set topNode [my getNode]
	AddWaveCommand $topNode [GetIdFromCaptionPath $path] "/none/"
	set useNodes(sounds) [lreplace $useNodes(sounds) $oblit $oblit+1]
	while {$oblit<[llength $useNodes(sounds)]} {
	    $winId.traces move [lindex $useNodes(sounds) $oblit] 0 -50
	    incr oblit 2
	}
    }
    
    method StartElement {name attList args} {
	foreach {att val} $attList {
	    switch $att {
		component {
		    set useNodes(comp) [::gen3d1::VerifyVariables [my getNode] \
					    Sound [list $val]]
		} mode {
		    set useNodes(mode) $val
		}
	    }
	}
    }

    method Stuff {contents} {
	if {[string trim $contents]==""} return ;# failure to ignore whitespace
	if {![llength $useNodes(comp)]} return ;# node exist check failed
	set topNode [my getNode]
	if {$useNodes(mode) eq "relative"} {
	    set shfPath [GetPathChoice .shf $topNode]
	    set soundFile [file normalize [file join $shfPath $contents]]
		    #puts "joined $shfPath and $contents to get $curFolder"
	} else {
	    set soundFile $contents
	}
    my AddSoundFor $topNode [lindex $useNodes(comp) 0] $soundFile
    }

    method Clear {} {
	$winId.traces delete tick
    }
    
    method AddEvent {} {
        $winId.message configure -text "Click on a delayed or limit event to add a sound for it."
        SetState $winId adding_inputs
        $modelInst grabClicks [self]
    }
    
    method Click {path} {
        switch [GetState $winId] {
            adding_inputs {
                if {[lsearch {EVENT SQUIRT} \
			 [$modelInst getModelClass $path]]>-1} {
		    set topNode [my  getNode]
		    set sound [ChooseFile sound.wav "Sound file for $path" 0 \
				   $topNode]
                    $modelInst releaseClicks
                    $winId.message configure -text \
			{Right click on caption to remove.}
		    if {$sound eq ""} {
			return
		    }
		    my AddSoundFor $topNode $path $sound
		    SetState $winId displaying
                }
	    }
	}
    }

method AddSoundFor {topNode path sound} {
	set ytext [expr {[llength $useNodes(sounds)]*25+25}]
	$winId.traces create text 25 $ytext -text "$path ([file tail $sound])" \
	    -fill gray -anchor w -tag [list $path capt]
	lappend useNodes(sounds) $path $sound
	set node [GetIdFromCaptionPath $path]
	AddWaveCommand $topNode $node [file nativename $sound]
	GetModelValue $node ;# to add it to foci
    }

    method PrepareSaveString {} {
	set State "<hsf simile_version=\"$::env(SIMILE_VERSION)\" helper_id=\"[[self] info class]\">\n"
	set shfPath [GetPathChoice .shf [my getNode]]
	foreach {path file} $useNodes(sounds) {	    
	    append State "<sound component=\"$path\" "
	    # puts "::fileutil::relative $shfPath $file"
	    if {[catch {::fileutil::relative $shfPath $file} rel] || \
		    [string first $file $rel]>-1} { ;# rel pointless
		append State "mode=\"absolute\">$file</sound>\n"
	    } else {
		append State "mode=\"relative\">$rel</sound>\n"
	    # will be wrong if modeller changes directory when saving .shf
	    }
	}
	append State </hsf>\n
    }

    method SumVals {vals} {
	#puts "Summing $vals"
	if {[llength $vals]==1} {
	    return $vals
	} else {
	    set res 0
	    foreach {idxs val} $vals {
		set res [expr {$res + [SumVals $val]}]
	    }
	    return $res
	}
    }

    method Reset {} {
	set useNodes(lastDisp) [GetModelTime]
	# Sounds will have been cleared if model rebuilt, due to possible node
	# id changes, so reinstate them
	set topNode [my getNode]
	foreach {path file} $useNodes(sounds) {	    
	    set node [GetIdFromCaptionPath $path]
	    AddWaveCommand $topNode $node [file nativename $file]
	}
    }
    
    method Display {time dispInt step} {
	set count 0
	set rhs [expr {[winfo width $winId.traces]-1}]
	foreach {path sound} $useNodes(sounds) {
	    set node [GetIdFromCaptionPath $path]
	    set numer [lindex [GetModelValue $node] 0]
	    if {[SumVals $numer]} {
		set new [$winId.traces create line $rhs $count \
			     $rhs [expr {$count+50}] \
			     -tag [list $path tick] -fill blue]
		CanvasBindPopup $winId.traces $new "Time $time Value(s) $numer"
#		switch $::tcl_platform(os) {
#		    Linux {
#			set cmd "aplay -q \"$sound\" &"
#		    } Darwin {
#			set cmd "afplay -q \"$sound\" &"
#		    } default { ;# windows
#			set cmd "cmdwav.exe \"%s\" &"
#		    }
#		}
#		eval exec $cmd
	    }
	    incr count 50
	}
	$winId.traces move tick \
	    [expr {($useNodes(lastDisp)-$time)*$rhs/1000.0}] 0
	set useNodes(lastDisp) $time
    }
}
