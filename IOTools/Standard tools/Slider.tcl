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
        MakeFrames $winId
        foreach node [GetObjectList $winId] {
	    set title [GetCaptionPathFromId $winId $node]
	    set initVal [InsertSlider $winId $node $title 1]
	    if {[llength $initVal]} {
		set done 1
		if {[string match COMPARTMENT \
			 [GetModelClass $winId $node]]} {
		    set compList($node) $initVal
		}
	    }
	}
        if {![info exists done]} {
            pack [message $winId.message -text "There are no variable parameters in this model which can be set by sliders, check boxes or pulldown lists. Note that these tools cannot be used on multidimensional parameters."]
        }
	set geom [PrefValue custom(slidersPosition) slidersPosition]
#        catch {wm geometry $winId $geom}
    }

    proc Restore {winId} {
        initialize $winId
    }

    proc InsertSlider {winId node title nest} {
	global checkStates comboChoices
	if {![string match INPUT [GetModelEval $winId $node]]} {
	    return {}
	}
        set initVal [lindex [GetModelValue $winId $node] 0]
        #ShowMessage debug info $def ok
	set levels [split $title /]
	set trans [GetTransTable $node]
	set type [GetModelType $winId $node] 
	switch $type {
	    FLAG {
	    } ENUMERATED {
		set possVals [lrange [lindex $trans end] 1 end]
	    } default {
#		set min [GetMinValue $winId $node]
#		set max [GetMaxValue $winId $node]
#		set magnitude [expr $max - $min]
		::graphtools::AxisRound [GetMinValue $winId $node] \
		    [GetMaxValue $winId $node] 0 min max gap s1 s2 s3 s4
		if {[string match INTEGER [GetModelType $winId $node]]} {
		    set spacing 1
		} else {
		    set spacing [expr $gap/100.0]
		}
	    }
	}
	set nodeDims [GetModelDims $winId $node]
	set outerDims 0
	while {$outerDims<[llength $nodeDims]} {
	    if {[lindex $nodeDims $outerDims]>0} {
		if {[info exists useDim]} {
		    # Cannot display sliders, too many dimensions
		    return {}
		} else {
		    set useDim $outerDims
		}
	    }
	    incr outerDims
	}
	if {$nest} {
	    pack [set f [frame [MakeSubFrames $winId $winId.sliderframe \
				    $levels [namespace current] 0]]] \
		-fill x -expand true
	} else {
	    set f $winId
	}
        if {![info exists useDim]} {
	    set defVal [GetDefVal $initVal -1 0]
	    switch $type {
		FLAG {
		pack [checkbutton $f.check -text [lindex $levels end] \
			  -variable checkStates($node) \
			  -offvalue 0 -onvalue 1 -relief ridge]
		set checkStates($node) $defVal
		} ENUMERATED {
		ComboBox $f.combo -values $possVals -editable 0 \
		    -text [lindex $possVals [expr $defVal-1]] \
		    -modifycmd [namespace code [list SetChoiceNumber $f.combo $node]]
		pack $f.combo -side right -fill x -expand true
		pack [label $f.caption -text [lindex $levels end]]
		set comboChoices($node) $defVal
		} default {
		scale $f.scale -length 120 -orient h -showvalue false \
                    -sliderlength 10 -from $min -to $max \
                    -tickinterval $gap -resolution $spacing \
                    -variable sliderVals($node)
		$f.scale set $defVal
		pack $f.scale -side right -fill x -expand true
		pack [label $f.caption -text [lindex $levels end]]
		pack [entry $f.entry -textvariable sliderVals($node) -width 8]\
		    -padx 1 -pady 1
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
		switch $type {
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
		    } ENUMERATED {
		    pack [frame $f.elt$index] -fill x -expand true
		    ComboBox $f.elt$index.c -values $possVals -editable 0 \
			-text [lindex $possVals [expr $defVal-1]] \
			-modifycmd [namespace code "SetChoiceNumber \
                             $f.elt$index.c $node,$index"]
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
		    set newScale $f.elt$index.scale
		    scale $newScale -length 180 \
                        -orient horizontal -showvalue false \
                        -sliderlength 10 -from $min -to $max \
                        -resolution $spacing \
                        -variable sliderVals($node,$index)
		    $newScale set $defVal
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

    proc SetChoiceNumber {cbox sub} {
	global comboChoices
	set comboChoices($sub) [expr [lsearch [$cbox cget -values] \
					  [$cbox cget -text]]+1]
    }

    proc oldOpen {winId smPath} {
        global checkStates sliderVals
        set metaFile [ChooseFile inputs.spf "Load input values from:" 0]
        if {[llength $metaFile]} {
            set iStr [open $metaFile r]
            while {[gets $iStr savedValue] != -1} {
                if {[string match : [string range $savedValue end end]]} {
                    set type [string trimright $savedValue :]
                    #ShowMessage debug info "Doing type $type" ok
                } else {
                    set pair [split $savedValue =]
                    set elmt [GetIdFromCaptionPath $winId \
				  $smPath[lindex $pair 0]]
                    #ShowMessage debug info "Setting elmt $elmt" ok
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
    
    proc oldSave {winId smPath} {
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
                         PutRelSliderContents $winId $iStr $smPath $elmt $val
                    }
                }
                foreach arr $arrs {
		    PutRelSliderContents $winId $iStr $smPath $arr [array get $arr]
                    unset $arr
                }
            }
            close $iStr
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
	    foreach node [GetObjectList $winId] {
		set title [GetCaptionPathFromId $winId $node]
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
	if {$levels==0 && $index>0} {
	    array set subvals $vals
	    return [GetDefVal $subvals($index) 0 0]
	} elseif {[llength  $vals]==1} {
	    return $vals
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
# initial values
    
    proc display {winId time display remainder} {
	global sliderVals
	variable compList
	foreach node [array names compList] {
	    if {[llength $compList($node)]==1} {
		set sliderVals($node) $compList($node)
	    } else {
		foreach {indx val} $compList($node) {
		    set sliderVals($node,$indx) $val
		}
	    }		
	}
    }
    
} ;# end of namespace

