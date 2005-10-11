# Simple helper app designed for management
# Set position of window on screen JMM
set keyValue slide139

namespace eval slide139 {
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "Slider control"
    }
    
    proc initialize {winId} {
	variable compList
	if {[info exists compList]} {
	    unset compList
	}

	menu $winId.slidervars -tearoff 0

	set toolbarItems \
	    [list [list new.gif "Clear" [namespace code "Clear $winId"]] \
		 [list add.gif "Add variables" \
		      [namespace code "AddVariable $winId"]] \
		 [list remove.gif "Remove a variable" \
		      [namespace code "RemoveVariable $winId"]] \
		 [list slider.gif "Add all variables" \
		      [namespace code "AddAllVariables $winId /"]]]
	
	::graphtools::MakeToolBar $winId $toolbarItems
	pack [message $winId.intro -aspect 800] -fill x

        MakeFrames $winId
	SetState $winId {}
	set geom [PrefValue custom(slidersPosition) slidersPosition]
#        catch {wm geometry $winId $geom}
    }

# Do not remove sliders when clearing data from displays
    proc clear {winId} {
    }

    proc Clear {winId} {
	foreach current [winfo children $winId.sliderframe] {
	    destroy $current
	}
	$winId.slidervars delete 0 end
	SetState $winId {}
    }

    proc Restore {winId} {
	set oldCapts [GetState $winId]
        initialize $winId
	foreach flatCapt $oldCapts {
	    set oldCapt [RestoreCrs $flatCapt]
	    InsertSlider $winId [GetIdFromCaptionPath $oldCapt] $oldCapt 1
	}
    }

    proc AddVariable {winId} {
	$winId.intro configure -text "Click on an input variable to add a slider for it, or on a submodel to add sliders for all input variables inside it."
	GrabClicks $winId
    }

    proc RemoveVariable { winId } {
        tk_popup $winId.slidervars \
	    [winfo pointerx $winId] [winfo pointery $winId]
    }

proc click {winId node caption} {
	variable useNodes
	
	set fullCapt [GetCaptionPathFromId $node]
	if {[string equal SUBMODEL [GetModelClass $node]]} {
	    AddAllVariables $winId $fullCapt
	} else {
	    InsertSlider $winId $node $fullCapt 1
	}
	$winId.intro configure -text {}
	ReleaseClicks $winId
    }

    proc AddAllVariables {winId prefix} {
        foreach node [GetObjectList] {
	    set title [GetCaptionPathFromId $node]
	    if {[string first $prefix $title]} {
		continue
	    }
	    set initVal [InsertSlider $winId $node $title 1]
	    if {[llength $initVal]} {
		set done 1
		if {[string match COMPARTMENT \
			 [GetModelClass $node]]} {
		    set compList($node) $initVal
		}
	    }
	}
        if {![info exists done]} {
            $winId.intro configure -text "There are no variable parameters in this model which can be set by sliders, check boxes or pulldown lists. Note that these tools cannot be used on multidimensional parameters."
        }
    }
    proc InsertSlider {winId node title nest} {
	global checkStates comboChoices
	if {![string match INPUT [GetModelEval $node]]} {
	    return {}
	}
        set initVal [lindex [GetModelValue $node] 0]
        #ShowMessage debug info $def ok
	set levels [split $title /]
	set trans [GetTransTable $node]
	set type [GetModelType $node] 
	switch -glob $type {
	    FLAG {
	    } ENUM(*) {
		set possVals [lrange [lindex $trans end] 1 end]
	    } default {
#		set min [GetMinValue $node]
#		set max [GetMaxValue $node]
#		set magnitude [expr $max - $min]
		::graphtools::AxisRound [GetMinValue $node] \
		    [GetMaxValue $node] 0 min max gap s1 s2 s3 s4
		if {[string match INTEGER [GetModelType $node]]} {
		    set spacing 1
		} else {
		    set spacing [expr $gap/100.0]
		}
	    }
	}
	set nodeDims [GetModelDims $node]
	set outerDims 0
	while {$outerDims<[llength $nodeDims]} {
	    set latestDim [lindex $nodeDims $outerDims]
	    if {[string equal START_VM $latestDim]} {
		set outerDims [lsearch -start $outerDims $nodeDims END_VM]
	    }
	    if {[string is integer $latestDim] && $latestDim>0} {
#		if {[info exists useDim]} {
		    # Cannot display sliders, too many dimensions
# even if too many dims, innermost array is copied over others
#		    return {}
#		} else {
		    set useDim $outerDims
#		}
	    }
	    incr outerDims
	}
	if {$nest} {
	    set f [MakeSubFrames $winId $winId.sliderframe \
				    $levels [namespace current] 0]
	    if {[winfo exists $f]} {
		$winId.c.canvas see $f
		return
	    } else {
		pack [frame $f] -fill x -expand true
		SetState $winId [concat [GetState $winId] \
				     [list [StripCrs $title]]]
	    }
	} else {
	    set f $winId
	}
	$winId.slidervars add command -label $title \
	    -command [namespace code [list Remove $winId $title]]
        if {![info exists useDim]} {
	    set defVal [GetDefVal $initVal -1 0]
	    switch -glob $type {
		FLAG {
		pack [checkbutton $f.check -text [lindex $levels end] \
			 -variable checkStates($node) \
			 -command [namespace code [list CheckStateToC $node]] \
			 -offvalue 0 -onvalue 1 -relief ridge]
		set checkStates($node) $defVal
		} ENUM(*) {
		ComboBox $f.combo -values $possVals -editable 0 \
		    -text [lindex $possVals [expr $defVal-1]] \
		    -textvariable comboTypes($node) \
		    -modifycmd [namespace code [list SetChoiceNumber $f.combo $node]]
		pack $f.combo -side right -fill x -expand true
		pack [label $f.caption -text [lindex $levels end]]
		set comboChoices($node) $defVal
		} default {
		scale $f.scale -length 120 -orient h -showvalue false \
                    -sliderlength 10 -from $min -to $max \
                    -tickinterval $gap -resolution $spacing \
                    -variable sliderVals($node) \
		    -command [namespace code [list SetArrayIfUsed $node {}]]
		    if {[llength $defVal]} {
			$f.scale set $defVal
		    }
		pack $f.scale -side right -fill x -expand true
		pack [label $f.caption -text [lindex $levels end]]
		pack [entry $f.entry -textvariable sliderVals($node) -width 8]\
		    -padx 1 -pady 1
		bind $f.entry <KeyRelease> [namespace code \
						[list SliderValsToC $node]]
		}
	    }
	    return $defVal
	} else {
#	    set useTrans [lindex $trans $useDim]
	    pack [label $f.caption -text [lindex $levels end]]
	    set count [lindex $nodeDims $useDim]
	    # bodge it to work with record submodels
	    if {[string equal RECORDS $count]} {
		set count [expr [llength $initVal]/2]
	    }
	    for {set index 1} {$count >= $index} {incr index} {
		set defVal [GetDefVal $initVal $useDim $index]
		if {[llength [lindex $trans $useDim]]} {
		    set slTitle [lindex [lindex $trans $useDim] $index]
		} else {
		    set slTitle $index
		}
		switch -glob $type {
		    FLAG {
		    set line [expr ($index+9)/10]
		    set row $f.row$line
		    if {![winfo exists $row]} {
			pack [frame $row]
			pack [label $row.low -text $index] -side left
			pack [label $row.high -text [min 10*$line $count]] \
				  -side right
		    }
		    pack [checkbutton $row.elt$index -borderwidth 1 \
			      -variable checkStates($node,$index) \
			      -command [namespace code [list CheckStateToC \
							    $node $index]] \
			      -padx 0 -offvalue 0 -onvalue 1] -side left
		    set checkStates($node,$index) $defVal
		    BindPopup $row.elt$index "For $slTitle"
		    set newbg white
		    if {fmod($line,2)==0} {
			set newbg \#e0e0ff
		    }
		    if {fmod($index,2)==0} {
			set newbg \#c0c0ff
		    }
		    $row.elt$index configure -bg $newbg
		    } ENUM(*) {
		    pack [frame $f.elt$index] -fill x -expand true
		    ComboBox $f.elt$index.c -values $possVals -editable 0 \
			-text [lindex $possVals [expr $defVal-1]] \
			-textvariable comboTypes($node,$index) \
			-modifycmd [namespace code [list SetChoiceNumber \
							$f.elt$index.c $node $index]]
		    pack $f.elt$index.c -side right -fill x -expand true
		    pack [label $f.elt$index.id -text $slTitle -width 10] \
			-side left
		    set comboChoices($node,$index) $defVal
		    } default {
		    pack [frame $f.elt$index] -fill x -expand true
		    pack [label $f.elt$index.id -text $slTitle -width 10] \
			-side left
		    pack [entry $f.elt$index.val \
			      -textvariable sliderVals($node,$index) \
			      -width 8] -side left -padx 1 -pady 1
		    bind $f.elt$index.val <KeyRelease> \
			[namespace code [list SliderValsToC $node $index]]
		    set newScale $f.elt$index.scale
		    scale $newScale -length 180 \
                        -orient horizontal -showvalue false \
                        -sliderlength 10 -from $min -to $max \
                        -resolution $spacing \
                        -variable sliderVals($node,$index) \
			-command [namespace code [list SetArrayIfUsed $node $index]]
		    if {[llength $defVal]} {
			$newScale set $defVal
		    }
		    pack $newScale -fill x -expand true
		    # only put legend on bottom one
		    if {$count==$index} {
			$newScale configure -tickinterval $gap
		    }
		    }
		}
		lappend allVals $index $defVal
	    }
	    return $allVals
        }
    }

    proc Remove {winId title} {
        set levels [split $title /]
	set f [MakeSubFrames $winId $winId.sliderframe \
		   $levels [namespace current] 0]
	Prune $winId $f
	set oldState [GetState $winId]
	set wipqosn [lsearch $oldState [StripCrs $title]]
	SetState $winId [lreplace $oldState $wipqosn $wipqosn]
	$winId.slidervars delete $title
    }

    proc Prune {winId tree} {
	set up [winfo parent $tree]
	destroy $tree
	if {![string equal ${winId}.sliderframe $up]} {
	    foreach remain [winfo children $up] {
		set box [winfo name $remain]
		if {[string match box* $box] || [string match frame* $box]} {
		    return
		}
	    }
	    Prune $winId $up
	}
    }

    proc SliderValsToC {node args} {
	global sliderVals
	set sub [join [concat [list $node] $args] ,]
	SetArrayIfUsed $node $args $sliderVals($sub)
    }

    proc CheckStateToC {node args} {
	global checkStates
	set sub [join [concat [list $node] $args] ,]
	SetArrayIfUsed $node $args $checkStates($sub)
    }

    proc SetArrayIfUsed {node indices value} {
    	if {[RunningInC $::myNode]} {
	    c_setparamelement $node $indices $value
	}
    }

    proc SetChoiceNumber {cbox node args} {
	global comboChoices
	if {[RunningInC $::myNode]} {
	    c_setparamelement $node $args \
		[expr [lsearch [$cbox cget -values] [$cbox cget -text]]+1]
	} else {
	    set sub [join [concat $node $args] ,]
	    set comboChoices($sub) [expr [lsearch [$cbox cget -values] \
					      [$cbox cget -text]]+1]
	}
    }

# If we load a file containing slider values, we only want to set the sliders
# that are mentioned in that file. so MergeParams needs to make a list of them

    proc Open {winId smPath} {
	global helperTable whichParamsAffected
	set metaFile [ChooseFile params.spf "Load parameters from:" 0]
	if {[llength $metaFile]} {
	    set topNode $helperTable($winId,whichModel)
	    ZapParams $topNode $smPath $metaFile
	}
    }

    proc Save {winId smPath} {
	global helperTable simtmpdir env
#puts "Saving submodel $smPath inputs"
        set metaFile [ChooseFile inputs.spf "Save input values as:" 1]
        if {[llength $metaFile]} {
	    set part [file join $simtmpdir temp_out.spf]
            set iStr [open $part w]

	    set topNode $helperTable($winId,whichModel)
	    set snip [string length $smPath]
	    foreach node [GetObjectList] {
		set title [GetCaptionPathFromId $node]
#puts "trimming $smPath from $title"
		if {!($snip && [string last $smPath $title [expr $snip-1]])} {
		    set titleTail [string range $title $snip end]
		    set trans [GetTransTable $node]
# Below should be reimplemented in this interpreter somehow
		    upvar \#0 [InputVarFor $topNode $node] collectPt
#puts "Available values: [array get collectPt]"
		    
		    foreach {elmt val} [array get collectPt $node*] {
#puts "got pair $elmt $val"
			set id [split $elmt ,]
			if {[llength $id]==2} {
			    lappend arr($node) [lindex $id 1] $val
			} else {
			    puts $iStr $titleTail=literal=[list NOW [TransEnums $trans $val]]
			}
		    }
		    foreach {arrNode vList} [array get arr] {
			puts $iStr $titleTail=literal=[list NOW [TransEnums $trans $vList]]
		    }
		    if {[info exists arr]} {unset arr}
		}
	    }
	    close $iStr
	    set PartType "application/x-simile"
	    set Description "Simile parameter file"
	    set style attachment
	    set newMime [mime::initialize -canonical $PartType \
			 -header [list "Content-Disposition" $style] \
			 -header [list "Content-Description" $Description] \
			 -header [list "Simile-Version" $env(SIMILE_VERSION)] \
			 -header [list "Simile-Origin" input-param-tool] \
			 -file $part]
	    set stream [NetOpen $metaFile w]
	    fconfigure $stream -translation binary
	    mime::copymessage $newMime $stream
        # clean everything up
	    close $stream
	    mime::finalize $newMime
	    file delete $part
	}
    }

    proc GetDefVal {vals levels index} {
#ShowMessage debug info "GetDefVal $vals $levels $index" ok
	if {[llength  $vals]==1} {
	    return $vals
	} elseif {$levels==0 && $index>0} {
	    array set subvals $vals
	    if {[info exists subvals($index)]} {
		return [GetDefVal $subvals($index) 0 0]
	    }
	} else {
	    incr levels -1
	    foreach {indx val} $vals {
		set subResult [GetDefVal $val $levels $index]
		if {[llength $subResult]} {
		    return $subResult
		}
	    }
	}
	return {}
    }
 
# No need to define click because we never request them   
#    proc click {winId node caption} {
#    }

# after reset, record the positions of compartment sliders so they can be put 
# back there while model is running (see below)

    proc reset {winId} {
	global sliderVals
	variable compList
	foreach node [array names compList] {
	    if {[info exists sliderVals($node)]} {
		# it's a single compartment
		set compList($node) $sliderVals($node)
	    } else {
		unset compList($node)
		foreach {indxSub val} [array get sliderVals $node,*] {
		    set indx [lindex [split $indxSub ,] 0]
		    lappend compList($node) $indx $val
		}
	    }
	}
    }

# purpose of display proc here is only to stop compartment sliders
# being altered while model is running, since they refer only to
# initial values. Also we want to update other input tools to reflect
# values from time series data
    
    proc display {winId time display remainder} {
	foreach valGroup {sliderVals checkStates comboTypes} {
	    upvar \#0 $valGroup valArray
	
	    foreach controlVal [array names valArray] {
		set ids [split $controlVal ,]
		set node [lindex $ids 0]
		if {[info exists compList($node)]} {
		    if {[llength $compList($node)]==1} {
			set valArray($node) $compList($node)
		    } else {
			foreach {indx val} $compList($node) {
			    set valArray($node,$indx) $val
			}
		    }		
		    continue
		}
		set data [lindex [GetModelValue $node] 0]
		set indx [lindex $ids 1]
		if {[string length $indx]} {
		    while {[llength [lindex $data 1]]!=1} {
			set data [lindex $data 1]
		    }
		    set data [lindex $data [expr {2*$indx-1}]]
		}
		if {[string length $data]} {
		    if {[string equal comboTypes $valGroup]} {
			set data [lindex [lindex [GetTransTable $node] end] \
				      $data]
		    }
		    set valArray($controlVal) $data
		}
	    }
	}
    }
} ;# end of namespace
