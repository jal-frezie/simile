################################################################################
#####     PROCEDURES FOR EQUATION DIALOG BOX                               #####
################################################################################
# Yet another dialog box, this one for equation entry. Title is 'Equation for
# <name> (<units>)' and we need to keep the box up to display errors while entering
# the equation. Put up warning messages if the units change etc etc etc. 

proc equationResources {} {

    foreach entryBox {name description comment units vname pname iname} {
	option add *Equation*$entryBox.relief		sunken	startup
	option add *Equation*$entryBox.background	white	startup
	option add *Equation*$entryBox.foreground	black	startup
    }

    # Text for the labels on variable/parameter/unit entries
    option add *Equation*n.text		Equation:	startup
    option add *Equation*u.text		Units:		startup
    option add *Equation*v.text		Label:	startup
    option add *Equation*p.text		"Local name:"	startup
    option add *Equation*i.text		Units:		startup

    # Text for the OK and Cancel buttons
    option add *Equation*ok*text		OK	startup
    option add *Equation*ok*underline		0	startup
    option add *Equation*cancel.text		Cancel	startup
    option add *Equation*cancel.underline 	0	startup
    option add *Equation*graph.text		"Sketch graph..."	startup
    option add *Equation*graph.underline 	0	startup
    option add *Equation*table.text		"Load table..."	startup
    option add *Equation*table.underline 	0	startup

    # Size of the listboxes
    foreach listBox {vlist plist ilist} {
	option add *Equation*$listBox.width	20	startup
	option add *Equation*$listBox.height	10	startup
    }
}

proc fill_equation {current_equation units isParam \
		table_data desc comment min max} {
	global equation 
	global equationbar

      set equationbar(units) $units
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


	$equation(top).main.descFrame.text delete 1.0 end
	$equation(top).main.descFrame.text insert 1.0 $desc
	$equation(top).main.cmtFrame.text delete 1.0 end
	$equation(top).main.cmtFrame.text insert 1.0 $comment
	$equation(top).main.eqnFrame.text delete 1.0 end
	$equation(top).main.eqnFrame.text insert 1.0 \
			[ExtractGraphData $current_equation]
	set equation(units) $units
	set equation(table_data) $table_data
	
	if {[set equation(isparam) $isParam]==-1} {
	    set paramMenuState disabled
	} else {
	    set paramMenuState normal
	}
	for {set paramhood 0} {$paramhood <= 2} {incr paramhood} {
	    $equation(top).buttons.role.parambox.radio$paramhood configure \
		    -state $paramMenuState
	}
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

    wm transient $t $parent
    wm protocol $t WM_DELETE_WINDOW "equationCancel"

	set equation(top) $t
	wm title $t $boxtitle
	equationResources

	# Create entries for the variable, parameter and units fields
	# The values are kept in equation(vname, pname, iname)

	set equation(vname) ""
	set equation(pname) ""
	set equation(iname) ""

	frame $t.top
	pack $t.top -side top -fill x

	label $t.top.v -padx 0
	set ev [label $t.top.vname -textvariable equation(vname) -width 16]
	label $t.top.p -padx 0
	set ep [entry $t.top.pname -textvariable equation(pname) -width 16]
	label $t.top.i -padx 0
	set ei [entry $t.top.iname -textvariable equation(iname) -width 16]
        button $t.top.alter -text Alter -command "set equation(done) 2"
	
	pack $t.top.v -side left
	pack $t.top.vname -side left -fill x -expand true
	pack $t.top.p -side left
	pack $t.top.pname -side left -fill x -expand true
	pack $t.top.i -side left
	pack $t.top.iname -side left -fill x -expand true
        pack $t.top.alter

	frame $t.middle

	# Create three listboxen to hold the table contents
	# These will scroll in combination a riddly diddly dee
	# scroll bar is on the right hand side (I said...)

        set rollList [list $t.middle.scroll $t.middle.vlist \
		$t.middle.plist $t.middle.ilist]

	set lbv [listbox $t.middle.vlist \
		-yscrollcommand [concat RollAll $rollList]]
	set lbp [listbox $t.middle.plist \
		-yscrollcommand [concat RollAll $rollList]]
	set lbi [listbox $t.middle.ilist \
		-yscrollcommand [concat RollAll $rollList]]
	scrollbar $t.middle.scroll -command [list ScrollAll \
		[list $lbv $lbp $lbi]]

	# Create the OK and Cancel buttons
	# The OK button has a rim to indicate it is the default
	frame $t.buttons -bd 10

	frame $t.buttons.range
	pack [frame $t.buttons.range.min]
	pack [frame $t.buttons.range.max]
	pack [label $t.buttons.range.min.label -text Min.] -side left
	pack [label $t.buttons.range.max.label -text Max.] -side left
	pack [entry $t.buttons.range.min.val -textvariable equation(min)] -side right
	pack [entry $t.buttons.range.max.val -textvariable equation(max)] -side right
	frame $t.buttons.load
	set graph [button $t.buttons.load.graph \
		-command "equationDoGraph $t $t.main.eqnFrame.text"]
    pack $graph
	set table [button $t.buttons.load.table \
		-command "GetTable $t $t.main.eqnFrame.text"]
    pack $table
	frame $t.buttons.ok -bd 2 -relief sunken
	set ok [button $t.buttons.ok.b \
		-command equationOK]
	set can [button $t.buttons.cancel \
		-command equationCancel]

	# Pack the lists, scrollbar, and button box
	# in a horizontal stack below the upper widgets
	pack $t.middle -side top -fill both -expand true

	pack $t.middle.vlist -side left -fill both -expand true
	pack $t.middle.plist -side left -fill both -expand true
	pack $t.middle.ilist -side left -fill both -expand true
	pack $t.middle.scroll -side left -fill y

# now for the main inputs; the equation and its commentary
	frame $t.main

	# first a listbox with its own scrollbar for the available functions

        pack [set fnbox [frame $t.main.fnbox -border 5 -relief ridge]] -side left
        pack [label $fnbox.title -text "Available functions"]
	set lbf [listbox $fnbox.flist \
		-yscrollcommand [list $fnbox.scrollf set]]
	foreach funk $equation(fnDefs) {
		$lbf insert end $funk
	}	
	scrollbar $fnbox.scrollf -command [list $lbf yview]

	pack $fnbox.flist -side left -fill both
	pack $fnbox.scrollf -side left -fill y

	# Now the same thing for the table of available indices

        pack [set idxbox [frame $t.main.idxbox -border 5 -relief ridge]] -side left
        pack [label $idxbox.title -text "Available indices"]
	set lbx [listbox $idxbox.ilist \
		-yscrollcommand [list $idxbox.scrolli set]]
	foreach indx $indices {
		$lbx insert end $indx
	}	
	scrollbar $idxbox.scrolli -command [list $lbx yview]

	pack $idxbox.ilist -side left -fill both
	pack $idxbox.scrolli -side left -fill y

	# Stella special: a keypad frame to prevent users having to touch their kbd
	set keys {< > -> = ( ) , / 7 8 9 * 4 5 6 - 1 2 3 + 0 dummy . DEL}
	# backslash does not escape semicolon till button command executes
	set keypadLoc $t.main.keypad
	frame $keypadLoc -border 5 -relief ridge
	for {set row 0} {$row < 6} {incr row} {
		pack [frame $keypadLoc.row$row] -fill x
		for {set col 0} {$col < 4} {incr col} {
			set act [lindex $keys [expr 4*$row+$col]]
			pack [button $keypadLoc.row$row.col$col -font system \
				-text $act -command "HitKey $t \{$act\}"] \
				-side left -fill x -expand true
		}
	}
	# Now make 0 button double width
	destroy $keypadLoc.row5.col1
	pack $keypadLoc.row4.col2 -expand false
	pack $keypadLoc.row4.col3 -expand false

	pack $keypadLoc -side left

# Box for equation
	label $t.main.n -padx 0
	pack $t.main.n -side top
	pack [set frm [frame $t.main.eqnFrame]] -fill x -expand true
	set en [text $frm.text -height 3 -width 40 \
		-yscrollcommand "$frm.scrly set"]
	scrollbar $frm.scrly -orient vert -command "$frm.text yview"
	pack $frm.text -side left -fill both -expand true
	pack $frm.scrly -side right -fill y	
	
# Box for description -- scrollbar removed cos too small to look good on X
	label $t.main.desclabel -text Description:
	pack $t.main.desclabel -side top
	pack [set frm [frame $t.main.descFrame]] -fill x -expand true
	text $frm.text -height 1 -width 40
#		-yscrollcommand "$frm.scrly set"
#	scrollbar $frm.scrly -orient vert -command "$frm.text yview"
	pack $frm.text -side left -fill both -expand true
#	pack $frm.scrly -side right -fill y	

# Box for comments
	label $t.main.cmtlabel -text Comments:
	pack $t.main.cmtlabel -side top
	pack [set frm [frame $t.main.cmtFrame]] -fill x -expand true
	text $frm.text -height 3 -width 40 \
		-yscrollcommand "$frm.scrly set"
	scrollbar $frm.scrly -orient vert -command "$frm.text yview"
	pack $frm.text -side left -fill both -expand true
	pack $frm.scrly -side right -fill y	

# Other stuff at bottom
	pack [frame $t.buttons.role] -side left
	pack [frame $t.buttons.role.parambox]
	pack [frame $t.buttons.range.unitbox]
	pack [label $t.buttons.range.unitbox.u -padx 0] -side left
	set eu [entry $t.buttons.range.unitbox.units \
		-textvariable equation(units)]
	pack $eu -side left -fill x -expand true

	for {set paramhood 0} {$paramhood <= 2} {incr paramhood} {
	    pack [radiobutton $t.buttons.role.parambox.radio$paramhood \
		    -text [lindex {{Has equation} {Input parameter} \
		        {File parameter}} $paramhood] \
		    -variable equation(isparam) -value $paramhood]
	}
	pack $t.buttons.range $t.buttons.load $t.buttons.ok $t.buttons.cancel \
		-side left -padx 10 -pady 5
	pack $t.buttons.ok.b -padx 4 -pady 4

	pack $t.buttons -side bottom -fill both
	pack $t.main -side bottom -fill both

	set equation(newGraphs) ""
	equationBindings $t $en $eu $ev $ep $ei $lbv $lbp $lbi \
			$lbf $lbx $graph $table $ok $can
	tkwait visibility $t.middle.vlist   
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
	grab $t
	tkwait variable equation(done)
	grab release $t
	if {$equation(done)==1} {
	    return [list [string trimright \
	          [CombineGraphData [$t.main.eqnFrame.text get 1.0 end]]] \
		    $equation(units) \
	          $equation(isparam) \
		    \['[join $equation(table_data) ',']'\] \
		    [string trimright [$t.main.descFrame.text get 1.0 end]] \
		    [string trimright [$t.main.cmtFrame.text get 1.0 end]] \
			$equation(min) $equation(max)]
	} elseif {$equation(done)==2} {
	    return [list $equation(vname) $equation(pname) $equation(iname)]
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
	# Initialize variables and display  list
	$t.middle.vlist delete 0 end
	$t.middle.plist delete 0 end
	$t.middle.ilist delete 0 end

	foreach vpiTriple $triples {
		$t.middle.vlist insert end [lindex $vpiTriple 0]
		$t.middle.plist insert end [lindex $vpiTriple 1]
		$t.middle.ilist insert end [lindex $vpiTriple 2]
	}
}

proc equationBindings { t en eu ev ep ei lbv lbp lbi \
		lbf lbx gr ta ok can } {
	# t - toplevel
	# en - equation entry
	# eu - units entry
	# ev - variable entry box
	# ep - parameter entry box
	# ei - input units entry box

	# lbf - listbox for available functions
	# lbx - listbox for available indices
	# lbv - variable listbox
	# lbp - parameter listbox
	# lbi - input units listbox
	# gr - graph button
	# ta - table button
	# ok - OK button
	# can - Cancel button

	# Elimate the all binding tag because we
	# do our own focus management
	foreach w [list $en $eu $ev $ep $ei $lbv $lbp $lbi \
			$lbf $ok $can] {
	    bindtags $w [list $t [winfo class $w] $w]
	}
	# Dialog-global cancel binding
	# Disabled because people type Ctrl-C to copy buffer into eqn box
	# bind $t <Control-c> equationCancel

	# Entry bindings
	foreach $w [list $en $eu $ev $ep $ei] {
	    bind $w <Return> equationOK
	}

	# A double click, or <space>, puts the name in the entry
	bind $lbv <space> "equationTake $%W  equation(vname); focus $ev"
	bind $lbv <Double-1> \
		"equationClick %W %y equation(vname); focus $ev"

	bind $lbp <space> "equationTake $%W  equation(pname); focus $ep"
	bind $lbp <Button-1> \
		"equationClick %W %y equation(pname); focus $ep"
	bind $lbp <Double-1> \
		"equationDouble %W %y $en; focus $en"

	bind $lbi <space> "equationTake $%W  equation(iname); focus $ei"
	bind $lbi <Button-1> \
		"equationClick %W %y equation(iname); focus $ei"
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
		set char [string tolower [string index  \
			[$but cget -text] [$but cget -underline]]]
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

# Tricky bit: let's say clicking in either listbox loads the item into
# the corresponding edit box...ie add boxname to call. (good tcl feature!)

proc equationClick { lb y bname} {
	# Take the item the user clicked on
	global equation
	set $bname [$lb get [$lb nearest $y]]
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

proc equationTake { lb bname} {
	# Take the currently selected list item
	global equation
	set $bname [$lb get [$lb curselection]]
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
	wm transient $t $parent
	wm protocol $t WM_DELETE_WINDOW {set disaggregate(done) 0}
	wm title $t "Instances of $title"

	frame $t.radio
	foreach rbutton {{generated "Generated set"} {population "Population"}} {
		radiobutton $t.radio.$rbutton -text [lindex $rbutton 1] \
			-value [lindex $rbutton 0] \
			-variable disaggregate(type) -relief raised \
			-command "SetHighlights $t"
		pack $t.radio.$rbutton -side left
		}
	pack $t.radio

	frame $t.count
	label $t.count.caption -text "Dimensions:"
	pack $t.count.caption -side left
	entry $t.count.value -textvariable disaggregate(icount)
	pack $t.count.value -side left
	pack $t.count

	frame $t.fatness
	label $t.fatness.caption -text "Graphical\nfatness:"
	pack $t.fatness.caption -side left
	scale $t.fatness.value -from .01 -to 1 -length 200 -orient horizontal \
		-resolution 0.01 -variable disaggregate(fatness)
	pack $t.fatness.value -side left
	pack $t.fatness

	frame $t.steps
	label $t.steps.caption -text "Time step:"
	pack $t.steps.caption -side left
	tk_optionMenu $t.steps.pulldown disaggregate(step) \
		Default -1 0 1 2 3 4 5 6 7
	pack $t.steps.pulldown -side left
	checkbutton $t.steps.hide -text "Hide contents" \
		-variable disaggregate(hide) -relief raised
	pack $t.steps.hide -side left
	checkbutton $t.steps.separate -text "Build separately" \
		-variable disaggregate(separate) -relief raised
	pack $t.steps.separate -side left
#	menubutton $t.steps.depthb -relief raised -text "Show detail..."
#	menu $t.steps.depthb.m
#	AddDetailMenu $t.steps.depthb.m SetDepthArg $args
#	$t.steps.depthb configure -menu $t.steps.depthb.m
#	pack $t.steps.depthb -side left
	pack $t.steps
	frame $t.colour
	pack [button $t.colour.fixcolour -text "Background shade" \
		-bg $disaggregate(colour) -command UpdateColour] -side right
	pack [button $t.colour.clear -text "Clear background" \
		-command "set disaggregate(colour) {}"] -side right
	pack $t.colour

	label $t.commentlabel -text Comments:
	pack $t.commentlabel
	text $t.comment -height 4 -width 40
	$t.comment insert 1.0 $comment
	pack $t.comment -fill both -expand true

	frame $t.exit
	checkbutton $t.exit.matherror -text "Ignore math errors" \
		-variable disaggregate(matherror) -relief raised
	pack $t.exit.matherror -side left
	button $t.exit.done -text "Done" -command {set disaggregate(done) 1}
	pack $t.exit.done -side left
	button $t.exit.cancel -text "Cancel" -command {set disaggregate(done) 0}
	pack $t.exit.cancel -side left
	pack $t.exit

	SetHighlights $t

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

proc UpdateColour {} {
	global disaggregate

	set new [tk_chooseColor \
			-initialcolor $disaggregate(colour)]
	if {[llength $new]} {
	    set disaggregate(colour) $new
	    .disaggregation.colour.fixcolour configure -bg $new
	}
}

proc SetHighlights {t} {
	global disaggregate

    switch -regexp $disaggregate(type) {
	none|population {
		$t.count.value configure -state disabled
	} 
	simple|generated {
	    $t.count.value configure -state normal
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
    wm transient $t $parent
    wm protocol $t WM_DELETE_WINDOW {set relation(done) 0}
    wm title $t "Properties of relation $title"
    set relation(isexclusive) $init_exc
    set relation(useoldmemb) $init_delay
    pack [checkbutton .relcheck.exclusive \
		-text "Exclusive role" \
		-variable relation(isexclusive) -offvalue 0 -onvalue 1]
    BindPopup .relcheck.exclusive exclusive
    pack [checkbutton .relcheck.oldmemb \
		-text "Last membership" \
		-variable relation(useoldmemb) -offvalue 0 -onvalue 1]
    BindPopup .relcheck.oldmemb oldmemb
    pack [text .relcheck.comment -width 32 -height 4]
    pack [button .relcheck.bdone -text OK -command {set relation(done) 1}] \
	    -side left
    pack [button .relcheck.bc -text Cancel -command {set relation(done) 0}] \
	    -side left
    .relcheck.comment delete 1.0 end
    .relcheck.comment insert 1.0 $init_comment

    tkwait visibility .relcheck
    grab .relcheck
    tkwait variable relation(done)
    grab release .relcheck
    set newComment [.relcheck.comment get 1.0 end]
    destroy .relcheck

    return [list $relation(done) $relation(isexclusive) $relation(useoldmemb) \
	    $newComment]
}

proc GetFindText {parent} {
    global find
    set t [toplevel .findentry -bd 4]
    wm transient $t $parent
    wm protocol $t WM_DELETE_WINDOW {set find(done) 0}

    pack [message .findentry.m -text "Find caption containing:"]
    pack [entry .findentry.e]
    bind .findentry.e <Return> "set find(done) 1"
    pack [set bs [frame .findentry.buttframe]]
    pack [button $bs.enter -text Enter -command "set find(done) 1"] -side left
    pack [button $bs.clear -text Clear -command ".findentry.e delete 0 end"] \
	    -side left
    pack [button $bs.cancel -text Cancel -command "set find(done) 0"]

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
