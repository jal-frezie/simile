# This is a dead simple helper designed to test the object-oriented helper app
# interface.

set newHelperClass EventSounds20180124
itcl::class similescript::$newHelperClass {
    inherit Helper

    variable useNodes

    proc Identify {} {
	return "Event sounds"
    }

    constructor {modelInst winTitle {state {}}} {
# perverse extra body because base class constructor has args
	Helper::constructor $modelInst $winTitle
    } {
	set ::helperTable($winId,wantEvents) 1
	set toolbarItems \
                [list [list new.gif "Clear" [code $this Clear]] \
                [list add.gif "Set sound for event" \
                [code $this AddEvent]]]
        ::graphtools::MakeToolBar $winId $toolbarItems
	pack [message $winId.message -aspect 500 -text {}]
	pack [canvas $winId.traces -bg white] -fill both -expand 1
	menu $winId.traces.context -tearoff 0
	$winId.traces.context add command -label "Change sound" \
	    -command [code $this SetSound]
	$winId.traces.context add command -label "Remove" \
	    -command [code $this Remove]
	bind $winId.traces <Button-3> {tk_popup %W.context %X %Y}
	set useNodes(lastDisp) [GetModelTime]
	set useNodes(sounds) {}
	$winId.message configure \
	    -text "Use + button to add sounds to model events"
	if {[string length $state]} { ;# we are restoring 
	    #puts $state
	    package require xml
	    set hsfParser [::xml::parser -ignorewhitespace true \
				-elementstartcommand [code $this StartElement] \
				-characterdatacommand [code $this Stuff]]
	    $hsfParser parse $state
	    SetState $winId displaying
	}
    }

    destructor {
	set topNode [$modelInst cget -modelNode]
	foreach {path act} $useNodes(sounds) {
	    catch {AddSoundFor $topNode $path {}}
	}
    }

    method IndFromY {} {
	set canvY [expr {[winfo rooty $winId.traces.context] - \
			     [winfo rooty $winId.traces]}]
	return [expr {min(int($canvY/50)*2, [llength $useNodes(sounds)]-2)}]
    }

    public method SetSound {} {
	set resonorize [IndFromY]
	set path [lindex $useNodes(sounds) $resonorize]
	set topNode [$modelInst cget -modelNode]
	set sound [ChooseFile sound.wav "New sound file for $path" 0 $topNode]
	lset useNodes(sounds) [incr resonorize] $sound
	AddEventCommand $topNode [GetIdFromCaptionPath $path] \
	    [file nativename $sound]
	$winId.traces itemconfig $path&&capt -text "$path ([file tail $sound])"
    }

    public method Remove {} {
	set oblit [IndFromY]
	set path [lindex $useNodes(sounds) $oblit]
	$winId.traces delete $path
	set topNode [$modelInst cget -modelNode]
	AddEventCommand $topNode [GetIdFromCaptionPath $path] {}
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
		    set useNodes(comp) $val
		} mode {
		    set useNodes(mode) $val
		}
	    }
	}
    }

    method Stuff {contents} {
	set topNode [$modelInst cget -modelNode]
	if {$useNodes(mode) eq "relative"} {
	    set shfPath [GetPathChoice .shf $topNode]
	    set soundFile [file normalize [file join $shfPath $contents]]
		    #puts "joined $shfPath and $contents to get $curFolder"
	} else {
	    set soundFile $contents
	}
	AddSoundFor $topNode $useNodes(comp) $soundFile
    }

    method Clear {} {
	$winId.traces delete tick
    }
    
    method AddEvent {} {
        $winId.message configure -text "Click on a delayed or limit event to add a sound for it."
        SetState $winId adding_inputs
        $modelInst GrabClicks $this
    }
    
    public method Click {path} {
        switch [GetState $winId] {
            adding_inputs {
                if {[lsearch {EVENT SQUIRT} \
			 [$modelInst GetModelClass $path]]>-1} {
		    set topNode [$modelInst cget -modelNode]
		    set sound [ChooseFile sound.wav "Sound file for $path" 0 \
				   $topNode]
                    $modelInst ReleaseClicks
                    $winId.message configure -text \
			{Use + button to add sounds to model events Right click on caption to remove.}
		    if {$sound eq ""} {
			return
		    }
		    AddSoundFor $topNode $path $sound
		    SetState $winId displaying
                }
	    }
	}
    }

    public method AddSoundFor {topNode path sound} {
	set ytext [expr {[llength $useNodes(sounds)]*25+25}]
	$winId.traces create text 25 $ytext -text "$path ([file tail $sound])" \
	    -fill gray -anchor w -tag [list $path capt]
	lappend useNodes(sounds) $path $sound
	set node [GetIdFromCaptionPath $path]
	AddEventCommand $topNode $node [file nativename $sound]
	do_for_node $topNode GetModelValue $node ;# to add it to foci
    }

    public method PrepareSaveString {} {
	set State "<hsf simile_version=\"$::env(SIMILE_VERSION)\" helper_id=\"[$this info class]\">\n"
	set shfPath [GetPathChoice .shf [$modelInst cget -modelNode]]
	foreach {path file} $useNodes(sounds) {	    
	    append State "<sound component=\"$path\" "
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

    public method Reset {} {
	set useNodes(lastDisp) [GetModelTime]
    }
    
    public method Display {time dispInt step} {
	set topNode [$modelInst cget -modelNode]
	set count 0
	set rhs [expr {[winfo width $winId.traces]-1}]
	foreach {path sound} $useNodes(sounds) {
	    set node [do_for_node $topNode GetIdFromCaptionPath $path]
	    set numer [lindex [do_for_node $topNode GetModelValue $node] 0]
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
