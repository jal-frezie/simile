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
        foreach node [GetObjectList] {
            if {[string match INPUT [GetModelEval $node]]} {
                set title [GetCaptionPathFromId $node]
                set initVal [InsertSlider $winId $node $title 1]
		set done 1
		if {[string match COMPARTMENT [GetModelClass $node]]} {
		    set compList($node) $initVal
		}
	    }
        }
        if {![info exists done]} {
            kill_helper_window $winId
        } else {
            pack [set bfrm [frame $winId.buttons]] \
                    -fill x
            pack [frame $bfrm.lpad] -side left -fill x -expand true
            
            set opimg [image create photo -file "../Images/Toolbar/open.gif"]
            set svimg [image create photo -file "../Images/Toolbar/save.gif"]
            pack [button $bfrm.merge -compound left -image $opimg -text "Load values" \
                    -command [namespace code MergeInputVals]] \
                    -side left -padx 2 -pady 4
            pack [button $bfrm.save -compound left -image $svimg -text "Save values" \
                    -command [namespace code SaveInputVals]] \
                    -side left -padx 2 -pady 4
            #	pack [frame $bfrm.rpad] -side left -fill x
        }
        set geom [PrefValue custom(slidersPosition) slidersPosition]
#        catch {wm geometry $winId $geom}
    }
    
    proc InsertSlider {winId node title nest} {
	global checkStates
        set initVal [lindex [GetModelValue $node] 0]
        #ShowMessage debug info $def ok
	set levels [lrange [split $title /] 1 end]
	if {$nest} {
	    pack [set f [frame [MakeSubFrames $winId.sliderframe $levels]]] \
                -fill x -expand true
	} else {
	    set f $winId
	}
	set trans [GetFromProlog tk_get_info({},$node,types)]
	switch [GetModelType $node] {
	    FLAG {
	    } ENUMERATED {
		set possVals [lrange [lindex $trans end] 1 end]
	    } default {
		set min [GetMinValue $node]
		set max [GetMaxValue $node]
		set magnitude [expr $max - $min]
		if {[string match INTEGER [GetModelType $node]]} {
		    set spacing 1
		} else {
		    set spacing [expr $magnitude/100.0]
		}
	    }
	}
	set nodeDims [GetModelDims $node]
	for {set outerDims [expr [llength $nodeDims]-1]} \
	    {$outerDims >= 0 && [lindex $nodeDims $outerDims] <= 0} \
	    {incr outerDims -1} {}
        if {$outerDims == -1} {
	    set defVal [GetDefVal $initVal $outerDims 0]
	    switch [GetModelType $node] {
		FLAG {
		pack [checkbutton $f.check -text [lindex $levels end] \
			  -variable checkStates($node) \
			  -offvalue 0 -onvalue 1 -relief ridge]
		set checkStates($node) $defVal
		} ENUMERATED {
		ComboBox $f.combo -values $possVals -editable 0 \
		   -text [lindex $possVals [expr $defVal-1]] \
		   -modifycmd [namespace code "SetChoiceNumber $f.combo $node"]
		pack $f.combo -side right -fill x -expand true
		pack [label $f.caption -text [lindex $levels end]]
		} default {
		scale $f.scale -length 120 -orient h -showvalue false \
                    -sliderlength 10 -from $min -to $max \
                    -tickinterval [expr $magnitude/5.0] \
                    -resolution $spacing \
                    -variable sliderVals($node)
		$f.scale set $defVal
		pack $f.scale -side right -fill x -expand true
		pack [label $f.caption -text [lindex $levels end]]
		pack [entry $f.entry -textvariable sliderVals($node) -width 8]\
		    -padx 1 -pady 1
		}
	    }
	} else {
	    pack [label $f.caption -text [lindex $levels end]]
	    set count [lindex $nodeDims $outerDims]
	    # bodge it to work with record submodels
	    if {[string equal RECORDS $count]} {
		set count [expr [llength $initVal]/2]
	    }
	    for {set index 1} {$count >= $index} {incr index} {
		set defVal [GetDefVal $initVal $outerDims $index]
		if {[llength [lindex $trans $outerDims]]} {
		    set slTitle [lindex [lindex $trans $outerDims] $index]
		} else {
		    set slTitle $index
		}
		switch [GetModelType $node] {
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
			$newScale configure -tickinterval [expr $magnitude/5.0]
		    }
		    }
		}
	    }
        }
	return $initVal
    }

    proc SetChoiceNumber {cbox sub} {
	global comboChoices
	set comboChoices($sub) [expr [lsearch [$cbox cget -values] \
					  [$cbox cget -text]]+1]
    }

    proc MergeInputVals {} {
        global checkStates sliderVals
        set metaFile [ChooseFile inputs.spi "Load input values from:" 0]
        if {[llength $metaFile]} {
            set iStr [open $metaFile r]
            while {[gets $iStr savedValue] != -1} {
                if {[string match : [string range $savedValue end end]]} {
                    set type [string trimright $savedValue :]
                    #ShowMessage debug info "Doing type $type" ok
                } else {
                    set pair [split $savedValue =]
                    set elmt [GetIdFromCaptionPath [lindex $pair 0]]
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

    proc reset {winId} {
	global sliderVals
	variable compList
	foreach node [array names compList] {
	    set compList($node) [lindex [GetModelValue $node] 0]
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

