# Simile source code file: Run/equation.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for the equation dialogue.
#
proc create_equation {parent boxtitle indices} {
    global equation equationbar tcl_platform iconImages
    
    ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        return
    }
    ResetEqnBar [winfo parent $parent]
    ### End formula bar section
    if [string match Darwin $tcl_platform(os)] {
      set t [toplevel .equation -bd 4 -class Equation]; ::tk::unsupported::MacWindowStyle style .equation floatZoomProc
    } else {
      set t [toplevel .equation -bd 4 -class Equation]
      wm transient $t $parent
    }
    wm title $t [BlankCrs $boxtitle]
    set equation(top) $t
    wm protocol $t WM_DELETE_WINDOW "equationCancel"
    
    set notebook [::ttk::notebook $t.notebook]
    $notebook add [frame $notebook.main] -text Main
    set mainF $notebook.main
    $notebook add [frame $notebook.documentation] -text Documentation
    set docF $notebook.documentation
    set equation(notebook) $notebook
    set equation(main) $mainF
    set equation(doc) $docF
    
    # frame for buttons
    set buttonF [frame $t.buttons]
    set ok [button $buttonF.ok -command equationOK \
            -width 10 -default active -text "OK"]
    bind $ok <Button-1> "focus $ok" ;# make sure new names checked before exit
    set can [button $buttonF.cancel -command equationCancel \
            -width 10 -text "Cancel"]
    set help [button $buttonF.help -command {ContextSensitiveHelp .equation equations/dialogue.htm} \
            -width 10 -text "Help"]
    pack $help -side right -padx 8 -pady 4 -anchor e
    pack $can -side right -padx 8 -pady 4 -anchor e
    pack $ok -side right -padx 8 -pady 4 -anchor e
    pack $buttonF -anchor nw -fill x -side bottom
    
    # Middle frame has the functions, indices and keypad
    # created variable middleF to point to the Middle frame makes moving the frame in
    # the widget hierrachy easier Jonathan 22 Aug 2002
    set middleF [frame $mainF.middle]
    TitleFrame $middleF.functions -text "Functions: "
    set fnFrame [$middleF.functions getframe].fnFrame
    ScrolledWindow $fnFrame
    set lbf [Tree $fnFrame.table -showlines yes]
    $fnFrame setwidget $lbf
    pack $fnFrame -expand yes -fill both
    
    foreach funk $equation(fnDefs) {
        set box root
        foreach level [split [join [lindex $funk 0] /] /] {
            set lname $box.[join $level _]
            if {![$lbf exists $lname]} {
                $lbf insert end $box $lname -image $iconImages(open) \
                        -text $level -open [string equal Built-in $level]
            }
            set box $lname
        }
        set component $box.[lindex $funk 1]
        if {![$lbf exists $component]} {
            $lbf insert end $box $component \
                    -image $iconImages(function) -text [lrange $funk 1 end]
        }
    }
    
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
    set keys {< > ( ) \{ \} \[ \] = ^ , / and dummy if dummy 7 8 9 * or dummy then dummy \
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
    radiobutton $mainf.slider.radio1 -text "Variable parameter: " -variable equation(isparam) -value 1
    pack $mainf.slider.radio1 -side left
    pack [label $mainf.slider.minlabel -text Minimum] -side left -padx 4 -pady 4
    pack [::ttk::entry $mainf.slider.minval -width 8 -textvariable equation(min)] -side left -padx 4 -pady 4
    pack [label $mainf.slider.maxlabel -text Maximum] -side left -padx 4 -pady 4
    pack [::ttk::entry $mainf.slider.maxval -width 8 -textvariable equation(max)] -side left -padx 4 -pady 4
    
    pack [label $mainf.slider.cur_dims] -side right -padx 4
    pack [label $mainf.slider.dims_txt -text "Current\ndimensions:"] -side right -padx 4
    pack [set eu [::ttk::entry $mainf.slider.entry -width 8 -textvariable equation(units)]] -side right -padx 4 -pady 4
    pack [label $mainf.slider.unitslabel -text "Units:"] -side right -padx 4 -pady 4
    
    pack $mainf.slider -anchor nw -fill x
    frame $mainf.file
    radiobutton $mainf.file.radio2 -text "Fixed parameter" -variable equation(isparam) -value 2
    pack $mainf.file.radio2 -side left
    pack $mainf.file -anchor nw
    frame $mainf.equation
    frame $mainf.equation.textbox
    
    regsub { for } $boxtitle {: } eqnRBtext
    radiobutton $mainf.equation.textbox.radio0 -text "$eqnRBtext = " -variable equation(isparam) -value 0
    
    set en [text $mainf.equation.textbox.text -height 4 -width 80 -yscrollcommand "$mainf.equation.textbox.scroll set"]
    scrollbar $mainf.equation.textbox.scroll -orient vert -command "$en yview"
    pack $mainf.equation.textbox.scroll -side right -fill y
    pack $en -side right -expand true -fill both
    pack $mainf.equation.textbox.radio0 -anchor nw
    pack $mainf.equation.textbox -expand true -fill both -side left
    focus $en
    
    frame $mainf.equation.textbox.buttons
    #$notebook itemconfigure Main -raisecmd "focus $en"
    set comp [lrange $boxtitle [expr [lsearch $boxtitle for]+1] end]
    
    if {[string match Darwin $tcl_platform(os)]} {
        set graph [button $mainf.equation.textbox.buttons.graph \
                -text " Graph... "\
                -command "equationDoGraph $t $en"]
        pack $graph -padx 8 -pady 4
        set table [button $mainf.equation.textbox.buttons.table \
                -text " Table... " \
                -command [list GetTable $t $comp $en]]
        pack $table -padx 8 -pady 4
    } else  {
        set graph [button $mainf.equation.textbox.buttons.graph \
                -compound left -image $iconImages(graph) -text " Graph... "\
                -command "equationDoGraph $t $en"]
        pack $graph -padx 8 -pady 4
        set table [button $mainf.equation.textbox.buttons.table \
                -compound left -image $iconImages(table) -text " Table... "\
                -command [list GetTable $t $comp $en]]
        pack $table -padx 8 -pady 4
    }
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
    scrollbar $influencesf.lists.yscroll -orient v \
            -command [list $influencesf.lists.f yview]
    pack $influencesf.lists.yscroll -side right -fill y
    ScrollableFrame $influencesf.lists.f -constrainedwidth true \
            -yscrollcommand [list AdjustCanvas $influencesf.lists f y]
    
    pack $influencesf.lists.f -fill x -expand true
    pack $influencesf.lists -side top -fill x -expand true
    
    set canId [$influencesf.lists.f getframe]
    set lbp [frame $canId.plist -bd 2 -relief sunken]
    set lbi [frame $canId.ilist -bd 2 -relief sunken]
    set lbd [frame $canId.dlist -bd 2 -relief sunken]
    pack $canId.plist $canId.ilist $canId.dlist -side left -fill x -expand true
    pack $bottomF.influences -fill x -anchor nw -padx 2 -pady 2
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
    #$notebook itemconfigure Documentation -raisecmd "focus $descf.text"
    
    label $docF.cmtlabel -text Comments:
    pack $docF.cmtlabel -side top
    pack [set frm [frame $docF.cmtFrame]] -fill both -expand true
    text $frm.text -height 3 -width 40 -wrap word \
            -yscrollcommand "$frm.scrly set"
    scrollbar $frm.scrly -orient vert -command "$frm.text yview"
    pack $frm.text -side left -fill both -expand true
    pack $frm.scrly -side right -fill y
    
    $notebook select 0
    pack $notebook -fill both -expand true
    set equation(newGraphs) ""
    set equation(done) 0
    equationBindings $t $en $eu $lbp $lbi $lbd $lbf $lbx $graph $table $ok $can
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
    $widget.equation.textbox.text insert 1.0 $current_equation
    set equation(units) [RealForUnity $units]
    if {[llength $mult]} {
        set emult [join $mult ,]
    } else {
        set emult none
    }
    $widget.slider.cur_dims configure -text $emult
    set equation(isparam) $isParam
    if {$equation(isparam)==-1} {
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

proc interact_equation {} {
    global equation equationbar tcl_platform
    
    ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        set equationbar(current_action) click
        return [list $equationbar(equation) \
                $equationbar(units) \
                $equationbar(isParam) \
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
    
    
    LetItShow $t
    grab $t
    tkwait variable equation(done)
    grab release $t
    switch $equation(done) {
        1 {
            set units [UnityForReal $equation(units)]
            return [list [string trimright \
                    [$eqnFrame.equation.textbox.text get 1.0 end]] \
                    $units $equation(isparam) \
                    [string trimright [$descFrame.text get 1.0 end]] \
                    [string trimright [$equation(doc).cmtFrame.text get 1.0 end]] \
                    $equation(min) $equation(max)]
        } 2 {
            return [list $equation(paths,$equation(ckLine)) \
                    $equation(entry$equation(ckLine)) \
                    [UnityForReal $equation(unit$equation(ckLine))]]
        } 3 {
            return [list \['[join $equation(table_data) ',']'\] \
                    $equation(table_values)]
        }
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
    
    focus [wm transient $equation(top)]
    destroy $equation(top)
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

# Allow table viewer to be used in this interp
source ../IOTools/DisplayFormats.tcl 
source ../IOTools/graphtools.tcl
source ../IOTools/two_table.tcl
set table_viewer(id) $keyValue

proc GetTable {parent comp box} {
    global equation table_entry
    
    set table_entry(data) $equation(table_data)
    set table_entry(values) $equation(table_values)
    if {[equationDoTable $parent $comp 1]} {
        if {[llength $table_entry(dataField)]} {
            set equation(table_data) [concat [list $table_entry(fileName) \
                    $table_entry(dataField)] \
                    $table_entry(indices)]
        }
        set equation(table_values) $table_entry(values)
        if {![string match *table(*)* [$box get 1.0 end]]} {
	    InsertFunction $box table
        }
        set equation(done) 3
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
    
    set t [$equation(main).main.main getframe]
    set en $t.equation.textbox.text
    set widget [$equation(main).bottom.influences getframe]
    set scroller [$widget.lists.f getframe]
    # Initialize variables and display  list
    foreach ipFrame {plist ilist dlist} {
        foreach ipEntry [winfo children $scroller.$ipFrame] {
            destroy $ipEntry
        }
    }
    set line 0
    foreach vpiTriple $triples {
        set equation(paths,$line) [lindex $vpiTriple 0]
        set equation(oldentry,$line) [lindex $vpiTriple 1]
        set equation(oldunit,$line) [RealForUnity [lindex $vpiTriple 2]]
        
        set p [entry $scroller.plist.p$line -bd 0 -relief flat \
                -textvariable "equation(entry$line)"]
        bind $p <Enter> [list QueuePopup AddWidgetPopup \
                "Value(s) of [lindex $vpiTriple 0]" %X %Y]
        bind $p <Double-1> "equationDouble %W $en; focus $en"
        bind $p <FocusOut> "ListEditDone $line"
        bind $p <Return> "ListEditDone $line"
        bind $p <Leave> RemovePopup
        $p config -highlightbackground [$p cget -background]
        $p delete 0 end
        $p insert end $equation(oldentry,$line)
        pack $p -fill x -expand true
        
        set u [entry $scroller.ilist.u$line -bd 0 -relief flat \
                -textvariable "equation(unit$line)"]
        bind $u <FocusOut> "ListEditDone $line"
        bind $u <Return> "ListEditDone $line"
        $u config -highlightbackground [$u cget -background]
        $u delete 0 end
        $u insert end $equation(oldunit,$line)
        pack $u -fill x -expand true
        set d [entry $scroller.dlist.d$line -bd 0 -relief flat]
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
        pack forget $equation(main).bottom
    } else {
        set showLines [max 3 [min 8 $line]]
        $widget.lists.f configure -height \
                [expr $showLines*[winfo reqheight $scroller.plist.p0]+4]
        update
    }
}

proc fill_table {table_data table_values} {
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
}

proc equationBindings { t en eu lbp lbi lbd lbf lbx gr ta ok can} {
    # t - toplevel
    # en - equation entry
    # eu - units entry
    
    # lbf - treebox for available functions
    # lbx - listbox for available indices
    # lbp - parameter listbox
    # lbi - input units listbox
    # gr - graph button
    # ta - table button
    # ok - OK button
    # can - Cancel button
    
    
    $lbf bindText <Enter> [list QueuePopup AddFnPopup %X %Y]
    $lbf bindText <Leave> RemovePopup
    $lbf bindText <Double-1> [list functionClick $en]

    set PopCmd [list QueuePopup AddIndexPopup %W %y %X %Y]
    bind $lbx <Enter> $PopCmd
    bind $lbx <Motion> "RemovePopup;$PopCmd"
    bind $lbx <Leave> RemovePopup
    
    bind $lbx <Double-1> \
            "indexClick %W %y $en; focus $en"
    
    bind $gr <Tab> "focus $ta"
    bind $ta <Tab> "focus $ok"
    bind $ok <Tab> "focus $can"
    bind $can <Tab> "focus $gr"
    
    # Set up for type in
    focus $en
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
    if [string match Darwin $tcl_platform(os)] {
      set t [toplevel .graph -bd 4 -class graphEntry]; ::tk::unsupported::MacWindowStyle style .graph floatZoomProc
    } else {
      toplevel .graph -class graphEntry -bd 4
      wm transient .graph $parent
    }
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
    destroy .graph
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
}

proc ListEditDone {line} {
    global equation
    set widget [$equation(main).bottom.influences getframe]
    set scroller [$widget.lists.f getframe]
    
    if {![string equal $equation(entry$line) $equation(oldentry,$line)] || \
                ![string equal $equation(unit$line) $equation(oldunit,$line)]} {
        set equation(ckLine) $line
        set equation(done) 2
    }
}

proc equationDouble { lb boxname} {
    # Take the item the user clicked on
    $boxname insert insert [$lb get]
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

proc functionClick {boxname fn} {
    # Take the item the user clicked on
    InsertFunction $boxname [lindex [split $fn .] end]
}

proc AddFnPopup {X Y fnName} {
    AddWidgetPopup [lindex [split $fnName .] end] $X $Y
}

proc AddIndexPopup {lb y X Y} {
    global equation
    set line [$lb nearest $y]
    AddWidgetPopup "Index [expr $line+1] is [$lb get $line]" $X $Y
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