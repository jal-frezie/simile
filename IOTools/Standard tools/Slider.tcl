# Simple helper app designed for management
# Set position of window on screen JMM
set keyValue slide139

namespace eval slide139 {

# namespace is used to minimize name clashes

proc identify {} {
	return "Slider control"
}

proc initialize {winId} {
    MakeFrames $winId
    set boxCount 0
    foreach node [GetObjectList] {
	if {[string match INPUT [GetModelEval $node]]} {
	    set title [GetCaptionPathFromId $node]
	    if {[string match FLAG [GetModelType $node]]} {
		InsertCheck $winId nodebox[incr boxCount] $node $title
	    } else {	    
		InsertSlider $winId nodebox[incr boxCount] $node $title
	    }
	}
    }
    if {!$boxCount} {
	kill_helper_window $winId
    } else {
	pack [set bfrm [frame $winId.buttons -bd 2 -relief sunken]] \
		-fill x
	pack [frame $bfrm.lpad] -side left -fill x -expand true
	pack [button $bfrm.merge -text "Load file" \
		  -command [namespace code MergeInputVals]] \
		-side left
	pack [button $bfrm.save -text "Save file" \
		  -command [namespace code SaveInputVals]] \
		-side left
	pack [frame $bfrm.rpad] -side left -fill x -expand true
	set_size $winId
    }
    set geom [PrefValue custom(slidersPosition) slidersPosition]
    catch {wm geometry $winId $geom}
}

proc InsertCheck {winId boxname node title} {
    global checkStates
    set def [lindex [GetModelValue $node] 0]
    set levels [lrange [split $title /] 1 end]
    set f [MakeSubFrames $winId.checkframe $levels]
    set count [lindex [GetModelDims $node] 0]
    if {$count == 0} {
	pack [checkbutton $f -text [lindex $levels end] \
		-variable checkStates($node) \
		-offvalue 0 -onvalue 1 -relief ridge]
	set checkStates($node) $def
    } else {
	array set defArr $def
	pack [set checkArr [frame $f]]
	pack [label $checkArr.caption -text [lindex $levels end]]
	for {set index 1} {$count >= $index} {incr index} {
	    pack [checkbutton $checkArr.elt$index \
		    -variable checkStates($node,$index) \
		    -borderwidth 1 -padx 0 -offvalue 0 -onvalue 1] \
		    -side left
	    set checkStates($node,$index) $defArr($index)
	    if {fmod($index,5)==0} {
		$checkArr.elt$index configure -bg blue
	    }
	}
    }
}

proc InsertSlider {winId boxname node title} {
    set min [GetMinValue $node]
    set def [lindex [GetModelValue $node] 0]
    set max [GetMaxValue $node]
#ShowMessage debug info $def ok
    set levels [lrange [split $title /] 1 end]
    pack [set f [frame [MakeSubFrames $winId.sliderframe $levels]]] \
	    -fill x -expand true
    set magnitude [expr $max - $min]
    if {[string match INTEGER [GetModelType $node]]} {
	set spacing 1
    } else {
	set spacing [expr $magnitude/100.0]
    }
    set count [SliderArray $node]
    if {$count == 0} {
	scale $f.scale -length 140 \
		-orient horizontal -showvalue false \
		-sliderlength 10 -from $min -to $max \
		-tickinterval [expr $magnitude/5.0] \
		-resolution $spacing \
		-variable sliderVals($node)
	$f.scale set $def
	pack $f.scale -side right
	pack [label $f.caption -text [lindex $levels end]]
	pack [entry $f.entry -textvariable sliderVals($node) -width 5]
    } else {
	array set defArr $def
	pack [label $f.caption -text [lindex $levels end]]
	for {set elt 1} {$count >= $elt} {incr elt} {
	    pack [frame $f.elt$elt]
	    pack [message $f.elt$elt.id -text $elt] -side left
	    pack [entry $f.elt$elt.val -textvariable sliderVals($node,$elt)] \
		    -side right
	    set newScale $f.elt$elt.scale
	    scale $newScale -length 200 \
		-orient horizontal -showvalue false \
		-sliderlength 10 -from $min -to $max \
		-resolution $spacing \
		-variable sliderVals($node,$elt)
	    $newScale set $defArr($elt)
	    pack $newScale
	}
	$newScale configure -tickinterval [expr $magnitude/5.0]
	# only put legend on bottom one
    }
}

proc MergeInputVals {} {
    global checkStates sliderVals
    set metaFile [ChooseFile inputs.spi "Save input values as:" 0]
    if {[llength $metaFile]} {
	set iStr [open $metaFile r]
	while {[gets $iStr savedValue] != -1} {
	    if {[string match : [string range $savedValue end end]]} {
		set type [string trimright $savedValue :]
ShowMessage debug info "Doing type $type" ok
	    } else {
		set pair [split $savedValue =]
		set elmt [GetIdFromCaptionPath [lindex $pair 0]]
ShowMessage debug info "Setting elmt $elmt" ok
		set arr [lindex $pair 1]
		if {[llength $arr]==1} {
		    set ${type}($elmt) $arr
		} else {
		    foreach {indx val} $arr {
			set ${type}($elmt,$indx) $val
		    }
		}
	    }
	}
    }
}

proc SaveInputVals {} {
    global checkStates sliderVals
    set metaFile [ChooseFile inputs.spi "Save input values as:" 1]
    if {[llength $metaFile]} {
	set iStr [open $metaFile w]

	foreach type {checkStates sliderVals} {
	    set arrs {}
	    puts $iStr ${type}:
	    foreach {elmt val} [array get $type] {
		set id [split $elmt ,]
		if {[llength $id]==2} {
		    set var [lindex $id 0]
		    if {[lsearch $arrs $var]==-1} {
			lappend arrs $var
		    }
		    set ${var}([lindex $id 1]) $val
		} else {
		    puts $iStr [GetCaptionPathFromId $elmt]=$val
		}
	    }
	    foreach arr $arrs {
		puts $iStr [GetCaptionPathFromId $arr]=[array get $arr]
		unset $arr
	    }
	}
	close $iStr
    }
}


proc SliderArray {node} {
# Need last positive val in dim array, or 0 if none
    set retDim 0
    foreach dim [GetModelDims $node] {
	if {$dim>0} {
	    set retDim $dim
	}
    }
    return $retDim
}

proc click {winId node caption} {
}

proc display {winId time display remainder} {
}

} ;# end of namespace

