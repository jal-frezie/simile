################################################################################
#####     PROCEDURES FOR EQUATION DIALOG BOX                               #####
################################################################################
# Yet another dialog box, this one for equation entry. Title is 'Equation for
# <name> (<units>)' and we need to keep the box up to display errors while entering
# the equation. Put up warning messages if the units change etc etc etc. 

proc equationResources {} {

#    foreach equation(ebox) {name description comment units} {
#	option add *Equation*$equation(ebox).relief		sunken	startup
#	option add *Equation*$equation(ebox).background	white	startup
#	option add *Equation*$equation(ebox).foreground	black	startup
#    }

    # Text for the labels on variable/parameter/unit entries
#    option add *Equation*n.text		Equation:	startup
#    option add *Equation*u.text		Units:		startup
#    option add *Equation*v.text		Label:	startup
#    option add *Equation*p.text		"Local name:"	startup
#    option add *Equation*i.text		Units:		startup

    # Text for the OK and Cancel buttons
#    option add *Equation*ok*text		OK	startup
     option add *Equation*ok*underline		0	startup
#    option add *Equation*cancel.text		Cancel	startup
     option add *Equation*cancel.underline 	0	startup
#    option add *Equation*graph.text		"Graph..."	startup
     option add *Equation*graph.underline 	0	startup
#    option add *Equation*table.text		"Table..."	startup
     option add *Equation*table.underline 	0	startup

    # Size of the listboxes
    foreach listBox {plist ilist} {
	option add *Equation*$listBox.width	15	startup
	option add *Equation*$listBox.height	8	startup
    }
}

proc fill_equation {current_equation units mult isParam \
		table_data desc comment min max} {
	global equation 
	global equationbar

      set equationbar(units) $units
#      set equationbar(mult) $mult
      set equationbar(isParam) $isParam
      set equationbar(table_data) $table_data
      set equationbar(desc) $desc
      set equationbar(comment) $comment
      set equationbar(min) $min
      set equationbar(max) $max


                                 ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
       return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        return
    }
                                ### End formula bar section

    set widget [$equation(top).properties.properties getframe]
    $widget.description.text delete 1.0 end
    $widget.description.text insert 1.0 $desc
#	$equation(top).main.cmtFrame.text delete 1.0 end
#	$equation(top).main.cmtFrame.text insert 1.0 $comment
    set widget [$equation(top).main.main getframe]
    $widget.equation.textbox.text delete 1.0 end
    $widget.equation.textbox.text insert 1.0 [ExtractGraphData $current_equation]
	set equation(units) $units
    set equation(mult) [join $mult ,]
	set equation(table_data) $table_data
	
	if {[set equation(isparam) $isParam]==-1} {
	    set paramMenuState disabled
	} else {
	    set paramMenuState normal
    }
    $widget.equation.textbox.radio0 configure -state $paramMenuState
    $widget.slider.radio1 configure -state $paramMenuState
    $widget.file.radio2 configure -state $paramMenuState
	set equation(min) $min
	set equation(max) $max
}
	
proc create_equation {parent boxtitle indices} {
    global equation 
    global equationbar

                                 ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        return
    }
                                ### End formula bar section

    set t [toplevel .equation -bd 4 -class Equation]
	set equation(top) $t
	wm title $t $boxtitle
    wm protocol $t WM_DELETE_WINDOW "equationCancel"
    equationResources

# Middle frame has the functions, indices and keypad, as well as the major buttons
    frame $t.middle
    TitleFrame $t.middle.functions -text "Functions: "
    set functionsf [$t.middle.functions getframe]
    frame $functionsf.list
    set lbf [listbox $functionsf.list.flist \
            -height 9 \
            -yscrollcommand [list $functionsf.list.scrollf set]]
    foreach funk $equation(fnDefs) {
        $lbf insert end $funk
    }
    scrollbar $functionsf.list.scrollf -command [list $lbf yview]
    pack $functionsf.list.flist -side left -fill both -expand true
    pack $functionsf.list.scrollf -side left -fill y
    pack $functionsf.list -anchor nw  -expand true -fill both
    pack $t.middle.functions -side left -anchor nw -padx 2 -pady 2 -expand true -fill both
    TitleFrame $t.middle.indices -text "Indices: "
    set indicesf [$t.middle.indices getframe]
    frame $indicesf.list
    set lbx [listbox $indicesf.list.ilist \
            -height 9 \
            -yscrollcommand [list $indicesf.list.scrolli set]]
    foreach indx $indices {
        $lbx insert end $indx
    }
    scrollbar $indicesf.list.scrolli -command [list $lbx yview]
    pack $indicesf.list.ilist -side left -fill both -expand true
    pack $indicesf.list.scrolli -side left -fill y
    pack $indicesf.list -anchor nw -expand true -fill both
    pack $t.middle.indices -side left -anchor nw  -padx 2 -pady 2 -expand true -fill both
# Stella special: a keypad frame to prevent users having to touch their kbd
    TitleFrame $t.middle.keypad -text "Keypad: "
    set keypadf [$t.middle.keypad getframe]
    frame $keypadf.keys
    set keys {< > -> = ( ) , / 7 8 9 * 4 5 6 - 1 2 3 + 0 dummy . DEL}
    for {set row 0} {$row < 6} {incr row} {
         pack [frame $keypadf.keys.row$row] -fill x
         for {set col 0} {$col < 4} {incr col} {
                set act [lindex $keys [expr 4*$row+$col]]
                pack [button $keypadf.keys.row$row.col$col \
                        -width 2 \
                        -text $act -command "HitKey $t \{$act\}"] \
                        -side left -fill x -expand true
         }
    }
# Make DEL button double width
    destroy $keypadf.keys.row5.col1
    pack $keypadf.keys.row5.col0 -expand false
    pack $keypadf.keys.row5.col2 -expand false
    pack $keypadf.keys -side left -anchor nw
    pack $t.middle.keypad -anchor nw -padx 2 -pady 2 -side left

    frame $t.middle.buttons
    set ok [button $t.middle.buttons.ok -command equationOK \
            -width 10 -default active -text "OK"]
    set can [button $t.middle.buttons.cancel -command equationCancel \
            -width 10 -text "Cancel"]
    set cmt [button $t.middle.buttons.comment \
            -width 10 -text "Comments..."]
    set help [button $t.middle.buttons.help -command {ContextSensitiveHelp .equation equations/dialogue.htm} \
            -width 10 -text "Help"]
    pack $ok -side top -padx 8 -pady 4 -anchor e
    pack $can -side top -padx 8 -pady 4 -anchor e
    pack $cmt -side top -padx 8 -pady 4 -anchor e
    pack $help -side top -padx 8 -pady 4 -anchor e
    pack $t.middle.buttons -anchor e -side left
    pack $t.middle -anchor nw -fill x
    
# Now for the main frame: the equation and its commentary
	frame $t.main
    TitleFrame $t.main.main -text "Data source: "
    set mainf [$t.main.main getframe]
    frame $mainf.slider
    radiobutton $mainf.slider.radio1 -text "Slider: " -variable equation(isparam) -value 1
    pack $mainf.slider.radio1 -side left
    pack [label $mainf.slider.minlabel -text Minimum] -side left -padx 4 -pady 4
    pack [entry $mainf.slider.minval -width 8 -textvariable equation(min)] -side left -padx 4 -pady 4
    pack [label $mainf.slider.maxlabel -text Maximum] -side left -padx 4 -pady 4
    pack [entry $mainf.slider.maxval -width 8 -textvariable equation(max)] -side right -padx 4 -pady 4
    pack $mainf.slider -anchor nw
    frame $mainf.file
    radiobutton $mainf.file.radio2 -text "File" -variable equation(isparam) -value 2
    pack $mainf.file.radio2 -side left
    pack $mainf.file -anchor nw
    frame $mainf.equation
    frame $mainf.equation.textbox
    radiobutton $mainf.equation.textbox.radio0 -text "Equation: " -variable equation(isparam) -value 0
    set en [text $mainf.equation.textbox.text -height 1 -width 30 -yscrollcommand "$mainf.equation.textbox.scroll set"]
    scrollbar $mainf.equation.textbox.scroll -orient vert -command "$mainf.equation.textbox.text yview"
    pack $mainf.equation.textbox.scroll -side right -fill y
    pack $mainf.equation.textbox.text -side right -expand true -fill both
    pack $mainf.equation.textbox.radio0 -anchor nw
    pack $mainf.equation.textbox -expand true -fill both -side left
    frame $mainf.equation.textbox.buttons
    set graph [button $mainf.equation.textbox.buttons.graph \
            -width 10 -text "Graph..."\
            -command "equationDoGraph $t $mainf.equation.textbox.text"]
    pack $graph -padx 8 -pady 4
    set table [button $mainf.equation.textbox.buttons.table \
            -width 10 -text "Table..."\
            -command "GetTable $t $mainf.equation.textbox.text"]
    pack $table -padx 8 -pady 4
    pack $mainf.equation.textbox.buttons -anchor e -side left
    pack $mainf.equation -expand true -fill both -anchor nw
    pack $t.main.main -anchor nw -expand true -fill both -padx 2 -pady 2
    pack $t.main -anchor nw -expand true -fill both

# Miscellaneous other stuff below
    frame $t.properties
    TitleFrame $t.properties.properties -text "Properties: "
    set propertiesf [$t.properties.properties getframe]
    frame $propertiesf.description
    label $propertiesf.description.desclabel -text "Description:"
    text $propertiesf.description.text -height 1 -width 20
    pack $propertiesf.description.desclabel -side left -padx 2 -pady 2
    pack $propertiesf.description.text -side left  -fill x -expand true -padx 2 -pady 2
    pack $propertiesf.description -side left  -fill x -expand true  -padx 4 -pady 4
    frame $propertiesf.units
    label $propertiesf.units.unitslabel -text "Units:"
    set eu [entry $propertiesf.units.entry -textvariable equation(units)]
    pack $propertiesf.units.unitslabel -side left  -padx 2 -pady 2
    pack $eu -side left -fill x -expand true -padx 2 -pady 2
    pack $propertiesf.units -side left -fill x -expand true  -padx 4 -pady 4

    frame $propertiesf.mult
    label $propertiesf.mult.multlabel -text "Dimensions:"
    set em [entry $propertiesf.mult.entry -textvariable equation(mult)]
    pack $propertiesf.mult.multlabel -side left  -padx 2 -pady 2
    pack $em -side left -fill x -expand true -padx 2 -pady 2
    pack $propertiesf.mult -side left -fill x -expand true  -padx 4 -pady 4

    pack $t.properties.properties -fill x -expand true -anchor nw \
	-padx 2 -pady 2
    pack $t.properties  -fill x  -anchor nw

# Bottom frame has the influences and parameters list boxes
    frame $t.bottom
    TitleFrame $t.bottom.influences -text "Influences: "
    set influencesf [$t.bottom.influences getframe]
    frame $influencesf.captions
    label $influencesf.captions.p -text "Parameter:"
    label $influencesf.captions.i -text "In units:"
    label $influencesf.captions.d -text "Dimensions:"
    pack $influencesf.captions.p $influencesf.captions.i \
	$influencesf.captions.d -side left -fill x -expand true
    pack $influencesf.captions -fill x
    frame $influencesf.lists
    set rollList [list $influencesf.lists.scroll $influencesf.lists.plist $influencesf.lists.ilist $influencesf.lists.dlist]
    set lbp [listbox $influencesf.lists.plist \
		-yscrollcommand [concat RollAll $rollList]]
    set lbi [listbox $influencesf.lists.ilist \
		-yscrollcommand [concat RollAll $rollList]]
    set lbd [listbox $influencesf.lists.dlist \
		-yscrollcommand [concat RollAll $rollList]]
    scrollbar $influencesf.lists.scroll -command [list ScrollAll \
						      [list $lbp $lbi $lbd]]
    pack $influencesf.lists.plist -side left -fill both -expand true
    pack $influencesf.lists.ilist -side left -fill both -expand true
    pack $influencesf.lists.dlist -side left -fill both -expand true
    pack $influencesf.lists.scroll -side left -fill y
    pack $influencesf.lists -side top -fill both -expand true
    pack $t.bottom.influences -fill x -expand true -anchor nw -padx 2 -pady 2
    pack $t.bottom -fill x 

    set equation(newGraphs) ""
    equationBindings $t $en $eu $lbp $lbi $lbd $lbf $lbx $graph $table $ok $can
    tkwait visibility $influencesf.lists.plist   
}

proc interact_equation {} {
	global equation
	global equationbar

                                 ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
	set equationbar(current_action) click
        return [list $equationbar(equation) \
         $equationbar(units) \
         $equationbar(isParam) \
         $equationbar(table_data) \
         $equationbar(desc) \
         $equationbar(comment) \
         $equationbar(min) \
         $equationbar(max)]
    }
                                 ### End formula bar section

    set t $equation(top)
    set descFrame [$equation(top).properties.properties getframe]
    set eqnFrame [$equation(top).main.main getframe]
    set listFrame [$equation(top).bottom.influences getframe]

    set equation(done) 0
    grab $t
    tkwait variable equation(done)
    grab release $t
    if {$equation(done)==1} {
	return [list [string trimright [CombineGraphData \
					    [$eqnFrame.equation.textbox.text get 1.0 end]]] \
		    $equation(units) $equation(isparam) \
		    \['[join $equation(table_data) ',']'\] \
		    [string trimright [$descFrame.description.text get 1.0 end]] \
		    [string trimright "No comment"] \
		    $equation(min) $equation(max)]
    } elseif {$equation(done)==2} {
	set rlist [list [lindex $equation(pathlist) $equation(ckLine)]]
	foreach list {plist ilist} {
	    set uselist $listFrame.lists.$list
	    if {[string match $uselist $equation(lbid)]} {
		lappend rlist $equation(listedit)
	    } else {
		lappend rlist [$uselist get $equation(ckLine)]
	    }
	}
	return $rlist
    }
}

proc destroy_equation {} {
	global equation
	global equationbar

                                 ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        return
    }
                                ### End formula bar section

	destroy $equation(top)
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

proc GetTable {parent box} {
    global equation table_entry

    if {[equationDoTable $parent]} {
	set equation(table_data) [concat [list $table_entry(fileName) \
		$table_entry(dataField)] $table_entry(indices)]
	if {![string match *table(*)* [$box get 1.0 end]]} {
	    $box insert insert table\(\[
	    for {set count [llength $table_entry(indices)]
	    if {!$count} {set count 1}} {$count>0} \
		    {incr count -1} {
		$box insert insert index\($count\),
	    }
	    $box delete [$box index {insert -1 chars}]
	    $box insert insert \]\)
	}
	    
    }
}

proc fill_inputs { triples } {
    global equation
	global equationbar


                                 ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        return
    }
                                 ### End formula bar section

    set t $equation(top)
    set widget [$equation(top).bottom.influences getframe]
	# Initialize variables and display  list
    set equation(pathlist) {}
    $widget.lists.plist delete 0 end
    $widget.lists.ilist delete 0 end 
    $widget.lists.dlist delete 0 end 

	foreach vpiTriple $triples {
	    lappend equation(pathlist) [lindex $vpiTriple 0]
        $widget.lists.plist insert end [lindex $vpiTriple 1]
        $widget.lists.ilist insert end [lindex $vpiTriple 2]
        $widget.lists.dlist insert end [lindex $vpiTriple 3]
	}

# Make box mode compact if not used
    set equation(listlength) [llength $triples]
    if {!$equation(listlength)} {
	pack forget $t.bottom
    } elseif {$equation(listlength)<=8} {
        $widget.lists.plist configure -height $equation(listlength)
        $widget.lists.ilist configure -height $equation(listlength)
        $widget.lists.dlist configure -height $equation(listlength)
        pack forget $widget.lists.scroll
    }
    set equation(selected,$widget.lists.plist) -1
    set equation(selected,$widget.lists.ilist) -1
}

proc equationBindings { t en eu lbp lbi lbd \
		lbf lbx gr ta ok can } {
	# t - toplevel
	# en - equation entry
	# eu - units entry

	# lbf - listbox for available functions
	# lbx - listbox for available indices
	# lbp - parameter listbox
	# lbi - input units listbox
	# gr - graph button
	# ta - table button
	# ok - OK button
	# can - Cancel button

	# Elimate the all binding tag because we
	# do our own focus management
	foreach w [list $en $eu $lbp $lbi $lbd $lbf $ok $can] {
	    bind $w <Button-1> ListEditDone
	    bindtags $w [list $t [winfo class $w] $w]
	}
	# Dialog-global cancel binding
	# Disabled because people type Ctrl-C to copy buffer into eqn box
	# bind $t <Control-c> equationCancel

	# Entry bindings
	foreach $w [list $en $eu] {
	    bind $w <Return> equationOK
	}
	set PopCmd [list QueuePopup "AddParamPopup %W %y %X %Y"]
	bind $lbp <Enter> $PopCmd
	bind $lbp <Motion> "RemovePopup;$PopCmd"
	bind $lbp <Leave> RemovePopup

	bind $lbp <Button-1> "equationClick %W %y"
	bind $lbp <Button-3> "equationRight %W %y"
	bind $lbp <Double-1> "equationDouble %W %y $en; focus $en"

	bind $lbi <Button-1> "equationClick %W %y"
	bind $lbi <Button-3> "equationRight %W %y"
	bind $lbi <Double-1> \
	    "equationDouble %W %y $eu; focus $eu; $eu icursor end"

	bind $lbf <Double-1> \
		"functionClick %W %y $en"
# popup boxes for functions
	set PopCmd [list QueuePopup "AddFnPopup %W %y %X %Y"]
	bind $lbf <Enter> $PopCmd
	bind $lbf <Motion> "RemovePopup;$PopCmd"
	bind $lbf <Leave> RemovePopup

	bind $lbx <Double-1> \
		"indexClick %W %y $en; focus $en"

	# Button focus.  Extract the underlined letter
	# from the button label to use as the focus key.
	foreach but [list $ok $can] {
	    set char [string tolower [string index [$but cget -text] \
					  [$but cget -underline]]]
	    bind $t <Alt-$char> "focus $but ; break"
	}
	bind $gr <Tab> "focus $ta"
	bind $ta <Tab> "focus $ok"
	bind $ok <Tab> "focus $can"
	bind $can <Tab> "focus $gr"

	# Set up for type in
	focus $en
}

proc equationDoGraph {parent box} {
    if {[equationGraph $parent] && \
	    ![string match *graph(*)* [$box get 1.0 end]]} {
	InsertFunction $box graph
    }
}

proc equationOK {} {
	global equation
	set equation(done) 1
}

proc equationCancel {} {
	global equation
	set equation(done) 0
}

proc equationClick { lb y } {
    global equation

    if {$equation(selected,$lb)==$y} {
	equationRight $lb $y
    } else {
	ListEditDone
	set equation(selected,$lb) -1
	after 500 [list set equation(selected,$lb) $y]
    }
}

proc equationRight { lb y } {
    global equation
#    if {![llength [$lb curselection]]} {
#	return
#    }
    ListEditDone
    if {$equation(done) == 2} {
# If an entry has already been edited, dont try to start editing another one
# because Prolog has to use the value entered for the old one first
	return
    }
    set ebox .equation.bottom.influences.f.lists.e
    set equation(lbid) $lb
    set equation(ckLine) [$lb nearest $y]
#    if {$ckLine == [$lb curselection]} {
	entry $ebox -textvariable equation(listedit)
	set equation(listedit) [$lb get $equation(ckLine)]
    place $ebox -in $lb \
	-rely [expr 1.0*$equation(ckLine)/$equation(listlength)] \
	-relwidth 1
    $ebox configure -font [$lb cget -font]
    $ebox select from 0
    $ebox select to end
    focus $ebox
    bind $ebox <Return> ListEditDone
#    }
	# Take the item the user clicked on
#	global equation
#	set $bname [$lb get [$lb nearest $y]]
}

proc ListEditDone {} {
    global equation
    set ebox .equation.bottom.influences.f.lists.e
    if {[winfo exists $ebox]} {
	if {[string compare $equation(listedit) \
		 [$equation(lbid) get $equation(ckLine)]]} {
	    set equation(done) 2
	}
	destroy $ebox
    }
}

proc equationDouble { lb y boxname} {
	# Take the item the user clicked on
	$boxname insert insert [$lb get [$lb nearest $y]]
}

proc HitKey { winId char } {
    if {[string match DEL $char]} {
	event generate $winId <Key-BackSpace>
    } elseif {[string match -> $char]} {
	event generate $winId <Key-Right>
    } else {
	[focus] insert insert $char
    }
}

proc functionClick { lb y boxname} {
	# Take the item the user clicked on
	InsertFunction $boxname [lindex [$lb get [$lb nearest $y]] 0]
}

proc AddFnPopup {lb y X Y} {
    AddWidgetPopup [lindex [$lb get [$lb nearest $y]] 0] $X $Y
}

proc AddParamPopup {lb y X Y} {
    global equation
    AddWidgetPopup "Value(s) of [lindex $equation(pathlist) [$lb nearest $y]]" \
	$X $Y
}

proc indexClick { lb y boxname} {
	# insert an index call using the line number clicked on
	$boxname insert insert index([expr [$lb nearest $y]+1])
}

proc InsertFunction {boxname functor} {
    if {[string match Text [winfo class $boxname]]} {
	set useRange [llength [$boxname tag ranges sel]]
	set insertCmd {mark set insert}
    } else {
	set useRange [$boxname select present]
	set insertCmd icursor
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
    focus $boxname
}

proc Disaggregate {parent title colour type fatness icount step \
            comment matherror hide separate} {
    global disaggregate
    
    foreach varName {colour type fatness icount step matherror hide \
                separate} {
        set disaggregate($varName) [set $varName]
    }
    set disaggregate(icount) [join $icount ,]
    
    set t [toplevel .disaggregation -bd 4 -class Disaggregation]
    #	wm transient $t $parent
    wm resizable $t 0 0
    wm protocol $t WM_DELETE_WINDOW {set disaggregate(done) 0}
    wm title $t "Properties of $title"
    
    
    frame $t.simple
    frame $t.simple.left
    
    TitleFrame $t.simple.left.count -text "Control of number of instances:"
    set countf [$t.simple.left.count getframe]
    
    frame $countf.radio
    foreach rbutton {{population "Using population symbols"} {generated "Using specified dimensions:"}} {
        radiobutton $countf.radio.$rbutton -text [lindex $rbutton 1] \
                -value [lindex $rbutton 0] \
                -variable disaggregate(type) \
                -command "SetHighlights $countf"
        pack $countf.radio.$rbutton -anchor w
    }
    pack $countf.radio -anchor w -side left
    
    Entry $countf.value -textvariable disaggregate(icount) -width 10
    pack $countf.value -side left -anchor s -pady 4
    pack $t.simple.left.count -expand 1 -fill both
    
    TitleFrame $t.simple.left.colour -text "Background shade"
    set colourf [$t.simple.left.colour getframe]
    pack [button $colourf.clear -text "Clear" \
            -width 10 -command "set disaggregate(colour) {}"]  \
            -padx 2 -pady 4 -side left
    pack [button $colourf.fixcolour -text "Colour" \
            -width 10 -bg $disaggregate(colour) -command "UpdateColour $colourf"]  \
            -padx 2 -pady 4 -side left
    pack $t.simple.left.colour -anchor w -pady 4 -fill both -expand true
    pack $t.simple.left -side left -expand 1 -fill both
    
    
    frame $t.simple.right
    button $t.simple.right.ok -text "OK" -width 10 -default active \
            -command {set disaggregate(done) 1}
    pack $t.simple.right.ok  -padx 2 -pady 4
    button $t.simple.right.cancel -text "Cancel" -width 10 \
            -command {set disaggregate(done) 0}
    pack $t.simple.right.cancel -padx 2 -pady 4
    button $t.simple.right.help -text "Help" -width 10 \
            -command {ContextSensitiveHelp .disaggregation submodels/dialogue.htm}
    pack $t.simple.right.help -padx 2 -pady 4
    button $t.simple.right.more -text "More" -width 10 -command "ShowComplexity $t"
    pack $t.simple.right.more -padx 2 -pady 4
    pack $t.simple.right -anchor ne -padx 4 -pady 4
    
    pack $t.simple -anchor nw -expand 1 -fill both
    
    
    label $t.commentlabel -text Comments:
    pack $t.commentlabel -padx 2 -pady 4
    text $t.comment -height 4 -width 40 -wrap word
    $t.comment insert 1.0 $comment
    pack $t.comment -anchor nw -fill both -expand true
    
    frame $t.complex
    
    TitleFrame $t.complex.appearance -text Appearance
    set appearancef [$t.complex.appearance getframe]
    checkbutton $appearancef.hide -text "Hide contents" \
            -variable disaggregate(hide)
    pack $appearancef.hide -anchor w
    frame $appearancef.scale
    scale $appearancef.scale.value -from .01 -to 1 -length 150 -orient horizontal \
            -resolution 0.01 -variable disaggregate(fatness)
    pack $appearancef.scale.value
    label $appearancef.scale.caption -text "Relative scale"
    pack $appearancef.scale.caption
    pack $appearancef.scale -anchor w
    pack $t.complex.appearance -anchor nw -side left -padx 4 -pady 4 -fill both -expand true
    
    TitleFrame $t.complex.math -text Calculation
    set mathf [$t.complex.math getframe]
    checkbutton $mathf.separate -text "Build submodel in separate dll" \
            -variable disaggregate(separate)
    pack $mathf.separate -anchor w
    checkbutton $mathf.matherror -text "Ignore math errors during calculation" \
            -variable disaggregate(matherror)
    pack $mathf.matherror -anchor w
    frame $mathf.step
    label $mathf.step.caption -text "Time step index:"
    pack $mathf.step.caption -side left
    #tk_optionMenu $mathf.step.pulldown disaggregate(step) Default -1 0 1 2 3 4 5 6 7
    ComboBox $mathf.step.pulldown -textvariable disaggregate(step) \
            -values "Default -1 0 1 2 3 4 5 6 7" -width 10 -editable false
    pack $mathf.step.pulldown
    pack $mathf.step -anchor w -padx 4 -pady 4
    pack $t.complex.math -side left -padx 4 -pady 4 -fill both -expand true
    
    # The above "complex" frame has been constructed, but is not packed until the "More" button is pressed
    #    pack $t.complex -anchor w
    
    SetHighlights $countf
    
    tkwait visibility $t
    grab $t
    tkwait variable disaggregate(done)
    grab release $t
    set disaggregate(comment) [string trimright [$t.comment get 1.0 end]]
    destroy $t
    if {$disaggregate(done)} {
        return [list $disaggregate(colour) $disaggregate(type) \
                $disaggregate(fatness) $disaggregate(icount) \
                $disaggregate(step) $disaggregate(comment) \
                $disaggregate(matherror) $disaggregate(hide) \
                $disaggregate(separate)]
    }
}

proc ShowComplexity {t} {
    if {[string match [$t.simple.right.more cget -text] More]} {
        pack $t.complex -anchor w
        $t.simple.right.more configure -text Less
    } else  {
        pack forget $t.complex
        $t.simple.right.more configure -text More
    }
}

proc UpdateColour {f} {
    global disaggregate
    
    set new [tk_chooseColor \
            -initialcolor $disaggregate(colour)]
    if {[llength $new]} {
        set disaggregate(colour) $new
        $f.fixcolour configure -bg $new
    }
}

proc SetHighlights {t} {
    global disaggregate
    
    switch -regexp $disaggregate(type) {
        none|population {
            $t.value configure -state disabled
        }
        simple|generated {
            $t.value configure -state normal
        }
    }
}

proc OpenProgressBox {{parent .}} {
    toplevel .progress 
    wm transient .progress $parent
    wm geometry .progress 400x100+0+0
    wm title .progress "Progress with current operation"
    message .progress.message -aspect 400 -text "Please wait"
    pack .progress.message -fill both -expand true
#    tkwait visibility .progress
    update
}

proc CloseProgressBox {} {
	destroy .progress
}

proc RelationCheck {parent title init_exc init_delay init_comment} {
    global relation
	
    set t [toplevel .relcheck -bd 4]
    wm resizable $t 0 0 
    wm protocol $t WM_DELETE_WINDOW {set relation(done) 0}
    wm title $t "Properties of $title"
    set relation(isexclusive) $init_exc
    set relation(useoldmemb) $init_delay
    frame .relcheck.top
    TitleFrame .relcheck.top.left -text "Association options:"
    set f [.relcheck.top.left getframe]
    pack [checkbutton $f.exclusive \
            -text "Exclusive role" -variable relation(isexclusive) -offvalue 0 -onvalue 1] -anchor w
#    BindPopup $f.exclusive exclusive
    pack [checkbutton $f.oldmemb \
            -text "Last membership" -variable relation(useoldmemb) -offvalue 0 -onvalue 1] -anchor w
#    BindPopup $f.oldmemb oldmemb
    pack .relcheck.top.left -side left -padx 4 -pady 4 -expand on -fill both -anchor nw
    frame .relcheck.top.right
    pack [button .relcheck.top.right.bdone \
            -text OK -width 10 -command {set relation(done) 1}] -padx 4 -pady 4
    pack [button .relcheck.top.right.bc \
            -text Cancel -width 10 -command {set relation(done) 0}] -padx 4 -pady 4
    pack [button .relcheck.top.right.help \
             -text Help -width 10 -command {ContextSensitiveHelp .relcheck submodels/association/dialogue.htm}] -padx 4 -pady 4
    pack .relcheck.top.right -side left
    pack .relcheck.top -expand on -fill both
    TitleFrame .relcheck.bottom -text "Comments:"
    set f [.relcheck.bottom getframe]
    pack [text $f.comment -width 40 -height 4 -wrap word] -anchor w -expand on -fill both -padx 2 -pady 2
    $f.comment delete 1.0 end
    $f.comment insert 1.0 $init_comment
    pack .relcheck.bottom
    
    tkwait visibility .relcheck
    grab .relcheck
    tkwait variable relation(done)
    grab release .relcheck
    set newComment [$f.comment get 1.0 end]
    destroy .relcheck

    return [list $relation(done) $relation(isexclusive) $relation(useoldmemb) \
	    $newComment]
}

proc GetFindText {parent} {
    global find
    set t [toplevel .findentry -bd 4]
    wm transient $t $parent
    wm protocol $t WM_DELETE_WINDOW {set find(done) 0}
    wm title $t "Find"
    wm resizable $t 0 0
    
    pack [message .findentry.m -text "Find caption containing text:" -width 300] -padx 0 -pady 2 -anchor nw
    pack [entry .findentry.e -width 30] -padx 5 -pady 4 -anchor nw
    bind .findentry.e <Return> "set find(done) 1"
    pack [set bs [frame .findentry.buttframe]]
    #pack [button $bs.clear -text Clear -width 10 -command ".findentry.e delete 0 end"] -padx 2 -pady 2 -side left
    pack [button $bs.ok -text OK -default active -width 10 -command "set find(done) 1"] -padx 2 -pady 4 -side left
    pack [button $bs.cancel -text Cancel -width 10 -command "set find(done) 0"] -padx 2 -pady 4
    
    tkwait visibility .findentry
    grab .findentry
    focus .findentry.e
    tkwait variable find(done)
    grab release .findentry
    set result [.findentry.e get]
    destroy .findentry
    if {$find(done)} {
        return $result
    }
}

proc DoRegDialog {} {
    global userinfo
    set t [toplevel .register -bd 4]
    wm title $t Registration
    wm transient $t
    wm protocol $t WM_DELETE_WINDOW {set userinfo(done) 0}

    pack [message .register.m -text "Registration enables us to keep you up-to-date with \
        your Simile installation.  We will contact you whenever we release a new \
        version of Simile.  Your personal information is not used for any other purpose."\
        -width 400] -pady 5
        
    pack [LabelEntry  .register.name  \
                -label "Name            " -labelanchor w -padx 5 \
                -textvariable userinfo(Name)] -fill x -pady 5
    pack [LabelEntry  .register.corp  -label "Company       " \
                        -labelanchor w -padx 5 -textvariable userinfo(Corp)] -fill x -pady 5
    pack [LabelEntry  .register.email -label "Email address" -labelanchor w -padx 5 \
                 -textvariable userinfo(email)]  -fill x -pady 5
    
    bind .register.email <Return> "set userinfo(done) 2"
    pack [set bs [frame .register.buttframe]] -pady 5
    pack [button $bs.enter -text "Register now" \
	    -command {set userinfo(done) 2}] -side left
    pack [button $bs.later -text "Register later" \
        -command {set userinfo(done) 0}] -side left
    pack [button $bs.cancel -text "Don't register" \
	    -command {set userinfo(done) 1}]

    tkwait visibility .register
    grab .register
    focus .register.email
    tkwait variable userinfo(done)
    grab release .register
    destroy .register
}

proc ContextSensitiveHelp {context page} {
    global tcl_platform
    if {[string match windows $tcl_platform(platform)]} {
        load winhelp
        package require winhelp
        winhelp $context ../Help/simile.chm $page
    }
}