# Simile source code file: Run/equation.tcl
#
# (c) Simulistics Ltd. 2001-2005
# (c) University of Edinburgh 1995-2001
#
# This file contains procedures for the equation dialogue.
#
proc create_equation {parent purpose comp indices enum_types} {
    global equation equationbar tcl_platform iconImages window_info custom

    ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
        return
    }
    ResetEqnBar [winfo parent $parent]
    ### End formula bar section
    set topNode $window_info($parent,top_node) 
    set t [PutItThere .equation $parent]
    wm title $t "[tr. $purpose] [tr. for] [BlankCrs $comp]"
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
    set buttonF [frame $t.buttons]
    set ok [button $buttonF.ok -command equationOK \
		-width 10 -default active -text [tr. OK]]
    bind $ok <Button-1> "focus $ok" ;# make sure new names checked before exit
    set can [button $buttonF.cancel -command equationCancel \
		 -width 10 -text [tr. Cancel]]
    set help [button $buttonF.help -command {ContextSensitiveHelp .equation equations/dialogue.htm} \
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
		if {[string equal {} [$lbf parent $box]]} {
		    $lbf item $box -open 1
		}
            }
            set box $lname
        }
        set component $box.[lindex $funk 1]
        if {![$lbf exists $component]} {
            $lbf insert $box end -id $component \
                    -image $iconImages(function) -text [lrange $funk 1 end]
        }
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
		  4 5 6 - not dummy elseif dummy \
		  1 2 3 + xor dummy else dummy \
		  0 .  <- -> [tr. DEL] dummy [tr. SPACE] dummy]
    if {[string equal windows $tcl_platform(platform)]} {
	set buttWidth 4
    } else {
	set buttWidth 1
    }
    for {set row 0} {$row < 6} {incr row} {
        pack [frame $keypadf.keys.row$row] -fill x
        for {set col 0} {$col < 8} {incr col} {
            set act [lindex $keys [expr 8*$row+$col]]
	    if {[string match custom $act]} {
		set act [PrefValue custom(myButton) myButton]
	    }
	    set bid [button $keypadf.keys.row$row.col$col -width $buttWidth \
		      -text $act -command [list HitKey $t $act]]
	    pack $bid -side left -fill x -expand false
	    if {[string first $act .0123456789]>-1} {
		$bid configure -bg \#a0a0a0 -activebackground \#a0a0a0
	    } elseif {[string match AC $act]} {
		$bid configure -bg orange -activebackground orange
	    } elseif {[lsearch -exact {<- -> SPACE DEL} $act]>-1} {
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
    $mainF add [frame $mainF.main]
    TitleFrame $mainF.main.main -text "[tr. {Data source}]: "
    set mainf [GetFrame $mainF.main.main]
    frame $mainf.slider
    radiobutton $mainf.slider.radio1 -text "[tr. {Variable parameter}]: " \
	-variable equation(isparam) -value 1
    pack $mainf.slider.radio1 -side left
    pack [label $mainf.slider.minlabel -text [tr. Minimum]] -side left \
	-padx 4 -pady 4
    pack [::ttk::entry $mainf.slider.minval -width 8 \
	      -textvariable equation(min)] -side left -padx 4 -pady 4
    pack [label $mainf.slider.maxlabel -text [tr. Maximum]] -side left \
	-padx 4 -pady 4
    pack [::ttk::entry $mainf.slider.maxval -width 8 \
	      -textvariable equation(max)] -side left -padx 4 -pady 4
    
    pack [label $mainf.slider.cur_dims] -side right -padx 4
    pack [label $mainf.slider.dims_txt -text [tr. "Current dimensions"]: \
	     -wraplength 100] -side right -padx 4
    pack [set eu [::ttk::entry $mainf.slider.entry -width 8 \
		      -textvariable equation(units)]] -side right \
	-padx 4 -pady 4
    pack [label $mainf.slider.unitslabel -text "[tr. Units]:"] -side right \
	-padx 4 -pady 4
    
    pack $mainf.slider -anchor nw -fill x
    frame $mainf.file
    radiobutton $mainf.file.radio2 -text [tr. "Fixed parameter"] \
	-variable equation(isparam) -value 2
    pack $mainf.file.radio2 -side left
    pack $mainf.file -anchor nw
    frame $mainf.equation
    frame $mainf.equation.textbox
    
    radiobutton $mainf.equation.textbox.radio0 -variable equation(isparam) \
	-text "[tr. $purpose]: $comp = " -wraplength 120 -value 0
    
    set en [text $mainf.equation.textbox.text -height 4 -width 64 \
		-relief sunken -bd 2 -highlightthickness 0 -font EquationFont \
		-yscrollcommand "$mainf.equation.textbox.scroll set"]

    scrollbar $mainf.equation.textbox.scroll -orient vert -command "$en yview"
    pack $mainf.equation.textbox.scroll -side right -fill y
    pack $en -side right -expand true -fill both
    pack $mainf.equation.textbox.radio0 -anchor nw
    pack $mainf.equation.textbox -expand true -fill both -side left
    focus $en
    
    frame $mainf.equation.textbox.buttons
    #$notebook itemconfigure Main -raisecmd "focus $en"
    
    set graph [button $mainf.equation.textbox.buttons.graph \
		   -text " [tr. Graph]... "\
		   -command "equationDoGraph $t $en"]
    pack $graph -padx 8 -pady 4
    set table [button $mainf.equation.textbox.buttons.table \
		   -text " [tr. Table]... " \
		   -command [list GetTable $t $topNode $comp $en]]
    pack $table -padx 8 -pady 4
    if {![string match Darwin $tcl_platform(os)]} {
	$graph configure -compound left -image $iconImages(graph)
	$table configure -compound left -image $iconImages(table)
    }

    pack $mainf.equation.textbox.buttons -anchor e -side left
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
    
    frame $influencesf.lists
    scrollbar $influencesf.lists.yscroll -orient v \
            -command [list $influencesf.lists.f yview]
    pack $influencesf.lists.yscroll -side right -fill y
    ScrollableFrame $influencesf.lists.f -constrainedwidth true \
            -yscrollcommand [list AdjustCanvas $influencesf.lists f y]
    
    pack $influencesf.lists.f -fill x -expand true
    pack $influencesf.lists -side top -fill x -expand true
    
    set canId [GetFrame $influencesf.lists.f]
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
    text $frm.text -height 3 -width 40 -wrap word -relief sunken -bd 2 -highlightthickness 0 \
            -yscrollcommand "$frm.scrly set"
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
    
    set widget [GetFrame $equation(doc).descf.description]
    $widget.text delete 1.0 end
    $widget.text insert 1.0 $desc
    $equation(doc).cmtFrame.text delete 1.0 end
    $equation(doc).cmtFrame.text insert 1.0 $comment
    set widget [GetFrame $equation(main).main.main]
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
	set equation(isparam) 0
        set paramMenuState disabled
    } else {
        set paramMenuState normal
    }
#    $widget.equation.textbox.radio0 configure -state $paramMenuState
    $widget.slider.radio1 configure -state $paramMenuState
    $widget.file.radio2 configure -state $paramMenuState
    if {[string first Initial \
	     [wm title [winfo toplevel $equation(main)]]]==0} {
# do not allow variable parameter for initial values...derrr
	$widget.slider.radio1 configure -state disabled
    }
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
    set descFrame [GetFrame $equation(doc).descf.description]
    set eqnFrame [GetFrame $equation(main).main.main]
    
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
    global equation equationbar custom tcl_platform
    
    ### Formula bar section
    if {[string compare $equationbar(current_action) click]==0} then {
        return
    }
    if {[string compare $equationbar(current_action) tick]==0} then {
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
    set layoutStream [NetOpen [file join $layoutDir equation] w]
    puts $layoutStream [string equal zoomed [wm state $equation(top)]]
    puts $layoutStream [wm geometry $equation(top)]

    RunEnv::SaveChildrenConfig $equation(top).notebook 0 $layoutStream
    close $layoutStream
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

proc GetTable {parent topNode comp box} {
    global equation table_entry
    
    set table_entry(data) $equation(table_data)
    set table_entry(values) $equation(table_values)
    if {[equationDoTable $parent $topNode $comp "(data determines dimensions)" \
	     1]>0} {
#        if {[llength $table_entry(dataField)]} {
#            set equation(table_data) [concat [list $table_entry(fileName) \
#                    $table_entry(dataField)] \
#                    $table_entry(indices)]
#        }
	set equation(table_data) $table_entry(data)
	if {[string equal ,gdal [lindex $table_entry(values) 1]]} {
	    set equation(table_values) \
		[NumberElements [ReadGdalRefToList $table_entry(values)]]
	} else {
	    set equation(table_values) $table_entry(values)
	}
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

    set t [GetFrame $equation(main).main.main]
    set en $t.equation.textbox.text
    set paramList [GetFrame $equation(main).middle.params]
    set lbp $paramList.list.ilist
    set widget [GetFrame $equation(params).bottom.influences]
    set scroller [GetFrame $widget.lists.f]
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
	set paramPopMsg "Value(s) of [lindex $vpiTriple 0]"
	lappend equation(origins) $paramPopMsg
        set equation(oldunit,$line) [RealForUnity [lindex $vpiTriple 2]]
        
        set p [entry $scroller.plist.p$line -bd 0 -relief flat \
                -font TkDefaultFont -textvariable "equation(entry$line)"]
        bind $p <Enter> [list QueuePopup AddWidgetPopup %X %Y $paramPopMsg]
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
        set showLines [max 3 [min 8 $line]]
        $widget.lists.f configure -height \
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
    bind $lbf <Double-1> [list functionClick %W %x %y $en]

    set PopCmd [list QueuePopup AddIndexPopup %W %y %X %Y]
    bind $lbx <Enter> $PopCmd
    bind $lbx <Motion> "RemovePopup;$PopCmd"
    bind $lbx <Leave> RemovePopup
    bind $lbx <Double-1> "indexClick %W %y $en; focus $en"

    set PopCmd [list QueuePopup AddParamPopup %W %y %X %Y]
    bind $lbp <Enter> $PopCmd
    bind $lbp <Motion> "RemovePopup;$PopCmd"
    bind $lbp <Leave> RemovePopup    
    bind $lbp <Double-1> "paramClick %W %y $en; focus $en"
    
    bind $gr <Tab> "focus $ta"
    bind $ta <Tab> "focus $ok"
    bind $ok <Tab> "focus $can"
    bind $can <Tab> "focus $gr"
    
    bind $en <Key> "FlashMatchingBracket %W %A"
    $en tag configure flash -background blue ;# for matching brackets
    # Set up for type in
    focus $en
}

# Following is copied from autocomplete in window, which does same job for
# eqn bar. Diffrences interacting with a text widget are so great that it is
# simplest just to have a separate procedure.
proc FlashMatchingBracket {win testChar} {
    set pt 0
    set brackets \(\[\{\)\]\}
    set bNum [string first $testChar $brackets]
    if {$bNum>2} { ;# 2 to enable; cannot config selbg for ttk::entry
	lappend stacket $bNum
	while {[$win index "insert - $pt chars"]>1.0} {
	    set testChar [$win get "insert - [incr pt] chars"]
	    set bNum [string first $testChar $brackets]
	    if {$bNum>2} {
		lappend stacket $bNum
	    } elseif {$bNum>-1} {
		if {$bNum+3==[lindex $stacket end]} { ;# match!
		    set stacket [lrange $stacket 0 end-1]
		    if {![llength $stacket]} {
			FlashTextRange $win $pt
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
	    FlashTextRange $win 0
	    #$win config -selectbackground red
	}
    }
}

proc FlashTextRange {win pt} {
    set pt [$win index "insert - $pt chars"]
    after idle $win tag add flash $pt
    after 100 $win tag remove flash $pt
    after 200 $win tag add flash $pt
    after 300 $win tag remove flash $pt
    after 400 $win tag add flash $pt
    after 500 $win tag remove flash $pt
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

    if {![string equal $equation($type$line) $equation(old$type,$line)]} {
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
	} \{ {
	    event generate $winId <Key-braceleft>
	} \} {
	    event generate $winId <Key-braceright>
	} default {
	    set begin 1.0
	    if {[string match *Entry [winfo class [focus]]]} {
		set begin 0
	    } else {
		focus [GetFrame $equation(main).main.main].equation.textbox.text
	    }
	    if {[string match AC $char]} {	    
		[focus] delete $begin end
	    } else {
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
	AddWidgetPopup $X $Y $popTxt
    }
}

proc AddIndexPopup {lb y X Y} {
    set line [$lb nearest $y]
    if {$line>-1} {
	AddWidgetPopup $X $Y "Index [expr $line+1] is [$lb get $line]"
    }
}

proc AddParamPopup {lb y X Y} {
    global equation
    set line [$lb nearest $y]
    if {$line>-1} {
	AddWidgetPopup $X $Y [lindex $equation(origins) $line]
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

