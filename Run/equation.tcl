# Simile source code file: Run/equation.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for the equation dialogue.
#
proc create_equation {parent purpose comp indices enum_types} {
    global equation tcl_platform iconImages window_info custom

    ### Formula bar section
    if {[lsearch {click tick} $::equationbar(current_action)]>=0} {
        return
    }
    ResetEqnBar [winfo parent $parent]
    ### End formula bar section
    set topNode $window_info($parent,top_node) 
#    if {[catch {PutItThere .equation $parent} t]} return ;# already exists
# Allow error message as it stops Prolog trying to close box later
    set t [PutItThere .equation [winfo parent $parent]]
    wm title $t [format $::msgs($purpose) [BlankCrs $comp]]
# TRANSLATOR: $purpose part of string is one of:
# Cause, Initial value, equation
    set equation(top) $t
    wm protocol $t WM_DELETE_WINDOW "equationCancel"
    
    set notebook [::ttk::notebook $t.notebook]
    set mainF $notebook.main
    $notebook add [panedwindow $mainF -orient vertical] -text [tr. Main]
    set paramF $notebook.params
    $notebook add [panedwindow $paramF -orient vertical] \
	-text [tr. "Parameters etc."]
    set docF $notebook.documentation
    $notebook add [frame $docF] -text [tr. Documentation]
    set equation(notebook) $notebook
    set equation(main) $mainF
    set equation(params) $paramF
    set equation(doc) $docF
    
    # frame for buttons
    set buttonF [ttk::frame $t.buttons]
    set ok [ttk::button $buttonF.ok -command equationOK \
		-width 10 -text [tr. OK]]
    bind $ok <Button-1> "focus $ok" ;# make sure new names checked before exit
    set can [ttk::button $buttonF.cancel -command equationCancel \
		 -width 10 -text [tr. Cancel]]
    set help [ttk::button $buttonF.help -command {ContextSensitiveHelp .equation equations/dialogue.htm} \
		  -width 10 -text [tr. Help]]
    pack $help -side right -padx 8 -pady 4 -anchor e
    pack $can -side right -padx 8 -pady 4 -anchor e
    pack $ok -side right -padx 8 -pady 4 -anchor e
    pack $buttonF -anchor nw -fill x -side bottom
    
    # Middle frame has the functions, indices and keypad
    # created variable middleF to point to the Middle frame makes moving the frame in
    # the widget hierrachy easier Jonathan 22 Aug 2002
    $mainF add [set middleF [panedwindow $mainF.middle -orient horizontal]]
    $middleF add [TitleFrame $middleF.functions -text "[tr. Functions]: "]
    BindPopup $middleF.functions function
    set fnFrame [GetFrame $middleF.functions].fnFrame
#    ScrolledWindow $fnFrame
    frame $fnFrame
#    set lbf [Tree $fnFrame.table -showlines yes]
    scrollbar $fnFrame.bar -command "$fnFrame.table yview"
    pack $fnFrame.bar -side right -fill y
    set lbf [::ttk::treeview $fnFrame.table -show tree \
		 -yscrollcommand "$fnFrame.bar set"]
    $fnFrame.table column \#0 -width 100
    pack $fnFrame.table -expand true -fill both
#    $fnFrame setwidget $lbf
    pack $fnFrame -expand true -fill both

    foreach funk $equation(fnDefs) {
        set box {} ;# was root for bwidget
        foreach level [lindex $funk 0] {
            set lname $box.[string tolower [join $level _]]
            if {![$lbf exists $lname]} {
#                $lbf insert end $box $lname -image $iconImages(find) \
#                        -text $level -open [string equal Built-in $level]
		$lbf insert $box end -id $lname \
		    -text [tr. $level] -image $iconImages(open)
# TRANSLATOR: strings for $level provided elsewhere
		if {[string equal {} [$lbf parent $box]]} {
		    $lbf item $box -open 1
		}
            }
            set box $lname
        }
        set component $box.[lindex $funk 2]
        if {[$lbf exists $component]} {
# want the last (most general) defn of each fn, so delete earlier
	    $lbf delete $component
        }
	$lbf insert $box end -id $component \
	    -image $iconImages(function) -text [lrange $funk 2 end]
    }
    $lbf insert {} end -id .et_top_level \
	-text [tr. {Enum. type constants}] -image $iconImages(open)
# add menu entries for enum. type constants
    foreach enumType [linsert $enum_types 0 [list boolean false true]] {
	set type [lindex $enumType 0]
	set lname .et_top_level.[join $type _]
	$lbf insert .et_top_level end -id $lname \
			-text $type -image $iconImages(open)
	foreach member [lrange $enumType 1 end] {
	    $lbf insert $lname end -id $lname.[join $member _] \
			-text $member -image $iconImages(text)
	}
    }


    
#    pack $middleF.functions -side left -anchor nw -padx 2 -pady 2 -expand true -fill both
    $middleF add [TitleFrame $middleF.params -text "[tr. Parameters]: "]
    BindPopup $middleF.params inputs
    set paramsf [GetFrame $middleF.params]
    frame $paramsf.list
    set lbp [listbox $paramsf.list.ilist \
            -height 8 -width 16 \
            -yscrollcommand [list $paramsf.list.scrolli set]]
    scrollbar $paramsf.list.scrolli -command [list $lbp yview]
    pack $paramsf.list.ilist -side left -fill both -expand true
    pack $paramsf.list.scrolli -side left -fill y
    pack $paramsf.list -anchor nw -expand true -fill both
    
    # Stella special: a keypad frame to prevent users having to touch their kbd
    $middleF add [TitleFrame $middleF.keypad -text "[tr. Keypad]: "]
    set keypadf [GetFrame $middleF.keypad]
    frame $keypadf.keys
    set keys [list < > ( ) \[ \] custom AC \
		  = ^ , / and dummy if dummy \
		  7 8 9 * or dummy then dummy \
		  4 5 6 - not dummy else dummy \
		  1 2 3 + xor dummy [tr. SPACE] dummy \
		  0 .  <- -> [tr. DEL] dummy [tr. NEWLINE] dummy]
    if {[string equal windows $tcl_platform(platform)]} {
	set buttWidth 4
    } else {
	set buttWidth 2
    }
    for {set row 0} {$row < 6} {incr row} {
        pack [frame $keypadf.keys.row$row] -fill x
        for {set col 0} {$col < 8} {incr col} {
            set act [lindex $keys [expr 8*$row+$col]]
	    if {[string match custom $act]} {
		set act [PrefValue custom(myButton) myButton]
	    }
	    set bid [button $keypadf.keys.row$row.col$col -text $act \
			 -width $buttWidth -command [list HitKey $t $act]]
	    pack $bid -side left -fill x -expand false
	    if {[string first $act .0123456789]>-1} {
		$bid configure -bg \#a0a0a0 -activebackground \#a0a0a0
	    } elseif {[string match AC $act]} {
		$bid configure -bg orange -activebackground orange
	    } elseif {[lsearch -exact {<- -> SPACE DEL NEWLINE} $act]>-1} {
		$bid configure -bg grey -activebackground grey
	    }
        }
    }
    # Make text buttons double width
    # 1. destroy dummy keys
    destroy $keypadf.keys.row1.col5
    destroy $keypadf.keys.row2.col5
    destroy $keypadf.keys.row3.col5
    destroy $keypadf.keys.row4.col5
    destroy $keypadf.keys.row1.col7
    destroy $keypadf.keys.row2.col7
    destroy $keypadf.keys.row3.col7
    destroy $keypadf.keys.row4.col7
    destroy $keypadf.keys.row5.col5
    destroy $keypadf.keys.row5.col7
    # 2. repack text keys with expand true
    pack $keypadf.keys.row1.col4 -expand true
    pack $keypadf.keys.row2.col4 -expand true
    pack $keypadf.keys.row3.col4 -expand true
    pack $keypadf.keys.row4.col4 -expand true
    pack $keypadf.keys.row1.col6 -expand true
    pack $keypadf.keys.row2.col6 -expand true
    pack $keypadf.keys.row3.col6 -expand true
    pack $keypadf.keys.row4.col6 -expand true
    pack $keypadf.keys.row5.col4 -expand true
    pack $keypadf.keys.row5.col6 -expand true
    # 3. Leave a slight gap between the text and numberic keypads
    pack $keypadf.keys.row0.col4 -padx [list 4 0]
    pack $keypadf.keys.row1.col4 -padx [list 4 0]
    pack $keypadf.keys.row2.col4 -padx [list 4 0]
    pack $keypadf.keys.row3.col4 -padx [list 4 0]
    pack $keypadf.keys.row4.col4 -padx [list 4 0]
    pack $keypadf.keys.row5.col4 -padx [list 4 0]
    
    pack $keypadf.keys -side left -anchor nw
#    No need to pack if they are panes
#    pack $middleF.keypad -anchor nw -padx 2 -pady 2 -side left -fill y
#    pack $middleF -expand off -fill x
    
    
    # Now for the main frame: the equation and its commentary
    switch $purpose {
	cause_for {
	    set eqnFrameTitle "Event condition"
	    set topType "Limit: Equation reaches..."
	    set midType "Time series event"
	    set bottomType "Triggered"
	} rules_for {
	    set eqnFrameTitle "Rules and boundaries"
	    set topType "Range of allowed values"
	    set midType "Initial values from file"
	    set bottomType "Rules"
	} init_val_for {
	    set eqnFrameTitle "Initial data source"
	    set topType "Range of allowed values"
	    set midType "Initial values from file"
	    set bottomType "Initial value"
	} equation_for {
	    set eqnFrameTitle "Data source"
	    set topType "Variable parameter"
	    set midType "Fixed parameter"
	    set bottomType "Derived"
	}
    }
# TRANSLATOR: Quoted strings above need translations in next block
    $mainF add [frame $mainF.main]
    TitleFrame $mainF.main.main -text "[tr. $eqnFrameTitle]: "
    BindPopup $mainF.main.main [NameToTag $eqnFrameTitle]
    set mainf [GetFrame $mainF.main.main]
    frame $mainf.slider
    radiobutton $mainf.slider.radio1 -text "[tr. $topType]: " \
	-variable equation(isparam) -value 1
    pack $mainf.slider.radio1 -side left
    if {[lsearch {init_val_for rules_for} $purpose]>=0} {
# do not allow variable parameter for initial values...derrr
	$mainf.slider.radio1 configure -state disabled
    } else {
	BindPopup $mainf.slider.radio1 [NameToTag $topType]
    }
    pack [set minmax [frame $mainf.slider.minmax]] -side left
    pack [label $minmax.minlabel -text [tr. Minimum]] -side left -padx 4 -pady 4
    pack [::ttk::entry $minmax.minval -width 8 \
	      -textvariable equation(min)] -side left -padx 4 -pady 4
    pack [label $minmax.maxlabel -text [tr. Maximum]] -side left -padx 4 -pady 4
    pack [::ttk::entry $minmax.maxval -width 8 \
	      -textvariable equation(max)] -side left -padx 4 -pady 4
    BindPopup $minmax range_of_allowed_values
    
    pack [set unitsanddims [frame $mainf.slider.unitsanddims]] -side right
    pack [label $unitsanddims.cur_dims] -side right -padx 4
    pack [label $unitsanddims.dims_txt -text [tr. "Current dimensions"]: \
	     -wraplength 100] -side right -padx 4
    pack [set eu [::ttk::entry $unitsanddims.entry -width 8 \
		      -textvariable equation(units)]] -side right \
	-padx 4 -pady 4
    pack [label $unitsanddims.unitslabel -text "[tr. Units]:"] -side right \
	-padx 4 -pady 4
    BindPopup $unitsanddims unitsanddims
    
    pack $mainf.slider -anchor nw -fill x
    frame $mainf.file
    radiobutton $mainf.file.radio2 -text [tr. $midType] \
	-variable equation(isparam) -value 2
    pack $mainf.file.radio2 -side left
    BindPopup $mainf.file.radio2 [NameToTag $midType]
    pack $mainf.file -anchor nw -fill x
    frame $mainf.equation
    
    set equation(actzone) $mainf.equation.textbox
    frame $equation(actzone)
    radiobutton $equation(actzone).radio0 -variable equation(isparam) \
	-text "$bottomType: $comp = " -wraplength 120 \
	-value 0
    BindPopup $equation(actzone).radio0 [NameToTag $bottomType]
    
    set en [text $equation(actzone).text -height 4 -width 64 \
		-relief sunken -bd 2 -highlightthickness 0 -font EquationFont \
		-yscrollcommand "$equation(actzone).scroll set"]
    AllowTextDrags $en
# risky choice, it may encourage modellers to enter very large equations
    # Safer bet: use math input toool. Problem, produces wrong kind of MathML
    # bind $en <<Paste>> {CheckForMathInput %W}
    
    scrollbar $equation(actzone).scroll -orient vert -command "$en yview"
    pack $equation(actzone).scroll -side right -fill y
    pack $en -side right -expand true -fill both
    if {[string equal rules_for $purpose]} {
	$en configure -width 48
	set ev [listbox $equation(actzone).evts -height 4]
	pack $ev -side right -expand true -fill both
	bind $ev <<ListboxSelect>> ChangeEvtSeln
    }
    pack $equation(actzone).radio0 -anchor nw
    pack $equation(actzone) -expand true -fill both -side left
    focus $en
    
    frame $equation(actzone).buttons
    #$notebook itemconfigure Main -raisecmd "focus $en"
    
    set graph [button $equation(actzone).buttons.graph \
		   -text " [tr. Graph]... "\
		   -command "equationDoGraph $t $en"]
    pack $graph -padx 8 -pady 4
    BindPopup $graph graph
    set table [button $equation(actzone).buttons.table \
		   -text " [tr. Table]... " \
		   -command [list GetTable $t $topNode $comp $en $enum_types]]
    pack $table -padx 8 -pady 4
    BindPopup $table table
    if {![string match Darwin $tcl_platform(os)]} {
	$graph configure -compound left -image $iconImages(graph)
	$table configure -compound left -image $iconImages(table)
    }

    pack $equation(actzone).buttons -anchor e -side left
    pack $mainf.equation -expand true -fill both -anchor nw
    pack $mainF.main.main -anchor nw -expand true -fill both -padx 2 -pady 2 -side left
    
#    pack $mainF.main -anchor nw -expand true -fill both -anchor nw
    
    # Miscellaneous other stuff below
    $paramF add [TitleFrame $paramF.indices -text "[tr. Indices]: "]
    set indicesf [GetFrame $paramF.indices]
    frame $indicesf.list
    set lbx [listbox $indicesf.list.ilist \
            -height 8 -width 16 \
            -yscrollcommand [list $indicesf.list.scrolli set]]
    foreach indx $indices {
        $lbx insert end $indx
    }
    scrollbar $indicesf.list.scrolli -command [list $lbx yview]
    pack $indicesf.list.ilist -side left -fill both -expand true
    pack $indicesf.list.scrolli -side left -fill y
    pack $indicesf.list -anchor nw -expand true -fill both
#    pack $middleF.indices -side left -anchor nw  -padx 2 -pady 2 -expand true -fill both

    # Bottom frame has the influences and parameters list boxes
    $paramF add [set bottomF [frame $paramF.bottom]]
    TitleFrame $bottomF.influences -text "[tr. Influences]: "
    set influencesf [GetFrame $bottomF.influences]
    frame $influencesf.captions
    label $influencesf.captions.p -text [tr. Parameter]:
    label $influencesf.captions.i -text [tr. "In units"]:
    label $influencesf.captions.d -text [tr. Dimensions]:
    pack $influencesf.captions.p $influencesf.captions.i \
            $influencesf.captions.d -side left -fill x -expand true
    pack $influencesf.captions -fill x
    
    DIYMakeFrames $influencesf
#    frame $influencesf.lists
#    scrollbar $influencesf.lists.yscroll -orient v \
#            -command [list $influencesf.lists.f yview]
#    pack $influencesf.lists.yscroll -side right -fill y
#    ScrollableFrame $influencesf.lists.f -constrainedwidth true \
#            -yscrollcommand [list AdjustCanvas $influencesf.lists f y]
    
#    pack $influencesf.lists.f -fill x -expand true
#    pack $influencesf.lists -side top -fill x -expand true
    
    set canId $influencesf.c.canvas.frame
    frame $canId.plist -bd 2 -relief sunken
    frame $canId.ilist -bd 2 -relief sunken
    frame $canId.dlist -bd 2 -relief sunken
    pack $canId.plist $canId.ilist $canId.dlist -side left -fill x -expand true
    pack $bottomF.influences -fill x -anchor nw -padx 2 -pady 2
#    pack $bottomF -fill x
    
    # comments in the Documentation page
    
    set descF [frame $docF.descf]
    TitleFrame $descF.description -text "[tr. Title]: "
    set descf [GetFrame $descF.description]
    label $descf.desclabel -text "[tr. Description]: "
    text $descf.text -height 1 -width 20 -relief sunken -bd 2 -highlightthickness 0
    pack $descf.desclabel -side left -padx 2 -pady 2
    pack $descf.text -side left  -fill x -expand true -padx 2 -pady 2
    pack $descf -side top  -fill x -expand off
    pack $descF.description  -fill x -expand off -padx 4 -pady 4
    pack $docF.descf -fill x -expand off
    #$notebook itemconfigure Documentation -raisecmd "focus $descf.text"
    
    label $docF.cmtlabel -text [tr. Comments]:
    pack $docF.cmtlabel -side top
    pack [set frm [frame $docF.cmtFrame]] -fill both -expand true
    text $frm.text -height 3 -width 40 -wrap word -relief sunken -bd 2 \
	-highlightthickness 0 -yscrollcommand "$frm.scrly set"
    AllowTextDrags $frm.text
    scrollbar $frm.scrly -orient vert -command "$frm.text yview"
    pack $frm.text -side left -fill both -expand true
    pack $frm.scrly -side right -fill y
    
    $notebook select 0
    pack $notebook -fill both -expand true
    set equation(newGraphs) ""
    set equation(showing) 0
    set equation(done) 0
    equationBindings $t $en $eu $lbf $lbx $lbp $graph $table $ok $can
    if {![llength $indices]} {
	destroy $paramF.indices
    }
#    tkwait visibility $middleF
# above is insufficient to get Mac version to work proper, so...
    update
    set eqnLayout [file join $custom(prefDir) .layouts equation]
    if {[file exists $eqnLayout]} {
        set stream [NetOpen $eqnLayout r]
        gets $stream whetherMaxed
	gets $stream oldGeom
	if {$whetherMaxed} {
	    wm state $t zoomed
	} else {
	    wm geometry $t $oldGeom ;# delete on exit, or may be off screen
	}

	while {[gets $stream posnData] >= 0} {
	    set widget [lindex $posnData 1]
	    if {[string equal sash [lindex $posnData 0]] && \
		    ![string first .equation.notebook.main. $widget]} {
		eval [list $widget sash place] [lrange $posnData 2 end]
	    }
	}
	close $stream
    } else {
# they do not place themselves properly ont' Mac
	$middleF sash place 0 170 0
	$middleF sash place 1 340 0
    }
}

proc CheckForMathInput {en} {
    package require twapi_clipboard
    twapi::open_clipboard
    # note that the id of any format can change over time
    foreach fmt [twapi::get_clipboard_formats] {
	if {[twapi::get_registered_clipboard_format_name $fmt] eq "MathML"} {
	    set raw [twapi::read_clipboard $fmt]
	}
    }
    if {![info exists raw]} return
#    $en insert insert [XmlToGenericPl [utf16-to-u $raw]]
    $en insert insert [utf16-to-u $raw]
}

proc utf16-to-u {u16str} {
    set endCode [scan $u16str %c%c]
    if {$endCode eq "255 254"} {
	set endianity yes
    } elseif {$endCode eq "254 255"} {
	set endianity no
    } else {
	error "Bad header"
    }
    set cur 0
    set need 0
    while {[string length $u16str]>2} {
	set u16str [string replace $u16str 0 1]
	scan $u16str %c%c c0 c1
	set num [expr {$c0+$c1+255*($endianity?$c1:$c0)}]

	if {$num < 0xd800 || $num > 0xdfff} {
	    append result [format %c $num]
	} else {
	    if {$num > 0xdbff && !$need} {
		set cur 0
	    } elseif {$num < 0xdc00} {
		set need 1
		set cur [expr {(($num & 0x3ff) << 10) + 0x10000}]
	    } elseif {$num > 0xdbff} {
		set cur [expr {$cur | ($num & 0x3ff)}]
		append result [format %c $cur]
	    }
	}
    }
    return $result
}

# when the selection in the list of causes changes, we have to check with 
# Prolog that the effect parses OK, so the change must first be reversed...
proc ChangeEvtSeln {} {
    global equation

    set en $equation(actzone).text
    set ev $equation(actzone).evts
    if {[llength [set equation(cur_cause) [$ev curselection]]]} {
	set equation(last_efct) [string trimright [$en get 1.0 end]]
	$ev selection clear 0 end
	$ev selection set $equation(last_cause)
# now give Prolog a chance to accept new data and redo switch
	set equation(done) 4
    }
}

# This is called from Prolog if the effect equation is OK
proc RedoChangeOfCause {updatedUnits mult} {
    global equation
    
    set en $equation(actzone).text
    set ev $equation(actzone).evts
    lset equation(rule_efx) $equation(last_cause) $equation(last_efct)
    $en delete 1.0 end
    $en insert 1.0 [lindex $equation(rule_efx) $equation(cur_cause)]
    set equation(last_cause) $equation(cur_cause)
    $ev selection clear 0 end
    $ev selection set $equation(last_cause)

    set equation(units) [RealForUnity $updatedUnits]
    if {[llength $mult]} {
        set emult [join $mult ,]
    } else {
        set emult none
    }
    set widget [GetFrame $equation(main).main.main]
    $widget.slider.unitsanddims.cur_dims configure -text $emult
}

proc fill_equation {current_equation units mult isParam desc comment min max} {
    
    global equation
    global equationbar

    set equationbar(units) $units
    set equationbar(isParam) $isParam
    set equationbar(desc) $desc
    set equationbar(comment) $comment
    set equationbar(min) $min
    set equationbar(max) $max

    
    ### Formula bar section
    if {[lsearch {click tick} $equationbar(current_action)]>=0} {
        return
    }
    ### End formula bar section
    
    set widget [GetFrame $equation(doc).descf.description]
    $widget.text delete 1.0 end
    $widget.text insert 1.0 $desc
    $equation(doc).cmtFrame.text delete 1.0 end
    $equation(doc).cmtFrame.text insert 1.0 $comment
    set widget [GetFrame $equation(main).main.main]
    $widget.equation.textbox.text delete 1.0 end

    set causeList $widget.equation.textbox.evts
    if {[winfo exists $causeList]} {
# a set of rules for a state
	set equation(rule_efx) {}
	foreach {cause effect} $current_equation {
	    lappend equation(rule_efx) $effect
	    $causeList insert end $cause
	}
	$causeList selection set 0 0
	$widget.equation.textbox.text insert 1.0 [lindex $equation(rule_efx) 0]
	set equation(last_cause) 0
    } else {	
	$widget.equation.textbox.text insert 1.0 $current_equation
    }
    set equation(units) [RealForUnity $units]
    if {[llength $mult]} {
        set emult [join $mult ,]
    } else {
        set emult none
    }
    $widget.slider.unitsanddims.cur_dims configure -text $emult
    set equation(isparam) $isParam
    if {$equation(isparam)==-1} {
	set equation(isparam) 0
#    $widget.equation.textbox.radio0 configure -state $paramMenuState
	$widget.slider.radio1 configure -state disabled
	$widget.file.radio2 configure -state disabled
    }
    set equation(min) $min
    set equation(max) $max
}

proc interact_equation {} {
    global equation equationbar tcl_platform
    
    ### Formula bar section
    switch $equationbar(current_action) {
	click {
	    return
	} tick {
	    set equationbar(current_action) click
	    if {[info exists equationbar(min_entry)]} {
		set equationbar(min) $equationbar(min_entry)
	    }
	    if {[info exists equationbar(max_entry)]} {
		set equationbar(max) $equationbar(max_entry)
	    }
	    set result [list $equationbar(equation) \
			    $equationbar(units) \
			    $equationbar(isParam) \
			    $equationbar(desc) \
			    $equationbar(comment) \
			    $equationbar(min) \
			    $equationbar(max)]
	    if {[info exists equationbar(curEvt)]} {
		return [linsert $result 1 $equationbar(curEvt)]
	    }
	    return $result
	}
    }
    ### End formula bar section

    set t $equation(top)
    set descFrame [GetFrame $equation(doc).descf.description]
    
    if {!$equation(showing)} {
	set equation(showing) 1
	LetItShow $t
    }
    if {[llength $equation(ckWidg)]} {
	.equation.notebook select 1 ;# raise parameters tab
	focus $equation(ckWidg) ;# keep here until correct input or cancel
    }
    grab $t
    tkwait variable equation(done)
    grab release $t

    set units [UnityForReal $equation(units)]
    switch $equation(done) {
        1 {
	    set res [string trimright [$equation(actzone).text get 1.0 end]]
	    set equation(prevs) [AddIfAbsent $res $equation(prevs)]
	    [wm transient $t].toolSlot.eqnbar.equation configure \
		-values $equation(prevs)
	    if {[winfo exists $equation(actzone).evts]} {
# entering rules -- individual items already passed back (case 4 below)
# but have to pass current pair in case modified
		return [list $res \
			    [$equation(actzone).evts get $equation(last_cause)] \
			    $units $equation(isparam) \
			    [string trimright [$descFrame.text get 1.0 end]] \
			    [string trimright [$equation(doc).cmtFrame.text get 1.0 end]] \
			    $equation(min) $equation(max)]
		
	    } else {
		return [list $res $units $equation(isparam) \
			    [string trimright [$descFrame.text get 1.0 end]] \
			    [string trimright [$equation(doc).cmtFrame.text get 1.0 end]] \
			    $equation(min) $equation(max)]
	    }
        } 2 {
            return [list $equation(ckLine) \
                    $equation(entry$equation(ckLine)) \
                    [UnityForReal $equation(unit$equation(ckLine))]]
        } 3 {
            return [list \['[join $equation(table_data) ',']'\] \
                    $equation(table_values)]
        } 4 {
            return [list $equation(last_efct) \
			[$equation(actzone).evts get $equation(last_cause)] \
			$units $equation(min) $equation(max)]
# min and max included to make up numbers and in case we decide they can differ
# between clauses
	}
    }
}

proc destroy_equation {} {
    global equation custom tcl_platform
    
    ### Formula bar section
    if {[lsearch {click tick} $::equationbar(current_action)]>=0} {
        return
    }
    ### End formula bar section
    
    set layoutDir [file join $custom(prefDir) .layouts]
    if {![file exists $layoutDir]} {
	file mkdir $layoutDir
	if {[string equal windows $tcl_platform(platform)]} {
	    file attributes $layoutDir -hidden true
	}
    }
    set lStm [NetOpen [file join $layoutDir equation] w]
    puts $lStm [string equal zoomed [wm state $equation(top)]]
    puts $lStm [wm geometry $equation(top)]

    foreach {parent count} {main 1 main.middle 2 params 1} {
	for {set i 0} {$i<$count} {incr i} {
	    set pw $equation(top).notebook.$parent
	    catch {puts $lStm "sash $pw $i [$pw sash coord $i]"}
	}
    }
#    RunEnv::SaveChildrenConfig $equation(top).notebook 0 ;# creates metaList
#    puts $layoutStream [join $metaList \n]
    close $lStm
    PackItUp $equation(top)
}

proc UnityForReal {show} {
    if {[string equal real $show]} {
        return 1
    } else {
        return $show
    }
}

proc RealForUnity {show} {
    if {[string equal 1 $show]} {
        return real
    } else {
        return $show
    }
}

# Scrolls all listboxes in response to scrollbar

proc ScrollAll {widgetList args} {
    
    foreach item $widgetList {
        eval {$item yview} $args
    }
}

proc RollAll {s l1 l2 l3 top bot} {
    $s set $top $bot
    $l1 yview moveto $top
    $l2 yview moveto $top
    $l3 yview moveto $top
}

proc GetTable {parent topNode comp box enum_types} {
    global equation table_entry
    
    set table_entry(data) $equation(table_data)
    set table_entry(values) $equation(table_values)
    if {[equationDoTable $parent $topNode $comp "(data determines dimensions)" \
	     $enum_types fixed]>0} {
#        if {[llength $table_entry(dataField)]} {
#            set equation(table_data) [concat [list $table_entry(fileName) \
#                    $table_entry(dataField)] \
#                    $table_entry(indices)]
	#        }
	if {$table_entry(data) eq {} && $table_entry(values) ne {}} {
	    set equation(table_data) {{} {}} ;# values entered in editor
	} else {
	    set equation(table_data) $table_entry(data)
	}
	if {[string equal ,gdal [lindex $table_entry(values) 1]]} {
	    set equation(table_values) \
		[NumberElements [ReadGdalRefToList $table_entry(values)]]
	} else {
	    set equation(table_values) [FloatifyBigInts $table_entry(values)]
	}
        if {![string match *table(*)* [$box get 1.0 end]]} {
	    InsertFunction $box table
        }
        set equation(done) 3
    }
}

proc FloatifyBigInts {vals} {
    if {[llength $vals]==1} {
	if {[string is double -strict $vals] && abs($vals)>=268435456} {
	    return [expr {double($vals)}]
	} else {
	    return $vals
	}
    } else {
	foreach {ind val} $vals {
	    lappend fltd $ind [FloatifyBigInts $val]
	}
	return $fltd
    }
}

proc fill_inputs { triples } {
    global equation
    
    ### Formula bar section
    if {[lsearch {click tick} $::equationbar(current_action)]>=0} {
        return
    }
    ### End formula bar section

    set t [GetFrame $equation(main).main.main]
    set en $t.equation.textbox.text
    set paramList [GetFrame $equation(main).middle.params]
    set lbp $paramList.list.ilist
    set widget [GetFrame $equation(params).bottom.influences]
    set scroller $widget.c.canvas.frame
    # Initialize variables and display  list
    foreach ipFrame {plist ilist dlist} {
        foreach ipEntry [winfo children $scroller.$ipFrame] {
            destroy $ipEntry
        }
    }
    set line 0
    $lbp delete 0 end
    set equation(origins) {}
    foreach vpiTriple $triples {
        set equation(paths,$line) [lindex $vpiTriple 0]
        set equation(oldentry,$line) [lindex $vpiTriple 1]
        $lbp insert end [lindex $vpiTriple 1]
	set paramPopMsg [DescribeInputParam [lindex $vpiTriple 0]]
	lappend equation(origins) $paramPopMsg
        set equation(oldunit,$line) [RealForUnity [lindex $vpiTriple 2]]
        
        set p [entry $scroller.plist.p$line -bd 0 -relief flat \
                -font TkDefaultFont -textvariable "equation(entry$line)"]
#       bind $p <Enter> [list QueuePopup AddWidgetPopup %X %Y $paramPopMsg]
	BindPopup $p $paramPopMsg
	KoreanClick $p 1 {}
        bind $p <Double-1> "equationDouble %W $en; focus $en"
        bind $p <FocusOut> "ListEditDone %W $line entry"
        bind $p <Return> "ListEditDone %W $line entry"
        bind $p <Leave> RemovePopup
        $p config -highlightbackground [$p cget -background]
        $p delete 0 end
        $p insert end $equation(oldentry,$line)
        pack $p -fill x -expand true
        
        set u [entry $scroller.ilist.u$line -bd 0 -relief flat \
                -font TkDefaultFont -textvariable "equation(unit$line)"]
        bind $u <FocusOut> "ListEditDone %W $line unit"
        bind $u <Return> "ListEditDone %W $line unit"
        $u config -highlightbackground [$u cget -background]
        $u delete 0 end
        $u insert end $equation(oldunit,$line)
        pack $u -fill x -expand true
        set d [entry $scroller.dlist.d$line -bd 0 -relief flat \
		   -font TkDefaultFont]
        $d delete 0 end
        $d insert end [lindex $vpiTriple 3]
        $d config -highlightbackground [$d cget -background] \
                -disabledbackground [$d cget -background] \
                -disabledforeground [$d cget -foreground] -state disabled
        pack $d -fill x -expand true
        incr line
    }
    # Make box mode compact if not used
    if {!$line} {
#        pack forget $equation(main).bottom
	 $equation(params) forget $equation(params).bottom
	 if {![winfo exists $equation(params).indices] && \
		 [winfo exists $equation(params)]} {
	     catch {.equation.notebook forget $equation(params)}
# 'hide' does not work on the Mac and 'forget' errors if already forgotten
	 }
    } else {
        set showLines [expr {max(3, min(8, $line))}]
        $widget.c.canvas.frame configure -height \
                [expr $showLines*[winfo reqheight $p]+8]
#        update
# Above was necessary so the window appeared fully on-screen, or something, but
# seems superfluous now it is placed on desktop window, and caused nasty bug by
# allowing two doubleclicks to be processed at once
    }
    set equation(ckWidg) {} ;# no need for widget to keep focus if updated
}

proc fill_table {node table_data table_values} {
    global equation
    set equation(table_data) [lrange $table_data 0 end]
    # you would think that the above line would not change the list, as it
    # takes the range from start to finish. But it does -- Prolog has wrapped
    # each element in curly brackets whether or not it needs it, and the effect
    # of the lrange is to remove unnecessary sets of curlies so that later when
    # we check if the elements have changed from the original list it does not
    # matter if some other function has quietly got rid of their surplus curly
    # brackets. Trust me, it works.

    # Translation should be done in Prolog by reverse_engineer
    set equation(table_values) $table_values

    prolog tk_interactively_parse($node)
}

proc equationBindings { t en eu lbf lbx lbp gr ta ok can} {
    # t - toplevel
    # en - equation entry
    # eu - units entry
    
    # lbf - treebox for available functions
    # lbx - listbox for available indices
    # lbp - parameter listbox
    # gr - graph button
    # ta - table button
    # ok - OK button
    # can - Cancel button
    
    
#    $lbf bindText <Enter> [list QueuePopup AddFnPopup %X %Y]
#    $lbf bindText <Leave> RemovePopup
#    $lbf bindText <Double-1> [list functionClick %W $en]
    bind $lbf <Enter> [list QueuePopup AddFnPopup %W %X %Y %x %y]
    bind $lbf <Motion> [list MoveInFns %W %X %Y %x %y]
    bind $lbf <Leave> RemovePopup
    KoreanClick $lbf 1 {}
    bind $lbf <Double-1> [list functionClick %W %x %y $en]

    set PopCmd [list QueuePopup AddIndexPopup %W %y %X %Y]
    bind $lbx <Enter> $PopCmd
    bind $lbx <Motion> "RemovePopup;$PopCmd"
    bind $lbx <Leave> RemovePopup
    KoreanClick $lbx 1 {}
    bind $lbx <Double-1> "indexClick %W %y $en; focus $en"

    set PopCmd [list QueuePopup AddParamPopup %W %y %X %Y]
    bind $lbp <Enter> $PopCmd
    bind $lbp <Motion> "RemovePopup;$PopCmd"
    bind $lbp <Leave> RemovePopup    
    KoreanClick $lbp 1 {}
    bind $lbp <Double-1> "paramClick %W %y $en; focus $en"
    
    bind $gr <Tab> "focus $ta"
    bind $ta <Tab> "focus $ok"
    bind $ok <Tab> "focus $can"
    bind $can <Tab> "focus $gr"
    
    bind $en <Key> "FlashMatchingBracket 1 %W 0 %A"
    bind $en <Button-1> "after 10 FlashOnClick 1 %W"
# pause is to allow insert point to move to click first
    $en tag configure flash -background blue ;# for matching brackets
    # Set up for type in
    focus $en
}

proc FlashOnClick {inText win} {
    if {$inText} {
	FlashMatchingBracket $inText $win 0 [$win get insert]
    } else {
	if {[$win selection present]} return
	set start [$win index insert]
	FlashMatchingBracket $inText $win $start \
	    [string index [$win get] $start]
    }
}

# Following is copied from autocomplete in window, which does same job for
# eqn bar. Diffrences interacting with a text widget are so great that it is
# simplest just to have a separate procedure.
proc FlashMatchingBracket {inText win pt testChar} {
    set brackets \(\[\{\)\]\}
    set start $pt
    set bNum [string first $testChar $brackets]
    if {$bNum>2} { ;# 2 to enable; cannot config selbg for ttk::entry
	lappend stacket $bNum
	while {[SeekingMatch $inText $win $pt]} {	  
	    set testChar [GetTestChar $inText $win [incr pt -1]]
	    set bNum [string first $testChar $brackets]
	    if {$bNum>2} {
		lappend stacket $bNum
	    } elseif {$bNum>-1} {
		if {$bNum+3==[lindex $stacket end]} { ;# match!
		    set stacket [lrange $stacket 0 end-1]
		    if {![llength $stacket]} {
			FlashRange $inText $win $pt
			#$win config -selectbackground green
			break
		    }
		} else {
		    lappend stacket 99 ;# make sure no match happens
		}
	    }
	    set testChar {}
	}
	if {[string equal {} $testChar]} { ;# no match found
	    FlashRange $inText $win $start
	    #$win config -selectbackground red
	}
    }
}

proc SeekingMatch {inText win pt} {
    if {$inText} {
	return [expr {[$win index "insert + $pt chars"]>1.0}]
    } else {
	return [expr {$pt>0}]
    }
}

proc GetTestChar {inText win pt} {
    if {$inText} {
	return [$win get "insert + $pt chars"]
    } else {
	return [string index [$win get] $pt]
    }
}

proc FlashRange {inText win pt} {
    if {$inText} {
	set pt [$win index "insert + $pt chars"]
	after idle $win tag add flash $pt
	after 100 $win tag remove flash $pt
	after 200 $win tag add flash $pt
	after 300 $win tag remove flash $pt
	after 400 $win tag add flash $pt
	after 500 $win tag remove flash $pt
    } else {
	set end [expr {$pt+1}]
	set pop "$win selection range $pt $end; update idletasks; after 100; $win selection clear"
	after idle $pop
	after 200 $pop
	after 400 $pop
    }
}

proc MoveInFns {w X Y x y} {
    global equation
    catch {if {![string equal $equation(whatPopped) \
		     [$w identify row $x $y]]} {
	# changed row; renew popup
	RemovePopup
	AddFnPopup $w $X $Y $x $y
    }}
}

proc equationDoGraph {parent box} {
    global equation
    if {[equationGraph $parent]} {
        if {![string match *graph(*)* [$box get 1.0 end]]} {
            InsertFunction $box graph
        }
        set equation(done) 3
    }
}

proc equationGraph {parent} {
    global equation tcl_platform
    PutItThere .graph $parent
    wm protocol .graph WM_DELETE_WINDOW {set graph(.graph,done) 0}
    # One way to set the window size is to do it explicitly: the other is to use a large initial graph pad size
    focus .graph
    grab .graph
    # set default values for new graph
    set graphArgs {0 100 400 100 0 400 0 21 200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200,200}
    if {[info exists equation(table_data)]} {
	if {[string equal /graph/ [lindex $equation(table_data) 0]]} {
	    set graphArgs [concat [lrange $equation(table_data) 5 7] \
			       [lrange $equation(table_data) 1 3] \
			       [lindex $equation(table_data) 8] \
			       [lindex $equation(table_data) 4] \
			       [join $equation(table_values) ,]]
	}
    }
    set done [eval {GraphEntry .graph} $graphArgs]
    grab release .graph
    PackItUp .graph
    grab $parent
    return $done
}

proc equationOK {} {
    global equation
    set equation(done) 1
}

proc equationCancel {} {
    global equation
    set equation(done) 0
}

#proc equationClick { lb y } {
#    global equation
#    
#    if {$equation(selected,$lb)==$y} {
#        equationRight $lb $y
#    } else {
#        ListEditDone
#        set equation(selected,$lb) -1
#        after 500 [list set equation(selected,$lb) $y]
#    }
#}
#
#proc equationRight { lb y } {
#    global equation
#    ListEditDone
#    if {$equation(done) == 2} {
#        # If an entry has already been edited, dont try to start editing another one
#        # because Prolog has to use the value entered for the old one first
#        return
#    }
#    set widget [GetFrame $equation(main).bottom.influences]
#    set ebox $widget.lists.e
#    set equation(lbid) $lb
#    set equation(ckLine) [$lb nearest $y]
#    entry $ebox -textvariable equation(listedit)
#    set equation(listedit) [$lb get $equation(ckLine)]
#    place $ebox -in $lb \
#            -rely [expr 1.0*$equation(ckLine)/$equation(listlength)] \
#            -relwidth 1
#    $ebox configure -font [$lb cget -font]
#    $ebox select from 0
#    $ebox select to end
#    focus $ebox
#    bind $ebox <Return> ListEditDone
#}
#
proc ListEditDone {w line type} {
    global equation

    if {![string equal $equation($type$line) $equation(old$type,$line)] &&
	![string equal [focus] .equation.buttons.cancel]} {
	set equation(ckLine) $line
	set equation(ckWidg) $w
	set equation(done) 2
    }
}

proc equationDouble { lb boxname} {
    # Take the item the user clicked on
    $boxname insert insert [$lb get]
}

proc HitKey { winId char } {
    global equation
    switch -exact -- $char {
	DEL {
	    event generate $winId <Key-BackSpace>
	} -> {
	    event generate $winId <Key-Right>
	} <- {
	    event generate $winId <Key-Left>
	} SPACE {
	    event generate $winId <Key-space>
	} NEWLINE {
	    event generate $winId <Key-Return>
	} \{ {
	    event generate $winId <Key-braceleft>
	} \} {
	    event generate $winId <Key-braceright>
	} default {
	    set begin 1.0
	    set en [GetFrame $equation(main).main.main].equation.textbox.text
	    if {[string match *Entry [winfo class [focus]]]} {
		set begin 0
	    } else {
		focus $en
	    }
	    if {[string match AC $char]} {	    
		[focus] delete $begin end
	    } else {
		FlashMatchingBracket 1 [focus] 0 $char
		[focus] insert insert $char
	    }
	}
    }
}

proc functionClick {tree x y boxname} {
    # work around smelly BWidget bug
    set fn [$tree identify row $x $y]
    # set tree [winfo parent $tree]
    # Take the item the user clicked on
    if {[string first .et_top_level. $fn]==0} { ;# do for type and members
	$boxname insert [$boxname index insert] \"[$tree item $fn -text]\"
	focus $boxname
    } elseif {[llength [$tree children $fn]]} {
	$tree item $fn -open [expr {![$tree item $fn -open]}]
    } else {
	InsertFunction $boxname [lindex [split $fn .] end]
    }
}

#proc AddFnPopup {X Y fnName} {
#    AddWidgetPopup [lindex [split $fnName .] end] $X $Y
#}
#
proc AddFnPopup {w X Y x y} {
    global equation
    set equation(whatPopped) [$w identify row $x $y]
# no popups for constants, until we can comment them for this purpose
    if {[string first .et_top_level. $equation(whatPopped)]==0} {
	return
    }
    set popTxt [lindex [split $equation(whatPopped) .] end]
    if {![string equal {} $popTxt]} {
	AddWidgetPopup $w $X $Y $popTxt
    }
}

proc AddIndexPopup {lb y X Y} {
    set line [$lb nearest $y]
    if {$line>-1} {
	AddWidgetPopup $lb $X $Y "Index [expr $line+1] is [$lb get $line]"
    }
}

proc AddParamPopup {lb y X Y} {
    global equation
    set line [$lb nearest $y]
    if {$line>-1} {
	AddWidgetPopup $lb $X $Y [lindex $equation(origins) $line]
    }
}

proc indexClick { lb y boxname} {
    # insert an index call using the line number clicked on
    $boxname insert insert index([expr [$lb nearest $y]+1])
}

proc paramClick { lb y boxname} {
    # insert a param ref using the line number clicked on
    $boxname insert insert [$lb get [$lb nearest $y]]
}

proc InsertFunction {boxname functor} {
    if {[string match Text [winfo class $boxname]]} {
        set useRange [llength [$boxname tag ranges sel]]
        set insertCmd {mark set insert}
    } else {
        set useRange [$boxname select present]
        set insertCmd icursor
	set val [$boxname cget -validate]
	$boxname configure -validate none
    }
    if {$useRange} {
        $boxname insert sel.last \)
        $boxname insert sel.first $functor\(
    } else {
        set insertPoint [$boxname index insert]
        $boxname insert $insertPoint \)
        eval $boxname $insertCmd $insertPoint
        $boxname insert $insertPoint $functor\(
    }
    if {[info exists val]} {
	$boxname configure -validate $val
    }
    focus $boxname
}

proc StartPlElement {name attList args} {
    global parseStatus

    array set tangentials $args
    if {[info exists tangentials(-namespacedecls)]} {
	array set parseStatus $tangentials(-namespacedecls)
    }
    if {[info exists tangentials(-namespace)]} {
	set name '$parseStatus($tangentials(-namespace)):$name'
    }

    set pairs {}
    foreach {att val} $attList {
	lappend pairs "($att)='$val'"
    }
    if {$parseStatus(inList)} {
	append parseStatus(plStr) ,
    }
    append parseStatus(plStr) "element($name,\[" [join $pairs ,] "\],\["
    set parseStatus(inList) no
}

proc FinishPlElement {name args} {
    global parseStatus

    append parseStatus(plStr) "])"
    set parseStatus(inList) yes
}

proc StuffPlElement {data} {
    global parseStatus

    append parseStatus(plStr) '$data'
}

proc ExmlToGenericPl {tgt} {
    set pStr [open $tgt r]
    set dada [read $pStr]
    close $pStr
    global parseStatus
    array unset parseStatus
    package require xml

    set parseStatus(pl) [::xml::parser -ignorewhitespace true \
				-elementstartcommand StartPlElement \
				-elementendcommand FinishPlElement \
				-characterdatacommand StuffPlElement]
    array set parseStatus {plStr {} inList no}
    $parseStatus(pl) parse $dada
    append parseStatus(plStr) . ;# allow prolog to read normally
    return $parseStatus(plStr)
}
