################################################################################
#####     PROCEDURES FOR EQUATION DIALOG BOX                               #####
################################################################################
# Yet another dialog box, this one for equation entry. Title is 'Equation for
# <name> (<units>)' and we need to keep the box up to display errors while entering
# the equation. Put up warning messages if the units change etc etc etc.

package require BWidget
catch {namespace import BWidget::*}

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
    #     option add *Equation*graph.underline 	1	startup
    #    option add *Equation*table.text		"Table..."	startup
    #     option add *Equation*table.underline 	1	startup
    
    # Size of the listboxes
    foreach listBox {plist ilist} {
        option add *Equation*$listBox.width	15	startup
        option add *Equation*$listBox.height	4	startup
    }
}

proc fill_equation {current_equation units mult isParam \
            table_data table_values desc comment min max} {
    
    global equation
    global equationbar
    
    set equationbar(units) $units
    #      set equationbar(mult) $mult
    set equationbar(isParam) $isParam
    set equationbar(table_data) $table_data
    set equationbar(table_values) $table_values
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
    
    set widget [$equation(doc).descf.description getframe]
    $widget.text delete 1.0 end
    $widget.text insert 1.0 $desc
    $equation(doc).cmtFrame.text delete 1.0 end
    $equation(doc).cmtFrame.text insert 1.0 $comment
    set widget [$equation(main).main.main getframe]
    $widget.equation.textbox.text delete 1.0 end
    $widget.equation.textbox.text insert 1.0 [ExtractGraphData $current_equation]
    set equation(units) $units
    set equation(mult) [join $mult ,]
    set equation(table_data) $table_data
    set equation(table_values) $table_values
    
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
    wm title $t $boxtitle
    wm transient $t $parent
    set equation(top) $t
    wm protocol $t WM_DELETE_WINDOW "equationCancel"
    equationResources
    
    set notebook [NoteBook $t.notebook]
    $notebook insert end Main -text Main
    set mainF [$notebook getframe Main]
    $notebook insert end Documentation -text Documentation
    set docF [$notebook getframe Documentation]
    set equation(notebook) $notebook
    set equation(main) $mainF
    set equation(doc) $docF
    
    # frame for buttons
    set buttonF [frame $t.buttons]
    set ok [button $buttonF.ok -command equationOK \
            -width 10 -default active -text "OK"]
    set can [button $buttonF.cancel -command equationCancel \
            -width 10 -text "Cancel"]
    set help [button $buttonF.help -command {ContextSensitiveHelp .equation equations/dialogue.htm} \
            -width 10 -text "Help"]
    pack $help -side right -padx 8 -pady 4 -anchor e
    pack $can -side right -padx 8 -pady 4 -anchor e
    pack $ok -side right -padx 8 -pady 4 -anchor e
    #    pack $buttonF.buttons -anchor e -side left
    pack $buttonF -anchor nw -fill x -side bottom
    
    # Middle frame has the functions, indices and keypad
    # created variable middleF to point to the Middle frame makes moving the frame in
    # the widget hierrachy easier Jonathan 22 Aug 2002
    set middleF [frame $mainF.middle]
    TitleFrame $middleF.functions -text "Functions: "
    set functionsf [$middleF.functions getframe]
    frame $functionsf.list
    set lbf [listbox $functionsf.list.flist \
            -height 8 -width 16 \
            -yscrollcommand [list $functionsf.list.scrollf set]]
    foreach funk $equation(fnDefs) {
        $lbf insert end $funk
    }
    scrollbar $functionsf.list.scrollf -command [list $lbf yview]
    pack $functionsf.list.flist -side left -fill both -expand true
    pack $functionsf.list.scrollf -side left -fill y
    pack $functionsf.list -anchor nw  -expand true -fill both
    pack $middleF.functions -side left -anchor nw -padx 2 -pady 2 -expand true -fill both
    TitleFrame $middleF.indices -text "Indices: "
    set indicesf [$middleF.indices getframe]
    frame $indicesf.list
    set lbx [listbox $indicesf.list.ilist \
            -height 8 -width 12 \
            -yscrollcommand [list $indicesf.list.scrolli set]]
    foreach indx $indices {
        $lbx insert end $indx
    }
    scrollbar $indicesf.list.scrolli -command [list $lbx yview]
    pack $indicesf.list.ilist -side left -fill both -expand true
    pack $indicesf.list.scrolli -side left -fill y
    pack $indicesf.list -anchor nw -expand true -fill both
    pack $middleF.indices -side left -anchor nw  -padx 2 -pady 2 -expand true -fill both
    
    # Stella special: a keypad frame to prevent users having to touch their kbd
    TitleFrame $middleF.keypad -text "Keypad: "
    set keypadf [$middleF.keypad getframe]
    frame $keypadf.keys
    set keys {< > ( ) \{ \} \[ \] = _ , / and dummy if dummy 7 8 9 * or dummy then dummy \
                4 5 6 - not dummy elseif dummy 1 2 3 + xor dummy else dummy 0 .  <- -> DEL \
                dummy SPACE dummy}
    for {set row 0} {$row < 6} {incr row} {
        pack [frame $keypadf.keys.row$row] -fill x
        for {set col 0} {$col < 8} {incr col} {
            set act [lindex $keys [expr 8*$row+$col]]
            if {[string match {\[} $act]} {
                pack [button $keypadf.keys.row$row.col$col \
                        -width 2 \
                        -text $act -command "HitKey $t \\$act"] \
                        -side left -fill x -expand false
            } else  {
                pack [button $keypadf.keys.row$row.col$col \
                        -width 2 \
                        -text $act -command "HitKey $t \"$act\""] \
                        -side left -fill x -expand false
                
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
    pack $middleF.keypad -anchor nw -padx 2 -pady 2 -side left -fill y
    pack $middleF -expand off -fill x
    
    
    # Now for the main frame: the equation and its commentary
    frame $mainF.main
    TitleFrame $mainF.main.main -text "Data source: "
    set mainf [$mainF.main.main getframe]
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
    
    regsub { for } $boxtitle {: } eqnRBtext
    radiobutton $mainf.equation.textbox.radio0 -text "$eqnRBtext = " -variable equation(isparam) -value 0
    
    set en [text $mainf.equation.textbox.text -height 4 -width 80 -yscrollcommand "$mainf.equation.textbox.scroll set"]
    scrollbar $mainf.equation.textbox.scroll -orient vert -command "$mainf.equation.textbox.text yview"
    pack $mainf.equation.textbox.scroll -side right -fill y
    pack $mainf.equation.textbox.text -side right -expand true -fill both
    pack $mainf.equation.textbox.radio0 -anchor nw
    pack $mainf.equation.textbox -expand true -fill both -side left
    frame $mainf.equation.textbox.buttons
    
    set grfimg [image create photo -file "../Images/Toolbar/graph.gif"]
    set tblimg [image create photo -file "../Images/Toolbar/table.gif"]
    set graph [button $mainf.equation.textbox.buttons.graph \
            -compound left -image $grfimg -text " Graph... "\
            -command "equationDoGraph $t $mainf.equation.textbox.text"]
    pack $graph -padx 8 -pady 4
    set table [button $mainf.equation.textbox.buttons.table \
            -compound left -image $tblimg -text " Table... "\
            -command "GetTable $t $mainf.equation.textbox.text"]
    pack $table -padx 8 -pady 4
    pack $mainf.equation.textbox.buttons -anchor e -side left
    pack $mainf.equation -expand true -fill both -anchor nw
    pack $mainF.main.main -anchor nw -expand true -fill both -padx 2 -pady 2 -side left
    
    pack $mainF.main -anchor nw -expand true -fill both -anchor nw
    
    # Miscellaneous other stuff below
    # Bottom frame has the influences and parameters list boxes
    set bottomF [frame $mainF.bottom]
    TitleFrame $bottomF.influences -text "Influences: "
    set influencesf [$bottomF.influences getframe]
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
    pack $bottomF.influences -fill x -expand true -anchor nw -padx 2 -pady 2
    pack $bottomF -fill x
    
    # comments in the Documentation page
    
    set descF [frame $docF.descf]
    TitleFrame $descF.description -text "Title: "
    set descf [$descF.description getframe]
    label $descf.desclabel -text "Description:"
    text $descf.text -height 1 -width 20
    pack $descf.desclabel -side left -padx 2 -pady 2
    pack $descf.text -side left  -fill x -expand true -padx 2 -pady 2
    pack $descf -side top  -fill x -expand off
    pack $descF.description  -fill x -expand off -padx 4 -pady 4
    pack $docF.descf -fill x -expand off
    
    label $docF.cmtlabel -text Comments:
    pack $docF.cmtlabel -side top
    pack [set frm [frame $docF.cmtFrame]] -fill both -expand true
    text $frm.text -height 3 -width 40 -wrap word \
            -yscrollcommand "$frm.scrly set"
    scrollbar $frm.scrly -orient vert -command "$frm.text yview"
    pack $frm.text -side left -fill both -expand true
    pack $frm.scrly -side right -fill y
    
    set propertiesF [frame $docF.properties]
    TitleFrame $propertiesF.properties -text "Properties: "
    set propertiesf [$propertiesF.properties getframe]
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
    
    pack $propertiesF.properties -fill x -expand true -anchor nw \
            -padx 2 -pady 2
    pack $propertiesF  -fill x  -anchor nw
    
    
    
    $notebook raise Main
    pack $notebook -fill both -expand true
    $notebook compute_size
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
                \['[join $equationbar(table_data) ',']'\] \
                $equationbar(table_values) \
                $equationbar(desc) \
                $equationbar(comment) \
                $equationbar(min) \
                $equationbar(max)]
    }
    ### End formula bar section
    set t $equation(top)
    set descFrame [$equation(doc).descf.description getframe]
    set eqnFrame [$equation(main).main.main getframe]
    set listFrame [$equation(main).bottom.influences getframe]
    
    set equation(done) 0
    grab $t
    tkwait variable equation(done)
    grab release $t
    if {$equation(done)==1} {
        return [list [string trimright [CombineGraphData \
                [$eqnFrame.equation.textbox.text get 1.0 end]]] \
                $equation(units) $equation(isparam) \
                \['[join $equation(table_data) ',']'\] \
                $equation(table_values) \
                [string trimright [$descFrame.text get 1.0 end]] \
                [string trimright [$equation(doc).cmtFrame.text get 1.0 end]] \
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
        set equation(table_values) [LoadTableData $equation(table_data)]
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
    
    set t $equation(main)
    set widget [$equation(main).bottom.influences getframe]
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
    
    #    pack $t.bottom -fill x -expand true
    $equation(notebook) compute_size
    pack $equation(notebook)
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
    set PopCmd [list QueuePopup AddParamPopup %W %y %X %Y]
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
    set PopCmd [list QueuePopup AddFnPopup %W %y %X %Y]
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
    set widget [$equation(main).bottom.influences getframe]
    set ebox $widget.lists.e
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
    set widget [$equation(main).bottom.influences getframe]
    set ebox $widget.lists.e
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
    } elseif {[string match <- $char]} {
        event generate $winId <Key-Left>
    } elseif {[string match SPACE $char]} {
        event generate $winId <Key-space>
    } elseif {[string match \{ $char]} {
        event generate $winId <Key-braceleft>
    } elseif {[string match \} $char]} {
        event generate $winId <Key-braceright>
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
    if [llength $icount]>0 {
        set disaggregate(icount) [join $icount ,]
    } else  {
        set disaggregate(icount) 1
    }
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
            -width 10 -command "UpdateColour $colourf"]  \
            -padx 2 -pady 4 -side left
    if {[catch {image type $disaggregate(colour)}]} {
        $colourf.fixcolour configure -bg $disaggregate(colour)
        set disaggregate(defColour) $disaggregate(colour)
    } else {
        set disaggregate(defColour) [$colourf.fixcolour cget -bg]
    }
    pack [button $colourf.setimage -text "Image..." \
            -width 10 -command ChooseImage] \
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
#    checkbutton $mathf.matherror -text "Ignore math errors during calculation" \
#            -variable disaggregate(matherror)
#    pack $mathf.matherror -anchor w
    frame $mathf.step
    label $mathf.step.caption -text "Time step index:"
    pack $mathf.step.caption -side left
    #tk_optionMenu $mathf.step.pulldown disaggregate(step) Default -1 0 1 2 3 4 5 6 7
    ComboBox $mathf.step.pulldown -textvariable disaggregate(step) \
            -values "Default -1 0 1 2 3 4 5 6 7" -width 10 -editable false
    pack $mathf.step.pulldown
    pack $mathf.step -anchor w -padx 4 -pady 6
    pack $t.complex.math -side left -padx 4 -pady 4 -fill both -expand true
    
    # The above "complex" frame has been constructed, but is not packed until the "More" button is pressed
    # unless, conditional expressions indicate that one of the complex attributes does not have its default
    # value
    #    pack $t.complex -anchor w
    if (![string match $disaggregate(step) Default]) {
        ShowComplexity $t
    } elseif ($disaggregate(matherror)) {
        ShowComplexity $t
    } elseif ($disaggregate(separate)) {
        ShowComplexity $t
    } elseif ($disaggregate(fatness)!=1.0) {
        ShowComplexity $t
    } elseif ($disaggregate(hide)) {
        ShowComplexity $t
    }
    
    SetHighlights $countf
    
    tkwait visibility $t
    grab $t
    tkwait variable disaggregate(done)
    grab release $t
    set disaggregate(comment) [string trimright [$t.comment get 1.0 end]]
    destroy $t
    if [string match $disaggregate(icount) 1] {
        set disaggregate(icount) [list]
    }
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
            -initialcolor $disaggregate(defColour)]
    if {[llength $new]} {
        set disaggregate(colour) $new
        set disaggregate(defColour) $new
        $f.fixcolour configure -bg $new
    }
}

set imageSources(uid) 0
package require Img

proc ChooseImage {} {
    global disaggregate
    global imageSources
    
    set newImage backgnd$imageSources(uid)
    while {![catch {image type $newImage}]} {
        incr imageSources(uid)
        set newImage backgnd$imageSources(uid)
    }
    image create photo $newImage
    set choosing 1
    while {$choosing} {
        set new [ChooseFile image.gif {Image for model background} 0]
        if {[llength $new]} {
            if {[catch {$newImage read $new -shrink} readFlop]} {
                ShowMessage {Problem loading file} error $readFlop ok
                # prevent crasho if reading fails
                #		$newImage config -width 100 -height 100
            } else {
                set xtn [string trimleft [file extension $new] .]
                if {[string match jpg $xtn]} {
                    set fmt jpeg
                } else {
                    set fmt $xtn
                }
                $newImage config -format $fmt
                set disaggregate(colour) $newImage
                PutSize $newImage
                set choosing 0
            }
        } else {
            set choosing 0
        }
    }
}

proc PutSize {img} {
    set width 0
    while {![catch {$img get $width 0}]} {
        incr width
    }
    set height 0
    while {![catch {$img get 0 $height}]} {
        incr height
    }
    # set them so I can read later
    $img config -width $width -height $height
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
    # GUI access to Last membership checkbox denied, although it is used for the Rantan Pandau model
    #    pack [checkbutton $f.oldmemb \
    #           -text "Last membership" -variable relation(useoldmemb) -offvalue 0 -onvalue 1] -anchor w
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
    set ft [frame .findentry.ft]
    pack [message $ft.m -text "Find text:" -width 300] -padx 4 -pady 6 -anchor nw -side left
    pack [entry $ft.e -width 40] -padx 4 -pady 6 -anchor nw -side left
    bind $ft.e <Return> "set find(done) 1"
    pack .findentry.ft -anchor nw -fill both
    TitleFrame .findentry.rbs -text "Search for text in"
    set rbs [.findentry.rbs getframe]
    set find(where) caption
    radiobutton $rbs.r1 -text "Captions" -variable find(where) -value caption
    radiobutton $rbs.r2 -text "Equations" -variable find(where) -value equation
    radiobutton $rbs.r3 -text "Descriptions and comments" \
            -variable find(where) -value description
    pack $rbs.r1 -anchor nw
    pack $rbs.r2 -anchor nw
    pack $rbs.r3 -anchor nw
    pack $rbs -anchor nw -fill both -padx 4 -pady 4
    pack .findentry.rbs -anchor nw -fill both
    pack [set bs [frame .findentry.buttframe]]
    #pack [button $bs.clear -text Clear -width 10 -command ".findentry.e delete 0 end"] -padx 2 -pady 2 -side left
    pack [button $bs.ok -text OK -default active -width 10 -command "set find(done) 1"] -padx 2 -pady 4 -side left
    pack [button $bs.cancel -text Cancel -width 10 -command "set find(done) 0"] -padx 2 -pady 4 -side left
    pack [button $bs.help -text Help -width 10 -command "ContextSensitiveHelp .findentry diagrams/search.htm"] -padx 2 -pady 4 -side left
    
    tkwait visibility .findentry
    grab .findentry
    focus $ft.e
    tkwait variable find(done)
    grab release .findentry
    set result [$ft.e get]
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
    
    # Lord I dont know what is this fascination with hi-tech multi-function
    # bug-ridden widgets, I'll just put the old version back, at least that
    # works...
    #    pack [LabelEntry  .register.name  \
    #                -label "Name            " -labelanchor w -padx 5 \
    #                -textvariable userinfo(Name)] -fill x -pady 5
    #    pack [LabelEntry  .register.corp  -label "Company       " \
    #                        -labelanchor w -padx 5 -textvariable userinfo(Corp)] -fill x -pady 5
    #    pack [LabelEntry  .register.email -label "Email address" -labelanchor w -padx 5 \
    #                 -textvariable userinfo(email)]  -fill x -pady 5
    
    foreach {field label} {name "Name:" corp "Company:" \
                email "Email address:"} {
        pack [frame .register.$field] -fill x -expand true
        pack [label .register.$field.l -width 15 -text $label] -side left
        pack [entry .register.$field.e -textvariable userinfo($field)] \
                -fill x -expand true
    }
    
    
    bind .register.email.e <Return> "set userinfo(done) 2"
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
    global tcl_platform helphtml
    if { [string match windows $tcl_platform(platform)]} {
            package require winhelp
            winhelp $context ../Help/simile.chm $page
    } else {
            set url [pwd]/../Help/$page
            expr {
                [info exists env(BROWSER)] ||
                [findExecutable mozilla        env(BROWSER)] ||
                [findExecutable netscape       env(BROWSER)] ||
                [findExecutable iexplorer      env(BROWSER)] ||
                [findExecutable $env(NETSCAPE) env(BROWSER)] ||
                [findExecutable lynx           env(BROWSER)]
            }
            # lynx can also output formatted text to a variable
            # with the -dump option, as a last resort:
            # set formatted_text [ exec lynx -dump $url ] - PSE
            if {[catch {exec $env(BROWSER) -remote $url}]} {
                # perhaps browser doesn't understand -remote flag
                if {[catch {exec $env(BROWSER) $url &} emsg]} {
                    error "Error displaying $url in browser\n$emsg"
                    # Another possibility is to just pop a window up
                    # with the URL to visit in it. - DKF
                }
           }        
    }
}

proc findExecutable {progname varname} {
     upvar 1 $varname result
     set progs [auto_execok $progname]
     if {[llength $progs]} {
         set result [lindex $progs 0]
     }
     return [llength $progs]
 }

proc CheckHyper {ywhat} {
    return 0
}

proc GoHyper {ywhat} {
    ShowMessage debug info $ywhat ok
}

proc ResolveHyper {args} {
    ShowMessage debug info "Resolving $args" ok
    return {}
}

proc ErrorHelp {diagnostic} {
    global diagno url help
    toplevel .diag
    wm title .diag {Error diagnostics}
    set parent [focus]
    if {[llength $parent]} {
	wm transient .diag $parent
    }
    wm protocol .diag WM_DELETE_WINDOW {set diagno(done) 0}
    labelframe .diag.errorf -text "Diagnostics:"
    message .diag.errorf.errorm -text "Full text of the error report, as generated by the TclTk interpreter:" -aspect 5000
    pack .diag.errorf.errorm -side top
    text .diag.errorf.e -yscrollcommand [list .diag.errorf.y set] -width 20 -height 8
    .diag.errorf.e insert 1.0 $diagnostic
    scrollbar .diag.errorf.y -command [list .diag.errorf.e yview]
    pack .diag.errorf.e -fill both -expand true -side left  -padx 4 -pady 4
    pack .diag.errorf.y -side left -fill y
    pack .diag.errorf -fill both -expand true -padx 4 -pady 4
    
    labelframe .diag.topicsf -text "Help:"
    message .diag.topicsf.errorm -text "The following relevant help topics were found.  Double-click a page title to view it." -aspect 5000
    pack .diag.topicsf.errorm -side top -padx 4 -pady 4
    pack [listbox .diag.topicsf.l -width 20 -height 8] -fill both -expand on  -padx 4 -pady 4
    bind .diag.topicsf.l <ButtonRelease-1> {GetHelp}
    pack [button .diag.b -text OK -width 10 -command {set diagno(done) 0}] -pady 4
    set diagno(keys) {}
    foreach key [array names help] {
        if {[regexp $key $diagnostic]} {
	    lappend diagno(keys) $key
            .diag.topicsf.l insert end $url($help($key))
	    pack .diag.topicsf -fill both -expand on  -padx 4 -pady 4
        }
    }
    tkwait visibility .diag
    grab .diag
    tkwait variable diagno(done)
    unset diagno(done)
    grab release .diag
    destroy .diag
}

proc GetHelp {} {
    global SIMILE_PATH diagno help
    cd $SIMILE_PATH/help
    ContextSensitiveHelp .diag \
	$help([lindex $diagno(keys) [.diag.topicsf.l curselection]])
}

proc VisitUrl {x} {
    global tcl_platform
    if [string match windows $tcl_platform(platform)] {
      set x [regsub -all -nocase {htm} $x {ht%6D}]
      exec rundll32 url.dll,FileProtocolHandler $x &
    } else {
        set url $x
        expr {
            [info exists env(BROWSER)] ||
            [findExecutable mozilla        env(BROWSER)] ||
            [findExecutable netscape       env(BROWSER)] ||
            [findExecutable iexplorer      env(BROWSER)] ||
            [findExecutable $env(NETSCAPE) env(BROWSER)] ||
            [findExecutable lynx           env(BROWSER)]
        }
        # lynx can also output formatted text to a variable
        # with the -dump option, as a last resort:
        # set formatted_text [ exec lynx -dump $url ] - PSE
        if {[catch {exec $env(BROWSER) -remote $url}]} {
            # perhaps browser doesn't understand -remote flag
            if {[catch {exec $env(BROWSER) $url &} emsg]} {
                error "Error displaying $url in browser\n$emsg"
                # Another possibility is to just pop a window up
                # with the URL to visit in it. - DKF
            }
        }
    }
}

proc ShowAbout {winId} {
    global sendvars userinfo interface
    toplevel .about
    wm transient .about $winId
    wm title .about About\ SIMILE
    image create photo dripu
    image create photo dripl
    dripu read "../Images/HelpAboutUpper.gif"
    dripl read "../Images/HelpAboutLower.gif"
    label .about.upper -image dripu
    pack .about.upper -pady 4
    frame .about.fr -relief sunken -borderwidth 2
    pack [label .about.fr.lab1 -text Version\ $sendvars(simV)\ $userinfo(edn) \
            -font {-weight bold -family helvetica -size 12}]
    set platform [frame .about.fr.platform]
    pack [label $platform.prolog -text "Prolog: $sendvars(proV)" \
            -font {-family helvetica -size 8}] -side left
    pack [label $platform.tcl -text "TclTk: [info patchlevel]" \
            -font {-family helvetica -size 8}] -side left
    pack $platform
    if [info exists userinfo(exp_time)] {
        set edate [clock format $userinfo(exp_time) -format {%d %h %Y}]
        set expf [frame .about.fr.expf]
        pack [label $expf.lab1 -text "This product expires on"] -side left
        pack [label $expf.lab2 -text $edate] -side left
        pack $expf
    }
    pack [label .about.fr.lab4 -text "This product is registered to\
            $userinfo(name), $userinfo(corp)" \
            -font {-family helvetica -size 8}]
    
    set gen [frame .about.fr.gen]
    if [string match evaluation $userinfo(edn)] {
        set info [label $gen.info -text "For upgrade to Standard\
                or Enterprise Editions," -font {-family helvetica -size 10}]
    } elseif [string match standard $userinfo(edn)] {
        set info [label $gen.info -text "For support or to upgrade\
                to Enterprise Edition," -font {-family helvetica -size 10}]
    } else {
        set info [label $gen.info -text "For support," \
                -font {-family helvetica -size 10}]
    }
    pack $info -side left
    pack [label $gen.visit -text "please visit" -font {-family helvetica -size 10}]\
            -side left
    pack [label $gen.www -text www.simulistics.com -relief flat \
            -font {-underline true -family helvetica -size 10} -fg blue -cursor hand2] -pady 2 -side left
    bind $gen.www <Button-1> "VisitUrl http://www.simulistics.com/"
    pack $gen -padx 4 -pady 2
    pack .about.fr -expand on -fill x -padx 8 -pady 2
    
    label .about.lower -image dripl
    pack .about.lower
    
    pack [button .about.b -text OK -width 10 -default active \
            -command "set sendvars(doneAbout) 1"] -pady 2
    pack [label .about.l16]
    wm geometry .about +[expr [winfo screenwidth .]/2-200]+[expr [winfo screenheight .]/2-250]
    grab .about
    
    tkwait variable sendvars(doneAbout)
    grab release .about
    destroy .about
}
