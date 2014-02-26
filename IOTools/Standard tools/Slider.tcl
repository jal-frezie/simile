# Simple helper app designed for management
# Set position of window on screen JMM
set keyValue slide139

namespace eval slide139 {
    
    # namespace is used to minimize name clashes
    
    proc identify {} {
        return "Slider control"
    }
    
    proc initialize {winId} {
        #	variable compList
        #	if {[info exists compList]} {
        #	    unset compList
        #	}
        
        menu $winId.slidervars -tearoff 0
        
        set toolbarItems \
                [list [list new.gif "Clear" [namespace code "Clear $winId"]] \
                [list add.gif "Add variables" \
                [namespace code "AddVariable $winId"]] \
                [list remove.gif "Remove a variable" \
                [namespace code "RemoveVariable $winId"]] \
                [list slider.gif "Add all variables" \
                [namespace code "AddAllVariables $winId"]]]
        
        ::graphtools::MakeToolBar $winId $toolbarItems
        pack [message $winId.intro -aspect 800] -fill x
        
        set ::topSFrame($winId) [DIYMakeFrames $winId]
        SetState $winId {}
        set geom [PrefValue custom(slidersPosition) slidersPosition]
        #        catch {wm geometry $winId $geom}
    }
    
    # Do not remove sliders when clearing data from displays
    proc clear {winId} {
    }
    
    proc Clear {winId} {
        foreach current [winfo children $::topSFrame($winId)] {
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
        set fullCapt [GetCaptionPathFromId $node]
        if {[string equal SUBMODEL [GetModelClass $node]]} {
            if {[AddAllVariablesInSubmodel $winId $fullCapt]} {
		ReleaseClicks $winId
	    }
        } elseif {[llength [InsertSlider $winId $node $fullCapt 1]]} {
            $winId.intro configure -text {}
            ReleaseClicks $winId
        } else {
            $winId.intro configure -text "This value cannot be set by sliders, check boxes or pulldown lists. Note that these tools cannot be used on derived values, constants or multidimensional parameters."
        }
    }
    
    proc AddAllVariables {winId} {
	global helperTable

	set helperTable(beingCalled) $helperTable($winId,whichInstance)
	AddAllVariablesInSubmodel $winId /
	set helperTable(beingCalled) {}
    }

    proc AddAllVariablesInSubmodel {winId prefix} {
        foreach node [GetObjectList] {
            set title [GetCaptionPathFromId $node]
            if {[string first $prefix $title] || \
                        ![string equal INPUT [GetModelEval $node]]} {
                continue
            }
            set initVal [InsertSlider $winId $node $title 1]
            if {[llength $initVal]} {
                set done 1
                #		if {[string match COMPARTMENT \
                #			 [GetModelClass $node]]} {
                #	            set compList($node) $initVal
                #		}
            }
        }
        if {[info exists done]} {
            $winId.intro configure -text {}
            return yes
        } else {
            $winId.intro configure -text "There are no more parameters in this model which can be set by sliders, check boxes or pulldown lists. Note that these tools cannot be used on multidimensional parameters."
	    return no
	}
    }
    proc InsertSlider {winId node title nest} {
	global widgetSeln sliderDoes

	set sliderDoes($title,node) $node
	if {[RunningInC $::myNode]} {
	    set node [GetModelBase $node] ;# ghosts not listed in debug mode
	}
        set parmType [GetModelEval $node]
        set fixed [lsearch {INPUT TABLE} $parmType]
        if {$fixed==-1} {
            return {}
        }
        set initVal [lindex [GetModelValue $node] 0]
        #ShowMess debug info $def ok
        set levels [split $title /]
        set trans [GetTransTable $node]
        set type [GetModelType $node]
	set class [GetModelClass $node]
	set sliderDoes($title,type) $type
	set sliderDoes($title,class) $class
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
                if {[string match INTEGER $type]} {
                    set spacing 1
		    set gap [expr {max($gap, $spacing)}]
                } else {
                    set spacing [expr $gap/100.0]
                }
            }
        }
        set sliderDoes($title,dims) [GetModelDims $node]
        set useDim [FindUseDim $sliderDoes($title,dims)]
        if {$nest} {
            set f [MakeSubFrames $winId $::topSFrame($winId) \
                    $levels [namespace current] 0]
            if {[winfo exists $f]} {
		ScrollToSee $winId.c.canvas $f
                return already_up
            } else {
                pack [frame $f] -fill x -expand true
		set lbg [[winfo parent $f].head cget -bg]
		set dbg [Gradient $lbg $f 15]
		set fbg [Gradient $lbg $f -50]
                $f configure -bg $lbg
		SetState $winId [concat [GetState $winId] \
                        [list [StripCrs $title]]]
            }
        } else {
            set f $winId
        }
        $winId.slidervars add command -label $title \
                -command [namespace code [list Remove $winId $title]]
        if {$useDim==-1} {
            set defVal [GetDefVal $initVal -1 0]
	    if {![set live [expr {$class ne "EVENT"}]]} {
		set holder [winfo parent $f]
		pack [::ttk::button $f.zap -style style$holder \
			  -image $::iconImages(zap) \
			  -command [namespace code \
					[list SliderEvent $node {}]]] \
		    -side right
		BindPopup $f.zap [tr. {Trigger an event now with this magnitude}]
	    }
            switch -glob $type {
                FLAG {
                    pack [checkbutton $f.check -text [lindex $levels end] \
			      -offvalue 0 -onvalue 1 -relief ridge \
			      -variable widgetSeln($node)]
                    set comment [do_in_editor GetFromProlog tk_get_info('$winId',$node,comment)]
                    BindPopup $f.check "$comment"
		    if {$live} {
			$f.check configure -command \
			    [namespace code [list WidgetSelnToC $node $fixed]]
		    }
		} ENUM(*) {
#		    ComboBox $f.combo -values $possVals -editable 0 \
#			-text [lindex $possVals [expr $defVal-1]] \
#			-textvariable comboTypes($node) \
#			-modifycmd [namespace code [list SetChoiceNumber $f.combo $node $fixed]]
#                    set bxMenu [menu $f.combomenu -tearoff 0]
#                    foreach choice $possVals {
#                        $bxMenu add command -label $choice -command \
#			    [namespace code [list SetChoiceNumber $f.combo \
#						 $node $fixed $choice $live]]
#                    }
#                    ::ttk::menubutton $f.combo -menu $bxMenu
#                    $bxMenu invoke [expr $defVal-1]
		    ttk::combobox $f.combo -values $possVals -state readonly
		    $f.combo current [expr $defVal-1]
		    bind $f.combo <<ComboboxSelected>> [namespace code \
			[list SetChoiceNumber $f.combo $node $fixed $live]]
                    pack $f.combo -side right -fill x -expand true
                    pack [label $f.caption -text [lindex $levels end] -width 12]
                } default {
                    scale $f.scale -length 120 -orient h -showvalue false \
			-sliderlength 10 -from $min -to $max \
			-tickinterval $gap -resolution $spacing \
			-bg $lbg -troughcolor $dbg -activebackground $fbg \
			-variable widgetSeln($node)
                    pack $f.scale -side right -fill x -expand true
                    pack [label $f.caption -text [lindex $levels end] \
			      -bg $lbg -width 12]
                        
                    pack [entry $f.entry -textvariable widgetSeln($node) \
			      -width 8] -padx 1 -pady 1
		    if {$live} {
			$f.scale configure -command [namespace code \
					  [list SetArrayIfUsed $node $fixed {}]]
			bind $f.entry <KeyRelease> \
                            [namespace code [list WidgetSelnToC $node $fixed]]
		    }
                }
	    }
	    set widgetSeln($node) $defVal
            set allVals $defVal
	    } else {
            #	    set useTrans [lindex $trans $useDim]
	    if {[string equal EVENT $class]} {
		set holder [winfo parent $f]
		pack [::ttk::button $f.zap -style style$holder \
			  -image $::iconImages(zap) \
			  -command [namespace code [list Rock]]] -side right
		BindPopup $f.zap [tr. {Trigger an event now with these magnitudes}]
	    }
            pack [label $f.caption -text [lindex $levels end] \
			      -bg $lbg -width 12]
            set count [lindex $sliderDoes($title,dims) $useDim]
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
                            pack [label $row.high 
				  -text [expr {min(10*$line,$count)}]] \
                                    -side right
                        }
                        pack [checkbutton $row.elt$index -borderwidth 1 \
				  -variable widgetSeln($node,$index) -command \
				  [namespace code [list WidgetSelnToC \
						       $node $fixed $index]] \
				  -padx 0 -offvalue 0 -onvalue 1] -side left
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
#			ComboBox $f.elt$index.c -values $possVals -editable 0 \
#			    -text [lindex $possVals [expr $defVal-1]] \
#			    -textvariable comboTypes($node,$index) \
#			    -modifycmd [namespace code [list SetChoiceNumber \
#							    $f.elt$index.c $node $fixed $index]]
#                        set bxMenu [menu $f.elt$index.cmenu -tearoff 0]
#                        foreach choice $possVals {
#                            $bxMenu add command -label $choice -command \
#				[namespace code [list SetChoiceNumber \
#						     $f.elt$index.c $node \
#						     $fixed $choice 1 $index]]
#                            
#                        }
#                        ::ttk::menubutton $f.elt$index.c -menu $bxMenu
#                        $bxMenu invoke [expr $defVal-1]
			ttk::combobox $f.elt$index.c -values $possVals \
			    -state readonly
			$f.elt$index.c current [expr $defVal-1]
			bind $f.elt$index.c <<ComboboxSelected>> \
			    [namespace code [list SetChoiceNumber \
						 $f.elt$index.c \
						 $node $fixed 1 $index]]
                        pack $f.elt$index.c -side right -fill x -expand true
                        pack [label $f.elt$index.id -text $slTitle -width 10] \
                                -side left
                    } default {
                        pack [frame $f.elt$index] -fill x -expand true
                        pack [label $f.elt$index.id -text $slTitle \
			      -bg $lbg -width 10] -side left
                        pack [entry $f.elt$index.val \
                                -textvariable widgetSeln($node,$index) \
                                -width 8] -side left -padx 1 -pady 1
                        bind $f.elt$index.val <KeyRelease> \
                                [namespace code [list WidgetSelnToC $node \
						     $fixed $index]]
                        set newScale $f.elt$index.scale
                        scale $newScale -length 180 \
			    -orient horizontal -showvalue false \
			    -sliderlength 10 -from $min -to $max \
			    -resolution $spacing \
			    -bg $lbg -troughcolor $dbg -activebackground $fbg \
			    -variable widgetSeln($node,$index) \
			    -command [namespace code [list SetArrayIfUsed \
							  $node $fixed $index]]
                        pack $newScale -fill x -expand true
                        # only put legend on bottom one
                        if {$count==$index} {
                            $newScale configure -tickinterval $gap
                        }
                    }
                }
		set widgetSeln($node,$index) $defVal
                lappend allVals $index $defVal
            }
        }
	if {[winfo exists $f.caption]} {
	    set nodeDims [TransBounds $trans $sliderDoes($title,dims)]
	    set dimList [MakeDimsLegible $nodeDims $type]
            set comment [do_in_editor GetFromProlog \
			     tk_get_info('$winId',$node,comment)]
            BindPopup $f.caption "[lindex $levels end] ($dimList)" $comment
	}
	return $allVals
    }
    
    proc FindUseDim {nodeDims} {
        set useDim -1
        set outerDims 0
        while {$outerDims<[llength $nodeDims]} {
            set latestDim [lindex $nodeDims $outerDims]
            if {[string equal START_VM $latestDim]} {
                set outerDims [lsearch -start $outerDims $nodeDims END_VM]
            }
            if {[string is integer $latestDim] && $latestDim>0 || \
		    [string equal RECORDS $latestDim]} {
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
        return $useDim
    }
    
    proc Remove {winId title} {
        set levels [split $title /]
        set f [MakeSubFrames $winId $::topSFrame($winId) \
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
        if {![string equal $::topSFrame($winId) $up]} {
            foreach remain [winfo children $up] {
                set box [winfo name $remain]
                if {[string match box* $box] || [string match frame* $box]} {
                    return
                }
            }
            Prune $winId $up
        }
    }
    
    proc WidgetSelnToC {node fixed args} {
        global widgetSeln
        set sub [join [concat [list $node] $args] ,]
        SetArrayIfUsed $node $fixed $args $widgetSeln($sub)
    }
    
    proc SliderEvent {node indices} {
	global myNode

#	set sub [join [concat [list {} NOW] $indices] ,]
#	SetArrayIfUsed $node 0 $indices [$scale get]
	MarkEvtParamActive $myNode $node [RunningInC $myNode]
#	ListToArray $myNode $node $sub $sub {} {} [$scale get] 1 \
#	    [RunningInC $myNode]
	eval [list WidgetSelnToC $node 0] $indices
    }

    proc SetArrayIfUsed {node fixed indices value} {
        global paramData runState myNode
	set sub [join [concat [list {}] $indices] ,]
        if {$fixed} {
	    set ledColour [$runState($myNode,cnvs) itemcget 1 -fill]
	    if {[lsearch {yellow green blue} $ledColour]>-1} return
	    set runState($myNode,reloadParams) -1
# bug: command is called when slider created, generating spurious reset request
            if {![RunningInC $myNode]} {
                set paramData($node$sub) $value
            }
        }
#	PlaceInArray $myNode $sub $value 0 [RunningInC $myNode]
	ListToArray $myNode $node $sub $sub {} {} $value 0 [RunningInC $myNode]
    }
    
    proc SetChoiceNumber {cbox node fixed live args} {
	global widgetSeln
	set sub [join [concat [list $node] $args] ,]
	set widgetSeln($sub) [expr {[$cbox current]+1}]
	if {$live} {
	    SetArrayIfUsed $node $fixed $args $widgetSeln($sub)
	}
    }
    
    # If we load a file containing slider values, we only want to set the sliders
    # that are mentioned in that file. so MergeParams needs to make a list of them
    
    proc Open {winId smPath} {
        global helperTable whichParamsAffected

	set smPath [string range $smPath 1 end] ;# submodels in toplevel style
	# (MergeParams will fix if .spf saved by this tool)
	set topNode [$helperTable($winId,whichInstance) GetNode]
        set metaFile [ChooseFile params.spf  [tr. "Load parameters from:"] \
			  0 $topNode]
        if {[llength $metaFile]} {
            ZapParams $topNode $smPath $metaFile 1
        }
    }
    
    proc Save {winId smPath} {
        global helperTable widgetSeln simtmpdir env

        #puts "Saving submodel $smPath inputs"
	set smPath [string range $smPath 1 end]/ ;# submodels in relative style
	set topNode [$helperTable($winId,whichInstance) GetNode]
        set metaFile [ChooseFile inputs.spf  [tr. "Save input values as:"] \
			  1 $topNode]
        if {[llength $metaFile]} {
            set part [file join $simtmpdir temp_out.spf]
            set iStr [open $part w]
            
            set snip [string length $smPath]
            foreach node [GetObjectList] {
                set title [GetCaptionPathFromId $node]
                #puts "trimming $smPath from $title"
                if {!($snip && [string last $smPath $title [expr $snip-1]])} {
                    set titleTail [string range $title $snip end]
                    set trans [GetTransTable $node]
                    # Below should be reimplemented in this interpreter somehow
                    
                    foreach {elmt val} [array get widgetSeln $node*] {
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
        #ShowMess debug info "GetDefVal $vals $levels $index" ok
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
        #	global sliderVals
        #	variable compList
        #	foreach node [array names compList] {
        #	    if {[info exists sliderVals($node)]} {
        #		# it's a single compartment
        #		set compList($node) $sliderVals($node)
        #	    } else {
        #		unset compList($node)
        #		foreach {indxSub val} [array get sliderVals $node,*] {
        #		    set indx [lindex [split $indxSub ,] 0]
        #		    lappend compList($node) $indx $val
        #		}
        #	    }
        #	}
    }
    
    proc ShowNthChoice {combi numbi} {
#	set newTxt [${combi}menu entrycget [expr {$numbi-1}] -label]
#	$combi configure -text $newTxt
	$combi current [expr {$numbi-1}]
    }
    
    # purpose of display proc here is only to stop compartment sliders
    # being altered while model is running, since they refer only to
    # initial values. That is no longer necessary; compartments cannot be
    # variable parameters. But also we want to update other input tools to
    # reflect values from time series data (or rebuilding the model)
    
    # this might be tidied by saving some data in a namespace variable
    
    proc display {winId time display remainder} {
	global helperTable widgetSeln sliderDoes

        foreach currentCaption [GetState $winId] {
            set title [RestoreCrs $currentCaption]
            if {[string equal EVENT $sliderDoes($title,class)]} continue
            set node $sliderDoes($title,node)
            set type $sliderDoes($title,type)
            set dims $sliderDoes($title,dims)
	    
#            set valGroup [InputVarFor [$helperTable($winId,whichInstance) \
#					   GetNode] $node]
#            upvar \#0 $valGroup valArray
#            if {[string equal comboChoices $valGroup]} {}
	    set model [$helperTable($winId,whichInstance) GetNode]
	    if {[string match ENUM(*) $type]} {
                # will need widget address to update it!
                set f [MakeSubFrames $winId $::topSFrame($winId) \
                        [split $title /] [namespace current] 0]
            } else {
                set f {}
            }
            set data [lindex [GetModelValue $node] 0]
            set useDim [FindUseDim $sliderDoes($title,dims)]
            if {$useDim==-1} {
                set widgetSeln($node) [GetDefVal $data -1 0]
                if {[llength $f]} {
                    ShowNthChoice $f.combo $widgetSeln($node)
                }
            } else {
                set count [lindex $sliderDoes($title,dims) $useDim]
                # bodge it to work with record submodels
                if {[string equal RECORDS $count]} {
                    set count [expr {[llength $data]/2}]
                }
                for {set index 1} {$count >= $index} {incr index} {
                    set widgetSeln($node,$index) \
                            [GetDefVal $data $useDim $index]
                    if {[llength $f]} {
                        ShowNthChoice $f.elt$index.c $widgetSeln($node,$index)
                    }
                }
            }
        }
    }
    
    # old version too lazy to check if it is its own slider. What the hell
    # is it doing? getting the whole data list for each element and using
    # only the appropriate value? Who wrote this crap?? Oh, it was
    # me. Never mind...
    
#    proc olddisplay {winId time display remainder} {
#        foreach valGroup {sliderVals checkStates comboTypes} {
#            upvar \#0 $valGroup valArray
#            foreach controlVal [array names valArray] {
#                set ids [split $controlVal ,]
#                set node [lindex $ids 0]
#                #		if {[info exists compList($node)]} {
#                #		    if {[llength $compList($node)]==1} {
#                #			set valArray($node) $compList($node)
#                #		    } else {
#                #			foreach {indx val} $compList($node) {
#                #			    set valArray($node,$indx) $val
#                #			}
#                #		    }
#                #		    continue
#                #		}
#                set data [lindex [GetModelValue $node] 0]
#                set indx [lindex $ids 1]
#                if {[string length $indx]} {
#                    while {[llength [lindex $data 1]]!=1} {
#                        set data [lindex $data 1]
#                    }
#                    set data [lindex $data [expr {2*$indx-1}]]
#                }
#                if {[string length $data]} {
#                    if {[string equal comboTypes $valGroup]} {
#                        set data [lindex [lindex [GetTransTable $node] end] \
#                                $data]
#                    }
#                    set valArray($controlVal) $data
#                }
#            }
#        }
#    }
} ;# end of namespace
